use strict;
use warnings;

package Test::Deep::Ignore;

use Test::Deep::Cmp;

my $Singleton = __PACKAGE__->SUPER::new;

sub new
{
	return $Singleton;
}

sub descend
{
	return 1;
}

1;
