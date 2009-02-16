use strict;
use warnings;

package Test::Deep::HashElements;

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

	my $master = $self->getMaster($got, $exp);

	foreach my $key (keys %$master)
	{
		$data->{index} = $key;

		my $got_elem = exists $got->{$key} ? $got->{$key} : $Test::Deep::DNE;
		my $exp_elem = exists $exp->{$key} ? $exp->{$key} : $Test::Deep::DNE;

		next if Test::Deep::descend($got_elem, $exp_elem);

		return 0;
	}

	return 1;
}

sub getMaster
{
	my $self = shift;

	my ($got, $exp) = @_;

	return keys %$got > keys %$exp ? $got : $exp;
}

sub render_stack
{
	my $self = shift;
	my ($var, $data) = @_;
	$var .= "->" unless $Test::Deep::Stack->incArrow;
	$var .= '{"'.quotemeta($data->{index}).'"}';

	return $var;
}

sub reset_arrow
{
	return 0;
}

package Test::Deep::SuperHashElements;

use base 'Test::Deep::HashElements';

sub getMaster
{
	my $self = shift;

	my ($got, $exp) = @_;

	return $exp;
}

package Test::Deep::SubHashElements;

use base 'Test::Deep::HashElements';

sub getMaster
{
	my $self = shift;

	my ($got, $exp) = @_;

	return $got;
}

1;
