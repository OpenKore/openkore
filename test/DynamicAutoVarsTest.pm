package DynamicAutoVarsTest;

use strict;
use warnings;
use FindBin qw($RealBin);
use lib "$RealBin";

use Test::More;
use eventMacro::Core;
use eventMacro::Data;
use eventMacro::FileParser;
use Data::Dumper;

sub start {
	my $parsed = parseMacroFile( "$RealBin/textfiles/DynamicAutoVarsTest.txt", 0 );
	
	ok ($parsed);
	
	$eventMacro = eventMacro::Core->new( "$RealBin/textfiles/DynamicAutoVarsTest.txt" );
	
	ok (defined $eventMacro);
	
	Log::warning "[dynamic] start\n";
	Log::warning "[test] Dynamic_Variable_Complements ".Dumper($eventMacro->{Dynamic_Variable_Complements})."\n";
	Log::warning "[test] Dynamic_Variable_Sub_Callbacks ".Dumper($eventMacro->{Dynamic_Variable_Sub_Callbacks})."\n";
	Log::warning "[test] Event_Related_Dynamic_Variables ".Dumper($eventMacro->{Event_Related_Dynamic_Variables})."\n";
	
	Log::warning "[dynamic] change NestedScalar1 to '10'\n";
	$eventMacro->set_scalar_var('NestedScalar1', 10);
	
	Log::warning "[test] Dynamic_Variable_Complements ".Dumper($eventMacro->{Dynamic_Variable_Complements})."\n";
	Log::warning "[test] Dynamic_Variable_Sub_Callbacks ".Dumper($eventMacro->{Dynamic_Variable_Sub_Callbacks})."\n";
	Log::warning "[test] Event_Related_Dynamic_Variables ".Dumper($eventMacro->{Event_Related_Dynamic_Variables})."\n";
}

1;