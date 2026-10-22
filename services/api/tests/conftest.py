import json
import os
from collections.abc import Iterator
from pathlib import Path
from typing import Any
from uuid import UUID, uuid4

import pytest
from alembic import command
from alembic.config import Config
from sqlalchemy import Engine, create_engine, text
from sqlalchemy.orm import Session

from daily_motion.config import settings
from daily_motion.models import OwnerState
from tests.database_target import validate_local_test_target


@pytest.fixture(scope="session")
def admin_engine() -> Iterator[Engine]:
    url = os.environ.get("DM_TEST_ADMIN_URL", "")
    if not url:
        pytest.skip("PostgreSQL integration requires DM_TEST_ADMIN_URL (see README)")
    validate_local_test_target(url)
    admin = create_engine(url)
    with admin.begin() as db:
        db.execute(text("DROP SCHEMA IF EXISTS training CASCADE"))
        db.execute(text("DROP SCHEMA IF EXISTS recovery CASCADE"))
        db.execute(text("DROP TABLE IF EXISTS alembic_version"))
        db.execute(
            text(
                "DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles "
                "WHERE rolname='dm_test_runtime') THEN CREATE ROLE dm_test_runtime "
                "LOGIN PASSWORD 'synthetic-test-only' NOSUPERUSER NOBYPASSRLS; END IF; END $$"
            )
        )
    os.environ["DM_DATABASE_URL"] = url
    settings.cache_clear()
    config = Config(str(Path(__file__).parents[1] / "alembic.ini"))
    config.set_main_option("script_location", str(Path(__file__).parents[1] / "migrations"))
    command.upgrade(config, "head")
    with admin.begin() as db:
        db.execute(text("GRANT USAGE ON SCHEMA training TO dm_test_runtime"))
        db.execute(text("GRANT USAGE ON SCHEMA recovery TO dm_test_runtime"))
        db.execute(text("GRANT SELECT ON recovery.control TO dm_test_runtime"))
        db.execute(
            text(
                "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES "
                "IN SCHEMA training TO dm_test_runtime"
            )
        )
    yield admin
    admin.dispose()


@pytest.fixture
def database(admin_engine: Engine, monkeypatch: pytest.MonkeyPatch) -> Iterator[Engine]:
    from daily_motion import db

    with admin_engine.begin() as connection:
        connection.execute(
            text(
                "TRUNCATE training.owner_state, training.workouts, training.exercises, "
                "training.sets, training.observations, training.receipts, training.changes, "
                "training.retired_ids, training.snapshots, training.profiles, "
                "training.account_retirements CASCADE"
            )
        )
    url = admin_engine.url.set(username="dm_test_runtime", password="synthetic-test-only")
    runtime = create_engine(url, pool_size=5, max_overflow=0)
    monkeypatch.setattr(db, "engine", lambda: runtime)
    monkeypatch.setenv("DM_SYNC_SIGNING_KEY", "synthetic-cursor-key-with-at-least-32-characters")
    monkeypatch.setenv("DM_ENVIRONMENT", "test")
    settings.cache_clear()
    yield runtime
    runtime.dispose()
    settings.cache_clear()


@pytest.fixture
def owner(database: Engine, admin_engine: Engine) -> UUID:
    identifier = uuid4()
    with Session(admin_engine) as db, db.begin():
        db.add(
            OwnerState(
                owner_id=identifier,
                status="active",
                generation=uuid4(),
                position=0,
                erasure_epoch=0,
            )
        )
    return identifier


@pytest.fixture
def create_body() -> dict[str, Any]:
    path = Path(__file__).parents[3] / "contracts/fixtures/workout.json"
    return json.loads(path.read_text(encoding="utf-8"))  # type: ignore[no-any-return]
