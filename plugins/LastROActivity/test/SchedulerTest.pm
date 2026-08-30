package SchedulerTest;

use strict;
use warnings;
use utf8;

use FindBin qw($RealBin);
use File::Spec;
use Test::More;

use LastROActivity::Rules;
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
		my $rule = {
			event_id => 'city_monster_party',
			enabled => 1,
			announce_regex => '城市魔物派对',
			start_regex => '城市魔物派对将在',
			lead_seconds => 10,
		};
		my $armed = $scheduler->observe($rule, '城市魔物派对将在2小时后开始', 1_000);

		is($armed->{event_id}, 'city_monster_party', 'stores event ID');
		is($armed->{start_at}, 8_200, 'computes start time');
		is($armed->{trigger_at}, 8_190, 'triggers at start minus ten seconds');
		is(scalar @{$scheduler->due(8_189)}, 0, 'does not trigger early');
		is(scalar @{$scheduler->due(8_190)}, 1, 'triggers at the ten-second boundary');
		is(scalar @{$scheduler->due(9_000)}, 0, 'dispatched event is not returned twice');

		my $unrelated_scheduler = LastROActivity::Scheduler->new(lead_seconds => 10);
		ok(
			!defined $unrelated_scheduler->observe(
				$rule,
				'维护将在2小时后开始',
				10_000,
			),
			'unrelated countdown does not arm the activity rule',
		);
		is(
			scalar @{$unrelated_scheduler->due(20_000)},
			0,
			'unrelated countdown does not become due',
		);

		my $immediate_rule = {
			event_id => 'lottery',
			enabled => 1,
			announce_regex => '活动',
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
		my $rule = {
			event_id => 'city_monster_party',
			enabled => 1,
			announce_regex => '城市魔物派对',
			start_regex => '城市魔物派对将在',
			lead_seconds => 10,
		};
		$scheduler->observe($rule, '城市魔物派对将在1分钟后开始', 2_000);
		my $replacement = $scheduler->observe($rule, '城市魔物派对将在1分钟后开始', 2_001);

		is($replacement->{trigger_at}, 2_051, 'replacement uses the latest receipt time');
		is(scalar @{$scheduler->due(2_050)}, 0, 'old duplicate timer is removed');
		is(scalar @{$scheduler->due(2_051)}, 1, 'duplicate announcements share one timer');

		my $early_rule = {
			event_id => 'early',
			enabled => 1,
			announce_regex => 'early',
			start_regex => 'early将在',
			lead_seconds => 10,
			priority => 1,
		};
		my $high_priority_rule = {
			event_id => 'high',
			enabled => 1,
			announce_regex => 'high',
			start_regex => 'high将在',
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

		my $countdown_without_start = {
			event_id => 'missing_start',
			enabled => 1,
			announce_regex => 'missing start',
			lead_seconds => 10,
		};
		ok(!defined $scheduler->observe(
			$countdown_without_start,
			'missing start将在2小时后开始',
			7_000,
		), 'countdown cannot arm an enabled rule without start evidence');
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
			announce_regex => '活动',
			start_regex => '活动将在',
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
			announce_regex => '活动',
			start_regex => '活动将在',
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

	subtest 'routes confirmed LastRO announcements and ignores long reminders' => sub {
		my ($rules, $errors) = LastROActivity::Rules::load_file(
			File::Spec->catfile($RealBin, '..', 'control', 'lastro_activity.txt'),
		);
		is_deeply(
			$errors,
			[
				'city_monster_party: entry_item_id is required for airship entry',
				'city_monster_party: search_targets evidence is required for shared search mode',
				'dungeon_monster_party: announce_regex required when enabled',
				'dungeon_monster_party: start_regex required when enabled',
				'dojo_challenge: entry_item_id is required for airship entry',
				'dojo_challenge: search_targets evidence is required for shared search mode',
				'pool_challenge: entry_item_id is required for airship entry',
				'pool_challenge: search_targets evidence is required for shared search mode',
				'lottery: entry_npc_trusted=1 is required for NPC entry',
				'lottery: entry_npc_evidence is required for NPC entry',
				'sky_chest: announce_regex required when enabled',
				'sky_chest: start_regex required when enabled',
			],
			'raw-enabled sections without announcement evidence fail closed during parsing',
		);

		my @cases = (
			{
				id => 'dojo_challenge',
				messages => [
					'[随机事件] 梦罗克道场将在1分钟后开启，深渊挑战即将开始 data-map="morocc#159#99"',
					'[随机事件] 梦罗克道场将在30秒后开启，深渊挑战即将开始 data-map="morocc#159#99"',
					'[随机事件] 梦罗克道场将在10秒后开启，深渊挑战即将开始 data-map="morocc#159#99"',
				],
				finish => '梦罗克道场入口已关闭，深渊挑战已开始',
				map => {map => 'morocc', x => 159, y => 99},
			},
			{
				id => 'pool_challenge',
				messages => [
					'[随机事件] 斐杨道场将在1分钟后开启，深渊挑战即将开始 data-map="payon#184#102"',
					'[随机事件] 斐杨道场将在30秒后开启，深渊挑战即将开始 data-map="payon#184#102"',
					'[随机事件] 斐杨道场将在10秒后开启，深渊挑战即将开始 data-map="payon#184#102"',
				],
				finish => '斐杨道场入口已关闭，深渊挑战已开始',
				map => {map => 'payon', x => 184, y => 102},
			},
			{
				id => 'lottery',
				messages => [
					'[随机事件] 抽奖活动60秒后开始啦 data-map="prontera#152#129"',
					'[随机事件] 抽奖活动30秒后开始啦 data-map="prontera#152#129"',
					'[随机事件] 抽奖活动10秒后开始啦 data-map="prontera#152#129"',
				],
				finish => '抽奖活动已结束',
				map => {map => 'prontera', x => 152, y => 129},
			},
			{
				id => 'city_monster_party',
				messages => [
					'[随机事件] 10秒后召唤师将在依斯鲁得岛举办魔物派对 data-map="pvp_y_5-2#0#0"',
				],
				finish => '魔物派对已结束',
				map => {map => 'pvp_y_5-2', x => 0, y => 0},
			},
		);

		my $scheduler = LastROActivity::Scheduler->new(lead_seconds => 10);
		my %routing_rules = map {
			my $source = $rules->{$_};
			$_ => {
				event_id => $_,
				enabled => 1,
				announce_regex => $source->{announce_regex},
				start_regex => $source->{start_regex},
				finish_regex => $source->{finish_regex},
				lead_seconds => $source->{lead_seconds},
				map_source => $source->{map_source},
			};
		} qw(dojo_challenge pool_challenge lottery city_monster_party);
		my $received_at = 50_000;
		for my $case (@cases) {
			# The production parser intentionally disables incomplete typed rules.
			# These projections are scheduler-only synthetic fixtures, so the
			# assertions exercise regex/countdown/map extraction independently of the
			# lifecycle evidence gate.
			my $rule = $routing_rules{$case->{id}};
			ok($rule->{enabled}, "$case->{id} is enabled for announcement routing");
			for my $message (@{$case->{messages}}) {
				like($message, qr/$rule->{announce_regex}/,
					"$case->{id} announcement matches announce_regex");
				like($message, qr/$rule->{start_regex}/,
					"$case->{id} announcement matches start_regex");
				my $countdown = LastROActivity::Scheduler::parse_countdown($message);
				ok(defined $countdown, "$case->{id} variant has a parsed countdown");
				my $event = $scheduler->observe($rule, $message, $received_at);
				ok($event, "$case->{id} announcement arms one event");
				is($event->{countdown_seconds}, $countdown,
					"$case->{id} preserves the countdown duration");
				is_deeply($event->{data_map}, $case->{map},
					"$case->{id} preserves dynamic map metadata");
				my $expected_trigger = $received_at + $countdown - 10;
				$expected_trigger = $received_at if $expected_trigger < $received_at;
				is($event->{trigger_at}, $expected_trigger,
					"$case->{id} uses the ten-second lead window");
				like($case->{finish}, qr/$rule->{finish_regex}/,
					"$case->{id} finish text matches finish_regex");
				$received_at += 100;
			}
		}

		my $party = $routing_rules{city_monster_party};
		my $immediate_scheduler = LastROActivity::Scheduler->new(lead_seconds => 10);
		my $immediate = $immediate_scheduler->observe(
			$party,
			'[随机事件] 10秒后召唤师将在依斯鲁得岛举办魔物派对 data-map="pvp_y_5-2#0#0"',
			60_000,
		);
		is($immediate->{trigger_at}, 60_000, '10-second party announcement triggers at receipt time');
		is(scalar @{$immediate_scheduler->due(60_000)}, 1, '10-second party announcement is due immediately');

		my $reminder = '[随机事件] 下一次事件将在2小时后发生，梦罗克道场稍后开放 data-map="morocc#159#99"';
		ok(!defined $scheduler->observe($rules->{dojo_challenge}, $reminder, 70_000),
			'long 下一次事件 reminder never arms a dojo rule');
		ok(!defined $scheduler->observe($rules->{city_monster_party},
			'[随机事件] 下一次事件将在10秒后发生，召唤师将在依斯鲁得岛举办魔物派对 data-map="pvp_y_5-2#0#0"',
			70_001,
		), '下一次事件 reminder never arms a party rule');

		my @invasion_cases = (
			['alberta', '[随机事件] invasion data-map="alberta#0#0"'],
			['aldebaran', '[随机事件] invasion data-map="aldebaran#0#0"'],
		);
		my @routing_ids = qw(city_monster_party dojo_challenge pool_challenge lottery);
		for my $invasion (@invasion_cases) {
			my ($map, $message) = @$invasion;
			is_deeply(
				LastROActivity::Scheduler::extract_data_map($message),
				{map => $map, x => 0, y => 0},
				"$map invasion data-map is parsed but remains unbound",
			);
			for my $event_id (@routing_ids) {
				ok(!defined $scheduler->observe($rules->{$event_id}, $message, 71_000),
					"$map invasion does not arm $event_id");
			}
		}
		done_testing();
	};
}

1;
