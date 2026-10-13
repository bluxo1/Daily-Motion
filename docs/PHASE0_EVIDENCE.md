# Phase 0 evidence reconciliation

Audited 2026-10-14 (IST) on `phase0-qualification-2026-10-13`.
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
| Managed Mumbai region, backups, processor arrangements and review ownership | Operator qualification checklist in [infra/QUALIFICATION.md](../infra/QUALIFICATION.md); synthetic local PostgreSQL only | External project/contract/operator review outstanding; no live settings claimed |
| Physical iPhone and Android acceptance, signed installation, native protection/backup/accessibility and durable-save p95 | Device procedures and native harnesses in [DEVICE_QUALIFICATION.md](DEVICE_QUALIFICATION.md); safe [emulator evidence](evidence/phase0-windows-native-2026-10-13.json) explicitly ineligible | External hardware/signing/provider acceptance outstanding |

## Scope corrections

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
No architectural decision changed.
