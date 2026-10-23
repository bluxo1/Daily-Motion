"""Run the actual Flutter HTTP client against verified JWTs and restricted PostgreSQL."""

import io
import json
import os
import shutil
import socket
import subprocess
import threading
import time
from datetime import UTC, datetime, timedelta
from pathlib import Path
from uuid import UUID, uuid4

import jwt
import pytest
import uvicorn
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec

from daily_motion import accounts
from daily_motion.config import settings
from daily_motion.main import app

CONNECTED_CASES = {
    "real signed JWT, restricted PostgreSQL upload, own echo and second-device bootstrap",
    "contract defaults and arbitrary supported IANA timezone survive real feed and snapshot",
    "real receipt after dropped committed response is exact and replay-safe",
    "real digest mismatch and exact duplicate results",
    "two real devices conflict without losing either branch",
    "real deletion retires pending branch, redacts feed and invalidates snapshot",
    "expired signed credentials pause cloud synchronization while logging continues",
    "real SQLite restart after delivered request recovers through real HTTP receipt/echo",
    (
        "account initialization and A to B to A recovery use real authenticated HTTP "
        "and separate SQLite stores"
    ),
}


def unique_json_object(pairs: list[tuple[str, object]]) -> dict[str, object]:
    value: dict[str, object] = {}
    for key, item in pairs:
        if key in value:
            raise ValueError("Duplicate JSON object key")
        value[key] = item
    return value


def connected_passed(output: str) -> bool:
    events = []
    for line in output.splitlines():
        if not line.strip():
            continue
        try:
            event = json.loads(line, object_pairs_hook=unique_json_object)
        except json.JSONDecodeError:
            # Flutter can print dependency progress before its machine stream.
            # Once events begin, malformed/trailing output cannot imply success.
            if events or line.lstrip().startswith(("{", "[")):
                return False
            continue
        except ValueError:
            # Reject duplicate keys at every depth without exposing their content.
            return False
        if events and events[-1].get("type") == "done":
            return False
        if (
            isinstance(event, list)
            and event
            and all(
                isinstance(item, dict)
                and set(item) == {"event", "params"}
                and item["event"] == "test.startedProcess"
                and isinstance(item["params"], dict)
                and set(item["params"]) == {"vmServiceUri"}
                and (
                    item["params"]["vmServiceUri"] is None
                    or isinstance(item["params"]["vmServiceUri"], str)
                )
                for item in event
            )
        ):
            continue
        if not isinstance(event, dict):
            return False
        events.append(event)
    if (
        not events
        or events[0].get("type") != "start"
        # Flutter 3.47.7's pinned test_core reporter emits protocol 0.1.1.
        # A different protocol requires an explicit compatibility review.
        or events[0].get("protocolVersion") != "0.1.1"
        or sum(event.get("type") == "start" for event in events) != 1
        or events[-1].get("type") != "done"
        or events[-1].get("success") is not True
        or sum(event.get("type") == "done" for event in events) != 1
    ):
        return False
    suites: dict[int, str] = {}
    started: dict[int, str] = {}
    completed: set[int] = set()
    passed: set[str] = set()
    suite_count: int | None = None
    try:
        for event in events:
            kind = event["type"]
            if kind == "suite":
                suite = event["suite"]
                identity = suite["id"]
                if type(identity) is not int or identity in suites:
                    return False
                filename = suite["path"].replace("\\", "/")
                if not filename.endswith("/apps/mobile/test/connected_http_test.dart"):
                    return False
                suites[identity] = filename
            elif kind == "testStart":
                test = event["test"]
                identity, suite_id, name = test["id"], test["suiteID"], test["name"]
                if (
                    type(identity) is not int
                    or identity in started
                    or type(suite_id) is not int
                    or suite_id not in suites
                    or not isinstance(name, str)
                    or not name
                ):
                    return False
                started[identity] = name
            elif kind == "testDone":
                identity = event["testID"]
                if (
                    type(identity) is not int
                    or identity not in started
                    or identity in completed
                    or event["skipped"] is not False
                    or event["result"] != "success"
                    or type(event["hidden"]) is not bool
                ):
                    return False
                completed.add(identity)
                if not event["hidden"]:
                    name = started[identity]
                    if name not in CONNECTED_CASES or name in passed:
                        return False
                    passed.add(name)
            elif kind == "allSuites":
                # Scheduling may finish before tests do. Compare only at the end.
                if suite_count is not None or type(event["count"]) is not int:
                    return False
                suite_count = event["count"]
            elif kind not in {"start", "group", "print", "debug", "done"}:
                return False
    except (KeyError, TypeError, AttributeError):
        return False
    return (
        len(suites) == 1
        and suite_count == len(suites)
        and completed == set(started)
        and passed == CONNECTED_CASES
    )


def assert_connected_result(result: subprocess.CompletedProcess[str]) -> None:
    assert result.returncode == 0, "Connected Flutter HTTP/PostgreSQL process failed"
    assert connected_passed(result.stdout), "Connected cases were skipped, failed or incomplete"


@pytest.fixture
def connected_events() -> list[dict]:
    names = [
        "real signed JWT, restricted PostgreSQL upload, own echo and second-device bootstrap",
        "contract defaults and arbitrary supported IANA timezone survive real feed and snapshot",
        "real receipt after dropped committed response is exact and replay-safe",
        "real digest mismatch and exact duplicate results",
        "two real devices conflict without losing either branch",
        "real deletion retires pending branch, redacts feed and invalidates snapshot",
        "expired signed credentials pause cloud synchronization while logging continues",
        "real SQLite restart after delivered request recovers through real HTTP receipt/echo",
        (
            "account initialization and A to B to A recovery use real authenticated HTTP "
            "and separate SQLite stores"
        ),
    ]
    events: list[dict] = [
        {"type": "start", "protocolVersion": "0.1.1"},
        {
            "type": "suite",
            "suite": {"id": 0, "path": "/owned/apps/mobile/test/connected_http_test.dart"},
        },
    ]
    # Real machine output includes a hidden loader completion as well as tests.
    for identity, name in enumerate(
        ["loading /owned/apps/mobile/test/connected_http_test.dart", *names]
    ):
        events.extend(
            [
                {"type": "testStart", "test": {"id": identity, "name": name, "suiteID": 0}},
                {
                    "type": "testDone",
                    "testID": identity,
                    "hidden": identity == 0,
                    "skipped": False,
                    "result": "success",
                },
            ]
        )
    events.extend([{"type": "allSuites", "count": 1}, {"type": "done", "success": True}])
    return events


@pytest.mark.parametrize(
    "fault",
    [
        None,
        "skip",
        "failure",
        "empty",
        "incomplete",
        "hidden",
        "wrong_name",
        "wrong_suite",
        "duplicate_completion",
        "duplicate_start",
        "duplicate_name",
        "missing_start",
        "unfinished_start",
        "unknown_completion",
        "hidden_failure",
        "hidden_skip",
        "error_event",
        "duplicate_done",
        "early_done",
        "trailing_error",
        "malformed_json",
        "unexpected_array",
        "missing_suite",
        "duplicate_suite",
        "bool_suite_id",
        "bool_test_id",
        "bool_completion_id",
        "bool_test_suite_id",
        "missing_hidden",
        "nonboolean_hidden",
        "missing_start_event",
        "duplicate_start_event",
        "non_event",
        "unknown_event",
        "malformed_daemon",
        "trailing_text",
    ],
)
def test_connected_report_cannot_claim_skipped_or_incomplete_success(
    fault: str | None, connected_events: list[dict]
) -> None:
    events = connected_events
    if fault == "skip":
        events[5]["skipped"] = True
    elif fault == "failure":
        events[5]["result"] = "error"
    elif fault == "empty":
        events = []
    elif fault == "incomplete":
        events.pop()
    elif fault == "hidden":
        events[5]["hidden"] = True
    elif fault == "wrong_name":
        events[4]["test"]["name"] = "unrelated passing case"
    elif fault == "wrong_suite":
        events[1]["suite"]["path"] = "/owned/apps/mobile/test/unrelated_test.dart"
    elif fault == "duplicate_completion":
        events[7] = events[5].copy()
    elif fault == "duplicate_start":
        events[6] = events[4].copy()
    elif fault == "duplicate_name":
        events[6]["test"]["name"] = events[4]["test"]["name"]
    elif fault == "missing_start":
        events.pop(4)
    elif fault == "unfinished_start":
        events.insert(
            -1, {"type": "testStart", "test": {"id": 50, "name": "unfinished", "suiteID": 0}}
        )
    elif fault == "unknown_completion":
        events[5]["testID"] = 50
    elif fault == "hidden_failure":
        events[3]["result"] = "error"
    elif fault == "hidden_skip":
        events[3]["skipped"] = True
    elif fault == "error_event":
        events.insert(-1, {"type": "error", "error": "synthetic error"})
    elif fault == "duplicate_done":
        events.insert(-1, {"type": "done", "success": True})
    elif fault == "early_done":
        events.insert(4, events.pop())
    elif fault == "trailing_error":
        events.append({"type": "error", "error": "synthetic error"})
    elif fault == "unexpected_array":
        events.insert(4, [{"type": "testDone", "result": "error"}])
    elif fault == "missing_suite":
        events.pop(1)
    elif fault == "duplicate_suite":
        events.insert(2, events[1].copy())
    elif fault == "bool_suite_id":
        events[1]["suite"]["id"] = False
    elif fault == "bool_test_id":
        events[4]["test"]["id"] = True
    elif fault == "bool_completion_id":
        events[5]["testID"] = True
    elif fault == "bool_test_suite_id":
        events[4]["test"]["suiteID"] = False
    elif fault == "missing_hidden":
        del events[3]["hidden"]
    elif fault == "nonboolean_hidden":
        events[3]["hidden"] = "true"
    elif fault == "missing_start_event":
        events.pop(0)
    elif fault == "duplicate_start_event":
        events.insert(1, events[0].copy())
    elif fault == "non_event":
        events.insert(4, {})
    elif fault == "unknown_event":
        events.insert(4, {"type": "testOmitted"})
    elif fault == "malformed_daemon":
        events.insert(4, [{"event": "test.startedProcess", "params": {"vmServiceUri": 17}}])
    output = "Resolving dependencies...\n" + "\n".join(json.dumps(event) for event in events)
    if fault == "malformed_json":
        output = output.replace('"type": "testStart"', '"type": ', 1)
    elif fault == "trailing_text":
        output += "\nUnhandled test failure"
    else:
        # Supported Flutter daemon messages are auxiliary, not test results.
        output = output.replace(
            '\n{"type": "suite"',
            '\n[{"event":"test.startedProcess","params":{"vmServiceUri":null}}]\n{"type": "suite"',
            1,
        )
    assert connected_passed(output) is (fault is None)


@pytest.mark.parametrize(
    "variant",
    ["windows_path", "interleaved", "auxiliary", "daemon_uri", "summary_before_suite"],
)
def test_connected_report_accepts_supported_machine_shapes(
    variant: str, connected_events: list[dict]
) -> None:
    events = connected_events
    if variant == "windows_path":
        events[1]["suite"]["path"] = r"E:\owned\apps\mobile\test\connected_http_test.dart"
    elif variant == "interleaved":
        # Parallel completion order need not match registration order.
        events = (
            events[:2]
            + [event for event in events[2:-1] if event["type"] == "testStart"]
            + [event for event in reversed(events[2:-1]) if event["type"] == "testDone"]
            + events[-2:]
        )
    elif variant == "auxiliary":
        events.insert(4, {"type": "print", "testID": 0, "message": "synthetic diagnostic"})
        events.insert(4, {"type": "group", "group": {"id": 0, "suiteID": 0}})
        events.insert(4, events.pop(-2))
        events.insert(4, {"type": "debug", "suiteID": 0})
    elif variant == "summary_before_suite":
        events.insert(1, events.pop(-2))
    output = "\n".join(json.dumps(event) for event in events)
    if variant == "daemon_uri":
        output = output.replace(
            '\n{"type": "suite"',
            '\n[{"event":"test.startedProcess",'
            '"params":{"vmServiceUri":"http://127.0.0.1:1234/"}}]\n{"type": "suite"',
            1,
        )
    assert connected_passed(output)


@pytest.mark.parametrize(
    ("original", "ambiguous"),
    [
        ('"success": true', '"success": false, "success": true'),
        ('"result": "success"', '"result": "error", "result": "success"'),
        ('"skipped": false', '"skipped": true, "skipped": false'),
        ('"type": "testDone"', '"type": "error", "type": "testDone"'),
        (
            '"path": "/owned/apps/mobile/test/connected_http_test.dart"',
            '"path": "/unrelated.dart", "path": "/owned/apps/mobile/test/connected_http_test.dart"',
        ),
        ('"suiteID": 0', '"suiteID": 50, "suiteID": 0'),
        ('"success": true', '"success": true, "success": true'),
        ('"success": true', r'"success": false, "\u0073uccess": true'),
    ],
    ids=["success", "result", "skipped", "type", "nested_suite", "nested_test", "same", "escaped"],
)
def test_connected_report_rejects_duplicate_keys(
    original: str, ambiguous: str, connected_events: list[dict]
) -> None:
    output = "\n".join(json.dumps(event) for event in connected_events)
    assert original in output
    assert not connected_passed(output.replace(original, ambiguous, 1))


@pytest.mark.parametrize(
    "ambiguous",
    [
        '{"type":"print","message":{"nested":{"value":1,"value":2}}}',
        '[{"event":"test.startedProcess","params":{"vmServiceUri":null,"vmServiceUri":null}}]',
    ],
    ids=["nested_diagnostic", "nested_daemon"],
)
def test_connected_report_rejects_duplicate_keys_in_auxiliary_objects(
    ambiguous: str, connected_events: list[dict]
) -> None:
    lines = [json.dumps(event) for event in connected_events]
    lines.insert(1, ambiguous)
    assert not connected_passed("\n".join(lines))


@pytest.mark.parametrize(
    "fault",
    ["missing", "duplicate", "missing_count", 0, 2, -1, True, False, None, 1.0, "1", [], {}],
    ids=[
        "missing",
        "duplicate",
        "missing_count",
        "zero",
        "two",
        "negative",
        "true",
        "false",
        "null",
        "float",
        "string",
        "array",
        "object",
    ],
)
def test_connected_report_requires_consistent_suite_summary(
    fault: object, connected_events: list[dict]
) -> None:
    if fault == "missing":
        connected_events.pop(-2)
    elif fault == "duplicate":
        connected_events.insert(-1, connected_events[-2].copy())
    elif fault == "missing_count":
        del connected_events[-2]["count"]
    else:
        connected_events[-2]["count"] = fault
    assert not connected_passed("\n".join(json.dumps(event) for event in connected_events))


@pytest.mark.parametrize(
    "protocol",
    [None, True, 0.1, [], {}, "", "0.1", "0.1.2", "999.0", " 0.1.1"],
    ids=[
        "null",
        "boolean",
        "number",
        "array",
        "object",
        "empty",
        "short",
        "new_patch",
        "unsupported",
        "whitespace",
    ],
)
def test_connected_report_rejects_unsupported_protocol(
    protocol: object, connected_events: list[dict]
) -> None:
    connected_events[0]["protocolVersion"] = protocol
    assert not connected_passed("\n".join(json.dumps(event) for event in connected_events))


def test_connected_report_requires_protocol(connected_events: list[dict]) -> None:
    del connected_events[0]["protocolVersion"]
    assert not connected_passed("\n".join(json.dumps(event) for event in connected_events))


@pytest.mark.parametrize(
    ("returncode", "valid_report", "error"),
    [
        (1, True, "process failed"),
        (-9, True, "process failed"),
        (0, False, "skipped, failed or incomplete"),
        (0, True, None),
    ],
    ids=["nonzero_valid", "signal_valid", "zero_invalid", "zero_valid"],
)
def test_connected_process_requires_exit_and_report_success(
    returncode: int, valid_report: bool, error: str | None, connected_events: list[dict]
) -> None:
    output = "\n".join(json.dumps(event) for event in connected_events) if valid_report else ""
    result = subprocess.CompletedProcess(["synthetic-flutter"], returncode, stdout=output)
    if error is None:
        assert_connected_result(result)
    else:
        with pytest.raises(AssertionError, match=error):
            assert_connected_result(result)


def test_flutter_http_with_real_postgres(
    owner: UUID, monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    if os.environ.get("DM_RUN_CONNECTED") != "1":
        pytest.skip("Set DM_RUN_CONNECTED=1 to run the Flutter ↔ HTTP ↔ PostgreSQL suite")
    root = Path(__file__).parents[3]
    flutter = os.environ.get("DM_FLUTTER_CMD") or shutil.which("flutter")
    if not flutter:
        candidate = root / ".tools/flutter/bin/flutter.bat"
        if candidate.exists():
            flutter = str(candidate)
    if not flutter:
        pytest.fail("Connected suite explicitly requested, but Flutter SDK was not found")
    key = ec.generate_private_key(ec.SECP256R1())
    public_file = tmp_path / "test-public.pem"
    public_file.write_bytes(
        key.public_key().public_bytes(
            serialization.Encoding.PEM,
            serialization.PublicFormat.SubjectPublicKeyInfo,
        )
    )
    issuer = "https://identity.daily-motion.test/auth/v1"
    monkeypatch.setenv("DM_JWT_ISSUER", issuer)
    monkeypatch.setenv("DM_ENVIRONMENT", "test")
    monkeypatch.setenv("DM_JWT_PUBLIC_KEY_FILE", str(public_file))
    settings.cache_clear()
    now = datetime.now(UTC)
    claims = {
        "sub": str(owner),
        "iss": issuer,
        "aud": "authenticated",
        "iat": now,
        "exp": now + timedelta(hours=1),
    }
    token = jwt.encode(claims, key, algorithm="ES256")
    other_owner = uuid4()
    other_token = jwt.encode(dict(claims, sub=str(other_owner)), key, algorithm="ES256")

    # The hosted provider boundary is simulated. JWT verification and API/DB
    # account initialization are real; this does not qualify email delivery.
    class CurrentIdentity:
        def open(self, request: object, timeout: int) -> io.BytesIO:
            from urllib.request import Request

            assert isinstance(request, Request)
            authorization = request.get_header("Authorization")
            assert authorization is not None
            subject = jwt.decode(
                authorization.split(" ", 1)[1],
                key.public_key(),
                algorithms=["ES256"],
                issuer=issuer,
                audience="authenticated",
            )["sub"]
            return io.BytesIO(
                json.dumps(
                    {
                        "id": subject,
                        "email_confirmed_at": "2026-10-13T00:00:00Z",
                        "is_anonymous": False,
                    }
                ).encode()
            )

    monkeypatch.setenv("DM_SUPABASE_URL", issuer.removesuffix("/auth/v1"))
    monkeypatch.setenv("DM_SUPABASE_PUBLISHABLE_KEY", "sb_publishable_synthetic")
    monkeypatch.setattr(accounts, "build_opener", lambda _: CurrentIdentity())
    settings.cache_clear()
    expired = jwt.encode(dict(claims, exp=now - timedelta(seconds=5)), key, algorithm="ES256")
    sock = socket.socket()
    sock.bind(("127.0.0.1", 0))
    port = sock.getsockname()[1]
    server = uvicorn.Server(uvicorn.Config(app, log_level="error", access_log=False))
    thread = threading.Thread(target=server.run, kwargs={"sockets": [sock]}, daemon=True)
    thread.start()
    try:
        for _ in range(200):
            if server.started:
                break
            time.sleep(0.025)
        assert server.started
        env = dict(
            os.environ,
            DM_SYNC_ENDPOINT=f"http://127.0.0.1:{port}",
            DM_SYNC_TOKEN=token,
            DM_SYNC_EXPIRED_TOKEN=expired,
            DM_SYNC_OWNER=str(owner),
            DM_SYNC_OWNER_B=str(other_owner),
            DM_SYNC_TOKEN_B=other_token,
        )
        result = subprocess.run(
            [flutter, "test", "test/connected_http_test.dart", "--machine"],
            cwd=root / "apps/mobile",
            env=env,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=180,
        )
        assert_connected_result(result)
        print("Connected Flutter HTTP/PostgreSQL: 9 passed, zero skipped")
    finally:
        server.should_exit = True
        thread.join(timeout=10)
        sock.close()
        settings.cache_clear()
