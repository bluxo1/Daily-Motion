"""Keep destructive integration setup inside the explicit local test database."""

import os

from sqlalchemy.engine import make_url
from sqlalchemy.exc import ArgumentError


def validate_local_test_target(raw: str) -> None:
    try:
        target = make_url(raw)
        if (
            target.drivername != "postgresql+psycopg"
            or target.host not in {"localhost", "127.0.0.1", "::1"}
            or target.database != "daily_motion_test"
            or target.query
            or (target.port is None and os.environ.get("PGPORT"))
            or any(
                os.environ.get(name)
                for name in ("PGHOSTADDR", "PGSERVICE", "PGSERVICEFILE", "PGOPTIONS")
            )
        ):
            raise ValueError()
    except (ArgumentError, TypeError, ValueError):
        # Parse errors can contain the original URL, including its password.
        raise RuntimeError(
            "Integration tests require local PostgreSQL daily_motion_test "
            "without query or libpq routing overrides"
        ) from None
