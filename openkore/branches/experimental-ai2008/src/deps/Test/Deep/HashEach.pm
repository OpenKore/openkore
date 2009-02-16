use strict;
use warnings;

package Test::Deep::HashEach;

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

	my %exp;

	@exp{keys %$got} = ($self->{val}) x (keys %$got);

	return Test::Deep::descend($got, \%exp);
}

1;
