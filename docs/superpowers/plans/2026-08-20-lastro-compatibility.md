# Lastro Protocol Compatibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Lastro sender match the web client's stable session, movement, and repeated basic-attack packet behavior.

**Architecture:** Keep all protocol-specific send behavior in `Network::Send::kRO::RagexeRE_2021_11_03`.  The generic AI continues to decide when to move or attack; its existing timeout hashes are adjusted only for an active Lastro session.  `NetworkTest` validates packet bytes through the real sender and a minimal network double.

**Tech Stack:** Perl 5, Test::More, OpenKore `Network::Send`, PacketCrypt.

**Spec:** `docs/superpowers/specs/2026-08-20-lastro-compatibility-design.md`

## Global Constraints

- Do not add a WebSocket transport layer or change generic AI target selection.
- Do not implement anti-cheat bypassing or client fingerprint spoofing.
- Preserve unrelated worktree changes and do not create a commit from the dirty worktree.
- Every production behavior change needs a failing `NetworkTest` assertion first.

---

### Task 1: Repair the Lastro NetworkTest fixture

**Files:**
- Modify: `src/test/NetworkTest.pm:103-213`

**Interfaces:**
- Consumes: `Globals::$masterServer`, `Network::Send->create`, `NetworkTest::FakeNet`.
- Produces: Lastro test setup that updates the scalar shared with `Network::Send` and a fake network with `serverAlive`, `getState`, `version`, and `serverSend`.

- [ ] **Step 1: Keep the existing failing baseline**

Run: `perl src/test/unittests.pl NetworkTest`

Expected: the `0065` test reports `got: '0', expected: '3'`, then the sender calls a missing `NetworkTest::FakeNet::version` method.

- [ ] **Step 2: Replace isolated `local $Globals::masterServer` fixtures**

Use a test helper that saves the shared imported `$masterServer`, assigns the
fixture for the duration of a callback, and restores it even when the callback
dies.  Do not use `local $Globals::masterServer`, because it creates a new
scalar that existing imported aliases do not observe.

```perl
sub with_master_server {
	my ($server, $code) = @_;
	my $previous = $masterServer;
	my (@result, $result, $ok, $error);
	$masterServer = $server;
	$ok = eval {
		wantarray ? (@result = $code->()) : ($result = $code->());
		1;
	};
	$error = $@;
	$masterServer = $previous;
	die $error unless $ok;
	return wantarray ? @result : $result;
}
```

- [ ] **Step 3: Add the missing fake-network method**

```perl
sub version { return 0; }
```

- [ ] **Step 4: Run the focused regression**

Run: `perl src/test/unittests.pl NetworkTest`

Expected: the `0065`, map-login, map-load, and sync tests pass without a
missing-method exception.

### Task 2: Start Lastro's browser-equivalent timers on map login

**Files:**
- Modify: `src/Network/Send/kRO/RagexeRE_2021_11_03.pm:15-77`
- Modify: `src/test/NetworkTest.pm:147-181`

**Interfaces:**
- Consumes: `%timeout` entries `ai_sync` and `ai_move_retry`.
- Produces: `sendMapLogin` sets `ai_sync` to 15 seconds, starts its timer, and
  sets movement retry to 0.5 seconds before normal AI begins.

- [ ] **Step 1: Write a failing Lastro timer test**

After `sendMapLogin`, assert that the real `%timeout` hash contains a
15-second `ai_sync` timeout, a defined `ai_sync` timestamp, and a 0.5-second
`ai_move_retry` timeout.  Restore the test's original timeout entries after
the assertion.

- [ ] **Step 2: Run the focused test to verify it fails**

Run: `perl src/test/unittests.pl NetworkTest`

Expected: the timer subtest fails because `sendMapLogin` has not configured
the timeout hashes.

- [ ] **Step 3: Add the minimal Lastro-specific initialization**

Import `Time::HiRes::time` and `%timeout` in the Lastro sender.  At the
start of `sendMapLogin`, set:

```perl
$timeout{ai_sync}{timeout} = 15;
$timeout{ai_sync}{time} = time;
$timeout{ai_move_retry}{timeout} = 0.5;
```

Keep the existing `sendSync(1)` early return so `007D` and `0AFF` remain the
only immediate map-load packets.

- [ ] **Step 4: Run the focused test to verify it passes**

Run: `perl src/test/unittests.pl NetworkTest`

Expected: all Lastro timer and map-entry tests pass.

### Task 3: Lock movement and repeated basic attack packet bytes

**Files:**
- Modify: `src/test/NetworkTest.pm:128-181`

**Interfaces:**
- Consumes: `sendMapLogin`, `sendMapLoaded`, `sendMove`, and `sendAction`.
- Produces: a regression for the encrypted packet sequence ending in a move
  to `(187,336)` and an action against `0x01020304` with flag `7`.

- [ ] **Step 1: Write a failing exact-wire test**

With the established PacketCrypt fixture, send map login, map loaded, move,
and action.  Assert literal hex payloads:

```perl
is(unpack('H*', $net->{sent}[3]), '046b2ed500', '035F move matches browser packing');
is(unpack('H*', $net->{sent}[4]), '35780403020107', '0437 repeated attack has expected layout');
```

- [ ] **Step 2: Run the test to verify the desired packet sequence**

Run: `perl src/test/unittests.pl NetworkTest`

Expected: it fails before the previous tasks are corrected, then passes once
the corrected fixture and timer initialization preserve the intended sequence.

- [ ] **Step 3: Keep production packet construction unchanged unless the test identifies a mismatch**

`035F` and `0437` already map to the web client's packet IDs, lengths, and
offsets.  No sender change is permitted in this task unless the literal
regression demonstrates different bytes.

- [ ] **Step 4: Run the complete network test suite**

Run: `perl src/test/unittests.pl NetworkTest`

Expected: exit status `0` and no `not ok` lines.

### Task 4: Manual protocol validation

**Files:**
- No repository changes.

**Interfaces:**
- Consumes: Lastro OpenKore profile with packet debugging enabled.
- Produces: browser and OpenKore captures covering login, 30-minute idle
  session, one move, and one repeated basic attack.

- [ ] **Step 1: Capture the browser reference actions**

With only the browser connected, capture all WebSocket frames for one manual
move and one normal basic attack.  Include the preceding and following frames
so PacketCrypt state can be reconstructed.

- [ ] **Step 2: Run the OpenKore validation session**

With the browser closed and one account logged in, run OpenKore for 30
minutes, then perform the same movement and basic attack.  Preserve the sent
and received packet debug output.

- [ ] **Step 3: Compare the evidence**

Confirm the map-entry sequence (`0436`, `007D`, `0AFF`), 15-second sync
cadence, `035F` coordinate payload, `0437` target ID and flag, and the absence
of unexpected disconnect or parser errors.  If a difference remains, create a
new single-cause regression before changing production code.
