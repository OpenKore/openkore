use strict;
use warnings;

package Test::Deep::RegexpMatches;

use Test::Deep::Array;

use base 'Test::Deep::Array';

use Scalar::Util qw( blessed );

sub init
{
	my $self = shift;

	my $val = shift;

	$val = Test::Deep::array($val) unless
		blessed($val) and UNIVERSAL::isa($val, "Test::Deep::Cmp");

	$self->{val} = $val;
	$self->{regex} = shift;
}

sub descend
{
	my $self = shift;

	my $got = shift;

	return Test::Deep::descend($got, $self->{val});
}

sub render_stack
{
	my $self = shift;

	my $stack = shift;

	$stack = "[$stack =~ $self->{regex}]";

	return $stack;
#	return $self->SUPER::render_stack($stack);
}

sub reset_arrow
{
	return 1;
}

1;
