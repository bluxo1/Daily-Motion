import hashlib
from datetime import UTC, datetime, timedelta
from typing import Any
from uuid import UUID, uuid4

import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient
from sqlalchemy import select

from daily_motion.auth import verified_owner
from daily_motion.contracts import Operation, canonical_json
from daily_motion.main import app
from daily_motion.models import OwnerState, Snapshot
from daily_motion.sync import (
    accept,
    bootstrap,
    next_transaction,
    prune_feed,
    pull,
    snapshot_page,
    validate_snapshot,
)

from .test_sync import command, record


def test_http_snapshot_checksums_match_serialized_pages(
    owner: UUID, create_body: dict[str, Any]
) -> None:
    accept(owner, Operation.model_validate(create_body))
    accept(owner, record(create_body))
    app.dependency_overrides[verified_owner] = lambda: owner
    try:
        with TestClient(app) as client:
            manifest = client.post(
                "/v1/sync/bootstrap", json={"installation_id": str(uuid4())}
            ).json()
            assert manifest["expires_at"].endswith("Z")
            page = client.get(
                "/v1/sync/bootstrap/pages/0", params={"token": manifest["token"]}
            ).json()
            assert (
                hashlib.sha256(canonical_json(page).encode()).hexdigest()
                == manifest["checksums"][0]
            )
            assert (
                client.get(
                    "/v1/sync/bootstrap/validate", params={"token": manifest["token"]}
                ).status_code
                == 200
            )
    finally:
        app.dependency_overrides.clear()


def test_retirement_survives_feed_pruning(owner: UUID, create_body: dict[str, Any]) -> None:
    accept(owner, Operation.model_validate(create_body))
    old_cursor = pull(owner, None, 1)["next_cursor"]
    accept(owner, command(create_body, "delete_session", 1))
    prune_feed(owner, datetime.now(UTC) + timedelta(seconds=1))
    with pytest.raises(HTTPException):
        pull(owner, old_cursor, 100)
    manifest = bootstrap(owner)
    page = snapshot_page(owner, manifest["token"], 0)
    assert create_body["aggregate_id"] in page["retired_ids"]
    assert page["roots"] == []
    assert (
        accept(owner, command(create_body, "create_session", 0, create_body["payload"]))["error"][
            "code"
        ]
        == "retired_id"
    )


def test_generation_and_snapshot_expiry_are_typed(owner: UUID, create_body: dict[str, Any]) -> None:
    accept(owner, Operation.model_validate(create_body))
    cursor = pull(owner, None, 1)["next_cursor"]
    manifest = bootstrap(owner)
    with next_transaction(owner) as db:
        snapshot = db.scalar(select(Snapshot))
        assert snapshot is not None
        snapshot.expires_at = datetime.now(UTC) - timedelta(seconds=1)
    with pytest.raises(HTTPException) as error:
        validate_snapshot(owner, manifest["token"])
    assert error.value.detail["code"] == "snapshot_expired"
    with next_transaction(owner) as db:
        state = db.get(OwnerState, owner)
        assert state is not None
        state.generation = uuid4()
    with pytest.raises(HTTPException) as error:
        pull(owner, cursor, 100)
    assert error.value.detail["code"] == "bootstrap_required"


def test_installations_have_independent_snapshot_slots(owner: UUID) -> None:
    first = bootstrap(owner, uuid4())
    second = bootstrap(owner, uuid4())
    assert snapshot_page(owner, first["token"], 0)["roots"] == []
    assert snapshot_page(owner, second["token"], 0)["roots"] == []


def test_unsupported_contract_is_explicit(owner: UUID) -> None:
    app.dependency_overrides[verified_owner] = lambda: owner
    try:
        with TestClient(app) as client:
            response = client.get("/v1/me", headers={"X-DM-Contract": "2"})
            assert response.status_code == 426
            assert response.json()["detail"]["code"] == "upgrade_required"
    finally:
        app.dependency_overrides.clear()
