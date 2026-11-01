"""Routine aggregate rules, invoked only by the guarded sync transaction."""

from collections.abc import Iterator
from typing import Any
from uuid import UUID

from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from daily_motion.models import (
    Change,
    Exercise,
    OwnerState,
    RetiredId,
    Routine,
    RoutineTemplate,
    Snapshot,
    Workout,
    WorkoutSet,
)
from daily_motion.routine_contracts import PublishRoutineTemplate, RoutineOperation
from daily_motion.sync import DomainError


def apply_routine_change(
    db: Session, owner: UUID, op: RoutineOperation, state: OwnerState, routine: Routine | None
) -> Routine:
    payload = PublishRoutineTemplate.model_validate(op.payload)
    identifiers = [payload.template_id]
    if op.command == "create_routine":
        identifiers.append(op.aggregate_id)
    # The accepted workout transport's retirement namespace is shared. A root
    # or template cannot alias a workout/child, otherwise workout erasure could
    # redact planning feed entries or strand a live routine under a retired ID.
    for model in (Workout, Exercise, WorkoutSet, Routine, RoutineTemplate):
        if db.scalar(select(model.id).where(model.owner_id == owner, model.id.in_(identifiers))):
            raise DomainError("duplicate_id")
    if op.command == "create_routine":
        if routine is not None:
            raise DomainError("already_exists")
        routine = Routine(
            owner_id=owner,
            id=op.aggregate_id,
            revision=1,
            current_template_id=payload.template_id,
        )
        db.add(routine)
        db.flush()
    else:
        if routine is None:
            raise DomainError("not_found")
        if routine.current_template_id != payload.predecessor_template_id:
            raise DomainError("template_lineage_mismatch")
        routine.revision += 1
        routine.current_template_id = payload.template_id
    if db.get(RoutineTemplate, (owner, payload.template_id)) is not None:
        raise DomainError("duplicate_id")
    if db.get(RetiredId, (owner, payload.template_id)) is not None:
        raise DomainError("retired_id")
    if payload.template_id == op.aggregate_id:
        raise DomainError("duplicate_id")
    db.add(
        RoutineTemplate(
            owner_id=owner,
            id=payload.template_id,
            routine_id=op.aggregate_id,
            revision=routine.revision,
            predecessor_template_id=payload.predecessor_template_id,
            # Retain the accepted prescription, including omitted optional fields.
            prescription=op.payload["prescription"],
        )
    )
    # This monotonically raised boundary applies to ALL v1 sync publication and
    # mutations, not just pages containing a routine. Never filter owner state.
    state.minimum_sync_contract = 3
    return routine


def routine_projections(db: Session, owner: UUID, routine: Routine) -> Iterator[dict[str, Any]]:
    # Stream immutable versions rather than allocating an unbounded root before
    # checking snapshot/page limits. One version fits its bounded command.
    for offset, template in enumerate(
        db.scalars(
            select(RoutineTemplate)
            .where(RoutineTemplate.owner_id == owner, RoutineTemplate.routine_id == routine.id)
            .order_by(RoutineTemplate.revision)
            .execution_options(yield_per=32)
        )
    ):
        yield {
            "aggregate_type": "routine",
            "aggregate_id": str(routine.id),
            "revision": routine.revision,
            "current_template_id": str(routine.current_template_id),
            "template_offset": offset,
            "templates": [
                {
                    "template_id": str(template.id),
                    "revision": template.revision,
                    "predecessor_template_id": (
                        str(template.predecessor_template_id)
                        if template.predecessor_template_id
                        else None
                    ),
                    "prescription": template.prescription,
                }
            ],
        }


def erase_routine_planning(db: Session, owner: UUID) -> None:
    """Retirement cleanup; caller holds the disabled owner's row lock."""
    for change in db.scalars(
        select(Change).where(
            Change.owner_id == owner,
            Change.body["operation"]["aggregate_type"].astext == "routine",
        )
    ):
        change.body = {
            "aggregate_id": str(change.session_id),
            "redacted": True,
            "retired_ids": [str(change.session_id)],
        }
    db.execute(delete(Snapshot).where(Snapshot.owner_id == owner))
    db.execute(delete(Routine).where(Routine.owner_id == owner))
