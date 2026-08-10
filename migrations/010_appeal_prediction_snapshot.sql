-- 010 — what the engine expected, frozen at the moment of filing.
--
-- The appeals tab can already say "payer overturned, $1,800 recovered".
-- What it could not say is what the engine thought BEFORE the payer
-- answered, because nothing recorded it. The only prediction on the
-- row was denial_events.appeal_probability, which was a seeded 65 on
-- every case regardless of denial type — the bundling constant on a
-- frequency denial and on a waiting-period denial.
--
-- ⚠ WHY A SNAPSHOT AND NOT A JOIN. resolve_appeal_viability can be
-- re-run at any time, but it does not return the same answer twice:
-- it reads evidence that accumulates, and it short-circuits on the
-- appeal deadline, so re-running it in October tells you the deadline
-- passed rather than what anyone believed in May. A prediction is only
-- a prediction if it is written down before the outcome is known.
--
-- Both columns are NULLABLE and mean it. "No prediction on record" is
-- an honest state for an appeal filed before this existed, and the UI
-- renders it as such rather than inventing a number.

ALTER TABLE appeal_events
  ADD COLUMN IF NOT EXISTS predicted_viable BOOLEAN;

-- 0.000 to 1.000, matching the resolver's success_probability. Not a
-- percentage: the UI multiplies, so a stored 65 vs 0.65 would be a
-- silent factor-of-100 the day someone reads the column directly.
ALTER TABLE appeal_events
  ADD COLUMN IF NOT EXISTS predicted_probability NUMERIC(4,3);

ALTER TABLE appeal_events
  DROP CONSTRAINT IF EXISTS appeal_predicted_probability_chk;
ALTER TABLE appeal_events
  ADD CONSTRAINT appeal_predicted_probability_chk
  CHECK (predicted_probability IS NULL
         OR (predicted_probability >= 0 AND predicted_probability <= 1));

COMMENT ON COLUMN appeal_events.predicted_viable IS
  'The engine''s verdict at the moment of filing. NULL = not recorded.';
COMMENT ON COLUMN appeal_events.predicted_probability IS
  'resolve_appeal_viability success_probability, 0-1, at filing time.';
