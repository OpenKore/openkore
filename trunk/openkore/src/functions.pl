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
	my $changetime = $config{'autoConfChange_min'} + rand($config{'autoConfChange_seed'});
	return if (!$config{'autoConfChange'});
	$nextConfChangeTime = time + $changetime;
	message "Next Config Change will be in ".timeConvert($changetime).".\n", "system";
}

# Initialize variables when you start a connection to a map server
sub initConnectVars {
	initMapChangeVars();
	undef %{$chars[$config{'char'}]{'skills'}};
	undef @skillsID;
}

# Initialize variables when you change map (after a teleport or after you walked into a portal)
sub initMapChangeVars {
	@portalsID_old = @portalsID;
	%portals_old = %portals;
	%{$chars_old[$config{'char'}]{'pos_to'}} = %{$chars[$config{'char'}]{'pos_to'}};
	undef $chars[$config{'char'}]{'sitting'};
	undef $chars[$config{'char'}]{'dead'};
	undef $chars[$config{'char'}]{'warp'};
	$timeout{'play'}{'time'} = time;
	$timeout{'ai_sync'}{'time'} = time;
	$timeout{'ai_sit_idle'}{'time'} = time;
	$timeout{'ai_teleport_idle'}{'time'} = time;
	$timeout{'ai_teleport_search'}{'time'} = time;
	$timeout{'ai_teleport_safe_force'}{'time'} = time;
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
	undef @venderItemList;
	undef $venderID;
	undef @venderListsID;
	undef %venderLists;
	undef %guild;
	undef %incomingGuild;

	$shopstarted = 0;
	$timeout{'ai_shop'}{'time'} = time;
	$timeout{'ai_storageAuto'}{'time'} = time + 5;
	$timeout{'ai_buyAuto'}{'time'} = time + 5;

	aiRemove("attack");

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
}

sub initOtherVars {
	# chat response stuff
	undef $nextresptime;
	undef $nextrespPMtime;
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

	if ($conState == 1 && !($remote_socket && $remote_socket->connected()) && timeOut(\%{$timeout_ex{'master'}}) && !$conState_tries) {
		message("Connecting to Master Server...\n", "connection");
		$shopstarted = 1;
		$conState_tries++;
		undef $msg;
		Network::connectTo(\$remote_socket, $config{"master_host_$config{'master'}"}, $config{"master_port_$config{'master'}"});

		if ($config{'secureLogin'} >= 1) {
			message("Secure Login...\n", "connection");
			undef $secureLoginKey;
			#in config example
			#secureLogin_requestCode 04 02 c7 0A 94 C2 7A CC 38 9A 47 F5 54 39 7C A4 D0 39
			sendMasterCodeRequest(\$remote_socket, $config{'secureLogin_requestCode'});
		} else {
			sendMasterLogin(\$remote_socket, $config{'username'}, $config{'password'});
		}

		$timeout{'master'}{'time'} = time;

	} elsif ($conState == 1 && $config{'secureLogin'} >= 1 && $secureLoginKey ne "" && !timeOut(\%{$timeout{'master'}}) 
			  && $conState_tries) {

		message("Sending encoded password...\n", "connection");
		sendMasterSecureLogin(\$remote_socket, $config{'username'}, $config{'password'},$secureLoginKey,
						$config{'version'},$config{"master_version_$config{'master'}"},
						$config{'secureLogin'},$config{'secureLogin_account'});
		undef $secureLoginKey;

	} elsif ($conState == 1 && timeOut(\%{$timeout{'master'}}) && timeOut(\%{$timeout_ex{'master'}})) {
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

	} elsif ($conState == 2 && timeOut(\%{$timeout{'gamelogin'}}) && $config{'server'} ne "") {
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
		message("Connecting to Map Server...\n", "connection");
		$conState_tries++;
		initConnectVars();
		Network::connectTo(\$remote_socket, $map_ip, $map_port);
		sendMapLogin(\$remote_socket, $accountID, $charID, $sessionID, $accountSex2);
		$timeout_ex{'master'}{'timeout'} = $timeout{'reconnect'}{'timeout'};
		$timeout{'maplogin'}{'time'} = time;

	} elsif ($conState == 4 && timeOut(\%{$timeout{'maplogin'}})) {
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

# Misc. main loop code
sub mainLoop {
	Plugins::callHook('mainLoop_pre');

	if ($config{'autoRestart'} && time - $KoreStartTime > $config{'autoRestart'}
	 && $conState == 5 && $ai_seq[0] ne "attack" && $ai_seq[0] ne "take") {
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
		Network::disconnect(\$remote_socket);
		$conState = 1;
		undef $conState_tries;
		initRandomRestart();
	}

	# Automatically switch to a different config file after a while
	if ($config{'autoConfChange'} && $config{'autoConfChange_files'} && $conState == 5
	 && time >= $nextConfChangeTime && $ai_seq[0] ne "attack" && $ai_seq[0] ne "take") {
	 	my ($file, @files);
	 	my ($oldMasterHost, $oldMasterPort, $oldUsername, $oldChar);

		# Choose random config file
		@files = split(/ /, $config{'autoConfChange_files'});
		$file = @files[rand(@files)];
		message "Changing configuration file (from \"$Settings::config_file\" to \"$file\")...\n", "system";

		# A relogin is necessary if the host/port, username or char is different
		$oldMasterHost = $config{"master_host_$config{'master'}"};
		$oldMasterPort = $config{"master_port_$config{'master'}"};
		$oldUsername = $config{'username'};
		$oldChar = $config{'char'};

		foreach (@Settings::configFiles) {
			if ($_->{file} eq $Settings::config_file) {
				$_->{file} = $file;
				last;
			}
		}
		$Settings::config_file = $file;
		parseDataFile2($file, \%config);

		if ($oldMasterHost ne $config{"master_host_$config{'master'}"}
		 || $oldMasterPort ne $config{"master_port_$config{'master'}"}
		 || $oldUsername ne $config{'username'}
		 || $oldChar ne $config{'char'}) {
			relog();
		} else {
			aiRemove("move");
			aiRemove("route");
			aiRemove("mapRoute");
		}

		initConfChange();
	}

	# Set interface title
	my $charName = $chars[$config{'char'}]{'name'};
	$charName .= ': ' if defined $charName;
	if ($conState == 5) {
		my ($title, $basePercent, $jobPercent, $weight, $pos);

		$basePercent = sprintf("%.2f", $chars[$config{'char'}]{'exp'} / $chars[$config{'char'}]{'exp_max'} * 100) if $chars[$config{'char'}]{'exp_max'};
		$jobPercent = sprintf("%.2f", $chars[$config{'char'}]{'exp_job'} /$ chars[$config{'char'}]{'exp_job_max'} * 100) if $chars[$config{'char'}]{'exp_job_max'};
		$weight = int($chars[$config{'char'}]{'weight'} / $chars[$config{'char'}]{'weight_max'} * 100) . "%" if $chars[$config{'char'}]{'weight_max'};
		$pos = " : $chars[$config{'char'}]{'pos'}{'x'},$chars[$config{'char'}]{'pos'}{'y'} $field{'name'}" if ($chars[$config{'char'}]{'pos'} && $field{'name'});

		$title = "${charName} B$chars[$config{'char'}]{'lv'} ($basePercent%), J$chars[$config{'char'}]{'lv_job'}($jobPercent%) : w$weight${pos} - $Settings::NAME";
		$interface->title($title);

	} elsif ($conState == 1) {
		$interface->title("${charName}Not connected - $Settings::NAME");
	} else {
		$interface->title("${charName}Connecting - $Settings::NAME");
	}

	Plugins::callHook('mainLoop_post');
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
	if (!$config{'XKore'} && $conState == 2 && $waitingForInput) {
		configModify('server', $input, 1);
		$waitingForInput = 0;

	} elsif (!$config{'XKore'} && $conState == 3 && $waitingForInput) {
		configModify('char', $input, 1);
		$waitingForInput = 0;
		sendCharLogin(\$remote_socket, $config{'char'});
		$timeout{'charlogin'}{'time'} = time;

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
			$monsters{$monstersID[$arg1]}{'attackedByPlayer'} = 0;
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

		my $i = 1;
		for my $item (@articles) {
			next unless $item;
			message(swrite(
				"@< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<< @>>> @>>>>>>>z @>>>>>",
				[$i++, $item->{name}, $itemTypes_lut{$item->{type}}, $item->{quantity}, $item->{price}, $item->{sold}]),
				"list");
		}
		message(('-'x79)."\n", "list");
		message("You have earned: " . formatNumber($shopEarned) . "z.\n", "list");
	} elsif ($switch eq "as") {
		# Stop attacking monster
		my $index = binFind(\@ai_seq, "attack");
		if ($index ne "") {
			$monsters{$ai_seq_args[$index]{'ID'}}{'ignore'} = 1;
			sendAttackStop(\$remote_socket);
			message "Stopped attacking $monsters{$ai_seq_args[$index]{'ID'}}{'name'} ($monsters{$ai_seq_args[$index]{'ID'}}{'binID'})\n", "success";
			aiRemove("attack");
		}

	} elsif ($switch eq "autobuy") {
		unshift @ai_seq, "buyAuto";
		unshift @ai_seq_args, {};

	} elsif ($switch eq "autosell") {
		unshift @ai_seq, "sellAuto";
		unshift @ai_seq_args, {};

	} elsif ($switch eq "autostorage") {
		unshift @ai_seq, "storageAuto";
		unshift @ai_seq_args, {};

	} elsif ($switch eq "itemexchange") {
		unshift @ai_seq, "itemExchange";
		unshift @ai_seq_args, {};

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
		my $input =~ s/$qm//;
		my @arg = split / /, $input;
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
			"#   Title                                Owner\n",
			"list");
		for (my $i = 0; $i < @venderListsID; $i++) {
			next if ($venderListsID[$i] eq "");
			my $owner_string = ($venderListsID[$i] ne $accountID) ? $players{$venderListsID[$i]}{'name'} : $chars[$config{'char'}]{'name'};
			message(swrite(
				"@<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<<<<<<<<",
				[$i, $venderLists{$venderListsID[$i]}{'title'}, $owner_string]),
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
			if (scalar(keys %{$currentDeal{'you'}}) < 10) {
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
			undef @monsters_Killed;
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

	} elsif ($switch eq "guild") {
		($arg1) = $input =~ /^.*? (\w+)/;
		if ($arg1 eq "info") {
			message("---------- Guild Information ----------\n", "info");
			message(swrite(
				"Name    : @<<<<<<<<<<<<<<<<<<<<<<<<",	[$guild{'name'}],
				"Lv      : @<<",			[$guild{'lvl'}],
				"Exp     : @>>>>>>>>>/@<<<<<<<<<<",	[$guild{'exp'}, $guild{'next_exp'}],
				"Master  : @<<<<<<<<<<<<<<<<<<<<<<<<",	[$guild{'master'}],
				"Connect : @>>/@<<",			[$guild{'conMember'}, $guild{'maxMember'}]),
				"info");
			message("---------------------------------------\n", "info");

		} elsif ($arg1 eq "member") {
			message("------------ Guild  Member ------------\n", "list");
			message("#  Name                       Job        Lv  Title                       Online\n", "list");
			my ($i, $name, $job, $lvl, $title, $online);

			my $count = @{$guild{'member'}};
			for ($i = 0; $i < $count; $i++) {
				$name  = $guild{'member'}[$i]{'name'};
				next if ($name eq "");
				$job   = $jobs_lut{$guild{'member'}[$i]{'jobID'}};
				$lvl   = $guild{'member'}[$i]{'lvl'};
				$title = $guild{'member'}[$i]{'title'};
				$online = $guild{'member'}[$i]{'online'} ? "Yes" : "No";

				message(swrite(
					"@< @<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<< @>  @<<<<<<<<<<<<<<<<<<<<<<<<<< @<<",
					[$i, $name, $job, $lvl, $title, $online]),
					"list");
			}
			message("---------------------------------------\n", "list");

		} elsif ($arg1 eq "") {
			message	"Requesting guild information...\n" .
				"Enter command to view guild information: guild < info | member >\n", "info";
			sendGuildInfoRequest(\$remote_socket);
			sendGuildRequest(\$remote_socket, 0);
			sendGuildRequest(\$remote_socket, 1);
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
		} else {
			for (my $i = 0; $i < @playersID; $i++) {
				next if ($players{$playersID[$i]} eq "");
				lookAtPosition($players{$playersID[$i]}{'pos_to'}, int(rand(3)));
				last;
			}
		}

	} elsif ($switch eq "move") {
		($arg1, $arg2, $arg3) = $input =~ /^[\s\S]*? (\d+) (\d+)(.*?)$/;

		undef $ai_v{'temp'}{'map'};
		if ($arg1 eq "") {
			($ai_v{'temp'}{'map'}) = $input =~ /^[\s\S]*? (.*?)$/;
		} else {
			$ai_v{'temp'}{'map'} = $arg3;
		}
		$ai_v{'temp'}{'map'} =~ s/\s//g;
		if (($arg1 eq "" || $arg2 eq "") && !$ai_v{'temp'}{'map'}) {
			error	"Syntax Error in function 'move' (Move Player)\n" .
				"Usage: move <x> <y> &| <map>\n";
		} elsif ($ai_v{'temp'}{'map'} eq "stop") {
			aiRemove("move");
			aiRemove("route");
			aiRemove("mapRoute");
			message "Stopped all movement\n", "success";
		} else {
			$ai_v{'temp'}{'map'} = $field{'name'} if ($ai_v{'temp'}{'map'} eq "");
			if ($maps_lut{$ai_v{'temp'}{'map'}.'.rsw'}) {
				if ($arg2 ne "") {
					message("Calculating route to: $maps_lut{$ai_v{'temp'}{'map'}.'.rsw'}($ai_v{'temp'}{'map'}): $arg1, $arg2\n", "route");
					$ai_v{'temp'}{'x'} = $arg1;
					$ai_v{'temp'}{'y'} = $arg2;
				} else {
					message("Calculating route to: $maps_lut{$ai_v{'temp'}{'map'}.'.rsw'}($ai_v{'temp'}{'map'})\n", "route");
					undef $ai_v{'temp'}{'x'};
					undef $ai_v{'temp'}{'y'};
				}
				ai_route($ai_v{'temp'}{'map'}, $ai_v{'temp'}{'x'}, $ai_v{'temp'}{'y'},
					attackOnRoute => 1,
					noSitAuto => 1);
			} else {
				error "Map $ai_v{'temp'}{'map'} does not exist\n";
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

	} elsif ($switch eq "sit") {
		$ai_v{'attackAuto_old'} = $config{'attackAuto'};
		$ai_v{'route_randomWalk_old'} = $config{'route_randomWalk'};
		$ai_v{'teleportAuto_idle_old'} = $config{'teleportAuto_idle'};
		$ai_v{'itemsGatherAuto_old'} = $config{'itemsGatherAuto'};
		configModify("attackAuto", 1) if $config{attackAuto};
		configModify("route_randomWalk", 0);
		configModify("teleportAuto_idle", 0);
		configModify("itemsGatherAuto", 0);
		aiRemove("move");
		aiRemove("route");
		aiRemove("mapRoute");
		sit();
		$ai_v{'sitAuto_forceStop'} = 0;

	} elsif ($switch eq "sl") {
		$input =~ /^[\s\S]*? (\d+) (\d+) (\d+)(?: (\d+))?/;
		my $skill_num = $1;
		my $x = $2;
		my $y = $3;
		my $lvl = $4;
		
		if (!$skill_num || !defined($x) || !defined($y)) {
			error	"Syntax Error in function 'sl' (Use Skill on Location)\n" .
				"Usage: sl <skill #> <x> <y> [<skill lvl>]\n";
		} elsif (!$skillsID[$skill_num]) {
			error	"Error in function 'sl' (Use Skill on Location)\n" .
				"Skill $skill_num does not exist.\n";
		} else {
			my $skill = $chars[$config{'char'}]{'skills'}{$skillsID[$skill_num]};
			$lvl = $skill->{'lv'} if (!$lvl || $lvl > $skill->{'lv'});
			ai_skillUse($skillsID[$skill_num], $lvl, 0, 0, $x, $y);
		}

	} elsif ($switch eq "sm") {
		($arg1) = $input =~ /^[\s\S]*? (\d+)/;
		($arg2) = $input =~ /^[\s\S]*? \d+ (\d+)/;
		($arg3) = $input =~ /^[\s\S]*? \d+ \d+ (\d+)/;
		if ($arg1 eq "" || $arg2 eq "") {
			error	"Syntax Error in function 'sm' (Use Skill on Monster)\n" .
				"Usage: sm <skill #> <monster #> [<skill lvl>]\n";
		} elsif ($monstersID[$arg2] eq "") {
			error	"Error in function 'sm' (Use Skill on Monster)\n" .
				"Monster $arg2 does not exist.\n";	
		} elsif ($skillsID[$arg1] eq "") {
			error	"Error in function 'sm' (Use Skill on Monster)\n" .
				"Skill $arg1 does not exist.\n";
		} else {
			if (!$arg3 || $arg3 > $chars[$config{'char'}]{'skills'}{$skillsID[$arg1]}{'lv'}) {
				$arg3 = $chars[$config{'char'}]{'skills'}{$skillsID[$arg1]}{'lv'};
			}
			if (!ai_getSkillUseType($skillsID[$arg1])) {
				ai_skillUse($skillsID[$arg1], $arg3, 0,0, $monstersID[$arg2]);
			} else {
				ai_skillUse($skillsID[$arg1], $arg3, 0,0, $monsters{$monstersID[$arg2]}{'pos_to'}{'x'}, $monsters{$monstersID[$arg2]}{'pos_to'}{'y'});
			}
		}

	} elsif ($switch eq "sp") {
		($arg1) = $input =~ /^[\s\S]*? (\d+)/;
		($arg2) = $input =~ /^[\s\S]*? \d+ (\d+)/;
		($arg3) = $input =~ /^[\s\S]*? \d+ \d+ (\d+)/;
		if ($arg1 eq "" || $arg2 eq "") {
			error	"Syntax Error in function 'sp' (Use Skill on Player)\n" .
				"Usage: sp <skill #> <player #> [<skill lvl>]\n";
		} elsif ($playersID[$arg2] eq "") {
			error	"Error in function 'sp' (Use Skill on Player)\n" .
				"Player $arg2 does not exist.\n";	
		} elsif ($skillsID[$arg1] eq "") {
			error	"Error in function 'sp' (Use Skill on Player)\n" .
				"Skill $arg1 does not exist.\n";
		} else {
			if (!$arg3 || $arg3 > $chars[$config{'char'}]{'skills'}{$skillsID[$arg1]}{'lv'}) {
				$arg3 = $chars[$config{'char'}]{'skills'}{$skillsID[$arg1]}{'lv'};
			}
			if (!ai_getSkillUseType($skillsID[$arg1])) {
				ai_skillUse($skillsID[$arg1], $arg3, 0,0, $playersID[$arg2]);
			} else {
				ai_skillUse($skillsID[$arg1], $arg3, 0,0, $players{$playersID[$arg2]}{'pos_to'}{'x'}, $players{$playersID[$arg2]}{'pos_to'}{'y'});
			}
		}

	} elsif ($switch eq "ss") {
		($arg1) = $input =~ /^[\s\S]*? (\d+)/;
		($arg2) = $input =~ /^[\s\S]*? \d+ (\d+)/;
		if ($arg1 eq "") {
			error	"Syntax Error in function 'ss' (Use Skill on Self)\n" .
				"Usage: ss <skill #> [<skill lvl>]\n";
		} elsif ($skillsID[$arg1] eq "") {
			error	"Error in function 'ss' (Use Skill on Self)\n" .
				"Skill $arg1 does not exist.\n";
		} else {
			if (!$arg2 || $arg2 > $chars[$config{'char'}]{'skills'}{$skillsID[$arg1]}{'lv'}) {
				$arg2 = $chars[$config{'char'}]{'skills'}{$skillsID[$arg1]}{'lv'};
			}
			if (!ai_getSkillUseType($skillsID[$arg1])) {
				ai_skillUse($skillsID[$arg1], $arg2, 0,0, $accountID);
			} else {
				ai_skillUse($skillsID[$arg1], $arg2, 0,0, $chars[$config{'char'}]{'pos_to'}{'x'}, $chars[$config{'char'}]{'pos_to'}{'y'});
			}
		}

	} elsif ($switch eq "stand") {
		if ($ai_v{'attackAuto_old'} ne "") {
			configModify("attackAuto", $ai_v{'attackAuto_old'});
			configModify("route_randomWalk", $ai_v{'route_randomWalk_old'});
			configModify("teleportAuto_idle", $ai_v{'teleportAuto_idle_old'});
			configModify("itemsGatherAuto", $ai_v{'itemsGatherAuto_old'});
			undef $ai_v{'attackAuto_old'};
			undef $ai_v{'route_randomWalk_old'};
			undef $ai_v{'teleportAuto_idle_old'};
			undef $ai_v{'itemsGatherAuto_old'};
		}
		stand();
		$ai_v{'sitAuto_forceStop'} = 1;

	} elsif ($switch eq "storage") {
		($arg1) = $input =~ /^[\s\S]*? (\w+)/;
		($arg2) = $input =~ /^[\s\S]*? \w+ ([\d,-]+)/;
		($arg3) = $input =~ /^[\s\S]*? \w+ [\d,-]+ (\d+)/;
		if ($arg1 eq "") {
			if ($storage{opened}) {
				my $list = "----------Storage-----------\n";
				$list .= "#  Name\n";
				for (my $i = 0; $i < @storageID; $i++) {
					next if ($storageID[$i] eq "");
	
					my $display = "$storage{$storageID[$i]}{'name'}";
					$display .= " x $storage{$storageID[$i]}{'amount'}";
					$display .= " -- Not Identified" if !$storage{$storageID[$i]}{identified};

					$list .= sprintf("%2d %s\n", $i, $display);
				}
				$list .= "\nCapacity: $storage{'items'}/$storage{'items_max'}\n";
				$list .= "-------------------------------\n";
				message($list, "list");
			} else {
				warning "No information about storage; it has not been opened before in this session\n";
			}

		} elsif ($arg1 eq "add" && $arg2 =~ /\d+/ && $chars[$config{'char'}]{'inventory'}[$arg2] eq "") {
			error	"Error in function 'storage add' (Add Item to Storage)\n" .
				"Inventory Item $arg2 does not exist\n";
		} elsif ($arg1 eq "add" && $arg2 =~ /\d+/) {
			if (!$arg3 || $arg3 > $chars[$config{'char'}]{'inventory'}[$arg2]{'amount'}) {
				$arg3 = $chars[$config{'char'}]{'inventory'}[$arg2]{'amount'};
			}
			sendStorageAdd(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$arg2]{'index'}, $arg3);

		} elsif ($arg1 eq "get" && $arg2 =~ /\d+/ && $storageID[$arg2] eq "") {
			error	"Error in function 'storage get' (Get Item from Storage)\n" .
				"Storage Item $arg2 does not exist\n";
		} elsif ($arg1 eq "get" && $arg2 =~ /[\d,-]+/) {
			my @temp = split(/,/, $arg2);
			@temp = grep(!/^$/, @temp); # Remove empty entries

			my @items = ();
			foreach (@temp) {
				if (/(\d+)-(\d+)/) {
					for ($1..$2) {
						push(@items, $_) if ($storageID[$_] ne "");
					}
				} else {
					push @items, $_;
				}
			}
			ai_storageGet(\@items, $arg3);

		} elsif ($arg1 eq "close") {
			sendStorageClose(\$remote_socket);

		} else {
			error	"Syntax Error in function 'storage' (Storage Functions)\n" .
				"Usage: storage [<add | get | close>] [<inventory # | storage #>] [<amount>]\n";
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
			sendTalkCancel(\$remote_socket, $talk{'ID'});


		} else {
			error	"Syntax Error in function 'talk' (Talk to NPC)\n" .
				"Usage: talk <NPC # | cont | resp | num> [<response #>|<number #>]\n";
		}

	} elsif ($switch eq "tele") {
		useTeleport(1);

	} elsif ($switch eq "where") {
		($map_string) = $map_name =~ /([\s\S]*)\.gat/;
		message("Location $maps_lut{$map_string.'.rsw'}($map_string) : $chars[$config{'char'}]{'pos_to'}{'x'}, $chars[$config{'char'}]{'pos_to'}{'y'}\n", "info");

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


	if (timeOut(\%{$timeout{'ai_wipe_check'}})) {
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
		$timeout{'ai_wipe_check'}{'time'} = time;
		debug "Wiped old\n", "ai", 2;
	}

	if (timeOut(\%{$timeout{'ai_getInfo'}})) {
		foreach (keys %players) {
			if ($players{$_}{'name'} eq "Unknown") {
				sendGetPlayerInfo(\$remote_socket, $_);
				last;
			}
		}
		foreach (keys %monsters) {
			if ($monsters{$_}{'name'} =~ /Unknown/) {
				sendGetPlayerInfo(\$remote_socket, $_);
				last;
			}
		}
		foreach (keys %npcs) { 
			if ($npcs{$_}{'name'} =~ /Unknown/) { 
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

	if (!$config{'XKore'} && timeOut(\%{$timeout{'ai_sync'}})) {
		$timeout{'ai_sync'}{'time'} = time;
		sendSync(\$remote_socket, getTickCount());
	}

	if (timeOut($mapdrt, $config{'intervalMapDrt'})) {
		$mapdrt = time;

		$map_name =~ /([\s\S]*)\.gat/;
		if ($1) {
			open(DATA, ">$Settings::logs_folder/walk.dat");
			print DATA "$1\n";
			print DATA $chars[$config{'char'}]{'pos_to'}{'x'}."\n";
			print DATA $chars[$config{'char'}]{'pos_to'}{'y'}."\n";

			for (my $i = 0; $i < @npcsID; $i++) {
				next if ($npcsID[$i] eq "");
				print DATA "NL " . $npcs{$npcsID[$i]}{'pos'}{'x'} . " " . $npcs{$npcsID[$i]}{'pos'}{'y'} . "\n";
			}
			for (my $i = 0; $i < @playersID; $i++) {
				next if ($playersID[$i] eq "");
				print DATA "PL " . $players{$playersID[$i]}{'pos'}{'x'} . " " . $players{$playersID[$i]}{'pos'}{'y'} . "\n";
			}
			for (my $i = 0; $i < @monstersID; $i++) {
				next if ($monstersID[$i] eq "");
				print DATA "ML " . $monsters{$monstersID[$i]}{'pos'}{'x'} . " " . $monsters{$monstersID[$i]}{'pos'}{'y'} . "\n";
			}

			close(DATA);
		}
	}

	return if (!$AI);



	##### REAL AI STARTS HERE #####

	Plugins::callHook('AI_pre');

	if (!$accountID) {
		$AI = 0;
		injectAdminMessage("Please relogin to enable X-${Settings::NAME}.") if ($config{'verbose'});
		return;
	}

	if (%cmd) {
		$responseVars{'cmd_user'} = $cmd{'user'};
		if ($cmd{'user'} eq $chars[$config{'char'}]{'name'}) {
			return;
		}
 		if ($cmd{'type'} eq "pm" || $cmd{'type'} eq "p" || $cmd{'type'} eq "g") {
			$ai_v{'temp'}{'qm'} = quotemeta $config{'adminPassword'};
			if ($cmd{msg} =~ /^$ai_v{'temp'}{'qm'}\b/) {
				if ($overallAuth{$cmd{user}} == 1) {
					sendMessage(\$remote_socket, "pm", getResponse("authF"), $cmd{'user'});
				} else {
					auth($cmd{'user'}, 1);
					sendMessage(\$remote_socket, "pm", getResponse("authS"),$cmd{'user'});
				}
			}
		}

		if ($cmd{'type'} eq "c" || $cmd{'type'} eq "p" || $cmd{'type'} eq "g"){
			#check if player is in area
			if (defined($players{$cmd{ID}})) {
				my $i = 0;
				while ($config{"autoEmote_word_$i"} ne "") {
					my $chat = $cmd{msg};
					if ($chat =~/.*$config{"autoEmote_word_$i"}+$/i || $chat =~ /.*$config{"autoEmote_word_$i"}+\W/i) {
						my %args = ();
						$args{'timeout'} = time + rand (1) + 0.75;
						$args{'emotion'} = $config{"autoEmote_num_$i"};
						unshift @ai_seq, "sendEmotion";
						unshift @ai_seq_args, \%args;
						last;
					}
					$i++;
				}
			}
		}

		if ($config{"autoResponse"}) {
			if ($cmd{type} eq "pm") {
				my $i = 0;
				while ($chat_resp{"words_said_$i"} ne "") {
					my $privMsg = $cmd{msg};
					if (($privMsg =~/.*$chat_resp{"words_said_$i"}+$/i || $chat =~ /.*$chat_resp{"words_said_$i"}+\W/i) &&
						binFind(\@ai_seq, "respPMAuto") eq "") {
						$args{'resp_num'} = $i;
						$args{'resp_user'} = $privMsgUser;
						unshift @ai_seq, "respPMAuto";
						unshift @ai_seq_args, \%args;
						$nextrespPMtime = time + 5;
						last;
					}
					$i++;
				}
			} elsif (($cmd{type} eq "c" && defined($players{$cmd{ID}})) || $cmd{type} eq "p" || $cmd{type} eq "g") {
				my $i = 0;
				while ($chat_resp{"words_said_$i"} ne "") {
					my $chat = $cmd{msg};
					if (($chat =~/.*$chat_resp{"words_said_$i"}+$/i || $chat =~ /.*$chat_resp{"words_said_$i"}+\W/i)
						&& binFind(\@ai_seq, "respAuto") eq "") {
						$args{'resp_num'} = $i;
						unshift @ai_seq, "respAuto";			
						unshift @ai_seq_args, \%args;
						$nextresptime = time + 5;
						last;
					}
					$i++;
				}
			}
		}
		avoidGM_talk($cmd{user}, $cmd{msg});
		avoidList_talk($cmd{user}, $cmd{msg}, unpack("L1",$cmd{ID}));

		$ai_v{'temp'}{'qm'} = quotemeta $config{'callSign'};
		if ($overallAuth{$cmd{'user'}} >= 1 
			&& ($cmd{'msg'} =~ /\b$ai_v{'temp'}{'qm'}\b/i || $cmd{'type'} eq "pm")) {
			if ($cmd{'msg'} =~ /\bsit\b/i) {
				$ai_v{'sitAuto_forceStop'} = 0;
				$ai_v{'attackAuto_old'} = $config{'attackAuto'};
				$ai_v{'route_randomWalk_old'} = $config{'route_randomWalk'};
				configModify("attackAuto", 1) if $config{attackAuto};
				configModify("route_randomWalk", 0);
				aiRemove("move");
				aiRemove("route");
				aiRemove("mapRoute");
				sit();
				sendMessage(\$remote_socket, $cmd{'type'}, getResponse("sitS"), $cmd{'user'}) if $config{'verbose'};
				$timeout{'ai_thanks_set'}{'time'} = time;
			} elsif ($cmd{'msg'} =~ /\bstand\b/i) {
				$ai_v{'sitAuto_forceStop'} = 1;
				if ($ai_v{'attackAuto_old'} ne "") {
					configModify("attackAuto", $ai_v{'attackAuto_old'});
					configModify("route_randomWalk", $ai_v{'route_randomWalk_old'});
				}
				stand();
				sendMessage(\$remote_socket, $cmd{'type'}, getResponse("standS"), $cmd{'user'}) if $config{'verbose'};
				$timeout{'ai_thanks_set'}{'time'} = time;
			} elsif ($cmd{'msg'} =~ /\brelog\b/i) {
				relog();
				sendMessage(\$remote_socket, $cmd{'type'}, getResponse("relogS"), $cmd{'user'}) if $config{'verbose'};
				$timeout{'ai_thanks_set'}{'time'} = time;
			} elsif ($cmd{'msg'} =~ /\blogout\b/i) {
				quit();
				sendMessage(\$remote_socket, $cmd{'type'}, getResponse("quitS"), $cmd{'user'}) if $config{'verbose'};
				$timeout{'ai_thanks_set'}{'time'} = time;
			} elsif ($cmd{'msg'} =~ /\breload\b/i) {
				Settings::parseReload($');
				sendMessage(\$remote_socket, $cmd{'type'}, getResponse("reloadS"), $cmd{'user'}) if $config{'verbose'};
				$timeout{'ai_thanks_set'}{'time'} = time;
			} elsif ($cmd{'msg'} =~ /\bstatus\b/i) {
				$responseVars{'char_sp'} = $chars[$config{'char'}]{'sp'};
				$responseVars{'char_hp'} = $chars[$config{'char'}]{'hp'};
				$responseVars{'char_sp_max'} = $chars[$config{'char'}]{'sp_max'};
				$responseVars{'char_hp_max'} = $chars[$config{'char'}]{'hp_max'};
				$responseVars{'char_lv'} = $chars[$config{'char'}]{'lv'};
				$responseVars{'char_lv_job'} = $chars[$config{'char'}]{'lv_job'};
				$responseVars{'char_exp'} = $chars[$config{'char'}]{'exp'};
				$responseVars{'char_exp_max'} = $chars[$config{'char'}]{'exp_max'};
				$responseVars{'char_exp_job'} = $chars[$config{'char'}]{'exp_job'};
				$responseVars{'char_exp_job_max'} = $chars[$config{'char'}]{'exp_job_max'};
				$responseVars{'char_weight'} = $chars[$config{'char'}]{'weight'};
				$responseVars{'char_weight_max'} = $chars[$config{'char'}]{'weight_max'};
				$responseVars{'zenny'} = $chars[$config{'char'}]{'zenny'};
				sendMessage(\$remote_socket, $cmd{'type'}, getResponse("statusS"), $cmd{'user'}) if $config{'verbose'};
			} elsif ($cmd{'msg'} =~ /\bconf\b/i) {
				$ai_v{'temp'}{'after'} = $';
				($ai_v{'temp'}{'arg1'}) = $ai_v{'temp'}{'after'} =~ /^\s*(\w+)/;
				($ai_v{'temp'}{'arg2'}) = $ai_v{'temp'}{'after'} =~ /^\s*\w+\s+([\s\S]+)\s*$/;
				@{$ai_v{'temp'}{'conf'}} = keys %config;
				if ($ai_v{'temp'}{'arg1'} eq "") {
					sendMessage(\$remote_socket, $cmd{'type'}, getResponse("confF1"), $cmd{'user'}) if $config{'verbose'};
				} elsif (binFind(\@{$ai_v{'temp'}{'conf'}}, $ai_v{'temp'}{'arg1'}) eq "") {
					sendMessage(\$remote_socket, $cmd{'type'}, getResponse("confF2"), $cmd{'user'}) if $config{'verbose'};
				} elsif ($ai_v{'temp'}{'arg2'} eq "") {
					if ($ai_v{'temp'}{'arg1'} =~ /username/i || $ai_v{'temp'}{'arg1'} =~ /password/i) {
						sendMessage(\$remote_socket, $cmd{'type'}, getResponse("confF3"), $cmd{'user'}) if $config{'verbose'};
					} else {
						$responseVars{'key'} = $ai_v{'temp'}{'arg1'};
						$responseVars{'value'} = $config{$ai_v{'temp'}{'arg1'}};
						sendMessage(\$remote_socket, $cmd{'type'}, getResponse("confS1"), $cmd{'user'}) if $config{'verbose'};
						$timeout{'ai_thanks_set'}{'time'} = time;
					}
				} else {
					$ai_v{'temp'}{'arg2'} = undef if ($ai_v{'temp'}{'arg2'} eq "none");
					configModify($ai_v{'temp'}{'arg1'}, $ai_v{'temp'}{'arg2'});
					sendMessage(\$remote_socket, $cmd{'type'}, getResponse("confS2"), $cmd{'user'}) if $config{'verbose'};
					$timeout{'ai_thanks_set'}{'time'} = time;
				}
			} elsif ($cmd{'msg'} =~ /\btimeout\b/i) {
				$ai_v{'temp'}{'after'} = $';
				($ai_v{'temp'}{'arg1'}, $ai_v{'temp'}{'arg2'}) = $ai_v{'temp'}{'after'} =~ /([\s\S]+) (\w+)/;
				if ($ai_v{'temp'}{'arg1'} eq "") {
					sendMessage(\$remote_socket, $cmd{'type'}, getResponse("timeoutF1"), $cmd{'user'}) if $config{'verbose'};
				} elsif ($timeout{$ai_v{'temp'}{'arg1'}} eq "") {
					sendMessage(\$remote_socket, $cmd{'type'}, getResponse("timeoutF2"), $cmd{'user'}) if $config{'verbose'};
				} elsif ($ai_v{'temp'}{'arg2'} eq "") {
					$responseVars{'key'} = $ai_v{'temp'}{'arg1'};
					$responseVars{'value'} = $timeout{$ai_v{'temp'}{'arg1'}};
					sendMessage(\$remote_socket, $cmd{'type'}, getResponse("timeoutS1"), $cmd{'user'}) if $config{'verbose'};
					$timeout{'ai_thanks_set'}{'time'} = time;
				} else {
					setTimeout($ai_v{'temp'}{'arg1'}, $ai_v{'temp'}{'arg2'});
					sendMessage(\$remote_socket, $cmd{'type'}, getResponse("timeoutS2"), $cmd{'user'}) if $config{'verbose'};
					$timeout{'ai_thanks_set'}{'time'} = time;
				}
			} elsif ($cmd{'msg'} =~ /\bshut[\s\S]*up\b/i) {
				if ($config{'verbose'}) {
					configModify("verbose", 0);
					sendMessage(\$remote_socket, $cmd{'type'}, getResponse("verboseOffS"), $cmd{'user'});
					$timeout{'ai_thanks_set'}{'time'} = time;
				} else {
					sendMessage(\$remote_socket, $cmd{'type'}, getResponse("verboseOffF"), $cmd{'user'});
				}
			} elsif ($cmd{'msg'} =~ /\bspeak\b/i) {
				if (!$config{'verbose'}) {
					configModify("verbose", 1);
					sendMessage(\$remote_socket, $cmd{'type'}, getResponse("verboseOnS"), $cmd{'user'});
					$timeout{'ai_thanks_set'}{'time'} = time;
				} else {
					sendMessage(\$remote_socket, $cmd{'type'}, getResponse("verboseOnF"), $cmd{'user'});
				}
			} elsif ($cmd{'msg'} =~ /\bdate\b/i) {
				$responseVars{'date'} = getFormattedDate(int(time));
				sendMessage(\$remote_socket, $cmd{'type'}, getResponse("dateS"), $cmd{'user'}) if $config{'verbose'};
				$timeout{'ai_thanks_set'}{'time'} = time;
			} elsif ($cmd{'msg'} =~ /\bmove\b/i
				&& $cmd{'msg'} =~ /\bstop\b/i) {
				aiRemove("move");
				aiRemove("route");
				aiRemove("mapRoute");
				sendMessage(\$remote_socket, $cmd{'type'}, getResponse("moveS"), $cmd{'user'}) if $config{'verbose'};
				$timeout{'ai_thanks_set'}{'time'} = time;
			} elsif ($cmd{'msg'} =~ /\bmove\b/i) {
				$ai_v{'temp'}{'after'} = $';
				$ai_v{'temp'}{'after'} =~ s/^\s+//;
				$ai_v{'temp'}{'after'} =~ s/\s+$//;
				($ai_v{'temp'}{'arg1'}, $ai_v{'temp'}{'arg2'}, $ai_v{'temp'}{'arg3'}) = $ai_v{'temp'}{'after'} =~ /(\d+)\D+(\d+)(.*?)$/;
				undef $ai_v{'temp'}{'map'};
				if ($ai_v{'temp'}{'arg1'} eq "") {
					($ai_v{'temp'}{'map'}) = $ai_v{'temp'}{'after'} =~ /(.*?)$/;
				} else {
					$ai_v{'temp'}{'map'} = $ai_v{'temp'}{'arg3'};
				}
				$ai_v{'temp'}{'map'} =~ s/\s//g;
				if (($ai_v{'temp'}{'arg1'} eq "" || $ai_v{'temp'}{'arg2'} eq "") && !$ai_v{'temp'}{'map'}) {
					sendMessage(\$remote_socket, $cmd{'type'}, getResponse("moveF"), $cmd{'user'}) if $config{'verbose'};
				} else {
					$ai_v{'temp'}{'map'} = $field{'name'} if ($ai_v{'temp'}{'map'} eq "");
					if ($maps_lut{$ai_v{'temp'}{'map'}.'.rsw'}) {
						if ($ai_v{'temp'}{'arg2'} ne "") {
							message "Calculating route to: $maps_lut{$ai_v{'temp'}{'map'}.'.rsw'}($ai_v{'temp'}{'map'}): $ai_v{'temp'}{'arg1'}, $ai_v{'temp'}{'arg2'}\n", "route";
							$ai_v{'temp'}{'x'} = $ai_v{'temp'}{'arg1'};
							$ai_v{'temp'}{'y'} = $ai_v{'temp'}{'arg2'};
						} else {
							message "Calculating route to: $maps_lut{$ai_v{'temp'}{'map'}.'.rsw'}($ai_v{'temp'}{'map'})\n", "route";
							undef $ai_v{'temp'}{'x'};
							undef $ai_v{'temp'}{'y'};
						}
						sendMessage(\$remote_socket, $cmd{'type'}, getResponse("moveS"), $cmd{'user'}) if $config{'verbose'};
						ai_route($ai_v{'temp'}{'map'}, $ai_v{'temp'}{'x'}, $ai_v{'temp'}{'y'},
							attackOnRoute => 1);
						$timeout{'ai_thanks_set'}{'time'} = time;
					} else {
						error "Map $ai_v{'temp'}{'map'} does not exist\n";
						sendMessage(\$remote_socket, $cmd{'type'}, getResponse("moveF"), $cmd{'user'}) if $config{'verbose'};
					}
				}
			} elsif ($cmd{'msg'} =~ /\blook\b/i) {
				($ai_v{'temp'}{'body'}) = $cmd{'msg'} =~ /(\d+)/;
				($ai_v{'temp'}{'head'}) = $cmd{'msg'} =~ /\d+ (\d+)/;
				if ($ai_v{'temp'}{'body'} ne "") {
					look($ai_v{'temp'}{'body'}, $ai_v{'temp'}{'head'});
					sendMessage(\$remote_socket, $cmd{'type'}, getResponse("lookS"), $cmd{'user'}) if $config{'verbose'};
					$timeout{'ai_thanks_set'}{'time'} = time;
				} else {
					sendMessage(\$remote_socket, $cmd{'type'}, getResponse("lookF"), $cmd{'user'}) if $config{'verbose'};
				}	

			} elsif ($cmd{'msg'} =~ /\bfollow/i
				&& $cmd{'msg'} =~ /\bstop\b/i) {
				if ($config{'follow'}) {
					aiRemove("follow");
					configModify("follow", 0);
					sendMessage(\$remote_socket, $cmd{'type'}, getResponse("followStopS"), $cmd{'user'}) if $config{'verbose'};
					$timeout{'ai_thanks_set'}{'time'} = time;
				} else {
					sendMessage(\$remote_socket, $cmd{'type'}, getResponse("followStopF"), $cmd{'user'}) if $config{'verbose'};
				}
			} elsif ($cmd{'msg'} =~ /\bfollow\b/i) {
				$ai_v{'temp'}{'after'} = $';
				$ai_v{'temp'}{'after'} =~ s/^\s+//;
				$ai_v{'temp'}{'after'} =~ s/\s+$//;
				$ai_v{'temp'}{'targetID'} = ai_getIDFromChat(\%players, $cmd{'user'}, $ai_v{'temp'}{'after'});
				if ($ai_v{'temp'}{'targetID'} ne "") {
					aiRemove("follow");
					ai_follow($players{$ai_v{'temp'}{'targetID'}}{'name'});
					configModify("follow", 1);
					configModify("followTarget", $players{$ai_v{'temp'}{'targetID'}}{'name'});
					sendMessage(\$remote_socket, $cmd{'type'}, getResponse("followS"), $cmd{'user'}) if $config{'verbose'};
					$timeout{'ai_thanks_set'}{'time'} = time;
				} else {
					sendMessage(\$remote_socket, $cmd{'type'}, getResponse("followF"), $cmd{'user'}) if $config{'verbose'};
				}
			} elsif ($cmd{'msg'} =~ /\btank/i
				&& $cmd{'msg'} =~ /\bstop\b/i) {
				if (!$config{'tankMode'}) {
					sendMessage(\$remote_socket, $cmd{'type'}, getResponse("tankStopF"), $cmd{'user'}) if $config{'verbose'};
				} elsif ($config{'tankMode'}) {
					sendMessage(\$remote_socket, $cmd{'type'}, getResponse("tankStopS"), $cmd{'user'}) if $config{'verbose'};
					configModify("tankMode", 0);
					$timeout{'ai_thanks_set'}{'time'} = time;
				}
			} elsif ($cmd{'msg'} =~ /\btank/i) {
				$ai_v{'temp'}{'after'} = $';
				$ai_v{'temp'}{'after'} =~ s/^\s+//;
				$ai_v{'temp'}{'after'} =~ s/\s+$//;
				$ai_v{'temp'}{'targetID'} = ai_getIDFromChat(\%players, $cmd{'user'}, $ai_v{'temp'}{'after'});
				if ($ai_v{'temp'}{'targetID'} ne "") {
					sendMessage(\$remote_socket, $cmd{'type'}, getResponse("tankS"), $cmd{'user'}) if $config{'verbose'};
					configModify("tankMode", 1);
					configModify("tankModeTarget", $players{$ai_v{'temp'}{'targetID'}}{'name'});
					$timeout{'ai_thanks_set'}{'time'} = time;
				} else {
					sendMessage(\$remote_socket, $cmd{'type'}, getResponse("tankF"), $cmd{'user'}) if $config{'verbose'};
				}
			} elsif ($cmd{'msg'} =~ /\btown/i) {
				sendMessage(\$remote_socket, $cmd{'type'}, getResponse("moveS"), $cmd{'user'}) if $config{'verbose'};
				useTeleport(2);
				
			} elsif ($cmd{'msg'} =~ /\bwhere\b/i) {
				$responseVars{'x'} = $chars[$config{'char'}]{'pos_to'}{'x'};
				$responseVars{'y'} = $chars[$config{'char'}]{'pos_to'}{'y'};
				$responseVars{'map'} = qq~$maps_lut{$field{'name'}.'.rsw'} ($field{'name'})~;
				$timeout{'ai_thanks_set'}{'time'} = time;
				sendMessage(\$remote_socket, $cmd{'type'}, getResponse("whereS"), $cmd{'user'}) if $config{'verbose'};
			}

			#HEAL
			if ($cmd{'msg'} =~ /\bheal\b/i) {
				$ai_v{'temp'}{'after'} = $';
				($ai_v{'temp'}{'amount'}) = $ai_v{'temp'}{'after'} =~ /(\d+)/;
				$ai_v{'temp'}{'after'} =~ s/\d+//;
				$ai_v{'temp'}{'after'} =~ s/^\s+//;
				$ai_v{'temp'}{'after'} =~ s/\s+$//;
				$ai_v{'temp'}{'targetID'} = ai_getIDFromChat(\%players, $cmd{'user'}, $ai_v{'temp'}{'after'});
				if ($ai_v{'temp'}{'targetID'} eq "") {
					sendMessage(\$remote_socket, $cmd{'type'}, getResponse("healF1"), $cmd{'user'}) if $config{'verbose'};
				} elsif ($chars[$config{'char'}]{'skills'}{'AL_HEAL'}{'lv'} > 0) {
					undef $ai_v{'temp'}{'amount_healed'};
					undef $ai_v{'temp'}{'sp_needed'};
					undef $ai_v{'temp'}{'sp_used'};
					undef $ai_v{'temp'}{'failed'};
					undef @{$ai_v{'temp'}{'skillCasts'}};
					while ($ai_v{'temp'}{'amount_healed'} < $ai_v{'temp'}{'amount'}) {
						for ($i = 1; $i <= $chars[$config{'char'}]{'skills'}{'AL_HEAL'}{'lv'}; $i++) {
							$ai_v{'temp'}{'sp'} = 10 + ($i * 3);
							$ai_v{'temp'}{'amount_this'} = int(($chars[$config{'char'}]{'lv'} + $chars[$config{'char'}]{'int'}) / 8)
									* (4 + $i * 8);
							last if ($ai_v{'temp'}{'amount_healed'} + $ai_v{'temp'}{'amount_this'} >= $ai_v{'temp'}{'amount'});
						}
						$ai_v{'temp'}{'sp_needed'} += $ai_v{'temp'}{'sp'};
						$ai_v{'temp'}{'amount_healed'} += $ai_v{'temp'}{'amount_this'};
					}
					while ($ai_v{'temp'}{'sp_used'} < $ai_v{'temp'}{'sp_needed'} && !$ai_v{'temp'}{'failed'}) {
						for ($i = 1; $i <= $chars[$config{'char'}]{'skills'}{'AL_HEAL'}{'lv'}; $i++) {
							$ai_v{'temp'}{'lv'} = $i;
							$ai_v{'temp'}{'sp'} = 10 + ($i * 3);
							if ($ai_v{'temp'}{'sp_used'} + $ai_v{'temp'}{'sp'} > $chars[$config{'char'}]{'sp'}) {
								$ai_v{'temp'}{'lv'}--;
								$ai_v{'temp'}{'sp'} = 10 + ($ai_v{'temp'}{'lv'} * 3);
								last;
							}
							last if ($ai_v{'temp'}{'sp_used'} + $ai_v{'temp'}{'sp'} >= $ai_v{'temp'}{'sp_needed'});
						}
						if ($ai_v{'temp'}{'lv'} > 0) {
							$ai_v{'temp'}{'sp_used'} += $ai_v{'temp'}{'sp'};
							$ai_v{'temp'}{'skillCast'}{'skill'} = 'AL_HEAL';
							$ai_v{'temp'}{'skillCast'}{'lv'} = $ai_v{'temp'}{'lv'};
							$ai_v{'temp'}{'skillCast'}{'maxCastTime'} = 0;
							$ai_v{'temp'}{'skillCast'}{'minCastTime'} = 0;
							$ai_v{'temp'}{'skillCast'}{'ID'} = $ai_v{'temp'}{'targetID'};
							unshift @{$ai_v{'temp'}{'skillCasts'}}, {%{$ai_v{'temp'}{'skillCast'}}};
						} else {
							$responseVars{'char_sp'} = $chars[$config{'char'}]{'sp'} - $ai_v{'temp'}{'sp_used'};
							sendMessage(\$remote_socket, $cmd{'type'}, getResponse("healF2"), $cmd{'user'}) if $config{'verbose'};
							$ai_v{'temp'}{'failed'} = 1;
						}
					}
					if (!$ai_v{'temp'}{'failed'}) {
						sendMessage(\$remote_socket, $cmd{'type'}, getResponse("healS"), $cmd{'user'}) if $config{'verbose'};
					}
					foreach (@{$ai_v{'temp'}{'skillCasts'}}) {
						ai_skillUse($$_{'skill'}, $$_{'lv'}, $$_{'maxCastTime'}, $$_{'minCastTime'}, $$_{'ID'});
					}
				} else {
					sendMessage(\$remote_socket, $cmd{'type'}, getResponse("healF3"), $cmd{'user'}) if $config{'verbose'};
				}
			}


			#INC AGI
			if ($cmd{'msg'} =~ /\bagi\b/i){
				$ai_v{'temp'}{'after'} = $';
				($ai_v{'temp'}{'amount'}) = $ai_v{'temp'}{'after'} =~ /(\d+)/;
				$ai_v{'temp'}{'after'} =~ s/\d+//;
				$ai_v{'temp'}{'after'} =~ s/^\s+//;
				$ai_v{'temp'}{'after'} =~ s/\s+$//;
				$ai_v{'temp'}{'targetID'} = ai_getIDFromChat(\%players, $cmd{'user'}, $ai_v{'temp'}{'after'});
				if ($ai_v{'temp'}{'targetID'} eq "") {
					sendMessage(\$remote_socket, $cmd{'type'}, getResponse("healF1"), $cmd{'user'}) if $config{'verbose'};
				} elsif ($chars[$config{'char'}]{'skills'}{'AL_INCAGI'}{'lv'} > 0) {
					undef $ai_v{'temp'}{'failed'};
					$ai_v{'temp'}{'failed'} = 1;
					for ($i = $chars[$config{'char'}]{'skills'}{'AL_INCAGI'}{'lv'}; $i >=1; $i--) {
						if ($chars[$config{'char'}]{'sp'} >= $skillsSP_lut{'AL_INCAGI'}{$i}) {
							ai_skillUse('AL_INCAGI', $i, 0, 0, $ai_v{'temp'}{'targetID'});
							$ai_v{'temp'}{'failed'} = 0;
							last;
						}
					}
					if (!$ai_v{'temp'}{'failed'}) {
						sendMessage(\$remote_socket, $cmd{'type'}, getResponse("healS"), $cmd{'user'}) if $config{'verbose'};
					}else{
						sendMessage(\$remote_socket, $cmd{'type'}, getResponse("healF2"), $cmd{'user'}) if $config{'verbose'};
					}
				} else {
					sendMessage(\$remote_socket, $cmd{'type'}, getResponse("healF3"), $cmd{'user'}) if $config{'verbose'};
				}
				$timeout{'ai_thanks_set'}{'time'} = time;
			}


			#BLESSING
			if ($cmd{'msg'} =~ /\bbless\b/i || $cmd{'msg'} =~ /\bblessing\b/i){
				$ai_v{'temp'}{'after'} = $';
				($ai_v{'temp'}{'amount'}) = $ai_v{'temp'}{'after'} =~ /(\d+)/;
				$ai_v{'temp'}{'after'} =~ s/\d+//;
				$ai_v{'temp'}{'after'} =~ s/^\s+//;
				$ai_v{'temp'}{'after'} =~ s/\s+$//;
				$ai_v{'temp'}{'targetID'} = ai_getIDFromChat(\%players, $cmd{'user'}, $ai_v{'temp'}{'after'});
				if ($ai_v{'temp'}{'targetID'} eq "") {
					sendMessage(\$remote_socket, $cmd{'type'}, getResponse("healF1"), $cmd{'user'}) if $config{'verbose'};
				} elsif ($chars[$config{'char'}]{'skills'}{'AL_BLESSING'}{'lv'} > 0) {
					undef $ai_v{'temp'}{'failed'};
					$ai_v{'temp'}{'failed'} = 1;
					for ($i = $chars[$config{'char'}]{'skills'}{'AL_BLESSING'}{'lv'}; $i >=1; $i--) {
						if ($chars[$config{'char'}]{'sp'} >= $skillsSP_lut{'AL_BLESSING'}{$i}) {
							ai_skillUse('AL_BLESSING', $i, 0, 0, $ai_v{'temp'}{'targetID'});
							$ai_v{'temp'}{'failed'} = 0;
							last;
						}
					}
					if (!$ai_v{'temp'}{'failed'}) {
						sendMessage(\$remote_socket, $cmd{'type'}, getResponse("healS"), $cmd{'user'}) if $config{'verbose'};
					}else{
						sendMessage(\$remote_socket, $cmd{'type'}, getResponse("healF2"), $cmd{'user'}) if $config{'verbose'};
					}
				} else {
					sendMessage(\$remote_socket, $cmd{'type'}, getResponse("healF3"), $cmd{'user'}) if $config{'verbose'};
				}
				$timeout{'ai_thanks_set'}{'time'} = time;
			}


			#Kyrie
			if ($cmd{'msg'} =~ /\bkyrie\b/i){
				$ai_v{'temp'}{'after'} = $';
				($ai_v{'temp'}{'amount'}) = $ai_v{'temp'}{'after'} =~ /(\d+)/;
				$ai_v{'temp'}{'after'} =~ s/\d+//;
				$ai_v{'temp'}{'after'} =~ s/^\s+//;
				$ai_v{'temp'}{'after'} =~ s/\s+$//;
				$ai_v{'temp'}{'targetID'} = ai_getIDFromChat(\%players, $cmd{'user'}, $ai_v{'temp'}{'after'});
				if ($ai_v{'temp'}{'targetID'} eq "") {
					sendMessage(\$remote_socket, $cmd{'type'}, getResponse("healF1"), $cmd{'user'}) if $config{'verbose'};
				} elsif ($chars[$config{'char'}]{'skills'}{'PR_KYRIE'}{'lv'} > 0) {
					undef $ai_v{'temp'}{'failed'};
					$ai_v{'temp'}{'failed'} = 1;
					for ($i = $chars[$config{'char'}]{'skills'}{'PR_KYRIE'}{'lv'}; $i >=1; $i--) {
						if ($chars[$config{'char'}]{'sp'} >= $skillsSP_lut{'PR_KYRIE'}{$i}) {
							ai_skillUse('PR_KYRIE', $i, 0, 0, $ai_v{'temp'}{'targetID'});
							$ai_v{'temp'}{'failed'} = 0;
							last;
						}
					}
					if (!$ai_v{'temp'}{'failed'}) {
						sendMessage(\$remote_socket, $cmd{'type'}, getResponse("healS"), $cmd{'user'}) if $config{'verbose'};
					}else{
						sendMessage(\$remote_socket, $cmd{'type'}, getResponse("healF2"), $cmd{'user'}) if $config{'verbose'};
					}
				} else {
					sendMessage(\$remote_socket, $cmd{'type'}, getResponse("healF3"), $cmd{'user'}) if $config{'verbose'};
				}
				$timeout{'ai_thanks_set'}{'time'} = time;
			}


			if ($cmd{'msg'} =~ /\bthank/i || $cmd{'msg'} =~ /\bthn/i) {
				if (!timeOut(\%{$timeout{'ai_thanks_set'}})) {
					$timeout{'ai_thanks_set'}{'time'} -= $timeout{'ai_thanks_set'}{'timeout'};
					sendMessage(\$remote_socket, $cmd{'type'}, getResponse("thankS"), $cmd{'user'}) if $config{'verbose'};
				}
			}
		}
	}


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
		injectAdminMessage($Settings::welcomeText) if ($config{'verbose'});
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

	##### TALK WITH NPC ######
	NPCTALK: {
		last NPCTALK if ($ai_seq[0] ne "NPC");
		$ai_seq_args[0]{'time'} = time unless $ai_seq_args[0]{'time'};

		if ($ai_seq_args[0]{'stage'} eq '') {
			if (timeOut($ai_seq_args[0]{'time'}, $timeout{'ai_npcTalk'}{'timeout'})) {
				error "Could not find the NPC at the designated location.\n", "ai_npcTalk";
				shift @ai_seq;
				shift @ai_seq_args;

			} elsif ($ai_seq_args[0]{'nameID'}) {
				# An NPC ID has been passed
				my $npc = pack("L1", $ai_seq_args[0]{'nameID'});
				last if (!$npcs{$npc} || $npcs{$npc}{'name'} eq '' || $npcs{$npc}{'name'} =~ /Unknown/i);
				$ai_seq_args[0]{'ID'} = $npc;
				$ai_seq_args[0]{'name'} = $npcs{$npc}{'name'};
				$ai_seq_args[0]{'stage'} = 'Talking to NPC';
				@{$ai_seq_args[0]{'steps'}} = parse_line('\s+', 0, "w3 x $ai_seq_args[0]{'sequence'}");
				undef $ai_seq_args[0]{'time'};
				undef $ai_v{'npc_talk'}{'time'};

			} else {
				# An x,y position has been passed
				foreach my $npc (@npcsID) {
					next if !$npc || $npcs{$npc}{'name'} eq '' || $npcs{$npc}{'name'} =~ /Unknown/i;
					if ( $npcs{$npc}{'pos'}{'x'} eq $ai_seq_args[0]{'pos'}{'x'} &&
					     $npcs{$npc}{'pos'}{'y'} eq $ai_seq_args[0]{'pos'}{'y'} ) {
						debug "Target NPC $npcs{$npc}{'name'} at ($ai_seq_args[0]{'pos'}{'x'},$ai_seq_args[0]{'pos'}{'y'}) found.\n", "ai_npcTalk";
					     	$ai_seq_args[0]{'nameID'} = $npcs{$npc}{'nameID'};
				     		$ai_seq_args[0]{'ID'} = $npc;
					     	$ai_seq_args[0]{'name'} = $npcs{$npc}{'name'};
						$ai_seq_args[0]{'stage'} = 'Talking to NPC';
						@{$ai_seq_args[0]{'steps'}} = parse_line('\s+', 0, "w3 x $ai_seq_args[0]{'sequence'}");
						undef $ai_seq_args[0]{'time'};
						undef $ai_v{'npc_talk'}{'time'};
						last;
					}
				}
			}


		} elsif ($ai_seq_args[0]{'mapChanged'} || @{$ai_seq_args[0]{'steps'}} == 0) {
			message "Done talking with $ai_seq_args[0]{'name'}.\n", "ai_npcTalk";
			# There is no need to cancel conversation if map changed; NPC is nowhere by now.
			#sendTalkCancel(\$remote_socket, $ai_seq_args[0]{'ID'});
			shift @ai_seq;
			shift @ai_seq_args;

		} elsif (timeOut($ai_seq_args[0]{'time'}, $timeout{'ai_npcTalk'}{'timeout'})) {
			# If NPC does not respond before timing out, then by default, it's a failure
			error "NPC did not respond.\n", "ai_npcTalk";
			sendTalkCancel(\$remote_socket, $ai_seq_args[0]{'ID'});
			shift @ai_seq;
			shift @ai_seq_args;

		} elsif (timeOut($ai_v{'npc_talk'}{'time'}, 0.25)) {
			$ai_seq_args[0]{'time'} = time;
			$ai_v{'npc_talk'}{'time'} = time + $timeout{'ai_npcTalk'}{'timeout'} + 5;

			if ($config{autoTalkCont}) {
				while ($ai_seq_args[0]{'steps'}[0] =~ /c/i) {
					shift @{$ai_seq_args[0]{'steps'}};
				}
			}
			if ($ai_seq_args[0]{'steps'}[0] =~ /w(\d+)/i) {
				my $time = $1;
				$ai_v{'npc_talk'}{'time'} = time + $time;
				$ai_seq_args[0]{'time'}   = time + $time;
			} elsif ( $ai_seq_args[0]{'steps'}[0] =~ /^t=(.*)/i ) {
				sendTalkText(\$remote_socket, $ai_seq_args[0]{'ID'}, $1);
			} elsif ( $ai_seq_args[0]{'steps'}[0] =~ /x/i ) {
				sendTalk(\$remote_socket, $ai_seq_args[0]{'ID'});
			} elsif ( $ai_seq_args[0]{'steps'}[0] =~ /c/i ) {
				sendTalkContinue(\$remote_socket, $ai_seq_args[0]{'ID'});
			} elsif ( $ai_seq_args[0]{'steps'}[0] =~ /r(\d+)/i ) {
				sendTalkResponse(\$remote_socket, $ai_seq_args[0]{'ID'}, $1+1);
			} elsif ( $ai_seq_args[0]{'steps'}[0] =~ /n/i ) {
				sendTalkCancel(\$remote_socket, $ai_seq_args[0]{'ID'});
				$ai_v{'npc_talk'}{'time'} = time;
				$ai_seq_args[0]{'time'}   = time;
			} elsif ( $ai_seq_args[0]{'steps'}[0] =~ /b/i ) {
				sendGetStoreList(\$remote_socket, $ai_seq_args[0]{'ID'});
			}
			shift @{$ai_seq_args[0]{'steps'}};
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
			AI::queue("storageAuto") if ($config{'storageAuto'});
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
		my $item = AI::args->{items}[0];
		my $amount = AI::args->{max};

		if (!$amount || $amount > $storage{$storageID[$item]}{amount}) {
			$amount = $storage{$storageID[$item]}{amount};
		}
		sendStorageGet(\$remote_socket, $storage{$storageID[$item]}{index}, $amount) if ($storage{opened});
		shift @{AI::args->{items}};
		AI::args->{time} = time;
		AI::dequeue if (@{AI::args->{'items'}} <= 0);
	}

	##### DROPPING #####
	# Drop one or more items from inventory.

	if (AI::action eq "drop" && timeOut(AI::args)) {
		my $item = AI::args->{'items'}[0];
		my $amount = AI::args->{max};

		if (!$amount || $amount > $char->{inventory}[$item]{amount}) {
			$amount = $char->{inventory}[$item]{amount};
		}
		sendDrop(\$remote_socket, $char->{inventory}[$item]{index}, $amount);
		shift @{AI::args->{items}};
		AI::args->{time} = time;
		AI::dequeue if (@{AI::args->{'items'}} <= 0);
	}

	##### DELAYED-TELEPORT #####

	if ($ai_v{temp}{teleport}{lv}) {
		useTeleport($ai_v{temp}{teleport}{lv});
	}

	#storageAuto - chobit aska 20030128
	#####AUTO STORAGE#####

	AUTOSTORAGE: {

	if (($ai_seq[0] eq "" || $ai_seq[0] eq "route" || $ai_seq[0] eq "sitAuto" || $ai_seq[0] eq "follow") && $config{'storageAuto'} && $config{'storageAuto_npc'} ne ""
	  && (($config{'itemsMaxWeight_sellOrStore'} && percent_weight(\%{$chars[$config{'char'}]}) >= $config{'itemsMaxWeight_sellOrStore'})
	      || (!$config{'itemsMaxWeight_sellOrStore'} && percent_weight(\%{$chars[$config{'char'}]}) >= $config{'itemsMaxWeight'})
	  )) {
		$ai_v{'temp'}{'ai_route_index'} = binFind(\@ai_seq, "route");
		if ($ai_v{'temp'}{'ai_route_index'} ne "") {
			$ai_v{'temp'}{'ai_route_attackOnRoute'} = $ai_seq_args[$ai_v{'temp'}{'ai_route_index'}]{'attackOnRoute'};
		}
		if (!($ai_v{'temp'}{'ai_route_index'} ne "" && $ai_v{'temp'}{'ai_route_attackOnRoute'} <= 1) && ai_storageAutoCheck()) {
			unshift @ai_seq, "storageAuto";
			unshift @ai_seq_args, {};
		}
	} elsif (($ai_seq[0] eq "" || $ai_seq[0] eq "route" || $ai_seq[0] eq "attack")
	      && $config{'storageAuto'} && $config{'storageAuto_npc'} ne "" && timeOut(\%{$timeout{'ai_storageAuto'}})) {
		undef $ai_v{'temp'}{'found'};
		$i = 0;
		while (1) {
			last if (!$config{"getAuto_$i"});
			$ai_v{'temp'}{'invIndex'} = findIndexString_lc(\@{$chars[$config{'char'}]{'inventory'}}, "name", $config{"getAuto_$i"});
			if ($config{"getAuto_$i"."_minAmount"} ne "" && $config{"getAuto_$i"."_maxAmount"} ne ""
			   && !$config{"getAuto_$i"."_passive"}
			   && ($ai_v{'temp'}{'invIndex'} eq "" 
				 	|| ($chars[$config{'char'}]{'inventory'}[$ai_v{'temp'}{'invIndex'}]{'amount'} <= $config{"getAuto_$i"."_minAmount"} 
					&& $chars[$config{'char'}]{'inventory'}[$ai_v{'temp'}{'invIndex'}]{'amount'} < $config{"getAuto_$i"."_maxAmount"}))
			   && (findKeyString(\%storage, "name", $config{"getAuto_$i"}) ne "" || !$storage{opened})
			) {
				$ai_v{'temp'}{'found'} = 1;
			}
			$i++;
		}

		$ai_v{'temp'}{'ai_route_index'} = binFind(\@ai_seq, "route");
		if ($ai_v{'temp'}{'ai_route_index'} ne "") {
			$ai_v{'temp'}{'ai_route_attackOnRoute'} = $ai_seq_args[$ai_v{'temp'}{'ai_route_index'}]{'attackOnRoute'};
		}
		if (!($ai_v{'temp'}{'ai_route_index'} ne "" && $ai_v{'temp'}{'ai_route_attackOnRoute'} <= 1) && $ai_v{'temp'}{'found'}) {
			unshift @ai_seq, "storageAuto";
			unshift @ai_seq_args, {};
		}
		$timeout{'ai_storageAuto'}{'time'} = time;
	}

	if ($ai_seq[0] eq "storageAuto" && $ai_seq_args[0]{'done'}) {
		$ai_v{'temp'}{'var'} = $ai_seq_args[0]{'forcedBySell'};
		shift @ai_seq;
		shift @ai_seq_args;
		if (!$ai_v{'temp'}{'var'}) {
			unshift @ai_seq, "sellAuto";
			unshift @ai_seq_args, {forcedByStorage => 1};
		}
	} elsif ($ai_seq[0] eq "storageAuto" && timeOut(\%{$timeout{'ai_storageAuto'}})) {
		getNPCInfo($config{'storageAuto_npc'}, \%{$ai_seq_args[0]{'npc'}});
		if (!$config{'storageAuto'} || !defined($ai_seq_args[0]{'npc'}{'ok'})) {
			$ai_seq_args[0]{'done'} = 1;
			last AUTOSTORAGE;
		}

		undef $ai_v{'temp'}{'do_route'};
		if ($field{'name'} ne $ai_seq_args[0]{'npc'}{'map'}) {
			$ai_v{'temp'}{'do_route'} = 1;
		} else {
			$ai_v{'temp'}{'distance'} = distance(\%{$ai_seq_args[0]{'npc'}{'pos'}}, \%{$chars[$config{'char'}]{'pos_to'}});
			if ($ai_v{'temp'}{'distance'} > $config{'storageAuto_distance'}) {
				$ai_v{'temp'}{'do_route'} = 1;
			}
		}
		if ($ai_v{'temp'}{'do_route'}) {
			if ($ai_seq_args[0]{'warpedToSave'} && !$ai_seq_args[0]{'mapChanged'}) {
				undef $ai_seq_args[0]{'warpedToSave'};
			}

			if ($config{'saveMap'} ne "" && $config{'saveMap_warpToBuyOrSell'} && !$ai_seq_args[0]{'warpedToSave'} 
				&& !$cities_lut{$field{'name'}.'.rsw'}) {
				$ai_seq_args[0]{'warpedToSave'} = 1;
				useTeleport(2);
				$timeout{'ai_storageAuto'}{'time'} = time;
			} else {
				message "Calculating auto-storage route to: $maps_lut{$ai_seq_args[0]{'npc'}{'map'}.'.rsw'}($ai_seq_args[0]{'npc'}{'map'}): $ai_seq_args[0]{'npc'}{'pos'}{'x'}, $ai_seq_args[0]{'npc'}{'pos'}{'y'}\n", "route";
				ai_route($ai_seq_args[0]{'npc'}{'map'}, $ai_seq_args[0]{'npc'}{'pos'}{'x'}, $ai_seq_args[0]{'npc'}{'pos'}{'y'},
					attackOnRoute => 1,
					distFromGoal => $config{'storageAuto_distance'},
					noSitAuto => 1);
			}
		} else {
			if (!defined($ai_seq_args[0]{'sentStore'})) {
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
				$ai_seq_args[0]{'sentStore'} = 1;
				
				if (defined $ai_seq_args[0]{'npc'}{'id'}) { 
					ai_talkNPC(ID => $ai_seq_args[0]{'npc'}{'id'}, $config{'storageAuto_npc_steps'}); 
				} else {
					ai_talkNPC($ai_seq_args[0]{'npc'}{'pos'}{'x'}, $ai_seq_args[0]{'npc'}{'pos'}{'y'}, $config{'storageAuto_npc_steps'}); 
				}

				$timeout{'ai_storageAuto'}{'time'} = time;
				last AUTOSTORAGE;
			}
			
			if (!defined $ai_v{temp}{storage_opened}) {
				last AUTOSTORAGE;
			}
			
			if (!$ai_seq_args[0]{'getStart'}) {
				$ai_seq_args[0]{'done'} = 1;
				$ai_seq_args[0]{'nextItem'} = 0 unless $ai_seq_args[0]{'nextItem'};
				for (my $i = $ai_seq_args[0]{'nextItem'}; $i < @{$chars[$config{'char'}]{'inventory'}}; $i++) {
					next if (!%{$chars[$config{'char'}]{'inventory'}[$i]} || $chars[$config{'char'}]{'inventory'}[$i]{'equipped'});
					if ($items_control{lc($chars[$config{'char'}]{'inventory'}[$i]{'name'})}{'storage'}
						&& $chars[$config{'char'}]{'inventory'}[$i]{'amount'} > $items_control{lc($chars[$config{'char'}]{'inventory'}[$i]{'name'})}{'keep'}) {
						if ($ai_seq_args[0]{'lastIndex'} ne "" && $ai_seq_args[0]{'lastIndex'} == $chars[$config{'char'}]{'inventory'}[$i]{'index'}
							&& timeOut(\%{$timeout{'ai_storageAuto_giveup'}})) {
							last AUTOSTORAGE;
						} elsif ($ai_seq_args[0]{'lastIndex'} eq "" || $ai_seq_args[0]{'lastIndex'} != $chars[$config{'char'}]{'inventory'}[$i]{'index'}) {
							$timeout{'ai_storageAuto_giveup'}{'time'} = time;
						}
						undef $ai_seq_args[0]{'done'};
						$ai_seq_args[0]{'lastIndex'} = $chars[$config{'char'}]{'inventory'}[$i]{'index'};
						sendStorageAdd(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$i]{'index'}, $chars[$config{'char'}]{'inventory'}[$i]{'amount'} - $items_control{lc($chars[$config{'char'}]{'inventory'}[$i]{'name'})}{'keep'});
						$timeout{'ai_storageAuto'}{'time'} = time;
						$ai_seq_args[0]{'nextItem'} = $i + 1;
						last AUTOSTORAGE;
					}
				}
			}
			
			# getAuto begin
			
			if (!$ai_seq_args[0]{getStart} && $ai_seq_args[0]{done} == 1) {
				$ai_seq_args[0]{getStart} = 1;
				undef $ai_seq_args[0]{done};
				$ai_seq_args[0]{index} = 0;
				$ai_seq_args[0]{retry} = 0;

				last AUTOSTORAGE;
			}
			
			if (defined($ai_seq_args[0]{getStart}) && $ai_seq_args[0]{done} != 1) {

				my %item;
				while ($config{"getAuto_$ai_seq_args[0]{index}"}) {
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
			$ai_seq_args[0]{done} = 1;
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
		shift @ai_seq;
		shift @ai_seq_args;
		if (!$ai_v{'temp'}{'var'}) {
			unshift @ai_seq, "buyAuto";
			unshift @ai_seq_args, {forcedBySell => 1};
		}
	} elsif ($ai_seq[0] eq "sellAuto" && timeOut(\%{$timeout{'ai_sellAuto'}})) {
		getNPCInfo($config{'sellAuto_npc'}, \%{$ai_seq_args[0]{'npc'}}) if ($config{'sellAuto'});
		if (!$config{'sellAuto'} || !defined($ai_seq_args[0]{'npc'}{'ok'})) {
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
				&& !$cities_lut{$field{'name'}.'.rsw'}) {
				$ai_seq_args[0]{'warpedToSave'} = 1;
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
				if ($items_control{lc($chars[$config{'char'}]{'inventory'}[$i]{'name'})}{'sell'}
					&& $chars[$config{'char'}]{'inventory'}[$i]{'amount'} > $items_control{lc($chars[$config{'char'}]{'inventory'}[$i]{'name'})}{'keep'}) {
					if ($ai_seq_args[0]{'lastIndex'} ne "" && $ai_seq_args[0]{'lastIndex'} == $chars[$config{'char'}]{'inventory'}[$i]{'index'}
						&& timeOut(\%{$timeout{'ai_sellAuto_giveup'}})) {
						last AUTOSELL;
					} elsif ($ai_seq_args[0]{'lastIndex'} eq "" || $ai_seq_args[0]{'lastIndex'} != $chars[$config{'char'}]{'inventory'}[$i]{'index'}) {
						$timeout{'ai_sellAuto_giveup'}{'time'} = time;
					}
					undef $ai_seq_args[0]{'done'};
					$ai_seq_args[0]{'lastIndex'} = $chars[$config{'char'}]{'inventory'}[$i]{'index'};
					sendSell(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$i]{'index'}, $chars[$config{'char'}]{'inventory'}[$i]{'amount'} - $items_control{lc($chars[$config{'char'}]{'inventory'}[$i]{'name'})}{'keep'});
					$timeout{'ai_sellAuto'}{'time'} = time;
					last AUTOSELL;
				}
			}
		}
	}

	} #END OF BLOCK AUTOSELL



	#####AUTO BUY#####

	AUTOBUY: {

	if (($ai_seq[0] eq "" || $ai_seq[0] eq "route" || $ai_seq[0] eq "follow") && timeOut(\%{$timeout{'ai_buyAuto'}})) {
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
		$ai_v{'temp'}{'var'} = $ai_seq_args[0]{'forcedBySell'};
		shift @ai_seq;
		shift @ai_seq_args;
		if (!$ai_v{'temp'}{'var'} && ai_sellAutoCheck()) {
			unshift @ai_seq, "sellAuto";
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
				&& !$cities_lut{$field{'name'}.'.rsw'}) {
				$ai_seq_args[0]{'warpedToSave'} = 1;
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


	##### LOCKMAP #####

	%{$ai_v{'temp'}{'lockMap_coords'}} = ();
	$ai_v{'temp'}{'lockMap_coords'}{'x'} = $config{'lockMap_x'} + ((int(rand(3))-1)*(int(rand($config{'lockMap_randX'}))+1));
	$ai_v{'temp'}{'lockMap_coords'}{'y'} = $config{'lockMap_y'} + ((int(rand(3))-1)*(int(rand($config{'lockMap_randY'}))+1));
	if ($ai_seq[0] eq "" && $config{'lockMap'} && $field{'name'}
		&& ($field{'name'} ne $config{'lockMap'} || ($config{'lockMap_x'} ne "" && $config{'lockMap_y'} ne "" 
		&& ($chars[$config{'char'}]{'pos_to'}{'x'} != $config{'lockMap_x'} || $chars[$config{'char'}]{'pos_to'}{'y'} != $config{'lockMap_y'}) 
		&& distance($ai_v{'temp'}{'lockMap_coords'}, $chars[$config{'char'}]{'pos_to'}) > 1.42))
	) {
		if ($maps_lut{$config{'lockMap'}.'.rsw'} eq "") {
			error "Invalid map specified for lockMap - map $config{'lockMap'} doesn't exist\n";
		} else {
			if ($config{'lockMap_x'} ne "" && $config{'lockMap_y'} ne "") {
				message "Calculating lockMap route to: $maps_lut{$config{'lockMap'}.'.rsw'}($config{'lockMap'}): $config{'lockMap_x'}, $config{'lockMap_y'}\n", "route";
			} else {
				message "Calculating lockMap route to: $maps_lut{$config{'lockMap'}.'.rsw'}($config{'lockMap'})\n", "route";
			}

			my $attackOnRoute;
			if ($config{'attackAuto_inLockOnly'} == 1) {
				$attackOnRoute = 1;
			} elsif ($config{'attackAuto_inLockOnly'} > 1) {
				$attackOnRoute = 0;
			} else {
				$attackOnRoute = 2;
			}
			ai_route($config{'lockMap'}, $config{'lockMap_x'}, $config{'lockMap_y'},
				attackOnRoute => $attackOnRoute);
		}
	}
	undef $ai_v{'temp'}{'lockMap_coords'};


	##### RANDOM WALK #####
	if ($config{route_randomWalk} && AI::isIdle && !$cities_lut{$field{name}.'.rsw'}) {
		# Find a random block on the map that we can walk on
		my ($randX, $randY);
		do { 
			$randX = int(rand() * ($field{width} - 1));
			$randY = int(rand() * ($field{height} - 1));
		} while (!checkFieldWalkable(\%field, $randX, $randY));

		# Move to that block
		message "Calculating random route to: $maps_lut{$field{name}.'.rsw'}($field{name}): $randX, $randY\n", "route";
		ai_route($field{name}, $randX, $randY,
			maxRouteTime => $config{route_randomWalk_maxRouteTime},
			attackOnRoute => 2);
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
					lookAtPosition($players{$ai_seq_args[$followIndex]{'ID'}}{'pos_to'}, int(rand(3))) if ($config{'followFaceDirection'});
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
	if (($ai_seq[0] eq "" || $ai_seq[0] eq "follow") && $config{'sitAuto_idle'} && !$chars[$config{'char'}]{'sitting'} && timeOut(\%{$timeout{'ai_sit_idle'}})) {
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

	if ($ai_v{'sitAuto_forceStop'} && percent_hp(\%{$chars[$config{'char'}]}) >= $config{'sitAuto_hp_lower'} && percent_sp(\%{$chars[$config{'char'}]}) >= $config{'sitAuto_sp_lower'}) {
		$ai_v{'sitAuto_forceStop'} = 0;
	}
	my $percentWeight = 0;
	$percentWeight = $chars[$config{'char'}]{'weight'} / $chars[$config{'char'}]{'weight_max'} * 100 if ($chars[$config{'char'}]{'weight_max'});

	if (!$ai_v{'sitAuto_forceStop'} && ($ai_seq[0] eq "" || $ai_seq[0] eq "follow" ||
	      ($ai_seq[0] eq "route" && (!$ai_seq_args[0]{'noSitAuto'} || $percentWeight < 50)) ||
	      ($ai_seq[0] eq "mapRoute" && (!$ai_seq_args[0]{'noSitAuto'} || $percentWeight < 50))
	   )
	 && binFind(\@ai_seq, "attack") eq "" && !ai_getAggressives()
	 && (percent_hp($chars[$config{'char'}]) < $config{'sitAuto_hp_lower'} || percent_sp($chars[$config{'char'}]) < $config{'sitAuto_sp_lower'})) {
		unshift @ai_seq, "sitAuto";
		unshift @ai_seq_args, {};
		debug "Auto-sitting\n", "ai";
	}
	if ($ai_seq[0] eq "sitAuto" && !$chars[$config{'char'}]{'sitting'} && $chars[$config{'char'}]{'skills'}{'NV_BASIC'}{'lv'} >= 3 &&
	  !ai_getAggressives() && ($percentWeight < 50 || $config{'sitAuto_over_50'} eq '1')) {
		sit();
	}
	if ($ai_seq[0] eq "sitAuto" && ($ai_v{'sitAuto_forceStop'}
		|| (percent_hp(\%{$chars[$config{'char'}]}) >= $config{'sitAuto_hp_upper'} && percent_sp(\%{$chars[$config{'char'}]}) >= $config{'sitAuto_sp_upper'}))) {
		shift @ai_seq;
		shift @ai_seq_args;
		if (!$config{'sitAuto_idle'} && $chars[$config{'char'}]{'sitting'}) {
			stand();
		}
	}


	##### AUTO-ATTACK #####

	if (($ai_seq[0] eq "" || $ai_seq[0] eq "route" || ($ai_seq[0] eq "mapRoute" && $ai_seq_args[0]{'stage'} eq 'Getting Map Solution')
	  || $ai_seq[0] eq "follow" || $ai_seq[0] eq "sitAuto" || $ai_seq[0] eq "take" || $ai_seq[0] eq "items_gather" || $ai_seq[0] eq "items_take")
	  && !($config{'itemsTakeAuto'} >= 2 && ($ai_seq[0] eq "take" || $ai_seq[0] eq "items_take"))
	  && !($config{'itemsGatherAuto'} >= 2 && ($ai_seq[0] eq "take" || $ai_seq[0] eq "items_gather"))
	  && timeOut($timeout{'ai_attack_auto'})) {
		undef @{$ai_v{'ai_attack_agMonsters'}};
		undef @{$ai_v{'ai_attack_cleanMonsters'}};
		undef @{$ai_v{'ai_attack_partyMonsters'}};
		undef $ai_v{'temp'}{'priorityAttack'};
		undef $ai_v{'temp'}{'foundID'};

		# If we're in tanking mode, only attack something if the person we're tanking for is on screen.
		if ($config{'tankMode'}) {
			undef $ai_v{'temp'}{'found'};
			foreach (@playersID) {	
				next if ($_ eq "");
				if ($config{'tankModeTarget'} eq $players{$_}{'name'}) {
					$ai_v{'temp'}{'found'} = 1;
					last;
				}
			}
		}

		# Generate a list of all monsters that we are allowed to attack.
		if (!$config{'tankMode'} || ($config{'tankMode'} && $ai_v{'temp'}{'found'})) {
			$ai_v{'temp'}{'ai_follow_index'} = binFind(\@ai_seq, "follow");
			if ($ai_v{'temp'}{'ai_follow_index'} ne "") {
				$ai_v{'temp'}{'ai_follow_following'} = $ai_seq_args[$ai_v{'temp'}{'ai_follow_index'}]{'following'};
				$ai_v{'temp'}{'ai_follow_ID'} = $ai_seq_args[$ai_v{'temp'}{'ai_follow_index'}]{'ID'};
			} else {
				undef $ai_v{'temp'}{'ai_follow_following'};
			}
			$ai_v{'temp'}{'ai_route_index'} = binFind(\@ai_seq, "route");
			if ($ai_v{'temp'}{'ai_route_index'} ne "") {
				$ai_v{'temp'}{'ai_route_attackOnRoute'} = $ai_seq_args[$ai_v{'temp'}{'ai_route_index'}]{'attackOnRoute'};
			}

			# List aggressive monsters
			@{$ai_v{'ai_attack_agMonsters'}} = ai_getAggressives() if ($config{'attackAuto'} && !($ai_v{'temp'}{'ai_route_index'} ne "" && !$ai_v{'temp'}{'ai_route_attackOnRoute'}));

			# There are two types of non-aggressive monsters. We generate two lists:
			foreach (@monstersID) {
				next if ($_ eq "");
				# List monsters that the follow target or party members are attacking
				if (( ($config{'attackAuto_party'}
				      && $ai_seq[0] ne "take" && $ai_seq[0] ne "items_take"
				      && ($monsters{$_}{'dmgToParty'} > 0 || $monsters{$_}{'dmgFromParty'} > 0)
				      )
				   || ($config{'attackAuto_followTarget'} && $ai_v{'temp'}{'ai_follow_following'} 
				       && ($monsters{$_}{'dmgToPlayer'}{$ai_v{'temp'}{'ai_follow_ID'}} > 0 || $monsters{$_}{'missedToPlayer'}{$ai_v{'temp'}{'ai_follow_ID'}} > 0 || $monsters{$_}{'dmgFromPlayer'}{$ai_v{'temp'}{'ai_follow_ID'}} > 0))
				    )
				   && !($ai_v{'temp'}{'ai_route_index'} ne "" && !$ai_v{'temp'}{'ai_route_attackOnRoute'})
				   && $monsters{$_}{'attack_failed'} == 0 && ($mon_control{lc($monsters{$_}{'name'})}{'attack_auto'} >= 1 || $mon_control{lc($monsters{$_}{'name'})}{'attack_auto'} eq "")
				) {
					push @{$ai_v{'ai_attack_partyMonsters'}}, $_;

				# Begin the attack only when noone else is on screen, stolen from the skore forums a long time ago.
				} elsif ($config{'attackAuto_onlyWhenSafe'}
					&& $config{'attackAuto'} >= 2
					&& binSize(\@playersID) == 0
					&& $ai_seq[0] ne "sitAuto" && $ai_seq[0] ne "take" && $ai_seq[0] ne "items_gather" && $ai_seq[0] ne "items_take"
					&& !($monsters{$_}{'dmgFromYou'} == 0 && ($monsters{$_}{'dmgTo'} > 0 || $monsters{$_}{'dmgFrom'} > 0 || %{$monsters{$_}{'missedFromPlayer'}} || %{$monsters{$_}{'missedToPlayer'}} || %{$monsters{$_}{'castOnByPlayer'}})) && $monsters{$_}{'attack_failed'} == 0
					&& !($ai_v{'temp'}{'ai_route_index'} ne "" && $ai_v{'temp'}{'ai_route_attackOnRoute'} <= 1)
					&& ($mon_control{lc($monsters{$_}{'name'})}{'attack_auto'} >= 1 || $mon_control{lc($monsters{$_}{'name'})}{'attack_auto'} eq "")) {
						push @{$ai_v{'ai_attack_cleanMonsters'}}, $_;
					
				# List monsters that nobody's attacking
				} elsif ($config{'attackAuto'} >= 2
					&& !$config{'attackAuto_onlyWhenSafe'}
					&& $ai_seq[0] ne "sitAuto" && $ai_seq[0] ne "take" && $ai_seq[0] ne "items_gather" && $ai_seq[0] ne "items_take"
					&& !($monsters{$_}{'dmgFromYou'} == 0 && ($monsters{$_}{'dmgTo'} > 0 || $monsters{$_}{'dmgFrom'} > 0 || %{$monsters{$_}{'missedFromPlayer'}} || %{$monsters{$_}{'missedToPlayer'}} || %{$monsters{$_}{'castOnByPlayer'}})) && $monsters{$_}{'attack_failed'} == 0
					&& !($ai_v{'temp'}{'ai_route_index'} ne "" && $ai_v{'temp'}{'ai_route_attackOnRoute'} <= 1)
					&& ($mon_control{lc($monsters{$_}{'name'})}{'attack_auto'} >= 1 || $mon_control{lc($monsters{$_}{'name'})}{'attack_auto'} eq "")) {
					push @{$ai_v{'ai_attack_cleanMonsters'}}, $_;
				}
			}
			undef $ai_v{'temp'}{'distSmall'};
			undef $ai_v{'temp'}{'foundID'};
			undef $ai_v{'temp'}{'highestPri'};
			undef $ai_v{'temp'}{'priorityAttack'};

			# Look for all aggressive monsters that have the highest priority
			foreach (@{$ai_v{'ai_attack_agMonsters'}}) {
				# Don't attack monsters near portals
				next if (positionNearPortal(\%{$monsters{$_}{'pos_to'}}, 4));
				# Don't attack ignored monsters
				next if ($mon_control{lc($monsters{$_}{'name'})}{'attack_auto'} == -1);

				if (defined ($priority{lc($monsters{$_}{'name'})}) &&
				    $priority{lc($monsters{$_}{'name'})} > $ai_v{'temp'}{'highestPri'}) {
					$ai_v{'temp'}{'highestPri'} = $priority{lc($monsters{$_}{'name'})};
				}
			}

			$ai_v{'temp'}{'first'} = 1;
			if (!$ai_v{'temp'}{'highestPri'}) {
				# If not found, look for the closest aggressive monster (without priority)
				foreach (@{$ai_v{'ai_attack_agMonsters'}}) {
					# Don't attack monsters near portals
					next if (positionNearPortal(\%{$monsters{$_}{'pos_to'}}, 4));
					# Don't attack ignored monsters
					next if ($mon_control{lc($monsters{$_}{'name'})}{'attack_auto'} == -1);

					$ai_v{'temp'}{'dist'} = distance(\%{$chars[$config{'char'}]{'pos_to'}}, \%{$monsters{$_}{'pos_to'}});
					if (($ai_v{'temp'}{'first'} || $ai_v{'temp'}{'dist'} < $ai_v{'temp'}{'distSmall'}) && !%{$monsters{$_}{'statuses'}}) {
						$ai_v{'temp'}{'distSmall'} = $ai_v{'temp'}{'dist'};
						$ai_v{'temp'}{'foundID'} = $_;
						undef $ai_v{'temp'}{'first'};
					}
				}
			} else {
				# If found, look for the closest monster with the highest priority
				foreach (@{$ai_v{'ai_attack_agMonsters'}}) {
					next if ($priority{lc($monsters{$_}{'name'})} != $ai_v{'temp'}{'highestPri'});
					# Don't attack monsters near portals
					next if (positionNearPortal(\%{$monsters{$_}{'pos_to'}}, 4));
					# Don't attack ignored monsters
					next if ($mon_control{lc($monsters{$_}{'name'})}{'attack_auto'} == -1);

					$ai_v{'temp'}{'dist'} = distance(\%{$chars[$config{'char'}]{'pos_to'}}, \%{$monsters{$_}{'pos_to'}});
					if (($ai_v{'temp'}{'first'} || $ai_v{'temp'}{'dist'} < $ai_v{'temp'}{'distSmall'}) && !%{$monsters{$_}{'statuses'}}) {
						$ai_v{'temp'}{'distSmall'} = $ai_v{'temp'}{'dist'};
						$ai_v{'temp'}{'foundID'} = $_;
						$ai_v{'temp'}{'priorityAttack'} = 1;
						undef $ai_v{'temp'}{'first'};
					}
				}
			}

			if (!$ai_v{'temp'}{'foundID'}) {
				# There are no aggressive monsters; look for the closest monster that a party member is attacking
				undef $ai_v{'temp'}{'distSmall'};
				undef $ai_v{'temp'}{'foundID'};
				$ai_v{'temp'}{'first'} = 1;
				foreach (@{$ai_v{'ai_attack_partyMonsters'}}) {
					$ai_v{'temp'}{'dist'} = distance(\%{$chars[$config{'char'}]{'pos_to'}}, \%{$monsters{$_}{'pos_to'}});
					if (($ai_v{'temp'}{'first'} || $ai_v{'temp'}{'dist'} < $ai_v{'temp'}{'distSmall'}) && !$monsters{$_}{'ignore'} && !%{$monsters{$_}{'statuses'}}) {
						$ai_v{'temp'}{'distSmall'} = $ai_v{'temp'}{'dist'};
						$ai_v{'temp'}{'foundID'} = $_;
						undef $ai_v{'temp'}{'first'};
					}
				}
			}

			if (!$ai_v{'temp'}{'foundID'}) {
				# No party monsters either; look for the closest, non-aggressive monster that:
				# 1) nobody's attacking
				# 2) isn't within 2 blocks distance of someone else

				# Look for the monster with the highest priority
				undef $ai_v{'temp'}{'distSmall'};
				undef $ai_v{'temp'}{'foundID'};
				$ai_v{'temp'}{'first'} = 1;
				foreach (@{$ai_v{'ai_attack_cleanMonsters'}}) {
					$ai_v{'temp'}{'dist'} = distance($char->{'pos_to'}, $monsters{$_}{'pos_to'});
					if (($ai_v{'temp'}{'first'} || $ai_v{'temp'}{'dist'} < $ai_v{'temp'}{'distSmall'} || $priority{lc($monsters{$_}{'name'})} > $ai_v{'temp'}{'highestPri'})
					 && !$monsters{$_}{'ignore'} && !scalar(keys %{$monsters{$_}{'statuses'}})
					 && !positionNearPlayer($monsters{$_}{'pos_to'}, 3)
					 && !positionNearPortal($monsters{$_}{'pos_to'}, 4)) {
						$ai_v{'temp'}{'distSmall'} = $ai_v{'temp'}{'dist'};
						$ai_v{'temp'}{'foundID'} = $_;
						$ai_v{'temp'}{'highestPri'} = $priority{lc($monsters{$_}{'name'})};
						undef $ai_v{'temp'}{'first'};
					}
				}
			}
		}

		# If an appropriate monster's found, attack it. If not, wait ai_attack_auto secs before searching again.
		if ($ai_v{'temp'}{'foundID'}) {
			ai_setSuspend(0);
			attack($ai_v{'temp'}{'foundID'}, $ai_v{'temp'}{'priorityAttack'});
		} else {
			$timeout{'ai_attack_auto'}{'time'} = time;
		}
	}




	##### ATTACK #####


	if ($ai_seq[0] eq "attack" && $ai_seq_args[0]{'suspended'}) {
		$ai_seq_args[0]{'ai_attack_giveup'}{'time'} += time - $ai_seq_args[0]{'suspended'};
		undef $ai_seq_args[0]{'suspended'};
	}

	if ($ai_seq[0] eq "attack" && $ai_seq_args[0]{move_start}) {
		# We've just finished moving to the monster.
		# Don't count the time we spent on moving
		$ai_seq_args[0]{'ai_attack_giveup'}{'time'} += time - $ai_seq_args[0]{move_start};
		undef $ai_seq_args[0]{'unstuck'}{'time'};
		undef $ai_seq_args[0]{move_start};

	} elsif ((($ai_seq[0] eq "route" && $ai_seq[1] eq "attack") || ($ai_seq[0] eq "move" && $ai_seq[2] eq "attack"))
	   && $ai_seq_args[0]{attackID}) {
		# We're on route to the monster; check whether the monster has moved
		my $ID = $ai_seq_args[0]{attackID};
		my $attackSeq = ($ai_seq[0] eq "route") ? $ai_seq_args[1] : $ai_seq_args[2];

		if ($monsters{$ID} && %{$monsters{$ID}} && $ai_seq_args[1]{monsterPos} && %{$attackSeq->{monsterPos}}
		 && distance($monsters{$ID}{pos_to}, $attackSeq->{monsterPos}) > $attackSeq->{'attackMethod'}{'distance'}) {
			# Stop moving
			shift @ai_seq;
			shift @ai_seq_args;
			if ($ai_seq[0] eq "move") {
				shift @ai_seq;
				shift @ai_seq_args;
			}

			$ai_seq_args[0]{'ai_attack_giveup'}{'time'} = time;
			debug "Target has moved more than " . $attackSeq->{'attackMethod'}{'distance'} . " blocks; readjusting route\n", "ai_attack";
		}
	}

	if ($ai_seq[0] eq "attack" && timeOut($ai_seq_args[0]{'ai_attack_giveup'})) {
		$monsters{$ai_seq_args[0]{'ID'}}{'attack_failed'}++;
		shift @ai_seq;
		shift @ai_seq_args;
		message "Can't reach or damage target, dropping target\n", "ai_attack";

	} elsif ($ai_seq[0] eq "attack" && !%{$monsters{$ai_seq_args[0]{'ID'}}}) {
		# Monster died or disappeared
		$timeout{'ai_attack'}{'time'} -= $timeout{'ai_attack'}{'timeout'};
		my $ID = $ai_seq_args[0]{'ID'};
		shift @ai_seq;
		shift @ai_seq_args;

		if ($monsters_old{$ID}{'dead'}) {
			message "Target died\n", "ai_attack";

			monKilled();
			$monsters_Killed{$monsters_old{$ID}{'nameID'}}++;

			# Pickup loot when monster's dead
			if ($config{'itemsTakeAuto'} && $monsters_old{$ID}{'dmgFromYou'} > 0 && !$monsters_old{$ID}{'attackedByPlayer'}
			&& !$monsters_old{$ID}{'ignore'}) {
				ai_items_take($monsters_old{$ID}{'pos'}{'x'}, $monsters_old{$ID}{'pos'}{'y'},
					$monsters_old{$ID}{'pos_to'}{'x'}, $monsters_old{$ID}{'pos_to'}{'y'});
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

	} elsif ($ai_seq[0] eq "attack") {
		# The attack sequence hasn't timed out and the monster is on screen

		# Update information about the monster and the current situation
		my $followIndex = binFind(\@ai_seq, "follow");
		my $following;
		my $followID;
		if (defined $followIndex) {
			$following = $ai_seq_args[$followIndex]{'following'};
			$followID = $ai_seq_args[$followIndex]{'ID'};
		}

		my $ID = $ai_seq_args[0]{'ID'};
		my $monsterDist = distance($chars[$config{'char'}]{'pos_to'}, $monsters{$ID}{'pos_to'});
		my $cleanMonster = (
			  !($monsters{$ID}{'dmgFromYou'} == 0 && ($monsters{$ID}{'dmgTo'} > 0 || $monsters{$ID}{'dmgFrom'} > 0 || %{$monsters{$ID}{'missedFromPlayer'}} || %{$monsters{$ID}{'missedToPlayer'}} || %{$monsters{$ID}{'castOnByPlayer'}}))
			|| ($monsters{$ID}{'dmgFromParty'} > 0 || $monsters{$ID}{'dmgToParty'} > 0 || $monsters{$ID}{'missedToParty'} > 0)
			|| ($following && ($monsters{$ID}{'dmgToPlayer'}{$followID} > 0 || $monsters{$ID}{'missedToPlayer'}{$followID} > 0 || $monsters{$ID}{'dmgFromPlayer'}{$followID} > 0))
			|| ($monsters{$ID}{'dmgToYou'} > 0 || $monsters{$ID}{'missedYou'} > 0)
		);
		$cleanMonster = 0 if ($monsters{$ID}{'attackedByPlayer'} && (!$following || $monsters{$ID}{'lastAttackFrom'} ne $followID));
		$cleanMonster = 1 if !$config{attackAuto};


		# If the damage numbers have changed, update the giveup time so we don't timeout
		if ($ai_seq_args[0]{'dmgToYou_last'} != $monsters{$ID}{'dmgToYou'}
		 || $ai_seq_args[0]{'missedYou_last'} != $monsters{$ID}{'missedYou'}
		 || $ai_seq_args[0]{'dmgFromYou_last'} != $monsters{$ID}{'dmgFromYou'}) {
			$ai_seq_args[0]{'ai_attack_giveup'}{'time'} = time;
			debug "Update attack giveup time\n", "ai_attack";
		}
		$ai_seq_args[0]{'dmgToYou_last'} = $monsters{$ID}{'dmgToYou'};
		$ai_seq_args[0]{'missedYou_last'} = $monsters{$ID}{'missedYou'};
		$ai_seq_args[0]{'dmgFromYou_last'} = $monsters{$ID}{'dmgFromYou'};
		$ai_seq_args[0]{'missedFromYou_last'} = $monsters{$ID}{'missedFromYou'};


		if (!%{$ai_seq_args[0]{'attackMethod'}}) {
			if ($config{'attackUseWeapon'}) {
				$ai_seq_args[0]{'attackMethod'}{'distance'} = $config{'attackDistance'};
				$ai_seq_args[0]{'attackMethod'}{'type'} = "weapon";
			} else {
				$ai_seq_args[0]{'attackMethod'}{'distance'} = 30;
				undef $ai_seq_args[0]{'attackMethod'}{'type'};
			}
			$i = 0;
			while ($config{"attackSkillSlot_$i"} ne "") {
				if (checkSelfCondition("attackSkillSlot_$i")
					&& (!$config{"attackSkillSlot_$i"."_maxUses"} || $ai_seq_args[0]{'attackSkillSlot_uses'}{$i} < $config{"attackSkillSlot_$i"."_maxUses"})
					&& (!$config{"attackSkillSlot_$i"."_monsters"} || existsInList($config{"attackSkillSlot_$i"."_monsters"}, $monsters{$ID}{'name'}))
					&& checkMonsterCondition("attackSkillSlot_$i"."_target", $ID)
				) {
					$ai_seq_args[0]{'attackSkillSlot_uses'}{$i}++;
					$ai_seq_args[0]{'attackMethod'}{'distance'} = $config{"attackSkillSlot_$i"."_dist"};
					$ai_seq_args[0]{'attackMethod'}{'type'} = "skill";
					$ai_seq_args[0]{'attackMethod'}{'skillSlot'} = $i;
					last;
				}
				$i++;
			}
		}

		if ($chars[$config{'char'}]{'sitting'}) {
			ai_setSuspend(0);
			stand();

		} elsif (!$cleanMonster) {
			# Drop target if it's already attacked by someone else
			message "Dropping target - you will not kill steal others\n", "ai_attack";
			$monsters{$ID}{'ignore'} = 1;
			sendAttackStop(\$remote_socket);
			shift @ai_seq;
			shift @ai_seq_args;

		} elsif ($monsterDist > $ai_seq_args[0]{'attackMethod'}{'distance'}) {
			if (checkFieldWalkable(\%field, $monsters{$ID}{pos_to}{x}, $monsters{$ID}{pos_to}{y})) {
				# Move to target
				$ai_seq_args[0]{move_start} = time;
				%{$ai_seq_args[0]{monsterPos}} = %{$monsters{$ID}{pos_to}};

				my $dist = sprintf("%.1f", $monsterDist);
				debug "Target distance $dist is >$ai_seq_args[0]{'attackMethod'}{'distance'}; moving to target: " .
					"from ($chars[$config{char}]{pos_to}{x},$chars[$config{char}]{pos_to}{y}) to ($monsters{$ID}{pos_to}{x},$monsters{$ID}{pos_to}{y})\n", "ai_attack";

				ai_route($field{'name'}, $monsters{$ID}{pos_to}{x}, $monsters{$ID}{pos_to}{y},
					distFromGoal => $ai_seq_args[0]{'attackMethod'}{'distance'},
					maxRouteTime => $config{'attackMaxRouteTime'},
					attackID => $ID);
			} else {
				# The target is at a spot that's not walkable according to the field file
				# Ignore the monster.
				$monsters{$ai_seq_args[0]{'ID'}}{'attack_failed'}++;
				shift @ai_seq;
				shift @ai_seq_args;
				message "Can't reach or damage target, dropping target\n", "ai_attack";
			}

		} elsif (($config{'tankMode'} && $monsters{$ID}{'dmgFromYou'} == 0)
		      || !$config{'tankMode'}) {
			# Attack the target. In case of tanking, only attack if it hasn't been hit once.

			if (!$ai_seq_args[0]{'firstAttack'}) {
				$ai_seq_args[0]{'firstAttack'} = 1;
				my $dist = sprintf("%.1f", distance($char->{pos_to}, $monsters{$ID}{pos_to}));
				my $pos = "$char->{pos_to}{x},$char->{pos_to}{y}";
				debug "Ready to attack target (which is $dist blocks away); we're at ($pos)\n", "ai_attack";
			}

			$ai_seq_args[0]{'unstuck'}{'time'} = time if (!$ai_seq_args[0]{'unstuck'}{'time'});
			if (!$monsters{$ID}{'dmgFromYou'} && timeOut($ai_seq_args[0]{'unstuck'})) {
				# We are close enough to the target, and we're trying to attack it,
				# but some time has passed and we still haven't dealed any damage.
				# Our recorded position might be out of sync, so try to unstuck
				$ai_seq_args[0]{'unstuck'}{'time'} = time;
				debug("Attack - trying to unstuck\n", "ai_attack");
				move($char->{pos_to}{x}, $char->{pos_to}{y});
			}

			if ($ai_seq_args[0]{'attackMethod'}{'type'} eq "weapon" && timeOut($timeout{'ai_attack'})) {
				sendAttack(\$remote_socket, $ID,
					($config{'tankMode'}) ? 0 : 7);
				$timeout{'ai_attack'}{'time'} = time;
				undef %{$ai_seq_args[0]{'attackMethod'}};

			} elsif ($ai_seq_args[0]{'attackMethod'}{'type'} eq "skill") {
				$ai_v{'ai_attack_method_skillSlot'} = $ai_seq_args[0]{'attackMethod'}{'skillSlot'};
				undef %{$ai_seq_args[0]{'attackMethod'}};
				ai_setSuspend(0);
				if (!ai_getSkillUseType($skills_rlut{lc($config{"attackSkillSlot_$ai_v{'ai_attack_method_skillSlot'}"})})) {
					ai_skillUse(
						$skills_rlut{lc($config{"attackSkillSlot_$ai_v{'ai_attack_method_skillSlot'}"})},
						$config{"attackSkillSlot_$ai_v{'ai_attack_method_skillSlot'}"."_lvl"},
						$config{"attackSkillSlot_$ai_v{'ai_attack_method_skillSlot'}"."_maxCastTime"},
						$config{"attackSkillSlot_$ai_v{'ai_attack_method_skillSlot'}"."_minCastTime"},
						$ID);
				} else {
					ai_skillUse(
						$skills_rlut{lc($config{"attackSkillSlot_$ai_v{'ai_attack_method_skillSlot'}"})},
						$config{"attackSkillSlot_$ai_v{'ai_attack_method_skillSlot'}"."_lvl"},
						$config{"attackSkillSlot_$ai_v{'ai_attack_method_skillSlot'}"."_maxCastTime"},
						$config{"attackSkillSlot_$ai_v{'ai_attack_method_skillSlot'}"."_minCastTime"},
						$monsters{$ID}{'pos_to'}{'x'},
						$monsters{$ID}{'pos_to'}{'y'});
				}
				$ai_seq_args[0]{monsterID} = $ai_v{'ai_attack_ID'};

				debug qq~Auto-skill on monster: $skills_lut{$skills_rlut{lc($config{"attackSkillSlot_$ai_v{'ai_attack_method_skillSlot'}"})}} (lvl $config{"attackSkillSlot_$ai_v{'ai_attack_method_skillSlot'}"."_lvl"})\n~, "ai_attack";
			}
			
		} elsif ($config{'tankMode'}) {
			if ($ai_seq_args[0]{'dmgTo_last'} != $monsters{$ID}{'dmgTo'}) {
				$ai_seq_args[0]{'ai_attack_giveup'}{'time'} = time;
			}
			$ai_seq_args[0]{'dmgTo_last'} = $monsters{$ID}{'dmgTo'};
		}
	}

	# Check for kill steal while moving
	if (binFind(\@ai_seq, "attack") ne ""
	  && (($ai_seq[0] eq "move" || $ai_seq[0] eq "route") && $ai_seq_args[0]{'attackID'})) {
		$ai_v{'temp'}{'ai_follow_index'} = binFind(\@ai_seq, "follow");
		if ($ai_v{'temp'}{'ai_follow_index'} ne "") {
			$ai_v{'temp'}{'ai_follow_following'} = $ai_seq_args[$ai_v{'temp'}{'ai_follow_index'}]{'following'};
			$ai_v{'temp'}{'ai_follow_ID'} = $ai_seq_args[$ai_v{'temp'}{'ai_follow_index'}]{'ID'};
		} else {
			undef $ai_v{'temp'}{'ai_follow_following'};
		}

		my $ID = $ai_seq_args[0]{'attackID'};
		$ai_v{'ai_attack_cleanMonster'} = (
				  !($monsters{$ID}{'dmgFromYou'} == 0 && ($monsters{$ID}{'dmgTo'} > 0 || $monsters{$ID}{'dmgFrom'} > 0 || %{$monsters{$ID}{'missedFromPlayer'}} || %{$monsters{$ID}{'missedToPlayer'}} || %{$monsters{$ID}{'castOnByPlayer'}}))
				|| ($config{'attackAuto_party'} && ($monsters{$ID}{'dmgFromParty'} > 0 || $monsters{$ID}{'dmgToParty'} > 0))
				|| ($config{'attackAuto_followTarget'} && $ai_v{'temp'}{'ai_follow_following'} && ($monsters{$ID}{'dmgToPlayer'}{$ai_v{'temp'}{'ai_follow_ID'}} > 0 || $monsters{$ID}{'missedToPlayer'}{$ai_v{'temp'}{'ai_follow_ID'}} > 0 || $monsters{$ID}{'dmgFromPlayer'}{$ai_v{'temp'}{'ai_follow_ID'}} > 0))
				|| ($monsters{$ID}{'dmgToYou'} > 0 || $monsters{$ID}{'missedYou'} > 0)
			);
		$ai_v{'ai_attack_cleanMonster'} = 0 if ($monsters{$ID}{'attackedByPlayer'});
		$ai_v{'ai_attack_cleanMonster'} = 1 if !$config{attackAuto};

		if (!$ai_v{'ai_attack_cleanMonster'}) {
			message "Dropping target - you will not kill steal others\n";
			sendAttackStop(\$remote_socket);
			$monsters{$ai_seq_args[0]{'ID'}}{'ignore'} = 1;

			# Remove "move"
			shift @ai_seq;
			shift @ai_seq_args;
			# Remove "route"
			if ($ai_seq[0] eq "route") {
				shift @ai_seq;
				shift @ai_seq_args;
			}
			# Remove "attack"
			shift @ai_seq;
			shift @ai_seq_args;
		}
	}

	##### AUTO-ITEM USE #####

	if ((AI::isIdle || existsInList("route,mapRoute,follow,sitAuto,take,items_gather,items_take,attack", AI::action))
		&& timeOut(\%{$timeout{ai_item_use_auto}})) {
		my $i = 0;
		while (defined($config{"useSelf_item_$i"})) {
			if (checkSelfCondition("useSelf_item_$i")) {
				my $index = findIndexStringList_lc(\@{$char->{inventory}}, "name", $config{"useSelf_item_$i"});
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

	if (AI::isIdle || existsInList("route,mapRoute,follow,sitAuto,take,items_gather,items_take,attack", AI::action)) {
		my $i = 0;
		my %self_skill = ();
		while (defined($config{"useSelf_skill_$i"})) {
			if (checkSelfCondition("useSelf_skill_$i")) {
				$ai_v{"useSelf_skill_$i"."_time"} = time;
				$self_skill{ID} = $skills_rlut{lc($config{"useSelf_skill_$i"})};
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

	if (%{$char->{party}} && (AI::isIdle || existsInList("route,mapRoute,follow,sitAuto,take,items_gather,items_take,attack,move", AI::action))){
		my $i = 0;
		my %party_skill;
		while (defined($config{"partySkill_$i"})) {
			for (my $j = 0; $j < @partyUsersID; $j++) {
				next if ($partyUsersID[$j] eq "" || $partyUsersID[$j] eq $accountID);
				if ($players{$partyUsersID[$j]}
					&& inRange(distance(\%{$char->{pos_to}}, \%{$char->{party}{users}{$partyUsersID[$j]}{pos}}), $config{partySkillDistance} || "1..8")
					&& (!$config{"partySkill_$i"."_target"} || existsInList($config{"partySkill_$i"."_target"}, $char->{party}{users}{$partyUsersID[$j]}{'name'}))
					&& checkPlayerCondition("partySkill_$i"."_target", $partyUsersID[$j])
					&& checkSelfCondition("partySkill_$i")
					){
					$ai_v{"partySkill_$i"."_target_time"}{$partyUsersID[$j]} = time;
					$party_skill{skillID} = $skills_rlut{lc($config{"partySkill_$i"})};
					$party_skill{skillLvl} = $config{"partySkill_$i"."_lvl"};
					$party_skill{target} = $char->{party}{users}{$partyUsersID[$j]}{name};
					$party_skill{targetID} = $partyUsersID[$j];
					$party_skill{maxCastTime} = $config{"partySkill_$i"."_maxCastTime"};
					$party_skill{minCastTime} = $config{"partySkill_$i"."_minCastTime"};
					$targetTimeout{$partyUsersID[$j]}{$skillID} = $i;
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
			debug qq~Party Skill used ($char->{party}{users}{$partyUsersID[$j]}{name}) Skills Used: $skills_lut{$party_skill{skillID}} (lvl $party_skill{skillLvl})\n~;
			if (!ai_getSkillUseType($party_skill{skillID})) {
				ai_skillUse($party_skill{skillID}, $party_skill{skillLvl}, $party_skill{maxCastTime}, $party_skill{minCastTime}, $party_skill{targetID});
			} else {
				ai_skillUse($party_skill{skillID}, $party_skill{skillLvl}, $party_skill{maxCastTime}, $party_skill{minCastTime}, $char->{party}{users}{$party_skill{targetID}}{pos}{x}, $char->{party}{users}{$party_skill{targetID}}{pos}{y});
			}
		}
	}

	##### AUTO-EQUIP #####
	if ((AI::isIdle || existsInList("route,mapRoute,follow,sitAuto,skill_use,take,items_gather,items_take,attack", AI::action) || $ai_v{temp}{teleport}{lv})
		&& timeOut($timeout{ai_item_equip_auto})) {

		my $ai_index_attack = AI::findAction("attack");
		my $ai_index_skill_use = AI::findAction("skill_use");

		my $currentSkill;
		if (defined $ai_index_skill_use) {
			my $skillID = AI::args($ai_index_skill_use)->{skill_use_id};
			$currentSkill = $skills_lut{$skillID};
		}

		my $ai_attack_mon;
		if (defined $ai_index_attack) {
			$ai_attack_mon = $monsters{AI::args($ai_index_attack)->{ID}}{name};
		}

		my $i = 0;
		while ($config{"equipAuto_$i"}) {
			if (checkSelfCondition("equipAuto_$i")
			 	&& (!$config{"equipAuto_$i" . "_weight"} || $char->{percent_weight} >= $config{"equipAuto_$i" . "_weight"})
			 	&& (!$config{"equipAuto_$i" . "_onTeleport"} || $ai_v{temp}{teleport}{lv})
			 	&& (!$config{"equipAuto_$i" . "_whileSitting"} || ($config{"equipAuto_$i" . "_whileSitting"} && $char->{sitting}))
				&& (!$config{"equipAuto_$i" . "_monsters"} || (defined $ai_attack_mon && existsInList($config{"equipAuto_$i" . "_monsters"}, $ai_attack_mon)))
			 	&& (!$config{"equipAuto_$i" . "_skills"} || (defined $currentSkill && existsInList($config{"equipAuto_$i" . "_skills"}, $currentSkill)))
				){
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
		AI::args->{ai_skill_use_giveup}{time} += time - AI::args->{suspended};
		AI::args->{ai_skill_use_minCastTime}{time} += time - AI::args->{suspended};
		AI::args->{ai_skill_use_maxCastTime}{time} += time - AI::args->{suspended};
		delete AI::args->{suspended};
	}

	if (AI::action eq "skill_use") {
		if (exists AI::args->{ai_equipAuto_skilluse_giveup} && binFind(\@skillsID, AI::args->{skill_use_id}) eq "" && timeOut(AI::args->{ai_equipAuto_skilluse_giveup})) {
			warning "Timeout equiping for skill\n";
			AI::dequeue;

		} else {
			my $skillIDNumber = $skillsID_rlut{lc($skills_lut{AI::args->{skill_use_id}})};
			if (defined AI::args->{monsterID} && !defined $monsters{AI::args->{monsterID}}) {
				# This skill is supposed to be used for attacking a monster, but that monster has died
				AI::dequeue;
	
			} elsif ($char->{sitting}) {
				AI::suspend();
				stand();

			} elsif (!AI::args->{skill_used}) {
				AI::args->{skill_used} = 1;
				AI::args->{ai_skill_use_giveup}{time} = time;
				if (AI::args->{skill_use_target_x} ne "") {
					sendSkillUseLoc(\$remote_socket, $skillIDNumber, AI::args->{skill_use_lv}, AI::args->{skill_use_target_x}, AI::args->{skill_use_target_y});
				} else {
					sendSkillUse(\$remote_socket, $skillIDNumber, AI::args->{skill_use_lv}, AI::args->{skill_use_target});
				}
				AI::args->{skill_use_last} = $char->{skills}{AI::args->{skill_use_id}}{time_used};
	
			} elsif ((AI::args->{skill_use_last} != $char->{skills}{AI::args->{skill_use_id}}{time_used} || (timeOut(AI::args->{ai_skill_use_giveup}) && (!$char->{time_cast} || !AI::args->{skill_use_maxCastTime}{timeout})) || (AI::args->{skill_use_maxCastTime}{timeout} && timeOut(AI::args->{skill_use_maxCastTime})))
				&& timeOut(AI::args->{skill_use_minCastTime})) {
				AI::dequeue;
			}
		}
	}

	####### ROUTE #######
	if ( $ai_seq[0] eq "route" && $field{'name'} && $chars[$config{'char'}]{'pos_to'}{'x'} ne '' && $chars[$config{'char'}]{'pos_to'}{'y'} ne '' ) {

		if ( $ai_seq_args[0]{'maxRouteTime'} && time - $ai_seq_args[0]{'time_start'} > $ai_seq_args[0]{'maxRouteTime'} ) {
			# we spent too much time
			debug "Route - we spent too much time; bailing out.\n", "route";
			shift @ai_seq;
			shift @ai_seq_args;

		} elsif ( ($field{'name'} ne $ai_seq_args[0]{'dest'}{'map'} || $ai_seq_args[0]{'mapChanged'}) ) {
			debug "Map changed: <$field{'name'}> <$ai_seq_args[0]{'dest'}{'map'}>\n", "route";
			shift @ai_seq;
			shift @ai_seq_args;

		} elsif ($ai_seq_args[0]{'stage'} eq '') {
			undef @{$ai_seq_args[0]{'solution'}};
			if (ai_route_getRoute( \@{$ai_seq_args[0]{'solution'}}, \%field, \%{$chars[$config{'char'}]{'pos_to'}}, \%{$ai_seq_args[0]{'dest'}{'pos'}}) ) {
				$ai_seq_args[0]{'stage'} = 'Route Solution Ready';
				debug "Route Solution Ready\n", "route";
			} else {
				debug "Something's wrong; there is no path to $field{'name'}($ai_seq_args[0]{'dest'}{'pos'}{'x'},$ai_seq_args[0]{'dest'}{'pos'}{'y'}).\n", "debug";
				shift @ai_seq;
				shift @ai_seq_args;
			}

		} elsif ( $ai_seq_args[0]{'stage'} eq 'Route Solution Ready' ) {
			if ($ai_seq_args[0]{'maxRouteDistance'} > 0 && $ai_seq_args[0]{'maxRouteDistance'} < 1) {
				# fractional route motion
				$ai_seq_args[0]{'maxRouteDistance'} = int($ai_seq_args[0]{'maxRouteDistance'} * scalar @{$ai_seq_args[0]{'solution'}});
			}
			splice(@{$ai_seq_args[0]{'solution'}},1+$ai_seq_args[0]{'maxRouteDistance'}) if $ai_seq_args[0]{'maxRouteDistance'} && $ai_seq_args[0]{'maxRouteDistance'} < @{$ai_seq_args[0]{'solution'}};

			# Trim down solution tree for pyDistFromGoal or distFromGoal
			if ($ai_seq_args[0]{'pyDistFromGoal'}) {
				my $trimsteps = 0;
				$trimsteps++ while ($trimsteps < @{$ai_seq_args[0]{'solution'}}
						 && distance($ai_seq_args[0]{'solution'}[@{$ai_seq_args[0]{'solution'}}-1-$trimsteps], $ai_seq_args[0]{'solution'}[@{$ai_seq_args[0]{'solution'}}-1]) < $ai_seq_args[0]{'pyDistFromGoal'}
					);
				debug "Route - trimming down solution by $trimsteps steps for pyDistFromGoal $ai_seq_args[0]{'pyDistFromGoal'}\n", "route";
				splice(@{$ai_seq_args[0]{'solution'}}, -$trimsteps) if ($trimsteps);
			} elsif ($ai_seq_args[0]{'distFromGoal'}) {
				my $trimsteps = $ai_seq_args[0]{distFromGoal};
				$trimsteps = @{$ai_seq_args[0]{'solution'}} if $trimsteps > @{$ai_seq_args[0]{'solution'}};
				debug "Route - trimming down solution by $trimsteps steps for distFromGoal $ai_seq_args[0]{'distFromGoal'}\n", "route";
				splice(@{$ai_seq_args[0]{'solution'}}, -$trimsteps) if ($trimsteps);
			}

			undef $ai_seq_args[0]{'mapChanged'};
			undef $ai_seq_args[0]{'index'};
			undef $ai_seq_args[0]{'old_x'};
			undef $ai_seq_args[0]{'old_y'};
			undef $ai_seq_args[0]{'new_x'};
			undef $ai_seq_args[0]{'new_y'};
			$ai_seq_args[0]{'time_step'} = time;
			$ai_seq_args[0]{'stage'} = 'Walk the Route Solution';

		} elsif ( $ai_seq_args[0]{'stage'} eq 'Walk the Route Solution' ) {

			my $cur_x = $chars[$config{'char'}]{'pos'}{'x'};
			my $cur_y = $chars[$config{'char'}]{'pos'}{'y'};

			unless (@{$ai_seq_args[0]{'solution'}}) {
				#no more points to cover
				shift @ai_seq;
				shift @ai_seq_args;

			} elsif ($ai_seq_args[0]{'old_x'} == $cur_x && $ai_seq_args[0]{'old_y'} == $cur_y && timeOut($ai_seq_args[0]{'time_step'}, 3)) {
				#we are still on the same spot, decrease step size
				$ai_seq_args[0]{'index'} = int($ai_seq_args[0]{'index'}*0.85);
				if ($ai_seq_args[0]{'index'}) {
					debug "Route - not moving, decreasing step size to $ai_seq_args[0]{'index'}\n", "route";
					if (@{$ai_seq_args[0]{'solution'}}) {
						#if we still have more points to cover, walk to next point
						$ai_seq_args[0]{'index'} = @{$ai_seq_args[0]{'solution'}}-1 if $ai_seq_args[0]{'index'} >= @{$ai_seq_args[0]{'solution'}};
						$ai_seq_args[0]{'new_x'} = $ai_seq_args[0]{'solution'}[$ai_seq_args[0]{'index'}]{'x'};
						$ai_seq_args[0]{'new_y'} = $ai_seq_args[0]{'solution'}[$ai_seq_args[0]{'index'}]{'y'};
						move($ai_seq_args[0]{'new_x'}, $ai_seq_args[0]{'new_y'}, $ai_seq_args[0]{'attackID'});
					}
				} else {
					#we're stuck
					my $msg = "Stuck at $field{'name'} ($cur_x,$cur_y)->($ai_seq_args[0]{'new_x'},$ai_seq_args[0]{'new_y'}).";
					$msg .= " Teleporting to unstuck." if $config{teleportAuto_unstuck};
					$msg .= "\n";
					warning $msg, "route";
					useTeleport(1) if $config{teleportAuto_unstuck};
					shift @ai_seq;
					shift @ai_seq_args;
				}

			} else {
				#we're either starting to move or already moving, so send out more
				#move commands periodically to keep moving and updating our position
				$ai_seq_args[0]{'index'} = $config{'route_step'} unless $ai_seq_args[0]{'index'};
				$ai_seq_args[0]{'index'}++ if $ai_seq_args[0]{'index'} < $config{'route_step'};
				if ($ai_seq_args[0]{'old_x'} && $ai_seq_args[0]{'old_y'}) {
					#see how far we've walked since the last move command and
					#trim down the soultion tree by this distance.
					#only remove the last step if we reached the destination
					my $trimsteps = 0;
					#if position has changed, we must have walked at least one step
					$trimsteps++ if ($cur_x != $ai_seq_args[0]{'old_x'} || $cur_y != $ai_seq_args[0]{'old_y'});
					#search the best matching entry for our position in the solution
					while ($trimsteps < @{$ai_seq_args[0]{'solution'}}
							 && distance( { 'x' => $cur_x, 'y' => $cur_y }, $ai_seq_args[0]{'solution'}[$trimsteps+1])
							    < distance( { 'x' => $cur_x, 'y' => $cur_y }, $ai_seq_args[0]{'solution'}[$trimsteps])
						) { 
						$trimsteps++; 
					}
					#remove the last step also if we reached the destination
					$trimsteps = @{$ai_seq_args[0]{'solution'}} - 1 if ($trimsteps >= @{$ai_seq_args[0]{'solution'}});
					$trimsteps = @{$ai_seq_args[0]{'solution'}} if ($trimsteps <= $ai_seq_args[0]{'index'} && $ai_seq_args[0]{'new_x'} == $cur_x && $ai_seq_args[0]{'new_y'} == $cur_y);
					debug "Route - trimming down solution by $trimsteps steps\n", "route";
					splice(@{$ai_seq_args[0]{'solution'}}, 0, $trimsteps) if ($trimsteps > 0);
				}
				my $stepsleft = @{$ai_seq_args[0]{'solution'}};
				if ($stepsleft > 0) {
					#if we still have more points to cover, walk to next point
					$ai_seq_args[0]{'index'} = @{$ai_seq_args[0]{'solution'}}-1 if $ai_seq_args[0]{'index'} >= @{$ai_seq_args[0]{'solution'}};
					$ai_seq_args[0]{'new_x'} = $ai_seq_args[0]{'solution'}[$ai_seq_args[0]{'index'}]{'x'};
					$ai_seq_args[0]{'new_y'} = $ai_seq_args[0]{'solution'}[$ai_seq_args[0]{'index'}]{'y'};
					$ai_seq_args[0]{'old_x'} = $cur_x;
					$ai_seq_args[0]{'old_y'} = $cur_y;
					$ai_seq_args[0]{'time_step'} = time if ($cur_x != $ai_seq_args[0]{'old_x'} || $cur_y != $ai_seq_args[0]{'old_y'});
					debug "Route - next step moving to ($ai_seq_args[0]{'new_x'}, $ai_seq_args[0]{'new_y'}), index $ai_seq_args[0]{'index'}, $stepsleft steps left\n", "route";
					move($ai_seq_args[0]{'new_x'}, $ai_seq_args[0]{'new_y'}, $ai_seq_args[0]{'attackID'});
				} else {
					#no more points to cover
					message "Destination reached.\n", "success", 2;
					shift @ai_seq;
					shift @ai_seq_args;
				}
			}

		} else {
			debug "Unexpected route stage [$ai_seq_args[0]{'stage'}] occured.\n", "route";
			shift @ai_seq;
			shift @ai_seq_args;
		}
	}


	####### MAPROUTE #######
	if ( $ai_seq[0] eq "mapRoute" && $field{'name'} && $chars[$config{'char'}]{'pos_to'}{'x'} ne '' && $chars[$config{'char'}]{'pos_to'}{'y'} ne '' ) {

		if ($ai_seq_args[0]{'stage'} eq '') {
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
				if ( ai_route_getRoute(\@{$ai_seq_args[0]{'solution'}}, \%field, \%{$chars[$config{'char'}]{'pos_to'}}, \%{$portals_lut{$portal}{'source'}{'pos'}}) ) {
					foreach my $dest (keys %{$portals_lut{$portal}{'dest'}}) {
						my $penalty = int(($portals_lut{$portal}{'dest'}{$dest}{'steps'} ne '') ? $routeWeights{'NPC'} : $routeWeights{'PORTAL'});
						$ai_seq_args[0]{'openlist'}{"$portal=$dest"}{'walk'} = $penalty + scalar @{$ai_seq_args[0]{'solution'}};
						$ai_seq_args[0]{'openlist'}{"$portal=$dest"}{'zenny'} = $portals_lut{$portal}{'dest'}{$dest}{'cost'};
					}
				}
			}
			$ai_seq_args[0]{'stage'} = 'Getting Map Solution';

		} elsif ( $ai_seq_args[0]{'stage'} eq 'Getting Map Solution' ) {
			$timeout{'ai_route_calcRoute'}{'time'} = time;
			while (!$ai_seq_args[0]{'done'} && !timeOut(\%{$timeout{'ai_route_calcRoute'}})) {
				ai_mapRoute_searchStep(\%{$ai_seq_args[0]});
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
				shift @ai_seq;
				shift @ai_seq_args;
			}
		} elsif ( $ai_seq_args[0]{'stage'} eq 'Traverse the Map Solution' ) {

			my %args;
			undef @{$args{'solution'}};
			unless (@{$ai_seq_args[0]{'mapSolution'}}) {
				#mapSolution is now empty
				shift @ai_seq;
				shift @ai_seq_args;
				debug "Map Router is finish traversing the map solution\n", "route";

			} elsif ( $field{'name'} ne $ai_seq_args[0]{'mapSolution'}[0]{'map'} || $ai_seq_args[0]{'mapChanged'} ) {
				#Solution Map does not match current map
				debug "Current map $field{'name'} does not match solution [ $ai_seq_args[0]{'mapSolution'}[0]{'portal'} ].\n", "route";
				delete $ai_seq_args[0]{'substage'};
				delete $ai_seq_args[0]{'timeout'};
				delete $ai_seq_args[0]{'mapChanged'};
				shift @{$ai_seq_args[0]{'mapSolution'}};

			} elsif ( $ai_seq_args[0]{'mapSolution'}[0]{'steps'} ) {
				#If current solution has conversation steps specified
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

				} elsif ( 5 > distance(\%{$chars[$config{'char'}]{'pos_to'}}, \%{$ai_seq_args[0]{'mapSolution'}[0]{'pos'}}) ) {
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

				} elsif ( ai_route_getRoute( \@{$args{'solution'}}, \%field, \%{$chars[$config{'char'}]{'pos_to'}}, \%{$ai_seq_args[0]{'mapSolution'}[0]{'pos'}} ) ) {
					# NPC is reachable from current position
					# >> Then "route" to it
					debug "Walking towards the NPC\n", "route";
					ai_route($ai_seq_args[0]{'mapSolution'}[0]{'map'}, $ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'x'}, $ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'y'},
						attackOnRoute => $ai_seq_args[0]{'attackOnRoute'},
						maxRouteTime => $ai_seq_args[0]{'maxRouteTime'},
						distFromGoal => 3,
						noSitAuto => $ai_seq_args[0]{'noSitAuto'},
						_solution => $args{'solution'},
						_internal => 1);

				} else {
					#Error, NPC is not reachable from current pos
					debug "CRTICAL ERROR: NPC is not reachable from current location.\n", "route";
					error "Unable to walk from $field{'name'} ($chars[$config{'char'}]{'pos_to'}{'x'},$chars[$config{'char'}]{'pos_to'}{'y'}) to NPC at ($ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'x'},$ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'y'}).\n", "route";
					shift @{$ai_seq_args[0]{'mapSolution'}};
				}

			} elsif ( $ai_seq_args[0]{'mapSolution'}[0]{'portal'} eq "$ai_seq_args[0]{'mapSolution'}[0]{'map'} $ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'x'} $ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'y'}=$ai_seq_args[0]{'mapSolution'}[0]{'map'} $ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'x'} $ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'y'}" ) {
				#This solution points to an X,Y coordinate
				my $distFromGoal = $ai_seq_args[0]{'pyDistFromGoal'} ? $ai_seq_args[0]{'pyDistFromGoal'} : ($ai_seq_args[0]{'distFromGoal'} ? $ai_seq_args[0]{'distFromGoal'} : 0);
				if ( $distFromGoal + 2 > distance($chars[$config{'char'}]{'pos_to'}, $ai_seq_args[0]{'mapSolution'}[0]{'pos'})) {
					#We need to specify +2 because sometimes the exact spot is occupied by someone else
					shift @{$ai_seq_args[0]{'mapSolution'}};

				} elsif ( $ai_seq_args[0]{'maxRouteTime'} && time - $ai_seq_args[0]{'time_start'} > $ai_seq_args[0]{'maxRouteTime'} ) {
					#we spent too long a time
					debug "We spent too much time; bailing out.\n", "route";
					shift @ai_seq;
					shift @ai_seq_args;

				} elsif ( ai_route_getRoute( \@{$args{'solution'}}, \%field, \%{$chars[$config{'char'}]{'pos_to'}}, \%{$ai_seq_args[0]{'mapSolution'}[0]{'pos'}} ) ) {
					# X,Y is reachable from current position
					# >> Then "route" to it
					ai_route($ai_seq_args[0]{'mapSolution'}[0]{'map'}, $ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'x'}, $ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'y'},
						attackOnRoute => $ai_seq_args[0]{'attackOnRoute'},
						maxRouteTime => $ai_seq_args[0]{'maxRouteTime'},
						distFromGoal => $ai_seq_args[0]{'distFromGoal'},
						pyDistFromGoal => $ai_seq_args[0]{'pyDistFromGoal'},
						noSitAuto => $ai_seq_args[0]{'noSitAuto'},
						_solution => $args{'solution'},
						_internal => 1);

				} else {
					warning "No LOS from $field{'name'} ($chars[$config{'char'}]{'pos_to'}{'x'},$chars[$config{'char'}]{'pos_to'}{'y'}) to Final Destination at ($ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'x'},$ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'y'}).\n", "route";
					error "Cannot reach ($ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'x'},$ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'y'}) from current position.\n", "route";
					shift @{$ai_seq_args[0]{'mapSolution'}};
				}

			} elsif ( $portals_lut{"$ai_seq_args[0]{'mapSolution'}[0]{'map'} $ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'x'} $ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'y'}"}{'source'}{'ID'} ) {
				# This is a portal solution

				if ( 2 > distance(\%{$chars[$config{'char'}]{'pos_to'}}, \%{$ai_seq_args[0]{'mapSolution'}[0]{'pos'}}) ) {
					# Portal is within 'Enter Distance'
					$timeout{'ai_portal_wait'}{'timeout'} = $timeout{'ai_portal_wait'}{'timeout'} || 0.5;
					if ( timeOut(\%{$timeout{'ai_portal_wait'}}) ) {
						sendMove( \$remote_socket, int($ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'x'}), int($ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'y'}) );
						$timeout{'ai_portal_wait'}{'time'} = time;
					}

				} elsif ( ai_route_getRoute( \@{$args{'solution'}}, \%field, \%{$chars[$config{'char'}]{'pos_to'}}, \%{$ai_seq_args[0]{'mapSolution'}[0]{'pos'}} ) ) {
					debug "portal within same map\n", "route";
					# Portal is reachable from current position
					# >> Then "route" to it
					debug "Portal route attackOnRoute = $ai_seq_args[0]{'attackOnRoute'}\n", "route";
					ai_route($ai_seq_args[0]{'mapSolution'}[0]{'map'}, $ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'x'}, $ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'y'},
						attackOnRoute => $ai_seq_args[0]{'attackOnRoute'},
						maxRouteTime => $ai_seq_args[0]{'maxRouteTime'},
						noSitAuto => $ai_seq_args[0]{'noSitAuto'},
						_solution => $args{'solution'},
						_internal => 1);

				} else {
					warning "No LOS from $field{'name'} ($chars[$config{'char'}]{'pos_to'}{'x'},$chars[$config{'char'}]{'pos_to'}{'y'}) to Portal at ($ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'x'},$ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'y'}).\n", "route";
					error "Cannot reach portal from current position\n", "route";
					shift @{$ai_seq_args[0]{'mapSolution'}};
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
		ai_clientSuspend(0, $timeout{ai_attack_waitAfterKill}{timeout});
	}
	if ($config{itemsTakeAuto} && AI::action eq "items_take" && timeOut(AI::args->{ai_items_take_start})) {
		my $foundID;
		my $dist, $dist_to;
		
		foreach (@itemsID) {
			next if ($_ eq "" || $itemsPickup{lc($items{$_}{name})} eq "0" || (!$itemsPickup{all} && !$itemsPickup{lc($items{$_}{name})}));
			$dist = distance(\%{$items{$_}{pos}}, AI::args->{pos});
			$dist_to = distance(\%{$items{$_}{pos}}, AI::args->{pos_to});
			if (($dist <= 4 || $dist_to <= 4) && $items{$_}{take_failed} == 0) {
				$foundID = $_;
				last;
			}
		}
		if ($foundID) {
			AI::args->{ai_items_take_end}{time} = time;
			AI::args->{started} = 1;
			take($foundID);
		} elsif (AI::args->{started} || timeOut(AI::args->{ai_items_take_end})) {
			AI::dequeue;
			ai_clientSuspend(0, $timeout{ai_attack_waitAfterKill}{timeout});
		}
	}


	##### ITEMS AUTO-GATHER #####

	if ((AI::isIdle || existsInList("follow,route,mapRoute", AI::action))
		&& $config{itemsGatherAuto}
		&& !(percent_weight($char) >= $config{itemsMaxWeight})
		&& timeOut(\%{$timeout{ai_items_gather_auto}})) {

		my @ai_gather_playerID;
		foreach (@playersID) {
			next if ($_ eq "");
			if (!%{$char->{party}} || !%{$char->{party}{users}{$_}}) {
				push @ai_gather_playerID, $_;
			}
		}
		foreach $item (@itemsID) {
			next if ($item eq ""
				|| time - $items{$item}{appear_time} < $timeout{ai_items_gather_start}{timeout}
				|| $items{$item}{take_failed} >= 1
				|| $itemsPickup{lc($items{$item}{name})} eq "0" || (!$itemsPickup{all} && !$itemsPickup{lc($items{$item}{name})}));

			my $found = 0;
			foreach (@ai_gather_playerID) {
				if (distance(\%{$items{$item}{pos}}, \%{$players{$_}{pos_to}}) < 9) {
					$found = 1;
					last;
				}
			}
			if (!$found) {
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
		my $found = 0;
		my @ai_gather_playerID;
		
		foreach (@playersID) {
			next if ($_ eq "");
			if (!%{$char->{party}} || !%{$char->{party}{users}{$_}}) {
				push @ai_gather_playerID, $_;
			}
		}
		foreach (@ai_gather_playerID) {
			if (distance(\%{$items{$ID}{pos}}, \%{$players{$_}{pos_to}}) < 9) {
				$found++;
				last;
			}
		}
		my $dist = distance(\%{$items{$ID}{pos}}, \%{$char->{pos_to}});
		if (timeOut(AI::args->{ai_items_gather_giveup})) {
			message "Failed to gather $items{$ID}{name} ($items{$ID}{binID}) : Timeout\n",,1;
			$items{$ID}{take_failed}++;
			AI::dequeue;
		} elsif ($char->{sitting}) {
			AI::suspend();
			stand();
		} elsif ($found == 0 && $dist > 2) {
			my %vec, %pos;
			getVector(\%vec, \%{$items{$ID}{pos}}, \%{$char->{pos_to}});
			moveAlongVector(\%pos, \%{$char->{pos_to}}, \%vec, $dist - 1);
			move($pos{x}, $pos{y});
		} elsif ($found == 0) {
			AI::dequeue;
			take($ID);
		} elsif ($found > 0) {
			message "Failed to gather $items{$ID}{name} ($items{$ID}{binID}) : No looting!\n",,1;
			AI::dequeue;
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
		my $dist = distance(\%{$items{$ID}{pos}}, \%{$char->{pos_to}});
		
		if ($char->{sitting}) {
			stand();

		} elsif ($dist > 2) {
			my %vec, %pos;
			getVector(\%vec, \%{$items{$ID}{pos}}, \%{$char->{pos_to}});
			moveAlongVector(\%pos, \%{$char->{pos_to}}, \%vec, $dist - 1);
			move($pos{x}, $pos{y});

		} elsif (timeOut(\%{$timeout{ai_take}})) {
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

		} elsif (time > AI::action->{retry}) {
			# No update yet, send move request again.
			# We do this every 0.5 secs
			AI::action->{retry} = time + 0.5;
			sendMove(\$remote_socket, AI::args->{move_to}{x}, AI::args->{move_to}{y});
		}
	}

	##### AUTO-TELEPORT #####
	TELEPORT: {
	my $map_name_lu = $field{name}.'.rsw';
	my $ai_teleport_safe = 0;

	if ($config{teleportAuto_onlyWhenSafe} && scalar(@playersID)) {
		if (!$cities_lut{$map_name_lu} && timeOut(\%{$timeout{ai_teleport_safe_force}})) {
			$ai_teleport_safe = 1;
		}
	} elsif (!$cities_lut{$map_name_lu}) {
		$ai_teleport_safe = 1;
		$timeout{ai_teleport_safe_force}{time} = time;
	}

	##### TELEPORT HP #####
	if (((($config{teleportAuto_hp} && percent_hp($char) <= $config{teleportAuto_hp}) || ($config{teleportAuto_sp} && percent_sp($char) <= $config{teleportAuto_sp})) && scalar(ai_getAggressives()) || ($config{teleportAuto_minAggressives} && scalar(ai_getAggressives()) >= $config{teleportAuto_minAggressives}))
		&& $ai_teleport_safe 
		&& timeOut(\%{$timeout{ai_teleport_hp}})) {
		useTeleport(1);
		$ai_v{temp}{clear_aiQueue} = 1;
		$timeout{ai_teleport_hp}{time} = time;
	}

	##### TELEPORT MONSTER #####
	if (timeOut(\%{$timeout{ai_teleport_away}}) && $ai_teleport_safe) {
		foreach (@monstersID) {
			if ($mon_control{lc($monsters{$_}{name})}{teleport_auto} == 1) {
				useTeleport(1);
				$ai_v{temp}{clear_aiQueue} = 1;
				last;
			}
		}
		$timeout{'ai_teleport_away'}{'time'} = time;
	}

	##### TELEPORT SEARCH #####
	if (($config{teleportAuto_search} &&  AI::inQueue("sitAuto","sitting","attack","follow","items_take","buyAuto","skill_use","sellAuto","storageAuto")) || !$config{attackAuto}){
		$timeout{ai_teleport_search}{time} = time;
	}

	if ($config{teleportAuto_search} && $ai_teleport_safe
		&& ($field{name} eq $config{lockMap} || $config{lockMap} eq "")
		&& timeOut(\%{$timeout{ai_teleport_search}})){

		my $do_search = 0;
		foreach (keys %mon_control) {
			if ($mon_control{$_}{teleport_search}) {
				$do_search = 1;
				last;
			}
		}
		if ($do_search) {
			my $found = 0;
			foreach (@monstersID) {
				if ($mon_control{lc($monsters{$_}{name})}{teleport_search}  && !$monsters{$_}{attackedByPlayer} && !$monsters{$_}{attack_failed}) {
					$found = 1;
					last;
				}
			}
			if (!$found) {
				useTeleport(1);
				$ai_v{temp}{clear_aiQueue} = 1;
			}
		
		}
		$timeout{ai_teleport_search}{time} = time;
	}

	##### TELEPORT IDLE / PORTAL #####
	if ($config{teleportAuto_idle} && AI::action ne "") {
		$timeout{ai_teleport_idle}{time} = time;
	}

	if ($config{teleportAuto_idle} && $ai_teleport_safe && timeOut(\%{$timeout{ai_teleport_idle}})){
		useTeleport(1);
		$ai_v{temp}{clear_aiQueue} = 1;
		$timeout{ai_teleport_idle}{time} = time;
	}

	if ($config{teleportAuto_portal} && $ai_teleport_safe
		&& ($config{'lockMap'} eq "" || $config{lockMap} eq $field{name})
		&& timeOut($timeout{'ai_teleport_portal'})) {
		if (scalar(@portalsID)) {
			useTeleport(1);
			$ai_v{temp}{clear_aiQueue} = 1;
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
	if (timeOut(\%{$timeout{ai_avoidcheck}})) {
		avoidGM_near() if ($config{avoidGM_near} && (!$config{avoidGM_near_inTown} || !$cities_lut{$field{name}.'.rsw'}));
		avoidList_near() if $config{avoidList};
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

	if ($config{shopAuto_open} && !AI::isIdle) {
		$timeout{ai_shop}{time} = time;
	}
	if ($config{shopAuto_open} && AI::isIdle && $conState == 5 && !$char->{sitting} && timeOut(\%{$timeout{ai_shop}}) && !$shopstarted) {
		openShop();
	}


	##########

	# DEBUG CODE
	if (time - $ai_v{'time'} > 2 && $config{'debug'} >= 2) {
		my $len = @ai_seq_args;
		debug "AI: @ai_seq | $len\n", "ai", 2;
		$ai_v{'time'} = time;
	}
	$ai_v{'AI_last_finished'} = time;

	if ($ai_v{temp}{clear_aiQueue}) {
		delete $ai_v{temp}{clear_aiQueue};
		AI::clear;
	}	
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
	debug "Packet Switch SENT_BY_CLIENT: $switch\n", "parseSendMsg", 0 if ($config{'debugPacket_ro_sent'} && !existsInList($config{'debugPacket_exclude'}, $switch));

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
		aiRemove("clientSuspend");
		makeCoords(\%coords, substr($msg, 2, 3));
		ai_clientSuspend($switch, (distance($char->{'pos'}, \%coords) * $char->{walk_speed}) + 4);

	} elsif ($switch eq "0089") {
		# Attack
		if (!($config{'tankMode'} && binFind(\@ai_seq, "attack") ne "")) {
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
		if ($chat =~ /^$config{'commandPrefix'}/) {
			$chat =~ s/^$config{'commandPrefix'}//;
			$chat =~ s/^\s*//;
			$chat =~ s/\s*$//;
			$chat =~ s/\000*$//;
			parseInput($chat, 1);
			undef $sendMsg;
		}

	} elsif ($switch eq "0096") {
		# Private message
		$length = unpack("S",substr($msg,2,2));
		($user) = substr($msg, 4, 24) =~ /([\s\S]*?)\000/;
		$chat = substr($msg, 28, $length - 29);
		$chat =~ s/^\s*//;
		if ($chat =~ /^$config{'commandPrefix'}/) {
			$chat =~ s/^$config{'commandPrefix'}//;
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
	}

	if ($sendMsg ne "") {
		sendToServerByInject(\$remote_socket, $sendMsg);
	}

	# What's this doing here?
	Plugins::callHook('AI_post');
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
	debug "Packet Switch: $switch\n", "parseMsg", 0 if ($config{'debugPacket_received'} && !existsInList($config{'debugPacket_exclude'}, $switch));

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
		if ($rpackets{$switch} eq "-") {
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
		if ($type == 0) {
			error("Account name doesn't exist\n", "connection");
			if (!$config{'XKore'} && !$config{ignoreInvalidLogin}) {
				message("Enter Username Again: ", "input");
				$msg = $interface->getInput(-1);
				configModify('username', $msg, 1);
			}
			relog();
		} elsif ($type == 1) {
			error("Password Error\n", "connection");
			if (!$config{'XKore'}) {
				message("Enter Password Again: ", "input");
				$msg = $interface->getInput(-1);
				configModify('password', $msg, 1);
			}
		} elsif ($type == 3) {
			error("Server connection has been denied\n", "connection");
		} elsif ($type == 4) {
			$interface->errorDialog("Critical Error: Your account has been blocked.");
			$quit = 1 if (!$config{'XKore'});
		} elsif ($type == 5) {
			$masterver = $config{"master_version_$config{'master'}"};
			error("Version $config{'version'} failed...trying to find version\n", "connection");
			error("Master Version: $masterver\n", "connection");
			$config{'version'}++;
			if (!$versionSearch) {
				$config{'version'} = 0;
				$versionSearch = 1;
			} elsif ($config{'version'} eq 51) {
				$config{"master_version_$config{'master'}"}++;
				$config{'version'} = 0;
			}
			relog();
		} elsif ($type == 6) {
			error("The server is temporarily blocking your connection\n", "connection");
		}
		if ($type != 5 && $versionSearch) {
			$versionSearch = 0;
			Misc::saveConfigFile();
		}

	} elsif ($switch eq "006B") {
		message("Received characters from Game Login Server\n", "connection");
		$conState = 3;
		undef $conState_tries;
		undef @chars;

		#my ($startVal, $num);
		#if ($config{"master_version_$config{'master'}"} ne "" && $config{"master_version_$config{'master'}"} == 0) {
		#	$startVal = 24;
		#} else {
		#	$startVal = 4;
		#}
		$startVal = $msg_size % 106;

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
			$chars[$num]{'ID'} = substr($msg, $i, 4) ;
			$chars[$num]{'lv'} = unpack("C1", substr($msg, $i + 58, 1));
			($chars[$num]{'name'}) = substr($msg, $i + 74, 24) =~ /([\s\S]*?)\000/;
			$chars[$num]{'str'} = unpack("C1", substr($msg, $i + 98, 1));
			$chars[$num]{'agi'} = unpack("C1", substr($msg, $i + 99, 1));
			$chars[$num]{'vit'} = unpack("C1", substr($msg, $i + 100, 1));
			$chars[$num]{'int'} = unpack("C1", substr($msg, $i + 101, 1));
			$chars[$num]{'dex'} = unpack("C1", substr($msg, $i + 102, 1));
			$chars[$num]{'luk'} = unpack("C1", substr($msg, $i + 103, 1));
			$chars[$num]{'sex'} = $accountSex2;
		}

		for ($num = 0; $num < @chars; $num++) {
			message(swrite(
				"-------  Character @< ---------",
				[$num],
				"Name: @<<<<<<<<<<<<<<<<<<<<<<<<",
				[$chars[$num]{'name'}],
				"Job:  @<<<<<<<      Job Exp: @<<<<<<<",
				[$jobs_lut{$chars[$num]{'jobID'}}, $chars[$num]{'exp_job'}],
				"Lv:   @<<<<<<<      Str: @<<<<<<<<",
				[$chars[$num]{'lv'}, $chars[$num]{'str'}],
				"J.Lv: @<<<<<<<      Agi: @<<<<<<<<",
				[$chars[$num]{'lv_job'}, $chars[$num]{'agi'}],
				"Exp:  @<<<<<<<      Vit: @<<<<<<<<",
				[$chars[$num]{'exp'}, $chars[$num]{'vit'}],
				"HP:   @||||/@||||   Int: @<<<<<<<<",
				[$chars[$num]{'hp'}, $chars[$num]{'hp_max'}, $chars[$num]{'int'}],
				"SP:   @||||/@||||   Dex: @<<<<<<<<",
				[$chars[$num]{'sp'}, $chars[$num]{'sp_max'}, $chars[$num]{'dex'}],
				"Zenny: @<<<<<<<<<<  Luk: @<<<<<<<<",
				[$chars[$num]{'zenny'}, $chars[$num]{'luk'}],
				"-------------------------------", []),
				"connection");

 		}

		if (!$config{'XKore'}) {
			if ($config{'char'} eq "") {
				message("Choose your character.  Enter the character number:\n", "input");
				$waitingForInput = 1;
			} else {
				message("Character $config{'char'} selected\n", "connection");
				sendCharLogin(\$remote_socket, $config{'char'});
				$timeout{'charlogin'}{'time'} = time;
			}
		}
		$firstLoginMap = 1;
		$startingZenny = $chars[$config{'char'}]{'zenny'} unless defined $startingZenny;
		$sentWelcomeMessage = 1;

	} elsif ($switch eq "006C") {
		error("Error logging into Game Login Server (invalid character specified)...\n", "connection");
		$conState = 1;
		undef $conState_tries;
		$timeout_ex{'master'}{'time'} = time;
		$timeout_ex{'master'}{'timeout'} = $timeout{'reconnect'}{'timeout'};
		Network::disconnect(\$remote_socket);

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

	} elsif ($switch eq "0078") {
		# 0078: long ID, word speed, word opt1, word opt2, word option, word class, word hair,
		# word weapon, word head_option_bottom, word sheild, word head_option_top, word head_option_mid,
		# word hair_color, word ?, word head_dir, long guild, long emblem, word manner, byte karma,
		# byte sex, 3byte X_Y_dir, byte ?, byte ?, byte sit, byte level
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		my $ID = substr($msg, 2, 4);
		makeCoords(\%coords, substr($msg, 46, 3));
		my $type = unpack("S*",substr($msg, 14,  2));
		my $pet = unpack("C*",substr($msg, 16,  1));
		my $sex = unpack("C*",substr($msg, 45,  1));
		my $sitting = unpack("C*",substr($msg, 51,  1));

		if ($jobs_lut{$type}) {
			if (!defined($players{$ID}{binID})) {
				$players{$ID}{'appear_time'} = time;
				binAdd(\@playersID, $ID);
				$players{$ID}{'jobID'} = $type;
				$players{$ID}{'sex'} = $sex;
				$players{$ID}{'name'} = "Unknown";
				$players{$ID}{'nameID'} = unpack("L1", $ID);
				$players{$ID}{'binID'} = binFind(\@playersID, $ID);
			}
			$players{$ID}{'sitting'} = $sitting > 0;
			%{$players{$ID}{'pos'}} = %coords;
			%{$players{$ID}{'pos_to'}} = %coords;
			debug "Player Exists: $players{$ID}{'name'} ($players{$ID}{'binID'}) $sex_lut{$players{$ID}{'sex'}} $jobs_lut{$players{$ID}{'jobID'}}\n", "parseMsg_presence", 1;

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
				%{$pets{$ID}{'pos'}} = %coords;
				%{$pets{$ID}{'pos_to'}} = %coords;
				debug "Pet Exists: $pets{$ID}{'name'} ($pets{$ID}{'binID'})\n", "parseMsg";
			} else {
				if (!%{$monsters{$ID}}) {
					$monsters{$ID}{'appear_time'} = time;
					$display = ($monsters_lut{$type} ne "") 
							? $monsters_lut{$type}
							: "Unknown ".$type;
					binAdd(\@monstersID, $ID);
					$monsters{$ID}{'nameID'} = $type;
					$monsters{$ID}{'name'} = $display;
					$monsters{$ID}{'binID'} = binFind(\@monstersID, $ID);
				}
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
			}
			%{$npcs{$ID}{'pos'}} = %coords;
			message "NPC Exists: $npcs{$ID}{'name'} ($npcs{$ID}{pos}->{x}, $npcs{$ID}{pos}->{y}) (ID $npcs{$ID}{'nameID'}) - ($npcs{$ID}{'binID'})\n", undef, 1;

		} else {
			debug "Unknown Exists: $type - ".unpack("L*",$ID)."\n", "parseMsg";
		}

	} elsif ($switch eq "0079") {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		my $ID = substr($msg, 2, 4);
		makeCoords(\%coords, substr($msg, 46, 3));
		my $type = unpack("S*",substr($msg, 14,  2));
		my $sex = unpack("C*",substr($msg, 45,  1));

		if ($jobs_lut{$type}) {
			if (!defined($players{$ID}{binID})) {
				$players{$ID}{'appear_time'} = time;
				binAdd(\@playersID, $ID);
				$players{$ID}{'jobID'} = $type;
				$players{$ID}{'sex'} = $sex;
				$players{$ID}{'name'} = "Unknown";
				$players{$ID}{'nameID'} = unpack("L1", $ID);
				$players{$ID}{'binID'} = binFind(\@playersID, $ID);
			}
			%{$players{$ID}{'pos'}} = %coords;
			%{$players{$ID}{'pos_to'}} = %coords;
			debug "Player Connected: $players{$ID}{'name'} ($players{$ID}{'binID'}) $sex_lut{$players{$ID}{'sex'}} $jobs_lut{$players{$ID}{'jobID'}}\n", "parseMsg";

		} else {
			debug "Unknown Connected: $type - ", "parseMsg";
		}

	} elsif ($switch eq "007A") {
		$conState = 5 if ($conState != 4 && $config{'XKore'});

	} elsif ($switch eq "007B") {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		$ID = substr($msg, 2, 4);
		makeCoords(\%coordsFrom, substr($msg, 50, 3));
		makeCoords2(\%coordsTo, substr($msg, 52, 3));
		$type = unpack("S*",substr($msg, 14,  2));
		$pet = unpack("C*",substr($msg, 16,  1));
		$sex = unpack("C*",substr($msg, 49,  1));

		if ($jobs_lut{$type}) {
			if (!defined($players{$ID}{binID})) {
				binAdd(\@playersID, $ID);
				$players{$ID}{'appear_time'} = time;
				$players{$ID}{'sex'} = $sex;
				$players{$ID}{'jobID'} = $type;
				$players{$ID}{'name'} = "Unknown";
				$players{$ID}{'nameID'} = unpack("L1", $ID);
				$players{$ID}{'binID'} = binFind(\@playersID, $ID);
				
				debug "Player Appeared: $players{$ID}{'name'} ($players{$ID}{'binID'}) $sex_lut{$sex} $jobs_lut{$type}\n", "parseMsg_presence";
			}
			%{$players{$ID}{'pos'}} = %coordsFrom;
			%{$players{$ID}{'pos_to'}} = %coordsTo;
			debug "Player Moved: $players{$ID}{'name'} ($players{$ID}{'binID'}) $sex_lut{$players{$ID}{'sex'}} $jobs_lut{$players{$ID}{'jobID'}}\n", "parseMsg";

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
				%{$pets{$ID}{'pos'}} = %coords;
				%{$pets{$ID}{'pos_to'}} = %coords;
				if (%{$monsters{$ID}}) {
					binRemove(\@monstersID, $ID);
					delete $monsters{$ID};
				}
				debug "Pet Moved: $pets{$ID}{'name'} ($pets{$ID}{'binID'})\n", "parseMsg";
			} else {
				if (!%{$monsters{$ID}}) {
					binAdd(\@monstersID, $ID);
					$monsters{$ID}{'appear_time'} = time;
					$monsters{$ID}{'nameID'} = $type;
					$display = ($monsters_lut{$type} ne "") 
						? $monsters_lut{$type}
						: "Unknown ".$type;
					$monsters{$ID}{'nameID'} = $type;
					$monsters{$ID}{'name'} = $display;
					$monsters{$ID}{'binID'} = binFind(\@monstersID, $ID);
					debug "Monster Appeared: $monsters{$ID}{'name'} ($monsters{$ID}{'binID'})\n", "parseMsg_presence";
				}
				%{$monsters{$ID}{'pos'}} = %coordsFrom;
				%{$monsters{$ID}{'pos_to'}} = %coordsTo;
				debug "Monster Moved: $monsters{$ID}{'name'} ($monsters{$ID}{'binID'})\n", "parseMsg", 2;
			}
		} else {
			debug "Unknown Moved: $type - ".getHex($ID)."\n", "parseMsg";
		}

	} elsif ($switch eq "007C") {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		$ID = substr($msg, 2, 4);
		makeCoords(\%coords, substr($msg, 36, 3));
		$type = unpack("S*",substr($msg, 20,  2));
		$pet = unpack("C*",substr($msg, 22,  1));
		$sex = unpack("C*",substr($msg, 35,  1));

		if ($jobs_lut{$type}) {
			if (!defined($players{$ID}{binID})) {
				binAdd(\@playersID, $ID);
				$players{$ID}{'jobID'} = $type;
				$players{$ID}{'sex'} = $sex;
				$players{$ID}{'name'} = "Unknown";
				$players{$ID}{'nameID'} = unpack("L1", $ID);
				$players{$ID}{'appear_time'} = time;
				$players{$ID}{'binID'} = binFind(\@playersID, $ID);
			}
			%{$players{$ID}{'pos'}} = %coords;
			%{$players{$ID}{'pos_to'}} = %coords;
			debug "Player Spawned: $players{$ID}{'name'} ($players{$ID}{'binID'}) $sex_lut{$players{$ID}{'sex'}} $jobs_lut{$players{$ID}{'jobID'}}\n", "parseMsg";

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
				%{$pets{$ID}{'pos'}} = %coords; 
				%{$pets{$ID}{'pos_to'}} = %coords; 
				debug "Pet Spawned: $pets{$ID}{'name'} ($pets{$ID}{'binID'})\n", "parseMsg";
			} else {
				if (!%{$monsters{$ID}}) {
					binAdd(\@monstersID, $ID);
					$monsters{$ID}{'nameID'} = $type;
					$monsters{$ID}{'appear_time'} = time;
					$display = ($monsters_lut{$monsters{$ID}{'nameID'}} ne "") 
							? $monsters_lut{$monsters{$ID}{'nameID'}}
							: "Unknown ".$monsters{$ID}{'nameID'};
					$monsters{$ID}{'name'} = $display;
					$monsters{$ID}{'binID'} = binFind(\@monstersID, $ID);
				}
				%{$monsters{$ID}{'pos'}} = %coords;
				%{$monsters{$ID}{'pos_to'}} = %coords;
				debug "Monster Spawned: $monsters{$ID}{'name'} ($monsters{$ID}{'binID'})\n", "parseMsg";
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
				debug "Monster Died: $monsters{$ID}{'name'} ($monsters{$ID}{'binID'})\n", "parseMsg";
				$monsters_old{$ID}{'dead'} = 1;
			}
			binRemove(\@monstersID, $ID);
			delete $monsters{$ID};

		} elsif (%{$players{$ID}}) {
			if ($type == 1) {
				message "Player Died: $players{$ID}{'name'} ($players{$ID}{'binID'}) $sex_lut{$players{$ID}{'sex'}} $jobs_lut{$players{$ID}{'jobID'}}\n";
				$players{$ID}{'dead'} = 1;
			} else {
				if ($type == 0) {
					debug "Player Disappeared: $players{$ID}{'name'} ($players{$ID}{'binID'}) $sex_lut{$players{$ID}{'sex'}} $jobs_lut{$players{$ID}{'jobID'}}\n", "parseMsg";
					$players{$ID}{'disappeared'} = 1;
				} elsif ($type == 2) {
					debug "Player Disconnected: $players{$ID}{'name'} ($players{$ID}{'binID'}) $sex_lut{$players{$ID}{'sex'}} $jobs_lut{$players{$ID}{'jobID'}}\n", "parseMsg";
					$players{$ID}{'disconnected'} = 1;
				} elsif ($type == 3) {
					debug "Player Teleported: $players{$ID}{'name'} ($players{$ID}{'binID'}) $sex_lut{$players{$ID}{'sex'}} $jobs_lut{$players{$ID}{'jobID'}}\n", "parseMsg";
					$players{$ID}{'teleported'} = 1;
				} else {
					debug "Player Disappeared in an unknown way: $players{$ID}{'name'} ($players{$ID}{'binID'}) $sex_lut{$players{$ID}{'sex'}} $jobs_lut{$players{$ID}{'jobID'}}\n", "parseMsg";
					$players{$ID}{'disappeared'} = 1;
				}

				%{$players_old{$ID}} = %{$players{$ID}};
				$players_old{$ID}{'gone_time'} = time;
				binRemove(\@playersID, $ID);
				delete $players{$ID};

				binRemove(\@venderListsID, $ID);
				delete $venderLists{$ID};
			}

		} elsif (%{$players_old{$ID}}) {
			if ($type == 2) {
				debug "Player Disconnected: $players_old{$ID}{'name'}\n", "parseMsg";
				$players_old{$ID}{'disconnected'} = 1;
			} elsif ($type == 3) {
				debug "Player Teleported: $players_old{$ID}{'name'}\n", "parseMsg";
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
		# Long distance attack solution
		$ID = substr($msg, 2, 4);
		undef %coords;
		$coords{'x'} = unpack("S1", substr($msg, 6, 2));
		$coords{'y'} = unpack("S1", substr($msg, 8, 2));
		if ($ID eq $accountID) {
			%{$chars[$config{'char'}]{'pos'}} = %coords;
			%{$chars[$config{'char'}]{'pos_to'}} = %coords;
			debug "Movement interrupted, your coordinates: $chars[$config{'char'}]{'pos'}{'x'}, $chars[$config{'char'}]{'pos'}{'y'}\n", "parseMsg_move";
			aiRemove("move");
		} elsif (%{$monsters{$ID}}) {
			%{$monsters{$ID}{'pos'}} = %coords;
			%{$monsters{$ID}{'pos_to'}} = %coords;
		} elsif (%{$players{$ID}}) {
			%{$players{$ID}{'pos'}} = %coords;
			%{$players{$ID}{'pos_to'}} = %coords;
		}
		# End of Long Distance attack Solution

	} elsif ($switch eq "008A") {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		my ($ID1, $ID2, $tick, $src_speed, $dst_speed, $damage, $param2, $type, $param3) = unpack("x2 a4 a4 a4 L1 L1 S1 S1 C1 S1", $msg);

		if ($type == 1) {
			# Take item
			my ($source, $verb, $target) = getActorNames($ID1, $ID2, 'pick up', 'picks up');
			debug "$source $verb $target\n", 'parseMsg';
			$items{$ID2}{takenBy} = $ID1;
		} elsif ($type == 2) {
			# Sit
			my ($source, $verb) = getActorNames($ID1, 0, 'are', 'is');
			if ($ID1 eq $accountID) {
				message "You are sitting.\n";
				$char->{sitting} = 1;
			} else {
				debug getActorName($ID1)." is sitting.\n", 'parseMsg';
				$players{$ID1}{sitting} = 1;
			}
		} elsif ($type == 3) {
			# Stand
			my ($source, $verb) = getActorNames($ID1, 0, 'are', 'is');
			if ($ID1 eq $accountID) {
				message "You are standing.\n";
				$char->{sitting} = 0;
			} else {
				debug getActorName($ID1)." is standing.\n", 'parseMsg';
				$players{$ID1}{sitting} = 0;
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

				# FIXME: param3 is only meaningful if this is not an attack
				# made by a monster. How can you tell if it's a monster?
				# You could check %monsters but there should be a better
				# way...?
				$dmgdisplay .= " + $param3" if $param3;
			}

			updateDamageTables($ID1, $ID2, $damage);

			my ($source, $verb, $target) = getActorNames($ID1, $ID2, 'attack', 'attacks');
			my $msg = "$source $verb $target - Dmg: $dmgdisplay";

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
				# FIXME: This assumes that if you're attacked, the spell
				# you were casting got stopped. But what about Phen card,
				# Endure, Sacrifice, dodge, etc.?
				undef $char->{time_cast};
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

		my %item;
		$item{type} = "c";
		$item{ID} = $ID;
		$item{user} = $chatMsgUser;
		$item{msg} = $chatMsg;
		$item{time} = time;
		binAdd(\@ai_cmdQue, \%item);
		$ai_cmdQue++;

		chatLog("c", "$chat\n") if ($config{'logChat'});
		message "$chat\n", "publicchat";

		Plugins::callHook('packet_pubMsg', { 
			pubMsgUser => $chatMsgUser, 
			pubMsg => $chatMsg 
		}); 

	} elsif ($switch eq "008E") {
		$chat = substr($msg, 4, $msg_size - 4);
		$chat =~ s/\000//g;
		($chatMsgUser, $chatMsg) = $chat =~ /([\s\S]*?) : ([\s\S]*)/;

		chatLog("c", $chat."\n") if ($config{'logChat'});
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
		while ($config{"useSelf_item_$i"}) {
			$ai_v{"useSelf_item_$i"."_time"} = 0;
			$i++;
		}
		$i = 0;
		while ($config{"useSelf_skill_$i"}) {
			$ai_v{"useSelf_skill_$i"."_time"} = 0;
			$i++;
		}
		undef %{$chars[$config{char}]{statuses}} if ($chars[$config{char}]{statuses});

	} elsif ($switch eq "0095") {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		$ID = substr($msg, 2, 4);
		if (%{$players{$ID}}) {
			($players{$ID}{'name'}) = substr($msg, 6, 24) =~ /([\s\S]*?)\000/;
			if ($config{'debug'} >= 2) {
				$binID = binFind(\@playersID, $ID);
				debug "Player Info: $players{$ID}{'name'} ($binID)\n", "parseMsg", 2;
			}
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
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		decrypt(\$newmsg, substr($msg, 28, length($msg)-28));
		$msg = substr($msg, 0, 28).$newmsg;
		my ($privMsgUser) = substr($msg, 4, 24) =~ /([\s\S]*?)\000/;
		my $privMsg = substr($msg, 28, $msg_size - 29);
		if ($privMsgUser ne "" && binFind(\@privMsgUsers, $privMsgUser) eq "") {
			$privMsgUsers[@privMsgUsers] = $privMsgUser;
		}

		my %item;
		$item{type} = "pm";
		$item{user} = $privMsgUser;
		$item{msg} = $privMsg;
		$item{time} = time;
		binAdd(\@ai_cmdQue, \%item);
		$ai_cmdQue++;

		chatLog("pm", "(From: $privMsgUser) : $privMsg\n") if ($config{'logPrivateChat'});
		message "(From: $privMsgUser) : $privMsg\n", "pm";

		Plugins::callHook('packet_privMsg', {
			privMsgUser => $privMsgUser,
			privMsg => $privMsg
			});

	} elsif ($switch eq "0098") {
		$type = unpack("C1",substr($msg, 2, 1));
		if ($type == 0) {
			message "(To $lastpm[0]{'user'}) : $lastpm[0]{'msg'}\n", "pm";
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

		my %item;
		$item{type} = "gmchat";
		$item{msg} = $chatMsg;
		$item{time} = time;
		binAdd(\@ai_cmdQue, \%item);
		$ai_cmdQue++;
		chatLog("s", $chat."\n") if ($config{'logSystemChat'});
		message "$chat\n", "schat";

	} elsif ($switch eq "009C") {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		$ID = substr($msg, 2, 4);
		$body = unpack("C1",substr($msg, 8, 1));
		$head = unpack("C1",substr($msg, 6, 1));
		if ($ID eq $accountID) {
			$chars[$config{'char'}]{'look'}{'head'} = $head;
			$chars[$config{'char'}]{'look'}{'body'} = $body;
			debug "You look at $chars[$config{'char'}]{'look'}{'body'}, $chars[$config{'char'}]{'look'}{'head'}\n", "parseMsg", 2;

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
		message "Item Appeared: $items{$ID}{'name'} ($items{$ID}{'binID'}) x $items{$ID}{'amount'}\n", "drop", 1;

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

		} elsif ($fail == 6) {
			message "Can't loot item...wait...\n", "drop";
		}

	} elsif ($switch eq "00A1") {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		$ID = substr($msg, 2, 4);
		if (%{$items{$ID}}) {
			debug "Item Disappeared: $items{$ID}{'name'} ($items{$ID}{'binID'})\n", "parseMsg";
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
		undef $invIndex;

		for($i = 4; $i < $msg_size; $i += $psize) {
			$index = unpack("S1", substr($msg, $i, 2));
			$ID = unpack("S1", substr($msg, $i + 2, 2));
			$invIndex = findIndex(\@{$chars[$config{'char'}]{'inventory'}}, "index", $index);
			if ($invIndex eq "") {
				$invIndex = findIndex(\@{$chars[$config{'char'}]{'inventory'}}, "nameID", "");
			}
			$chars[$config{'char'}]{'inventory'}[$invIndex]{'index'} = $index;
			$chars[$config{'char'}]{'inventory'}[$invIndex]{'nameID'} = $ID;
			$chars[$config{'char'}]{'inventory'}[$invIndex]{'amount'} = unpack("S1", substr($msg, $i + 6, 2));
			$chars[$config{'char'}]{'inventory'}[$invIndex]{'type'} = unpack("C1", substr($msg, $i + 4, 1));
			$display = ($items_lut{$chars[$config{'char'}]{'inventory'}[$invIndex]{'nameID'}} ne "")
				? $items_lut{$chars[$config{'char'}]{'inventory'}[$invIndex]{'nameID'}}
				: "Unknown ".$chars[$config{'char'}]{'inventory'}[$invIndex]{'nameID'};
			$chars[$config{'char'}]{'inventory'}[$invIndex]{'name'} = $display;
			debug "Inventory: $chars[$config{'char'}]{'inventory'}[$invIndex]{'name'} ($invIndex) x $chars[$config{'char'}]{'inventory'}[$invIndex]{'amount'} - $itemTypes_lut{$chars[$config{'char'}]{'inventory'}[$invIndex]{'type'}}\n", "parseMsg";
			Plugins::callHook('packet_inventory', {index => $invIndex});
		}

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
		my $invIndex = findIndex(\@{$chars[$config{'char'}]{'inventory'}}, "index", $index);
		$chars[$config{'char'}]{'inventory'}[$invIndex]{'amount'} -= $amount;
		message "You used Item: $chars[$config{'char'}]{'inventory'}[$invIndex]{'name'} ($invIndex) x $amount\n", "useItem";
		if ($chars[$config{'char'}]{'inventory'}[$invIndex]{'amount'} <= 0) {
			delete $chars[$config{'char'}]{'inventory'}[$invIndex];
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
		$index = unpack("S1",substr($msg, 2, 2));
		$amount = unpack("S1",substr($msg, 4, 2));
		undef $invIndex;
		$invIndex = findIndex(\@{$chars[$config{'char'}]{'inventory'}}, "index", $index);
		if (!$chars[$config{'char'}]{'arrow'} || ($chars[$config{'char'}]{'arrow'} && !($chars[$config{'char'}]{'inventory'}[$invIndex]{'name'} =~/arrow/i))) {
			message "Inventory Item Removed: $chars[$config{'char'}]{'inventory'}[$invIndex]{'name'} ($invIndex) x $amount\n", "inventory";
		}
		$chars[$config{'char'}]{'inventory'}[$invIndex]{'amount'} -= $amount;
		if ($chars[$config{'char'}]{'inventory'}[$invIndex]{'amount'} <= 0) {
			delete $chars[$config{'char'}]{'inventory'}[$invIndex];
		}

	} elsif ($switch eq "00B0") {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		my $type = unpack("S1",substr($msg, 2, 2));
		my $val = unpack("L1",substr($msg, 4, 4));
		if ($type == 0) {
			$char->{'walk_speed'} = $val / 1000;
			debug "Walk speed: $val\n", "parseMsg", 2;
		} elsif ($type == 3) {
			debug "Something2: $val\n", "parseMsg", 2;
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
		$type = unpack("S1",substr($msg, 2, 2));
		$val = unpack("L1",substr($msg, 4, 4));
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
			message "Exp gained: $monsterBaseExp/$monsterJobExp\n","exp";
			
		} elsif ($type == 20) {
			$chars[$config{'char'}]{'zenny'} = $val;
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
		message "$npcs{$ID}{'name'} : $talk{'msg'}\n", "npc";

	} elsif ($switch eq "00B5") {
		# 00b5: long ID
		# "Next" button appeared on the NPC message dialog
		my $ID = substr($msg, 2, 4);
		if ($config{autoTalkCont}) {
			sendTalkContinue(\$remote_socket, $ID);
		} else {
			message "$npcs{$ID}{'name'} : Type 'talk cont' to continue talking\n", "npc";
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
			} elsif ($type == 14) {
				$chars[$config{'char'}]{'agi'} = $val;
				debug "Agility: $val\n", "parseMsg";
			} elsif ($type == 15) {
				$chars[$config{'char'}]{'vit'} = $val;
				debug "Vitality: $val\n", "parseMsg";
			} elsif ($type == 16) {
				$chars[$config{'char'}]{'int'} = $val;
				debug "Intelligence: $val\n", "parseMsg";
			} elsif ($type == 17) {
				$chars[$config{'char'}]{'dex'} = $val;
				debug "Dexterity: $val\n", "parseMsg";
			} elsif ($type == 18) {
				$chars[$config{'char'}]{'luk'} = $val;
				debug "Luck: $val\n", "parseMsg";
			} else {
				debug "Something: $val\n", "parseMsg";
			}
		}
		Plugins::callHook('packet_charStats', {
			'type'	=> $type,
			'val'	=> $val,
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
		$users = unpack("L*", substr($msg, 2, 4));
		message "There are currently $users users online\n", "info";

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
		$index = unpack("S1", substr($msg, 2, 2));
		undef $invIndex;
		if ($index > 0) {
			$invIndex = findIndex(\@{$chars[$config{'char'}]{'inventory'}}, "index", $index);
			$currentDeal{'you'}{$chars[$config{'char'}]{'inventory'}[$invIndex]{'nameID'}}{'amount'} += $currentDeal{'lastItemAmount'};
			$chars[$config{'char'}]{'inventory'}[$invIndex]{'amount'} -= $currentDeal{'lastItemAmount'};
			message "You added Item to Deal: $chars[$config{'char'}]{'inventory'}[$invIndex]{'name'} x $currentDeal{'lastItemAmount'}\n", "deal";
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
		$storage{'items'} = unpack("S1", substr($msg, 2, 2));
		$storage{'items_max'} = unpack("S1", substr($msg, 4, 2));

		$ai_v{temp}{storage_opened} = 1;
		if (!$storage{opened}) {
			$storage{opened} = 1;
			message "Storage opened.\n", "storage";
			Plugins::callHook('packet_storage_open');
		}

	} elsif ($switch eq "00F6") {
		my $index = unpack("S1", substr($msg, 2, 2));
		my $amount = unpack("L1", substr($msg, 4, 4));
		$storage{$index}{amount} -= $amount;
		message "Storage Item Removed: $storage{$index}{name} ($storage{$index}{binID}) x $amount\n", "storage";
		if ($storage{$index}{amount} <= 0) {
			delete $storage{$index};
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

		if ($chars[$config{'char'}]{'party'}{'users'}{$accountID}{'admin'} && $chars[$config{'char'}]{'party'}{'share'}) {
			sendPartyShareEXP(\$remote_socket, 0) if ($config{'partyAutoShare'} && %{$chars[$config{'char'}]{'party'}});
			sendPartyShareEXP(\$remote_socket, 1) if ($config{'partyAutoShare'} && %{$chars[$config{'char'}]{'party'}});
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

	} elsif ($switch eq "0108") {
		my $type =  unpack("S1",substr($msg, 2, 2));
		my $index = unpack("S1",substr($msg, 4, 2));
		my $enchant = unpack("S1",substr($msg, 6, 2));
		my $invIndex = findIndex(\@{$chars[$config{'char'}]{'inventory'}}, "index", $index);
		$chars[$config{'char'}]{'inventory'}[$invIndex]{'enchant'} = $enchant;

	} elsif ($switch eq "0109") {
		decrypt(\$newmsg, substr($msg, 8, length($msg)-8));
		my $ID = substr($msg, 4, 4);
		my $chat = substr($msg, 8, $msg_size - 8);
		$chat =~ s/\000//g;
		my ($chatMsgUser, $chatMsg) = $chat =~ /([\s\S]*?) : ([\s\S]*)/;
		$chatMsgUser =~ s/ $//;

		my %item;
		$item{type} = "p";
		$item{ID} = $ID;
		$item{user} = $chatMsgUser;
		$item{msg} = $chatMsg;
		$item{time} = time;
		binAdd(\@ai_cmdQue, \%item);
		$ai_cmdQue++;

		message "%$chat\n", "partychat";
		chatLog("p", $chat."\n") if ($config{'logPartyChat'});

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
		$ID = unpack("S1",substr($msg, 2, 2));
		$lv = unpack("S1",substr($msg, 4, 2));
		$chars[$config{'char'}]{'skills'}{$skills_rlut{lc($skillsID_lut{$ID})}}{'lv'} = $lv;
		debug "Skill $skillsID_lut{$ID}: $lv\n", "parseMsg";

	} elsif ($switch eq "010F") {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		decrypt(\$newmsg, substr($msg, 4, length($msg)-4));
		$msg = substr($msg, 0, 4).$newmsg;
		undef @skillsID;
		for ($i = 4;$i < $msg_size;$i+=37) {
			my $skillID = unpack("S1", substr($msg, $i, 2));
			my $level = unpack("S1", substr($msg, $i + 6, 2));
			($skillName) = substr($msg, $i + 12, 24) =~ /([\s\S]*?)\000/;
			if (!$skillName) {
				$skillName = $skills_rlut{lc($skillsID_lut{$skillID})};
			}
			$chars[$config{'char'}]{'skills'}{$skillName}{'ID'} = $skillID;
			if (!$chars[$config{'char'}]{'skills'}{$skillName}{'lv'}) {
				$chars[$config{'char'}]{'skills'}{$skillName}{'lv'} = $level;
			}
			$skillsID_lut{$skillID} = $skills_lut{$skillName};
			binAdd(\@skillsID, $skillName);
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
		message "Skill $skillsID_lut{$skillID} failed ($failtype{$type})\n", "skill";

	} elsif ($switch eq "01B9") {
		# cast is cancelled
		my $skillID = unpack("S1", substr($msg, 2, 2));

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
		updateDamageTables($sourceID, $targetID, $damage) if $damage != -30000;
		setSkillUseTimer($skillID) if $sourceID eq $accountID;
		countCastOn($sourceID, $targetID);

		# Resolve source and target names
		my ($source, $uses, $target) = getActorNames($sourceID, $targetID, 'use', 'uses');
		$damage ||= "Miss!";
		my $disp = "$source $uses ".skillName($skillID);
		$disp .= " (lvl $level)" unless $level == 65535;
		$disp .= " on $target";
		$disp .= " - Dmg: $damage" unless $damage == -30000;
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

		# Print skill use message
		message "$source $uses ".skillName($skillID)." (level $lv) on location ($x, $y)\n", "skill";

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
			my $verbosity = ($actorType ne 'self') ? 1 : 2;
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
		# Skill used on target
		my $skillID = unpack("S1", substr($msg, 2, 2));
		my $targetID = substr($msg, 6, 4);
		my $sourceID = substr($msg, 10, 4);
		my $amount = unpack("S1", substr($msg, 4, 2));
		if (my $spell = $spells{$sourceID}) {
			# Resolve source of area attack skill
			$sourceID = $spell->{sourceID};
		}

		# Perform trigger actions
		$conState = 5 if $conState != 4 && $config{XKore};
		setSkillUseTimer($skillID, $targetID) if $sourceID eq $accountID;
		countCastOn($sourceID, $targetID);
		if ($config{'autoResponseOnHeal'}) {
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
		my $type = unpack("S1",substr($msg, 2, 2));

		my ($memo1) = substr($msg, 4, 16) =~ /([\s\S]*?)\000/;
		my ($memo2) = substr($msg, 20, 16) =~ /([\s\S]*?)\000/;
		my ($memo3) = substr($msg, 36, 16) =~ /([\s\S]*?)\000/;
		my ($memo4) = substr($msg, 52, 16) =~ /([\s\S]*?)\000/;

		($memo1) = $memo1 =~ /([\s\S]*)\.gat/;
		($memo2) = $memo2 =~ /([\s\S]*)\.gat/;
		($memo3) = $memo3 =~ /([\s\S]*)\.gat/;
		($memo4) = $memo4 =~ /([\s\S]*)\.gat/;

		$chars[$config{'char'}]{'warp'}{'type'} = $type;
		undef @{$chars[$config{'char'}]{'warp'}{'memo'}};
		push @{$chars[$config{'char'}]{'warp'}{'memo'}}, $memo1 if $memo1 ne "";
		push @{$chars[$config{'char'}]{'warp'}{'memo'}}, $memo2 if $memo2 ne "";
		push @{$chars[$config{'char'}]{'warp'}{'memo'}}, $memo3 if $memo3 ne "";
		push @{$chars[$config{'char'}]{'warp'}{'memo'}}, $memo4 if $memo4 ne "";

		message("----------------- Warp Portal --------------------\n", "list");
		message("#  Place                           Map\n", "list");
		for (my $i = 0; $i < @{$chars[$config{'char'}]{'warp'}{'memo'}}; $i++) {
			message(swrite(
				"@< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<<<<",
				[$i, $maps_lut{$chars[$config{'char'}]{'warp'}{'memo'}[$i].'.rsw'},
				$chars[$config{'char'}]{'warp'}{'memo'}[$i]]),
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
		my $SourceID = substr($msg, 6, 4);
		my $x = unpack("S1", substr($msg, 10, 2));
		my $y = unpack("S1", substr($msg, 12, 2));
		my $type = unpack("C1", substr($msg, 14, 1));
		my $fail = unpack("C1", substr($msg, 15, 1));

		$spells{$ID}{'sourceID'} = $SourceID;
		$spells{$ID}{'pos'}{'x'} = $x;
		$spells{$ID}{'pos'}{'y'} = $y;
		$binID = binAdd(\@spellsID, $ID);
		$spells{$ID}{'binID'} = $binID;
		if ($type == 0x81) {
			message getActorName($sourceID)." opened Warp Portal on ($x, $y)\n", "skill";
		}

	} elsif ($switch eq "0120") {
		# The area effect spell with ID dissappears
		my $ID = substr($msg, 2, 4);
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
		%{$monsters{$ID}{'pos_attack_info'}} = %coords1 if ($monsters{$ID} && %{$monsters{$ID}});
		%{$chars[$config{'char'}]{'pos'}} = %coords2;
		%{$chars[$config{'char'}]{'pos_to'}} = %coords2;
		debug "Received attack location - monster: $coords1{'x'},$coords1{'y'} - " .
			"you: $coords2{'x'},$coords2{'y'}\n", "parseMsg_move", 2;

	} elsif ($switch eq "013A") {
		$type = unpack("S1",substr($msg, 2, 2));

	# Hambo Arrow Equip
	} elsif ($switch eq "013B") {
		$type = unpack("S1",substr($msg, 2, 2)); 
		if ($type == 0) { 
			undef $chars[$config{'char'}]{'arrow'};
			if ($config{'dcOnEmptyArrow'}) {
				$interface->errorDialog("Please equip arrow first.");
				quit();
			} else {
				error "Please equip arrow first.\n";
			}

		} elsif ($type == 3) {
			message "Arrow equipped\n" if ($config{'debug'}); 
		} 

	} elsif ($switch eq "013C") {
		$index = unpack("S1", substr($msg, 2, 2)); 
		$invIndex = findIndex(\@{$chars[$config{'char'}]{'inventory'}}, "index", $index); 
		if ($invIndex ne "") { 
			$chars[$config{'char'}]{'arrow'}=1 if (!defined($chars[$config{'char'}]{'arrow'}));
			$chars[$config{'char'}]{'inventory'}[$invIndex]{'equipped'} = 32768; 
			message "Arrow equipped: $chars[$config{'char'}]{'inventory'}[$invIndex]{'name'} ($invIndex)\n";
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
		$sourceID = substr($msg, 2, 4);
		$targetID = substr($msg, 6, 4);
		$x = unpack("S1",substr($msg, 10, 2));
		$y = unpack("S1",substr($msg, 12, 2));
		$skillID = unpack("S1",substr($msg, 14, 2));

		# Resolve source and target names
		my ($source, $verb, $target) = getActorNames($sourceID, $targetID, 'are casting', 'is casting');
		if ($x != 0 || $y != 0) {
			$target = "location ($x, $y)";
		}

		# Perform trigger actions
		if ($sourceID eq $accountID) {
			$chars[$config{'char'}]{'time_cast'} = time;
		}
		if (%{$monsters{$targetID}}) {
			if ($sourceID eq $accountID) {
				$monsters{$targetID}{'castOnByYou'}++;
			} elsif (%{$players{$sourceID}}) {
				$monsters{$targetID}{'castOnByPlayer'}{$sourceID}++;
			} elsif (%{$monsters{$sourceID}}) {
				$monsters{$targetID}{'castOnByMonster'}{$sourceID}++;
			}
		}

		message "$source $verb ".skillName($skillID)." on $target\n", "skill", 1;

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
		decrypt(\$newmsg, substr($msg, 4, length($msg) - 4));
		my $msg = substr($msg, 0, 4) . $newmsg;
		my $c = 0;
		for (my $i = 4; $i < $msg_size; $i+=104){
			$guild{'member'}[$c]{'ID'}    = substr($msg, $i, 4);
			$guild{'member'}[$c]{'jobID'} = unpack("S1", substr($msg, $i + 14, 2));
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
		my ($name) = substr($msg, 4, 24) =~ /([\s\S]*?)\000/;
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
		undef $nameRequest;
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
		my ($name) = substr($msg, 6, 24) =~ /[\s\S]*?\000/;
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
		message "Received Possible Identify List - type 'identify'\n", 'info';

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
		$chat =~ s/\000$//;
		my ($chatMsgUser, $chatMsg) = $chat =~ /([\s\S]*?) : ([\s\S]*)\000/;
		$chatMsgUser =~ s/ $//;

		my %item;
		$item{type} = "g";
		$item{ID} = $ID;
		$item{user} = $chatMsgUser;
		$item{msg} = $chatMsg;
		$item{time} = time;
		binAdd(\@ai_cmdQue, \%item);
		$ai_cmdQue++;

		chatLog("g", $chat."\n") if ($config{'logGuildChat'});
		message "[Guild] $chat\n", "guildchat";

	} elsif ($switch eq "0188") {
		$type =  unpack("S1",substr($msg, 2, 2));
		$index = unpack("S1",substr($msg, 4, 2));
		$enchant = unpack("S1",substr($msg, 6, 2));
		$invIndex = findIndex(\@{$chars[$config{'char'}]{'inventory'}}, "index", $index);
		$chars[$config{'char'}]{'inventory'}[$invIndex]{'enchant'} = $enchant;

	} elsif ($switch eq "0194") {
		my $ID = substr($msg, 2, 4);
		my ($name) = substr($msg, 6, 24) =~ /([\s\S]*?)\000/;
		
		if ($nameRequest{type} eq "g") {
			message "Guild Member $name Log ".($nameRequest{online}?"In":"Out")."\n", 'guildchat';
		}

	} elsif ($switch eq "0195") {
		my $ID = substr($msg, 2, 4);
		if (%{$players{$ID}}) {
			($players{$ID}{'name'}) = substr($msg, 6, 24) =~ /([\s\S]*?)\000/;
			($players{$ID}{'party'}{'name'}) = substr($msg, 30, 24) =~ /([\s\S]*?)\000/;
			($players{$ID}{'guild'}{'name'}) = substr($msg, 54, 24) =~ /([\s\S]*?)\000/;
			($players{$ID}{'guild'}{'men'}{$players{$ID}{'name'}}{'title'}) = substr($msg, 78, 24) =~ /([\s\S]*?)\000/;
			debug "Player Info: $players{$ID}{'name'} ($players{$ID}{'binID'})\n", "parseMsg", 2;
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

		if (defined $actor) {
			my $name = getActorName($ID);
			if ($flag) {
				# Skill activated
				$actor->{statuses}{$skillName} = 1;
				message "$name are now: $skillName\n", "parseMsg_statuslook",2;

			} else {
				# Skill de-activate (expired)
				delete $actor->{statuses}{$skillName};
				message "$name are no longer: $skillName\n", "parseMsg_statuslook",2;
			}
		} else {
			if ($flag) {
				message "Unknown ".getHex($ID)." got status $skillName\n", "parseMsg_statuslook", 2;
			} else {
				message "Unknown ".getHex($ID)." lost status status $skillName\n", "parseMsg_statuslook", 2;
			}
		}

	} elsif ($switch eq "019B") {
		$ID = substr($msg, 2, 4);
		$type = unpack("L1",substr($msg, 6, 4));
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
			print "$name refined weapon Fail!\n";
		} elsif ($type == 3) {
			print "$name refined weapon Success!\n";
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
		}
		debug "Pet Spawned: $pets{$ID}{'name'} ($pets{$ID}{'binID'})\n", "parseMsg";
		#end of pet spawn code

	} elsif ($switch eq "01AA") {
		# pet

	} elsif ($switch eq "01B0") {
		# Class change
		# 01B0 : long ID, byte WhateverThisIs, long class
		my $ID = unpack("L", substr($msg, 2, 4));
		my $class = unpack("L", substr($msg, 7, 4));

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
			my $invIndex = findIndex(\@{$chars[$config{'char'}]{'inventory'}}, "index", $index);
			my $amount = $chars[$config{'char'}]{'inventory'}[$invIndex]{'amount'} - $amountleft;
			$chars[$config{'char'}]{'inventory'}[$invIndex]{'amount'} -= $amount;

			message("You used Item: $chars[$config{'char'}]{'inventory'}[$invIndex]{'name'} ($invIndex) x $amount\n", "useItem", 1);
			if ($chars[$config{'char'}]{'inventory'}[$invIndex]{'amount'} <= 0) {
				delete $chars[$config{'char'}]{'inventory'}[$invIndex];
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
		if ($sourceID eq $accountID) {
			$chars[$config{char}]{spirits} = unpack("S1",substr($msg, 6, 2));
			message "You have $chars[$config{char}]{spirits} spirit(s) now\n", "parseMsg_statuslook", 1;
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

	} elsif ($switch eq "01D8") {
		$ID = substr($msg, 2, 4);
		makeCoords(\%coords, substr($msg, 46, 3));
		$type = unpack("S*",substr($msg, 14,  2));
		$pet = unpack("C*",substr($msg, 16,  1));
		$sex = unpack("C*",substr($msg, 45,  1));
		$sitting = unpack("C*",substr($msg, 51,  1));

		if ($jobs_lut{$type}) {
			if (!defined($players{$ID}{binID})) {
				$players{$ID}{'appear_time'} = time;
				binAdd(\@playersID, $ID);
				$players{$ID}{'jobID'} = $type;
				$players{$ID}{'sex'} = $sex;
				$players{$ID}{'name'} = "Unknown";
				$players{$ID}{'nameID'} = unpack("L1", $ID);
				$players{$ID}{'binID'} = binFind(\@playersID, $ID);
			}
			$players{$ID}{'sitting'} = $sitting > 0;
			%{$players{$ID}{'pos'}} = %coords;
			%{$players{$ID}{'pos_to'}} = %coords;
			debug "Player Exists: $players{$ID}{'name'} ($players{$ID}{'binID'}) $sex_lut{$players{$ID}{'sex'}} $jobs_lut{$players{$ID}{'jobID'}}\n", "parseMsg_presence", 1;

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
				%{$pets{$ID}{'pos'}} = %coords;
				%{$pets{$ID}{'pos_to'}} = %coords;
				debug "Pet Exists: $pets{$ID}{'name'} ($pets{$ID}{'binID'})\n", "parseMsg";
			} else {
				if (!%{$monsters{$ID}}) {
					$monsters{$ID}{'appear_time'} = time;
					$display = ($monsters_lut{$type} ne "") 
							? $monsters_lut{$type}
							: "Unknown ".$type;
					binAdd(\@monstersID, $ID);
					$monsters{$ID}{'nameID'} = $type;
					$monsters{$ID}{'name'} = $display;
					$monsters{$ID}{'binID'} = binFind(\@monstersID, $ID);
				}
				%{$monsters{$ID}{'pos'}} = %coords;
				%{$monsters{$ID}{'pos_to'}} = %coords;
				debug "Monster Exists: $monsters{$ID}{'name'} ($monsters{$ID}{'binID'})\n", "parseMsg_presence", 1;
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
			}
			%{$npcs{$ID}{'pos'}} = %coords;
			message "NPC Exists: $npcs{$ID}{'name'} ($npcs{$ID}{pos}->{x}, $npcs{$ID}{pos}->{y}) (ID $npcs{$ID}{'nameID'}) - ($npcs{$ID}{'binID'})\n", undef, 1;

		} else {
			debug "Unknown Exists: $type - ".unpack("L*",$ID)."\n", "parseMsg";
		}
      		
	} elsif ($switch eq "01D9") {
		$ID = substr($msg, 2, 4);
		makeCoords(\%coords, substr($msg, 46, 3));
		$type = unpack("S*",substr($msg, 14,  2));
		$sex = unpack("C*",substr($msg, 45,  1));
		if ($jobs_lut{$type}) {
			if (!defined($players{$ID}{binID})) {
				$players{$ID}{'appear_time'} = time;
				binAdd(\@playersID, $ID);
				$players{$ID}{'jobID'} = $type;
				$players{$ID}{'sex'} = $sex;
				$players{$ID}{'name'} = "Unknown";
				$players{$ID}{'nameID'} = unpack("L1", $ID);
				$players{$ID}{'binID'} = binFind(\@playersID, $ID);
			}
			%{$players{$ID}{'pos'}} = %coords;
			%{$players{$ID}{'pos_to'}} = %coords;
			debug "Player Connected: $players{$ID}{'name'} ($players{$ID}{'binID'}) $sex_lut{$players{$ID}{'sex'}} $jobs_lut{$players{$ID}{'jobID'}}\n", "parseMsg";

		} else {
			debug "Unknown Connected: $type - ".getHex($ID)."\n", "parseMsg";
		}

	} elsif ($switch eq "01DA") {
		$ID = substr($msg, 2, 4);
		makeCoords(\%coordsFrom, substr($msg, 50, 3));
		makeCoords2(\%coordsTo, substr($msg, 52, 3));
		$type = unpack("S*",substr($msg, 14,  2));
		$pet = unpack("C*",substr($msg, 16,  1));
		$sex = unpack("C*",substr($msg, 49,  1));

		if ($jobs_lut{$type}) {
			if (!defined($players{$ID}{binID})) {
				binAdd(\@playersID, $ID);
				$players{$ID}{'appear_time'} = time;
				$players{$ID}{'sex'} = $sex;
				$players{$ID}{'jobID'} = $type;
				$players{$ID}{'name'} = "Unknown";
				$players{$ID}{'nameID'} = unpack("L1", $ID);
				$players{$ID}{'binID'} = binFind(\@playersID, $ID);

				debug "Player Appeared: $players{$ID}{'name'} ($players{$ID}{'binID'}) $sex_lut{$sex} $jobs_lut{$type}\n", "parseMsg_presence";
			}
			%{$players{$ID}{'pos'}} = %coordsFrom;
			%{$players{$ID}{'pos_to'}} = %coordsTo;
			debug "Player Moved: $players{$ID}{'name'} ($players{$ID}{'binID'}) $sex_lut{$players{$ID}{'sex'}} $jobs_lut{$players{$ID}{'jobID'}}\n", "parseMsg", 2;

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
				%{$pets{$ID}{'pos'}} = %coords;
				%{$pets{$ID}{'pos_to'}} = %coords;
				if (%{$monsters{$ID}}) {
					binRemove(\@monstersID, $ID);
					delete $monsters{$ID};
				}
				debug "Pet Moved: $pets{$ID}{'name'} ($pets{$ID}{'binID'})\n", "parseMsg";
			} else {
				if (!%{$monsters{$ID}}) {
					binAdd(\@monstersID, $ID);
					$monsters{$ID}{'appear_time'} = time;
					$monsters{$ID}{'nameID'} = $type;
					$display = ($monsters_lut{$type} ne "") 
						? $monsters_lut{$type}
						: "Unknown ".$type;
					$monsters{$ID}{'nameID'} = $type;
					$monsters{$ID}{'name'} = $display;
					$monsters{$ID}{'binID'} = binFind(\@monstersID, $ID);
					debug "Monster Appeared: $monsters{$ID}{'name'} ($monsters{$ID}{'binID'})\n", "parseMsg_presence";
				}
				%{$monsters{$ID}{'pos'}} = %coordsFrom;
				%{$monsters{$ID}{'pos_to'}} = %coordsTo;
				debug "Monster Moved: $monsters{$ID}{'name'} ($monsters{$ID}{'binID'})\n", "parseMsg";
			}

		} else {
			debug "Unknown Moved: $type - ".getHex($ID)."\n", "parseMsg";
		}

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
			my $index = findIndex(\@{char->{inventory}}, "nameID", $ID);
			binAdd(\@arrowCraftID, $index);
		}
		message "Recieved Possible Arrow Craft List - type 'arrowcraft'\n";

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

	$seq{items} = \@{$r_items};
	$seq{max} = $max;
	$seq{timeout} = 1;
	AI::queue("drop", \%seq);
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
				message "Calculating route to find master: $maps_lut{$ai_v{master}{map}.'.rsw'}\n", "follow";
			} elsif (distance(\%master, $char->{pos_to}) > $config{followDistanceMax} ) {
				message "Calculating route to find master: $maps_lut{$ai_v{master}{map}.'.rsw'} ($ai_v{master}{x},$ai_v{master}{y})\n", "follow";
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

sub ai_getAggressives {
	my @agMonsters;
	foreach (@monstersID) {
		next if ($_ eq "");
		if (($monsters{$_}{'dmgToYou'} > 0 || $monsters{$_}{'missedYou'} > 0) && $monsters{$_}{'attack_failed'} <= 1) {
			push @agMonsters, $_;
		}
	}
	return @agMonsters;
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

sub ai_getIDFromChat {
	my $r_hash = shift;
	my $msg_user = shift;
	my $match_text = shift;
	my $qm;
	if ($match_text !~ /\w+/ || $match_text eq "me") {
		foreach (keys %{$r_hash}) {
			next if ($_ eq "");
			if ($msg_user eq $$r_hash{$_}{'name'}) {
				return $_;
			}
		}
	} else {
		foreach (keys %{$r_hash}) {
			next if ($_ eq "");
			$qm = quotemeta $match_text;
			if ($$r_hash{$_}{'name'} =~ /$qm/i) {
				return $_;
			}
		}
	}
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
	return 1 if $skillsArea{$skill};
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
	$args{'params'} = $param{params} if exists $param{params};
	$args{'time_start'} = time;

	if (!$param{'_internal'}) {
		undef @{$args{'solution'}};
		undef @{$args{'mapSolution'}};
	} elsif (exists $param{'_solution'}) {
		$args{'solution'} = $param{'_solution'};
	}

	# Destination is same map and isn't blocked by walls/water/whatever
	if ($param{'_internal'} || ($field{'name'} eq $args{'dest'}{'map'} && ai_route_getRoute(\@{$args{'solution'}}, \%field, $chars[$config{'char'}]{'pos_to'}, $args{'dest'}{'pos'}))) {
		# Since the solution array is here, we can start in "Route Solution Ready"
		$args{'stage'} = 'Route Solution Ready';
		debug "Route Solution Ready\n", "route";
		unshift @ai_seq, "route";
		unshift @ai_seq_args, \%args;
	} else {
		# Nothing is initialized so we start scratch
		unshift @ai_seq, "mapRoute";
		unshift @ai_seq_args, \%args;
	}
}

sub ai_route_getRoute {
	my ($returnArray, $r_field, $r_start, $r_dest) = @_;
	undef @{$returnArray};
	return 1 if (!defined $r_dest->{x} || !defined $r_dest->{'y'});

	# The exact destination may not be a spot that we can walk on.
	# So we find a nearby spot that is walkable.
	my %start = %{$r_start};
	my %dest = %{$r_dest};
	closestWalkableSpot($r_field, \%start);
	closestWalkableSpot($r_field, \%dest);

	# Generate map weights (for wall avoidance)
	my $weights = join '', map chr $_, (255, 8, 7, 6, 5, 4, 3, 2, 1);
	$weights .= chr(1) x (256 - length($weights));

	# Calculate path
	my $pathfinding = new PathFinding(
		start => \%start,
		dest => \%dest,
		field => $r_field,
		weights => $weights
	);
	return undef if !$pathfinding;

	my $ret = $pathfinding->runref();
	return undef if !$ret; # Failure
	@{$returnArray} = @{$ret};
	return scalar @{$ret}; # Success
}

#sellAuto for items_control - chobit andy 20030210
sub ai_sellAutoCheck {
	for ($i = 0; $i < @{$chars[$config{'char'}]{'inventory'}};$i++) {
		next if (!%{$chars[$config{'char'}]{'inventory'}[$i]} || $chars[$config{'char'}]{'inventory'}[$i]{'equipped'});
		if ($items_control{lc($chars[$config{'char'}]{'inventory'}[$i]{'name'})}{'sell'}
			&& $chars[$config{'char'}]{'inventory'}[$i]{'amount'} > $items_control{lc($chars[$config{'char'}]{'inventory'}[$i]{'name'})}{'keep'}) {
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
	my $ID = shift;
	my $lv = shift;
	my $maxCastTime = shift;
	my $minCastTime = shift;
	my $target = shift;
	my $y = shift;
	my %args;
	$args{ai_skill_use_giveup}{time} = time;
	$args{ai_skill_use_giveup}{timeout} = $timeout{ai_skill_use_giveup}{timeout};
	$args{skill_use_id} = $ID;
	$args{skill_use_lv} = $lv;
	$args{skill_use_maxCastTime}{time} = time;
	$args{skill_use_maxCastTime}{timeout} = $maxCastTime;
	$args{skill_use_minCastTime}{time} = time;
	$args{skill_use_minCastTime}{timeout} = $minCastTime;
	if ($y eq "") {
		$args{skill_use_target} = $target;
	} else {
		$args{skill_use_target_x} = $target;
		$args{skill_use_target_y} = $y;
	}
	AI::queue("skill_use",\%args);
}

#storageAuto for items_control - chobit andy 20030210
sub ai_storageAutoCheck {
	for (my $i = 0; $i < @{$chars[$config{'char'}]{'inventory'}};$i++) {
		next if (!%{$chars[$config{'char'}]{'inventory'}[$i]} || $chars[$config{'char'}]{'inventory'}[$i]{'equipped'});
		if ($items_control{lc($chars[$config{'char'}]{'inventory'}[$i]{'name'})}{'storage'}
			&& $chars[$config{'char'}]{'inventory'}[$i]{'amount'} > $items_control{lc($chars[$config{'char'}]{'inventory'}[$i]{'name'})}{'keep'}) {
			return 1;
		}
	}
}

##
# ai_storageGet(items, max)
# items: reference to an array of storage item numbers.
# max: the maximum amount to get, for each item, or 0 for unlimited.
#
# Get one or more items from storage.
#
# Example:
# # Get items 2 and 5 from storage.
# ai_storageGet([2, 5]);
# # Get items 2 and 5 from storage, but at most 30 of each item.
# ai_storageGet([2, 5], 30);
sub ai_storageGet {
	my $r_items = shift;
	my $max = shift;
	my %seq = ();

	$seq{items} = \@{$r_items};
	$seq{max} = $max;
	$seq{timeout} = 0.15;
	AI::queue("storageGet", \%seq);
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
	unshift @ai_seq, "attack";
	unshift @ai_seq_args, \%args;

	if ($priorityAttack) {
		message "Priority Attacking: $monsters{$ID}{'name'} ($monsters{$ID}{'binID'}) [$monsters{$ID}{'nameID'}]\n";
	} else {
		message "Attacking: $monsters{$ID}{'name'} ($monsters{$ID}{'binID'}) [$monsters{$ID}{'nameID'}]\n";
	}


	$startedattack = 1;
	if ($config{"monsterCount"}) {	
		my $i = 0;
		while ($config{"monsterCount_mon_$i"} ne "") {
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
		while ($config{"autoSwitch_$i"} ne "") { 
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
	%{$args{pos}} = %{$items{$ID}{pos}};
	AI::queue("items_gather", \%args);
	debug "Targeting for Gather: $items{$ID}{name} ($items{$ID}{binID})\n";
}


sub look {
	my $body = shift;
	my $head = shift;
	my %args;
	unshift @ai_seq, "look";
	$args{'look_body'} = $body;
	$args{'look_head'} = $head;
	unshift @ai_seq_args, \%args;
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
	#$args{ai_move_giveup}{timeout} = 4 * ($char->{walk_speed} || 0.12) * (1 + $dist);
	$args{ai_move_giveup}{timeout} = $timeout{ai_move_giveup}{timeout};
	debug sprintf("Sending move from (%d,%d) to (%d,%d) - distance %.2f\n",
		$char->{pos}{x}, $char->{pos}{y}, $x, $y, $dist), "ai_move";
	AI::queue("move", \%args);
}

sub quit {
	$quit = 1;
	message "Exiting...\n", "system";
}

sub relog {
	$conState = 1;
	undef $conState_tries;
	$timeout_ex{'master'}{'time'} = time;
	$timeout_ex{'master'}{'timeout'} = 5;
	Network::disconnect(\$remote_socket);
	message "Relogging in 5 seconds...\n", "connection";
}

sub sendMessage {
	my $r_socket = shift;
	my $type = shift;
	my $msg = shift;
	my $user = shift;
	my $i, $j;
	my @msg;
	my @msgs;
	my $oldmsg;
	my $amount;
	my $space;
	@msgs = split /\\n/,$msg;
	for ($j = 0; $j < @msgs; $j++) {
	@msg = split / /, $msgs[$j];
	undef $msg;
	for ($i = 0; $i < @msg; $i++) {
		if (!length($msg[$i])) {
			$msg[$i] = " ";
			$space = 1;
		}
		if (length($msg[$i]) > $config{'message_length_max'}) {
			while (length($msg[$i]) >= $config{'message_length_max'}) {
				$oldmsg = $msg;
				if (length($msg)) {
					$amount = $config{'message_length_max'};
					if ($amount - length($msg) > 0) {
						$amount = $config{'message_length_max'} - 1;
						$msg .= " " . substr($msg[$i], 0, $amount - length($msg));
					}
				} else {
					$amount = $config{'message_length_max'};
					$msg .= substr($msg[$i], 0, $amount);
				}
				if ($type eq "c") {
					sendChat($r_socket, $msg);
				} elsif ($type eq "g") { 
					sendGuildChat($r_socket, $msg); 
				} elsif ($type eq "p") {
					sendPartyChat($r_socket, $msg);
				} elsif ($type eq "pm") {
					sendPrivateMsg($r_socket, $user, $msg);
					undef %lastpm;
					$lastpm{'msg'} = $msg;
					$lastpm{'user'} = $user;
					push @lastpm, {%lastpm};
				} elsif ($type eq "k" && $config{'XKore'}) {
					injectMessage($msg);
 				}
				$msg[$i] = substr($msg[$i], $amount - length($oldmsg), length($msg[$i]) - $amount - length($oldmsg));
				undef $msg;
			}
		}
		if (length($msg[$i]) && length($msg) + length($msg[$i]) <= $config{'message_length_max'}) {
			if (length($msg)) {
				if (!$space) {
					$msg .= " " . $msg[$i];
				} else {
					$space = 0;
					$msg .= $msg[$i];
				}
			} else {
				$msg .= $msg[$i];
			}
		} else {
			if ($type eq "c") {
				sendChat($r_socket, $msg);
			} elsif ($type eq "g") { 
				sendGuildChat($r_socket, $msg); 
			} elsif ($type eq "p") {
				sendPartyChat($r_socket, $msg);
			} elsif ($type eq "pm") {
				sendPrivateMsg($r_socket, $user, $msg);
				undef %lastpm;
				$lastpm{'msg'} = $msg;
				$lastpm{'user'} = $user;
				push @lastpm, {%lastpm};
			} elsif ($type eq "k" && $config{'XKore'}) {
				injectMessage($msg);
			}
			$msg = $msg[$i];
		}
		if (length($msg) && $i == @msg - 1) {
			if ($type eq "c") {
				sendChat($r_socket, $msg);
			} elsif ($type eq "g") { 
				sendGuildChat($r_socket, $msg); 
			} elsif ($type eq "p") {
				sendPartyChat($r_socket, $msg);
			} elsif ($type eq "pm") {
				sendPrivateMsg($r_socket, $user, $msg);
				undef %lastpm;
				$lastpm{'msg'} = $msg;
				$lastpm{'user'} = $user;
				push @lastpm, {%lastpm};
			} elsif ($type eq "k" && $config{'XKore'}) {
				injectMessage($msg);
			}
		}
	}
	}
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


sub getVector {
	my $r_store = shift;
	my $r_head = shift;
	my $r_tail = shift;
	$$r_store{'x'} = $$r_head{'x'} - $$r_tail{'x'};
	$$r_store{'y'} = $$r_head{'y'} - $$r_tail{'y'};
}

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


sub moveAlongVector {
	my $r_store = shift;
	my $r_pos = shift;
	my $r_vec = shift;
	my $amount = shift;
	my %norm;
	if ($amount) {
		normalize(\%norm, $r_vec);
		$$r_store{'x'} = $$r_pos{'x'} + $norm{'x'} * $amount;
		$$r_store{'y'} = $$r_pos{'y'} + $norm{'y'} * $amount;
	} else {
		$$r_store{'x'} = $$r_pos{'x'} + $$r_vec{'x'};
		$$r_store{'y'} = $$r_pos{'y'} + $$r_vec{'y'};
	}
}

sub normalize {
	my $r_store = shift;
	my $r_vec = shift;
	my $dist;
	$dist = distance($r_vec);
	if ($dist > 0) {
		$$r_store{'x'} = $$r_vec{'x'} / $dist;
		$$r_store{'y'} = $$r_vec{'y'} / $dist;
	} else {
		$$r_store{'x'} = 0;
		$$r_store{'y'} = 0;
	}
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

sub positionNearPlayer {
	my $r_hash = shift;
	my $dist = shift;

	for (my $i = 0; $i < @playersID; $i++) {
		next if ($playersID[$i] eq "");
		return 1 if (distance($r_hash, \%{$players{$playersID[$i]}{'pos_to'}}) <= $dist);
	}
	return 0;
}

sub positionNearPortal {
	my $r_hash = shift;
	my $dist = shift;

	for (my $i = 0; $i < @portalsID; $i++) {
		next if ($portalsID[$i] eq "");
		return 1 if (distance($r_hash, \%{$portals{$portalsID[$i]}{'pos'}}) <= $dist);
	}
	return 0;
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
		warning "Could not load field $file - you must install the kore-field pack!\n";
		return 0;
	}

	$dist_file =~ s/\.fld$/.dist/i;

	# Load the .fld file
	($$r_hash{'name'}) = $file =~ m{/?([^/.]*)\.};
	open FILE, "<", $file;
	binmode(FILE);
	my $data;
	{
		local($/);
		$data = <FILE>;
		close FILE;
		@$r_hash{'width', 'height'} = unpack("S1 S1", substr($data, 0, 4, ''));
		$$r_hash{'rawMap'} = $data;
		#$$r_hash{'field'} = [unpack("C*", $data)];
	}

	# Load the associated .dist file (distance map)
	if (-e $dist_file) {
		open FILE, "<", $dist_file;
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
		open FILE, ">", $dist_file or die "Could not write dist cache file: $!\n";
		binmode(FILE);
		print FILE pack("a2 S1", 'V#', 2);
		print FILE pack("S1 S1", @$r_hash{'width', 'height'});
		print FILE $$r_hash{'dstMap'};
		close FILE;
	}

	return 1;
}

##
# makeDistMap(data, width, height)
# data: the raw field data.
# width: the field's width.
# height: the field's height.
# Returns: the raw data of the distance map.
#
# Create a distance map from raw field data. This distance map data is used by pathfinding
# for wall avoidance support.
#
# This function is used internally by getField(). You shouldn't have to use this directly.
sub makeDistMap {
	my $data = shift;
	my $width = shift;
	my $height = shift;

	# Simplify the raw map data. Each byte in the raw map data
	# represents a block on the field, but only some bytes are
	# interesting to pathfinding.
	for (my $i = 0; $i < length($data); $i++) {
		my $v = ord(substr($data, $i, 1));
		# 0 is open, 3 is walkable water
		if ($v == 0 || $v == 3) {
			$v = 255;
		} else {
			$v = 0;
		}
		substr($data, $i, 1, chr($v));
	}

	my $done = 0;
	until ($done) {
		$done = 1;
		#'push' wall distance right and up
		for (my $y = 0; $y < $height; $y++) {
			for (my $x = 0; $x < $width; $x++) {
				my $i = $y * $width + $x;
				my $dist = ord(substr($data, $i, 1));
				if ($x != $width - 1) {
					my $ir = $y * $width + $x + 1;
					my $distr = ord(substr($data, $ir, 1));
					my $comp = $dist - $distr;
					if ($comp > 1) {
						my $val = $distr + 1;
						$val = 255 if $val > 255;
						substr($data, $i, 1, chr($val));
						$done = 0;
					} elsif ($comp < -1) {
						my $val = $dist + 1;
						$val = 255 if $val > 255;
						substr($data, $ir, 1, chr($val));
						$done = 0;
					}
				}
				if ($y != $height - 1) {
					my $iu = ($y + 1) * $width + $x;
					my $distu = ord(substr($data, $iu, 1));
					my $comp = $dist - $distu;
					if ($comp > 1) {
						my $val = $distu + 1;
						$val = 255 if $val > 255;
						substr($data, $i, 1, chr($val));
						$done = 0;
					} elsif ($comp < -1) {
						my $val = $dist + 1;
						$val = 255 if $val > 255;
						substr($data, $iu, 1, chr($val));
						$done = 0;
					}
				}
			}
		}
		#'push' wall distance left and down
		for (my $y = $height - 1; $y >= 0; $y--) {
			for (my $x = $width - 1; $x >= 0 ; $x--) {
				my $i = $y * $width + $x;
				my $dist = ord(substr($data, $i, 1));
				if ($x != 0) {
					my $il = $y * $width + $x - 1;
					my $distl = ord(substr($data, $il, 1));
					my $comp = $dist - $distl;
					if ($comp > 1) {
						my $val = $distl + 1;
						$val = 255 if $val > 255;
						substr($data, $i, 1, chr($val));
						$done = 0;
					} elsif ($comp < -1) {
						my $val = $dist + 1;
						$val = 255 if $val > 255;
						substr($data, $il, 1, chr($val));
						$done = 0;
					}
				}
				if ($y != 0) {
					my $id = ($y - 1) * $width + $x;
					my $distd = ord(substr($data, $id, 1));
					my $comp = $dist - $distd;
					if ($comp > 1) {
						my $val = $distd + 1;
						$val = 255 if $val > 255;
						substr($data, $i, 1, chr($val));
						$done = 0;
					} elsif ($comp < -1) {
						my $val = $dist + 1;
						$val = 255 if $val > 255;
						substr($data, $id, 1, chr($val));
						$done = 0;
					}
				}
			}
		}
	}
	return $data;
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

sub getResponse {
	my $type = shift;
	my $key;
	my @keys;
	my $msg;
	foreach $key (keys %responses) {
		if ($key =~ /^$type\_\d+$/) {
			push @keys, $key;
		} 
	}
	$msg = $responses{$keys[int(rand(@keys))]};
	$msg =~ s/\%\$(\w+)/$responseVars{$1}/eig;
	return $msg;
}

sub updateDamageTables {
	my ($ID1, $ID2, $damage) = @_;
	if ($ID1 eq $accountID) {
		if (%{$monsters{$ID2}}) {
			# You attack monster
			$monsters{$ID2}{'dmgTo'} += $damage;
			$monsters{$ID2}{'dmgFromYou'} += $damage;
			if ($damage == 0) {
				$monsters{$ID2}{'missedFromYou'}++;
			}
		}
	} elsif ($ID2 eq $accountID) {
		if (%{$monsters{$ID1}}) {
			# Monster attacks you
			$monsters{$ID1}{'dmgFrom'} += $damage;
			$monsters{$ID1}{'dmgToYou'} += $damage;
			if ($damage == 0) {
				$monsters{$ID1}{'missedYou'}++;
			}
			$monsters{$ID1}{'attackedByPlayer'} = 0;
			$monsters{$ID1}{'attackedYou'}++ unless (
					binSize([keys %{$monsters{$ID1}{'dmgFromPlayer'}}]) ||
					binSize([keys %{$monsters{$ID1}{'dmgToPlayer'}}]) ||
					$monsters{$ID1}{'missedFromPlayer'} ||
					$monsters{$ID1}{'missedToPlayer'}
				);

			my $teleport = 0;
			if ($mon_control{lc($monsters{$ID1}{'name'})}{'teleport_auto'}==2){
				message "Teleport due to $monsters{$ID1}{'name'} attack\n";
				$teleport = 1;
			} elsif ($config{'teleportAuto_deadly'} && $damage >= $chars[$config{'char'}]{'hp'} && !whenStatusActive("Hallucination")) {
				message "Next $damage dmg could kill you. Teleporting...\n";
				$teleport = 1;
			} elsif ($config{'teleportAuto_maxDmg'} && $damage >= $config{'teleportAuto_maxDmg'} && !whenStatusActive("Hallucination")) {
				message "$monsters{$ID1}{'name'} attack you more than $config{'teleportAuto_maxDmg'} dmg. Teleporting...\n";
				$teleport = 1;
			}
			useTeleport(1) if ($teleport && $AI);
		}
	} elsif (%{$monsters{$ID1}}) {
		if (%{$players{$ID2}}) {
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
				$monsters{$ID1}{'attackedByPlayer'} = 0 if ($config{'attackAuto_party'} || ( 
						$config{'attackAuto_followTarget'} &&
						$ai_v{'temp'}{'ai_follow_following'} &&
						$ID2 eq $ai_v{'temp'}{'ai_follow_ID'}
					)); 
			} else {
				$monsters{$ID1}{'attackedByPlayer'} = 1 unless (
					($config{'attackAuto_followTarget'} && $ai_v{'temp'}{'ai_follow_following'} && $ID2 eq $ai_v{'temp'}{'ai_follow_ID'})
					|| $monsters{$ID1}{'attackedYou'}
				);
			}
		}
		
	} elsif (%{$players{$ID1}}) {
		if (%{$monsters{$ID2}}) {
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
				$monsters{$ID2}{'attackedByPlayer'} = 0 if ($config{'attackAuto_party'} || ( 
				$config{'attackAuto_followTarget'} && 
				$config{'follow'} && $players{$ID1}{'name'} eq $config{'followTarget'})); 
			} else {
				$monsters{$ID2}{'attackedByPlayer'} = 1 unless (
							($config{'attackAuto_followTarget'} && $ai_v{'temp'}{'ai_follow_following'} && $ID1 eq $ai_v{'temp'}{'ai_follow_ID'})
							|| $monsters{$ID2}{'attackedYou'}
					);
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
		while ($config{"avoid_ignore_$j"} ne "") {
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

sub avoidGM_talk {
	return if (!$config{'avoidGM_talk'});
	my ($chatMsgUser, $chatMsg) = @_;

	# Check whether this "GM" is on the ignore list
	# in order to prevent false matches
	my $statusGM = 1;
	my $j = 0;
	while ($config{"avoid_ignore_$j"} ne "") {
		if ($chatMsgUser eq $config{"avoid_ignore_$j"}) {
			$statusGM = 0;
			last;
		}
		$j++;
	}

	if ($statusGM && $chatMsgUser =~ /^([a-z]?ro)?-?(Sub)?-?\[?GM\]?/i) {
		warning "Disconnecting to avoid GM!\n";
		chatLog("k", "*** The GM $chatMsgUser talked to you, auto disconnected ***\n");

		my $tmp = $config{'avoidGM_reconnect'};
		warning "Disconnect for $tmp seconds...\n";
		$timeout_ex{'master'}{'time'} = time;
		$timeout_ex{'master'}{'timeout'} = $tmp;
		Network::disconnect(\$remote_socket);
		return 1;
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
			warning "$players{$playersID[$i]}{'name'} ($players{$playersID[$i]}{'nameID'}) is nearby, teleporting...\n";
			chatLog("k", "*** Found $players{$playersID[$i]}{'name'} ($players{$playersID[$i]}{'nameID'}) nearby and teleported ***\n");
			useTeleport(1);
			return 1;
		}
	}
	return 0;
}

# avoidList_talk(playername, chatmsg, [playerid])
# playername: Name of the player who chatted/PMed the bot.
# chatmsg: Contents of the message. (currently not used)
# playerid: If present, check their player ID as well.
#
# Checks if the specified player is on the avoid.txt avoid list for chat messages,
# and disconnects if they are.
sub avoidList_talk {
	return if (!$config{'avoidList'} || $config{'XKore'});
	my ($chatMsgUser, $chatMsg, $nameID) = @_;

	if ($avoid{'Players'}{lc($chatMsgUser)}{'disconnect_on_chat'} || $avoid{'ID'}{$nameID}{'disconnect_on_chat'}) { 
		warning "Disconnecting to avoid $chatMsgUser!\n";
		chatLog("k", "*** $chatMsgUser talked to you, auto disconnected ***\n"); 
		warning "Disconnect for $config{'avoidList_reconnect'} seconds...\n";
		$timeout_ex{'master'}{'time'} = time;
		$timeout_ex{'master'}{'timeout'} = $config{'avoidList_reconnect'};
		Network::disconnect(\$remote_socket);
	}
}

sub compilePortals {
	my $checkOnly = shift;

	my %mapPortals;
	my %mapSpawns;
	my %missingMap;
	my @solution;

	# Collect portal source and destination coordinates per map
	foreach my $portal (keys %portals_lut) {
		%{$mapPortals{$portals_lut{$portal}{source}{map}}{$portal}} = %{$portals_lut{$portal}{source}{pos}};
		foreach my $dest (keys %{$portals_lut{$portal}{dest}}) {
			next if $portals_lut{$portal}{dest}{$dest}{map} eq '';
			%{$mapSpawns{$portals_lut{$portal}{dest}{$dest}{map}}{$dest}} = %{$portals_lut{$portal}{dest}{$dest}{pos}};
		}
	}

	# Calculate LOS values from each spawn point per map to other portals on same map
	foreach my $map (sort keys %mapSpawns) {
		message "Processing map $map...\n", "system" unless $checkOnly;
		foreach my $spawn (keys %{$mapSpawns{$map}}) {
			foreach my $portal (keys %{$mapPortals{$map}}) {
				next if $spawn eq $portal;
				next if $portals_los{$spawn}{$portal} ne '';
				if ($field{name} ne $map && !$missingMap{$map}) {
					$missingMap{$map} = 1 if (!getField("$Settings::def_field/$map.fld", \%field));
				}
				return 1 if $checkOnly;
				ai_route_getRoute(\@solution, \%field, \%{$mapSpawns{$map}{$spawn}}, \%{$mapPortals{$map}{$portal}});
				$portals_los{$spawn}{$portal} = scalar @solution;
				debug "LOS in $map from $mapSpawns{$map}{$spawn}{x},$mapSpawns{$map}{$spawn}{y} to $mapPortals{$map}{$portal}{x},$mapPortals{$map}{$portal}{y}: $portals_los{$spawn}{$portal}\n";
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
	my $pos1 = $chars[$config{'char'}]{'pos_to'};
	my $pos2 = shift;
	my $headdir = shift;
	my $dx = $pos2->{'x'} - $pos1->{'x'};
	my $dy = $pos2->{'y'} - $pos1->{'y'};
	my $bodydir = undef;

	if ($dx == 0) {
		if ($dy > 0) {
			$bodydir = 0;
		} elsif ($dy < 0) {
			$bodydir = 4;
		}
	} elsif ($dx < 0) {
		if ($dy > 0) {
			$bodydir = 1;
		} elsif ($dy < 0) {
			$bodydir = 3;
		} else {
			$bodydir = 2;
		}
	} else {
		if ($dy > 0) {
			$bodydir = 7;
		} elsif ($dy < 0) {
			$bodydir = 5;
		} else {
			$bodydir = 6;
		}
	}

	return unless (defined($bodydir));
	if ($headdir == 1) {
		$bodydir++;
		$bodydir -= 8 if ($bodydir > 7);
		look($bodydir, 1);
	} elsif ($headdir == 2) {
		$bodydir--;
		$bodydir += 8 if ($bodydir < 0);
		look($bodydir, 2);
	} else {
		look($bodydir);
	}
}

sub portalExists {
	my ($map, $r_pos) = @_;
	foreach (keys %portals_lut) {
		if ($portals_lut{$_}{'source'}{'map'} eq $map && $portals_lut{$_}{'source'}{'pos'}{'x'} == $$r_pos{'x'}
		 && $portals_lut{$_}{'source'}{'pos'}{'y'} == $$r_pos{'y'}) {
			return $_;
		}
	}
}

sub redirectXKoreMessages {
	my ($type, $domain, $level, $globalVerbosity, $message, $user_data) = @_;

	return if ($type eq "debug" || $level > 0 || $conState != 5 || $XKore_dontRedirect);
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
	if (!$id) {
		return 'Nothing';
	} elsif ($id eq $accountID) {
		return 'You';
	} elsif (my $player = $players{$id}) {
		return "Player $player->{name} ($player->{binID})";
	} elsif (my $monster = $monsters{$id}) {
		return "Monster $monster->{name} ($monster->{binID})";
	} elsif (my $item = $items{$id}) {
		return "Item $item->{name} ($item->{binID})";
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

sub useTeleport {
	my $level = shift;	
	my $invIndex = findIndex(\@{$chars[$config{'char'}]{'inventory'}}, "nameID", $level + 600);
	
	# it is safe to always set this value, because $ai_v{temp} is always cleared after teleport
	if (!$ai_v{temp}{teleport}{lv}) {
		$ai_v{temp}{teleport}{lv} = $level;
		
		# set a small timeout, will be overridden if related config in equipAuto is set
		$ai_v{temp}{teleport}{ai_equipAuto_skilluse_giveup}{time} = time;
		$ai_v{temp}{teleport}{ai_equipAuto_skilluse_giveup}{timeout} = 5;

	} elsif (defined $ai_v{temp}{teleport}{ai_equipAuto_skilluse_giveup} && timeOut(\%{$ai_v{temp}{teleport}{ai_equipAuto_skilluse_giveup}})) {
		warning "You don't have wing or skill to teleport/respawn or timeout elapsed\n";
		delete $ai_v{temp}{teleport};
	}

	# {'skills'}{'AL_TELEPORT'}{'lv'} is valid even after creamy is unequiped, use @skillsID instead
	if (!$config{teleportAuto_useItem} && binFind(\@skillsID, 'AL_TELEPORT') ne "") {
		sendSkillUse(\$remote_socket, $skillsID_rlut{teleport}, $level, $accountID) if ($config{'teleportAuto_useSP'});
		sendTeleport(\$remote_socket, "Random") if ($level == 1);
		sendTeleport(\$remote_socket, $config{'saveMap'}.".gat") if ($level == 2);
		delete $ai_v{temp}{teleport};
		
	} elsif ($config{teleportAuto_useItem} && $invIndex ne "") {
		sendItemUse(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$invIndex]{'index'}, $accountID);
		sendTeleport(\$remote_socket, "Random") if ($level == 1);
		delete $ai_v{temp}{teleport};
	}
}

# Keep track of when we last cast a skill
sub setSkillUseTimer {
	my ($skillID, $targetID) = @_;

	$chars[$config{char}]{skills}{$skills_rlut{lc($skillsID_lut{$skillID})}}{time_used} = time;
	undef $chars[$config{char}]{time_cast};

	# set partySkill target_time
	my $i = $targetTimeout{$targetID}{$skillID};
	$ai_v{"partySkill_${i}_target_time"}{$targetID} = time if $i;
}

# Increment counter for monster being casted on
sub countCastOn {
	my ($sourceID, $targetID) = @_;

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
	if ($cards[0] == 255) {
		# Forged item
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
		return 0 unless ($chars[$config{char}]{sp} >= $skillsSP_lut{$skills_rlut{lc($config{$prefix})}}{$config{$prefix . "_lvl"}})
	}

	if ($config{$prefix . "_aggressives"}) {
		return 0 unless (inRange(scalar ai_getAggressives(), $config{$prefix . "_aggressives"}));
	} elsif ($config{$prefix . "_maxAggressives"}) { # backward compatibility with old config format
		return 0 unless ($config{$prefix . "_minAggressives"} <= ai_getAggressives());
		return 0 unless ($config{$prefix . "_maxAggressives"} >= ai_getAggressives());
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

	if ($config{$prefix . "_aggressives"}) {
		return 0 unless (inRange(scalar ai_getPlayerAggressives($id), $config{$prefix . "_aggressives"}));
	} elsif ($config{$prefix . "_maxAggressives"}) { # backward compatibility with old config format
		return 0 unless ($config{$prefix . "_minAggressives"} <= ai_getPlayerAggressives($id));
		return 0 unless ($config{$prefix . "_maxAggressives"} >= ai_getPlayerAggressives($id));
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
	
	return 1;
}

sub checkMonsterCondition {
	$prefix = shift;
	$id = shift;

	if ($config{$prefix . "_whenStatusActive"}) {
		return 0 unless (whenStatusActiveMon($id, $config{$prefix . "_whenStatusActive"}));
	}
	if ($config{$prefix . "_whenStatusInactive"}) {
		return 0 if (whenStatusActiveMon($id, $config{$prefix . "_whenStatusInactive"}));
	}

	return 1;
}

##
# manualMove($dx, $dy)
#
# Moves the character offset from its current position.
sub manualMove {
	my ($dx, $dy) = @_;

	# Stop following if necessary
	if ($config{'follow'}) {
		configModify('follow', 0);
		aiRemove('follow');
	}

	# Stop moving if necessary
	aiRemove("move");
	aiRemove("route");
	aiRemove("mapRoute");

	ai_route($field{name}, $char->{pos_to}{x} + $dx, $char->{pos_to}{y} + $dy);
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

	sendOpenShop($shop{title}, \@items);
	message "Shop opened ($shop{title}) with ".@items." selling items.\n", "success";
	$shopstarted = 1;
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
