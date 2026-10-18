# Phase 0 recovery preparation

This is a tested local recovery procedure and an operator approval handoff.
It does not qualify hosted backup/restore. Phase 0 remains in progress and
Phase 1 has not started. [Qualification dependencies](QUALIFICATION.md) remain
authoritative for operator access and approvals.

## Local PostgreSQL rehearsal — 2026-10-18

Read the existing synthetic `daily_motion_test` database in the repository's
`infra-postgres-1` container. Verify the Docker endpoint is local, the container's
Compose working directory is this repository's `infra/`, and the image is the
expected PostgreSQL 17.7 image. Do not select another project's container.

1. Record Alembic revision, table counts, forced-RLS flags, canonical row
   fingerprints, policy definitions, constraints and indexes. This snapshot
   contains one workout, three sets, one receipt and one feed change; observations,
   profiles, retirements and snapshots are empty and supply no nonempty recovery
   coverage.
2. Use `pg_dump --format=custom --no-owner --no-password` through the source
   container's Unix socket. Keep the archive in process memory; record its SHA-256
   and size without copying row bodies, credentials or role verifiers into logs.
   This rehearsal does not retain an off-site backup.
3. Start a new temporary container from the same local image ID, with no network,
   no published ports and a tmpfs data directory. Bind cleanup to the exact
   newly created container ID and a unique rehearsal label. Never restore into
   the source or an existing provider/database.
4. Wait for the final PostgreSQL process and a successful query in the destination
   database. `pg_isready` alone can answer during image initialization.
5. Restore with `pg_restore --exit-on-error --single-transaction --no-owner`.
   First omit the restricted ACL role: restoration must fail and leave zero
   training tables. Create only the expected restricted, non-owner, **NOLOGIN**
   test role; no source password/verifier is copied. Repeat with a truncated
   archive and require atomic failure before restoring the complete archive.
6. Compare all row, policy, constraint and index fingerprints. Require Alembic
   `0003`, 11 training tables and enabled/forced RLS everywhere. Verify that the
   matching owner sees its workout, an unrelated/unset owner sees none, owner
   reassignment is rejected and duplicate receipt insertion is rejected. These
   SQL checks do not requalify the full Flutter/HTTP retry path after restoration.
7. Recheck that the source fingerprint is unchanged. Stop the exact temporary
   container and confirm automatic removal has finished; an immediate inspection
   can race asynchronous removal.

The final rehearsal passes, including both failed-restore attacks and confirmed
cleanup. The first helper attempt failed before its rollback check; initialization
timing was suspected but not independently reproduced. Stronger startup checks
were applied. A later immediate cleanup inspection also required bounded waiting.
[Actual results](../docs/evidence/phase0-recovery-and-connection-guards-2026-10-18.json).

## Hosted recovery approval package

Before any hosted export, restoration, project creation, paid plan change or
credential reset, the operator must approve the exact source, destination and
operation. The destructive integration fixture accepts only a local loopback
`daily_motion_test` database; never use it for a hosted restore drill.

The operator must supply or approve:

| Decision | Required concrete record |
| --- | --- |
| Backup route | Managed daily/PITR capability, or an independently scheduled protected export; actual plan and available restore controls |
| Custody | Named backup/recovery owner, approved destination/region/processor, encryption and separate key custody, access control and alert ownership |
| Recovery objectives | Accepted maximum data loss and recovery time, export frequency, monitored failure response and retention at most the documented 35-day ceiling |
| Restore destination | Isolated, owner-approved target, funding if applicable, access isolation and a change plan preserving staging |
| Identity and configuration | Preserved Auth user UUIDs, training owner mappings, Alembic history, provider configuration, custom role grants and a secure credential re-establishment procedure |
| Acceptance | Named operator/reviewer, actual restore results, measured recovery interval and explicit acceptance; a prepared plan supplies no approval |

Supabase recommends separate exports/off-site backups for Free projects. Its
daily backups omit custom role passwords and Storage object bytes. Follow the
supported [backup documentation](https://supabase.com/docs/guides/platform/backups)
and [manual recovery guide](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore).
A manual move also needs separate treatment of platform configuration and any
Vault/encrypted-column root key; check actual use before selecting that route.
No such key was retrieved and no hosted archive was created here.

An approved provider drill must prove the intended verified user UUID still maps
to its restored training owner; restricted-role/TLS/readiness and forced RLS pass;
receipts, pending retry, pull/bootstrap and A/B isolation work against the restored
environment; and actual backup custody/retention and recovery objectives hold.
Re-establish custom role authentication through the protected SCRAM provisioner
only with authorization. Keep values out of SQL/tool logs and account for retained
provider logging. Configuration validation now rejects connection-routing overrides
instead of allowing a checked hostname to be replaced.

Keep a restored environment closed until applicable retirement/deletion records
have been reconciled. The full production deletion-ledger replay job/drill remains
Phase 1 work under [ROADMAP.md](../docs/ROADMAP.md); this preparation neither
implements it nor claims that an empty local retirement table proves recovery
suppression. Physical backup/transfer and Keychain/Keystore qualification remain
separate [device gates](../docs/DEVICE_QUALIFICATION.md).
