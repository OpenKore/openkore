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
# iRO Re:Start
# Servertype overview: http://wiki.openkore.com/index.php/ServerType
package Network::Send::iRO::Restart;

use strict;
use base qw(Network::Send::ServerType0);
use Log qw(error debug);
# use Misc qw(visualDump);
use Utils qw(getCoordString getHex);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %handlers = qw(
		actor_info_request 48FF
    actor_look_at 49A3
		character_move 49B0
		sync 4AD0
		npc_talk 49A3
		npc_talk_continue 4035
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	return $self;
}

sub sendMove {
	# 0D 30
	# B0 69
	my ($self, $x, $y) = @_;

	my $msg = pack("C*", 0xB0, 0x49) . getCoordString($x, $y, 1);
	$self->sendToServer($msg);
	debug "Sent move to: $x, $y\n", "sendPacket", 2;
}

sub sendGetPlayerInfo {
	# DF 5E
	# 7F 0C
	# FF 48
	my ($self, $ID) = @_;

	my $msg = pack("C*", 0xFF, 0x48) . $ID;
	$self->sendToServer($msg);
	debug "Sent get player info: ID - ".getHex($ID)."\n", "sendPacket", 2;
}

sub sendSync {
	# 50 FC
	# 50 0E
	# D0 48
	# D0 72
	# D0 6A
	# D0 4A
	my ($self, $initialSync) = @_;
	# XKore mode 1 lets the client take care of syncing.
	return if ($self->{net}->version == 1);

	$self->sendToServer($self->reconstruct({switch => 'sync'}));
	debug "Sent Sync\n", "sendPacket", 2;
}

1;
