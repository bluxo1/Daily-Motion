import pytest

from tests import conftest
from tests.database_target import validate_local_test_target


@pytest.fixture(autouse=True)
def clear_routing_overrides(monkeypatch: pytest.MonkeyPatch) -> None:
    for name in ("PGHOSTADDR", "PGSERVICE", "PGSERVICEFILE", "PGPORT", "PGOPTIONS"):
        monkeypatch.delenv(name, raising=False)


@pytest.mark.parametrize(
    ("target", "hostaddr"),
    [
        pytest.param(
            "postgresql+psycopg://fixture:synthetic-only@remote.example.test/daily_motion_test",
            "",
            id="remote-host",
        ),
        pytest.param(
            "postgresql+psycopg://fixture:synthetic-only@localhost/postgres"
            "?application_name=/daily_motion_test",
            "",
            id="database-name-in-query-suffix",
        ),
        pytest.param(
            "postgresql+psycopg://fixture:synthetic-only@localhost/daily_motion_test",
            "192.0.2.10",
            id="ambient-remote-hostaddr",
        ),
    ],
)
def test_fixture_rejects_unsafe_target_before_creating_engine(
    monkeypatch: pytest.MonkeyPatch, target: str, hostaddr: str
) -> None:
    monkeypatch.setenv("DM_TEST_ADMIN_URL", target)
    monkeypatch.setenv("PGHOSTADDR", hostaddr)

    def forbidden_engine(*args: object, **kwargs: object) -> None:
        pytest.fail("Unsafe database target reached engine construction")

    monkeypatch.setattr(conftest, "create_engine", forbidden_engine)
    fixture = conftest.admin_engine.__wrapped__()
    with pytest.raises(RuntimeError) as error:
        next(fixture)
    assert "synthetic-only" not in str(error.value)


@pytest.mark.parametrize("host", ["localhost", "127.0.0.1:25432", "[::1]:5432"])
def test_local_postgres_target_is_accepted(host: str) -> None:
    validate_local_test_target(
        f"postgresql+psycopg://fixture:synthetic-only@{host}/daily_motion_test"
    )


@pytest.mark.parametrize(
    "target",
    [
        "not-a-url-synthetic-only",
        "postgresql+psycopg://fixture:synthetic-only@localhost:invalid/daily_motion_test",
        "sqlite:///daily_motion_test",
        "postgresql://fixture:synthetic-only@localhost/daily_motion_test",
        "postgresql+psycopg://fixture:synthetic-only@localhost/postgres",
        "postgresql+psycopg://fixture:synthetic-only@localhost/daily_motion_test"
        "?host=remote.example.test&application_name=/daily_motion_test",
        "postgresql+psycopg://fixture:synthetic-only@localhost/daily_motion_test"
        "?hostaddr=192.0.2.10",
        "postgresql+psycopg://fixture:synthetic-only@localhost/daily_motion_test?service=remote",
        "postgresql+psycopg://fixture:synthetic-only@localhost/daily_motion_test?port=5433",
        "postgresql+psycopg://fixture:synthetic-only@127.0.0.1.example.test/daily_motion_test",
    ],
)
def test_invalid_and_redirected_targets_fail_without_echoing_url(target: str) -> None:
    with pytest.raises(RuntimeError) as error:
        validate_local_test_target(target)
    assert "synthetic-only" not in str(error.value)
    assert target not in str(error.value)


@pytest.mark.parametrize("name", ["PGHOSTADDR", "PGSERVICE", "PGSERVICEFILE"])
def test_libpq_routing_overrides_are_rejected(monkeypatch: pytest.MonkeyPatch, name: str) -> None:
    monkeypatch.setenv(name, "synthetic-routing-override")
    with pytest.raises(RuntimeError) as error:
        validate_local_test_target(
            "postgresql+psycopg://fixture:synthetic-only@localhost/daily_motion_test"
        )
    assert "synthetic-routing-override" not in str(error.value)


@pytest.mark.parametrize(
    ("name", "value"), [("PGPORT", "6543"), ("PGOPTIONS", "-c role=other_role")]
)
def test_fixture_rejects_implicit_port_and_role_before_engine_creation(
    monkeypatch: pytest.MonkeyPatch, name: str, value: str
) -> None:
    monkeypatch.setenv(
        "DM_TEST_ADMIN_URL",
        "postgresql+psycopg://fixture:synthetic-only@localhost/daily_motion_test",
    )
    monkeypatch.setenv(name, value)

    def forbidden_engine(*args: object, **kwargs: object) -> None:
        pytest.fail("Implicit destination or role reached engine construction")

    monkeypatch.setattr(conftest, "create_engine", forbidden_engine)
    with pytest.raises(RuntimeError):
        next(conftest.admin_engine.__wrapped__())
