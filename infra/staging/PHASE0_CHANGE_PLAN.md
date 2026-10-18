# Phase 0 staging change approval plan

**Staging deployment prepared; not authorized or executed.** Phase 0 remains in progress; Phase 1 is
unstarted. `d655e1f` passed both remote CI runs. The routing follow-up `a4f0003`
is also published with green push/PR CI, including 145 Python tests; push macOS
needed one failed-job retry. A wider review then finds a separate development
setup bypass; its new fix passes
165 local Python tests, including real disposable PostgreSQL and connected
Flutter HTTP. That final review fix is published as `cbacc0a`; all three jobs pass
in both push/PR CI, with 165 Python / zero skipped and 151 Flutter / 12 explicit
skips on each mobile runner. Deployment candidate:
`cbacc0ab74d8d5bf7e54aff7a13d27267bf8cfdd`.
[Results and current CI status](../../docs/evidence/phase0-development-routing-and-ci-2026-10-18.json).

## 1. Deployment and rollback

**Target:** existing Render service `daily-motion-staging-api`,
`srv-db7p5knavr4c7392dasg`; existing Supabase project `pulruylvpehwftwqcvct`.
The last observed Live revision is `c5d5414` / `dep-db8efpon74is73epb8ng`;
capture the actual current revision before executing any change.

1. Obtain approval for the exact follow-up SHA after its CI is green, one manual
   deployment on the existing service, and bounded code rollback if qualification
   fails. Restore authenticated provider/browser control first; this session
   currently has GitHub/CLI access but exposes no browser, Supabase or Render
   control integration. No fresh provider configuration readback is claimed.
2. Read preflight configuration privately: one intended database host, explicit
   database, verified TLS/root certificate, no connection-query overrides or
   `PGHOSTADDR`/`PGSERVICE`/`PGSERVICEFILE`/`PGOPTIONS`; an omitted port must have no
   `PGPORT` override. Explicit ports take precedence. Return only classifications
   and equality booleans. Stop for separate configuration authorization on any
   mismatch. Check actual service auto-deploy state; the committed Blueprint's
   `off` setting does not establish persisted service state. Confirm the operation
   fits the existing included pipeline budget; any charge or plan change needs
   separate approval.
3. Use Render's **Deploy a specific commit** on that exact qualified SHA. Preserve
   existing environment values, resource IDs, database, region, plan and source
   branch. No migration is required. Dashboard deployment of a specific SHA
   disables service auto-deploys; confirm it is already off or obtain approval
   for that side effect before executing. Use no deploy/sync hook or Blueprint
   sync, branch repair, disconnection or recreation.
4. Verify the deployed revision, Live state, `/healthz` and `/readyz` 200,
   unauthenticated `/v1/me` 401, and a targeted credential-gated hosted sync/owner
   isolation case against the new build. Credentials remain in protected process
   memory. This new server revision justifies that targeted retest; repeat the
   longer OTP-expiry/lifecycle qualification only if a new failure warrants it.
5. On failed readiness, initialization/sync or owner isolation, stop qualification
   and execute the approved rollback. Prefer a manual deploy of the recorded
   previous code SHA using **current** environment values. A platform rollback
   can reuse historical environment variables; use it only after private
   confirmation of credential/configuration equivalence and artifact availability.
   Recheck revision, health/readiness and owner denial. Perform no database restore
   or credential reset as part of this code rollback.

Render incident **215476446235862 remains OPEN**. A service deployment does not
invalidate its exposed Blueprint credential. Support must confirm actual
revocation; this plan authorizes no incident fallback operation.
[Specific-commit behavior](https://render.com/docs/deploys#deploying-a-specific-commit),
[rollback configuration and retention](https://render.com/docs/rollbacks).

## 2. Sender-capacity decision

**Proposal requiring separate approval:** staging email messages **30 → 10/hour**,
preserving the **60-second** resend interval, OTP lifetime and verification limits.
The last saved readback was 30/hour; no setting has changed.

| Effect | Operational tradeoff |
| --- | --- |
| Nominal 24-hour allowance falls from 720 to 240 | Adds margin against the documented consumer Gmail 500-message/day allowance |
| One project-wide budget covers email-sending Auth flows | Concurrent testers, resends and other Auth emails can exhaust it; schedule qualification within the budget and handle 429/retry states |
| Gmail account may have other senders, bursts or bounce restrictions | This hourly setting is not an account-wide daily cap or delivery guarantee |
| Existing delivered-message SPF/DKIM/DMARC evidence remains valid | A named operator must accept capacity, own sender-wide usage/delivery monitoring and decide whether the account is dedicated |

After approval: change only the email/hour value, save and reload, verify the
persisted value and the retained resend setting without credentials, then perform
a bounded controlled delivery/verification check. Do not exhaust quotas or send
bulk test mail. Any limit reversal or SMTP-provider migration needs its own scope.
[Gmail limits](https://support.google.com/mail/answer/22839?hl=en),
[Supabase rate limits](https://supabase.com/docs/guides/auth/rate-limits).

## 3. Hosted recovery decision

The last observed staging project was Free with no managed backup/restore rows;
the completed local restore is preparation only.

| Choice needing approval | What must be accepted/provided |
| --- | --- |
| Managed daily backups on an eligible paid Supabase plan | Subscription/compute cost, actual retention, daily recovery-point limits, named owner and an approved isolated restore target |
| Keep Free and arrange scheduled encrypted off-site exports | Schedule, monitored failures, approved destination/region/processor, key custody, retention and an isolated restore target; operation is owned by the operator |
| Finer recovery using PITR, if required | Explicit add-on/compute spending and accepted recovery window; choose only after defining recovery objectives |

For any route, approve recovery-point/time objectives, access/key custody,
retention within the documented 35-day ceiling, identity/configuration recovery,
and the exact non-staging restore destination before provisioning or exporting.
Preserve Auth UUID mappings, training schemas and Alembic history; re-establish
custom role credentials securely. Database backup coverage does not establish
Storage-object recovery. Actual provider restoration, current backup settings and
operator/privacy/processor acceptance remain unqualified.
[Recovery package](../RECOVERY.md),
[provider backup capabilities](https://supabase.com/docs/guides/platform/backups).

## Next approval

After authenticated browser restoration and private preflight, authorize one
manual deployment of that exact qualified revision to the existing staging API
and bounded code rollback to the captured prior SHA, using current environment
values and the checks above. Publication of `cbacc0a` is already authorized;
this plan grants no staging-change permission. Deployment,
signing-key changes, sender limits, hosted backups and operator acceptance remain
separate decisions. Physical Android/iPhone, signing, native storage/backup,
accessibility and physical durable-save p95 evidence still require hardware/access.
