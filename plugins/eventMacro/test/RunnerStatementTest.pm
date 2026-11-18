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
	
	$eventMacro->{Macro_Runner} = new eventMacro::Runner(
			'testmacro1',
			'auto_name',
			1,
			undef,
			undef,
			undef,
			undef,
			undef,
			undef,
			0
		);
	
	ok (defined $eventMacro->{Macro_Runner});
	
	my $runner = $eventMacro->{Macro_Runner};
	# The runner's public API takes a parenthesized condition and returns
	# (boolean, trailing_text). Test the boolean without leaking the second
	# return value into Test::More's optional test-name argument.
	my $check = sub {
		my ($result) = $runner->parse_and_check_condition_text('(' . $_[0] . ')');
		return $result;
	};

	subtest 'math simple' => sub {
		is ($check->( '1 > 0' ), 1);
		is ($check->( '5 > 7' ), 0);
		is ($check->( '2 = 2' ), 1);
		is ($check->( '2 = 5' ), 0);
		is ($check->( '10 < 20' ), 1);
		is ($check->( '70 < 50' ), 0);
		is ($check->( '5 == 5' ), 1);
		is ($check->( '5 == 9' ), 0);
		is ($check->( '5 >= 4' ), 1);
		is ($check->( '5 >= 5' ), 1);
		is ($check->( '5 >= 6' ), 0);
		is ($check->( '3 <= 4' ), 1);
		is ($check->( '4 <= 4' ), 1);
		is ($check->( '5 <= 4' ), 0);
		is ($check->( '6 != 5' ), 1);
		is ($check->( '6 != 6' ), 0);
		done_testing();
	};
	
	subtest 'math range' => sub {
		is ($check->( '5 == 3..7' ), 1);
		is ($check->( '9 == 15..20' ), 0);
		is ($check->( '3 != 5..7' ), 1);
		is ($check->( '15 != 10..20' ), 0);
		
		is ($check->( '3..7 == 5' ), 1);
		is ($check->( '15..20 == 9' ), 0);
		is ($check->( '5..7 != 3' ), 1);
		is ($check->( '10..20 != 15' ), 0);
		done_testing();
	};
	
	subtest 'text' => sub {
		is ($check->( 'Poring == Poring' ), 1);
		is ($check->( 'Poring == Drops' ), 0);
		is ($check->( 'Poring != Drops' ), 1);
		is ($check->( 'Poring != Poring' ), 0);
		done_testing();
	};
	
	subtest 'list' => sub {
		is ($check->( 'Poring ~ Drops, Poring, Poporing, Magmaring' ), 1);
		is ($check->( 'Weapon ~ Shield, Hat, Shoe, Mantle' ), 0);
		done_testing();
	};
	
	subtest 'regex' => sub {
		is ($check->( 'Poring =~ /Por/'), 1);
		is ($check->( 'Poring =~ /Por/i'), 1);
		is ($check->( 'Poring =~ /por/'), 0);
		is ($check->( 'Poring =~ /por/i'), 1);
		is ($check->( 'Marin =~ /oring/i'), 0);
		done_testing();
	};

	subtest 'statement API and compound conditions' => sub {
		my ($value, $trailing) = $runner->parse_and_check_condition_text('(10 >= 5) {');
		is($value, 1, 'condition is true');
		is($trailing, '{', 'text after condition is preserved');
		is($check->('(1 == 1) && (2 == 2)'), 1, 'nested AND');
		is($check->('(1 == 2) || (2 == 2)'), 1, 'nested OR');
		is($check->('(1 == 2) && (2 == 2)'), 0, 'false nested AND');
		done_testing();
	};
}

1;
