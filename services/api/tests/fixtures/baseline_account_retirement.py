"""Approved-baseline retirement primitive for old-runtime compatibility controls only."""

from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy import text
from sqlalchemy.dialects.postgresql import insert

from daily_motion.models import AccountRetirement, OwnerState
from daily_motion.sync import next_transaction


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
