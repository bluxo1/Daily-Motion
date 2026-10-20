"""Opt-in recovery qualification confined to a newly created local PostgreSQL cluster.

Run DM_RUN_RECOVERY=1 pytest tests/test_recovery.py. No existing URL is consumed.
The ordinary database fixtures are deliberately not used.
"""

import hashlib
import json
import os
import time
from collections.abc import Iterator
from concurrent.futures import ThreadPoolExecutor
from copy import deepcopy
from datetime import UTC, datetime
from pathlib import Path
from typing import Any
from uuid import UUID, uuid4

import pytest
from alembic import command as alembic_command
from alembic.config import Config
from fastapi import HTTPException
from fastapi.testclient import TestClient
from sqlalchemy import Engine, func, select, text
from sqlalchemy.exc import DBAPIError

from daily_motion import db
from daily_motion.accounts import initialize_account, mark_account_retired
from daily_motion.auth import verified_owner
from daily_motion.config import settings
from daily_motion.contracts import Operation, canonical_json
from daily_motion.main import app
from daily_motion.models import Base, Change, Receipt, Workout
from daily_motion.sync import accept, bootstrap, next_transaction, pull, snapshot_page
from tests.recovery_lab import NativeRecoveryLab, RecoveryLab, fingerprint, migrate
from tests.test_sync import command, record

pytestmark = pytest.mark.skipif(
    os.environ.get("DM_RUN_RECOVERY") != "1", reason="requires explicit DM_RUN_RECOVERY=1"
)


def bind(runtime: Engine, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(db, "engine", lambda: runtime)
    monkeypatch.setenv("DM_ENVIRONMENT", "test")
    monkeypatch.setenv(
        "DM_SYNC_SIGNING_KEY", "synthetic-recovery-signing-key-at-least-32-characters"
    )
    settings.cache_clear()


def new_body() -> dict[str, Any]:
    body = json.loads((Path(__file__).parents[3] / "contracts/fixtures/workout.json").read_text())
    body["aggregate_id"], body["mutation_id"] = str(uuid4()), str(uuid4())
    for exercise in body["payload"]["exercises"]:
        exercise["session_exercise_id"] = str(uuid4())
        for item in exercise["sets"]:
            item["set_id"] = str(uuid4())
    return body


@pytest.fixture(scope="module")
def lab() -> Iterator[RecoveryLab]:
    native = os.environ.get("DM_RECOVERY_PG_BIN")
    value = NativeRecoveryLab(Path(native)) if native else RecoveryLab()
    try:
        value.start()
        value.evidence = {"backend": "native" if native else "docker", "restore_seconds": []}
        yield value
    finally:
        value.cleanup()
        if hasattr(value, "evidence"):
            value.evidence["cleanup_confirmed"] = True
            output = Path(__file__).parents[3] / ".tools" / "recovery-observation.json"
            output.parent.mkdir(parents=True, exist_ok=True)
            output.write_text(json.dumps(value.evidence, indent=2) + "\n", encoding="utf-8")


@pytest.fixture(scope="module")
def backup(lab: RecoveryLab) -> dict[str, Any]:
    admin = lab.engine("daily_motion_test")
    runtime = lab.engine("daily_motion_test", runtime=True)
    try:
        migrate(admin)
        with pytest.MonkeyPatch.context() as patch:
            bind(runtime, patch)
            owner_a, owner_b, retired_owner = uuid4(), uuid4(), uuid4()
            for owner in (owner_a, owner_b, retired_owner):
                initialize_account(owner)
            body = new_body()
            assert accept(owner_a, Operation.model_validate(body))["accepted_revision"] == 1
            observed = record(body)
            assert accept(owner_a, observed)["accepted_revision"] == 2
            assert accept(owner_a, command(body, "complete_session", 2))["accepted_revision"] == 3
            correction = command(
                body,
                "correct_set",
                3,
                {
                    **deepcopy(observed.payload),
                    "actual": {**deepcopy(observed.payload["actual"]), "reps": 6},
                    "correction_reason": "Synthetic recovery correction",
                },
            )
            assert accept(owner_a, correction)["accepted_revision"] == 4
            other_body = new_body()
            assert accept(owner_b, Operation.model_validate(other_body))["status"] == "accepted"
            deleted = new_body()
            assert accept(owner_a, Operation.model_validate(deleted))["status"] == "accepted"
            assert accept(owner_a, record(deleted))["status"] == "accepted"
            assert accept(owner_a, command(deleted, "delete_session", 2))["status"] == "accepted"
            mark_account_retired(retired_owner)
            snapshot = bootstrap(owner_a)
            bootstrap(owner_b)
            baseline = fingerprint(admin)
            assert baseline["revision"] == "0003"
            assert len(baseline["rows"]) == 11
            assert all(table["count"] > 0 for table in baseline["rows"].values())
            archive = lab.dump()
            assert fingerprint(admin) == baseline
            with admin.connect() as connection:
                version = connection.scalar(text("SHOW server_version"))
            lab.evidence.update(
                {
                    "server_version": version,
                    "archive_bytes": len(archive),
                    "archive_sha256": hashlib.sha256(archive).hexdigest(),
                    "source_fingerprint": baseline,
                }
            )
            return {
                "archive": archive,
                "sha256": hashlib.sha256(archive).hexdigest(),
                "fingerprint": baseline,
                "a": owner_a,
                "b": owner_b,
                "retired": retired_owner,
                "body": body,
                "other_body": other_body,
                "observed": observed,
                "deleted": deleted,
                "snapshot": snapshot,
            }
    finally:
        runtime.dispose()
        admin.dispose()
        settings.cache_clear()


@pytest.fixture
def restored(lab: RecoveryLab, backup: dict[str, Any]) -> Iterator[tuple[Engine, Engine]]:
    with lab.target() as name:
        assert hashlib.sha256(backup["archive"]).hexdigest() == backup["sha256"]
        started = time.monotonic()
        result = lab.restore(name, backup["archive"])
        assert result.returncode == 0, "Isolated pg_restore failed"
        lab.evidence["restore_seconds"].append(round(time.monotonic() - started, 6))
        admin, runtime = lab.engine(name), lab.engine(name, runtime=True)
        try:
            assert fingerprint(admin) == backup["fingerprint"]
            yield admin, runtime
        finally:
            runtime.dispose()
            admin.dispose()


def empty_restore_target(admin: Engine) -> None:
    with admin.connect() as connection:
        assert (
            connection.scalar(text("SELECT count(*) FROM pg_tables WHERE schemaname='training'"))
            == 0
        )
        assert connection.scalar(text("SELECT to_regclass('public.alembic_version')")) is None


def test_missing_acl_role_restore_rolls_back(lab: RecoveryLab, backup: dict[str, Any]) -> None:
    source = lab.engine("daily_motion_test")
    try:
        with source.begin() as connection:
            connection.execute(
                text("ALTER ROLE dm_recovery_runtime RENAME TO dm_recovery_temporarily_absent")
            )
        try:
            with lab.target() as name:
                assert lab.restore(name, backup["archive"]).returncode != 0
                admin = lab.engine(name)
                try:
                    empty_restore_target(admin)
                finally:
                    admin.dispose()
        finally:
            with source.begin() as connection:
                connection.execute(
                    text("ALTER ROLE dm_recovery_temporarily_absent RENAME TO dm_recovery_runtime")
                )
        assert fingerprint(source) == backup["fingerprint"]
    finally:
        source.dispose()


def test_retirement_migration_rollback_is_refused_without_data_loss(
    restored: tuple[Engine, Engine], backup: dict[str, Any]
) -> None:
    admin, _ = restored
    root = Path(__file__).parents[1]
    config = Config(str(root / "alembic.ini"))
    config.set_main_option("script_location", str(root / "migrations"))
    with pytest.raises(RuntimeError, match="Account retirement cannot be rolled back"):
        with admin.begin() as connection:
            config.attributes["connection"] = connection
            alembic_command.downgrade(config, "0002")
    assert fingerprint(admin) == backup["fingerprint"]


@pytest.mark.parametrize("damage", ["header", "truncated"])
def test_corrupt_backup_rolls_back_all_objects(
    lab: RecoveryLab, backup: dict[str, Any], damage: str
) -> None:
    original = backup["archive"]
    damaged = b"BROKEN" + original[6:] if damage == "header" else original[: len(original) // 2]
    assert hashlib.sha256(damaged).hexdigest() != backup["sha256"]
    # Also exercise pg_restore itself: checksum rejection is not proof of DB atomicity.
    with lab.target() as name:
        assert lab.restore(name, damaged).returncode != 0
        admin = lab.engine(name)
        try:
            empty_restore_target(admin)
        finally:
            admin.dispose()


def test_interrupted_restore_preserves_preexisting_state(
    lab: RecoveryLab, backup: dict[str, Any]
) -> None:
    with lab.target() as name:
        admin = lab.engine(name)
        try:
            with admin.begin() as connection:
                connection.execute(text("CREATE TABLE public.recovery_sentinel(value integer)"))
                connection.execute(text("INSERT INTO public.recovery_sentinel VALUES (7)"))
                # An explicit index is created after COPY. Block there, rather than racing a timer.
                connection.execute(
                    text("""
                    CREATE FUNCTION public.pause_recovery_index() RETURNS event_trigger
                    LANGUAGE plpgsql AS $$ BEGIN PERFORM pg_advisory_xact_lock(734946); END $$;
                    CREATE EVENT TRIGGER pause_recovery_index ON ddl_command_start
                    WHEN TAG IN ('CREATE INDEX')
                    EXECUTE FUNCTION public.pause_recovery_index();
                """)
                )
            with admin.connect() as lock, lock.begin(), ThreadPoolExecutor(max_workers=1) as pool:
                lock.execute(text("SELECT pg_advisory_xact_lock(734946)"))
                future = pool.submit(lab.restore, name, backup["archive"])
                pid = None
                deadline = time.monotonic() + 15
                while time.monotonic() < deadline:
                    with admin.connect() as probe:
                        pid = probe.scalar(
                            text(
                                "SELECT pid FROM pg_stat_activity WHERE datname=:name "
                                "AND application_name='dm_recovery_restore' "
                                "AND wait_event='advisory' AND query LIKE 'CREATE INDEX%'"
                            ),
                            {"name": name},
                        )
                    if pid is not None:
                        break
                    if future.done():
                        pytest.fail("Restore finished before the deterministic interruption point")
                    time.sleep(0.05)
                assert pid is not None, "Restore did not reach its post-data index barrier"
                with admin.begin() as killer:
                    assert killer.scalar(text("SELECT pg_terminate_backend(:pid)"), {"pid": pid})
                assert future.result(timeout=15).returncode != 0
            empty_restore_target(admin)
            with admin.begin() as connection:
                assert connection.scalar(text("SELECT value FROM public.recovery_sentinel")) == 7
                connection.execute(text("DROP EVENT TRIGGER pause_recovery_index"))
            # The same verified archive succeeds after the interrupted transaction rolled back.
            assert lab.restore(name, backup["archive"]).returncode == 0
            assert fingerprint(admin) == backup["fingerprint"]
        finally:
            admin.dispose()


def test_restored_all_table_rls_grants_and_owner_isolation(
    restored: tuple[Engine, Engine], backup: dict[str, Any], monkeypatch: pytest.MonkeyPatch
) -> None:
    admin, runtime = restored
    bind(runtime, monkeypatch)
    db.database_readiness()
    with admin.connect() as connection:
        assert (
            connection.scalar(
                text(
                    "SELECT bool_and(relrowsecurity AND relforcerowsecurity) FROM pg_class "
                    "JOIN pg_namespace n ON n.oid=relnamespace "
                    "WHERE n.nspname='training' AND relkind='r'"
                )
            )
            is True
        )
    for owner in (backup["a"], backup["b"], backup["retired"]):
        with next_transaction(owner) as session:
            for table in Base.metadata.sorted_tables:
                assert all(row == owner for row in session.scalars(select(table.c.owner_id)))
        # Reuse the pool without an owner: no table may leak the previous transaction's context.
        with runtime.begin() as connection:
            for table in Base.metadata.sorted_tables:
                assert connection.scalar(select(func.count()).select_from(table)) == 0
    with next_transaction(backup["a"]) as session:
        assert (
            session.execute(
                text("UPDATE training.workouts SET name='forbidden' WHERE owner_id=:other"),
                {"other": backup["b"]},
            ).rowcount
            == 0
        )
    with pytest.raises(DBAPIError) as error, next_transaction(backup["a"]) as session:
        session.execute(
            text("UPDATE training.workouts SET owner_id=:other"), {"other": backup["b"]}
        )
    assert error.value.orig.sqlstate == "42501"
    with pytest.raises(DBAPIError) as foreign_key, next_transaction(backup["a"]) as session:
        session.execute(
            text("UPDATE training.exercises SET session_id=:other"),
            {"other": UUID(backup["other_body"]["aggregate_id"])},
        )
    assert foreign_key.value.orig.sqlstate == "23503"
    with pytest.raises(DBAPIError) as duplicate, next_transaction(backup["a"]) as session:
        original = session.get(Receipt, (backup["a"], backup["observed"].mutation_id))
        session.execute(
            Receipt.__table__.insert().values(
                owner_id=original.owner_id,
                mutation_id=original.mutation_id,
                digest=original.digest,
                acknowledgement=original.acknowledgement,
            )
        )
    assert duplicate.value.orig.sqlstate == "23505"
    with next_transaction(backup["retired"]) as session:
        assert session.execute(text("DELETE FROM training.account_retirements")).rowcount == 0
        assert (
            session.execute(
                text("UPDATE training.account_retirements SET retired_at=now()")
            ).rowcount
            == 0
        )
    assert fingerprint(admin) == backup["fingerprint"]


def test_restored_runtime_fails_closed_when_forced_rls_is_removed(
    restored: tuple[Engine, Engine], monkeypatch: pytest.MonkeyPatch
) -> None:
    admin, runtime = restored
    bind(runtime, monkeypatch)
    try:
        with admin.begin() as connection:
            connection.execute(text("ALTER TABLE training.receipts NO FORCE ROW LEVEL SECURITY"))
        with pytest.raises(HTTPException) as unsafe:
            db.database_readiness()
        assert unsafe.value.status_code == 503
        with pytest.raises(HTTPException), next_transaction(uuid4()):
            pytest.fail("Unsafe restored configuration admitted a tenant transaction")
    finally:
        with admin.begin() as connection:
            connection.execute(text("ALTER TABLE training.receipts FORCE ROW LEVEL SECURITY"))
    db.database_readiness()


def test_restored_http_receipts_feed_bootstrap_and_retirement(
    restored: tuple[Engine, Engine], backup: dict[str, Any], monkeypatch: pytest.MonkeyPatch
) -> None:
    admin, runtime = restored
    bind(runtime, monkeypatch)
    owner = backup["a"]
    app.dependency_overrides[verified_owner] = lambda: owner
    try:
        with TestClient(app) as client:
            response = client.post(
                "/v1/sync/push",
                json={
                    "schema_version": 1,
                    "operations": [backup["observed"].model_dump(mode="json")],
                },
            )
        assert response.status_code == 200
        acknowledgement = response.json()["results"][0]
        assert acknowledgement["status"] == "duplicate"
        assert acknowledgement["accepted_revision"] == 2
    finally:
        app.dependency_overrides.pop(verified_owner, None)
    assert fingerprint(admin) == backup["fingerprint"]
    changed = backup["observed"].model_copy(deep=True)
    changed.payload["actual"]["reps"] = 99
    assert accept(owner, changed)["error"]["code"] == "mutation_digest_mismatch"
    with next_transaction(owner) as session:
        assert session.get(Workout, (owner, UUID(backup["body"]["aggregate_id"]))).revision == 4
    page = snapshot_page(owner, backup["snapshot"]["token"], 0)
    expected = backup["snapshot"]["checksums"][0]
    assert hashlib.sha256(canonical_json(page).encode()).hexdigest() == expected
    assert page["roots"][0]["revision"] == 4
    assert page["roots"][0]["exercises"][0]["sets"][0]["observation"]["actual"]["reps"] == 6
    with pytest.raises(HTTPException):
        snapshot_page(backup["b"], backup["snapshot"]["token"], 0)
    changes = pull(owner, None, 100)["changes"]
    assert len(changes) == 7
    assert [change["position"] for change in changes] == list(range(1, 8))
    deleted = backup["deleted"]
    assert accept(owner, Operation.model_validate(deleted))["status"] == "duplicate"
    assert (
        accept(owner, command(deleted, "create_session", 0, deleted["payload"]))["error"]["code"]
        == "retired_id"
    )
    with pytest.raises(HTTPException) as retired:
        initialize_account(backup["retired"])
    assert retired.value.detail["code"] == "account_inactive"


def test_backend_loss_rolls_back_projection_receipt_and_feed(
    restored: tuple[Engine, Engine], backup: dict[str, Any], monkeypatch: pytest.MonkeyPatch
) -> None:
    admin, runtime = restored
    bind(runtime, monkeypatch)
    owner = backup["a"]
    # Flush all three effects to PostgreSQL, kill that backend before commit, then reconnect.
    with pytest.raises(DBAPIError), next_transaction(owner) as session:
        workout = session.get(Workout, (owner, UUID(backup["body"]["aggregate_id"])))
        workout.revision += 1
        session.add(
            Receipt(
                owner_id=owner,
                mutation_id=uuid4(),
                digest="0" * 64,
                acknowledgement={"status": "accepted", "accepted_revision": 5},
            )
        )
        session.add(
            Change(
                owner_id=owner,
                position=8,
                session_id=workout.id,
                created_at=datetime.now(UTC),
                body={"synthetic": True},
            )
        )
        session.flush()
        pid = session.scalar(text("SELECT pg_backend_pid()"))
        with admin.begin() as killer:
            assert killer.scalar(text("SELECT pg_terminate_backend(:pid)"), {"pid": pid})
    assert fingerprint(admin) == backup["fingerprint"]
    assert accept(owner, backup["observed"])["status"] == "duplicate"


def test_restore_fence_rejects_cursor_from_discarded_timeline(
    lab: RecoveryLab,
    restored: tuple[Engine, Engine],
    backup: dict[str, Any],
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _, runtime = restored
    owner = backup["a"]
    bind(runtime, monkeypatch)
    payload = {
        **deepcopy(backup["observed"].payload),
        "actual": {**deepcopy(backup["observed"].payload["actual"]), "reps": 7},
        "correction_reason": "Synthetic discarded timeline",
    }
    assert accept(owner, command(backup["body"], "correct_set", 4, payload))["status"] == "accepted"
    discarded_cursor = pull(owner, None, 100)["next_cursor"]
    with lab.target() as name:
        assert lab.restore(name, backup["archive"]).returncode == 0
        admin, rewound = lab.engine(name), lab.engine(name, runtime=True)
        try:
            bind(rewound, monkeypatch)
            divergent = deepcopy(payload)
            divergent["actual"]["reps"] = 8
            assert (
                accept(owner, command(backup["body"], "correct_set", 4, divergent))["status"]
                == "accepted"
            )
            # A reused position/generation can hide a divergent accepted change after rewind.
            assert pull(owner, discarded_cursor, 100)["changes"] == []
            # Recovery operator procedure: fence the NEW target before clients/jobs access it.
            with admin.begin() as connection:
                fence = Path(__file__).parents[3] / "infra/recovery/restore_fence.sql"
                connection.exec_driver_sql(fence.read_text(encoding="utf-8"))
            with pytest.raises(HTTPException) as fenced:
                pull(owner, discarded_cursor, 100)
            assert fenced.value.detail["code"] == "bootstrap_required"
            with pytest.raises(HTTPException):
                snapshot_page(owner, backup["snapshot"]["token"], 0)
            manifest = bootstrap(owner)
            root = snapshot_page(owner, manifest["token"], 0)["roots"][0]
            assert root["exercises"][0]["sets"][0]["observation"]["actual"]["reps"] == 8
            assert accept(owner, backup["observed"])["status"] == "duplicate"
            lab.evidence["discarded_timeline_cursor_reuse_reproduced"] = True
            lab.evidence["new_generation_restore_fence_verified"] = True
        finally:
            rewound.dispose()
            admin.dispose()


def test_postgresql_crash_preserves_acknowledged_restore(
    lab: RecoveryLab, restored: tuple[Engine, Engine], backup: dict[str, Any]
) -> None:
    admin, runtime = restored
    with admin.connect() as connection:
        assert connection.scalar(text("SHOW fsync")) == "on"
        assert connection.scalar(text("SHOW synchronous_commit")) == "on"
        assert connection.scalar(text("SHOW full_page_writes")) == "on"
    runtime.dispose()
    admin.dispose()
    lab.crash_restart()
    assert fingerprint(admin) == backup["fingerprint"]
    source = lab.engine("daily_motion_test")
    try:
        assert fingerprint(source) == backup["fingerprint"]
    finally:
        source.dispose()


@pytest.mark.parametrize("interruption", ["rollback", "backend_loss"])
def test_restore_fence_interruption_preserves_original_timeline(
    restored: tuple[Engine, Engine],
    backup: dict[str, Any],
    monkeypatch: pytest.MonkeyPatch,
    interruption: str,
) -> None:
    admin, runtime = restored
    bind(runtime, monkeypatch)
    owner = backup["a"]
    original_cursor = pull(owner, None, 100)["next_cursor"]
    baseline = fingerprint(admin)
    fence = Path(__file__).parents[3] / "infra/recovery/restore_fence.sql"
    error = RuntimeError if interruption == "rollback" else DBAPIError
    with pytest.raises(error):
        with admin.begin() as connection:
            connection.exec_driver_sql(fence.read_text(encoding="utf-8"))
            assert connection.scalar(text("SELECT count(*) FROM training.snapshots")) == 0
            if interruption == "rollback":
                raise RuntimeError("Synthetic interruption before restore fence commit")
            pid = connection.scalar(text("SELECT pg_backend_pid()"))
            with admin.begin() as killer:
                assert killer.scalar(text("SELECT pg_terminate_backend(:pid)"), {"pid": pid})
            connection.execute(text("SELECT 1"))
    assert fingerprint(admin) == baseline
    assert pull(owner, original_cursor, 100)["changes"] == []
    page = snapshot_page(owner, backup["snapshot"]["token"], 0)
    assert (
        hashlib.sha256(canonical_json(page).encode()).hexdigest()
        == backup["snapshot"]["checksums"][0]
    )
    assert accept(owner, backup["observed"])["status"] == "duplicate"
    assert fingerprint(admin) == baseline


def test_repeated_restore_fence_preserves_receipts_retirements_and_isolation(
    restored: tuple[Engine, Engine],
    backup: dict[str, Any],
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    admin, runtime = restored
    bind(runtime, monkeypatch)
    stale = command(backup["deleted"], "create_session", 0, backup["deleted"]["payload"])
    assert accept(backup["a"], stale)["error"]["code"] == "retired_id"
    baseline = fingerprint(admin)
    fence = Path(__file__).parents[3] / "infra/recovery/restore_fence.sql"
    for _ in range(2):
        manifests = {owner: bootstrap(owner) for owner in (backup["a"], backup["b"])}
        with admin.connect() as connection:
            previous = connection.execute(
                text(
                    "SELECT owner_id,generation,position,erasure_epoch "
                    "FROM training.owner_state ORDER BY owner_id"
                )
            ).all()
        with admin.begin() as connection:
            connection.exec_driver_sql(fence.read_text(encoding="utf-8"))
        with admin.connect() as connection:
            for owner, generation, position, epoch in previous:
                current = connection.execute(
                    text(
                        "SELECT generation,position,minimum_position,erasure_epoch "
                        "FROM training.owner_state WHERE owner_id=:owner"
                    ),
                    {"owner": owner},
                ).one()
                assert current.generation != generation
                assert current.position == current.minimum_position == position
                assert current.erasure_epoch == epoch + 1
            assert connection.scalar(text("SELECT count(*) FROM training.snapshots")) == 0
        for owner, manifest in manifests.items():
            with pytest.raises(HTTPException) as cursor_error:
                pull(owner, manifest["cursor"], 100)
            assert cursor_error.value.detail["code"] == "bootstrap_required"
            with pytest.raises(HTTPException) as snapshot_error:
                snapshot_page(owner, manifest["token"], 0)
            assert snapshot_error.value.detail["code"] == "snapshot_expired"
            fresh = bootstrap(owner)
            page = snapshot_page(owner, fresh["token"], 0)
            assert (
                hashlib.sha256(canonical_json(page).encode()).hexdigest() == fresh["checksums"][0]
            )
            expected = backup["body"] if owner == backup["a"] else backup["other_body"]
            assert [root["aggregate_id"] for root in page["roots"]] == [expected["aggregate_id"]]
            other = backup["b"] if owner == backup["a"] else backup["a"]
            with pytest.raises(HTTPException):
                snapshot_page(other, fresh["token"], 0)
            assert pull(owner, fresh["cursor"], 100)["changes"] == []
        assert accept(backup["a"], backup["observed"])["status"] == "duplicate"
        assert accept(backup["a"], stale)["error"]["code"] == "retired_id"
        with pytest.raises(HTTPException) as retired:
            initialize_account(backup["retired"])
        assert retired.value.detail["code"] == "account_inactive"
        with runtime.begin() as connection:
            for table in Base.metadata.sorted_tables:
                assert connection.scalar(select(func.count()).select_from(table)) == 0
        current = fingerprint(admin)
        assert current["metadata"] == baseline["metadata"]
        for table, rows in baseline["rows"].items():
            if table not in {"owner_state", "snapshots"}:
                assert current["rows"][table] == rows
