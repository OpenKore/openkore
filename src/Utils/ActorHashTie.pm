package Tie::ActorHash;
use strict;

# from Tie::ExtraHash
sub TIEHASH  { my $p = shift; bless [{}, @_], $p }
#sub STORE    { $_[0][0]{$_[1]} = $_[2] }
sub FETCH    { $_[0][0]{$_[1]} }
sub FIRSTKEY { my $a = scalar keys %{$_[0][0]}; each %{$_[0][0]} }
sub NEXTKEY  { each %{$_[0][0]} }
sub EXISTS   { exists $_[0][0]->{$_[1]} }
sub DELETE   { delete $_[0][0]->{$_[1]} }
sub CLEAR    { %{$_[0][0]} = () }
sub SCALAR   { scalar %{$_[0][0]} }

sub STORE {
	my ($hashref, $key, $value) = ($_[0][0], @_[1, 2]);
	
	die "Attempt to STORE non Actor reference to the hash of actors\n"
	. "Key:\n"
	. (unpack 'H*', $key) . "\n"
	. "Value:\n"
	. Data::Dumper::Dumper($value) . "\n"
	unless $value && UNIVERSAL::isa($value, 'Actor');
	
	$hashref->{$key} = $value;
}

1;
