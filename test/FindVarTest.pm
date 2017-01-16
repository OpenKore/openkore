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
		ok (!exists $var->{index});
		ok (!exists $var->{key});
		ok ($var->{type} eq 'scalar');
		is_deeply($var, {display_name => '$foo', type => 'scalar', real_name => 'foo'});
	};
	
	subtest 'array' => sub {
		my $var = find_variable('@bar');
		ok (defined $var);
		ok (exists $var->{display_name});
		ok (exists $var->{real_name});
		ok (exists $var->{type});
		ok (!exists $var->{index});
		ok (!exists $var->{key});
		ok ($var->{type} eq 'array');
		is_deeply($var, {display_name => '@bar', type => 'array', real_name => 'bar'});
	};
	
	subtest 'accessed array' => sub {
		my $var = find_variable('$foobar[10]');
		ok (defined $var);
		ok (exists $var->{display_name});
		ok (exists $var->{real_name});
		ok (exists $var->{type});
		ok (exists $var->{index});
		ok (!exists $var->{key});
		ok ($var->{type} eq 'accessed_array');
		is_deeply($var, {display_name => '$foobar[10]', type => 'accessed_array', real_name => 'foobar', index => 10});
	};
	
	subtest 'hash' => sub {
		my $var = find_variable('%barfoo');
		ok (defined $var);
		ok (exists $var->{display_name});
		ok (exists $var->{real_name});
		ok (exists $var->{type});
		ok (!exists $var->{index});
		ok (!exists $var->{key});
		ok ($var->{type} eq 'hash');
		is_deeply($var, {display_name => '%barfoo', type => 'hash', real_name => 'barfoo'});
	};
	
	subtest 'accessed hash' => sub {
		my $var = find_variable('$baz{qux}');
		ok (defined $var);
		ok (exists $var->{display_name});
		ok (exists $var->{real_name});
		ok (exists $var->{type});
		ok (!exists $var->{index});
		ok (exists $var->{key});
		ok ($var->{type} eq 'accessed_hash');
		is_deeply($var, {display_name => '$baz{qux}', type => 'accessed_hash', real_name => 'baz', key => 'qux'});
	};
}

1;
