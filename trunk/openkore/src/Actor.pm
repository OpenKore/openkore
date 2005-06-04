package Actor;
use strict;

##
# $actor->name()
#
# Returns the name string of an actor, e.g. "Player pmak (3)"
# or "Monster Poring (0)".
sub name {
	my ($self) = @_;

	return "$self->{type} $self->{name} ($self->{binID})";
}

1;
