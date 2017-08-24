package Validator::ListMemberCheckTest;

use strict;
use warnings;

use Test::More;
use eventMacro::Data;
use eventMacro::Validator::ListMemberCheck;

sub start {
	subtest 'single member' => sub {
		my $v = eventMacro::Validator::ListMemberCheck->new( 'Poring' );
		ok $v->parsed;
		is_deeply($v->{list}, ['Poring']);
		ok $v->validate( 'Poring' );
		ok !$v->validate( 'Drops' );
		ok !$v->validate( 'poring' );

		$v = eventMacro::Validator::ListMemberCheck->new( 'drops' );
		ok $v->parsed;
		is_deeply($v->{list}, ['drops']);
		ok $v->validate( 'drops' );
		ok !$v->validate( 'marin' );
		ok !$v->validate( 'Drops' );

		$v = eventMacro::Validator::ListMemberCheck->new( 'prt_fild10' );
		ok $v->parsed;
		is_deeply($v->{list}, ['prt_fild10']);
		ok !$v->validate( 'geffen' );
		ok $v->validate( 'prt_fild10' );
		ok !$v->validate( '' );
	};
	
	subtest 'multiple members' => sub {
		my $v = eventMacro::Validator::ListMemberCheck->new( 'Poring, Drops, Poporing' );
		ok $v->parsed;
		is_deeply($v->{list}, ['Poring', 'Drops', 'Poporing']);
		ok $v->validate( 'Poring' );
		ok $v->validate( 'Drops' );
		ok $v->validate( 'Poporing' );
		ok !$v->validate( 'Marin' );
		ok !$v->validate( '' );

		$v = eventMacro::Validator::ListMemberCheck->new( 'prt_fild10, prt_fild11, gef_fild10' );
		ok $v->parsed;
		is_deeply($v->{list}, ['prt_fild10', 'prt_fild11', 'gef_fild10']);
		ok $v->validate( 'prt_fild10' );
		ok $v->validate( 'prt_fild11' );
		ok !$v->validate( 'prt_fild12' );
		ok $v->validate( 'gef_fild10' );
		ok !$v->validate( 'gef_fild12' );
	};
	
	subtest 'single variable member' => sub {
		my $v = eventMacro::Validator::ListMemberCheck->new( '$foo' );
		ok $v->parsed;
		is_deeply($v->{list}, [undef]);
		is_deeply($v->{var_to_member_index}, {'$foo' => [0]});
		
		ok !$v->validate( 'Poring' );
		ok !$v->validate( 'Drops' );
		ok !$v->validate( 'poring' );
		
		$v->update_vars( '$foo', 'Poring' );
		is_deeply($v->{list}, ['Poring']);
		
		ok $v->validate( 'Poring' );
		ok !$v->validate( 'Drops' );
		ok !$v->validate( 'poring' );

		$v = eventMacro::Validator::ListMemberCheck->new( '$foo{map}' );
		ok $v->parsed;
		is_deeply($v->{list}, [undef]);
		is_deeply($v->{var_to_member_index}, {'$foo{map}' => [0]});
		
		ok !$v->validate( 'geffen' );
		ok !$v->validate( 'prt_fild10' );
		
		$v->update_vars( '$foo{map}', 'prt_fild10' );
		is_deeply($v->{list}, ['prt_fild10']);
		
		ok !$v->validate( 'geffen' );
		ok $v->validate( 'prt_fild10' );
	};
	
	subtest 'multiple variable members' => sub {
		my $v = eventMacro::Validator::ListMemberCheck->new( '$foo, $bar[5], $foobar{mob}' );
		ok $v->parsed;
		is_deeply($v->{list}, [undef, undef, undef]);
		is_deeply($v->{var_to_member_index}, {'$foo' => [0], '$bar[5]' => [1],'$foobar{mob}' => [2]});
		
		ok !$v->validate( 'Poring' );
		ok !$v->validate( 'Drops' );
		ok !$v->validate( 'poring' );
		ok !$v->validate( 'Marin' );
		
		
		$v->update_vars( '$foo', 'Poring' );
		is_deeply($v->{list}, ['Poring', undef, undef]);
		
		ok $v->validate( 'Poring' );
		ok !$v->validate( 'Drops' );
		ok !$v->validate( 'poring' );
		ok !$v->validate( 'Marin' );
		
		$v->update_vars( '$foobar{mob}', 'poring' );
		is_deeply($v->{list}, ['Poring', undef, 'poring']);
		
		ok $v->validate( 'Poring' );
		ok !$v->validate( 'Drops' );
		ok $v->validate( 'poring' );
		ok !$v->validate( 'Marin' );
		
		$v->update_vars( '$bar[5]', 'Drops' );
		is_deeply($v->{list}, ['Poring', 'Drops', 'poring']);
		
		ok $v->validate( 'Poring' );
		ok $v->validate( 'Drops' );
		ok $v->validate( 'poring' );
		ok !$v->validate( 'Marin' );
	};
	
	subtest 'multiple nested variable members' => sub {
		my $v = eventMacro::Validator::ListMemberCheck->new( '$foo{$buz}, $bar[$hash{mob}], $baz{$bar[$foo]}' );
		ok $v->parsed;
		is_deeply($v->{list}, [undef, undef, undef]);
		is_deeply($v->{var_to_member_index}, {'$foo{$buz}' => [0], '$bar[$hash{mob}]' => [1],'$baz{$bar[$foo]}' => [2]});
		
		ok !$v->validate( 'Poring' );
		ok !$v->validate( 'Drops' );
		ok !$v->validate( 'poring' );
		ok !$v->validate( 'Marin' );
		
		
		$v->update_vars( '$foo{$buz}', 'Poring' );
		is_deeply($v->{list}, ['Poring', undef, undef]);
		
		ok $v->validate( 'Poring' );
		ok !$v->validate( 'Drops' );
		ok !$v->validate( 'poring' );
		ok !$v->validate( 'Marin' );
		
		$v->update_vars( '$baz{$bar[$foo]}', 'poring' );
		is_deeply($v->{list}, ['Poring', undef, 'poring']);
		
		ok $v->validate( 'Poring' );
		ok !$v->validate( 'Drops' );
		ok $v->validate( 'poring' );
		ok !$v->validate( 'Marin' );
		
		$v->update_vars( '$bar[$hash{mob}]', 'Drops' );
		is_deeply($v->{list}, ['Poring', 'Drops', 'poring']);
		
		ok $v->validate( 'Poring' );
		ok $v->validate( 'Drops' );
		ok $v->validate( 'poring' );
		ok !$v->validate( 'Marin' );
	};
}

1;
