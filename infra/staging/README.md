# Supabase + Render staging

Requested Phase 0 provider qualification target, deployed **2026-10-14**:
Supabase `daily-motion-staging`, Mumbai `ap-south-1`, project
`pulruylvpehwftwqcvct`; Render `daily-motion-staging-api`, Singapore, both free
plans. API [HTTPS readiness](https://daily-motion-staging-api.onrender.com/readyz)
passed again on **`c5d5414`**, deployment **`dep-db8efpon74is73epb8ng`**, after
credential rotation and protected saved-value verification on **2026-10-15**.
PostgreSQL **17.11**, Alembic **0003**, restricted runtime,
11 forced-RLS tables and rolled-back owner/pool probes are verified. These
resources are staging only. [Evidence](../../docs/evidence/phase0-hosted-staging-2026-10-14.json).

**Email/account/sync qualification remains blocked**: A/B controlled inboxes are
now designated and both real requests returned HTTP 200, without claiming delivery
or verified distinct identities. Native Supabase dashboard access is restored;
mailbox access remains unqualified. Custom SMTP was re-observed **off** on
2026-10-15, and the dashboard requires it before
subjects/bodies can be edited. Six-digit
OTP and 600-second expiry are configured; prepared code templates remain unapplied.
The free project has **no managed backups**; plan/restore qualification is open.

## Provisioning order

1. Sign in to Supabase and select the owner-approved staging organization. Create
   `daily-motion-staging` in the **specific Mumbai `ap-south-1` region**, using a
   generated database password entered directly into provider/secret storage.
   Record project reference, actual PostgreSQL version, plan and backup settings.
2. Enable confirmed email and six-digit email OTP. Configure custom SMTP directly
   in the provider before editing templates: the observed staging dashboard
   disables subject/body editing without it. Then set the Magic Link email
   subject to `Your Daily Motion staging code` and use
   [email-otp.html](email-otp.html) containing `{{ .Token }}`. Use the same OTP
   content for confirmation emails where the provider's signup flow uses that
   template. Keep anonymous/social providers off. Configure a practical expiry
   (e.g. 600 seconds), resend/attempt throttles and actual sender settings.
   Do not disable email confirmation to bypass delivery.
3. Select asymmetric ES256/RS256 signing; the API deliberately rejects legacy
   HS256 tokens. Copy the **publishable** `sb_publishable_…` key only. Keep the
   `training` schema out of exposed Data API schemas; disabling that unused API
   is preferable. Neither Flutter nor REST clients write training tables directly.
4. Download the project root certificate. Obtain the exact session-pooler host
   from the Connect dialog (IPv4 port **5432**, **not transaction port 6543**).
   Migration login is `postgres.PROJECT_REF`; API login is
   `dm_staging_runtime.PROJECT_REF`. For a reachable direct connection the login
   has no suffix. Use `postgresql+psycopg` URLs, URL-escaped passwords,
   `sslmode=verify-full` and the downloaded certificate in `sslrootcert`.
   [Supabase connections](https://supabase.com/docs/guides/database/connecting-to-postgres),
   [certificate verification](https://supabase.com/docs/guides/database/psql).
5. In an operator process, supply the environment names below from protected
   storage. Run from `services/api`:

   ```sh
   python scripts/provision_staging.py --confirm-project-ref PROJECT_REF
   ```

   It checks project/transport before changing anything, applies Alembic through
   `0003` on one supplied administrator connection, provisions only the named
   staging runtime role, grants the private schema and read-only migration
   metadata (including explicit `public` schema usage), and revokes direct
   training access from provider/public roles. Verification reads the actual
   migration revision through the runtime role; missing/stale metadata fails.
   Password DDL uses client-generated **SCRAM-SHA-256 verifiers**, regardless of
   the server password-encryption default; plaintext never enters that SQL.
   Verifiers are sensitive credential material too: suppress SQL/exception output
   and restrict provider logs. It never resets schemas, seeds personal accounts or prints credentials.
   Repeated setup retains accounts/workouts. The runtime probe uses fresh
   synthetic owners, checks forced RLS/isolation and rolls the entire probe back.
   Only safe booleans/count/revision reach stdout. For later verification use
   `--verify-only` with no admin/password environment variables.
6. Connect the repository to Render and create the blueprint from
   [render.yaml](../../render.yaml), from **main**, **Singapore**. The original
   qualification branch was merged by PR #2 and deleted. Both the Blueprint's
   tracked source branch and the service's linked branch must point to `main`;
   changing this YAML alone does not prove the existing provider settings changed.
   Plan `free` avoids selecting a paid compute tier; any provider billing/card
   boundary still belongs to the account owner. Render currently lists Singapore
   but no Mumbai region. This staging exception is [DM-018](../../docs/DECISIONS.md#dm-018--render-staging-provider-qualification).
   The production Cloud Run Mumbai decision is unchanged.
   Blueprint creation starts an initial deploy before the secret file can be
   added. Treat that attempt as unready; attach the certificate and deploy again.
   Do not infer readiness from resource creation or cancel a queued attempt
   using a stale selected deployment row. Record the exact deployment ID/revision.
7. Add a Render secret file `supabase-root.crt` with the project certificate.
   Set `DM_DATABASE_URL` to the **runtime** connection URL with
   `sslrootcert=/etc/secrets/supabase-root.crt`. Enter the prompted values below
   in Render; let Render generate and retain `DM_SYNC_SIGNING_KEY`. Never put
   `DM_STAGING_ADMIN_URL` or migration/admin credentials on the API service.
8. Deploy the exact validated commit manually. Builds use pinned Python/uv and
   the frozen lockfile; start runs Uvicorn with access logging disabled. Migrations
   are a separate operator step, not a startup hook. Render's health check uses
   `/readyz`; `/healthz` remains process liveness. Readiness validates hosted
   auth/TLS settings, restricted role, migration `0003`, table grants/forced RLS
   and missing-owner denial. It returns no owner/secret metadata. Database failures
   return sanitized 503 responses, never SQL parameters or stack traces.
9. Record the actual HTTPS `onrender.com` URL and Render deployed commit. Call
   `/healthz`, `/readyz` and unauthenticated `/v1/me` (must return 401). Free
   Render services can cold-start; this is staging functional evidence, not a
   production availability or latency qualification. No custom DNS is necessary.
   [Render FastAPI](https://render.com/docs/deploy-fastapi),
   [regions](https://render.com/docs/regions),
   [blueprint secrets](https://render.com/docs/blueprint-spec#prompting-for-secret-values).

## Environment separation

| Process | Required values | Secret handling |
|---|---|---|
| Operator provisioning only | `DM_STAGING_ADMIN_URL`, `DM_STAGING_RUNTIME_PASSWORD`, plus the runtime configuration below | Protected environment injection; never arguments/source/mobile/Render API runtime |
| Render API / verify-only operator | `DM_ENVIRONMENT=staging`, `DM_DATABASE_URL`, `DM_SUPABASE_URL`, `DM_SUPABASE_PUBLISHABLE_KEY`, `DM_JWT_ISSUER=SUPABASE_URL/auth/v1`, `DM_JWT_AUDIENCE=authenticated`, `DM_SYNC_SIGNING_KEY` | Runtime database password/signing key in provider secrets; public URL/publishable values are client safe |
| Flutter | Only the four keys in [mobile.example.json](mobile.example.json) | Copy with real client-safe values to ignored `.tools/staging/mobile.json`; no token/admin/database/signing keys |

The operator certificate path and Render certificate path can differ. Environment
variables are process-scoped; clear the migration/admin values after preparation.
All `.env` and `.env.*` files are ignored except `.env.example`; browser snapshots
are ignored. Do not paste actual provider environment settings or console
exceptions into ordinary logs. A staging build never sets fixture/token flags:

```sh
cd apps/mobile
flutter run --dart-define-from-file=../../.tools/staging/mobile.json
```

## Provider qualification and safe evidence

The continuation accepted one real request for each owner-designated inbox A/B,
but mailbox receipt and verified identity are still unqualified. A 200 request
response does not establish that the alias is a distinct verified identity or
that it needs no team invitation. Do not substitute uncontrolled addresses.

The prerequisite historical audit found that earlier provisioning sent a plaintext role password
in DDL on a project with DDL logging enabled. The fixed provisioner sends only
SCRAM verifiers; it does not remove historical logs or rotate existing secrets
automatically. Inspect aggregate counts/log settings, never raw query text or
passwords. Rotation was applied on 2026-10-15; **two legacy plaintext statements
remain retained**, while the two new role statements use SCRAM. No historical
purge or comprehensive log clearance is claimed. For subsequent rotations:

1. Generate credentials in a protected operator process. Enter only the runtime
   URL into Render. Keep administrator credentials off the service/mobile app.
2. Focus the exact value field before entry and trigger its normal blur. A native
   set-value call or closed save form is insufficient evidence: this qualification
   found a saved credential that still differed and was rejected by PostgreSQL.
3. Save and reload the provider page. Compare the saved URL/password to the current
   rotation **inside the protected process**, returning only equality booleans.
   Hide the field afterward. Never capture screenshots, export it to ordinary
   logs, or include its value in CLI arguments.
4. Apply the fixed SCRAM provisioner, verify a fresh restricted connection and
   rollback-only isolation probe, then deploy the exact tested API revision.
5. Verify the actual deployment reaches Live and HTTPS readiness passes. Keep the
   protected context alive until recovery is proven; an interrupted/expired
   context must not be replaced by recovering secrets from process memory/logs.

Password changes do not
invalidate already authenticated database sessions: replace the API process and
close old runtime-role sessions through protected provider/operator controls.
Verify a fresh runtime connection, owner isolation and pooled owner-context reset;
a readiness response from an old connection pool alone does not prove rotation.
Keep access to logs and SCRAM verifiers restricted. If retention/purge requires
provider support, record that boundary rather than claiming logs are clean.
[PostgreSQL connection authentication](https://www.postgresql.org/docs/17/auth-pg-hba-conf.html),
[session termination controls](https://www.postgresql.org/docs/17/functions-admin.html#FUNCTIONS-ADMIN-SIGNAL).

Use two owner-controlled **staging test inboxes**, A and B, without personal
training data. With default Supabase email delivery, recipients must be authorized
organization members and current limits apply. Default provider delivery can be
recorded as hosted OTP evidence; it **cannot qualify custom SMTP**. Configure
custom SMTP directly in Supabase only when sender/domain credentials are provided,
and record actual delivered messages before marking that path qualified.
[Supabase SMTP restrictions](https://supabase.com/docs/guides/auth/auth-smtp).

Execute the real app email-code UI, recording result categories rather than codes:
request → inbox delivery → verify → API initialize → matching local owner unlock.
Attempt an incorrect code, resend after throttle, expiry by waiting for configured
expiry, and provider refresh. Verify invalid/wrong-provider tokens are denied;
do not claim a tampered signature separately proves a valid-signature wrong-issuer
or wrong-audience case. Those independent claims remain real local JWT tests until
the appropriate actual provider credentials are available.

The normal first-account app intentionally has no personal sample workouts. Use
the existing repository/domain harness with the **verified staging owner and
real user credentials** for synthetic workout creation and sync; do not enable
`DM_FOUNDATION_FIXTURE` or `DM_ACCESS_TOKEN` in a staging app. A test invocation
may inject short-lived credentials through a protected process environment,
then discard them. Do not store tokens in a Flutter configuration JSON. Do not run
the destructive local PostgreSQL pytest fixture against the hosted project.

The prepared opt-in desktop Flutter harness is
`apps/mobile/test/hosted_staging_test.dart`. Supply `DM_HOSTED_SYNC_QUALIFICATION=1`,
the four client-safe settings and short-lived `DM_STAGING_TOKEN_A` /
`DM_STAGING_TOKEN_B` through a protected test-process environment, then run
`flutter test test/hosted_staging_test.dart`. Its local files contain synthetic
training, not sessions/tokens. It initializes both owners through the real API,
sends the same frozen command twice, leaves its acknowledgement uninstalled,
locks/reopens A→B→A, checks B's local/feed namespace and resumes the pending
mutation through the coordinator. It is **skipped by default and unqualified**
until actual staging credentials exist. It exercises repository locking; real
provider logout, OTP, refresh and UI secure storage are separately exercised
through the actual app, not inferred from this harness.

Verify lost-response exact retry, own echo, second-client pull/bootstrap, restart
with pending work, sign-out locking and A→B→A recovery. Disable only a deliberately
selected synthetic staging account through a separate operator action and prove
server denial; do not expose a public administrator route. Record rollback-only
hosted RLS probe results separately from Flutter HTTP behavior and physical-device
qualification. Hosted rollback-only database RLS/owner/pool probes have passed;
authenticated hosted Flutter sync and OTP lifecycle remain **unperformed** until
real credentials and mailbox evidence exist.

Record: UTC/local date, project/API URLs, actual Supabase/Render regions and plans,
PostgreSQL version, Alembic revision, API deployed commit, HTTPS/readiness/auth
checks, delivery route/default versus custom SMTP, test counts, owner-isolation
and retry/restart outcomes. Never retain OTPs, access/refresh tokens, passwords,
inbox message contents or personal workout payloads in evidence.
