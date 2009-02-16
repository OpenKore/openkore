use strict;
use warnings;

package Test::Deep::ArrayLength;

use Test::Deep::Ref;

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

	my $exp = $self->{val};

	return 0 unless $self->test_reftype($got, "ARRAY");

	return Test::Deep::descend($got, Test::Deep::arraylengthonly($exp));
}

1;
