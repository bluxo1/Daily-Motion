from datetime import UTC, datetime, timedelta
from types import SimpleNamespace
from uuid import uuid4

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import ec
from fastapi import HTTPException
from fastapi.security import HTTPAuthorizationCredentials

from daily_motion import auth
from daily_motion.config import settings


@pytest.mark.parametrize(
    "scenario",
    ["valid", "expired", "issuer", "audience", "missing_exp", "subject", "signature", "algorithm"],
)
def test_signature_claims_and_subject_are_verified(
    monkeypatch: pytest.MonkeyPatch, scenario: str
) -> None:
    private = ec.generate_private_key(ec.SECP256R1())
    public = private.public_key()
    monkeypatch.setenv("DM_JWT_ISSUER", "https://identity.example.test/auth/v1")
    settings.cache_clear()
    subject = uuid4()
    now = datetime.now(UTC)
    claims = {
        "sub": str(subject),
        "iss": "https://identity.example.test/auth/v1",
        "aud": "authenticated",
        "iat": now,
        "exp": now + timedelta(minutes=5),
    }
    if scenario == "expired":
        claims["exp"] = now - timedelta(minutes=1)
    elif scenario == "issuer":
        claims["iss"] = "https://attacker.example.test"
    elif scenario == "audience":
        claims["aud"] = "other-service"
    elif scenario == "missing_exp":
        del claims["exp"]
    elif scenario == "subject":
        claims["sub"] = "not-an-owner-id"
    signing_key = ec.generate_private_key(ec.SECP256R1()) if scenario == "signature" else private
    token = jwt.encode(
        claims,
        "synthetic-hmac-key-with-32-characters" if scenario == "algorithm" else signing_key,
        algorithm="HS256" if scenario == "algorithm" else "ES256",
    )
    monkeypatch.setattr(
        auth,
        "key_client",
        lambda _: SimpleNamespace(get_signing_key_from_jwt=lambda _: SimpleNamespace(key=public)),
    )
    credentials = HTTPAuthorizationCredentials(scheme="Bearer", credentials=token)
    try:
        if scenario == "valid":
            assert auth.verified_owner(credentials) == subject
        else:
            with pytest.raises(HTTPException) as error:
                auth.verified_owner(credentials)
            assert error.value.status_code == 401
    finally:
        settings.cache_clear()
