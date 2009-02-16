use strict;
use warnings;

package Test::Deep::String;

use Test::Deep::Cmp;

sub init
{
	my $self = shift;

	$self->{val} = shift;
}

sub descend
{
	my $self = shift;
	my $got = shift()."";

	$self->data->{got} = $got;

	return $got eq $self->{val};
}

sub diag_message
{
	my $self = shift;

	my $where = shift;

	return "Comparing $where as a string";
}

1;
