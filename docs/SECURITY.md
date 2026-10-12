# Security and privacy

Planning baseline: 2026-10-12. This document is the retention and security-policy authority for the documentation package. Controls describe requirements for future implementation, not certifications or completed audits. See [ARCHITECTURE.md](ARCHITECTURE.md), [DATA_MODEL.md](DATA_MODEL.md), and [TESTING.md](TESTING.md).

## Trust boundaries and primary threats

Daily Motion contains private training history, notes, body measurements, and eventually sensitive recovery/health observations. Treat all user-provided IDs, timestamps, catalog names, notes, imports, and assistant messages as untrusted input. An authenticated mobile client is not a trusted database administrator.

```mermaid
flowchart LR
  Device[User device and app-private data] -->|TLS and user token| API[FastAPI authorization boundary]
  API -->|Restricted role and transaction-local owner| DB[(Private PostgreSQL schema)]
  Device --> Auth[Supabase Auth]
  Admin[Restricted administrator or migration job] --> DB
  API --> Tools[Future authorized domain tools]
  Tools --> Provider[Future LLM provider with minimized context]
```

| Threat | Required defense |
| --- | --- |
| Nested-ID manipulation or tenant crossover | Verified owner, composite owner-aware foreign keys, RLS, runtime-role tests |
| Replay, stale mutation, or deletion resurrection | Frozen idempotency envelopes, aggregate CAS, retired IDs, transactional receipts |
| Lost/borrowed phone | OS-protected storage, secure tokens, locked account state after explicit sign-out |
| Token/secret disclosure | Secret manager, redacted telemetry, least privilege, rotation procedures |
| Malicious notes/imports or LLM tool arguments | Data/instruction separation, typed tools, authorization and confirmation outside the LLM |
| Abuse of OTP/export/AI endpoints | Provider limits, server budgets, bounded payloads/jobs, monitoring |
| Deletion race or backup restoration | Immediate account disable, purge workflow, deletion ledger before restored access |

A compromised/rooted device can expose data the app legitimately needs while unlocked. The MVP does not claim resistance to that adversary. Update the threat model before health reads, wearable transfer, or high-value billing launch.

## Authentication and local access

Use Supabase email OTP for the account-required MVP; initial verification requires network access. Configure OTP emails explicitly, custom production SMTP, sender-domain authentication, resend throttling, verification attempt limits, and generic responses that avoid account enumeration. Never log email codes or place them in analytics. OTP-only sign-in avoids unnecessary social-provider linking and password-management scope. [Supabase passwordless email](https://supabase.com/docs/guides/auth/auth-email-passwordless), [Production SMTP](https://supabase.com/docs/guides/auth/auth-smtp)

Persist sessions through the Flutter SDK's supported secure-storage adapter, backed by iOS Keychain/Android protected key storage. Its default SharedPreferences persistence is not the intended token store. Keep project publishable identifiers distinct from privileged keys; no service/admin/database credential enters the app bundle. [Supabase Flutter session storage](https://github.com/supabase/supabase-flutter/blob/main/packages/supabase_flutter/README.md)

Local account ownership and cloud authorization are separate states. After first verified signup, access-token expiry or refresh failure pauses sync without blocking local routine creation, workout start/log/finish, or history. Explicit sign-out removes the cloud session and locks the account database; preserve unsynced work under that owner for authenticated recovery. Account switching never retags or uploads another owner's outbox. An authentication event handler must not erase history on transient failure.

FastAPI verifies allowed signature algorithms, issuer, audience, expiry, and subject with a maintained JWT library and trusted JWKS. Bound/cache keys responsibly and provide a cache-invalidation path for urgent rotation. A valid JWT is not sufficient when the application account is disabled. Sensitive account operations require recent authentication; session revocation checks are separate from signature validation. [Supabase signing keys](https://supabase.com/docs/guides/auth/signing-keys), [Session behavior](https://supabase.com/docs/guides/auth/sessions)

Remote sign-out, permission revocation, or account deletion cannot instantly wipe an offline phone. Enforce server denial immediately; apply local lock/erasure when the device receives the authoritative state. State this limitation plainly in product policy. Account deletion acquires the same owner guard as domain writes; mutations, ordinary job-effect publication and bootstrap publication recheck active state/generation under that guard to prevent previously authorized work committing after disable. Erasure workers are narrowly authorized to operate in `deleting` state for cleanup only, without recreating data. Never hold the guard across external network work.

## Authorization and database isolation

All training access goes through the domain API. Application training tables occupy a private schema that is not exposed through Supabase Data API access. Disable that API when unused, or deny all training-table grants/exposure. Do not maintain a parallel direct-write path that bypasses command validation.

The normal API role is non-owner with `NOBYPASSRLS`. Set tenant context using `SET LOCAL` inside each explicit transaction, derived solely from verified identity. Missing context fails closed. Repository queries filter owner explicitly; composite owner-aware foreign keys prevent a child from referencing another user's parent. RLS and grants are defense in depth, not a substitute for API authorization. Views/functions receive the same scrutiny as tables; privileged security-definer functions require review. [Supabase RLS guidance](https://supabase.com/docs/guides/database/postgres/row-level-security)

Migration/admin roles are separate, audited, and unavailable to request handlers. Background workers use narrow roles appropriate to their job; cross-owner deletion/export administration is explicit, not an excuse for unrestricted API credentials. Pooling tests verify transaction-local context is reset and cannot bleed between owners. Keep production dashboards and database consoles behind MFA and limited membership.

Authorization applies to nested session/set IDs, routine versions, snapshots, exports, predictions, conversation IDs, tool proposals, and job polling. Return sanitized errors; possession of an opaque identifier or signed artifact token alone never proves ownership.

## Encryption, mobile controls, and API hardening

Require HTTPS for every external call and encrypted database connections with verified transport configuration. Managed PostgreSQL/storage encryption at rest must be confirmed in provider settings. Keep secrets in environment-specific secret managers, inject them at runtime, rotate SMTP/database/provider credentials, and scan commits/CI artifacts for leaks. Separate development, synthetic staging, and production projects and credentials.

MVP training data resides in OS-protected app-private SQLite; exclude the database, outbox, temporary exports, and auth state from automatic platform backups as appropriate. Verify exclusion on both platforms. This is not SQLCipher application-layer encryption. Do not mandate an extra native database stack without evidence; reconsider stronger local encryption and key lifecycle before storing imported native health data. Retain local access to pending work across process restarts without exposing it across accounts.

Hide private content from app-switcher previews where practical. Avoid sensitive notification text and clipboard persistence. Validate deep links strictly if future features introduce them. Certificate pinning is not required in MVP; ordinary platform trust plus a reliable rotation path is preferable to brittle pinning. Device attestation/root checks may inform abuse decisions later but cannot prove a trustworthy client.

Validate typed request bodies, sizes, enum values, owner references, and command schema versions. Bound sync batches, bootstrap snapshots, export size, conversation context, and job execution. Never concatenate user SQL. Apply per-user and per-IP budgets, stricter budgets for costly export/AI routes, and authentication-provider throttling. A per-process limiter alone is insufficient across autoscaled instances; use shared persisted budgets where needed. Limits must accommodate legitimate queued offline workouts and cannot block local logging.

Restrict storage objects by owner and use short-lived authenticated download paths. Do not log signed URLs. Audit dependencies and release signing; keep mobile signing keys and production deployment authority separate from untrusted PR jobs.

## AI and health data boundaries

No AI or health integration ships in MVP. Future LLM context is minimized to authorized training facts required for the request; provider retention/training settings and subprocessors require documented review. Imported HealthKit/Health Connect data remains local by default and is excluded from cloud sync, global model datasets, and LLM context. Permission to read a device store does not authorize onward sharing. See [HEALTH_INTEGRATIONS.md](HEALTH_INTEGRATIONS.md).

The assistant never receives database credentials or executes arbitrary SQL. Typed tool handlers enforce ownership, quotas, current revisions, and allowed operations independently of the prompt. Future-plan changes require an explicit user confirmation bound to a proposal; active/historical workout commits are outside assistant authority. Untrusted retrieved text cannot change tool permissions or approval requirements. Numerical predictions originate from versioned prediction tools, with unavailable results handled explicitly. See [CHATBOT_ARCHITECTURE.md](CHATBOT_ARCHITECTURE.md).

Store only necessary tool audit metadata: action, proposal/confirmation identifiers, affected IDs/revisions, outcome, model/tool version, and timestamps. Do not retain duplicate full prompts or tool payloads in observability. Personal/global model eligibility requires its own purpose and consent policy; account deletion removes future training eligibility, without promising instantaneous model unlearning.

## Retention, deletion, and portability

| Data | Default policy |
| --- | --- |
| User-visible training projections | Retained for account use; correction preserves historical truth; deletion hides/excludes immediately |
| Personal payload in live stores and derived artifacts after permanent deletion | Purge target within 7 days; failures are tracked and retried |
| Redacted operational application logs | 30 days |
| Legally required security logs | Separate stream/retention after applicability review; never include workout payloads |
| Future conversation transcripts | Rolling 90 days; user may delete earlier |
| User-confirmed training preferences | Until user removes them or account erasure |
| Future device-local imported health cache | Bounded 30-day window by default; no ordinary cloud upload |
| Transient bootstrap snapshots | 15-minute token expiry; expired artifacts cleaned promptly |
| Minimal mutation receipts/retired UUIDs | Owner lifetime, without training/notes/health payloads |
| Backups | Expire within 35 days, subject to verified provider configuration before release |

Permanent deletion is an explicit product action; correction retention does not justify retaining deleted personal payload. Disable account access before enqueuing erasure. Remove current data, historical values, personal predictions/recommendations, conversations, confirmed memory, exports/snapshots, and derived/model-dataset eligibility. Redact deleted-root values from retained sync-feed bodies immediately while preserving cursor metadata, and invalidate existing bootstrap tokens before asynchronous page cleanup. Older cursors/tokens must not return erased values; transport copies are included in the seven-day live-store purge target. Keep only narrowly necessary deletion/receipt metadata, with separate legal-retention justification where applicable.

Permanent data deletion advances an owner `erasure_epoch` under the guard. Snapshot preparation, export/model jobs and assistant evidence capture it with their input snapshot and recheck before personal payload is stored/published. Reject/discard stale materialization even when the account remains active, preventing cleanup from being followed by a late reconstructed copy. Do not hold a DB lock through inference, OS calls or external storage; stage work privately and reconcile at publication. Already issued responses and offline copies cannot be recalled instantly.

Backups cannot be represented as instantly rewritten. Maintain a deletion ledger outside restored application snapshots; reapply it **before** users or jobs can access a restored environment. Verify actual backup expiry/restore controls against the stated 35-day ceiling. Existing trained global artifacts need an explicit retraining/removal policy before Phase 5; do not promise instantaneous unlearning.

Provide in-app account deletion and a machine-readable account export covering training history, routines/programs, units/provenance, and relevant corrections. Export authentication/authorization is enforced, files expire, and one owner's export never contains another's data. Device-local imported health observations are separately identified and included only through an explicit local export purpose. [Apple in-app account deletion](https://developer.apple.com/support/offering-account-deletion-in-your-app/)

## Governance and incident response

Before the India-first adult public release, review current applicable DPDP provisions and staged commencement, notices/consent, grievance/contact arrangements, deletion/export rights, subprocessors, and cross-border handling. Review CERT-In directions for actual entity/service applicability, incident reporting, and security-log obligations. Hosting in Mumbai is an operating default; it does not establish blanket residency compliance or replace this review. [MeitY rules and enforcement timeline](https://www.meity.gov.in/documents/act-and-policies/digital-personal-data-protection-rules-2025-gDOxUjMtQWa), [CERT-In directions and FAQs](https://www.cert-in.org.in/Directions70B.jsp)

Assign an incident owner and contact before launch. Maintain procedures for credential rotation, account disable, optional-service shutdown, evidence-preserving redacted security logs, provider escalation, required notification/reporting, and safe restoration. Run a tabletop and restore drill. Public release is blocked by unresolved tenant isolation, workout loss, secret exposure, or deletion defects; record security exceptions and review conditions in [DECISIONS.md](DECISIONS.md).
