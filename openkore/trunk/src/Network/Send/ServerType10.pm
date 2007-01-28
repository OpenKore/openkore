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
package Network::Send::ServerType10;

use strict;
use Network::Send::ServerType0;
use base qw(Network::Send::ServerType0);
use Utils qw(getTickCount);

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

1;
