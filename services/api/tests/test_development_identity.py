from pathlib import Path

import pytest

from scripts import development_identity

LOCAL = "postgresql+psycopg://fixture:synthetic-only@localhost/daily_motion"


@pytest.fixture(autouse=True)
def isolate_setup(monkeypatch: pytest.MonkeyPatch) -> None:
    for name in ("PGHOSTADDR", "PGSERVICE", "PGSERVICEFILE", "PGPORT", "PGOPTIONS"):
        monkeypatch.delenv(name, raising=False)
    monkeypatch.setattr("sys.argv", ["development_identity.py"])

    def forbidden_setup(*args: object, **kwargs: object) -> None:
        pytest.fail("Unsafe development target reached file creation or database setup")

    monkeypatch.setattr(Path, "mkdir", forbidden_setup)
    monkeypatch.setattr(development_identity.command, "upgrade", forbidden_setup)
    monkeypatch.setattr(development_identity, "create_engine", forbidden_setup)


@pytest.mark.parametrize(
    "query",
    [
        "host=remote.example.test",
        "hostaddr=192.0.2.10",
        "dbname=other_database",
        "user=other_role",
        "service=other_project",
        "options=-crole=postgres",
        "port=5433",
    ],
)
def test_development_query_overrides_fail_before_setup(
    monkeypatch: pytest.MonkeyPatch, query: str
) -> None:
    monkeypatch.setenv("DM_DEV_ADMIN_URL", LOCAL + "?" + query)
    with pytest.raises(ValueError, match="Development setup requires") as error:
        development_identity.main()
    assert "synthetic-only" not in str(error.value)
    assert query not in str(error.value)


@pytest.mark.parametrize(
    "name", ["PGHOSTADDR", "PGSERVICE", "PGSERVICEFILE", "PGPORT", "PGOPTIONS"]
)
def test_development_ambient_overrides_fail_before_setup(
    monkeypatch: pytest.MonkeyPatch, name: str
) -> None:
    monkeypatch.setenv("DM_DEV_ADMIN_URL", LOCAL)
    monkeypatch.setenv(name, "synthetic-routing-override")
    with pytest.raises(ValueError, match="Development setup requires") as error:
        development_identity.main()
    assert "synthetic-routing-override" not in str(error.value)


@pytest.mark.parametrize(
    "target",
    [
        "postgresql+psycopg://fixture:synthetic-only@localhost:invalid/daily_motion",
        LOCAL.replace("postgresql+psycopg", "postgresql"),
        LOCAL.replace("/daily_motion", "/postgres"),
        LOCAL.replace("localhost", "remote.example.test"),
    ],
)
def test_invalid_development_target_fails_without_echoing_input(
    monkeypatch: pytest.MonkeyPatch, target: str
) -> None:
    monkeypatch.setenv("DM_DEV_ADMIN_URL", target)
    with pytest.raises(ValueError, match="Development setup requires") as error:
        development_identity.main()
    assert "synthetic-only" not in str(error.value)
    assert target not in str(error.value)


class SetupBoundaryReached(Exception):
    pass


@pytest.mark.parametrize(
    ("host", "port_override"),
    [("localhost", ""), ("127.0.0.1:25432", ""), ("[::1]:5432", ""), ("127.0.0.1:25432", "6543")],
)
def test_clean_development_target_reaches_only_setup_boundary(
    monkeypatch: pytest.MonkeyPatch, host: str, port_override: str
) -> None:
    monkeypatch.setenv("DM_DEV_ADMIN_URL", LOCAL.replace("localhost", host))
    if port_override:
        monkeypatch.setenv("PGPORT", port_override)

    def stop_at_boundary(*args: object, **kwargs: object) -> None:
        raise SetupBoundaryReached()

    monkeypatch.setattr(Path, "mkdir", stop_at_boundary)
    with pytest.raises(SetupBoundaryReached):
        development_identity.main()
