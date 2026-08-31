# LastRO Coordinate Teleport and Lottery Automation Design

## Scope

This change adds a LastRO-specific coordinate teleport command, migrates every
transfer issued by `LastROActivity` to that command, and uses it to make the
existing `lottery` activity runnable. It does not change the behavior of the
existing `privateairship` command outside `LastROActivity`, add bounty or hourly
task automation, or infer dialog answers beyond Continue and the first menu
option.

## Confirmed Protocol

The LastRO web client is the protocol authority for this feature. Its
`CZ_PRIVATE_AIRSHIP_REQUEST` packet is packet `0x0A49`, 34 bytes total, with
this layout:

| Offset | Size | Value |
| --- | ---: | --- |
| 0 | 2 | packet ID `0x0A49`, little-endian |
| 2 | 16 | zero-terminated map name (`Z16`) |
| 18 | 4 | X coordinate, little-endian unsigned 32-bit |
| 22 | 4 | Y coordinate, little-endian unsigned 32-bit |
| 26 | 4 | type, little-endian unsigned 32-bit |
| 30 | 4 | item ID, little-endian unsigned 32-bit |

Observed client behavior establishes two modes:

- map-only world-map requests send `x=0`, `y=0`, and `type=0`;
- quick-route requests with a destination coordinate send that `x/y` pair and
  `type=1`.

The client source does not provide a more specific semantic name for the type
field, so the implementation will preserve these observed values without
inventing one. The default item ID is `14527`, which is the server's fixed
teleport item/selector. A caller may explicitly override it.

## `tt` Command

`LastroAirship` will register a new command without replacing the existing
`privateairship` command:

```text
tt <map> [x y [item_id]]
```

Accepted forms are:

```text
tt prontera
tt prontera 152 133
tt prontera 152 133 14527
```

The first form sends map-only mode (`x=0`, `y=0`, `type=0`). The other two
send coordinate mode (`type=1`). When omitted, `item_id` is `14527`.

Validation is fail-closed:

- a non-empty map is required and its encoded value must fit the packet's
  16-byte map field;
- X and Y must either both be absent or both be present;
- X and Y must be decimal integers in `0..65535`, matching the web client's
  accepted coordinate range;
- `item_id` is accepted only after X and Y and must be a positive unsigned
  32-bit decimal integer;
- the command is available only on the LastRO server profile and while a
  message sender is available;
- invalid input logs a usage or validation error and sends no packet.

The LastRO network sender will expose the coordinate fields through a
backward-compatible extension of its existing private-airship send path.
Existing two-argument callers continue to emit the current map-only packet.

## Activity Transfer Policy

`LastROActivity` will use `tt` as its only transfer command for activity entry,
entry retries, failure cleanup, normal completion, and return to the capital.
No runtime path in this plugin may execute `privateairship`.

The activity destination is resolved once and retained for bounded retries:

- a named NPC entry uses the rule's confirmed `entry_map`, `entry_x`, and
  `entry_y`, even when announcement metadata points to a nearby clickable
  coordinate;
- a dynamic combat activity uses the map, X, and Y extracted together from
  its matching `data-map="map#x#y"` announcement;
- a static activity uses the configured map and uses configured X/Y when both
  are present;
- a destination without confirmed coordinates uses map-only `tt <map>` and
  never invents a coordinate.

Production combat rules will use `entry_type=tt`. Legacy `airship` and
`privateairship` entry-type values may remain parser-compatible for user
control files, but they are normalized to the same `tt` execution path and do
not call the old command. The default item ID comes from `tt`, so activity
rules no longer require an `entry_item_id` merely to use the fixed `14527`
default.

The canonical return policy becomes `tt:prontera` and executes `tt prontera`.
The return needs only a confirmed capital map because its purpose is to
restore the saved configuration and let the original lock map resume routing;
no return coordinate will be invented. The old `privateairship:prontera`
policy may be accepted as a compatibility alias, but it is also executed via
`tt prontera`.

## Lottery Rule

The production rule uses these confirmed values:

```text
event_id=lottery
entry_map=prontera
entry_x=152
entry_y=133
entry_npc_name=活动负责人#iz
entry_dialog_mode=repeat_first_until_finish
finish_regex=抽奖活动已结束
```

`entry_npc_name` is an NPC name, not a TalkNPC sequence. In particular, the
`#iz` suffix is part of the server-side NPC name and must never be parsed as
dialog commands. Existing sequence-driven NPC rules remain supported through
their existing field and behavior.

The rule parser will accept explicit fields for the named, event-driven dialog
mode. This confirmed operator-supplied name, coordinate, response policy, and
finish announcement replace the old requirement for an unknown fixed dialog
transcript. The rule remains fail-closed unless all named-dialog fields are
present and valid.

## Entry and Dialog Lifecycle

When the ten-second Lottery announcement becomes due, the activity controller
will follow this lifecycle:

1. Acquire the existing activity lock, stop the current attack/route work, and
   snapshot the normal lock-map and search settings.
2. Send `tt prontera 152 133`.
3. Wait for the existing map-change confirmation to report `prontera`; do not
   click an NPC while still on the previous map.
4. Resolve an NPC whose exact name is `活动负责人#iz` and whose observed
   position is `152,133`. Store its runtime actor ID as the only allowed dialog
   session ID.
5. Start one conversation with that actor.
6. For a Continue packet belonging to that actor ID, immediately send
   `sendTalkContinue`.
7. For a menu packet belonging to that actor ID, immediately send response
   value `1`, which is OpenKore's wire value for the first displayed option.
8. When the conversation closes, mark a re-click pending. The next
   `mainLoop_pre` starts a new conversation. This avoids re-entrant packet
   sends and simultaneous sessions without adding an artificial time delay.
9. Repeat steps 6-8 until the configured finish announcement is received.
10. Stop all Lottery dialog responses and re-clicks, run the one-shot
    `tt prontera` return, restore the saved settings, clear AI, and allow the
    saved lock map to resume normal routing.

If the character is already in `prontera`, the coordinate request is still
allowed; successful same-map confirmation follows the bounded confirmation
rules already used by the activity controller.

## Isolation and Safety

Automatic responses are active only while all of these conditions are true:

- the active event is `lottery`;
- the state is the Lottery entry/running dialog phase;
- the current map is `prontera`;
- the stored NPC actor still has the exact configured name and position;
- the incoming dialog packet's actor ID equals the stored actor ID;
- no finish announcement has been processed.

Packets from every other NPC are ignored. Only one Lottery conversation may
be active or pending at a time. A map change, disconnect, manual activity stop,
finish announcement, timeout, or cleanup clears the stored actor/session state.

The generic policy handles only Continue, menu choice, and close. A number
input, text input, shop, or other unsupported dialog request stops the Lottery
dialog loop, records an actionable warning, and enters the normal failure and
return path. It never guesses a value.

If the NPC is not yet visible after map load, the controller polls for it on
`mainLoop_pre` until the existing bounded entry timeout expires. A missing or
moved NPC, conflicting conversation, rejected teleport, or expired timeout
uses the existing activity failure cleanup and return flow.

## Compatibility

- `privateairship` keeps its current syntax and behavior for callers outside
  `LastROActivity`.
- Every `LastROActivity` transfer uses `tt`; tests and documentation must not
  retain a production activity command expectation containing
  `privateairship`.
- Existing LastRO route acceleration outside `LastROActivity` keeps sending
  its current map-only requests.
- Existing fixed-sequence NPC activity rules keep their current TalkNPC path.
- No global `autoTalkCont` setting is enabled or changed.
- Shared `mon_control.txt` is untouched because Lottery has no combat search
  targets.
- The canonical activity return policy is `tt:prontera`; the legacy policy is
  only a parser compatibility alias and never selects the old command.

## Verification

Automated coverage will include:

- exact 34-byte packet reconstruction for default and explicit coordinates,
  type values, default item ID, and overridden item ID;
- every accepted `tt` syntax and rejection of partial, malformed, out-of-range,
  overlong, non-LastRO, and disconnected requests;
- production-rule parsing with the corrected NPC coordinate and named-dialog
  fields, with effective Lottery enablement;
- immediate interruption followed by coordinate transfer before NPC contact;
- coordinate entry and retry commands for all dynamic activity metadata, with
  no `privateairship` command emitted by `LastROActivity`;
- delayed NPC visibility after map load;
- immediate Continue and first-option responses for the matching actor ID;
- ignoring packets from another NPC;
- close-to-re-click behavior with one session at a time;
- finish-announcement shutdown with no later response or re-click;
- unsupported dialog, missing NPC, map loss, transfer rejection, and timeout
  cleanup;
- restoration of the original lock map and normal AI after return.
- `tt prontera` as the only normal, failure, timeout, and manual-stop return
  command.

The focused sender, `LastroAirship`, and `LastROActivity` suites will run before
the full relevant OpenKore test set. A manual server check will then verify
`tt prontera`, `tt prontera 152 133`, and one controlled Lottery cycle.
