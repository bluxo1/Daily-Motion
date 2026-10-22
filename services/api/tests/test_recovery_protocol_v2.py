"""Disposable PostgreSQL admission components; full protocol qualification pending.

Use tools/run_recovery_v2_local.py. Never accepts an existing database URL.
These cases do not certify a provider or a complete B0-B6 implementation.
"""

import hashlib
import os
import threading
import time
import types
from collections.abc import Iterator
from concurrent.futures import ThreadPoolExecutor
from contextlib import contextmanager
from dataclasses import dataclass, replace
from datetime import UTC, datetime
from pathlib import Path
from typing import Any
from uuid import UUID, uuid4

import pytest
from alembic import command as alembic_command
from alembic.config import Config
from fastapi import HTTPException
from sqlalchemy import Engine, text
from sqlalchemy.exc import DBAPIError
from sqlalchemy.orm import Session

from daily_motion import db, recovery_effect, sync
from daily_motion.accounts import initialize_account
from daily_motion.config import settings
from daily_motion.contracts import Operation, OperationV2, canonical_json
from daily_motion.models import AccountRetirement, Change, OwnerState, Profile, Receipt, RetiredId
from daily_motion.recovery import Activation, Checkpoint, CommittedMarker, RecoveryDenied
from daily_motion.recovery_admission import Admission, Reservation, reserve
from daily_motion.recovery_db import (
    RECOVERY_KEY,
    RECOVERY_NAMESPACE,
    close_admission,
    require_read_committed,
)
from tests.recovery_authority import ConformanceAuthority
from tests.recovery_lab import NativeRecoveryLab, fingerprint, migrate


@pytest.fixture(scope="module")
def recovery_lab() -> Iterator[NativeRecoveryLab]:
    if os.environ.get("DM_RUN_RECOVERY_V2") != "1":
        pytest.skip("DRP/2 PostgreSQL components require the explicit owned-resource launcher")
    binary = os.environ.get("DM_RECOVERY_PG_BIN")
    if not binary:
        pytest.fail("DRP/2 explicitly requested but isolated PostgreSQL binaries are missing")
    lab = NativeRecoveryLab(Path(binary))
    try:
        lab.start()
        admin = lab.engine("daily_motion_test")
        try:
            migrate(admin)
        finally:
            admin.dispose()
        yield lab
    finally:
        lab.cleanup()


@dataclass
class Target:
    admin: Engine
    runtime: Engine
    owner: UUID


@pytest.fixture
def target(recovery_lab: NativeRecoveryLab, monkeypatch: pytest.MonkeyPatch) -> Iterator[Target]:
    admin = recovery_lab.engine("daily_motion_test")
    runtime = recovery_lab.engine("daily_motion_test", runtime=True)
    with admin.begin() as connection:
        connection.execute(text("DELETE FROM recovery.control"))
    monkeypatch.setattr(db, "engine", lambda: runtime)
    monkeypatch.setenv("DM_ENVIRONMENT", "test")
    monkeypatch.setenv("DM_SYNC_SIGNING_KEY", "synthetic-v2-component-key-32-characters")
    settings.cache_clear()
    owner = uuid4()
    initialize_account(owner)
    try:
        yield Target(admin, runtime, owner)
    finally:
        runtime.dispose()
        admin.dispose()
        settings.cache_clear()


def install_control(session: Session, state: str = "CLOSED") -> None:
    session.execute(
        text("""INSERT INTO recovery.control(
          environment_id,activation_serial,incarnation,target_digest,manifest_digest,state)
          VALUES(:environment,1,:incarnation,:target,:manifest,:state)"""),
        {
            "environment": uuid4(),
            "incarnation": uuid4(),
            "target": "a" * 64,
            "manifest": "b" * 64,
            "state": state,
        },
    )


@contextmanager
def denied(code: str) -> Iterator[None]:
    with pytest.raises(HTTPException) as result:
        yield
    assert result.value.status_code == 503
    assert result.value.detail == {"code": code}


@pytest.mark.parametrize("state", ["CLOSED", "RECONCILING", "OPEN"])
def test_unverified_control_denies_all_legacy_paths_without_consuming_mutation(
    target: Target, create_body: dict[str, Any], state: str
) -> None:
    with Session(target.admin) as session, session.begin():
        install_control(session, state)
        # Recovery denial precedes application-state denial, avoiding false erasure.
        session.execute(
            text("UPDATE training.owner_state SET status='deleting' WHERE owner_id=:id"),
            {"id": target.owner},
        )
    code = "recovery_metadata_unverified" if state == "OPEN" else "recovery_unavailable"
    actions = [
        lambda: sync.me(target.owner),
        lambda: initialize_account(target.owner),
        lambda: sync.accept(target.owner, Operation.model_validate(create_body)),
        lambda: sync.pull(target.owner, None, 100),
        lambda: sync.bootstrap(target.owner),
        db.database_readiness,
    ]
    for action in actions:
        with denied(code):
            action()
    with target.admin.connect() as connection:
        for table in ("workouts", "receipts", "changes", "recovery_attempts"):
            assert (
                connection.scalar(
                    text(f"SELECT count(*) FROM training.{table} WHERE owner_id=:id"),
                    {"id": target.owner},
                )
                == 0
            )


def test_shared_domain_transaction_finishes_before_exclusive_close_and_late_request_denies(
    target: Target, create_body: dict[str, Any], monkeypatch: pytest.MonkeyPatch
) -> None:
    entered, release, closing = threading.Event(), threading.Event(), threading.Event()
    original = sync._create
    closer_pid: list[int] = []

    def paused(*args: Any, **kwargs: Any) -> Any:
        entered.set()
        assert release.wait(10)
        return original(*args, **kwargs)

    def close() -> None:
        with Session(target.admin) as session, session.begin():
            closer_pid.append(session.scalar(text("SELECT pg_backend_pid()")))
            closing.set()
            # Install the first closed control under the exact same exclusive
            # fence, without pretending an unregistered legacy DB is activated.
            session.execute(
                text("SELECT pg_advisory_xact_lock(:namespace,:key)"),
                {"namespace": RECOVERY_NAMESPACE, "key": RECOVERY_KEY},
            )
            install_control(session)
            close_admission(session)

    monkeypatch.setattr(sync, "_create", paused)
    with ThreadPoolExecutor(2) as pool:
        effect = pool.submit(sync.accept, target.owner, Operation.model_validate(create_body))
        assert entered.wait(10)
        fence = pool.submit(close)
        try:
            assert closing.wait(10)
            deadline = time.monotonic() + 10
            waiting = False
            while time.monotonic() < deadline:
                with target.admin.connect() as connection:
                    waiting = connection.scalar(
                        text("""SELECT EXISTS(
                        SELECT 1 FROM pg_locks WHERE pid=:pid
                        AND locktype='advisory' AND NOT granted)"""),
                        {"pid": closer_pid[0]},
                    )
                if waiting:
                    break
                time.sleep(0.01)
            assert waiting is True, "Actual pg_locks wait must prove fence ordering"
            assert not fence.done()
        finally:
            release.set()
        assert effect.result(timeout=10)["status"] == "accepted"
        fence.result(timeout=10)
    with denied("recovery_unavailable"):
        sync.accept(target.owner, Operation.model_validate(create_body))
    with target.admin.connect() as connection:
        assert (
            connection.scalar(
                text("SELECT count(*) FROM training.receipts WHERE owner_id=:id"),
                {"id": target.owner},
            )
            == 1
        )
        assert (
            connection.scalar(
                text("SELECT count(*) FROM training.changes WHERE owner_id=:id"),
                {"id": target.owner},
            )
            == 1
        )


def test_effect_isolation_and_failed_close_do_not_claim_a_completed_fence(target: Target) -> None:
    with Session(target.admin) as session, session.begin():
        install_control(session, "OPEN")
    with Session(target.admin.execution_options(isolation_level="REPEATABLE READ")) as session:
        with denied("recovery_metadata_unverified"):
            close_admission(session)
    with Session(target.admin) as session:
        transaction = session.begin()
        close_admission(session)
        transaction.rollback()
    with target.admin.connect() as connection:
        assert connection.scalar(text("SELECT state FROM recovery.control")) == "OPEN"
    with denied("recovery_metadata_unverified"):
        sync.me(target.owner)


@pytest.mark.parametrize("privilege", ["UPDATE", "TRUNCATE", "TRIGGER"])
def test_runtime_cannot_activate_or_widen_control_grants(target: Target, privilege: str) -> None:
    with Session(target.runtime) as session:
        with pytest.raises(DBAPIError):
            close_admission(session)
    with target.admin.begin() as connection:
        connection.execute(text(f"GRANT {privilege} ON recovery.control TO dm_recovery_runtime"))
    try:
        with denied("service_not_configured"):
            sync.me(target.owner)
    finally:
        with target.admin.begin() as connection:
            connection.execute(
                text(f"REVOKE {privilege} ON recovery.control FROM dm_recovery_runtime")
            )


def test_default_effect_transaction_is_read_committed_and_pool_resets_owner(target: Target) -> None:
    with sync.next_transaction(target.owner) as session:
        require_read_committed(session)
    with target.runtime.connect() as connection:
        assert (
            connection.scalar(text("SELECT nullif(current_setting('app.owner_id',true),'')"))
            is None
        )


def test_new_private_metadata_has_forced_owner_rls_and_legacy_receipts_are_unchanged(
    target: Target, create_body: dict[str, Any]
) -> None:
    operation = Operation.model_validate(create_body)
    result = sync.accept(target.owner, operation)
    with target.admin.connect() as connection:
        receipt = connection.execute(
            text("""SELECT digest,acknowledgement FROM training.receipts
          WHERE owner_id=:owner AND mutation_id=:mutation"""),
            {"owner": target.owner, "mutation": operation.mutation_id},
        ).one()
        assert receipt.acknowledgement == result
        assert "origin_incarnation" not in receipt.acknowledgement
        assert connection.scalar(text("SELECT version_num FROM public.alembic_version")) == "0004"
        assert (
            connection.scalar(
                text("""SELECT bool_and(relrowsecurity AND relforcerowsecurity)
          FROM pg_class WHERE oid IN ('training.recovery_owners'::regclass,
          'training.recovery_attempts'::regclass)""")
            )
            is True
        )
    with sync.next_transaction(target.owner) as session:
        session.execute(
            text("""INSERT INTO training.recovery_owners(owner_id,environment_id,
          incarnation,generation,evidence_digest) VALUES(:owner,:e,:i,:g,:digest)"""),
            {"owner": target.owner, "e": uuid4(), "i": uuid4(), "g": uuid4(), "digest": "0" * 64},
        )
    with sync.next_transaction(uuid4()) as session:
        assert session.scalar(text("SELECT count(*) FROM training.recovery_owners")) == 0


@pytest.mark.parametrize("populated", [False, True])
def test_additive_migration_and_old_binary_denial(
    recovery_lab: NativeRecoveryLab,
    create_body: dict[str, Any],
    monkeypatch: pytest.MonkeyPatch,
    populated: bool,
) -> None:
    """PG21: empty/populated upgrade plus actual baseline readiness code.

    The frozen baseline module uses the real restricted connection. This does
    not deploy an old service or claim containment of separately running workers.
    """
    root = Path(__file__).parents[1]
    config = Config(str(root / "alembic.ini"))
    config.set_main_option("script_location", str(root / "migrations"))
    with recovery_lab.target() as name:
        admin = recovery_lab.engine(name)
        runtime = recovery_lab.engine(name, runtime=True)
        try:
            with admin.begin() as connection:
                config.attributes["connection"] = connection
                alembic_command.upgrade(config, "0003")
            owner, retired_owner = uuid4(), uuid4()
            operation = Operation.model_validate(create_body)
            if populated:
                with Session(admin) as session, session.begin():
                    seed_legacy_upgrade(session, owner, retired_owner, operation, create_body)
            before = fingerprint(admin)
            assert before["revision"] == "0003"
            with pytest.raises(RuntimeError, match="Account retirement cannot be rolled back"):
                with admin.begin() as connection:
                    config.attributes["connection"] = connection
                    alembic_command.downgrade(config, "0002")
            assert fingerprint(admin) == before
            with admin.begin() as connection:
                config.attributes["connection"] = connection
                alembic_command.upgrade(config, "head")
            after = fingerprint(admin)
            assert after["revision"] == "0004"
            assert all(after["rows"][name] == rows for name, rows in before["rows"].items())
            assert after["rows"]["recovery_owners"]["count"] == 0
            assert after["rows"]["recovery_attempts"]["count"] == 0
            with admin.begin() as connection:
                assert connection.scalar(text("SELECT count(*) FROM recovery.control")) == 0
                # Match the existing owned lab's restricted role, never its
                # migration principal. Grants apply only to this generated DB.
                connection.execute(
                    text("GRANT USAGE ON SCHEMA training,recovery TO dm_recovery_runtime")
                )
                connection.execute(text("GRANT SELECT ON recovery.control TO dm_recovery_runtime"))
                connection.execute(
                    text(
                        "GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA training "
                        "TO dm_recovery_runtime"
                    )
                )
                connection.execute(
                    text("GRANT SELECT ON public.alembic_version TO dm_recovery_runtime")
                )
                assert (
                    connection.scalar(
                        text("""SELECT count(*)=2 AND
                          bool_and(relrowsecurity AND relforcerowsecurity)
                      FROM pg_class WHERE oid IN ('training.recovery_owners'::regclass,
                      'training.recovery_attempts'::regclass)""")
                    )
                    is True
                )
            monkeypatch.setattr(db, "engine", lambda: runtime)
            db.database_readiness()
            with Session(admin) as session, session.begin():
                # An owned test arrangement only, not a verified activation.
                install_control(session, "OPEN")
            source = (root / "tests/fixtures/recovery_v1_db.py.txt").read_bytes()
            assert hashlib.sha256(source).hexdigest() == (
                "17dafc001b918c5e6648aec07622fd87e12998a836251197e5bb2d0d60e74109"
            )
            old = types.ModuleType("baseline_2781f5c_db")
            exec(compile(source, "baseline_2781f5c/db.py", "exec"), old.__dict__)
            old.engine = lambda: runtime  # type: ignore[attr-defined]
            with denied("service_not_configured"):
                old.database_readiness()  # type: ignore[attr-defined]
            with denied("recovery_metadata_unverified"):
                db.database_readiness()
            with Session(admin) as session, session.begin():
                close_admission(session)
            before_downgrade = fingerprint(admin)
            with pytest.raises(RuntimeError, match="compatible forward fix"):
                with admin.begin() as connection:
                    config.attributes["connection"] = connection
                    alembic_command.downgrade(config, "0003")
            assert fingerprint(admin) == before_downgrade
            with admin.connect() as connection:
                assert connection.scalar(text("SELECT state FROM recovery.control")) == "CLOSED"
            with denied("recovery_unavailable"):
                db.database_readiness()
        finally:
            runtime.dispose()
            admin.dispose()


def seed_legacy_upgrade(
    session: Session,
    owner: UUID,
    retired_owner: UUID,
    operation: Operation,
    create_body: dict[str, Any],
) -> None:
    session.add(
        OwnerState(
            owner_id=owner,
            status="active",
            generation=uuid4(),
            position=1,
            erasure_epoch=3,
        )
    )
    session.flush()
    sync._create(session, owner, operation)
    session.add(
        Receipt(
            owner_id=owner,
            mutation_id=operation.mutation_id,
            digest=hashlib.sha256(canonical_json(create_body).encode()).hexdigest(),
            acknowledgement={
                "mutation_id": str(operation.mutation_id),
                "aggregate_id": str(operation.aggregate_id),
                "status": "accepted",
                "accepted_revision": 1,
                "accepted_at": "2026-10-21T12:00:00Z",
            },
        )
    )
    session.add(
        Change(
            owner_id=owner,
            position=1,
            session_id=operation.aggregate_id,
            created_at=datetime.now(UTC),
            body={"operation": create_body, "revision": 1},
        )
    )
    session.add(RetiredId(owner_id=owner, id=uuid4()))
    session.add(AccountRetirement(owner_id=retired_owner, retired_at=datetime.now(UTC)))


def test_database_enforces_one_active_attempt_per_owner(target: Target) -> None:
    with sync.next_transaction(target.owner) as session:
        session.execute(
            text("""INSERT INTO training.recovery_owners(owner_id,environment_id,
          incarnation,generation,evidence_digest) VALUES(:owner,:e,:i,:g,:d)"""),
            {"owner": target.owner, "e": uuid4(), "i": uuid4(), "g": uuid4(), "d": "0" * 64},
        )
        values = {
            "owner": target.owner,
            "attempt": uuid4(),
            "mutation": uuid4(),
            "e": uuid4(),
            "i": uuid4(),
            "g": uuid4(),
            "d": "a" * 64,
        }
        insert = text("""INSERT INTO training.recovery_attempts(owner_id,attempt_id,mutation_id,
          schema_version,environment_id,incarnation,generation,activation_serial,request_digest,state)
          VALUES(:owner,:attempt,:mutation,2,:e,:i,:g,1,:d,'RESERVED')""")
        session.execute(insert, values)
        with pytest.raises(DBAPIError) as error:
            with session.begin_nested():
                session.execute(insert, {**values, "attempt": uuid4(), "mutation": uuid4()})
        assert error.value.orig.sqlstate == "23505"
        assert session.scalar(text("SELECT count(*) FROM training.recovery_attempts")) == 1


@dataclass
class ReservationCase:
    activation: Activation
    operation: OperationV2
    authority: ConformanceAuthority
    other_owner: UUID
    other_generation: UUID

    def fresh(self, owner: UUID) -> Admission:
        nonce = uuid4()
        return Admission(
            self.authority.current(self.activation, owner, nonce),
            nonce,
            self.activation,
            self.activation.target_digest,
            self.activation.serial,
        )


@pytest.fixture
def reservation_case(
    target: Target, create_body: dict[str, Any], tmp_path: Path
) -> ReservationCase:
    # Explicit owned-lab inventory/identity fixtures, not a production target
    # proof, activation procedure or retroactive certification of legacy data.
    other_owner, other_generation = uuid4(), uuid4()
    with Session(target.admin) as session, session.begin():
        install_control(session, "OPEN")
        control = session.execute(text("SELECT * FROM recovery.control")).mappings().one()
        activation = Activation(
            control["environment_id"],
            control["activation_serial"],
            control["incarnation"],
            control["target_digest"],
            control["manifest_digest"],
        )
        generation = session.scalar(
            text("SELECT generation FROM training.owner_state WHERE owner_id=:owner"),
            {"owner": target.owner},
        )
        assert isinstance(generation, UUID)
        session.add(
            OwnerState(
                owner_id=other_owner,
                status="active",
                generation=other_generation,
                position=0,
                erasure_epoch=0,
                minimum_position=0,
            )
        )
        session.flush()
        session.add(Profile(owner_id=other_owner, unit="kg"))
        session.execute(
            text("""INSERT INTO training.recovery_owners(owner_id,environment_id,
          incarnation,generation,evidence_digest) VALUES(:owner,:e,:i,:g,:digest)"""),
            {
                "owner": target.owner,
                "e": activation.environment,
                "i": activation.incarnation,
                "g": generation,
                "digest": "0" * 64,
            },
        )
        session.execute(
            text("""INSERT INTO training.recovery_owners(owner_id,environment_id,
              incarnation,generation,evidence_digest) VALUES(:owner,:e,:i,:g,:digest)"""),
            {
                "owner": other_owner,
                "e": activation.environment,
                "i": activation.incarnation,
                "g": other_generation,
                "digest": "0" * 64,
            },
        )
    operation = OperationV2.model_validate(
        {
            **create_body,
            "schema_version": 2,
            "environment_id": str(activation.environment),
            "origin_incarnation": str(activation.incarnation),
            "origin_generation": str(generation),
        }
    )
    authority = ConformanceAuthority.create(
        tmp_path / "authority.sqlite",
        activation,
        {target.owner: generation, other_owner: other_generation},
    )
    return ReservationCase(activation, operation, authority, other_owner, other_generation)


def reserve_case(
    target: Target,
    case: ReservationCase,
    admission: Admission | None = None,
    operation: OperationV2 | None = None,
) -> Reservation:
    # The authority read closes before the PostgreSQL transaction begins.
    admission = admission or case.fresh(target.owner)
    with Session(target.runtime) as session, session.begin():
        return reserve(session, target.owner, operation or case.operation, admission, uuid4())


def owner_rows(target: Target) -> dict[str, list[Any]]:
    tables = (
        "owner_state",
        "profiles",
        "workouts",
        "exercises",
        "sets",
        "observations",
        "receipts",
        "changes",
        "retired_ids",
        "snapshots",
        "recovery_owners",
        "recovery_attempts",
    )
    with target.admin.connect() as connection:
        return {
            table: list(
                connection.scalars(
                    text(
                        f"SELECT to_jsonb(t) FROM training.{table} t "
                        "WHERE owner_id=:owner ORDER BY to_jsonb(t)::text"
                    ),
                    {"owner": target.owner},
                )
            )
            for table in tables
        }


def assert_no_domain_effect(target: Target) -> None:
    with target.admin.connect() as connection:
        for table in (
            "workouts",
            "exercises",
            "sets",
            "observations",
            "receipts",
            "changes",
            "retired_ids",
        ):
            assert (
                connection.scalar(
                    text(f"SELECT count(*) FROM training.{table} WHERE owner_id=:owner"),
                    {"owner": target.owner},
                )
                == 0
            )
        assert (
            connection.scalar(
                text("SELECT position FROM training.owner_state WHERE owner_id=:owner"),
                {"owner": target.owner},
            )
            == 0
        )


def test_reservation_restart_and_preparation_response_loss_keep_one_attempt_without_effect(
    target: Target, reservation_case: ReservationCase
) -> None:
    first = reserve_case(target, reservation_case)
    second = reserve_case(target, reservation_case)
    assert first == second
    checkpoint = reservation_case.authority.prepare(first.intent, first.prior)
    assert checkpoint == first.prepared_checkpoint
    # Response loss at B2: a new request/nonce/candidate T reads exactly the same
    # independent PREPARED binding rather than manufacturing a new attempt.
    assert reserve_case(target, reservation_case) == first
    assert (
        reservation_case.authority.lookup(
            target.owner, first.intent.mutation, first.intent.request_digest
        )
        is None
    )
    with target.admin.connect() as connection:
        row = (
            connection.execute(
                text("SELECT * FROM training.recovery_attempts WHERE owner_id=:owner"),
                {"owner": target.owner},
            )
            .mappings()
            .one()
        )
        assert row["state"] == "RESERVED"
        assert (
            row["result"] is None and row["committed_marker"] is None and row["certificate"] is None
        )
        assert row["frozen_request"] == first.storage()
        assert (
            connection.scalar(
                text("SELECT hold_attempt FROM training.recovery_owners WHERE owner_id=:owner"),
                {"owner": target.owner},
            )
            == first.intent.attempt
        )
        assert (
            connection.scalar(
                text("SELECT evidence_order FROM training.recovery_owners WHERE owner_id=:owner"),
                {"owner": target.owner},
            )
            == 0
        )
    assert_no_domain_effect(target)


@pytest.mark.parametrize("field", ["environment_id", "origin_incarnation", "origin_generation"])
def test_reservation_rejects_old_origin_without_creating_hold_or_consuming_identity(
    target: Target, reservation_case: ReservationCase, field: str
) -> None:
    body = reservation_case.operation.model_dump(mode="json")
    body[field] = str(uuid4())
    with pytest.raises(RecoveryDenied, match="timeline_reconciliation_required"):
        reserve_case(target, reservation_case, operation=OperationV2.model_validate(body))
    with target.admin.connect() as connection:
        assert (
            connection.scalar(
                text("SELECT count(*) FROM training.recovery_attempts WHERE owner_id=:owner"),
                {"owner": target.owner},
            )
            == 0
        )
        assert (
            connection.scalar(
                text("SELECT hold_attempt FROM training.recovery_owners WHERE owner_id=:owner"),
                {"owner": target.owner},
            )
            is None
        )
    assert_no_domain_effect(target)


@pytest.mark.parametrize("fault", ["nonce", "target", "owner", "head", "closed"])
def test_reservation_requires_request_bound_fresh_admission(
    target: Target, reservation_case: ReservationCase, fault: str
) -> None:
    admission = reservation_case.fresh(target.owner)
    if fault == "nonce":
        admission = replace(admission, nonce=uuid4())
    elif fault == "target":
        admission = replace(admission, verified_target_digest="f" * 64)
    elif fault == "owner":
        admission = replace(admission, assertion=replace(admission.assertion, owner=uuid4()))
    elif fault == "head":
        admission = replace(
            admission, assertion=replace(admission.assertion, checkpoint=Checkpoint(1, "a" * 64))
        )
    else:
        with Session(target.admin) as session, session.begin():
            close_admission(session)
    with pytest.raises(RecoveryDenied):
        reserve_case(target, reservation_case, admission=admission)
    assert_no_domain_effect(target)
    with target.admin.connect() as connection:
        assert (
            connection.scalar(
                text("SELECT count(*) FROM training.recovery_attempts WHERE owner_id=:owner"),
                {"owner": target.owner},
            )
            == 0
        )


def test_reservation_digest_mismatch_and_other_root_do_not_replace_owner_hold(
    target: Target, reservation_case: ReservationCase
) -> None:
    first = reserve_case(target, reservation_case)
    body = reservation_case.operation.model_dump(mode="json")
    body["payload"] = {**body["payload"], "name": "Changed frozen identity"}
    with pytest.raises(RecoveryDenied, match="mutation_digest_mismatch"):
        reserve_case(target, reservation_case, operation=OperationV2.model_validate(body))
    body = reservation_case.operation.model_dump(mode="json")
    body.update(mutation_id=str(uuid4()), aggregate_id=str(uuid4()))
    with pytest.raises(RecoveryDenied, match="publication_pending"):
        reserve_case(target, reservation_case, operation=OperationV2.model_validate(body))
    reservation_case.authority.prepare(first.intent, first.prior)
    # A new root during the B2/B3 gap observes the known owner's PREPARED
    # checkpoint and remains pending, rather than resetting the evidence head.
    with pytest.raises(RecoveryDenied, match="publication_pending"):
        reserve_case(target, reservation_case, operation=OperationV2.model_validate(body))
    assert reserve_case(target, reservation_case) == first
    assert_no_domain_effect(target)


def test_reservation_reads_account_state_after_lock_instead_of_using_cached_orm(
    target: Target, reservation_case: ReservationCase
) -> None:
    admission = reservation_case.fresh(target.owner)
    with Session(target.runtime) as session, session.begin():
        session.execute(
            text("SELECT set_config('app.owner_id',:owner,true)"), {"owner": str(target.owner)}
        )
        cached = session.get(OwnerState, target.owner)
        assert cached is not None and cached.status == "active"
        with target.admin.begin() as connection:
            connection.execute(
                text("UPDATE training.owner_state SET status='deleting' WHERE owner_id=:owner"),
                {"owner": target.owner},
            )
        with pytest.raises(RecoveryDenied, match="recovery_unavailable"):
            reserve(session, target.owner, reservation_case.operation, admission, uuid4())
        assert cached.status == "deleting"
    assert_no_domain_effect(target)


def test_failed_hold_update_rolls_back_reservation_then_exact_request_can_retry(
    target: Target, reservation_case: ReservationCase
) -> None:
    with target.admin.begin() as connection:
        connection.execute(
            text("""CREATE FUNCTION recovery.test_fail_hold() RETURNS trigger
          LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'synthetic hold fault'; END $$;
          CREATE TRIGGER test_fail_hold BEFORE UPDATE ON training.recovery_owners
          FOR EACH ROW EXECUTE FUNCTION recovery.test_fail_hold();""")
        )
    try:
        with pytest.raises(DBAPIError):
            reserve_case(target, reservation_case)
    finally:
        with target.admin.begin() as connection:
            connection.execute(
                text(
                    "DROP TRIGGER test_fail_hold ON training.recovery_owners; "
                    "DROP FUNCTION recovery.test_fail_hold();"
                )
            )
    with target.admin.connect() as connection:
        assert (
            connection.scalar(
                text("SELECT count(*) FROM training.recovery_attempts WHERE owner_id=:owner"),
                {"owner": target.owner},
            )
            == 0
        )
        assert (
            connection.scalar(
                text("SELECT hold_attempt FROM training.recovery_owners WHERE owner_id=:owner"),
                {"owner": target.owner},
            )
            is None
        )
    assert_no_domain_effect(target)
    assert reserve_case(target, reservation_case).frozen_body == canonical_json(
        reservation_case.operation.model_dump(mode="json")
    )


@pytest.mark.parametrize("missing", ["owner_metadata", "application_owner", "control"])
def test_reservation_never_initializes_missing_recovery_or_account_inventory(
    target: Target, reservation_case: ReservationCase, missing: str
) -> None:
    with target.admin.begin() as connection:
        if missing == "control":
            connection.execute(text("DELETE FROM recovery.control"))
        else:
            table = "recovery_owners" if missing == "owner_metadata" else "owner_state"
            if missing == "application_owner":
                # Simulate an archive without the application owner/profile;
                # retain the real FK rather than weakening it for the test.
                connection.execute(
                    text("DELETE FROM training.profiles WHERE owner_id=:owner"),
                    {"owner": target.owner},
                )
            connection.execute(
                text(f"DELETE FROM training.{table} WHERE owner_id=:owner"), {"owner": target.owner}
            )
    with pytest.raises(RecoveryDenied):
        reserve_case(target, reservation_case)
    with target.admin.connect() as connection:
        assert (
            connection.scalar(
                text("SELECT count(*) FROM training.recovery_attempts WHERE owner_id=:owner"),
                {"owner": target.owner},
            )
            == 0
        )


def test_reservation_does_not_override_retired_owner_or_unsupported_isolation(
    target: Target, reservation_case: ReservationCase
) -> None:
    admission = reservation_case.fresh(target.owner)
    with (
        Session(target.runtime.execution_options(isolation_level="REPEATABLE READ")) as session,
        session.begin(),
    ):
        with denied("recovery_metadata_unverified"):
            reserve(session, target.owner, reservation_case.operation, admission, uuid4())
    with Session(target.admin) as session, session.begin():
        session.add(AccountRetirement(owner_id=target.owner, retired_at=datetime.now(UTC)))
    with pytest.raises(RecoveryDenied, match="recovery_unavailable"):
        reserve_case(target, reservation_case)
    assert_no_domain_effect(target)


def test_concurrent_exact_reservations_share_one_attempt_and_independent_owners_are_isolated(
    target: Target, reservation_case: ReservationCase
) -> None:
    barrier = threading.Barrier(2)
    admissions = [reservation_case.fresh(target.owner) for _ in range(2)]

    def exact(index: int) -> Reservation:
        barrier.wait(timeout=10)
        return reserve_case(target, reservation_case, admission=admissions[index])

    with ThreadPoolExecutor(2) as pool:
        values = list(pool.map(exact, [0, 1]))
    assert values[0] == values[1]
    with target.admin.connect() as connection:
        assert (
            connection.scalar(
                text("SELECT count(*) FROM training.recovery_attempts WHERE owner_id=:owner"),
                {"owner": target.owner},
            )
            == 1
        )
    assert_no_domain_effect(target)
    barrier = threading.Barrier(2)

    def independent(owner: UUID) -> Reservation:
        admission = reservation_case.fresh(owner)
        body = reservation_case.operation.model_dump(mode="json")
        if owner == reservation_case.other_owner:
            body["origin_generation"] = str(reservation_case.other_generation)
        operation = OperationV2.model_validate(body)
        barrier.wait(timeout=10)
        with Session(target.runtime) as session, session.begin():
            return reserve(session, owner, operation, admission, uuid4())

    with ThreadPoolExecutor(2) as pool:
        results = list(pool.map(independent, [target.owner, reservation_case.other_owner]))
    assert results[0] == values[0]
    assert results[1].intent.owner == reservation_case.other_owner
    assert results[1].intent.mutation == results[0].intent.mutation
    assert results[1].intent.attempt != results[0].intent.attempt
    for owner in (target.owner, reservation_case.other_owner):
        with Session(target.runtime) as session, session.begin():
            session.execute(
                text("SELECT set_config('app.owner_id',:owner,true)"), {"owner": str(owner)}
            )
            rows = (
                session.execute(text("SELECT * FROM training.recovery_attempts")).mappings().all()
            )
            assert len(rows) == 1 and rows[0]["owner_id"] == owner
            assert session.scalar(text("SELECT count(*) FROM training.workouts")) == 0


@pytest.mark.parametrize("changed_digest", [False, True])
def test_retained_receipt_without_verified_attempt_never_becomes_a_new_reservation(
    target: Target, reservation_case: ReservationCase, changed_digest: bool
) -> None:
    operation = reservation_case.operation
    digest = hashlib.sha256(canonical_json(operation.model_dump(mode="json")).encode()).hexdigest()
    with Session(target.admin) as session, session.begin():
        session.add(
            Receipt(
                owner_id=target.owner,
                mutation_id=operation.mutation_id,
                digest="f" * 64 if changed_digest else digest,
                acknowledgement={
                    "mutation_id": str(operation.mutation_id),
                    "aggregate_id": str(operation.aggregate_id),
                    "status": "accepted",
                    "accepted_revision": 1,
                    "accepted_at": "2026-10-22T00:00:00Z",
                },
            )
        )
    code = "mutation_digest_mismatch" if changed_digest else "timeline_reconciliation_required"
    with pytest.raises(RecoveryDenied, match=code):
        reserve_case(target, reservation_case)
    with target.admin.connect() as connection:
        assert (
            connection.scalar(
                text("SELECT count(*) FROM training.receipts WHERE owner_id=:owner"),
                {"owner": target.owner},
            )
            == 1
        )
        for table in ("workouts", "changes", "recovery_attempts"):
            assert (
                connection.scalar(
                    text(f"SELECT count(*) FROM training.{table} WHERE owner_id=:owner"),
                    {"owner": target.owner},
                )
                == 0
            )
        assert (
            connection.scalar(
                text("SELECT hold_attempt FROM training.recovery_owners WHERE owner_id=:owner"),
                {"owner": target.owner},
            )
            is None
        )


def test_shared_transaction_orders_before_exclusive_fence(
    target: Target, reservation_case: ReservationCase, monkeypatch: pytest.MonkeyPatch
) -> None:
    """PG04: pause the actual B3 transaction, observe its exclusive waiter in PG."""
    reservation = reserve_case(target, reservation_case)
    reservation_case.authority.prepare(reservation.intent, reservation.prior)
    admission = reservation_case.fresh(target.owner)
    entered, release, closing = threading.Event(), threading.Event(), threading.Event()
    original = recovery_effect.apply_domain_change
    closer_pid: list[int] = []

    def paused(*args: Any, **kwargs: Any) -> Any:
        entered.set()
        assert release.wait(10)
        return original(*args, **kwargs)

    def effect() -> CommittedMarker:
        with Session(target.runtime) as session, session.begin():
            return recovery_effect.commit_effect(session, target.owner, reservation, admission)

    def close() -> None:
        with Session(target.admin) as session, session.begin():
            closer_pid.append(session.scalar(text("SELECT pg_backend_pid()")))
            closing.set()
            close_admission(session)

    monkeypatch.setattr(recovery_effect, "apply_domain_change", paused)
    with ThreadPoolExecutor(2) as pool:
        working = pool.submit(effect)
        assert entered.wait(10)
        fence = pool.submit(close)
        try:
            assert closing.wait(10)
            deadline, waiting = time.monotonic() + 10, False
            while time.monotonic() < deadline:
                with target.admin.connect() as connection:
                    waiting = connection.scalar(
                        text("""SELECT EXISTS(
                      SELECT 1 FROM pg_locks WHERE pid=:pid
                      AND locktype='advisory' AND NOT granted)"""),
                        {"pid": closer_pid[0]},
                    )
                if waiting:
                    break
                time.sleep(0.01)
            assert waiting is True and not fence.done()
        finally:
            release.set()
        marker = working.result(timeout=10)
        assert marker.private_position == 1
        fence.result(timeout=10)
    # Arrival/authentication before close cannot authorize another B3 afterward.
    with pytest.raises(RecoveryDenied, match="recovery_unavailable"):
        effect()
    with target.admin.connect() as connection:
        assert connection.scalar(text("SELECT state FROM recovery.control")) == "CLOSED"
        for table in ("workouts", "changes", "receipts"):
            assert (
                connection.scalar(
                    text(f"SELECT count(*) FROM training.{table} WHERE owner_id=:owner"),
                    {"owner": target.owner},
                )
                == 1
            )
        metadata = (
            connection.execute(
                text("SELECT * FROM training.recovery_owners WHERE owner_id=:owner"),
                {"owner": target.owner},
            )
            .mappings()
            .one()
        )
        assert metadata["hold_attempt"] == reservation.intent.attempt
        assert metadata["visible_position"] == 0


def assert_old_origin_denied(target: Target, case: ReservationCase, revision: int) -> None:
    # Arrange the divergent restored branch explicitly. These are actual PG
    # admission tests, not an archive restoration or independent target proof.
    domain = {
        key: value
        for key, value in case.operation.model_dump(mode="json").items()
        if key
        not in {"schema_version", "environment_id", "origin_incarnation", "origin_generation"}
    }
    with Session(target.admin) as session, session.begin():
        workout = sync._create(session, target.owner, Operation.model_validate(domain))
        workout.name = "Restored divergent branch"
        workout.revision = revision
    exercise = case.operation.payload["exercises"][0]
    old = OperationV2.model_validate(
        {
            **case.operation.model_dump(mode="json"),
            "mutation_id": str(uuid4()),
            "origin_incarnation": str(uuid4()),
            "origin_generation": str(uuid4()),
            "expected_revision": 2,
            "command": "record_set",
            "payload": {
                "session_exercise_id": exercise["session_exercise_id"],
                "set_id": exercise["sets"][0]["set_id"],
                "execution_status": "completed",
                "actual": {
                    "load": {"value": "60", "unit": "kg", "basis": "total_external"},
                    "reps": 5,
                    "rep_convention": "bilateral",
                    "effort": None,
                },
                "completion_seq": 1,
                "order_source": "logged",
            },
        }
    )
    frozen = canonical_json(old.model_dump(mode="json")).encode()
    digest = hashlib.sha256(frozen).hexdigest()
    before = owner_rows(target)
    with pytest.raises(RecoveryDenied, match="timeline_reconciliation_required"):
        reserve_case(target, case, operation=OperationV2.model_validate_json(frozen))
    assert owner_rows(target) == before
    assert canonical_json(old.model_dump(mode="json")).encode() == frozen
    assert hashlib.sha256(frozen).hexdigest() == digest
    assert before["workouts"][0]["revision"] == revision
    assert before["workouts"][0]["name"] == "Restored divergent branch"
    assert not before["observations"] and not before["receipts"] and not before["changes"]
    assert not before["recovery_attempts"]
    assert before["recovery_owners"][0]["hold_attempt"] is None


def test_old_origin_equal_revision_denied(
    target: Target, reservation_case: ReservationCase
) -> None:
    """PG01: an equal R cannot make a frozen G1 body current on G2."""
    assert_old_origin_denied(target, reservation_case, 2)


@pytest.mark.parametrize("revision", [1, 3])
def test_old_origin_lower_higher_revision_denied(
    target: Target, reservation_case: ReservationCase, revision: int
) -> None:
    """PG02: provenance denial precedes ordinary lower/higher R comparison."""
    assert_old_origin_denied(target, reservation_case, revision)


@pytest.mark.parametrize("isolation", ["READ COMMITTED", "REPEATABLE READ"])
def test_pre_wait_snapshot_and_cached_state_do_not_admit(
    target: Target, reservation_case: ReservationCase, isolation: str
) -> None:
    """PG05: a real exclusive waiter defeats stale reads; RR is refused."""
    admission = reservation_case.fresh(target.owner)
    before = owner_rows(target)
    preloaded, attempt = threading.Event(), threading.Event()
    closed, release = threading.Event(), threading.Event()
    worker_pid: list[int] = []

    def worker() -> tuple[str, str, str]:
        with target.runtime.connect().execution_options(isolation_level=isolation) as connection:
            with Session(bind=connection) as session, session.begin():
                session.execute(
                    text("SELECT set_config('app.owner_id',:owner,true)"),
                    {"owner": str(target.owner)},
                )
                cached_owner = session.get(OwnerState, target.owner)
                assert cached_owner is not None and cached_owner.status == "active"
                cached_control = (
                    session.execute(text("SELECT * FROM recovery.control")).mappings().one()
                )
                assert cached_control["state"] == "OPEN"
                worker_pid.append(session.scalar(text("SELECT pg_backend_pid()")))
                preloaded.set()
                assert attempt.wait(10)
                try:
                    reserve(session, target.owner, reservation_case.operation, admission, uuid4())
                except RecoveryDenied as error:
                    code = error.code
                except HTTPException as error:
                    assert error.status_code == 503
                    code = error.detail["code"]
                else:
                    pytest.fail("Stale pre-wait state admitted a reservation")
                return (
                    code,
                    cached_control["state"],
                    session.scalar(text("SELECT state FROM recovery.control")),
                )

    def close() -> None:
        with Session(target.admin) as session, session.begin():
            close_admission(session)
            closed.set()
            assert release.wait(10)

    with ThreadPoolExecutor(2) as pool:
        working = pool.submit(worker)
        assert preloaded.wait(10)
        closer = pool.submit(close)
        try:
            assert closed.wait(10)
            attempt.set()
            if isolation == "READ COMMITTED":
                deadline, waiting = time.monotonic() + 10, False
                while time.monotonic() < deadline:
                    with target.admin.connect() as connection:
                        waiting = connection.scalar(
                            text("""SELECT EXISTS(
                          SELECT 1 FROM pg_locks WHERE pid=:pid
                          AND locktype='advisory' AND mode='ShareLock' AND NOT granted)"""),
                            {"pid": worker_pid[0]},
                        )
                    if waiting:
                        break
                    time.sleep(0.01)
                assert waiting is True and not working.done()
            else:
                # RR keeps its old snapshot, so it must be refused before any
                # shared-lock admission, rather than relying on a fresh read.
                assert working.result(timeout=10) == (
                    "recovery_metadata_unverified",
                    "OPEN",
                    "OPEN",
                )
        finally:
            attempt.set()
            release.set()
        closer.result(timeout=10)
        if isolation == "READ COMMITTED":
            assert working.result(timeout=10) == ("recovery_unavailable", "OPEN", "CLOSED")
    assert owner_rows(target) == before
    with target.admin.connect() as connection:
        assert connection.scalar(text("SELECT state FROM recovery.control")) == "CLOSED"


@pytest.mark.parametrize("deletion", [False, True])
def test_echo_duplicate_and_context_blocked_before_certificate(
    target: Target, reservation_case: ReservationCase, deletion: bool
) -> None:
    """PG10: actual B3 commit remains private across concurrent read/retry paths.

    The capability's public reads conservatively deny installed recovery control;
    there is no authenticated production V2 route or trusted B4/B5 adapter yet.
    Exercise both an initial write and a private erasure epoch transition.
    """
    operation = reservation_case.operation
    if deletion:
        domain = {
            key: value
            for key, value in operation.model_dump(mode="json").items()
            if key
            not in {
                "schema_version",
                "environment_id",
                "origin_incarnation",
                "origin_generation",
            }
        }
        with Session(target.admin) as session, session.begin():
            sync._create(session, target.owner, Operation.model_validate(domain))
        operation = OperationV2.model_validate(
            {
                **operation.model_dump(mode="json"),
                "mutation_id": str(uuid4()),
                "command": "delete_session",
                "payload": {},
                "expected_revision": 1,
            }
        )
    reservation = reserve_case(target, reservation_case, operation=operation)
    reservation_case.authority.prepare(reservation.intent, reservation.prior)
    admission = reservation_case.fresh(target.owner)
    with Session(target.runtime) as session, session.begin():
        marker = recovery_effect.commit_effect(session, target.owner, reservation, admission)
    assert (
        reservation_case.authority.lookup(
            target.owner, operation.mutation_id, reservation.intent.request_digest
        )
        is None
    )
    before = owner_rows(target)
    barrier = threading.Barrier(4)

    def probe(path: str) -> str:
        barrier.wait(timeout=10)
        if path == "duplicate":
            with pytest.raises(RecoveryDenied, match="publication_pending"):
                reserve_case(target, reservation_case, operation=operation)
            return "publication_pending"
        with denied("recovery_metadata_unverified"):
            if path == "pull":
                sync.pull(target.owner, None, 100)
            elif path == "me":
                sync.me(target.owner)
            else:
                initialize_account(target.owner)
        return "recovery_metadata_unverified"

    with ThreadPoolExecutor(4) as pool:
        results = list(pool.map(probe, ["pull", "me", "duplicate", "initialize"]))
    assert results == [
        "recovery_metadata_unverified",
        "recovery_metadata_unverified",
        "publication_pending",
        "recovery_metadata_unverified",
    ]
    assert owner_rows(target) == before
    assert before["owner_state"][0]["position"] == marker.private_position == 1
    assert before["owner_state"][0]["erasure_epoch"] == marker.erasure_epoch == int(deletion)
    metadata = before["recovery_owners"][0]
    assert metadata["visible_position"] == metadata["erasure_high_water"] == 0
    assert metadata["hold_attempt"] == str(reservation.intent.attempt)
    assert before["recovery_attempts"][0]["certificate"] is None
    assert before["receipts"][0]["acknowledgement"] == {
        "schema_version": 2,
        "mutation_id": str(operation.mutation_id),
        "aggregate_id": str(operation.aggregate_id),
        "status": "publication_pending",
    }
