# Quickstart: APM Core System Baseline

**Branch**: `001-apm-core-spec`  
**Date**: 2026-04-03

This quickstart describes how developers bring up the **planned** stack from
`APM_PROJECT_PLAN.md` once scaffolding exists. The repo today may still be
docs + SQL + generator only; treat this as the target local-dev path.

## Prerequisites

- Docker and Docker Compose (recommended), *or* local PostgreSQL 15+
- Python 3.11+ (backend)
- Node.js 20+ (frontend)

## 1. Database

From repo root (adjust paths if backend lives under `backend/`):

1. Create database and user (e.g. `apm_system` / `apm_user`).
2. Apply `schema.sql` to initialize tables, indexes, and views.

Example (psql):

```bash
psql -h localhost -U apm_user -d apm_system -f schema.sql
```

## 2. Environment

Use variables aligned with `APM_PROJECT_PLAN.md`:

- `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`
- `TEMPLATE_PATH` — path to `WI_Template.docx`
- `OUTPUT_DIR` — generated `.docx` output directory
- `SECRET_KEY` — JWT signing secret for FastAPI-Users

## 3. Backend (FastAPI)

Target layout:

```text
backend/
  main.py
  config.py
  routers/
  services/doc_generator.py
  models/
  schemas/
```

Install dependencies from `backend/requirements.txt`, then run:

```bash
cd backend
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Open interactive docs at `http://localhost:8000/docs`.

## 4. Frontend (React + Vite)

Target layout:

```text
frontend/
  src/pages/
  src/components/
  src/api/
```

```bash
cd frontend
npm install
npm run dev
```

Default Vite dev server: `http://localhost:5173` (proxy API to `:8000` as configured).

## 5. Docker Compose (when added)

```bash
docker compose up
```

Expected: Postgres on `5432`, API on `8000`, frontend dev or static on planned port.

## 6. Seed / migration from Excel

- One-time WI load: migrate `WI_Database.xlsx` into `wi_header` / `wi_steps` per
  project plan.
- Asset bulk import: use `POST /api/assets/import-bulk` once implemented; verify
  upsert and row-level error reporting.

## 7. Smoke checks (baseline scope)

- Equipment classes + FMEA + strategies + WI links readable from API.
- Asset tree: expand/collapse with lazy children load.
- WI generate: returns `.docx` + metadata for ERP reference.
- **No** work-order CRUD in API or UI for this baseline.
