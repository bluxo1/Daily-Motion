"""DRP/2 internal evidence rules; no provider, activation or runtime fallback.

These values are internal to the authority/admission boundary, not wire DTOs.
An authenticated real authority, target verifier and committed-marker observer
are required before they may authorize production effects. In particular, a
digest chain or a caller-constructed assertion is not an independent authority.
"""

import hashlib
from dataclasses import dataclass, replace
from datetime import datetime
from enum import StrEnum
from typing import Protocol
from uuid import UUID

from pydantic import ValidationError

from daily_motion.contracts import AcceptedResult, canonical_json

MAX_COUNTER = (1 << 63) - 1
EMPTY_DIGEST = "0" * 64


class RecoveryDenied(Exception):
    def __init__(self, code: str = "recovery_metadata_unverified") -> None:
        # Safe codes only; never interpolate evidence, identities or payloads.
        super().__init__(code)
        self.code = code


def counter(value: int) -> int:
    if type(value) is not int or not 0 <= value <= MAX_COUNTER:
        raise RecoveryDenied()
    return value


def digest(value: str) -> str:
    if (
        not isinstance(value, str)
        or len(value) != 64
        or any(char not in "0123456789abcdef" for char in value)
    ):
        raise RecoveryDenied()
    return value


def require_uuids(*values: UUID) -> None:
    if any(not isinstance(value, UUID) for value in values):
        raise RecoveryDenied()


def next_erasure_epoch(restored: int, certified_high_water: int) -> int:
    """Only trusted replay supplies H; a client maximum is never an input source."""
    return counter(max(counter(restored), counter(certified_high_water)) + 1)


@dataclass(frozen=True)
class Origin:
    environment: UUID
    incarnation: UUID
    generation: UUID

    def __post_init__(self) -> None:
        require_uuids(self.environment, self.incarnation, self.generation)


@dataclass(frozen=True)
class Activation:
    environment: UUID
    serial: int
    incarnation: UUID
    target_digest: str
    manifest_digest: str

    def __post_init__(self) -> None:
        require_uuids(self.environment, self.incarnation)
        if counter(self.serial) == 0:
            raise RecoveryDenied()
        digest(self.target_digest)
        digest(self.manifest_digest)


@dataclass(frozen=True)
class Checkpoint:
    order: int = 0
    digest: str = EMPTY_DIGEST

    def __post_init__(self) -> None:
        counter(self.order)
        digest(self.digest)
        if (self.order == 0) != (self.digest == EMPTY_DIGEST):
            raise RecoveryDenied()

    def append(self, record: dict[str, object]) -> "Checkpoint":
        order = counter(self.order + 1)
        body = {"previous": self.digest, "order": order, "record": record}
        return Checkpoint(order, hashlib.sha256(canonical_json(body).encode()).hexdigest())


class ActivationState(StrEnum):
    ACTIVE = "ACTIVE"
    CLOSING = "CLOSING"
    SEALED = "SEALED"


@dataclass(frozen=True)
class Assertion:
    """Authenticated by the chosen adapter, freshly fetched outside DB locks."""

    activation: Activation
    owner: UUID
    nonce: UUID
    checkpoint: Checkpoint
    state: ActivationState

    def __post_init__(self) -> None:
        require_uuids(self.owner, self.nonce)


def validate_assertion_binding(
    assertion: Assertion,
    *,
    owner: UUID,
    nonce: UUID,
    pinned: Activation,
    verified_target_digest: str,
    observed_serial: int,
    local_open: bool,
) -> None:
    """Bind request/activation/target only; does not establish head freshness."""
    if not local_open or assertion.state != ActivationState.ACTIVE:
        raise RecoveryDenied("recovery_unavailable")
    if (
        assertion.owner != owner
        or assertion.nonce != nonce
        or assertion.activation != pinned
        or pinned.target_digest != digest(verified_target_digest)
        or assertion.activation.serial < counter(observed_serial)
    ):
        raise RecoveryDenied()


def validate_admission(
    assertion: Assertion,
    *,
    owner: UUID,
    nonce: UUID,
    pinned: Activation,
    verified_target_digest: str,
    observed_serial: int,
    local_checkpoint: Checkpoint,
    local_open: bool,
) -> None:
    """Recheck under the shared DB fence after waits; never authenticate here.

    The caller must verify actual target identity through the approved platform,
    not obtain verified_target_digest from a copied control row or HTTP header.
    A different head requires refetch/reconciliation; integer order is no proof
    of ancestry. No clock/lease or stale cached assertion fallback is supplied.
    """
    validate_assertion_binding(
        assertion,
        owner=owner,
        nonce=nonce,
        pinned=pinned,
        verified_target_digest=verified_target_digest,
        observed_serial=observed_serial,
        local_open=local_open,
    )
    if assertion.checkpoint != local_checkpoint:
        raise RecoveryDenied()


@dataclass(frozen=True)
class Intent:
    owner: UUID
    mutation: UUID
    attempt: UUID
    root: UUID
    origin: Origin
    activation_serial: int
    request_digest: str

    def __post_init__(self) -> None:
        require_uuids(self.owner, self.mutation, self.attempt, self.root)
        if counter(self.activation_serial) == 0:
            raise RecoveryDenied()
        digest(self.request_digest)

    def metadata(self) -> dict[str, object]:
        return {
            "schema_version": 2,
            "owner": str(self.owner),
            "mutation": str(self.mutation),
            "attempt": str(self.attempt),
            "root": str(self.root),
            "environment": str(self.origin.environment),
            "incarnation": str(self.origin.incarnation),
            "generation": str(self.origin.generation),
            "activation_serial": self.activation_serial,
            "request_digest": self.request_digest,
        }


class OutcomeStatus(StrEnum):
    ACCEPTED = "accepted"
    CONFLICT = "conflict"
    REJECTED = "rejected"


class OutcomeCode(StrEnum):
    """Closed Phase 0 domain vocabulary; no free text in independent receipts."""

    REVISION_CONFLICT = "revision_conflict"
    DUPLICATE_ID = "duplicate_id"
    RETIRED_ID = "retired_id"
    NOT_FOUND = "not_found"
    INVALID_TRANSITION = "invalid_transition"
    LOAD_CONVENTION_MISMATCH = "load_convention_mismatch"
    REP_CONVENTION_MISMATCH = "rep_convention_mismatch"
    INVALID_COMPLETION_SEQUENCE = "invalid_completion_sequence"
    IMMUTABLE_COMPLETION_SEQUENCE = "immutable_completion_sequence"
    ALREADY_EXISTS = "already_exists"
    EMPTY_SESSION = "empty_session"


@dataclass(frozen=True)
class TerminalOutcome:
    """Minimal immutable workout result, sufficient without a payload backup.

    No projection, note, exercise/set values, raw command or free-text error can
    be retained here. This is an internal value, not O3's certificate format or
    a public response DTO. Initialization/lifecycle results require their own
    reviewed scope. A retry's `duplicate` label is not a second terminal fact.
    """

    status: OutcomeStatus
    accepted_revision: int | None = None
    accepted_at: str | None = None
    expected_revision: int | None = None
    current_revision: int | None = None
    error_code: OutcomeCode | None = None

    def __post_init__(self) -> None:
        if not isinstance(self.status, OutcomeStatus) or (
            self.error_code is not None and not isinstance(self.error_code, OutcomeCode)
        ):
            raise RecoveryDenied()
        for value in (self.accepted_revision, self.expected_revision, self.current_revision):
            if value is not None:
                counter(value)
        if self.status == OutcomeStatus.ACCEPTED:
            if (
                not self.accepted_revision
                or not isinstance(self.accepted_at, str)
                or self.expected_revision is not None
                or self.current_revision is not None
                or self.error_code is not None
            ):
                raise RecoveryDenied()
            # Match the existing result contract, but also reject impossible
            # calendar dates. Preserve the exact original timestamp spelling.
            try:
                AcceptedResult.model_validate(
                    {
                        "mutation_id": UUID(int=0),
                        "aggregate_id": UUID(int=0),
                        "status": "accepted",
                        "accepted_revision": self.accepted_revision,
                        "accepted_at": self.accepted_at,
                    }
                )
                datetime.fromisoformat(self.accepted_at)
            except (ValidationError, ValueError):
                raise RecoveryDenied() from None
        elif self.status == OutcomeStatus.CONFLICT:
            if (
                self.expected_revision is None
                or self.current_revision is None
                or self.expected_revision == self.current_revision
                or self.error_code != OutcomeCode.REVISION_CONFLICT
                or self.accepted_revision is not None
                or self.accepted_at is not None
            ):
                raise RecoveryDenied()
        elif (
            self.error_code is None
            or self.error_code == OutcomeCode.REVISION_CONFLICT
            or self.accepted_revision is not None
            or self.accepted_at is not None
            or self.expected_revision is not None
            or self.current_revision is not None
        ):
            raise RecoveryDenied()

    def result(self, intent: Intent) -> dict[str, object]:
        """Reconstruct only the exact terminal result, never workout payload."""
        result: dict[str, object] = {
            "mutation_id": str(intent.mutation),
            "aggregate_id": str(intent.root),
            "status": self.status.value,
        }
        if self.status == OutcomeStatus.ACCEPTED:
            result.update(accepted_revision=self.accepted_revision, accepted_at=self.accepted_at)
        else:
            assert self.error_code is not None
            result["error"] = {"code": self.error_code.value, "retryable": False}
            if self.status == OutcomeStatus.CONFLICT:
                result.update(
                    expected_revision=self.expected_revision, current_revision=self.current_revision
                )
        return result

    def result_digest(self, intent: Intent) -> str:
        return hashlib.sha256(canonical_json(self.result(intent)).encode()).hexdigest()


@dataclass(frozen=True)
class CommittedMarker:
    """Immutable effect/result binding; constructing it is not commit proof.

    B3 may construct it while writing its transaction. Only O3's separate trusted
    observation of the persisted committed marker after that transaction closes
    can authorize certification. No payload, raw command or credentials belong
    in independent evidence. The digest and minimal outcome must agree; a digest
    alone cannot recover the deterministic outcome when a primary receipt is lost.
    """

    intent: Intent
    marker_digest: str
    result_digest: str
    outcome: TerminalOutcome
    private_position: int | None
    erasure_epoch: int
    affected_ids: tuple[UUID, ...]
    retired_ids: tuple[UUID, ...] = ()

    def __post_init__(self) -> None:
        digest(self.marker_digest)
        digest(self.result_digest)
        if self.result_digest != self.outcome.result_digest(self.intent):
            raise RecoveryDenied()
        for values in (self.affected_ids, self.retired_ids):
            if not isinstance(values, tuple) or any(
                not isinstance(value, UUID) for value in values
            ):
                raise RecoveryDenied()
            if len(set(values)) != len(values):
                raise RecoveryDenied()
        if self.outcome.status == OutcomeStatus.ACCEPTED:
            if (
                self.private_position is None
                or counter(self.private_position) == 0
                or self.intent.root not in self.affected_ids
            ):
                raise RecoveryDenied()
        elif self.private_position is not None or self.retired_ids or self.affected_ids:
            # Rejected/conflicted intents cannot invent feed or deletion effects.
            raise RecoveryDenied()
        counter(self.erasure_epoch)
        if self.retired_ids and self.intent.root not in self.retired_ids:
            raise RecoveryDenied()
        if not set(self.retired_ids) <= set(self.affected_ids):
            raise RecoveryDenied()

    def metadata(self) -> dict[str, object]:
        return {
            **self.intent.metadata(),
            "marker_digest": self.marker_digest,
            "result_digest": self.result_digest,
            "outcome": self.outcome.result(self.intent),
            "private_position": self.private_position,
            "erasure_epoch": self.erasure_epoch,
            "affected_ids": [str(value) for value in self.affected_ids],
            "retired_ids": [str(value) for value in self.retired_ids],
        }


@dataclass(frozen=True)
class Certificate:
    committed: CommittedMarker
    checkpoint: Checkpoint


@dataclass(frozen=True)
class OwnerEvidence:
    """Immutable compare-and-append reducer, persisted atomically by an adapter.

    The separate provider must supply durable linearizable head reads/CAS and
    nonrollbackable completeness. This reducer makes no storage/trust claim.
    """

    owner: UUID
    activation: Activation
    generation: UUID
    checkpoint: Checkpoint = Checkpoint()
    prepared: Intent | None = None
    prepared_from: Checkpoint | None = None
    unresolved: bool = False
    certificates: tuple[Certificate, ...] = ()
    high_water: int = 0

    def __post_init__(self) -> None:
        require_uuids(self.owner, self.generation)
        counter(self.high_water)
        if (self.prepared is None) != (self.prepared_from is None):
            raise RecoveryDenied()
        if self.prepared_from is not None and self.prepared_from.order >= self.checkpoint.order:
            raise RecoveryDenied()
        if self.unresolved and self.prepared is None:
            raise RecoveryDenied()
        if self.prepared is not None and (
            self.prepared.owner != self.owner
            or self.prepared.origin
            != Origin(self.activation.environment, self.activation.incarnation, self.generation)
            or self.prepared.activation_serial != self.activation.serial
        ):
            raise RecoveryDenied()
        order, epoch = 0, 0
        reconstructed = Checkpoint()
        mutations: set[UUID] = set()
        attempts: set[UUID] = set()
        for certificate in self.certificates:
            marker = certificate.committed
            if (
                marker.intent.owner != self.owner
                or marker.intent.origin.environment != self.activation.environment
                or marker.intent.mutation in mutations
                or marker.intent.attempt in attempts
                or not order < certificate.checkpoint.order <= self.checkpoint.order
                or not epoch <= marker.erasure_epoch <= self.high_water
            ):
                raise RecoveryDenied()
            mutations.add(marker.intent.mutation)
            attempts.add(marker.intent.attempt)
            order, epoch = certificate.checkpoint.order, marker.erasure_epoch
            preparation = reconstructed.append({"kind": "PREPARED", **marker.intent.metadata()})
            committed = {"kind": "CERTIFIED", **marker.metadata()}
            uncertain = preparation.append({"kind": "UNRESOLVED", **marker.intent.metadata()})
            if certificate.checkpoint not in (
                preparation.append(committed),
                uncertain.append(committed),
            ):
                raise RecoveryDenied()
            reconstructed = certificate.checkpoint
        if self.prepared is not None:
            if (
                self.prepared_from != reconstructed
                or self.prepared.mutation in mutations
                or self.prepared.attempt in attempts
            ):
                raise RecoveryDenied()
            reconstructed = self.preparation_checkpoint()
            if self.unresolved:
                reconstructed = reconstructed.append(
                    {"kind": "UNRESOLVED", **self.prepared.metadata()}
                )
        if self.checkpoint != reconstructed:
            raise RecoveryDenied()

    def _compare(self, expected: Checkpoint) -> None:
        if expected != self.checkpoint:
            raise RecoveryDenied()

    def lookup(self, mutation: UUID, request_digest: str) -> Certificate | None:
        for certificate in self.certificates:
            intent = certificate.committed.intent
            if intent.mutation == mutation:
                if intent.request_digest != request_digest:
                    raise RecoveryDenied("mutation_digest_mismatch")
                return certificate
        if self.prepared and self.prepared.mutation == mutation:
            if self.prepared.request_digest != request_digest:
                raise RecoveryDenied("mutation_digest_mismatch")
        return None

    def prepare(
        self, intent: Intent, expected: Checkpoint, state: ActivationState
    ) -> "OwnerEvidence":
        if intent.owner != self.owner:
            raise RecoveryDenied()
        # Consult immutable historical bindings before deciding whether lineage
        # is current. A historical certificate is never a new effect permit.
        if self.lookup(intent.mutation, intent.request_digest) is not None:
            raise RecoveryDenied("timeline_reconciliation_required")
        if any(item.committed.intent.attempt == intent.attempt for item in self.certificates):
            raise RecoveryDenied()
        if self.prepared == intent and expected in (self.prepared_from, self.checkpoint):
            return self  # Idempotent recovery of PREPARED, including while closing.
        self._compare(expected)
        if state != ActivationState.ACTIVE:
            raise RecoveryDenied("recovery_unavailable")
        if self.prepared is not None:
            raise RecoveryDenied("publication_pending")
        if (
            intent.origin
            != Origin(self.activation.environment, self.activation.incarnation, self.generation)
            or intent.activation_serial != self.activation.serial
        ):
            raise RecoveryDenied("timeline_reconciliation_required")
        return replace(
            self,
            prepared=intent,
            prepared_from=self.checkpoint,
            checkpoint=self.checkpoint.append({"kind": "PREPARED", **intent.metadata()}),
        )

    def preparation_checkpoint(self) -> Checkpoint:
        if self.prepared is None or self.prepared_from is None:
            raise RecoveryDenied()
        return self.prepared_from.append({"kind": "PREPARED", **self.prepared.metadata()})

    def certify(
        self, committed: CommittedMarker, expected: Checkpoint, state: ActivationState
    ) -> "OwnerEvidence":
        intent = committed.intent
        if intent.owner != self.owner:
            raise RecoveryDenied()
        previous = self.lookup(intent.mutation, intent.request_digest)
        if previous is not None:
            if previous.committed != committed:
                raise RecoveryDenied()
            return self  # Retrieval of existing evidence remains legal after seal.
        self._compare(expected)
        if state == ActivationState.SEALED or self.prepared != intent:
            raise RecoveryDenied()
        if committed.erasure_epoch < self.high_water:
            raise RecoveryDenied()
        checkpoint = self.checkpoint.append({"kind": "CERTIFIED", **committed.metadata()})
        return replace(
            self,
            checkpoint=checkpoint,
            prepared=None,
            prepared_from=None,
            unresolved=False,
            certificates=(*self.certificates, Certificate(committed, checkpoint)),
            high_water=committed.erasure_epoch,
        )

    def uncertain(self, expected: Checkpoint) -> "OwnerEvidence":
        self._compare(expected)
        if self.prepared is None:
            raise RecoveryDenied()
        if self.unresolved:
            return self
        return replace(
            self,
            unresolved=True,
            checkpoint=self.checkpoint.append({"kind": "UNRESOLVED", **self.prepared.metadata()}),
        )

    def require_sealable(self) -> None:
        if self.prepared is not None or self.unresolved:
            raise RecoveryDenied("publication_pending")


class RecoveryAuthority(Protocol):
    """Authenticated scoped adapter; implementations must not use restored DB state.

    No default provider or production configuration is selected. All methods are
    external boundaries and must be called with no DB/SQLite transaction open.
    Missing/unavailable authority must raise RecoveryDenied, never fabricate IDLE.
    """

    def current(self, activation: Activation, owner: UUID, nonce: UUID) -> Assertion: ...

    def prepare(self, intent: Intent, expected: Checkpoint) -> Checkpoint: ...

    def certify(self, marker: CommittedMarker, expected: Checkpoint) -> Certificate: ...

    def lookup(self, owner: UUID, mutation: UUID, request_digest: str) -> Certificate | None: ...
