"""Routine-capable sync contract 3. Contract 2 remains reserved for DRP/2.

Workout operation envelopes are the original contract, including frozen bytes.
Routine prescriptions are snapshots, never private catalog definitions.
"""

import re
from typing import Annotated, Any, Literal
from uuid import UUID

from pydantic import BeforeValidator, Field, field_validator, model_validator

from daily_motion.contracts import (
    BATCH_LIMIT,
    COMMAND_LIMIT,
    CanonicalUuidV2,
    CreateSession,
    ErasedChange,
    MutationResult,
    Operation,
    PlannedSet,
    Prescription,
    RootProjection,
    StrictModel,
    UtcInstant,
    canonical_json,
)

_DART_WHITE_SPACE = (
    "\u0009\u000a\u000b\u000c\u000d\u0020\u0085\u00a0\u1680"
    "\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007\u2008\u2009\u200a"
    "\u2028\u2029\u202f\u205f\u3000\ufeff"
)

# Match the pinned native uuid reader, including its explicit nil/max cases.
# These are planning identities; frozen workout/DRP command rules stay intact.
_PLANNING_UUID_PATTERN = (
    r"^(?:[0-9a-f]{8}-[0-9a-f]{4}-[0-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}"
    r"|00000000-0000-0000-0000-000000000000|ffffffff-ffff-ffff-ffff-ffffffffffff)$"
)


def _planning_uuid(value: object) -> object:
    if not isinstance(value, (str, UUID)) or not re.fullmatch(_PLANNING_UUID_PATTERN, str(value)):
        raise ValueError("Use a canonical lowercase planning UUID supported by the native reader")
    return value


PlanningUuid = Annotated[
    UUID,
    BeforeValidator(_planning_uuid),
    Field(json_schema_extra={"pattern": _PLANNING_UUID_PATTERN}),
]


class RoutineTargets(Prescription):
    # The existing native RoutinePlan reader requires an explicit rest target.
    rest_seconds: Annotated[int, Field(strict=True, ge=0, le=3600)]


class RoutineSet(PlannedSet):
    set_id: PlanningUuid
    set_class: Literal["warmup", "working"]
    set_purpose: Literal["regular", "top", "backoff"]
    planned: RoutineTargets


class RoutineExercise(StrictModel):
    session_exercise_id: PlanningUuid
    variant_id: PlanningUuid
    name: Annotated[str, Field(min_length=1, max_length=120)]
    loading_basis: Literal[
        "total_external",
        "per_implement",
        "machine_stack",
        "added_bodyweight",
        "assistance",
        "bodyweight_only",
    ]
    rep_convention: Literal["bilateral", "per_side", "alternating_total"]
    side: Literal["left", "right", "both", "unspecified"] = "both"
    sets: Annotated[list[RoutineSet], Field(min_length=1, max_length=100)]


class RoutinePrescription(StrictModel):
    # This is the currently implemented local routine domain, not an expansion
    # of workout timezone support. Starting a workout still chooses its timezone.
    name: Annotated[str, Field(min_length=1, max_length=120)]
    timezone: Literal["UTC", "Asia/Kolkata", "Asia/Calcutta"]
    exercises: Annotated[list[RoutineExercise], Field(min_length=1, max_length=50)]

    @model_validator(mode="after")
    def supported_routine(self) -> "RoutinePrescription":
        # Python strip() disagrees with native Dart trim() on BOM and several
        # control characters. Match the pinned mobile reader without rewriting
        # accepted names or changing the established workout contract.
        if not self.name.strip(_DART_WHITE_SPACE) or any(
            not exercise.name.strip(_DART_WHITE_SPACE) for exercise in self.exercises
        ):
            raise ValueError("Name the routine and exercises")
        CreateSession.model_validate(self.model_dump(mode="json", exclude_unset=True))
        if any(
            item.set_purpose == "backoff" and item.set_class != "working"
            for exercise in self.exercises
            for item in exercise.sets
        ):
            raise ValueError("Back-off sets must be working sets")
        return self


def _reserve_routine_capacity(prescription: dict[str, Any]) -> None:
    """Same worst-case bounds as RoutinePlan; these are reservations, not commands."""
    identity = "00000000-0000-4000-8000-000000000000"
    instant = "9999-12-31T23:59:59.999999Z"
    common = {
        "mutation_id": identity,
        "installation_id": identity,
        "aggregate_id": identity,
        "expected_revision": 9223372036854775807,
        "occurred_at": instant,
        "recorded_at": instant,
    }
    workout = {
        **common,
        "schema_version": 2,
        "aggregate_type": "workout_session",
        "command": "create_session",
        "environment_id": identity,
        "origin_incarnation": identity,
        "origin_generation": identity,
        "payload": {**prescription, "timezone": "Asia/Calcutta"},
    }
    routine = {
        **common,
        "aggregate_type": "routine",
        "command": "publish_template",
        "payload": {
            "template_id": identity,
            "predecessor_template_id": identity,
            "prescription": prescription,
        },
    }
    if any(len(canonical_json(body).encode()) > COMMAND_LIMIT for body in (workout, routine)):
        raise ValueError("Routine exceeds reserved start/sync capacity")


class PublishRoutineTemplate(StrictModel):
    template_id: PlanningUuid
    predecessor_template_id: PlanningUuid | None
    prescription: RoutinePrescription

    @model_validator(mode="after")
    def startable(self) -> "PublishRoutineTemplate":
        _reserve_routine_capacity(self.prescription.model_dump(mode="json", exclude_unset=True))
        return self


class RoutineOperation(StrictModel):
    mutation_id: CanonicalUuidV2
    installation_id: CanonicalUuidV2
    aggregate_type: Literal["routine"]
    aggregate_id: PlanningUuid
    expected_revision: Annotated[int, Field(strict=True, ge=0, le=9223372036854775807)]
    command: Literal["create_routine", "publish_template"]
    occurred_at: UtcInstant
    recorded_at: UtcInstant
    payload: dict[str, Any] = Field(
        json_schema_extra={
            "x-command-schemas": {
                "create_routine": "PublishRoutineTemplate",
                "publish_template": "PublishRoutineTemplate",
            }
        }
    )

    @model_validator(mode="after")
    def valid_template(self) -> "RoutineOperation":
        template = PublishRoutineTemplate.model_validate(self.payload)
        if self.command == "create_routine":
            if self.expected_revision != 0 or template.predecessor_template_id is not None:
                raise ValueError("A new routine has no predecessor and expects revision zero")
        elif self.expected_revision == 0 or template.predecessor_template_id is None:
            raise ValueError("Publication requires an accepted predecessor")
        # Reuse the existing actual-instant validation, without inheriting its
        # workout-only command enum or adding recovery provenance.
        Operation.utc_instant(self.occurred_at)
        Operation.utc_instant(self.recorded_at)
        if len(canonical_json(self.model_dump(mode="json")).encode()) > COMMAND_LIMIT:
            raise ValueError("Command exceeds the 256 KiB limit")
        return self


SyncOperation3 = Annotated[Operation | RoutineOperation, Field(discriminator="aggregate_type")]


class PushRequest3(StrictModel):
    schema_version: Literal[3]
    operations: Annotated[list[SyncOperation3], Field(min_length=1, max_length=50)]

    @field_validator("schema_version", mode="before")
    @classmethod
    def exact_version(cls, value: Any) -> Any:
        if type(value) is not int or value != 3:
            raise ValueError("Use integer contract version 3")
        return value

    @model_validator(mode="after")
    def independent_heads(self) -> "PushRequest3":
        if len({(op.aggregate_type, op.aggregate_id) for op in self.operations}) != len(
            self.operations
        ):
            raise ValueError("Send at most one head per aggregate")
        if len({op.mutation_id for op in self.operations}) != len(self.operations):
            raise ValueError("Mutation identities must be distinct")
        if len(canonical_json(self.model_dump(mode="json")).encode()) > BATCH_LIMIT:
            raise ValueError("Batch exceeds the 1 MiB limit")
        return self


class SyncContext3(StrictModel):
    schema_version: Literal[3] = 3
    owner_id: UUID
    generation: UUID
    erasure_epoch: Annotated[int, Field(strict=True, ge=0)]


class MeResponse3(SyncContext3):
    position: Annotated[int, Field(strict=True, ge=0)]
    minimum_position: Annotated[int, Field(strict=True, ge=0)]
    account_status: Literal["active"] = "active"
    command_limit: Literal[262144] = 262144
    batch_limit: Literal[1048576] = 1048576
    page_limit: Literal[524288] = 524288
    snapshot_limit: Literal[67108864] = 67108864


class PushResponse3(SyncContext3):
    results: list[MutationResult]


class LiveChange3(StrictModel):
    position: Annotated[int, Field(strict=True, ge=1)]
    operation: SyncOperation3
    revision: Annotated[int, Field(strict=True, ge=1)]


class PullResponse3(SyncContext3):
    changes: list[LiveChange3 | ErasedChange]
    next_cursor: str
    next_position: Annotated[int, Field(strict=True, ge=0)]
    has_more: bool


class AcceptedTemplate(StrictModel):
    template_id: PlanningUuid
    predecessor_template_id: PlanningUuid | None
    revision: Annotated[int, Field(strict=True, ge=1)]
    prescription: RoutinePrescription


class RoutineProjection(StrictModel):
    aggregate_type: Literal["routine"] = "routine"
    aggregate_id: PlanningUuid
    revision: Annotated[int, Field(strict=True, ge=1)]
    current_template_id: PlanningUuid
    # A root's immutable history can span pages. The complete snapshot must
    # contain exactly revision templates, ordered from offset zero without gaps.
    template_offset: Annotated[int, Field(strict=True, ge=0)]
    templates: Annotated[list[AcceptedTemplate], Field(min_length=1)]


class SnapshotPage3(StrictModel):
    roots: list[RootProjection]
    routines: list[RoutineProjection]
    retired_ids: list[UUID]


class BootstrapManifest3(SyncContext3):
    installation_id: UUID
    token: str
    page_count: Annotated[int, Field(strict=True, ge=1, le=4096)]
    checksums: list[Annotated[str, Field(pattern="^[a-f0-9]{64}$")]]
    cursor: str
    position: Annotated[int, Field(strict=True, ge=0)]
    expires_at: UtcInstant
