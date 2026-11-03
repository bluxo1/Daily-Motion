# First safe MVP completion slice

Candidate: measured working-set records (PRD15), proposed PR22. Baseline
`852eedf04de74110c6cf001699094c4c16f00fc1`. Investigation/design precedes the
implementation; dated raw results and final source identities live in the new
ignored task evidence package. This document is finalized after actual checks.

## Selection

Progress already renders source-backed charts, but its source explicitly says
there are no records. Positive external-load records and fixed-load repetition
records are accepted MVP, unlike estimated strength or Phase2 aggregate analytics.
They can derive solely from existing corrected observations without changing
owner data, schemas, HTTP contracts, frozen requests or release admission.

More urgent release creation/privacy/resolution gates need separate architectural,
product or external acceptance. Local deletion is expressly refused; adding a
button would bypass necessary erasure/outbox design. Removing the release gate
would enroll owners without production admission. Neither is done here.

## Bounded acceptance contract

* Reuse exact ExerciseKey and the existing completed-working-set/completed-workout
  eligibility filter. Never include prescribed targets, drafts, warm-ups,
  partial/failed/skipped outcomes or active/abandoned workouts.
* Compute highest **positive** recorded external load separately per original
  unit for supported bases; never use approximate chart coordinates or convert
  kg/lb. Zero remains a genuine recorded value, not a highest-load achievement.
* Group repetition records at exactly equal numeric loads within the same unit,
  basis, side and repetition convention. Trailing decimal zeros compare equally;
  preserve the supporting original value string and source IDs. Bodyweight-only
  reps have no fictitious external load. Positive assistance never gets a
  highest-load achievement; its context remains explicitly assistance.
* Retain deterministic source selection/tie counts and source-workout navigation,
  current snapshot/local-sequence provenance and conflict warning. Records derive
  from current saved observations, including pending local work, not a claim of
  server acceptance or physiological capacity.
* Rebuild after correction, deletion and owner replacement using the existing
  provider invalidation. No persisted record cache or second state authority.
* Bound visible fixed-load rows with pagination. Keep existing chart paging and
  large-history worker behavior. Test narrow/large-text, both themes, semantics,
  keyboard and reduced-motion configuration; leave physical qualification open.

No public routine enablement, admission API, profile migration, account privacy
workflow, server command, catalog synchronization, automatic conflict resolution,
prediction or O3 work is included. See the [matrix](MVP_COMPLETION_MATRIX.md),
[next PRs](MVP_EXECUTION_PLAN.md) and [release gates](MVP_RELEASE_READINESS.md).

## Implementation and review boundary

`MeasuredProgress.records` derives eagerly beside existing worker computation.
`MeasuredRecordsScreen` reads the same owner-scoped provider; refresh hides stale
private values, source navigation checks repository identity, and the current
route observes authoritative disable. The screen pages twenty exact-load groups.
No persistent record authority, request rewriting or public routine admission is
introduced. Source revision/local sequence accompany supporting observations.

Deterministic controls cover exact decimal comparison, eligibility, separate units,
assistance/bodyweight, ties, corrections/removal, records outside the chart window,
320px/200% light/dark layouts, keyboard activation, file-backed correction/read
failure/retry/sign-out and authoritative disable. The existing two-device HTTP
journey additionally asserts record provenance before and after correction.

The preserved red entry test demonstrates the missing product path. Subsequent
failed runs exposed test-fixture status/identity and offscreen-navigation mistakes;
those controls were corrected rather than excluded. Final execution receipts,
actual counts, generated comparisons, source identities and patch reconstruction
are in the task-owned portable review bundle. Focused/internal/connected counts
are separate from the ordinary suite. Hosted and physical-device checks remain
unexecuted here. Desktop controls do not qualify phone accessibility or durability.

Review this as a local candidate, not a project-completion or public-release claim.
The next implementation sequence and required decisions remain in the execution
plan. No commit, push, PR, merge, deployment or public feature enablement is part
of this work.

## Source and executable controls

The [record derivation](../apps/mobile/lib/domain/measured_progress.dart),
[record screen](../apps/mobile/lib/features/measured_records_view.dart) and
[chart entry](../apps/mobile/lib/features/measured_progress_view.dart) are the
complete product change. Controls are [exact-value/domain tests](../apps/mobile/test/measured_records_test.dart),
[route/layout/keyboard tests](../apps/mobile/test/measured_records_widget_test.dart),
[file-backed account tests](../apps/mobile/test/measured_records_account_test.dart)
and [actual two-device HTTP assertions](../apps/mobile/test/routine_connected_http_test.dart).

The first complete database run exposed a connected-harness visibility mistake:
the source card was partly visible but the test tapped its action behind the
fixed paging footer. The corrected control reveals the actual action and asserts
hit-testability before tapping. All fifteen connected routine cases then passed
in a separate real-PostgreSQL replay. The original failed run and pre-fix patch
remain in the evidence; final full qualification must follow this correction.
