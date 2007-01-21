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
use Utils::Crypton;
use Utils::Whirlpool;
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
	undef %{$chars[$config{'char'}]{'skills'}} if ($chars[$config{'char'}]{'skills'});
	undef @skillsID;
	delete $chars[$config{'char'}]{'mute_period'};
	delete $chars[$config{'char'}]{'muted'};
	$useArrowCraft = 1;
}

# Initialize variables when you change map (after a teleport or after you walked into a portal)
sub initMapChangeVars {
	@portalsID_old = @portalsID;
	%portals_old = %portals;
	foreach (@portalsID_old) {
		next if (!$_ || !$portals_old{$_});
		$portals_old{$_}{gone_time} = time if (!$portals_old{$_}{gone_time});
	}

	$char->{old_pos_to} = {%{$char->{pos_to}}} if ($char->{pos_to});
	delete $chars[$config{'char'}]{'sitting'};
	delete $chars[$config{'char'}]{'dead'};
	delete $chars[$config{'char'}]{'warp'};
	$timeout{play}{time} = time;
	$timeout{ai_sync}{time} = time;
	$timeout{ai_sit_idle}{time} = time;
	$timeout{ai_teleport}{time} = time;
	$timeout{ai_teleport_idle}{time} = time;
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
	$ai_v{cart_time} = time + 60;
	$ai_v{inventory_time} = time + 60;
	$ai_v{temp} = {};
	$cart{inventory} = [];
	$chars[$config{char}]{inventory} = [];
	undef @venderItemList;
	undef $venderID;
	undef @venderListsID;
	undef %venderLists;
	undef %guild;
	undef %incomingGuild;
	undef @unknownObjects;
	undef @chatRoomsID;
	undef %chatRooms;
	undef @lastpm;
	undef %incomingFriend;

	$shopstarted = 0;
	$timeout{ai_shop}{time} = time;
	$timeout{ai_storageAuto}{time} = time + 5;
	$timeout{ai_buyAuto}{time} = time + 5;

	AI::clear("attack", "route", "move");
	ChatQueue::clear();

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
	$timeout{ai_shop}{time} = time;
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
# Special states:
# 1.5 (set by plugins): There is a special sequence for login servers and we must wait the plugins to finalize before continuing
# 1.2 (set by $config{gameGuard} == 2): Wait for the server response allowing us to continue login
# 1.3 (set by parseMsg()): The server allowed us to continue logging in, continue where we left off
# 2.5 (set by parseMsg()): Just passed character selection; next 4 bytes will be the account ID
sub checkConnection {
	return if ($xkore || $Settings::no_connect);

	if ($conState == 1 && (!$remote_socket || !$remote_socket->connected) && timeOut($timeout_ex{'master'}) && !$conState_tries) {
		my $master = $masterServer = $masterServers{$config{'master'}};

		if ($master->{serverType} ne '' && $config{serverType} != $master->{serverType}) {
			configModify('serverType', $master->{serverType});
		}
		if ($master->{chatLangCode} ne '' && $config{chatLangCode} != $master->{chatLangCode}) {
			configModify('chatLangCode', $master->{chatLangCode});
		}
		if ($master->{storageEncryptKey} ne '' && $config{storageEncryptKey} ne $master->{storageEncryptKey}) {
			configModify('storageEncryptKey', $master->{storageEncryptKey});
		}
		if ($master->{gameGuard} ne '' && $config{gameGuard} != $master->{gameGuard}) {
			configModify('gameGuard', $master->{gameGuard});
		}

		message("Connecting to Master Server...\n", "connection");
		$shopstarted = 1;
		$conState_tries++;
		$initSync = 1;
		undef $msg;
		Network::connectTo(\$remote_socket, $master->{ip}, $master->{port});

		# backported from 1.9.1
		# call plugin's hook to determine if we can continue the work
		if ($remote_socket && $remote_socket->connected) {
			Plugins::callHook("Network::serverConnect/master");
			return if ($conState == 1.5);
		}
		
		# ported from fakeGameGuard plugin
		if ($remote_socket && $remote_socket->connected && $config{gameGuard} == 2) {
			my $msg = pack("C*", 0x58, 0x02);
			#$net->serverSend($msg); (syntax from 1.9.1)
			sendMsgToServer(\$main::remote_socket, $msg);
			message "Requesting permission to logon on account server...\n";
			$conState = 1.2;
			return;
		}

		if ($remote_socket && $remote_socket->connected && $master->{secureLogin} >= 1) {
			my $code;

			message("Secure Login...\n", "connection");
			undef $secureLoginKey;

			if ($master->{secureLogin_requestCode} ne '') {
				$code = $master->{secureLogin_requestCode};
			} elsif ($config{secureLogin_requestCode} ne '') {
				$code = $config{secureLogin_requestCode};
			}

			if ($code ne '') {
				sendMasterCodeRequest(\$remote_socket, 'code', $code);
			} else {
				sendMasterCodeRequest(\$remote_socket, 'type', $master->{secureLogin_type});
			}

		} elsif ($remote_socket && $remote_socket->connected) {
			sendPreLoginCode(\$remote_socket, $master->{preLoginCode}) if ($master->{preLoginCode});
			sendMasterLogin(\$remote_socket, $config{'username'}, $config{'password'},
				$master->{master_version}, $master->{version});
		}

		$timeout{'master'}{'time'} = time;

	# we skipped some required connection operations while waiting for the server to allow as to login,
	# after we have successfully sent in the reply to the game guard challenge (using the poseidon server)
	# this conState will allow us to continue from where we left off.
	} elsif ($conState == 1.3) {
		$conState = 1;
		my $master = $masterServer = $masterServers{$config{'master'}};
		if ($master->{secureLogin} >= 1) {
			my $code;

			message("Secure Login...\n", "connection");
			undef $secureLoginKey;

			if ($master->{secureLogin_requestCode} ne '') {
				$code = $master->{secureLogin_requestCode};
			} elsif ($config{secureLogin_requestCode} ne '') {
				$code = $config{secureLogin_requestCode};
			}

			if ($code ne '') {
				sendMasterCodeRequest(\$remote_socket, 'code', $code);
			} else {
				sendMasterCodeRequest(\$remote_socket, 'type', $master->{secureLogin_type});
			}

		} else {
			sendPreLoginCode(\$remote_socket, $master->{preLoginCode}) if ($master->{preLoginCode});
			sendMasterLogin(\$remote_socket, $config{'username'}, $config{'password'},
				$master->{master_version}, $master->{version});
		}

		$timeout{'master'}{'time'} = time;

	} elsif ($conState == 1 && $masterServer->{secureLogin} >= 1 && $secureLoginKey ne ""
	   && !timeOut($timeout{'master'}) && $conState_tries) {

		my $master = $masterServer;
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
		$conState = 1;
		undef $conState_tries;

	# backported from 1.9.1
	} elsif ($conState == 1.5) {
		
		if (!($remote_socket && $remote_socket->connected)) {
			$conState = 1;
			undef $conState_tries;
			return;
		}
		
		# on this special stage, the plugin will know what to do next.
		Plugins::callHook("Network::serverConnect/special");
		
	} elsif ($conState == 2 && !($remote_socket && $remote_socket->connected())
	  && ($config{'server'} ne "" || $masterServer->{charServer_ip})
	  && !$conState_tries) {
		my $master = $masterServer;
		message("Connecting to Game Login Server...\n", "connection");
		$conState_tries++;

		if ($master->{charServer_ip}) {
			Network::connectTo(\$remote_socket, $master->{charServer_ip}, $master->{charServer_port});
		} elsif ($servers[$config{'server'}]) {
			Network::connectTo(\$remote_socket, $servers[$config{'server'}]{'ip'}, $servers[$config{'server'}]{'port'});
		} else {
			error "Invalid server specified, server $config{server} does not exist...\n", "connection";
		}

		# backported from 1.9.1
		# call plugin's hook to determine if we can continue the connection
		if ($remote_socket && $remote_socket->connected) {
			Plugins::callHook("Network::serverConnect/char");
			return if ($conState == 1.5);
		}
		
		# integrate fakeGameGuard here

		sendGameLogin(\$remote_socket, $accountID, $sessionID, $sessionID2, $accountSex);
		$timeout{'gamelogin'}{'time'} = time;

	} elsif ($conState == 2 && timeOut($timeout{'gamelogin'})
	  && ($config{'server'} ne "" || $masterServer->{'charServer_ip'})) {
		error "Timeout on Game Login Server, reconnecting...\n", "connection";
		$timeout_ex{'master'}{'time'} = time;
		$timeout_ex{'master'}{'timeout'} = $timeout{'reconnect'}{'timeout'};
		Network::disconnect(\$remote_socket);
		$conState = 1;
		undef $conState_tries;

	} elsif ($conState == 3 && !($remote_socket && $remote_socket->connected()) && $config{'char'} ne "" && !$conState_tries) {
		message("Connecting to Character Select Server...\n", "connection");
		$conState_tries++;
		Network::connectTo(\$remote_socket, $servers[$config{'server'}]{'ip'}, $servers[$config{'server'}]{'port'});

		# backported from 1.9.1
		# call plugin's hook to determine if we can continue the connection
		if ($remote_socket && $remote_socket->connected) {
			Plugins::callHook("Network::serverConnect/charselect");
			return if ($conState == 1.5);
		}

		# integrate fakeGameGuard here

		sendCharLogin(\$remote_socket, $config{'char'});
		$timeout{'charlogin'}{'time'} = time;

	} elsif ($conState == 3 && timeOut($timeout{'charlogin'}) && $config{'char'} ne "") {
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

		# backported from 1.9.1
		# call plugin's hook to determine if we can continue the connection
		if ($remote_socket && $remote_socket->connected) {
			Plugins::callHook("Network::serverConnect/mapserver");
			return if ($conState == 1.5);
		}

		# integrate fakeGameGuard here

		sendMapLogin(\$remote_socket, $accountID, $charID, $sessionID, $accountSex2);
		$timeout_ex{master}{time} = time;
		$timeout_ex{master}{timeout} = $timeout{reconnect}{timeout};
		$timeout{maplogin}{time} = time;

	} elsif ($conState == 4 && timeOut($timeout{maplogin})) {
		message("Timeout on Map Server, connecting to Master Server...\n", "connection");
		$timeout_ex{master}{timeout} = $timeout{reconnect}{timeout};
		Network::disconnect(\$remote_socket);
		$conState = 1;
		undef $conState_tries;

	} elsif ($conState == 5 && !($remote_socket && $remote_socket->connected())) {
		error "Disconnected from Map Server, ", "connection";
		if ($config{dcOnDisconnect}) {
			chatLog("k", "*** You disconnected, auto quit! ***\n");
			error "exiting...\n", "connection";
			$quit = 1;
		} else {
			error "connecting to Master Server in $timeout_ex{master}{timeout} seconds...\n", "connection";
			$timeout_ex{master}{time} = time;
			$conState = 1;
			undef $conState_tries;
		}

	} elsif ($conState == 5 && timeOut($timeout{play})) {
		error "Timeout on Map Server, ", "connection";
		if ($config{dcOnDisconnect}) {
			error "exiting...\n", "connection";
			$quit = 1;
		} else {
			error "connecting to Master Server in $timeout{reconnect}{timeout} seconds...\n", "connection";
			$timeout_ex{master}{time} = time;
			$timeout_ex{master}{timeout} = $timeout{reconnect}{timeout};
			Network::disconnect(\$remote_socket);
			$conState = 1;
			undef $conState_tries;
		}
	}
	#print "$conState:";
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
			if (defined(my $input = $interface->getInput(0))) {
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
				my $msg_length = length($msg);
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
		my $new;

		$remote_socket->recv($new, $Settings::MAX_READ);
		if ($new eq '') {
			# Connection from server closed
			close($remote_socket);

		} else {
			$msg .= $new;
			my $msg_length = length($msg);
			while ($msg ne "") {
				$msg = parseMsg($msg);
				return if ($msg_length == length($msg));
				$msg_length = length($msg);
			}
		}
	}

	# GameGuard support
	if ($config{gameGuard} && !$config{XKore}) {
		my $result = Poseidon::Client::getInstance()->getResult();
		if (defined($result)) {
			debug "Received Poseidon result.\n", "poseidon";
			$remote_socket->send($result);
		}
	}

	# Process AI
	if ($conState == 5 && timeOut($timeout{ai}) && $remote_socket && $remote_socket->connected) {
		AI();
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

			# A relogin is necessary if the server host/port, username
			# or char is different.
			my $oldMaster = $masterServer;
			my $oldUsername = $config{'username'};
			my $oldChar = $config{'char'};

			switchConfigFile($file);

			my $master = $masterServer = $masterServers{$config{'master'}};
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

	processStatisticsReporting();

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
		#
		# If you're still not convinced about the security of this,
		# please read the following web pages for more details and explanation:
		#   http://www.openkore.com/statistics.php
		# -and-
		#   http://forums.openkore.com/viewtopic.php?t=28044
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
	$printType = shift if ($xkore);

	debug("Input: $input\n", "parseInput", 2);

	if ($printType) {
		my $hookOutput = sub {
			my ($type, $domain, $level, $globalVerbosity, $message, $user_data) = @_;
			$msg .= $message if ($type ne 'debug' && $level <= $globalVerbosity);
		};
		$hook = Log::addHook($hookOutput);
		$interface->writeOutput("console", "$input\n");
	}
	$XKore_dontRedirect = 1 if ($xkore);

	# Check if in special state
	if (!$xkore && $conState == 2 && $waitingForInput) {
		configModify('server', $input, 1);
		$waitingForInput = 0;

	} else {
		Commands::run($input);
	}

	if ($printType) {
		Log::delHook($hook);
		if ($xkore && defined $msg && $conState == 5) {
			$msg =~ s/\n*$//s;
			$msg =~ s/\n/\\n/g;
			sendMessage(\$remote_socket, "k", $msg);
		}
	}
	$XKore_dontRedirect = 0 if ($xkore);
}

#######################################
#######################################
#AI
#######################################
#######################################



sub AI {
	if (timeOut($timeout{ai_wipe_check})) {
		my $timeout = $timeout{ai_wipe_old}{timeout};

		foreach (keys %players_old) {
			if (timeOut($players_old{$_}{'gone_time'}, $timeout)) {
				delete $players_old{$_};
				binRemove(\@playersID_old, $_);
			}
		}
		foreach (keys %monsters_old) {
			if (timeOut($monsters_old{$_}{'gone_time'}, $timeout)) {
				delete $monsters_old{$_};
				binRemove(\@monstersID_old, $_);
			}
		}
		foreach (keys %npcs_old) {
			delete $npcs_old{$_} if (time - $npcs_old{$_}{'gone_time'} >= $timeout{'ai_wipe_old'}{'timeout'});
		}
		foreach (keys %items_old) {
			delete $items_old{$_} if (time - $items_old{$_}{'gone_time'} >= $timeout{'ai_wipe_old'}{'timeout'});
		}
		foreach (keys %portals_old) {
			if (timeOut($portals_old{$_}{gone_time}, $timeout)) {
				delete $portals_old{$_};
				binRemove(\@portalsID_old, $_);
			}
		}

		# Remove players that are too far away; sometimes they don't get
		# removed from the list for some reason
		foreach (keys %players) {
			if (distance($char->{pos_to}, $players{$_}{pos_to}) > 35) {
				delete $players{$_};
				binRemove(\@playersID, $_);
			}
		}

		$timeout{'ai_wipe_check'}{'time'} = time;
		debug "Wiped old\n", "ai", 2;
	}

	if (timeOut($timeout{ai_getInfo})) {
		sub isSuspicious {
			# Check whether this actor is used to detect bots.
			my ($object, $pos_name) = @_;
			return $object->{statuses}{"GM Perfect Hide"} || distance($char->{pos_to}, $object->{$pos_name}) > 19;
		}

		while (@unknownObjects) {
			my $ID = $unknownObjects[0];
			my $object = $players{$ID} || $npcs{$ID};
			my $pos_name;

			if ($players{$ID}) {
				$pos_name = 'pos_to';
			} else {
				$pos_name = 'pos';
			}
			if (!$object || $object->{gotName} || isSuspicious($object, $pos_name)) {
				shift @unknownObjects;
				if (isSuspicious($object, $pos_name)) {
					if ($players{$ID}) {
						delete $players{$ID};
						binRemove(\@playersID, $ID);
					} elsif ($npcs{$ID}) {
						delete $npcs{$ID};
						binRemove(\@npcsID, $ID);
					}
				}
				next;
			}
			sendGetPlayerInfo(\$remote_socket, $ID);
			push(@unknownObjects, shift(@unknownObjects));
			last;
		}

		foreach (keys %monsters) {
			if ($monsters{$_}{'name'} =~ /Unknown/) {
				if (isSuspicious($monsters{$_}, 'pos_to')) {
					delete $monsters{$_};
					binRemove(\@monstersID, $_);
				} else {
					sendGetPlayerInfo(\$remote_socket, $_);
					last;
				}
			}
		}
		foreach (keys %pets) { 
			if ($pets{$_}{'name_given'} =~ /Unknown/) { 
				if (isSuspicious($pets{$_}, 'pos_to')) {
					delete $pets{$_};
					binRemove(\@petsID, $_);
				} else {
					sendGetPlayerInfo(\$remote_socket, $_);
					last;
				}
			}
		}
		$timeout{'ai_getInfo'}{'time'} = time;
	}

	if (!$xkore && timeOut($timeout{ai_sync})) {
		$timeout{ai_sync}{time} = time;
		sendSync(\$remote_socket);
	}

	if (timeOut($AI::Timeouts::mapdrt, $config{'intervalMapDrt'})) {
		$AI::Timeouts::mapdrt = time;
		if ($field{name}) {
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
		}
	}

	if (timeOut($char->{muted}, $char->{mute_period})) {
		delete $char->{muted};
		delete $char->{mute_period};
	}


	##### PORTALRECORD #####
	# Automatically record new unknown portals

	PORTALRECORD: {
		last unless $config{portalRecord};
		last unless $ai_v{portalTrace_mapChanged};
		delete $ai_v{portalTrace_mapChanged};

		debug "Checking for new portals...\n", "portalRecord";
		my $first = 1;
		my ($foundID, $smallDist, $dist);

		if (!$field{name}) {
			debug "Field name not known - abort\n", "portalRecord";
			last PORTALRECORD;
		}


		# Find the nearest portal or the only portal on the map
		# you came from (source portal)
		foreach (@portalsID_old) {
			next if (!$_);
			$dist = distance($char->{old_pos_to}, $portals_old{$_}{pos});
			if ($dist <= 7 && ($first || $dist < $smallDist)) {
				$smallDist = $dist;
				$foundID = $_;
				undef $first;
			}
		}

		my ($sourceMap, $sourceID, %sourcePos, $sourceIndex);
		if (defined $foundID) {
			$sourceMap = $portals_old{$foundID}{source}{map};
			$sourceID = $portals_old{$foundID}{nameID};
			%sourcePos = %{$portals_old{$foundID}{pos}};
			$sourceIndex = $foundID;
			debug "Source portal: $sourceMap ($sourcePos{x}, $sourcePos{y})\n", "portalRecord";
		} else {
			debug "No source portal found.\n", "portalRecord";
			last PORTALRECORD;
		}

		#if (defined portalExists($sourceMap, \%sourcePos)) {
		#	debug "Source portal is already in portals.txt - abort\n", "portalRecord";
		#	last PORTALRECORD;
		#}


		# Find the nearest portal or only portal on the
		# current map (destination portal)
		$first = 1;
		undef $foundID;
		undef $smallDist;

		foreach (@portalsID) {
			next if (!$_);
			$dist = distance($chars[$config{'char'}]{pos_to}, $portals{$_}{pos});
			if ($first || $dist < $smallDist) {
				$smallDist = $dist;
				$foundID = $_;
				undef $first;
			}
		}

		# Sanity checks
		if (!defined $foundID) {
			debug "No destination portal found.\n", "portalRecord";
			last PORTALRECORD;
		}
		#if (defined portalExists($field{name}, $portals{$foundID}{pos})) {
		#	debug "Destination portal is already in portals.txt\n", "portalRecord";
		#	last PORTALRECORD;
		#}
		if (defined portalExists2($sourceMap, \%sourcePos, $field{name}, $portals{$foundID}{pos})) {
			debug "This portal is already in portals.txt\n", "portalRecord";
			last PORTALRECORD;
		}


		# And finally, record the portal information
		my ($destMap, $destID, %destPos);
		$destMap = $field{name};
		$destID = $portals{$foundID}{nameID};
		%destPos = %{$portals{$foundID}{pos}};
		debug "Destination portal: $destMap ($destPos{x}, $destPos{y})\n", "portalRecord";

		$portals{$foundID}{name} = "$field{name} -> $sourceMap";
		$portals_old{$sourceIndex}{name} = "$sourceMap -> $field{name}";


		my ($ID, $destName);

		# Record information about destination portal
		if ($config{portalRecord} > 1 &&
		    !defined portalExists($field{name}, $portals{$foundID}{pos})) {
			$ID = "$field{name} $destPos{x} $destPos{y}";
			$portals_lut{$ID}{source}{map} = $field{name};
			$portals_lut{$ID}{source}{x} = $destPos{x};
			$portals_lut{$ID}{source}{y} = $destPos{y};
			$destName = "$sourceMap $sourcePos{x} $sourcePos{y}";
			$portals_lut{$ID}{dest}{$destName}{map} = $sourceMap;
			$portals_lut{$ID}{dest}{$destName}{x} = $sourcePos{x};
			$portals_lut{$ID}{dest}{$destName}{y} = $sourcePos{y};

			message "Recorded new portal (destination): $field{name} ($destPos{x}, $destPos{y}) -> $sourceMap ($sourcePos{x}, $sourcePos{y})\n", "portalRecord";
			updatePortalLUT("$Settings::tables_folder/portals.txt",
				$field{name}, $destPos{x}, $destPos{y},
				$sourceMap, $sourcePos{x}, $sourcePos{y});
		}

		# Record information about the source portal
		if (!defined portalExists($sourceMap, \%sourcePos)) {
			$ID = "$sourceMap $sourcePos{x} $sourcePos{y}";
			$portals_lut{$ID}{source}{map} = $sourceMap;
			$portals_lut{$ID}{source}{x} = $sourcePos{x};
			$portals_lut{$ID}{source}{y} = $sourcePos{y};
			$destName = "$field{name} $destPos{x} $destPos{y}";
			$portals_lut{$ID}{dest}{$destName}{map} = $field{name};
			$portals_lut{$ID}{dest}{$destName}{x} = $destPos{x};
			$portals_lut{$ID}{dest}{$destName}{y} = $destPos{y};
	
			message "Recorded new portal (source): $sourceMap ($sourcePos{x}, $sourcePos{y}) -> $field{name} ($char->{pos}{x}, $char->{pos}{y})\n", "portalRecord";
			updatePortalLUT("$Settings::tables_folder/portals.txt",
				$sourceMap, $sourcePos{x}, $sourcePos{y},
				$field{name}, $char->{pos}{x}, $char->{pos}{y});
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

	ChatQueue::processFirst();


	##### MISC #####

	if ($ai_seq[0] eq "look" && timeOut($timeout{'ai_look'})) {
		$timeout{'ai_look'}{'time'} = time;
		sendLook(\$remote_socket, $ai_seq_args[0]{'look_body'}, $ai_seq_args[0]{'look_head'});
		shift @ai_seq;
		shift @ai_seq_args;
	}

	if ($ai_seq[0] ne "deal" && %currentDeal) {
		AI::queue('deal');
	} elsif ($ai_seq[0] eq "deal") {
		if (%currentDeal) {
			if (!$currentDeal{you_finalize} && timeOut($timeout{ai_dealAuto}) &&
			    ($config{dealAuto} == 2 ||
				 $config{dealAuto} == 3 && $currentDeal{other_finalize})) {
				sendDealFinalize(\$remote_socket);
				$timeout{ai_dealAuto}{time} = time;
			} elsif ($currentDeal{other_finalize} && $currentDeal{you_finalize} &&timeOut($timeout{ai_dealAuto}) && $config{dealAuto} >= 2) {
				sendDealTrade(\$remote_socket);
				$timeout{ai_dealAuto}{time} = time;
			}
		} else {
			AI::dequeue();
		}
	}

	# dealAuto 1=refuse 2,3=accept
	if ($config{'dealAuto'} && %incomingDeal && timeOut($timeout{'ai_dealAuto'})) {
		if ($config{'dealAuto'} == 1) {
			sendDealCancel(\$remote_socket);
		} elsif ($config{'dealAuto'} >= 2) {
			sendDealAccept(\$remote_socket);
		}
		$timeout{'ai_dealAuto'}{'time'} = time;
	}


	# partyAuto 1=refuse 2=accept
	if ($config{'partyAuto'} && %incomingParty && timeOut($timeout{'ai_partyAuto'})) {
		if ($config{partyAuto} == 1) {
			message "Auto-denying party request\n";
		} else {
			message "Auto-accepting party request\n";
		}
		sendPartyJoin(\$remote_socket, $incomingParty{'ID'}, $config{'partyAuto'} - 1);
		$timeout{'ai_partyAuto'}{'time'} = time;
		undef %incomingParty;
	}

	if ($config{'guildAutoDeny'} && %incomingGuild && timeOut($timeout{'ai_guildAutoDeny'})) {
		sendGuildJoin(\$remote_socket, $incomingGuild{'ID'}, 0) if ($incomingGuild{'Type'} == 1);
		sendGuildAlly(\$remote_socket, $incomingGuild{'ID'}, 0) if ($incomingGuild{'Type'} == 2);
		$timeout{'ai_guildAutoDeny'}{'time'} = time;
		undef %incomingGuild;
	}


	if ($xkore && !$sentWelcomeMessage && timeOut($timeout{'welcomeText'})) {
		injectAdminMessage($Settings::welcomeText) if ($config{'verbose'} && !$config{'XKore_silent'});
		$sentWelcomeMessage = 1;
	}


	##### CLIENT SUSPEND #####
	# The clientSuspend AI sequence is used to freeze all other AI activity
	# for a certain period of time.

	if (AI::action eq 'clientSuspend' && timeOut(AI::args)) {
		debug "AI suspend by clientSuspend dequeued\n";
		AI::dequeue;
	} elsif (AI::action eq "clientSuspend" && $xkore) {
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
				if ($monsters{$ai_seq_args[0]{'args'}[1]} && %{$monsters{$ai_seq_args[0]{'args'}[1]}}) {
					$ai_seq_args[0]{'time'} = time;
				} else {
					$ai_seq_args[0]{'time'} -= $ai_seq_args[0]{'timeout'};
				}
				if (timeOut($ai_seq_args[0]{'forceGiveup'})) {
					$ai_seq_args[0]{'time'} -= $ai_seq_args[0]{'timeout'};
				}
			}

		} elsif ($ai_seq_args[0]{'type'} eq "009F") {
			# Player's manually picking up an item
			if (!$ai_seq_args[0]{'forceGiveup'}{'timeout'}) {
				$ai_seq_args[0]{'forceGiveup'}{'timeout'} = 4;
				$ai_seq_args[0]{'forceGiveup'}{'time'} = time;
			}
			if ($items{$ai_seq_args[0]{'args'}[0]} && %{$items{$ai_seq_args[0]{'args'}[0]}}) {
				$ai_seq_args[0]{'time'} = time;
			} else {
				$ai_seq_args[0]{'time'} -= $ai_seq_args[0]{'timeout'};
			}
			if (timeOut($ai_seq_args[0]{'forceGiveup'})) {
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
			my $stats;
			if ($config{"master"}) {
				$stats = $config{"master"};
				$stats =~ s/(\/| - |\(|\)|: | )/./g;
			} else {
				$stats = "unknown";
			}
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
	if (timeOut($AI::Timeouts::autoBreakTime, 30)) {
		my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime;
		my $hormin = sprintf("%02d:%02d", $hour, $min);
		my @wdays = ('sun','mon','tue','wed','thu','fri','sat');
		debug "autoBreakTime: hormin = $hormin, weekday = $wdays[$wday]\n", "autoBreakTime", 2;
		for (my $i = 0; exists $config{"autoBreakTime_$i"}; $i++) {
			next if (!$config{"autoBreakTime_$i"});

			if  ( ($wdays[$wday] eq lc($config{"autoBreakTime_$i"})) || (lc($config{"autoBreakTime_$i"}) eq "all") ) {
				if ($config{"autoBreakTime_${i}_startTime"} eq $hormin) {
					my ($hr1, $min1) = split /:/, $config{"autoBreakTime_${i}_startTime"};
					my ($hr2, $min2) = split /:/, $config{"autoBreakTime_${i}_stopTime"};
					my $time1 = $hr1 * 60 * 60 + $min1 * 60;
					my $time2 = $hr2 * 60 * 60 + $min2 * 60;
					my $diff = ($time2 - $time1) % (60 * 60 * 24);

					message("\nDisconnecting due to break time: " . $config{"autoBreakTime_$i"."_startTime"} . " to " . $config{"autoBreakTime_$i"."_stopTime"}."\n\n", "system");
					chatLog("k", "*** Disconnected due to Break Time: " . $config{"autoBreakTime_$i"."_startTime"}." to " . $config{"autoBreakTime_$i"."_stopTime"}." ***\n");

					$timeout_ex{'master'}{'timeout'} = $diff;
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
		}
		$AI::Timeouts::autoBreakTime = time;
	}


	##### TALK WITH NPC ######
	NPCTALK: {
		last NPCTALK if (AI::action ne "NPC");
		my $args = AI::args;
		$args->{time} = time unless $args->{time};

		if ($args->{stage} eq '') {
			unless (timeOut($char->{time_move}, $char->{time_move_calc} + 0.2)) {
				# Wait for us to stop moving before talking
			} elsif (timeOut($args->{time}, $timeout{ai_npcTalk}{timeout})) {
				error "Could not find the NPC at the designated location.\n", "ai_npcTalk";
				AI::dequeue;

			} elsif ($args->{nameID}) {
				# An NPC ID has been passed
				my $npc = pack("L1", $args->{nameID});
				last if (!$npcs{$npc} || $npcs{$npc}{'name'} eq '' || $npcs{$npc}{'name'} =~ /Unknown/i);
				$args->{ID} = $npc;
				$args->{name} = $npcs{$npc}{'name'};
				$args->{stage} = 'Talking to NPC';
				$args->{steps} = [];
				@{$args->{steps}} = parse_line('\s+', 0, "x $args->{sequence}");
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
						@{$args->{steps}} = parse_line('\s+', 0, "x $args->{sequence}");
						undef $args->{time};
						undef $ai_v{'npc_talk'}{'time'};
						lookAtPosition($args->{pos});
						last NPCTALK;
					}
				}
				foreach my $npc (@monstersID) {
					next if !$npc;
					if ( $monsters{$npc}{'pos'}{'x'} eq $args->{pos}{'x'} &&
					     $monsters{$npc}{'pos'}{'y'} eq $args->{pos}{'y'} ) {
						debug "Target Monster-NPC $monsters{$npc}{name} at ($args->{pos}{x},$args->{pos}{y}) found.\n", "ai_npcTalk";
						$args->{'nameID'} = $monsters{$npc}{'nameID'};
				     		$args->{'ID'} = $npc;
						$args->{'name'} = $monsters{$npc}{'name'};
						$args->{'stage'} = 'Talking to NPC';
						$args->{steps} = [];
						@{$args->{steps}} = parse_line('\s+', 0, "x $args->{sequence}");
						undef $args->{time};
						undef $ai_v{'npc_talk'}{'time'};
						lookAtPosition($args->{pos});
						last NPCTALK;
					}
				}
			}


		} elsif ($args->{mapChanged} || @{$args->{steps}} == 0) {
			message "Done talking with $args->{name}.\n", "ai_npcTalk";

			# Cancel conversation only if NPC is still around; otherwise
			# we could get disconnected.
			#sendTalkCancel(\$remote_socket, $args->{ID}) if $npcs{$args->{ID}};;
			AI::dequeue;

		} elsif (timeOut($args->{time}, $timeout{'ai_npcTalk'}{'timeout'})) {
			# If NPC does not respond before timing out, then by default, it's
			# a failure
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
			} elsif ( $ai_seq_args[0]{'steps'}[0] =~ /^b(\d+),(\d+)/i ) {
				my $itemID = $storeList[$1]{nameID};
				$ai_v{npc_talk}{itemID} = $itemID;
				sendBuy(\$remote_socket, $itemID, $2);
			} elsif ( $args->{steps}[0] =~ /b/i ) {
				sendGetStoreList(\$remote_socket, $args->{ID});
			} elsif ( $args->{steps}[0] =~ /e/i ) {
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
			if ($config{storageAuto} && !$config{storageAuto_notAfterDeath}) {
				message "Auto-storaging due to death\n";
				AI::queue("storageAuto");
			}
		}

	} elsif (AI::action ne "dead" && AI::action ne "deal" && $char->{'dead'}) {
		AI::clear();
		AI::queue("dead");
	}

	if (AI::action eq "dead" && $config{dcOnDeath} != -1 && time - $char->{dead_time} >= $timeout{ai_dead_respawn}{timeout}) {
		sendRespawn(\$remote_socket);
		$char->{'dead_time'} = time;
	}

	if (AI::action eq "dead" && $config{dcOnDeath} && $config{dcOnDeath} != -1) {
		message "Disconnecting on death!\n";
		chatLog("k", "*** You died, auto disconnect! ***\n");
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
	    $config{storageAuto} && ($config{storageAuto_npc} ne "" || $config{storageAuto_useChatCommand}) &&
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
			message "Auto-storaging due to excess weight\n";
			AI::queue("storageAuto");
		}

	} elsif (AI::is("", "route", "attack") &&
	         $config{storageAuto} && ($config{storageAuto_npc} ne "" || $config{storageAuto_useChatCommand}) &&
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
			message "Auto-storaging due to insufficient ".$config{"getAuto_$i"}."\n";
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

		my $do_route;

		if (!$config{storageAuto_useChatCommand}) {
			# Stop if the specified NPC is invalid
			$args->{npc} = {};
			getNPCInfo($config{'storageAuto_npc'}, $args->{npc});
			if (!defined($args->{npc}{ok})) {
				$args->{done} = 1;
				last AUTOSTORAGE;
			}

			# Determine whether we have to move to the NPC
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
			}
		}
		if (!$do_route) {
			# Talk to NPC if we haven't done so
			if (!defined($args->{sentStore})) {
				if ($config{storageAuto_useChatCommand}) {
					sendMessage(\$remote_socket, "c", $config{storageAuto_useChatCommand});
				} else {
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

					if (defined $args->{npc}{id}) { 
						ai_talkNPC(ID => $args->{npc}{id}, $config{'storageAuto_npc_steps'}); 
					} else {
						ai_talkNPC($args->{npc}{pos}{x}, $args->{npc}{pos}{y}, $config{'storageAuto_npc_steps'}); 
					}
				}

				delete $ai_v{temp}{storage_opened};
				$args->{sentStore} = 1;

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
					my $item = $char->{inventory}[$i];
					next unless ($item && %{$item});
					next if $item->{equipped};

					my $control = items_control($item->{name});
					my $store = $control->{storage};
					my $keep = $control->{keep};
					debug "AUTOSTORAGE: $item->{name} x $item->{amount} - store = $store, keep = $keep\n", "storage";
					if ($store && $item->{amount} > $keep) {
						if (AI::args->{lastIndex} == $item->{index} &&
						    timeOut($timeout{'ai_storageAuto_giveup'})) {
							last AUTOSTORAGE;
						} elsif (AI::args->{lastIndex} != $item->{index}) {
							$timeout{ai_storageAuto_giveup}{time} = time;
						}
						undef $args->{done};
						AI::args->{lastIndex} = $item->{index};
						sendStorageAdd(\$remote_socket, $item->{index}, $item->{amount} - $keep);
						$timeout{ai_storageAuto}{time} = time;
						AI::args->{nextItem} = $i + 1;
						last AUTOSTORAGE;
					}
				}

				if ($args->{done}) {
					# plugins can hook here and decide to keep storage open longer
					my %hookArgs;
					Plugins::callHook("AI_storage_done", \%hookArgs);
					undef $args->{done} if ($hookArgs{return});
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
				while (exists $config{"getAuto_$ai_seq_args[0]{index}"}) {
					if (!$config{"getAuto_$ai_seq_args[0]{index}"}) {
						$ai_seq_args[0]{index}++;
						next;
					}

					my %item;
					$item{name} = $config{"getAuto_$ai_seq_args[0]{index}"};
					$item{inventory}{index} = findIndexString_lc(\@{$chars[$config{char}]{inventory}}, "name", $item{name});
					$item{inventory}{amount} = ($item{inventory}{index} ne "") ? $chars[$config{char}]{inventory}[$item{inventory}{index}]{amount} : 0;
					$item{storage}{index} = findKeyString(\%storage, "name", $item{name});
					$item{storage}{amount} = ($item{storage}{index} ne "")? $storage{$item{storage}{index}}{amount} : 0;
					$item{max_amount} = $config{"getAuto_$ai_seq_args[0]{index}"."_maxAmount"};
					$item{amount_needed} = $item{max_amount} - $item{inventory}{amount};

					# Calculate the amount to get
					if ($item{amount_needed} > 0) {
						$item{amount_get} = ($item{storage}{amount} >= $item{amount_needed})? $item{amount_needed} : $item{storage}{amount};
					}

					# Try at most 3 times to get the item
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

					if (!$config{relogAfterStorage} && $ai_seq_args[0]{retry} >= 3 && !$ai_seq_args[0]{warned}) {
						# We tried 3 times to get the item and failed.
						# There is a weird server bug which causes this to happen,
						# but I can't reproduce it. This can be worked around by
						# relogging in after autostorage.
						warning "Kore tried to get an item from storage 3 times, but failed.\n";
						warning "This problem could be caused by a server bug.\n";
						warning "To work around this problem, set 'relogAfterStorage' to 1, and relogin.\n";
						$ai_seq_args[0]{warned} = 1;
					}

					# We got the item, or we tried 3 times to get it, but failed.
					# Increment index and process the next item.
					$ai_seq_args[0]{index}++;
					$ai_seq_args[0]{retry} = 0;
				}
			}

			sendStorageClose(\$remote_socket);
			if ($config{'relogAfterStorage'}) {
				writeStorageLog(0);
				relog();
			}
			$args->{done} = 1;
		}
	}
	} #END OF BLOCK AUTOSTORAGE



	#####AUTO SELL#####

	AUTOSELL: {

	if (($ai_seq[0] eq "" || $ai_seq[0] eq "route" || $ai_seq[0] eq "sitAuto" || $ai_seq[0] eq "follow") && $config{'sellAuto'} && $config{'sellAuto_npc'} ne ""
	  && (($config{'itemsMaxWeight_sellOrStore'} && percent_weight($char) >= $config{'itemsMaxWeight_sellOrStore'})
	      || (!$config{'itemsMaxWeight_sellOrStore'} && percent_weight($char) >= $config{'itemsMaxWeight'})
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
		my $var = $ai_seq_args[0]{'forcedByBuy'};
		my $var2 = $ai_seq_args[0]{'forcedByStorage'};
		message "Auto-sell sequence completed.\n", "success";
		AI::dequeue;
		if ($var2) {
			unshift @ai_seq, "buyAuto";
			unshift @ai_seq_args, {forcedByStorage => 1};
		} elsif (!$var) {
			unshift @ai_seq, "buyAuto";
			unshift @ai_seq_args, {forcedBySell => 1};
		}
	} elsif ($ai_seq[0] eq "sellAuto" && timeOut($timeout{'ai_sellAuto'})) {
		$ai_seq_args[0]{'npc'} = {};
		($config{sellAuto_standpoint}) ? getNPCInfo($config{'sellAuto_standpoint'}, $ai_seq_args[0]{'npc'}) : getNPCInfo($config{'sellAuto_npc'}, $ai_seq_args[0]{'npc'});
		if (!defined($ai_seq_args[0]{'npc'}{'ok'})) {
			$ai_seq_args[0]{'done'} = 1;
			last AUTOSELL;
		}

		undef $ai_v{'temp'}{'do_route'};
		if ($field{'name'} ne $ai_seq_args[0]{'npc'}{'map'}) {
			$ai_v{'temp'}{'do_route'} = 1;
		} else {
			$ai_v{'temp'}{'distance'} = distance($ai_seq_args[0]{'npc'}{'pos'}, $chars[$config{'char'}]{'pos_to'});
			$config{'sellAuto_distance'} = 1 if ($config{sellAuto_standpoint});
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
			$ai_seq_args[0]{'npc'} = {};
			getNPCInfo($config{'sellAuto_npc'}, $ai_seq_args[0]{'npc'});
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

			# Form list of 8 items to sell
			my @sellItems;
			for (my $i = 0; $i < @{$char->{inventory}};$i++) {
				my $item = $char->{inventory}[$i];
				next if (!$item || !%{$item} || $item->{equipped});
				my $sell = $items_control{all}{sell};
				$sell = $items_control{lc($item->{name})}{sell} if ($items_control{lc($item->{name})});
				my $keep = $items_control{all}{keep};
				$keep = $items_control{lc($item->{name})}{keep} if ($items_control{lc($item->{name})});

				if ($sell && $item->{'amount'} > $keep) {
					if (AI::args->{lastIndex} ne "" && AI::args->{lastIndex} == $item->{index} && timeOut($timeout{'ai_sellAuto_giveup'})) {
						last AUTOSELL;
					} elsif (AI::args->{lastIndex} eq "" || AI::args->{lastIndex} != $item->{index}) {
						$timeout{ai_sellAuto_giveup}{time} = time;
					}
					undef AI::args->{done};
					AI::args->{lastIndex} = $item->{index};

					my %obj;
					$obj{index} = $item->{index};
					$obj{amount} = $item->{amount} - $keep;
					push @sellItems, \%obj;

					$timeout{ai_sellAuto}{time} = time;
				}
			}
			sendSellBulk(\$remote_socket, \@sellItems) if (@sellItems);

			if (AI::args->{done}) {
				# plugins can hook here and decide to keep sell going longer
				my %hookArgs;
				Plugins::callHook("AI_sell_done", \%hookArgs);
				undef AI::args->{done} if ($hookArgs{return});
			}

		}
	}

	} #END OF BLOCK AUTOSELL



	#####AUTO BUY#####

	AUTOBUY: {

	if (($ai_seq[0] eq "" || $ai_seq[0] eq "route" || $ai_seq[0] eq "follow") && timeOut($timeout{'ai_buyAuto'}) && time > $ai_v{'inventory_time'}) {
		undef $ai_v{'temp'}{'found'};
		my $i = 0;
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

	} elsif ($ai_seq[0] eq "buyAuto" && timeOut($timeout{'ai_buyAuto_wait'}) && timeOut($timeout{'ai_buyAuto_wait_buy'})) {
		my $i = 0;
		undef $ai_seq_args[0]{'index'};
		
		while (1) {
			last if (!$config{"buyAuto_$i"});
			$ai_seq_args[0]{'invIndex'} = findIndexString_lc(\@{$chars[$config{'char'}]{'inventory'}}, "name", $config{"buyAuto_$i"});
			if (!$ai_seq_args[0]{'index_failed'}{$i} && $config{"buyAuto_$i"."_maxAmount"} ne "" && ($ai_seq_args[0]{'invIndex'} eq "" 
				|| $chars[$config{'char'}]{'inventory'}[$ai_seq_args[0]{'invIndex'}]{'amount'} < $config{"buyAuto_$i"."_maxAmount"})) {

				$ai_seq_args[0]{'npc'} = {};
				($config{"buyAuto_$i"."_standpoint"}) ? getNPCInfo($config{"buyAuto_$i"."_standpoint"}, $ai_seq_args[0]{'npc'}) : getNPCInfo($config{"buyAuto_$i"."_npc"}, $ai_seq_args[0]{'npc'});
				if (defined $ai_seq_args[0]{'npc'}{'ok'}) {
					$ai_seq_args[0]{'index'} = $i;
				}
				last;
			}
			$i++;
		}
		if ($ai_seq_args[0]{'index'} eq ""
			|| ($ai_seq_args[0]{'lastIndex'} ne "" && $ai_seq_args[0]{'lastIndex'} == $ai_seq_args[0]{'index'}
			&& timeOut($timeout{'ai_buyAuto_giveup'}))) {
			$ai_seq_args[0]{'done'} = 1;
			last AUTOBUY;
		}
		undef $ai_v{'temp'}{'do_route'};
		if ($field{'name'} ne $ai_seq_args[0]{'npc'}{'map'}) {
			$ai_v{'temp'}{'do_route'} = 1;			
		} else {
			$ai_v{'temp'}{'distance'} = distance($ai_seq_args[0]{'npc'}{'pos'}, $chars[$config{'char'}]{'pos_to'});
			$config{"buyAuto_$ai_seq_args[0]{'index'}"."_distance"} = 0 if ($config{"buyAuto_$i"."_standpoint"});
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
			$ai_seq_args[0]{'npc'} = {};
			getNPCInfo($config{"buyAuto_$i"."_npc"}, $ai_seq_args[0]{'npc'});
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

	if ((AI::isIdle || AI::is(qw/route move autoBuy follow sitAuto items_take items_gather/)) && timeOut($AI::Timeouts::autoCart, 2)) {
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
				getField($config{lockMap}, \%lockField);

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
					# Save which stat was raised, so that when we received the
					# "stat changed" packet (00BC?) we can changed $statChanged
					# back to 0 so that kore will start checking again if stats
					# need to be raised.
					# This basically prevents kore from sending packets to the
					# server super-fast, by only allowing another packet to be
					# sent when $statChanged is back to 0 (when the server has
					# replied with a a stat change)
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

	if (!$skillChanged && $config{skillsAddAuto}) {
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
				message "Auto-adding skill ".$skill->name."\n";

				# save which skill was raised, so that when we received the
				# "skill changed" packet (010F?) we can changed $skillChanged
				# back to 0 so that kore will start checking again if skills
				# need to be raised.
				# this basically does what $statChanged does for stats
				$skillChanged = $handle;
				# after we raise a skill, exit loop
				last;
			}
		}
	}


	##### RANDOM WALK #####
	if (AI::isIdle && $config{route_randomWalk} && !$cities_lut{$field{name}.'.rsw'} && length($field{rawMap}) ) {
		my ($randX, $randY);
		my $i = 500;
		do {
			$randX = int(rand($field{width}) + 1);
			$randX = int($config{'lockMap_x'} - $config{'lockMap_randX'} + rand(2*$config{'lockMap_randX'}+1)) if ($config{'lockMap_x'} ne '' && $config{'lockMap_randX'} ne '');
			$randY = int(rand($field{height}) + 1);
			$randY = int($config{'lockMap_y'} - $config{'lockMap_randY'} + rand(2*$config{'lockMap_randY'}+1)) if ($config{'lockMap_y'} ne '' && $config{'lockMap_randY'} ne '');
		} while (--$i && !checkFieldWalkable(\%field, $randX, $randY));
		if (!$i) {
			error "Invalid coordinates specified for randomWalk (coordinates are unwalkable); randomWalk disabled\n";
			$config{route_randomWalk} = 0;
		} else {
			message "Calculating random route to: $maps_lut{$field{name}.'.rsw'}($field{name}): $randX, $randY\n", "route";
			ai_route($field{name}, $randX, $randY,
				maxRouteTime => $config{route_randomWalk_maxRouteTime},
				attackOnRoute => 2,
				noMapRoute => ($config{route_randomWalk} == 2 ? 1 : 0) );
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
	} elsif (!$ai_seq_args[$followIndex]{'following'} && $players{$ai_seq_args[$followIndex]{'ID'}} && %{$players{$ai_seq_args[$followIndex]{'ID'}}}) {
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
		my $args = AI::args($followIndex);
		if (!$args->{ai_follow_lost}) {
			my $ID = $args->{ID};
			my $player = $players{$ID};

			if ($args->{following} && $player->{pos_to}) {
				my $dist = distance($char->{pos_to}, $player->{pos_to});
				if ($dist > $config{followDistanceMax} && timeOut($args->{move_timeout}, 0.25)) {
					$args->{move_timeout} = time;
					if ( $dist > 15 || ($config{followCheckLOS} && !checkLineWalkable($char->{pos_to}, $player->{pos_to})) ) {
						ai_route($field{name}, $player->{pos_to}{x}, $player->{pos_to}{y},
							attackOnRoute => 1,
							distFromGoal => $config{followDistanceMin});
					} else {
						my (%vec, %pos);
	
						stand() if ($char->{sitting});
						getVector(\%vec, $player->{pos_to}, $char->{pos_to});
						moveAlongVector(\%pos, $char->{pos_to}, \%vec, $dist - $config{followDistanceMin});
						$timeout{ai_sit_idle}{time} = time;
						sendMove($pos{x}, $pos{y});
					}
				}
			}
			
			if ($args->{following} && $player && %{$player}) {
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

	if ($ai_seq[0] eq "follow" && $ai_seq_args[$followIndex]{'following'} && ( ( $players{$ai_seq_args[$followIndex]{'ID'}} && $players{$ai_seq_args[$followIndex]{'ID'}}{'dead'} ) || ( ( !$players{$ai_seq_args[$followIndex]{'ID'}} || !%{$players{$ai_seq_args[$followIndex]{'ID'}}} ) && $players_old{$ai_seq_args[$followIndex]{'ID'}}{'dead'}))) {
		message "Master died.  I'll wait here.\n", "party";
		delete $ai_seq_args[$followIndex]{'following'};
	} elsif ($ai_seq_args[$followIndex]{'following'} && ( !$players{$ai_seq_args[$followIndex]{'ID'}} || !%{$players{$ai_seq_args[$followIndex]{'ID'}}} )) {
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
			$ai_seq_args[$followIndex]{'ai_follow_lost_vec'} = {};
			getVector($ai_seq_args[$followIndex]{'ai_follow_lost_vec'}, $players_old{$ai_seq_args[$followIndex]{'ID'}}{'pos_to'}, $chars[$config{'char'}]{'pos_to'});

			#check if player went through portal
			my $first = 1;
			my $foundID;
			my $smallDist;
			foreach (@portalsID) {
				$ai_v{'temp'}{'dist'} = distance($players_old{$ai_seq_args[$followIndex]{'ID'}}{'pos_to'}, $portals{$_}{'pos'});
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

		if (timeOut($ai_seq_args[$followIndex]{'ai_follow_lost_end'})) {
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
				moveAlongVector($ai_v{'temp'}{'pos'}, $chars[$config{'char'}]{'pos_to'}, $ai_seq_args[$followIndex]{'ai_follow_lost_vec'}, $config{'followLostStep'} / ($ai_seq_args[$followIndex]{'lost_stuck'} + 1));
				move($ai_v{'temp'}{'pos'}{'x'}, $ai_v{'temp'}{'pos'}{'y'});
			}
		} else {
			if ($ai_seq_args[$followIndex]{'follow_lost_portalID'} ne "") {
				if ($portals{$ai_seq_args[$followIndex]{'follow_lost_portalID'}} && %{$portals{$ai_seq_args[$followIndex]{'follow_lost_portalID'}}} && !$ai_seq_args[$followIndex]{'follow_lost_portal_tried'}) {
					$ai_seq_args[$followIndex]{'follow_lost_portal_tried'} = 1;
					%{$ai_v{'temp'}{'pos'}} = %{$portals{$ai_seq_args[$followIndex]{'follow_lost_portalID'}}{'pos'}};
					ai_route($field{'name'}, $ai_v{'temp'}{'pos'}{'x'}, $ai_v{'temp'}{'pos'}{'y'},
						attackOnRoute => 1);
				}
			} else {
				moveAlongVector($ai_v{'temp'}{'pos'}, $chars[$config{'char'}]{'pos_to'}, $ai_seq_args[$followIndex]{'ai_follow_lost_vec'}, $config{'followLostStep'});
				move($ai_v{'temp'}{'pos'}{'x'}, $ai_v{'temp'}{'pos'}{'y'});
			}
		}
	}

	# Use party information to find master
	if (!exists $ai_seq_args[$followIndex]{following} && !exists $ai_seq_args[$followIndex]{ai_follow_lost}) {
		ai_partyfollow();
	}
	} # end of FOLLOW block
	

	##### SITAUTO-IDLE #####
	if ($config{sitAuto_idle}) {
		if (!AI::isIdle && AI::action ne "follow") {
			$timeout{ai_sit_idle}{time} = time;
		}

		if ( !$char->{sitting} && timeOut($timeout{ai_sit_idle})
		 && (!$config{shopAuto_open} || timeOut($timeout{ai_shop})) ) {
			sit();
		}
	}

	##### SITTING #####
	if (AI::action eq "sitting") {
		if ($char->{sitting} || $char->{skills}{NV_BASIC}{lv} < 3) {
			# Stop if we're already sitting
			AI::dequeue;
			$timeout{ai_sit}{time} = $timeout{ai_sit_wait}{time} = 0;

		} elsif (!$char->{sitting} && timeOut($timeout{ai_sit}) && timeOut($timeout{ai_sit_wait})) {
			# Send the 'sit' packet every x seconds until we're sitting
			sendSit(\$remote_socket);
			$timeout{ai_sit}{time} = time;
			
			look($config{sitAuto_look}) if (defined $config{sitAuto_look});
		}
	}

	##### STANDING #####
	# Same logic as the 'sitting' AI
	if (AI::action eq "standing") {
		if (!$char->{sitting}) {
			AI::dequeue;

		} elsif (timeOut($timeout{ai_sit}) && timeOut($timeout{ai_stand_wait})) {
			sendStand(\$remote_socket);
			$timeout{ai_sit}{time} = time;
		}
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
			debug "sitAuto - sit\n", "sitAuto";
			sit();

		# Stand if our HP is high enough
		} elsif ($action eq "sitAuto" && ($ai_v{'sitAuto_forceStop'} || $upper_ok)) {
			AI::dequeue;
			debug "HP is now > $config{sitAuto_hp_upper}\n", "sitAuto";
			stand() if (!$config{'sitAuto_idle'} && $char->{sitting});

		} elsif (!$ai_v{'sitAuto_forceStop'} && ($weight < 50 || $config{'sitAuto_over_50'}) && AI::action ne "sitAuto") {
			if ($action eq "" || $action eq "follow"
			|| ($action eq "route" && !AI::args->{noSitAuto})
			|| ($action eq "mapRoute" && !AI::args->{noSitAuto})
			) {
				if (!AI::inQueue("attack") && !ai_getAggressives()
				&& (percent_hp($char) < $config{'sitAuto_hp_lower'} || percent_sp($char) < $config{'sitAuto_sp_lower'})) {
					AI::queue("sitAuto");
					debug "Auto-sitting\n", "sitAuto";
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

	if (AI::action eq "attack" && timeOut(AI::args->{ai_attack_giveup}) && !$config{attackNoGiveup}) {
		my $ID = AI::args->{ID};
		$monsters{$ID}{attack_failed} = time if ($monsters{$ID});
		AI::dequeue;
		message "Can't reach or damage target, dropping target\n", "ai_attack";
		useTeleport(1) if ($config{'teleportAuto_dropTarget'});

	} elsif (AI::action eq "attack" && !$monsters{$ai_seq_args[0]{ID}}) {
		# Monster died or disappeared
		$timeout{'ai_attack'}{'time'} -= $timeout{'ai_attack'}{'timeout'};
		my $ID = AI::args->{ID};
		AI::dequeue;

		if ($monsters_old{$ID} && $monsters_old{$ID}{dead}) {
			message "Target died\n", "ai_attack";
			monKilled();

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
			 && (!$config{"attackComboSlot_${i}_monsters"} || existsInList($config{"attackComboSlot_${i}_monsters"}, $monsters{$ID}{name}))
			 && (!$config{"attackComboSlot_${i}_notMonsters"} || !existsInList($config{"attackComboSlot_${i}_notMonsters"}, $monsters{$ID}{name}))
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

				my $skill = Skills->new(name => $config{"attackSkillSlot_$i"});
				if (checkSelfCondition("attackSkillSlot_$i")
					&& (!$config{"attackSkillSlot_$i"."_maxUses"} ||
					    $monsters{$ID}{skillUses}{$skill->handle} < $config{"attackSkillSlot_$i"."_maxUses"})
					&& (!$config{"attackSkillSlot_$i"."_maxAttempts"} || $args->{attackSkillSlot_attempts}{$i} < $config{"attackSkillSlot_$i"."_maxAttempts"})
					&& (!$config{"attackSkillSlot_$i"."_monsters"} || existsInList($config{"attackSkillSlot_$i"."_monsters"}, $monsters{$ID}{'name'}))
					&& (!$config{"attackSkillSlot_$i"."_notMonsters"} || !existsInList($config{"attackSkillSlot_$i"."_notMonsters"}, $monsters{$ID}{'name'}))
					&& (!$config{"attackSkillSlot_$i"."_previousDamage"} || inRange($monsters{$ID}{dmgTo}, $config{"attackSkillSlot_$i"."_previousDamage"}))
					&& checkMonsterCondition("attackSkillSlot_${i}_target", $monsters{$ID})
				) {
					$args->{attackSkillSlot_attempts}{$i}++;
					$args->{attackMethod}{distance} = $config{"attackSkillSlot_$i"."_dist"};
					$args->{attackMethod}{maxDistance} = $config{"attackSkillSlot_$i"."_dist"};
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

		$args->{attackMethod}{maxDistance} ||= $config{attackMaxDistance};
		$args->{attackMethod}{distance} ||= $config{attackDistance};
		if ($args->{attackMethod}{maxDistance} < $args->{attackMethod}{distance}) {
			$args->{attackMethod}{maxDistance} = $args->{attackMethod}{distance};
		}

		if ($char->{sitting}) {
			ai_setSuspend(0);
			stand();

		} elsif (!$cleanMonster) {
			# Drop target if it's already attacked by someone else
			message "Dropping target - you will not kill steal others\n", "ai_attack";
			sendMove($realMyPos->{x}, $realMyPos->{y});
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
					my $pos = ($config{"attackSkillSlot_${slot}_isSelfSkill"}) ? $char->{pos_to} : $monsters{$ID}{pos_to};
					ai_skillUse(
						$skills_rlut{lc($config{"attackSkillSlot_$slot"})},
						$config{"attackSkillSlot_${slot}_lvl"},
						$config{"attackSkillSlot_${slot}_maxCastTime"},
						$config{"attackSkillSlot_${slot}_minCastTime"},
						$pos->{x},
						$pos->{y},
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
				} elsif ($config{"useSelf_item_${i}_dcOnEmpty"}) {
					error "Disconnecting on empty ".$config{"useSelf_item_$i"}."!\n";
					chatLog("k", "Disconnecting on empty ".$config{"useSelf_item_$i"}."!\n");
					quit();
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
				my ($sp_req, $amount);
				
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
		if ($config{"useSelf_skill_$i"."_smartEncore"} &&
			$char->{encoreSkill} &&
			$char->{encoreSkill}->handle eq $self_skill{ID}) {
			# Use Encore skill instead if applicable
			$self_skill{ID} = 'BD_ENCORE';
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

	if (AI::isIdle || AI::is(qw(route mapRoute follow sitAuto take items_gather items_take attack move))){
		my %party_skill;
		for (my $i = 0; exists $config{"partySkill_$i"}; $i++) {
			next if (!$config{"partySkill_$i"});
			foreach my $ID (@playersID) {
				next if ($ID eq "");
				next if ((!$char->{party} || !$char->{party}{users}{$ID}) && !$config{"partySkill_$i"."_notPartyOnly"});
				# messy way to find the best object
				# but don't use object methods on this because we aren't sure if it's blessed
				my $player = $char->{party} ? ($char->{party}{users}{$ID} || $players{$ID}) : $players{$ID};
				if (inRange(distance($char->{pos_to}, $players{$ID}{pos}), $config{partySkillDistance} || "1..8")
					&& (!$config{"partySkill_$i"."_target"} || existsInList($config{"partySkill_$i"."_target"}, $player->{name}))
					&& checkPlayerCondition("partySkill_$i"."_target", $ID)
					&& checkSelfCondition("partySkill_$i")
					){
					$party_skill{skillID} = $skills_rlut{lc($config{"partySkill_$i"})};
					$party_skill{skillLvl} = $config{"partySkill_$i"."_lvl"};
					$party_skill{target} = $player->{name};
					$party_skill{x} = $player->{pos}{x};
					$party_skill{y} = $player->{pos}{y};
					$party_skill{targetID} = $ID;
					$party_skill{maxCastTime} = $config{"partySkill_$i"."_maxCastTime"};
					$party_skill{minCastTime} = $config{"partySkill_$i"."_minCastTime"};
					# This is used by setSkillUseTimer() to set
					# $ai_v{"partySkill_${i}_target_time"}{$targetID}
					# when the skill is actually cast
					$targetTimeout{$ID}{$party_skill{skillID}} = $i;
					last;
				}

			}
			last if (defined $party_skill{targetID});
		}

		if ($config{useSelf_skill_smartHeal} && $party_skill{skillID} eq "AL_HEAL") {
			my $smartHeal_lv = 1;
			my $hp_diff;
			if ($char->{party} && $char->{party}{users}{$party_skill{targetID}} && $char->{party}{users}{$party_skill{targetID}}{hp}) {
				$hp_diff = $char->{party}{users}{$party_skill{targetID}}{hp_max} - $char->{party}{users}{$party_skill{targetID}}{hp};
			} else {
				$hp_diff = -$players{$party_skill{targetID}}{deltaHp};
			}
			for (my $i = 1; $i <= $char->{skills}{$party_skill{skillID}}{lv}; $i++) {
				my ($sp_req, $amount);
				
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
			debug qq~Party Skill used ($party_skill{target}) Skills Used: $skills_lut{$party_skill{skillID}} (lvl $party_skill{skillLvl})\n~, "skill";
			if (!ai_getSkillUseType($party_skill{skillID})) {
				ai_skillUse($party_skill{skillID}, $party_skill{skillLvl}, $party_skill{maxCastTime}, $party_skill{minCastTime}, $party_skill{targetID});
			} else {
				ai_skillUse($party_skill{skillID}, $party_skill{skillLvl}, $party_skill{maxCastTime}, $party_skill{minCastTime}, $party_skill{x}, $party_skill{y});
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
			my @monsterIDs = ai_getAggressives(1, 1);
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
			 && (!$config{"equipAuto_${i}_weight"} || $char->{percent_weight} >= $config{"equipAuto_$i" . "_weight"})
			 && (!$config{"equipAuto_${i}_onTeleport"} || $ai_v{temp}{teleport}{lv})
			 && (!$config{"equipAuto_${i}_whileSitting"} || ($config{"equipAuto_${i}_whileSitting"} && $char->{sitting}))
			 && (!$config{"equipAuto_${i}_monsters"} || (defined $monster && existsInList($config{"equipAuto_$i" . "_monsters"}, $monster->{name})))
			 && (!$config{"equipAuto_${i}_skills"} || (defined $currentSkill && existsInList($config{"equipAuto_$i" . "_skills"}, $currentSkill)))
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
					} elsif (!$config{"equipAuto_${i}_onTeleport"} || $ai_v{temp}{teleport}{lv}) {
						$ai_v{temp}{teleport}{ai_equipAuto_skilluse_giveup}{time} = time;
						$ai_v{temp}{teleport}{ai_equipAuto_skilluse_giveup}{timeout} = $timeout{ai_equipAuto_skilluse_giveup}{timeout};
						warning "set timeout\n";
					}
					
					debug "Auto-equip: $char->{inventory}[$index]{name} ($index)\n", "equipAuto";
					last;
				}

			} elsif ($config{"equipAuto_${i}_def"} && !$char->{sitting} && !$config{"equipAuto_${i}_disabled"}) {
				my $index = findIndexString_lc_not_equip(\@{$char->{inventory}}, "name", $config{"equipAuto_${i}_def"});
				if (defined $index) {
					sendEquip(\$remote_socket, $char->{inventory}[$index]{index}, $char->{inventory}[$index]{type_equip});
					$timeout{ai_item_equip_auto}{time} = time;
					debug "Auto-equip: $char->{inventory}[$index]{name} ($index)\n", "equipAuto";
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

	SKILL_USE: {
		last SKILL_USE if (AI::action ne "skill_use");
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

				if ($handle eq 'AL_TELEPORT') {
					${$args->{ret}} = 'ok' if ($args->{ret});
					AI::dequeue;
					useTeleport($args->{lv});
					last SKILL_USE;
				}

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

				# Give an error if we don't actually possess this skill
				if ($char->{skills}{$handle}{lv} <= 0 && (!$char->{permitSkill} || $char->{permitSkill}->handle ne $handle)) {
					my $skill = new Skills(handle => $handle);
					debug "Attempted to use skill (".$skill->name.") which you do not have.\n";
				}

				if ($skillsArea{$handle} == 2) {
					sendSkillUse(\$remote_socket, $skillID, $args->{lv}, $accountID);
				} elsif ($args->{x} ne "") {
					sendSkillUseLoc(\$remote_socket, $skillID, $args->{lv}, $args->{x}, $args->{y});
				} else {
					sendSkillUse(\$remote_socket, $skillID, $args->{lv}, $args->{target});
				}
				undef $char->{permitSkill};
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
	  && timeOut($timeout{ai_attack_auto})
	  && (!$config{teleportAuto_search} || $ai_v{temp}{searchMonsters} > 0)) {

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
				if ((my $monCtrl = mon_control($monName))) {
					next if ( ($monCtrl->{attack_auto} ne "" && $monCtrl->{attack_auto} <= 0)
						|| ($monCtrl->{attack_lvl} ne "" && $monCtrl->{attack_lvl} > $char->{lv})
						|| ($monCtrl->{attack_jlvl} ne "" && $monCtrl->{attack_jlvl} > $char->{lv_job})
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
				next if (mon_control($name)->{attack_auto} == -1);
				next if (mon_control($name)->{attack_lvl} ne "" && mon_control($name)->{attack_lvl} > $char->{lv});
				next if (mon_control($name)->{attack_jlvl} ne "" && mon_control($name)->{attack_jlvl} > $char->{lv_job});

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
					next if (mon_control($name)->{attack_auto} == -1);
					next if (mon_control($name)->{attack_lvl} ne "" && mon_control($name)->{attack_lvl} > $char->{lv});
					next if (mon_control($name)->{attack_jlvl} ne "" && mon_control($name)->{attack_jlvl} > $char->{lv_job});

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
					next if (mon_control($name)->{attack_auto} == -1);
					next if (mon_control($name)->{attack_lvl} ne "" && mon_control($name)->{attack_lvl} > $char->{lv});
					next if (mon_control($name)->{attack_jlvl} ne "" && mon_control($name)->{attack_jlvl} > $char->{lv_job});

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
				if (AI::args->{notifyUponArrival}) {
					message "Destination reached.\n", "success";
				} else {
					debug "Destination reached.\n", "route";
				}
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
					if (AI::args->{notifyUponArrival}) {
						message "Destination reached.\n", "success";
					} else {
						debug "Destination reached.\n", "route";
					}
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
			$ai_seq_args[0]{'dest'}{'field'} = {};
			getField($ai_seq_args[0]{dest}{map}, $ai_seq_args[0]{dest}{field});

			# Initializes the openlist with portals walkable from the starting point
			foreach my $portal (keys %portals_lut) {
				next if $portals_lut{$portal}{'source'}{'map'} ne $field{'name'};
				if ( ai_route_getRoute(\@{$args->{solution}}, \%field, $char->{pos_to}, \%{$portals_lut{$portal}{'source'}}) ) {
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
				my $destpos = "$args->{dest}{pos}{x},$args->{dest}{pos}{y}";
				$destpos = "($destpos)" if ($destpos ne "");
				warning "Unable to calculate how to walk from [$field{name}($char->{pos_to}{x},$char->{pos_to}{y})] " .
					"to [$args->{dest}{map}${destpos}] (no map solution).\n", "route";
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

				} elsif (distance($chars[$config{'char'}]{'pos_to'}, $ai_seq_args[0]{'mapSolution'}[0]{'pos'}) <= 10) {
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

				} elsif ( ai_route_getRoute( \@solution, \%field, $chars[$config{'char'}]{'pos_to'}, $ai_seq_args[0]{'mapSolution'}[0]{'pos'} ) ) {
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

			} elsif ( $portals_lut{"$ai_seq_args[0]{'mapSolution'}[0]{'map'} $ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'x'} $ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'y'}"}{'source'} ) {
				# This is a portal solution

				if ( 2 > distance($char->{pos_to}, $args->{mapSolution}[0]{pos}) ) {
					# Portal is within 'Enter Distance'
					$timeout{'ai_portal_wait'}{'timeout'} = $timeout{'ai_portal_wait'}{'timeout'} || 0.5;
					if ( timeOut($timeout{'ai_portal_wait'}) ) {
						sendMove(int($ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'x'}), int($ai_seq_args[0]{'mapSolution'}[0]{'pos'}{'y'}) );
						$timeout{'ai_portal_wait'}{'time'} = time;
					}

				} else {
					my $walk = 1;

					# Teleport until we're close enough to the portal
					$args->{teleport} = $config{route_teleport} if (!defined $args->{teleport});

					if ($args->{teleport} && !$cities_lut{"$field{name}.rsw"}
					&& !existsInList($config{route_teleport_notInMaps}, $field{name})
					&& ( !$config{route_teleport_maxTries} || $args->{teleportTries} <= $config{route_teleport_maxTries} )) {
						my $minDist = $config{route_teleport_minDistance};

						if ($args->{mapChanged}) {
							undef $args->{sentTeleport};
							undef $args->{mapChanged};
						}

						if (!$args->{sentTeleport}) {
							# Find first inter-map portal
							my $portal;
							for my $x (@{$args->{mapSolution}}) {
								$portal = $x;
								last unless $x->{map} eq $x->{dest_map};
							}

							my $dist = new PathFinding(
								start => $char->{pos_to},
								dest => $portal->{pos},
								field => \%field
							)->runcount;
							debug "Distance to portal ($portal->{portal}) is $dist\n", "route_teleport";

							if ($dist <= 0 || $dist > $minDist) {
								if ($dist > 0 && $config{route_teleport_maxTries} && $args->{teleportTries} >= $config{route_teleport_maxTries}) {
									debug "Teleported $config{route_teleport_maxTries} times. Falling back to walking.\n", "route_teleport";
								} else {
									message "Attempting to teleport near portal, try #".($args->{teleportTries} + 1)."\n", "route_teleport";
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
	if (AI::action eq "items_take" && timeOut(AI::args->{ai_items_take_start})) {
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
	if (AI::action eq "items_gather" && !$items{AI::args->{ID}} && !%{$items{AI::args->{ID}}}) {
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
			my (%vec, %pos);
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

	if (AI::action eq "take" && ( !$items{AI::args->{ID}} || !%{$items{AI::args->{ID}}} )) {
		AI::dequeue;

	} elsif (AI::action eq "take" && timeOut(AI::args->{ai_take_giveup})) {
		my $item = $items{AI::args->{ID}};
		message "Failed to take $item->{name} ($item->{binID}) from ($char->{pos}{x}, $char->{pos}{y}) to ($item->{pos}{x}, $item->{pos}{y})\n";
		$items{AI::args->{ID}}{take_failed}++;
		AI::dequeue;
		
	} elsif (AI::action eq "take") {
		my $ID = AI::args->{ID};
		my $myPos = $char->{pos};
		my $dist = distance($items{$ID}{pos}, $myPos);
		my $item = $items{AI::args->{ID}};
		debug "Planning to take $item->{name} ($item->{binID}), distance $dist\n", "drop";
		
		if ($char->{sitting}) {
			stand();

		} elsif ($dist > 2) {
			my (%vec, %pos);
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
			sendMove(AI::args->{move_to}{x}, AI::args->{move_to}{y});
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
		if (!$cities_lut{$map_name_lu}) {
			if ($config{teleportAuto_onlyWhenSafe}) {
				if (!binSize(\@playersID) || timeOut($timeout{ai_teleport_safe_force})) {
					$safe = 1;
					$timeout{ai_teleport_safe_force}{time} = time;
				}
			} else {
				$safe = 1;
			}
		}

		##### TELEPORT HP #####
		if ($safe && timeOut($timeout{ai_teleport_hp})
		  && (
			(
				($config{teleportAuto_hp} && percent_hp($char) <= $config{teleportAuto_hp})
				|| ($config{teleportAuto_sp} && percent_sp($char) <= $config{teleportAuto_sp})
			)
			&& scalar(ai_getAggressives())
			|| (
				$config{teleportAuto_minAggressives}
				&& scalar(ai_getAggressives()) >= $config{teleportAuto_minAggressives}
				&& !($config{teleportAuto_minAggressivesInLock} && $field{name} eq $config{'lockMap'})
		 	) || (
				$config{teleportAuto_minAggressivesInLock}
				&& scalar(ai_getAggressives()) >= $config{teleportAuto_minAggressivesInLock}
				&& $field{name} eq $config{'lockMap'}
			)
		  )
		) {
			message "Teleporting due to insufficient HP/SP or too many aggressives\n", "teleport";
			$ai_v{temp}{clear_aiQueue} = 1 if (useTeleport(1));
			$timeout{ai_teleport_hp}{time} = time;
			last TELEPORT;
		}

		##### TELEPORT MONSTER #####
		if ($safe && timeOut($timeout{ai_teleport_away})) {
			foreach (@monstersID) {
				next unless $_;
				if (mon_control($monsters{$_}{name})->{teleport_auto} == 1) {
					message "Teleporting to avoid $monsters{$_}{name}\n", "teleport";
					$ai_v{temp}{clear_aiQueue} = 1 if (useTeleport(1));
					$timeout{ai_teleport_away}{time} = time;
					last TELEPORT;
				}
			}
			$timeout{ai_teleport_away}{time} = time;
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
				$ai_v{temp}{clear_aiQueue} = 1 if (useTeleport(1));
				$timeout{ai_teleport_portal}{time} = time;
				last TELEPORT;
			}
			$timeout{ai_teleport_portal}{time} = time;
		}
	} # end of block teleport


	##### ALLOWED MAPS #####
	# Respawn/disconnect if you're on a map other than the specified
	# list of maps.
	# This is to mostly useful on pRO, where GMs warp you to a secret room.
	#
	# Here, we only check for respawn. (Disconnect is handled in
	# packets 0091 and 0092.)
	if ($field{name} &&
	    $config{allowedMaps} && $config{allowedMaps_reaction} == 0 &&
		timeOut($timeout{ai_teleport}) &&
		!existsInList($config{allowedMaps}, $field{name}) &&
		$ai_v{temp}{allowedMapRespawnAttempts} < 3) {
		warning "The current map ($field{name}) is not on the list of allowed maps.\n";
		chatLog("k", "** The current map ($field{name}) is not on the list of allowed maps.\n");
		ai_clientSuspend(0, 5);
		message "Respawning to save point.\n";
		chatLog("k", "** Respawning to save point.\n");
		$ai_v{temp}{allowedMapRespawnAttempts}++;
		useTeleport(2);
		$timeout{ai_teleport}{time} = time;
	}


	##### AUTO RESPONSE #####

	if (AI::action eq "autoResponse") {
		my $args = AI::args;

		if ($args->{mapChanged} || !$config{autoResponse}) {
			AI::dequeue;
		} elsif (timeOut($args)) {
			if ($args->{type} eq "c") {
				sendMessage(\$remote_socket, "c", $args->{reply});
			} elsif ($args->{type} eq "pm") {
				sendMessage(\$remote_socket, "pm", $args->{reply}, $args->{from});
			}
			AI::dequeue;
		}
	}


	##### AVOID GM OR PLAYERS #####
	if (timeOut($timeout{ai_avoidcheck})) {
		avoidGM_near() if ($config{avoidGM_near} && (!$cities_lut{"$field{name}.rsw"} || $config{avoidGM_near_inTown}));
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

	my $sendMsg = $msg;
	if (length($msg) >= 4 && $conState >= 4 && length($msg) >= unpack("S1", substr($msg, 0, 2))) {
		decrypt(\$msg, $msg);
	}
	my $switch = uc(unpack("H2", substr($msg, 1, 1))) . uc(unpack("H2", substr($msg, 0, 1)));
	if ($config{'debugPacket_ro_sent'} && !existsInList($config{'debugPacket_exclude'}, $switch)) {
		my $label = $packetDescriptions{Send}{$switch} ?
			" - $packetDescriptions{Send}{$switch})" : '';
		if ($config{debugPacket_ro_sent} == 1) {
			debug "Packet SENT_BY_CLIENT: $switch$label\n", "parseSendMsg", 0;
		} else {
			visualDump($sendMsg, "$switch$label");
		}
	}

	Plugins::callHook('RO_sendMsg_pre', {switch => $switch, msg => $msg, realMsg => \$sendMsg});

	# If the player tries to manually do something in the RO client, disable AI for a small period
	# of time using ai_clientSuspend().

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
		message "Map loaded\n", "connection";

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

	} elsif ($switch eq "008C" || $switch eq "0108" || $switch eq "017E" || ($switch eq "00F3" && $config{serverType} == 3)) {
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
	}
	#elsif ($switch eq "007E") {
	#	my $a = unpack("L", substr($msg, 4, 4));
	#	my $b = int(time / 12 * 3075000) - 284089912922934;
	#	open(F, ">> DUMP.txt");
	#	print F "\n\n";
	#	print F "$a\n";
	#	print F "$b\n";
	#	print(F ($b - $a) . "\n");
	#	close F;
	#	dumpData($msg);
	#}

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
	my $switch = uc(unpack("H2", substr($msg, 1, 1))) . uc(unpack("H2", substr($msg, 0, 1)));
	if (length($msg) >= 4 && substr($msg,0,4) ne $accountID && $conState >= 4 && $lastswitch ne $switch
	 && length($msg) >= unpack("S1", substr($msg, 0, 2))) {
		decrypt(\$msg, $msg);
	}
	$switch = uc(unpack("H2", substr($msg, 1, 1))) . uc(unpack("H2", substr($msg, 0, 1)));

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

	if ($config{debugPacket_received} && !existsInList($config{'debugPacket_exclude'}, $switch)) {
		my $label = $packetDescriptions{Recv}{$switch} ?
			" ($packetDescriptions{Recv}{$switch})" : '';
		if ($config{debugPacket_received} == 1) {
			debug "Packet: $switch$label\n", "parseMsg", 0;
		} else {
			visualDump(substr($msg, 0, $msg_size), "$switch$label");
		}
	}

	Plugins::callHook('parseMsg/pre', {switch => $switch, msg => $msg, msg_size => $msg_size});

	$lastPacketTime = time;
	if ((substr($msg,0,4) eq $accountID && ($conState == 2 || $conState == 4))
	 || ($xkore && !$accountID && length($msg) == 4)) {
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
		debug "Received account ID\n", "parseMsg", 0 if ($config{debugPacket_received});

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
		# Account sex should only be 0 (female) or 1 (male)
		# inRO gives female as 2 but expects 0 back
		# do modulus of 2 here to fix?
		# FIXME: we should check exactly what operation the client does to the number given
		$accountSex = unpack("C1",substr($msg, 46, 1)) % 2;
		$accountSex2 = ($config{'sex'} ne "") ? $config{'sex'} : $accountSex;
		message(swrite(
			"---------Account Info-------------", [undef],
			"Account ID: @<<<<<<<<< @<<<<<<<<<<", [unpack("L1",$accountID), getHex($accountID)],
			"Sex:        @<<<<<<<<<<<<<<<<<<<<<", [$sex_lut{$accountSex}],
			"Session ID: @<<<<<<<<< @<<<<<<<<<<", [unpack("L1",$sessionID), getHex($sessionID)],
			"            @<<<<<<<<< @<<<<<<<<<<", [unpack("L1",$sessionID2), getHex($sessionID2)],
			"----------------------------------", [undef],
		), "connection");

		my $num = 0;
		undef @servers;
		for (my $i = 47; $i < $msg_size; $i+=32) {
			$servers[$num]{'ip'} = makeIP(substr($msg, $i, 4));
			$servers[$num]{'ip'} = $masterServer->{ip} if ($masterServer && $masterServer->{private});
			$servers[$num]{'port'} = unpack("S1", substr($msg, $i+4, 2));
			($servers[$num]{'name'}) = substr($msg, $i + 6, 20) =~ /([\s\S]*?)\000/;
			$servers[$num]{'users'} = unpack("L",substr($msg, $i + 26, 4));
			$num++;
		}

		message("--------- Servers ----------\n", "connection");
		message("#         Name            Users  IP              Port\n", "connection");
		for (my $num = 0; $num < @servers; $num++) {
			message(swrite(
				"@<< @<<<<<<<<<<<<<<<<<<<< @<<<<< @<<<<<<<<<<<<<< @<<<<<",
				[$num, $servers[$num]{'name'}, $servers[$num]{'users'}, $servers[$num]{'ip'}, $servers[$num]{'port'}]
			), "connection");
		}
		message("-------------------------------\n", "connection");

		if (!$xkore) {
			message("Closing connection to Master Server\n", "connection");
			Network::disconnect(\$remote_socket);
			if (!$masterServer->{'charServer_ip'} && $config{'server'} eq "") {
				message("Choose your server.  Enter the server number: ", "input");
				$waitingForInput = 1;
			} elsif ($masterServer->{'charServer_ip'}) {
				message("Forcing connect to char server $masterServer->{charServer_ip}:$masterServer->{charServer_port}\n", "connection");
			} else {
				message("Server $config{server} selected\n", "connection");
			}
		}

	} elsif ($switch eq "006A") {
		my $type = unpack("C1",substr($msg, 2, 1));
		Network::disconnect(\$remote_socket);
		if ($type == 0) {
			error("Account name doesn't exist\n", "connection");
			if (!$xkore && !$config{'ignoreInvalidLogin'}) {
				message("Enter Username Again: ", "input");
				$msg = $interface->getInput(-1);
				configModify('username', $msg, 1);
				$timeout_ex{'master'}{'time'} = 0;
				$conState_tries = 0;
			}
		} elsif ($type == 1) {
			error("Password Error\n", "connection");
			if (!$xkore && !$config{'ignoreInvalidLogin'}) {
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
			$quit = 1 if (!$xkore);
		} elsif ($type == 5) {
			my $master = $masterServer;
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
			writeSectionedFileIntact("$Settings::tables_folder/servers.txt", \%masterServers);
		}

	} elsif ($switch eq "006B" && $conState != 5) {
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

		my $startVal = $msg_size % 106;

		my $num;
		for (my $i = $startVal; $i < $msg_size; $i += 106) {
			#exp display bugfix - chobit andy 20030129
			$num = unpack("C1", substr($msg, $i + 104, 1));
			$chars[$num] = new Actor::You;
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

		# gradeA says it's supposed to send this packet here, but
		# it doesn't work...
		#sendBanCheck(\$remote_socket) if (!$xkore && $config{serverType} == 2);
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

	} elsif ($switch eq "006D" && $conState != 5) {
		my $char = new Actor::You;
		$char->{ID} = substr($msg, 2, 4);
		$char->{name} = unpack("Z24", substr($msg, 76, 24));
		$char->{zenny} = unpack("L", substr($msg, 10, 4));
		($char->{str}, $char->{agi}, $char->{vit}, $char->{int}, $char->{dex}, $char->{luk}) = unpack("C*", substr($msg, 100, 6));
		my $slot = unpack("C", substr($msg, 106, 1));

		$char->{lv} = 1;
		$char->{lv_job} = 1;
		$char->{sex} = $accountSex2;
		$chars[$slot] = $char;

		$conState = 3;
		message "Character $char->{name} ($slot) created.\n", "info";
		if (charSelectScreen() == 1) {
			$conState = 3;
			$firstLoginMap = 1;
			$startingZenny = $chars[$config{'char'}]{'zenny'} unless defined $startingZenny;
			$sentWelcomeMessage = 1;
		} else {
			return;
		}

	} elsif ($switch eq "006E" && $conState != 5) {
		message "Character cannot be to created. If you didn't make any mistake, then the name you chose already exists.\n", "info";
		if (charSelectScreen() == 1) {
			$conState = 3;
			$firstLoginMap = 1;
			$startingZenny = $chars[$config{'char'}]{'zenny'} unless defined $startingZenny;
			$sentWelcomeMessage = 1;
		} else {
			return;
		}

	} elsif ($switch eq "006F" && $conState != 5) {
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

	} elsif ($switch eq "0070" && $conState != 5) {
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
		my ($map_name) = substr($msg, 6, 16) =~ /([\s\S]*?)\000/;
		
		if ($xkore) {
			undef $masterServer;
			$masterServer = $masterServers{$config{master}} if ($config{master} ne "");
		}

		($ai_v{temp}{map}) = $map_name =~ /([\s\S]*)\./;
		if ($ai_v{temp}{map} ne $field{name}) {
			getField($ai_v{temp}{map}, \%field);
		}

		$map_ip = makeIP(substr($msg, 22, 4));
		$map_ip = $masterServer->{ip} if ($masterServer && $masterServer->{private});
		$map_port = unpack("S1", substr($msg, 26, 2));
		message "----------Game Info----------\n", "connection";
		message "Char ID: ".getHex($charID)." (".unpack("L1", $charID).")\n", "connection";
		message "MAP Name: $map_name\n", "connection";
		message "MAP IP: $map_ip\n", "connection";
		message "MAP Port: $map_port\n", "connection";
		message "-----------------------------\n", "connection";
		($ai_v{temp}{map}) = $map_name =~ /([\s\S]*)\./;
		checkAllowedMap($ai_v{temp}{map});
		message("Closing connection to Game Login Server\n", "connection") if (!$xkore);
		Network::disconnect(\$remote_socket) if (!$xkore);
		initStatVars();

	} elsif ($switch eq "0073") {
		$conState = 5;
		undef $conState_tries;
		$char = $chars[$config{'char'}];

		if ($xkore) {
			$conState = 4;
			message("Waiting for map to load...\n", "connection");
			ai_clientSuspend(0, 10);
			initMapChangeVars();
		} else {
			message("You are now in the game\n", "connection");
			sendMapLoaded(\$remote_socket);
			if ($config{serverType} != 0) {
				sendSync(\$remote_socket, 1);
				debug "Sent initial sync\n", "connection";
			}
			$timeout{'ai'}{'time'} = time;
		}

		$char->{pos} = {};
		makeCoords($char->{pos}, substr($msg, 6, 3));
		$char->{pos_to} = {%{$char->{pos}}};
		message("Your Coordinates: $char->{pos}{x}, $char->{pos}{y}\n", undef, 1);

		sendIgnoreAll(\$remote_socket, "all") if ($config{'ignoreAll'});

	} elsif ($switch eq "0075") {
		$conState = 5 if ($conState != 4 && $xkore);

	} elsif ($switch eq "0077") {
		$conState = 5 if ($conState != 4 && $xkore);

	} elsif ($switch eq '0227' && $config{gameGuard} && !$config{XKore}) {
		Poseidon::Client::getInstance()->query(substr($msg, 0, $msg_size));
		debug "Querying Poseidon\n", "poseidon";

	} elsif ($switch eq '0259') {
		my $gameGuard_reply = unpack("H2", substr($msg, 2, 1));
		message "Server granted logon request to " . ($gameGuard_reply eq '01' ? "account server" : "char/map server") . "\n", "poseidon";
		$conState = 1.3 if ($conState == 1.2);

	} elsif ($switch eq "0078" || $switch eq "01D8" || $switch eq "022C") {
		# 0078: long ID, word speed, word state, word ailment, word look, word
		# class, word hair, word weapon, word head_option_bottom, word shield,
		# word head_option_top, word head_option_mid, word hair_color, word ?,
		# word head_dir, long guild, long emblem, word manner, byte karma, byte
		# sex, 3byte coord, byte body_dir, byte ?, byte ?, byte sitting, word
		# level
		$conState = 5 if ($conState != 4 && $xkore);
		my ($ID, $walk_speed, $param1, $param2, $param3, $type, $pet,
			$weapon, $shield, $lowhead, $tophead, $midhead, $hair_color,
			$head_dir, $guildID, $sex, %coords, $body_dir, $act, $lv, $added);

		$ID = substr($msg, 2, 4);
		$walk_speed = unpack("S", substr($msg, 6, 2)) / 1000;
                $param1 = unpack("S1", substr($msg, 8, 2));
                $param2 = unpack("S1", substr($msg, 10, 2));
                $param3 = unpack("S1", substr($msg, 12, 2));

		if ($switch eq "022C") {
			$type = unpack("S*",substr($msg, 16,  2));
			$pet = unpack("C*",substr($msg, 18,  1));
			$weapon = unpack("S1", substr($msg, 20, 2));
			$shield = unpack("S1", substr($msg, 22, 2));
			$lowhead = unpack("S1", substr($msg, 24, 2));
			$tophead = unpack("S1", substr($msg, 30, 2));
			$midhead = unpack("S1", substr($msg, 32, 2));
			$hair_color = unpack("S1", substr($msg, 26, 2));
			$head_dir = unpack("S", substr($msg, 34, 2)) % 8;
			$guildID = unpack("L1", substr($msg, 36, 4));
			$sex = unpack("C*",substr($msg, 55, 1));
			makeCoords2(\%coords, substr($msg, 56, 3));
			$act = unpack("C*",substr($msg, 61, 1));
			$lv = unpack("S*",substr($msg, 62, 2));
		} else {
			$type = unpack("S*",substr($msg, 14,  2));
			$pet = unpack("C*",substr($msg, 16,  1));
			$weapon = unpack("S1", substr($msg, 18, 2));
			$shield = unpack("S1", substr($msg, $switch eq "01D8" ? 20 : 22, 2));
			$lowhead = unpack("S1", substr($msg, $switch eq "01D8" ? 22 : 20,  2));
			$tophead = unpack("S1", substr($msg, 24, 2));
			$midhead = unpack("S1", substr($msg, 26, 2));
			$hair_color = unpack("S1", substr($msg, 28, 2));
			$head_dir = unpack("S", substr($msg, 32, 2)) % 8;
			$guildID = unpack("L1", substr($msg, 34, 4));
			$sex = unpack("C*",substr($msg, 45,  1));
			makeCoords(\%coords, substr($msg, 46, 3));
			$body_dir = unpack("C", substr($msg, 48, 1)) % 8;
			$act = unpack("C*",substr($msg, 51,  1));
			$lv = unpack("S*",substr($msg, 52,  2));
		}

		if ($jobs_lut{$type}) {
			my $player = $players{$ID};
			if (!UNIVERSAL::isa($player, 'Actor')) {
				$player = $players{$ID} = new Actor::Player;
				binAdd(\@playersID, $ID);
				$player->{appear_time} = time;
				$player->{ID} = $ID;
				$player->{jobID} = $type;
				$player->{sex} = $sex;
				$player->{nameID} = unpack("L1", $ID);
				$player->{binID} = binFind(\@playersID, $ID);
				$added = 1;
			}

			$player->{walk_speed} = $walk_speed;
			$player->{headgear}{low} = $lowhead;
			$player->{headgear}{top} = $tophead;
			$player->{headgear}{mid} = $midhead;
			$player->{hair_color} = $hair_color;
			$player->{look}{body} = $body_dir;
			$player->{look}{head} = $head_dir;
			$player->{weapon} = $weapon;
			$player->{shield} = $shield;
			$player->{guildID} = $guildID;
			if ($act == 1) {
				$player->{dead} = 1;
			} elsif ($act == 2) {
				$player->{sitting} = 1;
			}
			$player->{lv} = $lv;
			$player->{pos} = {%coords};
			$player->{pos_to} = {%coords};
			my $domain = existsInList($config{friendlyAID}, unpack("L1", $player->{ID})) ? 'parseMsg_presence' : 'parseMsg_presence/player';
			debug "Player Exists: ".$player->name." ($player->{binID}) Level $lv $sex_lut{$player->{sex}} $jobs_lut{$player->{jobID}}\n", $domain, 1;

			objectAdded('player', $ID, $player) if ($added);

			Plugins::callHook('player', {player => $player});

			setStatus($ID,$param1,$param2,$param3);

		} elsif ($type >= 1000) {
			if ($pet || ($args->{type} >= 6000 && $pvp == 0)) {
				# Actor is a pet or actor is a Homunculus (when in non-PVP mode)
				if (!$pets{$ID} || !%{$pets{$ID}}) {
					$pets{$ID}{'appear_time'} = time;
					my $display = ($monsters_lut{$type} ne "") 
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

				if ($monsters{$ID}) {
					binRemove(\@monstersID, $ID);
					objectRemoved('monster', $ID, $monsters{$ID});
					delete $monsters{$ID};
				}

				objectAdded('pet', $ID, $pets{$ID}) if ($added);

			} else {
				if (!$monsters{$ID} || !%{$monsters{$ID}}) {
					$monsters{$ID} = new Actor::Monster;
					$monsters{$ID}{'appear_time'} = time;
					my $display = ($monsters_lut{$type} ne "") 
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

				objectAdded('monster', $ID, $monsters{$ID}) if ($added);

				# Monster state
				$param1 = 0 if $param1 == 5; # 5 has got something to do with the monster being undead
				setStatus($ID,$param1,$param2,$param3);

			}

		} elsif ($type == 45) {
			if (!$portals{$ID} || !%{$portals{$ID}}) {
				$portals{$ID}{'appear_time'} = time;
				my $nameID = unpack("L1", $ID);
				my $exists = portalExists($field{'name'}, \%coords);
				my $display = ($exists ne "")
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
			if (!$npcs{$ID} || !%{$npcs{$ID}}) {
				$npcs{$ID}{'appear_time'} = time;
				my $nameID = unpack("L1", $ID);
				my $display = ($npcs_lut{$nameID} && %{$npcs_lut{$nameID}}) 
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

			setStatus($ID, $param1, $param2, $param3);

		} else {
			debug "Unknown Exists: $type - ".unpack("L*",$ID)."\n", "parseMsg";
		}

	} elsif ($switch eq "0079" || $switch eq "01D9" || $switch eq "022B") {
		$conState = 5 if ($conState != 4 && $xkore);
		my ($ID, $walk_speed, $param1, $param2, $param3, $type, $weapon, $shield,
			$lowhead, $tophead, $midhead, $hair_color, $sex, $guildID, %coords, $lv);

		$ID = substr($msg, 2, 4);
		$walk_speed = unpack("S", substr($msg, 6, 2)) / 1000;
		$param1 = unpack("S1", substr($msg, 8, 2));
		$param2 = unpack("S1", substr($msg, 10, 2));
		$param3 = unpack("S1", substr($msg, 12, 2));
		if ($switch eq "022B") {
			$type = unpack("S1", substr($msg, 16,  2));
			$weapon = unpack("S1", substr($msg, 20, 2));
			$shield = unpack("S1", substr($msg, 22, 2));
			$lowhead = unpack("S1", substr($msg, 24, 2));
			$tophead = unpack("S1", substr($msg, 30, 2));
			$midhead = unpack("S1", substr($msg, 32, 2));
			$hair_color = unpack("S1", substr($msg, 26, 2));
			$sex = unpack("C*", substr($msg, 49, 1));
			$guildID = unpack("L1", substr($msg, 36, 4));
			makeCoords(\%coords, substr($msg, 50, 3));
			$lv = unpack("S*", substr($msg, 55, 2));
		} else {
			$type = unpack("S*", substr($msg, 14,  2));
			$weapon = unpack("S1", substr($msg, 18, 2));
			$shield = unpack("S1", substr($msg, $switch eq "01D9" ? 20 : 22, 2));
			$lowhead = unpack("S1", substr($msg, $switch eq "01D9" ? 22 : 20,  2));
			$tophead = unpack("S1", substr($msg, 24,  2));
			$midhead = unpack("S1", substr($msg, 26,  2));
			$hair_color = unpack("S1", substr($msg, 28, 2));
			$sex = unpack("C*", substr($msg, 45,  1));
			$guildID = unpack("L1", substr($msg, 34, 4));
			makeCoords(\%coords, substr($msg, 46, 3));
			$lv = unpack("S*", substr($msg, 51,  2));
		}

		if ($jobs_lut{$type}) {
			my $added;
			if (!UNIVERSAL::isa($players{$ID}, 'Actor')) {
				$players{$ID} = new Actor::Player;
				$players{$ID}{'appear_time'} = time;
				binAdd(\@playersID, $ID);
				$players{$ID}{'ID'} = $ID;
				$players{$ID}{'jobID'} = $type;
				$players{$ID}{'sex'} = $sex;
				$players{$ID}{'nameID'} = unpack("L1", $ID);
				$players{$ID}{'binID'} = binFind(\@playersID, $ID);
				$added = 1;
			}

			$players{$ID}{weapon} = $weapon;
			$players{$ID}{shield} = $shield;
			$players{$ID}{walk_speed} = $walk_speed;
			$players{$ID}{headgear}{low} = $lowhead;
			$players{$ID}{headgear}{top} = $tophead;
			$players{$ID}{headgear}{mid} = $midhead;
			$players{$ID}{hair_color} = $hair_color;
			$players{$ID}{guildID} = $guildID;
			$players{$ID}{look}{body} = 0;
			$players{$ID}{look}{head} = 0;
			$players{$ID}{lv} = $lv;
			$players{$ID}{pos} = {%coords};
			$players{$ID}{pos_to} = {%coords};
			my $domain = existsInList($config{friendlyAID}, unpack("L1", $ID)) ? 'parseMsg_presence' : 'parseMsg_presence/player';
			debug "Player Connected: ".$players{$ID}->name." ($players{$ID}{'binID'}) Level $lv $sex_lut{$players{$ID}{'sex'}} $jobs_lut{$players{$ID}{'jobID'}}\n", $domain;

			objectAdded('player', $ID, $players{$ID}) if ($added);

			setStatus($ID, $param1, $param2, $param3);

		} else {
			debug "Unknown Connected: $type - ", "parseMsg";
		}

	} elsif ($switch eq "007A") {
		$conState = 5 if ($conState != 4 && $xkore);

	} elsif ($switch eq "007B" || $switch eq "01DA") {
		$conState = 5 if ($conState != 4 && $xkore);
		my $ID = substr($msg, 2, 4);
		my $walk_speed = unpack("S", substr($msg, 6, 2)) / 1000;
		my $param1 = unpack("S1", substr($msg, 8, 2));
		my $param2 = unpack("S1", substr($msg, 10, 2));
		my $param3 = unpack("S1", substr($msg, 12, 2));
		my $type = unpack("S*",substr($msg, 14,  2));
		my $pet = unpack("C*",substr($msg, 16,  1));
		my $weapon = unpack("S1", substr($msg, 18, 2));
		my $shield = unpack("S1", substr($msg, $switch eq "01DA" ? 20 : 26, 2));
		my $lowhead = unpack("S1", substr($msg, $switch eq "01DA" ? 22 : 20,  2));
		my $tophead = unpack("S1", substr($msg, 28, 2));
		my $midhead = unpack("S1", substr($msg, 30, 2));
		my $hair_color = unpack("S1", substr($msg, 32, 2));
		my $sex = unpack("C*",substr($msg, 49,  1));
		my $guildID = unpack("L1", substr($msg, 38, 4));
		my (%coordsFrom, %coordsTo);
		makeCoords(\%coordsFrom, substr($msg, 50, 3));
		makeCoords2(\%coordsTo, substr($msg, 52, 3));
		my $lv = unpack("S*",substr($msg, 58,  2));

		my $added;
		my %vec;
		getVector(\%vec, \%coordsTo, \%coordsFrom);
		my $direction = int sprintf("%.0f", (360 - vectorToDegree(\%vec)) / 45);

		if ($jobs_lut{$type}) {
			if (!UNIVERSAL::isa($players{$ID}, 'Actor')) {
				$players{$ID} = new Actor::Player;
				binAdd(\@playersID, $ID);
				$players{$ID}{'appear_time'} = time;
				$players{$ID}{'sex'} = $sex;
				$players{$ID}{'ID'} = $ID;
				$players{$ID}{'jobID'} = $type;
				$players{$ID}{'nameID'} = unpack("L1", $ID);
				$players{$ID}{'binID'} = binFind(\@playersID, $ID);
				my $domain = existsInList($config{friendlyAID}, unpack("L1", $ID)) ? 'parseMsg_presence' : 'parseMsg_presence/player';
				debug "Player Appeared: ".$players{$ID}->name." ($players{$ID}{'binID'}) Level $lv $sex_lut{$sex} $jobs_lut{$type}\n", $domain;
				$added = 1;
				Plugins::callHook('player', {player => $players{$ID}});
			}

			$players{$ID}{weapon} = $weapon;
			$players{$ID}{shield} = $shield;
			$players{$ID}{walk_speed} = $walk_speed;
			$players{$ID}{look}{head} = 0;
			$players{$ID}{look}{body} = $direction;
			$players{$ID}{headgear}{low} = $lowhead;
			$players{$ID}{headgear}{top} = $tophead;
			$players{$ID}{headgear}{mid} = $midhead;
			$players{$ID}{hair_color} = $hair_color;
			$players{$ID}{lv} = $lv;
			$players{$ID}{guildID} = $guildID;
			$players{$ID}{pos} = {%coordsFrom};
			$players{$ID}{pos_to} = {%coordsTo};
			$players{$ID}{time_move} = time;
			$players{$ID}{time_move_calc} = distance(\%coordsFrom, \%coordsTo) * $walk_speed;
			debug "Player Moved: $players{$ID}{'name'} ($players{$ID}{'binID'}) $sex_lut{$players{$ID}{'sex'}} $jobs_lut{$players{$ID}{'jobID'}}\n", "parseMsg";

			objectAdded('player', $ID, $players{$ID}) if ($added);

                        setStatus($ID, $param1, $param2, $param3);

		} elsif ($type >= 1000) {
			if ($pet) {
				if (!$pets{$ID} || !%{$pets{$ID}}) {
					$pets{$ID}{'appear_time'} = time;
					my $display = ($monsters_lut{$type} ne "") 
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
					objectRemoved('monster', $ID, $monsters{$ID});
					delete $monsters{$ID};
				}

				debug "Pet Moved: $pets{$ID}{'name'} ($pets{$ID}{'binID'})\n", "parseMsg";

			} else {
				if (!$monsters{$ID} || !%{$monsters{$ID}}) {
					$monsters{$ID} = new Actor::Monster;
					binAdd(\@monstersID, $ID);
					$monsters{$ID}{ID} = $ID;
					$monsters{$ID}{'appear_time'} = time;
					$monsters{$ID}{'nameID'} = $type;
					my $display = ($monsters_lut{$type} ne "") 
						? $monsters_lut{$type}
						: "Unknown ".$type;
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

	                        setStatus($ID, $param1, $param2, $param3);
			}
		} else {
			debug "Unknown Moved: $type - ".getHex($ID)."\n", "parseMsg";
		}

	} elsif ($switch eq "007C" || $switch eq "022A") {
		$conState = 5 if ($conState != 4 && $xkore);
		my ($ID, $param1, $param2, $param3, $type, $pet, $sex, $added, %coords);
		if ($switch eq "007C") {
			$ID = substr($msg, 2, 4);
			$param1 = unpack("S1", substr($msg,  8, 2));
			$param2 = unpack("S1", substr($msg, 10, 2));
			$param3 = unpack("S1", substr($msg, 12, 2));
			makeCoords(\%coords, substr($msg, 36, 3));
			$type = unpack("S*",substr($msg, 20,  2));
			$pet = unpack("C*",substr($msg, 22,  1));
			$sex = unpack("C*",substr($msg, 35,  1));
		} else {
			$ID = substr($msg, 2, 4);
			$param1 = unpack("v1", substr($msg, 8, 2));
			$param2 = unpack("v1", substr($msg, 10, 2));
			$param3 = unpack("v1", substr($msg, 12, 2));
			makeCoords(\%coords, substr($msg, 50, 3));
			$type = unpack("v1", substr($msg, 16, 2));
			$pet = unpack("v1", substr($msg, 18, 2));
			$sex = unpack("C1", substr($msg, 49, 1));
		}

		if ($jobs_lut{$type}) {
			if (!UNIVERSAL::isa($players{$ID}, 'Actor')) {
				$players{$ID} = new Actor::Player;
				binAdd(\@playersID, $ID);
				$players{$ID}{'jobID'} = $type;
				$players{$ID}{'sex'} = $sex;
				$players{$ID}{'ID'} = $ID;
				$players{$ID}{'nameID'} = unpack("L1", $ID);
				$players{$ID}{'appear_time'} = time;
				$players{$ID}{'binID'} = binFind(\@playersID, $ID);
				$added = 1;
			}
			$players{$ID}{look}{head} = 0;
			$players{$ID}{look}{body} = 0;
			$players{$ID}{pos} = {%coords};
			$players{$ID}{pos_to} = {%coords};
			debug "Player Spawned: ".$players{$ID}->name." ($players{$ID}{'binID'}) $sex_lut{$players{$ID}{'sex'}} $jobs_lut{$players{$ID}{'jobID'}}\n", "parseMsg";

			objectAdded('player', $ID, $players{$ID}) if ($added);

			setStatus($ID, $param1, $param2, $param3);

		} elsif ($type >= 1000) {
			if ($pet) {
				if (!$pets{$ID} || !%{$pets{$ID}}) { 
					binAdd(\@petsID, $ID); 
					$pets{$ID}{'nameID'} = $type; 
					$pets{$ID}{'appear_time'} = time; 
					my $display = ($monsters_lut{$pets{$ID}{'nameID'}} ne "") 
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

				if ($monsters{$ID}) {
					binRemove(\@monstersID, $ID);
					objectRemoved('monster', $ID, $monsters{$ID});
					delete $monsters{$ID};
				}

			} else {
				if (!$monsters{$ID} || !%{$monsters{$ID}}) {
					$monsters{$ID} = new Actor::Monster;
					binAdd(\@monstersID, $ID);
					$monsters{$ID}{ID} = $ID;
					$monsters{$ID}{'nameID'} = $type;
					$monsters{$ID}{'appear_time'} = time;
					my $display = ($monsters_lut{$monsters{$ID}{'nameID'}} ne "") 
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

				setStatus($ID, $param1, $param2, $param3);
			}

		} else {
			debug "Unknown Spawned: $type - ".getHex($ID)."\n", "parseMsg_presence";
		}
		
	} elsif ($switch eq "007F") {
		$conState = 5 if ($conState != 4 && $xkore);
		my $time = unpack("L1",substr($msg, 2, 4));
		debug "Received Sync\n", "parseMsg", 2;
		$timeout{'play'}{'time'} = time;

	} elsif ($switch eq "0080") {
		$conState = 5 if ($conState != 4 && $xkore);
		my $ID = substr($msg, 2, 4);
		my $type = unpack("C1",substr($msg, 6, 1));

		if ($ID eq $accountID) {
			message "You have died\n";
			closeShop() unless !$shopstarted || $config{'dcOnDeath'} == -1 || !$AI;
			$char->{deathCount}++;
			$char->{dead} = 1;
			$char->{dead_time} = time;

		} elsif ($monsters{$ID} && %{$monsters{$ID}}) {
			%{$monsters_old{$ID}} = %{$monsters{$ID}};
			$monsters_old{$ID}{'gone_time'} = time;
			if ($type == 0) {
				debug "Monster Disappeared: $monsters{$ID}{'name'} ($monsters{$ID}{'binID'})\n", "parseMsg_presence";
				$monsters_old{$ID}{'disappeared'} = 1;

			} elsif ($type == 1) {
				debug "Monster Died: $monsters{$ID}{'name'} ($monsters{$ID}{'binID'})\n", "parseMsg_damage";
				$monsters_old{$ID}{'dead'} = 1;

				if ($config{itemsTakeAuto_party} &&
				    ($monsters{$ID}{dmgFromParty} > 0 ||
				     $monsters{$ID}{dmgFromYou} > 0)) {
					AI::clear("items_take");
					ai_items_take($monsters{$ID}{pos}{x}, $monsters{$ID}{pos}{y},
						$monsters{$ID}{pos_to}{x}, $monsters{$ID}{pos_to}{y});
				}

			} elsif ($type == 2) { # What's this?
				debug "Monster Disappeared: $monsters{$ID}{'name'} ($monsters{$ID}{'binID'})\n", "parseMsg_presence";
				$monsters_old{$ID}{'disappeared'} = 1;

			} elsif ($type == 3) {
				debug "Monster Teleported: $monsters{$ID}{'name'} ($monsters{$ID}{'binID'})\n", "parseMsg_presence";
				$monsters_old{$ID}{'teleported'} = 1;
			}
			binRemove(\@monstersID, $ID);
			objectRemoved('monster', $ID, $monsters{$ID});
			delete $monsters{$ID};

		} elsif (UNIVERSAL::isa($players{$ID}, 'Actor')) {
			if ($type == 1) {
				message "Player Died: ".$players{$ID}->name." ($players{$ID}{'binID'}) $sex_lut{$players{$ID}{'sex'}} $jobs_lut{$players{$ID}{'jobID'}}\n";
				$players{$ID}{'dead'} = 1;
			} else {
				if ($type == 0) {
					debug "Player Disappeared: ".$players{$ID}->name." ($players{$ID}{'binID'}) $sex_lut{$players{$ID}{'sex'}} $jobs_lut{$players{$ID}{'jobID'}}\n", "parseMsg_presence";
					$players{$ID}{'disappeared'} = 1;
				} elsif ($type == 2) {
					debug "Player Disconnected: ".$players{$ID}->name." ($players{$ID}{'binID'}) $sex_lut{$players{$ID}{'sex'}} $jobs_lut{$players{$ID}{'jobID'}}\n", "parseMsg_presence";
					$players{$ID}{'disconnected'} = 1;
				} elsif ($type == 3) {
					debug "Player Teleported: ".$players{$ID}->name." ($players{$ID}{'binID'}) $sex_lut{$players{$ID}{'sex'}} $jobs_lut{$players{$ID}{'jobID'}}\n", "parseMsg_presence";
					$players{$ID}{'teleported'} = 1;
				} else {
					debug "Player Disappeared in an unknown way: ".$players{$ID}->name." ($players{$ID}{'binID'}) $sex_lut{$players{$ID}{'sex'}} $jobs_lut{$players{$ID}{'jobID'}}\n", "parseMsg_presence";
					$players{$ID}{'disappeared'} = 1;
				}

				%{$players_old{$ID}} = %{$players{$ID}};
				$players_old{$ID}{'gone_time'} = time;
				binRemove(\@playersID, $ID);
				objectRemoved('player', $ID, $players{$ID});
				delete $players{$ID};

				binRemove(\@venderListsID, $ID);
				delete $venderLists{$ID};
			}

		} elsif ($players_old{$ID} && %{$players_old{$ID}}) {
			if ($type == 2) {
				debug "Player Disconnected: $players_old{$ID}{'name'}\n", "parseMsg_presence";
				$players_old{$ID}{'disconnected'} = 1;
			} elsif ($type == 3) {
				debug "Player Teleported: $players_old{$ID}{'name'}\n", "parseMsg_presence";
				$players_old{$ID}{'teleported'} = 1;
			}

		} elsif ($portals{$ID} && %{$portals{$ID}}) {
			debug "Portal Disappeared: $portals{$ID}{'name'} ($portals{$ID}{'binID'})\n", "parseMsg";
			$portals_old{$ID} = {%{$portals{$ID}}};
			$portals_old{$ID}{'disappeared'} = 1;
			$portals_old{$ID}{'gone_time'} = time;
			binRemove(\@portalsID, $ID);
			delete $portals{$ID};

		} elsif ($npcs{$ID} && %{$npcs{$ID}}) {
			debug "NPC Disappeared: $npcs{$ID}{'name'} ($npcs{$ID}{'binID'})\n", "parseMsg";
			%{$npcs_old{$ID}} = %{$npcs{$ID}};
			$npcs_old{$ID}{'disappeared'} = 1;
			$npcs_old{$ID}{'gone_time'} = time;
			binRemove(\@npcsID, $ID);
			objectRemoved('npc', $ID, $npcs{$ID});
			delete $npcs{$ID};

		} elsif ($pets{$ID} && %{$pets{$ID}}) {
			debug "Pet Disappeared: $pets{$ID}{'name'} ($pets{$ID}{'binID'})\n", "parseMsg";
			binRemove(\@petsID, $ID);
			delete $pets{$ID};
		} else {
			debug "Unknown Disappeared: ".getHex($ID)."\n", "parseMsg";
		}

	} elsif ($switch eq "0081") {
		my $type = unpack("C1", substr($msg, 2, 1));

		if ($conState == 5 &&
		    ($config{dcOnDisconnect} > 1 ||
			 ($config{dcOnDisconnect} && $type != 3))) {
			message "Lost connection; exiting\n";
			$quit = 1;
		}

		$conState = 1;
		undef $conState_tries;

		$timeout_ex{'master'}{'time'} = time;
		$timeout_ex{'master'}{'timeout'} = $timeout{'reconnect'}{'timeout'};
		Network::disconnect(\$remote_socket);

		if ($type == 0) {
			error("Server shutting down\n", "connection");
		} elsif ($type == 1) {
			error("Error: Server is closed\n", "connection");
		} elsif ($type == 2) {
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
			$quit = 1 if (!$xkore);
		} elsif ($type == 8) {
			error("Error: The server still recognizes your last connection\n", "connection");
		} elsif ($type == 10) {
			error("Error: You are out of available time paid for\n", "connection");
		} elsif ($type == 15) {
			error("Error: You have been forced to disconnect by a GM\n", "connection");
		} else {
			error("Unknown error $type\n", "connection");
		}

	} elsif ($switch eq "0087") {
		$conState = 5 if ($conState != 4 && $xkore);
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
			AI::clear("move");
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
			my $source = Actor::get($ID1);
			my $verb = $source->verb('pick up', 'picks up');
			#my $target = Actor::get($ID2);
			my $target = getActorName($ID2);
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
			my $totalDamage = $damage + $param3;
			if ($totalDamage == 0) {
				$dmgdisplay = "Miss!";
				$dmgdisplay .= "!" if ($type == 11);
			} else {
				$dmgdisplay = $damage;
				$dmgdisplay .= "!" if ($type == 10);
				$dmgdisplay .= " + $param3" if $param3;
			}

			updateDamageTables($ID1, $ID2, $damage);
			my $source = Actor::get($ID1);
			my $target = Actor::get($ID2);
			my $verb = $source->verb('attack', 'attacks');

			$target->{sitting} = 0 unless $type == 4 || $type == 9 || $totalDamage == 0;

			Plugins::callHook('packet_attack', {sourceID => $ID1, targetID => $ID2, msg => \$msg, dmg => $totalDamage});

			my $msg = "$source $verb $target - Dmg: $dmgdisplay (delay ".($src_speed/10).")";

			my $status = sprintf("[%3d/%3d]", percent_hp($char), percent_sp($char));

			if ($ID1 eq $accountID) {
				message("$status $msg\n", $totalDamage > 0 ? "attackMon" : "attackMonMiss");
				if ($startedattack) {
					$monstarttime = time();
					$monkilltime = time();
					$startedattack = 0;
				}
				calcStat($damage);
			} elsif ($ID2 eq $accountID) {
				# Check for monster with empty name
				if ($monsters{$ID1} && %{$monsters{$ID1}} && $monsters{$ID1}{'name'} eq "") {
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

		my $dist = "unknown";
		if ($players{$ID}) {
			$dist = distance($char->{pos_to}, $players{$ID}{pos_to});
			$dist = sprintf("%.1f", $dist) if ($dist =~ /\./);
		}

		$chat = "$chatMsgUser ($players{$ID}{binID}): $chatMsg";
		chatLog("c", "[$field{name} $char->{pos_to}{x}, $char->{pos_to}{y}] [$players{$ID}{pos_to}{x}, $players{$ID}{pos_to}{y}] [dist=$dist] " .
			"$chat\n") if ($config{logChat});
		message "[dist=$dist] $chat\n", "publicchat";

		ChatQueue::add('c', $ID, $chatMsgUser, $chatMsg);
		Plugins::callHook('packet_pubMsg', {
			pubID => $ID,
			pubMsgUser => $chatMsgUser,
			pubMsg => $chatMsg,
			MsgUser => $chatMsgUser,
			Msg => $chatMsg
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

		Plugins::callHook('packet_selfChat', { 
			user => $chatMsgUser, 
			msg => $chatMsg 
		}); 


	} elsif ($switch eq "0091") {
		$conState = 4 if ($conState != 4 && $xkore);

		my ($map_name) = substr($msg, 2, 16) =~ /([\s\S]*?)\000/;
		($ai_v{temp}{map}) = $map_name =~ /([\s\S]*)\./;
		checkAllowedMap($ai_v{temp}{map});
		if ($ai_v{temp}{map} ne $field{name}) {
			getField($ai_v{temp}{map}, \%field);
		}

		initMapChangeVars();
		for (my $i = 0; $i < @ai_seq; $i++) {
			ai_setMapChanged($i);
		}
		$ai_v{'portalTrace_mapChanged'} = 1;

		my %coords;
		$coords{'x'} = unpack("S1", substr($msg, 18, 2));
		$coords{'y'} = unpack("S1", substr($msg, 20, 2));
		$chars[$config{char}]{pos} = {%coords};
		$chars[$config{char}]{pos_to} = {%coords};
		message "Map Change: $map_name ($chars[$config{'char'}]{'pos'}{'x'}, $chars[$config{'char'}]{'pos'}{'y'})\n", "connection";
		if ($xkore) {
			ai_clientSuspend(0, 10);
		} else {
			sendMapLoaded(\$remote_socket);
			$timeout{'ai'}{'time'} = time;
		}

	} elsif ($switch eq "0092") {
		$conState = 4;

		my ($map_name) = substr($msg, 2, 16) =~ /([\s\S]*?)\000/;
		($ai_v{temp}{map}) = $map_name =~ /([\s\S]*)\./;
		checkAllowedMap($ai_v{temp}{map});
		if ($ai_v{temp}{map} ne $field{name}) {
			getField($ai_v{temp}{map}, \%field);
		}

		undef $conState_tries;
		for (my $i = 0; $i < @ai_seq; $i++) {
			ai_setMapChanged($i);
		}
		$ai_v{'portalTrace_mapChanged'} = 1;

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
		Network::disconnect(\$remote_socket) if (!$xkore);

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
		undef $char->{permitSkill};
		undef $char->{encoreSkill};

	} elsif ($switch eq "0095") {
		$conState = 5 if ($conState != 4 && $xkore);
		my $ID = substr($msg, 2, 4);
		if ($players{$ID} && %{$players{$ID}}) {
			($players{$ID}{'name'}) = substr($msg, 6, 24) =~ /([\s\S]*?)\000/;
			$players{$ID}{'gotName'} = 1;
			my $binID = binFind(\@playersID, $ID);
			debug "Player Info: $players{$ID}{'name'} ($binID)\n", "parseMsg_presence", 2;
		}
		if ($monsters{$ID} && %{$monsters{$ID}}) {
			my ($name) = substr($msg, 6, 24) =~ /([\s\S]*?)\000/;
			if ($config{'debug'} >= 2) {
				my $binID = binFind(\@monstersID, $ID);
				debug "Monster Info: $name ($binID)\n", "parseMsg", 2;
			}
			if ($monsters_lut{$monsters{$ID}{'nameID'}} eq "") {
				$monsters{$ID}{'name'} = $name;
				$monsters_lut{$monsters{$ID}{'nameID'}} = $monsters{$ID}{'name'};
				updateMonsterLUT("$Settings::tables_folder/monsters.txt", $monsters{$ID}{'nameID'}, $monsters{$ID}{'name'});
			}
		}
		if ($npcs{$ID} && %{$npcs{$ID}}) {
			($npcs{$ID}{'name'}) = substr($msg, 6, 24) =~ /([\s\S]*?)\000/; 
			$npcs{$ID}{'gotName'} = 1;
			if ($config{'debug'} >= 2) { 
				my $binID = binFind(\@npcsID, $ID); 
				debug "NPC Info: $npcs{$ID}{'name'} ($binID)\n", "parseMsg", 2;
			} 
			if (!$npcs_lut{$npcs{$ID}{'nameID'}} || !%{$npcs_lut{$npcs{$ID}{'nameID'}}}) { 
				$npcs_lut{$npcs{$ID}{'nameID'}}{'name'} = $npcs{$ID}{'name'};
				$npcs_lut{$npcs{$ID}{'nameID'}}{'map'} = $field{'name'};
				%{$npcs_lut{$npcs{$ID}{'nameID'}}{'pos'}} = %{$npcs{$ID}{'pos'}};
				updateNPCLUT("$Settings::tables_folder/npcs.txt", $npcs{$ID}{'nameID'}, $field{'name'}, $npcs{$ID}{'pos'}{'x'}, $npcs{$ID}{'pos'}{'y'}, $npcs{$ID}{'name'}); 
			}
		}
		if ($pets{$ID} && %{$pets{$ID}}) {
			($pets{$ID}{'name_given'}) = substr($msg, 6, 24) =~ /([\s\S]*?)\000/;
			if ($config{'debug'} >= 2) {
				my $binID = binFind(\@petsID, $ID);
				debug "Pet Info: $pets{$ID}{'name_given'} ($binID)\n", "parseMsg", 2;
			}
		}

	} elsif ($switch eq "0097") {
		# Private message
		$conState = 5 if ($conState != 4 && $xkore);
		my $newmsg;
		decrypt(\$newmsg, substr($msg, 28, length($msg)-28));
		my $msg = substr($msg, 0, 28) . $newmsg;
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
			privMsg => $privMsg,
			MsgUser => $privMsgUser,
			Msg => $privMsg
		});

		if ($config{dcOnPM} && $AI) {
			chatLog("k", "*** You were PM'd, auto disconnect! ***\n");
			message "Disconnecting on PM!\n";
			quit();
		}

	} elsif ($switch eq "0098") {
		my $type = unpack("C1",substr($msg, 2, 1));
		if ($type == 0) {
			message "(To $lastpm[0]{'user'}) : $lastpm[0]{'msg'}\n", "pm/sent";
			chatLog("pm", "(To: $lastpm[0]{'user'}) : $lastpm[0]{'msg'}\n") if ($config{'logPrivateChat'});

			Plugins::callHook('packet_sentPM', {
				to => $lastpm[0]{user},
				msg => $lastpm[0]{msg}
			});

		} elsif ($type == 1) {
			warning "$lastpm[0]{'user'} is not online\n";
		} elsif ($type == 2) {
			warning "Player ignored your message\n";
		} else {
			warning "Player doesn't want to receive messages\n";
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
		$conState = 5 if ($conState != 4 && $xkore);
		my $ID = substr($msg, 2, 4);
		my $body = unpack("C1",substr($msg, 8, 1));
		my $head = unpack("C1",substr($msg, 6, 1));
		if ($ID eq $accountID) {
			$chars[$config{'char'}]{'look'}{'head'} = $head;
			$chars[$config{'char'}]{'look'}{'body'} = $body;
			debug "You look at $body, $head\n", "parseMsg", 2;

		} elsif ($players{$ID} && %{$players{$ID}}) {
			$players{$ID}{'look'}{'head'} = $head;
			$players{$ID}{'look'}{'body'} = $body;
			debug "Player $players{$ID}{'name'} ($players{$ID}{'binID'}) looks at $players{$ID}{'look'}{'body'}, $players{$ID}{'look'}{'head'}\n", "parseMsg";

		} elsif ($monsters{$ID} && %{$monsters{$ID}}) {
			$monsters{$ID}{'look'}{'head'} = $head;
			$monsters{$ID}{'look'}{'body'} = $body;
			debug "Monster $monsters{$ID}{'name'} ($monsters{$ID}{'binID'}) looks at $monsters{$ID}{'look'}{'body'}, $monsters{$ID}{'look'}{'head'}\n", "parseMsg";
		}

	} elsif ($switch eq "009D") {
		$conState = 5 if ($conState != 4 && $xkore);
		my $ID = substr($msg, 2, 4);
		my $type = unpack("S1",substr($msg, 6, 2));
		my $x = unpack("S1", substr($msg, 9, 2));
		my $y = unpack("S1", substr($msg, 11, 2));
		my $amount = unpack("S1", substr($msg, 13, 2));
		if (!$items{$ID} || !%{$items{$ID}}) {
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
		$conState = 5 if ($conState != 4 && $xkore);
		my $ID = substr($msg, 2, 4);
		my $type = unpack("S1",substr($msg, 6, 2));
		my $x = unpack("S1", substr($msg, 9, 2));
		my $y = unpack("S1", substr($msg, 11, 2));
		my $amount = unpack("S1", substr($msg, 15, 2));
		my $item = $items{$ID} ||= {};
		if (!$item || !%{$item}) {
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
		$conState = 5 if ($conState != 4 && $xkore);

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
				$item->{broken} = unpack("C1", substr($msg, 9, 1));
				$item->{upgrade} = unpack("C1", substr($msg, 10, 1));
				$item->{cards} = substr($msg, 11, 8);
				$item->{name} = itemName($item);
			} else {
				# Add stackable item
				$item = $chars[$config{'char'}]{'inventory'}[$invIndex];
				$item->{amount} += $amount;
			}
			$item->{invIndex} = $invIndex;

			$itemChange{$item->{name}} += $amount;
			my $disp = "Item added to inventory: ";
			$disp .= $item->{name};
			$disp .= " ($invIndex) x $amount - $itemTypes_lut{$item->{type}}";
			message "$disp\n", "drop";

			$disp .= " ($field{name})\n";
			itemLog($disp);

			Plugins::callHook('packet_item_added',{item => $item});

			# TODO: move this stuff to AI()
			if ($ai_v{npc_talk}{itemID} eq $item->{nameID}) {
				$ai_v{'npc_talk'}{'talk'} = 'buy';
				$ai_v{'npc_talk'}{'time'} = time;
			}

			if ($AI) {
				# Auto-drop item
				$item = $char->{inventory}[$invIndex];
				if ($itemsPickup{lc($item->{name})} == -1 && !AI::inQueue('storageAuto', 'buyAuto')) {
					sendDrop(\$remote_socket, $item->{index}, $amount);
					message "Auto-dropping item: $item->{name} ($invIndex) x $amount\n", "drop";
				}
			}

		} elsif ($fail == 6) {
			message "Can't loot item...wait...\n", "drop";
		} elsif ($fail == 2) {
			message "Cannot pickup item (inventory full)\n", "drop";
		} else {
			message "Cannot pickup item (failure code $fail)\n", "drop";
		}

	} elsif ($switch eq "00A1") {
		$conState = 5 if ($conState != 4 && $xkore);
		my $ID = substr($msg, 2, 4);
		if ($items{$ID} && %{$items{$ID}}) {
			debug "Item Disappeared: $items{$ID}{'name'} ($items{$ID}{'binID'})\n", "parseMsg_presence";
			%{$items_old{$ID}} = %{$items{$ID}};
			$items_old{$ID}{'disappeared'} = 1;
			$items_old{$ID}{'gone_time'} = time;
			delete $items{$ID};
			binRemove(\@itemsID, $ID);
		}

	} elsif ($switch eq "00A3" || $switch eq "01EE") {
		$conState = 5 if ($conState != 4 && $xkore);
		my $newmsg;
		decrypt(\$newmsg, substr($msg, 4, length($msg)-4));
		my $msg = substr($msg, 0, 4).$newmsg;
		my $psize = ($switch eq "00A3") ? 10 : 18;

		for (my $i = 4; $i < $msg_size; $i += $psize) {
			my $index = unpack("S1", substr($msg, $i, 2));
			my $ID = unpack("S1", substr($msg, $i + 2, 2));
			my $invIndex = findIndex(\@{$chars[$config{'char'}]{'inventory'}}, "index", $index);
			if ($invIndex eq "") {
				$invIndex = findIndex(\@{$chars[$config{'char'}]{'inventory'}}, "nameID", "");
			}

			$char->{inventory}[$invIndex]{invIndex} = $invIndex;
			$char->{inventory}[$invIndex]{index} = $index;
			$char->{inventory}[$invIndex]{nameID} = $ID;
			$char->{inventory}[$invIndex]{amount} = unpack("S1", substr($msg, $i + 6, 2));
			$char->{inventory}[$invIndex]{type} = unpack("C1", substr($msg, $i + 4, 1));
			$char->{inventory}[$invIndex]{identified} = 1;
			$char->{inventory}[$invIndex]{equipped} = 32768 if (defined $char->{arrow} && $index == $char->{arrow});

			my $display = ($items_lut{$char->{inventory}[$invIndex]{nameID}} ne "")
				? $items_lut{$char->{inventory}[$invIndex]{nameID}}
				: "Unknown ".$char->{inventory}[$invIndex]{nameID};
			$char->{inventory}[$invIndex]{name} = $display;
			debug "Inventory: $char->{inventory}[$invIndex]{name} ($invIndex) x $char->{inventory}[$invIndex]{amount} - " .
				"$itemTypes_lut{$char->{inventory}[$invIndex]{type}}\n", "parseMsg";
			Plugins::callHook('packet_inventory', {index => $invIndex, item => $char->{inventory}[$invIndex]});
		}

		$ai_v{'inventory_time'} = time + 1;
		$ai_v{'cart_time'} = time + 1;

	} elsif ($switch eq "00A4") {
		$conState = 5 if $conState != 4 && $xkore;
		my $newmsg;
		decrypt(\$newmsg, substr($msg, 4, length($msg)-4));
		my $msg = substr($msg, 0, 4) . $newmsg;
		my $invIndex;
		for (my $i = 4; $i < $msg_size; $i += 20) {
			my $index = unpack("S1", substr($msg, $i, 2));
			my $ID = unpack("S1", substr($msg, $i + 2, 2));
			$invIndex = findIndex(\@{$chars[$config{char}]{inventory}}, "index", $index);
			$invIndex = findIndex(\@{$chars[$config{char}]{inventory}}, "nameID", "") unless defined $invIndex;

			my $item = $chars[$config{char}]{inventory}[$invIndex] = {};
			$item->{index} = $index;
			$item->{invIndex} = $invIndex;
			$item->{nameID} = $ID;
			$item->{amount} = 1;
			$item->{type} = unpack("C1", substr($msg, $i + 4, 1));
			$item->{identified} = unpack("C1", substr($msg, $i + 5, 1));
			$item->{type_equip} = unpack("S1", substr($msg, $i + 6, 2));
			$item->{equipped} = unpack("S1", substr($msg, $i + 8, 2));
			$item->{broken} = unpack("C1", substr($msg, $i + 10, 1));
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
		my $msg = substr($msg, 0, 4).$newmsg;
		undef %storage;
		undef @storageID;

		my $psize = ($switch eq "00A5") ? 10 : 18;
		for (my $i = 4; $i < $msg_size; $i += $psize) {
			my $index = unpack("S1", substr($msg, $i, 2));
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
		my $msg = substr($msg, 0, 4).$newmsg;

		for (my $i = 4; $i < $msg_size; $i += 20) {
			my $index = unpack("S1", substr($msg, $i, 2));
			my $ID = unpack("S1", substr($msg, $i + 2, 2));

			binAdd(\@storageID, $index);
			my $item = $storage{$index} = {};
			$item->{index} = $index;
			$item->{nameID} = $ID;
			$item->{amount} = 1;
			$item->{type} = unpack("C1", substr($msg, $i + 4, 1));
			$item->{identified} = unpack("C1", substr($msg, $i + 5, 1));
			$item->{broken} = unpack("C1", substr($msg, $i + 10, 1));
			$item->{upgrade} = unpack("C1", substr($msg, $i + 11, 1));
			$item->{cards} = substr($msg, $i + 12, 8);
			$item->{name} = itemName($item);
			$item->{binID} = binFind(\@storageID, $index);
			debug "Storage: $item->{name} ($item->{binID})\n", "parseMsg";
		}

	} elsif ($switch eq "00A8") {
		$conState = 5 if ($conState != 4 && $xkore);
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
		$conState = 5 if ($conState != 4 && $xkore);
		my $index = unpack("S1",substr($msg, 2, 2));
		my $type = unpack("S1",substr($msg, 4, 2));
		my $invIndex = findIndex($char->{inventory}, "index", $index);
		$char->{inventory}[$invIndex]{equipped} = "";
		message "You unequip $char->{inventory}[$invIndex]{name} ($invIndex) - $equipTypes_lut{$char->{inventory}[$invIndex]{type_equip}}\n", 'inventory';

	} elsif ($switch eq "00AF") {
		$conState = 5 if ($conState != 4 && $xkore);
		my ($index, $amount) = unpack("x2 S1 S1", $msg);
		my $invIndex = findIndex(\@{$char->{inventory}}, "index", $index);
		inventoryItemRemoved($invIndex, $amount);
		Plugins::callHook('packet_item_removed', {index => $invIndex});

	} elsif ($switch eq "00B0") {
		$conState = 5 if ($conState != 4 && $xkore);
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
			# Reset $skillChanged back to 0 to tell kore that a skill can be auto-raised again
			if ($skillChanged == 2) {
				$skillChanged = 0;
			}
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
		$conState = 5 if ($conState != 4 && $xkore);
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
				if ($config{'dcOnZeny'} && $val <= $config{'dcOnZeny'}) {
					$interface->errorDialog("Disconnecting due to zeny lower than $config{'dcOnZeny'}.");
					$quit = 1;
				}
			}
			$char->{zenny} = $val;
			debug "Zenny: $val\n", "parseMsg";
		} elsif ($type == 22) {
			$chars[$config{'char'}]{'exp_max_last'} = $chars[$config{'char'}]{'exp_max'};
			$chars[$config{'char'}]{'exp_max'} = $val;
			debug "Required Exp: $val\n", "parseMsg";
			if (!$xkore && $initSync && $config{serverType} == 2) {
				sendSync(\$remote_socket, 1);
				$initSync = 0;
			}
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
		my $newmsg;
		decrypt(\$newmsg, substr($msg, 8, length($msg)-8));
		my $msg = substr($msg, 0, 8).$newmsg;
		my $ID = substr($msg, 4, 4);
		my ($talk) = substr($msg, 8, $msg_size - 8) =~ /([\s\S]*?)\000/;
		$talk{'ID'} = $ID;
		$talk{'nameID'} = unpack("L1", $ID);
		$talk{'msg'} = $talk;
		# Remove RO color codes
		$talk{'msg'} =~ s/\^[a-fA-F0-9]{6}//g;

		# Resolve the source name
		my $name;
		if ($npcs{$ID}) {
			$name = $npcs{$ID}{name};
		} elsif ($monsters{$ID}) {
			$name = $monsters{$ID}{name};
		} else {
			$name = "Unknown #$talk{nameID}";
		}

		message "$name: $talk{'msg'}\n", "npc";

	} elsif ($switch eq "00B5") {
		# 00b5: long ID
		# "Next" button appeared on the NPC message dialog
		my $ID = substr($msg, 2, 4);

		# Resolve the source name
		my $name;
		if ($npcs{$ID}) {
			$name = $npcs{$ID}{name};
		} elsif ($monsters{$ID}) {
			$name = $monsters{$ID}{name};
		} else {
			$name = "Unknown #".unpack("L1", $ID);
		}

		if ($config{autoTalkCont}) {
			message "$name: Auto-continuing talking\n", "npc";
			sendTalkContinue(\$remote_socket, $ID);
		} else {
			message "$name: Type 'talk cont' to continue talking\n", "npc";
		}
		$ai_v{'npc_talk'}{'talk'} = 'next';
		$ai_v{'npc_talk'}{'time'} = time;

	} elsif ($switch eq "00B6") {
		# 00b6: long ID
		# "Close" icon appreared on the NPC message dialog
		my $ID = substr($msg, 2, 4);
		undef %talk;

		# Resolve the source name
		my $name;
		if ($npcs{$ID}) {
			$name = $npcs{$ID}{name};
		} elsif ($monsters{$ID}) {
			$name = $monsters{$ID}{name};
		} else {
			$name = "Unknown #".unpack("L1", $ID);
		}

		message "$name: Done talking\n", "npc";
		$ai_v{'npc_talk'}{'talk'} = 'close';
		$ai_v{'npc_talk'}{'time'} = time;
		sendTalkCancel(\$remote_socket, $ID);

		Plugins::callHook('npc_talk_done', {ID => $ID});

	} elsif ($switch eq "00B7") {
		# 00b7: word len, long ID, string str
		# A list of selections appeared on the NPC message dialog.
		# Each item is divided with ':'
		my $newmsg;
		decrypt(\$newmsg, substr($msg, 8, length($msg)-8));
		my $msg = substr($msg, 0, 8).$newmsg;
		my $ID = substr($msg, 4, 4);
		$talk{'ID'} = $ID;
		my ($talk) = substr($msg, 8, $msg_size - 8) =~ /([\s\S]*?)\000/;
		$talk = substr($msg, 8) if (!defined $talk);
		my @preTalkResponses = split /:/, $talk;
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

		# Resolve the source name
		my $name;
		if ($npcs{$ID}) {
			$name = $npcs{$ID}{name};
		} elsif ($monsters{$ID}) {
			$name = $monsters{$ID}{name};
		} else {
			$name = "Unknown #".unpack("L1", $ID);
		}

		message("$name: Type 'talk resp #' to choose a response.\n", "npc");

	} elsif ($switch eq "00BC") {
		my $type = unpack("S1",substr($msg, 2, 2));
		my $val = unpack("C1",substr($msg, 5, 1));
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
		$chars[$config{'char'}]{'attack_magic_min'} = unpack("S1", substr($msg, 22, 2));
		$chars[$config{'char'}]{'attack_magic_max'} = unpack("S1", substr($msg, 20, 2));
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
		my $type = unpack("S1",substr($msg, 2, 2));
		my $val = unpack("C1",substr($msg, 4, 1));
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
		my $ID = substr($msg, 2, 4);
		my $type = unpack("C*", substr($msg, 6, 1));
		my $emotion = $emotions_lut{$type} || "<emotion #$type>";
		if ($ID eq $accountID) {
			message "$chars[$config{'char'}]{'name'} : $emotion\n", "emotion";
			chatLog("e", "$chars[$config{'char'}]{'name'} : $emotion\n") if (existsInList($config{'logEmoticons'}, $type) || $config{'logEmoticons'} eq "all");
		} elsif ($players{$ID} && %{$players{$ID}}) {
			my $name = $players{$ID}{name} || "Unknown #".unpack("L", $ID);

			my $dist = "unknown";
			if ($players{$ID}) {
				$dist = distance($char->{pos_to}, $players{$ID}{pos_to});
				$dist = sprintf("%.1f", $dist) if ($dist =~ /\./);
			}

			message "[dist=$dist] $name ($players{$ID}{binID}): $emotion\n", "emotion";
			chatLog("e", "$name".": $emotion\n") if (existsInList($config{'logEmoticons'}, $type) || $config{'logEmoticons'} eq "all");

			my $index = binFind(\@ai_seq, "follow");
			if ($index ne "") {
				my $masterID = $ai_seq_args[$index]{'ID'};
				if ($config{'followEmotion'} && $masterID eq $ID &&
			 	       distance($chars[$config{'char'}]{'pos_to'}, $players{$masterID}{'pos_to'}) <= $config{'followEmotion_distance'})
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
		$conState = 5 if ($conState != 4 && $xkore);
		my $ID = substr($msg, 2, 4);
		my $part = unpack("C1", substr($msg, 6, 1));
		my $number = unpack("C1", substr($msg, 7, 1));

		if ($part == 0) {
			# Job change
			my $msg;
			if ($ID eq $accountID) {
				$char->{jobID} = $number;
				message "You changed job to: $jobs_lut{$number}\n", "parseMsg/job";
			} elsif ($players{$ID}) {
				$players{$ID}{jobID} = $number;
				message "Player $players{$ID}{name} ($players{$ID}{binID}) changed job to: $jobs_lut{$number}\n", "parseMsg/job", 2;
			} else {
				debug "Unknown #" . unpack("L", $ID) . " changed job to: $jobs_lut{$number}\n", "parseMsg/job", 2;
			}

		} elsif ($part == 3) {
			# Bottom headgear change
			message getActorName($ID)." changed bottom headgear to: ".headgearName($number)."\n", "parseMsg_statuslook", 2 unless $ID eq $accountID;
			$players{$ID}{headgear}{low} = $number if $players{$ID};

		} elsif ($part == 4) {
			# Top headgear change
			message getActorName($ID)." changed top headgear to: ".headgearName($number)."\n", "parseMsg_statuslook", 2 unless $ID eq $accountID;
			$players{$ID}{headgear}{top} = $number if $players{$ID};

		} elsif ($part == 5) {
			# Middle headgear change
			message getActorName($ID)." changed middle headgear to: ".headgearName($number)."\n", "parseMsg_statuslook", 2 unless $ID eq $accountID;
			$players{$ID}{headgear}{mid} = $number if $players{$ID};

		} elsif ($part == 6) {
			# Hair color change
			if ($ID eq $accountID) {
				$char->{hair_color} = $number;
				message "Your hair color changed to: $haircolors{$number} ($number)\n", "parseMsg/hairColor";
			} elsif ($players{$ID}) {
				$players{$ID}{hair_color} = $number;
				message "Player $players{$ID}{name} ($players{$ID}{binID}) changed hair color to: $haircolors{$number} ($number)\n", "parseMsg/hairColor", 2;
			} else {
				debug "Unknown #".unpack("L", $ID)." changed hair color to: $haircolors{$number} ($number)\n", "parseMsg/hairColor", 2;
			}
		}

		#if (0) {
		#my %parts = (
		#	0 => 'Body',
		#	2 => 'Right Hand',
		#	3 => 'Low Head',
		#	4 => 'Top Head',
		#	5 => 'Middle Head',
		#	8 => 'Left Hand'
		#);
		#if ($part == 3) {
		#	$part = 'low';
		#} elsif ($part == 4) {
		#	$part = 'top';
		#} elsif ($part == 5) {
		#	$part = 'mid';
		#}
		#
		#my $name = getActorName($ID);
		#if ($part == 3 || $part == 4 || $part == 5) {
		#	my $actor = getActorHash($ID);
		#	$actor->{headgear}{$part} = $items_lut{$number} if ($actor);
		#	my $itemName = $items_lut{$itemID};
		#	$itemName = 'nothing' if (!$itemName);
		#	debug "$name changes $parts{$part} ($part) equipment to $itemName\n", "parseMsg";
		#} else {
		#	debug "$name changes $parts{$part} ($part) equipment to item #$number\n", "parseMsg";
		#}
		#}

	} elsif ($switch eq "00C4") {
		my $ID = substr($msg, 2, 4);
		undef %talk;
		$talk{'buyOrSell'} = 1;
		$talk{'ID'} = $ID;
		$ai_v{'npc_talk'}{'talk'} = 'buy';
		$ai_v{'npc_talk'}{'time'} = time;

		# Resolve the source name
		my $name;
		if ($npcs{$ID}) {
			$name = $npcs{$ID}{name};
		} elsif ($monsters{$ID}) {
			$name = $monsters{$ID}{name};
		} else {
			$name = "Unknown #".unpack("L1", $ID);
		}

		message "$name: Type 'store' to start buying, or type 'sell' to start selling\n", "npc";

	} elsif ($switch eq "00C6") {
		my $newmsg;
		decrypt(\$newmsg, substr($msg, 4, length($msg)-4));
		my $msg = substr($msg, 0, 4).$newmsg;
		undef @storeList;
		my $storeList = 0;
		undef $talk{'buyOrSell'};
		for (my $i = 4; $i < $msg_size; $i += 11) {
			my $price = unpack("L1", substr($msg, $i, 4));
			my $type = unpack("C1", substr($msg, $i + 8, 1));
			my $ID = unpack("S1", substr($msg, $i + 9, 2));
			$storeList[$storeList]{'nameID'} = $ID;
			my $display = ($items_lut{$ID} ne "") 
				? $items_lut{$ID}
				: "Unknown ".$ID;
			$storeList[$storeList]{'name'} = $display;
			$storeList[$storeList]{'nameID'} = $ID;
			$storeList[$storeList]{'type'} = $type;
			$storeList[$storeList]{'price'} = $price;
			debug "Item added to Store: $storeList[$storeList]{'name'} - $price z\n", "parseMsg", 2;
			$storeList++;
		}

		# Resolve the source name
		my $name;
		my $ID = $talk{ID};
		if ($npcs{$ID}) {
			$name = $npcs{$ID}{name};
		} elsif ($monsters{$ID}) {
			$name = $monsters{$ID}{name};
		} else {
			$name = "Unknown #".unpack("L1", $ID);
		}

		message "$name: Check my store list by typing 'store'\n";
		$ai_v{'npc_talk'}{'talk'} = 'store';
		$ai_v{'npc_talk'}{'time'} = time;
		
	} elsif ($switch eq "00C7") {
		#sell list, similar to buy list
		if (length($msg) > 4) {
			my $newmsg;
			decrypt(\$newmsg, substr($msg, 4, length($msg)-4));
			my $msg = substr($msg, 0, 4).$newmsg;
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
		my $newmsg;
		decrypt(\$newmsg, substr($msg, 17, length($msg)-17));
		my $msg = substr($msg, 0, 17).$newmsg;
		my $ID = substr($msg,8,4);
		if (!$chatRooms{$ID} || !%{$chatRooms{$ID}}) {
			binAdd(\@chatRoomsID, $ID);
		}
		$chatRooms{$ID}{'title'} = substr($msg,17,$msg_size - 17);
		$chatRooms{$ID}{'ownerID'} = substr($msg,4,4);
		$chatRooms{$ID}{'limit'} = unpack("S1",substr($msg,12,2));
		$chatRooms{$ID}{'public'} = unpack("C1",substr($msg,16,1));
		$chatRooms{$ID}{'num_users'} = unpack("S1",substr($msg,14,2));
		
	} elsif ($switch eq "00D8") {
		my $ID = substr($msg,2,4);
		binRemove(\@chatRoomsID, $ID);
		delete $chatRooms{$ID};

	} elsif ($switch eq "00DA") {
		my $type = unpack("C1",substr($msg, 2, 1));
		if ($type == 1) {
			message "Can't join Chat Room - Incorrect Password\n";
		} elsif ($type == 2) {
			message "Can't join Chat Room - You're banned\n";
		}

	} elsif ($switch eq "00DB") {
		my $newmsg;
		decrypt(\$newmsg, substr($msg, 8, length($msg)-8));
		my $msg = substr($msg, 0, 8).$newmsg;
		my $ID = substr($msg,4,4);
		$currentChatRoom = $ID;
		$chatRooms{$currentChatRoom}{'num_users'} = 0;
		for (my $i = 8; $i < $msg_size; $i+=28) {
			my $type = unpack("C1",substr($msg,$i,1));
			my ($chatUser) = substr($msg,$i + 4,24) =~ /([\s\S]*?)\000/;
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
			my $num_users = unpack("S1", substr($msg,2,2));
			my ($joinedUser) = substr($msg,4,24) =~ /([\s\S]*?)\000/;
			binAdd(\@currentChatRoomUsers, $joinedUser);
			$chatRooms{$currentChatRoom}{'users'}{$joinedUser} = 1;
			$chatRooms{$currentChatRoom}{'num_users'} = $num_users;
			message "$joinedUser has joined the Chat Room\n";
		}
	
	} elsif ($switch eq "00DD") {
		my $num_users = unpack("S1", substr($msg,2,2));
		my ($leaveUser) = substr($msg,4,24) =~ /([\s\S]*?)\000/;
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
		my $newmsg;
		decrypt(\$newmsg, substr($msg, 17, length($msg)-17));
		my $msg = substr($msg, 0, 17).$newmsg;
		my $ID = substr($msg,8,4);
		my $ownerID = substr($msg,4,4);
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
		my $type = unpack("C1",substr($msg, 2, 1));
		my ($chatUser) = substr($msg, 6, 24) =~ /([\s\S]*?)\000/;
		if ($type == 0) {
			if ($chatUser eq $chars[$config{'char'}]{'name'}) {
				$chatRooms{$currentChatRoom}{'ownerID'} = $accountID;
			} else {
				my $key = findKeyString(\%players, "name", $chatUser);
				$chatRooms{$currentChatRoom}{'ownerID'} = $key;
			}
			$chatRooms{$currentChatRoom}{'users'}{$chatUser} = 2;
		} else {
			$chatRooms{$currentChatRoom}{'users'}{$chatUser} = 1;
		}

	} elsif ($switch eq "00E5" || $switch eq "01F4") {
		# Recieving deal request
		my ($dealUser) = substr($msg, 2, 24) =~ /([\s\S]*?)\000/; 
		my $dealUserLevel = $switch eq "01F4" ?
			unpack("S1",substr($msg, 30, 2)) :
			'Unknown';
		$incomingDeal{'name'} = $dealUser; 
		$timeout{'ai_dealAutoCancel'}{'time'} = time; 
		message "$dealUser (level $dealUserLevel) Requests a Deal\n", "deal"; 
		message "Type 'deal' to start dealing, or 'deal no' to deny the deal.\n", "deal"; 

	} elsif ($switch eq "00E7" || $switch eq "01F5") {
		my $type = unpack("C1", substr($msg, 2, 1));
		
		if ($type == 0) {
			error "That person is too far from you to trade.\n";
		} elsif ($type == 3) {
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
			my $item = $currentDeal{other}{$ID} ||= {};
			$item->{amount} += $amount;
			$item->{nameID} = $ID;
			$item->{identified} = unpack("C1", substr($msg, 8, 1));
			$item->{broken} = unpack("C1", substr($msg, 9, 1));
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
			$itemChange{$char->{inventory}[$invIndex]{name}} -= $currentDeal{lastItemAmount};
			$currentDeal{you_items}++;
			if ($chars[$config{'char'}]{'inventory'}[$invIndex]{'amount'} <= 0) {
				delete $chars[$config{'char'}]{'inventory'}[$invIndex];
			}
		}

	} elsif ($switch eq "00EC") {
		my $type = unpack("C1", substr($msg, 2, 1));
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

	} elsif ($switch eq "00F6") {
		my $index = unpack("S1", substr($msg, 2, 2));
		my $amount = unpack("L1", substr($msg, 4, 4));
		$storage{$index}{amount} -= $amount;
		message "Storage Item Removed: $storage{$index}{name} ($storage{$index}{binID}) x $amount\n", "storage";
		$itemChange{$storage{$index}{name}} -= $amount;
		if ($storage{$index}{amount} <= 0) {
			delete $storage{$index};
			binRemove(\@storageID, $index);
		}

	} elsif ($switch eq "00F8") {
		message "Storage closed.\n", "storage";
		delete $ai_v{temp}{storage_opened};
		Plugins::callHook('packet_storage_close');

		# Storage log
		writeStorageLog(0);

	} elsif ($switch eq "00FA") {
		my $type = unpack("C1", substr($msg, 2, 1));
		if ($type == 1) {
			warning "Can't organize party - party name exists\n";
		} else {
			my %party;
			my %user;
			$user{name} = $char->{name};
			$user{admin} = 1;
			$user{online} = 1;
			$user{pos} = {$char->{pos_to}};
			$user{hp} = $char->{hp};
			$user{hp} = $char->{hp_max};
			$party{name} = $lastPartyOrganizeName;
			$party{users}{$accountID} = \%user;
			$char->{party} = \%party;
			@partyUsersID = ($accountID);
			message "Party $lastPartyOrganizeName organized.\n", "info";
			undef $lastPartyOrganizeName;
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
			$chars[$config{'char'}]{'party'}{'users'}{$ID} = new Actor::Party;
			($chars[$config{'char'}]{'party'}{'users'}{$ID}{'name'}) = substr($msg, $i + 4, 24) =~ /([\s\S]*?)\000/;
			message "Party Member: $chars[$config{'char'}]{'party'}{'users'}{$ID}{'name'}\n", undef, 1;
			($chars[$config{'char'}]{'party'}{'users'}{$ID}{'map'}) = substr($msg, $i + 28, 16) =~ /([\s\S]*?)\000/;
			$chars[$config{'char'}]{'party'}{'users'}{$ID}{'online'} = !(unpack("C1",substr($msg, $i + 45, 1)));
			$chars[$config{'char'}]{'party'}{'users'}{$ID}{'admin'} = 1 if ($num == 0);
		}
		sendPartyShareEXP(\$remote_socket, 1) if ($config{'partyAutoShare'} && $chars[$config{'char'}]{'party'} && %{$chars[$config{'char'}]{'party'}});

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
		my $type = unpack("C1", substr($msg, 2, 1));
		$chars[$config{'char'}]{'party'}{'share'} = $type;
		if ($type == 0) {
			message "Party EXP set to Individual Take\n", "party", 1;
		} elsif ($type == 1) {
			message "Party EXP set to Even Share\n", "party", 1;
		} else {
			error "Error setting party option\n";
		}
		
	} elsif ($switch eq "0104") {
		my $ID = substr($msg, 2, 4);
		my $x = unpack("S1", substr($msg,10, 2));
		my $y = unpack("S1", substr($msg,12, 2));
		my $type = unpack("C1",substr($msg, 14, 1));
		my ($name) = substr($msg, 15, 24) =~ /([\s\S]*?)\000/;
		my ($partyUser) = substr($msg, 39, 24) =~ /([\s\S]*?)\000/;
		my ($map) = substr($msg, 63, 16) =~ /([\s\S]*?)\000/;
		if (!$chars[$config{'char'}]{'party'}{'users'}{$ID} || !%{$chars[$config{'char'}]{'party'}{'users'}{$ID}}) {
			binAdd(\@partyUsersID, $ID) if (binFind(\@partyUsersID, $ID) eq "");
			if ($ID eq $accountID) {
				message "You joined party '$name'\n", undef, 1;
				$char->{party} = {};
			} else {
				message "$partyUser joined your party '$name'\n", undef, 1;
			}
		}
		$chars[$config{'char'}]{'party'}{'users'}{$ID} = new Actor::Party;
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
			delete $chars[$config{'char'}]{'party'};
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
		my $newmsg;
		decrypt(\$newmsg, substr($msg, 8, length($msg)-8));
		my $ID = substr($msg, 4, 4);
		my $chat = substr($msg, 8, $msg_size - 8);
		$chat =~ s/\000//g;
		my ($chatMsgUser, $chatMsg) = $chat =~ /([\s\S]*?) : ([\s\S]*)/;
		$chatMsgUser =~ s/ $//;

		stripLanguageCode(\$chatMsg);
		$chat = "$chatMsgUser : $chatMsg";
		message "[Party] $chat\n", "partychat";

		chatLog("p", "$chat\n") if ($config{'logPartyChat'});
		ChatQueue::add('p', $ID, $chatMsgUser, $chatMsg);
		
		Plugins::callHook('packet_partyMsg', {
		        MsgUser => $chatMsgUser,
		        Msg => $chatMsg
		});

	# Hambo Started
	# 3 Packets About MVP
	} elsif ($switch eq "010A") {
		my $ID = unpack("S1", substr($msg, 2, 2));
		my $display = itemName({nameID => $ID});
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

		# Set $skillchanged to 2 so it knows to unset it when skill points are updated
		if ($skillChanged eq $handle) {
			$skillChanged = 2;
		}

		debug "Skill $name: $lv\n", "parseMsg";

	} elsif ($switch eq "010F") {
		# Character skill list
		$conState = 5 if ($conState != 4 && $xkore);
		my $newmsg;
		decrypt(\$newmsg, substr($msg, 4, length($msg)-4));
		my $msg = substr($msg, 0, 4).$newmsg;

		undef @skillsID;
		delete $char->{skills};
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
		Plugins::callHook('packet_skillfail', {'skillID' => $skillID, 'failType' => $failtype{$type}});

	} elsif ($switch eq "01B9") {
		# Cast is cancelled
		my $ID = substr($msg, 2, 4);

		my $source = Actor::get($ID);
		$source->{cast_cancelled} = time;
		my $skill = $source->{casting}->{skill};
		my $skillName = $skill ? $skill->name : 'Unknown';
		my $domain = ($ID eq $accountID) ? "selfSkill" : "skill";
		message "$source failed to cast $skillName\n", $domain;
		delete $source->{casting};

	} elsif ($switch eq "0114" || $switch eq "01DE") {
		# Skill use
		my $dmg_t = $switch eq "0114" ? "s1" : "l1";
		my ($skillID, $sourceID, $targetID, $tick, $src_speed, $dst_speed, $damage, $level, $param3, $type) = unpack("x2 S1 a4 a4 L1 L1 L1 $dmg_t S1 S1 C1", $msg);

		if (my $spell = $spells{$sourceID}) {
			# Resolve source of area attack skill
			$sourceID = $spell->{sourceID};
		}

		my $source = Actor::get($sourceID);
		my $target = Actor::get($targetID);

		delete $source->{casting};

		# Perform trigger actions
		$conState = 5 if $conState != 4 && $xkore;
		updateDamageTables($sourceID, $targetID, $damage) if ($damage != -30000);
		setSkillUseTimer($skillID, $targetID) if ($sourceID eq $accountID);
		setPartySkillTimer($skillID, $targetID) if
			$sourceID eq $accountID or $sourceID eq $targetID;
		countCastOn($sourceID, $targetID, $skillID);

		# Resolve source and target names
		$damage ||= "Miss!";
		my $verb = $source->verb('use', 'uses');
		my $disp = "$source $verb ".skillName($skillID);
		$disp .= " (lvl $level)" unless $level == 65535;
		$disp .= " on $target";
		$disp .= " - Dmg: $damage" unless $damage == -30000;
		$disp .= " (delay ".($src_speed/10).")";
		$disp .= "\n";

		if ($damage != -30000 &&
		    $sourceID eq $accountID &&
			$targetID ne $accountID) {
			calcStat($damage);
		}

		my $domain = ($sourceID eq $accountID) ? "selfSkill" : "skill";

		if ($damage == 0) {
			$domain = "attackMonMiss" if $sourceID eq $accountID && $targetID ne $accountID;
			$domain = "attackedMiss" if $sourceID ne $accountID && $targetID eq $accountID;

		} elsif ($damage != -30000) {
			$domain = "attackMon" if $sourceID eq $accountID && $targetID ne $accountID;
			$domain = "attacked" if $sourceID ne $accountID && $targetID eq $accountID;
		}

		if ((($sourceID eq $accountID) && ($targetID ne $accountID)) ||
		    (($sourceID ne $accountID) && ($targetID eq $accountID))) {
			my $status = sprintf("[%3d/%3d] ", percent_hp($char), percent_sp($char));
			$disp = $status.$disp;
		}
		$target->{sitting} = 0 unless $type == 4 || $type == 9 || $damage == 0;

		Plugins::callHook('packet_skilluse', {
			'skillID' => $skillID,
			'sourceID' => $sourceID,
			'targetID' => $targetID,
			'damage' => $damage,
			'amount' => 0,
			'x' => 0,
			'y' => 0,
			'disp' => \$disp
		});

		message $disp, $domain, 1;

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
		my $domain = ($sourceID eq $accountID) ? "selfSkill" : "skill";
		message $disp, $domain;

		Plugins::callHook('packet_skilluse', {
			'skillID' => $skillID,
			'sourceID' => $sourceID,
			'targetID' => '',
			'damage' => 0,
			'amount' => $lv,
			'x' => $x,
			'y' => $y
		});


	} elsif ($switch eq "0119" || $switch eq "0229") {
		# Character looks
		my $ID = substr($msg, 2, 4);
		my $param1 = unpack("S1", substr($msg, 6, 2));
		my $param2 = unpack("S1", substr($msg, 8, 2));
		my $param3 = unpack("S1", substr($msg, 10, 2));
		setStatus($ID, $param1, $param2, $param3);

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
		$conState = 5 if $conState != 4 && $xkore;
		setSkillUseTimer($skillID, $targetID) if ($sourceID eq $accountID);
		setPartySkillTimer($skillID, $targetID) if
			$sourceID eq $accountID or $sourceID eq $targetID;
		countCastOn($sourceID, $targetID, $skillID);
		if ($sourceID eq $accountID) {
			my $pos = calcPosition($char);
			$char->{pos_to} = $pos;
			$char->{time_move} = 0;
			$char->{time_move_calc} = 0;
		}

		# Resolve source and target names
		my $source = Actor::get($sourceID);
		my $target = Actor::get($targetID);
		my $verb = $source->verb('use', 'uses');

		delete $source->{casting};

		# Print skill use message
		my $extra = "";
		if ($skillID == 28) {
			$extra = ": $amount hp gained";
			updateDamageTables($sourceID, $targetID, -$amount);
		} elsif ($amount != 65535) {
			$extra = ": Lv $amount";
		}
  
		my $domain = ($sourceID eq $accountID) ? "selfSkill" : "skill";
		message "$source $verb ".skillName($skillID)." on ".$target->nameString($source)."$extra\n", $domain;

		if ($AI && $config{'autoResponseOnHeal'}) {
			# Handle auto-response on heal
			if (($players{$sourceID} && %{$players{$sourceID}}) && (($skillID == 28) || ($skillID == 29) || ($skillID == 34))) {
				if ($targetID eq $accountID) {
					chatLog("k", "***$source ".skillName($skillID)." on $target$extra***\n");
					sendMessage(\$remote_socket, "pm", getResponse("skillgoodM"), $players{$sourceID}{'name'});
				} elsif ($monsters{$targetID}) {
					chatLog("k", "***$source ".skillName($skillID)." on $target$extra***\n");
					sendMessage(\$remote_socket, "pm", getResponse("skillbadM"), $players{$sourceID}{'name'});
				}
			}
		}

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
		my $binID = binAdd(\@spellsID, $ID);
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
			$item->{broken} = unpack("C1", substr($msg, $i+10, 1));
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
			$item->{broken} = unpack("C1", substr($msg, 11 + $psize, 1));
			$item->{upgrade} = unpack("C1", substr($msg, 12 + $psize, 1));
			$item->{cards} = substr($msg, 13 + $psize, 8);
			$item->{name} = itemName($item);
		}
		message "Cart Item Added: $item->{name} ($index) x $amount\n";
		$itemChange{$item->{name}} += $amount;

	} elsif ($switch eq "0125") {
		my $index = unpack("S1", substr($msg, 2, 2));
		my $amount = unpack("L1", substr($msg, 4, 4));

		$cart{'inventory'}[$index]{'amount'} -= $amount;
		message "Cart Item Removed: $cart{'inventory'}[$index]{'name'} ($index) x $amount\n";
		$itemChange{$cart{inventory}[$index]{name}} -= $amount;
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
		if (!$venderLists{$ID} || !%{$venderLists{$ID}}) {
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

		message("----------Vender Store List-----------\n", "list");
		message("#  Name                                         Type           Amount Price\n", "list");
		for (my $i = 8; $i < $msg_size; $i+=22) {
			my $number = unpack("S1", substr($msg, $i + 6, 2));

			my $item = $venderItemList[$number] = {};
			$item->{price} = unpack("L1", substr($msg, $i, 4));
			$item->{amount} = unpack("S1", substr($msg, $i + 4, 2));
			$item->{type} = unpack("C1", substr($msg, $i + 8, 1));
			$item->{nameID} = unpack("S1", substr($msg, $i + 9, 2));
			$item->{identified} = unpack("C1", substr($msg, $i + 11, 1));
			$item->{broken} = unpack("C1", substr($msg, $i + 12, 1));
			$item->{upgrade} = unpack("C1", substr($msg, $i + 13, 1));
			$item->{cards} = substr($msg, $i + 14, 8);
			$item->{name} = itemName($item);

			debug("Item added to Vender Store: $item->{name} - $item->{price} z\n", "vending", 2);

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
		# FIXME: why do we need a seperate variable to track how many items are left in the store?
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
			$item->{broken} = unpack("C1", substr($msg, $i + 12, 1));
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
		my $ID = substr($msg, 2, 4);
		my $type = unpack("C1",substr($msg, 14, 1));
		my %coords1;
		$coords1{'x'} = unpack("S1",substr($msg, 6, 2));
		$coords1{'y'} = unpack("S1",substr($msg, 8, 2));
		my %coords2;
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
		if ($config{attackDistanceAuto} && $config{attackDistance} != $type) {
			message "Autodetected attackDistance = $type\n", "success";
			configModify('attackDistance', $type, 1);
			configModify('attackMaxDistance', $type, 1);
		}

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
		my $type = unpack("S1",substr($msg, 2, 2));
		my $amount = unpack("S1",substr($msg, 4, 2));
		if ($type == 5) {
			$chars[$config{'char'}]{'hp'} += $amount;
			$chars[$config{'char'}]{'hp'} = $chars[$config{'char'}]{'hp_max'} if ($chars[$config{'char'}]{'hp'} > $chars[$config{'char'}]{'hp_max'});
		} elsif ($type == 7) {
			$chars[$config{'char'}]{'sp'} += $amount;
			$chars[$config{'char'}]{'sp'} = $chars[$config{'char'}]{'sp_max'} if ($chars[$config{'char'}]{'sp'} > $chars[$config{'char'}]{'sp_max'});
		}

	} elsif ($switch eq "013E") {
		$conState = 5 if ($conState != 4 && $xkore);
		my $sourceID = substr($msg, 2, 4);
		my $targetID = substr($msg, 6, 4);
		my $x = unpack("S1", substr($msg, 10, 2));
		my $y = unpack("S1", substr($msg, 12, 2));
		my $skillID = unpack("S1", substr($msg, 14, 2));
		my $type = unpack("S1", substr($msg, 18, 2));
		my $wait = unpack("L1", substr($msg, 20, 4));
		my ($dist, %coords);

		# Resolve source and target
		my $source = Actor::get($sourceID);
		my $target = Actor::get($targetID);
		my $verb = $source->verb('are casting', 'is casting');

		$source->{casting} = {
			skill => new Skills(id => $skillID),
			target => $target,
			x => $x,
			y => $y,
			startTime => time,
			castTime => $wait
		};

		my $targetString;
		if ($x != 0 || $y != 0) {
			# If $dist is positive we are in range of the attack?
			$coords{x} = $x;
			$coords{y} = $y;
			$dist = judgeSkillArea($skillID) - distance($char->{pos_to}, \%coords);

			$targetString = "location ($x, $y)";
			undef $targetID;
		} else {
			$targetString = $target->nameString($source);
		}

		# Perform trigger actions
		if ($sourceID eq $accountID) {
			$char->{time_cast} = time;
			$char->{time_cast_wait} = $wait / 1000;
			delete $char->{cast_cancelled};
		}

		countCastOn($sourceID, $targetID, $skillID, $x, $y);
		my $domain = ($sourceID eq $accountID) ? "selfSkill" : "skill";
		message "$source $verb ".skillName($skillID)." on $targetString (time ${wait}ms)\n", $domain, 1;

		Plugins::callHook('is_casting', {
			sourceID => $sourceID,
			targetID => $targetID,
			skillID => $skillID,
			x => $x,
			y => $y
		});

		# Skill Cancel
		if ($AI && $monsters{$sourceID} && %{$monsters{$sourceID}} && mon_control($monsters{$sourceID}{'name'})->{'skillcancel_auto'}) {
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
		my $type = unpack("S1",substr($msg, 2, 2));
		my $val = unpack("S1",substr($msg, 6, 2));
		my $val2 = unpack("S1",substr($msg, 10, 2));
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
		my $ID = substr($msg, 2, 4);

		# Resolve the source name
		my $name;
		if ($npcs{$ID}) {
			$name = $npcs{$ID}{name};
		} elsif ($monsters{$ID}) {
			$name = $monsters{$ID}{name};
		} else {
			$name = "Unknown #".unpack("L1", $ID);
		}

		message("$name: Type 'talk num <number #>' to input a number.\n", "input");
		$ai_v{'npc_talk'}{'talk'} = 'num';
		$ai_v{'npc_talk'}{'time'} = time;

	} elsif ($switch eq "0147") {
		my $skillID = unpack("S*",substr($msg, 2, 2));
		my $skillLv = unpack("S*",substr($msg, 8, 2)); 
		my $skillName = unpack("A*", substr($msg, 14, 24));

		message "Permitted to use $skillsID_lut{$skillID} ($skillID), level $skillLv\n";
		my $skill = Skills->new(id => $skillID);

		unless ($config{noAutoSkill}) {
			sendSkillUse(\$remote_socket, $skillID, $skillLv, $accountID);
			undef $char->{permitSkill};
		} else {
			$char->{permitSkill} = $skill;
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

		} elsif ($players{$targetID} && %{$players{$targetID}}) {
			undef $players{$targetID}{'dead'};
		}

		if ($targetID ne $accountID) {
			message(getActorName($targetID)." has been resurrected\n", "info");
			$players{$targetID}{deltaHp} = 0;
		}

	} elsif ($switch eq "014C") {
		# Guild Allies/Enemy List
		# <len>.w (<type>.l <guildID>.l <guild name>.24B).*
		# type=0 Ally
		# type=1 Enemy

		# This is the length of the entire packet
		my $len = unpack("S", substr($msg, 2, 2));

		for (my $i = 4; $i < $len; $i += 32) {
			my ($type, $guildID, $guildName) = unpack("L1 L1 Z24", substr($msg, $i, 32));
			if ($type) {
				# Enemy guild
				$guild{enemy}{$guildID} = $guildName;
			} else {
				# Allied guild
				$guild{ally}{$guildID} = $guildName;
			}
			debug "Your guild is ".($type ? 'enemy' : 'ally')." with guild $guildID ($guildName)\n", "guild";
		}

	} elsif ($switch eq "0154") {
		my $newmsg;
		my $jobID;
		decrypt(\$newmsg, substr($msg, 4, length($msg) - 4));
		my $msg = substr($msg, 0, 4) . $newmsg;
		my $c = 0;
		for (my $i = 4; $i < $msg_size; $i+=104){
			$guild{'member'}[$c]{'ID'}    = substr($msg, $i, 4);
			$guild{'member'}[$c]{'charID'}    = substr($msg, $i+4, 4);
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
		my ($guildID, $emblemID, $mode, $guildName) = unpack("x2 L L L x5 Z24", $msg);
		$char->{guild}{name} = $guildName;
		$char->{guildID} = $guildID;

	} elsif ($switch eq "016D") {
		my $ID = substr($msg, 2, 4);
		my $TargetID =  substr($msg, 6, 4);
		my $online = unpack("L1", substr($msg, 10, 4));
		undef %guildNameRequest;
		$guildNameRequest{ID} = $TargetID;
		$guildNameRequest{online} = $online;
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
		for (my $i = 4; $i < $msg_size; $i += 2) {
			my $index = unpack("S1", substr($msg, $i, 2));
			my $invIndex = findIndex(\@{$chars[$config{'char'}]{'inventory'}}, "index", $index);
			binAdd(\@identifyID, $invIndex);
		}
		my $num = @identifyID;
		message "Received Possible Identify List ($num item(s)) - type 'identify'\n", 'info';

	} elsif ($switch eq "0179") {
		my $index = unpack("S*",substr($msg, 2, 2));
		my $invIndex = findIndex($char->{inventory}, "index", $index);
		$char->{inventory}[$invIndex]{identified} = 1;
		$char->{inventory}[$invIndex]{type_equip} = $itemSlots_lut{$char->{inventory}[$invIndex]{nameID}};
		message "Item Identified: $char->{inventory}[$invIndex]{name}\n", "info";
		undef @identifyID;

	} elsif ($switch eq "017B") {
		# You just requested a list of possible items to merge a card into
		# The RO client does this when you double click a card
		#decrypt(\$msg, substr($msg, 4, length($msg)-4));
		#$msg = substr($msg, 0, 4).$msg;
		my ($len) = unpack("x2 S1", $msg);

		my $display;
		$display .= "-----Card Merge Candidates-----\n";

		my $index;
		my $invIndex;
		for (my $i = 4; $i < $len; $i += 2) {
			$index = unpack("S1", substr($msg, $i, 2));
			$invIndex = findIndex($char->{inventory}, "index", $index);
			binAdd(\@cardMergeItemsID,$invIndex);
			$display .= "$invIndex $char->{inventory}[$invIndex]{name}\n";
		}

		$display .= "-------------------------------\n";
		message $display, "list";

	} elsif ($switch eq "017D") {
		# something about successful compound?
		my $item_index = unpack("S1", substr($msg, 2, 2));
		my $card_index = unpack("S1", substr($msg, 4, 2));
		my $fail = unpack("C1", substr($msg, 6, 1));

		if ($fail) {
			message "Card merging failed\n";
		} else {
			my $item_invindex = findIndex($char->{inventory}, "index", $item_index);
			my $card_invindex = findIndex($char->{inventory}, "index", $card_index);
			message "$char->{inventory}[$card_invindex]{name} has been successfully merged into $char->{inventory}[$item_invindex]{name}\n", "success";

			# get the ID so we can pack this into the weapon cards
			my $nameID = $char->{inventory}[$card_invindex]{nameID};

			# remove one of the card
			my $item = $char->{inventory}[$card_invindex];
			$item->{amount} -= 1;
			if ($item->{amount} <= 0) {
				delete $char->{inventory}[$card_invindex];
			}

			# rename the slotted item now
			my $item = $char->{inventory}[$item_invindex];
			# put the card into the item
			# FIXME: this is unoptimized
			my $newcards;
			my $addedcard;
			for (my $i = 0; $i < 4; $i++) {
				my $card = substr($item->{cards}, $i*2, 2);
				if (unpack("S1", $card)) {
					$newcards .= $card;
				} elsif (!$addedcard) {
					$newcards .= pack("S1", $nameID);
					$addedcard = 1;
				} else {
					$newcards .= pack("S1", 0);
				}
			}
			$item->{cards} = $newcards;
			$item->{name} = itemName($item);
		}

		undef @cardMergeItemsID;
		undef $cardMergeIndex;

	} elsif ($switch eq "017F") {
		my $newmsg;
		decrypt(\$newmsg, substr($msg, 4, length($msg)-4));
		my $msg = substr($msg, 0, 4).$newmsg;
		# there is no ID sent
		#my $ID = substr($msg, 4, 4);
		my $chat = substr($msg, 4, $msg_size - 4);
		$chat =~ s/\000+.*$//;
		my ($chatMsgUser, $chatMsg);
		if (($chatMsgUser, $chatMsg) = $chat =~ /(.*?) : (.*)/) {
			$chatMsgUser =~ s/ $//;
			stripLanguageCode(\$chatMsg);
			$chat = "$chatMsgUser : $chatMsg";
		}

		chatLog("g", "$chat\n") if ($config{'logGuildChat'});
		message "[Guild] $chat\n", "guildchat";
		# only queue this if it's a real chat message
		ChatQueue::add('g', 0, $chatMsgUser, $chatMsg) if ($chatMsgUser);
		
		Plugins::callHook('packet_guildMsg', {
		        MsgUser => $chatMsgUser,
		        Msg => $chatMsg
		});

	} elsif ($switch eq "0187") {
		# 0187 - long ID
		# I'm not sure what this is. In inRO this seems to have something
		# to do with logging into the game server, while on
		# oRO it has got something to do with the sync packet.
		if ($config{serverType} == 1) {
			my $ID = substr($msg, 2, 4);
			if ($ID == $accountID) {
				$timeout{ai_sync}{time} = time;
				sendSync(\$remote_socket) if (!$xkore);
				debug "Sync packet requested\n", "connection";
			} else {
				warning "Sync packet requested for wrong ID\n";
			}
		}

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
		
		message "Guild Member $name Log ".($guildNameRequest{online}?"In":"Out")."\n", 'guildchat';

	} elsif ($switch eq "0195") {
		my $ID = substr($msg, 2, 4);
		if ($players{$ID} && %{$players{$ID}}) {
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
			my $again = 'now';
			if ($actor) {
				$again = 'again' if $actor->{statuses}{$skillName};
				$actor->{statuses}{$skillName} = 1;
			}
			message "$name $is $again: $skillName\n", "parseMsg_statuslook",
				$ID eq $accountID ? 1 : 2;

		} else {
			# Skill de-activated (expired)
			delete $actor->{statuses}{$skillName} if $actor;
			message "$name $is no longer: $skillName\n", "parseMsg_statuslook",
				$ID eq $accountID ? 1 : 2;
		}

	} elsif ($switch eq "0199") {
		# 99 01 - 4 bytes, used by eAthena and < EP5 Aegis
		my $type = unpack("x2 S1", $msg);
		if ($type == 0) {
			$ai_v{temp}{pvp} = 0;
		} elsif ($type == 1) {
			message "PvP Display Mode\n", "map_event";
			$ai_v{temp}{pvp} = 1;
		} elsif ($type == 3) {
			message "GvG Display Mode\n", "map_event";
			$ai_v{temp}{pvp} = 2;
		}

	} elsif ($switch eq "01D6") {
		# D6 01 - 4 bytes, used by Aegis 8.5
		my $type = unpack("x2 S1", $msg);
		if ($type == 0) {
			$ai_v{temp}{pvp} = 0;
		} elsif ($type == 6) {
			message "PvP Display Mode\n", "map_event";
			$ai_v{temp}{pvp} = 1;
		} elsif ($type == 8) {
			message "GvG Display Mode\n", "map_event";
			$ai_v{temp}{pvp} = 2;
		}

	} elsif ($switch eq "019A") {
		# 9A 01 - 14 bytes long
		my ($ID, $rank, $num) = unpack("x2 L1 L1 L1", $msg);
		if ($rank != $ai_v{temp}{pvp_rank} ||
		    $num != $ai_v{temp}{pvp_num}) {
			$ai_v{temp}{pvp_rank} = $rank;
			$ai_v{temp}{pvp_num} = $num;
			message "Your PvP rank is: $rank/$num\n", "map_event";
		}

	} elsif ($switch eq "019B") {
		my $ID = substr($msg, 2, 4);
		my $type = unpack("L1",substr($msg, 6, 4));
		my $name = getActorName($ID);
		if ($type == 0) {
			message "$name gained a level!\n";
		} elsif ($type == 1) {
			message "$name gained a job level!\n";
		} elsif ($type == 2) {
			message "$name failed to refine a weapon!\n", "refine";
		} elsif ($type == 3) {
			message "$name successfully refined a weapon!\n", "refine";
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
		#my ($name) = substr($msg, 2, 24) =~ /([\s\S]*?)\000/;

	} elsif ($switch eq "01A4") {
		#pet spawn
		my $type = unpack("C1",substr($msg, 2, 1));
		my $ID = substr($msg, 3, 4);
		if (!$pets{$ID} || !%{$pets{$ID}}) {
			binAdd(\@petsID, $ID);
			$pets{$ID} = {};
			%{$pets{$ID}} = %{$monsters{$ID}};
			$pets{$ID}{name_given} = "Unknown";
			$pets{$ID}{binID} = binFind(\@petsID, $ID);
		}
		if ($monsters{$ID} && %{$monsters{$ID}}) {
			binRemove(\@monstersID, $ID);
			objectRemoved('monster', $ID, $monsters{$ID});
			delete $monsters{$ID};
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

	} elsif ($switch eq "01AB") {
		my ($ID, $duration) = unpack "x2 a4 x2 L1", $msg;
		if ($duration > 0) {
			$duration = 0xFFFFFFFF - $duration + 1;
			message getActorName($ID) . " is muted for $duration minutes\n", "parseMsg_statuslook", 2;
		} else {
			message getActorName($ID) . " is no longer muted\n", "parseMsg_statuslook", 2;
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
			$monsters{$ID}{nameID} = $type;
			$monsters{$ID}{name} = $name;
			$monsters{$ID}{dmgToParty} = 0;
			$monsters{$ID}{dmgFromParty} = 0;
			$monsters{$ID}{missedToParty} = 0;
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
				$item->{broken} = unpack("C1", substr($msg, 12, 1));
				$item->{upgrade} = unpack("C1", substr($msg, 13, 1));
				$item->{cards} = substr($msg, 14, 8);
			} elsif ($switch eq "00F4") {
				$item->{identified} = unpack("C1", substr($msg, 10, 1));
				$item->{broken} = unpack("C1", substr($msg, 11, 1));
				$item->{upgrade} = unpack("C1", substr($msg, 12, 1));
				$item->{cards} = substr($msg, 13, 8);
			}
			$item->{name} = itemName($item);
			$item->{binID} = binFind(\@storageID, $index);
		}
		message("Storage Item Added: $item->{name} ($item->{binID}) x $amount\n", "storage", 1);
		$itemChange{$item->{name}} += $amount;
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
			my $item = $char->{inventory}[$invIndex];
			my $amount = $item->{amount} - $amountleft;
			$item->{amount} -= $amount;

			message("You used Item: $item->{name} ($invIndex) x $amount - $amountleft left\n", "useItem", 1);
			$itemChange{$item->{name}}--;
			if ($item->{amount} <= 0) {
				delete $char->{inventory}[$invIndex];
			}

			Plugins::callHook('packet_useitem', {
				item => $item,
				invIndex => $invIndex,
				name => $item->{name},
				amount => $amount
			});

		} else {
			my $actor = Actor::get($ID);
			message "$actor used Item: $itemDisplay - $amountleft left\n", "useItem", 2;
		}

	} elsif ($switch eq "01CD") {
		# Sage Autospell - list of spells availible sent from server
		if ($config{autoSpell}) {
			my $skill = Skills->new(name => $config{autoSpell});
			sendAutoSpell(\$remote_socket,$skill->id);
		}

	} elsif ($switch eq "01D0" || $switch eq "01E1") {
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

		# Resolve the source name
		my $name;
		if ($npcs{$ID}) {
			$name = $npcs{$ID}{name};
		} elsif ($monsters{$ID}) {
			$name = $monsters{$ID}{name};
		} else {
			$name = "Unknown #".unpack("L1", $ID);
		}

		message "$name: Type 'talk text' (Respond to NPC)\n", "npc";
		$ai_v{'npc_talk'}{'talk'} = 'text';
		$ai_v{'npc_talk'}{'time'} = time;

	} elsif ($switch eq "01D7") {
		# Weapon Display (type - 2:hand eq, 9:foot eq)
		my $sourceID = substr($msg, 2, 4);
		my $type = unpack("C1",substr($msg, 6, 1));
		my $ID1 = unpack("S1", substr($msg, 7, 2));
		my $ID2 = unpack("S1", substr($msg, 9, 2));

		if (my $player = $players{$sourceID}) {
			my $name = getActorName($sourceID);
			if ($type == 2) {
				if ($ID1 ne $player->{weapon}) {
					message "$name changed Weapon to ".itemName({nameID => $ID1})."\n", "parseMsg_statuslook", 2;
					$player->{weapon} = $ID1;
				}
				if ($ID2 ne $player->{shield}) {
					message "$name changed Shield to ".itemName({nameID => $ID2})."\n", "parseMsg_statuslook", 2;
					$player->{shield} = $ID2;
				}
			} elsif ($type == 9) {
				if ($player->{shoes} && $ID1 ne $player->{shoes}) {
					message "$name changed Shoes to: ".itemName({nameID => $ID1})."\n", "parseMsg_statuslook", 2;
				}
				$player->{shoes} = $ID1;
			}
		}
      		
	} elsif ($switch eq "01DC") {
		$secureLoginKey = substr($msg, 4, $msg_size);

	} elsif ($switch eq "01F4") {
		# Recieving deal request
		# 01DC: 24byte nick, long charID, word level
		my ($dealUser) = substr($msg, 2, 24) =~ /([\s\S]*?)\000/;
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
		my $newmsg;
		decrypt(\$newmsg, substr($msg, 4, length($msg)-4));
		my $msg = substr($msg, 0, 4).$newmsg;
		undef @arrowCraftID;
		for (my $i = 4; $i < $msg_size; $i += 2) {
			my $ID = unpack("S1", substr($msg, $i, 2));
			my $index = findIndex($char->{inventory}, "nameID", $ID);
			binAdd(\@arrowCraftID, $index);
		}
		message "Received Possible Arrow Craft List - type 'arrowcraft'\n";

	} elsif ($switch eq "0169") {
		my $type = unpack("C1", substr($msg, 2, 1));
		my %types = (
			0 => 'Target is already in a guild.',
			1 => 'Target has denied.',
			2 => 'Target has accepted.',
			3 => 'Your guild is full.'
		);
		message "Guild join request: ".($types{$type} || "Unknown $type")."\n";

	} elsif ($switch eq "0201") {
		# Friend list
		undef @friendsID;
		undef %friends;
		my $ID = 0;
		for (my $i = 4; $i < $msg_size; $i += 32) {
			binAdd(\@friendsID, $ID);
			$friends{$ID}{'accountID'} = substr($msg, $i, 4);
			$friends{$ID}{'charID'} = substr($msg, $i + 4, 4);
			$friends{$ID}{'name'} = unpack("Z24", substr($msg, $i + 8 , 24));
			$friends{$ID}{'online'} = 0;
			$ID++;
		}

	} elsif ($switch eq "0206") {
		# Friend In/Out
		my $friendAccountID = substr($msg, 2, 4);
		my $friendCharID = substr($msg, 6, 4);
		my $isNotOnline = unpack("C1",substr($msg, 10, 1));
		
		for (my $i = 0; $i < @friendsID; $i++) {
			if ($friends{$i}{'accountID'} eq $friendAccountID && $friends{$i}{'charID'} eq $friendCharID) {
				$friends{$i}{'online'} = 1 - $isNotOnline;
				message "Friend $friends{$i}{'name'} has been " .
					($isNotOnline? 'disconnected' : 'connected') . "\n", undef, 1;
				last;
			}
		}

	} elsif ($switch eq "0207") {
		# Incoming friend request
		$incomingFriend{'accountID'} = substr($msg, 2, 4);
		$incomingFriend{'charID'} = substr($msg, 6, 4);
		$incomingFriend{'name'} = unpack("Z24", substr($msg, 10, 24));
		message "$incomingFriend{'name'} wants to be your friend\n";
		message "Type 'friend accept' to be friend with $incomingFriend{'name'}, otherwise type 'friend reject'\n";

	} elsif ($switch eq "0209") {
		# Response to friend request
		my $type = unpack("C1",substr($msg, 2, 1));
		my $name = unpack("Z24", substr($msg, 12, 24));
		if ($type) {
			message "$name rejected to be your friend\n";
		} else {
			my $ID = @friendsID;
			binAdd(\@friendsID, $ID);
			$friends{$ID}{'accountID'} = substr($msg, 4, 4);
			$friends{$ID}{'charID'} = substr($msg, 8, 4);
			$friends{$ID}{'name'} = $name;
			$friends{$ID}{'online'} = 1;
			message "$name is now your friend\n";
		}

	} elsif ($switch eq "020A") {
		# Friend removed
		my $friendAccountID = substr($msg, 2, 4);
		my $friendCharID = substr($msg, 6, 4);
		for (my $i = 0; $i < @friendsID; $i++) {
			if ($friends{$i}{'accountID'} eq $friendAccountID && $friends{$i}{'charID'} eq $friendCharID) {
				message "$friends{$i}{'name'} is no longer your friend\n";
				binRemove(\@friendsID, $i);
				delete $friends{$i};
				last;
			}
		}

	} elsif ($switch eq "00CA") {
		my $fail = unpack("x2 C1", $msg);

		if ($fail == 0) {
			message "Buy completed.\n", "success";
		} elsif ($fail == 1) {
			error "Buy failed (insufficient zeny).\n";
		} elsif ($fail == 2) {
			error "Buy failed (insufficient inventory capacity).\n";
		} else {
			error "Buy failed (failure code $fail).\n";
		}

	} elsif ($switch eq '023A') {
		my $flag = unpack("v1", substr($msg, 2, 2));
		if ($flag == 0) {
			message "Please enter a new storage password:\n";
		} elsif ($flag == 1) {

			while ($config{storageAuto_password} eq '' && !$quit) {
				message "Please enter your storage password:\n";
				my $input = $interface->getInput(-1);
				if ($input ne '') {
					configModify('storageAuto_password', $input, 1);
					message "Storage password set to: $input\n", "success";
					last;
				}
			}
			return if ($quit);

			#my @key = $config{storageEncryptKey} =~ /(.+)[, ]+(.+)[, ]+(.+)[, ]+(.+)[, ]+(.+)[, ]+(.+)[, ]+(.+)[, ]+(.+)/;
			my @key = split /[, ]+/, $config{storageEncryptKey};
			if (!@key) {
				# Default key for mRO and pRO
				@key = ('0x050B6F79', '0x0202C179', '0x00E20120', '0x04FA43E3', '0x0179B6C8', '0x05973DF2', '0x07D8D6B', '0x08CB9ED9');
				#error "Unable to send storage password. You must set the 'storageEncryptKey' option in config.txt or servers.txt.\n";
				#return;
			}

			my $crypton = new Utils::Crypton(pack("V*", @key), 32);
			my $num = $config{storageAuto_password};
			$num = sprintf("%d%08d", length($num), $num);
			my $ciphertextBlock = $crypton->encrypt(pack("V*", $num, 0, 0, 0));
			sendStoragePassword($ciphertextBlock, 3);

		} else {
			message "Storage password: unknown flag $flag\n";
		}

	} elsif ($switch eq '023C') {
		my $type = unpack("v1", substr($msg, 2, 2));
		my $val = unpack("v1", substr($msg, 4, 2));

		if ($type == 4) {
			message "Successfully changed storage password.\n", "success";
		} elsif ($type == 5) {
			error "Error: Incorrect storage password.\n";
		} elsif ($type == 6) {
			message "Successfully entered storage password.\n", "success";
		} else {
			message "Storage password: unknown type $args->{type}\n";
		}

		# $args->{val}
		# unknown, what is this for?

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
		
		if ((exists $ai_v{master} && distance(\%master, $ai_v{master}) > 15)
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
		if ((($type && mon_control($monster->{name})->{attack_auto} == 2) || 
		    $monster->{dmgToYou} || $monster->{missedYou} ||
			($party && ($monster->{dmgToParty} || $monster->{missedToParty} || $monster->{dmgFromParty})))
		  && timeOut($monster->{attack_failed}, $timeout{ai_attack_unfail}{timeout})) {

			if ($wantArray) {
				# Function is called in array context
				push @agMonsters, $_;

			} else {
				# Function is called in scalar context
				if (mon_control($monster->{name})->{weight} > 0) {
					$num += mon_control($monster->{name})->{weight};
				} elsif (mon_control($monster->{name})->{weight} != -1) {
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
		if ($monsters{$_}{dmgToPlayer}{$ID} > 0 || $monsters{$_}{missedToPlayer}{$ID} > 0 || $monsters{$_}{dmgFromPlayer}{$ID} > 0 || $monsters{$_}{missedFromPlayer}{$ID} > 0) {
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

	unless ($r_args->{openlist} && %{$r_args->{openlist}}) {
		$r_args->{done} = 1;
		$r_args->{found} = '';
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
					($arg{dest_map}, $arg{dest_pos}{x}, $arg{dest_pos}{y}) = split(' ', $to);
					$arg{'walk'} = $$r_args{'closelist'}{$this}{'walk'};
					$arg{'zenny'} = $$r_args{'closelist'}{$this}{'zenny'};
					$arg{'steps'} = $portals_lut{$from}{'dest'}{$to}{'steps'};
					unshift @{$$r_args{'mapSolution'}},\%arg;
					$this = $$r_args{'closelist'}{$this}{'parent'};
				}
				return;
			} elsif ( ai_route_getRoute(\@{$$r_args{'solution'}}, $$r_args{'dest'}{'field'}, $portals_lut{$portal}{'dest'}{$dest}, $$r_args{'dest'}{'pos'}) ) {
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
				my $destID = $subchild;
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
	$args{notifyUponArrival} = $param{notifyUponArrival} if exists $param{notifyUponArrival};
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
	for (my $i = 0; $i < @{$char->{inventory}}; $i++) {
		next if (!$char->{inventory}[$i] || !%{$char->{inventory}[$i]} || $char->{inventory}[$i]{equipped});
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

	if (!ai_getSkillUseType($skill->handle)) {
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
	return 0 if ($char->{skills}{NV_BASIC}{lv} < 6);
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
		whenDone => shift,
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
	$args{timeout} = $timeout{ai_cartAuto} ? $timeout{ai_cartAuto}{timeout} : 0.15;
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
	$args{timeout} = $timeout{ai_cartAuto} ? $timeout{ai_cartAuto}{timeout} : 0.15;
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

	Plugins::callHook('attack_start', {ID => $ID});

	#Mod Start
	AUTOEQUIP: {
		my $i = 0;
		my $Lequip = 0;
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

				if ($Leq ne "" && !$chars[$config{'char'}]{'inventory'}[$Leq]{'equipped'}){ 
					message "Auto Equiping [L] :".$config{"autoSwitch_$i"."_leftHand"}." ($Leq)\n", "equip";
					$Lequip = 1;
				}
				if ($Req ne "" && !$chars[$config{'char'}]{'inventory'}[$Req]{'equipped'} || $config{"autoSwitch_$i"."_rightHand"} eq "[NONE]") {
					$Ldef = findLastIndex(\@{$chars[$config{'char'}]{'inventory'}}, "equipped",32);
					if ($Ldef eq ""){
						$Ldef = findLastIndex(\@{$chars[$config{'char'}]{'inventory'}}, "equipped",2);
						$Ldef = findLastIndex(\@{$chars[$config{'char'}]{'inventory'}}, "equipped",34) if($Ldef eq "");
						sendUnequip(\$remote_socket,$chars[$config{'char'}]{'inventory'}[$Ldef]{'index'}) if($Ldef ne "");
					}

					$Rdef = findIndex(\@{$chars[$config{'char'}]{'inventory'}}, "equipped",34);
					$Rdef = findIndex(\@{$chars[$config{'char'}]{'inventory'}}, "equipped",2) if($Rdef eq "");
					#Debug for 2hand Quicken and Bare Hand attack with 2hand weapon
					if((!whenStatusActive("Twohand Quicken, Adrenaline, Spear Quicken") || $config{"autoSwitch_$i"."_rightHand"} eq "[NONE]") && $Rdef ne "" && $Rdef ne $Ldef){
						sendUnequip(\$remote_socket,$chars[$config{'char'}]{'inventory'}[$Rdef]{'index'});
					}
					if ($Req eq $Leq) {
						for ($j=0; $j < @{$chars[$config{'char'}]{'inventory'}};$j++) {
							next if (!$char->{inventory}[$j] || !%{$char->{inventory}[$j]});
							if ($chars[$config{'char'}]{'inventory'}[$j]{'name'} eq $config{"autoSwitch_$i"."_rightHand"} && $j != $Leq) {
								$Req = $j;
								last;
							}
						}
					}
					if ($config{"autoSwitch_$i"."_rightHand"} ne "[NONE]") {
						message "Auto Equiping [R] :".$config{"autoSwitch_$i"."_rightHand"}."($Req)\n", "equip"; 
						sendEquip(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$Req]{'index'},$chars[$config{'char'}]{'inventory'}[$Req]{'type_equip'});
						if ($Lequip==0){
							if ($config{'autoSwitch_default_leftHand'}) { 
								$Leq = findIndexString_lc(\@{$chars[$config{'char'}]{'inventory'}}, "name", $config{'autoSwitch_default_leftHand'});
								$Lequip = 1;
							}
						}
					}
				}
				if ($Lequip == 1){
					sendEquip(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$Leq]{'index'},$chars[$config{'char'}]{'inventory'}[$Leq]{'type_equip'}) if ($Leq ne ""); 
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
		$Lequip = 0;
		$Leq = "";
		$Req = findIndexString_lc(\@{$chars[$config{'char'}]{'inventory'}}, "name", $config{'autoSwitch_default_rightHand'}); 
		if ($config{'autoSwitch_default_leftHand'}) { 
			$Leq = findIndexString_lc(\@{$chars[$config{'char'}]{'inventory'}}, "name", $config{'autoSwitch_default_leftHand'});
			if($Leq ne "" && !$chars[$config{'char'}]{'inventory'}[$Leq]{'equipped'}){
				message "Auto equiping default [L] :".$config{'autoSwitch_default_leftHand'}."\n", "equip";
				$Lequip=1;
			}
		}
		if ($config{'autoSwitch_default_rightHand'}) { 
			#$Req = findIndexString_lc(\@{$chars[$config{'char'}]{'inventory'}}, "name", $config{'autoSwitch_default_rightHand'}); 
			if($Req ne "" && !$chars[$config{'char'}]{'inventory'}[$Req]{'equipped'}) {
				$Ldef = findLastIndex(\@{$chars[$config{'char'}]{'inventory'}}, "equipped",32);
				if ($Ldef eq ""){
					$Ldef = findLastIndex(\@{$chars[$config{'char'}]{'inventory'}}, "equipped",2);
					$Ldef = findLastIndex(\@{$chars[$config{'char'}]{'inventory'}}, "equipped",34) if($Ldef eq "");
					if($Ldef ne "" && $chars[$config{'char'}]{'inventory'}[$Ldef]{'equipped'}) {
						sendUnequip(\$remote_socket,$chars[$config{'char'}]{'inventory'}[$Ldef]{'index'});
						$Lequip=1;
					}
				}

				$Rdef = findIndex(\@{$chars[$config{'char'}]{'inventory'}}, "equipped",34);
				$Rdef = findIndex(\@{$chars[$config{'char'}]{'inventory'}}, "equipped",2) if($Rdef eq "");
				sendUnequip(\$remote_socket,$chars[$config{'char'}]{'inventory'}[$Rdef]{'index'}) if($Rdef ne "" && $chars[$config{'char'}]{'inventory'}[$Rdef]{'equipped'} && $Rdef ne $Ldef);
				message "Auto equiping default [R] :".$config{'autoSwitch_default_rightHand'}."\n", "equip"; 
				sendEquip(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$Req]{'index'},$chars[$config{'char'}]{'inventory'}[$Req]{'type_equip'});
			}
		}
		if ($Lequip == 1){
			sendEquip(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$Leq]{'index'},$chars[$config{'char'}]{'inventory'}[$Leq]{'type_equip'}) if ($Leq ne ""); ;
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

sub sit {
	$timeout{ai_sit_wait}{time} = time;
	$timeout{ai_sit}{time} = time;

	AI::clear("sitting", "standing");
	if ($char->{skills}{NV_BASIC}{lv} >= 3) {
		AI::queue("sitting");
		sendSit(\$remote_socket);
		look($config{sitAuto_look}) if (defined $config{sitAuto_look});
	}
}

sub stand {
	$timeout{ai_stand_wait}{time} = time;
	$timeout{ai_sit}{time} = time;

	AI::clear("sitting", "standing");
	if ($char->{skills}{NV_BASIC}{lv} >= 3) {
		sendStand(\$remote_socket);
		AI::queue("standing");
	}
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

##
# getField(name, r_field)
# name: the name of the field you want to load.
# r_field: reference to a hash, in which information about the field is stored.
# Returns: 1 on success, 0 on failure.
#
# Load a field (.fld) file. This function also loads an associated .dist file
# (the distance map file), which is used by pathfinding (for wall avoidance support).
# If the associated .dist file does not exist, it will be created.
#
# The r_field hash will contain the following keys:
# ~l
# - name: The name of the field. This is not always the same as baseName.
# - baseName: The name of the field, which is the base name of the file without the extension.
# - width: The field's width.
# - height: The field's height.
# - rawMap: The raw map data. Contains information about which blocks you can walk on (byte 0),
#    and which not (byte 1).
# - dstMap: The distance map data. Used by pathfinding.
# ~l~
sub getField {
	my ($name, $r_hash) = @_;
	my ($file, $dist_file);

	if ($name eq '') {
		error "Unable to load field file: no field name specified.\n";
		return 0;
	}

	undef %{$r_hash};
	$r_hash->{name} = $name;

	if ($masterServer && $masterServer->{"field_$name"}) {
		# Handle server-specific versions of the field.
		$file = "$Settings::def_field/" . $masterServer->{"field_$name"};
	} else {
		$file = "$Settings::def_field/$name.fld";
	}
	$file =~ s/\//\\/g if ($^O eq 'MSWin32');
	$dist_file = $file;

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
	$r_hash->{baseName} = $file;
	$r_hash->{baseName} =~ s/.*[\\\/]//;
	$r_hash->{baseName} =~ s/(.*)\..*/$1/;

	# Load the .fld file
	open FILE, "< $file";
	binmode(FILE);
	my $data;
	{
		local($/);
		$data = <FILE>;
		close FILE;
		@$r_hash{'width', 'height'} = unpack("S1 S1", substr($data, 0, 4, ''));
		$r_hash->{rawMap} = $data;
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
			$r_hash->{dstMap} = $dist_data;
		}
	}

	# The .dist file is not available; create it
	unless ($r_hash->{dstMap}) {
		$r_hash->{dstMap} = makeDistMap($r_hash->{rawMap}, $r_hash->{width}, $r_hash->{height});
		open FILE, "> $dist_file" or die "Could not write dist cache file: $!\n";
		binmode(FILE);
		print FILE pack("a2 S1", 'V#', 2);
		print FILE pack("S1 S1", @$r_hash{'width', 'height'});
		print FILE $r_hash->{dstMap};
		close FILE;
	}

	return 1;
}

sub getGatField {
	my $file = shift;
	my $r_hash = shift;
	my ($i, $data);
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

	# Track deltaHp
	#
	# A player's "deltaHp" initially starts at 0.
	# When he takes damage, the damage is subtracted from his deltaHp.
	# When he is healed, this amount is added to the deltaHp.
	# If the deltaHp becomes positive, it is reset to 0.
	#
	# Someone with a lot of negative deltaHp is probably in need of healing.
	# This allows us to intelligently heal non-party members.
	if (my $target = Actor::get($ID2)) {
		$target->{deltaHp} -= $damage;
		$target->{deltaHp} = 0 if $target->{deltaHp} > 0;
	}

	if ($ID1 eq $accountID) {
		if ($monsters{$ID2}) {
			# You attack monster
			$monsters{$ID2}{'dmgTo'} += $damage;
			$monsters{$ID2}{'dmgFromYou'} += $damage;
			$monsters{$ID2}{'numAtkFromYou'}++;
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
			if ($config{'teleportAuto_atkCount'} && $monsters{$ID2}{'numAtkFromYou'} >= $config{'teleportAuto_atkCount'}) {
				message "Teleporting after attacking a monster $config{'teleportAuto_atkCount'} times\n", "teleport";
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
				if (mon_control($monsters{$ID1}{'name'})->{'teleport_auto'} == 2){
					message "Teleporting due to attack from $monsters{$ID1}{'name'}\n", "teleport";
					$teleport = 1;
				} elsif ($config{'teleportAuto_deadly'} && $damage >= $chars[$config{'char'}]{'hp'} && !whenStatusActive("Hallucination")) {
					message "Next $damage dmg could kill you. Teleporting...\n", "teleport";
					$teleport = 1;
				} elsif ($config{'teleportAuto_maxDmg'} && $damage >= $config{'teleportAuto_maxDmg'} && !whenStatusActive("Hallucination") && !($config{'teleportAuto_maxDmgInLock'} && $field{'name'} eq $config{'lockMap'})) {
					message "$monsters{$ID1}{'name'} hit you for more than $config{'teleportAuto_maxDmg'} dmg. Teleporting...\n", "teleport";
					$teleport = 1;
				} elsif ($config{'teleportAuto_maxDmgInLock'} && $field{'name'} eq $config{'lockMap'} && $damage >= $config{'teleportAuto_maxDmgInLock'} && !whenStatusActive("Hallucination")) {
					message "$monsters{$ID1}{'name'} hit you for more than $config{'teleportAuto_maxDmgInLock'} dmg in lockMap. Teleporting...\n", "teleport";
					$teleport = 1;
				} elsif (AI::inQueue("sitAuto") && $config{'teleportAuto_attackedWhenSitting'} && $damage > 0) {
					message "$monsters{$ID1}{'name'} attacks you while you are sitting. Teleporting...\n", "teleport";
					$teleport = 1;
				} elsif ($config{'teleportAuto_totalDmg'} && $monsters{$ID1}{'dmgToYou'} >= $config{'teleportAuto_totalDmg'} && !whenStatusActive("Hallucination") && !($config{'teleportAuto_totalDmgInLock'} && $field{'name'} eq $config{'lockMap'})) {
					message "$monsters{$ID1}{'name'} hit you for a total of more than $config{'teleportAuto_totalDmg'} dmg. Teleporting...\n", "teleport";
					$teleport = 1;
				} elsif ($config{'teleportAuto_totalDmgInLock'} && $field{'name'} eq $config{'lockMap'} && $monsters{$ID1}{'dmgToYou'} >= $config{'teleportAuto_totalDmgInLock'} && !whenStatusActive("Hallucination")) {
					message "$monsters{$ID1}{'name'} hit you for a total of more than $config{'teleportAuto_totalDmgInLock'} dmg in lockMap. Teleporting...\n", "teleport";
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
			if (existsInList($config{tankersList}, $players{$ID2}{name}) ||
			    ($chars[$config{'char'}]{'party'} && %{$chars[$config{'char'}]{'party'}} && $chars[$config{'char'}]{'party'}{'users'}{$ID2} && %{$chars[$config{'char'}]{'party'}{'users'}{$ID2}})) {
				# Monster attacks party member
				$monsters{$ID1}{'dmgToParty'} += $damage;
				$monsters{$ID1}{'missedToParty'}++ if ($damage == 0);
			}
			$monsters{$ID1}{target} = $ID2;
			OpenKoreMod::updateDamageTables($monsters{$ID1}) if (defined &OpenKoreMod::updateDamageTables);
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

			if (existsInList($config{tankersList}, $players{$ID1}{name}) ||
			    ($chars[$config{'char'}]{'party'} && %{$chars[$config{'char'}]{'party'}} && $chars[$config{'char'}]{'party'}{'users'}{$ID1} && %{$chars[$config{'char'}]{'party'}{'users'}{$ID1}})) {
				$monsters{$ID2}{'dmgFromParty'} += $damage;
			}
			OpenKoreMod::updateDamageTables($monsters{$ID2}) if (defined &OpenKoreMod::updateDamageTables);
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
		next if ($playersID[$i] eq "");

		# Check whether this "GM" is on the ignore list
		# in order to prevent false matches
		my $statusGM = 1;
		my $j = 0;
		while (exists $config{"avoid_ignore_$j"}) {
			if (!$config{"avoid_ignore_$j"}) {
				$j++;
				next;
			}

			if ($players{$playersID[$i]}{name} eq $config{"avoid_ignore_$j"}) {
				$statusGM = 0;
				last;
			}
			$j++;
		}

		if ($statusGM && ($players{$playersID[$i]}{name} =~ /^([a-z]?ro)?-?(Sub)?-?\[?GM\]?/i || $players{$playersID[$i]}{name} =~ /$config{avoidGM_namePattern}/)) {
			my %args = (
				name => $players{$playersID[$i]}{name},
				ID => $playersID[$i]
			);
			Plugins::callHook('avoidGM_near', \%args);
			return 1 if ($args{return});

			my $msg = "GM $players{$playersID[$i]}{'name'} is nearby, ";
			if ($config{avoidGM_near} == 1) {
				# Mode 1: teleport & disconnect
				useTeleport(1);
				my $tmp = $config{avoidGM_reconnect};
				$msg .= "teleport & disconnect for $tmp seconds";
				$timeout_ex{master}{time} = time;
				$timeout_ex{master}{timeout} = $tmp;
				Network::disconnect(\$remote_socket);

			} elsif ($config{avoidGM_near} == 2) {
				# Mode 2: disconnect
				my $tmp = $config{avoidGM_reconnect};
				$msg .= "disconnect for $tmp seconds";
				$timeout_ex{master}{time} = time;
				$timeout_ex{master}{timeout} = $tmp;
				Network::disconnect(\$remote_socket);

			} elsif ($config{avoidGM_near} == 3) {
				# Mode 3: teleport
				useTeleport(1);
				$msg .= "teleporting";

			} elsif ($config{avoidGM_near} >= 4) {
				# Mode 4: respawn
				useTeleport(2);
				$msg .= "respawning";
			}

			warning "$msg\n";
			chatLog("k", "*** $msg ***\n");

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
	return if ($config{avoidList_inLockOnly} && $field{name} ne $config{lockMap});
	for (my $i = 0; $i < @playersID; $i++) {
		my $player = $players{$playersID[$i]};
		next if (!defined $player);

		my $avoidPlayer = $avoid{Players}{lc($player->{name})};
		my $avoidID = $avoid{ID}{$player->{nameID}};
		if (!$xkore && ( ($avoidPlayer && $avoidPlayer->{disconnect_on_sight}) || ($avoidID && $avoidID->{disconnect_on_sight}) )) {
			warning "$player->{name} ($player->{nameID}) is nearby, disconnecting...\n";
			chatLog("k", "*** Found $player->{name} ($player->{nameID}) nearby and disconnected ***\n");
			warning "Disconnect for $config{avoidList_reconnect} seconds...\n";
			$timeout_ex{master}{time} = time;
			$timeout_ex{master}{timeout} = $config{avoidList_reconnect};
			Network::disconnect(\$remote_socket);
			return 1;

		} elsif (($avoidPlayer && $avoidPlayer->{teleport_on_sight}) || ($avoidID && $avoidID->{$player->{nameID}}{teleport_on_sight})) {
			message "Teleporting to avoid player $player->{name} ($player->{nameID})\n", "teleport";
			chatLog("k", "*** Found $player->{name} ($player->{nameID}) nearby and teleported ***\n");
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
		$mapPortals{$portals_lut{$portal}{source}{map}}{$portal}{x} = $portals_lut{$portal}{source}{x};
		$mapPortals{$portals_lut{$portal}{source}{map}}{$portal}{y} = $portals_lut{$portal}{source}{y};
		foreach my $dest (keys %{$portals_lut{$portal}{dest}}) {
			next if $portals_lut{$portal}{dest}{$dest}{map} eq '';
			$mapSpawns{$portals_lut{$portal}{dest}{$dest}{map}}{$dest}{x} = $portals_lut{$portal}{dest}{$dest}{x};
			$mapSpawns{$portals_lut{$portal}{dest}{$dest}{map}}{$dest}{y} = $portals_lut{$portal}{dest}{$dest}{y};
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
					$missingMap{$map} = 1 if (!getField($map, \%field));
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

sub portalExists {
	my ($map, $r_pos) = @_;
	foreach (keys %portals_lut) {
		if ($portals_lut{$_}{source}{map} eq $map
		    && $portals_lut{$_}{source}{x} == $r_pos->{x}
		    && $portals_lut{$_}{source}{y} == $r_pos->{y}) {
			return $_;
		}       
	}       
	return; 
}   

sub portalExists2 {
	my ($src, $src_pos, $dest, $dest_pos) = @_;
	my $srcx = $src_pos->{x};
	my $srcy = $src_pos->{y};
	my $destx = $dest_pos->{x};
	my $desty = $dest_pos->{y};
	my $destID = "$dest $destx $desty";

	foreach (keys %portals_lut) {
		my $entry = $portals_lut{$_};
		if ($entry->{source}{map} eq $src
		 && $entry->{source}{pos}{x} == $srcx
		 && $entry->{source}{pos}{y} == $srcy
		 && $entry->{dest}{$destID}) {
			return $_;
		}
	}
	return;
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
	$totaldmg += $damage;
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
# Obsoleted by Actor module, don't use this!
sub getActorName {
	my $id = shift;

	if (!$id) {
		return 'Nothing';
	} elsif (my $item = $items{$id}) {
		return "Item $item->{name} ($item->{binID})";
	} else {
		my $hash = Actor::get($id);
		return $hash->nameString;
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
	my $use_lvl = shift;
	my $internal = shift;

	# for possible recursive calls
	if (!defined $internal) {
		$internal = $config{teleportAuto_useSkill};
	}

	# look if the character has the skill
	my $sk_lvl = 0;
	if ($char->{skills}{AL_TELEPORT}) {
		$sk_lvl = $char->{skills}{AL_TELEPORT}{lv};
	}

	# only if we want to use skill ?
	return if ($char->{muted});

	if ($sk_lvl > 0 && $internal > 0) {
		# We have the teleport skill, and should use it
		my $skill = new Skills(handle => 'AL_TELEPORT');
		if ($internal == 1 || ($internal == 2 && binSize(\@playersID))) {
			# Send skill use packet to appear legitimate
			sendSkillUse(\$remote_socket, $skill->id, $use_lvl, $accountID);
			undef $char->{permitSkill};
		}
		
		delete $ai_v{temp}{teleport};
		debug "Sending Teleport using Level $use_lvl\n", "useTeleport";
		if ($use_lvl == 1) {
			sendTeleport(\$remote_socket, "Random");
			return 1;
		} elsif ($use_lvl == 2) {
			# check for possible skill level abuse
			message "Using Teleport Skill Level 2 though we not have it !\n", "useTeleport" if ($sk_lvl == 1);

			# If saveMap is not set simply use a wrong .gat.
			# eAthena servers ignore it, but this trick doesn't work
			# on official servers.
			my $telemap = "prontera.gat";
			$telemap = "$config{saveMap}.gat" if ($config{saveMap} ne "");

			sendTeleport(\$remote_socket, $telemap);
			return 1;
		}
	}

	# else if $internal == 0 or $sk_lvl == 0
	# try to use item

	# could lead to problems if the ItemID would be different on some servers
	my $invIndex = findIndex($char->{inventory}, "nameID", $use_lvl + 600);
	if (defined $invIndex) {
		# We have Fly Wing/Butterfly Wing.
		# Don't spam the "use fly wing" packet, or we'll end up using too many wings.
		if (timeOut($timeout{ai_teleport})) {
			sendItemUse(\$remote_socket, $char->{inventory}[$invIndex]{index}, $accountID);
			$timeout{ai_teleport}{time} = time;
		}
		return 1;
	}

	# no item, but skill is still available
	if ( $sk_lvl > 0 ) {
		message "No Fly Wing or Butterfly Wing, fallback to Teleport Skill\n", "useTeleport";
		return useTeleport($use_lvl, 1);
	}

	# No skill and no wings; try to equip a Tele clip or something,
	# if equipAuto_#_onTeleport is set
	my $i = 0;
	while (exists $config{"equipAuto_$i"}) {
		if (!$config{"equipAuto_$i"}) {
			$i++;
			next;
		}

		if ($config{"equipAuto_${i}_onTeleport"}) {
			# it is safe to always set this value, because $ai_v{temp} is always cleared after teleport
			if (!$ai_v{temp}{teleport}{lv}) {
				debug "Equipping " . $config{"equipAuto_$i"} . " to teleport\n", "useTeleport";
				$ai_v{temp}{teleport}{lv} = $use_lvl;

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

	if ($use_lvl == 1) {
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

	# increment monsterSkill maxUses counter
	if ($monsters{$targetID}) {
		$monsters{$targetID}{skillUses}{$skill->handle}++;
	}

	# Set encore skill if applicable
	$char->{encoreSkill} = $skill if $targetID eq $accountID && $skillsEncore{$skill->handle};
}

sub setPartySkillTimer {
	my ($skillID, $targetID) = @_;
	my $skill = new Skills(id => $skillID);
	my $handle = $skill->handle; 

	# set partySkill target_time
	my $i = $targetTimeout{$targetID}{$handle};
	$ai_v{"partySkill_${i}_target_time"}{$targetID} = time if $i;
}

# Increment counter for monster being casted on
sub countCastOn {
	my ($sourceID, $targetID, $skillID, $x, $y) = @_;
	return unless defined $targetID;

	if ($monsters{$sourceID}) {
		if ($targetID eq $accountID) {
			$monsters{$sourceID}{'castOnToYou'}++;
		} elsif ($players{$targetID} && %{$players{$targetID}}) {
			$monsters{$sourceID}{'castOnToPlayer'}{$targetID}++;
		} elsif ($monsters{$targetID} && %{$monsters{$targetID}}) {
			$monsters{$sourceID}{'castOnToMonster'}{$targetID}++;
		}
	}

	if ($monsters{$targetID}) {
		if ($sourceID eq $accountID) {
			$monsters{$targetID}{'castOnByYou'}++;
		} elsif ($players{$sourceID} && %{$players{$sourceID}}) {
			$monsters{$targetID}{'castOnByPlayer'}{$sourceID}++;
		} elsif ($monsters{$sourceID} && %{$monsters{$sourceID}}) {
			$monsters{$targetID}{'castOnByMonster'}{$sourceID}++;
		}
	}
}

# return ID based on name if party member is online
sub findPartyUserID {
	if ($chars[$config{'char'}]{'party'} && %{$chars[$config{'char'}]{'party'}}) {
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
		if ($npcs_lut{$id} && %{$npcs_lut{$id}}) {
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
	return 'Unknown' unless defined($ID);
	return 'None' unless $ID;
	return $items_lut{$ID} || "Unknown #$ID";
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
		$prefix .= "$elementName " if ($elementName ne "");
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
	$display .= "BROKEN " if $item->{broken};
	$display .= "+$item->{upgrade} " if $item->{upgrade};
	$display .= $prefix if $prefix;
	$display .= $name;
	$display .= " [$suffix]" if $suffix;
	$display .= " [$numSlots]" if $numSlots;

	return $display;
}

sub checkSelfCondition {
	my $prefix = shift;

	return 0 if ($config{$prefix . "_disabled"} > 0);

	return 0 if $config{$prefix."_whenIdle"} && !AI::isIdle;

	if ($config{$prefix . "_hp"}) { 
		return 0 unless (inRange(percent_hp($char), $config{$prefix . "_hp"}));
	} elsif ($config{$prefix . "_hp_upper"}) { # backward compatibility with old config format
		return 0 unless (percent_hp($char) <= $config{$prefix . "_hp_upper"} && percent_hp($char) >= $config{$prefix . "_hp_lower"});
	}

	if ($config{$prefix . "_sp"}) { 
		return 0 unless (inRange(percent_sp($char), $config{$prefix . "_sp"}));
	} elsif ($config{$prefix . "_sp_upper"}) { # backward compatibility with old config format
		return 0 unless (percent_sp($char) <= $config{$prefix . "_sp_upper"} && percent_sp($char) >= $config{$prefix . "_sp_lower"});
	}

	# check skill use SP if this is a 'use skill' condition
	if ($prefix =~ /skill/i) {
		return 0 unless ($char->{sp} >= $skillsSP_lut{$skills_rlut{lc($config{$prefix})}}{$config{$prefix . "_lvl"}})
	}

	if (defined $config{$prefix . "_aggressives"}) {
		return 0 unless (inRange(scalar ai_getAggressives(), $config{$prefix . "_aggressives"}));
	} elsif ($config{$prefix . "_maxAggressives"}) { # backward compatibility with old config format
		return 0 unless ($config{$prefix . "_minAggressives"} <= ai_getAggressives());
		return 0 unless ($config{$prefix . "_maxAggressives"} >= ai_getAggressives());
	}

	if (defined $config{$prefix . "_partyAggressives"}) {
		return 0 unless (inRange(scalar ai_getAggressives(undef, 1), $config{$prefix . "_partyAggressives"}));
	}

	if ($config{$prefix . "_stopWhenHit"} > 0) { return 0 if (scalar ai_getMonstersAttacking($accountID)); }

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

	if ($config{$prefix . "_monsters"} && !($prefix =~ /skillSlot/i) && !($prefix =~ /ComboSlot/i)) {
		my $exists;
		foreach (ai_getAggressives()) {
			if (existsInList($config{$prefix . "_monsters"}, $monsters{$_}{name})) {
				$exists = 1;
				last;
			}
		}
		return 0 unless $exists;
	}

	if ($config{$prefix . "_defendMonsters"}) {
		my $exists;
		foreach (ai_getMonstersAttacking($accountID)) {
			if (existsInList($config{$prefix . "_defendMonsters"}, $monsters{$_}{name})) {
				$exists = 1;
				last;
			}
		}
		return 0 unless $exists;
	}

	if ($config{$prefix . "_notMonsters"} && !($prefix =~ /skillSlot/i) && !($prefix =~ /ComboSlot/i)) {
		my $exists;
		foreach (ai_getAggressives()) {
			if (existsInList($config{$prefix . "_notMonsters"}, $monsters{$_}{name})) {
				return 0;
			}
		}
	}

	if ($config{$prefix."_inInventory"}) {
		foreach my $input (split / *, */, $config{$prefix."_inInventory"}) {
			my ($item,$count) = $input =~ /(.*?)(\s+[><= 0-9]+)?$/;
			$count = '>0' if $count eq '';
			my $iX = findIndexString_lc($char->{inventory}, "name", $item);
 			return 0 if !inRange(!defined $iX ? 0 : $char->{inventory}[$iX]{amount}, $count);		}
	}

	if ($config{$prefix."_whenGround"}) {
		return 0 unless whenGroundStatus(calcPosition($char), $config{$prefix."_whenGround"});
	}
	if ($config{$prefix."_whenNotGround"}) {
		return 0 if whenGroundStatus(calcPosition($char), $config{$prefix."_whenNotGround"});
	}

	if ($config{$prefix."_whenPermitSkill"}) {
		return 0 unless $char->{permitSkill} &&
			$char->{permitSkill}->name eq $config{$prefix."_whenPermitSkill"};
	}

	if ($config{$prefix."_whenNotPermitSkill"}) {
		return 0 if $char->{permitSkill} &&
			$char->{permitSkill}->name eq $config{$prefix."_whenNotPermitSkill"};
	}

	if ($config{$prefix."_onlyWhenSafe"}) {
		return 0 if binSize(\@playersID);
	}

	my $pos = calcPosition($char);
	return 0 if $config{$prefix."_whenWater"} &&
		!checkFieldWater(\%field, $pos->{x}, $pos->{y});

	return 1;
}

sub checkPlayerCondition {
	my ($prefix, $id) = @_;

	my $player = $players{$id};

	if ($config{$prefix . "_timeout"}) { return 0 unless timeOut($ai_v{$prefix . "_time"}{$id}, $config{$prefix . "_timeout"}) }
	if ($config{$prefix . "_whenStatusActive"}) { return 0 unless (whenStatusActivePL($id, $config{$prefix . "_whenStatusActive"})); }
	if ($config{$prefix . "_whenStatusInactive"}) { return 0 if (whenStatusActivePL($id, $config{$prefix . "_whenStatusInactive"})); }
	if ($config{$prefix . "_notWhileSitting"} > 0) { return 0 if ($players{$id}{sitting}); }

	# we will have player HP info (only) if we are in the same party
	if ($chars[$config{char}]{party}{users}{$id}) {
		if ($config{$prefix . "_hp"}) { 
			return 0 unless (inRange(percent_hp($chars[$config{char}]{party}{users}{$id}), $config{$prefix . "_hp"}));
		} elsif ($config{$prefix . "Hp_upper"}) { # backward compatibility with old config format
			return 0 unless (percent_hp($chars[$config{char}]{party}{users}{$id}) <= $config{$prefix . "Hp_upper"});
			return 0 unless (percent_hp($chars[$config{char}]{party}{users}{$id}) >= $config{$prefix . "Hp_lower"});
		}
	}

	return 0 if $config{$prefix."_deltaHp"} && $players{$id}{deltaHp} > $config{$prefix."_deltaHp"};

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
		return 0 unless whenGroundStatus(calcPosition($players{$id}), $config{$prefix."_whenGround"});
	}
	if ($config{$prefix."_whenNotGround"}) {
		return 0 if whenGroundStatus(calcPosition($players{$id}), $config{$prefix."_whenNotGround"});
	}
	if ($config{$prefix."_dead"}) {
		return 0 if !$players{$id}{dead};
	}

	if ($config{$prefix."_whenWeaponEquipped"}) {
		return 0 unless $player->{weapon};
	}

	if ($config{$prefix."_whenShieldEquipped"}) {
		return 0 unless $player->{shield};
	}

	if ($config{$prefix."_isGuild"}) {
		return 0 unless ($player->{guild} && existsInList($config{$prefix . "_isGuild"}, $player->{guild}{name}));
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
		return 0 unless whenGroundStatus(calcPosition($monster), $config{$prefix."_whenGround"});
	}
	if ($config{$prefix."_whenNotGround"}) {
		return 0 if whenGroundStatus(calcPosition($monster), $config{$prefix."_whenNotGround"});
	}

	if ($config{$prefix."_dist"}) {
		return 0 unless inRange(distance(calcPosition($char), calcPosition($monster)), $config{$prefix."_dist"});
	}

	# This is only supposed to make sense for players,
	# but it has to be here for attackSkillSlot PVP to work
	if ($config{$prefix."_whenWeaponEquipped"}) {
		return 0 unless $monster->{weapon};
	}
	if ($config{$prefix."_whenShieldEquipped"}) {
		return 0 unless $monster->{shield};
	}

	my %args = (
		monster => $monster,
		prefix => $prefix,
		return => 1
	);

	Plugins::callHook('checkMonsterCondition', \%args);
	return $args{return};
}

##
# setStatus(ID, param1, param2, param3)
# ID: ID of a player or monster.
# param1: the state information of the object.
# param2: the ailment information of the object.
# param3: the "look" information of the object.
#
# Sets the state, ailment, and "look" statuses of the object.
# Does not include skillsstatus.txt items.
sub setStatus {
	my $ID = shift;
	my $param1 = shift;
	my $param2 = shift;
	my $param3 = shift;
	my $actorType;
	my $actor = getActorHash($ID, \$actorType);

	return if (!defined $actor);
	my $name = getActorName($ID);
	my $verbosity = ($actorType eq 'self') ? 1 : 2;
	my $are = ($actorType eq 'self') ? 'are' : 'is';
	my $have = ($actorType eq 'self') ? 'have' : 'has';

	foreach (keys %skillsState) {
		if ($param1 == $_) {
			if (!$actor->{statuses}{$skillsState{$_}}) {
				$actor->{statuses}{$skillsState{$_}} = 1;
				message "$name $are in $skillsState{$_} state\n", "parseMsg_statuslook", $verbosity;
			}
		} elsif ($actor->{statuses}{$skillsState{$_}}) {
			delete $actor->{statuses}{$skillsState{$_}};
			message "$name $are out of $skillsState{$_} state\n", "parseMsg_statuslook", $verbosity;
		}
	}

	foreach (keys %skillsAilments) {
		if (($param2 & $_) == $_) {
			if (!$actor->{statuses}{$skillsAilments{$_}}) {
				$actor->{statuses}{$skillsAilments{$_}} = 1;
				message "$name $have ailments: $skillsAilments{$_}\n", "parseMsg_statuslook", $verbosity;
			}
		} elsif ($actor->{statuses}{$skillsAilments{$_}}) {
			delete $actor->{statuses}{$skillsAilments{$_}};
			message "$name $are out of ailments: $skillsAilments{$_}\n", "parseMsg_statuslook", $verbosity;
		}
	}

	foreach (keys %skillsLooks) {
		if (($param3 & $_) == $_) {
			if (!$actor->{statuses}{$skillsLooks{$_}}) {
				$actor->{statuses}{$skillsLooks{$_}} = 1;
				debug "$name $have look: $skillsLooks{$_}\n", "parseMsg_statuslook", $verbosity;
			}
		} elsif ($actor->{statuses}{$skillsLooks{$_}}) {
			delete $actor->{statuses}{$skillsLooks{$_}};
			debug "$name $are out of look: $skillsLooks{$_}\n", "parseMsg_statuslook", $verbosity;
		}
	}

	# remove perfectly hidden objects
	if ($actor->{statuses}{'GM Perfect Hide'}) {
		if ($players{$ID}) {
			message "Remove perfectly hidden $actor\n";
			binRemove(\@playersID, $ID);
			objectRemoved('player', $ID, $players{$ID});
			delete $players{$ID};
		}
		if ($monsters{$ID}) {
			message "Remove perfectly hidden $actor\n";
			binRemove(\@monstersID, $ID);
			objectRemoved('monster', $ID, $monsters{$ID});
			delete $monsters{$ID};
		}
		# NPCs do this on purpose (who knows why)
		#if ($npcs{$ID}) {
		#	message "Remove perfectly hidden $actor\n";
		#	binRemove(\@npcsID, $ID);
		#	objectRemoved('npc', $ID, $npcs{$ID});
		#	delete $npcs{$ID};
		#}
	}
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
	shuffleArray(\@items) if ($config{shop_random});
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
