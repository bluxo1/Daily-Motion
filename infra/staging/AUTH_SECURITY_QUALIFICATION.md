# Phase 0 authentication and security qualification

This procedure was recovered from `phase0/auth-security` through the
[PR #6 integration audit](../../docs/INTEGRATION_RECOVERY.md). Preparation and
local tests do not authorize hosted execution or establish production readiness.

## Preserved checkpoints and current diagnosis

- [Oct 18 hosted functional proof](../../docs/evidence/phase0-hosted-auth-flow-2026-10-18.json)
  records a complete A → B → A lifecycle against the previously deployed source.
- [Later provider qualification](../../docs/evidence/phase0-provider-qualification-2026-10-18.json)
  records another successful lifecycle, real refresh-token revocation, and actual
  elapsed OTP expiry. These observations remain valid for their dated scope.
- [Exact deployment and rejected return to A](../../docs/evidence/phase0-staging-security-deployment-2026-10-18.json)
  records deployment `cbacc0a`, seven successful checkpoint events, and the third
  verification failing with `invalid_or_expired_code`. The final pending recovery
  and bootstrap were not executed. This does not erase the preceding successes.

The application maps multiple provider verification failures to the same safe
category. That category alone cannot distinguish an old, mistyped, expired or
already consumed code. Source review and synthetic tests do not establish which
one occurred. Do not attribute the rejection to the separately reproduced pacing
defect without provider correlation.

The remaining read-only lookup is Supabase Auth's `POST /verify` event on
2026-10-19 between **06:40 and 06:46 UTC**, after B's success at **06:42:11 UTC**.
Collect only timestamp, HTTP status, allowlisted error code and request ID.
Exclude bodies, headers, recipient addresses, codes and sessions. If event
retention has elapsed, record that limitation rather than inventing a cause.

## One controlled hosted lifecycle run — approval required

Target only Supabase project `pulruylvpehwftwqcvct` and the existing
`daily-motion-staging-api` service. The last recorded deployment is
`cbacc0ab74d8d5bf7e54aff7a13d27267bf8cfdd`; read the actual live revision before
execution. Do not substitute the current Git head or deploy this branch.

Approval scope is **one run, at most three OTP requests, A → B → A**. There are
no automatic resends, wrong-code probes, OTP retries or automatic test restarts.
Stop on the first failure. Sender-budget exhaustion, provider rejection, failed
initialization or a missing inbox message requires diagnosis before another run.

1. Verify the client configuration contains only the four keys in
   [mobile.example.json](mobile.example.json). Keep controlled recipients and
   codes private. Freeze distinct A/B recipient addresses for the entire run.
2. After approval, launch the reviewed masked-entry runner from **this worktree**:
   `python tools/auth_security/manual_otp_entry.py`. Its bridge launches Flutter
   from this worktree and uses the pinned SDK at `.tools/flutter`, this worktree's
   cache/temp folders, and the ignored client configuration/controlled recipients
   in `.tools/staging`. Prepare the pinned SDK/cache/temp paths in the chosen
   worktree before the approved run; an SDK junction in another worktree is not
   evidence that this worktree is ready. Import/preflight checks do not launch
   the GUI or a hosted test.
3. The runner starts only `test/hosted_auth_lifecycle_test.dart` with
   `DM_HOSTED_AUTH_LIFECYCLE=1` and `DM_HOSTED_OTP_BRIDGE` pointing to that bridge.
   Other inherited `DM_*` settings are removed from the Flutter child's
   environment. The four-key configuration is checked against the exact staging
   targets before a loopback server can start. Ordinary regressions leave hosted
   flags unset. Never enable request/debug logging or retain raw test output.
4. For each step, use the newest recipient-delivered code for that step's
   request timestamp. A sender's Sent copy does not qualify delivery. Clear the
   entry between challenges; submit a code once. Return to A waits at least 61
   seconds from A's successful request completion.
5. Require all checkpoints from SDK refresh through receipt replay, SQLite
   reopen, pending sign-out, revoked-refresh denial, B isolation and final A
   pending recovery plus hosted bootstrap. A/B verification alone is partial.
   The bridge accepts PASS only for a zero-exit child, the exact nine ordered
   lifecycle events, three submitted A/B/A challenges and no unconsumed codes.
   A skipped or incomplete test is a failure, even if its process exits zero.
6. Record only timestamps, safe categories, checkpoint booleans, source hashes
   and the exact live revision. Preserve failed-run evidence. End volatile
   bridge/session state after extracting the redacted result. Do not silently
   create cleanup/deletion requests beyond the reviewed harness behavior.

The reviewed runner sources are
[manual_otp_entry.py](../../tools/auth_security/manual_otp_entry.py) and
[operator_bridge.py](../../tools/auth_security/operator_bridge.py). Codes are
transient, masked and single-use. The bridge retains only safe failure fields;
its diagnostic route cannot return raw reporter output. Synthetic tests cover
an opaque refresh-token-shaped marker escaping the older regex redactor, header/
origin/size rejection, POST-only mutations, the three-step challenge boundary,
configuration isolation and failed child startup. No real disclosure through
that older route was observed. Use the reviewed runner instead of the older
ignored helper; confirm the candidate hashes in the session evidence before
approval. A prepared runner is not new hosted proof.

## Trusted signing-key rehearsal — separate approval required

This is a proposed **staging-only**, bounded provider operation. It has not run.
Use a provider-generated asymmetric **ES256** standby key; never export/import
private signing material. Do not touch the legacy JWT secret, API publishable key,
runtime database password, SMTP credentials, schema or Blueprint. No paid change,
new service, permanent key deletion or deployment is included.

Record approval for standby creation, activation, old-key revocation and the
specific reversible recovery actions before touching key controls. If verifier
process replacement is needed, its exact restart/deployment scope requires
separate explicit approval. This procedure does not grant that approval.

| Step | Required observation and stop condition |
| --- | --- |
| Baseline | Reconfirm target, live revision, healthy readiness, current public key metadata, current token expiry and the controlled owner. Keep a valid old-key session and refresh token solely in process memory. |
| Standby | Create one ES256 standby key. Read public JWKS until it contains both keys. Confirm every API verifier has discovered standby before activation; public discovery alone does not prove per-process discovery. |
| Activate | Rotate once. Refresh the controlled session once with the supported SDK; require a different public key ID, the same owner and successful `/v1/me`. Old-key `/v1/me` must still succeed while both keys are trusted and the old token remains unexpired. |
| Revoke | Revoke only the previously used key. Record the provider action time and public JWKS removal time independently. Never equate a click or key-state label with API rejection. |
| API trust | Before the old token's expiry, require old-key `/v1/me` to return **401 / invalid_credentials**, while the new-key token still succeeds for the same owner. A 5xx, ordinary expiry or account disable is not proof of key-revocation enforcement. |
| Recover | Require current-key SDK refresh and API use to remain functional. Confirm local owner/pending work survives cloud rejection. Record every cache/process action, result and limitation. |

The frozen PyJWT **2.15.1** verifier caches the key set for **300 seconds**, has a
**30-second** cooldown before an unknown-key refresh, and does not enable the
indefinite per-key cache. Unknown key IDs during cooldown fail closed. Local tests
exercise standby preload, discovery after cooldown, old/new overlap, stale cached
trust, explicit process-local invalidation, and discovery outage behavior with
ephemeral keys. They do not qualify Supabase/Render rotation.

`daily_motion.auth.key_client.cache_clear()` discards this application's cached
client **in the process where invoked**. Running it in an unrelated Python
process does not clear Uvicorn workers. There is no public cache-reset endpoint.
A separately approved replacement of all verifier processes clears their memory,
but cannot purge a stale upstream JWKS response. Verify each layer and actual
old-token rejection; never claim immediate revocation from a process restart.

Supabase documents a **10-minute edge JWKS cache** and throttled key-state changes.
The application adds its own cache; time the observed end-to-end result. Require
enough unexpired old-token lifetime to distinguish revocation from expiry. If a
bounded observation window expires, stop and record an incomplete rehearsal.
Do not continually retry, bypass the provider cooldown, or change token lifetime.

If activation fails before revocation, stop and request/execute only an already
approved return to the previous key. Re-enabling a revoked key expands trust and
requires explicit incident-owner approval; it is not an automatic fallback.
Never delete either key during the rehearsal.

Source: [Supabase signing keys](https://supabase.com/docs/guides/auth/signing-keys).
Session logout revokes refresh capability separately; a signed access token is
not automatically invalidated by logout. See
[Supabase sessions](https://supabase.com/docs/guides/auth/sessions).

## SMTP sender capacity — proposal only

The last saved evidence records consumer Gmail SMTP and **30 email messages per
hour**, a **60-second** resend interval and a **600-second** OTP lifetime. These
are historical readbacks, not newly observed settings. Nominal 30 × 24 permits
720 messages/day, above Google's published 500/day consumer allowance.

Propose **10 messages/hour**, retaining resend/verification limits and OTP
lifetime. Nominal capacity becomes 240/day. This is not a sender-wide daily cap:
provider bursts, other projects and other mailbox activity still matter. Assign
a named operator, use a dedicated staging sender, reserve capacity for a single
three-request run, and record sender-wide daily usage. If usage is unknown or
delivery fails, pause qualification; do not exhaust quotas to test them.

Changing the rate, moving to another SMTP provider, buying capacity and sending
test messages each need explicit approval. After rate-change approval, read back
only the persisted rate and unchanged resend/verification settings. Acceptance
also needs operator delivery monitoring and sender-wide capacity ownership.
Existing SPF/DKIM/DMARC proof remains limited to the message actually inspected.

Sources: [Gmail sending limits](https://support.google.com/mail/answer/22839?hl=en),
[Supabase Auth rate limits](https://supabase.com/docs/guides/auth/rate-limits).

## Render incident 215476446235862

Status remains **OPEN — revocation unconfirmed**. The
[preserved Support record](../../docs/evidence/phase0-render-support-submission-2026-10-18.json)
proves submission and automated acknowledgement of human escalation, not human
invalidation or old-hook rejection. Current inspection may be blocked by provider
sign-in; that adds no new Support result.

Read the existing private conversation when authenticated access is available.
Retain only the reply timestamp, human/automated classification, redacted outcome
and whether provider-side invalidation is explicitly confirmed. Do not copy hook
URLs, credentials or raw attachments. Never invoke the exposed hook to test it.
Do not disconnect, recreate, sync or deploy the Blueprint, or repair its branch,
without the required revocation evidence and explicit approval for changes.

Any new Support message or provider action requires its own authorization.
Escalation acknowledgement, Auto Sync Off and service deploy-hook guidance do
not close this Blueprint sync-hook incident.
