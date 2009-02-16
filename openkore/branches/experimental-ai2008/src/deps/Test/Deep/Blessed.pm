use strict;
use warnings;

package Test::Deep::Blessed;

use Test::Deep::Cmp;

use Scalar::Util qw( blessed );

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
	my $blessed = blessed($got);

	return Test::Deep::descend($blessed, Test::Deep::shallow($exp));
}

sub render_stack
{
	my $self = shift;
	my $var = shift;

	return "blessed($var)"
}

sub renderGot
{
	my $self = shift;

	my $got = shift;

	$self->SUPER::renderGot(blessed($got));
}

1;
