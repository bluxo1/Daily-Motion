"""Provision a synthetic, signed local identity without putting server secrets in Flutter."""

import argparse
import json
import os
import secrets
from datetime import UTC, datetime, timedelta
from pathlib import Path
from uuid import uuid4

import jwt
from alembic import command
from alembic.config import Config
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec
from sqlalchemy import create_engine, text
from sqlalchemy.engine import make_url
from sqlalchemy.exc import ArgumentError
from sqlalchemy.orm import Session

from daily_motion.config import settings
from daily_motion.models import OwnerState


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mobile-api-url", default="http://10.0.2.2:8000")
    args = parser.parse_args()
    try:
        admin_url = make_url(os.environ["DM_DEV_ADMIN_URL"])
        if (
            admin_url.drivername != "postgresql+psycopg"
            or admin_url.host not in ("127.0.0.1", "localhost", "::1")
            or admin_url.database != "daily_motion"
            or admin_url.query
            or (admin_url.port is None and os.environ.get("PGPORT"))
            or any(
                os.environ.get(name)
                for name in ("PGHOSTADDR", "PGSERVICE", "PGSERVICEFILE", "PGOPTIONS")
            )
        ):
            raise ValueError()
    except (KeyError, ArgumentError, TypeError, ValueError):
        raise ValueError(
            "Development setup requires loopback PostgreSQL daily_motion "
            "without query or libpq routing overrides"
        ) from None
    root = Path(__file__).resolve().parents[3]
    output = root / ".tools/development-sync"
    output.mkdir(parents=True, exist_ok=True)
    os.environ["DM_DATABASE_URL"] = admin_url.render_as_string(hide_password=False)
    settings.cache_clear()
    config = Config(str(root / "services/api/alembic.ini"))
    config.set_main_option("script_location", str(root / "services/api/migrations"))
    command.upgrade(config, "head")
    admin = create_engine(admin_url)
    # The setup process alone uses migration authority. HTTP always uses forced RLS.
    with admin.begin() as db:
        db.execute(
            text("""
            DO $$ BEGIN
              IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='dm_development_runtime') THEN
                CREATE ROLE dm_development_runtime LOGIN PASSWORD 'local-synthetic-only'
                  NOSUPERUSER NOBYPASSRLS;
              END IF;
            END $$
        """)
        )
        flags = db.execute(
            text(
                "SELECT rolsuper, rolbypassrls FROM pg_roles WHERE rolname='dm_development_runtime'"
            )
        ).one()
        if flags.rolsuper or flags.rolbypassrls:
            raise ValueError("Development runtime role must be restricted")
        db.execute(text("GRANT USAGE ON SCHEMA training TO dm_development_runtime"))
        db.execute(
            text(
                "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES "
                "IN SCHEMA training TO dm_development_runtime"
            )
        )
    owner = uuid4()
    with Session(admin) as session, session.begin():
        session.add(
            OwnerState(
                owner_id=owner, status="active", generation=uuid4(), position=0, erasure_epoch=0
            )
        )
    admin.dispose()
    key = ec.generate_private_key(ec.SECP256R1())
    public_path = output / "public.pem"
    public_path.write_bytes(
        key.public_key().public_bytes(
            serialization.Encoding.PEM, serialization.PublicFormat.SubjectPublicKeyInfo
        )
    )
    issuer = "https://identity.daily-motion.test/auth/v1"
    now = datetime.now(UTC)
    token = jwt.encode(
        {
            "sub": str(owner),
            "iss": issuer,
            "aud": "authenticated",
            "iat": now,
            "exp": now + timedelta(hours=1),
        },
        key,
        algorithm="ES256",
    )
    # The private signing key is never written; rerunning creates a fresh synthetic owner.
    runtime = admin_url.set(username="dm_development_runtime", password="local-synthetic-only")
    (output / "api.env").write_text(
        f"DM_DATABASE_URL={runtime.render_as_string(hide_password=False)}\n"
        f"DM_ENVIRONMENT=development\nDM_JWT_ISSUER={issuer}\nDM_JWT_PUBLIC_KEY_FILE={public_path.as_posix()}\n"
        f"DM_SYNC_SIGNING_KEY={secrets.token_urlsafe(48)}\n",
        encoding="utf-8",
        newline="\n",
    )
    (output / "mobile.json").write_text(
        json.dumps(
            {
                "DM_FOUNDATION_FIXTURE": "true",
                "DM_TEST_OWNER": str(owner),
                "DM_API_URL": args.mobile_api_url,
                "DM_ACCESS_TOKEN": token,
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
        newline="\n",
    )
    print(
        "Synthetic identity configured in ignored .tools/development-sync; "
        "token expires in one hour."
    )


if __name__ == "__main__":
    main()
