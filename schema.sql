-- ============================================================
--  APM System — PostgreSQL Schema
--  Version 1.0
-- ============================================================

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
--  LAYER 1: MAINTENANCE STRATEGY LIBRARY
-- ============================================================

CREATE TABLE equipment_class (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    class_name      VARCHAR(100) NOT NULL,          -- e.g. "Pump"
    type            VARCHAR(100),                   -- e.g. "Centrifugal"
    subclass        VARCHAR(100),                   -- e.g. "High Pressure"
    description     TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (class_name, type, subclass)
);

CREATE TABLE fmea (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    class_id        UUID NOT NULL REFERENCES equipment_class(id) ON DELETE CASCADE,
    function        VARCHAR(255) NOT NULL,          -- what the asset is supposed to do
    failure_mode    VARCHAR(255) NOT NULL,          -- how it can fail
    failure_effect  TEXT,                           -- what happens when it fails
    failure_cause   TEXT,                           -- why it fails
    severity        SMALLINT CHECK (severity BETWEEN 1 AND 10),
    occurrence      SMALLINT CHECK (occurrence BETWEEN 1 AND 10),
    detectability   SMALLINT CHECK (detectability BETWEEN 1 AND 10),
    rpn             SMALLINT GENERATED ALWAYS AS (severity * occurrence * detectability) STORED,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE maintenance_strategy (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    class_id        UUID NOT NULL REFERENCES equipment_class(id) ON DELETE CASCADE,
    strategy_name   VARCHAR(255) NOT NULL,
    interval_type   VARCHAR(20) CHECK (interval_type IN ('calendar','runtime','condition','on-failure')),
    interval_value  INTEGER,                        -- e.g. 90 (days), 500 (hours)
    interval_unit   VARCHAR(20),                    -- 'days','hours','starts'
    discipline      VARCHAR(50),                    -- 'mechanical','electrical','instrument'
    scope           TEXT,
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Links a strategy to one or more WIs in sequence
CREATE TABLE strategy_wi_link (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    strategy_id     UUID NOT NULL REFERENCES maintenance_strategy(id) ON DELETE CASCADE,
    wi_no           VARCHAR(50) NOT NULL REFERENCES wi_header(wi_no),
    sequence        SMALLINT NOT NULL DEFAULT 1,    -- order within the strategy
    task_type       VARCHAR(50),                    -- 'inspection','replacement','calibration'
    UNIQUE (strategy_id, wi_no)
);

-- ============================================================
--  LAYER 2: WORK INSTRUCTION DOCUMENTS
-- ============================================================

CREATE TABLE wi_header (
    wi_no                       VARCHAR(50) PRIMARY KEY,
    document_title              VARCHAR(255) NOT NULL,
    version                     VARCHAR(20) DEFAULT '1.0',
    effective_date              DATE,
    review_date                 DATE,
    file_name                   VARCHAR(255),
    site_area                   VARCHAR(100),
    equipment_asset             VARCHAR(100),
    asset_tag                   VARCHAR(100),
    department                  VARCHAR(100),
    prepared_by                 VARCHAR(100),
    approved_by                 VARCHAR(100),
    asset_status                VARCHAR(50),
    scope                       TEXT,
    purpose                     TEXT,
    references_definitions      TEXT,
    notes                       TEXT,
    safety_risk_controls        TEXT,
    prestart_checklist          TEXT,
    isolation_shutdown_loto     TEXT,
    testing_return_to_service   TEXT,
    revision_history            TEXT,
    generate                    VARCHAR(3) DEFAULT 'YES',
    created_at                  TIMESTAMPTZ DEFAULT NOW(),
    updated_at                  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE wi_steps (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    wi_no                   VARCHAR(50) NOT NULL REFERENCES wi_header(wi_no) ON DELETE CASCADE,
    step_no                 SMALLINT NOT NULL,
    section                 VARCHAR(50) CHECK (section IN ('Pre-start','LOTO','Task execution','Testing')),
    step_instruction        TEXT NOT NULL,
    step_keypoints_hazards  TEXT,
    step_check              VARCHAR(10) DEFAULT '☐',
    created_at              TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (wi_no, step_no, section)
);

-- ============================================================
--  LAYER 3: ASSET HIERARCHY
-- ============================================================

CREATE TABLE asset (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    asset_tag           VARCHAR(100) UNIQUE NOT NULL,   -- your asset number
    asset_name          VARCHAR(255) NOT NULL,
    class_id            UUID REFERENCES equipment_class(id),
    parent_asset_tag    VARCHAR(100) REFERENCES asset(asset_tag),  -- self-ref for hierarchy
    site                VARCHAR(100),
    area                VARCHAR(100),
    asset_status        VARCHAR(50) DEFAULT 'Operational',
    criticality         VARCHAR(20) CHECK (criticality IN ('A','B','C','D')),
    install_date        DATE,
    manufacturer        VARCHAR(100),
    model               VARCHAR(100),
    serial_number       VARCHAR(100),
    sap_equipment_no    VARCHAR(50),                    -- SAP PM link
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
--  LAYER 4: STRATEGY APPLICATION & VARIANTS
-- ============================================================

-- Assigns a strategy to a specific asset (with optional variant)
CREATE TABLE asset_strategy (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    asset_id        UUID NOT NULL REFERENCES asset(id) ON DELETE CASCADE,
    strategy_id     UUID NOT NULL REFERENCES maintenance_strategy(id),
    variant_name    VARCHAR(255),                   -- e.g. "High Pressure BFW Variant"
    variant_notes   TEXT,
    is_active       BOOLEAN DEFAULT TRUE,
    assigned_date   DATE DEFAULT CURRENT_DATE,
    assigned_by     VARCHAR(100),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (asset_id, strategy_id)
);

-- Field-level overrides for a specific asset's variant
-- e.g. override the purpose text or a specific step instruction
CREATE TABLE strategy_variant_override (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    asset_strategy_id   UUID NOT NULL REFERENCES asset_strategy(id) ON DELETE CASCADE,
    wi_no               VARCHAR(50) REFERENCES wi_header(wi_no),
    override_field      VARCHAR(100) NOT NULL,      -- e.g. 'purpose', 'step_3_instruction'
    override_value      TEXT NOT NULL,
    created_at          TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
--  LAYER 5: EXECUTION
-- ============================================================

CREATE TABLE work_order (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    wo_number           VARCHAR(50) UNIQUE,         -- your WO ref, or SAP WO number
    asset_id            UUID NOT NULL REFERENCES asset(id),
    asset_strategy_id   UUID REFERENCES asset_strategy(id),
    wi_no               VARCHAR(50) REFERENCES wi_header(wi_no),
    wo_type             VARCHAR(50) CHECK (wo_type IN ('preventive','corrective','inspection','shutdown')),
    scheduled_date      DATE,
    completed_date      DATE,
    status              VARCHAR(30) DEFAULT 'scheduled' CHECK (status IN ('scheduled','in-progress','completed','cancelled','deferred')),
    technician          VARCHAR(100),
    estimated_hours     NUMERIC(5,1),
    actual_hours        NUMERIC(5,1),
    findings            TEXT,
    actions_taken       TEXT,
    sap_notification    VARCHAR(50),                -- SAP PM notification number
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
--  INDEXES (performance for large asset hierarchies)
-- ============================================================

CREATE INDEX idx_asset_parent       ON asset(parent_asset_tag);
CREATE INDEX idx_asset_class        ON asset(class_id);
CREATE INDEX idx_asset_site         ON asset(site, area);
CREATE INDEX idx_asset_sap          ON asset(sap_equipment_no);
CREATE INDEX idx_fmea_class         ON fmea(class_id);
CREATE INDEX idx_strategy_class     ON maintenance_strategy(class_id);
CREATE INDEX idx_asset_strategy     ON asset_strategy(asset_id, strategy_id);
CREATE INDEX idx_work_order_asset   ON work_order(asset_id);
CREATE INDEX idx_work_order_status  ON work_order(status, scheduled_date);
CREATE INDEX idx_wi_steps_wi        ON wi_steps(wi_no, section, step_no);

-- ============================================================
--  VIEWS (useful queries pre-built)
-- ============================================================

-- Full asset hierarchy with class info
CREATE VIEW v_asset_hierarchy AS
SELECT
    a.asset_tag,
    a.asset_name,
    a.parent_asset_tag,
    a.site,
    a.area,
    a.asset_status,
    a.criticality,
    a.sap_equipment_no,
    ec.class_name,
    ec.type        AS equipment_type,
    ec.subclass    AS equipment_subclass
FROM asset a
LEFT JOIN equipment_class ec ON a.class_id = ec.id;

-- All active strategies per asset (with variant info)
CREATE VIEW v_asset_strategies AS
SELECT
    a.asset_tag,
    a.asset_name,
    a.site,
    ec.class_name,
    ms.strategy_name,
    ms.interval_type,
    ms.interval_value,
    ms.interval_unit,
    ast.variant_name,
    ast.is_active
FROM asset_strategy ast
JOIN asset a              ON ast.asset_id   = a.id
JOIN maintenance_strategy ms ON ast.strategy_id = ms.id
JOIN equipment_class ec   ON ms.class_id    = ec.id;

-- Work orders due in next 30 days
CREATE VIEW v_upcoming_work_orders AS
SELECT
    wo.wo_number,
    wo.scheduled_date,
    wo.status,
    a.asset_tag,
    a.asset_name,
    a.site,
    ms.strategy_name,
    wo.wi_no
FROM work_order wo
JOIN asset a              ON wo.asset_id         = a.id
JOIN asset_strategy ast   ON wo.asset_strategy_id = ast.id
JOIN maintenance_strategy ms ON ast.strategy_id    = ms.id
WHERE wo.scheduled_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '30 days'
  AND wo.status NOT IN ('completed','cancelled')
ORDER BY wo.scheduled_date;
