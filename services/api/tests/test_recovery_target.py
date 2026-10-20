import json
import subprocess

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


@pytest.mark.parametrize(
    "binding",
    [
        None,
        [],
        [{"HostIp": "0.0.0.0", "HostPort": "1234"}],
        [{"HostIp": "127.0.0.1", "HostPort": "1235"}],
    ],
)
def test_recovery_refuses_missing_changed_or_public_binding(
    binding: object, monkeypatch: pytest.MonkeyPatch
) -> None:
    lab = RecoveryLab.__new__(RecoveryLab)
    lab.container, lab.port = "a" * 64, 1234
    monkeypatch.setattr(
        lab,
        "checked",
        lambda *args: json.dumps([{"NetworkSettings": {"Ports": {"5432/tcp": binding}}}]).encode(),
    )
    with pytest.raises(RuntimeError, match="binding changed"):
        lab.assert_binding()


def test_recovery_startup_failure_keeps_owned_resources_cleanable(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    lab = RecoveryLab.__new__(RecoveryLab)
    lab.container, lab.volume, lab.port, lab.label = "", "", 0, "synthetic-lab"
    calls = []

    def checked(*args: str, **kwargs: object) -> bytes:
        calls.append(args)
        if args[0] == "image":
            return b"sha256:synthetic-image"
        if args[0] == "create":
            publish = args[args.index("--publish") + 1]
            assert publish == f"127.0.0.1:{lab.port}:5432" and lab.port > 0
            return ("a" * 64).encode()
        if args[0] == "start":
            raise RuntimeError("Synthetic port collision")
        if args[0] == "inspect" and "--format" in args:
            return lab.label.encode()
        if args[0] == "inspect":
            return json.dumps(
                [
                    {
                        "Config": {"Labels": {"daily-motion.recovery": lab.label}},
                        "Mounts": [
                            {"Destination": "/var/lib/postgresql/data", "Name": "synthetic-volume"}
                        ],
                    }
                ]
            ).encode()
        assert args == ("rm", "--force", "--volumes", "a" * 64)
        return b""

    monkeypatch.setattr(lab, "checked", checked)
    monkeypatch.setattr(lab, "docker", lambda *args: subprocess.CompletedProcess(args, 1))
    with pytest.raises(RuntimeError, match="Synthetic port collision"):
        lab.start()
    assert lab.container == "a" * 64 and lab.volume == "synthetic-volume"
    lab.cleanup()
    assert calls[-1] == ("rm", "--force", "--volumes", "a" * 64)
