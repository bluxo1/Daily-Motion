# Phase 0 hosted backup and recovery decision package

Prepared by Session 2 on 2026-10-19. **Proposal only; no paid plan, retention
change, hosted export, restore or credential operation is authorized by this
document.** The existing Free staging project has no qualified managed backup.
Local database results are recorded separately in [RECOVERY.md](RECOVERY.md).
Session 4 owns shared roadmap/status updates.

## Objectives and choices requiring approval

RPO is the maximum tolerable loss of **cloud-accepted** changes. A phone's pending
outbox is not a server backup and can be lost with that phone. RTO starts at
incident declaration and ends only after identity, deletion suppression, data,
isolation and application checks permit access. All numbers below are proposed
objectives, not measurements, provider guarantees or accepted policy.

| Choice | Proposed RPO / RTO | Proposed retention | Planning cost in USD |
| --- | --- | --- | --- |
| A: Free plus independent daily encrypted export | 24 hours / 8 hours | 7 daily copies | Supabase $0; approve a $10/month ceiling for storage, key custody, scheduler and export egress; separate restore capacity may cost extra |
| B: Pro daily backup plus independent daily encrypted export (recommended for Phase 0) | 24 hours / 8 hours | 7 managed daily points and 7 independent daily copies | Pro starts at $25/month with one Micro covered by compute credits; propose $10/month export budget and $5 per isolated drill, subject to a real quote |
| C: Pro, Small compute and 7-day PITR, plus daily independent encrypted export | 5 minutes / 4 hours for in-provider incidents; 24 hours / 8 hours if provider/account loss forces independent export | 7-day PITR and 7 independent daily copies | Approximately $130/month: $25 plan + $15 Small - $10 credit + about $100 PITR; export and drill budgets additional |

Prices were checked against [Supabase pricing](https://supabase.com/pricing) and
[backup/PITR pricing](https://supabase.com/docs/guides/platform/backups) on
2026-10-19. Compute credits apply once per organization, not per project; existing
paid projects can change the incremental cost. PITR needs at least Small compute,
replaces daily backups, and its effective recoverable endpoint must be measured.
The 5-minute target is a proposed operational target, not a provider SLA.
For a single project C's provisional base is $130; adding another continuously
running Small restore project adds about $15/month before usage. Temporary
projects are billed for their actual lifetime. Taxes, currency conversion,
object bytes, network, API hosting and operator labor are excluded. Obtain the
dashboard quote before any purchase. Options B/C also need an approved independent
export if recovery must survive deletion of the Supabase project/account.

All proposed windows are below the **35-day maximum** in
[SECURITY.md](../docs/SECURITY.md). Approving 7 days does not permit accumulating
35 days elsewhere. Longer retention, hourly exports or cross-region replicas
require a new decision and cost calculation. If A's independent archive cannot
be made and restored safely, A provides no qualified backup and is not an
acceptable substitute for B. Free project pausing also needs a monitored response.

## Independent export custody and encryption

Proposed destination: a private Google Cloud Storage **Standard** bucket in
Mumbai (`asia-south1`), in an operator-owned backup project separate from API
runtime and Supabase administration. This adds Google backup processing to the
Supabase Mumbai / Render Singapore staging arrangement and needs processor and
cross-border review; a region name alone is not compliance approval. No bucket,
key, account or schedule has been created.

Use verified TLS for export and transport. Stream the approved logical export
through authenticated client-side envelope encryption (AES-256-GCM data key,
separately wrapped under an approved Cloud KMS key); use a maintained reviewed
implementation, never a new cryptographic format. Require a complete authenticated
stream before restore. Store ciphertext with provider encryption at rest as a
second layer. Select and qualify the actual encryption tool after custody approval;
this document does not claim that encryption or key-loss recovery was tested.

Name a primary backup operator, alternate recovery operator, independent key
custodian and privacy/security approver. Give the scheduled writer object-create
and encryption permissions only; no object read/delete or key decrypt permission.
The restore identity gets time-bounded ciphertext read/decrypt access through an
audited operator procedure. The API/mobile receive no backup or key permissions.
Protect human access with MFA, audit access without payloads, and keep emergency
identity/key recovery outside the same compromised account. Test both normal
decryption and custodian unavailability before accepting custody.

Use immutable unique object names; publish the completion manifest only after
upload and integrity checks finish. Retain seven complete daily copies and alert
when the newest complete recovery point is older than 24 hours. Run once daily;
page the named operator on a failed job immediately and on excessive backup age.
An alert does not repair a missed RPO: record actual gaps and incident response.
Do not destroy the last usable copy automatically after a failed job without an
explicit retention/privacy decision.

Configure lifecycle expiry at 7 days, and account explicitly for noncurrent
versions, soft-delete retention, failed multipart uploads and temporary restore
objects. Either disable version/soft-delete extensions for this dedicated bucket
or include their combined maximum lifetime in the approved 7-day window. Measure
actual disappearance; a lifecycle rule is not proof of timely deletion. Avoid
locked retention exceeding the policy. Before expiry of the last valid copy in
an outage, escalate instead of silently retaining beyond the approved window.

Size the quote from measured encrypted archive size D GiB: seven daily full
copies consume approximately **7D GiB**; monthly export traffic is approximately
**30D GiB**, plus drills. Use **7D x regional Standard rate + operations + export
egress + scheduler/runner + KMS versions/operations + drill compute**. For D=1,
budget for 7 GiB stored and 30 GiB exported monthly. The $10 ceiling is a proposed
budget, not a quoted cost. Google lists location-dependent storage, operation and
network charges; software KMS key versions are $0.06/month before operation
charges. Obtain the selected-region quote and confirm Supabase egress before
enabling a job. [Cloud Storage pricing](https://cloud.google.com/storage/pricing),
[Cloud KMS pricing](https://cloud.google.com/kms/pricing).

## Required backup inventory

An archive of `training` alone cannot recover verified users. The approved backup
must capture a consistent view of application tables, receipt/feed/owner state,
retired IDs, account-retirement markers, profiles and Alembic history, together
with provider-supported Auth identity records preserving subject UUIDs. Record
source project identity/region, DB/server/client versions, schema and code commit,
snapshot time, owner feed/revision summaries, counts, constraints, indexes, forced
RLS, policies and grants in a protected manifest. Include archive size and SHA-256;
authenticate the manifest separately so a substituted archive and hash are
detectable. Protect even aggregate metadata when it describes real accounts.

Inventory Storage object bytes separately from database metadata; record "unused"
only after verification. Capture approved nonsecret Auth/SMTP/redirect/rate-limit,
extension, Realtime and API configuration separately. Secret-manager references
and rotation procedures replace plaintext credential copies. Verify whether
Vault or encrypted columns exist; a manual logical move needs separate root-key
handling when they do. Application migration authority remains Alembic.
[Supabase's supported logical recovery procedure](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore).

Managed backups stay within the provider's failure domain. Supabase documents
loss of its backups when a project is deleted. A provider restore does not
automatically prove independent custody, object recovery or custom-role login.
Re-establish the restricted runtime login through the existing SCRAM provisioner
with separate approval; do not put passwords in SQL logs or restore evidence.

## Isolated hosted drill and access gate

1. Obtain approval identifying the exact source project, backup timestamp, route,
   new target/region, permitted read/export operations, named operator/reviewer,
   spending cap, target lifetime and cleanup. No reset, restore-in-place or export
   of an existing hosted database is covered by this local mission.
2. Inventory extensions, cron jobs, webhooks, wrappers and external side effects.
   Supabase's **Restore to a New Project** requires a paid plan with physical
   backups, copies database/Auth identities and the encryption root key, and
   requires service configuration afterwards. Copied outbound jobs can start
   immediately. Approve that route only after proving no prohibited external
   execution can occur; otherwise use the supported logical route so jobs and
   triggers can be reviewed/neutralized before they run. Do not infer outbound
   containment from a private API or a new project name.
   [Clone behavior and limitations](https://supabase.com/docs/guides/platform/clone-project).
3. Keep the new target closed to ordinary users/jobs, disconnected from the live
   mobile/API origins, with outbound email/webhooks and scheduled effects
   suppressed. Check archive authenticity and decryptability before restoration.
   For custom-format application restores, require `pg_restore --single-transaction
   --exit-on-error --no-owner`; inspect grants and ownership explicitly. For a
   provider logical migration, follow its reviewed schema/Auth procedure instead
   of applying a bare local PostgreSQL archive to managed schemas.
4. Fence the restored timeline in the **new isolated target**, before opening
   access. In one operator transaction assign fresh `owner_state.generation`
   UUIDs, set each `minimum_position=position`, advance `erasure_epoch`, and delete
   transient snapshots. Preserve historical receipts and revisions. Without this
   step an old cursor can match a reused position in a divergent restored feed
   and silently skip a new change. Verify old cursors require bootstrap and old
   snapshot tokens fail; fresh bootstrap and exact historical retries must work.
   [The tested SQL](recovery/restore_fence.sql) must execute in one transaction
   with stop-on-error behavior against the approved isolated target. It is not an
   automatically deployed job.
   Keep writes fenced until client pending branches and any reused root revision
   numbers have been reconciled: changing the feed generation alone does not
   bind every mutation's expected revision to a disaster-recovery timeline.
   Reconcile `erasure_epoch` against an independent ledger/high-water mark as
   well: one increment of a rewound backup can remain lower than a phone's cached
   epoch. Such a phone correctly refuses bootstrap. This lab's one-increment
   fence is qualified for its synthetic history, not all discarded production
   timelines; the production ledger/fence replay remains release work.
5. Replay and independently verify the authoritative deletion ledger from
   **outside the restored snapshot before any access**. A nonempty local retirement
   row proves marker preservation only. The production ledger, payload purge and
   restore replay job remain Phase 1 release work. Do not open a real-user restored
   environment while that prerequisite is absent. Synthetic Phase 0 qualification
   must state its scope and cannot close this production gate.
6. Verify Auth UUID to training owner mapping, Alembic revision, all table/row and
   metadata fingerprints, receipt/feed/revision consistency, forced RLS and
   restricted non-owner grants. Reconfigure TLS, issuer/JWKS and client-safe
   endpoints for the isolated target. Check readiness and unset/A/B owner denial,
   nested foreign keys, immutable retirement markers and pooled-context reset.
7. With controlled synthetic recipients, run exact duplicate/digest mismatch,
   lost response/restart, pending retry, cursor/pull/bootstrap, A -> B -> A and
   retired-ID/account rejection against that target. Test a deliberately damaged
   archive, interrupted restore and rollback/retry in a further disposable target.
   Never run the ordinary `daily_motion_test` fixture against a provider.
8. Record declaration, approval, retrieval, key access, restore completion,
   verification and access-approval timestamps. Report total RTO and age of the
   newest recoverable accepted change. Preserve redacted failures and recovery
   actions; archive-only restore time is not full RTO. Prove old live resources
   and origins were unchanged. Destroy only the approved target/copies and revoke
   temporary access; verify cleanup and expiry.

Rollback keeps the live source/origins unchanged throughout the drill. Reject a
failed candidate and discard its isolated target; retry from the verified copy
in another fresh target. A future incident cutover needs its own change plan and
write fence: after clients write to a new target, switching back to an old source
without reconciliation can lose acknowledged work. No cutover is proposed here.

## Approval record for Session 4

| ID | Required decision or authorization | Concrete response needed |
| --- | --- | --- |
| REC-01 | Funding and route | Select A/B/C, approve recurring and drill caps, and identify billing owner; B is recommended for synthetic Phase 0 |
| REC-02 | Recovery/retention policy | Accept or replace the proposed RPO/RTO and 7-day window, including versions/soft deletes, schedule, alerts and outage expiry procedure |
| REC-03 | Processor and custody | Approve Supabase/Google locations and terms, name primary/alternate operators, key custodian, incident owner and reviewer; approve IAM/key recovery |
| REC-04 | Exact hosted operation | Name source and isolated destination/region, backup time, export/restore route, credential re-establishment scope, spend/lifetime and cleanup; prohibit in-place operations |
| REC-05 | External execution and identity | Approve the extension/job inventory and containment route, Auth UUID/config/root-key handling, controlled recipients and isolated endpoints |
| REC-06 | Measured acceptance | Named operator/reviewer signs actual archive custody/decryption, expiry, source preservation, restore/retry/isolation results and measured RPO/RTO |

These are open decisions, not requests to perform a purchase now. Production
deletion-ledger implementation/qualification and physical mobile backup/secure
storage remain separate roadmap/device gates. Session 4 should carry these exact
boundaries forward without marking Phase 0 or hosted recovery complete.
