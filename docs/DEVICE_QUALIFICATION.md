# Phase 0 native and device qualification

This is an executable procedure and evidence boundary, not a passing hardware
report. See [IMPLEMENTATION.md](IMPLEMENTATION.md), [TESTING.md](TESTING.md) and
[SECURITY.md](SECURITY.md). Phase 1 remains unstarted.

## Available and blocked environments

The current workspace is Windows. The user confirmed no physical Android phone,
iPhone, Mac test host, hosted Supabase project or real test inbox is available.
Windows SQLite kills, controlled auth responses, static native checks and emulator
results cannot close those gates. Record each unavailable case as **blocked**,
not passed, skipped successfully or inferred from another platform.

GitHub access exists, but the remote contains the planning commit and no Actions
workflows. Running remote CI on that revision would not test this code;
publication and dispatch remain pending.
The local workflow now supports manual dispatch and native build checks when it
is published. No remote CI success is claimed.

## Build preparation

Use the pinned Flutter/Dart and Python versions in [README.md](../README.md).
Android requires JDK 21, SDK platform 36, build tools 36.0.0 and NDK
28.2.13676358. Windows task installations/caches live under ignored `.tools/`.
Set `JAVA_HOME`, `ANDROID_HOME`, `GRADLE_USER_HOME`, `PUB_CACHE`, `TEMP` and `TMP`
for the command process; do not change global settings or expose credentials.
Run Flutter/Dart commands and the connected API harness serially in each checkout:
dependency refresh changes native registrants even when a build is already running.

```sh
cd apps/mobile
flutter pub get --enforce-lockfile
flutter build apk --debug
flutter build apk --profile
flutter build apk --release
```

Release Android output is deliberately unsigned until operator-owned signing is
configured; it no longer silently uses the debug key. Profile/debug are internal
test builds. A successful build proves compilation, not installation, OTP delivery,
device persistence, accessibility, store readiness or latency. Real application
configuration contains only HTTPS URLs and a client publishable key. Release
fixture/token/development flags fail closed. No admin, signing or SMTP secret goes
into Dart defines.

iOS requires a Mac with supported Xcode and the appropriate signing team/device:

```sh
flutter build ios --debug --no-codesign
flutter build ios --release --no-codesign
```

Unsigned compilation is distinct from a signed install and actual iPhone testing.
Windows cannot establish either. The native Swift clock/backup bridge must be
compiled and exercised on that host before claiming iOS evidence.

## Native storage and external process death

The dedicated [native test entrypoint](../apps/mobile/integration_test/native_storage_test.dart)
uses synthetic training and a synthetic session through the actual protected
storage adapter. It is never the production `main.dart` and proves no hosted
authentication. Android qualification builds set `DM_QUALIFICATION_BUILD=1` in
the build environment for a separate `.qualification` application ID. On iOS use
a dedicated test install/team and preserve the same application ID/signature
through all stages. Run serially on a clean test device; never clear a personal
training installation.

Set `DM_EVIDENCE_DIRECTORY` to an ignored directory. Collect native output with:

```sh
flutter drive --driver=test_driver/qualification_driver.dart \
  --target=integration_test/native_storage_test.dart --debug -d DEVICE \
  --dart-define=DM_NATIVE_STAGE=seed
```

After the seed reports durable success, externally terminate the application.
Android may use `adb shell am force-stop PACKAGE`; also test system process loss
and reboot separately, because force-stop has different scheduling semantics.
On iPhone use the supported Xcode/device termination procedure. Record command,
time, OS/build, seed receipt and restart method. Launch the `recover` stage with
the same signing identity and retained application data. The test checks SQLite
integrity, saved observation, draft, pending count, frozen-body checksum via the
protected probe, session restoration and timer availability. `smoke` only performs
same-process reopen and cannot be labelled process-death evidence. `cleanup`
removes only the dedicated synthetic qualification files/keys.

Repeat kills before save, during the transaction, after local acknowledgement,
before upload, after server commit/lost response, during receipt/pull installation,
after OTP verification, and during token persistence/refresh. Check every durable
receipt after restart. The Windows child-process suite independently uses real
Drift/WAL `synchronous=FULL` and hard OS termination before/during/after commit;
its evidence is explicitly Windows-only.

## Backup, restoration and secure-storage loss

Android disables automatic backup and explicitly excludes root/files/databases/
preferences/external and device-protected domains for cloud backup and device
transfer. The timer installation nonce lives in Android's no-backup directory.
iOS marks the application-support directory excluded from backup before opening
training storage; paths outside that native directory are rejected. Tokens and
the verified owner grant request device-only, non-synchronizing Keychain storage.
These controls still require actual backup and migration verification.

On each platform seed synthetic workouts, queued commands and secure sessions,
then inspect an actual backup/restore/transfer on a spare device. Training/WAL/
outbox/session material must be absent from excluded backup artifacts. Inspect
Android encrypted preferences/Keystore and iOS Keychain behavior; an emulator or
mock method channel does not establish hardware protection. Test reinstall,
locked-device access, missing/corrupt secure state and restored stale SQLite with
missing protected grants. Never guess ownership from filenames or email. Existing
locked data requires verified authentication; ordinary credential loss cannot
erase it. Retired IDs/account state must prevent resurrection on resumed sync.

## Timer and workout matrix

| Scenario | Expected evidence |
| --- | --- |
| Offline, expired token, failed refresh | Local sets/corrections/finish/history work; frozen outbox retained; cloud paused |
| A → B → A | Separate owner files/scopes; no A draft/cursor/conflict/outbox in B; A recovers |
| Network loss/restoration | Durable acknowledgement independent of requests; exact retry/own echo recover |
| Suspension and process loss | Native elapsed time advances without ticks/notifications; same-boot Android continuity survives process loss |
| Wall clock ±1 hour, timezone change | Same continuity uses elapsed time; clock divergence marks approximate; UTC timezone changes do not alter remaining time |
| Reboot/unknown continuity | Wall-anchor estimate clamped to configured duration and explicitly approximate; no measured-rest claim |
| iOS process loss | Conservative wall estimate marked approximate; process-scoped continuous clock is not reused across launches |
| Disk full/write failure | No saved acknowledgement or partial outbox/projection; prior work and recoverable draft survive |

The Windows capacity test forces real `SQLITE_FULL` using a pager quota and an
allocation in the save transaction. It does not qualify a full physical volume,
flash failure or power loss. On spare devices use supported quota/fault tools or
bounded temporary files, leave recovery space and remove only those files. Never
fill a personal device blindly or delete existing data to make room.

## Navigation and accessibility

Verify Android button/gesture/predictive back and iOS back gesture/sheets: leaving
the editor neither finishes nor discards the workout; durable drafts restore.
Exercise correction sheets with the keyboard visible, decimal/reps next/done,
invalid entry and interrupted saves. At large text, verify scrolling, no clipping,
48-pixel targets and actual units/outcome announcements. Use VoiceOver/TalkBack
on hardware, reduced motion, increased contrast and denied notifications/haptics.
Desktop semantics/tap-target checks complement these tests but do not replace
native screen readers or OEM navigation.

## Durable-save benchmark

Use [the benchmark entrypoint](../apps/mobile/integration_test/durable_save_benchmark_test.dart)
on declared **physical** Android/iPhone hardware in **profile/release**, with the
driver above in **profile** mode and an exact build/source-content identifier in
`DM_BUILD_REVISION`. Release-mode instrumentation/collection must be qualified
separately: an unsigned APK is not installable and the release VM service is
unavailable to the usual Flutter drive path. Do not claim a release run from
profile output.
Its primary stopwatch starts immediately before `WorkoutController.record` and
ends only after its successful Future: validation/read, native clock, SQLite
durable commit and projection refresh are included. The inner repository timing
hook alone is not the target measurement.

The workload declares 100 synthetic completed history roots, 32 fixed warmups and
200 measured saves. Warmup/raw measured microseconds are retained. Percentiles use
nearest rank `ceil(p*n)` on sorted samples; do not trim outliers, retry failures
into successes or mix debug/emulator data with phone samples. Any failed write,
fewer than 200 measured saves, unsupported metadata source, debug build or emulator
prevents a passing physical-performance claim. The target is **p95 ≤100,000 µs**.
Record device model/hardware identifier, OS/API, build mode/content hash, sample
count/method, history, warmups, battery/thermal state and connectivity/sync workload.

The prepared automated benchmark is labelled `offline_repository_no_provider`.
It does not qualify hosted auth or actual HTTP sync load. Also measure normal
authenticated training with active network sync, airplane mode, held requests and
long history; record those workloads separately. Current physical sample count is
**zero**. No phone p95 result is available.

## Hosted provider qualification

Blocked until an operator supplies a development/staging project, HTTPS API,
publishable configuration and controlled inbox. Configure six-digit OTP templates,
custom SMTP/domain authentication and provider limits outside the app. Verify real
request/delivery/resend/expiry/incorrect code/refresh/revocation/account guards and
restart/A → B → A with pending work. Record delivery timing and safe statuses,
never OTP values, tokens, headers, SMTP passwords or provider/admin secrets.
Controlled SDK/provider tests remain separate and are not delivery evidence.
