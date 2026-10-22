"""Explicit local characterization, excluded from default test discovery.

DM_RUN_TIMELINE_INVESTIGATION=1 pytest tests/investigations/restore_timeline_probe.py
No existing URL is accepted. API/domain code is unchanged; only timing and the
connection to newly restored disposable targets are controlled by this harness.
"""

import asyncio
import hashlib
import json
import os
import shutil
import socket
import subprocess
import threading
import time
from contextlib import ExitStack
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any
from uuid import UUID, uuid4

import jwt
import pytest
import uvicorn
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec
from fastapi import FastAPI, HTTPException, Request
from sqlalchemy import Engine, text

from daily_motion import db
from daily_motion.accounts import initialize_account
from daily_motion.config import settings
from daily_motion.contracts import Operation
from daily_motion.main import app
from daily_motion.sync import accept, me
from tests.recovery_lab import NativeRecoveryLab, RecoveryLab, fingerprint, migrate
from tests.test_recovery import new_body
from tests.test_sync import command, record

ROOT = Path(__file__).parents[4]
CASES = (
    "equal_fenced",
    "lower_fenced",
    "higher_fenced",
    "equal_unfenced",
    "delayed_inflight",
    "same_generation",
    "lost_receipt",
    "retained_receipt",
    "restart_preflight",
    "owner_isolation",
    "deletion_equal_epoch",
    "deletion_regressed_epoch",
    "deletion_retained_control",
)


class Investigation:
    def __init__(self, lab: RecoveryLab) -> None:
        self.lab = lab
        self.a, self.b = uuid4(), uuid4()
        self.body, self.other = new_body(), new_body()
        self.resources = ExitStack()
        self.runtime: Engine | None = None
        self.admin: Engine | None = None
        self.case = ""
        self.current: dict[str, Any] = {}
        self.results: list[dict[str, Any]] = []
        self.arrived = threading.Event()
        self.release = threading.Event()
        self.baseline_archive = b""
        self.initial_fingerprint: dict[str, Any] = {}

    def engine(self) -> Engine:
        assert self.runtime is not None
        return self.runtime

    def seed(self) -> None:
        self.admin = self.lab.engine("daily_motion_test")
        self.runtime = self.lab.engine("daily_motion_test", runtime=True)
        try:
            migrate(self.admin)
            for owner, body in [(self.a, self.body), (self.b, self.other)]:
                initialize_account(owner)
                assert accept(owner, Operation.model_validate(body))["status"] == "accepted"
            self.initial_fingerprint = fingerprint(self.admin)
            self.baseline_archive = self.lab.dump()
            assert fingerprint(self.admin) == self.initial_fingerprint
        finally:
            self.runtime.dispose()
            self.admin.dispose()
            self.runtime = self.admin = None

    def clone(self, archive: bytes) -> None:
        name = self.resources.enter_context(self.lab.target())
        result = self.lab.restore(name, archive)
        assert result.returncode == 0, "Disposable archive restore failed"
        self.admin = self.lab.engine(name)
        self.runtime = self.lab.engine(name, runtime=True)
        self.resources.callback(self.admin.dispose)
        self.resources.callback(self.runtime.dispose)

    def start(self, case: str) -> dict[str, str]:
        if case not in CASES:
            raise HTTPException(400, detail="Unknown investigation case")
        assert len(self.results) == CASES.index(case), "Cases must finish in declared order"
        self.resources.close()
        self.resources = ExitStack()
        self.case = case
        self.arrived.clear()
        self.release.clear()
        self.clone(self.baseline_archive)
        assert fingerprint(self.admin) == self.initial_fingerprint
        assert accept(self.a, record(self.body))["accepted_revision"] == 2
        self.current = {
            "case": case,
            "origin_generation": me(self.a)["generation"],
            "origin_revision": 2,
            "archive_sha256": hashlib.sha256(self.baseline_archive).hexdigest(),
            "push_arrivals": 0,
        }
        return {"root": self.body["aggregate_id"], "other_root": self.other["aggregate_id"]}

    def dump_active(self) -> bytes:
        assert self.admin is not None
        name = self.admin.url.database
        assert name is not None and name.startswith("recovery_")
        if isinstance(self.lab, NativeRecoveryLab):
            return self.lab.checked_native(
                "pg_dump",
                "--host=127.0.0.1",
                f"--port={self.lab.port}",
                "--username=dm_recovery_admin",
                f"--dbname={name}",
                "--format=custom",
                "--no-owner",
                "--no-password",
            )
        return self.lab.checked(
            "exec",
            self.lab.container,
            "pg_dump",
            "--username=dm_recovery_admin",
            f"--dbname={name}",
            "--format=custom",
            "--no-owner",
            "--no-password",
        )

    def restore(self, mutation: str | None = None) -> dict[str, Any]:
        assert "restored_generation" not in self.current
        if mutation is not None:
            self.current["prepared_mutation_id"] = str(UUID(mutation))
        if self.case == "delayed_inflight":
            assert self.arrived.wait(15), "HTTP push did not reach the test-only delay gate"
        retained = self.case in {"retained_receipt", "deletion_retained_control"}
        archive = self.dump_active() if retained else self.baseline_archive
        self.current["restored_archive_sha256"] = hashlib.sha256(archive).hexdigest()
        self.clone(archive)
        if not retained and not self.case.startswith("deletion_"):
            revision = 1
            if self.case != "lower_fenced":
                divergent = record(self.body)
                divergent.payload["actual"]["reps"] = 9
                assert accept(self.a, divergent)["accepted_revision"] == 2
                revision = 2
            if self.case == "higher_fenced":
                assert (
                    accept(self.a, record(self.body, 2, index=2, sequence=2))["accepted_revision"]
                    == 3
                )
                revision = 3
            self.current["restored_revision"] = revision
        fenced = self.case != "equal_unfenced"
        if fenced:
            assert self.admin is not None
            with self.admin.begin() as connection:
                owners_before = connection.scalar(text("SELECT count(*) FROM training.owner_state"))
                assert owners_before == 2
                connection.exec_driver_sql(
                    (ROOT / "infra/recovery/restore_fence.sql").read_text(encoding="utf-8")
                )
                assert connection.scalar(text("SELECT count(*) FROM training.snapshots")) == 0
        context = me(self.a)
        self.current.update(
            restore_fence_applied=fenced,
            restored_generation=context["generation"],
            restored_erasure_epoch=context["erasure_epoch"],
            request_arrived_before_restore=self.arrived.is_set(),
        )
        self.current["restored_state_before_upload"] = self.inspect()
        self.release.set()
        return self.inspect()

    def delete(self) -> dict[str, Any]:
        assert self.case.startswith("deletion_")
        assert accept(self.a, command(self.body, "delete_session", 2))["status"] == "accepted"
        if self.case == "deletion_regressed_epoch":
            for _ in range(2):
                extra = new_body()
                assert accept(self.a, Operation.model_validate(extra))["status"] == "accepted"
                assert accept(self.a, command(extra, "delete_session", 1))["status"] == "accepted"
        context = me(self.a)
        self.current["acknowledged_deletion_epoch"] = context["erasure_epoch"]
        self.current["pre_restore_deleted_root_absent"] = self.inspect()["root_revision"] is None
        return {"erasure_epoch": context["erasure_epoch"]}

    def inspect(self, mutation: str | None = None) -> dict[str, Any]:
        assert self.admin is not None
        with self.admin.connect() as connection:
            row = connection.execute(
                text("SELECT revision FROM training.workouts WHERE owner_id=:owner AND id=:root"),
                {"owner": self.a, "root": UUID(self.body["aggregate_id"])},
            ).first()
            observations = connection.execute(
                text(
                    "SELECT ordinal,observation FROM training.sets WHERE owner_id=:owner "
                    "ORDER BY ordinal"
                ),
                {"owner": self.a},
            ).all()
            reps = [
                r.observation["actual"]["reps"] if r.observation else None for r in observations
            ]
            root_b = connection.scalar(
                text("SELECT revision FROM training.workouts WHERE owner_id=:owner AND id=:root"),
                {"owner": self.b, "root": UUID(self.other["aggregate_id"])},
            )
            receipt = connection.scalar(
                text("SELECT count(*) FROM training.receipts WHERE owner_id=:owner"),
                {"owner": self.a},
            )
            retirements = connection.scalar(
                text("SELECT count(*) FROM training.retired_ids WHERE owner_id=:owner"),
                {"owner": self.a},
            )
            mutation = mutation or self.current.get("prepared_mutation_id")
            matched = (
                connection.scalar(
                    text(
                        "SELECT acknowledgement FROM training.receipts "
                        "WHERE owner_id=:owner AND mutation_id=:mutation"
                    ),
                    {"owner": self.a, "mutation": UUID(mutation)},
                )
                if mutation
                else None
            )
        return {
            "root_revision": row.revision if row else None,
            "observed_reps": reps,
            "other_root_revision": root_b,
            "receipt_count": receipt,
            "retired_count": retirements,
            "mutation_receipt": matched,
            "context": me(self.a),
        }

    def finish(self, result: dict[str, Any]) -> None:
        assert result["case"] == self.case
        if self.case == "restart_preflight":
            assert self.current["push_arrivals"] == 0
        assert not any(key in result for key in ("token", "authorization", "session"))
        self.results.append({**self.current, "client": result, "server": self.inspect()})
        self.save(False)
        print(f"Probe completed: {self.case}", flush=True)

    def save(self, completed: bool, **extra: Any) -> None:
        output = ROOT / ".tools/restore-timeline-observations.json"
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(
            json.dumps(
                {
                    "schema_version": 1,
                    "baseline": "2781f5c101e87e1a9351cb3e7bbf53453625e025",
                    "synthetic_only": True,
                    "hosted_operations": False,
                    "production_changes": False,
                    "completed": completed,
                    "cases": self.results,
                    "active_case": self.current,
                    **extra,
                },
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )


def probe_passed(output: str) -> bool:
    # An opt-in investigation must report every actual case, with no skips.
    events = []
    for line in output.splitlines():
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(event, dict):
            events.append(event)
    visible = [e for e in events if e.get("type") == "testDone" and e.get("hidden") is False]
    if len(visible) != len(CASES):
        return False
    if any(e.get("skipped") is not False or e.get("result") != "success" for e in visible):
        return False
    return any(e.get("type") == "done" and e.get("success") is True for e in events)


def test_restore_timeline_characterization(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    assert os.environ.get("DM_RUN_TIMELINE_INVESTIGATION") == "1", "Explicit local opt-in required"
    flutter = os.environ.get("DM_FLUTTER_CMD") or shutil.which("flutter")
    assert flutter, "Investigation requires the pinned Flutter SDK; never count a skip"
    native = os.environ.get("DM_RECOVERY_PG_BIN")
    lab = NativeRecoveryLab(Path(native)) if native else RecoveryLab()
    investigation = Investigation(lab)
    monkeypatch.setattr(db, "engine", investigation.engine)
    monkeypatch.setenv("DM_ENVIRONMENT", "test")
    monkeypatch.setenv(
        "DM_SYNC_SIGNING_KEY", "synthetic-local-timeline-investigation-key-32-characters"
    )
    key = ec.generate_private_key(ec.SECP256R1())
    public = tmp_path / "synthetic-public.pem"
    public.write_bytes(
        key.public_key().public_bytes(
            serialization.Encoding.PEM,
            serialization.PublicFormat.SubjectPublicKeyInfo,
        )
    )
    issuer = "https://identity.daily-motion.test/auth/v1"
    monkeypatch.setenv("DM_JWT_ISSUER", issuer)
    monkeypatch.setenv("DM_JWT_PUBLIC_KEY_FILE", str(public))
    settings.cache_clear()
    now = datetime.now(UTC)
    claims = {"iss": issuer, "aud": "authenticated", "iat": now, "exp": now + timedelta(hours=1)}
    tokens = {
        str(o): jwt.encode(dict(claims, sub=str(o)), key, algorithm="ES256")
        for o in (investigation.a, investigation.b)
    }
    outer = FastAPI()

    @outer.post("/__investigation/{action}")
    async def control(action: str, request: Request) -> dict[str, Any]:
        if request.headers.get("X-DM-Investigation") != "local-only" or "origin" in request.headers:
            raise HTTPException(403)
        raw = await request.body()
        if len(raw) > 8192:
            raise HTTPException(413)
        value = json.loads(raw or b"{}")
        if action == "start":
            return await asyncio.to_thread(investigation.start, value["case"])
        if action == "restore":
            return await asyncio.to_thread(investigation.restore, value.get("mutation_id"))
        if action == "delete":
            return await asyncio.to_thread(investigation.delete)
        if action == "inspect":
            return await asyncio.to_thread(investigation.inspect, value.get("mutation_id"))
        if action == "finish":
            await asyncio.to_thread(investigation.finish, value)
            return {"recorded": True}
        raise HTTPException(404)

    class DelayPush:
        async def __call__(self, scope: Any, receive: Any, send: Any) -> None:
            if scope["type"] == "http" and scope["path"] == "/v1/sync/push":
                investigation.current["push_arrivals"] += 1
                if investigation.case == "delayed_inflight" and not investigation.release.is_set():
                    messages = []
                    while True:
                        message = await receive()
                        messages.append(message)
                        if not message.get("more_body", False):
                            break
                    investigation.arrived.set()
                    assert await asyncio.to_thread(investigation.release.wait, 30)

                    async def replay() -> Any:
                        return messages.pop(0) if messages else await receive()

                    await app(scope, replay, send)
                    return
            await app(scope, receive, send)

    outer.mount("/", DelayPush())
    sock = socket.socket()
    sock.bind(("127.0.0.1", 0))
    port = sock.getsockname()[1]
    server = uvicorn.Server(uvicorn.Config(outer, log_level="critical", access_log=False))
    thread = threading.Thread(target=server.run, kwargs={"sockets": [sock]}, daemon=True)
    completed = False
    try:
        lab.start()
        investigation.seed()
        thread.start()
        for _ in range(200):
            if server.started:
                break
            time.sleep(0.025)
        assert server.started
        env = {k: v for k, v in os.environ.items() if not k.startswith("DM_")}
        env.update(
            DM_TIMELINE_ENDPOINT=f"http://127.0.0.1:{port}",
            DM_TIMELINE_OWNER=str(investigation.a),
            DM_TIMELINE_OWNER_B=str(investigation.b),
            DM_TIMELINE_TOKEN=tokens[str(investigation.a)],
            DM_TIMELINE_TOKEN_B=tokens[str(investigation.b)],
        )
        result = subprocess.run(
            [flutter, "test", "test/investigation/restore_timeline_probe.dart", "--machine"],
            cwd=ROOT / "apps/mobile",
            env=env,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=300,
        )
        # Synthetic-only output stays in ignored local artifacts, never token/config values.
        (ROOT / ".tools/timeline-flutter-machine.log").write_text(result.stdout, encoding="utf-8")
        assert result.returncode == 0, "Flutter investigation failed; inspect ignored synthetic log"
        assert probe_passed(result.stdout), (
            "Skipped/failed/incomplete investigation is not evidence"
        )
        assert [r["case"] for r in investigation.results] == list(CASES)
        source = lab.engine("daily_motion_test")
        try:
            assert fingerprint(source) == investigation.initial_fingerprint
        finally:
            source.dispose()
        completed = True
        print(
            f"Restore timeline characterization: {len(CASES)} "
            "real Flutter/SQLite/HTTP/PostgreSQL cases"
        )
    finally:
        investigation.release.set()
        server.should_exit = True
        if thread.is_alive():
            thread.join(timeout=10)
        sock.close()
        investigation.resources.close()
        lab.cleanup()
        settings.cache_clear()
        investigation.save(
            completed, cleanup_confirmed=True, backend=lab.image, source_unchanged=completed
        )
