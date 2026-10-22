"""Internal B1 reservation primitive; no public DRP/2 route or activation.

The future authenticated authority/actual-target adapter must supply Admission
outside this transaction. Constructing these values is not authentication. This
module never selects a provider, invents target proof, publishes a result, or
resolves lifecycle/initial-inventory policy. Only already initialized owners are
supported here; first initialization still needs its separate lifecycle path.
"""

import hashlib
from collections.abc import Mapping
from dataclasses import dataclass
from typing import Any
from uuid import UUID

from pydantic import ValidationError
from sqlalchemy import select, text
from sqlalchemy.orm import Session

from daily_motion.contracts import OperationV2, canonical_json
from daily_motion.db import assert_runtime_role
from daily_motion.models import AccountRetirement, OwnerState, Receipt
from daily_motion.recovery import (
    Activation,
    Assertion,
    Checkpoint,
    Intent,
    Origin,
    RecoveryDenied,
    counter,
    validate_admission,
    validate_assertion_binding,
)
from daily_motion.recovery_db import require_read_committed, shared_fence


@dataclass(frozen=True)
class Admission:
    """Inputs from a future verified adapter; never a client DTO or flag."""

    assertion: Assertion
    nonce: UUID
    pinned: Activation
    verified_target_digest: str
    observed_serial: int


@dataclass(frozen=True)
class Reservation:
    intent: Intent
    prior: Checkpoint
    frozen_body: str

    def __post_init__(self) -> None:
        try:
            operation = OperationV2.model_validate_json(self.frozen_body)
        except ValidationError:
            raise RecoveryDenied() from None
        if (
            self.frozen_body != canonical_json(operation.model_dump(mode="json"))
            or hashlib.sha256(self.frozen_body.encode()).hexdigest() != self.intent.request_digest
            or operation.mutation_id != self.intent.mutation
            or operation.aggregate_id != self.intent.root
            or Origin(
                operation.environment_id, operation.origin_incarnation, operation.origin_generation
            )
            != self.intent.origin
        ):
            raise RecoveryDenied()

    @property
    def prepared_checkpoint(self) -> Checkpoint:
        return self.prior.append({"kind": "PREPARED", **self.intent.metadata()})

    def storage(self) -> dict[str, object]:
        return {
            "operation": OperationV2.model_validate_json(self.frozen_body).model_dump(mode="json"),
            "intent": self.intent.metadata(),
            "prior_checkpoint": {"order": self.prior.order, "digest": self.prior.digest},
        }

    @classmethod
    def restore(cls, row: Mapping[str, Any]) -> "Reservation":
        stored = row["frozen_request"]
        if (
            not isinstance(stored, dict)
            or set(stored) != {"operation", "intent", "prior_checkpoint"}
            or not isinstance(row["aggregate_id"], UUID)
        ):
            raise RecoveryDenied()
        try:
            intent = Intent(
                row["owner_id"],
                row["mutation_id"],
                row["attempt_id"],
                row["aggregate_id"],
                Origin(row["environment_id"], row["incarnation"], row["generation"]),
                row["activation_serial"],
                row["request_digest"],
            )
            if stored["intent"] != intent.metadata():
                raise RecoveryDenied()
            prior = Checkpoint(**stored["prior_checkpoint"])
            return cls(intent, prior, canonical_json(stored["operation"]))
        except (KeyError, TypeError, ValueError):
            raise RecoveryDenied() from None


def _reserve(
    session: Session,
    owner: UUID,
    operation: OperationV2,
    admission: Admission,
    candidate_attempt: UUID,
    *,
    allow_new: bool,
) -> Reservation:
    """B1 only: durable request + stable T + owner hold, in one caller transaction.

    No external call, domain projection/feed/receipt mutation, account creation,
    historical success or publication occurs. A copied OPEN control alone never
    supplies Admission. Existing outcomes remain pending until O3's real trusted
    certificate validation/publication implementation exists.
    """
    if not session.in_transaction():
        raise RecoveryDenied()
    require_read_committed(session)
    shared_fence(session)
    assert_runtime_role(session)
    control = (
        session.execute(text("SELECT * FROM recovery.control WHERE singleton"))
        .mappings()
        .one_or_none()
    )
    if control is None:
        raise RecoveryDenied()
    pinned = Activation(
        control["environment_id"],
        control["activation_serial"],
        control["incarnation"],
        control["target_digest"],
        control["manifest_digest"],
    )
    if pinned != admission.pinned:
        raise RecoveryDenied()
    # Bind identity before owner-private reads. The actual durable checkpoint
    # comparison remains mandatory after ordered owner/attempt locks below.
    validate_assertion_binding(
        admission.assertion,
        owner=owner,
        nonce=admission.nonce,
        pinned=pinned,
        verified_target_digest=admission.verified_target_digest,
        observed_serial=admission.observed_serial,
        local_open=control["state"] == "OPEN",
    )
    session.execute(text("SELECT set_config('app.owner_id',:owner,true)"), {"owner": str(owner)})
    # Fresh populate_existing defeats cached pre-wait ORM/account state. No
    # owner initialization occurs, so no initialization advisory lock is needed.
    state = session.scalar(
        select(OwnerState)
        .where(OwnerState.owner_id == owner)
        .with_for_update()
        .execution_options(populate_existing=True)
    )
    metadata = (
        session.execute(
            text("SELECT * FROM training.recovery_owners WHERE owner_id=:owner FOR UPDATE"),
            {"owner": owner},
        )
        .mappings()
        .one_or_none()
    )
    if state is None or metadata is None:
        raise RecoveryDenied()
    if state.status != "active" or session.get(AccountRetirement, owner) is not None:
        # An uncertified lifecycle transition must not become a false erasure
        # instruction. The future lifecycle/independent-denial path is separate.
        raise RecoveryDenied("recovery_unavailable")
    origin = Origin(metadata["environment_id"], metadata["incarnation"], metadata["generation"])
    if origin != Origin(pinned.environment, pinned.incarnation, state.generation):
        raise RecoveryDenied()
    prior = Checkpoint(metadata["evidence_order"], metadata["evidence_digest"])
    high_water = counter(metadata["erasure_high_water"])
    local_epoch = counter(state.erasure_epoch)
    body = canonical_json(operation.model_dump(mode="json"))
    request_digest = hashlib.sha256(body.encode()).hexdigest()
    existing = (
        session.execute(
            text("""SELECT * FROM training.recovery_attempts
          WHERE owner_id=:owner AND mutation_id=:mutation FOR UPDATE"""),
            {"owner": owner, "mutation": operation.mutation_id},
        )
        .mappings()
        .one_or_none()
    )
    held: Reservation | None = None
    expected = prior
    if existing is not None and existing["state"] == "RESERVED":
        held = Reservation.restore(dict(existing))
        if (
            metadata["hold_attempt"] != held.intent.attempt
            or held.prior != prior
            or held.intent.origin != origin
            or held.intent.activation_serial != pinned.serial
        ):
            raise RecoveryDenied()
        # Exact B2 response-loss retry may observe the known PREPARED head;
        # arbitrary newer/divergent prefixes never repair the local anchor.
        if admission.assertion.checkpoint == held.prepared_checkpoint:
            expected = held.prepared_checkpoint
    elif metadata["hold_attempt"] is not None:
        blocking = (
            session.execute(
                text("""SELECT * FROM training.recovery_attempts
              WHERE owner_id=:owner AND attempt_id=:attempt FOR UPDATE"""),
                {"owner": owner, "attempt": metadata["hold_attempt"]},
            )
            .mappings()
            .one_or_none()
        )
        if blocking is None or blocking["state"] not in (
            "RESERVED",
            "EFFECT_COMMITTED",
            "UNRESOLVED",
        ):
            raise RecoveryDenied()
        if blocking["state"] == "RESERVED":
            active = Reservation.restore(dict(blocking))
            if (
                active.prior != prior
                or active.intent.origin != origin
                or active.intent.activation_serial != pinned.serial
            ):
                raise RecoveryDenied()
            if admission.assertion.checkpoint == active.prepared_checkpoint:
                expected = active.prepared_checkpoint
    validate_admission(
        admission.assertion,
        owner=owner,
        nonce=admission.nonce,
        pinned=pinned,
        verified_target_digest=admission.verified_target_digest,
        observed_serial=admission.observed_serial,
        local_checkpoint=expected,
        local_open=control["state"] == "OPEN",
    )
    if existing is not None:
        if existing["request_digest"] != request_digest:
            raise RecoveryDenied("mutation_digest_mismatch")
        if existing["state"] != "RESERVED":
            raise RecoveryDenied("publication_pending")
    if held is not None:
        if held.frozen_body != body or high_water < local_epoch:
            raise RecoveryDenied()
        return held
    if (
        Origin(operation.environment_id, operation.origin_incarnation, operation.origin_generation)
        != origin
    ):
        raise RecoveryDenied("timeline_reconciliation_required")
    if metadata["hold_attempt"] is not None:
        raise RecoveryDenied("publication_pending")
    if not allow_new or high_water < local_epoch:
        raise RecoveryDenied()
    legacy = session.get(Receipt, (owner, operation.mutation_id))
    if legacy is not None:
        # A retained primary receipt without its verified V2 attempt cannot
        # authorize a fresh effect, even if its payload/archive was lost.
        if legacy.digest != request_digest:
            raise RecoveryDenied("mutation_digest_mismatch")
        raise RecoveryDenied("timeline_reconciliation_required")
    if counter(state.position) != counter(metadata["visible_position"]):
        raise RecoveryDenied()
    reservation = Reservation(
        Intent(
            owner,
            operation.mutation_id,
            candidate_attempt,
            operation.aggregate_id,
            origin,
            pinned.serial,
            request_digest,
        ),
        prior,
        body,
    )
    session.execute(
        text("""INSERT INTO training.recovery_attempts(owner_id,attempt_id,mutation_id,
          aggregate_id,schema_version,environment_id,incarnation,generation,
          activation_serial,request_digest,state,frozen_request)
          VALUES(:owner,:attempt,:mutation,:root,2,:environment,:incarnation,:generation,
          :serial,:digest,'RESERVED',CAST(:request AS jsonb))"""),
        {
            "owner": owner,
            "attempt": reservation.intent.attempt,
            "mutation": operation.mutation_id,
            "root": operation.aggregate_id,
            "environment": origin.environment,
            "incarnation": origin.incarnation,
            "generation": origin.generation,
            "serial": pinned.serial,
            "digest": request_digest,
            "request": canonical_json(reservation.storage()),
        },
    )
    session.execute(
        text("UPDATE training.recovery_owners SET hold_attempt=:attempt WHERE owner_id=:owner"),
        {"attempt": reservation.intent.attempt, "owner": owner},
    )
    return reservation


def reserve(
    session: Session,
    owner: UUID,
    operation: OperationV2,
    admission: Admission,
    candidate_attempt: UUID,
) -> Reservation:
    """B1: reserve a new command or retrieve the same still-reserved command."""
    return _reserve(session, owner, operation, admission, candidate_attempt, allow_new=True)


def resume_prepared(
    session: Session,
    owner: UUID,
    reservation: Reservation,
    admission: Admission,
) -> None:
    """B3 precondition: never create a missing reservation or infer preparation.

    The future adapter must independently verify unchanged target continuity;
    rollback/unknown continuity requires UNRESOLVED, not this automatic path.
    Matching an authenticated fresh head to the complete PREPARED record binds
    its exact T/M/D/origin/prior anchor. This supplies no provider authentication.
    """
    operation = OperationV2.model_validate_json(reservation.frozen_body)
    stored = _reserve(
        session, owner, operation, admission, reservation.intent.attempt, allow_new=False
    )
    if stored != reservation or admission.assertion.checkpoint != stored.prepared_checkpoint:
        raise RecoveryDenied()
