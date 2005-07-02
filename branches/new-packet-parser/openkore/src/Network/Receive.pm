package Network::Receive;

use strict;

use Globals;
use Actor;
use Actor::You;
use Time::HiRes qw(time usleep);
use Settings;
use Log qw(message warning error debug);
use FileParsers;
use Interface;
use Network;
use Network::Send;
use Misc;
use Plugins;
use Utils;
use Skills;

###### Public methods ######

sub new {
	my ($class) = @_;
	my %self;

	#If you are wondering about those funny strings like 'x2 v1' read http://perldoc.perl.org/functions/pack.html
	#and http://perldoc.perl.org/perlpacktut.html

	#Defines a list of Packet Handlers and decoding information
	#'packetSwitch' => ['handler function','unpack string',[qw(argument names)]]
	$self{packet_list} = {
		'0069' => ['account_server_info', 'x2 a4 a4 a4 x30 C1 a*', [qw(sessionID accountID sessionID2 accountSex serverInfo)]],
		'006A' => ['login_error', 'C1', [qw(type)]],
		'006B' => ['received_characters'],
		'006C' => ['login_error_game_login_server'],
		'006D' => ['character_creation_successful', 'a4 x4 V1 x62 Z24 C1 C1 C1 C1 C1 C1 C1', [qw(ID zenny str agi vit int dex luk slot)]],
		'006E' => ['character_creation_failed'],
		'0075' => ['change_to_constate5'],
		'0077' => ['change_to_constate5'],
		'007A' => ['change_to_constate5'],
		'007F' => ['received_sync', 'V1', [qw(time)]],
		'0081' => ['errors', 'C1', [qw(type)]],
		'00A0' => ['inventory_item_added', 'v1 v1 v1 C1 C1 C1 a4 v1 C1 C1', [qw(index amount nameID identified broken upgrade cards type_equip type fail)]],
		'00EA' => ['deal_add', 'S1 C1', [qw(index fail)]],
		'011E' => ['memo_success', 'C1', [qw(fail)]],
		'0114' => ['skill_use', 'v1 a4 a4 V1 V1 V1 s1 v1 v1 C1', [qw(skillID sourceID targetID tick src_speed dst_speed damage level param3 type)]],
		'0119' => ['character_looks', 'a4 v1 v1 v1', [qw(ID param1 param2 param3)]],
		'011A' => ['skill_used_no_damage', 'v1 v1 a4 a4 C1', [qw(skillID amount targetID sourceID fail)]],
		'011C' => ['warp_portal_list', 'v1 a16 a16 a16 a16', [qw(type memo1 memo2 memo3 memo4)]],
		'0121' => ['cart_info', 'v1 v1 V1 V1', [qw(items items_max weight weight_max)]],
		'0124' => ['cart_item_added', 'v1 V1 v1 x C1 C1 C1 a8', [qw(index amount ID identified broken upgrade cards)]],
		'01DC' => ['secure_login_key', 'x2 a*', [qw(secure_key)]],
		'01DE' => ['skill_use', 'v1 a4 a4 V1 V1 V1 l1 v1 v1 C1', [qw(skillID sourceID targetID tick src_speed dst_speed damage level param3 type)]],
	};

	bless \%self, $class;
	return \%self;
}

sub create {
	my ($self, $type) = @_;
	my $class = "Network::Receive::ServerType$type";

	undef $@;
	eval "use $class;";
	if ($@) {
		error "Cannot load packet parser for type '$type'.\n";
		return;
	}

	return eval "new $class;";
}

sub parse {
	my ($self, $msg) = @_;

	my $switch = uc(unpack("H2", substr($msg, 1, 1))) . uc(unpack("H2", substr($msg, 0, 1)));
	my $handler = $self->{packet_list}{$switch};
	return 0 unless $handler;

	debug "Received packet: $switch\n", "packetParser", 2;

	my %args;
	$args{switch} = $switch;
	$args{RAW_MSG} = $msg;
	$args{RAW_MSG_SIZE} = length($msg);
	if ($handler->[1]) {
		my @unpacked_data = unpack("x2 $handler->[1]", $msg);
		my $keys = $handler->[2];
		foreach my $key (@{$keys}) {
			$args{$key} = shift @unpacked_data;
		}
	}

	# TODO: this might be slow. We should pre-resolve function references.
	my $callback = $self->can($handler->[0]);
	if ($callback) {
		Plugins::callHook("packet_pre/$handler->[0]", \%args);
		$self->$callback(\%args);
	} else {
		debug "Packet Parser: Unhandled Packet: $switch\n", "packetParser", 2;
	}

	Plugins::callHook("packet/$handler->[0]", \%args);
	return 1;
}


#######################################
###### Packet handling callbacks ######
#######################################


sub account_server_info {
	my ($self, $args) = @_;
	my $msg = $args->{serverInfo};
	my $msg_size = length($msg);

	$conState = 2;
	undef $conState_tries;
	if ($versionSearch) {
		$versionSearch = 0;
		Misc::saveConfigFile();
	}
	$sessionID = $args->{sessionID};
	$accountID = $args->{accountID};
	$sessionID2 = $args->{sessionID2};
	# Account sex should only be 0 (female) or 1 (male)
	# inRO gives female as 2 but expects 0 back
	# do modulus of 2 here to fix?
	# FIXME: we should check exactly what operation the client does to the number given
	$accountSex = $args->{accountSex} % 2;
	$accountSex2 = ($config{'sex'} ne "") ? $config{'sex'} : $accountSex;

	message(swrite(
		"---------Account Info-------------", [undef],
		"Account ID: @<<<<<<<<< @<<<<<<<<<<", [unpack("V1",$accountID), getHex($accountID)],
		"Sex:        @<<<<<<<<<<<<<<<<<<<<<", [$sex_lut{$accountSex}],
		"Session ID: @<<<<<<<<< @<<<<<<<<<<", [unpack("V1",$sessionID), getHex($sessionID)],
		"            @<<<<<<<<< @<<<<<<<<<<", [unpack("V1",$sessionID2), getHex($sessionID2)],
		"----------------------------------", [undef],
	), 'connection');

	my $num = 0;
	undef @servers;
	debug "PP: Server Info: msg_size: $msg_size, msg: $msg\n";
	for (my $i = 0; $i < $msg_size; $i+=32) {
		$servers[$num]{ip} = makeIP(substr($msg, $i, 4));
		$servers[$num]{ip} = $masterServer->{ip} if ($masterServer && $masterServer->{private});
		$servers[$num]{port} = unpack("S1", substr($msg, $i+4, 2));
		($servers[$num]{name}) = substr($msg, $i + 6, 20) =~ /([\s\S]*?)\000/;
		$servers[$num]{users} = unpack("L",substr($msg, $i + 26, 4));
		$num++;
	}

	message("--------- Servers ----------\n", 'connection');
	message("#         Name            Users  IP              Port\n", 'connection');
	for (my $num = 0; $num < @servers; $num++) {
		message(swrite(
			"@<< @<<<<<<<<<<<<<<<<<<<< @<<<<< @<<<<<<<<<<<<<< @<<<<<",
			[$num, $servers[$num]{name}, $servers[$num]{users}, $servers[$num]{ip}, $servers[$num]{port}]
		), 'connection');
	}
	message("-------------------------------\n", 'connection');

	if (!$xkore) {
		message("Closing connection to Master Server\n", 'connection');
		Network::disconnect(\$remote_socket);
		if (!$masterServer->{charServer_ip} && $config{server} eq "") {
			message("Choose your server.  Enter the server number: ", "input");
			$waitingForInput = 1;

		} elsif ($masterServer->{charServer_ip}) {
			message("Forcing connect to char server $masterServer->{charServer_ip}:$masterServer->{charServer_port}\n", 'connection');

		} else {
			message("Server $config{server} selected\n", 'connection');
		}
	}
}

sub cart_info {
	my ($self, $args) = @_;

	$cart{items} = $args->{items};
	$cart{items_max} = $args->{items_max};
	$cart{weight} = int($args->{weight} / 10);
	$cart{weight_max} = int($args->{weight_max} / 10);
}

sub cart_item_added {
	my ($self, $args) = @_;

	my $item = $cart{inventory}[$args->{index}] ||= {};
	if ($item->{amount}) {
		$item->{amount} += $args->{amount};
	} else {
		$item->{nameID} = $args->{ID};
		$item->{amount} = $args->{amount};
		$item->{identified} = $args->{identified};
		$item->{broken} = $args->{broken};
		$item->{upgrade} = $args->{upgrade};
		$item->{cards} = $args->{cards};
		$item->{name} = itemName($item);
	}
	message "Cart Item Added: $item->{name} ($args->{index}) x $args->{amount}\n";
	$itemChange{$item->{name}} += $args->{amount};
}

sub change_to_constate5 {
	$conState = 5 if ($conState != 4 && $xkore);
}

sub character_creation_failed {
	message "Character cannot be to created. If you didn't make any mistake, then the name you chose already exists.\n", "info";
	if (charSelectScreen() == 1) {
		$conState = 3;
		$firstLoginMap = 1;
		$startingZenny = $chars[$config{'char'}]{'zenny'} unless defined $startingZenny;
		$sentWelcomeMessage = 1;
	}
}

sub character_creation_successful {
	my ($self,$args) = @_;
	my $char = new Actor::You;
	$char->{ID} = $args->{ID};
	$char->{name} = $args->{name};
	$char->{zenny} = $args->{zenny};
	$char->{str} = $args->{str};
	$char->{agi} = $args->{agi};
	$char->{vit} = $args->{vit};
	$char->{int} = $args->{int};
	$char->{dex} = $args->{dex};
	$char->{luk} = $args->{luk};
	my $slot = $args->{slot};

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
	}
}

sub character_looks {
	my ($self, $args) = @_;
	setStatus($args->{ID}, $args->{param1}, $args->{param2}, $args->{param3});
}

sub inventory_item_added {
	my ($self, $args) = @_;

	$conState = 5 if ($conState != 4 && $xkore);

	my ($index, $amount, $fail) = ($args->{index}, $args->{amount}, $args->{fail});

	if (!$fail) {
		my $item;
		my $invIndex = findIndex(\@{$char->{inventory}}, "index", $index);
		if (!defined $invIndex) {
			# Add new item
			$invIndex = findIndex(\@{$char->{inventory}}, "nameID", "");
			$item = $char->{inventory}[$invIndex] = {};
			$item->{index} = $index;
			$item->{nameID} = $args->{nameID};
			$item->{type} = $args->{type};
			$item->{type_equip} = $args->{type_equip};
			$item->{amount} = $amount;
			$item->{identified} = $args->{identified};
			$item->{broken} = $args->{broken};
			$item->{upgrade} = $args->{upgrade};
			$item->{cards} = $args->{cards};
			$item->{name} = itemName($item);
		} else {
			# Add stackable item
			$item = $char->{inventory}[$invIndex];
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
}

sub deal_add {
	my ($self, $args) = @_;

	if ($args->{fail}) {
		error "That person is overweight; you cannot trade.\n", "deal";
		return;
	}

	return unless $args->{index} > 0;

	my $invIndex = findIndex(\@{$char->{inventory}}, 'index', $args->{index});
	my $item = $char->{inventory}[$invIndex];
	$currentDeal{you}{$item->{nameID}}{amount} += $currentDeal{lastItemAmount};
	$item->{amount} -= $currentDeal{lastItemAmount};
	message "You added Item to Deal: $item->{name} x $currentDeal{lastItemAmount}\n", "deal";
	$itemChange{$item->{name}} -= $currentDeal{lastItemAmount};
	$currentDeal{you_items}++;
	delete $char->{inventory}[$invIndex] if $item->{amount} <= 0;
}

sub errors {
	my ($self, $args) = @_;

	if ($conState == 5 &&
	    ($config{dcOnDisconnect} > 1 ||
		($config{dcOnDisconnect} && $args->{type} != 3))) {
		message "Lost connection; exiting\n";
		$quit = 1;
	}

	$conState = 1;
	undef $conState_tries;

	$timeout_ex{'master'}{'time'} = time;
	$timeout_ex{'master'}{'timeout'} = $timeout{'reconnect'}{'timeout'};
	Network::disconnect(\$remote_socket);

	if ($args->{type} == 0) {
		error("Server shutting down\n", "connection");
	} elsif ($args->{type} == 1) {
		error("Error: Server is closed\n", "connection");
	} elsif ($args->{type} == 2) {
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

	} elsif ($args->{type} == 3) {
		error("Error: Out of sync with server\n", "connection");
	} elsif ($args->{type} == 6) {
		$interface->errorDialog("Critical Error: You must pay to play this account!");
		$quit = 1 if (!$xkore);
	} elsif ($args->{type} == 8) {
		error("Error: The server still recognizes your last connection\n", "connection");
	} elsif ($args->{type} == 10) {
		error("Error: You are out of available time paid for\n", "connection");
	} elsif ($args->{type} == 15) {
		error("Error: You have been forced to disconnect by a GM\n", "connection");
	} else {
		error("Unknown error $args->{type}\n", "connection");
	}
}

sub memo_success {
	my ($self, $args) = @_;
	if ($args->{fail}) {
		warning "Memo Failed\n";
	} else {
		message "Memo Succeeded\n", "success";
	}
}

sub login_error {
	my ($self,$args) = @_;

	Network::disconnect(\$remote_socket);
	if ($args->{type} == 0) {
		error("Account name doesn't exist\n", "connection");
		if (!$xkore && !$config{'ignoreInvalidLogin'}) {
			message("Enter Username Again: ", "input");
			my $username = $interface->getInput(-1);
			configModify('username', $username, 1);
			$timeout_ex{'master'}{'time'} = 0;
			$conState_tries = 0;
		}
	} elsif ($args->{type} == 1) {
		error("Password Error\n", "connection");
		if (!$xkore && !$config{'ignoreInvalidLogin'}) {
			message("Enter Password Again: ", "input");
			# Set -9 on getInput timeout field mean this is password field
			my $password = $interface->getInput(-9);
			configModify('password', $password, 1);
			$timeout_ex{'master'}{'time'} = 0;
			$conState_tries = 0;
		}
	} elsif ($args->{type} == 3) {
		error("Server connection has been denied\n", "connection");
	} elsif ($args->{type} == 4) {
		$interface->errorDialog("Critical Error: Your account has been blocked.");
		$quit = 1 if (!$xkore);
	} elsif ($args->{type} == 5) {
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
	} elsif ($args->{type} == 6) {
		error("The server is temporarily blocking your connection\n", "connection");
	}
	if ($args->{type} != 5 && $versionSearch) {
		$versionSearch = 0;
		writeSectionedFileIntact("$Settings::tables_folder/servers.txt", \%masterServers);
	}
}

sub login_error_game_login_server {
	error("Error logging into Game Login Server (invalid character specified)...\n", 'connection');
	$conState = 1;
	undef $conState_tries;
	$timeout_ex{master}{time} = time;
	$timeout_ex{master}{timeout} = $timeout{'reconnect'}{'timeout'};
	Network::disconnect(\$remote_socket);
}

sub received_characters {
	return if $conState == 5;
	my ($self,$args) = @_;
	message("Received characters from Game Login Server\n", "connection");
	$conState = 3;
	undef $conState_tries;
	undef @chars;


	if (exists $args->{options}{charServer}) {
		$charServer = $args->{options}{charServer};
	} else {
		$charServer = $remote_socket->peerhost . ":" . $remote_socket->peerport;
	}

	my $num;
	for (my $i = $args->{RAW_MSG_SIZE} % 106; $i < $args->{RAW_MSG_SIZE}; $i += 106) {
		#exp display bugfix - chobit andy 20030129
		$num = unpack("C1", substr($args->{RAW_MSG}, $i + 104, 1));
		$chars[$num] = new Actor::You;
		$chars[$num]{'exp'} = unpack("V1", substr($args->{RAW_MSG}, $i + 4, 4));
		$chars[$num]{'zenny'} = unpack("V1", substr($args->{RAW_MSG}, $i + 8, 4));
		$chars[$num]{'exp_job'} = unpack("V1", substr($args->{RAW_MSG}, $i + 12, 4));
		$chars[$num]{'lv_job'} = unpack("C1", substr($args->{RAW_MSG}, $i + 16, 1));
		$chars[$num]{'hp'} = unpack("v1", substr($args->{RAW_MSG}, $i + 42, 2));
		$chars[$num]{'hp_max'} = unpack("v1", substr($args->{RAW_MSG}, $i + 44, 2));
		$chars[$num]{'sp'} = unpack("v1", substr($args->{RAW_MSG}, $i + 46, 2));
		$chars[$num]{'sp_max'} = unpack("v1", substr($args->{RAW_MSG}, $i + 48, 2));
		$chars[$num]{'jobID'} = unpack("C1", substr($args->{RAW_MSG}, $i + 52, 1));
		$chars[$num]{'ID'} = substr($args->{RAW_MSG}, $i, 4);
		$chars[$num]{'lv'} = unpack("C1", substr($args->{RAW_MSG}, $i + 58, 1));
		$chars[$num]{'hair_color'} = unpack("C1", substr($args->{RAW_MSG}, $i + 70, 1));
		($chars[$num]{'name'}) = substr($args->{RAW_MSG}, $i + 74, 24) =~ /([\s\S]*?)\000/;
		$chars[$num]{'str'} = unpack("C1", substr($args->{RAW_MSG}, $i + 98, 1));
		$chars[$num]{'agi'} = unpack("C1", substr($args->{RAW_MSG}, $i + 99, 1));
		$chars[$num]{'vit'} = unpack("C1", substr($args->{RAW_MSG}, $i + 100, 1));
		$chars[$num]{'int'} = unpack("C1", substr($args->{RAW_MSG}, $i + 101, 1));
		$chars[$num]{'dex'} = unpack("C1", substr($args->{RAW_MSG}, $i + 102, 1));
		$chars[$num]{'luk'} = unpack("C1", substr($args->{RAW_MSG}, $i + 103, 1));
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
}

sub received_sync {
    $conState = 5 if ($conState != 4 && $xkore);
    debug "Received Sync\n", 'parseMsg', 2;
    $timeout{'play'}{'time'} = time;
}

sub secure_login_key {
	my ($self,$args) = @_;
	$secureLoginKey = $args->{secure_key};
}

sub skill_use {
	my ($self, $args) = @_;

	if (my $spell = $spells{$args->{sourceID}}) {
		# Resolve source of area attack skill
		$args->{sourceID} = $spell->{sourceID};
	}

	my $source = Actor::get($args->{sourceID});
	my $target = Actor::get($args->{targetID});
	delete $source->{casting};

	# Perform trigger actions
	$conState = 5 if $conState != 4 && $xkore;
	updateDamageTables($args->{sourceID}, $args->{targetID}, $args->{damage}) if ($args->{damage} != -30000);
	setSkillUseTimer($args->{skillID}, $args->{targetID}) if ($args->{sourceID} eq $accountID);
	setPartySkillTimer($args->{skillID}, $args->{targetID}) if
		$args->{sourceID} eq $accountID or $args->{sourceID} eq $args->{targetID};
	countCastOn($args->{sourceID}, $args->{targetID}, $args->{skillID});

	# Resolve source and target names
	$args->{damage} ||= "Miss!";
	my $verb = $source->verb('use', 'uses');
	my $skill = new Skills(id => $args->{skillID});
	my $disp = "$source $verb ".$skill->name;
	$disp .= ' (lvl '.$args->{level}.')' unless $args->{level} == 65535;
	$disp .= " on $target";
	$disp .= ' - Dmg: '.$args->{damage} unless $args->{damage} == -30000;
	$disp .= " (delay ".($args->{src_speed}/10).")";
	$disp .= "\n";

	if ($args->{damage} != -30000 &&
	    $args->{sourceID} eq $accountID &&
		$args->{targetID} ne $accountID) {
		calcStat($args->{damage});
	}

	my $domain = ($args->{sourceID} eq $accountID) ? "selfSkill" : "skill";

	if ($args->{damage} == 0) {
		$domain = "attackMonMiss" if $args->{sourceID} eq $accountID && $args->{targetID} ne $accountID;
		$domain = "attackedMiss" if $args->{sourceID} ne $accountID && $args->{targetID} eq $accountID;

	} elsif ($args->{damage} != -30000) {
		$domain = "attackMon" if $args->{sourceID} eq $accountID && $args->{targetID} ne $accountID;
		$domain = "attacked" if $args->{sourceID} ne $accountID && $args->{targetID} eq $accountID;
	}

	if ((($args->{sourceID} eq $accountID) && ($args->{targetID} ne $accountID)) ||
	    (($args->{sourceID} ne $accountID) && ($args->{targetID} eq $accountID))) {
		my $status = sprintf("[%3d/%3d] ", $char->hp_percent, $char->sp_percent);
		$disp = $status.$disp;
	}
	$target->{sitting} = 0 unless $args->{type} == 4 || $args->{type} == 9 || $args->{damage} == 0;

	message $disp, $domain, 1;

}

sub skill_used_no_damage {
	my ($self,$args) = @_;
	# Skill used on target, with no damage done
	if (my $spell = $spells{$args->{sourceID}}) {
		# Resolve source of area attack skill
		$args->{sourceID} = $spell->{sourceID};
	}

	# Perform trigger actions
	$conState = 5 if $conState != 4 && $xkore;
	setSkillUseTimer($args->{skillID}, $args->{targetID}) if ($args->{sourceID} eq $accountID);
	setPartySkillTimer($args->{skillID}, $args->{targetID}) if
			$args->{sourceID} eq $accountID or $args->{sourceID} eq $args->{targetID};
	countCastOn($args->{sourceID}, $args->{targetID}, $args->{skillID});
	if ($args->{sourceID} eq $accountID) {
		my $pos = calcPosition($char);
		$char->{pos_to} = $pos;
		$char->{time_move} = 0;
		$char->{time_move_calc} = 0;
	}

	# Resolve source and target names
	my $source = Actor::get($args->{sourceID});
	my $target = Actor::get($args->{targetID});
	my $verb = $source->verb('use', 'uses');

	delete $source->{casting};

	# Print skill use message
	my $extra = "";
	if ($args->{skillID} == 28) {
		$extra = ": $args->{amount} hp gained";
		updateDamageTables($args->{sourceID}, $args->{targetID}, -$args->{amount});
	} elsif ($args->{amount} != 65535) {
		$extra = ": Lv $args->{amount}";
	}

	my $domain = ($args->{sourceID} eq $accountID) ? "selfSkill" : "skill";
	my $skill = new Skills(id => $args->{skillID});
	message "$source $verb ".$skill->name()." on ".$target->nameString($source)."$extra\n", $domain;

	if ($AI && $config{'autoResponseOnHeal'}) {
		# Handle auto-response on heal
		if (($players{$args->{sourceID}} && %{$players{$args->{sourceID}}}) && (($args->{skillID} == 28) || ($args->{skillID} == 29) || ($args->{skillID} == 34))) {
			if ($args->{targetID} eq $accountID) {
				chatLog("k", "***$source ".skillName($args->{skillID})." on $target$extra***\n");
				sendMessage(\$remote_socket, "pm", getResponse("skillgoodM"), $players{$args->{sourceID}}{'name'});
			} elsif ($monsters{$args->{targetID}}) {
				chatLog("k", "***$source ".skillName($args->{skillID})." on $target$extra***\n");
				sendMessage(\$remote_socket, "pm", getResponse("skillbadM"), $players{$args->{sourceID}}{'name'});
			}
		}
	}
}

sub warp_portal_list {
	my ($self,$args) = @_;
	($args->{memo1}) = $args->{memo1} =~ /([\s\S]*)\.gat/;
	($args->{memo2}) = $args->{memo2} =~ /([\s\S]*)\.gat/;
	($args->{memo3}) = $args->{memo3} =~ /([\s\S]*)\.gat/;
	($args->{memo4}) = $args->{memo4} =~ /([\s\S]*)\.gat/;

	# Auto-detect saveMap
	if ($args->{type} == 26) {
		configModify('saveMap', $args->{memo2}) if $args->{memo2};
	} elsif ($args->{type} == 27) {
		configModify('saveMap', $args->{memo1}) if $args->{memo1};
	}

	$char->{warp}{type} = $args->{type};
	undef @{$char->{warp}{memo}};
	push @{$char->{warp}{memo}}, $args->{memo1} if $args->{memo1} ne "";
	push @{$char->{warp}{memo}}, $args->{memo2} if $args->{memo2} ne "";
	push @{$char->{warp}{memo}}, $args->{memo3} if $args->{memo3} ne "";
	push @{$char->{warp}{memo}}, $args->{memo4} if $args->{memo4} ne "";

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
}

1;
