# Operator qualification handoff

This is an operator checklist. Staging deployment and desktop hosted SMTP/OTP,
SDK/controller and sync functional proof now exist; legal review, signing,
managed recovery and physical-device acceptance remain open.
[Phase 0 evidence](../docs/PHASE0_EVIDENCE.md) separates these from external gates.

The Daily Motion product/repository owner is accountable for commissioning the
India launch privacy/security review and assigning a named qualified reviewer.
The deployment operator owns region, backup, processor and signing evidence.
Named appointments and approval artifacts must be recorded before closing the
external dependency; software tests cannot provide that approval.

### Current operator dependencies — 2026-10-18 IST

- Invalidate the exposed private Render Blueprint sync hook for
  `daily-motion-staging` (provider support if necessary; no regeneration control
  is exposed by the current settings UI). Do not paste the replacement URL into
  chat. Confirm invalidation, then repair and verify the deleted source branch to
  `main`. The service already follows `main`; its secrets must remain protected.
- Authorize the staging-only ES256 standby/rotation/revocation rehearsal and API
  cache restart before trusted keys change. Observe provider JWKS cache propagation
  and verify overlapping/new/retired credentials. No key change is authorized yet.
- Approve a staging sender capacity policy: 30 emails/hour can permit 720/day,
  exceeding the consumer Gmail sender's documented 500/day allowance. Actual
  recipient delivery/signing/TLS and immediate resend denial pass; hourly/daily
  quota exhaustion and an operator capacity acceptance are not claimed.
- Provide an approved managed or separately arranged backup/recovery route and
  processor acceptance. The current backup dashboard still shows Free, no
  scheduled backup rows and no restore control. No paid upgrade was attempted.
- Supply Android/iPhone hardware, signing/install access, developer/store
  prerequisites, named privacy/security and incident ownership, and operator
  acceptance. Physical/native/accessibility/p95 evidence remains mandatory.

See [the safe provider audit](../docs/evidence/phase0-provider-qualification-2026-10-18.json).

#### Prepared private Render Support request

Submit through the Render Dashboard support portal or the support address on
[Render's contact page](https://render.com/contact). No message has been sent by
the agent. Omit hook URLs and secret values:

> Please invalidate/disable or rotate in place the potentially compromised
> Blueprint Sync Hook for `daily-motion-staging` / `exs-db7otpl9fdbs73f0qaqg`.
> Preserve existing service `srv-db7p5knavr4c7392dasg`, deployed revision,
> credentials and external Supabase PostgreSQL. Enqueue no sync/deploy and
> create/delete no resources. Confirm old credentials are rejected before
> enqueueing, using redacted provider-side evidence or a supported auth-only check.
> If direct invalidation is unavailable, document disconnection's revocation
> semantics and a same-resource reattachment plan without duplication, deployment
> or credential reset; obtain owner approval before disconnecting. Keep secrets
> and hook URLs out of the reply.

Auto Sync off is verified; revocation is not. The published Blueprint update API
accepts only name, Auto Sync and path. The separate service deploy-hook control
does not rotate a Blueprint sync hook. [Current evidence](../docs/evidence/phase0-render-hook-investigation-2026-10-18.json).

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
