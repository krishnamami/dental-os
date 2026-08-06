-- ============================================================
-- dental-os — 002_dental_os_tables.sql
-- The four tables dental-os OWNS and WRITES.
-- ============================================================
-- CONTEXT.md RULE 15: dental-simulator's tables are READ-ONLY to
-- dental-os. These four are the only things this repo writes.
--
-- ── Different DATABASE, same instance ───────────────────────
-- These live in the `dental_os` database, NOT in `dental`. Same RDS
-- instance, separate database, so a dental-os migration can never
-- alter a dental-simulator table and a `\dt` in either database shows
-- only that side's tables. The two are reached through two different
-- pools and two different env vars:
--
--   DATABASE_URL            -> dental      (read-only, dental_app)
--   DENTAL_OS_DATABASE_URL  -> dental_os   (read-write, this file)
--
-- The cost of that separation: no cross-database JOIN. A query that
-- needs both sides joins in Python, or uses the pred_request_id it
-- already has. That is a deliberate trade — the alternative is a
-- shared schema where RULE 15 is a convention rather than a boundary.
--
-- ── Apply ───────────────────────────────────────────────────
--   PGPASSWORD="$(aws ssm get-parameter --name /dental/db/password \
--       --with-decryption --profile dental \
--       --query Parameter.Value --output text)" \
--   psql -h dental-postgres.c2feioes4hil.us-east-1.rds.amazonaws.com \
--        -U dental_admin -d postgres -c "CREATE DATABASE dental_os;"
--
--   PGPASSWORD="$(...same...)" \
--   psql -h dental-postgres.c2feioes4hil.us-east-1.rds.amazonaws.com \
--        -U dental_admin -d dental_os -f migrations/002_dental_os_tables.sql
--
-- CREATE DATABASE cannot run inside a transaction block, which is why
-- it is a separate command above and not part of this file.
-- ============================================================

BEGIN;

-- ============================================================
-- decision_outputs — one row per decision, per pre-D, per pass
-- ============================================================
-- Append-only and versioned: a re-run adds a row, never mutates one.
-- `mode` is CHECKed to recommend | human_approval because there is no
-- auto_execute in this domain and a bug that invents one should fail
-- at the write, not surface as an AI that acted on its own.
CREATE TABLE IF NOT EXISTS decision_outputs (
    output_id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pred_request_id    VARCHAR(50)  NOT NULL,
    tenant_id          VARCHAR(50)  NOT NULL,
    decision_id        VARCHAR(50)  NOT NULL,   -- eligibility_analyst etc.
    wave               INTEGER      NOT NULL,
    mode               VARCHAR(20)  NOT NULL,
    outcome            VARCHAR(20),             -- recommend | escalate | block
    signals            JSONB        NOT NULL DEFAULT '[]',
    findings           JSONB        NOT NULL DEFAULT '{}',
    confidence_label   VARCHAR(50),
    boundary_rule      TEXT,
    processing_ms      INTEGER,
    bundle_id          UUID,                    -- -> persona_bundles
    human_action       VARCHAR(20),             -- approved | overridden | escalated
    human_reviewer     VARCHAR(50),
    human_override_reason TEXT,
    created_at         TIMESTAMPTZ  NOT NULL DEFAULT NOW(),

    CONSTRAINT decision_outputs_mode_chk
        CHECK (mode IN ('recommend', 'human_approval')),
    CONSTRAINT decision_outputs_outcome_chk
        CHECK (outcome IS NULL OR outcome IN ('recommend', 'escalate', 'block')),
    CONSTRAINT decision_outputs_wave_chk
        CHECK (wave BETWEEN 1 AND 5),
    CONSTRAINT decision_outputs_human_action_chk
        CHECK (human_action IS NULL
               OR human_action IN ('approved', 'overridden', 'escalated'))
);

COMMENT ON CONSTRAINT decision_outputs_mode_chk ON decision_outputs IS
    'No auto_execute. decisions.yaml has no automate_if clause and no '
    'auto_execute mode; recommend is the ceiling. AI decides nothing.';

-- ============================================================
-- persona_bundles — the frozen audit snapshot
-- ============================================================
-- Written AFTER decision_outputs commits, in the same transaction
-- (RULE 10). The in-memory PredContext is truth during a live run;
-- this is the audit record and is never read during one. Replay reads
-- it directly — no view, no enricher.
CREATE TABLE IF NOT EXISTS persona_bundles (
    bundle_id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pred_request_id    VARCHAR(50)  NOT NULL,
    tenant_id          VARCHAR(50)  NOT NULL,
    bundle_snapshot    JSONB        NOT NULL,   -- frozen PredContext
    rules_snapshot     JSONB        NOT NULL DEFAULT '{}',  -- frozen catalogue_rules
    wave_outputs       JSONB        NOT NULL DEFAULT '{}',
    all_signals        JSONB        NOT NULL DEFAULT '[]',
    is_current         BOOLEAN      NOT NULL DEFAULT TRUE,
    version            INTEGER      NOT NULL DEFAULT 1,
    dental_os_version  VARCHAR(20)  NOT NULL DEFAULT '0.1.0',
    completed_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

COMMENT ON COLUMN persona_bundles.rules_snapshot IS
    'The catalogue rules as resolved at decision time. Without this a '
    'replay would re-resolve against today''s catalogue and could reach '
    'a different answer than the one a human signed off on.';

-- ============================================================
-- provider_feedback — human override captured as a learning signal
-- ============================================================
-- The reflection block in decisions.yaml: retained 365 days and
-- replayed to the same persona on the next similar case.
CREATE TABLE IF NOT EXISTS provider_feedback (
    feedback_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pred_request_id    VARCHAR(50)  NOT NULL,
    tenant_id          VARCHAR(50)  NOT NULL,
    decision_id        VARCHAR(50)  NOT NULL,
    signal_code        VARCHAR(50)  NOT NULL,
    feedback_type      VARCHAR(20)  NOT NULL,
    notes              TEXT,
    submitted_by       VARCHAR(50),             -- role, not a person
    submitted_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    expires_at         TIMESTAMPTZ  NOT NULL DEFAULT (NOW() + INTERVAL '365 days'),

    CONSTRAINT provider_feedback_type_chk
        CHECK (feedback_type IN ('accepted', 'overridden', 'false_positive')),
    CONSTRAINT provider_feedback_role_chk
        CHECK (submitted_by IS NULL
               OR submitted_by IN ('front_desk', 'billing', 'dentist', 'dso_manager'))
);

COMMENT ON CONSTRAINT provider_feedback_role_chk ON provider_feedback IS
    'The four owner_team values in decisions.yaml. A role, never a '
    'named individual — this table is about which desk overrode the '
    'recommendation, not who.';

-- ============================================================
-- appeal_packets — generated appeals awaiting a human signature
-- ============================================================
CREATE TABLE IF NOT EXISTS appeal_packets (
    packet_id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pred_request_id     VARCHAR(50) NOT NULL,
    tenant_id           VARCHAR(50) NOT NULL,
    payer_id            VARCHAR(50) NOT NULL,
    denial_reason_code  VARCHAR(20),
    viability_score     NUMERIC(4,3),
    success_probability NUMERIC(4,3),
    appeal_letter_text  TEXT,
    evidence_list       JSONB DEFAULT '[]',
    citations           JSONB DEFAULT '[]',
    appeal_deadline     DATE,
    days_remaining      INTEGER,
    approved_by         VARCHAR(50),
    generated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    submitted_at        TIMESTAMPTZ,
    outcome             VARCHAR(20),

    -- NULL is already permitted by a CHECK unless NOT NULL is declared;
    -- listing NULL inside IN() would make the whole predicate NULL and
    -- silently accept anything. Spelled out explicitly instead.
    CONSTRAINT appeal_packets_outcome_chk
        CHECK (outcome IS NULL
               OR outcome IN ('approved', 'denied', 'pending')),
    CONSTRAINT appeal_packets_viability_chk
        CHECK (viability_score IS NULL
               OR (viability_score >= 0 AND viability_score <= 1)),
    -- An appeal is only ever sent by a human (appeal_specialist is
    -- human_approval). A submitted packet with no approver is a bug.
    CONSTRAINT appeal_packets_submitted_needs_approver_chk
        CHECK (submitted_at IS NULL OR approved_by IS NOT NULL)
);

-- ============================================================
-- Indexes — every lookup is (pred_request_id, tenant_id)
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_decision_outputs_pred
    ON decision_outputs (pred_request_id, tenant_id);
CREATE INDEX IF NOT EXISTS idx_decision_outputs_decision
    ON decision_outputs (decision_id, tenant_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_persona_bundles_pred
    ON persona_bundles (pred_request_id, tenant_id);
CREATE INDEX IF NOT EXISTS idx_persona_bundles_current
    ON persona_bundles (pred_request_id, tenant_id) WHERE is_current;
CREATE INDEX IF NOT EXISTS idx_provider_feedback_pred
    ON provider_feedback (pred_request_id, tenant_id);
CREATE INDEX IF NOT EXISTS idx_provider_feedback_signal
    ON provider_feedback (signal_code, tenant_id);
CREATE INDEX IF NOT EXISTS idx_appeal_packets_pred
    ON appeal_packets (pred_request_id, tenant_id);

-- ============================================================
-- Row Level Security
-- ============================================================
-- Every table carries tenant_id and every one enforces it, matching
-- dental-simulator. FORCE so the owner is bound by the policy too —
-- without FORCE, dental_admin reads every tenant and the isolation is
-- decorative.
ALTER TABLE decision_outputs  ENABLE ROW LEVEL SECURITY;
ALTER TABLE persona_bundles   ENABLE ROW LEVEL SECURITY;
ALTER TABLE provider_feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE appeal_packets    ENABLE ROW LEVEL SECURITY;

ALTER TABLE decision_outputs  FORCE ROW LEVEL SECURITY;
ALTER TABLE persona_bundles   FORCE ROW LEVEL SECURITY;
ALTER TABLE provider_feedback FORCE ROW LEVEL SECURITY;
ALTER TABLE appeal_packets    FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS tenant_isolation ON decision_outputs;
DROP POLICY IF EXISTS tenant_isolation ON persona_bundles;
DROP POLICY IF EXISTS tenant_isolation ON provider_feedback;
DROP POLICY IF EXISTS tenant_isolation ON appeal_packets;

CREATE POLICY tenant_isolation ON decision_outputs
    USING (tenant_id = current_setting('app.tenant_id', true))
    WITH CHECK (tenant_id = current_setting('app.tenant_id', true));
CREATE POLICY tenant_isolation ON persona_bundles
    USING (tenant_id = current_setting('app.tenant_id', true))
    WITH CHECK (tenant_id = current_setting('app.tenant_id', true));
CREATE POLICY tenant_isolation ON provider_feedback
    USING (tenant_id = current_setting('app.tenant_id', true))
    WITH CHECK (tenant_id = current_setting('app.tenant_id', true));
CREATE POLICY tenant_isolation ON appeal_packets
    USING (tenant_id = current_setting('app.tenant_id', true))
    WITH CHECK (tenant_id = current_setting('app.tenant_id', true));

COMMIT;
