# Adversarial review

Review date: 2026-10-12. Scope: the complete Markdown planning package and root README, including the requested PRD, phase checklist, rules and implementation prompt. Reviewers independently examined product/platform, architecture/synchronization, and ML/assistant risks, followed by reconciliation across documents.

**Original planning-review status (2026-10-12):** specification findings below were corrected, independent closing reviews found no remaining material contradiction, and the documentation checks below passed. Phase 0 code now exists; [IMPLEMENTATION.md](IMPLEMENTATION.md) records the subsequent self-review, desktop tests and open gates. The historical documentation results below do not qualify application release behavior.

## Review method and authority

Test the plan against the athlete's actual workout, a disconnected phone, another device, a stale client, a malicious authenticated request, a misleading dataset and an overconfident assistant. A coherent happy-path diagram is insufficient.

Cross-check [PRODUCT.md](PRODUCT.md) and [prd.md](prd.md) against [ROADMAP.md](ROADMAP.md), then reconcile [DATA_MODEL.md](DATA_MODEL.md), [SYNC_PROTOCOL.md](SYNC_PROTOCOL.md), [API.md](API.md), numerical policies and security. Changes affect the authoritative specification and its dependent flows/tests, not only this report.

Severity means consequence if implemented incorrectly: **high** can lose/overwrite private training data, violate isolation/deletion or invalidate model evaluation; **medium** produces misleading behavior or a stranded workflow; **scope** adds unjustified work. Resolution here means corrected specification, not demonstrated runtime safety.

## Findings and corrections

| ID | Severity | Failure discovered/challenged | Corrected specification and required proof |
|---|---|---|---|
| AR-01 | Scope | Routines postponed beyond the first useful release | MVP includes routines, immutable templates and basic progress. Multiweek programs follow in Phase 2. |
| AR-02 | Scope | Premature microservices, feature stores, vector search and shared packages | One modular API, internal mobile modules, contract/parity fixtures; extraction requires measured need/ADR. |
| AR-03 | High | Auth expiry blocks a workout or deletes pending work | Separate cached local identity from cloud authorization; explicit logout locks the owner DB. Fault-test refresh loss and account switch. |
| AR-04 | High | Retry/double tap creates duplicate sets/workouts | Stable IDs, local status validation, frozen request bodies and transactional receipt/hash checks. Kill at every commit/ack boundary. |
| AR-05 | High | External pull silently rebases a pending branch | Working/shadow/local sequence remain distinct; expected revisions derive from original base/own predecessor. Test late acknowledgements and simultaneous edits. |
| AR-06 | High | Bare sequence cursor skips a late transaction | Commit-order owner lock/counter, not allocation time. Test concurrent commits and pull pagination. |
| AR-07 | High | Bootstrap replaces local work or reads drifting pages | Consistent materialized pages, staged activation, preserved pending/local-only roots, explicit expiry/capacity errors. Test logging during installation. |
| AR-08 | High | Deleted IDs are recreated by old devices/feed pruning | Retire root/child IDs and keep minimal receipt metadata; updates never become creates. Test prolonged-offline replay. |
| AR-09 | High | Previously authorized request commits after account disable | Deletion, mutation and publication share the owner guard with an under-lock state/generation check. Erasure workers permit deleting state for cleanup only. |
| AR-10 | High | Deleted values survive in transport or are recreated by in-flight jobs | Redact old feed payloads, invalidate snapshots and advance an erasure epoch checked before late materialized/derived publication. Test old cursors/tokens, preparation races and restored backups. |
| AR-11 | Medium | A local command is accepted but can never fit an upload | Shared 256 KiB command bound before local acceptance, 1 MiB adaptive batches and incremental free-workout commands. Preserve oversize drafts. |
| AR-12 | High | Routine/catalog edits rewrite historical training truth | Immutable content versions, session snapshots and changed-observation revisions. Permanent deletion is an explicit retention exception. |
| AR-13 | Medium | Load/name conflation produces false trends or PRs | Variant/equipment/load/rep/side comparison keys; assistance is a lower-assistance trend, never highest-load PR. Failed/partial attempts cannot earn completed-load achievements. |
| AR-14 | Medium | Supersets, unilateral work and holds are flattened | Explicit grouping and observed completion chronology; separate conventions and nullable duration/distance. Advanced segment builders wait. |
| AR-15 | High | Missing effort/rest/order becomes fabricated ML input | Preserve null/source/quality; completion gaps are not measured rest and logger order is not physical-order proof. No mandatory extra tap for speculative features. |
| AR-16 | High | Prescribed submaximal reps are mislabeled as capacity/fatigue | Model outcomes conditional on prescription; retain skipped, failed, deliberate deload and shortened-session context. |
| AR-17 | High | Acceptance timestamps falsely establish historical visibility | Capture committed owner-feed fence plus consistent source/feature manifest. Test an early timestamp with a commit after inference. |
| AR-18 | Medium | Median rep forecast uses a different load | Exact normalized requested-load/context match; different loads remain dated references. No baseline interpolation. |
| AR-19 | Medium | Epley on added pull-up load ignores body mass | Initial proxy only eligible total-external free-weight work; unsupported conventions remain references. Estimated strength is never a measured PR. |
| AR-20 | Medium | Progression mixes top/back-off work or ambiguous effort | Separate same-prescription groups; same-scale RIR/RPE inequalities, two exposures, one increment and conservative cap; deload/disabled policy abstains. |
| AR-21 | Medium | Repeated static training is called a strength plateau | Require progression intent and comparable adherence/effort; display unchanged prescription separately from possible plateau. |
| AR-22 | High | Assistant writes race unsynced client edits | Client atomically rechecks/reserves affected future-plan roots; server checks cloud CAS/policy. Never hold SQLite across a request. |
| AR-23 | High | Timeout/cancellation causes duplicate or unknown assistant changes | Stable commit identity, durable reservation, authoritative receipt recovery and explicit unknown outcome. No claimed rollback from timeout. |
| AR-24 | High | Model self-confirms or fabricates displayed numbers | Confirmation capability issued through authenticated UI path outside tool allowlist; numerical cards render validated tool fields/references. |
| AR-25 | High | Health permission silently authorizes AI/global data use | Separate purposes/consents; imported health stays local and outside LLM/global training by default. No health access in MVP. |
| AR-26 | Medium | Stale native export recreates corrected/deleted data | Refresh account/exporter generation/current session before write, reconcile after acknowledgement and compensate in-flight changes. |
| AR-27 | Medium | Health read absence is called denial or poor readiness | HealthKit read ambiguity and Health Connect availability are explicit; missing observations remain unknown. |
| AR-28 | Medium | Empty session finishes as a completed workout | Require attempted/performed work; provide continue/abandon/discard. |
| AR-29 | Scope | Documentation phases contradict directory/service timing | `ml/` begins when reproducible experiments start; Phase 3 rules are local with server mirror, learned inference starts server-side. |
| AR-30 | Medium | API/prediction examples disagree on metric shapes | Both use the same typed result envelope, IDs/task, units, visibility fence and reference metric names. |

The corrections are integrated into the domain, API, sync, security, prediction, assistant, health, user-flow and testing documents. The relevant design rationale is preserved in [DECISIONS.md](DECISIONS.md).

## Deliberate tradeoffs

- Aggregate conflicts can affect disjoint edits on the same session. This is acceptable while same-session live collaboration is excluded; logging remains local.
- Required signup adds initial network/email friction. It is an explicit product choice, monitored through activation and store feedback.
- One designated phone exports health summaries initially. Switching devices may need previous-store cleanup; no universal cross-store deduplication is promised.
- Optional effort and actual rest may be sparse. Models must be useful without them or abstain; data completeness cannot dictate workout friction.
- Global models require voluntary eligible data. A smaller consented cohort may delay ML; it does not justify bundled consent.
- Managed regional infrastructure reduces operations but does not prove legal compliance or eliminate processor/backup review.

## Remaining implementation gates

These are planned engineering evidence, not unresolved permission requests or claims already achieved:

1. Prove transaction, outbox, root-CAS, deletion, bootstrap and owner-isolation invariants with real databases and deterministic fault tests.
2. Qualify local migrations, interrupted entry, timer clocks, disk failure and first-run/email delivery on actual supported phones.
3. Measure logging latency, frame behavior and accessible one-handed operation; retain cohort/sample evidence.
4. Verify provider transport, backup expiry, restore-time deletion suppression, SMTP, secret separation and India/store disclosures before public launch.
5. Evaluate numerical methods and data visibility before Phase 3; calibrate learned models and audit consent/deletion lineage before Phase 5.
6. Red-team assistant confirmation, injection, grounding, reservations and timeout recovery before enabling write tools.
7. Test native export/recovery permissions, account/device switching and compensation on physical platforms before their optional phases.

Provider/model selection, lower OS support, wearable handoff and service extraction have explicit future gates/ADR conditions. They are deferred because their implementation evidence and product need do not exist, not silently assumed solved.

## Documentation verification

At handoff, verify required-file coverage, UTF-8 integrity, heading/fence structure, local links, JSON examples, prediction-envelope agreement, Markdown lint, actual Mermaid rendering and documentation-only repository scope. Validation artifacts/tools live outside the repository; delivered documentation remains Markdown only.

| Check run on 2026-10-12 | Result |
|---|---|
| Required package and additional requested files | 21 docs plus root README present; documentation files are Markdown only |
| UTF-8, final newlines, headings, fences, drafting markers and whitespace | Passed across all 22 files |
| Relative file links, including case-sensitive path checks | 205 resolved; no broken links |
| Fenced JSON examples | Five parsed successfully |
| API/prediction result examples | Semantically identical typed envelopes |
| Markdown lint | markdownlint-cli2 0.23.3: zero issues across 22 files; prose line-length and decorative table-alignment rules disabled |
| Mermaid | Mermaid CLI 12.0.0 rendered all ten diagrams with headless Chrome; final sources match those verified renders |
| Closing independent reviews | Architecture/sync, ML/assistant and product/platform findings closed in specification |
| Repository change scope and Git whitespace check | README and docs only; no product code, scaffold, deployment or commit |

Application tests, model evaluation, benchmarks, compliance certification and store approval have not been run for this documentation-only delivery. [TESTING.md](TESTING.md) specifies what evidence implementation must produce. Any new risk found during implementation reopens the affected decision and its acceptance gate.

## 2026-10-13 — Connected Phase 0 adversarial pass

The milestone received deliberate fault injection and an independent read-only
agent review, followed by regression fixes. Confirmed defects included non-JSON
transient errors, wrong-owner disable/credential-switch erasure, missing-account
misclassification, checksum changes from defaults, duplicate positions, snapshot
identity collisions, invalid dates, late capacity checks, local acceptance versus
transport disagreement, Unicode text bounds and blank correction reasons.

The final corrected suites passed: 80 ordinary Flutter cases, eight actual
HTTP/JWT/restricted-PostgreSQL Flutter cases and 49 Python cases. File-backed
SQLite tests reopen after acknowledgement, pull/cursor, bootstrap, conflict and
delete faults; no partial transaction is treated as installed. Exact scope and
limitations are in [IMPLEMENTATION.md](IMPLEMENTATION.md). Review found no reason
to weaken root CAS, frozen identities, owner isolation, pending-branch protection,
monotonic shadows or deletion suppression. No ADR changed. Physical-device,
production authentication, account-erasure jobs and release gates remain open.
