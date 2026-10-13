from functools import lru_cache
from typing import Literal

from fastapi import HTTPException
from pydantic import Field, ValidationError, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


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


@lru_cache
def settings() -> Settings:
    try:
        return Settings()
    except ValidationError:
        # Pydantic's raw configuration error can contain input secrets.
        raise HTTPException(503, detail={"code": "service_not_configured"}) from None
