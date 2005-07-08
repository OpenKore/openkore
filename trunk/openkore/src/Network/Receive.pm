package Network::Receive;

use strict;
use Time::HiRes qw(time usleep);

use Globals;
use Actor;
use Actor::You;
use Actor::Player;
use Actor::Monster;
use Actor::Party;
use Actor::Unknown;
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
use AI;

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
		'006D' => ['character_creation_successful', 'a4 x4 V1 x62 Z24 C1 C1 C1 C1 C1 C1 C1', [qw(ID zenny name str agi vit int dex luk slot)]],
		'006E' => ['character_creation_failed'],
		'006F' => ['character_deletion_successful'],
		'0070' => ['character_deletion_failed'],
		'0071' => ['received_character_ID_and_Map', 'a4 a16 a4 v1', [qw(charID mapName mapIP mapPort)]],
		'0073' => ['map_loaded','x4 a3',[qw(coords)]],
		'0075' => ['change_to_constate5'],
		'0077' => ['change_to_constate5'],
		'0078' => ['actor_exists', 'a4 v1 v1 v1 v1 v1 C1 x1 v1 v1 v1 v1 v1 v1 x2 v1 V1 x7 C1 a3 x2 C1 v1', [qw(ID walk_speed param1 param2 param3 type pet weapon lowhead shield tophead midhead hair_color head_dir guildID sex coords act lv)]],
		'0079' => ['actor_connected', 'a4 v1 v1 v1 v1 v1 x2 v1 v1 v1 v1 v1 v1 x4 V1 x7 C1 a3 x2 v1', [qw(ID walk_speed param1 param2 param3 type weapon lowhead shield tophead midhead hair_color guildID sex coords lv)]],
		'007A' => ['change_to_constate5'],
		'007B' => ['actor_moved', 'a4 v1 v1 v1 v1 v1 C1 x1 v1 v1 x4 v1 v1 v1 v1 x4 V1 x7 C1 a5 x3 v1', [qw(ID walk_speed param1 param2 param3 type pet weapon lowhead shield tophead midhead hair_color guildID sex coords lv)]],
		'007C' => ['actor_spawned', 'a4 x14 v1 C1 x12 C1 a3', [qw(ID type pet sex coords)]],
		'007F' => ['received_sync', 'V1', [qw(time)]],
		'0080' => ['actor_died_or_disappeard', 'a4 C1', [qw(ID type)]],
		'0081' => ['errors', 'C1', [qw(type)]],
		'0087' => ['character_moves', 'x4 a5 C1', [qw(coords unknown)]],
		'0088' => ['actor_movement_interrupted', 'a4 v1 v1', [qw(ID x y)]],
		'008A' => ['actor_action', 'a4 a4 a4 V1 V1 s1 v1 C1 v1', [qw(sourceID targetID tick src_speed dst_speed damage param2 type param3)]],
		'008D' => ['public_message', 'x2 a4 a*', [qw(ID message)]],
		'008E' => ['self_chat', 'x2 a*', [qw(message)]],
		'0091' => ['map_change', 'Z16 v1 v1', [qw(map x y)]],
		'0092' => ['map_changed', 'Z16 x4 a4 v1', [qw(map IP port)]],
		'0095' => ['actor_info', 'a4 Z24', [qw(ID name)]],
		'0097' => ['private_message', 'x2 Z24', [qw(privMsgUser)]],
		'0098' => ['private_message_sent', 'C1', [qw(type)]],
		'009A' => ['system_chat', 'x2 Z*', [qw(message)]], #maybe use a* instead and $message =~ /\000$//; if there are problems
		'009C' => ['actor_look_at', 'a4 C1 x1 C1', [qw(ID head body)]],
		'009D' => ['item_exists', 'a4 v1 x1 v1 v1 v1', [qw(ID type x y amount)]],
		'009E' => ['item_appeared', 'a4 v1 x1 v1 v1 x2 v1', [qw(ID type x y amount)]],
		'00A0' => ['inventory_item_added', 'v1 v1 v1 C1 C1 C1 a8 v1 C1 C1', [qw(index amount nameID identified broken upgrade cards type_equip type fail)]],
		'00A1' => ['item_disappeared', 'a4', [qw(ID)]],
		'00EA' => ['deal_add', 'S1 C1', [qw(index fail)]],
		'00F4' => ['storage_item_added', 'v1 V1 v1 C1 C1 C1 a8', [qw(index amount ID identified broken upgrade cards)]],
		'0114' => ['skill_use', 'v1 a4 a4 V1 V1 V1 s1 v1 v1 C1', [qw(skillID sourceID targetID tick src_speed dst_speed damage level param3 type)]],
		'0119' => ['character_status', 'a4 v1 v1 v1', [qw(ID param1 param2 param3)]],
		'011A' => ['skill_used_no_damage', 'v1 v1 a4 a4 C1', [qw(skillID amount targetID sourceID fail)]],
		'011C' => ['warp_portal_list', 'v1 a16 a16 a16 a16', [qw(type memo1 memo2 memo3 memo4)]],
		'011E' => ['memo_success', 'C1', [qw(fail)]],
		'0121' => ['cart_info', 'v1 v1 V1 V1', [qw(items items_max weight weight_max)]],
		'012C' => ['cart_add_failed', 'C1', [qw(fail)]],
		'0124' => ['cart_item_added', 'v1 V1 v1 x C1 C1 C1 a8', [qw(index amount ID identified broken upgrade cards)]],
		'01B3' => ['npc_image', 'Z63 C1', [qw(npc_image type)]],
		'01C4' => ['storage_item_added', 'v1 V1 v1 x C1 C1 C1 a8', [qw(index amount ID identified broken upgrade cards)]],
		'01D8' => ['actor_exists', 'a4 v1 v1 v1 v1 v1 C1 x1 v1 v1 v1 v1 v1 v1 x2 v1 V1 x7 C1 a3 x2 C1 v1', [qw(ID walk_speed param1 param2 param3 type pet weapon shield lowhead tophead midhead hair_color head_dir guildID sex coords act lv)]],
		'01D9' => ['actor_connected', 'a4 v1 v1 v1 v1 v1 x2 v1 v1 v1 v1 v1 v1 x4 V1 x7 C1 a3 x2 v1', [qw(ID walk_speed param1 param2 param3 type weapon shield lowhead tophead midhead hair_color guildID sex coords lv)]],
		'01DA' => ['actor_moved', 'a4 v1 v1 v1 v1 v1 C1 x1 v1 v1 v1 x4 v1 v1 v1 x4 V1 x4 C1 x2 C1 a5 x3 v1', [qw(ID walk_speed param1 param2 param3 type pet weapon shield lowhead tophead midhead hair_color guildID skillstatus sex coords lv)]],
		'01DC' => ['secure_login_key', 'x2 a*', [qw(secure_key)]],
		'01DE' => ['skill_use', 'v1 a4 a4 V1 V1 V1 l1 v1 v1 C1', [qw(skillID sourceID targetID tick src_speed dst_speed damage level param3 type)]],
	};

	bless \%self, $class;
	return \%self;
}

sub create {
	my ($self, $type) = @_;
	$type = 0 if $type eq '';
	my $class = "Network::Receive::ServerType$type";

	undef $@;
	eval "use $class;";
	if ($@) {
		error "Cannot load packet parser for ServerType '$type'.\n";
		return;
	}

	return eval "new $class;";
}

sub parse {
	my ($self, $msg) = @_;

	my $switch = uc(unpack("H2", substr($msg, 1, 1))) . uc(unpack("H2", substr($msg, 0, 1)));
	my $handler = $self->{packet_list}{$switch};
	return 0 unless $handler;

	debug "Received packet: $switch Handler: $handler->[0]\n", "packetParser", 2;

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
		debug "Packet Parser: Unhandled Packet: $switch Handler: $handler->[0]\n", "packetParser", 2;
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

sub actor_action {
	my ($self,$args) = @_;
	$conState = 5 if ($conState != 4 && $xkore);

	if ($args->{type} == 1) {
		# Take item
		my $source = Actor::get($args->{sourceID});
		my $verb = $source->verb('pick up', 'picks up');
		#my $target = Actor::get($args->{targetID});
		my $target = getActorName($args->{targetID});
		debug "$source $verb $target\n", 'parseMsg_presence';
		$items{$args->{targetID}}{takenBy} = $args->{sourceID} if ($items{$args->{targetID}});
	} elsif ($args->{type} == 2) {
		# Sit
		my ($source, $verb) = getActorNames($args->{sourceID}, 0, 'are', 'is');
		if ($args->{sourceID} eq $accountID) {
			message "You are sitting.\n";
			$char->{sitting} = 1;
		} else {
			debug getActorName($args->{sourceID})." is sitting.\n", 'parseMsg';
			$players{$args->{sourceID}}{sitting} = 1 if ($players{$args->{sourceID}});
		}
	} elsif ($args->{type} == 3) {
		# Stand
		my ($source, $verb) = getActorNames($args->{sourceID}, 0, 'are', 'is');
		if ($args->{sourceID} eq $accountID) {
			message "You are standing.\n";
			$char->{sitting} = 0;
		} else {
			debug getActorName($args->{sourceID})." is standing.\n", 'parseMsg';
			$players{$args->{sourceID}}{sitting} = 0 if ($players{$args->{sourceID}});
		}
	} else {
		# Attack
		my $dmgdisplay;
		my $totalDamage = $args->{damage} + $args->{param3};
		if ($totalDamage == 0) {
			$dmgdisplay = "Miss!";
			$dmgdisplay .= "!" if ($args->{type} == 11);
		} else {
			$dmgdisplay = $args->{damage};
			$dmgdisplay .= "!" if ($args->{type} == 10);
			$dmgdisplay .= " + $args->{param3}" if $args->{param3};
		}

		updateDamageTables($args->{sourceID}, $args->{targetID}, $totalDamage);
		my $source = Actor::get($args->{sourceID});
		my $target = Actor::get($args->{targetID});
		my $verb = $source->verb('attack', 'attacks');

		$target->{sitting} = 0 unless $args->{type} == 4 || $args->{type} == 9 || $totalDamage == 0;

		my $msg = "$source $verb $target - Dmg: $dmgdisplay (delay ".($args->{src_speed}/10).")";

		Plugins::callHook('packet_attack', {sourceID => $args->{sourceID}, targetID => $args->{targetID}, msg => \$msg, dmg => $totalDamage});

		my $status = sprintf("[%3d/%3d]", percent_hp($char), percent_sp($char));

		if ($args->{sourceID} eq $accountID) {
			message("$status $msg\n", $totalDamage > 0 ? "attackMon" : "attackMonMiss");
			if ($startedattack) {
				$monstarttime = time();
				$monkilltime = time();
				$startedattack = 0;
			}
			calcStat($args->{damage});
		} elsif ($args->{targetID} eq $accountID) {
			# Check for monster with empty name
			if ($monsters{$args->{sourceID}} && %{$monsters{$args->{sourceID}}} && $monsters{$args->{sourceID}}{'name'} eq "") {
				if ($config{'teleportAuto_emptyName'} ne '0') {
					message "Monster with empty name attacking you. Teleporting...\n";
					useTeleport(1);
				} else {
					# Delete monster from hash; monster will be
					# re-added to the hash next time it moves.
					delete $monsters{$args->{sourceID}};
				}
			}
			message("$status $msg\n", $args->{damage} > 0 ? "attacked" : "attackedMiss");
		} else {
			debug("$msg\n", 'parseMsg_damage');
		}
	}
}

sub actor_connected {
	my ($self,$args) = @_;
	$conState = 5 if ($conState != 4 && $xkore);
	my %coords;
	makeCoords(\%coords, $args->{coords});

	if ($jobs_lut{$args->{type}}) {
		my $added;
		if (!UNIVERSAL::isa($players{$args->{ID}}, 'Actor')) {
			$players{$args->{ID}} = new Actor::Player();
			$players{$args->{ID}}{'appear_time'} = time;
			binAdd(\@playersID, $args->{ID});
			$players{$args->{ID}}{'ID'} = $args->{ID};
			$players{$args->{ID}}{'jobID'} = $args->{type};
			$players{$args->{ID}}{'sex'} = $args->{sex};
			$players{$args->{ID}}{'nameID'} = unpack("L1", $args->{ID});
			$players{$args->{ID}}{'binID'} = binFind(\@playersID, $args->{ID});
			$added = 1;
		}

		$players{$args->{ID}}{weapon} = $args->{weapon};
		$players{$args->{ID}}{shield} = $args->{shield};
		$players{$args->{ID}}{walk_speed} = $args->{walk_speed} / 1000;
		$players{$args->{ID}}{headgear}{low} = $args->{lowhead};
		$players{$args->{ID}}{headgear}{top} = $args->{tophead};
		$players{$args->{ID}}{headgear}{mid} = $args->{midhead};
		$players{$args->{ID}}{hair_color} = $args->{hair_color};
		$players{$args->{ID}}{guildID} = $args->{guildID};
		$players{$args->{ID}}{look}{body} = 0;
		$players{$args->{ID}}{look}{head} = 0;
		$players{$args->{ID}}{lv} = $args->{lv};
		$players{$args->{ID}}{pos} = {%coords};
		$players{$args->{ID}}{pos_to} = {%coords};
		my $domain = existsInList($config{friendlyAID}, unpack("L1", $args->{ID})) ? 'parseMsg_presence' : 'parseMsg_presence/player';
		debug "Player Connected: ".$players{$args->{ID}}->name." ($players{$args->{ID}}{'binID'}) Level $args->{lv} $sex_lut{$players{$args->{ID}}{'sex'}} $jobs_lut{$players{$args->{ID}}{'jobID'}}\n", $domain;
		setStatus($args->{ID}, $args->{param1}, $args->{param2}, $args->{param3});

		objectAdded('player', $args->{ID}, $players{$args->{ID}}) if ($added);

	} else {
		debug "Unknown Connected: $args->{type} - ", "parseMsg";
	}
}

sub actor_died_or_disappeard {
	my ($self,$args) = @_;
	$conState = 5 if ($conState != 4 && $xkore);

	if ($args->{ID} eq $accountID) {
		message "You have died\n";
		closeShop() unless !$shopstarted || $config{'dcOnDeath'} == -1 || !$AI;
		$char->{deathCount}++;
		$char->{dead} = 1;
		$char->{dead_time} = time;

	} elsif ($monsters{$args->{ID}} && %{$monsters{$args->{ID}}}) {
		%{$monsters_old{$args->{ID}}} = %{$monsters{$args->{ID}}};
		$monsters_old{$args->{ID}}{'gone_time'} = time;
		if ($args->{type} == 0) {
			debug "Monster Disappeared: $monsters{$args->{ID}}{'name'} ($monsters{$args->{ID}}{'binID'})\n", "parseMsg_presence";
			$monsters_old{$args->{ID}}{'disappeared'} = 1;

		} elsif ($args->{type} == 1) {
			debug "Monster Died: $monsters{$args->{ID}}{'name'} ($monsters{$args->{ID}}{'binID'})\n", "parseMsg_damage";
			$monsters_old{$args->{ID}}{'dead'} = 1;

			if ($config{itemsTakeAuto_party} &&
			    ($monsters{$args->{ID}}{dmgFromParty} > 0 ||
			     $monsters{$args->{ID}}{dmgFromYou} > 0)) {
				AI::clear("items_take");
				ai_items_take($monsters{$args->{ID}}{pos}{x}, $monsters{$args->{ID}}{pos}{y},
					$monsters{$args->{ID}}{pos_to}{x}, $monsters{$args->{ID}}{pos_to}{y});
			}

		} elsif ($args->{type} == 2) { # What's this?
			debug "Monster Disappeared: $monsters{$args->{ID}}{'name'} ($monsters{$args->{ID}}{'binID'})\n", "parseMsg_presence";
			$monsters_old{$args->{ID}}{'disappeared'} = 1;

		} elsif ($args->{type} == 3) {
			debug "Monster Teleported: $monsters{$args->{ID}}{'name'} ($monsters{$args->{ID}}{'binID'})\n", "parseMsg_presence";
			$monsters_old{$args->{ID}}{'teleported'} = 1;
		}
		binRemove(\@monstersID, $args->{ID});
		objectRemoved('monster', $args->{ID}, $monsters{$args->{ID}});
		delete $monsters{$args->{ID}};

	} elsif (UNIVERSAL::isa($players{$args->{ID}}, 'Actor')) {
		if ($args->{type} == 1) {
			message "Player Died: ".$players{$args->{ID}}->name." ($players{$args->{ID}}{'binID'}) $sex_lut{$players{$args->{ID}}{'sex'}} $jobs_lut{$players{$args->{ID}}{'jobID'}}\n";
			$players{$args->{ID}}{'dead'} = 1;
		} else {
			if ($args->{type} == 0) {
				debug "Player Disappeared: ".$players{$args->{ID}}->name." ($players{$args->{ID}}{'binID'}) $sex_lut{$players{$args->{ID}}{'sex'}} $jobs_lut{$players{$args->{ID}}{'jobID'}}\n", "parseMsg_presence";
				$players{$args->{ID}}{'disappeared'} = 1;
			} elsif ($args->{type} == 2) {
				debug "Player Disconnected: ".$players{$args->{ID}}->name." ($players{$args->{ID}}{'binID'}) $sex_lut{$players{$args->{ID}}{'sex'}} $jobs_lut{$players{$args->{ID}}{'jobID'}}\n", "parseMsg_presence";
				$players{$args->{ID}}{'disconnected'} = 1;
			} elsif ($args->{type} == 3) {
				debug "Player Teleported: ".$players{$args->{ID}}->name." ($players{$args->{ID}}{'binID'}) $sex_lut{$players{$args->{ID}}{'sex'}} $jobs_lut{$players{$args->{ID}}{'jobID'}}\n", "parseMsg_presence";
				$players{$args->{ID}}{'teleported'} = 1;
			} else {
				debug "Player Disappeared in an unknown way: ".$players{$args->{ID}}->name." ($players{$args->{ID}}{'binID'}) $sex_lut{$players{$args->{ID}}{'sex'}} $jobs_lut{$players{$args->{ID}}{'jobID'}}\n", "parseMsg_presence";
				$players{$args->{ID}}{'disappeared'} = 1;
			}

			%{$players_old{$args->{ID}}} = %{$players{$args->{ID}}};
			$players_old{$args->{ID}}{'gone_time'} = time;
			binRemove(\@playersID, $args->{ID});
			objectRemoved('player', $args->{ID}, $players{$args->{ID}});
			delete $players{$args->{ID}};

			binRemove(\@venderListsID, $args->{ID});
			delete $venderLists{$args->{ID}};
		}

	} elsif ($players_old{$args->{ID}} && %{$players_old{$args->{ID}}}) {
		if ($args->{type} == 2) {
			debug "Player Disconnected: $players_old{$args->{ID}}{'name'}\n", "parseMsg_presence";
			$players_old{$args->{ID}}{'disconnected'} = 1;
		} elsif ($args->{type} == 3) {
			debug "Player Teleported: $players_old{$args->{ID}}{'name'}\n", "parseMsg_presence";
			$players_old{$args->{ID}}{'teleported'} = 1;
		}

	} elsif ($portals{$args->{ID}} && %{$portals{$args->{ID}}}) {
		debug "Portal Disappeared: $portals{$args->{ID}}{'name'} ($portals{$args->{ID}}{'binID'})\n", "parseMsg";
		$portals_old{$args->{ID}} = {%{$portals{$args->{ID}}}};
		$portals_old{$args->{ID}}{'disappeared'} = 1;
		$portals_old{$args->{ID}}{'gone_time'} = time;
		binRemove(\@portalsID, $args->{ID});
		delete $portals{$args->{ID}};

	} elsif ($npcs{$args->{ID}} && %{$npcs{$args->{ID}}}) {
		debug "NPC Disappeared: $npcs{$args->{ID}}{'name'} ($npcs{$args->{ID}}{'binID'})\n", "parseMsg";
		%{$npcs_old{$args->{ID}}} = %{$npcs{$args->{ID}}};
		$npcs_old{$args->{ID}}{'disappeared'} = 1;
		$npcs_old{$args->{ID}}{'gone_time'} = time;
		binRemove(\@npcsID, $args->{ID});
		objectRemoved('npc', $args->{ID}, $npcs{$args->{ID}});
		delete $npcs{$args->{ID}};

	} elsif ($pets{$args->{ID}} && %{$pets{$args->{ID}}}) {
		debug "Pet Disappeared: $pets{$args->{ID}}{'name'} ($pets{$args->{ID}}{'binID'})\n", "parseMsg";
		binRemove(\@petsID, $args->{ID});
		delete $pets{$args->{ID}};
	} else {
		debug "Unknown Disappeared: ".getHex($args->{ID})."\n", "parseMsg";
	}
}

sub actor_exists {
	# 0078: long ID, word speed, word state, word ailment, word look, word
	# class, word hair, word weapon, word head_option_bottom, word shield,
	# word head_option_top, word head_option_mid, word hair_color, word ?,
	# word head_dir, long guild, long emblem, word manner, byte karma, byte
	# sex, 3byte coord, byte body_dir, byte ?, byte ?, byte sitting, word
	# level
	my ($self,$args) = @_;
	$conState = 5 if ($conState != 4 && $xkore);
	my %coords;
	makeCoords(\%coords, $args->{coords});
	debug ("$coords{x}x$coords{y}\n");
	$args->{body_dir} = unpack("v", substr($args->{RAW_MSG}, 48, 1)) % 8;
	my $added;

	if ($jobs_lut{$args->{type}}) {
		my $player = $players{$args->{ID}};
		if (!UNIVERSAL::isa($player, 'Actor')) {
			$player = $players{$args->{ID}} = new Actor::Player();
			binAdd(\@playersID, $args->{ID});
			$player->{appear_time} = time;
			$player->{ID} = $args->{ID};
			$player->{jobID} = $args->{type};
			$player->{sex} = $args->{sex};
			$player->{nameID} = unpack("L1", $args->{ID});
			$player->{binID} = binFind(\@playersID, $args->{ID});
			$added = 1;
		}

		$player->{walk_speed} = $args->{walk_speed} / 1000;
		$player->{headgear}{low} = $args->{lowhead};
		$player->{headgear}{top} = $args->{tophead};
		$player->{headgear}{mid} = $args->{midhead};
		$player->{hair_color} = $args->{hair_color};
		$player->{look}{body} = $args->{body_dir};
		$player->{look}{head} = $args->{head_dir};
		$player->{weapon} = $args->{weapon};
		$player->{shield} = $args->{shield};
		$player->{guildID} = $args->{guildID};
		if ($args->{act} == 1) {
			$player->{dead} = 1;
		} elsif ($args->{act} == 2) {
			$player->{sitting} = 1;
		}
		$player->{lv} = $args->{lv};
		$player->{pos} = {%coords};
		$player->{pos_to} = {%coords};
		my $domain = existsInList($config{friendlyAID}, unpack("L1", $player->{ID})) ? 'parseMsg_presence' : 'parseMsg_presence/player';
		debug "Player Exists: ".$player->name." ($player->{binID}) Level $args->{lv} ".$sex_lut{$player->{sex}}." $jobs_lut{$player->{jobID}}\n", $domain, 1;
		setStatus($args->{ID},$args->{param1},$args->{param2},$args->{param3});

		objectAdded('player', $args->{ID}, $player) if ($added);

		Plugins::callHook('player', {player => $player});

	} elsif ($args->{type} >= 1000) {
		if ($args->{pet}) {
			if (!$pets{$args->{ID}}{$args->{ID}} || !%{$pets{$args->{ID}}{$args->{ID}}}) {
				$pets{$args->{ID}}{$args->{ID}}{'appear_time'} = time;
				my $display = ($monsters_lut{$args->{type}} ne "")
						? $monsters_lut{$args->{type}}
						: "Unknown ".$args->{type};
				binAdd(\@petsID, $args->{ID});
				$pets{$args->{ID}}{$args->{ID}}{'nameID'} = $args->{type};
				$pets{$args->{ID}}{$args->{ID}}{'name'} = $display;
				$pets{$args->{ID}}{$args->{ID}}{'name_given'} = "Unknown";
				$pets{$args->{ID}}{$args->{ID}}{'binID'} = binFind(\@petsID, $args->{ID});
				$added = 1;
			}
			$pets{$args->{ID}}{$args->{ID}}{'walk_speed'} = $args->{walk_speed} / 1000;
			%{$pets{$args->{ID}}{$args->{ID}}{'pos'}} = %coords;
			%{$pets{$args->{ID}}{$args->{ID}}{'pos_to'}} = %coords;
			debug "Pet Exists: $pets{$args->{ID}}{$args->{ID}}{'name'} ($pets{$args->{ID}}{$args->{ID}}{'binID'})\n", "parseMsg";

			if ($monsters{$args->{ID}}) {
				binRemove(\@monstersID, $args->{ID});
				objectRemoved('monster', $args->{ID}, $monsters{$args->{ID}});
				delete $monsters{$args->{ID}};
			}

			objectAdded('pet', $args->{ID}, $pets{$args->{ID}}{$args->{ID}}) if ($added);

		} else {
			if (!$monsters{$args->{ID}} || !%{$monsters{$args->{ID}}}) {
				$monsters{$args->{ID}} = new Actor::Monster();
				$monsters{$args->{ID}}{'appear_time'} = time;
				my $display = ($monsters_lut{$args->{type}} ne "")
						? $monsters_lut{$args->{type}}
						: "Unknown ".$args->{type};
				binAdd(\@monstersID, $args->{ID});
				$monsters{$args->{ID}}{ID} = $args->{ID};
				$monsters{$args->{ID}}{'nameID'} = $args->{type};
				$monsters{$args->{ID}}{'name'} = $display;
				$monsters{$args->{ID}}{'binID'} = binFind(\@monstersID, $args->{ID});
				$added = 1;
			}
			$monsters{$args->{ID}}{'walk_speed'} = $args->{walk_speed} / 1000;
			%{$monsters{$args->{ID}}{'pos'}} = %coords;
			%{$monsters{$args->{ID}}{'pos_to'}} = %coords;

			debug "Monster Exists: $monsters{$args->{ID}}{'name'} ($monsters{$args->{ID}}{'binID'})\n", "parseMsg_presence", 1;


			# Monster state
			$args->{param1} = 0 if $args->{param1} == 5; # 5 has got something to do with the monster being undead
			setStatus($args->{ID},$args->{param1},$args->{param2},$args->{param3});

			objectAdded('monster', $args->{ID}, $monsters{$args->{ID}}) if ($added);
		}

	} elsif ($args->{type} == 45) {
		if (!$portals{$args->{ID}} || !%{$portals{$args->{ID}}}) {
			$portals{$args->{ID}}{'appear_time'} = time;
			my $nameID = unpack("L1", $args->{ID});
			my $exists = portalExists($field{'name'}, \%coords);
			my $display = ($exists ne "")
				? "$portals_lut{$exists}{'source'}{'map'} -> " . getPortalDestName($exists)
				: "Unknown ".$nameID;
			binAdd(\@portalsID, $args->{ID});
			$portals{$args->{ID}}{'source'}{'map'} = $field{'name'};
			$portals{$args->{ID}}{'type'} = $args->{type};
			$portals{$args->{ID}}{'nameID'} = $nameID;
			$portals{$args->{ID}}{'name'} = $display;
			$portals{$args->{ID}}{'binID'} = binFind(\@portalsID, $args->{ID});
		}
		%{$portals{$args->{ID}}{'pos'}} = %coords;
		message "Portal Exists: $portals{$args->{ID}}{'name'} ($coords{x}, $coords{y}) - ($portals{$args->{ID}}{'binID'})\n", "portals", 1;

	} elsif ($args->{type} < 1000) {
		if (!$npcs{$args->{ID}} || !%{$npcs{$args->{ID}}}) {
			my $nameID = unpack("L1", $args->{ID});
			$npcs{$args->{ID}}{'appear_time'} = time;

			$npcs{$args->{ID}}{pos} = {%coords};
			my $location = "$field{name} $npcs{$args->{ID}}{pos}{x} $npcs{$args->{ID}}{pos}{y}";
			my $display = $npcs_lut{$location} || "Unknown ".$nameID;
			binAdd(\@npcsID, $args->{ID});
			$npcs{$args->{ID}}{'type'} = $args->{type};
			$npcs{$args->{ID}}{'nameID'} = $nameID;
			$npcs{$args->{ID}}{'name'} = $display;
			$npcs{$args->{ID}}{'binID'} = binFind(\@npcsID, $args->{ID});
			$added = 1;
		} else {
			$npcs{$args->{ID}}{pos} = {%coords};
		}
		message "NPC Exists: $npcs{$args->{ID}}{'name'} ($npcs{$args->{ID}}{pos}{x}, $npcs{$args->{ID}}{pos}{y}) (ID $npcs{$args->{ID}}{'nameID'}) - ($npcs{$args->{ID}}{'binID'})\n", undef, 1;

		objectAdded('npc', $args->{ID}, $npcs{$args->{ID}}) if ($added);

	} else {
		debug "Unknown Exists: $args->{type} - ".unpack("L*",$args->{ID})."\n", "parseMsg";
	}
}

sub actor_info {
	my ($self,$args) = @_;
	$conState = 5 if ($conState != 4 && $xkore);
	if ($players{$args->{ID}} && %{$players{$args->{ID}}}) {
		($players{$args->{ID}}{'name'}) = $args->{name};
		$players{$args->{ID}}{'gotName'} = 1;
		my $binID = binFind(\@playersID, $args->{ID});
		debug "Player Info: $players{$args->{ID}}{'name'} ($binID)\n", "parseMsg_presence", 2;
	}
	if ($monsters{$args->{ID}} && %{$monsters{$args->{ID}}}) {
		my ($name) = $args->{name};
		if ($config{'debug'} >= 2) {
			my $binID = binFind(\@monstersID, $args->{ID});
			debug "Monster Info: $name ($binID)\n", "parseMsg", 2;
		}
		if ($monsters_lut{$monsters{$args->{ID}}{'nameID'}} eq "") {
			$monsters{$args->{ID}}{'name'} = $name;
			$monsters_lut{$monsters{$args->{ID}}{'nameID'}} = $monsters{$args->{ID}}{'name'};
			updateMonsterLUT("$Settings::tables_folder/monsters.txt", $monsters{$args->{ID}}{'nameID'}, $monsters{$args->{ID}}{'name'});
		}
	}
	if ($npcs{$args->{ID}} && %{$npcs{$args->{ID}}}) {
		($npcs{$args->{ID}}{'name'}) = $args->{name};
		$npcs{$args->{ID}}{'gotName'} = 1;
		if ($config{'debug'} >= 2) {
			my $binID = binFind(\@npcsID, $args->{ID});
			debug "NPC Info: $npcs{$args->{ID}}{'name'} ($binID)\n", "parseMsg", 2;
		}
		my $location = "$field{name} $npcs{$args->{ID}}{pos}{x} $npcs{$args->{ID}}{pos}{y}";
		if (!$npcs_lut{$location}) {
			$npcs_lut{$location} = $npcs{$args->{ID}}{name};
			updateNPCLUT("$Settings::tables_folder/npcs.txt", $location, $npcs{$args->{ID}}{name});
		}
	}
	if ($pets{$args->{ID}} && %{$pets{$args->{ID}}}) {
		($pets{$args->{ID}}{'name_given'}) = $args->{name};
		if ($config{'debug'} >= 2) {
			my $binID = binFind(\@petsID, $args->{ID});
			debug "Pet Info: $pets{$args->{ID}}{'name_given'} ($binID)\n", "parseMsg", 2;
		}
	}
}

sub actor_look_at {
	my ($self,$args) = @_;
	$conState = 5 if ($conState != 4 && $xkore);
	if ($args->{ID} eq $accountID) {
		$chars[$config{'char'}]{'look'}{'head'} = $args->{head};
		$chars[$config{'char'}]{'look'}{'body'} = $args->{body};
		debug "You look at $args->{body}, $args->{head}\n", "parseMsg", 2;

	} elsif ($players{$args->{ID}} && %{$players{$args->{ID}}}) {
		$players{$args->{ID}}{'look'}{'head'} = $args->{head};
		$players{$args->{ID}}{'look'}{'body'} = $args->{body};
		debug "Player $players{$args->{ID}}{'name'} ($players{$args->{ID}}{'binID'}) looks at $players{$args->{ID}}{'look'}{'body'}, $players{$args->{ID}}{'look'}{'head'}\n", "parseMsg";

	} elsif ($monsters{$args->{ID}} && %{$monsters{$args->{ID}}}) {
		$monsters{$args->{ID}}{'look'}{'head'} = $args->{head};
		$monsters{$args->{ID}}{'look'}{'body'} = $args->{body};
		debug "Monster $monsters{$args->{ID}}{'name'} ($monsters{$args->{ID}}{'binID'}) looks at $monsters{$args->{ID}}{'look'}{'body'}, $monsters{$args->{ID}}{'look'}{'head'}\n", "parseMsg";
	}
}

sub actor_moved {
	my ($self,$args) = @_;

	my (%coordsFrom, %coordsTo);
	makeCoords(\%coordsFrom, substr($args->{RAW_MSG}, 50, 3));
	makeCoords2(\%coordsTo, substr($args->{RAW_MSG}, 52, 3));

	#my %statuses = {
	#	1 => 'Twohand Quicken',
	#	4 => 'Energy Coat'
	#};
	#debug "actor has status $statuses{$args->{skillstatus}}\n";

	my $added;
	my %vec;
	getVector(\%vec, \%coordsTo, \%coordsFrom);
	my $direction = int sprintf("%.0f", (360 - vectorToDegree(\%vec)) / 45);

	if ($jobs_lut{$args->{type}}) {
		my $player = $players{$args->{ID}};
		if (!UNIVERSAL::isa($players{$args->{ID}}, 'Actor')) {
			$players{$args->{ID}} = $player = new Actor::Player();
			binAdd(\@playersID, $args->{ID});
			$player->{appear_time} = time;
			$player->{sex} = $args->{sex};
			$player->{ID} = $args->{ID};
			$player->{jobID} = $args->{type};
			$player->{nameID} = unpack("L1", $args->{ID});
			$player->{binID} = binFind(\@playersID, $args->{ID});
			my $domain = existsInList($config{friendlyAID}, unpack("L1", $args->{ID})) ? 'parseMsg_presence' : 'parseMsg_presence/player';
			debug "Player Appeared: ".$player->name." ($player->{'binID'}) Level $args->{lv} $sex_lut{$args->{sex}} $jobs_lut{$args->{type}}\n", $domain;
			$added = 1;
			Plugins::callHook('player', {player => $player});
		}

		$player->{weapon} = $args->{weapon};
		$player->{shield} = $args->{shield};
		$player->{walk_speed} = $args->{walk_speed} / 1000;
		$player->{look}{head} = 0;
		$player->{look}{body} = $direction;
		$player->{headgear}{low} = $args->{lowhead};
		$player->{headgear}{top} = $args->{tophead};
		$player->{headgear}{mid} = $args->{midhead};
		$player->{hair_color} = $args->{hair_color};
		$player->{lv} = $args->{lv};
		$player->{guildID} = $args->{guildID};
		$player->{pos} = {%coordsFrom};
		$player->{pos_to} = {%coordsTo};
		$player->{time_move} = time;
		$player->{time_move_calc} = distance(\%coordsFrom, \%coordsTo) * $player->{walk_speed};
		debug "Player Moved: ".$player->name." ($player->{'binID'}) $sex_lut{$player->{'sex'}} $jobs_lut{$player->{'jobID'}}\n", "parseMsg";
		setStatus($args->{ID}, $args->{param1}, $args->{param2}, $args->{param3});

		objectAdded('player', $args->{ID}, $player) if ($added);

	} elsif ($args->{type} >= 1000) {
		if ($args->{pet}) {
			my $pet = $pets{$args->{ID}} ||= {};
			if (!%{$pets{$args->{ID}}}) {
				$pet->{'appear_time'} = time;
				my $display = ($monsters_lut{$args->{type}} ne "")
						? $monsters_lut{$args->{type}}
						: "Unknown ".$args->{type};
				binAdd(\@petsID, $args->{ID});
				$pet->{'nameID'} = $args->{type};
				$pet->{'name'} = $display;
				$pet->{'name_given'} = "Unknown";
				$pet->{'binID'} = binFind(\@petsID, $args->{ID});
			}
			$pet->{look}{head} = 0;
			$pet->{look}{body} = $direction;
			$pet->{pos} = {%coordsFrom};
			$pet->{pos_to} = {%coordsTo};
			$pet->{time_move} = time;
			$pet->{walk_speed} = $args->{walk_speed} / 1000;
			$pet->{time_move_calc} = distance(\%coordsFrom, \%coordsTo) * $pet->{walk_speed};

			if ($monsters{$args->{ID}}) {
				binRemove(\@monstersID, $args->{ID});
				objectRemoved('monster', $args->{ID}, $monsters{$args->{ID}});
				delete $monsters{$args->{ID}};
			}

			debug "Pet Moved: $pet->{name} ($pet->{binID})\n", "parseMsg";

		} else {
			if (!$monsters{$args->{ID}} || !%{$monsters{$args->{ID}}}) {
				$monsters{$args->{ID}} = new Actor::Monster();
				binAdd(\@monstersID, $args->{ID});
				$monsters{$args->{ID}}{ID} = $args->{ID};
				$monsters{$args->{ID}}{'appear_time'} = time;
				$monsters{$args->{ID}}{'nameID'} = $args->{type};
				my $display = ($monsters_lut{$args->{type}} ne "")
					? $monsters_lut{$args->{type}}
					: "Unknown ".$args->{type};
				$monsters{$args->{ID}}{'name'} = $display;
				$monsters{$args->{ID}}{'binID'} = binFind(\@monstersID, $args->{ID});
				debug "Monster Appeared: $monsters{$args->{ID}}{'name'} ($monsters{$args->{ID}}{'binID'})\n", "parseMsg_presence";
				$added = 1;
			}
			$monsters{$args->{ID}}{look}{head} = 0;
			$monsters{$args->{ID}}{look}{body} = $direction;
			$monsters{$args->{ID}}{pos} = {%coordsFrom};
			$monsters{$args->{ID}}{pos_to} = {%coordsTo};
			$monsters{$args->{ID}}{time_move} = time;
			$monsters{$args->{ID}}{time_move_calc} = distance(\%coordsFrom, \%coordsTo) * ($args->{walk_speed} / 1000);
			$monsters{$args->{ID}}{walk_speed} = $args->{walk_speed} / 1000;
			debug "Monster Moved: $monsters{$args->{ID}}{'name'} ($monsters{$args->{ID}}{'binID'})\n", "parseMsg", 2;
			setStatus($args->{ID}, $args->{param1}, $args->{param2}, $args->{param3});

			objectAdded('monster', $args->{ID}, $monsters{$args->{ID}}) if ($added);
		}
	} else {
		debug "Unknown Moved: $args->{type} - ".getHex($args->{ID})."\n", "parseMsg";
	}
}

sub actor_movement_interrupted {
	my ($self,$args) = @_;
	my %coords;
	$coords{x} = $args->{x};
	$coords{y} = $args->{y};
	if ($args->{ID} eq $accountID) {
		%{$chars[$config{'char'}]{'pos'}} = %coords;
		%{$chars[$config{'char'}]{'pos_to'}} = %coords;
		$char->{sitting} = 0;
		debug "Movement interrupted, your coordinates: $coords{x}, $coords{y}\n", "parseMsg_move";
		AI::clear("move");
	} elsif ($monsters{$args->{ID}}) {
		%{$monsters{$args->{ID}}{pos}} = %coords;
		%{$monsters{$args->{ID}}{pos_to}} = %coords;
		$monsters{$args->{ID}}{sitting} = 0;
	} elsif ($players{$args->{ID}}) {
		%{$players{$args->{ID}}{pos}} = %coords;
		%{$players{$args->{ID}}{pos_to}} = %coords;
		$players{$args->{ID}}{sitting} = 0;
	}
}

sub actor_spawned {
	my ($self,$args) = @_;
	$conState = 5 if ($conState != 4 && $xkore);
	my %coords;
	makeCoords(\%coords, $args->{coords});
	my $added;

	if ($jobs_lut{$args->{type}}) {
		if (!UNIVERSAL::isa($players{$args->{ID}}, 'Actor')) {
			$players{$args->{ID}} = new Actor::Player();
			binAdd(\@playersID, $args->{ID});
			$players{$args->{ID}}{'jobID'} = $args->{type};
			$players{$args->{ID}}{'sex'} = $args->{sex};
			$players{$args->{ID}}{'ID'} = $args->{ID};
			$players{$args->{ID}}{'nameID'} = unpack("L1", $args->{ID});
			$players{$args->{ID}}{'appear_time'} = time;
			$players{$args->{ID}}{'binID'} = binFind(\@playersID, $args->{ID});
			$added = 1;
		}
		$players{$args->{ID}}{look}{head} = 0;
		$players{$args->{ID}}{look}{body} = 0;
		$players{$args->{ID}}{pos} = {%coords};
		$players{$args->{ID}}{pos_to} = {%coords};
		debug "Player Spawned: ".$players{$args->{ID}}->name." ($players{$args->{ID}}{'binID'}) $sex_lut{$players{$args->{ID}}{'sex'}} $jobs_lut{$players{$args->{ID}}{'jobID'}}\n", "parseMsg";

		objectAdded('player', $args->{ID}, $players{$args->{ID}}) if ($added);

	} elsif ($args->{type} >= 1000) {
		if ($args->{pet}) {
			if (!$pets{$args->{ID}} || !%{$pets{$args->{ID}}}) {
				binAdd(\@petsID, $args->{ID});
				$pets{$args->{ID}}{'nameID'} = $args->{type};
				$pets{$args->{ID}}{'appear_time'} = time;
				my $display = ($monsters_lut{$pets{$args->{ID}}{'nameID'}} ne "")
				? $monsters_lut{$pets{$args->{ID}}{'nameID'}}
				: "Unknown ".$pets{$args->{ID}}{'nameID'};
				$pets{$args->{ID}}{'name'} = $display;
				$pets{$args->{ID}}{'name_given'} = "Unknown";
				$pets{$args->{ID}}{'binID'} = binFind(\@petsID, $args->{ID});
			}
			$pets{$args->{ID}}{look}{head} = 0;
			$pets{$args->{ID}}{look}{body} = 0;
			%{$pets{$args->{ID}}{'pos'}} = %coords;
			%{$pets{$args->{ID}}{'pos_to'}} = %coords;
			debug "Pet Spawned: $pets{$args->{ID}}{'name'} ($pets{$args->{ID}}{'binID'})\n", "parseMsg";

			if ($monsters{$args->{ID}}) {
				binRemove(\@monstersID, $args->{ID});
				objectRemoved('monster', $args->{ID}, $monsters{$args->{ID}});
				delete $monsters{$args->{ID}};
			}

		} else {
			if (!$monsters{$args->{ID}} || !%{$monsters{$args->{ID}}}) {
				$monsters{$args->{ID}} = new Actor::Monster();
				binAdd(\@monstersID, $args->{ID});
				$monsters{$args->{ID}}{ID} = $args->{ID};
				$monsters{$args->{ID}}{'nameID'} = $args->{type};
				$monsters{$args->{ID}}{'appear_time'} = time;
				my $display = ($monsters_lut{$monsters{$args->{ID}}{'nameID'}} ne "")
						? $monsters_lut{$monsters{$args->{ID}}{'nameID'}}
						: "Unknown ".$monsters{$args->{ID}}{'nameID'};
				$monsters{$args->{ID}}{'name'} = $display;
				$monsters{$args->{ID}}{'binID'} = binFind(\@monstersID, $args->{ID});
				$added = 1;
			}
			$monsters{$args->{ID}}{look}{head} = 0;
			$monsters{$args->{ID}}{look}{body} = 0;
			%{$monsters{$args->{ID}}{'pos'}} = %coords;
			%{$monsters{$args->{ID}}{'pos_to'}} = %coords;
			debug "Monster Spawned: $monsters{$args->{ID}}{'name'} ($monsters{$args->{ID}}{'binID'})\n", "parseMsg_presence";

			objectAdded('monster', $args->{ID}, $monsters{$args->{ID}}) if ($added);
		}

	} else {
		debug "Unknown Spawned: $args->{type} - ".getHex($args->{ID})."\n", "parseMsg_presence";
	}
}

sub cart_info {
	my ($self, $args) = @_;

	$cart{items} = $args->{items};
	$cart{items_max} = $args->{items_max};
	$cart{weight} = int($args->{weight} / 10);
	$cart{weight_max} = int($args->{weight_max} / 10);
}

sub cart_add_failed {
	my ($self, $args) = @_;

	my $reason;
	if ($args->{fail} == 0) {
		$reason = 'overweight';
	} elsif ($args->{fail} == 1) {
		$reason = 'too many items';
	} else {
		$reason = "Unknown code $args->{fail}";
	}
	error "Can't Add Cart Item ($reason)\n";
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

sub character_deletion_successful {
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
	}
}

sub character_deletion_failed {
	error "Character cannot be deleted. Your e-mail address was probably wrong.\n";
	undef $AI::temp::delIndex;
	if (charSelectScreen() == 1) {
		$conState = 3;
		$firstLoginMap = 1;
		$startingZenny = $chars[$config{'char'}]{'zenny'} unless defined $startingZenny;
		$sentWelcomeMessage = 1;
	}
}

sub character_moves {
	my ($self,$args) = @_;
	$conState = 5 if ($conState != 4 && $xkore);
	makeCoords($char->{pos}, substr($args->{RAW_MSG}, 6, 3));
	makeCoords2($char->{pos_to}, substr($args->{RAW_MSG}, 8, 3));
	my $dist = sprintf("%.1f", distance($char->{pos}, $char->{pos_to}));
	debug "You're moving from ($char->{pos}{x}, $char->{pos}{y}) to ($char->{pos_to}{x}, $char->{pos_to}{y}) - distance $dist, unknown $args->{unknown}\n", "parseMsg_move";
	$char->{time_move} = time;
	$char->{time_move_calc} = distance($char->{pos}, $char->{pos_to}) * (($char->{walk_speed} / 1000) || 0.12);
}

sub character_status {
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

sub item_appeared {
	my ($self,$args) = @_;
	$conState = 5 if ($conState != 4 && $xkore);
	my $item = $items{$args->{ID}} ||= {};
	if (!$item || !%{$item}) {
		binAdd(\@itemsID, $args->{ID});
		$item->{appear_time} = time;
		$item->{amount} = $args->{amount};
		$item->{nameID} = $args->{type};
		$item->{binID} = binFind(\@itemsID, $args->{ID});
		$item->{name} = itemName($item);
	}
	$item->{pos}{x} = $args->{x};
	$item->{pos}{y} = $args->{y};

	# Take item as fast as possible
	if ($AI && $itemsPickup{lc($item->{name})} == 2 && distance($item->{pos}, $char->{pos_to}) <= 5) {
		sendTake(\$remote_socket, $args->{ID});
	}

	message "Item Appeared: $item->{name} ($item->{binID}) x $item->{amount} ($args->{x}, $args->{y})\n", "drop", 1;

}

sub item_exists {
	my ($self,$args) = @_;
	$conState = 5 if ($conState != 4 && $xkore);
	if (!$items{$args->{ID}} || !%{$items{$args->{ID}}}) {
		binAdd(\@itemsID, $args->{ID});
		$items{$args->{ID}}{'appear_time'} = time;
		$items{$args->{ID}}{'amount'} = $args->{amount};
		$items{$args->{ID}}{'nameID'} = $args->{type};
		$items{$args->{ID}}{'binID'} = binFind(\@itemsID, $args->{ID});
		$items{$args->{ID}}{'name'} = itemName($items{$args->{ID}});
	}
	$items{$args->{ID}}{'pos'}{'x'} = $args->{x};
	$items{$args->{ID}}{'pos'}{'y'} = $args->{y};
	message "Item Exists: $items{$args->{ID}}{'name'} ($items{$args->{ID}}{'binID'}) x $items{$args->{ID}}{'amount'}\n", "drop", 1;
}

sub item_disappeared {
	my ($self,$args) = @_;
	$conState = 5 if ($conState != 4 && $xkore);
	if ($items{$args->{ID}} && %{$items{$args->{ID}}}) {
		debug "Item Disappeared: $items{$args->{ID}}{'name'} ($items{$args->{ID}}{'binID'})\n", "parseMsg_presence";
		%{$items_old{$args->{ID}}} = %{$items{$args->{ID}}};
		$items_old{$args->{ID}}{'disappeared'} = 1;
		$items_old{$args->{ID}}{'gone_time'} = time;
		delete $items{$args->{ID}};
		binRemove(\@itemsID, $args->{ID});
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

sub map_change {
	my ($self,$args) = @_;
	$conState = 4 if ($conState != 4 && $xkore);

	($ai_v{temp}{map}) = $args->{map} =~ /([\s\S]*)\./;
	checkAllowedMap($ai_v{temp}{map});
	if ($ai_v{temp}{map} ne $field{name}) {
		getField($ai_v{temp}{map}, \%field);
	}

	main::initMapChangeVars();
	for (my $i = 0; $i < @ai_seq; $i++) {
		ai_setMapChanged($i);
	}
	$ai_v{'portalTrace_mapChanged'} = 1;

	my %coords;
	$coords{'x'} = $args->{x};
	$coords{'y'} = $args->{y};
	$chars[$config{char}]{pos} = {%coords};
	$chars[$config{char}]{pos_to} = {%coords};
	message "Map Change: $args->{map} ($chars[$config{'char'}]{'pos'}{'x'}, $chars[$config{'char'}]{'pos'}{'y'})\n", "connection";
	if ($xkore) {
		ai_clientSuspend(0, 10);
	} else {
		sendMapLoaded(\$remote_socket);
		$timeout{'ai'}{'time'} = time;
	}
}

sub map_changed {
	my ($self,$args) = @_;
	$conState = 4;

	($ai_v{temp}{map}) = $args->{map} =~ /([\s\S]*)\./;
	checkAllowedMap($ai_v{temp}{map});
	if ($ai_v{temp}{map} ne $field{name}) {
		getField($ai_v{temp}{map}, \%field);
	}

	undef $conState_tries;
	for (my $i = 0; $i < @ai_seq; $i++) {
		ai_setMapChanged($i);
	}
	$ai_v{'portalTrace_mapChanged'} = 1;

	$map_ip = makeIP($args->{IP});
	$map_port = $args->{port};
	message(swrite(
		"---------Map Change Info----------", [],
		"MAP Name: @<<<<<<<<<<<<<<<<<<",
		[$args->{map}],
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
}

sub map_loaded {
	#Note: ServerType0 overrides this function
	my ($self,$args) = @_;
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
		sendSync(\$remote_socket, 1);
		debug "Sent initial sync\n", "connection";
		$timeout{'ai'}{'time'} = time;
	}

	$char->{pos} = {};
	makeCoords($char->{pos}, $args->{coords});
	$char->{pos_to} = {%{$char->{pos}}};
	message("Your Coordinates: $char->{pos}{x}, $char->{pos}{y}\n", undef, 1);

	sendIgnoreAll(\$remote_socket, "all") if ($config{'ignoreAll'});
}

sub memo_success {
	my ($self, $args) = @_;
	if ($args->{fail}) {
		warning "Memo Failed\n";
	} else {
		message "Memo Succeeded\n", "success";
	}
}

sub npc_image {
	my ($self, $args) = @_;
	if ($args->{type} == 2) {
		debug "Show NPC image: $args->{npc_image}\n", "parseMsg";
	} elsif ($args->{type} == 255) {
		debug "Hide NPC image: $args->{npc_image}\n", "parseMsg";
	} else {
		debug "NPC image: $args->{npc_image} ($args->{type})\n", "parseMsg";
	}
}

sub public_message {
	my ($self,$args) = @_;
	$args->{message} =~ s/\000//g;
	($args->{chatMsgUser}, $args->{chatMsg}) = $args->{message} =~ /([\s\S]*?) : ([\s\S]*)/;
	$args->{chatMsgUser} =~ s/ $//;

	stripLanguageCode(\$args->{chatMsg});

	my $dist = "unknown";
	if ($players{$args->{ID}}) {
		$dist = distance($char->{pos_to}, $players{$args->{ID}}{pos_to});
		$dist = sprintf("%.1f", $dist) if ($dist =~ /\./);
	}

	$args->{chat} = "$args->{chatMsgUser} ($players{$args->{ID}}{binID}): $args->{chatMsg}";
	chatLog("c", "[$field{name} $char->{pos_to}{x}, $char->{pos_to}{y}] [$players{$args->{ID}}{pos_to}{x}, $players{$args->{ID}}{pos_to}{y}] [dist=$dist] " .
		"$args->{message}\n") if ($config{logChat});
	message "[dist=$dist] $args->{chat}\n", "publicchat";

	ChatQueue::add('c', $args->{ID}, $args->{chatMsgUser}, $args->{chatMsg});
	Plugins::callHook('packet_pubMsg', {
		pubID => $args->{ID},
		pubMsgUser => $args->{chatMsgUser},
		pubMsg => $args->{chatMsg},
		MsgUser => $args->{chatMsgUser},
		Msg => $args->{chatMsg}
	});
}

sub private_message {
	my ($self,$args) = @_;
	# Private message
	$conState = 5 if ($conState != 4 && $xkore);
	my $newmsg;
	decrypt(\$newmsg, substr($args->{RAW_MSG}, 28, length($args->{RAW_MSG})-28));
	my $msg = substr($args->{RAW_MSG}, 0, 28) . $newmsg;
	$args->{privMsg} = substr($msg, 28, $args->{RAW_MSG_SIZE} - 29);
	if ($args->{privMsgUser} ne "" && binFind(\@privMsgUsers, $args->{privMsgUser}) eq "") {
		push @privMsgUsers, $args->{privMsgUser};
		Plugins::callHook('parseMsg/addPrivMsgUser', {
			user => $args->{privMsgUser},
			msg => $args->{privMsg},
			userList => \@privMsgUsers
		});
	}

	stripLanguageCode(\$args->{privMsg});
	chatLog("pm", "(From: $args->{privMsgUser}) : $args->{privMsg}\n") if ($config{'logPrivateChat'});
	message "(From: $args->{privMsgUser}) : $args->{privMsg}\n", "pm";

	ChatQueue::add('pm', undef, $args->{privMsgUser}, $args->{privMsg});
	Plugins::callHook('packet_privMsg', {
		privMsgUser => $args->{privMsgUser},
		privMsg => $args->{privMsg},
		MsgUser => $args->{privMsgUser},
		Msg => $args->{privMsg}
	});

	if ($config{dcOnPM} && $AI) {
		chatLog("k", "*** You were PM'd, auto disconnect! ***\n");
		message "Disconnecting on PM!\n";
		quit();
	}
}

sub private_message_sent {
	my ($self,$args) = @_;
	if ($args->{type} == 0) {
		message "(To $lastpm[0]{'user'}) : $lastpm[0]{'msg'}\n", "pm/sent";
		chatLog("pm", "(To: $lastpm[0]{'user'}) : $lastpm[0]{'msg'}\n") if ($config{'logPrivateChat'});

		Plugins::callHook('packet_sentPM', {
			to => $lastpm[0]{user},
			msg => $lastpm[0]{msg}
		});

	} elsif ($args->{type} == 1) {
		warning "$lastpm[0]{'user'} is not online\n";
	} elsif ($args->{type} == 2) {
		warning "Player ignored your message\n";
	} else {
		warning "Player doesn't want to receive messages\n";
	}
	shift @lastpm;
}

sub received_characters {
	return if $conState == 5;
	my ($self,$args) = @_;
	message("Received characters from Game Login Server\n", "connection");
	$conState = 3;
	undef $conState_tries;
	undef @chars;

	Plugins::callHook('parseMsg/recvChars', $args->{options});
	if ($args->{options} && exists $args->{options}{charServer}) {
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
	}
}

sub received_character_ID_and_Map {
	my ($self,$args) = @_;
	message "Received character ID and Map IP from Game Login Server\n", "connection";
	$conState = 4;
	undef $conState_tries;
	$charID = $args->{charID};
	($args->{mapName}) = $args->{mapName} =~ /([\s\S]*?)\000/;

	if ($xkore) {
		undef $masterServer;
		$masterServer = $masterServers{$config{master}} if ($config{master} ne "");
	}

	($ai_v{temp}{map}) = $args->{mapName} =~ /([\s\S]*)\./;
	if ($ai_v{temp}{map} ne $field{name}) {
		getField($ai_v{temp}{map}, \%field);
	}

	$map_ip = makeIP($args->{mapIP});
	$map_ip = $masterServer->{ip} if ($masterServer && $masterServer->{private});
	$map_port = $args->{mapPort};
	message "----------Game Info----------\n", "connection";
	message "Char ID: ".getHex($charID)." (".unpack("L1", $charID).")\n", "connection";
	message "MAP Name: $args->{mapName}\n", "connection";
	message "MAP IP: $map_ip\n", "connection";
	message "MAP Port: $map_port\n", "connection";
	message "-----------------------------\n", "connection";
	($ai_v{temp}{map}) = $args->{mapName} =~ /([\s\S]*)\./;
	checkAllowedMap($ai_v{temp}{map});
	message("Closing connection to Game Login Server\n", "connection") if (!$xkore);
	Network::disconnect(\$remote_socket) if (!$xkore);
	main::initStatVars();
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

sub self_chat {
	my ($self,$args) = @_;
	$args->{message} =~ s/\000//g;
	($args->{chatMsgUser}, $args->{chatMsg}) = $args->{message} =~ /([\s\S]*?) : ([\s\S]*)/;
	# Note: $chatMsgUser/Msg may be undefined. This is the case on
	# eAthena servers: it uses this packet for non-chat server messages.

	if (defined $args->{chatMsgUser}) {
		stripLanguageCode(\$args->{chatMsg});
		$args->{chatMsgUser} = "$args->{chatMsgUser} : $args->{chatMsg}";
	}

	chatLog("c", "$args->{message}\n") if ($config{'logChat'});
	message "$args->{message}\n", "selfchat";

	Plugins::callHook('packet_selfChat', {
		user => $args->{chatMsgUser},
		msg => $args->{chatMsg}
	});
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

	Plugins::callHook('packet_skilluse', {
			'skillID' => $args->{skillID},
			'sourceID' => $args->{sourceID},
			'targetID' => $args->{targetID},
			'damage' => $args->{damage},
			'amount' => 0,
			'x' => 0,
			'y' => 0,
			'disp' => \$disp
		});

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
	Plugins::callHook('packet_skilluse', {
			'skillID' => $args->{skillID},
			'sourceID' => $args->{sourceID},
			'targetID' => $args->{targetID},
			'damage' => 0,
			'amount' => $args->{amount},
			'x' => 0,
			'y' => 0
			});
}

sub storage_item_added {
	my ($self, $args) = @_;

	my $index = $args->{index};
	my $amount = $args->{amount};

	my $item = $storage{$index} ||= {};
	if ($item->{amount}) {
		$item->{amount} += $amount;
	} else {
		binAdd(\@storageID, $index);
		$item->{nameID} = $args->{ID};
		$item->{index} = $index;
		$item->{amount} = $amount;
		$item->{identified} = $args->{identified};
		$item->{broken} = $args->{broken};
		$item->{upgrade} = $args->{upgrade};
		$item->{cards} = $args->{cards};
		$item->{name} = itemName($item);
		$item->{binID} = binFind(\@storageID, $index);
	}
	message("Storage Item Added: $item->{name} ($item->{binID}) x $amount\n", "storage", 1);
	$itemChange{$item->{name}} += $amount;
}

sub system_chat {
	my ($self,$args) = @_;
	#my $chat = substr($msg, 4, $msg_size - 4);
	#$chat =~ s/\000$//;

	stripLanguageCode(\$args->{message});
	chatLog("s", "$args->{message}\n") if ($config{'logSystemChat'});
	message "$args->{message}\n", "schat";
	ChatQueue::add('gm', undef, undef, $args->{message});
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
