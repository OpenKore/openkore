package Tie::ActorHash;
use strict;

use Tie::Hash;
use base 'Tie::ExtraHash';

sub STORE {
	my ($hashref, $key, $value) = ($_[0][0], @_[1, 2]);
	
	die "Attempt to STORE non Actor reference to the hash of actors\n"
	. "Key:\n"
	. (unpack 'H*', $key) . "\n"
	. "Value:\n"
	. Data::Dumper::Dumper($value) . "\n"
	unless $value && $value->isa('Actor');
	
	$hashref->{$key} = $value;
}

1;
