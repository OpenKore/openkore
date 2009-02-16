use strict;
use warnings;

package Test::Deep::ArrayElementsOnly;

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

	my $data = $self->data;

	for my $i (0..$#{$exp})
	{
		$data->{index} = $i;

		my $got_elem = $got->[$i];
		my $exp_elem = $exp->[$i];

		return 0 unless Test::Deep::descend($got_elem, $exp_elem)
	}

	return 1;
}

sub render_stack
{
	my $self = shift;
	my ($var, $data) = @_;
	$var .= "->" unless $Test::Deep::Stack->incArrow;
	$var .= "[$data->{index}]";

	return $var;
}

sub reset_arrow
{
	return 0;
}

1;
