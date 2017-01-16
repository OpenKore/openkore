package CoreVarFunctionsTest;

use strict;
use warnings;
use FindBin qw($RealBin);
use lib "$RealBin";

use Test::More;
use eventMacro::Data;
use eventMacro::Core;

#$eventMacro->{Scalar_Variable_List_Hash} = {};
#$eventMacro->{Array_Variable_List_Hash} = {};
#$eventMacro->{Hash_Variable_List_Hash} = {};

sub start {
	my $eventMacro = eventMacro::Core->new( "$RealBin/empty.txt" );
	
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
		
		is_deeply($eventMacro->{Scalar_Variable_List_Hash}, {'scalar1' => 73, 'scalar2' => undef});
		
		$eventMacro->set_scalar_var('scalar1', 'undef');
		ok (!defined $eventMacro->get_scalar_var('scalar1'));
		is ($eventMacro->is_scalar_var_defined('scalar1'), 0);
		
		ok (!defined $eventMacro->get_scalar_var('scalar2'));
		is ($eventMacro->is_scalar_var_defined('scalar2'), 0);
		
		is_deeply($eventMacro->{Scalar_Variable_List_Hash}, {'scalar1' => undef, 'scalar2' => undef});
		
		$eventMacro->set_scalar_var('scalar2', 5);
		ok (!defined $eventMacro->get_scalar_var('scalar1'));
		is ($eventMacro->is_scalar_var_defined('scalar1'), 0);
		
		ok (defined $eventMacro->get_scalar_var('scalar2'));
		is ($eventMacro->is_scalar_var_defined('scalar2'), 1);
		is ($eventMacro->get_scalar_var('scalar2'), 5);
		
		is_deeply($eventMacro->{Scalar_Variable_List_Hash}, {'scalar1' => undef, 'scalar2' => 5});
	};
	
	subtest 'array' => sub {
		is_deeply($eventMacro->{Array_Variable_List_Hash}, {});
		
		is ($eventMacro->get_array_size('array1'), 0);
		is ($eventMacro->get_array_size('array2'), 0);
		
		$eventMacro->set_full_array('array1', ['Poring', '15', undef, 'Drops', 'Magmaring']);
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
		
		$eventMacro->set_full_array('array2', ['Angeling', 'Deviling', 'Archangeling', undef, 'Mastering', undef, 'King Poring']);
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
		
		$new_size = $eventMacro->push_array('array1', 'Weapon');
		is_deeply($eventMacro->{Array_Variable_List_Hash}, {'array1' => ['Card', 10, 'Equip', 'Weapon'], 'array2' => [undef, undef, 'Drop']});
		is ($eventMacro->get_array_size('array1'), 4);
		is ($eventMacro->get_array_size('array2'), 3);
		is ($eventMacro->get_array_size('array1'), $new_size);
		
		$new_size = $eventMacro->unshift_array('array1', 'Shield');
		is_deeply($eventMacro->{Array_Variable_List_Hash}, {'array1' => ['Shield', 'Card', 10, 'Equip', 'Weapon'], 'array2' => [undef, undef, 'Drop']});
		is ($eventMacro->get_array_size('array1'), 5);
		is ($eventMacro->get_array_size('array2'), 3);
		is ($eventMacro->get_array_size('array1'), $new_size);
		
		$new_size = $eventMacro->unshift_array('array1', 'Staff');
		is_deeply($eventMacro->{Array_Variable_List_Hash}, {'array1' => ['Staff', 'Shield', 'Card', 10, 'Equip', 'Weapon'], 'array2' => [undef, undef, 'Drop']});
		is ($eventMacro->get_array_size('array1'), 6);
		is ($eventMacro->get_array_size('array2'), 3);
		is ($eventMacro->get_array_size('array1'), $new_size);
		
		my $removed;
		
		$removed = $eventMacro->pop_array('array1');
		is_deeply($eventMacro->{Array_Variable_List_Hash}, {'array1' => ['Staff', 'Shield', 'Card', 10, 'Equip'], 'array2' => [undef, undef, 'Drop']});
		is ($eventMacro->get_array_size('array1'), 5);
		is ($eventMacro->get_array_size('array2'), 3);
		is ($removed, 'Weapon');
		
		$removed = $eventMacro->pop_array('array1');
		is_deeply($eventMacro->{Array_Variable_List_Hash}, {'array1' => ['Staff', 'Shield', 'Card', 10], 'array2' => [undef, undef, 'Drop']});
		is ($eventMacro->get_array_size('array1'), 4);
		is ($eventMacro->get_array_size('array2'), 3);
		is ($removed, 'Equip');
		
		$removed = $eventMacro->shift_array('array1');
		is_deeply($eventMacro->{Array_Variable_List_Hash}, {'array1' => ['Shield', 'Card', 10], 'array2' => [undef, undef, 'Drop']});
		is ($eventMacro->get_array_size('array1'), 3);
		is ($eventMacro->get_array_size('array2'), 3);
		is ($removed, 'Staff');
		
		$removed = $eventMacro->shift_array('array1');
		is_deeply($eventMacro->{Array_Variable_List_Hash}, {'array1' => ['Card', 10], 'array2' => [undef, undef, 'Drop']});
		is ($eventMacro->get_array_size('array1'), 2);
		is ($eventMacro->get_array_size('array2'), 3);
		is ($removed, 'Shield');
	};
}

1;
