# MVP execution plan after PR21

Baseline, evidence and mode distinctions: [project state](PROJECT_STATE_AFTER_PR21.md)
and [18-requirement matrix](MVP_COMPLETION_MATRIX.md). Numbers below are proposed
review groupings, not created GitHub PRs. No commit/publication is authorized.

## Immediate selection and decision queue

P0 launch blockers are public first-workout availability, contract3 enrollment,
privacy/erasure recovery, physical qualification and provider/operator acceptance.
Their urgency does not authorize silently resolving their product/trust decisions.
New active-workout editing also requires a compatible command/projection extension.
Local deletion is expressly disabled and cannot safely become a button-only change.

The first independently safe candidate, proposed **PR22**, implements PRD15 measured
records from the existing corrected local projection. [Handoff](FIRST_SLICE_IMPLEMENTATION_HANDOFF.md)
defines its exact scope. It needs no schema/API/rollout decision, makes Progress
more useful and leaves the public routine gate intact. It does not complete MVP.

Before public admission, the owner must accept an all-device upgrade policy,
cohort/admission ownership, release rollback boundaries and explicit resolution
of already-conflicted or missing private definitions. Before privacy rollout,
approve recent-auth, request/retention/support scope and erasure-safe restoration.
No O3 decision or implementation is approved by this plan.

## Reviewable PR sequence

| Group / user outcome | Likely files/modules | Schema/API impact | Preconditions and security | Migration / rollback | Test/evidence and acceptance |
| --- | --- | --- | --- | --- | --- |
| PR22, current candidate: measured load and fixed-load rep records | `domain/measured_progress.dart`, new records view, existing chart entry, targeted tests and current audit docs | None; derived only | Existing ExerciseKey/eligible observations; never rank assistance or compare rounded painting coordinates | None; remove view/derivation without rewriting history | Exact-decimal ties/units/zero/assistance/bodyweight/eligibility; corrections/deletion/owner changes; page bounds and source links; full local gates; no performance estimate |
| PR23: minimal owner onboarding/preferences | `auth/auth_app.dart`, account controller, profile repository/UI, `accounts.py`, profile models/contracts and tests | Additive profile/preferences revision and bounded update/read API; local owner-scoped persistence | Confirm focus choices, default/skip behavior and multi-device preference conflict policy; verified owner only, no medical fields or retagging | Additive only; preserve prior original-unit observations/drafts. Keep compatible reader; UI off is not schema rollback | File-backed restart/expiry/account switch, RLS/CAS, units/focus editing, first-run retry,320px/200%, actual account routes. A verified user can explicitly choose units/focus without rewriting history |
| PR24: controlled routine admission and compatible transport | `internal_routine_access.dart`, `main.dart`, capabilities/transport, API owner guard/admission, migration/models, rollout docs/tests | Versioned admission policy1 independent of transport3; optional additive owner admission records/capability endpoint | Human acceptance of cohort, consent/upgrade notice, grandfathering and minimum readers; see [design](MVP_RELEASE_READINESS.md#controlled-routine-admission-design-proposed) | Preserve enrolled floor3 owners and frozen bodies. Pause new enrollment without downgrading owner/schema or shutting down compatible reads/receipts | Current v1/v3 replay plus missing/forged/stale admission, revocation/lost reply, mixed clients and old server; release-mode negative controls. No public activation in implementation PR |
| PR25: explicit conflict resolution | routine/workout conflict views, journal/repository/coordinator, bounded server commands if needed | Explicit new commands/IDs; version/capability impact must be reviewed | Approve Keep local/Use server/Copy behavior, preserving frozen original branches; no O3 restored-generation ancestry inference | Old branch remains inspectable until explicit reviewed resolution; no frozen-request rewrite or automatic rebase | Two devices diverge, third edit races confirmation, lost acknowledgement, restart and separate workout progress; no pending edit silently disappears; source snapshots remain intact |
| PR26: true empty workout and active exercise editing | workout domain/repository/controller/screen, catalog picker, backend command/projection DTOs, fixtures/generators | Add compatible zero-exercise start plus add/reorder/skip/substitution commands; explicit next transport capability for old readers | Review old-client refusal/pull semantics before extending closed v1/v3 command sets; template intent and performed instances remain separate | Additive lineage/order fields; no guessed legacy meaning. Existing frozen requests remain byte-identical | Empty continue/abandon/discard; add/reorder/repeated variants, completed-set preservation, substitution versus separate routine-change confirmation, stale UI/device CAS, real two-device tests |
| Privacy PR: export and deletion request journey | privacy UI, local export adapter/repository, recent-auth API/jobs, erasure ledger/operator documentation | Bounded owner-scoped exports/deletion requests; additive job/status interfaces | Approve scope including local-only custom/planning data, recent auth, retention, cancellation/support and restoration suppression | No destructive migration. Never overwrite pending stores; final erasure overrides retention only on proper authority | Cross-owner and stale-token denial, export completeness, offline pending scope, in-flight disable/delete, snapshot/backup restore after erasure, hardware share/temp cleanup and operator-approved drill |
| Measurements PR: basic holds/carries | typed measurement domain, SetEditor, validators/DTOs/projections, catalog and history | Explicit duration/distance fields/kind and compatible command contract | Confirm base units/input semantics; no fake reps/load, no prediction/cardio scope | Preserve repetition history and unknown fields as unknown; compatible readers required | Duration-only/distance-only/combined permitted shapes, actual zero/unknown rules, corrections, unsupported-reader refusal, migrated file and connected journey |
| Grouping/notes PRs, kept separate when review size warrants | routine/session editors, grouping/note domain, snapshot/history DTOs | Explicit ordered memberships; bounded private notes; compatibility design first | Simple supersets only; no inferred rest, physiological claims or AI processing of notes | Preserve old ungrouped order and old snapshots; no implicit pairing of neighbors | Repeated exercises, traversal/delayed logging, immutable templates, substitutions, notes privacy/size/error checks, source-level and connected parity |
| Entry UX PR: editable duplication/undo | SetEditor, drafts/controller and explicit correction/undo domain | Draft-only duplication may need none; undo-to-pending requires reviewed command semantics | Never turn copied targets/effort into performed work; confirm undo retention/lifecycle | Preserve old observations and frozen bytes; no destructive row reset | Restarted draft remains uncompleted, repeated taps, write failures, correction/undo after completion, owner replacement and timer unaffected |

**The exact next three implementation PRs after this candidate are PR23 profile
onboarding, PR24 admission/capability control, and PR25 conflict resolution.**
Each has the explicit preconditions above; a blocked decision does not prevent
independent test or design preparation. Privacy decisions and infrastructure/device
qualification run in parallel and are P0 launch blockers, not low-priority extras.

## Required review receipts per PR

Capture exact baseline/tree, changed files, source hashes/blobs, command/cwd/tool
versions/exit/counts, raw failures and source-bound final results. Keep focused,
ordinary, internal, connected, provider and device accounting separate. Reproduce
the complete patch from a clean archive, including new files, and verify hashes.
Changes to contracts require original-byte replay, generators, real PostgreSQL
RLS/transaction tests and two independent SQLite installations. Changes to local
schemas require frozen old-file upgrades, interruption rollback and old-reader
refusal. Never stage/commit/push/publish from an audit authorization alone.

Hardware, provider, signing, store/privacy and controlled beta gates are enumerated
in [release readiness](MVP_RELEASE_READINESS.md). Completing the code sequence is
necessary but does not itself authorize public launch.
