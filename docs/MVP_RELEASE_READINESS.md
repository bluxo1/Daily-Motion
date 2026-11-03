# MVP release readiness

Status: **not feature complete, not a qualified release candidate, launch not
authorized**. Baseline: [post-PR21 audit](PROJECT_STATE_AFTER_PR21.md).

## Four separate decisions

1. **Core code implemented:** a particular scoped path exists with source/tests.
2. **MVP feature complete:** every PRD01-18 acceptance path works in intended
   production configuration, including profile, authoring, privacy and resolution.
3. **Release candidate qualified:** exact signed builds pass actual infrastructure,
   phone, migration, accessibility, performance and operational gates.
4. **Public launch authorized:** accountable product/security/operator owners
   accept the candidate, store/privacy/support readiness and rollout policy.

Merged code and checked boxes prove neither the next state nor permission to
enable a feature. Phase 0 stays open, and public Phase 1 rollout is unauthorized.

## Controlled routine admission design (proposed)

This is a bounded proposed design for a later PR, not an accepted ADR, implemented
admission service or public feature activation. The current tested compatibility
policy remains fail-closed contract3; [routine sync](ROUTINE_CLOUD_SYNC.md) and
[current tests](../services/api/tests/test_routine_hardening.py) establish it.

The present single flag couples management UI and transport. Simply removing
`!kReleaseMode` would upload existing offline journal entries and enroll owners
without a controlled all-device upgrade boundary. Opening schema7 also happens
independently of the flag; disabling the flag cannot downgrade a file or owner.

Proposed admission **policy version1** is separate from transport contract3 and
SQLite reader7. A server-owned, owner-bound capability/admission record binds the
policy version/epoch, cohort and compatible minimum client contract/reader to
the active owner/generation/erasure epoch. Bearer authorization alone must not
allow an unsupported client header to claim admission. Enrollment checks and
first routine acceptance share the existing owner transaction/lock. The server
must gate every route that can enroll, not only a discovery/UI endpoint.

Separate client controls for displaying authoring, publishing new routine work,
and maintaining required contract3 transport for enrolled accounts. Rollback can
halt new enrollment/distribution/publication while preserving compatible workout
delivery, routine reads, bootstrap and established receipt replay. It cannot reset
the minimum contract, rewrite a frozen body or restore a schema6 file over pending
work. Keep a qualified schema0005/contract3 API and schema7 reader or forward-fix.

Already enrolled floor3 owners must be grandfathered safely. Distinguish a new
unaccepted mutation from a successful historical receipt: closing admission must
not turn lost-response replay into a different result or falsely declare current
state. Owner retirement remains authoritative before either operation. Carry
admission context outside frozen operation bodies, or explicitly version any new
envelope; do not add fields rejected by old closed DTOs or mutate old hashes.

| Owner/client/server situation | Current tested result | Required admission-v1 behavior / test |
| --- | --- | --- |
| Floor1, old client/current API | Workout sync supported | Remains supported; no accidental enrollment |
| Floor1, v3 discovery/workout-only/rejected routine | No floor upgrade | Discovery cannot admit; unsupported/missing/forged admission refuses first routine without changing data/floor/cursor |
| First accepted authorized routine | Atomic floor3 + root/template/receipt/feed | Explicit cohort/admission and all-device notice before acceptance; race gate closure under owner lock |
| Floor3, old client |426 upgrade_required; pending local data retained | Never return filtered success or reset floor; communicate compatible upgrade |
| New client/old API | Capability refusal, preserved local work | No v1 fallback that silently drops planning; local training continues |
| Previously accepted frozen mutation, gate closed | Historical receipt replay | Same acknowledgement, no duplicate; active owner/erasure barriers still enforced |
| Existing floor3 owner, rollback | Old API fails closed; schema6 reader refuses7 | Keep compatible serving/readers and data; grandfather pending original requests; no destructive downgrade |
| Stale generation/erasure epoch or owner replacement | Strict context refusal | Admission cannot authorize resurrection or install another owner's response |

Current compatibility has executable local/connected controls. The proposed
admission-v1 negative/race tests above are **not executed**, because that service
does not exist. They are mandatory before activation. Operator/product decisions
must choose cohort ownership, upgrade communication, enrollment consent and
grandfathering; a client flag is not that authorization boundary.

Catalog acceptance must preserve unavailable private definitions as snapshot-only
without name-based substitutes. A public conflict UI must support explicit safe
resolution, not just retained-plan inspection. Navigation must give a newly
verified user a usable first-start path. Keep future notes/substitutions/time
measurements behind their own compatible contracts until qualified.

## Infrastructure and hardware qualification queue

| Gate / accountable role | Existing automated evidence | Required actual acceptance before launch |
| --- | --- | --- |
| Android/iPhone installs; release engineer | Linux Android and unsigned macOS iOS CI compilation | Signed install/update on supported physical iOS16+/Android10+ cohort; record exact OS/build/signing identity, previous data and rollback-compatible reader |
| Secure storage; security/mobile engineer | Secure-channel routing/options, owner/file guards, static backup exclusions | Keychain/Keystore lock/reinstall/missing-key behavior, account A-B-A, backups/device transfer and protected-grant loss on hardware |
| Durability/drafts; mobile QA | Real desktop SQLite/WAL kills, capacity faults and migration controls | Actual phone termination before/during/after save and ack; suspension, reboot, disk-write failure, restored drafts/timers and original pending bytes |
| Performance; mobile engineer | Desktop worker/large history and bounded transport observations | Real caller p95 durable set write<=100ms with device/build/thermal/dataset/method/sample context; desktop charts are not phone latency evidence |
| Accessibility; accessibility reviewer | Widget semantics,320px/200%, keyboard/contrast checks | TalkBack/VoiceOver entire first/repeated workout, large text,48px targets, reduced motion, Android predictive/button back and iOS gestures/sheets; record assistive-tech configuration |
| Hosted identity/API; operator/security | Dated staging SMTP/OTP/JWT/refresh desktop evidence and local RLS tests | Fresh candidate against accepted provider settings; inbox, expiry/revocation/throttles, current JWKS/rotation/operator capacity; close or disposition historical hook incident without exposing secrets |
| Managed recovery/erasure; DB/operator/privacy owners | Local PostgreSQL dump/restore/fences and retirement tests | Approved managed backup route, restore exercise and erasure-ledger suppression preventing old training/accounts from resurrection. No O3 design is approved by this checklist |
| Store/privacy/support; product/legal/operator | Accepted planning boundaries and synthetic data logging guards | Named India reviewer, processor/retention/notices/export/delete/support policy, store disclosures, developer accounts, release signing and incident/recovery ownership |
| Controlled beta; product/reliability owners | Test counters and harnesses, not population outcomes | Approved admitted cohort; first-workout usability, repeated training, support/rollback procedure and sanitized crash/session denominator with build/sample context |
| Crash-free sessions; reliability owner | Local exceptions/fault cases | Measured proposed99.9% target with meaningful workout-session sample and confidence/limitations; do not infer from zero unit-test failures |

No device, provider, key, signing, hosted deployment, recovery-policy or public
enrollment operation is authorized in this local mission. Unknown gate status
remains unknown/blocked on its actual dependency; it is never a passing skip.
