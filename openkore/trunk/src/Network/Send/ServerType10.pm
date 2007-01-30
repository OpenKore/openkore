#########################################################################
#  OpenKore - Packet sending
#  This module contains functions for sending packets to the server.
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
# vRO (Vietnam(
package Network::Send::ServerType10;

use strict;
use Network::Send::ServerType0;
use base qw(Network::Send::ServerType0);
use Log qw(debug);
use Utils qw(getTickCount getCoordString);

sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}

sub sendMapLogin {
	my ($self, $accountID, $charID, $sessionID, $sex) = @_;
	my $msg = pack("C*",0x9b, 0x00, 0x00) .
		$accountID .
		$charID .
		$sessionID .
		pack("C*",0x35, 0x32, 0x61, 0x00) .
		pack("V", getTickCount()) .
		pack("C*",0x35, 0x00) .
		pack("C*", $sex) .
		pack("C*", 0x35, 0x36, 0x00);
	$self->sendToServer($msg);
}

sub sendSync {
	my ($self, $initialSync) = @_;
	# XKore mode 1 lets the client take care of syncing.
	return if ($self->{net}->version == 1);

	my $msg = pack("C*", 0xF3, 0x00, 0x00);
	$msg .= pack("V", getTickCount());
	$msg .= pack("C*", 0x39, 0x63, 0x62, 0x00);

	$self->sendToServer($msg);
	debug "Sent Sync\n", "sendPacket", 2;
}

sub sendMove {
	my $self = shift;
	my $x = int scalar shift;
	my $y = int scalar shift;

	my $msg = pack("C*", 0x13, 0x01, 0x61, 0x38, 0x39, 0x34, 0x00) .
		getCoordString($x, $y, 1) . pack("C*", 0x39, 0x32, 0x00);

	$self->sendToServer($msg);
	debug "Sent move to: $x, $y\n", "sendPacket", 2;
}

1;
