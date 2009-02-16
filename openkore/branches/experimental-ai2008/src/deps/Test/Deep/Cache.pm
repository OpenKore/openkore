use strict;
use warnings;

package Test::Deep::Cache;

use Test::Deep::Cache::Simple;

sub new
{
	my $pkg = shift;

	my $self = bless {}, $pkg;

	$self->{expects} = [Test::Deep::Cache::Simple->new];
	$self->{normal} = [Test::Deep::Cache::Simple->new];

	$self->local;

	return $self;
}

sub add
{
	my $self = shift;

	my $type = $self->type;

	$self->{$type}->[-1]->add(@_);
}

sub cmp
{
	# go through all the caches to see if we know this one

	my $self = shift;

	my $type = $self->type;

	foreach my $cache (@{$self->{$type}})
	{
		return 1 if $cache->cmp(@_);
	}

	return 0
}

sub local
{
	my $self = shift;

	foreach my $type (qw( expects normal ))
	{
		push(@{$self->{$type}}, Test::Deep::Cache::Simple->new);
	}
}

sub finish
{
	my $self = shift;

	my $keep = shift;

	foreach my $type (qw( expects normal ))
	{
		my $caches = $self->{$type};

		my $last = pop @$caches;

		$caches->[-1]->absorb($last) if $keep;
	}
}

sub type
{
	return $Test::Deep::Expects ? "expects" : "normal";
}

1;
