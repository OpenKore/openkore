#########################################################################
#  OpenKore - Network subsystem
#  This module contains functions for sending messages to the server.
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
# tRO (Thai) for 2007-05-22bRagexe by kLabMouse (thanks to abt123, championrpg and penz for support)
# latest updaes will go here. Please don't use this ServerType for other servers except tRO.
# Servertype overview: http://wiki.openkore.com/index.php/ServerType
package Network::Send::ServerType17;

use strict;
use Network::PaddedPackets;
use base qw(Network::Send::ServerType0);

use Log qw(debug);
use Utils qw(getHex);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'007E' => ['sync', 'x V x5', [qw(time)]],
		'0085' => ['storage_close'],
		'008C' => ['map_login', 'x3 a4 a4 x a4 x4 V C x2', [qw(accountID charID sessionID tick sex)]],
		'0094' => ['storage_item_remove', 'a2 V x6', [qw(ID amount)]],
		'009B' => ['item_drop', 'v2', [qw(ID amount)]],
		'009F' => ['skill_use_location', 'v x3 v3', [qw(y lv skillID x)]],
		'00A7' => ['storage_item_add', 'V x a2', [qw(amount ID)]],
		'00F5' => ['actor_name_request', 'a4 x5', [qw(ID)]],
		'00F7' => ['character_move', 'x11 a3', [qw(coords)]],
		'0113' => ['item_use', 'a4 v', [qw(targetID ID)]],
		'0190' => ['actor_info_request', 'a4 x', [qw(ID)]],
		'0275' => ['game_login', 'a4 a4 a4 v C x16 v x3', [qw(accountID sessionID sessionID2 userLevel accountSex iAccountSID)]],
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	my %handlers = qw(
		actor_look_at 0072
		sync 007E
		storage_close 0085
		map_login 008C
		storage_item_remove 0094
		item_drop 009B
		skill_use_location 009F
		storage_item_add 00A7
		public_chat 00F3
		actor_name_request 00F5
		character_move 00F7
		item_use 0113
		item_take 0116
		actor_info_request 0190
		game_login 0275
	);
	
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	
	return $self;
}

sub sendAction {
	my ($self, $monID, $flag) = @_;
	$self->sendToServer(Network::PaddedPackets::generateAtk($monID, $flag));
	debug "Sent Action: " .$flag. " on: " .getHex($monID)."\n", "sendPacket", 2;
}
=pod
sub sendSit {
	my ($self) = @_;
	$self->sendToServer(Network::PaddedPackets::generateSitStand(1));
	debug "Sitting\n", "sendPacket", 2;
}

sub sendStand {
	my ($self) = @_;
	$self->sendToServer(Network::PaddedPackets::generateSitStand(0));
	debug "Standing\n", "sendPacket", 2;
}
=cut

sub sendSkillUse {
	my ($self, $ID, $lv, $targetID) = @_;
	$self->sendToServer(Network::PaddedPackets::generateSkillUse($ID, $lv,  $targetID));
	debug "Skill Use: $ID\n", "sendPacket", 2;
}

sub sendMove {
	my ($self, $x, $y) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'character_move',
		x => $x,
		y => $y,
		no_padding => 1,
	}));
	
	debug "Sent move to: $x, $y\n", "sendPacket", 2;
}

1;