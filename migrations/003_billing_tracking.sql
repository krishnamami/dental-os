-- 003 — submission, denial and appeal tracking.
--
-- dental-os's own tables (CONTEXT.md RULE 15), bringing the count from
-- four to seven. These close dental-simulator Gap #3: until now the
-- `appeals` table on the simulator side existed and was empty, nothing
-- recorded that a pre-D had been sent, and the Revenue Ops analytics
-- had to say "not tracked yet" for appeal recovery.
--
-- Every table carries tenant_id and FORCE ROW LEVEL SECURITY. Note the
-- RLS trap this protects against: a query run WITHOUT app.tenant_id
-- returns zero rows and no error, so an endpoint that forgets the
-- tenant looks like an empty practice rather than a bug.

CREATE TABLE IF NOT EXISTS submission_events (
  submission_id     TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  tenant_id         TEXT NOT NULL,
  pred_request_id   TEXT NOT NULL,
  patient_name      TEXT NOT NULL,
  payer_id          TEXT NOT NULL,
  payer_name        TEXT NOT NULL,
  submitted_by      TEXT NOT NULL,          -- users.user_id
  submitted_at      TIMESTAMPTZ DEFAULT NOW(),
  submission_method TEXT DEFAULT 'manual',  -- manual/nea_fastattach/availity
  submission_ref    TEXT,                   -- the payer's reference number
  expected_response_days INT DEFAULT 15,
  status            TEXT DEFAULT 'submitted',
  notes             TEXT
);

CREATE INDEX IF NOT EXISTS submission_events_tenant_date
  ON submission_events(tenant_id, submitted_at);

-- The ON CONFLICT target for re-submission. One live submission per
-- pre-D per practice: sending the same case twice is a duplicate at
-- the payer, not a second record here.
CREATE UNIQUE INDEX IF NOT EXISTS submission_events_unique
  ON submission_events(tenant_id, pred_request_id);


CREATE TABLE IF NOT EXISTS denial_events (
  denial_id          TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  tenant_id          TEXT NOT NULL,
  pred_request_id    TEXT NOT NULL,
  patient_name       TEXT NOT NULL,
  payer_id           TEXT NOT NULL,
  denied_at          TIMESTAMPTZ DEFAULT NOW(),
  denial_reason      TEXT,   -- bundling/pre_d_required/clinical_criteria/...
  denial_reason_code TEXT,   -- the payer's own code
  denied_amount      NUMERIC(10,2),
  appeal_deadline    TIMESTAMPTZ,
  appeal_viable      BOOLEAN DEFAULT false,
  appeal_probability INT,    -- 0-100
  notes              TEXT
);

CREATE INDEX IF NOT EXISTS denial_events_tenant_date
  ON denial_events(tenant_id, denied_at);

-- Not in the brief, and the seed needs it: ON CONFLICT DO NOTHING with
-- no unique index has nothing to conflict on, so re-running the seed
-- would stack a second Carlos Rivera denial every time.
CREATE UNIQUE INDEX IF NOT EXISTS denial_events_unique
  ON denial_events(tenant_id, pred_request_id);


CREATE TABLE IF NOT EXISTS appeal_events (
  appeal_id        TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  tenant_id        TEXT NOT NULL,
  pred_request_id  TEXT NOT NULL,
  denial_id        TEXT REFERENCES denial_events(denial_id),
  patient_name     TEXT NOT NULL,
  payer_id         TEXT NOT NULL,
  filed_by         TEXT NOT NULL,           -- users.user_id
  filed_at         TIMESTAMPTZ DEFAULT NOW(),
  appeal_type      TEXT DEFAULT 'standard', -- standard/expedited/external
  status           TEXT DEFAULT 'filed',    -- filed/pending/overturned/upheld/withdrawn
  resolved_at      TIMESTAMPTZ,
  recovered_amount NUMERIC(10,2),
  notes            TEXT
);

CREATE INDEX IF NOT EXISTS appeal_events_tenant_date
  ON appeal_events(tenant_id, filed_at);

CREATE UNIQUE INDEX IF NOT EXISTS appeal_events_unique
  ON appeal_events(tenant_id, pred_request_id);


-- ── RLS ───────────────────────────────────────────────────────────
--
-- WITH CHECK is spelled out rather than left to default to USING.
-- Postgres does fall back to it, but an INSERT that can write a row
-- the same policy cannot then read is the kind of thing worth stating
-- explicitly on a table holding money.

ALTER TABLE submission_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE submission_events FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS submission_tenant_isolation ON submission_events;
CREATE POLICY submission_tenant_isolation ON submission_events
  USING (tenant_id = current_setting('app.tenant_id', true))
  WITH CHECK (tenant_id = current_setting('app.tenant_id', true));

ALTER TABLE denial_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE denial_events FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS denial_tenant_isolation ON denial_events;
CREATE POLICY denial_tenant_isolation ON denial_events
  USING (tenant_id = current_setting('app.tenant_id', true))
  WITH CHECK (tenant_id = current_setting('app.tenant_id', true));

ALTER TABLE appeal_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE appeal_events FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS appeal_tenant_isolation ON appeal_events;
CREATE POLICY appeal_tenant_isolation ON appeal_events
  USING (tenant_id = current_setting('app.tenant_id', true))
  WITH CHECK (tenant_id = current_setting('app.tenant_id', true));

-- UPDATE is granted alongside INSERT because the submission endpoint
-- upserts. Learned the hard way on checkin_events: ON CONFLICT DO
-- UPDATE fails with "permission denied" on the SECOND call only.
GRANT SELECT, INSERT, UPDATE ON submission_events TO dental_app;
GRANT SELECT, INSERT, UPDATE ON denial_events     TO dental_app;
GRANT SELECT, INSERT, UPDATE ON appeal_events     TO dental_app;
