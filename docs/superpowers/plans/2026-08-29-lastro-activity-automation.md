# LastRO Activity Automation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** Add a LastRO activity plugin that waits for countdown announcements, interrupts normal OpenKore grinding only 10 seconds before an enabled event, participates through shared search-mode monster control or a macro, then returns to prontera, restores the original lockMap settings, and resumes normal grinding.

**Architecture:** Keep all lifecycle logic in a new LastROActivity plugin and its small pure-Perl support modules. Store event routing and announcement rules in a control file; keep combat targeting in the existing shared control/mon_control.txt by using its third search column. Reuse the existing LastroAirship command interceptor and the macro plugin for server-specific travel or NPC dialog instead of changing OpenKore core AI code.

**Tech Stack:** Perl 5, OpenKore plugin hooks and Commands::register, Settings::addControlFile, AI::clear, Commands::run, Task::TalkNPC, Test::More, and existing OpenKore test runners.

**Spec:** D:\ROWeb\docs\superpowers\specs\2026-08-29-lastro-activity-automation-design.md

## Global Constraints

- First phase covers only the six LastRO特色活动 from the Excel document; bounty, personal, and world tasks remain out of scope.
- A long countdown only creates an ARMED timer; it must not change AI state, lockMap, or teleport settings before the final lead window.
- Default lead_seconds is 10; a 10秒后 announcement triggers immediately.
- The trigger must clear the current attack without waiting for the monster to die.
- Temporary lockMap, lockMap_x/y, lockMap_randX/Y, teleportAuto_search, and teleportAuto_idle changes are in-memory only and must be restored on every exit path.
- Activity combat uses the shared control/mon_control.txt; task monsters use search=1 in the third column and the plugin does not create per-character combat profiles.
- Returning always requests privateairship prontera, waits for packet_mapChange, restores the saved lock/teleport values, calls AI::clear, and lets OpenKore's processLockMap route back.
- Unknown LastRO map names, monster names/IDs, NPC dialog steps, and finish messages must leave the corresponding rule disabled.
- Do not modify OpenKore core AI, route, or packet parsing code for this feature.
- LastROActivity must load after LastroAirship so Commands::run("privateairship ...") uses the existing server-specific adapter.

## File Map

- Create plugins/LastROActivity/LastROActivity.pl: plugin registration, hooks, commands, and OpenKore side effects.
- Create plugins/LastROActivity/LastROActivity/Rules.pm: deterministic parser and validator for the activity control file.
- Create plugins/LastROActivity/LastROActivity/Scheduler.pm: countdown parsing, duplicate announcements, and due-event selection with an injectable clock.
- Create plugins/LastROActivity/LastROActivity/State.pm: allowed lifecycle transitions, configuration snapshot, and temporary search/lockMap mutations.
- Create plugins/LastROActivity/control/lastro_activity.txt: safe event entries; only entries with confirmed server data may be enabled.
- Create plugins/LastROActivity/test/unit_tests.pl: test runner that resolves OPENKORE_DIR and loads the plugin test modules.
- Create plugins/LastROActivity/test/RulesTest.pm, SchedulerTest.pm, and StateTest.pm: pure unit coverage.
- Create plugins/LastROActivity/test/PluginTest.pm: hook/command integration tests using stubbed globals and callbacks.
- Modify control/config.txt: add global activity settings with the 10-second default and search teleport interval.
- Modify control/sys.txt: load LastROActivity immediately after LastroAirship.
- Do not modify control/mon_control.txt until the actual LastRO monster names/IDs and existing attack columns are confirmed; add only search=1 to the shared production rows in the data-confirmation task.

### Task 1: Add the activity rule parser and safe rule fixture

**Files:**
- Create: plugins/LastROActivity/LastROActivity/Rules.pm
- Create: plugins/LastROActivity/control/lastro_activity.txt
- Create: plugins/LastROActivity/test/RulesTest.pm
- Create: plugins/LastROActivity/test/unit_tests.pl

**Interfaces:**
- Produces LastROActivity::Rules::parse_text($text) -> ($rules_hashref, $errors_arrayref).
- Produces LastROActivity::Rules::load_file($path) -> ($rules_hashref, $errors_arrayref).
- Produces LastROActivity::Rules::validate_rule($rule_hashref) -> $errors_arrayref.
- A parsed rule has event_id, enabled, announce_regex, start_regex, finish_regex, lead_seconds, map_source, entry_type, entry_map, entry_x, entry_y, entry_npc, duration_seconds, entry_macro, finish_macro, return_policy, search_targets, and phases. `search_targets` is evidence metadata only; it never replaces or rewrites shared `mon_control.txt`.

- [ ] **Step 1: Write the failing parser tests.**

~~~
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
~~~

- [ ] **Step 2: Run the focused test to verify it fails.**

Run: Set-Location D:\openkore; $env:OPENKORE_DIR='D:\openkore'; perl plugins\LastROActivity\test\unit_tests.pl RulesTest

Expected: FAIL because LastROActivity::Rules and the test runner do not exist.

- [ ] **Step 3: Implement the parser and validator.**

Use UTF-8 line reading, ignore blank/comment lines, start a section on [event_id], split each non-comment line on the first =, normalize numeric fields to integers, split comma-separated `search_targets` into an array, and collect repeated phase.<index>.<field> keys into an ordered phases array. Reject duplicate event IDs, enabled rules without announce_regex, invalid entry_type, non-positive duration, and lead_seconds < 0; attach each rule's validation_errors array and return the aggregate errors array without enabling the affected rule.

Use the following safe fixture entries in lastro_activity.txt: six event IDs (city_monster_party, dungeon_monster_party, dojo_challenge, pool_challenge, lottery, sky_chest), enabled=0 for every entry, confirmed lottery coordinates only, and explicit comments that unknown maps/dialog/finish messages keep a rule disabled. Do not invent monster names or map IDs.

- [ ] **Step 4: Run the focused test to verify it passes.**

Run: Set-Location D:\openkore; $env:OPENKORE_DIR='D:\openkore'; perl plugins\LastROActivity\test\unit_tests.pl RulesTest

Expected: PASS with parser, numeric conversion, duplicate rejection, and disabled-rule validation covered.

- [ ] **Step 5: Commit the parser unit.**

~~~
git add plugins/LastROActivity/LastROActivity/Rules.pm plugins/LastROActivity/control/lastro_activity.txt plugins/LastROActivity/test
git commit -m "feat: add LastRO activity rule parser"
~~~

### Task 2: Implement countdown scheduling and announcement deduplication

**Files:**
- Create: plugins/LastROActivity/LastROActivity/Scheduler.pm
- Create: plugins/LastROActivity/test/SchedulerTest.pm

**Interfaces:**
- LastROActivity::Scheduler->new(lead_seconds => 10, clock => $coderef) returns a scheduler object.
- LastROActivity::Scheduler::parse_countdown($message) -> $seconds_or_undef.
- $scheduler->observe($rule, $message, $received_at) -> $armed_hashref_or_undef stores one timer per event_id.
- $scheduler->due($now) -> $arrayref returns due events in start-time/priority order and marks them dispatched.
- $scheduler->cancel($event_id) removes an armed timer.

- [ ] **Step 1: Write failing countdown tests.**

~~~
is(LastROActivity::Scheduler::parse_countdown('活动将在2小时后开始'), 7200, 'parses hours');
is(LastROActivity::Scheduler::parse_countdown('活动将在1分钟后开始'), 60, 'parses minutes');
is(LastROActivity::Scheduler::parse_countdown('活动将在10秒钟后开始'), 10, 'parses seconds');
ok(!defined LastROActivity::Scheduler::parse_countdown('活动已经开始'), 'no countdown is undef');

my $scheduler = LastROActivity::Scheduler->new(lead_seconds => 10);
my $rule = {event_id => 'city_monster_party', enabled => 1, lead_seconds => 10};
my $armed = $scheduler->observe($rule, '城市魔物派对将在2小时后开始', 1_000);
is($armed->{trigger_at}, 8_190, 'triggers at start minus ten seconds');
is(scalar @{$scheduler->due(8_189)}, 0, 'does not trigger early');
is(scalar @{$scheduler->due(8_190)}, 1, 'triggers at the ten-second boundary');
$scheduler->observe($rule, '城市魔物派对将在1分钟后开始', 2_000);
$scheduler->observe($rule, '城市魔物派对将在1分钟后开始', 2_001);
is(scalar @{$scheduler->due(2_051)}, 1, 'duplicate announcements share one timer');
~~~

- [ ] **Step 2: Run the focused test and verify failure.**

Run: Set-Location D:\openkore; $env:OPENKORE_DIR='D:\openkore'; perl plugins\LastROActivity\test\unit_tests.pl SchedulerTest

Expected: FAIL because the scheduler module is missing.

- [ ] **Step 3: Implement deterministic scheduling.**

Match ([0-9]+)\s*(小时|小時|时), ([0-9]+)\s*分钟?, and ([0-9]+)\s*秒钟? anywhere in the message, sum all present units, and return undef when no unit is present. Compute start_at = received_at + countdown and trigger_at = max(received_at, start_at - lead_seconds). A message containing the rule's start_regex without a countdown creates an immediate due event. Store a revision timestamp so later duplicate broadcasts replace the timer rather than add another entry.

- [ ] **Step 4: Add dynamic map extraction tests and implementation.**

Expose extract_data_map($message) -> {map, x, y} for data-map='prontera#152#129'; reject malformed coordinates and only let the integration layer use the result when the rule's map_source is dynamic.

- [ ] **Step 5: Run focused tests and commit.**

Run: Set-Location D:\openkore; $env:OPENKORE_DIR='D:\openkore'; perl plugins\LastROActivity\test\unit_tests.pl SchedulerTest

Expected: PASS for all countdown units, immediate ten-second behavior, duplicate replacement, due ordering, and dynamic map extraction.

~~~
git add plugins/LastROActivity/LastROActivity/Scheduler.pm plugins/LastROActivity/test/SchedulerTest.pm
git commit -m "feat: schedule LastRO activities from countdowns"
~~~

### Task 3: Add lifecycle transitions and in-memory search/lockMap snapshots

**Files:**
- Create: plugins/LastROActivity/LastROActivity/State.pm
- Create: plugins/LastROActivity/test/StateTest.pm

**Interfaces:**
- LastROActivity::State->new starts in IDLE.
- $state->transition($event) -> $new_state accepts only documented transitions and dies with a stable error for invalid transitions.
- LastROActivity::State::snapshot_config($config_hashref) -> $snapshot_hashref copies lockMap, lockMap_x, lockMap_y, lockMap_randX, lockMap_randY, teleportAuto_search, and teleportAuto_idle.
- LastROActivity::State::apply_activity_config($config_hashref, $search_idle) -> $old_snapshot sets lockMap to an empty string, teleportAuto_search to 1, and teleportAuto_idle to the supplied interval without writing a file.
- LastROActivity::State::restore_config($config_hashref, $snapshot) restores every captured value.

- [ ] **Step 1: Write transition and snapshot tests.**

~~~
my $state = LastROActivity::State->new;
is($state->state, 'IDLE');
is($state->transition('arm'), 'ARMED');
is($state->transition('trigger'), 'INTERRUPTING');
is($state->transition('snapshot'), 'SNAPSHOTTED');
is($state->transition('depart'), 'DEPARTING');
is($state->transition('enter'), 'ENTERING');
is($state->transition('running'), 'RUNNING');
ok(!eval { $state->transition('resume'); 1 }, 'cannot resume before finishing');

my %config = (
    lockMap => 'pay_fild08', lockMap_x => 55, lockMap_y => 66,
    lockMap_randX => 7, lockMap_randY => 8,
    teleportAuto_search => 0, teleportAuto_idle => 0,
);
my $snapshot = LastROActivity::State::apply_activity_config(\%config, 1);
is($config{lockMap}, '', 'activity clears lockMap in memory');
is($config{teleportAuto_search}, 1, 'activity enables search gate');
is($config{teleportAuto_idle}, 1, 'activity enables idle teleport interval');
LastROActivity::State::restore_config(\%config, $snapshot);
is_deeply(\%config, { lockMap => 'pay_fild08', lockMap_x => 55, lockMap_y => 66,
    lockMap_randX => 7, lockMap_randY => 8, teleportAuto_search => 0,
    teleportAuto_idle => 0 }, 'restores every value');
~~~

- [ ] **Step 2: Run focused tests and verify failure.**

Run: Set-Location D:\openkore; $env:OPENKORE_DIR='D:\openkore'; perl plugins\LastROActivity\test\unit_tests.pl StateTest

Expected: FAIL because State.pm is missing.

- [ ] **Step 3: Implement the state machine and snapshot helpers.**

Define the transition table for IDLE -> ARMED -> INTERRUPTING -> SNAPSHOTTED -> DEPARTING -> ENTERING -> RUNNING -> FINISHING -> RETURNING -> RESUMED and permit fail from every non-terminal state. Keep apply_activity_config as a pure hash mutation; do not call configModify, saveConfigFile, or touch control/config.txt.

- [ ] **Step 4: Run focused tests and commit.**

Run: Set-Location D:\openkore; $env:OPENKORE_DIR='D:\openkore'; perl plugins\LastROActivity\test\unit_tests.pl StateTest

Expected: PASS for valid/invalid transitions and exact in-memory restoration.

~~~
git add plugins/LastROActivity/LastROActivity/State.pm plugins/LastROActivity/test/StateTest.pm
git commit -m "feat: add activity lifecycle and config snapshots"
~~~

### Task 4: Wire the plugin to OpenKore hooks and manual commands

**Files:**
- Create: plugins/LastROActivity/LastROActivity.pl
- Create: plugins/LastROActivity/test/PluginTest.pm
- Modify: control/config.txt
- Modify: control/sys.txt

**Interfaces:**
- Register plugin name LastROActivity and hooks packet_sysMsg, packet_pubMsg, mainLoop_pre, packet_mapChange, lastro_airship_result, and AI_state_change.
- Register the command lastroactivity with subcommands status, on, off, run <event_id>, stop, and reload.
- onSystemMessage($args) and onPublicMessage($args) pass $args->{Msg} (falling back to $args->{RawMsg}) to the scheduler.
- onMainLoopPre calls scheduler->due(time) and advances one state-machine action per loop; it is the only place that starts a due event.

- [ ] **Step 1: Write hook and command tests with stubs.**

Stub Globals::config, Globals::net, Globals::char, Globals::field, Commands::run, AI::clear, and Plugins::addHooks. Assert that an announcement two hours away only creates an armed timer, while a due event calls the interruption path exactly once and lastroactivity status reports ARMED or RUNNING.

- [ ] **Step 2: Run the focused test and verify failure.**

Run: Set-Location D:\openkore; $env:OPENKORE_DIR='D:\openkore'; perl plugins\LastROActivity\test\unit_tests.pl PluginTest

Expected: FAIL because the plugin module and command registration are missing.

- [ ] **Step 3: Implement plugin registration and configuration loading.**

Use Settings::addControlFile with the rules loader from Task 1. Read lastroActivity_enabled (default 1), lastroActivity_leadSeconds (default 10), and lastroActivity_teleportIdle (default 1) from %config, falling back to those defaults when absent. The loader must accept the plugin control file path from %config{lastroActivity_rulesFile} and default to lastro_activity.txt in the active control folder.

- [ ] **Step 4: Implement commands and the long-countdown behavior.**

on/off toggle only the plugin's enabled flag in memory. status prints state, armed event, trigger time, and last failure. run <event_id> goes through the same validation and item/map checks as a scheduled event. stop calls the common cleanup/return entry point. reload reloads the rule control file without changing an active snapshot.

- [ ] **Step 5: Add config keys and plugin load order.**

Append these entries to control/config.txt:

~~~
lastroActivity_enabled 1
lastroActivity_rulesFile lastro_activity.txt
lastroActivity_leadSeconds 10
lastroActivity_teleportIdle 1
~~~

Append LastROActivity immediately after LastroAirship in control/sys.txt's loadPlugins_list.

- [ ] **Step 6: Run focused tests and commit.**

Run: Set-Location D:\openkore; $env:OPENKORE_DIR='D:\openkore'; perl plugins\LastROActivity\test\unit_tests.pl PluginTest

Expected: PASS for hook registration, message field fallback, timer arming, command validation, and config defaults.

~~~
git add plugins/LastROActivity/LastROActivity.pl plugins/LastROActivity/test/PluginTest.pm control/config.txt control/sys.txt
git commit -m "feat: wire LastRO activity plugin into OpenKore"
~~~

### Task 5: Implement immediate interruption and shared search-mode entry

**Files:**
- Modify: plugins/LastROActivity/LastROActivity.pl
- Modify: plugins/LastROActivity/test/PluginTest.pm

**Interfaces:**
- begin_activity($rule, $scheduled_event) transitions through INTERRUPTING and SNAPSHOTTED before sending the entry command.
- clear_normal_ai() calls Commands::run('macro stop') when the macro plugin is available, then AI::clear(qw(attack move route mapRoute items_take items_gather take)).
- enter_search_mode($rule) calls State::apply_activity_config and leaves control/mon_control.txt untouched.

- [ ] **Step 1: Add failing interruption tests.**

Record calls in an array and assert this order when a due monster event is started:

~~~
is_deeply(\@calls, [
    'activity_lock:on',
    'macro stop',
    'AI::clear attack move route mapRoute items_take items_gather take',
    'snapshot',
    'config lockMap=',
    'config teleportAuto_search=1',
    'privateairship <event-map>',
], 'trigger interrupts before departure');
~~~

Also assert no call occurs while the scheduler has only an ARMED event with trigger_at in the future.

- [ ] **Step 2: Run the focused test and verify failure.**

Run: Set-Location D:\openkore; $env:OPENKORE_DIR='D:\openkore'; perl plugins\LastROActivity\test\unit_tests.pl PluginTest

Expected: FAIL because the interruption and search-mode functions are not implemented.

- [ ] **Step 3: Implement the interruption boundary.**

At the due timestamp, validate the enabled rule, connected in-game state, target map length/existence policy, and Private Airship inventory before mutating the runtime config. Once validation passes, set the activity lock, stop the current macro, clear AI, snapshot config, clear lockMap, set teleportAuto_search=1, set the configured teleportAuto_idle, and transition to DEPARTING.

- [ ] **Step 4: Preserve shared monster control semantics.**

Do not load, rewrite, or generate a per-event mon_control.txt. The plugin only relies on the existing shared rows whose third field is 1; all attack, teleport, skill-cancel, level, and weight fields continue to be read by OpenKore normally. Log a warning and fail the event if the rule declares no `search_targets` evidence.

- [ ] **Step 5: Run focused tests and commit.**

Run: Set-Location D:\openkore; $env:OPENKORE_DIR='D:\openkore'; perl plugins\LastROActivity\test\unit_tests.pl PluginTest

Expected: PASS for immediate attack interruption, no early mutation, no disk writes, and shared search behavior.

~~~
git add plugins/LastROActivity/LastROActivity.pl plugins/LastROActivity/test/PluginTest.pm
git commit -m "feat: interrupt grinding and enable shared search mode"
~~~

### Task 6: Add Private Airship departure, map confirmation, macro entry, and fixed return

**Files:**
- Modify: plugins/LastROActivity/LastROActivity.pl
- Modify: plugins/LastROActivity/test/PluginTest.pm

**Interfaces:**
- request_event_entry($rule) invokes Commands::run("privateairship $map") for airship entries; it never calls configModify.
- onMapChange($args) confirms ENTERING when the current field matches the event map and confirms RETURNING when it is prontera.
- onAirshipResult($args) maps nonzero LastRO Airship result codes to FAILED with a logged reason.
- finish_activity($reason) starts the common FINISHING -> RETURNING cleanup path.
- return_to_capital() calls Commands::run('privateairship prontera') and waits for the map hook.

- [ ] **Step 1: Write failing return-order tests.**

Stub Commands::run, the map-change hook, and config hashes. Assert that an end announcement produces this exact sequence:

~~~
is_deeply(\@calls, [
    'clear activity AI',
    'privateairship prontera',
    'map confirmed prontera',
    'restore lockMap/pay_fild08',
    'restore teleport settings',
    'AI::clear',
    'activity_lock:off',
], 'return flow restores lockMap before AI clear');
~~~

- [ ] **Step 2: Run focused tests and verify failure.**

Run: Set-Location D:\openkore; $env:OPENKORE_DIR='D:\openkore'; perl plugins\LastROActivity\test\unit_tests.pl PluginTest

Expected: FAIL because departure/return handlers are incomplete.

- [ ] **Step 3: Implement Private Airship entry and result handling.**

Call Commands::run("privateairship $rule->{entry_map}") so the existing LastroAirship interceptor selects the active LastRO item ID. Track a pending destination and deadline. Treat lastro_airship_result type 0 as accepted, and types 1..5 as failures with human-readable log messages; do not retry indefinitely.

- [ ] **Step 4: Implement optional macro entry/finish execution.**

For a rule with entry_macro, call Commands::run("macro $name -overrideAI -exclusive") only after the entry map is confirmed. Watch the macro queue through mainLoop_pre; a finished queue or macro/error hook marks the configured entry/finish stage complete or failed. Keep the activity lock until the macro result and map/finish condition are observed.

- [ ] **Step 5: Implement the common return path.**

On finish_regex, macro completion, leaving the event map, phase timeout, or overall duration timeout, clear activity AI, request privateairship prontera, wait for packet_mapChange, restore the exact snapshot, call AI::clear, clear the pending event, and release the activity lock. Never restore an old attack queue; processLockMap must rebuild the route from the restored config.

- [ ] **Step 6: Run focused tests and commit.**

Run: Set-Location D:\openkore; $env:OPENKORE_DIR='D:\openkore'; perl plugins\LastROActivity\test\unit_tests.pl PluginTest

Expected: PASS for successful entry, server rejection, map confirmation, finish timeout, fixed prontera return, and the exact restore/AI-clear order.

~~~
git add plugins/LastROActivity/LastROActivity.pl plugins/LastROActivity/test/PluginTest.pm
git commit -m "feat: return LastRO activities through prontera"
~~~

### Task 7: Add finish detection, phases, deduplication, and failure recovery

**Files:**
- Modify: plugins/LastROActivity/LastROActivity.pl
- Modify: plugins/LastROActivity/test/PluginTest.pm

**Interfaces:**
- onActivityMessage($message) checks finish regexes only for the active event and advances phase state without touching shared monster control.
- checkActivityTimeout($now) returns finish for phase/overall timeout and fail for entry timeout.
- cleanup_and_restore($reason) is idempotent and is the only function allowed to release the activity lock.

- [ ] **Step 1: Write tests for all finish paths.**

Cover finish announcement, phase transition from eggs to MVP, 15-minute overall timeout, three failed airship attempts, map kick-out, duplicate start announcement while RUNNING, and manual stop. Assert each scenario invokes cleanup_and_restore once and restores the original config.

- [ ] **Step 2: Run the focused tests and verify failure.**

Run: Set-Location D:\openkore; $env:OPENKORE_DIR='D:\openkore'; perl plugins\LastROActivity\test\unit_tests.pl PluginTest

Expected: FAIL until phase, timeout, idempotent cleanup, and duplicate handling are implemented.

- [ ] **Step 3: Implement event-scoped finish matching and phase changes.**

Only the active rule's finish_regex and current phase conditions may finish or advance the event. For city and dungeon monster parties, allow an eggs phase followed by mvp when the configured phase condition arrives; for non-monster events, use the rule's macro or finish regex.

- [ ] **Step 4: Implement bounded recovery and event mutex.**

Store one active event and one armed timer. Ignore duplicate events with the same event_id; while RUNNING, do not interrupt for another event. On any failure, call the same fixed return path, record the failure reason, restore values, and make the plugin ready for the next announcement.

- [ ] **Step 5: Run focused tests and commit.**

Run: Set-Location D:\openkore; $env:OPENKORE_DIR='D:\openkore'; perl plugins\LastROActivity\test\unit_tests.pl PluginTest

Expected: PASS for all finish, timeout, phase, mutex, and recovery cases.

~~~
git add plugins/LastROActivity/LastROActivity.pl plugins/LastROActivity/test/PluginTest.pm
git commit -m "feat: make activity cleanup and timeouts idempotent"
~~~

### Task 8: Connect the six event rules and shared monster-control data safely

**Files:**
- Modify: plugins/LastROActivity/control/lastro_activity.txt
- Modify, only after evidence is available: control/mon_control.txt
- Create: plugins/LastROActivity/README.md
- Create: plugins/LastROActivity/test/ProductionRulesTest.pm

**Interfaces:**
- Production rules stay disabled until every required map/entry/finish value is present.
- ProductionRulesTest loads the actual control file and fails if an enabled rule lacks a map source, start/finish evidence, valid return policy, usable entry, or (for a monster-search rule) `search_targets` evidence.
- mon_control.txt remains the single shared combat source; this task may only set the third field to 1 on confirmed event-monster rows while preserving existing first/second and remaining columns.

- [ ] **Step 1: Write the production-rule validation test.**

~~~
my ($rules, $errors) = LastROActivity::Rules::load_file($rules_file);
for my $id (qw(city_monster_party dungeon_monster_party dojo_challenge pool_challenge lottery sky_chest)) {
    ok(exists $rules->{$id}, "$id rule exists");
    ok(!$rules->{$id}{enabled} || !@{$rules->{$id}{validation_errors} || []}, "$id enabled only with complete evidence");
}
~~~

- [ ] **Step 2: Run the validation test and verify the current safe fixture passes.**

Run: Set-Location D:\openkore; $env:OPENKORE_DIR='D:\openkore'; perl plugins\LastROActivity\test\unit_tests.pl ProductionRulesTest

Expected: PASS with all six entries present and disabled where data is still unknown.

- [ ] **Step 3: Add the README operational contract.**

Document lastroActivity_enabled, the ten-second lead, the required mon_control.txt column order, the fact that search=1 is a search gate rather than an attack-priority override, the privateairship prontera return, and the exact evidence required before enabling a rule (announcement line, internal map name, monster IDs/names, and NPC macro/finish text).

- [ ] **Step 4: Populate confirmed shared search rows only when the user supplies server evidence.**

For each confirmed event monster, edit the existing shared row or add one row with the real monster name/ID, retain the user-approved attack/teleport/skill values, and set only the third field to 1. Run a textual diff that confirms no non-search column changed.

- [ ] **Step 5: Run production validation and commit.**

Run: Set-Location D:\openkore; $env:OPENKORE_DIR='D:\openkore'; perl plugins\LastROActivity\test\unit_tests.pl ProductionRulesTest

Expected: PASS with all unknown rules disabled and every enabled rule validated.

~~~
git add plugins/LastROActivity/control/lastro_activity.txt plugins/LastROActivity/README.md plugins/LastROActivity/test/ProductionRulesTest.pm
git add control/mon_control.txt  # only when confirmed search rows were added
git commit -m "feat: add safe LastRO activity rules and shared search docs"
~~~

### Task 9: Run the complete verification suite and prepare the first server trial

**Files:**
- Modify: plugins/LastROActivity/test/unit_tests.pl if a test module list needs updating.
- Review only: plugins/LastROActivity/LastROActivity.pl, plugins/LastROActivity/control/lastro_activity.txt, and control/sys.txt.

- [ ] **Step 1: Run all activity tests.**

Run: Set-Location D:\openkore; $env:OPENKORE_DIR='D:\openkore'; perl plugins\LastROActivity\test\unit_tests.pl

Expected: PASS for Rules, Scheduler, State, Plugin, and ProductionRules tests.

- [ ] **Step 2: Run the related OpenKore tests.**

Run: Set-Location D:\openkore; perl src\test\unittests.pl FileParsersTest PluginsHookTest TaskTalkNPCTest NetworkTest

Expected: PASS with no core behavior regressions.

- [ ] **Step 3: Run Perl syntax checks.**

Run: Set-Location D:\openkore; perl -Iplugins\LastROActivity -c plugins\LastROActivity\LastROActivity.pl; perl -Iplugins\LastROActivity -c plugins\LastROActivity\LastROActivity\Rules.pm; perl -Iplugins\LastROActivity -c plugins\LastROActivity\LastROActivity\Scheduler.pm; perl -Iplugins\LastROActivity -c plugins\LastROActivity\LastROActivity\State.pm

Expected: each file reports syntax OK.

- [ ] **Step 4: Perform a controlled server trial.**

Enable exactly one event rule with confirmed data, keep lastroActivity_leadSeconds 10, capture the system announcement and map-change logs, verify no config file timestamp/content change during search mode, verify the attack target changes immediately at the trigger, and verify the return sequence reaches prontera, restores lockMap, executes AI::clear, and resumes the normal route.

- [ ] **Step 5: Commit the verified implementation.**

~~~
git status --short
git diff --check
git commit -am "test: verify LastRO activity automation"
~~~

Expected: the working tree is clean, all automated tests pass, and the first live test has one explicitly enabled, evidence-backed activity rule.
