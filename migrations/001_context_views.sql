-- ============================================================
-- dental-os — 001_context_views.sql
-- 8 per-persona context views over dental-simulator tables.
-- ============================================================
-- One view per persona. Each is the pre-joined slice that persona
-- needs, and only what it needs — the SQL-level expression of
-- decisions_that_read_it in domains/dental/knowledge_base.json.
--
-- Personas read these views. Personas NEVER read raw tables and
-- NEVER call the rule loader (CONTEXT.md RULE 4 + RULE 5).
--
-- ── security_invoker = true — DO NOT REMOVE ─────────────────
-- These views are created by dental_admin, who OWNS the underlying
-- tables. A normal Postgres view executes with the VIEW OWNER's
-- privileges, so without security_invoker the RLS policy would be
-- evaluated as dental_admin and every caller would see every
-- tenant's rows through the view — a silent cross-tenant leak that
-- no test of dental_app's direct table access would catch.
-- security_invoker = true (PG15+) evaluates RLS as the CALLING
-- role, so dental_app still needs SET app.tenant_id and still sees
-- only its own tenant. Verified: without a tenant set, every view
-- below returns 0 rows.
--
-- ── Apply ───────────────────────────────────────────────────
--   PGPASSWORD="$(aws ssm get-parameter --name /dental/db/password \
--       --with-decryption --profile dental \
--       --query Parameter.Value --output text)" \
--   psql -h dental-postgres.c2feioes4hil.us-east-1.rds.amazonaws.com \
--        -U dental_admin -d dental -f migrations/001_context_views.sql
--
-- Do not paste the admin password into a shell literal — it bypasses
-- nothing here but it does grant DDL, and shell history is forever.
--
-- ── Verify ──────────────────────────────────────────────────
--   python scripts/verify_views.py
-- ============================================================

BEGIN;

-- ============================================================
-- vw_eligibility_context  ->  eligibility_analyst  (wave 1)
-- ============================================================
-- Is coverage live, and will this plan pay anything at all?
-- NOTE ON NAMING: eligibility_profiles spells it
-- annual_maximum_remaining / implant_coverage; pred_states spells the
-- same two concepts annual_max_remaining / implant_covered. Both are
-- exposed, prefixed elig_ and state_, because they can legitimately
-- disagree — the profile is what the payer said, the state is what the
-- assembler concluded.
CREATE OR REPLACE VIEW vw_eligibility_context
WITH (security_invoker = true) AS
SELECT
    pr.pred_request_id,
    pr.tenant_id,
    pr.patient_id,
    pr.provider_npi,
    pr.payer_id,
    pr.plan_id,
    pr.total_case_value,

    -- patient identity (member-ID mismatch detection)
    p.first_name || ' ' || p.last_name          AS patient_name,
    p.member_id                                  AS patient_member_id,
    p.group_number                               AS patient_group_number,
    p.dob,
    p.enrollment_start,
    p.active                                     AS patient_active,
    p.secondary_payer_id,

    -- plan terms
    pl.plan_name,
    pl.plan_type,
    pl.annual_maximum                            AS plan_annual_maximum,
    pl.deductible_individual,
    pl.waiting_period_basic_months,
    pl.waiting_period_major_months,
    pl.waiting_period_implant_months,
    pl.implant_coverage                          AS plan_implant_coverage,
    pl.missing_tooth_clause                      AS plan_missing_tooth_clause,
    py.name                                      AS payer_name,
    py.payer_type,

    -- what the X12 271 actually said
    ep.coverage_active,
    ep.annual_maximum                            AS elig_annual_maximum,
    ep.annual_maximum_used,
    ep.annual_maximum_remaining,
    ep.deductible_total,
    ep.deductible_met,
    ep.deductible_remaining,
    ep.benefit_pct_preventive,
    ep.benefit_pct_basic,
    ep.benefit_pct_major,
    ep.benefit_pct_implants,
    ep.implant_coverage                          AS elig_implant_coverage,
    ep.ortho_coverage,
    ep.waiting_period_met,
    ep.missing_tooth_clause                      AS elig_missing_tooth_clause,
    ep.missing_tooth_clause_confirmed,
    ep.coordination_of_benefits,
    ep.member_id                                 AS elig_member_id,
    ep.pred_required_codes,
    ep.confidence                                AS elig_confidence,
    ep.conflicts                                 AS elig_conflicts,

    -- Member-ID mismatch: the INSURANCE CARD document vs the X12 271.
    -- NOT patients.member_id vs eligibility_profiles.member_id — those
    -- are different ID namespaces (patients holds an internal id like
    -- SS-DA-A01-0001, the 271 holds the payer-format DDL-842901-M), so
    -- comparing them reports a mismatch on all 35 cases and is useless
    -- as a signal. Comparing the card to the 271 fires on exactly
    -- DA-M01, which is the scenario designed to test it.
    -- NULL, not false, when there is no card on file: absence of
    -- evidence is not evidence of a match (RULE 11).
    (SELECT (card.extracted_fields->>'member_id') IS DISTINCT FROM ep.member_id
       FROM clinical_evidence card
      WHERE card.pred_request_id = pr.pred_request_id
        AND card.document_type = 'INSURANCE_CARD'
      LIMIT 1)                                   AS member_id_mismatch,
    (SELECT card.extracted_fields->>'member_id'
       FROM clinical_evidence card
      WHERE card.pred_request_id = pr.pred_request_id
        AND card.document_type = 'INSURANCE_CARD'
      LIMIT 1)                                   AS card_member_id,

    -- what the assembler concluded
    ps.coverage_active                           AS state_coverage_active,
    ps.annual_max_remaining                      AS state_annual_max_remaining,
    ps.implant_covered                           AS state_implant_covered,
    ps.waiting_period_met                        AS state_waiting_period_met,
    ps.missing_tooth_clause_triggered,
    ps.decision,
    ps.open_conditions
FROM pred_requests pr
JOIN patients             p  ON p.patient_id      = pr.patient_id
LEFT JOIN plans           pl ON pl.plan_id        = pr.plan_id
LEFT JOIN payers          py ON py.payer_id       = pr.payer_id
LEFT JOIN eligibility_profiles ep ON ep.pred_request_id = pr.pred_request_id
LEFT JOIN pred_states     ps ON ps.pred_request_id = pr.pred_request_id;


-- ============================================================
-- vw_coverage_context  ->  coverage_analyst  (wave 2)
-- ============================================================
-- One row per PROCEDURE LINE, not per pre-D. Bundling, frequency and
-- downgrade are all per-code decisions, so the grain has to be the code.
CREATE OR REPLACE VIEW vw_coverage_context
WITH (security_invoker = true) AS
SELECT
    pr.pred_request_id,
    pr.tenant_id,
    pr.payer_id,
    pr.plan_id,
    pr.total_case_value,

    -- the line
    prl.line_no,
    prl.cdt_code,
    prl.tooth_number,
    prl.tooth_surface,
    prl.arch,
    prl.quadrant,
    prl.fee,
    prl.payer_allowed,
    prl.requires_pred,
    prl.description                              AS procedure_description,

    -- what it costs, and who pays
    ce.allowed_amount,
    ce.insurance_pays,
    ce.patient_pays,
    ce.deductible_applied,
    ce.benefit_pct,
    ce.annual_max_applied,
    ce.downgrade_applied,
    ce.downgrade_from,

    -- coverage headroom
    ep.annual_maximum_remaining,
    ep.implant_coverage                          AS elig_implant_coverage,
    ep.waiting_period_met,
    ep.coordination_of_benefits,

    -- assembler conclusions
    ps.has_bundling_conflict,
    ps.conflict_count,
    ps.conflicts,
    ps.open_conditions,
    ps.decision_trace,
    ps.decision,
    ps.pred_required,
    ps.annual_max_remaining                      AS state_annual_max_remaining
FROM pred_requests pr
JOIN procedure_lines prl ON prl.pred_request_id = pr.pred_request_id
-- Join on the LINE, not on (cdt_code, tooth_number). DA-A04 bills
-- D4341 four times — once per quadrant — with tooth_number NULL on
-- every line, so a (cdt_code, tooth_number) join matches 4x4 and
-- silently quadruples that case's fees. cost_estimates.procedure_id
-- is 'L' || procedure_lines.line_no; verified exact across all 67
-- rows (no orphans, no cdt_code disagreements). The regex-guarded
-- substring yields NULL rather than raising if that format ever
-- changes, which fails the join instead of failing the query.
LEFT JOIN cost_estimates ce
       ON ce.pred_request_id = prl.pred_request_id
      AND NULLIF(substring(ce.procedure_id FROM '^L([0-9]+)$'), '')::INTEGER
          = prl.line_no
LEFT JOIN eligibility_profiles ep ON ep.pred_request_id = pr.pred_request_id
LEFT JOIN pred_states          ps ON ps.pred_request_id = pr.pred_request_id;


-- ============================================================
-- vw_clinical_context  ->  clinical_reviewer  (wave 2)
-- ============================================================
-- One row per EVIDENCE DOCUMENT. The JSONB extracts below are the
-- measurements the ADA criteria are scored against — surfaced as typed
-- columns so a persona never has to reach into extracted_fields itself.
CREATE OR REPLACE VIEW vw_clinical_context
WITH (security_invoker = true) AS
SELECT
    pr.pred_request_id,
    pr.tenant_id,
    pr.provider_npi,

    -- the document
    ev.evidence_id,
    ev.document_type,
    ev.document_category,
    ev.tooth_number                              AS evidence_tooth_number,
    ev.s3_key,
    ev.confidence_score,
    ev.extraction_method,
    ev.received_at,
    ev.extracted_fields,

    -- measurements, typed. NULLIF guards the '' -> numeric cast.
    (NULLIF(ev.extracted_fields->>'bone_loss_mm',      ''))::NUMERIC AS bone_loss_mm,
    (NULLIF(ev.extracted_fields->>'bone_loss_pct',     ''))::NUMERIC AS bone_loss_pct,
    (NULLIF(ev.extracted_fields->>'pocket_depth_max',  ''))::NUMERIC AS pocket_depth_max,
    (NULLIF(ev.extracted_fields->>'sites_gte_5mm',     ''))::INTEGER AS sites_gte_5mm,
    (NULLIF(ev.extracted_fields->>'bleeding_pct',      ''))::NUMERIC AS bleeding_pct,
    (NULLIF(ev.extracted_fields->>'bone_volume_mm3',   ''))::NUMERIC AS bone_volume_mm3,
    (NULLIF(ev.extracted_fields->>'narrative_present', ''))::BOOLEAN AS narrative_present,
                ev.extracted_fields->>'cdt_codes_noted'             AS cdt_codes_noted,
                ev.extracted_fields->>'pred_decision'               AS pred_decision,
                ev.extracted_fields->>'image_quality'               AS image_quality,
                ev.extracted_fields->>'pathology'                   AS pathology,
                ev.extracted_fields->>'date_taken'                  AS date_taken,

    -- criteria scoring context
    ps.criteria_score,
    ps.medical_necessity_met,
    ps.criteria_met_count,
    ps.criteria_total_count,
    ps.clinical_evidence_count,
    ps.missing_evidence,
    ps.no_critical_conflicts,
    ps.decision,
    ps.decision_trace,
    ps.open_conditions,

    -- what was billed, for criteria selection
    (SELECT array_agg(DISTINCT prl.cdt_code)
       FROM procedure_lines prl
      WHERE prl.pred_request_id = pr.pred_request_id)  AS billed_cdt_codes,
    (SELECT array_agg(DISTINCT prl.tooth_number)
       FROM procedure_lines prl
      WHERE prl.pred_request_id = pr.pred_request_id
        AND prl.tooth_number IS NOT NULL)              AS billed_tooth_numbers
FROM pred_requests pr
JOIN clinical_evidence ev ON ev.pred_request_id = pr.pred_request_id
LEFT JOIN pred_states  ps ON ps.pred_request_id = pr.pred_request_id;


-- ============================================================
-- vw_documentation_context  ->  documentation_reviewer  (wave 3)
-- ============================================================
-- Is the packet complete enough to submit? Presence, currency, and
-- extraction confidence. below_trust_floor uses 0.70 (TRUST_FLOOR),
-- NOT the extractors' 0.6 — see CONTEXT.md and PRD Known Gap #5.
CREATE OR REPLACE VIEW vw_documentation_context
WITH (security_invoker = true) AS
SELECT
    pr.pred_request_id,
    pr.tenant_id,

    ev.evidence_id,
    ev.document_type,
    ev.document_category,
    ev.s3_key,
    ev.confidence_score,
    ev.extraction_method,
    ev.received_at,
    (ev.s3_key IS NOT NULL)                              AS has_document_file,
    (ev.confidence_score < 0.70)                         AS below_trust_floor,

    ps.missing_evidence,
    ps.open_conditions,
    ps.clinical_evidence_count,
    ps.criteria_score,
    ps.decision,

    -- which codes are billed determines which documents are required
    (SELECT array_agg(DISTINCT prl.cdt_code)
       FROM procedure_lines prl
      WHERE prl.pred_request_id = pr.pred_request_id)     AS billed_cdt_codes,

    -- packet-level rollups, so the persona can answer "is it complete?"
    -- without a second query
    (SELECT array_agg(DISTINCT e2.document_type)
       FROM clinical_evidence e2
      WHERE e2.pred_request_id = pr.pred_request_id)      AS document_types_present,
    (SELECT COUNT(*)
       FROM clinical_evidence e2
      WHERE e2.pred_request_id = pr.pred_request_id
        AND e2.confidence_score < 0.70)                   AS low_confidence_doc_count,

    -- Member-ID mismatch: the INSURANCE CARD document vs the X12 271.
    -- See the same block in vw_eligibility_context for why it is not
    -- patients.member_id. NULL when no card is on file.
    (SELECT (card.extracted_fields->>'member_id') IS DISTINCT FROM ep2.member_id
       FROM clinical_evidence card
       JOIN eligibility_profiles ep2
         ON ep2.pred_request_id = pr.pred_request_id
      WHERE card.pred_request_id = pr.pred_request_id
        AND card.document_type = 'INSURANCE_CARD'
      LIMIT 1)                                            AS member_id_mismatch
FROM pred_requests pr
JOIN clinical_evidence ev ON ev.pred_request_id = pr.pred_request_id
LEFT JOIN pred_states  ps ON ps.pred_request_id = pr.pred_request_id;


-- ============================================================
-- vw_provider_context  ->  provider_credentialing  (wave 1)
-- ============================================================
-- The narrowest view in the set, deliberately. This persona has no
-- business seeing the clinical chart or the fee schedule.
CREATE OR REPLACE VIEW vw_provider_context
WITH (security_invoker = true) AS
SELECT
    pr.pred_request_id,
    pr.tenant_id,
    pr.payer_id,

    prov.provider_npi,
    prov.name                                    AS provider_name,
    prov.first_name                              AS provider_first_name,
    prov.last_name                               AS provider_last_name,
    prov.credential,
    prov.specialty,
    prov.taxonomy_code,
    prov.practice_name,
    prov.license_state,
    prov.license_expiry,
    prov.credentialed,
    prov.network_status,
    prov.out_of_network,
    prov.oig_excluded,
    prov.sanctions,
    prov.nppes_verified,
    prov.nppes_verified_at,
    prov.source                                  AS provider_source,

    ps.provider_npi_valid,
    ps.provider_oig_excluded,
    ps.provider_specialty                        AS state_provider_specialty,
    ps.decision,
    ps.open_conditions,

    -- specialty-gated codes (D4xxx perio, D7xxx surgical) are what make
    -- a specialty mismatch matter
    (SELECT array_agg(DISTINCT prl.cdt_code)
       FROM procedure_lines prl
      WHERE prl.pred_request_id = pr.pred_request_id)  AS billed_cdt_codes
FROM pred_requests pr
LEFT JOIN providers   prov ON prov.provider_npi   = pr.provider_npi
LEFT JOIN pred_states ps   ON ps.pred_request_id  = pr.pred_request_id;


-- ============================================================
-- vw_fraud_context  ->  fraud_integrity  (wave 1)
-- ============================================================
-- One row per procedure line, with the note's cdt_codes_noted and the
-- X-ray's bone_loss_mm pulled alongside so upcoding and surface
-- conflicts are a column comparison rather than a join the persona has
-- to write. fee_ratio surfaces the waived-copay signal (fee == allowed).
CREATE OR REPLACE VIEW vw_fraud_context
WITH (security_invoker = true) AS
SELECT
    pr.pred_request_id,
    pr.tenant_id,
    pr.provider_npi,
    pr.payer_id,

    prl.line_no,
    prl.cdt_code,
    prl.tooth_number,
    prl.tooth_surface,
    prl.fee,
    prl.payer_allowed,

    ce.allowed_amount,
    ce.insurance_pays,
    ce.patient_pays,
    ce.downgrade_applied,
    ce.downgrade_from,

    -- waived copay: submitted fee exactly equals the allowed amount
    (prl.fee IS NOT NULL
     AND ce.allowed_amount IS NOT NULL
     AND prl.fee = ce.allowed_amount)                    AS fee_equals_allowed,

    -- what the clinical note says was done (upcoding / phantom detector)
    (SELECT e2.extracted_fields->>'cdt_codes_noted'
       FROM clinical_evidence e2
      WHERE e2.pred_request_id = pr.pred_request_id
        AND e2.document_type = 'CLINICAL_NOTE'
      LIMIT 1)                                           AS cdt_codes_noted,

    -- what the radiograph shows (surface / necessity conflict detector)
    (SELECT (NULLIF(e2.extracted_fields->>'bone_loss_mm', ''))::NUMERIC
       FROM clinical_evidence e2
      WHERE e2.pred_request_id = pr.pred_request_id
        AND e2.document_type = 'XRAY_PA'
      LIMIT 1)                                           AS bone_loss_mm,
    (SELECT e2.extracted_fields->>'tooth_surface'
       FROM clinical_evidence e2
      WHERE e2.pred_request_id = pr.pred_request_id
        AND e2.document_type = 'XRAY_PA'
      LIMIT 1)                                           AS xray_tooth_surface,

    -- typed graph edges: contradicts is the integrity signal
    (SELECT COUNT(*) FROM evidence_edges ee
      WHERE ee.pred_request_id = pr.pred_request_id
        AND ee.edge_type = 'confirms')                   AS confirms_count,
    (SELECT COUNT(*) FROM evidence_edges ee
      WHERE ee.pred_request_id = pr.pred_request_id
        AND ee.edge_type = 'contradicts')                AS contradicts_count,
    (SELECT array_agg(DISTINCT ee.relationship_type) FROM evidence_edges ee
      WHERE ee.pred_request_id = pr.pred_request_id)     AS relationship_types,
    -- WHICH field a contradiction is about decides whether it is an
    -- integrity concern at all. DA-A01 carries a 'contradicts' edge on
    -- field='bundling_conflict' — that is the coverage rule firing,
    -- modelled as a graph edge, not two documents disagreeing about a
    -- clinical fact. Counting it as fraud would flag the reference
    -- clean case. fraud_integrity filters on this.
    (SELECT array_agg(DISTINCT ee.field) FROM evidence_edges ee
      WHERE ee.pred_request_id = pr.pred_request_id
        AND ee.edge_type = 'contradicts')                AS contradicts_fields,

    ps.has_bundling_conflict,
    ps.conflict_count,
    ps.conflicts,
    ps.no_critical_conflicts,
    ps.decision,
    ps.open_conditions
FROM pred_requests pr
JOIN procedure_lines prl ON prl.pred_request_id = pr.pred_request_id
-- Join on the LINE, not on (cdt_code, tooth_number). DA-A04 bills
-- D4341 four times — once per quadrant — with tooth_number NULL on
-- every line, so a (cdt_code, tooth_number) join matches 4x4 and
-- silently quadruples that case's fees. cost_estimates.procedure_id
-- is 'L' || procedure_lines.line_no; verified exact across all 67
-- rows (no orphans, no cdt_code disagreements). The regex-guarded
-- substring yields NULL rather than raising if that format ever
-- changes, which fails the join instead of failing the query.
LEFT JOIN cost_estimates ce
       ON ce.pred_request_id = prl.pred_request_id
      AND NULLIF(substring(ce.procedure_id FROM '^L([0-9]+)$'), '')::INTEGER
          = prl.line_no
LEFT JOIN pred_states ps ON ps.pred_request_id = pr.pred_request_id;


-- ============================================================
-- vw_appeal_context  ->  appeal_specialist  (wave 5)
-- ============================================================
-- Only meaningful where the payer said denied or pended. The view does
-- not filter — appeal_specialist's own boundary decides whether to run
-- — but is_appealable_decision is precomputed so the caller does not
-- reimplement that test.
-- DROP first: CREATE OR REPLACE cannot remove a column from a view,
-- and received_at was removed from this one.
DROP VIEW IF EXISTS vw_appeal_context;
CREATE OR REPLACE VIEW vw_appeal_context
WITH (security_invoker = true) AS
SELECT
    pr.pred_request_id,
    pr.tenant_id,
    pr.payer_id,
    pr.total_case_value,

    presp.response_id,
    presp.response_type,
    presp.pred_number,
    presp.decision                               AS payer_decision,
    presp.denial_reason_code,
    presp.denial_reason_text,
    presp.denial_reason,
    presp.denial_code,
    presp.policy_citation,
    presp.appeal_deadline,
    presp.approved_amount,
    presp.valid_from,
    presp.valid_to,
    presp.pend_checklist,
    presp.response_date,
    -- ⚠ received_at IS DELIBERATELY NOT SELECTED.
    --
    -- payer_responses is dental-simulator FIXTURE data: the posture a
    -- payer is predicted to take on a pre-D. All 40 rows carried
    -- received_at = 2026-08-05, which asserted that a payer had
    -- responded to forty cases on one day, none of which had been
    -- sent. It was the only column in the table claiming an event
    -- happened, and nothing downstream read it.
    --
    -- What actually happened lives in dental_os: submission_events,
    -- denial_events, appeal_events. See migrations/009.

    (presp.decision IN ('denied', 'pended'))     AS is_appealable_decision,
    (presp.appeal_deadline - CURRENT_DATE)       AS days_to_appeal_deadline,

    ps.decision                                  AS state_decision,
    ps.criteria_score,
    ps.medical_necessity_met,
    ps.has_bundling_conflict,
    ps.open_conditions,
    ps.decision_trace,
    ps.missing_evidence,

    -- open conditions with their SLA and assignee
    (SELECT jsonb_agg(jsonb_build_object(
                'condition_code', pci.condition_code,
                'status',         pci.status,
                'assignee',       pci.assignee,
                'due_by',         pci.due_by))
       FROM pred_condition_instances pci
      WHERE pci.pred_request_id = pr.pred_request_id
        AND pci.status <> 'resolved')            AS open_condition_instances,

    -- the last 10 audit events, newest first
    (SELECT jsonb_agg(e ORDER BY (e->>'occurred_at') DESC)
       FROM (SELECT jsonb_build_object(
                        'event_type',  pal.event_type,
                        'actor',       pal.actor,
                        'occurred_at', pal.occurred_at,
                        'payload',     pal.payload) AS e
               FROM pred_audit_log pal
              WHERE pal.pred_request_id = pr.pred_request_id
              ORDER BY pal.occurred_at DESC
              LIMIT 10) sub)                     AS recent_audit_events
FROM pred_requests pr
LEFT JOIN payer_responses presp ON presp.pred_request_id = pr.pred_request_id
LEFT JOIN pred_states     ps    ON ps.pred_request_id    = pr.pred_request_id;


-- ============================================================
-- vw_portfolio_context  ->  dso_portfolio_manager  (wave 5)
-- ============================================================
-- Aggregate across ALL pre-Ds for the tenant. No per-pred_request join.
-- One row per tenant. Advisory only — this persona never blocks a case
-- (decisions.yaml hard rule portfolio_never_blocks_a_case).
CREATE OR REPLACE VIEW vw_portfolio_context
WITH (security_invoker = true) AS
SELECT
    pr.tenant_id,

    COUNT(DISTINCT pr.pred_request_id)                                   AS total_pred_requests,
    COUNT(DISTINCT pr.pred_request_id) FILTER (WHERE ps.decision = 'approved') AS approved_count,
    COUNT(DISTINCT pr.pred_request_id) FILTER (WHERE ps.decision = 'denied')   AS denied_count,
    COUNT(DISTINCT pr.pred_request_id) FILTER (WHERE ps.decision = 'pended')   AS pended_count,

    ROUND(AVG(ps.criteria_score), 4)                                     AS avg_criteria_score,
    COUNT(DISTINCT pr.pred_request_id) FILTER (WHERE ps.has_bundling_conflict) AS bundling_conflict_count,

    -- first-pass approval rate, the headline metric in PRD section 9
    ROUND(
        COUNT(DISTINCT pr.pred_request_id) FILTER (WHERE ps.decision = 'approved')::NUMERIC
        / NULLIF(COUNT(DISTINCT pr.pred_request_id), 0), 4
    )                                                                    AS first_pass_approval_rate,

    -- money
    SUM(pr.total_case_value)                                             AS total_billed,
    (SELECT SUM(insurance_pays) FROM cost_estimates c WHERE c.tenant_id = pr.tenant_id) AS total_insurance_pays,
    (SELECT SUM(patient_pays)   FROM cost_estimates c WHERE c.tenant_id = pr.tenant_id) AS total_patient_pays,
    SUM(pr.total_case_value) FILTER (WHERE ps.decision = 'denied')       AS revenue_at_risk,

    -- denial patterns: which condition codes fire most often
    (SELECT jsonb_agg(t) FROM (
        SELECT pci.condition_code, COUNT(*) AS n
          FROM pred_condition_instances pci
         WHERE pci.tenant_id = pr.tenant_id
         GROUP BY pci.condition_code
         ORDER BY COUNT(*) DESC
         LIMIT 10) t)                                                    AS denial_by_condition,

    -- and which payers they come from
    (SELECT jsonb_agg(t) FROM (
        SELECT r.payer_id,
               COUNT(*)                                        AS total,
               COUNT(*) FILTER (WHERE s.decision = 'denied')    AS denied,
               COUNT(*) FILTER (WHERE s.decision = 'pended')    AS pended,
               COUNT(*) FILTER (WHERE s.decision = 'approved')  AS approved
          FROM pred_requests r
          LEFT JOIN pred_states s ON s.pred_request_id = r.pred_request_id
         WHERE r.tenant_id = pr.tenant_id
         GROUP BY r.payer_id
         ORDER BY COUNT(*) DESC) t)                                      AS denial_by_payer,

    -- documentation quality, the training-need signal
    (SELECT ROUND(AVG(e.confidence_score), 4)
       FROM clinical_evidence e WHERE e.tenant_id = pr.tenant_id)        AS avg_extraction_confidence,
    (SELECT COUNT(*)
       FROM clinical_evidence e
      WHERE e.tenant_id = pr.tenant_id
        AND e.confidence_score < 0.70)                                   AS low_confidence_doc_count
FROM pred_requests pr
LEFT JOIN pred_states ps ON ps.pred_request_id = pr.pred_request_id
GROUP BY pr.tenant_id;


-- ============================================================
-- Grants — dental_app is the runtime role and is read-only.
-- ============================================================
GRANT SELECT ON vw_eligibility_context   TO dental_app;
GRANT SELECT ON vw_coverage_context      TO dental_app;
GRANT SELECT ON vw_clinical_context      TO dental_app;
GRANT SELECT ON vw_documentation_context TO dental_app;
GRANT SELECT ON vw_provider_context      TO dental_app;
GRANT SELECT ON vw_fraud_context         TO dental_app;
GRANT SELECT ON vw_appeal_context        TO dental_app;
GRANT SELECT ON vw_portfolio_context     TO dental_app;

COMMIT;
