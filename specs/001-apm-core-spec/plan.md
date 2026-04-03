# Implementation Plan: APM Core System Baseline

**Branch**: `001-apm-core-spec` | **Date**: 2026-04-03 | **Spec**: [spec.md](./spec.md)  
**Input**: Feature specification from `/specs/001-apm-core-spec/spec.md`

**Note**: Filled by `/speckit.plan`. Phase 2 task breakdown is `/speckit.tasks` (`tasks.md`).

## Summary

Deliver the APM core: **maintenance strategy library** (equipment classes, FMEA,
strategies, WI linkage), **asset hierarchy** with **folder-style expandable tree**
and **bulk import (upsert on `asset_tag`)**, **strategy assignment + variant
overrides**, **WI authoring data in PostgreSQL**, **.docx generation** with
**ERP-handoff metadata**, and a **dashboard** for assets, active strategies, and WI
generation activity. **Work orders and execution history stay in the ERP** — no WO
CRUD in app v1. Technical approach: **FastAPI + SQLAlchemy 2 + PostgreSQL** backend,
**React 18 + Vite + shadcn/ui + Tailwind** frontend, **python-docx** for documents,
per `APM_PROJECT_PLAN.md` and [research.md](./research.md).

## Technical Context

**Language/Version**: Python 3.11+ (backend), JavaScript/React 18 (frontend)  
**Primary Dependencies**: FastAPI, Uvicorn, SQLAlchemy 2.0, Pydantic v2, FastAPI-Users
(JWT), python-docx, openpyxl; React, Vite, Tailwind, shadcn/ui, axios (or fetch
wrapper)  
**Storage**: PostgreSQL 15+; local filesystem for templates and generated `.docx`
(`TEMPLATE_PATH`, `OUTPUT_DIR`)  
**Testing**: pytest + httpx (async API tests); frontend Vitest/React Testing Library
(optional in early scaffolding)  
**Target Platform**: Shared LAN/server — Docker Compose or bare metal; browsers for UI  
**Project Type**: Web application (split `backend/` + `frontend/`)  
**Performance Goals**: Bulk import up to **100k** asset rows with batched DB writes;
tree UI remains responsive via **lazy-loaded children**; WI generation completes for
typical WIs within interactive expectations for 2–5 users  
**Constraints**: Spec/UI must **not** implement work-order tracking; duplicate
`asset_tag` on import = **upsert**; preserve referential integrity per `schema.sql`  
**Scale/Scope**: ~100k assets, 2–5 concurrent users, six primary UI areas (dashboard,
equipment library, strategy library, asset hierarchy, work instructions, no WO page)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

- [x] Modular JS structure defined for frontend changes (clear module boundaries
      and no god-components planned).  
      *Pages vs components vs `api/` client; dedicated `AssetTree` for tree behavior.*
- [x] Design aligns with `APM_PROJECT_PLAN.md` stack/architecture, or an approved
      deviation with risk and migration notes is documented.  
      *Aligned; WO scope removed from product, not from DB — see [research.md](./research.md) R-03.*
- [x] API/data contracts for changed behavior are documented and independently
      testable from user stories.  
      *See [contracts/openapi.yaml](./contracts/openapi.yaml) and user stories in spec.*
- [x] Schema/data changes include integrity constraints, migration path, and
      rollback considerations.  
      *Baseline = `schema.sql`; changes via additive migrations; [data-model.md](./data-model.md).*
- [x] Work is sliced into small, reversible increments mapped to story/task IDs.  
      *P1 stories first (library + assets), then P2 (WI generation + dashboard).*

**Post-design**: No unresolved gates; `work_order` remains schema-only for v1 app.

## Project Structure

### Documentation (this feature)

```text
specs/001-apm-core-spec/
├── plan.md              # This file
├── spec.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── openapi.yaml
└── checklists/
    └── requirements.md
# tasks.md — /speckit.tasks (not created here)
```

### Source Code (repository root)

```text
backend/
├── main.py
├── config.py
├── models/
├── routers/
├── schemas/
├── services/
│   └── doc_generator.py
└── requirements.txt

frontend/
└── src/
    ├── pages/
    ├── components/
    │   └── AssetTree.jsx    # folder-style expand/collapse + lazy children
    └── api/

database/
├── schema.sql               # current canonical (or superseded by migrations)
└── migrations/

templates/
└── WI_Template.docx

tests/
├── contract/
├── integration/
└── unit/
```

**Structure Decision**: **Web application** layout per `APM_PROJECT_PLAN.md`: separate
`backend/` and `frontend/`, shared `database/` and `templates/`, tests colocated under
`tests/` (split by layer). Existing repo files (`generate_wi_docs.py`, Excel, Word)
migrate into `backend/services` and `templates/` as implementation proceeds.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| *(none)* | | |

## Phase outputs

| Phase | Artifact | Path |
|-------|----------|------|
| 0 | Research | [research.md](./research.md) |
| 1 | Data model | [data-model.md](./data-model.md) |
| 1 | API contracts | [contracts/openapi.yaml](./contracts/openapi.yaml) |
| 1 | Quickstart | [quickstart.md](./quickstart.md) |

**Next command**: `/speckit.tasks` to produce `tasks.md` from this plan and the spec.
