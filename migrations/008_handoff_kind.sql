-- 008 — what a handoff IS, and one row per thing being said.
--
-- ⚠ WHY A `kind` COLUMN AND NOT JUST "a row exists"
--
-- The plan was to derive "consultation complete" from the presence of a
-- clinical_handoffs row for the pre-D. That is not sound: TWO screens
-- write a handoff to_role='dentist' for the same pre-D.
--
--   CheckIn.tsx        Sarah's  [Notify clinical team]
--   PatientFinancial   Jennifer's [Mark consultation complete]
--
-- A patient the front desk flagged as waiting in reception would have
-- shown on the coordinator's screen as a finished consultation she
-- never had. The two facts are indistinguishable by row existence, by
-- to_role, and by anything else on the table today.
--
-- from_user's ROLE would separate them without a migration, but only by
-- accident — it holds precisely while tx_coord has exactly one button
-- that sends a handoff. A column that says what the row means is the
-- smaller thing to be wrong about later.
--
-- This is still not a new event table, which was the constraint.

ALTER TABLE clinical_handoffs
  ADD COLUMN IF NOT EXISTS kind TEXT NOT NULL DEFAULT 'note';

-- One live handoff per (pre-D, target role, kind).
--
-- ⚠ kind IS PART OF THE KEY, deliberately. Keying on (pre-D, to_role)
-- alone would make Sarah's "waiting in reception" and Jennifer's
-- "consultation complete" overwrite each other — whichever happened
-- last would be the only one the dentist saw, and marking a
-- consultation complete would silently erase the desk's flag.
--
-- Repeats of the SAME kind collapse into the row that is already
-- there, which is the duplicate this index exists to prevent: two
-- clicks of [Mark consultation complete] must not queue two notes.
DELETE FROM clinical_handoffs a
  USING clinical_handoffs b
 WHERE a.ctid < b.ctid
   AND a.tenant_id = b.tenant_id
   AND a.pred_request_id = b.pred_request_id
   AND a.to_role = b.to_role
   AND a.kind = b.kind;

CREATE UNIQUE INDEX IF NOT EXISTS clinical_handoffs_one_per_kind
  ON clinical_handoffs (tenant_id, pred_request_id, to_role, kind);
