# Local exercise catalog and routine picker

Status: internal local implementation for independent review. Phase 0 remains
in progress; this does not authorize Phase 1 rollout or public release.

The existing verified-owner [routine flow](LOCAL_ROUTINE_AUTHORING.md) remains
behind `!kReleaseMode && DM_LOCAL_ROUTINES`. **Add exercise** now opens a searchable
catalog. Search names/setup notes, filter equipment, movement category or source,
review the load/repetition/side labels, and choose an active definition. Configure
planned sets in the existing editor. Nothing becomes performed work until the
normal workout logger records it. Train, timezone choice, Resume, drafts, timers,
finish, [History](LOCAL_WORKOUT_HISTORY.md) and [measured charts](MEASURED_PROGRESS_CHARTS.md)
retain their existing repository paths.

## Identity and snapshots

The typed [catalog model](../apps/mobile/lib/domain/exercise_catalog.dart)
distinguishes movement UUID, variant UUID, definition revision, display name,
equipment/setup, category, loading basis, repetition convention, optional side,
provenance and archived state. The existing `ExerciseKey` is unchanged: stable
variant UUID plus loading basis, rep convention and recorded side. A movement
relationship or matching name does not establish comparable performance.

The 16 bundled variants have explicitly assigned, permanent UUIDs. Selecting the
same variant repeatedly or in another routine preserves that UUID and allocates
new template-instance/set UUIDs. Each workout start still allocates independent
session children. A display rename appends a custom definition revision while
preserving its variant; it never rewrites existing templates or session snapshots.
Changing equipment, setup, category or measurement semantics requires **Create
separate variant**, which assigns a new UUID once for that editor attempt. A
shared movement ID does not combine those distinct variants in Progress.

Only existing CreateSession fields are copied into the prescription: variant ID,
name, loading/repetition/side and planned sets. No catalog field is added to the
wire contract. Catalog revision/provenance/setup metadata stays local; workouts
remain self-contained with the snapshot fields their established contract supports.
They do not acquire a new cloud catalog lookup or historical catalog-revision proof.
New catalog prescriptions encode an unknown/optional side as explicit
`unspecified`, preventing the existing server default for an omitted side (`both`)
from changing that selection's comparison key after synchronization. Existing
manual plans and their original payload representation are not normalized.

Previously authored manual definitions remain readable with their original IDs,
names and conventions. They are not matched to curated entries by name. Existing
unknown manual definitions retain their explicit legacy editing behavior; changing
their definition creates another variant. Editing only targets preserves identity,
including an originally omitted/unspecified side. Known catalog definitions render
their saved snapshot metadata read-only in the routine editor; reselect a definition
to use a newer name in a future plan. If the catalog read fails, the editor keeps
all definition fields read-only until the owner-scoped catalog can be verified.
The visible **Retry exercise catalog** action requests a fresh guarded read;
it never guesses legacy identity from a name. There is no automatic migration of names.

## First-party catalog provenance

All bundled labels and category assignments were authored for Daily Motion on
2026-10-27. No third-party descriptions, instructions, images or video were scraped,
copied or downloaded. No external content license or attribution is required by
these entries. This does not assign a new repository redistribution license or
qualify public-release rights. No muscle percentages, technique instruction,
physiological equivalence or performance recommendation is supplied.

The bounded first set includes barbell/dumbbell bench press, back/goblet squat,
barbell deadlift, barbell/dumbbell Romanian deadlift, barbell/dumbbell overhead
press, barbell/single-arm dumbbell row, pull-up, weighted pull-up, push-up,
alternating dumbbell curl and standing dumbbell calf raise. Original load and
rep conventions are explicit. Machines/cables and a particular physical setup can
be named as private variants; the picker does not infer equipment from a label.
Detailed machine equivalence and unsupported duration/distance authoring are not
introduced. Equipment tags describe a definition, not a measured physiological
property or proof that two physical setups are identical.

## Private custom definitions

Create a custom definition without entering a UUID. Choose supported conventions,
equipment/category and an optional setup note. Save it to make it reusable in
the picker. Display rename and archive/restore append revisions. Archive removes
the definition from normal selection; it does not erase its revisions, previously
saved plans or historical workouts. Existing plans remain startable from their
own immutable content. Account disable retains the existing authoritative erasure
policy and removes all private definition revisions in the same purge transaction.

The [existing WorkoutRepository](../apps/mobile/lib/data/catalog_repository.dart)
provides guarded local queries and CAS saves. An exact response-loss retry succeeds only while its committed revision is
the latest head. Once another editor has committed a newer revision, the older
request fails its CAS check and the user must reopen/review. An old successful
revision is never presented as the current head. This preserves collision
visibility, though it is not an unbounded historical idempotency receipt.
The screen retains attempt identities and unsaved input in memory. Failed writes retain editable fields and provide sanitized retry.
An acknowledged definition survives SQLite reopening; unsaved forms do not become
durable drafts. Recreating an unsaved editor does not recover its prior intent.

Every custom query/write uses the existing database owner/lock/disable guard and
an explicit owner predicate. Another owner cannot read or edit it; sign-out locks
and retains it. Owner replacement/disable hides private picker/form content.
Cached verified-owner use needs no network or fresh cloud token.

Reusable definitions and routines are local-only: no catalog/routine sync or
backup is implemented. A started workout intentionally copies its supported
definition fields into the existing owner-private workout snapshot, which follows
normal workout synchronization. This is not a new cloud catalog write path.

## Schema 6 and rollback boundary

Schema 6 adds exactly one table, `custom_exercise_definitions`, with owner FK to
`local_identity(owner_id)`, variant UUID, positive definition revision and canonical
definition JSON. The owner/variant/revision primary key also indexes current-head
reads. No old column, command, migration on PostgreSQL or public contract changes.
App writes append immutable rows; there is no persisted derived history store.

The existing Drift migration transaction includes new DDL and `user_version`.
Tests use the byte-frozen protected-main schema-5 SQL, preserve every old row,
pending frozen outbox bytes, routine/template, draft, timer and active session,
and inject interruption both at DDL and after successful DDL before version commit.
Those failed migrations roll back the new table/version and permit safe retry.
Earlier supported-schema regression controls remain in the full suite.

Migration runs even with the UI feature disabled. Once schema 6 commits, an old
schema-5 application must refuse the file. Schema-6-compatible application code
is the minimum permitted reader for that upgraded database; a release/rollback
plan must not downgrade its reader to schema 5. The standalone compatibility harness
uses the exact protected-main Dart reader/generated SQL, checks v5 first, then
verifies refusal of v6 without changing pending data, tables or version. Disabling
the feature is not a database downgrade. Keep a compatible reader; do not delete
tables, reset a store or restore over pending work as a rollback shortcut.

## Validation and limits

The new catalog domain, repository, migration, picker and account tests exercise
real SQLite files, owner switching, CAS/retry, private erasure, offline cached
access and the actual verified-account route. The internal account variant runs
with `--dart-define=DM_LOCAL_ROUTINES=true`; the ordinary suite also checks the
default unavailable feature path. Keyboard navigation, focus restoration and
320-pixel/200% text with light/dark themes are desktop widget controls.

The existing nine-case connected HTTP/PostgreSQL harness retains all original
case names, parser and assertions. Its first case adds a separate catalog-based
workout after the existing corrected-skipped-only and multi-exercise scenarios.
It verifies curated/private UUIDs and effective corrected measurements after
real workout synchronization while reusable private definitions stay local.

Exact execution counts, failures, limitations, raw logs and source hashes belong
in this task's ignored `IMPLEMENTATION_HANDOFF.md`, not older historical receipts.
Desktop/fault/CI results do not qualify physical durability, native screen readers,
hosted providers, real inboxes, phone performance or public release. No provider,
authentication, recovery protocol or O3 implementation changes are included.
O3 D1–D11 remain unapproved, G1/B4/B5 unauthorized, and Phase 0 remains open.
