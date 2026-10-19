# Phase 0 evidence reconciliation

Audited through 2026-10-20 (IST). Recovery PR #7 starts from healthy remote
`main` (`8ba5a98`); its reviewed source is `e3da9d0`. The recovery remains a PR,
not a direct update to main. The earlier PR #6 merge was removed by a reset/push;
[the integration audit](INTEGRATION_RECOVERY.md) records the evidence.
[ROADMAP.md](ROADMAP.md) remains the scope authority. This matrix distinguishes
implemented foundation work from its separate physical/provider acceptance.
[IMPLEMENTATION.md](IMPLEMENTATION.md) records commands, counts and environments;
[phases.md](phases.md) is the checklist. A checked foundation row does not close
the overall Phase 0 exit gate.

| Authoritative Phase 0 work | Actual evidence | Status |
|---|---|---|
| Flutter/Riverpod/Drift, modular FastAPI, migrations and pinned toolchains | Mobile/API source, lockfiles, Alembic 0001–0003, Drift 1→3 and 2→3 tests; Linux Android all modes and macOS unsigned iOS debug/release CI | Complete for buildable foundations |
| Onboarding interaction prototype | Supabase OTP/account UI; controlled tests plus actual custom-SMTP A/B delivery/verification and production SDK/controller hosted cases | Prototype and desktop hosted functional proof complete; native UI/storage remains external |
| Routine-editing interaction prototype | Separate synthetic `routine_prototype.dart` entrypoint; editable planned sets/rep range/rest, immutable workout previews, validation/back/keyboard/large-text tests | Complete as disposable prototype; no production routine storage or sync |
| Active logging and history interaction prototypes | Fixture Train/History, durable editor/drafts, completion/abandonment/corrections; widget tests and real SQLite suites | Complete as executable foundation; public feature breadth belongs to Phase 1 |
| Small internal light/dark design system and accessible numeric/set controls | Semantic themes, explicit action/text colors, contrast tests, 320px/200% text/keyboard and labeled tap-target widget tests | Complete for implemented controls; physical usability/screen-reader acceptance remains external |
| Account-scoped local storage, transactions, drafts/outbox/timers and restart recovery | File-backed recovery suites, hard Windows kills, pager-full rollback, Android emulator protected-session seed/force-stop/recover | Complete for tested foundation primitives; phone lifecycle/power/storage remains external |
| Aggregate CAS, exact receipts, shadow/working separation, committed feed and consistent bootstrap | Real restricted-role PostgreSQL, live Flutter HTTP, atomic page/cursor and staged snapshot fault/restart tests | Complete for implemented protocol foundation; no physical-device inference |
| Account-disable races, erased transport/snapshots and migrations | Real owner locks/retirement/redaction tests, file-backed pending deletion and additive migration tests | Complete for foundation erasure barriers; public export/deletion jobs are Phase 1 |
| Additive checked API/contracts and fixtures | Generated OpenAPI/Dart DTO/limits, shared fixtures, byte-for-byte reproduction checks and fail-closed parsing tests | Complete for current version; four generated outputs include Drift |
| CI format/static/tests/docs and security basics | Three actual remote jobs, including recovered source `e3da9d0` in [PR #7 CI](https://github.com/bluxo1/Daily-Motion/actions/runs/39306127033); secret guard, release synthetic-auth rejection, safe logging tests, runtime-role/forced-RLS guard and real database attacks | Complete for implemented baseline; not a comprehensive security certification |
| Managed Mumbai region, backups, processor arrangements and review ownership | Public desk review/operator checklist in [infra/QUALIFICATION.md](../infra/QUALIFICATION.md), plus actual Mumbai staging PostgreSQL 17.11; observed free plan without managed backups | Staging region/database verified; managed backup/restore, processor and named operator/reviewer acceptance outstanding |
| Physical iPhone and Android acceptance, signed installation, native protection/backup/accessibility and durable-save p95 | Device procedures and native harnesses in [DEVICE_QUALIFICATION.md](DEVICE_QUALIFICATION.md); safe [emulator evidence](evidence/phase0-windows-native-2026-10-13.json) explicitly ineligible | External hardware/signing/provider acceptance outstanding |

## Integration recovery — 2026-10-20

The original auth head `950a946` was reviewed against bad merge `b2cfee9` and
healthy main `8ba5a98`. Recovery excludes malformed Dart, a fixed default clock
and a no-op delay. Successful-request cooldown, stale-challenge invalidation,
bounded qualification and redacted diagnostics now pass new regressions. A
separate reproduced false PASS for skipped hosted tests is fixed: the operator
bridge requires a complete ordered A/B/A lifecycle and consumed challenges.

Only after all three source PR CI jobs passed was this matrix reconciled.
Remote API: **204 Python / zero skipped**, including **55 PostgreSQL cases** and
the harness executing **9 live Flutter HTTP cases**. Each Linux/macOS mobile job:
**161 Flutter / 12 explicit skips**, plus Android builds and unsigned iOS
debug/release. Local Windows: **161 Flutter / 12 skips**, **148 Python / 56 skips**;
Docker startup failed, so the missing local database cases were qualified by CI,
not reported as local passes. All four generated outputs reproduce unchanged.

These are source-integration and desktop/database proofs. They do not repeat or
close the incomplete Oct 19 hosted return-to-A run, trusted-key rotation, SMTP
capacity/operator acceptance, phone hardware or physical p95 gates. Render
**215476446235862 remains OPEN**. No provider setting, OTP, key or deployment
action occurred. [Exact recovery evidence](evidence/phase0-integration-recovery-2026-10-20.json).

## Scope corrections

**Latest Oct 18 functional proof:** actual custom-SMTP recipient delivery and
verification establish distinct A/B subjects. Both targeted hosted Flutter cases
pass, including provider refresh/revocation, immediate resend/incorrect-code
denial, file reopening, pending sign-out, A → B → A, retry receipts and cross-owner
read/mutation denial. Two harness defects were fixed. Historical unperformed/
SMTP-failure statements below describe earlier checkpoints; current detail is in
[new evidence](evidence/phase0-hosted-auth-flow-2026-10-18.json). No native storage
or phone performance result is inferred.

**Later Oct 18 provider audit:** a delivered, unconsumed OTP is rejected after
610 actual seconds against the saved 600-second lifetime; a fresh delivered code
verifies and signs out. The hardened lifecycle case passes again. Local full
regressions pass: 108 Python, including the nine live Flutter HTTP cases, and
151 ordinary Flutter with 12 explicit skips. Assertion failure paths now avoid
formatting sessions; the credential guard rejects Render hook credentials.
[New provider evidence](evidence/phase0-provider-qualification-2026-10-18.json).

**New security/operator blockers:** a private Blueprint sync hook was returned in
a tool response during settings inspection; provider/operator invalidation is
requested and unconfirmed. No value is retained in repository evidence, and no
log purge is claimed. The Blueprint source still references a deleted branch;
its unsaved edit was discarded and repair is held until hook invalidation.
The configured 30-email/hour allowance can exceed consumer Gmail's documented
500/day capacity. Trusted-key rotation needs explicit approval. Physical,
managed recovery, processor and named operator/reviewer gates remain open.

**Authorized Support continuation:** private Render conversation
**215476446235862** is submitted and acknowledged for human escalation. The hook
incident remains **OPEN**, with no revocation confirmation or resource change.
Separately, an already delivered recipient message passes SPF/DKIM/DMARC in its
raw Authentication-Results and Gmail summary; no new OTP was requested and no
raw headers or credentials were retained. Sender-capacity acceptance remains
open. [Support submission](evidence/phase0-render-support-submission-2026-10-18.json),
[sender authentication](evidence/phase0-smtp-authentication-headers-2026-10-18.json).

**Recovery/security continuation:** an isolated real local PostgreSQL logical
restore preserves nonempty workout/receipt/feed data, constraints, indexes and
forced RLS; missing-role and truncated-archive attacks roll back atomically.
This does not qualify hosted Auth, off-site custody or managed recovery.
Connection-target defects in the destructive fixture and hosted API/operator
validation are fixed locally; 59 focused tests pass at that checkpoint. The later
CI/disposable-database qualification below supersedes its regression blocker;
hosted deployment still needs approval. The sender-limit reduction is proposed,
not applied or accepted. [Results and limitations](evidence/phase0-recovery-and-connection-guards-2026-10-18.json),
[hosted recovery approval package](../infra/RECOVERY.md).

**Authorized CI and independent review:** published `d655e1f` passes all three
jobs in both push and PR CI: 137 Python with no skips; Linux/macOS each 151
Flutter with 12 explicit skips; Android all modes and unsigned iOS debug/release.
Independent driver/default analysis then finds six uncovered negative cases in
the routing guards. The local follow-up fixes them and preserves valid-port
compatibility: 145 Python / zero skipped, including nine live Flutter HTTP cases,
pass in a new disposable local PostgreSQL container. Existing databases are not
reset. The follow-up awaits its own publication/CI authorization; hosted changes
remain unauthorized. [New evidence](evidence/phase0-ci-routing-review-2026-10-18.json),
[deployment/sender/recovery approval plan](../infra/staging/PHASE0_CHANGE_PLAN.md).

**Wider entrypoint review:** authorized `a4f0003` publication passes all three PR
CI jobs (145 Python / zero skipped; each mobile job 151 passed / 12 explicit
skips). Its push macOS unsigned debug build fails with Flutter's Development Team
fallback, then passes both unsigned modes on a fresh runner; the actual first
Xcode cause is unconfirmed. Only macOS is rerun; API/Linux successes are inherited.
Separately, the local development-identity setup has the same routing bypass
before migrations. Fourteen negative cases fail before the fix. New local
`cbacc0a` rejects unsafe input before setup; 165 full Python tests / zero skipped,
including nine live Flutter HTTP cases, pass against another new disposable
database. That commit is now authorized and published, with all three jobs passing
in both push/PR CI: 165 Python / zero skipped, mobile 151 passed / 12 explicit skips
on each runner, Android all modes and unsigned iOS debug/release. No existing
database or hosted configuration is changed.
[Results](evidence/phase0-development-routing-and-ci-2026-10-18.json).

**Authenticated staging deployment preflight, Oct 18:** Playwright access is
restored. Render still runs `c5d5414`, with service Auto Deploy Off and no active
deployment displayed. The saved transport/runtime configuration and matching CA
file pass private classification checks. Read-only Supabase catalogs confirm the
restricted role, migration `0003`, 11 forced-RLS tables, required grants, 12 exact
owner-policy definitions and denied PUBLIC/API-role training access. The exact
`cbacc0a` selector enables deployment; its dialog is cancelled without submission.
Pipeline usage is 2 / 500 included minutes. Public health/readiness return 200 and
unauthenticated identity returns 401 after an earlier transport timeout whose
cause is unconfirmed. No hosted configuration, resource or credential changes;
no new authenticated Flutter run or regression rerun is claimed. Deployment and
bounded code rollback require explicit approval. Render incident 215476446235862
remains OPEN; physical/provider/operator gates remain open.
[New preflight evidence](evidence/phase0-staging-deployment-preflight-2026-10-18.json),
[exact deployment and rollback plan](../infra/staging/PHASE0_CHANGE_PLAN.md).

**Authorized exact-SHA deployment:** user approval is received and exact `cbacc0a`
is Live as `dep-dbaf73ijnfac73fg5l20`. Fresh public health/readiness return 200 and
unauthenticated identity 401; post-deployment saved service/transport settings
match expected classifications. No provider setting, credential, Blueprint,
schema or resource changes; no rollback. A native masked-entry workflow allows
the operator to read email independently. The Oct 18 attempt times out before
verification; its original Auth logs show initial **200** and deliberate immediate
resend **429 / over_email_send_rate_limit**, without a correlated SMTP error.
The operator subsequently confirms the recipient and locates the original email.

**Oct 19 post-deployment manual qualification:** the authorized fresh run skips
automatic resend and incorrect-code probes. A and B verify as distinct identities;
actual hosted synchronization, SDK refresh, accepted/duplicate receipts, file
restart, pending sign-out/revocation, local isolation and cross-owner hosted
read/mutation denial pass. The third submission, returning to A, is rejected with
`invalid_or_expired_code` before final pending recovery/bootstrap. The generic
failure screen is fixed locally and checked with six parser cases and a stubbed
UI; no application defect is established. Exact provider status/error correlation
is pending restoration of the extension connection. No further OTPs, test restart,
provider changes or rollback. Public health/readiness remain 200. Deployment
execution and partial authenticated proof do not close the full acceptance gate.
[Deployment evidence](evidence/phase0-staging-security-deployment-2026-10-18.json).

**Return-to-A review:** source and synthetic native UI checks find no recipient
switch, retained old entry or account-state mixup. A separate pacing defect is
reproduced and fixed: cooldown is now measured from successful request completion.
Two regressions fail before correction; all four scheduling cases and targeted
analysis pass afterward. This is not established as the earlier verification
failure's cause. Manual Auth-log correlation is requested without repeated browser
reconnection. One controlled three-request run is prepared but requires explicit
approval; no new OTP or hosted run is executed. Full A → B → A recovery remains
unqualified for this deployment until one complete run passes.

The next explicitly requested milestone is hosted **Supabase + Render staging**,
with a scoped [DM-018](DECISIONS.md#dm-018--render-staging-provider-qualification)
hosting decision. [Deployment preparation](../infra/staging/README.md), role/
migration verification and the real-credential Flutter harness are implemented.
Provider dashboard login enabled initial provisioning. The existing empty Mumbai project was selected
and named `daily-motion-staging`; Render Singapore initially deployed `8e5af65`
and now runs **c5d5414** after the verified rotation/recovery below. Hosted
Alembic `0003`, 11 forced-RLS tables, actual restricted-role owner/pool probes,
runtime readiness, denied provider-role training grants and six public HTTPS/auth/
contract checks pass. See [hosted evidence](evidence/phase0-hosted-staging-2026-10-14.json).
The publishable key is verified against the real Auth settings endpoint. The
unused Data API is disabled; public REST access is denied while Auth remains
reachable. Free-plan managed backups are absent. Real OTP/SMTP, verified-account
initialization, refresh and authenticated Flutter sync remain unperformed.
The owner designated controlled A/B inboxes; both real email-auth requests returned
HTTP 200. This proves request acceptance, not delivery or verified distinct owners.
Mailbox access and SMTP code templates remain required. Initial provider access
was unavailable at the earlier checkpoint below; the later native dashboard audit
confirmed historical credential retention without retrieving credential values.

**2026-10-15 qualification checkpoint:** provider/browser and mailbox control are
absent at **00:04 IST**; SMTP/template readiness has not been re-observed. The prerequisite
log inspection/rotation/reverification therefore blocks new OTP or authenticated
sync attempts. Existing local staging checks **25/25 pass**; the hosted Flutter
harness explicitly reports **0 executed / 1 skipped**. No delivery, verification,
distinct-identity, custom-SMTP or hosted account-switch evidence was invented.

**2026-10-15 continuation:** native Supabase dashboard access was restored through
the existing GitHub session. An aggregate-only query of hosted query statistics
returned **2 role statements / 2 plaintext-password statements** for the staging
runtime role. No credential or raw historical query text was returned. Rotation
has **not** occurred; no fresh OTP was requested. Browser keyboard input then
failed with `window_not_focused` after restoration; manual foreground focus is
required. Render deploy/application log review, credential rotation/secret update,
fresh runtime verification, SMTP/templates and inbox access remain open. Public
HTTPS checks passed **6/6** after one warm-up read timeout; they do not prove
rotation, email delivery or authenticated hosted synchronization.

Committed configuration repair **69b929e** replaces the deleted qualification
branch with `main` in the Render blueprint. The runbook requires checking both
Blueprint source and linked service branches, replacing old database sessions
after rotation, and verifying a fresh restricted connection. Hosted settings have
not been changed. No product/protocol feature or acceptance gate changed.
See the [continuation evidence](evidence/phase0-hosted-auth-2026-10-15.json) for
separate observed, unperformed and blocked results.
Actual [CI run 38665949212](https://github.com/bluxo1/Daily-Motion/actions/runs/38665949212)
passed all three jobs on `69b929e`: **104 Python / 0 skipped**, Linux/Mac each
**148 Flutter / 10 skipped**, Android all modes and unsigned iOS debug/release.
Local serialized execution again covered **104 Python / 56 PostgreSQL**, **148
ordinary Flutter + 9 live loopback cases** and four identical generated artifacts.
This does not qualify real hosted OTP/sync or physical hardware.

**Later 2026-10-15 recovery:** affected staging credentials were rotated using
the fixed provisioner. A protected saved-setting check first reproduced actual
credential rejection, then a mismatch after save/reload. Focused field entry and
normal blur fixed persistence; protected comparison after reload proved the saved
URL/password matched the current rotation before applying it. The first deployment
failed readiness; explicit retry **dep-db8efpon74is73epb8ng / c5d5414** is **Live**.
After terminating the remaining runtime session, a fresh connection again passed
**0003 / 11 forced-RLS / owner isolation / pooled context reset**, and public HTTPS
checks passed **6/6**. Three new rollback-only hosted probes passed across the
continuation; no personal workout/account data was seeded.

Aggregate audit is now **4 role statements: 2 retained legacy plaintext and 2 new
SCRAM**, with a SCRAM runtime verifier. Four available historical Render deployment
views and the seven-day application view had no matches for the checked credential
patterns; this is bounded inspection, not comprehensive log clearance or purge.
The current four-key client configuration reaches actual Auth settings (200).
See [rotation evidence](evidence/phase0-hosted-rotation-2026-10-15.json).

SMTP was re-observed **off**; Supabase explicitly locks subject/body editing until
custom SMTP is configured. Prepared code templates remain unapplied. Operator
configuration is requested in the protected provider page; **0 new OTP requests,
0 deliveries/verified accounts and 0 authenticated hosted Flutter cases** are
claimed. Existing deployed-source CI **38710259066** is green in all three jobs
and was rechecked, not rerun. No physical/provider gate or ADR changed.

**2026-10-16 continuation:** the operator reports custom SMTP configured. This
does not contradict the dated off-state above or establish delivery. Native
browser navigation returns `window_not_focused`, including a supported restore
attempt; manual foreground focus was requested. Saved SMTP and subject/body
activation remain unverified. No fresh OTP request was sent before those checks;
delivered/verified identities and executed authenticated hosted Flutter cases
remain **0**. No provider credential was requested or exposed.

Fresh public HTTPS checks pass **6/6**, after two warm-up read timeouts. The actual
Auth settings endpoint returns **200**, email auth enabled, using the four-key
client-safe staging configuration. These are public/configuration checks, not
SMTP, refresh, A/B switching or authenticated hosted-sync proof. Current
regression and boundary evidence is recorded in
[the continuation checkpoint](evidence/phase0-hosted-auth-2026-10-16.json).

**2026-10-16, 18:49 IST reattachment:** the operator confirmed manual foreground
and signed-in Gmail. After refreshing a stale browser-window reference, the first
navigation still returned `window_not_focused`; the current bridge advertises
`supports.windows.focus=false`. Browser actions stopped immediately without a
restore attempt. No rotation/database verification, new OTP request, inbox/code
read, authenticated harness case or hosted-auth result was added. Repair of the
browser-control connection remains the immediate boundary; SMTP is still
reported configured and its saved settings/templates remain unverified.

**2026-10-17 provider readback:** supported Playwright page access now bypasses
the desktop-focus boundary. Two explicit authenticated staging configuration
reads returned **200**. Saved SMTP host/user/password, sender email/name and port
are absent. Both saved auth templates still use confirmation links without a
Token marker or nonempty custom override; prepared subjects do not match.
The operator's earlier configuration report and an enabled editable form are not
saved-provider proof. No incomplete configuration was submitted.

The immediate human boundary is now entering/saving a real staging SMTP sender
directly in Supabase. No new OTP request, delivery, verification, distinct A/B
owner or authenticated hosted Flutter case occurred. Dashboard operator access
does not verify app owners. No rotation/database probe or unchanged regression
suite was repeated. Current Git main is **c9a8370**; deployment was not reverified
and its last observed revision remains separately dated **c5d5414 / Oct 15**.
See [the safe readback evidence](evidence/phase0-hosted-smtp-2026-10-17.json).

**Later 2026-10-17 continuation:** saved SMTP fields are now verified. Both
Confirmation and Magic Link templates were fixed to contain `{{ .Token }}` and
the prepared subject, then verified after reload. Account A's real request at
**15:59:56 UTC** returns **500 / unexpected_failure**; the correlated Auth event
at **15:59:58 UTC** reports Google SMTP **535 / BadCredentials**. The current
human boundary is correcting the SMTP login directly in Supabase. No actual
delivery, verified identity or hosted Flutter case is claimed. Rotation/database
probes were not repeated. [New evidence](evidence/phase0-hosted-smtp-delivery-2026-10-17.json).

Source `8e5af65` passed all three jobs in
[actual run 38587594908](https://github.com/bluxo1/Daily-Motion/actions/runs/38587594908):
**102 Python**, including **54 PostgreSQL** cases; **148 ordinary Flutter passed/
10 skipped**, separate **9 loopback Flutter HTTP** cases, Android all modes and
unsigned iOS debug/release. A local unsigned **staging-configured** Android release
also compiled. No physical or real-email qualification is inferred.

Continued source **6606db0** replaces plaintext password DDL with explicit
client-side SCRAM. Local regressions pass **104 Python / 56 PostgreSQL**, **148
Flutter / 10 skipped** plus **9 live HTTP** cases; all four generated artifacts
match. Two new real database attacks fail before/pass after the fix. The initial
Flutter full run had one worker-boundary timeout; three isolated kill cases and
the full serial repeat passed. [IMPLEMENTATION.md](IMPLEMENTATION.md) retains the
failed run and current CI attempt, rather than suppressing failures. Historical
hosted rotation was subsequently applied as documented above; retained historical
statistics remain unpurged.

Staging preparation source `ef025c2` passed all three jobs in
[actual CI run 38570967779](https://github.com/bluxo1/Daily-Motion/actions/runs/38570967779):
**99 Python** (including **51 PostgreSQL** cases), **148 ordinary Flutter** with
**10 explicit skips**, separate **9 live loopback Flutter HTTP** cases, Android
debug/profile/release and unsigned iOS debug/release. The new hosted harness is
one of the skips; no hosted qualification is inferred from these results.

Older chronological evidence called interactive conflict resolution, public
account export/deletion jobs, final account purge, backup deletion-ledger restore
drills, scheduled production retention/abuse operations and full ten-year capacity
qualification "remaining Phase 0 gates". The roadmap assigns **production feature
completeness and public release readiness to Phase 1**. Those remain required
before public release; they are not authority to start Phase 1 now. Foundation
conflict preservation, disable/retirement/redaction, bounded capacity failure,
network-independent saves and migration safety are already exercised. Real
managed-provider backup/restore arrangements still require the operator project.

No gate was reduced: the overall Phase 0 physical acceptance and external
dependencies remain open. Historical MEMORY entries describe what was known then;
the latest appended entry and this matrix resolve their scope/status ambiguity.
The foundation protocol and production hosting decision are unchanged. DM-018
records the explicitly requested Render staging hosting exception.
