package Validator::NumericComparisonTest;

use strict;
use warnings;

use Test::More;
use eventMacro::Data;
use eventMacro::Validator::NumericComparison;

sub test {
	my ( $pattern, $neg, $zero, $pos ) = @_;
	my $v = eventMacro::Validator::NumericComparison->new( $pattern );
	ok $v->parsed;
	ok !!$neg eq !!$v->validate( -1 );
	ok !!$zero eq !!$v->validate( 0 );
	ok !!$pos eq !!$v->validate( 1 );
}

sub start {
	subtest 'simple number' => sub {
		my $v = eventMacro::Validator::NumericComparison->new( '< 10' );
		ok $v->parsed;
		ok $v->validate( 9 );
		ok !$v->validate( 10 );
		ok !$v->validate( 11 );

		$v = eventMacro::Validator::NumericComparison->new( '<= 10' );
		ok $v->parsed;
		ok $v->validate( 9 );
		ok $v->validate( 10 );
		ok !$v->validate( 11 );

		$v = eventMacro::Validator::NumericComparison->new( '== 10' );
		ok $v->parsed;
		ok !$v->validate( 9 );
		ok $v->validate( 10 );
		ok !$v->validate( 11 );

		$v = eventMacro::Validator::NumericComparison->new( '!= 10' );
		ok $v->parsed;
		ok $v->validate( 9 );
		ok !$v->validate( 10 );
		ok $v->validate( 11 );

		$v = eventMacro::Validator::NumericComparison->new( '>= 10' );
		ok $v->parsed;
		ok !$v->validate( 9 );
		ok $v->validate( 10 );
		ok $v->validate( 11 );

		$v = eventMacro::Validator::NumericComparison->new( '> 10' );
		ok $v->parsed;
		ok !$v->validate( 9 );
		ok !$v->validate( 10 );
		ok $v->validate( 11 );
	};

	subtest 'range' => sub {
		my $v = eventMacro::Validator::NumericComparison->new( '< 10..20' );
		ok $v->parsed;
		ok $v->validate( 9 );
		ok !$v->validate( 10 );
		ok !$v->validate( 20 );
		ok !$v->validate( 21 );

		$v = eventMacro::Validator::NumericComparison->new( '<= 10..20' );
		ok $v->parsed;
		ok $v->validate( 9 );
		ok $v->validate( 10 );
		ok $v->validate( 20 );
		ok !$v->validate( 21 );

		$v = eventMacro::Validator::NumericComparison->new( '== 10..20' );
		ok $v->parsed;
		ok !$v->validate( 9 );
		ok $v->validate( 10 );
		ok $v->validate( 20 );
		ok !$v->validate( 21 );

		$v = eventMacro::Validator::NumericComparison->new( '!= 10..20' );
		ok $v->parsed;
		ok $v->validate( 9 );
		ok !$v->validate( 10 );
		ok !$v->validate( 20 );
		ok $v->validate( 21 );

		$v = eventMacro::Validator::NumericComparison->new( '>= 10..20' );
		ok $v->parsed;
		ok !$v->validate( 9 );
		ok $v->validate( 10 );
		ok $v->validate( 20 );
		ok $v->validate( 21 );

		$v = eventMacro::Validator::NumericComparison->new( '> 10..20' );
		ok $v->parsed;
		ok !$v->validate( 9 );
		ok !$v->validate( 10 );
		ok !$v->validate( 20 );
		ok $v->validate( 21 );
	};

	subtest 'percent' => sub {
		my $v = eventMacro::Validator::NumericComparison->new( '<10%' );
		ok $v->parsed;

		ok $v->validate( 4.9, 50 );
		ok !$v->validate( 5,  50 );
		ok !$v->validate( 10, 50 );
		ok $v->validate( 19.9, 200 );
		ok !$v->validate( 20, 200 );
		ok !$v->validate( 40, 200 );

		$v = eventMacro::Validator::NumericComparison->new( '10%..20%' );
		ok $v->parsed;

		ok !$v->validate( 4.9, 50 );
		ok $v->validate( 5,  50 );
		ok $v->validate( 10, 50 );
		ok !$v->validate( 10.1, 50 );

		ok !$v->validate( 19.9, 200 );
		ok $v->validate( 20, 200 );
		ok $v->validate( 40, 200 );
		ok !$v->validate( 40.1, 200 );
	};

	subtest 'variable' => sub {
		my $v = eventMacro::Validator::NumericComparison->new( '< $foo' );
		ok $v->parsed;

		$v->update_vars( 'foo', 10 );
		ok $v->validate( 9 );
		ok !$v->validate( 10 );
		ok !$v->validate( 11 );
		$v->update_vars( 'foo', 11 );
		ok $v->validate( 9 );
		ok $v->validate( 10 );
		ok !$v->validate( 11 );

		$v = eventMacro::Validator::NumericComparison->new( '$foo .. $bar' );
		ok $v->parsed;

		$v->update_vars( 'foo', 10 );
		$v->update_vars( 'bar', 20 );
		ok !$v->validate( 9 );
		ok $v->validate( 10 );
		ok $v->validate( 20 );
		ok !$v->validate( 21 );
	};
}

1;
