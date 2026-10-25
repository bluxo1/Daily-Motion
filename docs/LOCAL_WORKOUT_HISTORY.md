# Local multi-exercise workout and history slice

This implementation extends the existing session projection and local repository.
It adds no tables, migrations, remote fields, authentication flows or routine
synchronization. Schema v5 and the routine entry point introduced in
[local routine authoring](LOCAL_ROUTINE_AUTHORING.md) retain their existing scope.
Phase 0 remains in progress; Phase 1 rollout is not authorized.

## Workout entry

A saved routine starts through the existing transactional, owner-scoped repository.
Every exercise instance appears in prescription order, including repeated variants.
Each exercise exposes its next pending set, so users can move between exercises.
Set order within each exercise remains the prescription order. Entries identify the
exercise and set by immutable IDs, not the current screen position.

The screen displays the snapshot's load basis, repetition convention, side and
prescribed unit. Bodyweight-only entry has no external-load field. Completed,
partial and failed attempts show their actual values; skipped observations have no
performed values. Unobserved sets remain planned and unperformed. Corrections keep
their reason and logged completion order, including corrections after completion.

The UI controller serializes its commands and reads fresh session state before
assigning each observation's completion sequence. It captures the owner repository
and child IDs at invocation. Repository transactions, owner locks, single-active
session checks and completion rules remain authoritative. This is a UI queue, not
a new synchronization or distributed concurrency protocol.

Drafts still use the existing owner database. Visited pending editors remain alive
while the workout screen is open, including after a draft write fails. An error
asks the user to keep the screen open and retry. Failed writes are **not** promised
to survive navigation, process termination or device loss. Correction-sheet input
is not a persisted draft; dismissing the sheet discards unsaved correction text.
Rest uses the existing persisted timer and clock uncertainty rules. A refresh
requested during an earlier timer read triggers another read before settling.

Finishing still requires an attempted observation at completion time; original
skipped-only or unobserved workouts cannot be completed. Abandoning retains the
recorded data. Confirmation and write guards prevent duplicate UI submissions.

## History and observed performance

History reads the existing workout projections. It lists completed and abandoned
workouts by descending start instant. Dates explicitly use UTC; workout detail
also displays the stored IANA timezone. It reports attempted observations,
skipped observations and unperformed sets separately. Planned sets are never
counted as performed work. Opening history uses the same all-exercise detail and
correction paths. Later routine edits do not change a started session snapshot.

Progress is deliberately limited to individual completed **working-set**
observations from completed workouts. Warm-ups, partial and failed attempts,
skipped sets, abandoned workouts and unperformed plans remain visible in History.
There are no personal records, combined scores, load conversion, rankings or
predictions. Every entry retains its exercise instance, source workout, load
basis, repetition convention and side. Equal exercise names or repeated variants
are not combined. Null actual load is omitted; a genuine recorded zero remains
visible as zero with its unit.

## Review and qualification boundaries

Deterministic tests cover the actual widget/controller/repository paths, file-backed
SQLite reopening, source-routine edits, interleaved exercise saves, corrections,
failed writes, draft retention, loading/errors, owner locking and narrow layouts.
The existing nine-case connected harness additionally exercises the production
controller's multi-exercise operations against loopback HTTP and disposable
PostgreSQL, retaining its corrected-skipped bootstrap controls. Focused tests are
subsets of the full suites and must not be added to their totals.

Desktop tests do not qualify physical-device persistence, performance,
accessibility, native builds or production recovery. Local HTTP tests do not
qualify hosted providers, real inbox delivery or verified account synchronization.
The three external/provider Flutter cases remain unexecuted. No O3 G1/B4/B5
implementation or D1–D11 approval follows from this slice.

Future review boundaries include pagination and measured performance for large
histories, timezone-localized dates, broader progress analysis, and physical-device
interaction testing. Routine cloud synchronization remains a separate contract
decision.
