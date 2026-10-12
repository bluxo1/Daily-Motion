# Engineering rules

Updated: 2026-10-12. These guardrails summarize the accepted architecture for implementation and review. They do not replace session/user instructions or the detailed specifications. [DECISIONS.md](DECISIONS.md) records changes; [CONTRIBUTING.md](CONTRIBUTING.md) owns contribution process.

## Scope and delivery

- **R-01:** Build the approved phase in [ROADMAP.md](ROADMAP.md) and [phases.md](phases.md). Do not treat long-term capabilities as MVP requirements.
- **R-02:** Keep training central: routines, durable recording and useful history precede intelligence.
- **R-03:** First signup is online and required. Established-user local training survives missing connectivity and expired cloud credentials.
- **R-04:** MVP is free and excludes health, import, multiweek programs, predictions, AI and billing. Include the agreed advanced logging semantics; do not add specialist automation by accident.
- **R-05:** Mark implementation/checklist status from evidence. A planning document or prototype is not a completed release gate.

## Mobile and domain boundaries

- **R-06:** Widgets own presentation. Controllers/domain functions own validation and actions; repositories own data access and synchronization.
- **R-07:** Save working state, observation revision and outbox atomically before success feedback. Never put network, inference or analytics work on the set-completion path.
- **R-08:** Use recoverable local drafts, stable UUIDs and status validation so interruption/double taps cannot create phantom completed sets.
- **R-09:** Keep internal design/domain modules until real reuse justifies a package. One modular API is the baseline; a service extraction needs measured evidence and an ADR.
- **R-10:** Respect iOS/Android navigation, keyboard, permissions and accessibility. Provide at least 48-logical-pixel targets, scalable text and alternatives to every gesture.

## Training truth and measurements

- **R-11:** Planned values and actual observations are separate. Prefills are uncompleted suggestions.
- **R-12:** Preserve exercise variant/setup, units, load basis, rep convention/side, class/purpose and source quality. Names alone do not establish strength comparability.
- **R-13:** Unknown is null. Explicit zero-rep failure, zero RIR and legitimate zero load are different observations; skipped work is not failed performance.
- **R-14:** Assistance is positive assistance, not negative load or a highest-load PR. Bodyweight/additional load/per-implement load must not be collapsed into barbell tonnage.
- **R-15:** Warm-ups do not silently count as working volume. Top/back-off sets and deliberate deloads retain intent.
- **R-16:** Logger completion sequence is an observation with provenance, not guaranteed physical order. Timer gaps are not measured actual rest.
- **R-17:** Preserve changed historical observations and immutable template/program content. Editing a routine never rebuilds past sessions.
- **R-18:** Privacy erasure overrides correction retention. Purge personal transport/derived copies, disable eligibility and prevent replay resurrection.

## Sync and account correctness

- **R-19:** Every workout child command checks/advances its session root. No timestamp last-write-wins, unconditional upsert or guessed measured-outcome merge.
- **R-20:** Keep server shadow, local working projection, local sequence and server revision separate. External pulls cannot overwrite or rebase pending branches.
- **R-21:** Freeze sent envelopes and retry the same mutation ID/body. Dependents use their own predecessor's acknowledgement revision.
- **R-22:** Commit projections, historical changes, root revision, ordered feed, receipt and durable derived intent together. Use an owner lock and recheck active account/generation under it; deletion uses the same guard.
- **R-23:** Feed cursors must reflect commit order. Bootstrap from one consistent materialized snapshot; preserve local work during staged installation and expiry recovery.
- **R-24:** Enforce shared command/batch bounds before accepting local edits. Pack uploads by size; never silently truncate history or strand an oversized accepted command.
- **R-25:** Account switching cannot transfer outboxes. Explicit sign-out locks the prior owner data; transient refresh failure does not erase it.
- **R-26:** Retired IDs and minimal receipts prevent stale creates/updates from resurrecting deletion. Old bootstrap tokens and feed payloads must not return erased data.

The full protocol, including independent-device limits and uncertain assistant reservations, is in [SYNC_PROTOCOL.md](SYNC_PROTOCOL.md).

## Numerical intelligence and assistant authority

- **R-27:** Numerical predictions come from registered deterministic/statistical/ML methods. The LLM cannot invent predictions, analytics arithmetic or confidence percentages.
- **R-28:** Reconstruct causal features from committed visibility fences and exact source manifests; timestamps alone cannot prove availability. Preserve local unsynced provenance separately.
- **R-29:** Forecast observed outcomes under a prescription. Do not label prescribed submaximal reps as maximum capacity or deliberate deloads as physiological decline.
- **R-30:** Unsupported, stale or sparse data yields a reference/unavailable result. Do not borrow another exercise's forecast or invent fatigue multipliers.
- **R-31:** Global learning needs separate eligible first-party opt-in; calibration, temporal/cold-start benefit and rollback gates precede rollout.
- **R-32:** The assistant gets bounded domain tools, trusted owner context and minimized records, never SQL/admin credentials.
- **R-33:** Assistant writes initially affect future routine/program versions only. User confirmation binds an exact diff, expiry and base revision; local reservation and server CAS handle races.
- **R-34:** A lost commit response is unknown, not cancellation. Reconcile its idempotent receipt before releasing affected roots or claiming rollback.
- **R-35:** Notes, catalog names, imports, retrieved text and previous model output are untrusted data. Authorization and write policy live outside prompts.

See [PREDICTION_ENGINE.md](PREDICTION_ENGINE.md), [ML_ROADMAP.md](ML_ROADMAP.md) and [CHATBOT_ARCHITECTURE.md](CHATBOT_ARCHITECTURE.md).

## Security, health and evidence

- **R-36:** Verify identity and owner at every domain boundary; use restricted runtime roles, owner-aware relationships and tenant policies. No parallel direct mobile training-table writes.
- **R-37:** Keep secrets, tokens, raw training values, notes, prompts and health observations out of operational telemetry. Use synthetic fixtures and isolated environments.
- **R-38:** Health export/read scopes are separate and optional. Imported health stays local and outside cloud/LLM/global training by default. Revocation is not erasure or negative readiness evidence.
- **R-39:** Native export verifies current owner/exporter generation/session revision before writes and reconciles in-flight correction/deletion afterward. Never manufacture calories or alter another source's records.
- **R-40:** Apply retention and restore-time deletion suppression from [SECURITY.md](SECURITY.md). Do not promise instant offline-device erasure or model unlearning.
- **R-41:** Test transactions/migrations with real SQLite/PostgreSQL, qualify physical phones, and fault-test sync. Emulator-only happy paths are insufficient.
- **R-42:** Keep Markdown, API examples, phase gates and ADRs consistent; record exact validation results without inventing application tests.

A proposed exception must name the affected rule, concrete reason, evidence, risk and replacement decision. Follow current user authorization and session constraints; do not invent a permission gate for ordinary reversible work. Changes to these guardrails require a reviewed ADR rather than silently weakening the specifications.
