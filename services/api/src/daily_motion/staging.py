"""Explicit operator-only staging preparation; never imported by request handlers."""

import re
from pathlib import Path
from uuid import uuid4

from alembic import command
from alembic.config import Config
from fastapi import HTTPException
from psycopg import sql
from sqlalchemy import Engine, text
from sqlalchemy.engine import make_url
from sqlalchemy.exc import DBAPIError, SQLAlchemyError
from sqlalchemy.orm import Session

from daily_motion.db import assert_runtime_role

ROLE = "dm_staging_runtime"
HEAD = "0003"


def validate_admin_url(value: str, project_ref: str) -> None:
    """Confirm the operator-selected project and TLS before any remote mutation."""
    try:
        url = make_url(value)
        host = url.host or ""
        direct = host == f"db.{project_ref}.supabase.co" and url.username == "postgres"
        pool = host.endswith(".pooler.supabase.com") and url.username == f"postgres.{project_ref}"
        if (
            not re.fullmatch(r"[a-z0-9]{20}", project_ref)
            or not (direct or pool)
            or url.drivername != "postgresql+psycopg"
            or url.database != "postgres"
            or url.port not in {None, 5432}
            or not url.password
            or url.query.get("sslmode") != "verify-full"
            or not url.query.get("sslrootcert")
        ):
            raise ValueError()
    except (ValueError, SQLAlchemyError):
        raise ValueError("Staging project/TLS configuration is invalid") from None


def provision(admin: Engine, runtime_password: str) -> None:
    if len(runtime_password) < 32 or "\x00" in runtime_password:
        raise ValueError("Runtime password must contain at least 32 characters")
    config = Config(str(Path(__file__).resolve().parents[2] / "alembic.ini"))
    config.set_main_option(
        "script_location", str(Path(__file__).resolve().parents[2] / "migrations")
    )
    with admin.begin() as connection:
        # Lock preparation across operator retries, without holding network/Auth work.
        connection.execute(text("SELECT pg_advisory_xact_lock(724681937110)"))
        flags = connection.execute(
            text("""
            SELECT rolsuper, rolbypassrls, rolcreatedb, rolcreaterole, rolreplication
            FROM pg_roles WHERE rolname=:role
        """),
            {"role": ROLE},
        ).one_or_none()
        if flags is not None and any(flags):
            raise ValueError("Existing staging role is not restricted")
        owner_member = (
            connection.scalar(
                text("""
            SELECT EXISTS (
              SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
              WHERE n.nspname='training' AND c.relkind IN ('r','p')
                AND pg_has_role(:role, c.relowner, 'MEMBER')
            )
        """),
                {"role": ROLE},
            )
            if flags is not None
            else False
        )
        if owner_member:
            raise ValueError("Existing staging role belongs to a table owner")
        config.attributes["connection"] = connection
        command.upgrade(config, "head")
        # psycopg quotes values/identifiers. Raw SQL/parameter representations are
        # never logged. Admin engine must use hide_parameters=True and echo=False.
        driver = connection.connection.driver_connection
        assert driver is not None
        with driver.cursor() as cursor:
            if flags is None:
                cursor.execute(
                    sql.SQL(
                        "CREATE ROLE {} LOGIN NOSUPERUSER NOBYPASSRLS NOCREATEDB "
                        "NOCREATEROLE NOREPLICATION PASSWORD {}"
                    ).format(sql.Identifier(ROLE), sql.Literal(runtime_password))
                )
            else:
                cursor.execute(
                    sql.SQL("ALTER ROLE {} LOGIN PASSWORD {}").format(
                        sql.Identifier(ROLE), sql.Literal(runtime_password)
                    )
                )
            cursor.execute(
                sql.SQL("GRANT USAGE ON SCHEMA training TO {}").format(sql.Identifier(ROLE))
            )
            cursor.execute(
                sql.SQL(
                    "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA training TO {}"
                ).format(sql.Identifier(ROLE))
            )
            cursor.execute(
                sql.SQL("GRANT USAGE ON SCHEMA public TO {}").format(sql.Identifier(ROLE))
            )
            cursor.execute(
                sql.SQL("GRANT SELECT ON public.alembic_version TO {}").format(sql.Identifier(ROLE))
            )
            for name in ("PUBLIC", "anon", "authenticated", "service_role"):
                exists = name == "PUBLIC" or connection.scalar(
                    text("SELECT EXISTS(SELECT 1 FROM pg_roles WHERE rolname=:name)"),
                    {"name": name},
                )
                if exists:
                    identifier = sql.SQL("PUBLIC") if name == "PUBLIC" else sql.Identifier(name)
                    cursor.execute(
                        sql.SQL("REVOKE ALL ON SCHEMA training FROM {}").format(identifier)
                    )
                    cursor.execute(
                        sql.SQL("REVOKE ALL ON ALL TABLES IN SCHEMA training FROM {}").format(
                            identifier
                        )
                    )
        if connection.scalar(text("SELECT version_num FROM public.alembic_version")) != HEAD:
            raise ValueError("Migration revision does not match the staging target")


def verify_isolation(runtime: Engine) -> dict[str, object]:
    """Rollback-only synthetic owner probe; safe on an explicitly selected staging DB."""
    first, second = uuid4(), uuid4()
    with Session(runtime) as session:
        transaction = session.begin()
        try:
            assert_runtime_role(session)
            session.execute(text("SELECT set_config('app.owner_id', '', true)"))
            try:
                revisions = session.scalars(
                    text("SELECT version_num FROM public.alembic_version")
                ).all()
            except SQLAlchemyError:
                raise ValueError("Runtime migration metadata is unavailable") from None
            if revisions != [HEAD]:
                raise ValueError("Runtime migration metadata does not match the staging target")
            if session.scalar(text("SELECT count(*) FROM training.owner_state")) != 0:
                raise ValueError("Missing owner context did not fail closed")
            for owner in (first, second):
                session.execute(
                    text("SELECT set_config('app.owner_id', :owner, true)"), {"owner": str(owner)}
                )
                session.execute(
                    text("""
                    INSERT INTO training.owner_state(owner_id,status,generation)
                    VALUES(:owner,'active',:generation)
                """),
                    {"owner": owner, "generation": uuid4()},
                )
            if session.scalars(text("SELECT owner_id FROM training.owner_state")).all() != [second]:
                raise ValueError("Owner isolation failed")
            crossed = False
            try:
                with session.begin_nested():
                    session.execute(
                        text("INSERT INTO training.profiles(owner_id) VALUES(:owner)"),
                        {"owner": first},
                    )
            except DBAPIError as error:
                if getattr(error.orig, "sqlstate", None) != "42501":
                    raise
                crossed = True
            if not crossed:
                raise ValueError("Cross-owner insertion did not fail closed")
            tables = session.execute(
                text("""
                SELECT count(*), bool_and(c.relrowsecurity AND c.relforcerowsecurity)
                FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
                WHERE n.nspname='training' AND c.relkind IN ('r','p')
            """)
            ).one()
            if tables[0] != 11 or tables[1] is not True:
                raise ValueError("Expected training schema/forced RLS is missing")
        except HTTPException:
            raise ValueError("Runtime role is unsafe") from None
        finally:
            transaction.rollback()
    with runtime.connect() as connection:
        if (
            connection.scalar(text("SELECT nullif(current_setting('app.owner_id',true),'')"))
            is not None
        ):
            raise ValueError("Pooled owner context leaked")
    return {
        "migration_revision": revisions[0],
        "training_tables": 11,
        "forced_rls": True,
        "owner_isolation": True,
        "probe_rolled_back": True,
        "pooled_owner_reset": True,
    }
