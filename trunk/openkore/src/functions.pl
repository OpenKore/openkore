# To run kore, execute openkore.pl instead.

#########################################################################
# This software is open source, licensed under the GNU General Public
# License, version 2.
# Basically, this means that you're allowed to modify and distribute
# this software. However, if you distribute modified versions, you MUST
# also distribute the source code.
# See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################

use Time::HiRes qw(time usleep);
use IO::Socket;
use Text::ParseWords;
use Config;
eval "no utf8;";
use bytes;

use Globals;
use Modules;
use Settings;
use Log qw(message warning error debug);
use FileParsers;
use Interface;
use Network;
use Network::Send;
use Commands;
use Misc;
use Plugins;
use Utils;


#######################################
#INITIALIZE VARIABLES
#######################################

# Calculate next random restart time.
# The restart time will be autoRestartMin + rand(autoRestartSeed)
sub initRandomRestart {
	if ($config{'autoRestart'}) {
		my $autoRestart = $config{'autoRestartMin'} + int(rand $config{'autoRestartSeed'});
		message "Next restart in ".timeConvert($autoRestart).".\n", "system";
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
	initMapChangeVars();
	undef %{$chars[$config{'char'}]{'skills'}};
	undef @skillsID;
	delete $chars[$config{'char'}]{'mute_period'};
	delete $chars[$config{'char'}]{'muted'};
	$useArrowCraft = 1;
}

# Initialize variables when you change map (after a teleport or after you walked into a portal)
sub initMapChangeVars {
	@portalsID_old = @portalsID;
	%portals_old = %portals;
	%{$chars_old[$config{'char'}]{'pos_to'}} = %{$chars[$config{'char'}]{'pos_to'}};
	undef $chars[$config{'char'}]{'sitting'};
	undef $chars[$config{'char'}]{'dead'};
	undef $chars[$config{'char'}]{'warp'};
	$timeout{play}{time} = time;
	$timeout{ai_sync}{time} = time;
	$timeout{ai_sit_idle}{time} = time;
	$timeout{ai_teleport}{time} = time;
	$timeout{ai_teleport_idle}{time} = time;
	$AI::Timeouts::teleSearch = time;
	$timeout{ai_teleport_safe_force}{time} = time;

	undef %incomingDeal;
	undef %outgoingDeal;
	undef %currentDeal;
	undef $currentChatRoom;
	undef @currentChatRoomUsers;
	undef @playersID;
	undef @monstersID;
	undef @portalsID;
	undef @itemsID;
	undef @npcsID;
	undef @identifyID;
	undef @spellsID;
	undef @petsID;
	undef @arrowCraftID;
	undef %players;
	undef %monsters;
	undef %portals;
	undef %items;
	undef %npcs;
	undef %spells;
	undef %incomingParty;
	undef $msg;
	undef %talk;
	undef %{$ai_v{'temp'}};
	undef @{$cart{'inventory'}};
	undef @{$chars[$config{'char'}]{'inventory'}};
	$ai_v{'inventory_time'} = time + 60;
	$ai_v{'cart_time'} = time + 60;
	undef @venderItemList;
	undef $venderID;
	undef @venderListsID;
	undef %venderLists;
	undef %guild;
	undef %incomingGuild;
	undef @unknownPlayers;
	undef @chatRoomsID;
	undef %chatRooms;
	undef @lastpm;

	$shopstarted = 0;
	$timeout{'ai_shop'}{'time'} = time;
	$timeout{'ai_storageAuto'}{'time'} = time + 5;
	$timeout{'ai_buyAuto'}{'time'} = time + 5;

	AI::clear("attack", "route", "move");
	ChatQueue::clear;

	initOtherVars();
	Plugins::callHook('packet_mapChange');
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
	undef $nextresptime;
	undef $nextrespPMtime;
	$timeout{ai_shop}{time} = $KoreStartTime;
	$useArrowCraft = 1;
}


#######################################
#######################################
#Check Connection
#######################################
#######################################


# $conState contains the connection state:
# 1: Not connected to anything		(next step -> connect to master server).
# 2: Connected to master server		(next step -> connect to login server)
# 3: Connected to login server		(next step -> connect to character server)
# 4: Connected to character server	(next step -> connect to map server)
# 5: Connected to map server; ready and functional.
#
# Special state:
# 2.5 (set by parseMsg()): Just passed character selection; next 4 bytes will be the account ID
sub checkConnection {
	return if ($config{'XKore'} || $Settings::no_connect);

	if ($conState == 1 && (!$remote_socket || !$remote_socket->connected) && timeOut($timeout_ex{'master'}) && !$conState_tries) {
		my $master = $masterServers{$config{'master'}};

		message("Connecting to Master Server...\n", "connection");
		$shopstarted = 1;
		$conState_tries++;
		undef $msg;
		Network::connectTo(\$remote_socket, $master->{ip}, $master->{port});

		if ($master->{secureLogin} >= 1) {
			message("Secure Login...\n", "connection");
			undef $secureLoginKey;
			if ($master->{secureLogin_requestCode} ne '') {
				sendMasterCodeRequest(\$remote_socket, 'code', $master->{secureLogin_requestCode});
			} else {
				sendMasterCodeRequest(\$remote_socket, 'type', $master->{secureLogin_type});
			}
		} else {
			sendMasterLogin(\$remote_socket, $config{'username'}, $config{'password'},
				$master->{master_version}, $master->{version});
		}

		$timeout{'master'}{'time'} = time;

	} elsif ($conState == 1 && $masterServers{$config{'master'}}{secureLogin} >= 1 && $secureLoginKey ne ""
	   && !timeOut($timeout{'master'}) && $conState_tries) {

		my $master = $masterServers{$config{'master'}};
		message("Sending encoded password...\n", "connection");
		sendMasterSecureLogin(\$remote_socket, $config{'username'}, $config{'password'}, $secureLoginKey,
				$master->{version}, $master->{master_version},
				$master->{secureLogin}, $master->{secureLogin_account});
		undef $secureLoginKey;

	} elsif ($conState == 1 && timeOut($timeout{'master'}) && timeOut($timeout_ex{'master'})) {
		error "Timeout on Master Server, reconnecting...\n", "connection";
		$timeout_ex{'master'}{'time'} = time;
		$timeout_ex{'master'}{'timeout'} = $timeout{'reconnect'}{'timeout'};
		Network::disconnect(\$remote_socket);
		undef $conState_tries;

	} elsif ($conState == 2 && !($remote_socket && $remote_socket->connected()) && $config{'server'} ne "" && !$conState_tries) {
		message("Connecting to Game Login Server...\n", "connection");
		$conState_tries++;
		Network::connectTo(\$remote_socket, $servers[$config{'server'}]{'ip'}, $servers[$config{'server'}]{'port'});
		sendGameLogin(\$remote_socket, $accountID, $sessionID, $sessionID2, $accountSex);
		$timeout{'gamelogin'}{'time'} = time;

	} elsif ($conState == 2 && timeOut($timeout{'gamelogin'}) && $config{'server'} ne "") {
		error "Timeout on Game Login Server, reconnecting...\n", "connection";
		$timeout_ex{'master'}{'time'} = time;
		$timeout_ex{'master'}{'timeout'} = $timeout{'reconnect'}{'timeout'};
		Network::disconnect(\$remote_socket);
		undef $conState_tries;
		$conState = 1;

	} elsif ($conState == 3 && !($remote_socket && $remote_socket->connected()) && $config{'char'} ne "" && !$conState_tries) {
		message("Connecting to Character Select Server...\n", "connection");
		$conState_tries++;
		Network::connectTo(\$remote_socket, $servers[$config{'server'}]{'ip'}, $servers[$config{'server'}]{'port'});
		sendCharLogin(\$remote_socket, $config{'char'});
		$timeout{'charlogin'}{'time'} = time;

	} elsif ($conState == 3 && timeOut(\%{$timeout{'charlogin'}}) && $config{'char'} ne "") {
		error "Timeout on Character Select Server, reconnecting...\n", "connection";
		$timeout_ex{'master'}{'time'} = time;
		$timeout_ex{'master'}{'timeout'} = $timeout{'reconnect'}{'timeout'};
		Network::disconnect(\$remote_socket);
		$conState = 1;
		undef $conState_tries;

	} elsif ($conState == 4 && !($remote_socket && $remote_socket->connected()) && !$conState_tries) {
		sleep($config{pauseMapServer}) if ($config{pauseMapServer});
		message("Connecting to Map Server...\n", "connection");
		$conState_tries++;
		initConnectVars();
		Network::connectTo(\$remote_socket, $map_ip, $map_port);
		if ($config{'pkServer'}) {
			sendPkMapLogin(\$remote_socket, $accountID, $sessionID, $accountSex2);
		} else {
			sendMapLogin(\$remote_socket, $accountID, $charID, $sessionID, $accountSex2);
		}
		$timeout_ex{'master'}{'timeout'} = $timeout{'reconnect'}{'timeout'};
		$timeout{'maplogin'}{'time'} = time;

	} elsif ($conState == 4 && timeOut($timeout{'maplogin'})) {
		message("Timeout on Map Server, connecting to Master Server...\n", "connection");
		$timeout_ex{'master'}{'time'} = time;
		$timeout_ex{'master'}{'timeout'} = $timeout{'reconnect'}{'timeout'};
		Network::disconnect(\$remote_socket);
		$conState = 1;
		undef $conState_tries;

	} elsif ($conState == 5 && !($remote_socket && $remote_socket->connected())) {
		error "Disconnected from Map Server, ", "connection";
		if ($config{dcOnDisconnect}) {
			error "exiting...\n", "connection";
			$quit = 1;
		} else {
			error "connecting to Master Server...\n", "connection";
			$conState = 1;
			undef $conState_tries;
		}

	} elsif ($conState == 5 && timeOut(\%{$timeout{'play'}})) {
		error "Timeout on Map Server, ", "connection";
		if ($config{dcOnDisconnect}) {
			error "exiting...\n", "connection";
			$quit = 1;
		} else {
			error "connecting to Master Server...\n", "connection";
			$timeout_ex{'master'}{'time'} = time;
			$timeout_ex{'master'}{'timeout'} = $timeout{'reconnect'}{'timeout'};
			Network::disconnect(\$remote_socket);
			$conState = 1;
			undef $conState_tries;
		}
	}
}

sub mainLoop {
	Plugins::callHook('mainLoop_pre');

	if ($xkore && !$xkore->alive) {
		# (Re-)initialize X-Kore if necessary
		$conState = 1;
		my $printed;
		my $pid;
		# Wait until the RO client has started
		while (!($pid = WinUtils::GetProcByName($config{exeName}))) {
			message("Please start the Ragnarok Online client ($config{exeName})\n", "startup") unless $printed;
			$printed = 1;
			$interface->iterate;
			if (defined($input = $interface->getInput(0))) {
				if ($input eq "quit") {
					$quit = 1;
					last;
				} else {
					message("Error: You cannot type anything except 'quit' right now.\n");
				}
			}
			usleep 20000;
			last if $quit;
		}
		return if $quit;

		# Inject DLL
		message("Ragnarok Online client found\n", "startup");
		sleep 1 if $printed;
		if (!$xkore->inject($pid)) {
			# Failed to inject
			$interface->errorDialog($@);
			exit 1;
		}

		# Wait until the RO client has connected to us
		$remote_socket = $xkore->waitForClient;
		message("You can login with the Ragnarok Online client now.\n", "startup");
		$timeout{'injectSync'}{'time'} = time;
	}

	# Parse command input
	my $input;
	if (defined($input = $interface->getInput(0))) {
		parseInput($input);
	}

	# Receive and handle data from the RO server
	if ($xkore) {
		my $injectMsg = $xkore->recv;
		while ($injectMsg ne "") {
			if (length($injectMsg) < 3) {
				undef $injectMsg;
				return;
			}

			my $type = substr($injectMsg, 0, 1);
			my $len = unpack("S",substr($injectMsg, 1, 2));
			my $newMsg = substr($injectMsg, 3, $len);
			$injectMsg = (length($injectMsg) >= $len+3) ? substr($injectMsg, $len+3, length($injectMsg) - $len - 3) : "";

			if ($type eq "R") {
				$msg .= $newMsg;
				$msg_length = length($msg);
				while ($msg ne "") {
					$msg = parseMsg($msg);
					last if ($msg_length == length($msg));
					$msg_length = length($msg);
				}
			} elsif ($type eq "S") {
				parseSendMsg($newMsg);
			}
		}
		
		if (timeOut($timeout{'injectSync'})) {
			$xkore->sync;
			$timeout{'injectSync'}{'time'} = time;
		}

	} elsif (dataWaiting(\$remote_socket)) {
		$remote_socket->recv($new, $Settings::MAX_READ);
		$msg .= $new;
		$msg_length = length($msg);
		while ($msg ne "") {
			$msg = parseMsg($msg);
			return if ($msg_length == length($msg));
			$msg_length = length($msg);
		}
	}

	# Process AI
	if ($conState == 5 && timeOut($timeout{ai}) && $remote_socket && $remote_socket->connected) {
		AI($ai_cmdQue[$i]);
		return if $quit;
	}

	# Handle connection states
	checkConnection();

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
		message "\nAuto-restarting!!\n", "system";

		if ($config{'autoRestartSleep'}) {
			my $sleeptime = $config{'autoSleepMin'} + int(rand $config{'autoSleepSeed'});
			$timeout_ex{'master'}{'timeout'} = $sleeptime;
			$sleeptime = $timeout{'reconnect'}{'timeout'} if ($sleeptime < $timeout{'reconnect'}{'timeout'});
			message "Sleeping for ".timeConvert($sleeptime).".\n", "system";
		} else {
			$timeout_ex{'master'}{'timeout'} = $timeout{'reconnect'}{'timeout'};
		}

		$timeout_ex{'master'}{'time'} = time;
		$KoreStartTime = time + $timeout_ex{'master'}{'timeout'};
		AI::clear();
		undef %ai_v;
		Network::disconnect(\$remote_socket);
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
			message "Changing configuration file (from \"$Settings::config_file\" to \"$file\")...\n", "system";

			# A relogin is necessary if the host/port, username or char is different
			my $oldMaster = $masterServers{$config{'master'}};
			my $oldUsername = $config{'username'};
			my $oldChar = $config{'char'};

			switchConfigFile($file);

			my $master = $masterServers{$config{'master'}};
			if (!$xkore
			 && $oldMaster->{ip} ne $master->{ip}
			 || $oldMaster->{port} ne $master->{port}
			 || $oldMaster->{master_version} ne $master->{master_version}
			 || $oldMaster->{version} ne $master->{version}
			 || $oldUsername ne $config{'username'}
			 || $oldChar ne $config{'char'}) {
				AI::clear;
				relog();
			} else {
				AI::clear("move", "route", "mapRoute");
			}

			initConfChange();
		}

		$AI::Timeouts::autoConfChangeTime = time;
	}

	# Set interface title
	my $charName = $chars[$config{'char'}]{'name'};
	$charName .= ': ' if defined $charName;
	if ($conState == 5) {
		my ($title, $basePercent, $jobPercent, $weight, $pos);

		$basePercent = sprintf("%.2f", $chars[$config{'char'}]{'exp'} / $chars[$config{'char'}]{'exp_max'} * 100) if $chars[$config{'char'}]{'exp_max'};
		$jobPercent = sprintf("%.2f", $chars[$config{'char'}]{'exp_job'} /$ chars[$config{'char'}]{'exp_job_max'} * 100) if $chars[$config{'char'}]{'exp_job_max'};
		$weight = int($chars[$config{'char'}]{'weight'} / $chars[$config{'char'}]{'weight_max'} * 100) . "%" if $chars[$config{'char'}]{'weight_max'};
		$pos = " : $char->{pos_to}{x},$char->{pos_to}{y} $field{'name'}" if ($char->{pos_to} && $field{'name'});

		$title = "${charName} B$chars[$config{'char'}]{'lv'} ($basePercent%), J$chars[$config{'char'}]{'lv_job'}($jobPercent%) : w$weight${pos} - $Settings::NAME";
		$interface->title($title);

	} elsif ($conState == 1) {
		$interface->title("${charName}Not connected - $Settings::NAME");
	} else {
		$interface->title("${charName}Connecting - $Settings::NAME");
	}

	Plugins::callHook('mainLoop_post');

	# Reload any modules that requested to be reloaded
	Modules::doReload();
}


#######################################
#PARSE INPUT
#######################################


sub parseInput {
	my $input = shift;
	my $printType;
	my ($hook, $msg);
	$printType = shift if ($config{'XKore'});

	debug("Input: $input\n", "parseInput", 2);

	if ($printType) {
		my $hookOutput = sub {
			my ($type, $domain, $level, $globalVerbosity, $message, $user_data) = @_;
			$msg .= $message if ($type ne 'debug' && $level <= $globalVerbosity);
		};
		$hook = Log::addHook($hookOutput);
		$interface->writeOutput("console", "$input\n");
	}
	$XKore_dontRedirect = 1 if ($config{XKore});

	# Check if in special state
	if (!$xkore && $conState == 2 && $waitingForInput) {
		configModify('server', $input, 1);
		$waitingForInput = 0;

	} else {
		Commands::run($input) || parseCommand($input);
	}

	if ($printType) {
		Log::delHook($hook);
		if ($config{'XKore'} && defined $msg && $conState == 5) {
			$msg =~ s/\n*$//s;
			$msg =~ s/\n/\\n/g;
			sendMessage(\$remote_socket, "k", $msg);
		}
	}
	$XKore_dontRedirect = 0 if ($config{XKore});
}

sub parseCommand {
	my $input = shift;

	my ($switch, $args) = split(' ', $input, 2);
	my ($arg1, $arg2, $arg3, $arg4);

	# Resolve command aliases
	if (my $alias = $config{"alias_$switch"}) {
		$input = $alias;
		$input .= " $args" if defined $args;
		($switch, $args) = split(' ', $input, 2);
	}

	if ($switch eq "a") {
		($arg1) = $input =~ /^[\s\S]*? (\w+)/;
		($arg2) = $input =~ /^[\s\S]*? [\s\S]*? (\d+)/;
		if ($arg1 =~ /^\d+$/ && $monstersID[$arg1] eq "") {
			error	"Error in function 'a' (Attack Monster)\n" .
				"Monster $arg1 does not exist.\n";
		} elsif ($arg1 =~ /^\d+$/) {
			attack($monstersID[$arg1]);

		} elsif ($arg1 eq "no") {
			configModify("attackAuto", 1);
		
		} elsif ($arg1 eq "yes") {
			configModify("attackAuto", 2);

		} else {
			error	"Syntax Error in function 'a' (Attack Monster)\n" .
				"Usage: attack <monster # | no | yes >\n";
		}

	} elsif ($switch eq "al") {
		if (!$shopstarted) {
			error("You do not have a shop open.\n");
			return;
		}
		# FIXME: Read the packet the server sends us to determine
		# the shop title instead of using $shop{title}.
		message(center(" $shop{title} ", 79, '-')."\n", "list");
		message("#  Name                                     Type         Qty     Price   Sold\n", "list");

		my $priceAfterSale=0;
		my $i = 1;
		for my $item (@articles) {
			next unless $item;
			message(swrite(
				"@< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<< @>>> @>>>>>>>z @>>>>>",
				[$i++, $item->{name}, $itemTypes_lut{$item->{type}}, $item->{quantity}, $item->{price}, $item->{sold}]),
				"list");
			$priceAfterSale += ($item->{quantity} * $item->{price});
		}
		message(('-'x79)."\n", "list");
		message("You have earned: " . formatNumber($shopEarned) . "z.\n", "list");
		message("Current zeny:    " . formatNumber($chars[$config{'char'}]{'zenny'}) . "z.\n", "list");
		message("Maximum earned:  " . formatNumber($priceAfterSale) . "z.\n", "list");
		message("Maximum zeny:   " . formatNumber($priceAfterSale + $chars[$config{'char'}]{'zenny'}) . "z.\n", "list");
	} elsif ($switch eq "as") {
		# Stop attacking monster
		my $index = binFind(\@ai_seq, "attack");
		if ($index ne "") {
			$monsters{$ai_seq_args[$index]{'ID'}}{'ignore'} = 1;
			stopAttack();
			message "Stopped attacking $monsters{$ai_seq_args[$index]{'ID'}}{'name'} ($monsters{$ai_seq_args[$index]{'ID'}}{'binID'})\n", "success";
			aiRemove("attack");
		}

	} elsif ($switch eq "autobuy") {
		message "Initiating auto-buy.\n";
		AI::queue("buyAuto");

	} elsif ($switch eq "autosell") {
		message "Initiating auto-sell.\n";
		AI::queue("sellAuto");

	} elsif ($switch eq "autostorage") {
		message "Initiating auto-storage.\n";
		AI::queue("storageAuto");

	} elsif ($switch eq "c") {
		($arg1) = $input =~ /^[\s\S]*? ([\s\S]*)/;
		if ($arg1 eq "") {
			error	"Syntax Error in function 'c' (Chat)\n" .
				"Usage: c <message>\n";
		} else {
			sendMessage(\$remote_socket, "c", $arg1);
		}

	} elsif ($switch eq "chat") {
		my ($replace, $title) = $input =~ /(^[\s\S]*? \"([\s\S]*?)\" ?)/;
		my $qm = quotemeta $replace;
		my $args = $input;
		$args =~ s/$qm//;
		my @arg = split / /, $args;
		if ($title eq "") {
			error	"Syntax Error in function 'chat' (Create Chat Room)\n" .
				"Usage: chat \"<title>\" [<limit #> <public flag> <password>]\n";
		} elsif ($currentChatRoom ne "") {
			error	"Error in function 'chat' (Create Chat Room)\n" .
				"You are already in a chat room.\n";
		} else {
			if ($arg[0] eq "") {
				$arg[0] = 20;
			}
			if ($arg[1] eq "") {
				$arg[1] = 1;
			}
			$title = ($config{chatTitleOversize}) ? $title : substr($title,0,36);
			sendChatRoomCreate(\$remote_socket, $title, $arg[0], $arg[1], $arg[2]);
			$createdChatRoom{'title'} = $title;
			$createdChatRoom{'ownerID'} = $accountID;
			$createdChatRoom{'limit'} = $arg[0];
			$createdChatRoom{'public'} = $arg[1];
			$createdChatRoom{'num_users'} = 1;
			$createdChatRoom{'users'}{$chars[$config{'char'}]{'name'}} = 2;
		}

	} elsif ($switch eq "cil") { 
		itemLog_clear();
		message("Item log cleared.\n", "success");

	} elsif ($switch eq "cl") { 
		chatLog_clear();
		message("Chat log cleared.\n", "success");

	#non-functional item count code
	} elsif ($switch eq "icount") {
		message("-[ Item Count ]--------------------------------\n", "list");
		message("#   ID   Name                Count\n", "list");
		my $i = 0;
		while ($pickup_count[$i]) {
			message(swrite(
				"@<< @<<<< @<<<<<<<<<<<<<       @<<<",
				[$i, $pickup_count[$i]{'nameID'}, $pickup_count[$i]{'name'}, $pickup_count[$i]{'count'}]),
				"list");
			$i++;
		}
		message("--------------------------------------------------\n", "list");
	#end of non-functional item count code

	} elsif ($switch eq "cri") {
		if ($currentChatRoom eq "") {
			error "There is no chat room info - you are not in a chat room\n";
		} else {
			message("-----------Chat Room Info-----------\n" .
				"Title                     Users   Public/Private\n",
				"list");
			my $public_string = ($chatRooms{$currentChatRoom}{'public'}) ? "Public" : "Private";
			my $limit_string = $chatRooms{$currentChatRoom}{'num_users'}."/".$chatRooms{$currentChatRoom}{'limit'};

			message(swrite(
				"@<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<< @<<<<<<<<<",
				[$chatRooms{$currentChatRoom}{'title'}, $limit_string, $public_string]),
				"list");

			message("-- Users --\n", "list");
			for (my $i = 0; $i < @currentChatRoomUsers; $i++) {
				next if ($currentChatRoomUsers[$i] eq "");
				my $user_string = $currentChatRoomUsers[$i];
				my $admin_string = ($chatRooms{$currentChatRoom}{'users'}{$currentChatRoomUsers[$i]} > 1) ? "(Admin)" : "";
				message(swrite(
					"@<< @<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<",
					[$i, $user_string, $admin_string]),
					"list");
			}
			message("------------------------------------\n", "list");
		}

	} elsif ($switch eq "crl") {
		message("-----------Chat Room List-----------\n" .
			"#   Title                     Owner                Users   Public/Private\n",
			"list");
		for (my $i = 0; $i < @chatRoomsID; $i++) {
			next if ($chatRoomsID[$i] eq "");
			my $owner_string = ($chatRooms{$chatRoomsID[$i]}{'ownerID'} ne $accountID) ? $players{$chatRooms{$chatRoomsID[$i]}{'ownerID'}}{'name'} : $chars[$config{'char'}]{'name'};
			my $public_string = ($chatRooms{$chatRoomsID[$i]}{'public'}) ? "Public" : "Private";
			my $limit_string = $chatRooms{$chatRoomsID[$i]}{'num_users'}."/".$chatRooms{$chatRoomsID[$i]}{'limit'};
			message(swrite(
				"@<< @<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<          @<<<<<< @<<<<<<<<<",
				[$i, $chatRooms{$chatRoomsID[$i]}{'title'}, $owner_string, $limit_string, $public_string]),
				"list");
		}
		message("------------------------------------\n", "list");

	} elsif ($switch eq "vl") {
		message("-----------Vender List-----------\n" .
			"#   Title                                Coords     Owner\n",
			"list");
		for (my $i = 0; $i < @venderListsID; $i++) {
			next if ($venderListsID[$i] eq "");
			my $player = $venderListsID[$i] eq $accountID ?
				$char :
				$players{$venderListsID[$i]};
			message(sprintf(
				"%3d %-36s (%3d, %3d) %-20s\n",
				$i, $venderLists{$venderListsID[$i]}{'title'}, 
				$player->{pos_to}{x}, $player->{pos_to}{y}, $player->{name}),
				"list");
		}
		message("----------------------------------\n", "list");

	} elsif ($switch eq "vender") {
		 ($arg1) = $input =~ /^.*? ([\d\w]+)/;
		($arg2) = $input =~ /^.*? [\d\w]+ (\d+)/;
		($arg3) = $input =~ /^.*? [\d\w]+ \d+ (\d+)/;
		if ($arg1 eq "") {
			error	"Error in function 'vender' (Vender Shop)\n" .
				"Usage: vender <vender # | end> [<item #> <amount>]\n";
		} elsif ($arg1 eq "end") {
			undef @venderItemList;
			undef $venderID;
		} elsif ($venderListsID[$arg1] eq "") {
			error	"Error in function 'vender' (Vender Shop)\n" .
				"Vender $arg1 does not exist.\n";
		} elsif ($arg2 eq "") {
			sendEnteringVender(\$remote_socket, $venderListsID[$arg1]);
		} elsif ($venderListsID[$arg1] ne $venderID) {
			error	"Error in function 'vender' (Vender Shop)\n" .
				"Vender ID is wrong.\n";
		} else {
			if ($arg3 <= 0) {
				$arg3 = 1;
			}
			sendBuyVender(\$remote_socket, $venderID, $arg2, $arg3);
		}

	} elsif ($switch eq "deal") {
		@arg = split / /, $input;
		shift @arg;
		if (%currentDeal && $arg[0] =~ /\d+/) {
			error	"Error in function 'deal' (Deal a Player)\n" .
				"You are already in a deal\n";
		} elsif (%incomingDeal && $arg[0] =~ /\d+/) {
			error	"Error in function 'deal' (Deal a Player)\n" .
				"You must first cancel the incoming deal\n";
		} elsif ($arg[0] =~ /\d+/ && !$playersID[$arg[0]]) {
			error	"Error in function 'deal' (Deal a Player)\n" .
				"Player $arg[0] does not exist\n";
		} elsif ($arg[0] =~ /\d+/) {
			message "Attempting to deal ".getActorName($playersID[$arg[0]])."\n";
			$outgoingDeal{'ID'} = $playersID[$arg[0]];
			sendDeal(\$remote_socket, $playersID[$arg[0]]);

		} elsif ($arg[0] eq "no" && !%incomingDeal && !%outgoingDeal && !%currentDeal) {
			error	"Error in function 'deal' (Deal a Player)\n" .
				"There is no incoming/current deal to cancel\n";
		} elsif ($arg[0] eq "no" && (%incomingDeal || %outgoingDeal)) {
			sendDealCancel(\$remote_socket);
		} elsif ($arg[0] eq "no" && %currentDeal) {
			sendCurrentDealCancel(\$remote_socket);


		} elsif ($arg[0] eq "" && !%incomingDeal && !%currentDeal) {
			error	"Error in function 'deal' (Deal a Player)\n" .
				"There is no deal to accept\n";
		} elsif ($arg[0] eq "" && $currentDeal{'you_finalize'} && !$currentDeal{'other_finalize'}) {
			error	"Error in function 'deal' (Deal a Player)\n" .
				"Cannot make the trade - $currentDeal{'name'} has not finalized\n";
		} elsif ($arg[0] eq "" && $currentDeal{'final'}) {
			error	"Error in function 'deal' (Deal a Player)\n" .
				"You already accepted the final deal\n";
		} elsif ($arg[0] eq "" && %incomingDeal) {
			sendDealAccept(\$remote_socket);
		} elsif ($arg[0] eq "" && $currentDeal{'you_finalize'} && $currentDeal{'other_finalize'}) {
			sendDealTrade(\$remote_socket);
			$currentDeal{'final'} = 1;
			message("You accepted the final Deal\n", "deal");
		} elsif ($arg[0] eq "" && %currentDeal) {
			sendDealAddItem(\$remote_socket, 0, $currentDeal{'you_zenny'});
			sendDealFinalize(\$remote_socket);
			

		} elsif ($arg[0] eq "add" && !%currentDeal) {
			error	"Error in function 'deal_add' (Add Item to Deal)\n" .
				"No deal in progress\n";
		} elsif ($arg[0] eq "add" && $currentDeal{'you_finalize'}) {
			error	"Error in function 'deal_add' (Add Item to Deal)\n" .
				"Can't add any Items - You already finalized the deal\n";
		} elsif ($arg[0] eq "add" && $arg[1] =~ /\d+/ && !%{$chars[$config{'char'}]{'inventory'}[$arg[1]]}) {
			error	"Error in function 'deal_add' (Add Item to Deal)\n" .
				"Inventory Item $arg[1] does not exist.\n";
		} elsif ($arg[0] eq "add" && $arg[2] && $arg[2] !~ /\d+/) {
			error	"Error in function 'deal_add' (Add Item to Deal)\n" .
				"Amount must either be a number, or not specified.\n";
		} elsif ($arg[0] eq "add" && $arg[1] =~ /\d+/) {
			if ($currentDeal{you_items} < 10) {
				if (!$arg[2] || $arg[2] > $chars[$config{'char'}]{'inventory'}[$arg[1]]{'amount'}) {
					$arg[2] = $chars[$config{'char'}]{'inventory'}[$arg[1]]{'amount'};
				}
				$currentDeal{'lastItemAmount'} = $arg[2];
				sendDealAddItem(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$arg[1]]{'index'}, $arg[2]);
			} else {
				error("You can't add any more items to the deal\n", "deal");
			}
		} elsif ($arg[0] eq "add" && $arg[1] eq "z") {
			if (!$arg[2] || $arg[2] > $chars[$config{'char'}]{'zenny'}) {
				$arg[2] = $chars[$config{'char'}]{'zenny'};
			}
			$currentDeal{'you_zenny'} = $arg[2];
			message("You put forward $arg[2] z to Deal\n", "deal");

		} else {
			error	"Syntax Error in function 'deal' (Deal a player)\n" .
				"Usage: deal [<Player # | no | add>] [<item #>] [<amount>]\n";
		}

	} elsif ($switch eq "dl") {
		if (!%currentDeal) {
			error "There is no deal list - You are not in a deal\n";

		} else {
			message("-----------Current Deal-----------\n", "list");
			my $other_string = $currentDeal{'name'};
			my $you_string = "You";
			if ($currentDeal{'other_finalize'}) {
				$other_string .= " - Finalized";
			}
			if ($currentDeal{'you_finalize'}) {
				$you_string .= " - Finalized";
			}

			message(swrite(
				"@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<   @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<",
				[$you_string, $other_string]),
				"list");

			undef @currentDealYou;
			undef @currentDealOther;
			foreach (keys %{$currentDeal{'you'}}) {
				push @currentDealYou, $_;
			}
			foreach (keys %{$currentDeal{'other'}}) {
				push @currentDealOther, $_;
			}

			my ($lastindex, $display);
			$lastindex = @currentDealOther;
			$lastindex = @currentDealYou if (@currentDealYou > $lastindex);
			for (my $i = 0; $i < $lastindex; $i++) {
				if ($i < @currentDealYou) {
					$display = ($items_lut{$currentDealYou[$i]} ne "") 
						? $items_lut{$currentDealYou[$i]}
						: "Unknown ".$currentDealYou[$i];
					$display .= " x $currentDeal{'you'}{$currentDealYou[$i]}{'amount'}";
				} else {
					$display = "";
				}
				if ($i < @currentDealOther) {
					$display2 = ($items_lut{$currentDealOther[$i]} ne "") 
						? $items_lut{$currentDealOther[$i]}
						: "Unknown ".$currentDealOther[$i];
					$display2 .= " x $currentDeal{'other'}{$currentDealOther[$i]}{'amount'}";
				} else {
					$display2 = "";
				}

				message(swrite(
					"@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<   @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<",
					[$display, $display2]),
					"list");
			}
			$you_string = ($currentDeal{'you_zenny'} ne "") ? $currentDeal{'you_zenny'} : 0;
			$other_string = ($currentDeal{'other_zenny'} ne "") ? $currentDeal{'other_zenny'} : 0;

			message(swrite(
				"Zenny: @<<<<<<<<<<<<<            Zenny: @<<<<<<<<<<<<<",
				[$you_string, $other_string]),
				"list");
			message("----------------------------------\n", "list");
		}


	} elsif ($switch eq "drop") {
		($arg1) = $input =~ /^[\s\S]*? ([\d,-]+)/;
		($arg2) = $input =~ /^[\s\S]*? [\d,-]+ (\d+)$/;
		if ($arg1 eq "") {
			error	"Syntax Error in function 'drop' (Drop Inventory Item)\n" .
				"Usage: drop <item #> [<amount>]\n";
		} elsif (!%{$chars[$config{'char'}]{'inventory'}[$arg1]}) {
			error	"Error in function 'drop' (Drop Inventory Item)\n" .
				"Inventory Item $arg1 does not exist.\n";
		} else {
			my @temp = split(/,/, $arg1);
			@temp = grep(!/^$/, @temp); # Remove empty entries

			my @items = ();
			foreach (@temp) {
				if (/(\d+)-(\d+)/) {
					for ($1..$2) {
						push(@items, $_) if (%{$chars[$config{'char'}]{'inventory'}[$_]});
					}
				} else {
					push @items, $_;
				}
			}
			ai_drop(\@items, $arg2);
		}

	} elsif ($switch eq "dump") {
		dumpData($msg);
		quit();

	} elsif ($switch eq "dumpnow") {
		dumpData($msg);

	} elsif ($switch eq "exp" || $switch eq "count") {
		# exp report
		($arg1) = $input =~ /^[\s\S]*? (\w+)/;
		if ($arg1 eq ""){
			my ($endTime_EXP,$w_sec,$total,$bExpPerHour,$jExpPerHour,$EstB_sec,$EstB_sec,$percentB,$percentJ);
			$endTime_EXP = time;
			$w_sec = int($endTime_EXP - $startTime_EXP);
			if ($w_sec > 0) {
				$zennyMade = $chars[$config{'char'}]{'zenny'} - $startingZenny;
				$bExpPerHour = int($totalBaseExp / $w_sec * 3600);
				$jExpPerHour = int($totalJobExp / $w_sec * 3600);
				$zennyPerHour = int($zennyMade / $w_sec * 3600);
				if ($chars[$config{'char'}]{'exp_max'} && $bExpPerHour){
					$percentB = "(".sprintf("%.2f",$totalBaseExp * 100 / $chars[$config{'char'}]{'exp_max'})."%)";
					$percentBhr = "(".sprintf("%.2f",$bExpPerHour * 100 / $chars[$config{'char'}]{'exp_max'})."%)";
					$EstB_sec = int(($chars[$config{'char'}]{'exp_max'} - $chars[$config{'char'}]{'exp'})/($bExpPerHour/3600));
				}
				if ($chars[$config{'char'}]{'exp_job_max'} && $jExpPerHour){
					$percentJ = "(".sprintf("%.2f",$totalJobExp * 100 / $chars[$config{'char'}]{'exp_job_max'})."%)";
					$percentJhr = "(".sprintf("%.2f",$jExpPerHour * 100 / $chars[$config{'char'}]{'exp_job_max'})."%)";
					$EstJ_sec = int(($chars[$config{'char'}]{'exp_job_max'} - $chars[$config{'char'}]{'exp_job'})/($jExpPerHour/3600));
				}
			}
			$chars[$config{'char'}]{'deathCount'} = 0 if (!defined $chars[$config{'char'}]{'deathCount'});
			message("------------Exp Report------------\n" .
			"Botting time : " . timeConvert($w_sec) . "\n" .
			"BaseExp      : " . formatNumber($totalBaseExp) . " $percentB\n" .
			"JobExp       : " . formatNumber($totalJobExp) . " $percentJ\n" .
			"BaseExp/Hour : " . formatNumber($bExpPerHour) . " $percentBhr\n" .
			"JobExp/Hour  : " . formatNumber($jExpPerHour) . " $percentJhr\n" .
			"Zenny        : " . formatNumber($zennyMade) . "\n" .
			"Zenny/Hour   : " . formatNumber($zennyPerHour) . "\n" .
			"Base Levelup Time Estimation : " . timeConvert($EstB_sec) . "\n" .
			"Job Levelup Time Estimation  : " . timeConvert($EstJ_sec) . "\n" .
			"Died : $chars[$config{'char'}]{'deathCount'}\n", "info");

			message("-[Monster Killed Count]-----------\n" .
				"#   ID   Name                Count\n",
				"list");
			for (my $i = 0; $i < @monsters_Killed; $i++) {
				next if ($monsters_Killed[$i] eq "");
				message(swrite(
					"@<< @<<<< @<<<<<<<<<<<<<       @<<< ",
					[$i, $monsters_Killed[$i]{'nameID'}, $monsters_Killed[$i]{'name'}, $monsters_Killed[$i]{'count'}]),
					"list");
				$total += $monsters_Killed[$i]{'count'};
			}
			message("----------------------------------\n" .
				"Total number of killed monsters: $total\n" .
				"----------------------------------\n",
				"list");

		} elsif ($arg1 eq "reset") {
			($bExpSwitch,$jExpSwitch,$totalBaseExp,$totalJobExp) = (2,2,0,0);
			$startTime_EXP = time;
			$startingZenny = $char->{zenny};
			undef @monsters_Killed;
			message "Exp counter reset.\n", "success";
		} else {
			error "Error in function 'exp' (Exp Report)\n" .
				"Usage: exp [reset]\n";
		}
		
	} elsif ($switch eq "follow") {
		($arg1) = $input =~ /^[\s\S]*? (.+) *$/;
		if ($arg1 eq "") {
			error	"Syntax Error in function 'follow' (Follow Player)\n" .
				"Usage: follow <player #>\n";
		} elsif ($arg1 eq "stop") {
			aiRemove("follow");
			configModify("follow", 0);

		} elsif ($arg1 =~ /^\d+$/) {
			if (!$playersID[$arg1]) {
				error	"Error in function 'follow' (Follow Player)\n" .
					"Player $arg1 either not visible or not online in party.\n";
			} else {
				aiRemove("follow");
				ai_follow($players{$playersID[$arg1]}{name});
				configModify("follow", 1);
				configModify("followTarget", $players{$playersID[$arg1]}{name});
			}

		} else {
			aiRemove("follow");
			ai_follow($arg1);
			configModify("follow", 1);
			configModify("followTarget", $arg1);
		}

	#Guild Chat - chobit andy 20030101
	} elsif ($switch eq "g") {
		($arg1) = $input =~ /^[\s\S]*? ([\s\S]*)/;
		if ($arg1 eq "") {
			error 	"Syntax Error in function 'g' (Guild Chat)\n" .
				"Usage: g <message>\n";
		} else {
			sendMessage(\$remote_socket, "g", $arg1);
		}

	} elsif ($switch eq "identify") {
		($arg1) = $input =~ /^[\s\S]*? (\w+)/;
		if ($arg1 eq "") {
			message("---------Identify List--------\n", "list");
			for (my $i = 0; $i < @identifyID; $i++) {
				next if ($identifyID[$i] eq "");
				message(swrite(
					"@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<",
					[$i, $chars[$config{'char'}]{'inventory'}[$identifyID[$i]]{'name'}]),
					"list");
			}
			message("------------------------------\n", "list");
		} elsif ($arg1 =~ /\d+/ && $identifyID[$arg1] eq "") {
			error	"Error in function 'identify' (Identify Item)\n" .
				"Identify Item $arg1 does not exist\n";

		} elsif ($arg1 =~ /\d+/) {
			sendIdentify(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$identifyID[$arg1]]{'index'});
		} else {
			error	"Syntax Error in function 'identify' (Identify Item)\n" .
				"Usage: identify [<identify #>]\n";
		}

	} elsif ($switch eq "join") {
		($arg1) = $input =~ /^[\s\S]*? (\d+)/;
		($arg2) = $input =~ /^[\s\S]*? \d+ ([\s\S]*)$/;
		if ($arg1 eq "") {
			error	"Syntax Error in function 'join' (Join Chat Room)\n" .
				"Usage: join <chat room #> [<password>]\n";
		} elsif ($currentChatRoom ne "") {
			error	"Error in function 'join' (Join Chat Room)\n" .
				"You are already in a chat room.\n";
		} elsif ($chatRoomsID[$arg1] eq "") {
			error	"Error in function 'join' (Join Chat Room)\n" .
				"Chat Room $arg1 does not exist.\n";
		} else {
			sendChatRoomJoin(\$remote_socket, $chatRoomsID[$arg1], $arg2);
		}

	} elsif ($switch eq "judge") {
		($arg1) = $input =~ /^[\s\S]*? (\d+)/;
		($arg2) = $input =~ /^[\s\S]*? \d+ (\d+)/;
		if ($arg1 eq "" || $arg2 eq "") {
			error	"Syntax Error in function 'judge' (Give an alignment point to Player)\n" .
				"Usage: judge <player #> <0 (good) | 1 (bad)>\n";
		} elsif ($playersID[$arg1] eq "") {
			error	"Error in function 'judge' (Give an alignment point to Player)\n" .
				"Player $arg1 does not exist.\n";
		} else {
			$arg2 = ($arg2 >= 1);
			sendAlignment(\$remote_socket, $playersID[$arg1], $arg2);
		}

	} elsif ($switch eq "kick") {
		($arg1) = $input =~ /^[\s\S]*? ([\s\S]*)/;
		if ($currentChatRoom eq "") {
			error	"Error in function 'kick' (Kick from Chat)\n" .
				"You are not in a Chat Room.\n";
		} elsif ($arg1 eq "") {
			error	"Syntax Error in function 'kick' (Kick from Chat)\n" .
				"Usage: kick <user #>\n";
		} elsif ($currentChatRoomUsers[$arg1] eq "") {
			error	"Error in function 'kick' (Kick from Chat)\n" .
				"Chat Room User $arg1 doesn't exist\n";
		} else {
			sendChatRoomKick(\$remote_socket, $currentChatRoomUsers[$arg1]);
		}

	} elsif ($switch eq "look") {
		($arg1) = $input =~ /^[\s\S]*? (\d+)/;
		($arg2) = $input =~ /^[\s\S]*? \d+ (\d+)$/;
		if ($arg1 eq "") {
			error	"Syntax Error in function 'look' (Look a Direction)\n" .
				"Usage: look <body dir> [<head dir>]\n";
		} else {
			look($arg1, $arg2);
		}

	} elsif ($switch eq "lookp") {
		($arg1) = $input =~ /^[\s\S]*? (\d+)/;
		if ($arg1 eq "") {
			error	"Syntax Error in function 'lookp' (Look at Player)\n" .
				"Usage: lookp <player #>\n";
		} elsif (!$playersID[$arg1]) {
			error	"Error in function 'lookp' (Look at Player)\n" .
				"'$arg1' is not a valid player number.\n";
		} else {
			lookAtPosition($players{$playersID[$arg1]}{pos_to});
		}

	} elsif ($switch eq "move") {
		($arg1, $arg2, $arg3) = $input =~ /^[\s\S]*? (\d+) (\d+)(.*?)$/;

		my $map;
		if ($arg1 eq "") {
			($map) = $input =~ /^[\s\S]*? (.*?)$/;
		} else {
			$map = $arg3;
		}
		$map =~ s/\s//g;
		if ($input eq "move 0") {
			if ($portalsID[0]) {
				message("Move into portal number 0 ($portals{$portalsID[0]}{'pos'}{'x'},$portals{$portalsID[0]}{'pos'}{'y'})\n");
				ai_route($field{name}, $portals{$portalsID[0]}{'pos'}{'x'}, $portals{$portalsID[0]}{'pos'}{'y'}, attackOnRoute => 1, noSitAuto => 1);
			} else {
				error "No portals exist.\n";
			}
		} elsif (($arg1 eq "" || $arg2 eq "") && !$map) {
			error	"Syntax Error in function 'move' (Move Player)\n" .
				"Usage: move <x> <y> &| <map>\n";
		} elsif ($map eq "stop") {
			AI::clear(qw/move route mapRoute/);
			message "Stopped all movement\n", "success";
		} else {
			AI::clear(qw/move route mapRoute/);
			$map = $field{name} if ($map eq "");
			if ($maps_lut{"${map}.rsw"}) {
				my ($x, $y);
				if ($arg2 ne "") {
					message("Calculating route to: $maps_lut{$map.'.rsw'}($map): $arg1, $arg2\n", "route");
					$x = $arg1;
					$y = $arg2;
				} else {
					message("Calculating route to: $maps_lut{$map.'.rsw'}($map)\n", "route");
				}
				ai_route($map, $x, $y,
					attackOnRoute => 1,
					noSitAuto => 1);
			} elsif ($map =~ /^\d$/) {
				if ($portalsID[$map]) {
					message("Move into portal number $map ($portals{$portalsID[$map]}{'pos'}{'x'},$portals{$portalsID[$map]}{'pos'}{'y'})\n");
					ai_route($field{name}, $portals{$portalsID[$map]}{'pos'}{'x'}, $portals{$portalsID[$map]}{'pos'}{'y'}, attackOnRoute => 1, noSitAuto => 1);
				} else {
					error "No portals exist.\n";
				}
			} else {
				error "Map $map does not exist\n";
			}
		}

	} elsif ($switch eq "p") {
		($arg1) = $input =~ /^[\s\S]*? ([\s\S]*)/;
		if ($arg1 eq "") {
			error	"Syntax Error in function 'p' (Party Chat)\n" .
				"Usage: p <message>\n";
		} else {
			sendMessage(\$remote_socket, "p", $arg1);
		}

	} elsif ($switch eq "party") {
		($arg1) = $input =~ /^[\s\S]*? (\w*)/;
		($arg2) = $input =~ /^[\s\S]*? [\s\S]*? (\d+)\b/;
		if ($arg1 eq "" && !%{$chars[$config{'char'}]{'party'}}) {
			error	"Error in function 'party' (Party Functions)\n" .
				"Can't list party - you're not in a party.\n";
		} elsif ($arg1 eq "") {
			message("----------Party-----------\n", "list");
			message($chars[$config{'char'}]{'party'}{'name'}."\n", "list");
			message("#      Name                  Map                    Online    HP\n", "list");
			for (my $i = 0; $i < @partyUsersID; $i++) {
				next if ($partyUsersID[$i] eq "");
				my $coord_string = "";
				my $hp_string = "";
				my $name_string = $chars[$config{'char'}]{'party'}{'users'}{$partyUsersID[$i]}{'name'};
				my $admin_string = ($chars[$config{'char'}]{'party'}{'users'}{$partyUsersID[$i]}{'admin'}) ? "(A)" : "";
				my $online_string;

				if ($partyUsersID[$i] eq $accountID) {
					$online_string = "Yes";
					($map_string) = $map_name =~ /([\s\S]*)\.gat/;
					$coord_string = $chars[$config{'char'}]{'pos'}{'x'}. ", ".$chars[$config{'char'}]{'pos'}{'y'};
					$hp_string = $chars[$config{'char'}]{'hp'}."/".$chars[$config{'char'}]{'hp_max'}
							." (".int($chars[$config{'char'}]{'hp'}/$chars[$config{'char'}]{'hp_max'} * 100)
							."%)";
				} else {
					$online_string = ($chars[$config{'char'}]{'party'}{'users'}{$partyUsersID[$i]}{'online'}) ? "Yes" : "No";
					($map_string) = $chars[$config{'char'}]{'party'}{'users'}{$partyUsersID[$i]}{'map'} =~ /([\s\S]*)\.gat/;
					$coord_string = $chars[$config{'char'}]{'party'}{'users'}{$partyUsersID[$i]}{'pos'}{'x'}
						. ", ".$chars[$config{'char'}]{'party'}{'users'}{$partyUsersID[$i]}{'pos'}{'y'}
						if ($chars[$config{'char'}]{'party'}{'users'}{$partyUsersID[$i]}{'pos'}{'x'} ne ""
							&& $chars[$config{'char'}]{'party'}{'users'}{$partyUsersID[$i]}{'online'});
					$hp_string = $chars[$config{'char'}]{'party'}{'users'}{$partyUsersID[$i]}{'hp'}."/".$chars[$config{'char'}]{'party'}{'users'}{$partyUsersID[$i]}{'hp_max'}
							." (".int($chars[$config{'char'}]{'party'}{'users'}{$partyUsersID[$i]}{'hp'}/$chars[$config{'char'}]{'party'}{'users'}{$partyUsersID[$i]}{'hp_max'} * 100)
							."%)" if ($chars[$config{'char'}]{'party'}{'users'}{$partyUsersID[$i]}{'hp_max'} && $chars[$config{'char'}]{'party'}{'users'}{$partyUsersID[$i]}{'online'});
				}
				message(swrite(
					"@< @<< @<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<< @<<<<<<< @<<       @<<<<<<<<<<<<<<<<<<",
					[$i, $admin_string, $name_string, $map_string, $coord_string, $online_string, $hp_string]),
					"list");
			}
			message("--------------------------\n", "list");

		} elsif ($arg1 eq "create") {
			($arg2) = $input =~ /^[\s\S]*? [\s\S]*? \"([\s\S]*?)\"/;
			if ($arg2 eq "") {
				error	"Syntax Error in function 'party create' (Organize Party)\n" .
					"Usage: party create \"<party name>\"\n";
			} else {
				sendPartyOrganize(\$remote_socket, $arg2);
			}

		} elsif ($arg1 eq "join" && $arg2 ne "1" && $arg2 ne "0") {
			error	"Syntax Error in function 'party join' (Accept/Deny Party Join Request)\n" .
				"Usage: party join <flag>\n";
		} elsif ($arg1 eq "join" && $incomingParty{'ID'} eq "") {
			error	"Error in function 'party join' (Join/Request to Join Party)\n" .
				"Can't accept/deny party request - no incoming request.\n";
		} elsif ($arg1 eq "join") {
			sendPartyJoin(\$remote_socket, $incomingParty{'ID'}, $arg2);
			undef %incomingParty;

		} elsif ($arg1 eq "request" && !%{$chars[$config{'char'}]{'party'}}) {
			error	"Error in function 'party request' (Request to Join Party)\n" .
				"Can't request a join - you're not in a party.\n";
		} elsif ($arg1 eq "request" && $playersID[$arg2] eq "") {
			error	"Error in function 'party request' (Request to Join Party)\n" .
				"Can't request to join party - player $arg2 does not exist.\n";
		} elsif ($arg1 eq "request") {
			sendPartyJoinRequest(\$remote_socket, $playersID[$arg2]);


		} elsif ($arg1 eq "leave" && !%{$chars[$config{'char'}]{'party'}}) {
			error	"Error in function 'party leave' (Leave Party)\n" .
				"Can't leave party - you're not in a party.\n";
		} elsif ($arg1 eq "leave") {
			sendPartyLeave(\$remote_socket);


		} elsif ($arg1 eq "share" && !%{$chars[$config{'char'}]{'party'}}) {
			error	"Error in function 'party share' (Set Party Share EXP)\n" .
				"Can't set share - you're not in a party.\n";
		} elsif ($arg1 eq "share" && $arg2 ne "1" && $arg2 ne "0") {
			error	"Syntax Error in function 'party share' (Set Party Share EXP)\n" .
				"Usage: party share <flag>\n";
		} elsif ($arg1 eq "share") {
			sendPartyShareEXP(\$remote_socket, $arg2);


		} elsif ($arg1 eq "kick" && !%{$chars[$config{'char'}]{'party'}}) {
			error	"Error in function 'party kick' (Kick Party Member)\n" .
				"Can't kick member - you're not in a party.\n";
		} elsif ($arg1 eq "kick" && $arg2 eq "") {
			error	"Syntax Error in function 'party kick' (Kick Party Member)\n" .
				"Usage: party kick <party member #>\n";
		} elsif ($arg1 eq "kick" && $partyUsersID[$arg2] eq "") {
			error	"Error in function 'party kick' (Kick Party Member)\n" .
				"Can't kick member - member $arg2 doesn't exist.\n";
		} elsif ($arg1 eq "kick") {
			sendPartyKick(\$remote_socket, $partyUsersID[$arg2]
					,$chars[$config{'char'}]{'party'}{'users'}{$partyUsersID[$arg2]}{'name'});

		}

	} elsif ($switch eq "petl") {
		message("-----------Pet List-----------\n" .
			"#    Type                     Name\n",
			"list");
		for (my $i = 0; $i < @petsID; $i++) {
			next if ($petsID[$i] eq "");
			message(swrite(
				"@<<< @<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<<<<<<<<<<<<<",
				[$i, $pets{$petsID[$i]}{'name'}, $pets{$petsID[$i]}{'name_given'}]),
				"list");
		}
		message("----------------------------------\n", "list");

	} elsif ($switch eq "pm") {
		($arg1, $arg2) = $input =~ /^[\S]*? "(.*?)" (.*)/;
		my $type = 0;
		if (!$arg1) {
			($arg1, $arg2) = $input =~ /^[\S]*? (\d+) (.*)/;
			$type = 1;
		}
		if ($arg1 eq "" || $arg2 eq "") {
			error	"Syntax Error in function 'pm' (Private Message)\n" .
				qq~Usage: pm ("<username>" | <pm #>) <message>\n~;
		} elsif ($type) {
			if ($arg1 - 1 >= @privMsgUsers) {
				error	"Error in function 'pm' (Private Message)\n" .
					"Quick look-up $arg1 does not exist\n";
			} else {
				sendMessage(\$remote_socket, "pm", $arg2, $privMsgUsers[$arg1 - 1]);
				$lastpm{'msg'} = $arg2;
				$lastpm{'user'} = $privMsgUsers[$arg1 - 1];
			}
		} else {
			if ($arg1 =~ /^%(\d*)$/) {
				$arg1 = $1;
			}

			if (binFind(\@privMsgUsers, $arg1) eq "") {
				$privMsgUsers[@privMsgUsers] = $arg1;
			}
			sendMessage(\$remote_socket, "pm", $arg2, $arg1);
			$lastpm{'msg'} = $arg2;
			$lastpm{'user'} = $arg1;
		}

	} elsif ($switch eq "pml") {
		message("-----------PM List-----------\n", "list");
		for (my $i = 1; $i <= @privMsgUsers; $i++) {
			message(swrite(
				"@<<< @<<<<<<<<<<<<<<<<<<<<<<<",
				[$i, $privMsgUsers[$i - 1]]),
				"list");
		}
		message("-----------------------------\n", "list");

	} elsif ($switch eq "quit") {
		quit();

	} elsif ($switch eq "rc") {
		($args) = $input =~ /^[\s\S]*? ([\s\S]*)/;
		if ($args ne "") {
			Modules::reload($args, 1);

		} else {
			Modules::reloadFile('functions.pl');
		}

	} elsif ($switch eq "relog") {
		relog();

	} elsif ($switch eq "respawn") {
		if ($chars[$config{'char'}]{'dead'}) {
			sendRespawn(\$remote_socket);
		} else {
			useTeleport(2);
		}

	} elsif ($switch eq "sell") {
		($arg1) = $input =~ /^[\s\S]*? (\d+)/;
		($arg2) = $input =~ /^[\s\S]*? \d+ (\d+)$/;
		if ($arg1 eq "" && $talk{'buyOrSell'}) {
			sendGetSellList(\$remote_socket, $talk{'ID'});

		} elsif ($arg1 eq "") {
			error	"Syntax Error in function 'sell' (Sell Inventory Item)\n" .
				"Usage: sell <item #> [<amount>]\n";
		} elsif (!%{$chars[$config{'char'}]{'inventory'}[$arg1]}) {
			error	"Error in function 'sell' (Sell Inventory Item)\n" .
				"Inventory Item $arg1 does not exist.\n";
		} else {
			if (!$arg2 || $arg2 > $chars[$config{'char'}]{'inventory'}[$arg1]{'amount'}) {
				$arg2 = $chars[$config{'char'}]{'inventory'}[$arg1]{'amount'};
			}
			sendSell(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$arg1]{'index'}, $arg2);
		}

	} elsif ($switch eq "store") {
		($arg1) = $input =~ /^[\s\S]*? (\w+)/;
		($arg2) = $input =~ /^[\s\S]*? \w+ (\d+)/;
		if ($arg1 eq "" && !$talk{'buyOrSell'}) {
			message("----------Store List-----------\n", "list");
			message("#  Name                    Type           Price\n", "list");
			for (my $i = 0; $i < @storeList; $i++) {
				$display = $storeList[$i]{'name'};
				message(swrite(
					"@< @<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<< @>>>>>>>z",
					[$i, $display, $itemTypes_lut{$storeList[$i]{'type'}}, $storeList[$i]{'price'}]),
					"list");
			}
			message("-------------------------------\n", "list");
		} elsif ($arg1 eq "" && $talk{'buyOrSell'}) {
			sendGetStoreList(\$remote_socket, $talk{'ID'});

		} elsif ($arg1 eq "desc" && $arg2 =~ /\d+/ && $storeList[$arg2] eq "") {
			error	"Error in function 'store desc' (Store Item Description)\n" .
				"Usage: Store item $arg2 does not exist\n";
		} elsif ($arg1 eq "desc" && $arg2 =~ /\d+/) {
			printItemDesc($storeList[$arg2]);

		} else {
			error	"Syntax Error in function 'store' (Store Functions)\n" .
				"Usage: store [<desc>] [<store item #>]\n";

		}

	} elsif ($switch eq "take") {
		($arg1) = $input =~ /^[\s\S]*? (\d+)$/;
		if ($arg1 eq "") {
			error	"Syntax Error in function 'take' (Take Item)\n" .
				"Usage: take <item #>\n";
		} elsif ($itemsID[$arg1] eq "") {
			error	"Error in function 'take' (Take Item)\n" .
				"Item $arg1 does not exist.\n";
		} else {
			take($itemsID[$arg1]);
		}


	} elsif ($switch eq "talk") {
		($arg1) = $input =~ /^[\s\S]*? (\w+)/;
		($arg2) = $input =~ /^[\s\S]*? [\s\S]*? (\d+)/;

		if ($arg1 =~ /^\d+$/ && $npcsID[$arg1] eq "") {
			error	"Error in function 'talk' (Talk to NPC)\n" .
				"NPC $arg1 does not exist\n";
		} elsif ($arg1 =~ /^\d+$/) {
			sendTalk(\$remote_socket, $npcsID[$arg1]);

		} elsif (($arg1 eq "resp" || $arg1 eq "num" || $arg1 eq "text") && !%talk) {
			error	"Error in function 'talk resp' (Respond to NPC)\n" .
				"You are not talking to any NPC.\n";

		} elsif ($arg1 eq "resp" && $arg2 eq "") {
			my $display = $npcs{$talk{'nameID'}}{'name'};
			message("----------Responses-----------\n", "list");
			message("NPC: $display\n", "list");
			message("#  Response\n", "list");
			for (my $i = 0; $i < @{$talk{'responses'}}; $i++) {
				message(swrite(
					"@< @<<<<<<<<<<<<<<<<<<<<<<",
					[$i, $talk{'responses'}[$i]]),
					"list");
			}
			message("-------------------------------\n", "list");
		} elsif ($arg1 eq "resp" && $arg2 ne "" && $talk{'responses'}[$arg2] eq "") {
			error	"Error in function 'talk resp' (Respond to NPC)\n" .
				"Response $arg2 does not exist.\n";
		} elsif ($arg1 eq "resp" && $arg2 ne "") {
			if ($talk{'responses'}[$arg2] eq "Cancel Chat") {
				$arg2 = 255;
			} else {
				$arg2 += 1;
			}
			sendTalkResponse(\$remote_socket, $talk{'ID'}, $arg2);

		} elsif ($arg1 eq "num" && $arg2 eq "") {
			error "Error in function 'talk num' (Respond to NPC)\n" .
				"You must specify a number.\n";
		} elsif ($arg1 eq "num" && !($arg2 =~ /^\d+$/)) {
			error "Error in function 'talk num' (Respond to NPC)\n" .
				"$arg2 is not a valid number.\n";
		} elsif ($arg1 eq "num" && $arg2 =~ /^\d+$/) {
			sendTalkNumber(\$remote_socket, $talk{'ID'}, $arg2);

		} elsif ($arg1 eq "text") {
			($arg2) = $input =~ /^[\s\S]*? [\s\S]*? (.*)/;
			if ($arg2 eq "") {
				error "Error in function 'talk text' (Respond to NPC)\n" .
					"You must specify a string.\n";
			} else {
				sendTalkText(\$remote_socket, $talk{'ID'}, $arg2);
			}
			
		} elsif ($arg1 eq "cont" && !%talk) {
			error	"Error in function 'talk cont' (Continue Talking to NPC)\n" .
				"You are not talking to any NPC.\n";
		} elsif ($arg1 eq "cont") {
			sendTalkContinue(\$remote_socket, $talk{'ID'});


		} elsif ($arg1 eq "no") {
			if (!%talk) {
				error "You are not talking to any NPC.\n";
			} else {
				sendTalkCancel(\$remote_socket, $talk{'ID'});
			}

		} else {
			error	"Syntax Error in function 'talk' (Talk to NPC)\n" .
				"Usage: talk <NPC # | cont | resp | num> [<response #>|<number #>]\n";
		}

	} elsif ($switch eq "tele") {
		useTeleport(1);

	} elsif ($switch eq "where") {
		($map_string) = $map_name =~ /([\s\S]*)\.gat/;
		my $pos = calcPosition($char);
		message("Location $maps_lut{$map_string.'.rsw'} ($map_string) : $pos->{x}, $pos->{y}\n", "info");

	} elsif ($switch eq "east") {
		manualMove(5, 0);
	} elsif ($switch eq "west") {
		manualMove(-5, 0);
	} elsif ($switch eq "north") {
		manualMove(0, 5);
	} elsif ($switch eq "south") {
		manualMove(0, -5);
	} elsif ($switch eq "northeast") {
		manualMove(5, 5);
	} elsif ($switch eq "southwest") {
		manualMove(-5, -5);
	} elsif ($switch eq "northwest") {
		manualMove(-5, 5);
	} elsif ($switch eq "southeast") {
		manualMove(5, -5);

	} else {
		my %params = ( switch => $switch, input => $input );
		Plugins::callHook('Command_post', \%params);
		if (!$params{return}) {
			error "Unknown command '$switch'. Please read the documentation for a list of commands.\n";
		}
	}
}


#######################################
#######################################
#AI
#######################################
#######################################



sub AI {
	my $i, $j;
	my %cmd = %{(shift)};


	if (timeOut($timeout{ai_wipe_check})) {
		foreach (keys %players_old) {
			delete $players_old{$_} if (time - $players_old{$_}{'gone_time'} >= $timeout{'ai_wipe_old'}{'timeout'});
		}
		foreach (keys %monsters_old) {
			delete $monsters_old{$_} if (time - $monsters_old{$_}{'gone_time'} >= $timeout{'ai_wipe_old'}{'timeout'});
		}
		foreach (keys %npcs_old) {
			delete $npcs_old{$_} if (time - $npcs_old{$_}{'gone_time'} >= $timeout{'ai_wipe_old'}{'timeout'});
		}
		foreach (keys %items_old) {
			delete $items_old{$_} if (time - $items_old{$_}{'gone_time'} >= $timeout{'ai_wipe_old'}{'timeout'});
		}
		foreach (keys %portals_old) {
			delete $portals_old{$_} if (time - $portals_old{$_}{'gone_time'} >= $timeout{'ai_wipe_old'}{'timeout'});
		}

		# Remove players that are too far away; sometimes they don't get
		# removed from the list for some reason
		foreach (keys %players) {
			if (distance($char->{pos_to}, $players{$_}{pos_to}) > 35) {
				delete $players{$_};
				binRemove(\@playersID, $_);
				next;
			}
		}

		$timeout{'ai_wipe_check'}{'time'} = time;
		debug "Wiped old\n", "ai", 2;
	}

	if (timeOut($timeout{ai_getInfo})) {
		while (@unknownObjects) {
			my $ID = $unknownObjects[0];
			my $object = $players{$ID} || $npcs{$ID};
			if (!$object || $object->{gotName}) {
				shift @unknownObjects;
				next;
			}
			sendGetPlayerInfo(\$remote_socket, $ID);
			push(@unknownObjects, shift(@unknownObjects));
			last;
		}

		foreach (keys %monsters) {
			if ($monsters{$_}{'name'} =~ /Unknown/) {
				sendGetPlayerInfo(\$remote_socket, $_);
				last;
			}
		}
		foreach (keys %pets) { 
			if ($pets{$_}{'name_given'} =~ /Unknown/) { 
				sendGetPlayerInfo(\$remote_socket, $_); 
				last; 
			}
		}
		$timeout{'ai_getInfo'}{'time'} = time;
	}

	if (!$xkore && timeOut($timeout{ai_sync})) {
		$timeout{ai_sync}{time} = time;
		sendSync(\$remote_socket, getTickCount());
	}

	if (timeOut($mapdrt, $config{'intervalMapDrt'})) {
		$mapdrt = time;

		$map_name =~ /([\s\S]*)\.gat/;
		if ($1) {
			my $pos = calcPosition($char);
			open(DATA, ">$Settings::logs_folder/walk.dat");
			print DATA "$1\n$pos->{x}\n$pos->{y}\n";
			if ($ipc && $ipc->connected && $ipc->ready) {
				print DATA $ipc->host . " " . $ipc->port . " " . $ipc->ID . "\n";
			} else {
				print DATA "\n";
			}

			for (my $i = 0; $i < @npcsID; $i++) {
				next if ($npcsID[$i] eq "");
				print DATA "NL " . $npcs{$npcsID[$i]}{pos_to}{x} . " " . $npcs{$npcsID[$i]}{pos_to}{y} . "\n";
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
		}
	}

	if (timeOut($char->{muted}, $char->{mute_period})) {
		delete $char->{muted};
		delete $char->{mute_period};
	}

	return if (!$AI);



	##### REAL AI STARTS HERE #####

	Plugins::callHook('AI_pre');

	if (!$accountID) {
		$AI = 0;
		injectAdminMessage("Please relogin to enable X-${Settings::NAME}.") if ($config{'verbose'});
		return;
	}

	ChatQueue::processFirst;


	##### MISC #####

	if ($ai_seq[0] eq "look" && timeOut(\%{$timeout{'ai_look'}})) {
		$timeout{'ai_look'}{'time'} = time;
		sendLook(\$remote_socket, $ai_seq_args[0]{'look_body'}, $ai_seq_args[0]{'look_head'});
		shift @ai_seq;
		shift @ai_seq_args;
	}

	if ($ai_seq[0] ne "deal" && %currentDeal) {
		AI::queue('deal');
	} elsif ($ai_seq[0] eq "deal" && %currentDeal && !$currentDeal{'you_finalize'} && timeOut(\%{$timeout{'ai_dealAuto'}}) && $config{'dealAuto'}==2) {
		sendDealFinalize(\$remote_socket);
		$timeout{'ai_dealAuto'}{'time'} = time;
	} elsif ($ai_seq[0] eq "deal" && %currentDeal && $currentDeal{'other_finalize'} && $currentDeal{'you_finalize'} &&timeOut(\%{$timeout{'ai_dealAuto'}}) && $config{'dealAuto'}==2) {
		sendDealTrade(\$remote_socket);
		$timeout{'ai_dealAuto'}{'time'} = time;
	} elsif ($ai_seq[0] eq "deal" && !%currentDeal) {
		AI::dequeue();
	}

	# dealAuto 1=refuse 2=accept
	if ($config{'dealAuto'} && %incomingDeal && timeOut(\%{$timeout{'ai_dealAuto'}})) {
		if ($config{'dealAuto'}==1) {
			sendDealCancel(\$remote_socket);
		}elsif ($config{'dealAuto'}==2) {
			sendDealAccept(\$remote_socket);
		}
		$timeout{'ai_dealAuto'}{'time'} = time;
	}


	# partyAuto 1=refuse 2=accept
	if ($config{'partyAuto'} && %incomingParty && timeOut(\%{$timeout{'ai_partyAuto'}})) {
		if ($config{partyAuto} == 1) {
			message "Auto-denying party request\n";
		} else {
			message "Auto-accepting party request\n";
		}
		sendPartyJoin(\$remote_socket, $incomingParty{'ID'}, $config{'partyAuto'} - 1);
		$timeout{'ai_partyAuto'}{'time'} = time;
		undef %incomingParty;
	}

	if ($config{'guildAutoDeny'} && %incomingGuild && timeOut(\%{$timeout{'ai_guildAutoDeny'}})) {
		sendGuildJoin(\$remote_socket, $incomingGuild{'ID'}, 0) if ($incomingGuild{'Type'} == 1);
		sendGuildAlly(\$remote_socket, $incomingGuild{'ID'}, 0) if ($incomingGuild{'Type'} == 2);
		$timeout{'ai_guildAutoDeny'}{'time'} = time;
		undef %incomingGuild;
	}


	##### PORTALRECORD #####
	# Automatically record new unknown portals

	if ($ai_v{'portalTrace_mapChanged'}) {
		undef $ai_v{'portalTrace_mapChanged'};
		my $first = 1;
		my ($foundID, $smallDist, $dist);

		# Find the nearest portal or the only portal on the map you came from (source portal)
		foreach (@portalsID_old) {
			$dist = distance($chars_old[$config{'char'}]{'pos_to'}, $portals_old{$_}{'pos'});
			if ($dist <= 7 && ($first || $dist < $smallDist)) {
				$smallDist = $dist;
				$foundID = $_;
				undef $first;
			}
		}

		my ($sourceMap, $sourceID, %sourcePos);
		if ($foundID) {
			$sourceMap = $portals_old{$foundID}{'source'}{'map'};
			$sourceID = $portals_old{$foundID}{'nameID'};
			%sourcePos = %{$portals_old{$foundID}{'pos'}};
		}

		# Continue only if the source portal isn't already in portals.txt
		if ($foundID && portalExists($sourceMap, \%sourcePos) eq "" && $field{'name'}) {
			$first = 1;
			undef $foundID;
			undef $smallDist;

			# Find the nearest portal or only portal on the current map
			foreach (@portalsID) {
				$dist = distance($chars[$config{'char'}]{'pos_to'}, $portals{$_}{'pos'});
				if ($first || $dist < $smallDist) {
					$smallDist = $dist;
					$foundID = $_;
					undef $first;
				}
			}

			# Final sanity check
			if (%{$portals{$foundID}} && portalExists($field{'name'}, $portals{$foundID}{'pos'}) eq ""
			 && $sourceMap && defined $sourcePos{x} && defined $sourcePos{y}
			 && defined $portals{$foundID}{'pos'}{'x'} && defined $portals{$foundID}{'pos'}{'y'}) {

				my ($ID, $ID2, $destName);
				$portals{$foundID}{'name'} = "$field{'name'} -> $sourceMap";
				$portals{pack("L", $sourceID)}{'name'} = "$sourceMap -> $field{'name'}";

				# Record information about the portal we walked into
				$ID = "$sourceMap $sourcePos{x} $sourcePos{y}";
				$portals_lut{$ID}{'source'}{'map'} = $sourceMap;
				%{$portals_lut{$ID}{'source'}{'pos'}} = %sourcePos;
				$destName = $field{'name'} . " " . $portals{$foundID}{'pos'}{'x'} . " " . $portals{$foundID}{'pos'}{'y'};
				$portals_lut{$ID}{'dest'}{$destName}{'map'} = $field{'name'};
				%{$portals_lut{$ID}{'dest'}{$destName}{'pos'}} = %{$portals{$foundID}{'pos'}};

				updatePortalLUT("$Settings::tables_folder/portals.txt",
					$sourceMap, $sourcePos{x}, $sourcePos{y},
					$field{'name'}, $portals{$foundID}{'pos'}{'x'}, $portals{$foundID}{'pos'}{'y'});

				# Record information about the portal in which we came out
				$ID2 = "$field{'name'} $portals{$foundID}{'pos'}{'x'} $portals{$foundID}{'pos'}{'y'}";
				$portals_lut{$ID2}{'source'}{'map'} = $field{'name'};
				%{$portals_lut{$ID2}{'source'}{'pos'}} = %{$portals{$foundID}{'pos'}};
				$destName = $sourceMap . " " . $sourcePos{x} . " " . $sourcePos{y};
				$portals_lut{$ID2}{'dest'}{$destName}{'map'} = $sourceMap;
				%{$portals_lut{$ID2}{'dest'}{$destName}{'pos'}} = %sourcePos;

				updatePortalLUT("$Settings::tables_folder/portals.txt",
					$field{'name'}, $portals{$foundID}{'pos'}{'x'}, $portals{$foundID}{'pos'}{'y'},
					$sourceMap, $sourcePos{x}, $sourcePos{y});
			}
		}
	}


	if ($config{'XKore'} && !$sentWelcomeMessage && timeOut(\%{$timeout{'welcomeText'}})) {
		injectAdminMessage($Settings::welcomeText) if ($config{'verbose'} && !$config{'XKore_silent'});
		$sentWelcomeMessage = 1;
	}


	##### CLIENT SUSPEND #####
	# The clientSuspend AI sequence is used to freeze all other AI activity
	# for a certain period of time.

	if (AI::action eq 'clientSuspend' && timeOut(AI::args)) {
		debug "AI suspend by clientSuspend dequeued\n";
		AI::dequeue;
	} elsif (AI::action eq "clientSuspend" && $config{'XKore'}) {
		# When XKore mode is turned on, clientSuspend will increase it's timeout
		# every time the user tries to do something manually.

		if ($ai_seq_args[0]{'type'} eq "0089") {
			# Player's manually attacking
			if ($ai_seq_args[0]{'args'}[0] == 2) {
				if ($chars[$config{'char'}]{'sitting'}) {
					$ai_seq_args[0]{'time'} = time;
				}
			} elsif ($ai_seq_args[0]{'args'}[0] == 3) {
				$ai_seq_args[0]{'timeout'} = 6;
			} else {
				if (!$ai_seq_args[0]{'forceGiveup'}{'timeout'}) {
					$ai_seq_args[0]{'forceGiveup'}{'timeout'} = 6;
					$ai_seq_args[0]{'forceGiveup'}{'time'} = time;
				}
				if ($ai_seq_args[0]{'dmgFromYou_last'} != $monsters{$ai_seq_args[0]{'args'}[1]}{'dmgFromYou'}) {
					$ai_seq_args[0]{'forceGiveup'}{'time'} = time;
				}
				$ai_seq_args[0]{'dmgFromYou_last'} = $monsters{$ai_seq_args[0]{'args'}[1]}{'dmgFromYou'};
				$ai_seq_args[0]{'missedFromYou_last'} = $monsters{$ai_seq_args[0]{'args'}[1]}{'missedFromYou'};
				if (%{$monsters{$ai_seq_args[0]{'args'}[1]}}) {
					$ai_seq_args[0]{'time'} = time;
				} else {
					$ai_seq_args[0]{'time'} -= $ai_seq_args[0]{'timeout'};
				}
				if (timeOut(\%{$ai_seq_args[0]{'forceGiveup'}})) {
					$ai_seq_args[0]{'time'} -= $ai_seq_args[0]{'timeout'};
				}
			}

		} elsif ($ai_seq_args[0]{'type'} eq "009F") {
			# Player's manually picking up an item
			if (!$ai_seq_args[0]{'forceGiveup'}{'timeout'}) {
				$ai_seq_args[0]{'forceGiveup'}{'timeout'} = 4;
				$ai_seq_args[0]{'forceGiveup'}{'time'} = time;
			}
			if (%{$items{$ai_seq_args[0]{'args'}[0]}}) {
				$ai_seq_args[0]{'time'} = time;
			} else {
				$ai_seq_args[0]{'time'} -= $ai_seq_args[0]{'timeout'};
			}
			if (timeOut(\%{$ai_seq_args[0]{'forceGiveup'}})) {
				$ai_seq_args[0]{'time'} -= $ai_seq_args[0]{'timeout'};
			}
		}

		# Client suspended, do not continue with AI
		return;
	}


	##### CHECK FOR UPDATES #####
	# We force the user to download an update if this version of kore is too old.
	# This is to prevent bots from KSing people because of new packets
	# (like it happened with Comodo and Juno).
	if (($ENV{OPENKORE_TESTUPDATE} || !($Settings::CVS =~ /CVS/)) && !$checkUpdate{checked}) {
		if ($checkUpdate{stage} eq '') {
			# We only want to check at most once a day
			open(F, "< $Settings::tables_folder/updatecheck.txt");
			my $time = <F>;
			close F;

			$time =~ s/[\r\n].*//;
			if (timeOut($time, 60 * 60 * 24)) {
				$checkUpdate{stage} = 'Connect';
			} else {
				$checkUpdate{checked} = 1;
				debug "Version up-to-date\n";
			}

		} elsif ($checkUpdate{stage} eq 'Connect') {
			my $sock = new IO::Socket::INET(
				PeerHost	=> 'openkore.sourceforge.net',
				PeerPort	=> 80,
				Proto		=> 'tcp',
				Timeout		=> 4
			);
			if (!$sock) {
				$checkUpdate{checked} = 1;
			} else {
				$checkUpdate{sock} = $sock;
				$checkUpdate{stage} = 'Request';
			}

		} elsif ($checkUpdate{stage} eq 'Request') {
			my $filename = "/cgi-bin/leastVersion.pl";
			my $stats = $config{"master_host_$config{'master'}"};
			$checkUpdate{sock}->send("GET $filename?$stats HTTP/1.1\r\n", 0);
			$checkUpdate{sock}->send("Host: openkore.sourceforge.net\r\n\r\n", 0);
			$checkUpdate{sock}->flush;
			$checkUpdate{stage} = 'Receive';

		} elsif ($checkUpdate{stage} eq 'Receive' && dataWaiting(\$checkUpdate{sock})) {
			my $data;
			$checkUpdate{sock}->recv($data, 1024 * 32);
			if ($data =~ /^HTTP\/.\.. 200/s) {
				# Remove CR
				$data =~ s/\r\n/\n/sg;
				# Strip HTTP header
				$data =~ s/.*?\n\n//s;
				# Get rid of first and last lines (HTTP chuncked encoding junk)
				$data =~ s/^.*?\n//s;
				$data =~ s/\n.*?$//s;
				# Remove everything but the first line
				$data =~ s/\n.*//;

				debug "Update check - least version: $data\n";
				unless (($Settings::VERSION cmp $data) >= 0) {
					Network::disconnect(\$remote_socket);
					$interface->errorDialog("Your version of $Settings::NAME " .
						"(${Settings::VERSION}${Settings::CVS}) is too old.\n" .
						"Please upgrade to at least version $data\n");
					quit();

				} else {
					# Store the current time in a file
					open(F, "> $Settings::tables_folder/updatecheck.txt");
					print F time;
					close F;
				}
			}

			$checkUpdate{sock}->close;
			undef %checkUpdate;
			$checkUpdate{checked} = 1;
		}
	}


	##### AUTOBREAKTIME #####
	# Break time: automatically disconnect at certain times of the day

	if (timeOut($AI::Timeouts::autoBreakTime, 1)) {
		my @datetimeyear = split / /, localtime;
		my $i = 0;
		while (exists $config{"autoBreakTime_$i"}) {
			if (!$config{"autoBreakTime_$i"}) {
				$i++;
				next;
			}

			if  ( (lc($datetimeyear[0]) eq lc($config{"autoBreakTime_$i"})) || (lc($config{"autoBreakTime_$i"}) eq "all") ) {
				my $mytime = $datetimeyear[3];
				my $hormin = substr($mytime, 0, 5);
				if ($config{"autoBreakTime_${i}_startTime"} eq $hormin) {
					my ($hr1, $min1) = split /:/, $config{"autoBreakTime_${i}_startTime"};
					my ($hr2, $min2) = split /:/, $config{"autoBreakTime_${i}_stopTime"};
					my $halt_sec = 0;
					my $hr = $hr2-$hr1;
					my $min = $min2-$min1;
					if ($hr < 0) {
						$hr = $hr+24;
					} elsif ($min < 0) {
						$hr = 24;
					}
					my $reconnect_time = $hr * 3600 + $min * 60;

					message("\nDisconnecting due to break time: " . $config{"autoBreakTime_$i"."_startTime"} . " to " . $config{"autoBreakTime_$i"."_stopTime"}."\n\n", "system");
					chatLog("k", "*** Disconnected due to Break Time: " . $config{"autoBreakTime_$i"."_startTime"}." to " . $config{"autoBreakTime_$i"."_stopTime"}." ***\n");

					$timeout_ex{'master'}{'timeout'} = $reconnect_time;
					$timeout_ex{'master'}{'time'} = time;
					$KoreStartTime = time;
					Network::disconnect(\$remote_socket);
					AI::clear();
					undef %ai_v;
					$conState = 1;
					undef $conState_tries;
					last;
				}
			}
			$i++;
		}
		$AI::Timeouts::autoBreakTime = time;
	}


	##### TALK WITH NPC ######
	NPCTALK: {
		last NPCTALK if (AI::action ne "NPC");
		my $args = AI::args;
		$args->{time} = time unless $args->{time};

		if ($args->{stage} eq '') {
			if (timeOut($args->{time}, $timeout{'ai_npcTalk'}{'timeout'})) {
				error "Could not find the NPC at the designated location.\n", "ai_npcTalk";
				AI::dequeue;

			} elsif ($args->{nameID}) {
				# An NPC ID has been passed
				my $npc = pack("L1", $ai_seq_args[0]{'nameID'});
				last if (!$npcs{$npc} || $npcs{$npc}{'name'} eq '' || $npcs{$npc}{'name'} =~ /Unknown/i);
				$args->{ID} = $npc;
				$args->{name} = $npcs{$npc}{'name'};
				$args->{stage} = 'Talking to NPC';
				$args->{steps} = [];
				@{$args->{steps}} = parse_line('\s+', 0, "w3 x $args->{sequence}");
				undef $args->{time};
				undef $ai_v{'npc_talk'}{'time'};

				# look at the NPC
				$args->{pos} = {};
				getNPCInfo($ai_seq_args[0]{'nameID'}, $args->{pos});
				lookAtPosition($args->{pos});

			} else {
				# An x,y position has been passed
				foreach my $npc (@npcsID) {
					next if !$npc || $npcs{$npc}{'name'} eq '' || $npcs{$npc}{'name'} =~ /Unknown/i;
					if ( $npcs{$npc}{'pos'}{'x'} eq $args->{pos}{'x'} &&
					     $npcs{$npc}{'pos'}{'y'} eq $args->{pos}{'y'} ) {
						debug "Target NPC $npcs{$npc}{'name'} at ($args->{pos}{x},$args->{pos}{y}) found.\n", "ai_npcTalk";
						$args->{'nameID'} = $npcs{$npc}{'nameID'};
				     		$args->{'ID'} = $npc;
						$args->{'name'} = $npcs{$npc}{'name'};
						$args->{'stage'} = 'Talking to NPC';
						$args->{steps} = [];
						@{$args->{steps}} = parse_line('\s+', 0, "w3 x $args->{sequence}");
						undef $args->{time};
						undef $ai_v{'npc_talk'}{'time'};
						lookAtPosition($args->{pos});
						last;
					}
				}
			}


		} elsif ($args->{mapChanged} || @{$args->{steps}} == 0) {
			message "Done talking with $args->{name}.\n", "ai_npcTalk";
			# There is no need to cancel conversation if map changed; NPC is nowhere by now.
			#sendTalkCancel(\$remote_socket, $args->{ID});
			AI::dequeue;

		} elsif (timeOut($args->{time}, $timeout{'ai_npcTalk'}{'timeout'})) {
			# If NPC does not respond before timing out, then by default, it's a failure
			error "NPC did not respond.\n", "ai_npcTalk";
			sendTalkCancel(\$remote_socket, $args->{ID});
			AI::dequeue;

		} elsif (timeOut($ai_v{'npc_talk'}{'time'}, 0.25)) {
			$args->{time} = time;
			$ai_v{'npc_talk'}{'time'} = time + $timeout{'ai_npcTalk'}{'timeout'} + 5;

			if ($config{autoTalkCont}) {
				while ($args->{steps}[0] =~ /c/i) {
					shift @{$args->{steps}};
				}
			}

			if ($args->{steps}[0] =~ /w(\d+)/i) {
				my $time = $1;
				$ai_v{'npc_talk'}{'time'} = time + $time;
				$args->{time} = time + $time;
			} elsif ( $args->{steps}[0] =~ /^t=(.*)/i ) {
				sendTalkText(\$remote_socket, $args->{ID}, $1);
			} elsif ($args->{steps}[0] =~ /d(\d+)/i) {
				sendTalkNumber(\$remote_socket, $args->{ID}, $1);
			} elsif ( $args->{steps}[0] =~ /x/i ) {
				sendTalk(\$remote_socket, $args->{ID});
			} elsif ( $args->{steps}[0] =~ /c/i ) {
				sendTalkContinue(\$remote_socket, $args->{ID});
			} elsif ( $args->{steps}[0] =~ /r(\d+)/i ) {
				sendTalkResponse(\$remote_socket, $args->{ID}, $1+1);
			} elsif ( $args->{steps}[0] =~ /n/i ) {
				sendTalkCancel(\$remote_socket, $args->{ID});
				$ai_v{'npc_talk'}{'time'} = time;
				$args->{time}   = time;
			} elsif ( $args->{steps}[0] =~ /b/i ) {
				sendGetStoreList(\$remote_socket, $args->{ID});
			}
			shift @{$args->{steps}};
		}
	}


	##### WAYPOINT ####

	if (AI::action eq "waypoint") {
		my $args = AI::args;

		if (defined $args->{walkedTo}) {
			message "Arrived at waypoint $args->{walkedTo}\n", "waypoint";
			Plugins::callHook('waypoint/arrived', {
				points => $args->{points},
				index => $args->{walkedTo}
			});
			delete $args->{walkedTo};

		} elsif ($args->{index} > -1 && $args->{index} < @{$args->{points}}) {
			# Walk to the next point
			my $point = $args->{points}[$args->{index}];
			message "Walking to waypoint $args->{index}: $maps_lut{$point->{map}}($point->{map}): $point->{x},$point->{y}\n", "waypoint";
			$args->{walkedTo} = $args->{index};
			$args->{index} += $args->{inc};

			my $result = ai_route($point->{map}, $point->{x}, $point->{y},
				attackOnRoute => $args->{attackOnRoute},
				tags => "waypoint");
			if (!$result) {
				error "Unable to calculate how to walk to $point->{map} ($point->{x}, $point->{y})\n";
				AI::dequeue;
			}

		} else {
			# We're at the end of the waypoint.
			# Figure out what to do now.
			if (!$args->{whenDone}) {
				AI::dequeue;

			} elsif ($args->{whenDone} eq 'repeat') {
				$args->{index} = 0;

			} elsif ($args->{whenDone} eq 'reverse') {
				if ($args->{inc} < 0) {
					$args->{inc} = 1;
					$args->{index} = 1;
					$args->{index} = 0 if ($args->{index} > $#{$args->{points}});
				} else {
					$args->{inc} = -1;
					$args->{index} -= 2;
					$args->{index} = 0 if ($args->{index} < 0);
				}
			}
		}
	}


	##### DEAD #####

	if (AI::action eq "dead" && !$char->{dead}) {
		AI::dequeue;

		if ($char->{resurrected}) {
			# We've been resurrected
			$char->{resurrected} = 0;

		} else {
			# Force storage after death
			AI::queue("storageAuto") if $config{storageAuto};
		}

	} elsif (AI::action ne "dead" && $char->{'dead'}) {
		AI::clear();
		AI::queue("dead");
	}

	if (AI::action eq "dead" && $config{dcOnDeath} != -1 && time - $char->{dead_time} >= $timeout{ai_dead_respawn}{timeout}) {
		sendRespawn(\$remote_socket);
		$char->{'dead_time'} = time;
	}

	if (AI::action eq "dead" && $config{dcOnDeath} && $config{dcOnDeath} != -1) {
		message "Disconnecting on death!\n";
		$quit = 1;
	}

	##### STORAGE GET #####
	# Get one or more items from storage.

	if (AI::action eq "storageGet" && timeOut(AI::args)) {
		my $item = shift @{AI::args->{items}};
		my $amount = AI::args->{max};

		if (!$amount || $amount > $item->{amount}) {
			$amount = $item->{amount};
		}
		sendStorageGet(\$remote_socket, $item->{index}, $amount) if $storage{opened};
		AI::args->{time} = time;
		AI::dequeue if !@{AI::args->{items}};
	}

	#### CART ADD ####
	# Put one or more items in cart.
	# TODO: check for cart weight & number of items

	if (AI::action eq "cartAdd" && timeOut(AI::args)) {
		my $item = AI::args->{items}[0];
		my $i = $item->{index};
		my $amount = $item->{amount};

		if (!$amount || $amount > $char->{inventory}[$i]{amount}) {
			$amount = $char->{inventory}[$i]{amount};
		}
		sendCartAdd(\$remote_socket, $char->{inventory}[$i]{index}, $amount);
		shift @{AI::args->{items}};
		AI::args->{time} = time;
		AI::dequeue if (@{AI::args->{items}} <= 0);
	}

	#### CART Get ####
	# Get one or more items from cart.

	if (AI::action eq "cartGet" && timeOut(AI::args)) {
		my $item = AI::args->{items}[0];
		my $i = $item->{index};
		my $amount = $item->{amount};

		if (!$amount || $amount > $cart{inventory}[$i]{amount}) {
			$amount = $cart{inventory}[$i]{amount};
		}
		sendCartGet(\$remote_socket, $i, $amount);
		shift @{AI::args->{items}};
		AI::args->{time} = time;
		AI::dequeue if (@{AI::args->{items}} <= 0);
	}

	##### DROPPING #####
	# Drop one or more items from inventory.

	if (AI::action eq "drop" && timeOut(AI::args)) {
		my $item = AI::args->{'items'}[0];
		my $amount = AI::args->{max};

		drop($item, $amount);
		shift @{AI::args->{items}};
		AI::args->{time} = time;
		AI::dequeue if (@{AI::args->{'items'}} <= 0);
	}

	##### DELAYED-TELEPORT #####

	if ($ai_v{temp}{teleport}{lv}) {
		useTeleport($ai_v{temp}{teleport}{lv});
	}


	####### AUTO MAKE ARROW #######
	if ((AI::isIdle || AI::is(qw/route move autoBuy storageAuto follow sitAuto items_take items_gather/))
	 && timeOut($AI::Timeouts::autoArrow, 0.2) && $config{autoMakeArrows} && defined binFind(\@skillsID, 'AC_MAKINGARROW') ) {
		my $max = @arrowCraftID;
		for (my $i = 0; $i < $max; $i++) {
			my $item = $char->{inventory}[$arrowCraftID[$i]];
			next if (!$item);
			if ($arrowcraft_items{lc($item->{name})}) {
				sendArrowCraft(\$remote_socket, $item->{nameID});
				debug "Making item\n", "ai_makeItem";
				last;
			}
		}
		$AI::Timeouts::autoArrow = time;
	}

	if ($config{autoMakeArrows} && $useArrowCraft) {
		if (defined binFind(\@skillsID, 'AC_MAKINGARROW')) {
			ai_skillUse('AC_MAKINGARROW', 1, 0, 0, $accountID);
		}
		undef $useArrowCraft;
	}


	#storageAuto - chobit aska 20030128
	#####AUTO STORAGE#####

	AUTOSTORAGE: {

	if (AI::is("", "route", "sitAuto", "follow") &&
	    $config{'storageAuto'} && $config{'storageAuto_npc'} ne "" &&
		(($config{'itemsMaxWeight_sellOrStore'} &&
		 percent_weight($char) >= $config{'itemsMaxWeight_sellOrStore'}) ||
		 (!$config{'itemsMaxWeight_sellOrStore'} &&
		  percent_weight($char) >= $config{'itemsMaxWeight'})) &&
		!AI::inQueue("storageAuto") && time > $ai_v{'inventory_time'}) {

		# Initiate autostorage when the weight limit has been reached
		my $routeIndex = AI::findAction("route");
		my $attackOnRoute = 2;
		$attackOnRoute = AI::args($routeIndex)->{attackOnRoute} if (defined $routeIndex);
		# Only autostorage when we're on an attack route, or not moving
		if ($attackOnRoute > 1 && ai_storageAutoCheck()) {
			AI::queue("storageAuto");
		}

	} elsif (AI::is("", "route", "attack") &&
	         $config{'storageAuto'} && $config{'storageAuto_npc'} ne "" &&
		 !AI::inQueue("storageAuto") &&
		 timeOut($timeout{'ai_storageAuto'})) {

		# Initiate autostorage when we're low on some item, and getAuto is set
		my $found;
		my $i = 0;
		while ($config{"getAuto_$i"}) {
			my $invIndex = findIndexString_lc($char->{inventory}, "name", $config{"getAuto_$i"});
			if ($config{"getAuto_${i}_minAmount"} ne "" && $config{"getAuto_${i}_maxAmount"} ne ""
			   && !$config{"getAuto_${i}_passive"}
			   && (!defined($invIndex)
				|| ($char->{inventory}[$invIndex]{amount} <= $config{"getAuto_${i}_minAmount"} 
				 && $char->{inventory}[$invIndex]{amount} < $config{"getAuto_${i}_maxAmount"}))
			   && (findKeyString(\%storage, "name", $config{"getAuto_$i"}) ne "" || !$storage{opened})
			) {
				$found = 1;
				last;
			}
			$i++;
		}

		my $routeIndex = AI::findAction("route");
		my $attackOnRoute;
		$attackOnRoute = AI::args($routeIndex)->{attackOnRoute} if (defined $routeIndex);

		# Only autostorage when we're on an attack route, or not moving
		if ((!defined($routeIndex) || $attackOnRoute > 1) && $found) {
			AI::queue("storageAuto");
		}
		$timeout{'ai_storageAuto'}{'time'} = time;
	}


	if (AI::action eq "storageAuto" && AI::args->{done}) {
		# Autostorage finished; trigger sellAuto unless autostorage was already triggered by it
		my $forcedBySell = AI::args->{forcedBySell};
		my $forcedByBuy = AI::args->{forcedByBuy};
		AI::dequeue;
		if ($forcedByBuy) {
			AI::queue("sellAuto", {forcedByBuy => 1});
		} elsif (!$forcedBySell && ai_sellAutoCheck() && $config{sellAuto}) {
			AI::queue("sellAuto", {forcedByStorage => 1});
		}

	} elsif (AI::action eq "storageAuto" && timeOut($timeout{'ai_storageAuto'})) {
		# Main autostorage block
		my $args = AI::args;

		# Stop if the specified NPC is invalid
		$args->{npc} = {};
		getNPCInfo($config{'storageAuto_npc'}, $args->{npc});
		if (!defined($args->{npc}{ok})) {
			$args->{done} = 1;
			last AUTOSTORAGE;
		}

		# Determine whether we have to move to the NPC
		my $do_route;
		if ($field{'name'} ne $args->{npc}{map}) {
			$do_route = 1;
		} else {
			my $distance = distance($args->{npc}{pos}, $char->{pos_to});
			if ($distance > $config{'storageAuto_distance'}) {
				$do_route = 1;
			}
		}

		if ($do_route) {
			if ($args->{warpedToSave} && !$args->{mapChanged} && !timeOut($args->{warpStart}, 8)) {
				undef $args->{warpedToSave};
			}

			# If warpToBuyOrSell is set, warp to saveMap if we haven't done so
			message "$args->{warpedToSave}\n";
			if ($config{'saveMap'} ne "" && $config{'saveMap_warpToBuyOrSell'} && !$args->{warpedToSave}
			&& !$cities_lut{$field{'name'}.'.rsw'} && $config{'saveMap'} ne $field{name}) {
				$args->{warpedToSave} = 1;
				# If we still haven't warped after a certain amount of time, fallback to walking
				$args->{warpStart} = time unless $args->{warpStart};
				message "Teleporting to auto-storage\n", "teleport";
				useTeleport(2);
				$timeout{'ai_storageAuto'}{'time'} = time;
			} else {
				# warpToBuyOrSell is not set, or we've already warped, or timed out. Walk to the NPC
				message "Calculating auto-storage route to: $maps_lut{$args->{npc}{map}.'.rsw'}($args->{npc}{map}): $args->{npc}{pos}{x}, $args->{npc}{pos}{y}\n", "route";
				ai_route($args->{npc}{map}, $args->{npc}{pos}{x}, $args->{npc}{pos}{y},
					attackOnRoute => 1,
					distFromGoal => $config{'storageAuto_distance'});
			}
		} else {
			# Talk to NPC if we haven't done so
			if (!defined($args->{sentStore})) {
				if ($config{'storageAuto_npc_type'} eq "" || $config{'storageAuto_npc_type'} eq "1") {
					warning "Warning storageAuto has changed. Please read News.txt\n" if ($config{'storageAuto_npc_type'} eq "");
					$config{'storageAuto_npc_steps'} = "c r1 n";
					debug "Using standard iRO npc storage steps.\n", "npc";				
				} elsif ($config{'storageAuto_npc_type'} eq "2") {
					$config{'storageAuto_npc_steps'} = "c c r1 n";
					debug "Using iRO comodo (location) npc storage steps.\n", "npc";
				} elsif ($config{'storageAuto_npc_type'} eq "3") {
					message "Using storage steps defined in config.\n", "info";
				} elsif ($config{'storageAuto_npc_type'} ne "" && $config{'storageAuto_npc_type'} ne "1" && $config{'storageAuto_npc_type'} ne "2" && $config{'storageAuto_npc_type'} ne "3") {
					error "Something is wrong with storageAuto_npc_type in your config.\n";
				}

				delete $ai_v{temp}{storage_opened};
				$args->{sentStore} = 1;

				if (defined $args->{npc}{id}) { 
					ai_talkNPC(ID => $args->{npc}{id}, $config{'storageAuto_npc_steps'}); 
				} else {
					ai_talkNPC($args->{npc}{pos}{x}, $args->{npc}{pos}{y}, $config{'storageAuto_npc_steps'}); 
				}

				# NPC talk retry
				$AI::Timeouts::storageOpening = time;
				$timeout{'ai_storageAuto'}{'time'} = time;
				last AUTOSTORAGE;
			}

			if (!defined $ai_v{temp}{storage_opened}) {
				# NPC talk retry
				if (timeOut($AI::Timeouts::storageOpening, 40)) {
					undef $args->{sentStore};
					debug "Retry talking to autostorage NPC.\n", "npc";
				}

				# Storage not yet opened; stop and wait until it's open
				last AUTOSTORAGE;
			}

			if (!$args->{getStart}) {
				$args->{done} = 1;
				$args->{nextItem} = 0 unless $args->{nextItem};
				for (my $i = $ai_seq_args[0]{'nextItem'}; $i < @{$chars[$config{'char'}]{'inventory'}}; $i++) {
					next if (!%{$chars[$config{'char'}]{'inventory'}[$i]} || $chars[$config{'char'}]{'inventory'}[$i]{'equipped'});
					my $store = $items_control{'all'}{'storage'};
					$store = $items_control{lc($chars[$config{'char'}]{'inventory'}[$i]{'name'})}{'storage'} if ($items_control{lc($chars[$config{'char'}]{'inventory'}[$i]{'name'})});
					my $keep = $items_control{'all'}{'keep'};
					$keep = $items_control{lc($chars[$config{'char'}]{'inventory'}[$i]{'name'})}{'keep'} if ($items_control{lc($chars[$config{'char'}]{'inventory'}[$i]{'name'})});
					debug "AUTOSTORAGE: $char->{inventory}[$i]{name} x $char->{inventory}[$i]{amount} - store = $store, keep = $keep\n", "storage";
					if ($store && $chars[$config{'char'}]{'inventory'}[$i]{'amount'} > $keep) {
						if ($ai_seq_args[0]{'lastIndex'} ne "" && $ai_seq_args[0]{'lastIndex'} == $chars[$config{'char'}]{'inventory'}[$i]{'index'}
							&& timeOut(\%{$timeout{'ai_storageAuto_giveup'}})) {
							last AUTOSTORAGE;
						} elsif ($ai_seq_args[0]{'lastIndex'} eq "" || $ai_seq_args[0]{'lastIndex'} != $chars[$config{'char'}]{'inventory'}[$i]{'index'}) {
							$timeout{'ai_storageAuto_giveup'}{'time'} = time;
						}
						undef $ai_seq_args[0]{'done'};
						$ai_seq_args[0]{'lastIndex'} = $chars[$config{'char'}]{'inventory'}[$i]{'index'};
						sendStorageAdd(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$i]{'index'}, $chars[$config{'char'}]{'inventory'}[$i]{'amount'} - $keep);
						$timeout{'ai_storageAuto'}{'time'} = time;
						$ai_seq_args[0]{'nextItem'} = $i + 1;
						last AUTOSTORAGE;
					}
				}
			}


			# getAuto begin

			if (!$args->{getStart} && $args->{done} == 1) {
				$args->{getStart} = 1;
				undef $args->{done};
				$args->{index} = 0;
				$args->{retry} = 0;
				last AUTOSTORAGE;
			}
			
			if (defined($args->{getStart}) && $args->{done} != 1) {

				my %item;
				while (exists $config{"getAuto_$ai_seq_args[0]{index}"}) {
					if (!$config{"getAuto_$ai_seq_args[0]{index}"}) {
						$ai_seq_args[0]{index}++;
						next;
					}

					undef %item;
					$item{name} = $config{"getAuto_$ai_seq_args[0]{index}"};
					$item{inventory}{index} = findIndexString_lc(\@{$chars[$config{char}]{inventory}}, "name", $item{name});
					$item{inventory}{amount} = ($item{inventory}{index} ne "") ? $chars[$config{char}]{inventory}[$item{inventory}{index}]{amount} : 0;
					$item{storage}{index} = findKeyString(\%storage, "name", $item{name});
					$item{storage}{amount} = ($item{storage}{index} ne "")? $storage{$item{storage}{index}}{amount} : 0;
					$item{max_amount} = $config{"getAuto_$ai_seq_args[0]{index}"."_maxAmount"};
					$item{amount_needed} = $item{max_amount} - $item{inventory}{amount};
					
					if ($item{amount_needed} > 0) {
						$item{amount_get} = ($item{storage}{amount} >= $item{amount_needed})? $item{amount_needed} : $item{storage}{amount};
					}
					
					if (($item{amount_get} > 0) && ($ai_seq_args[0]{retry} < 3)) {
						message "Attempt to get $item{amount_get} x $item{name} from storage, retry: $ai_seq_args[0]{retry}\n", "storage", 1;
						sendStorageGet(\$remote_socket, $item{storage}{index}, $item{amount_get});
						$timeout{ai_storageAuto}{time} = time;
						$ai_seq_args[0]{retry}++;
						last AUTOSTORAGE;
						
						# we don't inc the index when amount_get is more then 0, this will enable a way of retrying
						# on next loop if it fails this time
					}
					
					if ($item{storage}{amount} < $item{amount_needed}) {
						warning "storage: $item{name} out of stock\n";
					}
	
					# otherwise, increment the index
					$ai_seq_args[0]{index}++;
					$ai_seq_args[0]{retry} = 0;
				}
			}

			sendStorageClose(\$remote_socket);
			$args->{done} = 1;
		}
	}
	} #END OF BLOCK AUTOSTORAGE



	#####AUTO SELL#####

	AUTOSELL: {

	if (($ai_seq[0] eq "" || $ai_seq[0] eq "route" || $ai_seq[0] eq "sitAuto" || $ai_seq[0] eq "follow") && $config{'sellAuto'} && $config{'sellAuto_npc'} ne ""
	  && (($config{'itemsMaxWeight_sellOrStore'} && percent_weight(\%{$chars[$config{'char'}]}) >= $config{'itemsMaxWeight_sellOrStore'})
	      || (!$config{'itemsMaxWeight_sellOrStore'} && percent_weight(\%{$chars[$config{'char'}]}) >= $config{'itemsMaxWeight'})
	  )) {
		$ai_v{'temp'}{'ai_route_index'} = binFind(\@ai_seq, "route");
		if ($ai_v{'temp'}{'ai_route_index'} ne "") {
			$ai_v{'temp'}{'ai_route_attackOnRoute'} = $ai_seq_args[$ai_v{'temp'}{'ai_route_index'}]{'attackOnRoute'};
		}
		if (!($ai_v{'temp'}{'ai_route_index'} ne "" && $ai_v{'temp'}{'ai_route_attackOnRoute'} <= 1) && ai_sellAutoCheck()) {
			unshift @ai_seq, "sellAuto";
			unshift @ai_seq_args, {};
		}
	}

	if ($ai_seq[0] eq "sellAuto" && $ai_seq_args[0]{'done'}) {
		$ai_v{'temp'}{'var'} = $ai_seq_args[0]{'forcedByBuy'};
		$ai_v{'temp'}{'var2'} = $ai_seq_args[0]{'forcedByStorage'};
		message "Auto-sell sequence completed.\n", "success";
		AI::dequeue;
		if ($ai_v{'temp'}{'var2'}) {
			unshift @ai_seq, "buyAuto";
			unshift @ai_seq_args, {forcedByStorage => 1};
		} elsif (!$ai_v{'temp'}{'var'}) {
			unshift @ai_seq, "buyAuto";
			unshift @ai_seq_args, {forcedBySell => 1};
		}
	} elsif ($ai_seq[0] eq "sellAuto" && timeOut(\%{$timeout{'ai_sellAuto'}})) {
		getNPCInfo($config{'sellAuto_npc'}, \%{$ai_seq_args[0]{'npc'}});
		if (!defined($ai_seq_args[0]{'npc'}{'ok'})) {
			$ai_seq_args[0]{'done'} = 1;
			last AUTOSELL;
		}

		undef $ai_v{'temp'}{'do_route'};
		if ($field{'name'} ne $ai_seq_args[0]{'npc'}{'map'}) {
			$ai_v{'temp'}{'do_route'} = 1;
		} else {
			$ai_v{'temp'}{'distance'} = distance(\%{$ai_seq_args[0]{'npc'}{'pos'}}, \%{$chars[$config{'char'}]{'pos_to'}});
			if ($ai_v{'temp'}{'distance'} > $config{'sellAuto_distance'}) {
				$ai_v{'temp'}{'do_route'} = 1;
			}
		}
		if ($ai_v{'temp'}{'do_route'}) {
			if ($ai_seq_args[0]{'warpedToSave'} && !$ai_seq_args[0]{'mapChanged'}) {
				undef $ai_seq_args[0]{'warpedToSave'};
			}

			if ($config{'saveMap'} ne "" && $config{'saveMap_warpToBuyOrSell'} && !$ai_seq_args[0]{'warpedToSave'} 
			&& !$cities_lut{$field{'name'}.'.rsw'} && $config{'saveMap'} ne $field{name}) {
				$ai_seq_args[0]{'warpedToSave'} = 1;
				message "Teleporting to auto-sell\n", "teleport";
				useTeleport(2);
				$timeout{'ai_sellAuto'}{'time'} = time;
			} else {
				message "Calculating auto-sell route to: $maps_lut{$ai_seq_args[0]{'npc'}{'map'}.'.rsw'}($ai_seq_args[0]{'npc'}{'map'}): $ai_seq_args[0]{'npc'}{'pos'}{'x'}, $ai_seq_args[0]{'npc'}{'pos'}{'y'}\n", "route";
				ai_route($ai_seq_args[0]{'npc'}{'map'}, $ai_seq_args[0]{'npc'}{'pos'}{'x'}, $ai_seq_args[0]{'npc'}{'pos'}{'y'},
					attackOnRoute => 1,
					distFromGoal => $config{'sellAuto_distance'},
					noSitAuto => 1);
			}
		} else {
			if (!defined($ai_seq_args[0]{'sentSell'})) {
				$ai_seq_args[0]{'sentSell'} = 1;
				
				if (defined $ai_seq_args[0]{'npc'}{'id'}) { 
					ai_talkNPC(ID => $ai_seq_args[0]{'npc'}{'id'}, "b"); 
				} else {
					ai_talkNPC($ai_seq_args[0]{'npc'}{'pos'}{'x'}, $ai_seq_args[0]{'npc'}{'pos'}{'y'}, "b"); 
				}
				last AUTOSELL;
			}
			$ai_seq_args[0]{'done'} = 1;
			for ($i = 0; $i < @{$chars[$config{'char'}]{'inventory'}};$i++) {
				next if (!%{$chars[$config{'char'}]{'inventory'}[$i]} || $chars[$config{'char'}]{'inventory'}[$i]{'equipped'});
				my $sell = $items_control{'all'}{'sell'};
				$sell = $items_control{lc($chars[$config{'char'}]{'inventory'}[$i]{'name'})}{'sell'} if ($items_control{lc($chars[$config{'char'}]{'inventory'}[$i]{'name'})});
				my $keep = $items_control{'all'}{'keep'};
				$keep = $items_control{lc($chars[$config{'char'}]{'inventory'}[$i]{'name'})}{'keep'} if ($items_control{lc($chars[$config{'char'}]{'inventory'}[$i]{'name'})});
				if ($sell && $chars[$config{'char'}]{'inventory'}[$i]{'amount'} > $keep) {
					if ($ai_seq_args[0]{'lastIndex'} ne "" && $ai_seq_args[0]{'lastIndex'} == $chars[$config{'char'}]{'inventory'}[$i]{'index'}
						&& timeOut(\%{$timeout{'ai_sellAuto_giveup'}})) {
						last AUTOSELL;
					} elsif ($ai_seq_args[0]{'lastIndex'} eq "" || $ai_seq_args[0]{'lastIndex'} != $chars[$config{'char'}]{'inventory'}[$i]{'index'}) {
						$timeout{'ai_sellAuto_giveup'}{'time'} = time;
					}
					undef $ai_seq_args[0]{'done'};
					$ai_seq_args[0]{'lastIndex'} = $chars[$config{'char'}]{'inventory'}[$i]{'index'};
					sendSell(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$i]{'index'}, $chars[$config{'char'}]{'inventory'}[$i]{'amount'} - $keep);
					$timeout{'ai_sellAuto'}{'time'} = time;
					last AUTOSELL;
				}
			}
		}
	}

	} #END OF BLOCK AUTOSELL



	#####AUTO BUY#####

	AUTOBUY: {

	if (($ai_seq[0] eq "" || $ai_seq[0] eq "route" || $ai_seq[0] eq "follow") && timeOut(\%{$timeout{'ai_buyAuto'}}) && time > $ai_v{'inventory_time'}) {
		undef $ai_v{'temp'}{'found'};
		$i = 0;
		while (1) {
			last if (!$config{"buyAuto_$i"} || !$config{"buyAuto_$i"."_npc"});
			$ai_v{'temp'}{'invIndex'} = findIndexString_lc(\@{$chars[$config{'char'}]{'inventory'}}, "name", $config{"buyAuto_$i"});
			if ($config{"buyAuto_$i"."_minAmount"} ne "" && $config{"buyAuto_$i"."_maxAmount"} ne ""
				&& ($ai_v{'temp'}{'invIndex'} eq ""
				|| ($chars[$config{'char'}]{'inventory'}[$ai_v{'temp'}{'invIndex'}]{'amount'} <= $config{"buyAuto_$i"."_minAmount"}
				&& $chars[$config{'char'}]{'inventory'}[$ai_v{'temp'}{'invIndex'}]{'amount'} < $config{"buyAuto_$i"."_maxAmount"}))) {
				$ai_v{'temp'}{'found'} = 1;
			}
			$i++;
		}
		$ai_v{'temp'}{'ai_route_index'} = binFind(\@ai_seq, "route");
		if ($ai_v{'temp'}{'ai_route_index'} ne "") {
			$ai_v{'temp'}{'ai_route_attackOnRoute'} = $ai_seq_args[$ai_v{'temp'}{'ai_route_index'}]{'attackOnRoute'};
		}
		if (!($ai_v{'temp'}{'ai_route_index'} ne "" && $ai_v{'temp'}{'ai_route_attackOnRoute'} <= 1) && $ai_v{'temp'}{'found'}) {
			unshift @ai_seq, "buyAuto";
			unshift @ai_seq_args, {};
		}
		$timeout{'ai_buyAuto'}{'time'} = time;
	}

	if ($ai_seq[0] eq "buyAuto" && $ai_seq_args[0]{'done'}) {
		# buyAuto finished
		$ai_v{'temp'}{'var'} = $ai_seq_args[0]{'forcedBySell'};
		$ai_v{'temp'}{'var2'} = $ai_seq_args[0]{'forcedByStorage'};
		shift @ai_seq;
		shift @ai_seq_args;

		if ($ai_v{'temp'}{'var'} && $config{storageAuto}) {
			unshift @ai_seq, "storageAuto";
			unshift @ai_seq_args, {forcedBySell => 1};
		} elsif (!$ai_v{'temp'}{'var2'} && $config{storageAuto}) {
			unshift @ai_seq, "storageAuto";
			unshift @ai_seq_args, {forcedByBuy => 1};
		}

	} elsif ($ai_seq[0] eq "buyAuto" && timeOut(\%{$timeout{'ai_buyAuto_wait'}}) && timeOut(\%{$timeout{'ai_buyAuto_wait_buy'}})) {
		$i = 0;
		undef $ai_seq_args[0]{'index'};
		
		while (1) {
			last if (!$config{"buyAuto_$i"});
			$ai_seq_args[0]{'invIndex'} = findIndexString_lc(\@{$chars[$config{'char'}]{'inventory'}}, "name", $config{"buyAuto_$i"});
			if (!$ai_seq_args[0]{'index_failed'}{$i} && $config{"buyAuto_$i"."_maxAmount"} ne "" && ($ai_seq_args[0]{'invIndex'} eq "" 
				|| $chars[$config{'char'}]{'inventory'}[$ai_seq_args[0]{'invIndex'}]{'amount'} < $config{"buyAuto_$i"."_maxAmount"})) {

				getNPCInfo($config{"buyAuto_$i"."_npc"}, \%{$ai_seq_args[0]{'npc'}});
				if (defined $ai_seq_args[0]{'npc'}{'ok'}) {
					$ai_seq_args[0]{'index'} = $i;
				}
				last;
			}
			$i++;
		}
		if ($ai_seq_args[0]{'index'} eq ""
			|| ($ai_seq_args[0]{'lastIndex'} ne "" && $ai_seq_args[0]{'lastIndex'} == $ai_seq_args[0]{'index'}
			&& timeOut(\%{$timeout{'ai_buyAuto_giveup'}}))) {
			$ai_seq_args[0]{'done'} = 1;
			last AUTOBUY;
		}
		undef $ai_v{'temp'}{'do_route'};
		if ($field{'name'} ne $ai_seq_args[0]{'npc'}{'map'}) {
			$ai_v{'temp'}{'do_route'} = 1;			
		} else {
			$ai_v{'temp'}{'distance'} = distance(\%{$ai_seq_args[0]{'npc'}{'pos'}}, \%{$chars[$config{'char'}]{'pos_to'}});
			if ($ai_v{'temp'}{'distance'} > $config{"buyAuto_$ai_seq_args[0]{'index'}"."_distance"}) {
				$ai_v{'temp'}{'do_route'} = 1;
			}
		}
		if ($ai_v{'temp'}{'do_route'}) {
			if ($ai_seq_args[0]{'warpedToSave'} && !$ai_seq_args[0]{'mapChanged'}) {
				undef $ai_seq_args[0]{'warpedToSave'};
			}

			if ($config{'saveMap'} ne "" && $config{'saveMap_warpToBuyOrSell'} && !$ai_seq_args[0]{'warpedToSave'} 
			&& !$cities_lut{$field{'name'}.'.rsw'} && $config{'saveMap'} ne $field{name}) {
				$ai_seq_args[0]{'warpedToSave'} = 1;
				message "Teleporting to auto-buy\n", "teleport";
				useTeleport(2);
				$timeout{'ai_buyAuto_wait'}{'time'} = time;
			} else {
				message qq~Calculating auto-buy route to: $maps_lut{$ai_seq_args[0]{'npc'}{'map'}.'.rsw'}($ai_seq_args[0]{'npc'}{'map'}): $ai_seq_args[0]{'npc'}{'pos'}{'x'}, $ai_seq_args[0]{'npc'}{'pos'}{'y'}\n~, "route";
				ai_route($ai_seq_args[0]{'npc'}{'map'}, $ai_seq_args[0]{'npc'}{'pos'}{'x'}, $ai_seq_args[0]{'npc'}{'pos'}{'y'},
					attackOnRoute => 1,
					distFromGoal => $config{"buyAuto_$ai_seq_args[0]{'index'}"."_distance"});
			}
		} else {
			if ($ai_seq_args[0]{'lastIndex'} eq "" || $ai_seq_args[0]{'lastIndex'} != $ai_seq_args[0]{'index'}) {
				undef $ai_seq_args[0]{'itemID'};
				if ($config{"buyAuto_$ai_seq_args[0]{'index'}"."_npc"} != $config{"buyAuto_$ai_seq_args[0]{'lastIndex'}"."_npc"}) {
					undef $ai_seq_args[0]{'sentBuy'};
				}
				$timeout{'ai_buyAuto_giveup'}{'time'} = time;
			}
			$ai_seq_args[0]{'lastIndex'} = $ai_seq_args[0]{'index'};
			if ($ai_seq_args[0]{'itemID'} eq "") {
				foreach (keys %items_lut) {
					if (lc($items_lut{$_}) eq lc($config{"buyAuto_$ai_seq_args[0]{'index'}"})) {
						$ai_seq_args[0]{'itemID'} = $_;
					}
				}
				if ($ai_seq_args[0]{'itemID'} eq "") {
					$ai_seq_args[0]{'index_failed'}{$ai_seq_args[0]{'index'}} = 1;
					debug "autoBuy index $ai_seq_args[0]{'index'} failed\n", "npc";
					last AUTOBUY;
				}
			}

			if (!defined($ai_seq_args[0]{'sentBuy'})) {
				$ai_seq_args[0]{'sentBuy'} = 1;
				$timeout{'ai_buyAuto_wait'}{'time'} = time;
				if (defined $ai_seq_args[0]{'npc'}{'id'}) { 
					ai_talkNPC(ID => $ai_seq_args[0]{'npc'}{'id'}, "b"); 
				} else {
					ai_talkNPC($ai_seq_args[0]{'npc'}{'pos'}{'x'}, $ai_seq_args[0]{'npc'}{'pos'}{'y'}, "b"); 
				}
				last AUTOBUY;
			}
			if ($ai_seq_args[0]{'invIndex'} ne "") {
				sendBuy(\$remote_socket, $ai_seq_args[0]{'itemID'}, $config{"buyAuto_$ai_seq_args[0]{'index'}"."_maxAmount"} - $chars[$config{'char'}]{'inventory'}[$ai_seq_args[0]{'invIndex'}]{'amount'});
			} else {
				sendBuy(\$remote_socket, $ai_seq_args[0]{'itemID'}, $config{"buyAuto_$ai_seq_args[0]{'index'}"."_maxAmount"});
			}
			$timeout{'ai_buyAuto_wait_buy'}{'time'} = time;
		}
	}

	} #END OF BLOCK AUTOBUY


	##### AUTO-CART ADD/GET ####

	if ((AI::isIdle || AI::is(qw/route move autoBuy storageAuto follow sitAuto items_take items_gather/)) && timeOut($AI::Timeouts::autoCart, 2)) {
		my $hasCart = 0;
		if ($char->{statuses}) {
			foreach (keys %{$char->{statuses}}) {
				if ($_ =~ /^Level \d Cart$/) {
					$hasCart = 1;
					last;
				}
			}
		}

		if ($hasCart) {
			my @addItems;
			my @getItems;
			my $inventory = $char->{inventory};
			my $cartInventory = $cart{inventory};
			my $max;

			$max = @{$inventory};
			for (my $i = 0; $i < $max; $i++) {
				my $item = $inventory->[$i];
				next unless ($item);

				my $control = $items_control{'all'};
				$control = $items_control{lc($item->{name})} if ($items_control{lc($item->{name})});

				if ($control->{cart_add} && $item->{amount} > $control->{keep} && !$item->{equipped}) {
					my %obj;
					$obj{index} = $i;
					$obj{amount} = $item->{amount} - $control->{keep};
					push @addItems, \%obj;
					debug "Scheduling $item->{name} ($i) x $obj{amount} for adding to cart\n", "ai_autoCart";
				}
			}
			cartAdd(\@addItems);

			$max = @{$cartInventory};
			for (my $i = 0; $i < $max; $i++) {
				my $cartItem = $cartInventory->[$i];
				next unless ($cartItem);
				my $control = $items_control{'all'};
				$control = $items_control{lc($cartItem->{name})} if ($items_control{lc($cartItem->{name})});
				next unless ($control->{cart_get});

				my $invIndex = findIndexString_lc($inventory, "name", $cartItem->{name});
				my $amount;
				if ($invIndex eq '') {
					$amount = $control->{keep};
				} elsif ($inventory->[$invIndex]{'amount'} < $control->{keep}) {
					$amount = $control->{keep} - $inventory->[$invIndex]{'amount'};
				}
				if ($amount > $cartItem->{amount}) {
					$amount = $cartItem->{amount};
				}
				if ($amount > 0) {
					my %obj;
					$obj{index} = $i;
					$obj{amount} = $amount;
					push @getItems, \%obj;
					debug "Scheduling $cartItem->{name} ($i) x $obj{amount} for getting from cart\n", "ai_autoCart";
				}
			}
			cartGet(\@getItems);
		}
		$AI::Timeouts::autoCart = time;
	}


	##### LOCKMAP #####

	if (AI::isIdle && $config{lockMap} && ($field{name} ne $config{lockMap}
		|| ($config{lockMap_x} ne '' && ($char->{pos_to}{x} < $config{lockMap_x} - $config{lockMap_randX} || $char->{pos_to}{x} > $config{lockMap_x} + $config{lockMap_randX}))
		|| ($config{lockMap_y} ne '' && ($char->{pos_to}{y} < $config{lockMap_y} - $config{lockMap_randY} || $char->{pos_to}{y} > $config{lockMap_y} + $config{lockMap_randY}))
	)) {
		
		if ($maps_lut{$config{lockMap}.'.rsw'} eq '') {
			error "Invalid map specified for lockMap - map $config{lockMap} doesn't exist\n";
			$config{lockMap} = '';
		} else {
			my %args;
			Plugins::callHook("AI/lockMap", \%args);
			if (!$args{return}) {
				my %lockField;
				getField("$Settings::def_field/$config{lockMap}.fld", \%lockField);

				my ($lockX, $lockY);
				my $i = 500;
				if ($config{lockMap_x} ne '' || $config{lockMap_y} ne '') {
					do {
						$lockX = int($config{lockMap_x}) if ($config{lockMap_x} ne '');
						$lockX = int(rand($field{width}) + 1) if (!$config{lockMap_x} && $config{lockMap_y});
						$lockX += (int(rand($config{lockMap_randX}))+1) if ($config{lockMap_randX} ne '');
					    	$lockY = int($config{lockMap_y}) if ($config{lockMap_y} ne '');
					    	$lockY = int(rand($field{width}) + 1) if (!$config{lockMap_y} && $config{lockMap_x});
						$lockY += (int(rand($config{lockMap_randY}))+1) if ($config{lockMap_randY} ne '');
					} while (--$i && !checkFieldWalkable(\%lockField, $lockX, $lockY));
				}
				if (!$i) {
					error "Invalid coordinates specified for lockMap, coordinates are unwalkable\n";
					$config{lockMap} = '';
				} else {
					my $attackOnRoute = 2;
					$attackOnRoute = 1 if ($config{attackAuto_inLockOnly} == 1);
					$attackOnRoute = 0 if ($config{attackAuto_inLockOnly} > 1);
					if (defined $lockX || defined $lockY) {
						message "Calculating lockMap route to: $maps_lut{$config{lockMap}.'.rsw'}($config{lockMap}): $lockX, $lockY\n", "route";
					} else {
						message "Calculating lockMap route to: $maps_lut{$config{lockMap}.'.rsw'}($config{lockMap})\n", "route";
					}
					ai_route($config{lockMap}, $lockX, $lockY, attackOnRoute => $attackOnRoute);
				}
			}
		}
	}


	##### AUTO STATS #####

	if (!$statChanged && $config{statsAddAuto}) {
		# Split list of stats/values
		my @list = split(/ *,+ */, $config{"statsAddAuto_list"});
		my $statAmount;
		my ($num, $st);

		foreach my $item (@list) {
			# Split each stat/value pair
			($num, $st) = $item =~ /(\d+) (str|vit|dex|int|luk|agi)/i;
			$st = lc $st;
			# If stat needs to be raised to match desired amount
                        $statAmount = $char->{$st};
			$statAmount += $char->{"${st}_bonus"} if (!$config{statsAddAuto_dontUseBonus});

			if ($statAmount < $num && $char->{$st} < 99) {
				# If char has enough stat points free to raise stat
				if ($char->{points_free} >= $char->{"points_$st"}) {
					my $ID;
					if ($st eq "str") {
						$ID = 0x0D;
					} elsif ($st eq "agi") {
						$ID = 0x0E;
					} elsif ($st eq "vit") {
						$ID = 0x0F;
					} elsif ($st eq "int") {
						$ID = 0x10;
					} elsif ($st eq "dex") {
						$ID = 0x11;
					} elsif ($st eq "luk") {
						$ID = 0x12;
					}

					$char->{$st} += 1;
					# Raise stat
					sendAddStatusPoint(\$remote_socket, $ID);
					message "Auto-adding stat $st\n";
					# Save which stat was raised, so that when we received the "stat changed" packet (00BC?)
					# we can changed $statChanged back to 0 so that kore will start checking again if stats
					# need to be raised.
					# This basically prevents kore from sending packets to the server super-fast, by only allowing
					# another packet to be sent when $statChanged is back to 0 (when the server has replied with a
					# a stat change)
					$statChanged = $st;
					# After we raise a stat, exit loop				
					last;
				}
				# If stat needs to be changed but char doesn't have enough stat points to raise it then
				# don't raise it, exit loop
				last;
			}
		}
	}

	##### AUTO SKILLS #####	

	if (!$skillsChanged && $config{skillsAddAuto}) {
		# Split list of skills and levels
		my @list = split / *,+ */, lc($config{skillsAddAuto_list});

		foreach my $item (@list) {
			# Split each skill/level pair
			my ($sk, $num) = $item =~ /(.*) (\d+)/;
			my $skill = new Skills(auto => $sk);
			my $handle = $skill->handle;

			# If skill needs to be raised to match desired amount && skill points are available
			if ($skill->id && $char->{points_skill} > 0 && $char->{skills}{$handle}{lv} < $num) {
				# raise skill
				sendAddSkillPoint(\$remote_socket, $skill->id);

				# save which skill was raised, so that when we received the "skill changed" packet (010F?)
				# we can changed $skillChanged back to 0 so that kore will start checking again if skills
				# need to be raised.
				# this basically does what $statChanged does for stats
				$skillChanged = $handle;
				# after we raise a skill, exit loop
				last;
			}
		}
	}


	##### RANDOM WALK #####
	if (AI::isIdle && $config{route_randomWalk} && !$cities_lut{$field{name}.'.rsw'}) {
		my ($randX, $randY);
		my $i = 500;
		do {
			$randX = int(rand($field{width}) + 1);
			$randX = $config{'lockMap_x'} + (int(rand($config{'lockMap_randX'}))+1) if ($config{'lockMap_x'} ne '' && $config{'lockMap_randX'} ne '');
			$randY = int(rand($field{height}) + 1);
			$randY = $config{'lockMap_y'} + (int(rand($config{'lockMap_randY'}))+1) if ($config{'lockMap_y'} ne '' && $config{'lockMap_randY'} ne '');
		} while (--$i && !checkFieldWalkable(\%field, $randX, $randY));
		if (!$i) {
			error "Invalid coordinates specified for randomWalk (coordinates are unwalkable); randomWalk disabled\n";
			$config{route_randomWalk} = 0;
		} else {
			message "Calculating random route to: $maps_lut{$field{name}.'.rsw'}($field{name}): $randX, $randY\n", "route";
			ai_route($field{name}, $randX, $randY,
				maxRouteTime => $config{route_randomWalk_maxRouteTime},
				attackOnRoute => 2,
				noMapRoute => 1);
		}
	}


	##### FOLLOW #####
	
	# TODO: follow should be a 'mode' rather then a sequence, hence all
	# var/flag about follow should be moved to %ai_v

	FOLLOW: {
	last FOLLOW	if (!$config{follow});

	my $followIndex;
	if (($followIndex = binFind(\@ai_seq, "follow")) eq "") {
		# ai_follow will determine if the Target is 'follow-able'
		last FOLLOW if (!ai_follow($config{followTarget}));
	}

	# if we are not following now but master is in the screen...
	if (!defined $ai_seq_args[$followIndex]{'ID'}) {
		foreach (keys %players) {
			if ($players{$_}{'name'} eq $ai_seq_args[$followIndex]{'name'} && !$players{$_}{'dead'}) {
				$ai_seq_args[$followIndex]{'ID'} = $_;
				$ai_seq_args[$followIndex]{'following'} = 1;
				message "Found my master - $ai_seq_args[$followIndex]{'name'}\n", "follow";
				last;
			}
		}
	} elsif (!$ai_seq_args[$followIndex]{'following'} && %{$players{$ai_seq_args[$followIndex]{'ID'}}}) {
		$ai_seq_args[$followIndex]{'following'} = 1;
		delete $ai_seq_args[$followIndex]{'ai_follow_lost'};
		message "Found my master!\n", "follow"
	}

	# if we are not doing anything else now...
	if ($ai_seq[0] eq "follow") {
		if ($ai_seq_args[0]{'suspended'}) {
			if ($ai_seq_args[0]{'ai_follow_lost'}) {
				$ai_seq_args[0]{'ai_follow_lost_end'}{'time'} += time - $ai_seq_args[0]{'suspended'};
			}
			delete $ai_seq_args[0]{'suspended'};
		}
	
		# if we are not doing anything else now...
		if (!$ai_seq_args[$followIndex]{'ai_follow_lost'}) {
			if ($ai_seq_args[$followIndex]{'following'} && $players{$ai_seq_args[$followIndex]{'ID'}}{'pos_to'}) {
				$ai_v{'temp'}{'dist'} = distance(\%{$chars[$config{'char'}]{'pos_to'}}, \%{$players{$ai_seq_args[$followIndex]{'ID'}}{'pos_to'}});
				if ($ai_v{'temp'}{'dist'} > $config{'followDistanceMax'} && timeOut($ai_seq_args[$followIndex]{'move_timeout'}, 0.25)) {
					$ai_seq_args[$followIndex]{'move_timeout'} = time;
					if ($ai_v{'temp'}{'dist'} > 15) {
						ai_route($field{'name'}, $players{$ai_seq_args[$followIndex]{'ID'}}{'pos_to'}{'x'}, $players{$ai_seq_args[$followIndex]{'ID'}}{'pos_to'}{'y'},
							attackOnRoute => 1,
							distFromGoal => $config{'followDistanceMin'});
					} else {
						my $dist = distance(\%{$chars[$config{'char'}]{'pos_to'}}, \%{$players{$ai_seq_args[$followIndex]{'ID'}}{'pos_to'}});
						my (%vec, %pos);
	
						stand() if ($chars[$config{char}]{sitting});
						getVector(\%vec, \%{$players{$ai_seq_args[$followIndex]{'ID'}}{'pos_to'}}, \%{$chars[$config{'char'}]{'pos_to'}});
						moveAlongVector(\%pos, \%{$chars[$config{'char'}]{'pos_to'}}, \%vec, $dist - $config{'followDistanceMin'});
						$timeout{'ai_sit_idle'}{'time'} = time;
						sendMove(\$remote_socket, $pos{'x'}, $pos{'y'});
					}
				}
			}
			
			if ($ai_seq_args[$followIndex]{'following'} && %{$players{$ai_seq_args[$followIndex]{'ID'}}}) {
				if ($config{'followSitAuto'} && $players{$ai_seq_args[$followIndex]{'ID'}}{'sitting'} == 1 && $chars[$config{'char'}]{'sitting'} == 0) {
					sit();
				}
	
				my $dx = $ai_seq_args[$followIndex]{'last_pos_to'}{'x'} - $players{$ai_seq_args[$followIndex]{'ID'}}{'pos_to'}{'x'};
				my $dy = $ai_seq_args[$followIndex]{'last_pos_to'}{'y'} - $players{$ai_seq_args[$followIndex]{'ID'}}{'pos_to'}{'y'};
				$ai_seq_args[$followIndex]{'last_pos_to'}{'x'} = $players{$ai_seq_args[$followIndex]{'ID'}}{'pos_to'}{'x'};
				$ai_seq_args[$followIndex]{'last_pos_to'}{'y'} = $players{$ai_seq_args[$followIndex]{'ID'}}{'pos_to'}{'y'};
				if ($dx != 0 || $dy != 0) {
					lookAtPosition($players{$ai_seq_args[$followIndex]{'ID'}}{'pos_to'}) if ($config{'followFaceDirection'});
				}
			}
		}
	}

	if ($ai_seq[0] eq "follow" && $ai_seq_args[$followIndex]{'following'} && ($players{$ai_seq_args[$followIndex]{'ID'}}{'dead'} || (!%{$players{$ai_seq_args[$followIndex]{'ID'}}} && $players_old{$ai_seq_args[$followIndex]{'ID'}}{'dead'}))) {
		message "Master died.  I'll wait here.\n", "party";
		delete $ai_seq_args[$followIndex]{'following'};
	} elsif ($ai_seq_args[$followIndex]{'following'} && !%{$players{$ai_seq_args[$followIndex]{'ID'}}}) {
		message "I lost my master\n", "follow";
		if ($config{'followBot'}) {
			message "Trying to get him back\n", "follow";
			sendMessage(\$remote_socket, "pm", "move $chars[$config{'char'}]{'pos_to'}{'x'} $chars[$config{'char'}]{'pos_to'}{'y'}", $config{followTarget});
		}

		delete $ai_seq_args[$followIndex]{'following'};

		if ($players_old{$ai_seq_args[$followIndex]{'ID'}}{'disconnected'}) {
			message "My master disconnected\n", "follow";

		} elsif ($players_old{$ai_seq_args[$followIndex]{'ID'}}{'teleported'}) {
			message "My master teleported\n", "follow", 1;

		} elsif ($players_old{$ai_seq_args[$followIndex]{'ID'}}{'disappeared'}) {
			message "Trying to find lost master\n", "follow", 1;

			delete $ai_seq_args[$followIndex]{'ai_follow_lost_char_last_pos'};
			delete $ai_seq_args[$followIndex]{'follow_lost_portal_tried'};
			$ai_seq_args[$followIndex]{'ai_follow_lost'} = 1;
			$ai_seq_args[$followIndex]{'ai_follow_lost_end'}{'timeout'} = $timeout{'ai_follow_lost_end'}{'timeout'};
			$ai_seq_args[$followIndex]{'ai_follow_lost_end'}{'time'} = time;
			getVector(\%{$ai_seq_args[$followIndex]{'ai_follow_lost_vec'}}, \%{$players_old{$ai_seq_args[$followIndex]{'ID'}}{'pos_to'}}, \%{$chars[$config{'char'}]{'pos_to'}});

			#check if player went through portal
			my $first = 1;
			my $foundID;
			my $smallDist;
			foreach (@portalsID) {
				$ai_v{'temp'}{'dist'} = distance(\%{$players_old{$ai_seq_args[$followIndex]{'ID'}}{'pos_to'}}, \%{$portals{$_}{'pos'}});
				if ($ai_v{'temp'}{'dist'} <= 7 && ($first || $ai_v{'temp'}{'dist'} < $smallDist)) {
					$smallDist = $ai_v{'temp'}{'dist'};
					$foundID = $_;
					undef $first;
				}
			}
			$ai_seq_args[$followIndex]{'follow_lost_portalID'} = $foundID;
		} else {
			message "Don't know what happened to Master\n", "follow", 1;
		}
	}

	##### FOLLOW-LOST #####

	if ($ai_seq[0] eq "follow" && $ai_seq_args[$followIndex]{'ai_follow_lost'}) {
		if ($ai_seq_args[$followIndex]{'ai_follow_lost_char_last_pos'}{'x'} == $chars[$config{'char'}]{'pos_to'}{'x'} && $ai_seq_args[$followIndex]{'ai_follow_lost_char_last_pos'}{'y'} == $chars[$config{'char'}]{'pos_to'}{'y'}) {
			$ai_seq_args[$followIndex]{'lost_stuck'}++;
		} else {
			delete $ai_seq_args[$followIndex]{'lost_stuck'};
		}
		%{$ai_seq_args[0]{'ai_follow_lost_char_last_pos'}} = %{$chars[$config{'char'}]{'pos_to'}};

		if (timeOut(\%{$ai_seq_args[$followIndex]{'ai_follow_lost_end'}})) {
			delete $ai_seq_args[$followIndex]{'ai_follow_lost'};
			message "Couldn't find master, giving up\n", "follow";

		} elsif ($players_old{$ai_seq_args[$followIndex]{'ID'}}{'disconnected'}) {
			delete $ai_seq_args[0]{'ai_follow_lost'};
			message "My master disconnected\n", "follow";

		} elsif ($players_old{$ai_seq_args[$followIndex]{'ID'}}{'teleported'}) {
			delete $ai_seq_args[0]{'ai_follow_lost'};
			message "My master teleported\n", "follow";

		} elsif ($ai_seq_args[$followIndex]{'lost_stuck'}) {
			if ($ai_seq_args[$followIndex]{'follow_lost_portalID'} eq "") {
				moveAlongVector(\%{$ai_v{'temp'}{'pos'}}, \%{$chars[$config{'char'}]{'pos_to'}}, \%{$ai_seq_args[$followIndex]{'ai_follow_lost_vec'}}, $config{'followLostStep'} / ($ai_seq_args[$followIndex]{'lost_stuck'} + 1));
				move($ai_v{'temp'}{'pos'}{'x'}, $ai_v{'temp'}{'pos'}{'y'});
			}
		} else {
			if ($ai_seq_args[$followIndex]{'follow_lost_portalID'} ne "") {
				if (%{$portals{$ai_seq_args[$followIndex]{'follow_lost_portalID'}}} && !$ai_seq_args[$followIndex]{'follow_lost_portal_tried'}) {
					$ai_seq_args[$followIndex]{'follow_lost_portal_tried'} = 1;
					%{$ai_v{'temp'}{'pos'}} = %{$portals{$ai_seq_args[$followIndex]{'follow_lost_portalID'}}{'pos'}};
					ai_route($field{'name'}, $ai_v{'temp'}{'pos'}{'x'}, $ai_v{'temp'}{'pos'}{'y'},
						attackOnRoute => 1);
				}
			} else {
				moveAlongVector(\%{$ai_v{'temp'}{'pos'}}, \%{$chars[$config{'char'}]{'pos_to'}}, \%{$ai_seq_args[$followIndex]{'ai_follow_lost_vec'}}, $config{'followLostStep'});
				move($ai_v{'temp'}{'pos'}{'x'}, $ai_v{'temp'}{'pos'}{'y'});
			}
		}
	}

	# Use party information to find master
	if (!exists $ai_seq_args[$followIndex]{following} && !exists $ai_seq_args[$followIndex]{ai_follow_lost}) {
		ai_partyfollow();
	}
	} # end of FOLLOW block
	

	##### AUTO-SIT/SIT/STAND #####

	if ($config{'sitAuto_idle'} && ($ai_seq[0] ne "" && $ai_seq[0] ne "follow")) {
		$timeout{'ai_sit_idle'}{'time'} = time;
	}
	if (($ai_seq[0] eq "" || $ai_seq[0] eq "follow") && $config{'sitAuto_idle'} && !$chars[$config{'char'}]{'sitting'} && timeOut(\%{$timeout{'ai_sit_idle'}}) && (!$config{'shopAuto_open'} || timeOut(\%{$timeout{'ai_shop'}}))) {
		sit();
	}
	if ($ai_seq[0] eq "sitting" && ($chars[$config{'char'}]{'sitting'} || $chars[$config{'char'}]{'skills'}{'NV_BASIC'}{'lv'} < 3)) {
		shift @ai_seq;
		shift @ai_seq_args;
		$timeout{'ai_sit'}{'time'} -= $timeout{'ai_sit'}{'timeout'};
	} elsif ($ai_seq[0] eq "sitting" && !$chars[$config{'char'}]{'sitting'} && timeOut(\%{$timeout{'ai_sit'}}) && timeOut(\%{$timeout{'ai_sit_wait'}})) {
		sendSit(\$remote_socket);
		$timeout{'ai_sit'}{'time'} = time;

		if ($config{'sitAuto_look'}) {
			look($config{'sitAuto_look'});
		}
	}
	if ($ai_seq[0] eq "standing" && !$chars[$config{'char'}]{'sitting'} && !$timeout{'ai_stand_wait'}{'time'}) {
		$timeout{'ai_stand_wait'}{'time'} = time;
	} elsif ($ai_seq[0] eq "standing" && !$chars[$config{'char'}]{'sitting'} && timeOut(\%{$timeout{'ai_stand_wait'}})) {
		shift @ai_seq;
		shift @ai_seq_args;
		undef $timeout{'ai_stand_wait'}{'time'};
		$timeout{'ai_sit'}{'time'} -= $timeout{'ai_sit'}{'timeout'};
	} elsif ($ai_seq[0] eq "standing" && $chars[$config{'char'}]{'sitting'} && timeOut(\%{$timeout{'ai_sit'}})) {
		sendStand(\$remote_socket);
		$timeout{'ai_sit'}{'time'} = time;
	}


	##### SIT AUTO #####

	SITAUTO: {
		my $weight = percent_weight($char);
		my $action = AI::action;
		my $lower_ok = (percent_hp($char) >= $config{'sitAuto_hp_lower'} && percent_sp($char) >= $config{'sitAuto_sp_lower'});
		my $upper_ok = (percent_hp($char) >= $config{'sitAuto_hp_upper'} && percent_sp($char) >= $config{'sitAuto_sp_upper'});

		if ($ai_v{'sitAuto_forceStop'} && $lower_ok) {
			$ai_v{'sitAuto_forceStop'} = 0;
		}

		# Sit if we're not already sitting
		if ($action eq "sitAuto" && !$char->{sitting} && $char->{skills}{NV_BASIC}{lv} >= 3 &&
		  !ai_getAggressives() && ($weight < 50 || $config{'sitAuto_over_50'})) {
			sit();

		# Stand if our HP is high enough
		} elsif ($action eq "sitAuto" && ($ai_v{'sitAuto_forceStop'} || $upper_ok)) {
			AI::dequeue;
			stand() if (!$config{'sitAuto_idle'} && $char->{sitting});

		} elsif (!$ai_v{'sitAuto_forceStop'} && ($weight < 50 || $config{'sitAuto_over_50'}) && AI::action ne "sitAuto") {
			if ($action eq "" || $action eq "follow"
			|| ($action eq "route" && !AI::args->{noSitAuto})
			|| ($action eq "mapRoute" && !AI::args->{noSitAuto})
			) {
				if (!AI::inQueue("attack") && !ai_getAggressives()
				&& (percent_hp($char) < $config{'sitAuto_hp_lower'} || percent_sp($char) < $config{'sitAuto_sp_lower'})) {
					AI::queue("sitAuto");
					debug "Auto-sitting\n", "ai";
				}
			}
		}
	}



	##### ATTACK #####


	if (AI::action eq "attack" && AI::args->{suspended}) {
		AI::args->{ai_attack_giveup}{time} += time - AI::args->{suspended};
		delete AI::args->{suspended};
	}

	if (AI::action eq "attack" && AI::args->{move_start}) {
		# We've just finished moving to the monster.
		# Don't count the time we spent on moving
		AI::args->{ai_attack_giveup}{time} += time - AI::args->{move_start};
		undef AI::args->{unstuck}{time};
		undef AI::args->{move_start};

	} elsif (AI::action eq "attack" && AI::args->{avoiding}) {
		AI::args->{ai_attack_giveup}{time} = time + $monsters{AI::args->{ID}}{time_move_calc} + 3;
		undef AI::args->{avoiding};

	} elsif (((AI::action eq "route" && AI::action(1) eq "attack") || (AI::action eq "move" && AI::action(2) eq "attack"))
	   && AI::args->{attackID} && timeOut($AI::Temp::attack_route_adjust, 1)) {
		# We're on route to the monster; check whether the monster has moved
		my $ID = AI::args->{attackID};
		my $attackSeq = (AI::action eq "route") ? AI::args(1) : AI::args(2);
		my $monster = $monsters{$ID};

		if ($monster && $attackSeq->{monsterPos} && %{$attackSeq->{monsterPos}}
		 && distance(calcPosition($monster), $attackSeq->{monsterPos}) > $attackSeq->{attackMethod}{maxDistance}) {
			# Monster has moved; stop moving and let the attack AI readjust route
			AI::dequeue;
			AI::dequeue if (AI::action eq "route");

			$attackSeq->{ai_attack_giveup}{time} = time;
			debug "Target has moved more than $attackSeq->{attackMethod}{maxDistance} blocks; readjusting route\n", "ai_attack";

		} elsif ($monster && $attackSeq->{monsterPos} && %{$attackSeq->{monsterPos}}
		 && distance(calcPosition($monster), calcPosition($char)) <= $attackSeq->{attackMethod}{maxDistance}) {
			# Monster is within attack range; stop moving
			AI::dequeue;
			AI::dequeue if (AI::action eq "route");

			$attackSeq->{ai_attack_giveup}{time} = time;
			debug "Target at ($attackSeq->{monsterPos}{x},$attackSeq->{monsterPos}{y}) is now within " .
				"$attackSeq->{attackMethod}{maxDistance} blocks; stop moving\n", "ai_attack";
		}
		$AI::Temp::attack_route_adjust = time;
	}

	if (AI::action eq "attack" && timeOut(AI::args->{ai_attack_giveup}) &&
	    !$config{attackNoGiveup}) {
		my $ID = AI::args->{ID};
		$monsters{$ID}{attack_failed} = time if ($monsters{$ID});
		AI::dequeue;
		message "Can't reach or damage target, dropping target\n", "ai_attack";
		useTeleport(1) if ($config{'teleportAuto_dropTarget'});

	} elsif (AI::action eq "attack" && !$monsters{$ai_seq_args[0]{'ID'}}) {
		# Monster died or disappeared
		$timeout{'ai_attack'}{'time'} -= $timeout{'ai_attack'}{'timeout'};
		my $ID = AI::args->{ID};
		AI::dequeue;

		if ($monsters_old{$ID} && $monsters_old{$ID}{dead}) {
			message "Target died\n", "ai_attack";
			monKilled();
			$monsters_Killed{$monsters_old{$ID}{'nameID'}}++;

			# Pickup loot when monster's dead
			if ($config{'itemsTakeAuto'} && $monsters_old{$ID}{dmgFromYou} > 0 && !$monsters_old{$ID}{ignore}) {
				AI::clear("items_take");
				ai_items_take($monsters_old{$ID}{pos}{x}, $monsters_old{$ID}{pos}{y},
					$monsters_old{$ID}{pos_to}{x}, $monsters_old{$ID}{pos_to}{y});
			} elsif (!ai_getAggressives()) {
				# Cheap way to suspend all movement to make it look real
				ai_clientSuspend(0, $timeout{'ai_attack_waitAfterKill'}{'timeout'});
			}

			## kokal start
			## mosters counting
			my $i = 0;
			my $found = 0;
			while ($monsters_Killed[$i]) {
				if ($monsters_Killed[$i]{'nameID'} eq $monsters_old{$ID}{'nameID'}) {
					$monsters_Killed[$i]{'count'}++;
					monsterLog($monsters_Killed[$i]{'name'});
					$found = 1;
					last;
				}
				$i++;
			}
			if (!$found) {
				$monsters_Killed[$i]{'nameID'} = $monsters_old{$ID}{'nameID'};
				$monsters_Killed[$i]{'name'} = $monsters_old{$ID}{'name'};
				$monsters_Killed[$i]{'count'} = 1;
				monsterLog($monsters_Killed[$i]{'name'})
			}
			## kokal end

		} else {
			message "Target lost\n", "ai_attack";
		}

	} elsif (AI::action eq "attack") {
		# The attack sequence hasn't timed out and the monster is on screen

		# Update information about the monster and the current situation
		my $args = AI::args;
		my $followIndex = AI::findAction("follow");
		my $following;
		my $followID;
		if (defined $followIndex) {
			$following = AI::args($followIndex)->{following};
			$followID = AI::args($followIndex)->{ID};
		}

		my $ID = $args->{ID};
		my $myPos = $char->{pos_to};
		my $monsterPos = $monsters{$ID}{pos_to};
		my $monsterDist = distance($myPos, $monsterPos);

		my ($realMyPos, $realMonsterPos, $realMonsterDist, $hitYou);
		my $realMyPos = calcPosition($char);
		my $realMonsterPos = calcPosition($monsters{$ID});
		my $realMonsterDist = distance($realMyPos, $realMonsterPos);
		if (!$config{'runFromTarget'}) {
			$myPos = $realMyPos;
			$monsterPos = $realMonsterPos;
		}

		my $cleanMonster = checkMonsterCleanness($ID);


		# If the damage numbers have changed, update the giveup time so we don't timeout
		if ($args->{dmgToYou_last}   != $monsters{$ID}{dmgToYou}
		 || $args->{missedYou_last}  != $monsters{$ID}{missedYou}
		 || $args->{dmgFromYou_last} != $monsters{$ID}{dmgFromYou}
		 || $args->{lastSkillTime} != $char->{last_skill_time}) {
			$args->{ai_attack_giveup}{time} = time;
			debug "Update attack giveup time\n", "ai_attack", 2;
		}
		$hitYou = ($args->{dmgToYou_last} != $monsters{$ID}{dmgToYou}
			|| $args->{missedYou_last} != $monsters{$ID}{missedYou});
		$args->{dmgToYou_last} = $monsters{$ID}{dmgToYou};
		$args->{missedYou_last} = $monsters{$ID}{missedYou};
		$args->{dmgFromYou_last} = $monsters{$ID}{dmgFromYou};
		$args->{missedFromYou_last} = $monsters{$ID}{missedFromYou};
		$args->{lastSkillTime} = $char->{last_skill_time};


		# Determine what combo skill to use
		delete $args->{attackMethod};
		my $lastSkill = Skills->new(id => $char->{last_skill_used})->name;
		my $i = 0;
		while (exists $config{"attackComboSlot_$i"}) {
			if (!$config{"attackComboSlot_$i"}) {
				$i++;
				next;
			}

			if ($config{"attackComboSlot_${i}_afterSkill"} eq $lastSkill
			 && ( !$config{"attackComboSlot_${i}_maxUses"} || $args->{attackComboSlot_uses}{$i} < $config{"attackComboSlot_${i}_maxUses"} )
			 && ( !defined($args->{ID}) || $args->{ID} eq $char->{last_skill_target} )
			 && checkSelfCondition("attackComboSlot_$i")
			 && checkMonsterCondition("attackComboSlot_${i}_target", $monsters{$ID})) {

				$args->{attackComboSlot_uses}{$i}++;
				delete $char->{last_skill_used};
				$args->{attackMethod}{type} = "combo";
				$args->{attackMethod}{comboSlot} = $i;
				$args->{attackMethod}{distance} = $config{"attackComboSlot_${i}_dist"};
				$args->{attackMethod}{maxDistance} = $config{"attackComboSlot_${i}_dist"};
				$args->{attackMethod}{isSelfSkill} = $config{"attackComboSlot_${i}_isSelfSkill"};
				last;
			}
			$i++;
		}

		# Determine what skill to use to attack
		if (!$args->{attackMethod}{type}) {
			if ($config{'attackUseWeapon'}) {
				$args->{attackMethod}{distance} = $config{'attackDistance'};
				$args->{attackMethod}{maxDistance} = $config{'attackMaxDistance'};
				$args->{attackMethod}{type} = "weapon";
			} else {
				$args->{attackMethod}{distance} = 30;
				$args->{attackMethod}{maxDistance} = 30;
				undef $args->{attackMethod}{type};
			}

			$i = 0;
			while (exists $config{"attackSkillSlot_$i"}) {
				if (!$config{"attackSkillSlot_$i"}) {
					$i++;
					next;
				}

				if (checkSelfCondition("attackSkillSlot_$i")
					&& (!$config{"attackSkillSlot_$i"."_maxUses"} || $args->{attackSkillSlot_uses}{$i} < $config{"attackSkillSlot_$i"."_maxUses"})
					&& (!$config{"attackSkillSlot_$i"."_monsters"} || existsInList($config{"attackSkillSlot_$i"."_monsters"}, $monsters{$ID}{'name'}))
					&& (!$config{"attackSkillSlot_$i"."_notMonsters"} || !existsInList($config{"attackSkillSlot_$i"."_notMonsters"}, $monsters{$ID}{'name'}))
					&& checkMonsterCondition("attackSkillSlot_${i}_target", $monsters{$ID})
				) {
					$args->{attackSkillSlot_uses}{$i}++;
					$args->{attackMethod}{distance} = $config{"attackSkillSlot_$i"."_dist"};
					$args->{attackMethod}{type} = "skill";
					$args->{attackMethod}{skillSlot} = $i;
					last;
				}
				$i++;
			}

			if ($config{'runFromTarget'} && $config{'runFromTarget_dist'} > $args->{attackMethod}{distance}) {
				$args->{attackMethod}{distance} = $config{'runFromTarget_dist'};
			}
		}

		if ($args->{attackMethod}{maxDistance} < $args->{attackMethod}{distance}) {
			$args->{attackMethod}{maxDistance} = $args->{attackMethod}{distance};
		}

		if ($char->{sitting}) {
			ai_setSuspend(0);
			stand();

		} elsif (!$cleanMonster) {
			# Drop target if it's already attacked by someone else
			message "Dropping target - you will not kill steal others\n", "ai_attack";
			sendMove(\$remote_socket, $realMyPos->{x}, $realMyPos->{y});
			AI::dequeue;

		} elsif ($config{attackCheckLOS} &&
		         $args->{attackMethod}{distance} > 2 &&
		         !checkLineSnipable($realMyPos, $realMonsterPos)) {
			# We are a ranged attacker without LOS

			# Calculate squares around monster within shooting range, but not
			# closer than runFromTarget_dist
			my @stand = calcRectArea2($realMonsterPos->{x}, $realMonsterPos->{y},
			                          $args->{attackMethod}{distance},
									  $config{runFromTarget} ? $config{runFromTarget_dist} : 0);

			my ($master, $masterPos);
			if ($config{follow}) {
				foreach (keys %players) {
					if ($players{$_}{name} eq $config{followTarget}) {
						$master = $players{$_};
						last;
					}
				}
				$masterPos = calcPosition($master) if $master;
			}

			# Determine which of these spots are snipable
			my $best_spot;
			my $best_dist;
			for my $spot (@stand) {
				# Is this spot acceptable?
				# 1. It must have LOS to the target ($realMonsterPos).
				# 2. It must be within $config{followDistanceMax} of
				#    $masterPos, if we have a master.
				if (checkLineSnipable($spot, $realMonsterPos) &&
				    (!$master || distance($spot, $masterPos) <= $config{followDistanceMax})) {
					# FIXME: use route distance, not pythagorean distance
					my $dist = distance($realMyPos, $spot);
					if (!defined($best_dist) || $dist < $best_dist) {
						$best_dist = $dist;
						$best_spot = $spot;
					}
				}
			}

			# Move to the closest spot
			my $msg = "No LOS from ($realMyPos->{x}, $realMyPos->{y}) to target ($realMonsterPos->{x}, $realMonsterPos->{y})";
			if ($best_spot) {
				message "$msg; moving to ($best_spot->{x}, $best_spot->{y})\n";
				ai_route($field{name}, $best_spot->{x}, $best_spot->{y});
			} else {
				warning "$msg; no acceptable place to stand\n";
				AI::dequeue;
			}

		} elsif ($config{'runFromTarget'} && ($monsterDist < $config{'runFromTarget_dist'} || $hitYou)) {
			#my $begin = time;
			# Get a list of blocks that we can run to
			my @blocks = calcRectArea($myPos->{x}, $myPos->{y},
				# If the monster hit you while you're running, then your recorded
				# location may be out of date. So we use a smaller distance so we can still move.
				($hitYou) ? $config{'runFromTarget_dist'} / 2 : $config{'runFromTarget_dist'});

			# Find the distance value of the block that's farthest away from a wall
			my $highest;
			foreach (@blocks) {
				my $dist = ord(substr($field{dstMap}, $_->{y} * $field{width} + $_->{x}));
				if (!defined $highest || $dist > $highest) {
					$highest = $dist;
				}
			}

			# Get rid of rediculously large route distances (such as spots that are on a hill)
			# Get rid of blocks that are near a wall
			my $pathfinding = new PathFinding;
			use constant AVOID_WALLS => 4;
			for (my $i = 0; $i < @blocks; $i++) {
				# We want to avoid walls (so we don't get cornered), if possible
				my $dist = ord(substr($field{dstMap}, $blocks[$i]{y} * $field{width} + $blocks[$i]{x}));
				if ($highest >= AVOID_WALLS && $dist < AVOID_WALLS) {
					delete $blocks[$i];
					next;
				}

				$pathfinding->reset(
					field => \%field,
					start => $myPos,
					dest => $blocks[$i]);
				my $ret = $pathfinding->runcount;
				if ($ret <= 0 || $ret > $config{'runFromTarget_dist'} * 2) {
					delete $blocks[$i];
					next;
				}
			}

			# Find the block that's farthest to us
			my $largestDist;
			my $bestBlock;
			foreach (@blocks) {
				next unless defined $_;
				my $dist = distance($monsterPos, $_);
				if (!defined $largestDist || $dist > $largestDist) {
					$largestDist = $dist;
					$bestBlock = $_;
				}
			}

			#message "Time spent: " . (time - $begin) . "\n";
			#debug_showSpots('runFromTarget', \@blocks, $bestBlock);
			AI::args->{avoiding} = 1;
			move($bestBlock->{x}, $bestBlock->{y}, $ID);

		} elsif (!$config{'runFromTarget'} && $monsterDist > $args->{attackMethod}{maxDistance}
		  && timeOut($args->{ai_attack_giveup}, 0.5)) {
			# The target monster moved; move to target
			$args->{move_start} = time;
			$args->{monsterPos} = {%{$monsterPos}};

			# Calculate how long it would take to reach the monster.
			# Calculate where the monster would be when you've reached its
			# previous position.
			my $time_needed;
			if (objectIsMovingTowards($monsters{$ID}, $char, 45)) {
				$time_needed = $monsterDist * $char->{walk_speed};
			} else {
				# If monster is not moving towards you, then you need more time to walk
				$time_needed = $monsterDist * $char->{walk_speed} + 2;
			}
			my $pos = calcPosition($monsters{$ID}, $time_needed);

			my $dist = sprintf("%.1f", $monsterDist);
			debug "Target distance $dist is >$args->{attackMethod}{maxDistance}; moving to target: " .
				"from ($myPos->{x},$myPos->{y}) to ($pos->{x},$pos->{y})\n", "ai_attack";

			my $result = ai_route($field{'name'}, $pos->{x}, $pos->{y},
				distFromGoal => $args->{attackMethod}{distance},
				maxRouteTime => $config{'attackMaxRouteTime'},
				attackID => $ID,
				noMapRoute => 1,
				noAvoidWalls => 1);
			if (!$result) {
				# Unable to calculate a route to target
				$monsters{$ID}{attack_failed} = time if ($monsters{$ID});
				AI::dequeue;
				message "Unable to calculate a route to target, dropping target\n", "ai_attack";
			}

		} elsif ((!$config{'runFromTarget'} || $realMonsterDist >= $config{'runFromTarget_dist'})
		 && (!$config{'tankMode'} || !$monsters{$ID}{dmgFromYou})) {
			# Attack the target. In case of tanking, only attack if it hasn't been hit once.
			if (!AI::args->{firstAttack}) {
				AI::args->{firstAttack} = 1;
				my $dist = sprintf("%.1f", $monsterDist);
				my $pos = "$myPos->{x},$myPos->{y}";
				debug "Ready to attack target (which is $dist blocks away); we're at ($pos)\n", "ai_attack";
			}

			$args->{unstuck}{time} = time if (!$args->{unstuck}{time});
			if (!$monsters{$ID}{dmgFromYou} && timeOut($args->{unstuck})) {
				# We are close enough to the target, and we're trying to attack it,
				# but some time has passed and we still haven't dealed any damage.
				# Our recorded position might be out of sync, so try to unstuck
				$args->{unstuck}{time} = time;
				debug("Attack - trying to unstuck\n", "ai_attack");
				move($myPos->{x}, $myPos->{y});
			}

			if ($args->{attackMethod}{type} eq "weapon" && timeOut($timeout{ai_attack})) {
				sendAttack(\$remote_socket, $ID,
					($config{'tankMode'}) ? 0 : 7);
				$timeout{ai_attack}{time} = time;
				delete $args->{attackMethod};

			} elsif ($args->{attackMethod}{type} eq "skill") {
				my $slot = $args->{attackMethod}{skillSlot};
				delete $args->{attackMethod};

				ai_setSuspend(0);
				if (!ai_getSkillUseType($skills_rlut{lc($config{"attackSkillSlot_$slot"})})) {
					ai_skillUse(
						$skills_rlut{lc($config{"attackSkillSlot_$slot"})},
						$config{"attackSkillSlot_${slot}_lvl"},
						$config{"attackSkillSlot_${slot}_maxCastTime"},
						$config{"attackSkillSlot_${slot}_minCastTime"},
						$config{"attackSkillSlot_${slot}_isSelfSkill"} ? $accountID : $ID,
						undef,
						"attackSkill");
				} else {
					ai_skillUse(
						$skills_rlut{lc($config{"attackSkillSlot_$slot"})},
						$config{"attackSkillSlot_${slot}_lvl"},
						$config{"attackSkillSlot_${slot}_maxCastTime"},
						$config{"attackSkillSlot_${slot}_minCastTime"},
						$monsters{$ID}{pos_to}{x},
						$monsters{$ID}{pos_to}{y},
						"attackSkill");
				}
				$args->{monsterID} = $ID;

				debug "Auto-skill on monster ".getActorName($ID).": ".qq~$config{"attackSkillSlot_$slot"} (lvl $config{"attackSkillSlot_${slot}_lvl"})\n~, "ai_attack";

			} elsif ($args->{attackMethod}{type} eq "combo") {
				my $slot = $args->{attackMethod}{comboSlot};
				my $isSelfSkill = $args->{attackMethod}{isSelfSkill};
				my $skill = Skills->new(name => $config{"attackComboSlot_$slot"})->handle;
				delete $args->{attackMethod};

				if (!ai_getSkillUseType($skill)) {
					my $targetID = ($isSelfSkill) ? $accountID : $ID;
					ai_skillUse(
						$skill,
						$config{"attackComboSlot_${slot}_lvl"},
						$config{"attackComboSlot_${slot}_maxCastTime"},
						$config{"attackComboSlot_${slot}_minCastTime"},
						$targetID,
						undef,
						undef,
						undef,
						$config{"attackComboSlot_${slot}_waitBeforeUse"});
				} else {
					my $pos = ($isSelfSkill) ? $char->{pos_to} : $monsters{$ID}{pos_to};
					ai_skillUse(
						$skill,
						$config{"attackComboSlot_${slot}_lvl"},
						$config{"attackComboSlot_${slot}_maxCastTime"},
						$config{"attackComboSlot_${slot}_minCastTime"},
						$pos->{x},
						$pos->{y},
						undef,
						undef,
						$config{"attackComboSlot_${slot}_waitBeforeUse"});
				}
				$args->{monsterID} = $ID;
			}

		} elsif ($config{'tankMode'}) {
			if ($ai_seq_args[0]{'dmgTo_last'} != $monsters{$ID}{'dmgTo'}) {
				$ai_seq_args[0]{'ai_attack_giveup'}{'time'} = time;
			}
			$ai_seq_args[0]{'dmgTo_last'} = $monsters{$ID}{'dmgTo'};
		}
	}

	# Check for kill steal while moving
	if (AI::is("move", "route") && AI::args->{attackID} && AI::inQueue("attack")) {
		my $ID = AI::args->{attackID};
		if ($monsters{$ID} && !checkMonsterCleanness($ID)) {
			message "Dropping target - you will not kill steal others\n";
			stopAttack();
			$monsters{$ID}{ignore} = 1;

			# Right now, the queue is either
			#   move, route, attack
			# -or-
			#   route, attack
			AI::dequeue;
			AI::dequeue;
			AI::dequeue if (AI::action eq "attack");
		}
	}

	##### AUTO-ITEM USE #####

	if ((AI::isIdle || AI::is(qw(route mapRoute follow sitAuto take items_gather items_take attack skill_use)))
	  && timeOut($timeout{ai_item_use_auto})) {
		my $i = 0;
		while (exists $config{"useSelf_item_$i"}) {
			if ($config{"useSelf_item_$i"} && checkSelfCondition("useSelf_item_$i")) {
				my $index = findIndexStringList_lc($char->{inventory}, "name", $config{"useSelf_item_$i"});
				if (defined $index) {
					sendItemUse(\$remote_socket, $char->{inventory}[$index]{index}, $accountID);
					$ai_v{"useSelf_item_$i"."_time"} = time;
					$timeout{ai_item_use_auto}{time} = time;
					debug qq~Auto-item use: $char->{inventory}[$index]{name}\n~, "ai";
					last;
				}
			}
			$i++;
		}
	}


	##### AUTO-SKILL USE #####

	if (AI::isIdle || AI::is(qw(route mapRoute follow sitAuto take items_gather items_take attack))
	|| (AI::action eq "skill_use" && AI::args->{tag} eq "attackSkill")) {
		my $i = 0;
		my %self_skill;
		while (exists $config{"useSelf_skill_$i"}) {
			if ($config{"useSelf_skill_$i"} && checkSelfCondition("useSelf_skill_$i")) {
				$ai_v{"useSelf_skill_$i"."_time"} = time;
				$self_skill{ID} = $skills_rlut{lc($config{"useSelf_skill_$i"})};
				unless ($self_skill{ID}) {
					error "Unknown skill name '".$config{"useSelf_skill_$i"}."' in useSelf_skill_$i\n";
					configModify("useSelf_skill_${i}_disabled", 1);
					next;
				}
				$self_skill{lvl} = $config{"useSelf_skill_$i"."_lvl"};
				$self_skill{maxCastTime} = $config{"useSelf_skill_$i"."_maxCastTime"};
				$self_skill{minCastTime} = $config{"useSelf_skill_$i"."_minCastTime"};
				last;
			}
			$i++;
		}
		if ($config{useSelf_skill_smartHeal} && $self_skill{ID} eq "AL_HEAL") {
			my $smartHeal_lv = 1;
			my $hp_diff = $char->{hp_max} - $char->{hp};
			for ($i = 1; $i <= $char->{skills}{$self_skill{ID}}{lv}; $i++) {
				my $sp_req, $amount;
				
				$smartHeal_lv = $i;
				$sp_req = 10 + ($i * 3);
				$amount = int(($char->{lv} + $char->{int}) / 8) * (4 + $i * 8);
				if ($char->{sp} < $sp_req) {
					$smartHeal_lv--;
					last;
				}
				last if ($amount >= $hp_diff);
			}
			$self_skill{lvl} = $smartHeal_lv;
		}
		if ($self_skill{lvl} > 0) {
			debug qq~Auto-skill on self: $skills_lut{$self_skill{ID}} (lvl $self_skill{lvl})\n~, "ai";
			if (!ai_getSkillUseType($self_skill{ID})) {
				ai_skillUse($self_skill{ID}, $self_skill{lvl}, $self_skill{maxCastTime}, $self_skill{minCastTime}, $accountID);
			} else {
				ai_skillUse($self_skill{ID}, $self_skill{lvl}, $self_skill{maxCastTime}, $self_skill{minCastTime}, $char->{pos_to}{x}, $char->{pos_to}{y});
			}
		}
	}

	##### PARTY-SKILL USE ##### 

	if ($char->{party} && (AI::isIdle || AI::is(qw(route mapRoute follow sitAuto take items_gather items_take attack move)))){
		my $i = 0;
		my %party_skill;
		while ($config{"partySkill_$i"}) {
			if (!$config{"partySkill_$i"}) {
				$i++;
				next;
			}

			for (my $j = 0; $j < @partyUsersID; $j++) {
				next if ($partyUsersID[$j] eq "" || $partyUsersID[$j] eq $accountID);
				if ($players{$partyUsersID[$j]}
					&& inRange(distance(\%{$char->{pos_to}}, \%{$char->{party}{users}{$partyUsersID[$j]}{pos}}), $config{partySkillDistance} || "1..8")
					&& (!$config{"partySkill_$i"."_target"} || existsInList($config{"partySkill_$i"."_target"}, $char->{party}{users}{$partyUsersID[$j]}{'name'}))
					&& checkPlayerCondition("partySkill_$i"."_target", $partyUsersID[$j])
					&& checkSelfCondition("partySkill_$i")
					){
					$party_skill{skillID} = $skills_rlut{lc($config{"partySkill_$i"})};
					$party_skill{skillLvl} = $config{"partySkill_$i"."_lvl"};
					$party_skill{target} = $char->{party}{users}{$partyUsersID[$j]}{name};
					$party_skill{targetID} = $partyUsersID[$j];
					$party_skill{maxCastTime} = $config{"partySkill_$i"."_maxCastTime"};
					$party_skill{minCastTime} = $config{"partySkill_$i"."_minCastTime"};
					# This is used by setSkillUseTimer() to set
					# $ai_v{"partySkill_${i}_target_time"}{$targetID}
					# when the skill is actually cast
					$targetTimeout{$partyUsersID[$j]}{$party_skill{skillID}} = $i;
					last;
				}
			}
			$i++;
			last if (defined($party_skill{targetID}));
		}

		if ($config{useSelf_skill_smartHeal} && $party_skill{skillID} eq "AL_HEAL") {
			my $smartHeal_lv = 1;
			my $hp_diff = $char->{party}{users}{$party_skill{targetID}}{hp_max} - $char->{party}{users}{$party_skill{targetID}}{hp};
			for ($i = 1; $i <= $char->{skills}{$party_skill{skillID}}{lv}; $i++) {
				my $sp_req, $amount;
				
				$smartHeal_lv = $i;
				$sp_req = 10 + ($i * 3);
				$amount = int(($char->{lv} + $char->{int}) / 8) * (4 + $i * 8);
				if ($char->{sp} < $sp_req) {
					$smartHeal_lv--;
					last;
				}
				last if ($amount >= $hp_diff);
			}
			$party_skill{skillLvl} = $smartHeal_lv;
		}
		if ($party_skill{skillLvl} > 0) {
			debug qq~Party Skill used ($char->{party}{users}{$party_skill{targetID}}{name}) Skills Used: $skills_lut{$party_skill{skillID}} (lvl $party_skill{skillLvl})\n~, "skill";
			if (!ai_getSkillUseType($party_skill{skillID})) {
				ai_skillUse($party_skill{skillID}, $party_skill{skillLvl}, $party_skill{maxCastTime}, $party_skill{minCastTime}, $party_skill{targetID});
			} else {
				ai_skillUse($party_skill{skillID}, $party_skill{skillLvl}, $party_skill{maxCastTime}, $party_skill{minCastTime}, $char->{party}{users}{$party_skill{targetID}}{pos}{x}, $char->{party}{users}{$party_skill{targetID}}{pos}{y});
			}
		}
	}

	##### MONSTER SKILL USE #####
	if (AI::isIdle || AI::is(qw(route mapRoute follow sitAuto take items_gather items_take attack move))) {
		my $i = 0;
		my $prefix = "monsterSkill_$i";
		while ($config{$prefix}) {
			# monsterSkill can be used on any monster that we could
			# attackAuto
			@monsterIDs = ai_getAggressives(1, 1);
			for my $monsterID (@monsterIDs) {
				my $monster = $monsters{$monsterID};
				if (checkSelfCondition($prefix)
				    && checkMonsterCondition("${prefix}_target", $monster)) {
					my $skill = Skills->new(name => $config{$prefix});

					next if $config{"${prefix}_maxUses"} && $monster->{skillUses}{$skill->handle} >= $config{"${prefix}_maxUses"};
					next if $config{"${prefix}_target"} && !existsInList($config{"${prefix}_target"}, $monster->{name});

					my $lvl = $config{"${prefix}_lvl"};
					my $maxCastTime = $config{"${prefix}_maxCastTime"};
					my $minCastTime = $config{"${prefix}_minCastTime"};
					debug "Auto-monsterSkill on $monster->{name} ($monster->{binID}): ".$skill->name." (lvl $lvl)\n", "monsterSkill";
					ai_skillUse2($skill, $lvl, $maxCastTime, $minCastTime, $monster);
					$ai_v{$prefix . "_time"}{$monsterID} = time;
					last;
				}
			}
			$i++;
			$prefix = "monsterSkill_$i";
		}
	}

	##### AUTO-EQUIP #####
	if ((AI::isIdle || AI::is(qw(route mapRoute follow sitAuto skill_use take items_gather items_take attack)) || $ai_v{temp}{teleport}{lv})
	  && timeOut($timeout{ai_item_equip_auto}) && time > $ai_v{'inventory_time'}) {

		my $ai_index_attack = AI::findAction("attack");
		my $ai_index_skill_use = AI::findAction("skill_use");

		my $currentSkill;
		if (defined $ai_index_skill_use) {
			my $skillHandle = AI::args($ai_index_skill_use)->{skillHandle};
			$currentSkill = $skills_lut{$skillHandle};
		}

		my $monster;
		if (defined $ai_index_attack) {
			my $ID = AI::args($ai_index_attack)->{ID};
			$monster = $monsters{$ID};
		}

		my $i = 0;
		while (exists $config{"equipAuto_$i"}) {
			if (!$config{"equipAuto_$i"}) {
				$i++;
				next;
			}

			if (checkSelfCondition("equipAuto_$i")
				&& checkMonsterCondition("equipAuto_$i", $monster)
			 	&& (!$config{"equipAuto_$i" . "_weight"} || $char->{percent_weight} >= $config{"equipAuto_$i" . "_weight"})
			 	&& (!$config{"equipAuto_$i" . "_onTeleport"} || $ai_v{temp}{teleport}{lv})
			 	&& (!$config{"equipAuto_$i" . "_whileSitting"} || ($config{"equipAuto_$i" . "_whileSitting"} && $char->{sitting}))
				&& (!$config{"equipAuto_$i" . "_monsters"} || (defined $monster && existsInList($config{"equipAuto_$i" . "_monsters"}, $monster->{name})))
			 	&& (!$config{"equipAuto_$i" . "_skills"} || (defined $currentSkill && existsInList($config{"equipAuto_$i" . "_skills"}, $currentSkill)))
				) {
				my $index = findIndexString_lc_not_equip(\@{$char->{inventory}}, "name", $config{"equipAuto_$i"});
				if (defined $index) {
					sendEquip(\$remote_socket, $char->{inventory}[$index]{index}, $char->{inventory}[$index]{type_equip});
					$timeout{ai_item_equip_auto}{time} = time;
					
					# this is a skilluse equip
					if (!$config{"equipAuto_$i" . "_skills"} || (defined $currentSkill && existsInList($config{"equipAuto_$i" . "_skills"}, $currentSkill))) { 
						AI::args($ai_index_skill_use)->{ai_equipAuto_skilluse_giveup}{time} = time;
						AI::args($ai_index_skill_use)->{ai_equipAuto_skilluse_giveup}{timeout} = $timeout{ai_equipAuto_skilluse_giveup}{timeout};
						
					# this is a teleport equip
					} elsif (!$config{"equipAuto_$i" . "_onTeleport"} || $ai_v{temp}{teleport}{lv}) {
						$ai_v{temp}{teleport}{ai_equipAuto_skilluse_giveup}{time} = time;
						$ai_v{temp}{teleport}{ai_equipAuto_skilluse_giveup}{timeout} = $timeout{ai_equipAuto_skilluse_giveup}{timeout};
						warning "set timeout\n";
					}
					
					debug qq~Auto-equip: $char->{inventory}[$index]{name} ($index)\n~;
					last;
				}

			} elsif ($config{"equipAuto_$i" . "_def"} && !$char->{sitting} && !$config{"equipAuto_$i"."_disabled"}) {
				my $index = findIndexString_lc_not_equip(\@{$char->{inventory}}, "name", $config{"equipAuto_$i" . "_def"});
				if (defined $index) {
					sendEquip(\$remote_socket, $char->{inventory}[$index]{index}, $char->{inventory}[$index]{type_equip});
					$timeout{ai_item_equip_auto}{time} = time;
					debug qq~Auto-equip: $char->{inventory}[$index]{name} ($index)\n~;
				}
			}
			$i++;
		}
	}

	##### SKILL USE #####
	#FIXME: need to move closer before using skill on player,
	#there might be line of sight problem too
	#or the player disappers from the area

	if (AI::action eq "skill_use" && AI::args->{suspended}) {
		AI::args->{giveup}{time} += time - AI::args->{suspended};
		AI::args->{minCastTime}{time} += time - AI::args->{suspended};
		AI::args->{maxCastTime}{time} += time - AI::args->{suspended};
		delete AI::args->{suspended};
	}

	if (AI::action eq "skill_use") {
		my $args = AI::args;

		if ($args->{monsterID} && $skillsArea{$args->{skillHandle}} == 2) {
			delete $args->{monsterID};
		}

		if (exists $args->{ai_equipAuto_skilluse_giveup} && binFind(\@skillsID, $args->{skillHandle}) eq "" && timeOut($args->{ai_equipAuto_skilluse_giveup})) {
			warning "Timeout equiping for skill\n";
			AI::dequeue;
			${$args->{ret}} = 'equip timeout' if ($args->{ret});

		} elsif (timeOut($args->{waitBeforeUse})) {
			if (defined $args->{monsterID} && !defined $monsters{$args->{monsterID}}) {
				# This skill is supposed to be used for attacking a monster, but that monster has died
				AI::dequeue;
				${$args->{ret}} = 'target gone' if ($args->{ret});

			} elsif ($char->{sitting}) {
				AI::suspend;
				stand();

			# Use skill if we haven't done so yet
			} elsif (!$args->{skill_used}) {
				my $handle = $args->{skillHandle};
				if (!defined $args->{skillID}) {
					my $skill = new Skills(handle => $handle);
					$args->{skillID} = $skill->id;
				}
				my $skillID = $args->{skillID};


				$args->{skill_used} = 1;
				$args->{giveup}{time} = time;

				# Stop attacking, otherwise skill use might fail
				my $attackIndex = AI::findAction("attack");
				if (defined($attackIndex) && AI::args($attackIndex)->{attackMethod}{type} eq "weapon") {
					# 2005-01-24 pmak: Commenting this out since it may
					# be causing bot to attack slowly when a buff runs
					# out.
					#stopAttack();
				}

				if ($skillsArea{$handle} == 2) {
					sendSkillUse(\$remote_socket, $skillID, $args->{lv}, $accountID);
				} elsif ($args->{x} ne "") {
					sendSkillUseLoc(\$remote_socket, $skillID, $args->{lv}, $args->{x}, $args->{y});
				} else {
					sendSkillUse(\$remote_socket, $skillID, $args->{lv}, $args->{target});
				}
				$args->{skill_use_last} = $char->{skills}{$handle}{time_used};

				delete $char->{cast_cancelled};

			} elsif (timeOut($args->{minCastTime})) {
				if ($args->{skill_use_last} != $char->{skills}{$args->{skillHandle}}{time_used}) {
					AI::dequeue;
					${$args->{ret}} = 'ok' if ($args->{ret});

				} elsif ($char->{cast_cancelled} > $char->{time_cast}) {
					AI::dequeue;
					${$args->{ret}} = 'cancelled' if ($args->{ret});

				} elsif (timeOut($char->{time_cast}, $char->{time_cast_wait} + 0.5)
				  && ( (timeOut($args->{giveup}) && (!$char->{time_cast} || !$args->{maxCastTime}{timeout}) )
				      || ( $args->{maxCastTime}{timeout} && timeOut($args->{maxCastTime})) )
				) {
					AI::dequeue;
					${$args->{ret}} = 'timeout' if ($args->{ret});
				}
			}
		}
	}



	##### AUTO-ATTACK #####
	# The auto-attack logic is as follows:
	# 1. Generate a list of monsters that we are allowed to attack.
	# 2. Pick the "best" monster out of that list, and attack it.

	if ((AI::isIdle || AI::is(qw/route follow sitAuto take items_gather items_take/) || (AI::action eq "mapRoute" && AI::args->{stage} eq 'Getting Map Solution'))
	     # Don't auto-attack monsters while taking loot, and itemsTake/GatherAuto >= 2
	  && !($config{'itemsTakeAuto'} >= 2 && AI::is("take", "items_take"))
	  && !($config{'itemsGatherAuto'} >= 2 && AI::is("take", "items_gather"))
	  && timeOut($timeout{ai_attack_auto})) {

		# If we're in tanking mode, only attack something if the person we're tanking for is on screen.
		my $foundTankee;
		if ($config{'tankMode'}) {
			foreach (@playersID) {	
				next if (!$_);
				if ($config{'tankModeTarget'} eq $players{$_}{'name'}) {
					$foundTankee = 1;
					last;
				}
			}
		}

		my $attackTarget;
		my $priorityAttack;

		if (!$config{'tankMode'} || $foundTankee) {
			# This variable controls how far monsters must be away from portals and players.
			my $portalDist = $config{'attackMinPortalDistance'} || 4;
			my $playerDist = $config{'attackMinPlayerDistance'};
			$playerDist = 1 if ($playerDist < 1);

			# Detect whether we are currently in follow mode
			my $following;
			my $followID;
			if (defined(my $followIndex = AI::findAction("follow"))) {
				$following = AI::args($followIndex)->{following};
				$followID = AI::args($followIndex)->{ID};
			}

			my $routeIndex = AI::findAction("route");
			$routeIndex = AI::findAction("mapRoute") if (!defined $routeIndex);
			my $attackOnRoute;
			if (defined $routeIndex) {
				$attackOnRoute = AI::args($routeIndex)->{attackOnRoute};
			} else {
				$attackOnRoute = 2;
			}


			### Step 1: Generate a list of all monsters that we are allowed to attack. ###
			my @aggressives;
			my @partyMonsters;
			my @cleanMonsters;

			# List aggressive monsters
			@aggressives = ai_getAggressives(1) if ($config{'attackAuto'} && $attackOnRoute);

			# There are two types of non-aggressive monsters. We generate two lists:
			foreach (@monstersID) {
				next if (!$_ || !checkMonsterCleanness($_));
				my $monster = $monsters{$_};
				# Ignore ignored monsters in mon_control.txt
				my $monName = lc($monster->{name});
				if ((my $monCtrl = $mon_control{$monName})) {
					next if ( ($monCtrl->{attack_auto} ne "" && $monCtrl->{attack_auto} <= 0)
						|| ($monCtrl->{attack_lvl} ne "" && $monCtrl->{attack_lvl} > $char->{lv})
						|| ($monCtrl->{attack_hp}  ne "" && $monCtrl->{attack_hp} > $char->{hp})
						|| ($monCtrl->{attack_sp}  ne "" && $monCtrl->{attack_sp} > $char->{sp})
						);
				}


				my $pos = calcPosition($monster);

				# List monsters that party members are attacking
				if ($config{attackAuto_party} && $attackOnRoute && !AI::is("take", "items_take")
				 && (($monster->{dmgFromParty} && $config{attackAuto_party} != 2) ||
				     $monster->{dmgToParty} || $monster->{missedToParty})
				 && timeOut($monster->{attack_failed}, $timeout{ai_attack_unfail}{timeout})) {
					push @partyMonsters, $_;
					next;
				}

				# List monsters that the master is attacking
				if ($following && $config{'attackAuto_followTarget'} && $attackOnRoute && !AI::is("take", "items_take")
				 && ($monster->{dmgToPlayer}{$followID} || $monster->{dmgFromPlayer}{$followID} || $monster->{missedToPlayer}{$followID})
				 && timeOut($monster->{attack_failed}, $timeout{ai_attack_unfail}{timeout})) {
					push @partyMonsters, $_;
					next;
				}


				### List normal, non-aggressive monsters. ###

				# Ignore monsters that
				# - Have a status (such as poisoned), because there's a high chance
				#   they're being attacked by other players
				# - Are inside others' area spells (this includes being trapped).
				# - Are moving towards other players.
				# - Are behind a wall
				next if (( $monster->{statuses} && scalar(keys %{$monster->{statuses}}) )
					|| objectInsideSpell($monster)
					|| objectIsMovingTowardsPlayer($monster));
				if ($config{'attackCanSnipe'}) {
					next if (!checkLineSnipable($char->{pos_to}, $pos));
				} else {
					next if (!checkLineWalkable($char->{pos_to}, $pos));
				}

				my $safe = 1;
				if ($config{'attackAuto_onlyWhenSafe'}) {
					foreach (@playersID) {
						if ($_ && !$char->{party}{users}{$_}) {
							$safe = 0;
							last;
						}
					}
				}

				if (!AI::is(qw/sitAuto take items_gather items_take/) && $config{'attackAuto'} >= 2
				 && $attackOnRoute >= 2 && !$monster->{dmgFromYou} && $safe
				 && !positionNearPlayer($pos, $playerDist) && !positionNearPortal($pos, $portalDist)
				 && timeOut($monster->{attack_failed}, $timeout{ai_attack_unfail}{timeout})) {
					push @cleanMonsters, $_;
				}
			}


			### Step 2: Pick out the "best" monster ###

			my $myPos = calcPosition($char);
			my $highestPri;

			# Look for the aggressive monster that has the highest priority
			foreach (@aggressives) {
				my $monster = $monsters{$_};
				my $pos = calcPosition($monster);
				# Don't attack monsters near portals
				next if (positionNearPortal($pos, $portalDist));

				# Don't attack ignored monsters
				my $name = lc $monster->{name};
				next if ($mon_control{$name}{attack_auto} == -1);
				next if ($mon_control{$name}{attack_lvl} ne "" && $mon_control{$name}{attack_lvl} > $char->{lv});

				if (defined($priority{$name}) && $priority{$name} > $highestPri) {
					$highestPri = $priority{$name};
				}
			}

			my $smallestDist;
			if (!defined $highestPri) {
				# If not found, look for the closest aggressive monster (without priority)
				foreach (@aggressives) {
					my $monster = $monsters{$_};
					my $pos = calcPosition($monster);
					# Don't attack monsters near portals
					next if (positionNearPortal($pos, $portalDist));

					# Don't attack ignored monsters
					my $name = lc $monster->{name};
					next if ($mon_control{$name}{attack_auto} == -1);
					next if ($mon_control{$name}{attack_lvl} ne "" && $mon_control{$name}{attack_lvl} > $char->{lv});

					if (!defined($smallestDist) || (my $dist = distance($myPos, $pos)) < $smallestDist) {
						$smallestDist = $dist;
						$attackTarget = $_;
					}
				}
			} else {
				# If found, look for the closest aggressive monster with the highest priority
				foreach (@aggressives) {
					my $monster = $monsters{$_};
					my $pos = calcPosition($monster);
					# Don't attack monsters near portals
					next if (positionNearPortal($pos, $portalDist));

					# Don't attack ignored monsters
					my $name = lc $monster->{name};
					next if ($mon_control{$name}{attack_auto} == -1);
					next if ($mon_control{$name}{attack_lvl} ne "" && $mon_control{$name}{attack_lvl} > $char->{lv});

					if (!defined($smallestDist) || (my $dist = distance($myPos, $pos)) < $smallestDist) {
						$smallestDist = $dist;
						$attackTarget = $_;
						$priorityAttack = 1;
					}
				}
			}

			if (!$attackTarget) {
				undef $smallestDist;
				# There are no aggressive monsters; look for the closest monster that a party member/master is attacking
				foreach (@partyMonsters) {
					my $monster = $monsters{$_};
					my $pos = calcPosition($monster);
					if (!defined($smallestDist) || (my $dist = distance($myPos, $pos)) < $smallestDist) {
						$smallestDist = $dist;
						$attackTarget = $_;
					}
				}
			}

			if (!$attackTarget) {
				# No party monsters either; look for the closest, non-aggressive monster that:
				# 1) nobody's attacking
				# 2) has the highest priority

				undef $smallestDist;
				foreach (@cleanMonsters) {
					my $monster = $monsters{$_};
					next unless $monster;
					my $pos = calcPosition($monster);
					my $dist = distance($myPos, $pos);
					my $name = lc $monster->{name};

					if (!defined($smallestDist) || $priority{$name} > $highestPri
					  || ( $priority{$name} == $highestPri && $dist < $smallestDist )) {
						$smallestDist = $dist;
						$attackTarget = $_;
						$highestPri = $priority{$monster};
					}
				}
			}
		}
		# If an appropriate monster's found, attack it. If not, wait ai_attack_auto secs before searching again.
		if ($attackTarget) {
			ai_setSuspend(0);
			attack($attackTarget, $priorityAttack);
		} else {
			$timeout{'ai_attack_auto'}{'time'} = time;
		}
	}


	####### ROUTE #######

	if (AI::action eq "route" && AI::args->{suspended}) {
		AI::args->{time_start} += time - AI::args->{suspended};
		AI::args->{time_step} += time - AI::args->{suspended};
		delete AI::args->{suspended};
	}

	if (AI::action eq "route" && $field{'name'} && $char->{pos_to}{x} ne '' && $char->{pos_to}{y} ne '') {
		my $args = AI::args;

		if ( $args->{maxRouteTime} && timeOut($args->{time_start}, $args->{maxRouteTime})) {
			# We spent too much time
			debug "Route - we spent too much time; bailing out.\n", "route";
			AI::dequeue;

		} elsif ($field{name} ne $args->{dest}{map} || $args->{mapChanged}) {
			debug "Map changed: $field{name} $args->{dest}{map}\n", "route";
			AI::dequeue;

		} elsif ($args->{stage} eq '') {
			my $pos = calcPosition($char);
			$args->{solution} = [];
			if (ai_route_getRoute($args->{solution}, \%field, $pos, $args->{dest}{pos})) {
				$args->{stage} = 'Route Solution Ready';
				debug "Route Solution Ready\n", "route";
			} else {
				debug "Something's wrong; there is no path to $field{name}($args->{dest}{pos}{x},$args->{dest}{pos}{y}).\n", "debug";
				AI::dequeue;
			}

		} elsif ($args->{stage} eq 'Route Solution Ready') {
			my $solution = $args->{solution};
			if ($args->{maxRouteDistance} > 0 && $args->{maxRouteDistance} < 1) {
				# Fractional route motion
				$args->{maxRouteDistance} = int($args->{maxRouteDistance} * scalar(@{$solution}));
			}
			splice(@{$solution}, 1 + $args->{maxRouteDistance}) if $args->{maxRouteDistance} && $args->{maxRouteDistance} < @{$solution};

			# Trim down solution tree for pyDistFromGoal or distFromGoal
			if ($args->{pyDistFromGoal}) {
				my $trimsteps = 0;
				$trimsteps++ while ($trimsteps < @{$solution}
						 && distance($solution->[@{$solution} - 1 - $trimsteps], $solution->[@{$solution} - 1]) < $args->{pyDistFromGoal}
					);
				debug "Route - trimming down solution by $trimsteps steps for pyDistFromGoal $ai_seq_args[0]{'pyDistFromGoal'}\n", "route";
				splice(@{$ai_seq_args[0]{'solution'}}, -$trimsteps) if ($trimsteps);
			} elsif ($args->{distFromGoal}) {
				my $trimsteps = $ai_seq_args[0]{distFromGoal};
				$trimsteps = @{$ai_seq_args[0]{'solution'}} if $trimsteps > @{$ai_seq_args[0]{'solution'}};
				debug "Route - trimming down solution by $trimsteps steps for distFromGoal $ai_seq_args[0]{'distFromGoal'}\n", "route";
				splice(@{$args->{solution}}, -$trimsteps) if ($trimsteps);
			}

			undef $args->{mapChanged};
			undef $args->{index};
			undef $args->{old_x};
			undef $args->{old_y};
			undef $args->{new_x};
			undef $args->{new_y};
			$args->{time_step} = time;
			$args->{stage} = 'Walk the Route Solution';

		} elsif ($args->{stage} eq 'Walk the Route Solution') {

			my $pos = calcPosition($char);
			my ($cur_x, $cur_y) = ($pos->{x}, $pos->{y});

			unless (@{$args->{solution}}) {
				# No more points to cover; we've arrived at the destination
				debug "Destination reached.\n", "route";
				AI::dequeue;

			} elsif ($args->{old_x} == $cur_x && $args->{old_y} == $cur_y && timeOut($args->{time_step}, 3)) {
				# We tried to move for 3 seconds, but we are still on the same spot,
				# decrease step size.
				# However, if $args->{index} was already 0, then that means
				# we were almost at the destination (only 1 more step is needed).
				# But we got interrupted (by auto-attack for example). Don't count that
				# as stuck.
				my $wasZero = $args->{index} == 0;
				$args->{index} = int($args->{index} * 0.8);
				if ($args->{index}) {
					debug "Route - not moving, decreasing step size to $args->{index}\n", "route";
					if (@{$args->{solution}}) {
						# If we still have more points to cover, walk to next point
						$args->{index} = @{$args->{solution}} - 1 if $args->{index} >= @{$args->{solution}};
						$args->{new_x} = $args->{solution}[$args->{index}]{x};
						$args->{new_y} = $args->{solution}[$args->{index}]{y};
						$args->{time_step} = time;
						move($args->{new_x}, $args->{new_y}, $args->{attackID});
					}
				} elsif (!$wasZero) {
					# We're stuck
					my $msg = "Stuck at $field{name} ($char->{pos_to}{x},$char->{pos_to}{y}), while walking from ($cur_x,$cur_y) to ($args->{dest}{pos}{x},$args->{dest}{pos}{y}).";
					$msg .= " Teleporting to unstuck." if $config{teleportAuto_unstuck};
					$msg .= "\n";
					warning $msg, "route";
					useTeleport(1) if $config{teleportAuto_unstuck};
					AI::dequeue;
				} else {
					$args->{time_step} = time;
				}

			} else {
				# We're either starting to move or already moving, so send out more
				# move commands periodically to keep moving and updating our position
				my $solution = $args->{solution};
				$args->{index} = $config{'route_step'} unless $args->{index};
				$args->{index}++ if ($args->{index} < $config{'route_step'});

				if (defined($args->{old_x}) && defined($args->{old_y})) {
					# See how far we've walked since the last move command and
					# trim down the soultion tree by this distance.
					# Only remove the last step if we reached the destination
					my $trimsteps = 0;
					# If position has changed, we must have walked at least one step
					$trimsteps++ if ($cur_x != $args->{'old_x'} || $cur_y != $args->{'old_y'});
					# Search the best matching entry for our position in the solution
					while ($trimsteps < @{$solution}
							 && distance( { x => $cur_x, y => $cur_y }, $solution->[$trimsteps + 1])
							    < distance( { x => $cur_x, y => $cur_y }, $solution->[$trimsteps])
						) {
						$trimsteps++;
					}
					# Remove the last step also if we reached the destination
					$trimsteps = @{$solution} - 1 if ($trimsteps >= @{$solution});
					#$trimsteps = @{$solution} if ($trimsteps <= $args->{'index'} && $args->{'new_x'} == $cur_x && $args->{'new_y'} == $cur_y);
					$trimsteps = @{$solution} if ($cur_x == $solution->[$#{$solution}]{x} && $cur_y == $solution->[$#{$solution}]{y});
					debug "Route - trimming down solution (" . @{$solution} . ") by $trimsteps steps\n", "route";
					splice(@{$solution}, 0, $trimsteps) if ($trimsteps > 0);
				}

				my $stepsleft = @{$solution};
				if ($stepsleft > 0) {
					# If we still have more points to cover, walk to next point
					$args->{index} = $stepsleft - 1 if ($args->{index} >= $stepsleft);
					$args->{new_x} = $args->{solution}[$args->{index}]{x};
					$args->{new_y} = $args->{solution}[$args->{index}]{y};

					# But first, check whether the distance of the next point isn't abnormally large.
					# If it is, then we've moved to an unexpected place. This could be caused by auto-attack,
					# for example.
					my %nextPos = (x => $args->{new_x}, y => $args->{new_y});
					if (distance(\%nextPos, $pos) > $config{'route_step'}) {
						debug "Route - movement interrupted: reset route\n", "route";
						$args->{stage} = '';

					} else {
						$args->{old_x} = $cur_x;
						$args->{old_y} = $cur_y;
						$args->{time_step} = time if ($cur_x != $args->{old_x} || $cur_y != $args->{old_y});
						debug "Route - next step moving to ($args->{new_x}, $args->{new_y}), index $args->{index}, $stepsleft steps left\n", "route";
						move($args->{new_x}, $args->{new_y}, $args->{attackID});
					}
				} else {
					# No more points to cover
					debug "Destination reached.\n", "route";
					AI::dequeue;
				}
			}

		} else {
			debug "Unexpected route stage [$args->{stage}] occured.\n", "route";
			AI::dequeue;
		}
	}


	####### MAPROUTE #######
	if ( AI::action eq "mapRoute" && $field{name} && $char->{pos_to}{x} ne '' && $char->{pos_to}{y} ne '' ) {
		my $args = AI::args;

		if ($args->{stage} eq '') {
			$ai_seq_args[0]{'budget'} = $config{'route_maxWarpFee'} eq '' ?
				'' :
				$config{'route_maxWarpFee'} > $chars[$config{'char'}]{'zenny'} ?
					$chars[$config{'char'}]{'zenny'} :
					$config{'route_maxWarpFee'};
			delete $ai_seq_args[0]{'done'};
			delete $ai_seq_args[0]{'found'};
			delete $ai_seq_args[0]{'mapChanged'};
			delete $ai_seq_args[0]{'openlist'};
			delete $ai_seq_args[0]{'closelist'};
			undef @{$ai_seq_args[0]{'mapSolution'}};
			getField("$Settings::def_field/$ai_seq_args[0]{'dest'}{'map'}.fld", \%{$ai_seq_args[0]{'dest'}{'field'}});

			# Initializes the openlist with portals walkable from the starting point
			foreach my $portal (keys %portals_lut) {
				next if $portals_lut{$portal}{'source'}{'map'} ne $field{'name'};
				if ( ai_route_getRoute(\@{$args->{solution}}, \%field, $char->{pos_to}, \%{$portals_lut{$portal}{'source'}{'pos'}}) ) {
					foreach my $dest (keys %{$portals_lut{$portal}{'dest'}}) {
						my $penalty = int(($portals_lut{$portal}{'dest'}{$dest}{'steps'} ne '') ? $routeWeights{'NPC'} : $routeWeights{'PORTAL'});
						$ai_seq_args[0]{'openlist'}{"$portal=$dest"}{'walk'} = $penalty + scalar @{$ai_seq_args[0]{'solution'}};
						$ai_seq_args[0]{'openlist'}{"$portal=$dest"}{'zenny'} = $portals_lut{$portal}{'dest'}{$dest}{'cost'};
					}
				}
			}
			$ai_seq_args[0]{'stage'} = 'Getting Map Solution';

		} elsif ( $args->{stage} eq 'Getting Map Solution' ) {
			$timeout{'ai_route_calcRoute'}{'time'} = time;
			while (!$ai_seq_args[0]{'done'} && !timeOut(\%{$timeout{'ai_route_calcRoute'}})) {
				ai_mapRoute_searchStep($args);
			}
			if ($ai_seq_args[0]{'found'}) {
				$ai_seq_args[0]{'stage'} = 'Traverse the Map Solution';
				delete $ai_seq_args[0]{'openlist'};
				delete $ai_seq_args[0]{'solution'};
				delete $ai_seq_args[0]{'closelist'};
				delete $ai_seq_args[0]{'dest'}{'field'};
				debug "Map Solution Ready for traversal.\n", "route";
			} elsif ($ai_seq_args[0]{'done'}) {
				warning "Unable to calculate how to walk from [$field{'name'}($chars[$config{'char'}]{'pos_to'}{'x'},$chars[$config{'char'}]{'pos_to'}{'y'})] to [$ai_seq_args[0]{'dest'}{'map'}($ai_seq_args[0]{'dest'}{'pos'}{'x'},$ai_seq_args[0]{'dest'}{'pos'}{'y'})] (no map solution).\n", "route";
				AI::dequeue;
			}

		} elsif ( $args->{stage} eq 'Traverse the Map Solution' ) {

			my @solution;
			unless (@{$ai_seq_args[0]{'mapSolution'}}) {
				# mapSolution is now empty
				AI::dequeue;
				debug "Map Router is finish traversing the map solution\n", "route";

			} elsif ( $field{'name'} ne $ai_seq_args[0]{'mapSolution'}[0]{'map'}
				|| ( $args->{mapChanged} && !$args->{teleport} ) ) {
				# Solution Map does not match current map
				debug "Current map $field{'name'} does not match solution [ $ai_seq_args[0]{'mapSolution'}[0]{'portal'} ].\n", "route";
				delete $ai_seq_args[0]{'substage'};
				delete $ai_seq_args[0]{'timeout'};
				delete $ai_seq_args[0]{'mapChanged'};
				shift @{$ai_seq_args[0]{'mapSolution'}};

			} elsif ( $ai_seq_args[0]{'mapSolution'}[0]{'steps'} ) {
				# If current solution has conversation steps specified
				if ( $ai_seq_args[0]{'substage'} eq 'Waiting for Warp' ) {
					$ai_seq_args[0]{'timeout'} = time unless $ai_seq_args[0]{'timeout'};
					if (timeOut($ai_seq_args[0]{'timeout'}, 10)) {
						# We waited for 10 seconds and got nothing
						delete $ai_seq_args[0]{'substage'};
						delete $ai_seq_args[0]{'timeout'};
						if (++$ai_seq_args[0]{'mapSolution'}[0]{'retry'} > 5) {
							# NPC sequence is a failure
							# We delete that portal and try again
							delete $portals_lut{"$ai_seq_args[0]{'mapSolution'}[0]{'map'} $ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'x'} $ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'y'}"};
							warning "Unable to talk to NPC at $field{'name'} ($ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'x'},$ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'y'}).\n", "route";
							$ai_seq_args[0]{'stage'} = '';	# redo MAP router
						}
					}

				} elsif (distance(\%{$chars[$config{'char'}]{'pos_to'}}, \%{$ai_seq_args[0]{'mapSolution'}[0]{'pos'}}) <= 10) {
					my ($from,$to) = split /=/, $ai_seq_args[0]{'mapSolution'}[0]{'portal'};
					if ($chars[$config{'char'}]{'zenny'} >= $portals_lut{$from}{'dest'}{$to}{'cost'}) {
						#we have enough money for this service
						$ai_seq_args[0]{'substage'} = 'Waiting for Warp';
						$ai_seq_args[0]{'old_x'} = $chars[$config{'char'}]{'pos_to'}{'x'};
						$ai_seq_args[0]{'old_y'} = $chars[$config{'char'}]{'pos_to'}{'y'};
						$ai_seq_args[0]{'old_map'} = $field{'name'};
						ai_talkNPC($ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'x'}, $ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'y'}, $ai_seq_args[0]{'mapSolution'}[0]{'steps'} );
					} else {
						error "Insufficient zenny to pay for service at $field{'name'} ($ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'x'},$ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'y'}).\n", "route";
						$ai_seq_args[0]{'stage'} = ''; #redo MAP router
					}

				} elsif ( $ai_seq_args[0]{'maxRouteTime'} && time - $ai_seq_args[0]{'time_start'} > $ai_seq_args[0]{'maxRouteTime'} ) {
					# we spent too long a time
					debug "We spent too much time; bailing out.\n", "route";
					shift @ai_seq;
					shift @ai_seq_args;

				} elsif ( ai_route_getRoute( \@solution, \%field, $char->{pos_to}, $args->{mapSolution}[0]{pos} ) ) {
					# NPC is reachable from current position
					# >> Then "route" to it
					debug "Walking towards the NPC\n", "route";
					ai_route($ai_seq_args[0]{'mapSolution'}[0]{'map'}, $ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'x'}, $ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'y'},
						attackOnRoute => $ai_seq_args[0]{'attackOnRoute'},
						maxRouteTime => $ai_seq_args[0]{'maxRouteTime'},
						distFromGoal => 10,
						noSitAuto => $ai_seq_args[0]{'noSitAuto'},
						_solution => \@solution,
						_internal => 1);

				} else {
					#Error, NPC is not reachable from current pos
					debug "CRTICAL ERROR: NPC is not reachable from current location.\n", "route";
					error "Unable to walk from $field{'name'} ($chars[$config{'char'}]{'pos_to'}{'x'},$chars[$config{'char'}]{'pos_to'}{'y'}) to NPC at ($ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'x'},$ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'y'}).\n", "route";
					shift @{$ai_seq_args[0]{'mapSolution'}};
				}

			} elsif ( $ai_seq_args[0]{'mapSolution'}[0]{'portal'} eq "$ai_seq_args[0]{'mapSolution'}[0]{'map'} $ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'x'} $ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'y'}=$ai_seq_args[0]{'mapSolution'}[0]{'map'} $ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'x'} $ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'y'}" ) {
				# This solution points to an X,Y coordinate
				my $distFromGoal = $ai_seq_args[0]{'pyDistFromGoal'} ? $ai_seq_args[0]{'pyDistFromGoal'} : ($ai_seq_args[0]{'distFromGoal'} ? $ai_seq_args[0]{'distFromGoal'} : 0);
				if ( $distFromGoal + 2 > distance($chars[$config{'char'}]{'pos_to'}, $ai_seq_args[0]{'mapSolution'}[0]{'pos'})) {
					#We need to specify +2 because sometimes the exact spot is occupied by someone else
					shift @{$ai_seq_args[0]{'mapSolution'}};

				} elsif ( $ai_seq_args[0]{'maxRouteTime'} && time - $ai_seq_args[0]{'time_start'} > $ai_seq_args[0]{'maxRouteTime'} ) {
					#we spent too long a time
					debug "We spent too much time; bailing out.\n", "route";
					shift @ai_seq;
					shift @ai_seq_args;

				} elsif ( ai_route_getRoute( \@solution, \%field, \%{$chars[$config{'char'}]{'pos_to'}}, \%{$ai_seq_args[0]{'mapSolution'}[0]{'pos'}} ) ) {
					# X,Y is reachable from current position
					# >> Then "route" to it
					ai_route($ai_seq_args[0]{'mapSolution'}[0]{'map'}, $ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'x'}, $ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'y'},
						attackOnRoute => $ai_seq_args[0]{'attackOnRoute'},
						maxRouteTime => $ai_seq_args[0]{'maxRouteTime'},
						distFromGoal => $ai_seq_args[0]{'distFromGoal'},
						pyDistFromGoal => $ai_seq_args[0]{'pyDistFromGoal'},
						noSitAuto => $ai_seq_args[0]{'noSitAuto'},
						_solution => \@solution,
						_internal => 1);

				} else {
					warning "No LOS from $field{'name'} ($chars[$config{'char'}]{'pos_to'}{'x'},$chars[$config{'char'}]{'pos_to'}{'y'}) to Final Destination at ($ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'x'},$ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'y'}).\n", "route";
					error "Cannot reach ($ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'x'},$ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'y'}) from current position.\n", "route";
					shift @{$ai_seq_args[0]{'mapSolution'}};
				}

			} elsif ( $portals_lut{"$ai_seq_args[0]{'mapSolution'}[0]{'map'} $ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'x'} $ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'y'}"}{'source'}{'ID'} ) {
				# This is a portal solution

				if ( 2 > distance($char->{pos_to}, $args->{mapSolution}[0]{pos}) ) {
					# Portal is within 'Enter Distance'
					$timeout{'ai_portal_wait'}{'timeout'} = $timeout{'ai_portal_wait'}{'timeout'} || 0.5;
					if ( timeOut($timeout{'ai_portal_wait'}) ) {
						sendMove( \$remote_socket, int($ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'x'}), int($ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'y'}) );
						$timeout{'ai_portal_wait'}{'time'} = time;
					}

				} else {
					my $walk = 1;

					# Teleport until we're close enough to the portal
					$args->{teleport} = $config{route_teleport} if (!defined $args->{teleport});

					if ($args->{teleport} && !$cities_lut{"$field{name}.rsw"}
					&& ( !$config{route_teleport_maxTries} || $args->{teleportTries} <= $config{route_teleport_maxTries} )) {
						my $minDist = $config{route_teleport_minDistance};

						if ($args->{mapChanged}) {
							undef $args->{sentTeleport};
							undef $args->{mapChanged};
						}

						if (!$args->{sentTeleport}) {
							my $dist = new PathFinding(
								start => $char->{pos_to},
								dest => $args->{mapSolution}[0]{pos},
								field => \%field
							)->runcount;
							debug "Distance to portal is $dist\n", "route_teleport";

							if ($dist <= 0 || $dist > $minDist) {
								if ($dist > 0 && $config{route_teleport_maxTries} && $args->{teleportTries} >= $config{route_teleport_maxTries}) {
									debug "Teleported $config{route_teleport_maxTries} times. Falling back to walking.\n", "route_teleport";
								} else {
									debug "Attempting to teleport near portal, try #".($args->{teleportTries} + 1)."\n", "route_teleport";
									if (!useTeleport(1)) {
										$args->{teleport} = 0;
									} else {
										$walk = 0;
										$args->{sentTeleport} = 1;
										$args->{teleportTime} = time;
										$args->{teleportTries}++;
									}
								}
							}

						} elsif (timeOut($args->{teleportTime}, 4)) {
							debug "Unable to teleport; falling back to walking.\n", "route_teleport";
							$args->{teleport} = 0;
						} else {
							$walk = 0;
						}
					}

					if ($walk) {
						if ( ai_route_getRoute( \@solution, \%field, $char->{pos_to}, $args->{mapSolution}[0]{pos} ) ) {
							debug "portal within same map\n", "route";
							# Portal is reachable from current position
							# >> Then "route" to it
							debug "Portal route attackOnRoute = $args->{attackOnRoute}\n", "route";
							$args->{teleportTries} = 0;
							ai_route($ai_seq_args[0]{'mapSolution'}[0]{'map'}, $ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'x'}, $ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'y'},
								attackOnRoute => $args->{attackOnRoute},
								maxRouteTime => $args->{maxRouteTime},
								noSitAuto => $args->{noSitAuto},
								tags => $args->{tags},
								_solution => \@solution,
								_internal => 1);

						} else {
							warning "No LOS from $field{'name'} ($chars[$config{'char'}]{'pos_to'}{'x'},$chars[$config{'char'}]{'pos_to'}{'y'}) to Portal at ($ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'x'},$ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'y'}).\n", "route";
							error "Cannot reach portal from current position\n", "route";
							shift @{$args->{mapSolution}};
						}
					}
				}
			}
		}
	}


	##### ITEMS TAKE #####
	# Look for loot to pickup when your monster died.

	if (AI::action eq "items_take" && AI::args->{suspended}) {
		AI::args->{ai_items_take_start}{time} += time - AI::args->{suspended};
		AI::args->{ai_items_take_end}{time} += time - AI::args->{suspended};
		delete AI::args->{suspended};
	}
	if (AI::action eq "items_take" && (percent_weight($char) >= $config{itemsMaxWeight})) {
		AI::dequeue;
		ai_clientSuspend(0, $timeout{ai_attack_waitAfterKill}{timeout}) unless (ai_getAggressives());
	}
	if ($config{'itemsTakeAuto'} && AI::action eq "items_take" && timeOut(AI::args->{ai_items_take_start})) {
		my $foundID;
		my ($dist, $dist_to);

		foreach (@itemsID) {
			next unless $_;
			my $name = lc $items{$_}{name};
			next if ($itemsPickup{$name} eq "0" || $itemsPickup{$name} == -1
				|| ( !$itemsPickup{all} && !$itemsPickup{$name} ));

			$dist = distance($items{$_}{pos}, AI::args->{pos});
			$dist_to = distance($items{$_}{pos}, AI::args->{pos_to});
			if (($dist <= 4 || $dist_to <= 4) && $items{$_}{take_failed} == 0) {
				$foundID = $_;
				last;
			}
		}
		if (defined $foundID) {
			AI::args->{ai_items_take_end}{time} = time;
			AI::args->{started} = 1;
			take($foundID);
		} elsif (AI::args->{started} || timeOut(AI::args->{ai_items_take_end})) {
			$timeout{'ai_attack_auto'}{'time'} = 0;
			AI::dequeue;
		}
	}


	##### ITEMS AUTO-GATHER #####

	if ( (AI::isIdle || AI::action eq "follow"
		|| ( AI::is("route", "mapRoute") && (!AI::args->{ID} || $config{'itemsGatherAuto'} >= 2) ))
	  && $config{'itemsGatherAuto'}
	  && ($config{'itemsGatherAuto'} >= 2 || !ai_getAggressives())
	  && percent_weight($char) < $config{'itemsMaxWeight'}
	  && timeOut($timeout{ai_items_gather_auto}) ) {

		foreach my $item (@itemsID) {
			next if ($item eq ""
				|| !timeOut($items{$item}{appear_time}, $timeout{ai_items_gather_start}{timeout})
				|| $items{$item}{take_failed} >= 1
				|| $itemsPickup{lc($items{$item}{name})} eq "0"
				|| $itemsPickup{lc($items{$item}{name})} == -1
				|| ( !$itemsPickup{all} && !$itemsPickup{lc($items{$item}{name})} ) );
			if (!positionNearPlayer($items{$item}{pos}, 12)) {
				message "Gathering: $items{$item}{name} ($items{$item}{binID})\n";
				gather($item);
				last;
			}
		}
		$timeout{ai_items_gather_auto}{time} = time;
	}


	##### ITEMS GATHER #####

	if (AI::action eq "items_gather" && AI::args->{suspended}) {
		AI::args->{suspended}{ai_items_gather_giveup}{time} += time - AI::args->{suspended};
		delete AI::args->{suspended};
	}
	if (AI::action eq "items_gather" && !%{$items{AI::args->{ID}}}) {
		my $ID = AI::args->{ID};
		message "Failed to gather $items_old{$ID}{name} ($items_old{$ID}{binID}) : Lost target\n", "drop";
		AI::dequeue;

	} elsif (AI::action eq "items_gather") {
		my $ID = AI::args->{ID};
		my ($dist, $myPos);

		if (positionNearPlayer($items{$ID}{pos}, 12)) {
			message "Failed to gather $items{$ID}{name} ($items{$ID}{binID}) : No looting!\n", undef, 1;
			AI::dequeue;

		} elsif (timeOut(AI::args->{ai_items_gather_giveup})) {
			message "Failed to gather $items{$ID}{name} ($items{$ID}{binID}) : Timeout\n", undef, 1;
			$items{$ID}{take_failed}++;
			AI::dequeue;

		} elsif ($char->{sitting}) {
			AI::suspend();
			stand();

		} elsif (( $dist = distance($items{$ID}{pos}, ( $myPos = calcPosition($char) )) > 2 )) {
			my %vec, %pos;
			getVector(\%vec, $items{$ID}{pos}, $myPos);
			moveAlongVector(\%pos, $myPos, \%vec, $dist - 1);
			move($pos{x}, $pos{y});

		} else {
			AI::dequeue;
			take($ID);
		}
	}


	##### TAKE #####

	if (AI::action eq "take" && AI::args->{suspended}) {
		AI::args->{ai_take_giveup}{time} += time - AI::args->{suspended};
		delete AI::args->{suspended};
	}

	if (AI::action eq "take" && !%{$items{AI::args->{ID}}}) {
		AI::dequeue;

	} elsif (AI::action eq "take" && timeOut(AI::args->{ai_take_giveup})) {
		message "Failed to take $items{AI::args->{ID}}{name} ($items{AI::args->{ID}}{binID})\n",,1;
		$items{AI::args->{ID}}{take_failed}++;
		AI::dequeue;
		
	} elsif (AI::action eq "take") {
		my $ID = AI::args->{ID};
		my $myPos = calcPosition($char);
		my $dist = distance($items{$ID}{pos}, $myPos);
		
		if ($char->{sitting}) {
			stand();

		} elsif ($dist > 2) {
			my %vec, %pos;
			getVector(\%vec, $items{$ID}{pos}, $myPos);
			moveAlongVector(\%pos, $myPos, \%vec, $dist - 1);
			move($pos{x}, $pos{y});

		} elsif (timeOut($timeout{ai_take})) {
			sendTake(\$remote_socket, $ID);
			$timeout{ai_take}{time} = time;
		}
	}


	##### MOVE #####

	if (AI::action eq "move") {
		AI::args->{ai_move_giveup}{time} = time unless AI::args->{ai_move_giveup}{time};

		# Wait until we've stand up, if we're sitting
		if ($char->{sitting}) {
			AI::args->{ai_move_giveup}{time} = 0;
			stand();

		# Stop if the map changed
		} elsif (AI::args->{mapChanged}) {
			debug "Move - map change detected\n", "ai_move";
			AI::dequeue;

		# Stop if we've moved
		} elsif (AI::args->{time_move} != $char->{time_move}) {
			debug "Move - moving\n", "ai_move";
			AI::dequeue;

		# Stop if we've timed out
		} elsif (timeOut(AI::args->{ai_move_giveup})) {
			debug "Move - timeout\n", "ai_move";
			AI::dequeue;

		} elsif (timeOut($AI::Timeouts::move_retry, 0.5)) {
			# No update yet, send move request again.
			# We do this every 0.5 secs
			$AI::Timeouts::move_retry = time;
			sendMove(\$remote_socket, AI::args->{move_to}{x}, AI::args->{move_to}{y});
		}
	}

	##### AUTO-TELEPORT #####
	TELEPORT: {
		my $map_name_lu = $field{name}.'.rsw';
		my $safe = 0;

		if (!$cities_lut{$map_name_lu} && !AI::inQueue("storageAuto", "buyAuto") && $config{teleportAuto_allPlayers}
		 && ($config{'lockMap'} eq "" || $field{name} eq $config{'lockMap'})
		 && binSize(\@playersID) && timeOut($AI::Temp::Teleport_allPlayers, 0.75)) {
			message "Teleporting to avoid all players\n", "teleport";
			useTeleport(1);
			$ai_v{temp}{clear_aiQueue} = 1;
			$AI::Temp::Teleport_allPlayers = time;
		}

		# Check whether it's safe to teleport
		if ($config{teleportAuto_onlyWhenSafe}) {
			if (!$cities_lut{$map_name_lu} && timeOut($timeout{ai_teleport_safe_force})) {
				$safe = 1 if (!binSize(\@playersID));
				$timeout{ai_teleport_safe_force}{time} = time;
			}
		} elsif (!$cities_lut{$map_name_lu}) {
			$safe = 1;
			$timeout{ai_teleport_safe_force}{time} = time;
		}

		##### TELEPORT HP #####
		if ($safe && timeOut($timeout{ai_teleport_hp})
		  && ((($config{teleportAuto_hp} && percent_hp($char) <= $config{teleportAuto_hp}) || ($config{teleportAuto_sp} && percent_sp($char) <= $config{teleportAuto_sp})) && scalar(ai_getAggressives()) || ($config{teleportAuto_minAggressives} && scalar(ai_getAggressives()) >= $config{teleportAuto_minAggressives}))) {
			message "Teleporting due to insufficient HP/SP or too many aggressives\n", "teleport";
			useTeleport(1);
			$ai_v{temp}{clear_aiQueue} = 1;
			$timeout{ai_teleport_hp}{time} = time;
			last TELEPORT;
		}

		##### TELEPORT MONSTER #####
		if ($safe && timeOut($timeout{ai_teleport_away})) {
			foreach (@monstersID) {
				next unless $_;
				if ($mon_control{lc($monsters{$_}{name})}{teleport_auto} == 1) {
					message "Teleporting to avoid $monsters{$_}{name}\n", "teleport";
					useTeleport(1);
					$ai_v{temp}{clear_aiQueue} = 1;
					$AI::Timeouts::teleSearch = time;
					last TELEPORT;
				}
			}
			$timeout{ai_teleport_away}{time} = time;
		}

		##### TELEPORT SEARCH #####
		if ($safe && $config{'attackAuto'} && $config{'teleportAuto_search'}
		&& ($field{name} eq $config{'lockMap'} || $config{'lockMap'} eq "")) {
			if (AI::inQueue(qw/clientSuspend sitAuto sitting attack follow items_take items_gather take buyAuto skill_use sellAuto storageAuto/)) {
				$AI::Timeouts::teleSearch = time;
			}

			if (timeOut($AI::Timeouts::teleSearch, $timeout{ai_teleport_search}{timeout})) {
				my $do_search;
				foreach (values %mon_control) {
					if ($_->{teleport_search}) {
						$do_search = 1;
						last;
					}
				}
				if ($do_search) {
					my $found;
					foreach (@monstersID) {
						next unless $_;
						if ($mon_control{lc($monsters{$_}{name})}{teleport_search} && !$monsters{$_}{attack_failed}) {
							$found = 1;
							last;
						}
					}
					if (!$found) {
						message "Teleporting to search for monster\n", "teleport";
						useTeleport(1);
						$ai_v{temp}{clear_aiQueue} = 1;
						$AI::Timeouts::teleSearch = time;
						last TELEPORT;
					}
				}

				$AI::Timeouts::teleSearch = time;
			}

		} else {
			$AI::Timeouts::teleSearch = time;
		}


		##### TELEPORT IDLE / PORTAL #####
		if ($config{teleportAuto_idle} && AI::action ne "") {
			$timeout{ai_teleport_idle}{time} = time;
		}

		if ($safe && $config{teleportAuto_idle} && timeOut($timeout{ai_teleport_idle})){
			message "Teleporting due to idle\n", "teleport";
			useTeleport(1);
			$ai_v{temp}{clear_aiQueue} = 1;
			$timeout{ai_teleport_idle}{time} = time;
			last TELEPORT;
		}

		if ($safe && $config{teleportAuto_portal}
		  && ($config{'lockMap'} eq "" || $config{lockMap} eq $field{name})
		  && timeOut($timeout{ai_teleport_portal})) {
			if (scalar(@portalsID)) {
				message "Teleporting to avoid portal\n", "teleport";
				useTeleport(1);
				$ai_v{temp}{clear_aiQueue} = 1;
				$timeout{ai_teleport_portal}{time} = time;
				last TELEPORT;
			}
			$timeout{ai_teleport_portal}{time} = time;
		}
	} # end of block teleport


	##### AUTO RESPONSE #####

	if (AI::action eq "respAuto" && time >= $nextresptime) {
		my $i = AI::args->{resp_num};
		my $num_resp = getListCount($chat_resp{"words_resp_$i"});
		sendMessage(\$remote_socket, "c", getFromList($chat_resp{"words_resp_$i"}, int(rand() * ($num_resp - 1))));
		AI::dequeue;
	}

	if (AI::action eq "respPMAuto" && time >= $nextrespPMtime) {
		my $i = AI::args->{resp_num};
		my $privMsgUser = AI::args->{resp_user};
		$num_resp = getListCount($chat_resp{"words_resp_$i"});
		sendMessage(\$remote_socket, "pm", getFromList($chat_resp{"words_resp_$i"}, int(rand() * ($num_resp - 1))), $privMsgUser);
		AI::dequeue;
	}


	##### AVOID GM OR PLAYERS #####
	if (timeOut($timeout{ai_avoidcheck})) {
		avoidGM_near() if ($config{'avoidGM_near'} && (!$config{'avoidGM_near_inTown'} || !$cities_lut{$field{name}.'.rsw'}));
		avoidList_near() if $config{'avoidList'};
		$timeout{ai_avoidcheck}{time} = time;
	}


	##### SEND EMOTICON #####
	SENDEMOTION: {
		my $ai_sendemotion_index = AI::findAction("sendEmotion");
		last SENDEMOTION if (!defined $ai_sendemotion_index || time < AI::args->{timeout});
		sendEmotion(\$remote_socket, AI::args->{emotion});
		AI::clear("sendEmotion");
	}


	##### AUTO SHOP OPEN #####

	if ($config{'shopAuto_open'} && !AI::isIdle) {
		$timeout{ai_shop}{time} = time;
	}
	if ($config{'shopAuto_open'} && AI::isIdle && $conState == 5 && !$char->{sitting} && timeOut($timeout{ai_shop}) && !$shopstarted) {
		openShop();
	}


	##########

	# DEBUG CODE
	if (timeOut($ai_v{time}, 2) && $config{'debug'} >= 2) {
		my $len = @ai_seq_args;
		debug "AI: @ai_seq | $len\n", "ai", 2;
		$ai_v{time} = time;
	}
	$ai_v{'AI_last_finished'} = time;

	if ($ai_v{temp}{clear_aiQueue}) {
		delete $ai_v{temp}{clear_aiQueue};
		AI::clear;
	}

	Plugins::callHook('AI_post');
}


#######################################
#######################################
# Parse RO Client Send Message
#######################################
#######################################

sub parseSendMsg {
	my $msg = shift;

	$sendMsg = $msg;
	if (length($msg) >= 4 && $conState >= 4 && length($msg) >= unpack("S1", substr($msg, 0, 2))) {
		decrypt(\$msg, $msg);
	}
	$switch = uc(unpack("H2", substr($msg, 1, 1))) . uc(unpack("H2", substr($msg, 0, 1)));
	if ($config{'debugPacket_ro_sent'} && !existsInList($config{'debugPacket_exclude'}, $switch)) {
		if ($packetDescriptions{Send}{$switch}) {
			debug "Packet Switch SENT_BY_CLIENT: $switch - $packetDescriptions{Send}{$switch}\n", "parseSendMsg", 0;
		} else {
			debug "Packet Switch SENT_BY_CLIENT: $switch\n", "parseSendMsg", 0;
		}
	}

	# If the player tries to manually do something in the RO client, disable AI for a small period
	# of time using ai_clientSuspend().

	if ($switch eq "0066") {
 		# Login character selected
		configModify("char", unpack("C*",substr($msg, 2, 1)));

	} elsif ($switch eq "0072") {
		# Map login
		if ($config{'sex'} ne "") {
			$sendMsg = substr($sendMsg, 0, 18) . pack("C",$config{'sex'});
		}

	} elsif ($switch eq "007D") {
		# Map loaded
		$conState = 5;
		aiRemove("clientSuspend");
		$timeout{'ai'}{'time'} = time;
		if ($firstLoginMap) {
			undef $sentWelcomeMessage;
			undef $firstLoginMap;
		}
		$timeout{'welcomeText'}{'time'} = time;
		message "Map loaded\n", "connection";

	} elsif ($switch eq "0085") {
		# Move
		#aiRemove("clientSuspend");
		#makeCoords(\%coords, substr($msg, 2, 3));
		#ai_clientSuspend($switch, (distance($char->{'pos'}, \%coords) * $char->{walk_speed}) + 4);

	} elsif ($switch eq "0089") {
		# Attack
		if (!$config{'tankMode'} && !AI::inQueue("attack")) {
			aiRemove("clientSuspend");
			ai_clientSuspend($switch, 2, unpack("C*",substr($msg,6,1)), substr($msg,2,4));
		} else {
			undef $sendMsg;
		}

	} elsif ($switch eq "008C" || $switch eq "0108" || $switch eq "017E") {
		# Public, party and guild chat
		my $length = unpack("S",substr($msg,2,2));
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
		my $length = unpack("S",substr($msg,2,2));
		my ($user) = substr($msg, 4, 24) =~ /([\s\S]*?)\000/;
		my $chat = substr($msg, 28, $length - 29);
		$chat =~ s/^\s*//;

		stripLanguageCode(\$chat);

		my $prefix = quotemeta $config{'commandPrefix'};
		if ($chat =~ /^$prefix/) {
			$chat =~ s/^$prefix//;
			$chat =~ s/^\s*//;
			$chat =~ s/\s*$//;
			parseInput($chat, 1);
			undef $sendMsg;
		} else {
			undef %lastpm;
			$lastpm{'msg'} = $chat;
			$lastpm{'user'} = $user;
			push @lastpm, {%lastpm};
		}

	} elsif ($switch eq "009F") {
		# Take
		aiRemove("clientSuspend");
		ai_clientSuspend($switch, 2, substr($msg,2,4));

	} elsif ($switch eq "00B2") {
		# Trying to exit (respawn)
		aiRemove("clientSuspend");
		ai_clientSuspend($switch, 10);

	} elsif ($switch eq "018A") {
		# Trying to exit
		aiRemove("clientSuspend");
		ai_clientSuspend($switch, 10);

	} elsif ($switch eq "0149") {
		# Chat/skill mute
		undef $sendMsg;
	}

	if ($sendMsg ne "") {
		sendToServerByInject(\$remote_socket, $sendMsg);
	}
}


#######################################
#######################################
#Parse Message
#######################################
#######################################



##
# parseMsg(msg)
# msg: The data to parse, as received from the socket.
# Returns: The remaining bytes.
#
# When data (packets) from the RO server is received, it will be send to this
# function. It will determine what kind of packet this data is and process it.
# The length of the packets are gotten from recvpackets.txt.
#
# The received data does not always contain a complete packet, or may contain a
# piece of the next packet.
# If it contains a piece of the next packet too, parseMsg will delete the bytes
# of the first packet that's processed, and return the remaining bytes.
# If the data doesn't contain a complete packet, parseMsg will return "". $msg
# will be remembered by the main loop.
# Next time data from the RO server is received, the remaining bytes as returned
# by paseMsg, or the incomplete packet that the main loop remembered, will be
# prepended to the fresh data received from the RO server and then passed to
# parseMsg again.
# See also the main loop about how parseMsg's return value is treated.

# Types:
# word : 2-byte unsigned integer
# long : 4-byte unsigned integer
# byte : 1-byte character/integer
# bool : 1-byte boolean (true/false)
# string: an array of 1-byte characters, not NULL-terminated
sub parseMsg {
	my $msg = shift;
	my $msg_size;

	# Determine packet switch
	$switch = uc(unpack("H2", substr($msg, 1, 1))) . uc(unpack("H2", substr($msg, 0, 1)));
	if (length($msg) >= 4 && substr($msg,0,4) ne $accountID && $conState >= 4 && $lastswitch ne $switch
	 && length($msg) >= unpack("S1", substr($msg, 0, 2))) {
		decrypt(\$msg, $msg);
	}
	$switch = uc(unpack("H2", substr($msg, 1, 1))) . uc(unpack("H2", substr($msg, 0, 1)));
	if ($config{'debugPacket_received'} && !existsInList($config{'debugPacket_exclude'}, $switch)) {
		if ($packetDescriptions{Recv}{$switch} ne '') {
			debug "Packet: $switch - $packetDescriptions{Recv}{$switch}\n", "parseMsg", 0;
		} else {
			debug "Packet: $switch\n", "parseMsg", 0;
		}
	}

	# The user is running in X-Kore mode and wants to switch character.
	# We're now expecting an accountID.
	if ($conState == 2.5) {
		if (length($msg) >= 4) {
			$conState = 2;
			$accountID = substr($msg, 0, 4);
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
			$msg_size = unpack("S1", substr($msg, 2, 2));
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
				warning("Unknown packet - $switch\n", "connection");
				dumpData($msg) if ($config{'debugPacket_unparsed'});
			}
			return "";
		}
	}

	Plugins::callHook('parseMsg/pre', {switch => $switch, msg => $msg, msg_size => $msg_size});

	$lastPacketTime = time;
	if ((substr($msg,0,4) eq $accountID && ($conState == 2 || $conState == 4))
	 || ($config{'XKore'} && !$accountID && length($msg) == 4)) {
		$accountID = substr($msg, 0, 4);
		$AI = 1 if (!$AI_forcedOff);
		if ($config{'encrypt'} && $conState == 4) {
			my $encryptKey1 = unpack("L1", substr($msg, 6, 4));
			my $encryptKey2 = unpack("L1", substr($msg, 10, 4));
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

	} elsif ($switch eq "0069") {
		$conState = 2;
		undef $conState_tries;
		if ($versionSearch) {
			$versionSearch = 0;
			Misc::saveConfigFile();
		}
		$sessionID = substr($msg, 4, 4);
		$accountID = substr($msg, 8, 4);
		$sessionID2 = substr($msg, 12, 4);
		$accountSex = unpack("C1",substr($msg, 46, 1));
		$accountSex2 = ($config{'sex'} ne "") ? $config{'sex'} : $accountSex;
		message(swrite(
			"---------Account Info----------", [undef],
			"Account ID: @<<<<<<<<<<<<<<<<<<", [getHex($accountID)],
			"Sex:        @<<<<<<<<<<<<<<<<<<", [$sex_lut{$accountSex}],
			"Session ID: @<<<<<<<<<<<<<<<<<<", [getHex($sessionID)],
			"            @<<<<<<<<<<<<<<<<<<", [getHex($sessionID2)],
			"-------------------------------", [undef],
		), "connection");

		$num = 0;
		undef @servers;
		for($i = 47; $i < $msg_size; $i+=32) {
			$servers[$num]{'ip'} = makeIP(substr($msg, $i, 4));
			$servers[$num]{'ip'} = $masterServers{$config{'master'}}->{ip} if ($masterServers{$config{'master'}}->{private});
			$servers[$num]{'port'} = unpack("S1", substr($msg, $i+4, 2));
			($servers[$num]{'name'}) = substr($msg, $i + 6, 20) =~ /([\s\S]*?)\000/;
			$servers[$num]{'users'} = unpack("L",substr($msg, $i + 26, 4));
			$num++;
		}

		message("--------- Servers ----------\n", "connection");
		message("#         Name            Users  IP              Port\n", "connection");
		for ($num = 0; $num < @servers; $num++) {
			message(swrite(
				"@<< @<<<<<<<<<<<<<<<<<<<< @<<<<< @<<<<<<<<<<<<<< @<<<<<",
				[$num, $servers[$num]{'name'}, $servers[$num]{'users'}, $servers[$num]{'ip'}, $servers[$num]{'port'}]
			), "connection");
		}
		message("-------------------------------\n", "connection");

		if (!$config{'XKore'}) {
			message("Closing connection to Master Server\n", "connection");
			Network::disconnect(\$remote_socket);
			if ($config{'server'} eq "") {
				message("Choose your server.  Enter the server number: ", "input");
				$waitingForInput = 1;
			} else {
				message("Server $config{'server'} selected\n", "connection");
			}
		}

	} elsif ($switch eq "006A") {
		$type = unpack("C1",substr($msg, 2, 1));
		Network::disconnect(\$remote_socket);
		if ($type == 0) {
			error("Account name doesn't exist\n", "connection");
			if (!$config{'XKore'} && !$config{ignoreInvalidLogin}) {
				message("Enter Username Again: ", "input");
				$msg = $interface->getInput(-1);
				configModify('username', $msg, 1);
				$timeout_ex{'master'}{'time'} = 0;
				$conState_tries = 0;
			}
		} elsif ($type == 1) {
			error("Password Error\n", "connection");
			if (!$config{'XKore'}) {
				message("Enter Password Again: ", "input");
				# Set -9 on getInput timeout field mean this is password field
				$msg = $interface->getInput(-9);
				configModify('password', $msg, 1);
				$timeout_ex{'master'}{'time'} = 0;
				$conState_tries = 0;
			}
		} elsif ($type == 3) {
			error("Server connection has been denied\n", "connection");
		} elsif ($type == 4) {
			$interface->errorDialog("Critical Error: Your account has been blocked.");
			$quit = 1 if (!$config{'XKore'});
		} elsif ($type == 5) {
			my $master = $masterServers{$config{'master'}};
			error("Version $master->{version} failed... trying to find version\n", "connection");
			error("Master Version: $master->{master_version}\n", "connection");
			$master->{master_version}++;
			if (!$versionSearch) {
				$master->{master_version} = 0 if ($master->{master_version} > 1);
				$master->{version} = 0;
				$versionSearch = 1;
			} elsif ($master->{master_version} eq 60) {
				$master->{master_version} = 0;
				$master->{version}++;
			}
			relog(2);
		} elsif ($type == 6) {
			error("The server is temporarily blocking your connection\n", "connection");
		}
		if ($type != 5 && $versionSearch) {
			$versionSearch = 0;
			writeSectionedFileIntact("$Settings::control_folder/servers.txt", \%masterServers);
		}

	} elsif ($switch eq "006B") {
		message("Received characters from Game Login Server\n", "connection");
		$conState = 3;
		undef $conState_tries;
		undef @chars;

		my %options;
		Plugins::callHook('parseMsg/recvChars', \%options);
		if (exists $options{charServer}) {
			$charServer = $options{charServer};
		} else {
			$charServer = $remote_socket->peerhost . ":" . $remote_socket->peerport;
		}

		#my ($startVal, $num);
		#if ($config{"master_version_$config{'master'}"} ne "" && $config{"master_version_$config{'master'}"} == 0) {
		#	$startVal = 24;
		#} else {
		#	$startVal = 4;
		#}
		$startVal = $msg_size % 106;

		my $num;
		for (my $i = $startVal; $i < $msg_size; $i += 106) {
			#exp display bugfix - chobit andy 20030129
			$num = unpack("C1", substr($msg, $i + 104, 1));
			$chars[$num]{'exp'} = unpack("L1", substr($msg, $i + 4, 4));
			$chars[$num]{'zenny'} = unpack("L1", substr($msg, $i + 8, 4));
			$chars[$num]{'exp_job'} = unpack("L1", substr($msg, $i + 12, 4));
			$chars[$num]{'lv_job'} = unpack("C1", substr($msg, $i + 16, 1));
			$chars[$num]{'hp'} = unpack("S1", substr($msg, $i + 42, 2));
			$chars[$num]{'hp_max'} = unpack("S1", substr($msg, $i + 44, 2));
			$chars[$num]{'sp'} = unpack("S1", substr($msg, $i + 46, 2));
			$chars[$num]{'sp_max'} = unpack("S1", substr($msg, $i + 48, 2));
			$chars[$num]{'jobID'} = unpack("C1", substr($msg, $i + 52, 1));
			$chars[$num]{'ID'} = substr($msg, $i, 4);
			$chars[$num]{'lv'} = unpack("C1", substr($msg, $i + 58, 1));
			$chars[$num]{'hair_color'} = unpack("C1", substr($msg, $i + 70, 1));
			($chars[$num]{'name'}) = substr($msg, $i + 74, 24) =~ /([\s\S]*?)\000/;
			$chars[$num]{'str'} = unpack("C1", substr($msg, $i + 98, 1));
			$chars[$num]{'agi'} = unpack("C1", substr($msg, $i + 99, 1));
			$chars[$num]{'vit'} = unpack("C1", substr($msg, $i + 100, 1));
			$chars[$num]{'int'} = unpack("C1", substr($msg, $i + 101, 1));
			$chars[$num]{'dex'} = unpack("C1", substr($msg, $i + 102, 1));
			$chars[$num]{'luk'} = unpack("C1", substr($msg, $i + 103, 1));
			$chars[$num]{'sex'} = $accountSex2;
		}

		if (charSelectScreen(1) == 1) {
			$firstLoginMap = 1;
			$startingZenny = $chars[$config{'char'}]{'zenny'} unless defined $startingZenny;
			$sentWelcomeMessage = 1;
		} else {
			return;
		}

	} elsif ($switch eq "006C") {
		error("Error logging into Game Login Server (invalid character specified)...\n", "connection");
		$conState = 1;
		undef $conState_tries;
		$timeout_ex{'master'}{'time'} = time;
		$timeout_ex{'master'}{'timeout'} = $timeout{'reconnect'}{'timeout'};
		Network::disconnect(\$remote_socket);

	} elsif ($switch eq "006D") {
		my %char;
		$char{ID} = substr($msg, 2, 4);
		$char{name} = unpack("Z24", substr($msg, 76, 24));
		$char{zenny} = unpack("L", substr($msg, 10, 4));
		($char{str}, $char{agi}, $char{vit}, $char{int}, $char{dex}, $char{luk}) = unpack("C*", substr($msg, 100, 6));
		my $slot = unpack("C", substr($msg, 106, 1));

		$char{lv} = 1;
		$char{lv_job} = 1;
		$char{sex} = $accountSex2;
		$chars[$slot] = \%char;

		$conState = 3;
		message "Character $char{name} ($slot) created.\n", "info";
		if (charSelectScreen() == 1) {
			$conState = 3;
			$firstLoginMap = 1;
			$startingZenny = $chars[$config{'char'}]{'zenny'} unless defined $startingZenny;
			$sentWelcomeMessage = 1;
		} else {
			return;
		}

	} elsif ($switch eq "006E") {
		message "Character cannot be to created. If you didn't make any mistake, then the name you chose already exists.\n", "info";
		if (charSelectScreen() == 1) {
			$conState = 3;
			$firstLoginMap = 1;
			$startingZenny = $chars[$config{'char'}]{'zenny'} unless defined $startingZenny;
			$sentWelcomeMessage = 1;
		} else {
			return;
		}

	} elsif ($switch eq "006F") {
		if (defined $AI::temp::delIndex) {
			message "Character $chars[$AI::temp::delIndex]{name} ($AI::temp::delIndex) deleted.\n", "info";
			delete $chars[$AI::temp::delIndex];
			undef $AI::temp::delIndex;
			for (my $i = 0; $i < @chars; $i++) {
				delete $chars[$i] if ($chars[$i] && !scalar(keys %{$chars[$i]}))
			}
		} else {
			message "Character deleted.\n", "info";
		}

		if (charSelectScreen() == 1) {
			$conState = 3;
			$firstLoginMap = 1;
			$startingZenny = $chars[$config{'char'}]{'zenny'} unless defined $startingZenny;
			$sentWelcomeMessage = 1;
		} else {
			return;
		}

	} elsif ($switch eq "0070") {
		#my $errno = unpack("C", substr($msg, 2, 1));
		error "Character cannot be deleted. Your e-mail address was probably wrong.\n";
		undef $AI::temp::delIndex;
		if (charSelectScreen() == 1) {
			$conState = 3;
			$firstLoginMap = 1;
			$startingZenny = $chars[$config{'char'}]{'zenny'} unless defined $startingZenny;
			$sentWelcomeMessage = 1;
		} else {
			return;
		}

	} elsif ($switch eq "0071") {
		message "Received character ID and Map IP from Game Login Server\n", "connection";
		$conState = 4;
		undef $conState_tries;
		$charID = substr($msg, 2, 4);
		($map_name) = substr($msg, 6, 16) =~ /([\s\S]*?)\000/;

		($ai_v{'temp'}{'map'}) = $map_name =~ /([\s\S]*)\./;
		if ($ai_v{'temp'}{'map'} ne $field{'name'}) {
			getField("$Settings::def_field/$ai_v{'temp'}{'map'}.fld", \%field);
		}

		$map_ip = makeIP(substr($msg, 22, 4));
		$map_ip = $masterServers{$config{'master'}}->{ip} if ($masterServers{$config{'master'}}->{private});
		$map_port = unpack("S1", substr($msg, 26, 2));
		message(swrite(
			"---------Game Info----------", [],
			"Char ID: @<<<<<<<<<<<<<<<<<<",
			[getHex($charID)],
			"MAP Name: @<<<<<<<<<<<<<<<<<<",
			[$map_name],
			"MAP IP: @<<<<<<<<<<<<<<<<<<",
			[$map_ip],
			"MAP Port: @<<<<<<<<<<<<<<<<<<",
			[$map_port],
			"-------------------------------", []),
			"connection");
		message("Closing connection to Game Login Server\n", "connection") if (!$config{'XKore'});
		Network::disconnect(\$remote_socket) if (!$config{'XKore'});
		initStatVars();

	} elsif ($switch eq "0073") {
		$conState = 5;
		undef $conState_tries;
		$char = $chars[$config{'char'}];
		makeCoords(\%{$chars[$config{'char'}]{'pos'}}, substr($msg, 6, 3));
		%{$chars[$config{'char'}]{'pos_to'}} = %{$chars[$config{'char'}]{'pos'}};
		message("Your Coordinates: $chars[$config{'char'}]{'pos'}{'x'}, $chars[$config{'char'}]{'pos'}{'y'}\n", undef, 1);
		message("You are now in the game\n", "connection") if (!$config{'XKore'});
		message("Waiting for map to load...\n", "connection") if ($config{'XKore'});
		sendMapLoaded(\$remote_socket) if (!$config{'XKore'});
		sendIgnoreAll(\$remote_socket, "all") if ($config{'ignoreAll'});
		ai_clientSuspend(0, 10) if ($config{'XKore'});
		$timeout{'ai'}{'time'} = time if (!$config{'XKore'});

	} elsif ($switch eq "0075") {
		$conState = 5 if ($conState != 4 && $config{'XKore'});

	} elsif ($switch eq "0077") {
		$conState = 5 if ($conState != 4 && $config{'XKore'});

	} elsif ($switch eq "0078" || $switch eq "01D8") {
		# 0078: long ID, word speed, word state, word ailment, word look, word class, word hair,
		# word weapon, word head_option_bottom, word shield, word head_option_top, word head_option_mid,
		# word hair_color, word ?, word head_dir, long guild, long emblem, word manner, byte karma,
		# byte sex, 3byte coord, byte body_dir, byte ?, byte ?, byte sitting, word level
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		my $ID = substr($msg, 2, 4);
		my $walk_speed = unpack("S", substr($msg, 6, 2)) / 1000;
		my $type = unpack("S*",substr($msg, 14,  2));
		my $pet = unpack("C*",substr($msg, 16,  1));
		my $weapon = unpack("S1", substr($msg, 18, 2));
		my $lowhead = $headgears_lut[unpack("S1",substr($msg, 20,  2))];
		my $tophead = $headgears_lut[unpack("S1",substr($msg, 24,  2))];
		my $midhead = $headgears_lut[unpack("S1",substr($msg, 26,  2))];
		my $hair_color = unpack("S1", substr($msg, 28, 2));
		my $head_dir = unpack("S", substr($msg, 32, 2)) % 8;
		my $sex = unpack("C*",substr($msg, 45,  1));
		my %coords;
		makeCoords(\%coords, substr($msg, 46, 3));
		my $body_dir = unpack("C", substr($msg, 48, 1)) % 8;
		my $act = unpack("C*",substr($msg, 51,  1));
		my $lv = unpack("S*",substr($msg, 52,  2));
		my $added;

		if ($jobs_lut{$type}) {
			my $player = $players{$ID};
			if (!$player || !defined($player->{binID})) {
				$player = $players{$ID} ||= {};
				binAdd(\@playersID, $ID);
				$player->{appear_time} = time;
				$player->{ID} = $ID;
				$player->{jobID} = $type;
				$player->{sex} = $sex;
				$player->{name} = "Unknown";
				$player->{nameID} = unpack("L1", $ID);
				$player->{binID} = binFind(\@playersID, $ID);
				$player->{weapon} = $weapon;
				$added = 1;
			}

			$player->{walk_speed} = $walk_speed;
			$player->{headgear}{low} = $lowhead;
			$player->{headgear}{top} = $tophead;
			$player->{headgear}{mid} = $midhead;
			$player->{hair_color} = $hair_color;
			$player->{look}{body} = $body_dir;
			$player->{look}{head} = $head_dir;
			$player->{sitting} = $act > 0;
			$player->{lv} = $lv;
			$player->{pos} = {%coords};
			$player->{pos_to} = {%coords};
			debug "Player Exists: $player->{name} ($player->{binID}) $sex_lut{$player->{sex}} $jobs_lut{$player->{jobID}}\n", "parseMsg_presence", 1;

			objectAdded('player', $ID, $player) if ($added);

		} elsif ($type >= 1000) {
			if ($pet) {
				if (!%{$pets{$ID}}) {
					$pets{$ID}{'appear_time'} = time;
					$display = ($monsters_lut{$type} ne "") 
							? $monsters_lut{$type}
							: "Unknown ".$type;
					binAdd(\@petsID, $ID);
					$pets{$ID}{'nameID'} = $type;
					$pets{$ID}{'name'} = $display;
					$pets{$ID}{'name_given'} = "Unknown";
					$pets{$ID}{'binID'} = binFind(\@petsID, $ID);
					$added = 1;
				}
				$pets{$ID}{'walk_speed'} = $walk_speed;
				%{$pets{$ID}{'pos'}} = %coords;
				%{$pets{$ID}{'pos_to'}} = %coords;
				debug "Pet Exists: $pets{$ID}{'name'} ($pets{$ID}{'binID'})\n", "parseMsg";

				objectAdded('pet', $ID, $pets{$ID}) if ($added);

			} else {
				if (!%{$monsters{$ID}}) {
					$monsters{$ID}{'appear_time'} = time;
					$display = ($monsters_lut{$type} ne "") 
							? $monsters_lut{$type}
							: "Unknown ".$type;
					binAdd(\@monstersID, $ID);
					$monsters{$ID}{ID} = $ID;
					$monsters{$ID}{'nameID'} = $type;
					$monsters{$ID}{'name'} = $display;
					$monsters{$ID}{'binID'} = binFind(\@monstersID, $ID);
					$added = 1;
				}
				$monsters{$ID}{'walk_speed'} = $walk_speed;
				%{$monsters{$ID}{'pos'}} = %coords;
				%{$monsters{$ID}{'pos_to'}} = %coords;

				debug "Monster Exists: $monsters{$ID}{'name'} ($monsters{$ID}{'binID'})\n", "parseMsg_presence", 1;


				# Monster state
				my $param1 = unpack("S*", substr($msg, 8, 2));
				$param1 = 0 if $param1 == 5; # 5 has got something to do with the monster being undead
				foreach (keys %skillsState) {
					if ($param1 == $_) {
						$monsters{$ID}{statuses}{$skillsState{$_}} = 1;
						message getActorName($ID) . " in $skillsState{$_} state\n", "parseMsg_statuslook", 1;
					} elsif (defined $monsters{$ID}{statuses}{$skillsState{$_}}) {
						delete $monsters{$ID}{statuses}{$skillsState{$_}};
						message getActorName($ID) . " out of $skillsState{$_} state\n", "parseMsg_statuslook", 1;
					}
				}

				objectAdded('monster', $ID, $monsters{$ID}) if ($added);
			}

		} elsif ($type == 45) {
			if (!%{$portals{$ID}}) {
				$portals{$ID}{'appear_time'} = time;
				$nameID = unpack("L1", $ID);
				$exists = portalExists($field{'name'}, \%coords);
				$display = ($exists ne "")
					? "$portals_lut{$exists}{'source'}{'map'} -> " . getPortalDestName($exists)
					: "Unknown ".$nameID;
				binAdd(\@portalsID, $ID);
				$portals{$ID}{'source'}{'map'} = $field{'name'};
				$portals{$ID}{'type'} = $type;
				$portals{$ID}{'nameID'} = $nameID;
				$portals{$ID}{'name'} = $display;
				$portals{$ID}{'binID'} = binFind(\@portalsID, $ID);
			}
			%{$portals{$ID}{'pos'}} = %coords;
			message "Portal Exists: $portals{$ID}{'name'} ($coords{x}, $coords{y}) - ($portals{$ID}{'binID'})\n", "portals", 1;

		} elsif ($type < 1000) {
			if (!%{$npcs{$ID}}) {
				$npcs{$ID}{'appear_time'} = time;
				$nameID = unpack("L1", $ID);
				$display = (%{$npcs_lut{$nameID}}) 
					? $npcs_lut{$nameID}{'name'}
					: "Unknown ".$nameID;
				binAdd(\@npcsID, $ID);
				$npcs{$ID}{'type'} = $type;
				$npcs{$ID}{'nameID'} = $nameID;
				$npcs{$ID}{'name'} = $display;
				$npcs{$ID}{'binID'} = binFind(\@npcsID, $ID);
				$added = 1;
			}
			$npcs{$ID}{'pos'} = {%coords};
			message "NPC Exists: $npcs{$ID}{'name'} ($npcs{$ID}{pos}->{x}, $npcs{$ID}{pos}->{y}) (ID $npcs{$ID}{'nameID'}) - ($npcs{$ID}{'binID'})\n", undef, 1;

			objectAdded('npc', $ID, $npcs{$ID}) if ($added);

		} else {
			debug "Unknown Exists: $type - ".unpack("L*",$ID)."\n", "parseMsg";
		}

	} elsif ($switch eq "0079" || $switch eq "01D9") {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		my $ID = substr($msg, 2, 4);
		my $walk_speed = unpack("S", substr($msg, 6, 2)) / 1000;
		my $type = unpack("S*", substr($msg, 14,  2));
		my $weapon = unpack("S1", substr($msg, 18, 2));
		my $lowhead = $headgears_lut[unpack("S1",substr($msg, 20,  2))];
		my $tophead = $headgears_lut[unpack("S1",substr($msg, 24,  2))];
		my $midhead = $headgears_lut[unpack("S1",substr($msg, 26,  2))];
		my $hair_color = unpack("S1", substr($msg, 28, 2));
		my $sex = unpack("C*", substr($msg, 45,  1));
		my %coords;
		makeCoords(\%coords, substr($msg, 46, 3));
		my $lv = unpack("S*", substr($msg, 51,  2));

		if ($jobs_lut{$type}) {
			my $added;
			if (!$players{$ID} || !defined($players{$ID}{binID})) {
				$players{$ID}{'appear_time'} = time;
				binAdd(\@playersID, $ID);
				$players{$ID}{'ID'} = $ID;
				$players{$ID}{'jobID'} = $type;
				$players{$ID}{'sex'} = $sex;
				$players{$ID}{'name'} = "Unknown";
				$players{$ID}{'nameID'} = unpack("L1", $ID);
				$players{$ID}{'binID'} = binFind(\@playersID, $ID);
				$players{$ID}{weapon} = $weapon;
				$added = 1;
			}

			$players{$ID}{walk_speed} = $walk_speed;
			$players{$ID}{headgear}{low} = $lowhead;
			$players{$ID}{headgear}{top} = $tophead;
			$players{$ID}{headgear}{mid} = $midhead;
			$players{$ID}{hair_color} = $hair_color;
			$players{$ID}{look}{body} = 0;
			$players{$ID}{look}{head} = 0;
			$players{$ID}{lv} = $lv;
			$players{$ID}{pos} = {%coords};
			$players{$ID}{pos_to} = {%coords};
			debug "Player Connected: $players{$ID}{'name'} ($players{$ID}{'binID'}) $sex_lut{$players{$ID}{'sex'}} $jobs_lut{$players{$ID}{'jobID'}}\n", "parseMsg_presence";

			objectAdded('player', $ID, $players{$ID}) if ($added);

		} else {
			debug "Unknown Connected: $type - ", "parseMsg";
		}

	} elsif ($switch eq "007A") {
		$conState = 5 if ($conState != 4 && $config{'XKore'});

	} elsif ($switch eq "007B" || $switch eq "01DA") {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		my $ID = substr($msg, 2, 4);
		my $walk_speed = unpack("S", substr($msg, 6, 2)) / 1000;
		my $type = unpack("S*",substr($msg, 14,  2));
		my $pet = unpack("C*",substr($msg, 16,  1));
		my $weapon = unpack("S1", substr($msg, 18, 2));
		my $lowhead = $headgears_lut[unpack("S1",substr($msg, 20,  2))];
		my $tophead = $headgears_lut[unpack("S1",substr($msg, 28,  2))];
		my $midhead = $headgears_lut[unpack("S1",substr($msg, 30,  2))];
		my $hair_color = unpack("S1",substr($msg, 32,  2));
		my $sex = unpack("C*",substr($msg, 49,  1));
		my (%coordsFrom, %coordsTo);
		makeCoords(\%coordsFrom, substr($msg, 50, 3));
		makeCoords2(\%coordsTo, substr($msg, 52, 3));
		my $lv = unpack("S*",substr($msg, 58,  2));

		my $added;
		my %vec;
		getVector(\%vec, \%coordsTo, \%coordsFrom);
		my $direction = int sprintf("%.0f", (360 - vectorToDegree(\%vec)) / 45);

		if ($jobs_lut{$type}) {
			if (!$players{$ID} && !defined($players{$ID}{binID})) {
				binAdd(\@playersID, $ID);
				$players{$ID}{'appear_time'} = time;
				$players{$ID}{'sex'} = $sex;
				$players{$ID}{'ID'} = $ID;
				$players{$ID}{'jobID'} = $type;
				$players{$ID}{'name'} = "Unknown";
				$players{$ID}{'nameID'} = unpack("L1", $ID);
				$players{$ID}{'binID'} = binFind(\@playersID, $ID);
				$players{$ID}{weapon} = $weapon;
				debug "Player Appeared: $players{$ID}{'name'} ($players{$ID}{'binID'}) $sex_lut{$sex} $jobs_lut{$type}\n", "parseMsg_presence";
				$added = 1;
			}

			$players{$ID}{walk_speed} = $walk_speed;
			$players{$ID}{look}{head} = 0;
			$players{$ID}{look}{body} = $direction;
			$players{$ID}{headgear}{low} = $lowhead;
			$players{$ID}{headgear}{top} = $tophead;
			$players{$ID}{headgear}{mid} = $midhead;
			$players{$ID}{hair_color} = $hair_color;
			$players{$ID}{lv} = $lv;
			$players{$ID}{pos} = {%coordsFrom};
			$players{$ID}{pos_to} = {%coordsTo};
			$players{$ID}{time_move} = time;
			$players{$ID}{time_move_calc} = distance(\%coordsFrom, \%coordsTo) * $walk_speed;
			debug "Player Moved: $players{$ID}{'name'} ($players{$ID}{'binID'}) $sex_lut{$players{$ID}{'sex'}} $jobs_lut{$players{$ID}{'jobID'}}\n", "parseMsg";

			objectAdded('player', $ID, $players{$ID}) if ($added);

		} elsif ($type >= 1000) {
			if ($pet) {
				if (!%{$pets{$ID}}) {
					$pets{$ID}{'appear_time'} = time;
					$display = ($monsters_lut{$type} ne "") 
							? $monsters_lut{$type}
							: "Unknown ".$type;
					binAdd(\@petsID, $ID);
					$pets{$ID}{'nameID'} = $type;
					$pets{$ID}{'name'} = $display;
					$pets{$ID}{'name_given'} = "Unknown";
					$pets{$ID}{'binID'} = binFind(\@petsID, $ID);
				}
				$pets{$ID}{look}{head} = 0;
				$pets{$ID}{look}{body} = $direction;
				$pets{$ID}{pos} = {%coordsFrom};
				$pets{$ID}{pos_to} = {%coordsTo};
				$pets{$ID}{time_move} = time;
				$pets{$ID}{time_move_calc} = distance(\%coordsFrom, \%coordsTo) * $walk_speed;
				$pets{$ID}{walk_speed} = $walk_speed;
				if ($monsters{$ID}) {
					binRemove(\@monstersID, $ID);
					delete $monsters{$ID};
					objectRemoved('monster', $ID);
				}
				debug "Pet Moved: $pets{$ID}{'name'} ($pets{$ID}{'binID'})\n", "parseMsg";

			} else {
				if (!%{$monsters{$ID}}) {
					binAdd(\@monstersID, $ID);
					$monsters{$ID}{ID} = $ID;
					$monsters{$ID}{'appear_time'} = time;
					$monsters{$ID}{'nameID'} = $type;
					$display = ($monsters_lut{$type} ne "") 
						? $monsters_lut{$type}
						: "Unknown ".$type;
					$monsters{$ID}{'nameID'} = $type;
					$monsters{$ID}{'name'} = $display;
					$monsters{$ID}{'binID'} = binFind(\@monstersID, $ID);
					debug "Monster Appeared: $monsters{$ID}{'name'} ($monsters{$ID}{'binID'})\n", "parseMsg_presence";
					$added = 1;
				}
				$monsters{$ID}{look}{head} = 0;
				$monsters{$ID}{look}{body} = $direction;
				$monsters{$ID}{pos} = {%coordsFrom};
				$monsters{$ID}{pos_to} = {%coordsTo};
				$monsters{$ID}{time_move} = time;
				$monsters{$ID}{time_move_calc} = distance(\%coordsFrom, \%coordsTo) * $walk_speed;
				$monsters{$ID}{walk_speed} = $walk_speed;
				debug "Monster Moved: $monsters{$ID}{'name'} ($monsters{$ID}{'binID'})\n", "parseMsg", 2;

				objectAdded('monster', $ID, $monsters{$ID}) if ($added);
			}
		} else {
			debug "Unknown Moved: $type - ".getHex($ID)."\n", "parseMsg";
		}

	} elsif ($switch eq "007C") {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		my $ID = substr($msg, 2, 4);
		my %coords;
		makeCoords(\%coords, substr($msg, 36, 3));
		my $type = unpack("S*",substr($msg, 20,  2));
		my $pet = unpack("C*",substr($msg, 22,  1));
		my $sex = unpack("C*",substr($msg, 35,  1));
		my $added;

		if ($jobs_lut{$type}) {
			if (!$players{$ID} || !defined($players{$ID}{binID})) {
				binAdd(\@playersID, $ID);
				$players{$ID}{'jobID'} = $type;
				$players{$ID}{'sex'} = $sex;
				$players{$ID}{'ID'} = $ID;
				$players{$ID}{'name'} = "Unknown";
				$players{$ID}{'nameID'} = unpack("L1", $ID);
				$players{$ID}{'appear_time'} = time;
				$players{$ID}{'binID'} = binFind(\@playersID, $ID);
				$added = 1;
			}
			$players{$ID}{look}{head} = 0;
			$players{$ID}{look}{body} = 0;
			$players{$ID}{pos} = {%coords};
			$players{$ID}{pos_to} = {%coords};
			debug "Player Spawned: $players{$ID}{'name'} ($players{$ID}{'binID'}) $sex_lut{$players{$ID}{'sex'}} $jobs_lut{$players{$ID}{'jobID'}}\n", "parseMsg";

			objectAdded('player', $ID, $players{$ID}) if ($added);

		} elsif ($type >= 1000) {
			if ($pet) {
				if (!%{$pets{$ID}}) { 
					binAdd(\@petsID, $ID); 
					$pets{$ID}{'nameID'} = $type; 
					$pets{$ID}{'appear_time'} = time; 
					$display = ($monsters_lut{$pets{$ID}{'nameID'}} ne "") 
					? $monsters_lut{$pets{$ID}{'nameID'}} 
					: "Unknown ".$pets{$ID}{'nameID'}; 
					$pets{$ID}{'name'} = $display; 
					$pets{$ID}{'name_given'} = "Unknown";
					$pets{$ID}{'binID'} = binFind(\@petsID, $ID); 
				}
				$pets{$ID}{look}{head} = 0;
				$pets{$ID}{look}{body} = 0;
				%{$pets{$ID}{'pos'}} = %coords; 
				%{$pets{$ID}{'pos_to'}} = %coords; 
				debug "Pet Spawned: $pets{$ID}{'name'} ($pets{$ID}{'binID'})\n", "parseMsg";

			} else {
				if (!%{$monsters{$ID}}) {
					binAdd(\@monstersID, $ID);
					$monsters{$ID}{ID} = $ID;
					$monsters{$ID}{'nameID'} = $type;
					$monsters{$ID}{'appear_time'} = time;
					$display = ($monsters_lut{$monsters{$ID}{'nameID'}} ne "") 
							? $monsters_lut{$monsters{$ID}{'nameID'}}
							: "Unknown ".$monsters{$ID}{'nameID'};
					$monsters{$ID}{'name'} = $display;
					$monsters{$ID}{'binID'} = binFind(\@monstersID, $ID);
					$added = 1;
				}
				$monsters{$ID}{look}{head} = 0;
				$monsters{$ID}{look}{body} = 0;
				%{$monsters{$ID}{'pos'}} = %coords;
				%{$monsters{$ID}{'pos_to'}} = %coords;
				debug "Monster Spawned: $monsters{$ID}{'name'} ($monsters{$ID}{'binID'})\n", "parseMsg_presence";

				objectAdded('monster', $ID, $monsters{$ID}) if ($added);
			}

		} else {
			debug "Unknown Spawned: $type - ".getHex($ID)."\n", "parseMsg";
		}
		
	} elsif ($switch eq "007F") {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		$time = unpack("L1",substr($msg, 2, 4));
		debug "Received Sync\n", "parseMsg", 2;
		$timeout{'play'}{'time'} = time;

	} elsif ($switch eq "0080") {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		$ID = substr($msg, 2, 4);
		$type = unpack("C1",substr($msg, 6, 1));

		if ($ID eq $accountID) {
			message "You have died\n";
			closeShop() unless !$shopstarted || $config{'dcOnDeath'} == -1;
			$chars[$config{'char'}]{'deathCount'}++;
			$chars[$config{'char'}]{'dead'} = 1;
			$chars[$config{'char'}]{'dead_time'} = time;

		} elsif (%{$monsters{$ID}}) {
			%{$monsters_old{$ID}} = %{$monsters{$ID}};
			$monsters_old{$ID}{'gone_time'} = time;
			if ($type == 0) {
				debug "Monster Disappeared: $monsters{$ID}{'name'} ($monsters{$ID}{'binID'})\n", "parseMsg_presence";
				$monsters_old{$ID}{'disappeared'} = 1;

			} elsif ($type == 1) {
				debug "Monster Died: $monsters{$ID}{'name'} ($monsters{$ID}{'binID'})\n", "parseMsg_damage";
				$monsters_old{$ID}{'dead'} = 1;

				if ($config{itemsTakeAuto_party} &&
				    $monsters_old{$ID}{dmgFromParty} > 0) {
					AI::clear("items_take");
					ai_items_take($monsters_old{$ID}{pos}{x}, $monsters_old{$ID}{pos}{y},
						$monsters_old{$ID}{pos_to}{x}, $monsters_old{$ID}{pos_to}{y});
				}

			} elsif ($type == 2) { # What's this?
				debug "Monster Disappeared: $monsters{$ID}{'name'} ($monsters{$ID}{'binID'})\n", "parseMsg_presence";
				$monsters_old{$ID}{'disappeared'} = 1;

			} elsif ($type == 3) {
				debug "Monster Teleported: $monsters{$ID}{'name'} ($monsters{$ID}{'binID'})\n", "parseMsg_presence";
				$monsters_old{$ID}{'teleported'} = 1;
			}
			binRemove(\@monstersID, $ID);
			delete $monsters{$ID};
			objectRemoved('monster', $ID);

		} elsif (%{$players{$ID}}) {
			if ($type == 1) {
				message "Player Died: $players{$ID}{'name'} ($players{$ID}{'binID'}) $sex_lut{$players{$ID}{'sex'}} $jobs_lut{$players{$ID}{'jobID'}}\n";
				$players{$ID}{'dead'} = 1;
			} else {
				if ($type == 0) {
					debug "Player Disappeared: $players{$ID}{'name'} ($players{$ID}{'binID'}) $sex_lut{$players{$ID}{'sex'}} $jobs_lut{$players{$ID}{'jobID'}}\n", "parseMsg_presence";
					$players{$ID}{'disappeared'} = 1;
				} elsif ($type == 2) {
					debug "Player Disconnected: $players{$ID}{'name'} ($players{$ID}{'binID'}) $sex_lut{$players{$ID}{'sex'}} $jobs_lut{$players{$ID}{'jobID'}}\n", "parseMsg_presence";
					$players{$ID}{'disconnected'} = 1;
				} elsif ($type == 3) {
					debug "Player Teleported: $players{$ID}{'name'} ($players{$ID}{'binID'}) $sex_lut{$players{$ID}{'sex'}} $jobs_lut{$players{$ID}{'jobID'}}\n", "parseMsg_presence";
					$players{$ID}{'teleported'} = 1;
				} else {
					debug "Player Disappeared in an unknown way: $players{$ID}{'name'} ($players{$ID}{'binID'}) $sex_lut{$players{$ID}{'sex'}} $jobs_lut{$players{$ID}{'jobID'}}\n", "parseMsg_presence";
					$players{$ID}{'disappeared'} = 1;
				}

				%{$players_old{$ID}} = %{$players{$ID}};
				$players_old{$ID}{'gone_time'} = time;
				binRemove(\@playersID, $ID);
				delete $players{$ID};

				binRemove(\@venderListsID, $ID);
				delete $venderLists{$ID};

				objectRemoved('player', $ID);
			}

		} elsif (%{$players_old{$ID}}) {
			if ($type == 2) {
				debug "Player Disconnected: $players_old{$ID}{'name'}\n", "parseMsg_presence";
				$players_old{$ID}{'disconnected'} = 1;
			} elsif ($type == 3) {
				debug "Player Teleported: $players_old{$ID}{'name'}\n", "parseMsg_presence";
				$players_old{$ID}{'teleported'} = 1;
			}

		} elsif (%{$portals{$ID}}) {
			debug "Portal Disappeared: $portals{$ID}{'name'} ($portals{$ID}{'binID'})\n", "parseMsg";
			%{$portals_old{$ID}} = %{$portals{$ID}};
			$portals_old{$ID}{'disappeared'} = 1;
			$portals_old{$ID}{'gone_time'} = time;
			binRemove(\@portalsID, $ID);
			delete $portals{$ID};

		} elsif (%{$npcs{$ID}}) {
			debug "NPC Disappeared: $npcs{$ID}{'name'} ($npcs{$ID}{'binID'})\n", "parseMsg";
			%{$npcs_old{$ID}} = %{$npcs{$ID}};
			$npcs_old{$ID}{'disappeared'} = 1;
			$npcs_old{$ID}{'gone_time'} = time;
			binRemove(\@npcsID, $ID);
			delete $npcs{$ID};
			objectRemoved('npc', $ID);

		} elsif (%{$pets{$ID}}) {
			debug "Pet Disappeared: $pets{$ID}{'name'} ($pets{$ID}{'binID'})\n", "parseMsg";
			binRemove(\@petsID, $ID);
			delete $pets{$ID};
		} else {
			debug "Unknown Disappeared: ".getHex($ID)."\n", "parseMsg";
		}

	} elsif ($switch eq "0081") {
		if ($config{dcOnDisconnect} && $conState == 5) {
			message "Lost connection; exiting\n";
			$quit = 1;
		}
		$type = unpack("C1", substr($msg, 2, 1));
		$conState = 1;
		undef $conState_tries;

		$timeout_ex{'master'}{'time'} = time;
		$timeout_ex{'master'}{'timeout'} = $timeout{'reconnect'}{'timeout'};
		Network::disconnect(\$remote_socket);

		if ($type == 2) {
			if ($config{'dcOnDualLogin'} == 1) {
				$interface->errorDialog("Critical Error: Dual login prohibited - Someone trying to login!\n\n" .
					"$Settings::NAME will now immediately disconnect.");
				$quit = 1;
			} elsif ($config{'dcOnDualLogin'} >= 2) {
				error("Critical Error: Dual login prohibited - Someone trying to login!\n", "connection");
				message "Disconnect for $config{'dcOnDualLogin'} seconds...\n", "connection";
				$timeout_ex{'master'}{'timeout'} = $config{'dcOnDualLogin'};
			} else {
				error("Critical Error: Dual login prohibited - Someone trying to login!\n", "connection");
			}

		} elsif ($type == 3) {
			error("Error: Out of sync with server\n", "connection");
		} elsif ($type == 6) {
			$interface->errorDialog("Critical Error: You must pay to play this account!");
			$quit = 1 if (!$config{'XKore'});
		} elsif ($type == 8) {
			error("Error: The server still recognizes your last connection\n", "connection");
		} elsif ($type == 15) {
			error("You have been forced to disconnect by a GM\n", "connection");
		} else {
			error("Unknown error $type\n", "connection");
		}

	} elsif ($switch eq "0087") {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		my $unknown = unpack("C1", substr($msg, 11, 1));
		makeCoords($char->{pos}, substr($msg, 6, 3));
		makeCoords2($char->{pos_to}, substr($msg, 8, 3));
		my $dist = sprintf("%.1f", distance($char->{pos}, $char->{pos_to}));
		debug "You're moving from ($char->{pos}{x}, $char->{pos}{y}) to ($char->{pos_to}{x}, $char->{pos_to}{y}) - distance $dist, unknown $unknown\n", "parseMsg_move";
		$char->{time_move} = time;
		$char->{time_move_calc} = distance($char->{pos}, $char->{pos_to}) * ($char->{walk_speed} || 0.12);

	} elsif ($switch eq "0088") {
		# Object has been attacked; position changed
		my $ID = substr($msg, 2, 4);
		my %coords;
		$coords{x} = unpack("S1", substr($msg, 6, 2));
		$coords{y} = unpack("S1", substr($msg, 8, 2));
		if ($ID eq $accountID) {
			%{$chars[$config{'char'}]{'pos'}} = %coords;
			%{$chars[$config{'char'}]{'pos_to'}} = %coords;
			$char->{sitting} = 0;
			debug "Movement interrupted, your coordinates: $coords{x}, $coords{y}\n", "parseMsg_move";
			aiRemove("move");
		} elsif ($monsters{$ID}) {
			%{$monsters{$ID}{pos}} = %coords;
			%{$monsters{$ID}{pos_to}} = %coords;
			$monsters{$ID}{sitting} = 0;
		} elsif ($players{$ID}) {
			%{$players{$ID}{pos}} = %coords;
			%{$players{$ID}{pos_to}} = %coords;
			$players{$ID}{sitting} = 0;
		}

	} elsif ($switch eq "008A") {
		$conState = 5 if ($conState != 4 && $xkore);
		my ($ID1, $ID2, $tick, $src_speed, $dst_speed, $damage, $param2, $type, $param3) = unpack("x2 a4 a4 a4 L1 L1 s1 S1 C1 S1", $msg);

		if ($type == 1) {
			# Take item
			my ($source, $verb, $target) = getActorNames($ID1, $ID2, 'pick up', 'picks up');
			debug "$source $verb $target\n", 'parseMsg_presence';
			$items{$ID2}{takenBy} = $ID1 if ($items{$ID2});
		} elsif ($type == 2) {
			# Sit
			my ($source, $verb) = getActorNames($ID1, 0, 'are', 'is');
			if ($ID1 eq $accountID) {
				message "You are sitting.\n";
				$char->{sitting} = 1;
			} else {
				debug getActorName($ID1)." is sitting.\n", 'parseMsg';
				$players{$ID1}{sitting} = 1 if ($players{$ID1});
			}
		} elsif ($type == 3) {
			# Stand
			my ($source, $verb) = getActorNames($ID1, 0, 'are', 'is');
			if ($ID1 eq $accountID) {
				message "You are standing.\n";
				$char->{sitting} = 0;
			} else {
				debug getActorName($ID1)." is standing.\n", 'parseMsg';
				$players{$ID1}{sitting} = 0 if ($players{$ID1});
			}
		} else {
			# Attack
			my $dmgdisplay;
			if ($damage == 0) {
				$dmgdisplay = "Miss!";
				$dmgdisplay .= "!" if ($type == 11);
			} else {
				$dmgdisplay = $damage;
				$dmgdisplay .= "!" if ($type == 10);
				$dmgdisplay .= " + $param3" if $param3;
			}

			updateDamageTables($ID1, $ID2, $damage);

			my ($source, $verb, $target) = getActorNames($ID1, $ID2, 'attack', 'attacks');
			my $msg = "$source $verb $target - Dmg: $dmgdisplay (delay ".($src_speed/10).")";

			my $status = sprintf("[%3d/%3d]", percent_hp($char), percent_sp($char));

			if ($ID1 eq $accountID) {
				message("$status $msg\n", $damage > 0 ? "attackMon" : "attackMonMiss");
				if ($startedattack) {
					$monstarttime = time();
					$monkilltime = time();
					$startedattack = 0;
				}
				calcStat($damage);
			} elsif ($ID2 eq $accountID) {
				# Check for monster with empty name
				if (%{$monsters{$ID1}} && $monsters{$ID1}{'name'} eq "") {
					if ($config{'teleportAuto_emptyName'} ne '0') {
						message "Monster with empty name attacking you. Teleporting...\n";
						useTeleport(1);
					} else {
						# Delete monster from hash; monster will be
						# re-added to the hash next time it moves.
						delete $monsters{$ID1};
					}
				}
				message("$status $msg\n", $damage > 0 ? "attacked" : "attackedMiss");
			} else {
				debug("$msg\n", 'parseMsg_damage');
			}
		}

	} elsif ($switch eq "008D") {
		my $ID = substr($msg, 4, 4);
		my $chat = substr($msg, 8, $msg_size - 8);
		$chat =~ s/\000//g;
		my ($chatMsgUser, $chatMsg) = $chat =~ /([\s\S]*?) : ([\s\S]*)/;
		$chatMsgUser =~ s/ $//;

		stripLanguageCode(\$chatMsg);

		foreach (@playersID) {
			next unless $_;
			if (lc($players{$_}{name}) eq lc($chatMsgUser)) {
				$ID = $_;
				last;
			}
		}

		$dist = distance(\%{$chars[$config{'char'}]{'pos_to'}}, \%{$players{$ID}{'pos_to'}});
		$dist = sprintf("%.2f",$dist);

		$chat = "[dist=${dist}] $chatMsgUser : $chatMsg";
		($map_string) = $map_name =~ /([\s\S]*)\.gat/;
		chatLog("c", "[$map_string ${$chars[$config{'char'}]{'pos_to'}}{x}, ${$chars[$config{'char'}]{'pos_to'}}{y}] [${$players{$ID}{'pos_to'}}{x}, ${$players{$ID}{'pos_to'}}{y}] $chat\n") if ($config{'logChat'});
		message "$chat\n", "publicchat";

		ChatQueue::add('c', $ID, $chatMsgUser, $chatMsg);
		Plugins::callHook('packet_pubMsg', { 
			pubMsgUser => $chatMsgUser, 
			pubMsg => $chatMsg 
		}); 

	} elsif ($switch eq "008E") {
		my $chat = substr($msg, 4, $msg_size - 4);
		$chat =~ s/\000//g;
		my ($chatMsgUser, $chatMsg) = $chat =~ /(.*?) : (.*)/;
		# Note: $chatMsgUser/Msg may be undefined. This is the case on
		# eAthena servers: it uses this packet for non-chat server messages.

		if (defined $chatMsgUser) {
			stripLanguageCode(\$chatMsg);
			$chat = "$chatMsgUser : $chatMsg";
		}

		chatLog("c", "$chat\n") if ($config{'logChat'});
		message "$chat\n", "selfchat";

	} elsif ($switch eq "0091") {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		initMapChangeVars();
		for ($i = 0; $i < @ai_seq; $i++) {
			ai_setMapChanged($i);
		}
		$ai_v{'portalTrace_mapChanged'} = 1;

		($map_name) = substr($msg, 2, 16) =~ /([\s\S]*?)\000/;
		($ai_v{'temp'}{'map'}) = $map_name =~ /([\s\S]*)\./;
		if ($ai_v{'temp'}{'map'} ne $field{'name'}) {
			getField("$Settings::def_field/$ai_v{'temp'}{'map'}.fld", \%field);
		}
		$coords{'x'} = unpack("S1", substr($msg, 18, 2));
		$coords{'y'} = unpack("S1", substr($msg, 20, 2));
		%{$chars[$config{'char'}]{'pos'}} = %coords;
		%{$chars[$config{'char'}]{'pos_to'}} = %coords;
		message "Map Change: $map_name ($chars[$config{'char'}]{'pos'}{'x'}, $chars[$config{'char'}]{'pos'}{'y'})\n", "connection";
		sendMapLoaded(\$remote_socket) if (!$config{'XKore'});
		ai_clientSuspend(0, 10) if ($config{'XKore'});
		$timeout{'ai'}{'time'} = time if (!$config{'XKore'});

	} elsif ($switch eq "0092") {
		$conState = 4;
		initMapChangeVars() if ($config{'XKore'});
		undef $conState_tries;
		for (my $i = 0; $i < @ai_seq; $i++) {
			ai_setMapChanged($i);
		}
		$ai_v{'portalTrace_mapChanged'} = 1;

		($map_name) = substr($msg, 2, 16) =~ /([\s\S]*?)\000/;
		($ai_v{'temp'}{'map'}) = $map_name =~ /([\s\S]*)\./;
		if ($ai_v{'temp'}{'map'} ne $field{'name'}) {
			getField("$Settings::def_field/$ai_v{'temp'}{'map'}.fld", \%field);
		}

		$map_ip = makeIP(substr($msg, 22, 4));
		$map_port = unpack("S1", substr($msg, 26, 2));
		message(swrite(
			"---------Map Change Info----------", [],
			"MAP Name: @<<<<<<<<<<<<<<<<<<",
			[$map_name],
			"MAP IP: @<<<<<<<<<<<<<<<<<<",
			[$map_ip],
			"MAP Port: @<<<<<<<<<<<<<<<<<<",
			[$map_port],
			"-------------------------------", []),
			"connection");

		message("Closing connection to Map Server\n", "connection");
		Network::disconnect(\$remote_socket) if (!$config{'XKore'});

		# Reset item and skill times. The effect of items (like aspd potions)
		# and skills (like Twohand Quicken) disappears when we change map server.
		my $i = 0;
		while (exists $config{"useSelf_item_$i"}) {
			if (!$config{"useSelf_item_$i"}) {
				$i++;
				next;
			}

			$ai_v{"useSelf_item_$i"."_time"} = 0;
			$i++;
		}
		$i = 0;
		while (exists $config{"useSelf_skill_$i"}) {
			if (!$config{"useSelf_skill_$i"}) {
				$i++;
				next;
			}

			$ai_v{"useSelf_skill_$i"."_time"} = 0;
			$i++;
		}
		undef %{$chars[$config{char}]{statuses}} if ($chars[$config{char}]{statuses});
		$char->{spirits} = 0;

	} elsif ($switch eq "0095") {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		$ID = substr($msg, 2, 4);
		if (%{$players{$ID}}) {
			($players{$ID}{'name'}) = substr($msg, 6, 24) =~ /([\s\S]*?)\000/;
			$players{$ID}{'gotName'} = 1;
			my $binID = binFind(\@playersID, $ID);
			debug "Player Info: $players{$ID}{'name'} ($binID)\n", "parseMsg_presence", 2;
		}
		if (%{$monsters{$ID}}) {
			($monsters{$ID}{'name'}) = substr($msg, 6, 24) =~ /([\s\S]*?)\000/;
			if ($config{'debug'} >= 2) {
				$binID = binFind(\@monstersID, $ID);
				debug "Monster Info: $monsters{$ID}{'name'} ($binID)\n", "parseMsg", 2;
			}
			if ($monsters_lut{$monsters{$ID}{'nameID'}} eq "") {
				$monsters_lut{$monsters{$ID}{'nameID'}} = $monsters{$ID}{'name'};
				updateMonsterLUT("$Settings::tables_folder/monsters.txt", $monsters{$ID}{'nameID'}, $monsters{$ID}{'name'});
			}
		}
		if (%{$npcs{$ID}}) {
			($npcs{$ID}{'name'}) = substr($msg, 6, 24) =~ /([\s\S]*?)\000/; 
			$npcs{$ID}{'gotName'} = 1;
			if ($config{'debug'} >= 2) { 
				$binID = binFind(\@npcsID, $ID); 
				debug "NPC Info: $npcs{$ID}{'name'} ($binID)\n", "parseMsg", 2;
			} 
			if (!%{$npcs_lut{$npcs{$ID}{'nameID'}}}) { 
				$npcs_lut{$npcs{$ID}{'nameID'}}{'name'} = $npcs{$ID}{'name'};
				$npcs_lut{$npcs{$ID}{'nameID'}}{'map'} = $field{'name'};
				%{$npcs_lut{$npcs{$ID}{'nameID'}}{'pos'}} = %{$npcs{$ID}{'pos'}};
				updateNPCLUT("$Settings::tables_folder/npcs.txt", $npcs{$ID}{'nameID'}, $field{'name'}, $npcs{$ID}{'pos'}{'x'}, $npcs{$ID}{'pos'}{'y'}, $npcs{$ID}{'name'}); 
			}
		}
		if (%{$pets{$ID}}) {
			($pets{$ID}{'name_given'}) = substr($msg, 6, 24) =~ /([\s\S]*?)\000/;
			if ($config{'debug'} >= 2) {
				$binID = binFind(\@petsID, $ID);
				debug "Pet Info: $pets{$ID}{'name_given'} ($binID)\n", "parseMsg", 2;
			}
		}

	} elsif ($switch eq "0097") {
		# Private message
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		my $newmsg;
		decrypt(\$newmsg, substr($msg, 28, length($msg)-28));
		$msg = substr($msg, 0, 28) . $newmsg;
		my ($privMsgUser) = substr($msg, 4, 24) =~ /([\s\S]*?)\000/;
		my $privMsg = substr($msg, 28, $msg_size - 29);
		if ($privMsgUser ne "" && binFind(\@privMsgUsers, $privMsgUser) eq "") {
			push @privMsgUsers, $privMsgUser;
			Plugins::callHook('parseMsg/addPrivMsgUser', {
				user => $privMsgUser,
				msg => $privMsg,
				userList => \@privMsgUsers
			});
		}

		stripLanguageCode(\$privMsg);
		chatLog("pm", "(From: $privMsgUser) : $privMsg\n") if ($config{'logPrivateChat'});
		message "(From: $privMsgUser) : $privMsg\n", "pm";

		ChatQueue::add('pm', undef, $privMsgUser, $privMsg);
		Plugins::callHook('packet_privMsg', {
			privMsgUser => $privMsgUser,
			privMsg => $privMsg
			});

	} elsif ($switch eq "0098") {
		$type = unpack("C1",substr($msg, 2, 1));
		if ($type == 0) {
			message "(To $lastpm[0]{'user'}) : $lastpm[0]{'msg'}\n", "pm/sent";
			chatLog("pm", "(To: $lastpm[0]{'user'}) : $lastpm[0]{'msg'}\n") if ($config{'logPrivateChat'});
		} elsif ($type == 1) {
			warning "$lastpm[0]{'user'} is not online\n";
		} elsif ($type == 2) {
			warning "Player ignored your message\n";
		} else {
			warning "Player doesnt want to recieved messages\n";
		}
		shift @lastpm;

	} elsif ($switch eq "009A") {
		my $chat = substr($msg, 4, $msg_size - 4);
		$chat =~ s/\000$//;

		stripLanguageCode(\$chat);
		chatLog("s", "$chat\n") if ($config{'logSystemChat'});
		message "$chat\n", "schat";
		ChatQueue::add('gm', undef, undef, $chat);

	} elsif ($switch eq "009C") {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		my $ID = substr($msg, 2, 4);
		my $body = unpack("C1",substr($msg, 8, 1));
		my $head = unpack("C1",substr($msg, 6, 1));
		if ($ID eq $accountID) {
			$chars[$config{'char'}]{'look'}{'head'} = $head;
			$chars[$config{'char'}]{'look'}{'body'} = $body;
			debug "You look at $body, $head\n", "parseMsg", 2;

		} elsif (%{$players{$ID}}) {
			$players{$ID}{'look'}{'head'} = $head;
			$players{$ID}{'look'}{'body'} = $body;
			debug "Player $players{$ID}{'name'} ($players{$ID}{'binID'}) looks at $players{$ID}{'look'}{'body'}, $players{$ID}{'look'}{'head'}\n", "parseMsg";

		} elsif (%{$monsters{$ID}}) {
			$monsters{$ID}{'look'}{'head'} = $head;
			$monsters{$ID}{'look'}{'body'} = $body;
			debug "Monster $monsters{$ID}{'name'} ($monsters{$ID}{'binID'}) looks at $monsters{$ID}{'look'}{'body'}, $monsters{$ID}{'look'}{'head'}\n", "parseMsg";
		}

	} elsif ($switch eq "009D") {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		$ID = substr($msg, 2, 4);
		$type = unpack("S1",substr($msg, 6, 2));
		$x = unpack("S1", substr($msg, 9, 2));
		$y = unpack("S1", substr($msg, 11, 2));
		$amount = unpack("S1", substr($msg, 13, 2));
		if (!%{$items{$ID}}) {
			binAdd(\@itemsID, $ID);
			$items{$ID}{'appear_time'} = time;
			$items{$ID}{'amount'} = $amount;
			$items{$ID}{'nameID'} = $type;
			$items{$ID}{'binID'} = binFind(\@itemsID, $ID);
			$items{$ID}{'name'} = itemName($items{$ID});
		}
		$items{$ID}{'pos'}{'x'} = $x;
		$items{$ID}{'pos'}{'y'} = $y;
		message "Item Exists: $items{$ID}{'name'} ($items{$ID}{'binID'}) x $items{$ID}{'amount'}\n", "drop", 1;

	} elsif ($switch eq "009E") {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		$ID = substr($msg, 2, 4);
		$type = unpack("S1",substr($msg, 6, 2));
		$x = unpack("S1", substr($msg, 9, 2));
		$y = unpack("S1", substr($msg, 11, 2));
		$amount = unpack("S1", substr($msg, 15, 2));
		my $item = $items{$ID} ||= {};
		if (!%{$item}) {
			binAdd(\@itemsID, $ID);
			$item->{appear_time} = time;
			$item->{amount} = $amount;
			$item->{nameID} = $type;
			$item->{binID} = binFind(\@itemsID, $ID);
			$item->{name} = itemName($item);
		}
		$item->{pos}{x} = $x;
		$item->{pos}{y} = $y;

		# Take item as fast as possible
		if ($AI && $itemsPickup{lc($item->{name})} == 2 && distance($item->{pos}, $char->{pos_to}) <= 5) {
			sendTake(\$remote_socket, $ID);
		}

		message "Item Appeared: $item->{name} ($item->{binID}) x $item->{amount} ($x, $y)\n", "drop", 1;

	} elsif ($switch eq "00A0") {
		$conState = 5 if ($conState != 4 && $config{'XKore'});

		my $index = unpack("S1", substr($msg, 2, 2));
		my $amount = unpack("S1", substr($msg, 4, 2));
		my $fail = unpack("C1", substr($msg, 22, 1));

		if (!$fail) {
			my $item;
			my $invIndex = findIndex(\@{$chars[$config{'char'}]{'inventory'}}, "index", $index);
			if (!defined $invIndex) {
				# Add new item
				$invIndex = findIndex(\@{$chars[$config{'char'}]{'inventory'}}, "nameID", "");
				$item = $chars[$config{'char'}]{'inventory'}[$invIndex] = {};
				$item->{index} = $index;
				$item->{nameID} = unpack("S1", substr($msg, 6, 2));
				$item->{type} = unpack("C1", substr($msg, 21, 1));
				$item->{type_equip} = unpack("S1", substr($msg, 19, 2));
				$item->{amount} = $amount;
				$item->{identified} = unpack("C1", substr($msg, 8, 1));
				$item->{upgrade} = unpack("C1", substr($msg, 10, 1));
				$item->{cards} = substr($msg, 11, 8);
				$item->{name} = itemName($item);
			} else {
				# Add stackable item
				$item = $chars[$config{'char'}]{'inventory'}[$invIndex];
				$item->{amount} += $amount;
			}

			my $disp = "Item added to inventory: ";
			$disp .= $item->{name};
			$disp .= " ($invIndex) x $amount - $itemTypes_lut{$item->{type}}";
			message "$disp\n", "drop";

			($map_string) = $map_name =~ /([\s\S]*)\.gat/;
			$disp .= " ($map_string)\n";
			itemLog($disp);

			# TODO: move this stuff to AI()
			if ($AI) {
				# Auto-drop item
				$item = $char->{inventory}[$invIndex];
				if ($itemsPickup{lc($items_lut{$item->{nameID}})} == -1 && !AI::inQueue('storageAuto', 'buyAuto')) {
					sendDrop(\$remote_socket, $item->{index}, $amount);
					message "Auto-dropping item: $item->{name} ($invIndex) x $amount\n", "drop";
				}
			}

		} elsif ($fail == 6) {
			message "Can't loot item...wait...\n", "drop";
		}

	} elsif ($switch eq "00A1") {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		$ID = substr($msg, 2, 4);
		if (%{$items{$ID}}) {
			debug "Item Disappeared: $items{$ID}{'name'} ($items{$ID}{'binID'})\n", "parseMsg_presence";
			%{$items_old{$ID}} = %{$items{$ID}};
			$items_old{$ID}{'disappeared'} = 1;
			$items_old{$ID}{'gone_time'} = time;
			delete $items{$ID};
			binRemove(\@itemsID, $ID);
		}

	} elsif ($switch eq "00A3" || $switch eq "01EE") {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		decrypt(\$newmsg, substr($msg, 4, length($msg)-4));
		$msg = substr($msg, 0, 4).$newmsg;
		my $psize = ($switch eq "00A3") ? 10 : 18;

		for($i = 4; $i < $msg_size; $i += $psize) {
			my $index = unpack("S1", substr($msg, $i, 2));
			my $ID = unpack("S1", substr($msg, $i + 2, 2));
			my $invIndex = findIndex(\@{$chars[$config{'char'}]{'inventory'}}, "index", $index);
			if ($invIndex eq "") {
				$invIndex = findIndex(\@{$chars[$config{'char'}]{'inventory'}}, "nameID", "");
			}

			$char->{inventory}[$invIndex]{index} = $index;
			$char->{inventory}[$invIndex]{nameID} = $ID;
			$char->{inventory}[$invIndex]{amount} = unpack("S1", substr($msg, $i + 6, 2));
			$char->{inventory}[$invIndex]{type} = unpack("C1", substr($msg, $i + 4, 1));
			$char->{inventory}[$invIndex]{identified} = 1;
			$char->{inventory}[$invIndex]{equipped} = 32768 if (defined $char->{arrow} && $index == $char->{arrow});

			$display = ($items_lut{$char->{inventory}[$invIndex]{nameID}} ne "")
				? $items_lut{$char->{inventory}[$invIndex]{nameID}}
				: "Unknown ".$char->{inventory}[$invIndex]{nameID};
			$char->{inventory}[$invIndex]{name} = $display;
			debug "Inventory: $char->{inventory}[$invIndex]{name} ($invIndex) x $char->{inventory}[$invIndex]{amount} - " .
				"$itemTypes_lut{$char->{inventory}[$invIndex]{type}}\n", "parseMsg";
			Plugins::callHook('packet_inventory', {index => $invIndex});
		}

		$ai_v{'inventory_time'} = time + 1;
		$ai_v{'cart_time'} = time + 1;

	} elsif ($switch eq "00A4") {
		$conState = 5 if $conState != 4 && $config{XKore};
		decrypt(\$newmsg, substr($msg, 4, length($msg)-4));
		$msg = substr($msg, 0, 4) . $newmsg;
		my $invIndex;
		for (my $i = 4; $i < $msg_size; $i += 20) {
			$index = unpack("S1", substr($msg, $i, 2));
			$ID = unpack("S1", substr($msg, $i + 2, 2));
			$invIndex = findIndex(\@{$chars[$config{char}]{inventory}}, "index", $index);
			$invIndex = findIndex(\@{$chars[$config{char}]{inventory}}, "nameID", "") unless defined $invIndex;

			my $item = $chars[$config{char}]{inventory}[$invIndex] = {};
			$item->{index} = $index;
			$item->{nameID} = $ID;
			$item->{amount} = 1;
			$item->{type} = unpack("C1", substr($msg, $i + 4, 1));
			$item->{identified} = unpack("C1", substr($msg, $i + 5, 1));
			$item->{type_equip} = unpack("S1", substr($msg, $i + 6, 2));
			$item->{equipped} = unpack("S1", substr($msg, $i + 8, 2));
			$item->{upgrade} = unpack("C1", substr($msg, $i + 11, 1)); 
			$item->{cards} = substr($msg, $i + 12, 8);
			$item->{name} = itemName($item);

			debug "Inventory: $item->{name} ($invIndex) x $item->{amount} - $itemTypes_lut{$item->{type}} - $equipTypes_lut{$item->{type_equip}}\n", "parseMsg";
			Plugins::callHook('packet_inventory', {index => $invIndex});
		}

		$ai_v{'inventory_time'} = time + 1;
		$ai_v{'cart_time'} = time + 1;

	} elsif ($switch eq "00A5" || $switch eq "01F0") {
		# Retrieve list of stackable storage items
		my $newmsg;
		decrypt(\$newmsg, substr($msg, 4, length($msg)-4));
		$msg = substr($msg, 0, 4).$newmsg;
		undef %storage;
		undef @storageID;

		my $psize = ($switch eq "00A5") ? 10 : 18;
		for (my $i = 4; $i < $msg_size; $i += $psize) {
			my $index = unpack("C1", substr($msg, $i, 1));
			my $ID = unpack("S1", substr($msg, $i + 2, 2));
			binAdd(\@storageID, $index);
			my $item = $storage{$index} = {};
			$item->{index} = $index;
			$item->{nameID} = $ID;
			$item->{amount} = unpack("L1", substr($msg, $i + 6, 4)) & ~0x80000000;
			$item->{name} = itemNameSimple($ID);
			$item->{binID} = binFind(\@storageID, $index);
			$item->{identified} = 1;
			debug "Storage: $item->{name} ($item->{binID}) x $item->{amount}\n", "parseMsg";
		}

	} elsif ($switch eq "00A6") {
		# Retrieve list of non-stackable (weapons & armor) storage items.
		# This packet is sent immediately after 00A5/01F0.
		my $newmsg;
		decrypt(\$newmsg, substr($msg, 4, length($msg)-4));
		$msg = substr($msg, 0, 4).$newmsg;

		for (my $i = 4; $i < $msg_size; $i += 20) {
			my $index = unpack("C1", substr($msg, $i, 1));
			my $ID = unpack("S1", substr($msg, $i + 2, 2));

			binAdd(\@storageID, $index);
			my $item = $storage{$index} = {};
			$item->{index} = $index;
			$item->{nameID} = $ID;
			$item->{amount} = 1;
			$item->{type} = unpack("C1", substr($msg, $i + 4, 1));
			$item->{identified} = unpack("C1", substr($msg, $i + 5, 1));
			$item->{upgrade} = unpack("C1", substr($msg, $i + 11, 1));
			$item->{cards} = substr($msg, $i + 12, 8);
			$item->{name} = itemName($item);
			$item->{binID} = binFind(\@storageID, $index);
			debug "Storage: $item->{name} ($item->{binID})\n", "parseMsg";
		}

	} elsif ($switch eq "00A8") {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		my $index = unpack("S1",substr($msg, 2, 2));
		my $amount = unpack("C1",substr($msg, 6, 1));
		my $invIndex = findIndex($char->{inventory}, "index", $index);
		if (defined $invIndex) {
			$char->{inventory}[$invIndex]{amount} -= $amount;
			message "You used Item: $char->{inventory}[$invIndex]{name} ($invIndex) x $amount\n", "useItem";
			if ($char->{inventory}[$invIndex]{amount} <= 0) {
				delete $char->{inventory}[$invIndex];
			}
		}

	} elsif ($switch eq "00AA") {
		my $index = unpack("S1",substr($msg, 2, 2));
		my $type = unpack("S1",substr($msg, 4, 2));
		my $fail = unpack("C1",substr($msg, 6, 1));
		my $invIndex = findIndex(\@{$chars[$config{'char'}]{'inventory'}}, "index", $index);
		if ($fail == 0) {
			message "You can't put on $chars[$config{'char'}]{'inventory'}[$invIndex]{'name'} ($invIndex)\n";
		} else {
			$chars[$config{'char'}]{'inventory'}[$invIndex]{'equipped'} = $chars[$config{'char'}]{'inventory'}[$invIndex]{'type_equip'};
			message "You equip $chars[$config{'char'}]{'inventory'}[$invIndex]{'name'} ($invIndex) - $equipTypes_lut{$chars[$config{'char'}]{'inventory'}[$invIndex]{'type_equip'}}\n", 'inventory';
		}

	} elsif ($switch eq "00AC") {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		$index = unpack("S1",substr($msg, 2, 2));
		$type = unpack("S1",substr($msg, 4, 2));
		undef $invIndex;
		$invIndex = findIndex(\@{$chars[$config{'char'}]{'inventory'}}, "index", $index);
		$chars[$config{'char'}]{'inventory'}[$invIndex]{'equipped'} = "";
		message "You unequip $chars[$config{'char'}]{'inventory'}[$invIndex]{'name'} ($invIndex) - $equipTypes_lut{$chars[$config{'char'}]{'inventory'}[$invIndex]{'type_equip'}}\n", 'inventory';

	} elsif ($switch eq "00AF") {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		my ($index, $amount) = unpack("x2 S1 S1", $msg);
		my $invIndex = findIndex(\@{$char->{inventory}}, "index", $index);
		inventoryItemRemoved($invIndex, $amount);

	} elsif ($switch eq "00B0") {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		my $type = unpack("S1",substr($msg, 2, 2));
		my $val = unpack("L1",substr($msg, 4, 4));
		if ($type == 0) {
			$char->{'walk_speed'} = $val / 1000;
			debug "Walk speed: $val\n", "parseMsg", 2;
		} elsif ($type == 3) {
			debug "Something2: $val\n", "parseMsg", 2;
		} elsif ($type == 4) {
			if ($val == 0) {
				delete $char->{'muted'};
				delete $char->{'mute_period'};
				message "Mute period expired.\n";
			} else {
				$val = (0xFFFFFFFF - $val) + 1;
				$char->{'mute_period'} = $val * 60;
				$char->{'muted'} = time;
				if ($config{'dcOnMute'}) {
					message "You've been muted for $val minutes, auto disconnect!\n";
					chatLog("k", "*** You have been muted for $val minutes, auto disconnect! ***\n");
					quit();
				} else {
					#message "max = " . 0xFFFFFFFF . "\n";
					#message "1   = " . $a . "\n";
					#message "2   = " . abs($a) . "\n";
					message "You've been muted for $val minutes\n";
				}
			}
		} elsif ($type == 5) {
			$chars[$config{'char'}]{'hp'} = $val;
			debug "Hp: $val\n", "parseMsg", 2;
		} elsif ($type == 6) {
			$chars[$config{'char'}]{'hp_max'} = $val;
			debug "Max Hp: $val\n", "parseMsg", 2;
		} elsif ($type == 7) {
			$chars[$config{'char'}]{'sp'} = $val;
			debug "Sp: $val\n", "parseMsg", 2;
		} elsif ($type == 8) {
			$chars[$config{'char'}]{'sp_max'} = $val;
			debug "Max Sp: $val\n", "parseMsg", 2;
		} elsif ($type == 9) {
			$chars[$config{'char'}]{'points_free'} = $val;
			debug "Status Points: $val\n", "parseMsg", 2;
		} elsif ($type == 11) {
			$chars[$config{'char'}]{'lv'} = $val;
			debug "Level: $val\n", "parseMsg", 2;
		} elsif ($type == 12) {
			$chars[$config{'char'}]{'points_skill'} = $val;
			debug "Skill Points: $val\n", "parseMsg", 2;
		} elsif ($type == 24) {
			$chars[$config{'char'}]{'weight'} = int($val / 10);
			debug "Weight: $chars[$config{'char'}]{'weight'}\n", "parseMsg", 2;
		} elsif ($type == 25) {
			$chars[$config{'char'}]{'weight_max'} = int($val / 10);
			debug "Max Weight: $chars[$config{'char'}]{'weight_max'}\n", "parseMsg", 2;
		} elsif ($type == 41) {
			$chars[$config{'char'}]{'attack'} = $val;
			debug "Attack: $val\n", "parseMsg", 2;
		} elsif ($type == 42) {
			$chars[$config{'char'}]{'attack_bonus'} = $val;
			debug "Attack Bonus: $val\n", "parseMsg", 2;
		} elsif ($type == 43) {
			$chars[$config{'char'}]{'attack_magic_min'} = $val;
			debug "Magic Attack Min: $val\n", "parseMsg", 2;
		} elsif ($type == 44) {
			$chars[$config{'char'}]{'attack_magic_max'} = $val;
			debug "Magic Attack Max: $val\n", "parseMsg", 2;
		} elsif ($type == 45) {
			$chars[$config{'char'}]{'def'} = $val;
			debug "Defense: $val\n", "parseMsg", 2;
		} elsif ($type == 46) {
			$chars[$config{'char'}]{'def_bonus'} = $val;
			debug "Defense Bonus: $val\n", "parseMsg", 2;
		} elsif ($type == 47) {
			$chars[$config{'char'}]{'def_magic'} = $val;
			debug "Magic Defense: $val\n", "parseMsg", 2;
		} elsif ($type == 48) {
			$chars[$config{'char'}]{'def_magic_bonus'} = $val;
			debug "Magic Defense Bonus: $val\n", "parseMsg", 2;
		} elsif ($type == 49) {
			$chars[$config{'char'}]{'hit'} = $val;
			debug "Hit: $val\n", "parseMsg", 2;
		} elsif ($type == 50) {
			$chars[$config{'char'}]{'flee'} = $val;
			debug "Flee: $val\n", "parseMsg", 2;
		} elsif ($type == 51) {
			$chars[$config{'char'}]{'flee_bonus'} = $val;
			debug "Flee Bonus: $val\n", "parseMsg", 2;
		} elsif ($type == 52) {
			$chars[$config{'char'}]{'critical'} = $val;
			debug "Critical: $val\n", "parseMsg", 2;
		} elsif ($type == 53) { 
			$chars[$config{'char'}]{'attack_speed'} = 200 - $val/10; 
			debug "Attack Speed: $chars[$config{'char'}]{'attack_speed'}\n", "parseMsg", 2;
		} elsif ($type == 55) {
			$chars[$config{'char'}]{'lv_job'} = $val;
			debug "Job Level: $val\n", "parseMsg", 2;
		} elsif ($type == 124) {
			debug "Something3: $val\n", "parseMsg", 2;
		} else {
			debug "Something: $val\n", "parseMsg", 2;
		}

	} elsif ($switch eq "00B1") {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		my $type = unpack("S1",substr($msg, 2, 2));
		my $val = unpack("L1",substr($msg, 4, 4));

		if ($type == 1) {
			$chars[$config{'char'}]{'exp_last'} = $chars[$config{'char'}]{'exp'};
			$chars[$config{'char'}]{'exp'} = $val;
			debug "Exp: $val\n", "parseMsg";
			if (!$bExpSwitch) {
				$bExpSwitch = 1;
			} else {
				if ($chars[$config{'char'}]{'exp_last'} > $chars[$config{'char'}]{'exp'}) {
					$monsterBaseExp = 0;
				} else { 
					$monsterBaseExp = $chars[$config{'char'}]{'exp'} - $chars[$config{'char'}]{'exp_last'}; 
				} 
			$totalBaseExp += $monsterBaseExp; 
				if ($bExpSwitch == 1) { 
					$totalBaseExp += $monsterBaseExp; 
					$bExpSwitch = 2; 
				} 
			}
		} elsif ($type == 2) {
			$chars[$config{'char'}]{'exp_job_last'} = $chars[$config{'char'}]{'exp_job'};
			$chars[$config{'char'}]{'exp_job'} = $val;
			debug "Job Exp: $val\n", "parseMsg";
			if ($jExpSwitch == 0) { 
				$jExpSwitch = 1; 
			} else { 
				if ($chars[$config{'char'}]{'exp_job_last'} > $chars[$config{'char'}]{'exp_job'}) { 
					$monsterJobExp = 0; 
				} else { 
					$monsterJobExp = $chars[$config{'char'}]{'exp_job'} - $chars[$config{'char'}]{'exp_job_last'}; 
				} 
				$totalJobExp += $monsterJobExp; 
				if ($jExpSwitch == 1) { 
					$totalJobExp += $monsterJobExp; 
					$jExpSwitch = 2; 
				} 
			}
			my $basePercent = $char->{exp_max} ?
				($monsterBaseExp / $char->{exp_max} * 100) :
				0;
			my $jobPercent = $char->{exp_job_max} ?
				($monsterJobExp / $char->{exp_job_max} * 100) :
				0;
			message sprintf("Exp gained: %d/%d (%.2f%%/%.2f%%)\n", $monsterBaseExp, $monsterJobExp, $basePercent, $jobPercent), "exp";

		} elsif ($type == 20) {
			my $change = $val - $char->{zenny};
			if ($change > 0) {
				message "You gained $change zeny.\n";
			} elsif ($change < 0) {
				message "You lost ".-$change." zeny.\n";
			}
			$char->{zenny} = $val;
			debug "Zenny: $val\n", "parseMsg";
		} elsif ($type == 22) {
			$chars[$config{'char'}]{'exp_max_last'} = $chars[$config{'char'}]{'exp_max'};
			$chars[$config{'char'}]{'exp_max'} = $val;
			debug "Required Exp: $val\n", "parseMsg";
		} elsif ($type == 23) {
			$chars[$config{'char'}]{'exp_job_max_last'} = $chars[$config{'char'}]{'exp_job_max'};
			$chars[$config{'char'}]{'exp_job_max'} = $val;
			debug "Required Job Exp: $val\n", "parseMsg";
			message("BaseExp:$monsterBaseExp | JobExp:$monsterJobExp\n","info", 2) if ($monsterBaseExp);
		}

	} elsif ($switch eq "00B3") {
		$conState = 2.5;
		undef $accountID;

	} elsif ($switch eq "00B4") {
		decrypt(\$newmsg, substr($msg, 8, length($msg)-8));
		$msg = substr($msg, 0, 8).$newmsg;
		$ID = substr($msg, 4, 4);
		($talk) = substr($msg, 8, $msg_size - 8) =~ /([\s\S]*?)\000/;
		$talk{'ID'} = $ID;
		$talk{'nameID'} = unpack("L1", $ID);
		$talk{'msg'} = $talk;
		# Remove RO color codes
		$talk{'msg'} =~ s/\^[a-fA-F0-9]{6}//g;
		message "$npcs{$ID}{'name'} : $talk{'msg'}\n", "npc";

	} elsif ($switch eq "00B5") {
		# 00b5: long ID
		# "Next" button appeared on the NPC message dialog
		my $ID = substr($msg, 2, 4);
		if ($config{autoTalkCont}) {
			message "$npcs{$ID}{name} : Auto-continuing talking\n", "npc";
			sendTalkContinue(\$remote_socket, $ID);
		} else {
			message "$npcs{$ID}{name} : Type 'talk cont' to continue talking\n", "npc";
		}
		$ai_v{'npc_talk'}{'talk'} = 'next';
		$ai_v{'npc_talk'}{'time'} = time;

	} elsif ($switch eq "00B6") {
		# 00b6: long ID
		# "Close" icon appreared on the NPC message dialog
		my $ID = substr($msg, 2, 4);
		undef %talk;
		message "$npcs{$ID}{'name'} : Done talking\n", "npc";
		$ai_v{'npc_talk'}{'talk'} = 'close';
		$ai_v{'npc_talk'}{'time'} = time;
		sendTalkCancel(\$remote_socket, $ID);

	} elsif ($switch eq "00B7") {
		# 00b7: word len, long ID, string str
		# A list of selections appeared on the NPC message dialog.
		# Each item is divided with ':'
		decrypt(\$newmsg, substr($msg, 8, length($msg)-8));
		$msg = substr($msg, 0, 8).$newmsg;
		$ID = substr($msg, 4, 4);
		$talk{'ID'} = $ID;
		($talk) = substr($msg, 8, $msg_size - 8) =~ /([\s\S]*?)\000/;
		$talk = substr($msg, 8) if (!defined $talk);
		@preTalkResponses = split /:/, $talk;
		undef @{$talk{'responses'}};
		foreach (@preTalkResponses) {
			# Remove RO color codes
			s/\^[a-fA-F0-9]{6}//g;

			push @{$talk{'responses'}}, $_ if $_ ne "";
		}
		$talk{'responses'}[@{$talk{'responses'}}] = "Cancel Chat";

		$ai_v{'npc_talk'}{'talk'} = 'select';
		$ai_v{'npc_talk'}{'time'} = time;

		my $list = "----------Responses-----------\n";
		$list .=   "#  Response\n";
		for (my $i = 0; $i < @{$talk{'responses'}}; $i++) {
			$list .= swrite(
				"@< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<",
				[$i, $talk{'responses'}[$i]]);
		}
		$list .= "-------------------------------\n";
		message($list, "list");
		message("$npcs{$ID}{'name'} : Type 'talk resp #' to choose a response.\n", "npc");

	} elsif ($switch eq "00BC") {
		$type = unpack("S1",substr($msg, 2, 2));
		$val = unpack("C1",substr($msg, 5, 1));
		if ($val == 207) {
			error "Not enough stat points to add\n";
		} else {
			if ($type == 13) {
				$chars[$config{'char'}]{'str'} = $val;
				debug "Strength: $val\n", "parseMsg";
				# Reset $statChanged back to 0 to tell kore that a stat can be raised again
				$statChanged = 0 if ($statChanged eq "str");

			} elsif ($type == 14) {
				$chars[$config{'char'}]{'agi'} = $val;
				debug "Agility: $val\n", "parseMsg";
				$statChanged = 0 if ($statChanged eq "agi");

			} elsif ($type == 15) {
				$chars[$config{'char'}]{'vit'} = $val;
				debug "Vitality: $val\n", "parseMsg";
				$statChanged = 0 if ($statChanged eq "vit");

			} elsif ($type == 16) {
				$chars[$config{'char'}]{'int'} = $val;
				debug "Intelligence: $val\n", "parseMsg";
				$statChanged = 0 if ($statChanged eq "int");

			} elsif ($type == 17) {
				$chars[$config{'char'}]{'dex'} = $val;
				debug "Dexterity: $val\n", "parseMsg";
				$statChanged = 0 if ($statChanged eq "dex");

			} elsif ($type == 18) {
				$chars[$config{'char'}]{'luk'} = $val;
				debug "Luck: $val\n", "parseMsg";
				$statChanged = 0 if ($statChanged eq "luk");

			} else {
				debug "Something: $val\n", "parseMsg";
			}
		}
		Plugins::callHook('packet_charStats', {
			type	=> $type,
			val	=> $val,
		});


	} elsif ($switch eq "00BD") {
		$chars[$config{'char'}]{'points_free'} = unpack("S1", substr($msg, 2, 2));
		$chars[$config{'char'}]{'str'} = unpack("C1", substr($msg, 4, 1));
		$chars[$config{'char'}]{'points_str'} = unpack("C1", substr($msg, 5, 1));
		$chars[$config{'char'}]{'agi'} = unpack("C1", substr($msg, 6, 1));
		$chars[$config{'char'}]{'points_agi'} = unpack("C1", substr($msg, 7, 1));
		$chars[$config{'char'}]{'vit'} = unpack("C1", substr($msg, 8, 1));
		$chars[$config{'char'}]{'points_vit'} = unpack("C1", substr($msg, 9, 1));
		$chars[$config{'char'}]{'int'} = unpack("C1", substr($msg, 10, 1));
		$chars[$config{'char'}]{'points_int'} = unpack("C1", substr($msg, 11, 1));
		$chars[$config{'char'}]{'dex'} = unpack("C1", substr($msg, 12, 1));
		$chars[$config{'char'}]{'points_dex'} = unpack("C1", substr($msg, 13, 1));
		$chars[$config{'char'}]{'luk'} = unpack("C1", substr($msg, 14, 1));
		$chars[$config{'char'}]{'points_luk'} = unpack("C1", substr($msg, 15, 1));
		$chars[$config{'char'}]{'attack'} = unpack("S1", substr($msg, 16, 2));
		$chars[$config{'char'}]{'attack_bonus'} = unpack("S1", substr($msg, 18, 2));
		$chars[$config{'char'}]{'attack_magic_min'} = unpack("S1", substr($msg, 20, 2));
		$chars[$config{'char'}]{'attack_magic_max'} = unpack("S1", substr($msg, 22, 2));
		$chars[$config{'char'}]{'def'} = unpack("S1", substr($msg, 24, 2));
		$chars[$config{'char'}]{'def_bonus'} = unpack("S1", substr($msg, 26, 2));
		$chars[$config{'char'}]{'def_magic'} = unpack("S1", substr($msg, 28, 2));
		$chars[$config{'char'}]{'def_magic_bonus'} = unpack("S1", substr($msg, 30, 2));
		$chars[$config{'char'}]{'hit'} = unpack("S1", substr($msg, 32, 2));
		$chars[$config{'char'}]{'flee'} = unpack("S1", substr($msg, 34, 2));
		$chars[$config{'char'}]{'flee_bonus'} = unpack("S1", substr($msg, 36, 2));
		$chars[$config{'char'}]{'critical'} = unpack("S1", substr($msg, 38, 2));
		debug	"Strength: $chars[$config{'char'}]{'str'} #$chars[$config{'char'}]{'points_str'}\n"
			."Agility: $chars[$config{'char'}]{'agi'} #$chars[$config{'char'}]{'points_agi'}\n"
			."Vitality: $chars[$config{'char'}]{'vit'} #$chars[$config{'char'}]{'points_vit'}\n"
			."Intelligence: $chars[$config{'char'}]{'int'} #$chars[$config{'char'}]{'points_int'}\n"
			."Dexterity: $chars[$config{'char'}]{'dex'} #$chars[$config{'char'}]{'points_dex'}\n"
			."Luck: $chars[$config{'char'}]{'luk'} #$chars[$config{'char'}]{'points_luk'}\n"
			."Attack: $chars[$config{'char'}]{'attack'}\n"
			."Attack Bonus: $chars[$config{'char'}]{'attack_bonus'}\n"
			."Magic Attack Min: $chars[$config{'char'}]{'attack_magic_min'}\n"
			."Magic Attack Max: $chars[$config{'char'}]{'attack_magic_max'}\n"
			."Defense: $chars[$config{'char'}]{'def'}\n"
			."Defense Bonus: $chars[$config{'char'}]{'def_bonus'}\n"
			."Magic Defense: $chars[$config{'char'}]{'def_magic'}\n"
			."Magic Defense Bonus: $chars[$config{'char'}]{'def_magic_bonus'}\n"
			."Hit: $chars[$config{'char'}]{'hit'}\n"
			."Flee: $chars[$config{'char'}]{'flee'}\n"
			."Flee Bonus: $chars[$config{'char'}]{'flee_bonus'}\n"
			."Critical: $chars[$config{'char'}]{'critical'}\n"
			."Status Points: $chars[$config{'char'}]{'points_free'}\n", "parseMsg";

	} elsif ($switch eq "00BE") {
		$type = unpack("S1",substr($msg, 2, 2));
		$val = unpack("C1",substr($msg, 4, 1));
		if ($type == 32) {
			$chars[$config{'char'}]{'points_str'} = $val;
			debug "Points needed for Strength: $val\n", "parseMsg";
		} elsif ($type == 33) {
			$chars[$config{'char'}]{'points_agi'} = $val;
			debug "Points needed for Agility: $val\n", "parseMsg";
		} elsif ($type == 34) {
			$chars[$config{'char'}]{'points_vit'} = $val;
			debug "Points needed for Vitality: $val\n", "parseMsg";
		} elsif ($type == 35) {
			$chars[$config{'char'}]{'points_int'} = $val;
			debug "Points needed for Intelligence: $val\n", "parseMsg";
		} elsif ($type == 36) {
			$chars[$config{'char'}]{'points_dex'} = $val;
			debug "Points needed for Dexterity: $val\n", "parseMsg";
		} elsif ($type == 37) {
			$chars[$config{'char'}]{'points_luk'} = $val;
			debug "Points needed for Luck: $val\n", "parseMsg";
		}
		
	} elsif ($switch eq "00C0") {
		$ID = substr($msg, 2, 4);
		$type = unpack("C*", substr($msg, 6, 1));
		my $emotion = $emotions_lut{$type} || "<emotion #$type>";
		if ($ID eq $accountID) {
			message "$chars[$config{'char'}]{'name'} : $emotion\n", "emotion";
			chatLog("e", "$chars[$config{'char'}]{'name'} : $emotion\n") if (existsInList($config{'logEmoticons'}, $type) || $config{'logEmoticons'} eq "all");
		} elsif (%{$players{$ID}}) {
			message "$players{$ID}{'name'} : $emotion\n", "emotion";
			chatLog("e", "$players{$ID}{'name'} : $emotion\n") if (existsInList($config{'logEmoticons'}, $type) || $config{'logEmoticons'} eq "all");

			my $index = binFind(\@ai_seq, "follow");
			if ($index ne "") {
				my $masterID = $ai_seq_args[$index]{'ID'};
				if ($config{'followEmotion'} && $masterID eq $ID &&
			 	       distance(\%{$chars[$config{'char'}]{'pos_to'}}, \%{$players{$masterID}{'pos_to'}}) <= $config{'followEmotion_distance'})
				{
					my %args = ();
					$args{'timeout'} = time + rand (1) + 0.75;

					if ($type == 30) {
						$args{'emotion'} = 31;
					} elsif ($type == 31) {
						$args{'emotion'} = 30;
					} else {
						$args{'emotion'} = $type;
					}

					unshift @ai_seq, "sendEmotion";
					unshift @ai_seq_args, \%args;
				}
			}
		}

	} elsif ($switch eq "00C2") {
		my $users = unpack("L*", substr($msg, 2, 4));
		message "There are currently $users users online\n", "info";

	} elsif ($switch eq "00C3") {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		my $ID = substr($msg, 2, 4);
		my $part = unpack("C1",substr($msg, 6, 1));
		my $number = unpack("C1",substr($msg, 7, 1));

		if ($part == 0) {
			# Job change
			my $msg;
			if ($ID eq $accountID) {
				$char->{jobID} = $number;
				message "You changed job to: $jobs_lut{$number}\n", "parseMsg/job";
			} elsif ($players{$ID}) {
				$players{$ID}{jobID} = $number;
				message "Player $players{$ID}{name} ($players{$ID}{binID}) changed job to: $jobs_lut{$number}\n", "parseMsg/job";
			} else {
				debug "Unknown #" . unpack("L", $ID) . " changed job to: $jobs_lut{$number}\n", "parseMsg/job";
			}

		} elsif ($part == 6) {
			# Hair color change
			if ($ID eq $accountID) {
				$char->{hair_color} = $number;
				message "Your hair color changed to: $haircolors{$number} ($number)\n", "parseMsg/hairColor";
			} elsif ($players{$ID}) {
				$players{$ID}{hair_color} = $number;
				message "Player $players{$ID}{name} ($players{$ID}{binID}) changed hair color to: $haircolors{$number} ($number)\n", "parseMsg/hairColor";
			} else {
				debug "Unknown #" . unpack("L", $ID) . " changed hair color to: $haircolors{$number} ($number)\n", "parseMsg/hairColor";
			}
		}

		if (0) {
		my %parts = (
			0 => 'Body',
			2 => 'Right Hand',
			3 => 'Low Head',
			4 => 'Top Head',
			5 => 'Middle Head',
			8 => 'Left Hand'
		);
		if ($part == 3) {
			$part = 'low';
		} elsif ($part == 4) {
			$part = 'top';
		} elsif ($part == 5) {
			$part = 'mid';
		}

		my $name = getActorName($ID);
		if ($part == 3 || $part == 4 || $part == 5) {
			my $actor = getActorHash($ID);
			$actor->{headgear}{$part} = $items_lut{$number} if ($actor);
			my $itemName = $items_lut{$itemID};
			$itemName = 'nothing' if (!$itemName);
			debug "$name changes $parts{$part} ($part) equipment to $itemName\n", "parseMsg";
		} else {
			debug "$name changes $parts{$part} ($part) equipment to item #$number\n", "parseMsg";
		}
		}

	} elsif ($switch eq "00C4") {
		my $ID = substr($msg, 2, 4);
		undef %talk;
		$talk{'buyOrSell'} = 1;
		$talk{'ID'} = $ID;
		$ai_v{'npc_talk'}{'talk'} = 'buy';
		$ai_v{'npc_talk'}{'time'} = time;
		message "$npcs{$ID}{'name'} : Type 'store' to start buying, or type 'sell' to start selling\n", "npc";

	} elsif ($switch eq "00C6") {
		decrypt(\$newmsg, substr($msg, 4, length($msg)-4));
		$msg = substr($msg, 0, 4).$newmsg;
		undef @storeList;
		$storeList = 0;
		undef $talk{'buyOrSell'};
		for (my $i = 4; $i < $msg_size; $i += 11) {
			$price = unpack("L1", substr($msg, $i, 4));
			$type = unpack("C1", substr($msg, $i + 8, 1));
			$ID = unpack("S1", substr($msg, $i + 9, 2));
			$storeList[$storeList]{'nameID'} = $ID;
			$display = ($items_lut{$ID} ne "") 
				? $items_lut{$ID}
				: "Unknown ".$ID;
			$storeList[$storeList]{'name'} = $display;
			$storeList[$storeList]{'nameID'} = $ID;
			$storeList[$storeList]{'type'} = $type;
			$storeList[$storeList]{'price'} = $price;
			debug "Item added to Store: $storeList[$storeList]{'name'} - $price z\n", "parseMsg", 2;
			$storeList++;
		}
		message "$npcs{$talk{'ID'}}{'name'} : Check my store list by typing 'store'\n";
		
	} elsif ($switch eq "00C7") {
		#sell list, similar to buy list
		if (length($msg) > 4) {
			decrypt(\$newmsg, substr($msg, 4, length($msg)-4));
			$msg = substr($msg, 0, 4).$newmsg;
		}
		undef $talk{'buyOrSell'};
		message "Ready to start selling items\n";

	} elsif ($switch eq "00D1") {
		my $type = unpack("C1", substr($msg, 2, 1));
		my $error = unpack("C1", substr($msg, 3, 1));
		if ($type == 0) {
			message "Player ignored\n";
		} elsif ($type == 1) {
			if ($error == 0) {
				message "Player unignored\n";
			}
		}

	} elsif ($switch eq "00D2") {
		my $type = unpack("C1", substr($msg, 2, 1));
		my $error = unpack("C1", substr($msg, 3, 1));
		if ($type == 0) {
			message "All Players ignored\n";
		} elsif ($type == 1) {
			if ($error == 0) {
				message "All players unignored\n";
			}
		}

	} elsif ($switch eq "00D6") {
		$currentChatRoom = "new";
		%{$chatRooms{'new'}} = %createdChatRoom;
		binAdd(\@chatRoomsID, "new");
		binAdd(\@currentChatRoomUsers, $chars[$config{'char'}]{'name'});
		message "Chat Room Created\n";

	} elsif ($switch eq "00D7") {
		decrypt(\$newmsg, substr($msg, 17, length($msg)-17));
		$msg = substr($msg, 0, 17).$newmsg;
		$ID = substr($msg,8,4);
		if (!%{$chatRooms{$ID}}) {
			binAdd(\@chatRoomsID, $ID);
		}
		$chatRooms{$ID}{'title'} = substr($msg,17,$msg_size - 17);
		$chatRooms{$ID}{'ownerID'} = substr($msg,4,4);
		$chatRooms{$ID}{'limit'} = unpack("S1",substr($msg,12,2));
		$chatRooms{$ID}{'public'} = unpack("C1",substr($msg,16,1));
		$chatRooms{$ID}{'num_users'} = unpack("S1",substr($msg,14,2));
		
	} elsif ($switch eq "00D8") {
		$ID = substr($msg,2,4);
		binRemove(\@chatRoomsID, $ID);
		delete $chatRooms{$ID};

	} elsif ($switch eq "00DA") {
		$type = unpack("C1",substr($msg, 2, 1));
		if ($type == 1) {
			message "Can't join Chat Room - Incorrect Password\n";
		} elsif ($type == 2) {
			message "Can't join Chat Room - You're banned\n";
		}

	} elsif ($switch eq "00DB") {
		decrypt(\$newmsg, substr($msg, 8, length($msg)-8));
		$msg = substr($msg, 0, 8).$newmsg;
		$ID = substr($msg,4,4);
		$currentChatRoom = $ID;
		$chatRooms{$currentChatRoom}{'num_users'} = 0;
		for ($i = 8; $i < $msg_size; $i+=28) {
			$type = unpack("C1",substr($msg,$i,1));
			($chatUser) = substr($msg,$i + 4,24) =~ /([\s\S]*?)\000/;
			if ($chatRooms{$currentChatRoom}{'users'}{$chatUser} eq "") {
				binAdd(\@currentChatRoomUsers, $chatUser);
				if ($type == 0) {
					$chatRooms{$currentChatRoom}{'users'}{$chatUser} = 2;
				} else {
					$chatRooms{$currentChatRoom}{'users'}{$chatUser} = 1;
				}
				$chatRooms{$currentChatRoom}{'num_users'}++;
			}
		}
		message qq~You have joined the Chat Room "$chatRooms{$currentChatRoom}{'title'}"\n~;

	} elsif ($switch eq "00DC") {
		if ($currentChatRoom ne "") {
			$num_users = unpack("S1", substr($msg,2,2));
			($joinedUser) = substr($msg,4,24) =~ /([\s\S]*?)\000/;
			binAdd(\@currentChatRoomUsers, $joinedUser);
			$chatRooms{$currentChatRoom}{'users'}{$joinedUser} = 1;
			$chatRooms{$currentChatRoom}{'num_users'} = $num_users;
			message "$joinedUser has joined the Chat Room\n";
		}
	
	} elsif ($switch eq "00DD") {
		$num_users = unpack("S1", substr($msg,2,2));
		($leaveUser) = substr($msg,4,24) =~ /([\s\S]*?)\000/;
		$chatRooms{$currentChatRoom}{'users'}{$leaveUser} = "";
		binRemove(\@currentChatRoomUsers, $leaveUser);
		$chatRooms{$currentChatRoom}{'num_users'} = $num_users;
		if ($leaveUser eq $chars[$config{'char'}]{'name'}) {
			binRemove(\@chatRoomsID, $currentChatRoom);
			delete $chatRooms{$currentChatRoom};
			undef @currentChatRoomUsers;
			$currentChatRoom = "";
			message "You left the Chat Room\n";
		} else {
			message "$leaveUser has left the Chat Room\n";
		}

	} elsif ($switch eq "00DF") {
		decrypt(\$newmsg, substr($msg, 17, length($msg)-17));
		$msg = substr($msg, 0, 17).$newmsg;
		$ID = substr($msg,8,4);
		$ownerID = substr($msg,4,4);
		if ($ownerID eq $accountID) {
			$chatRooms{'new'}{'title'} = substr($msg,17,$msg_size - 17);
			$chatRooms{'new'}{'ownerID'} = $ownerID;
			$chatRooms{'new'}{'limit'} = unpack("S1",substr($msg,12,2));
			$chatRooms{'new'}{'public'} = unpack("C1",substr($msg,16,1));
			$chatRooms{'new'}{'num_users'} = unpack("S1",substr($msg,14,2));
		} else {
			$chatRooms{$ID}{'title'} = substr($msg,17,$msg_size - 17);
			$chatRooms{$ID}{'ownerID'} = $ownerID;
			$chatRooms{$ID}{'limit'} = unpack("S1",substr($msg,12,2));
			$chatRooms{$ID}{'public'} = unpack("C1",substr($msg,16,1));
			$chatRooms{$ID}{'num_users'} = unpack("S1",substr($msg,14,2));
		}
		message "Chat Room Properties Modified\n";
		
	} elsif ($switch eq "00E1") {
		$type = unpack("C1",substr($msg, 2, 1));
		($chatUser) = substr($msg, 6, 24) =~ /([\s\S]*?)\000/;
		if ($type == 0) {
			if ($chatUser eq $chars[$config{'char'}]{'name'}) {
				$chatRooms{$currentChatRoom}{'ownerID'} = $accountID;
			} else {
				$key = findKeyString(\%players, "name", $chatUser);
				$chatRooms{$currentChatRoom}{'ownerID'} = $key;
			}
			$chatRooms{$currentChatRoom}{'users'}{$chatUser} = 2;
		} else {
			$chatRooms{$currentChatRoom}{'users'}{$chatUser} = 1;
		}

	} elsif ($switch eq "00E5" || $switch eq "01F4") {
		# Recieving deal request
		($dealUser) = substr($msg, 2, 24) =~ /([\s\S]*?)\000/; 
		my $dealUserLevel = $switch eq "01F4" ?
			unpack("S1",substr($msg, 30, 2)) :
			'Unknown';
		$incomingDeal{'name'} = $dealUser; 
		$timeout{'ai_dealAutoCancel'}{'time'} = time; 
		message "$dealUser (level $dealUserLevel) Requests a Deal\n", "deal"; 
		message "Type 'deal' to start dealing, or 'deal no' to deny the deal.\n", "deal"; 

	} elsif ($switch eq "00E7" || $switch eq "01F5") {
		$type = unpack("C1", substr($msg, 2, 1));
		
		if ($type == 3) {
			if (%incomingDeal) {
				$currentDeal{'name'} = $incomingDeal{'name'};
				undef %incomingDeal;
			} else {
				$currentDeal{'ID'} = $outgoingDeal{'ID'};
				$currentDeal{'name'} = $players{$outgoingDeal{'ID'}}{'name'};
				undef %outgoingDeal;
			} 
			message "Engaged Deal with $currentDeal{'name'}\n", "deal";
		}

	} elsif ($switch eq "00E9") {
		my $amount = unpack("L*", substr($msg, 2,4));
		my $ID = unpack("S*", substr($msg, 6,2));
		if ($ID > 0) {
			$currentDeal{'other'}{$ID}{'amount'} += $amount;
			my $item = $currentDeal{other}{$ID} ||= {};
			$item->{amount} += $amount;
			$item->{nameID} = $ID;
			$item->{identified} = unpack("C1", substr($msg, 8, 1));
			$item->{upgrade} = unpack("C1", substr($msg, 10, 1));
			$item->{cards} = substr($msg, 11, 8);
			$item->{name} = itemName($item);
			message "$currentDeal{name} added Item to Deal: $item->{name} x $amount\n", "deal";
		} elsif ($amount > 0) {
			$currentDeal{other_zenny} += $amount;
			$amount = formatNumber($amount);
			message "$currentDeal{name} added $amount z to Deal\n", "deal";
		}

	} elsif ($switch eq "00EA") {
		my $index = unpack("S1", substr($msg, 2, 2));
		my $fail = unpack("C1", substr($msg, 4, 1));
		if ($fail) {
			error "That person is overweight; you cannot trade.\n", "deal";
		} elsif ($index > 0) {
			my $invIndex = findIndex(\@{$chars[$config{'char'}]{'inventory'}}, "index", $index);
			$currentDeal{'you'}{$chars[$config{'char'}]{'inventory'}[$invIndex]{'nameID'}}{'amount'} += $currentDeal{'lastItemAmount'};
			$chars[$config{'char'}]{'inventory'}[$invIndex]{'amount'} -= $currentDeal{'lastItemAmount'};
			message "You added Item to Deal: $chars[$config{'char'}]{'inventory'}[$invIndex]{'name'} x $currentDeal{'lastItemAmount'}\n", "deal";
			$currentDeal{you_items}++;
			if ($chars[$config{'char'}]{'inventory'}[$invIndex]{'amount'} <= 0) {
				delete $chars[$config{'char'}]{'inventory'}[$invIndex];
			}
		}

	} elsif ($switch eq "00EC") {
		$type = unpack("C1", substr($msg, 2, 1));
		if ($type == 1) {
			$currentDeal{'other_finalize'} = 1;
			message "$currentDeal{'name'} finalized the Deal\n", "deal";


		} else {
			$currentDeal{'you_finalize'} = 1;
			$chars[$config{'char'}]{'zenny'} -= $currentDeal{'you_zenny'};
			message "You finalized the Deal\n", "deal";
		}

	} elsif ($switch eq "00EE") {
		undef %incomingDeal;
		undef %outgoingDeal;
		undef %currentDeal;
		message "Deal Cancelled\n", "deal";

	} elsif ($switch eq "00F0") {
		undef %outgoingDeal;
		undef %incomingDeal;
		undef %currentDeal;
		message "Deal Complete\n", "deal";

	} elsif ($switch eq "00F2") {
		$storage{items} = unpack("S1", substr($msg, 2, 2));
		$storage{items_max} = unpack("S1", substr($msg, 4, 2));

		$ai_v{temp}{storage_opened} = 1;
		if (!$storage{opened}) {
			$storage{opened} = 1;
			message "Storage opened.\n", "storage";
			Plugins::callHook('packet_storage_open');
		}

		# Storage log
		my $f;
		if (open($f, "> $Settings::storage_file")) {
			print $f "---------- Storage ". getFormattedDate(int(time)) ." -----------\n";
			for (my $i = 0; $i < @storageID; $i++) {
				next if (!$storageID[$i]);
				my $item = $storage{$storageID[$i]};

				my $display = sprintf "%2d %s x %s", $i, $item->{name}, $item->{amount};
				$display .= " -- Not Identified" if !$item->{identified};
				print $f "$display\n";
			}
			print $f "\nCapacity: $storage{items}/$storage{items_max}\n";
			print $f "-------------------------------\n";
			close $f;
		}

	} elsif ($switch eq "00F6") {
		my $index = unpack("S1", substr($msg, 2, 2));
		my $amount = unpack("L1", substr($msg, 4, 4));
		$storage{$index}{amount} -= $amount;
		message "Storage Item Removed: $storage{$index}{name} ($storage{$index}{binID}) x $amount\n", "storage";
		if ($storage{$index}{amount} <= 0) {
			delete $storage{$index};
			binRemove(\@storageID, $index);
		}

	} elsif ($switch eq "00F8") {
		message "Storage closed.\n", "storage";
		delete $ai_v{temp}{storage_opened};
		Plugins::callHook('packet_storage_close');

	} elsif ($switch eq "00FA") {
		$type = unpack("C1", substr($msg, 2, 1));
		if ($type == 1) {
			warning "Can't organize party - party name exists\n";
		} 

	} elsif ($switch eq "00FB") {
		my $newmsg;
		decrypt(\$newmsg, substr($msg, 28, length($msg)-28));
		$msg = substr($msg, 0, 28).$newmsg;
		($chars[$config{'char'}]{'party'}{'name'}) = substr($msg, 4, 24) =~ /([\s\S]*?)\000/;
		for (my $i = 28; $i < $msg_size; $i += 46) {
			my $ID = substr($msg, $i, 4);
			my $num = unpack("C1",substr($msg, $i + 44, 1));
			if (binFind(\@partyUsersID, $ID) eq "") {
				binAdd(\@partyUsersID, $ID);
			}
			($chars[$config{'char'}]{'party'}{'users'}{$ID}{'name'}) = substr($msg, $i + 4, 24) =~ /([\s\S]*?)\000/;
			($chars[$config{'char'}]{'party'}{'users'}{$ID}{'map'}) = substr($msg, $i + 28, 16) =~ /([\s\S]*?)\000/;
			$chars[$config{'char'}]{'party'}{'users'}{$ID}{'online'} = !(unpack("C1",substr($msg, $i + 45, 1)));
			$chars[$config{'char'}]{'party'}{'users'}{$ID}{'admin'} = 1 if ($num == 0);
		}
		sendPartyShareEXP(\$remote_socket, 1) if ($config{'partyAutoShare'} && %{$chars[$config{'char'}]{'party'}});

	} elsif ($switch eq "00FD") {
		my ($name) = substr($msg, 2, 24) =~ /([\s\S]*?)\000/;
		my $type = unpack("C1", substr($msg, 26, 1));
		if ($type == 0) {
			warning "Join request failed: $name is already in a party\n";
		} elsif ($type == 1) {
			warning "Join request failed: $name denied request\n";
		} elsif ($type == 2) {
			message "$name accepted your request\n", "info";
		}

	} elsif ($switch eq "00FE") {
		my $ID = substr($msg, 2, 4);
		my ($name) = substr($msg, 6, 24) =~ /([\s\S]*?)\000/;
		message "Incoming Request to join party '$name'\n";
		$incomingParty{'ID'} = $ID;
		$timeout{'ai_partyAutoDeny'}{'time'} = time;

	} elsif ($switch eq "0101") {
		$type = unpack("C1", substr($msg, 2, 1));
		$chars[$config{'char'}]{'party'}{'share'} = $type;
		if ($type == 0) {
			message "Party EXP set to Individual Take\n", "party", 1;
		} elsif ($type == 1) {
			message "Party EXP set to Even Share\n", "party", 1;
		} else {
			error "Error setting party option\n";
		}
		
	} elsif ($switch eq "0104") {
		$ID = substr($msg, 2, 4);
		$x = unpack("S1", substr($msg,10, 2));
		$y = unpack("S1", substr($msg,12, 2));
		$type = unpack("C1",substr($msg, 14, 1));
		($name) = substr($msg, 15, 24) =~ /([\s\S]*?)\000/;
		($partyUser) = substr($msg, 39, 24) =~ /([\s\S]*?)\000/;
		($map) = substr($msg, 63, 16) =~ /([\s\S]*?)\000/;
		if (!%{$chars[$config{'char'}]{'party'}{'users'}{$ID}}) {
			binAdd(\@partyUsersID, $ID) if (binFind(\@partyUsersID, $ID) eq "");
			if ($ID eq $accountID) {
				message "You joined party '$name'\n", undef, 1;
			} else {
				message "$partyUser joined your party '$name'\n", undef, 1;
			}
		}
		if ($type == 0) {
			$chars[$config{'char'}]{'party'}{'users'}{$ID}{'online'} = 1;
		} elsif ($type == 1) {
			$chars[$config{'char'}]{'party'}{'users'}{$ID}{'online'} = 0;
		}
		$chars[$config{'char'}]{'party'}{'name'} = $name;
		$chars[$config{'char'}]{'party'}{'users'}{$ID}{'pos'}{'x'} = $x;
		$chars[$config{'char'}]{'party'}{'users'}{$ID}{'pos'}{'y'} = $y;
		$chars[$config{'char'}]{'party'}{'users'}{$ID}{'map'} = $map;
		$chars[$config{'char'}]{'party'}{'users'}{$ID}{'name'} = $partyUser;

		if ($config{'partyAutoShare'} && $char->{'party'} && $char->{'party'}{'users'}{$accountID}{'admin'}) {
			sendPartyShareEXP(\$remote_socket, 1);
		}
	
	} elsif ($switch eq "0105") {
		my $ID = substr($msg, 2, 4);
		my ($name) = substr($msg, 6, 24) =~ /([\s\S]*?)\000/;
		delete $chars[$config{'char'}]{'party'}{'users'}{$ID};
		binRemove(\@partyUsersID, $ID);
		if ($ID eq $accountID) {
			message "You left the party\n";
			undef %{$chars[$config{'char'}]{'party'}};
			$chars[$config{'char'}]{'party'} = "";
			undef @partyUsersID;
		} else {
			message "$name left the party\n";
		}


	} elsif ($switch eq "0106") {
		my $ID = substr($msg, 2, 4);
		$chars[$config{'char'}]{'party'}{'users'}{$ID}{'hp'} = unpack("S1", substr($msg, 6, 2));
		$chars[$config{'char'}]{'party'}{'users'}{$ID}{'hp_max'} = unpack("S1", substr($msg, 8, 2));

	} elsif ($switch eq "0107") {
		my $ID = substr($msg, 2, 4);
		my $x = unpack("S1", substr($msg,6, 2));
		my $y = unpack("S1", substr($msg,8, 2));
		$chars[$config{'char'}]{'party'}{'users'}{$ID}{'pos'}{'x'} = $x;
		$chars[$config{'char'}]{'party'}{'users'}{$ID}{'pos'}{'y'} = $y;
		$chars[$config{'char'}]{'party'}{'users'}{$ID}{'online'} = 1;
		debug "Party member location: $chars[$config{'char'}]{'party'}{'users'}{$ID}{'name'} - $x, $y\n", "parseMsg";

	} elsif ($switch eq "0108" || $switch eq "0188") {
		my ($type, $index, $upgrade) = unpack("S3", substr($msg, 2));
		my $invIndex = findIndex($char->{inventory}, "index", $index);
		if (defined $invIndex) {
			my $item = $char->{inventory}[$invIndex];
			$item->{upgrade} = $upgrade;
			message "Item $item->{name} has been upgraded to +$upgrade\n", "parseMsg/upgrade";
			$item->{name} = itemName($item);
		}

	} elsif ($switch eq "0109") {
		decrypt(\$newmsg, substr($msg, 8, length($msg)-8));
		my $ID = substr($msg, 4, 4);
		my $chat = substr($msg, 8, $msg_size - 8);
		$chat =~ s/\000//g;
		my ($chatMsgUser, $chatMsg) = $chat =~ /([\s\S]*?) : ([\s\S]*)/;
		$chatMsgUser =~ s/ $//;

		message "%$chat\n", "partychat";
		chatLog("p", "$chat\n") if ($config{'logPartyChat'});
		ChatQueue::add('p', $ID, $chatMsgUser, $chatMsg);

	# Hambo Started
	# 3 Packets About MVP
	} elsif ($switch eq "010A") {
		my $ID = unpack("S1", substr($msg, 2, 2));
		my $display = itemNameSimple($ID);
		message "Get MVP item $display\n";
		chatLog("k", "Get MVP item $display\n");

	} elsif ($switch eq "010B") {
		my $expAmount = unpack("L1", substr($msg, 2, 4));
		my $msg = "Congratulations, you are the MVP! Your reward is $expAmount exp!\n";
		message $msg;
		chatLog("k", $msg);

	} elsif ($switch eq "010C") {
		my $ID = substr($msg, 2, 4);
		my $display = getActorName($ID);
		message "$display become MVP!\n";
		chatLog("k", "$display become MVP!\n");
	# Hambo Ended

	} elsif ($switch eq "010E") {
		my $ID = unpack("S1",substr($msg, 2, 2));
		my $lv = unpack("S1",substr($msg, 4, 2));

		my $skill = new Skills(id => $ID);
		my $handle = $skill->handle;
		my $name = $skill->name;
		$char->{skills}{$handle}{lv} = $lv;
		debug "Skill $name: $lv\n", "parseMsg";

	} elsif ($switch eq "010F") {
		# Character skill list
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		decrypt(\$newmsg, substr($msg, 4, length($msg)-4));
		$msg = substr($msg, 0, 4).$newmsg;

		undef @skillsID;
		for (my $i = 4; $i < $msg_size; $i += 37) {
			my $skillID = unpack("S1", substr($msg, $i, 2));
			my $level = unpack("S1", substr($msg, $i + 6, 2));
			my ($skillName) = substr($msg, $i + 12, 24) =~ /([\s\S]*?)\000/;
			if (!$skillName) {
				$skillName = Skills->new(id => $skillID)->handle;
			}

			$char->{skills}{$skillName}{ID} = $skillID;
			if (!$char->{skills}{$skillName}{lv}) {
				$char->{skills}{$skillName}{lv} = $level;
			}
			$skillsID_lut{$skillID} = $skills_lut{$skillName};
			binAdd(\@skillsID, $skillName);

			# Reset $skillChanged back to 0 to tell kore that a skill can be auto-raised again
			if ($skillChanged eq $skillName) {
				$skillChanged = 0;
			}

			Plugins::callHook('packet_charSkills', {
				'ID' => $skillID,
				'skillName' => $skillName,
				'level' => $level,
				});
		}

	} elsif ($switch eq "0110") {
		# skill fail/delay
		my $skillID = unpack("S1", substr($msg, 2, 2));
		my $btype = unpack("S1", substr($msg, 4, 2));
		my $fail = unpack("C1", substr($msg, 8, 1));
		my $type = unpack("C1", substr($msg, 9, 1));
		
		my %failtype = (
			0 => 'Basic',
			1 => 'Insufficient SP',
			2 => 'Insufficient HP',
			3 => 'No Memo',
			4 => 'Mid-Delay',
			5 => 'No Zeny',
			6 => 'Wrong Weapon Type',
			7 => 'Red Gem Needed',
			8 => 'Blue Gem Needed',
			9 => '90% Overweight',
			10 => 'Requirement'
			);
		warning "Skill $skillsID_lut{$skillID} failed ($failtype{$type})\n", "skill";

	} elsif ($switch eq "01B9") {
		# Cast is cancelled
		my $skillID = unpack("S1", substr($msg, 2, 2));
		my $skill = new Skills(id => $skillID);
		my $name = $skill->name;
		$char->{cast_cancelled} = time;
		debug "Casting of skill $name has been cancelled.\n", "parseMsg";

	} elsif ($switch eq "0114" || $switch eq "01DE") {
		# Skill use
		my $dmg_t = $switch eq "0114" ? "s1" : "l1";
		my ($skillID, $sourceID, $targetID, $tick, $src_speed, $dst_speed, $damage, $level, $param3, $type) = unpack("x2 S1 a4 a4 L1 L1 L1 $dmg_t S1 S1 C1", $msg);

		if (my $spell = $spells{$sourceID}) {
			# Resolve source of area attack skill
			$sourceID = $spell->{sourceID};
		}

		# Perform trigger actions
		$conState = 5 if $conState != 4 && $config{XKore};
		updateDamageTables($sourceID, $targetID, $damage) if ($damage != -30000);
		setSkillUseTimer($skillID, $targetID) if ($sourceID eq $accountID);
		countCastOn($sourceID, $targetID, $skillID);

		# Resolve source and target names
		my ($source, $uses, $target) = getActorNames($sourceID, $targetID, 'use', 'uses');
		$damage ||= "Miss!";
		my $disp = "$source $uses ".skillName($skillID);
		$disp .= " (lvl $level)" unless $level == 65535;
		$disp .= " on $target";
		$disp .= " - Dmg: $damage" unless $damage == -30000;
		$disp .= " (delay ".($src_speed/10).")";
		$disp .= "\n";

		my $domain = "skill";

		if ($damage == 0) {
			$domain = "attackMonMiss" if (($source eq "You") && ($target ne "yourself"));
			$domain = "attackedMiss" if (($source ne "You") && ($target eq "You"));

		} elsif ($damage != -30000) {
			$domain = "attackMon" if (($source eq "You") && ($target ne "yourself"));
			$domain = "attacked" if (($source ne "You") && ($target eq "You"));
		}

		message $disp, $domain, 1;

		Plugins::callHook('packet_skilluse', {
			'skillID' => $skillID,
			'sourceID' => $sourceID,
			'targetID' => $targetID,
			'damage' => $damage,
			'amount' => 0,
			'x' => 0,
			'y' => 0
			});

	} elsif ($switch eq "0117") {
		# Skill used on coordinates
		my $skillID = unpack("S1", substr($msg, 2, 2));
		my $sourceID = substr($msg, 4, 4);
		my $lv = unpack("S1", substr($msg, 8, 2));
		my $x = unpack("S1", substr($msg, 10, 2));
		my $y = unpack("S1", substr($msg, 12, 2));
		
		# Perform trigger actions
		setSkillUseTimer($skillID) if $sourceID eq $accountID;

		# Resolve source name
		my ($source, $uses) = getActorNames($sourceID, 0, 'use', 'uses');
		my $disp = "$source $uses ".skillName($skillID);
		$disp .= " (lvl $lv)" unless $lv == 65535;
		$disp .= " on location ($x, $y)\n";

		# Print skill use message
		message $disp, 'skill';

		Plugins::callHook('packet_skilluse', {
			'skillID' => $skillID,
			'sourceID' => $sourceID,
			'targetID' => '',
			'damage' => 0,
			'amount' => $lv,
			'x' => $x,
			'y' => $y
		});


	} elsif ($switch eq "0119") {
		# Character looks
		my $ID = substr($msg, 2, 4);
		my $param1 = unpack("S1", substr($msg, 6, 2));
		my $param2 = unpack("S1", substr($msg, 8, 2));
		my $param3 = unpack("S1", substr($msg, 10, 2));
		my $actorType;
		my $actor = getActorHash($ID, \$actorType);

		if (defined $actor) {
			my $name = getActorName($ID);
			my $verbosity = ($actorType eq 'self') ? 1 : 2;
			my $are = ($actorType eq 'self') ? 'are' : 'is';
			my $have = ($actorType eq 'self') ? 'have' : 'has';

			foreach (keys %skillsState) {
				if ($param1 == $_) {
					$actor->{statuses}{$skillsState{$_}} = 1;
					message "$name $are in $skillsState{$_} state\n", "parseMsg_statuslook", $verbosity;
				} elsif ($actor->{statuses}{$skillsState{$_}}) {
					delete $actor->{statuses}{$skillsState{$_}};
					message "$name $are out of $skillsState{$_} state\n", "parseMsg_statuslook", $verbosity;
				}
			}

			foreach (keys %skillsAilments) {
				if (($param2 & $_) == $_) {
					$actor->{statuses}{$skillsAilments{$_}} = 1;
					message "$name $have ailments: $skillsAilments{$_}\n", "parseMsg_statuslook", $verbosity;
				} elsif ($actor->{statuses}{$skillsAilments{$_}}) {
					delete $actor->{statuses}{$skillsAilments{$_}};
					message "$name $are out of ailments: $skillsAilments{$_}\n", "parseMsg_statuslook", $verbosity;
				}
			}

			foreach (keys %skillsLooks) {
				if (($param3 & $_) == $_) {
					$actor->{statuses}{$skillsLooks{$_}} = 1;
					debug "$name $have look: $skillsLooks{$_}\n", "parseMsg_statuslook", $verbosity;
				} elsif ($actor->{statuses}{$skillsLooks{$_}}) {
					delete $actor->{statuses}{$skillsLooks{$_}};
					debug "$name $are out of look: $skillsLooks{$_}\n", "parseMsg_statuslook", $verbosity;
				}
			}
		}

	} elsif ($switch eq "011A") {
		# Skill used on target, with no damage done
		my $skillID = unpack("S1", substr($msg, 2, 2));
		my $amount = unpack("S1", substr($msg, 4, 2));
		my $targetID = substr($msg, 6, 4);
		my $sourceID = substr($msg, 10, 4);
		if (my $spell = $spells{$sourceID}) {
			# Resolve source of area attack skill
			$sourceID = $spell->{sourceID};
		}

		# Perform trigger actions
		$conState = 5 if $conState != 4 && $config{XKore};
		setSkillUseTimer($skillID, $targetID) if ($sourceID eq $accountID);
		countCastOn($sourceID, $targetID, $skillID);
		if ($sourceID eq $accountID) {
			my $pos = calcPosition($char);
			$char->{pos_to} = $pos;
			$char->{time_move} = 0;
			$char->{time_move_calc} = 0;
		}
		if ($AI && $config{'autoResponseOnHeal'}) {
			# Handle auto-response on heal
			if ((%{$players{$sourceID}}) && (($skillID == 28) || ($skillID == 29) || ($skillID == 34))) {
				if ($targetID eq $accountID) {
					chatLog("k", "***$sourceDisplay $skillsID_lut{$skillID} on $targetDisplay$extra***\n");
					sendMessage(\$remote_socket, "pm", getResponse("skillgoodM"), $players{$sourceID}{'name'});
				} elsif ($monsters{$targetID}) {
					chatLog("k", "***$sourceDisplay $skillsID_lut{$skillID} on $targetDisplay$extra***\n");
					sendMessage(\$remote_socket, "pm", getResponse("skillbadM"), $players{$sourceID}{'name'});
				}
			}
		}

		# Resolve source and target names
		my ($source, $uses, $target) = getActorNames($sourceID, $targetID, 'use', 'uses');

		# Print skill use message
		my $extra = "";
		if ($skillID == 28) {
			$extra = ": $amount hp gained";
		} elsif ($amount != 65535) {
			$extra = ": Lv $amount";
		}
  
		message "$source $uses ".skillName($skillID)." on $target$extra\n", "skill";

		Plugins::callHook('packet_skilluse', {
			'skillID' => $skillID,
			'sourceID' => $sourceID,
			'targetID' => $targetID,
			'damage' => 0,
			'amount' => $amount,
			'x' => 0,
			'y' => 0
			});

	} elsif ($switch eq "011C") {
		# Warp portal list

		# $type: 26 = Teleport, 27 = Warp Portal
		my ($type, $memo1, $memo2, $memo3, $memo4) =
			unpack("x2 S1 a16 a16 a16 a16", $msg);

		($memo1) = $memo1 =~ /([\s\S]*)\.gat/;
		($memo2) = $memo2 =~ /([\s\S]*)\.gat/;
		($memo3) = $memo3 =~ /([\s\S]*)\.gat/;
		($memo4) = $memo4 =~ /([\s\S]*)\.gat/;

		# Auto-detect saveMap
		if ($type == 26) {
			configModify('saveMap', $memo2) if $memo2;
		} elsif ($type == 27) {
			configModify('saveMap', $memo1) if $memo1;
		}

		$char->{warp}{type} = $type;
		undef @{$char->{warp}{memo}};
		push @{$char->{warp}{memo}}, $memo1 if $memo1 ne "";
		push @{$char->{warp}{memo}}, $memo2 if $memo2 ne "";
		push @{$char->{warp}{memo}}, $memo3 if $memo3 ne "";
		push @{$char->{warp}{memo}}, $memo4 if $memo4 ne "";

		message("----------------- Warp Portal --------------------\n", "list");
		message("#  Place                           Map\n", "list");
		for (my $i = 0; $i < @{$char->{warp}{memo}}; $i++) {
			message(swrite(
				"@< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<<<<",
				[$i, $maps_lut{$char->{warp}{memo}[$i].'.rsw'},
				$char->{warp}{memo}[$i]]),
				"list");
		}
		message("--------------------------------------------------\n", "list");

	} elsif ($switch eq "011E") {
		my $fail = unpack("C1", substr($msg, 2, 1));
		if ($fail) {
			warning "Memo Failed\n";
		} else {
			message "Memo Succeeded\n", "success";
		}

	} elsif ($switch eq "011F" || $switch eq "01C9") {
		# Area effect spell; including traps!
		my $ID = substr($msg, 2, 4);
		my $sourceID = substr($msg, 6, 4);
		my $x = unpack("S1", substr($msg, 10, 2));
		my $y = unpack("S1", substr($msg, 12, 2));
		my $type = unpack("C1", substr($msg, 14, 1));
		my $fail = unpack("C1", substr($msg, 15, 1));

		$spells{$ID}{'sourceID'} = $sourceID;
		$spells{$ID}{'pos'}{'x'} = $x;
		$spells{$ID}{'pos'}{'y'} = $y;
		$binID = binAdd(\@spellsID, $ID);
		$spells{$ID}{'binID'} = $binID;
		$spells{$ID}{'type'} = $type;
		if ($type == 0x81) {
			message getActorName($sourceID)." opened Warp Portal on ($x, $y)\n", "skill";
		}
		debug "Area effect ".getSpellName($type)." ($binID) from ".getActorName($sourceID)." appeared on ($x, $y)\n", "skill", 2;

		Plugins::callHook('packet_areaSpell', {
			fail => $fail,
			sourceID => $sourceID,
			type => $type,
			x => $x,
			y => $y
		});

	} elsif ($switch eq "0120") {
		# The area effect spell with ID dissappears
		my $ID = substr($msg, 2, 4);
		my $spell = $spells{$ID};
		debug "Area effect ".getSpellName($spell->{type})." ($spell->{binID}) from ".getActorName($spell->{sourceID})." disappeared from ($spell->{pos}{x}, $spell->{pos}{y})\n", "skill", 2;
		delete $spells{$ID};
		binRemove(\@spellsID, $ID);

	# Parses - chobit andy 20030102
	} elsif ($switch eq "0121") {
		$cart{'items'} = unpack("S1", substr($msg, 2, 2));
		$cart{'items_max'} = unpack("S1", substr($msg, 4, 2));
		$cart{'weight'} = int(unpack("L1", substr($msg, 6, 4)) / 10);
		$cart{'weight_max'} = int(unpack("L1", substr($msg, 10, 4)) / 10);

	} elsif ($switch eq "0122") {
		# "0122" sends non-stackable item info
		# "0123" sends stackable item info
		my $newmsg;
		decrypt(\$newmsg, substr($msg, 4, length($msg)-4));
		$msg = substr($msg, 0, 4).$newmsg;

		for (my $i = 4; $i < $msg_size; $i += 20) {
			my $index = unpack("S1", substr($msg, $i, 2));
			my $ID = unpack("S1", substr($msg, $i+2, 2));
			my $type = unpack("C1",substr($msg, $i+4, 1));
			my $item = $cart{inventory}[$index] = {};
			$item->{nameID} = $ID;
			$item->{amount} = 1;
			$item->{identified} = unpack("C1", substr($msg, $i+5, 1));
			$item->{type_equip} = unpack("S1", substr($msg, $i+6, 2));
			$item->{upgrade} = unpack("C1", substr($msg, $i+11, 1));
			$item->{cards} = substr($msg, $i+12, 8);
			$item->{name} = itemName($item);

			debug "Non-Stackable Cart Item: $item->{name} ($index) x 1\n", "parseMsg";
			Plugins::callHook('packet_cart', {index => $index});
		}

		$ai_v{'inventory_time'} = time + 1;
		$ai_v{'cart_time'} = time + 1;

	} elsif ($switch eq "0123" || $switch eq "01EF") {
		my $newmsg;
		decrypt(\$newmsg, substr($msg, 4, length($msg)-4));
		$msg = substr($msg, 0, 4).$newmsg;
		my $psize = ($switch eq "0123") ? 10 : 18;

		for (my $i = 4; $i < $msg_size; $i += $psize) {
			my $index = unpack("S1", substr($msg, $i, 2));
			my $ID = unpack("S1", substr($msg, $i+2, 2));
			my $amount = unpack("S1", substr($msg, $i+6, 2));

			my $item = $cart{inventory}[$index] ||= {};
			if ($item->{amount}) {
				$item->{amount} += $amount;
			} else {
				$item->{nameID} = $ID;
				$item->{amount} = $amount;
				$item->{name} = itemNameSimple($ID);
				$item->{identified} = 1;
			}
			debug "Stackable Cart Item: $item->{name} ($index) x $amount\n", "parseMsg";
			Plugins::callHook('packet_cart', {index => $index});
		}

		$ai_v{'inventory_time'} = time + 1;
		$ai_v{'cart_time'} = time + 1;

	} elsif ($switch eq "0124" || $switch eq "01C5") {
		my $index = unpack("S1", substr($msg, 2, 2));
		my $amount = unpack("L1", substr($msg, 4, 4));
		my $ID = unpack("S1", substr($msg, 8, 2));
		my $psize = $switch eq "0124" ? 0 : 1;

		my $item = $cart{inventory}[$index] ||= {};
		if ($item->{amount}) {
			$item->{amount} += $amount;
		} else {
			$item->{nameID} = $ID;
			$item->{amount} = $amount;
			$item->{identified} = unpack("C1", substr($msg, 10 + $psize, 1));
			$item->{upgrade} = unpack("C1", substr($msg, 12 + $psize, 1));
			$item->{cards} = substr($msg, 13 + $psize, 8);
			$item->{name} = itemName($item);
		}
		message "Cart Item Added: $item->{name} ($index) x $amount\n";

	} elsif ($switch eq "0125") {
		my $index = unpack("S1", substr($msg, 2, 2));
		my $amount = unpack("L1", substr($msg, 4, 4));

		$cart{'inventory'}[$index]{'amount'} -= $amount;
		message "Cart Item Removed: $cart{'inventory'}[$index]{'name'} ($index) x $amount\n";
		if ($cart{'inventory'}[$index]{'amount'} <= 0) {
			delete $cart{'inventory'}[$index];
		}

	} elsif ($switch eq "012C") {
		my $index = unpack("S1", substr($msg, 3, 2));
		my $amount = unpack("L1", substr($msg, 7, 2));
		my $ID = unpack("S1", substr($msg, 9, 2));
		if (defined $items_lut{$ID}) {
			message "Can't Add Cart Item: $items_lut{$ID}\n";
		}

	} elsif ($switch eq "012D") {
		# Used the shop skill.
		my $number = unpack("S1",substr($msg, 2, 2));
		message "You can sell $number items!\n";

	} elsif ($switch eq "0131") {
		my $ID = substr($msg,2,4);
		if (!%{$venderLists{$ID}}) {
			binAdd(\@venderListsID, $ID);
			Plugins::callHook('packet_vender', {ID => $ID});
		}
		($venderLists{$ID}{'title'}) = unpack("A30", substr($msg, 6, 36));
		$venderLists{$ID}{'id'} = $ID;

	} elsif ($switch eq "0132") {
		my $ID = substr($msg,2,4);
		binRemove(\@venderListsID, $ID);
		delete $venderLists{$ID};

	} elsif ($switch eq "0133") {
			undef @venderItemList;
			undef $venderID;
			$venderID = substr($msg,4,4);
			$venderItemList = 0;

			message("----------Vender Store List-----------\n", "list");
			message("#  Name                                         Type           Amount Price\n", "list");
			for ($i = 8; $i < $msg_size; $i+=22) {
				$number = unpack("S1", substr($msg, $i + 6, 2));

				my $item = $venderItemList[$number] = {};
				$item->{price} = unpack("L1", substr($msg, $i, 4));
				$item->{amount} = unpack("S1", substr($msg, $i + 4, 2));
				$item->{type} = unpack("C1", substr($msg, $i + 8, 1));
				$item->{nameID} = unpack("S1", substr($msg, $i + 9, 2));
				$item->{identified} = unpack("C1", substr($msg, $i + 11, 1));
				$item->{upgrade} = unpack("C1", substr($msg, $i + 13, 1));
				$item->{cards} = substr($msg, $i + 14, 8);
				$item->{name} = itemName($item);

				$venderItemList++;
				debug("Item added to Vender Store: $item->{name} - $price z\n", "vending", 2);

				Plugins::callHook('packet_vender_store', {
					venderID => $venderID,
					number => $number,
					name => $item->{name},
					amount => $item->{amount},
					price => $item->{price}
				});

				message(swrite(
					"@< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<< @>>>>> @>>>>>>>z",
					[$number, $item->{name}, $itemTypes_lut{$item->{type}}, $item->{amount}, $item->{price}]),
					"list");
			}
			message("--------------------------------------\n", "list");

			Plugins::callHook('packet_vender_store2', {
				venderID => $venderID,
				itemList => \@venderItemList
			});

	} elsif ($switch eq "0136") {
		$msg_size = unpack("S1",substr($msg,2,2));

		#started a shop.
		@articles = ();
		$articles = 0;

		# FIXME: Read the packet the server sends us to determine
		# the shop title instead of using $shop{title}.
		message(center(" $shop{title} ", 79, '-')."\n", "list");
		message("#  Name                                         Type        Amount     Price\n", "list");
		for (my $i = 8; $i < $msg_size; $i += 22) {
			my $number = unpack("S1", substr($msg, $i + 4, 2));
			my $item = $articles[$number] = {};
			$item->{nameID} = unpack("S1", substr($msg, $i + 9, 2));
			$item->{quantity} = unpack("S1", substr($msg, $i + 6, 2));
			$item->{type} = unpack("C1", substr($msg, $i + 8, 1));
			$item->{identified} = unpack("C1", substr($msg, $i + 11, 1));
			$item->{upgrade} = unpack("C1", substr($msg, $i + 13, 1));
			$item->{cards} = substr($msg, $i + 14, 8);
			$item->{price} = unpack("L1", substr($msg, $i, 4));
			$item->{name} = itemName($item);
			$articles++;

			debug("Item added to Vender Store: $item->{name} - $item->{price} z\n", "vending", 2);

			message(swrite(
				"@< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<< @>>>>> @>>>>>>>z",
				[$articles, $item->{name}, $itemTypes_lut{$item->{type}}, $item->{quantity}, $item->{price}]),
				"list");
		}
		message(('-'x79)."\n", "list");
		$shopEarned ||= 0;

	} elsif ($switch eq "0137") {
		# sold something
		my $number = unpack("S1", substr($msg, 2, 2));
		my $amount = unpack("S1", substr($msg, 4, 2));
		$articles[$number]{sold} += $amount;
		my $earned = $amount * $articles[$number]{price};
		$shopEarned += $earned;
		$articles[$number]{quantity} -= $amount;
		my $msg = "sold: $amount $articles[$number]{name} - $earned z\n";
		shopLog($msg);
		message($msg, "sold");
		if ($articles[$number]{quantity} < 1) {
			message("sold out: $articles[$number]{name}\n", "sold");
			#$articles[$number] = "";
			if (!--$articles){
				message("Items have been sold out.\n", "sold");
				closeShop();
			}
		}

	} elsif ($switch eq "0139") {
		$ID = substr($msg, 2, 4);
		$type = unpack("C1",substr($msg, 14, 1));
		$coords1{'x'} = unpack("S1",substr($msg, 6, 2));
		$coords1{'y'} = unpack("S1",substr($msg, 8, 2));
		$coords2{'x'} = unpack("S1",substr($msg, 10, 2));
		$coords2{'y'} = unpack("S1",substr($msg, 12, 2));
		%{$monsters{$ID}{'pos_attack_info'}} = %coords1 if ($monsters{$ID});
		%{$chars[$config{'char'}]{'pos'}} = %coords2;
		%{$chars[$config{'char'}]{'pos_to'}} = %coords2;
		debug "Received attack location - monster: $coords1{'x'},$coords1{'y'} - " .
			"you: $coords2{'x'},$coords2{'y'}\n", "parseMsg_move", 2;

	} elsif ($switch eq "013A") {
		my $type = unpack("S1",substr($msg, 2, 2));
		debug "Your attack range is: $type\n";
		$char->{attack_range} = $type;

	# Hambo Arrow Equip
	} elsif ($switch eq "013B") {
		my $type = unpack("S1",substr($msg, 2, 2)); 
		if ($type == 0) { 
			delete $char->{'arrow'};
			if ($config{'dcOnEmptyArrow'}) {
				$interface->errorDialog("Please equip arrow first.");
				quit();
			} else {
				error "Please equip arrow first.\n";
			}

		} elsif ($type == 3) {
			debug "Arrow equipped\n";
		} 

	} elsif ($switch eq "013C") {
		my $index = unpack("S1", substr($msg, 2, 2)); 
		$char->{arrow} = $index;

		my $invIndex = findIndex(\@{$chars[$config{'char'}]{'inventory'}}, "index", $index); 
		if ($invIndex ne "") { 
			$char->{inventory}[$invIndex]{equipped} = 32768;
			message "Arrow equipped: $char->{inventory}[$invIndex]{name} ($invIndex)\n";
		} 

	} elsif ($switch eq "013D") {
		$type = unpack("S1",substr($msg, 2, 2));
		$amount = unpack("S1",substr($msg, 4, 2));
		if ($type == 5) {
			$chars[$config{'char'}]{'hp'} += $amount;
			$chars[$config{'char'}]{'hp'} = $chars[$config{'char'}]{'hp_max'} if ($chars[$config{'char'}]{'hp'} > $chars[$config{'char'}]{'hp_max'});
		} elsif ($type == 7) {
			$chars[$config{'char'}]{'sp'} += $amount;
			$chars[$config{'char'}]{'sp'} = $chars[$config{'char'}]{'sp_max'} if ($chars[$config{'char'}]{'sp'} > $chars[$config{'char'}]{'sp_max'});
		}

	} elsif ($switch eq "013E") {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		my $sourceID = substr($msg, 2, 4);
		my $targetID = substr($msg, 6, 4);
		my $x = unpack("S1", substr($msg, 10, 2));
		my $y = unpack("S1", substr($msg, 12, 2));
		my $skillID = unpack("S1", substr($msg, 14, 2));
		my $type = unpack("S1", substr($msg, 18, 2));
		my $wait = unpack("L1", substr($msg, 20, 4));
		my ($dist, %coords);

		# Resolve source and target names
		my ($source, $verb, $target) = getActorNames($sourceID, $targetID, 'are casting', 'is casting');
		if ($x != 0 || $y != 0) {
			# If $dist is positive we are in range of the attack?
			$coords{x} = $x;
			$coords{y} = $y;
			$dist = judgeSkillArea($skillID) - distance($char->{pos_to}, \%coords);

			$target = "location ($x, $y)";
			undef $targetID;
		}

		# Perform trigger actions
		if ($sourceID eq $accountID) {
			$char->{time_cast} = time;
			$char->{time_cast_wait} = $wait / 1000;
			delete $char->{cast_cancelled};
		}

		countCastOn($sourceID, $targetID, $skillID, $x, $y);
		message "$source $verb ".skillName($skillID)." on $target (time ${wait}ms)\n", "skill", 1;

		Plugins::callHook('is_casting', {
			sourceID => $sourceID,
			targetID => $targetID,
			skillID => $skillID,
			x => $x,
			y => $y
		});

		# Skill Cancel
		if ($AI && %{$monsters{$sourceID}} && $mon_control{lc($monsters{$sourceID}{'name'})}{'skillcancel_auto'}) {
			if ($targetID eq $accountID || $dist > 0 || (AI::action eq "attack" && AI::args->{ID} ne $sourceID)) {
				message "Monster Skill - switch Target to : $monsters{$sourceID}{name} ($monsters{$sourceID}{binID})\n";
				stopAttack();
				AI::dequeue;
				attack($sourceID);
			}

			# Skill area casting -> running to monster's back
			my $ID = AI::args->{ID};
			if ($dist > 0) {
				# Calculate X axis
				if ($char->{pos_to}{x} - $monsters{$ID}{pos_to}{x} < 0) {
					$coords{x} = $monsters{$ID}{pos_to}{x} + 2;
				} else {
					$coords{x} = $monsters{$ID}{pos_to}{x} - 2;
				}
				# Calculate Y axis
				if ($char->{pos_to}{y} - $monsters{$ID}{pos_to}{y} < 0) {
					$coords{y} = $monsters{$ID}{pos_to}{y} + 2;
				} else {
					$coords{y} = $monsters{$ID}{pos_to}{y} - 2;
				}

				my (%vec, %pos);
				getVector(\%vec, \%coords, $char->{pos_to});
				moveAlongVector(\%pos, $char->{pos_to}, \%vec, distance($char->{'pos_to'}, \%coords));
				ai_route($field{name}, $pos{x}, $pos{y},
					maxRouteDistance => $config{'attackMaxRouteDistance'},
					maxRouteTime => $config{'attackMaxRouteTime'},
					noMapRoute => 1);
				message "Avoid casting Skill - switch position to : $pos{x},$pos{y}\n", 1;
			}
		}

	} elsif ($switch eq "0141") {
		$type = unpack("S1",substr($msg, 2, 2));
		$val = unpack("S1",substr($msg, 6, 2));
		$val2 = unpack("S1",substr($msg, 10, 2));
		if ($type == 13) {
			$chars[$config{'char'}]{'str'} = $val;
			$chars[$config{'char'}]{'str_bonus'} = $val2;
			debug "Strength: $val + $val2\n", "parseMsg";
		} elsif ($type == 14) {
			$chars[$config{'char'}]{'agi'} = $val;
			$chars[$config{'char'}]{'agi_bonus'} = $val2;
			debug "Agility: $val + $val2\n", "parseMsg";
		} elsif ($type == 15) {
			$chars[$config{'char'}]{'vit'} = $val;
			$chars[$config{'char'}]{'vit_bonus'} = $val2;
			debug "Vitality: $val + $val2\n", "parseMsg";
		} elsif ($type == 16) {
			$chars[$config{'char'}]{'int'} = $val;
			$chars[$config{'char'}]{'int_bonus'} = $val2;
			debug "Intelligence: $val + $val2\n", "parseMsg";
		} elsif ($type == 17) {
			$chars[$config{'char'}]{'dex'} = $val;
			$chars[$config{'char'}]{'dex_bonus'} = $val2;
			debug "Dexterity: $val + $val2\n", "parseMsg";
		} elsif ($type == 18) {
			$chars[$config{'char'}]{'luk'} = $val;
			$chars[$config{'char'}]{'luk_bonus'} = $val2;
			debug "Luck: $val + $val2\n", "parseMsg";
		}

	} elsif ($switch eq "0142") {
		$ID = substr($msg, 2, 4);
		message("$npcs{$ID}{'name'} : Type 'talk num <number #>' to input a number.\n", "input");
		$ai_v{'npc_talk'}{'talk'} = 'num';
		$ai_v{'npc_talk'}{'time'} = time;

	} elsif ($switch eq "0147") {
		my $skillID = unpack("S*",substr($msg, 2, 2));
		my $skillLv = unpack("S*",substr($msg, 8, 2)); 
		my $skillName = unpack("A*", substr($msg, 14, 24));

		message "Permitted to use $skillsID_lut{$skillID} ($skillID), level $skillLv\n";

		unless ($config{noAutoSkill}) {
			sendSkillUse(\$remote_socket, $skillID, $skillLv, $accountID);
		}

		Plugins::callHook('item_skill', {
			ID => $skillID,
			level => $skillLv,
			name => $skillName
		});

	} elsif ($switch eq "0148") {
		# 0148 long ID, word type
		my $targetID = substr($msg, 2, 4);
		my $type = unpack("S1", substr($msg, 6, 2));

		if ($targetID eq $accountID) {
			message("You have been resurrected\n", "info");
			undef $chars[$config{'char'}]{'dead'};
			undef $chars[$config{'char'}]{'dead_time'};
			$chars[$config{'char'}]{'resurrected'} = 1;

		} elsif (%{$players{$targetID}}) {
			undef $players{$targetID}{'dead'};
		}

		if ($targetID ne $accountID) {
			message(getActorName($targetID)." has been resurrected\n", "info");
		}

	} elsif ($switch eq "0154") {
		my $newmsg;
		my $jobID;
		decrypt(\$newmsg, substr($msg, 4, length($msg) - 4));
		my $msg = substr($msg, 0, 4) . $newmsg;
		my $c = 0;
		for (my $i = 4; $i < $msg_size; $i+=104){
			$guild{'member'}[$c]{'ID'}    = substr($msg, $i, 4);
			$jobID = unpack("S1", substr($msg, $i + 14, 2));
			if ($jobID =~ /^40/) {
				$jobID =~ s/^40/1/;
				$jobID += 60;
			}
			$guild{'member'}[$c]{'jobID'} = $jobID;
			$guild{'member'}[$c]{'lvl'}   = unpack("S1", substr($msg, $i + 16, 2));
			$guild{'member'}[$c]{'contribution'} = unpack("L1", substr($msg, $i + 18, 4));
			$guild{'member'}[$c]{'online'} = unpack("S1", substr($msg, $i + 22, 2));
			my $gtIndex = unpack("L1", substr($msg, $i + 26, 4));
			$guild{'member'}[$c]{'title'} = $guild{'title'}[$gtIndex];
			($guild{'member'}[$c]{'name'}) = substr($msg, $i + 80, 24) =~ /([\s\S]*?)\000/;
			$c++;
		}

	} elsif ($switch eq "0166") {
		my $newmsg;
		decrypt(\$newmsg, substr($msg, 4, length($msg) - 4));
		my $msg = substr($msg, 0, 4) . $newmsg;
		my $gtIndex;
		for (my $i = 4; $i < $msg_size; $i+=28) {
			$gtIndex = unpack("L1", substr($msg, $i, 4));
			($guild{'title'}[$gtIndex]) = substr($msg, $i + 4, 24) =~ /([\s\S]*?)\000/;
		}

	} elsif ($switch eq "016A") {
		# Guild request
		my $ID = substr($msg, 2, 4);
		my ($name) = substr($msg, 6, 24) =~ /([\s\S]*?)\000/;
		message "Incoming Request to join Guild '$name'\n";
		$incomingGuild{'ID'} = $ID;
		$incomingGuild{'Type'} = 1;
		$timeout{'ai_guildAutoDeny'}{'time'} = time;

	} elsif ($switch eq "016C") {
		($chars[$config{'char'}]{'guild'}{'name'}) = substr($msg, 19, 24) =~ /([\s\S]*?)\000/;

	} elsif ($switch eq "016D") {
		my $ID = substr($msg, 2, 4);
		my $TargetID =  substr($msg, 6, 4);
		my $online = unpack("L1", substr($msg, 10, 4));
		undef %nameRequest;
		$nameRequest{type} = "g";
		$nameRequest{ID} = $TargetID;
		$nameRequest{online} = $online;
		sendGuildMemberNameRequest(\$remote_socket, $TargetID);

	} elsif ($switch eq "016F") {
		my ($address) = substr($msg, 2, 60) =~ /([\s\S]*?)\000/;
		my ($message) = substr($msg, 62, 120) =~ /([\s\S]*?)\000/;
		message	"---Guild Notice---\n"
			."$address\n\n"
			."$message\n"
			."------------------\n", "guildnotice";

	} elsif ($switch eq "0171") {
		my $ID = substr($msg, 2, 4);
		my ($name) = substr($msg, 6, 24) =~ /([\s\S]*?)\000/;
		message "Incoming Request to Ally Guild '$name'\n";
		$incomingGuild{'ID'} = $ID;
		$incomingGuild{'Type'} = 2;
		$timeout{'ai_guildAutoDeny'}{'time'} = time;

	} elsif ($switch eq "0177") {
		my $newmsg;
		decrypt(\$newmsg, substr($msg, 4, length($msg)-4));
		my $msg = substr($msg, 0, 4).$newmsg;
		undef @identifyID;
		undef $invIndex;
		for (my $i = 4; $i < $msg_size; $i += 2) {
			my $index = unpack("S1", substr($msg, $i, 2));
			my $invIndex = findIndex(\@{$chars[$config{'char'}]{'inventory'}}, "index", $index);
			binAdd(\@identifyID, $invIndex);
		}
		my $num = @identifyID;
		message "Received Possible Identify List ($num item(s)) - type 'identify'\n", 'info';

	} elsif ($switch eq "0179") {
		$index = unpack("S*",substr($msg, 2, 2));
		undef $invIndex;
		$invIndex = findIndex(\@{$chars[$config{'char'}]{'inventory'}}, "index", $index);
		$chars[$config{'char'}]{'inventory'}[$invIndex]{'identified'} = 1;
		$chars[$config{'char'}]{'inventory'}[$invIndex]{'type_equip'} = $itemSlots_lut{$chars[$config{'char'}]{'inventory'}[$invIndex]{'nameID'}};
		message "Item Identified: $chars[$config{'char'}]{'inventory'}[$invIndex]{'name'}\n", "info";
		undef @identifyID;

	} elsif ($switch eq "017F") { 
		decrypt(\$newmsg, substr($msg, 4, length($msg)-4));
		$msg = substr($msg, 0, 4).$newmsg;
		my $ID = substr($msg, 4, 4);
		my $chat = substr($msg, 4, $msg_size - 4);
		$chat =~ s/\000*$//;
		my ($chatMsgUser, $chatMsg) = $chat =~ /(.*?) : (.*)/;
		$chatMsgUser =~ s/ $//;

		stripLanguageCode(\$chatMsg);
		$chat = "$chatMsgUser : $chatMsg";

		chatLog("g", "$chat\n") if ($config{'logGuildChat'});
		message "[Guild] $chat\n", "guildchat";
		ChatQueue::add('g', $ID, $chatMsgUser, $chatMsg);

	} elsif ($switch eq "018F") {
		my ($flag) = unpack("x2 S1", $msg);
		if ($flag) {
			message "You failed to refine a weapon!\n";
		} else {
			message "You successfully refined a weapon!\n";
		}

	} elsif ($switch eq "0194") {
		my $ID = substr($msg, 2, 4);
		my ($name) = unpack("Z*", substr($msg, 6, 24));
		
		if ($nameRequest{type} eq "g") {
			message "Guild Member $name Log ".($nameRequest{online}?"In":"Out")."\n", 'guildchat';
		}

	} elsif ($switch eq "0195") {
		my $ID = substr($msg, 2, 4);
		if (%{$players{$ID}}) {
			($players{$ID}{'name'}) = substr($msg, 6, 24) =~ /([\s\S]*?)\000/;
			$players{$ID}{'gotName'} = 1;
			($players{$ID}{'party'}{'name'}) = substr($msg, 30, 24) =~ /([\s\S]*?)\000/;
			($players{$ID}{'guild'}{'name'}) = substr($msg, 54, 24) =~ /([\s\S]*?)\000/;
			($players{$ID}{'guild'}{'title'}) = substr($msg, 78, 24) =~ /([\s\S]*?)\000/;
			debug "Player Info: $players{$ID}{'name'} ($players{$ID}{'binID'})\n", "parseMsg_presence", 2;
			Plugins::callHook('charNameUpdate');
		}

	} elsif ($switch eq "0196") {
		# 0196 - type: word, ID: long, flag: bool
		# This packet tells you about character statuses (such as when blessing or poison is (de)activated)
		my $type = unpack("S1", substr($msg, 2, 2));
		my $ID = substr($msg, 4, 4);
		my $flag = unpack("C1", substr($msg, 8, 1));

		my $skillName = (defined($skillsStatus{$type})) ? $skillsStatus{$type} : "Unknown $type";
		my $actor = getActorHash($ID);

		my ($name, $is) = getActorNames($ID, 0, 'are', 'is');
		if ($flag) {
			# Skill activated
			$actor->{statuses}{$skillName} = 1 if $actor;
			message "$name $is now: $skillName\n", "parseMsg_statuslook",
				$ID eq $accountID ? 1 : 2;

		} else {
			# Skill de-activated (expired)
			delete $actor->{statuses}{$skillName} if $actor;
			message "$name $is no longer: $skillName\n", "parseMsg_statuslook",
				$ID eq $accountID ? 1 : 2;
		}

	} elsif ($switch eq "019B") {
		my $ID = substr($msg, 2, 4);
		my $type = unpack("L1",substr($msg, 6, 4));
		if (%{$players{$ID}}) {
			$name = $players{$ID}{'name'};
		} else {
			$name = "Unknown";
		}
		if ($type == 0) {
			message "Player $name gained a level!\n";
		} elsif ($type == 1) {
			message "Player $name gained a job level!\n";
		} elsif ($type == 2) {
			message "$name failed to refine a weapon!\n";
		} elsif ($type == 3) {
			message "$name successfully refined a weapon!\n";
		}

	} elsif ($switch eq "01A0") {
		# Catch pet - result
		my $success = unpack("C1", substr($msg, 2, 1));
		if ($success) {
			message "Pet capture success\n";
		} else {
			message "Pet capture failed\n";
		}

	} elsif ($switch eq "01A2") {
		#pet
		my ($name) = substr($msg, 2, 24) =~ /([\s\S]*?)\000/;
		$pets{$ID}{'name_given'} = 1;

	} elsif ($switch eq "01A4") {
		#pet spawn
		my $type = unpack("C1",substr($msg, 2, 1));
		my $ID = substr($msg, 3, 4);
		if (!%{$pets{$ID}}) {
			binAdd(\@petsID, $ID);
			%{$pets{$ID}} = %{$monsters{$ID}};
			$pets{$ID}{'name_given'} = "Unknown";
			$pets{$ID}{'binID'} = binFind(\@petsID, $ID);
		}
		if (%{$monsters{$ID}}) {
			binRemove(\@monstersID, $ID);
			delete $monsters{$ID};
			objectRemoved('monster', $ID);
		}
		debug "Pet Spawned: $pets{$ID}{'name'} ($pets{$ID}{'binID'})\n", "parseMsg";
		#end of pet spawn code

	} elsif ($switch eq "01AA") {
		# 01aa: long ID, long emotion
		# pet emotion
		my ($ID, $type) = unpack "x2 a4 L1", $msg;
		my $emote = $emotions_lut{$type} || "/e$type";
		if ($pets{$ID}) {
			message "$pets{$ID}{name} : $emote\n", "emotion";
		}

	} elsif ($switch eq "01AC") {
		# 01AC: long ID
		# Indicates that an object is trapped, but ID is not a
		# valid monster or player ID.

	} elsif ($switch eq "01B0") {
		# Class change / monster type change
		# 01B0 : long ID, byte WhateverThisIs, long type
		my $ID = substr($msg, 2, 4);
		my $type = unpack("L1", substr($msg, 7, 4));

		if ($monsters{$ID}) {
			my $name = $monsters_lut{$type} || "Unknown $type";
			message "Monster $monsters{$ID}{name} ($monsters{$ID}{binID}) changed to $name\n";
			$monsters{$ID}{type} = $type;
			$monsters{$ID}{name} = $name;
		}

	} elsif ($switch eq "01B3") {
		# NPC image 
		my $npc_image = substr($msg, 2,64); 
		($npc_image) = $npc_image =~ /(\S+)/; 
		debug "NPC image: $npc_image\n", "parseMsg";

	} elsif ($switch eq "01B6") {
		# Guild Info 
		$guild{'ID'}        = substr($msg, 2, 4);
		$guild{'lvl'}       = unpack("L1", substr($msg,  6, 4));
		$guild{'conMember'} = unpack("L1", substr($msg, 10, 4));
		$guild{'maxMember'} = unpack("L1", substr($msg, 14, 4));
		$guild{'average'}   = unpack("L1", substr($msg, 18, 4));
		$guild{'exp'}       = unpack("L1", substr($msg, 22, 4));
		$guild{'next_exp'}  = unpack("L1", substr($msg, 26, 4));
		$guild{'members'}   = unpack("L1", substr($msg, 42, 4)) + 1;
		($guild{'name'})    = substr($msg, 46, 24) =~ /([\s\S]*?)\000/;
		($guild{'master'})  = substr($msg, 70, 24) =~ /([\s\S]*?)\000/;

	} elsif ($switch eq "01C4" || $switch eq "00F4") {
		my $index = unpack("S1", substr($msg, 2, 2));
		my $amount = unpack("L1", substr($msg, 4, 4));
		my $ID = unpack("S1", substr($msg, 8, 2));

		my $item = $storage{$index} ||= {};
		if ($item->{amount}) {
			$item->{amount} += $amount;
		} else {
			binAdd(\@storageID, $index);
			$item->{nameID} = $ID;
			$item->{index} = $index;
			$item->{amount} = $amount;
			if ($switch eq "01C4") {
				$item->{identified} = unpack("C1", substr($msg, 11, 1));
				$item->{upgrade} = unpack("C1", substr($msg, 13, 1));
				$item->{cards} = substr($msg, 14, 8);
			} elsif ($switch eq "00F4") {
				$item->{identified} = unpack("C1", substr($msg, 10, 1));
				$item->{upgrade} = unpack("C1", substr($msg, 12, 1));
				$item->{cards} = substr($msg, 13, 8);
			}
			$item->{name} = itemName($item);
			$item->{binID} = binFind(\@storageID, $index);
		}
		message("Storage Item Added: $item->{name} ($item->{binID}) x $amount\n", "storage", 1);
		Plugins::callHook('packet_storage_added');
		
	} elsif ($switch eq "01C8") {
		my $index = unpack("S1",substr($msg, 2, 2));
		my $ID = substr($msg, 6, 4);
		my $itemType = unpack("S1", substr($msg, 4, 2));
		my $amountleft = unpack("S1",substr($msg, 10, 2));
		my $itemDisplay = ($items_lut{$itemType} ne "") 
			? $items_lut{$itemType}
			: "Unknown " . unpack("L*", $ID);

		if ($ID eq $accountID) {
			my $invIndex = findIndex($char->{inventory}, "index", $index);
			my $amount = $char->{inventory}[$invIndex]{amount} - $amountleft;
			$char->{inventory}[$invIndex]{amount} -= $amount;

			message("You used Item: $char->{inventory}[$invIndex]{name} ($invIndex) x $amount\n", "useItem", 1);
			if ($char->{inventory}[$invIndex]{amount} <= 0) {
				delete $char->{inventory}[$invIndex];
			}

		} elsif (%{$players{$ID}}) {
			message("Player $players{$ID}{'name'} ($players{$ID}{'binID'}) used Item: $itemDisplay - $amountleft left\n", "useItem", 2);

		} elsif (%{$monsters{$ID}}) {
			message("Monster $monsters{$ID}{'name'} ($monsters{$ID}{'binID'}) used Item: $itemDisplay - $amountleft left\n", "useItem", 2);

		} else {
			message("Unknown " . unpack("L*", $ID) . " used Item: $itemDisplay - $amountleft left\n", "useItem", 2);

		}

	} elsif ($switch eq "01D0" || $switch eq "01E1"){
		# Monk Spirits
		my $sourceID = substr($msg, 2, 4);
		my $spirits = unpack("S1", substr($msg, 6, 2));

		if ($sourceID eq $accountID) {
			$char->{spirits} = $spirits;
			message "You have $spirits spirit(s) now\n", "parseMsg_statuslook", 1;

		} elsif ($players{$sourceID}) {
			$players{$sourceID}{spirits} = $spirits;
		}

	} elsif ($switch eq "01D4") {
		# NPC requested a text string reply
		my $ID = substr($msg, 2, 4);
		message "$npcs{$ID}{'name'} : Type 'talk text' (Respond to NPC)\n", "npc";
		$ai_v{'npc_talk'}{'talk'} = 'text';
		$ai_v{'npc_talk'}{'time'} = time;

	} elsif ($switch eq "01D7") {
		# Weapon Display (type - 2:hand eq, 9:foot eq)
		my $sourceID = substr($msg, 2, 4);
		my $type = unpack("C1",substr($msg, 6, 1));
		my $ID1 = unpack("S1", substr($msg, 7, 2));
		my $ID2 = unpack("S1", substr($msg, 9, 2));
      		
	} elsif ($switch eq "01DC") {
		$secureLoginKey = substr($msg, 4, $msg_size);

	} elsif ($switch eq "01F4") {
		# Recieving deal request
		# 01DC: 24byte nick, long charID, word level
		($dealUser) = substr($msg, 2, 24) =~ /([\s\S]*?)\000/;
		my $dealUserLevel = unpack("S1",substr($msg, 30, 2));
		$incomingDeal{'name'} = $dealUser;
		$timeout{'ai_dealAutoCancel'}{'time'} = time;
		message "$dealUser (level $dealUserLevel) Requests a Deal\n", "deal";
		message "Type 'deal' to start dealing, or 'deal no' to deny the deal.\n", "deal";

	} elsif ($switch eq "01F5") {
		# The deal you request has been accepted
		# 01F5: byte fail, long charID, word level
		my $type = unpack("C1", substr($msg, 2, 1));
		if ($type == 3) {
			if (%incomingDeal) {
				$currentDeal{'name'} = $incomingDeal{'name'};
			} else {
				$currentDeal{'ID'} = $outgoingDeal{'ID'};
				$currentDeal{'name'} = $players{$outgoingDeal{'ID'}}{'name'};
			}
			message "Engaged Deal with $currentDeal{'name'}\n", "deal";
		}
		undef %outgoingDeal;
		undef %incomingDeal;

	} elsif ($switch eq "01AD") {
		decrypt(\$newmsg, substr($msg, 4, length($msg)-4));
		$msg = substr($msg, 0, 4).$newmsg;
		undef @arrowCraftID;
		for ($i = 4; $i < $msg_size; $i += 2) {
			$ID = unpack("S1", substr($msg, $i, 2));
			my $index = findIndex($char->{inventory}, "nameID", $ID);
			binAdd(\@arrowCraftID, $index);
		}
		message "Received Possible Arrow Craft List - type 'arrowcraft'\n";

	#} elsif ($switch eq "0187") {
		# 0187 - ID: long
		# Deal canceled
	#	undef %incomingDeal;
	#	undef %outgoingDeal;
	#	undef %currentDeal;
	#	message "Deal Cancelled\n", "deal";
	}

	$msg = (length($msg) >= $msg_size) ? substr($msg, $msg_size, length($msg) - $msg_size) : "";
	return $msg;
}




#######################################
#######################################
#AI FUNCTIONS
#######################################
#######################################

##
# ai_clientSuspend(packet_switch, duration, args...)
# initTimeout: a number of seconds.
#
# Freeze the AI for $duration seconds. $packet_switch and @args are only
# used internally and are ignored unless XKore mode is turned on.
sub ai_clientSuspend {
	my ($type, $duration, @args) = @_;
	my %args;
	$args{type} = $type;
	$args{time} = time;
	$args{timeout} = $duration;
	@{$args{args}} = @args;
	AI::queue("clientSuspend", \%args);
	debug "AI suspended by clientSuspend for $args{timeout} seconds\n";
}

##
# ai_drop(items, max)
# items: reference to an array of inventory item numbers.
# max: the maximum amount to drop, for each item, or 0 for unlimited.
#
# Drop one or more items.
#
# Example:
# # Drop inventory items 2 and 5.
# ai_drop([2, 5]);
# # Drop inventory items 2 and 5, but at most 30 of each item.
# ai_drop([2, 5], 30);
sub ai_drop {
	my $r_items = shift;
	my $max = shift;
	my %seq = ();

	if (@{$r_items} == 1) {
		# Dropping one item; do it immediately
		drop($r_items->[0], $max);
	} else {
		# Dropping multiple items; queue an AI sequence
		$seq{items} = \@{$r_items};
		$seq{max} = $max;
		$seq{timeout} = 1;
		AI::queue("drop", \%seq);
	}
}

sub ai_follow {
	my $name = shift;

	if (binFind(\@ai_seq, "follow") eq "") {
		my %args;
		$args{name} = $name; 
		push @ai_seq, "follow";
		push @ai_seq_args, \%args;
	}
	
	return 1;
}

sub ai_partyfollow {
	# we have to enable re-calc of route based on master's possition regulary, even when it is
	# on route and move, otherwise we have finaly moved to the possition and found that the master
	# already teleported to another side of the map.

	# This however will give problem on few seq such as storageAuto as 'move' and 'route' might
	# be triggered to move to the NPC

	my %master;
	$master{id} = findPartyUserID($config{followTarget});
	if ($master{id} ne "" && !AI::inQueue("storageAuto","storageGet","sellAuto","buyAuto")) {

		$master{x} = $char->{party}{users}{$master{id}}{pos}{x};
		$master{y} = $char->{party}{users}{$master{id}}{pos}{y};
		($master{map}) = $char->{party}{users}{$master{id}}{map} =~ /([\s\S]*)\.gat/;

		if ($master{map} ne $field{name} || $master{x} == 0 || $master{y} == 0) {
			delete $master{x};
			delete $master{y};
		}

		return unless ($master{map} ne $field{name} || exists $master{x});
		
		if ((exists $ai_v{master} && distance(\%master, \%{$ai_v{master}}) > 15)
			|| $master{map} != $ai_v{master}{map}
			|| (timeOut($ai_v{master}{time}, 15) && distance(\%master, $char->{pos_to}) > $config{followDistanceMax})) {

			$ai_v{master}{x} = $master{x};
			$ai_v{master}{y} = $master{y};
			$ai_v{master}{map} = $master{map};
			$ai_v{master}{time} = time; 

			if ($ai_v{master}{map} ne $field{name}) {
				message "Calculating route to find master: $ai_v{master}{map}\n", "follow";
			} elsif (distance(\%master, $char->{pos_to}) > $config{followDistanceMax} ) {
				message "Calculating route to find master: $ai_v{master}{map} ($ai_v{master}{x},$ai_v{master}{y})\n", "follow";
			} else {
				return;
			}

			AI::clear("move", "route", "mapRoute");
			ai_route($ai_v{master}{map}, $ai_v{master}{x}, $ai_v{master}{y}, distFromGoal => $config{followDistanceMin});
			
			my $followIndex = AI::findAction("follow");
			if (defined $followIndex) {
				$ai_seq_args[$followIndex]{ai_follow_lost_end}{timeout} = $timeout{ai_follow_lost_end}{timeout};
			}
		}
	}
}

##
# ai_getAggressives([check_mon_control], [party])
# Returns: an array of monster hashes.
#
# Get a list of all aggressive monsters on screen.
# The definition of "aggressive" is: a monster who has hit or missed me.
#
# If $check_mon_control is set, then all monsters in mon_control.txt
# with the 'attack_auto' flag set to 2, will be considered as aggressive.
# See also the manual for more information about this.
#
# If $party is set, then monsters that have fought with party members
# (not just you) will be considered as aggressive.
sub ai_getAggressives {
	my ($type, $party) = @_;
	my $wantArray = wantarray;
	my $num = 0;
	my @agMonsters;

	foreach (@monstersID) {
		next if (!$_);
		my $monster = $monsters{$_};
		if ((($type && $mon_control{lc($monster->{name})}{attack_auto} == 2) || 
		    $monster->{dmgToYou} || $monster->{missedYou} ||
			($party && ($monster->{dmgToParty} || $monster->{missedToParty} || $monster->{dmgFromParty})))
		  && timeOut($monster->{attack_failed}, $timeout{ai_attack_unfail}{timeout})) {

			if ($wantArray) {
				# Function is called in array context
				push @agMonsters, $_;

			} else {
				# Function is called in scalar context
				if ($mon_control{lc($monster->{name})}{weight} > 0) {
					$num += $mon_control{lc($monster->{name})}{weight};
				} elsif ($mon_control{lc($monster->{name})}{weight} != -1) {
					$num++;
				}
			}
		}
	}

	if ($wantArray) {
		return @agMonsters;
	} else {
		return $num;
	}
}

sub ai_getPlayerAggressives {
	my $ID = shift;
	my @agMonsters;

	foreach (@monstersID) {
		next if ($_ eq "");
		if ($monsters{$_}{dmgToPlayer}{$ID} > 0 || $monsters{$_}{missedToPlayer}{$ID} > 0 || $monsters{$_}{dmgFromPlayer}{$ID} > 0 || $monsters{$_}{missFromPlayer}{$ID} > 0) {
			push @agMonsters, $_;
		}
	}
	return @agMonsters;
}

##
# ai_getMonstersAttacking($ID)
#
# Get the monsters who are attacking player $ID.
sub ai_getMonstersAttacking {
	my $ID = shift;
	my @agMonsters;
	foreach (@monstersID) {
		next unless $_;
		my $monster = $monsters{$_};
		push @agMonsters, $_ if $monster->{target} eq $ID;
	}
	return @agMonsters;
}

##
# ai_getSkillUseType(name)
# name: the internal name of the skill (as found in skills.txt), such as
# WZ_FIREPILLAR.
# Returns: 1 if it's a location skill, 0 if it's an object skill.
#
# Determines whether a skill is a skill that's casted on a location, or one
# that's casted on an object (monster/player/etc).
# For example, Firewall is a location skill, while Cold Bolt is an object
# skill.
sub ai_getSkillUseType {
	my $skill = shift;
	return 1 if $skillsArea{$skill} == 1;
	return 0;
}

sub ai_mapRoute_searchStep {
	my $r_args = shift;

	unless (%{$$r_args{'openlist'}}) {
		$$r_args{'done'} = 1;
		$$r_args{'found'} = '';
		return 0;
	}

	my $parent = (sort {$$r_args{'openlist'}{$a}{'walk'} <=> $$r_args{'openlist'}{$b}{'walk'}} keys %{$$r_args{'openlist'}})[0];
	# Uncomment this if you want minimum MAP count. Otherwise use the above for minimum step count
	#foreach my $parent (keys %{$$r_args{'openlist'}})
	{
		my ($portal,$dest) = split /=/, $parent;
		if ($$r_args{'budget'} ne '' && $$r_args{'openlist'}{$parent}{'zenny'} > $$r_args{'budget'}) {
			#This link is too expensive
			delete $$r_args{'openlist'}{$parent};
			next;
		} else {
			#MOVE this entry into the CLOSELIST
			$$r_args{'closelist'}{$parent}{'walk'}   = $$r_args{'openlist'}{$parent}{'walk'};
			$$r_args{'closelist'}{$parent}{'zenny'}  = $$r_args{'openlist'}{$parent}{'zenny'};
			$$r_args{'closelist'}{$parent}{'parent'} = $$r_args{'openlist'}{$parent}{'parent'};
			#Then delete in from OPENLIST
			delete $$r_args{'openlist'}{$parent};
		}

		if ($portals_lut{$portal}{'dest'}{$dest}{'map'} eq $$r_args{'dest'}{'map'}) {
			if ($$r_args{'dest'}{'pos'}{'x'} eq '' && $$r_args{'dest'}{'pos'}{'y'} eq '') {
				$$r_args{'found'} = $parent;
				$$r_args{'done'} = 1;
				undef @{$$r_args{'mapSolution'}};
				my $this = $$r_args{'found'};
				while ($this) {
					my %arg;
					$arg{'portal'} = $this;
					my ($from,$to) = split /=/, $this;
					($arg{'map'},$arg{'pos'}{'x'},$arg{'pos'}{'y'}) = split / /,$from;
					$arg{'walk'} = $$r_args{'closelist'}{$this}{'walk'};
					$arg{'zenny'} = $$r_args{'closelist'}{$this}{'zenny'};
					$arg{'steps'} = $portals_lut{$from}{'dest'}{$to}{'steps'};
					unshift @{$$r_args{'mapSolution'}},\%arg;
					$this = $$r_args{'closelist'}{$this}{'parent'};
				}
				return;
			} elsif ( ai_route_getRoute(\@{$$r_args{'solution'}}, \%{$$r_args{'dest'}{'field'}}, \%{$portals_lut{$portal}{'dest'}{$dest}{'pos'}}, \%{$$r_args{'dest'}{'pos'}}) ) {
				my $walk = "$$r_args{'dest'}{'map'} $$r_args{'dest'}{'pos'}{'x'} $$r_args{'dest'}{'pos'}{'y'}=$$r_args{'dest'}{'map'} $$r_args{'dest'}{'pos'}{'x'} $$r_args{'dest'}{'pos'}{'y'}";
				$$r_args{'closelist'}{$walk}{'walk'} = scalar @{$$r_args{'solution'}} + $$r_args{'closelist'}{$parent}{$dest}{'walk'};
				$$r_args{'closelist'}{$walk}{'parent'} = $parent;
				$$r_args{'closelist'}{$walk}{'zenny'} = $$r_args{'closelist'}{$parent}{'zenny'};
				$$r_args{'found'} = $walk;
				$$r_args{'done'} = 1;
				undef @{$$r_args{'mapSolution'}};
				my $this = $$r_args{'found'};
				while ($this) {
					my %arg;
					$arg{'portal'} = $this;
					my ($from,$to) = split /=/, $this;
					($arg{'map'},$arg{'pos'}{'x'},$arg{'pos'}{'y'}) = split / /,$from;
					$arg{'walk'} = $$r_args{'closelist'}{$this}{'walk'};
					$arg{'zenny'} = $$r_args{'closelist'}{$this}{'zenny'};
					$arg{'steps'} = $portals_lut{$from}{'dest'}{$to}{'steps'};
					unshift @{$$r_args{'mapSolution'}},\%arg;
					$this = $$r_args{'closelist'}{$this}{'parent'};
				}
				return;
			}
		}
		#get all children of each openlist
		foreach my $child (keys %{$portals_los{$dest}}) {
			next unless $portals_los{$dest}{$child};
			foreach my $subchild (keys %{$portals_lut{$child}{'dest'}}) {
				my $destID = $portals_lut{$child}{'dest'}{$subchild}{'ID'};
				my $mapName = $portals_lut{$child}{'source'}{'map'};
				#############################################################
				my $penalty = int($routeWeights{lc($mapName)}) + int(($portals_lut{$child}{'dest'}{$subchild}{'steps'} ne '') ? $routeWeights{'NPC'} : $routeWeights{'PORTAL'});
				my $thisWalk = $penalty + $$r_args{'closelist'}{$parent}{'walk'} + $portals_los{$dest}{$child};
				if (!exists $$r_args{'closelist'}{"$child=$subchild"}) {
					if ( !exists $$r_args{'openlist'}{"$child=$subchild"} || $$r_args{'openlist'}{"$child=$subchild"}{'walk'} > $thisWalk ) {
						$$r_args{'openlist'}{"$child=$subchild"}{'parent'} = $parent;
						$$r_args{'openlist'}{"$child=$subchild"}{'walk'} = $thisWalk;
						$$r_args{'openlist'}{"$child=$subchild"}{'zenny'} = $$r_args{'closelist'}{$parent}{'zenny'} + $portals_lut{$child}{'dest'}{$subchild}{'cost'};
					}
				}
			}
		}
	}
}

sub ai_items_take {
	my ($x1, $y1, $x2, $y2) = @_;
	my %args;
	$args{pos}{x} = $x1;
	$args{pos}{y} = $y1;
	$args{pos_to}{x} = $x2;
	$args{pos_to}{y} = $y2;
	$args{ai_items_take_end}{time} = time;
	$args{ai_items_take_end}{timeout} = $timeout{ai_items_take_end}{timeout};
	$args{ai_items_take_start}{time} = time;
	$args{ai_items_take_start}{timeout} = $timeout{ai_items_take_start}{timeout};
	AI::queue("items_take", \%args);
}

sub ai_route {
	my $map = shift;
	my $x = shift;
	my $y = shift;
	my %param = @_;
	debug "On route to: $maps_lut{$map.'.rsw'}($map): $x, $y\n", "route";

	my %args;
	$x = int($x) if ($x ne "");
	$y = int($y) if ($y ne "");
	$args{'dest'}{'map'} = $map;
	$args{'dest'}{'pos'}{'x'} = $x;
	$args{'dest'}{'pos'}{'y'} = $y;
	$args{'maxRouteDistance'} = $param{maxRouteDistance} if exists $param{maxRouteDistance};
	$args{'maxRouteTime'} = $param{maxRouteTime} if exists $param{maxRouteTime};
	$args{'attackOnRoute'} = $param{attackOnRoute} if exists $param{attackOnRoute};
	$args{'distFromGoal'} = $param{distFromGoal} if exists $param{distFromGoal};
	$args{'pyDistFromGoal'} = $param{pyDistFromGoal} if exists $param{pyDistFromGoal};
	$args{'attackID'} = $param{attackID} if exists $param{attackID};
	$args{'noSitAuto'} = $param{noSitAuto} if exists $param{noSitAuto};
	$args{'noAvoidWalls'} = $param{noAvoidWalls} if exists $param{noAvoidWalls};
	$args{'tags'} = $param{tags} if exists $param{tags};
	$args{'time_start'} = time;

	if (!$param{'_internal'}) {
		$args{'solution'} = [];
		$args{'mapSolution'} = [];
	} elsif (exists $param{'_solution'}) {
		$args{'solution'} = $param{'_solution'};
	}

	# Destination is same map and isn't blocked by walls/water/whatever
	my $pos = calcPosition($char);
	if ($param{'_internal'} || ($field{'name'} eq $args{'dest'}{'map'} && ai_route_getRoute(\@{$args{solution}}, \%field, $pos, $args{dest}{pos}, $args{noAvoidWalls}))) {
		# Since the solution array is here, we can start in "Route Solution Ready"
		$args{'stage'} = 'Route Solution Ready';
		debug "Route Solution Ready\n", "route";
		AI::queue("route", \%args);
		return 1;
	} else {
		return 0 if ($param{noMapRoute});
		# Nothing is initialized so we start scratch
		AI::queue("mapRoute", \%args);
		return 1;
	}
}

##
# ai_route_getRoute(returnArray, r_field, r_start, r_dest, [noAvoidWalls])
# returnArray: reference to an array. The solution will be stored in here.
# r_field: reference to a field hash (usually \%field).
# r_start: reference to a hash. This is the start coordinate.
# r_dest: reference to a hash. This is the destination coordinate.
# noAvoidWalls: 1 if you don't want to avoid walls on route.
# Returns: 1 if the calculation succeeded, 0 if not.
#
# Calculates how to walk from $r_start to $r_dest.
# The blocks you have to walk on in order to get to $r_dest are stored in
# $returnArray. This function is a convenience wrapper function for the stuff
# in PathFinding.pm
sub ai_route_getRoute {
	my ($returnArray, $r_field, $r_start, $r_dest, $noAvoidWalls) = @_;
	undef @{$returnArray};
	return 1 if ($r_dest->{x} eq '' || $r_dest->{y} eq '');

	# The exact destination may not be a spot that we can walk on.
	# So we find a nearby spot that is walkable.
	my %start = %{$r_start};
	my %dest = %{$r_dest};
	closestWalkableSpot($r_field, \%start);
	closestWalkableSpot($r_field, \%dest);

	# Generate map weights (for wall avoidance)
	my $weights;
	if ($noAvoidWalls) {
		$weights = chr(255) . (chr(1) x 255);
	} else {
		$weights = join '', map chr $_, (255, 8, 7, 6, 5, 4, 3, 2, 1);
		$weights .= chr(1) x (256 - length($weights));
	}

	# Calculate path
	my $pathfinding = new PathFinding(
		start => \%start,
		dest => \%dest,
		field => $r_field,
		weights => $weights
	);
	return undef if !$pathfinding;

	my $ret = $pathfinding->run($returnArray);
	if ($ret <= 0) {
		# Failure
		return undef;
	} else {
		# Success
		return $ret;
	}
}

#sellAuto for items_control - chobit andy 20030210
sub ai_sellAutoCheck {
	for ($i = 0; $i < @{$chars[$config{'char'}]{'inventory'}};$i++) {
		next if (!%{$chars[$config{'char'}]{'inventory'}[$i]} || $chars[$config{'char'}]{'inventory'}[$i]{'equipped'});
		my $sell = $items_control{'all'}{'sell'};
		$sell = $items_control{lc($chars[$config{'char'}]{'inventory'}[$i]{'name'})}{'sell'} if ($items_control{lc($chars[$config{'char'}]{'inventory'}[$i]{'name'})});
		my $keep = $items_control{'all'}{'keep'};
		$keep = $items_control{lc($chars[$config{'char'}]{'inventory'}[$i]{'name'})}{'keep'} if ($items_control{lc($chars[$config{'char'}]{'inventory'}[$i]{'name'})});
		if ($sell && $chars[$config{'char'}]{'inventory'}[$i]{'amount'} > $keep) {
			return 1;
		}
	}
}

sub ai_setMapChanged {
	my $index = shift;
	$index = 0 if ($index eq "");
	if ($index < @ai_seq_args) {
		$ai_seq_args[$index]{'mapChanged'} = time;
	}
}

sub ai_setSuspend {
	my $index = shift;
	$index = 0 if ($index eq "");
	if ($index < @ai_seq_args) {
		$ai_seq_args[$index]{'suspended'} = time;
	}
}

sub ai_skillUse {
	return if ($char->{muted});
	my %args = (
		skillHandle => shift,
		lv => shift,
		maxCastTime => { time => time, timeout => shift },
		minCastTime => { time => time, timeout => shift },
		target => shift,
		y => shift,
		tag => shift,
		ret => shift,
		waitBeforeUse => { time => time, timeout => shift }
	);
	$args{giveup}{time} = time;
	$args{giveup}{timeout} = $timeout{ai_skill_use_giveup}{timeout};

	if ($args{y} ne "") {
		$args{x} = $args{target};
		delete $args{target};
	}
	AI::queue("skill_use", \%args);
}

##
# ai_skillUse2($skill, $lvl, $maxCastTime, $minCastTime, $target)
#
# Calls ai_skillUse(), resolving $target to ($x, $y) if $skillID is an
# area skill.
#
# FIXME: All code of the following structure:
#
# if (!ai_getSkillUseType(...)) {
#     ai_skillUse(..., $ID);
# } else {
#     ai_skillUse(..., $x, $y);
# }
#
# should be converted to use this helper function. Note that this
# function uses objects instead of IDs for the skill and target.
sub ai_skillUse2 {
	my ($skill, $lvl, $maxCastTime, $minCastTime, $target) = @_;

	if (!ai_getSkillUseType($skillID)) {
		ai_skillUse($skill->handle, $lvl, $maxCastTime, $minCastTime, $target->{ID});
	} else {
		ai_skillUse($skill->handle, $lvl, $maxCastTime, $minCastTime, $target->{pos_to}{x}, $target->{pos_to}{y});
	}
}

##
# ai_storageAutoCheck()
#
# Returns 1 if it is time to perform storageAuto sequence.
# Returns 0 otherwise.
sub ai_storageAutoCheck {
	for (my $i = 0; $i < @{$char->{inventory}}; $i++) {
		my $slot = $char->{inventory}[$i];
		next if (!$slot || $slot->{equipped});
		my $store = $items_control{'all'}{'storage'};
		$store = $items_control{lc($slot->{name})}{'storage'} if ($items_control{lc($slot->{name})});
		my $keep = $items_control{'all'}{'keep'};
		$keep = $items_control{lc($slot->{name})}{'keep'} if ($items_control{lc($slot->{name})});
		if ($store && $slot->{amount} > $keep) {
			return 1;
		}
	}
	return 0;
}

##
# ai_waypoint(points, [whenDone, attackOnRoute])
# points: reference to an array containing waypoint information. FileParsers::parseWaypoint() creates such an array.
# whenDone: specifies what to do when the waypoint has finished. Possible values are: 'repeat' (repeat waypoint) or 'reverse' (repeat waypoint, but in opposite direction).
# attackOnRoute: 0 (or not given) if you don't want to attack anything while walking, 1 if you want to attack aggressives, and 2 if you want to attack all monsters.
#
# Initialize a waypoint.
sub ai_waypoint {
	my %args = (
		points => shift,
		index => 0,
		inc => 1,
		whenDone => shift
		attackOnRoute => shift
	);

	if ($args{whenDone} && $args{whenDone} ne "repeat" && $args{whenDone} ne "reverse") {
		error "Unknown waypoint argument: $args{whenDone}\n";
		return;
	}
	AI::queue("waypoint", \%args);
}

##
# cartGet(items)
# items: a reference to an array of indices.
#
# Get one or more items from cart.
# \@items is a list of hashes; each has must have an "index" key, and may optionally have an "amount" key.
# "index" is the index of the cart inventory item number. If "amount" is given, only the given amount of
# items will retrieved from cart.
#
# Example:
# # You want to get 5 Apples (inventory item 2) and all
# # Fly Wings (inventory item 5) from cart.
# my @items;
# push @items, {index => 2, amount => 5};
# push @items, {index => 5};
# cartGet(\@items);
sub cartGet {
	my $items = shift;
	return unless ($items && @{$items});

	my %args;
	$args{items} = $items;
	$args{timeout} = 0.15;
	AI::queue("cartGet", \%args);
}

##
# cartAdd(items)
# items: a reference to an array of hashes.
#
# Put one or more items in cart.
# \@items is a list of hashes; each has must have an "index" key, and may optionally have an "amount" key.
# "index" is the index of the inventory item number. If "amount" is given, only the given amount of items will be put in cart.
#
# Example:
# # You want to add 5 Apples (inventory item 2) and all
# # Fly Wings (inventory item 5) to cart.
# my @items;
# push @items, {index => 2, amount => 5};
# push @items, {index => 5};
# cartAdd(\@items);
sub cartAdd {
	my $items = shift;
	return unless ($items && @{$items});

	my %args;
	$args{items} = $items;
	$args{timeout} = 0.15;
	AI::queue("cartAdd", \%args);
}

##
# ai_talkNPC( (x, y | ID => number), sequence)
# x, y: the position of the NPC to talk to.
# ID: the ID of the NPC to talk to.
# sequence: A string containing the NPC talk sequences.
#
# Talks to an NPC. You can specify an NPC position, or an NPC ID.
#
# $sequence is a list of whitespace-separated commands:
# ~l
# c       : Continue
# r#      : Select option # from menu.
# n       : Stop talking to NPC.
# b       : Send the "Show shop item list" (Buy) packet.
# w#      : Wait # seconds.
# x       : Initialize conversation with NPC. Useful to perform multiple transaction with a single NPC.
# t="str" : send the text str to NPC, double quote is needed only if the string contains space 
# ~l~
#
# Example:
# # Sends "Continue", "Select option 0" to the NPC at (102, 300)
# ai_talkNPC(102, 300, "c r0");
# # Do the same thing with the NPC whose ID is 1337
# ai_talkNPC(ID => 1337, "c r0");
sub ai_talkNPC {
	my %args;
	if ($_[0] eq 'ID') {
		shift;
		$args{'nameID'} = shift;
	} else {
		$args{'pos'}{'x'} = shift;
		$args{'pos'}{'y'} = shift;
	}
	$args{'sequence'} = shift;
	$args{'sequence'} =~ s/^ +| +$//g;
	unshift @ai_seq, "NPC";
	unshift @ai_seq_args,\%args;
}

sub attack {
	my $ID = shift;
	my $priorityAttack = shift;
	my %args;
	$args{'ai_attack_giveup'}{'time'} = time;
	$args{'ai_attack_giveup'}{'timeout'} = $timeout{'ai_attack_giveup'}{'timeout'};
	$args{'ID'} = $ID;
	$args{'unstuck'}{'timeout'} = ($timeout{'ai_attack_unstuck'}{'timeout'} || 1.5);
	%{$args{'pos_to'}} = %{$monsters{$ID}{'pos_to'}};
	%{$args{'pos'}} = %{$monsters{$ID}{'pos'}};
	AI::queue("attack", \%args);

	if ($priorityAttack) {
		message "Priority Attacking: $monsters{$ID}{'name'} ($monsters{$ID}{'binID'}) [$monsters{$ID}{'nameID'}]\n";
	} else {
		message "Attacking: $monsters{$ID}{'name'} ($monsters{$ID}{'binID'}) [$monsters{$ID}{'nameID'}]\n";
	}


	$startedattack = 1;
	if ($config{"monsterCount"}) {	
		my $i = 0;
		while (exists $config{"monsterCount_mon_$i"}) {
			if (!$config{"monsterCount_mon_$i"}) {
				$i++;
				next;
			}

			if ($config{"monsterCount_mon_$i"} eq $monsters{$ID}{'name'}) {
				$monsters_killed[$i] = $monsters_killed[$i] + 1;
			}
			$i++;
		}
	}

	#Mod Start
	AUTOEQUIP: {
		my $i = 0;
		my ($Rdef,$Ldef,$Req,$Leq,$arrow,$j);
		while (exists $config{"autoSwitch_$i"}) {
			if (!$config{"autoSwitch_$i"}) {
				$i++;
				next;
			}

			if (existsInList($config{"autoSwitch_$i"}, $monsters{$ID}{'name'})) {
				message "Encounter Monster : ".$monsters{$ID}{'name'}."\n";

				$Req = findIndexString_lc(\@{$chars[$config{'char'}]{'inventory'}}, "name", $config{"autoSwitch_$i"."_rightHand"}) if ($config{"autoSwitch_$i"."_rightHand"});
				$Leq = findIndexString_lc(\@{$chars[$config{'char'}]{'inventory'}}, "name", $config{"autoSwitch_$i"."_leftHand"}) if ($config{"autoSwitch_$i"."_leftHand"});
				$arrow = findIndexString_lc(\@{$chars[$config{'char'}]{'inventory'}}, "name", $config{"autoSwitch_$i"."_arrow"}) if ($config{"autoSwitch_$i"."_arrow"});

				if ($Leq ne "" && !$chars[$config{'char'}]{'inventory'}[$Leq]{'equipped'}) { 
					$Ldef = findIndex(\@{$chars[$config{'char'}]{'inventory'}}, "equipped",32);
					sendUnequip(\$remote_socket,$chars[$config{'char'}]{'inventory'}[$Ldef]{'index'}) if($Ldef ne "");
					message "Auto Equiping [L] :".$config{"autoSwitch_$i"."_leftHand"}." ($Leq)\n", "equip";
					sendEquip(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$Leq]{'index'},$chars[$config{'char'}]{'inventory'}[$Leq]{'type_equip'}); 
				}
				if ($Req ne "" && !$chars[$config{'char'}]{'inventory'}[$Req]{'equipped'} || $config{"autoSwitch_$i"."_rightHand"} eq "[NONE]") {
					$Rdef = findIndex(\@{$chars[$config{'char'}]{'inventory'}}, "equipped",34);
					$Rdef = findIndex(\@{$chars[$config{'char'}]{'inventory'}}, "equipped",2) if($Rdef eq "");
					#Debug for 2hand Quicken and Bare Hand attack with 2hand weapon
					if((!whenStatusActive("Twohand Quicken, Adrenaline, Spear Quicken") || $config{"autoSwitch_$i"."_rightHand"} eq "[NONE]") && $Rdef ne ""){
						sendUnequip(\$remote_socket,$chars[$config{'char'}]{'inventory'}[$Rdef]{'index'});
					}
					if ($Req eq $Leq) {
						for ($j=0; $j < @{$chars[$config{'char'}]{'inventory'}};$j++) {
							next if (!%{$chars[$config{'char'}]{'inventory'}[$j]});
							if ($chars[$config{'char'}]{'inventory'}[$j]{'name'} eq $config{"autoSwitch_$i"."_rightHand"} && $j != $Leq) {
								$Req = $j;
								last;
							}
						}
					}
					if ($config{"autoSwitch_$i"."_rightHand"} ne "[NONE]") {
						message "Auto Equiping [R] :".$config{"autoSwitch_$i"."_rightHand"}."($Req)\n", "equip"; 
						sendEquip(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$Req]{'index'},$chars[$config{'char'}]{'inventory'}[$Req]{'type_equip'});
					}
				}
				if ($arrow ne "" && !$chars[$config{'char'}]{'inventory'}[$arrow]{'equipped'}) { 
					message "Auto Equiping [A] :".$config{"autoSwitch_$i"."_arrow"}."\n", "equip";
					sendEquip(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$arrow]{'index'},0); 
				}
				if ($config{"autoSwitch_$i"."_distance"} && $config{"autoSwitch_$i"."_distance"} != $config{'attackDistance'}) { 
					$ai_v{'attackDistance'} = $config{'attackDistance'};
					$config{'attackDistance'} = $config{"autoSwitch_$i"."_distance"};
					message "Change Attack Distance to : ".$config{'attackDistance'}."\n", "equip";
				}
				if ($config{"autoSwitch_$i"."_useWeapon"} ne "") { 
					$ai_v{'attackUseWeapon'} = $config{'attackUseWeapon'};
					$config{'attackUseWeapon'} = $config{"autoSwitch_$i"."_useWeapon"};
					message "Change Attack useWeapon to : ".$config{'attackUseWeapon'}."\n", "equip";
				}
				last AUTOEQUIP; 
			}
			$i++;
		}
		if ($config{'autoSwitch_default_leftHand'}) { 
			$Leq = findIndexString_lc(\@{$chars[$config{'char'}]{'inventory'}}, "name", $config{'autoSwitch_default_leftHand'});
			if($Leq ne "" && !$chars[$config{'char'}]{'inventory'}[$Leq]{'equipped'}) {
				$Ldef = findIndex(\@{$chars[$config{'char'}]{'inventory'}}, "equipped",32);
				sendUnequip(\$remote_socket,$chars[$config{'char'}]{'inventory'}[$Ldef]{'index'}) if($Ldef ne "" && $chars[$config{'char'}]{'inventory'}[$Ldef]{'equipped'});
				message "Auto equiping default [L] :".$config{'autoSwitch_default_leftHand'}."\n", "equip";
				sendEquip(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$Leq]{'index'},$chars[$config{'char'}]{'inventory'}[$Leq]{'type_equip'});
			}
		}
		if ($config{'autoSwitch_default_rightHand'}) { 
			$Req = findIndexString_lc(\@{$chars[$config{'char'}]{'inventory'}}, "name", $config{'autoSwitch_default_rightHand'}); 
			if($Req ne "" && !$chars[$config{'char'}]{'inventory'}[$Req]{'equipped'}) {
				message "Auto equiping default [R] :".$config{'autoSwitch_default_rightHand'}."\n", "equip"; 
				sendEquip(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$Req]{'index'},$chars[$config{'char'}]{'inventory'}[$Req]{'type_equip'});
			}
		}
		if ($config{'autoSwitch_default_arrow'}) { 
			$arrow = findIndexString_lc(\@{$chars[$config{'char'}]{'inventory'}}, "name", $config{'autoSwitch_default_arrow'}); 
			if($arrow ne "" && !$chars[$config{'char'}]{'inventory'}[$arrow]{'equipped'}) {
				message "Auto equiping default [A] :".$config{'autoSwitch_default_arrow'}."\n", "equip"; 
				sendEquip(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$arrow]{'index'},0);
			}
		}
		if ($ai_v{'attackDistance'} && $config{'attackDistance'} != $ai_v{'attackDistance'}) { 
			$config{'attackDistance'} = $ai_v{'attackDistance'};
			message "Change Attack Distance to Default : ".$config{'attackDistance'}."\n", "equip";
		}
		if ($ai_v{'attackUseWeapon'} ne "" && $config{'attackUseWeapon'} != $ai_v{'attackUseWeapon'}) { 
			$config{'attackUseWeapon'} = $ai_v{'attackUseWeapon'};
			message "Change Attack useWeapon to default : ".$config{'attackUseWeapon'}."\n", "equip";
		}
	} #END OF BLOCK AUTOEQUIP 
}

sub aiRemove {
	my $ai_type = shift;
	my $index;
	while (1) {
		$index = binFind(\@ai_seq, $ai_type);
		if ($index ne "") {
			if ($ai_seq_args[$index]{'destroyFunction'}) {
				&{$ai_seq_args[$index]{'destroyFunction'}}(\%{$ai_seq_args[$index]});
			}
			binRemoveAndShiftByIndex(\@ai_seq, $index);
			binRemoveAndShiftByIndex(\@ai_seq_args, $index);
		} else {
			last;
		}
	}
}


sub gather {
	my $ID = shift;
	my %args;
	$args{ai_items_gather_giveup}{time} = time;
	$args{ai_items_gather_giveup}{timeout} = $timeout{ai_items_gather_giveup}{timeout};
	$args{ID} = $ID;
	$args{pos} = { %{$items{$ID}{pos}} };
	AI::queue("items_gather", \%args);
	debug "Targeting for Gather: $items{$ID}{name} ($items{$ID}{binID})\n";
}


sub look {
	my %args = (
		look_body => shift,
		look_head => shift
	);
	AI::queue("look", \%args);
}

sub move {
	my $x = shift;
	my $y = shift;
	my $attackID = shift;
	my %args;
	my $dist;
	$args{move_to}{x} = $x;
	$args{move_to}{y} = $y;
	$args{attackID} = $attackID;
	$args{time_move} = $char->{time_move};
	$dist = distance($char->{pos}, $args{move_to});
	$args{ai_move_giveup}{timeout} = $timeout{ai_move_giveup}{timeout};

	debug sprintf("Sending move from (%d,%d) to (%d,%d) - distance %.2f\n",
		$char->{pos}{x}, $char->{pos}{y}, $x, $y, $dist), "ai_move";
	AI::queue("move", \%args);
}

sub relog {
	my $timeout = (shift || 5);
	$conState = 1;
	undef $conState_tries;
	$timeout_ex{'master'}{'time'} = time;
	$timeout_ex{'master'}{'timeout'} = $timeout;
	Network::disconnect(\$remote_socket);
	message "Relogging in $timeout seconds...\n", "connection";
}

sub sit {
	$timeout{ai_sit_wait}{time} = time;
	aiRemove("standing");
	AI::queue("sitting");
}

sub stand {
	aiRemove("sitting");
	AI::queue("standing");
}

sub take {
	my $ID = shift;
	my %args;
	$args{ai_take_giveup}{time} = time;
	$args{ai_take_giveup}{timeout} = $timeout{ai_take_giveup}{timeout};
	$args{ID} = $ID;
	%{$args{pos}} = %{$items{$ID}{pos}};
	AI::queue("take", \%args);
	debug "Picking up: $items{$ID}{name} ($items{$ID}{binID})\n";
}

#######################################
#######################################
#AI MATH
#######################################
#######################################

sub lineIntersection {
	my $r_pos1 = shift;
	my $r_pos2 = shift;
	my $r_pos3 = shift;
	my $r_pos4 = shift;
	my ($x1, $x2, $x3, $x4, $y1, $y2, $y3, $y4, $result, $result1, $result2);
	$x1 = $$r_pos1{'x'};
	$y1 = $$r_pos1{'y'};
	$x2 = $$r_pos2{'x'};
	$y2 = $$r_pos2{'y'};
	$x3 = $$r_pos3{'x'};
	$y3 = $$r_pos3{'y'};
	$x4 = $$r_pos4{'x'};
	$y4 = $$r_pos4{'y'};
	$result1 = ($x4 - $x3)*($y1 - $y3) - ($y4 - $y3)*($x1 - $x3);
	$result2 = ($y4 - $y3)*($x2 - $x1) - ($x4 - $x3)*($y2 - $y1);
	if ($result2 != 0) {
		$result = $result1 / $result2;
	}
	return $result;
}

sub percent_hp {
	my $r_hash = shift;
	if (!$$r_hash{'hp_max'}) {
		return 0;
	} else {
		return ($$r_hash{'hp'} / $$r_hash{'hp_max'} * 100);
	}
}

sub percent_sp {
	my $r_hash = shift;
	if (!$$r_hash{'sp_max'}) {
		return 0;
	} else {
		return ($$r_hash{'sp'} / $$r_hash{'sp_max'} * 100);
	}
}

sub percent_weight {
	my $r_hash = shift;
	if (!$$r_hash{'weight_max'}) {
		return 0;
	} else {
		return ($$r_hash{'weight'} / $$r_hash{'weight_max'} * 100);
	}
}


#######################################
#######################################
#FILE PARSING AND WRITING
#######################################
#######################################

sub chatLog {
	my $type = shift;
	my $message = shift;
	open CHAT, ">> $Settings::chat_file";
	print CHAT "[".getFormattedDate(int(time))."][".uc($type)."] $message";
	close CHAT;
}

sub shopLog {
	my $crud = shift;
	open SHOPLOG, ">> $Settings::shop_log_file";
	print SHOPLOG "[".getFormattedDate(int(time))."] $crud";
	close SHOPLOG;
}

sub itemLog {
	my $crud = shift;
	return if (!$config{'itemHistory'});
	open ITEMLOG, ">> $Settings::item_log_file";
	print ITEMLOG "[".getFormattedDate(int(time))."] $crud";
	close ITEMLOG;
}

sub monsterLog {
	my $crud = shift;
	return if (!$config{'monsterLog'});
	open MONLOG, ">> $Settings::monster_log";
	print MONLOG "[".getFormattedDate(int(time))."] $crud\n";
	close MONLOG;
}

sub chatLog_clear { 
	if (-f $Settings::chat_file) { unlink($Settings::chat_file); } 
}

sub itemLog_clear { 
	if (-f $Settings::item_log_file) { unlink($Settings::item_log_file); } 
}

sub convertGatField {
	my $file = shift;
	my $r_hash = shift;
	my $i;
	open FILE, "+> $file";
	binmode(FILE);
	print FILE pack("S*", $$r_hash{'width'}, $$r_hash{'height'});
	print FILE $$r_hash{'rawMap'};
	close FILE;
}

sub dumpData {
	my $msg = shift;
	my $dump;
	my $puncations = quotemeta '~!@#$%^&*()_+|\"\'';

	$dump = "\n\n================================================\n" .
		getFormattedDate(int(time)) . "\n\n" . 
		length($msg) . " bytes\n\n";

	for (my $i = 0; $i < length($msg); $i += 16) {
		my $line;
		my $data = substr($msg, $i, 16);
		my $rawData = '';

		for (my $j = 0; $j < length($data); $j++) {
			my $char = substr($data, $j, 1);

			if (($char =~ /\W/ && $char =~ /\S/ && !($char =~ /[$puncations]/))
			    || ($char eq chr(10) || $char eq chr(13) || $char eq "\t")) {
				$rawData .= '.';
			} else {
				$rawData .= substr($data, $j, 1);
			}
		}

		$line = getHex(substr($data, 0, 8));
		$line .= '    ' . getHex(substr($data, 8)) if (length($data) > 8);

		$line .= ' ' x (50 - length($line)) if (length($line) < 54);
		$line .= "    $rawData\n";
		$line = sprintf("%3d>  ", $i) . $line;
		$dump .= $line;
	}

	open DUMP, ">> DUMP.txt";
	print DUMP $dump;
	close DUMP;
 
	debug "$dump\n", "parseMsg", 2;
	message "Message Dumped into DUMP.txt!\n", undef, 1;
}

##
# getField(file, r_field)
# file: the filename of the .fld file you want to load.
# r_field: reference to a hash, in which information about the field is stored.
# Returns: 1 on success, 0 on failure.
#
# Load a field (.fld) file. This function also loads an associated .dist file
# (the distance map file), which is used by pathfinding (for wall avoidance support).
# If the associated .dist file does not exist, it will be created.
#
# The r_field hash will contain the following keys:
# ~l
# - name: The name of the field, which is basically the base name of the file without the extension.
# - width: The field's width.
# - height: The field's height.
# - rawMap: The raw map data. Contains information about which blocks you can walk on (byte 0),
#    and which not (byte 1).
# - dstMap: The distance map data. Used by pathfinding.
# ~l~
sub getField {
	my $file = shift;
	my $r_hash = shift;
	my $dist_file = $file;

	undef %{$r_hash};
	unless (-e $file) {
		my %aliases = (
			'new_1-1.fld' => 'new_zone01.fld',
			'new_2-1.fld' => 'new_zone01.fld',
			'new_3-1.fld' => 'new_zone01.fld',
			'new_4-1.fld' => 'new_zone01.fld',
			'new_5-1.fld' => 'new_zone01.fld',

			'new_1-2.fld' => 'new_zone02.fld',
			'new_2-2.fld' => 'new_zone02.fld',
			'new_3-2.fld' => 'new_zone02.fld',
			'new_4-2.fld' => 'new_zone02.fld',
			'new_5-2.fld' => 'new_zone02.fld',

			'new_1-3.fld' => 'new_zone03.fld',
			'new_2-3.fld' => 'new_zone03.fld',
			'new_3-3.fld' => 'new_zone03.fld',
			'new_4-3.fld' => 'new_zone03.fld',
			'new_5-3.fld' => 'new_zone03.fld',

			'new_1-4.fld' => 'new_zone04.fld',
			'new_2-4.fld' => 'new_zone04.fld',
			'new_3-4.fld' => 'new_zone04.fld',
			'new_4-4.fld' => 'new_zone04.fld',
			'new_5-4.fld' => 'new_zone04.fld',
		);

		my ($dir, $base) = $file =~ /^(.*[\\\/])?(.*)$/;
		if (exists $aliases{$base}) {
			$file = "${dir}$aliases{$base}";
			$dist_file = $file;
		}

		if (! -e $file) {
			warning "Could not load field $file - you must install the kore-field pack!\n";
			return 0;
		}
	}

	$dist_file =~ s/\.fld$/.dist/i;

	# Load the .fld file
	$r_hash->{name} = $file;
	$r_hash->{name} =~ s/.*[\\\/]//;
	$r_hash->{name} =~ s/(.*)\..*/$1/;

	open FILE, "<", $file;
	binmode(FILE);
	my $data;
	{
		local($/);
		$data = <FILE>;
		close FILE;
		@$r_hash{'width', 'height'} = unpack("S1 S1", substr($data, 0, 4, ''));
		$$r_hash{'rawMap'} = $data;
	}

	# Load the associated .dist file (distance map)
	if (-e $dist_file) {
		open FILE, "< $dist_file";
		binmode(FILE);
		my $dist_data;

		{
			local($/);
			$dist_data = <FILE>;
		}
		close FILE;
		my $dversion = 0;
		if (substr($dist_data, 0, 2) eq "V#") {
			$dversion = unpack("xx S1", substr($dist_data, 0, 4, ''));
		}

		my ($dw, $dh) = unpack("S1 S1", substr($dist_data, 0, 4, ''));
		if (
			#version 0 files had a bug when height != width
			#version 1 files did not treat walkable water as walkable, all version 0 and 1 maps need to be rebuilt
			#version 2 and greater have no know bugs, so just do a minimum validity check.
			$dversion >= 2 && $$r_hash{'width'} == $dw && $$r_hash{'height'} == $dh
		) {
			$$r_hash{'dstMap'} = $dist_data;
		}
	}

	# The .dist file is not available; create it
	unless ($$r_hash{'dstMap'}) {
		$$r_hash{'dstMap'} = makeDistMap(@$r_hash{'rawMap', 'width', 'height'});
		open FILE, "> $dist_file" or die "Could not write dist cache file: $!\n";
		binmode(FILE);
		print FILE pack("a2 S1", 'V#', 2);
		print FILE pack("S1 S1", @$r_hash{'width', 'height'});
		print FILE $$r_hash{'dstMap'};
		close FILE;
	}

	return 1;
}

sub getGatField {
	my $file = shift;
	my $r_hash = shift;
	my $i, $data;
	undef %{$r_hash};
	($$r_hash{'name'}) = $file =~ /([\s\S]*)\./;
	open FILE, $file;
	binmode(FILE);
	read(FILE, $data, 16);
	my $width = unpack("L1", substr($data, 6,4));
	my $height = unpack("L1", substr($data, 10,4));
	$$r_hash{'width'} = $width;
	$$r_hash{'height'} = $height;
	while (read(FILE, $data, 20)) {
		$$r_hash{'rawMap'} .= substr($data, 14, 1);
		$i++;
	}
	close FILE;
}

sub updateDamageTables {
	my ($ID1, $ID2, $damage) = @_;
	if ($ID1 eq $accountID) {
		if ($monsters{$ID2}) {
			# You attack monster
			$monsters{$ID2}{'dmgTo'} += $damage;
			$monsters{$ID2}{'dmgFromYou'} += $damage;
			if ($damage <= ($config{missDamage} || 0)) {
				$monsters{$ID2}{'missedFromYou'}++;
				debug "Incremented missedFromYou count to $monsters{$ID2}{'missedFromYou'}\n", "attackMonMiss";
				$monsters{$ID2}{'atkMiss'}++;
			} else {
				$monsters{$ID2}{'atkMiss'} = 0;
			}
			 if ($config{'teleportAuto_atkMiss'} && $monsters{$ID2}{'atkMiss'} >= $config{'teleportAuto_atkMiss'}) {
				message "Teleporting because of attack miss\n", "teleport";
				useTeleport(1);
			}
		}
	} elsif ($ID2 eq $accountID) {
		if ($monsters{$ID1}) {
			# Monster attacks you
			$monsters{$ID1}{'dmgFrom'} += $damage;
			$monsters{$ID1}{'dmgToYou'} += $damage;
			if ($damage == 0) {
				$monsters{$ID1}{'missedYou'}++;
			}
			$monsters{$ID1}{'attackedYou'}++ unless (
					scalar(keys %{$monsters{$ID1}{'dmgFromPlayer'}}) ||
					scalar(keys %{$monsters{$ID1}{'dmgToPlayer'}}) ||
					$monsters{$ID1}{'missedFromPlayer'} ||
					$monsters{$ID1}{'missedToPlayer'}
				);
			$monsters{$ID1}{target} = $ID2;

			if ($AI) {
				my $teleport = 0;
				if ($mon_control{lc($monsters{$ID1}{'name'})}{'teleport_auto'} == 2){
					message "Teleporting due to attack from $monsters{$ID1}{'name'} attack\n";
					$teleport = 1;
				} elsif ($config{'teleportAuto_deadly'} && $damage >= $chars[$config{'char'}]{'hp'} && !whenStatusActive("Hallucination")) {
					message "Next $damage dmg could kill you. Teleporting...\n";
					$teleport = 1;
				} elsif ($config{'teleportAuto_maxDmg'} && $damage >= $config{'teleportAuto_maxDmg'} && !whenStatusActive("Hallucination")) {
					message "$monsters{$ID1}{'name'} hit you for more than $config{'teleportAuto_maxDmg'} dmg. Teleporting...\n";
					$teleport = 1;
				} elsif (AI::inQueue("sitAuto") && $config{'teleportAuto_attackedWhenSitting'} && $damage > 0) {
					message "$monsters{$ID1}{'name'} attacks you while you are sitting. Teleporting...\n";
					$teleport = 1;
				}
				useTeleport(1) if ($teleport);
			}
		}

	} elsif ($monsters{$ID1}) {
		if ($players{$ID2}) {
			# Monster attacks player
			$monsters{$ID1}{'dmgFrom'} += $damage;
			$monsters{$ID1}{'dmgToPlayer'}{$ID2} += $damage;
			$players{$ID2}{'dmgFromMonster'}{$ID1} += $damage;
			if ($damage == 0) {
				$monsters{$ID1}{'missedToPlayer'}{$ID2}++;
				$players{$ID2}{'missedFromMonster'}{$ID1}++;
			}
			if (%{$chars[$config{'char'}]{'party'}} && %{$chars[$config{'char'}]{'party'}{'users'}{$ID2}}) {
				# Monster attacks party member
				$monsters{$ID1}{'dmgToParty'} += $damage;
				$monsters{$ID1}{'missedToParty'}++ if ($damage == 0);
			}
			$monsters{$ID1}{target} = $ID2;
		}
		
	} elsif ($players{$ID1}) {
		if ($monsters{$ID2}) {
			# Player attacks monster
			$monsters{$ID2}{'dmgTo'} += $damage;
			$monsters{$ID2}{'dmgFromPlayer'}{$ID1} += $damage;
			$monsters{$ID2}{'lastAttackFrom'} = $ID1;
			$players{$ID1}{'dmgToMonster'}{$ID2} += $damage;
			
			if ($damage == 0) {
				$monsters{$ID2}{'missedFromPlayer'}{$ID1}++;
				$players{$ID1}{'missedToMonster'}{$ID2}++;
			}
			if (%{$chars[$config{'char'}]{'party'}} && %{$chars[$config{'char'}]{'party'}{'users'}{$ID1}}) {
				$monsters{$ID2}{'dmgFromParty'} += $damage;
			}
		}
	}
}


#######################################
#######################################
#MISC FUNCTIONS
#######################################
#######################################

sub avoidGM_near {
	for (my $i = 0; $i < @playersID; $i++) {
		next if($playersID[$i] eq "");

		# Check whether this "GM" is on the ignore list
		# in order to prevent false matches
		my $statusGM = 1;
		my $j = 0;
		while (exists $config{"avoid_ignore_$j"}) {
			if (!$config{"avoid_ignore_$j"}) {
				$j++;
				next;
			}

			if ($players{$playersID[$i]}{'name'} eq $config{"avoid_ignore_$j"}) {
				$statusGM = 0;
				last;
			}
			$j++;
		}

		if ($statusGM && $players{$playersID[$i]}{'name'} =~ /^([a-z]?ro)?-?(Sub)?-?\[?GM\]?/i) {
			warning "GM $players{$playersID[$i]}{'name'} is nearby, disconnecting...\n";
			chatLog("k", "*** Found GM $players{$playersID[$i]}{'name'} nearby and disconnected ***\n");

			my $tmp = $config{'avoidGM_reconnect'};
			warning "Disconnect for $tmp seconds...\n";
			$timeout_ex{'master'}{'time'} = time;
			$timeout_ex{'master'}{'timeout'} = $tmp;
			Network::disconnect(\$remote_socket);
			return 1;
		}
	}
	return 0;
}

##
# avoidList_near()
# Returns: 1 if someone was detected, 0 if no one was detected.
#
# Checks if any of the surrounding players are on the avoid.txt avoid list.
# Disconnects / teleports if a player is detected.
sub avoidList_near {
	return if ($config{'avoidList_inLockOnly'} && $field{'name'} ne $config{'lockMap'});
	for (my $i = 0; $i < @playersID; $i++) {
		next if($playersID[$i] eq "");
		if (($avoid{'Players'}{lc($players{$playersID[$i]}{'name'})}{'disconnect_on_sight'} || $avoid{'ID'}{$players{$playersID[$i]}{'nameID'}}{'disconnect_on_sight'}) && !$config{'XKore'}) {
			warning "$players{$playersID[$i]}{'name'} ($players{$playersID[$i]}{'nameID'}) is nearby, disconnecting...\n";
			chatLog("k", "*** Found $players{$playersID[$i]}{'name'} ($players{$playersID[$i]}{'nameID'}) nearby and disconnected ***\n");
			warning "Disconnect for $config{'avoidList_reconnect'} seconds...\n";
			$timeout_ex{'master'}{'time'} = time;
			$timeout_ex{'master'}{'timeout'} = $config{'avoidList_reconnect'};
			Network::disconnect(\$remote_socket);
			return 1;
		}
		elsif ($avoid{'Players'}{lc($players{$playersID[$i]}{'name'})}{'teleport_on_sight'} || $avoid{'ID'}{$players{$playersID[$i]}{'nameID'}}{'teleport_on_sight'}) {
			message "Teleporting to avoid player $players{$playersID[$i]}{'name'} ($players{$playersID[$i]}{'nameID'})\n", "teleport";
			chatLog("k", "*** Found $players{$playersID[$i]}{'name'} ($players{$playersID[$i]}{'nameID'}) nearby and teleported ***\n");
			useTeleport(1);
			return 1;
		}
	}
	return 0;
}

sub compilePortals {
	my $checkOnly = shift;

	my %mapPortals;
	my %mapSpawns;
	my %missingMap;
	my $pathfinding;
	my @solution;

	# Collect portal source and destination coordinates per map
	foreach my $portal (keys %portals_lut) {
		%{$mapPortals{$portals_lut{$portal}{source}{map}}{$portal}} = %{$portals_lut{$portal}{source}{pos}};
		foreach my $dest (keys %{$portals_lut{$portal}{dest}}) {
			next if $portals_lut{$portal}{dest}{$dest}{map} eq '';
			%{$mapSpawns{$portals_lut{$portal}{dest}{$dest}{map}}{$dest}} = %{$portals_lut{$portal}{dest}{$dest}{pos}};
		}
	}

	$pathfinding = new PathFinding if (!$checkOnly);

	# Calculate LOS values from each spawn point per map to other portals on same map
	foreach my $map (sort keys %mapSpawns) {
		message "Processing map $map...\n", "system" unless $checkOnly;
		foreach my $spawn (keys %{$mapSpawns{$map}}) {
			foreach my $portal (keys %{$mapPortals{$map}}) {
				next if $spawn eq $portal;
				next if $portals_los{$spawn}{$portal} ne '';
				return 1 if $checkOnly;
				if ($field{name} ne $map && !$missingMap{$map}) {
					$missingMap{$map} = 1 if (!getField("$Settings::def_field/$map.fld", \%field));
				}

				my %start = %{$mapSpawns{$map}{$spawn}};
				my %dest = %{$mapPortals{$map}{$portal}};
				closestWalkableSpot(\%field, \%start);
				closestWalkableSpot(\%field, \%dest);
				
				$pathfinding->reset(
					start => \%start,
					dest => \%dest,
					field => \%field
					);
				my $count = $pathfinding->runcount;
				$portals_los{$spawn}{$portal} = ($count >= 0) ? $count : 0;
				debug "LOS in $map from $start{x},$start{y} to $dest{x},$dest{y}: $portals_los{$spawn}{$portal}\n";
			}
		}
	}
	return 0 if $checkOnly;

	# Write new portalsLOS.txt
	writePortalsLOS("$Settings::tables_folder/portalsLOS.txt", \%portals_los);
	message "Wrote portals Line of Sight table to '$Settings::tables_folder/portalsLOS.txt'\n", "system";

	# Print warning for missing fields
	if (%missingMap) {
		warning "----------------------------Error Summary----------------------------\n";
		warning "Missing: $_.fld\n" foreach (sort keys %missingMap);
		warning "Note: LOS information for the above listed map(s) will be inaccurate;\n";
		warning "      however it is safe to ignore if those map(s) are not used\n";
		warning "----------------------------Error Summary----------------------------\n";
	}
}

sub compilePortals_check {
	return compilePortals(1);
}

##
# lookAtPosition(pos, [headdir])
# pos: a reference to a coordinate hash.
# headdir: 0 = face directly, 1 = look right, 2 = look left
#
# Turn face and body direction to position %pos.
sub lookAtPosition {
	my $pos2 = shift;
	my $headdir = shift;
	my %vec;
	my $direction;

	getVector(\%vec, $pos2, $char->{pos_to});
	$direction = int(sprintf("%.0f", (360 - vectorToDegree(\%vec)) / 45)) % 8;
	look($direction, $headdir);
}

sub portalExists {
	my ($map, $r_pos) = @_;
	foreach (keys %portals_lut) {
		if ($portals_lut{$_}{'source'}{'map'} eq $map
		 && $portals_lut{$_}{'source'}{'pos'}{'x'} == $$r_pos{'x'}
		 && $portals_lut{$_}{'source'}{'pos'}{'y'} == $$r_pos{'y'}) {
			return $_;
		}
	}
	return 0;
}

sub redirectXKoreMessages {
	my ($type, $domain, $level, $globalVerbosity, $message, $user_data) = @_;

	return if ($config{'XKore_silent'} || $type eq "debug" || $level > 0 || $conState != 5 || $XKore_dontRedirect);
	return if ($domain =~ /^(connection|startup|pm|publicchat|guildchat|guildnotice|selfchat|emotion|drop|inventory|deal|storage|input)$/);
	return if ($domain =~ /^(attack|skill|list|info|partychat|npc|route)/);

	$message =~ s/\n*$//s;
	$message =~ s/\n/\\n/g;
	sendMessage(\$remote_socket, "k", $message);
}

sub calcStat {
	my $damage = shift;
	$totaldmg = $totaldmg + $damage;
}

sub monKilled {
	$monkilltime = time();
	# if someone kills it
	if (($monstarttime == 0) || ($monkilltime < $monstarttime)) { 
		$monstarttime = 0;
		$monkilltime = 0; 
	}
	$elasped = $monkilltime - $monstarttime;
	$totalelasped = $totalelasped + $elasped;
	if ($totalelasped == 0) {
		$dmgpsec = 0
	} else {
		$dmgpsec = $totaldmg / $totalelasped;
	}
}

sub getListCount {
	my ($list) = @_;
	my $i = 0;
	my @array = split / *, */, $list;
	foreach (@array) {
		s/^\s+//;
		s/\s+$//;
		s/\s+/ /g;
		next if ($_ eq "");
		$i++;
	}
	return $i;
}

sub getFromList {
	my ($list, $num) = @_;
	my $i = 0;
	my @array = split(/ *, */, $list);
	foreach (@array) {
		s/^\s+//;
		s/\s+$//;
		s/\s+/ /g;
		next if ($_ eq "");
		$i++;
		return $_ if ($i eq $num);
	}
	return undef;
}

# Resolves a player or monster ID into a hash
sub getActorHash {
	my $id = shift;
	my $r_type = shift;

	if ($id eq $accountID) {
		$$r_type = 'self' if ($r_type);
		return $char;
	} elsif (my $player = $players{$id}) {
		$$r_type = 'player' if ($r_type);
		return $player;
	} elsif (my $monster = $monsters{$id}) {
		$$r_type = 'monster' if ($r_type);
		return $monster;
	} elsif (my $item = $items{$id}) {
		$$r_type = 'item' if ($r_type);
		return $item;
	} else {
		return undef;
	}
}

# Resolves a player or monster ID into a name
sub getActorName {
	my $id = shift;
	my $hash;

	if (!$id) {
		return 'Nothing';
	} elsif ($id eq $accountID) {
		return 'You';
	} elsif (($hash = $players{$id}) && defined $hash->{binID}) {
		return "Player $hash->{name} ($hash->{binID})";
	} elsif (($hash = $monsters{$id}) && defined $hash->{binID}) {
		return "Monster $hash->{name} ($hash->{binID})";
	} elsif (($hash = $items{$id}) && defined $hash->{binID}) {
		return "Item $hash->{name} ($hash->{binID})";
	} else {
		return "Unknown #".unpack("L1", $id);
	}
}

# Resolves a pair of player/monster IDs into names
sub getActorNames {
	my ($sourceID, $targetID, $verb1, $verb2) = @_;

	my $source = getActorName($sourceID);
	my $verb = $source eq 'You' ? $verb1 : $verb2;
	my $target;

	if ($targetID eq $sourceID) {
		if ($targetID eq $accountID) {
			$target = 'yourself';
		} else {
			$target = 'self';
		}
	} else {
		$target = getActorName($targetID);
	}

	return ($source, $verb, $target);
}

##
# useTeleport(level)
# level: 1 to teleport to a random spot, 2 to respawn.
sub useTeleport {
	my $level = shift;

	return if ($char->{muted});
	if ($char->{skills}{AL_TELEPORT} &&
	    $char->{skills}{AL_TELEPORT}{lv} > 0) {
		# We have the teleport skill
		my $skill = new Skills(handle => 'AL_TELEPORT');
		if ($config{teleportAuto_useSP} == 1 || 
		    ($config{teleportAuto_useSP} == 2 && binSize(\@playersID))) {
			# Send skill use packet to appear legitimate
			sendSkillUse(\$remote_socket, $skill->id, $level, $accountID);
		}
		if ($level == 1) {
			sendTeleport(\$remote_socket, "Random");
			return 1;
		} elsif ($level == 2 && $config{saveMap} ne "") {
			sendTeleport(\$remote_socket, $config{'saveMap'}.".gat");
			return 1;
			# If saveMap is not set, attempt to use Butterfly Wing
		}
	}

	my $invIndex = findIndex($char->{inventory}, "nameID", $level + 600);
	if (defined $invIndex) {
		# We have Fly Wing/Butterfly Wing.
		# Don't spam the "use fly wing" packet, or we'll end up using too many wings.
		if (timeOut($timeout{ai_teleport})) {
			sendItemUse(\$remote_socket, $char->{inventory}[$invIndex]{index}, $accountID);
			sendTeleport(\$remote_socket, "Random") if ($level == 1);
			$timeout{ai_teleport}{time} = time;
		}
		return 1;
	}

	# No skill and no wings; try to equip a Tele clip or something, if equipAuto_#_onTeleport is set
	my $i = 0;
	while (exists $config{"equipAuto_$i"}) {
		if (!$config{"equipAuto_$i"}) {
			$i++;
			next;
		}

		if ($config{"equipAuto_${i}_onTeleport"}) {
			# it is safe to always set this value, because $ai_v{temp} is always cleared after teleport
			if (!$ai_v{temp}{teleport}{lv}) {
				$ai_v{temp}{teleport}{lv} = $level;

				# set a small timeout, will be overridden if related config in equipAuto is set
				$ai_v{temp}{teleport}{ai_equipAuto_skilluse_giveup}{time} = time;
				$ai_v{temp}{teleport}{ai_equipAuto_skilluse_giveup}{timeout} = 5;
				return 1;

			} elsif (defined $ai_v{temp}{teleport}{ai_equipAuto_skilluse_giveup} && timeOut($ai_v{temp}{teleport}{ai_equipAuto_skilluse_giveup})) {
				message "You don't have wing or skill to teleport/respawn or timeout elapsed\n", "teleport";
				delete $ai_v{temp}{teleport};
				return 0;

			} else {
				# Waiting for item to equip
				return 1;
			}
		}
		$i++;
	}

	if ($level == 1) {
		message "You don't have the Teleport skill or a Fly Wing\n", "teleport";
	} else {
		message "You don't have the Teleport skill or a Butterfly Wing\n", "teleport";
	}
	return 0;
}

# Keep track of when we last cast a skill
sub setSkillUseTimer {
	my ($skillID, $targetID, $wait) = @_;
	my $skill = new Skills(id => $skillID);
	my $handle = $skill->handle;

	$char->{skills}{$handle}{time_used} = time;
	delete $char->{time_cast};
	delete $char->{cast_cancelled};
	$char->{last_skill_time} = time;
	$char->{last_skill_used} = $skillID;
	$char->{last_skill_target} = $targetID;

	# set partySkill target_time
	my $i = $targetTimeout{$targetID}{$skill->handle};
	$ai_v{"partySkill_${i}_target_time"}{$targetID} = time if $i;

	# increment monsterSkill maxUses counter
	if ($monsters{$targetID}) {
		$monsters{$targetID}{skillUses}{$skill->handle}++;
	}
}

# Increment counter for monster being casted on
sub countCastOn {
	my ($sourceID, $targetID, $skillID, $x, $y) = @_;
	return unless defined $targetID;

	if ($monsters{$sourceID}) {
		if ($targetID eq $accountID) {
			$monsters{$sourceID}{'castOnToYou'}++;
		} elsif (%{$players{$targetID}}) {
			$monsters{$sourceID}{'castOnToPlayer'}{$targetID}++;
		} elsif (%{$monsters{$targetID}}) {
			$monsters{$sourceID}{'castOnToMonster'}{$targetID}++;
		}
	}

	if ($monsters{$targetID}) {
		if ($sourceID eq $accountID) {
			$monsters{$targetID}{'castOnByYou'}++;
		} elsif (%{$players{$sourceID}}) {
			$monsters{$targetID}{'castOnByPlayer'}{$sourceID}++;
		} elsif (%{$monsters{$sourceID}}) {
			$monsters{$targetID}{'castOnByMonster'}{$sourceID}++;
		}
	}
}

# return ID based on name if party member is online
sub findPartyUserID {
	if (%{$chars[$config{'char'}]{'party'}}) {
		my $partyUserName = shift; 
		for (my $j = 0; $j < @partyUsersID; $j++) {
	        	next if ($partyUsersID[$j] eq "");
			if ($partyUserName eq $chars[$config{'char'}]{'party'}{'users'}{$partyUsersID[$j]}{'name'}
				&& $chars[$config{'char'}]{'party'}{'users'}{$partyUsersID[$j]}{'online'}) {
				return $partyUsersID[$j];
			}
		}
	}

	return undef;
}

# fill in a hash of NPC information either base on ID or location ("map x y")
sub getNPCInfo {
	my $id = shift;
	my $return_hash = shift;

	undef %{$return_hash};
	
	if ($id =~ /^\d+$/) {
		if (%{$npcs_lut{$id}}) {
			$$return_hash{id} = $id;
			$$return_hash{map} = $npcs_lut{$id}{map};
			$$return_hash{pos}{x} = $npcs_lut{$id}{pos}{x};
			$$return_hash{pos}{y} = $npcs_lut{$id}{pos}{y};		
		}
	}
	else {
		my ($map, $x, $y) = split(/ +/, $id, 3);
		
		$$return_hash{map} = $map;
		$$return_hash{pos}{x} = $x;
		$$return_hash{pos}{y} = $y;
	}
	
	if (defined($$return_hash{map}) && defined($$return_hash{pos}{x}) && defined($$return_hash{pos}{y})) {
		$$return_hash{ok} = 1;
	} else {
		error "Incomplete NPC info or ID not found in npcs.txt\n";
	}
}

# Resolve the name of a skill
sub skillName {
	my $skillID = shift;

	return $skillsID_lut{$skillID} || "Unknown $skillID";
}

# Resolve the name of a card
sub cardName {
	my $cardID = shift;

	# If card name is unknown, just return ?number
	my $card = $items_lut{$cardID};
	return "?$cardID" if !$card;
	$card =~ s/ Card$//;
	return $card;
}

# Resolve the name of a simple item
sub itemNameSimple {
	my $ID = shift;
	return 'None' unless $ID;
	return $items_lut{$ID} || "Unknown $ID";
}

##
# itemName($item)
#
# Resolve the name of an item. $item should be a hash with these keys:
# nameID  => integer index into %items_lut
# cards   => 8-byte binary data as sent by server
# upgrade => integer upgrade level
sub itemName {
	my $item = shift;

	my $name = itemNameSimple($item->{nameID});

	# Resolve item prefix/suffix (carded or forged)
	my $prefix = "";
	my $suffix = "";
	my @cards;
	my %cards;
	for (my $i = 0; $i < 4; $i++) {
		my $card = unpack("S1", substr($item->{cards}, $i*2, 2));
		last unless $card;
		push(@cards, $card);
		($cards{$card} ||= 0) += 1;
	}
	if ($cards[0] == 254) {
		# Alchemist-made potion
		#
		# Ignore the "cards" inside.
	} elsif ($cards[0] == 255) {
		# Forged weapon
		#
		# Display e.g. "VVS Earth" or "Fire"
		my $elementID = $cards[1] % 10;
		my $elementName = $elements_lut{$elementID};
		my $starCrumbs = ($cards[1] >> 8) / 5;
		$prefix .= ('V'x$starCrumbs)."S " if $starCrumbs;
		$prefix .= "$elementName ";
	} elsif (@cards) {
		# Carded item
		#
		# List cards in alphabetical order.
		# Stack identical cards.
		# e.g. "Hydra*2,Mummy*2", "Hydra*3,Mummy"
		$suffix = join(',', map { 
			cardName($_).($cards{$_} > 1 ? "*$cards{$_}" : '')
		} sort { cardName($a) cmp cardName($b) } keys %cards);
	}

	my $numSlots = $itemSlotCount_lut{$item->{nameID}} if ($prefix eq "");

	my $display = "";
	$display .= "+$item->{upgrade} " if $item->{upgrade};
	$display .= $prefix if $prefix;
	$display .= $name;
	$display .= " [$suffix]" if $suffix;
	$display .= " [$numSlots]" if $numSlots;

	return $display;
}

sub checkSelfCondition {
	$prefix = shift;

	return 0 if ($config{$prefix . "_disabled"} > 0);

	return 0 if $config{$prefix."_whenIdle"} && !AI::isIdle;

	if ($config{$prefix . "_hp"}) { 
		return 0 unless (inRange(percent_hp(\%{$chars[$config{char}]}), $config{$prefix . "_hp"}));
	} elsif ($config{$prefix . "_hp_upper"}) { # backward compatibility with old config format
		return 0 unless (percent_hp(\%{$chars[$config{char}]}) <= $config{$prefix . "_hp_upper"} && percent_hp(\%{$chars[$config{char}]}) >= $config{$prefix . "_hp_lower"});
	}

	if ($config{$prefix . "_sp"}) { 
		return 0 unless (inRange(percent_sp(\%{$chars[$config{char}]}), $config{$prefix . "_sp"}));
	} elsif ($config{$prefix . "_sp_upper"}) { # backward compatibility with old config format
		return 0 unless (percent_sp(\%{$chars[$config{char}]}) <= $config{$prefix . "_sp_upper"} && percent_sp(\%{$chars[$config{char}]}) >= $config{$prefix . "_sp_lower"});
	}

	# check skill use SP if this is a 'use skill' condition
	if ($prefix =~ /skill/i) {
		return 0 unless ($char->{sp} >= $skillsSP_lut{$skills_rlut{lc($config{$prefix})}}{$config{$prefix . "_lvl"}})
	}

	if ($config{$prefix . "_aggressives"}) {
		return 0 unless (inRange(scalar ai_getAggressives(), $config{$prefix . "_aggressives"}));
	} elsif ($config{$prefix . "_maxAggressives"}) { # backward compatibility with old config format
		return 0 unless ($config{$prefix . "_minAggressives"} <= ai_getAggressives());
		return 0 unless ($config{$prefix . "_maxAggressives"} >= ai_getAggressives());
	}

	if ($config{$prefix . "_partyAggressives"}) {
		return 0 unless (inRange(scalar ai_getAggressives(undef, 1), $config{$prefix . "_partyAggressives"}));
	}

	if ($config{$prefix . "_stopWhenHit"} > 0) { return 0 if (scalar ai_getAggressives()); }

	if ($config{$prefix . "_whenFollowing"} && $config{follow}) {
		return 0 if (!checkFollowMode());
	}

	if ($config{$prefix . "_whenStatusActive"}) { return 0 unless (whenStatusActive($config{$prefix . "_whenStatusActive"})); }
	if ($config{$prefix . "_whenStatusInactive"}) { return 0 if (whenStatusActive($config{$prefix . "_whenStatusInactive"})); }

	if ($config{$prefix . "_onAction"}) { return 0 unless (existsInList($config{$prefix . "_onAction"}, AI::action)); }
	if ($config{$prefix . "_spirit"}) {return 0 unless (inRange($chars[$config{char}]{spirits}, $config{$prefix . "_spirit"})); }

	if ($config{$prefix . "_timeout"}) { return 0 unless timeOut($ai_v{$prefix . "_time"}, $config{$prefix . "_timeout"}) }
	if ($config{$prefix . "_inLockOnly"} > 0) { return 0 unless ($field{name} eq $config{lockMap}); }
	if ($config{$prefix . "_notWhileSitting"} > 0) { return 0 if ($chars[$config{char}]{'sitting'}); }
	if ($config{$prefix . "_notInTown"} > 0) { return 0 if ($cities_lut{$field{name}.'.rsw'}); }

	if ($config{$prefix . "_monsters"} && !($prefix =~ /skillSlot/i)) {
		my $exists;
		foreach (ai_getAggressives()) {
			if (existsInList($config{$prefix . "_monsters"}, $monsters{$_}{name})) {
				$exists = 1;
				last;
			}
		}
		return 0 unless $exists;
	}

	if ($config{$prefix . "_defendMonsters"} && !($prefix =~ /skillSlot/i)) {
		my $exists;
		foreach (ai_getMonstersAttacking($accountID)) {
			if (existsInList($config{$prefix . "_defendMonsters"}, $monsters{$_}{name})) {
				$exists = 1;
				last;
			}
		}
		return 0 unless $exists;
	}

	if ($config{$prefix . "_notMonsters"} && !($prefix =~ /skillSlot/i)) {
		my $exists;
		foreach (ai_getAggressives()) {
			if (existsInList($config{$prefix . "_notMonsters"}, $monsters{$_}{name})) {
				return 0;
			}
		}
	}

	if ($config{$prefix . "_inInventory_name"}) {
		my @arrN = split / *, */, $config{$prefix . "_inInventory_name"};
		my @arrQ = split / *, */, $config{$prefix . "_inInventory_qty"};
		my $found = 0;

		my $i = 0;
		foreach (@arrN) {
			my $index = findIndexString_lc(\@{$chars[$config{'char'}]{'inventory'}}, "name", $_);
			if ($index ne "") {
				$found = 1;
				return 0 unless inRange($chars[$config{'char'}]{'inventory'}[$index]{amount},$arrQ[$i]);
			}
			$i++;
		}
		return 0 unless $found;
	}

	if ($config{$prefix."_whenGround"}) {
		return 0 unless whenGroundStatus($char, $config{$prefix."_whenGround"});
	}
	if ($config{$prefix."_whenNotGround"}) {
		return 0 if whenGroundStatus($char, $config{$prefix."_whenNotGround"});
	}

	return 1;
}

sub checkPlayerCondition {
	$prefix = shift;
	$id = shift;

	if ($config{$prefix . "_timeout"}) { return 0 unless timeOut($ai_v{$prefix . "_time"}{$id}, $config{$prefix . "_timeout"}) }
	if ($config{$prefix . "_whenStatusActive"}) { return 0 unless (whenStatusActivePL($id, $config{$prefix . "_whenStatusActive"})); }
	if ($config{$prefix . "_whenStatusInactive"}) { return 0 if (whenStatusActivePL($id, $config{$prefix . "_whenStatusInactive"})); }
	if ($config{$prefix . "_notWhileSitting"} > 0) { return 0 if ($players{$id}{sitting}); }

	# we will have player HP info (only) if we are in the same party
	if ($chars[$config{char}]{party}{users}{$id}) {
		if ($config{$prefix . "_hp"}) { 
			return 0 unless (inRange(percent_hp(\%{$chars[$config{char}]{party}{users}{$id}}), $config{$prefix . "_hp"}));
		} elsif ($config{$prefix . "Hp_upper"}) { # backward compatibility with old config format
			return 0 unless (percent_hp(\%{$chars[$config{char}]{party}{users}{$id}}) <= $config{$prefix . "Hp_upper"});
			return 0 unless (percent_hp(\%{$chars[$config{char}]{party}{users}{$id}}) >= $config{$prefix . "Hp_lower"});
		}
	}

	# check player job class
	if ($config{$prefix . "_isJob"}) { return 0 unless (existsInList($config{$prefix . "_isJob"}, $jobs_lut{$players{$id}{jobID}})); }
	if ($config{$prefix . "_isNotJob"}) { return 0 if (existsInList($config{$prefix . "_isNotJob"}, $jobs_lut{$players{$id}{jobID}})); }

	if ($config{$prefix . "_aggressives"}) {
		return 0 unless (inRange(scalar ai_getPlayerAggressives($id), $config{$prefix . "_aggressives"}));
	} elsif ($config{$prefix . "_maxAggressives"}) { # backward compatibility with old config format
		return 0 unless ($config{$prefix . "_minAggressives"} <= ai_getPlayerAggressives($id));
		return 0 unless ($config{$prefix . "_maxAggressives"} >= ai_getPlayerAggressives($id));
	}

	if ($config{$prefix . "_defendMonsters"}) {
		my $exists;
		foreach (ai_getMonstersAttacking($id)) {
			if (existsInList($config{$prefix . "_defendMonsters"}, $monsters{$_}{name})) {
				$exists = 1;
				last;
			}
		}
		return 0 unless $exists;
	}

	if ($config{$prefix . "_monsters"}) {
		my $exists;
		foreach (ai_getPlayerAggressives($id)) {
			if (existsInList($config{$prefix . "_monsters"}, $monsters{$_}{name})) {
				$exists = 1;
				last;
			}
		}
		return 0 unless $exists;
	}

	if ($config{$prefix."_whenGround"}) {
		return 0 unless whenGroundStatus($players{$id}, $config{$prefix."_whenGround"});
	}
	if ($config{$prefix."_whenNotGround"}) {
		return 0 if whenGroundStatus($players{$id}, $config{$prefix."_whenNotGround"});
	}
	
	return 1;
}

sub checkMonsterCondition {
	my ($prefix, $monster) = @_;

	if ($config{$prefix . "_timeout"}) { return 0 unless timeOut($ai_v{$prefix . "_time"}{$monster->{ID}}, $config{$prefix . "_timeout"}) }

	if (my $misses = $config{$prefix . "_misses"}) {
		return 0 unless inRange($monster->{atkMiss}, $misses);
	}

	if (my $misses = $config{$prefix . "_totalMisses"}) {
		return 0 unless inRange($monster->{missedFromYou}, $misses);
	}

	if ($config{$prefix . "_whenStatusActive"}) {
		return 0 unless (whenStatusActiveMon($monster, $config{$prefix . "_whenStatusActive"}));
	}
	if ($config{$prefix . "_whenStatusInactive"}) {
		return 0 if (whenStatusActiveMon($monster, $config{$prefix . "_whenStatusInactive"}));
	}

	if ($config{$prefix."_whenGround"}) {
		return 0 unless whenGroundStatus($monster, $config{$prefix."_whenGround"});
	}
	if ($config{$prefix."_whenNotGround"}) {
		return 0 if whenGroundStatus($monster, $config{$prefix."_whenNotGround"});
	}
	
	return 1;
}

##
# findCartItemInit()
#
# Resets all "found" flags in the cart to 0.
sub findCartItemInit {
	for (@{$cart{inventory}}) {
		next unless %{$_};
		undef $_->{found};
	}
}

##
# findCartItem($name [, $found [, $nounid]])
#
# Returns the integer index into $cart{inventory} for the cart item matching
# the given name, or undef.
#
# If an item is found, the "found" value for that item is set to 1. Items
# cannot be found again until you reset the "found" flags using
# findCartItemInit(), if $found is true.
#
# Unidentified items will not be returned if $nounid is true.
sub findCartItem {
	my ($name, $found, $nounid) = @_;

	$name = lc($name);
	my $index = 0;
	for (@{$cart{inventory}}) {
		if (lc($_->{name}) eq $name &&
		    !($found && $_->{found}) &&
			!($nounid && !$_->{identified})) {
			$_->{found} = 1;
			return $index;
		}
		$index++;
	}
	return undef;
}

##
# makeShop()
#
# Returns an array of items to sell. The array can be no larger than the
# maximum number of items that the character can vend. Each item is a hash
# reference containing the keys "index", "amount" and "price".
#
# If there is a problem with opening a shop, an error message will be printed
# and nothing will be returned.
sub makeShop {
	if ($shopstarted) {
		error "A shop has already been opened.\n";
		return;
	}

	if (!$char->{skills}{MC_VENDING}{lv}) {
		error "You don't have the Vending skill.\n";
		return;
	}

	if (!$shop{title}) {
		error "Your shop does not have a title.\n";
		return;
	}

	my @items = ();
	my $max_items = $char->{skills}{MC_VENDING}{lv} + 2;

	# Iterate through items to be sold
	findCartItemInit();
	for my $sale (@{$shop{items}}) {
		my $index = findCartItem($sale->{name}, 1, 1);
		next unless defined($index);

		# Found item to vend
		my $cart_item = $cart{inventory}[$index];
		my $amount = $cart_item->{amount};

		my %item;
		$item{name} = $cart_item->{name};
		$item{index} = $index;
		$item{price} = $sale->{price};
		$item{amount} = 
			$sale->{amount} && $sale->{amount} < $amount ?
			$sale->{amount} : $amount;
		push(@items, \%item);

		# We can't vend anymore items
		last if @items >= $max_items;
	}

	if (!@items) {
		error "There are no items to sell.\n";
		return;
	}
	return @items;
}

sub openShop {
	my @items = makeShop();
	return unless @items;
	$shop{title} = ($config{shopTitleOversize}) ? $shop{title} : substr($shop{title},0,36);
	sendOpenShop($shop{title}, \@items);
	message "Shop opened ($shop{title}) with ".@items." selling items.\n", "success";
	$shopstarted = 1;
	$shopEarned = 0;
}

sub closeShop {
	if (!$shopstarted) {
		error "A shop has not been opened.\n";
		return;
	}

	sendCloseShop();

	$shopstarted = 0;
	$timeout{'ai_shop'}{'time'} = time;
	message "Shop closed.\n";
}

return 1;
