"""No provider calls or real recipients: qualify the private operator boundary."""

import importlib.util
import json
from io import BytesIO
from pathlib import Path
from types import ModuleType, SimpleNamespace
from typing import Any

import pytest


@pytest.fixture
def bridge() -> ModuleType:
    path = Path(__file__).parents[3] / "tools/auth_security/operator_bridge.py"
    spec = importlib.util.spec_from_file_location("auth_operator_bridge", path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def call(
    bridge: ModuleType,
    path: str,
    data: dict[str, Any] | None = None,
    *,
    method: str = "GET",
    headers: dict[str, str] | None = None,
) -> tuple[int, dict[str, Any]]:
    body = json.dumps(data).encode() if data is not None else b""
    handler = object.__new__(bridge.Handler)
    handler.server = SimpleNamespace(server_port=12345)
    handler.headers = {
        "Host": "127.0.0.1:12345",
        "X-DM-Qualification": "phase0-local",
        "Content-Length": str(len(body)),
        **(headers or {}),
    }
    handler.command = method
    handler.path = path
    handler.rfile = BytesIO(body)
    responses: list[tuple[int, dict[str, Any]]] = []
    handler.respond = lambda payload, status=200: responses.append((status, payload))
    bridge.server = handler.server
    handler.run_request()
    return responses[0]


def test_diagnostics_never_return_raw_session_output(bridge: ModuleType) -> None:
    marker = "synthetic-non-jwt-refresh-material"
    bridge.state["output"] = marker
    status, response = call(bridge, "/diagnostic")
    assert status == 200
    assert marker not in json.dumps(response)


@pytest.mark.parametrize(
    "headers,status",
    [
        ({"X-DM-Qualification": "missing"}, 403),
        ({"Host": "untrusted.example.test"}, 403),
        ({"Origin": "https://untrusted.example.test"}, 403),
        ({"Content-Length": "4097"}, 413),
    ],
)
def test_bridge_rejects_untrusted_origin_host_header_and_capacity(
    bridge: ModuleType, headers: dict[str, str], status: int
) -> None:
    assert call(bridge, "/status", headers=headers)[0] == status


def test_failure_parser_emits_only_allowlisted_metadata(bridge: ModuleType) -> None:
    marker = "synthetic-non-jwt-refresh-material"
    result = bridge.failure_summary(
        f"Hosted verification failed: invalid_or_expired_code {marker}",
        [{"account": "A", "submitted": True}],
    )
    assert result == {
        "stage": "verification",
        "category": "invalid_or_expired_code",
        "account": "A",
        "step": 1,
    }
    assert marker not in json.dumps(result)


@pytest.mark.parametrize("path", ["/start", "/code", "/event", "/shutdown"])
def test_mutations_require_post(bridge: ModuleType, path: str) -> None:
    assert call(bridge, path)[0] == 405


def test_challenges_are_single_use_and_bound_to_three_account_steps(bridge: ModuleType) -> None:
    bridge.addresses = {"A": "a@example.test", "B": "b@example.test"}
    for index, account in enumerate(("A", "B", "A"), start=1):
        status, response = call(
            bridge,
            "/challenge",
            {"account": account, "requested_at": "2026-10-19T00:00:00Z"},
            method="POST",
        )
        assert status == 200
        assert response == {"id": index}
        submission = {"id": index, "code": "123456"}
        assert call(bridge, "/code", submission, method="POST")[0] == 200
        assert call(bridge, "/code", submission, method="POST")[0] == 400
        assert call(bridge, f"/code/{index}")[1]["code"] == "123456"
        assert call(bridge, f"/code/{index}")[1]["code"] is None
    assert (
        call(
            bridge,
            "/challenge",
            {"account": "B", "requested_at": "2026-10-19T00:00:00Z"},
            method="POST",
        )[0]
        == 409
    )


def test_wrong_account_or_overlapping_challenge_is_rejected(bridge: ModuleType) -> None:
    bridge.addresses = {"A": "a@example.test", "B": "b@example.test"}
    for account, status in (("B", 409), ("A", 200), ("B", 409)):
        assert (
            call(
                bridge,
                "/challenge",
                {"account": account, "requested_at": "2026-10-19T00:00:00Z"},
                method="POST",
            )[0]
            == status
        )


def test_launch_uses_own_worktree_and_retains_only_safe_failure(
    bridge: ModuleType, monkeypatch: pytest.MonkeyPatch
) -> None:
    marker = "synthetic-non-jwt-refresh-material"
    launches = []

    def run(command: list[str], **kwargs: Any) -> SimpleNamespace:
        launches.append((command, kwargs))
        return SimpleNamespace(
            returncode=1,
            stdout=f"Hosted verification failed: invalid_or_expired_code {marker}",
            stderr="",
        )

    monkeypatch.setattr(bridge.subprocess, "run", run)
    monkeypatch.setenv("DM_DATABASE_URL", "synthetic-server-secret")
    bridge.server = SimpleNamespace(server_port=12345)
    bridge.launch("lifecycle")
    command, options = launches[0]
    assert options["cwd"] == Path(__file__).parents[3] / "apps/mobile"
    assert "test/hosted_auth_lifecycle_test.dart" in command
    assert "--no-pub" in command
    assert options["env"]["DM_HOSTED_AUTH_LIFECYCLE"] == "1"
    assert "DM_DATABASE_URL" not in options["env"]
    assert bridge.state["running"] is False
    assert marker not in json.dumps(bridge.state)
    assert bridge.state["failure"]["category"] == "invalid_or_expired_code"


@pytest.mark.parametrize(
    "scenario", ["valid", "extra_key", "wrong_project", "wrong_api", "same_recipient", "wrong_key"]
)
def test_private_inputs_are_only_expected_staging_client_configuration(
    bridge: ModuleType, monkeypatch: pytest.MonkeyPatch, tmp_path: Path, scenario: str
) -> None:
    monkeypatch.setattr(bridge, "root", tmp_path)
    private = tmp_path / ".tools/staging"
    private.mkdir(parents=True)
    configuration = {
        "DM_ENVIRONMENT": "staging",
        "DM_SUPABASE_URL": "https://pulruylvpehwftwqcvct.supabase.co",
        "DM_SUPABASE_PUBLISHABLE_KEY": "sb_publishable_synthetic",
        "DM_API_URL": "https://daily-motion-staging-api.onrender.com",
    }
    recipients = {"A": "a@example.test", "B": "b@example.test"}
    if scenario == "extra_key":
        configuration["DM_ACCESS_TOKEN"] = "synthetic-user-secret"
    elif scenario == "wrong_project":
        configuration["DM_SUPABASE_URL"] = "https://other.supabase.co"
    elif scenario == "wrong_api":
        configuration["DM_API_URL"] = "https://other.example.test"
    elif scenario == "same_recipient":
        recipients["B"] = recipients["A"]
    elif scenario == "wrong_key":
        configuration["DM_SUPABASE_PUBLISHABLE_KEY"] = "synthetic-privileged-key"
    (private / "mobile.json").write_text(json.dumps(configuration), encoding="utf-8")
    (private / "otp_request_probe.py").write_text(f"emails = {recipients!r}", encoding="utf-8")
    if scenario == "valid":
        assert bridge.private_inputs() == (recipients, configuration)
    else:
        with pytest.raises(ValueError):
            bridge.private_inputs()


def test_failed_process_launch_stops_without_exception_or_raw_diagnostics(
    bridge: ModuleType, monkeypatch: pytest.MonkeyPatch
) -> None:
    marker = "synthetic-private-process-error"

    def fail(*args: Any, **kwargs: Any) -> None:
        raise OSError(marker)

    monkeypatch.setattr(bridge.subprocess, "run", fail)
    bridge.server = SimpleNamespace(server_port=12345)
    bridge.state["running"] = True
    bridge.launch("lifecycle")
    assert bridge.state["running"] is False
    assert bridge.state["passed"] is False
    assert bridge.state["failure"]["category"] == "unclassified_failure"
    assert marker not in json.dumps(bridge.state)


@pytest.mark.parametrize(
    "scenario",
    [
        "complete",
        "skipped",
        "no_checkpoints",
        "missing_checkpoint",
        "out_of_order_checkpoint",
        "extra_checkpoint",
        "missing_challenge",
        "wrong_challenge_account",
        "wrong_challenge_id",
        "unsubmitted_challenge",
        "unconsumed_code",
        "nonzero_exit",
    ],
)
def test_process_success_requires_full_ordered_and_consumed_lifecycle(
    bridge: ModuleType, monkeypatch: pytest.MonkeyPatch, scenario: str
) -> None:
    # Independent fixture names bind the operator's PASS to the documented flow.
    events = [
        "a_verified",
        "sdk_refresh_passed",
        "retry_receipt_replay_passed",
        "controller_file_restart_passed",
        "remote_sign_out_pending_and_revocation_passed",
        "b_verified",
        "cross_owner_feed_and_mutation_denial_passed",
        "a_verified",
        "a_b_a_pending_recovery_and_hosted_bootstrap_passed",
    ]
    bridge.state.update(
        running=True,
        events=[{"event": event} for event in events],
        challenges=[
            {"id": index, "account": account, "submitted": True}
            for index, account in enumerate(("A", "B", "A"), 1)
        ],
    )
    if scenario in ("skipped", "no_checkpoints"):
        bridge.state["events"] = []
        bridge.state["challenges"] = []
    elif scenario == "missing_checkpoint":
        bridge.state["events"].pop()
    elif scenario == "out_of_order_checkpoint":
        bridge.state["events"].reverse()
    elif scenario == "extra_checkpoint":
        bridge.state["events"].append({"event": "a_verified"})
    elif scenario == "missing_challenge":
        bridge.state["challenges"].pop()
    elif scenario == "wrong_challenge_account":
        bridge.state["challenges"][2]["account"] = "B"
    elif scenario == "wrong_challenge_id":
        bridge.state["challenges"][2]["id"] = 2
    elif scenario == "unsubmitted_challenge":
        bridge.state["challenges"][2]["submitted"] = False
    elif scenario == "unconsumed_code":
        bridge.state["codes"][3] = "123456"

    marker = "synthetic-private-process-output"
    monkeypatch.setattr(
        bridge.subprocess,
        "run",
        lambda *args, **kwargs: SimpleNamespace(
            returncode=1 if scenario == "nonzero_exit" else 0,
            stdout="All tests skipped." if scenario == "skipped" else marker,
            stderr="",
        ),
    )
    bridge.server = SimpleNamespace(server_port=12345)
    bridge.launch("lifecycle")

    assert bridge.state["running"] is False
    assert bridge.state["passed"] is (scenario == "complete")
    if scenario == "complete":
        assert bridge.state["failure"] is None
    else:
        assert bridge.state["failure"]["category"] == (
            "unclassified_failure" if scenario == "nonzero_exit" else "qualification_incomplete"
        )
    assert marker not in json.dumps(bridge.state)
