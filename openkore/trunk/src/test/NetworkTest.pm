# Unit test for Network
package NetworkTest;

use strict;
use Test::More;
use Network::Receive;
use Network::Send;

sub start {
	my %tests = (
		'Network::Receive' => [
			{
				switch => 'quest_update_mission_hunt',
				mobs => [
					{questID => 1001, mobID => 2001, count => 10},
					{questID => 1002, mobID => 2002, count => 100},
				]
			},
		],
		'Network::Send' => [
			{
				switch => 'master_login',
				version => 1,
				master_version => 123456,
				username => 'username',
				password => 'password',
			},
			{
				switch => 'buy_bulk_vender',
				items => [
					{itemIndex => 0, amount => 1},
					{itemIndex => 2, amount => 30000},
				]
			},
		],
	);
	
	for my $serverType (qw(
		0
		1
		2
		3
		4
		5
		6
		7
		8
		8_1
		8_2
		8_3
		8_4
		8_5
		9
		10
		11
		12
		13
		14
		15
		16
		17
		18
		19
		20
		21
		22
		bRO
		bRO_Thor
		fRO
		idRO
		iRO
		mRO
		pRO
		rRO
		tRO
		twRO
		kRO_RagexeRE_0
	)) {
		subtest "serverType $serverType" => sub {
			for my $module (keys %tests) {
				SKIP: {
					my $instance = eval { $module->create(undef, $serverType) };
					ok($instance, "create $module") or skip 'failed', 1;
					
					# do not test unsupported STs further
					next if $serverType =~ /^[1-9]/;
					
					# do not test kRO tree further
					next if $serverType =~ /^kRO/;
					
					for my $expected (@{$tests{$module}}) {
						subtest "$expected->{switch}" => sub { SKIP: {
							my ($reconstruct_callback, $parse_callback);
							
							subtest 'check for reconstruct and parse callbacks' => sub {
								ok($reconstruct_callback = $instance->can("reconstruct_$expected->{switch}"));
								ok($parse_callback = $instance->can("parse_$expected->{switch}"));
							} or skip 'failed', 1;
							
							my $got = Storable::dclone($expected);
							$instance->$reconstruct_callback($got);
							$instance->$parse_callback($got);
							
							# there may be additional keys after reconstruct_callback
							$got = reduce_struct($got, $expected);
							
							is_deeply($got, $expected, 'reconstruct and parse test data');
						}}
					}
				}
			}
		}
	}
}

sub reduce_struct {
	my ($got, $expected) = @_;
	
	ref $got eq 'HASH' ? {map { exists $expected->{$_} ? ($_ => reduce_struct($got->{$_}, $expected->{$_})) : () } keys %$got}
	: ref $got eq 'ARRAY' ? [List::MoreUtils::pairwise { reduce_struct($a, $b) } @$got, @$expected]
	: $got
}

1;
