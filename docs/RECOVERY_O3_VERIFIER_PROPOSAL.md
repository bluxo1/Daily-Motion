# O3 committed-marker verifier and certificate proposal

2026-10-22. **PROPOSED / UNAPPROVED. Backend and security review required.**
This is a review input for O3 in the
[proposed Recovery V2 specification](RECOVERY_PROTOCOL_V2_SPEC.md#14-unresolved-decisions-and-implementation-prerequisites),
not an accepted ADR, implementation authorization or provider selection. The
[proposed ADR](ADR_RECOVERY_PROTOCOL_V2_PROPOSED.md) remains unchanged. Phase 0
is in progress; Phase 1 has not started. No hosted operation is authorized here.

## Decision requested

Review a same-codebase, separately authorized verifier that observes an existing
B3 commit on its verified original target, releases every database lock, then
submits minimal evidence to the independent authority. The authority validates
the verifier's identity and exact PREPARED binding before compare-and-append.
The application can publish only after a separate B5 transaction verifies the
resulting authority certificate and fresh local state.

The existing `observe_committed` helper is only the database observation part.
Caller-created `Admission`, marker objects or matching hashes do not authenticate
anything. Its nondelete checks bind the persisted marker, request, result, feed
and root revision; they do not independently audit every normalized child or
observation value, reconstruct payloads or prove backup completeness. It relies
on trusted B3 atomicity. A trusted caller must separately establish target
identity and unchanged continuity; a copied OPEN row cannot do that. It cannot
currently inspect CLOSED targets or recover an unknown/lost marker.

## Proposed trust and permission boundary

| Principal | Proposed permission | Explicit exclusion |
| --- | --- | --- |
| API effect runtime | Restricted owner-scoped B1/B3 database work; request preparation through authenticated adapter | Cannot mint a trusted commit attestation, activate/seal or delete authority history |
| Verifier identity | Observe the named prepared attempt on the approved original target; submit commit evidence for that attempt | Cannot activate targets, cancel uncertain attempts, decrypt backups or publish client success |
| Authority | Authenticate scoped verifier; validate activation, PREPARED and evidence bindings; durably compare-and-append and return exact certificate | Cannot infer commit from intent, timeout, missing restored receipt or a client assertion |
| B5 runtime | Verify certificate and current target/owner state under ordered locks; atomically publish | Cannot reinterpret an old certificate as a current effect or repeat B3 |
| Operator/custodian | Explicit activation, containment and sealing procedures with audit | No implicit activation through configuration or application startup |

Use a distinct workload identity and narrowly scoped credentials. Reuse reviewed
code in the modular monolith; this proposal does not require another service.
The verifier's database permissions need an explicit read/lock grant design:
PostgreSQL row locking may require UPDATE privileges even without application
writes. Do not claim read-only SQL grants until the actual role and queries are
qualified. Preserve non-owner/NOBYPASSRLS, forced RLS and verified tenant context;
never substitute migration/admin credentials or a privileged unreviewed function.
An independent authority must restrict certificate append to the verifier role;
an API runtime holding the same unrestricted authority key would erase this
boundary. Custody and compromised-principal assumptions require O1/O2/O9/O11.

## Proposed observation and append sequence

1. Outside database transactions, authenticate a bounded reconciliation request,
   retrieve the exact PREPARED attempt and fresh authority head, and verify
   E/A/I, owner, nonce and actual target identity/continuity. Select the approved
   code/schema/manifest. An unverified reconnect, target replacement, rewind,
   evidence contradiction or unavailable original commit evidence stops the
   process with the owner held; it never resumes B3 automatically.
2. In a new short READ COMMITTED transaction, take the shared recovery fence,
   read fresh control, set verified tenant context, then take owner and attempt
   locks in the specified order. Recheck purpose-appropriate account policy,
   activation, PREPARED checkpoint and complete stored marker/result/request,
   receipt, private feed and deletion scope. Reject borrowed transactions and
   stale ORM state. No authority, identity or storage call occurs under locks.
3. Close the transaction before producing a trusted attestation. Bind the
   attestation to the exact observation, original target/manifest and verifier
   identity. A successful function return is an input to this trusted boundary,
   never a certificate itself. Failure or response loss leaves the hold intact.
4. Outside database locks, submit authenticated evidence to the authority with
   the expected PREPARED head. Accept only the same E/A/I/T/M/D and marker/result
   binding. An exact retry returns the same durable certificate; a changed
   binding or contradictory head is denied. No new preparation is allowed while
   CLOSING; settlement of an existing preparation requires reviewed CLOSING
   policy. A SEALED activation rejects all new certificates.
5. Retrieve and authenticate the authority result. A lost response requires exact
   attempt lookup, not a new certificate identity or a new effect. Authority
   unavailability or an older/divergent prefix never falls back to local receipts.
6. Only a later B5 transaction can validate the certificate and fresh activation,
   owner/lifecycle policy, hold and P/V/H, then update the publication metadata,
   pending receipt and temporary-request cleanup atomically. A close/new
   incarnation between observation and B5 preserves historical evidence while
   denying ordinary publication. This PR implements none of these B5 writes.

CLOSED-target settlement needs a separate purpose-scoped path and tests before
step 2 can support it. Keep it unavailable in the current helper. Missing original
commit evidence remains UNRESOLVED under O4; this proposal provides no abort proof.

## Proposed logical certificate content

The candidate is a versioned, authenticated authority record retrievable by exact
attempt, with a verifiable binding to both its PREPARED predecessor and independent
current head/seal. An authenticated record/reference may suffice; a custom signed
token is not assumed necessary. Transport/encoding and cryptography remain review
decisions. A self-contained signature alone cannot establish a latest complete
prefix. Proposed logical fields are:

| Field group | Required binding |
| --- | --- |
| Domain/version | Distinct commit-evidence type and explicit format version; reject unknown versions |
| Identity | E/A/I/G, verified owner, T/M/root, complete-command schema and D |
| Commit | Exact marker digest, deterministic minimal terminal result and its digest, private position or null |
| Erasure/lifecycle | Committed epoch, complete affected/retired IDs, purpose and applicable lifecycle denial scope |
| Target/verifier | Verified original-target identity digest, approved manifest/code/schema binding, verifier identity and observation request nonce |
| Ordering | Exact PREPARED order/digest, authority append predecessor and resulting checkpoint; seal/activation reference |
| Authentication | Authority identity plus maintained authenticated transport or signature/key-version metadata as selected by review |

Do not include the frozen command, set values, notes, raw JWT/OTP, database URLs,
credentials or backup decryption material. Owner/root/child IDs remain sensitive
metadata subject to [security policy](SECURITY.md#retention-deletion-and-portability)
and O5. No timestamps or TTLs establish commit, abort, continuity or completeness.
Canonical representation must preserve JSON types and checked integer bounds;
reject duplicate keys, malformed digests, noncanonical/ambiguous encodings and
unknown fields rather than silently changing signed or hashed meanings. Align
the eventual encoding with existing marker/checkpoint digests through reviewed
fixtures; do not silently replace their canonicalization.

## Review decisions and acceptance before implementation

| Decision | Reviewer and required answer |
| --- | --- |
| Trust in a commit observation | Backend + security: accept trusted B3 atomicity plus original-target continuity, or require additional durable WAL/commit evidence; define exact failure/reconnect behavior |
| Target and continuity proof | Operator + security (O2): name the actual platform evidence, custody and verification procedure; SQL control/hostname/flag alone is insufficient |
| Verifier permissions and authentication | Backend + security: separate identities, owner/purpose authorization, SQL lock grants, bounded credentials and revocation; test denial of runtime-minted attestations |
| Certificate representation | Backend + security: authenticated record/reference versus signed envelope, maintained encoding/library, exact field schema, key rotation/retrieval and freshness/seal validation |
| Lifecycle and retention | Security/privacy + backend (O5): purpose-specific account denial, minimal ID retention, temporary request cleanup, authority/key lifetime and erasure behavior |
| Independent storage and unresolved attempts | Storage/recovery owners (O1/O4): real durable CAS/head/seal semantics and unavailable-source policy; no emulator substitution |

All reviewers are unassigned and all decisions remain unresolved. This proposal
and the implementation review are not backend/security acceptance or O11's
independent security review. Do not implement a production certifier or B5 until
the blocking design has an explicit review record and the required authorization.

After that review, the next implementation slice is a local trusted-adapter
boundary with generated certificate fixtures and deterministic fault tests:
forged/cross-owner identity, copied target, stale authority head, changed marker,
rollback, commit-response loss, append-response loss/restart, CLOSING/SEALED races,
account denial, deletion scope, lock release before I/O and atomic B5 rollback.
Use actual PostgreSQL for transaction/RLS behavior. Verify that every ordinary
read/echo/duplicate/bootstrap path stays held until B5 and that old-context
certificates cannot publish on another incarnation. Keep RC10/RC11 **NOT
EXECUTED** until separately authorized provider/custody qualification. No local
test result closes physical-device, hosted recovery or Phase 0 release gates.
