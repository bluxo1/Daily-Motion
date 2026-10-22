"""File-backed local conformance emulator. Never a production authority adapter.

SQLite supplies deterministic local CAS/restart tests, not independent provider
custody, authenticated assertions, nonrollbackable storage or RC10/RC11 evidence.
Only tests import this module. It cannot activate/reopen any application target.
"""

import dataclasses
import json
import os
import sqlite3
import types
import typing
from collections.abc import Callable, Iterator, Mapping
from contextlib import closing, contextmanager
from enum import Enum
from pathlib import Path
from uuid import UUID

from pydantic import TypeAdapter

from daily_motion.recovery import (
    Activation,
    ActivationState,
    Assertion,
    Certificate,
    Checkpoint,
    CommittedMarker,
    Intent,
    OwnerEvidence,
    RecoveryDenied,
)

ACTIVATION_DUMPER = TypeAdapter(Activation)
OWNER_DUMPER = TypeAdapter(OwnerEvidence)


_UNION_ORIGINS = (typing.Union, types.UnionType)


def _decode_strict(raw: object, annotation: object) -> object:
    """Decode stored JSON with no coercion and no unknown/extra keys.

    Stored bodies are untrusted input: numeric/string/bool coercions, absent
    fields and unknown private-payload keys must all be denied, never adjusted.
    """
    origin = typing.get_origin(annotation)
    arguments = typing.get_args(annotation)
    if dataclasses.is_dataclass(annotation):
        if not isinstance(raw, dict):
            raise RecoveryDenied()
        hints = typing.get_type_hints(annotation)
        expected = {field.name for field in dataclasses.fields(annotation)}  # type: ignore[arg-type]
        if set(raw) != expected:
            raise RecoveryDenied()
        decoded = {
            field.name: _decode_strict(raw[field.name], hints[field.name])
            for field in dataclasses.fields(annotation)  # type: ignore[arg-type]
        }
        return annotation(**decoded)  # type: ignore[operator]
    if origin is tuple:
        if len(arguments) == 2 and arguments[1] is Ellipsis:
            if not isinstance(raw, list):
                raise RecoveryDenied()
            return tuple(_decode_strict(item, arguments[0]) for item in raw)
        raise RecoveryDenied()
    if origin is not None:
        if origin in _UNION_ORIGINS and len(arguments) == 2 and type(None) in arguments:
            other = arguments[0] if arguments[1] is type(None) else arguments[1]
            if raw is None:
                return None
            return _decode_strict(raw, other)
        raise RecoveryDenied()
    if isinstance(annotation, type):
        if annotation is UUID:
            if not isinstance(raw, str):
                raise RecoveryDenied()
            try:
                return UUID(raw)
            except ValueError:
                raise RecoveryDenied() from None
        if issubclass(annotation, Enum):
            # Enum members serialize as their value string in stored JSON.
            if type(raw) is not str:
                raise RecoveryDenied()
            try:
                return annotation(raw)
            except ValueError:
                raise RecoveryDenied() from None
        if annotation in (int, str, bool):
            if type(raw) is not annotation:
                raise RecoveryDenied()
            return raw
    raise RecoveryDenied()


_ST = typing.TypeVar("_ST")


def _strict_json_codec[ST](stream: type[ST]) -> Callable[[str], ST]:
    def decode(body: str) -> ST:
        if not isinstance(body, str):
            raise RecoveryDenied()
        try:
            raw = json.loads(body)
        except (json.JSONDecodeError, UnicodeDecodeError, ValueError):
            raise RecoveryDenied() from None
        return typing.cast(ST, _decode_strict(raw, stream))

    return decode


ACTIVATION_CODEC = _strict_json_codec(Activation)
OWNER_CODEC = _strict_json_codec(OwnerEvidence)


class ConformanceAuthority:
    def __init__(self, path: Path) -> None:
        self.path = path.resolve(strict=True)

    @classmethod
    def create(
        cls, path: Path, activation: Activation, owners: Mapping[UUID, UUID]
    ) -> "ConformanceAuthority":
        # Explicit isolated test setup; never truncate/reuse an existing file.
        descriptor = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
        os.close(descriptor)
        authority = cls(path)
        with authority.transaction() as db:
            db.execute("CREATE TABLE activation(body TEXT NOT NULL, state TEXT NOT NULL)")
            db.execute("CREATE TABLE owners(owner TEXT PRIMARY KEY, body TEXT NOT NULL)")
            db.execute(
                "INSERT INTO activation VALUES(?,?)",
                (ACTIVATION_DUMPER.dump_json(activation).decode(), ActivationState.ACTIVE),
            )
            for owner, generation in owners.items():
                stream = OwnerEvidence(owner, activation, generation)
                db.execute(
                    "INSERT INTO owners VALUES(?,?)",
                    (str(owner), OWNER_DUMPER.dump_json(stream).decode()),
                )
        return authority

    @contextmanager
    def transaction(self) -> Iterator[sqlite3.Connection]:
        try:
            # mode=rw forbids silently fabricating a missing/reset authority.
            with closing(sqlite3.connect(self.path.as_uri() + "?mode=rw", uri=True)) as db:
                db.execute("PRAGMA journal_mode=WAL")
                db.execute("PRAGMA synchronous=FULL")
                db.execute("BEGIN IMMEDIATE")
                try:
                    yield db
                    db.commit()
                except BaseException:
                    db.rollback()
                    raise
        except (sqlite3.Error, ValueError):
            raise RecoveryDenied() from None

    def _activation(self, db: sqlite3.Connection) -> tuple[Activation, ActivationState]:
        rows = db.execute("SELECT body,state FROM activation").fetchall()
        if len(rows) != 1:
            raise RecoveryDenied()
        return ACTIVATION_CODEC(rows[0][0]), ActivationState(rows[0][1])

    def _owner(self, db: sqlite3.Connection, owner: UUID) -> OwnerEvidence:
        row = db.execute("SELECT body FROM owners WHERE owner=?", (str(owner),)).fetchone()
        if row is None:
            raise RecoveryDenied()
        stream = OWNER_CODEC(row[0])
        activation, _ = self._activation(db)
        if stream.owner != owner or stream.activation != activation:
            raise RecoveryDenied()
        return stream

    def _write(self, db: sqlite3.Connection, stream: OwnerEvidence) -> None:
        db.execute(
            "UPDATE owners SET body=? WHERE owner=?",
            (OWNER_DUMPER.dump_json(stream).decode(), str(stream.owner)),
        )

    def current(self, activation: Activation, owner: UUID, nonce: UUID) -> Assertion:
        with self.transaction() as db:
            actual, state = self._activation(db)
            if actual != activation:
                raise RecoveryDenied()
            stream = self._owner(db, owner)
            return Assertion(actual, owner, nonce, stream.checkpoint, state)

    def prepare(self, intent: Intent, expected: Checkpoint) -> Checkpoint:
        with self.transaction() as db:
            _, state = self._activation(db)
            stream = self._owner(db, intent.owner).prepare(intent, expected, state)
            self._write(db, stream)
            return stream.preparation_checkpoint()

    def certify(self, marker: CommittedMarker, expected: Checkpoint) -> Certificate:
        with self.transaction() as db:
            _, state = self._activation(db)
            stream = self._owner(db, marker.intent.owner).certify(marker, expected, state)
            self._write(db, stream)
            result = stream.lookup(marker.intent.mutation, marker.intent.request_digest)
            assert result is not None
            return result

    def lookup(self, owner: UUID, mutation: UUID, request_digest: str) -> Certificate | None:
        with self.transaction() as db:
            return self._owner(db, owner).lookup(mutation, request_digest)

    def uncertain(self, owner: UUID, expected: Checkpoint) -> None:
        with self.transaction() as db:
            self._write(db, self._owner(db, owner).uncertain(expected))

    def close(self) -> None:
        with self.transaction() as db:
            _, state = self._activation(db)
            if state != ActivationState.ACTIVE:
                raise RecoveryDenied()
            db.execute("UPDATE activation SET state=?", (ActivationState.CLOSING,))

    def seal(self) -> None:
        with self.transaction() as db:
            _, state = self._activation(db)
            if state != ActivationState.CLOSING:
                raise RecoveryDenied()
            for (body,) in db.execute("SELECT body FROM owners").fetchall():
                OWNER_CODEC(body).require_sealable()
            db.execute("UPDATE activation SET state=?", (ActivationState.SEALED,))
