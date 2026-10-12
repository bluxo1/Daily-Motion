# Daily Motion

Daily Motion is a planned premium strength and hypertrophy training app for iOS and Android. Its foundation is fast, reliable workout logging; its long-term direction is an intelligent training system built around **Plan -> Train -> Record -> Predict -> Learn -> Adapt**.

## Project status

The repository contains the product and technical planning package. **Application implementation has not started.** Architecture decisions are accepted planning baselines that still require implementation spikes, testing and release qualification.

The first useful release targets advanced recreational strength/hypertrophy trainees, with an India-first, English-language adult launch. It will be free initially and require online account creation before the first workout. Subsequent routines, workout logging and local history are designed to work offline, including when cloud authentication expires.

MVP: **Create routine -> Start workout -> Log exercises/sets -> Finish workout -> View history/progress**. Warm-up/working sets, optional effort, simple supersets, substitutions and precise exercise/load conventions belong in this foundation. Programs, import, health integrations, billing, predictions and the assistant are introduced progressively.

## Documentation

Markdown is the source of truth. Start with product, roadmap and architecture; use the data model, sync protocol and API together when implementing training behavior.

| Area | Documents |
|---|---|
| Product and delivery | [Product](docs/PRODUCT.md), [Product requirements](docs/prd.md), [Roadmap](docs/ROADMAP.md), [Phase checklist](docs/phases.md) |
| Technical foundation | [Architecture](docs/ARCHITECTURE.md), [Data model](docs/DATA_MODEL.md), [API](docs/API.md), [Offline and sync protocol](docs/SYNC_PROTOCOL.md) |
| Experience | [Design system](docs/DESIGN_SYSTEM.md), [User flows](docs/USER_FLOWS.md) |
| Intelligence | [ML roadmap](docs/ML_ROADMAP.md), [Prediction engine](docs/PREDICTION_ENGINE.md), [Assistant architecture](docs/CHATBOT_ARCHITECTURE.md) |
| Trust and quality | [Health integrations](docs/HEALTH_INTEGRATIONS.md), [Security and privacy](docs/SECURITY.md), [Testing](docs/TESTING.md), [Adversarial review](docs/ADVERSARIAL_REVIEW.md) |
| Project conventions | [Decision log](docs/DECISIONS.md), [Contributing](docs/CONTRIBUTING.md), [Engineering rules](docs/rules.md), [Implementation handoff prompt](docs/prompt.md) |

Each document distinguishes MVP from future capabilities. The decision log records alternatives and revisit conditions; the adversarial review records corrections and remaining validation gates.

## Proposed repository structure

Only `docs/` and this README are being delivered now. The following application layout is proposed, not scaffolded:

```text
Daily-Motion/
├── apps/
│   └── mobile/       # Flutter features, internal domain/design modules, local persistence
├── services/
│   └── api/          # Modular FastAPI backend, durable jobs, app-schema migrations
├── contracts/        # Generated OpenAPI/client contracts and behavioral fixtures
├── infra/            # Local services and deployment configuration
├── ml/               # Added when offline experiments/training actually begin
├── docs/
└── README.md
```

The baseline stack is Flutter/Riverpod/Drift, one modular Python/FastAPI service and managed Supabase PostgreSQL/Auth. Cloud deployment defaults to Mumbai. Separate ML services and shared packages are added only when demonstrated requirements justify them.

## Implementation order

1. Prove local durability, sync recovery, platform UX and the design system.
2. Deliver routines, offline workout tracking, history and basic progress.
3. Add versioned programs, richer analytics and reviewed migration/integration workflows.
4. Introduce conservative numerical intelligence, then grounded assistant actions.
5. Add validated personalized models and recovery/wearable intelligence.

There are no application build or test commands yet. [CONTRIBUTING.md](docs/CONTRIBUTING.md) and [TESTING.md](docs/TESTING.md) define the conventions and checks to introduce with implementation.
