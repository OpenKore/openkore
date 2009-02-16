use strict;
use warnings;

package Test::Deep::Number;

use Test::Deep::Cmp;

use Scalar::Util;

sub init
{
	my $self = shift;

	$self->{val} = shift(@_) + 0;
	$self->{tolerance} = shift;
}

sub descend
{
	my $self = shift;
	my $got = shift;
	$self->data->{got_string} = $got;
	{
		no warnings 'numeric';
		$got += 0;
	}

	$self->data->{got} = $got;
	if (defined(my $tolerance = $self->{tolerance}))
	{
		return abs($got - $self->{val}) <= $tolerance;
	}
	else
	{
		return $got == $self->{val};
	}
}

sub diag_message
{
	my $self = shift;

	my $where = shift;

	return "Comparing $where as a number";
}

sub renderGot
{
	my $self = shift;
	my $val = shift;

	my $got_string = $self->data->{got_string};
	if ("$val" ne "$got_string")
	{
		$got_string = $self->SUPER::renderGot($got_string);
		return "$val ($got_string)"
	}
	else
	{
		return $val;
	}
}
sub renderExp
{
	my $self = shift;

	my $exp = $self->{val};

	if (defined(my $tolerance = $self->{tolerance}))
	{
		return "$exp +/- $tolerance";
	}
	else
	{
		return $exp;
	}
}

1;
