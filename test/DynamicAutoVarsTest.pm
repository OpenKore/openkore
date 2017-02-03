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
	
	subtest 'single condition - single nest' => sub {
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
		$eventMacro->set_scalar_var('NestedScalar1', 5);
		
		#NestedScalar1 is defined
		is ($eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{defined}, 1);
		is ($eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{value}, 5);
		ok (exists $eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{call_to}[0]{sub_callback_index});
		is ($eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{call_to}[0]{sub_callback_index}, 1);
		
		#NestArray1 is not defined, but it's complement is
		is ($eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray1}{'$NestedScalar1'}{defined}, 0);
		ok (exists $eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray1}{'$NestedScalar1'}{complement_defined});
		
		#Both of them have sub calls now
		ok (exists $eventMacro->{Dynamic_Variable_Sub_Callbacks}{scalar}{NestedScalar1});
		ok (exists $eventMacro->{Dynamic_Variable_Sub_Callbacks}{accessed_array}{NestArray1});
		
		#NestArray1 sub call has the correct complement
		ok (exists $eventMacro->{Dynamic_Variable_Sub_Callbacks}{accessed_array}{NestArray1}{5});
		is (scalar keys %{$eventMacro->{Dynamic_Variable_Sub_Callbacks}{accessed_array}{NestArray1}}, 1);
		
		#NestArray1 sub call and NestedScalar1 sub call index point to each other
		ok (exists $eventMacro->{Dynamic_Variable_Sub_Callbacks}{accessed_array}{NestArray1}{5}{$eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{call_to}[0]{sub_callback_index}});
		is ($eventMacro->{Dynamic_Variable_Sub_Callbacks}{accessed_array}{NestArray1}{5}{$eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{call_to}[0]{sub_callback_index}}, '$NestedScalar1');
		
		#Neither of them has events
		ok (!exists $eventMacro->{Event_Related_Dynamic_Variables}{scalar}{NestedScalar1});
		ok (!exists $eventMacro->{Event_Related_Dynamic_Variables}{accessed_array}{NestArray1});
		
		#Changing NestedScalar1
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
	
		#Undefining NestedScalar1 while NestArray1 is defined
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
		
		#Defining NestedScalar1 with a value that makes NestArray1 also defined
		$eventMacro->set_scalar_var('NestedScalar1', 7);
		
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
	};
	
	subtest 'double condition - single nest' => sub {
		my $parsed = parseMacroFile( "$RealBin/textfiles/DynamicAutoVarsTest2.txt", 0 );
		
		ok ($parsed);
		
		$eventMacro = eventMacro::Core->new( "$RealBin/textfiles/DynamicAutoVarsTest2.txt" );
		
		ok (defined $eventMacro);
		
		#All vars exist
		ok (exists $eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1});
		ok (exists $eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray1});
		ok (exists $eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray1}{'$NestedScalar1'});
		ok (exists $eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray2});
		ok (exists $eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray2}{'$NestedScalar1'});
		
		#NestedScalar1 is not the last var, so it has calls
		ok (exists $eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{call_to});
		is ($eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{last_nested}, 0);
		
		#NestArray1 and NestArray2 is the last var, so it doesn't have calls, but has auto indexes
		ok (!exists $eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray1}{'$NestedScalar1'}{call_to});
		is ($eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray1}{'$NestedScalar1'}{last_nested}, 1);
		ok (exists $eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray1}{'$NestedScalar1'}{auto_indexes});
		ok (!exists $eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray2}{'$NestedScalar1'}{call_to});
		is ($eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray2}{'$NestedScalar1'}{last_nested}, 1);
		ok (exists $eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray2}{'$NestedScalar1'}{auto_indexes});
		
		#NestedScalar1 correctly calls to NestArray1 and NestArray2
		ok (($eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{call_to}[0]{name} eq 'NestArray1' && $eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{call_to}[1]{name} eq 'NestArray2') || ($eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{call_to}[1]{name} eq 'NestArray1' && $eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{call_to}[0]{name} eq 'NestArray2'));
		
		#Neither of them is defined
		is ($eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{defined}, 0);
		ok (!exists $eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{call_to}[0]{sub_callback_index});
		ok (!exists $eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{call_to}[1]{sub_callback_index});
		is ($eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray1}{'$NestedScalar1'}{defined}, 0);
		is ($eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray2}{'$NestedScalar1'}{defined}, 0);
		ok (!exists $eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray1}{'$NestedScalar1'}{complement_defined});
		ok (!exists $eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray2}{'$NestedScalar1'}{complement_defined});
		
		#Only NestedScalar1 has a sub callback
		ok (exists $eventMacro->{Dynamic_Variable_Sub_Callbacks}{scalar}{NestedScalar1});
		ok (!exists $eventMacro->{Dynamic_Variable_Sub_Callbacks}{accessed_array}{NestArray1});
		ok (!exists $eventMacro->{Dynamic_Variable_Sub_Callbacks}{accessed_array}{NestArray2});
		
		#Neither of them has events
		ok (!exists $eventMacro->{Event_Related_Dynamic_Variables}{scalar}{NestedScalar1});
		ok (!exists $eventMacro->{Event_Related_Dynamic_Variables}{accessed_array}{NestArray1});
		ok (!exists $eventMacro->{Event_Related_Dynamic_Variables}{accessed_array}{NestArray2});

		#Defining NestedScalar1
		$eventMacro->set_scalar_var('NestedScalar1', 3);
		
		#NestedScalar1 is defined
		is ($eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{defined}, 1);
		is ($eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{value}, 3);
		ok (exists $eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{call_to}[0]{sub_callback_index});
		is ($eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{call_to}[0]{sub_callback_index}, 1);
		ok (exists $eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{call_to}[1]{sub_callback_index});
		is ($eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{call_to}[1]{sub_callback_index}, 1);
		
		#NestArray1 is not defined, but it's complement is
		is ($eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray1}{'$NestedScalar1'}{defined}, 0);
		ok (exists $eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray1}{'$NestedScalar1'}{complement_defined});
		
		#NestArray2 is not defined, but it's complement is
		is ($eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray2}{'$NestedScalar1'}{defined}, 0);
		ok (exists $eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray2}{'$NestedScalar1'}{complement_defined});
		
		#all of them have sub calls now
		ok (exists $eventMacro->{Dynamic_Variable_Sub_Callbacks}{scalar}{NestedScalar1});
		ok (exists $eventMacro->{Dynamic_Variable_Sub_Callbacks}{accessed_array}{NestArray1});
		ok (exists $eventMacro->{Dynamic_Variable_Sub_Callbacks}{accessed_array}{NestArray2});
		
		#NestArray1 sub call has the correct complement
		ok (exists $eventMacro->{Dynamic_Variable_Sub_Callbacks}{accessed_array}{NestArray1}{3});
		is (scalar keys %{$eventMacro->{Dynamic_Variable_Sub_Callbacks}{accessed_array}{NestArray1}}, 1);
		
		#NestArray2 sub call has the correct complement
		ok (exists $eventMacro->{Dynamic_Variable_Sub_Callbacks}{accessed_array}{NestArray2}{3});
		is (scalar keys %{$eventMacro->{Dynamic_Variable_Sub_Callbacks}{accessed_array}{NestArray2}}, 1);
		
		#Neither of them has events
		ok (!exists $eventMacro->{Event_Related_Dynamic_Variables}{scalar}{NestedScalar1});
		ok (!exists $eventMacro->{Event_Related_Dynamic_Variables}{accessed_array}{NestArray1});
		ok (!exists $eventMacro->{Event_Related_Dynamic_Variables}{accessed_array}{NestArray2});
	};
	
	subtest 'single condition - multiple nest' => sub {
		my $parsed = parseMacroFile( "$RealBin/textfiles/DynamicAutoVarsTest3.txt", 0 );
		
		ok ($parsed);
		
		$eventMacro = eventMacro::Core->new( "$RealBin/textfiles/DynamicAutoVarsTest3.txt" );
		
		ok (defined $eventMacro);
		#BaseLevel $NestHash2{$NestHash1{$NestArray1[$NestedScalar1]}}
		
		#All vars exist
		ok (exists $eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1});
		ok (exists $eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray1});
		ok (exists $eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray1}{'$NestedScalar1'});
		ok (exists $eventMacro->{Dynamic_Variable_Complements}{accessed_hash}{NestHash1});
		ok (exists $eventMacro->{Dynamic_Variable_Complements}{accessed_hash}{NestHash1}{'$NestArray1[$NestedScalar1]'});
		ok (exists $eventMacro->{Dynamic_Variable_Complements}{accessed_hash}{NestHash2});
		ok (exists $eventMacro->{Dynamic_Variable_Complements}{accessed_hash}{NestHash2}{'$NestHash1{$NestArray1[$NestedScalar1]}'});
		
		#NestedScalar1, NestArray1, NestHash1 is not the last var, so it has calls
		ok (exists $eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{call_to});
		is ($eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{last_nested}, 0);
		
		ok (exists $eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray1}{'$NestedScalar1'}{call_to});
		is ($eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray1}{'$NestedScalar1'}{last_nested}, 0);
		
		ok (exists $eventMacro->{Dynamic_Variable_Complements}{accessed_hash}{NestHash1}{'$NestArray1[$NestedScalar1]'}{call_to});
		is ($eventMacro->{Dynamic_Variable_Complements}{accessed_hash}{NestHash1}{'$NestArray1[$NestedScalar1]'}{last_nested}, 0);
		
		#NestHash2 is the last var, so it doesn't have calls, but has auto indexes
		ok (!exists $eventMacro->{Dynamic_Variable_Complements}{accessed_hash}{NestHash2}{'$NestHash1{$NestArray1[$NestedScalar1]}'}{call_to});
		is ($eventMacro->{Dynamic_Variable_Complements}{accessed_hash}{NestHash2}{'$NestHash1{$NestArray1[$NestedScalar1]}'}{last_nested}, 1);
		ok (exists $eventMacro->{Dynamic_Variable_Complements}{accessed_hash}{NestHash2}{'$NestHash1{$NestArray1[$NestedScalar1]}'}{auto_indexes});
		
		#Each var calls to its successor
		is ($eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{call_to}[0]{name}, 'NestArray1');
		is ($eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray1}{'$NestedScalar1'}{call_to}[0]{name}, 'NestHash1');
		is ($eventMacro->{Dynamic_Variable_Complements}{accessed_hash}{NestHash1}{'$NestArray1[$NestedScalar1]'}{call_to}[0]{name}, 'NestHash2');
		
		#None of them is defined
		is ($eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{defined}, 0);
		ok (!exists $eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{call_to}[0]{sub_callback_index});
		
		is ($eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray1}{'$NestedScalar1'}{defined}, 0);
		ok (!exists $eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray1}{'$NestedScalar1'}{complement_defined});
		
		is ($eventMacro->{Dynamic_Variable_Complements}{accessed_hash}{NestHash1}{'$NestArray1[$NestedScalar1]'}{defined}, 0);
		ok (!exists $eventMacro->{Dynamic_Variable_Complements}{accessed_hash}{NestHash1}{'$NestArray1[$NestedScalar1]'}{complement_defined});
		
		is ($eventMacro->{Dynamic_Variable_Complements}{accessed_hash}{NestHash2}{'$NestHash1{$NestArray1[$NestedScalar1]}'}{defined}, 0);
		ok (!exists $eventMacro->{Dynamic_Variable_Complements}{accessed_hash}{NestHash2}{'$NestHash1{$NestArray1[$NestedScalar1]}'}{complement_defined});
		
		#Only NestedScalar1 has a sub callback
		ok (exists $eventMacro->{Dynamic_Variable_Sub_Callbacks}{scalar}{NestedScalar1});
		ok (!exists $eventMacro->{Dynamic_Variable_Sub_Callbacks}{accessed_array}{NestArray1});
		ok (!exists $eventMacro->{Dynamic_Variable_Sub_Callbacks}{accessed_hash}{NestHash1});
		ok (!exists $eventMacro->{Dynamic_Variable_Sub_Callbacks}{accessed_hash}{NestHash2});
		
		#Neither of them has events
		ok (!exists $eventMacro->{Event_Related_Dynamic_Variables}{scalar}{NestedScalar1});
		ok (!exists $eventMacro->{Event_Related_Dynamic_Variables}{accessed_array}{NestArray1});
		ok (!exists $eventMacro->{Event_Related_Dynamic_Variables}{accessed_hash}{NestHash1});
		ok (!exists $eventMacro->{Event_Related_Dynamic_Variables}{accessed_hash}{NestHash2});
		
		#Changing NestedScalar1
		$eventMacro->set_scalar_var('NestedScalar1', 2);
		
		#NestedScalar1 is defined
		is ($eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{defined}, 1);
		is ($eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{value}, 2);
		ok (exists $eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{call_to}[0]{sub_callback_index});
		is ($eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{call_to}[0]{sub_callback_index}, 1);
		
		#NestArray1 is not defined, but it's complement is
		is ($eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray1}{'$NestedScalar1'}{defined}, 0);
		ok (exists $eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray1}{'$NestedScalar1'}{complement_defined});
		
		#NestHash1 and NestHash2 is not defined
		is ($eventMacro->{Dynamic_Variable_Complements}{accessed_hash}{NestHash1}{'$NestArray1[$NestedScalar1]'}{defined}, 0);
		ok (!exists $eventMacro->{Dynamic_Variable_Complements}{accessed_hash}{NestHash1}{'$NestArray1[$NestedScalar1]'}{complement_defined});
		
		is ($eventMacro->{Dynamic_Variable_Complements}{accessed_hash}{NestHash2}{'$NestHash1{$NestArray1[$NestedScalar1]}'}{defined}, 0);
		ok (!exists $eventMacro->{Dynamic_Variable_Complements}{accessed_hash}{NestHash2}{'$NestHash1{$NestArray1[$NestedScalar1]}'}{complement_defined});
		
		#Both of them have sub calls now, the others don't
		ok (exists $eventMacro->{Dynamic_Variable_Sub_Callbacks}{scalar}{NestedScalar1});
		ok (exists $eventMacro->{Dynamic_Variable_Sub_Callbacks}{accessed_array}{NestArray1});
		ok (!exists $eventMacro->{Dynamic_Variable_Sub_Callbacks}{accessed_hash}{NestHash1});
		ok (!exists $eventMacro->{Dynamic_Variable_Sub_Callbacks}{accessed_hash}{NestHash2});
		
		#NestArray1 sub call has the correct complement
		ok (exists $eventMacro->{Dynamic_Variable_Sub_Callbacks}{accessed_array}{NestArray1}{2});
		is (scalar keys %{$eventMacro->{Dynamic_Variable_Sub_Callbacks}{accessed_array}{NestArray1}}, 1);
		
		#NestArray1 sub call and NestedScalar1 sub call index point to each other
		ok (exists $eventMacro->{Dynamic_Variable_Sub_Callbacks}{accessed_array}{NestArray1}{2}{$eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{call_to}[0]{sub_callback_index}});
		is ($eventMacro->{Dynamic_Variable_Sub_Callbacks}{accessed_array}{NestArray1}{2}{$eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{call_to}[0]{sub_callback_index}}, '$NestedScalar1');
		
		#Neither of them has events
		ok (!exists $eventMacro->{Event_Related_Dynamic_Variables}{scalar}{NestedScalar1});
		ok (!exists $eventMacro->{Event_Related_Dynamic_Variables}{accessed_array}{NestArray1});
		ok (!exists $eventMacro->{Event_Related_Dynamic_Variables}{accessed_hash}{NestHash1});
		ok (!exists $eventMacro->{Event_Related_Dynamic_Variables}{accessed_hash}{NestHash2});
		
		#Changing NestArray1[2]
		$eventMacro->set_array_var('NestArray1', 2, 'poring');
		
		#NestedScalar1 is defined
		is ($eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{defined}, 1);
		is ($eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{value}, 2);
		ok (exists $eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{call_to}[0]{sub_callback_index});
		is ($eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{call_to}[0]{sub_callback_index}, 1);
		
		#NestArray1 is defined
		is ($eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray1}{'$NestedScalar1'}{defined}, 1);
		is ($eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray1}{'$NestedScalar1'}{value}, 'poring');
		ok (exists $eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray1}{'$NestedScalar1'}{call_to}[0]{sub_callback_index});
		is ($eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray1}{'$NestedScalar1'}{call_to}[0]{sub_callback_index}, 1);
		ok (exists $eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray1}{'$NestedScalar1'}{complement_defined});
		
		#NestHash1 is not defined, but it's complement is
		is ($eventMacro->{Dynamic_Variable_Complements}{accessed_hash}{NestHash1}{'$NestArray1[$NestedScalar1]'}{defined}, 0);
		ok (exists $eventMacro->{Dynamic_Variable_Complements}{accessed_hash}{NestHash1}{'$NestArray1[$NestedScalar1]'}{complement_defined});
		
		#NestHash2 is not defined
		is ($eventMacro->{Dynamic_Variable_Complements}{accessed_hash}{NestHash2}{'$NestHash1{$NestArray1[$NestedScalar1]}'}{defined}, 0);
		ok (!exists $eventMacro->{Dynamic_Variable_Complements}{accessed_hash}{NestHash2}{'$NestHash1{$NestArray1[$NestedScalar1]}'}{complement_defined});
		
		#3 of them have sub calls now, NestHash2 doesn't
		ok (exists $eventMacro->{Dynamic_Variable_Sub_Callbacks}{scalar}{NestedScalar1});
		ok (exists $eventMacro->{Dynamic_Variable_Sub_Callbacks}{accessed_array}{NestArray1});
		ok (exists $eventMacro->{Dynamic_Variable_Sub_Callbacks}{accessed_hash}{NestHash1});
		ok (!exists $eventMacro->{Dynamic_Variable_Sub_Callbacks}{accessed_hash}{NestHash2});
		
		#NestArray1 sub call has the correct complement
		ok (exists $eventMacro->{Dynamic_Variable_Sub_Callbacks}{accessed_array}{NestArray1}{2});
		is (scalar keys %{$eventMacro->{Dynamic_Variable_Sub_Callbacks}{accessed_array}{NestArray1}}, 1);
		
		#NestArray1 sub call and NestedScalar1 sub call index point to each other
		ok (exists $eventMacro->{Dynamic_Variable_Sub_Callbacks}{accessed_array}{NestArray1}{2}{$eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{call_to}[0]{sub_callback_index}});
		is ($eventMacro->{Dynamic_Variable_Sub_Callbacks}{accessed_array}{NestArray1}{2}{$eventMacro->{Dynamic_Variable_Complements}{scalar}{NestedScalar1}{call_to}[0]{sub_callback_index}}, '$NestedScalar1');
		
		#NestHash1 sub call has the correct complement
		ok (exists $eventMacro->{Dynamic_Variable_Sub_Callbacks}{accessed_hash}{NestHash1}{'poring'});
		is (scalar keys %{$eventMacro->{Dynamic_Variable_Sub_Callbacks}{accessed_hash}{NestHash1}}, 1);
		
		#NestHash1 sub call and NestArray1 sub call index point to each other
		ok (exists $eventMacro->{Dynamic_Variable_Sub_Callbacks}{accessed_hash}{NestHash1}{'poring'}{$eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray1}{'$NestedScalar1'}{call_to}[0]{sub_callback_index}});
		is ($eventMacro->{Dynamic_Variable_Sub_Callbacks}{accessed_hash}{NestHash1}{'poring'}{$eventMacro->{Dynamic_Variable_Complements}{accessed_array}{NestArray1}{'$NestedScalar1'}{call_to}[0]{sub_callback_index}}, '$NestArray1[$NestedScalar1]');
		
		#Neither of them has events
		ok (!exists $eventMacro->{Event_Related_Dynamic_Variables}{scalar}{NestedScalar1});
		ok (!exists $eventMacro->{Event_Related_Dynamic_Variables}{accessed_array}{NestArray1});
		ok (!exists $eventMacro->{Event_Related_Dynamic_Variables}{accessed_hash}{NestHash1});
		ok (!exists $eventMacro->{Event_Related_Dynamic_Variables}{accessed_hash}{NestHash2});
	};
}

#Log::warning "[test] Dynamic_Variable_Complements ".Dumper($eventMacro->{Dynamic_Variable_Complements})."\n";
#Log::warning "[test] Dynamic_Variable_Sub_Callbacks ".Dumper($eventMacro->{Dynamic_Variable_Sub_Callbacks})."\n";
#Log::warning "[test] Event_Related_Dynamic_Variables ".Dumper($eventMacro->{Event_Related_Dynamic_Variables})."\n";

1;