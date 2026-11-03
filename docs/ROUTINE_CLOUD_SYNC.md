# Internally gated routine synchronization

Status: merged in PR21 at `852eedf04de74110c6cf001699094c4c16f00fc1`.
The [post-merge audit](PROJECT_STATE_AFTER_PR21.md) and
[proposed admission design](MVP_RELEASE_READINESS.md#controlled-routine-admission-design-proposed)
describe remaining production policy and qualification. Phase 0 remains open. This
does not enable public builds, approve O3 recovery, qualify a hosted provider or
establish phone durability, performance or accessibility.

The existing foreground coordinator can synchronize reusable routine definitions
when the internal `!kReleaseMode && DM_LOCAL_ROUTINES` gate is enabled. A local
Save commits the working plan, immutable template and pending publication in one
SQLite transaction. HTTP delivery runs separately. Started workouts continue to
use their self-contained prescription snapshots and original frozen operations.

## Contract and compatibility

Routine-capable clients use `X-DM-Contract: 3` with `/v3/me`, `/v3/sync/push`,
`/v3/sync/pull`, `/v3/sync/bootstrap`, `/v3/sync/bootstrap/pages/{page}` and
`/v3/sync/bootstrap/validate`. Contract 2 remains reserved for the separate,
unfinished recovery protocol. Account initialization remains the existing
verified `POST /v1/account/initialize` with a closed empty request.

The contract-3 push envelope accepts a discriminated union of the unchanged
workout operation and a distinct routine operation. Routine commands are
`create_routine` (first template published atomically) and `publish_template`.
Each command names a stable routine UUID, new immutable template UUID, expected
server revision and predecessor template UUID. The server derives ownership
from verified authentication. Event timestamps never decide edit precedence.

Routine-specific validation matches the pinned native reader: names use Dart's
whitespace rules, planning UUIDs must be readable by its UUID implementation,
and set class, purpose and rest targets are explicit. Optional prescription
omissions stay omitted. Both future workout-start and routine-publication
envelopes reserve worst-case command capacity before accepting a template.
These checks do not alter historical workout schemas or frozen command bytes.

The first accepted routine raises that owner's minimum sync contract to 3 in
the same transaction as revision, receipt and feed publication. Contract-1 sync
then refuses with `upgrade_required`; it cannot filter routine events and advance
the cursor. A restrictive owner-state RLS policy also denies older API binaries
that cannot set the trusted server contract context. An unknown response type or
version fails validation before installation. New clients contacting a server
without `/v3` retain pending work and report capability unavailable.

An additional restrictive retirement-insert policy prevents an older runtime
from mistaking its hidden upgraded owner row for an absent account and recording
a retirement marker while leaving that account active. Such a transaction fails
atomically. The original workout-only owner's retirement behavior is preserved.

Disabling the internal feature leaves local plans and their journal intact.
It does not downgrade the owner, rewrite frozen requests or label pending plans
as synchronized. An upgraded owner needs a compatible client to synchronize
workouts as well. This explicit account compatibility boundary prevents older
clients from claiming a complete backup after discarding planning content.

## Persistence and revisions

PostgreSQL migration `0005_routines` adds owner-scoped `routines` and
`routine_templates`. Each immutable template has its accepted revision,
predecessor and complete prescription. Composite owner keys bind the current
head and predecessor, with a deferred current-head foreign key for atomic first
publication. An immutable-content trigger rejects updates. Forced RLS and the
restricted runtime role apply to both tables. The existing owner lock, receipts,
change positions and feed transaction are reused. Replaying an identical
mutation returns its established receipt; changing its body is rejected. An old
successful receipt does not state that its template remains current.

SQLite schema 7 adds `routine_sync_state`, `routine_mutations` and
`routine_cloud_templates`. Local editor CAS, pending sequence and accepted server
revision remain distinct. The accepted shadow contains the immutable cloud
history; pending editor templates are never replaced by a remote alternative.
Only a clean adopted current template enters the local editor revision namespace.
Existing schema-6 templates enroll without changing their UUIDs, prescriptions,
local revisions, workouts or frozen outbox bytes. Enrollment time records the
publication intent, not a guessed original authoring time.

Both migrations are additive. The SQLite DDL, enrollment and version change
commit together. A schema-6 reader refuses a schema-7 file. Turning off a feature
flag is not a database downgrade. Keep a compatible reader; do not rebuild owner
databases, restore over pending changes or delete immutable history. PostgreSQL
downgrade is deliberately refused rather than destructively dropping private
planning data.

## Delivery, conflicts and bootstrap

Frozen requests retain their mutation IDs and bytes through retry and restart.
Acknowledgement, shadow and immutable-cache changes commit together. A matching
feed echo can reconcile a lost response. A historical acknowledgement must match
the publication in any already installed authoritative lineage; it cannot move
the shadow backward or substitute another template.

Stale expected revisions produce durable conflicts, retaining both the saved
working plan and remote shadow. Only that routine's pending descendants stop.
Independent workout roots continue through the same coordinator. There is no
automatic overwrite, merge, rebase or conflict-resolution command.

Contract-3 bootstrap includes workout roots and routine history fragments.
Offsets, revision continuity, predecessor chain, immutable content, owner,
generation, erasure epoch, bounds and page checksums are validated before one
activation transaction. Root/template UUIDs cannot alias workout or retired
identities. A snapshot downloaded before a newer pull cannot rewind its cursor.
When a push acknowledgement is ahead of the pull cursor, an older snapshot root
must still match the accepted immutable history prefix before activation can
continue. Keeping a newer shadow does not permit ignoring contradictory history.
Activation rereads local pending work. A missing previously accepted routine or
changed-generation branch is retained for attention, not silently deleted or
replayed using revision-order assumptions. Existing recovery authority fences
remain in force; ordinary routine transport supplies no recovery provenance.

## Catalog boundary and user status

A routine transfers prescription fields and stable variant UUIDs. It does not
transfer owner-private catalog definitions, setup metadata or provenance. On a
second device an unavailable definition remains snapshot-only. Its name and
measurement semantics are read-only; safe target edits and workout starts use
the retained prescription. No name match, substitute or new catalog UUID is
invented. Performed observations come only from recorded workout sets.

The routine screen distinguishes local save, pending delivery, synchronization,
authoritative acknowledgement, attention, sign-in requirement, capability
unavailability and conflict. Conflict review displays both retained plans without
resolving them. An account-feed validation error also prevents an acknowledged
routine from displaying an unqualified synchronized status. Account replacement
hides stale private reads. Sign-out locks
the owner file; authoritative disable purges local planning payloads. Internal
server retirement erases routine roots/templates and routine-bearing snapshot
copies and redacts planning feed payloads. These primitives are not a completed
public account-deletion product.

The HTTP transport admits the destructive account-disable transition only for
HTTP 403 with integer error schema version 1 and the matching local owner.
An inactive-account label on another status or malformed schema cannot authorize
local erasure. Valid owner-bound denials continue to lock and purge the file.

## Verification boundaries

`routine_sync_repository_test.dart` uses real file-backed SQLite with exact
transaction faults and restart checks. `routine_journal_test.dart` upgrades a
byte-frozen schema-6 layout with historical plans, active/completed workouts,
custom definitions and pending state, including rollback at each new table's
DDL. `routine_sync_widget_test.dart` exercises factual status, owner replacement,
conflict review, keyboard focus, 320 logical pixels and 200% text in both themes.
`routine_transport_test.dart` supplies deliberately invalid HTTP responses to
verify capability refusal and cursor/outbox retention. It is a negative wire
control; successful cloud behavior is demonstrated by the real connected suite.

The existing process-kill harness additionally checks routine journal state and
terminates actual Dart workers before, during and after request freezing. Frozen
mutation identity, request bytes and digest survive without graceful disposal.
The connected UI case uses Flutter's live test binding and real HTTP/event loop
to navigate received History, measured charts and source workouts. Automated
fake-clock widgets remain separate layout/ownership controls; neither mode
qualifies physical devices.

`routine_connected_http_test.dart` uses independent SQLite files/installation
identities, the production coordinator/repository/HTTP transport, FastAPI,
verified synthetic JWTs and disposable PostgreSQL. Its separate strict report
parser requires every named routine case; the established nine connected names
and parser remain unchanged. Synthetic provider identity does not qualify email
delivery, hosted service operation or native-device behavior. Exact dated raw
outputs, failures and source hashes belong in the task-owned evidence package;
passing focused cases do not replace the final complete regression matrix.

The hardening controls additionally permute local edits, acknowledgements, pulls
and bootstrap activation on reopened files. Older external echoes must match the
accepted immutable history before the cursor can advance. Contract-3 workout
retirement rejects identifiers belonging to retained routine roots or templates;
a valid workout retirement still leaves planning content available. An unavailable
private definition stays snapshot-only after a missing-cloud-root attention state,
using retained immutable history to identify its origin.

Cloud interruption status takes precedence over an earlier acknowledgement:
update requirements, unavailable capability, recovery attention and temporary
service failures remain visible while local editing continues. SQLite migration
tests terminate actual Dart workers before, during and after the schema-7
transaction. These desktop process-kill controls do not qualify phone power loss.
