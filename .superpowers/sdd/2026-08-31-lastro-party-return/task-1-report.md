# Task 1 Report

## Scope

Implemented explicit normal combat for the LastRO monster-party lifecycle and
fixed confirmed same-map Lottery cleanup.

## Changes

- `plugins/LastROActivity/LastROActivity/Rules.pm`
  - Parses `combat_mode` and `random_walk`.
  - Accepts only `combat_mode=normal` after trimming and case folding.
  - Lets normal-combat rules omit `search_targets`; unsupported modes fail closed.
- `plugins/LastROActivity/LastROActivity/State.pm`
  - Snapshots and restores `route_randomWalk`, including whether it was absent.
  - Keeps the two-argument `apply_activity_config` API and adds an optional combat-mode argument.
  - Applies the normal-combat teleport and random-walk settings without changing `attackAuto`.
- `plugins/LastROActivity/LastROActivity.pl`
  - Validates and normalizes runtime combat mode.
  - Bypasses shared-search validation for normal combat while retaining the activity snapshot.
  - Completes confirmed `prontera` returns directly for Lottery and other activity types.
- `plugins/LastROActivity/control/lastro_activity.txt`
  - Enables `city_monster_party` with `combat_mode=normal`, `random_walk=1`, dynamic map routing, and empty `search_targets`.
- Tests updated or added in `plugins/LastROActivity/test/`
  - `RulesTest.pm`, `StateTest.pm`, `ProductionRulesTest.pm`, `PluginTest.pm`, and `SchedulerTest.pm` cover parser, state, production, lifecycle, and stale expectation changes; the production validator also rejects unsupported explicit combat modes.

## TDD Evidence

### RED

After adding the focused normal-combat, route-snapshot, and same-map Lottery
tests before the production changes, this focused command exited non-zero:

```text
perl plugins/LastROActivity/test/unit_tests.pl RulesTest StateTest ProductionRulesTest PluginTest
```

The failures covered the expected missing behavior: normal combat was rejected
for absent search evidence, `route_randomWalk` was not part of the
snapshot/config transition, and confirmed same-map Lottery cleanup still issued
`tt prontera`.

For the review follow-up, the exact focused RED command was:

```text
perl plugins/LastROActivity/test/unit_tests.pl ProductionRulesTest
```

Observed output before adding production `random_walk` validation:

```text
exit=1
not ok 12 - invalid random_walk values are rejected
#                   ''
#     doesn't match '(?^:random_walk)'
# Looks like you failed 1 test of 22.
```

### GREEN

- `perl plugins/LastROActivity/test/unit_tests.pl`
  - Exit code 0; all 120 top-level tests passed.
- `perl -I src -I src/deps -c plugins/LastROActivity/LastROActivity.pl` and syntax checks for every `*.pm` under `plugins/LastROActivity/LastROActivity`
  - Exit code 0; all plugin/module syntax checks reported `syntax OK`.
- `git diff --check`
  - Exit code 0.

## Review Follow-up

- Documented the normal-combat party exception and temporary route settings in
  the README and production fixture header.
- Extended `ProductionRulesTest` to assert trimmed/case-insensitive normal mode,
  `random_walk=1` with empty search targets, and rejection of invalid
  `random_walk` values.
- Added the missing production-level `random_walk` validation; the focused
  `ProductionRulesTest` rerun exited 0 with both subtests passing.

## Residual Concerns

- Perl emits locale fallback warnings in this environment; they do not affect
  test or syntax exit status.
- Directly invoking `LastROActivity.pl` without `-I src -I src/deps` still
  cannot resolve OpenKore modules such as `AI.pm`; the required include-aware
  syntax check passes.
- Untracked XSTools and HTTP-reader build artifacts were pre-existing and were
  intentionally excluded from the commit.
