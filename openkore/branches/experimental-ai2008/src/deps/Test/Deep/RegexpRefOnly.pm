use strict;
use warnings;

package Test::Deep::RegexpRefOnly;

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

	return $got eq $exp;
}

sub render_stack
{
	my $self = shift;
	my ($var, $data) = @_;

	return "m/$var/";
}

sub renderGot
{
	my $self = shift;

	return shift()."";
}

1;
