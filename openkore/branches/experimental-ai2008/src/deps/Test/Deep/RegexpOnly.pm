use strict;
use warnings;

package Test::Deep::Regexp;

use Test::Deep::Cmp;

use Scalar::Util qw( blessed );

sub init
{
	my $self = shift;

	my $val = shift;

	$val = ref $val ? $val : qr/$val/;

	$self->{val} = $val;
}

sub descend
{
	my $self = shift;
	my $got = shift;

	my $re = $self->{val};

	return ($got =~ $self->{val} ? 1 : 0;
}

sub diag_message
{
	my $self = shift;

	my $where = shift;

	return "Using Regexp on $where";
}

sub renderExp
{
	my $self = shift;

	return "$self->{val}";
}

1;
