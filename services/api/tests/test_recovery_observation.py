"""Known-marker database observation only; no O3 certifier/provider qualification."""

import hashlib
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from dataclasses import replace
from datetime import UTC, datetime, timedelta
from uuid import uuid4

import pytest
from sqlalchemy import create_engine, text
from sqlalchemy.orm import Session

from daily_motion import sync
from daily_motion.contracts import Operation, OperationV2, canonical_json
from daily_motion.models import Change, OwnerState, Snapshot
from daily_motion.recovery import Checkpoint, CommittedMarker, RecoveryDenied
from daily_motion.recovery_db import close_admission
from daily_motion.recovery_effect import commit_effect
from daily_motion.recovery_observation import observe_committed
from tests.test_recovery_effect import domain_copy, effect_case, record_operation
from tests.test_recovery_protocol_v2 import (
    ReservationCase,
    Target,
    denied,
    owner_rows,
    reserve_case,
)
from tests.test_recovery_protocol_v2 import recovery_lab as recovery_lab
from tests.test_recovery_protocol_v2 import reservation_case as reservation_case
from tests.test_recovery_protocol_v2 import target as target


def wait_for_observer_lock(target: Target, tag: str) -> bool:
    deadline = time.monotonic() + 4
    while time.monotonic() < deadline:
        with target.admin.connect() as connection:
            waiting = connection.scalar(
                text(
                    "SELECT EXISTS(SELECT 1 FROM pg_stat_activity "
                    "WHERE application_name=:tag AND wait_event_type='Lock')"
                ),
                {"tag": tag},
            )
        if waiting:
            return True
        time.sleep(0.01)
    return False


def committed(target: Target, case: ReservationCase, kind: str = "create") -> CommittedMarker:
    operation = case.operation
    if kind in {"conflict", "record", "delete"}:
        with Session(target.admin) as session, session.begin():
            workout = sync._create(
                session, target.owner, Operation.model_validate(domain_copy(operation))
            )
            if kind == "delete":
                state = session.get(OwnerState, target.owner)
                assert state is not None
                state.position = 1
                session.add(
                    Change(
                        owner_id=target.owner,
                        position=1,
                        session_id=workout.id,
                        created_at=datetime.now(UTC),
                        body={"operation": domain_copy(operation), "revision": 1},
                    )
                )
                session.execute(
                    text(
                        "UPDATE training.recovery_owners SET visible_position=1 "
                        "WHERE owner_id=:owner"
                    ),
                    {"owner": target.owner},
                )
    if kind == "record":
        operation = record_operation(case)
    elif kind in {"rejected", "delete"}:
        operation = OperationV2.model_validate(
            {
                **operation.model_dump(mode="json"),
                "command": "delete_session" if kind == "delete" else "complete_session",
                "expected_revision": 1 if kind == "delete" else 0,
                "payload": {},
            }
        )
    reservation = reserve_case(target, case, operation=operation)
    case.authority.prepare(reservation.intent, reservation.prior)
    return effect_case(target, case, reservation)


@pytest.mark.parametrize("kind", ["create", "record", "conflict", "rejected", "delete"])
def test_observation_reads_committed_result_without_publishing_or_changing_rows(
    target: Target, reservation_case: ReservationCase, kind: str
) -> None:
    marker = committed(target, reservation_case, kind)
    before = owner_rows(target)
    for _ in range(2):
        admission = reservation_case.fresh(target.owner)
        assert observe_committed(target.runtime, target.owner, marker, admission) == marker
        assert owner_rows(target) == before
    assert (
        reservation_case.authority.lookup(
            target.owner, marker.intent.mutation, marker.intent.request_digest
        )
        is None
    )
    assert before["recovery_owners"][0]["hold_attempt"] == str(marker.intent.attempt)
    assert before["recovery_attempts"][0]["certificate"] is None
    assert before["receipts"][0]["acknowledgement"]["status"] == "publication_pending"
    assert "payload" not in canonical_json(marker.metadata())
    for action in (
        lambda: sync.me(target.owner),
        lambda: sync.pull(target.owner, None, 100),
        lambda: sync.bootstrap(target.owner),
    ):
        with denied("recovery_metadata_unverified"):
            action()


@pytest.mark.parametrize(
    "fault",
    [
        "hold",
        "anchor",
        "generation",
        "position",
        "visible",
        "minimum_position",
        "epoch",
        "high_water",
        "unresolved",
        "certificate",
        "receipt_missing",
        "receipt_digest",
        "receipt_result",
        "receipt_schema",
        "feed_missing",
        "feed_body",
        "workout_revision",
        "account_deleting",
        "retired_account",
        "control_closed",
        "control_missing",
        "manifest",
        "serial",
    ],
)
def test_observation_denies_incomplete_or_divergent_primary_state_without_repair(
    target: Target, reservation_case: ReservationCase, fault: str
) -> None:
    marker = committed(target, reservation_case)
    admission = reservation_case.fresh(target.owner)
    statements = {
        "hold": "UPDATE training.recovery_owners SET hold_attempt=NULL WHERE owner_id=:owner",
        "anchor": (
            "UPDATE training.recovery_owners SET evidence_digest=repeat('a',64) "
            "WHERE owner_id=:owner"
        ),
        "generation": "UPDATE training.owner_state SET generation=:other WHERE owner_id=:owner",
        "position": "UPDATE training.owner_state SET position=position+1 WHERE owner_id=:owner",
        "visible": "UPDATE training.recovery_owners SET visible_position=1 WHERE owner_id=:owner",
        "minimum_position": (
            "UPDATE training.owner_state SET minimum_position=1 WHERE owner_id=:owner"
        ),
        "epoch": "UPDATE training.owner_state SET erasure_epoch=1 WHERE owner_id=:owner",
        "high_water": (
            "UPDATE training.recovery_owners SET erasure_high_water=1 WHERE owner_id=:owner"
        ),
        "unresolved": (
            "UPDATE training.recovery_attempts SET state='UNRESOLVED' WHERE owner_id=:owner"
        ),
        "certificate": (
            "UPDATE training.recovery_attempts SET certificate='{}' WHERE owner_id=:owner"
        ),
        "receipt_missing": "DELETE FROM training.receipts WHERE owner_id=:owner",
        "receipt_digest": (
            "UPDATE training.receipts SET digest=repeat('a',64) WHERE owner_id=:owner"
        ),
        "receipt_result": "UPDATE training.receipts SET acknowledgement='{}' WHERE owner_id=:owner",
        "receipt_schema": (
            "UPDATE training.receipts SET acknowledgement="
            "jsonb_set(acknowledgement,'{schema_version}','2.0') WHERE owner_id=:owner"
        ),
        "feed_missing": "DELETE FROM training.changes WHERE owner_id=:owner",
        "feed_body": "UPDATE training.changes SET body='{}' WHERE owner_id=:owner",
        "workout_revision": (
            "UPDATE training.workouts SET revision=revision+1 WHERE owner_id=:owner"
        ),
        "account_deleting": (
            "UPDATE training.owner_state SET status='deleting' WHERE owner_id=:owner"
        ),
        "retired_account": (
            "INSERT INTO training.account_retirements(owner_id,retired_at) VALUES(:owner,now())"
        ),
        "control_closed": "UPDATE recovery.control SET state='CLOSED'",
        "control_missing": "DELETE FROM recovery.control",
        "manifest": "UPDATE recovery.control SET manifest_digest=repeat('c',64)",
        "serial": "UPDATE recovery.control SET activation_serial=activation_serial+1",
    }
    with target.admin.begin() as connection:
        connection.execute(text(statements[fault]), {"owner": target.owner, "other": uuid4()})
    before = owner_rows(target)
    with pytest.raises(RecoveryDenied):
        observe_committed(target.runtime, target.owner, marker, admission)
    assert owner_rows(target) == before


@pytest.mark.parametrize("fault", ["nonce", "owner", "target", "serial", "checkpoint"])
def test_observation_requires_original_owner_target_and_fresh_bound_head(
    target: Target, reservation_case: ReservationCase, fault: str
) -> None:
    marker = committed(target, reservation_case)
    admission = reservation_case.fresh(target.owner)
    if fault == "nonce":
        admission = replace(admission, nonce=uuid4())
    elif fault == "owner":
        admission = reservation_case.fresh(reservation_case.other_owner)
    elif fault == "target":
        admission = replace(admission, verified_target_digest="c" * 64)
    elif fault == "serial":
        admission = replace(admission, observed_serial=admission.observed_serial + 1)
    else:
        admission = replace(
            admission, assertion=replace(admission.assertion, checkpoint=Checkpoint())
        )
    before = owner_rows(target)
    with pytest.raises(RecoveryDenied):
        observe_committed(target.runtime, target.owner, marker, admission)
    with pytest.raises(RecoveryDenied):
        observe_committed(target.runtime, reservation_case.other_owner, marker, admission)
    assert owner_rows(target) == before


@pytest.mark.parametrize("fault", ["digest", "position", "epoch", "affected"])
def test_observation_does_not_treat_a_caller_constructed_marker_as_commit_proof(
    target: Target, reservation_case: ReservationCase, fault: str
) -> None:
    marker = committed(target, reservation_case)
    if fault == "digest":
        candidate = replace(marker, marker_digest="a" * 64)
    elif fault == "position":
        candidate = replace(marker, private_position=marker.private_position + 1)
    elif fault == "epoch":
        candidate = replace(marker, erasure_epoch=marker.erasure_epoch + 1)
    else:
        candidate = replace(marker, affected_ids=(marker.intent.root,))
    if fault != "digest":
        binding = candidate.metadata()
        del binding["marker_digest"]
        candidate = replace(
            candidate,
            marker_digest=hashlib.sha256(
                canonical_json({"kind": "EFFECT_COMMITTED", **binding}).encode()
            ).hexdigest(),
        )
    before = owner_rows(target)
    with pytest.raises(RecoveryDenied):
        observe_committed(
            target.runtime, target.owner, candidate, reservation_case.fresh(target.owner)
        )
    assert owner_rows(target) == before


@pytest.mark.parametrize(
    "fault", ["retirement", "historical_feed", "historical_feed_shape", "snapshot"]
)
def test_observation_requires_complete_deletion_suppression_before_returning_metadata(
    target: Target, reservation_case: ReservationCase, fault: str
) -> None:
    marker = committed(target, reservation_case, "delete")
    with Session(target.admin) as session, session.begin():
        if fault == "retirement":
            session.execute(
                text("DELETE FROM training.retired_ids WHERE owner_id=:owner AND id=:root"),
                {"owner": target.owner, "root": marker.intent.root},
            )
        elif fault in {"historical_feed", "historical_feed_shape"}:
            session.execute(
                text(
                    "UPDATE training.changes SET body=CAST(:body AS jsonb) "
                    "WHERE owner_id=:owner AND position=1"
                ),
                {"owner": target.owner, "body": "[]" if fault == "historical_feed_shape" else "{}"},
            )
        else:
            session.add(
                Snapshot(
                    owner_id=target.owner,
                    id=uuid4(),
                    generation=marker.intent.origin.generation,
                    erasure_epoch=0,
                    position=1,
                    installation_id=uuid4(),
                    expires_at=datetime.now(UTC) + timedelta(days=1),
                    pages=[{"roots": ["private archived workout"]}],
                )
            )
    before = owner_rows(target)
    with pytest.raises(RecoveryDenied):
        observe_committed(
            target.runtime, target.owner, marker, reservation_case.fresh(target.owner)
        )
    assert owner_rows(target) == before


def test_observation_closes_transaction_and_releases_fence_before_return(
    target: Target, reservation_case: ReservationCase
) -> None:
    marker = committed(target, reservation_case)
    assert observe_committed(
        target.runtime, target.owner, marker, reservation_case.fresh(target.owner)
    )
    with Session(target.admin) as session, session.begin():
        session.execute(text("SET LOCAL statement_timeout = '1s'"))
        close_admission(session)
    with pytest.raises(RecoveryDenied, match="recovery_unavailable"):
        observe_committed(
            target.runtime, target.owner, marker, reservation_case.fresh(target.owner)
        )


def test_observation_rejects_admin_repeatable_read_and_borrowed_transactions(
    target: Target, reservation_case: ReservationCase
) -> None:
    marker = committed(target, reservation_case)
    admission = reservation_case.fresh(target.owner)
    before = owner_rows(target)
    with denied("service_not_configured"):
        observe_committed(target.admin, target.owner, marker, admission)
    with denied("recovery_metadata_unverified"):
        observe_committed(
            target.runtime.execution_options(isolation_level="REPEATABLE READ"),
            target.owner,
            marker,
            admission,
        )
    with target.runtime.connect() as connection, connection.begin():
        with pytest.raises(RecoveryDenied):
            observe_committed(connection, target.owner, marker, admission)
    assert owner_rows(target) == before


@pytest.mark.parametrize("commit", [False, True])
def test_observation_waits_for_actual_commit_and_never_certifies_rolled_back_marker(
    target: Target, reservation_case: ReservationCase, commit: bool
) -> None:
    reservation = reserve_case(target, reservation_case)
    reservation_case.authority.prepare(reservation.intent, reservation.prior)
    effect_admission = reservation_case.fresh(target.owner)
    observe_admission = reservation_case.fresh(target.owner)
    tag = "dm_observe_" + uuid4().hex
    observer = create_engine(
        target.runtime.url, connect_args={"application_name": tag}, hide_parameters=True
    )
    started = threading.Event()
    before = owner_rows(target)
    try:
        with Session(target.runtime) as session, ThreadPoolExecutor(1) as pool:
            transaction = session.begin()
            marker = commit_effect(session, target.owner, reservation, effect_admission)

            def read() -> CommittedMarker:
                started.set()
                return observe_committed(observer, target.owner, marker, observe_admission)

            future = pool.submit(read)
            try:
                assert started.wait(5)
                assert wait_for_observer_lock(target, tag) and not future.done()
                if commit:
                    transaction.commit()
                else:
                    transaction.rollback()
            finally:
                if transaction.is_active:
                    transaction.rollback()
            if commit:
                assert future.result(timeout=5) == marker
            else:
                with pytest.raises(RecoveryDenied):
                    future.result(timeout=5)
                assert owner_rows(target) == before
    finally:
        observer.dispose()


def test_observation_waiting_behind_exclusive_close_reads_fresh_closed_control(
    target: Target, reservation_case: ReservationCase
) -> None:
    marker = committed(target, reservation_case)
    admission = reservation_case.fresh(target.owner)
    before = owner_rows(target)
    tag = "dm_observe_" + uuid4().hex
    observer = create_engine(
        target.runtime.url, connect_args={"application_name": tag}, hide_parameters=True
    )
    try:
        with Session(target.admin) as session, ThreadPoolExecutor(1) as pool:
            transaction = session.begin()
            close_admission(session)
            future = pool.submit(observe_committed, observer, target.owner, marker, admission)
            try:
                assert wait_for_observer_lock(target, tag) and not future.done()
                transaction.commit()
            finally:
                if transaction.is_active:
                    transaction.rollback()
            with pytest.raises(RecoveryDenied, match="recovery_unavailable"):
                future.result(timeout=5)
        assert owner_rows(target) == before
    finally:
        observer.dispose()
