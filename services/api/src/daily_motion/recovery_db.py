"""Database side of the recovery fence; no activation or independent proof fallback."""

from fastapi import HTTPException
from sqlalchemy import text
from sqlalchemy.orm import Session

# PostgreSQL two-int advisory keys occupy a separate space from the existing
# single-bigint owner initialization/retirement keys. 0x44525032 is ASCII DRP2.
RECOVERY_NAMESPACE = 0x44525032
RECOVERY_KEY = 1


def shared_fence(session: Session) -> None:
    # Separate statement: effect/control reads must acquire their fresh snapshot
    # after the wait, using READ COMMITTED, never a cached ORM instance.
    session.execute(
        text("SELECT pg_advisory_xact_lock_shared(:namespace,:key)"),
        {"namespace": RECOVERY_NAMESPACE, "key": RECOVERY_KEY},
    )


def require_read_committed(session: Session) -> None:
    if session.scalar(text("SHOW transaction_isolation")) != "read committed":
        raise HTTPException(503, detail={"code": "recovery_metadata_unverified"})


def deny_unverified_recovery(session: Session) -> None:
    """Preserve pre-activation v1 only when no recovery control has been installed.

    A copied OPEN row, flag, or ordinary startup cannot activate DRP/2. Until a
    verified authority/target adapter and full publication path are available,
    every installed recovery state denies all ordinary v1 access. This is not
    an account lifecycle transition and consumes no mutation identity.
    """
    state = session.scalar(text("SELECT state FROM recovery.control WHERE singleton"))
    if state is not None:
        raise HTTPException(
            503,
            detail={
                "code": "recovery_metadata_unverified"
                if state == "OPEN"
                else "recovery_unavailable"
            },
        )


def close_admission(session: Session) -> None:
    """Operator-only; the fence is the caller's transaction COMMIT, not this call.

    Runtime has no UPDATE privilege on control. Never used to reopen/activate a
    target. Authentication/approval and actual target identification belong to
    the operator boundary, outside this short transaction.
    """
    require_read_committed(session)
    session.execute(
        text("SELECT pg_advisory_xact_lock(:namespace,:key)"),
        {"namespace": RECOVERY_NAMESPACE, "key": RECOVERY_KEY},
    )
    changed = session.scalar(
        text("UPDATE recovery.control SET state='CLOSED' WHERE singleton RETURNING singleton")
    )
    if changed is not True:
        raise HTTPException(503, detail={"code": "recovery_metadata_unverified"})
