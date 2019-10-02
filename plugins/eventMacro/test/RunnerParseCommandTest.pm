package RunnerParseCommandTest;

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
	
	subtest 'scalar' => sub {
		$eventMacro->set_scalar_var('scalar1', 10);
		is ($eventMacro->{Macro_Runner}->parse_command( '$scalar1' ), '10');
		is ($eventMacro->{Macro_Runner}->parse_command( '$scalar1 + $scalar1' ), '10 + 10');
		is ($eventMacro->{Macro_Runner}->parse_command( '$scalar1 * $scalar1' ), '10 * 10');
		
		$eventMacro->set_scalar_var('scalar2', 25);
		is ($eventMacro->{Macro_Runner}->parse_command( '$scalar2' ), '25');
		is ($eventMacro->{Macro_Runner}->parse_command( '$scalar1 + $scalar2' ), '10 + 25');
		is ($eventMacro->{Macro_Runner}->parse_command( '$scalar1 * $scalar2' ), '10 * 25');
		
		is ($eventMacro->{Macro_Runner}->parse_command( '$scalar3' ), '');
		is ($eventMacro->{Macro_Runner}->parse_command( '$scalar3 + $scalar2' ), ' + 25');
		is ($eventMacro->{Macro_Runner}->parse_command( '$scalar3 * $scalar2' ), ' * 25');
	};
	
	subtest 'array' => sub {
		$eventMacro->set_full_array('array1', ['Angeling', 'Deviling', 'Archangeling', 'undef', 'Mastering', 'undef', 'King Poring']);
		is ($eventMacro->{Macro_Runner}->parse_command( '@array1' ), '7');
		is ($eventMacro->{Macro_Runner}->parse_command( '@array1 > $scalar1' ), '7 > 10');
		is ($eventMacro->{Macro_Runner}->parse_command( '@array1 - 5' ), '7 - 5');
		
		$eventMacro->set_full_array('array2', ['Poring', 'undef', 'Drops', 'Magmaring']);
		is ($eventMacro->{Macro_Runner}->parse_command( '@array2' ), '4');
		is ($eventMacro->{Macro_Runner}->parse_command( '@array1 + @array2' ), '7 + 4');
		
		is ($eventMacro->{Macro_Runner}->parse_command( '$array1[0]' ), 'Angeling');
		is ($eventMacro->{Macro_Runner}->parse_command( '$array1[0] or $array1[1] or maybe $array1[2] or even $array1[3] or if not possible $array1[6]' ), 'Angeling or Deviling or maybe Archangeling or even  or if not possible King Poring');
		is ($eventMacro->{Macro_Runner}->parse_command( '$array2[2] is weaker than $array1[0], but stronger then $array2[0]' ), 'Drops is weaker than Angeling, but stronger then Poring');
		
		is ($eventMacro->{Macro_Runner}->parse_command( '$array[7] '.$macro_keywords_character.'push(@array1, Another Poring) $array1[7] @array1' ), ' 8 Another Poring 8');
		
		is ($eventMacro->{Macro_Runner}->parse_command( $macro_keywords_character.'unshift(@array1, Even other poring)' ), '9');
		is ($eventMacro->{Macro_Runner}->parse_command( '@array1' ), '9');
		is ($eventMacro->{Macro_Runner}->parse_command( '$array1[0]' ), 'Even other poring');
		
		is ($eventMacro->{Macro_Runner}->parse_command( $macro_keywords_character.'pop(@array2)' ), 'Magmaring');
		is ($eventMacro->{Macro_Runner}->parse_command( '@array2' ), '3');
		is ($eventMacro->{Macro_Runner}->parse_command( $macro_keywords_character.'shift(@array2)' ), 'Poring');
		is ($eventMacro->{Macro_Runner}->parse_command( '@array2' ), '2');
	};
	
	subtest 'hash' => sub {
		$eventMacro->set_full_hash('hash1', {'Poring' => 10, 'Drops' => 25, 'Poporing' => 'undef', 'Magmaring' => 100, 'Angeling' => 'undef'});
		is ($eventMacro->{Macro_Runner}->parse_command( '%hash1' ), '5');
		is ($eventMacro->{Macro_Runner}->parse_command( '%hash1 > $scalar1 == @array2' ), '5 > 10 == 2');
		is ($eventMacro->{Macro_Runner}->parse_command( '%hash1 + %hash1 * %hash1' ), '5 + 5 * 5');
		
		$eventMacro->set_full_hash('hash2', {'Staff' => 2000, 'Shield' => 'undef', 'Card' => 7000});
		is ($eventMacro->{Macro_Runner}->parse_command( '%hash2' ), '3');
		is ($eventMacro->{Macro_Runner}->parse_command( '%hash2 / %hash2' ), '3 / 3');
		is ($eventMacro->{Macro_Runner}->parse_command( '%hash2 + %hash1' ), '3 + 5');
		
		is ($eventMacro->{Macro_Runner}->parse_command( 'The member of key Poring is $hash1{Poring}' ), 'The member of key Poring is 10');
		is ($eventMacro->{Macro_Runner}->parse_command( 'Poporing is $hash1{Poporing}' ), 'Poporing is ');
		is ($eventMacro->{Macro_Runner}->parse_command( 'The staff costs $hash2{Staff}' ), 'The staff costs 2000');
		
		is ($eventMacro->{Macro_Runner}->parse_command( $macro_keywords_character.'exists($hash1{Poring})' ), '1');
		is ($eventMacro->{Macro_Runner}->parse_command( $macro_keywords_character.'exists($hash1{Poporing})' ), '1');
		is ($eventMacro->{Macro_Runner}->parse_command( $macro_keywords_character.'exists($hash2{Staff})' ), '1');
		is ($eventMacro->{Macro_Runner}->parse_command( $macro_keywords_character.'exists($hash1{Staff})' ), '0');
		is ($eventMacro->{Macro_Runner}->parse_command( $macro_keywords_character.'exists($hash2{Poporing})' ), '0');
		
		is ($eventMacro->{Macro_Runner}->parse_command( $macro_keywords_character.'delete($hash1{Magmaring})' ), '100');
		is ($eventMacro->{Macro_Runner}->parse_command( $macro_keywords_character.'delete($hash2{Staff})' ), '2000');
	};
	
	subtest 'complex vars' => sub {
		$eventMacro->set_full_hash('hash1', {'Poring' => 1, 'Drops' => 7, 'Magmaring' => 10, 'Angeling' => 25, 'Deviling' => 100});
		$eventMacro->set_full_hash('hash2', {'Staff' => 2000, 'Shield' => 5000, 'Card' => 7000});
		$eventMacro->set_full_array('array1', ['Angeling', 'Deviling', 'Archangeling', 'Mastering', 'King Poring']);
		$eventMacro->set_full_array('array2', ['Poring', 'Drops', 'Magmaring']);
		$eventMacro->set_scalar_var('scalar1', 0);
		$eventMacro->set_scalar_var('scalar2', 1);
		$eventMacro->set_scalar_var('scalar3', 2);
		is ($eventMacro->{Macro_Runner}->parse_command( '$hash1{$array1[$scalar1]}' ), '25');
		is ($eventMacro->{Macro_Runner}->parse_command( '$array2[$scalar2]' ), 'Drops');
		$eventMacro->set_scalar_var('scalar4', 'Poring');
		is ($eventMacro->{Macro_Runner}->parse_command( '$hash1{$scalar4}' ), '1');
		is ($eventMacro->{Macro_Runner}->parse_command( '$array1[$hash1{$scalar4}]' ), 'Deviling');
		is ($eventMacro->{Macro_Runner}->parse_command( '$hash1{$array1[$hash1{$scalar4}]}' ), '100');
		
		$eventMacro->set_full_hash('hash3', {'Poring' => 'Drops', 'Drops' => 'Magmaring', 'Magmaring' => 'Angeling', 'Angeling' => 'Deviling', 'Deviling' => 'victory'});
		
		is ($eventMacro->{Macro_Runner}->parse_command( '$hash3{$scalar4}' ), 'Drops');
		is ($eventMacro->{Macro_Runner}->parse_command( '$hash3{$hash3{$scalar4}}' ), 'Magmaring');
		is ($eventMacro->{Macro_Runner}->parse_command( '$hash3{$hash3{$hash3{$scalar4}}}' ), 'Angeling');
		is ($eventMacro->{Macro_Runner}->parse_command( '$hash3{$hash3{$hash3{$hash3{$scalar4}}}}' ), 'Deviling');
		is ($eventMacro->{Macro_Runner}->parse_command( '$hash3{$hash3{$hash3{$hash3{$hash3{$scalar4}}}}}' ), 'victory');
		
		$eventMacro->set_full_array('array3', [5, 2, 3, 0, 1, 4]);
		$eventMacro->set_full_array('array4', [2, 5, 3, 4, 'end', 1]);
		
		is ($eventMacro->{Macro_Runner}->parse_command( '$array4[$array3[$array4[$array3[$array4[$array3[$array4[$array3[$array4[$array3[$array4[$array3[$scalar1]]]]]]]]]]]]' ), 'end');
		
		is ($eventMacro->{Macro_Runner}->parse_command( 'olha que legal esse [{{$hash3{$hash3{$scalar4}}}}]' ), 'olha que legal esse [{{Magmaring}}]');
		
	};
	
	subtest 'defined' => sub {
		$eventMacro->set_scalar_var('scalar1', 'undef');
		$eventMacro->set_scalar_var('scalar2', 15);
		
		is ($eventMacro->{Macro_Runner}->parse_command( 'the value is $scalar1' ), 'the value is ');
		is ($eventMacro->{Macro_Runner}->parse_command( 'the value is $scalar2' ), 'the value is 15');
		
		is ($eventMacro->{Macro_Runner}->parse_command( $macro_keywords_character.'defined($scalar1)' ), 0);
		is ($eventMacro->{Macro_Runner}->parse_command( $macro_keywords_character.'defined($scalar2)' ), 1);
		
		$eventMacro->set_scalar_var('scalar1', 8);
		$eventMacro->set_scalar_var('scalar2', 'undef');
		
		is ($eventMacro->{Macro_Runner}->parse_command( 'the value is $scalar1' ), 'the value is 8');
		is ($eventMacro->{Macro_Runner}->parse_command( 'the value is $scalar2' ), 'the value is ');
		
		is ($eventMacro->{Macro_Runner}->parse_command( $macro_keywords_character.'defined($scalar1)' ), 1);
		is ($eventMacro->{Macro_Runner}->parse_command( $macro_keywords_character.'defined($scalar2)' ), 0);
		
		$eventMacro->clear_array('array1');
		
		$eventMacro->set_array_var('array1', 0, 'undef');
		$eventMacro->set_array_var('array1', 1, 27);
		
		is ($eventMacro->{Macro_Runner}->parse_command( 'the value is $array1[0]' ), 'the value is ');
		is ($eventMacro->{Macro_Runner}->parse_command( 'the value is $array1[1]' ), 'the value is 27');
		
		is ($eventMacro->{Macro_Runner}->parse_command( $macro_keywords_character.'defined($array1[0])' ), 0);
		is ($eventMacro->{Macro_Runner}->parse_command( $macro_keywords_character.'defined($array1[1])' ), 1);
		
		$eventMacro->set_array_var('array1', 0, 35);
		$eventMacro->set_array_var('array1', 1, 'undef');
		
		is ($eventMacro->{Macro_Runner}->parse_command( 'the value is $array1[0]' ), 'the value is 35');
		is ($eventMacro->{Macro_Runner}->parse_command( 'the value is $array1[1]' ), 'the value is ');
		
		is ($eventMacro->{Macro_Runner}->parse_command( $macro_keywords_character.'defined($array1[0])' ), 1);
		is ($eventMacro->{Macro_Runner}->parse_command( $macro_keywords_character.'defined($array1[1])' ), 0);
		
		$eventMacro->clear_hash('hash1');
		
		$eventMacro->set_hash_var('hash1', 'key1', 'undef');
		$eventMacro->set_hash_var('hash1', 'key2', 12);
		
		is ($eventMacro->{Macro_Runner}->parse_command( 'the value is $hash1{key1}' ), 'the value is ');
		is ($eventMacro->{Macro_Runner}->parse_command( 'the value is $hash1{key2}' ), 'the value is 12');
		
		is ($eventMacro->{Macro_Runner}->parse_command( $macro_keywords_character.'defined($hash1{key1})' ), 0);
		is ($eventMacro->{Macro_Runner}->parse_command( $macro_keywords_character.'defined($hash1{key2})' ), 1);
		
		$eventMacro->set_hash_var('hash1', 'key1', 21);
		$eventMacro->set_hash_var('hash1', 'key2', 'undef');
		
		is ($eventMacro->{Macro_Runner}->parse_command( 'the value is $hash1{key1}' ), 'the value is 21');
		is ($eventMacro->{Macro_Runner}->parse_command( 'the value is $hash1{key2}' ), 'the value is ');
		
		is ($eventMacro->{Macro_Runner}->parse_command( $macro_keywords_character.'defined($hash1{key1})' ), 1);
		is ($eventMacro->{Macro_Runner}->parse_command( $macro_keywords_character.'defined($hash1{key2})' ), 0);
	}
}

1;
