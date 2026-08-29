package SchedulerTest;

use strict;
use warnings;
use utf8;

use Test::More;

use LastROActivity::Scheduler;

sub start {
	subtest 'parses Chinese countdown units and sums them' => sub {
		is(LastROActivity::Scheduler::parse_countdown('活动将在2小时后开始'), 7200, 'parses hours');
		is(LastROActivity::Scheduler::parse_countdown('活动将在1分钟后开始'), 60, 'parses minutes');
		is(LastROActivity::Scheduler::parse_countdown('活动将在10秒钟后开始'), 10, 'parses seconds');
		is(
			LastROActivity::Scheduler::parse_countdown('活动将在1小时 2分钟 3秒后开始'),
			3723,
			'sums all present units',
		);
		is(
			LastROActivity::Scheduler::parse_countdown('活动将在1小時后开始'),
			3600,
			'parses traditional hours',
		);
		is(
			LastROActivity::Scheduler::parse_countdown('活动将在2时后开始'),
			7200,
			'parses abbreviated hours',
		);
		ok(!defined LastROActivity::Scheduler::parse_countdown('活动已经开始'), 'no countdown is undef');
		is(LastROActivity::Scheduler::parse_countdown('活动将在0秒后开始'), 0, 'zero countdown is defined');
		done_testing();
	};

	subtest 'arms an event at the lead boundary and starts immediate events' => sub {
		my $scheduler = LastROActivity::Scheduler->new(lead_seconds => 10);
		my $rule = {event_id => 'city_monster_party', enabled => 1, lead_seconds => 10};
		my $armed = $scheduler->observe($rule, '城市魔物派对将在2小时后开始', 1_000);

		is($armed->{event_id}, 'city_monster_party', 'stores event ID');
		is($armed->{start_at}, 8_200, 'computes start time');
		is($armed->{trigger_at}, 8_190, 'triggers at start minus ten seconds');
		is(scalar @{$scheduler->due(8_189)}, 0, 'does not trigger early');
		is(scalar @{$scheduler->due(8_190)}, 1, 'triggers at the ten-second boundary');
		is(scalar @{$scheduler->due(9_000)}, 0, 'dispatched event is not returned twice');

		my $immediate_rule = {
			event_id => 'lottery',
			enabled => 1,
			start_regex => '活动已经开始',
			lead_seconds => 10,
		};
		my $immediate = $scheduler->observe($immediate_rule, '通知：活动已经开始！', 4_000);
		is($immediate->{start_at}, 4_000, 'immediate event starts at receipt time');
		is($immediate->{trigger_at}, 4_000, 'immediate event is due without a countdown');
		is(scalar @{$scheduler->due(3_999)}, 0, 'immediate event is not due before receipt');
		is(scalar @{$scheduler->due(4_000)}, 1, 'immediate event is due at receipt');
		done_testing();
	};

	subtest 'replaces duplicate announcements and orders due events' => sub {
		my $scheduler = LastROActivity::Scheduler->new(
			lead_seconds => 10,
			clock => sub { 9_999 },
		);
		my $rule = {event_id => 'city_monster_party', enabled => 1, lead_seconds => 10};
		$scheduler->observe($rule, '城市魔物派对将在1分钟后开始', 2_000);
		my $replacement = $scheduler->observe($rule, '城市魔物派对将在1分钟后开始', 2_001);

		is($replacement->{trigger_at}, 2_051, 'replacement uses the latest receipt time');
		is(scalar @{$scheduler->due(2_050)}, 0, 'old duplicate timer is removed');
		is(scalar @{$scheduler->due(2_051)}, 1, 'duplicate announcements share one timer');

		my $early_rule = {
			event_id => 'early',
			enabled => 1,
			lead_seconds => 10,
			priority => 1,
		};
		my $high_priority_rule = {
			event_id => 'high',
			enabled => 1,
			lead_seconds => 10,
			priority => 5,
		};
		$scheduler->observe($high_priority_rule, 'high将在1分钟后开始', 3_000);
		$scheduler->observe($early_rule, 'early将在1分钟后开始', 3_000);
		my $due = $scheduler->due(3_050);
		is_deeply(
			[map { $_->{event_id} } @$due],
			[qw(high early)],
			'same start time is ordered by descending priority',
		);

		$scheduler->observe($rule, '城市魔物派对将在1分钟后开始', 5_000);
		ok($scheduler->cancel('city_monster_party'), 'cancel reports an armed event');
		ok(!$scheduler->cancel('city_monster_party'), 'cancel reports no event after removal');
		is(scalar @{$scheduler->due(5_050)}, 0, 'cancelled event is not due');
		done_testing();
	};

	subtest 'extracts only well-formed dynamic map coordinates' => sub {
		is_deeply(
			LastROActivity::Scheduler::extract_data_map("<a data-map='prontera#152#129'>event</a>"),
			{map => 'prontera', x => 152, y => 129},
			'extracts single-quoted data-map coordinates',
		);
		is_deeply(
			LastROActivity::Scheduler::extract_data_map('<a data-map="prontera#152#129">event</a>'),
			{map => 'prontera', x => 152, y => 129},
			'extracts double-quoted data-map coordinates',
		);
		ok(!defined LastROActivity::Scheduler::extract_data_map("data-map='prontera#x#129'"), 'rejects nonnumeric x');
		ok(!defined LastROActivity::Scheduler::extract_data_map("data-map='prontera#152#129#1'"), 'rejects extra coordinates');
		ok(!defined LastROActivity::Scheduler::extract_data_map('no map metadata'), 'returns undef without metadata');

		my $scheduler = LastROActivity::Scheduler->new;
		my $dynamic = {
			event_id => 'dynamic',
			enabled => 1,
			map_source => 'dynamic',
		};
		my $dynamic_event = $scheduler->observe(
			$dynamic,
			"活动将在10秒后开始 data-map='payon#42#84'",
			6_000,
		);
		is_deeply($dynamic_event->{data_map}, {map => 'payon', x => 42, y => 84}, 'keeps dynamic map data on the event');

		my $static = {
			event_id => 'static',
			enabled => 1,
			map_source => 'announcement',
		};
		my $static_event = $scheduler->observe(
			$static,
			"活动将在10秒后开始 data-map='payon#42#84'",
			6_000,
		);
		ok(!exists $static_event->{data_map}, 'does not attach dynamic data to static rules');
		done_testing();
	};
}

1;
