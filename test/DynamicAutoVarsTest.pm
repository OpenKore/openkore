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
	
	#All vars exist
	ok (exists $eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1});
	ok (exists $eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray1});
	ok (exists $eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray1}{'$NestedScalar1'});
	
	#NestedScalar1 is not the last var, so it has calls
	ok (exists $eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{call_to});
	is ($eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{last_nested}, 0);
	
	#NestArray1 is the last var, so it doesn't have calls, but has auto indexes
	ok (!exists $eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray1}{'$NestedScalar1'}{call_to});
	is ($eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray1}{'$NestedScalar1'}{last_nested}, 1);
	ok (exists $eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray1}{'$NestedScalar1'}{auto_indexes});
	
	#NestedScalar1 correctly calls to NestArray1
	is ($eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{call_to}[0]{name}, 'NestArray1');
	
	#Neither of them is defined
	is ($eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{defined}, 0);
	ok (!exists $eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{call_to}[0]{sub_callback_index});
	is ($eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray1}{'$NestedScalar1'}{defined}, 0);
	ok (!exists $eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray1}{'$NestedScalar1'}{complement_defined});
	
	#Only NestedScalar1 has a sub callback
	ok (exists $eventMacro->{Dynamic_Variable_Sub_Callbacks}{scalar}{NestedScalar1});
	ok (!exists $eventMacro->{Dynamic_Variable_Sub_Callbacks}{accessed_array}{NestArray1});
	
	#Neither of them has events
	ok (!exists $eventMacro->{Event_Related_Dynamic_Variables}{scalar}{NestedScalar1});
	ok (!exists $eventMacro->{Event_Related_Dynamic_Variables}{accessed_array}{NestArray1});

	#Defining NestedScalar1
	$eventMacro->set_scalar_var('NestedScalar1', 3);
	
	#NestedScalar1 is defined
	is ($eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{defined}, 1);
	is ($eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{value}, 3);
	ok (exists $eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{call_to}[0]{sub_callback_index});
	is ($eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{call_to}[0]{sub_callback_index}, 1);
	
	#NestArray1 is not defined, but it's complement is
	is ($eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray1}{'$NestedScalar1'}{defined}, 0);
	ok (exists $eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray1}{'$NestedScalar1'}{complement_defined});
	
	#Both of them have sub calls now
	ok (exists $eventMacro->{Dynamic_Variable_Sub_Callbacks}{scalar}{NestedScalar1});
	ok (exists $eventMacro->{Dynamic_Variable_Sub_Callbacks}{accessed_array}{NestArray1});
	
	#NestArray1 sub call has the correct complement
	ok (exists $eventMacro->{Dynamic_Variable_Sub_Callbacks}{accessed_array}{NestArray1}{3});
	is (scalar keys %{$eventMacro->{Dynamic_Variable_Sub_Callbacks}{accessed_array}{NestArray1}}, 1);
	
	#NestArray1 sub call and NestedScalar1 sub call index point to each other
	ok (exists $eventMacro->{Dynamic_Variable_Sub_Callbacks}{accessed_array}{NestArray1}{3}{$eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{call_to}[0]{sub_callback_index}});
	is ($eventMacro->{Dynamic_Variable_Sub_Callbacks}{accessed_array}{NestArray1}{3}{$eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{call_to}[0]{sub_callback_index}}, '$NestedScalar1');
	
	#Neither of them has events
	ok (!exists $eventMacro->{Event_Related_Dynamic_Variables}{scalar}{NestedScalar1});
	ok (!exists $eventMacro->{Event_Related_Dynamic_Variables}{accessed_array}{NestArray1});
	
	#Undefining NestedScalar1
	$eventMacro->set_scalar_var('NestedScalar1', 'undef');
	
	#Neither of them is defined
	is ($eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{defined}, 0);
	ok (!exists $eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{call_to}[0]{sub_callback_index});
	is ($eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray1}{'$NestedScalar1'}{defined}, 0);
	ok (!exists $eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray1}{'$NestedScalar1'}{complement_defined});
	
	#Only NestedScalar1 has a sub callback
	ok (exists $eventMacro->{Dynamic_Variable_Sub_Callbacks}{scalar}{NestedScalar1});
	ok (!exists $eventMacro->{Dynamic_Variable_Sub_Callbacks}{accessed_array}{NestArray1});
	
	#Neither of them has events
	ok (!exists $eventMacro->{Event_Related_Dynamic_Variables}{scalar}{NestedScalar1});
	ok (!exists $eventMacro->{Event_Related_Dynamic_Variables}{accessed_array}{NestArray1});
	
	#Re-Defining NestedScalar1
	$eventMacro->set_scalar_var('NestedScalar1', 7);
	
	#NestedScalar1 is defined
	is ($eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{defined}, 1);
	is ($eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{value}, 7);
	ok (exists $eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{call_to}[0]{sub_callback_index});
	is ($eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{call_to}[0]{sub_callback_index}, 1);
	
	#NestArray1 is not defined, but it's complement is
	is ($eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray1}{'$NestedScalar1'}{defined}, 0);
	ok (exists $eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray1}{'$NestedScalar1'}{complement_defined});
	
	#Both of them have sub calls now
	ok (exists $eventMacro->{Dynamic_Variable_Sub_Callbacks}{scalar}{NestedScalar1});
	ok (exists $eventMacro->{Dynamic_Variable_Sub_Callbacks}{accessed_array}{NestArray1});
	
	#NestArray1 sub call has the correct complement
	ok (exists $eventMacro->{Dynamic_Variable_Sub_Callbacks}{accessed_array}{NestArray1}{7});
	is (scalar keys %{$eventMacro->{Dynamic_Variable_Sub_Callbacks}{accessed_array}{NestArray1}}, 1);
	
	#NestArray1 sub call and NestedScalar1 sub call index point to each other
	ok (exists $eventMacro->{Dynamic_Variable_Sub_Callbacks}{accessed_array}{NestArray1}{7}{$eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{call_to}[0]{sub_callback_index}});
	is ($eventMacro->{Dynamic_Variable_Sub_Callbacks}{accessed_array}{NestArray1}{7}{$eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{call_to}[0]{sub_callback_index}}, '$NestedScalar1');
	
	#Neither of them has events
	ok (!exists $eventMacro->{Event_Related_Dynamic_Variables}{scalar}{NestedScalar1});
	ok (!exists $eventMacro->{Event_Related_Dynamic_Variables}{accessed_array}{NestArray1});
	
	#Defining NestArray1[7]
	$eventMacro->set_array_var('NestArray1', 7, 93);
	
	#NestedScalar1 is defined
	is ($eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{defined}, 1);
	is ($eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{value}, 7);
	ok (exists $eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{call_to}[0]{sub_callback_index});
	is ($eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{call_to}[0]{sub_callback_index}, 1);
	
	#NestArray1 is defined
	is ($eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray1}{'$NestedScalar1'}{defined}, 1);
	is ($eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray1}{'$NestedScalar1'}{value}, 93);
	ok (exists $eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray1}{'$NestedScalar1'}{complement_defined});
	
	#Both of them have sub calls now
	ok (exists $eventMacro->{Dynamic_Variable_Sub_Callbacks}{scalar}{NestedScalar1});
	ok (exists $eventMacro->{Dynamic_Variable_Sub_Callbacks}{accessed_array}{NestArray1});
	
	#NestArray1 sub call has the correct complement
	ok (exists $eventMacro->{Dynamic_Variable_Sub_Callbacks}{accessed_array}{NestArray1}{7});
	is (scalar keys %{$eventMacro->{Dynamic_Variable_Sub_Callbacks}{accessed_array}{NestArray1}}, 1);
	
	#NestArray1 sub call and NestedScalar1 sub call index point to each other
	ok (exists $eventMacro->{Dynamic_Variable_Sub_Callbacks}{accessed_array}{NestArray1}{7}{$eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{call_to}[0]{sub_callback_index}});
	is ($eventMacro->{Dynamic_Variable_Sub_Callbacks}{accessed_array}{NestArray1}{7}{$eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{call_to}[0]{sub_callback_index}}, '$NestedScalar1');
	
	#NestArray1 has event
	ok (!exists $eventMacro->{Event_Related_Dynamic_Variables}{scalar}{NestedScalar1});
	ok (exists $eventMacro->{Event_Related_Dynamic_Variables}{accessed_array}{NestArray1});
	
	#NestArray1 event has the correct complement
	ok (exists $eventMacro->{Event_Related_Dynamic_Variables}{accessed_array}{NestArray1}{7});
	is (scalar keys %{$eventMacro->{Event_Related_Dynamic_Variables}{accessed_array}{NestArray1}}, 1);
	
	#NestArray1 event points to NestedScalar1
	ok (exists $eventMacro->{Event_Related_Dynamic_Variables}{accessed_array}{NestArray1}{7}{'$NestedScalar1'});
	
	#NestArray1 event has the correct auto indexes
	is_deeply	($eventMacro->{Event_Related_Dynamic_Variables}{accessed_array}{NestArray1}{7}{'$NestedScalar1'}, $eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray1}{'$NestedScalar1'}{auto_indexes});
}

1;