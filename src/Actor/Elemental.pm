#########################################################################
#  OpenKore - Elemental actor object
#  Copyright (c) 2005 OpenKore Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#
#  $Revision: 3869 $
#  $Id: Player.pm 3869 2006-02-02 12:10:15Z hongli $
#
#########################################################################
##
# MODULE DESCRIPTION: Elemental actor object
#
# All members in %elementals are of the Actor::Elemental class.
#
# @MODULE(Actor) is the base class for this class.
package Actor::Elemental;

use strict;
use Actor;
use base qw(Actor);
use Translation qw(T);

sub new {
	my ($class) = @_;
	return $class->SUPER::new(T('Elemental'));
}

##
# float $elemental->hp_percent()
#
# Returns elemental HP percentage (between 0 and 100).
sub hp_percent {
	my ($self) = @_;

	return main::percent_hp($self);
}

##
# float $elemental->sp_percent()
#
# Returns elemental SP percentage (between 0 and 100).
sub sp_percent {
	my ($self) = @_;

	return main::percent_sp($self);
}

1;
