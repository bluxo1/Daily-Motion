"""Bounded review of existing O3 components; no B4/B5 or authenticated authority.

Accepts only explicit portable Windows binaries and starts its own disposable
cluster. Existing test fixtures supply synthetic Admission/target/authority;
their construction establishes no authentication or continuity. The omission
control deliberately uses administrator corruption to expose a trust assumption.
"""

import argparse
import hashlib
import json
import os
import sys
from contextlib import contextmanager
from dataclasses import replace
from pathlib import Path
from typing import Any
from unittest.mock import patch
from uuid import uuid4

ROOT = Path(__file__).resolve().parents[2]
sys.path[:0] = [str(ROOT / "services/api"), str(ROOT / "tools"), str(Path(__file__).parent)]

import pytest  # noqa: E402
from recovery_o3_local_probe import EXPECTED_CHECKS, checks_complete  # noqa: E402
from run_recovery_v2_local import clean_environment  # noqa: E402
from sqlalchemy import create_engine, text  # noqa: E402
from sqlalchemy.exc import DBAPIError  # noqa: E402

from daily_motion.contracts import canonical_json  # noqa: E402
from daily_motion.recovery import RecoveryDenied  # noqa: E402
from daily_motion.recovery_observation import observe_committed  # noqa: E402
from tests.recovery_lab import NativeRecoveryLab, migrate  # noqa: E402
from tests.test_recovery_observation import committed  # noqa: E402
from tests.test_recovery_protocol_v2 import (  # noqa: E402
    owner_rows,
    reservation_case,
    target,
)

ROLE = "dm_o3_advisory_observer"
FULL_SELECT = (
    "owner_state",
    "account_retirements",
    "workouts",
    "receipts",
    "changes",
    "recovery_owners",
    "recovery_attempts",
)
COLUMN_SELECT = {
    "exercises": "owner_id,id",
    "sets": "owner_id,id",
    "retired_ids": "owner_id,id",
    "observations": "owner_id,session_id",
    "snapshots": "owner_id,id",
}
EXPECTED = {
    *(f"reader_observes_{kind}" for kind in ("create", "record", "conflict", "rejected", "delete")),
    "existing_observer_denies_unresolved_head",
    "prepared_lookup_has_no_certificate",
    "inconsistent_omitted_scope_denied",
    "consistent_omitted_scope_not_independently_detected",
    *(
        f"reader_denies_{name}"
        for name in (
            "profiles",
            "observation_payload",
            "exercise_definition",
            "set_observation",
            "snapshot_pages",
            "owner_update",
        )
    ),
    *(
        f"inventory_{name}"
        for name in ("complete", "empty", "missing", "duplicate", "unknown", "failed", "truthy")
    ),
    "old_aggregate_gate_accepts_empty",
}


def record(report: dict[str, Any], name: str, matched: bool, category: str, **details: Any) -> None:
    report["checks"].append(
        {"name": name, "matched_expectation": matched, "category": category, **details}
    )


def runner_controls(report: dict[str, Any]) -> None:
    good = [{"name": name, "passed": True} for name in sorted(EXPECTED_CHECKS)]
    variants = {
        "complete": (good, True),
        "empty": ([], False),
        "missing": (good[:-1], False),
        "duplicate": (good[:-1] + good[:1], False),
        "unknown": (good[:-1] + [{"name": "unknown", "passed": True}], False),
        "failed": (good[:-1] + [{**good[-1], "passed": False}], False),
        "truthy": (good[:-1] + [{**good[-1], "passed": "yes"}], False),
    }
    for name, (checks, expected) in variants.items():
        record(report, f"inventory_{name}", checks_complete(checks) is expected, "runner_control")
    # Exact pre-fix expression, not a SQL execution or a trusted record.
    legacy = all(item["passed"] for item in []) and True
    record(report, "old_aggregate_gate_accepts_empty", legacy is True, "unsafe_runner_control")


def install_reader(admin: Any) -> None:
    with admin.begin() as db:
        db.execute(
            text(
                f"CREATE ROLE {ROLE} LOGIN NOSUPERUSER NOBYPASSRLS "
                "NOCREATEDB NOCREATEROLE NOREPLICATION"
            )
        )
        db.execute(text(f"GRANT USAGE ON SCHEMA training,recovery TO {ROLE}"))
        db.execute(text(f"GRANT SELECT ON recovery.control TO {ROLE}"))
        for table in FULL_SELECT:
            db.execute(text(f"GRANT SELECT ON training.{table} TO {ROLE}"))
        for table, columns in COLUMN_SELECT.items():
            db.execute(text(f"GRANT SELECT({columns}) ON training.{table} TO {ROLE}"))
        for table in ("owner_state", "recovery_owners", "recovery_attempts"):
            db.execute(text(f"GRANT UPDATE(owner_id) ON training.{table} TO {ROLE}"))
            db.execute(
                text(
                    f"CREATE POLICY advisory_reader ON training.{table} AS RESTRICTIVE "
                    f"FOR UPDATE TO {ROLE} USING(owner_id=nullif("
                    "current_setting('app.owner_id',true),'')::uuid) WITH CHECK(false)"
                )
            )


def database_checks(lab: NativeRecoveryLab, attempt: Path, report: dict[str, Any]) -> None:
    admin = lab.engine("daily_motion_test")
    reader = None
    try:
        migrate(admin)
        install_reader(admin)
        reader = create_engine(admin.url.set(username=ROLE), hide_parameters=True)
        fixture = json.loads((ROOT / "contracts/fixtures/workout.json").read_text(encoding="utf-8"))
        with pytest.MonkeyPatch.context() as monkeypatch:
            for kind in ("create", "record", "conflict", "rejected", "delete"):
                local = attempt / kind
                local.mkdir()
                with contextmanager(target.__wrapped__)(lab, monkeypatch) as active:
                    case = reservation_case.__wrapped__(active, fixture, local)
                    marker = committed(active, case, kind)
                    before = owner_rows(active)
                    observed = observe_committed(
                        reader, active.owner, marker, case.fresh(active.owner)
                    )
                    record(
                        report,
                        f"reader_observes_{kind}",
                        observed == marker and owner_rows(active) == before,
                        "postgres_component",
                    )
                    if kind == "create":
                        absent = case.authority.lookup(
                            active.owner, marker.intent.mutation, marker.intent.request_digest
                        )
                        record(
                            report,
                            "prepared_lookup_has_no_certificate",
                            absent is None and owner_rows(active) == before,
                            "existing_test_authority",
                        )
                        head = case.authority.current(
                            case.activation, active.owner, uuid4()
                        ).checkpoint
                        case.authority.uncertain(active.owner, head)
                        denied = False
                        try:
                            observe_committed(
                                reader, active.owner, marker, case.fresh(active.owner)
                            )
                        except RecoveryDenied:
                            denied = True
                        record(
                            report,
                            "existing_observer_denies_unresolved_head",
                            denied and owner_rows(active) == before,
                            "postgres_component_expected_denial",
                        )
                        negative_queries = {
                            "profiles": "SELECT * FROM training.profiles",
                            "observation_payload": "SELECT payload FROM training.observations",
                            "exercise_definition": "SELECT definition FROM training.exercises",
                            "set_observation": "SELECT observation FROM training.sets",
                            "snapshot_pages": "SELECT pages FROM training.snapshots",
                            "owner_update": (
                                "UPDATE training.owner_state SET owner_id=owner_id "
                                "WHERE owner_id=:owner"
                            ),
                        }
                        for name, sql in negative_queries.items():
                            state = None
                            try:
                                with reader.begin() as db:
                                    db.execute(
                                        text("SELECT set_config('app.owner_id',:owner,true)"),
                                        {"owner": str(active.owner)},
                                    )
                                    db.execute(text(sql), {"owner": active.owner})
                            except DBAPIError as error:
                                state = getattr(error.orig, "sqlstate", None)
                            record(
                                report,
                                f"reader_denies_{name}",
                                state == "42501",
                                "postgres_permission",
                                sqlstate=state,
                            )
                    if kind == "delete":
                        assert len(marker.retired_ids) > 1
                        omitted = next(
                            value for value in marker.retired_ids if value != marker.intent.root
                        )
                        remaining = tuple(value for value in marker.retired_ids if value != omitted)
                        changed = replace(marker, affected_ids=remaining, retired_ids=remaining)
                        fields = changed.metadata()
                        del fields["marker_digest"]
                        changed = replace(
                            changed,
                            marker_digest=hashlib.sha256(
                                canonical_json({"kind": "EFFECT_COMMITTED", **fields}).encode()
                            ).hexdigest(),
                        )
                        # Scoped synthetic administrator fault: immutable production
                        # bindings are bypassed only inside this disposable lab.
                        with active.admin.begin() as db:
                            db.execute(
                                text(
                                    "ALTER TABLE training.recovery_attempts "
                                    "DISABLE TRIGGER recovery_attempt_binding"
                                )
                            )
                            db.execute(
                                text(
                                    "UPDATE training.recovery_attempts "
                                    "SET committed_marker=CAST(:marker AS jsonb) "
                                    "WHERE owner_id=:owner"
                                ),
                                {
                                    "marker": canonical_json(changed.metadata()),
                                    "owner": active.owner,
                                },
                            )
                            db.execute(
                                text(
                                    "ALTER TABLE training.recovery_attempts "
                                    "ENABLE TRIGGER recovery_attempt_binding"
                                )
                            )
                        denied = False
                        try:
                            observe_committed(
                                reader, active.owner, changed, case.fresh(active.owner)
                            )
                        except RecoveryDenied:
                            denied = True
                        record(
                            report,
                            "inconsistent_omitted_scope_denied",
                            denied,
                            "postgres_component_expected_denial",
                        )
                        with active.admin.begin() as db:
                            db.execute(
                                text(
                                    "UPDATE training.changes SET body=jsonb_set("
                                    "body,'{retired_ids}',CAST(:ids AS jsonb)) "
                                    "WHERE owner_id=:owner AND session_id=:root"
                                ),
                                {
                                    "ids": canonical_json([str(value) for value in remaining]),
                                    "owner": active.owner,
                                    "root": marker.intent.root,
                                },
                            )
                        corrupted = owner_rows(active)
                        accepted = observe_committed(
                            reader, active.owner, changed, case.fresh(active.owner)
                        )
                        record(
                            report,
                            "consistent_omitted_scope_not_independently_detected",
                            accepted == changed and owner_rows(active) == corrupted,
                            "unsafe_admin_corruption_control",
                            limitation=(
                                "Excluded administrator/whole-binding corruption: B3 completeness "
                                "is trusted, not independently recovered from post-delete rows"
                            ),
                        )
    finally:
        if reader is not None:
            reader.dispose()
        admin.dispose()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-local", action="store_true", required=True)
    parser.add_argument("--pg-bin", type=Path, required=True)
    args = parser.parse_args()
    binary = args.pg_bin.resolve(strict=True)
    if not all(
        (binary / name).is_file()
        for name in ("postgres.exe", "pg_ctl.exe", "initdb.exe", "createdb.exe")
    ):
        parser.error("Explicit portable PostgreSQL directory required")
    attempt = ROOT / ".tools/o3-advisory" / uuid4().hex
    attempt.mkdir(parents=True, exist_ok=False)
    temporary = attempt / "temp"
    temporary.mkdir()
    report: dict[str, Any] = {
        "scope": (
            "Existing component and runner review only; no B4/B5, authentication, "
            "target continuity or provider qualification"
        ),
        "source_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "checks": [],
        "success": False,
        "cleanup_completed": False,
    }
    try:
        runner_controls(report)
        environment = clean_environment(dict(os.environ))
        environment.update(TEMP=str(temporary), TMP=str(temporary), PYTHONUTF8="1")
        with patch.dict(os.environ, environment, clear=True):
            lab = NativeRecoveryLab(binary)
            try:
                lab.start()
                report["postgres_version"] = lab.image
                database_checks(lab, attempt, report)
            finally:
                lab.cleanup()
                report["cleanup_completed"] = not lab.directory.exists()
        names = [item["name"] for item in report["checks"]]
        report["inventory_complete"] = len(names) == len(EXPECTED) and set(names) == EXPECTED
        report["success"] = (
            report["inventory_complete"]
            and all(item["matched_expectation"] is True for item in report["checks"])
            and report["cleanup_completed"]
        )
    except Exception as error:
        report["error_category"] = type(error).__name__
    finally:
        (attempt / "probe.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print(
            json.dumps(
                {
                    "report": (attempt / "probe.json").relative_to(ROOT).as_posix(),
                    "checks": len(report["checks"]),
                    "success": report["success"],
                    "cleanup_completed": report["cleanup_completed"],
                }
            )
        )
    return 0 if report["success"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
