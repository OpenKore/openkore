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
# %players).
#
# See also: Monster.pm and Player.pm

package Actor;
use strict;

##
# $actor->name()
#
# Returns the name string of an actor, e.g. "Player pmak (3)"
# or "Monster Poring (0)".
sub name {
	my ($self) = @_;

	return "You" if $self->{type} eq 'You';
	return "$self->{type} $self->{name} ($self->{binID})";
}

1;
