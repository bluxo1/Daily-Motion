# O3 deterministic fault tests and implementation acceptance

2026-10-22. **PROPOSED / UNAPPROVED. Future implementation plan.** None of the
36 cases below is claimed as newly implemented or executed. The separate
[local design probe](experiments/recovery_o3_local_probe.py) executed 25 bounded
permission/reducer checks; these do not qualify a trusted certifier, B5, a provider
or any additional complete PG/SQ/RC case. Phase 0 remains in progress.

Use this with the [recommended design and decision matrix](RECOVERY_O3_VERIFIER_PROPOSAL.md)
and [record definitions](RECOVERY_O3_RECORDS_PROPOSED.md). The original
[proposed protocol](RECOVERY_PROTOCOL_V2_SPEC.md#12-exact-defensive-test-definitions-not-implemented-or-run)
remains the acceptance authority; this plan gives O3 implementation oracles and
does not replace its larger matrix.

The [advisory review](RECOVERY_O3_TECHNICAL_REVIEW.md) audits every case family
and records corrections and additional deterministic subcases. The separate
component/runner experiments do not execute these future B4/B5 acceptance cases.

## Implementation gates and scope

| Gate | Required input and reviewable output | Acceptance / authority |
| --- | --- | --- |
| G0: design review | Named backend/security decisions D1-D11, explicit trust/fence interpretation, platform/storage continuity and atomicity answers, privacy lifecycle/cleanup direction | Required review record plus explicit user authorization before B4/B5 implementation. This package is ready for that review, not accepted |
| G1: records and grants | Strict proposed records/golden fixtures; additive successor schema and explicit verifier/publisher grants/readiness; preserve populated 0004 rows and old command/receipt bytes | Backend/security review; V01-V04 and R01/R02 contract/grant prerequisites. P01/P02/P04/L05 remain deferred until their runtime stages exist; do not count them passed at G1. No public activation |
| G2: authenticated adapters | Selected workload authentication, target session factory, authority atomic API and current-head/inventory contract | Platform/storage/security evidence; V07-V10, R03-R08, K01/K02. Local fakes establish control flow only |
| G3: B4 | Purpose-scoped committed observation, closed-session append, exact retry/lookup, bounded uncertainty. Normal ACTIVE/OPEN first; CLOSED settlement requires its own reviewed path | Backend/security authorization; V05/V06, R03-R06, P06 and lifecycle prerequisites. Never bypass current helper denials with flags |
| G4: B5 and publication barrier | Exact transition validator, atomic receipt/anchor/V/H/body/hold updates, already-published retry, every ordinary publication path; generated contracts/client installation tests | Backend/mobile/security review; P01-P08, L01-L06, S01/S02, mapped PG/SQ regressions. No activation from passing local tests |
| G5: operational qualification | Complete inventory, independent storage/head durability, containment, key/retention/RPO decisions, compatibility and full named protocol suite | O1-O12 and operator acceptance; RC10/RC11 remain NOT EXECUTED until separately authorized. Hosted drill/deploy/provider actions need further exact-scope permission |

No stage grants permission to perform itself. An unavailable platform proof or
privacy decision is an explicit blocker, not an invitation to implement a local
boolean/certificate stub and call it trusted. Keep proposed specifications/ADRs
proposed until the required review process changes their status.

## Harness and evidence rules

Use new owned disposable PostgreSQL clusters and real restricted LOGIN roles,
not administrator SET ROLE alone. Reuse the existing safe lab's loopback binding,
environment scrubbing, generated resource identities and verified cleanup.
Inspect actual pg_locks/pg_stat_activity/NOWAIT conflicts to establish waits;
thread events or test hooks order fault boundaries. Sleeps may bound polling,
but are not proof that a transaction waited or committed. Use separate engines
for effect, verifier, publisher and operator.

For authority faults, use a local adapter with durable test state and explicit
barriers at before-append, after-durable-append/before-response, before-current-
read and before-seal. It implements the reviewed contract only after G0 and
authorization. It is not a qualified provider. Actual provider atomicity, IAM,
latest-head durability and key custody need separately authorized external
evidence; missing external cases never become local passes.

After every fault/restart assert normalized rows/revisions, marker/result and
receipt digests, P/V/H, local/independent evidence anchors, hold/T, frozen request,
retired scope, snapshots/observations and authority certificate count. Scan
responses/logs for private payload and secrets without echoing matches. Reopen
file-backed authority/SQLite state where persistence is part of the oracle.
No test response may be acknowledged as cloud success before B5 commits.

## Proposed exact case inventory

All rows have status **NOT IMPLEMENTED / NOT EXECUTED by this package**.
`PG` means real disposable PostgreSQL; `AUTH` means deterministic local authority
or identity adapter; `EXT` means a separately qualified platform/provider route.
An EXT requirement cannot be closed by its AUTH counterpart.

| ID | Arrangement / deterministic boundary | Required oracle and scope |
| --- | --- | --- |
| V01 identity/purpose | Valid verifier versus mobile/API token, wrong issuer/audience/algorithm/expiry/not-before; revoke subject policy before/after append barrier; replay challenge for another owner/T/purpose | Only mapped currently authorized verifier submits; denial precedes owner-private reads and head/certificate changes. Explicit append/revocation ordering, not JWT-cache revocation assumptions. AUTH then EXT IAM; PG17 |
| V02 tenant routing | Authenticated B requests A's T; reuse pooled connection after A; forged owner in hint | Reject before private A reads; SET LOCAL resets; another login's ability to set a GUC is not mistaken for verified identity. PG/AUTH; PG17 |
| V03 complete verifier grants | Execute every SQL query used by the future observer under the actual restricted login; attack UPDATE/INSERT/DELETE/TRUNCATE, schema/control writes and privileged membership | Only specified reads/locks work; no application DML. Removing restrictive policy or granting an escape role fails verifier readiness. PG; PG16/17 |
| V04 owner/fence waits | Hold owner row or exclusive recovery lock, preload stale state, then release after deletion/close/context change | Prove real lock wait; fresh READ COMMITTED reread denies stale state. Unsupported isolation/borrowed session denied. PG; PG04/05/19 |
| V05 no I/O under locks | Instrument engine transactions and fake authority HTTP at each observation/append/lookup boundary; force callback while a transaction is open | External operation refuses to run under DB/SQLite transaction; no hold clearance. After return/timeout competing exclusive lock succeeds. PG/AUTH |
| V06 actual commit/rollback | Produce known marker in uncommitted B3, start observer, then commit or rollback; repeat after process loss | Commit path observes persisted marker; rollback never creates certificate, consumes a second mutation or reapplies historical work. PG/AUTH; PG10/15 |
| V07 actual connection binding | Trusted registry names target A, factory checks out B or a different database behind the same proxy/hostname | Reject before observation/effect/publication; Engine URL/control row alone cannot pass. AUTH contract test plus EXT broker/channel proof; PG06/16, RC03/09 |
| V08 copied identity | Copy control/E/I/G/marker into a second disposable target, with plausible SQL diagnostics; present no valid independent binding | Neither copied metadata nor equal SQL fingerprint authenticates target continuity. PG/AUTH, with EXT lifecycle evidence required; PG06, RC01/03 |
| V09 reconnect/epoch change | Invalidate binding between verification/checkout and during observation; attempt ancestry change while its connection is active; reconnect pool after revision changes | Old factory/ticket refused; lifecycle change revokes/drains and fences before rewind, or meets its reviewed equivalent guarantee. No point-in-time DSN check/cached assertion passes. AUTH/PG and EXT; RC01/09 |
| V10 unknown original evidence | Original target unavailable or continuity unknown after PREPARED/commit response loss; restored receipt absent | Remain UNRESOLVED/held, no B3 automatic replay or inferred abort, seal/open blocked. AUTH/PG; PG07/15, RC08/12 |
| R01 exact encoding/hash | Golden core/envelope fixtures, Counter 0/1/2^53+1/MAX and overflow, bool/float/exponent, duplicate JSON keys/IDs, altered timestamp spelling, unknown fields/versions | Preserve exact current marker/result/event digests; strict new parser denies ambiguity/overflow. No nonce/provenance inserted into old core event. AUTH/fixture parity; PG20 |
| R02 conflicting identity | Reuse M with changed D, T with changed result/epoch/target, and same certificate_id with altered record | Denial without replacing first record or head; sanitized error only. AUTH/PG; PG08/09 |
| R03 concurrent certification | Two verifier processes submit same T/core at a barrier; separately submit different attempts for one held owner and a legitimate other owner; pause environment root anchoring | One certificate/event/H advance for exact T; conflicting owner attempt refused. With anchor progressing, other owner makes correct progress; while a root is unanchored the chosen environment-wide barrier intentionally pauses both. AUTH/PG; PG17 |
| R04 append response loss | Drop request before durable append, after durable append/before anchor, and after anchor/before response; restart with new nonce/credential; query by owner/M/D with T/ID unknown | Complete absence is certificate=null/absent with same preparation held; unanchored is pending. Existing anchored record returns first ID/provenance. Retry same T/core only; no extra Q/H/feed/revision, invented abort or new attempt. Durable AUTH; PG07/15 |
| R05 seal/append order | Pause new append immediately before atomic authority commit; race seal in both orders; retrieve an existing certificate after SEALED | Either append precedes seal and is included in complete inventory, or append denied. Existing authorized lookup still returns original. AUTH plus EXT atomicity; RC01/02 |
| R06 CLOSING preparation | Move ACTIVE to CLOSING before new PREPARED and before exact existing-attempt settlement | New preparation denied; existing exact settlement permitted by purpose, no ordinary publication from a CLOSING view. AUTH; PG15, RC01 |
| R07 authority rollback/prefix | Older/truncated authority prefix with fresh nonce on a new worker; crash before/after monotonic anchor CAS; race the next root | Snapshot-root/independently read anchor must match. Unanchored commit stays pending and blocks next mutation; CAS/response retry reuses same root/certificate. Restored store behind anchor or missing journal stays closed, never Q=0/anchor reset. AUTH controls plus EXT O1 witness; RC02/03/10 |
| R08 inventory absence/gap | Drop owner inventory, omit an unresolved T, introduce equal-order different digest or larger unrelated head | No inferred new owner, seal, activation or publication; preserve local pending bytes. AUTH/PG; PG18/22, RC02/08 |
| P01 first direct publication | Local anchor Qp/hold T, authority certificate Qc=append(Qp,CERTIFIED); fresh current view equals Qc | Purpose-specific validator accepts exact transition; normal admission still rejects unequal heads. One atomic publication and no domain/revision effect. PG/AUTH; PG10-13 |
| P02 unresolved extension | Real committed marker/local Qp, then authority appends UNRESOLVED(T); exercise ACTIVE/OPEN and CLOSING/CLOSED separately, then settle and publish only eligible ACTIVE/OPEN context; also altered T/intermediate event | Current helper must refuse unequal heads. Future purpose-specific observer and publisher each require their exact transition proof. No synthesized PREPARED assertion, arbitrary higher-Q repair, B3 replay or local_open flag bypass. PG/AUTH; PG15 |
| P03 binding/erasure tamper | Independently alter owner/E/A/I/G/T/M/D, target/manifest/continuity, marker/result, feed/private position, H/epoch or retired-ID completeness | No B5 writes; hold/body/receipt preserved; no certificate from a caller-constructed object. PG/AUTH; PG09/17, RC04-06 |
| P04 every B5 write fault | Inject failure after each anchor/certificate/V/H/receipt/body/hold/state statement and before commit; reopen | Entire before-image survives each rollback, including body/hold. Same certificate retry publishes once; B3 is never called. PG |
| P05 published response loss | Commit B5, lose response, publish later legitimate owner command, then retry old M; also change incarnation | Same-context already-published path returns original result/context with no counters changed, despite later Q. Old I/G is historical-only and cannot release successors. PG/AUTH/SQLite; PG07-09, SQ02/03 |
| P06 close/config race | Fetch ACTIVE publication view, race B5 shared lock against exclusive CLOSED; separately fetch CLOSING, replace A/manifest/I/G, then deliver old response | Accept only D7's approved ordering before the fence; waiter rereads CLOSED and denies. Binding change never restamps pending effect; no ordinary publish from CLOSING/SEALED. PG/AUTH; PG04/05/14, RC01 |
| P07 every success path | Freeze after B3 before B5 and invoke push results/duplicates, pull own echo, me/profile/init, bootstrap prepare/page/validate and job artifact publication | All ordinary paths remain held before account-state/payload/context output; owner B stays isolated. Repeat after B5 and after denial/close. Missing future endpoint is an open acceptance item, not a passing placeholder. PG/HTTP/SQLite; PG10-14/19/22, SQ03/05 |
| P08 bootstrap two phases | Snapshot before hold/deletion/fence, then fresh publication/activation after it; interrupt page install | Reject stale snapshot/publication and preserve local branch/page-cursor atomicity. Snapshot RR never authorizes B3/B5 admission. PG/SQLite; PG12/13, SQ04/09 |
| L01 genuine account denial | Disable before owner lock and after commit observation; submit workout certificate as lifecycle evidence | No ordinary effect/publication after actual denial; no maintenance account_inactive or false local erasure. Reviewed lifecycle variant must check its exact denying transition; unsupported variant denied. PG/AUTH; PG19 |
| L02 retired account missing | Valid old provider identity but retired owner absent from archive; unknown independent inventory | No initialization/profile recreation or guessed active state; independent denial preserved. PG/AUTH; PG18/22, RC07 |
| L03 complete workout deletion | Capture pre-delete child ID inventory in the harness, execute B3 deletion, compare exact emitted/retired/feed scope; corrupt one copy, then coherently omit one child from marker/feed | Honest B3 scope must equal captured inventory; inconsistent copy denied. Coherent post-delete omission documents trusted-writer limit, not an independent-completeness pass. Accept that trust or add a reviewed independent witness before activation. PREPARED metadata alone cannot authorize recovery purge/client erasure. PG/AUTH; RC04-06, SQ04 |
| L04 stale materialization | Capture snapshot/job/export input before deletion; finish after epoch/activation change or account denial | No stale payload publication; minimal retirement evidence retained; rollback never restores erased values. PG/SQLite; RC07 |
| L05 certified-held cleanup | Certified original T on CLOSED target; future additive cleanup transition, faults at each update; attempt bodyless B3 resume | Body can purge only with verified certificate/minimal anchor retained. Marker/result/cert/hold remain; V/H do not advance. B3 cannot reapply; old binary fails readiness, no edited 0004/downgrade. PG; PG21 |
| L06 unresolved retention | Permanent deletion/account erasure requested; unresolved raw body approaches its seven-day live-payload purge target | Emit accountable privacy/recovery escalation under accepted policy; no silent indefinite retention, proof destruction or timeout-based NOT_COMMITTED. Exact cleanup policy must be approved before this oracle can be completed. AUTH/PG; O5, RC08/11 |
| K01 credential rotation | Expire/revoke verifier identity before append; rotate workload/JWKS between append and exact lookup | Auth failure holds work; current authorized identity retrieves original cert unchanged. No token/secret in record/log; invalid identity cannot append or impersonate operator. AUTH then EXT IAM |
| K02 custody/head loss | Authority unavailable, old encryption key missing, restored authority head or custodian unavailable | No fallback to primary receipts or old cached authority view; recovery remains closed; verified local training continues independently. AUTH/SQLite plus separately authorized EXT custody; SQ08, RC03/11 |
| S01 evidence bounds | At cap-1/cap/cap+1 UTF-8 bytes, oversized full view containing certificate, hostile JSON depth and truncated/reordered page/reference; capture head immediately before attempted append | Denied oversized append adds no CERTIFIED event/Q/H advance. Earlier PREPARED/UNRESOLVED and private B3 effect may already exist and stay held; never rewind them. No truncation or success. Bound parser memory/depth and full view, not just inner certificate. Paging/size coverage requires D10 decision. AUTH/PG |
| S02 deadlines/restarts | Kill verifier/publisher, cancel blocked connection, exceed task deadline at each SQL/external boundary; restart same code with verified continuity | Locks/sessions close; preserve T/M/D and hold; no automatic abort by elapsed time; no external call under locks or duplicate effect. PG/AUTH; PG15/16 |

## Required completion evidence after future implementation

The eventual runner must require every implemented local case name explicitly,
report executed/passed/failed/error/skipped counts and successful terminal/JUnit
completion, and fail if a required module/name silently disappears. Do not call
36 future cases passed because this document lists them. Each staged implementation
must record which cases remain NOT IMPLEMENTED, and keep provider-gated RC10/11
separate as NOT EXECUTED until qualified and authorized.

Record source/schema/fixture hashes, exact role grants/policies and lab version,
fault boundary, before/after row/authority invariants, cleanup and every failed
attempt. Preserve old characterization expectations and receipts. Local authority
success cannot establish actual storage linearizability, independent rollback
resistance, custody or phone durability. Full appropriate existing regression,
contracts, static checks and generated artifact comparisons follow runtime/schema
changes; documentation-only work uses its own validation evidence.

## Handoff questions that require a named answer

1. Backend/security: accept trusted B3 atomicity and the D7 ACTIVE-read/database-
   fence cutoff, or require a different commit witness/coordination mechanism?
2. Platform/security: which independently enforced lifecycle and actual-connection
   binding satisfy D3, including pooler/reconnect/restore/failover? Missing proof
   blocks production acceptance; a desk recommendation cannot qualify it.
3. Storage/security: which authority operation atomically orders activation,
   owner CAS, append/H/idempotency and sealing, and which independent latest-head
   anchor survives its rollback? RC10 still needs separate authorization.
4. Backend/security: accept the online record, exact core compatibility and new
   publication validator; approve full role/readiness and successor-schema plan?
5. Privacy/product/security: define lifecycle variants, certified-held cleanup,
   unresolved-body retention, account-retirement/key horizons and D10 overflow
   coverage without silent loss or an unapproved product-size limit?
6. Operator/custodian/billing: name owners/alternates, workload/key custody,
   revocation/incident handling and separately priced provider/drill scope?

All required reviewers are unassigned and all answers remain pending approval.
The local package is complete when these decisions are concrete and reviewable
with supporting evidence, not when their required approval or implementation is
claimed. No commit, push, PR, merge, deployment, provider change or hosted drill
is authorized by this document.
