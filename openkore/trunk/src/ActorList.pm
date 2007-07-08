#########################################################################
#  OpenKore - Actor list
#
#  Copyright (c) 2006 OpenKore Development Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
##
# MODULE DESCRIPTION: List of actors
#
# <b>Derived from: @CLASS(ObjectList)</b>
#
# The ActorList class holds a list of Actor-objects.
# OpenKore stores lists of players/monsters/portals/NPCs/etc. in lists
# of this type. Those lists are $playersList, $monstersList, $npcsList,
# $petsList and $portalsList, defined in Globals.pm.
#
# <h3>Differences compared to ObjectList</h3>
# All items in ActorList are of the same class, and are all a
# subclass of @CLASS(Actor).
package ActorList;

use strict;
use Carp::Assert;
use Utils::ObjectList;
use base qw(ObjectList);

### CATEGORY: Class ActorList

##
# ActorList ActorList->new(String type)
# type: The name of the class that all items in this ActorList must be.
# Requires: defined($type) && UNIVERSAL::isa($type, "Actor")
# Ensures:  $self->size() == 0
#
# Creates a new ActorList object.
sub new {
	my ($class, $type) = @_;
	assert(defined $type) if DEBUG;
	assert(UNIVERSAL::isa($type, "Actor")) if DEBUG;

	my $self = $class->SUPER::new();

	# Invariant: defined(type)
	$self->{type} = $type;

	# Hash<Bytes, Actor> IDmap
	# Maps an actor ID ($Actor->{ID}) to an actor. Used
	# for fast lookups of actors based on IDs.
	#
	# Invariant:
	#     defined(IDmap)
	#     scalar(keys IDmap) == size()
	#     for all values $v in IDmap:
	#         find($v) != -1
	$self->{IDmap} = {};

	return $self;
}

##
# int $ActorList->add(Actor actor)
# Requires:
#     defined($actor)
#     defined($actor->{ID})
#     $self->find($actor) == -1
#
# Adds an actor to this ActorList.
#
# This method overloads $ObjectList->add(), and has a stronger precondition.
# See the documentation for that method for more information about this
# method.
sub add {
	my ($self, $actor) = @_;
	assert(defined $actor) if DEBUG;
	assert($actor->isa($self->{type})) if DEBUG;
	assert(defined $actor->{ID}) if DEBUG;
	assert(!exists $self->{IDmap}{$actor->{ID}}) if DEBUG;

	$self->{IDmap}{$actor->{ID}} = $actor;
	return $self->SUPER::add($actor);
}

##
# Actor $ActorList->getByID(Bytes ID)
# Returns: An Actor, or undef if there is no actor with that ID in this list.
# Requires: defined($ID)
# Ensures: if defined(result): result->{ID} eq $ID
#
# Looks up an Actor object based on the actor ID.
#
# See also: $Actor->{ID}
sub getByID {
	my ($self, $ID) = @_;
	assert(defined $ID) if DEBUG;
	return $self->{IDmap}{$ID};
}

##
# boolean $ActorList->remove(Actor actor)
# Requires: defined($actor) && defined($actor->{ID})
#
# Removes an actor from this ActorList.
#
# This method overloads $ObjectList->remove(), and has a stronger precondition.
# See the documentation for that method for more information about this
# method.
sub remove {
	my ($self, $actor) = @_;
	assert(defined $actor) if DEBUG;
	assert(UNIVERSAL::isa($actor, $self->{type})) if DEBUG;
	assert(defined $actor->{ID}) if DEBUG;

	my $result = $self->SUPER::remove($actor);
	if ($result) {
		delete $self->{IDmap}{$actor->{ID}};
	}
	return $result;
}

##
# boolean $ActorList->removeByID(Bytes ID)
# ID: The ID of the actor to remove.
# Returns: Whether the actor with the specified ID was in the list.
# Requires: defined($ID)
#
# Removes an actor based on the actor ID. This will trigger an onRemove event
# before the actor is removed.
#
# See also: $Actor->{ID}
sub removeByID {
	my ($self, $ID) = @_;
	my $actor = $self->getByID($ID);
	if (defined $actor) {
		return $self->remove($actor);
	} else {
		return 0;
	}
}

# overloaded
sub doClear {
	my ($self) = @_;
	$self->SUPER::doClear();
	$self->{IDmap} = {};
}

# overloaded
sub checkValidity {
	my ($self) = @_;
	$self->SUPER::checkValidity();

	assert(defined $self->{type});
	assert(defined $self->{IDmap});
	should(scalar(keys %{$self->{IDmap}}), $self->size());
	foreach my $v (values %{$self->{IDmap}}) {
		assert($self->find($v) != -1);
	}
}

1;
