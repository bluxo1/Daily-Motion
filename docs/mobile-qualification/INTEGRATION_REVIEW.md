# Session 3 integration review

Reviewed against protected main `0e64b310a2f4e1a2f12deb1896cc61d2137451e0`.
The source implementation is `e5ece1e61993156d2409b6c9f7be1e68ca05d942` and
the source evidence is `7806046f1b196a6537e681717513a44663938176`.
The original branch, commits, worktree and evidence remain intact. Integration
uses a new `fix/phase0-mobile-qualification-integration` branch and worktree.
The original [Session 3 handoff](SESSION3.md#handoff-to-session-4) remains a
historical report of its own revision, with zero physical samples.

## Reviewed change and compatibility

Both source commits apply cleanly. The resulting product changes preserve
protected storage on Android errors, display prescribed load units and recorded
effort, handle timer-cancel failure without losing the timer, and advance the
correction keyboard to its required reason. Native adapters expose only the
application ID needed to reject ordinary installations in synthetic harnesses.
No schema, API contract, cloud identity or signing identity changes are included.

The native storage harness checks the owner grant separately from the session,
preserves exact frozen-request checksums, verifies drafts and pending counts,
and checks SQLite integrity and foreign keys. The recorded force-stop proves a
live PID before termination and no PID afterward. The reboot record proves a
changed boot counter and database presence before launching recovery. The
initial invalid reboot attempt remains recorded: default Flutter drive teardown
uninstalled the synthetic application. The corrected intermediate-stage
procedure uses `--keep-app-running`. These remain original-revision emulator
receipts, not reruns of the integration branch or evidence of phone behavior.

Timer persistence still uses a monotonic sample with continuity identity and
wall-clock fallback. Same-boot recovery retains an exact countdown estimate;
reboot or clock uncertainty is labelled approximate. Timer cancellation errors
are sanitized. No timer value becomes measured physiological rest.

The benchmark still times the complete `WorkoutController.record` future.
It now requires explicit completion, fixed warmups and declared history before
qualification, retains failed durations and partial successful samples, and
writes driver receipts on failure. The original 200-sample profile result has
an independently checked nearest-rank p95 of 43,171 microseconds. Its physical
evidence and target-met flags remain false. The no-provider workload does not
qualify active-sync, long-history or release-runtime performance.

[Merged PR #7](https://github.com/bluxo1/Daily-Motion/pull/7) protections are
preserved exactly, including successful-request OTP cooldown, stale-recipient
invalidation, default clock/delay tests and operator-bridge lifecycle validation.
The auth controller, auth account tests, hosted schedule helper and operator
bridge were compared byte-for-byte with current main. Secure-storage changes do
not weaken account binding, owner isolation or explicit sign-out locking.

Session 2 implementation `77e5124bf8e0065dbcaf39c919f0e33cc616f93f` touches the
repository and sync layers rather than these product files. Its mobile patch
applies cleanly and was tested as a temporary overlay with all six file-backed
restore regressions. Frozen branches, original bases and the private restore
upload fence survive the combined tests. The overlay was removed afterward;
this PR retains main's repository/sync files exactly. Session 2 still needs its
own reviewed integration. A changed Session 2 candidate needs renewed combined
verification; these tests qualify only the identified patch.

## Review fixes and repeatable validation

Review found a stale-PID cleanup edge in the process-kill harness. Successful
worker termination is now recorded immediately, before waiting for pipe EOF.
Cleanup also avoids killing an already-exited launcher. Existing real-process
before/during/after-commit tests pass with this correction.

[The evidence validator](../../tools/check_mobile_qualification.py) checks
archived receipt hashes, storage assertions, force-stop/reboot preconditions,
all 200 raw benchmark samples and recomputed percentiles. It rejects physical
promotion and signed-install claims from unsigned compilation. Four focused
tamper regressions exercise the validator. Documentation checks now include
this nested directory. CI also compiles Android native storage, the Android
profile collector and the unsigned iOS native storage entrypoint. Compilation
does not execute those native harnesses.

| Local check | Result |
| --- | --- |
| Complete Flutter suite on the integration source | 171 passed, 12 explicitly skipped |
| Connected protocol and Flutter HTTP/PostgreSQL | 6 Python cases passed, including 9 Flutter HTTP cases; zero skipped |
| Complete Flutter suite with Session 2 mobile overlay | 177 passed, 12 explicitly skipped; includes 6 restore regressions |
| Connected protocol with that overlay | 6 Python cases and 9 Flutter HTTP cases passed; zero skipped |
| Generated Drift source and Dart formatting | No generated diff; 63 files checked, zero formatting changes |
| Flutter analysis | No issues |
| Python formatting/lint and strict source/script typing | Passed |
| Native configuration, documentation, secret and whitespace checks | Passed |
| Archived receipt validator and tamper regressions | Passed; four regressions |

The ordinary Flutter skips are nine connected cases run separately above and
three hosted/provider cases not rerun. Do not add the embedded Flutter count to
the Python harness count as distinct backend cases. Both connected runs used
an isolated PostgreSQL 17.11 cluster on local port 26483, restricted runtime role,
real JWT/HTTP/SQLite/PostgreSQL and simulated provider identity. No shared or
hosted database was touched. The task cluster is stopped. A cluster-unavailable
attempt produced six setup errors; the successful retry and the earlier failed
attempt are separately retained. An earlier log-decoding error caused a duplicate
base run rather than an overlay run; it is not counted as overlay qualification.

[Local machine-readable results](integration-local-evidence-2026-10-20.json)
include raw-log hashes, counts, source mobile-tree identity and the overlay patch
hash. Reproduce the base suite with `flutter test --no-pub --concurrency=1
--machine`. Reproduce connected tests with the documented isolated test setup,
`DM_RUN_CONNECTED=1`, then `pytest -q -s tests/test_connected_protocol.py
tests/test_flutter_connected.py`. To reproduce compatibility, apply only the
three mobile paths listed in the evidence from `git diff 77e5124^ 77e5124`, run
both suites, then reverse the patch. Preserve all other account/auth files.
Review all three required CI jobs on the exact PR head before approval; CI build
results belong to that revision rather than the archived emulator revision.

## Signing and remaining acceptance

The original source commits were unsigned and are preserved without rewriting.
Local SSH commit signing remains enabled; its configured key has no reachable
agent in this session. New integration commits use GitHub's verified server
signing through `createCommitOnBranch`. The publisher verifies a valid GitHub
signature and an exact match between the server tree and reviewed Git index.
No signing checks, branch protection or keys are disabled or changed.

**Physical sample count remains zero.** Hardware Android/iPhone durability,
signed installation/upgrade, iOS runtime, actual Keystore/Keychain behavior,
lock/key-loss recovery, backup/transfer, TalkBack/VoiceOver and native keyboard/
back gestures, disk/power faults and physical durable-save p95 at most 100 ms
remain open. Android emulator detection is a heuristic; operator hardware
attestation is still required. Disabling destructive storage reset preserves
recovery material but does not solve irrecoverable key loss. CI iOS compilation
does not qualify these device behaviors. Release instrumentation and realistic
active-sync/long-history measurements remain separate work. Phase 0 stays open;
Phase 1 has not started. Approval is required before merging this PR.
