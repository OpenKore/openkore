# LastROActivity operations

LastROActivity listens for explicitly configured LastRO activity announcements,
waits until the configured lead time, and temporarily hands control to the
activity lifecycle. The bundled rules preserve all six first-phase event IDs
and their raw enable flags. Effective runtime enablement is stricter: parser
and lifecycle validation fail closed when evidence is incomplete.

## Enablement and timing

`lastroActivity_enabled` in `control/config.txt` is the global scheduling
switch. The rules file is selected by `lastroActivity_rulesFile`; the bundled
`control/lastro_activity.txt` is used only when no active control-file override
is found. `lastroActivity_leadSeconds` defaults to 10, so a countdown is acted
on about ten seconds before the announced start. An armed countdown does not
change AI, lock maps, inventory, or the shared monster-control file.

For a live configuration, do not set `enabled=1` while any map, announcement,
entry, target, or finish value is inferred rather than confirmed. The bundled
fixture intentionally keeps `enabled=1` in the source for evidence auditing;
the parser changes incomplete sections to effective `enabled=0`. Lottery is the
exception in this fixture because its named NPC, coordinates, dialog mode, and
finish evidence are complete.

An enabled rule must provide both `announce_regex` for the registered server
announcement and `start_regex` for the scheduler's explicit start line. A
countdown in the announcement may supply the timing, but it does not remove
the requirement for those two evidence patterns.

`map_source` accepts only `static`, `dynamic`, or `announcement`. `static` and
`announcement` use the configured `entry_map`; `dynamic` requires a
`data-map="<map>#<x>#<y>"` value in the matching announcement. Fixed map names
must exist in the selected server map table, and dynamic announcement metadata
is checked against the loaded map table before entry.

## `tt` transport

Activity transfers use the LastRO `tt` command. The accepted forms are:

`tt <map> [x y [item_id]]`

```text
tt <map>
tt <map> <x> <y>
tt <map> <x> <y> <item_id>
```

The map-only form uses the default item `14527` and the map-only protocol
variant. Coordinates select the coordinate variant; an explicit `item_id` is
the final token and overrides `14527`. A return is always map-only:
`tt prontera` (the configured return policy is `tt:prontera`).

The resolved destination is retained from the first request through bounded
retries. Coordinate precedence is: named repeating NPC rules use their
configured `entry_x`/`entry_y`; `dynamic` rules use the matching announcement's
`data-map`; `static` and `announcement` rules use their configured map and
coordinates. Coordinates are emitted only as a complete pair. The parser still
accepts legacy `airship`/`privateairship` entry types and
`privateairship:prontera` return aliases for old control files, but production
rules and runtime commands use `tt`.

## Current evidence fixture

The four confirmed announcement routes below retain their raw `enabled=1`
flags for evidence auditing. The three combat routes remain effectively
disabled until shared target evidence is supplied. Lottery is effectively
enabled because its named-dialog evidence is complete.

| Rule | Raw source flag / effective runtime state | Lifecycle gate | Confirmed entry metadata |
| --- | --- | --- | --- |
| `city_monster_party` | raw `1` / effective `0` | `search_targets` evidence is missing | dynamic `pvp_y_5-2#0#0` |
| `dojo_challenge` | raw `1` / effective `0` | `search_targets` evidence is missing | dynamic `morocc#159#99` |
| `pool_challenge` | raw `1` / effective `0` | `search_targets` evidence is missing | dynamic `payon#184#102` |
| `lottery` | raw `1` / effective `1` | named NPC and repeating-dialog fields are complete | static `prontera 152 133`, `活动负责人#iz` |
| `dungeon_monster_party` | raw `1` / effective `0` | `announce_regex` and `start_regex` are absent | none |
| `sky_chest` | raw `1` / effective `0` | `announce_regex` and `start_regex` are absent | none |

The source file's raw flags and parsed effective state are intentionally
audited separately. Do not treat a raw flag as proof that an activity is
runnable. Announcement-only evidence cannot activate a lifecycle.

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

## Lottery dialog

The enabled Lottery rule is deliberately exact:

```text
entry_type=npc
entry_map=prontera
entry_x=152
entry_y=133
entry_npc_name=活动负责人#iz
entry_dialog_mode=repeat_first_until_finish
```

`#iz` is part of the NPC name. After `tt prontera 152 133` is confirmed, the
plugin binds only an actor with that exact name and position. It sends the
first `sendTalk` on the next main-loop turn, answers Continue immediately, and
sends wire response `1` immediately for the first menu option. A close packet
marks one re-click for the next main-loop turn; it does not recurse in the hook,
sleep, or add an artificial delay. The finish line `抽奖活动已结束` stops all
responses and re-clicks, clears the dialog state, and starts the normal return.

Number, text, shop, and any unsupported Lottery dialog input fail closed. The
plugin records a warning in the form `[LastROActivity] <reason>.`, restores the
temporary activity settings through the common cleanup path, and requests
`tt prontera`; it never guesses a value or a different NPC.

For a normal run, the expected transport and lifecycle sequence is:

```text
tt prontera 152 133
[internal lifecycle event] Lottery NPC bound: 活动负责人#iz at prontera 152 133
sendTalk(<actor-id>)
sendTalkContinue(<actor-id>)
sendTalkResponse(<actor-id>, 1)
抽奖活动已结束
tt prontera
```

The first and last lines are the exact transport commands. The binding line is
an internal lifecycle event, not a default console message; confirm it from the
following `sendTalk(<actor-id>)` or an enabled debug trace. The remaining lines
represent the expected response, finish, and return events; actor IDs are
session-specific. Failures use `[LastROActivity] <reason>.` and still request
`tt prontera`. A ten-second announcement is due at message receipt because the
default `lead_seconds` is also ten seconds.

## Entry and return

Every activity uses the fixed return policy `tt:prontera`, executed as
`tt prontera` after finish, timeout, map loss, or a failed entry. The original
in-memory lock-map and teleport/search settings are restored only after the
return map is confirmed; normal OpenKore routing then handles the trip back to
the saved lock map.

Round-based activities must provide both `round_start_regex` and
`round_success_regex`.  Give `round_start_regex` a capture for the server's
stable round number (or configure `round_id_regex` for a separate token).  The
plugin remembers completed identities for the entire activity, so repeated
packets cannot replay a success.  When a start packet has no verifiable
identity, only the first such round is accepted; later unidentified starts are
ignored until the rule supplies distinguishable evidence.

Legacy fixed-sequence NPC entry is gated by `entry_npc_trusted=1` and a
non-empty `entry_npc_evidence`. The explicit Lottery repeating mode above uses
the exact name, map, coordinate pair, supported mode, and finish regex instead;
it does not require a legacy trust-attestation field. Macro names must refer to
an installed, tested macro.

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

Lottery is enabled with the confirmed `prontera 152 133` NPC identity and the
bounded repeating first-option dialog mode. The monster-party and challenge
fixtures remain blocked until shared `search_targets` evidence is supplied;
the dungeon and chest sections remain parser-disabled until their announcement
lines are known. Bounty, personal, and world tasks are outside this plugin's
scope.

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
