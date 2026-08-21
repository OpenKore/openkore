# Lastro Protocol Compatibility Design

## Goal

Make the existing Lastro profile emit the same login, map-entry, heartbeat,
movement, and basic-attack packet shapes and timing as the web client, while
leaving OpenKore's generic AI decision-making unchanged.

## Scope

- Keep the direct TCP connection and the existing `PacketCrypt` key sequence.
- Keep Lastro-specific behavior in `Network::Send::kRO::RagexeRE_2021_11_03`.
- Repair `NetworkTest` so the tests exercise the actual `Globals` scalar and
  the fake network implements every method used by the sender.
- Use a 15-second sync interval and 0.5-second movement retry interval for
  the Lastro session only.
- Add exact encrypted-packet regressions for a representative move and a
  repeated basic attack.

## Non-goals

- Do not add a WebSocket transport layer.
- Do not alter OpenKore's target selection, route planning, or attack AI.
- Do not implement anti-cheat bypassing, client fingerprint spoofing, or
  behavior intended to evade server enforcement.

## Evidence and Decisions

The Lastro web client sets a 15-second `REQUEST_TIME` timer immediately after
it sends `CZ.ENTER`.  OpenKore's generic `ai_sync` interval is 12 seconds;
the Lastro sender will set the per-session timeout to 15 seconds and start it
when it sends map login.  The existing immediate map-load sync remains
suppressed.

The web client sends `CZ.REQUEST_MOVE` (`035F`) at most once every 500 ms.
OpenKore's generic retry default is 400 ms.  The Lastro sender will set only
`ai_move_retry` to 0.5 seconds.  The generic 1.2-second movement give-up
limit remains unchanged so a stalled route remains bounded.

For the fixed PacketCrypt fixture (`47DA30BB`, `234A5224`, `1B013ABC`) and
the representative values below, the verified encrypted packet stream is:

| Logical packet | Meaning | Wire bytes |
| --- | --- | --- |
| `0436` | map login | `7d44 01000000 02000000 03000000 00000000 00000000 00` |
| `007D` | actor init | `c915` |
| `0AFF` | load info | `706d` |
| `035F` | move to `(187,336)` | `046b 2ed500` |
| `0437` | repeated attack on `0x01020304` | `3578 04030201 07` |

## Acceptance Criteria

1. `perl src/test/unittests.pl NetworkTest` completes successfully.
2. The Lastro tests assert the packet stream above and the `0065` client type.
3. Manual validation uses one account with no browser client logged in:
   login, remain connected for at least 30 minutes, move, and execute a
   normal basic attack without protocol parse errors or an unexpected server
   disconnect.
4. A browser capture of one manual move and one normal basic attack is kept
   as evidence for any further protocol work.  It must include the complete
   WebSocket send order around each action.
