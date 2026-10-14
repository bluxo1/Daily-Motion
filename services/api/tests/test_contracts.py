import hashlib
import json
from copy import deepcopy
from pathlib import Path
from typing import Any

import pytest
from pydantic import ValidationError

from daily_motion.contracts import Effort, Operation, PushRequest, RecordSet, canonical_json
from daily_motion.main import app


def test_shared_creation_fixture(create_body: dict[str, Any]) -> None:
    assert Operation.model_validate(create_body).expected_revision == 0
    checksum = Path(__file__).parents[3] / "contracts/fixtures/workout.sha256"
    assert (
        hashlib.sha256(canonical_json(create_body).encode()).hexdigest()
        == checksum.read_text().strip()
    )


def test_openapi_snapshot_matches_runtime() -> None:
    import json

    contract = Path(__file__).parents[3] / "contracts/openapi.json"
    assert json.loads(contract.read_text(encoding="utf-8")) == app.openapi()


def test_unicode_contract_text_uses_code_points() -> None:
    path = Path(__file__).parents[3] / "contracts/fixtures/unicode_workout.json"
    op = Operation.model_validate(json.loads(path.read_text(encoding="utf-8")))
    assert len(op.payload["name"]) == 80


@pytest.mark.parametrize("reason", ["   ", "\ufeff", "\u001c", "\u0085"])
def test_blank_correction_reason_is_rejected(create_body: dict[str, Any], reason: str) -> None:
    with pytest.raises(ValidationError):
        RecordSet.model_validate(
            {
                "session_exercise_id": create_body["payload"]["exercises"][0][
                    "session_exercise_id"
                ],
                "set_id": create_body["payload"]["exercises"][0]["sets"][0]["set_id"],
                "execution_status": "skipped",
                "actual": None,
                "completion_seq": 1,
                "correction_reason": reason,
            }
        )


@pytest.mark.parametrize("scale,value", [("rir", "0"), ("rir", "10"), ("rpe", "1"), ("rpe", "8.5")])
def test_effort_bounds(scale: str, value: str) -> None:
    assert Effort.model_validate({"scale": scale, "value": value}).value == value


@pytest.mark.parametrize(
    "scale,value",
    [("rir", "0.5"), ("rir", "11"), ("rpe", "0"), ("rpe", "7.2"), ("rpe", "NaN"), ("rir", "-1")],
)
def test_invalid_effort(scale: str, value: str) -> None:
    with pytest.raises(ValidationError):
        Effort.model_validate({"scale": scale, "value": value})


def test_rejects_owner_and_duplicate_root(create_body: dict[str, Any]) -> None:
    invalid = deepcopy(create_body)
    invalid["owner_id"] = "attacker-chosen-owner"
    with pytest.raises(ValidationError):
        Operation.model_validate(invalid)
    with pytest.raises(ValidationError):
        PushRequest.model_validate({"schema_version": 1, "operations": [create_body, create_body]})


@pytest.mark.parametrize(
    "stamp", ["2026-10-12", "2026-10-12T13:00:00", "2026-10-12T13:00:00+05:30"]
)
def test_requires_utc_instant(create_body: dict[str, Any], stamp: str) -> None:
    create_body["recorded_at"] = stamp
    with pytest.raises(ValidationError):
        Operation.model_validate(create_body)


def test_zero_reps_requires_explicit_attempt() -> None:
    payload = {
        "session_exercise_id": "10000000-0000-4000-8000-000000000004",
        "set_id": "10000000-0000-4000-8000-000000000006",
        "execution_status": "failed",
        "actual": {
            "load": {"value": "0", "unit": "kg", "basis": "total_external"},
            "reps": 0,
            "rep_convention": "bilateral",
            "effort": None,
        },
        "completion_seq": 1,
    }
    RecordSet.model_validate(payload)
    payload["execution_status"] = "completed"
    with pytest.raises(ValidationError):
        RecordSet.model_validate(payload)
