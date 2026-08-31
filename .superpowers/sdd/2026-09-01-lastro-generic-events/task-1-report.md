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
