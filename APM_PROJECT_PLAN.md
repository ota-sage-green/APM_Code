# APM System — Master Project Plan
## For use with Claude Code / Cursor / GitHub Copilot

---

## Project Overview

Build a web-based Asset Performance Management (APM) system that:
- Manages a maintenance strategy library (FMEA → strategies → WIs)
- Stores a full asset hierarchy (up to 100,000 assets)
- Applies strategies to assets with variant overrides
- Generates Word (.docx) work instruction documents from templates
- Supports ERP execution by generating context-rich WIs and metadata
- Designed for a team of 2-5 users on a shared network/server

---

## Tech Stack

| Layer | Technology | Why |
|---|---|---|
| Frontend | React 18 + Vite | Modern, fast, AI-generatable components |
| UI Components | shadcn/ui + Tailwind CSS | Pre-built, professional, easy to customise |
| Backend API | FastAPI (Python) | Async, fast, auto-generates API docs, Python skills apply |
| Database | PostgreSQL 15+ | Multi-user, handles 100k+ rows, scales to cloud |
| ORM | SQLAlchemy 2.0 | Pythonic DB access, works with FastAPI |
| Doc Generation | python-docx (existing) | Already built and working |
| Auth | FastAPI-Users (JWT) | Simple user login/roles |
| File Storage | Local filesystem → S3 later | Start simple |

---

## Repository Structure

```
apm-system/
├── backend/
│   ├── main.py               # FastAPI app entry point
│   ├── config.py             # DB connection, settings
│   ├── models/               # SQLAlchemy table models
│   │   ├── equipment.py      # equipment_class, fmea
│   │   ├── strategy.py       # maintenance_strategy, strategy_wi_link
│   │   ├── wi.py             # wi_header, wi_steps
│   │   ├── asset.py          # asset (self-referencing hierarchy)
│   │   ├── asset_strategy.py # asset_strategy, variant_overrides
│   ├── routers/              # API route handlers
│   │   ├── equipment.py
│   │   ├── strategy.py
│   │   ├── wi.py
│   │   ├── assets.py
│   │   └── generate.py       # doc generation endpoint
│   ├── services/
│   │   └── doc_generator.py  # existing python-docx code moved here
│   ├── schemas/              # Pydantic request/response models
│   └── requirements.txt
├── frontend/
│   ├── src/
│   │   ├── App.jsx
│   │   ├── pages/
│   │   │   ├── Dashboard.jsx
│   │   │   ├── EquipmentLibrary.jsx
│   │   │   ├── StrategyLibrary.jsx
│   │   │   ├── AssetHierarchy.jsx
│   │   │   ├── WorkInstructions.jsx
│   │   │   └── WorkOrders.jsx
│   │   ├── components/
│   │   │   ├── AssetTree.jsx       # hierarchical tree view
│   │   │   ├── StrategyCard.jsx
│   │   │   ├── WIEditor.jsx
│   │   │   └── GenerateButton.jsx
│   │   └── api/
│   │       └── client.js           # axios API calls
│   ├── package.json
│   └── vite.config.js
├── database/
│   ├── schema.sql            # full schema (already built)
│   ├── migrations/           # future schema changes
│   └── seed_data.sql         # sample data for development
├── templates/
│   └── WI_Template.docx      # your existing Word template
├── docker-compose.yml         # runs postgres + backend + frontend together
└── README.md
```

---

## Database Schema

See schema.sql — already complete. Key tables:

```
equipment_class → fmea                    (FMEA library)
equipment_class → maintenance_strategy    (strategy library)
maintenance_strategy → strategy_wi_link → wi_header  (WI links)
asset (self-referencing hierarchy)        (100k assets)
asset → asset_strategy → strategy_variant_override   (variants)
```

---

## API Endpoints (FastAPI)

### Equipment & FMEA
```
GET    /api/equipment-classes
POST   /api/equipment-classes
GET    /api/equipment-classes/{id}/fmea
POST   /api/equipment-classes/{id}/fmea
GET    /api/equipment-classes/{id}/strategies
```

### Strategies
```
GET    /api/strategies
POST   /api/strategies
PUT    /api/strategies/{id}
POST   /api/strategies/{id}/wi-links
DELETE /api/strategies/{id}/wi-links/{wi_no}
```

### Work Instructions
```
GET    /api/wi
POST   /api/wi
GET    /api/wi/{wi_no}
PUT    /api/wi/{wi_no}
GET    /api/wi/{wi_no}/steps
POST   /api/wi/{wi_no}/steps
POST   /api/wi/generate          # triggers doc generation
POST   /api/wi/import-excel      # import from existing xlsx
```

### Assets
```
GET    /api/assets               # with ?site=&area=&class_id= filters
POST   /api/assets
GET    /api/assets/{tag}
PUT    /api/assets/{tag}
GET    /api/assets/{tag}/children     # hierarchy traversal
GET    /api/assets/{tag}/strategies
POST   /api/assets/{tag}/strategies  # assign strategy
POST   /api/assets/import-bulk       # bulk import 100k rows from CSV/Excel
```

## Frontend Pages

### 1. Dashboard
- KPI cards: assets, active strategies, WI generation activity
- Recent activity feed

### 2. Equipment Library
- Table of equipment classes (class / type / subclass)
- Click to expand: FMEA records, linked strategies
- Add/edit class, add FMEA rows inline

### 3. Strategy Library
- List of strategies per equipment class
- Each strategy shows: interval, linked WIs in sequence
- Assign strategy to asset(s) from here

### 4. Asset Hierarchy
- Tree view (collapsible) showing full hierarchy
- Filter by site / area / class / status
- Click asset → see assigned strategies and variants
- Bulk import button → upload CSV/Excel of 100k assets

### 5. Work Instructions
- Table of all WIs with Generate? toggle
- Click WI → edit all fields (maps to wi_header + wi_steps tables)
- Generate button → calls /api/wi/generate → downloads .docx

## Document Generation Flow

```
User clicks Generate in UI
    → POST /api/wi/generate  {wi_nos: ['WI-001'], asset_tag: 'P-101A'}
    → Backend loads wi_header + wi_steps from PostgreSQL
    → Backend checks asset_strategy for any variant overrides
    → Merges base WI data with overrides
    → Opens WI_Template.docx
    → Replaces [placeholders] with merged data
    → Expands multi-line fields and steps tables
    → Saves output to /output_docs/{asset_tag}/{wi_no}.docx
    → Returns download URL to frontend
```

The core doc generation code (generate_wi_docs.py) moves into
backend/services/doc_generator.py unchanged — just wrapped in a
FastAPI endpoint.

---

## Prompts for Claude Code (Use These In Order)

### PROMPT 1 — Project Setup
```
Create a new project called apm-system with this structure:
[paste repository structure above]

Set up:
- FastAPI backend with SQLAlchemy 2.0 and PostgreSQL
- React 18 frontend with Vite, Tailwind CSS, and shadcn/ui
- docker-compose.yml that runs postgres, backend on :8000, frontend on :3000
- config.py that reads DB connection from environment variables
- requirements.txt with: fastapi, uvicorn, sqlalchemy, psycopg2-binary,
  python-docx, openpyxl, python-multipart, pydantic

Do not write any business logic yet — just the scaffolding and config.
```

### PROMPT 2 — Database Models
```
Create SQLAlchemy models in backend/models/ based on this schema:
[paste schema.sql]

Each model file should match the schema.sql table groupings.
Include a base.py with the declarative base and timestamp mixins.
Include an __init__.py that imports all models.
Do not create any routes yet.
```

### PROMPT 3 — Asset Import
```
Create a bulk import endpoint at POST /api/assets/import-bulk

It should:
- Accept a CSV or Excel file upload (up to 100,000 rows)
- Expected columns: asset_tag, asset_name, parent_asset_tag, site, area,
  class_name, asset_status, criticality, sap_equipment_no
- Look up class_id from equipment_class table by class_name
- Insert in batches of 1000 rows using SQLAlchemy bulk_insert_mappings
- Return a summary: {inserted: N, updated: N, errors: [{row, reason}]}
- Handle parent_asset_tag references correctly (assets may reference
  parents not yet inserted — do two passes)
```

### PROMPT 4 — WI Generation Endpoint
```
Move the document generation code from this existing Python script
into backend/services/doc_generator.py:
[paste generate_wi_docs.py content]

Then create a FastAPI endpoint POST /api/wi/generate that:
- Accepts {wi_nos: list[str], asset_tag: str | None}
- Loads wi_header and wi_steps from the database
- If asset_tag is provided, loads strategy_variant_override records
  and merges them into the wi data before generation
- Calls doc_generator.build_document(wi_data, steps, template_path)
- Saves output to OUTPUT_DIR/{wi_no}.docx
- Returns {files: [{wi_no, download_url}]}
```

### PROMPT 5 — Asset Hierarchy UI
```
Create a React component AssetHierarchy.jsx that:
- Fetches GET /api/assets?site=&area= and displays as a collapsible tree
- Each node shows: asset_tag, asset_name, class, status badge, criticality badge
- Clicking a node expands it to show children
- Clicking a node also opens a side panel showing:
  - Asset details (all fields)
  - Assigned strategies (fetched from GET /api/assets/{tag}/strategies)
  - Assign Strategy button that opens a modal with a strategy dropdown
- Include a search bar that filters the tree by asset_tag or asset_name
- Include a Bulk Import button that opens a file upload dialog
  calling POST /api/assets/import-bulk
- Use shadcn/ui components for all UI elements
- Use Tailwind CSS for all styling
```

### PROMPT 6 — Dashboard
```
Create a Dashboard.jsx page that shows:
- 4 KPI cards: Total Assets, Active Strategies, WIs Generated This Week, Assets With Strategies
  (each fetched from the appropriate API endpoint)
- A table of recently generated work instructions
  with columns: WI#, Asset, Strategy, Generated Date, Generated By
- A Recent Activity section showing the last 10 created/updated records
  across all entity types
Use shadcn/ui Card, Table, and Badge components.
Use Tailwind for layout.
```

---

## Migration from Excel

When ready, run this one-time migration:

```python
# migrate_excel_to_db.py
# Reads WI_Database.xlsx and inserts into PostgreSQL
# Run once: python migrate_excel_to_db.py
```

Claude Code prompt for this:
```
Write a migration script migrate_excel_to_db.py that:
- Reads WI_Database.xlsx (sheets: WI_Header, WI_Steps)
- Connects to PostgreSQL using config from config.py
- Inserts all rows into wi_header and wi_steps tables
- Skips rows where wi_no already exists (upsert)
- Prints a summary at the end
```

---

## Deployment Options

### Local network (current)
```
docker-compose up
→ PostgreSQL on port 5432
→ FastAPI on http://server-ip:8000
→ React on http://server-ip:3000
```

### Cloud (when selling)
```
Docker containers → AWS ECS / DigitalOcean App Platform
PostgreSQL → AWS RDS / DigitalOcean Managed DB
Files → AWS S3
Domain + SSL → Cloudflare
```

---

## SAP Integration (Future)

When ready, add:
- `sap_equipment_no` on asset table (already in schema)
- A sync service: GET SAP equipment list via OData API → upsert assets
- ERP remains system-of-record for work order planning, execution, and history

SAP OData endpoint pattern:
```
GET https://sap-server/sap/opu/odata/sap/API_EQUIPMENT_SRV/Equipment
Authorization: Basic {base64 credentials}
```

---

## Environment Variables (.env file)

```
DB_HOST=localhost
DB_PORT=5432
DB_NAME=apm_system
DB_USER=apm_user
DB_PASSWORD=yourpassword
TEMPLATE_PATH=./templates/WI_Template.docx
OUTPUT_DIR=./output_docs
SECRET_KEY=your-jwt-secret-key
ENVIRONMENT=development
```

---

## What Already Exists (Don't Rebuild)

- generate_wi_docs.py — move to backend/services/doc_generator.py
- WI_Template.docx — move to templates/
- WI_Database.xlsx — migrate to DB then archive
- schema.sql — run against PostgreSQL to create tables

