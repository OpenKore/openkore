package RulesTest;

use strict;
use warnings;
use utf8;

use FindBin qw($RealBin);
use File::Spec;
use Test::More;

use LastROActivity::Rules;

sub start {
	subtest 'parses the documented rule fields' => sub {
		my ($rules, $errors) = LastROActivity::Rules::parse_text(<<'RULES');
[lottery]
enabled=0
announce_regex=抽奖活动
lead_seconds=10
entry_type=npc
entry_map=prontera
entry_x=152
entry_y=129
entry_npc=活动负责人#iz
return_policy=privateairship:prontera

[bad_rule]
enabled=1
announce_regex=bad
entry_type=unknown
RULES

		is($rules->{lottery}{entry_map}, 'prontera', 'parses fixed NPC map');
		is($rules->{lottery}{entry_x}, 152, 'parses NPC x coordinate');
		is($rules->{lottery}{lead_seconds}, 10, 'parses ten-second lead');
		ok(!$rules->{lottery}{enabled}, 'lottery remains disabled without dialog data');
		is_deeply($errors, ['bad_rule: invalid entry_type unknown'], 'reports invalid enabled rule');
		ok(!$rules->{bad_rule}{enabled}, 'invalid rule is not enabled');
		is_deeply($rules->{lottery}{validation_errors}, [], 'valid disabled rule has no validation errors');
		done_testing();
	};

	subtest 'validates enabled rules without changing direct input' => sub {
		my $rule = {
			enabled => 1,
			announce_regex => '',
			entry_type => 'npc',
		};
		is_deeply(
			LastROActivity::Rules::validate_rule($rule),
			['announce_regex required when enabled'],
			'requires announcement evidence for enabled rules',
		);
		is($rule->{enabled}, 1, 'validator does not mutate direct rule input');
		is_deeply(
			LastROActivity::Rules::validate_rule({enabled => 0}),
			[],
			'allows a disabled rule without announcement evidence',
		);
		done_testing();
	};

	subtest 'attaches parser syntax errors and reports orphan syntax' => sub {
		my ($rules, $errors) = LastROActivity::Rules::parse_text(<<'RULES');
orphan=1

[broken]
enabled=1
announce_regex=ready
malformed syntax
=bad
RULES

		is_deeply(
			$errors,
			[
				'line 1: setting outside an event section',
				'broken: malformed setting on line 6',
				'broken: empty setting name on line 7',
			],
			'reports syntax errors in source order',
		);
		ok(!$rules->{broken}{enabled}, 'syntax errors disable the affected rule');
		is_deeply(
			$rules->{broken}{validation_errors},
			[
				'malformed setting on line 6',
				'empty setting name on line 7',
			],
			'attaches syntax errors to the affected rule',
		);
		done_testing();
	};

	subtest 'rejects empty numeric values' => sub {
		my ($rules, $errors) = LastROActivity::Rules::parse_text(<<'RULES');
[empty_numeric]
enabled=1
announce_regex=ready
lead_seconds=
duration_seconds=
RULES

		is_deeply(
			$errors,
			[
				'empty_numeric: duration_seconds must be an integer',
				'empty_numeric: lead_seconds must be an integer',
			],
			'rejects explicit empty numeric settings',
		);
		ok(!$rules->{empty_numeric}{enabled}, 'empty numeric settings disable the rule');
		is_deeply(
			$rules->{empty_numeric}{validation_errors},
			[
				'duration_seconds must be an integer',
				'lead_seconds must be an integer',
			],
			'attaches empty numeric errors to the rule',
		);
		done_testing();
	};

	subtest 'rejects reserved rule keys without corrupting parser state' => sub {
		my ($rules, $errors) = LastROActivity::Rules::parse_text(<<'RULES');
[canonical]
event_id=spoofed
enabled=1
announce_regex=ready

[phase_bomb]
enabled=1
announce_regex=ready
_phase_data=oops
phase.1.name=opening
RULES

		is_deeply(
			$errors,
			[
				'canonical: reserved key event_id',
				'phase_bomb: reserved key _phase_data',
			],
			'rejects section identity and internal state overrides',
		);
		is($rules->{canonical}{event_id}, 'canonical', 'preserves canonical section event ID');
		ok(!$rules->{canonical}{enabled}, 'reserved event ID error disables the rule');
		ok(!$rules->{phase_bomb}{enabled}, 'reserved internal key error disables the rule');
		is_deeply(
			$rules->{phase_bomb}{phases},
			[{name => 'opening'}],
			'valid phase data still materializes after a rejected internal key',
		);
		done_testing();
	};

	subtest 'normalizes numeric, search, and phase fields' => sub {
		my ($rules, $errors) = LastROActivity::Rules::parse_text(<<'RULES');
[complex]
enabled=1
announce_regex=activity=ready
start_regex=activity started
finish_regex=activity finished
lead_seconds=07
map_source=announcement
entry_type=airship
entry_map=event_map
entry_x=015
entry_y=27
entry_npc=Event Guide
duration_seconds=0900
entry_macro=enter_event
finish_macro=finish_event
return_policy=privateairship:prontera
search_targets=Dragon Egg,  Golden Thief ,MVP
phase.2.name=final
phase.2.finish_regex=final complete
phase.2.timeout_seconds=600
phase.1.name=opening
phase.1.finish_regex=opening complete
phase.1.timeout_seconds=180
RULES

		is_deeply($errors, [], 'complete rule has no errors');
		is($rules->{complex}{enabled}, 1, 'normalizes enabled flag');
		is($rules->{complex}{lead_seconds}, 7, 'normalizes lead seconds');
		is($rules->{complex}{entry_x}, 15, 'normalizes x coordinate');
		is($rules->{complex}{entry_y}, 27, 'normalizes y coordinate');
		is($rules->{complex}{duration_seconds}, 900, 'normalizes duration');
		is($rules->{complex}{announce_regex}, 'activity=ready', 'splits values on the first equals sign');
		is_deeply(
			$rules->{complex}{search_targets},
			['Dragon Egg', 'Golden Thief', 'MVP'],
			'splits and trims comma-separated search metadata',
		);
		is_deeply(
			$rules->{complex}{phases},
			[
				{
					name => 'opening',
					finish_regex => 'opening complete',
					timeout_seconds => 180,
				},
				{
					name => 'final',
					finish_regex => 'final complete',
					timeout_seconds => 600,
				},
			],
			'orders phases by numeric index',
		);
		done_testing();
	};

	subtest 'rejects duplicates and invalid values while preserving disabled state' => sub {
		my ($rules, $errors) = LastROActivity::Rules::parse_text(<<'RULES');
[duplicate]
enabled=0
announce_regex=first

[duplicate]
announce_regex=second

[invalid]
enabled=0
entry_type=unknown
duration_seconds=0
lead_seconds=-1

[malformed_enabled]
enabled=not-a-flag
announce_regex=ignored

[out_of_range]
enabled=2
announce_regex=ready

[negative_enabled]
enabled=-1
announce_regex=ready
RULES

		is($rules->{duplicate}{announce_regex}, 'first', 'keeps the first definition');
		is_deeply(
			$errors,
			[
				'duplicate: duplicate event_id duplicate',
				'invalid: invalid entry_type unknown',
				'invalid: duration_seconds must be positive',
				'invalid: lead_seconds must be non-negative',
				'malformed_enabled: enabled must be 0 or 1',
				'out_of_range: enabled must be 0 or 1',
				'negative_enabled: enabled must be 0 or 1',
			],
			'aggregates duplicate and validation errors in source order',
		);
		ok(!$rules->{invalid}{enabled}, 'invalid disabled rule remains disabled');
		ok(!$rules->{malformed_enabled}{enabled}, 'malformed enabled value fails closed');
		ok(!$rules->{out_of_range}{enabled}, 'out-of-range enabled value fails closed');
		ok(!$rules->{negative_enabled}{enabled}, 'negative enabled value fails closed');
		is_deeply(
			$rules->{invalid}{validation_errors},
			[
				'invalid entry_type unknown',
				'duration_seconds must be positive',
				'lead_seconds must be non-negative',
			],
			'attaches validation errors to the affected rule',
		);
		done_testing();
	};

	subtest 'loads the safe UTF-8 fixture' => sub {
		my $rules_file = File::Spec->catfile($RealBin, '..', 'control', 'lastro_activity.txt');
		my ($rules, $errors) = LastROActivity::Rules::load_file($rules_file);
		my @expected_ids = qw(
			city_monster_party
			dungeon_monster_party
			dojo_challenge
			pool_challenge
			lottery
			sky_chest
		);

		is_deeply([sort keys %{$rules}], [sort @expected_ids], 'fixture contains exactly six event rules');
		is_deeply($errors, [], 'safe fixture has no parser errors');
		for my $event_id (@expected_ids) {
			ok(!$rules->{$event_id}{enabled}, "$event_id starts disabled");
		}
		is($rules->{lottery}{entry_map}, 'prontera', 'fixture retains confirmed lottery map');
		is($rules->{lottery}{entry_x}, 152, 'fixture retains confirmed lottery x coordinate');
		is($rules->{lottery}{entry_y}, 129, 'fixture retains confirmed lottery y coordinate');
		is($rules->{lottery}{entry_npc}, '活动负责人#iz', 'fixture retains confirmed lottery NPC');
		done_testing();
	};
}

1;
