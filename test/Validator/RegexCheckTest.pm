package Validator::RegexCheckTest;

use strict;
use warnings;

use Test::More;
use eventMacro::Data;
use eventMacro::Validator::RegexCheck;

sub start {
	subtest 'simple text' => sub {
		my $v = eventMacro::Validator::RegexCheck->new( '/oring/' );
		ok $v->parsed;
		ok (defined $v->{regex});
		is ($v->{regex}, 'oring');
		is ($v->{original_regex}, $v->{regex});
		ok (!$v->{case_insensitive});
		
		ok $v->validate( 'Poring' );
		ok !$v->validate( 'Drops' );
		ok $v->validate( 'poring' );
		ok $v->validate( 'poporing' );
		ok $v->validate( 'Poporing' );
		ok !$v->validate( 'Marin' );
		ok !$v->validate( 'Magmaring' );

		$v = eventMacro::Validator::RegexCheck->new( '/Poring/i' );
		ok $v->parsed;
		ok (defined $v->{regex});
		is ($v->{regex}, 'Poring');
		is ($v->{original_regex}, $v->{regex});
		ok ($v->{case_insensitive});
		
		ok $v->validate( 'Poring' );
		ok !$v->validate( 'Drops' );
		ok $v->validate( 'poring' );
		ok $v->validate( 'poporing' );
		ok $v->validate( 'Poporing' );
		ok !$v->validate( 'Marin' );
		ok !$v->validate( 'Magmaring' );
	};
	
	subtest 'regex code' => sub {
		my $v = eventMacro::Validator::RegexCheck->new( '/\d+\s\d+/' );
		ok $v->parsed;
		ok (defined $v->{regex});
		is ($v->{regex}, '\d+\s\d+');
		is ($v->{original_regex}, $v->{regex});
		ok (!$v->{case_insensitive});
		
		ok !$v->validate( 'Poring' );
		ok $v->validate( '100 50' );
		ok $v->validate( '15 20' );
		ok !$v->validate( '14 hey' );
		ok !$v->validate( 'hey you' );
		
		$v = eventMacro::Validator::RegexCheck->new( '/(Poring|Marin)/i' );
		ok $v->parsed;
		ok (defined $v->{regex});
		is ($v->{regex}, '(Poring|Marin)');
		is ($v->{original_regex}, $v->{regex});
		ok ($v->{case_insensitive});
		
		ok $v->validate( 'Poring' );
		ok !$v->validate( 'Drops' );
		ok $v->validate( 'poring' );
		ok $v->validate( 'poporing' );
		ok $v->validate( 'Poporing' );
		ok $v->validate( 'Marin' );
		ok $v->validate( 'Magmaring' );
		ok $v->validate( 'marin' );
	};
	
	subtest 'simple variable with text' => sub {
		my $v = eventMacro::Validator::RegexCheck->new( '/$foo{mob}/' );
		ok $v->parsed;
		ok (!defined $v->{regex});
		is ($v->{original_regex}, '$foo{mob}');
		ok (!$v->{case_insensitive});
		is_deeply ($v->{defined_var_list}, {'$foo{mob}' => 0});
		is ($v->{undefined_vars}, 1);
		
		ok !$v->validate( 'Poring' );
		ok !$v->validate( 'Drops' );
		ok !$v->validate( 'poring' );
		ok !$v->validate( 'poporing' );
		ok !$v->validate( 'Poporing' );
		ok !$v->validate( 'Marin' );
		ok !$v->validate( 'Magmaring' );
		
		$v->update_vars( '$foo{mob}', 'oring' );
		ok (defined $v->{regex});
		is ($v->{regex}, 'oring');
		is_deeply ($v->{defined_var_list}, {'$foo{mob}' => 1});
		is ($v->{undefined_vars}, 0);
		
		ok $v->validate( 'Poring' );
		ok !$v->validate( 'Drops' );
		ok $v->validate( 'poring' );
		ok $v->validate( 'poporing' );
		ok $v->validate( 'Poporing' );
		ok !$v->validate( 'Marin' );
		ok !$v->validate( 'Magmaring' );
	};
	
	subtest 'simple variable with regex code' => sub {
		my $v = eventMacro::Validator::RegexCheck->new( '/$foo[4]/i' );
		ok $v->parsed;
		ok (!defined $v->{regex});
		is ($v->{original_regex}, '$foo[4]');
		ok ($v->{case_insensitive});
		is_deeply ($v->{defined_var_list}, {'$foo[4]' => 0});
		is ($v->{undefined_vars}, 1);
		
		ok !$v->validate( 'Poring' );
		ok !$v->validate( 'Drops' );
		ok !$v->validate( 'poring' );
		ok !$v->validate( 'poporing' );
		ok !$v->validate( 'Poporing' );
		ok !$v->validate( 'Marin' );
		ok !$v->validate( 'Magmaring' );
		ok !$v->validate( 'marin' );
		
		$v->update_vars( '$foo[4]', '(Poring|Marin)' );
		ok (defined $v->{regex});
		is ($v->{regex}, '(Poring|Marin)');
		is ($v->{undefined_vars}, 0);
		is_deeply ($v->{defined_var_list}, {'$foo[4]' => 1});
		
		ok $v->validate( 'Poring' );
		ok !$v->validate( 'Drops' );
		ok $v->validate( 'poring' );
		ok $v->validate( 'poporing' );
		ok $v->validate( 'Poporing' );
		ok $v->validate( 'Marin' );
		ok $v->validate( 'Magmaring' );
		ok $v->validate( 'marin' );
	};
	
	subtest 'multiple variable with text' => sub {
		my $v = eventMacro::Validator::RegexCheck->new( '/$foo$bar $foobar bot/i' );
		ok $v->parsed;
		ok (!defined $v->{regex});
		is ($v->{original_regex}, '$foo$bar $foobar bot');
		ok ($v->{case_insensitive});
		is_deeply ($v->{defined_var_list}, {'$foo' => 0, '$bar' => 0, '$foobar' => 0});
		is ($v->{undefined_vars}, 3);
		ok !$v->validate( 'hey there you bot' );
		ok !$v->validate( 'hello you bot' );
		ok !$v->validate( 'I will kill you bot' );
		
		$v->update_vars( '$foo', 'hey' );
		ok (!defined $v->{regex});
		is_deeply ($v->{defined_var_list}, {'$foo' => 1, '$bar' => 0, '$foobar' => 0});
		is ($v->{undefined_vars}, 2);
		
		ok !$v->validate( 'hey there you bot' );
		ok !$v->validate( 'hello you bot' );
		ok !$v->validate( 'I will kill you bot' );
		
		$v->update_vars( '$bar', ' there' );
		ok (!defined $v->{regex});
		is_deeply ($v->{defined_var_list}, {'$foo' => 1, '$bar' => 1, '$foobar' => 0});
		is ($v->{undefined_vars}, 1);
		
		$v->update_vars( '$foobar', 'you' );
		ok (defined $v->{regex});
		is ($v->{undefined_vars}, 0);
		is_deeply ($v->{defined_var_list}, {'$foo' => 1, '$bar' => 1, '$foobar' => 1});
		
		ok $v->validate( 'hey there you bot' );
		ok !$v->validate( 'hello you bot' );
		ok !$v->validate( 'I will kill you bot' );
		
		$v->update_vars( '$foo', 'hell' );
		ok (defined $v->{regex});
		is ($v->{undefined_vars}, 0);
		is_deeply ($v->{defined_var_list}, {'$foo' => 1, '$bar' => 1, '$foobar' => 1});
		
		ok !$v->validate( 'hey there you bot' );
		ok !$v->validate( 'hello you bot' );
		ok !$v->validate( 'I will kill you bot' );
		
		$v->update_vars( '$bar', 'o' );
		ok (defined $v->{regex});
		is ($v->{undefined_vars}, 0);
		is_deeply ($v->{defined_var_list}, {'$foo' => 1, '$bar' => 1, '$foobar' => 1});
		
		$v->update_vars( '$foobar', 'you' );
		ok (defined $v->{regex});
		is ($v->{undefined_vars}, 0);
		is_deeply ($v->{defined_var_list}, {'$foo' => 1, '$bar' => 1, '$foobar' => 1});
		
		ok !$v->validate( 'hey there you bot' );
		ok $v->validate( 'hello you bot' );
		ok !$v->validate( 'I will kill you bot' );
	};
	
	subtest 'repeated var' => sub {
		my $v = eventMacro::Validator::RegexCheck->new( '/$foo is $foo, also $foo is big/i' );
		ok $v->parsed;
		ok (!defined $v->{regex});
		is ($v->{original_regex}, '$foo is $foo, also $foo is big');
		ok ($v->{case_insensitive});
		is_deeply ($v->{defined_var_list}, {'$foo' => 0});
		is ($v->{undefined_vars}, 1);
		ok !$v->validate( '1 is 1, also 1 is big' );
		ok !$v->validate( '5 is 5, also 5 is big' );
		ok !$v->validate( '6 is 6, also 6 is big' );
		ok !$v->validate( 'he is he, also he is big' );
		
		$v->update_vars( '$foo', '5' );
		ok (defined $v->{regex});
		is_deeply ($v->{defined_var_list}, {'$foo' => 1});
		is ($v->{undefined_vars}, 0);
		
		ok !$v->validate( '1 is 1, also 1 is big' );
		ok $v->validate( '5 is 5, also 5 is big' );
		ok !$v->validate( '6 is 6, also 6 is big' );
		ok !$v->validate( 'he is he, also he is big' );
		
		$v->update_vars( '$foo', '6' );
		ok (defined $v->{regex});
		is_deeply ($v->{defined_var_list}, {'$foo' => 1});
		is ($v->{undefined_vars}, 0);
		
		ok !$v->validate( '1 is 1, also 1 is big' );
		ok !$v->validate( '5 is 5, also 5 is big' );
		ok $v->validate( '6 is 6, also 6 is big' );
		ok !$v->validate( 'he is he, also he is big' );
		
		$v->update_vars( '$foo', 'he' );
		ok (defined $v->{regex});
		is_deeply ($v->{defined_var_list}, {'$foo' => 1});
		is ($v->{undefined_vars}, 0);
		
		ok !$v->validate( '1 is 1, also 1 is big' );
		ok !$v->validate( '5 is 5, also 5 is big' );
		ok !$v->validate( '6 is 6, also 6 is big' );
		ok $v->validate( 'he is he, also he is big' );
	};
	
	subtest 'multiple variable with regex code' => sub {
		my $v = eventMacro::Validator::RegexCheck->new( '/$foo$bar$foobar/i' );
		ok $v->parsed;
		ok (!defined $v->{regex});
		is ($v->{original_regex}, '$foo$bar$foobar');
		ok ($v->{case_insensitive});
		is_deeply ($v->{defined_var_list}, {'$foo' => 0, '$bar' => 0, '$foobar' => 0});
		is ($v->{undefined_vars}, 3);
		
		ok !$v->validate( 'poring' );
		ok !$v->validate( 'poporing' );
		ok !$v->validate( 'drops' );
		ok !$v->validate( 'marin' );
		
		$v->update_vars( '$foo', '(oring' );
		ok (!defined $v->{regex});
		is ($v->{undefined_vars}, 2);
		is_deeply ($v->{defined_var_list}, {'$foo' => 1, '$bar' => 0, '$foobar' => 0});
		
		ok !$v->validate( 'poring' );
		ok !$v->validate( 'poporing' );
		ok !$v->validate( 'drops' );
		ok !$v->validate( 'marin' );
		
		$v->update_vars( '$bar', '|arin|' );
		ok (!defined $v->{regex});
		is ($v->{undefined_vars}, 1);
		is_deeply ($v->{defined_var_list}, {'$foo' => 1, '$bar' => 1, '$foobar' => 0});
		
		$v->update_vars( '$foobar', 'rops)' );
		ok (defined $v->{regex});
		is ($v->{undefined_vars}, 0);
		is_deeply ($v->{defined_var_list}, {'$foo' => 1, '$bar' => 1, '$foobar' => 1});
		
		ok $v->validate( 'poring' );
		ok $v->validate( 'poporing' );
		ok $v->validate( 'drops' );
		ok $v->validate( 'marin' );
		
		$v->update_vars( '$foo', '(magma' );
		ok (defined $v->{regex});
		is ($v->{undefined_vars}, 0);
		is_deeply ($v->{defined_var_list}, {'$foo' => 1, '$bar' => 1, '$foobar' => 1});
		
		ok !$v->validate( 'poring' );
		ok !$v->validate( 'poporing' );
		ok $v->validate( 'drops' );
		ok $v->validate( 'marin' );
		
		$v->update_vars( '$bar', '|oring|' );
		ok (defined $v->{regex});
		is ($v->{undefined_vars}, 0);
		is_deeply ($v->{defined_var_list}, {'$foo' => 1, '$bar' => 1, '$foobar' => 1});
		
		ok $v->validate( 'poring' );
		ok $v->validate( 'poporing' );
		ok $v->validate( 'drops' );
		ok !$v->validate( 'marin' );
	};
	
	subtest 'simple nested variable with text' => sub {
		my $v = eventMacro::Validator::RegexCheck->new( '/$foo{$bar}/' );
		ok $v->parsed;
		ok (!defined $v->{regex});
		is ($v->{original_regex}, '$foo{$bar}');
		ok (!$v->{case_insensitive});
		is_deeply ($v->{defined_var_list}, {'$foo{$bar}' => 0});
		is ($v->{undefined_vars}, 1);
		
		ok !$v->validate( 'Poring' );
		ok !$v->validate( 'Drops' );
		ok !$v->validate( 'poring' );
		ok !$v->validate( 'poporing' );
		ok !$v->validate( 'Poporing' );
		ok !$v->validate( 'Marin' );
		ok !$v->validate( 'Magmaring' );
		
		$v->update_vars( '$foo{$bar}', 'oring' );
		ok (defined $v->{regex});
		is ($v->{regex}, 'oring');
		is_deeply ($v->{defined_var_list}, {'$foo{$bar}' => 1});
		is ($v->{undefined_vars}, 0);
		
		ok $v->validate( 'Poring' );
		ok !$v->validate( 'Drops' );
		ok $v->validate( 'poring' );
		ok $v->validate( 'poporing' );
		ok $v->validate( 'Poporing' );
		ok !$v->validate( 'Marin' );
		ok !$v->validate( 'Magmaring' );
	};
	
	subtest 'repeated nested var' => sub {
		my $v = eventMacro::Validator::RegexCheck->new( '/$foo[$baz{$quz{mob}}] is $foo[$baz{$quz{mob}}], also $foo[$baz{$quz{mob}}] is big/i' );
		ok $v->parsed;
		ok (!defined $v->{regex});
		is ($v->{original_regex}, '$foo[$baz{$quz{mob}}] is $foo[$baz{$quz{mob}}], also $foo[$baz{$quz{mob}}] is big');
		ok ($v->{case_insensitive});
		is_deeply ($v->{defined_var_list}, {'$foo[$baz{$quz{mob}}]' => 0});
		is ($v->{undefined_vars}, 1);
		ok !$v->validate( '1 is 1, also 1 is big' );
		ok !$v->validate( '5 is 5, also 5 is big' );
		ok !$v->validate( '6 is 6, also 6 is big' );
		ok !$v->validate( 'he is he, also he is big' );
		
		$v->update_vars( '$foo[$baz{$quz{mob}}]', '5' );
		ok (defined $v->{regex});
		is_deeply ($v->{defined_var_list}, {'$foo[$baz{$quz{mob}}]' => 1});
		is ($v->{undefined_vars}, 0);
		
		ok !$v->validate( '1 is 1, also 1 is big' );
		ok $v->validate( '5 is 5, also 5 is big' );
		ok !$v->validate( '6 is 6, also 6 is big' );
		ok !$v->validate( 'he is he, also he is big' );
		
		$v->update_vars( '$foo[$baz{$quz{mob}}]', '6' );
		ok (defined $v->{regex});
		is_deeply ($v->{defined_var_list}, {'$foo[$baz{$quz{mob}}]' => 1});
		is ($v->{undefined_vars}, 0);
		
		ok !$v->validate( '1 is 1, also 1 is big' );
		ok !$v->validate( '5 is 5, also 5 is big' );
		ok $v->validate( '6 is 6, also 6 is big' );
		ok !$v->validate( 'he is he, also he is big' );
		
		$v->update_vars( '$foo[$baz{$quz{mob}}]', 'he' );
		ok (defined $v->{regex});
		is_deeply ($v->{defined_var_list}, {'$foo[$baz{$quz{mob}}]' => 1});
		is ($v->{undefined_vars}, 0);
		
		ok !$v->validate( '1 is 1, also 1 is big' );
		ok !$v->validate( '5 is 5, also 5 is big' );
		ok !$v->validate( '6 is 6, also 6 is big' );
		ok $v->validate( 'he is he, also he is big' );
	};
	
	subtest 'multiple nested variable with regex code' => sub {
		my $v = eventMacro::Validator::RegexCheck->new( '/$foo[$bar[$baz[$quz]]]$bar[$scalar]$foobar{$baz}/i' );
		ok $v->parsed;
		ok (!defined $v->{regex});
		is ($v->{original_regex}, '$foo[$bar[$baz[$quz]]]$bar[$scalar]$foobar{$baz}');
		ok ($v->{case_insensitive});
		is_deeply ($v->{defined_var_list}, {'$foo[$bar[$baz[$quz]]]' => 0, '$bar[$scalar]' => 0, '$foobar{$baz}' => 0});
		is ($v->{undefined_vars}, 3);
		
		ok !$v->validate( 'poring' );
		ok !$v->validate( 'poporing' );
		ok !$v->validate( 'drops' );
		ok !$v->validate( 'marin' );
		
		$v->update_vars( '$foo[$bar[$baz[$quz]]]', '(oring' );
		ok (!defined $v->{regex});
		is ($v->{undefined_vars}, 2);
		is_deeply ($v->{defined_var_list}, {'$foo[$bar[$baz[$quz]]]' => 1, '$bar[$scalar]' => 0, '$foobar{$baz}' => 0});
		
		ok !$v->validate( 'poring' );
		ok !$v->validate( 'poporing' );
		ok !$v->validate( 'drops' );
		ok !$v->validate( 'marin' );
		
		$v->update_vars( '$bar[$scalar]', '|arin|' );
		ok (!defined $v->{regex});
		is ($v->{undefined_vars}, 1);
		is_deeply ($v->{defined_var_list}, {'$foo[$bar[$baz[$quz]]]' => 1, '$bar[$scalar]' => 1, '$foobar{$baz}' => 0});
		
		$v->update_vars( '$foobar{$baz}', 'rops)' );
		ok (defined $v->{regex});
		is ($v->{undefined_vars}, 0);
		is_deeply ($v->{defined_var_list}, {'$foo[$bar[$baz[$quz]]]' => 1, '$bar[$scalar]' => 1, '$foobar{$baz}' => 1});
		
		ok $v->validate( 'poring' );
		ok $v->validate( 'poporing' );
		ok $v->validate( 'drops' );
		ok $v->validate( 'marin' );
		
		$v->update_vars( '$foo[$bar[$baz[$quz]]]', '(magma' );
		ok (defined $v->{regex});
		is ($v->{undefined_vars}, 0);
		is_deeply ($v->{defined_var_list}, {'$foo[$bar[$baz[$quz]]]' => 1, '$bar[$scalar]' => 1, '$foobar{$baz}' => 1});
		
		ok !$v->validate( 'poring' );
		ok !$v->validate( 'poporing' );
		ok $v->validate( 'drops' );
		ok $v->validate( 'marin' );
		
		$v->update_vars( '$bar[$scalar]', '|oring|' );
		ok (defined $v->{regex});
		is ($v->{undefined_vars}, 0);
		is_deeply ($v->{defined_var_list}, {'$foo[$bar[$baz[$quz]]]' => 1, '$bar[$scalar]' => 1, '$foobar{$baz}' => 1});
		
		ok $v->validate( 'poring' );
		ok $v->validate( 'poporing' );
		ok $v->validate( 'drops' );
		ok !$v->validate( 'marin' );
	};
}

1;
