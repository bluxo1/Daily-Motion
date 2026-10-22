"""DRP/2 command definitions only; no enabled admission/provider qualification."""

import hashlib
import json
from copy import deepcopy
from pathlib import Path
from typing import Any
from uuid import UUID

import pytest
from pydantic import ValidationError

from daily_motion import contracts
from daily_motion.contracts import Operation, OperationV2, PushRequestV2, canonical_json

ROOT = Path(__file__).parents[3]


def fixture() -> dict[str, Any]:
    return json.loads((ROOT / "contracts/fixtures/recovery_v2_workout.json").read_text("utf-8"))  # type: ignore[no-any-return]


def test_v2_fixture_binds_full_origin_without_changing_original_body() -> None:
    body = fixture()
    original = deepcopy(body)
    operation = OperationV2.model_validate(body)
    assert operation.schema_version == 2
    encoded = canonical_json(operation.model_dump(mode="json"))
    expected = (ROOT / "contracts/fixtures/recovery_v2_workout.sha256").read_text().strip()
    assert hashlib.sha256(encoded.encode()).hexdigest() == expected
    assert body == original
    for field in ("environment_id", "origin_incarnation", "origin_generation"):
        changed = {**body, field: str(UUID(int=999))}
        changed_body = OperationV2.model_validate(changed).model_dump(mode="json")
        assert hashlib.sha256(canonical_json(changed_body).encode()).hexdigest() != expected


@pytest.mark.parametrize(
    "field",
    [
        "schema_version",
        "environment_id",
        "origin_incarnation",
        "origin_generation",
    ],
)
def test_missing_lineage_is_never_filled_from_current_context(field: str) -> None:
    body = fixture()
    del body[field]
    with pytest.raises(ValidationError):
        OperationV2.model_validate(body)


def test_v1_v2_mixed_or_falsely_versioned_commands_cannot_cross_contracts() -> None:
    body = fixture()
    with pytest.raises(ValidationError):
        Operation.model_validate(body)
    legacy = {
        key: value
        for key, value in body.items()
        if key
        not in {
            "schema_version",
            "environment_id",
            "origin_incarnation",
            "origin_generation",
        }
    }
    Operation.model_validate(legacy)
    with pytest.raises(ValidationError):
        PushRequestV2.model_validate({"schema_version": 2, "operations": [legacy]})
    with pytest.raises(ValidationError):
        PushRequestV2.model_validate({"schema_version": 1, "operations": [body]})
    with pytest.raises(ValidationError):
        OperationV2.model_validate({**body, "owner_id": str(UUID(int=99))})
    with pytest.raises(ValidationError):
        PushRequestV2.model_validate({"schema_version": 2, "operations": [body, body]})


def test_provenance_and_utf8_are_included_in_command_and_batch_bounds(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    body = fixture()
    size = len(canonical_json(body).encode())
    monkeypatch.setattr(contracts, "COMMAND_LIMIT", size)
    OperationV2.model_validate(body)
    monkeypatch.setattr(contracts, "COMMAND_LIMIT", size - 1)
    with pytest.raises(ValidationError, match="256 KiB"):
        OperationV2.model_validate(body)
    monkeypatch.setattr(contracts, "COMMAND_LIMIT", size)
    batch = {"schema_version": 2, "operations": [body]}
    batch_size = len(canonical_json(batch).encode())
    monkeypatch.setattr(contracts, "BATCH_LIMIT", batch_size)
    PushRequestV2.model_validate(batch)
    monkeypatch.setattr(contracts, "BATCH_LIMIT", batch_size - 1)
    with pytest.raises(ValidationError, match="1 MiB"):
        PushRequestV2.model_validate(batch)


@pytest.mark.parametrize(
    "field",
    [
        "mutation_id",
        "installation_id",
        "aggregate_id",
        "environment_id",
        "origin_incarnation",
        "origin_generation",
    ],
)
@pytest.mark.parametrize("spelling", ["uppercase", "braced", "compact"])
def test_v2_cannot_normalize_uuid_spelling_before_binding_frozen_digest(
    field: str, spelling: str
) -> None:
    body = fixture()
    if spelling == "uppercase":
        body[field] = "ABCDEF00-0000-4000-8000-000000000001"
    elif spelling == "braced":
        body[field] = "{" + body[field] + "}"
    else:
        body[field] = body[field].replace("-", "")
    with pytest.raises(ValidationError, match="canonical lowercase UUID"):
        OperationV2.model_validate(body)


@pytest.mark.parametrize("version", [2.0, "2", True])
def test_v2_cannot_coerce_command_or_batch_version_before_digest(version: object) -> None:
    body = fixture()
    with pytest.raises(ValidationError):
        OperationV2.model_validate({**body, "schema_version": version})
    with pytest.raises(ValidationError):
        PushRequestV2.model_validate({"schema_version": version, "operations": [body]})


@pytest.mark.parametrize("revision", [-1, True, 2.0, 9223372036854775808])
def test_v2_revision_matches_the_clients_checked_integer_range(revision: object) -> None:
    body = {
        **fixture(),
        "command": "complete_session",
        "payload": {},
        "expected_revision": revision,
    }
    with pytest.raises(ValidationError):
        OperationV2.model_validate(body)
    body["expected_revision"] = 9223372036854775807
    assert OperationV2.model_validate(body).expected_revision == 9223372036854775807
