"""Internal DRP/2 rules, not PostgreSQL/provider or independent custody qualification."""

from dataclasses import FrozenInstanceError, replace
from uuid import UUID

import pytest

from daily_motion.recovery import (
    MAX_COUNTER,
    Activation,
    ActivationState,
    Assertion,
    Checkpoint,
    CommittedMarker,
    Intent,
    Origin,
    OutcomeCode,
    OutcomeStatus,
    OwnerEvidence,
    RecoveryDenied,
    TerminalOutcome,
    next_erasure_epoch,
    validate_admission,
)

OWNER = UUID(int=1)
OTHER = UUID(int=2)
ENVIRONMENT = UUID(int=3)
INCARNATION = UUID(int=4)
GENERATION = UUID(int=5)
NONCE = UUID(int=6)
ACTIVATION = Activation(ENVIRONMENT, 1, INCARNATION, "a" * 64, "b" * 64)
INTENT = Intent(
    OWNER,
    UUID(int=7),
    UUID(int=8),
    UUID(int=9),
    Origin(ENVIRONMENT, INCARNATION, GENERATION),
    1,
    "c" * 64,
)
OUTCOME = TerminalOutcome(OutcomeStatus.ACCEPTED, 1, "2026-10-22T00:00:00Z")
MARKER = CommittedMarker(
    INTENT, "d" * 64, OUTCOME.result_digest(INTENT), OUTCOME, 1, 0, (INTENT.root,)
)


def empty() -> OwnerEvidence:
    return OwnerEvidence(OWNER, ACTIVATION, GENERATION)


@pytest.mark.parametrize("value", ["private workout notes", str(OWNER), None, 1, [OWNER]])
@pytest.mark.parametrize(
    "scope,field",
    [
        ("origin", "environment"),
        ("origin", "incarnation"),
        ("origin", "generation"),
        ("activation", "environment"),
        ("activation", "incarnation"),
        ("intent", "owner"),
        ("intent", "mutation"),
        ("intent", "attempt"),
        ("intent", "root"),
        ("owner", "owner"),
        ("owner", "generation"),
        ("assertion", "owner"),
        ("assertion", "nonce"),
    ],
)
def test_independent_identity_fields_require_decoded_uuids(
    value: object, scope: str, field: str
) -> None:
    assertion = Assertion(ACTIVATION, OWNER, NONCE, Checkpoint(), ActivationState.ACTIVE)
    original = {
        "origin": INTENT.origin,
        "activation": ACTIVATION,
        "intent": INTENT,
        "owner": empty(),
        "assertion": assertion,
    }[scope]
    with pytest.raises(RecoveryDenied):
        replace(original, **{field: value})  # type: ignore[type-var]


@pytest.mark.parametrize("value", [list("a" * 64), tuple("a" * 64), None, 64, b"a" * 64])
@pytest.mark.parametrize("field", ["request_digest", "marker_digest", "target_digest"])
def test_independent_digests_reject_non_string_containers(value: object, field: str) -> None:
    original = {
        "request_digest": INTENT,
        "marker_digest": MARKER,
        "target_digest": ACTIVATION,
    }[field]
    with pytest.raises(RecoveryDenied):
        replace(original, **{field: value})  # type: ignore[type-var]


def prepared() -> OwnerEvidence:
    return empty().prepare(INTENT, Checkpoint(), ActivationState.ACTIVE)


def test_intent_is_immutable_and_preparation_is_not_commit_evidence() -> None:
    with pytest.raises(FrozenInstanceError):
        INTENT.origin = Origin(ENVIRONMENT, UUID(int=10), GENERATION)  # type: ignore[misc]
    stream = prepared()
    assert stream.checkpoint.order == 1
    assert stream.certificates == ()
    assert stream.lookup(INTENT.mutation, INTENT.request_digest) is None
    assert stream.high_water == 0
    with pytest.raises(RecoveryDenied, match="publication_pending"):
        stream.require_sealable()
    assert empty().checkpoint == Checkpoint()


def test_prepare_retries_preserve_attempt_and_compare_complete_head() -> None:
    stream = prepared()
    assert stream.prepare(INTENT, stream.checkpoint, ActivationState.CLOSING) is stream
    assert stream.prepare(INTENT, Checkpoint(), ActivationState.ACTIVE) is stream
    with pytest.raises(RecoveryDenied):
        stream.prepare(INTENT, Checkpoint(1, "f" * 64), ActivationState.ACTIVE)
    another = replace(INTENT, mutation=UUID(int=10), attempt=UUID(int=11))
    with pytest.raises(RecoveryDenied, match="publication_pending"):
        stream.prepare(another, stream.checkpoint, ActivationState.ACTIVE)


@pytest.mark.parametrize("field", ["environment", "incarnation", "generation"])
def test_known_old_lineage_cannot_prepare_a_new_attempt(field: str) -> None:
    old = replace(INTENT, origin=replace(INTENT.origin, **{field: OTHER}))
    stream = empty()
    with pytest.raises(RecoveryDenied, match="timeline_reconciliation_required"):
        stream.prepare(old, stream.checkpoint, ActivationState.ACTIVE)
    assert stream.checkpoint == Checkpoint()
    assert stream.prepared is None


@pytest.mark.parametrize("state", [ActivationState.CLOSING, ActivationState.SEALED])
def test_closed_activation_does_not_issue_new_preparations(state: ActivationState) -> None:
    with pytest.raises(RecoveryDenied, match="recovery_unavailable"):
        empty().prepare(INTENT, Checkpoint(), state)


def test_certified_retry_has_one_evidence_effect_and_no_intent_substitution() -> None:
    stream = prepared()
    terminal = stream.certify(MARKER, stream.checkpoint, ActivationState.ACTIVE)
    assert terminal.checkpoint.order == 2
    assert terminal.prepared is None
    assert len(terminal.certificates) == 1
    assert terminal.certify(MARKER, terminal.checkpoint, ActivationState.SEALED) is terminal
    assert terminal.lookup(INTENT.mutation, INTENT.request_digest) == terminal.certificates[0]
    terminal.require_sealable()
    with pytest.raises(RecoveryDenied, match="mutation_digest_mismatch"):
        terminal.lookup(INTENT.mutation, "f" * 64)
    with pytest.raises(RecoveryDenied):
        terminal.certify(
            replace(MARKER, result_digest="f" * 64), terminal.checkpoint, ActivationState.ACTIVE
        )


def test_certificate_requires_exact_prepared_binding_and_unsealed_activation() -> None:
    stream = prepared()
    for intent in [
        replace(INTENT, attempt=OTHER),
        replace(INTENT, root=OTHER),
        replace(INTENT, owner=OTHER),
    ]:
        marker = replace(
            MARKER,
            intent=intent,
            result_digest=OUTCOME.result_digest(intent),
            affected_ids=(intent.root,),
        )
        with pytest.raises(RecoveryDenied):
            stream.certify(marker, stream.checkpoint, ActivationState.ACTIVE)
    with pytest.raises(RecoveryDenied):
        stream.certify(MARKER, stream.checkpoint, ActivationState.SEALED)
    with pytest.raises(RecoveryDenied):
        empty().certify(MARKER, Checkpoint(), ActivationState.ACTIVE)


def test_restored_receipt_is_only_historical_and_cannot_prepare_on_new_timeline() -> None:
    stream = prepared()
    terminal = stream.certify(MARKER, stream.checkpoint, ActivationState.ACTIVE)
    restored = replace(
        terminal, activation=replace(ACTIVATION, serial=2, incarnation=OTHER), generation=OTHER
    )
    certificate = restored.lookup(INTENT.mutation, INTENT.request_digest)
    assert certificate is not None and certificate.committed.intent.origin == INTENT.origin
    with pytest.raises(RecoveryDenied, match="timeline_reconciliation_required"):
        restored.prepare(INTENT, restored.checkpoint, ActivationState.ACTIVE)
    assert restored.checkpoint == terminal.checkpoint


def test_uncertain_prepared_delete_never_becomes_deletion_or_abort_by_timeout() -> None:
    stream = prepared()
    uncertain = stream.uncertain(stream.checkpoint)
    assert uncertain.prepared == INTENT
    assert uncertain.unresolved is True
    assert uncertain.certificates == ()
    assert uncertain.uncertain(uncertain.checkpoint) is uncertain
    with pytest.raises(RecoveryDenied, match="publication_pending"):
        uncertain.require_sealable()
    with pytest.raises(RecoveryDenied):
        empty().uncertain(Checkpoint())
    # Only a separately trusted original committed-marker observation resolves it.
    settled = uncertain.certify(MARKER, uncertain.checkpoint, ActivationState.CLOSING)
    settled.require_sealable()
    assert settled.unresolved is False


def test_owner_namespaces_and_minimal_independent_metadata() -> None:
    stream = empty()
    with pytest.raises(RecoveryDenied):
        stream.prepare(replace(INTENT, owner=OTHER), stream.checkpoint, ActivationState.ACTIVE)
    metadata = MARKER.metadata()
    assert set(metadata) == {
        "schema_version",
        "owner",
        "mutation",
        "attempt",
        "root",
        "environment",
        "incarnation",
        "generation",
        "activation_serial",
        "request_digest",
        "marker_digest",
        "result_digest",
        "outcome",
        "private_position",
        "erasure_epoch",
        "affected_ids",
        "retired_ids",
    }
    assert "payload" not in metadata and "command" not in metadata


def test_deletion_high_water_is_monotonic_and_requires_root_scope() -> None:
    stream = replace(prepared(), high_water=3)
    with pytest.raises(RecoveryDenied):
        stream.certify(MARKER, stream.checkpoint, ActivationState.ACTIVE)
    marker = replace(
        MARKER, erasure_epoch=4, retired_ids=(INTENT.root, OTHER), affected_ids=(INTENT.root, OTHER)
    )
    terminal = stream.certify(marker, stream.checkpoint, ActivationState.ACTIVE)
    assert terminal.high_water == 4
    assert terminal.certificates[0].committed.retired_ids == (INTENT.root, OTHER)
    with pytest.raises(RecoveryDenied):
        replace(marker, retired_ids=(OTHER,))
    with pytest.raises(RecoveryDenied):
        replace(marker, retired_ids=(INTENT.root, INTENT.root))


@pytest.mark.parametrize("restored,high_water,result", [(0, 3, 4), (4, 3, 5), (3, 3, 4)])
def test_recovery_epoch_exceeds_restored_and_certified_fences(
    restored: int, high_water: int, result: int
) -> None:
    assert next_erasure_epoch(restored, high_water) == result


@pytest.mark.parametrize("value", [-1, MAX_COUNTER, MAX_COUNTER + 1, True])
def test_invalid_or_overflowing_erasure_epoch_stays_closed(value: int) -> None:
    with pytest.raises(RecoveryDenied):
        next_erasure_epoch(0, value)


@pytest.mark.parametrize(
    "fault",
    [
        "owner",
        "nonce",
        "target",
        "activation",
        "serial",
        "stale_head",
        "divergent_head",
        "closed",
        "closing",
        "sealed",
    ],
)
def test_admission_requires_exact_fresh_request_target_and_checkpoint(fault: str) -> None:
    checkpoint = prepared().checkpoint
    assertion = Assertion(ACTIVATION, OWNER, NONCE, checkpoint, ActivationState.ACTIVE)
    target, serial, is_open = ACTIVATION.target_digest, 1, True
    if fault == "owner":
        assertion = replace(assertion, owner=OTHER)
    elif fault == "nonce":
        assertion = replace(assertion, nonce=OTHER)
    elif fault == "target":
        target = "f" * 64
    elif fault == "activation":
        assertion = replace(assertion, activation=replace(ACTIVATION, incarnation=OTHER))
    elif fault == "serial":
        serial = 2
    elif fault == "stale_head":
        assertion = replace(assertion, checkpoint=Checkpoint())
    elif fault == "divergent_head":
        assertion = replace(assertion, checkpoint=Checkpoint(checkpoint.order, "f" * 64))
    elif fault == "closed":
        is_open = False
    elif fault == "closing":
        assertion = replace(assertion, state=ActivationState.CLOSING)
    elif fault == "sealed":
        assertion = replace(assertion, state=ActivationState.SEALED)
    with pytest.raises(RecoveryDenied):
        validate_admission(
            assertion,
            owner=OWNER,
            nonce=NONCE,
            pinned=ACTIVATION,
            verified_target_digest=target,
            observed_serial=serial,
            local_checkpoint=checkpoint,
            local_open=is_open,
        )


def test_matching_admission_does_not_invent_freshness_from_time_or_revision() -> None:
    assertion = Assertion(ACTIVATION, OWNER, NONCE, Checkpoint(), ActivationState.ACTIVE)
    validate_admission(
        assertion,
        owner=OWNER,
        nonce=NONCE,
        pinned=ACTIVATION,
        verified_target_digest=ACTIVATION.target_digest,
        observed_serial=1,
        local_checkpoint=Checkpoint(),
        local_open=True,
    )


@pytest.mark.parametrize(
    "changes",
    [
        {"accepted_revision": 0},
        {"accepted_revision": True},
        {"accepted_revision": MAX_COUNTER + 1},
        {"accepted_at": "2026-02-30T00:00:00Z"},
        {"accepted_at": "2026-10-22T00:00:00+00:00"},
        {"accepted_at": "private workout notes"},
        {"error_code": OutcomeCode.NOT_FOUND},
        {"current_revision": 1},
        {"status": "accepted"},
    ],
)
def test_terminal_metadata_rejects_invalid_or_mixed_accepted_outcomes(
    changes: dict[str, object],
) -> None:
    with pytest.raises(RecoveryDenied):
        replace(OUTCOME, **changes)  # type: ignore[arg-type]


def test_rejected_and_conflicted_receipts_cannot_claim_domain_or_erasure_effects() -> None:
    conflict = TerminalOutcome(
        OutcomeStatus.CONFLICT,
        expected_revision=2,
        current_revision=3,
        error_code=OutcomeCode.REVISION_CONFLICT,
    )
    rejected = TerminalOutcome(OutcomeStatus.REJECTED, error_code=OutcomeCode.RETIRED_ID)
    for outcome in (conflict, rejected):
        marker = replace(
            MARKER,
            outcome=outcome,
            result_digest=outcome.result_digest(INTENT),
            private_position=None,
            affected_ids=(),
        )
        stream = prepared().certify(marker, prepared().checkpoint, ActivationState.ACTIVE)
        assert stream.certificates[0].committed.outcome.result(INTENT) == outcome.result(INTENT)
        for changes in (
            {"private_position": 1},
            {"retired_ids": (INTENT.root,)},
            {"affected_ids": (INTENT.root,)},
        ):
            with pytest.raises(RecoveryDenied):
                replace(marker, **changes)  # type: ignore[arg-type]
    with pytest.raises(RecoveryDenied):
        replace(conflict, current_revision=2)
    with pytest.raises(RecoveryDenied):
        replace(conflict, error_code=OutcomeCode.NOT_FOUND)
    with pytest.raises(RecoveryDenied):
        replace(rejected, error_code="notes from a workout")  # type: ignore[arg-type]
    with pytest.raises(RecoveryDenied):
        replace(MARKER, private_position=None)
    with pytest.raises(RecoveryDenied):
        replace(MARKER, outcome=replace(OUTCOME, accepted_revision=2))


def test_certified_attempt_identity_cannot_be_reused_for_another_mutation() -> None:
    stream = prepared().certify(MARKER, prepared().checkpoint, ActivationState.ACTIVE)
    another = replace(INTENT, mutation=OTHER)
    with pytest.raises(RecoveryDenied):
        stream.prepare(another, stream.checkpoint, ActivationState.ACTIVE)
    assert stream.prepared is None
    assert len(stream.certificates) == 1


@pytest.mark.parametrize(
    "changes",
    [
        {"affected_ids": ()},
        {"affected_ids": (INTENT.root, INTENT.root)},
        {"affected_ids": (OTHER,)},
        {"affected_ids": (INTENT.root, "private notes")},
        {"affected_ids": [INTENT.root]},
        {"retired_ids": (INTENT.root, OTHER)},
    ],
)
def test_affected_scope_is_immutable_uuid_metadata_and_covers_retirements(
    changes: dict[str, object],
) -> None:
    with pytest.raises(RecoveryDenied):
        replace(MARKER, **changes)  # type: ignore[arg-type]
