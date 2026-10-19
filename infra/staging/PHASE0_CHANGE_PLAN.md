# Phase 0 staging change approval plan

**Exact-SHA deployment was explicitly authorized and executed on 2026-10-18.**
Public health/readiness pass. Oct 19 manual qualification passes A/B authentication,
refresh, sync, receipts, restart and cross-owner denial, but final A verification
is rejected; full A → B → A recovery remains pending diagnosis.
Phase 0 remains in progress; Phase 1 is
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
[New private provider preflight](../../docs/evidence/phase0-staging-deployment-preflight-2026-10-18.json).
[Authorized deployment result](../../docs/evidence/phase0-staging-security-deployment-2026-10-18.json).

## 1. Deployment and rollback

**Target:** existing Render service `daily-motion-staging-api`,
`srv-db7p5knavr4c7392dasg`; existing Supabase project `pulruylvpehwftwqcvct`.
The authenticated readback at **16:07 UTC on Oct 18** confirms Live revision
`c5d5414fef28a4a5170d605b61d878797786acbd` /
`dep-db8efpon74is73epb8ng`, with no active/queued deployment displayed.
Saved settings confirm `main`, Singapore, Free, expected build/start/root/health
commands, no pre-deploy command and service **Auto Deploy Off**. PR #4 was already
merged externally; the exact `cbacc0a` entry remains distinct from merge revision
`4329ba6`. Selecting its full-SHA entry enables **Deploy commit**; the dialog was
cancelled without submission. Do not select **Deploy latest commit**.

Saved environment readback passes intended-project/runtime-login/database,
explicit session-pooler port 5432, `verify-full`, matching CA secret file, permitted
unique query keys and absence of routing overrides. Read-only Supabase catalogs
confirm restricted runtime privileges, no owner membership, migration `0003`,
11 forced-RLS tables, required grants, 12 exact owner-policy definitions and
denied PUBLIC/API-role training access. No user rows or password verifiers were
read. At **16:11 UTC**, public health/readiness return **200**, and unauthenticated
`/v1/me` returns **401**; an earlier readiness transport timeout remains recorded
with unconfirmed cause. Billing shows **2 / 500 included pipeline minutes used**.
These are dated preflight facts; recheck revision, queue, configuration and budget
immediately before an approved deployment.

**Authorized execution:** exact `cbacc0a` was submitted at **16:27:59 UTC** as
`dep-dbaf73ijnfac73fg5l20`; Render confirms it Live at **16:31:43 UTC**, with a
displayed build/deploy duration of 1m10s. Public checks at **16:32 UTC** return
health/readiness 200 and unauthenticated identity 401. Saved service settings
and private transport/authentication classifications pass again after deployment.
No configuration, credential, Blueprint, schema or resource changes were made.
No rollback was used. The Oct 18 native manual-entry attempt times out awaiting
Account A's code; the operator later confirms the recipient and finds the email.
An authorized fresh Oct 19 run verifies distinct A/B identities and passes hosted
sync, refresh, accepted/duplicate receipts, file restart, pending sign-out and
cross-owner denial. Its third submission, returning to A, fails verification with
`invalid_or_expired_code`; final pending recovery/bootstrap is not reached. There
is no established application/deployment regression or basis for rollback.

1. Explicit approval was received for one manual deployment of exact
   `cbacc0ab74d8d5bf7e54aff7a13d27267bf8cfdd` on the existing service, its bounded
   controlled-account hosted qualification, and one code rollback if qualification
   fails. Authenticated Playwright access to Render and Supabase is restored;
   fresh provider readback is recorded above. No new credential or provider
   configuration change is part of this deployment request.
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
   and execute the approved rollback. The captured rollback SHA is
   `c5d5414fef28a4a5170d605b61d878797786acbd`; stop for renewed approval if the live
   baseline has changed before execution. Prefer a manual deploy of this previous
   code SHA using **current** environment values. A platform rollback
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

## Current authorization and remaining dependency

The approved exact-SHA deployment is executed; the conditional code rollback is
unused. The latest continuation requires new explicit approval before one fresh
controlled-account qualification run. The existing OTP rejection alone does not
justify rollback.
The operator can read email independently and enter codes in the native masked
qualification window; inbox automation is not required. The original recipient/
email search dependency is resolved. Exact Auth-log correlation remains pending;
manual read-only lookup instructions are supplied because the extension remains
disconnected. Recipient/challenge/account-state review finds no demonstrated
mixup. A separate confirmed cooldown defect is fixed and locally verified: wait
61 seconds from successful request completion, independently for A/B. The generic
failure display also identifies the failed account step/category. Successful
earlier checkpoints and the failed third submission remain preserved.

**Prepared approval scope:** one complete A → B → A run on the existing staging
API; at most three fresh OTP requests, no automatic resend or incorrect-code
probe, masked local entry for each new message, per-account pacing and stop on
failure. Final A pending-work recovery and hosted bootstrap must pass in this
same run before end-to-end qualification is claimed. No OTP or run is started
while approval is pending. No provider or deployment settings are changed.

Any additional deployment or provider change needs separate approval.
Signing-key changes, sender limits, hosted backups
and operator acceptance remain separate decisions. Physical Android/iPhone,
signing, native storage/backup, accessibility and physical durable-save p95
evidence still require hardware/access.
