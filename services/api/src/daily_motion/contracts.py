"""The intentionally small Phase 0 command surface; future commands fail closed."""

import json
import re
from datetime import datetime
from decimal import Decimal
from typing import Annotated, Any, Literal
from uuid import UUID
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

COMMAND_LIMIT = 256 * 1024
BATCH_LIMIT = 1024 * 1024
PAGE_LIMIT = 512 * 1024
SNAPSHOT_LIMIT = 64 * 1024 * 1024
NONBLANK_REASON = (
    r"[^ \t\r\n\f\v\u0085\u00A0\u1680\u2000-\u200A"
    r"\u2028\u2029\u202F\u205F\u3000\uFEFF\u001C-\u001F]"
)
DecimalText = Annotated[str, Field(pattern=r"^(0|[1-9]\d{0,6})(\.\d{1,6})?$")]
UtcInstant = Annotated[
    str,
    Field(
        pattern=r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?Z$",
        json_schema_extra={"format": "date-time"},
    ),
]


def canonical_json(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class Load(StrictModel):
    value: DecimalText
    unit: Literal["kg", "lb"]
    basis: Literal[
        "total_external", "per_implement", "machine_stack", "added_bodyweight", "assistance"
    ]


class Effort(StrictModel):
    scale: Literal["rir", "rpe"]
    value: DecimalText
    source: Literal["self_reported"] = "self_reported"

    @model_validator(mode="after")
    def valid_range(self) -> "Effort":
        number = Decimal(self.value)
        if self.scale == "rir" and (number > 10 or number != number.to_integral_value()):
            raise ValueError("RIR must be a whole number from 0 to 10")
        if self.scale == "rpe" and (not 1 <= number <= 10 or number * 2 % 1):
            raise ValueError("RPE must be from 1 to 10 in half steps")
        return self


class Actual(StrictModel):
    load: Load | None
    reps: Annotated[int, Field(strict=True, ge=0, le=999)]
    rep_convention: Literal["bilateral", "per_side", "alternating_total"]
    effort: Effort | None = None


class Prescription(StrictModel):
    reps: Annotated[int, Field(strict=True, ge=1, le=999)] | None = None
    load: Load | None = None
    rest_seconds: Annotated[int, Field(strict=True, ge=0, le=3600)] = 120


class PlannedSet(StrictModel):
    set_id: UUID
    set_class: Literal["warmup", "working"] = "working"
    set_purpose: Literal["regular", "top", "backoff"] = "regular"
    planned: Prescription


class ExerciseSnapshot(StrictModel):
    session_exercise_id: UUID
    variant_id: UUID
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
    sets: Annotated[list[PlannedSet], Field(min_length=1, max_length=100)]

    @model_validator(mode="after")
    def unique_sets(self) -> "ExerciseSnapshot":
        if len({item.set_id for item in self.sets}) != len(self.sets):
            raise ValueError("Set IDs must be unique")
        for item in self.sets:
            if item.planned.load and item.planned.load.basis != self.loading_basis:
                raise ValueError("Planned load must follow the exercise convention")
        return self


class CreateSession(StrictModel):
    name: Annotated[str, Field(min_length=1, max_length=120)]
    timezone: Annotated[str, Field(max_length=80)]
    exercises: Annotated[list[ExerciseSnapshot], Field(min_length=1, max_length=50)]

    @field_validator("timezone")
    @classmethod
    def valid_timezone(cls, value: str) -> str:
        try:
            ZoneInfo(value)
        except ZoneInfoNotFoundError as error:
            raise ValueError("Use a supported IANA timezone") from error
        return value

    @model_validator(mode="after")
    def unique_children(self) -> "CreateSession":
        identifiers = [exercise.session_exercise_id for exercise in self.exercises]
        identifiers.extend(item.set_id for exercise in self.exercises for item in exercise.sets)
        if len(set(identifiers)) != len(identifiers):
            raise ValueError("All child IDs must be distinct")
        return self


class RecordSet(StrictModel):
    session_exercise_id: UUID
    set_id: UUID
    execution_status: Literal["completed", "partial", "failed", "skipped"]
    actual: Actual | None
    completion_seq: Annotated[int, Field(strict=True, ge=1)]
    order_source: Literal["logged"] = "logged"
    correction_reason: (
        Annotated[str, Field(min_length=1, max_length=240, pattern=NONBLANK_REASON)] | None
    ) = None

    @model_validator(mode="after")
    def valid_outcome(self) -> "RecordSet":
        if self.execution_status == "skipped":
            if self.actual is not None:
                raise ValueError("Skipped sets have no actual observation")
        elif self.actual is None:
            raise ValueError("Performed/attempted sets require an observation")
        elif self.execution_status != "failed" and self.actual.reps == 0:
            raise ValueError("Zero reps requires an explicit failed attempt")
        return self


class EmptyPayload(StrictModel):
    pass


class Operation(StrictModel):
    mutation_id: UUID
    installation_id: UUID
    aggregate_type: Literal["workout_session"]
    aggregate_id: UUID
    expected_revision: Annotated[int, Field(strict=True, ge=0)]
    command: Literal[
        "create_session",
        "record_set",
        "correct_set",
        "complete_session",
        "abandon_session",
        "delete_session",
    ]
    occurred_at: UtcInstant
    recorded_at: UtcInstant
    payload: dict[str, Any] = Field(
        json_schema_extra={
            "x-command-schemas": {
                "create_session": "CreateSession",
                "record_set": "RecordSet",
                "correct_set": "RecordSet",
                "complete_session": "EmptyPayload",
                "abandon_session": "EmptyPayload",
                "delete_session": "EmptyPayload",
            }
        }
    )

    @field_validator("occurred_at", "recorded_at")
    @classmethod
    def utc_instant(cls, value: str) -> str:
        if not re.fullmatch(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?Z", value):
            raise ValueError("Use a UTC RFC3339 instant ending in Z")
        datetime.fromisoformat(value)
        return value

    @model_validator(mode="after")
    def validate_command(self) -> "Operation":
        if self.command == "create_session":
            CreateSession.model_validate(self.payload)
            if self.expected_revision != 0:
                raise ValueError("Creates must expect revision zero")
        elif self.command in {"record_set", "correct_set"}:
            record = RecordSet.model_validate(self.payload)
            if self.command == "correct_set" and not record.correction_reason:
                raise ValueError("Historical corrections require a reason")
            if self.command == "record_set" and record.correction_reason is not None:
                raise ValueError("Use correct_set to make a correction")
        else:
            EmptyPayload.model_validate(self.payload)
        if len(canonical_json(self.model_dump(mode="json")).encode()) > COMMAND_LIMIT:
            raise ValueError("Command exceeds the 256 KiB limit")
        return self


class PushRequest(StrictModel):
    schema_version: Literal[1]
    operations: Annotated[list[Operation], Field(min_length=1, max_length=50)]

    @model_validator(mode="after")
    def independent_heads(self) -> "PushRequest":
        if len({op.aggregate_id for op in self.operations}) != len(self.operations):
            raise ValueError("Send at most one head per aggregate")
        if len(canonical_json(self.model_dump(mode="json")).encode()) > BATCH_LIMIT:
            raise ValueError("Batch exceeds the 1 MiB limit")
        return self


class SyncContext(StrictModel):
    schema_version: Literal[1] = 1
    owner_id: UUID
    generation: UUID
    erasure_epoch: Annotated[int, Field(strict=True, ge=0)]


class MeResponse(SyncContext):
    position: Annotated[int, Field(strict=True, ge=0)]
    minimum_position: Annotated[int, Field(strict=True, ge=0)]
    account_status: Literal["active"] = "active"
    command_limit: Literal[262144] = 262144
    batch_limit: Literal[1048576] = 1048576
    page_limit: Literal[524288] = 524288
    snapshot_limit: Literal[67108864] = 67108864


class OperationError(StrictModel):
    code: str
    retryable: Literal[False] = False


class AcceptedResult(StrictModel):
    mutation_id: UUID
    aggregate_id: UUID
    status: Literal["accepted", "duplicate"]
    accepted_revision: Annotated[int, Field(strict=True, ge=1)]
    accepted_at: UtcInstant


class ConflictResult(StrictModel):
    mutation_id: UUID
    aggregate_id: UUID
    status: Literal["conflict"]
    expected_revision: Annotated[int, Field(strict=True, ge=0)]
    current_revision: Annotated[int, Field(strict=True, ge=0)]
    error: OperationError


class RejectedResult(StrictModel):
    mutation_id: UUID
    aggregate_id: UUID
    status: Literal["rejected"]
    error: OperationError


MutationResult = Annotated[
    AcceptedResult | ConflictResult | RejectedResult, Field(discriminator="status")
]


class PushResponse(SyncContext):
    results: list[MutationResult]


class LiveChange(StrictModel):
    position: Annotated[int, Field(strict=True, ge=1)]
    operation: Operation
    revision: Annotated[int, Field(strict=True, ge=1)]


class ErasedChange(StrictModel):
    position: Annotated[int, Field(strict=True, ge=1)]
    aggregate_id: UUID
    redacted: Literal[True]
    retired_ids: list[UUID]


class PullResponse(SyncContext):
    changes: list[LiveChange | ErasedChange]
    next_cursor: str
    next_position: Annotated[int, Field(strict=True, ge=0)]
    has_more: bool


class Observation(RecordSet):
    occurred_at: UtcInstant
    recorded_at: UtcInstant


class ProjectedSet(PlannedSet):
    observation: Observation | None


class ProjectedExercise(ExerciseSnapshot):
    sets: Annotated[list[ProjectedSet], Field(min_length=1, max_length=100)]  # type: ignore[assignment]


class RootProjection(StrictModel):
    aggregate_id: UUID
    revision: Annotated[int, Field(strict=True, ge=1)]
    name: Annotated[str, Field(min_length=1, max_length=120)]
    timezone: Annotated[str, Field(max_length=80)]
    status: Literal["active", "completed", "abandoned"]
    started_at: UtcInstant
    ended_at: UtcInstant | None
    exercises: Annotated[list[ProjectedExercise], Field(min_length=1, max_length=50)]


class BootstrapRequest(StrictModel):
    installation_id: UUID


class AccountInitializeRequest(StrictModel):
    pass


class MinimalProfile(StrictModel):
    unit: Literal["kg", "lb"]


class AccountResponse(MeResponse):
    profile: MinimalProfile


class BootstrapManifest(SyncContext):
    installation_id: UUID
    token: str
    page_count: Annotated[int, Field(strict=True, ge=1, le=4096)]
    checksums: list[Annotated[str, Field(pattern="^[a-f0-9]{64}$")]]
    cursor: str
    position: Annotated[int, Field(strict=True, ge=0)]
    expires_at: UtcInstant


class SnapshotPage(StrictModel):
    roots: list[RootProjection]
    retired_ids: list[UUID]
