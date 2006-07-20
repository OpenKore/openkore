package WhirlpoolTest;

use strict;
use Test::More;
use Utils::Whirlpool qw(whirlpool whirlpool_hex);

sub start {
	print "### Starting WhirlpoolTest\n";
	WhirlpoolTest->new()->run();
}

###################################

sub new {
	my ($class) = @_;
	return bless {}, $class;
}

# Run the test.
sub run {
	my ($self) = @_;
	
	testHash("", "19FA61D75522A4669B44E39C1D2E1726C530232130D407F89AFEE0964997F7A7" .
			"3E83BE698B288FEBCF88E3E03C4F0757EA8964E59B63D93708B138CC42A66EB3");
	testHash("The quick brown fox jumps over the lazy dog",
			"B97DE512E91E3828B40D2B0FDCE9CEB3C4A71F9BEA8D88E75C4FA854DF36725F" .
			"D2B52EB6544EDCACD6F8BEDDFEA403CB55AE31F03AD62A5EF54E42EE82C3FB35");
	testHash("The quick brown fox jumps over the lazy eog",
			"C27BA124205F72E6847F3E19834F925CC666D0974167AF915BB462420ED40CC5" .
			"0900D85A1F923219D832357750492D5C143011A76988344C2635E69D06F2D38C");
}

sub testHash {
	my ($data, $expectedHash) = @_;
	my $wp = new Utils::Whirlpool();
	$wp->add($data);
	my $hash = uc unpack("H*", $wp->finalize());
	is($hash, $expectedHash, "\"$data\"");

	$wp->init();
	$wp->add($data);
	$hash = uc unpack("H*", $wp->finalize());
	is($hash, $expectedHash, "\"$data\"");

	$hash = uc whirlpool_hex($data);
	is($hash, $expectedHash, "\"$data\"");
}

1;
