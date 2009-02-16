use strict;
use warnings;

package Test::Deep::Array;

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

	return 0 unless Test::Deep::descend($got, Test::Deep::arraylength(scalar @$exp));

	return 0 unless $self->test_class($got);

	return Test::Deep::descend($got, Test::Deep::arrayelementsonly($exp));
}

sub reset_arrow
{
	return 0;
}

1;
