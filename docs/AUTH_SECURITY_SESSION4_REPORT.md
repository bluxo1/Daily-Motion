# Session 1 report for Session 4

Worktree: `E:/Motion/worktrees/auth-security`; branch: `phase0/auth-security`;
base: `57a4494df84c414bf5d2572fdf65c47f77bb8d1a`. Phase 0 remains in progress.
Shared roadmap/status documents have not been edited.

## Verified local changes

Two application regressions failed before correction and now pass:

- Successful OTP requests start a full 60-second resend cooldown **after** the
  provider returns. Request-start pacing is retained for ambiguous failures.
- A new OTP request clears the prior recipient challenge. A failed request for
  B cannot submit a code against A's old challenge or initialize A accidentally.

The hosted candidate freezes distinct A/B recipients, preserves receipt replay
assertions, waits 61 seconds from successful request completion per account,
allows at most three OTP requests and stops after a request failure. Automatic
resend/wrong-code probes and initialization retries are removed from this
lifecycle case. No new hosted qualification has run.

Focused local results: **53 Flutter passed / 0 skipped**, including real
file-backed SQLite account lifecycle, isolation, refresh/logout races, safe SDK
errors and six request-scheduling tests; **35 Python passed / 0 skipped** for
signed JWTs, real JWKS cache behavior with ephemeral keys and the reviewed
operator bridge. Ruff formatting and lint pass on all 36 checked Python files;
mypy passes on 10 source files. Full Flutter analysis passes with no issues
(145.3 seconds). PostgreSQL integration, remote CI and physical devices were not run.

The JWKS tests show both rollover behavior and its limits: cached old trust is
not instantly revoked, process-local invalidation removes it, the 300-second TTL
forces rediscovery, and an expired cache cannot authorize through a discovery
outage. Unknown-key discovery respects the library's 30-second cooldown.

A third confirmed defect affects the older ignored operator helper: its
`/diagnostic` route's regex redactor lets an opaque refresh-token-shaped string
escape. A synthetic regression failed before correction; no real credential
disclosure through this route was observed. The reviewed runner now lives in
`tools/auth_security/`, returns only allowlisted diagnostics and holds no raw
reporter output in bridge state. It also rejects non-POST mutations, repeated/
overlapping/fourth challenges, wrong staging targets and extra client keys.
Failed process startup stops safely. Use this runner instead of the older
ignored helper. The private four-key configuration and controlled recipients
are prepared locally and ignored by Git; the GUI has not launched.

## Evidence and approval boundaries

[Machine-readable evidence](evidence/phase0-auth-security-session1-2026-10-19.json)
preserves historical successes, both before-fix failures and the current checks.
The imported deployment/preflight and rejected-OTP files match the original
uncommitted checkpoints byte-for-byte; their original timestamps and hashes
remain intact.

[The auth/security procedure](../infra/staging/AUTH_SECURITY_QUALIFICATION.md)
contains the bounded hosted run, staging signing-key rehearsal, SMTP proposal
and Render incident requirements. External work remains specifically blocked:

| Item | Remaining dependency |
| --- | --- |
| Rejected return to A | Only timestamp/status/error_code/request_id from the existing Auth event; provider sign-in or operator-supplied metadata is needed. The cause remains unconfirmed. |
| Fresh A → B → A proof on the target deployment | Explicit approval for one three-request run and recipient/operator availability. The reviewed runner and private inputs are prepared in this worktree. |
| Trusted signing-key rehearsal | Separate approval for exact provider actions, authenticated operator access and any separately scoped verifier restart. Local JWKS tests are preparation only. |
| SMTP capacity | Approve or reject 30 → 10 emails/hour and name the owner of sender-wide usage/delivery monitoring. The proposed nominal 240/day is not a daily account-wide cap. |
| Render Support 215476446235862 | Authenticated access and explicit provider-side hook invalidation proof. Status remains OPEN; no new reply, invocation, resource change or revocation is claimed. |
| Commits | The authorized commit failed because the configured SSH signing key could not unlock. Signing remains enabled; the user has been asked to unlock it locally. No new commit SHA exists at this checkpoint. |

A read-only public JWKS check at **2026-10-19 14:46:17 UTC** returned 200,
one ES256 key. Provider dashboards in the isolated browser require sign-in.
No new OTPs, settings changes, deployment, rotation, purchases, push or merge
occurred. Earlier hosted A → B → A/elapsed-expiry successes and the later failed
return to A must remain separate observations in shared status documents.

One progress update was accepted by the existing coordinator terminal for
Session 4; a receiving turn start was not observed. This file is the durable
report. Update shared implementation/evidence status only from the exact results
recorded here, preserving the external/provider and physical-device limitations.
