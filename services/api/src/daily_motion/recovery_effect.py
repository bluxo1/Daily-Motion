"""Internal B3 private effects; no certification, publication or public route.

Only an authenticated fresh authority/actual-target adapter with independently
verified unchanged target continuity may call this boundary. No provider or proof
is selected here. The returned marker is not commit proof: B4 must separately
observe the committed row after the caller's transaction has closed (O3).
"""

import hashlib
import json
from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy import select, text
from sqlalchemy.orm import Session

from daily_motion.contracts import CreateSession, Operation, RecordSet, canonical_json
from daily_motion.models import Change, OwnerState, Receipt, RetiredId, Workout
from daily_motion.recovery import (
    CommittedMarker,
    OutcomeCode,
    OutcomeStatus,
    RecoveryDenied,
    TerminalOutcome,
    counter,
)
from daily_motion.recovery_admission import Admission, Reservation, resume_prepared
from daily_motion.sync import DomainError, apply_domain_change


def _affected(
    operation: Operation, retired: list[UUID], outcome: TerminalOutcome
) -> tuple[UUID, ...]:
    if outcome.status != OutcomeStatus.ACCEPTED:
        return ()
    identifiers = {operation.aggregate_id}
    if operation.command == "create_session":
        plan = CreateSession.model_validate(operation.payload)
        for exercise in plan.exercises:
            identifiers.add(exercise.session_exercise_id)
            identifiers.update(item.set_id for item in exercise.sets)
    elif operation.command in ("record_set", "correct_set"):
        record = RecordSet.model_validate(operation.payload)
        identifiers.update((record.session_exercise_id, record.set_id))
    elif operation.command == "delete_session":
        identifiers.update(retired)
    return tuple(sorted(identifiers, key=str))


def commit_effect(
    session: Session,
    owner: UUID,
    reservation: Reservation,
    admission: Admission,
) -> CommittedMarker:
    """Write one private deterministic outcome atomically, retaining the B1 hold.

    The caller must commit before handing work to a separate trusted observer.
    A nested transaction also protects the B1 reservation if a caller catches a
    failed write and commits its outer transaction. No external calls occur.
    An EFFECT_COMMITTED retry remains publication_pending and cannot reapply.
    """
    resume_prepared(session, owner, reservation, admission)
    intent = reservation.intent
    # Domain adapters see the same validated command surface as legacy writes;
    # only the private feed/request binding retains the full original provenance.
    wire = json.loads(reservation.frozen_body)
    domain = Operation.model_validate(
        {
            key: value
            for key, value in wire.items()
            if key
            not in {
                "schema_version",
                "environment_id",
                "origin_incarnation",
                "origin_generation",
            }
        }
    )
    with session.begin_nested():
        state = session.get(OwnerState, owner)
        if state is None or session.get(Receipt, (owner, intent.mutation)) is not None:
            raise RecoveryDenied()
        visible = session.scalar(
            text("SELECT visible_position FROM training.recovery_owners WHERE owner_id=:owner"),
            {"owner": owner},
        )
        if counter(state.position) != counter(visible):
            raise RecoveryDenied()
        workout = session.scalar(
            select(Workout)
            .where(Workout.owner_id == owner, Workout.id == intent.root)
            .with_for_update()
            .execution_options(populate_existing=True)
        )
        position: int | None = None
        retired: list[UUID] = []
        current = counter(workout.revision) if workout is not None else 0
        if session.get(RetiredId, (owner, intent.root)) is not None:
            outcome = TerminalOutcome(OutcomeStatus.REJECTED, error_code=OutcomeCode.RETIRED_ID)
        elif current != domain.expected_revision:
            outcome = TerminalOutcome(
                OutcomeStatus.CONFLICT,
                expected_revision=domain.expected_revision,
                current_revision=current,
                error_code=OutcomeCode.REVISION_CONFLICT,
            )
        else:
            try:
                with session.begin_nested():
                    # Checked capacity denies without wrapping DB counters or
                    # consuming a terminal result. The durable owner hold stays.
                    next_position = counter(state.position + 1)
                    if workout is not None:
                        counter(workout.revision + 1)
                    if domain.command == "delete_session":
                        counter(state.erasure_epoch + 1)
                    workout, retired = apply_domain_change(session, owner, domain, state, workout)
                    now = datetime.now(UTC)
                    outcome = TerminalOutcome(
                        OutcomeStatus.ACCEPTED,
                        workout.revision,
                        now.isoformat().replace("+00:00", "Z"),
                    )
                    state.position = next_position
                    position = next_position
                    session.add(
                        Change(
                            owner_id=owner,
                            position=position,
                            session_id=intent.root,
                            created_at=now,
                            body=(
                                {
                                    "aggregate_id": str(intent.root),
                                    "redacted": True,
                                    "retired_ids": [str(identifier) for identifier in retired],
                                }
                                if domain.command == "delete_session"
                                else {"operation": wire, "revision": workout.revision}
                            ),
                        )
                    )
                    session.flush()
            except DomainError as error:
                # All intermediate domain/revision writes rolled back. Retain
                # only the deterministic rejection, never the exception text.
                outcome = TerminalOutcome(
                    OutcomeStatus.REJECTED, error_code=OutcomeCode(error.code)
                )
                position, retired = None, []
        result = outcome.result(intent)
        result_digest = outcome.result_digest(intent)
        retired_ids = tuple(sorted(retired, key=str))
        affected_ids = _affected(domain, retired, outcome)
        epoch = counter(state.erasure_epoch)
        binding = {
            **intent.metadata(),
            "result_digest": result_digest,
            "outcome": result,
            "private_position": position,
            "erasure_epoch": epoch,
            "affected_ids": [str(identifier) for identifier in affected_ids],
            "retired_ids": [str(identifier) for identifier in retired_ids],
        }
        marker_digest = hashlib.sha256(
            canonical_json({"kind": "EFFECT_COMMITTED", **binding}).encode()
        ).hexdigest()
        marker = CommittedMarker(
            intent,
            marker_digest,
            result_digest,
            outcome,
            position,
            epoch,
            affected_ids,
            retired_ids,
        )
        # Receipt presence alone cannot expose accepted/conflict/rejected data.
        # The exact result is private in the attempt until B5 verifies/publishes.
        session.add(
            Receipt(
                owner_id=owner,
                mutation_id=intent.mutation,
                digest=intent.request_digest,
                acknowledgement={
                    "schema_version": 2,
                    "mutation_id": str(intent.mutation),
                    "aggregate_id": str(intent.root),
                    "status": "publication_pending",
                },
            )
        )
        changed = session.scalar(
            text("""UPDATE training.recovery_attempts SET
          state='EFFECT_COMMITTED',result=CAST(:result AS jsonb),
          committed_marker=CAST(:marker AS jsonb)
          WHERE owner_id=:owner AND attempt_id=:attempt AND state='RESERVED'
          RETURNING attempt_id"""),
            {
                "owner": owner,
                "attempt": intent.attempt,
                "result": canonical_json(result),
                "marker": canonical_json(marker.metadata()),
            },
        )
        if changed != intent.attempt:
            raise RecoveryDenied()
        anchored = session.scalar(
            text("""UPDATE training.recovery_owners SET
          evidence_order=:q,evidence_digest=:digest WHERE owner_id=:owner AND hold_attempt=:attempt
          AND evidence_order=:prior_q AND evidence_digest=:prior_digest RETURNING hold_attempt"""),
            {
                "owner": owner,
                "attempt": intent.attempt,
                "q": reservation.prepared_checkpoint.order,
                "digest": reservation.prepared_checkpoint.digest,
                "prior_q": reservation.prior.order,
                "prior_digest": reservation.prior.digest,
            },
        )
        if anchored != intent.attempt:
            raise RecoveryDenied()
        session.flush()
    return marker
