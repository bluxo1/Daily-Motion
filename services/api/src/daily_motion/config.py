import os
from functools import lru_cache
from typing import Literal
from urllib.parse import urlsplit

from fastapi import HTTPException
from pydantic import Field, ValidationError, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict
from sqlalchemy.engine import URL, make_url
from sqlalchemy.exc import ArgumentError


def validate_database_transport(database: URL) -> None:
    """Do not let libpq replace the destination/role that the operator confirmed."""
    root_cert = database.query.get("sslrootcert")
    if (
        not database.host
        or "," in database.host
        or not database.database
        or (database.port is None and os.environ.get("PGPORT"))
        or set(database.query) - {"sslmode", "sslrootcert"}
        or database.query.get("sslmode") != "verify-full"
        or not isinstance(root_cert, str)
        or not root_cert
        or any(
            os.environ.get(name)
            for name in ("PGHOSTADDR", "PGSERVICE", "PGSERVICEFILE", "PGOPTIONS")
        )
    ):
        raise ValueError("Database transport configuration is invalid")


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="DM_", env_file=".env", extra="ignore")
    database_url: str = Field(default="", repr=False)
    jwt_issuer: str = ""
    jwt_audience: str = "authenticated"
    sync_signing_key: str = Field(default="", repr=False)
    # Public keys only, for an explicitly configured local development identity issuer.
    jwt_public_key_file: str = ""
    environment: Literal["development", "test", "staging", "production"] = "production"
    supabase_url: str = ""
    supabase_publishable_key: str = Field(default="", repr=False)

    @model_validator(mode="after")
    def isolate_test_auth(self) -> "Settings":
        if self.jwt_public_key_file and self.environment not in {"development", "test"}:
            raise ValueError("Synthetic verification keys require development or test")
        return self

    def validate_hosted(self) -> None:
        """Fail closed for live configuration; never include raw values in errors."""
        if self.environment not in {"staging", "production"}:
            return
        try:
            origin = urlsplit(self.supabase_url)
            if (
                origin.scheme != "https"
                or not origin.hostname
                or origin.username
                or origin.password
                or origin.query
                or origin.fragment
                or origin.path not in {"", "/"}
                or self.jwt_issuer.rstrip("/") != self.supabase_url.rstrip("/") + "/auth/v1"
                or self.jwt_audience != "authenticated"
                or not self.supabase_publishable_key.startswith("sb_publishable_")
                or len(self.sync_signing_key) < 32
                or self.jwt_public_key_file
            ):
                raise ValueError()
            database = make_url(self.database_url)
            validate_database_transport(database)
            if (
                database.drivername != "postgresql+psycopg"
                or not database.host
                or not database.username
                or not database.password
                or database.port == 6543
            ):
                raise ValueError()
        except (ValueError, TypeError, ArgumentError):
            raise HTTPException(503, detail={"code": "service_not_configured"}) from None


@lru_cache
def settings() -> Settings:
    try:
        return Settings()
    except ValidationError:
        # Pydantic's raw configuration error can contain input secrets.
        raise HTTPException(503, detail={"code": "service_not_configured"}) from None
