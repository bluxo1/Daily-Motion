from collections.abc import Iterator
from functools import lru_cache
from uuid import UUID

from fastapi import HTTPException
from sqlalchemy import Engine, create_engine, text
from sqlalchemy.orm import Session

from daily_motion.config import settings
from daily_motion.models import Base
from daily_motion.recovery_db import deny_unverified_recovery, shared_fence


@lru_cache
def engine() -> Engine:
    config = settings()
    config.validate_hosted()
    url = config.database_url
    if not url:
        raise HTTPException(503, detail={"code": "service_not_configured"})
    return create_engine(
        url,
        pool_size=5,
        max_overflow=0,
        pool_pre_ping=True,
        pool_timeout=5,
        hide_parameters=True,
        connect_args={"connect_timeout": 5},
    )


def assert_runtime_role(session: Session) -> None:
    # Recheck each transaction; role/policy changes cannot outlive a cache.
    restricted = session.scalar(
        text("""
        SELECT NOT r.rolsuper AND NOT r.rolbypassrls
          AND NOT r.rolcreatedb AND NOT r.rolcreaterole AND NOT r.rolreplication
          AND has_schema_privilege(current_user, 'recovery', 'USAGE')
          AND NOT has_schema_privilege(current_user, 'recovery', 'CREATE')
          AND has_table_privilege(current_user, 'recovery.control', 'SELECT')
          AND NOT has_table_privilege(current_user, 'recovery.control',
              'INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')
          AND NOT EXISTS (
            SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
            WHERE n.nspname='recovery' AND c.relname='control'
              AND pg_has_role(current_user,c.relowner,'MEMBER')
          )
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


def database_readiness() -> None:
    """Read-only and owner-free; migration credentials never run in the API."""
    with Session(engine()) as session, session.begin():
        session.execute(text("SET LOCAL statement_timeout = '5s'"))
        session.execute(text("SELECT set_config('app.owner_id', '', true)"))
        assert_runtime_role(session)
        if session.scalars(text("SELECT version_num FROM public.alembic_version")).all() != [
            "0004"
        ]:
            raise HTTPException(503, detail={"code": "service_not_configured"})
        expected = {table.name for table in Base.metadata.tables.values()} | {
            "recovery_owners",
            "recovery_attempts",
        }
        present = set(
            session.scalars(
                text("""
            SELECT c.relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
            WHERE n.nspname='training' AND c.relkind IN ('r','p')
              AND has_table_privilege(current_user, c.oid, 'SELECT')
              AND has_table_privilege(current_user, c.oid, 'INSERT')
              AND has_table_privilege(current_user, c.oid, 'UPDATE')
              AND has_table_privilege(current_user, c.oid, 'DELETE')
        """)
            )
        )
        if (
            not expected.issubset(present)
            or session.scalar(text("SELECT count(*) FROM training.owner_state")) != 0
        ):
            raise HTTPException(503, detail={"code": "service_not_configured"})
        deny_unverified_recovery(session)


def tenant_transaction(owner: UUID, isolation: str | None = None) -> Iterator[Session]:
    bind = engine().execution_options(isolation_level=isolation or "READ COMMITTED")
    with Session(bind) as session, session.begin():
        shared_fence(session)
        assert_runtime_role(session)
        deny_unverified_recovery(session)
        session.execute(
            text("SELECT set_config('app.owner_id', :owner, true)"), {"owner": str(owner)}
        )
        yield session
