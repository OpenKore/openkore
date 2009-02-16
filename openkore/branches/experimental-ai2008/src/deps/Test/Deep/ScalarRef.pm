use strict;
use warnings;

package Test::Deep::ScalarRef;

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

	return 0 unless $self->test_class($got);
	return 0 unless $self->test_reftype($got, Scalar::Util::reftype($exp));
	return Test::Deep::descend($got, Test::Deep::scalarrefonly($exp));
}

1;
