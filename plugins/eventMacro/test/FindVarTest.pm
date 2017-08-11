package FindVarTest;

use strict;
use warnings;

use Test::More;
use eventMacro::Data;
use eventMacro::Utilities qw(find_variable);

sub start {
	subtest 'scalar' => sub {
		my $var = find_variable('$foo');
		ok (defined $var);
		ok (exists $var->{display_name});
		ok (exists $var->{real_name});
		ok (exists $var->{type});
		ok (!exists $var->{complement});
		ok ($var->{type} eq 'scalar');
		is_deeply($var, {display_name => '$foo', type => 'scalar', real_name => 'foo'});
	};
	
	subtest 'array' => sub {
		my $var = find_variable('@bar');
		ok (defined $var);
		ok (exists $var->{display_name});
		ok (exists $var->{real_name});
		ok (exists $var->{type});
		ok (!exists $var->{complement});
		ok ($var->{type} eq 'array');
		is_deeply($var, {display_name => '@bar', type => 'array', real_name => 'bar'});
	};
	
	subtest 'accessed array' => sub {
		my $var = find_variable('$foobar[10]');
		ok (defined $var);
		ok (exists $var->{display_name});
		ok (exists $var->{real_name});
		ok (exists $var->{type});
		ok (exists $var->{complement});
		ok ($var->{type} eq 'accessed_array');
		is_deeply($var, {display_name => '$foobar[10]', type => 'accessed_array', real_name => 'foobar', complement => 10});
	};
	
	subtest 'hash' => sub {
		my $var = find_variable('%barfoo');
		ok (defined $var);
		ok (exists $var->{display_name});
		ok (exists $var->{real_name});
		ok (exists $var->{type});
		ok (!exists $var->{complement});
		ok ($var->{type} eq 'hash');
		is_deeply($var, {display_name => '%barfoo', type => 'hash', real_name => 'barfoo'});
	};
	
	subtest 'accessed hash' => sub {
		my $var = find_variable('$baz{qux}');
		ok (defined $var);
		ok (exists $var->{display_name});
		ok (exists $var->{real_name});
		ok (exists $var->{type});
		ok (exists $var->{complement});
		ok ($var->{type} eq 'accessed_hash');
		is_deeply($var, {display_name => '$baz{qux}', type => 'accessed_hash', real_name => 'baz', complement => 'qux'});
	};
	
	subtest 'nested vars' => sub {
		my $var = find_variable('$hash{$scalar}');
		ok (defined $var);
		ok (exists $var->{display_name});
		ok (exists $var->{real_name});
		ok (exists $var->{type});
		ok (exists $var->{complement});
		ok ($var->{type} eq 'accessed_hash');
		is_deeply($var, {display_name => '$hash{$scalar}', type => 'accessed_hash', real_name => 'hash', complement => '$scalar'});
		
		$var = find_variable('$array[$hash2{$array2[$scalar2]}]');
		ok (defined $var);
		ok (exists $var->{display_name});
		ok (exists $var->{real_name});
		ok (exists $var->{type});
		ok (exists $var->{complement});
		ok ($var->{type} eq 'accessed_array');
		is_deeply($var, {display_name => '$array[$hash2{$array2[$scalar2]}]', type => 'accessed_array', real_name => 'array', complement => '$hash2{$array2[$scalar2]}'});
	};
	
	subtest 'false vars' => sub {
		ok (!defined find_variable('hey'));
		ok (!defined find_variable('this is a poring'));
		ok (!defined find_variable('\$var'));
		ok (!defined find_variable('$var is cool'));
		ok (!defined find_variable('$array[key]'));
		ok (!defined find_variable('$hash{}'));
		ok (!defined find_variable('$array[]'));
		ok (!defined find_variable('$var_name'));
		ok (!defined find_variable('$array[$array[hi]]'));
	};
}

1;
