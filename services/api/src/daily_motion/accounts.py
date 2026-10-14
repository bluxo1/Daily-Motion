"""Current provider verification followed by idempotent, owner-guarded initialization."""

import json
from datetime import UTC, datetime
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import HTTPRedirectHandler, Request, build_opener
from uuid import UUID, uuid4

from fastapi import HTTPException
from sqlalchemy import text
from sqlalchemy.dialects.postgresql import insert

from daily_motion.config import settings
from daily_motion.models import AccountRetirement, OwnerState, Profile
from daily_motion.sync import me, next_transaction, owner_guard


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, *args: Any, **kwargs: Any) -> None:
        return None


def current_provider_identity(owner: UUID, token: str) -> None:
    config = settings()
    origin = config.supabase_url.rstrip("/")
    if (
        not origin.startswith("https://")
        or config.jwt_issuer.rstrip("/") != origin + "/auth/v1"
        or not config.supabase_publishable_key.startswith("sb_publishable_")
    ):
        raise HTTPException(503, detail={"code": "identity_not_configured"})
    request = Request(
        origin + "/auth/v1/user",
        headers={"Authorization": "Bearer " + token, "apikey": config.supabase_publishable_key},
    )
    try:
        with build_opener(NoRedirect()).open(request, timeout=5) as response:
            body = response.read(65537)
            if len(body) > 65536:
                raise ValueError()
            user = json.loads(body)
        if (
            not isinstance(user, dict)
            or user.get("id") != str(owner)
            or not isinstance(user.get("email_confirmed_at"), str)
            or not user["email_confirmed_at"]
            or user.get("is_anonymous", False)
            or user.get("deleted_at")
        ):
            raise ValueError()
        banned = user.get("banned_until")
        if banned and datetime.fromisoformat(banned).astimezone(UTC) > datetime.now(UTC):
            raise ValueError()
    except HTTPError as error:
        if error.code in (401, 403, 404):
            raise HTTPException(401, detail={"code": "invalid_credentials"}) from None
        raise HTTPException(503, detail={"code": "identity_provider_unavailable"}) from None
    except (URLError, TimeoutError, OSError):
        raise HTTPException(503, detail={"code": "identity_provider_unavailable"}) from None
    except (ValueError, TypeError):
        raise HTTPException(401, detail={"code": "invalid_credentials"}) from None


def initialize_account(owner: UUID) -> dict[str, Any]:
    with next_transaction(owner) as db:
        # Serialize absent-row creation/retirement without trusting device identity.
        db.execute(
            text("SELECT pg_advisory_xact_lock(hashtextextended(:owner,0))"), {"owner": str(owner)}
        )
        if db.get(AccountRetirement, owner) is not None:
            raise HTTPException(
                403,
                detail={"code": "account_inactive", "owner_id": str(owner), "schema_version": 1},
            )
        db.execute(
            insert(OwnerState)
            .values(
                owner_id=owner,
                status="active",
                generation=uuid4(),
                position=0,
                erasure_epoch=0,
                minimum_position=0,
            )
            .on_conflict_do_nothing(index_elements=[OwnerState.owner_id])
        )
        owner_guard(db, owner)
        db.execute(
            insert(Profile)
            .values(owner_id=owner, unit="kg")
            .on_conflict_do_nothing(index_elements=[Profile.owner_id])
        )
        profile = db.get(Profile, owner)
        assert profile is not None
        unit = profile.unit
    return {**me(owner), "profile": {"unit": unit}}


def mark_account_retired(owner: UUID) -> None:
    """Internal erasure barrier, recorded before payload/account removal; no public route."""
    with next_transaction(owner) as db:
        db.execute(
            text("SELECT pg_advisory_xact_lock(hashtextextended(:owner,0))"), {"owner": str(owner)}
        )
        state = db.get(OwnerState, owner, with_for_update=True)
        if state is not None:
            state.status = "deleting"
            state.erasure_epoch += 1
        db.execute(
            insert(AccountRetirement)
            .values(owner_id=owner, retired_at=datetime.now(UTC))
            .on_conflict_do_nothing(index_elements=[AccountRetirement.owner_id])
        )
