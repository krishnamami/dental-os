-- 005 — one person handing a case to another.
--
-- ⚠ THIS TABLE IS NOT IN ANY SPEC I CAN READ. The needs_clinician
-- filter's fourth condition is "an unread clinical_handoffs row targets
-- role 'dentist'", and the queue response is required to carry a
-- `handoff` object — but no such table existed and
-- dentist-workbench-build-prompt.md is in none of the three repos. The
-- shape below is mine. Change it freely; nothing outside the queue
-- filter reads it yet.
--
-- Follows 003/004: tenant_id, ENABLE + FORCE RLS, USING and WITH CHECK.

CREATE TABLE IF NOT EXISTS clinical_handoffs (
  handoff_id      TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  tenant_id       TEXT NOT NULL,
  pred_request_id TEXT NOT NULL,
  -- Who is being asked. A ROLE, not a person: "the dentist" is who
  -- covers the chair today, and naming an individual means the case
  -- disappears when they are on leave.
  to_role         TEXT NOT NULL DEFAULT 'dentist',
  from_user       TEXT NOT NULL,          -- users.user_id
  message         TEXT NOT NULL,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  -- NULL means unread. That is the whole filter condition, so it is a
  -- timestamp rather than a boolean: "when did they see it" is the
  -- question anyone asks next.
  read_at         TIMESTAMPTZ,
  read_by         TEXT
);

-- The filter reads unread-by-role per case; this is the index for it.
CREATE INDEX IF NOT EXISTS clinical_handoffs_unread
  ON clinical_handoffs(tenant_id, to_role, pred_request_id)
  WHERE read_at IS NULL;

ALTER TABLE clinical_handoffs ENABLE ROW LEVEL SECURITY;
ALTER TABLE clinical_handoffs FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS clinical_handoffs_tenant ON clinical_handoffs;
CREATE POLICY clinical_handoffs_tenant ON clinical_handoffs
  USING (tenant_id = current_setting('app.tenant_id', true))
  WITH CHECK (tenant_id = current_setting('app.tenant_id', true));

GRANT SELECT, INSERT, UPDATE ON clinical_handoffs TO dental_app;
