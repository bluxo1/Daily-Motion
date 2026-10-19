# Phase 0 PR #6 integration recovery

Audit date: 2026-10-20 IST. Phase 0 remains in progress; Phase 1 is unstarted.
This recovery authorizes no provider settings, OTP requests, key changes or deployment.
Render incident **215476446235862 remains OPEN**, pending confirmed invalidation.

## Why the merged PR is absent

| Object | Observed state |
| --- | --- |
| Healthy remote `main` | `8ba5a980a4dcd2e31ce8cb6246176a522b912f39` |
| Original auth head | `950a9463df62f2df7bef2d9237410d095b4b80e4` |
| PR #6 merge | `b2cfee92d6a22b5f6d829268276af9a2ab637bc0`, parents healthy main and original auth head |
| Common ancestor of main/auth | `57a4494df84c414bf5d2572fdf65c47f77bb8d1a` |

[PR #6](https://github.com/bluxo1/Daily-Motion/pull/6) is marked merged at
2026-10-19 17:40:06 UTC. The original head's
[push run 39288518142](https://github.com/bluxo1/Daily-Motion/actions/runs/39288518142)
passed all three jobs. The merge contained additional source edits beyond that
tested head. Its [push run 39296087127](https://github.com/bluxo1/Daily-Motion/actions/runs/39296087127)
failed Linux Dart formatting: line 14, column 19 of
`test/support/hosted_otp_schedule.dart` could not be parsed. API passed and macOS
was cancelled; those outcomes do not qualify the merged Flutter source.

Local reflogs establish this sequence on 2026-10-19 IST:

1. 23:09:55: local main created merge `b2cfee9`.
2. 23:10:07: remote-tracking main advanced to it, recorded as `update by push`.
3. 23:12:19: local main reset to `8ba5a98`.
4. 23:12:26: remote-tracking main moved back to `8ba5a98`, again `update by push`.

This is a non-fast-forward history replacement, not a revert commit. GitHub's
merged PR record persists independently of the branch reference. No missing Git
object or new application revert explains the absent merge. Reflogs identify the
operations and timing, not which human or automation initiated them.
[Restored-main run 39296413052](https://github.com/bluxo1/Daily-Motion/actions/runs/39296413052)
is green. Remote main was independently read before recovery and was unprotected.

## Preservation and selective recovery

All five pre-existing worktrees retain their HEAD, index and working files.
Before recovery, the integration worktree had staged and unstaged changes;
mobile-qualification and recovery also had unstaged changes. Their status and
SHA-256 hashes of staged/unstaged patches were recorded privately for comparison.
The root's untracked skill installation is unrelated and excluded.
`recovery/pr6-bad-merge-20261020` preserves the bad merge. Existing auth refs preserve
the original head. No reset, stash, cleanup, worktree removal or force-push is part
of this recovery. A new worktree/branch starts directly from healthy remote main.

The recovery selects application/test/operator sources from `950a946`, preserving
current main's newer implementation/evidence/change-plan history. It retains
successful-request cooldown timing, stale-recipient invalidation, bounded A/B/A
scheduling, frozen recipients, one-use challenges, safe diagnostic categories and
local JWKS rotation tests. It rejects the merge's malformed constructor, fixed UTC
clock, no-op default delay and malformed `Duration` call. Default-behavior tests
exercise the actual clock and timer rather than supplying both replacements.

Review additionally found that the operator bridge treated any zero-exit child as
qualification success. Recovery requires the full ordered lifecycle checkpoints,
three submitted/consumed A/B/A challenges, and a successful child. Local regressions
exercise skipped/incomplete/out-of-order runs. They establish bridge safety, not
new hosted delivery or authenticated qualification.

## Recommended main protection

Recommendation only; repository settings are unchanged. Configure an active rule
for `main` that requires a pull request, review and all three GitHub Actions checks:
`api`, `mobile (ubuntu-24.04)` and `mobile (macos-15-intel)`. Require the branch to
be up to date before merge, dismiss approvals on new changes and prevent bypass
for routine direct updates, including administrators. Block force-pushes and
branch deletion. Restrict update authority to the intended maintainers/integration
automation through the reviewed PR path; keep any emergency bypass narrow and audited.

Do not merge a locally edited conflict-resolution tree on the strength of earlier
head checks. Publish and test that tree first. A merge queue is an optional future
alternative; the current workflow lacks `merge_group` and must support that event
before a queue is enabled. See GitHub's
[protected-branch guidance](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)
and [required-check troubleshooting](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-required-status-checks).

## Validation

Local targeted Flutter validation passes **35 tests**. Full Windows Flutter
validation passes **161 tests / 12 explicit skips**, with zero analysis issues
and 59 formatted Dart files unchanged. Focused Python authentication/operator
validation passes **39 tests**; full local Python passes **148 / 56 skipped**.
The skips are 55 PostgreSQL cases and the connected Flutter harness: Docker
Desktop failed startup, and no existing database or Docker data was reset.
Ruff formatting/lint pass for 40 Python files; strict mypy passes 13 source files.
All four generated artifacts reproduce byte-for-byte after OpenAPI/transport and
Drift generation (88 seconds, 116 builder outputs). Static native guards,
documentation links and the credential scan pass. An isolated original-versus-
recovered bridge execution reproduces zero-exit/skipped output reporting PASS
before the fix and failing closed afterward; it sends no provider requests.

The recovered source `e3da9d0448fc57215d70b88a9d1e45d410a2af9d` is a GitHub-verified
signed commit whose tree matches the reviewed local index. Local signing settings
remain enabled. [PR #7](https://github.com/bluxo1/Daily-Motion/pull/7) targets main;
no merge or main update is performed.

All three [source PR CI jobs](https://github.com/bluxo1/Daily-Motion/actions/runs/39306127033)
pass: **204 Python / zero skipped**, including 55 real PostgreSQL cases and the
harness executing nine live Flutter HTTP cases; each Linux/macOS runner passes
**161 Flutter / 12 explicit skips**. Android debug/profile/release plus prototype
debug and unsigned iOS debug/release compilation pass. All four generated-output
checks pass. This is compilation and desktop/database evidence, not phone proof.

Only after this passing integration was the Phase 0 matrix reconciled. Earlier
dated hosted results remain historical evidence; the failed return-to-A run and
provider/hardware/operator blockers remain open. No production delivery,
trusted-key rotation, phone storage or physical performance qualification follows
from these tests. [Machine-readable recovery results](evidence/phase0-integration-recovery-2026-10-20.json).
