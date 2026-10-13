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
        session.execute(
            text("SELECT set_config('app.owner_id', :owner, true)"), {"owner": str(owner)}
        )
        yield session
