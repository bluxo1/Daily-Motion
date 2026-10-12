# Daily Motion design system

Planning baseline: 2026-10-12. This is the intended first-release specification, not an implemented component library. Product boundaries are in [PRODUCT.md](PRODUCT.md); behavior is in [USER_FLOWS.md](USER_FLOWS.md); performance and accessibility qualification are in [TESTING.md](TESTING.md).

## Visual philosophy and foundations

The interface should feel calm, precise and responsive. Give workout information priority over decoration: exercise identity, actual load/reps, previous comparable performance and next action. Premium quality comes from readable hierarchy, excellent defaults and reliable interaction. Avoid a dashboard dominated by readiness scores, chat prompts, streaks or unsupported numerical claims.

Use a four-logical-pixel spacing grid: 4, 8, 12, 16, 24, 32 and 48. Default phone page padding is 16; related controls use 8–12; sections use 24–32. Respect platform safe areas, cutouts and keyboard insets. Layout must work at 320 logical pixels wide without horizontal scrolling of primary workout controls. Larger text may turn a dense row into stacked fields.

Use platform system typography: San Francisco on Apple platforms only, Roboto/system typography on Android. Do not distribute SF as an Android asset. Defaults are 17 for body, 14 for supporting labels, 22 for section headings, 28–32 for page titles and 36–48 for primary workout metrics. Use tabular numerals for load/reps/timers and medium/semibold weight selectively. All text scales with system accessibility settings; sizes are defaults rather than fixed-height constraints. Flutter provides platform adaptations but application-specific choices still require deliberate design. [Flutter adaptations](https://docs.flutter.dev/ui/adaptive-responsive/platform-adaptations)

Define semantic colors rather than widget-local hex values. Initial dark tokens: background `#0B0D10`, surface `#151A20`, raised surface `#202731`, primary text `#F4F6F8`, secondary text `#AAB4C0`, divider `#35404D`, accent `#9BD8BE`, danger `#FF8F91`. Initial light tokens: background `#F5F7F9`, surface `#FFFFFF`, raised surface `#E8EDF2`, primary text `#101820`, secondary text `#4B5967`, divider `#CCD5DE`, accent `#245C48`, danger `#A82332`. These are starting tokens; automated and visual contrast checks determine final acceptance. Each semantic state also uses labels/icons, never color alone. Default appearance follows the system with explicit light/dark overrides.

Filled accent actions use an explicit `on_accent` text token: `#102019` in dark mode and `#FFFFFF` in light mode. Divider tokens are decorative, not the sole boundary/focus indicator of a control. Validate each actual text/control pairing during Phase 0 rather than assuming every semantic token can be combined arbitrarily.

## Hierarchy, navigation and components

Three persistent destinations are **Train**, **History** and **Progress**. Train contains reusable routines and a prominent start/resume action. History shows completed sessions; Progress shows comparable lift charts and measured records. Profile/settings are accessed from a secondary control. The assistant later appears contextually and through a dedicated entry point; it does not replace Train or add an empty MVP tab.

An active session is a focused workspace with an exercise list, current exercise, set editor and persistent session status. Leaving the screen preserves the session. A resume bar on other destinations returns to it. Back navigation must not silently abandon a workout. Single-device active-session limits produce a clear resume/finish/abandon choice.

Component hierarchy: semantic tokens → accessible primitives → domain controls → feature screens. Build internal mobile modules first; extract shared packages only after concrete reuse exists. Domain calculation, validation and persistence belong in controllers/use cases, not widget callbacks.

- **Cards:** represent actionable routines or summaries. Use one surface layer, consistent corner radius 16 and minimal shadow. Lists and set rows use alignment and dividers rather than a card around every datum.
- **Buttons:** primary filled action, secondary tonal/outlined action, tertiary text action, destructive action with explicit wording. Standard controls have at least 48×48 logical-pixel targets; primary workout actions are at least 56 high. Provide pressed, focused, loading, disabled and error states.
- **Set rows:** show set class/purpose, previous result, draft or actual values, optional effort and completion state. Recorded versus suggested values require text/state distinction. Editing a recorded set opens a correction flow rather than silently rewriting the chart.
- **Workout controls:** current-set completion stays in the lower thumb zone, above safe-area/keyboard insets. Put destructive and session-finishing actions away from routine completion taps. Allow quick load/repetition increments respecting exercise convention and user settings.
- **Inputs:** locale-aware decimal load entry, explicit unit labels, integer reps, and contextual RIR/RPE selection. RIR supports 0–10, with 10 labeled coarse high reserve; RPE supports 1–10 in half-point steps. Avoid binary floating-point assumptions in the domain layer. Zero reps is allowed only as an explicitly attempted failed set; a blank draft is not zero. Holds/carries use duration/distance fields appropriate to the variant. A blank bodyweight external load must not ambiguously mean total body mass.
- **Bottom sheets:** use for numeric editing, set options and exercise selection. Offer visible close/back and keyboard Done/Next controls. A dirty edit is preserved as a local draft or deliberately discarded; dismissing a sheet is never completion.

## One-handed logging and feedback

Prefill an editable set draft using comparable previous performance or an explicit template target, identifying the source. A deliberate complete action validates values, persists the local transaction and only then shows a completed state and optional light haptic. Failure leaves the draft intact with an inline retry. Do not wait for the server, prediction service or analytics recomputation. See [SYNC_PROTOCOL.md](SYNC_PROTOCOL.md).

Prefill precedence is an explicit template value, then the most recent compatible completed working-set value, then blank. For a prescribed rep range, use a compatible previous count within the range or its lower bound. Never prefill actual RIR/RPE from a target or previous report; show those as hints and require a new optional observation. Preserve the underlying canonical value of an untouched prefill when changing display units rather than converting its rounded display text back into stored load.

Completing a set can start its planned rest timer. Timer adjustments and cancellation are visible. Store the deadline and restore it after app suspension; never rely on a continuously running UI timer or guaranteed notification delivery. Show “rest timer” and “inter-set gap” distinctly from an observed actual-rest interval. Supersets show the next exercise and round; only start the configured group rest at the defined end of the round. A missing or skipped exercise does not fabricate a completed round.

Undo is prominent briefly after completion and remains available through editing. Swipe/long-press may expose shortcuts, but all actions also exist as labeled buttons or accessible menus. Haptics are optional, respect settings and never convey unique information. Use light confirmation for a successful local save, a distinct optional cue for timer expiry, and no haptic storm during every keystroke or sync event.

Animations communicate state: roughly 120–180 ms for control feedback and 200–300 ms for local expansion/sheet transitions, with platform-native route transitions where appropriate. Prefer opacity/position changes over theatrical movement. Reduced-motion mode removes nonessential movement. Avoid animated charts during active set entry, confetti on every set and persistent pulse effects.

## Charts and application states

Charts prioritize comparable observed load and reps. Label axes, units, date ranges and exercise/equipment context. Do not join incompatible variants or use aggregate lifted weight as a universal strength score. Offer an accessible textual summary and data list. Empty history explains the first useful action; empty progress says comparable recorded data is needed. Estimated strength and confidence bands appear only in later phases.

Local data renders immediately; use a short skeleton only when local data truly has not loaded. Background sync uses a compact pending/retry indicator, not a full-screen spinner. Empty states retain navigation and clear calls to action. Errors distinguish validation, local-storage failure, expired authentication, network delay and unresolved conflict. Do not label unsynced data lost. Expired authentication pauses upload while cached history, routine editing and logging remain available.

## Accessibility and platform behavior

Every custom control needs semantics, logical focus order, descriptive action labels and values. Screen readers announce exercise, set number/class, load basis, reps, effort and completion state without reading decorative separators. Charts and timers have useful alternatives; do not announce a countdown every second. Test full logging and correction with VoiceOver/TalkBack and without gestures.

Use at least 48 logical pixels for interactive targets, exceeding Apple's 44-point guidance and matching Android's 48-dp guidance. Support system text enlargement through the largest practical accessibility sizes, including at least 200%, without clipping primary controls. Verify contrast, grayscale/color blindness, switch/voice access, disabled-state readability and bright-gym lighting. [Apple control guidance](https://developer.apple.com/design/tips/), [Android accessibility](https://developer.android.com/design/ui/mobile/guides/foundations/accessibility), [Apple larger-text criteria](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/larger-text-evaluation-criteria)

iOS respects edge-back, modal conventions, numeric-keyboard completion affordances, safe areas and platform share/permission UI. Android respects system/predictive back, keyboard back behavior, edge-to-edge insets, platform selection/permission UI and native-feeling navigation. Shared branding does not require identical app bars or modal chrome. Test Flutter's actual behavior on both platforms; do not assume adaptive constructors solve every case. [Android predictive back](https://developer.android.com/guide/navigation/custom-back/predictive-back-gesture)

The p95 durable local set-commit goal is 100 ms on qualification devices. Smooth interaction targets 60 fps on supported 60 Hz devices; higher-refresh devices must not regress. Measure physical-device performance in profile/release mode with keyboard open, charts cached, pending sync and a realistic long session. Functional durability has priority over cosmetic optimistic completion.
