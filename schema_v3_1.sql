-- ============================================================
--  APM System — PostgreSQL Schema v3
--  Updated from Data_definitions.xlsx review
--  Changes from v2:
--    - asset table: expanded with all hierarchy fields
--    - criticality_assessment: full risk matrix model
--      (4 dimensions × likelihood/consequence/rules/final)
--    - fmea: aligned to actual column set
--    - operation: aligned to task operations sheet
--    - Added lookup/reference tables for codes
--    - Added activity_type lookup table (C1-G3 codes)
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
--  REFERENCE / LOOKUP TABLES
-- ============================================================

-- Activity type codes from FMEA RPN Scoring sheet
-- C1-C3 = Condition monitoring, R1-R7 = Repair/Restore,
-- P1-P3 = Projects, N1-N6 = NDT/Asset Integrity, G1-G3 = General
CREATE TABLE activity_type (
    code            VARCHAR(5) PRIMARY KEY,      -- e.g. C1, R2, N4
    category        VARCHAR(50) NOT NULL,        -- Observing / Repair / Projects / NDT / General
    description     VARCHAR(100) NOT NULL        -- e.g. Inspection, Service, NDT Inspection
);

INSERT INTO activity_type VALUES
('C1','Observing Condition','Inspection'),
('C2','Observing Condition','Condition Monitoring'),
('C3','Observing Condition','Test'),
('R1','Repair/Restore','Service'),
('R2','Repair/Restore','Overhaul'),
('R3','Repair/Restore','Refurbishment'),
('R4','Repair/Restore','Calibrate'),
('R5','Repair/Restore','Reset'),
('R6','Repair/Restore','Repair'),
('R7','Repair/Restore','Replace'),
('P1','Projects/Modify','Modification Minor'),
('P2','Projects/Modify','Capital Project'),
('P3','Projects/Modify','Major Project'),
('N1','NDT/Asset Integrity','PIS Commissioning Inspection'),
('N2','NDT/Asset Integrity','PIS Thorough Inspection'),
('N3','NDT/Asset Integrity','PIS Review External'),
('N4','NDT/Asset Integrity','PIS NDT Inspection'),
('N5','NDT/Asset Integrity','PIS CUI Inspection'),
('N6','NDT/Asset Integrity','PIS Retest PRD'),
('G1','Operational/General','Clean'),
('G2','Operational/General','Operate'),
('G3','Operational/General','General');

-- Trade / resource codes
CREATE TABLE trade (
    code            VARCHAR(20) PRIMARY KEY,
    description     VARCHAR(100) NOT NULL
);

INSERT INTO trade VALUES
('MECH-FITTER',   'Mechanical Fitter'),
('MECH-TA',       'Mechanical Trade Assistant'),
('EI-ELEC',       'Electrician'),
('EI-ELEC-HV',    'Electrician HV'),
('EI-INST',       'Instrumentation'),
('OPERATOR',      'Operator'),
('CIVIL',         'Civil'),
('INSPECTOR',     'Plant Inspector'),
('ENGINEER',      'Engineer'),
('RIGGER',        'Rigger');

-- ============================================================
--  LAYER 1: EQUIPMENT CLASSIFICATION
-- ============================================================

CREATE TABLE equipment_class (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    class_name      VARCHAR(100) NOT NULL,       -- e.g. "Control Valve"
    class_code      VARCHAR(20),                 -- e.g. "PMP", "MOT", "VLV"  (from Asset Class col)
    object_type     VARCHAR(20),                 -- e.g. "MPMC", "EMOT"       (from Object Type col)
    type            VARCHAR(100),                -- e.g. "Centrifugal"
    subclass        VARCHAR(100),                -- e.g. "High Pressure"
    variant         VARCHAR(100),                -- e.g. "Coastal/Marine exposed"
    description     TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (class_name, type, subclass, variant)
);

-- ============================================================
--  LAYER 2: FMEA LIBRARY
--  Columns aligned to your FMEA sheet exactly
-- ============================================================

CREATE TABLE fmea (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    class_id                UUID NOT NULL REFERENCES equipment_class(id) ON DELETE CASCADE,
    -- Component being analysed (e.g. "Valve Body", "Trim")
    component               VARCHAR(255),
    -- Operating context (e.g. "Exposed, close to ocean <500m")
    operating_context       TEXT,
    -- RCM Function/Failure chain
    asset_function          TEXT NOT NULL,       -- "To contain the process fluid..."
    functional_failure      TEXT,                -- "Loss of ability to contain pressure..."
    failure_mode            VARCHAR(255) NOT NULL,-- "External leakage"
    failure_mechanism       TEXT,                -- "Corrosion"
    failure_cause           TEXT,                -- "Salt-laden atmosphere..."
    failure_effect          TEXT,                -- "Environmental contamination..."
    -- Detection
    detectability_type      VARCHAR(50) CHECK (detectability_type IN
                                ('Detectable',
                                 'Detectable with Anciliary Equipment',
                                 'Hidden')),
    -- Consequence
    consequence_type        VARCHAR(50),         -- Safety / Environmental / Compliance / Production
    -- RPN scoring (1-5 scale per your scoring sheet)
    consequence_score       SMALLINT CHECK (consequence_score BETWEEN 1 AND 5),
    likelihood_score        SMALLINT CHECK (likelihood_score BETWEEN 1 AND 5),
    detectability_score     SMALLINT CHECK (detectability_score BETWEEN 1 AND 5),
    rpn                     SMALLINT GENERATED ALWAYS AS
                                (consequence_score * likelihood_score * detectability_score) STORED,
    -- Recommended task from FMEA
    task_description        TEXT,                -- "External visual inspection of..."
    task_acceptable_conditions TEXT,             -- "Valve body free from visible leakage..."
    corrective_action       TEXT,                -- "Raise a Work Request for repairs"
    activity_type_code      VARCHAR(5) REFERENCES activity_type(code),
    -- Task scheduling fields (from FMEA sheet — these feed into task operations)
    task_list_id            VARCHAR(50),         -- reference to task list
    interval_value          INTEGER,
    interval_unit           VARCHAR(20),         -- Hours / Days / Months / Years
    trade_code              VARCHAR(20) REFERENCES trade(code),
    manning                 NUMERIC(4,1),        -- number of people
    duration_hrs            NUMERIC(6,2),
    -- References
    location_photo          TEXT,
    documents               TEXT,
    safety_hazards_ppe      TEXT,
    resources_tools         TEXT,
    notes                   TEXT,
    created_at              TIMESTAMPTZ DEFAULT NOW()
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
    discipline      VARCHAR(50),
    is_active       BOOLEAN DEFAULT TRUE,
    notes           TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
--  LAYER 4: TASK LISTS
--  Aligned to your "Task Header" sheet
-- ============================================================

CREATE TABLE task_list (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    strategy_id             UUID REFERENCES maintenance_strategy(id) ON DELETE SET NULL,
    -- From Task Header sheet
    equipment_floc          VARCHAR(100),        -- Equipment Number / FLOC (asset this TL was built for)
    task_list_ref           VARCHAR(50) UNIQUE,  -- Task List ID e.g. TL0001 (unique natural key)
    task_list_name          VARCHAR(255) NOT NULL,-- TL Description (e.g. "Pump Sewerage Service")
    system_condition        VARCHAR(100),        -- System Condition (e.g. online/offline)
    scope                   TEXT,
    -- Scheduling
    interval_type           VARCHAR(20) CHECK (interval_type IN
                                ('calendar','runtime','condition','on-failure','shutdown')),
    interval_value          INTEGER,
    interval_unit           VARCHAR(20),         -- months/hours/years
    estimated_duration_hrs  NUMERIC(6,2),
    shutdown_required       BOOLEAN DEFAULT FALSE,
    created_at              TIMESTAMPTZ DEFAULT NOW(),
    updated_at              TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
--  LAYER 5: OPERATIONS
--  Aligned to your "Task Operations" sheet exactly
-- ============================================================

CREATE TABLE operation (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_list_id            UUID NOT NULL REFERENCES task_list(id) ON DELETE CASCADE,
    -- From Task Operations sheet
    operation_number        VARCHAR(10) NOT NULL,-- "0010", "0020" etc
    work_centre             VARCHAR(20),         -- e.g. XGBS01, XMMF01
    operation_description   VARCHAR(255) NOT NULL,
    operation_long_text     TEXT,                -- full detailed instructions
    -- Resource
    special_skills          VARCHAR(50),         -- trade code e.g. AXGBS, AXMMF
    qty_resource            NUMERIC(5,1),
    work_value              NUMERIC(8,2),        -- planned work quantity
    work_unit               VARCHAR(10),         -- usually HUR
    duration                NUMERIC(8,2),
    duration_unit           VARCHAR(10),         -- HUR / DAY etc
    -- Flags
    safety_critical         BOOLEAN DEFAULT FALSE,
    compliance              BOOLEAN DEFAULT FALSE,
    compliance_standard     VARCHAR(100),        -- e.g. "Fire", "CO"
    -- FMEA traceability
    fmea_id                 UUID REFERENCES fmea(id),
    -- Sequence within task list
    sequence                SMALLINT,
    notes                   TEXT,
    created_at              TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (task_list_id, operation_number)
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
-- ============================================================

CREATE TABLE operation_pmi (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    operation_id    UUID NOT NULL REFERENCES operation(id) ON DELETE CASCADE,
    wi_no           VARCHAR(50) NOT NULL REFERENCES wi_header(wi_no),
    pmi_role        VARCHAR(100),               -- Primary / Safety Reference / Supplementary
    sequence        SMALLINT DEFAULT 1,
    is_mandatory    BOOLEAN DEFAULT TRUE,
    notes           TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (operation_id, wi_no)
);

-- ============================================================
--  LAYER 8: ASSET HIERARCHY
--  Aligned to your "hierarchy" sheet exactly
-- ============================================================

CREATE TABLE asset (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- Core identity (from hierarchy sheet)
    asset_tag           VARCHAR(100) UNIQUE NOT NULL,  -- Equipment Number e.g. 1150P0052
    asset_name          VARCHAR(255) NOT NULL,          -- Description
    class_id            UUID REFERENCES equipment_class(id),
    -- Hierarchy
    parent_asset_tag    VARCHAR(100) REFERENCES asset(asset_tag),
    -- Classification codes (from hierarchy sheet)
    asset_class_code    VARCHAR(20),            -- PMP, MOT, VLV etc
    object_type         VARCHAR(20),            -- MPMC, EMOT etc
    -- Location
    site                VARCHAR(100),           -- Plant
    area                VARCHAR(100),           -- Location / Block
    location_detail     VARCHAR(255),           -- e.g. "AAN Block 1 Level 2"
    -- Operational
    discipline          VARCHAR(50),            -- Electrical / Mechanical / Instrument
    asset_department    VARCHAR(100),           -- e.g. Ammonia
    cost_centre         VARCHAR(50),
    work_centre         VARCHAR(20),            -- e.g. MECH02, ELEC01
    planner_group       VARCHAR(20),            -- e.g. M02, E01
    process_code        VARCHAR(50),            -- e.g. Water, Elec
    -- Equipment details
    manufacturer        VARCHAR(100),           -- Asset Make
    model               VARCHAR(100),           -- Asset Model
    serial_number       VARCHAR(100),
    install_date        DATE,
    -- Special classifications (flags from hierarchy sheet)
    safety_critical     BOOLEAN DEFAULT FALSE,  -- SC code
    compliance_flag     BOOLEAN DEFAULT FALSE,  -- CO code
    environmental_flag  BOOLEAN DEFAULT FALSE,  -- ENV code
    eeha_flag           BOOLEAN DEFAULT FALSE,  -- EEHA (Explosive/Hazardous Area)
    -- Criticality (overall result — detail in criticality_assessment)
    criticality_abc     VARCHAR(5),             -- A / B / C / D / E
    -- ERP reference
    sap_equipment_no    VARCHAR(50),
    jde_equipment_no    VARCHAR(50),
    -- Status
    asset_status        VARCHAR(50) DEFAULT 'Operational',  -- EQ_Stat
    long_text           TEXT,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
--  LAYER 9: CRITICALITY ASSESSMENT
--  Aligned to your criticality sheet — 4 dimensions,
--  each scored independently with likelihood × consequence
--  then rule-adjusted to produce a final rating
-- ============================================================

CREATE TABLE criticality_assessment (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    asset_id                UUID NOT NULL REFERENCES asset(id) ON DELETE CASCADE,
    assessment_date         DATE DEFAULT CURRENT_DATE,
    assessed_by             VARCHAR(100),
    review_source           VARCHAR(100),       -- e.g. "JDE Data 20251105"
    review_status           VARCHAR(50),        -- e.g. "2 Assessed by Consultant"

    -- Special flags (boolean columns from criticality sheet)
    flag_co                 BOOLEAN DEFAULT FALSE,   -- Compliance Obligation
    flag_sc                 BOOLEAN DEFAULT FALSE,   -- Safety Critical
    flag_bar                BOOLEAN DEFAULT FALSE,   -- Barrier
    flag_sif                BOOLEAN DEFAULT FALSE,   -- Safety Instrumented Function
    flag_bms                BOOLEAN DEFAULT FALSE,   -- Burner Management System
    flag_haz                BOOLEAN DEFAULT FALSE,   -- Hazardous
    flag_volt               BOOLEAN DEFAULT FALSE,   -- High Voltage
    flag_gas                BOOLEAN DEFAULT FALSE,   -- Gas
    flag_eeha               BOOLEAN DEFAULT FALSE,   -- Explosive/Hazardous Area
    flag_mech               BOOLEAN DEFAULT FALSE,   -- Mechanical
    flag_elect              BOOLEAN DEFAULT FALSE,   -- Electrical
    flag_env                BOOLEAN DEFAULT FALSE,   -- Environmental

    -- Health & Safety dimension
    hs_likelihood           VARCHAR(5),              -- A/B/C/D/E
    hs_consequence          SMALLINT CHECK (hs_consequence BETWEEN 1 AND 5),
    hs_crit_assessed        VARCHAR(20),             -- Low/Moderate/High/Extreme
    hs_crit_rules           VARCHAR(20),             -- rule-adjusted rating
    hs_crit_final_num       SMALLINT,                -- numeric final

    -- Environmental dimension
    env_likelihood          VARCHAR(5),
    env_consequence         SMALLINT CHECK (env_consequence BETWEEN 1 AND 5),
    env_crit_assessed       VARCHAR(20),
    env_crit_rules          VARCHAR(20),
    env_crit_final_num      SMALLINT,

    -- Compliance/Operations dimension
    co_likelihood           VARCHAR(5),
    co_consequence          SMALLINT CHECK (co_consequence BETWEEN 1 AND 5),
    co_crit_assessed        VARCHAR(20),
    co_crit_rules           VARCHAR(20),
    co_crit_final_num       SMALLINT,

    -- Production dimension
    prod_likelihood         VARCHAR(5),
    prod_consequence        SMALLINT CHECK (prod_consequence BETWEEN 1 AND 5),
    prod_crit_assessed      VARCHAR(20),
    prod_crit_rules         VARCHAR(20),
    prod_crit_final_num     SMALLINT,

    -- Overall result
    highest_criticality     VARCHAR(20),             -- worst of all 4 dimensions
    overall_abc             VARCHAR(5),              -- A/B/C/D/E — overall criticality rating
    jde_crit_equivalent     VARCHAR(20),             -- mapping back to JDE/ERP criticality

    comments                TEXT,
    created_at              TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
--  LAYER 10: STRATEGY APPLICATION & VARIANTS
-- ============================================================

CREATE TABLE asset_strategy (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    asset_id        UUID NOT NULL REFERENCES asset(id) ON DELETE CASCADE,
    strategy_id     UUID NOT NULL REFERENCES maintenance_strategy(id),
    variant_name    VARCHAR(255),
    variant_notes   TEXT,
    is_active       BOOLEAN DEFAULT TRUE,
    assigned_date   DATE DEFAULT CURRENT_DATE,
    assigned_by     VARCHAR(100),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (asset_id, strategy_id)
);

CREATE TABLE strategy_variant_override (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    asset_strategy_id   UUID NOT NULL REFERENCES asset_strategy(id) ON DELETE CASCADE,
    override_level      VARCHAR(20) CHECK (override_level IN
                            ('task_list','operation','wi','step')),
    target_id           UUID,
    override_field      VARCHAR(100) NOT NULL,
    override_value      TEXT NOT NULL,
    override_reason     TEXT,
    created_at          TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
--  LAYER 11: WORK ORDERS
-- ============================================================

CREATE TABLE work_order (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    wo_number           VARCHAR(50) UNIQUE,
    asset_id            UUID NOT NULL REFERENCES asset(id),
    asset_strategy_id   UUID REFERENCES asset_strategy(id),
    task_list_id        UUID REFERENCES task_list(id),
    wo_type             VARCHAR(50) CHECK (wo_type IN
                            ('preventive','corrective','inspection',
                             'shutdown','predictive')),
    scheduled_date      DATE,
    completed_date      DATE,
    status              VARCHAR(30) DEFAULT 'scheduled' CHECK (status IN
                            ('scheduled','in-progress','completed',
                             'cancelled','deferred')),
    technician          VARCHAR(100),
    estimated_hours     NUMERIC(5,1),
    actual_hours        NUMERIC(5,1),
    findings            TEXT,
    actions_taken       TEXT,
    sap_notification    VARCHAR(50),
    sap_order           VARCHAR(50),
    jde_mwo             VARCHAR(50),            -- JDE maintenance work order ref
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE work_order_operation (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    wo_id               UUID NOT NULL REFERENCES work_order(id) ON DELETE CASCADE,
    operation_id        UUID REFERENCES operation(id),
    sequence            SMALLINT,
    status              VARCHAR(20) DEFAULT 'pending' CHECK (status IN
                            ('pending','in-progress','completed','skipped')),
    actual_duration_hrs NUMERIC(5,1),
    technician          VARCHAR(100),
    findings            TEXT,
    completed_at        TIMESTAMPTZ
);

-- ============================================================
--  INDEXES
-- ============================================================

CREATE INDEX idx_asset_parent           ON asset(parent_asset_tag);
CREATE INDEX idx_asset_class            ON asset(class_id);
CREATE INDEX idx_asset_site             ON asset(site, area);
CREATE INDEX idx_asset_sap              ON asset(sap_equipment_no);
CREATE INDEX idx_asset_jde              ON asset(jde_equipment_no);
CREATE INDEX idx_asset_criticality      ON asset(criticality_abc);
CREATE INDEX idx_criticality_asset      ON criticality_assessment(asset_id);
CREATE INDEX idx_fmea_class             ON fmea(class_id);
CREATE INDEX idx_fmea_rpn               ON fmea(rpn);
CREATE INDEX idx_strategy_class         ON maintenance_strategy(class_id);
CREATE INDEX idx_task_list_strategy     ON task_list(strategy_id);
CREATE INDEX idx_task_list_floc         ON task_list(equipment_floc);
CREATE INDEX idx_task_list_ref          ON task_list(task_list_ref);
CREATE INDEX idx_operation_task_list    ON operation(task_list_id, sequence);
CREATE INDEX idx_operation_pmi          ON operation_pmi(operation_id);
CREATE INDEX idx_operation_pmi_wi       ON operation_pmi(wi_no);
CREATE INDEX idx_asset_strategy         ON asset_strategy(asset_id, strategy_id);
CREATE INDEX idx_work_order_asset       ON work_order(asset_id);
CREATE INDEX idx_work_order_status      ON work_order(status, scheduled_date);
CREATE INDEX idx_wi_steps_wi            ON wi_steps(wi_no, section, step_no);

-- ============================================================
--  VIEWS
-- ============================================================

-- Full strategy chain: class → strategy → task list → operations → PMIs
CREATE VIEW v_strategy_operations AS
SELECT
    ec.class_name,
    ec.type             AS equipment_type,
    ec.subclass,
    ms.strategy_name,
    tl.task_list_name,
    tl.interval_value,
    tl.interval_unit,
    op.operation_number,
    op.operation_description,
    op.work_centre,
    op.qty_resource,
    op.duration,
    op.duration_unit,
    op.safety_critical,
    op.compliance_standard,
    wh.wi_no,
    wh.document_title   AS pmi_title,
    opm.pmi_role,
    opm.is_mandatory
FROM maintenance_strategy ms
JOIN equipment_class ec     ON ms.class_id       = ec.id
JOIN task_list tl           ON tl.strategy_id    = ms.id
JOIN operation op           ON op.task_list_id   = tl.id
LEFT JOIN operation_pmi opm ON opm.operation_id  = op.id
LEFT JOIN wi_header wh      ON wh.wi_no          = opm.wi_no
ORDER BY ec.class_name, ms.strategy_name, tl.task_list_name, op.sequence;

-- Asset with full criticality summary
CREATE VIEW v_asset_criticality AS
SELECT
    a.asset_tag,
    a.asset_name,
    a.site,
    a.area,
    a.discipline,
    a.asset_status,
    a.criticality_abc,
    a.safety_critical,
    a.compliance_flag,
    a.eeha_flag,
    ec.class_name,
    ca.overall_abc,
    ca.hs_crit_final_num,
    ca.env_crit_final_num,
    ca.co_crit_final_num,
    ca.prod_crit_final_num,
    ca.highest_criticality,
    ca.flag_sif,
    ca.flag_bms,
    ca.assessment_date
FROM asset a
LEFT JOIN equipment_class ec        ON a.class_id    = ec.id
LEFT JOIN criticality_assessment ca ON ca.asset_id   = a.id;

-- Upcoming work orders
CREATE VIEW v_upcoming_work_orders AS
SELECT
    wo.wo_number,
    wo.scheduled_date,
    wo.status,
    a.asset_tag,
    a.asset_name,
    a.site,
    a.criticality_abc,
    ms.strategy_name,
    tl.task_list_name,
    wo.estimated_hours
FROM work_order wo
JOIN asset a                ON wo.asset_id          = a.id
JOIN asset_strategy ast     ON wo.asset_strategy_id = ast.id
JOIN maintenance_strategy ms ON ast.strategy_id     = ms.id
LEFT JOIN task_list tl      ON wo.task_list_id      = tl.id
WHERE wo.scheduled_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '30 days'
  AND wo.status NOT IN ('completed','cancelled')
ORDER BY a.criticality_abc, wo.scheduled_date;
