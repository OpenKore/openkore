# To run kore, execute openkore.pl instead.

#########################################################################
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
use Time::HiRes qw(time usleep);
use IO::Socket;
use Getopt::Long;
use Digest::MD5 qw(md5);
use Config;

#######################################
#INITIALIZE VARIABLES
#######################################

# The following sub sets up the random restart times governed by the config variables autoRestartSeed and autoRestartMin
# The restart time will be autoRestartMin + rand(autoRestartSeed)
# Saved to the config file just to make the code slightly cleaner (trust me, the old code was ugly)
sub initRandomRestart {
	if ($config{'autoRestart'}) {
		my $autoRestart = $config{'autoRestartMin'} + int(rand $config{'autoRestartSeed'});
		print "Next restart in $autoRestart seconds.\n";
		configModify("autoRestart", $autoRestart, 1);
	}
}

sub initConnectVars {
	initMapChangeVars();
	undef @{$chars[$config{'char'}]{'inventory'}};
	undef %{$chars[$config{'char'}]{'skills'}};
	undef @skillsID;
}

sub initMapChangeVars {
	@portalsID_old = @portalsID;
	%portals_old = %portals;
	%{$chars_old[$config{'char'}]{'pos_to'}} = %{$chars[$config{'char'}]{'pos_to'}};
	undef $chars[$config{'char'}]{'sitting'};
	undef $chars[$config{'char'}]{'dead'};
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
	undef %players;
	undef %monsters;
	undef %portals;
	undef %items;
	undef %npcs;
	undef %spells;
	undef %incomingParty;
	undef $msg;
	undef %talk;
	undef $ai_v{'temp'};
#Cart List bugfix - chobit aska 20030128
	undef @cartID;
	undef %{$cart{'inventory'}};
	undef @venderItemList;
	undef $venderID;
	undef @venderListsID;
	undef $venderLists;
	undef %guild;
	undef %incomingGuild;

	$shopstarted = 0;
	$timeout{'ai_shop'}{'time'} = time;

	initOtherVars();
}

#Solos Start
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
# route error check variables
	undef $old_x;
	undef $old_y;
	undef $old_pos_x;
	undef $old_pos_y;
	undef $move_x;
	undef $move_y;
	undef $move_pos_x;
	undef $move_pos_y;
	$calcFrom_SameSpot = 0;
	$calcTo_SameSpot = 0;
	$moveFrom_SameSpot = 0;
	$moveTo_SameSpot = 0;
	$route_stuck = 0;
	$totalStuckCount = 0 if ($totalStuckCount > 10 || $totalStuckCount < 0);
}
#Solos End


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
sub checkConnection {
	return if ($config{'XKore'});

	if ($conState == 1 && !($remote_socket && $remote_socket->connected()) && timeOut(\%{$timeout_ex{'master'}}) && !$conState_tries) {
		print "Connecting to Master Server...\n";
		$shopstarted = 1;
		$conState_tries++;
		undef $msg;
		connection(\$remote_socket, $config{"master_host_$config{'master'}"},$config{"master_port_$config{'master'}"});

		if ($config{'secure'} >= 1) {
			print "Secure Login...\n";
			undef $secureLoginKey;
			sendMasterCodeRequest(\$remote_socket);
                } else {
			sendMasterLogin(\$remote_socket, $config{'username'}, $config{'password'});
		}

		$timeout{'master'}{'time'} = time;

	} elsif ($conState == 1 && $config{'secure'} >= 1 && $secureLoginKey ne "" && !timeOut(\%{$timeout{'master'}}) && $conState_tries) {
		print "Sending encoded password...\n";
		sendMasterSecureLogin(\$remote_socket, $config{'username'}, $config{'password'}, $secureLoginKey);
		undef $secureLoginKey;

	} elsif ($conState == 1 && timeOut(\%{$timeout{'master'}}) && timeOut(\%{$timeout_ex{'master'}})) {
		print "Timeout on Master Server, reconnecting...\n";
		killConnection(\$remote_socket);
		undef $conState_tries;

	} elsif ($conState == 2 && !($remote_socket && $remote_socket->connected()) && $config{'server'} ne "" && !$conState_tries) {
		print "Connecting to Game Login Server...\n";
		$conState_tries++;
		connection(\$remote_socket, $servers[$config{'server'}]{'ip'},$servers[$config{'server'}]{'port'});
		sendGameLogin(\$remote_socket, $accountID, $sessionID, $accountSex);
		$timeout{'gamelogin'}{'time'} = time;

	} elsif ($conState == 2 && timeOut(\%{$timeout{'gamelogin'}}) && $config{'server'} ne "") {
		print "Timeout on Game Login Server, reconnecting...\n";
		$timeout_ex{'master'}{'time'} = time;
		$timeout_ex{'master'}{'timeout'} = $timeout{'reconnect'}{'timeout'};
		killConnection(\$remote_socket);
		undef $conState_tries;
		$conState = 1;

	} elsif ($conState == 3 && !($remote_socket && $remote_socket->connected()) && $config{'char'} ne "" && !$conState_tries) {
		print "Connecting to Character Select Server...\n";
		$conState_tries++;
		connection(\$remote_socket, $servers[$config{'server'}]{'ip'},$servers[$config{'server'}]{'port'});
		sendCharLogin(\$remote_socket, $config{'char'});
		$timeout{'charlogin'}{'time'} = time;

	} elsif ($conState == 3 && timeOut(\%{$timeout{'charlogin'}}) && $config{'char'} ne "") {
		print "Timeout on Character Select Server, reconnecting...\n";
		$timeout_ex{'master'}{'time'} = time;
		$timeout_ex{'master'}{'timeout'} = $timeout{'reconnect'}{'timeout'};
		killConnection(\$remote_socket);
		$conState = 1;
		undef $conState_tries;

	} elsif ($conState == 4 && !($remote_socket && $remote_socket->connected()) && !$conState_tries) {
		print "Connecting to Map Server...\n";
		$conState_tries++;
		initConnectVars();
		connection(\$remote_socket, $map_ip, $map_port);
		sendMapLogin(\$remote_socket, $accountID, $charID, $sessionID, $accountSex2);
		$timeout_ex{'master'}{'timeout'} = $timeout{'reconnect'}{'timeout'};
		$timeout{'maplogin'}{'time'} = time;

	} elsif ($conState == 4 && timeOut(\%{$timeout{'maplogin'}})) {
		print "Timeout on Map Server, connecting to Master Server...\n";
		$timeout_ex{'master'}{'time'} = time;
		$timeout_ex{'master'}{'timeout'} = $timeout{'reconnect'}{'timeout'};
		killConnection(\$remote_socket);
		$conState = 1;
		undef $conState_tries;

	} elsif ($conState == 5 && !($remote_socket && $remote_socket->connected())) {
		$conState = 1;
		undef $conState_tries;

	} elsif ($conState == 5 && timeOut(\%{$timeout{'play'}})) {
		print "Timeout on Map Server, connecting to Master Server...\n";
		$timeout_ex{'master'}{'time'} = time;
		$timeout_ex{'master'}{'timeout'} = $timeout{'reconnect'}{'timeout'};
		killConnection(\$remote_socket);
		$conState = 1;
		undef $conState_tries;
	}


	# This is where saving the random restart time to the config file makes it a little cleaner, only one simple if needed
	# The local variable $sleeptime is controlled by the same system as used in initRandomRestart() for the restart times
	# The only thing that may want changing here is the sleep and restart times being printed in minutes rather than seconds
	# However, as I'm sure we are all used to working in seconds ourselves, this can be changed come release (if at all)
	if ($config{'autoRestart'} && time - $KoreStartTime > $config{'autoRestart'} && $conState == 5 && $ai_seq[0] ne "attack") {
		print "\nAuto-restarting!!\n";

		if ($config{'autoRestartSleep'}) {
			my $sleeptime = $config{'autoSleepMin'} + int(rand $config{'autoSleepSeed'});
			$timeout_ex{'master'}{'timeout'} = $sleeptime;
			$sleeptime = $timeout{'reconnect'}{'timeout'} if ($sleeptime < $timeout{'reconnect'}{'timeout'});
			print "Sleeping for $sleeptime seconds\n";
		} else {
			$timeout_ex{'master'}{'timeout'} = $timeout{'reconnect'}{'timeout'};
		}

		$timeout_ex{'master'}{'time'} = time;
		$KoreStartTime = time + $timeout_ex{'master'}{'timeout'};
		killConnection(\$remote_socket);
		$conState = 1;
		undef $conState_tries;
		initRandomRestart();
	}
}


#######################################
#PARSE INPUT
#######################################


sub parseInput {
	my $input = shift;
	my $printType;
	$printType = shift if ($config{'XKore'});

	my ($arg1, $arg2, $switch);
	print "Echo: $input\n" if ($config{'debug'} >= 2);
	($switch) = $input =~ /^(\w*)/;

	if ($printType) {
		open(BUFFER, '>buffer');
		select(BUFFER);
		BUFFER->autoflush(0);
	}

#Check if in special state

	if (!$config{'XKore'} && $conState == 2 && $waitingForInput) {
		$config{'server'} = $input;
		$waitingForInput = 0;
		writeDataFileIntact($config_file, \%config);
	} elsif (!$config{'XKore'} && $conState == 3 && $waitingForInput) {
		$config{'char'} = $input;
		$waitingForInput = 0;
		writeDataFileIntact($config_file, \%config);
		sendCharLogin(\$remote_socket, $config{'char'});
		$timeout{'charlogin'}{'time'} = time;


#Parse command...ugh

	} elsif ($switch eq "a") {
		($arg1) = $input =~ /^[\s\S]*? (\w+)/;
		($arg2) = $input =~ /^[\s\S]*? [\s\S]*? (\d+)/;
		if ($arg1 =~ /^\d+$/ && $monstersID[$arg1] eq "") {
			print	"Error in function 'a' (Attack Monster)\n"
				,"Monster $arg1 does not exist.\n";
		} elsif ($arg1 =~ /^\d+$/) {
			$monsters{$monstersID[$arg1]}{'attackedByPlayer'} = 0;
			attack($monstersID[$arg1]);

		} elsif ($arg1 eq "no") {
			configModify("attackAuto", 1);
		
		} elsif ($arg1 eq "yes") {
			configModify("attackAuto", 2);

		} else {
			print	"Syntax Error in function 'a' (Attack Monster)\n"
				,"Usage: attack <monster # | no | yes >\n";
		}

	} elsif ($switch eq "ai") {
		if ($AI) {
			undef $AI;
			$AI_forcedOff = 1;
			print "AI turned off\n";
		} else {
			$AI = 1;
			undef $AI_forcedOff;
			print "AI turned on\n";
		}

	} elsif ($switch eq "aiv") {
		print "ai_seq = @ai_seq\n";
		if ($ai_seq_args[0]{'waitingForMapSolution'}) {
			print "waitingForMapSolution\n";
		}
		if ($ai_seq_args[0]{'waitingForSolution'}) {
			print "waitingForSolution\n";
		}
		if ($ai_seq_args[0]{'solution'}) {
			print "solution\n";
		}

	} elsif ($switch eq "al") {
		$~ = "ARTICLESLIST2";
		print "----------Items being sold in store------------\n";
		print "#  Name                                     Type         Qty     Price   Sold\n";		       

		my $i = 1;
		for ($number = 0; $number < @articles; $number++) {
			next if ($articles[$number] eq "");
			$display = $articles[$number]{'name'};
			if (!($articles[$number]{'identified'})) {
				$display = $display." -- Not Identified";
			}
			if ($articles[$number]{'card1'}) {
				$display = $display."[".$cards_lut{$articles[$number]{'card1'}}."]";
			}
			if ($articles[$number]{'card2'}) {
				$display = $display."[".$cards_lut{$articles[$number]{'card2'}}."]";
			}
			if ($articles[$number]{'card3'}) {
				$display = $display."[".$cards_lut{$articles[$number]{'card3'}}."]";
			}
			if ($articles[$number]{'card4'}) {
				$display = $display."[".$cards_lut{$articles[$number]{'card4'}}."]";
			}

			format ARTICLESLIST2 =
@< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<< @>>> @>>>>>>>z @>>>>>
$i $display $itemTypes_lut{$articles[$number]{'type'}} $articles[$number]{'quantity'} $articles[$number]{'price'} $articles[$number]{'sold'}
.
			write;
			$i++;
		}
		print "----------------------------------------------\n";
		print "You have earned $shopEarned"."z.\n";

	} elsif ($switch eq "as") {
		# Stop attacking monster
		my $index = binFind(\@ai_seq, "attack");
		if ($index ne "") {
			$monsters{$ai_seq_args[$index]{'ID'}}{'ignore'} = 1;
			sendAttackStop(\$remote_socket);
			print "Stopped attacking $monsters{$ai_seq_args[$index]{'ID'}}{'name'} ($monsters{$ai_seq_args[$index]{'ID'}}{'binID'})\n";
			aiRemove("attack");
		}

	} elsif ($switch eq "auth") {
		my ($arg1, $arg2) = $input =~ /^[\s\S]*? ([\s\S]*) ([\s\S]*?)$/;
		if ($arg1 eq "" || ($arg2 ne "1" && $arg2 ne "0")) {
			print	"Syntax Error in function 'auth' (Overall Authorize)\n"
				,"Usage: auth <username> <flag>\n";
		} else {
			auth($arg1, $arg2);
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
		
	} elsif ($switch eq "bestow") {
		my ($arg1) = $input =~ /^[\s\S]*? ([\s\S]*)/;
		if ($currentChatRoom eq "") {
			print	"Error in function 'bestow' (Bestow Admin in Chat)\n"
				,"You are not in a Chat Room.\n";
		} elsif ($arg1 eq "") {
			print	"Syntax Error in function 'bestow' (Bestow Admin in Chat)\n"
				,"Usage: bestow <user #>\n";
		} elsif ($currentChatRoomUsers[$arg1] eq "") {
			print	"Error in function 'bestow' (Bestow Admin in Chat)\n"
				,"Chat Room User $arg1 doesn't exist\n";
		} else {
			sendChatRoomBestow(\$remote_socket, $currentChatRoomUsers[$arg1]);
		}

	} elsif ($switch eq "buy") {
		my ($arg1) = $input =~ /^[\s\S]*? (\d+)/;
		my ($arg2) = $input =~ /^[\s\S]*? \d+ (\d+)$/;
		if ($arg1 eq "") {
			print	"Syntax Error in function 'buy' (Buy Store Item)\n"
				,"Usage: buy <item #> [<amount>]\n";
		} elsif ($storeList[$arg1] eq "") {
			print	"Error in function 'buy' (Buy Store Item)\n"
				,"Store Item $arg1 does not exist.\n";
		} else {
			if ($arg2 <= 0) {
				$arg2 = 1;
			}
			sendBuy(\$remote_socket, $storeList[$arg1]{'nameID'}, $arg2);
		}

	} elsif ($switch eq "c") {
		($arg1) = $input =~ /^[\s\S]*? ([\s\S]*)/;
		if ($arg1 eq "") {
			print	"Syntax Error in function 'c' (Chat)\n"
				,"Usage: c <message>\n";
		} else {
			sendMessage(\$remote_socket, "c", $arg1);
		}

	#Cart command - chobit andy 20030101
	} elsif ($switch eq "cart") {
		my ($arg1) = $input =~ /^[\s\S]*? (\w+)/;
		my ($arg2) = $input =~ /^[\s\S]*? \w+ (\d+)/;
		my ($arg3) = $input =~ /^[\s\S]*? \w+ \d+ (\d+)/;
		if ($arg1 eq "") {
			$~ = "CARTLIST";
			print "-------------Cart--------------\n";
			print "#  Name\n";
			
			for ($i=0; $i < @cartID; $i++) {
				next if ($cartID[$i] eq "");
				$display = "$cart{'inventory'}{$cartID[$i]}{'name'} x $cart{'inventory'}{$cartID[$i]}{'amount'}";
				format CARTLIST =
@< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$i $display
.
				write;
			}
			print "\nCapacity: " . int($cart{'items'}) . "/" . int($cart{'items_max'}) . "  Weight: " . int($cart{'weight'}) . "/" . int($cart{'weight_max'}) . "\n";
			print "-------------------------------\n";

		} elsif ($arg1 eq "add" && $arg2 =~ /\d+/ && $chars[$config{'char'}]{'inventory'}[$arg2] eq "") {
			print	"Error in function 'cart add' (Add Item to Cart)\n"
				,"Inventory Item $arg2 does not exist.\n";
		} elsif ($arg1 eq "add" && $arg2 =~ /\d+/) {
			if (!$arg3 || $arg3 > $chars[$config{'char'}]{'inventory'}[$arg2]{'amount'}) {
				$arg3 = $chars[$config{'char'}]{'inventory'}[$arg2]{'amount'};
			}
			sendCartAdd(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$arg2]{'index'}, $arg3);
		} elsif ($arg1 eq "add" && $arg2 eq "") {
			print	"Syntax Error in function 'cart add' (Add Item to Cart)\n"
				,"Usage: cart add <item #>\n";
		} elsif ($arg1 eq "get" && $arg2 =~ /\d+/ && !%{$cart{'inventory'}{$cartID[$arg2]}}) {
			print	"Error in function 'cart get' (Get Item from Cart)\n"
				,"Cart Item $arg2 does not exist.\n";
		} elsif ($arg1 eq "get" && $arg2 =~ /\d+/) {
			if (!$arg3 || $arg3 > $cart{'inventory'}{$cartID[$arg2]}{'amount'}) {
				$arg3 = $cart{'inventory'}{$cartID[$arg2]}{'amount'};
			}
			sendCartGet(\$remote_socket, $cart{'inventory'}{$cartID[$arg2]}{'index'}, $arg3);
		} elsif ($arg1 eq "get" && $arg2 eq "") {
			print	"Syntax Error in function 'cart get' (Get Item from Cart)\n"
				,"Usage: cart get <cart item #>\n";
		}

	} elsif ($switch eq "chat") {
		my ($replace, $title) = $input =~ /(^[\s\S]*? \"([\s\S]*?)\" ?)/;
		my $qm = quotemeta $replace;
		my $input =~ s/$qm//;
		my @arg = split / /, $input;
		if ($title eq "") {
			print	"Syntax Error in function 'chat' (Create Chat Room)\n"
				,qq~Usage: chat "<title>" [<limit #> <public flag> <password>]\n~;
		} elsif ($currentChatRoom ne "") {
			print	"Error in function 'chat' (Create Chat Room)\n"
				,"You are already in a chat room.\n";
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

	} elsif ($switch eq "chatmod") {
		my ($replace, $title) = $input =~ /(^[\s\S]*? \"([\s\S]*?)\" ?)/;
		my $qm = quotemeta $replace;
		my $input =~ s/$qm//;
		my @arg = split / /, $input;
		if ($title eq "") {
			print	"Syntax Error in function 'chatmod' (Modify Chat Room)\n"
				,qq~Usage: chatmod "<title>" [<limit #> <public flag> <password>]\n~;
		} else {
			if ($arg[0] eq "") {
				$arg[0] = 20;
			}
			if ($arg[1] eq "") {
				$arg[1] = 1;
			}
			sendChatRoomChange(\$remote_socket, $title, $arg[0], $arg[1], $arg[2]);
		}

	} elsif ($switch eq "chist") { 
		(open(CHAT, $chat_file)) or print("Unable to open chat.txt\n");
		@chat = <CHAT>;
		close(CHAT);
		print "------ Chat History --------------------\n";
		for ($i = @chat - 5; $i < @chat;$i++) {
			print $chat[$i];
		}
		print "----------------------------------------\n";

	} elsif ($switch eq "cil") { 
		itemLog_clear();
		print qq~Item log cleared.\n~; 

	} elsif ($switch eq "cl") { 
		chatLog_clear();
		print qq~Chat log cleared.\n~; 

	} elsif ($switch eq "closeshop") {
		sendCloseShop(\$remote_socket);

	} elsif ($switch eq "conf") {
		my ($arg1) = $input =~ /^[\s\S]*? (\w+)/;
		my ($arg2) = $input =~ /^[\s\S]*? \w+ ([\s\S]+)$/;
		@{$ai_v{'temp'}{'conf'}} = keys %config;
		if ($arg1 eq "") {
			print	"Syntax Error in function 'conf' (Config Modify)\n"
				,"Usage: conf <variable> [<value>]\n";
		} elsif (binFind(\@{$ai_v{'temp'}{'conf'}}, $arg1) eq "") {
			print "Config variable $arg1 doesn't exist\n";
		} elsif ($arg2 eq "value") {
			print "Config '$arg1' is $config{$arg1}\n";
		} else {
			configModify($arg1, $arg2);
		}

#kokal monster count code
	} elsif ($switch eq "count") { 
       		$~ = "MONKILLED"; 
        	print "-[ Monster Count ]--------------------------------\n"; 
        	print "#   ID   Name                Count\n"; 
       		my $i = 0; 
        	while ($monsters_Killed[$i]) { 
			format MONKILLED = 
@<< @<<<< @<<<<<<<<<<<<<       @<<< 
$i $monsters_Killed[$i]{'nameID'} $monsters_Killed[$i]{'name'} $monsters_Killed[$i]{'count'} 
. 
            		write;       
            		$i++;    
      		} 
      		print "--------------------------------------------------\n";
#end of kokal monster count code

#non-functional item count code
	} elsif ($switch eq "icount") {
		$~ = "IPICKED";
		print "-[ Item Count ]--------------------------------\n";
		print "#   ID   Name                Count\n";
		my $i = 0;
		while ($pickup_count[$i]) {
			format IPICKED =
@<< @<<<< @<<<<<<<<<<<<<       @<<<
$i $pickup_count[$i]{'nameID'} $pickup_count[$i]{'name'} $pickup_count[$i]{'count'}
.
			write;      
			$i++;   
		}
		print "--------------------------------------------------\n"; 
#end of non-functional item count code

	} elsif ($switch eq "cri") {
		if ($currentChatRoom eq "") {
			print "There is no chat room info - you are not in a chat room\n";
		} else {
			$~ = "CRI";
			print	"-----------Chat Room Info-----------\n"
				,"Title                     Users   Public/Private\n";
			my $public_string = ($chatRooms{$currentChatRoom}{'public'}) ? "Public" : "Private";
			my $limit_string = $chatRooms{$currentChatRoom}{'num_users'}."/".$chatRooms{$currentChatRoom}{'limit'};
			format CRI =
@<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<< @<<<<<<<<<
$chatRooms{$currentChatRoom}{'title'} $limit_string $public_string
.
			write;
			$~ = "CRIUSERS";
			print	"-- Users --\n";
			for ($i = 0; $i < @currentChatRoomUsers; $i++) {
				next if ($currentChatRoomUsers[$i] eq "");
				my $user_string = $currentChatRoomUsers[$i];
				my $admin_string = ($chatRooms{$currentChatRoom}{'users'}{$currentChatRoomUsers[$i]} > 1) ? "(Admin)" : "";
				format CRIUSERS =
@<< @<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<
$i  $user_string               $admin_string
.
				write;
			}
			print "------------------------------------\n";
		}

	} elsif ($switch eq "crl") {
		$~ = "CRLIST";
		print	"-----------Chat Room List-----------\n"
			,"#   Title                     Owner                Users   Public/Private\n";
		for ($i = 0; $i < @chatRoomsID; $i++) {
			next if ($chatRoomsID[$i] eq "");
			$owner_string = ($chatRooms{$chatRoomsID[$i]}{'ownerID'} ne $accountID) ? $players{$chatRooms{$chatRoomsID[$i]}{'ownerID'}}{'name'} : $chars[$config{'char'}]{'name'};
			$public_string = ($chatRooms{$chatRoomsID[$i]}{'public'}) ? "Public" : "Private";
			$limit_string = $chatRooms{$chatRoomsID[$i]}{'num_users'}."/".$chatRooms{$chatRoomsID[$i]}{'limit'};
			format CRLIST = 
@<< @<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<          @<<<<<< @<<<<<<<<<
$i  $chatRooms{$chatRoomsID[$i]}{'title'}          $owner_string $limit_string $public_string
.
			write;
		}
		print "------------------------------------\n";

#Solos Start
	} elsif ($switch eq "vl") {
		$~ = "VLIST";
		print	 "-----------Vender List-----------\n"
				,"#   Title                                Owner\n";
		for ($i = 0; $i < @venderListsID; $i++) {
			next if ($venderListsID[$i] eq "");
			$owner_string = ($venderListsID[$i] ne $accountID) ? $players{$venderListsID[$i]}{'name'} : $chars[$config{'char'}]{'name'};
			format VLIST = 
@<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<<<<<<<<
$i  $venderLists{$venderListsID[$i]}{'title'} $owner_string
.
			write;
		}
		print	"----------------------------------\n";

	} elsif ($switch eq "vender") {
		($arg1) = $input =~ /^.*? (\d+)/;
		($arg2) = $input =~ /^.*? \d+ (\d+)/;
		($arg3) = $input =~ /^.*? \d+ \d+ (\d+)/;
		if ($arg1 eq "") {
			print	 "Error in function 'vender' (Vender Shop)\n"
					,"Usage: vender <vender # | end> [<item #> <amount>]\n";
		} elsif ($arg1 eq "end") {
			undef @venderItemList;
			undef $venderID;
		} elsif ($venderListsID[$arg1] eq "") {
			print	 "Error in function 'vender' (Vender Shop)\n"
					,"Vender $arg1 does not exist.\n";
		} elsif ($arg2 eq "") {
			sendEnteringVender(\$remote_socket, $venderListsID[$arg1]);
		} elsif ($venderListsID[$arg1] ne $venderID) {
			print	 "Error in function 'vender' (Vender Shop)\n"
					,"Vender ID is wrong.\n";
		} else {
			if ($arg3 <= 0) {
				$arg3 = 1;
			}
			sendBuyVender(\$remote_socket, $arg2, $arg3);
		}
#Solos End
	} elsif ($switch eq "deal") {
		@arg = split / /, $input;
		shift @arg;
		if (%currentDeal && $arg[0] =~ /\d+/) {
			print	"Error in function 'deal' (Deal a Player)\n"
				,"You are already in a deal\n";
		} elsif (%incomingDeal && $arg[0] =~ /\d+/) {
			print	"Error in function 'deal' (Deal a Player)\n"
				,"You must first cancel the incoming deal\n";
		} elsif ($arg[0] =~ /\d+/ && !$playersID[$arg[0]]) {
			print	"Error in function 'deal' (Deal a Player)\n"
				,"Player $arg[0] does not exist\n";
		} elsif ($arg[0] =~ /\d+/) {
			$outgoingDeal{'ID'} = $playersID[$arg[0]];
			sendDeal(\$remote_socket, $playersID[$arg[0]]);


		} elsif ($arg[0] eq "no" && !%incomingDeal && !%outgoingDeal && !%currentDeal) {
			print	"Error in function 'deal' (Deal a Player)\n"
				,"There is no incoming/current deal to cancel\n";
		} elsif ($arg[0] eq "no" && (%incomingDeal || %outgoingDeal)) {
			sendDealCancel(\$remote_socket);
		} elsif ($arg[0] eq "no" && %currentDeal) {
			sendCurrentDealCancel(\$remote_socket);


		} elsif ($arg[0] eq "" && !%incomingDeal && !%currentDeal) {
			print	"Error in function 'deal' (Deal a Player)\n"
				,"There is no deal to accept\n";
		} elsif ($arg[0] eq "" && $currentDeal{'you_finalize'} && !$currentDeal{'other_finalize'}) {
			print	"Error in function 'deal' (Deal a Player)\n"
				,"Cannot make the trade - $currentDeal{'name'} has not finalized\n";
		} elsif ($arg[0] eq "" && $currentDeal{'final'}) {
			print	"Error in function 'deal' (Deal a Player)\n"
				,"You already accepted the final deal\n";
		} elsif ($arg[0] eq "" && %incomingDeal) {
			sendDealAccept(\$remote_socket);
		} elsif ($arg[0] eq "" && $currentDeal{'you_finalize'} && $currentDeal{'other_finalize'}) {
			sendDealTrade(\$remote_socket);
			$currentDeal{'final'} = 1;
			print "You accepted the final Deal\n";
		} elsif ($arg[0] eq "" && %currentDeal) {
			sendDealAddItem(\$remote_socket, 0, $currentDeal{'you_zenny'});
			sendDealFinalize(\$remote_socket);
			

		} elsif ($arg[0] eq "add" && !%currentDeal) {
			print	"Error in function 'deal_add' (Add Item to Deal)\n"
				,"No deal in progress\n";
		} elsif ($arg[0] eq "add" && $currentDeal{'you_finalize'}) {
			print	"Error in function 'deal_add' (Add Item to Deal)\n"
				,"Can't add any Items - You already finalized the deal\n";
		} elsif ($arg[0] eq "add" && $arg[1] =~ /\d+/ && !%{$chars[$config{'char'}]{'inventory'}[$arg[1]]}) {
			print	"Error in function 'deal_add' (Add Item to Deal)\n"
				,"Inventory Item $arg[1] does not exist.\n";
		} elsif ($arg[0] eq "add" && $arg[2] && $arg[2] !~ /\d+/) {
			print	"Error in function 'deal_add' (Add Item to Deal)\n"
				,"Amount must either be a number, or not specified.\n";
		} elsif ($arg[0] eq "add" && $arg[1] =~ /\d+/) {
			if (scalar(keys %{$currentDeal{'you'}}) < 10) {
				if (!$arg[2] || $arg[2] > $chars[$config{'char'}]{'inventory'}[$arg[1]]{'amount'}) {
					$arg[2] = $chars[$config{'char'}]{'inventory'}[$arg[1]]{'amount'};
				}
				$currentDeal{'lastItemAmount'} = $arg[2];
				sendDealAddItem(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$arg[1]]{'index'}, $arg[2]);
			} else {
				print "You can't add any more items to the deal\n";
			}
		} elsif ($arg[0] eq "add" && $arg[1] eq "z") {
			if (!$arg[2] || $arg[2] > $chars[$config{'char'}]{'zenny'}) {
				$arg[2] = $chars[$config{'char'}]{'zenny'};
			}
			$currentDeal{'you_zenny'} = $arg[2];
			print "You put forward $arg[2] z to Deal\n";

		} else {
			print	"Syntax Error in function 'deal' (Deal a player)\n"
				,"Usage: deal [<Player # | no | add>] [<item #>] [<amount>]\n";
		}

	} elsif ($switch eq "debug") {
		($arg1) = $input =~ /^[\s\S]*? (\d+)/;
		if ($arg1 eq "0") {
			configModify("debug", 0);
		} elsif ($arg1 eq "1") {
			configModify("debug", 1);
		} elsif ($arg1 eq "2") {
			configModify("debug", 2);
		}

	} elsif ($switch eq "dl") {
		if (!%currentDeal) {
			print "There is no deal list - You are not in a deal\n";

		} else {
			print	"-----------Current Deal-----------\n";
			$other_string = $currentDeal{'name'};
			$you_string = "You";
			if ($currentDeal{'other_finalize'}) {
				$other_string .= " - Finalized";
			}
			if ($currentDeal{'you_finalize'}) {
				$you_string .= " - Finalized";
			}
		
			$~ = "PREDLIST";
			format PREDLIST =
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<   @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$you_string                      $other_string
.
			write;
			$~ = "DLIST";
			undef @currentDealYou;
			undef @currentDealOther;
			foreach (keys %{$currentDeal{'you'}}) {
				push @currentDealYou, $_;
			}
			foreach (keys %{$currentDeal{'other'}}) {
				push @currentDealOther, $_;
			}
			$lastindex = @currentDealOther;
			$lastindex = @currentDealYou if (@currentDealYou > $lastindex);
			for ($i = 0; $i < $lastindex; $i++) {
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
				format DLIST =
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<   @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$display                         $display2
.
				write;
			}
			$you_string = ($currentDeal{'you_zenny'} ne "") ? $currentDeal{'you_zenny'} : 0;
			$other_string = ($currentDeal{'other_zenny'} ne "") ? $currentDeal{'other_zenny'} : 0;
			$~ = "DLISTSUF";
			format DLISTSUF =
Zenny: @<<<<<<<<<<<<<            Zenny: @<<<<<<<<<<<<<
$you_string                      $other_string
.
			write;
			print "----------------------------------\n";
		}


	} elsif ($switch eq "drop") {
		($arg1) = $input =~ /^[\s\S]*? (\d+)/;
		($arg2) = $input =~ /^[\s\S]*? \d+ (\d+)$/;
		if ($arg1 eq "") {
			print	"Syntax Error in function 'drop' (Drop Inventory Item)\n"
				,"Usage: drop <item #> [<amount>]\n";
		} elsif (!%{$chars[$config{'char'}]{'inventory'}[$arg1]}) {
			print	"Error in function 'drop' (Drop Inventory Item)\n"
				,"Inventory Item $arg1 does not exist.\n";
		} else {
			if (!$arg2 || $arg2 > $chars[$config{'char'}]{'inventory'}[$arg1]{'amount'}) {
				$arg2 = $chars[$config{'char'}]{'inventory'}[$arg1]{'amount'};
			}
			sendDrop(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$arg1]{'index'}, $arg2);
		}

	} elsif ($switch eq "dump") {
		dumpData($msg);
		quit();
#Solos Start
	} elsif ($switch eq "dumpnow") {
		dumpData($msg);
#Solos End
	} elsif ($switch eq "e") {
		($arg1) = $input =~ /^[\s\S]*? (\d+)/;
		if ($arg1 eq "" || $arg1 > 33 || $arg1 < 0) {
			print	"Syntax Error in function 'e' (Emotion)\n"
				,"Usage: e <emotion # (0-33)>\n";
		} else {
			sendEmotion(\$remote_socket, $arg1);
		}

	} elsif ($switch eq "eq") {
		($arg1) = $input =~ /^[\s\S]*? (\d+)/;
		($arg2) = $input =~ /^[\s\S]*? \d+ (\w+)/;
		if ($arg1 eq "") {
			print	"Syntax Error in function 'equip' (Equip Inventory Item)\n"
				,"Usage: equip <item #> [r]\n";
		} elsif (!%{$chars[$config{'char'}]{'inventory'}[$arg1]}) {
			print	"Error in function 'equip' (Equip Inventory Item)\n"
				,"Inventory Item $arg1 does not exist.\n";
		} elsif ($chars[$config{'char'}]{'inventory'}[$arg1]{'type_equip'} == 0) {
			print	"Error in function 'equip' (Equip Inventory Item)\n"
				,"Inventory Item $arg1 can't be equipped.\n";
		} else {
			if ($chars[$config{'char'}]{'inventory'}[$arg1]{'type_equip'} == 256
				|| $chars[$config{'char'}]{'inventory'}[$arg1]{'type_equip'} == 513) {
				sendEquip(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$arg1]{'index'}, 0, 1);
			} elsif ($chars[$config{'char'}]{'inventory'}[$arg1]{'type_equip'} == 512) {
				sendEquip(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$arg1]{'index'}, 0, 2);
			} elsif ($chars[$config{'char'}]{'inventory'}[$arg1]{'type_equip'} == 1) {
				sendEquip(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$arg1]{'index'}, 1, 0);
			} else {
				if ($arg2 eq "r") {
					sendEquip(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$arg1]{'index'}, 32, 0);
				} else {
					sendEquip(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$arg1]{'index'}, $chars[$config{'char'}]{'inventory'}[$arg1]{'type_equip'}, 0);
				}
			}
		}

	} elsif ($switch eq "follow") {
		($arg1) = $input =~ /^[\s\S]*? (\w+)/;
		if ($arg1 eq "") {
			print	"Syntax Error in function 'follow' (Follow Player)\n"
				,"Usage: follow <player #>\n";
		} elsif ($arg1 eq "stop") {
			aiRemove("follow");
			configModify("follow", 0);
		} elsif ($playersID[$arg1] eq "") {
			print	"Error in function 'follow' (Follow Player)\n"
				,"Player $arg1 does not exist.\n";
		} else {
			ai_follow($players{$playersID[$arg1]}{'name'});
			configModify("follow", 1);
			configModify("followTarget", $players{$playersID[$arg1]}{'name'});
		}

	#Guild Chat - chobit andy 20030101
	} elsif ($switch eq "g") {
		my ($arg1) = $input =~ /^[\s\S]*? ([\s\S]*)/;
		if ($arg1 eq "") {
			print "Syntax Error in function 'g' (Guild Chat)\n"
				,"Usage: g <message>\n";
		} else {
			sendMessage(\$remote_socket, "g", $arg1);
		}

	} elsif ($switch eq "guild") {
		my ($arg1) = $input =~ /^.*? (\w+)/;
		if ($arg1 eq "info") {
			print "---------- Guild Information ----------\n";
			$~ = "GUILD";
			format GUILD =
Name    : @<<<<<<<<<<<<<<<<<<<<<<<<
$guild{'name'}
Lv      : @<<
$guild{'lvl'}
Exp     : @>>>>>>>>>/@<<<<<<<<<<
$guild{'exp'} $guild{'next_exp'}
Master  : @<<<<<<<<<<<<<<<<<<<<<<<<
$guild{'master'}
Connect : @>>/@<<
$guild{'conMember'} $guild{'maxMember'}
.
			write;
			print "---------------------------------------\n";

		} elsif ($arg1 eq "member") {
			print "------------ Guild  Member ------------\n";
			print "#  Name                       Job        Lv  Title                       Online\n";
			my ($i, $name, $job, $lvl, $title, $online);

			$~ = "GM";
			format GM = 
@< @<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<< @>  @<<<<<<<<<<<<<<<<<<<<<<<<<< @<<
$i  $name                    $job       $lvl $title                   $online
.

			my $count = @{$guild{'member'}};
			for ($i = 0; $i < $count; $i++) {
				$name  = $guild{'member'}[$i]{'name'};
				next if ($name eq "");
				$job   = $jobs_lut{$guild{'member'}[$i]{'jobID'}};
				$lvl   = $guild{'member'}[$i]{'lvl'};
				$title = $guild{'member'}[$i]{'title'};
				$online = $guild{'member'}[$i]{'online'} ? "Yes" : "No";
				write;
			}
			print "---------------------------------------\n";

		} elsif ($arg1 eq "") {
			print "Requesting guild information...\n",
				"Enter command to view guild information: guild < info | member >\n";
			sendGuildInfoRequest(\$remote_socket);
			sendGuildRequest(\$remote_socket, 0);
			sendGuildRequest(\$remote_socket, 1);
		}

	} elsif ($switch eq "i") {
		($arg1) = $input =~ /^[\s\S]*? (\w+)/;
		($arg2) = $input =~ /^[\s\S]*? \w+ (\d+)/;
		if ($arg1 eq "" || $arg1 eq "eq" || $arg1 eq "u" || $arg1 eq "nu") {
			undef @useable;
			undef @equipment;
			undef @non_useable;
			for ($i = 0; $i < @{$chars[$config{'char'}]{'inventory'}};$i++) {
				next if (!%{$chars[$config{'char'}]{'inventory'}[$i]});
				if ($chars[$config{'char'}]{'inventory'}[$i]{'type_equip'} != 0) {
					push @equipment, $i;
				} elsif ($chars[$config{'char'}]{'inventory'}[$i]{'type'} <= 2) {
					push @useable, $i;
				} else {
					push @non_useable, $i;
				} 
			}
			$~ = "INVENTORY";
			format INVENTORY =
@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$index   $display
.
			print	"-----------Inventory-----------\n";
			if ($arg1 eq "" || $arg1 eq "eq") {
				print	"-- Equipment --\n";
				for ($i = 0; $i < @equipment; $i++) {
					$display = $chars[$config{'char'}]{'inventory'}[$equipment[$i]]{'name'};
#Solos Start
					$display .= " ($itemTypes_lut{$chars[$config{'char'}]{'inventory'}[$equipment[$i]]{'type'}})";

					if ($chars[$config{'char'}]{'inventory'}[$equipment[$i]]{'equipped'}) {
						$display .= " -- Eqp: $equipTypes_lut{$chars[$config{'char'}]{'inventory'}[$equipment[$i]]{'type_equip'}}";
					}
#Solos End
					if (!$chars[$config{'char'}]{'inventory'}[$equipment[$i]]{'identified'}) {
						$display .= " -- Not Identified";
					}
					$index = $equipment[$i];
					write;
				}
			}
			if ($arg1 eq "" || $arg1 eq "nu") {
				print	"-- Non-Useable --\n";
				for ($i = 0; $i < @non_useable; $i++) {
					$display = $chars[$config{'char'}]{'inventory'}[$non_useable[$i]]{'name'};
					$display .= " x $chars[$config{'char'}]{'inventory'}[$non_useable[$i]]{'amount'}";
					$index = $non_useable[$i];
					write;
				}
			}
			if ($arg1 eq "" || $arg1 eq "u") {
				print	"-- Useable --\n";
				for ($i = 0; $i < @useable; $i++) {
					$display = $chars[$config{'char'}]{'inventory'}[$useable[$i]]{'name'};
					$display .= " x $chars[$config{'char'}]{'inventory'}[$useable[$i]]{'amount'}";
					$index = $useable[$i];
					write;
				}
			}
			print "-------------------------------\n";

		} elsif ($arg1 eq "desc" && $arg2 =~ /\d+/ && $chars[$config{'char'}]{'inventory'}[$arg2] eq "") {
			print	"Error in function 'i' (Iventory Item Desciption)\n"
				,"Inventory Item $arg2 does not exist\n";
		} elsif ($arg1 eq "desc" && $arg2 =~ /\d+/) {
			printItemDesc($chars[$config{'char'}]{'inventory'}[$arg2]{'nameID'});

		} else {
			print	"Syntax Error in function 'i' (Iventory List)\n"
				,"Usage: i [<u|eq|nu|desc>] [<inventory #>]\n";
		}

	} elsif ($switch eq "identify") {
		($arg1) = $input =~ /^[\s\S]*? (\w+)/;
		if ($arg1 eq "") {
			$~ = "IDENTIFY";
			print	"---------Identify List--------\n";
			for ($i = 0; $i < @identifyID; $i++) {
				next if ($identifyID[$i] eq "");
				format IDENTIFY =
@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$i   $chars[$config{'char'}]{'inventory'}[$identifyID[$i]]{'name'}
.
				write;
			}
			print	"------------------------------\n";
		} elsif ($arg1 =~ /\d+/ && $identifyID[$arg1] eq "") {
			print	"Error in function 'identify' (Identify Item)\n"
				,"Identify Item $arg1 does not exist\n";

		} elsif ($arg1 =~ /\d+/) {
			sendIdentify(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$identifyID[$arg1]]{'index'});
		} else {
			print	"Syntax Error in function 'identify' (Identify Item)\n"
				,"Usage: identify [<identify #>]\n";
		}


	} elsif ($switch eq "ignore") {
		($arg1, $arg2) = $input =~ /^[\s\S]*? (\d+) ([\s\S]*)/;
		if ($arg1 eq "" || $arg2 eq "" || ($arg1 ne "0" && $arg1 ne "1")) {
			print	"Syntax Error in function 'ignore' (Ignore Player/Everyone)\n"
				,"Usage: ignore <flag> <name | all>\n";
		} else {
			if ($arg2 eq "all") {
				sendIgnoreAll(\$remote_socket, !$arg1);
			} else {
				sendIgnore(\$remote_socket, $arg2, !$arg1);
			}
		}

	} elsif ($switch eq "il") {
		$~ = "ILIST";
		print	"-----------Item List-----------\n"
			,"#    Name                      \n";
		for ($i = 0; $i < @itemsID; $i++) {
			next if ($itemsID[$i] eq "");
			$display = $items{$itemsID[$i]}{'name'};
			$display .= " x $items{$itemsID[$i]}{'amount'}";
			format ILIST =
@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$i   $display
.
			write;
		}
		print "-------------------------------\n";

	} elsif ($switch eq "im") {
		($arg1) = $input =~ /^[\s\S]*? (\d+)/;
		($arg2) = $input =~ /^[\s\S]*? \d+ (\d+)/;
		if ($arg1 eq "" || $arg2 eq "") {
			print	"Syntax Error in function 'im' (Use Item on Monster)\n"
				,"Usage: im <item #> <monster #>\n";
		} elsif (!%{$chars[$config{'char'}]{'inventory'}[$arg1]}) {
			print	"Error in function 'im' (Use Item on Monster)\n"
				,"Inventory Item $arg1 does not exist.\n";
		} elsif ($chars[$config{'char'}]{'inventory'}[$arg1]{'type'} > 2) {
			print	"Error in function 'im' (Use Item on Monster)\n"
				,"Inventory Item $arg1 is not of type Usable.\n";
		} elsif ($monstersID[$arg2] eq "") {
			print	"Error in function 'im' (Use Item on Monster)\n"
				,"Monster $arg2 does not exist.\n";
		} else {
			sendItemUse(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$arg1]{'index'}, $monstersID[$arg2]);
		}

	} elsif ($switch eq "ip") {
		($arg1) = $input =~ /^[\s\S]*? (\d+)/;
		($arg2) = $input =~ /^[\s\S]*? \d+ (\d+)/;
		if ($arg1 eq "" || $arg2 eq "") {
			print	"Syntax Error in function 'ip' (Use Item on Player)\n"
				,"Usage: ip <item #> <player #>\n";
		} elsif (!%{$chars[$config{'char'}]{'inventory'}[$arg1]}) {
			print	"Error in function 'ip' (Use Item on Player)\n"
				,"Inventory Item $arg1 does not exist.\n";
		} elsif ($chars[$config{'char'}]{'inventory'}[$arg1]{'type'} > 2) {
			print	"Error in function 'ip' (Use Item on Player)\n"
				,"Inventory Item $arg1 is not of type Usable.\n";
		} elsif ($playersID[$arg2] eq "") {
			print	"Error in function 'ip' (Use Item on Player)\n"
				,"Player $arg2 does not exist.\n";
		} else {
			sendItemUse(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$arg1]{'index'}, $playersID[$arg2]);
		}

	} elsif ($switch eq "is") {
		($arg1) = $input =~ /^[\s\S]*? (\d+)/;
		if ($arg1 eq "") {
			print	"Syntax Error in function 'is' (Use Item on Self)\n"
				,"Usage: is <item #>\n";
		} elsif (!%{$chars[$config{'char'}]{'inventory'}[$arg1]}) {
			print	"Error in function 'is' (Use Item on Self)\n"
				,"Inventory Item $arg1 does not exist.\n";
		} elsif ($chars[$config{'char'}]{'inventory'}[$arg1]{'type'} > 2) {
			print	"Error in function 'is' (Use Item on Self)\n"
				,"Inventory Item $arg1 is not of type Usable.\n";
		} else {
			sendItemUse(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$arg1]{'index'}, $accountID);
		}

	} elsif ($switch eq "join") {
		($arg1) = $input =~ /^[\s\S]*? (\d+)/;
		($arg2) = $input =~ /^[\s\S]*? \d+ ([\s\S]*)$/;
		if ($arg1 eq "") {
			print	"Syntax Error in function 'join' (Join Chat Room)\n"
				,"Usage: join <chat room #> [<password>]\n";
		} elsif ($currentChatRoom ne "") {
			print	"Error in function 'join' (Join Chat Room)\n"
				,"You are already in a chat room.\n";
		} elsif ($chatRoomsID[$arg1] eq "") {
			print	"Error in function 'join' (Join Chat Room)\n"
				,"Chat Room $arg1 does not exist.\n";
		} else {
			sendChatRoomJoin(\$remote_socket, $chatRoomsID[$arg1], $arg2);
		}

	} elsif ($switch eq "judge") {
		($arg1) = $input =~ /^[\s\S]*? (\d+)/;
		($arg2) = $input =~ /^[\s\S]*? \d+ (\d+)/;
		if ($arg1 eq "" || $arg2 eq "") {
			print	"Syntax Error in function 'judge' (Give an alignment point to Player)\n"
				,"Usage: judge <player #> <0 (good) | 1 (bad)>\n";
		} elsif ($playersID[$arg1] eq "") {
			print	"Error in function 'judge' (Give an alignment point to Player)\n"
				,"Player $arg1 does not exist.\n";
		} else {
			$arg2 = ($arg2 >= 1);
			sendAlignment(\$remote_socket, $playersID[$arg1], $arg2);
		}

	} elsif ($switch eq "kick") {
		($arg1) = $input =~ /^[\s\S]*? ([\s\S]*)/;
		if ($currentChatRoom eq "") {
			print	"Error in function 'kick' (Kick from Chat)\n"
				,"You are not in a Chat Room.\n";
		} elsif ($arg1 eq "") {
			print	"Syntax Error in function 'kick' (Kick from Chat)\n"
				,"Usage: kick <user #>\n";
		} elsif ($currentChatRoomUsers[$arg1] eq "") {
			print	"Error in function 'kick' (Kick from Chat)\n"
				,"Chat Room User $arg1 doesn't exist\n";
		} else {
			sendChatRoomKick(\$remote_socket, $currentChatRoomUsers[$arg1]);
		}

	} elsif ($switch eq "leave") {
		if ($currentChatRoom eq "") {
			print	"Error in function 'leave' (Leave Chat Room)\n"
				,"You are not in a Chat Room.\n";
		} else {
			sendChatRoomLeave(\$remote_socket);
		}

	} elsif ($switch eq "look") {
		my ($arg1) = $input =~ /^[\s\S]*? (\d+)/;
		my ($arg2) = $input =~ /^[\s\S]*? \d+ (\d+)$/;
		if ($arg1 eq "") {
			print	"Syntax Error in function 'look' (Look a Direction)\n"
				,"Usage: look <body dir> [<head dir>]\n";
		} else {
			look($arg1, $arg2);
		}

	} elsif ($switch eq "lookp") {
		my ($arg1) = $input =~ /^[\s\S]*? (\d+)/;
		if ($arg1 eq "") {
			print "Syntax Error in function 'lookp' (Look at Player)\n" .
					"Usage: lookp <player #>\n";
		} else {
			for (my $i = 0; $i < @playersID; $i++) {
				next if ($players{$playersID[$i]} eq "");
				lookAtPosition($players{$playersID[$i]}{'pos_to'}, int(rand(3)));
				last;
			}
		}

	} elsif ($switch eq "memo") {
		sendMemo(\$remote_socket);

	} elsif ($switch eq "ml") {
		$~ = "MLIST";
		print	"-----------Monster List-----------\n"
			,"#    Name                     DmgTo    DmgFrom    Distance    Coordinates\n";
		for (my $i = 0; $i < @monstersID; $i++) {
			next if ($monstersID[$i] eq "");
			$dmgTo = ($monsters{$monstersID[$i]}{'dmgTo'} ne "")
				? $monsters{$monstersID[$i]}{'dmgTo'}
				: 0;
			$dmgFrom = ($monsters{$monstersID[$i]}{'dmgFrom'} ne "")
				? $monsters{$monstersID[$i]}{'dmgFrom'}
				: 0;
			my $dist = distance(\%{$chars[$config{'char'}]{'pos_to'}}, \%{$monsters{$monstersID[$i]}{'pos_to'}});
			$dist = sprintf ("%.1f", $dist) if (index ($dist, '.') > -1);
			my $pos = '(' . $monsters{$monstersID[$i]}{'pos_to'}{'x'} . ', ' . $monsters{$monstersID[$i]}{'pos_to'}{'y'} . ')';

			format MLIST =
@<<< @<<<<<<<<<<<<<<<<<<<<<<< @<<<<    @<<<<      @<<<<<      @<<<<<<<<<<
$i   $monsters{$monstersID[$i]}{'name'}                 $dmgTo   $dmgFrom  $dist  $pos
.
			write;
		}
		print "----------------------------------\n";

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
			print	"Syntax Error in function 'move' (Move Player)\n"
				,"Usage: move <x> <y> &| <map>\n";
		} elsif ($ai_v{'temp'}{'map'} eq "stop") {
			aiRemove("move");
			aiRemove("route");
			aiRemove("route_getRoute");
			aiRemove("route_getMapRoute");
			print "Stopped all movement\n";
		} else {
			$ai_v{'temp'}{'map'} = $field{'name'} if ($ai_v{'temp'}{'map'} eq "");
			if ($maps_lut{$ai_v{'temp'}{'map'}.'.rsw'}) {
				if ($arg2 ne "") {
					print "Calculating route to: $maps_lut{$ai_v{'temp'}{'map'}.'.rsw'}($ai_v{'temp'}{'map'}): $arg1, $arg2\n";
					$ai_v{'temp'}{'x'} = $arg1;
					$ai_v{'temp'}{'y'} = $arg2;
				} else {
					print "Calculating route to: $maps_lut{$ai_v{'temp'}{'map'}.'.rsw'}($ai_v{'temp'}{'map'})\n";
					undef $ai_v{'temp'}{'x'};
					undef $ai_v{'temp'}{'y'};
				}
				ai_route(\%{$ai_v{'temp'}{'returnHash'}}, $ai_v{'temp'}{'x'}, $ai_v{'temp'}{'y'}, $ai_v{'temp'}{'map'}, 0, 0, 1, 0, 0, 1);
			} else {
				print "Map $ai_v{'temp'}{'map'} does not exist\n";
			}
		}

	} elsif ($switch eq "nl") {
		$~ = "NLIST";
		print	"-----------NPC List-----------\n"
			,"#    Name                         Coordinates   ID\n";
		for ($i = 0; $i < @npcsID; $i++) {
			next if ($npcsID[$i] eq "");
			$ai_v{'temp'}{'pos_string'} = "($npcs{$npcsID[$i]}{'pos'}{'x'}, $npcs{$npcsID[$i]}{'pos'}{'y'})";
			format NLIST =
@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<   @<<<<<<<<
$i   $npcs{$npcsID[$i]}{'name'} $ai_v{'temp'}{'pos_string'}   $npcs{$npcsID[$i]}{'nameID'}
.
			write;
		}
		print "---------------------------------\n";

	} elsif ($switch eq "openshop"){
		if (!$shopstarted) {
			sendOpenShop(\$remote_socket);
		} else {
			print "Error: a shop has already been opened.\n";
		}

	} elsif ($switch eq "p") {
		($arg1) = $input =~ /^[\s\S]*? ([\s\S]*)/;
		if ($arg1 eq "") {
			print	"Syntax Error in function 'p' (Party Chat)\n"
				,"Usage: p <message>\n";
		} else {
			sendMessage(\$remote_socket, "p", $arg1);
		}

	} elsif ($switch eq "party") {
		($arg1) = $input =~ /^[\s\S]*? (\w*)/;
		($arg2) = $input =~ /^[\s\S]*? [\s\S]*? (\d+)\b/;
		if ($arg1 eq "" && !%{$chars[$config{'char'}]{'party'}}) {
			print	"Error in function 'party' (Party Functions)\n"
				,"Can't list party - you're not in a party.\n";
		} elsif ($arg1 eq "") {
			print "----------Party-----------\n";
			print $chars[$config{'char'}]{'party'}{'name'}."\n";
			$~ = "PARTYUSERS";
			print "#      Name                  Map                    Online    HP\n";
			for ($i = 0; $i < @partyUsersID; $i++) {
				next if ($partyUsersID[$i] eq "");
				$coord_string = "";
				$hp_string = "";
				$name_string = $chars[$config{'char'}]{'party'}{'users'}{$partyUsersID[$i]}{'name'};
				$admin_string = ($chars[$config{'char'}]{'party'}{'users'}{$partyUsersID[$i]}{'admin'}) ? "(A)" : "";
				
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
				format PARTYUSERS = 
@< @<< @<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<< @<<<<<<< @<<       @<<<<<<<<<<<<<<<<<<
$i $admin_string $name_string $map_string  $coord_string $online_string $hp_string
.
				write;
			}
			print "--------------------------\n";
			
		} elsif ($arg1 eq "create") {
			($arg2) = $input =~ /^[\s\S]*? [\s\S]*? \"([\s\S]*?)\"/;
			if ($arg2 eq "") {
				print	"Syntax Error in function 'party create' (Organize Party)\n"
				,qq~Usage: party create "<party name>"\n~;
			} else {
				sendPartyOrganize(\$remote_socket, $arg2);
			}

		} elsif ($arg1 eq "join" && $arg2 ne "1" && $arg2 ne "0") {
			print	"Syntax Error in function 'party join' (Accept/Deny Party Join Request)\n"
				,"Usage: party join <flag>\n";
		} elsif ($arg1 eq "join" && $incomingParty{'ID'} eq "") {
			print	"Error in function 'party join' (Join/Request to Join Party)\n"
				,"Can't accept/deny party request - no incoming request.\n";
		} elsif ($arg1 eq "join") {
			sendPartyJoin(\$remote_socket, $incomingParty{'ID'}, $arg2);
			undef %incomingParty;

		} elsif ($arg1 eq "request" && !%{$chars[$config{'char'}]{'party'}}) {
			print	"Error in function 'party request' (Request to Join Party)\n"
				,"Can't request a join - you're not in a party.\n";
		} elsif ($arg1 eq "request" && $playersID[$arg2] eq "") {
			print	"Error in function 'party request' (Request to Join Party)\n"
				,"Can't request to join party - player $arg2 does not exist.\n";
		} elsif ($arg1 eq "request") {
			sendPartyJoinRequest(\$remote_socket, $playersID[$arg2]);


		} elsif ($arg1 eq "leave" && !%{$chars[$config{'char'}]{'party'}}) {
			print	"Error in function 'party leave' (Leave Party)\n"
				,"Can't leave party - you're not in a party.\n";
		} elsif ($arg1 eq "leave") {
			sendPartyLeave(\$remote_socket);


		} elsif ($arg1 eq "share" && !%{$chars[$config{'char'}]{'party'}}) {
			print	"Error in function 'party share' (Set Party Share EXP)\n"
				,"Can't set share - you're not in a party.\n";
		} elsif ($arg1 eq "share" && $arg2 ne "1" && $arg2 ne "0") {
			print	"Syntax Error in function 'party share' (Set Party Share EXP)\n"
				,"Usage: party share <flag>\n";
		} elsif ($arg1 eq "share") {
			sendPartyShareEXP(\$remote_socket, $arg2);


		} elsif ($arg1 eq "kick" && !%{$chars[$config{'char'}]{'party'}}) {
			print	"Error in function 'party kick' (Kick Party Member)\n"
				,"Can't kick member - you're not in a party.\n";
		} elsif ($arg1 eq "kick" && $arg2 eq "") {
			print	"Syntax Error in function 'party kick' (Kick Party Member)\n"
				,"Usage: party kick <party member #>\n";
		} elsif ($arg1 eq "kick" && $partyUsersID[$arg2] eq "") {
			print	"Error in function 'party kick' (Kick Party Member)\n"
				,"Can't kick member - member $arg2 doesn't exist.\n";
		} elsif ($arg1 eq "kick") {
			sendPartyKick(\$remote_socket, $partyUsersID[$arg2]
					,$chars[$config{'char'}]{'party'}{'users'}{$partyUsersID[$arg2]}{'name'});

		}

	} elsif ($switch eq "petl") {
		$~ = "PETLIST";
		print	"-----------Pet List-----------\n"
			,"#    Type                     Name\n";
		for ($i = 0; $i < @petsID; $i++) {
			next if ($petsID[$i] eq "");
			format PETLIST =
@<<< @<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<<<<<<<<<<<<<
$i   $pets{$petsID[$i]}{'name'} $pets{$petsID[$i]}{'name_given'}
.
			write;
		}
		print "----------------------------------\n";

	} elsif ($switch eq "pm") {
		($arg1, $arg2) =$input =~ /^[\s\S]*? "([\s\S]*?)" ([\s\S]*)/;
		$type = 0;
		if (!$arg1) {
			($arg1, $arg2) =$input =~ /^[\s\S]*? (\d+) ([\s\S]*)/;
			$type = 1;
		}
		if ($arg1 eq "" || $arg2 eq "") {
			print	"Syntax Error in function 'pm' (Private Message)\n"
				,qq~Usage: pm ("<username>" | <pm #>) <message>\n~;
		} elsif ($type) {
			if ($arg1 - 1 >= @privMsgUsers) {
				print	"Error in function 'pm' (Private Message)\n"
				,"Quick look-up $arg1 does not exist\n";
			} else {
				sendMessage(\$remote_socket, "pm", $arg2, $privMsgUsers[$arg1 - 1]);
				$lastpm{'msg'} = $arg2;
				$lastpm{'user'} = $privMsgUsers[$arg1 - 1];
			}
		} else {
			if ($arg1 =~ /^%(\d*)$/) {
				$arg1 = $1;
			}
#pml bugfix - chobit andy 20030127
			if (binFind(\@privMsgUsers, $arg1) eq "") {
				$privMsgUsers[@privMsgUsers] = $arg1;
			}
			sendMessage(\$remote_socket, "pm", $arg2, $arg1);
			$lastpm{'msg'} = $arg2;
			$lastpm{'user'} = $arg1;
		}

	} elsif ($switch eq "pml") {
		$~ = "PMLIST";
		print "-----------PM LIST-----------\n";
		for ($i = 1; $i <= @privMsgUsers; $i++) {
			format PMLIST =
@<<< @<<<<<<<<<<<<<<<<<<<<<<<
$i   $privMsgUsers[$i - 1]
.
			write;
		}
		print "-----------------------------\n";


	} elsif ($switch eq "pl") {
		$~ = "PLIST";
		print	"-----------Player List-----------\n"
			,"#    Name                                    Sex   Job         Dist  Coord\n";
		for ($i = 0; $i < @playersID; $i++) {
			next if ($playersID[$i] eq "");
			if (%{$players{$playersID[$i]}{'guild'}}) {
				$name = "$players{$playersID[$i]}{'name'} [$players{$playersID[$i]}{'guild'}{'name'}]";
			} else {
				$name = $players{$playersID[$i]}{'name'};
			}
			my $dist = distance(\%{$chars[$config{'char'}]{'pos_to'}}, \%{$players{$playersID[$i]}{'pos_to'}});
			$dist = sprintf ("%.1f", $dist) if (index ($dist, '.') > -1);
			my $pos = '(' . $players{$playersID[$i]}{'pos_to'}{'x'} . ', ' . $players{$playersID[$i]}{'pos_to'}{'y'} . ')';

			format PLIST =
@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<< @<<<<<<<<<< @<<<< @<<<<<<<<<<
$i   $name $sex_lut{$players{$playersID[$i]}{'sex'}} $jobs_lut{$players{$playersID[$i]}{'jobID'}} $dist $pos
.
			write;
		}
		print "---------------------------------\n";

	} elsif ($switch eq "portals") {
		$~ = "PORTALLIST";
		print	"-----------Portal List-----------\n"
			,"#    Name                                Coordinates\n";
		for ($i = 0; $i < @portalsID; $i++) {
			next if ($portalsID[$i] eq "");
			$coords = "($portals{$portalsID[$i]}{'pos'}{'x'},$portals{$portalsID[$i]}{'pos'}{'y'})";
			format PORTALLIST =
@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<
$i   $portals{$portalsID[$i]}{'name'}    $coords
.
			write;
		}
		print "---------------------------------\n";

	} elsif ($switch eq "quit") {
		quit();

	} elsif ($switch eq "rc") {
		# Check functions.pl for syntax errors
		# Note: this is $Config, not $config!
		my $ok = 1;
		if (-f $Config{'perlpath'}) {
			$ok = 0;
			print "Checking functions.pl for errors...\n";
			system($Config{'perlpath'}, '-c', 'functions.pl');
			if ($? == -1) {
				print "Error: failed to execute $Config{'perlpath'}\n";
			} elsif ($? & 127) {
				print "Error: $Config{'perlpath'} exited abnormally\n";
			} elsif (($? >> 8) == 0) {
				print "functions.pl passed syntax check.\n" if ($printType);
				$ok = 1;
			} else {
				print "Error: functions.pl contains syntax errors.\n";
			}
		}

		if ($ok) {
			print "Reloading functions.pl...\n";
			if (!do 'functions.pl' || $@) {
				print "Unable to reload functions.pl\n";
				print "$@\n" if ($@);
			}
		}

	} elsif ($switch eq "reload") {
		($arg1) = $input =~ /^[\s\S]*? ([\s\S]*)/;
		parseReload($arg1);

	} elsif ($switch eq "relog") {
		relog();

	} elsif ($switch eq "respawn") {
		useTeleport(2);

	} elsif ($switch eq "s") {
		if ($chars[$config{'char'}]{'exp_last'} > $chars[$config{'char'}]{'exp'}) {
			$baseEXPKill = $chars[$config{'char'}]{'exp_max_last'} - $chars[$config{'char'}]{'exp_last'} + $chars[$config{'char'}]{'exp'};
		} elsif ($chars[$config{'char'}]{'exp_last'} == 0 && $chars[$config{'char'}]{'exp_max_last'} == 0) {
			$baseEXPKill = 0;
		} else {
			$baseEXPKill = $chars[$config{'char'}]{'exp'} - $chars[$config{'char'}]{'exp_last'};
		}
		if ($chars[$config{'char'}]{'exp_job_last'} > $chars[$config{'char'}]{'exp_job'}) {
			$jobEXPKill = $chars[$config{'char'}]{'exp_job_max_last'} - $chars[$config{'char'}]{'exp_job_last'} + $chars[$config{'char'}]{'exp_job'};
		} elsif ($chars[$config{'char'}]{'exp_job_last'} == 0 && $chars[$config{'char'}]{'exp_job_max_last'} == 0) {
			$jobEXPKill = 0;
		} else {
			$jobEXPKill = $chars[$config{'char'}]{'exp_job'} - $chars[$config{'char'}]{'exp_job_last'};
		}
		$lastBase =
		$hp_string = $chars[$config{'char'}]{'hp'}."/".$chars[$config{'char'}]{'hp_max'}." ("
				.int($chars[$config{'char'}]{'hp'}/$chars[$config{'char'}]{'hp_max'} * 100)
				."%)" if $chars[$config{'char'}]{'hp_max'};
		$sp_string = $chars[$config{'char'}]{'sp'}."/".$chars[$config{'char'}]{'sp_max'}." ("
				.int($chars[$config{'char'}]{'sp'}/$chars[$config{'char'}]{'sp_max'} * 100)
				."%)" if $chars[$config{'char'}]{'sp_max'};
		$base_string = $chars[$config{'char'}]{'exp'}."/".$chars[$config{'char'}]{'exp_max'}." /$baseEXPKill ("
				.sprintf("%.2f",$chars[$config{'char'}]{'exp'}/$chars[$config{'char'}]{'exp_max'} * 100)
				."%)" if $chars[$config{'char'}]{'exp_max'};
		$job_string = $chars[$config{'char'}]{'exp_job'}."/".$chars[$config{'char'}]{'exp_job_max'}." /$jobEXPKill ("
				.sprintf("%.2f",$chars[$config{'char'}]{'exp_job'}/$chars[$config{'char'}]{'exp_job_max'} * 100)
				."%)" if $chars[$config{'char'}]{'exp_job_max'};
		$weight_string = $chars[$config{'char'}]{'weight'}."/".$chars[$config{'char'}]{'weight_max'}." ("
				.int($chars[$config{'char'}]{'weight'}/$chars[$config{'char'}]{'weight_max'} * 100)
				."%)" if $chars[$config{'char'}]{'weight_max'};
		$job_name_string = "$jobs_lut{$chars[$config{'char'}]{'jobID'}} $sex_lut{$chars[$config{'char'}]{'sex'}}";
		print	"-----------Status-----------\n";
		$~ = "STATUS";
		format STATUS =
@<<<<<<<<<<<<<<<<<<<<<<<< HP: @<<<<<<<<<<<<<<<<<<
$chars[$config{'char'}]{'name'} $hp_string
@<<<<<<<<<<<<<<<<<<<<<<<< SP: @<<<<<<<<<<<<<<<<<<
$job_name_string              $sp_string
Base: @<< @>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
      $chars[$config{'char'}]{'lv'} $base_string
Job:  @<< @>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
      $chars[$config{'char'}]{'lv_job'} $job_string
Weight: @>>>>>>>>>>>>>>>> Zenny: @<<<<<<<<<<<<<<
        $weight_string           $chars[$config{'char'}]{'zenny'}
.
		write;
		print	"----------------------------\n";
#Solos Start
		printStat();
#Solos End

	

	} elsif ($switch eq "sell") {
		($arg1) = $input =~ /^[\s\S]*? (\d+)/;
		($arg2) = $input =~ /^[\s\S]*? \d+ (\d+)$/;
		if ($arg1 eq "" && $talk{'buyOrSell'}) {
			sendGetSellList(\$remote_socket, $talk{'ID'});

		} elsif ($arg1 eq "") {
			print	"Syntax Error in function 'sell' (Sell Inventory Item)\n"
				,"Usage: sell <item #> [<amount>]\n";
		} elsif (!%{$chars[$config{'char'}]{'inventory'}[$arg1]}) {
			print	"Error in function 'sell' (Sell Inventory Item)\n"
				,"Inventory Item $arg1 does not exist.\n";
		} else {
			if (!$arg2 || $arg2 > $chars[$config{'char'}]{'inventory'}[$arg1]{'amount'}) {
				$arg2 = $chars[$config{'char'}]{'inventory'}[$arg1]{'amount'};
			}
			sendSell(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$arg1]{'index'}, $arg2);
		}

	} elsif ($switch eq "send") {
		($args) = $input =~ /^[\s\S]*? ([\s\S]*)/;
		sendRaw(\$remote_socket, $args);

	} elsif ($switch eq "sit") {
		$ai_v{'attackAuto_old'} = $config{'attackAuto'};
		$ai_v{'route_randomWalk_old'} = $config{'route_randomWalk'};
		$ai_v{'teleportAuto_idle_old'} = $config{'teleportAuto_idle'};
		configModify("attackAuto", 1);
		configModify("route_randomWalk", 0);
		configModify("teleportAuto_idle", 0);
		aiRemove("move");
		aiRemove("route");
		aiRemove("route_getRoute");
		aiRemove("route_getMapRoute");
		sit();
		$ai_v{'sitAuto_forceStop'} = 0;

	} elsif ($switch eq "sm") {
		($arg1) = $input =~ /^[\s\S]*? (\d+)/;
		($arg2) = $input =~ /^[\s\S]*? \d+ (\d+)/;
		($arg3) = $input =~ /^[\s\S]*? \d+ \d+ (\d+)/;
		if ($arg1 eq "" || $arg2 eq "") {
			print	"Syntax Error in function 'sm' (Use Skill on Monster)\n"
				,"Usage: sm <skill #> <monster #> [<skill lvl>]\n";
		} elsif ($monstersID[$arg2] eq "") {
			print	"Error in function 'sm' (Use Skill on Monster)\n"
				,"Monster $arg2 does not exist.\n";	
		} elsif ($skillsID[$arg1] eq "") {
			print	"Error in function 'sm' (Use Skill on Monster)\n"
				,"Skill $arg1 does not exist.\n";
		} else {
			if (!$arg3 || $arg3 > $chars[$config{'char'}]{'skills'}{$skillsID[$arg1]}{'lv'}) {
				$arg3 = $chars[$config{'char'}]{'skills'}{$skillsID[$arg1]}{'lv'};
			}
			if (!ai_getSkillUseType($skillsID[$arg1])) {
				ai_skillUse($chars[$config{'char'}]{'skills'}{$skillsID[$arg1]}{'ID'}, $arg3, 0,0, $monstersID[$arg2]);
			} else {
				ai_skillUse($chars[$config{'char'}]{'skills'}{$skillsID[$arg1]}{'ID'}, $arg3, 0,0, $monsters{$monstersID[$arg2]}{'pos_to'}{'x'}, $monsters{$monstersID[$arg2]}{'pos_to'}{'y'});
			}
		}

	} elsif ($switch eq "skills") {
		($arg1) = $input =~ /^[\s\S]*? (\w+)/;
		($arg2) = $input =~ /^[\s\S]*? \w+ (\d+)/;
		if ($arg1 eq "") {
			$~ = "SKILLS";
			print "----------Skill List-----------\n";
			print "#  Skill Name                    Lv     SP\n";
			for ($i=0; $i < @skillsID; $i++) {
				format SKILLS =
@< @<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<    @<<<
$i $skills_lut{$skillsID[$i]} $chars[$config{'char'}]{'skills'}{$skillsID[$i]}{'lv'} $skillsSP_lut{$skillsID[$i]}{$chars[$config{'char'}]{'skills'}{$skillsID[$i]}{'lv'}}
.
				write;
			}
			print "\nSkill Points: $chars[$config{'char'}]{'points_skill'}\n";
			print "-------------------------------\n";


		} elsif ($arg1 eq "add" && $arg2 =~ /\d+/ && $skillsID[$arg2] eq "") {
			print	"Error in function 'skills add' (Add Skill Point)\n"
				,"Skill $arg2 does not exist.\n";
		} elsif ($arg1 eq "add" && $arg2 =~ /\d+/ && $chars[$config{'char'}]{'points_skill'} < 1) {
			print	"Error in function 'skills add' (Add Skill Point)\n"
				,"Not enough skill points to increase $skills_lut{$skillsID[$arg2]}.\n";
		} elsif ($arg1 eq "add" && $arg2 =~ /\d+/) {
			sendAddSkillPoint(\$remote_socket, $chars[$config{'char'}]{'skills'}{$skillsID[$arg2]}{'ID'});

		} elsif ($arg1 eq "desc" && $arg2 =~ /\d+/ && $skillsID[$arg2] eq "") {
			print	"Error in function 'skills desc' (Skill Description)\n"
				,"Skill $arg2 does not exist.\n";
		} elsif ($arg1 eq "desc" && $arg2 =~ /\d+/) {
			print "===============Skill Description===============\n";
			print "Skill: $skills_lut{$skillsID[$arg2]}\n\n";
			print $skillsDesc_lut{$skillsID[$arg2]};
			print "==============================================\n";
		} else {
			print	"Syntax Error in function 'skills' (Skills Functions)\n"
				,"Usage: skills [<add | desc>] [<skill #>]\n";
		}


	} elsif ($switch eq "sp") {
		($arg1) = $input =~ /^[\s\S]*? (\d+)/;
		($arg2) = $input =~ /^[\s\S]*? \d+ (\d+)/;
		($arg3) = $input =~ /^[\s\S]*? \d+ \d+ (\d+)/;
		if ($arg1 eq "" || $arg2 eq "") {
			print	"Syntax Error in function 'sp' (Use Skill on Player)\n"
				,"Usage: sp <skill #> <player #> [<skill lvl>]\n";
		} elsif ($playersID[$arg2] eq "") {
			print	"Error in function 'sp' (Use Skill on Player)\n"
				,"Player $arg2 does not exist.\n";	
		} elsif ($skillsID[$arg1] eq "") {
			print	"Error in function 'sp' (Use Skill on Player)\n"
				,"Skill $arg1 does not exist.\n";
		} else {
			if (!$arg3 || $arg3 > $chars[$config{'char'}]{'skills'}{$skillsID[$arg1]}{'lv'}) {
				$arg3 = $chars[$config{'char'}]{'skills'}{$skillsID[$arg1]}{'lv'};
			}
			if (!ai_getSkillUseType($skillsID[$arg1])) {
				ai_skillUse($chars[$config{'char'}]{'skills'}{$skillsID[$arg1]}{'ID'}, $arg3, 0,0, $playersID[$arg2]);
			} else {
				ai_skillUse($chars[$config{'char'}]{'skills'}{$skillsID[$arg1]}{'ID'}, $arg3, 0,0, $players{$playersID[$arg2]}{'pos_to'}{'x'}, $players{$playersID[$arg2]}{'pos_to'}{'y'});
			}
		}

	} elsif ($switch eq "ss") {
		($arg1) = $input =~ /^[\s\S]*? (\d+)/;
		($arg2) = $input =~ /^[\s\S]*? \d+ (\d+)/;
		if ($arg1 eq "") {
			print	"Syntax Error in function 'ss' (Use Skill on Self)\n"
				,"Usage: ss <skill #> [<skill lvl>]\n";
		} elsif ($skillsID[$arg1] eq "") {
			print	"Error in function 'ss' (Use Skill on Self)\n"
				,"Skill $arg1 does not exist.\n";
		} else {
			if (!$arg2 || $arg2 > $chars[$config{'char'}]{'skills'}{$skillsID[$arg1]}{'lv'}) {
				$arg2 = $chars[$config{'char'}]{'skills'}{$skillsID[$arg1]}{'lv'};
			}
			if (!ai_getSkillUseType($skillsID[$arg1])) {
				ai_skillUse($chars[$config{'char'}]{'skills'}{$skillsID[$arg1]}{'ID'}, $arg2, 0,0, $accountID);
			} else {
				ai_skillUse($chars[$config{'char'}]{'skills'}{$skillsID[$arg1]}{'ID'}, $arg2, 0,0, $chars[$config{'char'}]{'pos_to'}{'x'}, $chars[$config{'char'}]{'pos_to'}{'y'});
			}
		}

	} elsif ($switch eq "st") {
		print	"-----------Char Stats-----------\n";
		$~ = "STATS";
		$tilde = "~";
		format STATS =
Str: @<<+@<< #@< Atk:  @<<+@<< Def:  @<<+@<<
$chars[$config{'char'}]{'str'} $chars[$config{'char'}]{'str_bonus'} $chars[$config{'char'}]{'points_str'} $chars[$config{'char'}]{'attack'} $chars[$config{'char'}]{'attack_bonus'} $chars[$config{'char'}]{'def'} $chars[$config{'char'}]{'def_bonus'}
Agi: @<<+@<< #@< Matk: @<<@@<< Mdef: @<<+@<<
$chars[$config{'char'}]{'agi'} $chars[$config{'char'}]{'agi_bonus'} $chars[$config{'char'}]{'points_agi'} $chars[$config{'char'}]{'attack_magic_min'} $tilde $chars[$config{'char'}]{'attack_magic_max'} $chars[$config{'char'}]{'def_magic'} $chars[$config{'char'}]{'def_magic_bonus'}
Vit: @<<+@<< #@< Hit:  @<<     Flee: @<<+@<<
$chars[$config{'char'}]{'vit'} $chars[$config{'char'}]{'vit_bonus'} $chars[$config{'char'}]{'points_vit'} $chars[$config{'char'}]{'hit'} $chars[$config{'char'}]{'flee'} $chars[$config{'char'}]{'flee_bonus'}
Int: @<<+@<< #@< Critical: @<< Aspd: @<<
$chars[$config{'char'}]{'int'} $chars[$config{'char'}]{'int_bonus'} $chars[$config{'char'}]{'points_int'} $chars[$config{'char'}]{'critical'} $chars[$config{'char'}]{'attack_speed'}
Dex: @<<+@<< #@< Status Points: @<<
$chars[$config{'char'}]{'dex'} $chars[$config{'char'}]{'dex_bonus'} $chars[$config{'char'}]{'points_dex'} $chars[$config{'char'}]{'points_free'}
Luk: @<<+@<< #@< Guild: @<<<<<<<<<<<<<<<<<<<<<
$chars[$config{'char'}]{'luk'} $chars[$config{'char'}]{'luk_bonus'} $chars[$config{'char'}]{'points_luk'} $chars[$config{'char'}]{'guild'}{'name'}
.
		write;
		print	"--------------------------------\n";

	} elsif ($switch eq "stand") {
		if ($ai_v{'attackAuto_old'} ne "") {
			configModify("attackAuto", $ai_v{'attackAuto_old'});
			configModify("route_randomWalk", $ai_v{'route_randomWalk_old'});
			configModify("teleportAuto_idle", $ai_v{'teleportAuto_idle_old'});
			undef $ai_v{'attackAuto_old'};
			undef $ai_v{'route_randomWalk_old'};
			undef $ai_v{'teleportAuto_idle_old'};
		}
		stand();
		$ai_v{'sitAuto_forceStop'} = 1;

	} elsif ($switch eq "stat_add") {
		($arg1) = $input =~ /^[\s\S]*? ([\s\S]*)$/;
		if ($arg1 ne "str" &&  $arg1 ne "agi" && $arg1 ne "vit" && $arg1 ne "int" 
			&& $arg1 ne "dex" && $arg1 ne "luk") {
			print	"Syntax Error in function 'stat_add' (Add Status Point)\n"
			,"Usage: stat_add <str | agi | vit | int | dex | luk>\n";
		} else {
			if ($arg1 eq "str") {
				$ID = 0x0D;
			} elsif ($arg1 eq "agi") {
				$ID = 0x0E;
			} elsif ($arg1 eq "vit") {
				$ID = 0x0F;
			} elsif ($arg1 eq "int") {
				$ID = 0x10;
			} elsif ($arg1 eq "dex") {
				$ID = 0x11;
			} elsif ($arg1 eq "luk") {
				$ID = 0x12;
			}
			if ($chars[$config{'char'}]{"points_$arg1"} > $chars[$config{'char'}]{'points_free'}) {
				print	"Error in function 'stat_add' (Add Status Point)\n"
					,"Not enough status points to increase $arg1\n";
			} else {
				$chars[$config{'char'}]{$arg1} += 1;
				sendAddStatusPoint(\$remote_socket, $ID);
			}
		}

	} elsif ($switch eq "storage") {
		($arg1) = $input =~ /^[\s\S]*? (\w+)/;
		($arg2) = $input =~ /^[\s\S]*? \w+ (\d+)/;
		($arg3) = $input =~ /^[\s\S]*? \w+ \d+ (\d+)/;
		if ($arg1 eq "") {
			$~ = "STORAGELIST";
			print "----------Storage-----------\n";
			print "#  Name\n";
			for ($i=0; $i < @storageID;$i++) {
				next if ($storageID[$i] eq "");
#Solos Start
#				$display = "$storage{$storageID[$i]}{'name'} x $storage{$storageID[$i]}{'amount'}";		
				$display = "$storage{$storageID[$i]}{'name'}";
				if ($storage{$storageID[$i]}{'enchant'}) {
					$display = "+$storage{$storageID[$i]}{'enchant'} ".$display;
				}
				if ($storage{$storageID[$i]}{'slotName'} ne "") { 
                  	$display = $display ." [$storage{$storageID[$i]}{'slotName'}]";
               	} 
				$display = $display . " x $storage{$storageID[$i]}{'amount'}";
#Solos End
				format STORAGELIST =
@< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$i $display                
.
				write;
			}
			print "\nCapacity: $storage{'items'}/$storage{'items_max'}\n";
			print "-------------------------------\n";


		} elsif ($arg1 eq "add" && $arg2 =~ /\d+/ && $chars[$config{'char'}]{'inventory'}[$arg2] eq "") {
			print	"Error in function 'storage add' (Add Item to Storage)\n"
				,"Inventory Item $arg2 does not exist\n";
		} elsif ($arg1 eq "add" && $arg2 =~ /\d+/) {
			if (!$arg3 || $arg3 > $chars[$config{'char'}]{'inventory'}[$arg2]{'amount'}) {
				$arg3 = $chars[$config{'char'}]{'inventory'}[$arg2]{'amount'};
			}
			sendStorageAdd(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$arg2]{'index'}, $arg3);

		} elsif ($arg1 eq "get" && $arg2 =~ /\d+/ && $storageID[$arg2] eq "") {
			print	"Error in function 'storage get' (Get Item from Storage)\n"
				,"Storage Item $arg2 does not exist\n";
		} elsif ($arg1 eq "get" && $arg2 =~ /\d+/) {
			if (!$arg3 || $arg3 > $storage{$storageID[$arg2]}{'amount'}) {
				$arg3 = $storage{$storageID[$arg2]}{'amount'};
			}
			sendStorageGet(\$remote_socket, $storage{$storageID[$arg2]}{'index'}, $arg3);

		} elsif ($arg1 eq "close") {
			sendStorageClose(\$remote_socket);

		} else {
			print	"Syntax Error in function 'storage' (Storage Functions)\n"
				,"Usage: storage [<add | get | close>] [<inventory # | storage #>] [<amount>]\n";
		}

	} elsif ($switch eq "store") {
		($arg1) = $input =~ /^[\s\S]*? (\w+)/;
		($arg2) = $input =~ /^[\s\S]*? \w+ (\d+)/;
		if ($arg1 eq "" && !$talk{'buyOrSell'}) {
			$~ = "STORELIST";
			print "----------Store List-----------\n";
			print "#  Name                    Type           Price\n";
			for ($i=0; $i < @storeList;$i++) {
				$display = $storeList[$i]{'name'};
				format STORELIST =
@< @<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<< @>>>>>>>z
$i $display                $itemTypes_lut{$storeList[$i]{'type'}} $storeList[$i]{'price'}
.
				write;
			}
			print "-------------------------------\n";
		} elsif ($arg1 eq "" && $talk{'buyOrSell'}) {
			sendGetStoreList(\$remote_socket, $talk{'ID'});
			

		} elsif ($arg1 eq "desc" && $arg2 =~ /\d+/ && $storeList[$arg2] eq "") {
			print	"Error in function 'store desc' (Store Item Description)\n"
				,"Usage: Store item $arg2 does not exist\n";
		} elsif ($arg1 eq "desc" && $arg2 =~ /\d+/) {
			printItemDesc($storeList[$arg2]);

		} else {
			print	"Syntax Error in function 'store' (Store Functions)\n"
				,"Usage: store [<desc>] [<store item #>]\n";

		}

	} elsif ($switch eq "take") {
		($arg1) = $input =~ /^[\s\S]*? (\d+)$/;
		if ($arg1 eq "") {
			print	"Syntax Error in function 'take' (Take Item)\n"
				,"Usage: take <item #>\n";
		} elsif ($itemsID[$arg1] eq "") {
			print	"Error in function 'take' (Take Item)\n"
				,"Item $arg1 does not exist.\n";
		} else {
			take($itemsID[$arg1]);
		}


	} elsif ($switch eq "talk") {
		($arg1) = $input =~ /^[\s\S]*? (\w+)/;
		($arg2) = $input =~ /^[\s\S]*? [\s\S]*? (\d+)/;

		if ($arg1 =~ /^\d+$/ && $npcsID[$arg1] eq "") {
			print	"Error in function 'talk' (Talk to NPC)\n"
				,"NPC $arg1 does not exist\n";
		} elsif ($arg1 =~ /^\d+$/) {
			sendTalk(\$remote_socket, $npcsID[$arg1]);

		} elsif ($arg1 eq "resp" && !%talk) {
			print	"Error in function 'talk resp' (Respond to NPC)\n"
				,"You are not talking to any NPC.\n";
		} elsif ($arg1 eq "resp" && $arg2 eq "") {
			$display = $npcs{$talk{'nameID'}}{'name'};
			$~ = "RESPONSES";
			print "----------Responses-----------\n";
			print "NPC: $display\n";
			print "#  Response\n";
			for ($i=0; $i < @{$talk{'responses'}};$i++) {
				format RESPONSES =
@< @<<<<<<<<<<<<<<<<<<<<<<
$i $talk{'responses'}[$i]
.
				write;
			}
			print "-------------------------------\n";
		} elsif ($arg1 eq "resp" && $arg2 ne "" && $talk{'responses'}[$arg2] eq "") {
			print	"Error in function 'talk resp' (Respond to NPC)\n"
				,"Response $arg2 does not exist.\n";
		} elsif ($arg1 eq "resp" && $arg2 ne "") {
			if ($talk{'responses'}[$arg2] eq "Cancel Chat") {
				$arg2 = 255;
			} else {
				$arg2 += 1;
			}
			sendTalkResponse(\$remote_socket, $talk{'ID'}, $arg2);


		} elsif ($arg1 eq "cont" && !%talk) {
			print	"Error in function 'talk cont' (Continue Talking to NPC)\n"
				,"You are not talking to any NPC.\n";
		} elsif ($arg1 eq "cont") {
			sendTalkContinue(\$remote_socket, $talk{'ID'});


		} elsif ($arg1 eq "no") {
			sendTalkCancel(\$remote_socket, $talk{'ID'});


		} else {
			print	"Syntax Error in function 'talk' (Talk to NPC)\n"
				,"Usage: talk <NPC # | cont | resp> [<response #>]\n";
		}


	} elsif ($switch eq "tank") {
		($arg1) = $input =~ /^[\s\S]*? (\w+)/;
		if ($arg1 eq "") {
			print	"Syntax Error in function 'tank' (Tank for a Player)\n"
				,"Usage: tank <player #>\n";
		} elsif ($arg1 eq "stop") {
			configModify("tankMode", 0);
		} elsif ($playersID[$arg1] eq "") {
			print	"Error in function 'tank' (Tank for a Player)\n"
				,"Player $arg1 does not exist.\n";
		} else {
			configModify("tankMode", 1);
			configModify("tankModeTarget", $players{$playersID[$arg1]}{'name'});
		}

	} elsif ($switch eq "tele") {
		useTeleport(1);

	} elsif ($switch eq "timeout") {
		($arg1, $arg2) = $input =~ /^[\s\S]*? ([\s\S]*) ([\s\S]*?)$/;
		if ($arg1 eq "") {
			print	"Syntax Error in function 'timeout' (set a timeout)\n"
				,"Usage: timeout <type> [<seconds>]\n";
		} elsif ($timeout{$arg1} eq "") {
			print	"Error in function 'timeout' (set a timeout)\n"
				,"Timeout $arg1 doesn't exist\n";
		} elsif ($arg2 eq "") {
			print "Timeout '$arg1' is $config{$arg1}\n";
		} else {
			setTimeout($arg1, $arg2);
		}


	} elsif ($switch eq "uneq") {
		($arg1) = $input =~ /^[\s\S]*? (\d+)/;
		if ($arg1 eq "") {
			print	"Syntax Error in function 'unequip' (Unequip Inventory Item)\n"
				,"Usage: unequip <item #>\n";
		} elsif (!%{$chars[$config{'char'}]{'inventory'}[$arg1]}) {
			print	"Error in function 'unequip' (Unequip Inventory Item)\n"
				,"Inventory Item $arg1 does not exist.\n";
		} elsif ($chars[$config{'char'}]{'inventory'}[$arg1]{'equipped'} == 0) {
			print	"Error in function 'unequip' (Unequip Inventory Item)\n"
				,"Inventory Item $arg1 is not equipped.\n";
		} else {
			sendUnequip(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$arg1]{'index'});
		}
		
	} elsif ($switch eq "where") {
		($map_string) = $map_name =~ /([\s\S]*)\.gat/;
		print "Location $maps_lut{$map_string.'.rsw'}($map_string) : $chars[$config{'char'}]{'pos_to'}{'x'}, $chars[$config{'char'}]{'pos_to'}{'y'}\n";
		print "Last destination calculated : (".int($old_x).", ".int($old_y).") from spot (".int($old_pos_x).", ".int($old_pos_y).").\n";

	} elsif ($switch eq "who") {
		sendWho(\$remote_socket);

	} elsif ($switch eq "v") {
		if ($config{'verbose'}) {
			configModify("verbose", 0);
		} else {
			configModify("verbose", 1);
		}
	}


	if ($printType) {
		close(BUFFER);
		open(BUFREAD, '<buffer');

		my $msg = '';
		while (<BUFREAD>) {
			$msg .= $_;
		}
		close(BUFREAD);

		select(STDOUT);
		print "$input\n";
		print $msg;

		if ($config{'XKore'}) {
			$msg =~ s/\n*$//s;
			$msg =~ s/\n/\\n/g;
			sendMessage(\$remote_socket, "k", $msg);
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
		print "Wiped old\n" if ($config{'debug'} >= 2);
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
			open(DATA, ">walk.dat");
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

	if (!$accountID) {
		$AI = 0;
		injectAdminMessage("Kore does not have enough account information, so AI has been disabled. Relog to enable AI.") if ($config{'verbose'});
		return;
	}

	if (%cmd) {
		$responseVars{'cmd_user'} = $cmd{'user'};
		if ($cmd{'user'} eq $chars[$config{'char'}]{'name'}) {
			return;
		}
 		if ($cmd{'type'} eq "pm" || $cmd{'type'} eq "p" || $cmd{'type'} eq "g") {
			$ai_v{'temp'}{'qm'} = quotemeta $config{'adminPassword'};
			if ($cmd{'msg'} =~ /^$ai_v{'temp'}{'qm'}\b/) {
				if ($overallAuth{$cmd{'user'}} == 1) {
					sendMessage(\$remote_socket, "pm", getResponse("authF"), $cmd{'user'});
				} else {
					auth($cmd{'user'}, 1);
					sendMessage(\$remote_socket, "pm", getResponse("authS"),$cmd{'user'});
				}
			}
		}
		$ai_v{'temp'}{'qm'} = quotemeta $config{'callSign'};
		if ($overallAuth{$cmd{'user'}} >= 1 
			&& ($cmd{'msg'} =~ /\b$ai_v{'temp'}{'qm'}\b/i || $cmd{'type'} eq "pm")) {
			if ($cmd{'msg'} =~ /\bsit\b/i) {
				$ai_v{'sitAuto_forceStop'} = 0;
				$ai_v{'attackAuto_old'} = $config{'attackAuto'};
				$ai_v{'route_randomWalk_old'} = $config{'route_randomWalk'};
				configModify("attackAuto", 1);
				configModify("route_randomWalk", 0);
				aiRemove("move");
				aiRemove("route");
				aiRemove("route_getRoute");
				aiRemove("route_getMapRoute");
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
				parseReload($');
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
				($ai_v{'temp'}{'arg1'}, $ai_v{'temp'}{'arg2'}) = $ai_v{'temp'}{'after'} =~ /(\w+) (\w+)/;
				@{$ai_v{'temp'}{'conf'}} = keys %config;
				if ($ai_v{'temp'}{'arg1'} eq "") {
					sendMessage(\$remote_socket, $cmd{'type'}, getResponse("confF1"), $cmd{'user'}) if $config{'verbose'};
				} elsif (binFind(\@{$ai_v{'temp'}{'conf'}}, $ai_v{'temp'}{'arg1'}) eq "") {
					sendMessage(\$remote_socket, $cmd{'type'}, getResponse("confF2"), $cmd{'user'}) if $config{'verbose'};
				} elsif ($ai_v{'temp'}{'arg2'} eq "value") {
					if ($ai_v{'temp'}{'arg1'} =~ /username/i || $ai_v{'temp'}{'arg1'} =~ /password/i) {
						sendMessage(\$remote_socket, $cmd{'type'}, getResponse("confF3"), $cmd{'user'}) if $config{'verbose'};
					} else {
						$responseVars{'key'} = $ai_v{'temp'}{'arg1'};
						$responseVars{'value'} = $config{$ai_v{'temp'}{'arg1'}};
						sendMessage(\$remote_socket, $cmd{'type'}, getResponse("confS1"), $cmd{'user'}) if $config{'verbose'};
						$timeout{'ai_thanks_set'}{'time'} = time;
					}
				} else {
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
				aiRemove("route_getRoute");
				aiRemove("route_getMapRoute");
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
							print "Calculating route to: $maps_lut{$ai_v{'temp'}{'map'}.'.rsw'}($ai_v{'temp'}{'map'}): $ai_v{'temp'}{'arg1'}, $ai_v{'temp'}{'arg2'}\n";
							injectMessage("Calculating route to: $maps_lut{$ai_v{'temp'}{'map'}.'.rsw'}($ai_v{'temp'}{'map'}): $ai_v{'temp'}{'arg1'}, $ai_v{'temp'}{'arg2'}\n") if ($config{'verbose'} && $config{'XKore'});
							$ai_v{'temp'}{'x'} = $ai_v{'temp'}{'arg1'};
							$ai_v{'temp'}{'y'} = $ai_v{'temp'}{'arg2'};
						} else {
							print "Calculating route to: $maps_lut{$ai_v{'temp'}{'map'}.'.rsw'}($ai_v{'temp'}{'map'})\n";
							injectMessage("Calculating route to: $maps_lut{$ai_v{'temp'}{'map'}.'.rsw'}($ai_v{'temp'}{'map'})\n") if ($config{'verbose'} && $config{'XKore'});
							undef $ai_v{'temp'}{'x'};
							undef $ai_v{'temp'}{'y'};
						}
						sendMessage(\$remote_socket, $cmd{'type'}, getResponse("moveS"), $cmd{'user'}) if $config{'verbose'};
						ai_route(\%{$ai_v{'temp'}{'returnHash'}}, $ai_v{'temp'}{'x'}, $ai_v{'temp'}{'y'}, $ai_v{'temp'}{'map'}, 0, 0, 1, 0, 0, 1);
						$timeout{'ai_thanks_set'}{'time'} = time;
					} else {
						print "Map $ai_v{'temp'}{'map'} does not exist\n";
						injectMessage("Map $ai_v{'temp'}{'map'} does not exist\n") if ($config{'verbose'} && $config{'XKore'});
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
			
		}
		$ai_v{'temp'}{'qm'} = quotemeta $config{'callSign'};
		if ($overallAuth{$cmd{'user'}} >= 1 && ($cmd{'msg'} =~ /\b$ai_v{'temp'}{'qm'}\b/i || $cmd{'type'} eq "pm")
			&& $cmd{'msg'} =~ /\bheal\b/i) {
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
						$ai_v{'temp'}{'skillCast'}{'skill'} = 28;
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

		if ($overallAuth{$cmd{'user'}} >= 1) {
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

	if ($ai_seq[0] ne "deal" && $ai_seq[0] ne "dealAutoAccept" && %currentDeal) {
		unshift @ai_seq, "deal";
		unshift @ai_seq_args, "";
	} elsif ($ai_seq[0] eq "deal" && !%currentDeal) {
		shift @ai_seq;
		shift @ai_seq_args;
	}

	if ($config{'dealAutoCancel'} && %incomingDeal && timeOut(\%{$timeout{'ai_dealAutoCancel'}})) {
		sendDealCancel(\$remote_socket);
		$timeout{'ai_dealAutoCancel'}{'time'} = time;
	}
	if ($config{'partyAutoDeny'} && %incomingParty && timeOut(\%{$timeout{'ai_partyAutoDeny'}})) {
		sendPartyJoin(\$remote_socket, $incomingParty{'ID'}, 0);
		$timeout{'ai_partyAutoDeny'}{'time'} = time;
		undef %incomingParty;
	}
	if ($config{'guildAutoDeny'} && %incomingGuild && timeOut(\%{$timeout{'ai_guildAutoDeny'}})) {
		sendGuildJoin(\$remote_socket, $incomingGuild{'ID'}, 0) if ($incomingGuild{'Type'} == 1);
		sendGuildAlly(\$remote_socket, $incomingGuild{'ID'}, 0) if ($incomingGuild{'Type'} == 2);
		$timeout{'ai_guildAutoDeny'}{'time'} = time;
		undef %incomingGuild;
	}

	if ($ai_v{'portalTrace_mapChanged'}) {
		undef $ai_v{'portalTrace_mapChanged'};
		$ai_v{'temp'}{'first'} = 1;
		undef $ai_v{'temp'}{'foundID'};
		undef $ai_v{'temp'}{'smallDist'};
		
		foreach (@portalsID_old) {
			$ai_v{'temp'}{'dist'} = distance(\%{$chars_old[$config{'char'}]{'pos_to'}}, \%{$portals_old{$_}{'pos'}});
			if ($ai_v{'temp'}{'dist'} <= 7 && ($ai_v{'temp'}{'first'} || $ai_v{'temp'}{'dist'} < $ai_v{'temp'}{'smallDist'})) {
				$ai_v{'temp'}{'smallDist'} = $ai_v{'temp'}{'dist'};
				$ai_v{'temp'}{'foundID'} = $_;
				undef $ai_v{'temp'}{'first'};
			}
		}
		if ($ai_v{'temp'}{'foundID'}) {
			$ai_v{'portalTrace'}{'source'}{'map'} = $portals_old{$ai_v{'temp'}{'foundID'}}{'source'}{'map'};
			$ai_v{'portalTrace'}{'source'}{'ID'} = $portals_old{$ai_v{'temp'}{'foundID'}}{'nameID'};
			%{$ai_v{'portalTrace'}{'source'}{'pos'}} = %{$portals_old{$ai_v{'temp'}{'foundID'}}{'pos'}};
		}
	}

	if (%{$ai_v{'portalTrace'}} && portalExists($ai_v{'portalTrace'}{'source'}{'map'}, \%{$ai_v{'portalTrace'}{'source'}{'pos'}}) ne "") {
		undef %{$ai_v{'portalTrace'}};
	} elsif (%{$ai_v{'portalTrace'}} && $field{'name'}) {
		$ai_v{'temp'}{'first'} = 1;
		undef $ai_v{'temp'}{'foundID'};
		undef $ai_v{'temp'}{'smallDist'};
		
		foreach (@portalsID) {
			$ai_v{'temp'}{'dist'} = distance(\%{$chars[$config{'char'}]{'pos_to'}}, \%{$portals{$_}{'pos'}});
			if ($ai_v{'temp'}{'first'} || $ai_v{'temp'}{'dist'} < $ai_v{'temp'}{'smallDist'}) {
				$ai_v{'temp'}{'smallDist'} = $ai_v{'temp'}{'dist'};
				$ai_v{'temp'}{'foundID'} = $_;
				undef $ai_v{'temp'}{'first'};
			}
		}
		
		if (%{$portals{$ai_v{'temp'}{'foundID'}}}) {
			if (portalExists($field{'name'}, \%{$portals{$ai_v{'temp'}{'foundID'}}{'pos'}}) eq ""
				&& $ai_v{'portalTrace'}{'source'}{'map'} && $ai_v{'portalTrace'}{'source'}{'pos'}{'x'} ne "" && $ai_v{'portalTrace'}{'source'}{'pos'}{'y'} ne ""
				&& $field{'name'} && $portals{$ai_v{'temp'}{'foundID'}}{'pos'}{'x'} ne "" && $portals{$ai_v{'temp'}{'foundID'}}{'pos'}{'y'} ne "") {

				
				$portals{$ai_v{'temp'}{'foundID'}}{'name'} = "$field{'name'} -> $ai_v{'portalTrace'}{'source'}{'map'}";
				$portals{pack("L",$ai_v{'portalTrace'}{'source'}{'ID'})}{'name'} = "$ai_v{'portalTrace'}{'source'}{'map'} -> $field{'name'}";

				$ai_v{'temp'}{'ID'} = "$ai_v{'portalTrace'}{'source'}{'map'} $ai_v{'portalTrace'}{'source'}{'pos'}{'x'} $ai_v{'portalTrace'}{'source'}{'pos'}{'y'}";
				$portals_lut{$ai_v{'temp'}{'ID'}}{'source'}{'map'} = $ai_v{'portalTrace'}{'source'}{'map'};
				%{$portals_lut{$ai_v{'temp'}{'ID'}}{'source'}{'pos'}} = %{$ai_v{'portalTrace'}{'source'}{'pos'}};
				$portals_lut{$ai_v{'temp'}{'ID'}}{'dest'}{'map'} = $field{'name'};
				%{$portals_lut{$ai_v{'temp'}{'ID'}}{'dest'}{'pos'}} = %{$portals{$ai_v{'temp'}{'foundID'}}{'pos'}};

				updatePortalLUT("tables/portals.txt",
					$ai_v{'portalTrace'}{'source'}{'map'}, $ai_v{'portalTrace'}{'source'}{'pos'}{'x'}, $ai_v{'portalTrace'}{'source'}{'pos'}{'y'},
					$field{'name'}, $portals{$ai_v{'temp'}{'foundID'}}{'pos'}{'x'}, $portals{$ai_v{'temp'}{'foundID'}}{'pos'}{'y'});

				$ai_v{'temp'}{'ID2'} = "$field{'name'} $portals{$ai_v{'temp'}{'foundID'}}{'pos'}{'x'} $portals{$ai_v{'temp'}{'foundID'}}{'pos'}{'y'}";
				$portals_lut{$ai_v{'temp'}{'ID2'}}{'source'}{'map'} = $field{'name'};
				%{$portals_lut{$ai_v{'temp'}{'ID2'}}{'source'}{'pos'}} = %{$portals{$ai_v{'temp'}{'foundID'}}{'pos'}};
				$portals_lut{$ai_v{'temp'}{'ID2'}}{'dest'}{'map'} = $ai_v{'portalTrace'}{'source'}{'map'};
				%{$portals_lut{$ai_v{'temp'}{'ID2'}}{'dest'}{'pos'}} = %{$ai_v{'portalTrace'}{'source'}{'pos'}};

				updatePortalLUT("tables/portals.txt",
					$field{'name'}, $portals{$ai_v{'temp'}{'foundID'}}{'pos'}{'x'}, $portals{$ai_v{'temp'}{'foundID'}}{'pos'}{'y'},
					$ai_v{'portalTrace'}{'source'}{'map'}, $ai_v{'portalTrace'}{'source'}{'pos'}{'x'}, $ai_v{'portalTrace'}{'source'}{'pos'}{'y'});
			}
			undef %{$ai_v{'portalTrace'}};
		}
	}


	if ($config{'XKore'} && !$sentWelcomeMessage && timeOut(\%{$timeout{'welcomeText'}})) {
		injectAdminMessage($welcomeText) if ($config{'verbose'});
		$sentWelcomeMessage = 1;
	}


	##### CLIENT SUSPEND #####
	# The clientSuspend AI sequence is used to freeze all other AI activity
	# for a certain period of time.

	if ($ai_seq[0] eq "clientSuspend" && timeOut(\%{$ai_seq_args[0]})) {
		shift @ai_seq;
		shift @ai_seq_args;
	} elsif ($ai_seq[0] eq "clientSuspend" && $config{'XKore'}) {
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
	}

	############### START XLR82XS ###################
	# This is my really really really funky way of dealing with all the red socks with holes that I constantly pick up
	# However, it can just as easily be used to have your bot convert any * herb + empty bottles that it picks up into a potion
	# Not much of the real meat is done here (strangly enough) basically, if itemExchange is turned on in config.txt
	# and ai_itemExchangeCheck returns true, it'll move to the npc designated by itemExchange_npc in config.txt and talk to them
	# The sequence it sends the npc is controlled by itemExchange_steps in config.txt so its easy to set it up to do juice, or potions
	# or red socks, or whatever.
	#  accepts only one input, "minimum"
	# more about that near the sub ;)

	ITEMEXCHANGE: {

		if (($ai_seq[0] eq "" || $ai_seq[0] eq "route") && $config{'itemExchange'} && $config{'itemExchange_npc'} ne "" && ai_itemExchangeCheck()) {
			$ai_v{'temp'}{'ai_route_index'} = binFind(\@ai_seq, "route");
			if ($ai_v{'temp'}{'ai_route_index'} ne "") {
				$ai_v{'temp'}{'ai_route_attackOnRoute'} = $ai_seq_args[$ai_v{'temp'}{'ai_route_index'}]{'attackOnRoute'};
			}
			if (!($ai_v{'temp'}{'ai_route_index'} ne "" && $ai_v{'temp'}{'ai_route_attackOnRoute'} <= 1)) {
				unshift @ai_seq, "itemExchange";
				unshift @ai_seq_args, {};
			}
		}

		if ($ai_seq[0] eq "itemExchange" && timeOut(\%{$timeout{'ai_itemExchange'}})) {
			if (!$config{'itemExchange'} || !%{$npcs_lut{$config{'itemExchange_npc'}}}) {
				$ai_seq_args[0]{'done'} = 1;
				last ITEMEXCHANGE;
			}

			undef $ai_v{'temp'}{'do_route'};
			if ($field{'name'} ne $npcs_lut{$config{'itemExchange_npc'}}{'map'}) {
				$ai_v{'temp'}{'do_route'} = 1;
			} else {
				$ai_v{'temp'}{'distance'} = distance(\%{$npcs_lut{$config{'itemExchange_npc'}}{'pos'}}, \%{$chars[$config{'char'}]{'pos_to'}});
				if ($ai_v{'temp'}{'distance'} > 14) {
					$ai_v{'temp'}{'do_route'} = 1;
				}
			}

			if ($ai_v{'temp'}{'do_route'}) {
				print "Calculating auto-exchange route to: $maps_lut{$npcs_lut{$config{'itemExchange_npc'}}{'map'}.'.rsw'}($npcs_lut{$config{'itemExchange_npc'}}{'map'}): $npcs_lut{$config{'itemExchange_npc'}}{'pos'}{'x'}, $npcs_lut{$config{'itemExchange_npc'}}{'pos'}{'y'}\n";
				injectMessage("Calculating auto-exchange route to: $maps_lut{$npcs_lut{$config{'itemExchange_npc'}}{'map'}.'.rsw'}($npcs_lut{$config{'itemExchange_npc'}}{'map'}): $npcs_lut{$config{'itemExchange_npc'}}{'pos'}{'x'}, $npcs_lut{$config{'itemExchange_npc'}}{'pos'}{'y'}\n") if ($config{'XKore'});
				ai_route(\%{$ai_v{'temp'}{'returnHash'}}, $npcs_lut{$config{'itemExchange_npc'}}{'pos'}{'x'}, $npcs_lut{$config{'itemExchange_npc'}}{'pos'}{'y'}, $npcs_lut{$config{'itemExchange_npc'}}{'map'}, 0, 0, 1, 0, 0, 1);
			}

		} elsif ($config{'itemExchange'}) {
			my $temp = "minimum";
			while (ai_itemExchangeCheck($temp)) {
				@{$ai_seq_args[0]{'npc'}{'steps'}} = split(/ /, $config{'itemExchange_steps'});
				if ($ai_seq_args[0]{'npc'}{'steps'}[$ai_seq_args[0]{'npc'}{'step'}] =~ /c/i) {
					sendTalkContinue(\$remote_socket, pack("L1",$config{'itemExchange_npc'}));
					$ai_seq_args[0]{'npc'}{'step'}++;
				} elsif ($ai_seq_args[0]{'npc'}{'steps'}[$ai_seq_args[0]{'npc'}{'step'}] =~ /n/i) {
					sendTalkCancel(\$remote_socket, pack("L1",$config{'itemExchange_npc'}));
					$ai_seq_args[0]{'npc'}{'step'}++;
				} else {
					($ai_v{'temp'}{'arg'}) = $ai_seq_args[0]{'npc'}{'steps'}[$ai_seq_args[0]{'npc'}{'step'}] =~ /r(\d+)/i;
					if ($ai_v{'temp'}{'arg'} ne "") {
						$ai_v{'temp'}{'arg'}++;
						sendTalkResponse(\$remote_socket, pack("L1",$config{'itemExchange_npc'}), $ai_v{'temp'}{'arg'});
					}
				}
				$ai_seq_args[0]{'npc'}{'step'}++;
			} last ITEMEXCHANGE;
		}
	}
	######### END XLR82XS ##############


	#storageAuto - chobit aska 20030128
	#####AUTO STORAGE#####

	AUTOSTORAGE: {

	if (($ai_seq[0] eq "" || $ai_seq[0] eq "route") && $config{'storageAuto'} && $config{'storageAuto_npc'} ne "" && percent_weight(\%{$chars[$config{'char'}]}) >= $config{'itemsMaxWeight'}) {
		$ai_v{'temp'}{'ai_route_index'} = binFind(\@ai_seq, "route");
		if ($ai_v{'temp'}{'ai_route_index'} ne "") {
			$ai_v{'temp'}{'ai_route_attackOnRoute'} = $ai_seq_args[$ai_v{'temp'}{'ai_route_index'}]{'attackOnRoute'};
		}
		if (!($ai_v{'temp'}{'ai_route_index'} ne "" && $ai_v{'temp'}{'ai_route_attackOnRoute'} <= 1) && ai_storageAutoCheck()) {
			unshift @ai_seq, "storageAuto";
			unshift @ai_seq_args, {};
		}
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
		if (!$config{'storageAuto'} || !%{$npcs_lut{$config{'storageAuto_npc'}}}) {
			$ai_seq_args[0]{'done'} = 1;
			last AUTOSTORAGE;
		}

		undef $ai_v{'temp'}{'do_route'};
		if ($field{'name'} ne $npcs_lut{$config{'storageAuto_npc'}}{'map'}) {
			$ai_v{'temp'}{'do_route'} = 1;
		} else {
			$ai_v{'temp'}{'distance'} = distance(\%{$npcs_lut{$config{'storageAuto_npc'}}{'pos'}}, \%{$chars[$config{'char'}]{'pos_to'}});
			if ($ai_v{'temp'}{'distance'} > 14) {
				$ai_v{'temp'}{'do_route'} = 1;
			}
		}
		if ($ai_v{'temp'}{'do_route'}) {
			if ($ai_seq_args[0]{'warpedToSave'} && !$ai_seq_args[0]{'mapChanged'}) {
				undef $ai_seq_args[0]{'warpedToSave'};
			}
#Solos Start
			if ($config{'saveMap'} ne "" && $config{'saveMap_warpToBuyOrSell'} && !$ai_seq_args[0]{'warpedToSave'} 
				&& !$cities_lut{$field{'name'}.'.rsw'}) {
				$ai_seq_args[0]{'warpedToSave'} = 1;
				useTeleport(2);
#Solos End
				$timeout{'ai_storageAuto'}{'time'} = time;
			} else {
				if (!$config{'XKore'}) {
					print "Calculating auto-storage route to: $maps_lut{$npcs_lut{$config{'storageAuto_npc'}}{'map'}.'.rsw'}($npcs_lut{$config{'storageAuto_npc'}}{'map'}): $npcs_lut{$config{'storageAuto_npc'}}{'pos'}{'x'}, $npcs_lut{$config{'storageAuto_npc'}}{'pos'}{'y'}\n";
				} else {
					injectMessage("Calculating auto-storage route to: $maps_lut{$npcs_lut{$config{'storageAuto_npc'}}{'map'}.'.rsw'}($npcs_lut{$config{'storageAuto_npc'}}{'map'}): $npcs_lut{$config{'storageAuto_npc'}}{'pos'}{'x'}, $npcs_lut{$config{'storageAuto_npc'}}{'pos'}{'y'}\n");
				}
				ai_route(\%{$ai_v{'temp'}{'returnHash'}}, $npcs_lut{$config{'storageAuto_npc'}}{'pos'}{'x'}, $npcs_lut{$config{'storageAuto_npc'}}{'pos'}{'y'}, $npcs_lut{$config{'storageAuto_npc'}}{'map'}, 0, 0, 1, 0, 0, 1);
			}
		} else {
			if ($ai_seq_args[0]{'sentStore'} <= 1) {
				sendTalk(\$remote_socket, pack("L1",$config{'storageAuto_npc'})) if !$ai_seq_args[0]{'sentStore'};
				sendTalkContinue(\$remote_socket, pack("L1",$config{'storageAuto_npc'})) if !$ai_seq_args[0]{'sentStore'};
				sendTalkResponse(\$remote_socket, pack("L1",$config{'storageAuto_npc'}),'2') if !$ai_seq_args[0]{'sentStore'};
				$ai_seq_args[0]{'sentStore'}++;
				$timeout{'ai_storageAuto'}{'time'} = time;
				last AUTOSTORAGE;
			}
			$ai_seq_args[0]{'done'} = 1;
			for ($i = 0; $i < @{$chars[$config{'char'}]{'inventory'}};$i++) {
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
					last AUTOSTORAGE;
				}
			}
			sendStorageClose(\$remote_socket);
		}
	}

	} #END OF BLOCK AUTOSTORAGE



	#####AUTO SELL#####

	AUTOSELL: {

	if (($ai_seq[0] eq "" || $ai_seq[0] eq "route") && $config{'sellAuto'} && $config{'sellAuto_npc'} ne "" && percent_weight(\%{$chars[$config{'char'}]}) >= $config{'itemsMaxWeight'}) {
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
		if (!$config{'sellAuto'} || !%{$npcs_lut{$config{'sellAuto_npc'}}}) {
			$ai_seq_args[0]{'done'} = 1;
			last AUTOSELL;
		}

		undef $ai_v{'temp'}{'do_route'};
		if ($field{'name'} ne $npcs_lut{$config{'sellAuto_npc'}}{'map'}) {
			$ai_v{'temp'}{'do_route'} = 1;
		} else {
			$ai_v{'temp'}{'distance'} = distance(\%{$npcs_lut{$config{'sellAuto_npc'}}{'pos'}}, \%{$chars[$config{'char'}]{'pos_to'}});
			if ($ai_v{'temp'}{'distance'} > 14) {
				$ai_v{'temp'}{'do_route'} = 1;
			}
		}
		if ($ai_v{'temp'}{'do_route'}) {
			if ($ai_seq_args[0]{'warpedToSave'} && !$ai_seq_args[0]{'mapChanged'}) {
				undef $ai_seq_args[0]{'warpedToSave'};
			}
#Solos Start
			if ($config{'saveMap'} ne "" && $config{'saveMap_warpToBuyOrSell'} && !$ai_seq_args[0]{'warpedToSave'} 
				&& !$cities_lut{$field{'name'}.'.rsw'}) {
				$ai_seq_args[0]{'warpedToSave'} = 1;
				useTeleport(2);
#Solos End
				$timeout{'ai_sellAuto'}{'time'} = time;
			} else {
				if (!$config{'XKore'}) {
					print "Calculating auto-sell route to: $maps_lut{$npcs_lut{$config{'sellAuto_npc'}}{'map'}.'.rsw'}($npcs_lut{$config{'sellAuto_npc'}}{'map'}): $npcs_lut{$config{'sellAuto_npc'}}{'pos'}{'x'}, $npcs_lut{$config{'sellAuto_npc'}}{'pos'}{'y'}\n";
				} else {
					injectMessage("Calculating auto-sell route to: $maps_lut{$npcs_lut{$config{'sellAuto_npc'}}{'map'}.'.rsw'}($npcs_lut{$config{'sellAuto_npc'}}{'map'}): $npcs_lut{$config{'sellAuto_npc'}}{'pos'}{'x'}, $npcs_lut{$config{'sellAuto_npc'}}{'pos'}{'y'}\n");
				}
				ai_route(\%{$ai_v{'temp'}{'returnHash'}}, $npcs_lut{$config{'sellAuto_npc'}}{'pos'}{'x'}, $npcs_lut{$config{'sellAuto_npc'}}{'pos'}{'y'}, $npcs_lut{$config{'sellAuto_npc'}}{'map'}, 0, 0, 1, 0, 0, 1);
			}
		} else {
			if ($ai_seq_args[0]{'sentSell'} <= 1) {
				sendTalk(\$remote_socket, pack("L1",$config{'sellAuto_npc'})) if !$ai_seq_args[0]{'sentSell'};
				sendGetSellList(\$remote_socket, pack("L1",$config{'sellAuto_npc'})) if $ai_seq_args[0]{'sentSell'};
				$ai_seq_args[0]{'sentSell'}++;
				$timeout{'ai_sellAuto'}{'time'} = time;
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

	if (($ai_seq[0] eq "" || $ai_seq[0] eq "route" 
#Solos Start
	|| $ai_seq[0] eq "attack"
#Solos End
	) && timeOut(\%{$timeout{'ai_buyAuto'}})) {
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
			last if (!$config{"buyAuto_$i"} || !%{$npcs_lut{$config{"buyAuto_$i"."_npc"}}});
			$ai_seq_args[0]{'invIndex'} = findIndexString_lc(\@{$chars[$config{'char'}]{'inventory'}}, "name", $config{"buyAuto_$i"});
			if (!$ai_seq_args[0]{'index_failed'}{$i} && $config{"buyAuto_$i"."_maxAmount"} ne "" && ($ai_seq_args[0]{'invIndex'} eq "" 
				|| $chars[$config{'char'}]{'inventory'}[$ai_seq_args[0]{'invIndex'}]{'amount'} < $config{"buyAuto_$i"."_maxAmount"})) {
				$ai_seq_args[0]{'index'} = $i;
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
		if ($field{'name'} ne $npcs_lut{$config{"buyAuto_$ai_seq_args[0]{'index'}"."_npc"}}{'map'}) {
			$ai_v{'temp'}{'do_route'} = 1;			
		} else {
			$ai_v{'temp'}{'distance'} = distance(\%{$npcs_lut{$config{"buyAuto_$ai_seq_args[0]{'index'}"."_npc"}}{'pos'}}, \%{$chars[$config{'char'}]{'pos_to'}});
			if ($ai_v{'temp'}{'distance'} > 14) {
				$ai_v{'temp'}{'do_route'} = 1;
			}
		}
		if ($ai_v{'temp'}{'do_route'}) {
			if ($ai_seq_args[0]{'warpedToSave'} && !$ai_seq_args[0]{'mapChanged'}) {
				undef $ai_seq_args[0]{'warpedToSave'};
			}
#Solos Start
			if ($config{'saveMap'} ne "" && $config{'saveMap_warpToBuyOrSell'} && !$ai_seq_args[0]{'warpedToSave'} 
				&& !$cities_lut{$field{'name'}.'.rsw'}) {
				$ai_seq_args[0]{'warpedToSave'} = 1;
				useTeleport(2);
#Solos End
				$timeout{'ai_buyAuto_wait'}{'time'} = time;
			} else {
				if (!$config{'XKore'}) {
					print qq~Calculating auto-buy route to: $maps_lut{$npcs_lut{$config{"buyAuto_$ai_seq_args[0]{'index'}"."_npc"}}{'map'}.'.rsw'}($npcs_lut{$config{"buyAuto_$ai_seq_args[0]{'index'}"."_npc"}}{'map'}): $npcs_lut{$config{"buyAuto_$ai_seq_args[0]{'index'}"."_npc"}}{'pos'}{'x'}, $npcs_lut{$config{"buyAuto_$ai_seq_args[0]{'index'}"."_npc"}}{'pos'}{'y'}\n~;
				} else {
					injectMessage(qq~Calculating auto-buy route to: $maps_lut{$npcs_lut{$config{"buyAuto_$ai_seq_args[0]{'index'}"."_npc"}}{'map'}.'.rsw'}($npcs_lut{$config{"buyAuto_$ai_seq_args[0]{'index'}"."_npc"}}{'map'}): $npcs_lut{$config{"buyAuto_$ai_seq_args[0]{'index'}"."_npc"}}{'pos'}{'x'}, $npcs_lut{$config{"buyAuto_$ai_seq_args[0]{'index'}"."_npc"}}{'pos'}{'y'}~) if ($config{'verbose'});
				}
				ai_route(\%{$ai_v{'temp'}{'returnHash'}}, $npcs_lut{$config{"buyAuto_$ai_seq_args[0]{'index'}"."_npc"}}{'pos'}{'x'}, $npcs_lut{$config{"buyAuto_$ai_seq_args[0]{'index'}"."_npc"}}{'pos'}{'y'}, $npcs_lut{$config{"buyAuto_$ai_seq_args[0]{'index'}"."_npc"}}{'map'}, 0, 0, 1, 0, 0, 1);
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
					print "autoBuy index $ai_seq_args[0]{'index'} failed\n" if $config{'debug'};
					last AUTOBUY;
				}
			}

			if ($ai_seq_args[0]{'sentBuy'} <= 1) {
				sendTalk(\$remote_socket, pack("L1",$config{"buyAuto_$ai_seq_args[0]{'index'}"."_npc"})) if !$ai_seq_args[0]{'sentBuy'};
				sendGetStoreList(\$remote_socket, pack("L1",$config{"buyAuto_$ai_seq_args[0]{'index'}"."_npc"})) if $ai_seq_args[0]{'sentBuy'};
				$ai_seq_args[0]{'sentBuy'}++;
				$timeout{'ai_buyAuto_wait'}{'time'} = time;
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
	

	if ($ai_seq[0] eq "" && $config{'lockMap'} && $field{'name'} 
		&& ($field{'name'} ne $config{'lockMap'} || ($config{'lockMap_x'} ne "" && ($chars[$config{'char'}]{'pos_to'}{'x'} != $config{'lockMap_x'} || $chars[$config{'char'}]{'pos_to'}{'y'} != $config{'lockMap_y'})))) {
		if ($maps_lut{$config{'lockMap'}.'.rsw'} eq "") {
			if (!$config{'XKore'}) {
				print "Invalid map specified for lockMap - map $config{'lockMap'} doesn't exist\n";
			} else {
				injectMessage("Invalid map specified for lockMap - map $config{'lockMap'} doesn't exist") if ($config{'verbose'});
			}
		} else {
			if ($config{'lockMap_x'} ne "") {
				if (!$config{'XKore'}) {
					print "Calculating lockMap route to: $maps_lut{$config{'lockMap'}.'.rsw'}($config{'lockMap'}): $config{'lockMap_x'}, $config{'lockMap_y'}\n";
				} else {
					injectMessage("Calculating lockMap route to: $maps_lut{$config{'lockMap'}.'.rsw'}($config{'lockMap'}): $config{'lockMap_x'}, $config{'lockMap_y'}") if ($config{'verbose'});
				}
			} else {
				if (!$config{'XKore'}) {
					print "Calculating lockMap route to: $maps_lut{$config{'lockMap'}.'.rsw'}($config{'lockMap'})\n";
				} else {
					injectMessage("Calculating lockMap route to: $maps_lut{$config{'lockMap'}.'.rsw'}($config{'lockMap'})") if ($config{'verbose'});
				}
			}
			ai_route(\%{$ai_v{'temp'}{'returnHash'}}, $config{'lockMap_x'}, $config{'lockMap_y'}, $config{'lockMap'}, 0, 0, 1, 0, 0, 1);
		}
	}

	##### RANDOM WALK #####
	if ($config{'route_randomWalk'} && $ai_seq[0] eq "" && @{$field{'field'}} > 1 && !$cities_lut{$field{'name'}.'.rsw'}) {
		do { 
			$ai_v{'temp'}{'randX'} = int(rand() * ($field{'width'} - 1));
			$ai_v{'temp'}{'randY'} = int(rand() * ($field{'height'} - 1));
		} while ($field{'field'}[$ai_v{'temp'}{'randY'}*$field{'width'} + $ai_v{'temp'}{'randX'}]);
		print "Calculating random route to: $maps_lut{$field{'name'}.'.rsw'}($field{'name'}): $ai_v{'temp'}{'randX'}, $ai_v{'temp'}{'randY'}\n";
		injectMessage("Calculating random route to: $maps_lut{$field{'name'}.'.rsw'}($field{'name'}): $ai_v{'temp'}{'randX'}, $ai_v{'temp'}{'randY'}") if ($config{'verbose'} && $config{'XKore'});
		ai_route(\%{$ai_v{'temp'}{'returnHash'}}, $ai_v{'temp'}{'randX'}, $ai_v{'temp'}{'randY'}, $field{'name'}, 0, $config{'route_randomWalk_maxRouteTime'}, 2, undef, undef, 1);
	}

	##### DEAD #####


	if ($ai_seq[0] eq "dead" && !$chars[$config{'char'}]{'dead'}) {
		shift @ai_seq;
		shift @ai_seq_args;

		#force storage after death
		unshift @ai_seq, "storageAuto";
		unshift @ai_seq_args, {};
	} elsif ($ai_seq[0] ne "dead" && $chars[$config{'char'}]{'dead'}) {
		undef @ai_seq;
		undef @ai_seq_args;
		unshift @ai_seq, "dead";
		unshift @ai_seq_args, {};
	}
	
	if ($ai_seq[0] eq "dead" && time - $chars[$config{'char'}]{'dead_time'} >= $timeout{'ai_dead_respawn'}{'timeout'}) {
		sendRespawn(\$remote_socket);
		$chars[$config{'char'}]{'dead_time'} = time;
	}
	
	if ($ai_seq[0] eq "dead" && $config{'dcOnDeath'}) {
		if (!$config{'XKore'}) {
			print "Disconnecting on death!\n";
		} else {
			injectMessage("Disconnecting on death!") if ($config{'verbose'});
		}
		$quit = 1;
	}


	##### AUTO-ITEM USE #####


	if (($ai_seq[0] eq "" || $ai_seq[0] eq "route" || $ai_seq[0] eq "route_getRoute" || $ai_seq[0] eq "route_getMapRoute" || $ai_seq[0] eq "follow" || $ai_seq[0] eq "sitAuto" || $ai_seq[0] eq "take" || $ai_seq[0] eq "items_gather" || $ai_seq[0] eq "items_take"
#Solos Start
		|| $ai_seq[0] eq "attack"
#Solos End
	)
		&& timeOut(\%{$timeout{'ai_item_use_auto'}})) { 
		$i = 0;
		while (1) {
			last if (!$config{"useSelf_item_$i"});
			if (percent_hp(\%{$chars[$config{'char'}]}) <= $config{"useSelf_item_$i"."_hp_upper"} && percent_hp(\%{$chars[$config{'char'}]}) >= $config{"useSelf_item_$i"."_hp_lower"}
				&& percent_sp(\%{$chars[$config{'char'}]}) <= $config{"useSelf_item_$i"."_sp_upper"} && percent_sp(\%{$chars[$config{'char'}]}) >= $config{"useSelf_item_$i"."_sp_lower"}
				&& !($config{"useSelf_item_$i"."_stopWhenHit"} && ai_getMonstersWhoHitMe())
				&& $config{"useSelf_item_$i"."_minAggressives"} <= ai_getAggressives()
				&& (!$config{"useSelf_item_$i"."_maxAggressives"} || $config{"useSelf_item_$i"."_maxAggressives"} >= ai_getAggressives()) 
            			&& timeOut($ai_v{"useSelf_item_$i"."_time"}, $config{"useSelf_item_$i"."_timeout"})
            			&& (!$config{"useSelf_item_$i"."_inLockOnly"} || ($config{"useSelf_item_$i"."_inLockOnly"} && $field{'name'} eq $config{'lockMap'}))) {
				undef $ai_v{'temp'}{'invIndex'};
				$ai_v{'temp'}{'invIndex'} = findIndexString_lc(\@{$chars[$config{'char'}]{'inventory'}}, "name", $config{"useSelf_item_$i"});
				$ai_v{"useSelf_item_$i"."_time"} = time;
				if ($ai_v{'temp'}{'invIndex'} ne "") {
					sendItemUse(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$ai_v{'temp'}{'invIndex'}]{'index'}, $accountID);
					$timeout{'ai_item_use_auto'}{'time'} = time;
					print qq~Auto-item use: $items_lut{$chars[$config{'char'}]{'inventory'}[$ai_v{'temp'}{'invIndex'}]{'nameID'}}\n~ if $config{'debug'};
					last;
				}
			}
			$i++;
		}
	}

#Solos Start
	##### AUTO-EQUIP #####

	if (($ai_seq[0] eq "" || $ai_seq[0] eq "route" || $ai_seq[0] eq "route_getRoute" || 
	     $ai_seq[0] eq "route_getMapRoute" || $ai_seq[0] eq "follow" || $ai_seq[0] eq "sitAuto" || 
		 $ai_seq[0] eq "take" || $ai_seq[0] eq "items_gather" || $ai_seq[0] eq "items_take" || 
		 $ai_seq[0] eq "attack"
	)
		&& timeOut(\%{$timeout{'ai_item_equip_auto'}}) 
		&& ($config{"autoEquip_item_card_new"} ne "")) { 
			if (percent_hp(\%{$chars[$config{'char'}]}) <= $config{"autoEquip_item_hp"} && 
				percent_sp(\%{$chars[$config{'char'}]}) >= $config{"autoEquip_item_sp"}) {
				undef $ai_v{'temp'}{'invIndex'};
				$ai_v{'temp'}{'invIndex'} = findIndexString_lc_not_equip(\@{$chars[$config{'char'}]{'inventory'}}, "slotName", $config{"autoEquip_item_card_new"});
				if ($ai_v{'temp'}{'invIndex'} ne "") {
					sendEquip(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$ai_v{'temp'}{'invIndex'}]{'index'}, $chars[$config{'char'}]{'inventory'}[$ai_v{'temp'}{'invIndex'}]{'type_equip'}, 0);
					$timeout{'ai_item_equip_auto'}{'time'} = time;
					print qq~Auto-equip: $items_lut{$chars[$config{'char'}]{'inventory'}[$ai_v{'temp'}{'invIndex'}]{'nameID'}}\n~ if $config{'debug'};
				}
			} else {
				undef $ai_v{'temp'}{'invIndex'};
				$ai_v{'temp'}{'invIndex'} = findIndexString_lc_not_equip(\@{$chars[$config{'char'}]{'inventory'}}, "slotName", $config{"autoEquip_item_card_def"});
				if ($ai_v{'temp'}{'invIndex'} ne "") {
					sendEquip(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$ai_v{'temp'}{'invIndex'}]{'index'}, $chars[$config{'char'}]{'inventory'}[$ai_v{'temp'}{'invIndex'}]{'type_equip'}, 0);					
					$timeout{'ai_item_equip_auto'}{'time'} = time;
					print qq~Auto-equip: $items_lut{$chars[$config{'char'}]{'inventory'}[$ai_v{'temp'}{'invIndex'}]{'nameID'}}\n~ if $config{'debug'};
				}
			}
	}
#Solos End


	##### AUTO-SKILL USE #####


	if ($ai_seq[0] eq "" || $ai_seq[0] eq "route" || $ai_seq[0] eq "route_getRoute" || $ai_seq[0] eq "route_getMapRoute" || $ai_seq[0] eq "follow" || $ai_seq[0] eq "sitAuto" || $ai_seq[0] eq "take" || $ai_seq[0] eq "items_gather" || $ai_seq[0] eq "items_take"
#Solos Start
		|| $ai_seq[0] eq "attack"
#Solos End
	   	) {
		$i = 0;
		undef $ai_v{'useSelf_skill'};
		undef $ai_v{'useSelf_skill_lvl'};
		while (1) {
			last if (!$config{"useSelf_skill_$i"});
			if (percent_hp(\%{$chars[$config{'char'}]}) <= $config{"useSelf_skill_$i"."_hp_upper"} && percent_hp(\%{$chars[$config{'char'}]}) >= $config{"useSelf_skill_$i"."_hp_lower"}
				&& percent_sp(\%{$chars[$config{'char'}]}) <= $config{"useSelf_skill_$i"."_sp_upper"} && percent_sp(\%{$chars[$config{'char'}]}) >= $config{"useSelf_skill_$i"."_sp_lower"}
				&& $chars[$config{'char'}]{'sp'} >= $skillsSP_lut{$skills_rlut{lc($config{"useSelf_skill_$i"})}}{$config{"useSelf_skill_$i"."_lvl"}}
				&& timeOut($config{"useSelf_skill_$i"."_timeout"}, $ai_v{"useSelf_skill_$i"."_time"})
				&& !($config{"useSelf_skill_$i"."_stopWhenHit"} && ai_getMonstersWhoHitMe())
				&& $config{"useSelf_skill_$i"."_minAggressives"} <= ai_getAggressives()
				&& (!$config{"useSelf_skill_$i"."_maxAggressives"} || $config{"useSelf_skill_$i"."_maxAggressives"} >= ai_getAggressives())) {
				$ai_v{"useSelf_skill_$i"."_time"} = time;
				$ai_v{'useSelf_skill'} = $config{"useSelf_skill_$i"};
				$ai_v{'useSelf_skill_lvl'} = $config{"useSelf_skill_$i"."_lvl"};
				$ai_v{'useSelf_skill_maxCastTime'} = $config{"useSelf_skill_$i"."_maxCastTime"};
				$ai_v{'useSelf_skill_minCastTime'} = $config{"useSelf_skill_$i"."_minCastTime"};
				last;
			}
			$i++;
		}
		if ($config{'useSelf_skill_smartHeal'} && $skills_rlut{lc($ai_v{'useSelf_skill'})} eq "AL_HEAL") {
			undef $ai_v{'useSelf_skill_smartHeal_lvl'};
			$ai_v{'useSelf_skill_smartHeal_hp_dif'} = $chars[$config{'char'}]{'hp_max'} - $chars[$config{'char'}]{'hp'};
			for ($i = 1; $i <= $chars[$config{'char'}]{'skills'}{$skills_rlut{lc($ai_v{'useSelf_skill'})}}{'lv'}; $i++) {
				$ai_v{'useSelf_skill_smartHeal_lvl'} = $i;
				$ai_v{'useSelf_skill_smartHeal_sp'} = 10 + ($i * 3);
				$ai_v{'useSelf_skill_smartHeal_amount'} = int(($chars[$config{'char'}]{'lv'} + $chars[$config{'char'}]{'int'}) / 8)
						* (4 + $i * 8);
				if ($chars[$config{'char'}]{'sp'} < $ai_v{'useSelf_skill_smartHeal_sp'}) {
					$ai_v{'useSelf_skill_smartHeal_lvl'}--;
					last;
				}
				last if ($ai_v{'useSelf_skill_smartHeal_amount'} >= $ai_v{'useSelf_skill_smartHeal_hp_dif'});
			}
			$ai_v{'useSelf_skill_lvl'} = $ai_v{'useSelf_skill_smartHeal_lvl'};
		}
		if ($ai_v{'useSelf_skill_lvl'} > 0) {
			print qq~Auto-skill on self: $skills_lut{$skills_rlut{lc($ai_v{'useSelf_skill'})}} (lvl $ai_v{'useSelf_skill_lvl'})\n~ if $config{'debug'};
			if (!ai_getSkillUseType($skills_rlut{lc($ai_v{'useSelf_skill'})})) {
				ai_skillUse($chars[$config{'char'}]{'skills'}{$skills_rlut{lc($ai_v{'useSelf_skill'})}}{'ID'}, $ai_v{'useSelf_skill_lvl'}, $ai_v{'useSelf_skill_maxCastTime'}, $ai_v{'useSelf_skill_minCastTime'}, $accountID);
			} else {
				ai_skillUse($chars[$config{'char'}]{'skills'}{$skills_rlut{lc($ai_v{'useSelf_skill'})}}{'ID'}, $ai_v{'useSelf_skill_lvl'}, $ai_v{'useSelf_skill_maxCastTime'}, $ai_v{'useSelf_skill_minCastTime'}, $chars[$config{'char'}]{'pos_to'}{'x'}, $chars[$config{'char'}]{'pos_to'}{'y'});
			}
		}
	}



	##### SKILL USE #####


	if ($ai_seq[0] eq "skill_use" && $ai_seq_args[0]{'suspended'}) {
		$ai_seq_args[0]{'ai_skill_use_giveup'}{'time'} += time - $ai_seq_args[0]{'suspended'};
		$ai_seq_args[0]{'ai_skill_use_minCastTime'}{'time'} += time - $ai_seq_args[0]{'suspended'};
		$ai_seq_args[0]{'ai_skill_use_maxCastTime'}{'time'} += time - $ai_seq_args[0]{'suspended'};
		undef $ai_seq_args[0]{'suspended'};
	}
	if ($ai_seq[0] eq "skill_use") {
		if ($chars[$config{'char'}]{'sitting'}) {
			ai_setSuspend(0);
			stand();
		} elsif (!$ai_seq_args[0]{'skill_used'}) {
			$ai_seq_args[0]{'skill_used'} = 1;
			$ai_seq_args[0]{'ai_skill_use_giveup'}{'time'} = time;
			if ($ai_seq_args[0]{'skill_use_target_x'} ne "") {
				sendSkillUseLoc(\$remote_socket, $ai_seq_args[0]{'skill_use_id'}, $ai_seq_args[0]{'skill_use_lv'}, $ai_seq_args[0]{'skill_use_target_x'}, $ai_seq_args[0]{'skill_use_target_y'});
			} else {
				sendSkillUse(\$remote_socket, $ai_seq_args[0]{'skill_use_id'}, $ai_seq_args[0]{'skill_use_lv'}, $ai_seq_args[0]{'skill_use_target'});
			}
			$ai_seq_args[0]{'skill_use_last'} = $chars[$config{'char'}]{'skills'}{$skills_rlut{lc($skillsID_lut{$ai_seq_args[0]{'skill_use_id'}})}}{'time_used'};

		} elsif (($ai_seq_args[0]{'skill_use_last'} != $chars[$config{'char'}]{'skills'}{$skills_rlut{lc($skillsID_lut{$ai_seq_args[0]{'skill_use_id'}})}}{'time_used'}
			|| (timeOut(\%{$ai_seq_args[0]{'ai_skill_use_giveup'}}) && (!$chars[$config{'char'}]{'time_cast'} || !$ai_seq_args[0]{'skill_use_maxCastTime'}{'timeout'}))
			|| ($ai_seq_args[0]{'skill_use_maxCastTime'}{'timeout'} && timeOut(\%{$ai_seq_args[0]{'skill_use_maxCastTime'}})))
			&& timeOut(\%{$ai_seq_args[0]{'skill_use_minCastTime'}})) {
			shift @ai_seq;
			shift @ai_seq_args;
		}
	}



	
	##### FOLLOW #####


	if ($ai_seq[0] eq "" && $config{'follow'}) {
		ai_follow($config{'followTarget'});
	}
	if ($ai_seq[0] eq "follow" && $ai_seq_args[0]{'suspended'}) {
		if ($ai_seq_args[0]{'ai_follow_lost'}) {
			$ai_seq_args[0]{'ai_follow_lost_end'}{'time'} += time - $ai_seq_args[0]{'suspended'};
		}
		undef $ai_seq_args[0]{'suspended'};
	}
	if ($ai_seq[0] eq "follow" && !$ai_seq_args[0]{'ai_follow_lost'}) {
		if (!$ai_seq_args[0]{'following'}) {
			foreach (keys %players) {
				if ($players{$_}{'name'} eq $ai_seq_args[0]{'name'} && !$players{$_}{'dead'}) {
					$ai_seq_args[0]{'ID'} = $_;
					$ai_seq_args[0]{'following'} = 1;
					last;
				}
			}
		}
		if ($ai_seq_args[0]{'following'} && $players{$ai_seq_args[0]{'ID'}}{'pos_to'}) {
			$ai_v{'temp'}{'dist'} = distance(\%{$chars[$config{'char'}]{'pos_to'}}, \%{$players{$ai_seq_args[0]{'ID'}}{'pos_to'}});
			if ($ai_v{'temp'}{'dist'} > $config{'followDistanceMax'}) {
				if ($ai_v{'temp'}{'dist'} > 15) {
					ai_route(\%{$ai_seq_args[0]{'ai_route_returnHash'}}, $players{$ai_seq_args[0]{'ID'}}{'pos_to'}{'x'}, $players{$ai_seq_args[0]{'ID'}}{'pos_to'}{'y'}, $field{'name'}, 0, 0, 1, 0, $config{'followDistanceMin'});
				} else {
					my $dist = distance(\%{$chars[$config{'char'}]{'pos_to'}}, \%{$players{$ai_seq_args[0]{'ID'}}{'pos_to'}});
					my (%vec, %pos);

					getVector(\%vec, \%{$players{$ai_seq_args[0]{'ID'}}{'pos_to'}}, \%{$chars[$config{'char'}]{'pos_to'}});
					moveAlongVector(\%pos, \%{$chars[$config{'char'}]{'pos_to'}}, \%vec, $dist - $config{'followDistanceMin'});
					sendMove(\$remote_socket, $pos{'x'}, $pos{'y'});
				}
			}
		}
		if ($ai_seq_args[0]{'following'} && %{$players{$ai_seq_args[0]{'ID'}}}) {
			if ($config{'followSitAuto'} && $players{$ai_seq_args[0]{'ID'}}{'sitting'} == 1 && $chars[$config{'char'}]{'sitting'} == 0) {
				sit();
			}

			my $dx = $ai_seq_args[0]{'last_pos_to'}{'x'} - $players{$ai_seq_args[0]{'ID'}}{'pos_to'}{'x'};
			my $dy = $ai_seq_args[0]{'last_pos_to'}{'y'} - $players{$ai_seq_args[0]{'ID'}}{'pos_to'}{'y'};
			$ai_seq_args[0]{'last_pos_to'}{'x'} = $players{$ai_seq_args[0]{'ID'}}{'pos_to'}{'x'};
			$ai_seq_args[0]{'last_pos_to'}{'y'} = $players{$ai_seq_args[0]{'ID'}}{'pos_to'}{'y'};
			if ($dx != 0 || $dy != 0) {
				lookAtPosition($players{$ai_seq_args[0]{'ID'}}{'pos_to'}, int(rand(3))) if ($config{'followFaceDirection'});
			}
		}
	}

	if ($ai_seq[0] eq "follow" && $ai_seq_args[0]{'following'} && ($players{$ai_seq_args[0]{'ID'}}{'dead'} || $players_old{$ai_seq_args[0]{'ID'}}{'dead'})) {
		print "Master died.  I'll wait here.\n";
		injectMessage("Master died.  I'll wait here.") if ($config{'verbose'} && $config{'XKore'});
		undef $ai_seq_args[0]{'following'};
	} elsif ($ai_seq[0] eq "follow" && $ai_seq_args[0]{'following'} && !%{$players{$ai_seq_args[0]{'ID'}}}) {
		print "I lost my master\n";
		if ($config{'followBot'}) {
			print "Trying to get him back\n";
			sendMessage(\$remote_socket, "pm", "move $chars[$config{'char'}]{'pos_to'}{'x'} $chars[$config{'char'}]{'pos_to'}{'y'}", $config{followTarget});
		}
		injectMessage("I lost my master") if ($config{'verbose'} && $config{'XKore'});

		undef $ai_seq_args[0]{'following'};
		if ($players_old{$ai_seq_args[0]{'ID'}}{'disconnected'}) {
			print "My master disconnected\n";
			injectMessage("My master disconnected") if ($config{'verbose'} && $config{'XKore'});
		
		} elsif ($players_old{$ai_seq_args[0]{'ID'}}{'teleported'}) {
			print "My master teleported\n";
			injectMessage("My master teleported") if ($config{'verbose'} && $config{'XKore'});

		} elsif ($players_old{$ai_seq_args[0]{'ID'}}{'disappeared'}) {
			print "Trying to find lost master\n";
			injectMessage("Trying to find lost master") if ($config{'verbose'} && $config{'XKore'});

			undef $ai_seq_args[0]{'ai_follow_lost_char_last_pos'};
			undef $ai_seq_args[0]{'follow_lost_portal_tried'};
			$ai_seq_args[0]{'ai_follow_lost'} = 1;
			$ai_seq_args[0]{'ai_follow_lost_end'}{'timeout'} = $timeout{'ai_follow_lost_end'}{'timeout'};
			$ai_seq_args[0]{'ai_follow_lost_end'}{'time'} = time;
			getVector(\%{$ai_seq_args[0]{'ai_follow_lost_vec'}}, \%{$players_old{$ai_seq_args[0]{'ID'}}{'pos_to'}}, \%{$chars[$config{'char'}]{'pos_to'}});

			#check if player went through portal
			$ai_v{'temp'}{'first'} = 1;
			undef $ai_v{'temp'}{'foundID'};
			undef $ai_v{'temp'}{'smallDist'};
			foreach (@portalsID) {
				$ai_v{'temp'}{'dist'} = distance(\%{$players_old{$ai_seq_args[0]{'ID'}}{'pos_to'}}, \%{$portals{$_}{'pos'}});
				if ($ai_v{'temp'}{'dist'} <= 7 && ($ai_v{'temp'}{'first'} || $ai_v{'temp'}{'dist'} < $ai_v{'temp'}{'smallDist'})) {
					$ai_v{'temp'}{'smallDist'} = $ai_v{'temp'}{'dist'};
					$ai_v{'temp'}{'foundID'} = $_;
					undef $ai_v{'temp'}{'first'};
				}
			}
			$ai_seq_args[0]{'follow_lost_portalID'} = $ai_v{'temp'}{'foundID'};
		} else {
			if (!$config{'XKore'}) {
				print "Don't know what happened to Master\n";
			} else {
				injectMessage("Don't know what happened to Master") if ($config{'verbose'});
			}
		}
	}



	##### FOLLOW-LOST #####


	if ($ai_seq[0] eq "follow" && $ai_seq_args[0]{'ai_follow_lost'}) {
		if ($ai_seq_args[0]{'ai_follow_lost_char_last_pos'}{'x'} == $chars[$config{'char'}]{'pos_to'}{'x'} && $ai_seq_args[0]{'ai_follow_lost_char_last_pos'}{'y'} == $chars[$config{'char'}]{'pos_to'}{'y'}) {
			$ai_seq_args[0]{'lost_stuck'}++;
		} else {
			undef $ai_seq_args[0]{'lost_stuck'};
		}
		%{$ai_seq_args[0]{'ai_follow_lost_char_last_pos'}} = %{$chars[$config{'char'}]{'pos_to'}};

		if (timeOut(\%{$ai_seq_args[0]{'ai_follow_lost_end'}})) {
			undef $ai_seq_args[0]{'ai_follow_lost'};
			if (!$config{'XKore'}) {
				print "Couldn't find master, giving up\n";
			} else {
				injectMessage("Couldn't find master, giving up") if ($config{'verbose'});
			}

		} elsif ($players_old{$ai_seq_args[0]{'ID'}}{'disconnected'}) {
			undef $ai_seq_args[0]{'ai_follow_lost'};
			print "My master disconnected\n";
			injectMessage("My master disconnected") if ($config{'verbose'} && $config{'XKore'});

		} elsif ($players_old{$ai_seq_args[0]{'ID'}}{'teleported'}) {
			undef $ai_seq_args[0]{'ai_follow_lost'};
			print "My master teleported\n";
			injectMessage("My master teleported") if ($config{'verbose'} && $config{'XKore'});

		} elsif (%{$players{$ai_seq_args[0]{'ID'}}}) {
			$ai_seq_args[0]{'following'} = 1;
			undef $ai_seq_args[0]{'ai_follow_lost'};
			if (!$config{'XKore'}) {
				print "Found my master!\n";
			} else {
				injectMessage("Found my master!") if ($config{'verbose'});
			}

		} elsif ($ai_seq_args[0]{'lost_stuck'}) {
			if ($ai_seq_args[0]{'follow_lost_portalID'} eq "") {
				moveAlongVector(\%{$ai_v{'temp'}{'pos'}}, \%{$chars[$config{'char'}]{'pos_to'}}, \%{$ai_seq_args[0]{'ai_follow_lost_vec'}}, $config{'followLostStep'} / ($ai_seq_args[0]{'lost_stuck'} + 1));
				move($ai_v{'temp'}{'pos'}{'x'}, $ai_v{'temp'}{'pos'}{'y'});
			}
		} else {
			if ($ai_seq_args[0]{'follow_lost_portalID'} ne "") {
				if (%{$portals{$ai_seq_args[0]{'follow_lost_portalID'}}} && !$ai_seq_args[0]{'follow_lost_portal_tried'}) {
					$ai_seq_args[0]{'follow_lost_portal_tried'} = 1;
					%{$ai_v{'temp'}{'pos'}} = %{$portals{$ai_seq_args[0]{'follow_lost_portalID'}}{'pos'}};
					ai_route(\%{$ai_v{'temp'}{'returnHash'}}, $ai_v{'temp'}{'pos'}{'x'}, $ai_v{'temp'}{'pos'}{'y'}, $field{'name'}, 0, 0, 1);
				}
			} else {
				moveAlongVector(\%{$ai_v{'temp'}{'pos'}}, \%{$chars[$config{'char'}]{'pos_to'}}, \%{$ai_seq_args[0]{'ai_follow_lost_vec'}}, $config{'followLostStep'});
				move($ai_v{'temp'}{'pos'}{'x'}, $ai_v{'temp'}{'pos'}{'y'});
			}
		}
	}

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

	if ($ai_v{'sitAuto_forceStop'} && percent_hp(\%{$chars[$config{'char'}]}) >= $config{'sitAuto_hp_lower'} && percent_sp(\%{$chars[$config{'char'}]}) >= $config{'sitAuto_sp_lower'}) {
		$ai_v{'sitAuto_forceStop'} = 0;
	}

	if (!$ai_v{'sitAuto_forceStop'} && ($ai_seq[0] eq "" || $ai_seq[0] eq "follow" || $ai_seq[0] eq "route" || $ai_seq[0] eq "route_getRoute" || $ai_seq[0] eq "route_getMapRoute") && binFind(\@ai_seq, "attack") eq "" && !ai_getAggressives()
		&& (percent_hp(\%{$chars[$config{'char'}]}) < $config{'sitAuto_hp_lower'} || percent_sp(\%{$chars[$config{'char'}]}) < $config{'sitAuto_sp_lower'})) {
		unshift @ai_seq, "sitAuto";
		unshift @ai_seq_args, {};
		print "Auto-sitting\n" if $config{'debug'};
	}
	if ($ai_seq[0] eq "sitAuto" && !$chars[$config{'char'}]{'sitting'} && $chars[$config{'char'}]{'skills'}{'NV_BASIC'}{'lv'} >= 3 && !ai_getAggressives()) {
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


	if (($ai_seq[0] eq "" || $ai_seq[0] eq "route" || $ai_seq[0] eq "route_getRoute" || $ai_seq[0] eq "route_getMapRoute" || $ai_seq[0] eq "follow" 
		|| $ai_seq[0] eq "sitAuto" || $ai_seq[0] eq "take" || $ai_seq[0] eq "items_gather" || $ai_seq[0] eq "items_take")
		&& !($config{'itemsTakeAuto'} >= 2 && ($ai_seq[0] eq "take" || $ai_seq[0] eq "items_take"))
		&& !($config{'itemsGatherAuto'} >= 2 && ($ai_seq[0] eq "take" || $ai_seq[0] eq "items_gather"))
		&& timeOut(\%{$timeout{'ai_attack_auto'}})) {
		undef @{$ai_v{'ai_attack_agMonsters'}};
		undef @{$ai_v{'ai_attack_cleanMonsters'}};
		undef @{$ai_v{'ai_attack_partyMonsters'}};
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
				if ((($config{'attackAuto_party'}
					&& $ai_seq[0] ne "take" && $ai_seq[0] ne "items_take"
					&& ($monsters{$_}{'dmgToParty'} > 0 || $monsters{$_}{'dmgFromParty'} > 0))
					|| ($config{'attackAuto_followTarget'} && $ai_v{'temp'}{'ai_follow_following'} 
					&& ($monsters{$_}{'dmgToPlayer'}{$ai_v{'temp'}{'ai_follow_ID'}} > 0 || $monsters{$_}{'missedToPlayer'}{$ai_v{'temp'}{'ai_follow_ID'}} > 0 || $monsters{$_}{'dmgFromPlayer'}{$ai_v{'temp'}{'ai_follow_ID'}} > 0)))
					&& !($ai_v{'temp'}{'ai_route_index'} ne "" && !$ai_v{'temp'}{'ai_route_attackOnRoute'})
					&& $monsters{$_}{'attack_failed'} == 0 && ($mon_control{lc($monsters{$_}{'name'})}{'attack_auto'} >= 1 || $mon_control{lc($monsters{$_}{'name'})}{'attack_auto'} eq "")) {
					push @{$ai_v{'ai_attack_partyMonsters'}}, $_;

				# Begin the attack only when noone else is on screen, stollen from the skore forums a long time ago.
				} elsif ($config{'attackAuto_onlyWhenSafe'}
					&& $config{'attackAuto'} >= 1
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
			$ai_v{'temp'}{'first'} = 1;

			# Look for the closest aggressive monster to attack
			foreach (@{$ai_v{'ai_attack_agMonsters'}}) {
				# Don't attack monsters near portals
				next if (positionNearPortal(\%{$monsters{$_}{'pos_to'}}, 4));

				$ai_v{'temp'}{'dist'} = distance(\%{$chars[$config{'char'}]{'pos_to'}}, \%{$monsters{$_}{'pos_to'}});
				if (($ai_v{'temp'}{'first'} || $ai_v{'temp'}{'dist'} < $ai_v{'temp'}{'distSmall'}) && !$monsters{$_}{'state'}) {
					$ai_v{'temp'}{'distSmall'} = $ai_v{'temp'}{'dist'};
					$ai_v{'temp'}{'foundID'} = $_;
					undef $ai_v{'temp'}{'first'};
				}
			}

			if (!$ai_v{'temp'}{'foundID'}) {
				# There are no aggressive monsters; look for the closest monster that a party member is attacking
				undef $ai_v{'temp'}{'distSmall'};
				undef $ai_v{'temp'}{'foundID'};
				$ai_v{'temp'}{'first'} = 1;
				foreach (@{$ai_v{'ai_attack_partyMonsters'}}) {
					$ai_v{'temp'}{'dist'} = distance(\%{$chars[$config{'char'}]{'pos_to'}}, \%{$monsters{$_}{'pos_to'}});
					if (($ai_v{'temp'}{'first'} || $ai_v{'temp'}{'dist'} < $ai_v{'temp'}{'distSmall'}) && !$monsters{$_}{'ignore'} && !$monsters{$_}{'state'}) {
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
				undef $ai_v{'temp'}{'distSmall'};
				undef $ai_v{'temp'}{'foundID'};
				$ai_v{'temp'}{'first'} = 1;
				foreach (@{$ai_v{'ai_attack_cleanMonsters'}}) {
					$ai_v{'temp'}{'dist'} = distance(\%{$chars[$config{'char'}]{'pos_to'}}, \%{$monsters{$_}{'pos_to'}});
					if (($ai_v{'temp'}{'first'} || $ai_v{'temp'}{'dist'} < $ai_v{'temp'}{'distSmall'})
					 && !$monsters{$_}{'ignore'} && !$monsters{$_}{'state'}
					 && !positionNearPlayer(\%{$monsters{$_}{'pos_to'}}, 3)
					 && !positionNearPortal(\%{$monsters{$_}{'pos_to'}}, 4)) {
						$ai_v{'temp'}{'distSmall'} = $ai_v{'temp'}{'dist'};
						$ai_v{'temp'}{'foundID'} = $_;
						undef $ai_v{'temp'}{'first'};
					}
				}
			}
		}

		# If an appropriate monster's found, attack it. If not, wait ai_attack_auto secs before searching again.
		if ($ai_v{'temp'}{'foundID'}) {
			ai_setSuspend(0);
			attack($ai_v{'temp'}{'foundID'});
		} else {
			$timeout{'ai_attack_auto'}{'time'} = time;
		}
	}




	##### ATTACK #####


	if ($ai_seq[0] eq "attack" && $ai_seq_args[0]{'suspended'}) {
		$ai_seq_args[0]{'ai_attack_giveup'}{'time'} += time - $ai_seq_args[0]{'suspended'};
		undef $ai_seq_args[0]{'suspended'};
	}
	if ($ai_seq[0] eq "attack" && timeOut(\%{$ai_seq_args[0]{'ai_attack_giveup'}})) {
		$monsters{$ai_seq_args[0]{'ID'}}{'attack_failed'}++;
		shift @ai_seq;
		shift @ai_seq_args;
		print "Can't reach or damage target, dropping target\n";
		injectMessage("Can't reach or damage target, dropping target") if ($config{'XKore'} && $config{'verbose'});

	} elsif ($ai_seq[0] eq "attack" && !%{$monsters{$ai_seq_args[0]{'ID'}}}) {
		$timeout{'ai_attack'}{'time'} -= $timeout{'ai_attack'}{'timeout'};
		$ai_v{'ai_attack_ID_old'} = $ai_seq_args[0]{'ID'};
		shift @ai_seq;
		shift @ai_seq_args;
		if ($monsters_old{$ai_v{'ai_attack_ID_old'}}{'dead'}) {
			print "Target died\n";

			monKilled();
			$monsters_Killed{$monsters_old{$ai_v{'ai_attack_ID_old'}}{'nameID'}}++;

			if ($config{'itemsTakeAuto'} && $monsters_old{$ai_v{'ai_attack_ID_old'}}{'dmgFromYou'} > 0 && !$monsters_old{$ai_v{'ai_attack_ID_old'}}{'attackedByPlayer'} && !$monsters_old{$ai_v{'ai_attack_ID_old'}}{'ignore'}) {
				ai_items_take($monsters_old{$ai_v{'ai_attack_ID_old'}}{'pos'}{'x'}, $monsters_old{$ai_v{'ai_attack_ID_old'}}{'pos'}{'y'}, $monsters_old{$ai_v{'ai_attack_ID_old'}}{'pos_to'}{'x'}, $monsters_old{$ai_v{'ai_attack_ID_old'}}{'pos_to'}{'y'});
			} elsif (!ai_getAggressives()) {
				# Cheap way to suspend all movement to make it look real
				ai_clientSuspend(0, $timeout{'ai_attack_waitAfterKill'}{'timeout'});
			}

## kokal start 
## mosters counting 
			$i = 0;
			$found = 0;
			while ($monsters_Killed[$i]) {
				if ($monsters_Killed[$i]{'nameID'} eq $monsters_old{$ai_v{'ai_attack_ID_old'}}{'nameID'}) {
					$monsters_Killed[$i]{'count'}++;
					$found = 1;
					last;
				}
				$i++;
			}
			if (!$found) {
				$monsters_Killed[$i]{'nameID'} = $monsters_old{$ai_v{'ai_attack_ID_old'}}{'nameID'};
				$monsters_Killed[$i]{'name'} = $monsters_old{$ai_v{'ai_attack_ID_old'}}{'name'};
				$monsters_Killed[$i]{'count'} = 1;
			}
## kokal end

		} else {
			print "Target lost\n";
			injectMessage("Target lost") if ($config{'verbose'} && $config{'XKore'});
		}

	} elsif ($ai_seq[0] eq "attack") {
		$ai_v{'temp'}{'ai_follow_index'} = binFind(\@ai_seq, "follow");
		if ($ai_v{'temp'}{'ai_follow_index'} ne "") {
			$ai_v{'temp'}{'ai_follow_following'} = $ai_seq_args[$ai_v{'temp'}{'ai_follow_index'}]{'following'};
			$ai_v{'temp'}{'ai_follow_ID'} = $ai_seq_args[$ai_v{'temp'}{'ai_follow_index'}]{'ID'};
		} else {
			undef $ai_v{'temp'}{'ai_follow_following'};
		}

		$ai_v{'ai_attack_cleanMonster'} = (
				  !($monsters{$ai_seq_args[0]{'ID'}}{'dmgFromYou'} == 0 && ($monsters{$ai_seq_args[0]{'ID'}}{'dmgTo'} > 0 || $monsters{$ai_seq_args[0]{'ID'}}{'dmgFrom'} > 0 || %{$monsters{$ai_seq_args[0]{'ID'}}{'missedFromPlayer'}} || %{$monsters{$ai_seq_args[0]{'ID'}}{'missedToPlayer'}} || %{$monsters{$ai_seq_args[0]{'ID'}}{'castOnByPlayer'}}))
				|| ($config{'attackAuto_party'} && ($monsters{$ai_seq_args[0]{'ID'}}{'dmgFromParty'} > 0 || $monsters{$ai_seq_args[0]{'ID'}}{'dmgToParty'} > 0))
				|| ($config{'attackAuto_followTarget'} && $ai_v{'temp'}{'ai_follow_following'} && ($monsters{$ai_seq_args[0]{'ID'}}{'dmgToPlayer'}{$ai_v{'temp'}{'ai_follow_ID'}} > 0 || $monsters{$ai_seq_args[0]{'ID'}}{'missedToPlayer'}{$ai_v{'temp'}{'ai_follow_ID'}} > 0 || $monsters{$ai_seq_args[0]{'ID'}}{'dmgFromPlayer'}{$ai_v{'temp'}{'ai_follow_ID'}} > 0))
				|| ($monsters{$ai_seq_args[0]{'ID'}}{'dmgToYou'} > 0 || $monsters{$ai_seq_args[0]{'ID'}}{'missedYou'} > 0)
			);
		$ai_v{'ai_attack_cleanMonster'} = 0 if ($monsters{$ai_seq_args[0]{'ID'}}{'attackedByPlayer'});

		$ai_v{'ai_attack_monsterDist'} = distance(\%{$chars[$config{'char'}]{'pos_to'}}, \%{$monsters{$ai_seq_args[0]{'ID'}}{'pos_to'}});

		if ($ai_seq_args[0]{'dmgToYou_last'} != $monsters{$ai_seq_args[0]{'ID'}}{'dmgToYou'}
			|| $ai_seq_args[0]{'missedYou_last'} != $monsters{$ai_seq_args[0]{'ID'}}{'missedYou'}
			|| $ai_seq_args[0]{'dmgFromYou_last'} != $monsters{$ai_seq_args[0]{'ID'}}{'dmgFromYou'}) {
				$ai_seq_args[0]{'ai_attack_giveup'}{'time'} = time;
		}
		$ai_seq_args[0]{'dmgToYou_last'} = $monsters{$ai_seq_args[0]{'ID'}}{'dmgToYou'};
		$ai_seq_args[0]{'missedYou_last'} = $monsters{$ai_seq_args[0]{'ID'}}{'missedYou'};
		$ai_seq_args[0]{'dmgFromYou_last'} = $monsters{$ai_seq_args[0]{'ID'}}{'dmgFromYou'};
		$ai_seq_args[0]{'missedFromYou_last'} = $monsters{$ai_seq_args[0]{'ID'}}{'missedFromYou'};
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
				if (percent_hp(\%{$chars[$config{'char'}]}) >= $config{"attackSkillSlot_$i"."_hp_lower"} && percent_hp(\%{$chars[$config{'char'}]}) <= $config{"attackSkillSlot_$i"."_hp_upper"}
					&& percent_sp(\%{$chars[$config{'char'}]}) >= $config{"attackSkillSlot_$i"."_sp_lower"} && percent_sp(\%{$chars[$config{'char'}]}) <= $config{"attackSkillSlot_$i"."_sp_upper"}
					&& $chars[$config{'char'}]{'sp'} >= $skillsSP_lut{$skills_rlut{lc($config{"attackSkillSlot_$i"})}}{$config{"attackSkillSlot_$i"."_lvl"}}
					&& !($config{"attackSkillSlot_$i"."_stopWhenHit"} && ai_getMonstersWhoHitMe())
					&& (!$config{"attackSkillSlot_$i"."_maxUses"} || $ai_seq_args[0]{'attackSkillSlot_uses'}{$i} < $config{"attackSkillSlot_$i"."_maxUses"})
					&& $config{"attackSkillSlot_$i"."_minAggressives"} <= ai_getAggressives()
					&& (!$config{"attackSkillSlot_$i"."_maxAggressives"} || $config{"attackSkillSlot_$i"."_maxAggressives"} >= ai_getAggressives())
					&& (!$config{"attackSkillSlot_$i"."_monsters"} || existsInList($config{"attackSkillSlot_$i"."_monsters"}, $monsters{$ai_seq_args[0]{'ID'}}{'name'}))) {
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

		} elsif (!$ai_v{'ai_attack_cleanMonster'}) {
			# Drop target if it's already attacked by someone else
			print "Dropping target - no kill steal\n"; 
			injectMessage("Dropping target - no kill steal") if ($config{'verbose'} && $config{'XKore'});
			$monsters{$ai_seq_args[0]{'ID'}}{'ignore'} = 1;
			sendAttackStop(\$remote_socket);
			shift @ai_seq;
			shift @ai_seq_args;

		} elsif ($ai_v{'ai_attack_monsterDist'} > $ai_seq_args[0]{'attackMethod'}{'distance'}) {
			# Move to target
			if (%{$ai_seq_args[0]{'char_pos_last'}} && %{$ai_seq_args[0]{'attackMethod_last'}}
				&& $ai_seq_args[0]{'attackMethod_last'}{'distance'} == $ai_seq_args[0]{'attackMethod'}{'distance'}
				&& $ai_seq_args[0]{'char_pos_last'}{'x'} == $chars[$config{'char'}]{'pos_to'}{'x'}
				&& $ai_seq_args[0]{'char_pos_last'}{'y'} == $chars[$config{'char'}]{'pos_to'}{'y'}) {
				$ai_seq_args[0]{'distanceDivide'}++;
			} else {
				$ai_seq_args[0]{'distanceDivide'} = 1;
			}
			if (int($ai_seq_args[0]{'attackMethod'}{'distance'} / $ai_seq_args[0]{'distanceDivide'}) == 0
				|| ($config{'attackMaxRouteDistance'} && $ai_seq_args[0]{'ai_route_returnHash'}{'solutionLength'} > $config{'attackMaxRouteDistance'})
				|| ($config{'attackMaxRouteTime'} && $ai_seq_args[0]{'ai_route_returnHash'}{'solutionTime'} > $config{'attackMaxRouteTime'})) {
				$monsters{$ai_seq_args[0]{'ID'}}{'attack_failed'}++;
				shift @ai_seq;
				shift @ai_seq_args;
				print "Dropping target - couldn't reach target\n";
				injectMessage("Dropping target - couldn't reach target") if ($config{'verbose'} && $config{'XKore'});
			} else {
				getVector(\%{$ai_v{'temp'}{'vec'}}, \%{$monsters{$ai_seq_args[0]{'ID'}}{'pos_to'}}, \%{$chars[$config{'char'}]{'pos_to'}});
				moveAlongVector(\%{$ai_v{'temp'}{'pos'}}, \%{$chars[$config{'char'}]{'pos_to'}}, \%{$ai_v{'temp'}{'vec'}},
				                $ai_v{'ai_attack_monsterDist'} - ($ai_seq_args[0]{'attackMethod'}{'distance'} / $ai_seq_args[0]{'distanceDivide'}) + 1);

				%{$ai_seq_args[0]{'char_pos_last'}} = %{$chars[$config{'char'}]{'pos_to'}};
				%{$ai_seq_args[0]{'attackMethod_last'}} = %{$ai_seq_args[0]{'attackMethod'}};

				ai_setSuspend(0);
				if (@{$field{'field'}} > 1) {
					ai_route(\%{$ai_seq_args[0]{'ai_route_returnHash'}}, $ai_v{'temp'}{'pos'}{'x'}, $ai_v{'temp'}{'pos'}{'y'}, $field{'name'}, $config{'attackMaxRouteDistance'}, $config{'attackMaxRouteTime'}, 0, 0, 0, 0, $ai_seq_args[0]{'ID'});
				} else {
					move($ai_v{'temp'}{'pos'}{'x'}, $ai_v{'temp'}{'pos'}{'y'}, 0, $ai_seq_args[0]{'ID'});
				}
			}

		} elsif ((($config{'tankMode'} && $monsters{$ai_seq_args[0]{'ID'}}{'dmgFromYou'} == 0)
		        || !$config{'tankMode'})) {
			# Attack the target. In case of tanking, only attack if it hasn't been hit once.

			if ($ai_seq_args[0]{'attackMethod'}{'type'} eq "weapon" && timeOut(\%{$timeout{'ai_attack'}})) {
				if ($config{'tankMode'}) {
					sendAttack(\$remote_socket, $ai_seq_args[0]{'ID'}, 0);
				} else {
					sendAttack(\$remote_socket, $ai_seq_args[0]{'ID'}, 7);
				}
				$timeout{'ai_attack'}{'time'} = time;
				undef %{$ai_seq_args[0]{'attackMethod'}};
			} elsif ($ai_seq_args[0]{'attackMethod'}{'type'} eq "skill") {
				$ai_v{'ai_attack_method_skillSlot'} = $ai_seq_args[0]{'attackMethod'}{'skillSlot'};
				$ai_v{'ai_attack_ID'} = $ai_seq_args[0]{'ID'};
				undef %{$ai_seq_args[0]{'attackMethod'}};
				ai_setSuspend(0);
				if (!ai_getSkillUseType($skills_rlut{lc($config{"attackSkillSlot_$ai_v{'ai_attack_method_skillSlot'}"})})) {
					ai_skillUse($chars[$config{'char'}]{'skills'}{$skills_rlut{lc($config{"attackSkillSlot_$ai_v{'ai_attack_method_skillSlot'}"})}}{'ID'}, $config{"attackSkillSlot_$ai_v{'ai_attack_method_skillSlot'}"."_lvl"}, $config{"attackSkillSlot_$ai_v{'ai_attack_method_skillSlot'}"."_maxCastTime"}, $config{"attackSkillSlot_$ai_v{'ai_attack_method_skillSlot'}"."_minCastTime"}, $ai_v{'ai_attack_ID'});
				} else {
					ai_skillUse($chars[$config{'char'}]{'skills'}{$skills_rlut{lc($config{"attackSkillSlot_$ai_v{'ai_attack_method_skillSlot'}"})}}{'ID'}, $config{"attackSkillSlot_$ai_v{'ai_attack_method_skillSlot'}"."_lvl"}, $config{"attackSkillSlot_$ai_v{'ai_attack_method_skillSlot'}"."_maxCastTime"}, $config{"attackSkillSlot_$ai_v{'ai_attack_method_skillSlot'}"."_minCastTime"}, $monsters{$ai_v{'ai_attack_ID'}}{'pos_to'}{'x'}, $monsters{$ai_v{'ai_attack_ID'}}{'pos_to'}{'y'});
				}
				print qq~Auto-skill on monster: $skills_lut{$skills_rlut{lc($config{"attackSkillSlot_$ai_v{'ai_attack_method_skillSlot'}"})}} (lvl $config{"attackSkillSlot_$ai_v{'ai_attack_method_skillSlot'}"."_lvl"})\n~ if $config{'debug'};
			}
			
		} elsif ($config{'tankMode'}) {
			if ($ai_seq_args[0]{'dmgTo_last'} != $monsters{$ai_seq_args[0]{'ID'}}{'dmgTo'}) {
				$ai_seq_args[0]{'ai_attack_giveup'}{'time'} = time;
			}
			$ai_seq_args[0]{'dmgTo_last'} = $monsters{$ai_seq_args[0]{'ID'}}{'dmgTo'};
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

		if (!$ai_v{'ai_attack_cleanMonster'}) {
			sendAttackStop(\$remote_socket);
			shift @ai_seq;
			shift @ai_seq_args;
			if ($ai_seq[0] eq "route") {
				shift @ai_seq;
				shift @ai_seq_args;
			}
		}
	}

	
	##### ROUTE #####

	ROUTE: {

	if ($ai_seq[0] eq "route" && @{$ai_seq_args[0]{'solution'}} && $ai_seq_args[0]{'index'} == @{$ai_seq_args[0]{'solution'}} - 1 && $ai_seq_args[0]{'solutionReady'}) {
		print "Route success\n" if $config{'debug'};
		shift @ai_seq;
		shift @ai_seq_args;
	} elsif ($ai_seq[0] eq "route" && $ai_seq_args[0]{'failed'}) {
		print "Route failed\n" if $config{'debug'};
		shift @ai_seq;
		shift @ai_seq_args;
		aiRemove("move");
		aiRemove("route");
		aiRemove("route_getRoute");
		aiRemove("route_getMapRoute");
	} elsif ($ai_seq[0] eq "route" && timeOut(\%{$timeout{'ai_route_npcTalk'}})) {
		last ROUTE if (!$field{'name'});
		if ($ai_seq_args[0]{'waitingForMapSolution'}) {
			undef $ai_seq_args[0]{'waitingForMapSolution'};
			if (!@{$ai_seq_args[0]{'mapSolution'}}) {
				print "NPC talk - route failed\n" if $config{'debug'};
				$ai_seq_args[0]{'failed'} = 1;
				last ROUTE;
			}
			$ai_seq_args[0]{'mapIndex'} = -1;
		}
		if ($ai_seq_args[0]{'waitingForSolution'}) {
			undef $ai_seq_args[0]{'waitingForSolution'};
			if ($ai_seq_args[0]{'distFromGoal'} && $field{'name'} && $ai_seq_args[0]{'dest_map'} eq $field{'name'} 
				&& (!@{$ai_seq_args[0]{'mapSolution'}} || $ai_seq_args[0]{'mapIndex'} == @{$ai_seq_args[0]{'mapSolution'}} - 1)) {
				for ($i = 0; $i < $ai_seq_args[0]{'distFromGoal'}; $i++) {
					pop @{$ai_seq_args[0]{'solution'}};
				}
				if (@{$ai_seq_args[0]{'solution'}}) {
					$ai_seq_args[0]{'dest_x_original'} = $ai_seq_args[0]{'dest_x'};
					$ai_seq_args[0]{'dest_y_original'} = $ai_seq_args[0]{'dest_y'};
					$ai_seq_args[0]{'dest_x'} = $ai_seq_args[0]{'solution'}[@{$ai_seq_args[0]{'solution'}}-1]{'x'};
					$ai_seq_args[0]{'dest_y'} = $ai_seq_args[0]{'solution'}[@{$ai_seq_args[0]{'solution'}}-1]{'y'};
				}
			}
			$ai_seq_args[0]{'returnHash'}{'solutionLength'} = @{$ai_seq_args[0]{'solution'}};
			$ai_seq_args[0]{'returnHash'}{'solutionTime'} = time - $ai_seq_args[0]{'time_getRoute'};
			if ($ai_seq_args[0]{'maxRouteDistance'} && @{$ai_seq_args[0]{'solution'}} > $ai_seq_args[0]{'maxRouteDistance'}) {
				print "Solution length - route failed\n" if $config{'debug'};
				$ai_seq_args[0]{'failed'} = 1;
				last ROUTE;
			}
			if (!@{$ai_seq_args[0]{'solution'}} && !@{$ai_seq_args[0]{'mapSolution'}} && $ai_seq_args[0]{'dest_map'} eq $field{'name'} && $ai_seq_args[0]{'checkInnerPortals'} && !$ai_seq_args[0]{'checkInnerPortals_done'}) {
				$ai_seq_args[0]{'checkInnerPortals_done'} = 1;
				print "Route Logic - check inner portals done\n" if $config{'debug'};
				undef $ai_seq_args[0]{'solutionReady'};
				$ai_seq_args[0]{'temp'}{'pos'}{'x'} = $ai_seq_args[0]{'dest_x'};
				$ai_seq_args[0]{'temp'}{'pos'}{'y'} = $ai_seq_args[0]{'dest_y'};
				$ai_seq_args[0]{'waitingForMapSolution'} = 1;
				ai_mapRoute_getRoute(\@{$ai_seq_args[0]{'mapSolution'}}, \%field, \%{$chars[$config{'char'}]{'pos_to'}}, \%field, \%{$ai_seq_args[0]{'temp'}{'pos'}}, $ai_seq_args[0]{'maxRouteTime'});
				last ROUTE;
			} elsif (!@{$ai_seq_args[0]{'solution'}}) {
				print "No solution - route failed\n" if $config{'debug'};
				$ai_seq_args[0]{'failed'} = 1;
				last ROUTE;
			}
		}
		if (@{$ai_seq_args[0]{'mapSolution'}} && $ai_seq_args[0]{'mapChanged'} && $field{'name'} eq $ai_seq_args[0]{'mapSolution'}[$ai_seq_args[0]{'mapIndex'}]{'dest'}{'map'}) {
			print "Route logic - map changed\n" if $config{'debug'};
			undef $ai_seq_args[0]{'mapChanged'};
			undef @{$ai_seq_args[0]{'solution'}};
			undef %{$ai_seq_args[0]{'last_pos'}};
			undef $ai_seq_args[0]{'index'};
			undef $ai_seq_args[0]{'npc'};
			undef $ai_seq_args[0]{'divideIndex'};
		}
		if (!@{$ai_seq_args[0]{'solution'}}) {
			if ($ai_seq_args[0]{'dest_map'} eq $field{'name'}
				&& (!@{$ai_seq_args[0]{'mapSolution'}} || $ai_seq_args[0]{'mapIndex'} == @{$ai_seq_args[0]{'mapSolution'}} - 1)) {
				$ai_seq_args[0]{'temp'}{'dest'}{'x'} = $ai_seq_args[0]{'dest_x'};
				$ai_seq_args[0]{'temp'}{'dest'}{'y'} = $ai_seq_args[0]{'dest_y'};
				$ai_seq_args[0]{'solutionReady'} = 1;
				undef @{$ai_seq_args[0]{'mapSolution'}};
				undef $ai_seq_args[0]{'mapIndex'};
				print "Route logic - solution ready\n" if $config{'debug'};
			} else {
				if (!(@{$ai_seq_args[0]{'mapSolution'}})) {
					if (!%{$ai_seq_args[0]{'dest_field'}}) {
						getField("fields/$ai_seq_args[0]{'dest_map'}.fld", \%{$ai_seq_args[0]{'dest_field'}});
					}
					$ai_seq_args[0]{'temp'}{'pos'}{'x'} = $ai_seq_args[0]{'dest_x'};
					$ai_seq_args[0]{'temp'}{'pos'}{'y'} = $ai_seq_args[0]{'dest_y'};
					$ai_seq_args[0]{'waitingForMapSolution'} = 1;
					print "Route logic - waiting for map solution\n" if $config{'debug'};
					ai_mapRoute_getRoute(\@{$ai_seq_args[0]{'mapSolution'}}, \%field, \%{$chars[$config{'char'}]{'pos_to'}}, \%{$ai_seq_args[0]{'dest_field'}}, \%{$ai_seq_args[0]{'temp'}{'pos'}}, $ai_seq_args[0]{'maxRouteTime'});
					last ROUTE;
				}
				if ($field{'name'} eq $ai_seq_args[0]{'mapSolution'}[$ai_seq_args[0]{'mapIndex'} + 1]{'source'}{'map'}) {
					$ai_seq_args[0]{'mapIndex'}++;
					%{$ai_seq_args[0]{'temp'}{'dest'}} = %{$ai_seq_args[0]{'mapSolution'}[$ai_seq_args[0]{'mapIndex'}]{'source'}{'pos'}};
				} else {
					%{$ai_seq_args[0]{'temp'}{'dest'}} = %{$ai_seq_args[0]{'mapSolution'}[$ai_seq_args[0]{'mapIndex'}]{'source'}{'pos'}};
				}
			}
			if ($ai_seq_args[0]{'temp'}{'dest'}{'x'} eq "") {
				print "No destination - route failed\n" if $config{'debug'};
				$ai_seq_args[0]{'failed'} = 1;
				last ROUTE;
			}
			$ai_seq_args[0]{'waitingForSolution'} = 1;
			$ai_seq_args[0]{'time_getRoute'} = time;
			print "Route logic - waiting for solution\n" if $config{'debug'};
			ai_route_getRoute(\@{$ai_seq_args[0]{'solution'}}, \%field, \%{$chars[$config{'char'}]{'pos_to'}}, \%{$ai_seq_args[0]{'temp'}{'dest'}}, $ai_seq_args[0]{'maxRouteTime'});
			last ROUTE;
		}
		if (@{$ai_seq_args[0]{'mapSolution'}} && @{$ai_seq_args[0]{'solution'}} && $ai_seq_args[0]{'index'} == @{$ai_seq_args[0]{'solution'}} - 1
			&& %{$ai_seq_args[0]{'mapSolution'}[$ai_seq_args[0]{'mapIndex'}]{'npc'}}) {
			if ($ai_seq_args[0]{'mapSolution'}[$ai_seq_args[0]{'mapIndex'}]{'npc'}{'steps'}[$ai_seq_args[0]{'npc'}{'step'}] ne "") {
				if (!$ai_seq_args[0]{'npc'}{'sentTalk'}) {
					sendTalk(\$remote_socket, pack("L1",$ai_seq_args[0]{'mapSolution'}[$ai_seq_args[0]{'mapIndex'}]{'npc'}{'ID'}));
					$ai_seq_args[0]{'npc'}{'sentTalk'} = 1;
				} elsif ($ai_seq_args[0]{'mapSolution'}[$ai_seq_args[0]{'mapIndex'}]{'npc'}{'steps'}[$ai_seq_args[0]{'npc'}{'step'}] =~ /c/i) {
					sendTalkContinue(\$remote_socket, pack("L1",$ai_seq_args[0]{'mapSolution'}[$ai_seq_args[0]{'mapIndex'}]{'npc'}{'ID'}));
					$ai_seq_args[0]{'npc'}{'step'}++;
				} elsif ($ai_seq_args[0]{'mapSolution'}[$ai_seq_args[0]{'mapIndex'}]{'npc'}{'steps'}[$ai_seq_args[0]{'npc'}{'step'}] =~ /n/i) {
					sendTalkCancel(\$remote_socket, pack("L1",$ai_seq_args[0]{'mapSolution'}[$ai_seq_args[0]{'mapIndex'}]{'npc'}{'ID'}));
					$ai_seq_args[0]{'npc'}{'step'}++;
				} else {
					($ai_v{'temp'}{'arg'}) = $ai_seq_args[0]{'mapSolution'}[$ai_seq_args[0]{'mapIndex'}]{'npc'}{'steps'}[$ai_seq_args[0]{'npc'}{'step'}] =~ /r(\d+)/i;
					if ($ai_v{'temp'}{'arg'} ne "") {
						$ai_v{'temp'}{'arg'}++;
						sendTalkResponse(\$remote_socket, pack("L1",$ai_seq_args[0]{'mapSolution'}[$ai_seq_args[0]{'mapIndex'}]{'npc'}{'ID'}), $ai_v{'temp'}{'arg'});
					}
					$ai_seq_args[0]{'npc'}{'step'}++;
				}
				$timeout{'ai_route_npcTalk'}{'time'} = time;
				last ROUTE;
			}
		}
		if ($ai_seq_args[0]{'mapChanged'}) {
			print "Map changed - route failed\n" if $config{'debug'};
			$ai_seq_args[0]{'failed'} = 1;
			last ROUTE;

		} elsif (%{$ai_seq_args[0]{'last_pos'}}
			&& $chars[$config{'char'}]{'pos_to'}{'x'} != $ai_seq_args[0]{'solution'}[$ai_seq_args[0]{'index'}]{'x'}
			&& $chars[$config{'char'}]{'pos_to'}{'y'} != $ai_seq_args[0]{'solution'}[$ai_seq_args[0]{'index'}]{'y'}
			&& $ai_seq_args[0]{'last_pos'}{'x'} != $chars[$config{'char'}]{'pos_to'}{'x'}
			&& $ai_seq_args[0]{'last_pos'}{'y'} != $chars[$config{'char'}]{'pos_to'}{'y'}) {

			if ($ai_seq_args[0]{'dest_x_original'} ne "") {
				$ai_seq_args[0]{'dest_x'} = $ai_seq_args[0]{'dest_x_original'};
				$ai_seq_args[0]{'dest_y'} = $ai_seq_args[0]{'dest_y_original'};
			}
			print "Route logic - last pos\n" if $config{'debug'};
			undef @{$ai_seq_args[0]{'solution'}};
			undef %{$ai_seq_args[0]{'last_pos'}};
			undef $ai_seq_args[0]{'index'};
			undef $ai_seq_args[0]{'npc'};
			undef $ai_seq_args[0]{'divideIndex'};
	
		} else {
			if ($ai_seq_args[0]{'divideIndex'} && $chars[$config{'char'}]{'pos_to'}{'x'} != $ai_seq_args[0]{'solution'}[$ai_seq_args[0]{'index'}]{'x'}
				&& $chars[$config{'char'}]{'pos_to'}{'y'} != $ai_seq_args[0]{'solution'}[$ai_seq_args[0]{'index'}]{'y'}) {

				#we're stuck!
				print "Route logic - stuck\n" if $config{'debug'};
				$ai_v{'temp'}{'index_old'} = $ai_seq_args[0]{'index'};
				$ai_seq_args[0]{'index'} -= int($config{'route_step'} / $ai_seq_args[0]{'divideIndex'});
				$ai_seq_args[0]{'index'} = 0 if ($ai_seq_args[0]{'index'} < 0);
				$ai_v{'temp'}{'index'} = $ai_seq_args[0]{'index'};
				undef $ai_v{'temp'}{'done'};
				do {
					$ai_seq_args[0]{'divideIndex'}++;
					$ai_v{'temp'}{'index'} = $ai_seq_args[0]{'index'};
					$ai_v{'temp'}{'index'} += int($config{'route_step'} / $ai_seq_args[0]{'divideIndex'});
					$ai_v{'temp'}{'index'} = @{$ai_seq_args[0]{'solution'}} - 1 if ($ai_v{'temp'}{'index'} >= @{$ai_seq_args[0]{'solution'}});
					$ai_v{'temp'}{'done'} = 1 if (int($config{'route_step'} / $ai_seq_args[0]{'divideIndex'}) == 0);
				} while ($ai_v{'temp'}{'index'} >= $ai_v{'temp'}{'index_old'} && !$ai_v{'temp'}{'done'});
			} else {
				$ai_seq_args[0]{'divideIndex'} = 1;
				print "Route logic - divide index = 1\n" if $config{'debug'};
#Solos Start
				$pos_x = int($chars[$config{'char'}]{'pos_to'}{'x'}) if ($chars[$config{'char'}]{'pos_to'}{'x'} ne "");
				$pos_y = int($chars[$config{'char'}]{'pos_to'}{'y'}) if ($chars[$config{'char'}]{'pos_to'}{'y'} ne "");
#if kore is stuck
				if (($old_pos_x == $pos_x) && ($old_pos_y == $pos_y)) {
					$route_stuck++;
				} else {
					$route_stuck = 0;
					$old_pos_x = $pos_x;
					$old_pos_y = $pos_y;
				}
				if ($route_stuck >= 50) {
					ClearRouteAI("Route failed, clearing route AI to unstuck ...\n");
					last ROUTE;
				}
				if ($route_stuck >= 80) {
					$route_stuck = 0;
					Unstuck("Route failed, trying to unstuck ...\n");
					last ROUTE;
				}	
				if ($totalStuckCount >= 10) {
					RespawnUnstuck();
					last ROUTE;
				}		
#Solos End
			}

				
			if (int($config{'route_step'} / $ai_seq_args[0]{'divideIndex'}) == 0) {
				print "Route step - route failed\n" if $config{'debug'};
				$ai_seq_args[0]{'failed'} = 1;
				last ROUTE;
			}

			%{$ai_seq_args[0]{'last_pos'}} = %{$chars[$config{'char'}]{'pos_to'}};
			
			do {
				$ai_seq_args[0]{'index'} += int($config{'route_step'} / $ai_seq_args[0]{'divideIndex'});
				$ai_seq_args[0]{'index'} = @{$ai_seq_args[0]{'solution'}} - 1 if ($ai_seq_args[0]{'index'} >= @{$ai_seq_args[0]{'solution'}});
			} while ($ai_seq_args[0]{'solution'}[$ai_seq_args[0]{'index'}]{'x'} == $chars[$config{'char'}]{'pos_to'}{'x'}
				&& $ai_seq_args[0]{'solution'}[$ai_seq_args[0]{'index'}]{'y'} == $chars[$config{'char'}]{'pos_to'}{'y'}
				&& $ai_seq_args[0]{'index'} != @{$ai_seq_args[0]{'solution'}} - 1);
			
			if ($ai_seq_args[0]{'avoidPortals'}) {
				$ai_v{'temp'}{'first'} = 1;
				undef $ai_v{'temp'}{'foundID'};
				undef $ai_v{'temp'}{'smallDist'};
				foreach (@portalsID) {
					$ai_v{'temp'}{'dist'} = distance(\%{$ai_seq_args[0]{'solution'}[$ai_seq_args[0]{'index'}]}, \%{$portals{$_}{'pos'}});
					if ($ai_v{'temp'}{'dist'} <= 7 && ($ai_v{'temp'}{'first'} || $ai_v{'temp'}{'dist'} < $ai_v{'temp'}{'smallDist'})) {
						$ai_v{'temp'}{'smallDist'} = $ai_v{'temp'}{'dist'};
						$ai_v{'temp'}{'foundID'} = $_;
						undef $ai_v{'temp'}{'first'};
						print "Route logic - portal found\n" if $config{'debug'};
					}
				}
				if ($ai_v{'temp'}{'foundID'}) {
					print "Cannot found portal ID - route failed\n" if $config{'debug'};
					$ai_seq_args[0]{'failed'} = 1;
					last ROUTE;
				}
			}
			if ($ai_seq_args[0]{'solution'}[$ai_seq_args[0]{'index'}]{'x'} != $chars[$config{'char'}]{'pos_to'}{'x'}
				|| $ai_seq_args[0]{'solution'}[$ai_seq_args[0]{'index'}]{'y'} != $chars[$config{'char'}]{'pos_to'}{'y'}) {
				move($ai_seq_args[0]{'solution'}[$ai_seq_args[0]{'index'}]{'x'}, $ai_seq_args[0]{'solution'}[$ai_seq_args[0]{'index'}]{'y'}, 1, $ai_seq_args[0]{'attackID'});
			}
		}
	}
	} #END OF ROUTE BLOCK


	##### ROUTE_GETROUTE #####

	if ($ai_seq[0] eq "route_getRoute" && $ai_seq_args[0]{'suspended'}) {
		$ai_seq_args[0]{'time_giveup'}{'time'} += time - $ai_seq_args[0]{'suspended'};
		undef $ai_seq_args[0]{'suspended'};
	}
	if ($ai_seq[0] eq "route_getRoute" && ($ai_seq_args[0]{'done'} || $ai_seq_args[0]{'mapChanged'}
		|| ($ai_seq_args[0]{'time_giveup'}{'timeout'} && timeOut(\%{$ai_seq_args[0]{'time_giveup'}})))) {
		$timeout{'ai_route_calcRoute_cont'}{'time'} -= $timeout{'ai_route_calcRoute_cont'}{'timeout'};
		ai_route_getRoute_destroy(\%{$ai_seq_args[0]});
		shift @ai_seq;
		shift @ai_seq_args;

	} elsif ($ai_seq[0] eq "route_getRoute" && timeOut(\%{$timeout{'ai_route_calcRoute_cont'}})) {
		if (!$ai_seq_args[0]{'init'}) {
			undef @{$ai_v{'temp'}{'subSuc'}};
			undef @{$ai_v{'temp'}{'subSuc2'}};
			if (ai_route_getMap(\%{$ai_seq_args[0]}, $ai_seq_args[0]{'start'}{'x'}, $ai_seq_args[0]{'start'}{'y'})) {
				ai_route_getSuccessors(\%{$ai_seq_args[0]}, \%{$ai_seq_args[0]{'start'}}, \@{$ai_v{'temp'}{'subSuc'}},0);
				ai_route_getDiagSuccessors(\%{$ai_seq_args[0]}, \%{$ai_seq_args[0]{'start'}}, \@{$ai_v{'temp'}{'subSuc'}},0);
				foreach (@{$ai_v{'temp'}{'subSuc'}}) {
					ai_route_getSuccessors(\%{$ai_seq_args[0]}, \%{$_}, \@{$ai_v{'temp'}{'subSuc2'}},0);
					ai_route_getDiagSuccessors(\%{$ai_seq_args[0]}, \%{$_}, \@{$ai_v{'temp'}{'subSuc2'}},0);
				}
				if (@{$ai_v{'temp'}{'subSuc'}}) {
					%{$ai_seq_args[0]{'start'}} = %{$ai_v{'temp'}{'subSuc'}[0]};
				} elsif (@{$ai_v{'temp'}{'subSuc2'}}) {
					%{$ai_seq_args[0]{'start'}} = %{$ai_v{'temp'}{'subSuc2'}[0]};
				}
			}
			undef @{$ai_v{'temp'}{'subSuc'}};
			undef @{$ai_v{'temp'}{'subSuc2'}};
			if (ai_route_getMap(\%{$ai_seq_args[0]}, $ai_seq_args[0]{'dest'}{'x'}, $ai_seq_args[0]{'dest'}{'y'})) {
				ai_route_getSuccessors(\%{$ai_seq_args[0]}, \%{$ai_seq_args[0]{'dest'}}, \@{$ai_v{'temp'}{'subSuc'}},0);
				ai_route_getDiagSuccessors(\%{$ai_seq_args[0]}, \%{$ai_seq_args[0]{'dest'}}, \@{$ai_v{'temp'}{'subSuc'}},0);
				foreach (@{$ai_v{'temp'}{'subSuc'}}) {
					ai_route_getSuccessors(\%{$ai_seq_args[0]}, \%{$_}, \@{$ai_v{'temp'}{'subSuc2'}},0);
					ai_route_getDiagSuccessors(\%{$ai_seq_args[0]}, \%{$_}, \@{$ai_v{'temp'}{'subSuc2'}},0);
				}
				if (@{$ai_v{'temp'}{'subSuc'}}) {
					%{$ai_seq_args[0]{'dest'}} = %{$ai_v{'temp'}{'subSuc'}[0]};
				} elsif (@{$ai_v{'temp'}{'subSuc2'}}) {
					%{$ai_seq_args[0]{'dest'}} = %{$ai_v{'temp'}{'subSuc2'}[0]};
				}
			}
			$ai_seq_args[0]{'timeout'} = $timeout{'ai_route_calcRoute'}{'timeout'}*1000;
		}
		$ai_seq_args[0]{'init'} = 1;
		ai_route_searchStep(\%{$ai_seq_args[0]});
		$timeout{'ai_route_calcRoute_cont'}{'time'} = time;
		ai_setSuspend(0);
	}

	##### ROUTE_GETMAPROUTE #####

	ROUTE_GETMAPROUTE: {

	if ($ai_seq[0] eq "route_getMapRoute" && $ai_seq_args[0]{'suspended'}) {
		$ai_seq_args[0]{'time_giveup'}{'time'} += time - $ai_seq_args[0]{'suspended'};
		undef $ai_seq_args[0]{'suspended'};
	}
	if ($ai_seq[0] eq "route_getMapRoute" && ($ai_seq_args[0]{'done'} || $ai_seq_args[0]{'mapChanged'}
		|| ($ai_seq_args[0]{'time_giveup'}{'timeout'} && timeOut(\%{$ai_seq_args[0]{'time_giveup'}})))) {
		$timeout{'ai_route_calcRoute_cont'}{'time'} -= $timeout{'ai_route_calcRoute_cont'}{'timeout'};
		shift @ai_seq;
		shift @ai_seq_args;

	} elsif ($ai_seq[0] eq "route_getMapRoute" && timeOut(\%{$timeout{'ai_route_calcRoute_cont'}})) {
		if (!%{$ai_seq_args[0]{'start'}}) {
			%{$ai_seq_args[0]{'start'}{'dest'}{'pos'}} = %{$ai_seq_args[0]{'r_start_pos'}};
			$ai_seq_args[0]{'start'}{'dest'}{'map'} = $ai_seq_args[0]{'r_start_field'}{'name'};
			$ai_seq_args[0]{'start'}{'dest'}{'field'} = $ai_seq_args[0]{'r_start_field'};
			%{$ai_seq_args[0]{'dest'}{'source'}{'pos'}} = %{$ai_seq_args[0]{'r_dest_pos'}};
			$ai_seq_args[0]{'dest'}{'source'}{'map'} = $ai_seq_args[0]{'r_dest_field'}{'name'};
			$ai_seq_args[0]{'dest'}{'source'}{'field'} = $ai_seq_args[0]{'r_dest_field'};
			push @{$ai_seq_args[0]{'openList'}}, \%{$ai_seq_args[0]{'start'}};
		}
		$timeout{'ai_route_calcRoute'}{'time'} = time;
		while (!$ai_seq_args[0]{'done'} && !timeOut(\%{$timeout{'ai_route_calcRoute'}})) {
			ai_mapRoute_searchStep(\%{$ai_seq_args[0]});
			last ROUTE_GETMAPROUTE if ($ai_seq[0] ne "route_getMapRoute");
		}

		if ($ai_seq_args[0]{'done'}) {
			@{$ai_seq_args[0]{'returnArray'}} = @{$ai_seq_args[0]{'solutionList'}};
		}
		$timeout{'ai_route_calcRoute_cont'}{'time'} = time;
		ai_setSuspend(0);
	}

	} #End of block ROUTE_GETMAPROUTE


	##### ITEMS TAKE #####
	# Look for loot to pickup when your monster died.

	if ($ai_seq[0] eq "items_take" && $ai_seq_args[0]{'suspended'}) {
		$ai_seq_args[0]{'ai_items_take_start'}{'time'} += time - $ai_seq_args[0]{'suspended'};
		$ai_seq_args[0]{'ai_items_take_end'}{'time'} += time - $ai_seq_args[0]{'suspended'};
		undef $ai_seq_args[0]{'suspended'};
	}
	if ($ai_seq[0] eq "items_take" && (percent_weight(\%{$chars[$config{'char'}]}) >= $config{'itemsMaxWeight'})) {
		shift @ai_seq;
		shift @ai_seq_args;
		ai_clientSuspend(0, $timeout{'ai_attack_waitAfterKill'}{'timeout'});
	}
	if ($config{'itemsTakeAuto'} && $ai_seq[0] eq "items_take" && timeOut(\%{$ai_seq_args[0]{'ai_items_take_start'}})) {
		undef $ai_v{'temp'}{'foundID'};
		foreach (@itemsID) {
			next if ($_ eq "" || $itemsPickup{lc($items{$_}{'name'})} eq "0" || (!$itemsPickup{'all'} && !$itemsPickup{lc($items{$_}{'name'})}));
			$ai_v{'temp'}{'dist'} = distance(\%{$items{$_}{'pos'}}, \%{$ai_seq_args[0]{'pos'}});
			$ai_v{'temp'}{'dist_to'} = distance(\%{$items{$_}{'pos'}}, \%{$ai_seq_args[0]{'pos_to'}});
			if (($ai_v{'temp'}{'dist'} <= 4 || $ai_v{'temp'}{'dist_to'} <= 4) && $items{$_}{'take_failed'} == 0) {
				$ai_v{'temp'}{'foundID'} = $_;
				last;
			}
		}
		if ($ai_v{'temp'}{'foundID'}) {
			$ai_seq_args[0]{'ai_items_take_end'}{'time'} = time;
			$ai_seq_args[0]{'started'} = 1;
			take($ai_v{'temp'}{'foundID'});
		} elsif ($ai_seq_args[0]{'started'} || timeOut(\%{$ai_seq_args[0]{'ai_items_take_end'}})) {
			shift @ai_seq;
			shift @ai_seq_args;
			ai_clientSuspend(0, $timeout{'ai_attack_waitAfterKill'}{'timeout'});
		}
	}



	##### ITEMS AUTO-GATHER #####


	if (($ai_seq[0] eq "" || $ai_seq[0] eq "follow" || $ai_seq[0] eq "route" || $ai_seq[0] eq "route_getRoute" || $ai_seq[0] eq "route_getMapRoute")
	    && $config{'itemsGatherAuto'}
	    && !(percent_weight(\%{$chars[$config{'char'}]}) >= $config{'itemsMaxWeight'})
	    && timeOut(\%{$timeout{'ai_items_gather_auto'}})) {
		undef @{$ai_v{'ai_items_gather_foundIDs'}};
		foreach (@playersID) {
			next if ($_ eq "");
			if (!%{$chars[$config{'char'}]{'party'}} || !%{$chars[$config{'char'}]{'party'}{'users'}{$_}}) {
				push @{$ai_v{'ai_items_gather_foundIDs'}}, $_;
			}
		}
		foreach $item (@itemsID) {
			next if ($item eq "" || time - $items{$item}{'appear_time'} < $timeout{'ai_items_gather_start'}{'timeout'}
				|| $items{$item}{'take_failed'} >= 1
				|| $itemsPickup{lc($items{$item}{'name'})} eq "0" || (!$itemsPickup{'all'} && !$itemsPickup{lc($items{$item}{'name'})}));
			undef $ai_v{'temp'}{'dist'};
			undef $ai_v{'temp'}{'found'};
			foreach (@{$ai_v{'ai_items_gather_foundIDs'}}) {
				$ai_v{'temp'}{'dist'} = distance(\%{$items{$item}{'pos'}}, \%{$players{$_}{'pos_to'}});
				if ($ai_v{'temp'}{'dist'} < 9) {
					$ai_v{'temp'}{'found'} = 1;
					last;
				}
			}
			if ($ai_v{'temp'}{'found'} == 0) {
				gather($item);
				last;
			}
		}
		$timeout{'ai_items_gather_auto'}{'time'} = time;
	}



	##### ITEMS GATHER #####


	if ($ai_seq[0] eq "items_gather" && $ai_seq_args[0]{'suspended'}) {
		$ai_seq_args[0]{'ai_items_gather_giveup'}{'time'} += time - $ai_seq_args[0]{'suspended'};
		undef $ai_seq_args[0]{'suspended'};
	}
	if ($ai_seq[0] eq "items_gather" && !%{$items{$ai_seq_args[0]{'ID'}}}) {
		if (!$config{'XKore'}) {
			print "Failed to gather $items_old{$ai_seq_args[0]{'ID'}}{'name'} ($items_old{$ai_seq_args[0]{'ID'}}{'binID'}) : Lost target\n";
		} else {
			injectMessage("Failed to gather $items_old{$ai_seq_args[0]{'ID'}}{'name'} ($items_old{$ai_seq_args[0]{'ID'}}{'binID'}) : Lost target") if ($config{'verbose'});
		}
		shift @ai_seq;
		shift @ai_seq_args;
	} elsif ($ai_seq[0] eq "items_gather") {
		undef $ai_v{'temp'}{'dist'};
		undef @{$ai_v{'ai_items_gather_foundIDs'}};
		undef $ai_v{'temp'}{'found'};
		foreach (@playersID) {
			next if ($_ eq "");
			if (%{$chars[$config{'char'}]{'party'}} && !%{$chars[$config{'char'}]{'party'}{'users'}{$_}}) {
				push @{$ai_v{'ai_items_gather_foundIDs'}}, $_;
			}
		}
		foreach (@{$ai_v{'ai_items_gather_foundIDs'}}) {
			$ai_v{'temp'}{'dist'} = distance(\%{$items{$ai_seq_args[0]{'ID'}}{'pos'}}, \%{$players{$_}{'pos'}});
			if ($ai_v{'temp'}{'dist'} < 9) {
				$ai_v{'temp'}{'found'}++;
			}
		}
		$ai_v{'temp'}{'dist'} = distance(\%{$items{$ai_seq_args[0]{'ID'}}{'pos'}}, \%{$chars[$config{'char'}]{'pos_to'}});
		if (timeOut(\%{$ai_seq_args[0]{'ai_items_gather_giveup'}})) {
			print "Failed to gather $items{$ai_seq_args[0]{'ID'}}{'name'} ($items{$ai_seq_args[0]{'ID'}}{'binID'}) : Timeout\n";
			injectMessage("Failed to gather $items{$ai_seq_args[0]{'ID'}}{'name'} ($items{$ai_seq_args[0]{'ID'}}{'binID'}) : Timeout") if ($config{'XKore'} && $config{'verbose'});
			$items{$ai_seq_args[0]{'ID'}}{'take_failed'}++;
			shift @ai_seq;
			shift @ai_seq_args;
		} elsif ($chars[$config{'char'}]{'sitting'}) {
			ai_setSuspend(0);
			stand();
		} elsif ($ai_v{'temp'}{'found'} == 0 && $ai_v{'temp'}{'dist'} > 2) {
			getVector(\%{$ai_v{'temp'}{'vec'}}, \%{$items{$ai_seq_args[0]{'ID'}}{'pos'}}, \%{$chars[$config{'char'}]{'pos_to'}});
			moveAlongVector(\%{$ai_v{'temp'}{'pos'}}, \%{$chars[$config{'char'}]{'pos_to'}}, \%{$ai_v{'temp'}{'vec'}}, $ai_v{'temp'}{'dist'} - 1);
			move($ai_v{'temp'}{'pos'}{'x'}, $ai_v{'temp'}{'pos'}{'y'});
		} elsif ($ai_v{'temp'}{'found'} == 0) {
			$ai_v{'ai_items_gather_ID'} = $ai_seq_args[0]{'ID'};
			shift @ai_seq;
			shift @ai_seq_args;
			take($ai_v{'ai_items_gather_ID'});
		} elsif ($ai_v{'temp'}{'found'} > 0) {
			print "Failed to gather $items{$ai_seq_args[0]{'ID'}}{'name'} ($items{$ai_seq_args[0]{'ID'}}{'binID'}) : No looting!\n";
			injectMessage("Failed to gather $items{$ai_seq_args[0]{'ID'}}{'name'} ($items{$ai_seq_args[0]{'ID'}}{'binID'}) : No looting!") if ($config{'XKore'} && $config{'verbose'});
			shift @ai_seq;
			shift @ai_seq_args;
		}
	}



	##### TAKE #####


	if ($ai_seq[0] eq "take" && $ai_seq_args[0]{'suspended'}) {
		$ai_seq_args[0]{'ai_take_giveup'}{'time'} += time - $ai_seq_args[0]{'suspended'};
		undef $ai_seq_args[0]{'suspended'};
	}
	if ($ai_seq[0] eq "take" && !%{$items{$ai_seq_args[0]{'ID'}}}) {
		shift @ai_seq;
		shift @ai_seq_args;

	} elsif ($ai_seq[0] eq "take" && timeOut(\%{$ai_seq_args[0]{'ai_take_giveup'}})) {
		print "Failed to take $items{$ai_seq_args[0]{'ID'}}{'name'} ($items{$ai_seq_args[0]{'ID'}}{'binID'})\n";
		injectMessage("Failed to take $items{$ai_seq_args[0]{'ID'}}{'name'} ($items{$ai_seq_args[0]{'ID'}}{'binID'})") if ($config{'XKore'} && $config{'verbose'});
		$items{$ai_seq_args[0]{'ID'}}{'take_failed'}++;
		shift @ai_seq;
		shift @ai_seq_args;

	} elsif ($ai_seq[0] eq "take") {

		$ai_v{'temp'}{'dist'} = distance(\%{$items{$ai_seq_args[0]{'ID'}}{'pos'}}, \%{$chars[$config{'char'}]{'pos_to'}});
		if ($chars[$config{'char'}]{'sitting'}) {
			stand();
		} elsif ($ai_v{'temp'}{'dist'} > 2) {
			getVector(\%{$ai_v{'temp'}{'vec'}}, \%{$items{$ai_seq_args[0]{'ID'}}{'pos'}}, \%{$chars[$config{'char'}]{'pos_to'}});
			moveAlongVector(\%{$ai_v{'temp'}{'pos'}}, \%{$chars[$config{'char'}]{'pos_to'}}, \%{$ai_v{'temp'}{'vec'}}, $ai_v{'temp'}{'dist'} - 1);
			move($ai_v{'temp'}{'pos'}{'x'}, $ai_v{'temp'}{'pos'}{'y'});
		} elsif (timeOut(\%{$timeout{'ai_take'}})) {
			sendTake(\$remote_socket, $ai_seq_args[0]{'ID'});
			$timeout{'ai_take'}{'time'} = time;
		}
	}

	
	##### MOVE #####


	if ($ai_seq[0] eq "move" && $ai_seq_args[0]{'suspended'}) {
		$ai_seq_args[0]{'ai_move_giveup'}{'time'} += time - $ai_seq_args[0]{'suspended'};
		undef $ai_seq_args[0]{'suspended'};
	}
	if ($ai_seq[0] eq "move") {
		if (!$ai_seq_args[0]{'ai_moved'} && $ai_seq_args[0]{'ai_moved_tried'} && $ai_seq_args[0]{'ai_move_time_last'} != $chars[$config{'char'}]{'time_move'}) {
			$ai_seq_args[0]{'ai_moved'} = 1;
		}
		if ($chars[$config{'char'}]{'sitting'}) {
			ai_setSuspend(0);
			stand();
		} elsif (!$ai_seq_args[0]{'ai_moved'} && timeOut(\%{$ai_seq_args[0]{'ai_move_giveup'}})) {
			shift @ai_seq;
			shift @ai_seq_args;
		} elsif (!$ai_seq_args[0]{'ai_moved_tried'}) {
			sendMove(\$remote_socket, int($ai_seq_args[0]{'move_to'}{'x'}), int($ai_seq_args[0]{'move_to'}{'y'}));
			$ai_seq_args[0]{'ai_move_giveup'}{'time'} = time;
			$ai_seq_args[0]{'ai_move_time_last'} = $chars[$config{'char'}]{'time_move'};
			$ai_seq_args[0]{'ai_moved_tried'} = 1;
		} elsif ($ai_seq_args[0]{'ai_moved'} && time - $chars[$config{'char'}]{'time_move'} >= $chars[$config{'char'}]{'time_move_calc'}) {
			shift @ai_seq;
			shift @ai_seq_args;
		}
	}



	##### AUTO-TELEPORT #####

	($ai_v{'map_name_lu'}) = $map_name =~ /([\s\S]*)\./;
	$ai_v{'map_name_lu'} .= ".rsw";
	if ($config{'teleportAuto_onlyWhenSafe'} && binSize(\@playersID)) {
		undef $ai_v{'ai_teleport_safe'};
		if (!$cities_lut{$ai_v{'map_name_lu'}} && timeOut(\%{$timeout{'ai_teleport_safe_force'}})) {
			$ai_v{'ai_teleport_safe'} = 1;
		}
	} elsif (!$cities_lut{$ai_v{'map_name_lu'}}) {
		$ai_v{'ai_teleport_safe'} = 1;
		$timeout{'ai_teleport_safe_force'}{'time'} = time;
	} else {
		undef $ai_v{'ai_teleport_safe'};
	}

	if (timeOut(\%{$timeout{'ai_teleport_away'}}) && $ai_v{'ai_teleport_safe'}) {
		foreach (@monstersID) {
			if ($mon_control{lc($monsters{$_}{'name'})}{'teleport_auto'}) {
				useTeleport(1);
				$ai_v{'temp'}{'search'} = 1;
				last;
			}
		}
		$timeout{'ai_teleport_away'}{'time'} = time;
	}

	if ((($config{'teleportAuto_hp'} && percent_hp(\%{$chars[$config{'char'}]}) <= $config{'teleportAuto_hp'} && ai_getAggressives())
		|| ($config{'teleportAuto_minAggressives'} && ai_getAggressives() >= $config{'teleportAuto_minAggressives'}))
		&& $ai_v{'ai_teleport_safe'} && timeOut(\%{$timeout{'ai_teleport_hp'}})) {
		useTeleport(1);
		$ai_v{'clear_aiQueue'} = 1;
		$timeout{'ai_teleport_hp'}{'time'} = time;
	}

	if ($config{'teleportAuto_search'} && timeOut(\%{$timeout{'ai_teleport_search'}}) && binFind(\@ai_seq, "attack") eq "" && binFind(\@ai_seq, "items_take") eq ""
	 && $ai_v{'ai_teleport_safe'} && binFind(\@ai_seq, "sitAuto") eq "" 
	 && binFind(\@ai_seq, "buyAuto") eq "" && binFind(\@ai_seq, "sellAuto") eq "" && binFind(\@ai_seq, "storageAuto") eq "" 
	 && ($ai_v{'map_name_lu'} eq $config{'lockMap'}.'.rsw' || $config{'lockMap'} eq "")) {
		undef $ai_v{'temp'}{'search'};
		foreach (keys %mon_control) {
			if ($mon_control{$_}{'teleport_search'}) {
				$ai_v{'temp'}{'search'} = 1;
				last;
			}
		}
		if ($ai_v{'temp'}{'search'}) {
			undef $ai_v{'temp'}{'found'};
			foreach (@monstersID) {
				if ($mon_control{lc($monsters{$_}{'name'})}{'teleport_search'} && !$monsters{$_}{'attack_failed'}) {
					$ai_v{'temp'}{'found'} = 1;
					last;
				}
			}
			if (!$ai_v{'temp'}{'found'}) {
				useTeleport(1);
				$ai_v{'clear_aiQueue'} = 1;
			}
		}
		$timeout{'ai_teleport_search'}{'time'} = time;
	}

	if ($config{'teleportAuto_idle'} && $ai_seq[0] ne "") {
		$timeout{'ai_teleport_idle'}{'time'} = time;
	}

	if ($config{'teleportAuto_idle'} && timeOut(\%{$timeout{'ai_teleport_idle'}}) && $ai_v{'ai_teleport_safe'}) {
		useTeleport(1);
		$ai_v{'clear_aiQueue'} = 1;
		$timeout{'ai_teleport_idle'}{'time'} = time;
	}

	if ($config{'teleportAuto_portal'} && timeOut(\%{$timeout{'ai_teleport_portal'}}) && $ai_v{'ai_teleport_safe'}) {
		if (binSize(\@portalsID)) {
			useTeleport(1);
			$ai_v{'clear_aiQueue'} = 1;
		}
		$timeout{'ai_teleport_portal'}{'time'} = time;
	}

	##### AUTO RESPONSE #####

	if ($ai_seq[0] eq "respAuto" && time >= $nextresptime) {
		$i = $ai_seq_args[0]{'resp_num'};
		$num_resp = getListCount($chat_resp{"words_resp_$i"});
		sendMessage(\$remote_socket, "c", getFromList($chat_resp{"words_resp_$i"}, int(rand() * ($num_resp - 1))));
		shift @ai_seq;
		shift @ai_seq_args;
	}

	if ($ai_seq[0] eq "respPMAuto" && time >= $nextrespPMtime) {
		$i = $ai_seq_args[0]{'resp_num'};
		$privMsgUser = $ai_seq_args[0]{'resp_user'};
		$num_resp = getListCount($chat_resp{"words_resp_$i"});
		sendMessage(\$remote_socket, "pm", getFromList($chat_resp{"words_resp_$i"}, int(rand() * ($num_resp - 1))), $privMsgUser);
		shift @ai_seq;
		shift @ai_seq_args;
	}


	#BCN Start - DealDump
	##### DEAL AUTO ACCEPT #####

	if ($ai_seq[0] eq "dealAutoAccept" && time >= $ai_seq_args[0]{'time'}) {
		if ($ai_seq_args[0]{'mode'} eq "engage") {
			print "[DealDump] Accepted deal request from " . $ai_seq_args[0]{'name'} . "\n" if ($config{'dealAutoAccept_debug'});
			sendDealAccept(\$remote_socket);
         
			my $args = ();
			$args{'mode'} = "finalize";
			$args{'time'} = time + 0.2;

			shift @ai_seq;
			shift @ai_seq_args;

			unshift @ai_seq, "dealAutoAccept";
			unshift @ai_seq_args, \%args;

		} elsif ($ai_seq_args[0]{'mode'} eq "finalize") {
			print "[DealDump] Finalized the deal.\n" if ($config{'dealAutoAccept_debug'});
			sendDealFinalize(\$remote_socket);

			shift @ai_seq;
			shift @ai_seq_args;         

		} elsif ($ai_seq_args[0]{'mode'} eq "accept") {
			print "[DealDump] Accepted the final deal.\n" if ($config{'dealAutoAccept_debug'});
			sendDealTrade(\$remote_socket);
      
			shift @ai_seq;
			shift @ai_seq_args;
		}
	}
	#BCN End - DealDump

	##### AVOID GM OR PLAYERS #####

	if (timeOut(\%{$timeout{'ai_avoidcheck'}})) {
		if ($config{'avoidGM_near'} && (!$config{'avoidGM_near_inTown'} || !$cities_lut{$field{'name'}.'.rsw'})) {
			avoidGM_near ();
		}
		if ($config{'avoidList'}) {
			avoidList_near ();
		}
		$timeout{'ai_avoidcheck'}{'time'} = time;
	}


	##### SEND EMOTICON #####

	SENDEMOTION: {
		my $index = binFind(\@ai_seq, "sendEmotion");
		last SENDEMOTION if ($index eq "" || time < $ai_seq_args[$index]{'timeout'});
		sendEmotion(\$remote_socket, $ai_seq_args[$index]{'emotion'});
		aiRemove ("sendEmotion");
	}


	##### AUTO SHOP OPEN #####

	if ($config{"shopAuto_open"} && $ai_seq[0] eq "" && $conState == 5 && !$shopstarted && $chars[$config{'char'}]{'sitting'}
	    && timeOut(\%{$timeout{'ai_shop'}})) {
		sendOpenShop(\$remote_socket);
	}


	##########

	# DEBUG CODE
	if (time - $ai_v{'time'} > 2 && $config{'debug'} >= 2) {
		$stuff = @ai_seq_args;
		print "AI: @ai_seq | $stuff\n";
		$ai_v{'time'} = time;
	}

	if ($ai_v{'clear_aiQueue'}) {
		undef $ai_v{'clear_aiQueue'};
		undef @ai_seq;
		undef @ai_seq_args;
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
	print "Packet Switch SENT_BY_CLIENT: $switch\n" if ($config{'debugPacket_ro_sent'} && !existsInList($config{'debugPacket_exclude'}, $switch));

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
		$timeout{'ai'}{'time'} = time;
		if ($firstLoginMap) {
			undef $sentWelcomeMessage;
			undef $firstLoginMap;
		}
		$timeout{'welcomeText'}{'time'} = time;
		print "Map loaded\n";

	} elsif ($switch eq "0085") {
		# Move
		aiRemove("clientSuspend");
		makeCoords(\%coords, substr($msg, 2, 3));
		ai_clientSuspend($switch, (distance(\%{$chars[$config{'char'}]{'pos'}}, \%coords) * $config{'seconds_per_block'}) + 2);
		
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
}


#######################################
#######################################
#Parse Message
#######################################
#######################################



##
# parseMsg($msg)
# $msg: The data to parse, as received from the socket.
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
	print "Packet Switch: $switch\n" if ($config{'debugPacket_received'} && !existsInList($config{'debugPacket_exclude'}, $switch));


	# Handle unparsed packets
	if ($lastswitch eq $switch && length($msg) > $lastMsgLength) {
		$errorCount++;
	} else {
		$errorCount = 0;
	}
	if ($errorCount > 3) {
		print "Caught unparsed packet error, potential loss of data.\n";
		dumpData($msg) if ($config{'debugPacket_unparsed'} && !existsInList($config{'debugPacket_exclude'}, $switch));
		$errorCount = 0;
		$msg_size = length($msg);
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
			if (length($msg) < $rpackets{$switch}) {
				return $msg;
			}
			$msg_size = $rpackets{$switch};

		} else {
			dumpData($last_know_msg.$msg);
		}

		$last_know_msg = substr($msg, 0, $msg_size);
		$last_know_switch = $switch;
	}
	$lastMsgLength = length($msg);


	if ((substr($msg,0,4) eq $accountID && ($conState == 2 || $conState == 4)) || ($config{'XKore'} && !$accountID && length($msg) == 4)) {
		$accountID = substr($msg, 0, 4);
		$AI = 1 if (!$AI_forcedOff);
		if ($config{'encrypt'} && $conState == 4) {
			$encryptKey1 = unpack("L1", substr($msg, 6, 4));
			$encryptKey2 = unpack("L1", substr($msg, 10, 4));
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
	} elsif ($switch eq "0069" && length($msg) >= unpack("S1", substr($msg, 2, 2))) {
		$msg_size = unpack("S1", substr($msg, 2, 2));
		$conState = 2;
		undef $conState_tries;
		if ($versionSearch) {
			$versionSearch = 0;
			writeDataFileIntact($config_file, \%config);
		}
		$sessionID = substr($msg, 4, 4);
		$accountID = substr($msg, 8, 4);
		$accountSex = unpack("C1",substr($msg, 46, 1));
		$accountSex2 = ($config{'sex'} ne "") ? $config{'sex'} : $accountSex;
		format ACCOUNT =
---------Account Info----------
Account ID: @<<<<<<<<<<<<<<<<<<
            getHex($accountID)
Sex:        @<<<<<<<<<<<<<<<<<<
            $sex_lut{$accountSex}
Session ID: @<<<<<<<<<<<<<<<<<<
            getHex($sessionID)
-------------------------------
.
		$~ = "ACCOUNT";
		write;
		$num = 0;
		undef @servers;
		for($i = 47; $i < $msg_size; $i+=32) {
			$servers[$num]{'ip'} = makeIP(substr($msg, $i, 4));
			$servers[$num]{'port'} = unpack("S1", substr($msg, $i+4, 2));
			($servers[$num]{'name'}) = substr($msg, $i + 6, 20) =~ /([\s\S]*?)\000/;
			$servers[$num]{'users'} = unpack("L",substr($msg, $i + 26, 4));
			$num++;
		}
		$~ = "SERVERS";
		print "--------- Servers ----------\n";
		print "#         Name            Users  IP              Port\n";
		for ($num = 0; $num < @servers; $num++) {
			format SERVERS =
@<< @<<<<<<<<<<<<<<<<<<<< @<<<<< @<<<<<<<<<<<<<< @<<<<<
$num  $servers[$num]{'name'}  $servers[$num]{'users'} $servers[$num]{'ip'} $servers[$num]{'port'}
.
			write;
		}
		print "-------------------------------\n";

		if (!$config{'XKore'}) {
			print "Closing connection to Master Server\n";
			killConnection(\$remote_socket);
			if ($config{'server'} eq "") {
				print "Choose your server.  Enter the server number:\n";
				$waitingForInput = 1;
			} else {
				print "Server $config{'server'} selected\n";
			}
		}

	} elsif ($switch eq "006A") {
		$type = unpack("C1",substr($msg, 2, 1));
		if ($type == 0) {
			print "Account name doesn't exist\n";
			if (!$config{'XKore'}) {
				print "Enter Username Again:\n";
				$input_socket->recv($msg, $MAX_READ);
				$config{'username'} = $msg;
				writeDataFileIntact($config_file, \%config);
			}
		} elsif ($type == 1) {
			print "Password Error\n";
			if (!$config{'XKore'}) {
				print "Enter Password Again:\n";
				$input_socket->recv($msg, $MAX_READ);
				$config{'password'} = $msg;
				writeDataFileIntact($config_file, \%config);
			}
		} elsif ($type == 3) {
			print "Server connection has been denied\n";
		} elsif ($type == 4) {
			print "Critical Error: Account has been disabled by evil Gravity\n";
			$quit = 1;
		} elsif ($type == 5) {
			print "Version $config{'version'} failed...trying to find version\n";
			$config{'version'}++;
			if (!$versionSearch) {
				$config{'version'} = 0;
				$versionSearch = 1;
			}
		} elsif ($type == 6) {
			print "The server is temporarily blocking your connection\n";
		}
		if ($type != 5 && $versionSearch) {
			$versionSearch = 0;
			writeDataFileIntact($config_file, \%config);
		}

	} elsif ($switch eq "006B") {
		print "Recieved characters from Game Login Server\n";
		$conState = 3;
		undef $conState_tries;
		$msg_size = unpack("S1", substr($msg, 2, 2));
		if ($config{"master_version_$config{'master'}"} ne "" && $config{"master_version_$config{'master'}"} == 0) {
			$startVal = 24;
		} else {
			$startVal = 4;
		}
		for($i = $startVal; $i < $msg_size; $i+=106) {

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
		$~ = "CHAR";
		for ($num = 0; $num < @chars; $num++) {
			format CHAR =
-------  Character @< ---------
         $num
Name: @<<<<<<<<<<<<<<<<<<<<<<<<
      $chars[$num]{'name'}
Job:  @<<<<<<<      Job Exp: @<<<<<<<
$jobs_lut{$chars[$num]{'jobID'}} $chars[$num]{'exp_job'}
Lv:   @<<<<<<<      Str: @<<<<<<<<
$chars[$num]{'lv'}  $chars[$num]{'str'}
J.Lv: @<<<<<<<      Agi: @<<<<<<<<
$chars[$num]{'lv_job'}  $chars[$num]{'agi'}
Exp:  @<<<<<<<      Vit: @<<<<<<<<
$chars[$num]{'exp'} $chars[$num]{'vit'}
HP:   @||||/@||||   Int: @<<<<<<<<
$chars[$num]{'hp'} $chars[$num]{'hp_max'} $chars[$num]{'int'}
SP:   @||||/@||||   Dex: @<<<<<<<<
$chars[$num]{'sp'} $chars[$num]{'sp_max'} $chars[$num]{'dex'}
Zenny: @<<<<<<<<<<  Luk: @<<<<<<<<
$chars[$num]{'zenny'} $chars[$num]{'luk'}
-------------------------------
.
			write;
		}
		if (!$config{'XKore'}) {
			if ($config{'char'} eq "") {
				print "Choose your character.  Enter the character number:\n";
				$waitingForInput = 1;
			} else {
				print "Character $config{'char'} selected\n";
				sendCharLogin(\$remote_socket, $config{'char'});
				$timeout{'charlogin'}{'time'} = time;
			}
		}
		$firstLoginMap = 1;
		$sentWelcomeMessage = 1;
		$msg_size = length($msg);

	} elsif ($switch eq "006C") {
		print "Error logging into Game Login Server (invalid character specified)...\n";
		$conState = 1;
		undef $conState_tries;
		$timeout_ex{'master'}{'time'} = time;
		$timeout_ex{'master'}{'timeout'} = $timeout{'reconnect'}{'timeout'};
		killConnection(\$remote_socket);

	} elsif ($switch eq "006E") {

	} elsif ($switch eq "0071") {
		print "Recieved character ID and Map IP from Game Login Server\n";
		$conState = 4;
		undef $conState_tries;
		$charID = substr($msg, 2, 4);
		($map_name) = substr($msg, 6, 16) =~ /([\s\S]*?)\000/;

		($ai_v{'temp'}{'map'}) = $map_name =~ /([\s\S]*)\./;
		if ($ai_v{'temp'}{'map'} ne $field{'name'}) {
			getField("fields/$ai_v{'temp'}{'map'}.fld", \%field);
		}

		$map_ip = makeIP(substr($msg, 22, 4));
		$map_port = unpack("S1", substr($msg, 26, 2));
		format CHARINFO =
---------Game Info----------
Char ID: @<<<<<<<<<<<<<<<<<<
            getHex($charID)
MAP Name: @<<<<<<<<<<<<<<<<<<
            $map_name
MAP IP: @<<<<<<<<<<<<<<<<<<
            $map_ip
MAP Port: @<<<<<<<<<<<<<<<<<<
	$map_port
-------------------------------
.
		$~ = "CHARINFO";
		write;
		print "Closing connection to Game Login Server\n" if (!$config{'XKore'});
		killConnection(\$remote_socket) if (!$config{'XKore'});
#Solos Start
		initStatVars();
#Solos End

	} elsif ($switch eq "0073") {
		$conState = 5;
		undef $conState_tries;
		makeCoords(\%{$chars[$config{'char'}]{'pos'}}, substr($msg, 6, 3));
		%{$chars[$config{'char'}]{'pos_to'}} = %{$chars[$config{'char'}]{'pos'}};
		print "Your Coordinates: $chars[$config{'char'}]{'pos'}{'x'}, $chars[$config{'char'}]{'pos'}{'y'}\n" if $config{'debug'};
		print "You are now in the game\n" if (!$config{'XKore'});
		print "Waiting for map to load...\n" if ($config{'XKore'});
		sendMapLoaded(\$remote_socket) if (!$config{'XKore'});
		sendIgnoreAll(\$remote_socket, "all") if ($config{'ignoreAll'});
		$timeout{'ai'}{'time'} = time if (!$config{'XKore'});

	} elsif ($switch eq "0075") {
		$conState = 5 if ($conState != 4 && $config{'XKore'});

	} elsif ($switch eq "0077") {
		$conState = 5 if ($conState != 4 && $config{'XKore'});

	} elsif ($switch eq "0078" && length($msg) >= 52) {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		$ID = substr($msg, 2, 4);
		makeCoords(\%coords, substr($msg, 46, 3));
		$type = unpack("S*",substr($msg, 14,  2));
		$pet = unpack("C*",substr($msg, 16,  1));
		$sex = unpack("C*",substr($msg, 45,  1));
		$sitting = unpack("C*",substr($msg, 51,  1));
		if ($type >= 1000) {
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
				print "Pet Exists: $pets{$ID}{'name'} ($pets{$ID}{'binID'})\n" if ($config{'debug'});
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

				print "Monster Exists: $monsters{$ID}{'name'} ($monsters{$ID}{'binID'})\n" if ($config{'debug'});

				my $prevState = $monsters{$ID}{'state'};
				$monsters{$ID}{'state'} = unpack("S*", substr($msg, 8, 2)); 
				$monsters{$ID}{'state'} = 0 if ($monsters{$ID}{'state'} == 5); 
				my $mon = "Monster $monsters{$ID}{name} $monsters{$ID}{nameID} ($monsters{$ID}{binID})"; 
				if (!$monsters{$ID}{'state'}) {
					print "$mon is free.\n" if ($prevState);

				} elsif ($monsters{$ID}{'state'} == 1) {
					print "$mon is stoned.\n";
					$monsters{$ID}{'ignore'} = 1;

				} elsif ($monsters{$ID}{'state'} == 2) {
					print "$mon is frozen.\n";
					$monsters{$ID}{'ignore'} = 1;

				} elsif ($monsters{$ID}{'state'} == 3) {
					print "$mon is stunned.\n";
					$monsters{$ID}{'ignore'} = 1;

				} elsif ($monsters{$ID}{'state'} == 4) {
					print "$mon is asleep.\n";
					$monsters{$ID}{'ignore'} = 1;

				} else {
					print "$mon is disabled.\n";
					$monsters{$ID}{'ignore'} = 1;
				}
			}

		} elsif ($jobs_lut{$type}) {
			if (!%{$players{$ID}}) {
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
			print "Player Exists: $players{$ID}{'name'} ($players{$ID}{'binID'}) $sex_lut{$players{$ID}{'sex'}} $jobs_lut{$players{$ID}{'jobID'}}\n" if ($config{'debug'});

		} elsif ($type == 45) {
			if (!%{$portals{$ID}}) {
				$portals{$ID}{'appear_time'} = time;
				$nameID = unpack("L1", $ID);
				$exists = portalExists($field{'name'}, \%coords);
				$display = ($exists ne "") 
					? "$portals_lut{$exists}{'source'}{'map'} -> $portals_lut{$exists}{'dest'}{'map'}"
					: "Unknown ".$nameID;
				binAdd(\@portalsID, $ID);
				$portals{$ID}{'source'}{'map'} = $field{'name'};
				$portals{$ID}{'type'} = $type;
				$portals{$ID}{'nameID'} = $nameID;
				$portals{$ID}{'name'} = $display;
				$portals{$ID}{'binID'} = binFind(\@portalsID, $ID);
			}
			%{$portals{$ID}{'pos'}} = %coords;
			print "Portal Exists: $portals{$ID}{'name'} - ($portals{$ID}{'binID'})\n";

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
			print "NPC Exists: $npcs{$ID}{'name'} - ($npcs{$ID}{'binID'})\n";

		} else {
			print "Unknown Exists: $type - ".unpack("L*",$ID)."\n" if $config{'debug'};
		}

	} elsif ($switch eq "0079" && length($msg) >= 51) {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		$ID = substr($msg, 2, 4);
		makeCoords(\%coords, substr($msg, 46, 3));
		$type = unpack("S*",substr($msg, 14,  2));
		$sex = unpack("C*",substr($msg, 45,  1));
		if ($jobs_lut{$type}) {
			if (!%{$players{$ID}}) {
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
			print "Player Connected: $players{$ID}{'name'} ($players{$ID}{'binID'}) $sex_lut{$players{$ID}{'sex'}} $jobs_lut{$players{$ID}{'jobID'}}\n" if ($config{'debug'});

		} else {
			print "Unknown Connected: $type - ".getHex($ID)."\n" if $config{'debug'};
		}

	} elsif ($switch eq "007A" && length($msg) >= 4) {
		$conState = 5 if ($conState != 4 && $config{'XKore'});

	} elsif ($switch eq "007B" && length($msg) >= 58) {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		$ID = substr($msg, 2, 4);
		makeCoords(\%coordsFrom, substr($msg, 50, 3));
		makeCoords2(\%coordsTo, substr($msg, 52, 3));
		$type = unpack("S*",substr($msg, 14,  2));
		$pet = unpack("C*",substr($msg, 16,  1));
		$sex = unpack("C*",substr($msg, 49,  1));
		if ($type >= 1000) {
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
					undef %{$monsters{$ID}};
				}
				print "Pet Moved: $pets{$ID}{'name'} ($pets{$ID}{'binID'})\n" if ($config{'debug'});
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
					print "Monster Appeared: $monsters{$ID}{'name'} ($monsters{$ID}{'binID'})\n" if $config{'debug'};
				}
				%{$monsters{$ID}{'pos'}} = %coordsFrom;
				%{$monsters{$ID}{'pos_to'}} = %coordsTo;
				print "Monster Moved: $monsters{$ID}{'name'} ($monsters{$ID}{'binID'})\n" if ($config{'debug'} >= 2);
			}
		} elsif ($jobs_lut{$type}) {
			if (!%{$players{$ID}}) {
				binAdd(\@playersID, $ID);
				$players{$ID}{'appear_time'} = time;
				$players{$ID}{'sex'} = $sex;
				$players{$ID}{'jobID'} = $type;
				$players{$ID}{'name'} = "Unknown";
				$players{$ID}{'nameID'} = unpack("L1", $ID);
				$players{$ID}{'binID'} = binFind(\@playersID, $ID);
				
				print "Player Appeared: $players{$ID}{'name'} ($players{$ID}{'binID'}) $sex_lut{$sex} $jobs_lut{$type}\n" if $config{'debug'};
			}
			%{$players{$ID}{'pos'}} = %coordsFrom;
			%{$players{$ID}{'pos_to'}} = %coordsTo;
			print "Player Moved: $players{$ID}{'name'} ($players{$ID}{'binID'}) $sex_lut{$players{$ID}{'sex'}} $jobs_lut{$players{$ID}{'jobID'}}\n" if ($config{'debug'} >= 2);
		} else {
			print "Unknown Moved: $type - ".getHex($ID)."\n" if $config{'debug'};
		}

	} elsif ($switch eq "007C" && length($msg) >= 41) {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		$ID = substr($msg, 2, 4);
		makeCoords(\%coords, substr($msg, 36, 3));
		$type = unpack("S*",substr($msg, 20,  2));
		$pet = unpack("C*",substr($msg, 22,  1));
		$sex = unpack("C*",substr($msg, 35,  1));
		if ($type >= 1000) {
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
				print "Pet Spawned: $pets{$ID}{'name'} ($pets{$ID}{'binID'})\n" if ($config{'debug'}); 
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
				print "Monster Spawned: $monsters{$ID}{'name'} ($monsters{$ID}{'binID'})\n" if ($config{'debug'}); 
			}
		} elsif ($jobs_lut{$type}) {
			if (!%{$players{$ID}}) {
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
			print "Player Spawned: $players{$ID}{'name'} ($players{$ID}{'binID'}) $sex_lut{$players{$ID}{'sex'}} $jobs_lut{$players{$ID}{'jobID'}}\n" if ($config{'debug'});
		} else {
			print "Unknown Spawned: $type - ".getHex($ID)."\n" if $config{'debug'};
		}
		
	} elsif ($switch eq "007F") {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		$time = unpack("L1",substr($msg, 2, 4));
		print "Recieved Sync\n" if ($config{'debug'} >= 2);
		$timeout{'play'}{'time'} = time;

	} elsif ($switch eq "0080") {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		$ID = substr($msg, 2, 4);
		$type = unpack("C1",substr($msg, 6, 1));

		if ($ID eq $accountID) {
			print "You have died\n";
			sendCloseShop();
			$chars[$config{'char'}]{'dead'} = 1;
			$chars[$config{'char'}]{'dead_time'} = time;
		} elsif (%{$monsters{$ID}}) {
			%{$monsters_old{$ID}} = %{$monsters{$ID}};
			$monsters_old{$ID}{'gone_time'} = time;
			if ($type == 0) {
				print "Monster Disappeared: $monsters{$ID}{'name'} ($monsters{$ID}{'binID'})\n" if $config{'debug'};
				$monsters_old{$ID}{'disappeared'} = 1;

			} elsif ($type == 1) {
				print "Monster Died: $monsters{$ID}{'name'} ($monsters{$ID}{'binID'})\n" if $config{'debug'};
				$monsters_old{$ID}{'dead'} = 1;
			}
			binRemove(\@monstersID, $ID);
			undef %{$monsters{$ID}};

		} elsif (%{$players{$ID}}) {
			if ($type == 1) {
				print "Player Died: $players{$ID}{'name'} ($players{$ID}{'binID'}) $sex_lut{$players{$ID}{'sex'}} $jobs_lut{$players{$ID}{'jobID'}}\n";
				$players{$ID}{'dead'} = 1;
			} else {
				if ($type == 0) {
					print "Player Disappeared: $players{$ID}{'name'} ($players{$ID}{'binID'}) $sex_lut{$players{$ID}{'sex'}} $jobs_lut{$players{$ID}{'jobID'}}\n" if ($config{'debug'});
					$players{$ID}{'disappeared'} = 1;
				} elsif ($type == 2) {
					print "Player Disconnected: $players{$ID}{'name'} ($players{$ID}{'binID'}) $sex_lut{$players{$ID}{'sex'}} $jobs_lut{$players{$ID}{'jobID'}}\n" if ($config{'debug'});
					$players{$ID}{'disconnected'} = 1;
				} elsif ($type == 3) {
					print "Player Teleported: $players{$ID}{'name'} ($players{$ID}{'binID'}) $sex_lut{$players{$ID}{'sex'}} $jobs_lut{$players{$ID}{'jobID'}}\n" if ($config{'debug'});
					$players{$ID}{'teleported'} = 1;
				} else {
					print "Player Disappeared in an unknown way: $players{$ID}{'name'} ($players{$ID}{'binID'}) $sex_lut{$players{$ID}{'sex'}} $jobs_lut{$players{$ID}{'jobID'}}\n" if ($config{'debug'});
					$players{$ID}{'disappeared'} = 1;
				}

				%{$players_old{$ID}} = %{$players{$ID}};
				$players_old{$ID}{'gone_time'} = time;
				binRemove(\@playersID, $ID);
				undef %{$players{$ID}};

				binRemove(\@venderListsID, $ID);
				undef %{$venderLists{$ID}};
			}

		} elsif (%{$players_old{$ID}}) {
			if ($type == 2) {
				print "Player Disconnected: $players_old{$ID}{'name'}\n" if $config{'debug'};
				$players_old{$ID}{'disconnected'} = 1;
			} elsif ($type == 3) {
				print "Player Teleported: $players_old{$ID}{'name'}\n" if $config{'debug'};
				$players_old{$ID}{'teleported'} = 1;
			}
		} elsif (%{$portals{$ID}}) {
			print "Portal Disappeared: $portals{$ID}{'name'} ($portals{$ID}{'binID'})\n" if ($config{'debug'});
			%{$portals_old{$ID}} = %{$portals{$ID}};
			$portals_old{$ID}{'disappeared'} = 1;
			$portals_old{$ID}{'gone_time'} = time;
			binRemove(\@portalsID, $ID);
			undef %{$portals{$ID}};
		} elsif (%{$npcs{$ID}}) {
			print "NPC Disappeared: $npcs{$ID}{'name'} ($npcs{$ID}{'binID'})\n" if ($config{'debug'});
			%{$npcs_old{$ID}} = %{$npcs{$ID}};
			$npcs_old{$ID}{'disappeared'} = 1;
			$npcs_old{$ID}{'gone_time'} = time;
			binRemove(\@npcsID, $ID);
			undef %{$npcs{$ID}};
		} elsif (%{$pets{$ID}}) {
			print "Pet Disappeared: $pets{$ID}{'name'} ($pets{$ID}{'binID'})\n" if ($config{'debug'});
			binRemove(\@petsID, $ID);
			undef %{$pets{$ID}};
		} else {
			print "Unknown Disappeared: ".getHex($ID)."\n" if $config{'debug'};
		}

	} elsif ($switch eq "0081") {
		$type = unpack("C1", substr($msg, 2, 1));
		$conState = 1;
		undef $conState_tries;
		
		$timeout_ex{'master'}{'time'} = time;
		$timeout_ex{'master'}{'timeout'} = $timeout{'reconnect'}{'timeout'};

		if ($type == 2) {
			print "Critical Error: Dual login prohibited - Someone trying to login!\n";
			if ($config{'dcOnDualLogin'} == 1) {
				print "Disconnect immediately!\n";
				$quit = 1;
			} elsif ($config{'dcOnDualLogin'} >= 2) {
				print "Disconnect for $config{'dcOnDualLogin'} seconds...\n";
				$timeout_ex{'master'}{'timeout'} = $config{'dcOnDualLogin'};
			}

		} elsif ($type == 3) {
			print "Error: Out of sync with server\n";
		} elsif ($type == 6) {
			print "Critical Error: You must pay to play this account!\n";
			$quit = 1;
		} elsif ($type == 8) {
			print "Error: The server still recognizes your last connection\n";
		}

	} elsif ($switch eq "0087" && length($msg) >= 12) {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		makeCoords(\%coordsFrom, substr($msg, 6, 3));
		makeCoords2(\%coordsTo, substr($msg, 8, 3));
		%{$chars[$config{'char'}]{'pos'}} = %coordsFrom;
		%{$chars[$config{'char'}]{'pos_to'}} = %coordsTo;
		print "You move to: $coordsTo{'x'}, $coordsTo{'y'}\n" if $config{'debug'};
		$chars[$config{'char'}]{'time_move'} = time;
		$chars[$config{'char'}]{'time_move_calc'} = distance(\%{$chars[$config{'char'}]{'pos'}}, \%{$chars[$config{'char'}]{'pos_to'}}) * $config{'seconds_per_block'};

	} elsif ($switch eq "0088") {
		undef $level_real;
# Long distance attack solution
		$ID = substr($msg, 2, 4);
		undef %coords;
		$coords{'x'} = unpack("S1", substr($msg, 6, 2));
		$coords{'y'} = unpack("S1", substr($msg, 8, 2));
		if ($ID eq $accountID) {
			%{$chars[$config{'char'}]{'pos'}} = %coords;
			%{$chars[$config{'char'}]{'pos_to'}} = %coords;
			print "Movement interrupted, your coordinates: $chars[$config{'char'}]{'pos'}{'x'}, $chars[$config{'char'}]{'pos'}{'y'}\n" if $config{'debug'};
			aiRemove("move");
		} elsif (%{$monsters{$ID}}) {
			%{$monsters{$ID}{'pos'}} = %coords;
			%{$monsters{$ID}{'pos_to'}} = %coords;
		} elsif (%{$players{$ID}}) {
			%{$players{$ID}{'pos'}} = %coords;
			%{$players{$ID}{'pos_to'}} = %coords;
		}
# End of Long Distance attack Solution

	} elsif ($switch eq "0089") {

	} elsif ($switch eq "008A") {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		$ID1 = substr($msg, 2, 4);
		$ID2 = substr($msg, 6, 4);
		$standing = unpack("C1", substr($msg, 26, 2)) - 2;
		$damage = unpack("S1", substr($msg, 22, 2));
		if ($damage == 0) {
			$dmgdisplay = "Miss!";
		} else {
			$dmgdisplay = $damage;
		}
		updateDamageTables($ID1, $ID2, $damage);
		if ($ID1 eq $accountID) {
			if (%{$monsters{$ID2}}) { 
#Solos Start
				print  "[".$chars[$config{'char'}]{'hp'}."/".$chars[$config{'char'}]{'hp_max'}." ("
				.int($chars[$config{'char'}]{'hp'}/$chars[$config{'char'}]{'hp_max'} * 100)
				."%)] "."You attack Monster: $monsters{$ID2}{'name'} $monsters{$ID2}{'nameID'} ($monsters{$ID2}{'binID'}) - Dmg: $dmgdisplay\n";

				if ($startedattack == 1)
				{
				$monstarttime = time();
				$monkilltime = time();
				$startedattack = 0;
				}
				calcStat($damage);
#Solos End
			} elsif (%{$items{$ID2}}) {
				print "You pick up Item: $items{$ID2}{'name'} ($items{$ID2}{'binID'})\n" if $config{'debug'};
				$items{$ID2}{'takenBy'} = $accountID;
			} elsif ($ID2 == 0) {
				if ($standing) {
					$chars[$config{'char'}]{'sitting'} = 0;
					print "You're Standing\n";
				} else {
					$chars[$config{'char'}]{'sitting'} = 1;
					print "You're Sitting\n";
				}
			}
		} elsif ($ID2 eq $accountID) {
			if (%{$monsters{$ID1}}) {
				useTeleport(1) if ($monsters{$ID1}{'name'} eq "");

				print  "[".$chars[$config{'char'}]{'hp'}."/".$chars[$config{'char'}]{'hp_max'}." ("
				.int($chars[$config{'char'}]{'hp'}/$chars[$config{'char'}]{'hp_max'} * 100)
				."%)] "."Monster $monsters{$ID1}{'name'} $monsters{$ID1}{'nameID'} ($monsters{$ID1}{'binID'}) attacks You: - Dmg: $dmgdisplay\n";

				#junq start
				if ($config{'teleportAuto_maxDmg'} > 0) {
               				if ($dmgdisplay > $config{'teleportAuto_maxDmg'}) {
                  				print "Monster hits you for more than $config{'teleportAuto_maxDmg'} dmg. Teleporting\n";
                  				useTeleport(1);
               				} 
            			}
            			if ($config{'teleportAuto_deadly'}) {
               				if ($damage > $chars[$config{'char'}]{'hp'}) {
                  				print "Next hit of $damage dmg could kill you. Teleporting\n";
                  				useTeleport(1);
               				}
            			}
				#junq end
			}
			undef $chars[$config{'char'}]{'time_cast'};
		} elsif (%{$monsters{$ID1}}) {
			if (%{$players{$ID2}}) {
				print "Monster $monsters{$ID1}{'name'} ($monsters{$ID1}{'binID'}) attacks Player $players{$ID2}{'name'} ($players{$ID2}{'binID'}) - Dmg: $dmgdisplay\n" if ($config{'debug'});
			}
			
		} elsif (%{$players{$ID1}}) {
			if (%{$monsters{$ID2}}) {
				print "Player $players{$ID1}{'name'} ($players{$ID1}{'binID'}) attacks Monster $monsters{$ID2}{'name'} ($monsters{$ID2}{'binID'}) - Dmg: $dmgdisplay\n" if ($config{'debug'});
			} elsif (%{$items{$ID2}}) {
				$items{$ID2}{'takenBy'} = $ID1;
				print "Player $players{$ID1}{'name'} ($players{$ID1}{'binID'}) picks up Item $items{$ID2}{'name'} ($items{$ID2}{'binID'})\n" if ($config{'debug'});
			} elsif ($ID2 == 0) {
				if ($standing) {
					$players{$ID1}{'sitting'} = 0;
					print "Player is Standing: $players{$ID1}{'name'} ($players{$ID1}{'binID'})\n" if $config{'debug'};
				} else {
					$players{$ID1}{'sitting'} = 1;
					print "Player is Sitting: $players{$ID1}{'name'} ($players{$ID1}{'binID'})\n" if $config{'debug'};
				}
			}
		} else {
			print "Unknown ".getHex($ID1)." attacks ".getHex($ID2)." - Dmg: $dmgdisplay\n" if $config{'debug'};
		}

	} elsif ($switch eq "008D" && length($msg) >= unpack("S1", substr($msg, 2, 2))) {
		$msg_size = unpack("S*", substr($msg, 2, 2));
		$ID = substr($msg, 4, 4);
		$chat = substr($msg, 8, $msg_size - 8);
		$chat =~ s/\000//g;
		($chatMsgUser, $chatMsg) = $chat =~ /([\s\S]*?) : ([\s\S]*)/;
		$chatMsgUser =~ s/ $//;

		chatLog("c", "$chat\n") if ($config{'logChat'});
		if ($config{'relay'}) {
			sendMessage(\$remote_socket, "pm", $chat, $config{'relay_user'});
		}

		$ai_cmdQue[$ai_cmdQue]{'type'} = "c";
		$ai_cmdQue[$ai_cmdQue]{'ID'} = $ID;
		$ai_cmdQue[$ai_cmdQue]{'user'} = $chatMsgUser;
		$ai_cmdQue[$ai_cmdQue]{'msg'} = $chatMsg;
		$ai_cmdQue[$ai_cmdQue]{'time'} = time;
		$ai_cmdQue++;
		print "$chat\n";
#Solos Start

#auto-emote
		$i = 0;
		while ($config{"autoEmote_word_$i"} ne "") {
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
#auto-response
		if ($config{"autoResponse"}) {
			$i = 0;
			while ($chat_resp{"words_said_$i"} ne "") {
				if (($chat =~/.*$chat_resp{"words_said_$i"}+$/i || $chat =~ /.*$chat_resp{"words_said_$i"}+\W/i) &&
				    binFind(\@ai_seq, "respAuto") eq "") {
					$args{'resp_num'} = $i;
					unshift @ai_seq, "respAuto";			
					unshift @ai_seq_args, \%args;
					$nextresptime = time + 5;
					last;
				}
				$i++;
			}
		}

		avoidGM_talk($chatMsgUser, $chatMsg);
		avoidList_talk($chatMsgUser, $chatMsg);
#Solos End

	} elsif ($switch eq "008E") {
		$msg_size = unpack("S*", substr($msg, 2, 2));
		$chat = substr($msg, 4, $msg_size - 4);
		$chat =~ s/\000//g;
		($chatMsgUser, $chatMsg) = $chat =~ /([\s\S]*?) : ([\s\S]*)/;
		chatLog("c", $chat."\n") if ($config{'logChat'});
		if ($config{'relay'}) {
			sendMessage(\$remote_socket, "pm", $chat, $config{'relay_user'});
		}
		$ai_cmdQue[$ai_cmdQue]{'type'} = "c";
		$ai_cmdQue[$ai_cmdQue]{'user'} = $chatMsgUser;
		$ai_cmdQue[$ai_cmdQue]{'msg'} = $chatMsg;
		$ai_cmdQue[$ai_cmdQue]{'time'} = time;
		$ai_cmdQue++;
		print "$chat\n";
#Solos Start
# this is self talk portion
#Solos End
	} elsif ($switch eq "008F") {

	} elsif ($switch eq "0091") {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		initMapChangeVars();
		for ($i = 0; $i < @ai_seq; $i++) {
			ai_setMapChanged($i);
		}
		($map_name) = substr($msg, 2, 16) =~ /([\s\S]*?)\000/;
		($ai_v{'temp'}{'map'}) = $map_name =~ /([\s\S]*)\./;
		if ($ai_v{'temp'}{'map'} ne $field{'name'}) {
			getField("fields/$ai_v{'temp'}{'map'}.fld", \%field);
		}
		$coords{'x'} = unpack("S1", substr($msg, 18, 2));
		$coords{'y'} = unpack("S1", substr($msg, 20, 2));
		%{$chars[$config{'char'}]{'pos'}} = %coords;
		%{$chars[$config{'char'}]{'pos_to'}} = %coords;
		print "Map Change: $map_name\n";
		print "Your Coordinates: $chars[$config{'char'}]{'pos'}{'x'}, $chars[$config{'char'}]{'pos'}{'y'}\n" if $config{'debug'};
		print "Sending Map Loaded\n" if ($config{'debug'} && !$config{'XKore'});
		sendMapLoaded(\$remote_socket) if (!$config{'XKore'});

	} elsif ($switch eq "0092") {
		$conState = 4;
		initMapChangeVars() if ($config{'XKore'});
		undef $conState_tries;
		for (my $i = 0; $i < @ai_seq; $i++) {
			ai_setMapChanged($i);
		}
		($map_name) = substr($msg, 2, 16) =~ /([\s\S]*?)\000/;
		($ai_v{'temp'}{'map'}) = $map_name =~ /([\s\S]*)\./;
		if ($ai_v{'temp'}{'map'} ne $field{'name'}) {
			getField("fields/$ai_v{'temp'}{'map'}.fld", \%field);
		}
		$map_ip = makeIP(substr($msg, 22, 4));
		$map_port = unpack("S1", substr($msg, 26, 2));
		format MAPINFO =
---------Map Change Info----------
MAP Name: @<<<<<<<<<<<<<<<<<<
            $map_name
MAP IP: @<<<<<<<<<<<<<<<<<<
            $map_ip
MAP Port: @<<<<<<<<<<<<<<<<<<
	$map_port
-------------------------------
.
		$~ = "MAPINFO";
		write;
		print "Closing connection to Map Server\n";
		killConnection(\$remote_socket) if (!$config{'XKore'});

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

	} elsif ($switch eq "0093") {

	} elsif ($switch eq "0095") {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		$ID = substr($msg, 2, 4);
		if (%{$players{$ID}}) {
			($players{$ID}{'name'}) = substr($msg, 6, 24) =~ /([\s\S]*?)\000/;
			if ($config{'debug'} >= 2) {
				$binID = binFind(\@playersID, $ID);
				print "Player Info: $players{$ID}{'name'} ($binID)\n";
			}
		}
		if (%{$monsters{$ID}}) {
			($monsters{$ID}{'name'}) = substr($msg, 6, 24) =~ /([\s\S]*?)\000/;
			if ($config{'debug'} >= 2) {
				$binID = binFind(\@monstersID, $ID);
				print "Monster Info: $monsters{$ID}{'name'} ($binID)\n";
			}
			if ($monsters_lut{$monsters{$ID}{'nameID'}} eq "") {
				$monsters_lut{$monsters{$ID}{'nameID'}} = $monsters{$ID}{'name'};
				updateMonsterLUT("tables/monsters.txt", $monsters{$ID}{'nameID'}, $monsters{$ID}{'name'});
			}
		}
		if (%{$npcs{$ID}}) {
			($npcs{$ID}{'name'}) = substr($msg, 6, 24) =~ /([\s\S]*?)\000/; 
			if ($config{'debug'} >= 2) { 
				$binID = binFind(\@npcsID, $ID); 
				print "NPC Info: $npcs{$ID}{'name'} ($binID)\n"; 
			} 
			if (!%{$npcs_lut{$npcs{$ID}{'nameID'}}}) { 
				$npcs_lut{$npcs{$ID}{'nameID'}}{'name'} = $npcs{$ID}{'name'};
				$npcs_lut{$npcs{$ID}{'nameID'}}{'map'} = $field{'name'};
				%{$npcs_lut{$npcs{$ID}{'nameID'}}{'pos'}} = %{$npcs{$ID}{'pos'}};
				updateNPCLUT("tables/npcs.txt", $npcs{$ID}{'nameID'}, $field{'name'}, $npcs{$ID}{'pos'}{'x'}, $npcs{$ID}{'pos'}{'y'}, $npcs{$ID}{'name'}); 
			}
		}
		if (%{$pets{$ID}}) {
			($pets{$ID}{'name_given'}) = substr($msg, 6, 24) =~ /([\s\S]*?)\000/;
			if ($config{'debug'} >= 2) {
				$binID = binFind(\@petsID, $ID);
				print "Pet Info: $pets{$ID}{'name_given'} ($binID)\n";
			}
		}

	} elsif ($switch eq "0096") {

	} elsif ($switch eq "0097" && length($msg) >= unpack("S1", substr($msg, 2, 2))) {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		$msg_size = unpack("S1",substr($msg,2,2));
		decrypt(\$newmsg, substr($msg, 28, length($msg)-28));
		$msg = substr($msg, 0, 28).$newmsg;
		($privMsgUser) = substr($msg, 4, 24) =~ /([\s\S]*?)\000/;
		$privMsg = substr($msg, 28, $msg_size - 29);
		if ($privMsgUser ne "" && binFind(\@privMsgUsers, $privMsgUser) eq "") {
			$privMsgUsers[@privMsgUsers] = $privMsgUser;
		}

		chatLog("pm", "(From: $privMsgUser) : $privMsg\n") if ($config{'logPrivateChat'});
		if ($config{'relay'}) {
			sendMessage(\$remote_socket, "pm", "(From: $privMsgUser) : $privMsg", $config{'relay_user'});
		}

		$ai_cmdQue[$ai_cmdQue]{'type'} = "pm";
		$ai_cmdQue[$ai_cmdQue]{'user'} = $privMsgUser;
		$ai_cmdQue[$ai_cmdQue]{'msg'} = $privMsg;
		$ai_cmdQue[$ai_cmdQue]{'time'} = time;
		$ai_cmdQue++;
		print "(From: $privMsgUser) : $privMsg\n";

		avoidGM_talk($privMsgUser, $privMsg);
		avoidList_talk($privMsgUser, $privMsg);

		# auto-response
		if ($config{"autoResponse"}) {
			$i = 0;
			while ($chat_resp{"words_said_$i"} ne "") {
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
		}

	} elsif ($switch eq "0098") {
		$type = unpack("C1",substr($msg, 2, 1));
		if ($type == 0) {
			print "(To $lastpm[0]{'user'}) : $lastpm[0]{'msg'}\n";
			chatLog("pm", "(To: $lastpm[0]{'user'}) : $lastpm[0]{'msg'}\n") if ($config{'logPrivateChat'});
		} elsif ($type == 1) {
			print "$lastpm[0]{'user'} is not online\n";
		} elsif ($type == 2) {
			print "Player can't hear you - you are ignored\n";
		}
		shift @lastpm;

	} elsif ($switch eq "009A" && length($msg) >= unpack("S1", substr($msg, 2, 2))) {
		$msg_size = unpack("S1", substr($msg, 2, 2));
		$chat = substr($msg, 4, $msg_size - 4);
		$chat =~ s/\000$//;
		chatLog("s", $chat."\n") if ($config{'logChat'});
		print "$chat\n";
		avoidGM_talk(undef, $chat);

	} elsif ($switch eq "009C") {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		$ID = substr($msg, 2, 4);
		$body = unpack("C1",substr($msg, 8, 1));
		$head = unpack("C1",substr($msg, 6, 1));
		if ($ID eq $accountID) {
			$chars[$config{'char'}]{'look'}{'head'} = $head;
			$chars[$config{'char'}]{'look'}{'body'} = $body;
			print "You look at $chars[$config{'char'}]{'look'}{'body'}, $chars[$config{'char'}]{'look'}{'head'}\n" if ($config{'debug'} >= 2);

		} elsif (%{$players{$ID}}) {
			$players{$ID}{'look'}{'head'} = $head;
			$players{$ID}{'look'}{'body'} = $body;
			print "Player $players{$ID}{'name'} ($players{$ID}{'binID'}) looks at $players{$ID}{'look'}{'body'}, $players{$ID}{'look'}{'head'}\n" if ($config{'debug'} >= 2);

		} elsif (%{$monsters{$ID}}) {
			$monsters{$ID}{'look'}{'head'} = $head;
			$monsters{$ID}{'look'}{'body'} = $body;
			print "Monster $monsters{$ID}{'name'} ($monsters{$ID}{'binID'}) looks at $monsters{$ID}{'look'}{'body'}, $monsters{$ID}{'look'}{'head'}\n" if ($config{'debug'} >= 2);
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
			$display = ($items_lut{$items{$ID}{'nameID'}} ne "") 
				? $items_lut{$items{$ID}{'nameID'}}
				: "Unknown ".$items{$ID}{'nameID'};
			$items{$ID}{'binID'} = binFind(\@itemsID, $ID);
			$items{$ID}{'name'} = $display;
		}
		$items{$ID}{'pos'}{'x'} = $x;
		$items{$ID}{'pos'}{'y'} = $y;
		print "Item Exists: $items{$ID}{'name'} ($items{$ID}{'binID'}) x $items{$ID}{'amount'}\n";

	} elsif ($switch eq "009E" && length($msg) >= 17) {
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
			$display = ($items_lut{$items{$ID}{'nameID'}} ne "") 
				? $items_lut{$items{$ID}{'nameID'}}
				: "Unknown ".$items{$ID}{'nameID'};
			$items{$ID}{'binID'} = binFind(\@itemsID, $ID);
			$items{$ID}{'name'} = $display;
		}
		$items{$ID}{'pos'}{'x'} = $x;
		$items{$ID}{'pos'}{'y'} = $y;
		print "Item Appeared: $items{$ID}{'name'} ($items{$ID}{'binID'}) x $items{$ID}{'amount'}\n";

	} elsif ($switch eq "00A0" && length($msg) >= 23) {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		$index = unpack("S1",substr($msg, 2, 2));
		$amount = unpack("S1",substr($msg, 4, 2));
		$ID = unpack("S1",substr($msg, 6, 2));
		$type = unpack("C1",substr($msg, 21, 1));
		$type_equip = unpack("C1",substr($msg, 19, 1));
		makeCoords(\%test, substr($msg, 8, 3));
		$fail = unpack("C1",substr($msg, 22, 1));
		undef $invIndex;
#Solos Start
#Search with index, not name! Otherwise non-stackable item will screw it up!
#		$invIndex = findIndex(\@{$chars[$config{'char'}]{'inventory'}}, "nameID", $ID);
		$invIndex = findIndex(\@{$chars[$config{'char'}]{'inventory'}}, "index", $index);
#Solos End
		if ($fail == 0) {
			if ($invIndex eq "" || $itemSlots_lut{$ID} != 0) {
				$invIndex = findIndex(\@{$chars[$config{'char'}]{'inventory'}}, "nameID", "");
				$chars[$config{'char'}]{'inventory'}[$invIndex]{'index'} = $index;
				$chars[$config{'char'}]{'inventory'}[$invIndex]{'nameID'} = $ID;
				$chars[$config{'char'}]{'inventory'}[$invIndex]{'amount'} = $amount;
				$chars[$config{'char'}]{'inventory'}[$invIndex]{'type'} = $type;
				$chars[$config{'char'}]{'inventory'}[$invIndex]{'type_equip'} = $itemSlots_lut{$ID};
				$chars[$config{'char'}]{'inventory'}[$invIndex]{'identified'} = unpack("C1",substr($msg, 8, 1));
#Solos Start
				$chars[$config{'char'}]{'inventory'}[$invIndex]{'enchant'} = unpack("C1",substr($msg, 10, 1)); 
            	$chars[$config{'char'}]{'inventory'}[$invIndex]{'elementID'} = unpack("S1",substr($msg, 12, 2)); 
            	$chars[$config{'char'}]{'inventory'}[$invIndex]{'elementName'} = $elements_lut{$chars[$config{'char'}]{'inventory'}[$invIndex]{'elementID'}}; 
            	undef @cnt; 
            	$count = 0; 
            	for($j=1 ;$j < 5;$j++) { 
               		if(unpack("S1", substr($msg, 9 + $j + $j, 2)) > 0) { 
	                  	$chars[$config{'char'}]{'inventory'}[$invIndex]{'slotID_$j'} = unpack("S1", substr($msg, 9 + $j + $j, 2)); 
    	              	for($k = 0;$k < 4;$k++) { 
        	             	if(($chars[$config{'char'}]{'inventory'}[$invIndex]{'slotID_$j'} eq $cnt[$k]{'ID'}) && ($chars[$config{'char'}]{'inventory'}[$invIndex]{'slotID_$j'} ne "")) { 
            	            	$cnt[$k]{'amount'} += 1;                         
                	        	last; 
                    		} elsif ($chars[$config{'char'}]{'inventory'}[$invIndex]{'slotID_$j'} ne "") { 
	                        	$cnt[$k]{'amount'} = 1; 
    	                    	$cnt[$k]{'name'} = $cards_lut{$chars[$config{'char'}]{'inventory'}[$invIndex]{'slotID_$j'}}; 
        	                	$cnt[$k]{'ID'} = $chars[$config{'char'}]{'inventory'}[$invIndex]{'slotID_$j'}; 
            	            	$count++; 
                	        	last;                         
                    	 	} 
                  		} 
               		} 
            	} 
            	$display = ""; 
            	$count ++; 
            	for($j = 0;$j < $count;$j++) { 
               		if($j == 0 && $cnt[$j]{'amount'}) { 
                  		if($cnt[$j]{'amount'} > 1) { 
                     		$display .= "$cnt[$j]{'amount'}X$cnt[$j]{'name'}"; 
                  		} else { 
                     		$display .= "$cnt[$j]{'name'}"; 
                  		} 
               		} elsif ($cnt[$j]{'amount'}) { 
                  		if($cnt[$j]{'amount'} > 1) { 
                     		$display .= ",$cnt[$j]{'amount'}X$cnt[$j]{'name'}"; 
                  	} else { 
                     	$display .= ",$cnt[$j]{'name'}"; 
                  	} 
               	} 
            } 
            $chars[$config{'char'}]{'inventory'}[$invIndex]{'slotName'} = $display; 
            undef @cnt; 
            undef $count; 
#Solos End
			} else {
				$chars[$config{'char'}]{'inventory'}[$invIndex]{'amount'} += $amount;
			}
			$display = ($items_lut{$chars[$config{'char'}]{'inventory'}[$invIndex]{'nameID'}} ne "")
				? $items_lut{$chars[$config{'char'}]{'inventory'}[$invIndex]{'nameID'}}
				: "Unknown ".$chars[$config{'char'}]{'inventory'}[$invIndex]{'nameID'};
			$chars[$config{'char'}]{'inventory'}[$invIndex]{'name'} = $display;
#Solos Start
#			print "Item added to inventory: $display ($invIndex) x $amount - $itemTypes_lut{$chars[$config{'char'}]{'inventory'}[$invIndex]{'type'}}\n";
			$disp = "Item added to inventory: $display"; 
         	if($chars[$config{'char'}]{'inventory'}[$invIndex]{'enchant'} > 0) { 
	            $disp = "+$chars[$config{'char'}]{'inventory'}[$invIndex]{'enchant'} ".$disp; 
    	     } 
        	 if($chars[$config{'char'}]{'inventory'}[$invIndex]{'elementName'} ne "") { 
            	$disp .= " [$chars[$config{'char'}]{'inventory'}[$invIndex]{'elementName'}]"; 
         	} 
         	if($chars[$config{'char'}]{'inventory'}[$invIndex]{'slotName'} ne "") { 
            	$disp .= " [$chars[$config{'char'}]{'inventory'}[$invIndex]{'slotName'}]"; 
         	} 
         	$disp .= " ($invIndex) x $amount - $itemTypes_lut{$chars[$config{'char'}]{'inventory'}[$invIndex]{'type'}}"; #junq modded 
            	print "$disp\n"; #junq modded 
#Solos End
#junq start 
		($map_string) = $map_name =~ /([\s\S]*)\.gat/; 
		$disp .= " ($map_string)\n"; 
# junq end
#xlr82xs start
		itemLog($disp);
#xlr82xs end
		} elsif ($fail == 6) {
			print "Can't loot item...wait...\n";
		}

	} elsif ($switch eq "00A1") {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		$ID = substr($msg, 2, 4);
		if (%{$items{$ID}}) {
			print "Item Disappeared: $items{$ID}{'name'} ($items{$ID}{'binID'})\n" if $config{'debug'};
			%{$items_old{$ID}} = %{$items{$ID}};
			$items_old{$ID}{'disappeared'} = 1;
			$items_old{$ID}{'gone_time'} = time;
			undef %{$items{$ID}};
			binRemove(\@itemsID, $ID);
		}

	} elsif ($switch eq "00A3") {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		$msg_size = unpack("S1", substr($msg, 2, 2));
		decrypt(\$newmsg, substr($msg, 4, length($msg)-4));
		$msg = substr($msg, 0, 4).$newmsg;
		undef $invIndex;
		for($i = 4; $i < $msg_size; $i+=10) {
			$index = unpack("S1", substr($msg, $i, 2));
			$ID = unpack("S1", substr($msg, $i + 2, 2));
			$invIndex = findIndex(\@{$chars[$config{'char'}]{'inventory'}}, "index", $index);
			if ($invIndex eq "") {
				$invIndex = findIndex(\@{$chars[$config{'char'}]{'inventory'}}, "nameID", "");
#Solos Start
			}
#Solos End
				$chars[$config{'char'}]{'inventory'}[$invIndex]{'index'} = $index;
				$chars[$config{'char'}]{'inventory'}[$invIndex]{'nameID'} = $ID;
				$chars[$config{'char'}]{'inventory'}[$invIndex]{'amount'} = unpack("S1", substr($msg, $i + 6, 2));
				$chars[$config{'char'}]{'inventory'}[$invIndex]{'type'} = unpack("C1", substr($msg, $i + 4, 1));
				$display = ($items_lut{$chars[$config{'char'}]{'inventory'}[$invIndex]{'nameID'}} ne "")
					? $items_lut{$chars[$config{'char'}]{'inventory'}[$invIndex]{'nameID'}}
					: "Unknown ".$chars[$config{'char'}]{'inventory'}[$invIndex]{'nameID'};
				$chars[$config{'char'}]{'inventory'}[$invIndex]{'name'} = $display;
				print "Inventory: $chars[$config{'char'}]{'inventory'}[$invIndex]{'name'} ($invIndex) x $chars[$config{'char'}]{'inventory'}[$invIndex]{'amount'} - $itemTypes_lut{$chars[$config{'char'}]{'inventory'}[$invIndex]{'type'}}\n" if $config{'debug'};
#Solos Start
#			} 
#Solos End
		}

	} elsif ($switch eq "00A4") {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		$msg_size = unpack("S1", substr($msg, 2, 2));
		decrypt(\$newmsg, substr($msg, 4, length($msg)-4));
		$msg = substr($msg, 0, 4).$newmsg;
		undef $invIndex;
		for($i = 4; $i < $msg_size; $i+=20) {
			$index = unpack("S1", substr($msg, $i, 2));
			$ID = unpack("S1", substr($msg, $i + 2, 2));
			$invIndex = findIndex(\@{$chars[$config{'char'}]{'inventory'}}, "index", $index);
			if ($invIndex eq "") {
				$invIndex = findIndex(\@{$chars[$config{'char'}]{'inventory'}}, "nameID", "");
#Solos Start
			}
#Solos End
				$chars[$config{'char'}]{'inventory'}[$invIndex]{'index'} = $index;
				$chars[$config{'char'}]{'inventory'}[$invIndex]{'nameID'} = $ID;
				$chars[$config{'char'}]{'inventory'}[$invIndex]{'amount'} = 1;
				$chars[$config{'char'}]{'inventory'}[$invIndex]{'type'} = unpack("C1", substr($msg, $i + 4, 1));
				$chars[$config{'char'}]{'inventory'}[$invIndex]{'identified'} = unpack("C1", substr($msg, $i + 5, 1));
				$chars[$config{'char'}]{'inventory'}[$invIndex]{'type_equip'} = $itemSlots_lut{$ID};
				$chars[$config{'char'}]{'inventory'}[$invIndex]{'equipped'} = unpack("C1", substr($msg, $i + 8, 1));
#Solos Start
				$chars[$config{'char'}]{'inventory'}[$invIndex]{'enchant'} = unpack("C1", substr($msg, $i + 11, 1)); 
#Solos End
				if (unpack("C1", substr($msg, $i + 9, 1)) > 0) {
					$chars[$config{'char'}]{'inventory'}[$invIndex]{'equipped'} = unpack("C1", substr($msg, $i + 9, 1));
				}
				$display = ($items_lut{$chars[$config{'char'}]{'inventory'}[$invIndex]{'nameID'}} ne "")
					? $items_lut{$chars[$config{'char'}]{'inventory'}[$invIndex]{'nameID'}}
					: "Unknown ".$chars[$config{'char'}]{'inventory'}[$invIndex]{'nameID'};
				$chars[$config{'char'}]{'inventory'}[$invIndex]{'name'} = $display;
#Solos Start
#				print "Inventory: $chars[$config{'char'}]{'inventory'}[$invIndex]{'name'} ($invIndex) x $chars[$config{'char'}]{'inventory'}[$invIndex]{'amount'} - $itemTypes_lut{$chars[$config{'char'}]{'inventory'}[$invIndex]{'type'}} - $equipTypes_lut{$chars[$config{'char'}]{'inventory'}[$invIndex]{'type_equip'}}\n" if $config{'debug'};
			undef @cnt; 
            $count = 0; 
            for($j=1 ;$j < 5;$j++) { 
            	if(unpack("S1", substr($msg, $i + 10 + $j + $j, 2)) > 0) { 
                	$chars[$config{'char'}]{'inventory'}[$invIndex]{'slotID_$j'} = unpack("S1", substr($msg, $i + 10 + $j + $j, 2)); 
                  	for($k = 0;$k < 4;$k++) { 
                    	if(($chars[$config{'char'}]{'inventory'}[$invIndex]{'slotID_$j'} eq $cnt[$k]{'ID'}) && ($chars[$config{'char'}]{'inventory'}[$invIndex]{'slotID_$j'} ne "")) { 
                        	$cnt[$k]{'amount'} += 1;                         
                        	last; 
                     	} elsif ($chars[$config{'char'}]{'inventory'}[$invIndex]{'slotID_$j'} ne "") { 
	                        $cnt[$k]{'amount'} = 1; 
    	                    $cnt[$k]{'name'} = $cards_lut{$chars[$config{'char'}]{'inventory'}[$invIndex]{'slotID_$j'}}; 
        	                $cnt[$k]{'ID'} = $chars[$config{'char'}]{'inventory'}[$invIndex]{'slotID_$j'}; 
            	            $count++; 
                	        last;                         
                    	} 
                  	} 
               	} 
            } 
            $display = ""; 
            $count ++; 
            for($j = 0;$j < $count;$j++) { 
            	if($j == 0 && $cnt[$j]{'amount'}) { 
                	if($cnt[$j]{'amount'} > 1) { 
                    	$display .= "$cnt[$j]{'amount'}X$cnt[$j]{'name'}"; 
                  	} else { 
                    	$display .= "$cnt[$j]{'name'}"; 
                  	} 
               	} elsif ($cnt[$j]{'amount'}) { 
                  	if($cnt[$j]{'amount'} > 1) { 
                    	$display .= ",$cnt[$j]{'amount'}X$cnt[$j]{'name'}"; 
                  	} else { 
                     	$display .= ",$cnt[$j]{'name'}"; 
                  	} 
               	} 
            } 
            $chars[$config{'char'}]{'inventory'}[$invIndex]{'slotName'} = $display; 
            undef @cnt; 
            undef $count; 
            $chars[$config{'char'}]{'inventory'}[$invIndex]{'elementID'} = unpack("S1",substr($msg, $i + 13, 2)); 
            $chars[$config{'char'}]{'inventory'}[$invIndex]{'elementName'} = $elements_lut{$chars[$config{'char'}]{'inventory'}[$invIndex]{'elementID'}}; 

			$display = $chars[$config{'char'}]{'inventory'}[$invIndex]{'name'};
			if($chars[$config{'char'}]{'inventory'}[$invIndex]{'enchant'} > 0) { 
             	$display = "+$chars[$config{'char'}]{'inventory'}[$invIndex]{'enchant'} ".$display; 
   	       	} 
			if($chars[$config{'char'}]{'inventory'}[$invIndex]{'elementName'}) { 
            	$display .= " [$chars[$config{'char'}]{'inventory'}[$invIndex]{'elementName'}]" 
			}                
            if($chars[$config{'char'}]{'inventory'}[$invIndex]{'slotName'} ne "") { 
            	$display .= " [$chars[$config{'char'}]{'inventory'}[$invIndex]{'slotName'}]" 
			} 
			$chars[$config{'char'}]{'inventory'}[$invIndex]{'name'} = $display;

            print "Inventory: +$chars[$config{'char'}]{'inventory'}[$invIndex]{'enchant'} $chars[$config{'char'}]{'inventory'}[$invIndex]{'name'} [$chars[$config{'char'}]{'inventory'}[$invIndex]{'slotName'}] [$chars[$config{'char'}]{'inventory'}[$invIndex]{'elementName'}] ($invIndex) x $chars[$config{'char'}]{'inventory'}[$invIndex]{'amount'} - $itemTypes_lut{$chars[$config{'char'}]{'inventory'}[$invIndex]{'type'}} - $equipTypes_lut{$chars[$config{'char'}]{'inventory'}[$invIndex]{'type_equip'}}\n" if $config{'debug'};
#			} 
#Solos End
		}

	} elsif ($switch eq "00A5") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
		decrypt(\$newmsg, substr($msg, 4, length($msg)-4));
		$msg = substr($msg, 0, 4).$newmsg;
		undef %storage;
		undef @storageID;
		for($i = 4; $i < $msg_size; $i+=10) {
			$index = unpack("C1", substr($msg, $i, 1));
			$ID = unpack("S1", substr($msg, $i + 2, 2));
			binAdd(\@storageID, $ID);
			$storage{$ID}{'index'} = $index;
			$storage{$ID}{'nameID'} = $ID;
			$storage{$ID}{'amount'} = unpack("L1", substr($msg, $i + 6, 4));
			$display = ($items_lut{$ID} ne "")
				? $items_lut{$ID}
				: "Unknown ".$ID;
			$storage{$ID}{'name'} = $display;
			$storage{$ID}{'binID'} = binFind(\@storageID, $ID);
			print "Storage: $storage{$ID}{'name'} ($storage{$ID}{'binID'})\n" if $config{'debug'};
		}
		print "Storage opened\n";
#Solos Start
	} elsif ($switch eq "00A6") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
		decrypt(\$newmsg, substr($msg, 4, length($msg)-4));
		$msg = substr($msg, 0, 4).$newmsg;
#		undef %storage;
#		undef @storageID;
		for($i = 4; $i < $msg_size; $i+=20) {
			$index = unpack("C1", substr($msg, $i, 1));
			$ID = unpack("S1", substr($msg, $i + 2, 2));
			binAdd(\@storageID, $index);
			$storage{$index}{'index'} = $index;
			$storage{$index}{'nameID'} = $ID;
#			$storage{$index}{'amount'} = unpack("L1", substr($msg, $i + 6, 4));
			$storage{$index}{'amount'} = 1;
			$storage{$index}{'enchant'} = unpack("C1", substr($msg, $i + 11, 1));
           	undef @cnt; 
           	$count = 0; 
           	for($j=1 ;$j < 5;$j++) { 
           		if(unpack("S1", substr($msg, $i + $j + $j + 10, 2)) > 0) { 
	            	$storage{$index}{'slotID_$j'} = unpack("S1", substr($msg, $i + $j + $j + 10, 2)); 
    	            for($k = 0;$k < 4;$k++) { 
        	           	if(($storage{$index}{'slotID_$j'} eq $cnt[$k]{'ID'}) && ($storage{$index}{'slotID_$j'} ne "")) { 
            	           	$cnt[$k]{'amount'} += 1;                         
                	       	last; 
                    	} elsif ($storage{$index}{'slotID_$j'} ne "") { 
	                        $cnt[$k]{'amount'} = 1; 
    	                    $cnt[$k]{'name'} = $cards_lut{$storage{$index}{'slotID_$j'}}; 
        	                $cnt[$k]{'ID'} = $storage{$index}{'slotID_$j'}; 
            	            $count++; 
                	        last;                         
                    	} 
                  	} 
               	} 
            } 
            $display = ""; 
            $count ++; 
            for($j = 0;$j < $count;$j++) { 
				if($j == 0 && $cnt[$j]{'amount'}) { 
                	if($cnt[$j]{'amount'} > 1) { 
                		$display .= "$cnt[$j]{'amount'}X$cnt[$j]{'name'}"; 
                		} else { 
		                	$display .= "$cnt[$j]{'name'}"; 
    		            } 
        			} elsif ($cnt[$j]{'amount'}) { 
            	    	if($cnt[$j]{'amount'} > 1) { 
                	    	$display .= ",$cnt[$j]{'amount'}X$cnt[$j]{'name'}"; 
					} else { 
                		$display .= ",$cnt[$j]{'name'}"; 
					} 
				} 
			} 
			$storage{$index}{'slotName'} = $display; 

			$display = ($items_lut{$ID} ne "")
				? $items_lut{$ID}
				: "Unknown ".$ID;
			$storage{$index}{'name'} = $display;
			$storage{$index}{'binID'} = binFind(\@storageID, $index);
			print "Storage: $storage{$index}{'name'} ($storage{$index}{'binID'})\n" if $config{'debug'};
		}
		print "Storage opened\n";
#Solos End
	} elsif ($switch eq "00A8") {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		$index = unpack("S1",substr($msg, 2, 2));
		$amount = unpack("C1",substr($msg, 6, 1));
		undef $invIndex;
		$invIndex = findIndex(\@{$chars[$config{'char'}]{'inventory'}}, "index", $index);
		$chars[$config{'char'}]{'inventory'}[$invIndex]{'amount'} -= $amount;
		print "You used Item: $chars[$config{'char'}]{'inventory'}[$invIndex]{'name'} ($invIndex) x $amount\n";
		if ($chars[$config{'char'}]{'inventory'}[$invIndex]{'amount'} <= 0) {
			undef %{$chars[$config{'char'}]{'inventory'}[$invIndex]};
		}

	} elsif ($switch eq "00AA") {
		$index = unpack("S1",substr($msg, 2, 2));
		$type = unpack("S1",substr($msg, 4, 2));
		$fail = unpack("C1",substr($msg, 6, 1));
		undef $invIndex;
		$invIndex = findIndex(\@{$chars[$config{'char'}]{'inventory'}}, "index", $index);
		if ($fail == 0) {
			print "You can't put on $chars[$config{'char'}]{'inventory'}[$invIndex]{'name'} ($invIndex)\n";
		} else {
			$chars[$config{'char'}]{'inventory'}[$invIndex]{'equipped'} = $chars[$config{'char'}]{'inventory'}[$invIndex]{'type_equip'};
			print "You equip $chars[$config{'char'}]{'inventory'}[$invIndex]{'name'} ($invIndex) - $equipTypes_lut{$chars[$config{'char'}]{'inventory'}[$invIndex]{'type_equip'}}\n";
		}

	} elsif ($switch eq "00AC") {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		$index = unpack("S1",substr($msg, 2, 2));
		$type = unpack("S1",substr($msg, 4, 2));
		undef $invIndex;
		$invIndex = findIndex(\@{$chars[$config{'char'}]{'inventory'}}, "index", $index);
		$chars[$config{'char'}]{'inventory'}[$invIndex]{'equipped'} = "";
		print "You unequip $chars[$config{'char'}]{'inventory'}[$invIndex]{'name'} ($invIndex) - $equipTypes_lut{$chars[$config{'char'}]{'inventory'}[$invIndex]{'type_equip'}}\n";

	} elsif ($switch eq "00AF") {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		$index = unpack("S1",substr($msg, 2, 2));
		$amount = unpack("S1",substr($msg, 4, 2));
		undef $invIndex;
		$invIndex = findIndex(\@{$chars[$config{'char'}]{'inventory'}}, "index", $index);
		print "Inventory Item Removed: $chars[$config{'char'}]{'inventory'}[$invIndex]{'name'} ($invIndex) x $amount\n";
		$chars[$config{'char'}]{'inventory'}[$invIndex]{'amount'} -= $amount;
		if ($chars[$config{'char'}]{'inventory'}[$invIndex]{'amount'} <= 0) {
			undef %{$chars[$config{'char'}]{'inventory'}[$invIndex]};
		}

	} elsif ($switch eq "00B0") {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		$type = unpack("S1",substr($msg, 2, 2));
		$val = unpack("S1",substr($msg, 4, 2));
		if ($type == 0) {
			print "Something1: $val\n" if ($config{'debug'} >= 2);
		} elsif ($type == 3) {
			print "Something2: $val\n" if ($config{'debug'} >= 2);
		} elsif ($type == 5) {
			$chars[$config{'char'}]{'hp'} = $val;
			print "Hp: $val\n" if ($config{'debug'} >= 2);
		} elsif ($type == 6) {
			$chars[$config{'char'}]{'hp_max'} = $val;
			print "Max Hp: $val\n" if ($config{'debug'} >= 2);
		} elsif ($type == 7) {
			$chars[$config{'char'}]{'sp'} = $val;
			print "Sp: $val\n" if ($config{'debug'} >= 2);
		} elsif ($type == 8) {
			$chars[$config{'char'}]{'sp_max'} = $val;
			print "Max Sp: $val\n" if ($config{'debug'} >= 2);
		} elsif ($type == 9) {
			$chars[$config{'char'}]{'points_free'} = $val;
			print "Status Points: $val\n" if ($config{'debug'} >= 2);
		} elsif ($type == 11) {
			$chars[$config{'char'}]{'lv'} = $val;
			print "Level: $val\n" if ($config{'debug'} >= 2);
		} elsif ($type == 12) {
			$chars[$config{'char'}]{'points_skill'} = $val;
			print "Skill Points: $val\n" if ($config{'debug'} >= 2);
		} elsif ($type == 24) {
			$chars[$config{'char'}]{'weight'} = int($val / 10);
			print "Weight: $chars[$config{'char'}]{'weight'}\n" if ($config{'debug'} >= 2);
		} elsif ($type == 25) {
			$chars[$config{'char'}]{'weight_max'} = int($val / 10);
			print "Max Weight: $chars[$config{'char'}]{'weight_max'}\n" if ($config{'debug'} >= 2);
		} elsif ($type == 41) {
			$chars[$config{'char'}]{'attack'} = $val;
			print "Attack: $val\n" if ($config{'debug'} >= 2);
		} elsif ($type == 42) {
			$chars[$config{'char'}]{'attack_bonus'} = $val;
			print "Attack Bonus: $val\n" if ($config{'debug'} >= 2);
		} elsif ($type == 43) {
			$chars[$config{'char'}]{'attack_magic_min'} = $val;
			print "Magic Attack Min: $val\n" if ($config{'debug'} >= 2);
		} elsif ($type == 44) {
			$chars[$config{'char'}]{'attack_magic_max'} = $val;
			print "Magic Attack Max: $val\n" if ($config{'debug'} >= 2);
		} elsif ($type == 45) {
			$chars[$config{'char'}]{'def'} = $val;
			print "Defense: $val\n" if ($config{'debug'} >= 2);
		} elsif ($type == 46) {
			$chars[$config{'char'}]{'def_bonus'} = $val;
			print "Defense Bonus: $val\n"if ($config{'debug'} >= 2);
		} elsif ($type == 47) {
			$chars[$config{'char'}]{'def_magic'} = $val;
			print "Magic Defense: $val\n" if ($config{'debug'} >= 2);
		} elsif ($type == 48) {
			$chars[$config{'char'}]{'def_magic_bonus'} = $val;
			print "Magic Defense Bonus: $val\n" if ($config{'debug'} >= 2);
		} elsif ($type == 49) {
			$chars[$config{'char'}]{'hit'} = $val;
			print "Hit: $val\n" if ($config{'debug'} >= 2);
		} elsif ($type == 50) {
			$chars[$config{'char'}]{'flee'} = $val;
			print "Flee: $val\n" if ($config{'debug'} >= 2);
		} elsif ($type == 51) {
			$chars[$config{'char'}]{'flee_bonus'} = $val;
			print "Flee Bonus: $val\n" if ($config{'debug'} >= 2);
		} elsif ($type == 52) {
			$chars[$config{'char'}]{'critical'} = $val;
			print "Critical: $val\n" if ($config{'debug'} >= 2);
#Solos Start
        } elsif ($type == 53) { 
            $chars[$config{'char'}]{'attack_speed'} = 200 - $val/10; 
            print "Attack Speed: $chars[$config{'char'}]{'attack_speed'}\n" if ($config{'debug'} >= 2);
#Solos End
		} elsif ($type == 55) {
			$chars[$config{'char'}]{'lv_job'} = $val;
			print "Job Level: $val\n" if ($config{'debug'} >= 2);
		} elsif ($type == 124) {
			print "Something3: $val\n" if ($config{'debug'} >= 2);
		} else {
			print "Something: $val\n" if ($config{'debug'} >= 2);
		}

	} elsif ($switch eq "00B1") {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		$type = unpack("S1",substr($msg, 2, 2));
		$val = unpack("L1",substr($msg, 4, 4));
		if ($type == 1) {
			$chars[$config{'char'}]{'exp_last'} = $chars[$config{'char'}]{'exp'};
			$chars[$config{'char'}]{'exp'} = $val;
			print "Exp: $val\n" if $config{'debug'}; 
		} elsif ($type == 2) {
			$chars[$config{'char'}]{'exp_job_last'} = $chars[$config{'char'}]{'exp_job'};
			$chars[$config{'char'}]{'exp_job'} = $val;
			print "Job Exp: $val\n" if $config{'debug'};
		} elsif ($type == 20) {
			$chars[$config{'char'}]{'zenny'} = $val;
			print "Zenny: $val\n" if $config{'debug'};
		} elsif ($type == 22) {
			$chars[$config{'char'}]{'exp_max_last'} = $chars[$config{'char'}]{'exp_max'};
			$chars[$config{'char'}]{'exp_max'} = $val;
			print "Required Exp: $val\n" if $config{'debug'};
		} elsif ($type == 23) {
			$chars[$config{'char'}]{'exp_job_max_last'} = $chars[$config{'char'}]{'exp_job_max'};
			$chars[$config{'char'}]{'exp_job_max'} = $val;
			print "Required Job Exp: $val\n" if $config{'debug'};
		}

	} elsif ($switch eq "00B3") {
		$conState = 2;

	} elsif ($switch eq "00B4" && length($msg) >= unpack("S1", substr($msg, 2, 2))) {
		$msg_size = unpack("S1", substr($msg, 2, 2));
		decrypt(\$newmsg, substr($msg, 8, length($msg)-8));
		$msg = substr($msg, 0, 8).$newmsg;
		$ID = substr($msg, 4, 4);
		($talk) = substr($msg, 8, $msg_size - 8) =~ /([\s\S]*?)\000/;
		$talk{'ID'} = $ID;
		$talk{'nameID'} = unpack("L1", $ID);
		$talk{'msg'} = $talk;
		print "$npcs{$ID}{'name'} : $talk{'msg'}\n";

	} elsif ($switch eq "00B5") {
		$ID = substr($msg, 2, 4);
		print "$npcs{$ID}{'name'} : Type 'talk cont' to continue talking\n";

	} elsif ($switch eq "00B6") {
		$ID = substr($msg, 2, 4);
		undef %talk;
		print "$npcs{$ID}{'name'} : Done talking\n";

	} elsif ($switch eq "00B7" && length($msg) >= unpack("S1", substr($msg, 2, 2))) {
		$msg_size = unpack("S1", substr($msg, 2, 2));
		decrypt(\$newmsg, substr($msg, 8, length($msg)-8));
		$msg = substr($msg, 0, 8).$newmsg;
		$ID = substr($msg, 4, 4);
		($talk) = substr($msg, 8, $msg_size - 8) =~ /([\s\S]*?)\000/;
		@preTalkResponses = split /:/, $talk;
		undef @{$talk{'responses'}};
		foreach (@preTalkResponses) {
			push @{$talk{'responses'}}, $_ if $_ ne "";
		}
		$talk{'responses'}[@{$talk{'responses'}}] = "Cancel Chat";
		print "$npcs{$ID}{'name'} : Type 'talk resp' and choose a response.\n";
	
	} elsif ($switch eq "00BC") {
		$type = unpack("S1",substr($msg, 2, 2));
		$val = unpack("C1",substr($msg, 5, 1));
		if ($val == 207) {
			print "Not enough stat points to add\n";
		} else {
			if ($type == 13) {
				$chars[$config{'char'}]{'str'} = $val;
				print "Strength: $val\n" if $config{'debug'};
			} elsif ($type == 14) {
				$chars[$config{'char'}]{'agi'} = $val;
				print "Agility: $val\n" if $config{'debug'};
			} elsif ($type == 15) {
				$chars[$config{'char'}]{'vit'} = $val;
				print "Vitality: $val\n" if $config{'debug'};
			} elsif ($type == 16) {
				$chars[$config{'char'}]{'int'} = $val;
				print "Intelligence: $val\n" if $config{'debug'};
			} elsif ($type == 17) {
				$chars[$config{'char'}]{'dex'} = $val;
				print "Dexterity: $val\n" if $config{'debug'};
			} elsif ($type == 18) {
				$chars[$config{'char'}]{'luk'} = $val;
				print "Luck: $val\n" if $config{'debug'};
			} else {
				print "Something: $val\n";
			}
		}


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
		print	"Strength: $chars[$config{'char'}]{'str'} #$chars[$config{'char'}]{'points_str'}\n"
			,"Agility: $chars[$config{'char'}]{'agi'} #$chars[$config{'char'}]{'points_agi'}\n"
			,"Vitality: $chars[$config{'char'}]{'vit'} #$chars[$config{'char'}]{'points_vit'}\n"
			,"Intelligence: $chars[$config{'char'}]{'int'} #$chars[$config{'char'}]{'points_int'}\n"
			,"Dexterity: $chars[$config{'char'}]{'dex'} #$chars[$config{'char'}]{'points_dex'}\n"
			,"Luck: $chars[$config{'char'}]{'luk'} #$chars[$config{'char'}]{'points_luk'}\n"
			,"Attack: $chars[$config{'char'}]{'attack'}\n"
			,"Attack Bonus: $chars[$config{'char'}]{'attack_bonus'}\n"
			,"Magic Attack Min: $chars[$config{'char'}]{'attack_magic_min'}\n"
			,"Magic Attack Max: $chars[$config{'char'}]{'attack_magic_max'}\n"
			,"Defense: $chars[$config{'char'}]{'def'}\n"
			,"Defense Bonus: $chars[$config{'char'}]{'def_bonus'}\n"
			,"Magic Defense: $chars[$config{'char'}]{'def_magic'}\n"
			,"Magic Defense Bonus: $chars[$config{'char'}]{'def_magic_bonus'}\n"
			,"Hit: $chars[$config{'char'}]{'hit'}\n"
			,"Flee: $chars[$config{'char'}]{'flee'}\n"
			,"Flee Bonus: $chars[$config{'char'}]{'flee_bonus'}\n"
			,"Critical: $chars[$config{'char'}]{'critical'}\n"
			,"Status Points: $chars[$config{'char'}]{'points_free'}\n"
			if $config{'debug'};

	} elsif ($switch eq "00BE") {
		$type = unpack("S1",substr($msg, 2, 2));
		$val = unpack("C1",substr($msg, 4, 1));
		if ($type == 32) {
			$chars[$config{'char'}]{'points_str'} = $val;
			print "Points needed for Strength: $val\n" if $config{'debug'};
		} elsif ($type == 33) {
			$chars[$config{'char'}]{'points_agi'} = $val;
			print "Points needed for Agility: $val\n" if $config{'debug'};
		} elsif ($type == 34) {
			$chars[$config{'char'}]{'points_vit'} = $val;
			print "Points needed for Vitality: $val\n" if $config{'debug'};
		} elsif ($type == 35) {
			$chars[$config{'char'}]{'points_int'} = $val;
			print "Points needed for Intelligence: $val\n" if $config{'debug'};
		} elsif ($type == 36) {
			$chars[$config{'char'}]{'points_dex'} = $val;
			print "Points needed for Dexterity: $val\n" if $config{'debug'};
		} elsif ($type == 37) {
			$chars[$config{'char'}]{'points_luk'} = $val;
			print "Points needed for Luck: $val\n" if $config{'debug'};
		}
		
	} elsif ($switch eq "00C0") {
		$ID = substr($msg, 2, 4);
		$type = unpack("C*", substr($msg, 6, 1));
		if ($ID eq $accountID) {
			print "$chars[$config{'char'}]{'name'} : $emotions_lut{$type}\n";
			chatLog("e", "$chars[$config{'char'}]{'name'} : $emotions_lut{$type}\n") if (existsInList($config{'logEmoticons'}, $type) || $config{'logEmoticons'} eq "all");
		} elsif (%{$players{$ID}}) {
			print "$players{$ID}{'name'} : $emotions_lut{$type}\n";
			chatLog("e", "$players{$ID}{'name'} : $emotions_lut{$type}\n") if (existsInList($config{'logEmoticons'}, $type) || $config{'logEmoticons'} eq "all");

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


	} elsif ($switch eq "00C1") {
		
	} elsif ($switch eq "00C2") {
		$users = unpack("L*", substr($msg, 2, 4));
		print "There are currently $users users online\n";

	} elsif ($switch eq "00C3") {

	} elsif ($switch eq "00C4") {
		$ID = substr($msg, 2, 4);
		undef %talk;
		$talk{'buyOrSell'} = 1;
		$talk{'ID'} = $ID;
		print "$npcs{$ID}{'name'} : Type 'store' to start buying, or type 'sell' to start selling\n";

	} elsif ($switch eq "00C6" && length($msg) >= unpack("S1", substr($msg, 2, 2))) {
		$msg_size = unpack("S1",substr($msg,2,2));
		decrypt(\$newmsg, substr($msg, 4, length($msg)-4));
		$msg = substr($msg, 0, 4).$newmsg;
		undef @storeList;
		$storeList = 0;
		undef $talk{'buyOrSell'};
		for ($i = 4; $i < $msg_size; $i+=11) {
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
			print "Item added to Store: $storeList[$storeList]{'name'} - $price z\n" if ($config{'debug'} >= 2);
			$storeList++;
		}
		print "$npcs{$talk{'ID'}}{'name'} : Check my store list by typing 'store'\n";
		
	} elsif ($switch eq "00C7" && length($msg) >= unpack("S1", substr($msg, 2, 2))) {
		#sell list, similar to buy list
		$msg_size = unpack("S1",substr($msg,2,2));
		if (length($msg) > 4) {
			decrypt(\$newmsg, substr($msg, 4, length($msg)-4));
			$msg = substr($msg, 0, 4).$newmsg;
		}
		undef $talk{'buyOrSell'};
		print "Ready to start selling items\n";
		
	} elsif ($switch eq "00CA") {

	} elsif ($switch eq "00CB") {

	} elsif ($switch eq "00D1") {
		$type = unpack("C1", substr($msg, 2, 1));
		$error = unpack("C1", substr($msg, 3, 1));
		if ($type == 0) {
			print "Player ignored\n";
		} elsif ($type == 1) {
			if ($error == 0) {
				print "Player unignored\n";
			}
		}

	} elsif ($switch eq "00D2") {
		$type = unpack("C1", substr($msg, 2, 1));
		$error = unpack("C1", substr($msg, 3, 1));
		if ($type == 0) {
			print "All Players ignored\n";
		} elsif ($type == 1) {
			if ($error == 0) {
				print "All players unignored\n";
			}
		}

	} elsif ($switch eq "00D3") {

	} elsif ($switch eq "00D6") {
		$currentChatRoom = "new";
		%{$chatRooms{'new'}} = %createdChatRoom;
		binAdd(\@chatRoomsID, "new");
		binAdd(\@currentChatRoomUsers, $chars[$config{'char'}]{'name'});
		print "Chat Room Created\n";

	} elsif ($switch eq "00D7" && length($msg) >= unpack("S1", substr($msg, 2, 2))) {
		$msg_size = unpack("S1",substr($msg,2,2));
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
		undef %{$chatRooms{$ID}};

	} elsif ($switch eq "00DA") {
		$type = unpack("C1",substr($msg, 2, 1));
		if ($type == 1) {
			print "Can't join Chat Room - Incorrect Password\n";
		} elsif ($type == 2) {
			print "Can't join Chat Room - You're banned\n";
		}

	} elsif ($switch eq "00DB" && length($msg) >= unpack("S1", substr($msg, 2, 2))) {
		$msg_size = unpack("S1",substr($msg,2,2));
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
		print qq~You have joined the Chat Room "$chatRooms{$currentChatRoom}{'title'}"\n~;

	} elsif ($switch eq "00DC") {
		if ($currentChatRoom ne "") {
			$num_users = unpack("S1", substr($msg,2,2));
			($joinedUser) = substr($msg,4,24) =~ /([\s\S]*?)\000/;
			binAdd(\@currentChatRoomUsers, $joinedUser);
			$chatRooms{$currentChatRoom}{'users'}{$joinedUser} = 1;
			$chatRooms{$currentChatRoom}{'num_users'} = $num_users;
			print "$joinedUser has joined the Chat Room\n";
		}
	
	} elsif ($switch eq "00DD") {
		$num_users = unpack("S1", substr($msg,2,2));
		($leaveUser) = substr($msg,4,24) =~ /([\s\S]*?)\000/;
		$chatRooms{$currentChatRoom}{'users'}{$leaveUser} = "";
		binRemove(\@currentChatRoomUsers, $leaveUser);
		$chatRooms{$currentChatRoom}{'num_users'} = $num_users;
		if ($leaveUser eq $chars[$config{'char'}]{'name'}) {
			binRemove(\@chatRoomsID, $currentChatRoom);
			undef %{$chatRooms{$currentChatRoom}};
			undef @currentChatRoomUsers;
			$currentChatRoom = "";
			print "You left the Chat Room\n";
		} else {
			print "$leaveUser has left the Chat Room\n";
		}

	} elsif ($switch eq "00DF" && length($msg) >= unpack("S1", substr($msg, 2, 2))) {
		$msg_size = unpack("S1",substr($msg,2,2));
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
		print "Chat Room Properties Modified\n";
		
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

	} elsif ($switch eq "00E5") {
		($dealUser) = substr($msg, 2, 24) =~ /([\s\S]*?)\000/;
		$incomingDeal{'name'} = $dealUser;
		$timeout{'ai_dealAutoCancel'}{'time'} = time;
		print "$dealUser Requests a Deal\n";

		#BCN Start - DealDump
		if ($config{'dealAutoAccept'} && $ai_seq[0] ne "dealAutoAccept") {
			my $args = ();
			$args{'mode'} = "engage";
			$args{'time'} = time + 0.2;
			$args{'name'} = $dealUser;

			unshift @ai_seq, "dealAutoAccept";
			unshift @ai_seq_args, \%args;
		}
		#BCN End - DealDump

	} elsif ($switch eq "00E7") {
		$type = unpack("C1", substr($msg, 2, 1));
		
		if ($type == 3) {
			if (%incomingDeal) {
				$currentDeal{'name'} = $incomingDeal{'name'};
			} else {
				$currentDeal{'ID'} = $outgoingDeal{'ID'};
				$currentDeal{'name'} = $players{$outgoingDeal{'ID'}}{'name'};
			} 
			print "Engaged Deal with $currentDeal{'name'}\n";
		}
		undef %outgoingDeal;
		undef %incomingDeal;

	} elsif ($switch eq "00E9") {
		$amount = unpack("L*", substr($msg, 2,4));
		$ID = unpack("S*", substr($msg, 6,2));
		if ($ID > 0) {
			$currentDeal{'other'}{$ID}{'amount'} += $amount;
			$display = ($items_lut{$ID} ne "")
					? $items_lut{$ID}
					: "Unknown ".$ID;
			$currentDeal{'other'}{$ID}{'name'} = $display;
			print "$currentDeal{'name'} added Item to Deal: $currentDeal{'other'}{$ID}{'name'} x $amount\n";
		} elsif ($amount > 0) {
			$currentDeal{'other_zenny'} += $amount;
			print "$currentDeal{'name'} added $amount z to Deal\n";
		}

	} elsif ($switch eq "00EA") {
		$index = unpack("S1", substr($msg, 2, 2));
		undef $invIndex;
		if ($index > 0) {
			$invIndex = findIndex(\@{$chars[$config{'char'}]{'inventory'}}, "index", $index);
			$currentDeal{'you'}{$chars[$config{'char'}]{'inventory'}[$invIndex]{'nameID'}}{'amount'} += $currentDeal{'lastItemAmount'};
			$chars[$config{'char'}]{'inventory'}[$invIndex]{'amount'} -= $currentDeal{'lastItemAmount'};
			print "You added Item to Deal: $chars[$config{'char'}]{'inventory'}[$invIndex]{'name'} x $currentDeal{'lastItemAmount'}\n";
			if ($chars[$config{'char'}]{'inventory'}[$invIndex]{'amount'} <= 0) {
				undef %{$chars[$config{'char'}]{'inventory'}[$invIndex]};
			}
		} elsif ($currentDeal{'lastItemAmount'} > 0) {
			$chars[$config{'char'}]{'zenny'} -= $currentDeal{'you_zenny'};
		}

	} elsif ($switch eq "00EC") {
		$type = unpack("C1", substr($msg, 2, 1));
		if ($type == 1) {
			$currentDeal{'other_finalize'} = 1;
			print "$currentDeal{'name'} finalized the Deal\n";

			#BCN Start - DealDump
			if ($config{'dealAutoAccept'} && $ai_seq[0] ne "dealAutoAccept") {
				my $args = ();
				$args{'mode'} = "accept";
				$args{'time'} = time + 0.3;

				unshift @ai_seq, "dealAutoAccept";
				unshift @ai_seq_args, \%args;
			}
			#BCN End - DealDump
		} else {
			$currentDeal{'you_finalize'} = 1;
			print "You finalized the Deal\n";
		}

	} elsif ($switch eq "00EE") {
		undef %incomingDeal;
		undef %outgoingDeal;
		undef %currentDeal;
		print "Deal Cancelled\n";

	} elsif ($switch eq "00F0") {
		print "Deal Complete\n";
		undef %currentDeal;

	} elsif ($switch eq "00F2") {
		$storage{'items'} = unpack("S1", substr($msg, 2, 2));
		$storage{'items_max'} = unpack("S1", substr($msg, 4, 2));

	} elsif ($switch eq "00F4") {
		$index = unpack("S1", substr($msg, 2, 2));
		$amount = unpack("L1", substr($msg, 4, 4));
		$ID = unpack("S1", substr($msg, 8, 2));
		if (%{$storage{$ID}}) {
			$storage{$ID}{'amount'} += $amount;
		} else {
			binAdd(\@storageID, $ID);
			$storage{$ID}{'index'} = $index;
			$storage{$ID}{'amount'} = $amount;
			$display = ($items_lut{$ID} ne "")
				? $items_lut{$ID}
				: "Unknown ".$ID;
			$storage{$ID}{'name'} = $display;
			$storage{$ID}{'binID'} = binFind(\@storageID, $ID);
		}
		print "Storage Item Added: $storage{$ID}{'name'} ($storage{$ID}{'binID'}) x $amount\n";

	} elsif ($switch eq "00F6") {
		$index = unpack("S1", substr($msg, 2, 2));
		$amount = unpack("L1", substr($msg, 4, 4));
		$ID = findKey(\%storage, "index", $index);
		$storage{$ID}{'amount'} -= $amount;
		print "Storage Item Removed: $storage{$ID}{'name'} ($storage{$ID}{'binID'}) x $amount\n";
		if ($storage{$ID}{'amount'} <= 0) {
			undef %{$storage{$ID}};
			binRemove(\@storageID, $ID);
		}

	} elsif ($switch eq "00F8") {
		print "Storage Closed\n";

	} elsif ($switch eq "00FA") {
		$type = unpack("C1", substr($msg, 2, 1));
		if ($type == 1) {
			print "Can't organize party - party name exists\n";
		} 

	} elsif ($switch eq "00FB" && length($msg) >= unpack("S1", substr($msg, 2, 2))) {
		$msg_size = unpack("S1", substr($msg, 2, 2));
		decrypt(\$newmsg, substr($msg, 28, length($msg)-28));
		$msg = substr($msg, 0, 28).$newmsg;
		($chars[$config{'char'}]{'party'}{'name'}) = substr($msg, 4, 24) =~ /([\s\S]*?)\000/;
		for ($i = 28; $i < $msg_size;$i+=46) {
			$ID = substr($msg, $i, 4);
			$num = unpack("C1",substr($msg, $i + 44, 1));
			if (!%{$chars[$config{'char'}]{'party'}{'users'}{$ID}}) {
				binAdd(\@partyUsersID, $ID);
			}
			($chars[$config{'char'}]{'party'}{'users'}{$ID}{'name'}) = substr($msg, $i + 4, 24) =~ /([\s\S]*?)\000/;
			($chars[$config{'char'}]{'party'}{'users'}{$ID}{'map'}) = substr($msg, $i + 28, 16) =~ /([\s\S]*?)\000/;
			$chars[$config{'char'}]{'party'}{'users'}{$ID}{'online'} = !(unpack("C1",substr($msg, $i + 45, 1)));
			$chars[$config{'char'}]{'party'}{'users'}{$ID}{'admin'} = 1 if ($num == 0);
		}
		sendPartyShareEXP(\$remote_socket, 1) if ($config{'partyAutoShare'} && %{$chars[$config{'char'}]{'party'}});

	} elsif ($switch eq "00FD") {
		($name) = substr($msg, 2, 24) =~ /([\s\S]*?)\000/;
		$type = unpack("C1", substr($msg, 26, 1));
		if ($type == 0) {
			print "Join request failed: $name is already in a party\n";
		} elsif ($type == 1) {
			print "Join request failed: $name denied request\n";
		} elsif ($type == 2) {
			print "$name accepted your request\n";
		}

	} elsif ($switch eq "00FE") {
		$ID = substr($msg, 2, 4);
		($name) = substr($msg, 6, 24) =~ /([\s\S]*?)\000/;
		print "Incoming Request to join party '$name'\n";
		$incomingParty{'ID'} = $ID;
		$timeout{'ai_partyAutoDeny'}{'time'} = time;

	} elsif ($switch eq "0100") {

	} elsif ($switch eq "0101") {
		$type = unpack("C1", substr($msg, 2, 1));
		if ($type == 0) {
			print "Party EXP set to Individual Take\n";
		} elsif ($type == 1) {
			print "Party EXP set to Even Share\n";
		} else {
			print "Error setting party option\n";
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
			binAdd(\@partyUsersID, $ID);
			if ($ID eq $accountID) {
				print "You joined party '$name'\n";
			} else {
				print "$partyUser joined your party '$name'\n";
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

	
	} elsif ($switch eq "0105") {
		$ID = substr($msg, 2, 4);
		($name) = substr($msg, 6, 24) =~ /([\s\S]*?)\000/;
		undef %{$chars[$config{'char'}]{'party'}{'users'}{$ID}};
		binRemove(\@partyUsersID, $ID);
		if ($ID eq $accountID) {
			print "You left the party\n";
			undef %{$chars[$config{'char'}]{'party'}};
			$chars[$config{'char'}]{'party'} = "";
			undef @partyUsersID;
		} else {
			print "$name left the party\n";
		}

	} elsif ($switch eq "0106") {
		$ID = substr($msg, 2, 4);
		$chars[$config{'char'}]{'party'}{'users'}{$ID}{'hp'} = unpack("S1", substr($msg, 6, 2));
		$chars[$config{'char'}]{'party'}{'users'}{$ID}{'hp_max'} = unpack("S1", substr($msg, 8, 2));

	} elsif ($switch eq "0107") {
		$ID = substr($msg, 2, 4);
		$x = unpack("S1", substr($msg,6, 2));
		$y = unpack("S1", substr($msg,8, 2));
		$chars[$config{'char'}]{'party'}{'users'}{$ID}{'pos'}{'x'} = $x;
		$chars[$config{'char'}]{'party'}{'users'}{$ID}{'pos'}{'y'} = $y;
		$chars[$config{'char'}]{'party'}{'users'}{$ID}{'online'} = 1;
		print "Party member location: $chars[$config{'char'}]{'party'}{'users'}{$ID}{'name'} - $x, $y\n" if ($config{'debug'} >= 2);

	} elsif ($switch eq "0108") {
		$type =  unpack("S1",substr($msg, 2, 2));
		$index = unpack("S1",substr($msg, 4, 2));
		$enchant = unpack("S1",substr($msg, 6, 2));
		$invIndex = findIndex(\@{$chars[$config{'char'}]{'inventory'}}, "index", $index);
		$chars[$config{'char'}]{'inventory'}[$invIndex]{'enchant'} = $enchant;

	} elsif ($switch eq "0109" && length($msg) >= unpack("S*", substr($msg, 2, 2))) {
		$msg_size = unpack("S*", substr($msg, 2, 2));
		decrypt(\$newmsg, substr($msg, 8, length($msg)-8));
		$msg = substr($msg, 0, 8).$newmsg;
		$chat = substr($msg, 8, $msg_size - 8);
		$chat =~ s/\000$//;
		($chatMsgUser, $chatMsg) = $chat =~ /([\s\S]*?) : ([\s\S]*)\000/;
		chatLog("p", $chat."\n") if ($config{'logPartyChat'});
		$ai_cmdQue[$ai_cmdQue]{'type'} = "p";
		$ai_cmdQue[$ai_cmdQue]{'user'} = $chatMsgUser;
		$ai_cmdQue[$ai_cmdQue]{'msg'} = $chatMsg;
		$ai_cmdQue[$ai_cmdQue]{'time'} = time;
		$ai_cmdQue++;
		print "%$chat\n";

	# Hambo Started
	# 3 Packets About MVP
	} elsif ($switch eq "010A") {
		$ID = unpack("S1", substr($msg, 2, 2));
		$display = ($items_lut{$ID} ne "")
		? $items_lut{$ID}
		: "Unknown" . $ID;
		print "Get MVP item&#65306;$display\n";
		chatLog("k", "Get MVP item&#65306;$display\n");

	} elsif ($switch eq "010B") {
		$expAmout = unpack("L1", substr($msg, 2, 4));
		print "Congradulations, you are the MVP! Your reward is $expAmout exp!\n";
		chatLog("k", "Congradulations, you are the MVP! Your reward is $expAmout exp!\n");

	} elsif ($switch eq "010C") {
		$ID = substr($msg, 2, 4);
		$display = "Unknown";
		if (%{$players{$ID}}) {
			$display = "Player ". $players{$ID}{'name'} . "(" . $players{$ID}{'binID'} . ") ";
		} elsif ($ID eq $accountID) {
			$display = "Your";
		}
		print "$displaybecome MVP!\n";
		chatLog("k", $display . "become MVP!\n");
	# Hambo Ended

	} elsif ($switch eq "010E") {
		$ID = unpack("S1",substr($msg, 2, 2));
		$lv = unpack("S1",substr($msg, 4, 2));
		$chars[$config{'char'}]{'skills'}{$skills_rlut{lc($skillsID_lut{$ID})}}{'lv'} = $lv;
		print "Skill $skillsID_lut{$ID}: $lv\n" if $config{'debug'};

	} elsif ($switch eq "010F" && length($msg) >= unpack("S1", substr($msg, 2, 2))) {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		$msg_size = unpack("S1", substr($msg, 2, 2));
		decrypt(\$newmsg, substr($msg, 4, length($msg)-4));
		$msg = substr($msg, 0, 4).$newmsg;
		undef @skillsID;
		for($i = 4;$i < $msg_size;$i+=37) {
			$ID = unpack("S1", substr($msg, $i, 2));
			($name) = substr($msg, $i + 12, 24) =~ /([\s\S]*?)\000/;
			if (!$name) {
				$name = $skills_rlut{lc($skillsID_lut{$ID})};
			}
			$chars[$config{'char'}]{'skills'}{$name}{'ID'} = $ID;
			if (!$chars[$config{'char'}]{'skills'}{$name}{'lv'}) {
				$chars[$config{'char'}]{'skills'}{$name}{'lv'} = unpack("S1", substr($msg, $i + 6, 2));
			}
			$skillsID_lut{$ID} = $skills_lut{$name};
			binAdd(\@skillsID, $name);
		}

	} elsif ($switch eq "0110") {
		#Parse this: warp portal

	} elsif ($switch eq "0111") {

	} elsif ($switch eq "0114") {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		$skillID = unpack("S1",substr($msg, 2, 2));
		$sourceID = substr($msg, 4, 4);
		$targetID = substr($msg, 8, 4);
		$damage = unpack("S1",substr($msg, 24, 2));
		$level = unpack("S1",substr($msg, 28, 2));

		undef $sourceDisplay;
		undef $targetDisplay;
		undef $extra;
		if (%{$spells{$sourceID}}) {
			$sourceID = $spells{$sourceID}{'sourceID'}
		}

		updateDamageTables($sourceID, $targetID, $damage) if ($damage != 35536);
		if (%{$monsters{$sourceID}}) {
			$sourceDisplay = "$monsters{$sourceID}{'name'} ($monsters{$sourceID}{'binID'}) uses";
		} elsif (%{$players{$sourceID}}) {
			$sourceDisplay = "$players{$sourceID}{'name'} ($players{$sourceID}{'binID'}) uses";
			
		} elsif ($sourceID eq $accountID) {
			$sourceDisplay = "You use";
			$chars[$config{'char'}]{'skills'}{$skills_rlut{lc($skillsID_lut{$skillID})}}{'time_used'} = time;
			undef $chars[$config{'char'}]{'time_cast'};
		} else {
			$sourceDisplay = "Unknown uses";
		}

		if (%{$monsters{$targetID}}) {
			$targetDisplay = "$monsters{$targetID}{'name'} ($monsters{$targetID}{'binID'})";
			if ($sourceID eq $accountID) {
				$monsters{$targetID}{'castOnByYou'}++;
			} else {
				$monsters{$targetID}{'castOnByPlayer'}{$sourceID}++;
			}
		} elsif (%{$players{$targetID}}) {
			$targetDisplay = "$players{$targetID}{'name'} ($players{$targetID}{'binID'})";
		} elsif ($targetID eq $accountID) {
			if ($sourceID eq $accountID) {
				$targetDisplay = "yourself";
			} else {
				$targetDisplay = "you";
			}
		} else {
			$targetDisplay = "unknown";
		}

		if ($damage == 35536) {
			$level_real = $level;
			print "$sourceDisplay $skillsID_lut{$skillID} (lvl $level)\n";
		} else {
			$damage = "Miss!" if (!$damage);
			if ($level == 65535) {
				print "$sourceDisplay $skillsID_lut{$skillID} on $targetDisplay$extra - Dmg: $damage\n";
			} else {
				$level = $level_real if ($level_real ne "");
				print "$sourceDisplay $skillsID_lut{$skillID} (lvl $level) on $targetDisplay$extra - Dmg: $damage\n";
			}
		}


	} elsif ($switch eq "0115") {

	} elsif ($switch eq "0117") {
		$skillID = unpack("S1",substr($msg, 2, 2));
		$sourceID = substr($msg, 4, 4);
		$lv = unpack("S1",substr($msg, 8, 2));
		$x = unpack("S1",substr($msg, 10, 2));
		$y = unpack("S1",substr($msg, 12, 2));
		
		undef $sourceDisplay;
		if (%{$monsters{$sourceID}}) {
			$sourceDisplay = "$monsters{$sourceID}{'name'} ($monsters{$sourceID}{'binID'}) uses";
		} elsif (%{$players{$sourceID}}) {
			$sourceDisplay = "$players{$sourceID}{'name'} ($players{$sourceID}{'binID'}) uses";
		} elsif ($sourceID eq $accountID) {
			$sourceDisplay = "You use";
			$chars[$config{'char'}]{'skills'}{$skills_rlut{lc($skillsID_lut{$skillID})}}{'time_used'} = time;
			undef $chars[$config{'char'}]{'time_cast'};
		} else {
			$sourceDisplay = "Unknown uses";
		}
		print "$sourceDisplay $skillsID_lut{$skillID} on location ($x, $y)\n";

	} elsif ($switch eq "0119") {
#Solos Start
		$ID = substr($msg, 2, 4);
		$param1 = unpack("S1", substr($msg, 6, 2));
		$param2 = unpack("S1", substr($msg, 8, 2));
		$param3 = unpack("S1", substr($msg, 10, 2));
		$frozen = unpack("S1", substr($msg, 6, 2));

		# character looks
		if ($ID eq $accountID) {
			if ($param2 == 0x0001) {
				# poison
				# if you've got detoxify, use it ;)
				if ($chars[$config{'char'}]{'skills'}{'TF_DETOXIFY'}{'lv'}) {
					ai_skillUse($chars[$config{'char'}]{'skills'}{'TF_DETOXIFY'}{'ID'}, 1, 0, 0, $accountID);
				} else {
					my $index = findIndexString_lc(\@{$chars[$config{'char'}]{'inventory'}}, "name", $config{"useSelf_item_CurePoison"});
					if ($index ne "") {
						print "Auto cure poison\n";
						sendItemUse(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$index]{'index'}, $accountID);
					}
				}
			}
				
		} elsif (%{$monsters{$ID}}) {
			my $prevState = $monsters{$ID}{'state'};
			$monsters{$ID}{'state'} = unpack("S*", substr($msg, 6, 2)); 
			$monsters{$ID}{'state'} = 0 if ($monsters{$ID}{'state'} == 5); 
			my $mon = "Monster $monsters{$ID}{name} $monsters{$ID}{nameID} ($monsters{$ID}{binID})"; 
			if (!$monsters{$ID}{'state'}) {
				print "$mon is free.\n" if ($prevState);

			} elsif ($monsters{$ID}{'state'} == 1) {
				print "$mon is stoned.\n";
				$monsters{$ID}{'ignore'} = 1;

			} elsif ($monsters{$ID}{'state'} == 2) {
				print "$mon is frozen.\n";
				$monsters{$ID}{'ignore'} = 1;

			} elsif ($monsters{$ID}{'state'} == 3) {
				print "$mon is stunned.\n";
				$monsters{$ID}{'ignore'} = 1;

			} elsif ($monsters{$ID}{'state'} == 4) {
				print "$mon is asleep.\n";
				$monsters{$ID}{'ignore'} = 1;

			} else {
				print "$mon is disabled.\n";
				$monsters{$ID}{'ignore'} = 1;
			}
		}
#Solos End                

	
	} elsif ($switch eq "011A") {
		$conState = 5 if ($conState != 4 && $config{'XKore'});
		$skillID = unpack("S1",substr($msg, 2, 2));
		$targetID = substr($msg, 6, 4);
		$sourceID = substr($msg, 10, 4);
		$amount = unpack("S1",substr($msg, 4, 2));
		undef $sourceDisplay;
		undef $targetDisplay;
		undef $extra;
		if (%{$spells{$sourceID}}) {
			$sourceID = $spells{$sourceID}{'sourceID'}
		}
		if (%{$monsters{$sourceID}}) {
			$sourceDisplay = "$monsters{$sourceID}{'name'} ($monsters{$sourceID}{'binID'}) uses";
		} elsif (%{$players{$sourceID}}) {
			$sourceDisplay = "$players{$sourceID}{'name'} ($players{$sourceID}{'binID'}) uses";
		} elsif ($sourceID eq $accountID) {
			$sourceDisplay = "You use";
			$chars[$config{'char'}]{'skills'}{$skills_rlut{lc($skillsID_lut{$skillID})}}{'time_used'} = time;
			undef $chars[$config{'char'}]{'time_cast'};
		} else {
			$sourceDisplay = "Unknown uses";
		}
		if (%{$monsters{$targetID}}) {
			$targetDisplay = "$monsters{$targetID}{'name'} ($monsters{$targetID}{'binID'})";
			if ($sourceID eq $accountID) {
				$monsters{$targetID}{'castOnByYou'}++;
			} else {
				$monsters{$targetID}{'castOnByPlayer'}{$sourceID}++;
			}
		} elsif (%{$players{$targetID}}) {
			$targetDisplay = "$players{$targetID}{'name'} ($players{$targetID}{'binID'})";
		} elsif ($targetID eq $accountID) {
			if ($sourceID eq $accountID) {
				$targetDisplay = "yourself";
			} else {
				$targetDisplay = "you";
			}
		} else {
			$targetDisplay = "unknown";
		}
		if ($skillID == 28) {
			$extra = ": $amount hp gained";
		} elsif ($amount != 65535) {
			$extra = ": Lv $amount";
		}
		print "$sourceDisplay $skillsID_lut{$skillID} on $targetDisplay$extra\n";
		#X Start
		if ($config{'autoResponseOnHeal'}) {
			if ((%{$players{$sourceID}}) && (($skillID == 28) || ($skillID == 29) || ($skillID == 34))) {
				if ($targetDisplay eq "you") {
					chatLog("k", "***$sourceDisplay $skillsID_lut{$skillID} on $targetDisplay$extra***\n");
					sendMessage(\$remote_socket, "pm", getResponse("skillgoodM"), $players{$sourceID}{'name'});
				} elsif ($targetDisplay eq  "$monsters{$targetID}{'name'} ($monsters{$targetID}{'binID'})") {
					chatLog("k", "***$sourceDisplay $skillsID_lut{$skillID} on $targetDisplay$extra***\n");
					sendMessage(\$remote_socket, "pm", getResponse("skillbadM"), $players{$sourceID}{'name'});
				}
			}
		}
		#X End

	} elsif ($switch eq "011C") {

	} elsif ($switch eq "011E") {
		$fail = unpack("C1", substr($msg, 2, 1));
		if ($fail) {
			print "Memo Failed\n";
		} else {
			print "Memo Succeeded\n";
		}

	} elsif ($switch eq "011F") {
		#area effect spell
		$ID = substr($msg, 2, 4);
		$SourceID = substr($msg, 6, 4);
		$x = unpack("S1",substr($msg, 10, 2));
		$y = unpack("S1",substr($msg, 12, 2));
		$spells{$ID}{'sourceID'} = $SourceID;
		$spells{$ID}{'pos'}{'x'} = $x;
		$spells{$ID}{'pos'}{'y'} = $y;
		$binID = binAdd(\@spellsID, $ID);
		$spells{$ID}{'binID'} = $binID;

	} elsif ($switch eq "0120") {
		#The area effect spell with ID dissappears
		$ID = substr($msg, 2, 4);
		undef %{$spells{$ID}};
		binRemove(\@spellsID, $ID);

#Cart Parses - chobit andy 20030102
	} elsif ($switch eq "0121") {
		$cart{'items'} = unpack("S1", substr($msg, 2, 2));
		$cart{'items_max'} = unpack("S1", substr($msg, 4, 2));
		$cart{'weight'} = int(unpack("L1", substr($msg, 6, 4)) / 10);
		$cart{'weight_max'} = int(unpack("L1", substr($msg, 10, 4)) / 10);

	} elsif ($switch eq "0122") {
#Solos Start
		$msg_size = unpack("S1",substr($msg, 2, 2));
		decrypt(\$newmsg, substr($msg, 4, length($msg)-4));
		$msg = substr($msg, 0, 4).$newmsg;
		for($i = 4; $i < $msg_size; $i+=20) {
			$index = unpack("S1", substr($msg, $i, 2));
			$ID = unpack("S1", substr($msg, $i+2, 2));
			$type = unpack("C1",substr($msg, $i+4, 1));

#"0122" sends non-stackable item info
#"0123" sends stackable item info
# This is a HACK!!! If the item ID is non-stackable, then try to get an unique item ID for it
# but get the item name first!
			$display = ($items_lut{$ID} ne "")
				? $items_lut{$ID}
				: "Unknown ".$ID;
#			print "[0122]Cart Item Original ID: ".$ID."\n";
			$oldID = $ID;
			$ID += 30000;
			while (%{$cart{'inventory'}{$ID}}) {
				$ID += 1;
			}
#			print "[0122]Cart Item New ID: ".$ID."\n";

			binAdd(\@cartID, $ID);
			$cart{'inventory'}{$ID}{'index'} = $index;
			$cart{'inventory'}{$ID}{'nameID'} = $ID;
			$cart{'inventory'}{$ID}{'amount'} = 1;
			$cart{'inventory'}{$ID}{'name'} = $display;
			$cart{'inventory'}{$ID}{'binID'} = binFind(\@cartID, $ID);
			$cart{'inventory'}{$ID}{'type_equip'} = $itemSlots_lut{$ID};
			$cart{'inventory'}{$ID}{'identified'} = unpack("C1", substr($msg, $i+5, 1));
			$cart{'inventory'}{$ID}{'oldID'} = $oldID;
			print "Non-Stackable Cart Item: $cart{'inventory'}{$ID}{'name'} ($cart{'inventory'}{$ID}{'binID'}) x 1\n" if ($config{'debug'} >= 1);
		}
#Solos End
	} elsif ($switch eq "0123") {
		$msg_size = unpack("S1",substr($msg, 2, 2));
		decrypt(\$newmsg, substr($msg, 4, length($msg)-4));
		$msg = substr($msg, 0, 4).$newmsg;
		for($i = 4; $i < $msg_size; $i+=10) {
			$index = unpack("S1", substr($msg, $i, 2));
			$ID = unpack("S1", substr($msg, $i+2, 2));
			$amount = unpack("S1", substr($msg, $i+6, 2));
			if (%{$cart{'inventory'}{$ID}}) {
				$cart{'inventory'}{$ID}{'amount'} += $amount;
			} else {
				binAdd(\@cartID, $ID);
				$cart{'inventory'}{$ID}{'index'} = $index;
				$cart{'inventory'}{$ID}{'amount'} = $amount;
				$display = ($items_lut{$ID} ne "")
					? $items_lut{$ID}
					: "Unknown ".$ID;
				$cart{'inventory'}{$ID}{'name'} = $display;
				$cart{'inventory'}{$ID}{'binID'} = binFind(\@cartID, $ID);
			}
			print "Cart Item: $cart{'inventory'}{$ID}{'name'} ($cart{'inventory'}{$ID}{'binID'}) x $amount\n" if ($config{'debug'} >= 1);
		}

	} elsif ($switch eq "0124") {
		$index = unpack("S1", substr($msg, 2, 2));
		$amount = unpack("L1", substr($msg, 4, 4));
		$ID = unpack("S1", substr($msg, 8, 2));

#Solos Start
# This is another HACK!!! If the item ID is >= 9000 then you know it is a non-stackable item!
# Then get it an unique item ID but get display name first, as usual.
		if ($ID >= 9000) {
			$oldID = $ID;
			$display = ($items_lut{$ID} ne "")
				? $items_lut{$ID}
				: "Unknown ".$ID;
			$ID += 30000;
			while (%{$cart{'inventory'}{$ID}}) {
				$ID += 1;
			}
			binAdd(\@cartID, $ID);
			$cart{'inventory'}{$ID}{'index'} = $index;
			$cart{'inventory'}{$ID}{'amount'} = $amount;
			$cart{'inventory'}{$ID}{'name'} = $display;
			$cart{'inventory'}{$ID}{'binID'} = binFind(\@cartID, $ID);
			$cart{'inventory'}{$ID}{'oldID'} = $oldID;

		} elsif (%{$cart{'inventory'}{$ID}}) {
			$cart{'inventory'}{$ID}{'amount'} += $amount;

		} else {
			binAdd(\@cartID, $ID);
			$cart{'inventory'}{$ID}{'index'} = $index;
			$cart{'inventory'}{$ID}{'amount'} = $amount;
			$display = ($items_lut{$ID} ne "")
				? $items_lut{$ID}
				: "Unknown ".$ID;
			$cart{'inventory'}{$ID}{'name'} = $display;
			$cart{'inventory'}{$ID}{'binID'} = binFind(\@cartID, $ID);
		}
		print "Cart Item Added: $cart{'inventory'}{$ID}{'name'} ($cart{'inventory'}{$ID}{'binID'}) x $amount\n";

	} elsif ($switch eq "0125") {
		$index = unpack("S1", substr($msg, 2, 2));
		$amount = unpack("L1", substr($msg, 4, 4));
		$ID = findKey(\%{$cart{'inventory'}}, "index", $index);

		$cart{'inventory'}{$ID}{'amount'} -= $amount;
		print "Cart Item Removed: $cart{'inventory'}{$ID}{'name'} ($cart{'inventory'}{$ID}{'binID'}) x $amount\n";
		if ($cart{'inventory'}{$ID}{'amount'} <= 0) {
			undef %{$cart{'inventory'}{$ID}};
			binRemove(\@cartID, $ID);
		}

	} elsif ($switch eq "012C") {
		$index = unpack("S1", substr($msg, 3, 2));
		$amount = unpack("L1", substr($msg, 7, 2));
		$ID = unpack("S1", substr($msg, 9, 2));
		if ($items_lut{$ID} ne "") {
			print "Can't Add Cart Item: $items_lut{$ID}\n";
		}
#Solos Start
	} elsif ($switch eq "012D") {
		#used the shop skill.
		$number = unpack("S1",substr($msg, 2, 2));
		print "You can sell $number items!\n";
#Solos End
	} elsif ($switch eq "0131") {
#Solos Start
		$ID = substr($msg,2,4);
		if (!%{$venderLists{$ID}}) {
			binAdd(\@venderListsID, $ID);
		}
		($venderLists{$ID}{'title'}) = substr($msg,6,36) =~ /(.*?)\000/;
		$venderLists{$ID}{'id'} = $ID;
#Solos End

	} elsif ($switch eq "0132") {
#Solos Start
		$ID = substr($msg,2,4);
		binRemove(\@venderListsID, $ID);
		undef %{$venderLists{$ID}};
#Solos End
#Solos Start
	} elsif ($switch eq "0133") {
		if (length($msg) >= unpack("S1", substr($msg, 2, 2))) {
			$msg_size = unpack("S1",substr($msg,2,2));
			undef @venderItemList;
			undef $venderID;
			$venderID = substr($msg,4,4);
			$venderItemList = 0;
			$~ = "VSTORELIST";
			print "----------Vender Store List-----------\n";
			print "#  Name                                         Type           Amount Price\n";								   
			for ($i = 8; $i < $msg_size; $i+=22) {
				$price = unpack("L1", substr($msg, $i, 4));
				$amount = unpack("S1", substr($msg, $i + 4, 2));
				$number = unpack("S1", substr($msg, $i + 6, 2));
				$type = unpack("C1", substr($msg, $i + 8, 1));
				$ID = unpack("S1", substr($msg, $i + 9, 2));
				$identified = unpack("C1", substr($msg, $i + 11, 1));
				$custom = unpack("C1", substr($msg, $i + 13, 1));
				$card1 = unpack("S1", substr($msg, $i + 14, 2));
				$card2 = unpack("S1", substr($msg, $i + 16, 2));
				$card3 = unpack("S1", substr($msg, $i + 18, 2));
				$card4 = unpack("S1", substr($msg, $i + 20, 2));

				$venderItemList[$number]{'nameID'} = $ID;
				$display = ($items_lut{$ID} ne "") 
					? $items_lut{$ID}
					: "Unknown ".$ID;
				if ($custom) {
					$display = "+$custom " . $display;
				}
				$venderItemList[$number]{'name'} = $display;
				$venderItemList[$number]{'amount'} = $amount;
				$venderItemList[$number]{'type'} = $type;
				$venderItemList[$number]{'identified'} = $identified;
				$venderItemList[$number]{'custom'} = $custom;
				$venderItemList[$number]{'card1'} = $card1;
				$venderItemList[$number]{'card2'} = $card2;
				$venderItemList[$number]{'card3'} = $card3;
				$venderItemList[$number]{'card4'} = $card4;
				$venderItemList[$number]{'price'} = $price;
				$venderItemList++;
				print "Item added to Vender Store: $items{$ID}{'name'} - $price z\n" if ($config{'debug'} >= 2);

				$display = $venderItemList[$number]{'name'};
				if (!($venderItemList[$number]{'identified'})) {
					$display = $display."[NI]";
				}
				if ($venderItemList[$number]{'card1'}) {
					$display = $display."[".$cards_lut{$venderItemList[$number]{'card1'}}."]";
				}
				if ($venderItemList[$number]{'card2'}) {
					$display = $display."[".$cards_lut{$venderItemList[$number]{'card2'}}."]";
				}
				if ($venderItemList[$number]{'card3'}) {
					$display = $display."[".$cards_lut{$venderItemList[$number]{'card3'}}."]";
				}
				if ($venderItemList[$number]{'card4'}) {
					$display = $display."[".$cards_lut{$venderItemList[$number]{'card4'}}."]";
				}
				format VSTORELIST =
@< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<< @>>>>> @>>>>>>>z
$number $display $itemTypes_lut{$venderItemList[$number]{'type'}} $venderItemList[$number]{'amount'} $venderItemList[$number]{'price'}
.
				write;
			}
			print "--------------------------------------\n";
		}

	} elsif ($switch eq "0136") {
		$msg_size = unpack("S1",substr($msg,2,2));

		#started a shop.
		undef @articles;
		$articles = 0;
		$~ = "ARTICLESLIST";
		print "----------Items added to shop ------------------\n";
		print "#  Name                                         Type        Amount     Price\n";				
		for ($i = 8; $i < $msg_size; $i+=22) {
			$price = unpack("L1", substr($msg, $i, 4));
			$number = unpack("S1", substr($msg, $i + 4, 2));
			$amount = unpack("S1", substr($msg, $i + 6, 2));
			$type = unpack("C1", substr($msg, $i + 8, 1));
			$ID = unpack("S1", substr($msg, $i + 9, 2));
			$identified = unpack("C1", substr($msg, $i + 11, 1));
			$custom = unpack("C1", substr($msg, $i + 13, 1));
			$card1 = unpack("S1", substr($msg, $i + 14, 2));
			$card2 = unpack("S1", substr($msg, $i + 16, 2));
			$card3 = unpack("S1", substr($msg, $i + 18, 2));
			$card4 = unpack("S1", substr($msg, $i + 20, 2));

			$articles[$number]{'nameID'} = $ID;
			$display = ($items_lut{$ID} ne "") 
				? $items_lut{$ID}
				: "Unknown ".$ID;
			if ($custom) {
				$display = "+$custom " . $display;
			}
			$articles[$number]{'name'} = $display;
			$articles[$number]{'quantity'} = $amount;
			$articles[$number]{'type'} = $type;
			$articles[$number]{'identified'} = $identified;
			$articles[$number]{'custom'} = $custom;
			$articles[$number]{'card1'} = $card1;
			$articles[$number]{'card2'} = $card2;
			$articles[$number]{'card3'} = $card3;
			$articles[$number]{'card4'} = $card4;
			$articles[$number]{'price'} = $price;
			undef $articles[$number]{'sold'};
			$articles++;

			print "Item added to Vender Store: $items{$ID}{'name'} - $price z\n" if ($config{'debug'} >= 2);
			$display = $articles[$number]{'name'};
			if (!($articles[$number]{'identified'})) {
				$display = $display."[NI]";
			}
			if ($articles[$number]{'card1'}) {
				$display = $display."[".$cards_lut{$articles[$number]{'card1'}}."]";
			}
			if ($articles[$number]{'card2'}) {
				$display = $display."[".$cards_lut{$articles[$number]{'card2'}}."]";
			}
			if ($articles[$number]{'card3'}) {
				$display = $display."[".$cards_lut{$articles[$number]{'card3'}}."]";
			}
			if ($articles[$number]{'card4'}) {
				$display = $display."[".$cards_lut{$articles[$number]{'card4'}}."]";
			}
			format ARTICLESLIST =
@< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<< @>>>>> @>>>>>>>z
$number $display $itemTypes_lut{$articles[$number]{'type'}} $articles[$number]{'quantity'} $articles[$number]{'price'}
.
			write;
		}
		print "-----------------------------------------\n";
		$shopEarned = 0 if (!defined($shopEarned));

	} elsif ($switch eq "0137") {
		#sold something.
		$number = unpack("S1",substr($msg, 2, 2));
		$amount = unpack("S1",substr($msg, 4, 2));
		$articles[$number]{'sold'} += $amount;
		$shopEarned += $amount * $articles[$number]{'price'};
		$articles[$number]{'quantity'} -= $amount;
		print "sold: $amount $articles[$number]{'name'}.\n";
		if ($articles[$number]{'quantity'} < 1) {
			print "sold out: $articles[$number]{'name'}.\n";
			#$articles[$number] = "";
			if (!--$articles){
				print "sold all out.^^\n";
				sendCloseShop(\$remote_socket);
			}
		}
#Solos End

	} elsif ($switch eq "0139") {
		$ID = substr($msg, 2, 4);
		$type = unpack("C1",substr($msg, 14, 1));
		$coords1{'x'} = unpack("S1",substr($msg, 6, 2));
		$coords1{'y'} = unpack("S1",substr($msg, 8, 2));
		$coords2{'x'} = unpack("S1",substr($msg, 10, 2));
		$coords2{'y'} = unpack("S1",substr($msg, 12, 2));
		%{$monsters{$ID}{'pos_attack_info'}} = %coords1;
		%{$chars[$config{'char'}]{'pos'}} = %coords2;
		%{$chars[$config{'char'}]{'pos_to'}} = %coords2;
		print "Recieved attack location - $monsters{$ID}{'pos_attack_info'}{'x'}, $monsters{$ID}{'pos_attack_info'}{'y'} - ".getHex($ID)."\n" if ($config{'debug'} >= 2);

	} elsif ($switch eq "013A") {
		$type = unpack("S1",substr($msg, 2, 2));
	} elsif ($switch eq "013B") {
	} elsif ($switch eq "013C") {  
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
		undef $sourceDisplay;
		undef $targetDisplay;
		if (%{$monsters{$sourceID}}) {
			$sourceDisplay = "$monsters{$sourceID}{'name'} ($monsters{$sourceID}{'binID'}) is casting";
		} elsif (%{$players{$sourceID}}) {
			$sourceDisplay = "$players{$sourceID}{'name'} ($players{$sourceID}{'binID'}) is casting";
		} elsif ($sourceID eq $accountID) {
			$sourceDisplay = "You are casting";
			$chars[$config{'char'}]{'time_cast'} = time;
		} else {
			$sourceDisplay = "Unknown is casting";
		}

			
		if (%{$monsters{$targetID}}) {
			$targetDisplay = "$monsters{$targetID}{'name'} ($monsters{$targetID}{'binID'})";
			if ($sourceID eq $accountID) {
				$monsters{$targetID}{'castOnByYou'}++;
			} else {
				$monsters{$targetID}{'castOnByPlayer'}{$sourceID}++;
			}
		} elsif (%{$players{$targetID}}) {
			$targetDisplay = "$players{$targetID}{'name'} ($players{$targetID}{'binID'})";
		} elsif ($targetID eq $accountID) {
			if ($sourceID eq $accountID) {
				$targetDisplay = "yourself";
			} else {
				$targetDisplay = "you";
			}
		} elsif ($x != 0 || $y != 0) {
			$targetDisplay = "location ($x, $y)";
		} else {
			$targetDisplay = "unknown";
		}
		print "$sourceDisplay $skillsID_lut{$skillID} on $targetDisplay\n";
#Solos Start
#Check if GM is casting warp on you
		if ($skillID == 27) {
#warp avoid code 
			if (($chars[$config{'char'}]{'pos_to'}{'x'} == $x) && ($chars[$config{'char'}]{'pos_to'}{'y'} == $y)) { 
				if (($config{'avoidWarpByTeleport'})) { 
					useTeleport(1); 
				} 
				if (($config{'avoidWarpByWalk'})) { 
					$ai_v{'temp'}{'pos'}{'x'} = int(rand() * 2 - 1 + $x); 
					$ai_v{'temp'}{'pos'}{'y'} = int(rand() * 2 - 1 + $y); 
					if (($ai_v{'temp'}{'pos'}{'x'} == $x) && ($ai_v{'temp'}{'pos'}{'y'} == $y)) { 
						$ai_v{'temp'}{'pos'}{'x'} = int(1 + $x); 
					} 
					move($ai_v{'temp'}{'pos'}{'x'}, $ai_v{'temp'}{'pos'}{'y'}); 
				} 
			} 
#avoid code end 
		}
#Solos End

	} elsif ($switch eq "0141") {
		$type = unpack("S1",substr($msg, 2, 2));
		$val = unpack("S1",substr($msg, 6, 2));
		$val2 = unpack("S1",substr($msg, 10, 2));
		if ($type == 13) {
			$chars[$config{'char'}]{'str'} = $val;
			$chars[$config{'char'}]{'str_bonus'} = $val2;
			print "Strength: $val + $val2\n" if $config{'debug'};
		} elsif ($type == 14) {
			$chars[$config{'char'}]{'agi'} = $val;
			$chars[$config{'char'}]{'agi_bonus'} = $val2;
			print "Agility: $val + $val2\n" if $config{'debug'};
		} elsif ($type == 15) {
			$chars[$config{'char'}]{'vit'} = $val;
			$chars[$config{'char'}]{'vit_bonus'} = $val2;
			print "Vitality: $val + $val2\n" if $config{'debug'};
		} elsif ($type == 16) {
			$chars[$config{'char'}]{'int'} = $val;
			$chars[$config{'char'}]{'int_bonus'} = $val2;
			print "Intelligence: $val + $val2\n" if $config{'debug'};
		} elsif ($type == 17) {
			$chars[$config{'char'}]{'dex'} = $val;
			$chars[$config{'char'}]{'dex_bonus'} = $val2;
			print "Dexterity: $val + $val2\n" if $config{'debug'};
		} elsif ($type == 18) {
			$chars[$config{'char'}]{'luk'} = $val;
			$chars[$config{'char'}]{'luk_bonus'} = $val2;
			print "Luck: $val + $val2\n" if $config{'debug'};
		}

	} elsif ($switch eq "0145") {

	} elsif ($switch eq "0147") {
		$skillID = unpack("S*",substr($msg, 2, 2));
		$skillLv = unpack("S*",substr($msg, 8, 2)); 
      		print "Now use $skillsID_lut{$skillID}, level $skillLv\n"; 
      		sendSkillUse(\$remote_socket, $skillID, $skillLv, $accountID);

#viper mass addon begin
	} elsif ($switch eq "014B") {
	} elsif ($switch eq "014C") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
	} elsif ($switch eq "014E") {
	} elsif ($switch eq "0150") {
	} elsif ($switch eq "0152" && length($msg) >= unpack("S1", substr($msg, 2, 2))) { 
		$msg_size = unpack("S*", substr($msg, 2, 2));

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

	} elsif ($switch eq "0156") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
	} elsif ($switch eq "015A") {
	} elsif ($switch eq "015C") {
	} elsif ($switch eq "0160") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
	} elsif ($switch eq "0163") {
		$msg_size = unpack("S1", substr($msg, 2, 2));

	} elsif ($switch eq "0166") {
		my $newmsg;
		decrypt(\$newmsg, substr($msg, 4, length($msg) - 4));
		my $msg = substr($msg, 0, 4) . $newmsg;
		my $gtIndex;
		for (my $i = 4; $i < $msg_size; $i+=28) {
			$gtIndex = unpack("L1", substr($msg, $i, 4));
			($guild{'title'}[$gtIndex]) = substr($msg, $i + 4, 24) =~ /([\s\S]*?)\000/;
		}
		$msg_size = unpack("S1", substr($msg, 2, 2));

	} elsif ($switch eq "016A") {
		# Guild request
		my $ID = substr($msg, 2, 4);
		my ($name) = substr($msg, 4, 24) =~ /([\s\S]*?)\000/;
		print "Incoming Request to join Guild '$name'\n";
		$incomingGuild{'ID'} = $ID;
		$incomingGuild{'Type'} = 1;
		$timeout{'ai_guildAutoDeny'}{'time'} = time;

#viper mass addon end
	} elsif ($switch eq "016C") {
		($chars[$config{'char'}]{'guild'}{'name'}) = substr($msg, 19, 24) =~ /([\s\S]*?)\000/;
	
	} elsif ($switch eq "016D") {
#Solos Start
		$ID = substr($msg, 2, 4); 
		$TargetID =  substr($msg, 6, 4); 
		$type = unpack("L1", substr($msg, 10, 4)); 
		if ($type) { 
			$isOnline = "Log In"; 
		} else { 
			$isOnline = "Log Out"; 
		} 
		sendGuildMemberNameRequest(\$remote_socket, $TargetID); 
#Solos End

	} elsif ($switch eq "016F" && length($msg) >= 182) {
		($address) = substr($msg, 2, 60) =~ /([\s\S]*?)\000/;
		($message) = substr($msg, 62, 120) =~ /([\s\S]*?)\000/;
		print	"---Guild Notice---\n"
			,"$address\n\n"
			,"$message\n"
			,"------------------\n";

	} elsif ($switch eq "0171") {
		my $ID = substr($msg, 2, 4);
		my ($name) = substr($msg, 6, 24) =~ /[\s\S]*?\000/;
		print "Incoming Request to Ally Guild '$name'\n";
		$incomingGuild{'ID'} = $ID;
		$incomingGuild{'Type'} = 2;
		$timeout{'ai_guildAutoDeny'}{'time'} = time;

	} elsif ($switch eq "0173") {
	} elsif ($switch eq "0174") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
	} elsif ($switch eq "0177" && length($msg) >= unpack("S1", substr($msg, 2, 2))) {
		$msg_size = unpack("S1", substr($msg, 2, 2));
		decrypt(\$newmsg, substr($msg, 4, length($msg)-4));
		$msg = substr($msg, 0, 4).$newmsg;
		undef @identifyID;
		undef $invIndex;
		for ($i = 4; $i < $msg_size; $i += 2) {
			$index = unpack("S1", substr($msg, $i, 2));
			$invIndex = findIndex(\@{$chars[$config{'char'}]{'inventory'}}, "index", $index);
			binAdd(\@identifyID, $invIndex);
		}
		print "Recieved Possible Identify List - type 'identify'\n";

	} elsif ($switch eq "0179") {
		$index = unpack("S*",substr($msg, 2, 2));
		undef $invIndex;
		$invIndex = findIndex(\@{$chars[$config{'char'}]{'inventory'}}, "index", $index);
		$chars[$config{'char'}]{'inventory'}[$invIndex]{'identified'} = 1;
		$chars[$config{'char'}]{'inventory'}[$invIndex]{'type_equip'} = $itemSlots_lut{$chars[$config{'char'}]{'inventory'}[$invIndex]{'nameID'}};
		print "Item Identified: $chars[$config{'char'}]{'inventory'}[$invIndex]{'name'}\n";
		undef @identifyID;
	} elsif ($switch eq "017B") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
	} elsif ($switch eq "017D") {
	} elsif ($switch eq "017F" && length($msg) >= unpack("S1", substr($msg, 2, 2))) { 
		$msg_size = unpack("S*", substr($msg, 2, 2));
		decrypt(\$newmsg, substr($msg, 4, length($msg)-4));
		$msg = substr($msg, 0, 4).$newmsg;
		$ID = substr($msg, 4, 4);
		$chat = substr($msg, 4, $msg_size - 4);
		$chat =~ s/\000$//;
		($chatMsgUser, $chatMsg) = $chat =~ /([\s\S]*?) : ([\s\S]*)\000/;
		chatLog("g", $chat."\n") if ($config{'logGuildChat'});
		$ai_cmdQue[$ai_cmdQue]{'type'} = "g";
		$ai_cmdQue[$ai_cmdQue]{'ID'} = $ID;
		$ai_cmdQue[$ai_cmdQue]{'user'} = $chatMsgUser;
		$ai_cmdQue[$ai_cmdQue]{'msg'} = $chatMsg;
		$ai_cmdQue[$ai_cmdQue]{'time'} = time;
		$ai_cmdQue++;
		print "[Guild] $chat\n";

	} elsif ($switch eq "0188") {
		$type =  unpack("S1",substr($msg, 2, 2));
		$index = unpack("S1",substr($msg, 4, 2));
		$enchant = unpack("S1",substr($msg, 6, 2));
		$invIndex = findIndex(\@{$chars[$config{'char'}]{'inventory'}}, "index", $index);
		$chars[$config{'char'}]{'inventory'}[$invIndex]{'enchant'} = $enchant;

	} elsif ($switch eq "0192") {
#Solos Start
	} elsif ($switch eq "0194") { 
		$ID = substr($msg, 2, 4); 
		if ($characterID ne $ID) { 
			($name) = substr($msg, 6, 24) =~ /([\s\S]*?)\000/; 
			print "Guild Member $name $isOnline\n"; 
		} 
#Solos End
	} elsif ($switch eq "0195") {
		$ID = substr($msg, 2, 4);
		if (%{$players{$ID}}) {
			($players{$ID}{'name'}) = substr($msg, 6, 24) =~ /([\s\S]*?)\000/;
			($players{$ID}{'party'}{'name'}) = substr($msg, 30, 24) =~ /([\s\S]*?)\000/;
			($players{$ID}{'guild'}{'name'}) = substr($msg, 54, 24) =~ /([\s\S]*?)\000/;
			($players{$ID}{'guild'}{'men'}{$players{$ID}{'name'}}{'title'}) = substr($msg, 78, 24) =~ /([\s\S]*?)\000/;
			print "Player Info: $players{$ID}{'name'} ($players{$ID}{'binID'})\n" if ($config{'debug'} >= 2);
		}

	} elsif ($switch eq "0196") {
		#two-hand quicken

	} elsif ($switch eq "019B") {
		$ID = substr($msg, 2, 4);
		$type = unpack("L1",substr($msg, 6, 4));
		if (%{$players{$ID}}) {
			$name = $players{$ID}{'name'};
		} else {
			$name = "Unknown";
		}
		if ($type == 0) {
			print "Player $name gained a level!\n";
		} elsif ($type == 1) {
			print "Player $name gained a job level!\n";
		}
	} elsif ($switch eq "019E") {
	} elsif ($switch eq "01F4") {

	} elsif ($switch eq "01A2") {
		#pet
		($name) = substr($msg, 2, 24) =~ /([\s\S]*?)\000/;
		$pets{$ID}{'name_given'} = 1;

	} elsif ($switch eq "01A4") {
#pet spawn
		$type = unpack("C1",substr($msg, 2, 1));
		$ID = substr($msg, 3, 4);
		if (!%{$pets{$ID}}) {
			binAdd(\@petsID, $ID);
			%{$pets{$ID}} = %{$monsters{$ID}};
			$pets{$ID}{'name_given'} = "Unknown";
			$pets{$ID}{'binID'} = binFind(\@petsID, $ID);
		}
		if (%{$monsters{$ID}}) {
			binRemove(\@monstersID, $ID);
			undef %{$monsters{$ID}};
		}
		print "Pet Spawned: $pets{$ID}{'name'} ($pets{$ID}{'binID'})\n" if ($config{'debug'});
#end of pet spawn code
		
	} elsif ($switch eq "01AA") {
		#pet

	} elsif ($switch eq "01B0") {

#Solos Start
    } elsif ($switch eq "01B3") {
		#NPC image 
		$npc_image = substr($msg, 2,64); 
		($npc_image) = $npc_image =~ /(\S+)/; 
		print "NPC image: $npc_image\n" if $config{'debug'}; 
#Solos End
	} elsif ($switch eq "01B6") {
		#Guild Info 
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

	} elsif ($switch eq "01C4") { 
      		$index = unpack("S1", substr($msg, 2, 2)); 
      		$amount = unpack("L1", substr($msg, 4, 4)); 
      		$ID = unpack("S1", substr($msg, 8, 2)); 
      		if (%{$storage{'inventory'}[$index]}) { 
         		$storage{'inventory'}[$index]{'amount'} += $amount; 
     	 	} else { 
         	$storage{'inventory'}[$index]{'nameID'} = $ID; 
         	$storage{'inventory'}[$index]{'amount'} = $amount; 
         	$display = ($items_lut{$ID} ne "") 
            		? $items_lut{$ID} 
            		: "Unknown ".$ID; 
         		$storage{'inventory'}[$index]{'name'} = $display; 
      		} 
      		print "Storage Item Added: $storage{'inventory'}[$index]{'name'} ($index) x $amount\n"; 

	} elsif ($switch eq "01C8") {
		my $index = unpack("S1",substr($msg, 2, 2));
		my $ID = substr($msg, 6, 4);
		my $itemType = unpack("S1", substr($msg, 4, 2));
		my $amountleft = unpack("S1",substr($msg, 10, 2));
		my $itemDisplay = ($items_lut{$itemType} ne "") 
			? $items_lut{$itemType}
			: "Unknown";

		if ($ID eq $accountID) {
			my $invIndex = findIndex(\@{$chars[$config{'char'}]{'inventory'}}, "index", $index);
			my $amount = $chars[$config{'char'}]{'inventory'}[$invIndex]{'amount'} - $amountleft;
			$chars[$config{'char'}]{'inventory'}[$invIndex]{'amount'} -= $amount;

			print "You used Item: $chars[$config{'char'}]{'inventory'}[$invIndex]{'name'} ($invIndex) x $amount\n";
			if ($chars[$config{'char'}]{'inventory'}[$invIndex]{'amount'} <= 0) {
				undef %{$chars[$config{'char'}]{'inventory'}[$invIndex]};
			}

		} elsif (%{$players{$ID}}) {
			print "Player $players{$ID}{'name'} ($players{$ID}{'binID'}) used Item: $itemDisplay - $amountleft left\n";

		} elsif (%{$monsters{$ID}}) {
			print "Monster $monsters{$ID}{'name'} ($monsters{$ID}{'binID'}) used Item: $itemDisplay - $amountleft left\n";

		} else {
			print "Unknown " . unpack("L*", $ID) . " used Item: $itemDisplay - $amountleft left\n";

		}


	} elsif ($switch eq "01D7") {

	} elsif ($switch eq "01D8" && length($msg) >= 52) {
		$ID = substr($msg, 2, 4);
		makeCoords(\%coords, substr($msg, 46, 3));
		$type = unpack("S*",substr($msg, 14,  2));
		$pet = unpack("C*",substr($msg, 16,  1));
		$sex = unpack("C*",substr($msg, 45,  1));
		$sitting = unpack("C*",substr($msg, 51,  1));
		if ($type >= 1000) {
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
				print "Pet Exists: $pets{$ID}{'name'} ($pets{$ID}{'binID'})\n" if ($config{'debug'});
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
				print "Monster Exists: $monsters{$ID}{'name'} ($monsters{$ID}{'binID'})\n" if ($config{'debug'});
			}

		} elsif ($jobs_lut{$type}) {
			if (!%{$players{$ID}}) {
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
			print "Player Exists: $players{$ID}{'name'} ($players{$ID}{'binID'}) $sex_lut{$players{$ID}{'sex'}} $jobs_lut{$players{$ID}{'jobID'}}\n" if ($config{'debug'});

		} elsif ($type == 45) {
			if (!%{$portals{$ID}}) {
				$portals{$ID}{'appear_time'} = time;
				$nameID = unpack("L1", $ID);
				$exists = portalExists($field{'name'}, \%coords);
				$display = ($exists ne "") 
					? "$portals_lut{$exists}{'source'}{'map'} -> $portals_lut{$exists}{'dest'}{'map'}"
					: "Unknown ".$nameID;
				binAdd(\@portalsID, $ID);
				$portals{$ID}{'source'}{'map'} = $field{'name'};
				$portals{$ID}{'type'} = $type;
				$portals{$ID}{'nameID'} = $nameID;
				$portals{$ID}{'name'} = $display;
				$portals{$ID}{'binID'} = binFind(\@portalsID, $ID);
			}
			%{$portals{$ID}{'pos'}} = %coords;
			print "Portal Exists: $portals{$ID}{'name'} - ($portals{$ID}{'binID'})\n";

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
			print "NPC Exists: $npcs{$ID}{'name'} - ($npcs{$ID}{'binID'})\n";

		} else {
			print "Unknown Exists: $type - ".unpack("L*",$ID)."\n" if $config{'debug'};
		}
      		
      		} elsif ($switch eq "01D9" && length($msg) >= 51) {
		$ID = substr($msg, 2, 4);
		makeCoords(\%coords, substr($msg, 46, 3));
		$type = unpack("S*",substr($msg, 14,  2));
		$sex = unpack("C*",substr($msg, 45,  1));
		if ($jobs_lut{$type}) {
			if (!%{$players{$ID}}) {
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
			print "Player Connected: $players{$ID}{'name'} ($players{$ID}{'binID'}) $sex_lut{$players{$ID}{'sex'}} $jobs_lut{$players{$ID}{'jobID'}}\n" if ($config{'debug'});

		} else {
			print "Unknown Connected: $type - ".getHex($ID)."\n" if $config{'debug'};
		}

	} elsif ($switch eq "01DA" && length($msg) >= 58) {
		$ID = substr($msg, 2, 4);
		makeCoords(\%coordsFrom, substr($msg, 50, 3));
		makeCoords2(\%coordsTo, substr($msg, 52, 3));
		$type = unpack("S*",substr($msg, 14,  2));
		$pet = unpack("C*",substr($msg, 16,  1));
		$sex = unpack("C*",substr($msg, 49,  1));
		if ($type >= 1000) {
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
					undef %{$monsters{$ID}};
				}
				print "Pet Moved: $pets{$ID}{'name'} ($pets{$ID}{'binID'})\n" if ($config{'debug'});
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
					print "Monster Appeared: $monsters{$ID}{'name'} ($monsters{$ID}{'binID'})\n" if $config{'debug'};
				}
				%{$monsters{$ID}{'pos'}} = %coordsFrom;
				%{$monsters{$ID}{'pos_to'}} = %coordsTo;
				print "Monster Moved: $monsters{$ID}{'name'} ($monsters{$ID}{'binID'})\n" if ($config{'debug'} >= 2);
			}
		} elsif ($jobs_lut{$type}) {
			if (!%{$players{$ID}}) {
				binAdd(\@playersID, $ID);
				$players{$ID}{'appear_time'} = time;
				$players{$ID}{'sex'} = $sex;
				$players{$ID}{'jobID'} = $type;
				$players{$ID}{'name'} = "Unknown";
				$players{$ID}{'nameID'} = unpack("L1", $ID);
				$players{$ID}{'binID'} = binFind(\@playersID, $ID);
				
				print "Player Appeared: $players{$ID}{'name'} ($players{$ID}{'binID'}) $sex_lut{$sex} $jobs_lut{$type}\n" if $config{'debug'};
			}
			%{$players{$ID}{'pos'}} = %coordsFrom;
			%{$players{$ID}{'pos_to'}} = %coordsTo;
			print "Player Moved: $players{$ID}{'name'} ($players{$ID}{'binID'}) $sex_lut{$players{$ID}{'sex'}} $jobs_lut{$players{$ID}{'jobID'}}\n" if ($config{'debug'} >= 2);
		} else {
			print "Unknown Moved: $type - ".getHex($ID)."\n" if $config{'debug'};
		}

	} elsif ($switch eq "01DC") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
		$secureLoginKey = substr($msg, 4, $msg_size);

	} elsif ($switch eq "01DE" && length($msg) >= 33) {
		$skillID = unpack("S1",substr($msg, 2, 2));
		$sourceID = substr($msg, 4, 4);
		$targetID = substr($msg, 8, 4);
		$damage = unpack("S1",substr($msg, 24, 2));
		$level = unpack("S1",substr($msg, 28, 2));

		undef $sourceDisplay;
		undef $targetDisplay;
		undef $extra;
		if (%{$spells{$sourceID}}) {
			$sourceID = $spells{$sourceID}{'sourceID'}
		}

		updateDamageTables($sourceID, $targetID, $damage) if ($damage != 35536);
		if (%{$monsters{$sourceID}}) {
			$sourceDisplay = "$monsters{$sourceID}{'name'} ($monsters{$sourceID}{'binID'}) uses";
		} elsif (%{$players{$sourceID}}) {
			$sourceDisplay = "$players{$sourceID}{'name'} ($players{$sourceID}{'binID'}) uses";
			
		} elsif ($sourceID eq $accountID) {
			$sourceDisplay = "You use";
			$chars[$config{'char'}]{'skills'}{$skills_rlut{lc($skillsID_lut{$skillID})}}{'time_used'} = time;
			undef $chars[$config{'char'}]{'time_cast'};
		} else {
			$sourceDisplay = "Unknown uses";
		}

		if (%{$monsters{$targetID}}) {
			$targetDisplay = "$monsters{$targetID}{'name'} ($monsters{$targetID}{'binID'})";
			if ($sourceID eq $accountID) {
				$monsters{$targetID}{'castOnByYou'}++;
			} else {
				$monsters{$targetID}{'castOnByPlayer'}{$sourceID}++;
			}
		} elsif (%{$players{$targetID}}) {
			$targetDisplay = "$players{$targetID}{'name'} ($players{$targetID}{'binID'})";
		} elsif ($targetID eq $accountID) {
			if ($sourceID eq $accountID) {
				$targetDisplay = "yourself";
			} else {
				$targetDisplay = "you";
			}
		} else {
			$targetDisplay = "unknown";
		}

		if ($damage == 35536) {
			$level_real = $level;
			print "$sourceDisplay $skillsID_lut{$skillID} (lvl $level)\n";
		} else {
			$damage = "Miss!" if (!$damage);
			if ($level == 65535) {
				print "$sourceDisplay $skillsID_lut{$skillID} on $targetDisplay$extra - Dmg: $damage\n";
			} else {
				$level = $level_real if ($level_real ne "");
				print "$sourceDisplay $skillsID_lut{$skillID} (lvl $level) on $targetDisplay$extra - Dmg: $damage\n";
			}
		}

	} elsif ($switch eq "08DC") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
	} elsif ($switch eq "0AEB") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
	} elsif ($switch eq "1009") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
	} elsif ($switch eq "1401") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
	} elsif ($switch eq "15DF") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
	} elsif ($switch eq "15F7") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
	} elsif ($switch eq "1641") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
	} elsif ($switch eq "16C1") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
	} elsif ($switch eq "1694") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
	} elsif ($switch eq "1700") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
	} elsif ($switch eq "1C00") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
	} elsif ($switch eq "3A00") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
	} elsif ($switch eq "4394") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
	} elsif ($switch eq "5900") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
	} elsif ($switch eq "5901") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
	} elsif ($switch eq "6EF3") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
	} elsif ($switch eq "7800") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
	} elsif ($switch eq "7801") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
	} elsif ($switch eq "7B01") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
	} elsif ($switch eq "7F01") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
	} elsif ($switch eq "8A01") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
	} elsif ($switch eq "9600") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
	} elsif ($switch eq "9601") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
	} elsif ($switch eq "A000") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
	} elsif ($switch eq "B000") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
	} elsif ($switch eq "B001") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
	} elsif ($switch eq "B103") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
	} elsif ($switch eq "B292") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
	} elsif ($switch eq "CA00") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
	} elsif ($switch eq "CA44") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
	} elsif ($switch eq "CAC0") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
	} elsif ($switch eq "CACC") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
	} elsif ($switch eq "CAE1") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
	} elsif ($switch eq "D900") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
	} elsif ($switch eq "F776") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
	} elsif ($switch eq "0000") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
	} elsif ($switch eq "0001") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
	} elsif ($switch eq "0005") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
	} elsif ($switch eq "000E") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
	} elsif ($switch eq "0014") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
	} elsif ($switch eq "001C") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
	} elsif ($switch eq "002A") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
	} elsif ($switch eq "00CF") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
	} elsif ($switch eq "01A6") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
	} elsif ($switch eq "01AD") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
	} elsif ($switch eq "01DC") {
		$msg_size = unpack("S1", substr($msg, 2, 2));
	} elsif (!$rpackets{$switch} && !existsInList($config{'debugPacket_exclude'}, $switch)) {
		print "Unparsed packet - $switch\n" if ($config{'debugPacket_received'});
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
# ai_clientSuspend($type, $initTimeout, @args...)
# $initTimeout: a number of seconds.
#
# Freeze the AI for $initTimeout seconds. $type and @args are ignored
# unless XKore mode is turned on, and are only used internally.
sub ai_clientSuspend {
	my ($type,$initTimeout,@args) = @_;
	my %args;
	$args{'type'} = $type;
	$args{'time'} = time;
	$args{'timeout'} = $initTimeout;
	@{$args{'args'}} = @args;
	unshift @ai_seq, "clientSuspend";
	unshift @ai_seq_args, \%args;
}

sub ai_follow {
	my $name = shift;
	my %args;
	$args{'name'} = $name; 
	unshift @ai_seq, "follow";
	unshift @ai_seq_args, \%args;
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

sub ai_getMonstersWhoHitMe {
	my @agMonsters;
	foreach (@monstersID) {
		next if ($_ eq "");
		if ($monsters{$_}{'dmgToYou'} > 0 && $monsters{$_}{'attack_failed'} <= 1) {
			push @agMonsters, $_;
		}
	}
	return @agMonsters;
}

sub ai_getSkillUseType {
	my $skill = shift;
	if ($skill eq "WZ_FIREPILLAR" || $skill eq "WZ_METEOR" 
		|| $skill eq "WZ_VERMILION" || $skill eq "WZ_STORMGUST" 
		|| $skill eq "WZ_HEAVENDRIVE" || $skill eq "WZ_QUAGMIRE" 
		|| $skill eq "MG_SAFETYWALL" || $skill eq "MG_FIREWALL" 
		|| $skill eq "MG_THUNDERSTORM") { 
		return 1;
	} else {
		return 0;
	}

}

##
# ai_itemExchangeCheck([$exchange])
#
# This is where most of the actual calculation for the item exchange is done.
# If $exchange equals "minimum", we only check that we can do
# one exchange (specified by itemExchange_minAmount_x in the config).
# Say we're making something that requires 3 pearls, 2 apples, and 8 empty bottles
# and we only want to go and make this item when we have at least 30 pearls, 20 apples, and 80 empty bottles
# what we would put into config.txt would be:
#
# itemExchange_item_0 Pearl
# itemExchange_amount_0 30
# itemExchange_minAmount_0 3
#
# itemExchange_item_1 Apple
# itemExchange_amount_1 20
# itemExchange_minAmount_1 2
#
# itemExchange_item_2 Empty bottle
# itemExchange_   etc etc etc
#
# If $exchange is not "minimum" it will look to see if we have at least 30 pearls,
# 20 apples, and 80 empty bottles (done very inelligently by cycling through your inventory, seeing if item names match
# what is in your config.txt, and if it does, seeing if the amount is greater than amount)
# if on the other hand you do a ai_itemExchangeCheck("minimum"), it does the same thing, except it compares the amounts
# to the minamount specified in config.txt
# maybe at some stage i'll modify it so you can make more than one item, but for now, meh
sub ai_itemExchangeCheck {
	my $exchange = $_[0];
	my $failed = 0;
	my $j = 0;

	while ($config{"itemExchange_item_$j"}) {
		last if ($failed);
		last if (!$config{"itemExchange_item_$j"} || !$config{"itemExchange_amount_$j"} || !config{"itemExchange_minAmount_$j"});
		my $amount;

		my $item = $config{"itemExchange_item_$j"};
		if ($exchange eq "minimum") {
			$amount = $config{"itemExchange_minAmount_$j"};
		} else {
			$amount = $config{"itemExchange_amount_$j"};
		}

		for (my $i = 0; $i < @{$chars[$config{'char'}]{'inventory'}}; $i++) {
			next if (!%{$chars[$config{'char'}]{'inventory'}[$i]} || $chars[$config{'char'}]{'inventory'}[$i]{'equipped'});

			if (lc($chars[$config{'char'}]{'inventory'}[$i]{'name'}) eq lc($item)
			    && $chars[$config{'char'}]{'inventory'}[$i]{'amount'} ne $amount) {
				$failed = 1;
				last;
			}
		}
		$j++;
	}

	return !$failed;
}

sub ai_mapRoute_getRoute {

	my %args;

	##VARS

	$args{'g_normal'} = 1;

	###
	
	my ($returnArray, $r_start_field, $r_start_pos, $r_dest_field, $r_dest_pos, $time_giveup) = @_;
	$args{'returnArray'} = $returnArray;
	$args{'r_start_field'} = $r_start_field;
	$args{'r_start_pos'} = $r_start_pos;
	$args{'r_dest_field'} = $r_dest_field;
	$args{'r_dest_pos'} = $r_dest_pos;
	$args{'time_giveup'}{'timeout'} = $time_giveup;
	$args{'time_giveup'}{'time'} = time;
	unshift @ai_seq, "route_getMapRoute";
	unshift @ai_seq_args, \%args;
}

sub ai_mapRoute_getSuccessors {
	my ($r_args, $r_array, $r_cur) = @_;
	my $ok;
	foreach (keys %portals_lut) {
		if ($portals_lut{$_}{'source'}{'map'} eq $$r_cur{'dest'}{'map'}

			&& !($$r_cur{'source'}{'map'} eq $portals_lut{$_}{'dest'}{'map'}
			&& $$r_cur{'source'}{'pos'}{'x'} == $portals_lut{$_}{'dest'}{'pos'}{'x'}
			&& $$r_cur{'source'}{'pos'}{'y'} == $portals_lut{$_}{'dest'}{'pos'}{'y'})

			&& !(%{$$r_cur{'parent'}} && $$r_cur{'parent'}{'source'}{'map'} eq $portals_lut{$_}{'dest'}{'map'}
			&& $$r_cur{'parent'}{'source'}{'pos'}{'x'} == $portals_lut{$_}{'dest'}{'pos'}{'x'}
			&& $$r_cur{'parent'}{'source'}{'pos'}{'y'} == $portals_lut{$_}{'dest'}{'pos'}{'y'})) {
			undef $ok;
			if (!%{$$r_cur{'parent'}}) {
				if (!$$r_args{'solutions'}{$$r_args{'start'}{'dest'}{'field'}.\%{$$r_args{'start'}{'dest'}{'pos'}}.\%{$portals_lut{$_}{'source'}{'pos'}}}{'solutionTried'}) {
					$$r_args{'solutions'}{$$r_args{'start'}{'dest'}{'field'}.\%{$$r_args{'start'}{'dest'}{'pos'}}.\%{$portals_lut{$_}{'source'}{'pos'}}}{'solutionTried'} = 1;
					$timeout{'ai_route_calcRoute'}{'time'} -= $timeout{'ai_route_calcRoute'}{'timeout'};
					$$r_args{'waitingForSolution'} = 1;
					ai_route_getRoute(\@{$$r_args{'solutions'}{$$r_args{'start'}{'dest'}{'field'}.\%{$$r_args{'start'}{'dest'}{'pos'}}.\%{$portals_lut{$_}{'source'}{'pos'}}}{'solution'}}, 
							$$r_args{'start'}{'dest'}{'field'}, \%{$$r_args{'start'}{'dest'}{'pos'}}, \%{$portals_lut{$_}{'source'}{'pos'}});
					last;
				}
				$ok = 1 if (@{$$r_args{'solutions'}{$$r_args{'start'}{'dest'}{'field'}.\%{$$r_args{'start'}{'dest'}{'pos'}}.\%{$portals_lut{$_}{'source'}{'pos'}}}{'solution'}});
			} elsif ($portals_los{$$r_cur{'dest'}{'ID'}}{$portals_lut{$_}{'source'}{'ID'}} ne "0"
				&& $portals_los{$portals_lut{$_}{'source'}{'ID'}}{$$r_cur{'dest'}{'ID'}} ne "0") {
				$ok = 1;
			}
			if ($$r_args{'dest'}{'source'}{'pos'}{'x'} ne "" && $portals_lut{$_}{'dest'}{'map'} eq $$r_args{'dest'}{'source'}{'map'}) {
				if (!$$r_args{'solutions'}{$$r_args{'dest'}{'source'}{'field'}.\%{$portals_lut{$_}{'dest'}{'pos'}}.\%{$$r_args{'dest'}{'source'}{'pos'}}}{'solutionTried'}) {
					$$r_args{'solutions'}{$$r_args{'dest'}{'source'}{'field'}.\%{$portals_lut{$_}{'dest'}{'pos'}}.\%{$$r_args{'dest'}{'source'}{'pos'}}}{'solutionTried'} = 1;
					$timeout{'ai_route_calcRoute'}{'time'} -= $timeout{'ai_route_calcRoute'}{'timeout'};
					$$r_args{'waitingForSolution'} = 1;
					ai_route_getRoute(\@{$$r_args{'solutions'}{$$r_args{'dest'}{'source'}{'field'}.\%{$portals_lut{$_}{'dest'}{'pos'}}.\%{$$r_args{'dest'}{'source'}{'pos'}}}{'solution'}}, 
							$$r_args{'dest'}{'source'}{'field'}, \%{$portals_lut{$_}{'dest'}{'pos'}}, \%{$$r_args{'dest'}{'source'}{'pos'}});
					last;
				}
			}
			push @{$r_array}, \%{$portals_lut{$_}} if $ok;
		}
	}
}

sub ai_mapRoute_searchStep {
	my $r_args = shift;
	my @successors;
	my $r_cur, $r_suc;
	my $i;

	###check if failed
	if (!@{$$r_args{'openList'}}) {
		#failed!
		$$r_args{'done'} = 1;
		return;
	}
	
	$r_cur = shift @{$$r_args{'openList'}};

	###check if finished
	if ($$r_args{'dest'}{'source'}{'map'} eq $$r_cur{'dest'}{'map'}
		&& (@{$$r_args{'solutions'}{$$r_args{'dest'}{'source'}{'field'}.\%{$$r_cur{'dest'}{'pos'}}.\%{$$r_args{'dest'}{'source'}{'pos'}}}{'solution'}}
		|| $$r_args{'dest'}{'source'}{'pos'}{'x'} eq "")) {
		do {
			unshift @{$$r_args{'solutionList'}}, {%{$r_cur}};
			$r_cur = $$r_cur{'parent'} if (%{$$r_cur{'parent'}});
		} while ($r_cur != \%{$$r_args{'start'}});
		$$r_args{'done'} = 1;
		return;
	}

	ai_mapRoute_getSuccessors($r_args, \@successors, $r_cur);
	if ($$r_args{'waitingForSolution'}) {
		undef $$r_args{'waitingForSolution'};
		unshift @{$$r_args{'openList'}}, $r_cur;
		return;
	}

	$newg = $$r_cur{'g'} + $$r_args{'g_normal'};
	foreach $r_suc (@successors) {
		undef $found;
		undef $openFound;
		undef $closedFound;
		for($i = 0; $i < @{$$r_args{'openList'}}; $i++) {
			if ($$r_suc{'dest'}{'map'} eq $$r_args{'openList'}[$i]{'dest'}{'map'}
				&& $$r_suc{'dest'}{'pos'}{'x'} == $$r_args{'openList'}[$i]{'dest'}{'pos'}{'x'}
				&& $$r_suc{'dest'}{'pos'}{'y'} == $$r_args{'openList'}[$i]{'dest'}{'pos'}{'y'}) {
				if ($newg >= $$r_args{'openList'}[$i]{'g'}) {
					$found = 1;
					}
				$openFound = $i;
				last;
			}
		}
		next if ($found);
		
		undef $found;
		for($i = 0; $i < @{$$r_args{'closedList'}}; $i++) {
			if ($$r_suc{'dest'}{'map'} eq $$r_args{'closedList'}[$i]{'dest'}{'map'}
				&& $$r_suc{'dest'}{'pos'}{'x'} == $$r_args{'closedList'}[$i]{'dest'}{'pos'}{'x'}
				&& $$r_suc{'dest'}{'pos'}{'y'} == $$r_args{'closedList'}[$i]{'dest'}{'pos'}{'y'}) {
				if ($newg >= $$r_args{'closedList'}[$i]{'g'}) {
					$found = 1;
				}
				$closedFound = $i;
				last;
			}
		}
		next if ($found);
		if ($openFound ne "") {
			binRemoveAndShiftByIndex(\@{$$r_args{'openList'}}, $openFound);
		}
		if ($closedFound ne "") {
			binRemoveAndShiftByIndex(\@{$$r_args{'closedList'}}, $closedFound);
		}
		$$r_suc{'g'} = $newg;
		$$r_suc{'h'} = 0;
		$$r_suc{'f'} = $$r_suc{'g'} + $$r_suc{'h'};
		$$r_suc{'parent'} = $r_cur;
		minHeapAdd(\@{$$r_args{'openList'}}, $r_suc, "f");
	}
	push @{$$r_args{'closedList'}}, $r_cur;
}

sub ai_items_take {
	my ($x1, $y1, $x2, $y2) = @_;
	my %args;
	$args{'pos'}{'x'} = $x1;
	$args{'pos'}{'y'} = $y1;
	$args{'pos_to'}{'x'} = $x2;
	$args{'pos_to'}{'y'} = $y2;
	$args{'ai_items_take_end'}{'time'} = time;
	$args{'ai_items_take_end'}{'timeout'} = $timeout{'ai_items_take_end'}{'timeout'};
	$args{'ai_items_take_start'}{'time'} = time;
	$args{'ai_items_take_start'}{'timeout'} = $timeout{'ai_items_take_start'}{'timeout'};
	unshift @ai_seq, "items_take";
	unshift @ai_seq_args, \%args;
}

sub ai_route {
	my ($r_ret, $x, $y, $map, $maxRouteDistance, $maxRouteTime, $attackOnRoute, $avoidPortals, $distFromGoal, $checkInnerPortals, $attackID) = @_;
	my %args;
#Solos Start
	my $pos_x;
	my $pos_y;
	$pos_x = int($chars[$config{'char'}]{'pos_to'}{'x'}) if ($chars[$config{'char'}]{'pos_to'}{'x'} ne "");
	$pos_y = int($chars[$config{'char'}]{'pos_to'}{'y'}) if ($chars[$config{'char'}]{'pos_to'}{'y'} ne "");
#Solos End
	$x = int($x) if ($x ne "");
	$y = int($y) if ($y ne "");
	$args{'returnHash'} = $r_ret;
	$args{'dest_x'} = $x;
	$args{'dest_y'} = $y;
	$args{'dest_map'} = $map;
	$args{'maxRouteDistance'} = $maxRouteDistance;
	$args{'maxRouteTime'} = $maxRouteTime;
	$args{'attackOnRoute'} = $attackOnRoute;
	$args{'avoidPortals'} = $avoidPortals;
	$args{'distFromGoal'} = $distFromGoal;
	$args{'checkInnerPortals'} = $checkInnerPortals;
	$args{'attackID'} = $attackID;
	undef %{$args{'returnHash'}};
	unshift @ai_seq, "route";
	unshift @ai_seq_args, \%args;
	print "On route to: $maps_lut{$map.'.rsw'}($map): $x, $y\n" if $config{'debug'};
#Solos Start
#if kore is stuck
	if (($old_x == $x) && ($old_y == $y)) {
		$calcTo_SameSpot++;
	} else {
		$calcTo_SameSpot = 0;
		$old_x = $x;
		$old_y = $y;
	}
	if ($calcTo_SameSpot >= 10) {
		$calcTo_SameSpot = 0;
		Unstuck("Cannot find destination, trying to unstuck ...\n");
	}

	if (($old_pos_x == $pos_x) && ($old_pos_y == $pos_y)) {
		$calcFrom_SameSpot++;
	} else {
		$calcFrom_SameSpot = 0;
		$old_pos_x = $pos_x;
		$old_pos_y = $pos_y;
	}
	if ($calcFrom_SameSpot >= 10) {
		$calcFrom_SameSpot = 0;
		Unstuck("Invalid original position, trying to unstuck ...\n");
	}	

	if ($totalStuckCount >= 10) {
		RespawnUnstuck();
	}	
#Solos End
}

sub ai_route_getDiagSuccessors {
	my $r_args = shift;
	my $r_pos = shift;
	my $r_array = shift;
	my $type = shift;
	my %pos;

	if (ai_route_getMap($r_args, $$r_pos{'x'}-1, $$r_pos{'y'}-1) == $type
		&& !($$r_pos{'parent'} && $$r_pos{'parent'}{'x'} == $$r_pos{'x'}-1 && $$r_pos{'parent'}{'y'} == $$r_pos{'y'}-1)) {
		$pos{'x'} = $$r_pos{'x'}-1;
		$pos{'y'} = $$r_pos{'y'}-1;
		push @{$r_array}, {%pos};
	}

	if (ai_route_getMap($r_args, $$r_pos{'x'}+1, $$r_pos{'y'}-1) == $type
		&& !($$r_pos{'parent'} && $$r_pos{'parent'}{'x'} == $$r_pos{'x'}+1 && $$r_pos{'parent'}{'y'} == $$r_pos{'y'}-1)) {
		$pos{'x'} = $$r_pos{'x'}+1;
		$pos{'y'} = $$r_pos{'y'}-1;
		push @{$r_array}, {%pos};
	}	

	if (ai_route_getMap($r_args, $$r_pos{'x'}+1, $$r_pos{'y'}+1) == $type
		&& !($$r_pos{'parent'} && $$r_pos{'parent'}{'x'} == $$r_pos{'x'}+1 && $$r_pos{'parent'}{'y'} == $$r_pos{'y'}+1)) {
		$pos{'x'} = $$r_pos{'x'}+1;
		$pos{'y'} = $$r_pos{'y'}+1;
		push @{$r_array}, {%pos};
	}	

		
	if (ai_route_getMap($r_args, $$r_pos{'x'}-1, $$r_pos{'y'}+1) == $type
		&& !($$r_pos{'parent'} && $$r_pos{'parent'}{'x'} == $$r_pos{'x'}-1 && $$r_pos{'parent'}{'y'} == $$r_pos{'y'}+1)) {
		$pos{'x'} = $$r_pos{'x'}-1;
		$pos{'y'} = $$r_pos{'y'}+1;
		push @{$r_array}, {%pos};
	}	
}

sub ai_route_getMap {
	my $r_args = shift;
	my $x = shift;
	my $y = shift;
	if($x < 0 || $x >= $$r_args{'field'}{'width'} || $y < 0 || $y >= $$r_args{'field'}{'height'}) {
		return 1;	 
	}
	return $$r_args{'field'}{'field'}[($y*$$r_args{'field'}{'width'})+$x];
}

sub ai_route_getRoute {
	my %args;
	my ($returnArray, $r_field, $r_start, $r_dest, $time_giveup) = @_;
	$args{'returnArray'} = $returnArray;
	$args{'field'} = $r_field;
	%{$args{'start'}} = %{$r_start};
	%{$args{'dest'}} = %{$r_dest};
	$args{'time_giveup'}{'timeout'} = $time_giveup;
	$args{'time_giveup'}{'time'} = time;
	$args{'destroyFunction'} = \&ai_route_getRoute_destroy;
	undef @{$args{'returnArray'}};
	unshift @ai_seq, "route_getRoute";
	unshift @ai_seq_args, \%args;
}

sub ai_route_getRoute_destroy {
	my $r_args = shift;
	if (!$config{'buildType'}) {
		$CalcPath_destroy->Call($$r_args{'session'}) if ($$r_args{'session'} ne "");;
	} elsif ($config{'buildType'} == 1) {
		&{$CalcPath_destroy}($$r_args{'session'}) if ($$r_args{'session'} ne "");;
	}
}

sub ai_route_searchStep {
	my $r_args = shift;
	my $ret;

	if (!$$r_args{'initialized'}) {
		#####
		my $SOLUTION_MAX = 5000;
		$$r_args{'solution'} = "\0" x ($SOLUTION_MAX*4+4);
		#####
		if (!$config{'buildType'}) {
			$$r_args{'session'} = $CalcPath_init->Call($$r_args{'solution'},
				$$r_args{'field'}{'rawMap'}, $$r_args{'field'}{'width'}, $$r_args{'field'}{'height'}, 
				pack("S*",$$r_args{'start'}{'x'}, $$r_args{'start'}{'y'}), pack("S*",$$r_args{'dest'}{'x'}, $$r_args{'dest'}{'y'}), $$r_args{'timeout'});
		} elsif ($config{'buildType'} == 1) {
			$$r_args{'session'} = &{$CalcPath_init}($$r_args{'solution'},
				$$r_args{'field'}{'rawMap'}, $$r_args{'field'}{'width'}, $$r_args{'field'}{'height'}, 
				pack("S*",$$r_args{'start'}{'x'}, $$r_args{'start'}{'y'}), pack("S*",$$r_args{'dest'}{'x'}, $$r_args{'dest'}{'y'}), $$r_args{'timeout'});

		}
	}
	if ($$r_args{'session'} < 0) {
		$$r_args{'done'} = 1;
		return;
	}
	$$r_args{'initialized'} = 1;
	if (!$config{'buildType'}) {
		$ret = $CalcPath_pathStep->Call($$r_args{'session'});
	} elsif ($config{'buildType'} == 1) {
		$ret = &{$CalcPath_pathStep}($$r_args{'session'});
	}
	if (!$ret) {
		my $size = unpack("L",substr($$r_args{'solution'},0,4));
		my $j = 0;
		my $i;
		for ($i = ($size-1)*4+4; $i >= 4;$i-=4) {
			$$r_args{'returnArray'}[$j]{'x'} = unpack("S",substr($$r_args{'solution'}, $i, 2));
			$$r_args{'returnArray'}[$j]{'y'} = unpack("S",substr($$r_args{'solution'}, $i+2, 2));
			$j++;
		}
		$$r_args{'done'} = 1;
	}
}

sub ai_route_getSuccessors {
	my $r_args = shift;
	my $r_pos = shift;
	my $r_array = shift;
	my $type = shift;
	my %pos;
	
	if (ai_route_getMap($r_args, $$r_pos{'x'}-1, $$r_pos{'y'}) == $type
		&& !($$r_pos{'parent'} && $$r_pos{'parent'}{'x'} == $$r_pos{'x'}-1 && $$r_pos{'parent'}{'y'} == $$r_pos{'y'})) {
		$pos{'x'} = $$r_pos{'x'}-1;
		$pos{'y'} = $$r_pos{'y'};
		push @{$r_array}, {%pos};
	}

	if (ai_route_getMap($r_args, $$r_pos{'x'}, $$r_pos{'y'}-1) == $type
		&& !($$r_pos{'parent'} && $$r_pos{'parent'}{'x'} == $$r_pos{'x'} && $$r_pos{'parent'}{'y'} == $$r_pos{'y'}-1)) {
		$pos{'x'} = $$r_pos{'x'};
		$pos{'y'} = $$r_pos{'y'}-1;
		push @{$r_array}, {%pos};
	}	

	if (ai_route_getMap($r_args, $$r_pos{'x'}+1, $$r_pos{'y'}) == $type
		&& !($$r_pos{'parent'} && $$r_pos{'parent'}{'x'} == $$r_pos{'x'}+1 && $$r_pos{'parent'}{'y'} == $$r_pos{'y'})) {
		$pos{'x'} = $$r_pos{'x'}+1;
		$pos{'y'} = $$r_pos{'y'};
		push @{$r_array}, {%pos};
	}	

		
	if (ai_route_getMap($r_args, $$r_pos{'x'}, $$r_pos{'y'}+1) == $type
		&& !($$r_pos{'parent'} && $$r_pos{'parent'}{'x'} == $$r_pos{'x'} && $$r_pos{'parent'}{'y'} == $$r_pos{'y'}+1)) {
		$pos{'x'} = $$r_pos{'x'};
		$pos{'y'} = $$r_pos{'y'}+1;
		push @{$r_array}, {%pos};
	}	
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
	$ai_v{'portalTrace_mapChanged'} = 1;
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
	$args{'ai_skill_use_giveup'}{'time'} = time;
	$args{'ai_skill_use_giveup'}{'timeout'} = $timeout{'ai_skill_use_giveup'}{'timeout'};
	$args{'skill_use_id'} = $ID;
	$args{'skill_use_lv'} = $lv;
	$args{'skill_use_maxCastTime'}{'time'} = time;
	$args{'skill_use_maxCastTime'}{'timeout'} = $maxCastTime;
	$args{'skill_use_minCastTime'}{'time'} = time;
	$args{'skill_use_minCastTime'}{'timeout'} = $minCastTime;
	if ($y eq "") {
		$args{'skill_use_target'} = $target;
	} else {
		$args{'skill_use_target_x'} = $target;
		$args{'skill_use_target_y'} = $y;
	}
	unshift @ai_seq, "skill_use";
	unshift @ai_seq_args, \%args;
}

#storageAuto for items_control - chobit andy 20030210
sub ai_storageAutoCheck {
	for ($i = 0; $i < @{$chars[$config{'char'}]{'inventory'}};$i++) {
		next if (!%{$chars[$config{'char'}]{'inventory'}[$i]} || $chars[$config{'char'}]{'inventory'}[$i]{'equipped'});
		if ($items_control{lc($chars[$config{'char'}]{'inventory'}[$i]{'name'})}{'storage'}
			&& $chars[$config{'char'}]{'inventory'}[$i]{'amount'} > $items_control{lc($chars[$config{'char'}]{'inventory'}[$i]{'name'})}{'keep'}) {
			return 1;
		}
	}
}

sub attack {
	my $ID = shift;
	my %args;
	$args{'ai_attack_giveup'}{'time'} = time;
	$args{'ai_attack_giveup'}{'timeout'} = $timeout{'ai_attack_giveup'}{'timeout'};
	$args{'ID'} = $ID;
	%{$args{'pos_to'}} = %{$monsters{$ID}{'pos_to'}};
	%{$args{'pos'}} = %{$monsters{$ID}{'pos'}};
	unshift @ai_seq, "attack";
	unshift @ai_seq_args, \%args;
	print "Attacking: $monsters{$ID}{'name'} ($monsters{$ID}{'binID'})\n";
	injectMessage("Attacking: $monsters{$ID}{'name'} ($monsters{$ID}{'binID'})") if ($config{'verbose'} && $config{'XKore'});

	$startedattack = 1;
	if ($config{"monsterCount"}) {	
		$i = 0;
		while ($config{"monsterCount_mon_$i"} ne "") {
			if ($config{"monsterCount_mon_$i"} eq $monsters{$ID}{'name'}) {
				$monsters_killed[$i] = $monsters_killed[$i] + 1;
			}
			$i++;
		}
	}

	if ($config{"autoSwitch"}) {
		$i = 0;
		$is_mon = 0;
		while ($config{"autoSwitch_mon_$i"} ne "") {
#		if ($config{"autoSwitch_weapon_mon_$i"} eq $monsters{$ID}{'name'}) {
       			if (existsInList($config{"autoSwitch_mon_$i"}, $monsters{$ID}{'name'})) {
	        		print "Auto-Switching for this monster : ".$monsters{$ID}{'name'}."\n";
				$eq_weap = findIndexString_lc(\@{$chars[$config{'char'}]{'inventory'}}, "name", $config{"autoSwitch_weapon_new_$i"});
				$eq_shield = findIndexString_lc(\@{$chars[$config{'char'}]{'inventory'}}, "name", $config{"autoSwitch_shield_new_$i"});
				$is_mon = 1;
				if (($eq_weap ne "") && !($chars[$config{'char'}]{'inventory'}[$eq_weap]{'equipped'})) {
					print "Equiping :".$config{"autoSwitch_weapon_new_$i"}."\n";
					sendEquip(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$eq_weap]{'index'}, $chars[$config{'char'}]{'inventory'}[$eq_weap]{'type_equip'}, 0);
				}
         			if (($eq_shield ne "") && !($chars[$config{'char'}]{'inventory'}[$eq_shield]{'equipped'})) {
            				print "Equiping :".$config{"autoSwitch_shield_new_$i"}."\n";
            				sendEquip(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$eq_shield]{'index'}, $chars[$config{'char'}]{'inventory'}[$eq_shield]{'type_equip'}, 32, 0);
         			}
				last;
			}
			$i++;
		}
		if (($is_mon == 0) && ($config{"autoSwitch_weapon_def"} ne "")) {
			$eq_weap = findIndexString_lc(\@{$chars[$config{'char'}]{'inventory'}}, "name", $config{"autoSwitch_weapon_def"});
			if (($eq_weap ne "") && !($chars[$config{'char'}]{'inventory'}[$eq_weap]{'equipped'})) {
				print "Equiping :".$config{"autoSwitch_weapon_def"}."\n";
				sendEquip(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$eq_weap]{'index'}, $chars[$config{'char'}]{'inventory'}[$eq_weap]{'type_equip'}, 0);
			}
		}
   		if (($is_mon == 0) && ($config{"autoSwitch_shield_def"} ne "")) {
      			$eq_shield = findIndexString_lc(\@{$chars[$config{'char'}]{'inventory'}}, "name", $config{"autoSwitch_shield_def"});
      			if (($eq_shield ne "") && !($chars[$config{'char'}]{'inventory'}[$eq_shield]{'equipped'})) {
         			print "Equiping :".$config{"autoSwitch_shield_def"}."\n";
         			sendEquip(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$eq_shield]{'index'}, 32, 0);
      			}
   		}
	}
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
	$args{'ai_items_gather_giveup'}{'time'} = time;
	$args{'ai_items_gather_giveup'}{'timeout'} = $timeout{'ai_items_gather_giveup'}{'timeout'};
	$args{'ID'} = $ID;
	%{$args{'pos'}} = %{$items{$ID}{'pos'}};
	unshift @ai_seq, "items_gather";
	unshift @ai_seq_args, \%args;
	print "Targeting for Gather: $items{$ID}{'name'} ($items{$ID}{'binID'})\n" if $config{'debug'};
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
	my $triggeredByRoute = shift;
	my $attackID = shift;
	my %args;
#Solos Start
	my $pos_x;
	my $pos_y;
	$pos_x = int($chars[$config{'char'}]{'pos_to'}{'x'}) if ($chars[$config{'char'}]{'pos_to'}{'x'} ne "");
	$pos_y = int($chars[$config{'char'}]{'pos_to'}{'y'}) if ($chars[$config{'char'}]{'pos_to'}{'y'} ne "");
#Solos End
	$args{'move_to'}{'x'} = $x;
	$args{'move_to'}{'y'} = $y;
	$args{'triggeredByRoute'} = $triggeredByRoute;
	$args{'attackID'} = $attackID;
	$args{'ai_move_giveup'}{'time'} = time;
	$args{'ai_move_giveup'}{'timeout'} = $timeout{'ai_move_giveup'}{'timeout'};
	unshift @ai_seq, "move";
	unshift @ai_seq_args, \%args;
#Solos Start
#if kore is stuck
	if (($move_x == $x) && ($move_y == $y)) {
		$moveTo_SameSpot++;
	} else {
		$moveTo_SameSpot = 0;
		$move_x = $x;
		$move_y = $y;
	}
	if ($moveTo_SameSpot == 20) {
		ClearRouteAI("Keep trying to move to same spot, clearing route AI to unstuck ...\n");
	}
	if ($moveTo_SameSpot >= 50) {
		$moveTo_SameSpot = 0;
		Unstuck("Keep trying to move to same spot, teleporting to unstuck ...\n");
	}

	if (($move_pos_x == $pos_x) && ($move_pos_y == $pos_y)) {
		$moveFrom_SameSpot++;
	} else {
		$moveFrom_SameSpot = 0;
		$move_pos_x = $pos_x;
		$move_pos_y = $pos_y;
	}
	if ($moveFrom_SameSpot == 20) {
		ClearRouteAI("Keep trying to move from same spot, clearing route AI to unstuck ...\n");
	}
	if ($moveFrom_SameSpot >= 50) {
		$moveFrom_SameSpot = 0;
		Unstuck("Keep trying to move from same spot, teleport to unstuck ...\n");
	}											    

	if ($totalStuckCount >= 10) {
		RespawnUnstuck();
	}	
#Solos End
}

sub quit {
	$quit = 1;
	print "Exiting...\n";
}

sub relog {
	$conState = 1;
	undef $conState_tries;
	$timeout_ex{'master'}{'time'} = time;
	$timeout_ex{'master'}{'timeout'} = 5;
	killConnection(\$remote_socket);
	print "Relogging in 5 seconds...\n";
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
	$timeout{'ai_sit_wait'}{'time'} = time;
	unshift @ai_seq, "sitting";
	unshift @ai_seq_args, {};
}

sub stand {
	unshift @ai_seq, "standing";
	unshift @ai_seq_args, {};
}

sub take {
	my $ID = shift;
	my %args;
	$args{'ai_take_giveup'}{'time'} = time;
	$args{'ai_take_giveup'}{'timeout'} = $timeout{'ai_take_giveup'}{'timeout'};
	$args{'ID'} = $ID;
	%{$args{'pos'}} = %{$items{$ID}{'pos'}};
	unshift @ai_seq, "take";
	unshift @ai_seq_args, \%args;
	print "Targeting for Pickup: $items{$ID}{'name'} ($items{$ID}{'binID'})\n" if $config{'debug'};
}

#######################################
#######################################
#AI MATH
#######################################
#######################################


sub distance {
	my $r_hash1 = shift;
	my $r_hash2 = shift;
	my %line;
	if ($r_hash2) {
		$line{'x'} = abs($$r_hash1{'x'} - $$r_hash2{'x'});
		$line{'y'} = abs($$r_hash1{'y'} - $$r_hash2{'y'});
	} else {
		%line = %{$r_hash1};
	}
	return sqrt($line{'x'} ** 2 + $line{'y'} ** 2);
}

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
	my $x1, $x2, $x3, $x4, $y1, $y2, $y3, $y4, $result, $result1, $result2;
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
#CONFIG MODIFIERS
#######################################
#######################################

sub auth {
	my $user = shift;
	my $flag = shift;
	if ($flag) {
		print "Authorized user '$user' for admin\n";
	} else {
		print "Revoked admin privilages for user '$user'\n";
	}	
	$overallAuth{$user} = $flag;
	writeDataFile("control/overallAuth.txt", \%overallAuth);
}

sub configModify {
	my $key = shift;
	my $val = shift;
	my $quiet = shift;
	print "Config '$key' set to $val\n" unless ($quiet);
	$config{$key} = $val;
	writeDataFileIntact($config_file, \%config);
}

sub setTimeout {
	my $timeout = shift;
	my $time = shift;
	$timeout{$timeout}{'timeout'} = $time;
	print "Timeout '$timeout' set to $time\n";
	writeDataFileIntact2("control/timeouts.txt", \%timeout);
}


#######################################
#######################################
#OUTGOING PACKET FUNCTIONS
#######################################
#######################################

sub decrypt {
	my $r_msg = shift;
	my $themsg = shift;
	my @mask;
	my $i;
	my ($temp, $msg_temp, $len_add, $len_total, $loopin, $len, $val);
	if ($config{'encrypt'} == 1) {
		undef $$r_msg;
		undef $len_add;
		undef $msg_temp;
		for ($i = 0; $i < 13;$i++) {
			$mask[$i] = 0;
		}
		$len = unpack("S1",substr($themsg,0,2));
		$val = unpack("S1",substr($themsg,2,2));
		{
			use integer;
			$temp = ($val * $val * 1391);
		}
		$temp = ~(~($temp));
		$temp = $temp % 13;
		$mask[$temp] = 1;
		{
			use integer;
			$temp = $val * 1397;
		}
		$temp = ~(~($temp));
		$temp = $temp % 13;
		$mask[$temp] = 1;
		for($loopin = 0; ($loopin + 4) < $len; $loopin++) {
 			if (!($mask[$loopin % 13])) {
  				$msg_temp .= substr($themsg,$loopin + 4,1);
			}
		}
		if (($len - 4) % 8 != 0) {
			$len_add = 8 - (($len - 4) % 8);
		}
		$len_total = $len + $len_add;
		$$r_msg = $msg_temp.substr($themsg, $len_total, length($themsg) - $len_total);
	} elsif ($config{'encrypt'} >= 2) {
		undef $$r_msg;
		undef $len_add;
		undef $msg_temp;
		for ($i = 0; $i < 17;$i++) {
			$mask[$i] = 0;
		}
		$len = unpack("S1",substr($themsg,0,2));
		$val = unpack("S1",substr($themsg,2,2));
		{
			use integer;
			$temp = ($val * $val * 34953);
		}
		$temp = ~(~($temp));
		$temp = $temp % 17;
		$mask[$temp] = 1;
		{
			use integer;
			$temp = $val * 2341;
		}
		$temp = ~(~($temp));
		$temp = $temp % 17;
		$mask[$temp] = 1;
		for($loopin = 0; ($loopin + 4) < $len; $loopin++) {
 			if (!($mask[$loopin % 17])) {
  				$msg_temp .= substr($themsg,$loopin + 4,1);
			}
		}
		if (($len - 4) % 8 != 0) {
			$len_add = 8 - (($len - 4) % 8);
		}
		$len_total = $len + $len_add;
		$$r_msg = $msg_temp.substr($themsg, $len_total, length($themsg) - $len_total);
	} else {
		$$r_msg = $themsg;
	}
}

sub encrypt {
	my $r_msg = shift;
	my $themsg = shift;
	my @mask;
	my $newmsg;
	my ($in, $out);
	if ($config{'encrypt'} == 1 && $conState >= 5) {
		$out = 0;
		undef $newmsg;
		for ($i = 0; $i < 13;$i++) {
			$mask[$i] = 0;
		}
		{
			use integer;
			$temp = ($encryptVal * $encryptVal * 1391);
		}
		$temp = ~(~($temp));
		$temp = $temp % 13;
		$mask[$temp] = 1;
		{
			use integer;
			$temp = $encryptVal * 1397;
		}
		$temp = ~(~($temp));
		$temp = $temp % 13;
		$mask[$temp] = 1;
		for($in = 0; $in < length($themsg); $in++) {
			if ($mask[$out % 13]) {
				$newmsg .= pack("C1", int(rand() * 255) & 0xFF);
				$out++;
			}
			$newmsg .= substr($themsg, $in, 1);
			$out++;
		}
		$out += 4;
		$newmsg = pack("S2", $out, $encryptVal) . $newmsg;
		while ((length($newmsg) - 4) % 8 != 0) {
			$newmsg .= pack("C1", (rand() * 255) & 0xFF);
		}
	} elsif ($config{'encrypt'} >= 2 && $conState >= 5) {
		$out = 0;
		undef $newmsg;
		for ($i = 0; $i < 17;$i++) {
			$mask[$i] = 0;
		}
		{
			use integer;
			$temp = ($encryptVal * $encryptVal * 34953);
		}
		$temp = ~(~($temp));
		$temp = $temp % 17;
		$mask[$temp] = 1;
		{
			use integer;
			$temp = $encryptVal * 2341;
		}
		$temp = ~(~($temp));
		$temp = $temp % 17;
		$mask[$temp] = 1;
		for($in = 0; $in < length($themsg); $in++) {
			if ($mask[$out % 17]) {
				$newmsg .= pack("C1", int(rand() * 255) & 0xFF);
				$out++;
			}
			$newmsg .= substr($themsg, $in, 1);
			$out++;
		}
		$out += 4;
		$newmsg = pack("S2", $out, $encryptVal) . $newmsg;
		while ((length($newmsg) - 4) % 8 != 0) {
			$newmsg .= pack("C1", (rand() * 255) & 0xFF);
		}
	} else {
		$newmsg = $themsg;
	}

	$$r_msg = $newmsg;
}

sub injectMessage {
	my $message = shift;
	my $name = "|";
	my $msg .= $name . " : " . $message . chr(0);
	encrypt(\$msg, $msg);
	$msg = pack("C*",0x09, 0x01) . pack("S*", length($name) + length($message) + 12) . pack("C*",0,0,0,0) . $msg;
	encrypt(\$msg, $msg);
	sendToClientByInject(\$remote_socket, $msg);
}

sub injectAdminMessage {
	my $message = shift;
	$msg = pack("C*",0x9A, 0x00) . pack("S*", length($message)+5) . $message .chr(0);
	encrypt(\$msg, $msg);
	sendToClientByInject(\$remote_socket, $msg);
}

sub sendAddSkillPoint {
	my $r_socket = shift;
	my $skillID = shift;
	my $msg = pack("C*", 0x12, 0x01) . pack("S*", $skillID);
	sendMsgToServer($r_socket, $msg);
}

sub sendAddStatusPoint {
	my $r_socket = shift;
	my $statusID = shift;
	my $msg = pack("C*", 0xBB, 0) . pack("S*", $statusID) . pack("C*", 0x01);
	sendMsgToServer($r_socket, $msg);
}

sub sendAlignment {
	my $r_socket = shift;
	my $ID = shift;
	my $alignment = shift;
	my $msg = pack("C*", 0x49, 0x01) . $ID . pack("C*", $alignment);
	sendMsgToServer($r_socket, $msg);
	print "Sent Alignment: ".getHex($ID).", $alignment\n" if ($config{'debug'} >= 2);
}

sub sendAttack {
	my $r_socket = shift;
	my $monID = shift;
	my $flag = shift;
	my $msg = pack("C*", 0x89, 0x00) . $monID . pack("C*", $flag);
	sendMsgToServer($r_socket, $msg);
	print "Sent attack: ".getHex($monID)."\n" if ($config{'debug'} >= 2);
}

sub sendAttackStop {
	my $r_socket = shift;
	#my $msg = pack("C*", 0x18, 0x01);
	# Apparently this packet is wrong. The server disconnects us if we do this.
	# Sending a move command to the current position seems to be able to emulate
	# what this function is supposed to do.
	sendMove ($r_socket, $chars[$config{'char'}]{'pos_to'}{'x'}, $chars[$config{'char'}]{'pos_to'}{'y'});
	print "Sent stop attack\n" if $config{'debug'};
}

sub sendBuy {
	my $r_socket = shift;
	my $ID = shift;
	my $amount = shift;
	my $msg = pack("C*", 0xC8, 0x00, 0x08, 0x00) . pack("S*", $amount, $ID);
	sendMsgToServer($r_socket, $msg);
	print "Sent buy: ".getHex($ID)."\n" if ($config{'debug'} >= 2);
}

sub sendBuyVender {
	my $r_socket = shift;
	my $ID = shift;
	my $amount = shift;
	my $msg = pack("C*", 0x34, 0x01, 0x0C, 0x00) . $venderID . pack("S*", $amount, $ID);
	sendMsgToServer($r_socket, $msg);
	print "Sent Vender Buy: ".getHex($ID)."\n" if ($config{'debug'} >= 2);
}

sub sendCartAdd {  
	my $r_socket = shift;  
	my $index = shift;  
	my $amount = shift;
	my $msg = pack("C*", 0x26, 0x01) . pack("S*", $index) . pack("L*", $amount); 
	sendMsgToServer($r_socket, $msg);  
	print "Sent Cart Add: $index x $amount\n" if ($config{'debug'} >= 2);
}

sub sendCartGet {  
	my $r_socket = shift;  
	my $index = shift;  
	my $amount = shift;
	my $msg = pack("C*", 0x27, 0x01) . pack("S*", $index) . pack("L*", $amount); 
	sendMsgToServer($r_socket, $msg);  
	print "Sent Cart Get: $index x $amount\n" if ($config{'debug'} >= 2);
}

sub sendCharLogin {
	my $r_socket = shift;
	my $char = shift;
	my $msg = pack("C*", 0x66,0) . pack("C*",$char);
	sendMsgToServer($r_socket, $msg);
}

sub sendChat {
	my $r_socket = shift;
	my $message = shift;
	my $msg = pack("C*",0x8C, 0x00) . pack("S*", length($chars[$config{'char'}]{'name'}) + length($message) + 8) . 
		$chars[$config{'char'}]{'name'} . " : " . $message . chr(0);
	sendMsgToServer($r_socket, $msg);
}

sub sendChatRoomBestow {
	my $r_socket = shift;
	my $name = shift;
	$name = substr($name, 0, 24) if (length($name) > 24);
	$name = $name . chr(0) x (24 - length($name));
	my $msg = pack("C*", 0xE0, 0x00, 0x00, 0x00, 0x00, 0x00).$name;
	sendMsgToServer($r_socket, $msg);
	print "Sent Chat Room Bestow: $name\n" if ($config{'debug'} >= 2);
}

sub sendChatRoomChange {
	my $r_socket = shift;
	my $title = shift;
	my $limit = shift;
	my $public = shift;
	my $password = shift;
	$password = substr($password, 0, 8) if (length($password) > 8);
	$password = $password . chr(0) x (8 - length($password));
	my $msg = pack("C*", 0xDE, 0x00).pack("S*", length($title) + 15, $limit).pack("C*",$public).$password.$title;
	sendMsgToServer($r_socket, $msg);
	print "Sent Change Chat Room: $title, $limit, $public, $password\n" if ($config{'debug'} >= 2);
}

sub sendChatRoomCreate {
	my $r_socket = shift;
	my $title = shift;
	my $limit = shift;
	my $public = shift;
	my $password = shift;
	$password = substr($password, 0, 8) if (length($password) > 8);
	$password = $password . chr(0) x (8 - length($password));
	my $msg = pack("C*", 0xD5, 0x00).pack("S*", length($title) + 15, $limit).pack("C*",$public).$password.$title;
	sendMsgToServer($r_socket, $msg);
	print "Sent Create Chat Room: $title, $limit, $public, $password\n" if ($config{'debug'} >= 2);
}

sub sendChatRoomJoin {
	my $r_socket = shift;
	my $ID = shift;
	my $password = shift;
	$password = substr($password, 0, 8) if (length($password) > 8);
	$password = $password . chr(0) x (8 - length($password));
	my $msg = pack("C*", 0xD9, 0x00).$ID.$password;
	sendMsgToServer($r_socket, $msg);
	print "Sent Join Chat Room: ".getHex($ID)." $password\n" if ($config{'debug'} >= 2);
}

sub sendChatRoomKick {
	my $r_socket = shift;
	my $name = shift;
	$name = substr($name, 0, 24) if (length($name) > 24);
	$name = $name . chr(0) x (24 - length($name));
	my $msg = pack("C*", 0xE2, 0x00).$name;
	sendMsgToServer($r_socket, $msg);
	print "Sent Chat Room Kick: $name\n" if ($config{'debug'} >= 2);
}

sub sendChatRoomLeave {
	my $r_socket = shift;
	my $msg = pack("C*", 0xE3, 0x00);
	sendMsgToServer($r_socket, $msg);
	print "Sent Leave Chat Room\n" if ($config{'debug'} >= 2);
}

sub sendCloseShop {
	my $r_socket = shift;
	my $msg = pack("C*", 0x2E, 0x01);
	sendMsgToServer($r_socket, $msg);
	print "Shop Closed: $index x $amount\n" if ($config{'debug'} >= 2);
	$shopstarted = 0;
	$timeout{'ai_shop'}{'time'} = time;
}

sub sendCurrentDealCancel {
	my $r_socket = shift;
	my $msg = pack("C*", 0xED, 0x00);
	sendMsgToServer($r_socket, $msg);
	print "Sent Cancel Current Deal\n" if ($config{'debug'} >= 2);
}

sub sendDeal {
	my $r_socket = shift;
	my $ID = shift;
	my $msg = pack("C*", 0xE4, 0x00) . $ID;
	sendMsgToServer($r_socket, $msg);
	print "Sent Initiate Deal: ".getHex($ID)."\n" if ($config{'debug'} >= 2);
}

sub sendDealAccept {
	my $r_socket = shift;
	my $msg = pack("C*", 0xE6, 0x00, 0x03);
	sendMsgToServer($r_socket, $msg);
	print "Sent Accept Deal\n" if ($config{'debug'} >= 2);
}

sub sendDealAddItem {
	my $r_socket = shift;
	my $index = shift;
	my $amount = shift;
	my $msg = pack("C*", 0xE8, 0x00) . pack("S*", $index) . pack("L*",$amount);	
	sendMsgToServer($r_socket, $msg);
	print "Sent Deal Add Item: $index, $amount\n" if ($config{'debug'} >= 2);
}

sub sendDealCancel {
	my $r_socket = shift;
	my $msg = pack("C*", 0xE6, 0x00, 0x04);
	sendMsgToServer($r_socket, $msg);
	print "Sent Cancel Deal\n" if ($config{'debug'} >= 2);
}

sub sendDealFinalize {
	my $r_socket = shift;
	my $msg = pack("C*", 0xEB, 0x00);
	sendMsgToServer($r_socket, $msg);
	print "Sent Deal OK\n" if ($config{'debug'} >= 2);
}

sub sendDealOK {
	my $r_socket = shift;
	my $msg = pack("C*", 0xEB, 0x00);
	sendMsgToServer($r_socket, $msg);
	print "Sent Deal OK\n" if ($config{'debug'} >= 2);
}

sub sendDealTrade {
	my $r_socket = shift;
	my $msg = pack("C*", 0xEF, 0x00);
	sendMsgToServer($r_socket, $msg);
	print "Sent Deal Trade\n" if ($config{'debug'} >= 2);
}

sub sendDrop {
	my $r_socket = shift;
	my $index = shift;
	my $amount = shift;
	my $msg = pack("C*", 0xA2, 0x00) . pack("S*", $index, $amount);
	sendMsgToServer($r_socket, $msg);
	print "Sent drop: $index x $amount\n" if ($config{'debug'} >= 2);
}

sub sendEmotion {
	my $r_socket = shift;
	my $ID = shift;
	my $msg = pack("C*", 0xBF, 0x00).pack("C1",$ID);
	sendMsgToServer($r_socket, $msg);
	print "Sent Emotion\n" if ($config{'debug'} >= 2);
}

sub sendEnteringVender {
	my $r_socket = shift;
	my $ID = shift;
	my $msg = pack("C*", 0x30, 0x01) . $ID;
	sendMsgToServer($r_socket, $msg);
	print "Sent Entering Vender: ".getHex($ID)."\n" if ($config{'debug'} >= 2);
}

sub sendEquip{
	my $r_socket = shift;
	my $index = shift;
	my $type = shift;
	my $masktype = shift;
	my $msg = pack("C*", 0xA9, 0x00) . pack("S*", $index) .  pack("C*", $type, $masktype);
	sendMsgToServer($r_socket, $msg);
	print "Sent Equip: $index\n" if ($config{'debug'} >= 2);
}

sub sendGameLogin {
	my $r_socket = shift;
	my $accountID = shift;
	my $sessionID = shift;
	my $sex = shift;
	my $msg = pack("C*", 0x65,0) . $accountID . $sessionID . pack("C*", 0,0,0,0,0,0,$sex);
	sendMsgToServer($r_socket, $msg);
}

sub sendGetPlayerInfo {
	my $r_socket = shift;
	my $ID = shift;
	my $msg = pack("C*", 0x94, 0x00) . $ID;
	sendMsgToServer($r_socket, $msg);
	print "Sent get player info: ID - ".getHex($ID)."\n" if ($config{'debug'} >= 2);
}

sub sendGetStoreList {
	my $r_socket = shift;
	my $ID = shift;
	my $msg = pack("C*", 0xC5, 0x00) . $ID . pack("C*",0x00);
	sendMsgToServer($r_socket, $msg);
	print "Sent get store list: ".getHex($ID)."\n" if ($config{'debug'} >= 2);
}

sub sendGetSellList {
	my $r_socket = shift;
	my $ID = shift;
	my $msg = pack("C*", 0xC5, 0x00) . $ID . pack("C*",0x01);
	sendMsgToServer($r_socket, $msg);
	print "Sent sell to NPC: ".getHex($ID)."\n" if ($config{'debug'} >= 2);
}

sub sendGuildAlly{
	my $r_socket = shift;
	my $ID = shift;
	my $flag = shift;
	my $msg = pack("C*", 0x72, 0x01).$ID.pack("L1", $flag);
	sendMsgToServer($r_socket, $msg);
	print "Sent Ally Guild : ".getHex($ID).", $flag\n" if ($config{'debug'});
}

sub sendGuildChat {
	my $r_socket = shift;
	my $message = shift;
	my $msg = pack("C*",0x7E, 0x01) . pack("S*",length($chars[$config{'char'}]{'name'}) + length($message) + 8) .
	$chars[$config{'char'}]{'name'} . " : " . $message . chr(0);
	sendMsgToServer($r_socket, $msg);
}

sub sendGuildInfoRequest {
	my $r_socket = shift;
	my $msg = pack("C*", 0x4d, 0x01);
	sendMsgToServer($r_socket, $msg);
	print "Sent Guild Information Request\n" if ($config{'debug'});
}

sub sendGuildJoin{
	my $r_socket = shift;
	my $ID = shift;
	my $flag = shift;
	my $msg = pack("C*", 0x6B, 0x01).$ID.pack("L1", $flag);
	sendMsgToServer($r_socket, $msg);
	print "Sent Join Guild : ".getHex($ID).", $flag\n" if ($config{'debug'});
}

sub sendGuildMemberNameRequest {
	my $r_socket = shift;
	my $ID = shift;
	my $msg = pack("C*", 0x93, 0x01) . $ID;
	sendMsgToServer($r_socket, $msg);
	print "Sent Guild Member Name Request : ".getHex($ID)."\n" if ($config{'debug'} >= 2);
}

sub sendGuildRequest {
	my $r_socket = shift;
	my $page = shift;
	my $msg = pack("C*", 0x4f, 0x01).pack("L1", $page);
	sendMsgToServer($r_socket, $msg);
	print "Sent Guild Request Page : ".$page."\n" if ($config{'debug'});
}

sub sendIdentify {
	my $r_socket = shift;
	my $index = shift;
	my $msg = pack("C*", 0x78, 0x01) . pack("S*", $index);
	sendMsgToServer($r_socket, $msg);
	print "Sent Identify: $index\n" if ($config{'debug'} >= 2);
}

sub sendIgnore {
	my $r_socket = shift;
	my $name = shift;
	my $flag = shift;
	$name = substr($name, 0, 24) if (length($name) > 24);
	$name = $name . chr(0) x (24 - length($name));
	my $msg = pack("C*", 0xCF, 0x00).$name.pack("C*", $flag);
	sendMsgToServer($r_socket, $msg);
	print "Sent Ignore: $name, $flag\n" if ($config{'debug'} >= 2);
}

sub sendIgnoreAll { 
	my $r_socket = shift; 
	my $flag = shift; 
	my $msg = pack("C*", 0xD0, 0x00).pack("C*", $flag); 
	sendMsgToServer($r_socket, $msg); 
	print "Sent Ignore All: $flag\n" if ($config{'debug'} >= 2); 
}

#sendGetIgnoreList - chobit 20021223 
sub sendIgnoreListGet {  
	my $r_socket = shift;  
	my $flag = shift;  
	my $msg = pack("C*", 0xD3, 0x00);  
	sendMsgToServer($r_socket, $msg); 
	print "Sent get Ignore List: $flag\n" if ($config{'debug'} >= 2);
}

sub sendItemUse {
	my $r_socket = shift;
	my $ID = shift;
	my $targetID = shift;
	my $msg = pack("C*", 0xA7, 0x00).pack("S*",$ID).$targetID;
	sendMsgToServer($r_socket, $msg);
	print "Item Use: $ID\n" if ($config{'debug'} >= 2);
}

sub sendLook {
	my $r_socket = shift;
	my $body = shift;
	my $head = shift;
	my $msg = pack("C*", 0x9B, 0x00, $head, 0x00, $body);
	sendMsgToServer($r_socket, $msg);
	print "Sent look: $body $head\n" if ($config{'debug'} >= 2);
	$chars[$config{'char'}]{'look'}{'head'} = $head;
	$chars[$config{'char'}]{'look'}{'body'} = $body;
}

sub sendMapLoaded {
	my $r_socket = shift;
	my $msg = pack("C*", 0x7D,0x00);
	print "Sending Map Loaded\n" if $config{'debug'};
	sendMsgToServer($r_socket, $msg);
}

sub sendMapLogin {
	my $r_socket = shift;
	my $accountID = shift;
	my $charID = shift;
	my $sessionID = shift;
	my $sex = shift;
	my $msg = pack("C*", 0x72,0) . $accountID . $charID . $sessionID . pack("L1", getTickCount()) . pack("C*",$sex);
	sendMsgToServer($r_socket, $msg);
}

sub sendMasterCodeRequest {
	my $r_socket = shift;
	my $msg = pack("C*", 0xDB, 0x01);
	sendMsgToServer($r_socket, $msg);
}

sub sendMasterLogin {
	my $r_socket = shift;
	my $username = shift;
	my $password = shift;
	my $msg = pack("C*", 0x64,0,$config{'version'},0,0,0) . $username . chr(0) x (24 - length($username)) . 
			$password . chr(0) x (24 - length($password)) . pack("C*", $config{"master_version_$config{'master'}"});
	sendMsgToServer($r_socket, $msg);
}

sub sendMasterSecureLogin {
	my $r_socket = shift;
	my $username = shift;
	my $password = shift;
	my $salt = shift;

	if ($config{'secure'} == 1) {
		$salt = $salt . $password;
	} else {
		$salt = $password . $salt;
	}
	my $msg = pack("C*", 0xDD, 0x01) . pack("L1", $config{'version'}) . $username . chr(0) x (24 - length($username)) .
	md5($salt) . pack("C*", $config{"master_version_$config{'master'}"});
	sendMsgToServer($r_socket, $msg);
}

sub sendMemo {
	my $r_socket = shift;
	my $msg = pack("C*", 0x1D, 0x01);
	sendMsgToServer($r_socket, $msg);
	print "Sent Memo\n" if ($config{'debug'} >= 2);
}

sub sendMove {
	my $r_socket = shift;
	my $x = shift;
	my $y = shift;
	my $msg = pack("C*", 0x85, 0x00) . getCoordString($x, $y);
	sendMsgToServer($r_socket, $msg);
	print "Sent move to: $x, $y\n" if ($config{'debug'} >= 2);
}

sub sendOpenShop {
	my $r_socket = shift;
	my ($i, $index, $totalitem, $items_selling, $citem, $oldid);
	my %itemtosell;

	$shopstarted = 0;
	if ($chars[$config{'char'}]{'skills'}{'MC_VENDING'}{'lv'}) {
		if ($shop{'shop_title'} eq "") {
			print "Cannot open shop: you must specify a title for your shop.\n";
			return 0;
		}

		$i = 0;
		$items_selling = 0;
		while ($shop{"name_$i"} ne "" && $items_selling < $chars[$config{'char'}]{'skills'}{'MC_VENDING'}{'lv'} + 2) {
			for ($index = 0; $index < @cartID; $index++) {
				if ($cart{'inventory'}{$cartID[$index]}{'name'} eq $shop{"name_$i"}) {
					$citem = $index;
					foreach (keys %itemtosell) {
						if ($_ eq $index) {
							$oldid = $_;
							$citem = -1;
						}
					}

					if ($citem >- 1) {
						$itemtosell{$index}{'index'} = $cart{'inventory'}{$cartID[$index]}{'index'};

						# Calculate amount
						if ($shop{"quantity_$i"} > 0 && $cart{'inventory'}{$cartID[$index]}{'amount'} >= $shop{"quantity_$i"}) {
							$itemtosell{$index}{'amount'} = $shop{"quantity_$i"};
						} elsif ($shop{"quantity_$i"} > 0 && $cart{'inventory'}{$cartID[$index]}{'amount'} < $shop{"quantity_$i"}) {
							$itemtosell{$index}{'amount'} = $cart{'inventory'}{$cartID[$index]}{'amount'};
						} else {
							$itemtosell{$index}{'amount'} = $cart{'inventory'}{$cartID[$index]}{'amount'};
						}

						# Calculate price
						if ($shop{"price_$i"} > 10000000) {
							$itemtosell{$index}{'price'} = 10000000;
						} elsif ($shop{"price_$i"} > 0) {
							$itemtosell{$index}{'price'} = $shop{"price_$i"};
						} else {
							$itemtosell{$index}{'price'} = 1;
						}
						$items_selling++;
						last;
					}
				}
			}
			$i++;
		}

		if (!$items_selling) {
			print "Cannot open shop: no items to sell.\n";
			return 0;
		}

		my $length = 0x55 + 0x08 * $items_selling;

		my $msg = pack("C*", 0xB2, 0x01) . pack("S*", $length) . 
		$shop{'shop_title'} . chr(0) x (80 - length($shop{'shop_title'})) .  pack("C*", 0x01);

		foreach (keys %itemtosell) {
			$msg .= pack("S1",$itemtosell{$_}{'index'}) . pack("S1", $itemtosell{$_}{'amount'}) . pack("L1", $itemtosell{$_}{'price'});
		}
		if(length($msg) == $length) {
			sendMsgToServer($r_socket, $msg);
			print "Shop opened ($shop{'shop_title'}) with $items_selling items.\n";
			$shopstarted = 1;
			return 1;
		} else {
			print "Unknown error while opening shop.\n";
			return 0;
		}
	} else {
		print "Cannot open shop: you don't have the Vending skill.\n";
		return 0;
	}
}

sub sendPartyChat {
	my $r_socket = shift;
	my $message = shift;
	my $msg = pack("C*",0x08, 0x01) . pack("S*",length($chars[$config{'char'}]{'name'}) + length($message) + 8) . 
		$chars[$config{'char'}]{'name'} . " : " . $message . chr(0);
	sendMsgToServer($r_socket, $msg);
}

sub sendPartyJoin {
	my $r_socket = shift;
	my $ID = shift;
	my $flag = shift;
	my $msg = pack("C*", 0xFF, 0x00).$ID.pack("L", $flag);
	sendMsgToServer($r_socket, $msg);
	print "Sent Join Party: ".getHex($ID).", $flag\n" if ($config{'debug'} >= 2);
}

sub sendPartyJoinRequest {
	my $r_socket = shift;
	my $ID = shift;
	my $msg = pack("C*", 0xFC, 0x00).$ID;
	sendMsgToServer($r_socket, $msg);
	print "Sent Request Join Party: ".getHex($ID)."\n" if ($config{'debug'} >= 2);
}

sub sendPartyKick {
	my $r_socket = shift;
	my $ID = shift;
	my $name = shift;
	$name = substr($name, 0, 24) if (length($name) > 24);
	$name = $name . chr(0) x (24 - length($name));
	my $msg = pack("C*", 0x03, 0x01).$ID.$name;
	sendMsgToServer($r_socket, $msg);
	print "Sent Kick Party: ".getHex($ID).", $name\n" if ($config{'debug'} >= 2);
}

sub sendPartyLeave {
	my $r_socket = shift;
	my $msg = pack("C*", 0x00, 0x01);
	sendMsgToServer($r_socket, $msg);
	print "Sent Leave Party: $name\n" if ($config{'debug'} >= 2);
}

sub sendPartyOrganize {
	my $r_socket = shift;
	my $name = shift;
	$name = substr($name, 0, 24) if (length($name) > 24);
	$name = $name . chr(0) x (24 - length($name));
	my $msg = pack("C*", 0xF9, 0x00).$name;
	sendMsgToServer($r_socket, $msg);
	print "Sent Organize Party: $name\n" if ($config{'debug'} >= 2);
}

sub sendPartyShareEXP {
	my $r_socket = shift;
	my $flag = shift;
	my $msg = pack("C*", 0x02, 0x01).pack("L", $flag);
	sendMsgToServer($r_socket, $msg);
	print "Sent Party Share: $flag\n" if ($config{'debug'} >= 2);
}

sub sendQuit {
	my $r_socket = shift;
	my $msg = pack("C*", 0x8A, 0x01, 0x00, 0x00);
	sendMsgToServer($r_socket, $msg);
	print "Sent Quit\n" if ($config{'debug'} >= 2);
}

sub sendRaw {
	my $r_socket = shift;
	my $raw = shift;
	my @raw;
	my $msg;
	@raw = split / /, $raw;
	foreach (@raw) {
		$msg .= pack("C", hex($_));
	}
	sendMsgToServer($r_socket, $msg);
	print "Sent Raw Packet: @raw\n" if ($config{'debug'} >= 2);
}

sub sendRespawn {
	my $r_socket = shift;
	my $msg = pack("C*", 0xB2, 0x00, 0x00);
	sendMsgToServer($r_socket, $msg);
	print "Sent Respawn\n" if ($config{'debug'} >= 2);
}

sub sendPrivateMsg {
	my $r_socket = shift;
	my $user = shift;
	my $message = shift;
	my $msg = pack("C*",0x96, 0x00) . pack("S*",length($message) + 29) . $user . chr(0) x (24 - length($user)) .
			$message . chr(0);
	sendMsgToServer($r_socket, $msg);
}

sub sendSell {
	my $r_socket = shift;
	my $index = shift;
	my $amount = shift;
	my $msg = pack("C*", 0xC9, 0x00, 0x08, 0x00) . pack("S*", $index, $amount);
	sendMsgToServer($r_socket, $msg);
	print "Sent sell: $index x $amount\n" if ($config{'debug'} >= 2);
	
}

sub sendSit {
	my $r_socket = shift;
	my $msg = pack("C*", 0x89,0x00, 0x00, 0x00, 0x00, 0x00, 0x02);
	sendMsgToServer($r_socket, $msg);
	print "Sitting\n" if ($config{'debug'} >= 2);
}

sub sendSkillUse {
	my $r_socket = shift;
	my $ID = shift;
	my $lv = shift;
	my $targetID = shift;
	my $msg = pack("C*", 0x13, 0x01).pack("S*",$lv,$ID).$targetID;
	sendMsgToServer($r_socket, $msg);
	print "Skill Use: $ID\n" if ($config{'debug'} >= 2);
}

sub sendSkillUseLoc {
	my $r_socket = shift;
	my $ID = shift;
	my $lv = shift;
	my $x = shift;
	my $y = shift;
	my $msg = pack("C*", 0x16, 0x01).pack("S*",$lv,$ID,$x,$y);
	sendMsgToServer($r_socket, $msg);
	print "Skill Use Loc: $ID\n" if ($config{'debug'} >= 2);
}

sub sendStorageAdd {
	my $r_socket = shift;
	my $index = shift;
	my $amount = shift;
	my $msg = pack("C*", 0xF3, 0x00) . pack("S*", $index) . pack("L*", $amount);
	sendMsgToServer($r_socket, $msg);
	print "Sent Storage Add: $index x $amount\n" if ($config{'debug'} >= 2);	
}

sub sendStorageClose {
	my $r_socket = shift;
	my $msg = pack("C*", 0xF7, 0x00);
	sendMsgToServer($r_socket, $msg);
	print "Sent Storage Done\n" if ($config{'debug'} >= 2);
}

sub sendStorageGet {
	my $r_socket = shift;
	my $index = shift;
	my $amount = shift;
	my $msg = pack("C*", 0xF5, 0x00) . pack("S*", $index) . pack("L*", $amount);
	sendMsgToServer($r_socket, $msg);
	print "Sent Storage Get: $index x $amount\n" if ($config{'debug'} >= 2);	
}

sub sendStand {
	my $r_socket = shift;
	my $msg = pack("C*", 0x89,0x00, 0x00, 0x00, 0x00, 0x00, 0x03);
	sendMsgToServer($r_socket, $msg);
	print "Standing\n" if ($config{'debug'} >= 2);
}

sub sendSync {
	my $r_socket = shift;
	my $time = shift;
	my $msg = pack("C*", 0x7E, 0x00) . pack("L1", $time);
	sendMsgToServer($r_socket, $msg);
	print "Sent Sync: $time\n" if ($config{'debug'} >= 2);
}

sub sendSyncInject {
	my $r_socket = shift;
	$$r_socket->send("K".pack("S", 0)) if $$r_socket && $$r_socket->connected();
}

sub sendTake {
	my $r_socket = shift;
	my $itemID = shift;
	my $msg = pack("C*", 0x9F, 0x00) . $itemID;
	sendMsgToServer($r_socket, $msg);
	print "Sent take\n" if ($config{'debug'} >= 2);
}

sub sendTalk {
	my $r_socket = shift;
	my $ID = shift;
	my $msg = pack("C*", 0x90, 0x00) . $ID . pack("C*",0x01);
	sendMsgToServer($r_socket, $msg);
	print "Sent talk: ".getHex($ID)."\n" if ($config{'debug'} >= 2);
}

sub sendTalkCancel {
	my $r_socket = shift;
	my $ID = shift;
	my $msg = pack("C*", 0x46, 0x01) . $ID;
	sendMsgToServer($r_socket, $msg);
	print "Sent talk cancel: ".getHex($ID)."\n" if ($config{'debug'} >= 2);
}

sub sendTalkContinue {
	my $r_socket = shift;
	my $ID = shift;
	my $msg = pack("C*", 0xB9, 0x00) . $ID;
	sendMsgToServer($r_socket, $msg);
	print "Sent talk continue: ".getHex($ID)."\n" if ($config{'debug'} >= 2);
}

sub sendTalkResponse {
	my $r_socket = shift;
	my $ID = shift;
	my $response = shift;
	my $msg = pack("C*", 0xB8, 0x00) . $ID. pack("C1",$response);
	sendMsgToServer($r_socket, $msg);
	print "Sent talk respond: ".getHex($ID).", $response\n" if ($config{'debug'} >= 2);
}

sub sendTeleport {
	my $r_socket = shift;
	my $location = shift;
	$location = substr($location, 0, 16) if (length($location) > 16);
	$location .= chr(0) x (16 - length($location));
	my $msg = pack("C*", 0x1B, 0x01, 0x1A, 0x00) . $location;
	sendMsgToServer($r_socket, $msg);
	print "Sent Teleport: $location\n" if ($config{'debug'} >= 2);
}

sub sendToClientByInject {
	my $r_socket = shift;
	my $msg = shift;
	$$r_socket->send("R".pack("S", length($msg)).$msg) if $$r_socket && $$r_socket->connected();
}

sub sendToServerByInject {
	my $r_socket = shift;
	my $msg = shift;
	$$r_socket->send("S".pack("S", length($msg)).$msg) if $$r_socket && $$r_socket->connected();
}

sub sendMsgToServer {
	my $r_socket = shift;
	my $msg = shift;
	return if (!$$r_socket || !$$r_socket->connected());
	encrypt(\$msg, $msg);
	if ($config{'XKore'}) {
		sendToServerByInject(\$remote_socket, $msg);
	} else {
		$$r_socket->send($msg) if ($$r_socket && $$r_socket->connected());
	}

	my $switch = uc(unpack("H2", substr($msg, 1, 1))) . uc(unpack("H2", substr($msg, 0, 1)));
	print "Packet Switch SENT: $switch\n" if ($config{'debugPacket_sent'} && !existsInList($config{'debugPacket_exclude'}, $switch));
}

sub sendUnequip{
	my $r_socket = shift;
	my $index = shift;
	my $msg = pack("C*", 0xAB, 0x00) . pack("S*", $index);
	sendMsgToServer($r_socket, $msg);
	print "Sent Unequip: $index\n" if ($config{'debug'} >= 2);
}

sub sendWho {
	my $r_socket = shift;
	my $msg = pack("C*", 0xC1, 0x00);
	sendMsgToServer($r_socket, $msg);
	print "Sent Who\n" if ($config{'debug'} >= 2);
}




#######################################
#######################################
#CONNECTION FUNCTIONS
#######################################
#######################################


sub connection {
	my $r_socket = shift;
	my $host = shift;
	my $port = shift;
	print "Connecting ($host:$port)... ";
	$$r_socket = IO::Socket::INET->new(
			PeerAddr	=> $host,
			PeerPort	=> $port,
			Proto		=> 'tcp',
			Timeout		=> 4);
	($$r_socket && inet_aton($$r_socket->peerhost()) eq inet_aton($host)) ? print "connected\n" : print "couldn't connect\n";
}

sub dataWaiting {
	my $r_fh = shift;
	my $bits;
	vec($bits,fileno($$r_fh),1)=1;
	return (select($bits,$bits,$bits,0.05) > 1);
}

sub input_client {
	my ($input, $switch);
	my $msg;
	my $local_socket;
	my ($addrcheck, $portcheck, $hostcheck);
	my ($host, $port);

	print "Spawning Input Socket...\n";
	$host = $input_server_socket->sockhost();
	$port = $input_server_socket->sockport();
	my $pid = fork();
	if ($pid == 0) {
		$local_socket = IO::Socket::INET->new(
				PeerAddr	=> $host,
				PeerPort	=> $port,
				Proto		=> 'tcp');
		($local_socket) || die "Error creating connection to local server: $!";
		while (1) {
			$input = <STDIN>;
			last if (!defined($input));
			chomp $input;
			($switch) = $input =~ /^(\w*)/;
			if ($input ne "") {
				$local_socket->send($input);
			}
			last if ($input eq "quit" || $input eq "dump");
		}
		close($local_socket);
		exit;
	} else {
		$input_socket = $input_server_socket->accept();
		(inet_aton($input_socket->peerhost()) == inet_aton('localhost')) 
		|| die "Input Socket must be connected from localhost";
		print "Input Socket connected\n";
		return $pid;
	}
}

sub killConnection {
	my $r_socket = shift;
	if ($$r_socket && $$r_socket->connected()) {
		print "Disconnecting (".$$r_socket->peerhost().":".$$r_socket->peerport().")... ";
		sendQuit($r_socket);
		close($$r_socket);
		!$$r_socket->connected() ? print "disconnected\n" : print "couldn't disconnect\n";
	}
}





#######################################
#######################################
#FILE PARSING AND WRITING
#######################################
#######################################

sub addParseFiles {
	my $file = shift;
	my $hash = shift;
	my $function = shift;
	$parseFiles[$parseFiles]{'file'} = $file;
	$parseFiles[$parseFiles]{'hash'} = $hash;
	$parseFiles[$parseFiles]{'function'} = $function;
	$parseFiles++;
}

sub chatLog {
	$type = shift;
	$message = shift;
	open CHAT, ">> $chat_file";
	print CHAT "[".getFormattedDate(int(time))."][".uc($type)."] $message";
	close CHAT;
}

sub itemLog {
	$crud = shift;
	return if (!$config{'itemHistory'});
	open ITEMLOG, ">> $item_log_file";
	print ITEMLOG "[".getFormattedDate(int(time))."] $crud";
	close ITEMLOG;
}

sub itemLog_clear { 
	if (-e $item_log_file) { unlink($item_log_file); } 
}

sub chatLog_clear { 
	if (-e $chat_file) { unlink($chat_file); } 
}

sub convertGatField {
	my $file = shift;
	my $r_hash = shift;
	my $i;
	open FILE, "+> $file";
	binmode(FILE);
	print FILE pack("S*", $$r_hash{'width'}, $$r_hash{'height'});
	for ($i = 0; $i < @{$$r_hash{'field'}}; $i++) {
		print FILE pack("C1", $$r_hash{'field'}[$i]);
	}
	close FILE;
}

sub dumpData {
	my $msg = shift;
	my $dump;
	my $i;
	$dump = "\n\n================================================\n".getFormattedDate(int(time))."\n\n".length($msg)." bytes\n\n";
	for ($i=0; $i + 15 < length($msg);$i += 16) {
		$dump .= getHex(substr($msg,$i,8))."    ".getHex(substr($msg,$i+8,8))."\n";
	}
	if (length($msg) - $i > 8) {
		$dump .= getHex(substr($msg,$i,8))."    ".getHex(substr($msg,$i+8,length($msg) - $i - 8))."\n";
	} elsif (length($msg) > 0) {
		$dump .= getHex(substr($msg,$i,length($msg) - $i))."\n";
	}
	open DUMP, ">> DUMP.txt";
	print DUMP $dump;
	close DUMP;
	print "$dump\n" if $config{'debug'} >= 2;
	print "Message Dumped into DUMP.txt!\n";
}

sub getField {
	my $file = shift;
	my $r_hash = shift;
	my $i, $data;
	undef %{$r_hash};
	if (!(-e $file)) {
		print "\n!!Could not load field - you must install the kore-field pack!!\n\n";
	}
	if ($file =~ /\//) {
		($$r_hash{'name'}) = $file =~ /\/([\s\S]*)\./;
	} else {
		($$r_hash{'name'}) = $file =~ /([\s\S]*)\./;
	}
	open FILE, $file;
	binmode(FILE);
	read(FILE, $data, 4);
	my $width = unpack("S1", substr($data, 0,2));
	my $height = unpack("S1", substr($data, 2,2));
	$$r_hash{'width'} = $width;
	$$r_hash{'height'} = $height;
	while (read(FILE, $data, 1)) {
		$$r_hash{'field'}[$i] = unpack("C",$data);
		$$r_hash{'rawMap'} .= $data;
		$i++;
	}
	close FILE;
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
		$$r_hash{'field'}[$i] = unpack("C1", substr($data, 14,1));
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

sub load {
	my $r_array = shift;
	
	foreach (@{$r_array}) {
		if (-e $$_{'file'}) {
			print "Loading $$_{'file'}...\n";
		} else {
			print "Error: Couldn't load $$_{'file'}\n";
		}
		&{$$_{'function'}}("$$_{'file'}", $$_{'hash'});
	}
}



sub parseDataFile {
	my $file = shift;
	my $r_hash = shift;
	undef %{$r_hash};
	my $key,$value;
	open FILE, $file;
	foreach (<FILE>) {
		next if (/^#/);
		s/[\r\n]//g;
		s/\s+$//g;
		($key, $value) = $_ =~ /([\s\S]*) ([\s\S]*?)$/;
		if ($key ne "" && $value ne "") {
			$$r_hash{$key} = $value;
		}
	}
	close FILE;
}

sub parseDataFile_lc {
	my $file = shift;
	my $r_hash = shift;
	undef %{$r_hash};
	my $key,$value;
	open FILE, $file;
	foreach (<FILE>) {
		next if (/^#/);
		s/[\r\n]//g;
		s/\s+$//g;
		($key, $value) = $_ =~ /([\s\S]*) ([\s\S]*?)$/;
		if ($key ne "" && $value ne "") {
			$$r_hash{lc($key)} = $value;
		}
	}
	close FILE;
}

sub parseDataFile2 {
	my $file = shift;
	my $r_hash = shift;
	undef %{$r_hash};
	my $key,$value;
	open FILE, $file;
	foreach (<FILE>) {
		next if (/^#/);
		s/[\r\n]//g;
		s/\s+$//g;
		($key, $value) = $_ =~ /([\s\S]*?) ([\s\S]*)$/;
		$key =~ s/\s//g;
		if ($key eq "") {
			($key) = $_ =~ /([\s\S]*)$/;
			$key =~ s/\s//g;
		}
		if ($key ne "") {
			$$r_hash{$key} = $value;
		}
	}
	close FILE;
}

sub parseItemsControl {
	my $file = shift;
	my $r_hash = shift;
	undef %{$r_hash};
	my $key,@args;
	open FILE, $file;
	foreach (<FILE>) {
		next if (/^#/);
		s/[\r\n]//g;
		s/\s+$//g;
		($key, $args) = $_ =~ /([\s\S]+?) (\d+[\s\S]*)/;
		@args = split / /,$args;
		if ($key ne "") {
			$$r_hash{lc($key)}{'keep'} = $args[0];
			$$r_hash{lc($key)}{'storage'} = $args[1];
			$$r_hash{lc($key)}{'sell'} = $args[2];
		}
	}
	close FILE;
}

sub parseNPCs {
	my $file = shift;
	my $r_hash = shift;
	my $i, $string;
	undef %{$r_hash};
	my $key,$value;
	open FILE, $file;
	foreach (<FILE>) {
		next if (/^#/);
		s/[\r\n]//g;
		s/\s+/ /g;
		s/\s+$//g;
		@args = split /\s/, $_;
		if (@args > 4) {
			$$r_hash{$args[0]}{'map'} = $args[1];
			$$r_hash{$args[0]}{'pos'}{'x'} = $args[2];
			$$r_hash{$args[0]}{'pos'}{'y'} = $args[3];
			$string = $args[4];
			for ($i = 5; $i < @args; $i++) {
				$string .= " $args[$i]";
			}
			$$r_hash{$args[0]}{'name'} = $string;
		}
	}
	close FILE;
}

sub parseMonControl {
	my $file = shift;
	my $r_hash = shift;
	undef %{$r_hash};
	my $key,@args;
	open FILE, $file;
	foreach (<FILE>) {
		next if (/^#/);
		s/[\r\n]//g;
		s/\s+$//g;
		($key, $args) = $_ =~ /([\s\S]+?) (\d+[\s\S]*)/;
		@args = split / /,$args;
		if ($key ne "") {
			$$r_hash{lc($key)}{'attack_auto'} = $args[0];
			$$r_hash{lc($key)}{'teleport_auto'} = $args[1];
			$$r_hash{lc($key)}{'teleport_search'} = $args[2];
		}
	}
	close FILE;
}

sub parsePortals {
	my $file = shift;
	my $r_hash = shift;
	undef %{$r_hash};
	my $key,$value;
	my %IDs;
	my $i;
	my $j = 0;
	open FILE, $file;
	foreach (<FILE>) {
		next if (/^#/);
		s/[\r\n]//g;
		s/\s+/ /g;
		s/\s+$//g;
		@args = split /\s/, $_;
		if (@args > 5) {
			$IDs{$args[0]}{$args[1]}{$args[2]} = "$args[0] $args[1] $args[2]";
			$$r_hash{"$args[0] $args[1] $args[2]"}{'source'}{'ID'} = "$args[0] $args[1] $args[2]";
			$$r_hash{"$args[0] $args[1] $args[2]"}{'source'}{'map'} = $args[0];
			$$r_hash{"$args[0] $args[1] $args[2]"}{'source'}{'pos'}{'x'} = $args[1];
			$$r_hash{"$args[0] $args[1] $args[2]"}{'source'}{'pos'}{'y'} = $args[2];
			$$r_hash{"$args[0] $args[1] $args[2]"}{'dest'}{'map'} = $args[3];
			$$r_hash{"$args[0] $args[1] $args[2]"}{'dest'}{'pos'}{'x'} = $args[4];
			$$r_hash{"$args[0] $args[1] $args[2]"}{'dest'}{'pos'}{'y'} = $args[5];
			if ($args[6] ne "") {
				$$r_hash{"$args[0] $args[1] $args[2]"}{'npc'}{'ID'} = $args[6];
				for ($i = 7; $i < @args; $i++) {
					$$r_hash{"$args[0] $args[1] $args[2]"}{'npc'}{'steps'}[@{$$r_hash{"$args[0] $args[1] $args[2]"}{'npc'}{'steps'}}] = $args[$i];
				}
			}
		}
		$j++;
	}
	foreach (keys %{$r_hash}) {
		$$r_hash{$_}{'dest'}{'ID'} = $IDs{$$r_hash{$_}{'dest'}{'map'}}{$$r_hash{$_}{'dest'}{'pos'}{'x'}}{$$r_hash{$_}{'dest'}{'pos'}{'y'}};
	}
	close FILE;
}

sub parsePortalsLOS {
	my $file = shift;
	my $r_hash = shift;
	undef %{$r_hash};
	my $key;
	open FILE, $file;
	foreach (<FILE>) {
		next if (/^#/);
		s/[\r\n]//g;
		s/\s+/ /g;
		s/\s+$//g;
		@args = split /\s/, $_;
		if (@args) {
			$map = shift @args;
			$x = shift @args;
			$y = shift @args;
			for ($i = 0; $i < @args; $i += 4) {
				$$r_hash{"$map $x $y"}{"$args[$i] $args[$i+1] $args[$i+2]"} = $args[$i+3];
			}
		}
	}
	close FILE;
}

sub parseReload {
	my $temp = shift;
	my @temp;
	my %temp;
	my $temp2;
	my $except;
	my $found;
	while ($temp =~ /(\w+)/g) {
		$temp2 = $1;
		$qm = quotemeta $temp2;
		if ($temp2 eq "all") {
			foreach (@parseFiles) {
				$temp{$$_{'file'}} = $_;
			}
		} elsif ($temp2 =~ /\bexcept\b/i || $temp2 =~ /\bbut\b/i) {
			$except = 1;
		} else {
			if ($except) {
				foreach (@parseFiles) {
					delete $temp{$$_{'file'}} if $$_{'file'} =~ /$qm/i;
				}
			} else {
				foreach (@parseFiles) {
					$temp{$$_{'file'}} = $_ if $$_{'file'} =~ /$qm/i;
				}
			}
		}
	}
	foreach $temp (keys %temp) {
		$temp[@temp] = $temp{$temp};
	}
	load(\@temp);
}

sub parseResponses {
	my $file = shift;
	my $r_hash = shift;
	undef %{$r_hash};
	my $key,$value;
	my $i;
	open FILE, $file;
	foreach (<FILE>) {
		next if (/^#/);
		s/[\r\n]//g;
		($key, $value) = $_ =~ /([\s\S]*?) ([\s\S]*)$/;
		if ($key ne "" && $value ne "") {
			$i = 0;
			while ($$r_hash{"$key\_$i"} ne "") {
				$i++;
			}
			$$r_hash{"$key\_$i"} = $value;
		}
	}
	close FILE;
}

sub parseROLUT {
	my $file = shift;
	my $r_hash = shift;
	undef %{$r_hash};
	my @stuff;
	open FILE, $file;
	foreach (<FILE>) {
		s/\r//g;
		next if /^\/\//;
		@stuff = split /#/, $_;
		$stuff[1] =~ s/_/ /g;
		if ($stuff[0] ne "" && $stuff[1] ne "") {
			$$r_hash{$stuff[0]} = $stuff[1];
		}
	}
	close FILE;
}

sub parseRODescLUT {
	my $file = shift;
	my $r_hash = shift;
	undef %{$r_hash};
	my $ID;
	my $IDdesc;
	open FILE, $file;
	foreach (<FILE>) {
		s/\r//g;
		if (/^#/) {
			$$r_hash{$ID} = $IDdesc;
			undef $ID;
			undef $IDdesc;
		} elsif (!$ID) {
			($ID) = /([\s\S]+)#/;
		} else {
			$IDdesc .= $_;
			$IDdesc =~ s/\^......//g;
			$IDdesc =~ s/_/--------------/g;
		}
	}
	close FILE;
}

sub parseROSlotsLUT {
	my $file = shift;
	my $r_hash = shift;
	undef %{$r_hash};
	my $ID;
	open FILE, $file;
	foreach (<FILE>) {
		if (!$ID) {
			($ID) = /(\d+)#/;
		} else {
			($$r_hash{$ID}) = /(\d+)#/;
			undef $ID;
		}
	}
	close FILE;
}

sub parseSkillsLUT {
	my $file = shift;
	my $r_hash = shift;
	undef %{$r_hash};
	my @stuff;
	my $i;
	open FILE, $file;
	$i = 1;
	foreach (<FILE>) {
		@stuff = split /#/, $_;
		$stuff[1] =~ s/_/ /g;
		if ($stuff[0] ne "" && $stuff[1] ne "") {
			$$r_hash{$stuff[0]} = $stuff[1];
		}
		$i++;
	}
	close FILE;
}


sub parseSkillsIDLUT {
	my $file = shift;
	my $r_hash = shift;
	undef %{$r_hash};
	my @stuff;
	my $i;
	open FILE, $file;
	$i = 1;
	foreach (<FILE>) {
		@stuff = split /#/, $_;
		$stuff[1] =~ s/_/ /g;
		if ($stuff[0] ne "" && $stuff[1] ne "") {
			$$r_hash{$i} = $stuff[1];
		}
		$i++;
	}
	close FILE;
}

sub parseSkillsReverseLUT_lc {
	my $file = shift;
	my $r_hash = shift;
	undef %{$r_hash};
	my @stuff;
	my $i;
	open FILE, $file;
	$i = 1;
	foreach (<FILE>) {
		@stuff = split /#/, $_;
		$stuff[1] =~ s/_/ /g;
		if ($stuff[0] ne "" && $stuff[1] ne "") {
			$$r_hash{lc($stuff[1])} = $stuff[0];
		}
		$i++;
	}
	close FILE;
}

sub parseSkillsSPLUT {
	my $file = shift;
	my $r_hash = shift;
	undef %{$r_hash};
	my $ID;
	my $i;
	$i = 1;
	open FILE, $file;
	foreach (<FILE>) {
		if (/^\@/) {
			undef $ID;
			$i = 1;
		} elsif (!$ID) {
			($ID) = /([\s\S]+)#/;
		} else {
			($$r_hash{$ID}{$i++}) = /(\d+)#/;
		}
	}
	close FILE;
}

sub parseTimeouts {
	my $file = shift;
	my $r_hash = shift;
	my ($key,$value);
	open (FILE, "<$file");
	foreach (<FILE>) {
		next if (/^#/);
		s/[\r\n]//g;
		($key, $value) = $_ =~ /([\s\S]*) ([\s\S]*?)$/;
		if ($key ne "" && $value ne "") {
			$$r_hash{$key}{'timeout'} = $value;
		}
	}
	close FILE;
}

sub writeDataFile {
	my $file = shift;
	my $r_hash = shift;
	my ($key,$value);
	open (FILE, "+> $file");
	foreach (keys %{$r_hash}) {
		if ($_ ne "") {
			print FILE "$_ $$r_hash{$_}\n";
		}
	}
	close FILE;
}

sub writeDataFileIntact {
	my $file = shift;
	my $r_hash = shift;
	my $data;
	my $key;
	open FILE, $file;
	foreach (<FILE>) {
                if (/^#/ || $_ =~ /^\n/ || $_ =~ /^\r/) {
                        $data .= $_;
                        next;
                }
                ($key) = $_ =~ /^(\w+)/;
                $data .= "$key $$r_hash{$key}\n";
        }
	close FILE;
	open FILE, "+> $file";
	print FILE $data;
	close FILE;
}

sub writeDataFileIntact2 {
	my $file = shift;
	my $r_hash = shift;
	my $data;
	my $key;
	open FILE, $file;
	foreach (<FILE>) {
                if (/^#/ || $_ =~ /^\n/ || $_ =~ /^\r/) {
                        $data .= $_;
                        next;
                }
                ($key) = $_ =~ /^(\w+)/;
                $data .= "$key $$r_hash{$key}{'timeout'}\n";
        }
	close FILE;
	open FILE, "+> $file";
	print FILE $data;
	close FILE;
}

sub writePortalsLOS {
	my $file = shift;
	my $r_hash = shift;
	open FILE, "+> $file";
	foreach $key (keys %{$r_hash}) {
		next if (!(keys %{$$r_hash{$key}}));
		print FILE $key;
		foreach (keys %{$$r_hash{$key}}) {
			print FILE " $_ $$r_hash{$key}{$_}";
		}
		print FILE "\n";
	}
	close FILE;
}

sub updateMonsterLUT {
	my $file = shift;
	my $ID = shift;
	my $name = shift;
	open FILE, ">> $file";
	print FILE "$ID $name\n";
	close FILE;
}

sub updatePortalLUT {
	my ($file, $src, $x1, $y1, $dest, $x2, $y2) = @_;
	open FILE, ">> $file";
	print FILE "$src $x1 $y1 $dest $x2 $y2\n";
	close FILE;
}

sub updateNPCLUT {
	my ($file, $ID, $map, $x, $y, $name) = @_;
	open FILE, ">> $file"; 
	print FILE "$ID $map $x $y $name\n"; 
	close FILE; 
} 

#######################################
#######################################
#HASH/ARRAY MANAGEMENT
#######################################
#######################################


sub binAdd {
	my $r_array = shift;
	my $ID = shift;
	my $i;
	for ($i = 0; $i <= @{$r_array};$i++) {
		if ($$r_array[$i] eq "") {
			$$r_array[$i] = $ID;
			return $i;
		}
	}
}

sub binFind {
	my $r_array = shift;
	my $ID = shift;
	my $i;
	for ($i = 0; $i < @{$r_array};$i++) {
		if ($$r_array[$i] eq $ID) {
			return $i;
		}
	}
}

sub binFindReverse {
	my $r_array = shift;
	my $ID = shift;
	my $i;
	for ($i = @{$r_array} - 1; $i >= 0;$i--) {
		if ($$r_array[$i] eq $ID) {
			return $i;
		}
	}
}

sub binRemove {
	my $r_array = shift;
	my $ID = shift;
	my $i;
	for ($i = 0; $i < @{$r_array};$i++) {
		if ($$r_array[$i] eq $ID) {
			undef $$r_array[$i];
			last;
		}
	}
}

sub binRemoveAndShift {
	my $r_array = shift;
	my $ID = shift;
	my $found;
	my $i;
	my @newArray;
	for ($i = 0; $i < @{$r_array};$i++) {
		if ($$r_array[$i] ne $ID || $found ne "") {
			push @newArray, $$r_array[$i];
		} else {
			$found = $i;
		}
	}
	@{$r_array} = @newArray;
	return $found;
}

sub binRemoveAndShiftByIndex {
	my $r_array = shift;
	my $index = shift;
	my $found;
	my $i;
	my @newArray;
	for ($i = 0; $i < @{$r_array};$i++) {
		if ($i != $index) {
			push @newArray, $$r_array[$i];
		} else {
			$found = 1;
		}
	}
	@{$r_array} = @newArray;
	return $found;
}

sub binSize {
	my $r_array = shift;
	my $found = 0;
	my $i;
	for ($i = 0; $i < @{$r_array};$i++) {
		if ($$r_array[$i] ne "") {
			$found++;
		}
	}
	return $found;
}

sub existsInList {
	my ($list, $val) = @_;
	@array = split /,/, $list;
	return 0 if ($val eq "");
	$val = lc($val);
	foreach (@array) {
		s/^\s+//;
		s/\s+$//;
		s/\s+/ /g;
		next if ($_ eq "");
		return 1 if (lc($_) eq $val);
	}
	return 0;
}

sub findIndex {
	my $r_array = shift;
	my $match = shift;
	my $ID = shift;
	my $i;
	for ($i = 0; $i < @{$r_array} ;$i++) {
		if ((%{$$r_array[$i]} && $$r_array[$i]{$match} == $ID)
			|| (!%{$$r_array[$i]} && $ID eq "")) {
			return $i;
		}
	}
	if ($ID eq "") {
		return $i;
	}
}


sub findIndexString {
	my $r_array = shift;
	my $match = shift;
	my $ID = shift;
	my $i;
	for ($i = 0; $i < @{$r_array} ;$i++) {
		if ((%{$$r_array[$i]} && $$r_array[$i]{$match} eq $ID)
			|| (!%{$$r_array[$i]} && $ID eq "")) {
			return $i;
		}
	}
	if ($ID eq "") {
		return $i;
	}
}


sub findIndexString_lc {
	my $r_array = shift;
	my $match = shift;
	my $ID = shift;
	my $i;
	for ($i = 0; $i < @{$r_array} ;$i++) {
		if ((%{$$r_array[$i]} && lc($$r_array[$i]{$match}) eq lc($ID))
			|| (!%{$$r_array[$i]} && $ID eq "")) {
			return $i;
		}
	}
	if ($ID eq "") {
		return $i;
	}
}

sub findKey {
	my $r_hash = shift;
	my $match = shift;
	my $ID = shift;
	foreach (keys %{$r_hash}) {
		if ($$r_hash{$_}{$match} == $ID) {
			return $_;
		}
	}
}

sub findKeyString {
	my $r_hash = shift;
	my $match = shift;
	my $ID = shift;
	foreach (keys %{$r_hash}) {
		if ($$r_hash{$_}{$match} eq $ID) {
			return $_;
		}
	}
}

sub minHeapAdd {
	my $r_array = shift;
	my $r_hash = shift;
	my $match = shift;
	my $i;
	my $found;
	my @newArray;
	for ($i = 0; $i < @{$r_array};$i++) {
		if (!$found && $$r_hash{$match} < $$r_array[$i]{$match}) {
			push @newArray, $r_hash;
			$found = 1;
		}
		push @newArray, $$r_array[$i];
	}
	if (!$found) {
		push @newArray, $r_hash;
	}
	@{$r_array} = @newArray;
}

sub updateDamageTables {
	my ($ID1, $ID2, $damage) = @_;
	if ($ID1 eq $accountID) {
		if (%{$monsters{$ID2}}) {
			$monsters{$ID2}{'dmgTo'} += $damage;
			$monsters{$ID2}{'dmgFromYou'} += $damage;
			if ($damage == 0) {
				$monsters{$ID2}{'missedFromYou'}++;
			}
		}
	} elsif ($ID2 eq $accountID) {
		if (%{$monsters{$ID1}}) {
			$monsters{$ID1}{'dmgFrom'} += $damage;
			$monsters{$ID1}{'dmgToYou'} += $damage;
			if ($damage == 0) {
				$monsters{$ID1}{'missedYou'}++;
			}
			$monsters{$ID1}{'attackedByPlayer'} = 0;
			$monsters{$ID1}{'attackedYou'}++ unless ($monsters{$ID1}{'dmgFromPlayer'} || $monsters{$ID1}{'missedFromPlayer'}
			                                      || $monsters{$ID1}{'missedToPlayer'} || $monsters{$ID1}{'dmgToPlayer'});
		}
	} elsif (%{$monsters{$ID1}}) {
		if (%{$players{$ID2}}) {
			$monsters{$ID1}{'dmgFrom'} += $damage;
			$monsters{$ID1}{'dmgToPlayer'}{$ID2} += $damage;
			$players{$ID2}{'dmgFromMonster'}{$ID1} += $damage;
			if ($damage == 0) {
				$monsters{$ID1}{'missedToPlayer'}{$ID2}++;
				$players{$ID2}{'missedFromMonster'}{$ID1}++;
			}
			if (%{$chars[$config{'char'}]{'party'}} && %{$chars[$config{'char'}]{'party'}{'users'}{$ID2}}) {
				$monsters{$ID1}{'dmgToParty'} += $damage;
				$monsters{$ID1}{'attackedByPlayer'} = 0 if ($config{'attackAuto_party'} || ( 
						$config{'attackAuto_followTarget'} &&
						$ai_v{'temp'}{'ai_follow_following'} &&
						$ID2 eq $ai_v{'temp'}{'ai_follow_ID'}
					)); 
			} else {
				$monsters{$ID1}{'attackedByPlayer'} = 1 unless ($config{'attackAuto_followTarget'}
					&& $ai_v{'temp'}{'ai_follow_following'} && $ID2 eq $ai_v{'temp'}{'ai_follow_ID'});
			}
		}
		
	} elsif (%{$players{$ID1}}) {
		if (%{$monsters{$ID2}}) {
			$monsters{$ID2}{'dmgTo'} += $damage;
			$monsters{$ID2}{'dmgFromPlayer'}{$ID1} += $damage;
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

sub avoidGM_near() {
	for (my $i = 0; $i < @playersID; $i++) {
		next if($playersID[$i] eq "");

		# Check whether this "GM" is on the ignore list
		# in order to prevent false matches
		my $statusGM = 1;
		my $j = 0;
		while ($avoid{"avoid_$j"} ne "") {
			if ($players{$playersID[$i]}{'name'} eq $avoid{"avoid_ignore_$j"})
			{
				$statusGM = 0;
				last;
			}
			$j++;
		}

		if ($statusGM && $players{$playersID[$i]}{'name'} =~/GM(.*)\d{1,}/i) {
			print "GM $players{$playersID[$i]}{'name'} is nearby, disconnecting...\n";
			chatLog("k", "*** Found GM $players{$playersID[$i]}{'name'} nearby and disconnected ***\n");

			my $tmp = $config{'avoidGM_reconnect'};
			print "Disconnect for $tmp seconds...\n";
			$timeout_ex{'master'}{'time'} = time;
			$timeout_ex{'master'}{'timeout'} = $tmp;
			killConnection(\$remote_socket);
			return 1;
		}
	}
	return 0;
}

sub avoidGM_talk($$) {
	return if (!$config{'avoidGM_talk'});
	my ($chatMsgUser, $chatMsg) = @_;

	# Check whether this "GM" is on the ignore list
	# in order to prevent false matches
	my $statusGM = 1;
	my $j = 0;
	while ($avoid{"avoid_$j"} ne "") {
		if ($chatMsgUser eq $avoid{"avoid_ignore_$j"})
		{
			$statusGM = 0;
			last;
		}
		$j++;
	}

	if ($statusGM && $chatMsgUser =~/GM(.*)\d{1,}/i) {
		print "Disconnecting to avoid GM!\n"; 
		chatLog("k", "*** The GM $chatMsgUser talked to you, auto disconnected ***\n");

		my $tmp = $config{'avoidGM_reconnect'};
		print "Disconnect for $tmp seconds...\n";
		$timeout_ex{'master'}{'time'} = time;
		$timeout_ex{'master'}{'timeout'} = $tmp;
		killConnection(\$remote_socket);
		return 1;
	}
	return 0;
}

sub avoidList_near() {
	for (my $i = 0; $i < @playersID; $i++) {
		next if($playersID[$i] eq "");
		$j = 0;
		while ($avoid{"avoid_$j"} ne "") {
			if ($players{$playersID[$i]}{'name'} eq $avoid{"avoid_$j"} || $players{$playersID[$i]}{'nameID'} eq $avoid{"avoid_aid_$j"}) {
				print "$players{$playersID[$i]}{'name'} is nearby, disconnecting...\n";
				chatLog("k", "*** Found $players{$playersID[$i]}{'name'} nearby and disconnected ***\n");
				print "Disconnect for $config{'avoidList_reconnect'} seconds...\n";
				$timeout_ex{'master'}{'time'} = time;
				$timeout_ex{'master'}{'timeout'} = $config{'avoidList_reconnect'};
				killConnection(\$remote_socket);
				return 1;
			}
			$j++;
		}
	}
	return 0;
}

sub avoidList_talk($$) {
	return if (!$config{'avoidList'});
	my ($chatMsgUser, $chatMsg) = @_;

	my $j = 0;
	while ($avoid{"avoid_$j"} ne "") {
		if ($chatMsgUser eq $avoid{"avoid_$j"}) { 
			print "Disconnecting to avoid $chatMsgUser!\n"; 
			chatLog("k", "*** $chatMsgUser talked to you, auto disconnected ***\n"); 
			print "Disconnect for $config{'avoidList_reconnect'} seconds...\n";
			$timeout_ex{'master'}{'time'} = time;
			$timeout_ex{'master'}{'timeout'} = $config{'avoidList_reconnect'};
			killConnection(\$remote_socket);
		}
		$j++;
	}
}

sub compilePortals {
	undef %mapPortals;
	foreach (keys %portals_lut) {
		%{$mapPortals{$portals_lut{$_}{'source'}{'map'}}{$_}{'pos'}} = %{$portals_lut{$_}{'source'}{'pos'}};
	}
	$l = 0;
	foreach $map (keys %mapPortals) {
		foreach $portal (keys %{$mapPortals{$map}}) {
			foreach (keys %{$mapPortals{$map}}) {
				next if ($_ eq $portal);
				if ($portals_los{$portal}{$_} eq "" && $portals_los{$_}{$portal} eq "") {
					if ($field{'name'} ne $map) {
						print "Processing map $map\n";
						getField("fields/$map.fld", \%field);
					}
					print "Calculating portal route $portal -> $_\n";
					ai_route_getRoute(\@solution, \%field, \%{$mapPortals{$map}{$portal}{'pos'}}, \%{$mapPortals{$map}{$_}{'pos'}});
					compilePortals_getRoute();
					$portals_los{$portal}{$_} = (@solution) ? 1 : 0;
				}
			}
		}
	}

	writePortalsLOS("tables/portalsLOS.txt", \%portals_los);

	print "Wrote portals Line of Sight table to 'tables/portalsLOS.txt'\n";

}

sub compilePortals_check {
	my $r_return = shift;
	my %mapPortals;
	undef $$r_return;
	foreach (keys %portals_lut) {
		%{$mapPortals{$portals_lut{$_}{'source'}{'map'}}{$_}{'pos'}} = %{$portals_lut{$_}{'source'}{'pos'}};
	}
	foreach $map (keys %mapPortals) {
		foreach $portal (keys %{$mapPortals{$map}}) {
			foreach (keys %{$mapPortals{$map}}) {
				next if ($_ eq $portal);
				if ($portals_los{$portal}{$_} eq "" && $portals_los{$_}{$portal} eq "") {
					$$r_return = 1;
					return;
				}
			}
		}
	}
}

sub compilePortals_getRoute {	
	if ($ai_seq[0] eq "route_getRoute") {
		if (!$ai_seq_args[0]{'init'}) {
			undef @{$ai_v{'temp'}{'subSuc'}};
			undef @{$ai_v{'temp'}{'subSuc2'}};
			if (ai_route_getMap(\%{$ai_seq_args[0]}, $ai_seq_args[0]{'start'}{'x'}, $ai_seq_args[0]{'start'}{'y'})) {
				ai_route_getSuccessors(\%{$ai_seq_args[0]}, \%{$ai_seq_args[0]{'start'}}, \@{$ai_v{'temp'}{'subSuc'}},0);
				ai_route_getDiagSuccessors(\%{$ai_seq_args[0]}, \%{$ai_seq_args[0]{'start'}}, \@{$ai_v{'temp'}{'subSuc'}},0);
				foreach (@{$ai_v{'temp'}{'subSuc'}}) {
					ai_route_getSuccessors(\%{$ai_seq_args[0]}, \%{$_}, \@{$ai_v{'temp'}{'subSuc2'}},0);
					ai_route_getDiagSuccessors(\%{$ai_seq_args[0]}, \%{$_}, \@{$ai_v{'temp'}{'subSuc2'}},0);
				}
				if (@{$ai_v{'temp'}{'subSuc'}}) {
					%{$ai_seq_args[0]{'start'}} = %{$ai_v{'temp'}{'subSuc'}[0]};
				} elsif (@{$ai_v{'temp'}{'subSuc2'}}) {
					%{$ai_seq_args[0]{'start'}} = %{$ai_v{'temp'}{'subSuc2'}[0]};
				}
			}
			undef @{$ai_v{'temp'}{'subSuc'}};
			undef @{$ai_v{'temp'}{'subSuc2'}};
			if (ai_route_getMap(\%{$ai_seq_args[0]}, $ai_seq_args[0]{'dest'}{'x'}, $ai_seq_args[0]{'dest'}{'y'})) {
				ai_route_getSuccessors(\%{$ai_seq_args[0]}, \%{$ai_seq_args[0]{'dest'}}, \@{$ai_v{'temp'}{'subSuc'}},0);
				ai_route_getDiagSuccessors(\%{$ai_seq_args[0]}, \%{$ai_seq_args[0]{'dest'}}, \@{$ai_v{'temp'}{'subSuc'}},0);
				foreach (@{$ai_v{'temp'}{'subSuc'}}) {
					ai_route_getSuccessors(\%{$ai_seq_args[0]}, \%{$_}, \@{$ai_v{'temp'}{'subSuc2'}},0);
					ai_route_getDiagSuccessors(\%{$ai_seq_args[0]}, \%{$_}, \@{$ai_v{'temp'}{'subSuc2'}},0);
				}
				if (@{$ai_v{'temp'}{'subSuc'}}) {
					%{$ai_seq_args[0]{'dest'}} = %{$ai_v{'temp'}{'subSuc'}[0]};
				} elsif (@{$ai_v{'temp'}{'subSuc2'}}) {
					%{$ai_seq_args[0]{'dest'}} = %{$ai_v{'temp'}{'subSuc2'}[0]};
				}
			}
			$ai_seq_args[0]{'timeout'} = 90000;
		}
		$ai_seq_args[0]{'init'} = 1;
		ai_route_searchStep(\%{$ai_seq_args[0]});
		ai_route_getRoute_destroy(\%{$ai_seq_args[0]});
		shift @ai_seq;
		shift @ai_seq_args;
	}
}


sub getCoordString {
	my $x = shift;
	my $y = shift;
	return pack("C*", int($x / 4), ($x % 4) * 64 + int($y / 16), ($y % 16) * 16);
}

sub getFormattedDate {
        my $thetime = shift;
        my $r_date = shift;
        my @localtime = localtime $thetime;
        my $themonth = (Jan, Feb, Mar, Apr, May, Jun, Jul, Aug, Sep, Oct, Nov, Dec)[$localtime[4]];
        $localtime[2] = "0" . $localtime[2] if ($localtime[2] < 10);
        $localtime[1] = "0" . $localtime[1] if ($localtime[1] < 10);
        $localtime[0] = "0" . $localtime[0] if ($localtime[0] < 10);
        $$r_date = "$themonth $localtime[3] $localtime[2]:$localtime[1]:$localtime[0] " . ($localtime[5] + 1900);
        return $$r_date;
}

sub getHex {
	my $data = shift;
	my $i;
	my $return;
	for ($i = 0; $i < length($data); $i++) {
		$return .= uc(unpack("H2",substr($data, $i, 1)));
		if ($i + 1 < length($data)) {
			$return .= " ";
		}
	}
	return $return;
}



sub getTickCount {
	my $time = int(time()*1000);
	if (length($time) > 9) {
		return substr($time, length($time) - 8, length($time));
	} else {
		return $time;
	}
}

##
# lookAtPosition($pos, [$headdir])
# $pos: a reference to a coordinate hash.
# $headdir: 0 = face directly, 1 = look right, 2 = look left
#
# Look at position $pos.
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

sub makeCoords {
	my $r_hash = shift;
	my $rawCoords = shift;
	$$r_hash{'x'} = unpack("C", substr($rawCoords, 0, 1)) * 4 + (unpack("C", substr($rawCoords, 1, 1)) & 0xC0) / 64;
	$$r_hash{'y'} = (unpack("C",substr($rawCoords, 1, 1)) & 0x3F) * 16 + 
				(unpack("C",substr($rawCoords, 2, 1)) & 0xF0) / 16;
}
sub makeCoords2 {
	my $r_hash = shift;
	my $rawCoords = shift;
	$$r_hash{'x'} = (unpack("C",substr($rawCoords, 1, 1)) & 0xFC) / 4 + 
				(unpack("C",substr($rawCoords, 0, 1)) & 0x0F) * 64;
	$$r_hash{'y'} = (unpack("C", substr($rawCoords, 1, 1)) & 0x03) * 256 + unpack("C", substr($rawCoords, 2, 1));
}
sub makeIP {
	my $raw = shift;
	my $ret;
	my $i;
	for ($i=0;$i < 4;$i++) {
		$ret .= hex(getHex(substr($raw, $i, 1)));
		if ($i + 1 < 4) {
			$ret .= ".";
		}
	}
	return $ret;
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

sub printItemDesc {
	my $itemID = shift;
	print "===============Item Description===============\n";
	print "Item: $items_lut{$itemID}\n\n";
	print $itemsDesc_lut{$itemID};
	print "==============================================\n";
}

sub timeOut {
	my ($r_time, $compare_time) = @_;
	if ($compare_time ne "") {
		return (time - $r_time > $compare_time);
	} else {
		return (time - $$r_time{'time'} > $$r_time{'timeout'});
	}
}

sub vocalString {
        my $letter_length = shift;
        return if ($letter_length <= 0);
        my $r_string = shift;
        my $test;
        my $i;
        my $password;
        my @cons = ("b", "c", "d", "g", "h", "j", "k", "l", "m", "n", "p", "r", "s", "t", "v", "w", "y", "z", "tr", "cl", "cr", "br", "fr", "th", "dr", "ch", "st", "sp", "sw", "pr", "sh", "gr", "tw", "wr", "ck");
        my @vowels = ("a", "e", "i", "o", "u" , "a", "e" ,"i","o","u","a","e","i","o", "ea" , "ou" , "ie" , "ai" , "ee" ,"au", "oo");
        my %badend = ( "tr" => 1, "cr" => 1, "br" => 1, "fr" => 1, "dr" => 1, "sp" => 1, "sw" => 1, "pr" =>1, "gr" => 1, "tw" => 1, "wr" => 1, "cl" => 1);
        for (;;) {
                $password = "";
                for($i = 0; $i < $letter_length; $i++){
                        $password .= $cons[rand(@cons - 1)] . $vowels[rand(@vowels - 1)];
                }
                $password = substr($password, 0, $letter_length);
                ($test) = ($password =~ /(..)\z/);
                last if ($badend{$test} != 1);
        }
        $$r_string = $password;
        return $$r_string;
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

sub printStat {
	my $dmgpsec_string = sprintf("%.2f", $dmgpsec);
	my $totalelasped_string = sprintf("%.2f", $totalelasped);
	my $elasped_string = sprintf("%.2f", $elasped);

	$~ = "COMBATSTATS";
	format COMBATSTATS =
Total Damage: @>>>>>>>>>>>>> Dmg/sec: @<<<<<<<<<<<<<<
              $totaldmg               $dmgpsec_string
Total Time spent (sec): @>>>>>>>>
                        $totalelasped_string
Last Monster took (sec): @>>>>>>>
 			$elasped_string
.
		write;
		print	"----------------------------\n";

}

sub findIndexString_lc_not_equip {
	my $r_array = shift;
	my $match = shift;
	my $ID = shift;
	my $i;
	for ($i = 0; $i < @{$r_array} ;$i++) {
		if ((%{$$r_array[$i]} && lc($$r_array[$i]{$match}) eq lc($ID) && !($$r_array[$i]{'equipped'}))
			 || (!%{$$r_array[$i]} && $ID eq "")) {			  
			return $i;
		}
	}
	if ($ID eq "") {
		return $i;
	}
}

sub getListCount {
	my ($list) = @_;
	my $i = 0;
	@array = split /,/, $list;
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
	@array = split /,/, $list;
	foreach (@array) {
		s/^\s+//;
		s/\s+$//;
		s/\s+/ /g;
		next if ($_ eq "");
		$i++;
		return $_ if ($i eq $num);
	}
	return "";
}

sub ClearRouteAI {
	my $msg = shift;
	print $msg;
	chatLog("k", $msg);
	aiRemove("move");
	aiRemove("route");
	aiRemove("route_getRoute");
	aiRemove("route_getMapRoute");
	ai_clientSuspend(0, 5);
}

sub Unstuck {
	my $msg = shift;

	$totalStuckCount++;
	$old_x = 0;
	$old_y = 0;
	$old_pos_x = 0;
	$old_pos_y = 0;
	$move_x = 0;
	$move_y = 0;
	$move_pos_x = 0;
	$move_pos_y = 0;
	print $msg;
	chatLog("k", $msg);
	aiRemove("move");
	aiRemove("route");
	aiRemove("route_getRoute");
	aiRemove("route_getMapRoute");
	useTeleport(1);
	ai_clientSuspend(0, 5);
}

sub RespawnUnstuck {
	$totalStuckCount = 0;
	$calcTo_SameSpot = 0;
	$calcFrom_SameSpot = 0;
	$moveTo_SameSpot = 0;
	$moveFrom_SameSpot = 0;
	$route_stuck = 0;
	$old_x = 0;
	$old_y = 0;
	$old_pos_x = 0;
	$old_pos_y = 0;
	$move_x = 0;
	$move_y = 0;
	$move_pos_x = 0;
	$move_pos_y = 0;
	print "Cannot calculate route, respawning to saveMap ...\n";
	chatLog("k", "Cannot calculate route, respawning to saveMap ...\n"); 
	aiRemove("move");
	aiRemove("route");
	aiRemove("route_getRoute");
	aiRemove("route_getMapRoute");
	useTeleport(2);
	ai_clientSuspend(0, 5);
}

sub useTeleport { 
	my $level = shift; 
	my $invIndex = findIndex(\@{$chars[$config{'char'}]{'inventory'}}, "nameID", $level + 600); 
	if (!$config{'teleportAuto_useItem'} || $chars[$config{'char'}]{'skills'}{'AL_TELEPORT'}{'lv'} ) { 
		sendTeleport(\$remote_socket, "Random") if ($level == 1); 
		sendTeleport(\$remote_socket, $config{'saveMap'}.".gat") if ($level == 2); 
	} elsif ($config{'teleportAuto_useItem'} && $invIndex ne "") { 
		sendItemUse(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$invIndex]{'index'}, $accountID); 
		if ($level == 1) { 
			sendTeleport(\$remote_socket, "Random");
		}
	} else { 
		print "You don't have wing or skill to teleport or respawn\n"; 
	} 
}

return 1;
