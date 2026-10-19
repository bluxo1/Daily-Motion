"""Exercise real JWT/JWKS verification with ephemeral keys, without provider changes."""

import json
import time
from collections.abc import Iterator
from datetime import UTC, datetime, timedelta
from io import BytesIO
from types import SimpleNamespace
from typing import Any
from urllib.error import URLError
from uuid import UUID, uuid4

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import ec
from fastapi import HTTPException
from fastapi.security import HTTPAuthorizationCredentials

from daily_motion import auth
from daily_motion.config import settings

ISSUER = "https://identity.example.test/auth/v1"


@pytest.fixture
def discovery(monkeypatch: pytest.MonkeyPatch) -> Iterator[dict[str, Any]]:
    state: dict[str, Any] = {"keys": [], "fetches": 0, "unavailable": False}
    clock = [time.monotonic()]

    def fetch(request: Any, timeout: float) -> BytesIO:
        assert request.full_url == f"{ISSUER}/.well-known/jwks.json"
        assert timeout == 5
        state["fetches"] += 1
        if state["unavailable"]:
            raise URLError("synthetic provider outage; this message must not escape")
        return BytesIO(json.dumps({"keys": state["keys"]}).encode())

    monkeypatch.setenv("DM_JWT_ISSUER", ISSUER)
    monkeypatch.setenv("DM_JWT_PUBLIC_KEY_FILE", "")
    monkeypatch.setattr(
        jwt.jwks_client.urllib.request, "build_opener", lambda *_: SimpleNamespace(open=fetch)
    )
    for module in (jwt.jwks_client, jwt.jwk_set_cache, jwt.api_jwk):
        monkeypatch.setattr(module, "time", SimpleNamespace(monotonic=lambda: clock[0]))
    state["clock"] = clock
    settings.cache_clear()
    auth.key_client.cache_clear()
    yield state
    auth.key_client.cache_clear()
    settings.cache_clear()


def signer(kid: str) -> tuple[ec.EllipticCurvePrivateKey, dict[str, Any]]:
    private = ec.generate_private_key(ec.SECP256R1())
    public = json.loads(jwt.algorithms.ECAlgorithm.to_jwk(private.public_key()))
    return private, {**public, "kid": kid, "alg": "ES256", "use": "sig"}


def credential(
    private: ec.EllipticCurvePrivateKey, kid: str, subject: UUID
) -> HTTPAuthorizationCredentials:
    now = datetime.now(UTC)
    token = jwt.encode(
        {
            "sub": str(subject),
            "iss": ISSUER,
            "aud": "authenticated",
            "iat": now,
            "exp": now + timedelta(minutes=30),
        },
        private,
        algorithm="ES256",
        headers={"kid": kid, "jku": "https://untrusted.example.test/keys"},
    )
    return HTTPAuthorizationCredentials(scheme="Bearer", credentials=token)


def rejected(credentials: HTTPAuthorizationCredentials, status: int, code: str) -> None:
    with pytest.raises(HTTPException) as error:
        auth.verified_owner(credentials)
    assert error.value.status_code == status
    assert error.value.detail == {"code": code}


def test_standby_discovery_preserves_old_and_new_signers(discovery: dict[str, Any]) -> None:
    old, old_public = signer("old")
    new, new_public = signer("next")
    discovery["keys"] = [old_public, new_public]
    subject = uuid4()
    assert auth.verified_owner(credential(old, "old", subject)) == subject
    assert auth.verified_owner(credential(new, "next", subject)) == subject
    assert discovery["fetches"] == 1


def test_unknown_key_respects_fetch_cooldown_then_discovers_rotation(
    discovery: dict[str, Any],
) -> None:
    old, old_public = signer("old")
    new, new_public = signer("next")
    discovery["keys"] = [old_public]
    subject = uuid4()
    assert auth.verified_owner(credential(old, "old", subject)) == subject
    discovery["keys"] = [old_public, new_public]
    next_token = credential(new, "next", subject)
    rejected(next_token, 401, "invalid_credentials")
    assert discovery["fetches"] == 1
    discovery["clock"][0] += 31
    assert auth.verified_owner(next_token) == subject
    assert discovery["fetches"] == 2


def test_revocation_needs_cache_invalidation_and_retains_current_signer(
    discovery: dict[str, Any],
) -> None:
    old, old_public = signer("old")
    new, new_public = signer("next")
    discovery["keys"] = [old_public, new_public]
    subject = uuid4()
    old_token = credential(old, "old", subject)
    new_token = credential(new, "next", subject)
    assert auth.verified_owner(old_token) == subject
    discovery["keys"] = [new_public]
    # Discovery changes do not invalidate an existing process's cached trust.
    assert auth.verified_owner(old_token) == subject
    auth.key_client.cache_clear()
    rejected(old_token, 401, "invalid_credentials")
    assert auth.verified_owner(new_token) == subject


def test_discovery_outage_fails_closed_without_provider_error_text(
    discovery: dict[str, Any],
) -> None:
    private, _ = signer("current")
    discovery["unavailable"] = True
    rejected(credential(private, "current", uuid4()), 503, "identity_provider_unavailable")


def test_expired_discovery_cache_rechecks_revoked_trust(discovery: dict[str, Any]) -> None:
    old, old_public = signer("old")
    new, new_public = signer("next")
    discovery["keys"] = [old_public, new_public]
    subject = uuid4()
    old_token = credential(old, "old", subject)
    assert auth.verified_owner(old_token) == subject
    discovery["keys"] = [new_public]
    discovery["clock"][0] += 299
    assert auth.verified_owner(old_token) == subject
    assert discovery["fetches"] == 1
    discovery["clock"][0] += 2
    rejected(old_token, 401, "invalid_credentials")
    assert auth.verified_owner(credential(new, "next", subject)) == subject
    assert discovery["fetches"] == 2


def test_expired_cache_does_not_accept_stale_trust_during_outage(
    discovery: dict[str, Any],
) -> None:
    current, public = signer("current")
    discovery["keys"] = [public]
    subject = uuid4()
    current_token = credential(current, "current", subject)
    assert auth.verified_owner(current_token) == subject
    discovery["clock"][0] += 301
    discovery["unavailable"] = True
    rejected(current_token, 503, "identity_provider_unavailable")


def test_unknown_key_outage_does_not_remove_cached_current_key(
    discovery: dict[str, Any],
) -> None:
    current, public = signer("current")
    unknown, _ = signer("unknown")
    discovery["keys"] = [public]
    subject = uuid4()
    current_token = credential(current, "current", subject)
    assert auth.verified_owner(current_token) == subject
    discovery["clock"][0] += 31
    discovery["unavailable"] = True
    rejected(credential(unknown, "unknown", subject), 503, "identity_provider_unavailable")
    assert auth.verified_owner(current_token) == subject
