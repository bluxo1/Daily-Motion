import io
import json
from concurrent.futures import ThreadPoolExecutor, TimeoutError
from datetime import UTC, datetime, timedelta
from pathlib import Path
from threading import Event
from typing import Any
from urllib.error import HTTPError
from uuid import UUID, uuid4

import jwt
import pytest
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec
from fastapi import HTTPException
from fastapi.testclient import TestClient
from sqlalchemy import Engine, func, select, text

from daily_motion import accounts
from daily_motion.config import settings
from daily_motion.main import app
from daily_motion.models import AccountRetirement, OwnerState, Profile, Workout
from daily_motion.sync import next_transaction, owner_guard


@pytest.fixture
def identity(database: Engine, monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> Any:
    private = ec.generate_private_key(ec.SECP256R1())
    pem = tmp_path / "public.pem"
    pem.write_bytes(
        private.public_key().public_bytes(
            serialization.Encoding.PEM, serialization.PublicFormat.SubjectPublicKeyInfo
        )
    )
    issuer = "https://identity.supabase.test/auth/v1"
    monkeypatch.setenv("DM_JWT_ISSUER", issuer)
    monkeypatch.setenv("DM_JWT_PUBLIC_KEY_FILE", str(pem))
    monkeypatch.setenv("DM_SUPABASE_URL", "https://identity.supabase.test")
    monkeypatch.setenv("DM_SUPABASE_PUBLISHABLE_KEY", "sb_publishable_synthetic")
    settings.cache_clear()

    class Identity:
        provider_failure = False
        provider_owner: str | None = None
        provider_state: str = "valid"

        def headers(self, owner: UUID, scenario: str = "valid") -> dict[str, str]:
            now = datetime.now(UTC)
            claims: dict[str, Any] = {
                "sub": str(owner),
                "iss": issuer,
                "aud": "authenticated",
                "iat": now,
                "exp": now + timedelta(minutes=5),
            }
            if scenario == "expired":
                claims["exp"] = now - timedelta(seconds=10)
            if scenario == "issuer":
                claims["iss"] = "https://wrong.test/auth/v1"
            if scenario == "audience":
                claims["aud"] = "wrong"
            key = ec.generate_private_key(ec.SECP256R1()) if scenario == "signature" else private
            token = (
                "malformed"
                if scenario == "malformed"
                else jwt.encode(claims, key, algorithm="ES256")
            )
            return {"Authorization": "Bearer " + token}

        def open(self, request: Any, timeout: int) -> io.BytesIO:
            if self.provider_failure:
                raise TimeoutError()
            if self.provider_state == "revoked":
                raise HTTPError(request.full_url, 401, "unauthorized", None, None)
            token = request.get_header("Authorization").split(" ", 1)[1]
            subject = jwt.decode(
                token,
                private.public_key(),
                algorithms=["ES256"],
                issuer=issuer,
                audience="authenticated",
            )["sub"]
            user = {
                "id": self.provider_owner or subject,
                "email_confirmed_at": "2026-10-13T00:00:00Z",
                "is_anonymous": False,
            }
            if self.provider_state == "unconfirmed":
                user["email_confirmed_at"] = None
            elif self.provider_state == "anonymous":
                user["is_anonymous"] = True
            elif self.provider_state == "banned":
                user["banned_until"] = "2099-01-01T00:00:00Z"
            elif self.provider_state == "deleted":
                user["deleted_at"] = "2026-10-13T00:00:00Z"
            return io.BytesIO(json.dumps(user).encode())

    value = Identity()
    monkeypatch.setattr(accounts, "build_opener", lambda _: value)
    return value


def test_first_and_replayed_initialize(identity: Any) -> None:
    owner = uuid4()
    with TestClient(app) as client:
        first = client.post("/v1/account/initialize", json={}, headers=identity.headers(owner))
        second = client.post("/v1/account/initialize", json={}, headers=identity.headers(owner))
    assert first.status_code == second.status_code == 200
    assert first.json() == second.json()
    assert first.json()["owner_id"] == str(owner)
    with next_transaction(owner) as db:
        assert db.scalar(select(func.count()).select_from(OwnerState)) == 1
        assert db.scalar(select(func.count()).select_from(Profile)) == 1
        assert db.scalar(select(func.count()).select_from(Workout)) == 0


def test_client_owner_is_never_initialization_authority(identity: Any) -> None:
    with TestClient(app) as client:
        response = client.post(
            "/v1/account/initialize",
            json={"user_id": str(uuid4())},
            headers=identity.headers(uuid4()),
        )
    assert response.status_code == 422


@pytest.mark.parametrize("scenario", ["expired", "issuer", "audience", "signature", "malformed"])
def test_real_jwt_failures_cannot_initialize(identity: Any, scenario: str) -> None:
    owner = uuid4()
    with TestClient(app) as client:
        response = client.post(
            "/v1/account/initialize", json={}, headers=identity.headers(owner, scenario)
        )
    assert response.status_code == 401
    with next_transaction(owner) as db:
        assert db.get(OwnerState, owner) is None


def test_current_provider_subject_must_match_verified_jwt(identity: Any) -> None:
    owner = uuid4()
    identity.provider_owner = str(uuid4())
    with TestClient(app) as client:
        response = client.post("/v1/account/initialize", json={}, headers=identity.headers(owner))
    assert response.status_code == 401
    with next_transaction(owner) as db:
        assert db.get(OwnerState, owner) is None


@pytest.mark.parametrize("state", ["revoked", "unconfirmed", "anonymous", "banned", "deleted"])
def test_current_provider_rejection_cannot_initialize(identity: Any, state: str) -> None:
    owner = uuid4()
    identity.provider_state = state
    headers = identity.headers(owner)
    with TestClient(app) as client:
        response = client.post("/v1/account/initialize", json={}, headers=headers)
    assert response.status_code == 401
    assert response.json() == {"detail": {"code": "invalid_credentials"}}
    assert headers["Authorization"] not in response.text
    with next_transaction(owner) as db:
        assert db.get(OwnerState, owner) is None


def test_provider_unavailable_does_not_initialize_or_destroy_existing_account(
    identity: Any, owner: UUID
) -> None:
    identity.provider_failure = True
    with TestClient(app) as client:
        response = client.post("/v1/account/initialize", json={}, headers=identity.headers(owner))
    assert response.status_code == 503
    with next_transaction(owner) as db:
        assert owner_guard(db, owner).status == "active"


def test_disabled_account_cannot_be_reinitialized(identity: Any, owner: UUID) -> None:
    with next_transaction(owner) as db:
        owner_guard(db, owner).status = "deleting"
    with TestClient(app) as client:
        response = client.post("/v1/account/initialize", json={}, headers=identity.headers(owner))
    assert response.status_code == 403
    assert response.json()["detail"]["owner_id"] == str(owner)
    with next_transaction(owner) as db:
        assert db.get(Profile, owner) is None


def test_erased_owner_barrier_prevents_old_valid_identity_recreation(identity: Any) -> None:
    owner = uuid4()
    with next_transaction(owner) as db:
        db.add(AccountRetirement(owner_id=owner, retired_at=datetime.now(UTC)))
    with TestClient(app) as client:
        response = client.post("/v1/account/initialize", json={}, headers=identity.headers(owner))
    assert response.status_code == 403
    with next_transaction(owner) as db:
        assert db.get(OwnerState, owner) is None
        assert db.get(AccountRetirement, owner) is not None
        # Even blanket runtime grants cannot remove the irreversible marker.
        assert db.execute(text("DELETE FROM training.account_retirements")).rowcount == 0


def test_concurrent_initialization_and_profile_idempotency(identity: Any) -> None:
    owner = uuid4()
    with ThreadPoolExecutor(4) as executor:
        responses = list(executor.map(lambda _: accounts.initialize_account(owner), range(8)))
    assert len({r["generation"] for r in responses}) == 1
    with next_transaction(owner) as db:
        assert db.scalar(select(func.count()).select_from(Profile)) == 1


def test_under_lock_disable_wins_over_previously_authenticated_initialize(
    identity: Any, owner: UUID
) -> None:
    arrived = Event()

    def initialize() -> None:
        arrived.set()
        accounts.initialize_account(owner)

    with ThreadPoolExecutor(1) as executor:
        with next_transaction(owner) as db:
            owner_guard(db, owner).status = "deleting"
            db.flush()
            future = executor.submit(initialize)
            assert arrived.wait(10)
            with pytest.raises(TimeoutError):
                future.result(timeout=0.1)
        with pytest.raises(HTTPException) as error:
            future.result(timeout=10)
    assert error.value.status_code == 403
    with next_transaction(owner) as db:
        assert db.get(Profile, owner) is None


def test_profile_and_retirement_rls_and_connection_context(identity: Any) -> None:
    a, b = uuid4(), uuid4()
    accounts.initialize_account(a)
    accounts.initialize_account(b)
    with next_transaction(a) as db:
        assert db.get(Profile, b) is None
        db.add(AccountRetirement(owner_id=a, retired_at=datetime.now(UTC)))
    with next_transaction(b) as db:
        assert db.get(Profile, a) is None
        assert db.get(AccountRetirement, a) is None
    from daily_motion.db import engine

    with engine().connect() as db:
        assert db.scalar(text("SELECT count(*) FROM training.profiles")) == 0
        assert db.scalar(text("SELECT count(*) FROM training.account_retirements")) == 0


def test_production_synthetic_verification_config_fails_closed_without_secret_echo(
    identity: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv("DM_ENVIRONMENT", "production")
    settings.cache_clear()
    with TestClient(app) as client:
        response = client.get("/v1/me", headers=identity.headers(uuid4()))
    assert response.status_code == 503
    assert response.json() == {"detail": {"code": "service_not_configured"}}
    settings.cache_clear()


def test_erasure_barrier_also_denies_old_sync_token_after_account_row_purge(
    identity: Any, owner: UUID
) -> None:
    accounts.mark_account_retired(owner)
    with next_transaction(owner) as db:
        db.execute(text("DELETE FROM training.owner_state WHERE owner_id=:owner"), {"owner": owner})
    with TestClient(app) as client:
        response = client.get("/v1/me", headers=identity.headers(owner))
    assert response.status_code == 403
    assert response.json()["detail"]["code"] == "account_inactive"
    assert response.json()["detail"]["owner_id"] == str(owner)
