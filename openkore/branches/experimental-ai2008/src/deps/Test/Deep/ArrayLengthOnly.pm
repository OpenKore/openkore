use strict;
use warnings;

package Test::Deep::ArrayLengthOnly;

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

	my $len = $self->{val};

	return @$got == $len;
}

sub render_stack
{
	my $self = shift;
	my ($var, $data) = @_;

	return "array length of $var";
}

sub renderVal
{
	my $self = shift;

	my $val = shift;

	return "array with $val element(s)"
}

sub renderGot
{
	my $self = shift;

	my $got = shift;

	return $self->renderVal(@$got + 0);
}

sub renderExp
{
	my $self = shift;

	return $self->renderVal($self->{val});
}

1;
