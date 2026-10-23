"""Explicit, disposable O3 design probes; no B4/B5 implementation or provider.

Run with services/api/.venv Python, --run-local and an explicit portable Windows
PostgreSQL bin directory. No existing database URL is accepted. Output is written
only to a new ignored .tools/o3-review directory; failures are retained too.
"""

import argparse
import hashlib
import json
import os
import sys
from dataclasses import replace
from pathlib import Path
from typing import Any
from unittest.mock import patch
from uuid import UUID, uuid4

ROOT = Path(__file__).resolve().parents[2]
sys.path[:0] = [str(ROOT / "services/api"), str(ROOT / "tools")]

from run_recovery_v2_local import clean_environment  # noqa: E402
from sqlalchemy import create_engine, text  # noqa: E402
from sqlalchemy.exc import DBAPIError  # noqa: E402
from sqlalchemy.orm import Session  # noqa: E402

from daily_motion.contracts import canonical_json  # noqa: E402
from daily_motion.db import assert_runtime_role  # noqa: E402
from daily_motion.recovery import (  # noqa: E402
    Activation,
    ActivationState,
    Assertion,
    CommittedMarker,
    Intent,
    Origin,
    OutcomeStatus,
    OwnerEvidence,
    RecoveryDenied,
    TerminalOutcome,
    validate_admission,
)
from tests.recovery_lab import NativeRecoveryLab, migrate  # noqa: E402

OWNER = UUID("61000000-0000-4000-8000-000000000001")
OTHER = UUID("61000000-0000-4000-8000-000000000002")

# A missing/duplicated check must not become a successful partial probe.
EXPECTED_CHECKS = frozenset(
    {
        "core_certification_paths",
        "sealed_exact_lookup_is_idempotent",
        "sealed_new_certification_denied",
        "ordinary_admission_rejects_prepared_to_certified_gap",
        "adding_envelope_fields_changes_existing_core_hash",
        "select_only_cannot_lock",
        "permissive_false_check_does_not_override_owner_policy",
        "restrictive_verifier_locks_owner_state",
        "restrictive_verifier_cannot_update_owner_state",
        "restrictive_verifier_locks_recovery_owners",
        "restrictive_verifier_cannot_update_recovery_owners",
        "restrictive_verifier_locks_recovery_attempts",
        "restrictive_verifier_cannot_update_recovery_attempts",
        "verifier_denied_delete",
        "verifier_denied_insert",
        "verifier_denied_truncate",
        "verifier_denied_change_state",
        "verifier_denied_create",
        "owner_filter_and_transaction_local_reset",
        "guc_is_context_not_authenticated_owner_proof",
        "existing_runtime_metadata_guard_accepts_restricted_verifier",
        "read_only_transaction_cannot_lock",
        "verifier_lock_blocks_competing_owner_writer",
        "verifier_lock_released_after_transaction",
        "xid_and_wal_position_do_not_prove_commit",
    }
)


def checks_complete(checks: list[dict[str, Any]]) -> bool:
    names = [check.get("name") for check in checks]
    return (
        len(names) == len(EXPECTED_CHECKS)
        and all(isinstance(name, str) for name in names)
        and set(names) == EXPECTED_CHECKS
        and all(check.get("passed") is True for check in checks)
    )


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def core_fixture() -> tuple[OwnerEvidence, CommittedMarker]:
    activation = Activation(
        UUID("62000000-0000-4000-8000-000000000001"),
        1,
        UUID("62000000-0000-4000-8000-000000000002"),
        "b" * 64,
        "c" * 64,
    )
    generation = UUID("62000000-0000-4000-8000-000000000003")
    root = UUID("63000000-0000-4000-8000-000000000001")
    intent = Intent(
        OWNER,
        UUID("63000000-0000-4000-8000-000000000002"),
        UUID("63000000-0000-4000-8000-000000000003"),
        root,
        Origin(activation.environment, activation.incarnation, generation),
        1,
        "a" * 64,
    )
    outcome = TerminalOutcome(OutcomeStatus.ACCEPTED, 2, "2026-10-22T00:00:00Z")
    marker = CommittedMarker(
        intent, "d" * 64, outcome.result_digest(intent), outcome, 1, 1, (root,), (root,)
    )
    fields = marker.metadata()
    del fields["marker_digest"]
    marker = replace(
        marker,
        marker_digest=hashlib.sha256(
            canonical_json({"kind": "EFFECT_COMMITTED", **fields}).encode()
        ).hexdigest(),
    )
    return OwnerEvidence(OWNER, activation, generation), marker


def probe_protocol(checks: list[dict[str, Any]]) -> dict[str, Any]:
    original, marker = core_fixture()
    prepared = original.prepare(marker.intent, original.checkpoint, ActivationState.ACTIVE)
    certified = prepared.certify(marker, prepared.checkpoint, ActivationState.ACTIVE)
    uncertain = prepared.uncertain(prepared.checkpoint)
    settled = uncertain.certify(marker, uncertain.checkpoint, ActivationState.CLOSING)
    checks.append(
        {
            "name": "core_certification_paths",
            "passed": certified.checkpoint.order == 2 and settled.checkpoint.order == 3,
        }
    )
    checks.append(
        {
            "name": "sealed_exact_lookup_is_idempotent",
            "passed": certified.certify(marker, prepared.checkpoint, ActivationState.SEALED)
            == certified,
        }
    )
    try:
        prepared.certify(marker, prepared.checkpoint, ActivationState.SEALED)
    except RecoveryDenied:
        denied = True
    else:
        denied = False
    checks.append({"name": "sealed_new_certification_denied", "passed": denied})
    nonce = UUID("64000000-0000-4000-8000-000000000001")
    assertion = Assertion(
        original.activation, OWNER, nonce, certified.checkpoint, ActivationState.ACTIVE
    )
    try:
        validate_admission(
            assertion,
            owner=OWNER,
            nonce=nonce,
            pinned=original.activation,
            verified_target_digest=original.activation.target_digest,
            observed_serial=1,
            local_checkpoint=prepared.checkpoint,
            local_open=True,
        )
    except RecoveryDenied:
        denied = True
    else:
        denied = False
    checks.append(
        {"name": "ordinary_admission_rejects_prepared_to_certified_gap", "passed": denied}
    )
    event = {"kind": "CERTIFIED", **marker.metadata()}
    augmented = {**event, "transport_nonce": str(nonce)}
    checks.append(
        {
            "name": "adding_envelope_fields_changes_existing_core_hash",
            "passed": prepared.checkpoint.append(augmented) != certified.checkpoint,
        }
    )
    return {
        "synthetic_example_only": True,
        "not_authenticated_or_executed_commit": True,
        "marker": marker.metadata(),
        "prior": {"order": 0, "digest": "0" * 64},
        "prepared": {"order": prepared.checkpoint.order, "digest": prepared.checkpoint.digest},
        "certified": {"order": certified.checkpoint.order, "digest": certified.checkpoint.digest},
        "unresolved": {"order": uncertain.checkpoint.order, "digest": uncertain.checkpoint.digest},
        "settled": {"order": settled.checkpoint.order, "digest": settled.checkpoint.digest},
    }


def probe_sql(lab: NativeRecoveryLab, checks: list[dict[str, Any]]) -> None:
    admin = lab.engine("daily_motion_test")
    roles = ("dm_o3_select", "dm_o3_permissive", "dm_o3_verifier")
    engines = {}
    tables = ("owner_state", "recovery_owners", "recovery_attempts")
    try:
        migrate(admin)
        with admin.begin() as db:
            for owner in (OWNER, OTHER):
                db.execute(
                    text(
                        "INSERT INTO training.owner_state(owner_id,status,generation) "
                        "VALUES(:owner,'active',:gen)"
                    ),
                    {"owner": owner, "gen": uuid4()},
                )
                db.execute(
                    text(
                        "INSERT INTO training.recovery_owners(owner_id,environment_id,"
                        "incarnation,generation,evidence_digest) VALUES(:owner,:e,:i,:g,:d)"
                    ),
                    {"owner": owner, "e": uuid4(), "i": uuid4(), "g": uuid4(), "d": "0" * 64},
                )
                db.execute(
                    text(
                        "INSERT INTO training.recovery_attempts(owner_id,attempt_id,mutation_id,"
                        "aggregate_id,schema_version,environment_id,incarnation,generation,"
                        "activation_serial,request_digest,state,frozen_request) "
                        "VALUES(:owner,:t,:m,:r,2,:e,:i,:g,1,:d,'RESERVED','{}')"
                    ),
                    {
                        "owner": owner,
                        "t": uuid4(),
                        "m": uuid4(),
                        "r": uuid4(),
                        "e": uuid4(),
                        "i": uuid4(),
                        "g": uuid4(),
                        "d": "a" * 64,
                    },
                )
            db.execute(text("REVOKE CREATE ON SCHEMA public FROM PUBLIC"))
            for role in roles:
                db.execute(
                    text(
                        f"CREATE ROLE {role} LOGIN NOSUPERUSER NOBYPASSRLS "
                        "NOCREATEDB NOCREATEROLE NOREPLICATION"
                    )
                )
                db.execute(text(f"GRANT USAGE ON SCHEMA training,recovery TO {role}"))
                db.execute(text(f"GRANT SELECT ON recovery.control TO {role}"))
                for table in tables:
                    db.execute(text(f"GRANT SELECT ON training.{table} TO {role}"))
                    if role != roles[0]:
                        db.execute(text(f"GRANT UPDATE(owner_id) ON training.{table} TO {role}"))
                        flavor = "RESTRICTIVE" if role == roles[2] else "PERMISSIVE"
                        db.execute(
                            text(
                                f"CREATE POLICY o3_{role} ON training.{table} AS {flavor} "
                                f"FOR UPDATE TO {role} USING(owner_id=nullif("
                                "current_setting('app.owner_id',true),'')::uuid) WITH CHECK(false)"
                            )
                        )
                engines[role] = create_engine(admin.url.set(username=role), hide_parameters=True)

        def query(
            role: str,
            sql: str,
            *,
            owner: UUID | None = OWNER,
            expected_error: str | None = None,
            name: str,
        ) -> None:
            state = None
            rows = None
            try:
                with engines[role].begin() as db:
                    db.execute(text("SET LOCAL statement_timeout='2s'"))
                    if owner is not None:
                        db.execute(
                            text("SELECT set_config('app.owner_id',:owner,true)"),
                            {"owner": str(owner)},
                        )
                    result = db.execute(text(sql), {"owner": OWNER, "other": OTHER})
                    rows = len(result.fetchall()) if result.returns_rows else result.rowcount
            except DBAPIError as error:
                state = getattr(error.orig, "sqlstate", None)
            passed = state == expected_error and (state is not None or rows == 1)
            checks.append({"name": name, "passed": passed, "sqlstate": state, "rows": rows})

        query(
            roles[0],
            "SELECT * FROM training.owner_state WHERE owner_id=:owner FOR UPDATE",
            expected_error="42501",
            name="select_only_cannot_lock",
        )
        query(
            roles[1],
            "UPDATE training.owner_state SET owner_id=owner_id WHERE owner_id=:owner",
            name="permissive_false_check_does_not_override_owner_policy",
        )
        for table in tables:
            query(
                roles[2],
                f"SELECT * FROM training.{table} WHERE owner_id=:owner FOR UPDATE",
                name=f"restrictive_verifier_locks_{table}",
            )
            query(
                roles[2],
                f"UPDATE training.{table} SET owner_id=owner_id WHERE owner_id=:owner",
                expected_error="42501",
                name=f"restrictive_verifier_cannot_update_{table}",
            )
        for verb, sql in {
            "delete": "DELETE FROM training.owner_state WHERE owner_id=:owner",
            "insert": "INSERT INTO training.owner_state(owner_id,generation) VALUES(:owner,:other)",
            "truncate": "TRUNCATE training.owner_state",
            "change_state": (
                "UPDATE training.owner_state SET status='deleting' WHERE owner_id=:owner"
            ),
            "create": "CREATE TABLE training.o3_forbidden(id int)",
        }.items():
            query(roles[2], sql, expected_error="42501", name=f"verifier_denied_{verb}")
        with engines[roles[2]].begin() as db:
            db.execute(text("SELECT set_config('app.owner_id',:owner,true)"), {"owner": str(OWNER)})
            other_count = db.scalar(
                text("SELECT count(*) FROM training.owner_state WHERE owner_id=:other"),
                {"other": OTHER},
            )
        with engines[roles[2]].begin() as db:
            missing_count = db.scalar(text("SELECT count(*) FROM training.owner_state"))
        checks.append(
            {
                "name": "owner_filter_and_transaction_local_reset",
                "passed": other_count == 0 and missing_count == 0,
            }
        )
        query(
            roles[2],
            "SELECT * FROM training.owner_state WHERE owner_id=:other",
            owner=OTHER,
            name="guc_is_context_not_authenticated_owner_proof",
        )
        with Session(engines[roles[2]]) as session, session.begin():
            assert_runtime_role(session)
        checks.append(
            {"name": "existing_runtime_metadata_guard_accepts_restricted_verifier", "passed": True}
        )
        with engines[roles[2]].begin() as db:
            db.execute(text("SET TRANSACTION READ ONLY"))
            db.execute(text("SELECT set_config('app.owner_id',:owner,true)"), {"owner": str(OWNER)})
            try:
                db.execute(text("SELECT * FROM training.owner_state FOR UPDATE"))
            except DBAPIError as error:
                checks.append(
                    {
                        "name": "read_only_transaction_cannot_lock",
                        "passed": getattr(error.orig, "sqlstate", None) == "25006",
                        "sqlstate": getattr(error.orig, "sqlstate", None),
                    }
                )
            else:
                checks.append({"name": "read_only_transaction_cannot_lock", "passed": False})
        with engines[roles[2]].begin() as observer:
            observer.execute(
                text("SELECT set_config('app.owner_id',:owner,true)"), {"owner": str(OWNER)}
            )
            observer.execute(
                text("SELECT * FROM training.owner_state WHERE owner_id=:owner FOR UPDATE"),
                {"owner": OWNER},
            )
            try:
                with admin.begin() as writer:
                    writer.execute(
                        text(
                            "SELECT * FROM training.owner_state "
                            "WHERE owner_id=:owner FOR UPDATE NOWAIT"
                        ),
                        {"owner": OWNER},
                    )
            except DBAPIError as error:
                checks.append(
                    {
                        "name": "verifier_lock_blocks_competing_owner_writer",
                        "passed": getattr(error.orig, "sqlstate", None) == "55P03",
                        "sqlstate": getattr(error.orig, "sqlstate", None),
                    }
                )
            else:
                checks.append(
                    {"name": "verifier_lock_blocks_competing_owner_writer", "passed": False}
                )
        with admin.begin() as writer:
            unlocked = writer.scalar(
                text(
                    "SELECT owner_id FROM training.owner_state "
                    "WHERE owner_id=:owner FOR UPDATE NOWAIT"
                ),
                {"owner": OWNER},
            )
        checks.append(
            {"name": "verifier_lock_released_after_transaction", "passed": unlocked == OWNER}
        )
        with admin.begin() as db:
            db.execute(text("CREATE TABLE public.o3_wal_probe(id int PRIMARY KEY)"))
        with admin.connect() as db:
            before = db.scalar(text("SELECT pg_current_wal_insert_lsn()"))
            db.commit()
            db.execute(text("INSERT INTO public.o3_wal_probe VALUES(1)"))
            xid = db.scalar(text("SELECT pg_current_xact_id()"))
            after = db.scalar(text("SELECT pg_current_wal_insert_lsn()"))
            db.rollback()
            absent = db.scalar(text("SELECT count(*) FROM public.o3_wal_probe")) == 0
            advanced = db.scalar(
                text("SELECT CAST(:later AS pg_lsn)>CAST(:earlier AS pg_lsn)"),
                {"later": after, "earlier": before},
            )
        checks.append(
            {
                "name": "xid_and_wal_position_do_not_prove_commit",
                "passed": bool(xid) and absent and advanced is True,
            }
        )
    finally:
        for engine in engines.values():
            engine.dispose()
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
    attempt = ROOT / ".tools/o3-review" / uuid4().hex
    attempt.mkdir(parents=True, exist_ok=False)
    temporary = attempt / "temp"
    temporary.mkdir()
    report: dict[str, Any] = {
        "scope": "Local permission and existing reducer probes only; no trusted certification",
        "source_sha256": sha(Path(__file__)),
        "checks": [],
        "success": False,
        "cleanup_completed": False,
    }
    lab = None
    try:
        report["core_example"] = probe_protocol(report["checks"])
        environment = clean_environment(dict(os.environ))
        environment.update(TEMP=str(temporary), TMP=str(temporary), PYTHONUTF8="1")
        with patch.dict(os.environ, environment, clear=True):
            lab = NativeRecoveryLab(binary)
            try:
                lab.start()
                report["postgres_version"] = lab.image
                probe_sql(lab, report["checks"])
            finally:
                lab.cleanup()
                report["cleanup_completed"] = not lab.directory.exists()
        report["inventory_complete"] = checks_complete(report["checks"])
        report["success"] = report["inventory_complete"] and report["cleanup_completed"]
    except Exception as error:
        report["error_category"] = type(error).__name__
    finally:
        destination = attempt / "probe.json"
        destination.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print(
            json.dumps(
                {
                    "report": destination.relative_to(ROOT).as_posix(),
                    "checks": len(report["checks"]),
                    "success": report["success"],
                    "cleanup_completed": report["cleanup_completed"],
                }
            )
        )
    return 0 if report["success"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
