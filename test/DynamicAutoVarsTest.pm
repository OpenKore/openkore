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
	use Data::Dumper;
	
	Log::warning "[dynamictest] start\n";
	
	Log::warning "[test] Dumper dynamic complements '".Dumper($eventMacro->{Dynamic_Variable_Complements})."'\n";
	Log::warning "[test] Dumper dynamic sub call '".Dumper($eventMacro->{Dynamic_Variable_Sub_Callbacks})."'\n";
	Log::warning "[test] Dumper dynamic true call '".Dumper($eventMacro->{Event_Related_Dynamic_Variables})."'\n";
	
	Log::warning "[dynamictest] var NestedScalar1 change to 2\n";
	$eventMacro->set_scalar_var('NestedScalar1', 2);
	
	Log::warning "[test] Dumper dynamic complements '".Dumper($eventMacro->{Dynamic_Variable_Complements})."'\n";
	Log::warning "[test] Dumper dynamic sub call '".Dumper($eventMacro->{Dynamic_Variable_Sub_Callbacks})."'\n";
	Log::warning "[test] Dumper dynamic true call '".Dumper($eventMacro->{Event_Related_Dynamic_Variables})."'\n";
	
	Log::warning "[dynamictest] var NestedScalar1 change to 27\n";
	$eventMacro->set_scalar_var('NestedScalar1', 27);
	
	Log::warning "[test] Dumper dynamic complements '".Dumper($eventMacro->{Dynamic_Variable_Complements})."'\n";
	Log::warning "[test] Dumper dynamic sub call '".Dumper($eventMacro->{Dynamic_Variable_Sub_Callbacks})."'\n";
	Log::warning "[test] Dumper dynamic true call '".Dumper($eventMacro->{Event_Related_Dynamic_Variables})."'\n";
	
	Log::warning "[dynamictest] var NestedScalar1 change to undef\n";
	$eventMacro->set_scalar_var('NestedScalar1', 'undef');
	
	Log::warning "[test] Dumper dynamic complements '".Dumper($eventMacro->{Dynamic_Variable_Complements})."'\n";
	Log::warning "[test] Dumper dynamic sub call '".Dumper($eventMacro->{Dynamic_Variable_Sub_Callbacks})."'\n";
	Log::warning "[test] Dumper dynamic true call '".Dumper($eventMacro->{Event_Related_Dynamic_Variables})."'\n";
	
	Log::warning "[dynamictest] var NestArray3[5] change to 7\n";
	$eventMacro->set_array_var('NestArray3', 5, 7);
	
	Log::warning "[test] Dumper dynamic complements '".Dumper($eventMacro->{Dynamic_Variable_Complements})."'\n";
	Log::warning "[test] Dumper dynamic sub call '".Dumper($eventMacro->{Dynamic_Variable_Sub_Callbacks})."'\n";
	Log::warning "[test] Dumper dynamic true call '".Dumper($eventMacro->{Event_Related_Dynamic_Variables})."'\n";
	
	Log::warning "[dynamictest] var NestArray4[7] change to 2\n";
	$eventMacro->set_array_var('NestArray4', 7, 2);
	
	Log::warning "[test] Dumper dynamic complements '".Dumper($eventMacro->{Dynamic_Variable_Complements})."'\n";
	Log::warning "[test] Dumper dynamic sub call '".Dumper($eventMacro->{Dynamic_Variable_Sub_Callbacks})."'\n";
	Log::warning "[test] Dumper dynamic true call '".Dumper($eventMacro->{Event_Related_Dynamic_Variables})."'\n";
	
	Log::warning "[dynamictest] var NestArray3[2] change to 3\n";
	$eventMacro->set_array_var('NestArray3', 2, 3);
	
	Log::warning "[test] Dumper dynamic complements '".Dumper($eventMacro->{Dynamic_Variable_Complements})."'\n";
	Log::warning "[test] Dumper dynamic sub call '".Dumper($eventMacro->{Dynamic_Variable_Sub_Callbacks})."'\n";
	Log::warning "[test] Dumper dynamic true call '".Dumper($eventMacro->{Event_Related_Dynamic_Variables})."'\n";
	
	Log::warning "[dynamictest] var NestedScalar1 change to 5\n";
	$eventMacro->set_scalar_var('NestedScalar1', 5);
	
	Log::warning "[test] Dumper dynamic complements '".Dumper($eventMacro->{Dynamic_Variable_Complements})."'\n";
	Log::warning "[test] Dumper dynamic sub call '".Dumper($eventMacro->{Dynamic_Variable_Sub_Callbacks})."'\n";
	Log::warning "[test] Dumper dynamic true call '".Dumper($eventMacro->{Event_Related_Dynamic_Variables})."'\n";
	
	Log::warning "[dynamictest] var NestedScalar1 change to 2\n";
	$eventMacro->set_scalar_var('NestedScalar1', 2);
	
	Log::warning "[test] Dumper dynamic complements '".Dumper($eventMacro->{Dynamic_Variable_Complements})."'\n";
	Log::warning "[test] Dumper dynamic sub call '".Dumper($eventMacro->{Dynamic_Variable_Sub_Callbacks})."'\n";
	Log::warning "[test] Dumper dynamic true call '".Dumper($eventMacro->{Event_Related_Dynamic_Variables})."'\n";
	
	Log::warning "[dynamictest] var NestArray4[3] change to 78\n";
	$eventMacro->set_array_var('NestArray4', 3, 78);
	
	Log::warning "[test] Dumper dynamic complements '".Dumper($eventMacro->{Dynamic_Variable_Complements})."'\n";
	Log::warning "[test] Dumper dynamic sub call '".Dumper($eventMacro->{Dynamic_Variable_Sub_Callbacks})."'\n";
	Log::warning "[test] Dumper dynamic true call '".Dumper($eventMacro->{Event_Related_Dynamic_Variables})."'\n";
}

1;
