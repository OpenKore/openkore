use strict;
use warnings;

package Test::Deep::ScalarRefOnly;

use Test::Deep::Cmp;

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

	return Test::Deep::descend($$got, $$exp);
}

sub render_stack
{
	my $self = shift;
	my ($var, $data) = @_;

	return "\${$var}";
}

1;
