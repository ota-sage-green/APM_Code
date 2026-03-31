<!--
Sync Impact Report
- Version change: template -> 1.0.0
- Modified principles:
  - [PRINCIPLE_1_NAME] -> I. Modular JavaScript By Default
  - [PRINCIPLE_2_NAME] -> II. Plan-Aligned Architecture
  - [PRINCIPLE_3_NAME] -> III. Contract-First and Testable Changes
  - [PRINCIPLE_4_NAME] -> IV. Data Integrity and Migration Safety
  - [PRINCIPLE_5_NAME] -> V. Traceable, Small, Reversible Delivery
- Added sections:
  - Architecture & Stack Constraints
  - Delivery Workflow & Quality Gates
- Removed sections: None
- Templates requiring updates:
  - ✅ .specify/templates/plan-template.md
  - ✅ .specify/templates/spec-template.md
  - ✅ .specify/templates/tasks-template.md
  - ⚠ pending: .specify/templates/commands/*.md (directory not present in this repo)
- Deferred TODOs: None
-->

# APM System Constitution

## Core Principles

### I. Modular JavaScript By Default
Frontend code MUST be modular JavaScript organized by responsibility
(`pages/`, `components/`, `api/`, reusable utilities). Files MUST have single
clear purposes and avoid tightly coupled "god components". Shared UI logic MUST
be extracted into composable modules before duplication is introduced.
Rationale: modular JS supports maintainability and safer incremental delivery.

### II. Plan-Aligned Architecture
Implementation decisions MUST align with `APM_PROJECT_PLAN.md` unless an
explicitly approved change is documented in the active spec and plan. The stack
baseline is React + Vite frontend, FastAPI backend, PostgreSQL storage, and
python-docx-based document generation. Deviations MUST include impact, risk, and
migration notes.
Rationale: architecture drift is the fastest path to delivery failure.

### III. Contract-First and Testable Changes
API and data behavior MUST be specified before implementation using clear input,
output, and error expectations. Every user story MUST define an independent test
path; acceptance scenarios are mandatory in specs. For changed APIs, integration
tests MUST validate request/response compatibility and error handling.
Rationale: explicit contracts reduce regressions across frontend/backend boundaries.

### IV. Data Integrity and Migration Safety
Schema changes MUST preserve data integrity with explicit constraints, indexes,
and migration steps. Destructive changes require rollback guidance. Imports and
bulk operations (including high-volume asset loads) MUST include validation,
error summaries, and idempotent behavior where feasible.
Rationale: APM reliability depends on durable and trustworthy asset/work data.

### V. Traceable, Small, Reversible Delivery
Work MUST be shipped in small slices mapped to user stories and task IDs. Each
change set MUST be reviewable, reversible, and documented by intent. Cross-cutting
refactors require explicit justification in the plan's complexity tracking.
Rationale: small reversible changes reduce risk and speed up troubleshooting.

## Architecture & Stack Constraints

- Frontend MUST remain React + Vite and use modular JS with clear folder
  boundaries (`frontend/src/pages`, `frontend/src/components`, `frontend/src/api`).
- Backend MUST remain FastAPI with SQLAlchemy data access and typed schemas.
- PostgreSQL is the source of truth; file-based data is transitional and MUST
  include import/migration plans.
- Generated WI documents MUST continue using template-driven python-docx services.

## Delivery Workflow & Quality Gates

1. Define or update spec with user stories, acceptance scenarios, and measurable
   outcomes.
2. Pass Constitution Check in the implementation plan before execution.
3. Implement by user story priority (P1 -> P2 -> P3) with independent validation.
4. Validate changed contracts, data constraints, and user-facing behavior.
5. Update docs when architecture, setup, or workflow assumptions change.

## Governance

This constitution is the top-level engineering standard for this repository.
All plans, specs, tasks, and pull requests MUST demonstrate compliance.

Amendment policy:
- Any contributor may propose a change via PR that updates this file and explains
  impact on templates/process.
- Versioning follows semantic rules: MAJOR for incompatible governance changes,
  MINOR for new principles/sections or materially expanded rules, PATCH for
  clarifications that do not alter obligations.
- Compliance review occurs at plan approval and pull request review checkpoints.

**Version**: 1.0.0 | **Ratified**: 2026-03-31 | **Last Amended**: 2026-03-31
