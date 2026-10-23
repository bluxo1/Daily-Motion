# O3 interface and record definitions for review

2026-10-22. **PROPOSED / UNAPPROVED. Design notation only.** These are recommended
internal contracts for the [O3 design](RECOVERY_O3_VERIFIER_PROPOSAL.md), not
implemented Python classes, HTTP routes, OpenAPI changes or authenticated objects.
Constructing any value below supplies no authorization. Backend/security review
and explicit implementation authorization precede production code.

## Scalar and encoding rules

| Type | Proposed definition |
| --- | --- |
| UUID | Canonical lowercase, hyphenated UUID string; exact stored identity, no case/format rewriting after hashing |
| Digest | Exactly 64 lowercase hexadecimal characters, SHA-256 content binding; not an authentication token |
| Counter | JSON integer token, 0 through 2^63-1; A/revisions/private positions positive where required. Reject booleans, floats/exponents, overflow and lossy numeric decoders |
| Checkpoint | Exactly `{order: Counter, digest: Digest}`; order zero iff digest is 64 zeroes |
| Reference | 1-256 ASCII bytes in 0x21-0x7e; opaque registered reference, never dereferenced as a URL, filesystem path or DSN. No credential supplied by a caller |
| Timestamp | Existing exact UTC accepted_at spelling from the committed result; never a completeness/abort clock |

Decode UTF-8 JSON with duplicate-key rejection, exact field sets and typed
validation before hashing. Preserve the existing repository canonical JSON:
`json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':'))`,
UTF-8 encoded. The new records permit no floating-point, NaN or infinity values.
This is not a claim of RFC 8785/JCS canonicalization or IEEE-754 safety. Consumers
must preserve signed 63-bit integers exactly, including values above 2^53-1.
Do not change already-hashed marker array ordering or timestamp spelling.

Unknown record/event versions, purposes, fields, duplicate identities or invalid
counter/UUID/digest forms fail closed. Proposed initial transport bound: 1 MiB
per complete encoded request/response, including a CurrentAuthorityView containing
a certificate; maximum JSON object/array nesting depth 16. Both are candidate
decoder/transport bounds requiring D10 review, not implemented limits.
An oversized retirement list is
never truncated or replaced by an unchecked reference. D10 requires a reviewed
size/paging extension or accepted coverage bound before activation; this proposal
does not reduce the product's permitted workout size.

The [shape-sizing experiment](experiments/recovery_o3_record_sizing.py) uses the
current DTO ceiling of 50 exercises and 100 sets each: at most 5,051 retired IDs
including the root. With maximal counter widths, timestamp and escaped reference,
compact observation/certificate/publication-view shapes measure 396,618 / 396,832 /
399,365 bytes. This conservative count may exceed command-byte admission. It
supports headroom for the present workout variant, not cryptographic validity,
arbitrary whitespace/JSON depth, lifecycle scope or future contract coverage.

## Existing core events remain byte-compatible

IntentMetadata is exactly the current Intent.metadata field set:

```text
schema_version=2, owner, mutation, attempt, root, environment,
incarnation, generation, activation_serial, request_digest
```

CommittedMetadata is exactly current CommittedMarker.metadata:

```text
all IntentMetadata fields, marker_digest, result_digest, outcome,
private_position, erasure_epoch, affected_ids, retired_ids
```

The outcome is the exact current accepted/conflict/rejected TerminalOutcome
result. Accepted includes original accepted_revision/accepted_at. Conflict and
rejection use the closed error-code vocabulary, with no personal/free-text error.
Nonaccepted outcomes have null private_position and empty affected/retired lists.
Retirement IDs are complete and unique and are a subset of affected IDs. When
nonempty they contain the root; for accepted nondelete operations they are empty.
The verifier checks the frozen operation and private database evidence as required by purpose;
this format alone does not prove that check occurred.
Complete child enumeration depends on trusted B3's pre-delete inventory. The
current post-delete observer checks consistency/suppression of listed IDs; it
cannot independently recover an omitted child from purged state. See advisory F2.

For checkpoint `q` and event `e`, use the existing operation unchanged:

```text
append(q, e).order = q.order + 1, checked against 2^63-1
append(q, e).digest = SHA256(CanonicalUTF8({
  previous: q.digest, order: q.order + 1, record: e
}))

prepared = append(prior, {kind: PREPARED, **IntentMetadata})
uncertain = append(prepared, {kind: UNRESOLVED, **IntentMetadata})
certified = append(predecessor, {kind: CERTIFIED, **CommittedMetadata})
predecessor = prepared OR uncertain, for the exact same intent
```

Marker digest remains SHA256 of canonical `{kind: EFFECT_COMMITTED,
**CommittedMetadata without marker_digest}`. Result digest remains the hash of
the exact TerminalOutcome result. No target descriptor, nonce, credential or
new envelope field is inserted into these existing preimages. A core-event
version change would require separate fixtures/migration/review.

## Recommended proposed interfaces

These signatures describe trust/transaction boundaries, not executable code:

```text
assigned_preparation(attempt_hint, fresh_nonce, authenticated_workload)
    -> PreparedScopeV1 | Denial
open_verified_target(activation_binding, purpose, fresh_registry_view)
    -> AttestedSessionFactory | UnverifiedTarget
observe_and_close(prepared_scope, known_marker, attested_session_factory)
    -> ObservationEvidenceV1 | Denial
append_certificate(observation, expected_head, authenticated_verifier)
    -> CertificateRecordV1 | SameCertificate | AuthorityPending | HeadConflict | Unresolved
current_view(scope, purpose, fresh_nonce, certificate_key?)
    -> CurrentAuthorityViewV1 | AuthorityPending | Denial
publish_known(certificate, verified_current_view, attested_session_factory)
    -> OriginalResultAndContext | PublicationPending | RecoveryDenied
```

Only authenticated adapters construct trusted instances; a type name/private
constructor or a boolean flag is not a security boundary. The factory binds the
actual checked-out connection, not merely an Engine's URL. Each SQL transaction
owns and closes its session; external operations require no active transaction
or database/SQLite lock. The current observe_committed function does not implement
these interfaces: it accepts an Engine and untrusted internal Admission values,
and supports only a known marker with active owner and ACTIVE/OPEN state.

AuthorityPending is a nonterminal `authority_anchor_pending` or unavailable
result, not a certificate acknowledgment or proof of an unresolved domain effect.
An append succeeds only after the independently checked root/anchor match below.
Any eventual public response mapping needs reviewed contracts; no new route or
wire error is introduced by this design notation.

| Proposed type | Exact required fields / validation |
| --- | --- |
| ActivationBindingV1 | environment UUID, activation_serial positive Counter, incarnation UUID, target_identity_digest Digest, manifest_digest Digest, continuity_ref Digest. Each reference resolves through the independently authenticated registry |
| PreparedScopeV1 | IntentMetadata, prior_checkpoint, prepared_checkpoint, current append_predecessor, activation_binding, authority challenge nonce and authenticated assignment/purpose. Recompute PREPARED and any UNRESOLVED predecessor; no client-selected owner/DSN |
| AttestedSessionFactory | Opaque local handle to approved connection factory plus verified ActivationBindingV1 and proof reference. No public serialization or caller-provided Engine; unknown target/reconnect is denial |
| ObservationEvidenceV1 | Exact record shape below, derived by the authenticated verifier only after the observation transaction closes |
| CertificateRecordV1 | Immutable authority record below; authenticated retrieval/append response required before it can be used |
| CurrentAuthorityViewV1 | Separate fresh atomic authority result below, not an extension of the immutable certificate's event hash |

### Independent target registry entry

Recommend an immutable TargetBindingEntryV1 with exactly record_type=
`dm.recovery.target_binding`, record_version=1, environment, activation_serial,
incarnation, resource_identity, endpoint_policy_ref, routing_policy_ref,
role_binding_ref, manifest_digest, continuity_revision and connection_contract_ref.
E/A/I and counters use the scalar rules; policy/contract references are Digests.
resource_identity is exactly provider_namespace, account_resource,
project_resource and database_resource, each a Reference to an independently
authenticated immutable resource identity, not an application-selected hostname.

target_identity_digest is SHA256 of `b"dm.recovery.target-identity.v1\0"` plus
canonical resource_identity. continuity_ref is SHA256 of
`b"dm.recovery.target-binding.v1\0"` plus canonical TargetBindingEntryV1.
These recomputed references must match ActivationBindingV1. Current authorization
to use that immutable entry is obtained freshly from the independent registry,
bound to the requesting workload/purpose/nonce and registered connection contract;
revoking/closed or unknown state denies use. Do not modify an old entry to bless
a new resource. A new ancestry requires new I/G and approved activation.

connection_contract_ref names the reviewed guarantee covering the **actual
connection for the whole transaction**, including revocation/drain before rewind.
It is not a generic serialized `connection_verified` flag or a clock-only lease.
Its platform proof format is deliberately unresolved O2: adapters cannot construct
AttestedSessionFactory until the selected platform has supplied and qualified
that mechanism. The synthetic example uses placeholder digests and does not
pretend that such a registry entry or proof was obtained.

ObservationEvidenceV1 exact keys:

```text
record_type = "dm.recovery.observation"
record_version = 1
purpose = "workout_observe" | "workout_settle"
request_nonce: UUID
activation_binding: ActivationBindingV1
prior_checkpoint: Checkpoint
prepared_checkpoint: Checkpoint
append_predecessor: Checkpoint
committed: CommittedMetadata
verifier_principal_ref: Reference
verifier_manifest_digest: Digest
observation_method = "postgres_committed_row/v1"
```

The authority derives/compares verifier_principal_ref from authenticated identity
and checks the approved manifest registry; it never trusts the supplied name.
`workout_observe` requires ACTIVE/OPEN and the exact PREPARED head.
`workout_settle` covers the reviewed head/state combinations below, including
an authority UNRESOLVED head on ACTIVE/OPEN; the current helper rejects that gap.
It is not a backdoor to invoke B3 or publish. A challenge is fresh and scoped to
E/A/I, owner/T and purpose; credential TTL is not the authority's freshness proof.
No raw token, frozen request, set value, note, connection string or backup key
appears in this evidence. A trusted verifier still reads necessary private data
transiently during observation.

Define `attestation_digest = SHA256(b"dm.recovery.observation.v1\0" +
CanonicalUTF8(ObservationEvidenceV1))`. The zero byte is domain separation, not
a literal backslash plus zero. This digest binds a request authenticated over
TLS; it is not a detached signature or proof of who sent an arbitrary object.

### Observation head and state matrix

All rows require independently verified original-target continuity, authenticated
assignment/purpose and fresh root/anchor checks outside SQL locks. Inside the
fresh transaction require ordered fence/owner/attempt locks, exact T/M/D/origin,
local hold, immutable marker/result/receipt/private evidence, and local anchor
equal to recomputed prepared_checkpoint. Lookup an already-existing authentic
certificate first; returning it needs no second observation or append.

| Authority / local original target | Authority append_predecessor | Proposed observation rule |
| --- | --- | --- |
| ACTIVE / OPEN | PREPARED(T) | Normal workout_observe; the current helper's head/state checks have this shape, without supplying authentication/continuity |
| ACTIVE / OPEN | append(PREPARED(T),UNRESOLVED(T)) | New workout_settle observer; exact same-intent extension validation, never ordinary validate_admission or a synthesized equal-head assertion |
| CLOSING / OPEN or CLOSED | PREPARED(T) or its one same-intent UNRESOLVED successor | New workout_settle observer with explicit original-target reconciliation authorization; no ordinary publication |
| SEALED, different target/lineage, RECONCILING, unknown binding or arbitrary higher head | Any | No new observation-based append; authorized exact existing-certificate lookup only where policy permits |

The reviewed first settlement path requires local EFFECT_COMMITTED with complete
immutable evidence. A future UNRESOLVED local state is not by itself commit proof
or an approved extra transition. Loss of evidence requires O4 and safe closure.
The future validator recomputes PREPARED from prior_checkpoint and IntentMetadata,
and the optional UNRESOLVED successor from that exact intent. It checks the
authority's pending intent equals the original intent and the append predecessor
equals the fresh authority head. After SQL closes, append uses that expected head
and atomically rechecks state/binding; a competing append/seal is never bypassed.
None of this is implemented by a new flag around observe_committed.

## CertificateRecordV1 exact fields

| Key | Value and binding |
| --- | --- |
| record_type | Literal `dm.recovery.certificate` |
| record_version | Integer 1, outer representation version |
| event_version | Integer 1, current checkpoint-event representation |
| purpose | Literal `workout`; account lifecycle/initialization is not accepted as this variant |
| activation_binding | ActivationBindingV1; E/A/I exactly match committed metadata. Bound target/manifest/continuity come from the trusted registry |
| prior_checkpoint | Original owner head immediately before this exact PREPARED |
| prepared_checkpoint | Recomputed from prior and IntentMetadata |
| previous_checkpoint | PREPARED or its same-intent UNRESOLVED successor; no arbitrary newer head |
| checkpoint | Recomputed CERTIFIED successor of previous_checkpoint; immutable certificate position |
| committed | Exact persisted CommittedMetadata, including original result, feed/epoch and complete affected/retired scope |
| observation | Exactly verifier_principal_ref, verifier_manifest_digest and attestation_digest from the first accepted authenticated observation |
| certificate_id | Digest defined below; content reference only |

`certificate_id = SHA256(b"dm.recovery.certificate.v1\0" +
CanonicalUTF8(all CertificateRecordV1 fields except certificate_id))`.
The authority creates this record atomically with its owner event, head/H and
unique E/owner/T and E/owner/M bindings. A verifier cannot create an authentic
record merely by computing this ID.

Response-loss retry first looks up the original E/owner/T/M/D. If an existing
record's committed core/activation bindings match, return that **first exact
record**, including its original observation provenance and certificate_id.
A retried challenge, rotated verifier credential or new observation is not a
reason to mint another record. Different core/target/result evidence is denied
as a contradiction. SEALED allows authorized retrieval of an existing record,
but not new append. Atomically order seal versus append inside the authority.

The [synthetic example](evidence/recovery-o3-certificate-v1-example.json) contains
computed marker/result/checkpoint and envelope hashes. Its wrapper labels the
fictional observation and certificate; it is not evidence that a domain commit,
authentication or certification happened. The executable probe uses only the
already-existing pure reducer to exercise hash/order rules.

## CurrentAuthorityViewV1 and B5 transition proof

Recommend one authenticated linearizable authority operation returning this exact
logical field set; the platform-specific transport adapter remains unimplemented:

| Key | Required meaning |
| --- | --- |
| record_type / record_version | `dm.recovery.current_view` / integer 1 |
| request_nonce | Newly generated request UUID, exact match; no reuse on another request |
| purpose | `normal_admission`, `workout_observe`, `workout_settle`, `workout_publish`, `published_lookup`, `historical_lookup` or `recovery_inventory`; deny unknown purposes |
| scope | Exactly environment, requested_activation, owner, attempt, mutation, request_digest and certificate_id. environment/owner are UUIDs, requested_activation is ActivationBindingV1; the last four fields are explicitly nullable as specified below |
| current_activation | Current ActivationBindingV1 plus state ACTIVE/CLOSING/SEALED |
| authority_root | AuthorityRootV1 for this exact atomic snapshot, checked against a separately obtained authenticated anchor as specified below |
| requested_activation_state | Fresh state of the certificate/preparation's original activation, which may now be SEALED/historical |
| current_owner | Exactly owner, generation, checkpoint, certified erasure_high_water, lifecycle_state, inventory_ref and pending_attempt; or null when owner existence/inventory is unknown. An unknown/missing inventory or denial state refuses normal admission/publication |
| certificate | Exact CertificateRecordV1 or explicit null for an authorized absent lookup or a purpose not requesting a certificate. workout_publish requires a nonnull matching certificate |
| inclusion | Exactly certificate_id (or null), owner_checkpoint (null only if inventory is unknown) and classification: `included_current`, `included_historical`, `absent`, `contradictory`, `unknown`, `not_requested`. Authority verifies inclusion/absence in that atomic view; an untrusted boolean claim is insufficient |

Scope nullability is purpose-specific: normal_admission/recovery_inventory have
all four nullable fields null; workout_observe/workout_settle require T/M/D and
null certificate_id; workout_publish requires all four. published_lookup and
historical_lookup require M/D, with T and certificate_id optional to support loss
of the original append response or a missing local receipt after restore.
The authenticated authority's owner/M/D lookup supplies original T/certificate_id;
it never invents a new attempt. The returned record must match every supplied
field. Missing keys are never equivalent to explicit null. Unknown purpose or conflicting
scope is denied, not interpreted as a broader query.

For published_lookup/historical_lookup, a complete authenticated view may return
certificate=null and classification=absent when the append never committed.
This is a valid response-loss branch, not permission to abort/reapply B3, clear
the hold or initialize an owner. An existing same-intent PREPARED/UNRESOLVED still
blocks closure. A current assigned verifier may retry the same evidence append
only under its matching original scope/state/head. Missing inventory, a root/
anchor mismatch or inability to authenticate lookup yields unknown/denial, never
absent. If no certificate key was requested, use not_requested rather than infer
absence. Conflicting M/D/T/certificate_id returns a sanitized contradiction/denial.

`current_owner.pending_attempt` is IntentMetadata for the independently unresolved
PREPARED attempt, or null after certification; it is **not** the local publication hold. The local
hold remains until B5 even when the authority has certified and pending_attempt
is null. `lifecycle_state` is `active`, `disabled`, `retired` or `unknown`; the
source/policy and retained denial scope require O5. `inventory_ref` is a Digest
to complete authenticated inventory, nullable only when completeness is unknown
(which denies normal work). An absent owner is not automatically a fresh owner:
never synthesize generation, Q=0 or active lifecycle from missing inventory.
All fields, certificate lookup and inclusion are from the same atomic authority
view, not independently sampled reads combined by the caller.

For **first publication** require all of the following in the fresh SQL transaction:

1. Current and certificate E/A/I/target/manifest/continuity match the actual target;
   current generation matches G, local OPEN and fresh authority ACTIVE. See D7's
   explicit read-versus-exclusive-fence concurrency interpretation.
2. Same local hold T and immutable attempt/M/D/result/marker, active account with
   no retirement for normal workout purpose; private effect/feed/erasure scope
   matches certificate. No owner/root state is reused from before a lock wait.
3. Local evidence anchor equals the certificate's prepared_checkpoint. Validate
   the exact same-intent optional UNRESOLVED event and CERTIFIED successor.
   Authority current owner head equals this certificate checkpoint, its H equals
   the certified committed epoch, pending_attempt is null, and inclusion is
   included_current. Do not accept a larger order as proof of ancestry or apply ordinary validate_admission
   to local PREPARED versus authority CERTIFIED.
4. Update local evidence anchor to certificate checkpoint; set V=P only for the
   matching private position (nonaccepted outcome leaves feed unchanged), set
   certified H, bind certificate and exact receipt/result/context, clear body and
   hold, and mark PUBLISHED in one transaction. Add a certificate-present schema
   constraint plus authenticated application validation. Rollback restores all.

For **already-published duplicates**, a later certificate can legitimately be the
current head. Require current local anchor to equal the fresh current owner head,
no local hold, P=V, current active owner, and authenticated inclusion of the old
certificate in that prefix. Return the already-published original result/context;
do not move counters or restamp it. For historical lookup across I/G, preserve
historical-only classification and never release a pending successor.

The current Assertion/Certificate dataclasses do not supply this authenticated
view, lifecycle/target proof or new publication validator. This record proposal
does not add them. Retention of the minimal preparation anchor after body purge,
CERTIFIED_HELD cleanup and lifecycle variants require the reviewed successor
schema described in the main proposal. No activation or privacy policy is changed.

## Authority root and independent anchor contract

This is a concrete **candidate O1 contract**, not an implemented storage backend.
AuthorityRootV1 has exactly record_type=`dm.recovery.authority_root`,
record_version=1, environment UUID, revision Counter, previous_root Digest,
state_digest Digest and root_digest Digest. Revision zero uses zero previous_root
and represents an explicitly registered genesis inventory, never inferred absence.
root_digest is SHA256 of `b"dm.recovery.authority-root.v1\0"` plus canonical
UTF-8 of all fields except root_digest. A successor uses revision+1 and the
previous root_digest, with checked counters.

state_digest binds a complete canonical metadata inventory snapshot: current and
historical activation bindings/states/seals; owner UUID/G/Q/H/lifecycle references;
all pending/unresolved intents; certificate and retirement references; complete
owner/attempt membership, including absent-from-archive owners. Arrays are sorted
by their unique identity, and every referenced record has a content digest.
O1 must freeze that inventory schema and coverage algorithm before G2; a root
over an incomplete selected list is not acceptable. Ordinary clients do not get
the cross-owner inventory or authority credentials. Only the scoped atomic view
and its authenticated inclusion result leave the authority for that caller.

The separate monotonic service stores an AnchorHeadV1 tuple of exactly
environment, revision and root_digest. Its authenticated fresh read echoes the
caller's new request_nonce; its CAS accepts the exact current tuple and its
one-revision successor, idempotently returning that tuple on exact retry while it
is current. A later head requires fresh authenticated current-state/inclusion
verification; it never permits overwriting the anchor with the older tuple.
Reset, deletion, gaps and arbitrary overwrite are unavailable to application,
verifier, publisher and authority-writer identities. A separate root publisher
advances it after the authority transaction closes. Its custody/restore semantics
are required platform evidence, not supplied by JSON or a content hash.

Trusted adapters fetch the scoped atomic view and the anchor independently, over
their authorized channels with fresh nonces, and require identical E/revision/
root_digest. They never trust an authority-provided `anchor_verified=true` flag.
During a pending root, mismatch or outage, ordinary admission/publication and
successful append acknowledgment are unavailable. A stored immutable certificate
may still be retrieved as pending/historical evidence without conferring current
authority. R07/RC10 must test both crash windows and rollback on a new worker;
no deployed service is claimed to implement this contract.
