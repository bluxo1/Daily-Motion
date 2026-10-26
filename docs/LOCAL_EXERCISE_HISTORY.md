# Local exercise history and measured progress

This local feature extends the [workout history slice](LOCAL_WORKOUT_HISTORY.md)
and [saved routines](LOCAL_ROUTINE_AUTHORING.md). Phase 0 remains in progress;
provider, operator and physical-device qualification remain open. This does not
authorize Phase 1 rollout or public release.

## Using recorded history

Open **Progress**, find an exercise and open its history. Exercise entries require
an actual observation in a completed or abandoned workout. Unperformed plans and
active sessions do not create browse entries. Search includes historical names;
names never determine comparison identity.

Each page shows up to ten source workouts, newest first by workout start time,
with an oldest-first option and navigation to older pages. Repeated exercise
instances remain separately identified inside their source workout. Sets retain
their prescription order, with class, purpose, effective outcome and correction
reason. Completed, partial, failed, skipped and unperformed sets are distinct;
abandoned workouts are explicitly labelled. Open the source workout to inspect
or correct an observation using the existing correction flow.

The completed-working-set filter excludes warm-ups and other outcomes. The load
unit filter preserves original recorded units. Individual load and repetition
values can be read across chronological source workouts; no totals, rankings,
personal records, estimated strength or physiological conclusions are calculated.
There is no chart or numerical aggregation in this bounded implementation. The
textual source list is the progress view, including cases that cannot support a
meaningful numerical trend.

## Comparison boundaries

The key is the stored variant UUID, loading basis, repetition convention and
recorded side. An unspecified side stays unspecified; it is not inferred to mean
both, left or right. The implemented projection has no separate equipment/setup
identifier. Variant identity is the available equipment/setup boundary; the UI
does not infer compatibility from a display name. Distinct variants sharing a
name remain separate, with their identities displayed for disambiguation.

Kilograms and pounds are never converted, added or ranked. Bodyweight-only work
has no external-load value. Missing load is not zero; an actual zero remains
zero. Positive assistance remains positive assistance, not negative load or a
claim of improvement. Per-side, alternating-total and bilateral repetitions are
never summed together. Set purpose and warm-up/working class remain visible.

## Previous performance while logging

Each active exercise can show up to three completed working sets from its most
recent comparable completed source workout, with links to all exercise history
and that source workout. Current and other active sessions, abandoned workouts,
warm-ups, partial/failed attempts, skipped and unperformed sets cannot become this
reference. No reference values are copied into today's actual observation.

History loading and errors have an independent, non-blocking presentation state.
They do not disable the set editor, change drafts, cancel rest timers or bypass
workout command serialization. Returning from source history preserves the active
editor. A lack of comparable completed work is an explicit empty state.

## Local data and correction consistency

The existing owner-guarded SQLite projections remain the only source. There is no
new schema, API, synchronization protocol, repository, history table or persisted
aggregate. One owner-scoped asynchronous presentation index is rebuilt when the
workout provider changes. Large histories (more than 2,000 prescribed sets) use
an isolate for indexing; browser entries and detail pages bound widget creation.
Existing projection reads still load the owner's full local history; this is not
an unlimited-history performance qualification.

Only the latest effective observation is indexed. Superseded observations and
outbox events are not accumulated as additional sets. Corrections can remove a
previous-performance reference, including correction to skipped, without changing
the completed prescription snapshot. New reads after SQLite reopening rebuild
the same view offline. Conflicted source workouts are labelled as requiring sync
review; this presentation is not an independent certification of server state.

Owner changes invalidate asynchronous dependencies. Lock/read errors hide cached
history rather than displaying the previous successful view. Existing account
containers, sign-out locks and authoritative erasure retain their responsibilities;
presentation caches do not authorize access.

## Verification and limits

Relevant executable coverage lives in `exercise_history_test.dart`,
`exercise_history_provider_test.dart`, `exercise_progress_test.dart`, the existing
multi-exercise tests and the connected HTTP acceptance test. Run these from
`apps/mobile` with the pinned SDK using `flutter test`, followed by the full
[testing matrix](TESTING.md). Connected acceptance requires the documented
disposable PostgreSQL/HTTP harness and its unchanged exact nine-case parser.

Desktop widget tests do not qualify physical-device accessibility, durability,
native storage, hosted providers or production recovery. No remote routine sync,
new exercise catalog semantics, O3 G1/B4/B5 implementation or D1–D11 approval is
provided. Advanced charting and measured cross-unit conversions require separate
scope and evidence.
