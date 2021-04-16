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
# pRO Valkyrie as of October 24 2007
# paddedPackets_attackID 0x0190
# paddedPackets_skillUseID 0x007E
# syncID 0x116
# syncTickOffset 9
# mapLoadedTickOffset 11
# Servertype overview: https://openkore.com/wiki/ServerType
package Network::Send::ServerType20;

use strict;
use base qw(Network::Send::ServerType0);

use Log qw(debug);
use Utils qw(getHex);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'0072' => ['actor_info_request', 'x a4', [qw(ID)]],
		'0085' => ['storage_close'],
		'0089' => ['item_use', 'a4 v', [qw(targetID ID)]],
		'008C' => ['storage_item_remove', 'x V a2', [qw(amount ID)]],
		'009B' => ['storage_item_add', 'x2 a2 V', [qw(ID amount)]],
		'00F3' => ['item_drop', 'v2', [qw(ID amount)]],
		'00F5' => ['character_move', 'x a3 x9', [qw(coords)]],
		'0113' => ['skill_use_location', 'v4 x2', [qw(y skillID x lv)]],
		'0116' => ['sync', 'x7 V x2', [qw(time)]],
		'0193' => ['map_login', 'x3 a4 a4 x5 a4 V x2 C x4', [qw(accountID charID sessionID tick sex)]],
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		actor_info_request 0072
		storage_close 0085
		item_use 0089
		storage_item_remove 008C
		item_take 0094
		storage_item_add 009B
		actor_look_at 009F
		public_chat 00A7
		item_drop 00F3
		character_move 00F5
		skill_use_location 0113
		sync 0116
		map_login 0193
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
