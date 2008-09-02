#########################################################################
#  OpenKore - Party actor object
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
# MODULE DESCRIPTION: Party actor object
#
# Represents a party member.
# All members in $char->{party}{users} are of the Actor::Party class.
#
# Actor.pm is the base class for this class.
package Actor::Party;

use strict;
use Actor;

our @ISA = qw(Actor);

sub new {
	my ($class) = @_;
	return $class->SUPER::new('Party');
}

##
# Hash* $ActorParty->position()
#
# Returns the position of the actor.
sub position {
	my ($self) = @_;

	return $self->{pos};
}

1;
