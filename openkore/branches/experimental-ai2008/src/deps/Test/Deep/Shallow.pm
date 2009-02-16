use strict;
use warnings;

package Test::Deep::Shallow;

use Test::Deep::Cmp;

use Scalar::Util qw( refaddr );

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

	my $ok;

	if (!defined $got and !defined $exp)
	{
		$ok = 1;
	}
	elsif (defined $got xor defined $exp)
	{
		$ok = 0;
	}
	elsif (ref $got and ref $exp)
	{
		$ok = refaddr($got) == refaddr($exp);
	}
	elsif (ref $got xor ref $exp)
	{
		$ok = 0;
	}
	else
	{
		$ok = $got eq $exp;
	}

	return $ok;
}

1;
