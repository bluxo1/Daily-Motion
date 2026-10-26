# Source-backed measured progress charts

This local implementation extends [exercise history](LOCAL_EXERCISE_HISTORY.md).
Phase 0 remains in progress; this feature does not establish provider, hardware,
recovery or public-release qualification. See [Phase 0 evidence](PHASE0_EVIDENCE.md).

## Using the view

Open Progress, find a recorded exercise, open its history and choose **Measured
charts**. Choose recorded load or performed repetitions. Load observations use
separate kg and lb selections with no conversion. Bodyweight-only exercises offer
repetitions without manufacturing external load. Assistance is labelled as
assistance, without a strength or improvement claim.

The scatter plot shows a maximum of 80 observations at once, initially the most
recent observations. Older/Newer observations navigation retains access to the
rest. Each window is chronological. The visible observation range is explicit;
axis ranges describe that window, not the full historical range. No line connects
sets, and there is no smoothing, interpolation, prediction, ranking or estimated
strength. One set is one observed point. Distinct sets can overlap exactly.

Every plotted point has an **Exact observations** source row with the original
decimal/unit, repetitions, convention, workout name/start instant, exercise
instance and set ordinal. Activate the row to open its source workout. The chart
is not the only representation: these text rows are keyboard navigable and have
screen-reader action labels. Axis labels can ellipsize at large text sizes; source
rows retain the exact values. A finite floating-point coordinate is used only for
painting; it is never saved back into an observation.

**Source history** remains available beside the chart, including abandoned
workouts, warm-ups, partial/failed/skipped observations, unperformed plans,
historical names, conflict markers, completed-only/unit filters and pagination.
These source filters are independent of the chart's stricter eligibility rules.

## Measurement and provenance rules

The existing `ExerciseKey` separates stable variant UUID, loading basis,
repetition convention and recorded side. Display names never identify a series.
The current projection supplies no independent machine setup or physical technique
identity; this view does not infer one from names or claim equivalence between
unrecorded setups. See the [data model](DATA_MODEL.md).

Only effective **completed working-set observations in completed workouts** are
plotted. Active/abandoned workouts, warm-ups, partial/failed/skipped observations,
unperformed prescriptions and superseded values are excluded. Missing load is
unknown, not zero; genuine recorded zero remains a point. Per-implement loads
are not doubled. Repetition conventions and sides are not combined or doubled.
Repetition rows include their actual load context: more reps at a different load
do not imply a strength record. Unsupported numeric measurements are omitted
with a notice; their source history stays inspectable.

Each detached point retains comparison identity, workout/exercise/set IDs,
workout start instant, exact actual values, eligibility fields, correction reason
and source conflict marker. Ordering uses workout start in UTC, stable workout
ID for equal instants, then prescription exercise/set order. That tie order is
deterministic presentation, **not a claim of physical set execution time**.
Correction time and completion sequence do not become workout dates.

## Refresh, isolation and storage

The chart derives from the same owner-scoped effective projection and shared
exercise-history provider as the source view. It does not read outbox events,
introduce a repository, persist derived tables or change schema v5, API or
synchronization semantics. Large selected histories are transformed in a worker
isolate; only a bounded window and lazy source rows are rendered.

An existing historical correction rebuilds the derived measurements. A unit
change moves the observation to that unit's series; a completed-to-skipped
correction removes eligibility. A removed selection gets an explicit fallback,
and reduced page counts clamp safely. Choices survive ordinary projection
refreshes while loading/error states hide old values. A local read error provides
a retry that refreshes the underlying workout projection, without exposing raw
storage errors or recording commands.

The existing workout controller rejects an older in-flight refresh result after
a newer refresh starts. This prevents a read sampled before a correction or lock
from replacing the newer effective value or access error. The command queue and
repository transactions are unchanged; this is presentation-read ordering, not a
new server revision or synchronization rule.

Account lock, sign-out, owner replacement and authoritative disable retain the
existing repository/account guards. The visible exercise route also observes
account status so disable can finish while Home is offstage. No authentication,
deletion or synchronization authority is changed. Offline cached history remains
available to the established owner, including after file-backed SQLite reopening;
this is not cloud backup or provider qualification.

## Validation scope

Deterministic read-model controls cover comparability, eligibility, numeric
boundaries, original units, chronology, repeated instances and bounded windows.
Production repository/widget paths cover historical load/unit/repetition/skipped
corrections, pagination clamping, explicit unit fallback, SQLite close/reopen,
source-workout navigation, active drafts/rest timers, storage retry and large
history. Controlled verified-account fixtures cover offline token expiry,
sign-out, same-variant owner replacement and authoritative disable. Layout and
keyboard/semantics controls cover light/dark themes at 320 logical pixels and
200% text. See [testing](TESTING.md) for the wider qualification boundary.

Execution counts and raw reports belong to the task's additive local evidence,
not rewritten historical receipts. Desktop tests do not qualify physical-device
accessibility, latency, native durability, real inboxes or hosted providers.
