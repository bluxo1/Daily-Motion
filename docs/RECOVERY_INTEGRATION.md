# Session 2 recovery integration

2026-10-21 IST. Phase 0 remains in progress; Phase 1 is unstarted. This is local
recovery implementation evidence, not authorization for a hosted restore.

## Source and preservation

Integration starts at protected main `5975999bdb617b54a3c4e644ad07604a81fad025`,
containing merged PR #7 authentication and PR #8 mobile qualification. The complete
[Session 2 handoff](SESSION2_RECOVERY_HANDOFF.md), implementation
`77e5124bf8e0065dbcaf39c919f0e33cc616f93f` and evidence
`ddbd41878af5c62d8af12e322be3540247c79b09` were inspected. Their patch applied
cleanly to an isolated integration branch; no older branch tree replaced main.
The original commits/evidence and all seven existing worktrees/indexes are
preserved. Unrelated skills are excluded.

The original commits documented a command-specific signing override. Integration
does not repeat it: signing stays required, and publication must verify both the
signature and exact reviewed tree. No merge is authorized by this evidence.

## Behavior and adversarial fixes

The operator SQL fence changes restored feed generations, advances the synthetic
erasure fence, raises the bootstrap watermark and invalidates snapshots in one
explicit transaction. Receipts/retirements remain intact. This procedure targets
only an approved isolated restore; it is not an automatic startup hook.

Mobile bootstrap retains acknowledged workouts absent from a backup as conflicts.
Divergent restored roots update their shadow separately from preserved local
observations, original pending bases and frozen envelopes. A private persisted
marker fences uploads across logging/restart, including downloaded roots with no
historical outbox. Local logging continues; permanent retirement still wins.

Independent review found an additional defect: a higher divergent revision after
a generation change was trusted as newer history. The unfixed regression returned
`synchronized` instead of `attention`; that path could overwrite acknowledged
observations. Integration removes the cross-generation revision shortcut. New
tests cover lower/equal/higher divergence, missing roots, unchanged controls,
downloaded roots, continued logging/reopening, atomic activation retry and erasure.

CI previously lacked `DM_RUN_RECOVERY=1`. Integration enables it, verifies the
PostgreSQL image supplied by CI, and rejects JUnit skip/failure/error or missing
recovery/live HTTP collection. Connected qualification requires nine visible,
successful, unskipped Flutter machine events, successful completion and process
exit. Parser tests and zero-exit empty output cannot replace live qualification.

## Local validation

Windows, Flutter 3.47.7/Dart 3.13.5, Python 3.13.14, frozen dependencies and new
disposable native PostgreSQL 17.11 clusters. The portable binary fingerprint is
the previously recorded Session 2 provenance, not publisher attestation. No
existing local or hosted application database was selected.

| Check | Exact result |
| --- | --- |
| Unfixed higher-revision regression | One failure reproduced before fixing runtime |
| Focused file-backed SQLite recovery | 9 passed |
| Ordinary Flutter | 180 passed, 12 explicit skips; 134.01 seconds |
| Full Python/real PostgreSQL | 237 passed, zero skipped; 106.24 seconds |
| Recovery cases within Python total | 14; all 11 application tables populated |
| Recovery target guards within Python total | 13 |
| Connected Flutter through Python wrapper | 9 passed, zero skipped; real JWT/HTTP/SQLite/PostgreSQL, simulated provider identity |
| Connected report guards within Python total | 6 passed |
| Separate Python report validator unittest suite | 9 passed |
| Existing mobile receipt validator unittest suite | 4 passed |
| Flutter analysis | Zero issues |
| Python static checks | Ruff format/lint: 47 files; strict mypy: 13 source files |
| Dart format/generation | 64 formatted files unchanged; all four generated artifacts reproduce after required formatting; Drift 58 seconds/125 outputs |
| Migrations/cleanup | Alembic `0003`, repeated upgrade verified; generated clusters removed |

The 12 ordinary Flutter skips are nine connected cases run separately above and
three forbidden hosted cases. Python subsets are already in the total; do not
sum them again. Fault cases cover fence rollback/backend loss, interrupted restore
and retry, repeated fencing, WAL restart, RLS/owner isolation, checksums, receipts
and retirement. Required PR CI checks the published head's Android configurations
and unsigned iOS builds. This local checkpoint claims no future remote result and
does not qualify physical phones or hosted recovery.

## Hook investigation

The October 17 visible failures were Security Guidance 2.0.10 launching an unusable
WSL Bash, Claude Memory missing Bun, and notification command length exceeding
Windows limits. Supplementary security review launch was affected. Saved October
19 repair evidence reports 52 enabled/trusted hooks, zero loading warnings/errors,
22 launch/security probes, 16 notification tests and eight helper tests passing.

Separately, Session 2 security logs misclassified successful source commits and
skipped their reviews; Stop had an empty review set. Baseline/touched-path state
did not establish recovery-worktree coverage. The hook reads stdout/stderr while
retained Codex records use aggregated output/exit status. Raw historical hook input
is absent, so field mapping versus wrong-worktree context cannot be proven
individually. Automatic commit/Stop security coverage is **not claimed**. Deliberate
self-review, independent reviews and repository/CI checks gate this integration.
No installed Git pre-commit hook exists (`core.hooksPath` unset; sample files only).
No Git safety hook or signing requirement was bypassed for this integration. The
audit did not change global hooks/configuration.

## Remaining risks and approvals

- Push envelopes lack restored-generation binding. Preflight cannot close a
  restore between that request and upload. Keep restored writes closed until
  branch reconciliation and qualified-client admission; this local marker is
  not a universal server-side restore barrier.
- Incrementing a rewound erasure epoch once may remain below a discarded phone
  epoch. Independent deletion-ledger/high-water replay and payload suppression
  remain unqualified. Retained retirement rows do not prove ledger replay.
- Explicit conflict resolution is future work; no automatic merge discards a branch.
- Hosted restore/retention/key custody/RPO/RTO and REC-01 through REC-06 remain
  unapproved. No hosted DB, restore, OTP, deployment, provider change or rotation.
- All outstanding Phase 0 hardware, protected-storage, signed-installation,
  backup/transfer, accessibility, phone fault/power, physical p95, provider and
  operator gates remain open. Render **215476446235862 remains OPEN**.

No schema, public contract, dependency or ADR changes. PR #7 authentication and
PR #8 native qualification files remain unchanged. See
[integration evidence](evidence/phase0-recovery-integration-2026-10-21.json),
[source qualification](RECOVERY_QUALIFICATION.md) and the
[unapproved hosted strategy](../infra/HOSTED_RECOVERY_STRATEGY.md).
