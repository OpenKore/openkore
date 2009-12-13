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
#
#  $Revision: 5555 $
#  $Id: ServerType8.pm 5555 2007-03-21 16:23:01Z vcl_kore $
#  Modified by skseo, Jan-24-2007, Fixed bugs.
########################################################################
# Some eAthena servers after Feb 26th 2008
# kRO 2008-3-26 (eA packet version 9)
# Servertype overview: http://www.openkore.com/wiki/index.php/ServerType
package Network::Send::ServerType8_2;

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

1;
