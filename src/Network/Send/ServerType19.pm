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
# pRO Valkyrie as of October 17 2007
# paddedPackets_attackID 0x0190
# paddedPackets_skillUseID 0x00A7
# Servertype overview: https://openkore.com/wiki/ServerType
package Network::Send::ServerType19;

use strict;
use Network::PaddedPackets;
use base qw(Network::Send::ServerType0);

use Log qw(debug);
use Utils qw(getHex);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'0072' => ['skill_use_location', 'x9 v4', [qw(lv skillID x y)]],
		'0089' => ['item_drop', 'v2', [qw(ID amount)]],
		'0094' => ['actor_info_request', 'x3 a4', [qw(ID)]],
		'009B' => ['sync', 'V x6', [qw(time)]],
		'009F' => ['storage_item_add', 'a2 x V', [qw(ID amount)]],
		'00F3' => ['storage_close'],
		'00F5' => ['item_use', 'v a4', [qw(ID targetID)]],
		'0113' => ['storage_item_remove', 'a2 x V', [qw(ID amount)]],
		'0116' => ['map_login', 'x10 C x3 a4 V a4 a4 x2', [qw(sex charID tick sessionID accountID)]],
		'0193' => ['character_move', 'a3 x6', [qw(coords)]],
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		skill_use_location 0072
		public_chat 0085
		item_drop 0089
		actor_look_at 008C
		actor_info_request 0094
		sync 009B
		storage_item_add 009F
		item_take 00A2
		storage_close 00F3
		item_use 00F5
		storage_item_remove 0113
		map_login 0116
		character_move 0193
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

sub sendSkillUse {
	my ($self, $ID, $lv, $targetID) = @_;
	$self->sendToServer(Network::PaddedPackets::generateSkillUse($ID, $lv,  $targetID));
	debug "Skill Use: $ID\n", "sendPacket", 2;
}

1;
