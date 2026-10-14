"""Run only after operator login/project selection; no secret arguments or output."""

import argparse
import json
import os

from sqlalchemy import create_engine
from sqlalchemy.engine import make_url

from daily_motion.config import Settings
from daily_motion.staging import provision, validate_admin_url, verify_isolation


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--confirm-project-ref", required=True)
    parser.add_argument("--verify-only", action="store_true")
    args = parser.parse_args()
    if os.environ.get("DM_ENVIRONMENT") != "staging":
        print("Staging environment confirmation required; no database changed")
        return 1
    engines = []
    try:
        # Runtime URL has the same project/transport, but a different database login.
        config = Settings()
        config.validate_hosted()
        runtime_url = make_url(config.database_url)
        if config.supabase_url.rstrip("/") != f"https://{args.confirm_project_ref}.supabase.co":
            raise ValueError()
        if runtime_url.host == f"db.{args.confirm_project_ref}.supabase.co":
            expected = "dm_staging_runtime"
        elif (runtime_url.host or "").endswith(".pooler.supabase.com"):
            expected = "dm_staging_runtime." + args.confirm_project_ref
        else:
            raise ValueError()
        if runtime_url.username != expected or runtime_url.database != "postgres":
            raise ValueError()
        if not args.verify_only:
            admin_url = os.environ["DM_STAGING_ADMIN_URL"]
            validate_admin_url(admin_url, args.confirm_project_ref)
            parsed_admin = make_url(admin_url)
            if parsed_admin.host != runtime_url.host or parsed_admin.port != runtime_url.port:
                raise ValueError()
            password = os.environ["DM_STAGING_RUNTIME_PASSWORD"]
            if runtime_url.password != password:
                raise ValueError()
            admin = create_engine(
                admin_url, hide_parameters=True, connect_args={"connect_timeout": 5}
            )
            engines.append(admin)
            provision(admin, password)
        runtime = create_engine(
            config.database_url, hide_parameters=True, connect_args={"connect_timeout": 5}
        )
        engines.append(runtime)
        print(json.dumps(verify_isolation(runtime)))
        return 0
    except Exception:
        # Provider/SQLAlchemy exceptions can echo passwords and queries. Never print them.
        print(
            "Staging preparation/verification failed; check protected settings and provider access"
        )
        return 1
    finally:
        for engine in engines:
            engine.dispose()


if __name__ == "__main__":
    raise SystemExit(main())
