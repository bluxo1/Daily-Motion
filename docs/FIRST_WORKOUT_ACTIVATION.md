# First-workout activation in internal builds

Status: local implementation for independent review. Phase 0 remains in progress;
this does not authorize Phase 1 rollout or a public release.

The verified-owner [account application](../apps/mobile/lib/auth/auth_app.dart)
continues to open Train with synthetic training disabled. In a non-release build
with `--dart-define=DM_LOCAL_ROUTINES=true`, Train exposes the existing persistent
[routine authoring flow](LOCAL_ROUTINE_AUTHORING.md) directly:

1. An empty account sees **Create routine** and an explanation of recording sets
   and finding History and Progress. There are no demo observations or statistics.
2. Saved routines show their actual names and planned exercise/set counts. Creating
   and editing a plan does not record performed work or send a routine command.
3. Select a supported workout timezone explicitly before **Start workout**. The
   routine plan's internal timezone placeholder is not a detected user timezone.
4. The existing owner-scoped `startRoutine` transaction creates the session snapshot,
   outbox command and retry receipt. It remains the single authoritative write path.
5. **Resume workout** takes priority whenever a locally active workout exists.
   Another start is disabled while a start/read/navigation is pending or an active
   workout is known; the repository retains its independent single-active guard.
6. Log actual sets across exercises and finish using the existing workout screen.
   Finish returns to Train, including when starting through **My routines**. History
   opens the saved workout; Progress reads its actual exercise observations through
   the [existing history index](LOCAL_EXERCISE_HISTORY.md).

Routines remain only on this device: they are not backed up or cloud synchronized.
The separate **Workouts** status refers to workout synchronization, not routine
backup. A successful local start does not mean an upload occurred. Cached local
training remains available after cloud-token expiry; sign-out still locks the
owner store and authoritative account disable still purges it.

## Interrupted navigation and local failures

The Train host retains an in-memory pending-start guard across tab/list navigation.
An acknowledged start refreshes that same owner's workout projection even if the
routine controls have unmounted. Leaving a tab or dismissing routine management
while SQLite is busy does not cause a late callback to pop a different route or
force the workout screen open. The user can Resume the committed session.

A failure to read after an acknowledged commit says the workout was saved on this
device and offers retry/open recovery. It does not report that the write failed.
Read errors reveal no raw storage details. Existing unsaved-editor confirmation,
explicit timezone choice, stable start attempts, immutable session prescriptions,
drafts, correction and completion rules remain in use.

Pending UI guards and attempt IDs are not a new persistent intent system. After
app/screen destruction, the authoritative active session and receipt survive in
SQLite; recovery is through Resume, not replay of a new screen's start. Unsaved
routine edits remain in memory until Save is acknowledged.

## Verification and boundaries

`apps/mobile/test/train_activation_test.dart` exercises the actual
`AccountApplication` route with controlled verified-owner/provider fixtures and
real per-owner SQLite files. Run its internal acceptance variant with:

```sh
flutter test test/train_activation_test.dart --dart-define=DM_LOCAL_ROUTINES=true
```

The ordinary suite tests the default unavailable feature path. A separate
product-VM probe exercises the exact production internal-access guard with an
explicit true request: a release VM still denies access. The constructor retains
`!kReleaseMode && DM_LOCAL_ROUTINES`; the guard also rejects a release-mode widget
request. This is a code boundary check, not mobile release qualification.

Tests cover the three-exercise create/log/finish/history/progress path, reopening,
rapid starts/resume, queued starts during navigation, failed writes, post-commit
read failure, offline expired-token access, owner switching, sign-out, authoritative
disable, unsaved edits, storage retry and 320-pixel/200% text semantics. File-backed
widget fixtures use a synchronous SQLite executor; existing production background
factory, migration, recovery and real HTTP/PostgreSQL tests remain separate.

No schema, public API, synchronization protocol, authentication security, cloud
routine semantics or provider configuration changes are introduced. No empty
workout/dynamic-add commands are added. Hardware, native screen-reader usability,
hosted-provider and release qualification remain open. O3 G1/B4/B5 remain
unauthorized and D1–D11 remain proposed.
