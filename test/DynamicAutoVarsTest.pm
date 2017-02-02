package DynamicAutoVarsTest;

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
	my $parsed = parseMacroFile( "$RealBin/DynamicAutoVarsTest.txt", 0 );
	
	ok ($parsed);
	
	$eventMacro = eventMacro::Core->new( "$RealBin/DynamicAutoVarsTest.txt" );
	
	ok (defined $eventMacro);
	
	$eventMacro->set_scalar_var('NestedScalar1', 2);
}

1;
