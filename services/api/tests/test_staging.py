from uuid import UUID

import psycopg
import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient
from sqlalchemy import Engine, create_engine, text

from daily_motion import main
from daily_motion.config import Settings, settings
from daily_motion.main import app
from daily_motion.staging import ROLE, provision, validate_admin_url, verify_isolation


def hosted() -> dict[str, str]:
    return {
        "environment": "staging",
        "database_url": "postgresql+psycopg://dm_staging_runtime:synthetic@db.abcdefghijklmnopqrst.supabase.co:5432/postgres?sslmode=verify-full&sslrootcert=/run/secrets/root.crt",
        "supabase_url": "https://abcdefghijklmnopqrst.supabase.co",
        "supabase_publishable_key": "sb_publishable_synthetic",
        "jwt_issuer": "https://abcdefghijklmnopqrst.supabase.co/auth/v1",
        "sync_signing_key": "synthetic-cursor-signing-key-32-characters",
    }


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("database_url", "postgresql://user:password@localhost/postgres"),
        ("database_url", "postgresql+psycopg://user:password@db.test/postgres?sslmode=require"),
        (
            "database_url",
            "postgresql+psycopg://user:password@db.test:6543/postgres?sslmode=verify-full&sslrootcert=/tmp/root.crt",
        ),
        ("database_url", "malformed-secret-synthetic-password"),
        ("supabase_url", "http://identity.test"),
        ("supabase_url", "https://secret:password@identity.test"),
        ("jwt_issuer", "https://another-identity.test/auth/v1"),
        ("jwt_audience", "another-service"),
        ("supabase_publishable_key", "sb_secret_synthetic"),
        ("sync_signing_key", "short"),
    ],
)
def test_hosted_configuration_fails_closed_without_leaking_values(field: str, value: str) -> None:
    values = hosted()
    values[field] = value
    with pytest.raises(HTTPException) as error:
        Settings(**values).validate_hosted()
    assert error.value.status_code == 503
    assert error.value.detail == {"code": "service_not_configured"}
    assert value not in str(error.value)


def test_hosted_configuration_accepts_verified_session_connection() -> None:
    Settings(**hosted()).validate_hosted()
    ref = "abcdefghijklmnopqrst"
    admin = str(hosted()["database_url"]).replace("dm_staging_runtime:", "postgres:")
    validate_admin_url(admin, ref)
    with pytest.raises(ValueError):
        validate_admin_url(admin, "xxxxxxxxxxxxxxxxxxxx")


@pytest.mark.parametrize(
    "override",
    [
        "host=other-project.example.test",
        "hostaddr=192.0.2.10",
        "dbname=other_database",
        "user=other_role",
        "service=other_project",
        "options=-crole=postgres",
        "sslrootcert=/tmp/another-root.crt",
    ],
)
def test_hosted_project_confirmation_rejects_query_routing_overrides(override: str) -> None:
    values = hosted()
    values["database_url"] += "&" + override
    with pytest.raises(HTTPException) as error:
        Settings(**values).validate_hosted()
    assert error.value.detail == {"code": "service_not_configured"}
    assert "synthetic" not in str(error.value)
    assert override not in str(error.value)
    admin = values["database_url"].replace("dm_staging_runtime:", "postgres:")
    with pytest.raises(ValueError, match="Staging project/TLS configuration is invalid"):
        validate_admin_url(admin, "abcdefghijklmnopqrst")


@pytest.mark.parametrize("name", ["PGHOSTADDR", "PGSERVICE", "PGSERVICEFILE"])
def test_hosted_project_confirmation_rejects_ambient_routing_overrides(
    monkeypatch: pytest.MonkeyPatch, name: str
) -> None:
    monkeypatch.setenv(name, "synthetic-routing-override")
    values = hosted()
    with pytest.raises(HTTPException) as error:
        Settings(**values).validate_hosted()
    assert error.value.detail == {"code": "service_not_configured"}
    admin = values["database_url"].replace("dm_staging_runtime:", "postgres:")
    with pytest.raises(ValueError, match="Staging project/TLS configuration is invalid"):
        validate_admin_url(admin, "abcdefghijklmnopqrst")


@pytest.mark.parametrize(
    "scenario", ["port_default", "multiple_hosts", "database_default", "role_options"]
)
def test_connection_review_rejects_implicit_and_multiple_destinations(
    monkeypatch: pytest.MonkeyPatch, scenario: str
) -> None:
    values = hosted()
    if scenario == "port_default":
        values["database_url"] = values["database_url"].replace(":5432/postgres", "/postgres")
        monkeypatch.setenv("PGPORT", "6543")
    elif scenario == "multiple_hosts":
        values["database_url"] = (
            values["database_url"]
            .replace(
                "db.abcdefghijklmnopqrst.supabase.co",
                "unrelated.example.test,aws-0-ap-south-1.pooler.supabase.com",
            )
            .replace("dm_staging_runtime:", "dm_staging_runtime.abcdefghijklmnopqrst:")
        )
    elif scenario == "database_default":
        values["database_url"] = values["database_url"].replace("/postgres?", "/?")
        monkeypatch.setenv("PGDATABASE", "unintended_database")
    else:
        monkeypatch.setenv("PGOPTIONS", "-c role=unintended_role")
    with pytest.raises(HTTPException) as error:
        Settings(**values).validate_hosted()
    assert error.value.detail == {"code": "service_not_configured"}
    assert "synthetic" not in str(error.value)
    admin = values["database_url"].replace("dm_staging_runtime", "postgres")
    with pytest.raises(ValueError, match="Staging project/TLS configuration is invalid"):
        validate_admin_url(admin, "abcdefghijklmnopqrst")


def test_explicit_port_takes_precedence_over_unused_environment_default(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("PGPORT", "6543")
    values = hosted()
    Settings(**values).validate_hosted()
    validate_admin_url(
        values["database_url"].replace("dm_staging_runtime:", "postgres:"), "abcdefghijklmnopqrst"
    )
    engine = create_engine(values["database_url"])
    try:
        _, arguments = engine.dialect.create_connect_args(engine.url)
        assert arguments["port"] == 5432
    finally:
        engine.dispose()


def test_implicit_port_without_environment_override_is_accepted(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.delenv("PGPORT", raising=False)
    values = hosted()
    values["database_url"] = values["database_url"].replace(":5432/postgres", "/postgres")
    Settings(**values).validate_hosted()
    validate_admin_url(
        values["database_url"].replace("dm_staging_runtime:", "postgres:"), "abcdefghijklmnopqrst"
    )


def test_provision_staging_is_repeatable_and_probe_rolls_back(
    database: Engine, admin_engine: Engine, owner: UUID
) -> None:
    password = "synthetic-staging-runtime-password-'quoted'-32-characters"
    with admin_engine.begin() as connection:
        connection.execute(text("DROP SCHEMA training CASCADE"))
        connection.execute(text("DROP TABLE public.alembic_version"))
    provision(admin_engine, password)
    # Repeated preparation applies no destructive migration or duplicate account.
    provision(admin_engine, password)
    runtime = create_engine(admin_engine.url.set(username=ROLE, password=password))
    try:
        report = verify_isolation(runtime)
        assert report["migration_revision"] == "0003"
        assert report["training_tables"] == 11
        assert report["probe_rolled_back"] is True
        with admin_engine.connect() as connection:
            assert connection.scalar(text("SELECT count(*) FROM training.owner_state")) == 0
    finally:
        runtime.dispose()
        with admin_engine.begin() as connection:
            connection.execute(text("DROP OWNED BY dm_staging_runtime"))
            connection.execute(text("DROP ROLE dm_staging_runtime"))
            # The shared test fixture role's grants were removed with the schema.
            connection.execute(text("GRANT USAGE ON SCHEMA training TO dm_test_runtime"))
            connection.execute(
                text(
                    "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES "
                    "IN SCHEMA training TO dm_test_runtime"
                )
            )


@pytest.mark.parametrize("server_algorithm", ["md5", "scram-sha-256"])
def test_provision_sends_only_scram_verifiers_and_rotates_real_login(
    database: Engine, admin_engine: Engine, server_algorithm: str
) -> None:
    statements: list[str] = []

    class AuditCursor(psycopg.Cursor):
        def execute(self, query, params=None, **kwargs):
            # Observe the real driver boundary, then execute against PostgreSQL.
            rendered = (
                query.as_string(self.connection)
                if isinstance(query, psycopg.sql.Composable)
                else str(query)
            )
            if rendered.startswith(("CREATE ROLE", "ALTER ROLE")):
                statements.append(rendered)
            return super().execute(query, params, **kwargs)

    operator = create_engine(
        admin_engine.url,
        hide_parameters=True,
        connect_args={
            "cursor_factory": AuditCursor,
            "options": "-c password_encryption=" + server_algorithm,
        },
    )
    passwords = [
        "synthetic-first-password-'quoted'-32-characters",
        "synthetic-rotated-password-with-unicode-λ-32-characters",
    ]
    try:
        for password in passwords:
            provision(operator, password)
            runtime = create_engine(admin_engine.url.set(username=ROLE, password=password))
            try:
                assert verify_isolation(runtime)["owner_isolation"] is True
            finally:
                runtime.dispose()
        assert len(statements) == 2
        # Plaintext must never reach password DDL or its potential server logs.
        assert all(password not in statement for password in passwords for statement in statements)
        assert all("SCRAM-SHA-256$" in statement for statement in statements)
        with admin_engine.connect() as connection:
            stored = connection.scalar(
                text("SELECT rolpassword FROM pg_authid WHERE rolname=:role"), {"role": ROLE}
            )
            assert stored.startswith("SCRAM-SHA-256$")
        stale = create_engine(admin_engine.url.set(username=ROLE, password=passwords[0]))
        try:
            with pytest.raises(psycopg.OperationalError):
                # Raw connect proves the replaced credential is rejected, without
                # SQLAlchemy wrapping a credential-bearing URL in an exception.
                psycopg.connect(
                    host=stale.url.host,
                    port=stale.url.port,
                    dbname=stale.url.database,
                    user=ROLE,
                    password=passwords[0],
                )
        finally:
            stale.dispose()
    finally:
        operator.dispose()
        with admin_engine.begin() as connection:
            connection.execute(text("DROP OWNED BY " + ROLE))
            connection.execute(text("DROP ROLE " + ROLE))


def test_readiness_uses_runtime_role_and_does_not_mutate_accounts(
    database: Engine, admin_engine: Engine, owner: UUID
) -> None:
    with admin_engine.begin() as connection:
        connection.execute(text("GRANT SELECT ON public.alembic_version TO dm_test_runtime"))
    client = TestClient(app)
    response = client.get("/readyz")
    assert response.status_code == 200
    assert response.json() == {"status": "ready"}
    with admin_engine.begin() as connection:
        assert connection.scalar(text("SELECT count(*) FROM training.owner_state")) == 1
        connection.execute(text("REVOKE SELECT ON public.alembic_version FROM dm_test_runtime"))
    response = client.get("/readyz")
    assert response.status_code == 503
    assert response.json() == {"detail": {"code": "database_unavailable"}}


@pytest.mark.parametrize("fault", ["revision", "grant"])
def test_runtime_probe_checks_actual_migration_metadata(
    database: Engine, admin_engine: Engine, fault: str
) -> None:
    password = "synthetic-runtime-metadata-probe-password-32-characters"
    provision(admin_engine, password)
    runtime = create_engine(admin_engine.url.set(username=ROLE, password=password))
    try:
        with admin_engine.begin() as connection:
            if fault == "revision":
                connection.execute(text("UPDATE public.alembic_version SET version_num='0002'"))
            else:
                connection.execute(text("REVOKE SELECT ON public.alembic_version FROM " + ROLE))
        with pytest.raises(ValueError, match="migration metadata"):
            verify_isolation(runtime)
        with admin_engine.connect() as connection:
            assert connection.scalar(text("SELECT count(*) FROM training.owner_state")) == 0
    finally:
        runtime.dispose()
        with admin_engine.begin() as connection:
            connection.execute(text("UPDATE public.alembic_version SET version_num='0003'"))
            connection.execute(text("DROP OWNED BY " + ROLE))
            connection.execute(text("DROP ROLE " + ROLE))


def test_provision_grants_metadata_access_with_restricted_public_schema(
    database: Engine, admin_engine: Engine
) -> None:
    password = "synthetic-runtime-schema-probe-password-32-characters"
    with admin_engine.begin() as connection:
        connection.execute(text("REVOKE USAGE ON SCHEMA public FROM PUBLIC"))
    runtime = None
    try:
        provision(admin_engine, password)
        runtime = create_engine(admin_engine.url.set(username=ROLE, password=password))
        with runtime.connect() as connection:
            assert (
                connection.scalar(text("SELECT version_num FROM public.alembic_version")) == "0003"
            )
    finally:
        if runtime is not None:
            runtime.dispose()
        with admin_engine.begin() as connection:
            connection.execute(text("GRANT USAGE ON SCHEMA public TO PUBLIC"))
            connection.execute(text("DROP OWNED BY " + ROLE))
            connection.execute(text("DROP ROLE " + ROLE))


def test_database_error_response_does_not_log_or_return_sql_payload(
    monkeypatch: pytest.MonkeyPatch, caplog: pytest.LogCaptureFixture
) -> None:
    from sqlalchemy.exc import OperationalError

    def failure() -> None:
        raise OperationalError(
            "SELECT private_workout",
            {"password": "synthetic-do-not-log"},
            Exception("synthetic-secret"),
        )

    monkeypatch.setattr(main, "database_readiness", failure)
    monkeypatch.setenv("DM_ENVIRONMENT", "test")
    settings.cache_clear()
    try:
        response = TestClient(app).get("/readyz")
        assert response.status_code == 503
        assert "synthetic" not in response.text + caplog.text
        assert "private_workout" not in response.text + caplog.text
    finally:
        settings.cache_clear()


@pytest.mark.parametrize(
    "scenario", ["migration", "grant", "createdb", "createrole", "replication"]
)
def test_readiness_rejects_incomplete_or_privileged_deployment(
    database: Engine, admin_engine: Engine, owner: UUID, scenario: str
) -> None:
    with admin_engine.begin() as connection:
        connection.execute(text("GRANT SELECT ON public.alembic_version TO dm_test_runtime"))
        if scenario == "migration":
            connection.execute(text("UPDATE public.alembic_version SET version_num='0002'"))
        elif scenario == "grant":
            connection.execute(text("REVOKE UPDATE ON training.workouts FROM dm_test_runtime"))
        else:
            connection.execute(text("ALTER ROLE dm_test_runtime " + scenario.upper()))
    try:
        response = TestClient(app).get("/readyz")
        assert response.status_code == 503
        assert response.json() == {"detail": {"code": "service_not_configured"}}
    finally:
        with admin_engine.begin() as connection:
            connection.execute(text("UPDATE public.alembic_version SET version_num='0003'"))
            connection.execute(text("GRANT UPDATE ON training.workouts TO dm_test_runtime"))
            connection.execute(
                text("ALTER ROLE dm_test_runtime NOCREATEDB NOCREATEROLE NOREPLICATION")
            )
            connection.execute(text("REVOKE SELECT ON public.alembic_version FROM dm_test_runtime"))


def test_domain_database_error_is_sanitized_without_exception_logging(
    monkeypatch: pytest.MonkeyPatch, caplog: pytest.LogCaptureFixture
) -> None:
    from uuid import uuid4

    from sqlalchemy.exc import OperationalError

    from daily_motion.auth import verified_owner

    def failure(owner: UUID) -> None:
        raise OperationalError(
            "SELECT private_payload",
            {"secret": "synthetic-hidden-token"},
            Exception("synthetic-password"),
        )

    monkeypatch.setattr(main, "me", failure)
    app.dependency_overrides[verified_owner] = uuid4
    try:
        response = TestClient(app).get("/v1/me")
        assert response.status_code == 503
        assert response.json() == {"detail": {"code": "database_unavailable"}}
        assert "synthetic" not in response.text + caplog.text
        assert "private_payload" not in response.text + caplog.text
    finally:
        app.dependency_overrides.pop(verified_owner, None)
