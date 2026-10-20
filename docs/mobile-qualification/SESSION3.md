# Session 3: Phase 0 mobile qualification

This track owns mobile changes and mobile evidence. Session 4 owns reconciliation
of the shared roadmap and status documents. The baseline is `57a4494`; the branch
is `phase0/mobile-qualification` in its own Git worktree. Phase 1 remains unstarted.

The acceptance authority is [the device procedure](../DEVICE_QUALIFICATION.md)
and [the test matrix](../TESTING.md). Earlier Windows/emulator results remain
dated evidence in [the native report](../evidence/phase0-windows-native-2026-10-13.json).
They are not reruns of this revision and do not qualify physical hardware.

## Isolation and execution

Use a separate Pub cache, temporary directory, Gradle user home, Android user
directory and AVD directory for this worktree. This run used a task-local Flutter
SDK/cache and a task-local copy of the writable Flutter Gradle plugin; shared
framework sources were read through links. The ordinary desktop suite also used
the installed pinned SDK with task-local Pub and temporary files. Respect any SDK
startup lock without stopping other sessions. Project build, generated assets and
test outputs stay in this worktree.
Shared SDK/platform binaries and read-only dependency artifacts can be read. Do not
refresh dependencies, generate sources, test or build concurrently within the
checkout. Never use an existing personal installation or another session's AVD,
database, Gradle daemon or provider accounts.

The verified source commit for this run is `e5ece1e61993156d2409b6c9f7be1e68ca05d942`.
Seed/recover binaries declared the working-source SHA-256 before that commit;
the archived digest remained unchanged after the commit. Profile collection
declares the source commit directly. See the reviewed
[evidence index](evidence-2026-10-20.json) and original
[seed](android-emulator-seed-2026-10-20.json) and
[recovery](android-emulator-recover-2026-10-20.json) reports.

For a reproducible candidate, commit the mobile source and verify that
`git status --porcelain -- apps/mobile` is empty. Record `git rev-parse HEAD` and
retain the APK/IPA SHA-256, Flutter/Dart versions, OS and test command. A branch
name alone does not identify the source content. Keep logs and raw native reports
under ignored `.tools/evidence/`; publish only reviewed synthetic evidence.

## Native persistence and backup review

- Android secure storage now explicitly disables automatic reset on error.
  The pinned plugin otherwise allows deletion of protected ciphertext/grants
  after some decryption or migration faults. Errors surface as unavailable
  storage, preserving recovery material. An irrecoverable Keystore failure can
  still require an explicit operator/user recovery path; this change does not
  prove hardware key protection or silently delete data to make sign-in work.
- SQLite uses file-backed Drift, WAL, `synchronous=FULL` and foreign keys. A
  durable set acknowledgement follows the transaction containing projection,
  observation, outbox and draft removal. HTTP is outside that transaction.
- Owner UUID files and protected grants are separate from expiring cloud
  credentials. Local sign-out locks both stores; switching accounts never
  retags the original outbox. Existing Windows tests cover real file reopening,
  migrations, interrupted commits, pager-full failure, bootstrap and conflicts.
- The Windows hard-kill harness now records the worker's actual PID. The pinned
  `dart run` launcher and SQLite-owning VM have different PIDs; one run hit
  `SQLITE_BUSY` while reopening after launcher-only termination. The precise
  Windows lock-release timing is not established.
  The harness kills the worker and waits for inherited output pipes to close
  before reopening. It adds no application retry, sleep or weaker assertion.
- Android disables automatic backup and explicitly excludes all nine supported
  credential/device-protected domains for cloud and Android device transfer.
  `allowBackup=false` alone does not establish OEM transfer exclusion; Android
  documents that OEM behavior varies. Verify the installed merged manifest,
  actual artifacts and spare-device transfer. See
  [Android backup controls](https://developer.android.com/identity/data/autobackup).
- Android 16 QPR2 adds cross-platform transfers with separate configuration.
  This checkout has no configured iOS matching bundle/team for that channel.
  Treat its absence as an unqualified platform boundary; do not invent team IDs
  or infer transfer protection from the Android-to-Android rules.
- iOS canonicalizes the application-support path and checks backup exclusion
  before opening storage. The directory requests
  `completeUntilFirstUserAuthentication`; this is not a promise that SQLite
  becomes unreadable on every subsequent device lock. Tokens/grants request
  non-synchronizing, device-only Keychain access while unlocked. Verify
  directory/file/WAL/SHM protection, locked access and actual backup/restore on
  signed hardware. Apple notes that operations may reset the backup property:
  [backup property documentation](https://developer.apple.com/documentation/foundation/urlresourcevalues/isexcludedfrombackup).
- Android Keystore use is not proof of a hardware-backed key. Inspect the actual
  key security level on the declared devices. Test missing/corrupt keys without
  clearing training data. Reinstallation and stale restored SQLite must require
  verified ownership rather than guessing from a file or email.

## Reproducible native recovery

Both harnesses verify the native application ID ends in `.qualification` before
opening test storage. Use only a dedicated synthetic `.qualification` installation. Set
`DM_QUALIFICATION_BUILD=1` for Android. Retain the same application ID and signing
certificate for all stages. Set `DM_EVIDENCE_DIRECTORY` to an ignored directory.
On iOS the operator must configure a dedicated bundle ID with that suffix and
matching provisioning on the Mac; the ordinary application identity is rejected.
Run these from `apps/mobile` with the pinned SDK and task-local environment:

```powershell
flutter drive --driver=test_driver/qualification_driver.dart --target=integration_test/native_storage_test.dart --debug --keep-app-running -d DEVICE --dart-define=DM_NATIVE_STAGE=seed
adb -s DEVICE shell pidof com.dailymotion.training.daily_motion.qualification
adb -s DEVICE shell am force-stop com.dailymotion.training.daily_motion.qualification
adb -s DEVICE shell pidof com.dailymotion.training.daily_motion.qualification
flutter drive --driver=test_driver/qualification_driver.dart --target=integration_test/native_storage_test.dart --debug --keep-app-running -d DEVICE --dart-define=DM_NATIVE_STAGE=recover
```

Record seed receipt, external termination time/method, absence of the old process,
OS/API, source and binary hashes, signing-certificate digest, restart method and
recovery report. Require a live PID immediately before the external kill and no
PID afterward. The pinned Flutter driver stops **and uninstalls** its packaged
app by default. Use `--keep-app-running` on every intermediate stage, including
recovery when a reboot or another recovery follows. A missing installation after
default driver cleanup is not reboot data loss. A successful `smoke` or
same-process reopen is not external-kill evidence. Force-stop does not establish system eviction, suspension or reboot.
Recovery checks the synthetic protected owner grant and cloud session separately,
as well as frozen outbox checksum, pending count, draft, SQLite integrity/foreign
keys and bounded timer state. Timer approximation is included in the report.
For an Android reboot check, record a live PID, `settings get global boot_count`
and `run-as APPLICATION_ID test -f files/native-qualification/training.sqlite`
before targeted `adb -s DEVICE reboot`. Wait for `sys.boot_completed=1`, verify
the boot count changed, verify no app PID exists and check the database **before**
launching another driver. Retain both receipts and the command record. Do not
substitute a new seed for recovery.

Repeat those separately on hardware. Only the dedicated synthetic harness may
be cleaned with `DM_NATIVE_STAGE=cleanup`; never clear a personal app.

Use controlled clocks and real local files for timer uncertainty, disk quota,
offline recovery and owner-isolation regressions. No shared PostgreSQL database
or OTP request is needed for those cases. Hosted account qualification belongs
to the provider track and does not establish native protected storage.

## Profile and release performance

The prepared benchmark's scope is `offline_repository_no_provider`. It includes
the complete `WorkoutController.record` Future, not just SQL timing. Declare
100 completed history roots, 32 fixed warmups and 200 measured saves. Retain
every raw microsecond sample. Compute nearest-rank `ceil(p*n)` without trimming.
Record battery/thermal state, power mode, connectivity, storage state and whether
tracing is active. Independently confirm physical hardware; the Android heuristic
and native `physical` flag are not sufficient operator evidence.

For a committed clean candidate:

```powershell
$revision = git rev-parse HEAD
$env:DM_QUALIFICATION_BUILD = '1'
$env:DM_EVIDENCE_DIRECTORY = 'ABSOLUTE_IGNORED_EVIDENCE_DIRECTORY'
flutter drive --driver=test_driver/qualification_driver.dart --target=integration_test/durable_save_benchmark_test.dart --profile -d DEVICE --dart-define=DM_BUILD_REVISION=$revision
```

Use normal dependency preparation when switching build modes; stale generated
plugin registrants caused an earlier build failure. Archive the exact profile
APK and hash before another build overwrites the output. Any failed write,
incomplete workload, missing metadata or debug/emulator run prevents a passing
physical-performance claim. A complete physical report must have p95 at most
100,000 microseconds. A slower completed run is a failed target, not a reason to
discard its report.

Completion is explicit and defaults to false. Missing workload declarations,
incomplete history/warmups and failed attempts cannot produce a passing report.
Failed measured durations and partial successful samples remain available; the
driver writes report data even when the integration test fails. An early failure
without report data produces an explicit unavailable-report marker. Process
termination before driver communication still requires external evidence.

Release compilation uses `flutter build apk --release` and
`flutter build ios --release --no-codesign` on their supported hosts. Android
release output is deliberately unsigned. The profile driver cannot collect from
a release build because the usual Dart VM service is absent. Release execution
therefore remains blocked until operator signing and a separately verified
release instrumentation/collection path are available; do not label profile
results as release evidence. The profile path above is executable independently
of production release signing on Android. See
[Flutter performance integration testing](https://docs.flutter.dev/cookbook/testing/integration/profiling).

The offline workload does not qualify authenticated active sync, held HTTP
requests, airplane mode with expired cloud credentials, or long-history
performance. Record each separately on physical devices, preserving its source,
workload and full caller timing. CPU/thermal throttling and host build duration
are not set-save measurements.

## Operator signing and hardware acceptance

1. Supply a representative constrained Android phone and physical iPhone,
   including oldest supported and current OS coverage. Supply a supported Mac
   and Xcode for signed iOS installation. Maintain separate synthetic installs.
2. The operator chooses Android release key custody and iOS team, bundle ID,
   provisioning and registered devices. Enter secrets through protected local/CI
   controls. No key, certificate private material or password belongs in Git or
   Dart defines. Keep CI PR jobs separate from signing authority.
3. Verify a signed install, app ID/certificate continuity on upgrade, and retained
   synthetic data. An unsigned build or hosted macOS compilation is not an
   install pass. Retain certificate fingerprints, never private keys.
4. Execute process loss before/during/after acknowledgement, reboot, suspension,
   clock/timezone changes, expired/failed refresh, pending sign-out and A/B/A.
   Check drafts, exact frozen bodies, outbox counts, isolation, timer uncertainty,
   SQLite integrity and absence of phantom acknowledgements.
5. On spare devices, verify backup/restore, Android transfer and iOS Keychain,
   lock/reinstall/key-loss behavior. Use supported bounded disk-fault tools with
   recovery space. Do not fill or reset a personal device.
6. Use TalkBack and VoiceOver with large text, increased contrast and reduced
   motion. Verify exercise/set/class/outcome/load/reps/effort announcements,
   focus order, 48-pixel targets, numeric next/done, correction reason, modal
   dismissal and gesture/button/predictive back. Back must retain the active
   session and durable draft. Desktop semantics remain complementary evidence.
7. Collect the profile benchmark and separate realistic sync workloads. Keep
   hardware, signing, screen-reader, backup/transfer and latency rows open until
   each has actual evidence. No public release claim follows from this track.

## Handoff to Session 4

The available Windows/emulator qualification is complete for source commit
`e5ece1e61993156d2409b6c9f7be1e68ca05d942`. The evidence commit follows it on
`phase0/mobile-qualification`; use both commits when integrating this track.
Shared status and roadmap reconciliation remain with Session 4. No merge, push,
provider change, signing-identity change or Phase 1 work was performed.

- The complete ordinary Flutter run passed **161 tests**, with **12 explicit
  skips**: nine connected HTTP cases and three hosted/provider cases. Analysis
  passed, and all 61 Dart files passed formatting with zero changes. The evidence
  index retains per-suite counts, duration and the raw-log hash.
- Android API 36 native seed and external force-stop recovery passed. PID 5570
  was live before force-stop and absent afterward. Recovery restored the
  synthetic session and owner grant, exact frozen request checksum, draft and
  two pending outbox entries. SQLite integrity and foreign keys passed; the
  same-boot timer reported 36 seconds remaining, without approximation.
- Offline reboot recovery passed with a preserved installation. PID 5921 and
  the database were verified before reboot; boot count changed from 5 to 6.
  The database existed before the recovery driver, and no app PID was running.
  Protected records, draft, frozen outbox and SQLite checks passed again. The
  timer reported zero remaining and approximate state. See the original
  [reboot seed](android-emulator-reboot-seed-2026-10-20.json) and
  [reboot recovery](android-emulator-reboot-recover-2026-10-20.json) reports.
- The [profile collector](android-emulator-profile-benchmark-2026-10-20.json)
  completed 100 seeded history roots, 32 warmups and 200 measured saves with no
  failures. Its emulator p95 was **43,171 microseconds**. All raw samples remain;
  nearest-rank p95 was independently recomputed. Both physical-evidence and
  target-met flags are **false**. Android reported airplane mode enabled,
  Wi-Fi disabled and no default network. This is no-provider emulator evidence.
- The ARM64 release compile passed with exit 0 in 223.3 seconds. Its 22,043,765
  byte APK is unsigned; the expected signature-verification failure confirms
  the absent certificate. It has no debuggable or cleartext override and retains
  backup exclusions/back callback configuration. It was not installed or run.
  An earlier daemon-stop interruption is retained as a failed attempt, not a
  successful build. Native APK/report hashes are in the evidence index.
- An additional recovery attempt after default driver teardown correctly
  rejected an absent database. Inspection of the pinned driver confirmed its
  uninstall behavior. The corrected preserved-installation reboot procedure
  passed; the [failed-attempt marker](android-emulator-invalid-reboot-attempt-2026-10-20.json)
  remains available. Task-owned emulator, ADB server 5038 and Gradle daemon were
  stopped; shared server 5037 and other sessions' processes were left alone.

**Physical sample count remains zero.** Session 4 must keep Android/iPhone
hardware, current iOS compilation/execution, operator signing and signed upgrade,
real Keychain/Keystore and backup/transfer, hardware lifecycle/disk faults,
TalkBack/VoiceOver/keyboard/back behavior, and physical p95 <= 100 ms acceptance
open. Release runtime instrumentation/collection and realistic active-sync and
long-history workloads also require separate qualification. The iOS native
application-ID addition has not been compiled on this Windows host. The operator
steps above are prepared; Phase 0 remains in progress.
