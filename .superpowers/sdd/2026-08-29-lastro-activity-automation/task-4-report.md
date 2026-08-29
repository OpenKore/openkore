# Task 4 Report: Wire the LastRO Activity Plugin

## Result

Implemented and committed the Task 4 plugin shell.

Commit: `953d1aff7` (`feat: wire LastRO activity plugin into OpenKore`)

Files in the commit:

- `plugins/LastROActivity/LastROActivity.pl`
- `plugins/LastROActivity/test/PluginTest.pm`
- `control/config.txt`
- `control/sys.txt`

The plugin registers `LastROActivity`, the six requested hooks, and the
`lastroactivity` command. It loads validated enabled rules through
`Settings::addControlFile`, accepts `Msg` with `RawMsg` fallback, keeps long
countdowns in `ARMED`, and routes due events through the single
`_start_due_event`/`begin_activity` boundary in `mainLoop_pre`. The Task 4
`begin_activity` body intentionally has no AI, inventory, map, Airship, or
runtime-config side effects; those remain for Task 5+.

## TDD Red

Command run before `LastROActivity.pl` existed:

```text
$env:OPENKORE_DIR='D:\\openkore\\.worktrees\\lastro-activity-automation'; perl plugins\\LastROActivity\\test\\unit_tests.pl PluginTest
```

Output:

```text
#### Starting PluginTest test ####
Unable to load LastROActivity.pl:  No such file or directory at D:/openkore/.worktrees/lastro-activity-automation/plugins/LastROActivity/test/PluginTest.pm line 127.
1..0
```

## Verification

Focused command:

```text
$env:OPENKORE_DIR='D:\\openkore\\.worktrees\\lastro-activity-automation'; $env:LC_ALL='C'; perl plugins\\LastROActivity\\test\\unit_tests.pl PluginTest
```

Exact output tail:

```text
#### Starting PluginTest test ####
ok 1 - registers the plugin hooks and command
ok 2 - uses Msg and falls back to RawMsg when arming
ok 3 - status and command validation have no unrelated side effects
ok 4 - mainLoop_pre invokes the due start boundary exactly once
1..4
```

The focused command exited `0`; its four subtests contained 24 passing
assertions.

Combined activity command:

```text
$env:OPENKORE_DIR='D:\\openkore\\.worktrees\\lastro-activity-automation'; $env:LC_ALL='C'; perl plugins\\LastROActivity\\test\\unit_tests.pl RulesTest SchedulerTest StateTest PluginTest
```

Exact output tail:

```text
#### Starting RulesTest test ####
#### Starting SchedulerTest test ####
#### Starting StateTest test ####
#### Starting PluginTest test ####
1..22
```

The command exited `0`; all 22 subtests passed.

Deterministic plugin syntax/load command:

```text
$env:LC_ALL='C'; perl -Iplugins\\LastROActivity\\test -Iplugins\\LastROActivity -e 'require PluginTest; my $r = do "./plugins/LastROActivity/LastROActivity.pl"; die "load failed: $@ $!\\n" if !defined $r; print "plugin syntax/load OK\\n";'
```

Exact output:

```text
plugin syntax/load OK
```

Whitespace check:

```text
git diff --check
```

Exact output: no output, exit `0`.

Post-commit repository check:

```text
git status --short --branch
git show --format=fuller --stat --oneline HEAD
```

Exact output:

```text
## codex/lastro-activity-automation
953d1aff7 feat: wire LastRO activity plugin into OpenKore
 control/config.txt                        |   5 +
 control/sys.txt                           |   2 +-
 plugins/LastROActivity/LastROActivity.pl  | 440 ++++++++++++++++++++++++++++++
 plugins/LastROActivity/test/PluginTest.pm | 222 ++++++++++++++++
 4 files changed, 668 insertions(+), 1 deletion(-)
```

## Runtime Dependency Check

The source-path-free syntax command fails before parsing because `AI.pm` is
not on `@INC`:

```text
$env:OPENKORE_DIR='D:\\openkore\\.worktrees\\lastro-activity-automation'; $env:LC_ALL='C'; perl -Iplugins\\LastROActivity -c plugins\\LastROActivity\\LastROActivity.pl
```

Exact output:

```text
Can't locate AI.pm in @INC (you may need to install the AI module) (@INC entries checked: plugins\\LastROActivity plugins\\LastROActivity C:/Strawberry/perl/site/lib C:/Strawberry/perl/vendor/lib C:/Strawberry/perl/lib) at plugins\\LastROActivity\\LastROActivity.pl line 21.
BEGIN failed--compilation aborted at plugins\\LastROActivity\\LastROActivity.pl line 21.
```

Adding `-Isrc -Isrc\\deps` reaches the OpenKore native dependency and fails
before plugin parsing because this host has no usable `XSTools.dll`:

```text
Error: XSTools.dll is not found. Please check your installation.
Can't locate loadable object for module XSTools in @INC (@INC contains: plugins\\LastROActivity src src\\deps plugins\\LastROActivity C:/Strawberry/perl/site/lib C:/Strawberry/perl/vendor/lib C:/Strawberry/perl/lib) at src/FastUtils.pm line 19.
```

The deterministic stubbed syntax/load check and activity unit suite do not
require that native extension.

## Concerns

- Task 4 intentionally defers interruption, runtime-config mutation,
  inventory/map checks, Airship lifecycle, and return cleanup to Task 5+.
- The default `lastro_activity.txt` first uses Settings auto-search in the
  active control folders, preserving a user-provided active-control override.
  When no active file resolves, it falls back to the shipped
  `plugins/LastROActivity/control/lastro_activity.txt` fixture. Explicitly
  configured absolute or directory paths load directly.
- Real OpenKore syntax checking remains dependent on the unavailable
  `XSTools.dll` in this host.

## Review Fix: Deferred Initialization and Rules Resolution

### Root Cause

OpenKore loads plugin files during `STATE_LOAD_PLUGINS`, then loads registered
configuration files during `loadDataFiles()`, and only calls `start3` after
that configuration load. The original plugin read `%config` and registered its
rules handle while the plugin file was being evaluated, so configured values
were not available and the default rules handle could resolve to no file.

### TDD Red

Command run before the deferred initialization fix:

```text
$env:OPENKORE_DIR='D:\\openkore\\.worktrees\\lastro-activity-automation'; $env:LC_ALL='C'; perl plugins\\LastROActivity\\test\\unit_tests.pl PluginTest
```

Exact output:

```text
#### Starting PluginTest test ####
not ok 1 - defers config initialization to start3
#   Failed test 'defers config initialization to start3'
Can't use an undefined value as a subroutine reference at D:/openkore/.worktrees/lastro-activity-automation/plugins/LastROActivity/test/PluginTest.pm line 189.
1..1
# Looks like you failed 1 test of 1.
```

The same red test also covered the missing bundled fallback, command
descriptor shape, and stale-rule reload behavior after those assertions were
added.

### Review Fix

- Keep safe defaults and a default scheduler at plugin load time.
- Read `lastroActivity_*` values and register rules once from `start3`.
- Let Settings auto-search active control folders first, then load the plugin
  bundled fixture only when the default name is unresolved.
- Use a scalar top-level command description followed by subcommand entries so
  OpenKore's `helpIndent` can render `help lastroactivity`.
- Treat an optional rules load with no resolved file as a failed reload, clear
  stale rules, and return failure for changed or unchanged missing paths.
- Keep the armed status candidate aligned with scheduler ordering when multiple
  rules match the same announcement.
- Route a pre-`start3` `reload` through the same guarded initialization path so
  it cannot register a duplicate rules handle.

### Verification

Focused command:

```text
$env:OPENKORE_DIR='D:\\openkore\\.worktrees\\lastro-activity-automation'; $env:LC_ALL='C'; perl plugins\\LastROActivity\\test\\unit_tests.pl PluginTest
```

Exact output:

```text
#### Starting PluginTest test ####
ok 1 - defers config initialization to start3
ok 2 - registers the plugin hooks and command
ok 3 - active control rules override the bundled fixture
ok 4 - uses values loaded before the deferred startup hook
ok 5 - uses Msg and falls back to RawMsg when arming
ok 6 - status and command validation have no unrelated side effects
ok 7 - mainLoop_pre invokes the due start boundary exactly once
ok 8 - failed rule reloads do not retain stale rules
ok 9 - overlapping announcements keep the scheduler winner armed
ok 10 - pre-start3 reload initializes only once
1..10
```

The focused command exited `0`; its 47 assertions passed. The combined
command also exited `0` with 28 passing subtests:

```text
$env:OPENKORE_DIR='D:\\openkore\\.worktrees\\lastro-activity-automation'; $env:LC_ALL='C'; perl plugins\\LastROActivity\\test\\unit_tests.pl RulesTest SchedulerTest StateTest PluginTest
```

`git diff --check` produced no output and exited `0`.

## Review Fix: Retry Gate and Transactional Reload Safety

### Root Cause

Two failure paths could leave the plugin in an unsafe or misleading state.
First, a failed initial rules load marked the plugin initialized, so later
hooks could retain defaults or repeatedly retry registration. Second, a
reload failure cleared the parsed rules but left scheduler timers, the armed
candidate, or queued manual work alive; an event from the previous rules file
could therefore still dispatch.

### Review Fix

- Initialization now commits `$initialized` only after a rules candidate is
  loaded and reconciled successfully. Failed attempts remove their temporary
  Settings handle and remain retryable.
- Lazy initialization records a signature of the relevant configuration after
  a failure. Runtime hooks do not retry the same failed configuration every
  `mainLoop_pre`; explicit `lastroactivity reload` and `start3` force a fresh
  attempt. This is the bounded-retry operational contract and avoids a retry
  storm while still allowing recovery after a file/configuration fix.
- Rules loading is transactional: candidates are parsed in a temporary
  context and committed only on success. A failed or missing load fail-closes
  the rules, scheduler timers, armed status, and pending queues.
- A `pre_load_lastro_activity_rules` hook detects optional-file skips during a
  generic Settings reload, selects the bundled fixture only when the active
  control file is absent, and fail-closes deleted files instead of retaining
  stale rules.
- Successful reloads reconcile existing timers and queues against the new
  validated rule set, preserving surviving events and pruning removed or
  invalid ones. The scheduler exposes `clear` and `events` for this boundary.

### Verification

Focused plugin suite:

```text
$env:OPENKORE_DIR='D:\\openkore\\.worktrees\\lastro-activity-automation'; $env:LC_ALL='C'; perl plugins\\LastROActivity\\test\\unit_tests.pl PluginTest
```

Result: exit `0`; all 20 top-level PluginTest subtests passed, including
failed-initial-load recovery, bounded lazy retries, transactional reload,
stale-timer cancellation, and generic Settings reload handling.

Combined activity suite:

```text
$env:OPENKORE_DIR='D:\\openkore\\.worktrees\\lastro-activity-automation'; $env:LC_ALL='C'; perl plugins\\LastROActivity\\test\\unit_tests.pl RulesTest SchedulerTest StateTest PluginTest
```

Result: exit `0`; all 38 top-level subtests passed.

The deterministic stubbed syntax/load check also passed, and `git diff --check`
reported no whitespace errors. Native OpenKore syntax checking remains
blocked by the host's unavailable `XSTools.dll`, as noted above.

### Operational Concern

If a missing rules file appears later without a configuration-key change,
automatic hooks intentionally remain gated. Operators should issue
`lastroactivity reload` (or restart so `start3` runs) after correcting the
file; this explicit recovery path is preferred to retrying registration on
every loop.
