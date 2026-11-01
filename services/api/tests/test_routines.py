"""Real restricted-role PostgreSQL controls for the routine aggregate."""

import hashlib
import inspect
import json
from concurrent.futures import ThreadPoolExecutor
from contextlib import contextmanager
from copy import deepcopy
from pathlib import Path
from threading import Barrier
from typing import Any
from uuid import UUID, uuid4

import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient
from pydantic import ValidationError
from sqlalchemy import Engine, event, select, text
from sqlalchemy.exc import DBAPIError, IntegrityError
from sqlalchemy.orm import Session

from daily_motion.auth import verified_owner
from daily_motion.contracts import Operation, canonical_json
from daily_motion.main import app
from daily_motion.models import (
    AccountRetirement,
    Change,
    OwnerState,
    Receipt,
    Routine,
    RoutineTemplate,
)
from daily_motion.routine_contracts import RoutineOperation, SnapshotPage3
from daily_motion.sync import (
    accept,
    bootstrap,
    disable_account,
    me,
    next_transaction,
    pull,
    snapshot_page,
    validate_snapshot,
)
from tests.fixtures import baseline_account_retirement


def test_old_runtime_cannot_record_retirement_while_its_upgraded_owner_guard_is_hidden(
    owner: UUID, create_body: dict[str, Any], admin_engine: Engine, monkeypatch: pytest.MonkeyPatch
) -> None:
    assert (
        hashlib.sha256(
            inspect.getsource(baseline_account_retirement.mark_account_retired).encode()
        ).hexdigest()
        == "e602ac9a91f9217b3c5448d0396adb4c518f327647b4349198997124b776258f"
    )
    first = routine_command(create_body)
    accept(owner, first, 3)

    @contextmanager
    def prior_transaction(subject: UUID):
        with next_transaction(subject) as db:
            db.execute(text("SELECT set_config('app.server_sync_contract','',true)"))
            yield db

    monkeypatch.setattr(baseline_account_retirement, "next_transaction", prior_transaction)
    denied = False
    try:
        baseline_account_retirement.mark_account_retired(owner)
    except DBAPIError as error:
        assert error.orig.sqlstate == "42501"
        denied = True
    with Session(admin_engine) as db:
        marker = db.get(AccountRetirement, owner)
        state = db.get(OwnerState, owner)
        assert marker is None or state.status != "active", (
            "Legacy retirement committed a permanent marker "
            "while leaving the upgraded account active"
        )
        assert db.get(AccountRetirement, owner) is None
        assert db.get(OwnerState, owner).status == "active"
        assert db.get(Routine, (owner, first.aggregate_id)) is not None
    assert denied, "Unsupported old retirement must fail explicitly without partial effects"
    assert me(owner, 3)["position"] == 1


def test_old_runtime_retirement_of_a_workout_only_owner_keeps_its_original_barrier(
    owner: UUID, create_body: dict[str, Any], admin_engine: Engine, monkeypatch: pytest.MonkeyPatch
) -> None:
    accept(owner, Operation.model_validate(create_body))

    @contextmanager
    def prior_transaction(subject: UUID):
        with next_transaction(subject) as db:
            db.execute(text("SELECT set_config('app.server_sync_contract','',true)"))
            yield db

    monkeypatch.setattr(baseline_account_retirement, "next_transaction", prior_transaction)
    baseline_account_retirement.mark_account_retired(owner)
    with Session(admin_engine) as db:
        assert db.get(AccountRetirement, owner) is not None
        assert db.get(OwnerState, owner).status == "deleting"
    with pytest.raises(HTTPException) as error:
        me(owner)
    assert error.value.detail["code"] == "account_inactive"


def test_first_routine_publication_racing_old_retirement_never_leaves_an_active_retired_owner(
    owner: UUID, create_body: dict[str, Any], admin_engine: Engine, monkeypatch: pytest.MonkeyPatch
) -> None:
    gate = Barrier(2)
    first = routine_command(create_body)

    @contextmanager
    def prior_transaction(subject: UUID):
        with next_transaction(subject) as db:
            db.execute(text("SELECT set_config('app.server_sync_contract','',true)"))
            yield db

    monkeypatch.setattr(baseline_account_retirement, "next_transaction", prior_transaction)

    def retire() -> str:
        gate.wait(timeout=20)
        try:
            baseline_account_retirement.mark_account_retired(owner)
            return "retired"
        except DBAPIError as error:
            assert error.orig.sqlstate == "42501"
            return "unsupported"

    def publish() -> str:
        gate.wait(timeout=20)
        try:
            assert accept(owner, first, 3)["status"] == "accepted"
            return "accepted"
        except HTTPException as error:
            assert error.detail["code"] == "account_inactive"
            return "inactive"

    with ThreadPoolExecutor(2) as executor:
        old = executor.submit(retire)
        new = executor.submit(publish)
        outcome = (old.result(timeout=30), new.result(timeout=30))
    assert outcome in {("retired", "inactive"), ("unsupported", "accepted")}
    with Session(admin_engine) as db:
        marker = db.get(AccountRetirement, owner)
        state = db.get(OwnerState, owner)
        routine = db.get(Routine, (owner, first.aggregate_id))
        if marker is not None:
            assert state.status == "deleting"
            assert routine is None
        else:
            assert state.status == "active"
            assert state.minimum_sync_contract == 3
            assert routine is not None


def routine_command(body: dict[str, Any], revision: int = 0, **kwargs: Any) -> RoutineOperation:
    return RoutineOperation.model_validate(
        {
            **body,
            "aggregate_type": "routine",
            "mutation_id": str(uuid4()),
            "command": "create_routine" if revision == 0 else "publish_template",
            "expected_revision": revision,
            "payload": {
                "template_id": str(uuid4()),
                "predecessor_template_id": None,
                "prescription": deepcopy(body["payload"]),
            },
            **kwargs,
        }
    )


def publication(first: RoutineOperation, revision: int = 1) -> RoutineOperation:
    value = first.model_dump(mode="json")
    value.update(mutation_id=str(uuid4()), expected_revision=revision, command="publish_template")
    value["payload"] = {
        "template_id": str(uuid4()),
        "predecessor_template_id": first.payload["template_id"],
        "prescription": {**first.payload["prescription"], "name": "Edited routine"},
    }
    return RoutineOperation.model_validate(value)


def test_routine_receipt_lineage_feed_bootstrap_and_historical_replay(
    owner: UUID, create_body: dict[str, Any]
) -> None:
    first = routine_command(create_body)
    result = accept(owner, first, 3)
    assert result["accepted_revision"] == 1
    second = publication(first)
    assert accept(owner, second, 3)["accepted_revision"] == 2
    assert accept(owner, first, 3) == dict(result, status="duplicate")
    altered = first.model_copy(update={"recorded_at": "2026-10-29T12:00:00Z"})
    assert accept(owner, altered, 3)["error"]["code"] == "mutation_digest_mismatch"
    changes = pull(owner, None, 100, 3)["changes"]
    assert [c["revision"] for c in changes] == [1, 2]
    assert canonical_json(changes[0]["operation"]) == canonical_json(first.model_dump(mode="json"))
    manifest = bootstrap(owner, contract=3)
    page = snapshot_page(owner, manifest["token"], 0, 3)
    SnapshotPage3.model_validate(page)
    assert len(page["routines"]) == 2
    root = page["routines"][0]
    assert root["current_template_id"] == second.payload["template_id"]
    assert [r["template_offset"] for r in page["routines"]] == [0, 1]
    assert [t["revision"] for r in page["routines"] for t in r["templates"]] == [1, 2]
    assert root["templates"][0]["prescription"] == first.payload["prescription"]
    assert validate_snapshot(owner, manifest["token"], 3)["schema_version"] == 3


def test_concurrent_revision_race_and_exact_duplicate_race(
    owner: UUID, create_body: dict[str, Any]
) -> None:
    first = routine_command(create_body)
    with ThreadPoolExecutor(2) as executor:
        results = list(executor.map(lambda _: accept(owner, first, 3), range(2)))
    assert sorted(r["status"] for r in results) == ["accepted", "duplicate"]
    with ThreadPoolExecutor(2) as executor:
        results = list(
            executor.map(lambda op: accept(owner, op, 3), [publication(first), publication(first)])
        )
    assert sorted(r["status"] for r in results) == ["accepted", "conflict"]
    assert len(pull(owner, None, 100, 3)["changes"]) == 2


def test_failed_projection_receipt_and_contract_upgrade_roll_back_together(
    owner: UUID, create_body: dict[str, Any]
) -> None:
    def fail(db: Session, *_: Any) -> None:
        if any(isinstance(row, Receipt) for row in db.new):
            raise RuntimeError("Controlled response/commit boundary")

    event.listen(Session, "before_flush", fail)
    op = routine_command(create_body)
    try:
        with pytest.raises(RuntimeError):
            accept(owner, op, 3)
    finally:
        event.remove(Session, "before_flush", fail)
    assert me(owner)["position"] == 0
    with next_transaction(owner) as db:
        assert db.get(Routine, (owner, op.aggregate_id)) is None
        assert db.scalars(select(Change)).all() == []
        assert db.scalars(select(RoutineTemplate)).all() == []
    assert accept(owner, op, 3)["status"] == "accepted"


def test_legacy_sync_refuses_all_access_after_routine_and_snapshot_cannot_cross_contracts(
    owner: UUID, create_body: dict[str, Any]
) -> None:
    legacy_snapshot = bootstrap(owner)
    accept(owner, routine_command(create_body), 3)
    for action in [
        lambda: me(owner),
        lambda: pull(owner, None, 100),
        lambda: bootstrap(owner),
        lambda: snapshot_page(owner, legacy_snapshot["token"], 0),
        lambda: validate_snapshot(owner, legacy_snapshot["token"]),
        lambda: accept(owner, Operation.model_validate(create_body)),
    ]:
        with pytest.raises(HTTPException) as error:
            action()
        assert error.value.status_code == 426
        assert error.value.detail["code"] == "upgrade_required"
    with pytest.raises(HTTPException):
        snapshot_page(owner, legacy_snapshot["token"], 0, 3)
    # Unrelated workouts remain supported for a capable client.
    independent_workout = {**create_body, "aggregate_id": str(uuid4())}
    assert accept(owner, Operation.model_validate(independent_workout), 3)["status"] == "accepted"


def test_owner_rls_composite_lineage_immutability_and_disable(
    owner: UUID, create_body: dict[str, Any], admin_engine: Engine
) -> None:
    first = routine_command(create_body)
    accept(owner, first, 3)
    other = uuid4()
    with Session(admin_engine) as db, db.begin():
        db.add(OwnerState(owner_id=other, generation=uuid4()))
    with next_transaction(other) as db:
        assert db.scalars(select(Routine)).all() == []
        assert db.scalars(select(RoutineTemplate)).all() == []
    with pytest.raises(IntegrityError), next_transaction(other) as db:
        db.execute(
            text(
                "INSERT INTO training.routine_templates"
                "(owner_id,id,routine_id,revision,prescription) "
                "VALUES(:owner,:id,:root,1,'{}')"
            ),
            {"owner": other, "id": uuid4(), "root": first.aggregate_id},
        )
    with pytest.raises(IntegrityError), next_transaction(owner) as db:
        db.execute(
            text("UPDATE training.routine_templates SET prescription='{}' WHERE owner_id=:owner"),
            {"owner": owner},
        )
    stale = publication(first)
    assert accept(other, stale, 3)["status"] == "conflict"
    disable_account(owner)
    for action in [
        lambda: accept(owner, stale, 3),
        lambda: bootstrap(owner, contract=3),
        lambda: me(owner, 3),
    ]:
        with pytest.raises(HTTPException) as error:
            action()
        assert error.value.detail["code"] == "account_inactive"


def test_http_closed_contract_and_wrong_header(owner: UUID, create_body: dict[str, Any]) -> None:
    app.dependency_overrides[verified_owner] = lambda: owner
    try:
        with TestClient(app) as client:
            op = routine_command(create_body).model_dump(mode="json")
            assert (
                client.post(
                    "/v1/sync/push", json={"schema_version": 1, "operations": [op]}
                ).status_code
                == 422
            )
            assert client.get("/v3/me", headers={"X-DM-Contract": "2"}).status_code == 426
            assert (
                client.post(
                    "/v3/sync/push",
                    json={"schema_version": 3, "operations": [{**op, "owner_id": str(owner)}]},
                ).status_code
                == 422
            )
            response = client.post("/v3/sync/push", json={"schema_version": 3, "operations": [op]})
            assert response.status_code == 200, response.text
            assert response.json()["results"][0]["status"] == "accepted"
            assert client.get("/v1/me").status_code == 426
            assert client.get("/v3/sync/pull").json()["changes"][0]["operation"] == op
    finally:
        app.dependency_overrides.clear()


def test_routine_contract_rejects_invalid_lineage_and_observations(
    create_body: dict[str, Any],
) -> None:
    op = routine_command(create_body).model_dump(mode="json")
    for change in [
        {"expected_revision": 1},
        {"command": "publish_template"},
        {"aggregate_type": "workout_session"},
    ]:
        with pytest.raises(ValidationError):
            RoutineOperation.model_validate({**op, **change})
    op["payload"]["prescription"]["exercises"][0]["sets"][0]["observation"] = {}
    with pytest.raises(ValidationError):
        RoutineOperation.model_validate(op)


def test_every_baseline_schema_and_frozen_workout_fixture_remains_unchanged() -> None:
    root = Path(__file__).parents[3]
    expected = json.loads((root / "contracts/fixtures/routine_sync_compatibility.json").read_text())
    schemas = app.openapi()["components"]["schemas"]
    for name, digest in expected["schemas"].items():
        assert hashlib.sha256(canonical_json(schemas[name]).encode()).hexdigest() == digest, name
    fixture = (root / "contracts/fixtures/workout.json").read_bytes().replace(b"\r\n", b"\n")
    assert hashlib.sha256(fixture).hexdigest() == expected["workout_fixture_sha256"]


def test_account_retirement_erases_private_planning_copies_and_denies_stale_replay(
    owner: UUID, create_body: dict[str, Any], admin_engine: Engine
) -> None:
    from daily_motion.accounts import mark_account_retired
    from daily_motion.models import Snapshot

    op = routine_command(create_body)
    accept(owner, op, 3)
    bootstrap(owner, contract=3)
    mark_account_retired(owner)
    with Session(admin_engine) as db:
        assert db.scalars(select(Routine).where(Routine.owner_id == owner)).all() == []
        assert (
            db.scalars(select(RoutineTemplate).where(RoutineTemplate.owner_id == owner)).all() == []
        )
        assert db.scalars(select(Snapshot).where(Snapshot.owner_id == owner)).all() == []
        assert all(
            c.body.get("redacted")
            for c in db.scalars(select(Change).where(Change.owner_id == owner))
        )
    with pytest.raises(HTTPException) as error:
        accept(owner, op, 3)
    assert error.value.detail["code"] == "account_inactive"


def test_large_immutable_history_pages_without_truncation_or_unbounded_single_root(
    owner: UUID, create_body: dict[str, Any]
) -> None:
    body = deepcopy(create_body)
    prototype = body["payload"]["exercises"][0]
    exercises = []
    for _ in range(20):
        exercise = deepcopy(prototype)
        exercise["session_exercise_id"] = str(uuid4())
        exercise["sets"] = [
            dict(deepcopy(prototype["sets"][0]), set_id=str(uuid4())) for _ in range(35)
        ]
        exercises.append(exercise)
    body["payload"]["exercises"] = exercises
    op = routine_command(body)
    for revision in range(1, 7):
        if revision > 1:
            op = publication(op, revision - 1)
        assert accept(owner, op, 3)["accepted_revision"] == revision
    manifest = bootstrap(owner, contract=3)
    assert manifest["page_count"] > 1
    versions = []
    for index in range(manifest["page_count"]):
        page = snapshot_page(owner, manifest["token"], index, 3)
        SnapshotPage3.model_validate(page)
        assert (
            hashlib.sha256(canonical_json(page).encode()).hexdigest()
            == manifest["checksums"][index]
        )
        assert len(canonical_json(page).encode()) <= 524288
        versions.extend(page["routines"])
    assert [root["template_offset"] for root in versions] == list(range(6))
    assert [root["templates"][0]["revision"] for root in versions] == list(range(1, 7))
    assert all(root["revision"] == 6 for root in versions)
    assert len({root["templates"][0]["template_id"] for root in versions}) == 6
    assert all(root["templates"][0]["prescription"]["exercises"] == exercises for root in versions)
    changes = []
    token = None
    while True:
        page = pull(owner, token, 100, 3)
        changes.extend(page["changes"])
        if not page["has_more"]:
            break
        token = page["next_cursor"]
    assert [change["position"] for change in changes] == list(range(1, 7))


@pytest.mark.parametrize(
    "field", ["template", "variant", "envelope", "timezone", "blank_name", "backoff_warmup"]
)
def test_routine_validation_cannot_accept_state_the_current_mobile_reader_cannot_install(
    create_body: dict[str, Any], field: str
) -> None:
    op = routine_command(create_body).model_dump(mode="json")
    plan = op["payload"]["prescription"]
    if field == "template":
        op["payload"]["template_id"] = "ABCDEFAB-1111-4111-8111-ABCDEFABCDEF"
    elif field == "variant":
        plan["exercises"][0]["variant_id"] = "ABCDEFAB-1111-4111-8111-ABCDEFABCDEF"
    elif field == "envelope":
        op["mutation_id"] = "ABCDEFAB-1111-4111-8111-ABCDEFABCDEF"
    elif field == "timezone":
        plan["timezone"] = "Europe/London"
    elif field == "blank_name":
        plan["name"] = "   "
    else:
        plan["exercises"][0]["sets"][0]["set_class"] = "warmup"
        plan["exercises"][0]["sets"][0]["set_purpose"] = "backoff"
    with pytest.raises(ValidationError):
        RoutineOperation.model_validate(op)


def test_prior_runtime_without_routine_capability_cannot_read_upgraded_owner_state(
    owner: UUID, create_body: dict[str, Any]
) -> None:
    op = routine_command(create_body)
    accept(owner, op, 3)
    with next_transaction(owner) as db:
        db.execute(text("SELECT set_config('app.server_sync_contract','',true)"))
        assert db.scalar(text("SELECT count(*) FROM training.owner_state")) == 0
    # The current server sees the owner and gives explicit contract refusal.
    with pytest.raises(HTTPException) as error:
        me(owner)
    assert error.value.status_code == 426
    assert me(owner, 3)["position"] == 1


@pytest.mark.parametrize(
    "collision",
    ["workout_root", "routine_root", "template_root", "template_child", "workout_child"],
)
def test_planning_and_workout_live_id_namespaces_cannot_alias(
    owner: UUID, create_body: dict[str, Any], collision: str
) -> None:
    workout = deepcopy(create_body)
    routine = routine_command(create_body).model_dump(mode="json")
    if collision in {"template_root", "template_child"}:
        routine["aggregate_id"] = str(uuid4())
        routine["payload"]["template_id"] = (
            workout["aggregate_id"]
            if collision == "template_root"
            else workout["payload"]["exercises"][0]["sets"][0]["set_id"]
        )
    if collision in {"routine_root", "workout_child"}:
        assert accept(owner, RoutineOperation.model_validate(routine), 3)["status"] == "accepted"
        if collision == "workout_child":
            workout["aggregate_id"] = str(uuid4())
            workout["payload"]["exercises"][0]["sets"][0]["set_id"] = routine["payload"][
                "template_id"
            ]
        result = accept(owner, Operation.model_validate(workout), 3)
    else:
        assert accept(owner, Operation.model_validate(workout), 3)["status"] == "accepted"
        result = accept(owner, RoutineOperation.model_validate(routine), 3)
    assert result["status"] == "rejected"
    assert result["error"]["code"] == "duplicate_id"
    assert len(pull(owner, None, 100, 3)["changes"]) == 1
