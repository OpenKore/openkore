use strict;
use warnings;

package Test::Deep::Ref;

use Test::Deep::Cmp;

use Scalar::Util qw( blessed );

sub test_class
{
	my $self = shift;
	my $got = shift;

	my $exp = $self->{val};
	
	if ($Test::Deep::Snobby)
	{
		return Test::Deep::descend($got, Test::Deep::blessed(blessed($exp)));
	}
	else
	{
		return 1;
	}
}

sub test_reftype
{
	my $self = shift;
	my $got = shift;
	my $reftype = shift;

	return Test::Deep::descend($got, Test::Deep::reftype($reftype));
}

1;
