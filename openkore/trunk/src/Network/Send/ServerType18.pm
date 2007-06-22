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
package Network::Send::ServerType18;

use strict;
use Globals qw($char $syncSync $net %config);
use Network::Send::ServerType11;
use base qw(Network::Send::ServerType0);
use Log qw(error debug);
use I18N qw(stringToBytes);
use Utils qw(getTickCount getHex getCoordString2);

sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}

# Create a random byte string of a specified length.
sub createRandomBytes {
	my ($length) = @_;
	my $str = '';
	for (1..$length) {
		$str .= chr(rand(256));
	}
	return $str;
}

sub sendGetPlayerInfo {
	my ($self, $ID) = @_;
	my $msg = pack("C*", 0x93, 0x01) . createRandomBytes(3) . $ID;
	$self->sendToServer($msg);
	debug "Sent get player info: ID - ".getHex($ID)."\n", "sendPacket", 2;
}

sub sendMapLogin {
	my ($self, $accountID, $charID, $sessionID, $sex) = @_;
	my $msg;

	$sex = 0 if ($sex > 1 || $sex < 0); # Sex can only be 0 (female) or 1 (male)
	$msg = pack("C*", 0xF3, 0x00) .
		createRandomBytes(3) .
		$charID .
		$accountID .
		chr(0) .
		$sessionID .
		pack("V", getTickCount()) .
		createRandomBytes(9) .
		chr($sex) .
		createRandomBytes(5);
	$self->sendToServer($msg);
}

sub sendMove {
	my ($self) = @_;
	my $x = int scalar shift;
	my $y = int scalar shift;
	my $msg =
		pack("C*", 0x85, 0x00, 0x00, 0x00, 0x00, 0x00) .
		getCoordString2($x, $y, 1);
	$self->sendToServer($msg);
	debug "Sent move to: $x, $y\n", "sendPacket", 2;
}

1;
