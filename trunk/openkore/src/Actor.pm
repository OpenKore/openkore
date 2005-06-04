#########################################################################
#  OpenKore - Base class for all actor objects
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
# MODULE DESCRIPTION: Base class for all actor objects
#
# The Actor class is a base class for all actor objects.
# An actor object is a monster or player (all members of %monsters and
# %players). Do not create an object of this class; use one of the
# subclasses instead.
#
# An actor object is also a hash.
#
# See also: Actor::Monster.pm and Actor::Player.pm

package Actor;
use strict;

### CATEGORY: Hash members

##
# $actor->{type}
#
# The actor's type. Can be either "Monster" or "Player".


### CATEGORY: Methods

##
# $actor->name()
#
# Returns the name string of an actor, e.g. "Player pmak (3)",
# "Monster Poring (0)" or "You".
sub name {
	my ($self) = @_;

	return "You" if $self->{type} eq 'You';
	return "$self->{type} $self->{name} ($self->{binID})";
}

1;
