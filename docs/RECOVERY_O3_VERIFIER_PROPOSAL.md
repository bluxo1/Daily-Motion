# O3 trusted verifier and certificate: recommended design for review

2026-10-22, revision 3 after advisory technical review. **PROPOSED / UNAPPROVED.** Backend and security acceptance,
followed by explicit implementation authorization, are required before B4/B5.
This is a local review package, not an accepted ADR or an implemented certifier.
Phase 0 is in progress; Phase 1 has not started.

Baseline: signed main `3935d5186a8797693413379271b97df614666102`, squash merge of
PR #11, tree `f5fe7067535b14fe2df04e5f80982a9bb9129085`, matching reviewed `266e164`.
The [first O3 sketch](https://github.com/bluxo1/Daily-Motion/blob/3935d5186a8797693413379271b97df614666102/docs/RECOVERY_O3_VERIFIER_PROPOSAL.md),
[proposed protocol](RECOVERY_PROTOCOL_V2_SPEC.md),
[proposed ADR](ADR_RECOVERY_PROTOCOL_V2_PROPOSED.md) and
[historical characterization](RESTORE_TIMELINE_INVESTIGATION.md) remain historical
references. This revision recommends choices; it does not approve them or amend
the proposed protocol silently.

Read this document with the [exact record/interface proposal](RECOVERY_O3_RECORDS_PROPOSED.md),
[fault-test and implementation acceptance plan](RECOVERY_O3_ACCEPTANCE_PLAN.md),
and [local evidence and limits](evidence/recovery-o3-design-review-2026-10-22.json).
That receipt preserves revision 2's hashes and executed evidence; it is not
rewritten for this revision. The [advisory findings and D1-D11 decision record](RECOVERY_O3_TECHNICAL_REVIEW.md)
and its separate receipt record the subsequent corrections. No required approval
is inferred from either package.

## Recommended decision

Use a separately authorized verifier process from the same codebase, an online
authenticated authority record, and a separate guarded publication transaction.
Trust the existing B3 atomic transaction only on an independently verified
original target with unchanged continuity. Keep authority operations outside
database transactions. Require authority-internal atomicity for activation state,
owner head, certificate/idempotency entry and erasure high-water. Do not claim an
atomic transaction between PostgreSQL and the independent authority.

Prefer workload identity over shared application secrets, and a strict JSON
record retrieved over authenticated TLS over a new self-contained signed token.
The record's digest binds content; a fresh authenticated authority view establishes
currentness and inclusion. Neither one establishes database continuity. If the
platform cannot supply the continuity contract below, keep the path unavailable;
do not substitute SQL fingerprints, flags, clocks or an unqualified WAL witness.

## Critical review of the first sketch

| Finding | Local basis | Consequence for the recommended design |
| --- | --- | --- |
| A SELECT-only verifier cannot take the helper's row locks | Real PostgreSQL 17.11 probe: SQLSTATE 42501. READ ONLY transaction also refuses locking, 25006 | Use narrowly granted column UPDATE plus restrictive RLS; call this a role with denied DML, not a read-only transaction |
| A permissive denial policy is insufficient | The existing PUBLIC owner policy ORs with a new permissive false check; the probe's no-op UPDATE succeeds | A verifier-specific UPDATE policy must be RESTRICTIVE, with WITH CHECK false, and role membership must not permit escaping it |
| Ordinary admission cannot validate B5's next checkpoint | Existing validate_admission requires exact head equality; the probe denies local PREPARED versus authority CERTIFIED | Define a purpose-specific publication transition proof, including the possible UNRESOLVED event; do not weaken normal admission |
| Appending transport fields changes existing hashes | Probe adding a nonce to the CERTIFIED event changes the checkpoint digest | Preserve the current marker/event preimage and put authentication/target bindings in a separately versioned record envelope |
| Known-marker observation has narrower authority than its prospective caller | recovery_observation.py requires ACTIVE/OPEN, active existing owner, known marker and exact PREPARED head; it does not authenticate Admission or an Engine | CLOSED settlement, unknown-marker lookup, lifecycle purposes and connection binding need separately reviewed interfaces |
| Cleanup is supported only at certain local states | Migration 0004 permits clearing frozen_request at PUBLISHED/NOT_COMMITTED; it does not permit certified-but-held cleanup. PUBLISHED currently requires marker/result, but not a certificate | B5 can use the existing terminal cleanup shape, but needs certificate constraints/validation. CLOSED cleanup needs an additive reviewed design; no existing migration is edited |

The probe has **25 checks matching expectations: 20 SQL checks and five existing
reducer checks**, zero skipped checks, and confirmed owned-cluster cleanup. Some
checks deliberately reproduce unsafe controls; matching an expected unsafe
control is not evidence of a secure deployment. It does not run or qualify B4/B5.
The [reproducible probe](experiments/recovery_o3_local_probe.py) and receipt retain
that distinction.

## Trust assumptions and authorization

The proposed certificate witnesses a specific committed B3 result, not the
correctness of arbitrary SQL or completeness of a payload backup. It assumes
trusted B3/domain code, scoped operators and an honest authenticated authority.
The helper does not independently audit every nondelete child/observation value
or independently reconstruct the pre-delete child inventory. Deletion checks
verify the listed retirements and consistent suppression, but complete scope
still depends on trusted B3 enumeration. The advisory probe deliberately rewrites
both marker and redacted feed under a disposable administrator: an omitted child
then goes undetected. That excluded whole-binding corruption is an assurance
limit, not a demonstrated exploit by the restricted reader. Backend/security
must accept B3's completeness trust or require a different independent witness.
An application writer capable of fabricating all matching database rows, a
compromised verifier or a malicious database/authority administrator is not
defeated by a hash or separate credential. Backend/security must explicitly accept
this trust model, or require a different independently durable commit witness.

Run the verifier in a distinct process/workload security context. Reusing the
application binary is appropriate; giving the API access to the verifier identity
or its impersonation/deployment permission is not. The recommended authentication
is short-lived workload JWTs over server-authenticated TLS, with an allowlisted
issuer/JWKS, audience, algorithms and subject mapped by the authority to the
verifier role. Bind subject to an operator-approved deployment/manifest registry;
a JWT subject alone does not attest a code image. Reject caller-selected key URLs
and role names. These JWT validation rules follow
[RFC 8725](https://datatracker.ietf.org/doc/html/rfc8725); the actual workload
issuer, federation and revocation route remain platform decisions.

Use an explicit verifier audience/subject policy distinct from mobile/API token
acceptance, validate expiry/not-before, and consult current authorization policy
on every append/lookup. A signature-valid cached JWT/JWKS is not proof that a
subject still has verifier permission. Order revocation versus append through
the authority's authorization decision; an already authorized append is not
retroactively erased. The actual enforcement and revocation bound need D1 review.

An API/scheduler may provide an opaque attempt hint. The verifier obtains owner,
E/A/I/G, T/M/D and the permitted purpose from authenticated PREPARED inventory,
never from that hint or a mobile JWT alone. It selects its own approved connection
binding; requests cannot supply an Engine, DSN, callback URL, SQL or arbitrary
owner. Authority authorization checks environment, activation, attempt and purpose
on every operation. A certificate reference is not a bearer authorization grant.

| Principal | Database permission | Authority permission |
| --- | --- | --- |
| Effect runtime | Reviewed B1/B3 writes under owner/fence guards; no activation DDL | Prepare and exact scoped lookup; cannot submit verifier evidence or activate/seal |
| Commit verifier | Explicit SELECT grants needed for observation; lock privileges on three guard tables; DML denied as below | Read assigned PREPARED scope and fresh views; submit matching commit evidence for that scope only |
| Publisher process | Reviewed B5 metadata/receipt/cleanup updates, no second domain effect | Read exact certificate and fresh publication view; no certification or activation |
| Authority root publisher | Independent authority journal only, no application SQL | Advance the external root anchor by exact successor CAS; no reset/delete or activation privilege |
| Activation operator | Separate migration/operator identity; exclusive close/activation under approved procedure | Close/seal/activate, with inventory and containment acceptance |
| Erasure/reconciliation worker | Purpose-specific cleanup under owner guards, including genuine denying lifecycle state | Only reviewed lifecycle/settlement scope; no ordinary payload publication |
| Custodian | No ordinary application SQL | Separate recovery/encryption custody and controlled emergency access; no routine application credential |

The identities and permissions are recommendations, not configured accounts.
Existing effect-runtime grants are broader than this desired separation. Future
grant changes need a reviewed successor migration and compatibility tests.

## Database role that can lock but cannot change rows

Retain non-owner/NOBYPASSRLS, no role/schema creation, no privileged membership,
forced owner RLS and transaction-local tenant context. Grant SELECT only on the
tables/columns observation needs. With the current helper this includes frozen
request/feed payloads transiently in process memory; no plaintext payload enters
the authority, logs, traces or error bodies. This is not a metadata-only database
reader. Do not grant profiles or unrelated future tables by wildcard.

For owner_state, recovery_owners and recovery_attempts, recommend UPDATE on the
owner_id column solely to satisfy locking permissions, paired with a
verifier-specific RESTRICTIVE UPDATE policy whose USING preserves owner scope
and whose WITH CHECK is false. The following is a design specimen, not a migration:

```sql
GRANT SELECT ON training.owner_state TO dm_commit_verifier;
GRANT UPDATE(owner_id) ON training.owner_state TO dm_commit_verifier;
CREATE POLICY verifier_denies_dml ON training.owner_state
  AS RESTRICTIVE FOR UPDATE TO dm_commit_verifier
  USING (owner_id = nullif(current_setting('app.owner_id', true), '')::uuid)
  WITH CHECK (false);
```

Apply the equivalent policy to the other two locked tables, with no INSERT,
DELETE, TRUNCATE, DDL, control mutation, role switching or unsafe function grants.
The SQL probe demonstrates this mechanism on those three real migrated tables,
including contention with an actual owner writer and lock release. It does not
qualify a complete production role or hosted pooling setup. PostgreSQL documents
the [locking privilege](https://www.postgresql.org/docs/17/ddl-priv.html) and
[policy combination rules](https://www.postgresql.org/docs/17/sql-createpolicy.html).

RLS's GUC is context, not authenticated identity: the same login can set another
owner context, as the positive control demonstrates. Verified request routing and
trusted verifier code must supply it. This design does not promise isolation
after theft of the verifier's SQL credential. Reset context on transaction end;
validate effective grants/membership/forced RLS every transaction. The existing
assert_runtime_role guard is useful but does not enforce this entire role plan.
database_readiness requires broad CRUD and must not be reused as verifier
readiness. Use an explicit verifier grant/policy allowlist after review.

For the current helper, the advisory role experiment additionally exercises all
five existing outcome branches with SELECT on owner_state, account_retirements,
workouts, receipts, changes, recovery_owners and recovery_attempts; column SELECT
on exercises/sets/retired_ids (owner_id,id), observations (owner_id,session_id),
snapshots (owner_id,id), and SELECT on recovery.control. Only the three guard
tables have UPDATE(owner_id) with restrictive denial. Profiles and the other
listed payload columns remain denied. This is a local query-compatibility result,
not qualified IAM, role-drift detection, lifecycle/settlement or hosted pooling.

## Original target and unchanged continuity

Require an independently maintained TargetBinding record with E/A/I, immutable
provider/project/database resource identities, approved routing/role/manifest and
a continuity revision. Its history and current authorization must survive the
application's restore. Every permitted restore, rewind, target replacement or
ancestry-changing failover must first revoke ordinary access, fence/contain the
old source, and establish a new I/G and continuity binding through activation.
An ordinary process restart is resumable only when that lifecycle contract still
proves the original target unchanged.

Bind evidence to the **actual physical connection checked out for observation**,
not a DSN verified before a pool chooses/reconnects elsewhere. A future verified
session factory must authenticate the endpoint and independently bind that
connection to the registered resource/continuity revision before beginning the
observation transaction. Invalidate pooled connections on binding change. A
pooler/proxy that can retarget sessions needs an equivalent qualified guarantee.
External identity/provider calls occur with no database transaction or lock open.

The binding must cover the whole observation transaction, not merely a fresh
preflight. A qualifying lifecycle mechanism must revoke/drain the relevant
connections and fence writes before changing ancestry, or provide an equivalent
connection-bound guarantee valid through transaction close. A point-in-time
resource read followed by an uncoordinated restore leaves a check/use race and
does not qualify. No such platform mechanism has been demonstrated locally.

| Evidence | Role in this design |
| --- | --- |
| Copied control row, E/I/G, database name, configured hostname | Compare local consistency only; not an independent target identity |
| TLS verify-full | Authenticates CA/hostname; does not prove database ancestry or no rewind. This is an inference from the documented [TLS guarantee](https://www.postgresql.org/docs/17/libpq-ssl.html) |
| SQL system identifier, timeline, LSN, transaction ID, startup time | Diagnostics/corroboration only; XID and advancing WAL can accompany rollback, as executed locally |
| Fresh authenticated resource/lifecycle binding and enforced containment | Recommended trust root, conditional on an actual platform's enforceable guarantees and connection binding |
| Independently durable commit/WAL witness | Alternative requiring a different proof, custody and failure-domain review; not selected or supplied here |

O2 remains blocking: no selected platform proof is available in this package.
An eventually delivered audit event, self-reported image hash or an operator's
unchecked flag does not satisfy the contract. Unknown reconnect/continuity,
contradiction or inaccessible original evidence keeps the owner held and recovery
closed. No universal automatic rollback detection is claimed.

## Record, freshness and ordering

Recommend CertificateRecordV1 and a separate nonce-bound CurrentAuthorityViewV1
as defined in [the record proposal](RECOVERY_O3_RECORDS_PROPOSED.md). Preserve the
current `CERTIFIED + marker.metadata()` event and checkpoint calculation. Put
activation/continuity and first-observation provenance in an authenticated,
versioned envelope. Use a content digest for its identifier, not as a signature.
Retrieve the immutable record by the original E/owner/T/M/D after response loss.
An exact repeat returns the first record, even when the retry has a new challenge
or verifier credential; changed core evidence is a contradiction.

Freshness comes from a linearizable authenticated current authority read, bound
to a new request nonce, E/A/I, owner, purpose, current head, H, lifecycle state and
exact certificate lookup/inclusion. No stale-cache fallback is permitted. A nonce
does not repair a rolled-back authority: its latest head/inventory must be
independently protected from rollback under O1. Neither a signature on an old
record nor locally restored maximum Q proves completeness.

The authority must serialize activation changes with certificate append, owner
head CAS, H and the idempotency record in **one authority-internal atomic operation**.
Per-object CAS alone is insufficient if checking ACTIVE/CLOSING and appending
can race sealing. O1 must demonstrate this using a transactional store or a
qualified equivalent sequencer/root CAS; no provider is assumed to support it.

### Concrete candidate for O1 freshness/completeness

Recommend an independent transactional authority store plus a separately
administered monotonic root anchor. This is a proposed contract, not a selected
or qualified service. A certificate writer has no anchor-reset permission;
verifiers/publishers can read the anchor but cannot advance it. A distinct
authority root-publisher identity can compare-and-advance only. O1 must establish
that application/authority restore cannot also rewind that anchor.

Within the authority transaction, serialize activation/seal changes and owner
CAS, check E/owner/T/M uniqueness, store the first certificate, clear its pending
attempt, update Q/H, and commit one new environment root with complete inventory
bindings. Permit at most one unanchored environment revision. The root publisher
closes that transaction, then compare-and-advances the external anchor by exactly
one revision using the durable journal. No network call holds SQL locks.
Only an independently authenticated anchor match makes the new root usable for
ordinary admission/publication or an acknowledged certificate append. An exact
retry can find a durably stored but unanchored certificate; it is still pending,
not a successful B4 response.

| Failure window | Required behavior |
| --- | --- |
| Authority commit before anchor advance | Close ordinary work; retry the same journal/root CAS after verifying its predecessor, without a second certificate |
| Anchor advance before response or local confirmation | Exact authenticated anchor/root match recovers the same result; confirmation loss does not append another root |
| Authority restored behind anchor | Mismatch closes work, including a new worker with no local history; no anchor reset or primary-receipt fallback |
| Concurrent root change during fresh reads | Require an exact snapshot-root/anchor match or bounded retry; larger revision alone is not membership/completeness proof |
| Missing journal, contradictory root or unavailable anchor | Remain closed; authority recovery procedure and custody are still required O1 decisions |

The [record proposal](RECOVERY_O3_RECORDS_PROPOSED.md#authority-root-and-independent-anchor-contract)
defines the root/anchor binding. This deliberately serializes environment-wide
authority mutations; throughput/availability and cost need storage/operator
review. A later sharded or batched scheme requires another completeness proof.
No local database, ordinary object-store version list or cached maximum is
claimed to supply this monotonic service. RC10 must qualify the actual failure
domains and latest-head recovery, under separate authorization.

```mermaid
sequenceDiagram
    participant V as Authorized verifier
    participant D as Original PostgreSQL
    participant A as Independent authority
    participant R as Independent monotonic anchor
    participant P as Authorized publisher
    V->>A: Fresh scoped preparation and target binding
    V->>R: Fresh root match for authority view
    V->>D: Tx-OBSERVE: shared fence, fresh owner/attempt checks
    D-->>V: Existing committed marker; transaction closes
    V->>A: Authenticated append with expected head
    A->>R: Root publisher CAS after authority transaction closes
    A-->>V: Immutable certificate or uncertainty
    V->>R: Independently verify root before usable append success
    P->>A: Fresh publication view and exact certificate
    P->>R: Fresh root match before Tx-PUBLISH
    P->>D: Tx-PUBLISH: fresh fence/owner checks, exact transition proof
    D-->>P: Atomic V/H/receipt/anchor/cleanup/hold commit
```

B5 must require the certificate's original context and matching private effect.
For first publication, validate the exact PREPARED-to-CERTIFIED extension, or
PREPARED-to-UNRESOLVED-to-CERTIFIED extension for the same T, rather than accepting
an arbitrary higher Q. Only then atomically advance the local evidence anchor,
V/H, bind the receipt/certificate, purge the frozen request and clear the hold.
Conflicts/rejections have no feed event: V remains P, but their certificate and
anchor still publish atomically. There is no second domain/revision change.

Published duplicate handling is different: after later commands, the old
certificate need not be the current head. Verify its authenticated inclusion,
the already-published local receipt, current owner/activation/head and no hold;
return original context without advancing anything. Older-incarnation lookup is
historical-only and cannot acknowledge a new working branch.

## Failure and closure rules

Known-commit settlement needs a purpose-specific observation validator as well
as B5's publication validator. If the authority records UNRESOLVED(T), its head
advances beyond local PREPARED. The current observe_committed then correctly
refuses the unequal heads, even on ACTIVE/OPEN. Never forge a PREPARED-head
Assertion to get past that refusal. The proposed workout_settle path must verify
the exact same-intent extension, original target and immutable committed/private
evidence; it cannot rerun B3 or treat an UNRESOLVED flag as commit proof. See the
[observation matrix](RECOVERY_O3_RECORDS_PROPOSED.md#observation-head-and-state-matrix).
This new observer remains unimplemented and requires backend/security review.

| Boundary or race | Required disposition |
| --- | --- |
| B3 commit/response loss | Re-observe the same known T/M/D on the verified original target; never reapply because a restored receipt is absent |
| Observer timeout/crash/denial | No certificate or publication; hold remains. Deadline bounds work, not commit uncertainty |
| Authority UNRESOLVED head with local committed marker | Current helper denies; only a reviewed same-intent settlement observer may supply B4 evidence. No synthesized head or automatic B3 replay |
| Certificate append/response loss | Exact lookup first, then idempotent same-core append if still permitted; no new T or duplicate event |
| CLOSING before preparation | No new PREPARED. Existing preparations may settle with scoped proof |
| CLOSED original target | A new purpose-specific observer may settle an existing preparation after review; the current helper still refuses this path |
| SEALED versus append | Authority-internal ordering allows either append before seal, included in its complete inventory, or rejection after seal. Existing exact retrieval remains allowed |
| Close/new activation between observation and B5 | Preserve historical certificate; deny current publication on CLOSED or different E/A/I/G |
| First B5 rollback | All publication metadata/receipt/cleanup/hold changes roll back together; same certificate remains retryable |
| B5 response loss after commit | Already-published exact path returns original result under current publication guards; never repeat the effect |
| Original evidence unavailable, authority gap/loss or conflicting marker | UNRESOLVED, held owner, no timeout-based abort; do not seal/open another target with unresolved coverage |

One concurrency interpretation needs explicit backend/security acceptance:
an ACTIVE view fetched before the authority moves to CLOSING can reach B5 before
the exclusive database close commits. The recommended authorization is the fresh
ACTIVE read plus the shared database fence; the exclusive CLOSED commit is the
cutoff. CLOSING stops new preparations, but does not retroactively cancel an
already obtained view. This is not a claim that authority ACTIVE and PostgreSQL
commit are sampled atomically. If reviewers require ACTIVE at the exact commit
instant across stores, this design is insufficient and a different mechanism is
required. The original proposed specification is unchanged pending that decision.

## Lifecycle, deletion, retention and custody

Normal workout observation continues to require an active existing account.
Initialization, disable and account retirement require separate purpose/record
variants: current Intent requires a workout root, and the helper cannot witness
a transition to deleting. Do not invent a dummy workout/feed entry or allow a
normal-workout certificate to authorize lifecycle denial. These variants remain
blocked by O5 and are required before complete-protocol activation.

Genuine disable must immediately deny ordinary server work under the owner guard.
A pending uncertified transition must produce safe recovery/pending denial before
any client-visible erasure instruction. Only policy-permitted, certified,
owner-bound lifecycle evidence can drive that instruction. Maintenance never
manufactures account_inactive. Old account denials must survive archive absence;
initialization requires independent history/retirement checks.

Workout deletion certificates bind the complete retired root/child scope and
epoch; verify purge of live/history/feed/snapshots and suppression of later jobs
before reopening. Completeness relies on trusted B3 enumeration as stated above;
checking absence of listed rows alone cannot establish that no child was omitted.
Reconstruct certified retirements even if B5 never completed.
PREPARED metadata alone never authorizes recovery purge or client erasure.
This does not prevent the guarded B3 deletion transaction itself. Certificate metadata cannot
replace missing workout payload or an approved RPO.

| Data | Recommended handling, subject to security/privacy acceptance |
| --- | --- |
| Frozen request | Primary owner-private DB only; no independent payload backup/logging. Purge atomically at B5 using existing nullable terminal shape |
| Certified but CLOSED/held request | Recommend a new reviewed CERTIFIED_HELD cleanup state: validate/store the authentic certificate and purge only the body, retaining marker/result/hold and leaving V/H unchanged. Current 0004 does not support this cleanup state; successor migration and compatibility tests required |
| Unresolved request reaching erasure deadline | Escalate before the accepted seven-day live-payload purge target. No indefinite raw-payload exception or destruction of needed evidence is approved; O5 must decide a minimal-proof cleanup/retention procedure |
| Minimal certificates/retired IDs | Owner lifetime under current policy; account-retirement lifetime, offline replay horizon and lawful minimization need O5. Never silently expire them when backups expire |
| Backups and logs | Existing ceilings remain: backup expiry within 35 days, ordinary redacted operational logs 30 days. No provider expiry verification is supplied here |
| Credentials and keys | Managed workload credentials and TLS trust; separate authority encryption/recovery custody from application/backup keys. No client authority secret or new application signing key is recommended |

CERTIFIED_HELD is a cleanup proposal, not authority to publish while CLOSED.
It would also require a minimal stored preparation anchor, since current
Reservation.restore reads it from frozen_request. Add a PUBLISHED-requires-
certificate constraint and immutable certificate binding in a successor migration;
do not reinterpret the present schema as already enforcing cryptographic validity.

Plan rotation/revocation of workload identities and authority trust keys, retain
necessary public key/version and approval references under O5, and qualify
encryption-key loss/restore using an independent custodian. With online records,
old certificates need no permanent client signing secret: the current authority
authenticates retrieval. Loss of authority trust/head/encryption access keeps
cloud recovery closed. Provider/KMS choice, region, costs and custody owners are
unresolved; none is purchased, configured or qualified by this recommendation.

## Decision matrix and reviewer handoff

Every row remains **unapproved**. Local evidence resolves mechanisms and gaps;
it does not grant the named technical or operator acceptance.

| ID | Recommended choice versus alternative | Evidence/uncertainty | Required reviewer and gate |
| --- | --- | --- | --- |
| D1 | Separate verifier workload identity and process, no API impersonation, rather than a shared secret | Trust assumption; exact federation/deployment controls unqualified | Backend + security; O3 implementation |
| D2 | Column lock grants plus restrictive WITH CHECK false, rather than broad UPDATE or SELECT-only | 20 SQL checks support mechanism on three tables; full grants/readiness still to test | Backend + security; role/migration acceptance |
| D3 | Enforced resource/lifecycle registry bound to each physical connection; fail closed if unavailable | No actual platform attestation/continuity route selected | Operator/platform + security; O2, production implementation acceptance |
| D4 | Online authenticated strict-JSON certificate record plus fresh authority view, rather than a new signed bearer token | Existing hashes/lookup semantics support shape; no real authority qualified | Backend + security + storage; O1/O3 |
| D5 | Preserve marker/event hashes; version the outer envelope and purpose-specific publication validator | Five reducer checks expose exact head transition and hash compatibility | Backend + security; schema/contract acceptance |
| D6 | Transactional authority with one unanchored root and a separate monotonic anchor; exact root match before usable success | Proposed contract/crash ordering, no platform qualified; per-object CAS or cached maximum insufficient | Storage engineer + security + operator; O1/RC10 and throughput/custody |
| D7 | Shared-fence cutoff with fresh ACTIVE view; no cross-store simultaneous-state claim | Concurrency interpretation above needs explicit acceptance | Backend + security + recovery operator; O3/fence semantics |
| D8 | Exact retries and indefinite safe closure without commit/abort proof | Existing reducer/observation behavior; original-source-loss resolver unavailable | Recovery owner + security; O4 |
| D9 | Distinct lifecycle variants and certified-held cleanup; no dummy root or indefinite plaintext retention | 0004 inspection; retention/lifecycle proof unqualified | Privacy/security + backend + product; O5 |
| D10 | Candidate 1 MiB complete-body cap, depth 16 and bounded references; never truncate. New variants need sizing/coverage review | Present DTO ceiling is 5,051 IDs; compact publication-view shape 399,365 bytes. Shape measurement is not parser/crypto qualification; lifecycle scope remains open | Backend + product + security; complete variant/decoder coverage |
| D11 | Managed encryption/custody and current authenticated retrieval, no new client-held authority signing key | Custody, rotation, pricing and unavailable-key drills not qualified | Operator/custodian + privacy/security + billing; O9/O10/RC11 |

Required sign-off record: named reviewer, decision IDs, accepted threat/continuity
assumptions, requested amendments, source/proposal hashes, validation evidence and
scope of any subsequent implementation authorization. Backend, security,
platform/storage, privacy/product and custodian/operator reviewers are currently
**unassigned; acceptance pending**. Advisory automated review is not O3 or O11
approval; the previously unavailable independent security review is not retried.

After required review and authorization, implement the acceptance plan in small
stages: strict records/fixtures and scoped permissions; authenticated target and
authority adapters; B4 observation/append with recovery cases; B5/cleanup plus all
publication gates and generated contracts. These are future implementation
steps. The local package adds no B4/B5 runtime, migration, public route or provider
configuration. RC10/RC11 remain NOT EXECUTED, physical samples remain zero, and
the full PG/SQ/RC and Phase 0 exit gates remain open.
