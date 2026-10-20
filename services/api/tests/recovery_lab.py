"""Disposable local PostgreSQL lab; never accepts an existing database URL."""

import hashlib
import json
import os
import re
import shutil
import socket
import subprocess
import tempfile
import time
from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path
from typing import Any
from uuid import uuid4

from alembic import command
from alembic.config import Config
from sqlalchemy import Engine, create_engine, text
from sqlalchemy.engine import URL
from sqlalchemy.exc import OperationalError


def local_docker_endpoint(endpoint: str) -> str:
    """Pin the daemon before creating resources; TCP/SSH contexts are forbidden."""
    if endpoint not in {
        "npipe:////./pipe/dockerDesktopLinuxEngine",
        "npipe:////./pipe/docker_engine",
        "unix:///var/run/docker.sock",
    } and not re.fullmatch(r"unix:///run/user/[0-9]+/docker.sock", endpoint):
        raise RuntimeError("Recovery lab requires a local Docker socket")
    return endpoint


class RecoveryLab:
    def __init__(self) -> None:
        if any(
            os.environ.get(name)
            for name in ("PGHOSTADDR", "PGSERVICE", "PGSERVICEFILE", "PGOPTIONS")
        ):
            raise RuntimeError("Recovery lab forbids ambient libpq routing overrides")
        # context inspect is local metadata; no connection to that daemon is made yet.
        result = subprocess.run(
            ["docker", "context", "inspect", "--format", "{{.Endpoints.docker.Host}}"],
            capture_output=True,
            timeout=15,
            check=True,
        )
        self.endpoint = local_docker_endpoint(result.stdout.decode().strip())
        self.label = uuid4().hex
        self.container = ""
        self.volume = ""
        self.port = 0

    def docker(self, *args: str, data: bytes | None = None) -> subprocess.CompletedProcess[bytes]:
        # An explicit local socket wins over ambient host/context configuration.
        environment = {
            key: value
            for key, value in os.environ.items()
            if key not in {"DOCKER_HOST", "DOCKER_CONTEXT", "DOCKER_TLS_VERIFY", "DOCKER_CERT_PATH"}
        }
        return subprocess.run(
            ["docker", "--host", self.endpoint, *args],
            input=data,
            capture_output=True,
            timeout=60,
            env=environment,
        )

    def checked(self, *args: str, data: bytes | None = None) -> bytes:
        result = self.docker(*args, data=data)
        if result.returncode:
            # Neither database payloads nor command stderr belong in evidence logs.
            raise RuntimeError(f"Local recovery Docker operation failed: {args[0]}")
        return result.stdout

    def start(self) -> None:
        # Do not pull images, reuse containers, mount host files or select Compose services.
        image = self.checked("image", "inspect", "postgres:17.7", "--format", "{{.Id}}")
        self.image = image.decode().strip()
        self.container = (
            self.checked(
                "run",
                "--detach",
                "--pull=never",
                "--label",
                f"daily-motion.recovery={self.label}",
                "--name",
                f"dm-recovery-{self.label}",
                "--publish",
                "127.0.0.1::5432",
                "--volume",
                "/var/lib/postgresql/data",
                "--env",
                "POSTGRES_HOST_AUTH_METHOD=trust",
                "--env",
                "POSTGRES_USER=dm_recovery_admin",
                "--env",
                "POSTGRES_DB=daily_motion_test",
                self.image,
            )
            .decode()
            .strip()
        )
        if not re.fullmatch(r"[0-9a-f]{64}", self.container):
            raise RuntimeError("Invalid newly created recovery container ID")
        details = json.loads(self.checked("inspect", self.container))[0]
        binding = details["NetworkSettings"]["Ports"]["5432/tcp"]
        assert len(binding) == 1 and binding[0]["HostIp"] == "127.0.0.1"
        self.port = int(binding[0]["HostPort"])
        self.volume = next(
            mount["Name"]
            for mount in details["Mounts"]
            if mount["Destination"] == "/var/lib/postgresql/data"
        )
        self.wait_ready()

    def engine(self, database: str, *, runtime: bool = False) -> Engine:
        return create_engine(
            URL.create(
                "postgresql+psycopg",
                username="dm_recovery_runtime" if runtime else "dm_recovery_admin",
                host="127.0.0.1",
                port=self.port,
                database=database,
            ),
            hide_parameters=True,
            pool_pre_ping=True,
            connect_args={"connect_timeout": 2},
        )

    def wait_ready(self) -> None:
        deadline = time.monotonic() + 45
        engine = self.engine("daily_motion_test")
        try:
            while time.monotonic() < deadline:
                try:
                    with engine.connect() as db:
                        assert db.scalar(text("SELECT 1")) == 1
                    return
                except OperationalError:
                    time.sleep(0.2)
            raise RuntimeError("Disposable PostgreSQL did not become ready")
        finally:
            engine.dispose()

    @contextmanager
    def target(self) -> Iterator[str]:
        # Only names generated here can reach CREATE/DROP DATABASE.
        name = "recovery_" + uuid4().hex
        admin = self.engine("postgres").execution_options(isolation_level="AUTOCOMMIT")
        try:
            with admin.connect() as db:
                db.execute(text(f'CREATE DATABASE "{name}"'))
            yield name
        finally:
            with admin.connect() as db:
                db.execute(text(f'DROP DATABASE IF EXISTS "{name}" WITH (FORCE)'))
            admin.dispose()

    def dump(self) -> bytes:
        return self.checked(
            "exec",
            self.container,
            "pg_dump",
            "--username=dm_recovery_admin",
            "--dbname=daily_motion_test",
            "--format=custom",
            "--no-owner",
            "--no-password",
        )

    def restore(self, name: str, archive: bytes) -> subprocess.CompletedProcess[bytes]:
        if not re.fullmatch(r"recovery_[0-9a-f]{32}", name):
            raise RuntimeError("Restore target must be a generated disposable database")
        return self.docker(
            "exec",
            "--interactive",
            "--env",
            "PGAPPNAME=dm_recovery_restore",
            self.container,
            "pg_restore",
            "--username=dm_recovery_admin",
            f"--dbname={name}",
            "--single-transaction",
            "--exit-on-error",
            "--no-owner",
            "--no-password",
            data=archive,
        )

    def cleanup(self) -> None:
        if not self.container:
            return
        label = (
            self.checked(
                "inspect",
                self.container,
                "--format",
                '{{index .Config.Labels "daily-motion.recovery"}}',
            )
            .decode()
            .strip()
        )
        assert label == self.label
        self.checked("rm", "--force", "--volumes", self.container)
        assert self.docker("inspect", self.container).returncode != 0
        if self.volume:
            assert self.docker("volume", "inspect", self.volume).returncode != 0

    def crash_restart(self) -> None:
        self.checked("kill", "--signal=KILL", self.container)
        self.checked("start", self.container)
        self.wait_ready()


class NativeRecoveryLab(RecoveryLab):
    """Fallback using portable Windows binaries and a new, task-local data directory."""

    def __init__(self, binary_directory: Path) -> None:
        if any(
            os.environ.get(name)
            for name in ("PGHOSTADDR", "PGSERVICE", "PGSERVICEFILE", "PGOPTIONS")
        ):
            raise RuntimeError("Recovery lab forbids ambient libpq routing overrides")
        self.binary_directory = binary_directory.resolve(strict=True)
        self.lab_root = (Path(__file__).parents[3] / ".tools" / "recovery-labs").resolve()
        self.lab_root.mkdir(parents=True, exist_ok=True)
        self.directory = Path(tempfile.mkdtemp(prefix="pg-", dir=self.lab_root)).resolve()
        self.data = self.directory / "data"
        self.port = 0
        self.started = False

    def run_native(
        self, program: str, *args: str, data: bytes | None = None
    ) -> subprocess.CompletedProcess[bytes]:
        executable = self.binary_directory / f"{program}.exe"
        # Windows server descendants can retain captured pipe handles after the
        # launcher exits. Do not wait for EOF from a background server's handles.
        background = program in {"pg_ctl", "initdb"}
        return subprocess.run(
            [str(executable), *args],
            input=data,
            stdout=subprocess.DEVNULL if background else subprocess.PIPE,
            stderr=subprocess.DEVNULL if background else subprocess.PIPE,
            timeout=180 if program == "initdb" else 60,
            creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
        )

    def checked_native(self, program: str, *args: str) -> bytes:
        result = self.run_native(program, *args)
        if result.returncode:
            raise RuntimeError(f"Disposable native PostgreSQL operation failed: {program}")
        return result.stdout or b""

    def start(self) -> None:
        self.image = self.checked_native("postgres", "--version").decode().strip()
        self.checked_native(
            "initdb",
            "--pgdata",
            str(self.data),
            "--username=dm_recovery_admin",
            "--auth=trust",
            "--encoding=UTF8",
            "--locale=C",
        )
        with socket.socket() as reservation:
            reservation.bind(("127.0.0.1", 0))
            self.port = reservation.getsockname()[1]
        self.start_server()
        self.checked_native(
            "createdb",
            "--host=127.0.0.1",
            f"--port={self.port}",
            "--username=dm_recovery_admin",
            "daily_motion_test",
        )
        self.wait_ready()

    def start_server(self) -> None:
        self.checked_native(
            "pg_ctl",
            "start",
            "--pgdata",
            str(self.data),
            "--log",
            str(self.directory / "server.log"),
            "--wait",
            "--timeout=30",
            "--options",
            f"-p {self.port} -h 127.0.0.1",
        )
        self.started = True

    def dump(self) -> bytes:
        return self.checked_native(
            "pg_dump",
            "--host=127.0.0.1",
            f"--port={self.port}",
            "--username=dm_recovery_admin",
            "--dbname=daily_motion_test",
            "--format=custom",
            "--no-owner",
            "--no-password",
        )

    def restore(self, name: str, archive: bytes) -> subprocess.CompletedProcess[bytes]:
        if not re.fullmatch(r"recovery_[0-9a-f]{32}", name):
            raise RuntimeError("Restore target must be a generated disposable database")
        # libpq startup options are explicitly forbidden at lab creation; the test
        # process name is set only for this child, not through inherited PGOPTIONS.
        environment = dict(os.environ, PGAPPNAME="dm_recovery_restore")
        return subprocess.run(
            [
                str(self.binary_directory / "pg_restore.exe"),
                "--host=127.0.0.1",
                f"--port={self.port}",
                "--username=dm_recovery_admin",
                f"--dbname={name}",
                "--single-transaction",
                "--exit-on-error",
                "--no-owner",
                "--no-password",
            ],
            input=archive,
            capture_output=True,
            timeout=60,
            env=environment,
            creationflags=subprocess.CREATE_NO_WINDOW,
        )

    def crash_restart(self) -> None:
        self.checked_native(
            "pg_ctl", "stop", "--pgdata", str(self.data), "--mode=immediate", "--wait"
        )
        self.started = False
        self.start_server()
        self.wait_ready()

    def cleanup(self) -> None:
        if (
            self.data.exists()
            and self.run_native("pg_ctl", "status", "--pgdata", str(self.data)).returncode == 0
        ):
            self.checked_native(
                "pg_ctl", "stop", "--pgdata", str(self.data), "--mode=fast", "--wait"
            )
            self.started = False
        # Check the exact generated absolute target before recursive Windows removal.
        target = self.directory.resolve(strict=True)
        if target.parent != self.lab_root or not re.fullmatch(r"pg-[a-z0-9_]+", target.name):
            raise RuntimeError("Refusing cleanup outside the generated recovery lab")
        shutil.rmtree(target)
        assert not target.exists()


def migrate(engine: Engine) -> None:
    root = Path(__file__).parents[1]
    config = Config(str(root / "alembic.ini"))
    config.set_main_option("script_location", str(root / "migrations"))
    with engine.begin() as connection:
        config.attributes["connection"] = connection
        command.upgrade(config, "head")
        connection.execute(text("CREATE ROLE dm_recovery_runtime LOGIN NOSUPERUSER NOBYPASSRLS"))
        connection.execute(text("GRANT USAGE ON SCHEMA training TO dm_recovery_runtime"))
        connection.execute(
            text(
                "GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA training "
                "TO dm_recovery_runtime"
            )
        )
        connection.execute(text("GRANT SELECT ON public.alembic_version TO dm_recovery_runtime"))


def fingerprint(engine: Engine) -> dict[str, Any]:
    """Compare content, policies, grants and structural metadata without logging rows."""
    with engine.connect() as db:
        tables = db.scalars(
            text("SELECT tablename FROM pg_tables WHERE schemaname='training' ORDER BY tablename")
        ).all()
        rows = {}
        for table in tables:
            assert re.fullmatch(r"[a-z_]+", table)
            payload = db.scalar(
                text(
                    "SELECT coalesce(jsonb_agg(to_jsonb(t) "
                    "ORDER BY to_jsonb(t)::text),'[]'::jsonb) "
                    f'FROM training."{table}" t'
                )
            )
            encoded = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode()
            rows[table] = {"count": len(payload), "sha256": hashlib.sha256(encoded).hexdigest()}
        metadata = {}
        for name, query in {
            "rls": "SELECT relname,relrowsecurity,relforcerowsecurity FROM pg_class "
            "JOIN pg_namespace n ON n.oid=relnamespace WHERE n.nspname='training' "
            "AND relkind='r' ORDER BY relname",
            "policies": "SELECT tablename,policyname,permissive,roles,cmd,qual,with_check "
            "FROM pg_policies WHERE schemaname='training' ORDER BY tablename,policyname",
            "constraints": "SELECT conrelid::regclass::text,conname,pg_get_constraintdef(oid) "
            "FROM pg_constraint WHERE connamespace='training'::regnamespace ORDER BY 1,2",
            "indexes": "SELECT tablename,indexname,indexdef FROM pg_indexes "
            "WHERE schemaname='training' ORDER BY 1,2",
            "grants": "SELECT table_name,grantee,privilege_type,is_grantable "
            "FROM information_schema.role_table_grants WHERE table_schema='training' "
            "ORDER BY 1,2,3",
        }.items():
            payload = [list(row) for row in db.execute(text(query))]
            metadata[name] = hashlib.sha256(
                json.dumps(payload, sort_keys=True).encode()
            ).hexdigest()
        return {
            "revision": db.scalar(text("SELECT version_num FROM public.alembic_version")),
            "rows": rows,
            "metadata": metadata,
        }
