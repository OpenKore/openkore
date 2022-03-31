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
# iRO (International) as of June 21 2007.
# Servertype overview: https://openkore.com/wiki/ServerType
package Network::Send::ServerType18;

use strict;
use Network::PaddedPackets;
use base qw(Network::Send::ServerType0);

use Globals qw($masterServer);
use Log qw(debug);
use Utils qw(getHex getCoordString2);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'007E' => ['item_drop', 'v2', [qw(amount ID)]],
		'0085' => ['character_move', 'x4 a3', [qw(coords)]],
		'008C' => ['skill_use_location', 'v3 x4 v', [qw(lv skillID x y)]],
		'009B' => ['storage_item_remove', 'V x12 a2', [qw(amount ID)]],
		'00A2' => ['storage_item_add', 'a2 V x8', [qw(ID amount)]],
		'00A7' => ['sync', 'x6 V', [qw(time)]],
		'009F' => ['item_use', 'v a4', [qw(ID targetID)]],
		'00F3' => ['map_login', 'x3 a4 a4 x a4 x9 V C x5', [qw(charID accountID sessionID tick sex)]],
		'0113' => ['storage_close'],
		'0193' => ['actor_info_request', 'x3 a4', [qw(ID)]],
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		item_drop 007E
		character_move 0085
		skill_use_location 008C
		storage_item_remove 009B
		storage_item_add 00A2
		sync 00A7
		item_use 009F
		map_login 00F3
		actor_look_at 00F7
		storage_close 0113
		item_take 0116
		public_chat 0190
		actor_info_request 0193
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

sub reconstruct_character_move {
	my ($self, $args) = @_;

	$args->{no_padding} = defined $args->{no_padding} ? $args->{no_padding} : $masterServer->{serverType} == 0;

	$args->{coords} = getCoordString2(@{$args}{qw(x y)}, $args->{no_padding});
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

sub sendSkillUse {
	my ($self, $ID, $lv, $targetID) = @_;
	$self->sendToServer(Network::PaddedPackets::generateSkillUse($ID, $lv,  $targetID));
	debug "Skill Use: $ID\n", "sendPacket", 2;
}

1;