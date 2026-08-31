# Task 1 report: generic LastRO dojo and sky-chest rules

## RED

Tests were updated before the production fixture. The focused suite was run
against the old fixture with:

```powershell
$env:OPENKORE_DIR='D:\openkore\.worktrees\lastro-activity-automation'; perl plugins/LastROActivity/test/unit_tests.pl RulesTest SchedulerTest ProductionRulesTest PluginTest
```

The command failed as expected. The failures exposed the old
`pool_challenge` route, city-specific party and dojo regexes, missing sky-chest
announcement evidence, and expectations for the pre-change event set.

## GREEN

The complete unit suite passes:

```powershell
perl plugins/LastROActivity/test/unit_tests.pl
```

Result: exit code `0`; all `121` subtests passed. The run emits only the
repository's existing Perl locale and wide-character warnings.

Include-aware syntax checks pass for the plugin and every runtime module:

```powershell
perl -I src -I src/deps -I plugins/LastROActivity -c plugins/LastROActivity/LastROActivity.pl
perl -I src -I src/deps -I plugins/LastROActivity -c plugins/LastROActivity/LastROActivity/Rules.pm
perl -I src -I src/deps -I plugins/LastROActivity -c plugins/LastROActivity/LastROActivity/Scheduler.pm
perl -I src -I src/deps -I plugins/LastROActivity -c plugins/LastROActivity/LastROActivity/State.pm
```

Each command reports `syntax OK` and exits `0`.

Additional checks:

- `git diff --check` exits `0`.
- A repository runtime scan found no direct `Commands::run("privateairship ...")`
  call in `plugins/LastROActivity`.

## Changed files

- `plugins/LastROActivity/control/lastro_activity.txt`: made dojo and city
  monster-party patterns location-generic, removed `pool_challenge`, and added
  dynamic sky-chest `tt` announcement rules with placeholder target `999999`.
- `plugins/LastROActivity/README.md`: documented the five canonical IDs,
  arbitrary-city/dojo matching, sky-chest placeholder behavior, and the
  fail-closed shared-control gate.
- `plugins/LastROActivity/test/RulesTest.pm`: updated fixture parsing assertions
  and generic pattern coverage.
- `plugins/LastROActivity/test/SchedulerTest.pm`: removed duplicate pool
  routing and covered sky-chest dynamic map extraction.
- `plugins/LastROActivity/test/ProductionRulesTest.pm`: updated production
  inventory, validation, route, and placeholder assertions.
- `plugins/LastROActivity/test/PluginTest.pm`: covered canonical routing,
  generic locations, whole-message dojo finish matching, and sky-chest runtime
  validation.
- `.superpowers/sdd/2026-09-01-lastro-generic-events/task-1-report.md`: this
  verification report.

## Residual concerns

`sky_chest` intentionally remains effectively disabled: `999999` is a
placeholder absent from shared `control/mon_control.txt`. Enabling it requires
the real server-confirmed monster ID and a matching shared `search=1` row; this
task deliberately does not modify shared monster control. The generic dojo
rule likewise remains blocked until confirmed search-target evidence is added.

The pre-existing Perl locale and wide-character warnings remain in the test
environment and do not affect the passing exit status.

## Fix Round 1

### RED

The focused regression was added before changing the production fixture and
run with:

```powershell
$env:OPENKORE_DIR='D:\openkore\.worktrees\lastro-activity-automation'; perl plugins/LastROActivity/test/unit_tests.pl SchedulerTest
```

The command exited with status `1`. The counted sky-chest case passed, while
the no-countdown case failed at the new assertions:

```text
not ok 71 - sky chest no-countdown announcement arms an event
#   Failed test 'sky chest no-countdown announcement arms an event'
#   at D:/openkore/.worktrees/lastro-activity-automation/plugins/LastROActivity/test/SchedulerTest.pm line 323.
not ok 72 - sky chest no-countdown announcement triggers immediately
#          got: undef
#     expected: '70000'
#   at D:/openkore/.worktrees/lastro-activity-automation/plugins/LastROActivity/test/SchedulerTest.pm line 324.
not ok 73 - sky chest no-countdown announcement preserves dynamic map coordinates
#   at D:/openkore/.worktrees/lastro-activity-automation/plugins/LastROActivity/test/SchedulerTest.pm line 327.
#     $got = undef
#     $expected = HASH(0x21ffdedc0d0)
# Looks like you failed 3 tests of 83.
```

This confirmed that the current `start_regex` rejected a valid no-countdown
announcement before `Scheduler::observe` could apply its zero-second default.

### GREEN

After making the countdown branch optional, the focused regression and related
production/plugin checks passed with:

```powershell
$env:OPENKORE_DIR='D:\openkore\.worktrees\lastro-activity-automation'; perl plugins/LastROActivity/test/unit_tests.pl SchedulerTest ProductionRulesTest PluginTest
```

Result: exit code `0`; all `97` reported subtests passed. The no-countdown
sky-chest event arms at receipt time and preserves `cmd_fild01#0#0`; the
counted event still preserves its countdown and ten-second lead window.

The sky-chest fixture and tests now document two independent activation gates:
the real monster ID plus a matching shared `search=1` row, and a confirmed
finish pattern, phase boundary, round-success boundary, or positive duration.
No completion signal or duration was invented.

### Fix files

- `plugins/LastROActivity/control/lastro_activity.txt`: made the sky-chest
  countdown branch optional and documented both fail-closed gates.
- `plugins/LastROActivity/README.md`: documented the missing completion
  boundary alongside the placeholder shared-search evidence for the sky-chest
  rule; the dojo rule remains blocked on shared-target evidence.
- `plugins/LastROActivity/test/SchedulerTest.pm`: added no-countdown immediate
  scheduling/map assertions and counted lead-window assertions.
- `plugins/LastROActivity/test/ProductionRulesTest.pm`: asserted the optional
  sky start pattern and both production evidence gates.
- `plugins/LastROActivity/test/PluginTest.pm`: asserted runtime completion
  validation remains independent of shared-search validation.
- `plugins/LastROActivity/test/RulesTest.pm`: clarified that parser-enabled
  sky-chest state still precedes runtime gates.
- `.superpowers/sdd/2026-09-01-lastro-generic-events/task-1-report.md`: this
  Fix Round 1 evidence.

### Fix residual concerns

`sky_chest` remains effectively disabled until both the real server-confirmed
monster target/shared `search=1` evidence and a separately confirmed completion
boundary are supplied. `dojo_challenge` remains blocked on its shared target
evidence; its generic finish pattern is already configured from the supplied
announcement examples. Shared `control/mon_control.txt` remains unchanged.
The pre-existing Perl locale and wide-character warnings remain in the test
environment.

### Final verification

The complete plugin suite was rerun after the fix:

```powershell
perl plugins/LastROActivity/test/unit_tests.pl
```

Result: exit code `0`; all `121` subtests passed. The run retains only the
pre-existing Perl locale and wide-character warnings.

Post-fix include-aware syntax checks all exited `0` and reported `syntax OK`:

```powershell
perl -I src -I src/deps -I plugins/LastROActivity -c plugins/LastROActivity/LastROActivity.pl
perl -I src -I src/deps -I plugins/LastROActivity -c plugins/LastROActivity/LastROActivity/Rules.pm
perl -I src -I src/deps -I plugins/LastROActivity -c plugins/LastROActivity/LastROActivity/Scheduler.pm
perl -I src -I src/deps -I plugins/LastROActivity -c plugins/LastROActivity/LastROActivity/State.pm
```

`git diff --check` exited `0`, and the runtime scan again found no direct
`Commands::run("privateairship ...")` call in `plugins/LastROActivity`.
