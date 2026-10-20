# Session 2 handoff to Session 4

2026-10-20. Dedicated branch: `phase0/recovery`. Worktree:
`E:\Motion\Daily-Motion-worktrees\recovery`. Base: `57a4494`.

Implementation commit: **`77e5124bf8e0065dbcaf39c919f0e33cc616f93f`**
(`fix: preserve workout branches across disaster recovery`). The following
evidence/handoff commit completes the track; obtain its SHA with `git log -1`
on this branch. Both commits are local and unsigned: the configured signing key
was locked, so a per-command signing override was used. Signing configuration
and keys were not changed. No push, merge, deployment or Phase 1 start occurred.

## Verified results

| Verification | Result and scope |
| --- | --- |
| PostgreSQL recovery and target guards | **24 passed, 0 skipped**: 11 real local recovery cases and 13 boundary cases |
| Full Python with dedicated local PostgreSQL | **178 passed, 0 skipped**, including the connected Flutter harness; real-login cases use SCRAM authentication |
| Connected Flutter HTTP/PostgreSQL | **9 passed**, enabled separately inside the Python run, with real JWT/HTTP/SQLite/PostgreSQL and simulated provider identity |
| Full ordinary Flutter suite | **157 passed, 12 explicitly skipped**; skips comprise those 9 connected cases run above and 3 hosted credential-gated cases left unrun |
| Focused restore/account lifecycle | **31 passed**, including 6 new file-backed restore regressions |
| Static/repository checks | Flutter analyze; Dart formatting; Ruff lint/format; strict mypy; native static guards; documentation links; credential guard and whitespace checks pass |

The 13 target guards occur in both the focused and full Python selections; do
not sum those counts as distinct tests. PostgreSQL **17.11 native Windows** was
used after Docker engine startup failed. The Docker execution branch remains
unqualified by this session. All disposable clusters and restore databases were
removed. Prior failures, source hashes, table fingerprints and exact limits are
preserved in [machine-readable evidence](evidence/phase0-database-recovery-2026-10-20.json)
and the [qualification report](RECOVERY_QUALIFICATION.md).

The independent audit confirms the Oct 18 restore evidence's internal fingerprint
agreement and recorded limits. New reproducible tests populate **all 11 tables**
and cover corruption, missing ACL roles, interrupted restore/rollback/retry,
immutable retirement and refused migration rollback, all-table forced RLS,
owner isolation, foreign keys, receipt consistency, snapshot checksums, backend
loss and local WAL crash recovery. A 33,199-byte synthetic archive restored in
approximately 0.28–0.92 seconds across seven measured successes; these small
archive timings are **not hosted RTO**.

## Defects fixed and operational requirements

- A restored feed that reuses its old generation/positions can silently skip
  divergent changes for a discarded-timeline cursor. The tested
  [restore fence](../infra/recovery/restore_fence.sql) requires fresh generations,
  a bootstrap watermark, an advanced erasure fence and snapshot invalidation.
- The client ignored divergent equal/lower restored root revisions and could
  upload a frozen pending command against a reused revision. It now installs
  the restored shadow separately, preserves the working branch/base/frozen body,
  marks a conflict and persists a private upload fence across further logging
  and file reopening, including downloaded roots without outbox history.
- A previously acknowledged local workout missing from a restored backup was
  removed. It now remains recoverable as a conflict; retired-ID erasure still
  applies. Unchanged restored roots continue normal synchronization.

No schema or contract changes are required. Phase 1 conflict-resolution UI is
not implemented. Do not reopen a restored environment to unqualified older
clients or roll back to the old client during recovery: doing so reintroduces
these hazards. A fresh feed generation alone does not bind every old mutation
envelope to the restored timeline. Reconcile branches before writes.

Reconcile erasure epochs against a failure-independent ledger/high-water mark;
incrementing an old backup value once can still remain behind a phone's cached
epoch. Production deletion-ledger replay/purge and the operational fence replay
remain release work. Local nonempty retirement preservation does not close them.

## Exact approvals remaining

Use the complete [hosted strategy](../infra/HOSTED_RECOVERY_STRATEGY.md) for the
reviewable choices, cost calculations, custody controls and isolated drill steps.
It proposes seven-day retention, below the existing 35-day policy ceiling;
no retention or spending decision has been accepted.

| ID | Session 4 must obtain |
| --- | --- |
| REC-01 | Select A (Free plus independent export), B (Pro daily plus independent export, recommended for synthetic Phase 0), or C (Pro/Small/PITR plus export); name billing owner and approve recurring and isolated-drill caps. B's proposed budget is $25/month provider baseline plus up to $10/month export costs and $5 per drill, subject to the actual quote. C's provisional provider baseline is about $130/month before exports/drills/tax/usage. |
| REC-02 | Accept or replace proposed daily-route **RPO 24 hours / RTO 8 hours** and seven-day retention; C proposes in-provider **5 minutes / 4 hours**, subject to measurement. Approve scheduling, alert response, noncurrent versions/soft-delete handling and outage expiry decisions. |
| REC-03 | Name primary/alternate recovery operators, incident owner, separate key custodian and privacy/security reviewer; approve proposed Supabase/Google processor locations/terms, backup IAM, encryption and emergency key access. |
| REC-04 | Authorize the exact hosted source project and backup time, permitted export/read operation, newly isolated destination/region, route, credential re-establishment scope, spending/lifetime and cleanup. No existing hosted reset or in-place restore is authorized. |
| REC-05 | Approve extension/cron/webhook inventory and outbound containment before a clone can execute jobs; approve Auth UUID mapping, configuration/root-key treatment, synthetic recipients and isolated API endpoints. |
| REC-06 | Named operator/reviewer accepts actual backup custody/decryption, verified expiry and isolated hosted restore, timeline/deletion/owner/receipt checks, source preservation and measured total RPO/RTO. |

No existing hosted database was read, exported, reset or modified; no production
credentials or personal user data were retrieved. Hosted Auth recovery, off-site
encrypted retention/key-loss recovery, real expiry and provider recovery remain
unqualified. Physical phone backup/transfer, secure storage and durable-save
latency remain separate device gates. Leave shared roadmap/status reconciliation
to Session 4; Phase 0 stays open.
