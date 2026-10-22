"""B3 PostgreSQL components; no B4/B5 or complete PG/RC qualification claim."""

import threading
from concurrent.futures import ThreadPoolExecutor
from datetime import UTC, datetime, timedelta
from typing import Any
from uuid import UUID, uuid4

import pytest
from sqlalchemy import text
from sqlalchemy.exc import DBAPIError
from sqlalchemy.orm import Session

from daily_motion import sync
from daily_motion.accounts import initialize_account
from daily_motion.contracts import Operation, OperationV2
from daily_motion.models import Change, OwnerState, RetiredId, Snapshot
from daily_motion.recovery import MAX_COUNTER, CommittedMarker, OutcomeStatus, RecoveryDenied
from daily_motion.recovery_admission import Admission, Reservation
from daily_motion.recovery_db import close_admission
from daily_motion.recovery_effect import commit_effect
from tests.test_recovery_protocol_v2 import (
    ReservationCase,
    Target,
    denied,
    owner_rows,
    reserve_case,
)
from tests.test_recovery_protocol_v2 import (
    recovery_lab as recovery_lab,
)
from tests.test_recovery_protocol_v2 import (
    reservation_case as reservation_case,
)
from tests.test_recovery_protocol_v2 import (
    target as target,
)


def effect_case(
    target: Target,
    case: ReservationCase,
    reservation: Reservation,
    admission: Admission | None = None,
) -> CommittedMarker:
    admission = admission or case.fresh(target.owner)
    with Session(target.runtime) as session, session.begin():
        return commit_effect(session, target.owner, reservation, admission)


def assert_private_outcome(
    target: Target, reservation: Reservation, marker: CommittedMarker, visible: int = 0
) -> None:
    rows = owner_rows(target)
    attempt, metadata = rows["recovery_attempts"][0], rows["recovery_owners"][0]
    assert attempt["state"] == "EFFECT_COMMITTED"
    assert attempt["result"] == marker.outcome.result(marker.intent)
    assert attempt["committed_marker"] == marker.metadata()
    assert attempt["certificate"] is None
    assert attempt["frozen_request"] == reservation.storage()
    assert metadata["hold_attempt"] == str(reservation.intent.attempt)
    assert metadata["evidence_order"] == reservation.prepared_checkpoint.order
    assert metadata["evidence_digest"] == reservation.prepared_checkpoint.digest
    assert metadata["visible_position"] == visible
    receipt = rows["receipts"][0]
    assert receipt["digest"] == reservation.intent.request_digest
    assert receipt["acknowledgement"]["status"] == "publication_pending"
    assert "accepted_revision" not in receipt["acknowledgement"]


def test_effect_requires_existing_preparation_and_stores_one_private_outcome(
    target: Target, reservation_case: ReservationCase
) -> None:
    reservation = reserve_case(target, reservation_case)
    before = owner_rows(target)
    with pytest.raises(RecoveryDenied):
        effect_case(target, reservation_case, reservation)
    assert owner_rows(target) == before
    reservation_case.authority.prepare(reservation.intent, reservation.prior)
    marker = effect_case(target, reservation_case, reservation)
    assert marker.outcome.status == OutcomeStatus.ACCEPTED
    assert marker.outcome.accepted_revision == 1
    assert marker.private_position == 1
    assert marker.intent == reservation.intent
    expected_ids = {reservation_case.operation.aggregate_id}
    for exercise in reservation_case.operation.payload["exercises"]:
        expected_ids.add(UUID(exercise["session_exercise_id"]))
        expected_ids.update(UUID(item["set_id"]) for item in exercise["sets"])
    assert set(marker.affected_ids) == expected_ids
    assert_private_outcome(target, reservation, marker)
    assert (
        reservation_case.authority.lookup(
            target.owner, marker.intent.mutation, marker.intent.request_digest
        )
        is None
    )
    after = owner_rows(target)
    with pytest.raises(RecoveryDenied, match="publication_pending"):
        effect_case(target, reservation_case, reservation)
    assert owner_rows(target) == after
    for action in (
        lambda: sync.me(target.owner),
        lambda: sync.pull(target.owner, None, 100),
        lambda: sync.bootstrap(target.owner),
        lambda: initialize_account(target.owner),
    ):
        with denied("recovery_metadata_unverified"):
            action()


def test_effect_never_recreates_a_missing_primary_reservation(
    target: Target, reservation_case: ReservationCase
) -> None:
    reservation = reserve_case(target, reservation_case)
    with target.admin.begin() as connection:
        connection.execute(
            text("UPDATE training.recovery_owners SET hold_attempt=NULL WHERE owner_id=:owner"),
            {"owner": target.owner},
        )
        connection.execute(
            text("DELETE FROM training.recovery_attempts WHERE owner_id=:owner"),
            {"owner": target.owner},
        )
    before = owner_rows(target)
    with pytest.raises(RecoveryDenied):
        effect_case(target, reservation_case, reservation)
    assert owner_rows(target) == before
    reservation_case.authority.prepare(reservation.intent, reservation.prior)
    with pytest.raises(RecoveryDenied):
        effect_case(target, reservation_case, reservation)
    assert owner_rows(target) == before


@pytest.mark.parametrize("fault", ["marker", "anchor"])
def test_effect_write_failure_rolls_back_domain_receipt_feed_marker_and_anchor(
    target: Target, reservation_case: ReservationCase, fault: str
) -> None:
    reservation = reserve_case(target, reservation_case)
    reservation_case.authority.prepare(reservation.intent, reservation.prior)
    before = owner_rows(target)
    table, column = (
        ("recovery_attempts", "state")
        if fault == "marker"
        else ("recovery_owners", "evidence_order")
    )
    with target.admin.begin() as connection:
        connection.execute(
            text(f"""CREATE FUNCTION recovery.test_fail_effect() RETURNS trigger
          LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'synthetic effect fault'; END $$;
          CREATE TRIGGER test_fail_effect BEFORE UPDATE OF {column} ON training.{table}
          FOR EACH ROW EXECUTE FUNCTION recovery.test_fail_effect();""")
        )
    try:
        admission = reservation_case.fresh(target.owner)
        with Session(target.runtime) as session, session.begin():
            with pytest.raises(DBAPIError):
                commit_effect(session, target.owner, reservation, admission)
            assert session.scalar(text("SELECT count(*) FROM training.workouts")) == 0
    finally:
        with target.admin.begin() as connection:
            connection.execute(
                text(
                    f"DROP TRIGGER test_fail_effect ON training.{table}; "
                    "DROP FUNCTION recovery.test_fail_effect();"
                )
            )
    assert owner_rows(target) == before
    marker = effect_case(target, reservation_case, reservation)
    assert_private_outcome(target, reservation, marker)


@pytest.mark.parametrize("kind", ["conflict", "empty_session", "not_found", "retired_id"])
def test_effect_conflicts_and_rejections_are_private_deterministic_receipts_without_feed(
    target: Target, reservation_case: ReservationCase, kind: str
) -> None:
    body = reservation_case.operation.model_dump(mode="json")
    if kind in ("conflict", "empty_session"):
        legacy = {
            key: value
            for key, value in body.items()
            if key
            not in {"schema_version", "environment_id", "origin_incarnation", "origin_generation"}
        }
        with Session(target.admin) as session, session.begin():
            sync._create(session, target.owner, Operation.model_validate(legacy))
    if kind in ("empty_session", "not_found"):
        body.update(
            command="complete_session",
            expected_revision=1 if kind == "empty_session" else 0,
            payload={},
        )
    if kind == "retired_id":
        with Session(target.admin) as session, session.begin():
            session.add(
                RetiredId(owner_id=target.owner, id=reservation_case.operation.aggregate_id)
            )
    reservation = reserve_case(target, reservation_case, operation=OperationV2.model_validate(body))
    reservation_case.authority.prepare(reservation.intent, reservation.prior)
    before = owner_rows(target)
    marker = effect_case(target, reservation_case, reservation)
    assert marker.outcome.status == (
        OutcomeStatus.CONFLICT if kind == "conflict" else OutcomeStatus.REJECTED
    )
    assert marker.private_position is None and marker.retired_ids == ()
    assert marker.affected_ids == ()
    assert_private_outcome(target, reservation, marker)
    after = owner_rows(target)
    for table in (
        "workouts",
        "exercises",
        "sets",
        "observations",
        "changes",
        "retired_ids",
        "owner_state",
    ):
        assert after[table] == before[table]
    assert after["recovery_attempts"][0]["result"]["error"]["code"] == (
        "revision_conflict" if kind == "conflict" else kind
    )
    with pytest.raises(RecoveryDenied, match="publication_pending"):
        effect_case(target, reservation_case, reservation)
    assert owner_rows(target) == after


def test_effect_concurrent_retries_and_close_never_double_apply(
    target: Target, reservation_case: ReservationCase
) -> None:
    reservation = reserve_case(target, reservation_case)
    reservation_case.authority.prepare(reservation.intent, reservation.prior)
    barrier = threading.Barrier(2)
    admissions = [reservation_case.fresh(target.owner) for _ in range(2)]

    def attempt(index: int) -> str:
        barrier.wait(timeout=10)
        try:
            effect_case(target, reservation_case, reservation, admissions[index])
            return "committed"
        except RecoveryDenied as error:
            return error.code

    with ThreadPoolExecutor(2) as pool:
        assert sorted(pool.map(attempt, [0, 1])) == ["committed", "publication_pending"]
    after = owner_rows(target)
    assert len(after["workouts"]) == len(after["changes"]) == len(after["receipts"]) == 1
    assert after["owner_state"][0]["position"] == 1
    with Session(target.admin) as session, session.begin():
        close_admission(session)
    with pytest.raises(RecoveryDenied, match="recovery_unavailable"):
        effect_case(target, reservation_case, reservation)
    assert owner_rows(target) == after


def domain_copy(operation: OperationV2) -> dict[str, Any]:
    return {
        key: value
        for key, value in operation.model_dump(mode="json").items()
        if key
        not in {"schema_version", "environment_id", "origin_incarnation", "origin_generation"}
    }


def record_operation(case: ReservationCase) -> OperationV2:
    exercise = case.operation.payload["exercises"][0]
    return OperationV2.model_validate(
        {
            **case.operation.model_dump(mode="json"),
            "mutation_id": str(uuid4()),
            "command": "record_set",
            "expected_revision": 1,
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


def test_effect_records_observation_revision_with_private_feed_and_full_origin(
    target: Target, reservation_case: ReservationCase
) -> None:
    with Session(target.admin) as session, session.begin():
        sync._create(
            session, target.owner, Operation.model_validate(domain_copy(reservation_case.operation))
        )
    operation = record_operation(reservation_case)
    reservation = reserve_case(target, reservation_case, operation=operation)
    reservation_case.authority.prepare(reservation.intent, reservation.prior)
    marker = effect_case(target, reservation_case, reservation)
    assert_private_outcome(target, reservation, marker)
    rows = owner_rows(target)
    assert rows["workouts"][0]["revision"] == 2
    observation = rows["observations"][0]
    assert observation["revision"] == 2 and observation["position"] == 1
    assert observation["generation"] == str(operation.origin_generation)
    assert observation["payload"]["actual"]["reps"] == 5
    assert rows["changes"][0]["body"]["operation"] == operation.model_dump(mode="json")
    assert marker.outcome.accepted_revision == 2
    assert set(marker.affected_ids) == {
        operation.aggregate_id,
        UUID(operation.payload["session_exercise_id"]),
        UUID(operation.payload["set_id"]),
    }


def test_effect_deletion_purges_complete_scope_and_holds_uncertified_epoch(
    target: Target, reservation_case: ReservationCase
) -> None:
    create = domain_copy(reservation_case.operation)
    create["payload"]["name"] = "PRIVATE_PAYLOAD_SENTINEL"
    record = record_operation(reservation_case)
    with Session(target.admin) as session, session.begin():
        state = session.get(OwnerState, target.owner)
        assert state is not None
        workout = sync._create(session, target.owner, Operation.model_validate(create))
        state.position = 1
        session.add(
            Change(
                owner_id=target.owner,
                position=1,
                session_id=workout.id,
                created_at=datetime.now(UTC),
                body={"operation": create, "revision": 1},
            )
        )
        workout, _ = sync.apply_domain_change(
            session, target.owner, Operation.model_validate(domain_copy(record)), state, workout
        )
        state.position = 2
        session.add(
            Change(
                owner_id=target.owner,
                position=2,
                session_id=workout.id,
                created_at=datetime.now(UTC),
                body={"operation": domain_copy(record), "revision": 2},
            )
        )
        session.flush()
        session.add(
            Snapshot(
                owner_id=target.owner,
                id=uuid4(),
                generation=state.generation,
                erasure_epoch=0,
                position=2,
                installation_id=record.installation_id,
                expires_at=datetime.now(UTC) + timedelta(days=1),
                pages=[
                    {"roots": [sync.projection(session, target.owner, workout)], "retired_ids": []}
                ],
            )
        )
        session.execute(
            text("UPDATE training.recovery_owners SET visible_position=2 WHERE owner_id=:owner"),
            {"owner": target.owner},
        )
    deletion = OperationV2.model_validate(
        {
            **reservation_case.operation.model_dump(mode="json"),
            "mutation_id": str(uuid4()),
            "command": "delete_session",
            "payload": {},
            "expected_revision": 2,
        }
    )
    reservation = reserve_case(target, reservation_case, operation=deletion)
    reservation_case.authority.prepare(reservation.intent, reservation.prior)
    marker = effect_case(target, reservation_case, reservation)
    assert_private_outcome(target, reservation, marker, visible=2)
    expected_ids = {
        str(deletion.aggregate_id),
        *(exercise["session_exercise_id"] for exercise in create["payload"]["exercises"]),
        *(
            item["set_id"]
            for exercise in create["payload"]["exercises"]
            for item in exercise["sets"]
        ),
    }
    assert {str(identifier) for identifier in marker.retired_ids} == expected_ids
    assert set(marker.affected_ids) == set(marker.retired_ids)
    rows = owner_rows(target)
    for table in ("workouts", "exercises", "sets", "observations", "snapshots"):
        assert rows[table] == []
    assert {row["id"] for row in rows["retired_ids"]} == expected_ids
    assert len(rows["changes"]) == 3 and all(
        row["body"]["redacted"] is True for row in rows["changes"]
    )
    assert rows["owner_state"][0]["erasure_epoch"] == marker.erasure_epoch == 1
    assert rows["owner_state"][0]["position"] == marker.private_position == 3
    assert rows["recovery_owners"][0]["erasure_high_water"] == 0
    assert "PRIVATE_PAYLOAD_SENTINEL" not in str(rows["changes"]) + str(marker.metadata())
    with pytest.raises(RecoveryDenied, match="publication_pending"):
        reserve_case(target, reservation_case, operation=deletion)
    assert owner_rows(target) == rows


@pytest.mark.parametrize("field", ["revision", "position", "erasure"])
def test_effect_counter_overflow_leaves_prepared_attempt_and_all_old_rows_intact(
    target: Target, reservation_case: ReservationCase, field: str
) -> None:
    with Session(target.admin) as session, session.begin():
        workout = sync._create(
            session, target.owner, Operation.model_validate(domain_copy(reservation_case.operation))
        )
        state = session.get(OwnerState, target.owner)
        assert state is not None
        if field == "revision":
            workout.revision = MAX_COUNTER
        elif field == "position":
            state.position = MAX_COUNTER
            session.execute(
                text(
                    "UPDATE training.recovery_owners SET visible_position=:maximum "
                    "WHERE owner_id=:owner"
                ),
                {"maximum": MAX_COUNTER, "owner": target.owner},
            )
        else:
            state.erasure_epoch = MAX_COUNTER
            session.execute(
                text(
                    "UPDATE training.recovery_owners SET erasure_high_water=:maximum "
                    "WHERE owner_id=:owner"
                ),
                {"maximum": MAX_COUNTER, "owner": target.owner},
            )
    operation = OperationV2.model_validate(
        {
            **reservation_case.operation.model_dump(mode="json"),
            "mutation_id": str(uuid4()),
            "command": "delete_session",
            "payload": {},
            "expected_revision": MAX_COUNTER if field == "revision" else 1,
        }
    )
    reservation = reserve_case(target, reservation_case, operation=operation)
    reservation_case.authority.prepare(reservation.intent, reservation.prior)
    before = owner_rows(target)
    with pytest.raises(RecoveryDenied):
        effect_case(target, reservation_case, reservation)
    assert owner_rows(target) == before


@pytest.mark.parametrize("child", ["exercise", "set"])
def test_effect_cannot_observe_or_mutate_another_owners_nested_identity(
    target: Target, reservation_case: ReservationCase, child: str
) -> None:
    other = domain_copy(reservation_case.operation)
    other["aggregate_id"] = str(uuid4())
    for exercise in other["payload"]["exercises"]:
        exercise["session_exercise_id"] = str(uuid4())
        for item in exercise["sets"]:
            item["set_id"] = str(uuid4())
    with Session(target.admin) as session, session.begin():
        sync._create(
            session, target.owner, Operation.model_validate(domain_copy(reservation_case.operation))
        )
        sync._create(session, reservation_case.other_owner, Operation.model_validate(other))
    other_target = Target(target.admin, target.runtime, reservation_case.other_owner)
    other_before = owner_rows(other_target)
    body = record_operation(reservation_case).model_dump(mode="json")
    key = "session_exercise_id" if child == "exercise" else "set_id"
    body["payload"][key] = (
        other["payload"]["exercises"][0]["session_exercise_id"]
        if child == "exercise"
        else other["payload"]["exercises"][0]["sets"][0]["set_id"]
    )
    reservation = reserve_case(target, reservation_case, operation=OperationV2.model_validate(body))
    reservation_case.authority.prepare(reservation.intent, reservation.prior)
    marker = effect_case(target, reservation_case, reservation)
    assert marker.outcome.status == OutcomeStatus.REJECTED
    assert marker.affected_ids == ()
    assert marker.outcome.result(marker.intent)["error"] == {
        "code": "not_found",
        "retryable": False,
    }
    assert owner_rows(other_target) == other_before
    assert owner_rows(target)["workouts"][0]["revision"] == 1


def test_effect_authenticated_before_close_still_checks_fence_before_domain_write(
    target: Target, reservation_case: ReservationCase
) -> None:
    reservation = reserve_case(target, reservation_case)
    reservation_case.authority.prepare(reservation.intent, reservation.prior)
    admission = reservation_case.fresh(target.owner)
    before = owner_rows(target)
    with Session(target.admin) as session, session.begin():
        close_admission(session)
    with pytest.raises(RecoveryDenied, match="recovery_unavailable"):
        effect_case(target, reservation_case, reservation, admission)
    assert owner_rows(target) == before


@pytest.mark.parametrize("field", ["marker", "result", "digest", "origin", "request", "affected"])
def test_runtime_cannot_rewrite_committed_marker_result_or_original_binding(
    target: Target, reservation_case: ReservationCase, field: str
) -> None:
    reservation = reserve_case(target, reservation_case)
    reservation_case.authority.prepare(reservation.intent, reservation.prior)
    effect_case(target, reservation_case, reservation)
    before = owner_rows(target)
    changes = {
        "marker": "committed_marker='{}'::jsonb",
        "result": "result='{}'::jsonb",
        "digest": "request_digest=repeat('f',64)",
        "origin": "incarnation='00000000-0000-0000-0000-000000000999'::uuid",
        "request": "frozen_request='{}'::jsonb",
        "affected": "committed_marker=jsonb_set(committed_marker,'{affected_ids}','[]'::jsonb)",
    }
    with pytest.raises(DBAPIError, match="binding is immutable"):
        with Session(target.runtime) as session, session.begin():
            session.execute(
                text("SELECT set_config('app.owner_id',:owner,true)"), {"owner": str(target.owner)}
            )
            session.execute(
                text(
                    f"UPDATE training.recovery_attempts SET {changes[field]} WHERE owner_id=:owner"
                ),
                {"owner": target.owner},
            )
    assert owner_rows(target) == before
