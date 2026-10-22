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


def connected_passed(output: str) -> bool:
    events = []
    for line in output.splitlines():
        if not line.strip():
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            # Flutter can print dependency progress before its machine stream.
            # Once events begin, malformed/trailing output cannot imply success.
            if events or line.lstrip().startswith(("{", "[")):
                return False
            continue
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
            elif kind not in {"start", "group", "print", "debug", "allSuites", "done"}:
                return False
    except (KeyError, TypeError, AttributeError):
        return False
    return len(suites) == 1 and completed == set(started) and passed == CONNECTED_CASES


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
    events.append({"type": "done", "success": True})
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


@pytest.mark.parametrize("variant", ["windows_path", "interleaved", "auxiliary", "daemon_uri"])
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
            + events[-1:]
        )
    elif variant == "auxiliary":
        events.insert(4, {"type": "print", "testID": 0, "message": "synthetic diagnostic"})
        events.insert(4, {"type": "group", "group": {"id": 0, "suiteID": 0}})
        events.insert(4, {"type": "allSuites", "count": 1})
        events.insert(4, {"type": "debug", "suiteID": 0})
    output = "\n".join(json.dumps(event) for event in events)
    if variant == "daemon_uri":
        output = output.replace(
            '\n{"type": "suite"',
            '\n[{"event":"test.startedProcess",'
            '"params":{"vmServiceUri":"http://127.0.0.1:1234/"}}]\n{"type": "suite"',
            1,
        )
    assert connected_passed(output)


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
        assert result.returncode == 0, "Connected Flutter HTTP/PostgreSQL process failed"
        assert connected_passed(result.stdout), "Connected cases were skipped, failed or incomplete"
        print("Connected Flutter HTTP/PostgreSQL: 9 passed, zero skipped")
    finally:
        server.should_exit = True
        thread.join(timeout=10)
        sock.close()
        settings.cache_clear()
