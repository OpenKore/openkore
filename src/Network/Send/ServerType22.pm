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
# tRO (Thai) for 2008-09-16Ragexe12_Th
# Servertype overview: https://openkore.com/wiki/ServerType
package Network::Send::ServerType22;

use strict;
use base qw(Network::Send::ServerType21);

sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}

1;