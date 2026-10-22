# Proposed ADR: recovery admission and certified publication

2026-10-21 IST. **Status: PROPOSED / UNAPPROVED.**
Identifier: `PROPOSED-RECOVERY-02`; no accepted DM number is assigned/reserved.
Baseline: `2781f5c101e87e1a9351cb3e7bbf53453625e025`.

This is a specification-stage proposal. It does not change
[the accepted decision log](DECISIONS.md), enable DRP/2, authorize a resource or
implement runtime behavior. Phase 0 remains open; Phase 1 has not started.

## Context and observed evidence

[The preserved investigation](RESTORE_TIMELINE_INVESTIGATION.md) records four
executed safety findings: equal-revision stale admission, delayed-request
admission, acceptance again after receipt loss and deleted workout resurrection
after retirement-record loss. Its one Python harness/13 Flutter characterization
successes are reproduction evidence, not recovery qualification.

The current client restore fence preserves local branches but cannot prevent a
server commit between preflight and upload. Independent receipt/deletion evidence
must outlive application rollback. Push response gating alone is inadequate:
pull own echoes and bootstrap projections can also convey authoritative effects.

The proposal affects DM-005/DM-006 (lineage, receipts, feed publication), DM-012
(deletion/retention) and DM-014 (safe denial/local availability). No existing
decision is superseded unless this ADR is explicitly reviewed and accepted.

## Proposed decision

Adopt the [DRP/2 specification](RECOVERY_PROTOCOL_V2_SPEC.md), subject to all
unresolved decisions in its section 14:

1. Independently authenticate environment/target activation and ordered evidence
   checkpoints. Copied OPEN rows, hash chains without a trusted latest head and
   stale cached assertions never authorize recovery.
2. Capture immutable environment/incarnation/generation with each local branch;
   bind it into frozen commands. Admit effects under a shared recovery lock and
   fresh READ COMMITTED owner/control checks. Operator close uses the exclusive
   lock; separate old-source containment handles cross-database cutover.
3. Reserve a durable per-owner publication hold before applying an effect.
   Preserve the single atomic domain/revision/feed/receipt transaction. Certify
   its committed marker independently outside DB locks, then publish in a fresh
   guarded transaction. Push, duplicates, pull/own echoes, metadata, snapshots
   and jobs cannot bypass this barrier.
4. Distinguish intent, committed, independently certified, published and
   unresolved outcomes. Never infer abort or permission to replay from an absent
   restored receipt. Historical results do not authorize current shadows/successors.
5. Reconstruct all certified retirement/lifecycle evidence before access; suppress
   erased projections/history/feed/snapshots/jobs and reconcile the authoritative
   epoch above restored and independently certified high-water. Receipts do not
   replace payload backup or establish an unapproved RPO.
6. Deny legacy/unknown-origin cloud writes explicitly; preserve frozen bytes,
   ownership, acknowledged work, drafts and local training. Review the accepted
   current/previous-client compatibility commitment before activation.

No new business microservice, broker, CDC platform or custom cryptographic format
is selected. The independent capability must be chosen and qualified before its
guarantees are claimed. Prepared-attempt resolution after source loss remains a
blocking decision; the default is closed recovery, not guessed deletion/abort.

## Alternatives and reasons

| Alternative | Assessment |
| --- | --- |
| Client preflight/local fence alone | Reproduced D1/D2: cannot atomically prevent server stale admission |
| Only request headers/latest generation at send | Relabels branch basis; frozen identity and causality can be lost |
| Ordinary receipt/CAS checks after restore | D1/D3: equal revisions and missing historical receipts permit unsafe effects |
| Increment restored erasure epoch | D4: no reconstruction of missing retired IDs; can remain below observed high-water |
| Delay push response only | Leaves own echoes, duplicates, projections and metadata publication uncovered |
| Hold owner/SQLite locks through independent storage calls | Violates accepted lock/network boundaries and local availability |
| Asynchronous daily export as zero-gap receipt/deletion authority | Cannot establish coverage of effects acknowledged after its snapshot |
| Whole-batch transaction | Does not solve independent durability or source cutover; changes established per-operation rollback/locking semantics |
| Distributed atomic commit / zero-gap independently durable WAL route | Potential alternative if the actual platform supports and qualifies it; not assumed available or priced |

## Consequences and trade-offs

- Local set saving and cached-owner access stay independent of recovery/Auth.
- Cloud operations for an owner pause while one command awaits certification;
  other owners remain independent on an otherwise qualified environment.
- Every published result requires independent evidence; authority latency,
  availability, capacity and costs become cloud synchronization dependencies.
- Prepared uncertainty may block restoration indefinitely when the source and
  trusted commit evidence are lost. An available resolver cannot be assumed.
- More explicit metadata/migrations and client compatibility work are necessary.
  Immutable old envelopes are preserved; old unknown-origin work is not silently
  upgraded or discarded.
- Independent metadata remains sensitive and requires minimal retention, access,
  encryption/key custody, lifecycle cleanup and privacy/security review.
- Generation admission prevents stale effects; it cannot recover missing workout
  payload or authorize switching back after new-target writes.

## Acceptance and prerequisites

Require specification invariants I1–I10, PG01–PG22, SQ01–SQ10 and RC01–RC12,
including genuine selected-authority conformance/custody evidence. Use actual
disposable PostgreSQL and file-backed SQLite, deterministic fault boundaries and
machine/JUnit guards against skipped/incomplete successes. Characterization
receipts remain immutable; defensive tests must assert protected outcomes.

Approve authority/provider/target identity, commit observation and abort proof,
initial coverage, lifecycle retention, payload RPO/RTO, legacy policy, costs,
operators and an available independent security review before implementation
authorization. Hosted drills need separate exact-scope approval after local
qualification; this ADR grants none.

## Migration and rollback

Use additive PostgreSQL/Drift migrations and generated versioned contracts.
Do not edit old migrations, restamp legacy receipts, rewrite frozen commands or
downgrade a live activated environment to a server ignoring admission/publication.
Rollback before activation requires proof that no v2 semantics were used; after
activation use compatible forward repair with cloud admission closed. Reverting
routing after new-target writes is a new reconciled recovery, not a URL rollback.

## Review and approval record

| Item | State |
| --- | --- |
| Product/operator decisions | Unresolved; see specification O1–O12 |
| Independent security review | Unavailable; restricted output not retried, retrieved or bypassed |
| Runtime implementation/tests for DRP/2 | Not implemented / not executed |
| Hosted qualification | Not authorized / not performed |
| Accepted ADR update | None; proposal only |
| Commit / PR / merge | None; separate approval required |

This primary-agent proposal does not claim independent approval. Keep all
existing Phase 0 acceptance gates and recorded external blockers open.
