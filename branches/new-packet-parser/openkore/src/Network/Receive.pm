package Network::Receive;

use strict;

use Globals;
use Settings;
use Log qw(message warning error debug);
use FileParsers;
use Interface;
use Network;
use Network::Send;
use Misc;
use Plugins;
use Utils;


###### Public methods ######

sub new {
	my ($class) = @_;
	my %self;

	$self{packet_list} = {
		'006C' => ['login_error'],
		'0069' => ['account_server_info', 'x2 a4 a4 a4 x30 C1 a*', [qw(sessionID accountID sessionID2 accountSex serverInfo)]],
		'0075' => ['change_to_constate5'],
		'0077' => ['change_to_constate5'],
		'007A' => ['change_to_constate5'],
		'007F' => ['received_sync', 'L1', [qw(time)]],
		'0081' => ['errors', 'C1', [qw(type)]],
		'011E' => ['memo_success', 'C1', [qw(fail)]],
		'0114' => ['skill_use', 'S1 a4 a4 L1 L1 L1 s1 S1 S1 C1', [qw(skillID sourceID targetID tick src_speed dst_speed damage level param3 type)]],
		'0119' => ['character_looks', 'a2 S1 S1 S1', [qw(ID param1 param2 param3)]],
		'0121' => ['cart_info', 'S1 S1 L1 L1', [qw(items items_max weight weight_max)]],
		'0124' => ['cart_item_added', 'S1 L1 S1 x C1 C1 C1 a8', [qw(index amount ID identified broken upgrade cards)]],
		'01DE' => ['skill_use', 'S1 a4 a4 L1 L1 L1 l1 S1 S1 C1', [qw(skillID sourceID targetID tick src_speed dst_speed damage level param3 type)]],
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
		"Account ID: @<<<<<<<<< @<<<<<<<<<<", [unpack("L1",$accountID), getHex($accountID)],
		"Sex:        @<<<<<<<<<<<<<<<<<<<<<", [$sex_lut{$accountSex}],
		"Session ID: @<<<<<<<<< @<<<<<<<<<<", [unpack("L1",$sessionID), getHex($sessionID)],
		"            @<<<<<<<<< @<<<<<<<<<<", [unpack("L1",$sessionID2), getHex($sessionID2)],
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
sub character_looks {
	my ($self, $args) = @_;
	main::setStatus($args->{ID}, $args->{param1}, $args->{param2}, $args->{param3});
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
	error("Error logging into Game Login Server (invalid character specified)...\n", 'connection');
	$conState = 1;
	undef $conState_tries;
	$timeout_ex{master}{time} = time;
	$timeout_ex{master}{timeout} = $timeout{'reconnect'}{'timeout'};
	Network::disconnect(\$remote_socket);
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

sub received_sync {
    $conState = 5 if ($conState != 4 && $xkore);
    debug "Received Sync\n", 'parseMsg', 2;
    $timeout{'play'}{'time'} = time;
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
	my $disp = "$source $verb ".skillName($args->{skillID});
	$disp .= ' (lvl '.$$args->{level}.')' unless $$args->{level} == 65535;
	$disp .= " on $target";
	$disp .= ' - Dmg: '.$$args->{damage} unless $$args->{damage} == -30000;
	$disp .= " (delay ".($$args->{src_speed}/10).")";
	$disp .= "\n";

	if ($$args->{damage} != -30000 &&
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
		my $status = sprintf("[%3d/%3d] ", percent_hp($char), percent_sp($char));
		$disp = $status.$disp;
	}
	$target->{sitting} = 0 unless $args->{type} == 4 || $args->{type} == 9 || $args->{damage} == 0;

	message $disp, $domain, 1;

}

1;
