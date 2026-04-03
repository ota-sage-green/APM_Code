# Research: APM Core System Baseline

**Feature**: `001-apm-core-spec`  
**Date**: 2026-04-03

## R-01: Large asset hierarchy in the UI (100k rows)

**Decision**: Use a **lazy-loaded, expand/collapse tree** backed by a **children API**
(`GET /api/assets/{tag}/children` or equivalent filtered list), not a single payload of
the full hierarchy.

**Rationale**: Loading all assets into the browser violates performance and memory
constraints. Folder-style UX still requires expandable nodes and stable parent context.

**Alternatives considered**:
- Full tree in one request — rejected (payload size, time to first paint).
- Flat table only — rejected (spec requires folder-like tree).

## R-02: Bulk import duplicate `asset_tag` (upsert)

**Decision**: Import treats duplicate tags as **update** (upsert): existing row fields
are replaced with the latest validated row; summary returns `inserted`, `updated`,
and `errors` with row-level reasons.

**Rationale**: Matches clarified spec and supports iterative file fixes/reloads.

**Alternatives considered**:
- Reject duplicates — rejected (explicit product choice).
- Ignore duplicates silently — rejected (not auditable).

## R-03: `work_order` table vs application scope

**Decision**: **PostgreSQL schema may retain** `work_order` (and related indexes/views)
for future ERP alignment. **Application v1 does not** implement work-order CRUD, APIs,
or UI; ERP remains system of record for execution.

**Rationale**: Avoids a destructive schema fork while honoring the out-of-scope WO
requirement.

**Alternatives considered**:
- Drop table from schema — rejected (breaks existing SQL artifacts and future SAP).

## R-04: Authentication baseline

**Decision**: Implement **JWT auth** per `APM_PROJECT_PLAN.md` stack, with **single
shared effective access** in v1 (no role-gated features), matching spec assumptions.

**Rationale**: Stack alignment; RBAC deferred without blocking a secure baseline.

**Alternatives considered**:
- No auth on LAN — rejected (still multi-user shared server; needs basic accountability).

## R-05: WI generation and ERP handoff

**Decision**: Generation returns **downloadable .docx** plus **structured metadata**
(asset tag, strategy id/name where applicable, `wi_no`, generation timestamp) in the
API response for ERP reference/logging.

**Rationale**: Satisfies FR-008 without requiring APM to own work orders.

**Alternatives considered**:
- Metadata only in document body — rejected (harder to automate ERP workflows).
