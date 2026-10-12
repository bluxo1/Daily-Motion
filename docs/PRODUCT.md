# Daily Motion product specification

Planning baseline: 2026-10-12. This document defines product intent; [ROADMAP.md](ROADMAP.md) defines release gates, [DATA_MODEL.md](DATA_MODEL.md) defines domain vocabulary, and [DECISIONS.md](DECISIONS.md) records architectural choices. No production application is implemented yet.

## Vision and audience

Daily Motion is a premium strength-training application for iPhone and Android. It should help a trainee plan useful sessions, record what actually happened, understand progress, and eventually adapt training using trustworthy evidence. The long-term loop is **Plan → Train → Record → Predict → Learn → Adapt**. A completed workout should improve the next training decision.

The initial audience is adults who already train seriously for strength and hypertrophy: experienced gym users who repeat exercises, manage routines, and care about load, repetitions, effort and progression. The initial public launch is India-first, English, phones, with both platforms supported. “Premium” describes quality, responsiveness and care; the first public release is free. Monetization is a later product decision after retention evidence, not a prerequisite for building the logger.

Experienced recreational trainees are the primary audience. Beginners can use the application, but extensive exercise instruction and beginner curriculum are not launch priorities. Competitive peaking, rehabilitation and specialist sport coaching require additional domain validation and are outside the MVP. The initial product defaults are iOS 16+ and Android 10+, subject to release-time SDK qualification.

## Problems and value

Users need to record a set while tired, with one hand, and without interrupting their session. They need relevant previous performance rather than a crowded dashboard. They need to distinguish warm-ups from work, interpret load consistently, change an exercise when equipment is unavailable, and correct mistakes without corrupting history. They also need confidence that poor connectivity, app termination or an expired login will not lose their training.

The MVP value proposition is an excellent routine-to-history experience: fast logging, durable offline records, clear previous-set context and honest progress comparisons. The longer-term differentiation is the connection between those records and conservative recommendations. We do not claim superiority over Lyfta or another competitor without comparative usability and performance evidence. Competitor references are product-quality benchmarks, not a license to copy interfaces or unsupported marketing claims.

The assistant eventually becomes another way to use training systems: asking what happened last chest session, exploring a plateau, or reviewing a proposed future program adjustment. It does not become the home screen or a collection of unrelated AI features. A feature belongs only if it improves training decisions, reduces logging friction or makes historical evidence easier to understand.

## Product principles

1. **Training stays central.** Navigation starts with Train, History and Progress. The active workout receives the greatest design and performance attention.
2. **Recording must survive connectivity loss.** Local durable storage acknowledges changes; network synchronization happens afterward. Initial account creation requires connectivity, but an existing user's cached training remains available when authentication expires.
3. **Actual performance is distinct from intention.** Prior results and template targets may prefill drafts; nothing becomes a performed set until deliberately recorded. Missing effort, rest or recovery data remains missing.
4. **History is correctable and explainable.** Routine changes do not rewrite past workouts. Corrections retain revisions; explicit permanent deletion removes personal payloads and derived eligibility.
5. **Intelligence must show its evidence.** Numerical estimates come from deterministic/statistical/ML systems, never invented by an LLM. Confidence is not a decorative percentage.
6. **Adaptation preserves agency.** Recommendations are proposals. Future assistant writes require a concrete review and explicit confirmation; active training remains under direct UI control.
7. **Platform familiarity supports one identity.** Common visual tokens and training components coexist with native navigation, input, permission and accessibility conventions.
8. **Add complexity when evidence justifies it.** A lean team of one to three engineers favors managed infrastructure, internal modules and quality gates over premature services or generalized frameworks.

## MVP: first useful public release

The release must support **Create routine → Start workout → Log exercises/sets → Finish workout → View history/progress** end to end.

- Required account through email OTP; minimal onboarding for units and training focus. There is no guest mode. Accounts include export, deletion and privacy controls.
- A curated exercise catalog and owner-created variants with explicit equipment and load conventions; search and exercise-history access.
- User routines containing ordered exercises, set targets, planned rest and simple superset groups. Content edits publish immutable workout templates under the routine's stable identity; a routine is not a multiweek program.
- Routine-based and empty workouts, addition/reordering/skipping of exercises, substitutions, notes, resumable active sessions and clear abandonment behavior.
- Warm-up and working classes; optional top/back-off purpose tags; actual load and reps; optional RIR **or** RPE preserving the original scale; bodyweight-added and assisted load conventions. Basic holds/carries support duration/distance entry without prediction or a full cardio product.
- One-handed set recording, correction, duplication into an editable draft, rest timer and optional notification reminders.
- Offline cached catalog, routines, active workouts and history; durable local writes, idempotent synchronization, explicit conflicts and visible pending changes.
- Completed-workout history, comparable exercise history, measured working-set records such as highest supported external load and rep records, and basic load/repetition charts. Positive assistance is excluded from highest-load achievements and shown as a separately labeled lower-assistance trend. An estimated one-rep maximum is a prediction and is excluded at launch.

Simple supersets group exercises and describe their order. Complex automatic cluster, drop-set and rest-pause behavior is excluded; a user can record ordinary sets and notes without the application pretending to model those techniques precisely. See [USER_FLOWS.md](USER_FLOWS.md) and [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md).

## Near-term and long-term scope

After the logger passes public-release gates, add versioned multiweek programs, richer analytics, controlled CSV import and optional completed-workout export to platform health stores. Then introduce conservative deterministic intelligence: comparable estimated strength, progression proposals and carefully defined trend flags. The assistant follows stable analytics, prediction and change-proposal interfaces. Validated global and hierarchical/personalized models follow sufficient data and evaluation evidence. Recovery signals and wearable training arrive last. [ML_ROADMAP.md](ML_ROADMAP.md), [PREDICTION_ENGINE.md](PREDICTION_ENGINE.md) and [CHATBOT_ARCHITECTURE.md](CHATBOT_ARCHITECTURE.md) define those boundaries.

The enduring vision includes time-constrained session planning, useful substitutions, missed-session adjustment and goal-directed program adaptation. These are staged capabilities, not promises for the first release. Health access is optional and must never become a condition of effective logging.

Explicitly out of scope are medical diagnosis/treatment, injury prediction, drug or supplement guidance, nutrition/calorie tracking, computer-vision technique scoring, social feeds, trainer marketplaces, extensive video content, minors-focused services, real-time coach messaging and general-purpose chat. Do not build web/desktop clients or separate wearable applications before the phone experience is proven.

## Success criteria, assumptions and risks

The north-star product measure is **weekly retained trainees completing useful recorded workouts**, supported by four-week retention and repeated routine use. Count workouts, not chat messages, and do not interpret app retention as proof of strength or health improvement.

Measure account-to-first-completed-workout activation within seven days, first-routine creation/start time, set-entry effort, corrections, abandoned sessions, sync recovery and support reports. A prefilled set should require one deliberate completion tap. Use beta studies to establish baselines before inventing growth targets. Reliability gates include zero lost acknowledged sets or duplicate workouts in fault tests, a p95 durable local set-commit goal of 100 ms on qualification devices, and a proposed crash-free workout-session target of at least 99.9% once sample size supports interpretation.

Major assumptions are that experienced trainees will repeatedly log enough comparable sets, optional effort capture is sustainable, and a free quality-first launch produces a useful beta cohort. Risks include a logger too generic for advanced users, catalog ambiguity, excessive input burden, unreliable sync, misleading analytics, thin engineering capacity and premature AI spend. Prediction usefulness is uncertain until evaluated against simple baselines. India launch requires current privacy/security and store-policy review; English-only launch does not settle future notice-language obligations. Every release gate should identify an accountable owner and evidence rather than claim that documentation alone establishes compliance.
