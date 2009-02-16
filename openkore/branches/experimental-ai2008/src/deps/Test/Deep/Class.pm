use strict;
use warnings;

package Test::Deep::Class;

use Test::Deep::Cmp;

sub init
{
	my $self = shift;

	my $snobby = shift;
	my $val = shift;

	$self->{snobby} = $snobby;
	$self->{val} = $val;
}

sub descend
{
	my $self = shift;
	my $got = shift;

	local $Test::Deep::Snobby = $self->{snobby};

	Test::Deep::wrap($self->{val})->descend($got);
}

1;
