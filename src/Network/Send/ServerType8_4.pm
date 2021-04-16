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
# kRO 2008-3-26 (eA packet version 9)
# Servertype overview: https://openkore.com/wiki/ServerType
package Network::Send::ServerType8_4;

use strict;
use Network::Send::ServerType8;
use base qw(Network::Send::ServerType8);

sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}

1;