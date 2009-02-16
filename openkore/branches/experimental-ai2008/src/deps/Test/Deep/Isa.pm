use strict;
use warnings;

package Test::Deep::Isa;

use Test::Deep::Cmp;

sub init
{
	my $self = shift;

	my $val = shift;
	$self->{val} = $val;
}

sub descend
{
	my $self = shift;
	my $got = shift;

	return UNIVERSAL::isa($got, $self->{val});
}

sub diag_message
{
	my $self = shift;

	my $where = shift;

	return "Checking class of $where with isa()";
}

1;
