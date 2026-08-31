# LastRO Coordinate Teleport and Lottery Automation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `tt <map> [x y [item_id]]`, route every `LastROActivity` transfer through it, and make Lottery repeatedly operate the confirmed NPC until the finish announcement.

**Architecture:** Extend the existing LastRO `0x0A49` sender without changing legacy callers, and register `tt` in `LastroAirship` as the sole activity transfer adapter. Separate activity transport from post-arrival entry actions so dynamic combat events use announcement coordinates while Lottery travels to its configured NPC coordinate and then runs an actor-ID-scoped, packet-driven dialog loop.

**Tech Stack:** Perl 5, OpenKore `Network::Send`, plugin hooks, `Commands::register`, actor globals, `Test::More`, and the existing OpenKore/plugin test runners.

**Spec:** `docs/superpowers/specs/2026-08-31-lastro-teleport-lottery-design.md`

## Global Constraints

- The LastRO packet is exactly `0x0A49` followed by `Z16 V4`, for 34 bytes total.
- Map-only requests send `x=0`, `y=0`, `type=0`; coordinate requests send the supplied X/Y and `type=1`.
- `tt` syntax is exactly `tt <map> [x y [item_id]]`; coordinates must be supplied as a pair in `0..65535`.
- The default item ID is `14527`; an explicit positive unsigned 32-bit item ID is allowed only after X and Y.
- `privateairship` remains compatible outside `LastROActivity`, but no runtime path in `LastROActivity` may execute it.
- Dynamic combat entries use the matching announcement's `data-map="map#x#y"`; named NPC entries use configured coordinates.
- Every activity entry/retry uses `tt map x y` when coordinates are confirmed; returns use `tt prontera` because no return coordinate is confirmed.
- Lottery NPC identity is exact name `活动负责人#iz` at `prontera 152 133`; `#iz` is part of the name, not a TalkNPC sequence.
- Lottery automatically handles only Continue and the first menu option, repeats after close on the next main loop, and stops at `抽奖活动已结束`.
- Automatic dialog replies must be scoped to the stored Lottery NPC actor ID and must ignore every other NPC.
- Number, text, shop, or other unsupported dialog input fails closed and enters the existing return/restore path.
- The existing activity lock, bounded transfer retries, return confirmation, snapshot restoration, and final AI clear remain authoritative.
- Shared `mon_control.txt` is not rewritten and Lottery does not enter search mode.
- Implementation tasks use TDD and commit independently; Luna max implements and Terra max performs the final whole-branch review.

## File Map

- Modify `src/Network/Send/kRO/RagexeRE_2021_11_03.pm`: accept optional X/Y/type fields in the LastRO `0x0A49` sender while preserving two-argument behavior.
- Modify `src/test/NetworkTest.pm`: assert exact map-only and coordinate packet fields, including an item-ID override.
- Modify `plugins/LastroAirship/LastroAirship.pl`: register/unregister `tt`, parse and validate its exact syntax, and send through the LastRO sender.
- Create `plugins/LastroAirship/test/unit_tests.pl`: focused plugin test runner.
- Create `plugins/LastroAirship/test/LastroAirshipTest.pm`: command parsing, validation, availability, and send-call coverage.
- Modify `plugins/LastROActivity/LastROActivity/Rules.pm`: accept canonical `tt` entries, named-dialog fields, and `tt:prontera`; retain legacy policy aliases without selecting the old command.
- Modify `plugins/LastROActivity/LastROActivity.pl`: resolve destinations with coordinates, replace every activity transfer with `tt`, and add the scoped Lottery dialog lifecycle.
- Modify `plugins/LastROActivity/control/lastro_activity.txt`: correct Lottery metadata and migrate production transfer policies.
- Modify `plugins/LastROActivity/README.md`: document `tt`, coordinate sources, and Lottery behavior.
- Modify `plugins/LastROActivity/test/RulesTest.pm`, `ProductionRulesTest.pm`, and `PluginTest.pm`: parser, production policy, transfer, retry, return, and dialog integration coverage.

---

### Task 1: Add the coordinate sender and `tt` command

**Files:**
- Modify: `src/Network/Send/kRO/RagexeRE_2021_11_03.pm:148`
- Modify: `src/test/NetworkTest.pm:353`
- Modify: `plugins/LastroAirship/LastroAirship.pl`
- Create: `plugins/LastroAirship/test/unit_tests.pl`
- Create: `plugins/LastroAirship/test/LastroAirshipTest.pm`

**Interfaces:**
- Consumes: existing `isEnabled($masterServer)`, `normalizeMapName($map)`, and `sendPrivateAirshipRequest` LastRO packet registration.
- Produces: `sendPrivateAirshipRequest($map, $item_id, $x = 0, $y = 0, $type = 0)` with old two-argument calls unchanged.
- Produces: command callback `_cmdTeleport($switch, $args)` registered as `tt`.
- Produces: `tt <map> [x y [item_id]]` with default item `14527`.

- [ ] **Step 1: Add failing network packet tests.**

Extend the existing LastRO private-airship subtest with these assertions:

```perl
$instance->sendPrivateAirshipRequest('prontera', 14527, 152, 133, 1);
my $coordinate_packet = $net->{sent}[1];
is(length($coordinate_packet), 34, 'coordinate 0A49 remains 34 bytes');
is(substr($coordinate_packet, 2, 16), "prontera\0" . "\0" x 7,
    'coordinate request packs the normalized map in Z16');
is_deeply(
    [unpack('V4', substr($coordinate_packet, 18, 16))],
    [152, 133, 1, 14527],
    'coordinate request matches the web-client x/y/type/item layout',
);

$instance->sendPrivateAirshipRequest('prontera', 607, 10, 20, 1);
is_deeply(
    [unpack('V4', substr($net->{sent}[2], 18, 16))],
    [10, 20, 1, 607],
    'coordinate request preserves an explicit item ID',
);
```

- [ ] **Step 2: Run the network test and verify RED.**

Run:

```powershell
perl src\test\unittests.pl NetworkTest
```

Expected: FAIL because the LastRO override currently discards X, Y, and type and emits zeros.

- [ ] **Step 3: Extend the sender minimally.**

Change only the LastRO override signature and field defaults:

```perl
sub sendPrivateAirshipRequest {
    my ($self, $map_name, $nameID, $x, $y, $type) = @_;
    return $self->SUPER::sendPrivateAirshipRequest($map_name, $nameID)
        unless isEnabled($masterServer);

    $map_name = normalizeMapName($map_name);
    $nameID = 14527 unless defined $nameID;
    $x = 0 unless defined $x;
    $y = 0 unless defined $y;
    $type = 0 unless defined $type;

    $self->sendToServer(pack('v Z16 V4',
        0x0A49, stringToBytes($map_name), $x, $y, $type, $nameID,
    ));
}
```

Do not change the non-LastRO superclass path or the existing map-only callers.

- [ ] **Step 4: Run the network test and verify GREEN.**

Run:

```powershell
perl src\test\unittests.pl NetworkTest
```

Expected: PASS, including the existing LastRO map-only and non-LastRO legacy packet tests.

- [ ] **Step 5: Add failing `tt` command tests.**

Create a plugin harness that stubs `Commands::register`, `Commands::unregister`, the LastRO globals, logging, and a message sender recording calls. Cover these calls:

```perl
run_tt('prontera');
is_deeply($calls[-1], ['prontera', 14527, 0, 0, 0], 'map-only tt uses type zero');

run_tt('prontera 152 133');
is_deeply($calls[-1], ['prontera', 14527, 152, 133, 1], 'coordinate tt uses type one');

run_tt('prontera 152 133 607');
is_deeply($calls[-1], ['prontera', 607, 152, 133, 1], 'tt accepts explicit item ID');
```

Also assert that each input below sends nothing and logs an error:

```text
<empty>
prontera 152
prontera 152 133 14527 extra
prontera -1 133
prontera 65536 133
prontera 152 nope
prontera 152 133 0
map_name_longer_than_sixteen_bytes
```

Add cases for a non-LastRO profile and a missing sender. Assert the command handle is unregistered in `onUnload`.

- [ ] **Step 6: Run the plugin test and verify RED.**

Run:

```powershell
$env:OPENKORE_DIR=(Get-Location).Path
perl plugins\LastroAirship\test\unit_tests.pl LastroAirshipTest
```

Expected: FAIL because `tt` is not registered.

- [ ] **Step 7: Implement command registration and validation.**

Register the command with `Commands::register`:

```perl
my $commands = Commands::register(
    ['tt', 'tt <map> [x y [item_id]] - LastRO coordinate teleport', \&_cmdTeleport],
);
```

Parse only these shapes:

```perl
my @parts = grep { length } split /\s+/, _trim($args);
# 1 part: map-only; 3 parts: map+x+y; 4 parts: map+x+y+item
```

Normalize the map, reject encoded map names longer than 16 bytes, validate coordinates with `^\d+$` and `<= 65535`, validate item ID with `^\d+$`, `> 0`, and `<= 4294967295`, require LastRO and a sender supporting `sendPrivateAirshipRequest`, then call:

```perl
$messageSender->sendPrivateAirshipRequest($map, $item_id, $x, $y, $type);
```

Unregister the command in `onUnload` without changing the existing `privateairship` interceptor.

- [ ] **Step 8: Run focused tests and commit.**

Run:

```powershell
perl src\test\unittests.pl NetworkTest
$env:OPENKORE_DIR=(Get-Location).Path
perl plugins\LastroAirship\test\unit_tests.pl LastroAirshipTest
```

Expected: both commands exit 0 with all assertions passing.

Commit:

```powershell
git add src/Network/Send/kRO/RagexeRE_2021_11_03.pm src/test/NetworkTest.pm plugins/LastroAirship
git commit -m "feat: add LastRO coordinate teleport command"
```

### Task 2: Migrate all activity transfers to `tt`

**Files:**
- Modify: `plugins/LastROActivity/LastROActivity/Rules.pm`
- Modify: `plugins/LastROActivity/LastROActivity.pl`
- Modify: `plugins/LastROActivity/test/RulesTest.pm`
- Modify: `plugins/LastROActivity/test/PluginTest.pm`

**Interfaces:**
- Consumes: Task 1 command `tt <map> [x y [item_id]]`.
- Produces: `_event_destination($rule, $event) -> {map => $map, x => $x_or_undef, y => $y_or_undef}`.
- Produces: `_destination_command($destination) -> 'tt map x y'` or `'tt map'`.
- Produces: canonical `entry_type=tt` and `return_policy=tt:prontera`.
- Preserves: legacy `airship`/`privateairship` entry and return policy strings as input aliases that execute `tt`.

- [ ] **Step 1: Add failing rule-policy tests.**

Add parser cases asserting:

```perl
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
RULES

is_deeply($errors, [], 'canonical tt rule validates');
is($rules->{canonical}{entry_type}, 'tt', 'tt is a supported entry type');
```

Keep a legacy rule and assert it validates as compatibility input. Add a bad return such as `tt:payon` and assert rejection.

- [ ] **Step 2: Add failing transport integration tests.**

Use the existing command recorder and assert exact calls:

```perl
is_deeply(
    activity_entry_commands(dynamic_event('morocc', 159, 99)),
    ['tt morocc 159 99'],
    'dynamic event uses announcement coordinates',
);

is_deeply(
    activity_entry_commands(static_event('prontera', 152, 133)),
    ['tt prontera 152 133'],
    'static event uses configured coordinates',
);

is_deeply(
    activity_return_commands(),
    ['tt prontera'],
    'return uses the new map-only command',
);
```

Exercise a transfer rejection twice and assert every bounded retry repeats the same resolved `tt map x y`. Exercise normal finish, timeout, map loss, manual stop, and `lastroactivity off`, then assert no command in the recorder matches `^privateairship\b`.

- [ ] **Step 3: Run RulesTest and PluginTest and verify RED.**

Run:

```powershell
$env:OPENKORE_DIR=(Get-Location).Path
perl plugins\LastROActivity\test\unit_tests.pl RulesTest PluginTest
```

Expected: FAIL because `tt` is not a rule entry type and production code still calls `privateairship`.

- [ ] **Step 4: Implement destination resolution.**

Add `_event_destination` with this precedence:

```perl
if ($entry_type eq 'npc'
    && lc(_trim($rule->{entry_dialog_mode})) eq 'repeat_first_until_finish') {
    return {map => _event_map($rule, $event), x => $rule->{entry_x}, y => $rule->{entry_y}};
}
if (lc(_trim($rule->{map_source})) eq 'dynamic') {
    return {map => $event->{data_map}{map}, x => $event->{data_map}{x}, y => $event->{data_map}{y}};
}
return {map => _event_map($rule, $event), x => $rule->{entry_x}, y => $rule->{entry_y}};
```

Coordinates are used only when both are defined decimal integers. This plan
retains `entry_type=npc`; `entry_dialog_mode` distinguishes the new named loop
from the legacy fixed TalkNPC-sequence path.

Add `_destination_command` that emits only validated literal map and numeric coordinate tokens. Store the resolved destination on the active event before the first request so retries cannot change when later announcements arrive.

- [ ] **Step 5: Replace every activity transfer command.**

Change entry, retry, and return call sites to use only:

```perl
_run_checked_command(_destination_command($destination));
_run_checked_command('tt prontera');
```

Allow `tt` in `Rules.pm`, make `tt:prontera` canonical, and accept `privateairship:prontera` only as a compatibility alias. Remove the activity preflight requirement that an `entry_item_id` be configured or present in inventory; `tt` supplies `14527`. Retain the server-result hook and bounded pending-destination logic because it observes the same `0x0A49` result packet.

- [ ] **Step 6: Update existing test expectations without weakening assertions.**

Mechanically replace activity command expectations with their exact `tt` equivalents. Dynamic fixtures that carry `data_map` must expect coordinates. Fixed test fixtures without coordinates expect `tt event_map`. Do not delete rejection, retry-count, map-confirmation, cleanup-order, or single-return assertions.

- [ ] **Step 7: Run focused tests and commit.**

Run:

```powershell
$env:OPENKORE_DIR=(Get-Location).Path
perl plugins\LastROActivity\test\unit_tests.pl RulesTest SchedulerTest StateTest PluginTest
```

Expected: exit 0, and the new command-recorder invariant confirms no activity path executes `privateairship`.

Commit:

```powershell
git add plugins/LastROActivity/LastROActivity/Rules.pm plugins/LastROActivity/LastROActivity.pl plugins/LastROActivity/test/RulesTest.pm plugins/LastROActivity/test/PluginTest.pm
git commit -m "feat: route LastRO activities through tt"
```

### Task 3: Add the scoped repeating Lottery dialog

**Files:**
- Modify: `plugins/LastROActivity/LastROActivity/Rules.pm`
- Modify: `plugins/LastROActivity/LastROActivity.pl`
- Modify: `plugins/LastROActivity/test/RulesTest.pm`
- Modify: `plugins/LastROActivity/test/PluginTest.pm`

**Interfaces:**
- Consumes: Task 2 destination confirmation and activity lifecycle.
- Produces rule fields: `entry_npc_name` and `entry_dialog_mode=repeat_first_until_finish`.
- Produces runtime fields for a single loop: actor ID, actor identity snapshot, session-active flag, and re-click-pending flag.
- Produces hooks: `packet/npc_talk_continue`, `npc_talk_responses`, `npc_talk_done`, `packet/npc_talk_number`, `packet/npc_talk_text`, and `packet/npc_store_begin`.

- [ ] **Step 1: Add failing parser tests for named dialog metadata.**

Parse this rule and require no fixed TalkNPC sequence:

```perl
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
```

Assert the exact name, mode, and coordinate values. Add invalid cases for a missing name, missing coordinate, and unknown dialog mode; each must become effectively disabled with a specific validation error.

- [ ] **Step 2: Add failing entry and response tests.**

Build a test NPC with binary actor ID, exact name, and `{pos => {x => 152, y => 133}}`. Assert this sequence:

```perl
start_lottery();
is_deeply(\@Commands::run_calls, ['tt prontera 152 133'], 'travel happens before NPC contact');
ok(!@send_talk_calls, 'NPC is not clicked before map confirmation');

confirm_map('prontera');
main_loop();
is_deeply(\@send_talk_calls, [$npc_id], 'confirmed NPC is clicked once');

LastROActivity::onNpcTalkContinue(undef, {ID => $npc_id});
is_deeply(\@continue_calls, [$npc_id], 'matching Continue is answered immediately');

LastROActivity::onNpcTalkResponses(undef, {ID => $npc_id, responses => ['领取', '取消']});
is_deeply(\@response_calls, [[$npc_id, 1]], 'first wire response is selected immediately');
```

Implement `_dialog_packet_id($args, $raw_offset)` to return `$args->{ID}` when
present and otherwise return four bytes from `$args->{RAW_MSG}` at the supplied
offset. Continue uses offset 2. The normalized-hook and raw-packet forms must
both be covered.

- [ ] **Step 3: Add failing isolation, repetition, and stop tests.**

Assert all of the following:

- a different actor ID receives no Continue or response;
- an actor with the same name at a different coordinate is not bound;
- `npc_talk_done` for the bound ID sets re-click pending but does not send recursively inside the hook;
- the next `mainLoop_pre` sends exactly one new `sendTalk`;
- two close notifications before the loop still produce only one re-click;
- the finish announcement clears the actor/session flags before return and no later packet or main loop sends a response or click;
- number, text, and shop hooks for the bound ID record a failure and execute the common `tt prontera` return;
- the same unsupported hooks for another ID are ignored;
- missing NPC visibility waits within the existing entry deadline and then fails once;
- map change/disconnect/manual stop clear the dialog state.

- [ ] **Step 4: Run focused tests and verify RED.**

Run:

```powershell
$env:OPENKORE_DIR=(Get-Location).Path
perl plugins\LastROActivity\test\unit_tests.pl RulesTest PluginTest
```

Expected: FAIL because named dialog fields and event-scoped packet hooks do not exist.

- [ ] **Step 5: Implement named NPC resolution and initial click.**

Import `%npcs` and `@npcsID`. After `prontera` is confirmed, scan observed NPC actors and bind only one whose exact `name` and `pos`/`pos_to` match the configured values. Store its binary ID and identity values. On `mainLoop_pre`, revalidate the actor still exists with that ID/name/position before calling:

```perl
$Globals::messageSender->sendTalk($lottery_npc_id);
```

If the NPC is not visible, keep waiting until the existing entry deadline; do not call `talknpc`, parse `#iz`, or guess a nearby actor.

For this dialog mode, map confirmation alone must not promote `ENTERING` to
`RUNNING`. Keep the activity in `ENTERING` while resolving the NPC, send the
first `sendTalk`, then mark entry confirmed and transition to `RUNNING`.
Replace the fixed-sequence evidence gate only for this explicit mode: its exact
name, map, coordinate pair, supported mode, and finish regex are the complete
required evidence. Legacy `entry_type=npc` rules without this mode continue to
require their existing trusted fixed sequence.

- [ ] **Step 6: Implement event-driven replies and next-loop repetition.**

Register the hooks and gate every callback through a single predicate equivalent to:

```perl
return unless _lottery_dialog_active();
return unless defined $incoming_id && $incoming_id eq $lottery_npc_id;
```

For the matching ID, send Continue immediately and send response wire value `1` immediately. On close, set `reclick_pending=1` and `session_active=0`; `mainLoop_pre` consumes the pending flag and starts one new session. Do not set a timer or sleep.

Unsupported input calls `_mark_activity_failed` with the dialog type and uses the existing `tt prontera` cleanup. Every finish/cleanup/unload/map-loss path calls one `_clear_lottery_dialog` helper before any return command.

- [ ] **Step 7: Run focused tests and commit.**

Run:

```powershell
$env:OPENKORE_DIR=(Get-Location).Path
perl plugins\LastROActivity\test\unit_tests.pl RulesTest PluginTest
```

Expected: exit 0 with exact actor isolation, no artificial response delay, one-session repetition, and finish shutdown covered.

Commit:

```powershell
git add plugins/LastROActivity/LastROActivity/Rules.pm plugins/LastROActivity/LastROActivity.pl plugins/LastROActivity/test/RulesTest.pm plugins/LastROActivity/test/PluginTest.pm
git commit -m "feat: automate the LastRO lottery dialog"
```

### Task 4: Migrate production rules and operational documentation

**Files:**
- Modify: `plugins/LastROActivity/control/lastro_activity.txt`
- Modify: `plugins/LastROActivity/README.md`
- Modify: `plugins/LastROActivity/test/ProductionRulesTest.pm`
- Modify: `plugins/LastROActivity/test/RulesTest.pm`

**Interfaces:**
- Consumes: Task 2 `tt` policies and Task 3 named Lottery dialog mode.
- Produces: effective runnable Lottery rule with exact NPC metadata.
- Produces: production combat rules whose entry policy is `tt` and whose dynamic coordinates come from announcements.

- [ ] **Step 1: Add failing production-rule assertions.**

Assert the real file contains:

```perl
is($rules->{lottery}{entry_y}, 133, 'lottery uses confirmed NPC Y');
is($rules->{lottery}{entry_npc_name}, '活动负责人#iz', 'NPC suffix remains part of the name');
is($rules->{lottery}{entry_dialog_mode}, 'repeat_first_until_finish', 'lottery repeats first-option dialog');
ok($rules->{lottery}{enabled}, 'lottery is effectively enabled');
is($rules->{lottery}{return_policy}, 'tt:prontera', 'lottery returns through tt');

for my $id (qw(city_monster_party dojo_challenge pool_challenge)) {
    is($rules->{$id}{entry_type}, 'tt', "$id uses tt entry");
    is($rules->{$id}{return_policy}, 'tt:prontera', "$id uses tt return");
}
```

Keep incomplete activities effectively disabled for their existing missing announcement/target evidence; changing the transport must not invent monsters or finish evidence.

- [ ] **Step 2: Run production tests and verify RED.**

Run:

```powershell
$env:OPENKORE_DIR=(Get-Location).Path
perl plugins\LastROActivity\test\unit_tests.pl ProductionRulesTest RulesTest
```

Expected: FAIL because the fixture still uses `privateairship`, Lottery Y is 129, and the named dialog metadata is absent.

- [ ] **Step 3: Update the production control file.**

For confirmed combat activities, set `entry_type=tt` and `return_policy=tt:prontera`; leave their dynamic announcement coordinates untouched. For Lottery use exactly:

```text
[lottery]
enabled=1
announce_regex=(?=.*\[随机事件\])(?=.*抽奖活动)(?=.*开始啦)(?!.*下一次事件)
start_regex=(?=.*\[随机事件\])(?=.*抽奖活动)(?=.*[0-9]+\s*秒钟?后)(?=.*开始啦)(?!.*下一次事件)
finish_regex=抽奖活动已结束
lead_seconds=10
map_source=static
entry_type=npc
entry_map=prontera
entry_x=152
entry_y=133
entry_npc_name=活动负责人#iz
entry_dialog_mode=repeat_first_until_finish
return_policy=tt:prontera
search_targets=
```

Remove the obsolete comment saying Lottery lacks dialog trust data. Do not add `entry_item_id`; `tt` defaults to `14527`.

- [ ] **Step 4: Update the README contract.**

Replace activity `privateairship` examples with exact `tt` behavior. Document coordinate precedence, map-only capital return, default/override item syntax, exact Lottery identity, first-option repetition, unsupported-dialog failure, and expected console messages for travel, NPC binding, dialog responses, finish, and return. Preserve the warnings that incomplete monster activities remain fail-closed.

- [ ] **Step 5: Run production and complete activity tests.**

Run:

```powershell
$env:OPENKORE_DIR=(Get-Location).Path
perl plugins\LastROActivity\test\unit_tests.pl RulesTest SchedulerTest StateTest ProductionRulesTest PluginTest
```

Expected: exit 0; Lottery is effectively enabled, incomplete rules retain their evidence failures, and every runtime activity command expectation uses `tt`.

- [ ] **Step 6: Commit production policy and docs.**

```powershell
git add plugins/LastROActivity/control/lastro_activity.txt plugins/LastROActivity/README.md plugins/LastROActivity/test/ProductionRulesTest.pm plugins/LastROActivity/test/RulesTest.pm
git commit -m "docs: enable Lottery through tt automation"
```

### Task 5: Verify the integrated branch and prepare the existing PR

**Files:**
- Review: all files changed since `2852deb80`.
- Modify only if a covering test first demonstrates a verification failure.

**Interfaces:**
- Consumes: Tasks 1-4.
- Produces: verified branch with no activity runtime `privateairship` calls and an updated existing GitHub PR.

- [ ] **Step 1: Run focused sender and plugin suites.**

```powershell
perl src\test\unittests.pl NetworkTest
$env:OPENKORE_DIR=(Get-Location).Path
perl plugins\LastroAirship\test\unit_tests.pl LastroAirshipTest
perl plugins\LastROActivity\test\unit_tests.pl RulesTest SchedulerTest StateTest ProductionRulesTest PluginTest
```

Expected: every command exits 0 with no failed assertions.

- [ ] **Step 2: Run syntax checks.**

```powershell
perl -Isrc -Isrc\deps -Iplugins\LastROActivity -c plugins\LastROActivity\LastROActivity.pl
perl -Isrc -Isrc\deps -Iplugins\LastROActivity -c plugins\LastROActivity\LastROActivity\Rules.pm
perl -Isrc -Isrc\deps -c plugins\LastroAirship\LastroAirship.pl
```

Expected: each file reports `syntax OK`.

- [ ] **Step 3: Run source-policy scans and diff hygiene.**

```powershell
rg -n 'Commands::run\([^\n]*privateairship|_run_checked_command\([^\n]*privateairship' plugins\LastROActivity\LastROActivity.pl
git diff --check origin/codex/lastro-activity-automation...HEAD
git status --short
```

Expected: the `rg` command has no matches, `git diff --check` has no output, and status contains no uncommitted implementation changes.

- [ ] **Step 4: Perform final Terra max whole-branch review.**

Give the reviewer the spec, this plan, task reports, and a full diff package from merge base through HEAD. Require separate spec-compliance and code-quality verdicts, with exact file/line findings. Any Critical or Important finding goes through one Luna max fix task and one scoped Terra max re-review.

- [ ] **Step 5: Re-run verification after review fixes.**

Repeat Steps 1-3 from the final reviewed HEAD. Do not rely on earlier test output.

- [ ] **Step 6: Push and update the existing PR.**

```powershell
git push origin codex/lastro-activity-automation
gh pr view 16 --repo parkerjj/OpenKore --json number,url,headRefName,baseRefName,state
```

Expected: push succeeds and PR `parkerjj/OpenKore#16` remains open from `codex/lastro-activity-automation` into the repository's main branch.
