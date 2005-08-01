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
use Item;
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

	# If you are wondering about those funny strings like 'x2 v1' read http://perldoc.perl.org/functions/pack.html
	# and http://perldoc.perl.org/perlpacktut.html

	# Defines a list of Packet Handlers and decoding information
	# 'packetSwitch' => ['handler function','unpack string',[qw(argument names)]]

	$self{packet_list} = {
		'0069' => ['account_server_info', 'x2 a4 a4 a4 x30 C1 a*', [qw(sessionID accountID sessionID2 accountSex serverInfo)]],
		'006A' => ['login_error', 'C1', [qw(type)]],
		'006B' => ['received_characters'],
		'006C' => ['login_error_game_login_server'],
		'006D' => ['character_creation_successful', 'a4 x4 V1 x62 Z24 C1 C1 C1 C1 C1 C1 C1', [qw(ID zenny name str agi vit int dex luk slot)]],
		'006E' => ['character_creation_failed'],
		'006F' => ['character_deletion_successful'],
		'0070' => ['character_deletion_failed'],
		'0071' => ['received_character_ID_and_Map', 'a4 Z16 a4 v1', [qw(charID mapName mapIP mapPort)]],
		'0073' => ['map_loaded','x4 a3',[qw(coords)]],
		'0075' => ['change_to_constate5'],
		'0077' => ['change_to_constate5'],
		'0078' => ['actor_exists', 'a4 v1 v1 v1 v1 v1 C1 x1 v1 v1 v1 v1 v1 v1 x2 v1 V1 x7 C1 a3 x2 C1 v1', [qw(ID walk_speed param1 param2 param3 type pet weapon lowhead shield tophead midhead hair_color head_dir guildID sex coords act lv)]],
		'0079' => ['actor_connected', 'a4 v1 v1 v1 v1 v1 x2 v1 v1 v1 v1 v1 v1 x4 V1 x7 C1 a3 x2 v1', [qw(ID walk_speed param1 param2 param3 type weapon lowhead shield tophead midhead hair_color guildID sex coords lv)]],
		'007A' => ['change_to_constate5'],
		'007B' => ['actor_moved', 'a4 v1 v1 v1 v1 v1 C1 x1 v1 v1 x4 v1 v1 v1 v1 x4 V1 x7 C1 a5 x3 v1', [qw(ID walk_speed param1 param2 param3 type pet weapon lowhead shield tophead midhead hair_color guildID sex coords lv)]],
		'007C' => ['actor_spawned', 'a4 v1 v1 v1 v1 x6 v1 C1 x12 C1 a3', [qw(ID walk_speed param1 param2 param3 type pet sex coords)]],
		'007F' => ['received_sync', 'V1', [qw(time)]],
		'0080' => ['actor_died_or_disappeard', 'a4 C1', [qw(ID type)]],
		'0081' => ['errors', 'C1', [qw(type)]],
		'0087' => ['character_moves', 'x4 a5 C1', [qw(coords unknown)]],
		'0088' => ['actor_movement_interrupted', 'a4 v1 v1', [qw(ID x y)]],
		'008A' => ['actor_action', 'a4 a4 a4 V1 V1 s1 v1 C1 v1', [qw(sourceID targetID tick src_speed dst_speed damage param2 type param3)]],
		'008D' => ['public_chat', 'x2 a4 Z*', [qw(ID message)]],
		'008E' => ['self_chat', 'x2 Z*', [qw(message)]],
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
		'00A3' => ['inventory_items_stackable'],
		'00A4' => ['inventory_items_nonstackable'],
		'00A5' => ['storage_items_stackable'],
		'00A6' => ['storage_items_nonstackable'],
		'00A8' => ['use_item', 'v1 x2 C1', [qw(index amount)]],
		'00AA' => ['equip_item', 'v1 v1 C1', [qw(index type success)]],
		'00AC' => ['unequip_item', 'v1 v1', [qw(index type)]],
		'00AF' => ['inventory_item_removed', 'v1 v1', [qw(index amount)]],
		'00B0' => ['stat_info', 'v1 V1', [qw(type val)]],
		'00B1' => ['exp_zeny_info', 'v1 V1', [qw(type val)]],
		'00B3' => ['change_to_constate25'],
		'00B4' => ['npc_talk'],
		'00B5' => ['npc_talk_continue'],
		'00B6' => ['npc_talk_close', 'a4', [qw(ID)]],
		'00B7' => ['npc_talk_responses'],
		'00BC' => ['stats_added', 'v1 x1 C1', [qw(type val)]],
		'00BD' => ['stats_info', 'v1 C1 C1 C1 C1 C1 C1 C1 C1 C1 C1 C1 C1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1', [qw(points_free str points_str agi points_agi vit points_vit int points_int dex points_dex luk points_luk attack attack_bonus attack_magic_min attack_magic_max def def_bonus def_magic def_magic_bonus hit flee flee_bonus critical)]],
		'00BE' => ['stats_points_needed', 'v1 C1', [qw(type val)]],
		'00C0' => ['emoticon', 'a4 C1', [qw(ID type)]],
		'00CA' => ['buy_result', 'C1', [qw(fail)]],
		'00C2' => ['users_online', 'V1', [qw(users)]],
		'00C3' => ['job_equipment_hair_change', 'a4 C1 C1', [qw(ID part number)]],
		'00C4' => ['npc_store_begin', 'a4', [qw(ID)]],
		'00C6' => ['npc_store_info'],
		'00C7' => ['npc_sell_list'],
		'00D1' => ['ignore_player_result', 'C1 C1', [qw(type error)]],
		'00D2' => ['ignore_all_result', 'C1 C1', [qw(type error)]],
		'00D6' => ['chat_created'],
		'00D7' => ['chat_info', 'x2 a4 a4 v1 v1 C1 a*', [qw(ownerID ID limit num_users public title)]],
		'00DA' => ['chat_join_result', 'C1', [qw(type)]],
		'00D8' => ['chat_removed', 'a4', [qw(ID)]],
		'00DB' => ['chat_users'],
		'00DC' => ['chat_user_join', 'v1 Z24', [qw(num_users user)]],
		'00DD' => ['chat_user_leave', 'v1 Z24', [qw(num_users user)]],
		'00DF' => ['chat_modified', 'x2 a4 a4 v1 v1 C1 a*', [qw(ownerID ID limit num_users public title)]],
		'00E1' => ['chat_newowner', 'C1 x3 Z24', [qw(type user)]],
		'00E5' => ['deal_request', 'Z24', [qw(user)]],
		'00E7' => ['deal_begin', 'C1', [qw(type)]],
		'00E9' => ['deal_add_other', 'V1 v1 C1 C1 C1 a8', [qw(amount nameID identified broken upgrade cards)]],
		'00EA' => ['deal_add_you', 'v1 C1', [qw(index fail)]],
		'00EC' => ['deal_finalize', 'C1', [qw(type)]],
		'00EE' => ['deal_cancelled'],
		'00F0' => ['deal_complete'],
		'00F2' => ['storage_opened', 'v1 v1', [qw(items items_max)]],
		'00F4' => ['storage_item_added', 'v1 V1 v1 C1 C1 C1 a8', [qw(index amount ID identified broken upgrade cards)]],
		'00F6' => ['storage_item_removed', 'v1 V1', [qw(index amount)]],
		'00F8' => ['storage_closed'],
		'00FA' => ['party_organize_result', 'C1', [qw(fail)]],
		'00FB' => ['party_users_info', 'x2 Z24', [qw(party_name)]],
		'00FD' => ['party_invite_result', 'Z24 C1', [qw(name type)]],
		'00FE' => ['party_invite', 'a4 Z24', [qw(ID name)]],
		'0101' => ['party_exp', 'C1', [qw(type)]],
		'0104' => ['party_join', 'a4 x4 v1 v1 C1 Z24 Z24 Z16', [qw(ID x y type name user map)]],
		'0105' => ['party_leave', 'a4 Z24', [qw(ID name)]],
		'0106' => ['party_hp_info', 'a4 v1 v1', [qw(ID hp hp_max)]],
		'0107' => ['party_location', 'a4 v1 v1', [qw(ID x y)]],
		'0108' => ['item_upgrade', 'v1 v1 v1', [qw(type index upgrade)]],
		'0109' => ['party_chat', 'x2 a4 Z*', [qw(ID message)]],
		'010A' => ['mvp_item', 'v1', [qw(itemID)]],
		'010B' => ['mvp_you', 'V1', [qw(expAmount)]],
		'010C' => ['mvp_other', 'a4', [qw(ID)]],
		'0114' => ['skill_use', 'v1 a4 a4 V1 V1 V1 s1 v1 v1 C1', [qw(skillID sourceID targetID tick src_speed dst_speed damage level param3 type)]],
		'0119' => ['character_status', 'a4 v1 v1 v1', [qw(ID param1 param2 param3)]],
		'011A' => ['skill_used_no_damage', 'v1 v1 a4 a4 C1', [qw(skillID amount targetID sourceID fail)]],
		'011C' => ['warp_portal_list', 'v1 Z16 Z16 Z16 Z16', [qw(type memo1 memo2 memo3 memo4)]],
		'011E' => ['memo_success', 'C1', [qw(fail)]],
		'0121' => ['cart_info', 'v1 v1 V1 V1', [qw(items items_max weight weight_max)]],
		'0124' => ['cart_item_added', 'v1 V1 v1 x C1 C1 C1 a8', [qw(index amount ID identified broken upgrade cards)]],
		'0125' => ['cart_item_removed', 'v1 V1', [qw(index amount)]],
		'012C' => ['cart_add_failed', 'C1', [qw(fail)]],
		'013C' => ['arrow_equipped', 'v1', [qw(index)]],
		'0141' => ['stat_info2', 'v1 x2 v1 x2 v1', [qw(type val val2)]],
		'017F' => ['guild_chat', 'x2 Z*', [qw(message)]],
		'0188' => ['item_upgrade', 'v1 v1 v1', [qw(type index upgrade)]],
		'018F' => ['refine_result', 'v1 v1', [qw(fail nameID)]],
		#'0192' => ['location_msg'], #finish me 
		'0195' => ['actor_name_received', 'a4 Z24 Z24 Z24 Z24', [qw(ID name partyName guildName guildTitle)]],
		'0196' => ['actor_status_active', 'v1 a4 C1', [qw(type ID flag)]],
		'01A2' => ['pet_info', 'Z24 C1 v1 v1 v1 v1', [qw(name nameflag level hungry friendly accessory)]],
		'01A6' => ['egg_list'],
		'01B3' => ['npc_image', 'Z63 C1', [qw(npc_image type)]],
		'01C4' => ['storage_item_added', 'v1 V1 v1 C1 C1 C1 C1 a8', [qw(index amount ID type identified broken upgrade cards)]],
		'01C5' => ['cart_item_added', 'v1 V1 v1 x C1 C1 C1 a8', [qw(index amount ID identified broken upgrade cards)]],
		'01C8' => ['item_used', 'v1 v1 a4 v1', [qw(index itemID ID remaining)]],
		'01D2' => ['combo_delay', 'a4 V1', [qw(ID delay)]],
		'01D8' => ['actor_exists', 'a4 v1 v1 v1 v1 v1 C1 x1 v1 v1 v1 v1 v1 v1 x2 v1 V1 x7 C1 a3 x2 C1 v1', [qw(ID walk_speed param1 param2 param3 type pet weapon shield lowhead tophead midhead hair_color head_dir guildID sex coords act lv)]],
		'01D9' => ['actor_connected', 'a4 v1 v1 v1 v1 v1 x2 v1 v1 v1 v1 v1 v1 x4 V1 x7 C1 a3 x2 v1', [qw(ID walk_speed param1 param2 param3 type weapon shield lowhead tophead midhead hair_color guildID sex coords lv)]],
		'01DA' => ['actor_moved', 'a4 v1 v1 v1 v1 v1 C1 x1 v1 v1 v1 x4 v1 v1 v1 x4 V1 x4 v1 x1 C1 a5 x3 v1', [qw(ID walk_speed param1 param2 param3 type pet weapon shield lowhead tophead midhead hair_color guildID skillstatus sex coords lv)]],
		'01DC' => ['secure_login_key', 'x2 a*', [qw(secure_key)]],
		'01DE' => ['skill_use', 'v1 a4 a4 V1 V1 V1 l1 v1 v1 C1', [qw(skillID sourceID targetID tick src_speed dst_speed damage level param3 type)]],
		'01EE' => ['inventory_items_stackable'],
		'01F4' => ['deal_request', 'Z24 x4 v1', [qw(user level)]],
		'01F5' => ['deal_begin', 'C1', [qw(type)]],
		'01F0' => ['storage_items_stackable'],
		'01FC' => ['repair_list'],
		'01FE' => ['repair_result', 'v1 C1', [qw(nameID flag)]],
		#'023A' => ['storage_password_unknown', 'v1', [qw(flag)]],
		#'023C' => ['storage_password_unknown2', 'v1 v1', [qw(type val)]],
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
		$servers[$num]{port} = unpack("v1", substr($msg, $i+4, 2));
		($servers[$num]{name}) = unpack("Z*", substr($msg, $i + 6, 20));
		$servers[$num]{users} = unpack("V",substr($msg, $i + 26, 4));
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
			message getActorName($args->{sourceID})." is sitting.\n", 'parseMsg_statuslook', 2;
			$players{$args->{sourceID}}{sitting} = 1 if ($players{$args->{sourceID}});
		}
	} elsif ($args->{type} == 3) {
		# Stand
		my ($source, $verb) = getActorNames($args->{sourceID}, 0, 'are', 'is');
		if ($args->{sourceID} eq $accountID) {
			message "You are standing.\n";
			$char->{sitting} = 0;
		} else {
			message getActorName($args->{sourceID})." is standing.\n", 'parseMsg_statuslook', 2;
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
			$players{$args->{ID}}{'nameID'} = unpack("V1", $args->{ID});
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
		my $domain = existsInList($config{friendlyAID}, unpack("V1", $args->{ID})) ? 'parseMsg_presence' : 'parseMsg_presence/player';
		debug "Player Connected: ".$players{$args->{ID}}->name." ($players{$args->{ID}}{'binID'}) Level $args->{lv} $sex_lut{$players{$args->{ID}}{'sex'}} $jobs_lut{$players{$args->{ID}}{'jobID'}}\n", $domain;

		objectAdded('player', $args->{ID}, $players{$args->{ID}}) if ($added);
		Plugins::callHook('player', {player => $players{$args->{ID}}});

		setStatus($args->{ID}, $args->{param1}, $args->{param2}, $args->{param3});

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

sub combo_delay {
	my ($self, $args) = @_;

	$args->{actor} = Actor::get($args->{ID});
	my $verb = $args->{actor}->verb('have', 'has');
	debug "$args->{actor} $verb combo delay $args->{delay}\n", "parseMsg_comboDelay";
}

sub actor_exists {
	# 0078: long ID, word speed, word state, word ailment, word look, word
	# class, word hair, word weapon, word head_option_bottom, word shield,
	# word head_option_top, word head_option_mid, word hair_color, word ?,
	# word head_dir, long guild, long emblem, word manner, byte karma, byte
	# sex, 3byte coord, byte body_dir, byte ?, byte ?, byte sitting, word
	# level
	my ($self, $args) = @_;
	$conState = 5 if ($conState != 4 && $xkore);
	my %coords;
	makeCoords(\%coords, $args->{coords});
	#debug ("$coords{x}x$coords{y}\n");
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
			$player->{nameID} = unpack("V1", $args->{ID});
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

		my $domain = existsInList($config{friendlyAID}, unpack("V1", $player->{ID})) ? 'parseMsg_presence' : 'parseMsg_presence/player';
		debug "Player Exists: " . $player->name . " ($player->{binID}) Level $args->{lv} " . $sex_lut{$player->{sex}} . " $jobs_lut{$player->{jobID}}\n", $domain, 1;

		objectAdded('player', $args->{ID}, $player) if ($added);

		Plugins::callHook('player', {player => $player});

		setStatus($args->{ID},$args->{param1},$args->{param2},$args->{param3});

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

			objectAdded('monster', $args->{ID}, $monsters{$args->{ID}}) if ($added);

			# Monster state
			$args->{param1} = 0 if $args->{param1} == 5; # 5 has got something to do with the monster being undead
			setStatus($args->{ID},$args->{param1},$args->{param2},$args->{param3});
		}

	} elsif ($args->{type} == 45) {
		if (!$portals{$args->{ID}} || !%{$portals{$args->{ID}}}) {
			$portals{$args->{ID}}{'appear_time'} = time;
			my $nameID = unpack("V1", $args->{ID});
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
			my $nameID = unpack("V1", $args->{ID});
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

		setStatus($args->{ID}, $args->{param1}, $args->{param2}, $args->{param3});

	} else {
		debug "Unknown Exists: $args->{type} - ".unpack("V*",$args->{ID})."\n", "parseMsg";
	}
}

sub actor_info {
	my ($self, $args) = @_;
	$conState = 5 if ($conState != 4 && $xkore);

	debug "Received object info: $args->{name}\n", "parseMsg_presence/name", 2;

	my $player = $players{$args->{ID}};
	if ($player && %{$player}) {
		# This packet tells us the names of players who aren't in a guild, as opposed to 0195.
		$player->{name} = $args->{name};
		$player->{gotName} = 1;
		my $binID = binFind(\@playersID, $args->{ID});
		debug "Player Info: $player->{name} ($binID)\n", "parseMsg_presence", 2;
		updatePlayerNameCache($player);
		Plugins::callHook('charNameUpdate', $player);
	}

	my $monster = $monsters{$args->{ID}};
	if ($monster && %{$monster}) {
		my $name = $args->{name};
		if ($config{debug} >= 2) {
			my $binID = binFind(\@monstersID, $args->{ID});
			debug "Monster Info: $name ($binID)\n", "parseMsg", 2;
		}
		if ($monsters_lut{$monster->{nameID}} eq "") {
			$monster->{name} = $name;
			$monsters_lut{$monster->{nameID}} = $name;
			updateMonsterLUT("$Settings::tables_folder/monsters.txt", $monster->{nameID}, $name);
		}
	}

	my $npc = $npcs{$args->{ID}};
	if ($npc && %{$npc}) {
		$npc->{name} = $args->{name};
		$npc->{gotName} = 1;
		if ($config{debug} >= 2) {
			my $binID = binFind(\@npcsID, $args->{ID});
			debug "NPC Info: $npc->{name} ($binID)\n", "parseMsg", 2;
		}

		my $location = "$field{name} $npc->{pos}{x} $npc->{pos}{y}";
		if (!$npcs_lut{$location}) {
			$npcs_lut{$location} = $npc->{name};
			updateNPCLUT("$Settings::tables_folder/npcs.txt", $location, $npc->{name});
		}
	}

	my $pet = $pets{$args->{ID}};
	if ($pet && %{$pet}) {
		$pet->{name_given} = $args->{name};
		if ($config{debug} >= 2) {
			my $binID = binFind(\@petsID, $args->{ID});
			debug "Pet Info: $pet->{name_given} ($binID)\n", "parseMsg", 2;
		}
	}
}

sub actor_look_at {
	my ($self, $args) = @_;
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
			$player->{nameID} = unpack("V1", $args->{ID});
			$player->{binID} = binFind(\@playersID, $args->{ID});
			my $domain = existsInList($config{friendlyAID}, unpack("V1", $args->{ID})) ? 'parseMsg_presence' : 'parseMsg_presence/player';
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

		objectAdded('player', $args->{ID}, $player) if ($added);

		setStatus($args->{ID}, $args->{param1}, $args->{param2}, $args->{param3});

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
			$monsters{$args->{ID}}{walk_speed} = $args->{walk_speed} / 1000;
			$monsters{$args->{ID}}{time_move_calc} = distance(\%coordsFrom, \%coordsTo) * $monsters{$args->{ID}}{walk_speed};
			debug "Monster Moved: $monsters{$args->{ID}}{'name'} ($monsters{$args->{ID}}{'binID'})\n", "parseMsg", 2;

			objectAdded('monster', $args->{ID}, $monsters{$args->{ID}}) if ($added);

			setStatus($args->{ID}, $args->{param1}, $args->{param2}, $args->{param3});
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

sub actor_name_received {
	my ($self, $args) = @_;

	my $player = $players{$args->{ID}};
	if ($player && %{$player}) {
		# Receive names of players who are in a guild.
		$player->{name} = $args->{name};
		$player->{gotName} = 1;
		$player->{party}{name} = $args->{partyName};
		$player->{guild}{name} = $args->{guildName};
		$player->{guild}{title} = $args->{guildTitle};
		updatePlayerNameCache($player);
		debug "Player Info: $player->{name} ($player->{binID})\n", "parseMsg_presence", 2;
		Plugins::callHook('charNameUpdate', $player);
	} else {
		debug "Player Info for ".unpack("V", $args->{ID})." (not on screen): $args->{name}\n", "parseMsg_presence/remote", 2;
	}
}

sub actor_status_active {
	my ($self, $args) = @_;

	my ($type, $ID, $flag) = @{$args}{qw(type ID flag)};

	my $skillName = (defined($skillsStatus{$type})) ? $skillsStatus{$type} : "Unknown $type";
	$args->{skillName} = $skillName;
	my $actor = Actor::get($ID);
	$args->{actor} = $actor;

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
}

sub actor_spawned {
	my ($self, $args) = @_;
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
			$players{$args->{ID}}{'nameID'} = unpack("V1", $args->{ID});
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

		setStatus($args->{ID}, $args->{param1}, $args->{param2}, $args->{param3});

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
			debug "Pet Spawned: $pets{$args->{ID}}{'name'} ($pets{$args->{ID}}{'binID'}) Monster type: $args->{type}\n", "parseMsg";

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

			setStatus($args->{ID}, $args->{param1}, $args->{param2}, $args->{param3});
		}

	# portals don't spawn
	#} elsif ($args->{type} == 45) {

	} elsif ($args->{type} < 1000) {
		if (!$npcs{$args->{ID}} || !%{$npcs{$args->{ID}}}) {
			my $nameID = unpack("V1", $args->{ID});
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
		message "NPC Spawned: $npcs{$args->{ID}}{'name'} ($npcs{$args->{ID}}{pos}{x}, $npcs{$args->{ID}}{pos}{y}) (ID $npcs{$args->{ID}}{'nameID'}) - ($npcs{$args->{ID}}{'binID'})\n", undef, 1;

		objectAdded('npc', $args->{ID}, $npcs{$args->{ID}}) if ($added);

		setStatus($args->{ID}, $args->{param1}, $args->{param2}, $args->{param3});

	} else {
		debug "Unknown Spawned: $args->{type} - ".getHex($args->{ID})."\n", "parseMsg_presence";
	}
}

sub arrow_equipped {
	my ($self,$args) = @_;
	return unless $args->{index};
	$char->{arrow} = $args->{index};

	my $invIndex = findIndex(\@{$chars[$config{'char'}]{'inventory'}}, "index", $args->{index});
	if ($invIndex ne "" && $char->{equipment}{arrow} != $char->{inventory}[$invIndex]) {
		$char->{equipment}{arrow} = $char->{inventory}[$invIndex];
		$char->{inventory}[$invIndex]{equipped} = 32768;
		$ai_v{temp}{waitForEquip}-- if $ai_v{temp}{waitForEquip};
		message "Arrow equipped: $char->{inventory}[$invIndex]{name} ($invIndex)\n";
	}
}

sub buy_result {
	my ($self, $args) = @_;
	if ($args->{fail} == 0) {
		message "Buy completed.\n", "success";
	} elsif ($args->{fail} == 1) {
		error "Buy failed (insufficient zeny).\n";
	} elsif ($args->{fail} == 2) {
		error "Buy failed (insufficient weight capacity).\n";
	} elsif ($args->{fail} == 3) {
		error "Buy failed (too many different inventory items).\n";
	} else {
		error "Buy failed (failure code $args->{fail}).\n";
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
		$item->{index} = $args->{index};
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

sub item_used {
	my ($self, $args) = @_;

	my ($index, $itemID, $ID, $remaining) =
		@{$args}{qw(index itemID ID remaining)};

	if ($ID eq $accountID) {
		my $invIndex = findIndex($char->{inventory}, "index", $index);
		my $item = $char->{inventory}[$invIndex];
		my $amount = $item->{amount} - $remaining;
		$item->{amount} -= $amount;

		message("You used Item: $item->{name} ($invIndex) x $amount - $remaining left\n", "useItem", 1);
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
		my $itemDisplay = itemNameSimple($itemID);
		message "$actor used Item: $itemDisplay - $remaining left\n", "useItem", 2;
	}
}

sub cart_item_removed {
	my ($self, $args) = @_;

	my ($index, $amount) = @{$args}{qw(index amount)};

	$cart{'inventory'}[$index]{'amount'} -= $amount;
	message "Cart Item Removed: $cart{'inventory'}[$index]{'name'} ($index) x $amount\n";
	$itemChange{$cart{inventory}[$index]{name}} -= $amount;
	if ($cart{'inventory'}[$index]{'amount'} <= 0) {
		$cart{'inventory'}[$index] = undef;
	}
}

sub change_to_constate25 {
	# 00B3 - user is switching characters in XKore
	$conState = 2.5;
	undef $accountID;
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
	my ($self, $args) = @_;
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
	my ($self, $args) = @_;
	$conState = 5 if ($conState != 4 && $xkore);
	makeCoords($char->{pos}, substr($args->{RAW_MSG}, 6, 3));
	makeCoords2($char->{pos_to}, substr($args->{RAW_MSG}, 8, 3));
	my $dist = sprintf("%.1f", distance($char->{pos}, $char->{pos_to}));
	debug "You're moving from ($char->{pos}{x}, $char->{pos}{y}) to ($char->{pos_to}{x}, $char->{pos_to}{y}) - distance $dist, unknown $args->{unknown}\n", "parseMsg_move";
	$char->{time_move} = time;
	$char->{time_move_calc} = distance($char->{pos}, $char->{pos_to}) * ($char->{walk_speed} || 0.12);
}

sub character_status {
	my ($self, $args) = @_;
	setStatus($args->{ID}, $args->{param1}, $args->{param2}, $args->{param3});
}

sub chat_created {
	my ($self, $args) = @_;
	$currentChatRoom = "new";
	$chatRooms{new} = {%createdChatRoom};
	binAdd(\@chatRoomsID, "new");
	binAdd(\@currentChatRoomUsers, $char->{name});
	message "Chat Room Created\n";
}

sub chat_info {
	my ($self, $args) = @_;

	my $title;
	decrypt(\$title, $args->{title});

	my $chat = $chatRooms{$args->{ID}};
	if (!$chat || !%{$chat}) {
		$chat = $chatRooms{$args->{ID}} = {};
		binAdd(\@chatRoomsID, $args->{ID});
	}
	$chat->{title} = $title;
	$chat->{ownerID} = $args->{ownerID};
	$chat->{limit} = $args->{limit};
	$chat->{public} = $args->{public};
	$chat->{num_users} = $args->{num_users};
}

sub chat_join_result {
	my ($self, $args) = @_;
	if ($args->{type} == 1) {
		message "Can't join Chat Room - Incorrect Password\n";
	} elsif ($args->{type} == 2) {
		message "Can't join Chat Room - You're banned\n";
	}
}

sub chat_modified {
	my ($self, $args) = @_;
	my $title;
	decrypt(\$title, $args->{title});

	my ($ownerID, $ID, $limit, $public, $num_users) = @{$args}{qw(ownerID ID limit public num_users)};

	if ($ownerID eq $accountID) {
		$chatRooms{new}{title} = $title;
		$chatRooms{new}{ownerID} = $ownerID;
		$chatRooms{new}{limit} = $limit;
		$chatRooms{new}{public} = $public;
		$chatRooms{new}{num_users} = $num_users;
	} else {
		$chatRooms{$ID}{title} = $title;
		$chatRooms{$ID}{ownerID} = $ownerID;
		$chatRooms{$ID}{limit} = $limit;
		$chatRooms{$ID}{public} = $public;
		$chatRooms{$ID}{num_users} = $num_users;
	}
	message "Chat Room Properties Modified\n";
}

sub chat_newowner {
	my ($self, $args) = @_;

	if ($args->{type} == 0) {
		if ($args->{user} eq $char->{name}) {
			$chatRooms{$currentChatRoom}{ownerID} = $accountID;
		} else {
			my $key = findKeyString(\%players, "name", $args->{user});
			$chatRooms{$currentChatRoom}{ownerID} = $key;
		}
		$chatRooms{$currentChatRoom}{users}{ $args->{user} } = 2;
	} else {
		$chatRooms{$currentChatRoom}{users}{ $args->{user} } = 1;
	}
}

sub chat_user_join {
	my ($self, $args) = @_;
	if ($currentChatRoom ne "") {
		binAdd(\@currentChatRoomUsers, $args->{user});
		$chatRooms{$currentChatRoom}{users}{ $args->{user} } = 1;
		$chatRooms{$currentChatRoom}{num_users} = $args->{num_users};
		message "$args->{user} has joined the Chat Room\n";
	}
}

sub chat_user_leave {
	my ($self, $args) = @_;
	delete $chatRooms{$currentChatRoom}{users}{ $args->{user} };
	binRemove(\@currentChatRoomUsers, $args->{user});
	$chatRooms{$currentChatRoom}{num_users} = $args->{num_users};
	if ($args->{user} eq $char->{name}) {
		binRemove(\@chatRoomsID, $currentChatRoom);
		delete $chatRooms{$currentChatRoom};
		undef @currentChatRoomUsers;
		$currentChatRoom = "";
		message "You left the Chat Room\n";
	} else {
		message "$args->{user} has left the Chat Room\n";
	}
}

sub chat_users {
	my ($self, $args) = @_;

	my $newmsg;
	decrypt(\$newmsg, substr($args->{RAW_MSG}, 8));
	my $msg = substr($args->{RAW_MSG}, 0, 8).$newmsg;

	my $ID = substr($args->{RAW_MSG},4,4);
	$currentChatRoom = $ID;

	my $chat = $chatRooms{$currentChatRoom} ||= {};

	$chat->{num_users} = 0;
	for (my $i = 8; $i < $args->{RAW_MSG_SIZE}; $i += 28) {
		my $type = unpack("C1",substr($msg,$i,1));
		my ($chatUser) = unpack("Z*", substr($msg,$i + 4,24));
		if ($chat->{users}{$chatUser} eq "") {
			binAdd(\@currentChatRoomUsers, $chatUser);
			if ($type == 0) {
				$chat->{users}{$chatUser} = 2;
			} else {
				$chat->{users}{$chatUser} = 1;
			}
			$chat->{num_users}++;
		}
	}
	message "You have joined the Chat Room $chat->{title}\n";
}

sub chat_removed {
	my ($self, $args) = @_;
	binRemove(\@chatRoomsID, $args->{ID});
	delete $chatRooms{ $args->{ID} };
}

sub deal_add_other {
	my ($self, $args) = @_;
	if ($args->{nameID} > 0) {
		my $item = $currentDeal{other}{ $args->{ID} } ||= {};
		$item->{amount} += $args->{amount};
		$item->{nameID} = $args->{nameID};
		$item->{identified} = $args->{identified};
		$item->{broken} = $args->{broken};
		$item->{upgrade} = $args->{upgrade};
		$item->{cards} = $args->{cards};
		$item->{name} = itemName($item);
		message "$currentDeal{name} added Item to Deal: $item->{name} x $args->{amount}\n", "deal";
	} elsif ($args->{amount} > 0) {
		$currentDeal{other_zenny} += $args->{amount};
		my $amount = formatNumber($args->{amount});
		message "$currentDeal{name} added $args->{amount} z to Deal\n", "deal";
	}
}

sub deal_add_you {
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

sub deal_begin {
	my ($self, $args) = @_;
	if ($args->{type} == 0) {
		error "That person is too far from you to trade.\n";
	} elsif ($args->{type} == 3) {
		if (%incomingDeal) {
			$currentDeal{name} = $incomingDeal{name};
			undef %incomingDeal;
		} else {
			$currentDeal{ID} = $outgoingDeal{ID};
			$currentDeal{name} = $players{$outgoingDeal{ID}}{name};
			undef %outgoingDeal;
		}
		message "Engaged Deal with $currentDeal{name}\n", "deal";
	}
}

sub deal_cancelled {
	undef %incomingDeal;
	undef %outgoingDeal;
	undef %currentDeal;
	message "Deal Cancelled\n", "deal";
}

sub deal_complete {
	undef %outgoingDeal;
	undef %incomingDeal;
	undef %currentDeal;
	message "Deal Complete\n", "deal";
}

sub deal_finalize {
	my ($self, $args) = @_;
	if ($args->{type} == 1) {
		$currentDeal{other_finalize} = 1;
		message "$currentDeal{name} finalized the Deal\n", "deal";

	} else {
		$currentDeal{you_finalize} = 1;
		# FIXME: shouldn't we do this when we actually complete the deal?
		$char->{zenny} -= $currentDeal{you_zenny};
		message "You finalized the Deal\n", "deal";
	}
}

sub deal_request {
	my ($self, $args) = @_;
	my $level = $args->{level} || 'Unknown';
	$incomingDeal{name} = $args->{user};
	$timeout{ai_dealAutoCancel}{time} = time;
	message "$args->{user} (level $level) Requests a Deal\n", "deal";
	message "Type 'deal' to start dealing, or 'deal no' to deny the deal.\n", "deal";
}

sub egg_list {
	my ($self, $args) = @_;
	message "-----Egg Hatch Candidates-----\n", "list";
	for (my $i = 4; $i < $args->{RAW_MSG_SIZE}; $i += 2) {
		my $index = unpack("v1", substr($args->{RAW_MSG}, $i, 2));
		my $invIndex = findIndex($char->{inventory}, "index", $index);
		message "$invIndex $char->{inventory}[$invIndex]{name}\n", "list";
	}
	message "------------------------------\n", "list";
}

sub emoticon {
	my ($self, $args) = @_;
	my $emotion = $emotions_lut{$args->{type}}{display} || "<emotion #$args->{type}>";
	if ($args->{ID} eq $accountID) {
		message "$char->{name}: $emotion\n", "emotion";
		chatLog("e", "$char->{name}: $emotion\n") if (existsInList($config{'logEmoticons'}, $args->{type}) || $config{'logEmoticons'} eq "all");

	} elsif ($players{$args->{ID}} && %{$players{$args->{ID}}}) {
		my $player = $players{$args->{ID}};

		my $name = $player->{name} || "Unknown #".unpack("V", $args->{ID});

		#my $dist = "unknown";
		my $dist = distance($char->{pos_to}, $player->{pos_to});
		$dist = sprintf("%.1f", $dist) if ($dist =~ /\./);

		message "[dist=$dist] $name ($player->{binID}): $emotion\n", "emotion";
		chatLog("e", "$name".": $emotion\n") if (existsInList($config{'logEmoticons'}, $args->{type}) || $config{'logEmoticons'} eq "all");

		my $index = AI::findAction("follow");
		if ($index ne "") {
			my $masterID = AI::args($index)->{ID};
			if ($config{'followEmotion'} && $masterID eq $args->{ID} &&
		 	       distance($char->{pos_to}, $player->{pos_to}) <= $config{'followEmotion_distance'})
			{
				my %args = ();
				$args{timeout} = time + rand (1) + 0.75;

				if ($args->{type} == 30) {
					$args{emotion} = 31;
				} elsif ($args->{type} == 31) {
					$args{emotion} = 30;
				} else {
					$args{emotion} = $args->{type};
				}

				AI::queue("sendEmotion", \%args);
			}
		}
	}
}

sub equip_item {
	my ($self, $args) = @_;
	my $invIndex = findIndex($char->{inventory}, "index", $args->{index});
	my $item = $char->{inventory}[$invIndex];
	if (!$args->{success}) {
		message "You can't put on $item->{name} ($invIndex)\n";
	} else {
		$item->{equipped} = $args->{type};
		if ($args->{type} == 10) {
			$char->{equipment}{arrow} = $item;
		}
		else {
			foreach (%equipSlot_rlut){
				if ($_ & $args->{type}){
					next if $_ == 10; # work around Arrow bug
					$char->{equipment}{$equipSlot_lut{$_}} = $item;
				}
			}
		}
		message "You equip $item->{name} ($invIndex) - $equipTypes_lut{$item->{type_equip}} (type $args->{type})\n", 'inventory';
	}
	$ai_v{temp}{waitForEquip}-- if $ai_v{temp}{waitForEquip};
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

sub exp_zeny_info {
	my ($self, $args) = @_;
	$conState = 5 if ($conState != 4 && $xkore);

	if ($args->{type} == 1) {
		$char->{exp_last} = $char->{exp};
		$char->{exp} = $args->{val};
		debug "Exp: $args->{val}\n", "parseMsg";
		if (!$bExpSwitch) {
			$bExpSwitch = 1;
		} else {
			if ($char->{exp_last} > $char->{exp}) {
				$monsterBaseExp = 0;
			} else {
				$monsterBaseExp = $char->{exp} - $char->{exp_last};
			}
			$totalBaseExp += $monsterBaseExp;
			if ($bExpSwitch == 1) {
				$totalBaseExp += $monsterBaseExp;
				$bExpSwitch = 2;
			}
		}

	} elsif ($args->{type} == 2) {
		$char->{exp_job_last} = $char->{exp_job};
		$char->{exp_job} = $args->{val};
		debug "Job Exp: $args->{val}\n", "parseMsg";
		if ($jExpSwitch == 0) {
			$jExpSwitch = 1;
		} else {
			if ($char->{exp_job_last} > $char->{exp_job}) {
				$monsterJobExp = 0;
			} else {
				$monsterJobExp = $char->{exp_job} - $char->{exp_job_last};
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

	} elsif ($args->{type} == 20) {
		my $change = $args->{val} - $char->{zenny};
		if ($change > 0) {
			message "You gained $change zeny.\n";
		} elsif ($change < 0) {
			message "You lost ".-$change." zeny.\n";
			if ($config{dcOnZeny} && $args->{val} <= $config{dcOnZeny}) {
				$interface->errorDialog("Disconnecting due to zeny lower than $config{dcOnZeny}.");
				$quit = 1;
			}
		}
		$char->{zenny} = $args->{val};
		debug "Zenny: $args->{val}\n", "parseMsg";
	} elsif ($args->{type} == 22) {
		$char->{exp_max_last} = $char->{exp_max};
		$char->{exp_max} = $args->{val};
		debug "Required Exp: $args->{val}\n", "parseMsg";
		if (!$xkore && $initSync && $config{serverType} == 2) {
			sendSync(\$remote_socket, 1);
			$initSync = 0;
		}
	} elsif ($args->{type} == 23) {
		$char->{exp_job_max_last} = $char->{exp_job_max};
		$char->{exp_job_max} = $args->{val};
		debug "Required Job Exp: $args->{val}\n", "parseMsg";
		message("BaseExp:$monsterBaseExp | JobExp:$monsterJobExp\n","info", 2) if ($monsterBaseExp);
	}
}

sub guild_chat {
	my ($self, $args) = @_;
	my ($chatMsgUser, $chatMsg);
	my $chat = $args->{message};
	if (($chatMsgUser, $chatMsg) = $args->{message} =~ /(.*?) : (.*)/) {
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

	$args->{chatMsgUser} = $chatMsgUser;
	$args->{chatMsg} = $chatMsg;
}

sub ignore_all_result {
	my ($self, $args) = @_;
	if ($args->{type} == 0) {
		message "All Players ignored\n";
	} elsif ($args->{type} == 1) {
		if ($args->{error} == 0) {
			message "All players unignored\n";
		}
	}
}

sub ignore_player_result {
	my ($self, $args) = @_;
	if ($args->{type} == 0) {
		message "Player ignored\n";
	} elsif ($args->{type} == 1) {
		if ($args->{error} == 0) {
			message "Player unignored\n";
		}
	}
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
			$item = $char->{inventory}[$invIndex] = new Item();
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
	} elsif ($fail == 1) {
		message "Cannot pickup item (you're Frozen?)\n", "drop";
	} else {
		message "Cannot pickup item (failure code $fail)\n", "drop";
	}
}

sub inventory_item_removed {
	my ($self, $args) = @_;
	$conState = 5 if ($conState != 4 && $xkore);
	my $invIndex = findIndex($char->{inventory}, "index", $args->{index});
	inventoryItemRemoved($invIndex, $args->{amount});
	Plugins::callHook('packet_item_removed', {index => $invIndex});
}

sub inventory_items_nonstackable {
	my ($self, $args) = @_;
	$conState = 5 if $conState != 4 && $xkore;
	my $newmsg;
	decrypt(\$newmsg, substr($args->{RAW_MSG}, 4));
	my $msg = substr($args->{RAW_MSG}, 0, 4) . $newmsg;
	my $invIndex;
	for (my $i = 4; $i < $args->{RAW_MSG_SIZE}; $i += 20) {
		my $index = unpack("v1", substr($msg, $i, 2));
		my $ID = unpack("v1", substr($msg, $i + 2, 2));
		$invIndex = findIndex($char->{inventory}, "index", $index);
		$invIndex = findIndex($char->{inventory}, "nameID", "") unless defined $invIndex;

		my $item = $char->{inventory}[$invIndex] = new Item();
		$item->{index} = $index;
		$item->{invIndex} = $invIndex;
		$item->{nameID} = $ID;
		$item->{amount} = 1;
		$item->{type} = unpack("C1", substr($msg, $i + 4, 1));
		$item->{identified} = unpack("C1", substr($msg, $i + 5, 1));
		$item->{type_equip} = unpack("v1", substr($msg, $i + 6, 2));
		$item->{equipped} = unpack("v1", substr($msg, $i + 8, 2));
		$item->{broken} = unpack("C1", substr($msg, $i + 10, 1));
		$item->{upgrade} = unpack("C1", substr($msg, $i + 11, 1));
		$item->{cards} = substr($msg, $i + 12, 8);
		$item->{name} = itemName($item);
		if ($item->{equipped}) {
			foreach (%equipSlot_rlut){
				if ($_ & $item->{equipped}){
					next if $_ == 10; #work around Arrow bug
					$char->{equipment}{$equipSlot_lut{$_}} = $item;
				}
			}
		}


		debug "Inventory: $item->{name} ($invIndex) x $item->{amount} - $itemTypes_lut{$item->{type}} - $equipTypes_lut{$item->{type_equip}}\n", "parseMsg";
		Plugins::callHook('packet_inventory', {index => $invIndex});
	}

	$ai_v{'inventory_time'} = time + 1;
	$ai_v{'cart_time'} = time + 1;
}

sub inventory_items_stackable {
	my ($self, $args) = @_;
	$conState = 5 if ($conState != 4 && $xkore);
	my $newmsg;
	decrypt(\$newmsg, substr($msg, 4));
	my $msg = substr($args->{RAW_MSG}, 0, 4).$newmsg;
	my $psize = ($args->{switch} eq "00A3") ? 10 : 18;

	for (my $i = 4; $i < $args->{RAW_MSG_SIZE}; $i += $psize) {
		my $index = unpack("v1", substr($msg, $i, 2));
		my $ID = unpack("v1", substr($msg, $i + 2, 2));
		my $invIndex = findIndex($char->{inventory}, "index", $index);
		if ($invIndex eq "") {
			$invIndex = findIndex($char->{inventory}, "nameID", "");
		}

		my $item = $char->{inventory}[$invIndex] = new Item();
		$item->{invIndex} = $invIndex;
		$item->{index} = $index;
		$item->{nameID} = $ID;
		$item->{amount} = unpack("v1", substr($msg, $i + 6, 2));
		$item->{type} = unpack("C1", substr($msg, $i + 4, 1));
		$item->{identified} = 1;
		if (defined $char->{arrow} && $index == $char->{arrow}) {
			$item->{equipped} = 32768;
			$char->{equipment}{arrow} = $item;
		}
		$item->{name} = itemNameSimple($item->{nameID});
		debug "Inventory: $item->{name} ($invIndex) x $item->{amount} - " .
			"$itemTypes_lut{$item->{type}}\n", "parseMsg";
		Plugins::callHook('packet_inventory', {index => $invIndex, item => $item});
	}

	$ai_v{'inventory_time'} = time + 1;
	$ai_v{'cart_time'} = time + 1;
}

sub item_appeared {
	my ($self, $args) = @_;
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
	my ($self, $args) = @_;
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
	my ($self, $args) = @_;
	$conState = 5 if ($conState != 4 && $xkore);
	if ($items{$args->{ID}} && %{$items{$args->{ID}}}) {
		if ($config{attackLooters} && AI::action ne "sitAuto" && ( $itemsPickup{lc($items{$args->{ID}}{name})} ne '' ? $itemsPickup{lc($items{$args->{ID}}{name})} : $itemsPickup{'all'} ) ) {
			foreach my $looter (values %monsters) { #attack looter code
				next if (!$looter || !%{$looter});
				if (distance($items{$args->{ID}}{pos},$looter->{pos}) == 0) {
					attack ($looter->{ID});
					message "Attack Looter: $looter looted $items{$args->{ID}}{'name'}\n","looter";
					last;
				}
			}
		}
		debug "Item Disappeared: $items{$args->{ID}}{'name'} ($items{$args->{ID}}{'binID'})\n", "parseMsg_presence";
		%{$items_old{$args->{ID}}} = %{$items{$args->{ID}}};
		$items_old{$args->{ID}}{'disappeared'} = 1;
		$items_old{$args->{ID}}{'gone_time'} = time;
		delete $items{$args->{ID}};
		binRemove(\@itemsID, $args->{ID});
	}
}

sub item_upgrade {
	my ($self, $args) = @_;

	my ($type, $index, $upgrade) = @{$args}{qw(type index upgrade)};

	my $invIndex = findIndex($char->{inventory}, "index", $index);
	if (defined $invIndex) {
		my $item = $char->{inventory}[$invIndex];
		$item->{upgrade} = $upgrade;
		message "Item $item->{name} has been upgraded to +$upgrade\n", "parseMsg/upgrade";
		$item->{name} = itemName($item);
	}
}

sub job_equipment_hair_change {
	my ($self, $args) = @_;
	$conState = 5 if ($conState != 4 && $xkore);

	my $actor = Actor::get($args->{ID});
	if ($args->{part} == 0) {
		# Job change
		$actor->{jobID} = $args->{number};
		message "$actor changed job to: $jobs_lut{$args->{number}}\n", "parseMsg/job", ($actor->{type} eq 'You' ? 0 : 2);

	} elsif ($args->{part} == 3) {
		# Bottom headgear change
		message "$actor changed bottom headgear to: ".headgearName($args->{number})."\n", "parseMsg_statuslook", 2 unless $actor->{type} eq 'You';
		$actor->{headgear}{low} = $args->{number} if $actor->{type} eq 'Player';

	} elsif ($args->{part} == 4) {
		# Top headgear change
		message "$actor changed top headgear to: ".headgearName($args->{number})."\n", "parseMsg_statuslook", 2 unless $actor->{type} eq 'You';
		$actor->{headgear}{top} = $args->{number} if $actor->{type} eq 'Player';

	} elsif ($args->{part} == 5) {
		# Middle headgear change
		message "$actor changed middle headgear to: ".headgearName($args->{number})."\n", "parseMsg_statuslook", 2 unless $actor->{type} eq 'You';
		$actor->{headgear}{mid} = $args->{number} if $actor->{type} eq 'Player';

	} elsif ($args->{part} == 6) {
		# Hair color change
		$actor->{hair_color} = $args->{number};
		message "$actor changed hair color to: $haircolors{$args->{number}} ($args->{number})\n", "parseMsg/hairColor", ($actor->{type} eq 'You' ? 0 : 2);
	}

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
	#	my $actor = Actor::get($ID);
	#	$actor->{headgear}{$part} = $items_lut{$number} if ($actor);
	#	my $itemName = $items_lut{$itemID};
	#	$itemName = 'nothing' if (!$itemName);
	#	debug "$name changes $parts{$part} ($part) equipment to $itemName\n", "parseMsg";
	#} else {
	#	debug "$name changes $parts{$part} ($part) equipment to item #$number\n", "parseMsg";
	#}

}

sub login_error {
	my ($self, $args) = @_;

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
	my ($self, $args) = @_;
	$conState = 4 if ($conState != 4 && $xkore);

	($ai_v{temp}{map}) = $args->{map} =~ /([\s\S]*)\./;
	checkAllowedMap($ai_v{temp}{map});
	if ($ai_v{temp}{map} ne $field{name}) {
		getField($ai_v{temp}{map}, \%field);
	}

	AI::clear if $ai_v{temp}{clear_aiQueue};

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
	my ($self, $args) = @_;
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
	my ($self, $args) = @_;
	$conState = 5;
	undef $conState_tries;
	$char = $chars[$config{'char'}];

	if ($xkore) {
		$conState = 4;
		message("Waiting for map to load...\n", "connection");
		ai_clientSuspend(0, 10);
		main::initMapChangeVars();
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

sub mvp_item {
	my ($self, $args) = @_;
	my $display = itemNameSimple($args->{itemID});
	message "Get MVP item $display\n";
	chatLog("k", "Get MVP item $display\n");
}

sub mvp_other {
	my ($self, $args) = @_;
	my $display = Actor::get($args->{ID});
	message "$display become MVP!\n";
	chatLog("k", "$display became MVP!\n");
}

sub mvp_you {
	my ($self, $args) = @_;
	my $msg = "Congratulations, you are the MVP! Your reward is $args->{expAmount} exp!\n";
	message $msg;
	chatLog("k", $msg);
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

sub npc_sell_list {
	my ($self, $args) = @_;
	#sell list, similar to buy list
	if (length($args->{RAW_MSG}) > 4) {
		my $newmsg;
		decrypt(\$newmsg, substr($args->{RAW_MSG}, 4));
		my $msg = substr($args->{RAW_MSG}, 0, 4).$newmsg;
	}
	undef $talk{buyOrSell};
	message "Ready to start selling items\n";

	# continue talk sequence now
	$ai_v{npc_talk}{time} = time;
}

sub npc_store_begin {
	my ($self, $args) = @_;
	undef %talk;
	$talk{buyOrSell} = 1;
	$talk{ID} = $args->{ID};
	$ai_v{npc_talk}{talk} = 'buy';
	$ai_v{npc_talk}{time} = time;

	my $name = getNPCName($args->{ID});

	message "$name: Type 'store' to start buying, or type 'sell' to start selling\n", "npc";
}

sub npc_store_info {
	my ($self, $args) = @_;
	my $newmsg;
	decrypt(\$newmsg, substr($args->{RAW_MSG}, 4));
	my $msg = substr($args->{RAW_MSG}, 0, 4).$newmsg;
	undef @storeList;
	my $storeList = 0;
	undef $talk{'buyOrSell'};
	for (my $i = 4; $i < $args->{RAW_MSG_SIZE}; $i += 11) {
		my $price = unpack("V1", substr($msg, $i, 4));
		my $type = unpack("C1", substr($msg, $i + 8, 1));
		my $ID = unpack("v1", substr($msg, $i + 9, 2));

		my $store = $storeList[$storeList] = {};
		my $display = ($items_lut{$ID} ne "")
			? $items_lut{$ID}
			: "Unknown ".$ID;
		$store->{name} = $display;
		$store->{nameID} = $ID;
		$store->{type} = $type;
		$store->{price} = $price;
		debug "Item added to Store: $store->{name} - $price z\n", "parseMsg", 2;
		$storeList++;
	}

	my $name = getNPCName($talk{ID});
	$ai_v{npc_talk}{talk} = 'store';
	# continue talk sequence now
	$ai_v{'npc_talk'}{'time'} = time;

	if ($ai_seq[0] ne 'buyAuto') {
		message("----------$name's Store List-----------\n", "list");
		message("#  Name                    Type           Price\n", "list");
		my $display;
		for (my $i = 0; $i < @storeList; $i++) {
			$display = $storeList[$i]{'name'};
			message(swrite(
				"@< @<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<< @>>>>>>>z",
				[$i, $display, $itemTypes_lut{$storeList[$i]{'type'}}, $storeList[$i]{'price'}]),
				"list");
		}
		message("-------------------------------\n", "list");
	}
}

sub npc_talk {
	my ($self, $args) = @_;
	my $newmsg;
	decrypt(\$newmsg, substr($args->{RAW_MSG}, 8));
	my $msg = substr($args->{RAW_MSG}, 0, 8).$newmsg;
	my $ID = substr($msg, 4, 4);
	my $talk = unpack("Z*", substr($msg, 8));
	$talk{'ID'} = $ID;
	$talk{'nameID'} = unpack("V1", $ID);
	$talk{'msg'} = $talk;
	# Remove RO color codes
	$talk{'msg'} =~ s/\^[a-fA-F0-9]{6}//g;

	my $name = getNPCName($ID);

	message "$name: $talk{'msg'}\n", "npc";
}

sub npc_talk_close {
	my ($self, $args) = @_;
	# 00b6: long ID
	# "Close" icon appreared on the NPC message dialog
	my $ID = $args->{ID};
	undef %talk;

	my $name = getNPCName($ID);

	message "$name: Done talking\n", "npc";
	$ai_v{'npc_talk'}{'talk'} = 'close';
	$ai_v{'npc_talk'}{'time'} = time;
	sendTalkCancel(\$remote_socket, $ID);

	Plugins::callHook('npc_talk_done', {ID => $ID});
}

sub npc_talk_continue {
	my ($self, $args) = @_;
	# 00b5: long ID
	# "Next" button appeared on the NPC message dialog
	my $ID = substr($args->{RAW_MSG}, 2, 4);

	my $name = getNPCName($ID);

	$ai_v{npc_talk}{talk} = 'next';
	$ai_v{npc_talk}{time} = time;

	if ($config{autoTalkCont}) {
		message "$name: Auto-continuing talking\n", "npc";
		sendTalkContinue(\$remote_socket, $ID);
		# this time will be reset once the NPC responds
		$ai_v{'npc_talk'}{'time'} = time + $timeout{'ai_npcTalk'}{'timeout'} + 5;
	} else {
		message "$name: Type 'talk cont' to continue talking\n", "npc";
	}
}

sub npc_talk_responses {
	my ($self, $args) = @_;
	# 00b7: word len, long ID, string str
	# A list of selections appeared on the NPC message dialog.
	# Each item is divided with ':'
	my $newmsg;
	decrypt(\$newmsg, substr($args->{RAW_MSG}, 8));
	my $msg = substr($msg, 0, 8).$newmsg;
	my $ID = substr($msg, 4, 4);
	$talk{'ID'} = $ID;
	my $talk = unpack("Z*", substr($msg, 8));
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

	my $name = getNPCName($ID);

	message("$name: Type 'talk resp #' to choose a response.\n", "npc");
}

sub party_chat {
	my ($self, $args) = @_;
	my $msg;
	decrypt(\$msg, $args->{message});
	my ($chatMsgUser, $chatMsg) = $msg =~ /(.*?) : (.*)/;
	$chatMsgUser =~ s/ $//;

	stripLanguageCode(\$chatMsg);
	my $chat = "$chatMsgUser : $chatMsg";
	message "[Party] $chat\n", "partychat";

	chatLog("p", "$chat\n") if ($config{'logPartyChat'});
	ChatQueue::add('p', $args->{ID}, $chatMsgUser, $chatMsg);

	Plugins::callHook('packet_partyMsg', {
	        MsgUser => $chatMsgUser,
	        Msg => $chatMsg
	});

	$args->{chatMsgUser} = $chatMsgUser;
	$args->{chatMsg} = $chatMsg;
}

sub party_exp {
	my ($self, $args) = @_;
	$chars[$config{char}]{party}{share} = $args->{type};
	if ($args->{type} == 0) {
		message "Party EXP set to Individual Take\n", "party", 1;
	} elsif ($args->{type} == 1) {
		message "Party EXP set to Even Share\n", "party", 1;
	} else {
		error "Error setting party option\n";
	}
}

sub party_hp_info {
	my ($self, $args) = @_;
	my $ID = $args->{ID};
	$chars[$config{char}]{party}{users}{$ID}{hp} = $args->{hp};
	$chars[$config{char}]{party}{users}{$ID}{hp_max} = $args->{hp_max};
}

sub party_invite {
	my ($self, $args) = @_;
	message "Incoming Request to join party '$args->{name}'\n";
	$incomingParty{ID} = $args->{ID};
	$timeout{ai_partyAutoDeny}{time} = time;
}

sub party_invite_result {
	my ($self, $args) = @_;
	if ($args->{type} == 0) {
		warning "Join request failed: $args->{name} is already in a party\n";
	} elsif ($args->{type} == 1) {
		warning "Join request failed: $args->{name} denied request\n";
	} elsif ($args->{type} == 2) {
		message "$args->{name} accepted your request\n", "info";
	}
}

sub party_join {
	my ($self, $args) = @_;

	my ($ID, $x, $y, $type, $name, $user, $map) = @{$args}{qw(ID x y type name user map)};

	if (!$char->{party} || !%{$char->{party}} || !$chars[$config{char}]{party}{users}{$ID} || !%{$chars[$config{char}]{party}{users}{$ID}}) {
		binAdd(\@partyUsersID, $ID) if (binFind(\@partyUsersID, $ID) eq "");
		if ($ID eq $accountID) {
			message "You joined party '$name'\n", undef, 1;
			$char->{party} = {};
		} else {
			message "$user joined your party '$name'\n", undef, 1;
		}
	}
	$chars[$config{char}]{party}{users}{$ID} = new Actor::Party;
	if ($type == 0) {
		$chars[$config{char}]{party}{users}{$ID}{online} = 1;
	} elsif ($type == 1) {
		$chars[$config{char}]{party}{users}{$ID}{online} = 0;
	}
	$chars[$config{char}]{party}{name} = $name;
	$chars[$config{char}]{party}{users}{$ID}{pos}{x} = $x;
	$chars[$config{char}]{party}{users}{$ID}{pos}{y} = $y;
	$chars[$config{char}]{party}{users}{$ID}{map} = $map;
	$chars[$config{char}]{party}{users}{$ID}{name} = $user;

	if ($config{partyAutoShare} && $char->{party} && $char->{party}{users}{$accountID}{admin}) {
		sendPartyShareEXP(\$remote_socket, 1);
	}
}

sub party_leave {
	my ($self, $args) = @_;

	my $ID = $args->{ID};
	delete $chars[$config{char}]{party}{users}{$ID};
	binRemove(\@partyUsersID, $ID);
	if ($ID eq $accountID) {
		message "You left the party\n";
		delete $chars[$config{char}]{party} if ($chars[$config{char}]{party});
		undef @partyUsersID;
	} else {
		message "$args->{name} left the party\n";
	}
}

sub party_location {
	my ($self, $args) = @_;
	my $ID = $args->{ID};
	$chars[$config{char}]{party}{users}{$ID}{pos}{x} = $args->{x};
	$chars[$config{char}]{party}{users}{$ID}{pos}{y} = $args->{y};
	$chars[$config{char}]{party}{users}{$ID}{online} = 1;
	debug "Party member location: $chars[$config{char}]{party}{users}{$ID}{name} - $args->{x}, $args->{y}\n", "parseMsg";
}

sub party_organize_result {
	my ($self, $args) = @_;
	if ($args->{fail}) {
		warning "Can't organize party - party name exists\n";
	}
}

sub party_users_info {
	my ($self, $args) = @_;

	my $msg;
	decrypt(\$msg, substr($args->{RAW_MSG}, 28));
	$msg = substr($args->{RAW_MSG}, 0, 28).$msg;
	$char->{party}{name} = $args->{party_name};

	for (my $i = 28; $i < $args->{RAW_MSG_SIZE}; $i += 46) {
		my $ID = substr($msg, $i, 4);
		my $num = unpack("C1", substr($msg, $i + 44, 1));
		if (binFind(\@partyUsersID, $ID) eq "") {
			binAdd(\@partyUsersID, $ID);
		}
		$chars[$config{char}]{party}{users}{$ID} = new Actor::Party;
		$chars[$config{char}]{party}{users}{$ID}{name} = unpack("Z24", substr($msg, $i + 4, 24));
		message "Party Member: $chars[$config{char}]{party}{users}{$ID}{name}\n", undef, 1;
		$chars[$config{char}]{party}{users}{$ID}{map} = unpack("Z16", substr($msg, $i + 28, 16));
		$chars[$config{char}]{party}{users}{$ID}{online} = !(unpack("C1",substr($msg, $i + 45, 1)));
		$chars[$config{char}]{party}{users}{$ID}{admin} = 1 if ($num == 0);
	}

	sendPartyShareEXP(\$remote_socket, 1) if ($config{partyAutoShare} && $chars[$config{char}]{party} && %{$chars[$config{char}]{party}});

}

sub pet_info {
	my ($self, $args) = @_;
	$pet{name} = $args->{name};
	$pet{nameflag} = $args->{nameflag};
	$pet{level} = $args->{level};
	$pet{hungry} = $args->{hungry};
	$pet{friendly} = $args->{friendly};
	$pet{accessory} = $args->{accessory};
	debug "Pet status: name: $pet{name} name set?: ". ($pet{nameflag} ? 'yes' : 'no') ." level=$pet{level} hungry=$pet{hungry} intimacy=$pet{friendly} accessory=".itemNameSimple($pet{accessory})."\n", "pet";
}

sub public_chat {
	my ($self, $args) = @_;
	($args->{chatMsgUser}, $args->{chatMsg}) = $args->{message} =~ /(.*?) : (.*)/;
	$args->{chatMsgUser} =~ s/ $//;

	stripLanguageCode(\$args->{chatMsg});

	my $actor = Actor::get($args->{ID});

	my $dist = "unknown";
	if ($actor->{type} ne 'Unknown') {
		$dist = distance($char->{pos_to}, $actor->{pos_to});
		$dist = sprintf("%.1f", $dist) if ($dist =~ /\./);
	}

	my $message;
	$message = "$args->{chatMsgUser} ($actor->{binID}): $args->{chatMsg}";

	# this code autovivifies $actor->{pos_to} but it doesnt matter
	chatLog("c", "[$field{name} $char->{pos_to}{x}, $char->{pos_to}{y}] [$actor->{pos_to}{x}, $actor->{pos_to}{y}] [dist=$dist] " .
		"$message\n") if ($config{logChat});
	message "[dist=$dist] $message\n", "publicchat";

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
	my ($self, $args) = @_;
	# Private message
	$conState = 5 if ($conState != 4 && $xkore);
	my $newmsg;
	decrypt(\$newmsg, substr($args->{RAW_MSG}, 28));
	my $msg = substr($args->{RAW_MSG}, 0, 28) . $newmsg;
	$args->{privMsg} = substr($msg, 28, $args->{RAW_MSG_SIZE} - 29); # why doesn't it want the last byte?
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
	my ($self, $args) = @_;
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
	my ($self, $args) = @_;
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
		($chars[$num]{'name'}) = unpack("Z*", substr($args->{RAW_MSG}, $i + 74, 24));
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
	my ($self, $args) = @_;
	message "Received character ID and Map IP from Game Login Server\n", "connection";
	$conState = 4;
	undef $conState_tries;
	$charID = $args->{charID};

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
	message "Char ID: ".getHex($charID)." (".unpack("V1", $charID).")\n", "connection";
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

sub refine_result {
	my ($self, $args) = @_;
	if ($args->{fail}) {
		message "You failed to refine a weapon (ID $args->{nameID})!\n";
	} else {
		message "You successfully refined a weapon (ID $args->{nameID})!\n";
	}

}

sub repair_list {
	my ($self, $args) = @_;
	my $msg;
	$msg .= "--------Repair List--------\n";
	for (my $i = 4; $i < $args->{RAW_MSG_SIZE}; $i += 13) {
		my $index = unpack("v1", substr($args->{RAW_MSG}, $i, 2));
		my $nameID = unpack("v1", substr($args->{RAW_MSG}, $i+2, 2));
		# what are these  two?
		my $status = unpack("V1", substr($args->{RAW_MSG}, $i+4, 4));
		my $status2 = unpack("V1", substr($args->{RAW_MSG}, $i+8, 4));
		my $listID = unpack("C1", substr($args->{RAW_MSG}, $i+12, 1));
		my $name = itemNameSimple($nameID);
		$msg .= "$index $name\n";
	}
	$msg .= "---------------------------\n";
	message $msg, "list";
}

sub repair_result {
	my ($self, $args) = @_;
	my $itemName = itemNameSimple($args->{nameID});
	if ($args->{flag}) {
		message "Repair of $itemName failed.\n";
	} else {
		message "Successfully repaired $itemName.\n";
	}
}

sub secure_login_key {
	my ($self, $args) = @_;
	$secureLoginKey = $args->{secure_key};
}

sub self_chat {
	my ($self, $args) = @_;
	($args->{chatMsgUser}, $args->{chatMsg}) = $args->{message} =~ /([\s\S]*?) : ([\s\S]*)/;
	# Note: $chatMsgUser/Msg may be undefined. This is the case on
	# eAthena servers: it uses this packet for non-chat server messages.

	my $message;
	if (defined $args->{chatMsgUser}) {
		stripLanguageCode(\$args->{chatMsg});
		$message = "$args->{chatMsgUser} : $args->{chatMsg}";
	} else {
		$message = $args->{message};
	}

	chatLog("c", "$message\n") if ($config{'logChat'});
	message "$message\n", "selfchat";

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
	$args->{source} = $source;
	$args->{target} = $target;
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
	$args->{skill} = $skill;
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
	my ($self, $args) = @_;
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

	# Set teleport time
	if ($args->{sourceID} eq $accountID && $skill->handle eq 'AL_TELEPORT') {
		$timeout{ai_teleport_delay}{time} = time;
	}

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

sub stats_added {
	my ($self, $args) = @_;
	if ($args->{val} == 207) {
		error "Not enough stat points to add\n";
	} else {
		if ($args->{type} == 13) {
			$char->{str} = $args->{val};
			debug "Strength: $args->{val}\n", "parseMsg";
			# Reset $statChanged back to 0 to tell kore that a stat can be raised again
			$statChanged = 0 if ($statChanged eq "str");

		} elsif ($args->{type} == 14) {
			$char->{agi} = $args->{val};
			debug "Agility: $args->{val}\n", "parseMsg";
			$statChanged = 0 if ($statChanged eq "agi");

		} elsif ($args->{type} == 15) {
			$char->{vit} = $args->{val};
			debug "Vitality: $args->{val}\n", "parseMsg";
			$statChanged = 0 if ($statChanged eq "vit");

		} elsif ($args->{type} == 16) {
			$char->{int} = $args->{val};
			debug "Intelligence: $args->{val}\n", "parseMsg";
			$statChanged = 0 if ($statChanged eq "int");

		} elsif ($args->{type} == 17) {
			$char->{dex} = $args->{val};
			debug "Dexterity: $args->{val}\n", "parseMsg";
			$statChanged = 0 if ($statChanged eq "dex");

		} elsif ($args->{type} == 18) {
			$char->{luk} = $args->{val};
			debug "Luck: $args->{val}\n", "parseMsg";
			$statChanged = 0 if ($statChanged eq "luk");

		} else {
			debug "Something: $args->{val}\n", "parseMsg";
		}
	}
	Plugins::callHook('packet_charStats', {
		type	=> $args->{type},
		val	=> $args->{val},
	});
}

sub stats_info {
	my ($self, $args) = @_;
	$char->{points_free} = $args->{points_free};
	$char->{str} = $args->{str};
	$char->{points_str} = $args->{points_str};
	$char->{agi} = $args->{agi};
	$char->{points_agi} = $args->{points_agi};
	$char->{vit} = $args->{vit};
	$char->{points_vit} = $args->{points_vit};
	$char->{int} = $args->{int};
	$char->{points_int} = $args->{points_int};
	$char->{dex} = $args->{dex};
	$char->{points_dex} = $args->{points_dex};
	$char->{luk} = $args->{luk};
	$char->{points_luk} = $args->{points_luk};
	$char->{attack} = $args->{attack};
	$char->{attack_bonus} = $args->{attack_bonus};
	$char->{attack_magic_min} = $args->{attack_magic_min};
	$char->{attack_magic_max} = $args->{attack_magic_max};
	$char->{def} = $args->{def};
	$char->{def_bonus} = $args->{def_bonus};
	$char->{def_magic} = $args->{def_magic};
	$char->{def_magic_bonus} = $args->{def_magic_bonus};
	$char->{hit} = $args->{hit};
	$char->{flee} = $args->{flee};
	$char->{flee_bonus} = $args->{flee_bonus};
	$char->{critical} = $args->{critical};
	debug	"Strength: $char->{str} #$char->{points_str}\n"
		."Agility: $char->{agi} #$char->{points_agi}\n"
		."Vitality: $char->{vit} #$char->{points_vit}\n"
		."Intelligence: $char->{int} #$char->{points_int}\n"
		."Dexterity: $char->{dex} #$char->{points_dex}\n"
		."Luck: $char->{luk} #$char->{points_luk}\n"
		."Attack: $char->{attack}\n"
		."Attack Bonus: $char->{attack_bonus}\n"
		."Magic Attack Min: $char->{attack_magic_min}\n"
		."Magic Attack Max: $char->{attack_magic_max}\n"
		."Defense: $char->{def}\n"
		."Defense Bonus: $char->{def_bonus}\n"
		."Magic Defense: $char->{def_magic}\n"
		."Magic Defense Bonus: $char->{def_magic_bonus}\n"
		."Hit: $char->{hit}\n"
		."Flee: $char->{flee}\n"
		."Flee Bonus: $char->{flee_bonus}\n"
		."Critical: $char->{critical}\n"
		."Status Points: $char->{points_free}\n", "parseMsg";
}

sub stat_info {
	my ($self,$args) = @_;
	$conState = 5 if ($conState != 4 && $xkore);
	if ($args->{type} == 0) {
		$char->{walk_speed} = $args->{val} / 1000;
		debug "Walk speed: $args->{val}\n", "parseMsg", 2;
	} elsif ($args->{type} == 3) {
		debug "Something2: $args->{val}\n", "parseMsg", 2;
	} elsif ($args->{type} == 4) {
		if ($args->{val} == 0) {
			delete $char->{muted};
			delete $char->{mute_period};
			message "Mute period expired.\n";
		} else {
			my $val = (0xFFFFFFFF - $args->{val}) + 1;
			$char->{mute_period} = $val * 60;
			$char->{muted} = time;
			if ($config{dcOnMute}) {
				message "You've been muted for $val minutes, auto disconnect!\n";
				chatLog("k", "*** You have been muted for $val minutes, auto disconnect! ***\n");
				quit();
			} else {
				message "You've been muted for $val minutes\n";
			}
		}
	} elsif ($args->{type} == 5) {
		$char->{hp} = $args->{val};
		debug "Hp: $args->{val}\n", "parseMsg", 2;
	} elsif ($args->{type} == 6) {
		$char->{hp_max} = $args->{val};
		debug "Max Hp: $args->{val}\n", "parseMsg", 2;
	} elsif ($args->{type} == 7) {
		$char->{sp} = $args->{val};
		debug "Sp: $args->{val}\n", "parseMsg", 2;
	} elsif ($args->{type} == 8) {
		$char->{sp_max} = $args->{val};
		debug "Max Sp: $args->{val}\n", "parseMsg", 2;
	} elsif ($args->{type} == 9) {
		$char->{points_free} = $args->{val};
		debug "Status Points: $args->{val}\n", "parseMsg", 2;
	} elsif ($args->{type} == 11) {
		$char->{lv} = $args->{val};
		message "You are now level $args->{val}\n", "success";
		if ($config{dcOnLevel} && $char->{lv} >= $config{dcOnLevel}) {
			message "Disconnecting on level $config{dcOnLevel}!\n";
			chatLog("k", "Disconnecting on level $config{dcOnLevel}!\n");
			quit();
		}
	} elsif ($args->{type} == 12) {
		$char->{points_skill} = $args->{val};
		debug "Skill Points: $args->{val}\n", "parseMsg", 2;
		# Reset $skillChanged back to 0 to tell kore that a skill can be auto-raised again
		if ($skillChanged == 2) {
			$skillChanged = 0;
		}
	} elsif ($args->{type} == 24) {
		$char->{weight} = $args->{val} / 10;
		debug "Weight: $char->{weight}\n", "parseMsg", 2;
	} elsif ($args->{type} == 25) {
		$char->{weight_max} = int($args->{val} / 10);
		debug "Max Weight: $char->{weight_max}\n", "parseMsg", 2;
	} elsif ($args->{type} == 41) {
		$char->{attack} = $args->{val};
		debug "Attack: $args->{val}\n", "parseMsg", 2;
	} elsif ($args->{type} == 42) {
		$char->{attack_bonus} = $args->{val};
		debug "Attack Bonus: $args->{val}\n", "parseMsg", 2;
	} elsif ($args->{type} == 43) {
		$char->{attack_magic_min} = $args->{val};
		debug "Magic Attack Min: $args->{val}\n", "parseMsg", 2;
	} elsif ($args->{type} == 44) {
		$char->{attack_magic_max} = $args->{val};
		debug "Magic Attack Max: $args->{val}\n", "parseMsg", 2;
	} elsif ($args->{type} == 45) {
		$char->{def} = $args->{val};
		debug "Defense: $args->{val}\n", "parseMsg", 2;
	} elsif ($args->{type} == 46) {
		$char->{def_bonus} = $args->{val};
		debug "Defense Bonus: $args->{val}\n", "parseMsg", 2;
	} elsif ($args->{type} == 47) {
		$char->{def_magic} = $args->{val};
		debug "Magic Defense: $args->{val}\n", "parseMsg", 2;
	} elsif ($args->{type} == 48) {
		$char->{def_magic_bonus} = $args->{val};
		debug "Magic Defense Bonus: $args->{val}\n", "parseMsg", 2;
	} elsif ($args->{type} == 49) {
		$char->{hit} = $args->{val};
		debug "Hit: $args->{val}\n", "parseMsg", 2;
	} elsif ($args->{type} == 50) {
		$char->{flee} = $args->{val};
		debug "Flee: $args->{val}\n", "parseMsg", 2;
	} elsif ($args->{type} == 51) {
		$char->{flee_bonus} = $args->{val};
		debug "Flee Bonus: $args->{val}\n", "parseMsg", 2;
	} elsif ($args->{type} == 52) {
		$char->{critical} = $args->{val};
		debug "Critical: $args->{val}\n", "parseMsg", 2;
	} elsif ($args->{type} == 53) {
		$char->{attack_speed} = 200 - $args->{val}/10;
		debug "Attack Speed: $char->{attack_speed}\n", "parseMsg", 2;
	} elsif ($args->{type} == 55) {
		$char->{lv_job} = $args->{val};
		message "You are now job level $args->{val}\n", "success";
		if ($config{dcOnJobLevel} && $char->{lv_job} >= $config{dcOnJobLevel}) {
			message "Disconnecting on job level $config{dcOnJobLevel}!\n";
			chatLog("k", "Disconnecting on job level $config{dcOnJobLevel}!\n");
			quit();
		}
	} elsif ($args->{type} == 124) {
		debug "Something3: $args->{val}\n", "parseMsg", 2;
	} else {
		debug "Something: $args->{val}\n", "parseMsg", 2;
	}
}

sub stat_info2 {
	my ($self, $args) = @_;
	my ($type, $val, $val2) = @{$args}{qw(type val val2)};
	if ($type == 13) {
		$char->{str} = $val;
		$char->{str_bonus} = $val2;
		debug "Strength: $val + $val2\n", "parseMsg";
	} elsif ($type == 14) {
		$char->{agi} = $val;
		$char->{agi_bonus} = $val2;
		debug "Agility: $val + $val2\n", "parseMsg";
	} elsif ($type == 15) {
		$char->{vit} = $val;
		$char->{vit_bonus} = $val2;
		debug "Vitality: $val + $val2\n", "parseMsg";
	} elsif ($type == 16) {
		$char->{int} = $val;
		$char->{int_bonus} = $val2;
		debug "Intelligence: $val + $val2\n", "parseMsg";
	} elsif ($type == 17) {
		$char->{dex} = $val;
		$char->{dex_bonus} = $val2;
		debug "Dexterity: $val + $val2\n", "parseMsg";
	} elsif ($type == 18) {
		$char->{luk} = $val;
		$char->{luk_bonus} = $val2;
		debug "Luck: $val + $val2\n", "parseMsg";
	}
}

sub stats_points_needed {
	my ($self, $args) = @_;
	if ($args->{type} == 32) {
		$char->{points_str} = $args->{val};
		debug "Points needed for Strength: $args->{val}\n", "parseMsg";
	} elsif ($args->{type}  == 33) {
		$char->{points_agi} = $args->{val};
		debug "Points needed for Agility: $args->{val}\n", "parseMsg";
	} elsif ($args->{type} == 34) {
		$char->{points_vit} = $args->{val};
		debug "Points needed for Vitality: $args->{val}\n", "parseMsg";
	} elsif ($args->{type} == 35) {
		$char->{points_int} = $args->{val};
		debug "Points needed for Intelligence: $args->{val}\n", "parseMsg";
	} elsif ($args->{type} == 36) {
		$char->{points_dex} = $args->{val};
		debug "Points needed for Dexterity: $args->{val}\n", "parseMsg";
	} elsif ($args->{type} == 37) {
		$char->{points_luk} = $args->{val};
		debug "Points needed for Luck: $args->{val}\n", "parseMsg";
	}
}

sub storage_closed {
	message "Storage closed.\n", "storage";
	delete $ai_v{temp}{storage_opened};
	Plugins::callHook('packet_storage_close');

	# Storage log
	writeStorageLog(0);
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
		$item->{type} = $args->{type};
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

sub storage_item_removed {
	my ($self, $args) = @_;

	my ($index, $amount) = @{$args}{qw(index amount)};

	$storage{$index}{amount} -= $amount;
	message "Storage Item Removed: $storage{$index}{name} ($storage{$index}{binID}) x $amount\n", "storage";
	$itemChange{$storage{$index}{name}} -= $amount;
	if ($storage{$index}{amount} <= 0) {
		delete $storage{$index};
		binRemove(\@storageID, $index);
	}
}

sub storage_items_nonstackable {
	my ($self, $args) = @_;
	# Retrieve list of non-stackable (weapons & armor) storage items.
	# This packet is sent immediately after 00A5/01F0.
	my $newmsg;
	decrypt(\$newmsg, substr($args->{RAW_MSG}, 4));
	my $msg = substr($args->{RAW_MSG}, 0, 4).$newmsg;

	for (my $i = 4; $i < $args->{RAW_MSG_SIZE}; $i += 20) {
		my $index = unpack("v1", substr($msg, $i, 2));
		my $ID = unpack("v1", substr($msg, $i + 2, 2));

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
}

sub storage_items_stackable {
	my ($self, $args) = @_;
	# Retrieve list of stackable storage items
	my $newmsg;
	decrypt(\$newmsg, substr($args->{RAW_MSG}, 4));
	my $msg = substr($args->{RAW_MSG}, 0, 4).$newmsg;
	undef %storage;
	undef @storageID;

	my $psize = ($args->{switch} eq "00A5") ? 10 : 18;
	for (my $i = 4; $i < $args->{RAW_MSG_SIZE}; $i += $psize) {
		my $index = unpack("v1", substr($msg, $i, 2));
		my $ID = unpack("v1", substr($msg, $i + 2, 2));
		binAdd(\@storageID, $index);
		my $item = $storage{$index} = {};
		$item->{index} = $index;
		$item->{nameID} = $ID;
		$item->{type} = unpack("C1", substr($msg, $i + 4, 1));
		$item->{amount} = unpack("V1", substr($msg, $i + 6, 4)) & ~0x80000000;
		$item->{name} = itemNameSimple($ID);
		$item->{binID} = binFind(\@storageID, $index);
		$item->{identified} = 1;
		debug "Storage: $item->{name} ($item->{binID}) x $item->{amount}\n", "parseMsg";
	}
}

sub storage_opened {
	my ($self, $args) = @_;
	$storage{items} = $args->{items};
	$storage{items_max} = $args->{items_max};

	$ai_v{temp}{storage_opened} = 1;
	if (!$storage{opened}) {
		$storage{opened} = 1;
		message "Storage opened.\n", "storage";
		Plugins::callHook('packet_storage_open');
	}
}

sub system_chat {
	my ($self, $args) = @_;
	#my $chat = substr($msg, 4, $msg_size - 4);
	#$chat =~ s/\000$//;

	stripLanguageCode(\$args->{message});
	chatLog("s", "$args->{message}\n") if ($config{'logSystemChat'});
	message "[GM] $args->{message}\n", "schat";
	ChatQueue::add('gm', undef, undef, $args->{message});
}

sub unequip_item {
	my ($self, $args) = @_;
	$conState = 5 if ($conState != 4 && $xkore);
	my $invIndex = findIndex($char->{inventory}, "index", $args->{index});
	$char->{inventory}[$invIndex]{equipped} = "";
	if ($args->{type} == 10) {
		$char->{equipment}{arrow} = undef;
	} else {
		foreach (%equipSlot_rlut){
			if ($_ & $args->{type}){
				next if $_ == 10; #work around Arrow bug
				$char->{equipment}{$equipSlot_lut{$_}} = undef;
			}
		}
	}
	message "You unequip $char->{inventory}[$invIndex]{name} ($invIndex) - $equipTypes_lut{$char->{inventory}[$invIndex]{type_equip}}\n", 'inventory';
}

sub use_item {
	my ($self, $args) = @_;
	$conState = 5 if ($conState != 4 && $xkore);
	my $invIndex = findIndex($char->{inventory}, "index", $args->{index});
	if (defined $invIndex) {
		$char->{inventory}[$invIndex]{amount} -= $args->{amount};
		message "You used Item: $char->{inventory}[$invIndex]{name} ($invIndex) x $args->{amount}\n", "useItem";
		if ($char->{inventory}[$invIndex]{amount} <= 0) {
			delete $char->{inventory}[$invIndex];
		}
	}
}

sub users_online {
	my ($self, $args) = @_;
	message "There are currently $args->{users} users online\n", "info";
}

sub warp_portal_list {
	my ($self, $args) = @_;
	# strip gat extension
	($args->{memo1}) = $args->{memo1} =~ /^(.*)\.gat/;
	($args->{memo2}) = $args->{memo2} =~ /^(.*)\.gat/;
	($args->{memo3}) = $args->{memo3} =~ /^(.*)\.gat/;
	($args->{memo4}) = $args->{memo4} =~ /^(.*)\.gat/;
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
