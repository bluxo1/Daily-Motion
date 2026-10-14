from concurrent.futures import ThreadPoolExecutor, TimeoutError
from threading import Event
from typing import Any
from uuid import UUID, uuid4

import pytest
from fastapi import HTTPException
from sqlalchemy import func, select

from daily_motion import sync
from daily_motion.contracts import Operation
from daily_motion.models import Snapshot, Workout
from daily_motion.sync import accept, bootstrap, next_transaction, owner_guard

from .test_sync import command, record


def test_mutation_waiting_on_disable_rechecks_state(
    owner: UUID, create_body: dict[str, Any]
) -> None:
    started = Event()

    def previously_authenticated_request() -> None:
        started.set()
        accept(owner, Operation.model_validate(create_body))

    with ThreadPoolExecutor(1) as executor:
        with next_transaction(owner) as db:
            state = owner_guard(db, owner)
            state.status = "deleting"
            state.erasure_epoch += 1
            db.flush()
            future = executor.submit(previously_authenticated_request)
            assert started.wait(10)
            with pytest.raises(TimeoutError):
                future.result(timeout=0.1)
        with pytest.raises(HTTPException) as error:
            future.result(timeout=10)
        assert error.value.status_code == 403
    with next_transaction(owner) as db:
        assert db.scalar(select(func.count()).select_from(Workout)) == 0


def test_deletion_during_materialization_cannot_publish_payload(
    owner: UUID, create_body: dict[str, Any], monkeypatch: pytest.MonkeyPatch
) -> None:
    accept(owner, Operation.model_validate(create_body))
    original = sync.projection

    def delete_after_read(*args: Any) -> dict[str, Any]:
        result = original(*args)
        accept(owner, command(create_body, "delete_session", 1))
        return result

    monkeypatch.setattr(sync, "projection", delete_after_read)
    with pytest.raises(HTTPException) as error:
        bootstrap(owner)
    assert error.value.detail["code"] == "snapshot_invalidated"
    with next_transaction(owner) as db:
        assert db.scalar(select(func.count()).select_from(Snapshot)) == 0


def test_rejected_mutation_id_cannot_be_rewritten(owner: UUID, create_body: dict[str, Any]) -> None:
    accept(owner, Operation.model_validate(create_body))
    rejected = command(create_body, "complete_session", 1)
    result = accept(owner, rejected)
    assert result["error"]["code"] == "empty_session"
    assert accept(owner, rejected) == result
    altered = rejected.model_dump(mode="json")
    altered["command"] = "abandon_session"
    assert (
        accept(owner, Operation.model_validate(altered))["error"]["code"]
        == "mutation_digest_mismatch"
    )
    assert accept(owner, record(create_body))["accepted_revision"] == 2


def test_nested_id_cannot_target_another_workout(owner: UUID, create_body: dict[str, Any]) -> None:
    accept(owner, Operation.model_validate(create_body))
    op = record(create_body)
    body = op.model_dump(mode="json")
    body["payload"]["session_exercise_id"] = str(uuid4())
    assert accept(owner, Operation.model_validate(body))["error"]["code"] == "not_found"
    assert accept(owner, op)["error"]["code"] == "mutation_digest_mismatch"
    assert accept(owner, record(create_body))["accepted_revision"] == 2
