from collections.abc import Iterator
from contextlib import contextmanager
from uuid import UUID

import pytest
from fastapi import HTTPException
from sqlalchemy import Engine, text
from sqlalchemy.orm import Session

from daily_motion import db


def enter(owner: UUID) -> None:
    transaction = db.tenant_transaction(owner)
    try:
        next(transaction)
    finally:
        transaction.close()


def test_runtime_guard_denies_privileged_connection(
    database: Engine, admin_engine: Engine, owner: UUID, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(db, "engine", lambda: admin_engine)
    with pytest.raises(HTTPException) as error:
        enter(owner)
    assert error.value.status_code == 503
    assert error.value.detail == {"code": "service_not_configured"}
    # Nothing established a persistent tenant context on the pooled connection.
    with admin_engine.connect() as connection:
        assert (
            connection.scalar(text("SELECT nullif(current_setting('app.owner_id', true),'')"))
            is None
        )


def test_runtime_guard_denies_membership_in_table_owner_role(
    database: Engine, admin_engine: Engine, owner: UUID
) -> None:
    with admin_engine.begin() as connection:
        table_owner = connection.scalar(
            text(
                "SELECT pg_get_userbyid(relowner) FROM pg_class "
                "WHERE oid='training.workouts'::regclass"
            )
        )
        quoted_owner = connection.dialect.identifier_preparer.quote(table_owner)
        connection.execute(text(f"GRANT {quoted_owner} TO dm_test_runtime"))
    try:
        with pytest.raises(HTTPException) as error:
            enter(owner)
        assert error.value.status_code == 503
    finally:
        with admin_engine.begin() as connection:
            connection.execute(text(f"REVOKE {quoted_owner} FROM dm_test_runtime"))
    enter(owner)


@contextmanager
def unsafe_policy(admin: Engine, clause: str, undo: str) -> Iterator[None]:
    with admin.begin() as connection:
        connection.execute(text("ALTER TABLE training.workouts " + clause))
    try:
        yield
    finally:
        with admin.begin() as connection:
            connection.execute(text("ALTER TABLE training.workouts " + undo))


@pytest.mark.parametrize(
    ("clause", "undo"),
    [
        ("NO FORCE ROW LEVEL SECURITY", "FORCE ROW LEVEL SECURITY"),
        ("DISABLE ROW LEVEL SECURITY", "ENABLE ROW LEVEL SECURITY"),
    ],
)
def test_runtime_guard_rechecks_policy_changes(
    database: Engine, admin_engine: Engine, owner: UUID, clause: str, undo: str
) -> None:
    enter(owner)
    with unsafe_policy(admin_engine, clause, undo):
        with pytest.raises(HTTPException) as error:
            enter(owner)
        assert error.value.status_code == 503
    # Removing a configuration failure restores ordinary use without an app restart.
    enter(owner)
    with Session(database) as session, session.begin():
        assert (
            session.scalar(text("SELECT nullif(current_setting('app.owner_id', true),'')")) is None
        )
