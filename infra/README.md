# Local PostgreSQL

This development service contains synthetic data only. It binds PostgreSQL to
`127.0.0.1:25432`; no Supabase project or cloud deployment is created.

[QUALIFICATION.md](QUALIFICATION.md) records the operator-managed hosted-provider,
region/backup/processor, review and signing prerequisites. None is inferred from
local PostgreSQL or remote unsigned builds.

```sh
docker compose -f infra/compose.yaml up -d
docker compose -f infra/compose.yaml exec -T postgres createdb -U dm_admin daily_motion_test
```

The integration suite refuses a database whose name is not `daily_motion_test`.
It rebuilds the private training schema there, runs Alembic and grants a separate
`NOSUPERUSER NOBYPASSRLS` test role. Test schema cleanup is destructive inside
that dedicated database. Keep it separate from development/personal data.

Migrations use administrator credentials. API processes use a non-owner runtime
role with `USAGE` on `training` and `SELECT, INSERT, UPDATE, DELETE` on its tables.
Do not expose `training` through the Supabase Data API. Verified account
initialization uses the runtime role after JWT/current-provider checks; tests
also seed synthetic owners with the migration connection. Migration `0003`
adds profiles and account-retirement RLS; apply grants to the new tables. No
runtime update/delete RLS policy permits removal of retirement markers.

Stop the service without removing its volume:

```sh
docker compose -f infra/compose.yaml stop
```
