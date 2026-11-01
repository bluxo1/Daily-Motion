"""Shared boundaries must agree with the actual mobile RoutinePlan reader."""

import hashlib
import json
from copy import deepcopy
from pathlib import Path
from typing import Any

import pytest
from pydantic import ValidationError

from daily_motion.contracts import canonical_json
from daily_motion.routine_contracts import RoutineOperation
from tests.test_routines import routine_command

ROOT = Path(__file__).parents[3]
SPEC = json.loads((ROOT / "contracts/fixtures/routine_capacity_edge.json").read_text())


@pytest.mark.parametrize(
    "field",
    [
        "session_exercise_id",
        "variant_id",
        "set_id",
        "aggregate_id",
        "template_id",
        "predecessor_template_id",
    ],
)
@pytest.mark.parametrize("identity", SPEC["invalid_planning_uuids"])
def test_routine_rejects_planning_ids_the_native_reader_cannot_use(
    create_body: dict[str, Any], field: str, identity: str
) -> None:
    operation = routine_command(create_body).model_dump(mode="json")
    if field == "aggregate_id":
        operation[field] = identity
    elif field in ("template_id", "predecessor_template_id"):
        operation["payload"][field] = identity
        if field == "predecessor_template_id":
            operation.update(command="publish_template", expected_revision=1)
    else:
        exercise = operation["payload"]["prescription"]["exercises"][0]
        (exercise["sets"][0] if field == "set_id" else exercise)[field] = identity
    with pytest.raises(ValidationError):
        RoutineOperation.model_validate(operation)


@pytest.mark.parametrize(
    "field",
    [
        "session_exercise_id",
        "variant_id",
        "set_id",
        "aggregate_id",
        "template_id",
        "predecessor_template_id",
    ],
)
@pytest.mark.parametrize("identity", SPEC["valid_planning_uuids"])
def test_routine_preserves_native_planning_uuid_boundary(
    create_body: dict[str, Any], field: str, identity: str
) -> None:
    operation = routine_command(create_body).model_dump(mode="json")
    if field == "aggregate_id":
        operation[field] = identity
    elif field in ("template_id", "predecessor_template_id"):
        operation["payload"][field] = identity
        if field == "predecessor_template_id":
            operation.update(command="publish_template", expected_revision=1)
    else:
        exercise = operation["payload"]["prescription"]["exercises"][0]
        (exercise["sets"][0] if field == "set_id" else exercise)[field] = identity
    RoutineOperation.model_validate(operation)


def capacity_operation() -> dict[str, Any]:
    original = json.loads((ROOT / "contracts/fixtures/workout.json").read_text())
    prototype = original["payload"]["exercises"][0]
    counter = 0

    def identity() -> str:
        nonlocal counter
        counter += 1
        return f"10000000-0000-4000-8000-{counter:012x}"

    exercises = []
    for index, count in enumerate(SPEC["sets_per_exercise"]):
        exercise = deepcopy(prototype)
        exercise["session_exercise_id"] = identity()
        exercise["name"] = SPEC["exercise_names"][index]
        exercise["sets"] = [
            dict(deepcopy(prototype["sets"][0]), set_id=identity()) for _ in range(count)
        ]
        exercises.append(exercise)
    return {
        **{
            key: original[key]
            for key in (
                "mutation_id",
                "installation_id",
                "aggregate_id",
                "occurred_at",
                "recorded_at",
            )
        },
        "aggregate_type": "routine",
        "expected_revision": 0,
        "command": "create_routine",
        "payload": {
            "template_id": "60000000-0000-4000-8000-000000000001",
            "predecessor_template_id": None,
            "prescription": {
                "name": SPEC["routine_name"],
                "timezone": original["payload"]["timezone"],
                "exercises": exercises,
            },
        },
    }


def test_routine_command_reserves_capacity_for_actual_mobile_start() -> None:
    operation = capacity_operation()
    frozen = canonical_json(operation).encode()
    assert len(frozen) == SPEC["canonical_operation_bytes"]
    assert hashlib.sha256(frozen).hexdigest() == SPEC["canonical_operation_sha256"]
    with pytest.raises(ValidationError):
        RoutineOperation.model_validate(operation)


def test_routine_below_reserved_capacity_is_accepted() -> None:
    operation = capacity_operation()
    sets = operation["payload"]["prescription"]["exercises"][0]["sets"]
    del sets[-SPEC["pruned_sets"] :]
    RoutineOperation.model_validate(operation)


@pytest.mark.parametrize("field", ["routine", "exercise"])
@pytest.mark.parametrize("name", SPEC["blank_names"])
def test_routine_rejects_names_blank_in_native_dart(
    create_body: dict[str, Any], field: str, name: str
) -> None:
    operation = routine_command(create_body).model_dump(mode="json")
    plan = operation["payload"]["prescription"]
    (plan if field == "routine" else plan["exercises"][0])["name"] = name
    with pytest.raises(ValidationError):
        RoutineOperation.model_validate(operation)


@pytest.mark.parametrize("field", ["routine", "exercise"])
@pytest.mark.parametrize("name", SPEC["nonblank_names"])
def test_routine_preserves_names_nonblank_in_native_dart(
    create_body: dict[str, Any], field: str, name: str
) -> None:
    operation = routine_command(create_body).model_dump(mode="json")
    plan = operation["payload"]["prescription"]
    (plan if field == "routine" else plan["exercises"][0])["name"] = name
    assert RoutineOperation.model_validate(operation).payload == operation["payload"]


@pytest.mark.parametrize("field", ["set_class", "set_purpose", "rest_seconds"])
def test_routine_needs_explicit_client_required_prescription_fields(
    create_body: dict[str, Any], field: str
) -> None:
    operation = routine_command(create_body).model_dump(mode="json")
    item = operation["payload"]["prescription"]["exercises"][0]["sets"][0]
    (item["planned"] if field == "rest_seconds" else item).pop(field)
    with pytest.raises(ValidationError):
        RoutineOperation.model_validate(operation)


@pytest.mark.parametrize("field", ["side", "reps", "load"])
def test_routine_keeps_optional_omissions_without_fabricating_defaults(
    create_body: dict[str, Any], field: str
) -> None:
    operation = routine_command(create_body).model_dump(mode="json")
    exercise = operation["payload"]["prescription"]["exercises"][0]
    (exercise if field == "side" else exercise["sets"][0]["planned"]).pop(field, None)
    assert RoutineOperation.model_validate(operation).payload == operation["payload"]
