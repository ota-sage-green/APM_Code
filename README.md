# APM System

Asset Performance Management system for managing maintenance strategies,
work instructions, and asset hierarchies.

## Current Status
- ✅ Work instruction document generator (Python + python-docx)
- ✅ Excel database (WI_Header + WI_Steps)
- ✅ Word template (WI_Template.docx)
- ✅ PostgreSQL schema designed
- 🔲 FastAPI backend
- 🔲 React frontend
- 🔲 Asset hierarchy import

## Quick Start (Current Version)
```bash
pip install openpyxl python-docx
python generate_wi_docs.py
```
Generated documents appear in the `Output Docs/` folder.

## Project Plan
See `APM_PROJECT_PLAN.md` for the full roadmap and Claude Code prompts.

## Engineering Constitution
Project standards for modular JavaScript structure, plan alignment, contract-first
changes, and data integrity are defined in `.specify/memory/constitution.md`.

## Tech Stack (Planned)
- Frontend: React 18 + Vite + shadcn/ui
- Backend: FastAPI (Python)
- Database: PostgreSQL
- Doc Generation: python-docx
