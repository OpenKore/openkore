# To run kore, execute openkore.pl instead.

#########################################################################
# This software is open source, licensed under the GNU General Public
# License, version 2.
# Basically, this means that you're allowed to modify and distribute
# this software. However, if you distribute modified versions, you MUST
# also distribute the source code.
# See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################

use strict;
use Time::HiRes qw(time usleep);
use IO::Socket;
use Text::ParseWords;
use Carp::Assert;
use Config;
use encoding 'utf8';

use Globals;
use Modules;
use Settings qw(%sys);
use Log qw(message warning error debug);
use Interface;
use Network::Receive;
use Network::Send;
use Commands;
use Misc;
use Plugins;
use Utils;
use ChatQueue;
use I18N;
use Utils::Benchmark;
use Utils::HttpReader;


# use SelfLoader; 1;
# __DATA__


#######################################
#INITIALIZE VARIABLES
#######################################

# Calculate next random restart time.
# The restart time will be autoRestartMin + rand(autoRestartSeed)
sub initRandomRestart {
	if ($config{'autoRestart'}) {
		my $autoRestart = $config{'autoRestartMin'} + int(rand $config{'autoRestartSeed'});
		message TF("Next restart in %s\n", timeConvert($autoRestart)), "system";
		configModify("autoRestart", $autoRestart, 1);
	}
}

# Initialize random configuration switching time
sub initConfChange {
	my $i = 0;
	while (exists $ai_v{"autoConfChange_${i}_timeout"}) {
		delete $ai_v{"autoConfChange_${i}_timeout"};
		$i++;
	}

	$i = 0;
	while (exists $config{"autoConfChange_$i"}) {
		$ai_v{"autoConfChange_${i}_timeout"} = $config{"autoConfChange_${i}_minTime"} +
			int(rand($config{"autoConfChange_${i}_varTime"}));
		$i++;
	}
	$lastConfChangeTime = time;
}

# Initialize variables when you start a connection to a map server
sub initConnectVars {
	# we must use $chars[$config{char}] here because $char may not be set
	initMapChangeVars();
	$chars[$config{char}]{skills} = {} if ($chars[$config{char}]{skills});
	undef @skillsID;
	delete $chars[$config{char}]{mute_period};
	delete $chars[$config{char}]{muted};
	$useArrowCraft = 1;
}

# Initialize variables when you change map (after a teleport or after you walked into a portal)
sub initMapChangeVars {
	# we must use $chars[$config{char}] here because $char may not be set
	@portalsID_old = @portalsID;
	%portals_old = %portals;
	foreach (@portalsID_old) {
		next if (!$_ || !$portals_old{$_});
		$portals_old{$_}{gone_time} = time if (!$portals_old{$_}{gone_time});
	}

	# this is just used for portalRecord (add opposite portal by guessing method)
	$chars[$config{char}]{old_pos_to} = {%{$chars[$config{char}]{pos_to}}} if ($chars[$config{char}]{pos_to});
	delete $chars[$config{char}]{sitting};
	delete $chars[$config{char}]{dead};
	delete $chars[$config{char}]{warp};
	delete $chars[$config{char}]{casting};
	delete $chars[$config{char}]{homunculus}{appear_time};
	$timeout{play}{time} = time;
	$timeout{ai_sync}{time} = time;
	$timeout{ai_sit_idle}{time} = time;
	$timeout{ai_teleport}{time} = time;
	$timeout{ai_teleport_idle}{time} = time;
	$timeout{ai_teleport_safe_force}{time} = time;

	delete $timeout{ai_teleport_retry}{time};
	delete $timeout{ai_teleport_delay}{time};

	undef %incomingDeal;
	undef %outgoingDeal;
	undef %currentDeal;
	undef $currentChatRoom;
	undef @currentChatRoomUsers;
	undef @itemsID;
	undef @identifyID;
	undef @spellsID;
	undef @arrowCraftID;
	undef %items;
	undef %spells;
	undef %incomingParty;
	#undef $msg;		# Why're these undefined?
	#undef $msgOut;
	undef %talk;
	$ai_v{cart_time} = time + 60;
	$ai_v{inventory_time} = time + 60;
	$ai_v{temp} = {};
	$cart{inventory} = [];
	$chars[$config{char}]{inventory} = [];
	undef @venderItemList;
	undef $venderID;
	undef @venderListsID;
	undef %venderLists;
	undef %incomingGuild;
	undef @chatRoomsID;
	undef %chatRooms;
	undef @lastpm;
	undef %incomingFriend;

	$itemsList->clear();
	$monstersList->clear();
	$playersList->clear();
	$petsList->clear();
	$portalsList->clear();
	$npcsList->clear();

	@unknownPlayers = ();
	@unknownNPCs = ();
	@sellList = ();

	$shopstarted = 0;
	$timeout{ai_shop}{time} = time;
	$timeout{ai_storageAuto}{time} = time + 5;
	$timeout{ai_buyAuto}{time} = time + 5;

	AI::clear("attack", "route", "move");
	AI::Homunculus::clear("attack", "route", "move");
	ChatQueue::clear;

	initOtherVars();
	Plugins::callHook('packet_mapChange');

	$logAppend = ($config{logAppendUsername}) ? "_$config{username}_$config{char}" : '';
	if ($config{logAppendUsername} && !($Settings::storage_file =~ /$logAppend/)) {
		$Settings::chat_file	 = substr($Settings::chat_file,0,length($Settings::chat_file)-4)."$logAppend.txt";
		$Settings::monster_log	 = substr($Settings::monster_log,0,length($Settings::monster_log)-4)."$logAppend.txt";
		$Settings::item_log_file = substr($Settings::item_log_file,0,length($Settings::item_log_file)-4)."$logAppend.txt";
		$Settings::storage_file  = substr($Settings::storage_file,0,length($Settings::storage_file)-4)."$logAppend.txt";
		$Settings::shop_log_file = substr($Settings::shop_log_file,0,length($Settings::shop_log_file)-4)."$logAppend.txt";
	}
}

# Initialize variables when your character logs in
sub initStatVars {
	$totaldmg = 0;
	$dmgpsec = 0;
	$startedattack = 0;
	$monstarttime = 0;
	$monkilltime = 0;
	$elasped = 0;
	$totalelasped = 0;
	$statChanged = 0;
	$skillChanged = 0;
}

sub initOtherVars {
	$timeout{ai_shop}{time} = time;
}

sub mainLoop {
	Benchmark::begin("mainLoop") if DEBUG;
	Plugins::callHook('mainLoop_pre');

	Benchmark::begin("mainLoop_part1") if DEBUG;

	# Parse command input
	my $input;
	if (defined($input = $interface->getInput(0))) {
		Misc::checkValidity("parseInput (pre)");
		parseInput($input);
		Misc::checkValidity("parseInput");
	}

	# Handle connection states
	$net->checkConnection();

	# Receive and handle data from the RO server
	my $servMsg = $net->serverRecv;
	if ($servMsg && length($servMsg)) {
		Benchmark::begin("parseMsg") if DEBUG;
		$msg .= $servMsg;
		my $msg_length = length($msg);
		while ($msg ne "") {
			$msg = parseMsg($msg);
			last if ($msg_length == length($msg));
			$msg_length = length($msg);
		}
		$net->clientFlush() if (UNIVERSAL::isa($net, 'XKoreProxy'));
		Benchmark::end("parseMsg") if DEBUG;
	}

	# Receive and handle data from the RO client
	my $cliMsg = $net->clientRecv;
	if ($cliMsg && length($cliMsg)) {
		use bytes; # pmak/VCL - fix corrupted data introduced by UTF8
		no encoding 'utf8';
		$msgOut .= $cliMsg;
		my $msg_length = length($msgOut);
		while ($msgOut ne "") {
			$msgOut = parseSendMsg($msgOut);
			last if ($msg_length == length($msgOut));
			$msg_length = length($msgOut);
		}
	}

	# GameGuard support
	if ($config{gameGuard} && ($net->version != 1 || ($net->version == 1 && $config{gameGuard} eq '2'))) {
		my $result = Poseidon::Client::getInstance()->getResult();
		if (defined($result)) {
			debug "Received Poseidon result.\n", "poseidon";
			$net->serverSend($result);
		}
	}

	Benchmark::end("mainLoop_part1") if DEBUG;
	Benchmark::begin("mainLoop_part2") if DEBUG;

	# Process AI
	if ($conState == 5 && timeOut($timeout{ai}) && $net->serverAlive()) {
		Misc::checkValidity("AI (pre)");
		Benchmark::begin("ai") if DEBUG;
		AI::CoreLogic::iterate();
		Benchmark::end("ai") if DEBUG;
		Benchmark::begin("ai_homunculus") if DEBUG;
		AI::Homunculus::iterate();
		Benchmark::end("ai_homunculus") if DEBUG;
		Misc::checkValidity("AI");
		return if $quit;
	}

	Benchmark::end("mainLoop_part2") if DEBUG;
	Benchmark::begin("mainLoop_part3") if DEBUG;

	# Process messages from the IPC network
	if ($ipc && $ipc->connected) {
		my @ipcMessages;
		$ipc->iterate;
		if ($ipc->ready && $ipc->recv(\@ipcMessages) > 0) {
			foreach (@ipcMessages) {
				IPC::Processors::process($ipc, $_);
			}
		}
	}


	###### Other stuff that's run in the main loop #####

	if ($config{'autoRestart'} && time - $KoreStartTime > $config{'autoRestart'}
	 && $conState == 5 && !AI::inQueue(qw/attack take items_take/)) {
		message T("\nAuto-restarting!!\n"), "system";

		if ($config{'autoRestartSleep'}) {
			my $sleeptime = $config{'autoSleepMin'} + int(rand $config{'autoSleepSeed'});
			$timeout_ex{'master'}{'timeout'} = $sleeptime;
			$sleeptime = $timeout{'reconnect'}{'timeout'} if ($sleeptime < $timeout{'reconnect'}{'timeout'});
			message TF("Sleeping for %s\n", timeConvert($sleeptime)), "system";
		} else {
			$timeout_ex{'master'}{'timeout'} = $timeout{'reconnect'}{'timeout'};
		}

		$timeout_ex{'master'}{'time'} = time;
		$KoreStartTime = time + $timeout_ex{'master'}{'timeout'};
		AI::clear();
		AI::Homunculus::clear();
		undef %ai_v;
		$net->serverDisconnect;
		$conState = 1;
		undef $conState_tries;
		initRandomRestart();
	}

	# Automatically switch to a different config file
	# based on certain conditions
	if ($conState == 5 && timeOut($AI::Timeouts::autoConfChangeTime, 0.5)
	 && !AI::inQueue(qw/attack take items_take/)) {
		my $selected;
		my $i = 0;
		while (exists $config{"autoConfChange_$i"}) {
			if ($config{"autoConfChange_$i"}
			 && ( !$config{"autoConfChange_${i}_minTime"} || timeOut($lastConfChangeTime, $ai_v{"autoConfChange_${i}_timeout"}) )
			 && inRange($char->{lv}, $config{"autoConfChange_${i}_lvl"})
			 && inRange($char->{lv_job}, $config{"autoConfChange_${i}_joblvl"})
			 && ( !$config{"autoConfChange_${i}_isJob"} || $jobs_lut{$char->{jobID}} eq $config{"autoConfChange_${i}_isJob"} )
			) {
				$selected = $config{"autoConfChange_$i"};
				last;
			}
			$i++;
		}

		if ($selected) {
			# Choose a random configuration file
			my @files = split(/,+/, $selected);
			my $file = $files[rand(@files)];
			message TF("Changing configuration file (from \"%s\" to \"%s\")...\n", $Settings::config_file, $file), "system";

			# A relogin is necessary if the server host/port, username
			# or char is different.
			my $oldMaster = $masterServer;
			my $oldUsername = $config{'username'};
			my $oldChar = $config{'char'};

			switchConfigFile($file);

			my $master = $masterServer = $masterServers{$config{'master'}};
			if ($net->version != 1
			 && $oldMaster->{ip} ne $master->{ip}
			 || $oldMaster->{port} ne $master->{port}
			 || $oldMaster->{master_version} ne $master->{master_version}
			 || $oldMaster->{version} ne $master->{version}
			 || $oldUsername ne $config{'username'}
			 || $oldChar ne $config{'char'}) {
				AI::clear;
				AI::Homunculus::clear();
				relog();
			} else {
				AI::clear("move", "route", "mapRoute");
				AI::Homunculus::clear("move", "route", "mapRoute");
			}

			initConfChange();
		}

		$AI::Timeouts::autoConfChangeTime = time;
	}

	processStatisticsReporting() unless ($sys{sendAnonymousStatisticReport} eq "0");

	# Update walk.dat
	if ($conState == 5 && timeOut($AI::Timeouts::mapdrt, $config{intervalMapDrt})) {
		$AI::Timeouts::mapdrt = time;
		if ($field{name}) {
			Misc::checkValidity("walk.dat (pre)");
			my $pos = calcPosition($char);
			open(DATA, ">$Settings::logs_folder/walk.dat");
			print DATA "$field{name} $field{baseName}\n";
			print DATA "$pos->{x}\n$pos->{y}\n";
			if ($ipc && $ipc->connected && $ipc->ready) {
				print DATA $ipc->host . " " . $ipc->port . " " . $ipc->ID . "\n";
			} else {
				print DATA "\n";
			}

			for (my $i = 0; $i < @npcsID; $i++) {
				next if ($npcsID[$i] eq "");
				print DATA "NL " . $npcs{$npcsID[$i]}{pos}{x} . " " . $npcs{$npcsID[$i]}{pos}{y} . "\n";
			}
			for (my $i = 0; $i < @playersID; $i++) {
				next if ($playersID[$i] eq "");
				print DATA "PL " . $players{$playersID[$i]}{pos_to}{x} . " " . $players{$playersID[$i]}{pos_to}{y} . "\n";
			}
			for (my $i = 0; $i < @monstersID; $i++) {
				next if ($monstersID[$i] eq "");
				print DATA "ML " . $monsters{$monstersID[$i]}{pos_to}{x} . " " . $monsters{$monstersID[$i]}{pos_to}{y} . "\n";
			}

			close(DATA);
			Misc::checkValidity("walk.dat");
		}
	}

	# Set interface title
	my $charName = $chars[$config{'char'}]{'name'};
	my $title;
	$charName .= ': ' if defined $charName;
	if ($conState == 5) {
		my ($basePercent, $jobPercent, $weight, $pos);

		$basePercent = sprintf("%.2f", $chars[$config{'char'}]{'exp'} / $chars[$config{'char'}]{'exp_max'} * 100) if $chars[$config{'char'}]{'exp_max'};
		$jobPercent = sprintf("%.2f", $chars[$config{'char'}]{'exp_job'} / $chars[$config{'char'}]{'exp_job_max'} * 100) if $chars[$config{'char'}]{'exp_job_max'};
		$weight = int($chars[$config{'char'}]{'weight'} / $chars[$config{'char'}]{'weight_max'} * 100) . "%" if $chars[$config{'char'}]{'weight_max'};
		$pos = " : $char->{pos_to}{x},$char->{pos_to}{y} $field{'name'}" if ($char->{pos_to} && $field{'name'});

		# Translation Comment: Interface Title with character status
		$title = TF("%s B%s (%s), J%s (%s) : w%s%s - %s", 
			${charName}, $chars[$config{'char'}]{'lv'}, $basePercent.'%', 
			$chars[$config{'char'}]{'lv_job'}, $jobPercent.'%',
			$weight, ${pos}, $Settings::NAME);

	} elsif ($conState == 1) {
		# Translation Comment: Interface Title
		$title = TF("%sNot connected - %s", ${charName}, $Settings::NAME);
	} else {
		# Translation Comment: Interface Title
		$title = TF("%sConnecting - %s", ${charName}, $Settings::NAME);
	}
	my %args = (return => $title);
	Plugins::callHook('mainLoop::setTitle',\%args);
	$interface->title($args{return});

	Benchmark::end("mainLoop_part3") if DEBUG;

	Plugins::callHook('mainLoop_post');
	Benchmark::end("mainLoop") if DEBUG;

	# Reload any modules that requested to be reloaded
	Modules::doReload();
}

# Anonymous statistics reporting. This gives us insight about
# server our users play.
sub processStatisticsReporting {
	our %statisticsReporting;
	return if ($statisticsReporting{done} || !$config{master} || !$config{username});

	if (!$statisticsReporting{http}) {
		use Utils qw(urlencode);
		import Utils::Whirlpool qw(whirlpool_hex);

		# Note that ABSOLUTELY NO SENSITIVE INFORMATION about the
		# user is sent. The username is filtered through an
		# irreversible hashing algorithm before it is sent to the
		# server. It is impossible to deduce the user's username
		# from the data sent to the server.
		my $url = "http://www.openkore.com/statistics.php?";
		$url .= "server=" . urlencode($config{master});
		$url .= "&product=" . urlencode($Settings::NAME);
		$url .= "&version=" . urlencode($Settings::VERSION);
		$url .= "&uid=" . urlencode(whirlpool_hex($config{master} . $config{username} . $userSeed));
		$statisticsReporting{http} = new StdHttpReader($url);
		debug "Posting anonymous usage statistics to $url\n", "statisticsReporting";
	}

	my $http = $statisticsReporting{http};
	if ($http->getStatus() == HttpReader::DONE) {
		$statisticsReporting{done} = 1;
		delete $statisticsReporting{http};
		debug "Statistics posting completed.\n", "statisticsReporting";

	} elsif ($http->getStatus() == HttpReader::ERROR) {
		$statisticsReporting{done} = 1;
		delete $statisticsReporting{http};
		debug "Statistics posting failed: " . $http->getError() . "\n", "statisticsReporting";
	}
}


#######################################
#PARSE INPUT
#######################################


sub parseInput {
	my $input = shift;
	my $printType;
	my ($hook, $msg);
	$printType = shift if ($net->clientAlive);

	debug("Input: $input\n", "parseInput", 2);

	if ($printType) {
		my $hookOutput = sub {
			my ($type, $domain, $level, $globalVerbosity, $message, $user_data) = @_;
			$msg .= $message if ($type ne 'debug' && $level <= $globalVerbosity);
		};
		$hook = Log::addHook($hookOutput);
		$interface->writeOutput("console", "$input\n");
	}
	$XKore_dontRedirect = 1;

	# Check if in special state
	if ($net->version != 1 && $conState == 2 && $waitingForInput) {
		configModify('server', $input, 1);
		$waitingForInput = 0;

	} else {
		Commands::run($input);
	}

	if ($printType) {
		Log::delHook($hook);
		if (defined $msg && $conState == 5 && $config{XKore_silent}) {
			$msg =~ s/\n*$//s;
			$msg =~ s/\n/\\n/g;
			sendMessage($net, "k", $msg);
		}
	}
	$XKore_dontRedirect = 0;
}


#######################################
#######################################
# Parse RO Client Send Message
#######################################
#######################################

sub parseSendMsg {
	use bytes;
	no encoding 'utf8';
	my $msg = shift;

	my $sendMsg = $msg;
	if (length($msg) >= 4 && $conState >= 4 && length($msg) >= unpack("v1", substr($msg, 0, 2))) {
		decrypt(\$msg, $msg);
	}
	my $switch = uc(unpack("H2", substr($msg, 1, 1))) . uc(unpack("H2", substr($msg, 0, 1)));
	if ($config{'debugPacket_ro_sent'} && !existsInList($config{'debugPacket_exclude'}, $switch)
	   || $config{debugPacket_include_dumpMethod} && existsInList($config{'debugPacket_include'}, $switch)) {
		my $label = $packetDescriptions{Send}{$switch} ?
			" - $packetDescriptions{Send}{$switch})" : '';
		
		if ($config{debugPacket_ro_sent} == 1) {
			debug "Packet SENT_BY_CLIENT: $switch$label\n", "parseSendMsg", 0;
		} elsif ($config{debugPacket_ro_sent} == 2) {
			visualDump($sendMsg, $switch . $label);
		}
		if ($config{debugPacket_include_dumpMethod} == 1) {
			debug "Packet: $switch$label\n", "parseMsg", 0;
		} elsif ($config{debugPacket_include_dumpMethod} == 2) {
			visualDump($sendMsg, $switch . $label);
		} elsif ($config{debugPacket_include_dumpMethod} == 3) {
			dumpData($msg,1);
		}
	}

	Plugins::callHook('RO_sendMsg_pre', {switch => $switch, msg => $msg, realMsg => \$sendMsg});

	# If the player tries to manually do something in the RO client, disable AI for a small period
	# of time using ai_clientSuspend().

	my $hookname = "packet_outMangle/$switch";
	my $hook = $Plugins::hooks{$hookname}->[0];
	if ($hook && $hook->{r_func} &&
	    $hook->{r_func}($hookname, {switch => $switch, data => $sendMsg}, $hook->{user_data})) {
		undef $sendMsg;
	}

	if ($switch eq "0066") {
		# Login character selected
		configModify("char", unpack("C*",substr($msg, 2, 1)));

	} elsif ($switch eq "0072") {
		if ($config{serverType} == 0) {
			# Map login
			if ($config{'sex'} ne "") {
				$sendMsg = substr($sendMsg, 0, 18) . pack("C",$config{'sex'});
			}
		}

	} elsif ($switch eq "007D") {
		# Map loaded
		$conState = 5;
		AI::clear("clientSuspend");
		$timeout{'ai'}{'time'} = time;
		if ($firstLoginMap) {
			undef $sentWelcomeMessage;
			undef $firstLoginMap;
		}
		$timeout{'welcomeText'}{'time'} = time;
		$ai_v{portalTrace_mapChanged} = time;
		#syncSync support for XKore 1 mode
		if($config{serverType} == 11 || $config{serverType} == 12 || $config{serverType} == 13)
		{
			$syncSync = substr($msg, 5, 4);
		} 
		message T("Map loaded\n"), "connection";
		
		Plugins::callHook('map_loaded');

	} elsif ($switch eq "007E" && ($config{serverType} == 11 || $config{serverType} == 12 || $config{serverType} == 13)) {
		#syncSync support for XKore 1 mode
		$syncSync = substr($msg, length($msg) - 4, 4); 

	} elsif ($switch eq "0085") {
		#if ($config{serverType} == 0 || $config{serverType} == 1 || $config{serverType} == 2) {
		#	#Move
		#	AI::clear("clientSuspend");
		#	makeCoords(\%coords, substr($msg, 2, 3));
		#	ai_clientSuspend($switch, (distance($char->{'pos'}, \%coords) * $char->{walk_speed}) + 4);
		#}

	} elsif ($switch eq "0089") {
		if ($config{serverType} == 0) {
			# Attack
			if (!$config{'tankMode'} && !AI::inQueue("attack")) {
				AI::clear("clientSuspend");
				ai_clientSuspend($switch, 2, unpack("C*",substr($msg,6,1)), substr($msg,2,4));
			} else {
				undef $sendMsg;
			}
		}
		#undef $sendMsg;

	} elsif (($switch eq "008C" && $config{serverType} == 0) ||	# Public chat
		($switch eq "008C" && $config{serverType} == 1) ||
		($switch eq "008C" && $config{serverType} == 2) ||
		($switch eq "00F3" && $config{serverType} == 3) ||
		($switch eq "009F" && $config{serverType} == 4) ||
		($switch eq "00F3" && $config{serverType} == 5) ||
		($switch eq "008C" && $config{serverType} == 6) ||

		$switch eq "0108" ||	# Party chat

		$switch eq "017E") {	# Guild chat

		my $length = unpack("v",substr($msg,2,2));
		my $message = substr($msg, 4, $length - 4);
		my ($chat) = $message =~ /^[\s\S]*? : ([\s\S]*)\000?/;
		$chat =~ s/^\s*//;

		stripLanguageCode(\$chat);

		my $prefix = quotemeta $config{'commandPrefix'};
		if ($chat =~ /^$prefix/) {
			$chat =~ s/^$prefix//;
			$chat =~ s/^\s*//;
			$chat =~ s/\s*$//;
			$chat =~ s/\000*$//;
			parseInput($chat, 1);
			undef $sendMsg;
		}

	} elsif ($switch eq "0096") {
		# Private message
		my $length = unpack("v",substr($msg,2,2));
		my ($user) = substr($msg, 4, 24) =~ /([\s\S]*?)\000/;
		my $chat = substr($msg, 28, $length - 29);
		$chat =~ s/^\s*//;

		# Ensures: $user and $chat are String
		$user = I18N::bytesToString($user);
		$chat = I18N::bytesToString($chat);
		stripLanguageCode(\$chat);

		my $prefix = quotemeta $config{commandPrefix};
		if ($chat =~ /^$prefix/) {
			$chat =~ s/^$prefix//;
			$chat =~ s/^\s*//;
			$chat =~ s/\s*$//;
			parseInput($chat, 1);
			undef $sendMsg;
		} else {
			undef %lastpm;
			$lastpm{msg} = $chat;
			$lastpm{user} = $user;
			push @lastpm, {%lastpm};
		}

	} elsif (($switch eq "009B" && $config{serverType} == 0) ||
		($switch eq "009B" && $config{serverType} == 1) ||
		($switch eq "009B" && $config{serverType} == 2) ||
		($switch eq "0085" && $config{serverType} == 3) ||
		($switch eq "00F3" && $config{serverType} == 4) ||
		($switch eq "0085" && $config{serverType} == 5) ||
		#($switch eq "009B" && $config{serverType} == 6) || serverType 6 uses what?
		($switch eq "009B" && $config{serverType} == 7)) {
		# Look
		
		if ($config{serverType} == 0) {
			$char->{look}{head} = unpack("C", substr($msg, 2, 1));
			$char->{look}{body} = unpack("C", substr($msg, 4, 1));
		} elsif ($config{serverType} == 1 ||
			$config{serverType} == 2 ||
			$config{serverType} == 4 ||
			$config{serverType} == 7) {
			$char->{look}{head} = unpack("C", substr($msg, 6, 1));
			$char->{look}{body} = unpack("C", substr($msg, 14, 1));
		} elsif ($config{serverType} == 3) {
			$char->{look}{head} = unpack("C", substr($msg, 12, 1));
			$char->{look}{body} = unpack("C", substr($msg, 22, 1));
		} elsif ($config{serverType} == 5) {
			$char->{look}{head} = unpack("C", substr($msg, 8, 1));
			$char->{look}{body} = unpack("C", substr($msg, 16, 1));
		}	

	} elsif ($switch eq "009F") {
		if ($config{serverType} == 0) {
			# Take
			AI::clear("clientSuspend");
			ai_clientSuspend($switch, 2, substr($msg,2,4));
		}

	} elsif ($switch eq "00B2") {
		# Trying to exit (respawn)
		AI::clear("clientSuspend");
		ai_clientSuspend($switch, 10);

	} elsif ($switch eq "018A") {
		# Trying to exit
		AI::clear("clientSuspend");
		ai_clientSuspend($switch, 10);

	} elsif ($switch eq "0149") {
		# Chat/skill mute
		undef $sendMsg;

	} elsif ($switch eq "01B2") {
		# client started a shop manually
		$shopstarted = 1;
		
	} elsif ($switch eq "012E") {
		# client stopped shop manually
		$shopstarted = 0;
	}

	if ($sendMsg ne "") {
		$net->serverSend($sendMsg);
	}

	# This should be changed to packets that haven't been parsed yet, in a similar manner
	# as parseMsg
	return "";
}


#######################################
#######################################
#Parse Message
#######################################
#######################################



##
# Bytes parseMsg(Bytes msg)
# msg: The data to parse, as received from the socket.
# Returns: The remaining (unparsed) data.
#
# Parse network data sent by the RO server. Returns the remaining data that are not parsed.
sub parseMsg {
	my $msg = shift;
	my $msg_size;
	my $realMsg;
	
	# A packet is going to be at least 2 bytes long
	return $msg if (length($msg) < 2);

	# Determine packet switch
	my $switch = uc(unpack("H2", substr($msg, 1, 1))) . uc(unpack("H2", substr($msg, 0, 1)));
	if (length($msg) >= 4 && substr($msg,0,4) ne $accountID && $conState >= 4 && $lastswitch ne $switch
	 && length($msg) >= unpack("v1", substr($msg, 0, 2))) {
		# The decrypt below casued annoying unparsed errors (at least in serverType  2)
		if ($config{serverType} != 2) {
			decrypt(\$msg, $msg)
		}
	}
	$switch = uc(unpack("H2", substr($msg, 1, 1))) . uc(unpack("H2", substr($msg, 0, 1)));

	# The user is running in X-Kore mode and wants to switch character or gameGuard type 2 after 0259 tag 02.
	# We're now expecting an accountID, unless the server has replicated packet 0259 (server-side bug).
	if ($conState == 2.5 && (!$config{gameGuard} || ($switch ne '0259' && $config{gameGuard} eq "2"))) {
		if (length($msg) >= 4) {
			$conState = 2;
			$accountID = substr($msg, 0, 4);
			debug "Selecting character, new accountID: ".unpack("V", $accountID)."\n";
			$net->clientSend($accountID);
			return substr($msg, 4);
		} else {
			return $msg;
		}
	}

	$lastswitch = $switch;
	# Determine packet length using recvpackets.txt.
	if (substr($msg,0,4) ne $accountID || ($conState != 2 && $conState != 4)) {
		if ($rpackets{$switch} eq "-" || $switch eq "0070") {
			# Complete packet; the size of this packet is equal
			# to the size of the entire data
			$msg_size = length($msg);

		} elsif ($rpackets{$switch} eq "0") {
			# Variable length packet
			if (length($msg) < 4) {
				return $msg;
			}
			$msg_size = unpack("v1", substr($msg, 2, 2));
			if (length($msg) < $msg_size) {
				return $msg;
			}

		} elsif ($rpackets{$switch} > 1) {
			# Static length packet
			$msg_size = $rpackets{$switch};
			if (length($msg) < $msg_size) {
				return $msg;
			}

		} else {
			# Unknown packet - ignore it
			if (!existsInList($config{'debugPacket_exclude'}, $switch)) {
				warning TF("Unknown packet - %s\n", $switch), "connection";
				dumpData($msg) if ($config{'debugPacket_unparsed'});
			}

			# Pass it along to the client, whatever it is
			$net->clientSend($msg);
			
			Plugins::callHook('parseMsg/unknown', {switch => $switch, msg => $msg});
			return "";
		}
	}

	if ($config{debugPacket_received} && !existsInList($config{'debugPacket_exclude'}, $switch)) {
		my $label = $packetDescriptions{Recv}{$switch} ?
			" ($packetDescriptions{Recv}{$switch})" : '';
		if ($config{debugPacket_received} == 1) {
			debug "Packet: $switch$label\n", "parseMsg", 0;
		} else {
			visualDump(substr($msg, 0, $msg_size), "$switch$label");
		}
	}

	if ($config{debugPacket_include_dumpMethod} && existsInList($config{'debugPacket_include'}, $switch)) {
		my $label = $packetDescriptions{Recv}{$switch} ?
			" ($packetDescriptions{Recv}{$switch})" : '';
		if ($config{debugPacket_include_dumpMethod} == 1) {
			debug "Packet: $switch$label\n", "parseMsg", 0;
		} elsif ($config{debugPacket_include_dumpMethod} == 2) {
			visualDump(substr($msg, 0, $msg_size), "$switch$label");
		} else {
			dumpData($msg,1);
		}
	}

	Plugins::callHook('parseMsg/pre', {switch => $switch, msg => $msg, msg_size => $msg_size});

	if ($msg_size > 0 && !$packetParser->willMangle($switch)) {
		# Continue the message to the client
		$net->clientSend(substr($msg, 0, $msg_size));
	}

	$lastPacketTime = time;
	if ((substr($msg,0,4) eq $accountID && ($conState == 2 || $conState == 4))
	 || ($net->version == 1 && !$accountID && length($msg) == 4)) {
		$accountID = substr($msg, 0, 4);
		$AI = 2 if (!$AI_forcedOff);
		if ($config{'encrypt'} && $conState == 4) {
			my $encryptKey1 = unpack("V1", substr($msg, 6, 4));
			my $encryptKey2 = unpack("V1", substr($msg, 10, 4));
			my ($imult, $imult2);
			{
				use integer;
				$imult = (($encryptKey1 * $encryptKey2) + $encryptKey1) & 0xFF;
				$imult2 = ((($encryptKey1 * $encryptKey2) << 4) + $encryptKey2 + ($encryptKey1 * 2)) & 0xFF;
			}
			$encryptVal = $imult + ($imult2 << 8);
			$msg_size = 14;
		} else {
			$msg_size = 4;
		}
		debug "Received account ID\n", "parseMsg", 0 if ($config{debugPacket_received});
		
		# Continue the message to the client
		$net->clientSend(substr($msg, 0, $msg_size));

	} elsif ($packetParser &&
	         (my $args = $packetParser->parse(substr($msg, 0, $msg_size)))) {
		# Use the new object-oriented packet parser
		if ($config{debugPacket_received} > 2 &&
		    !existsInList($config{'debugPacket_exclude'}, $switch)) {
			my $switch = $args->{switch};
			my $packet = $packetParser->{packet_list}{$switch};
			my ($name, $packString, $varNames) = @{$packet};

			my @vars = ();
			for my $varName (@{$varNames}) {
				message "$varName = $args->{$varName}\n";
			}
		}

		if ($packetParser->willMangle($switch)) {
			my $ret = $packetParser->mangle($args);
			if (!$ret) {
				# Packet was not mangled
				$net->clientSend($args->{RAW_MSG});
			} elsif ($ret == 1) {
				# Packet was mangled
				$net->clientSend($packetParser->reconstruct($args));
			} else {
				# Packet was suppressed
			}
		}
	}
	$msg = (length($msg) >= $msg_size) ? substr($msg, $msg_size, length($msg) - $msg_size) : "";
	return $msg;
}

return 1;
