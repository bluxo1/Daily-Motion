import base64
import hashlib
import hmac
import json
from contextlib import contextmanager
from datetime import UTC, datetime, timedelta
from typing import Any
from uuid import UUID, uuid4

from fastapi import HTTPException
from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from daily_motion.config import settings
from daily_motion.contracts import (
    PAGE_LIMIT,
    SNAPSHOT_LIMIT,
    CreateSession,
    Operation,
    RecordSet,
    canonical_json,
)
from daily_motion.db import tenant_transaction
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


class DomainError(Exception):
    def __init__(self, code: str) -> None:
        self.code = code


def owner_guard(db: Session, owner: UUID) -> OwnerState:
    state = db.scalar(select(OwnerState).where(OwnerState.owner_id == owner).with_for_update())
    if state is None:
        raise HTTPException(
            403,
            detail={
                "code": "account_inactive"
                if db.get(AccountRetirement, owner) is not None
                else "account_not_initialized",
                "owner_id": str(owner),
                "schema_version": 1,
            },
        )
    if state.status != "active":
        raise HTTPException(
            403, detail={"code": "account_inactive", "owner_id": str(owner), "schema_version": 1}
        )
    return state


def _token(value: dict[str, Any]) -> str:
    secret = settings().sync_signing_key
    if len(secret) < 32:
        raise HTTPException(503, detail={"code": "sync_not_configured"})
    data = base64.urlsafe_b64encode(canonical_json(value).encode()).decode().rstrip("=")
    signature = hmac.new(secret.encode(), data.encode(), hashlib.sha256).hexdigest()
    return data + "." + signature


def _untoken(token: str, owner: UUID, kind: str) -> dict[str, Any]:
    try:
        data, signature = token.split(".")
        secret = settings().sync_signing_key
        if len(secret) < 32:
            raise ValueError()
        expected = hmac.new(secret.encode(), data.encode(), hashlib.sha256).hexdigest()
        if not hmac.compare_digest(expected, signature):
            raise ValueError()
        value = json.loads(base64.urlsafe_b64decode(data + "=" * (-len(data) % 4)))
        if value["owner"] != str(owner) or value["kind"] != kind:
            raise ValueError()
        if not isinstance(value, dict):
            raise ValueError()
        return value
    except (ValueError, KeyError, TypeError) as error:
        raise HTTPException(409, detail={"code": "bootstrap_required"}) from error


def cursor(owner: UUID, generation: UUID, position: int) -> str:
    return _token(
        {"kind": "cursor", "owner": str(owner), "generation": str(generation), "position": position}
    )


def sync_context(owner: UUID, state: OwnerState) -> dict[str, Any]:
    return {
        "schema_version": 1,
        "owner_id": str(owner),
        "generation": str(state.generation),
        "erasure_epoch": state.erasure_epoch,
    }


def me(owner: UUID) -> dict[str, Any]:
    with next_transaction(owner) as db:
        state = owner_guard(db, owner)
        return {
            **sync_context(owner, state),
            "position": state.position,
            "minimum_position": state.minimum_position,
            "account_status": "active",
            "command_limit": 262144,
            "batch_limit": 1048576,
            "page_limit": PAGE_LIMIT,
            "snapshot_limit": SNAPSHOT_LIMIT,
        }


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


def _record(
    db: Session, owner: UUID, workout: Workout, op: Operation, position: int, generation: UUID
) -> None:
    record = RecordSet.model_validate(op.payload)
    exercise = db.get(Exercise, (owner, record.session_exercise_id))
    item = db.get(WorkoutSet, (owner, record.set_id))
    if (
        exercise is None
        or exercise.session_id != workout.id
        or item is None
        or item.exercise_id != exercise.id
    ):
        raise DomainError("not_found")
    if op.command == "record_set" and (workout.status != "active" or item.observation is not None):
        raise DomainError("invalid_transition")
    if op.command == "correct_set" and item.observation is None:
        raise DomainError("invalid_transition")
    if record.actual:
        basis = exercise.definition["loading_basis"]
        if (basis == "bodyweight_only" and record.actual.load is not None) or (
            basis != "bodyweight_only"
            and (record.actual.load is None or record.actual.load.basis != basis)
        ):
            raise DomainError("load_convention_mismatch")
        if record.actual.rep_convention != exercise.definition["rep_convention"]:
            raise DomainError("rep_convention_mismatch")
    existing = db.scalars(
        select(WorkoutSet)
        .join(
            Exercise,
            (WorkoutSet.owner_id == Exercise.owner_id) & (WorkoutSet.exercise_id == Exercise.id),
        )
        .where(Exercise.owner_id == owner, Exercise.session_id == workout.id)
    ).all()
    if op.command == "record_set":
        last = max(
            (int(s.observation["completion_seq"]) for s in existing if s.observation), default=0
        )
        if record.completion_seq != last + 1:
            raise DomainError("invalid_completion_sequence")
    elif item.observation and record.completion_seq != item.observation["completion_seq"]:
        raise DomainError("immutable_completion_sequence")
    observation = dict(op.payload, occurred_at=op.occurred_at, recorded_at=op.recorded_at)
    item.observation = observation
    db.add(
        ObservationRevision(
            owner_id=owner,
            session_id=workout.id,
            revision=workout.revision,
            set_id=item.id,
            position=position,
            generation=generation,
            payload=observation,
        )
    )


def _erase(db: Session, owner: UUID, workout: Workout, state: OwnerState) -> list[UUID]:
    exercises = db.scalars(
        select(Exercise).where(Exercise.owner_id == owner, Exercise.session_id == workout.id)
    ).all()
    exercise_ids = [item.id for item in exercises]
    sets = db.scalars(
        select(WorkoutSet).where(
            WorkoutSet.owner_id == owner, WorkoutSet.exercise_id.in_(exercise_ids)
        )
    ).all()
    retired = [workout.id, *exercise_ids, *(item.id for item in sets)]
    for identifier in retired:
        db.add(RetiredId(owner_id=owner, id=identifier))
    db.execute(
        delete(ObservationRevision).where(
            ObservationRevision.owner_id == owner, ObservationRevision.session_id == workout.id
        )
    )
    for change in db.scalars(
        select(Change).where(Change.owner_id == owner, Change.session_id == workout.id)
    ):
        change.body = {
            "aggregate_id": str(workout.id),
            "redacted": True,
            "retired_ids": [str(identifier) for identifier in retired],
        }
    db.execute(delete(Snapshot).where(Snapshot.owner_id == owner))
    state.erasure_epoch += 1
    db.delete(workout)
    return retired


def apply_domain_change(
    db: Session, owner: UUID, op: Operation, state: OwnerState, workout: Workout | None
) -> tuple[Workout, list[UUID]]:
    """Shared normalized mutation rules; caller owns locks, savepoint and feed/result writes."""
    retired: list[UUID] = []
    if op.command == "create_session":
        if workout:
            raise DomainError("already_exists")
        workout = _create(db, owner, op)
    else:
        if workout is None:
            raise DomainError("not_found")
        workout.revision += 1
        if op.command in {"record_set", "correct_set"}:
            _record(db, owner, workout, op, state.position + 1, state.generation)
        elif op.command in {"complete_session", "abandon_session"}:
            if workout.status != "active":
                raise DomainError("invalid_transition")
            if op.command == "complete_session":
                attempted = db.scalar(
                    select(WorkoutSet)
                    .join(
                        Exercise,
                        (WorkoutSet.owner_id == Exercise.owner_id)
                        & (WorkoutSet.exercise_id == Exercise.id),
                    )
                    .where(
                        Exercise.owner_id == owner,
                        Exercise.session_id == workout.id,
                        WorkoutSet.observation.is_not(None),
                        WorkoutSet.observation["execution_status"].astext != "skipped",
                    )
                )
                if attempted is None:
                    raise DomainError("empty_session")
            workout.status = "completed" if op.command == "complete_session" else "abandoned"
            workout.ended_at = op.occurred_at
        elif op.command == "delete_session":
            retired = _erase(db, owner, workout, state)
    return workout, retired


def accept(owner: UUID, op: Operation) -> dict[str, Any]:
    body = op.model_dump(mode="json")
    digest = hashlib.sha256(canonical_json(body).encode()).hexdigest()
    with next_transaction(owner) as db:
        state = owner_guard(db, owner)
        receipt = db.get(Receipt, (owner, op.mutation_id))
        if receipt:
            if receipt.digest != digest:
                return _rejected(op, "mutation_digest_mismatch")
            if receipt.acknowledgement["status"] == "accepted":
                return dict(receipt.acknowledgement, status="duplicate")
            return receipt.acknowledgement
        workout = db.get(Workout, (owner, op.aggregate_id))
        if db.get(RetiredId, (owner, op.aggregate_id)):
            return _remember(db, owner, op, digest, _rejected(op, "retired_id"))
        current = workout.revision if workout else 0
        if current != op.expected_revision:
            conflict = {
                "mutation_id": str(op.mutation_id),
                "aggregate_id": str(op.aggregate_id),
                "status": "conflict",
                "expected_revision": op.expected_revision,
                "current_revision": current,
                "error": {"code": "revision_conflict", "retryable": False},
            }
            return _remember(db, owner, op, digest, conflict)
        try:
            # Validation failures roll back all intermediate projections before returning rejection.
            with db.begin_nested():
                workout, retired = apply_domain_change(db, owner, op, state, workout)
                accepted_revision = workout.revision
                accepted_at = datetime.now(UTC)
                state.position += 1
                result = {
                    "mutation_id": str(op.mutation_id),
                    "status": "accepted",
                    "aggregate_id": str(op.aggregate_id),
                    "accepted_revision": accepted_revision,
                    "accepted_at": accepted_at.isoformat().replace("+00:00", "Z"),
                }
                db.add(
                    Receipt(
                        owner_id=owner,
                        mutation_id=op.mutation_id,
                        digest=digest,
                        acknowledgement=result,
                    )
                )
                db.add(
                    Change(
                        owner_id=owner,
                        position=state.position,
                        session_id=op.aggregate_id,
                        created_at=accepted_at,
                        body=(
                            {
                                "aggregate_id": str(op.aggregate_id),
                                "redacted": True,
                                "retired_ids": [str(item) for item in retired],
                            }
                            if op.command == "delete_session"
                            else {"operation": body, "revision": accepted_revision}
                        ),
                    )
                )
                db.flush()
                return result
        except DomainError as error:
            return _remember(db, owner, op, digest, _rejected(op, error.code))


def _remember(
    db: Session, owner: UUID, op: Operation, digest: str, result: dict[str, Any]
) -> dict[str, Any]:
    db.add(
        Receipt(owner_id=owner, mutation_id=op.mutation_id, digest=digest, acknowledgement=result)
    )
    return result


def _rejected(op: Operation, code: str) -> dict[str, Any]:
    return {
        "mutation_id": str(op.mutation_id),
        "aggregate_id": str(op.aggregate_id),
        "status": "rejected",
        "error": {"code": code, "retryable": False},
    }


# A context manager closes the generator and commits before exposing the acknowledgement.
next_transaction = contextmanager(tenant_transaction)


def pull(owner: UUID, token: str | None, limit: int) -> dict[str, Any]:
    with next_transaction(owner) as db:
        state = owner_guard(db, owner)
        position = 0
        if token:
            value = _untoken(token, owner, "cursor")
            if value["generation"] != str(state.generation):
                raise HTTPException(409, detail={"code": "bootstrap_required"})
            position = value["position"]
        if position > state.position or position < state.minimum_position:
            raise HTTPException(409, detail={"code": "bootstrap_required"})
        changes = db.scalars(
            select(Change)
            .where(Change.owner_id == owner, Change.position > position)
            .order_by(Change.position)
            .limit(limit + 1)
        ).all()
        page: list[dict[str, Any]] = []
        size = 0
        for change in changes[:limit]:
            batch = {"position": change.position, **change.body}
            batch_size = len(canonical_json(batch).encode())
            if batch_size > PAGE_LIMIT:
                raise HTTPException(413, detail={"code": "bootstrap_required"})
            if size + batch_size > PAGE_LIMIT:
                break
            page.append(batch)
            size += batch_size
        next_position = page[-1]["position"] if page else position
        return {
            **sync_context(owner, state),
            "changes": page,
            "next_cursor": cursor(owner, state.generation, next_position),
            "next_position": next_position,
            "has_more": next_position < state.position,
            "generation": str(state.generation),
        }


def projection(db: Session, owner: UUID, workout: Workout) -> dict[str, Any]:
    exercises = []
    for exercise in db.scalars(
        select(Exercise)
        .where(Exercise.owner_id == owner, Exercise.session_id == workout.id)
        .order_by(Exercise.ordinal)
    ):
        sets = [
            {**item.prescription, "observation": item.observation}
            for item in db.scalars(
                select(WorkoutSet)
                .where(WorkoutSet.owner_id == owner, WorkoutSet.exercise_id == exercise.id)
                .order_by(WorkoutSet.ordinal)
            )
        ]
        exercises.append({**exercise.definition, "sets": sets})
    return {
        "aggregate_id": str(workout.id),
        "revision": workout.revision,
        "name": workout.name,
        "timezone": workout.timezone,
        "status": workout.status,
        "started_at": workout.started_at,
        "ended_at": workout.ended_at,
        "exercises": exercises,
    }


def bootstrap(owner: UUID, installation: UUID | None = None) -> dict[str, Any]:
    # Materialize under a short consistent snapshot, then publish under the owner guard.
    with next_transaction(owner, "REPEATABLE READ") as db:
        state = db.get(OwnerState, owner)
        if state is None:
            raise HTTPException(
                403,
                detail={
                    "code": "account_inactive"
                    if db.get(AccountRetirement, owner) is not None
                    else "account_not_initialized",
                    "owner_id": str(owner),
                    "schema_version": 1,
                },
            )
        if state.status != "active":
            raise HTTPException(
                403,
                detail={"code": "account_inactive", "owner_id": str(owner), "schema_version": 1},
            )
        generation, epoch, position = state.generation, state.erasure_epoch, state.position
        pages: list[dict[str, Any]] = []
        page: dict[str, Any] = {"roots": [], "retired_ids": []}
        total = 0
        for workout in db.scalars(
            select(Workout).where(Workout.owner_id == owner).order_by(Workout.id)
        ):
            root = projection(db, owner, workout)
            root_size = len(canonical_json(root).encode())
            total += root_size + 1
            if total > SNAPSHOT_LIMIT:
                raise HTTPException(413, detail={"code": "snapshot_capacity"})
            if root_size + 64 > PAGE_LIMIT:
                raise HTTPException(413, detail={"code": "snapshot_root_capacity"})
            if len(canonical_json(page).encode()) + root_size + 1 > PAGE_LIMIT:
                pages.append(page)
                page = {"roots": [], "retired_ids": []}
            page["roots"].append(root)
        for retired in db.scalars(
            select(RetiredId).where(RetiredId.owner_id == owner).order_by(RetiredId.id)
        ):
            total += 40
            if total > SNAPSHOT_LIMIT:
                raise HTTPException(413, detail={"code": "snapshot_capacity"})
            if len(canonical_json(page).encode()) + 40 > PAGE_LIMIT:
                pages.append(page)
                page = {"roots": [], "retired_ids": []}
            page["retired_ids"].append(str(retired.id))
        pages.append(page)
        total = sum(len(canonical_json(item).encode()) for item in pages)
        if total > SNAPSHOT_LIMIT or len(pages) > 4096:
            raise HTTPException(413, detail={"code": "snapshot_capacity"})
    with next_transaction(owner) as db:
        state = owner_guard(db, owner)
        if (state.generation, state.erasure_epoch) != (generation, epoch):
            raise HTTPException(409, detail={"code": "snapshot_invalidated"})
        identifier = uuid4()
        expires = datetime.now(UTC) + timedelta(minutes=15)
        installation = installation or UUID(int=0)
        db.execute(
            delete(Snapshot).where(
                Snapshot.owner_id == owner,
                (Snapshot.installation_id == installation)
                | (Snapshot.expires_at <= datetime.now(UTC)),
            )
        )
        db.add(
            Snapshot(
                owner_id=owner,
                id=identifier,
                generation=generation,
                erasure_epoch=epoch,
                position=position,
                installation_id=installation,
                expires_at=expires,
                pages=pages,
            )
        )
        return {
            **sync_context(owner, state),
            "installation_id": str(installation),
            "token": _token({"kind": "snapshot", "owner": str(owner), "id": str(identifier)}),
            "schema_version": 1,
            "page_count": len(pages),
            "checksums": [
                hashlib.sha256(canonical_json(page).encode()).hexdigest() for page in pages
            ],
            "cursor": cursor(owner, generation, position),
            "position": position,
            "expires_at": expires.isoformat().replace("+00:00", "Z"),
        }


def snapshot_page(owner: UUID, token: str, page: int) -> dict[str, Any]:
    value = _untoken(token, owner, "snapshot")
    with next_transaction(owner) as db:
        state = owner_guard(db, owner)
        snapshot = db.get(Snapshot, (owner, UUID(value["id"])))
        if (
            snapshot is None
            or snapshot.expires_at <= datetime.now(UTC)
            or snapshot.erasure_epoch != state.erasure_epoch
            or snapshot.generation != state.generation
        ):
            raise HTTPException(409, detail={"code": "snapshot_expired"})
        if page >= len(snapshot.pages):
            raise HTTPException(404, detail={"code": "not_found"})
        return snapshot.pages[page]


def disable_account(owner: UUID) -> None:
    """Internal lifecycle primitive; public reauthentication/erasure jobs are Phase 1."""
    with next_transaction(owner) as db:
        state = owner_guard(db, owner)
        state.status = "deleting"
        state.erasure_epoch += 1
        db.execute(delete(Snapshot).where(Snapshot.owner_id == owner))


def validate_snapshot(owner: UUID, token: str) -> dict[str, Any]:
    # Revalidate immediately before client activation; never hold a transaction over HTTP.
    snapshot_page(owner, token, 0)
    return me(owner)


def prune_feed(owner: UUID, before: datetime) -> None:
    with next_transaction(owner) as db:
        state = owner_guard(db, owner)
        expired = db.scalars(
            select(Change)
            .where(Change.owner_id == owner, Change.created_at < before)
            .order_by(Change.position)
        ).all()
        # Prune only a contiguous prefix, even if acceptance wall clocks moved backwards.
        watermark = state.minimum_position
        for item in expired:
            if item.position != watermark + 1:
                break
            watermark = item.position
        db.execute(delete(Change).where(Change.owner_id == owner, Change.position <= watermark))
        state.minimum_position = watermark
