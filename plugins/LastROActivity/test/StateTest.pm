package StateTest;

use strict;
use warnings;

use Test::More;

use LastROActivity::State;

sub start {
	subtest 'follows every documented successful lifecycle transition' => sub {
		my $state = LastROActivity::State->new;
		is($state->state, 'IDLE', 'new state starts idle');

		my @transitions = (
			[arm      => 'ARMED'],
			[trigger  => 'INTERRUPTING'],
			[snapshot => 'SNAPSHOTTED'],
			[depart   => 'DEPARTING'],
			[enter    => 'ENTERING'],
			[running  => 'RUNNING'],
			[finish   => 'FINISHING'],
			[return   => 'RETURNING'],
			[resume   => 'RESUMED'],
		);

		for my $transition (@transitions) {
			is(
				$state->transition($transition->[0]),
				$transition->[1],
				"event $transition->[0] enters $transition->[1]",
			);
			is($state->state, $transition->[1], "state is $transition->[1]");
		}
		done_testing();
	};

	subtest 'allows fail from every non-terminal state' => sub {
		my @states = qw(IDLE ARMED INTERRUPTING SNAPSHOTTED DEPARTING ENTERING RUNNING FINISHING RETURNING);
		my %next_event = (
			IDLE         => 'arm',
			ARMED        => 'trigger',
			INTERRUPTING => 'snapshot',
			SNAPSHOTTED  => 'depart',
			DEPARTING    => 'enter',
			ENTERING     => 'running',
			RUNNING      => 'finish',
			FINISHING    => 'return',
			RETURNING    => 'resume',
		);

		for my $expected_state (@states) {
			my $state = LastROActivity::State->new;
			for my $current_state (@states) {
				last if $current_state eq $expected_state;
				$state->transition($next_event{$current_state});
			}
			is($state->state, $expected_state, "reaches $expected_state before failure");
			is($state->transition('fail'), 'FAILED', "fail from $expected_state enters FAILED");
			is($state->state, 'FAILED', "failure from $expected_state is terminal");
		}
		done_testing();
	};

	subtest 'rejects invalid transitions with a stable error' => sub {
		my $state = LastROActivity::State->new;
		my $error = eval { $state->transition('trigger'); 1 };
		my $message = $@;
		ok(!$error, 'invalid event does not transition');
		is($message, "invalid transition from IDLE via trigger\n", 'invalid transition error is stable');
		is($state->state, 'IDLE', 'invalid event leaves state unchanged');

		$state->transition('arm');
		my $terminal_error = eval { $state->transition('resume'); 1 };
		my $terminal_message = $@;
		ok(!$terminal_error, 'event for another state is rejected');
		is($terminal_message, "invalid transition from ARMED via resume\n", 'rejection identifies current state and event');

		$state->transition('fail');
		my $failed_error = eval { $state->transition('arm'); 1 };
		my $failed_message = $@;
		ok(!$failed_error, 'failed state is terminal');
		is($failed_message, "invalid transition from FAILED via arm\n", 'failed state rejects all events');

		my $resumed = LastROActivity::State->new;
		$resumed->transition($_) for qw(arm trigger snapshot depart enter running finish return resume);
		my $resumed_error = eval { $resumed->transition('fail'); 1 };
		my $resumed_message = $@;
		ok(!$resumed_error, 'resumed state is terminal');
		is($resumed_message, "invalid transition from RESUMED via fail\n", 'resumed state rejects failure');
		done_testing();
	};

	subtest 'snapshots, applies, and restores config entirely in memory' => sub {
		my %config = (
			lockMap => 'pay_fild08',
			lockMap_x => 55,
			lockMap_y => 66,
			lockMap_randX => 7,
			lockMap_randY => 8,
			teleportAuto_search => 0,
			teleportAuto_idle => 0,
			route_randomWalk => 0,
			attackAuto => 1,
			itemsTakeAuto => 0,
			itemsGatherAuto => 0,
			unrelated => 'untouched',
		);
		my %before = %config;

		my $snapshot = LastROActivity::State::snapshot_config(\%config);
		is_deeply(
			$snapshot,
			{
				values => { map { $_ => $before{$_} } qw(lockMap lockMap_x lockMap_y lockMap_randX lockMap_randY teleportAuto_search teleportAuto_idle route_randomWalk attackAuto itemsTakeAuto itemsGatherAuto) },
				present => { map { $_ => 1 } qw(lockMap lockMap_x lockMap_y lockMap_randX lockMap_randY teleportAuto_search teleportAuto_idle route_randomWalk attackAuto itemsTakeAuto itemsGatherAuto) },
			},
			'snapshot copies only activity settings and their presence',
		);

		my $old_snapshot = LastROActivity::State::apply_activity_config(\%config, 17);
		is_deeply($old_snapshot, $snapshot, 'apply returns the exact pre-activity snapshot');
		is($config{lockMap}, '', 'activity clears lockMap in memory');
		is($config{teleportAuto_search}, 1, 'activity enables search gate');
		is($config{teleportAuto_idle}, 17, 'activity enables supplied idle teleport interval');
		is($config{unrelated}, 'untouched', 'activity leaves unrelated config untouched');

		LastROActivity::State::restore_config(\%config, $old_snapshot);
		is_deeply(\%config, \%before, 'restore returns the exact pre-activity config');
		done_testing();
	};

	subtest 'normal combat applies idle and random-walk settings and restores presence' => sub {
		my %config = (
			lockMap => 'pay_fild08',
			teleportAuto_search => 1,
			teleportAuto_idle => 9,
			route_randomWalk => 0,
			attackAuto => 7,
		);
		my %before = %config;
		my $snapshot = LastROActivity::State::snapshot_config(\%config);
		my $old_snapshot = LastROActivity::State::apply_activity_config(\%config, 99, 'normal');
		is_deeply($old_snapshot, $snapshot, 'normal apply returns the exact pre-activity snapshot');
		is($config{teleportAuto_search}, 0, 'normal combat disables search teleporting');
		is($config{teleportAuto_idle}, 1, 'normal combat uses one-second teleport idle');
		is($config{route_randomWalk}, 1, 'normal combat enables random walking');
		is($config{attackAuto}, 7, 'normal combat leaves attackAuto unchanged');
		ok(!exists $config{itemsTakeAuto}, 'normal combat does not create item pickup settings');
		ok(!exists $config{itemsGatherAuto}, 'normal combat does not create item gathering settings');

		LastROActivity::State::restore_config(\%config, $old_snapshot);
		is_deeply(\%config, \%before, 'normal combat restores every original setting');

		my %missing_route = (lockMap => 'pay_fild08');
		my $missing_snapshot = LastROActivity::State::apply_activity_config(\%missing_route, 1, 'normal');
		ok(exists $missing_route{route_randomWalk}, 'normal apply creates a temporary route setting');
		LastROActivity::State::restore_config(\%missing_route, $missing_snapshot);
		ok(!exists $missing_route{route_randomWalk}, 'restore removes a route setting that was originally absent');
		done_testing();
	};

	subtest 'dojo combat settings are temporary and restore all activity keys' => sub {
		my %config = (
			lockMap => 'pay_fild08',
			lockMap_x => 55,
			lockMap_y => 66,
			lockMap_randX => 7,
			lockMap_randY => 8,
			teleportAuto_search => 0,
			teleportAuto_idle => 0,
			route_randomWalk => 0,
			attackAuto => 1,
			itemsTakeAuto => 0,
			itemsGatherAuto => 0,
		);
		my %before = %config;
		my $snapshot = LastROActivity::State::apply_activity_config(
			\%config, 7, 'normal', 'dojo_challenge',
		);
		is($config{attackAuto}, 2, 'dojo enables attack automation');
		is($config{itemsTakeAuto}, 2, 'dojo enables item pickup');
		is($config{itemsGatherAuto}, 2, 'dojo enables item gathering');
		is($config{teleportAuto_search}, 0, 'dojo keeps search teleport disabled');
		is($config{route_randomWalk}, 1, 'dojo enables random walking');
		LastROActivity::State::restore_config(\%config, $snapshot);
		is_deeply(\%config, \%before, 'dojo restores every temporary setting');
		done_testing();
	};

	subtest 'restores missing and explicitly undefined settings distinctly' => sub {
		my %config = (
			lockMap => undef,
			lockMap_x => 55,
			teleportAuto_search => 0,
		);
		my $snapshot = LastROActivity::State::snapshot_config(\%config);

		$config{lockMap} = 'temporary';
		$config{lockMap_y} = 66;
		$config{teleportAuto_idle} = 1;
		LastROActivity::State::restore_config(\%config, $snapshot);

		ok(exists $config{lockMap}, 'explicitly present undef value remains present');
		ok(!defined $config{lockMap}, 'explicitly present undef value remains undef');
		ok(!exists $config{lockMap_y}, 'missing lockMap_y is removed on restore');
		ok(!exists $config{lockMap_randX}, 'missing lockMap_randX remains missing');
		ok(!exists $config{lockMap_randY}, 'missing lockMap_randY remains missing');
		ok(!exists $config{teleportAuto_idle}, 'missing teleportAuto_idle is removed on restore');
		is_deeply(
			\%config,
			{lockMap => undef, lockMap_x => 55, teleportAuto_search => 0},
			'restore preserves the exact key shape',
		);
		done_testing();
	};

	subtest 'does not call persistence helpers' => sub {
		my %config = (
			lockMap => 'pay_fild08',
			teleportAuto_search => 0,
			teleportAuto_idle => 0,
		);
		my $called = 0;
		{
			no warnings qw(once redefine);
			local *main::configModify = sub { $called++; die 'configModify must not be called' };
			local *main::saveConfigFile = sub { $called++; die 'saveConfigFile must not be called' };
			my $snapshot = LastROActivity::State::apply_activity_config(\%config, 1);
			LastROActivity::State::restore_config(\%config, $snapshot);
		}
		is($called, 0, 'config persistence helpers are never invoked');
		done_testing();
	};
}

1;
