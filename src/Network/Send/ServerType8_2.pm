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
# Servertype overview: http://wiki.openkore.com/index.php/ServerType
package Network::Send::ServerType8_2;

use strict;
use Network::Send::ServerType8;
use base qw(Network::Send::ServerType8);

sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}

1;
