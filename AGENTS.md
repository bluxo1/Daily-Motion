# Repository Guidelines

## Project Structure & Module Organization

This repository currently contains planning documents only: `README.md` introduces the product, and `docs/` holds requirements, architecture, design, security, and testing specifications. Application code, tests, and assets have not been scaffolded. The proposed layout is `apps/mobile/` for Flutter, `services/api/` for FastAPI, `contracts/` for API schemas and shared fixtures, and `infra/` for deployment configuration. Add `ml/` only when experiments begin. Start with `docs/PRODUCT.md`, `docs/ROADMAP.md`, and `docs/ARCHITECTURE.md`; consult `docs/DATA_MODEL.md`, `docs/SYNC_PROTOCOL.md`, and `docs/API.md` together for workout behavior.

## Build, Test, and Development Commands

There is no runnable application or build/test script yet. For documentation edits, run `git diff --check` to catch whitespace errors and review changed Markdown links against their targets. Once implementation exists, follow `docs/CONTRIBUTING.md`: use `dart format`, `flutter analyze`, and `flutter test` for mobile changes; use `ruff format`, `ruff check`, mypy, and pytest for Python changes. Do not report those future checks as completed today.

## Coding Style & Naming Conventions

Keep Markdown headings descriptive and relative links valid. Use the domain terms in `docs/DATA_MODEL.md` precisely: a routine, template, program version, workout session, session exercise, and set are distinct. Future Dart and Python code should follow their standard formatters, with feature/domain names matching the specifications. Keep planned, observed, inferred, and derived values separate.

## Testing Guidelines

For now, check documentation consistency, links, and phase claims. `docs/TESTING.md` defines future unit, widget, database, contract, device, accessibility, and sync fault tests. Add tests for observable behavior with deterministic synthetic fixtures; exercise real SQLite or PostgreSQL where transactions, migrations, or row policies matter. No coverage percentage or test-file naming convention is established yet.

## Commit & Pull Request Guidelines

History currently contains an initial commit and `docs: add Daily Motion product and architecture planning`; `docs/CONTRIBUTING.md` encourages meaningful, conventional-style messages and short-lived `feat/`, `fix/`, `docs/`, or `chore/` branches. Keep one outcome per PR. Explain scope, roadmap phase, validation commands and results, and limitations. Include screenshots for interaction changes, contract fixtures for API changes, and migration/rollback details for schema changes.

## Security & Configuration

Keep secrets and production user data out of version control, fixtures, screenshots, and notebooks. Use placeholders in example environment files. Check `docs/SECURITY.md` before changing authentication, owner isolation, deletion, or data handling.
