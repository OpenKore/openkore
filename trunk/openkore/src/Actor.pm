package Actor;
use strict;

sub name {
	my ($self) = @_;

	return "$self->{type} $self->{name} ($self->{binID})";
}

1;
