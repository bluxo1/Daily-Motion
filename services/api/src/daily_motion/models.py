from datetime import datetime
from typing import Any
from uuid import UUID

from sqlalchemy import (
    BigInteger,
    CheckConstraint,
    DateTime,
    ForeignKeyConstraint,
    Index,
    String,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    pass


class OwnerState(Base):
    __tablename__ = "owner_state"
    __table_args__ = {"schema": "training"}
    owner_id: Mapped[UUID] = mapped_column(primary_key=True)
    status: Mapped[str] = mapped_column(String(16), default="active")
    generation: Mapped[UUID]
    position: Mapped[int] = mapped_column(BigInteger, default=0)
    erasure_epoch: Mapped[int] = mapped_column(BigInteger, default=0)
    minimum_position: Mapped[int] = mapped_column(BigInteger, default=0)
    minimum_sync_contract: Mapped[int] = mapped_column(default=1)


class Profile(Base):
    __tablename__ = "profiles"
    __table_args__ = {"schema": "training"}
    owner_id: Mapped[UUID] = mapped_column(primary_key=True)
    unit: Mapped[str] = mapped_column(String(2), default="kg")


class AccountRetirement(Base):
    __tablename__ = "account_retirements"
    __table_args__ = {"schema": "training"}
    owner_id: Mapped[UUID] = mapped_column(primary_key=True)
    retired_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class Workout(Base):
    __tablename__ = "workouts"
    __table_args__ = (
        CheckConstraint("revision > 0"),
        {"schema": "training"},
    )
    owner_id: Mapped[UUID] = mapped_column(primary_key=True)
    id: Mapped[UUID] = mapped_column(primary_key=True)
    revision: Mapped[int] = mapped_column(BigInteger)
    name: Mapped[str] = mapped_column(String(120))
    timezone: Mapped[str] = mapped_column(String(80))
    status: Mapped[str] = mapped_column(String(16))
    started_at: Mapped[str]
    ended_at: Mapped[str | None]


class Exercise(Base):
    __tablename__ = "exercises"
    __table_args__ = (
        ForeignKeyConstraint(
            ["owner_id", "session_id"],
            ["training.workouts.owner_id", "training.workouts.id"],
            ondelete="CASCADE",
        ),
        {"schema": "training"},
    )
    owner_id: Mapped[UUID] = mapped_column(primary_key=True)
    id: Mapped[UUID] = mapped_column(primary_key=True)
    session_id: Mapped[UUID]
    ordinal: Mapped[int]
    definition: Mapped[dict[str, Any]] = mapped_column(JSONB)


class WorkoutSet(Base):
    __tablename__ = "sets"
    __table_args__ = (
        ForeignKeyConstraint(
            ["owner_id", "exercise_id"],
            ["training.exercises.owner_id", "training.exercises.id"],
            ondelete="CASCADE",
        ),
        {"schema": "training"},
    )
    owner_id: Mapped[UUID] = mapped_column(primary_key=True)
    id: Mapped[UUID] = mapped_column(primary_key=True)
    exercise_id: Mapped[UUID]
    ordinal: Mapped[int]
    prescription: Mapped[dict[str, Any]] = mapped_column(JSONB)
    observation: Mapped[dict[str, Any] | None] = mapped_column(JSONB, nullable=True)


class ObservationRevision(Base):
    __tablename__ = "observations"
    __table_args__ = {"schema": "training"}
    owner_id: Mapped[UUID] = mapped_column(primary_key=True)
    session_id: Mapped[UUID] = mapped_column(primary_key=True)
    revision: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    set_id: Mapped[UUID]
    position: Mapped[int] = mapped_column(BigInteger)
    generation: Mapped[UUID]
    payload: Mapped[dict[str, Any]] = mapped_column(JSONB)


class Receipt(Base):
    __tablename__ = "receipts"
    __table_args__ = {"schema": "training"}
    owner_id: Mapped[UUID] = mapped_column(primary_key=True)
    mutation_id: Mapped[UUID] = mapped_column(primary_key=True)
    digest: Mapped[str] = mapped_column(String(64))
    acknowledgement: Mapped[dict[str, Any]] = mapped_column(JSONB)


class Change(Base):
    __tablename__ = "changes"
    __table_args__ = {"schema": "training"}
    owner_id: Mapped[UUID] = mapped_column(primary_key=True)
    position: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    session_id: Mapped[UUID]
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    body: Mapped[dict[str, Any]] = mapped_column(JSONB)


class RetiredId(Base):
    __tablename__ = "retired_ids"
    __table_args__ = {"schema": "training"}
    owner_id: Mapped[UUID] = mapped_column(primary_key=True)
    id: Mapped[UUID] = mapped_column(primary_key=True)


class Snapshot(Base):
    __tablename__ = "snapshots"
    __table_args__ = {"schema": "training"}
    owner_id: Mapped[UUID] = mapped_column(primary_key=True)
    id: Mapped[UUID] = mapped_column(primary_key=True)
    generation: Mapped[UUID]
    erasure_epoch: Mapped[int] = mapped_column(BigInteger)
    position: Mapped[int] = mapped_column(BigInteger)
    installation_id: Mapped[UUID]
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    pages: Mapped[list[dict[str, Any]]] = mapped_column(JSONB)
    sync_contract: Mapped[int] = mapped_column(default=1)


class Routine(Base):
    __tablename__ = "routines"
    __table_args__ = (
        CheckConstraint("revision > 0"),
        ForeignKeyConstraint(["owner_id"], ["training.owner_state.owner_id"]),
        ForeignKeyConstraint(
            ["owner_id", "id", "current_template_id"],
            [
                "training.routine_templates.owner_id",
                "training.routine_templates.routine_id",
                "training.routine_templates.id",
            ],
            deferrable=True,
            initially="DEFERRED",
            use_alter=True,
            name="routine_current_template",
        ),
        {"schema": "training"},
    )
    owner_id: Mapped[UUID] = mapped_column(primary_key=True)
    id: Mapped[UUID] = mapped_column(primary_key=True)
    revision: Mapped[int] = mapped_column(BigInteger)
    current_template_id: Mapped[UUID]


class RoutineTemplate(Base):
    __tablename__ = "routine_templates"
    __table_args__ = (
        UniqueConstraint("owner_id", "routine_id", "id"),
        UniqueConstraint("owner_id", "routine_id", "revision"),
        CheckConstraint("revision > 0"),
        CheckConstraint("(revision=1)=(predecessor_template_id IS NULL)"),
        Index("routine_template_predecessor", "owner_id", "routine_id", "predecessor_template_id"),
        ForeignKeyConstraint(
            ["owner_id", "routine_id"],
            ["training.routines.owner_id", "training.routines.id"],
            ondelete="CASCADE",
        ),
        ForeignKeyConstraint(
            ["owner_id", "routine_id", "predecessor_template_id"],
            [
                "training.routine_templates.owner_id",
                "training.routine_templates.routine_id",
                "training.routine_templates.id",
            ],
        ),
        {"schema": "training"},
    )
    owner_id: Mapped[UUID] = mapped_column(primary_key=True)
    id: Mapped[UUID] = mapped_column(primary_key=True)
    routine_id: Mapped[UUID]
    revision: Mapped[int] = mapped_column(BigInteger)
    predecessor_template_id: Mapped[UUID | None]
    prescription: Mapped[dict[str, Any]] = mapped_column(JSONB)
