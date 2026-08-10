-- 011 — one signature per pre-D, enforced by the database.
--
-- api/routes.py already refuses a second attestation with a 409. This
-- is the same rule stated where it cannot be bypassed: by a future
-- endpoint that forgets, by a backfill script, by a psql session at
-- 2am. The application check gives a good error message; the index
-- makes the invariant true.
--
-- ⚠ WHY THIS IS SAFE ON AN APPEND-ONLY TABLE. clinical_attestations
-- is append-only in the sense that a row is never UPDATEd or deleted —
-- what was signed cannot be edited afterwards. It was never meant to
-- hold two signatures for one pre-D; it just had nothing stopping it,
-- and a UTC/local date bug was enough to get a case back into the
-- dentist's queue for a second signing.
--
-- Re-signing after a material change is a different act and needs a
-- different design (supersede-and-link, not a second bare row). When
-- that exists, this index changes shape with it.

CREATE UNIQUE INDEX IF NOT EXISTS clinical_attestations_one_per_pred
  ON clinical_attestations (tenant_id, pred_request_id);
