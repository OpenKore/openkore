package RunnerStatementTest;

use strict;
use warnings;
use FindBin qw($RealBin);
use lib "$RealBin";

use Test::More;
use eventMacro::Core;
use eventMacro::Data;
use eventMacro::Runner;
use eventMacro::Utilities qw(find_variable);

sub start {
	$eventMacro = eventMacro::Core->new( "$RealBin/textfiles/LoadConditionsTest.txt" );
	
	$eventMacro->{Macro_Runner}{'1'} = new eventMacro::Runner(
			'testmacro1',  # name
			1,             # repeat
			1,             # slot
			undef,         # exclusive
			undef,         # overrideAI
			undef,         # orphan
			undef,         # delay
			undef,         # macro_delay
			0              # is_subcall
	);
	
	ok (exists $eventMacro->{Macro_Runner}{'1'});
	
	ok (defined $eventMacro->{Macro_Runner}{'1'});
	
	subtest 'math simple' => sub {
		is (($eventMacro->{Macro_Runner}{'1'}->parse_and_check_condition_text( '(1 > 0)' ))[0], 1);
		is (($eventMacro->{Macro_Runner}{'1'}->parse_and_check_condition_text( '(5 > 7)' ))[0], 0);
		is (($eventMacro->{Macro_Runner}{'1'}->parse_and_check_condition_text( '(2 = 2)' ))[0], 1);
		is (($eventMacro->{Macro_Runner}{'1'}->parse_and_check_condition_text( '(2 = 5)' ))[0], 0);
		is (($eventMacro->{Macro_Runner}{'1'}->parse_and_check_condition_text( '(10 < 20)' ))[0], 1);
		is (($eventMacro->{Macro_Runner}{'1'}->parse_and_check_condition_text( '(70 < 50)' ))[0], 0);
		is (($eventMacro->{Macro_Runner}{'1'}->parse_and_check_condition_text( '(5 == 5)' ))[0], 1);
		is (($eventMacro->{Macro_Runner}{'1'}->parse_and_check_condition_text( '(5 == 9)' ))[0], 0);
		is (($eventMacro->{Macro_Runner}{'1'}->parse_and_check_condition_text( '(5 >= 4)' ))[0], 1);
		is (($eventMacro->{Macro_Runner}{'1'}->parse_and_check_condition_text( '(5 >= 5)' ))[0], 1);
		is (($eventMacro->{Macro_Runner}{'1'}->parse_and_check_condition_text( '(5 >= 6)' ))[0], 0);
		is (($eventMacro->{Macro_Runner}{'1'}->parse_and_check_condition_text( '(3 <= 4)' ))[0], 1);
		is (($eventMacro->{Macro_Runner}{'1'}->parse_and_check_condition_text( '(4 <= 4)' ))[0], 1);
		is (($eventMacro->{Macro_Runner}{'1'}->parse_and_check_condition_text( '(5 <= 4)' ))[0], 0);
		is (($eventMacro->{Macro_Runner}{'1'}->parse_and_check_condition_text( '(6 != 5)' ))[0], 1);
		is (($eventMacro->{Macro_Runner}{'1'}->parse_and_check_condition_text( '(6 != 6)' ))[0], 0);
	};
	
	subtest 'math range' => sub {
		is (($eventMacro->{Macro_Runner}{'1'}->parse_and_check_condition_text( '(5 == 3..7)' ))[0], 1);
		is (($eventMacro->{Macro_Runner}{'1'}->parse_and_check_condition_text( '(9 == 15..20)' ))[0], 0);
		is (($eventMacro->{Macro_Runner}{'1'}->parse_and_check_condition_text( '(3 != 5..7)' ))[0], 1);
		is (($eventMacro->{Macro_Runner}{'1'}->parse_and_check_condition_text( '(15 != 10..20)' ))[0], 0);
		
		is (($eventMacro->{Macro_Runner}{'1'}->parse_and_check_condition_text( '(3..7 == 5)' ))[0], 1);
		is (($eventMacro->{Macro_Runner}{'1'}->parse_and_check_condition_text( '(15..20 == 9)' ))[0], 0);
		is (($eventMacro->{Macro_Runner}{'1'}->parse_and_check_condition_text( '(5..7 != 3)' ))[0], 1);
		is (($eventMacro->{Macro_Runner}{'1'}->parse_and_check_condition_text( '(10..20 != 15)' ))[0], 0);
	};
	
	subtest 'text' => sub {
		is (($eventMacro->{Macro_Runner}{'1'}->parse_and_check_condition_text( '(Poring == Poring)' ))[0], 1);
		is (($eventMacro->{Macro_Runner}{'1'}->parse_and_check_condition_text( '(Poring == Drops)' ))[0], 0);
		is (($eventMacro->{Macro_Runner}{'1'}->parse_and_check_condition_text( '(Poring != Drops)' ))[0], 1);
		is (($eventMacro->{Macro_Runner}{'1'}->parse_and_check_condition_text( '(Poring != Poring)' ))[0], 0);
	};
	
	subtest 'list' => sub {
		is (($eventMacro->{Macro_Runner}{'1'}->parse_and_check_condition_text( '(Poring ~ Drops, Poring, Poporing, Magmaring)' ))[0], 1);
		is (($eventMacro->{Macro_Runner}{'1'}->parse_and_check_condition_text( '(Weapon ~ Shield, Hat, Shoe, Mantle)' ))[0], 0);
	};
	
	subtest 'regex' => sub {
		is (($eventMacro->{Macro_Runner}{'1'}->parse_and_check_condition_text( '(Poring =~ /Por/)' ))[0], 1);
		is (($eventMacro->{Macro_Runner}{'1'}->parse_and_check_condition_text( '(Poring =~ /Por/i)' ))[0], 1);
		is (($eventMacro->{Macro_Runner}{'1'}->parse_and_check_condition_text( '(Poring =~ /por/)' ))[0], 0);
		is (($eventMacro->{Macro_Runner}{'1'}->parse_and_check_condition_text( '(Poring =~ /por/i)' ))[0], 1);
		is (($eventMacro->{Macro_Runner}{'1'}->parse_and_check_condition_text( '(Marin =~ /oring/i)' ))[0], 0);
	};
}

1;
