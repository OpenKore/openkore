#########################################################################
#  OpenKore - Slave actor object
#  Copyright (c) 2005 OpenKore Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#
#########################################################################
##
# MODULE DESCRIPTION: Homunculus Slave actor object
#
# @MODULE(Actor::Slave) is the base class for this class.
package Actor::Slave::Homunculus;

use strict;
use Actor::Slave;
use base qw(Actor::Slave);
use Translation qw(T);

sub new {
	my ($class) = @_;
	
	return $class->SUPER::new(T('Homunculus'));
}

1;