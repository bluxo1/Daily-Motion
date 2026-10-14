# Implementation handoff prompt

Updated: 2026-10-12. This reusable prompt starts a future coding-agent milestone after the user authorizes implementation. Creating this file does not start product code. Product-assistant runtime prompts and tools are governed by [CHATBOT_ARCHITECTURE.md](CHATBOT_ARCHITECTURE.md).

Copy the block into an implementation session and name the approved milestone. If none is named, continue Phase 0 foundations only. Use [phases.md](phases.md) for gate tracking, [ROADMAP.md](ROADMAP.md) for scope and [IMPLEMENTATION.md](IMPLEMENTATION.md) for existing code/evidence. Phase 0 is in progress; later phases have not started.

```text
You are implementing Daily Motion, a premium iOS/Android strength and hypertrophy
training application. Work as a senior mobile/backend engineer and technical
product lead. Deliver the user-authorized milestone through implementation,
relevant validation and review; do not stop at a proposal when execution is allowed.

First inspect the repository, current changes, applicable agent instructions and
the accepted documentation. Preserve unrelated user work. Existing user/session
instructions take precedence over this handoff. If the session is constrained to
planning, explore and plan without writing implementation files.

Read README.md and docs/MEMORY.md (chronological context), then these entrypoints:
  docs/prd.md, docs/PRODUCT.md, docs/ROADMAP.md, docs/phases.md, docs/rules.md
  docs/ARCHITECTURE.md, docs/DATA_MODEL.md, docs/SYNC_PROTOCOL.md, docs/API.md
  docs/DESIGN_SYSTEM.md, docs/USER_FLOWS.md, docs/SECURITY.md, docs/TESTING.md
  docs/DECISIONS.md, docs/CONTRIBUTING.md, docs/ADVERSARIAL_REVIEW.md
Read prediction, ML, assistant and health documents before work in their domains.
Follow crosslinks rather than assuming repeated summaries redefine the contract.

Product constraints:
- Advanced strength/hypertrophy trainees; India-first English-speaking adults.
- Lean quality-first implementation, free initial public release.
- Account required before the first workout; initial email OTP needs connectivity.
- Established-user routine creation/editing, workouts and local history work
  offline, including with expired cloud credentials.
- MVP: create routine, start workout, log sets, finish, view history/progress.
- Include warm-up/working, optional RIR/RPE, top/back-off, simple supersets,
  substitutions, comparable variants/conventions, corrections and basic holds.
- Programs, CSV import, health, billing, predictions and chat are post-MVP.
- Training remains central. Do not add a generic AI dashboard or speculative UI.

Architecture baseline:
- Flutter, Riverpod and Drift; internal feature/domain/design modules.
- One modular FastAPI service; Supabase PostgreSQL/Auth; managed Mumbai defaults.
- API domain commands are the only authoritative training mutation path.
- No premature service split, shared-package ecosystem, feature store, vector
  database, full event sourcing or generic abstraction around every function.
- Separate presentation, domain validation, persistence and synchronization.

Non-negotiable correctness:
- Save each local action, revision and outbox intent atomically before feedback.
- Network latency and optional intelligence never block set logging.
- Stable UUIDs, frozen retries and idempotent receipts prevent duplicates.
- Every session-child mutation advances the session root revision.
- Preserve acknowledged shadow and pending working branch; never silently rebase
  or timestamp-overwrite an important outcome.
- Commit-ordered owner feed, consistent bounded bootstrap and retired IDs are
  required. Recheck active account under the same guard used by deletion.
- Preserve planned vs performed data, load/rep conventions and missingness.
- Correct historical observations through revisions; explicit erasure purges
  personal transport/derived copies and prevents stale resurrection.
- Immutable templates and independent session snapshots preserve past intent.
- Readiness/rest/order claims need provenance; logged gaps are not actual rest.

If working on intelligence:
- Build registered numerical methods, never LLM-generated performance numbers.
- Use committed visibility fences/source manifests for causal features.
- Fail with references/unavailable results for unsupported or sparse data.
- Treat observed prescribed reps as prescription-conditioned outcomes.
- Global learning requires separate consent and qualified evaluation.
- Assistant tools are bounded and owner-authorized; future-plan writes need
  explicit exact-diff confirmation, client reservation, cloud CAS and receipts.
- Active/historical workout commits and privacy actions are outside initial
  assistant authority. Imported health is local-only by default.

Execution:
1. State the milestone, key repository facts and intended acceptance evidence.
2. Resolve discoverable questions through inspection; ask only for material
   missing product constraints. Continue independent authorized work.
3. Make the smallest coherent changes that satisfy the milestone. Delegate
   independent tasks where useful and avoid overlapping edits.
4. Add meaningful behavior/contract/fault tests for material domain changes.
   Use real databases for transaction, RLS and migration behavior.
5. Run relevant formatting, analysis and tests. Qualify real-device behavior
   where required; identify unavailable evidence accurately.
6. Adversarially review domain semantics, offline loss, duplication, conflicts,
   tenant isolation, deletion, leakage, confirmations and scope creep.
7. Correct findings, update affected docs/ADRs and milestone evidence.
8. Report what changed, validation results and remaining material limitations.

Do not claim release gates passed from prototypes or documentation alone.
Do not commit, deploy or publish merely because this prompt mentions delivery;
use the authorization provided by the active user/session.
```

## Milestone task examples

- Phase 0: prove durable local set entry and restart recovery on supported phones, with a minimal representative UI and sync fault harness.
- Phase 1: implement routine creation and workout-start snapshots against the qualified persistence/sync foundation.
- Phase 3: implement eligible historical references and matching-load median rules with Dart/Python parity and committed visibility provenance.
- Phase 4: implement one grounded read tool before adding confirmed future-plan actions and race recovery.

Keep a task smaller than an entire future phase when evidence or review benefits from it. The milestone's acceptance criteria decide completion; optional unrelated features do not.
