# Feature Specification: APM Core System Baseline

**Feature Branch**: `001-apm-core-spec`  
**Created**: 2026-03-31  
**Status**: Draft  
**Input**: User description: "read APM_PROJECT_PLAN.md and start the specify step"

## Constitution Alignment *(mandatory)*

- **CA-001 Modular JS Impact**: Frontend implementation will follow a modular
  JavaScript structure under `frontend/src/pages`, `frontend/src/components`,
  and `frontend/src/api`, with each page and component focused on a single,
  well-defined responsibility.
- **CA-002 Plan Alignment**: This feature defines the functional baseline for
  the APM system exactly as described in `APM_PROJECT_PLAN.md` (React + Vite
  frontend, FastAPI backend, PostgreSQL, python-docx-based WI generation) with
  no intentional deviations.
- **CA-003 Contract/Testability**: API contracts for the core entities
  (equipment classes, strategies, assets, WIs) will be expressed via clear
  request/response shapes and acceptance scenarios in this spec, and later
  validated through endpoint-level tests.
- **CA-004 Data Integrity**: The spec assumes the existing PostgreSQL schema
  from `schema.sql` as the source of truth. Any schema changes must preserve
  referential integrity between equipment, strategies, assets, and WIs and
  provide safe migration paths.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Plan and Manage Maintenance Strategies (Priority: P1)

A reliability engineer needs to define and maintain a library of maintenance
strategies (derived from FMEA) that can be reused across many assets.

**Why this priority**: Accurate, reusable strategies are the foundation of the
APM system; without them, work instructions have no consistent basis.

**Independent Test**: With only the strategy and FMEA features enabled,
engineers can create equipment classes, define FMEA records, and associate
strategies and WIs without needing asset hierarchy.

**Acceptance Scenarios**:

1. **Given** a new equipment class, **When** a reliability engineer adds FMEA
   records and links maintenance strategies to failure modes, **Then** the
   strategy library shows the strategies grouped by equipment class and failure
   mode.
2. **Given** an existing strategy, **When** the engineer updates intervals or
   linked WIs, **Then** the changes are reflected for all future usages.

---

### User Story 2 - Maintain Asset Hierarchy and Assign Strategies (Priority: P1)

An asset engineer needs to create and maintain a 100k-row asset hierarchy and
assign appropriate strategies (with variants) to each asset.

**Why this priority**: Strategy assignment to real assets is necessary to
generate actionable work instructions; it ties the library to operations.

**Independent Test**: With only asset hierarchy and strategy assignment
features enabled, engineers can import assets, browse the hierarchy, and assign
strategies without needing WI generation.

**Acceptance Scenarios**:

1. **Given** a CSV/Excel file with up to 100,000 assets, **When** the engineer
   imports it through the bulk import flow, **Then** the full hierarchy is
   created with correct parent/child relationships and any errors are reported
   with row-level reasons.
2. **Given** an asset node in the tree, **When** the engineer assigns a
   strategy from the strategy library, **Then** the asset shows the assigned
   strategy and any configured variant overrides.
3. **Given** the hierarchy view is open, **When** a user clicks an asset with
   children, **Then** the UI expands/collapses like a folder tree and preserves
   parent-child context while navigating.

---

### User Story 3 - Generate Work Instructions for ERP Execution (Priority: P2)

A planner or technician needs to generate WI documents from templates for use
in the ERP execution process.

**Why this priority**: Document generation provides visible value to maintenance
teams, but depends on the strategy and asset foundations.

**Independent Test**: With only WI generation features enabled, planners can
generate and download WIs for a given strategy/asset, even if asset import and
strategy configuration were done earlier.

**Acceptance Scenarios**:

1. **Given** a configured WI template and WI data in PostgreSQL, **When** a
   planner requests document generation for one or more WIs, **Then** the
   system returns .docx files with merged header/step data and any applicable
   variant overrides.
2. **Given** an asset with assigned strategies, **When** a planner generates
   required WIs, **Then** each document includes enough context (asset,
   strategy, WI identifiers) to execute the job in ERP.

---

### Edge Cases

- What happens when the bulk asset import file contains invalid or duplicate
  asset tags, missing parent references, or unknown equipment classes?
- How does the system handle document generation when WI data is incomplete,
  or when variant overrides conflict with base WI definitions?
- For duplicate asset tags during import, the system updates existing asset
  records using the latest provided row values and reports the row as updated.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST allow engineers to create, view, and update equipment
  classes, FMEA records, and maintenance strategies in a reusable library.
- **FR-002**: System MUST allow import, creation, and update of assets in a
  hierarchical structure with filters by site, area, and class.
- **FR-002a**: System MUST present assets in an expandable/collapsible tree view
  that behaves like a folder structure for navigating parent and child assets.
- **FR-003**: System MUST allow assigning one or more maintenance strategies to
  assets, including specifying variant overrides at the asset level.
- **FR-004**: System MUST generate WI documents (.docx) using the configured
  template and data stored in PostgreSQL.
- **FR-005**: System MUST provide a dashboard view summarizing key KPIs (asset
  counts, active strategies, WI generation activity) using data from the core
  tables.
- **FR-006**: System MUST support a single shared access level for all users in
  this baseline release, with no role-based feature restrictions.
- **FR-007**: System MUST process duplicate asset tags in bulk imports as
  updates (upsert behavior), and include inserted/updated/error counts in the
  import summary.
- **FR-008**: System MUST provide export-ready WI metadata (asset, strategy, WI
  identifiers) so generated documents can be referenced in the ERP system.

### Key Entities *(include if feature involves data)*

- **Equipment Class**: Represents a type of equipment and is the parent for
  FMEA records and maintenance strategies.
- **Maintenance Strategy**: Represents a set of tasks and intervals applied to
  equipment classes and assets, linked to specific WIs.
- **Asset**: Represents a physical asset with a self-referencing hierarchy and
  associated strategies.
- **Work Instruction (WI)**: Represents the header and steps for a task that
  can be generated into a Word document.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Engineers can configure strategies and assign them to at least
  10,000 assets without data loss or hierarchy corruption.
- **SC-002**: Planners can generate WI documents for selected WIs and assets
  with a successful generation rate of at least 95% (no template or data
  errors).
- **SC-003**: Users can identify asset and strategy coverage plus recent WI
  generation activity from a single dashboard view.
- **SC-004**: Initial production configuration (strategy library + asset
  hierarchy + WIs) can be completed starting from existing Excel data using the
  planned import and migration flows.

## Assumptions

- Target users (engineers, planners, technicians) have stable network access to
  the APM server.
- Initial scope is a single environment (shared network/server) for a team of
  2-5 users; multi-tenant or SaaS scaling is out of scope for this feature.
- Role-based access control is out of scope for this baseline and can be added
  in a later feature without breaking existing workflows.
- Existing Excel sources (WI_Database.xlsx and any asset lists) contain
  sufficient, reasonably clean data to seed the system, though validation and
  error reporting will be required.
- Work order planning/execution and maintenance history remain in the ERP
  system and are out of scope for this APM baseline.
