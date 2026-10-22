"""Internal committed-row observation; no certificate, authority or public route.

This checks a known B3 marker using a separate short transaction on the original
target. It is not O3's authenticated certifier or proof of unchanged target
continuity. The future verified adapter must supply fresh Admission outside DB
locks. CLOSED-target reconciliation and lost-marker recovery remain unavailable.
"""

import hashlib
from datetime import datetime
from uuid import UUID

from sqlalchemy import Engine, select, text
from sqlalchemy.orm import Session

from daily_motion.contracts import OperationV2, canonical_json
from daily_motion.db import assert_runtime_role
from daily_motion.models import (
    AccountRetirement,
    Change,
    Exercise,
    ObservationRevision,
    OwnerState,
    Receipt,
    RetiredId,
    Snapshot,
    Workout,
    WorkoutSet,
)
from daily_motion.recovery import (
    Activation,
    Checkpoint,
    CommittedMarker,
    Origin,
    OutcomeStatus,
    RecoveryDenied,
    counter,
    validate_admission,
    validate_assertion_binding,
)
from daily_motion.recovery_admission import Admission, Reservation
from daily_motion.recovery_db import require_read_committed, shared_fence
from daily_motion.recovery_effect import _affected


def _same_json(left: object, right: object) -> bool:
    # Python equality treats True/1 and 1.0/1 as equal; stored evidence must not.
    try:
        return canonical_json(left) == canonical_json(right)
    except (TypeError, ValueError):
        raise RecoveryDenied() from None


def _check_effect(
    session: Session,
    marker: CommittedMarker,
    operation: OperationV2,
    state: OwnerState,
    visible: int,
    high_water: int,
) -> None:
    intent = marker.intent
    if (
        counter(state.erasure_epoch) != marker.erasure_epoch
        or counter(state.minimum_position) > visible
    ):
        raise RecoveryDenied()
    if marker.outcome.status != OutcomeStatus.ACCEPTED:
        if counter(state.position) != visible or marker.erasure_epoch != high_water:
            raise RecoveryDenied()
        return
    if (
        counter(state.position) != marker.private_position
        or counter(visible + 1) != marker.private_position
        or marker.affected_ids != _affected(operation, list(marker.retired_ids), marker.outcome)
    ):
        raise RecoveryDenied()
    change = session.get(Change, (intent.owner, marker.private_position))
    workout = session.get(Workout, (intent.owner, intent.root))
    if (
        change is None
        or change.session_id != intent.root
        or marker.outcome.accepted_at is None
        or change.created_at != datetime.fromisoformat(marker.outcome.accepted_at)
    ):
        raise RecoveryDenied()
    if operation.command != "delete_session":
        if (
            marker.retired_ids
            or marker.erasure_epoch != high_water
            or workout is None
            or workout.revision != marker.outcome.accepted_revision
            or not _same_json(
                change.body,
                {"operation": operation.model_dump(mode="json"), "revision": workout.revision},
            )
        ):
            raise RecoveryDenied()
        return
    if (
        workout is not None
        or not marker.retired_ids
        or marker.erasure_epoch != counter(high_water + 1)
    ):
        raise RecoveryDenied()
    expected_ids = {str(value) for value in marker.retired_ids}
    retired = set(
        session.scalars(
            select(RetiredId.id).where(
                RetiredId.owner_id == intent.owner, RetiredId.id.in_(marker.retired_ids)
            )
        )
    )
    if retired != set(marker.retired_ids):
        raise RecoveryDenied()
    # Observe suppression as well as the epoch: missing retirement evidence or
    # a restored payload copy cannot be justified by a deletion marker alone.
    for model in (Workout, Exercise, WorkoutSet):
        if (
            session.scalar(
                select(model.id).where(
                    model.owner_id == intent.owner, model.id.in_(marker.retired_ids)
                )
            )
            is not None
        ):
            raise RecoveryDenied()
    if session.scalar(
        select(ObservationRevision.session_id).where(
            ObservationRevision.owner_id == intent.owner,
            ObservationRevision.session_id == intent.root,
        )
    ) is not None or session.scalar(select(Snapshot.id).where(Snapshot.owner_id == intent.owner)):
        raise RecoveryDenied()
    for row in session.scalars(
        select(Change).where(Change.owner_id == intent.owner, Change.session_id == intent.root)
    ):
        body = row.body
        if not isinstance(body, dict):
            raise RecoveryDenied()
        identifiers = body.get("retired_ids")
        if (
            set(body) != {"aggregate_id", "redacted", "retired_ids"}
            or body["aggregate_id"] != str(intent.root)
            or body["redacted"] is not True
            or not isinstance(identifiers, list)
            or any(not isinstance(value, str) for value in identifiers)
            or len(identifiers) != len(expected_ids)
            or set(identifiers) != expected_ids
        ):
            raise RecoveryDenied()


def observe_committed(
    bind: Engine, owner: UUID, marker: CommittedMarker, admission: Admission
) -> CommittedMarker:
    """Validate a known B3 result after its transaction, without publishing it.

    An Engine is required so the caller cannot lend its uncommitted transaction
    or cached ORM state. The session and all locks close before this function
    returns. A returned value remains internal metadata, never a certificate or
    permission to append evidence/publish. No external operation occurs here.
    """
    if not isinstance(bind, Engine) or owner != marker.intent.owner:
        raise RecoveryDenied()
    binding = marker.metadata()
    del binding["marker_digest"]
    expected_digest = hashlib.sha256(
        canonical_json({"kind": "EFFECT_COMMITTED", **binding}).encode()
    ).hexdigest()
    if marker.marker_digest != expected_digest:
        raise RecoveryDenied()
    with Session(bind, autoflush=False) as session, session.begin():
        session.execute(text("SET LOCAL statement_timeout = '5s'"))
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
        validate_assertion_binding(
            admission.assertion,
            owner=owner,
            nonce=admission.nonce,
            pinned=pinned,
            verified_target_digest=admission.verified_target_digest,
            observed_serial=admission.observed_serial,
            local_open=control["state"] == "OPEN",
        )
        session.execute(
            text("SELECT set_config('app.owner_id',:owner,true)"), {"owner": str(owner)}
        )
        state = session.scalar(
            select(OwnerState).where(OwnerState.owner_id == owner).with_for_update()
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
            raise RecoveryDenied("recovery_unavailable")
        origin = Origin(metadata["environment_id"], metadata["incarnation"], metadata["generation"])
        if (
            origin != marker.intent.origin
            or origin != Origin(pinned.environment, pinned.incarnation, state.generation)
            or marker.intent.activation_serial != pinned.serial
            or metadata["hold_attempt"] != marker.intent.attempt
        ):
            raise RecoveryDenied()
        checkpoint = Checkpoint(metadata["evidence_order"], metadata["evidence_digest"])
        validate_admission(
            admission.assertion,
            owner=owner,
            nonce=admission.nonce,
            pinned=pinned,
            verified_target_digest=admission.verified_target_digest,
            observed_serial=admission.observed_serial,
            local_checkpoint=checkpoint,
            local_open=control["state"] == "OPEN",
        )
        attempt = (
            session.execute(
                text("""SELECT * FROM training.recovery_attempts
                  WHERE owner_id=:owner AND attempt_id=:attempt FOR UPDATE"""),
                {"owner": owner, "attempt": marker.intent.attempt},
            )
            .mappings()
            .one_or_none()
        )
        if (
            attempt is None
            or attempt["state"] != "EFFECT_COMMITTED"
            or attempt["certificate"] is not None
        ):
            raise RecoveryDenied()
        reservation = Reservation.restore(dict(attempt))
        if (
            reservation.intent != marker.intent
            or reservation.prepared_checkpoint != checkpoint
            or not _same_json(reservation.storage(), attempt["frozen_request"])
            or not _same_json(marker.metadata(), attempt["committed_marker"])
            or not _same_json(marker.outcome.result(marker.intent), attempt["result"])
        ):
            raise RecoveryDenied()
        receipt = session.get(Receipt, (owner, marker.intent.mutation))
        if (
            receipt is None
            or receipt.digest != marker.intent.request_digest
            or not _same_json(
                receipt.acknowledgement,
                {
                    "schema_version": 2,
                    "mutation_id": str(marker.intent.mutation),
                    "aggregate_id": str(marker.intent.root),
                    "status": "publication_pending",
                },
            )
        ):
            raise RecoveryDenied()
        operation = OperationV2.model_validate_json(reservation.frozen_body)
        _check_effect(
            session,
            marker,
            operation,
            state,
            counter(metadata["visible_position"]),
            counter(metadata["erasure_high_water"]),
        )
    return marker
