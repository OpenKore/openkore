#########################################################################
#  OpenKore - Monster actor object
#  Copyright (c) 2005 OpenKore Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#
#  $Revision$
#  $Id$
#
#########################################################################
##
# MODULE DESCRIPTION: Monsters actor object
#
# All members in %monsters are of the Actor::Monster class.
#
# Actor.pm is the base class for this class.
package Actor::Monster;

use strict;

use base qw(Actor);

sub new {
	my ($class) = @_;
	return $class->SUPER::new('Monster');
}

1;
