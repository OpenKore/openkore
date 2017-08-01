package LoadConditionsTest;

use strict;
use warnings;
use FindBin qw($RealBin);
use lib "$RealBin";

use Test::More;
use eventMacro::Core;
use eventMacro::Data;
use eventMacro::Runner;
use eventMacro::FileParser;
use eventMacro::Utilities qw(find_variable);

sub start {
	my $parsed = parseMacroFile( "$RealBin/textfiles/LoadConditionsTest.txt", 0 );
	
	ok ($parsed);
	
	$eventMacro = eventMacro::Core->new( "$RealBin/textfiles/LoadConditionsTest.txt" );
	
	ok (defined $eventMacro);
}

1;
