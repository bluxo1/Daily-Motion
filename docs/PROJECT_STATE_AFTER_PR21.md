# Project state after PR21

Audit baseline: `852eedf04de74110c6cf001699094c4c16f00fc1`, tree
`0e3c5831f92c9cab778d9f75cfff7b5dada97770` (2026-11-02 IST).
PRs [15](https://github.com/bluxo1/Daily-Motion/pull/15),
[16](https://github.com/bluxo1/Daily-Motion/pull/16),
[17](https://github.com/bluxo1/Daily-Motion/pull/17),
[18](https://github.com/bluxo1/Daily-Motion/pull/18),
[19](https://github.com/bluxo1/Daily-Motion/pull/19),
[20](https://github.com/bluxo1/Daily-Motion/pull/20) and
[21](https://github.com/bluxo1/Daily-Motion/pull/21) are merged.

The old checklist understates implemented code. The repository is also not a
publicly usable MVP. Neither observation closes Phase 0 or authorizes release.
[Requirement matrix](MVP_COMPLETION_MATRIX.md), [execution plan](MVP_EXECUTION_PLAN.md)
and [release gates](MVP_RELEASE_READINESS.md) separate those questions.

## What the source actually provides

* [AccountApplication](../apps/mobile/lib/auth/auth_app.dart),
  [AccountController](../apps/mobile/lib/auth/account_controller.dart) and
  [SupabaseOtpProvider](../apps/mobile/lib/auth/supabase_provider.dart) implement
  OTP, secure-session adapters, cached verified ownership, expiry continuity and
  locked sign-out/account switching. There is no units/focus onboarding screen.
  [Account initialization](../services/api/src/daily_motion/accounts.py) creates a
  profile with `unit=kg`; that default is not user-selected onboarding.
* [RoutinePlan](../apps/mobile/lib/domain/routine.dart), the
  [repository](../apps/mobile/lib/data/routine_repository.dart) and
  [editor](../apps/mobile/lib/features/routine_screen.dart) author durable ordered
  routines with planned sets/rest/class/purpose, immutable versions and editor CAS.
  The [catalog](../apps/mobile/lib/domain/exercise_catalog.dart) and
  [picker](../apps/mobile/lib/features/exercise_catalog_screen.dart) preserve stable
  variants, fork material definitions and keep private definitions owner-local.
* [WorkoutScreen](../apps/mobile/lib/features/workout_screen.dart) and
  [WorkoutController](../apps/mobile/lib/features/workout_controller.dart) support
  all prescribed exercise instances, deliberate prefilled set recording,
  warm-up/working and purpose labels, optional RIR/RPE, correction, resume,
  finish/abandon and restored draft/timer state. This is a fixed-prescription
  repetition/load logger, not arbitrary active-workout editing.
* [History](../apps/mobile/lib/features/workout_history.dart),
  [exercise history](../apps/mobile/lib/domain/exercise_history.dart) and
  [measured progress](../apps/mobile/lib/domain/measured_progress.dart) retain
  original units, source IDs, exact values and correction invalidation. PR19
  deliberately shipped charts without measured-record summaries. The candidate
  [first slice](FIRST_SLICE_IMPLEMENTATION_HANDOFF.md) addresses that bounded gap.
* [Foreground synchronization](../apps/mobile/lib/sync/coordinator.dart), the
  [local journal](../apps/mobile/lib/data/routine_sync_repository.dart) and
  [server domain](../services/api/src/daily_motion/routines.py) implement durable
  receipt replay, owner-scoped routine/workout feed/bootstrap, immutable history
  and preserved conflicts. Conflict inspection retains both plans; it does not
  resolve a branch. [Contract3](ROUTINE_CLOUD_SYNC.md) enrolls the entire account,
  including workout synchronization, on its first accepted routine.

## What a release-mode user can reach

[main.dart](../apps/mobile/lib/main.dart) selects production-shaped account
configuration in release and rejects synthetic configuration.
[internalRoutineAccess](../apps/mobile/lib/features/internal_routine_access.dart)
denies product/release mode even when requested. It also controls transport opt-in.
[HomeScreen](../apps/mobile/lib/features/home_screen.dart) exposes routine creation
only through that gate. The foundation Start action belongs to the synthetic
fixture; a verified release user with no existing workout has no supported
first-workout creation path. Existing restored workouts can still be resumed or
read, and History/Progress use the ordinary account scope. A successful release
build therefore does not demonstrate the required first-user product journey.

Debug and profile builds can opt in with `DM_LOCAL_ROUTINES=true`; default debug
and profile builds do not opt in. Profile is not a strict debug-only gate. No
gate is removed or public capability enabled by this audit or first slice.

## Missing or incomplete product behavior

Current [closed operation models](../services/api/src/daily_motion/contracts.py)
support create/record/correct/complete/abandon/delete workout commands, not notes,
substitutions, exercise insertion/reordering, supersets or duration/distance.
`CreateSession.exercises` requires at least one exercise. These are real source
gaps, not checklist assumptions. [Local commit](../apps/mobile/lib/data/workout_repository.dart)
expressly rejects `delete_session`; remote redaction handling and internal account
retirement are not user-facing deletion. Public export/deletion routes and a
complete conflict-resolution flow are absent. Canonical conversion/preferences,
full profile onboarding and editable duplicated-set drafts remain incomplete.

Do not solve these by adding unknown fields to frozen requests, by exposing a
backend helper as a completed privacy product, or by deleting a local branch.
Each requires its own bounded contract/product acceptance work.

## Evidence and release boundaries

PR21 reports 637 ordinary Flutter passes/27 explicit skips, 731 PostgreSQL/Python
passes and nested 9+15 connected cases. Those are historical source-bound results,
not executions of this new candidate. Main push
[41361445546](https://github.com/bluxo1/Daily-Motion/actions/runs/41361445546)
was still running at the initial audit: API passed; mobile jobs were unfinished.
The task evidence records later read-only observations and fresh local results.

[Device qualification](DEVICE_QUALIFICATION.md) and
[operator qualification](../infra/QUALIFICATION.md) retain open physical,
provider, signing, backup/erasure-restoration and privacy/support gates. Historical
hosted OTP successes are useful dated evidence, not current provider approval.
The historical Render-hook incident and signing/JWKS/sender-capacity dependencies
must be dispositioned by their operators, without assuming still-valid settings.

Core code implemented, MVP feature complete, release candidate qualified and
public launch authorized are four different states. Only scoped code/local
evidence advances in this task. Phase 0 remains open; Phase 1 public entry and
rollout remain unauthorized; Phase 2-6 and O3 expansion remain excluded.
