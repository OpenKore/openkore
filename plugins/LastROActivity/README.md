# LastROActivity operations

LastROActivity listens for explicitly configured LastRO activity announcements,
waits until the configured lead time, and temporarily hands control to the
activity lifecycle. The bundled rules preserve all six first-phase event IDs
and the raw enable flags used by the announcement-evidence fixture. Effective
runtime enablement is stricter: parser and lifecycle validation fail closed
when evidence is incomplete.

## Enablement and timing

`lastroActivity_enabled` in `control/config.txt` is the global scheduling
switch. The rules file is selected by `lastroActivity_rulesFile`; the bundled
`control/lastro_activity.txt` is used only when no active control-file override
is found. `lastroActivity_leadSeconds` defaults to 10, so a countdown is acted
on about ten seconds before the announced start. An armed countdown does not
change AI, lock maps, inventory, or the shared monster-control file.

For a live configuration, do not set `enabled=1` while any map, announcement,
entry, target, or finish value is inferred rather than confirmed. The bundled
fixture intentionally keeps `enabled=1` in the source for evidence-backed
announcement tests; the parser changes incomplete sections to effective
`enabled=0`, and the lifecycle validator rejects missing entry evidence.

An enabled rule must provide both `announce_regex` for the registered server
announcement and `start_regex` for the scheduler's explicit start line. A
countdown in the announcement may supply the timing, but it does not remove
the requirement for those two evidence patterns.

`map_source` accepts only `static`, `dynamic`, or `announcement`. `static` and
`announcement` use the configured `entry_map`; `dynamic` requires a
`data-map="<map>#<x>#<y>"` value in the matching announcement. Fixed map names
must exist in the selected server map table, and dynamic announcement metadata
is checked against the loaded map table before entry.

## Current evidence fixture

The four confirmed announcement routes below can be armed by the scheduler,
but none is currently runnable end to end. Their missing lifecycle evidence is
deliberate and must be supplied before a server trial.

| Rule | Effective announcement routing | Lifecycle gate | Confirmed dynamic metadata |
| --- | --- | --- | --- |
| `city_monster_party` | `enabled=1` | Private Airship item and shared `search_targets` evidence are missing | `pvp_y_5-2#0#0` |
| `dojo_challenge` | `enabled=1` | Private Airship item and shared `search_targets` evidence are missing | `morocc#159#99` |
| `pool_challenge` | `enabled=1` | Private Airship item and shared `search_targets` evidence are missing | `payon#184#102` |
| `lottery` | `enabled=1` | Trusted NPC dialog attestation is missing; `prontera#152#129` is retained as the confirmed entry NPC location | `prontera#152#129` |
| `dungeon_monster_party` | Parser forces effective `enabled=0` | `announce_regex` and `start_regex` are absent | none |
| `sky_chest` | Parser forces effective `enabled=0` | `announce_regex` and `start_regex` are absent | none |

The source file's raw flags and the parsed effective state are intentionally
different for the last two rows. Do not treat a raw flag as proof that an
activity is runnable.

The Morocc and Payon announcements are accepted with `1分钟后`, `30秒后`, or
`10秒后`; lottery accepts `60秒后`, `30秒后`, or `10秒后`; the monster-party
fixture has the confirmed `10秒后` form. A ten-second countdown is due at
message receipt because the default lead time is also ten seconds.

Lines containing `下一次事件` are planning reminders, not start evidence, and
are rejected before a rule can be armed. Observed invasion metadata at
`alberta#0#0` and `aldebaran#0#0` is intentionally unbound: no existing rule
ID is mapped to either invasion, and no destination or monster data is
invented for them.

## Shared monster control

There is one combat source for every character: `control/mon_control.txt`. Its
columns are, in order:

```text
<monster> <attack> <teleport> <search> <skillcancel> <lv> <joblv> <hp> <sp> <weight>
```

An event monster may add `1` only in the third (`search`) column. Keep the
attack, teleport, skill, level, HP, SP, and weight columns exactly as the
operator maintains them. LastROActivity never rewrites this file and never
creates an event-specific copy.

`search=1` is a search gate, not an attack-priority override. During an event,
`teleportAuto_search=1` waits for one of the declared event targets to appear;
once a target is found, OpenKore still applies the existing `attack`, distance,
aggression, and skill settings from `mon_control.txt` to choose what to fight.

For a monster-search rule, `search_targets` must list server-confirmed monster
names or IDs that themselves have a matching shared row with `search=1`. The
production gate requires the exact declared key; it does not infer an ID/name
alias that may be absent from the runtime monster LUT. Do not add a target
based on a translated display name or an unverified database entry.

## Entry and return

Every activity uses the fixed return policy `privateairship:prontera`, which is
executed as `privateairship prontera` after finish, timeout, map loss, or a
failed entry. The original in-memory lock-map and teleport/search settings are
restored only after the return map is confirmed; normal OpenKore routing then
handles the trip back to the saved lock map.

NPC entry is additionally gated by the canonical metadata fields
`entry_npc_trusted=1` and a non-empty `entry_npc_evidence`. These fields attest
to a real server dialog sequence; they are not a substitute for testing the
sequence. Macro names must refer to an installed, tested macro.

## Evidence checklist

Before enabling any of the six rules, record all of the following from server
logs, map-change packets, or a user-supplied dialog transcript:

- the exact announcement line and its start/countdown wording;
- the internal map name (or confirmed dynamic-map announcement metadata);
- every event monster's internal name and numeric ID, plus its shared
  `mon_control.txt` row with only the third column changed to `1`;
- the entry method, item/NPC coordinates, and tested NPC or macro sequence;
- the exact finish announcement, phase completion text, or a measured positive
  duration fallback;
- the finish/reward macro text and any NPC result text when the activity uses
  an NPC or macro.

The lottery fixture retains the confirmed capital entry coordinates and NPC
identifier, but its trusted dialog sequence is intentionally unknown, so entry
is rejected until an attestation is recorded. The monster-party and challenge
fixtures likewise remain blocked until their item and shared-target evidence
is supplied; the dungeon and chest sections are parser-disabled until their
announcement lines are known. Bounty, personal, and world tasks are outside
this plugin's scope.

## Checks

From the repository root, run the focused production check with:

```text
$env:OPENKORE_DIR='D:\openkore'; perl plugins\LastROActivity\test\unit_tests.pl ProductionRulesTest
```

Run the complete activity unit set before a server trial:

```text
$env:OPENKORE_DIR='D:\openkore'; perl plugins\LastROActivity\test\unit_tests.pl RulesTest SchedulerTest StateTest ProductionRulesTest PluginTest
```

Only after the production test passes should a rule be enabled, and the first
run should use `lastroactivity run <event_id>` in a controlled account/session.
