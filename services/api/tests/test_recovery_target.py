import pytest

from tests.recovery_lab import RecoveryLab, local_docker_endpoint


@pytest.mark.parametrize("name", ["PGHOSTADDR", "PGSERVICE", "PGSERVICEFILE", "PGOPTIONS"])
def test_recovery_rejects_libpq_overrides_before_docker(
    name: str, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv(name, "synthetic-unsafe-override")
    with pytest.raises(RuntimeError, match="libpq routing"):
        RecoveryLab()


@pytest.mark.parametrize(
    "endpoint",
    [
        "tcp://127.0.0.1:2375",
        "tcp://remote:2376",
        "ssh://operator@example.test",
        "unix:///tmp/unknown.sock",
        "npipe:////remote/pipe/docker_engine",
        "",
    ],
)
def test_recovery_rejects_unqualified_daemons(endpoint: str) -> None:
    with pytest.raises(RuntimeError, match="local Docker socket"):
        local_docker_endpoint(endpoint)


@pytest.mark.parametrize(
    "endpoint",
    [
        "npipe:////./pipe/dockerDesktopLinuxEngine",
        "unix:///var/run/docker.sock",
        "unix:///run/user/1000/docker.sock",
    ],
)
def test_recovery_accepts_explicit_local_sockets(endpoint: str) -> None:
    assert local_docker_endpoint(endpoint) == endpoint
