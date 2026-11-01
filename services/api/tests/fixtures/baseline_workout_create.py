"""Frozen approved-baseline workout writer, solely for pre-upgrade schema fixtures.

The function below is byte-identical to _create at
7f0c7da6cbb2ddcb72420a1fd19446f73cd9da89. Do not use the current writer
against a historical schema that cannot contain its newer aggregate tables.
"""

from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from daily_motion.contracts import CreateSession, Operation
from daily_motion.models import Exercise, RetiredId, Workout, WorkoutSet
from daily_motion.sync import DomainError


def _create(db: Session, owner: UUID, op: Operation) -> Workout:
    plan = CreateSession.model_validate(op.payload)
    ids = [op.aggregate_id]
    ids.extend(exercise.session_exercise_id for exercise in plan.exercises)
    ids.extend(item.set_id for exercise in plan.exercises for item in exercise.sets)
    if len(set(ids)) != len(ids):
        raise DomainError("duplicate_id")
    if db.scalar(select(RetiredId).where(RetiredId.owner_id == owner, RetiredId.id.in_(ids))):
        raise DomainError("retired_id")
    # Child identities cannot be reused in a different live session.
    for model in (Workout, Exercise, WorkoutSet):
        if db.scalar(select(model).where(model.owner_id == owner, model.id.in_(ids))):
            raise DomainError("duplicate_id")
    workout = Workout(
        owner_id=owner,
        id=op.aggregate_id,
        revision=1,
        name=plan.name,
        timezone=plan.timezone,
        status="active",
        started_at=op.occurred_at,
        ended_at=None,
    )
    db.add(workout)
    db.flush()
    for ordinal, exercise in enumerate(plan.exercises):
        db.add(
            Exercise(
                owner_id=owner,
                id=exercise.session_exercise_id,
                session_id=op.aggregate_id,
                ordinal=ordinal,
                definition=exercise.model_dump(mode="json", exclude={"sets"}),
            )
        )
        db.flush()
        for set_ordinal, item in enumerate(exercise.sets):
            db.add(
                WorkoutSet(
                    owner_id=owner,
                    id=item.set_id,
                    exercise_id=exercise.session_exercise_id,
                    ordinal=set_ordinal,
                    prescription=item.model_dump(mode="json"),
                    observation=None,
                )
            )
    return workout
