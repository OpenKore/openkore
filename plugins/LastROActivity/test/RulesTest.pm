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
entry_y=133
entry_npc_name=活动负责人#iz
entry_dialog_mode=repeat_first_until_finish
return_policy=tt:prontera

[bad_rule]
enabled=1
announce_regex=bad
start_regex=bad
entry_type=unknown
RULES

		is($rules->{lottery}{entry_map}, 'prontera', 'parses fixed NPC map');
		is($rules->{lottery}{entry_x}, 152, 'parses NPC x coordinate');
		is($rules->{lottery}{entry_y}, 133, 'parses confirmed NPC y coordinate');
		is($rules->{lottery}{entry_npc_name}, '活动负责人#iz', 'parses exact NPC name');
		is($rules->{lottery}{entry_dialog_mode}, 'repeat_first_until_finish',
			'parses repeating dialog mode');
		is($rules->{lottery}{return_policy}, 'tt:prontera', 'parses canonical return policy');
		is($rules->{lottery}{lead_seconds}, 10, 'parses ten-second lead');
		ok(!$rules->{lottery}{enabled}, 'explicitly disabled Lottery rule remains disabled');
		is_deeply($errors, ['bad_rule: invalid entry_type unknown'], 'reports invalid enabled rule');
		ok(!$rules->{bad_rule}{enabled}, 'invalid rule is not enabled');
		is_deeply($rules->{lottery}{validation_errors}, [], 'valid disabled rule has no validation errors');
		done_testing();
	};

	subtest 'accepts canonical tt routing and legacy transfer aliases' => sub {
		my ($rules, $errors) = LastROActivity::Rules::parse_text(<<'RULES');
[canonical]
enabled=1
announce_regex=START
start_regex=START
finish_regex=DONE
map_source=static
entry_type=tt
entry_map=prontera
entry_x=10
entry_y=20
return_policy=tt:prontera
search_targets=1002

[legacy_airship]
enabled=1
announce_regex=START
start_regex=START
finish_regex=DONE
map_source=static
entry_type=airship
entry_map=prontera
return_policy=privateairship:prontera
search_targets=1002

[legacy_privateairship]
enabled=1
announce_regex=START
start_regex=START
finish_regex=DONE
map_source=static
entry_type=privateairship
entry_map=prontera
return_policy=privateairship:prontera
search_targets=1002

[dialog_compatible]
enabled=0
entry_type=npc
entry_dialog_mode=repeat_first_until_finish

[bad_return]
enabled=1
announce_regex=START
start_regex=START
finish_regex=DONE
map_source=static
entry_type=tt
entry_map=prontera
return_policy=tt:payon
search_targets=1002
RULES

		is_deeply($errors, ['bad_return: return_policy must be tt:prontera'],
			'canonical tt rule validates while non-prontera return is rejected');
		is($rules->{canonical}{entry_type}, 'tt', 'tt is a supported entry type');
		is($rules->{canonical}{return_policy}, 'tt:prontera',
			'tt:prontera is the canonical return policy');
		ok($rules->{legacy_airship}{enabled},
			'airship remains accepted as a tt compatibility input without an item ID');
		ok($rules->{legacy_privateairship}{enabled},
			'privateairship remains accepted as a tt compatibility input without an item ID');
		is($rules->{dialog_compatible}{entry_dialog_mode}, 'repeat_first_until_finish',
			'preserves the deferred NPC dialog mode field');
		done_testing();
	};

	subtest 'parses and validates the named repeating Lottery dialog metadata' => sub {
		my ($rules, $errors) = LastROActivity::Rules::parse_text(<<'RULES');
[lottery]
enabled=1
announce_regex=抽奖活动
start_regex=抽奖活动.*秒后
finish_regex=抽奖活动已结束
map_source=static
entry_type=npc
entry_map=prontera
entry_x=152
entry_y=133
entry_npc_name=活动负责人#iz
entry_dialog_mode=repeat_first_until_finish
return_policy=tt:prontera
RULES

	is_deeply($errors, [], 'named Lottery rule has no validation errors');
	ok($rules->{lottery}{enabled}, 'named Lottery rule remains enabled');
	is($rules->{lottery}{entry_npc_name}, '活动负责人#iz',
		'NPC suffix is retained as part of the exact name');
	is($rules->{lottery}{entry_dialog_mode}, 'repeat_first_until_finish',
		'named Lottery rule selects the repeating dialog mode');
	is($rules->{lottery}{entry_map}, 'prontera', 'named Lottery map is exact');
	is($rules->{lottery}{entry_x}, 152, 'named Lottery X coordinate is exact');
	is($rules->{lottery}{entry_y}, 133, 'named Lottery Y coordinate is exact');

	my @invalid_cases = (
		[
			'missing name',
			qr/entry_npc_name is required for repeating NPC dialog/,
		],
		[
			'missing coordinate',
			qr/entry_y is required for NPC entry/,
		],
		[
			'unknown dialog mode',
			qr/entry_dialog_mode must be repeat_first_until_finish/,
		],
		[
			'missing finish pattern',
			qr/finish_regex is required for repeating NPC dialog/,
		],
		[
			'malformed finish pattern',
			qr/finish_regex is invalid/,
		],
	);
	for my $case (@invalid_cases) {
		my ($label, $error_pattern) = @$case;
		my $text = <<'RULES';
[lottery]
enabled=1
announce_regex=抽奖活动
start_regex=抽奖活动.*秒后
finish_regex=抽奖活动已结束
map_source=static
entry_type=npc
entry_map=prontera
entry_x=152
entry_y=133
entry_npc_name=活动负责人#iz
entry_dialog_mode=repeat_first_until_finish
duration_seconds=900
return_policy=tt:prontera
RULES
		$text =~ s/entry_npc_name=活动负责人#iz\n/entry_npc_name=\n/ if $label eq 'missing name';
		$text =~ s/entry_y=133\n/entry_y=\n/ if $label eq 'missing coordinate';
		$text =~ s/entry_dialog_mode=repeat_first_until_finish\n/entry_dialog_mode=guess_first\n/ if $label eq 'unknown dialog mode';
		$text =~ s/finish_regex=抽奖活动已结束\n// if $label eq 'missing finish pattern';
		$text =~ s/finish_regex=抽奖活动已结束\n/finish_regex=[\n/ if $label eq 'malformed finish pattern';
		my ($invalid, $invalid_errors) = LastROActivity::Rules::parse_text($text);
		ok(!$invalid->{lottery}{enabled}, "$label disables the rule");
		like(join('; ', @{$invalid->{lottery}{validation_errors} || []}), $error_pattern,
			"$label records a specific validation error");
		ok(@$invalid_errors, "$label is reported to the parser caller");
	}
		done_testing();
	};

	subtest 'validates enabled rules without changing direct input' => sub {
		my $rule = {
			enabled => 1,
			announce_regex => '',
		};
		is_deeply(
			LastROActivity::Rules::validate_rule($rule),
			['announce_regex required when enabled', 'start_regex required when enabled'],
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

	subtest 'rejects malformed enabled runtime patterns and non-canonical returns' => sub {
		my ($rules, $errors) = LastROActivity::Rules::parse_text(<<'RULES');
[bad_announce]
enabled=1
announce_regex=[
start_regex=START
entry_type=macro
entry_macro=enter_event
duration_seconds=60
return_policy=privateairship:prontera

[bad_finish]
enabled=1
announce_regex=START
start_regex=START
finish_regex=[
entry_type=macro
entry_macro=enter_event
duration_seconds=60
return_policy=privateairship:prontera

[bad_round]
enabled=1
announce_regex=START
start_regex=START
round_start_regex=[
round_success_regex=ROUND OK
entry_type=macro
entry_macro=enter_event
duration_seconds=60
return_policy=privateairship:prontera

[bad_round_id]
enabled=1
announce_regex=START
start_regex=START
round_start_regex=ROUND .+ START
round_id_regex=[
round_success_regex=ROUND OK
entry_type=macro
entry_macro=enter_event
duration_seconds=60
return_policy=privateairship:prontera

[bad_phase]
enabled=1
announce_regex=START
start_regex=START
entry_type=macro
entry_macro=enter_event
duration_seconds=60
phase.1.finish_regex=[
return_policy=privateairship:prontera

[bad_return]
enabled=1
announce_regex=START
start_regex=START
entry_type=macro
entry_macro=enter_event
duration_seconds=60
return_policy=privateairship:payon
RULES

		for my $id (qw(bad_announce bad_finish bad_round bad_round_id bad_phase bad_return)) {
			ok(!$rules->{$id}{enabled}, "$id is disabled after validation failure");
			ok(@{$rules->{$id}{validation_errors} || []}, "$id keeps validation errors");
		}
		like(join('; ', @{$rules->{bad_announce}{validation_errors}}), qr/announce_regex.*invalid/i,
			'malformed announcement regex is rejected by the parser');
		like(join('; ', @{$rules->{bad_finish}{validation_errors}}), qr/finish_regex.*invalid/i,
			'malformed finish regex is rejected by the parser');
		like(join('; ', @{$rules->{bad_round}{validation_errors}}), qr/round_start_regex.*invalid/i,
			'malformed round regex is rejected by the parser');
		like(join('; ', @{$rules->{bad_round_id}{validation_errors}}), qr/round_id_regex.*invalid/i,
			'malformed round identity regex is rejected by the parser');
		like(join('; ', @{$rules->{bad_phase}{validation_errors}}), qr/phase.*pattern.*invalid|phase.*invalid/i,
			'malformed phase regex is rejected by the parser');
		like(join('; ', @{$rules->{bad_return}{validation_errors}}), qr/return_policy/i,
			'non-canonical return policy is rejected by the parser');
		done_testing();
	};

	subtest 'disables explicitly configured entry rules when lifecycle evidence is incomplete' => sub {
		my ($rules, $errors) = LastROActivity::Rules::parse_text(<<'RULES');
[incomplete_airship]
enabled=1
announce_regex=ready
start_regex=starts
finish_regex=done
map_source=static
entry_map=prontera
entry_type=privateairship
return_policy=privateairship:prontera
search_targets=

[incomplete_npc]
enabled=1
announce_regex=ready
start_regex=starts
finish_regex=done
map_source=static
entry_map=prontera
entry_type=npc
entry_x=152
entry_y=129
entry_npc=Guide#c
return_policy=privateairship:prontera
RULES

		is_deeply(
			$errors,
			[
				'incomplete_airship: search_targets evidence is required for shared search mode',
				'incomplete_npc: entry_npc_trusted=1 is required for NPC entry',
				'incomplete_npc: entry_npc_evidence is required for NPC entry',
			],
			'rejects enabled entry rules without search or trusted NPC evidence',
		);
		ok(!$rules->{incomplete_airship}{enabled},
			'airship rule is effectively disabled before scheduling');
		ok(!$rules->{incomplete_npc}{enabled},
			'NPC rule is effectively disabled before scheduling');
		like(join('; ', @{$rules->{incomplete_airship}{validation_errors}}),
			qr/search_targets/,
			'airship compatibility rule keeps its search evidence error');
		like(join('; ', @{$rules->{incomplete_npc}{validation_errors}}),
			qr/entry_npc_trusted.*entry_npc_evidence|entry_npc_evidence.*entry_npc_trusted/,
			'NPC evidence errors are attached to the parsed rule');
		done_testing();
	};

	subtest 'requires scheduler start evidence and documents transfer timeout' => sub {
		my ($rules, $errors) = LastROActivity::Rules::parse_text(<<'RULES');
[valid_timeout]
enabled=0
timeout_seconds=45

[invalid_timeout]
enabled=1
announce_regex=ready
start_regex=starts
timeout_seconds=0

[missing_start]
enabled=1
announce_regex=ready
timeout_seconds=45
RULES

		is($rules->{valid_timeout}{timeout_seconds}, 45,
			'parses the canonical top-level timeout_seconds field');
		is_deeply(
			$errors,
			[
				'invalid_timeout: timeout_seconds must be positive',
				'missing_start: start_regex required when enabled',
			],
			'rejects non-positive timeouts and missing start evidence',
		);
		ok(!$rules->{invalid_timeout}{enabled}, 'invalid timeout disables the rule');
		ok(!$rules->{missing_start}{enabled}, 'missing start evidence disables the rule');

		my $bad_source = {
			enabled => 1,
			announce_regex => 'ready',
			start_regex => 'starts',
			map_source => 'arbitrary',
		};
		is_deeply(
			LastROActivity::Rules::validate_rule($bad_source),
			['map_source must be static, dynamic, or announcement'],
			'rejects undocumented map-source values in direct validation',
		);
		done_testing();
	};

	subtest 'attaches parser syntax errors and reports orphan syntax' => sub {
		my ($rules, $errors) = LastROActivity::Rules::parse_text(<<'RULES');
orphan=1

[broken]
enabled=1
announce_regex=ready
start_regex=ready
malformed syntax
=bad
RULES

		is_deeply(
			$errors,
			[
				'line 1: setting outside an event section',
				'broken: malformed setting on line 7',
				'broken: empty setting name on line 8',
			],
			'reports syntax errors in source order',
		);
		ok(!$rules->{broken}{enabled}, 'syntax errors disable the affected rule');
		is_deeply(
			$rules->{broken}{validation_errors},
			[
				'malformed setting on line 7',
				'empty setting name on line 8',
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
start_regex=ready
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
start_regex=ready

[phase_bomb]
enabled=1
announce_regex=ready
start_regex=ready
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
entry_item_id=14527
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

	subtest 'defaults and parses dojo round and leave policy fields' => sub {
		my ($rules, $errors) = LastROActivity::Rules::parse_text(<<'RULES');
[dojo_defaults]
enabled=0

[dojo_rounds]
enabled=0
announce_regex=dojo
start_regex=dojo starts
finish_regex=dojo done
round_start_regex=round starts
round_id_regex=round (\d+) starts
round_success_regex=round cleared
max_rounds=5
resurrection_wait_seconds=45
leave_npc=Central Guide#ok,yes
leave_npc_trusted=1
leave_npc_evidence=server transcript
leave_x=12
leave_y=34
RULES

		is_deeply($errors, [], 'round and leave fields parse without errors');
		is($rules->{dojo_defaults}{max_rounds}, 3,
			'dojo rules default max_rounds to three');
		is($rules->{dojo_defaults}{resurrection_wait_seconds}, 30,
			'dojo rules default resurrection wait to thirty seconds');
		is($rules->{dojo_rounds}{max_rounds}, 5,
			'parses a configured maximum round count');
		is($rules->{dojo_rounds}{resurrection_wait_seconds}, 45,
			'parses a configured resurrection wait');
		is($rules->{dojo_rounds}{round_start_regex}, 'round starts',
			'parses round start evidence');
		is($rules->{dojo_rounds}{round_id_regex}, 'round (\d+) starts',
			'parses round identity evidence');
		is($rules->{dojo_rounds}{round_success_regex}, 'round cleared',
			'parses round success evidence');
		is($rules->{dojo_rounds}{leave_npc}, 'Central Guide#ok,yes',
			'parses the leave NPC sequence');
		is($rules->{dojo_rounds}{leave_x}, 12, 'parses leave NPC x coordinate');
		is($rules->{dojo_rounds}{leave_y}, 34, 'parses leave NPC y coordinate');
		done_testing();
	};

	subtest 'validates the canonical airship item ID field' => sub {
		my ($rules, $errors) = LastROActivity::Rules::parse_text(<<'RULES');
[valid_item]
enabled=0
entry_item_id=14527

[zero_item]
enabled=1
announce_regex=ready
start_regex=ready
entry_item_id=0

[bad_item]
enabled=1
announce_regex=ready
start_regex=ready
entry_item_id=not_numeric

[alias_item]
enabled=1
announce_regex=ready
start_regex=ready
private_airship_item_id=14527
RULES

	is($rules->{valid_item}{entry_item_id}, 14527, 'parses the canonical item ID');
	is_deeply(
		$errors,
		[
			'zero_item: entry_item_id must be positive',
			'bad_item: entry_item_id must be an integer',
			'alias_item: unsupported key private_airship_item_id',
		],
		'rejects invalid and undeclared item fields',
	);
	ok(!$rules->{zero_item}{enabled}, 'zero item ID disables the rule');
	ok(!$rules->{bad_item}{enabled}, 'non-numeric item ID disables the rule');
	ok(!$rules->{alias_item}{enabled}, 'undeclared item alias disables the rule');
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
start_regex=ignored

[out_of_range]
enabled=2
announce_regex=ready
start_regex=ready

[negative_enabled]
enabled=-1
announce_regex=ready
start_regex=ready
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
		is_deeply(
			$errors,
			[
				'city_monster_party: search_targets evidence is required for shared search mode',
				'dungeon_monster_party: announce_regex required when enabled',
				'dungeon_monster_party: start_regex required when enabled',
				'dojo_challenge: search_targets evidence is required for shared search mode',
				'pool_challenge: search_targets evidence is required for shared search mode',
				'sky_chest: announce_regex required when enabled',
				'sky_chest: start_regex required when enabled',
			],
			'raw-enabled sections without announcement evidence fail closed during parsing',
		);
		for my $event_id (@expected_ids) {
			my $expected_enabled = $event_id eq 'lottery' ? 1 : 0;
			is($rules->{$event_id}{enabled}, $expected_enabled,
				"$event_id has the expected effective enable state");
		}
		ok(!$rules->{dungeon_monster_party}{enabled},
			'dungeon_monster_party is effectively disabled after parser validation');
		ok(!$rules->{sky_chest}{enabled},
			'sky_chest is effectively disabled after parser validation');
		is($rules->{lottery}{entry_map}, 'prontera', 'fixture retains confirmed lottery map');
		is($rules->{lottery}{entry_x}, 152, 'fixture retains confirmed lottery x coordinate');
		is($rules->{lottery}{entry_y}, 133, 'fixture retains confirmed lottery y coordinate');
		is($rules->{lottery}{entry_npc_name}, '活动负责人#iz',
			'fixture retains confirmed lottery NPC name');
		is($rules->{lottery}{entry_dialog_mode}, 'repeat_first_until_finish',
			'fixture retains repeating Lottery dialog mode');
		is($rules->{lottery}{return_policy}, 'tt:prontera',
			'fixture uses the canonical Lottery return policy');
		ok(!defined $rules->{lottery}{entry_item_id},
			'fixture does not require a Lottery entry item');
		ok(!defined $rules->{lottery}{entry_npc},
			'fixture does not use a TalkNPC sequence for Lottery');
		done_testing();
	};

	subtest 'loads the confirmed announcement evidence without inventing lifecycle data' => sub {
		my $rules_file = File::Spec->catfile($RealBin, '..', 'control', 'lastro_activity.txt');
		my ($rules, $errors) = LastROActivity::Rules::load_file($rules_file);
		is_deeply(
			$errors,
			[
				'city_monster_party: search_targets evidence is required for shared search mode',
				'dungeon_monster_party: announce_regex required when enabled',
				'dungeon_monster_party: start_regex required when enabled',
				'dojo_challenge: search_targets evidence is required for shared search mode',
				'pool_challenge: search_targets evidence is required for shared search mode',
				'sky_chest: announce_regex required when enabled',
				'sky_chest: start_regex required when enabled',
			],
			'incomplete raw-enabled sections fail closed during parsing',
		);

		open my $raw_fh, '<:encoding(UTF-8)', $rules_file
			or die "Unable to read $rules_file: $!";
		local $/;
		my $raw_text = <$raw_fh>;
		close $raw_fh;
		for my $event_id (qw(city_monster_party dungeon_monster_party dojo_challenge pool_challenge lottery sky_chest)) {
			like($raw_text, qr/\[$event_id\][^\[]*?\benabled=1\b/s,
				"$event_id keeps the requested raw enabled=1 flag");
		}
		ok(!$rules->{dungeon_monster_party}{enabled},
			'dungeon_monster_party effective rule is disabled');
		ok(!$rules->{sky_chest}{enabled}, 'sky_chest effective rule is disabled');

		my @routing_ids = qw(city_monster_party dojo_challenge pool_challenge lottery);
		for my $event_id (@routing_ids) {
			if ($event_id eq 'lottery') {
				ok($rules->{$event_id}{enabled}, 'lottery is effectively enabled with complete named-dialog evidence');
				is($rules->{$event_id}{map_source}, 'static', 'lottery uses its confirmed static NPC map');
			} else {
				ok(!$rules->{$event_id}{enabled}, "$event_id is effectively disabled before lifecycle evidence is complete");
				is($rules->{$event_id}{map_source}, 'dynamic', "$event_id uses dynamic announcement map metadata");
			}
		}

		is($rules->{dojo_challenge}{finish_regex}, '梦罗克道场入口已关闭，深渊挑战已开始',
			'morocc finish evidence is exact');
		is($rules->{pool_challenge}{finish_regex}, '斐杨道场入口已关闭，深渊挑战已开始',
			'payon finish evidence is exact');
		is($rules->{lottery}{finish_regex}, '抽奖活动已结束', 'lottery finish evidence is exact');
		is($rules->{city_monster_party}{finish_regex}, '魔物派对已结束',
			'monster party finish evidence is exact');
		is($rules->{lottery}{entry_npc_name}, '活动负责人#iz',
			'lottery identity keeps the exact NPC suffix');
		is($rules->{lottery}{entry_dialog_mode}, 'repeat_first_until_finish',
			'lottery repeats the first dialog option until finish');
		is($rules->{lottery}{entry_x}, 152, 'lottery static NPC x coordinate is exact');
		is($rules->{lottery}{entry_y}, 133, 'lottery static NPC y coordinate is exact');
		is($rules->{lottery}{return_policy}, 'tt:prontera', 'lottery uses tt for return');
		ok(!defined $rules->{lottery}{entry_npc_trusted},
			'lottery does not require legacy trust attestation');

		my $morocc = '[随机事件] 梦罗克道场将在1分钟后开启，深渊挑战即将开始';
		my $payon = '[随机事件] 斐杨道场将在30秒后开启，深渊挑战即将开始';
		my $lottery = '[随机事件] 抽奖活动60秒后开始啦';
		my $party = '[随机事件] 10秒后召唤师将在依斯鲁得岛举办魔物派对';
		like($morocc, qr/$rules->{dojo_challenge}{start_regex}/, 'morocc start evidence matches');
		like($payon, qr/$rules->{pool_challenge}{start_regex}/, 'payon start evidence matches');
		like($lottery, qr/$rules->{lottery}{start_regex}/, 'lottery start evidence matches');
		like($party, qr/$rules->{city_monster_party}{start_regex}/, 'party start evidence matches');
		unlike('[随机事件] 下一次事件将在2小时后发生，梦罗克道场稍后开放',
			qr/$rules->{dojo_challenge}{start_regex}/,
			'next-event reminder is not start evidence');
		done_testing();
	};
}

1;
