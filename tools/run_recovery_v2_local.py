"""Explicit local component checks with a fresh owned PostgreSQL cluster.

This is an incremental development runner, not full DRP/2 qualification. It never
accepts an existing URL or a provider. RC10/RC11 are not executed. The final full
named-case/machine acceptance wrapper remains required before goal completion.
"""

import argparse
import contextlib
import json
import os
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from unittest.mock import patch
from uuid import uuid4


def clean_environment(source: dict[str, str]) -> dict[str, str]:
    # Allowlist process mechanics; do not inherit DM/libpq/provider credentials.
    allowed = {
        "SYSTEMROOT",
        "SYSTEMDRIVE",
        "WINDIR",
        "COMSPEC",
        "PATH",
        "PATHEXT",
        "USERPROFILE",
        "APPDATA",
        "LOCALAPPDATA",
        "PROGRAMFILES",
        "PROGRAMFILES(X86)",
        "PROGRAMDATA",
        "NUMBER_OF_PROCESSORS",
        "PROCESSOR_ARCHITECTURE",
    }
    return {key: value for key, value in source.items() if key.upper() in allowed}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-local", action="store_true", required=True)
    parser.add_argument("--pg-bin", type=Path, required=True)
    parser.add_argument("--full-python", action="store_true")
    parser.add_argument("--flutter", type=Path)
    parser.add_argument("--pub-cache", type=Path)
    options = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    binary = options.pg_bin.resolve(strict=True)
    for name in ("postgres.exe", "initdb.exe", "pg_ctl.exe", "createdb.exe"):
        if not (binary / name).is_file():
            parser.error("Portable local PostgreSQL executables are incomplete")
    if options.full_python and (
        options.flutter is None
        or not options.flutter.is_file()
        or options.pub_cache is None
        or not options.pub_cache.is_dir()
    ):
        parser.error("Full Python/connected checks require explicit Flutter and Pub cache paths")
    attempt = root / ".tools" / "recovery-v2-attempts" / uuid4().hex
    attempt.mkdir(parents=True, exist_ok=False)
    temporary = attempt / "temp"
    temporary.mkdir()
    environment = clean_environment(dict(os.environ))
    environment.update(
        DM_RUN_RECOVERY_V2="1",
        DM_RECOVERY_PG_BIN=str(binary),
        TEMP=str(temporary),
        TMP=str(temporary),
        PYTHONUTF8="1",
    )
    report = attempt / "pytest.xml"
    command = [
        sys.executable,
        "-m",
        "pytest",
        "-q",
        "--tb=short",
        "tests/test_recovery_protocol_v2.py",
        "tests/test_recovery_effect.py",
        "tests/test_recovery_evidence.py",
        "tests/test_recovery_authority.py",
        "tests/test_recovery_contracts.py",
        "--junitxml=" + str(report),
    ]
    print(
        "Starting disposable local PostgreSQL and authority component checks: " + attempt.name,
        flush=True,
    )
    with contextlib.ExitStack() as resources:
        if options.full_python:
            sys.path.insert(0, str(root / "services/api"))
            from tests.recovery_lab import NativeRecoveryLab

            # The parent lab also receives only the scrubbed environment. The
            # destructive legacy fixtures get this newly owned cluster's URL.
            resources.enter_context(patch.dict(os.environ, environment, clear=True))
            lab = NativeRecoveryLab(binary)
            resources.callback(lab.cleanup)
            lab.start()
            # The staging-runtime password boundary must negotiate SCRAM.
            # Other synthetic roles retain trust within this owned loopback lab;
            # this is not hosted authentication qualification.
            hba = (lab.data / "pg_hba.conf").resolve(strict=True)
            if hba.parent != lab.data.resolve(strict=True):
                raise RuntimeError("Unexpected disposable PostgreSQL HBA target")
            hba.write_text(
                "host all dm_staging_runtime 127.0.0.1/32 scram-sha-256\n" + hba.read_text("utf-8"),
                encoding="utf-8",
                newline="\n",
            )
            lab.checked_native("pg_ctl", "reload", "--pgdata", str(lab.data))
            admin = lab.engine("daily_motion_test")
            try:
                environment["DM_TEST_ADMIN_URL"] = admin.url.render_as_string(hide_password=False)
            finally:
                admin.dispose()
            environment.update(
                DM_RUN_CONNECTED="1",
                DM_RUN_RECOVERY="1",
                DM_FLUTTER_CMD=str(options.flutter.resolve()),
                PUB_CACHE=str(options.pub_cache.resolve()),
            )
            command = [
                sys.executable,
                "-m",
                "pytest",
                "-q",
                "--tb=short",
                "--junitxml=" + str(report),
            ]
        result = subprocess.run(
            command,
            cwd=root / "services/api",
            env=environment,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
    (attempt / "python.log").write_text(result.stdout + "\n" + result.stderr, encoding="utf-8")
    success = result.returncode == 0
    count = 0
    try:
        document = ET.parse(report).getroot()
        cases = list(document.iter("testcase"))
        count = len(cases)
        modules = {case.get("classname") for case in cases}
        if options.full_python:
            success = success and {"tests.test_recovery", "tests.test_flutter_connected"} <= modules
            success = success and any(
                case.get("classname") == "tests.test_flutter_connected"
                and case.get("name") == "test_flutter_http_with_real_postgres"
                for case in cases
            )
        success = (
            success
            and count > 0
            and {
                "tests.test_recovery_protocol_v2",
                "tests.test_recovery_effect",
                "tests.test_recovery_evidence",
                "tests.test_recovery_authority",
                "tests.test_recovery_contracts",
            }
            <= modules
            and not any(list(document.iter(tag)) for tag in ("skipped", "failure", "error"))
        )
    except (OSError, ET.ParseError):
        success = False
    receipt = {
        "scope": "local components only",
        "full_python_requested": options.full_python,
        "complete_protocol_qualification": False,
        "rc10_rc11": "NOT EXECUTED; no selected provider/custody authorization",
        "child_exit_code": result.returncode,
        "component_checks_passed": success,
        "test_cases": count,
        "junit": str(report),
        "log": str(attempt / "python.log"),
    }
    (attempt / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(receipt), flush=True)
    return 0 if success else 1


if __name__ == "__main__":
    raise SystemExit(main())
