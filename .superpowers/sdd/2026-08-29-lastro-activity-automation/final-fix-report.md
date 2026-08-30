# LastROActivity Final Fix Report

## Scope and result

This report records the final review fix wave for the LastROActivity activity
automation branch. The implementation now fails closed when round identity,
return confirmation, lifecycle evidence, or shared-search metadata cannot be
verified. The bundled production fixture still contains all six first-phase
event IDs, but every rule remains effectively disabled until server-specific
evidence is supplied.

## Review finding and historical RED

The final scoped review found that dojo round de-duplication only remembered an
identical start message at the same clock instant. A delayed replay (for
example, the same packet arriving six seconds later) could therefore be treated
as a new round and allow a replayed success message to increment the round
counter. A start message without a stable identity had the same ambiguity once
the short time window expired.

The review also exposed lifecycle variants of the same fail-closed problem:

- a return timeout or rejected return could clear the activity snapshot before
  a `prontera` map packet proved that the character had arrived;
- runtime validation could accept malformed patterns, a non-canonical return
  route, or a search target that the runtime resolver could not authorize;
- stale resurrection-capable party records could be polled while entry or
  finish work was still pending.

These were the historical RED conditions. The regression fixtures now cover a
delayed duplicate, a later round with a distinct identity, an unidentified
replay, return timeout confirmation, strict runtime/parser validation, and
entry/finish-state death polling.

## Fixes

- Extract and canonicalize round identities from `round_id_regex`, captures in
  the round-start pattern, or a documented ordinal form. Completed identities
  are retained for the entire activity; unidentified starts are accepted only
  before an unidentified/completed round exists.
- Keep a failed return pending after command rejection or timeout. The config
  snapshot and activity lock are restored only after `packet_mapChange`
  confirms `prontera`.
- Validate explicit return policies, announcement/finish/phase/round identity
  patterns, and exact shared `mon_control.txt` keys consistently in parser and
  runtime paths.
- Poll party death records only while the confirmed activity is `RUNNING`, and
  recognize the supported resurrection-capable job variants.
- Extend parser, lifecycle, and plugin tests and document the round identity
  and fail-closed requirements in the LastROActivity README.

## Fresh GREEN verification

All commands below were run from
`D:\openkore\.worktrees\lastro-activity-automation` with
`OPENKORE_DIR=D:\openkore` and `LC_ALL=C` where shown.

Focused suites:

```text
perl plugins\LastROActivity\test\unit_tests.pl RulesTest
exit=0; final plan 1..14

perl plugins\LastROActivity\test\unit_tests.pl SchedulerTest
exit=0; final plan 1..5

perl plugins\LastROActivity\test\unit_tests.pl ProductionRulesTest
exit=0; final plan 1..2

perl plugins\LastROActivity\test\unit_tests.pl PluginTest
exit=0; final plan 1..85
```

The complete activity runner also exits `0`, reports no `not ok` assertions,
and ends at `1..112`:

```text
perl plugins\LastROActivity\test\unit_tests.pl
exit=0; final plan 1..112
```

Additional scoped lifecycle regressions now pass:

- NPC, private-airship, and macro entry requests confirm an already-current
  destination map and reach `RUNNING` without requiring a duplicate map packet;
- a `RUNNING` map-loss packet received while the live map is already `prontera`
  finalizes immediately, issues no second return transfer, and restores the
  exact pre-activity configuration;
- an unconfirmed entry timeout or command rejection while still on source
  `prontera` retains the failed lifecycle and canonical return request, so a
  delayed entry-map arrival cannot strand the character after premature
  cleanup;
- live-field entry confirmation remains retryable after a rejected airship
  result, while an authoritative map-change confirmation still fails closed on
  a late rejection.

Pure-Perl syntax checks pass for `Rules.pm`, `Scheduler.pm`, `State.pm`, all
five activity test modules, and `unit_tests.pl`. The deterministic stubbed
plugin load check also passes:

```text
perl -Iplugins\LastROActivity\test -Iplugins\LastROActivity -e 'require PluginTest; my $r = do "./plugins/LastROActivity/LastROActivity.pl"; die "load failed: $@ $!\n" if !defined $r; print "plugin syntax/load OK\n";'
exit=0
plugin syntax/load OK
```

Repository checks pass:

```text
git diff --check
exit=0

git diff --exit-code -- control\mon_control.txt
exit=0
```

## Native check limitation

Direct compilation of the production plugin and the related OpenKore baseline
suite remain blocked before test execution by the host's incompatible or
unavailable `XSTools.dll`:

```text
perl -c -I"D:\openkore\src" -I"D:\openkore\src\deps" plugins\LastROActivity\LastROActivity.pl
exit=1
Error: XSTools.dll is not found. Please check your installation.

perl src\test\unittests.pl FileParsersTest PluginsHookTest TaskTalkNPCTest NetworkTest
exit=1
Error: XSTools.dll is not found. Please check your installation.
```

This is an environment/toolchain limitation, not a failure reported by the
pure-Perl activity suite or the deterministic stubbed load.

## Production and trial status

`ProductionRulesTest` confirms the six bundled rules retain their raw fixture
flags but parse to effective `enabled=0` with auditable validation errors.
No event monster rows, maps, finish messages, or lottery dialog steps were
invented, and `control\mon_control.txt` is unchanged. No live server trial was
run because confirmed server evidence and credentials are unavailable.

Before enabling a rule, capture its exact announcement/start evidence,
destination map, entry method, shared search rows, finish/phase evidence, and
return behavior, then run one controlled account/session through the README
checklist.
