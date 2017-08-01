package GlobalVarRegexTest;

use strict;
use warnings;

use Test::More;
use eventMacro::Data;

sub start {
	subtest 'scalar' => sub {
		my $var = '$foo';
		ok ($var =~ /^$general_variable_qr$/);
		ok ($var =~ /^$scalar_variable_qr$/);
		ok !($var =~ /^$array_variable_qr$/);
		ok !($var =~ /^$accessed_array_variable_qr$/);
		ok !($var =~ /^$hash_variable_qr$/);
		ok !($var =~ /^$accessed_hash_variable_qr$/);
	};
	
	subtest 'array' => sub {
		my $var = '@bar';
		ok ($var =~ /^$general_variable_qr$/);
		ok !($var =~ /^$scalar_variable_qr$/);
		ok ($var =~ /^$array_variable_qr$/);
		ok !($var =~ /^$accessed_array_variable_qr$/);
		ok !($var =~ /^$hash_variable_qr$/);
		ok !($var =~ /^$accessed_hash_variable_qr$/);
	};
	
	subtest 'accessed array' => sub {
		my $var = '$foobar[10]';
		ok ($var =~ /^$general_variable_qr$/);
		ok !($var =~ /^$scalar_variable_qr$/);
		ok !($var =~ /^$array_variable_qr$/);
		ok ($var =~ /^$accessed_array_variable_qr$/);
		ok !($var =~ /^$hash_variable_qr$/);
		ok !($var =~ /^$accessed_hash_variable_qr$/);
	};
	
	subtest 'hash' => sub {
		my $var = '%barfoo';
		ok ($var =~ /^$general_variable_qr$/);
		ok !($var =~ /^$scalar_variable_qr$/);
		ok !($var =~ /^$array_variable_qr$/);
		ok !($var =~ /^$accessed_array_variable_qr$/);
		ok ($var =~ /^$hash_variable_qr$/);
		ok !($var =~ /^$accessed_hash_variable_qr$/);
	};
	
	subtest 'accessed hash' => sub {
		my $var = '$baz{qux}';
		ok ($var =~ /^$general_variable_qr$/);
		ok !($var =~ /^$scalar_variable_qr$/);
		ok !($var =~ /^$array_variable_qr$/);
		ok !($var =~ /^$accessed_array_variable_qr$/);
		ok !($var =~ /^$hash_variable_qr$/);
		ok ($var =~ /^$accessed_hash_variable_qr$/);
	};
	
	subtest 'bug test' => sub {
		my $var = '%bar{hey}';
		ok !($var =~ /^$general_variable_qr$/);
		ok !($var =~ /^$scalar_variable_qr$/);
		ok !($var =~ /^$array_variable_qr$/);
		ok !($var =~ /^$accessed_array_variable_qr$/);
		ok !($var =~ /^$hash_variable_qr$/);
		ok !($var =~ /^$accessed_hash_variable_qr$/);
		
		$var = '%bar[10]';
		ok !($var =~ /^$general_variable_qr$/);
		ok !($var =~ /^$scalar_variable_qr$/);
		ok !($var =~ /^$array_variable_qr$/);
		ok !($var =~ /^$accessed_array_variable_qr$/);
		ok !($var =~ /^$hash_variable_qr$/);
		ok !($var =~ /^$accessed_hash_variable_qr$/);
		
		$var = '@bar[10]';
		ok !($var =~ /^$general_variable_qr$/);
		ok !($var =~ /^$scalar_variable_qr$/);
		ok !($var =~ /^$array_variable_qr$/);
		ok !($var =~ /^$accessed_array_variable_qr$/);
		ok !($var =~ /^$hash_variable_qr$/);
		ok !($var =~ /^$accessed_hash_variable_qr$/);
		
		$var = '@bar{foo}';
		ok !($var =~ /^$general_variable_qr$/);
		ok !($var =~ /^$scalar_variable_qr$/);
		ok !($var =~ /^$array_variable_qr$/);
		ok !($var =~ /^$accessed_array_variable_qr$/);
		ok !($var =~ /^$hash_variable_qr$/);
		ok !($var =~ /^$accessed_hash_variable_qr$/);
		
		$var = '$bar[foo]';
		ok !($var =~ /^$general_variable_qr$/);
		ok !($var =~ /^$scalar_variable_qr$/);
		ok !($var =~ /^$array_variable_qr$/);
		ok !($var =~ /^$accessed_array_variable_qr$/);
		ok !($var =~ /^$hash_variable_qr$/);
		ok !($var =~ /^$accessed_hash_variable_qr$/);
		
	};
}

1;
