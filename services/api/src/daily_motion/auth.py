from functools import lru_cache
from pathlib import Path
from typing import Annotated
from uuid import UUID

import jwt
from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from daily_motion.config import settings

bearer = HTTPBearer(auto_error=False)


@lru_cache
def key_client(issuer: str) -> jwt.PyJWKClient:
    return jwt.PyJWKClient(issuer.rstrip("/") + "/.well-known/jwks.json", timeout=5)


def verified_owner(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)],
) -> UUID:
    if credentials is None:
        raise HTTPException(401, detail={"code": "authentication_required"})
    config = settings()
    if not config.jwt_issuer.startswith("https://"):
        raise HTTPException(503, detail={"code": "identity_not_configured"})
    try:
        public = (
            Path(config.jwt_public_key_file).read_text(encoding="utf-8")
            if config.jwt_public_key_file
            else key_client(config.jwt_issuer).get_signing_key_from_jwt(credentials.credentials).key
        )
        claims = jwt.decode(
            credentials.credentials,
            public,
            algorithms=["ES256", "RS256"],
            issuer=config.jwt_issuer,
            audience=config.jwt_audience,
            options={"require": ["exp", "iat", "sub", "iss", "aud"]},
        )
        return UUID(claims["sub"])
    except (jwt.PyJWKClientConnectionError, OSError):
        raise HTTPException(503, detail={"code": "identity_provider_unavailable"}) from None
    except (jwt.PyJWTError, ValueError, KeyError):
        raise HTTPException(401, detail={"code": "invalid_credentials"}) from None
