package RijndaelTest;

use strict;
use Test::More;
use Utils::Rijndael qw(give_hex);

sub start {
	print "### Starting RijndaelTest\n";
	RijndaelTest->new()->run();
}

###################################

sub new {
	my ($class) = @_;
	return bless {}, $class;
}

# Run the test.
sub run {
	my ($self) = @_;
	testHash("katon92", "0779633C7C7080C6B4F443E9130B06C8C66BC0BAB9700DAF");
}

sub testHash {
	my ($data, $expectedHash) = @_;
	
	my $in = pack('a24', $data);
	
	# hardcoded
	my $key = pack('C24', (6, 169, 33, 64, 54, 184, 161, 91, 81, 46, 3, 213, 52, 18, 0, 6, 61, 175, 186, 66, 157, 158, 180, 48));
	my $chain = pack('C24', (61, 175, 186, 66, 157, 158, 180, 48, 180, 34, 218, 128, 44, 159, 172, 65, 1, 2, 4, 8, 16, 32, 128));
	
	my $rijndael = Utils::Rijndael->new();
	$rijndael->MakeKey($key, $chain, 24, 24);
	my $hash = $rijndael->Encrypt($in, undef, 24, 0);
	is(give_hex($hash), $expectedHash, "\"$data\"");
}

1;
