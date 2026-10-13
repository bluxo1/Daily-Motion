# Operator qualification handoff

This is a preparation checklist, not a deployed environment or a claim that
provider settings, email delivery, legal review or signing were qualified.
The workspace has synthetic local PostgreSQL and remote compilation only.
[Phase 0 evidence](../docs/PHASE0_EVIDENCE.md) separates these from external gates.

The Daily Motion product/repository owner is accountable for commissioning the
India launch privacy/security review and assigning a named qualified reviewer.
The deployment operator owns region, backup, processor and signing evidence.
Named appointments and approval artifacts must be recorded before closing the
external dependency; software tests cannot provide that approval.

## Hosted staging prerequisites

### Public feasibility desk review — 2026-10-14 IST

No project credentials were used. Published primary sources confirm the planned
region is available: Supabase's specific Mumbai region is `ap-south-1`, and
Cloud Run's Mumbai region is `asia-south1`.
[Supabase regions](https://supabase.com/docs/guides/platform/regions),
[Cloud Run locations](https://docs.cloud.google.com/run/docs/locations).
Use a specific Supabase region rather than assuming a broad APAC selection is
Mumbai. Cloud Run lists Mumbai services but not native custom-domain mapping;
the default HTTPS service URL remains sufficient for the Phase 0 API origin.

[Supabase backup documentation](https://supabase.com/docs/guides/platform/backups)
lists daily database backups on paid plans and an optional PITR add-on. Free
projects need separately arranged dumps; recovery settings/retention must be
recorded from the actual project. Database backups omit Storage API object bytes,
and daily-backup restoration requires resetting custom role passwords. Those
boundaries belong in the future operator restore drill; no restore was performed.

Reviewed the published source inventory for operator/privacy review:
[Supabase DPA](https://supabase.com/legal/customer-resources/data-processing-addendum),
[subprocessors](https://supabase.com/legal/customer-resources/subprocessor-list),
[data-location/transfer FAQ](https://supabase.com/legal/privacy-resources/data-residency-and-transfers-faq)
and [Google Cloud DPA](https://cloud.google.com/terms/data-processing-addendum).
This establishes available review materials, not an executed agreement, approved
processing arrangement or India compliance determination. Actual project,
backup/recovery, contract and named-reviewer approvals remain external.

### Operator-managed configuration

- Create isolated development/staging Supabase and API environments using the
  accepted Mumbai hosting default. Record actual project/database/API locations,
  available recovery settings, retention/PITR, plan limits and processor terms.
  A configured region name is not residency or compliance proof.
- Configure asymmetric JWT signing, issuer/audience, OTP template, custom SMTP,
  domain authentication, resend/attempt budgets and a controlled test inbox. Keep
  SMTP, signing, migration/database and service/admin credentials in operator
  secret storage. Only URLs and a client-safe publishable key go to mobile.
- Keep `training` private and unexposed to the Supabase Data API. Use a dedicated
  non-owner, `NOSUPERUSER NOBYPASSRLS` API role with no membership in table-owner
  roles, minimum grants and verified TLS. Run Alembic separately as the migration
  role; grant required tables after migration. All training tables require forced
  RLS. The API now checks those conditions before each tenant transaction.
- Use staging/production auth configuration without a public-key-file override,
  fixture flag or synthetic token. Require HTTPS. Verify signing-key rotation and
  provider revocation against the real project. Restart API workers to discard
  cached JWKS for urgent trusted-key rotation; do not add an unauthenticated cache
  reset endpoint. Test both accepted and rejected credentials afterward.
- Record reviewer/incident owner assignments and review privacy purposes,
  notices, processors, transfer, retention and current India requirements using
  [SECURITY.md](../docs/SECURITY.md). This checklist supplies no legal conclusion.

## Record actual evidence

Use [DEVICE_QUALIFICATION.md](../docs/DEVICE_QUALIFICATION.md) for the hosted OTP
and hardware procedures. Preserve environment, build revision, platform/device,
scenario and result; redact codes, tokens, emails, personal training and secrets.
Test account initialization/lost response, expiry/refresh, sign-out and A→B→A,
then native storage loss, backup/transfer, suspension/reboot/clock changes,
process/storage failures, accessibility and profile/release durable-save samples.
Use operator signing for installations; unsigned hosted iOS compilation is a
separate result. A debug/emulator benchmark cannot close the phone latency gate.

Production backup restoration must additionally replay the deletion ledger before
normal access, as specified in [SECURITY.md](../docs/SECURITY.md). Full public
deletion/export jobs and their restoration drill are Phase 1 release work, not
implemented by this foundation handoff. Do not restore erased personal payloads.
