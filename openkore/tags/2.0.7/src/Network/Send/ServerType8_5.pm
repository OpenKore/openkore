#########################################################################
# OpenKore - Packet sending
# This module contains functions for sending packets to the server.
#
# This software is open source, licensed under the GNU General Public
# License, version 2.
# Basically, this means that you're allowed to modify and distribute
# this software. However, if you distribute modified versions, you MUST
# also distribute the source code.
# See http://www.gnu.org/licenses/gpl.html for the full license.
#
# $Revision: 5761 $
# $Id: ServerType8.pm 5761 2007-06-26 12:25:48Z bibian $
# Modified by skseo, Jan-24-2007, Fixed bugs.
########################################################################
#  kRO Client 2009-02-25b (eA packet version 23)
# Servertype overview: http://www.openkore.com/wiki/index.php/ServerType
package Network::Send::ServerType8_5;

use strict;
use Globals qw($accountID $sessionID $sessionID2 $accountSex $char $charID %config %guild @chars $masterServer $syncSync $net);
use Network::Send::ServerType8;
use base qw(Network::Send::ServerType8);
use Log qw(message warning error debug);
use I18N qw(stringToBytes);
use Utils qw(getTickCount getHex getCoordString);

sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}

sub sendMapLogin {
	my ($self, $accountID, $charID, $sessionID, $sex) = @_;
	my $msg;
	$sex = 0 if ($sex > 1 || $sex < 0); # Sex can only be 0 (female) or 1 (male)
	$msg = pack("C*", 0x36, 0x04) .
		$accountID .
		$charID .
		$sessionID .
		pack("V", getTickCount()) .
		pack("C", $sex);
	$self->sendToServer($msg);
}

1;