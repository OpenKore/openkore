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
use Globals qw(%config %masterServers $messageSender $net $char $conState_tries %timeout @chars);
use Translation;
use Utils qw(makeCoordsDir);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'020D' => ['character_ban_list', 'v a*', [qw(len charList)]], # -1 charList[charName size:24]
		'09FD' => ['actor_moved', 'v C a4 a4 v3 V v5 a4 v6 a4 a2 v V C2 a6 C2 v2 a9 Z*', [qw(len object_type ID charID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tick tophead midhead hair_color clothes_color head_dir costume guildID emblemID manner opt3 stance sex coords xSize ySize lv font opt4 name)]],
		'09FE' => ['actor_connected', 'v C a4 a4 v3 V v11 a4 a2 v V C2 a3 C2 v2 a9 Z*', [qw(len object_type ID charID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir costume guildID emblemID manner opt3 stance sex coords xSize ySize lv font opt4 name)]],
		'09FF' => ['actor_exists', 'v C a4 a4 v3 V v11 a4 a2 v V C2 a3 C3 v2 a9 Z*', [qw(len object_type ID charID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir costume guildID emblemID manner opt3 stance sex coords xSize ySize act lv font opt4 name)]],
		'0A00' => ['hotkeys'],
		'0A37' => ['inventory_item_added', 'a2 v2 C3 a8 V C2 a4 v a25', [qw(ID amount nameID identified broken upgrade cards type_equip type fail expire unknown options)]],
		'0AC4' => ['account_server_info', 'x2 a4 a4 a4 a4 a26 C x17 a*', [qw(sessionID accountID sessionID2 lastLoginIP lastLoginTime accountSex serverInfo)]],
		'0AC5' => ['received_character_ID_and_Map', 'a4 Z16 a4 v', [qw(charID mapName mapIP mapPort)]],
		'0ACB' => ['stat_info', 'v V', [qw(type val)]],
		'0ADC' => ['flag', 'a*', [qw(unknown)]],
		'0ADE' => ['flag', 'a*', [qw(unknown)]],
		'0ADF' => ['actor_info', 'a4 a4 Z24 Z24', [qw(ID charID name prefix_name)]],
		'0AE3' => ['received_login_token', 'v l Z20 Z*', [qw(len login_type flag login_token)]],		
		
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

sub character_ban_list {
	my ($self, $args) = @_;
	# Header + Len + CharList[character_name(size:24)]
}

sub flag {
	my ($self, $args) = @_;
}

1;