# Product requirements document

Status: accepted planning baseline. Updated: 2026-10-12. This PRD translates [PRODUCT.md](PRODUCT.md) into implementation acceptance criteria. It does not report implemented behavior. [ROADMAP.md](ROADMAP.md) owns phase scope; [DATA_MODEL.md](DATA_MODEL.md), [SYNC_PROTOCOL.md](SYNC_PROTOCOL.md) and [API.md](API.md) own technical semantics.

## Product, audience and first release

Daily Motion helps advanced strength/hypertrophy trainees create reusable routines, log performed work quickly and use trustworthy history during their next session. The first release targets English-speaking adults in India on iPhone and Android, using a lean team and managed infrastructure. It launches free; premium means polished, dependable interaction.

The required first-release journey is **Create routine -> Start workout -> Log exercises/sets -> Finish workout -> View history/progress**. Account creation needs connectivity; every established-user training step works locally after that, including when cloud authentication expires.

Core success measures are activation within seven days, repeat completed workouts, four-week retention, one-handed logging effort and workout reliability. Set numeric growth targets from beta evidence. The durable local save target is p95 <=100 ms on the qualification cohort; the crash-free workout-session target is 99.9% with sample/build context. These are targets, not measurements or promises already achieved.

## MVP requirements and acceptance

All requirements in this section are required for the first public release. Optional user inputs remain optional even when supporting infrastructure is required.

| ID | Requirement | Acceptance criterion |
|---|---|---|
| PRD-01 | Required account and minimal onboarding | A user verifies email OTP, selects units/focus and can reach routine creation or an empty workout without a medical questionnaire. Initial verification failure is recoverable. |
| PRD-02 | Offline account continuity | After verification, expired tokens and unavailable refresh pause cloud sync but permit local routine editing, session start/entry/completion and history. |
| PRD-03 | Owner isolation | Switching accounts never exposes or uploads the prior owner's database/outbox. Explicit sign-out preserves locked pending work unless the user deliberately erases it. |
| PRD-04 | Curated/custom catalog | A user can select a cached exercise or create a private variant with supported measurements/loading conventions. Catalog changes do not rewrite prior observations. |
| PRD-05 | Reusable routines | A user names a routine, orders exercises, supplies optional targets/rest and groups simple supersets. Saving publishes immutable template content; future edits leave started sessions unchanged. |
| PRD-06 | Start/resume session | Start produces one stable local session and self-contained prescription. A second start on that device offers resume/finish/abandon. Other devices' independently started sessions are preserved. |
| PRD-07 | Fast logging | An editable prefilled set can be deliberately completed in one tap. Completion feedback follows durable local storage, without a server/prediction dependency. A double tap cannot create a second set. |
| PRD-08 | Accurate measurements | Barbell total, dumbbell per-implement, machine stack, bodyweight, added load, assistance, unilateral conventions and original units remain explicit. Valid zero is distinct from unknown. |
| PRD-09 | Set semantics | Warm-up/working classes, regular/top/back-off purpose and pending/completed/partial/failed/skipped states remain distinct. RIR/RPE is optional and retains its reported scale. |
| PRD-10 | Basic holds/carries | Supported duration/distance entries can be recorded without pretending they are repetition/load strength observations or full cardio tracking. |
| PRD-11 | Recoverable entry/corrections | Interrupted drafts return uncompleted. Corrections/undo preserve prior truth and update derived eligibility. Correcting a completed session does not reactivate it. |
| PRD-12 | Rest and supersets | Timers restore after suspension/restart; denied notifications do not affect saving. Superset membership/order is explicit; timer gaps are not claimed to be measured actual rest. |
| PRD-13 | Substitution | The ordinary picker creates a replacement relationship, preserves the intended exercise and completed original sets, and asks separately before changing the reusable routine. |
| PRD-14 | Completion/abandonment | Finish requires an explicit action and attempted/performed work. Empty sessions offer continue/abandon/discard. Abandonment retains performed work without inventing missed-set outcomes. |
| PRD-15 | History/progress | A user inspects sessions and comparable exercise load/rep trends with units and source context. Unsupported comparisons are explained. Assistance is not rewarded as highest lifted load. |
| PRD-16 | Reliable synchronization | Exact retries do not duplicate entities; stale writes conflict; remote pulls preserve pending local branches; bootstrap/migration do not discard unsynced work. |
| PRD-17 | Privacy and portability | Users can request owner-scoped account export/deletion and permanently delete workouts. Old cursors/snapshots cannot return erased payloads; retention/backup limitations are accurate. |
| PRD-18 | Platform accessibility | Train/History/Progress and logging work with screen readers, enlarged text, reduced motion and gesture alternatives. Targets meet the shared 48-logical-pixel minimum; navigation respects each platform. |

Routine targets and past results are suggestions until deliberately recorded. Timing/order includes source/quality; delayed logging must not become proof of physical execution order. Working-set summaries exclude warm-ups, drafts and deleted outcomes.

## Functional boundaries after MVP

| Phase | Added requirement | Release condition |
|---|---|---|
| 2 | Versioned multiweek programs, manual measurements, richer analytics and previewable CSV import | Past intent survives changes; missing/imported fields remain unknown; repeat imports do not duplicate data. |
| 2 optional | Completed-workout health export | Designated current exporter, current accepted revision, stable native identifiers, retry/compensation and permission qualification. |
| 3 | Numerical references, estimates and progressive-overload proposals | Supported conventions, committed visibility provenance, conservative abstention and local/server parity. No invented confidence. |
| 4 | Deeply integrated training assistant | Authorized grounded tools, exact preview/confirmation, local reservation and cloud CAS. Initial writes affect future plans only. |
| 5 | Statistical/global/hierarchical models | Separate donated-data opt-in, causal labels, temporal/cold-start value, calibrated uncertainty and rollback. |
| 6 | Recovery/wearable intelligence | Purpose-specific consent, local-only health default, incremental benefit and tested disconnection/ownership. |

The long-term product adapts useful future plans to time budgets, missed sessions, changing goals and validated performance evidence. Adaptation is a reviewed proposal through domain systems; the LLM orchestrates and explains rather than fabricating weights or hidden writes.

Billing has a separate later decision/gate. Clinical diagnosis, rehabilitation prescriptions, social feeds, nutrition tracking, coach marketplaces, live cross-device workout handoff and automated specialist methods are outside MVP. See [PRODUCT.md](PRODUCT.md) for the full scope rationale.

## Failure and release acceptance

The first public release is blocked by known lost acknowledged sets, duplicate accepted workouts, cross-user access, silent conflict overwrite, unrecoverable migration, misleading completion feedback or unqualified deletion behavior.

Qualify airplane-mode logging, process loss at commit/ack boundaries, disk failure, authentication loss, two-device conflicts, deleted-ID replay, feed pruning, snapshot expiry, interrupted imports in their phase, and shared transport limits. Run on physical supported phones with representative long history.

User-visible errors distinguish local-save failure from cloud delay. Optional services and unavailable permissions leave the core loop usable. Beta findings and support needs can change scope through [DECISIONS.md](DECISIONS.md), rather than accumulating unrelated AI features.

## Traceability and change control

Link implementation PRs and tests to the relevant PRD IDs and phase gate. Describe observable before/after behavior, validation evidence and material limits. Do not interpret a future requirement as permission to expand the current milestone.

| Requirement group | Authoritative implementation references |
|---|---|
| PRD-01–03 | [SECURITY.md](SECURITY.md), [USER_FLOWS.md](USER_FLOWS.md), [API.md](API.md) |
| PRD-04–15 | [DATA_MODEL.md](DATA_MODEL.md), [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md), [USER_FLOWS.md](USER_FLOWS.md) |
| PRD-16–17 | [SYNC_PROTOCOL.md](SYNC_PROTOCOL.md), [SECURITY.md](SECURITY.md), [TESTING.md](TESTING.md) |
| PRD-18 | [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md), [TESTING.md](TESTING.md) |
| Future intelligence/integrations | [ML_ROADMAP.md](ML_ROADMAP.md), [PREDICTION_ENGINE.md](PREDICTION_ENGINE.md), [CHATBOT_ARCHITECTURE.md](CHATBOT_ARCHITECTURE.md), [HEALTH_INTEGRATIONS.md](HEALTH_INTEGRATIONS.md) |

Use [phases.md](phases.md) as the implementation checklist and [ADVERSARIAL_REVIEW.md](ADVERSARIAL_REVIEW.md) as the regression-risk register. Product performance/retention claims need measured evidence; documentation approval alone cannot establish them.
