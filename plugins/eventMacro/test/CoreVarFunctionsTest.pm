package CoreVarFunctionsTest;

use strict;
use warnings;
use FindBin qw($RealBin);
use lib "$RealBin";

use Test::More;
use eventMacro::Data;
use eventMacro::Core;

sub start {
	my $eventMacro = eventMacro::Core->new( "$RealBin/textfiles/empty.txt" );
	
	subtest 'scalar' => sub {
		is_deeply($eventMacro->{Scalar_Variable_List_Hash}, {});
		
		ok (!defined $eventMacro->get_scalar_var('scalar1'));
		is ($eventMacro->is_scalar_var_defined('scalar1'), 0);
		
		ok (!defined $eventMacro->get_scalar_var('scalar2'));
		is ($eventMacro->is_scalar_var_defined('scalar2'), 0);
		
		$eventMacro->set_scalar_var('scalar1', 15);
		ok (defined $eventMacro->get_scalar_var('scalar1'));
		is ($eventMacro->is_scalar_var_defined('scalar1'), 1);
		is ($eventMacro->get_scalar_var('scalar1'), 15);
		
		ok (!defined $eventMacro->get_scalar_var('scalar2'));
		is ($eventMacro->is_scalar_var_defined('scalar2'), 0);
		
		is_deeply($eventMacro->{Scalar_Variable_List_Hash}, {'scalar1' => 15});
		
		$eventMacro->set_scalar_var('scalar2', 10);
		ok (defined $eventMacro->get_scalar_var('scalar1'));
		is ($eventMacro->is_scalar_var_defined('scalar1'), 1);
		is ($eventMacro->get_scalar_var('scalar1'), 15);
		
		ok (defined $eventMacro->get_scalar_var('scalar2'));
		is ($eventMacro->is_scalar_var_defined('scalar2'), 1);
		is ($eventMacro->get_scalar_var('scalar2'), 10);
		
		is_deeply($eventMacro->{Scalar_Variable_List_Hash}, {'scalar1' => 15, 'scalar2' => 10});
		
		$eventMacro->set_scalar_var('scalar1', 73);
		ok (defined $eventMacro->get_scalar_var('scalar1'));
		is ($eventMacro->is_scalar_var_defined('scalar1'), 1);
		is ($eventMacro->get_scalar_var('scalar1'), 73);
		
		ok (defined $eventMacro->get_scalar_var('scalar2'));
		is ($eventMacro->is_scalar_var_defined('scalar2'), 1);
		is ($eventMacro->get_scalar_var('scalar2'), 10);
		
		is_deeply($eventMacro->{Scalar_Variable_List_Hash}, {'scalar1' => 73, 'scalar2' => 10});
		
		$eventMacro->set_scalar_var('scalar2', 'undef');
		ok (defined $eventMacro->get_scalar_var('scalar1'));
		is ($eventMacro->is_scalar_var_defined('scalar1'), 1);
		is ($eventMacro->get_scalar_var('scalar1'), 73);
		
		ok (!defined $eventMacro->get_scalar_var('scalar2'));
		is ($eventMacro->is_scalar_var_defined('scalar2'), 0);
		
		is_deeply($eventMacro->{Scalar_Variable_List_Hash}, {'scalar1' => 73});
		
		$eventMacro->set_scalar_var('scalar1', 'undef');
		ok (!defined $eventMacro->get_scalar_var('scalar1'));
		is ($eventMacro->is_scalar_var_defined('scalar1'), 0);
		
		ok (!defined $eventMacro->get_scalar_var('scalar2'));
		is ($eventMacro->is_scalar_var_defined('scalar2'), 0);
		
		is_deeply($eventMacro->{Scalar_Variable_List_Hash}, {});
		
		$eventMacro->set_scalar_var('scalar2', 5);
		ok (!defined $eventMacro->get_scalar_var('scalar1'));
		is ($eventMacro->is_scalar_var_defined('scalar1'), 0);
		
		ok (defined $eventMacro->get_scalar_var('scalar2'));
		is ($eventMacro->is_scalar_var_defined('scalar2'), 1);
		is ($eventMacro->get_scalar_var('scalar2'), 5);
		
		is_deeply($eventMacro->{Scalar_Variable_List_Hash}, {'scalar2' => 5});
	};
	
	subtest 'array' => sub {
		is_deeply($eventMacro->{Array_Variable_List_Hash}, {});
		
		is ($eventMacro->get_array_size('array1'), 0);
		is ($eventMacro->get_array_size('array2'), 0);
		
		$eventMacro->set_full_array('array1', ['Poring', '15', 'undef', 'Drops', 'Magmaring']);
		is ($eventMacro->get_array_size('array1'), 5);
		is ($eventMacro->get_array_size('array2'), 0);
		
		is ($eventMacro->is_array_var_defined('array1', 0), 1);
		is ($eventMacro->get_array_var('array1', 0), 'Poring');
		
		is ($eventMacro->is_array_var_defined('array1', 1), 1);
		is ($eventMacro->get_array_var('array1', 1), 15);
		
		is ($eventMacro->is_array_var_defined('array1', 2), 0);
		ok (!defined $eventMacro->get_array_var('array1', 2));
		
		is ($eventMacro->is_array_var_defined('array1', 3), 1);
		is ($eventMacro->get_array_var('array1', 3), 'Drops');
		
		is ($eventMacro->is_array_var_defined('array1', 4), 1);
		is ($eventMacro->get_array_var('array1', 4), 'Magmaring');
		
		is ($eventMacro->is_array_var_defined('array1', 5), 0);
		ok (!defined $eventMacro->get_array_var('array1', 5));
		
		is_deeply($eventMacro->{Array_Variable_List_Hash}, {'array1' => ['Poring', '15', undef, 'Drops', 'Magmaring']});
		
		$eventMacro->set_full_array('array2', ['Angeling', 'Deviling', 'Archangeling', 'undef', 'Mastering', 'undef', 'King Poring']);
		is ($eventMacro->get_array_size('array1'), 5);
		is ($eventMacro->get_array_size('array2'), 7);
		
		is ($eventMacro->is_array_var_defined('array2', 0), 1);
		is ($eventMacro->get_array_var('array2', 0), 'Angeling');
		
		is ($eventMacro->is_array_var_defined('array2', 1), 1);
		is ($eventMacro->get_array_var('array2', 1), 'Deviling');
		
		is ($eventMacro->is_array_var_defined('array2', 2), 1);
		is ($eventMacro->get_array_var('array2', 2), 'Archangeling');
		
		is ($eventMacro->is_array_var_defined('array2', 3), 0);
		ok (!defined $eventMacro->get_array_var('array2', 3));
		
		is ($eventMacro->is_array_var_defined('array2', 4), 1);
		is ($eventMacro->get_array_var('array2', 4), 'Mastering');
		
		is ($eventMacro->is_array_var_defined('array2', 5), 0);
		ok (!defined $eventMacro->get_array_var('array2', 5));
		
		is ($eventMacro->is_array_var_defined('array2', 6), 1);
		is ($eventMacro->get_array_var('array2', 6), 'King Poring');
		
		is ($eventMacro->is_array_var_defined('array2', 7), 0);
		ok (!defined $eventMacro->get_array_var('array2', 7));
		
		is_deeply($eventMacro->{Array_Variable_List_Hash}, {'array1' => ['Poring', '15', undef, 'Drops', 'Magmaring'], 'array2' => ['Angeling', 'Deviling', 'Archangeling', undef, 'Mastering', undef, 'King Poring']});
		
		$eventMacro->clear_array('array1');
		is ($eventMacro->get_array_size('array1'), 0);
		is ($eventMacro->get_array_size('array2'), 7);
		is_deeply($eventMacro->{Array_Variable_List_Hash}, {'array2' => ['Angeling', 'Deviling', 'Archangeling', undef, 'Mastering', undef, 'King Poring']});
		
		$eventMacro->clear_array('array2');
		is ($eventMacro->get_array_size('array1'), 0);
		is ($eventMacro->get_array_size('array2'), 0);
		is_deeply($eventMacro->{Array_Variable_List_Hash}, {});
		
		
		$eventMacro->set_array_var('array1', 1, 10);
		is ($eventMacro->get_array_size('array1'), 2);
		is ($eventMacro->get_array_size('array2'), 0);
		
		is ($eventMacro->is_array_var_defined('array1', 0), 0);
		ok (!defined $eventMacro->get_array_var('array1', 0));
		
		is ($eventMacro->is_array_var_defined('array1', 1), 1);
		is ($eventMacro->get_array_var('array1', 1), 10);
		
		is ($eventMacro->is_array_var_defined('array1', 2), 0);
		ok (!defined $eventMacro->get_array_var('array1', 2));
		
		is_deeply($eventMacro->{Array_Variable_List_Hash}, {'array1' => [undef, 10]});
		
		$eventMacro->set_array_var('array1', 0, 'Card');
		is ($eventMacro->get_array_size('array1'), 2);
		is ($eventMacro->get_array_size('array2'), 0);
		
		is ($eventMacro->is_array_var_defined('array1', 0), 1);
		is ($eventMacro->get_array_var('array1', 0), 'Card');
		
		is ($eventMacro->is_array_var_defined('array1', 1), 1);
		is ($eventMacro->get_array_var('array1', 1), 10);
		
		is ($eventMacro->is_array_var_defined('array1', 2), 0);
		ok (!defined $eventMacro->get_array_var('array1', 2));
		
		is_deeply($eventMacro->{Array_Variable_List_Hash}, {'array1' => ['Card', 10]});
		
		$eventMacro->set_array_var('array2', 2, 'Drop');
		is ($eventMacro->get_array_size('array1'), 2);
		is ($eventMacro->get_array_size('array2'), 3);
		
		is ($eventMacro->is_array_var_defined('array2', 0), 0);
		ok (!defined $eventMacro->get_array_var('array2', 0));
		
		is ($eventMacro->is_array_var_defined('array2', 1), 0);
		ok (!defined $eventMacro->get_array_var('array2', 1));
		
		is ($eventMacro->is_array_var_defined('array2', 2), 1);
		is ($eventMacro->get_array_var('array2', 2), 'Drop');
		
		is_deeply($eventMacro->{Array_Variable_List_Hash}, {'array1' => ['Card', 10], 'array2' => [undef, undef, 'Drop']});
		
		my $new_size;
		
		$new_size = $eventMacro->push_array('array1', 'Equip');
		is_deeply($eventMacro->{Array_Variable_List_Hash}, {'array1' => ['Card', 10, 'Equip'], 'array2' => [undef, undef, 'Drop']});
		is ($eventMacro->get_array_size('array1'), 3);
		is ($eventMacro->get_array_size('array2'), 3);
		is ($eventMacro->get_array_size('array1'), $new_size);
		
		$new_size = $eventMacro->push_array('array1', 'undef');
		is_deeply($eventMacro->{Array_Variable_List_Hash}, {'array1' => ['Card', 10, 'Equip', undef], 'array2' => [undef, undef, 'Drop']});
		is ($eventMacro->get_array_size('array1'), 4);
		is ($eventMacro->get_array_size('array2'), 3);
		is ($eventMacro->get_array_size('array1'), $new_size);
		
		$new_size = $eventMacro->push_array('array1', 'Weapon');
		is_deeply($eventMacro->{Array_Variable_List_Hash}, {'array1' => ['Card', 10, 'Equip', undef, 'Weapon'], 'array2' => [undef, undef, 'Drop']});
		is ($eventMacro->get_array_size('array1'), 5);
		is ($eventMacro->get_array_size('array2'), 3);
		is ($eventMacro->get_array_size('array1'), $new_size);
		
		$new_size = $eventMacro->unshift_array('array1', 'Shield');
		is_deeply($eventMacro->{Array_Variable_List_Hash}, {'array1' => ['Shield', 'Card', 10, 'Equip', undef, 'Weapon'], 'array2' => [undef, undef, 'Drop']});
		is ($eventMacro->get_array_size('array1'), 6);
		is ($eventMacro->get_array_size('array2'), 3);
		is ($eventMacro->get_array_size('array1'), $new_size);
		
		$new_size = $eventMacro->unshift_array('array1', 'undef');
		is_deeply($eventMacro->{Array_Variable_List_Hash}, {'array1' => [undef, 'Shield', 'Card', 10, 'Equip', undef, 'Weapon'], 'array2' => [undef, undef, 'Drop']});
		is ($eventMacro->get_array_size('array1'), 7);
		is ($eventMacro->get_array_size('array2'), 3);
		is ($eventMacro->get_array_size('array1'), $new_size);
		
		$new_size = $eventMacro->unshift_array('array1', 'Staff');
		is_deeply($eventMacro->{Array_Variable_List_Hash}, {'array1' => ['Staff', undef, 'Shield', 'Card', 10, 'Equip', undef, 'Weapon'], 'array2' => [undef, undef, 'Drop']});
		is ($eventMacro->get_array_size('array1'), 8);
		is ($eventMacro->get_array_size('array2'), 3);
		is ($eventMacro->get_array_size('array1'), $new_size);
		
		my $removed;
		
		$removed = $eventMacro->pop_array('array1');
		is_deeply($eventMacro->{Array_Variable_List_Hash}, {'array1' => ['Staff', undef, 'Shield', 'Card', 10, 'Equip', undef], 'array2' => [undef, undef, 'Drop']});
		is ($eventMacro->get_array_size('array1'), 7);
		is ($eventMacro->get_array_size('array2'), 3);
		is ($removed, 'Weapon');
		
		$removed = $eventMacro->pop_array('array1');
		is_deeply($eventMacro->{Array_Variable_List_Hash}, {'array1' => ['Staff', undef, 'Shield', 'Card', 10, 'Equip'], 'array2' => [undef, undef, 'Drop']});
		is ($eventMacro->get_array_size('array1'), 6);
		is ($eventMacro->get_array_size('array2'), 3);
		ok (!defined $removed);
		
		$removed = $eventMacro->pop_array('array1');
		is_deeply($eventMacro->{Array_Variable_List_Hash}, {'array1' => ['Staff', undef, 'Shield', 'Card', 10], 'array2' => [undef, undef, 'Drop']});
		is ($eventMacro->get_array_size('array1'), 5);
		is ($eventMacro->get_array_size('array2'), 3);
		is ($removed, 'Equip');
		
		$removed = $eventMacro->shift_array('array1');
		is_deeply($eventMacro->{Array_Variable_List_Hash}, {'array1' => [undef, 'Shield', 'Card', 10], 'array2' => [undef, undef, 'Drop']});
		is ($eventMacro->get_array_size('array1'), 4);
		is ($eventMacro->get_array_size('array2'), 3);
		is ($removed, 'Staff');
		
		$removed = $eventMacro->shift_array('array1');
		is_deeply($eventMacro->{Array_Variable_List_Hash}, {'array1' => ['Shield', 'Card', 10], 'array2' => [undef, undef, 'Drop']});
		is ($eventMacro->get_array_size('array1'), 3);
		is ($eventMacro->get_array_size('array2'), 3);
		ok (!defined $removed);
	};
	
	subtest 'hash' => sub {
		is_deeply($eventMacro->{Hash_Variable_List_Hash}, {});
		
		is ($eventMacro->get_hash_size('hash1'), 0);
		is ($eventMacro->get_hash_size('hash2'), 0);
		
		$eventMacro->set_full_hash('hash1', {'Poring' => 10, 'Drops' => 25, 'Poporing' => 'undef', 'Magmaring' => 100, 'Angeling' => 'undef'});
		is ($eventMacro->get_hash_size('hash1'), 5);
		is ($eventMacro->get_hash_size('hash2'), 0);
		
		is ($eventMacro->exists_hash('hash1', 'Poring'), 1);
		is ($eventMacro->is_hash_var_defined('hash1', 'Poring'), 1);
		is ($eventMacro->get_hash_var('hash1', 'Poring'), 10);
		
		is ($eventMacro->exists_hash('hash1', 'Drops'), 1);
		is ($eventMacro->is_hash_var_defined('hash1', 'Drops'), 1);
		is ($eventMacro->get_hash_var('hash1', 'Drops'), 25);
		
		is ($eventMacro->exists_hash('hash1', 'Magmaring'), 1);
		is ($eventMacro->is_hash_var_defined('hash1', 'Magmaring'), 1);
		is ($eventMacro->get_hash_var('hash1', 'Magmaring'), 100);
		
		is ($eventMacro->exists_hash('hash1', 'Poporing'), 1);
		is ($eventMacro->is_hash_var_defined('hash1', 'Poporing'), 0);
		ok (!defined $eventMacro->get_hash_var('hash1', 'Poporing'));
		
		is ($eventMacro->exists_hash('hash1', 'Angeling'), 1);
		is ($eventMacro->is_hash_var_defined('hash1', 'Angeling'), 0);
		ok (!defined $eventMacro->get_hash_var('hash1', 'Angeling'));
		
		is ($eventMacro->exists_hash('hash1', 'Deviling'), 0);
		is ($eventMacro->is_hash_var_defined('hash1', 'Deviling'), 0);
		ok (!defined $eventMacro->get_hash_var('hash1', 'Deviling'));
		
		is ($eventMacro->exists_hash('hash1', 'ArchAngeling'), 0);
		is ($eventMacro->is_hash_var_defined('hash1', 'ArchAngeling'), 0);
		ok (!defined $eventMacro->get_hash_var('hash1', 'Deviling'));
		
		is_deeply($eventMacro->{Hash_Variable_List_Hash}, {'hash1' => {'Poring' => 10, 'Drops' => 25, 'Poporing' => undef, 'Magmaring' => 100, 'Angeling' => undef}});
		
		
		$eventMacro->set_full_hash('hash2', {'Staff' => 2000, 'Shield' => 'undef', 'Card' => 7000});
		is ($eventMacro->get_hash_size('hash1'), 5);
		is ($eventMacro->get_hash_size('hash2'), 3);
		
		is ($eventMacro->exists_hash('hash2', 'Staff'), 1);
		is ($eventMacro->is_hash_var_defined('hash2', 'Staff'), 1);
		is ($eventMacro->get_hash_var('hash2', 'Staff'), 2000);
		
		is ($eventMacro->exists_hash('hash2', 'Shield'), 1);
		is ($eventMacro->is_hash_var_defined('hash2', 'Shield'), 0);
		ok (!defined $eventMacro->get_hash_var('hash2', 'Shield'));
		
		is ($eventMacro->exists_hash('hash2', 'Card'), 1);
		is ($eventMacro->is_hash_var_defined('hash2', 'Card'), 1);
		is ($eventMacro->get_hash_var('hash2', 'Card'), 7000);
		
		is ($eventMacro->exists_hash('hash2', 'Weapon'), 0);
		is ($eventMacro->is_hash_var_defined('hash2', 'Weapon'), 0);
		ok (!defined $eventMacro->get_hash_var('hash2', 'Weapon'));
		
		is_deeply($eventMacro->{Hash_Variable_List_Hash}, {'hash1' => {'Poring' => 10, 'Drops' => 25, 'Poporing' => undef, 'Magmaring' => 100, 'Angeling' => undef}, 'hash2' => {'Staff' => 2000, 'Shield' => undef, 'Card' => 7000}});
		
		
		my @keys1 = @{$eventMacro->get_hash_keys('hash1')};
		my @real_keys1 = keys %{$eventMacro->{Hash_Variable_List_Hash}{'hash1'}};
		is_deeply(\@keys1, \@real_keys1);
		
		my @values1 = @{$eventMacro->get_hash_values('hash1')};
		my @real_values1 = values %{$eventMacro->{Hash_Variable_List_Hash}{'hash1'}};
		is_deeply(\@values1, \@real_values1);
		
		my @keys2 = @{$eventMacro->get_hash_keys('hash2')};
		my @real_keys2 = keys %{$eventMacro->{Hash_Variable_List_Hash}{'hash2'}};
		is_deeply(\@keys2, \@real_keys2);
		
		my @values2 = @{$eventMacro->get_hash_values('hash2')};
		my @real_values2 = values %{$eventMacro->{Hash_Variable_List_Hash}{'hash2'}};
		is_deeply(\@values2, \@real_values2);
		
		
		$eventMacro->clear_hash('hash1');
		is ($eventMacro->get_hash_size('hash1'), 0);
		is ($eventMacro->get_hash_size('hash2'), 3);
		is_deeply($eventMacro->{Hash_Variable_List_Hash}, {'hash2' => {'Staff' => 2000, 'Shield' => undef, 'Card' => 7000}});
		
		$eventMacro->clear_hash('hash2');
		is ($eventMacro->get_hash_size('hash1'), 0);
		is ($eventMacro->get_hash_size('hash2'), 0);
		is_deeply($eventMacro->{Hash_Variable_List_Hash}, {});
		

		$eventMacro->set_hash_var('hash1', 'Quest1', 10);
		is ($eventMacro->get_hash_size('hash1'), 1);
		is ($eventMacro->get_hash_size('hash2'), 0);
		
		is ($eventMacro->exists_hash('hash1', 'Quest1'), 1);
		is ($eventMacro->is_hash_var_defined('hash1', 'Quest1'), 1);
		is ($eventMacro->get_hash_var('hash1', 'Quest1'), 10);
		
		is ($eventMacro->exists_hash('hash1', 'Quest2'), 0);
		is ($eventMacro->is_hash_var_defined('hash1', 'Quest2'), 0);
		ok (!defined $eventMacro->get_hash_var('hash1', 'Quest2'));
		
		is_deeply($eventMacro->{Hash_Variable_List_Hash}, {'hash1' => {'Quest1' => 10}});
		
		
		
		$eventMacro->set_hash_var('hash1', 'Quest2', 'undef');
		is ($eventMacro->get_hash_size('hash1'), 2);
		is ($eventMacro->get_hash_size('hash2'), 0);
		
		is ($eventMacro->exists_hash('hash1', 'Quest1'), 1);
		is ($eventMacro->is_hash_var_defined('hash1', 'Quest1'), 1);
		is ($eventMacro->get_hash_var('hash1', 'Quest1'), 10);
		
		is ($eventMacro->exists_hash('hash1', 'Quest2'), 1);
		is ($eventMacro->is_hash_var_defined('hash1', 'Quest2'), 0);
		ok (!defined $eventMacro->get_hash_var('hash1', 'Quest2'));
		
		is_deeply($eventMacro->{Hash_Variable_List_Hash}, {'hash1' => {'Quest1' => 10, 'Quest2' => undef}});
		
		$eventMacro->set_hash_var('hash1', 'Quest2', 15);
		is ($eventMacro->get_hash_size('hash1'), 2);
		is ($eventMacro->get_hash_size('hash2'), 0);
		
		is ($eventMacro->exists_hash('hash1', 'Quest1'), 1);
		is ($eventMacro->is_hash_var_defined('hash1', 'Quest1'), 1);
		is ($eventMacro->get_hash_var('hash1', 'Quest1'), 10);
		
		is ($eventMacro->exists_hash('hash1', 'Quest2'), 1);
		is ($eventMacro->is_hash_var_defined('hash1', 'Quest2'), 1);
		is ($eventMacro->get_hash_var('hash1', 'Quest2'), 15);
		
		is_deeply($eventMacro->{Hash_Variable_List_Hash}, {'hash1' => {'Quest1' => 10, 'Quest2' => 15}});
		
		$eventMacro->delete_key('hash1', 'Quest1');
		is ($eventMacro->get_hash_size('hash1'), 1);
		is ($eventMacro->get_hash_size('hash2'), 0);
		
		is ($eventMacro->exists_hash('hash1', 'Quest1'), 0);
		is ($eventMacro->is_hash_var_defined('hash1', 'Quest1'), 0);
		ok (!defined $eventMacro->get_hash_var('hash1', 'Quest1'));
		
		is ($eventMacro->exists_hash('hash1', 'Quest2'), 1);
		is ($eventMacro->is_hash_var_defined('hash1', 'Quest2'), 1);
		is ($eventMacro->get_hash_var('hash1', 'Quest2'), 15);
		
		is_deeply($eventMacro->{Hash_Variable_List_Hash}, {'hash1' => {'Quest2' => 15}});
		
		$eventMacro->delete_key('hash1', 'Quest2');
		is ($eventMacro->get_hash_size('hash1'), 0);
		is ($eventMacro->get_hash_size('hash2'), 0);
		
		is ($eventMacro->exists_hash('hash1', 'Quest1'), 0);
		is ($eventMacro->is_hash_var_defined('hash1', 'Quest1'), 0);
		ok (!defined $eventMacro->get_hash_var('hash1', 'Quest1'));
		
		is ($eventMacro->exists_hash('hash1', 'Quest2'), 0);
		is ($eventMacro->is_hash_var_defined('hash1', 'Quest2'), 0);
		ok (!defined $eventMacro->get_hash_var('hash1', 'Quest2'));
		
		is_deeply($eventMacro->{Hash_Variable_List_Hash}, {'hash1' => {}});
	};
}

1;
