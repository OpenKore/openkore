use strict;
use warnings;

package Test::Deep::RefType;

use Test::Deep::Cmp;

use Scalar::Util qw( reftype );

sub init
{
	my $self = shift;

	$self->{val} = shift;
}

sub descend
{
	my $self = shift;

	my $got = shift;

	my $exp = $self->{val};
	my $reftype = reftype($got);

	return Test::Deep::descend($reftype, Test::Deep::shallow($exp));
}

sub render_stack
{
	my $self = shift;
	my $var = shift;

	return "reftype($var)";
}

sub renderGot
{
	my $self = shift;

	my $got = shift;

	$self->SUPER::renderGot(reftype($got));
}

1;
