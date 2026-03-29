-- ============================================================
--  APM System — PostgreSQL Schema v2
--  Updated: Task List + Operations + PMI many-to-many
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
--  LAYER 1: EQUIPMENT CLASSIFICATION
-- ============================================================

CREATE TABLE equipment_class (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    class_name      VARCHAR(100) NOT NULL,       -- e.g. "Pump"
    type            VARCHAR(100),                -- e.g. "Centrifugal"
    subclass        VARCHAR(100),                -- e.g. "High Pressure"
    description     TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (class_name, type, subclass)
);

-- ============================================================
--  LAYER 2: FMEA LIBRARY
--  (columns left broad — will refine after seeing your Excel)
-- ============================================================

CREATE TABLE fmea (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    class_id            UUID NOT NULL REFERENCES equipment_class(id) ON DELETE CASCADE,
    -- Function / Failure
    asset_function      VARCHAR(255) NOT NULL,   -- what it's supposed to do
    functional_failure  VARCHAR(255),            -- how function is lost
    failure_mode        VARCHAR(255) NOT NULL,   -- specific failure mechanism
    failure_effect      TEXT,                    -- consequence of failure
    failure_cause       TEXT,                    -- root cause
    failure_mechanism   VARCHAR(255),            -- wear, fatigue, corrosion etc
    -- RPN scoring
    severity            SMALLINT CHECK (severity BETWEEN 1 AND 10),
    occurrence          SMALLINT CHECK (occurrence BETWEEN 1 AND 10),
    detectability       SMALLINT CHECK (detectability BETWEEN 1 AND 10),
    rpn                 SMALLINT GENERATED ALWAYS AS
                            (severity * occurrence * detectability) STORED,
    -- Consequence classification (common in APM)
    consequence_category VARCHAR(50),            -- Safety / Environmental / Production / Asset
    maintenance_type    VARCHAR(50),             -- Preventive / Predictive / Corrective / Run-to-fail
    -- Links back to what task addresses this failure mode
    -- (populated once task lists are built)
    notes               TEXT,
    created_at          TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
--  LAYER 3: MAINTENANCE STRATEGY
-- ============================================================

CREATE TABLE maintenance_strategy (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    class_id        UUID NOT NULL REFERENCES equipment_class(id) ON DELETE CASCADE,
    strategy_name   VARCHAR(255) NOT NULL,
    strategy_type   VARCHAR(50) CHECK (strategy_type IN
                        ('time-based','condition-based','predictive',
                         'run-to-fail','shutdown-based')),
    discipline      VARCHAR(50),                 -- mechanical / electrical / instrument / civil
    is_active       BOOLEAN DEFAULT TRUE,
    notes           TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
--  LAYER 4: TASK LISTS
--  One strategy can have multiple task lists
--  (e.g. "Annual Inspection", "5-Year Overhaul" both under same strategy)
-- ============================================================

CREATE TABLE task_list (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    strategy_id     UUID NOT NULL REFERENCES maintenance_strategy(id) ON DELETE CASCADE,
    task_list_name  VARCHAR(255) NOT NULL,       -- e.g. "Pump Inspection — Annual"
    scope           TEXT,                        -- high-level description of what's covered
    interval_type   VARCHAR(20) CHECK (interval_type IN
                        ('calendar','runtime','condition','on-failure','shutdown')),
    interval_value  INTEGER,                     -- e.g. 12
    interval_unit   VARCHAR(20),                 -- 'months','hours','starts','years'
    estimated_duration_hrs NUMERIC(6,2),         -- total estimated job duration
    shutdown_required BOOLEAN DEFAULT FALSE,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
--  LAYER 5: OPERATIONS
--  Each task list has multiple ordered operations
-- ============================================================

CREATE TABLE operation (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_list_id        UUID NOT NULL REFERENCES task_list(id) ON DELETE CASCADE,
    sequence            SMALLINT NOT NULL,       -- order within the task list
    operation_no        VARCHAR(20),             -- e.g. "0010", "0020" (SAP style)
    operation_name      VARCHAR(255) NOT NULL,   -- e.g. "Isolate pump"
    operation_description TEXT,                  -- brief what/how
    resource_type       VARCHAR(50) CHECK (resource_type IN
                            ('labour','material','contractor','equipment','tool')),
    resource_name       VARCHAR(100),            -- e.g. "Mechanical Fitter", "Grease Gun"
    resource_qty        NUMERIC(8,2),            -- quantity
    resource_unit       VARCHAR(20),             -- 'hrs','each','kg','L'
    duration_hrs        NUMERIC(6,2),            -- planned duration
    -- Flags
    requires_isolation  BOOLEAN DEFAULT FALSE,
    requires_permit     BOOLEAN DEFAULT FALSE,
    -- FMEA traceability — which failure mode does this operation address?
    fmea_id             UUID REFERENCES fmea(id),
    notes               TEXT,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (task_list_id, sequence)
);

-- ============================================================
--  LAYER 6: PMI / WORK INSTRUCTIONS
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
    section                 VARCHAR(50) CHECK (section IN
                                ('Pre-start','LOTO','Task execution','Testing')),
    step_instruction        TEXT NOT NULL,
    step_keypoints_hazards  TEXT,
    step_check              VARCHAR(10) DEFAULT '☐',
    created_at              TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (wi_no, step_no, section)
);

-- ============================================================
--  LAYER 7: OPERATION ↔ PMI  (many-to-many)
--  An operation can reference multiple PMIs
--  A PMI can be used across multiple operations
-- ============================================================

CREATE TABLE operation_pmi (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    operation_id    UUID NOT NULL REFERENCES operation(id) ON DELETE CASCADE,
    wi_no           VARCHAR(50) NOT NULL REFERENCES wi_header(wi_no),
    -- Context for why this PMI applies to this operation
    pmi_role        VARCHAR(100),               -- e.g. "Primary WI", "Safety Reference", "Supplementary"
    sequence        SMALLINT DEFAULT 1,         -- if multiple PMIs, what order to follow
    is_mandatory    BOOLEAN DEFAULT TRUE,
    notes           TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (operation_id, wi_no)
);

-- ============================================================
--  LAYER 8: ASSET HIERARCHY
-- ============================================================

CREATE TABLE asset (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    asset_tag           VARCHAR(100) UNIQUE NOT NULL,
    asset_name          VARCHAR(255) NOT NULL,
    class_id            UUID REFERENCES equipment_class(id),
    parent_asset_tag    VARCHAR(100) REFERENCES asset(asset_tag),  -- self-ref hierarchy
    site                VARCHAR(100),
    area                VARCHAR(100),
    asset_status        VARCHAR(50) DEFAULT 'Operational',
    criticality         VARCHAR(5) CHECK (criticality IN ('A','B','C','D')),
    install_date        DATE,
    manufacturer        VARCHAR(100),
    model               VARCHAR(100),
    serial_number       VARCHAR(100),
    sap_equipment_no    VARCHAR(50),
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
--  LAYER 9: STRATEGY APPLICATION & VARIANTS
-- ============================================================

-- Assigns a strategy to a specific asset
CREATE TABLE asset_strategy (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    asset_id        UUID NOT NULL REFERENCES asset(id) ON DELETE CASCADE,
    strategy_id     UUID NOT NULL REFERENCES maintenance_strategy(id),
    variant_name    VARCHAR(255),               -- e.g. "High Pressure BFW Variant"
    variant_notes   TEXT,
    is_active       BOOLEAN DEFAULT TRUE,
    assigned_date   DATE DEFAULT CURRENT_DATE,
    assigned_by     VARCHAR(100),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (asset_id, strategy_id)
);

-- Field-level overrides for a specific asset's variant
-- e.g. different interval, different resource, additional step
CREATE TABLE strategy_variant_override (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    asset_strategy_id   UUID NOT NULL REFERENCES asset_strategy(id) ON DELETE CASCADE,
    -- What is being overridden
    override_level      VARCHAR(20) CHECK (override_level IN
                            ('task_list','operation','wi','step')),
    target_id           UUID,                   -- id of the task_list / operation / wi being overridden
    override_field      VARCHAR(100) NOT NULL,  -- e.g. 'interval_value','duration_hrs','step_instruction'
    override_value      TEXT NOT NULL,
    override_reason     TEXT,
    created_at          TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
--  LAYER 10: WORK ORDERS (EXECUTION)
-- ============================================================

CREATE TABLE work_order (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    wo_number           VARCHAR(50) UNIQUE,
    asset_id            UUID NOT NULL REFERENCES asset(id),
    asset_strategy_id   UUID REFERENCES asset_strategy(id),
    task_list_id        UUID REFERENCES task_list(id),
    wo_type             VARCHAR(50) CHECK (wo_type IN
                            ('preventive','corrective','inspection','shutdown','predictive')),
    scheduled_date      DATE,
    completed_date      DATE,
    status              VARCHAR(30) DEFAULT 'scheduled' CHECK (status IN
                            ('scheduled','in-progress','completed','cancelled','deferred')),
    technician          VARCHAR(100),
    estimated_hours     NUMERIC(5,1),
    actual_hours        NUMERIC(5,1),
    findings            TEXT,
    actions_taken       TEXT,
    sap_notification    VARCHAR(50),
    sap_order           VARCHAR(50),
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

-- Work order line items — one per operation completed
CREATE TABLE work_order_operation (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    wo_id           UUID NOT NULL REFERENCES work_order(id) ON DELETE CASCADE,
    operation_id    UUID REFERENCES operation(id),
    sequence        SMALLINT,
    status          VARCHAR(20) DEFAULT 'pending' CHECK (status IN
                        ('pending','in-progress','completed','skipped')),
    actual_duration_hrs NUMERIC(5,1),
    technician      VARCHAR(100),
    findings        TEXT,
    completed_at    TIMESTAMPTZ
);

-- ============================================================
--  INDEXES
-- ============================================================

CREATE INDEX idx_asset_parent         ON asset(parent_asset_tag);
CREATE INDEX idx_asset_class          ON asset(class_id);
CREATE INDEX idx_asset_site           ON asset(site, area);
CREATE INDEX idx_asset_sap            ON asset(sap_equipment_no);
CREATE INDEX idx_fmea_class           ON fmea(class_id);
CREATE INDEX idx_strategy_class       ON maintenance_strategy(class_id);
CREATE INDEX idx_task_list_strategy   ON task_list(strategy_id);
CREATE INDEX idx_operation_task_list  ON operation(task_list_id, sequence);
CREATE INDEX idx_operation_pmi        ON operation_pmi(operation_id);
CREATE INDEX idx_operation_pmi_wi     ON operation_pmi(wi_no);
CREATE INDEX idx_asset_strategy       ON asset_strategy(asset_id, strategy_id);
CREATE INDEX idx_work_order_asset     ON work_order(asset_id);
CREATE INDEX idx_work_order_status    ON work_order(status, scheduled_date);
CREATE INDEX idx_wi_steps_wi          ON wi_steps(wi_no, section, step_no);

-- ============================================================
--  USEFUL VIEWS
-- ============================================================

-- Full strategy breakdown: strategy → task list → operations → PMIs
CREATE VIEW v_strategy_operations AS
SELECT
    ec.class_name,
    ec.type             AS equipment_type,
    ms.strategy_name,
    tl.task_list_name,
    tl.interval_value,
    tl.interval_unit,
    op.sequence,
    op.operation_no,
    op.operation_name,
    op.resource_type,
    op.resource_name,
    op.duration_hrs,
    wh.wi_no,
    wh.document_title   AS pmi_title,
    opm.pmi_role,
    opm.is_mandatory
FROM maintenance_strategy ms
JOIN equipment_class ec     ON ms.class_id      = ec.id
JOIN task_list tl           ON tl.strategy_id   = ms.id
JOIN operation op           ON op.task_list_id  = tl.id
LEFT JOIN operation_pmi opm ON opm.operation_id = op.id
LEFT JOIN wi_header wh      ON wh.wi_no         = opm.wi_no
ORDER BY ec.class_name, ms.strategy_name, tl.task_list_name, op.sequence;

-- Asset hierarchy with class and active strategy count
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
    ec.type             AS equipment_type,
    COUNT(ast.id)       AS active_strategies
FROM asset a
LEFT JOIN equipment_class ec    ON a.class_id  = ec.id
LEFT JOIN asset_strategy ast    ON ast.asset_id = a.id AND ast.is_active = TRUE
GROUP BY a.id, ec.class_name, ec.type;

-- Upcoming work orders (next 30 days)
CREATE VIEW v_upcoming_work_orders AS
SELECT
    wo.wo_number,
    wo.scheduled_date,
    wo.status,
    a.asset_tag,
    a.asset_name,
    a.site,
    ms.strategy_name,
    tl.task_list_name,
    wo.estimated_hours
FROM work_order wo
JOIN asset a                ON wo.asset_id       = a.id
JOIN asset_strategy ast     ON wo.asset_strategy_id = ast.id
JOIN maintenance_strategy ms ON ast.strategy_id  = ms.id
LEFT JOIN task_list tl      ON wo.task_list_id   = tl.id
WHERE wo.scheduled_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '30 days'
  AND wo.status NOT IN ('completed','cancelled')
ORDER BY wo.scheduled_date;
