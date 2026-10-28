# Local routine authoring experiment

The 2026-10-27 [local catalog follow-up](LOCAL_EXERCISE_CATALOG.md) adds a searchable
picker, reusable private variants and additive schema 6. The earlier routine
design and dated qualification below remain the historical foundation; the
follow-up documents the current picker and forward-only compatibility boundary.

This exploratory implementation is local and subject to human review. Phase 0
remains in progress; it does not close a phase gate or authorize Phase 1 rollout.
The disposable [interaction prototype](../apps/mobile/lib/qualification/routine_prototype.dart)
is preserved. The persistent screen reuses its planned-value, explicit-save and
keyboard-safe interaction pattern with the existing application theme.

## Try the local slice

The screen is off by default and unavailable through the default release path.
For a synthetic local development account:

```sh
cd apps/mobile
flutter run --dart-define=DM_FOUNDATION_FIXTURE=true --dart-define=DM_LOCAL_ROUTINES=true
```

Open **My routines** from Train. Create/name a routine, add exercise definitions,
choose load/rep conventions, order exercises and edit planned sets. Save before
leaving. Open a saved routine to edit it or start a workout. The existing active
workout must be resumed, finished or abandoned before another start.

Choose **Workout timezone** explicitly before starting. This local foundation's
existing command validator supports `UTC`, `Asia/Kolkata` and `Asia/Calcutta`;
the start screen offers exactly those choices and never infers India from the
routine prescription. The server's broader IANA support is unchanged. Automatic
device/profile timezone discovery and other local timezone support are deferred;
do not treat a UTC choice as the user's local timezone or invent a numeric offset.

The same debug flag can expose the screen inside an already configured, verified
owner application. It does not bypass authentication, create a guest account or
require a working cloud token for local editing. No hosted setup is part of this
experiment. Routines are saved only on this device, as the screen states.

## Architecture and invariants

- A stable owner-scoped `routines` row points to immutable `workout_templates`
  content. Saved editor revisions are local CAS tokens, never server revisions.
  An unchanged save or exact response-loss retry does not create another version.
- Template content uses the existing `CreateSession` prescription shape and
  validators. Exercise/set IDs are template-local; every workout start creates
  separate session/exercise/set IDs while retaining exercise variant identity.
  Load decimals and units, class/purpose, ordering and optional targets survive
  reopening. Back-off prescriptions require working class.
- Changes to exercise definitions in the editor create a new variant identity;
  editing targets alone retains it. A later routine edit does not rewrite an
  active or completed session, its observations, pending commands or frozen body.
- The start binds a caller-retained attempt UUID to routine, template, timezone
  and session in the same transaction as the existing session/outbox command.
  Exact retries reuse that result, including after completion and routine edits.
  A removed session cannot be recreated by replaying its old start identity.
  Routine/template/start identities require canonical lowercase UUID spelling,
  matching the existing workout contract; alternate spellings cannot create aliases.
- All reads/writes use the existing local-owner lock/disable guard. Composite
  owner-aware keys bind roots, templates and start records. Sign-out retains and
  locks plans; authoritative account disable erases their private payloads too.
- Only workout commands enter the accepted synchronization protocol. Routine
  edits do not invent a wire aggregate, upload path, provider or server receipt.
  Started sessions remain self-contained and use the existing outbox/recovery.

## Migration and rollback boundary

Drift schema 5 adds three local planning tables and the owner uniqueness index
needed by their foreign keys. Existing workout/outbox/recovery columns and wire
contracts are unchanged. The DDL and version update are one transaction. Tests
use the exact main schema-4 SQL, preserve a pre-existing frozen workout command,
inject a late DDL failure, reopen files and run the earlier schema 1–3 regressions.

The UI flag does **not** suppress database migration. A schema-4 application
correctly refuses a schema-5 file. Turning the UI flag off is a feature rollback;
it is not a database downgrade. Keep a compatible schema-5 reader or obtain a
separately reviewed recovery procedure. Do not delete tables, reset owner stores
or restore over pending work to roll this experiment back.

The follow-up compatibility harness uses the exact baseline schema-4 Dart reader,
generated database and SQL from `e3104b5`. It checks a genuine schema-4 file first,
upgrades a separate owned file with pending workout data, then attempts to open
schema 5 with that unchanged reader. It compares all persistent rows, schema and
version and reopens with current code. Commands and results are retained in the
separate task-owned `routine-review-20261024` evidence; old receipts are unchanged.

## Interrupted routine starts

Repository idempotency requires the caller to retain the same attempt UUID and
request binding. The screen retains that binding only while its state lives;
recreating the screen or app loses its in-memory attempt map and timezone choice.
It does not automatically replay the old attempt after restart.

If a start committed before the screen was interrupted, the session and outbox
survive reopening. The existing active-workout guard prevents another start;
**Resume workout** from Train opens that session. If the transaction did not
commit, a new attempt can start normally. A focused file-backed widget control
destroys the screen after commit but before refresh/navigation returns, reopens
SQLite and resumes the single retained active workout. This is not a physical
process-kill or backup-rewind guarantee for the screen's attempt identity. After
that session is completed or abandoned, a fresh screen can intentionally start
another session; repository receipts do not infer that it was the old UI intent.

## Validation and remaining scope

Repository tests exercise the production background SQLite factory. Widget tests
also close/reopen real SQLite files; they use a synchronous executor for widget
scheduling. Hard-kill workers exercise WAL/FULL before, during and after edit and
start transactions. SQLite pager quotas and failed-write triggers test rollback.
These are desktop fault controls, not physical-device durability qualification.

The first connected acceptance case starts from a saved routine through real
Flutter HTTP/PostgreSQL and restores its unchanged prescription on another
device after later routine edits. All nine connected case names and the accepted
PR #13 report parser remain unchanged. Routine content itself is not transferred.
Raw dated commands/results, failures, hashes and the review patch belong in the
task-owned `OVERNIGHT_HANDOFF.md`; historical Phase 0 receipts are not rewritten.

Not implemented: routine cloud sync/backup/conflict resolution, routine export,
archive/delete UI, a curated catalog/custom catalog synchronization, supersets,
rep ranges, effort targets, duration/distance or source IDs in the wire contract.
The current foundation supports a single rep target, optional load and rest.
Unsaved routine forms remain in memory; only an acknowledged Save is durable.
Existing persistent workout-entry drafts are unchanged. Screen-reader/hardware,
phone performance, native protection and hosted/provider qualification remain
open. O3 G0 and D1–D11 remain unapproved; G1/B4/B5 implementation is unchanged.
