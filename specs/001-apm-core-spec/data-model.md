# Data Model: APM Core System Baseline

**Feature**: `001-apm-core-spec`  
**Source of truth**: `schema.sql` (repository root) unless a migration explicitly
supersedes it.  
**Date**: 2026-04-03

## Entity overview

| Entity | Table(s) | Purpose |
|--------|-----------|---------|
| Equipment class | `equipment_class` | Catalog of equipment types (class / type / subclass). |
| FMEA row | `fmea` | Failure modes and ratings per equipment class. |
| Maintenance strategy | `maintenance_strategy` | Strategy definition per class (interval, discipline, etc.). |
| Strategy–WI link | `strategy_wi_link` | Ordered WIs attached to a strategy. |
| Work instruction header | `wi_header` | WI metadata and document fields. |
| Work instruction step | `wi_steps` | Steps grouped by section per WI. |
| Asset | `asset` | Self-referencing hierarchy via `parent_asset_tag` → `asset_tag`. |
| Asset strategy | `asset_strategy` | Strategy assignment to an asset (+ variant label). |
| Variant override | `strategy_variant_override` | Field-level overrides for an asset strategy. |
| Work order (schema only v1) | `work_order` | Present in DB; **not** in application scope for this feature. |

## Validation & integrity (from schema + spec)

- **Equipment class**: `UNIQUE (class_name, type, subclass)`; FMEA and strategies
  cascade on class delete (`ON DELETE CASCADE` on `fmea`, `maintenance_strategy`).
- **FMEA**: `severity`, `occurrence`, `detectability` constrained to 1–10; `rpn` stored
  generated.
- **Strategy**: `interval_type` enum-like check; `strategy_wi_link` enforces
  `UNIQUE (strategy_id, wi_no)` and ordered `sequence`.
- **Asset**: `asset_tag` **UNIQUE**; `parent_asset_tag` FK to `asset(asset_tag)`;
  optional `class_id` to `equipment_class`.
- **Asset strategy**: `UNIQUE (asset_id, strategy_id)`; ties asset to strategy with
  optional `variant_name` / notes.
- **Variant override**: Scoped to `asset_strategy_id`; may reference `wi_no` for
  WI-scoped overrides.
- **Bulk import**: Duplicate `asset_tag` rows are **upserts** (application behavior);
  invalid foreign keys (unknown class, broken parent) must surface as **row errors**
  with reasons.

## Relationships (conceptual)

```
equipment_class ─┬─< fmea
                 ├─< maintenance_strategy ─< strategy_wi_link >── wi_header ─< wi_steps
                 └─< asset (via class_id)

asset (self-ref parent) ─< asset_strategy >── maintenance_strategy
asset_strategy ─< strategy_variant_override

work_order (exists in schema; out of scope for app v1)
```

## Query patterns

- **Tree navigation**: Fetch roots (e.g. `parent_asset_tag IS NULL` or filtered list),
  then **lazy-load children** by parent tag for expand/collapse.
- **Strategy library**: Join `maintenance_strategy` ↔ `equipment_class`; expand WI
  sequence via `strategy_wi_link`.
- **WI generation**: Load `wi_header` + `wi_steps` + applicable `strategy_variant_override`
  for asset/strategy context.

## Migration notes

- Prefer **additive** migrations under `database/migrations/` when evolving beyond
  `schema.sql`.
- If `work_order` is ever used by the app, introduce APIs and UI in a **separate**
  feature with explicit scope; do not revive WO tracking in this baseline.
