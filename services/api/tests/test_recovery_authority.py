"""Local SQLite conformance; never selected-provider or custody qualification."""

import json
import sqlite3
import threading
from concurrent.futures import ThreadPoolExecutor
from dataclasses import replace
from pathlib import Path
from uuid import UUID

import pytest

from daily_motion.recovery import (
    ActivationState,
    Checkpoint,
    OutcomeCode,
    OutcomeStatus,
    RecoveryDenied,
    TerminalOutcome,
)
from tests.recovery_authority import ConformanceAuthority
from tests.test_recovery_evidence import ACTIVATION, GENERATION, INTENT, MARKER, NONCE, OTHER, OWNER


def create(path: Path) -> ConformanceAuthority:
    return ConformanceAuthority.create(path, ACTIVATION, {OWNER: GENERATION, OTHER: GENERATION})


def test_response_loss_and_restart_preserve_exact_preparation_and_certificate(
    tmp_path: Path,
) -> None:
    path = tmp_path / "authority.sqlite"
    authority = create(path)
    checkpoint = authority.prepare(INTENT, Checkpoint())
    # Discard each client object/response and open the same authority file again.
    authority = ConformanceAuthority(path)
    assert authority.prepare(INTENT, Checkpoint()) == checkpoint
    certificate = authority.certify(MARKER, checkpoint)
    authority = ConformanceAuthority(path)
    assert authority.lookup(OWNER, INTENT.mutation, INTENT.request_digest) == certificate
    assert authority.certify(MARKER, checkpoint) == certificate
    assert authority.current(ACTIVATION, OWNER, NONCE).checkpoint.order == 2
    with pytest.raises(RecoveryDenied, match="mutation_digest_mismatch"):
        authority.lookup(OWNER, INTENT.mutation, "f" * 64)


def test_concurrent_compare_and_append_cannot_lose_owner_attempt(tmp_path: Path) -> None:
    authority = create(tmp_path / "authority.sqlite")
    barrier = threading.Barrier(2)

    def prepare(index: int) -> bool:
        intent = replace(INTENT, mutation=UUID(int=20 + index), attempt=UUID(int=30 + index))
        barrier.wait(timeout=5)
        try:
            authority.prepare(intent, Checkpoint())
            return True
        except RecoveryDenied:
            return False

    with ThreadPoolExecutor(2) as pool:
        assert sorted(pool.map(prepare, [0, 1])) == [False, True]
    assert authority.current(ACTIVATION, OWNER, NONCE).checkpoint.order == 1


def test_independent_owners_and_receipt_indexes_do_not_cross(tmp_path: Path) -> None:
    authority = create(tmp_path / "authority.sqlite")
    checkpoint = authority.prepare(INTENT, Checkpoint())
    certificate = authority.certify(MARKER, checkpoint)
    assert authority.lookup(OTHER, INTENT.mutation, INTENT.request_digest) is None
    other_intent = replace(INTENT, owner=OTHER, attempt=OTHER)
    other_checkpoint = authority.prepare(other_intent, Checkpoint())
    other_marker = replace(
        MARKER, intent=other_intent, result_digest=MARKER.outcome.result_digest(other_intent)
    )
    other_certificate = authority.certify(other_marker, other_checkpoint)
    assert certificate.committed.intent.owner == OWNER
    assert other_certificate.committed.intent.owner == OTHER
    assert certificate.checkpoint != other_certificate.checkpoint


def test_closing_settles_prepared_work_but_unresolved_owner_prevents_seal(tmp_path: Path) -> None:
    path = tmp_path / "authority.sqlite"
    authority = create(path)
    checkpoint = authority.prepare(INTENT, Checkpoint())
    authority.close()
    with pytest.raises(RecoveryDenied, match="recovery_unavailable"):
        authority.prepare(replace(INTENT, owner=OTHER), Checkpoint())
    authority.uncertain(OWNER, checkpoint)
    authority = ConformanceAuthority(path)
    current = authority.current(ACTIVATION, OWNER, NONCE)
    assert current.state == ActivationState.CLOSING
    with pytest.raises(RecoveryDenied, match="publication_pending"):
        authority.seal()
    authority.certify(MARKER, current.checkpoint)
    authority.seal()
    assert authority.current(ACTIVATION, OWNER, NONCE).state == ActivationState.SEALED
    certificate = authority.lookup(OWNER, INTENT.mutation, INTENT.request_digest)
    assert certificate is not None
    assert authority.certify(MARKER, certificate.checkpoint) == certificate


@pytest.mark.parametrize("fault", ["missing_owner", "malformed_owner", "missing_activation"])
def test_incomplete_or_corrupt_inventory_cannot_fabricate_idle(tmp_path: Path, fault: str) -> None:
    path = tmp_path / "authority.sqlite"
    authority = create(path)
    with sqlite3.connect(path) as db:
        if fault == "missing_owner":
            db.execute("DELETE FROM owners WHERE owner=?", (str(OWNER),))
        elif fault == "malformed_owner":
            db.execute("UPDATE owners SET body='{}' WHERE owner=?", (str(OWNER),))
        else:
            db.execute("DELETE FROM activation")
    with pytest.raises(RecoveryDenied):
        authority.current(ACTIVATION, OWNER, NONCE)


@pytest.mark.parametrize(
    "field,value",
    [
        ("high_water", False),
        ("checkpoint.order", 2.0),
        ("activation.serial", True),
        ("certificates.0.committed.private_position", "1"),
        ("certificates.0.committed.outcome.accepted_revision", True),
        ("certificates.0.committed.notes", "synthetic private payload sentinel"),
        ("certificates.0.committed.intent.raw_command", {"private": "synthetic sentinel"}),
        ("notes", "synthetic private payload sentinel"),
    ],
)
def test_stored_owner_metadata_rejects_coercion_and_unknown_payload(
    tmp_path: Path, field: str, value: object
) -> None:
    path = tmp_path / "authority.sqlite"
    authority = create(path)
    checkpoint = authority.prepare(INTENT, Checkpoint())
    authority.certify(MARKER, checkpoint)
    with sqlite3.connect(path) as db:
        body = json.loads(
            db.execute("SELECT body FROM owners WHERE owner=?", (str(OWNER),)).fetchone()[0]
        )
        cursor = body
        parts = field.split(".")
        for part in parts[:-1]:
            cursor = cursor[int(part)] if isinstance(cursor, list) else cursor[part]
        cursor[parts[-1]] = value
        changed = json.dumps(body)
        db.execute("UPDATE owners SET body=? WHERE owner=?", (changed, str(OWNER)))
    with pytest.raises(RecoveryDenied):
        ConformanceAuthority(path).current(ACTIVATION, OWNER, NONCE)
    with sqlite3.connect(path) as db:
        assert (
            db.execute("SELECT body FROM owners WHERE owner=?", (str(OWNER),)).fetchone()[0]
            == changed
        )


@pytest.mark.parametrize(
    "field,value",
    [("serial", True), ("serial", 1.0), ("serial", "1"), ("notes", "synthetic sentinel")],
)
def test_stored_activation_rejects_coercion_and_unknown_payload(
    tmp_path: Path, field: str, value: object
) -> None:
    path = tmp_path / "authority.sqlite"
    authority = create(path)
    with sqlite3.connect(path) as db:
        body = json.loads(db.execute("SELECT body FROM activation").fetchone()[0])
        body[field] = value
        changed = json.dumps(body)
        db.execute("UPDATE activation SET body=?", (changed,))
    with pytest.raises(RecoveryDenied):
        authority.current(ACTIVATION, OWNER, NONCE)
    with sqlite3.connect(path) as db:
        assert db.execute("SELECT body FROM activation").fetchone()[0] == changed


def test_older_valid_prefix_does_not_satisfy_newer_trusted_head(tmp_path: Path) -> None:
    authority = create(tmp_path / "authority.sqlite")
    old = authority.current(ACTIVATION, OWNER, NONCE)
    checkpoint = authority.prepare(INTENT, old.checkpoint)
    assert checkpoint.order > old.checkpoint.order
    with pytest.raises(RecoveryDenied):
        authority.certify(MARKER, old.checkpoint)
    assert authority.current(ACTIVATION, OWNER, NONCE).checkpoint == checkpoint


def test_lost_certificate_or_changed_binding_cannot_leave_a_valid_idle_head(tmp_path: Path) -> None:
    path = tmp_path / "authority.sqlite"
    authority = create(path)
    checkpoint = authority.prepare(INTENT, Checkpoint())
    authority.certify(MARKER, checkpoint)
    with sqlite3.connect(path) as db:
        body = json.loads(
            db.execute("SELECT body FROM owners WHERE owner=?", (str(OWNER),)).fetchone()[0]
        )
        body["certificates"] = []
        db.execute("UPDATE owners SET body=? WHERE owner=?", (json.dumps(body), str(OWNER)))
    with pytest.raises(RecoveryDenied):
        authority.current(ACTIVATION, OWNER, NONCE)


def test_missing_or_existing_authority_is_never_silently_created_or_overwritten(
    tmp_path: Path,
) -> None:
    path = tmp_path / "authority.sqlite"
    with pytest.raises(FileNotFoundError):
        ConformanceAuthority(path)
    authority = create(path)
    with pytest.raises(FileExistsError):
        create(path)
    assert authority.current(ACTIVATION, OWNER, NONCE).checkpoint == Checkpoint()


@pytest.mark.parametrize(
    "outcome",
    [
        MARKER.outcome,
        TerminalOutcome(
            OutcomeStatus.CONFLICT,
            expected_revision=2,
            current_revision=3,
            error_code=OutcomeCode.REVISION_CONFLICT,
        ),
        TerminalOutcome(OutcomeStatus.REJECTED, error_code=OutcomeCode.INVALID_TRANSITION),
    ],
)
def test_minimal_terminal_outcome_survives_restart_without_primary_receipts_or_payload(
    tmp_path: Path, outcome: TerminalOutcome
) -> None:
    path = tmp_path / "authority.sqlite"
    authority = create(path)
    checkpoint = authority.prepare(INTENT, Checkpoint())
    marker = replace(
        MARKER,
        outcome=outcome,
        result_digest=outcome.result_digest(INTENT),
        private_position=1 if outcome.status == OutcomeStatus.ACCEPTED else None,
        affected_ids=MARKER.affected_ids if outcome.status == OutcomeStatus.ACCEPTED else (),
    )
    certificate = authority.certify(marker, checkpoint)
    authority = ConformanceAuthority(path)
    restored = authority.lookup(OWNER, INTENT.mutation, INTENT.request_digest)
    assert restored == certificate
    assert restored.committed.outcome.result(INTENT) == outcome.result(INTENT)
    assert restored.committed.intent.origin == INTENT.origin
    with authority.transaction() as db:
        body = db.execute("SELECT body FROM owners WHERE owner=?", (str(OWNER),)).fetchone()[0]
        metadata = json.loads(body)
        encoded = json.dumps(metadata)
        assert all(word not in encoded for word in ("payload", "notes", "frozen_request", "token"))
        metadata["certificates"][0]["committed"]["outcome"]["accepted_revision"] = 50
        db.execute("UPDATE owners SET body=? WHERE owner=?", (json.dumps(metadata), str(OWNER)))
    # A different deterministic result cannot be spliced under a retained digest.
    with pytest.raises(RecoveryDenied):
        authority.lookup(OWNER, INTENT.mutation, INTENT.request_digest)
