-- 009 — a denial must follow a submission, an appeal must follow a denial.
--
-- Option B from the reconciliation: dental_os's event tables are the
-- record of what HAPPENED, and payer_responses is dental-simulator's
-- fixture describing what a payer is predicted to do. The two stop
-- claiming to describe the same thing.
--
-- ⚠ THE FK YOU CANNOT HAVE. denial_events could not point at
-- payer_responses even if we wanted it to: payer_responses lives in
-- database `dental` and these tables live in `dental_os`. Same RDS
-- instance, two databases, and neither carries postgres_fdw or dblink
-- — only plpgsql. A foreign key cannot cross a database in Postgres.
-- The FKs below are the ones that ARE enforceable, and they are the
-- ones that matter: they make the chain inside dental_os real.
--
-- APPLY THIS FIRST, then run scripts/seed_billing_timeline.py. The FK
-- is on a NULLABLE column, so the pre-existing B04 denial — which has
-- no submission behind it — validates as NULL rather than blocking the
-- migration. The seeder then replaces it with a real chain.

-- ── denial_events.submission_id -> submission_events ─────────────
-- Nullable: a denial can arrive for something submitted before this
-- system existed, and we would rather record it than lose it. What we
-- will not accept is an id that points at nothing.
ALTER TABLE denial_events
  ADD COLUMN IF NOT EXISTS submission_id TEXT;   -- TEXT: submission_events.submission_id is TEXT, not UUID

ALTER TABLE denial_events
  DROP CONSTRAINT IF EXISTS denial_events_submission_fk;
ALTER TABLE denial_events
  ADD CONSTRAINT denial_events_submission_fk
  FOREIGN KEY (submission_id) REFERENCES submission_events (submission_id)
  ON DELETE SET NULL;

-- ── appeal_events.denial_id -> denial_events ─────────────────────
-- ⚠ CORRECTION TO THE AUDIT. This was reported as existing
-- "unconstrained". It was not — appeal_events_denial_id_fkey was
-- already there, created with the table. What was missing is the link
-- BELOW it: the denial pointed at no submission, so the chain was
-- broken one link further back than the audit said.
--
-- The original is replaced rather than duplicated, purely to add
-- ON DELETE SET NULL: deleting a denial should orphan its appeal, not
-- refuse the delete or silently take the appeal with it.
ALTER TABLE appeal_events
  DROP CONSTRAINT IF EXISTS appeal_events_denial_id_fkey;
ALTER TABLE appeal_events
  DROP CONSTRAINT IF EXISTS appeal_events_denial_fk;
ALTER TABLE appeal_events
  ADD CONSTRAINT appeal_events_denial_fk
  FOREIGN KEY (denial_id) REFERENCES denial_events (denial_id)
  ON DELETE SET NULL;

-- ── The dates have to be derived, not independently stamped ──────
-- Both seeds anchored to NOW() at seed time: denied_at = NOW() - 8d,
-- appeal_deadline = NOW() + 52d. They agreed only by arithmetic
-- coincidence, and nothing stopped a denial predating its submission.
ALTER TABLE denial_events
  DROP CONSTRAINT IF EXISTS denial_after_submission_chk;
ALTER TABLE appeal_events
  DROP CONSTRAINT IF EXISTS appeal_after_denial_chk;

-- Enforced in the seeder and in POST /appeals rather than as a table
-- CHECK: a CHECK cannot reference another row, and making these
-- triggers would put business logic somewhere nobody reads. The FKs
-- above give the structure; ordering is asserted by the tests.
