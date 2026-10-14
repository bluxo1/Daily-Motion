from concurrent.futures import ThreadPoolExecutor, TimeoutError
from copy import deepcopy
from threading import Event
from typing import Any
from uuid import UUID, uuid4

import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient
from sqlalchemy import Engine, event, func, select
from sqlalchemy.orm import Session

from daily_motion.auth import verified_owner
from daily_motion.contracts import Operation
from daily_motion.main import app
from daily_motion.models import Change, ObservationRevision, OwnerState, Receipt, Workout
from daily_motion.sync import (
    accept,
    bootstrap,
    disable_account,
    next_transaction,
    pull,
    snapshot_page,
)


def command(
    body: dict[str, Any], name: str, revision: int, payload: dict[str, Any] | None = None
) -> Operation:
    return Operation.model_validate(
        dict(
            body,
            mutation_id=str(uuid4()),
            command=name,
            expected_revision=revision,
            payload=payload or {},
        )
    )


def record(body: dict[str, Any], revision: int = 1, index: int = 0, sequence: int = 1) -> Operation:
    exercise = body["payload"]["exercises"][0]
    return command(
        body,
        "record_set",
        revision,
        {
            "session_exercise_id": exercise["session_exercise_id"],
            "set_id": exercise["sets"][index]["set_id"],
            "execution_status": "completed",
            "actual": {
                "load": {"value": "60", "unit": "kg", "basis": "total_external"},
                "reps": 5,
                "rep_convention": "bilateral",
                "effort": None,
            },
            "completion_seq": sequence,
            "order_source": "logged",
        },
    )


def test_lost_response_and_digest_binding(owner: UUID, create_body: dict[str, Any]) -> None:
    op = Operation.model_validate(create_body)
    first = accept(owner, op)
    replay = accept(owner, op)
    assert replay == dict(first, status="duplicate")
    changed = deepcopy(create_body)
    changed["payload"]["name"] = "Different content"
    assert (
        accept(owner, Operation.model_validate(changed))["error"]["code"]
        == "mutation_digest_mismatch"
    )
    assert len(pull(owner, None, 100)["changes"]) == 1


def test_session_cas_and_retained_corrections(owner: UUID, create_body: dict[str, Any]) -> None:
    accept(owner, Operation.model_validate(create_body))
    original = record(create_body)
    assert accept(owner, original)["accepted_revision"] == 2
    assert accept(owner, record(create_body, index=1))["status"] == "conflict"
    assert accept(owner, command(create_body, "complete_session", 2))["accepted_revision"] == 3
    correction = command(
        create_body,
        "correct_set",
        3,
        dict(
            original.payload,
            actual=dict(original.payload["actual"], reps=6),
            correction_reason="Corrected entry",
        ),
    )
    assert accept(owner, correction)["accepted_revision"] == 4
    with next_transaction(owner) as db:
        assert db.get(Workout, (owner, original.aggregate_id)).status == "completed"
        revisions = db.scalars(
            select(ObservationRevision).order_by(ObservationRevision.revision)
        ).all()
        assert [row.payload["actual"]["reps"] for row in revisions] == [5, 6]
        assert [row.position for row in revisions] == [2, 4]


def test_empty_finish_rolls_back_revision(owner: UUID, create_body: dict[str, Any]) -> None:
    accept(owner, Operation.model_validate(create_body))
    assert (
        accept(owner, command(create_body, "complete_session", 1))["error"]["code"]
        == "empty_session"
    )
    assert accept(owner, record(create_body))["accepted_revision"] == 2


def test_transaction_failure_publishes_nothing(owner: UUID, create_body: dict[str, Any]) -> None:
    def fail(db: Session, *_: Any) -> None:
        if any(isinstance(item, Receipt) for item in db.new):
            raise RuntimeError("injected process boundary failure")

    event.listen(Session, "before_flush", fail)
    try:
        with pytest.raises(RuntimeError):
            accept(owner, Operation.model_validate(create_body))
    finally:
        event.remove(Session, "before_flush", fail)
    with next_transaction(owner) as db:
        assert db.scalar(select(func.count()).select_from(Workout)) == 0
        assert db.scalar(select(func.count()).select_from(Change)) == 0
        assert db.get(OwnerState, owner).position == 0
    assert accept(owner, Operation.model_validate(create_body))["accepted_revision"] == 1


def test_deletion_redacts_transport_invalidates_snapshots_and_retires_children(
    owner: UUID, create_body: dict[str, Any]
) -> None:
    op = Operation.model_validate(create_body)
    accept(owner, op)
    accept(owner, record(create_body))
    snapshot = bootstrap(owner)
    assert (
        snapshot_page(owner, snapshot["token"], 0)["roots"][0]["exercises"][0]["sets"][0][
            "observation"
        ]["actual"]["reps"]
        == 5
    )
    accept(owner, command(create_body, "delete_session", 2))
    changes = pull(owner, None, 100)["changes"]
    assert all(item.get("redacted") for item in changes[:2])
    assert changes[-1]["redacted"] is True
    assert changes[-1]["aggregate_id"] == create_body["aggregate_id"]
    with next_transaction(owner) as db:
        assert db.scalar(select(func.count()).select_from(ObservationRevision)) == 0
        assert db.scalar(select(func.count()).select_from(Workout)) == 0
    with pytest.raises(HTTPException):
        snapshot_page(owner, snapshot["token"], 0)
    assert accept(owner, op)["status"] == "duplicate"  # Receipt is historical, not resurrection.
    assert (
        accept(owner, command(create_body, "create_session", 0, op.payload))["error"]["code"]
        == "retired_id"
    )
    alternate = deepcopy(create_body)
    alternate["aggregate_id"], alternate["mutation_id"] = str(uuid4()), str(uuid4())
    assert accept(owner, Operation.model_validate(alternate))["error"]["code"] == "retired_id"
    assert bootstrap(owner)["page_count"] == 1


def test_rls_fails_closed_and_context_does_not_leak(
    database: Engine, owner: UUID, create_body: dict[str, Any]
) -> None:
    accept(owner, Operation.model_validate(create_body))
    with Session(database) as db, db.begin():
        assert db.scalar(select(func.count()).select_from(Workout)) == 0
    other = uuid4()
    with next_transaction(other) as db:
        assert db.scalar(select(func.count()).select_from(Workout)) == 0
    with next_transaction(owner) as db:
        assert db.scalar(select(func.count()).select_from(Workout)) == 1
    with Session(database) as db, db.begin():
        assert db.scalar(select(func.count()).select_from(Workout)) == 0


def test_owner_lock_orders_concurrent_commits(
    owner: UUID, create_body: dict[str, Any], monkeypatch: pytest.MonkeyPatch
) -> None:
    from daily_motion import sync

    entered, release, second_started = Event(), Event(), Event()
    other = deepcopy(create_body)
    # Independent sessions need their own children.
    replacements = {
        old: str(uuid4())
        for old in [
            other["aggregate_id"],
            other["mutation_id"],
            other["payload"]["exercises"][0]["session_exercise_id"],
            *(s["set_id"] for s in other["payload"]["exercises"][0]["sets"]),
        ]
    }
    import json

    serialized = json.dumps(other)
    for old, new in replacements.items():
        serialized = serialized.replace(old, new)
    other = json.loads(serialized)

    original_create = sync._create

    def paused_create(db: Session, current_owner: UUID, op: Operation) -> Workout:
        result = original_create(db, current_owner, op)
        if str(op.aggregate_id) == create_body["aggregate_id"]:
            entered.set()
            assert release.wait(10)
        return result

    monkeypatch.setattr(sync, "_create", paused_create)

    def first() -> None:
        accept(owner, Operation.model_validate(create_body))

    def second() -> None:
        assert entered.wait(10)
        second_started.set()
        accept(owner, Operation.model_validate(other))

    with ThreadPoolExecutor(2) as executor:
        a, b = executor.submit(first), executor.submit(second)
        assert second_started.wait(10)
        try:
            with pytest.raises(TimeoutError):
                b.result(timeout=0.1)
        finally:
            release.set()
        a.result(10)
        b.result(10)
    page = pull(owner, None, 1)
    assert page["changes"][0]["position"] == 1
    assert page["changes"][0]["operation"]["aggregate_id"] == create_body["aggregate_id"]
    assert pull(owner, page["next_cursor"], 1)["changes"][0]["position"] == 2


def test_disabled_account_cannot_use_previously_valid_identity(
    owner: UUID, create_body: dict[str, Any]
) -> None:
    disable_account(owner)
    with pytest.raises(HTTPException) as error:
        accept(owner, Operation.model_validate(create_body))
    assert error.value.status_code == 403
    with pytest.raises(HTTPException):
        bootstrap(owner)


def test_api_auth_body_bound_and_safe_cache(owner: UUID, create_body: dict[str, Any]) -> None:
    with TestClient(app) as client:
        assert (
            client.post(
                "/v1/sync/push", json={"schema_version": 1, "operations": [create_body]}
            ).status_code
            == 401
        )
        app.dependency_overrides[verified_owner] = lambda: owner
        try:
            response = client.post(
                "/v1/sync/push", json={"schema_version": 1, "operations": [create_body]}
            )
            assert response.status_code == 200
            assert response.headers["Cache-Control"] == "private, no-store"
            assert client.post("/v1/sync/push", content=b"x" * (1024 * 1024 + 1)).status_code == 413
        finally:
            app.dependency_overrides.clear()
