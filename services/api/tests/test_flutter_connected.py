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


def connected_passed(output: str) -> bool:
    events = []
    for line in output.splitlines():
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(event, dict):
            events.append(event)
    cases = [
        event
        for event in events
        if event.get("type") == "testDone" and event.get("hidden") is False
    ]
    return (
        len(cases) == 9
        and all(case.get("skipped") is False and case.get("result") == "success" for case in cases)
        and any(event.get("type") == "done" and event.get("success") is True for event in events)
    )


@pytest.mark.parametrize("fault", [None, "skip", "failure", "empty", "incomplete", "hidden"])
def test_connected_report_cannot_claim_skipped_or_incomplete_success(fault: str | None) -> None:
    cases = [
        {"type": "testDone", "hidden": False, "skipped": False, "result": "success"}
        for _ in range(9)
    ]
    if fault == "skip":
        cases[0]["skipped"] = True
    elif fault == "failure":
        cases[0]["result"] = "error"
    elif fault == "empty":
        cases.clear()
    elif fault == "hidden":
        cases[0]["hidden"] = True
    events = cases + ([] if fault == "incomplete" else [{"type": "done", "success": True}])
    assert connected_passed("\n".join(json.dumps(event) for event in events)) is (fault is None)


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
