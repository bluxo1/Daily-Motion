# Phase 0 evidence reconciliation

Audited 2026-10-15 (IST); continuation on `phase0-hosted-auth-2026-10-15`
from merged `main` (`9669fa2`).
[ROADMAP.md](ROADMAP.md) remains the scope authority. This matrix distinguishes
implemented foundation work from its separate physical/provider acceptance.
[IMPLEMENTATION.md](IMPLEMENTATION.md) records commands, counts and environments;
[phases.md](phases.md) is the checklist. A checked foundation row does not close
the overall Phase 0 exit gate.

| Authoritative Phase 0 work | Actual evidence | Status |
|---|---|---|
| Flutter/Riverpod/Drift, modular FastAPI, migrations and pinned toolchains | Mobile/API source, lockfiles, Alembic 0001–0003, Drift 1→3 and 2→3 tests; Linux Android all modes and macOS unsigned iOS debug/release CI | Complete for buildable foundations |
| Onboarding interaction prototype | Supabase OTP/account UI; controlled SDK/provider and widget/lifecycle tests, first verified owner initialization | Complete as executable prototype; real delivery remains external |
| Routine-editing interaction prototype | Separate synthetic `routine_prototype.dart` entrypoint; editable planned sets/rep range/rest, immutable workout previews, validation/back/keyboard/large-text tests | Complete as disposable prototype; no production routine storage or sync |
| Active logging and history interaction prototypes | Fixture Train/History, durable editor/drafts, completion/abandonment/corrections; widget tests and real SQLite suites | Complete as executable foundation; public feature breadth belongs to Phase 1 |
| Small internal light/dark design system and accessible numeric/set controls | Semantic themes, explicit action/text colors, contrast tests, 320px/200% text/keyboard and labeled tap-target widget tests | Complete for implemented controls; physical usability/screen-reader acceptance remains external |
| Account-scoped local storage, transactions, drafts/outbox/timers and restart recovery | File-backed recovery suites, hard Windows kills, pager-full rollback, Android emulator protected-session seed/force-stop/recover | Complete for tested foundation primitives; phone lifecycle/power/storage remains external |
| Aggregate CAS, exact receipts, shadow/working separation, committed feed and consistent bootstrap | Real restricted-role PostgreSQL, live Flutter HTTP, atomic page/cursor and staged snapshot fault/restart tests | Complete for implemented protocol foundation; no physical-device inference |
| Account-disable races, erased transport/snapshots and migrations | Real owner locks/retirement/redaction tests, file-backed pending deletion and additive migration tests | Complete for foundation erasure barriers; public export/deletion jobs are Phase 1 |
| Additive checked API/contracts and fixtures | Generated OpenAPI/Dart DTO/limits, shared fixtures, byte-for-byte reproduction checks and fail-closed parsing tests | Complete for current version; four generated outputs include Drift |
| CI format/static/tests/docs and security basics | Three actual remote jobs, secret guard, release synthetic-auth rejection, safe logging tests, runtime-role/forced-RLS guard and real database attacks | Complete for implemented baseline; not a comprehensive security certification |
| Managed Mumbai region, backups, processor arrangements and review ownership | Public desk review/operator checklist in [infra/QUALIFICATION.md](../infra/QUALIFICATION.md), plus actual Mumbai staging PostgreSQL 17.11; observed free plan without managed backups | Staging region/database verified; managed backup/restore, processor and named operator/reviewer acceptance outstanding |
| Physical iPhone and Android acceptance, signed installation, native protection/backup/accessibility and durable-save p95 | Device procedures and native harnesses in [DEVICE_QUALIFICATION.md](DEVICE_QUALIFICATION.md); safe [emulator evidence](evidence/phase0-windows-native-2026-10-13.json) explicitly ineligible | External hardware/signing/provider acceptance outstanding |

## Scope corrections

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
