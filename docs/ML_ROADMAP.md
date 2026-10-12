# ML roadmap

Status: planned; 2026-10-12. The MVP contains no prediction service, learned model, or assistant. This strategy follows [PRODUCT.md](PRODUCT.md), [ROADMAP.md](ROADMAP.md), and the revision rules in [DATA_MODEL.md](DATA_MODEL.md). Future entities and interfaces described here are introduced with their owning phase, not provisioned as unused MVP tables.

## Purpose and staged delivery

ML should help an advanced strength or hypertrophy athlete choose a useful next action. It must earn its complexity against simple references, respect deliberate submaximal training, and improve the training loop rather than create a separate AI dashboard. With 1–3 engineers, reliable records and excellent logging take precedence over model infrastructure.

| Stage | Deliverable | Gate and exclusions |
| --- | --- | --- |
| MVP | Correct offline records, explicit prescriptions, comparable histories | No inference, data donation, or model training |
| Phase 2 | Versioned programs, richer analytics, provenance-aware imports | No learned readiness or capacity scores |
| Phase 3 | Versioned deterministic references and conservative progression proposals | Ship only supported loading conventions; no automatic changes |
| Phase 4 | Assistant consumes domain analytics and prediction results | LLM remains outside numerical inference |
| Phase 5A | Statistical/global models in shadow mode, then limited experiments | Only separately opted-in first-party training logs enter population training |
| Phase 5B | Hierarchical personalization | Demonstrated temporal benefit; no independent model per user by default |
| Phase 6 | Optional recovery-signal research and wearable context | Separate permissions and proven incremental utility |

Early inference is a module in the modular FastAPI backend. A later Python job trains offline and publishes a versioned artifact. PostgreSQL remains the source of truth; object storage holds authorized dataset manifests and artifacts. Do not introduce a feature store, vector database, streaming platform, or separate ML microservice before measured workload or independent operational ownership requires one. See [ARCHITECTURE.md](ARCHITECTURE.md).

## Day-one data contract

Collect what normal training requires, without adding mandatory taps for hypothetical features:

- Planned load, rep range, optional effort target, planned rest, template/program version, and the prescription snapshot actually used.
- Actual load and its convention; reps and their convention; side; nullable duration/distance; `set_class=warmup/working`; `set_purpose=regular/top/backoff`; `execution_status=pending/completed/partial/failed/skipped`, preserving explicit failed-attempt context.
- Stable exercise variant, equipment/setup comparability, catalog semantics version, observed logger completion sequence, `order_source`, delayed-entry indicators, exercise position, and superset membership. Logger order is not proof of physical execution order.
- Optional reported RIR or RPE, retaining the selected scale. Missing effort is unknown; neither scale is automatically converted into the other.
- Session occurrence times, per-root local recording sequence, server acceptance times, committed owner-feed generation/position, observation revisions, and source provenance. CSV imports are identifiable and excluded from global training by default.
- Planned rest and separately observed timer intervals. A gap between set completions includes lifting time and is not actual rest. Actual set-start capture remains optional.

Null, legitimate zero, failure, and skipping must remain distinct. A failed attempt may have zero actual reps; a skipped set has no performance label. Bodyweight, assistance, per-implement load, and total external load are different measurements. Specialized future methods require segment-level observations rather than a summed drop/cluster set. Derived volume is a measurement under a documented convention, not a direct measure of muscle stimulus.

Notes, inferred injuries, chat transcripts, and optional health data are not default training features. Body measurements remain optional product records. Catalog muscle mappings support descriptive analytics, but their heuristic nature must survive into features and explanations.

## Baselines, targets, and cold start

[PREDICTION_ENGINE.md](PREDICTION_ENGINE.md) owns deterministic policies: last comparable exposure, median of three comparable exposures, restricted estimated-strength proxy, and gated double progression. Include the prescribed-target baseline in learned-model comparisons; otherwise a model can appear useful merely by predicting the rep count the athlete was told to perform.

The first learned target is observed working-set reps **conditional on the prescription**, load, and available preceding history. Reaching a five-rep target does not establish five-rep capacity. A deliberate stop, deload, back-off set, or shortened workout cannot silently become a fatigue or failure label. Intentional interruptions are excluded from performance labels when identified; unknown intent is flagged and evaluated separately.

Evaluate completion probability as a separate target with its own calibration and eligibility. Later next-set, session-outcome, and progression tasks receive separate datasets and model versions. No latent physiological fatigue target is invented from workout totals.

Start with regularized statistical models; consider modest tree models only when they improve the relevant holdout. Global models provide a prior; personalized effects shrink toward that prior. A candidate personalization floor is 30 eligible working sets across 10 comparable exposures spanning six weeks **per user, variant/comparability key and target task**, not pooled unrelated exercises. This is an engineering eligibility default, not proof of adequate data: require temporal benefit and acceptable uncertainty before activation. Sparse users receive supported deterministic references or abstention, without mandatory AMRAP tests or failure training.

## Features and reproducible datasets

Use explicit load/prescription features, lagged comparable performance, set position, prior completed sets, recent volume, elapsed time since training, and missingness indicators. Effort and actual-rest observations are optional. Delayed or ambiguous execution order cannot feed timing-dependent features. Do not predict from signals not collected or imply an inter-completion interval is physiological recovery.

Each dataset manifest records consent scope, extraction cutoff, observation revisions, feature/label definitions, comparability policy, exclusions, and split boundaries. Feature construction recreates what was visible at inference time. Server inference reads features and the committed owner-feed visibility fence in one consistent database snapshot; preserve its `visibility_cursor` and exhaustive source/feature manifest. Historical rows carry feed generation/position. An acceptance timestamp assigned inside a transaction is not proof of visibility if that transaction commits later. Local inference captures a consistent SQLite snapshot with per-root `local_seq` and a manifest. Catalog/mapping versions are captured explicitly outside the owner feed. Later edits, completed-session totals, the target set's reported RIR, and subsequent sets are forbidden inputs. Labels may use explicitly versioned corrections; feature history cannot be retroactively improved. Deletion invalidates affected replay/dataset rows rather than justifying retention of erased values.

Fit imputers, encoders, scaling, and feature selection only on training partitions. Temporal evaluation and preprocessing isolation are supported by [scikit-learn's leakage guidance](https://scikit-learn.org/stable/common_pitfalls.html). Use date-based rolling folds for irregular workouts, rather than blindly applying an equal-spacing helper; see its [time-series evaluation guidance](https://scikit-learn.org/stable/modules/cross_validation).

## Evaluation and release gates

Keep whole sessions within a temporal partition. For an online next-set replay, preceding completed sets in the evaluation session are available only after their actual visibility cutoff. Separately hold out users to measure cold start. Report performance by exercise family, loading convention, data density, missing effort, and prescription style; do not publish sensitive small-cohort breakdowns.

For observed reps, report MAE against last exposure, median history, and prescribed-target baselines. For completion probability, report Brier score and calibration. For intervals, report empirical coverage and width by supported cohort. Include abstention rate, stale-data rate, and errors that would recommend excessive progression. Dataset counts and eligibility exclusions accompany every result.

Promotion requires better temporal performance than relevant baselines, no material regression in supported cohorts, and a bounded shadow period followed by a consented experiment. Online measures include prescription completion, override frequency, recommendation usefulness, retention, and reported excessive difficulty. Acceptance rate alone is insufficient. Recommendations remain optional proposals; experiments cannot silently increase training demands.

## Operations, privacy, and useful restraint

Track artifact checksum, code revision, dataset manifest, parameters, evaluation report, supported inputs, and rollback version. Register feature and output schemas alongside method versions. Prediction records preserve provenance and outcomes; observability logs contain identifiers and operational metrics rather than raw training or health payloads.

Evaluate drift weekly using eligible observed outcomes. Initial policy: a rolling 14-day window needs at least 100 outcomes per task; two consecutive qualified evaluations with task loss more than 10% worse than the corresponding baseline trigger rollback and investigation. Use MAE for reps and Brier score for completion probabilities. Smaller windows yield an insufficient-evidence alert, not a claim that drift is absent. Invalid schemas or unsupported inputs fall back immediately. These operational thresholds are versioned pilot defaults.

Population training requires separate, revocable opt-in; personal predictions do not imply donation. Imported health data and CSV records are excluded by default, and health data or derived health signals never go to the third-party assistant. Deletion removes eligibility, source payloads, and affected stored datasets according to [SECURITY.md](SECURITY.md). Recheck current consent/erasure eligibility before publishing an artifact or stored derived dataset; stale in-flight extraction cannot recreate an erased copy. Document the retraining response for existing artifacts; do not promise immediate exact unlearning from model weights.

Useful ML improves a specific decision beyond rules. Unnecessary ML includes an unexplained readiness score, a new per-user neural network with ten workouts, arbitrary fatigue multipliers, LLM-generated weights, or a model whose accuracy comes from prescribed-rep leakage. Changes to targets, consent, eligibility, or deployment gates require an entry in [DECISIONS.md](DECISIONS.md) and the checks in [TESTING.md](TESTING.md).
