from collections.abc import Iterator
from functools import lru_cache
from uuid import UUID

from fastapi import HTTPException
from sqlalchemy import Engine, create_engine, text
from sqlalchemy.orm import Session

from daily_motion.config import settings


@lru_cache
def engine() -> Engine:
    url = settings().database_url
    if not url:
        raise HTTPException(503, detail={"code": "service_not_configured"})
    return create_engine(url, pool_size=5, max_overflow=0, pool_pre_ping=True)


def tenant_transaction(owner: UUID, isolation: str | None = None) -> Iterator[Session]:
    bind = engine().execution_options(isolation_level=isolation) if isolation else engine()
    with Session(bind) as session, session.begin():
        # Do not assume deployment credentials enforce the tested isolation.
        # Recheck per transaction so role/policy changes cannot outlive a cache.
        restricted = session.scalar(
            text("""
            SELECT NOT r.rolsuper AND NOT r.rolbypassrls
              AND NOT EXISTS (
                SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
                WHERE n.nspname='training' AND c.relkind IN ('r','p')
                  AND (NOT c.relrowsecurity OR NOT c.relforcerowsecurity
                       OR pg_has_role(current_user, c.relowner, 'MEMBER'))
              )
            FROM pg_roles r WHERE r.rolname=current_user
        """)
        )
        if restricted is not True:
            raise HTTPException(503, detail={"code": "service_not_configured"})
        session.execute(
            text("SELECT set_config('app.owner_id', :owner, true)"), {"owner": str(owner)}
        )
        yield session
