#########################################################################
#  OpenKore - Packet Receiveing
#  This module contains functions for Receiveing packets to the server.
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
########################################################################
# Korea (kRO) #bysctnightcore
# The majority of private servers use eAthena, this is a clone of kRO
package Network::Receive::Zero;
use strict;
use base qw(Network::Receive::ServerType0);
use Log qw(warning debug error message);
use Globals;
use Translation;
use I18N qw(bytesToString);
use Socket qw(inet_ntoa);
use Utils;
use Utils::DataStructures;

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'020D' => ['character_ban_list', 'v a*', [qw(len charList)]], # -1 charList[charName size:24]
		'09FD' => ['actor_moved', 'v C a4 a4 v3 V v5 a4 v6 a4 a2 v V C2 a6 C2 v2 a9 Z*', [qw(len object_type ID charID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tick tophead midhead hair_color clothes_color head_dir costume guildID emblemID manner opt3 stance sex coords xSize ySize lv font opt4 name)]],
		'09FE' => ['actor_connected', 'v C a4 a4 v3 V v11 a4 a2 v V C2 a3 C2 v2 a9 Z*', [qw(len object_type ID charID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir costume guildID emblemID manner opt3 stance sex coords xSize ySize lv font opt4 name)]],
		'09FF' => ['actor_exists', 'v C a4 a4 v3 V v11 a4 a2 v V C2 a3 C3 v2 a9 Z*', [qw(len object_type ID charID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir costume guildID emblemID manner opt3 stance sex coords xSize ySize act lv font opt4 name)]],
		'0A00' => ['hotkeys'],
		'0A30' => ['actor_info', 'a4 Z24 Z24 Z24 Z24 x4', [qw(ID name partyName guildName guildTitle)]],
		'0A37' => ['inventory_item_added', 'a2 v2 C3 a8 V C2 a4 v a25', [qw(ID amount nameID identified broken upgrade cards type_equip type fail expire unknown options)]],
		'0A89' => ['clone_vender_found', 'a4 v4 C v9 Z24', [qw(ID jobID unknown coord_x coord_y sex head_dir weapon shield lowhead tophead midhead hair_color clothes_color robe title)]],
		'0A8A' => ['clone_vender_lost', 'v a4', [qw(len ID)]],		
		'0AC4' => ['account_server_info', 'x2 a4 a4 a4 a4 a26 C x17 a*', [qw(sessionID accountID sessionID2 lastLoginIP lastLoginTime accountSex serverInfo)]],
		'0AC5' => ['received_character_ID_and_Map', 'a4 Z16 a4 v', [qw(charID mapName mapIP mapPort)]], #miss 128 unknow
		'0AC7' => ['map_changed', 'Z16 v2 a4 v', [qw(map x y IP port)]], # 28
		'0ACB' => ['stat_info', 'v Z8', [qw(type val)]],
		'0ACC' => ['exp', 'a4 Z8 v2', [qw(ID val type flag)]],
		'0ADC' => ['flag', 'a*', [qw(unknown)]],
		'0ADE' => ['flag', 'a*', [qw(unknown)]],
		'0ADF' => ['actor_info', 'a4 a4 Z24 Z24', [qw(ID charID name prefix_name)]],
		'0ADD' => ['item_exists', 'a4 v2 C v2 C2 v C v', [qw(ID nameID type identified x y subx suby amount show_effect effect_type )]],
		'0AE3' => ['received_login_token', 'v l Z20 Z*', [qw(len login_type flag login_token)]],
		'0AE4' => ['party_join', 'a4 a4 V v4 C Z24 Z24 Z16 C2', [qw(ID charID role jobID lv x y type name user map item_pickup item_share)]],
 		'0AE5' => ['party_users_info', 'v Z24 a*', [qw(len party_name playerInfo)]],
	);

	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	return $self;
}

sub received_login_token {
	my ($self, $args) = @_;

	my $master = $masterServers{$config{master}};

	$messageSender->sendTokenToServer($config{username}, $config{password}, $master->{master_version}, $master->{version}, $args->{login_token}, $args->{len}, $master->{OTT_ip}, $master->{OTT_port});
}

# from old ServerType0
sub map_loaded {
	my ($self, $args) = @_;
	$net->setState(Network::IN_GAME);
	undef $conState_tries;
	$char = $chars[$config{char}];
	return unless Network::Receive::changeToInGameState;

	if ($net->version == 1) {
		$net->setState(4);
		message(T("Waiting for map to load...\n"), "connection");
		ai_clientSuspend(0, 10);
		main::initMapChangeVars();
	} else {
		$messageSender->sendMapLoaded();

		$messageSender->sendSync(1);

		message(T("You are now in the game\n"), "connection");
		Plugins::callHook('in_game');
		$timeout{'ai'}{'time'} = time;
		our $quest_generation++;

		$messageSender->sendIgnoreAll("all") if ($config{ignoreAll}); # broking xkore 1 and 3 when use cryptkey
	}

	$char->{pos} = {};
	makeCoordsDir($char->{pos}, $args->{coords}, \$char->{look}{body});
	$char->{pos_to} = {%{$char->{pos}}};
	message(TF("Your Coordinates: %s, %s\n", $char->{pos}{x}, $char->{pos}{y}), undef, 1);
}

sub parse_account_server_info {
    my ($self, $args) = @_;

    @{$args->{servers}} = map {
		my %server;
		@server{qw(ip port name users state property unknown)} = unpack 'a4 v Z20 v3 a128', $_;		
		$server{ip} = inet_ntoa($server{ip});
		$server{name} = bytesToString($server{name});
		\%server
	} unpack '(a160)*', $args->{serverInfo};
}

sub character_ban_list {
	my ($self, $args) = @_;
	# Header + Len + CharList[character_name(size:24)]
}

sub flag {
	my ($self, $args) = @_;
}

sub parse_stat_info {
	my ($self, $args) = @_;
	if($args->{switch} eq "0ACB") {
		$args->{val} = getHex($args->{val});
		$args->{val} = join '', reverse split / /, $args->{val};
		$args->{val} = hex $args->{val};
	}
}

sub parse_exp {
	my ($self, $args) = @_;
	if($args->{switch} eq "0ACC") {
		$args->{val} = getHex($args->{val});
		$args->{val} = join '', reverse split / /, $args->{val};
		$args->{val} = hex $args->{val};
	}
}

sub clone_vender_found {
	my ($self, $args) = @_;
	my $ID = unpack("V", $args->{ID});
	if (!$venderLists{$ID} || !%{$venderLists{$ID}}) {
		binAdd(\@venderListsID, $ID);
		Plugins::callHook('packet_vender', {ID => $ID, title => bytesToString($args->{title})});
	}
	$venderLists{$ID}{title} = bytesToString($args->{title});
	$venderLists{$ID}{id} = $ID;

	my $actor = $playersList->getByID($args->{ID});
	if (!defined $actor) {
		$actor = new Actor::Player();
		$actor->{ID} = $args->{ID};
		$actor->{nameID} = $ID;
		$actor->{appear_time} = time;
		$actor->{jobID} = $args->{jobID};
		$actor->{pos_to}{x} = $args->{coord_x};
		$actor->{pos_to}{y} = $args->{coord_y};
		$actor->{walk_speed} = 1; #hack
		$actor->{robe} = $args->{robe};
		$actor->{clothes_color} = $args->{clothes_color};
		$actor->{headgear}{low} = $args->{lowhead};
		$actor->{headgear}{mid} = $args->{midhead};
		$actor->{headgear}{top} = $args->{tophead};
		$actor->{weapon} = $args->{weapon};
		$actor->{shield} = $args->{shield};
		$actor->{sex} = $args->{sex};
		$actor->{hair_color} = $args->{hair_color} if (exists $args->{hair_color});

		$playersList->add($actor);
		Plugins::callHook('add_player_list', $actor);
	}
}

sub clone_vender_lost {
	my ($self, $args) = @_;

	my $ID = unpack("V", $args->{ID});
	binRemove(\@venderListsID, $ID);
	delete $venderLists{$ID};

	if (defined $playersList->getByID($args->{ID})) {
		my $player = $playersList->getByID($args->{ID});

		if (grep { $ID eq $_ } @venderListsID) {
			binRemove(\@venderListsID, $ID);
			delete $venderLists{$ID};
		}

		$player->{gone_time} = time;
		$players_old{$ID} = $player->deepCopy();
		Plugins::callHook('player_disappeared', {player => $player});

		$playersList->removeByID($args->{ID});
	}
}

 sub party_users_info {
	my ($self, $args) = @_;
 	return unless Network::Receive::changeToInGameState();
 
 	$char->{party}{name} = bytesToString($args->{party_name});

	for (my $i = 0; $i < length($args->{playerInfo}); $i += 54) {
		my $ID = substr($args->{playerInfo}, $i, 4);
		if (binFind(\@partyUsersID, $ID) eq "") {
			binAdd(\@partyUsersID, $ID);
		}
		$char->{party}{users}{$ID} = new Actor::Party();
		@{$char->{party}{users}{$ID}}{qw(ID GID name map admin online jobID lv)} = unpack('V V Z24 Z16 C2 v2', substr($args->{playerInfo}, $i, 54));
		$char->{party}{users}{$ID}{name} = bytesToString($char->{party}{users}{$ID}{name});
		$char->{party}{users}{$ID}{admin} = !$char->{party}{users}{$ID}{admin};
		$char->{party}{users}{$ID}{online} = !$char->{party}{users}{$ID}{online};

		debug TF("Party Member: %s (%s)\n", $char->{party}{users}{$ID}{name}, $char->{party}{users}{$ID}{map}), "party", 1;
	}
}
1;