use strict;
use warnings;

package Test::Deep::HashKeys;

use Test::Deep::Ref;

sub init
{
	my $self = shift;

	my %keys;
	@keys{@_} = ();
	$self->{val} = \%keys;
	$self->{keys} = [sort @_];
}

sub descend
{
	my $self = shift;
	my $got = shift;

	my $exp = $self->{val};

	return 0 unless $self->test_reftype($got, "HASH");

	return Test::Deep::descend($got, $self->hashkeysonly($exp));
}

sub hashkeysonly
{
	require Test::Deep::HashKeysOnly;

	my $self = shift;
	my $exp = shift;

	return Test::Deep::HashKeysOnly->new(keys %$exp)
}

package Test::Deep::SuperHashKeys;

use base 'Test::Deep::HashKeys';

sub hashkeysonly
{
	require Test::Deep::HashKeysOnly;

	my $self = shift;
	my $exp = shift;

	return Test::Deep::SuperHashKeysOnly->new(keys %$exp)
}

package Test::Deep::SubHashKeys;

use base 'Test::Deep::HashKeys';

sub hashkeysonly
{
	require Test::Deep::HashKeysOnly;

	my $self = shift;
	my $exp = shift;

	return Test::Deep::SubHashKeysOnly->new(keys %$exp)
}

1;
