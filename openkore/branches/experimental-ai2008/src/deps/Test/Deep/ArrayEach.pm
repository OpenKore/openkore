use strict;
use warnings;

package Test::Deep::ArrayEach;

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

	my $exp = [ ($self->{val}) x @$got ];

	return Test::Deep::descend($got, $exp);
}

1;
