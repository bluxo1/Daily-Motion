"""Independent contract, database interruption and retirement race controls.

All transaction and row-policy assertions use the real restricted-role PostgreSQL
fixture. Events hold exact SQL boundaries; no delay is treated as proof of a race.
"""

from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from threading import Event
from time import monotonic
from typing import Any
from uuid import UUID, uuid4

import pytest
from alembic import command
from alembic.config import Config
from fastapi import HTTPException
from fastapi.testclient import TestClient
from sqlalchemy import Engine, event, select, text
from sqlalchemy.engine import Connection
from sqlalchemy.exc import DBAPIError
from sqlalchemy.orm import Session

from daily_motion.accounts import mark_account_retired
from daily_motion.auth import verified_owner
from daily_motion.contracts import Operation
from daily_motion.main import app
from daily_motion.models import (
    AccountRetirement,
    Change,
    OwnerState,
    Receipt,
    Routine,
    RoutineTemplate,
    Snapshot,
)
from daily_motion.routine_contracts import RoutineOperation
from daily_motion.sync import accept, bootstrap, me, next_transaction, pull, snapshot_page
from tests.test_routines import publication, routine_command


def assert_backend_waits_for_owner_lock(admin: Engine, waiting: int, blocking: int) -> None:
    with admin.connect() as observer:
        deadline = monotonic() + 10
        while monotonic() < deadline:
            if observer.scalar(
                text("SELECT :blocking = ANY(pg_blocking_pids(:waiting))"),
                {"blocking": blocking, "waiting": waiting},
            ):
                return
    pytest.fail("The competing transaction never actually waited on the owner lock")


@pytest.mark.parametrize(
    ("path", "header"),
    [
        ("/v3/me", "1"),
        ("/v3/me", "2"),
        ("/v3/me", "3.0"),
        ("/v3/me", "03"),
        ("/v3/me", "3, 1"),
        ("/v3/me", ""),
        ("/v1/me", "3"),
        ("/v1/me", "2"),
    ],
)
def test_contract_declaration_cannot_change_dispatch_or_enroll_an_owner(
    owner: UUID, path: str, header: str
) -> None:
    app.dependency_overrides[verified_owner] = lambda: owner
    try:
        with TestClient(app) as client:
            response = client.get(path, headers={"X-DM-Contract": header})
            assert response.status_code == 426
            assert response.json() == {"detail": {"code": "upgrade_required"}}
            assert response.headers["cache-control"] == "private, no-store"
        assert me(owner)["position"] == 0
        with next_transaction(owner) as db:
            assert db.get(OwnerState, owner).minimum_sync_contract == 1
            assert db.scalars(select(Receipt)).all() == []
    finally:
        app.dependency_overrides.clear()


@pytest.mark.parametrize("version", [1, 2, 3.0, True, "3"])
def test_v3_body_version_refuses_before_any_database_effect(
    owner: UUID, create_body: dict[str, Any], version: object
) -> None:
    op = routine_command(create_body).model_dump(mode="json")
    app.dependency_overrides[verified_owner] = lambda: owner
    try:
        with TestClient(app) as client:
            response = client.post(
                "/v3/sync/push",
                headers={"X-DM-Contract": "3"},
                json={"schema_version": version, "operations": [op]},
            )
            assert response.status_code == 422
        assert me(owner)["position"] == 0
        with next_transaction(owner) as db:
            assert db.get(OwnerState, owner).minimum_sync_contract == 1
            assert db.scalars(select(Routine)).all() == []
            assert db.scalars(select(Receipt)).all() == []
    finally:
        app.dependency_overrides.clear()


def test_contract_three_discovery_and_workouts_do_not_enroll_without_routine_acceptance(
    owner: UUID, create_body: dict[str, Any]
) -> None:
    assert me(owner, 3)["position"] == 0
    bootstrap(owner, contract=3)
    assert accept(owner, Operation.model_validate(create_body), 3)["status"] == "accepted"
    assert me(owner)["position"] == 1
    with next_transaction(owner) as db:
        assert db.get(OwnerState, owner).minimum_sync_contract == 1
    # A domain-rejected routine cannot enroll the owner either.
    collision = routine_command(create_body)
    assert accept(owner, collision, 3)["status"] == "rejected"
    assert me(owner)["position"] == 1


@pytest.mark.parametrize("changed_payload", [False, True])
def test_duplicate_waiting_on_executing_original_keeps_one_effect(
    owner: UUID,
    create_body: dict[str, Any],
    database: Engine,
    admin_engine: Engine,
    changed_payload: bool,
) -> None:
    original = routine_command(create_body)
    retry = original.model_dump(mode="json")
    if changed_payload:
        retry["payload"]["prescription"]["name"] = "Changed identity reuse"
    duplicate = RoutineOperation.model_validate(retry)
    entered, release, second_entered = Event(), Event(), Event()
    original_backend: list[int] = []
    retry_backend: list[int] = []

    def hold_receipt(
        conn: Connection,
        cursor: Any,
        statement: str,
        parameters: Any,
        context: Any,
        executemany: bool,
    ) -> None:
        if statement.startswith("INSERT INTO training.receipts") and not entered.is_set():
            original_backend.append(conn.connection.driver_connection.info.backend_pid)
            entered.set()
            assert release.wait(20), "Original publication barrier was not released"
        elif (
            "FROM training.owner_state" in statement
            and "FOR UPDATE" in statement
            and entered.is_set()
            and not release.is_set()
        ):
            retry_backend.append(conn.connection.driver_connection.info.backend_pid)
            second_entered.set()

    event.listen(database, "before_cursor_execute", hold_receipt)
    try:
        with ThreadPoolExecutor(2) as workers:
            first = workers.submit(accept, owner, original, 3)
            assert entered.wait(20), "Original never reached its receipt transaction"

            def retry_same_identity() -> dict[str, Any]:
                return accept(owner, duplicate, 3)

            second = workers.submit(retry_same_identity)
            assert second_entered.wait(20)
            assert_backend_waits_for_owner_lock(admin_engine, retry_backend[0], original_backend[0])
            release.set()
            first_result = first.result(timeout=30)
            second_result = second.result(timeout=30)
    finally:
        release.set()
        event.remove(database, "before_cursor_execute", hold_receipt)
    assert first_result["status"] == "accepted"
    if changed_payload:
        assert second_result["status"] == "rejected"
        assert second_result["error"]["code"] == "mutation_digest_mismatch"
    else:
        assert second_result == dict(first_result, status="duplicate")
    with next_transaction(owner) as db:
        assert len(db.scalars(select(Routine)).all()) == 1
        assert len(db.scalars(select(RoutineTemplate)).all()) == 1
        assert len(db.scalars(select(Receipt)).all()) == 1
        assert len(db.scalars(select(Change)).all()) == 1
        assert db.get(OwnerState, owner).position == 1


def test_backend_termination_before_receipt_rolls_back_projection_floor_and_feed(
    owner: UUID, create_body: dict[str, Any], database: Engine, admin_engine: Engine
) -> None:
    operation = routine_command(create_body)
    entered, release = Event(), Event()
    backend: list[int] = []

    def hold_receipt(
        conn: Connection,
        cursor: Any,
        statement: str,
        parameters: Any,
        context: Any,
        executemany: bool,
    ) -> None:
        if statement.startswith("INSERT INTO training.receipts") and not entered.is_set():
            backend.append(conn.connection.driver_connection.info.backend_pid)
            entered.set()
            assert release.wait(20)

    event.listen(database, "before_cursor_execute", hold_receipt)
    try:
        with ThreadPoolExecutor(1) as workers:
            future = workers.submit(accept, owner, operation, 3)
            assert entered.wait(20)
            with admin_engine.begin() as db:
                assert db.scalar(text("SELECT pg_terminate_backend(:pid)"), {"pid": backend[0]})
            release.set()
            with pytest.raises(DBAPIError):
                future.result(timeout=30)
    finally:
        release.set()
        event.remove(database, "before_cursor_execute", hold_receipt)
    assert me(owner)["position"] == 0
    with next_transaction(owner) as db:
        assert db.get(OwnerState, owner).minimum_sync_contract == 1
        for model in (Routine, RoutineTemplate, Receipt, Change):
            assert db.scalars(select(model)).all() == []
    accepted = accept(owner, operation, 3)
    assert accepted["status"] == "accepted"
    assert accept(owner, operation, 3) == dict(accepted, status="duplicate")
    assert len(pull(owner, None, 100, 3)["changes"]) == 1


@pytest.mark.parametrize("retirement_first", [False, True])
def test_current_retirement_and_template_publication_serialize_in_both_orders(
    owner: UUID,
    create_body: dict[str, Any],
    database: Engine,
    admin_engine: Engine,
    retirement_first: bool,
) -> None:
    first = routine_command(create_body)
    accept(owner, first, 3)
    next_template = publication(first)
    entered, release, waiting = Event(), Event(), Event()
    blocking_pid: list[int] = []
    waiting_pid: list[int] = []

    def hold_first_transaction(
        conn: Connection,
        cursor: Any,
        statement: str,
        parameters: Any,
        context: Any,
        executemany: bool,
    ) -> None:
        boundary = (
            statement.startswith("UPDATE training.owner_state") and "status" in statement
            if retirement_first
            else statement.startswith("INSERT INTO training.receipts")
        )
        if boundary and not entered.is_set():
            blocking_pid.append(conn.connection.driver_connection.info.backend_pid)
            entered.set()
            assert release.wait(20)
        elif (
            "FROM training.owner_state" in statement
            and "FOR UPDATE" in statement
            and entered.is_set()
            and not release.is_set()
        ):
            waiting_pid.append(conn.connection.driver_connection.info.backend_pid)
            waiting.set()

    event.listen(database, "before_cursor_execute", hold_first_transaction)
    try:
        with ThreadPoolExecutor(2) as workers:
            first_work = (
                workers.submit(mark_account_retired, owner)
                if retirement_first
                else workers.submit(accept, owner, next_template, 3)
            )
            assert entered.wait(20)
            second_work = (
                workers.submit(accept, owner, next_template, 3)
                if retirement_first
                else workers.submit(mark_account_retired, owner)
            )
            assert waiting.wait(20)
            assert_backend_waits_for_owner_lock(admin_engine, waiting_pid[0], blocking_pid[0])
            release.set()
            if retirement_first:
                first_work.result(timeout=30)
                with pytest.raises(HTTPException) as error:
                    second_work.result(timeout=30)
                assert error.value.detail["code"] == "account_inactive"
            else:
                assert first_work.result(timeout=30)["accepted_revision"] == 2
                second_work.result(timeout=30)
    finally:
        release.set()
        event.remove(database, "before_cursor_execute", hold_first_transaction)
    with Session(admin_engine) as db:
        assert db.get(AccountRetirement, owner) is not None
        assert db.get(OwnerState, owner).status == "deleting"
        for model in (Routine, RoutineTemplate, Snapshot):
            assert db.scalars(select(model).where(model.owner_id == owner)).all() == []
        receipt = db.get(Receipt, (owner, next_template.mutation_id))
        if retirement_first:
            assert receipt is None
        else:
            assert receipt.acknowledgement["accepted_revision"] == 2
        changes = db.scalars(select(Change).where(Change.owner_id == owner)).all()
        assert len(changes) == (1 if retirement_first else 2)
        assert all(change.body.get("redacted") is True for change in changes)


def test_retirement_during_snapshot_materialization_blocks_publication(
    owner: UUID, create_body: dict[str, Any], database: Engine, admin_engine: Engine
) -> None:
    operation = routine_command(create_body)
    accept(owner, operation, 3)
    entered, release = Event(), Event()

    def hold_read(
        conn: Connection,
        cursor: Any,
        statement: str,
        parameters: Any,
        context: Any,
        executemany: bool,
    ) -> None:
        if statement.startswith("SELECT training.routine_templates.") and not entered.is_set():
            entered.set()
            assert release.wait(20)

    event.listen(database, "before_cursor_execute", hold_read)
    try:
        with ThreadPoolExecutor(1) as workers:
            future = workers.submit(bootstrap, owner, None, 3)
            assert entered.wait(20), "Snapshot never reached the real template read"
            mark_account_retired(owner)
            release.set()
            with pytest.raises(HTTPException) as error:
                future.result(timeout=30)
            assert error.value.status_code == 403
            assert error.value.detail["code"] == "account_inactive"
    finally:
        release.set()
        event.remove(database, "before_cursor_execute", hold_read)
    with Session(admin_engine) as db:
        assert db.get(AccountRetirement, owner) is not None
        assert db.get(OwnerState, owner).status == "deleting"
        assert db.scalars(select(Snapshot).where(Snapshot.owner_id == owner)).all() == []
        assert db.scalars(select(Routine).where(Routine.owner_id == owner)).all() == []
        assert (
            db.scalars(select(RoutineTemplate).where(RoutineTemplate.owner_id == owner)).all() == []
        )


def test_owner_tokens_receipts_and_duplicate_root_ids_remain_scoped(
    owner: UUID, create_body: dict[str, Any], admin_engine: Engine
) -> None:
    first = routine_command(create_body)
    accepted = accept(owner, first, 3)
    owner_cursor = pull(owner, None, 100, 3)["next_cursor"]
    owner_snapshot = bootstrap(owner, contract=3)
    other = uuid4()
    with Session(admin_engine) as db, db.begin():
        db.add(OwnerState(owner_id=other, generation=uuid4()))
    with next_transaction(other) as db:
        assert db.get(Routine, (owner, first.aggregate_id)) is None
        assert db.get(RoutineTemplate, (owner, UUID(first.payload["template_id"]))) is None
        assert db.get(Receipt, (owner, first.mutation_id)) is None
        assert (
            db.execute(
                text("UPDATE training.routines SET revision=revision+1 WHERE owner_id=:owner"),
                {"owner": owner},
            ).rowcount
            == 0
        )
    for action in (
        lambda: pull(other, owner_cursor, 100, 3),
        lambda: snapshot_page(other, owner_snapshot["token"], 0, 3),
    ):
        with pytest.raises(HTTPException) as error:
            action()
        assert error.value.status_code == 409
    # Identical UUIDs can belong to separate owners, without leaking a receipt.
    second_body = first.model_dump(mode="json")
    second_body["payload"]["prescription"]["name"] = "Other owner's private plan"
    second = RoutineOperation.model_validate(second_body)
    other_accepted = accept(other, second, 3)
    assert other_accepted["status"] == "accepted"
    assert other_accepted != dict(accepted, status="duplicate")
    assert pull(other, None, 100, 3)["changes"][0]["operation"] == second_body
    assert pull(owner, None, 100, 3)["changes"][0]["operation"] == first.model_dump(mode="json")


@pytest.mark.parametrize("boundary", ["before", "during", "after"])
def test_additive_migration_failure_is_atomic_and_retryable(
    admin_engine: Engine, boundary: str
) -> None:
    # The enclosing transaction is rolled back to the fixture's schema 0005;
    # all destructive setup is confined to the disposable local test database.
    config = Config(str(Path(__file__).parents[1] / "alembic.ini"))
    config.set_main_option("script_location", str(Path(__file__).parents[1] / "migrations"))
    with admin_engine.connect() as db:
        transaction = db.begin()
        try:
            db.execute(text("DROP SCHEMA training CASCADE"))
            db.execute(text("DROP SCHEMA recovery CASCADE"))
            db.execute(text("DROP TABLE public.alembic_version"))
            config.attributes["connection"] = db
            command.upgrade(config, "0004")
            identifier, generation = uuid4(), uuid4()
            db.execute(
                text(
                    "INSERT INTO training.owner_state(owner_id,status,generation) "
                    "VALUES(:o,'active',:g)"
                ),
                {"o": identifier, "g": generation},
            )
            old_row = dict(db.execute(text("SELECT * FROM training.owner_state")).one()._mapping)

            def fail_ddl(
                conn: Connection,
                cursor: Any,
                statement: str,
                parameters: Any,
                context: Any,
                executemany: bool,
            ) -> None:
                target = {
                    "before": "ALTER TABLE training.owner_state ADD COLUMN minimum_sync_contract",
                    "during": "ALTER TABLE training.routine_templates ENABLE ROW LEVEL SECURITY",
                    "after": "UPDATE alembic_version",
                }[boundary]
                if target in statement:
                    raise RuntimeError("Controlled routine migration interruption")

            event.listen(db, "before_cursor_execute", fail_ddl)
            try:
                with pytest.raises(RuntimeError, match="Controlled routine migration"):
                    with db.begin_nested():
                        command.upgrade(config, "head")
            finally:
                event.remove(db, "before_cursor_execute", fail_ddl)
            assert db.scalar(text("SELECT version_num FROM public.alembic_version")) == "0004"
            assert db.scalar(text("SELECT to_regclass('training.routines')")) is None
            assert (
                dict(db.execute(text("SELECT * FROM training.owner_state")).one()._mapping)
                == old_row
            )
            command.upgrade(config, "head")
            command.upgrade(config, "head")
            assert db.scalar(text("SELECT version_num FROM public.alembic_version")) == "0005"
            upgraded = dict(db.execute(text("SELECT * FROM training.owner_state")).one()._mapping)
            assert upgraded.pop("minimum_sync_contract") == 1
            assert upgraded == old_row
            with pytest.raises(RuntimeError, match="destructive downgrade denied"):
                with db.begin_nested():
                    command.downgrade(config, "0004")
            assert db.scalar(text("SELECT version_num FROM public.alembic_version")) == "0005"
        finally:
            transaction.rollback()
