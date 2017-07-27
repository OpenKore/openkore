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
use Utils qw(getCoordString);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %handlers = qw(
		actor_info_request 48FF
    actor_look_at 49A3
		character_move 49B0
		sync 4AD0
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	$self->cryptKeys(0x42780CC0, 0x67F86D28, 0x1CEB0ADC);

	return $self;
}

sub sendMove {
	my ($self, $x, $y) = @_;

	my $msg = pack("C*", 0xB0, 0x49) . getCoordString($x, $y, 1);

	$self->sendToServer($msg);
	debug "Sent move to: $x, $y\n", "sendPacket", 1;
}

1;
