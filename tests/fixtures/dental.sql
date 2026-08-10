--
-- PostgreSQL database dump
--

\restrict ruuJxZ53aiTbRkttzfHcbDv407NQvIcRoTj5NqwaaHBE8X4Y8DCpFP3rtb6Ju6g

-- Dumped from database version 15.8
-- Dumped by pg_dump version 15.17

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ada_guidelines; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ada_guidelines (
    guideline_id uuid DEFAULT gen_random_uuid() NOT NULL,
    cdt_code character varying(10),
    cdt_category character varying(50),
    guideline_type character varying(50) NOT NULL,
    guideline_name character varying(300) NOT NULL,
    guideline_version character varying(20) DEFAULT 'CDT-2026'::character varying,
    issuing_body character varying(100) DEFAULT 'ADA'::character varying,
    criteria_checklist jsonb DEFAULT '[]'::jsonb NOT NULL,
    clinical_thresholds jsonb DEFAULT '{}'::jsonb NOT NULL,
    auto_approve_score numeric(4,3) DEFAULT 0.85,
    auto_deny_score numeric(4,3) DEFAULT 0.30,
    citation character varying(500),
    effective_date date DEFAULT '2026-01-01'::date,
    notes text,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT ada_guidelines_type_chk CHECK (((guideline_type)::text = ANY ((ARRAY['clinical_criteria'::character varying, 'coding_standard'::character varying, 'radiograph_guideline'::character varying, 'medical_necessity'::character varying, 'ethical_standard'::character varying])::text[])))
);


--
-- Name: appeals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.appeals (
    appeal_id bigint NOT NULL,
    pred_request_id text NOT NULL,
    tenant_id text NOT NULL,
    status text DEFAULT 'draft'::text NOT NULL,
    rationale text,
    policy_citation text,
    overturn_reason text,
    outcome text,
    submitted_at text,
    decided_at text
);

ALTER TABLE ONLY public.appeals FORCE ROW LEVEL SECURITY;


--
-- Name: appeals_appeal_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.appeals_appeal_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: appeals_appeal_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.appeals_appeal_id_seq OWNED BY public.appeals.appeal_id;


--
-- Name: bundling_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bundling_rules (
    rule_id uuid DEFAULT gen_random_uuid() NOT NULL,
    payer_id character varying(50),
    primary_cdt_code character varying(10) NOT NULL,
    bundled_cdt_code character varying(10) NOT NULL,
    bundling_type character varying(20) NOT NULL,
    scope character varying(50) NOT NULL,
    separable boolean DEFAULT false,
    separation_criteria text,
    denial_reason_code character varying(20),
    policy_section character varying(100),
    effective_date date DEFAULT '2026-01-01'::date,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT bundling_rules_type_chk CHECK (((bundling_type)::text = ANY ((ARRAY['hard'::character varying, 'soft'::character varying])::text[])))
);


--
-- Name: catalogue_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.catalogue_versions (
    catalogue_name character varying(50) NOT NULL,
    version character varying(20),
    effective_date date,
    source text,
    loaded_at timestamp with time zone DEFAULT now(),
    loaded_by character varying(50),
    row_count integer,
    states text[]
);


--
-- Name: cdt_codes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cdt_codes (
    cdt_code character varying(10) NOT NULL,
    description character varying(300) NOT NULL,
    category character varying(50) NOT NULL,
    subcategory character varying(100),
    tooth_specific boolean DEFAULT false,
    surface_specific boolean DEFAULT false,
    arch_specific boolean DEFAULT false,
    quadrant_specific boolean DEFAULT false,
    valid_tooth_ranges text[],
    valid_surfaces text[],
    age_limit_min integer,
    age_limit_max integer,
    requires_xray boolean DEFAULT false,
    requires_perio_chart boolean DEFAULT false,
    requires_narrative boolean DEFAULT false,
    requires_medical_clearance boolean DEFAULT false,
    sedation_code boolean DEFAULT false,
    effective_date date DEFAULT '2026-01-01'::date,
    notes text,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT cdt_codes_category_chk CHECK (((category)::text = ANY ((ARRAY['diagnostic'::character varying, 'preventive'::character varying, 'restorative'::character varying, 'endodontic'::character varying, 'periodontic'::character varying, 'implant'::character varying, 'prosthodontic_removable'::character varying, 'prosthodontic_fixed'::character varying, 'oral_surgery'::character varying, 'orthodontic'::character varying, 'adjunctive'::character varying])::text[])))
);


--
-- Name: clinical_criteria; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.clinical_criteria (
    criteria_id bigint NOT NULL,
    cdt_code character varying(10) NOT NULL,
    payer_id text DEFAULT 'delta_dental'::text NOT NULL,
    criteria_checklist jsonb DEFAULT '[]'::jsonb NOT NULL,
    auto_approve_threshold numeric(4,3) DEFAULT 0.85,
    auto_deny_threshold numeric(4,3) DEFAULT 0.30,
    criteria_version text DEFAULT 'v1'::text
);


--
-- Name: clinical_criteria_criteria_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.clinical_criteria_criteria_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: clinical_criteria_criteria_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.clinical_criteria_criteria_id_seq OWNED BY public.clinical_criteria.criteria_id;


--
-- Name: clinical_evidence; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.clinical_evidence (
    evidence_id text NOT NULL,
    pred_request_id text NOT NULL,
    tenant_id text NOT NULL,
    document_type text,
    document_category text,
    tooth_number integer,
    source_channel text,
    source_system text,
    extracted_fields jsonb DEFAULT '{}'::jsonb NOT NULL,
    confidence_score numeric(4,3),
    extraction_method text,
    received_at text,
    s3_key text,
    CONSTRAINT clinical_evidence_extraction_method_chk CHECK (((extraction_method IS NULL) OR (extraction_method = ANY (ARRAY['deterministic'::text, 'ai_vision'::text, 'caller_supplied'::text, 'none'::text])))),
    CONSTRAINT clinical_evidence_tooth_range CHECK (((tooth_number IS NULL) OR ((tooth_number >= 1) AND (tooth_number <= 32))))
);

ALTER TABLE ONLY public.clinical_evidence FORCE ROW LEVEL SECURITY;


--
-- Name: cob_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cob_rules (
    rule_id uuid DEFAULT gen_random_uuid() NOT NULL,
    rule_code character varying(50) NOT NULL,
    rule_name character varying(200) NOT NULL,
    rule_type character varying(50) NOT NULL,
    description text NOT NULL,
    primary_determination text NOT NULL,
    secondary_determination text,
    documentation_required text,
    notes text,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT cob_rules_type_chk CHECK (((rule_type)::text = ANY ((ARRAY['birthday_rule'::character varying, 'court_order'::character varying, 'medicare_primary'::character varying, 'active_employment'::character varying, 'gender_rule_legacy'::character varying])::text[])))
);


--
-- Name: conditions_library; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.conditions_library (
    condition_code text NOT NULL,
    category text NOT NULL,
    template_text text NOT NULL,
    payer_citation text,
    sla_hours integer DEFAULT 48 NOT NULL,
    assignee text DEFAULT 'provider'::text NOT NULL,
    recommended_action text
);


--
-- Name: cost_estimates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cost_estimates (
    estimate_id uuid DEFAULT gen_random_uuid() NOT NULL,
    pred_request_id text NOT NULL,
    procedure_id text NOT NULL,
    tenant_id character varying(50) NOT NULL,
    cdt_code character varying(10) NOT NULL,
    tooth_number integer,
    fee_submitted numeric(10,2),
    allowed_amount numeric(10,2),
    insurance_pays numeric(10,2),
    patient_pays numeric(10,2),
    deductible_applied numeric(10,2),
    benefit_pct numeric(5,2),
    annual_max_applied boolean DEFAULT false,
    downgrade_applied boolean DEFAULT false,
    downgrade_from character varying(10),
    computed_at timestamp with time zone DEFAULT now()
);

ALTER TABLE ONLY public.cost_estimates FORCE ROW LEVEL SECURITY;


--
-- Name: coverage_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.coverage_rules (
    rule_id bigint NOT NULL,
    payer_id text NOT NULL,
    cdt_code character varying(10) NOT NULL,
    covered boolean DEFAULT true NOT NULL,
    benefit_category text,
    coverage_pct numeric(5,2),
    frequency_limit integer,
    frequency_unit character varying(30),
    frequency_scope character varying(30),
    bundled_with text[],
    bundling_note text,
    bundling_separable boolean,
    downgrade_to_cdt character varying(10),
    downgrade_note text,
    missing_tooth_clause_applies boolean DEFAULT false NOT NULL,
    pred_required boolean DEFAULT false NOT NULL,
    clinical_criteria_required boolean DEFAULT false NOT NULL,
    policy_section text
);


--
-- Name: coverage_rules_rule_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.coverage_rules_rule_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: coverage_rules_rule_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.coverage_rules_rule_id_seq OWNED BY public.coverage_rules.rule_id;


--
-- Name: downgrade_matrix; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.downgrade_matrix (
    downgrade_id uuid DEFAULT gen_random_uuid() NOT NULL,
    payer_id character varying(50),
    plan_type character varying(30),
    billed_cdt_code character varying(10) NOT NULL,
    paid_cdt_code character varying(10) NOT NULL,
    tooth_position character varying(20),
    downgrade_reason text,
    patient_choice_allowed boolean DEFAULT true,
    policy_section character varying(100),
    effective_date date DEFAULT '2026-01-01'::date,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: eligibility_profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.eligibility_profiles (
    pred_request_id text NOT NULL,
    tenant_id text NOT NULL,
    coverage_active boolean DEFAULT false NOT NULL,
    plan_type text,
    annual_maximum numeric(10,2),
    annual_maximum_used numeric(10,2),
    annual_maximum_remaining numeric(10,2),
    deductible_total numeric(10,2),
    deductible_met numeric(10,2),
    deductible_remaining numeric(10,2),
    benefit_pct_preventive numeric(5,2),
    benefit_pct_basic numeric(5,2),
    benefit_pct_major numeric(5,2),
    benefit_pct_implants numeric(5,2),
    implant_coverage boolean DEFAULT false NOT NULL,
    ortho_coverage boolean DEFAULT false NOT NULL,
    waiting_period_met boolean DEFAULT true NOT NULL,
    missing_tooth_clause boolean DEFAULT true NOT NULL,
    missing_tooth_clause_confirmed boolean DEFAULT false NOT NULL,
    coordination_of_benefits boolean DEFAULT false NOT NULL,
    member_id text,
    group_number text,
    payer_id text,
    enrollment_date text,
    pred_required_codes jsonb DEFAULT '[]'::jsonb NOT NULL,
    source text,
    confidence numeric(4,3) DEFAULT 0.0 NOT NULL,
    verified_at text,
    assembled_at text,
    conflicts jsonb DEFAULT '[]'::jsonb NOT NULL
);

ALTER TABLE ONLY public.eligibility_profiles FORCE ROW LEVEL SECURITY;


--
-- Name: evidence_edges; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.evidence_edges (
    edge_id bigint NOT NULL,
    tenant_id text NOT NULL,
    pred_request_id text,
    from_node bigint,
    to_node bigint,
    edge_type text NOT NULL,
    confidence numeric(4,3),
    relationship_type text,
    field text,
    reasoning text,
    CONSTRAINT evidence_edges_type_chk CHECK ((edge_type = ANY (ARRAY['confirms'::text, 'corroborates'::text, 'contradicts'::text, 'supersedes'::text])))
);

ALTER TABLE ONLY public.evidence_edges FORCE ROW LEVEL SECURITY;


--
-- Name: evidence_edges_edge_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.evidence_edges_edge_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: evidence_edges_edge_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.evidence_edges_edge_id_seq OWNED BY public.evidence_edges.edge_id;


--
-- Name: evidence_nodes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.evidence_nodes (
    node_id bigint NOT NULL,
    tenant_id text NOT NULL,
    pred_request_id text,
    node_type text NOT NULL,
    ref_id text,
    attributes jsonb DEFAULT '{}'::jsonb NOT NULL,
    entity_type text,
    entity_id text,
    properties jsonb DEFAULT '{}'::jsonb NOT NULL,
    confidence numeric(4,3),
    source text
);

ALTER TABLE ONLY public.evidence_nodes FORCE ROW LEVEL SECURITY;


--
-- Name: evidence_nodes_node_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.evidence_nodes_node_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: evidence_nodes_node_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.evidence_nodes_node_id_seq OWNED BY public.evidence_nodes.node_id;


--
-- Name: fee_schedules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fee_schedules (
    schedule_id uuid DEFAULT gen_random_uuid() NOT NULL,
    payer_id character varying(50) NOT NULL,
    plan_type character varying(30),
    cdt_code character varying(10) NOT NULL,
    state character varying(2) DEFAULT 'GA'::character varying NOT NULL,
    zip_code character varying(10),
    allowed_amount numeric(10,2) NOT NULL,
    effective_date date DEFAULT '2026-01-01'::date,
    source character varying(50) DEFAULT 'estimated'::character varying,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT fee_schedules_source_chk CHECK ((((source)::text = ANY ((ARRAY['estimated'::character varying, 'payer_published'::character varying, 'contracted'::character varying, 'cms_medicare'::character varying])::text[])) OR ((source)::text ~ '^[a-z]{2}_medicaid_spa_[a-z0-9_]+$'::text) OR ((source)::text ~ '^[a-z]{2}_medicaid_estimated$'::text)))
);


--
-- Name: frequency_limits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.frequency_limits (
    limit_id uuid DEFAULT gen_random_uuid() NOT NULL,
    payer_id character varying(50),
    plan_type character varying(30),
    cdt_code character varying(10) NOT NULL,
    frequency_count integer NOT NULL,
    frequency_period character varying(20) NOT NULL,
    frequency_scope character varying(30) NOT NULL,
    age_limit_min integer,
    age_limit_max integer,
    waiting_days integer DEFAULT 0,
    notes text,
    effective_date date DEFAULT '2026-01-01'::date,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT frequency_limits_period_chk CHECK (((frequency_period)::text = ANY ((ARRAY['per_year'::character varying, 'per_2_years'::character varying, 'per_3_years'::character varying, 'per_4_years'::character varying, 'per_5_years'::character varying, 'per_7_years'::character varying, 'per_lifetime'::character varying])::text[]))),
    CONSTRAINT frequency_limits_scope_chk CHECK (((frequency_scope)::text = ANY ((ARRAY['per_patient'::character varying, 'per_tooth'::character varying, 'per_quadrant'::character varying, 'per_arch'::character varying])::text[])))
);


--
-- Name: medical_history_flags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.medical_history_flags (
    flag_id uuid DEFAULT gen_random_uuid() NOT NULL,
    flag_code character varying(50) NOT NULL,
    flag_name character varying(200) NOT NULL,
    flag_category character varying(50) NOT NULL,
    contraindicated_cdts text[] NOT NULL,
    risk_level character varying(30) NOT NULL,
    icd10_codes text[],
    drug_names text[],
    drug_classes text[],
    documentation_required text,
    clinical_action text,
    notes text,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT medical_flags_category_chk CHECK (((flag_category)::text = ANY ((ARRAY['medication'::character varying, 'medical_condition'::character varying, 'lifestyle'::character varying, 'allergy'::character varying])::text[]))),
    CONSTRAINT medical_flags_risk_chk CHECK (((risk_level)::text = ANY ((ARRAY['absolute_contraindication'::character varying, 'high_risk'::character varying, 'requires_medical_clearance'::character varying, 'document_only'::character varying])::text[])))
);


--
-- Name: overlay_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.overlay_rules (
    overlay_rule_id bigint NOT NULL,
    tenant_id character varying(64) NOT NULL,
    payer_id character varying(64) NOT NULL,
    cdt_code character varying(10) NOT NULL,
    rule_overrides jsonb DEFAULT '{}'::jsonb NOT NULL,
    reason text,
    active boolean DEFAULT true NOT NULL,
    effective_from date DEFAULT CURRENT_DATE NOT NULL,
    effective_to date,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT overlay_rules_effective_range CHECK (((effective_to IS NULL) OR (effective_to >= effective_from))),
    CONSTRAINT overlay_rules_overrides_is_object CHECK ((jsonb_typeof(rule_overrides) = 'object'::text))
);

ALTER TABLE ONLY public.overlay_rules FORCE ROW LEVEL SECURITY;


--
-- Name: overlay_rules_overlay_rule_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.overlay_rules_overlay_rule_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: overlay_rules_overlay_rule_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.overlay_rules_overlay_rule_id_seq OWNED BY public.overlay_rules.overlay_rule_id;


--
-- Name: patients; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.patients (
    patient_id text NOT NULL,
    tenant_id text NOT NULL,
    first_name text,
    last_name text,
    dob text,
    gender text,
    member_id text,
    group_number text,
    payer_id text,
    enrollment_start date,
    active boolean DEFAULT true NOT NULL,
    plan_id text,
    secondary_payer_id text,
    email text,
    mobile_phone text
);

ALTER TABLE ONLY public.patients FORCE ROW LEVEL SECURITY;


--
-- Name: payer_responses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payer_responses (
    response_id bigint NOT NULL,
    pred_request_id text NOT NULL,
    tenant_id text NOT NULL,
    response_type text,
    pred_number text,
    decision text,
    denial_reason text,
    denial_code text,
    policy_citation text,
    received_at text,
    raw_payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    payer_id text,
    plan_type text,
    response_date date,
    approved_amount numeric(10,2),
    valid_from date,
    valid_to date,
    denial_reason_code text,
    denial_reason_text text,
    appeal_deadline date,
    pend_checklist jsonb DEFAULT '[]'::jsonb NOT NULL
);

ALTER TABLE ONLY public.payer_responses FORCE ROW LEVEL SECURITY;


--
-- Name: payer_responses_response_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.payer_responses_response_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: payer_responses_response_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.payer_responses_response_id_seq OWNED BY public.payer_responses.response_id;


--
-- Name: payers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payers (
    payer_id text NOT NULL,
    name text NOT NULL,
    payer_type text,
    x12_payer_id text,
    portal_url text
);


--
-- Name: plans; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.plans (
    plan_id text NOT NULL,
    payer_id text,
    plan_type text,
    group_number text,
    benefit_year_start text,
    annual_maximum numeric(10,2),
    deductible numeric(10,2),
    waiting_period_months integer DEFAULT 12,
    plan_name text,
    deductible_individual numeric(10,2),
    deductible_family numeric(10,2),
    waiting_period_basic_months integer DEFAULT 6,
    waiting_period_major_months integer DEFAULT 12,
    waiting_period_implant_months integer DEFAULT 12,
    implant_coverage boolean DEFAULT true,
    missing_tooth_clause boolean DEFAULT true,
    benefit_pct_preventive numeric(5,2) DEFAULT 100,
    benefit_pct_basic numeric(5,2) DEFAULT 80,
    benefit_pct_major numeric(5,2) DEFAULT 50,
    benefit_pct_implants numeric(5,2) DEFAULT 50
);


--
-- Name: pred_audit_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pred_audit_log (
    audit_id bigint NOT NULL,
    tenant_id text NOT NULL,
    pred_request_id text,
    event_type text NOT NULL,
    actor text,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    criteria_version text,
    occurred_at timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone
);

ALTER TABLE ONLY public.pred_audit_log FORCE ROW LEVEL SECURITY;


--
-- Name: pred_audit_log_audit_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.pred_audit_log_audit_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pred_audit_log_audit_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.pred_audit_log_audit_id_seq OWNED BY public.pred_audit_log.audit_id;


--
-- Name: pred_condition_instances; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pred_condition_instances (
    condition_instance_id bigint NOT NULL,
    pred_request_id text NOT NULL,
    tenant_id text NOT NULL,
    condition_code text NOT NULL,
    status text DEFAULT 'open'::text NOT NULL,
    assignee text,
    due_by timestamp with time zone,
    opened_at timestamp with time zone DEFAULT now() NOT NULL,
    resolved_at timestamp with time zone,
    context jsonb DEFAULT '{}'::jsonb NOT NULL,
    CONSTRAINT pred_condition_status_chk CHECK ((status = ANY (ARRAY['open'::text, 'resolved'::text, 'waived'::text])))
);

ALTER TABLE ONLY public.pred_condition_instances FORCE ROW LEVEL SECURITY;


--
-- Name: pred_condition_instances_condition_instance_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.pred_condition_instances_condition_instance_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pred_condition_instances_condition_instance_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.pred_condition_instances_condition_instance_id_seq OWNED BY public.pred_condition_instances.condition_instance_id;


--
-- Name: pred_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pred_requests (
    pred_request_id text NOT NULL,
    tenant_id text NOT NULL,
    patient_id text,
    provider_npi text,
    payer_id text,
    plan_type text,
    pred_number text,
    status text DEFAULT 'draft'::text NOT NULL,
    decision text,
    total_case_value numeric(10,2) DEFAULT 0,
    submitted_at text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    plan_id text,
    CONSTRAINT pred_requests_status_chk CHECK ((status = ANY (ARRAY['draft'::text, 'submitted'::text, 'assembled'::text, 'pended'::text, 'approved'::text, 'denied'::text, 'appealed'::text])))
);

ALTER TABLE ONLY public.pred_requests FORCE ROW LEVEL SECURITY;


--
-- Name: pred_states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pred_states (
    pred_request_id text NOT NULL,
    tenant_id text NOT NULL,
    coverage_active boolean DEFAULT false NOT NULL,
    annual_max_remaining numeric(10,2),
    implant_covered boolean DEFAULT false NOT NULL,
    waiting_period_met boolean DEFAULT true NOT NULL,
    missing_tooth_clause_triggered boolean DEFAULT false NOT NULL,
    pred_required boolean DEFAULT false NOT NULL,
    criteria_score numeric(4,3) DEFAULT 0.0 NOT NULL,
    medical_necessity_met boolean DEFAULT false NOT NULL,
    clinical_evidence_count integer DEFAULT 0 NOT NULL,
    criteria_met_count integer DEFAULT 0 NOT NULL,
    criteria_total_count integer DEFAULT 0 NOT NULL,
    missing_evidence jsonb DEFAULT '[]'::jsonb NOT NULL,
    no_critical_conflicts boolean DEFAULT true NOT NULL,
    has_bundling_conflict boolean DEFAULT false NOT NULL,
    conflict_count integer DEFAULT 0 NOT NULL,
    conflicts jsonb DEFAULT '[]'::jsonb NOT NULL,
    readiness_flags jsonb DEFAULT '{}'::jsonb NOT NULL,
    status text,
    decision text DEFAULT 'pended'::text NOT NULL,
    decision_confidence numeric(4,3),
    requires_human_review boolean DEFAULT false NOT NULL,
    auto_decision_eligible boolean DEFAULT false NOT NULL,
    open_conditions jsonb DEFAULT '[]'::jsonb NOT NULL,
    decision_trace jsonb DEFAULT '[]'::jsonb NOT NULL,
    updated_at text,
    provider_npi_valid boolean DEFAULT true,
    provider_oig_excluded boolean DEFAULT false,
    provider_specialty character varying(100),
    submission_ready boolean DEFAULT false NOT NULL,
    CONSTRAINT pred_states_decision_chk CHECK ((decision = ANY (ARRAY['approved'::text, 'denied'::text, 'pended'::text]))),
    CONSTRAINT pred_states_decision_trace_is_array CHECK ((jsonb_typeof(decision_trace) = 'array'::text))
);

ALTER TABLE ONLY public.pred_states FORCE ROW LEVEL SECURITY;


--
-- Name: procedure_lines; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.procedure_lines (
    procedure_line_id bigint NOT NULL,
    pred_request_id text NOT NULL,
    tenant_id text NOT NULL,
    line_no integer,
    cdt_code character varying(10) NOT NULL,
    tooth_number integer,
    tooth_surface character varying(10),
    arch character varying(10),
    quadrant character varying(5),
    fee numeric(10,2),
    payer_allowed numeric(10,2),
    requires_pred boolean DEFAULT true NOT NULL,
    description text,
    CONSTRAINT procedure_lines_tooth_range CHECK (((tooth_number IS NULL) OR ((tooth_number >= 1) AND (tooth_number <= 32))))
);

ALTER TABLE ONLY public.procedure_lines FORCE ROW LEVEL SECURITY;


--
-- Name: procedure_lines_procedure_line_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.procedure_lines_procedure_line_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: procedure_lines_procedure_line_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.procedure_lines_procedure_line_id_seq OWNED BY public.procedure_lines.procedure_line_id;


--
-- Name: providers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.providers (
    provider_npi text NOT NULL,
    tenant_id text NOT NULL,
    first_name text,
    last_name text,
    specialty text,
    license_state text,
    license_expiry text,
    credentialed boolean DEFAULT true NOT NULL,
    out_of_network boolean DEFAULT false NOT NULL,
    sanctions boolean DEFAULT false NOT NULL,
    name text,
    credential text,
    taxonomy_code text,
    practice_name text,
    address text,
    phone text,
    network_status text DEFAULT 'in_network'::text,
    oig_excluded boolean DEFAULT false,
    nppes_verified boolean DEFAULT false,
    nppes_verified_at timestamp with time zone,
    source text
);

ALTER TABLE ONLY public.providers FORCE ROW LEVEL SECURITY;


--
-- Name: tenants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tenants (
    tenant_id text NOT NULL,
    name text NOT NULL,
    domain_type text DEFAULT 'dental'::text NOT NULL,
    practice_type text,
    primary_payer text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    address text,
    phone text,
    active boolean DEFAULT true NOT NULL
);


--
-- Name: vw_appeal_context; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_appeal_context WITH (security_invoker='true') AS
 SELECT pr.pred_request_id,
    pr.tenant_id,
    pr.payer_id,
    pr.total_case_value,
    presp.response_id,
    presp.response_type,
    presp.pred_number,
    presp.decision AS payer_decision,
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
    (presp.decision = ANY (ARRAY['denied'::text, 'pended'::text])) AS is_appealable_decision,
    (presp.appeal_deadline - CURRENT_DATE) AS days_to_appeal_deadline,
    ps.decision AS state_decision,
    ps.criteria_score,
    ps.medical_necessity_met,
    ps.has_bundling_conflict,
    ps.open_conditions,
    ps.decision_trace,
    ps.missing_evidence,
    ( SELECT jsonb_agg(jsonb_build_object('condition_code', pci.condition_code, 'status', pci.status, 'assignee', pci.assignee, 'due_by', pci.due_by)) AS jsonb_agg
           FROM public.pred_condition_instances pci
          WHERE ((pci.pred_request_id = pr.pred_request_id) AND (pci.status <> 'resolved'::text))) AS open_condition_instances,
    ( SELECT jsonb_agg(sub.e ORDER BY (sub.e ->> 'occurred_at'::text) DESC) AS jsonb_agg
           FROM ( SELECT jsonb_build_object('event_type', pal.event_type, 'actor', pal.actor, 'occurred_at', pal.occurred_at, 'payload', pal.payload) AS e
                   FROM public.pred_audit_log pal
                  WHERE (pal.pred_request_id = pr.pred_request_id)
                  ORDER BY pal.occurred_at DESC
                 LIMIT 10) sub) AS recent_audit_events
   FROM ((public.pred_requests pr
     LEFT JOIN public.payer_responses presp ON ((presp.pred_request_id = pr.pred_request_id)))
     LEFT JOIN public.pred_states ps ON ((ps.pred_request_id = pr.pred_request_id)));


--
-- Name: vw_clinical_context; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_clinical_context WITH (security_invoker='true') AS
 SELECT pr.pred_request_id,
    pr.tenant_id,
    pr.provider_npi,
    ev.evidence_id,
    ev.document_type,
    ev.document_category,
    ev.tooth_number AS evidence_tooth_number,
    ev.s3_key,
    ev.confidence_score,
    ev.extraction_method,
    ev.received_at,
    ev.extracted_fields,
    (NULLIF((ev.extracted_fields ->> 'bone_loss_mm'::text), ''::text))::numeric AS bone_loss_mm,
    (NULLIF((ev.extracted_fields ->> 'bone_loss_pct'::text), ''::text))::numeric AS bone_loss_pct,
    (NULLIF((ev.extracted_fields ->> 'pocket_depth_max'::text), ''::text))::numeric AS pocket_depth_max,
    (NULLIF((ev.extracted_fields ->> 'sites_gte_5mm'::text), ''::text))::integer AS sites_gte_5mm,
    (NULLIF((ev.extracted_fields ->> 'bleeding_pct'::text), ''::text))::numeric AS bleeding_pct,
    (NULLIF((ev.extracted_fields ->> 'bone_volume_mm3'::text), ''::text))::numeric AS bone_volume_mm3,
    (NULLIF((ev.extracted_fields ->> 'narrative_present'::text), ''::text))::boolean AS narrative_present,
    (ev.extracted_fields ->> 'cdt_codes_noted'::text) AS cdt_codes_noted,
    (ev.extracted_fields ->> 'pred_decision'::text) AS pred_decision,
    (ev.extracted_fields ->> 'image_quality'::text) AS image_quality,
    (ev.extracted_fields ->> 'pathology'::text) AS pathology,
    (ev.extracted_fields ->> 'date_taken'::text) AS date_taken,
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
    ( SELECT array_agg(DISTINCT prl.cdt_code) AS array_agg
           FROM public.procedure_lines prl
          WHERE (prl.pred_request_id = pr.pred_request_id)) AS billed_cdt_codes,
    ( SELECT array_agg(DISTINCT prl.tooth_number) AS array_agg
           FROM public.procedure_lines prl
          WHERE ((prl.pred_request_id = pr.pred_request_id) AND (prl.tooth_number IS NOT NULL))) AS billed_tooth_numbers
   FROM ((public.pred_requests pr
     JOIN public.clinical_evidence ev ON ((ev.pred_request_id = pr.pred_request_id)))
     LEFT JOIN public.pred_states ps ON ((ps.pred_request_id = pr.pred_request_id)));


--
-- Name: vw_coverage_context; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_coverage_context WITH (security_invoker='true') AS
 SELECT pr.pred_request_id,
    pr.tenant_id,
    pr.payer_id,
    pr.plan_id,
    pr.total_case_value,
    prl.line_no,
    prl.cdt_code,
    prl.tooth_number,
    prl.tooth_surface,
    prl.arch,
    prl.quadrant,
    prl.fee,
    prl.payer_allowed,
    prl.requires_pred,
    prl.description AS procedure_description,
    ce.allowed_amount,
    ce.insurance_pays,
    ce.patient_pays,
    ce.deductible_applied,
    ce.benefit_pct,
    ce.annual_max_applied,
    ce.downgrade_applied,
    ce.downgrade_from,
    ep.annual_maximum_remaining,
    ep.implant_coverage AS elig_implant_coverage,
    ep.waiting_period_met,
    ep.coordination_of_benefits,
    ps.has_bundling_conflict,
    ps.conflict_count,
    ps.conflicts,
    ps.open_conditions,
    ps.decision_trace,
    ps.decision,
    ps.pred_required,
    ps.annual_max_remaining AS state_annual_max_remaining
   FROM ((((public.pred_requests pr
     JOIN public.procedure_lines prl ON ((prl.pred_request_id = pr.pred_request_id)))
     LEFT JOIN public.cost_estimates ce ON (((ce.pred_request_id = prl.pred_request_id) AND ((NULLIF("substring"(ce.procedure_id, '^L([0-9]+)$'::text), ''::text))::integer = prl.line_no))))
     LEFT JOIN public.eligibility_profiles ep ON ((ep.pred_request_id = pr.pred_request_id)))
     LEFT JOIN public.pred_states ps ON ((ps.pred_request_id = pr.pred_request_id)));


--
-- Name: vw_documentation_context; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_documentation_context WITH (security_invoker='true') AS
 SELECT pr.pred_request_id,
    pr.tenant_id,
    ev.evidence_id,
    ev.document_type,
    ev.document_category,
    ev.s3_key,
    ev.confidence_score,
    ev.extraction_method,
    ev.received_at,
    (ev.s3_key IS NOT NULL) AS has_document_file,
    (ev.confidence_score < 0.70) AS below_trust_floor,
    ps.missing_evidence,
    ps.open_conditions,
    ps.clinical_evidence_count,
    ps.criteria_score,
    ps.decision,
    ( SELECT array_agg(DISTINCT prl.cdt_code) AS array_agg
           FROM public.procedure_lines prl
          WHERE (prl.pred_request_id = pr.pred_request_id)) AS billed_cdt_codes,
    ( SELECT array_agg(DISTINCT e2.document_type) AS array_agg
           FROM public.clinical_evidence e2
          WHERE (e2.pred_request_id = pr.pred_request_id)) AS document_types_present,
    ( SELECT count(*) AS count
           FROM public.clinical_evidence e2
          WHERE ((e2.pred_request_id = pr.pred_request_id) AND (e2.confidence_score < 0.70))) AS low_confidence_doc_count,
    ( SELECT ((card.extracted_fields ->> 'member_id'::text) IS DISTINCT FROM ep2.member_id)
           FROM (public.clinical_evidence card
             JOIN public.eligibility_profiles ep2 ON ((ep2.pred_request_id = pr.pred_request_id)))
          WHERE ((card.pred_request_id = pr.pred_request_id) AND (card.document_type = 'INSURANCE_CARD'::text))
         LIMIT 1) AS member_id_mismatch
   FROM ((public.pred_requests pr
     JOIN public.clinical_evidence ev ON ((ev.pred_request_id = pr.pred_request_id)))
     LEFT JOIN public.pred_states ps ON ((ps.pred_request_id = pr.pred_request_id)));


--
-- Name: vw_eligibility_context; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_eligibility_context WITH (security_invoker='true') AS
 SELECT pr.pred_request_id,
    pr.tenant_id,
    pr.patient_id,
    pr.provider_npi,
    pr.payer_id,
    pr.plan_id,
    pr.total_case_value,
    ((p.first_name || ' '::text) || p.last_name) AS patient_name,
    p.member_id AS patient_member_id,
    p.group_number AS patient_group_number,
    p.dob,
    p.enrollment_start,
    p.active AS patient_active,
    p.secondary_payer_id,
    pl.plan_name,
    pl.plan_type,
    pl.annual_maximum AS plan_annual_maximum,
    pl.deductible_individual,
    pl.waiting_period_basic_months,
    pl.waiting_period_major_months,
    pl.waiting_period_implant_months,
    pl.implant_coverage AS plan_implant_coverage,
    pl.missing_tooth_clause AS plan_missing_tooth_clause,
    py.name AS payer_name,
    py.payer_type,
    ep.coverage_active,
    ep.annual_maximum AS elig_annual_maximum,
    ep.annual_maximum_used,
    ep.annual_maximum_remaining,
    ep.deductible_total,
    ep.deductible_met,
    ep.deductible_remaining,
    ep.benefit_pct_preventive,
    ep.benefit_pct_basic,
    ep.benefit_pct_major,
    ep.benefit_pct_implants,
    ep.implant_coverage AS elig_implant_coverage,
    ep.ortho_coverage,
    ep.waiting_period_met,
    ep.missing_tooth_clause AS elig_missing_tooth_clause,
    ep.missing_tooth_clause_confirmed,
    ep.coordination_of_benefits,
    ep.member_id AS elig_member_id,
    ep.pred_required_codes,
    ep.confidence AS elig_confidence,
    ep.conflicts AS elig_conflicts,
    ( SELECT ((card.extracted_fields ->> 'member_id'::text) IS DISTINCT FROM ep.member_id)
           FROM public.clinical_evidence card
          WHERE ((card.pred_request_id = pr.pred_request_id) AND (card.document_type = 'INSURANCE_CARD'::text))
         LIMIT 1) AS member_id_mismatch,
    ( SELECT (card.extracted_fields ->> 'member_id'::text)
           FROM public.clinical_evidence card
          WHERE ((card.pred_request_id = pr.pred_request_id) AND (card.document_type = 'INSURANCE_CARD'::text))
         LIMIT 1) AS card_member_id,
    ps.coverage_active AS state_coverage_active,
    ps.annual_max_remaining AS state_annual_max_remaining,
    ps.implant_covered AS state_implant_covered,
    ps.waiting_period_met AS state_waiting_period_met,
    ps.missing_tooth_clause_triggered,
    ps.decision,
    ps.open_conditions
   FROM (((((public.pred_requests pr
     JOIN public.patients p ON ((p.patient_id = pr.patient_id)))
     LEFT JOIN public.plans pl ON ((pl.plan_id = pr.plan_id)))
     LEFT JOIN public.payers py ON ((py.payer_id = pr.payer_id)))
     LEFT JOIN public.eligibility_profiles ep ON ((ep.pred_request_id = pr.pred_request_id)))
     LEFT JOIN public.pred_states ps ON ((ps.pred_request_id = pr.pred_request_id)));


--
-- Name: vw_fraud_context; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_fraud_context WITH (security_invoker='true') AS
 SELECT pr.pred_request_id,
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
    ((prl.fee IS NOT NULL) AND (ce.allowed_amount IS NOT NULL) AND (prl.fee = ce.allowed_amount)) AS fee_equals_allowed,
    ( SELECT (e2.extracted_fields ->> 'cdt_codes_noted'::text)
           FROM public.clinical_evidence e2
          WHERE ((e2.pred_request_id = pr.pred_request_id) AND (e2.document_type = 'CLINICAL_NOTE'::text))
         LIMIT 1) AS cdt_codes_noted,
    ( SELECT (NULLIF((e2.extracted_fields ->> 'bone_loss_mm'::text), ''::text))::numeric AS "nullif"
           FROM public.clinical_evidence e2
          WHERE ((e2.pred_request_id = pr.pred_request_id) AND (e2.document_type = 'XRAY_PA'::text))
         LIMIT 1) AS bone_loss_mm,
    ( SELECT (e2.extracted_fields ->> 'tooth_surface'::text)
           FROM public.clinical_evidence e2
          WHERE ((e2.pred_request_id = pr.pred_request_id) AND (e2.document_type = 'XRAY_PA'::text))
         LIMIT 1) AS xray_tooth_surface,
    ( SELECT count(*) AS count
           FROM public.evidence_edges ee
          WHERE ((ee.pred_request_id = pr.pred_request_id) AND (ee.edge_type = 'confirms'::text))) AS confirms_count,
    ( SELECT count(*) AS count
           FROM public.evidence_edges ee
          WHERE ((ee.pred_request_id = pr.pred_request_id) AND (ee.edge_type = 'contradicts'::text))) AS contradicts_count,
    ( SELECT array_agg(DISTINCT ee.relationship_type) AS array_agg
           FROM public.evidence_edges ee
          WHERE (ee.pred_request_id = pr.pred_request_id)) AS relationship_types,
    ( SELECT array_agg(DISTINCT ee.field) AS array_agg
           FROM public.evidence_edges ee
          WHERE ((ee.pred_request_id = pr.pred_request_id) AND (ee.edge_type = 'contradicts'::text))) AS contradicts_fields,
    ps.has_bundling_conflict,
    ps.conflict_count,
    ps.conflicts,
    ps.no_critical_conflicts,
    ps.decision,
    ps.open_conditions
   FROM (((public.pred_requests pr
     JOIN public.procedure_lines prl ON ((prl.pred_request_id = pr.pred_request_id)))
     LEFT JOIN public.cost_estimates ce ON (((ce.pred_request_id = prl.pred_request_id) AND ((NULLIF("substring"(ce.procedure_id, '^L([0-9]+)$'::text), ''::text))::integer = prl.line_no))))
     LEFT JOIN public.pred_states ps ON ((ps.pred_request_id = pr.pred_request_id)));


--
-- Name: vw_portfolio_context; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_portfolio_context WITH (security_invoker='true') AS
 SELECT pr.tenant_id,
    count(DISTINCT pr.pred_request_id) AS total_pred_requests,
    count(DISTINCT pr.pred_request_id) FILTER (WHERE (ps.decision = 'approved'::text)) AS approved_count,
    count(DISTINCT pr.pred_request_id) FILTER (WHERE (ps.decision = 'denied'::text)) AS denied_count,
    count(DISTINCT pr.pred_request_id) FILTER (WHERE (ps.decision = 'pended'::text)) AS pended_count,
    round(avg(ps.criteria_score), 4) AS avg_criteria_score,
    count(DISTINCT pr.pred_request_id) FILTER (WHERE ps.has_bundling_conflict) AS bundling_conflict_count,
    round(((count(DISTINCT pr.pred_request_id) FILTER (WHERE (ps.decision = 'approved'::text)))::numeric / (NULLIF(count(DISTINCT pr.pred_request_id), 0))::numeric), 4) AS first_pass_approval_rate,
    sum(pr.total_case_value) AS total_billed,
    ( SELECT sum(c.insurance_pays) AS sum
           FROM public.cost_estimates c
          WHERE ((c.tenant_id)::text = pr.tenant_id)) AS total_insurance_pays,
    ( SELECT sum(c.patient_pays) AS sum
           FROM public.cost_estimates c
          WHERE ((c.tenant_id)::text = pr.tenant_id)) AS total_patient_pays,
    sum(pr.total_case_value) FILTER (WHERE (ps.decision = 'denied'::text)) AS revenue_at_risk,
    ( SELECT jsonb_agg(t.*) AS jsonb_agg
           FROM ( SELECT pci.condition_code,
                    count(*) AS n
                   FROM public.pred_condition_instances pci
                  WHERE (pci.tenant_id = pr.tenant_id)
                  GROUP BY pci.condition_code
                  ORDER BY (count(*)) DESC
                 LIMIT 10) t) AS denial_by_condition,
    ( SELECT jsonb_agg(t.*) AS jsonb_agg
           FROM ( SELECT r.payer_id,
                    count(*) AS total,
                    count(*) FILTER (WHERE (s.decision = 'denied'::text)) AS denied,
                    count(*) FILTER (WHERE (s.decision = 'pended'::text)) AS pended,
                    count(*) FILTER (WHERE (s.decision = 'approved'::text)) AS approved
                   FROM (public.pred_requests r
                     LEFT JOIN public.pred_states s ON ((s.pred_request_id = r.pred_request_id)))
                  WHERE (r.tenant_id = pr.tenant_id)
                  GROUP BY r.payer_id
                  ORDER BY (count(*)) DESC) t) AS denial_by_payer,
    ( SELECT round(avg(e.confidence_score), 4) AS round
           FROM public.clinical_evidence e
          WHERE (e.tenant_id = pr.tenant_id)) AS avg_extraction_confidence,
    ( SELECT count(*) AS count
           FROM public.clinical_evidence e
          WHERE ((e.tenant_id = pr.tenant_id) AND (e.confidence_score < 0.70))) AS low_confidence_doc_count
   FROM (public.pred_requests pr
     LEFT JOIN public.pred_states ps ON ((ps.pred_request_id = pr.pred_request_id)))
  GROUP BY pr.tenant_id;


--
-- Name: vw_provider_context; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_provider_context WITH (security_invoker='true') AS
 SELECT pr.pred_request_id,
    pr.tenant_id,
    pr.payer_id,
    prov.provider_npi,
    prov.name AS provider_name,
    prov.first_name AS provider_first_name,
    prov.last_name AS provider_last_name,
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
    prov.source AS provider_source,
    ps.provider_npi_valid,
    ps.provider_oig_excluded,
    ps.provider_specialty AS state_provider_specialty,
    ps.decision,
    ps.open_conditions,
    ( SELECT array_agg(DISTINCT prl.cdt_code) AS array_agg
           FROM public.procedure_lines prl
          WHERE (prl.pred_request_id = pr.pred_request_id)) AS billed_cdt_codes
   FROM ((public.pred_requests pr
     LEFT JOIN public.providers prov ON ((prov.provider_npi = pr.provider_npi)))
     LEFT JOIN public.pred_states ps ON ((ps.pred_request_id = pr.pred_request_id)));


--
-- Name: appeals appeal_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.appeals ALTER COLUMN appeal_id SET DEFAULT nextval('public.appeals_appeal_id_seq'::regclass);


--
-- Name: clinical_criteria criteria_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clinical_criteria ALTER COLUMN criteria_id SET DEFAULT nextval('public.clinical_criteria_criteria_id_seq'::regclass);


--
-- Name: coverage_rules rule_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coverage_rules ALTER COLUMN rule_id SET DEFAULT nextval('public.coverage_rules_rule_id_seq'::regclass);


--
-- Name: evidence_edges edge_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evidence_edges ALTER COLUMN edge_id SET DEFAULT nextval('public.evidence_edges_edge_id_seq'::regclass);


--
-- Name: evidence_nodes node_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evidence_nodes ALTER COLUMN node_id SET DEFAULT nextval('public.evidence_nodes_node_id_seq'::regclass);


--
-- Name: overlay_rules overlay_rule_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.overlay_rules ALTER COLUMN overlay_rule_id SET DEFAULT nextval('public.overlay_rules_overlay_rule_id_seq'::regclass);


--
-- Name: payer_responses response_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payer_responses ALTER COLUMN response_id SET DEFAULT nextval('public.payer_responses_response_id_seq'::regclass);


--
-- Name: pred_audit_log audit_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pred_audit_log ALTER COLUMN audit_id SET DEFAULT nextval('public.pred_audit_log_audit_id_seq'::regclass);


--
-- Name: pred_condition_instances condition_instance_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pred_condition_instances ALTER COLUMN condition_instance_id SET DEFAULT nextval('public.pred_condition_instances_condition_instance_id_seq'::regclass);


--
-- Name: procedure_lines procedure_line_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.procedure_lines ALTER COLUMN procedure_line_id SET DEFAULT nextval('public.procedure_lines_procedure_line_id_seq'::regclass);


--
-- Data for Name: ada_guidelines; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.ada_guidelines (guideline_id, cdt_code, cdt_category, guideline_type, guideline_name, guideline_version, issuing_body, criteria_checklist, clinical_thresholds, auto_approve_score, auto_deny_score, citation, effective_date, notes, created_at) FROM stdin;
05204b70-5f14-4ca5-9923-41f274360a87	D6010	implant	clinical_criteria	Endosteal Implant Placement	CDT-2026	ADA	[{"id": "bone_loss_xray", "text": "Periapical X-ray showing bone loss >=3mm", "weight": 0.40, "required": true, "data_source": "xray"}, {"id": "edentulous_site", "text": "Edentulous site confirmed radiographically", "weight": 0.30, "required": true, "data_source": "xray"}, {"id": "clinical_narrative", "text": "Clinical narrative supporting implant need", "weight": 0.20, "required": false, "data_source": "clinical_note"}, {"id": "cbct_analysis", "text": "CBCT bone volume and density analysis", "weight": 0.10, "required": false, "data_source": "cbct"}]	{"age_min": 18, "auto_deny_score": 0.30, "bone_loss_mm_min": 3.0, "auto_approve_score": 0.85}	0.850	0.300	ADA CDT-2026 D6010; AAOMS Clinical Practice Guidelines for Implant Dentistry 2024	2026-01-01	\N	2026-08-04 18:07:57.313762+00
b7743530-7bca-4841-ac73-1308143f1aa8	D7953	oral_surgery	clinical_criteria	Bone Replacement Graft for Ridge Preservation	CDT-2026	ADA	[{"id": "bone_loss_xray", "text": "X-ray showing bone loss >=3mm at graft site", "weight": 0.50, "required": true, "data_source": "xray"}, {"id": "clinical_narrative", "text": "Narrative explaining graft necessity independent of implant", "weight": 0.30, "required": true, "data_source": "clinical_note"}, {"id": "cbct_bone_volume", "text": "CBCT showing inadequate bone volume", "weight": 0.20, "required": false, "data_source": "cbct"}]	{"auto_deny_score": 0.30, "bone_loss_mm_min": 3.0, "auto_approve_score": 0.85}	0.850	0.300	ADA CDT-2026 D7953; ADA Position Statement on Ridge Preservation 2023	2026-01-01	\N	2026-08-04 18:07:57.313762+00
86f7b0f6-49b4-46b8-8f3b-41eaaf0c01a7	D4260	periodontic	clinical_criteria	Osseous Surgery â€” Four or More Teeth per Quadrant	CDT-2026	AAP	[{"id": "pocket_depth_5mm", "text": "Pocket depth >=5mm documented in 6 or more sites", "weight": 0.40, "required": true, "data_source": "perio_chart"}, {"id": "bone_loss_25pct", "text": "Radiographic bone loss >=25 percent", "weight": 0.30, "required": true, "data_source": "xray"}, {"id": "perio_chart_current", "text": "Current periodontal chart within 6 months", "weight": 0.20, "required": true, "data_source": "perio_chart"}, {"id": "prior_srp_documented", "text": "Prior scaling and root planing documented", "weight": 0.10, "required": false, "data_source": "clinical_note"}]	{"sites_min": 6, "bone_loss_pct_min": 25, "auto_approve_score": 0.85, "pocket_depth_mm_min": 5}	0.850	0.300	ADA CDT-2026 D4260; AAP Clinical Practice Guidelines for Periodontitis Surgery 2022; AAP Staging and Grading System 2018	2026-01-01	\N	2026-08-04 18:07:57.313762+00
3db126ef-26de-447f-9e79-3492afa51676	D4341	periodontic	clinical_criteria	Periodontal Scaling and Root Planing	CDT-2026	AAP	[{"id": "pocket_depth_4mm", "text": "Pocket depth >=4mm in 4 or more teeth per quadrant", "weight": 0.50, "required": true, "data_source": "perio_chart"}, {"id": "perio_chart_current", "text": "Current periodontal chart documenting subgingival calculus", "weight": 0.50, "required": true, "data_source": "perio_chart"}]	{"auto_deny_score": 0.30, "auto_approve_score": 0.80, "pocket_depth_mm_min": 4}	0.800	0.300	ADA CDT-2026 D4341; AAP Guidelines for Periodontal Therapy 2021	2026-01-01	\N	2026-08-04 18:07:57.313762+00
d3844379-7c64-4972-936e-1b718d9f1dfb	D2750	restorative	clinical_criteria	Crown â€” Porcelain Fused to High Noble Metal	CDT-2026	ADA	[{"id": "xray_decay", "text": "Radiograph confirming decay or fracture requiring full coverage", "weight": 0.60, "required": true, "data_source": "xray"}, {"id": "clinical_note", "text": "Clinical note documenting tooth condition and necessity", "weight": 0.40, "required": true, "data_source": "clinical_note"}]	{"auto_deny_score": 0.30, "auto_approve_score": 0.80}	0.800	0.300	ADA CDT-2026 D2750; ADA Policy on Restorative Materials 2023	2026-01-01	\N	2026-08-04 18:07:57.313762+00
799054e8-0cce-475b-a52e-f21377364d09	D2740	restorative	clinical_criteria	Crown â€” Porcelain/Ceramic	CDT-2026	ADA	[{"id": "xray_decay", "text": "Radiograph confirming decay or fracture requiring full coverage", "weight": 0.60, "required": true, "data_source": "xray"}, {"id": "clinical_note", "text": "Clinical note documenting tooth condition and necessity", "weight": 0.40, "required": true, "data_source": "clinical_note"}]	{"auto_deny_score": 0.30, "auto_approve_score": 0.80}	0.800	0.300	ADA CDT-2026 D2740; ADA Policy on Restorative Materials 2023	2026-01-01	\N	2026-08-04 18:07:57.313762+00
d14b3f16-b3b8-4150-8dc7-3fdbb2dbcba5	D3310	endodontic	clinical_criteria	Endodontic Therapy â€” Anterior Tooth	CDT-2026	AAE	[{"id": "xray_periapical", "text": "Periapical X-ray showing pulp pathology or periapical lesion", "weight": 0.50, "required": true, "data_source": "xray"}, {"id": "pulp_diagnosis", "text": "Clinical note documenting pulp diagnosis (irreversible pulpitis or necrosis)", "weight": 0.50, "required": true, "data_source": "clinical_note"}]	{"auto_approve_score": 0.80}	0.800	0.300	ADA CDT-2026 D3310; AAE Clinical Practice Guidelines 2023	2026-01-01	\N	2026-08-04 18:07:57.313762+00
5a5f04b2-254d-43e7-9053-38e8fc17d860	D3320	endodontic	clinical_criteria	Endodontic Therapy â€” Premolar Tooth	CDT-2026	AAE	[{"id": "xray_periapical", "text": "Periapical X-ray showing pulp pathology or periapical lesion", "weight": 0.50, "required": true, "data_source": "xray"}, {"id": "pulp_diagnosis", "text": "Clinical note documenting pulp diagnosis (irreversible pulpitis or necrosis)", "weight": 0.50, "required": true, "data_source": "clinical_note"}]	{"auto_approve_score": 0.80}	0.800	0.300	ADA CDT-2026 D3320; AAE Clinical Practice Guidelines 2023	2026-01-01	\N	2026-08-04 18:07:57.313762+00
d482845b-2a0b-48c7-8d04-2736fe5811fb	D3330	endodontic	clinical_criteria	Endodontic Therapy â€” Molar Tooth	CDT-2026	AAE	[{"id": "xray_periapical", "text": "Periapical X-ray showing pulp pathology or periapical lesion", "weight": 0.50, "required": true, "data_source": "xray"}, {"id": "pulp_diagnosis", "text": "Clinical note documenting pulp diagnosis (irreversible pulpitis or necrosis)", "weight": 0.50, "required": true, "data_source": "clinical_note"}]	{"auto_approve_score": 0.80}	0.800	0.300	ADA CDT-2026 D3330; AAE Clinical Practice Guidelines 2023	2026-01-01	\N	2026-08-04 18:07:57.313762+00
85a53375-81af-47f1-bc1b-37110362817e	D9220	adjunctive	medical_necessity	Deep Sedation / General Anaesthesia	CDT-2026	ADA	[{"id": "medical_clearance", "text": "Medical history reviewed â€” no absolute contraindications", "weight": 0.50, "required": true, "data_source": "clinical_note"}, {"id": "clinical_necessity", "text": "Clinical necessity documented â€” patient cannot tolerate procedure under local anaesthesia", "weight": 0.50, "required": true, "data_source": "clinical_note"}]	{"auto_approve_score": 0.80}	0.800	0.300	ADA CDT-2026 D9220; ADA Guidelines for Teaching Pain Control 2023	2026-01-01	\N	2026-08-04 18:07:57.313762+00
\.


--
-- Data for Name: appeals; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.appeals (appeal_id, pred_request_id, tenant_id, status, rationale, policy_citation, overturn_reason, outcome, submitted_at, decided_at) FROM stdin;
\.


--
-- Data for Name: bundling_rules; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.bundling_rules (rule_id, payer_id, primary_cdt_code, bundled_cdt_code, bundling_type, scope, separable, separation_criteria, denial_reason_code, policy_section, effective_date, created_at) FROM stdin;
9902b843-5df8-4db1-8ebf-a5f13162d136	\N	D2950	D2710	hard	same_tooth_same_date	f	\N	97	ADA coding standard â€” buildup included in crown preparation	2026-01-01	2026-08-04 18:07:58.087075+00
e5f8368c-cd13-4c79-a1a9-a4fbadfab3ae	\N	D2950	D2720	hard	same_tooth_same_date	f	\N	97	ADA coding standard â€” buildup included in crown preparation	2026-01-01	2026-08-04 18:07:58.108727+00
8bf3c116-92a4-4105-b0e5-243143744328	\N	D2950	D2721	hard	same_tooth_same_date	f	\N	97	ADA coding standard â€” buildup included in crown preparation	2026-01-01	2026-08-04 18:07:58.128973+00
fd822313-9063-46c6-a34d-39e703f22e7f	\N	D2950	D2722	hard	same_tooth_same_date	f	\N	97	ADA coding standard â€” buildup included in crown preparation	2026-01-01	2026-08-04 18:07:58.150029+00
5debbb90-2ba9-4b87-9a78-9b40905469ff	\N	D2950	D2740	hard	same_tooth_same_date	f	\N	97	ADA coding standard â€” buildup included in crown preparation	2026-01-01	2026-08-04 18:07:58.175018+00
76b13b23-12ed-4c47-b5e9-a7345ef647ad	\N	D2950	D2750	hard	same_tooth_same_date	f	\N	97	ADA coding standard â€” buildup included in crown preparation	2026-01-01	2026-08-04 18:07:58.195241+00
9df397de-f3d4-427d-b346-38fde18f5d28	\N	D2950	D2751	hard	same_tooth_same_date	f	\N	97	ADA coding standard â€” buildup included in crown preparation	2026-01-01	2026-08-04 18:07:58.215522+00
c397ad3e-4941-417f-bde3-e53cd51ef127	\N	D2950	D2752	hard	same_tooth_same_date	f	\N	97	ADA coding standard â€” buildup included in crown preparation	2026-01-01	2026-08-04 18:07:58.236227+00
961d7a2c-700b-4b89-a923-f83b81075587	\N	D2950	D2780	hard	same_tooth_same_date	f	\N	97	ADA coding standard â€” buildup included in crown preparation	2026-01-01	2026-08-04 18:07:58.257495+00
85e7ad64-7a2e-4b20-b53f-30aaefc0cee0	\N	D2950	D2781	hard	same_tooth_same_date	f	\N	97	ADA coding standard â€” buildup included in crown preparation	2026-01-01	2026-08-04 18:07:58.278484+00
352ec9fa-c890-4965-bb08-4f69ac3d64a0	\N	D2950	D2782	hard	same_tooth_same_date	f	\N	97	ADA coding standard â€” buildup included in crown preparation	2026-01-01	2026-08-04 18:07:58.298995+00
aa927196-b200-4308-99fd-edf081d5bed0	\N	D2950	D2790	hard	same_tooth_same_date	f	\N	97	ADA coding standard â€” buildup included in crown preparation	2026-01-01	2026-08-04 18:07:58.320253+00
572480ec-80dd-49f1-a8ec-cf52c7c16746	\N	D0210	D0272	hard	same_date	f	\N	97	FMX includes bitewings	2026-01-01	2026-08-04 18:07:58.341972+00
84a98262-e250-40b6-a785-96592e86a785	\N	D0210	D0274	hard	same_date	f	\N	97	FMX includes 4 bitewings	2026-01-01	2026-08-04 18:07:58.363+00
63c449d2-13ce-4d02-9e50-0642a613b083	\N	D4341	D1110	hard	same_date	f	\N	97	SRP and prophylaxis not payable same date	2026-01-01	2026-08-04 18:07:58.386236+00
bff40bd9-c8a4-4793-9252-235475d4a8c5	\N	D4342	D1110	hard	same_date	f	\N	97	SRP and prophylaxis not payable same date	2026-01-01	2026-08-04 18:07:58.407028+00
b6195278-1309-4a2b-97c2-685e1b63064f	\N	D0272	D0274	hard	same_date	f	\N	97	Cannot bill two bitewing codes same date	2026-01-01	2026-08-04 18:07:58.428726+00
e38ce03f-1002-4819-bc1e-4948e905e213	delta_dental	D7953	D6010	soft	same_site_within_30_days	t	Requires: (1) PA X-ray showing bone loss >=3mm documented separately, (2) clinical narrative explaining bone graft necessity independent of implant placement, (3) CBCT bone volume analysis if available. Appeal success rate approximately 65 percent when documented.	97	D.7.4	2026-01-01	2026-08-04 18:07:58.453243+00
4c6d630a-7329-4628-a826-83cca06b629b	cigna	D7953	D6010	soft	same_site_within_30_days	t	Bone loss documentation and narrative. Cigna more flexible than Delta â€” bone loss X-ray often sufficient without separate narrative.	97	CIGNA-DENT-7.2	2026-01-01	2026-08-04 18:07:58.479493+00
2db91640-c70b-4d92-a1a5-c81d7a74c51e	\N	D4260	D4341	soft	same_quad_within_30_days	t	Separate appointment dates at least 4 weeks apart plus documentation of scaling failure and surgical necessity.	97	AAP sequencing standard	2026-01-01	2026-08-04 18:07:58.501528+00
\.


--
-- Data for Name: catalogue_versions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.catalogue_versions (catalogue_name, version, effective_date, source, loaded_at, loaded_by, row_count, states) FROM stdin;
cdt_codes	CDT-2026	2026-01-01	ADA CDT-2026 public	2026-08-06 02:31:53.416924+00	dental_admin	181	{ALL}
ada_guidelines	CDT-2026	2026-01-01	ADA CDT-2026 + AAP 2021-2024	2026-08-06 02:31:53.494402+00	dental_admin	10	{ALL}
bundling_rules	1.0	2026-01-01	Delta/Cigna/MetLife provider manuals	2026-08-06 02:31:53.551921+00	dental_admin	20	{ALL}
frequency_limits	1.0	2026-01-01	Delta/Cigna/MetLife provider manuals	2026-08-06 02:31:53.611925+00	dental_admin	27	{ALL}
downgrade_matrix	1.0	2026-01-01	Delta/Cigna/MetLife provider manuals	2026-08-06 02:31:53.670909+00	dental_admin	9	{ALL}
conditions_library	1.0	2026-01-01	Accord Dental internal	2026-08-06 02:31:53.784161+00	dental_admin	50	{ALL}
medical_history_flags	1.0	2026-01-01	ADA guidelines + OpenFDA	2026-08-06 02:31:53.843401+00	dental_admin	8	{ALL}
coverage_rules	2.0	2026-01-01	Delta/Cigna/MetLife provider manuals (Tier 1, 14 codes) + ADA category defaults (Tier 2/3, remaining 167). Tier 2/3 rates are standard commercial class defaults, NOT read from each payer's published manual. Sprint 1: extended to 6 payers â€” aetna_dmo/humana_dpo/guardian_dpo are category defaults with documented per-payer overrides, NOT read from their published manuals.	2026-08-06 13:44:51.916146+00	dental_admin	1086	{ALL}
fee_schedules	2.0	2025-07-01	GA: SPA GA-25-0005 (sourced). FL/TX/NC/SC/TN/AL: DERIVED from GA by STATE_MULTIPLIERS in scripts/pull_fee_schedules.py â€” estimated, NOT read from those states published schedules.	2026-08-06 13:44:51.916146+00	dental_admin	1176	{GA,FL,TX,NC,SC,TN,AL}
payers	2.0	2026-08-06	Sprint 1 â€” expanded from 3 to 6 payers for LP support. Plan terms are representative commercial structures, not contracted rate sheets.	2026-08-06 13:44:51.916146+00	dental_app	6	{ALL}
\.


--
-- Data for Name: cdt_codes; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.cdt_codes (cdt_code, description, category, subcategory, tooth_specific, surface_specific, arch_specific, quadrant_specific, valid_tooth_ranges, valid_surfaces, age_limit_min, age_limit_max, requires_xray, requires_perio_chart, requires_narrative, requires_medical_clearance, sedation_code, effective_date, notes, created_at) FROM stdin;
D0120	Periodic oral evaluation â€” established patient	diagnostic	evaluation	f	f	f	f	\N	\N	\N	\N	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D0140	Limited oral evaluation â€” problem focused	diagnostic	evaluation	f	f	f	f	\N	\N	\N	\N	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D0145	Oral evaluation, patient under 3 years	diagnostic	evaluation	f	f	f	f	\N	\N	\N	3	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D0150	Comprehensive oral evaluation â€” new or established patient	diagnostic	evaluation	f	f	f	f	\N	\N	\N	\N	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D0160	Detailed and extensive oral evaluation â€” problem focused	diagnostic	evaluation	f	f	f	f	\N	\N	\N	\N	f	f	t	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D0170	Re-evaluation â€” limited, problem focused	diagnostic	evaluation	f	f	f	f	\N	\N	\N	\N	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D0180	Comprehensive periodontal evaluation	diagnostic	evaluation	f	f	f	f	\N	\N	\N	\N	f	t	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D0210	Intraoral â€” complete series of radiographic images	diagnostic	radiograph	f	f	f	f	\N	\N	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D0220	Intraoral â€” periapical first radiographic image	diagnostic	radiograph	t	f	f	f	\N	\N	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D0230	Intraoral â€” periapical each additional radiographic image	diagnostic	radiograph	t	f	f	f	\N	\N	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D0240	Intraoral â€” occlusal radiographic image	diagnostic	radiograph	f	f	f	f	\N	\N	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D0272	Bitewings â€” two radiographic images	diagnostic	radiograph	f	f	f	f	\N	\N	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D0273	Bitewings â€” three radiographic images	diagnostic	radiograph	f	f	f	f	\N	\N	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D0274	Bitewings â€” four radiographic images	diagnostic	radiograph	f	f	f	f	\N	\N	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D0277	Vertical bitewings â€” 7 to 8 radiographic images	diagnostic	radiograph	f	f	f	f	\N	\N	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D0330	Panoramic radiographic image	diagnostic	radiograph	f	f	f	f	\N	\N	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D0364	Cone beam CT capture and interpretation â€” limited field	diagnostic	cbct	f	f	f	f	\N	\N	\N	\N	t	f	t	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D0367	Cone beam CT capture and interpretation â€” full arch	diagnostic	cbct	f	f	f	f	\N	\N	\N	\N	t	f	t	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D0470	Diagnostic casts	diagnostic	models	f	f	f	f	\N	\N	\N	\N	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D0601	Caries risk assessment â€” low risk	diagnostic	assessment	f	f	f	f	\N	\N	\N	\N	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D0602	Caries risk assessment â€” moderate risk	diagnostic	assessment	f	f	f	f	\N	\N	\N	\N	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D0603	Caries risk assessment â€” high risk	diagnostic	assessment	f	f	f	f	\N	\N	\N	\N	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D1110	Prophylaxis â€” adult	preventive	prophylaxis	f	f	f	f	\N	\N	14	\N	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D1120	Prophylaxis â€” child	preventive	prophylaxis	f	f	f	f	\N	\N	\N	13	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D1206	Topical application of fluoride varnish	preventive	fluoride	f	f	f	f	\N	\N	\N	\N	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D1208	Topical application of fluoride â€” excluding varnish	preventive	fluoride	f	f	f	f	\N	\N	\N	\N	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D1310	Nutritional counselling for control of dental disease	preventive	counselling	f	f	f	f	\N	\N	\N	\N	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D1330	Oral hygiene instructions	preventive	counselling	f	f	f	f	\N	\N	\N	\N	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D1351	Sealant â€” per tooth	preventive	sealant	t	f	f	f	\N	\N	\N	15	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D1352	Preventive resin restoration â€” permanent tooth	preventive	sealant	t	f	f	f	\N	\N	\N	15	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D1354	Interim caries arresting medicament application	preventive	sealant	t	f	f	f	\N	\N	\N	\N	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D1516	Space maintainer â€” fixed, bilateral, maxillary	preventive	space_maintainer	f	f	t	f	\N	\N	\N	17	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D1517	Space maintainer â€” fixed, bilateral, mandibular	preventive	space_maintainer	f	f	t	f	\N	\N	\N	17	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D2140	Amalgam â€” one surface, primary or permanent	restorative	amalgam	t	t	f	f	\N	{M,O,D,B,L,F,I}	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D2150	Amalgam â€” two surfaces, primary or permanent	restorative	amalgam	t	t	f	f	\N	{M,O,D,B,L,F,I}	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D2160	Amalgam â€” three surfaces, primary or permanent	restorative	amalgam	t	t	f	f	\N	{M,O,D,B,L,F,I}	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D2161	Amalgam â€” four or more surfaces	restorative	amalgam	t	t	f	f	\N	{M,O,D,B,L,F,I}	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D2330	Resin-based composite â€” one surface, anterior	restorative	composite	t	t	f	f	\N	{M,O,D,B,L,F,I}	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D2331	Resin-based composite â€” two surfaces, anterior	restorative	composite	t	t	f	f	\N	{M,O,D,B,L,F,I}	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D2332	Resin-based composite â€” three surfaces, anterior	restorative	composite	t	t	f	f	\N	{M,O,D,B,L,F,I}	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D2335	Resin-based composite â€” four or more surfaces, anterior	restorative	composite	t	t	f	f	\N	{M,O,D,B,L,F,I}	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D2391	Resin-based composite â€” one surface, posterior	restorative	composite	t	t	f	f	\N	{M,O,D,B,L,F,I}	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D2392	Resin-based composite â€” two surfaces, posterior	restorative	composite	t	t	f	f	\N	{M,O,D,B,L,F,I}	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D2393	Resin-based composite â€” three surfaces, posterior	restorative	composite	t	t	f	f	\N	{M,O,D,B,L,F,I}	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D2394	Resin-based composite â€” four or more surfaces, posterior	restorative	composite	t	t	f	f	\N	{M,O,D,B,L,F,I}	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D2390	Resin-based composite crown, anterior	restorative	composite	t	f	f	f	\N	\N	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D2510	Inlay â€” metallic, one surface	restorative	inlay	t	t	f	f	\N	{M,O,D,B,L,F,I}	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D2542	Onlay â€” metallic, two surfaces	restorative	onlay	t	t	f	f	\N	{M,O,D,B,L,F,I}	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D2610	Inlay â€” porcelain/ceramic, one surface	restorative	inlay	t	t	f	f	\N	{M,O,D,B,L,F,I}	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D2642	Onlay â€” porcelain/ceramic, two surfaces	restorative	onlay	t	t	f	f	\N	{M,O,D,B,L,F,I}	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D2710	Crown â€” resin-based composite, indirect	restorative	crown	t	f	f	f	\N	\N	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D2720	Crown â€” resin with high noble metal	restorative	crown	t	f	f	f	\N	\N	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D2721	Crown â€” resin with predominantly base metal	restorative	crown	t	f	f	f	\N	\N	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D2722	Crown â€” resin with noble metal	restorative	crown	t	f	f	f	\N	\N	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D2740	Crown â€” porcelain/ceramic	restorative	crown	t	f	f	f	\N	\N	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D2750	Crown â€” porcelain fused to high noble metal	restorative	crown	t	f	f	f	\N	\N	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D2751	Crown â€” porcelain fused to predominantly base metal	restorative	crown	t	f	f	f	\N	\N	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D2752	Crown â€” porcelain fused to noble metal	restorative	crown	t	f	f	f	\N	\N	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D2780	Crown â€” 3/4 cast high noble metal	restorative	crown	t	f	f	f	\N	\N	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D2781	Crown â€” 3/4 cast predominantly base metal	restorative	crown	t	f	f	f	\N	\N	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D2782	Crown â€” 3/4 cast noble metal	restorative	crown	t	f	f	f	\N	\N	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D2790	Crown â€” full cast high noble metal	restorative	crown	t	f	f	f	\N	\N	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D2791	Crown â€” full cast predominantly base metal	restorative	crown	t	f	f	f	\N	\N	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D2792	Crown â€” full cast noble metal	restorative	crown	t	f	f	f	\N	\N	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D2910	Re-cement or re-bond inlay, onlay or partial coverage restoration	restorative	repair	t	f	f	f	\N	\N	\N	\N	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D2920	Re-cement or re-bond crown	restorative	repair	t	f	f	f	\N	\N	\N	\N	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D2929	Prefabricated porcelain/ceramic crown â€” primary tooth	restorative	crown	t	f	f	f	\N	\N	\N	13	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D2930	Prefabricated stainless steel crown â€” primary tooth	restorative	crown	t	f	f	f	\N	\N	\N	13	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D2931	Prefabricated stainless steel crown â€” permanent tooth	restorative	crown	t	f	f	f	\N	\N	\N	\N	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D2940	Protective restoration	restorative	temporary	t	f	f	f	\N	\N	\N	\N	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D2950	Core buildup, including any pins when required	restorative	buildup	t	f	f	f	\N	\N	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D2951	Pin retention â€” per tooth, in addition to restoration	restorative	buildup	t	f	f	f	\N	\N	\N	\N	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D2952	Post and core in addition to crown, indirectly fabricated	restorative	post_core	t	f	f	f	\N	\N	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D2954	Prefabricated post and core in addition to crown	restorative	post_core	t	f	f	f	\N	\N	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D3110	Pulp cap â€” direct, excluding final restoration	endodontic	pulp_cap	t	f	f	f	\N	\N	\N	\N	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D3120	Pulp cap â€” indirect, excluding final restoration	endodontic	pulp_cap	t	f	f	f	\N	\N	\N	\N	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D3220	Therapeutic pulpotomy â€” excluding final restoration	endodontic	pulpotomy	t	f	f	f	\N	\N	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D3221	Pulpal debridement, primary and permanent teeth	endodontic	pulpotomy	t	f	f	f	\N	\N	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D3310	Endodontic therapy, anterior tooth	endodontic	root_canal	t	f	f	f	{6-11,22-27}	\N	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D3320	Endodontic therapy, premolar tooth	endodontic	root_canal	t	f	f	f	{4-5,12-13,20-21,28-29}	\N	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D3330	Endodontic therapy, molar tooth	endodontic	root_canal	t	f	f	f	{1-3,14-16,17-19,30-32}	\N	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D3346	Retreatment of previous root canal therapy â€” anterior	endodontic	retreatment	t	f	f	f	{6-11,22-27}	\N	\N	\N	t	f	t	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D3347	Retreatment of previous root canal therapy â€” premolar	endodontic	retreatment	t	f	f	f	{4-5,12-13,20-21,28-29}	\N	\N	\N	t	f	t	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D3348	Retreatment of previous root canal therapy â€” molar	endodontic	retreatment	t	f	f	f	{1-3,14-16,17-19,30-32}	\N	\N	\N	t	f	t	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D3410	Apicoectomy â€” anterior	endodontic	surgical	t	f	f	f	{6-11,22-27}	\N	\N	\N	t	f	t	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D3421	Apicoectomy â€” premolar, first root	endodontic	surgical	t	f	f	f	{4-5,12-13,20-21,28-29}	\N	\N	\N	t	f	t	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D3425	Apicoectomy â€” molar, first root	endodontic	surgical	t	f	f	f	{1-3,14-16,17-19,30-32}	\N	\N	\N	t	f	t	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D3430	Retrograde filling â€” per root	endodontic	surgical	t	f	f	f	\N	\N	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D4210	Gingivectomy or gingivoplasty â€” four or more teeth per quadrant	periodontic	surgical	f	f	f	t	\N	\N	\N	\N	t	t	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D4211	Gingivectomy or gingivoplasty â€” one to three teeth per quadrant	periodontic	surgical	f	f	f	t	\N	\N	\N	\N	t	t	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D4240	Gingival flap procedure â€” four or more teeth per quadrant	periodontic	surgical	f	f	f	t	\N	\N	\N	\N	t	t	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D4241	Gingival flap procedure â€” one to three teeth per quadrant	periodontic	surgical	f	f	f	t	\N	\N	\N	\N	t	t	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D4249	Clinical crown lengthening â€” hard tissue	periodontic	surgical	t	f	f	f	\N	\N	\N	\N	t	f	t	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D4260	Osseous surgery â€” four or more teeth per quadrant	periodontic	surgical	f	f	f	t	\N	\N	\N	\N	t	t	t	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D4261	Osseous surgery â€” one to three teeth per quadrant	periodontic	surgical	f	f	f	t	\N	\N	\N	\N	t	t	t	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D4263	Bone replacement graft â€” retained natural tooth, first site	periodontic	graft	t	f	f	f	\N	\N	\N	\N	t	f	t	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D4264	Bone replacement graft â€” retained natural tooth, each additional	periodontic	graft	t	f	f	f	\N	\N	\N	\N	t	f	t	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D4266	Guided tissue regeneration â€” resorbable barrier, per site	periodontic	graft	t	f	f	f	\N	\N	\N	\N	t	f	t	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D4270	Pedicle soft tissue graft procedure	periodontic	graft	t	f	f	f	\N	\N	\N	\N	f	f	t	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D4341	Periodontal scaling and root planing â€” four or more teeth per quadrant	periodontic	srp	f	f	f	t	\N	\N	\N	\N	f	t	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D4342	Periodontal scaling and root planing â€” one to three teeth per quadrant	periodontic	srp	f	f	f	t	\N	\N	\N	\N	f	t	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D4346	Scaling in presence of generalized moderate gingival inflammation	periodontic	srp	f	f	f	f	\N	\N	\N	\N	f	t	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D4355	Full mouth debridement to enable comprehensive evaluation	periodontic	debridement	f	f	f	f	\N	\N	\N	\N	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D4381	Localized delivery of antimicrobial agents â€” per tooth	periodontic	adjunct	t	f	f	f	\N	\N	\N	\N	f	t	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D4910	Periodontal maintenance	periodontic	maintenance	f	f	f	f	\N	\N	\N	\N	f	t	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D5110	Complete denture â€” maxillary	prosthodontic_removable	complete_denture	f	f	t	f	\N	\N	\N	\N	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D5120	Complete denture â€” mandibular	prosthodontic_removable	complete_denture	f	f	t	f	\N	\N	\N	\N	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D5130	Immediate denture â€” maxillary	prosthodontic_removable	complete_denture	f	f	t	f	\N	\N	\N	\N	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D5140	Immediate denture â€” mandibular	prosthodontic_removable	complete_denture	f	f	t	f	\N	\N	\N	\N	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D5211	Maxillary partial denture â€” resin base	prosthodontic_removable	partial_denture	f	f	t	f	\N	\N	\N	\N	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D5212	Mandibular partial denture â€” resin base	prosthodontic_removable	partial_denture	f	f	t	f	\N	\N	\N	\N	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D5213	Maxillary partial denture â€” cast metal with resin base	prosthodontic_removable	partial_denture	f	f	t	f	\N	\N	\N	\N	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D5214	Mandibular partial denture â€” cast metal with resin base	prosthodontic_removable	partial_denture	f	f	t	f	\N	\N	\N	\N	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D5410	Adjust complete denture â€” maxillary	prosthodontic_removable	adjustment	f	f	t	f	\N	\N	\N	\N	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D5510	Repair broken complete denture base	prosthodontic_removable	repair	f	f	t	f	\N	\N	\N	\N	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D5750	Reline complete maxillary denture â€” laboratory	prosthodontic_removable	reline	f	f	t	f	\N	\N	\N	\N	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D5751	Reline complete mandibular denture â€” laboratory	prosthodontic_removable	reline	f	f	t	f	\N	\N	\N	\N	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D6010	Surgical placement of implant body â€” endosteal implant	implant	surgical	t	f	f	f	\N	\N	18	\N	t	f	t	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D6011	Surgical access to an implant body â€” second stage surgery	implant	surgical	t	f	f	f	\N	\N	18	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D6012	Surgical placement of interim implant body	implant	surgical	t	f	f	f	\N	\N	18	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D6013	Surgical placement of mini implant	implant	surgical	t	f	f	f	\N	\N	18	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D6040	Surgical placement â€” eposteal implant	implant	surgical	t	f	f	f	\N	\N	18	\N	t	f	t	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D6050	Surgical placement â€” transosteal implant	implant	surgical	t	f	f	f	\N	\N	18	\N	t	f	t	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D6055	Connecting bar â€” implant or abutment supported	implant	abutment	f	f	f	f	\N	\N	18	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D6056	Prefabricated abutment â€” includes modification and placement	implant	abutment	t	f	f	f	\N	\N	18	\N	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D6057	Custom fabricated abutment â€” includes placement	implant	abutment	t	f	f	f	\N	\N	18	\N	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D6058	Abutment supported porcelain/ceramic crown	implant	crown	t	f	f	f	\N	\N	18	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D6059	Abutment supported porcelain fused to metal crown â€” high noble	implant	crown	t	f	f	f	\N	\N	18	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D6065	Implant supported porcelain/ceramic crown	implant	crown	t	f	f	f	\N	\N	18	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D6066	Implant supported crown â€” porcelain fused to high noble alloys	implant	crown	t	f	f	f	\N	\N	18	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D6067	Implant supported crown â€” high noble alloys	implant	crown	t	f	f	f	\N	\N	18	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D6080	Implant maintenance procedures	implant	maintenance	f	f	f	f	\N	\N	18	\N	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D6104	Bone graft at time of implant placement	implant	graft	t	f	f	f	\N	\N	18	\N	t	f	t	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D6190	Radiographic/surgical implant index	implant	planning	f	f	f	f	\N	\N	18	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D6210	Pontic â€” cast high noble metal	prosthodontic_fixed	pontic	t	f	f	f	\N	\N	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D6240	Pontic â€” porcelain fused to high noble metal	prosthodontic_fixed	pontic	t	f	f	f	\N	\N	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D6245	Pontic â€” porcelain/ceramic	prosthodontic_fixed	pontic	t	f	f	f	\N	\N	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D6740	Retainer crown â€” porcelain/ceramic	prosthodontic_fixed	retainer	t	f	f	f	\N	\N	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D6750	Retainer crown â€” porcelain fused to high noble metal	prosthodontic_fixed	retainer	t	f	f	f	\N	\N	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D6930	Re-cement or re-bond fixed partial denture	prosthodontic_fixed	repair	t	f	f	f	\N	\N	\N	\N	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D7111	Extraction â€” coronal remnants, primary tooth	oral_surgery	extraction	t	f	f	f	\N	\N	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D7140	Extraction â€” erupted tooth or exposed root	oral_surgery	extraction	t	f	f	f	\N	\N	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D7210	Extraction â€” erupted tooth requiring bone removal and/or sectioning	oral_surgery	surgical_extraction	t	f	f	f	\N	\N	\N	\N	t	f	t	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D7220	Removal of impacted tooth â€” soft tissue	oral_surgery	impaction	t	f	f	f	\N	\N	\N	\N	t	f	t	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D7230	Removal of impacted tooth â€” partially bony	oral_surgery	impaction	t	f	f	f	\N	\N	\N	\N	t	f	t	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D7240	Removal of impacted tooth â€” completely bony	oral_surgery	impaction	t	f	f	f	\N	\N	\N	\N	t	f	t	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D7241	Removal of impacted tooth â€” completely bony with complications	oral_surgery	impaction	t	f	f	f	\N	\N	\N	\N	t	f	t	t	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D7250	Removal of residual tooth roots â€” cutting procedure	oral_surgery	surgical_extraction	t	f	f	f	\N	\N	\N	\N	t	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D7280	Exposure of an unerupted tooth	oral_surgery	exposure	t	f	f	f	\N	\N	\N	\N	t	f	t	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D7285	Incisional biopsy of oral tissue â€” hard	oral_surgery	biopsy	f	f	f	f	\N	\N	\N	\N	t	f	t	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D7286	Incisional biopsy of oral tissue â€” soft	oral_surgery	biopsy	f	f	f	f	\N	\N	\N	\N	f	f	t	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D7310	Alveoloplasty in conjunction with extractions â€” four or more teeth	oral_surgery	alveoloplasty	f	f	f	t	\N	\N	\N	\N	t	f	t	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D7320	Alveoloplasty not in conjunction with extractions	oral_surgery	alveoloplasty	f	f	f	t	\N	\N	\N	\N	t	f	t	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D7510	Incision and drainage of abscess â€” intraoral soft tissue	oral_surgery	abscess	f	f	f	f	\N	\N	\N	\N	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D7953	Bone replacement graft for ridge preservation â€” per site	oral_surgery	graft	t	f	f	f	\N	\N	\N	\N	t	f	t	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D7960	Frenulectomy â€” separate procedure	oral_surgery	frenectomy	f	f	f	f	\N	\N	\N	\N	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D8010	Limited orthodontic treatment â€” primary dentition	orthodontic	limited	f	f	f	f	\N	\N	\N	12	f	f	t	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D8020	Limited orthodontic treatment â€” transitional dentition	orthodontic	limited	f	f	f	f	\N	\N	\N	14	f	f	t	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D8030	Limited orthodontic treatment â€” adolescent dentition	orthodontic	limited	f	f	f	f	\N	\N	\N	\N	f	f	t	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D8040	Limited orthodontic treatment â€” adult dentition	orthodontic	limited	f	f	f	f	\N	\N	\N	\N	f	f	t	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D8070	Comprehensive orthodontic treatment â€” transitional dentition	orthodontic	comprehensive	f	f	f	f	\N	\N	\N	14	f	f	t	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D8080	Comprehensive orthodontic treatment â€” adolescent dentition	orthodontic	comprehensive	f	f	f	f	\N	\N	12	19	f	f	t	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D8090	Comprehensive orthodontic treatment â€” adult dentition	orthodontic	comprehensive	f	f	f	f	\N	\N	18	\N	f	f	t	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D8210	Removable appliance therapy	orthodontic	appliance	f	f	f	f	\N	\N	\N	\N	f	f	t	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D8220	Fixed appliance therapy	orthodontic	appliance	f	f	f	f	\N	\N	\N	\N	f	f	t	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D8670	Periodic orthodontic treatment visit	orthodontic	visit	f	f	f	f	\N	\N	\N	\N	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D8680	Orthodontic retention â€” removal of appliances	orthodontic	retention	f	f	f	f	\N	\N	\N	\N	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D9110	Palliative treatment of dental pain â€” per visit	adjunctive	palliative	f	f	f	f	\N	\N	\N	\N	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D9210	Local anaesthesia not in conjunction with operative procedure	adjunctive	anaesthesia	f	f	f	f	\N	\N	\N	\N	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D9215	Local anaesthesia in conjunction with operative procedure	adjunctive	anaesthesia	f	f	f	f	\N	\N	\N	\N	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D9220	Deep sedation / general anaesthesia â€” first 15 minutes	adjunctive	sedation	f	f	f	f	\N	\N	\N	\N	f	f	t	t	t	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D9223	Deep sedation / general anaesthesia â€” each 15 minute increment	adjunctive	sedation	f	f	f	f	\N	\N	\N	\N	f	f	t	t	t	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D9230	Inhalation of nitrous oxide / analgesia, anxiolysis	adjunctive	sedation	f	f	f	f	\N	\N	\N	\N	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D9239	Intravenous moderate sedation â€” first 15 minutes	adjunctive	sedation	f	f	f	f	\N	\N	\N	\N	f	f	t	t	t	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D9243	Intravenous moderate sedation â€” each 15 minute increment	adjunctive	sedation	f	f	f	f	\N	\N	\N	\N	f	f	t	t	t	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D9310	Consultation â€” diagnostic service by other than requesting dentist	adjunctive	consultation	f	f	f	f	\N	\N	\N	\N	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D9430	Office visit for observation â€” no other services performed	adjunctive	visit	f	f	f	f	\N	\N	\N	\N	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D9440	Office visit â€” after regularly scheduled hours	adjunctive	visit	f	f	f	f	\N	\N	\N	\N	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D9944	Occlusal guard â€” hard appliance, full arch	adjunctive	appliance	f	f	t	f	\N	\N	\N	\N	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D9951	Occlusal adjustment â€” limited	adjunctive	occlusal	t	f	f	f	\N	\N	\N	\N	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
D9995	Teledentistry â€” synchronous, real-time encounter	adjunctive	teledentistry	f	f	f	f	\N	\N	\N	\N	f	f	f	f	f	2026-01-01	\N	2026-08-04 18:07:38.097111+00
\.


--
-- Data for Name: clinical_criteria; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.clinical_criteria (criteria_id, cdt_code, payer_id, criteria_checklist, auto_approve_threshold, auto_deny_threshold, criteria_version) FROM stdin;
1	D2750	delta_dental	[{"id": "xray_decay", "text": "Radiograph confirming decay", "weight": 0.6, "required": true}, {"id": "clinical_note", "text": "Clinical note", "weight": 0.4, "required": true}]	0.800	0.300	v1
2	D3330	delta_dental	[{"id": "xray_periapical", "text": "Periapical X-ray", "weight": 0.5, "required": true}, {"id": "clinical_note", "text": "Clinical note", "weight": 0.5, "required": true}]	0.800	0.300	v1
3	D4260	delta_dental	[{"id": "pocket_depth_5mm", "text": "Pocket depth >=5mm in 6+ sites", "weight": 0.4, "required": true}, {"id": "bone_loss_30pct", "text": "Bone loss >=25%", "weight": 0.3, "required": true}, {"id": "perio_chart", "text": "Current periodontal chart", "weight": 0.2, "required": true}, {"id": "clinical_narrative", "text": "Clinical narrative", "weight": 0.1, "required": false}]	0.850	0.300	v1
4	D4341	delta_dental	[{"id": "pocket_depth_4mm", "text": "Pocket depth >=4mm", "weight": 0.5, "required": true}, {"id": "perio_chart", "text": "Periodontal chart", "weight": 0.5, "required": true}]	0.800	0.300	v1
5	D6010	delta_dental	[{"id": "bone_loss_xray", "text": "X-ray showing bone loss >=3mm", "weight": 0.4, "required": true}, {"id": "edentulous_site", "text": "Edentulous site confirmed", "weight": 0.3, "required": true}, {"id": "clinical_narrative", "text": "Clinical narrative", "weight": 0.2, "required": false}, {"id": "cbct_analysis", "text": "CBCT analysis", "weight": 0.1, "required": false}]	0.850	0.300	v1
6	D7953	delta_dental	[{"id": "bone_loss_xray", "text": "X-ray showing bone loss >=3mm", "weight": 0.5, "required": true}, {"id": "clinical_narrative", "text": "Narrative explaining graft necessity", "weight": 0.3, "required": true}, {"id": "cbct_bone_volume", "text": "CBCT bone volume", "weight": 0.2, "required": false}]	0.850	0.300	v1
\.


--
-- Data for Name: clinical_evidence; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.clinical_evidence (evidence_id, pred_request_id, tenant_id, document_type, document_category, tooth_number, source_channel, source_system, extracted_fields, confidence_score, extraction_method, received_at, s3_key) FROM stdin;
X12-DA-A02-271-D01	PRED-SIM-DA-A02	suwanee_smiles	X12_271_RESPONSE	eligibility	\N	x12_271	\N	{"payer_id": "delta_dental", "member_id": "DDL-531024-W", "plan_type": "PPO", "group_number": "GRP-44821", "annual_maximum": 2000.0, "deductible_met": 50.0, "coverage_active": true, "enrollment_date": "2019-03-01", "months_enrolled": 89, "deductible_total": 100.0, "implant_coverage": false, "benefit_pct_basic": 80.0, "benefit_pct_major": 50.0, "secondary_payer_id": null, "waiting_period_met": true, "annual_maximum_used": 200.0, "pred_required_codes": ["D2750"], "benefit_pct_implants": 0.0, "deductible_remaining": 50.0, "missing_tooth_clause": true, "benefit_pct_preventive": 100.0, "annual_maximum_remaining": 1800.0, "coordination_of_benefits": false, "missing_tooth_clause_confirmed": false}	0.980	deterministic	2026-08-05T16:18:02.565965+00:00	\N
NOTE-DA-A01-D03	PRED-SIM-DA-A01	suwanee_smiles	CLINICAL_NOTE	clinical	\N	api	\N	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D6010", "D7953", "D6065"], "diagnosis": "Reference: D6010+D7953+D6065 tooth #19. Delta Dental PPO. Bone graft separately documented.", "narrative": "Bone graft documented with PA X-ray showing 4.2mm bone loss. Approved when documentation complete.", "visit_date": "2026-08-05", "treatment_plan": "D6010+D7953+D6065 tooth #19", "cdt_codes_noted": ["D6010", "D6065", "D7953"], "chief_complaint": "Clean Approval â€” Implant + Bone Graft + Crown", "narrative_present": true, "primary_diagnosis": "Reference: D6010+D7953+D6065 tooth #19. Delta Dental PPO. Bone graft separately documented."}	0.900	deterministic	2026-08-06T05:21:09.596876+00:00	suwanee_smiles/DA-A01/DA-A01_CLINICAL_NOTE.pdf
INS-DA-A01-CARD-D04	PRED-SIM-DA-A01	suwanee_smiles	INSURANCE_CARD	eligibility	\N	api	\N	{"payer_id": "delta_dental", "member_id": "DDL-842901-M", "plan_type": "PPO", "group_number": "GRP-44821", "coverage_active": true}	0.950	caller_supplied	2026-08-06T05:21:09.640382+00:00	suwanee_smiles/DA-A01/DA-A01_INSURANCE_CARD.pdf
XRAY-DA-A01-D02	PRED-SIM-DA-A01	suwanee_smiles	XRAY_PA	clinical	19	api	\N	{"pathology": "Edentulous space #19 with healed ridge", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "bone_loss_mm": 4.2, "tooth_number": 19, "bone_loss_pct": 35.0, "image_quality": "DIAGNOSTIC"}	1.000	deterministic	2026-08-06T05:21:09.663377+00:00	suwanee_smiles/DA-A01/DA-A01_PA_XRAY_TOOTH19.pdf
NOTE-DL-A01-D03	PRED-SIM-DL-A01	dallas_dental	CLINICAL_NOTE	clinical	\N	api	\N	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D6010", "D6065"], "diagnosis": "D6010 + D6065 tooth #30. Guardian covers implants at 50% after a 12-month wait, met here.", "narrative": "The counterweight to TB-B01. Identical clinical picture, identical CDT codes, opposite answer â€” because Guardian sells an implant benefit and Aetna's DMO does not. The engine is reading the plan, not the procedure.", "visit_date": "2026-08-06", "treatment_plan": "D6010+D6065 tooth #30", "cdt_codes_noted": ["D6010", "D6065"], "chief_complaint": "Implant Approved â€” Guardian DPPO Texas", "narrative_present": true, "primary_diagnosis": "D6010 + D6065 tooth #30. Guardian covers implants at 50% after a 12-month wait, met here."}	0.900	deterministic	2026-08-06T13:43:06.816066+00:00	dallas_dental/DL-A01/DL-A01_CLINICAL_NOTE.pdf
DA-A02-PRED_LETTER	PRED-SIM-DA-A02	suwanee_smiles	PRED_LETTER	administrative	\N	s3	accord-dental-documents	{"decision": "approved", "pred_number": "PD-DAA02", "denial_reason": "", "pred_decision": "APPROVED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": [], "cdt_codes_reviewed": ["D2750"]}	1.000	deterministic	2026-08-06T05:21:09.741635+00:00	suwanee_smiles/DA-A02/DA-A02_PRED_LETTER_APPROVED.pdf
XRAY-DL-A01-D02	PRED-SIM-DL-A01	dallas_dental	XRAY_PA	clinical	30	api	\N	{"pathology": "Edentulous space #30 with healed ridge", "xray_date": "2026-08-06", "xray_type": "periapical", "date_taken": "2026-08-06", "bone_loss_mm": 4.2, "tooth_number": 30, "bone_loss_pct": 35.0, "image_quality": "DIAGNOSTIC"}	1.000	deterministic	2026-08-06T13:43:06.875572+00:00	dallas_dental/DL-A01/DL-A01_PA_XRAY_TOOTH30.pdf
PMS-DA-A01-SUPERBILL-D00	PRED-SIM-DA-A01	suwanee_smiles	CDT_SUPERBILL	administrative	\N	api	\N	{"fees": [2800.0, 950.0, 1800.0], "arches": ["lower", "lower", "lower"], "payer_id": "delta_dental", "cdt_codes": ["D6010", "D7953", "D6065"], "member_id": "DDL-842901-M", "quadrants": ["LL", "LL", "LL"], "provider_npi": null, "payer_allowed": [null, null, null], "tooth_numbers": [19, 19, 19], "tooth_surfaces": [null, null, null], "provider_out_of_network": false}	0.950	caller_supplied	2026-08-05T16:18:00.474768+00:00	\N
NOTE-DA-A03-D03	PRED-SIM-DA-A03	suwanee_smiles	CLINICAL_NOTE	clinical	\N	api	\N	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D3330", "D2750"], "diagnosis": "D3330 + D2750. Core buildup correctly NOT billed separately.", "visit_date": "2026-08-05", "treatment_plan": "D3330+D2750 tooth #30", "cdt_codes_noted": ["D2750", "D3330"], "chief_complaint": "Clean Approval â€” Root Canal + Crown #30", "narrative_present": false, "primary_diagnosis": "D3330 + D2750. Core buildup correctly NOT billed separately."}	0.750	deterministic	2026-08-06T05:21:09.760412+00:00	suwanee_smiles/DA-A03/DA-A03_CLINICAL_NOTE.pdf
XRAY-DA-A03-D02	PRED-SIM-DA-A03	suwanee_smiles	XRAY_PA	clinical	30	api	\N	{"pathology": "Caries extending to pulp chamber, tooth #30", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "tooth_number": 30, "decay_present": true, "image_quality": "DIAGNOSTIC"}	0.700	deterministic	2026-08-06T05:21:09.780464+00:00	suwanee_smiles/DA-A03/DA-A03_PA_XRAY_TOOTH30.pdf
PMS-DA-A02-SUPERBILL-D00	PRED-SIM-DA-A02	suwanee_smiles	CDT_SUPERBILL	administrative	\N	api	\N	{"fees": [1450.0], "arches": ["upper"], "payer_id": "delta_dental", "cdt_codes": ["D2750"], "member_id": "DDL-531024-W", "quadrants": ["UR"], "provider_npi": null, "payer_allowed": [null], "tooth_numbers": [3], "tooth_surfaces": ["MOD"], "provider_out_of_network": false}	0.950	caller_supplied	2026-08-05T16:18:02.565965+00:00	\N
DA-A03-PRED_LETTER	PRED-SIM-DA-A03	suwanee_smiles	PRED_LETTER	administrative	\N	s3	accord-dental-documents	{"decision": "approved", "pred_number": "PD-DAA03", "denial_reason": "", "pred_decision": "APPROVED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": [], "cdt_codes_reviewed": ["D2750", "D3330"]}	1.000	deterministic	2026-08-06T05:21:09.799200+00:00	suwanee_smiles/DA-A03/DA-A03_PRED_LETTER_APPROVED.pdf
XRAY-DA-B04-D02	PRED-SIM-DA-B04	suwanee_smiles	XRAY_PA	clinical	19	api	\N	{"pathology": "Edentulous space #19 with healed ridge", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "bone_loss_mm": 4.2, "tooth_number": 19, "bone_loss_pct": 35.0, "image_quality": "DIAGNOSTIC"}	1.000	deterministic	2026-08-06T05:21:10.113221+00:00	suwanee_smiles/DA-B04/DA-B04_PA_XRAY_TOOTH19.pdf
PMS-DA-A03-SUPERBILL-D00	PRED-SIM-DA-A03	suwanee_smiles	CDT_SUPERBILL	administrative	\N	api	\N	{"fees": [1200.0, 1450.0], "arches": ["lower", "lower"], "payer_id": "delta_dental", "cdt_codes": ["D3330", "D2750"], "member_id": "DDL-729384-C", "quadrants": ["LR", "LR"], "provider_npi": null, "payer_allowed": [null, null], "tooth_numbers": [30, 30], "tooth_surfaces": [null, "MODBL"], "provider_out_of_network": false}	0.950	caller_supplied	2026-08-05T16:18:04.044097+00:00	\N
DL-A01-PRED_LETTER	PRED-SIM-DL-A01	dallas_dental	PRED_LETTER	administrative	\N	s3	accord-dental-documents	{"decision": "approved", "pred_number": "PD-DLA01", "denial_reason": "", "pred_decision": "APPROVED", "response_date": "2026-08-06", "appeal_deadline": "2027-02-02", "condition_codes": [], "cdt_codes_reviewed": ["D6010", "D6065"]}	1.000	deterministic	2026-08-06T13:43:06.895242+00:00	dallas_dental/DL-A01/DL-A01_PRED_LETTER_APPROVED.pdf
X12-DA-A03-271-D01	PRED-SIM-DA-A03	suwanee_smiles	X12_271_RESPONSE	eligibility	\N	x12_271	\N	{"payer_id": "delta_dental", "member_id": "DDL-729384-C", "plan_type": "PPO", "group_number": "GRP-77103", "annual_maximum": 2000.0, "deductible_met": 50.0, "coverage_active": true, "enrollment_date": "2021-06-01", "months_enrolled": 62, "deductible_total": 50.0, "implant_coverage": false, "benefit_pct_basic": 80.0, "benefit_pct_major": 50.0, "secondary_payer_id": null, "waiting_period_met": true, "annual_maximum_used": 200.0, "pred_required_codes": ["D2750"], "benefit_pct_implants": 0.0, "deductible_remaining": 0.0, "missing_tooth_clause": true, "benefit_pct_preventive": 100.0, "annual_maximum_remaining": 1800.0, "coordination_of_benefits": false, "missing_tooth_clause_confirmed": false}	0.980	deterministic	2026-08-05T16:18:04.044097+00:00	\N
DL-B01-PRED_LETTER	PRED-SIM-DL-B01	dallas_dental	PRED_LETTER	administrative	\N	s3	accord-dental-documents	{"decision": "denied", "pred_number": "PD-DLB01", "denial_reason": "CLINICAL_CRITERIA_NOT_MET", "pred_decision": "DENIED", "response_date": "2026-08-06", "appeal_deadline": "2027-02-02", "condition_codes": ["CLINICAL_CRITERIA_NOT_MET"], "cdt_codes_reviewed": ["D4260"], "denial_reason_text": "CLINICAL_CRITERIA_NOT_MET"}	1.000	deterministic	2026-08-06T13:43:06.971929+00:00	dallas_dental/DL-B01/DL-B01_PRED_LETTER_DENIED.pdf
NOTE-DL-C01-D03	PRED-SIM-DL-C01	dallas_dental	CLINICAL_NOTE	clinical	\N	api	\N	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D2750"], "diagnosis": "D2750 tooth #3, three years after the last crown on the same tooth. Delta allows one per five years.", "narrative": "The cleanest state isolation in the corpus: same payer as Suwanee, same rule, same 1-per-5-years window. Only the fee schedule differs. If this denies in Georgia and approves in Texas, geography leaked into the clinical path.", "visit_date": "2026-08-06", "treatment_plan": "D2750 tooth #3", "cdt_codes_noted": ["D2750"], "chief_complaint": "Crown Frequency Denied â€” Delta Dental in Texas", "narrative_present": true, "primary_diagnosis": "D2750 tooth #3, three years after the last crown on the same tooth. Delta allows one per five years."}	0.900	deterministic	2026-08-06T13:43:06.991753+00:00	dallas_dental/DL-C01/DL-C01_CLINICAL_NOTE.pdf
PMS-DA-A04-SUPERBILL-D00	PRED-SIM-DA-A04	suwanee_smiles	CDT_SUPERBILL	administrative	\N	api	\N	{"fees": [285.0, 285.0, 285.0, 285.0], "arches": ["upper", "upper", "lower", "lower"], "payer_id": "delta_dental", "cdt_codes": ["D4341", "D4341", "D4341", "D4341"], "member_id": "DDL-482019-R", "quadrants": ["UR", "UL", "LR", "LL"], "provider_npi": null, "payer_allowed": [null, null, null, null], "tooth_numbers": [null, null, null, null], "tooth_surfaces": [null, null, null, null], "provider_out_of_network": false}	0.950	caller_supplied	2026-08-05T16:18:05.508836+00:00	\N
DL-C01-PRED_LETTER	PRED-SIM-DL-C01	dallas_dental	PRED_LETTER	administrative	\N	s3	accord-dental-documents	{"decision": "denied", "pred_number": "PD-DLC01", "denial_reason": "FREQUENCY_LIMIT_EXCEEDED", "pred_decision": "DENIED", "response_date": "2026-08-06", "appeal_deadline": "2027-02-02", "condition_codes": ["ELIG_FREQUENCY_EXCEEDED"], "cdt_codes_reviewed": ["D2750"], "denial_reason_text": "FREQUENCY_LIMIT_EXCEEDED"}	1.000	deterministic	2026-08-06T13:43:07.048407+00:00	dallas_dental/DL-C01/DL-C01_PRED_LETTER_DENIED.pdf
NOTE-DL-D01-D03	PRED-SIM-DL-D01	dallas_dental	CLINICAL_NOTE	clinical	\N	api	\N	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D8090"], "diagnosis": "D8090 comprehensive ortho, adult dentition. The Invisalign question, answered from the catalogue.", "narrative": "The question every adult patient asks about Invisalign. Humana's standard plan buys child ortho only â€” D8080 is covered to age 19, D8090 is not covered at all. A $4,500 answer that used to take a phone call.", "visit_date": "2026-08-06", "treatment_plan": "D8090 tooth multiple quadrants", "cdt_codes_noted": ["D8080", "D8090"], "chief_complaint": "Adult Orthodontics Denied â€” Humana Standard Plan", "narrative_present": true, "primary_diagnosis": "D8090 comprehensive ortho, adult dentition. The Invisalign question, answered from the catalogue."}	0.900	deterministic	2026-08-06T13:43:07.067093+00:00	dallas_dental/DL-D01/DL-D01_CLINICAL_NOTE.pdf
DL-D01-PRED_LETTER	PRED-SIM-DL-D01	dallas_dental	PRED_LETTER	administrative	\N	s3	accord-dental-documents	{"decision": "denied", "pred_number": "PD-DLD01", "denial_reason": "ADULT_ORTHO_NOT_COVERED", "pred_decision": "DENIED", "response_date": "2026-08-06", "appeal_deadline": "2027-02-02", "condition_codes": ["ELIG_ADULT_ORTHO_NOT_COVERED"], "cdt_codes_reviewed": ["D8090"], "denial_reason_text": "ADULT_ORTHO_NOT_COVERED"}	1.000	deterministic	2026-08-06T13:43:07.105128+00:00	dallas_dental/DL-D01/DL-D01_PRED_LETTER_DENIED.pdf
DA-A01-PRED_LETTER	PRED-SIM-DA-A01	suwanee_smiles	PRED_LETTER	administrative	\N	s3	accord-dental-documents	{"decision": "pended", "pred_number": "PD-DAA01", "denial_reason": "", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": [], "cdt_codes_reviewed": ["D6010", "D6065", "D7953"]}	1.000	deterministic	2026-08-06T05:21:09.683234+00:00	suwanee_smiles/DA-A01/DA-A01_PRED_LETTER_PENDED.pdf
NOTE-DA-A02-D03	PRED-SIM-DA-A02	suwanee_smiles	CLINICAL_NOTE	clinical	\N	api	\N	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D2750"], "diagnosis": "D2750 crown. X-ray confirms decay. Frequency limit not triggered.", "visit_date": "2026-08-05", "treatment_plan": "D2750 tooth #3", "cdt_codes_noted": ["D2750"], "chief_complaint": "Clean Approval â€” Crown on Tooth #3", "narrative_present": false, "primary_diagnosis": "D2750 crown. X-ray confirms decay. Frequency limit not triggered."}	0.750	deterministic	2026-08-06T05:21:09.703194+00:00	suwanee_smiles/DA-A02/DA-A02_CLINICAL_NOTE.pdf
XRAY-DA-A02-D02	PRED-SIM-DA-A02	suwanee_smiles	XRAY_PA	clinical	3	api	\N	{"pathology": "Caries extending to pulp chamber, tooth #3", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "tooth_number": 3, "decay_present": true, "image_quality": "DIAGNOSTIC"}	0.700	deterministic	2026-08-06T05:21:09.722095+00:00	suwanee_smiles/DA-A02/DA-A02_PA_XRAY_TOOTH3.pdf
X12-DA-A01-271-D01	PRED-SIM-DA-A01	suwanee_smiles	X12_271_RESPONSE	eligibility	\N	x12_271	\N	{"payer_id": "delta_dental", "member_id": "DDL-842901-M", "plan_type": "PPO", "group_number": "GRP-44821", "annual_maximum": 2000.0, "deductible_met": 50.0, "coverage_active": true, "enrollment_date": "2020-01-01", "months_enrolled": 79, "deductible_total": 100.0, "implant_coverage": true, "benefit_pct_basic": 80.0, "benefit_pct_major": 50.0, "secondary_payer_id": null, "waiting_period_met": true, "annual_maximum_used": 200.0, "pred_required_codes": ["D6010", "D7953", "D6065"], "benefit_pct_implants": 50.0, "deductible_remaining": 50.0, "missing_tooth_clause": true, "benefit_pct_preventive": 100.0, "annual_maximum_remaining": 1800.0, "coordination_of_benefits": false, "missing_tooth_clause_confirmed": false}	0.980	deterministic	2026-08-05T16:18:00.474768+00:00	\N
X12-DA-A05-271-D01	PRED-SIM-DA-A05	suwanee_smiles	X12_271_RESPONSE	eligibility	\N	x12_271	\N	{"payer_id": "delta_dental", "member_id": "DDL-901234-P", "plan_type": "PPO", "group_number": "GRP-44821", "annual_maximum": 2000.0, "deductible_met": 0.0, "coverage_active": true, "enrollment_date": "2020-09-01", "months_enrolled": 71, "deductible_total": 0.0, "implant_coverage": false, "benefit_pct_basic": 80.0, "benefit_pct_major": 50.0, "secondary_payer_id": null, "waiting_period_met": true, "annual_maximum_used": 200.0, "pred_required_codes": [], "benefit_pct_implants": 0.0, "deductible_remaining": 0.0, "missing_tooth_clause": true, "benefit_pct_preventive": 100.0, "annual_maximum_remaining": 1800.0, "coordination_of_benefits": false, "missing_tooth_clause_confirmed": false}	0.980	deterministic	2026-08-05T16:18:06.902083+00:00	\N
X12-DA-A04-271-D01	PRED-SIM-DA-A04	suwanee_smiles	X12_271_RESPONSE	eligibility	\N	x12_271	\N	{"payer_id": "delta_dental", "member_id": "DDL-482019-R", "plan_type": "PPO", "group_number": "GRP-55290", "annual_maximum": 2000.0, "deductible_met": 50.0, "coverage_active": true, "enrollment_date": "2022-01-01", "months_enrolled": 55, "deductible_total": 100.0, "implant_coverage": false, "benefit_pct_basic": 80.0, "benefit_pct_major": 50.0, "secondary_payer_id": null, "waiting_period_met": true, "annual_maximum_used": 200.0, "pred_required_codes": [], "benefit_pct_implants": 0.0, "deductible_remaining": 50.0, "missing_tooth_clause": true, "benefit_pct_preventive": 100.0, "annual_maximum_remaining": 1800.0, "coordination_of_benefits": false, "missing_tooth_clause_confirmed": false}	0.980	deterministic	2026-08-05T16:18:05.508836+00:00	\N
X12-DA-B01-271-D01	PRED-SIM-DA-B01	suwanee_smiles	X12_271_RESPONSE	eligibility	\N	x12_271	\N	{"payer_id": "delta_dental", "member_id": "DDL-334891-J", "plan_type": "PPO", "group_number": "GRP-BASIC-01", "annual_maximum": 1500.0, "deductible_met": 50.0, "coverage_active": true, "enrollment_date": "2024-01-01", "months_enrolled": 31, "deductible_total": 50.0, "implant_coverage": false, "benefit_pct_basic": 80.0, "benefit_pct_major": 50.0, "secondary_payer_id": null, "waiting_period_met": true, "annual_maximum_used": 0.0, "pred_required_codes": ["D6010", "D6065"], "benefit_pct_implants": 0.0, "deductible_remaining": 0.0, "missing_tooth_clause": true, "benefit_pct_preventive": 100.0, "annual_maximum_remaining": 1500.0, "coordination_of_benefits": false, "missing_tooth_clause_confirmed": false}	0.980	deterministic	2026-08-05T16:18:08.057502+00:00	\N
DL-U01-CLINICAL_NOTE	PRED-SIM-DL-U01	dallas_dental	CLINICAL_NOTE	clinical	\N	s3	accord-dental-documents	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D0330"], "diagnosis": "D0330 panoramic radiograph. Guardian allows one per three years, none taken in the window.", "narrative": "The multi-state arithmetic in one line: $185 billed, GA allows $185, TX allows $203.50 at the 1.10 multiplier. Preventive at 100%, so the patient owes nothing either way â€” the practice's reimbursement is what moved.", "visit_date": "2026-08-06", "treatment_plan": "D0330 tooth multiple quadrants", "cdt_codes_noted": ["D0330"], "chief_complaint": "Uncontested â€” Panoramic Film, Guardian Texas", "narrative_present": true, "primary_diagnosis": "D0330 panoramic radiograph. Guardian allows one per three years, none taken in the window."}	0.900	deterministic	2026-08-06T13:43:07.124679+00:00	dallas_dental/DL-U01/DL-U01_CLINICAL_NOTE.pdf
PMS-DA-A05-SUPERBILL-D00	PRED-SIM-DA-A05	suwanee_smiles	CDT_SUPERBILL	administrative	\N	api	\N	{"fees": [195.0], "arches": [null], "payer_id": "delta_dental", "cdt_codes": ["D0330"], "member_id": "DDL-901234-P", "quadrants": [null], "provider_npi": null, "payer_allowed": [null], "tooth_numbers": [null], "tooth_surfaces": [null], "provider_out_of_network": false}	0.950	caller_supplied	2026-08-05T16:18:06.902083+00:00	\N
DL-U01-PRED_LETTER	PRED-SIM-DL-U01	dallas_dental	PRED_LETTER	administrative	\N	s3	accord-dental-documents	{"decision": "approved", "pred_number": "PD-DLU01", "denial_reason": "", "pred_decision": "APPROVED", "response_date": "2026-08-06", "appeal_deadline": "2027-02-02", "condition_codes": [], "cdt_codes_reviewed": ["D0330"]}	1.000	deterministic	2026-08-06T13:43:07.163443+00:00	dallas_dental/DL-U01/DL-U01_PRED_LETTER_APPROVED.pdf
NOTE-DA-A04-D03	PRED-SIM-DA-A04	suwanee_smiles	CLINICAL_NOTE	clinical	\N	api	\N	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D4341", "D4341", "D4341", "D4341"], "diagnosis": "D4341 x4. Perio chart supports pocket depths 5-7mm.", "narrative": "Procedures planned: D4341, D4341, D4341, D4341", "visit_date": "2026-08-05", "treatment_plan": "D4341+D4341+D4341+D4341 tooth multiple quadrants", "cdt_codes_noted": ["D4341"], "chief_complaint": "Clean Approval â€” Perio Scaling 4 Quads", "narrative_present": true, "primary_diagnosis": "D4341 x4. Perio chart supports pocket depths 5-7mm."}	0.900	deterministic	2026-08-06T05:21:09.819639+00:00	suwanee_smiles/DA-A04/DA-A04_CLINICAL_NOTE.pdf
PERIO-DA-A04-D02	PRED-SIM-DA-A04	suwanee_smiles	PERIO_CHART	clinical	\N	api	\N	{"exam_date": "2026-08-05", "charted_on": "2026-08-05", "bleeding_pct": 42.0, "sites_charted": 24, "sites_gte_4mm": 8, "sites_gte_5mm": 8, "sites_gte_6mm": 4, "interpretation": "Probing depths support osseous surgery per AAP criteria.", "perio_diagnosis": "Stage III Periodontitis", "pocket_depth_avg": 3.83, "pocket_depth_max": 6.0, "max_pocket_depth_mm": 6, "bleeding_on_probing_pct": 42.0}	0.900	deterministic	2026-08-06T05:21:09.839482+00:00	suwanee_smiles/DA-A04/DA-A04_PERIO_CHART.pdf
PMS-DA-B01-SUPERBILL-D00	PRED-SIM-DA-B01	suwanee_smiles	CDT_SUPERBILL	administrative	\N	api	\N	{"fees": [2800.0, 1800.0], "arches": ["upper", "upper"], "payer_id": "delta_dental", "cdt_codes": ["D6010", "D6065"], "member_id": "DDL-334891-J", "quadrants": ["UL", "UL"], "provider_npi": null, "payer_allowed": [null, null], "tooth_numbers": [14, 14], "tooth_surfaces": [null, null], "provider_out_of_network": false}	0.950	caller_supplied	2026-08-05T16:18:08.057502+00:00	\N
PMS-DA-B03-SUPERBILL-D00	PRED-SIM-DA-B03	suwanee_smiles	CDT_SUPERBILL	administrative	\N	api	\N	{"fees": [1450.0], "arches": ["upper"], "payer_id": "delta_dental", "cdt_codes": ["D2750"], "member_id": "DDL-223847-H", "quadrants": ["UR"], "provider_npi": null, "payer_allowed": [null], "tooth_numbers": [3], "tooth_surfaces": ["MO"], "provider_out_of_network": false}	0.950	caller_supplied	2026-08-05T16:18:10.947658+00:00	\N
PMS-DA-B02-SUPERBILL-D00	PRED-SIM-DA-B02	suwanee_smiles	CDT_SUPERBILL	administrative	\N	api	\N	{"fees": [2800.0, 1800.0], "arches": ["lower", "lower"], "payer_id": "delta_dental", "cdt_codes": ["D6010", "D6065"], "member_id": "DDL-778234-A", "quadrants": ["LL", "LL"], "provider_npi": null, "payer_allowed": [null, null], "tooth_numbers": [19, 19], "tooth_surfaces": [null, null], "provider_out_of_network": false}	0.950	caller_supplied	2026-08-05T16:18:09.511433+00:00	\N
HIST-DA-B03-PRIOR-D00	PRED-SIM-DA-B03	suwanee_smiles	PRED_LETTER_PENDED	administrative	\N	payer_portal	\N	{"member_id": "DDL-223847-H", "prior_services": [{"status": "paid", "cdt_code": "D2750", "tooth_number": 3, "date_of_service": "2023-05-04"}], "open_pred_requests": []}	0.990	deterministic	2026-08-05T16:18:10.947658+00:00	\N
DA-A04-PRED_LETTER	PRED-SIM-DA-A04	suwanee_smiles	PRED_LETTER	administrative	\N	s3	accord-dental-documents	{"decision": "approved", "pred_number": "PD-DAA04", "denial_reason": "", "pred_decision": "APPROVED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": [], "cdt_codes_reviewed": ["D4341"]}	1.000	deterministic	2026-08-06T05:21:09.859261+00:00	suwanee_smiles/DA-A04/DA-A04_PRED_LETTER_APPROVED.pdf
INS-DA-A05-CARD-D02	PRED-SIM-DA-A05	suwanee_smiles	INSURANCE_CARD	eligibility	\N	api	\N	{"payer_id": "delta_dental", "member_id": "DDL-901234-P", "plan_type": "PPO", "group_number": "GRP-44821", "coverage_active": true}	0.950	caller_supplied	2026-08-06T05:21:09.879564+00:00	suwanee_smiles/DA-A05/DA-A05_INSURANCE_CARD.pdf
DA-A05-PRED_LETTER	PRED-SIM-DA-A05	suwanee_smiles	PRED_LETTER	administrative	\N	s3	accord-dental-documents	{"decision": "approved", "pred_number": "PD-DAA05", "denial_reason": "", "pred_decision": "APPROVED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": [], "cdt_codes_reviewed": ["D0330"]}	1.000	deterministic	2026-08-06T05:21:09.899522+00:00	suwanee_smiles/DA-A05/DA-A05_PRED_LETTER_APPROVED.pdf
INS-DA-B01-CARD-D03	PRED-SIM-DA-B01	suwanee_smiles	INSURANCE_CARD	eligibility	\N	api	\N	{"payer_id": "delta_dental", "member_id": "DDL-334891-J", "plan_type": "PPO", "group_number": "GRP-BASIC-01", "coverage_active": true}	0.950	caller_supplied	2026-08-06T05:21:09.917633+00:00	suwanee_smiles/DA-B01/DA-B01_INSURANCE_CARD.pdf
X12-DA-B04-271-D01	PRED-SIM-DA-B04	suwanee_smiles	X12_271_RESPONSE	eligibility	\N	x12_271	\N	{"payer_id": "delta_dental", "member_id": "DDL-558934-R", "plan_type": "PPO", "group_number": "GRP-44821", "annual_maximum": 2000.0, "deductible_met": 50.0, "coverage_active": true, "enrollment_date": "2021-01-01", "months_enrolled": 67, "deductible_total": 100.0, "implant_coverage": true, "benefit_pct_basic": 80.0, "benefit_pct_major": 50.0, "secondary_payer_id": null, "waiting_period_met": true, "annual_maximum_used": 200.0, "pred_required_codes": ["D6010", "D7953"], "benefit_pct_implants": 50.0, "deductible_remaining": 50.0, "missing_tooth_clause": true, "benefit_pct_preventive": 100.0, "annual_maximum_remaining": 1800.0, "coordination_of_benefits": false, "missing_tooth_clause_confirmed": false}	0.980	deterministic	2026-08-05T16:18:12.575516+00:00	\N
XRAY-DA-B01-D02	PRED-SIM-DA-B01	suwanee_smiles	XRAY_PA	clinical	14	api	\N	{"pathology": "Edentulous space #14 with healed ridge", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "bone_loss_mm": 4.2, "tooth_number": 14, "bone_loss_pct": 35.0, "image_quality": "DIAGNOSTIC"}	1.000	deterministic	2026-08-06T05:21:09.937406+00:00	suwanee_smiles/DA-B01/DA-B01_PA_XRAY_TOOTH14.pdf
X12-DA-B03-271-D01	PRED-SIM-DA-B03	suwanee_smiles	X12_271_RESPONSE	eligibility	\N	x12_271	\N	{"payer_id": "delta_dental", "member_id": "DDL-223847-H", "plan_type": "PPO", "group_number": "GRP-77103", "annual_maximum": 2000.0, "deductible_met": 50.0, "coverage_active": true, "enrollment_date": "2018-01-01", "months_enrolled": 103, "deductible_total": 100.0, "implant_coverage": false, "benefit_pct_basic": 80.0, "benefit_pct_major": 50.0, "secondary_payer_id": null, "waiting_period_met": true, "annual_maximum_used": 200.0, "pred_required_codes": ["D2750"], "benefit_pct_implants": 0.0, "deductible_remaining": 50.0, "missing_tooth_clause": true, "benefit_pct_preventive": 100.0, "annual_maximum_remaining": 1800.0, "coordination_of_benefits": false, "missing_tooth_clause_confirmed": false}	0.980	deterministic	2026-08-05T16:18:10.947658+00:00	\N
PMS-DA-B04-SUPERBILL-D00	PRED-SIM-DA-B04	suwanee_smiles	CDT_SUPERBILL	administrative	\N	api	\N	{"fees": [2800.0, 950.0], "arches": ["lower", "lower"], "payer_id": "delta_dental", "cdt_codes": ["D6010", "D7953"], "member_id": "DDL-558934-R", "quadrants": ["LL", "LL"], "provider_npi": null, "payer_allowed": [null, null], "tooth_numbers": [19, 19], "tooth_surfaces": [null, null], "provider_out_of_network": false}	0.950	caller_supplied	2026-08-05T16:18:12.575516+00:00	\N
X12-DA-B05-271-D01	PRED-SIM-DA-B05	suwanee_smiles	X12_271_RESPONSE	eligibility	\N	x12_271	\N	{"payer_id": "delta_dental", "member_id": "DDL-112983-T", "plan_type": "PPO", "group_number": "GRP-NEW-2025", "annual_maximum": 2000.0, "deductible_met": 50.0, "coverage_active": true, "enrollment_date": "2025-12-04", "months_enrolled": 8, "deductible_total": 100.0, "implant_coverage": false, "benefit_pct_basic": 80.0, "benefit_pct_major": 50.0, "secondary_payer_id": null, "waiting_period_met": false, "annual_maximum_used": 200.0, "pred_required_codes": ["D2750"], "benefit_pct_implants": 0.0, "deductible_remaining": 50.0, "missing_tooth_clause": true, "benefit_pct_preventive": 100.0, "annual_maximum_remaining": 1800.0, "coordination_of_benefits": false, "missing_tooth_clause_confirmed": false}	0.980	deterministic	2026-08-05T16:18:14.018787+00:00	\N
DA-B01-PRED_LETTER	PRED-SIM-DA-B01	suwanee_smiles	PRED_LETTER	administrative	\N	s3	accord-dental-documents	{"decision": "denied", "pred_number": "PD-DAB01", "denial_reason": "Implants excluded from this plan.", "pred_decision": "DENIED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["ELIG_IMPLANT_NOT_COVERED"], "cdt_codes_reviewed": ["D6010", "D6065"], "denial_reason_text": "Implants excluded from this plan."}	1.000	deterministic	2026-08-06T05:21:09.956855+00:00	suwanee_smiles/DA-B01/DA-B01_PRED_LETTER_DENIED.pdf
INS-DA-B02-CARD-D03	PRED-SIM-DA-B02	suwanee_smiles	INSURANCE_CARD	eligibility	\N	api	\N	{"payer_id": "delta_dental", "member_id": "DDL-778234-A", "plan_type": "PPO", "group_number": "GRP-44821", "coverage_active": true}	0.950	caller_supplied	2026-08-06T05:21:09.976176+00:00	suwanee_smiles/DA-B02/DA-B02_INSURANCE_CARD.pdf
XRAY-DA-B02-D02	PRED-SIM-DA-B02	suwanee_smiles	XRAY_PA	clinical	19	api	\N	{"pathology": "Edentulous space #19 with healed ridge", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "bone_loss_mm": 4.2, "tooth_number": 19, "bone_loss_pct": 35.0, "image_quality": "DIAGNOSTIC"}	1.000	deterministic	2026-08-06T05:21:09.995334+00:00	suwanee_smiles/DA-B02/DA-B02_PA_XRAY_TOOTH19.pdf
DA-B02-PRED_LETTER	PRED-SIM-DA-B02	suwanee_smiles	PRED_LETTER	administrative	\N	s3	accord-dental-documents	{"decision": "denied", "pred_number": "PD-DAB02", "denial_reason": "Missing tooth clause â€” tooth #19 missing before enrollment.", "pred_decision": "DENIED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["CLINICAL_EXTRACTION_DATE", "ELIG_MISSING_TOOTH_CLAUSE"], "cdt_codes_reviewed": ["D6010", "D6065"], "denial_reason_text": "Missing tooth clause â€” tooth #19 missing before enrollment."}	1.000	deterministic	2026-08-06T05:21:10.015105+00:00	suwanee_smiles/DA-B02/DA-B02_PRED_LETTER_DENIED.pdf
INS-DA-B03-CARD-D03	PRED-SIM-DA-B03	suwanee_smiles	INSURANCE_CARD	eligibility	\N	api	\N	{"payer_id": "delta_dental", "member_id": "DDL-223847-H", "plan_type": "PPO", "group_number": "GRP-77103", "coverage_active": true}	0.950	caller_supplied	2026-08-06T05:21:10.034239+00:00	suwanee_smiles/DA-B03/DA-B03_INSURANCE_CARD.pdf
PMS-DA-C01-SUPERBILL-D00	PRED-SIM-DA-C01	suwanee_smiles	CDT_SUPERBILL	administrative	\N	api	\N	{"fees": [2800.0, 950.0], "arches": ["lower", "lower"], "payer_id": "delta_dental", "cdt_codes": ["D6010", "D7953"], "member_id": "DDL-610455-K", "quadrants": ["LL", "LL"], "provider_npi": null, "payer_allowed": [null, null], "tooth_numbers": [19, 19], "tooth_surfaces": [null, null], "provider_out_of_network": false}	0.950	caller_supplied	2026-08-05T16:18:15.445959+00:00	\N
XRAY-DA-B03-D02	PRED-SIM-DA-B03	suwanee_smiles	XRAY_PA	clinical	3	api	\N	{"pathology": "Caries extending to pulp chamber, tooth #3", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "tooth_number": 3, "decay_present": true, "image_quality": "DIAGNOSTIC"}	0.700	deterministic	2026-08-06T05:21:10.053858+00:00	suwanee_smiles/DA-B03/DA-B03_PA_XRAY_TOOTH3.pdf
PMS-DA-B05-SUPERBILL-D00	PRED-SIM-DA-B05	suwanee_smiles	CDT_SUPERBILL	administrative	\N	api	\N	{"fees": [1450.0], "arches": ["upper"], "payer_id": "delta_dental", "cdt_codes": ["D2750"], "member_id": "DDL-112983-T", "quadrants": ["UL"], "provider_npi": null, "payer_allowed": [null], "tooth_numbers": [13], "tooth_surfaces": ["DO"], "provider_out_of_network": false}	0.950	caller_supplied	2026-08-05T16:18:14.018787+00:00	\N
DA-B03-PRED_LETTER	PRED-SIM-DA-B03	suwanee_smiles	PRED_LETTER	administrative	\N	s3	accord-dental-documents	{"decision": "denied", "pred_number": "PD-DAB03", "denial_reason": "Crown frequency limit exceeded. Last approved 2023. Next eligible 2028.", "pred_decision": "DENIED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["ELIG_FREQUENCY_LIMIT"], "cdt_codes_reviewed": ["D2750"], "denial_reason_text": "Crown frequency limit exceeded. Last approved 2023. Next eligible 2028."}	1.000	deterministic	2026-08-06T05:21:10.073663+00:00	suwanee_smiles/DA-B03/DA-B03_PRED_LETTER_DENIED.pdf
NOTE-DA-B04-D03	PRED-SIM-DA-B04	suwanee_smiles	CLINICAL_NOTE	clinical	\N	api	\N	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D6010", "D7953"], "diagnosis": "THE core scenario: D7953 denied as not separately payable with D6010.", "narrative": "Accord catches bundling before submission. Appeal success ~65% when documented.", "visit_date": "2026-08-05", "treatment_plan": "D6010+D7953 tooth #19", "cdt_codes_noted": ["D6010", "D7953"], "chief_complaint": "Denial â€” Bone Graft Bundled with Implant", "narrative_present": true, "primary_diagnosis": "THE core scenario: D7953 denied as not separately payable with D6010."}	0.900	deterministic	2026-08-06T05:21:10.093355+00:00	suwanee_smiles/DA-B04/DA-B04_CLINICAL_NOTE.pdf
DA-B04-PRED_LETTER	PRED-SIM-DA-B04	suwanee_smiles	PRED_LETTER	administrative	\N	s3	accord-dental-documents	{"decision": "pended", "pred_number": "PD-DAB04", "denial_reason": "D7953 bundled with D6010. Separate clinical documentation required.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["CLINICAL_NARRATIVE_REQUIRED", "CLINICAL_XRAY_REQUIRED", "COVERAGE_BUNDLING_CONFLICT"], "cdt_codes_reviewed": ["D6010", "D7953"], "denial_reason_text": "D7953 bundled with D6010. Separate clinical documentation required."}	1.000	deterministic	2026-08-06T05:21:10.133200+00:00	suwanee_smiles/DA-B04/DA-B04_PRED_LETTER_PENDED.pdf
INS-DA-B05-CARD-D03	PRED-SIM-DA-B05	suwanee_smiles	INSURANCE_CARD	eligibility	\N	api	\N	{"payer_id": "delta_dental", "member_id": "DDL-112983-T", "plan_type": "PPO", "group_number": "GRP-NEW-2025", "coverage_active": true}	0.950	caller_supplied	2026-08-06T05:21:10.153238+00:00	suwanee_smiles/DA-B05/DA-B05_INSURANCE_CARD.pdf
XRAY-DA-B05-D02	PRED-SIM-DA-B05	suwanee_smiles	XRAY_PA	clinical	13	api	\N	{"pathology": "Caries extending to pulp chamber, tooth #13", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "tooth_number": 13, "decay_present": true, "image_quality": "DIAGNOSTIC"}	0.700	deterministic	2026-08-06T05:21:10.172240+00:00	suwanee_smiles/DA-B05/DA-B05_PA_XRAY_TOOTH13.pdf
PMS-DA-C02-SUPERBILL-D00	PRED-SIM-DA-C02	suwanee_smiles	CDT_SUPERBILL	administrative	\N	api	\N	{"fees": [1850.0], "arches": ["upper"], "payer_id": "delta_dental", "cdt_codes": ["D4260"], "member_id": "DDL-482277-S", "quadrants": ["UL"], "provider_npi": null, "payer_allowed": [null], "tooth_numbers": [14], "tooth_surfaces": [null], "provider_out_of_network": false}	0.950	caller_supplied	2026-08-05T16:18:16.772839+00:00	\N
XRAY-DA-C02-D03	PRED-SIM-DA-C02	suwanee_smiles	XRAY_PA	clinical	14	api	\N	{"pathology": "Edentulous space #14 with healed ridge", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "bone_loss_mm": 2.1, "tooth_number": 14, "bone_loss_pct": 20.0, "image_quality": "DIAGNOSTIC"}	1.000	deterministic	2026-08-06T05:21:10.267540+00:00	suwanee_smiles/DA-C02/DA-C02_PA_XRAY_TOOTH14.pdf
PAN-DA-C03-D02	PRED-SIM-DA-C03	suwanee_smiles	XRAY_PAN	clinical	\N	api	\N	{"pathology": "Generalized bone loss", "xray_date": "2026-08-05", "xray_type": "panoramic", "date_taken": "2026-08-05", "bone_loss_mm": 4.0, "tooth_number": null, "bone_loss_pct": 32.0, "image_quality": "DIAGNOSTIC"}	0.850	deterministic	2026-08-06T05:21:10.325097+00:00	suwanee_smiles/DA-C03/DA-C03_PANORAMIC_XRAY.pdf
DA-B05-PRED_LETTER	PRED-SIM-DA-B05	suwanee_smiles	PRED_LETTER	administrative	\N	s3	accord-dental-documents	{"decision": "denied", "pred_number": "PD-DAB05", "denial_reason": "12-month waiting period not met. Eligible 12/01/2026.", "pred_decision": "DENIED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["ELIG_WAITING_PERIOD_NOT_MET"], "cdt_codes_reviewed": ["D2750"], "denial_reason_text": "12-month waiting period not met. Eligible 12/01/2026."}	1.000	deterministic	2026-08-06T05:21:10.190687+00:00	suwanee_smiles/DA-B05/DA-B05_PRED_LETTER_DENIED.pdf
NOTE-DA-C01-D02	PRED-SIM-DA-C01	suwanee_smiles	CLINICAL_NOTE	clinical	\N	api	\N	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D6010", "D7953"], "diagnosis": "D6010+D7953 submitted with a narrative but no radiograph. Bone loss unprovable.", "narrative": "Evidence missing, not contradicted â€” pend and request the PA X-ray.", "visit_date": "2026-08-05", "treatment_plan": "D6010+D7953 tooth #19", "cdt_codes_noted": ["D6010", "D7953"], "chief_complaint": "Pended â€” Implant Missing X-ray", "narrative_present": true, "primary_diagnosis": "D6010+D7953 submitted with a narrative but no radiograph. Bone loss unprovable."}	0.900	deterministic	2026-08-06T05:21:10.210499+00:00	suwanee_smiles/DA-C01/DA-C01_CLINICAL_NOTE.pdf
DA-C01-PRED_LETTER	PRED-SIM-DA-C01	suwanee_smiles	PRED_LETTER	administrative	\N	s3	accord-dental-documents	{"decision": "pended", "pred_number": "PD-DAC01", "denial_reason": "No radiograph â€” bone loss cannot be established.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["CLINICAL_BONE_LOSS_THRESHOLD", "CLINICAL_XRAY_REQUIRED"], "cdt_codes_reviewed": ["D6010", "D7953"], "denial_reason_text": "No radiograph â€” bone loss cannot be established."}	1.000	deterministic	2026-08-06T05:21:10.228759+00:00	suwanee_smiles/DA-C01/DA-C01_PRED_LETTER_PENDED.pdf
X12-DA-C01-271-D01	PRED-SIM-DA-C01	suwanee_smiles	X12_271_RESPONSE	eligibility	\N	x12_271	\N	{"payer_id": "delta_dental", "member_id": "DDL-610455-K", "plan_type": "PPO", "group_number": "GRP-44821", "annual_maximum": 2000.0, "deductible_met": 50.0, "coverage_active": true, "enrollment_date": "2020-01-01", "months_enrolled": 79, "deductible_total": 100.0, "implant_coverage": true, "benefit_pct_basic": 80.0, "benefit_pct_major": 50.0, "secondary_payer_id": null, "waiting_period_met": true, "annual_maximum_used": 200.0, "pred_required_codes": ["D6010", "D7953"], "benefit_pct_implants": 50.0, "deductible_remaining": 50.0, "missing_tooth_clause": true, "benefit_pct_preventive": 100.0, "annual_maximum_remaining": 1800.0, "coordination_of_benefits": false, "missing_tooth_clause_confirmed": false}	0.980	deterministic	2026-08-05T16:18:15.445959+00:00	\N
X12-DA-C03-271-D01	PRED-SIM-DA-C03	suwanee_smiles	X12_271_RESPONSE	eligibility	\N	x12_271	\N	{"payer_id": "delta_dental", "member_id": "DDL-773901-F", "plan_type": "PPO", "group_number": "GRP-44821", "annual_maximum": 2000.0, "deductible_met": 50.0, "coverage_active": true, "enrollment_date": "2018-01-01", "months_enrolled": 103, "deductible_total": 100.0, "implant_coverage": true, "benefit_pct_basic": 80.0, "benefit_pct_major": 50.0, "secondary_payer_id": null, "waiting_period_met": true, "annual_maximum_used": 200.0, "pred_required_codes": ["D6010", "D6010", "D6010", "D6010", "D6065", "D6065", "D6065", "D6065"], "benefit_pct_implants": 50.0, "deductible_remaining": 50.0, "missing_tooth_clause": true, "benefit_pct_preventive": 100.0, "annual_maximum_remaining": 1800.0, "coordination_of_benefits": false, "missing_tooth_clause_confirmed": false}	0.980	deterministic	2026-08-05T16:18:18.433862+00:00	\N
PMS-DA-C04-SUPERBILL-D00	PRED-SIM-DA-C04	suwanee_smiles	CDT_SUPERBILL	administrative	\N	api	\N	{"fees": [1450.0], "arches": ["upper"], "payer_id": "delta_dental", "cdt_codes": ["D2750"], "member_id": "DDL-559120-W", "quadrants": ["UR"], "provider_npi": null, "payer_allowed": [null], "tooth_numbers": [3], "tooth_surfaces": ["MOD"], "provider_out_of_network": false}	0.950	caller_supplied	2026-08-05T16:18:19.894443+00:00	\N
X12-DA-C04-271-D01	PRED-SIM-DA-C04	suwanee_smiles	X12_271_RESPONSE	eligibility	\N	x12_271	\N	{"payer_id": "delta_dental", "member_id": "DDL-559120-W", "plan_type": "PPO", "group_number": "GRP-77103", "annual_maximum": 2000.0, "deductible_met": 50.0, "coverage_active": true, "enrollment_date": "2021-02-01", "months_enrolled": 66, "deductible_total": 100.0, "implant_coverage": false, "benefit_pct_basic": 80.0, "benefit_pct_major": 50.0, "secondary_payer_id": null, "waiting_period_met": true, "annual_maximum_used": 200.0, "pred_required_codes": ["D2750"], "benefit_pct_implants": 0.0, "deductible_remaining": 50.0, "missing_tooth_clause": true, "benefit_pct_preventive": 100.0, "annual_maximum_remaining": 1800.0, "coordination_of_benefits": false, "missing_tooth_clause_confirmed": false}	0.980	deterministic	2026-08-05T16:18:19.894443+00:00	\N
NOTE-DA-C02-D02	PRED-SIM-DA-C02	suwanee_smiles	CLINICAL_NOTE	clinical	\N	api	\N	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D4260"], "diagnosis": "D4260 with a radiograph showing 20% bone loss (below the 25% threshold) and no perio chart.", "narrative": "Pocket depth was never measured â€” the defining criterion is missing, so pend rather than deny.", "visit_date": "2026-08-05", "treatment_plan": "D4260 tooth #14", "cdt_codes_noted": ["D4260"], "chief_complaint": "Pended â€” Perio Surgery Chart Insufficient", "narrative_present": true, "primary_diagnosis": "D4260 with a radiograph showing 20% bone loss (below the 25% threshold) and no perio chart."}	0.900	deterministic	2026-08-06T05:21:10.248841+00:00	suwanee_smiles/DA-C02/DA-C02_CLINICAL_NOTE.pdf
PMS-DA-C03-SUPERBILL-D00	PRED-SIM-DA-C03	suwanee_smiles	CDT_SUPERBILL	administrative	\N	api	\N	{"fees": [2800.0, 2800.0, 2800.0, 2800.0, 1800.0, 1800.0, 1800.0, 1800.0], "arches": ["upper", "upper", "lower", "lower", "upper", "upper", "lower", "lower"], "payer_id": "delta_dental", "cdt_codes": ["D6010", "D6010", "D6010", "D6010", "D6065", "D6065", "D6065", "D6065"], "member_id": "DDL-773901-F", "quadrants": ["UR", "UL", "LL", "LR", "UR", "UL", "LL", "LR"], "provider_npi": null, "payer_allowed": [null, null, null, null, null, null, null, null], "tooth_numbers": [3, 14, 19, 30, 3, 14, 19, 30], "tooth_surfaces": [null, null, null, null, null, null, null, null], "provider_out_of_network": false}	0.950	caller_supplied	2026-08-05T16:18:18.433862+00:00	\N
DA-C02-PRED_LETTER	PRED-SIM-DA-C02	suwanee_smiles	PRED_LETTER	administrative	\N	s3	accord-dental-documents	{"decision": "pended", "pred_number": "PD-DAC02", "denial_reason": "Perio chart absent; radiographic bone loss below 25%.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["CLINICAL_BONE_LOSS_THRESHOLD", "CLINICAL_PERIO_CHART_REQUIRED"], "cdt_codes_reviewed": ["D4260"], "denial_reason_text": "Perio chart absent; radiographic bone loss below 25%."}	1.000	deterministic	2026-08-06T05:21:10.286956+00:00	suwanee_smiles/DA-C02/DA-C02_PRED_LETTER_PENDED.pdf
DA-C03-PRED_LETTER	PRED-SIM-DA-C03	suwanee_smiles	PRED_LETTER	administrative	\N	s3	accord-dental-documents	{"decision": "pended", "pred_number": "PD-DAC03", "denial_reason": "CBCT required for implant cases above $10,000.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["CLINICAL_CBCT_REQUIRED"], "cdt_codes_reviewed": ["D6010", "D6065"], "denial_reason_text": "CBCT required for implant cases above $10,000."}	1.000	deterministic	2026-08-06T05:21:10.345071+00:00	suwanee_smiles/DA-C03/DA-C03_PRED_LETTER_PENDED.pdf
PMS-DA-C05-SUPERBILL-D00	PRED-SIM-DA-C05	suwanee_smiles	CDT_SUPERBILL	administrative	\N	api	\N	{"fees": [1450.0], "arches": ["upper"], "payer_id": "delta_dental", "cdt_codes": ["D2750"], "member_id": "DDL-902314-P", "quadrants": ["UL"], "provider_npi": null, "payer_allowed": [null], "tooth_numbers": [14], "tooth_surfaces": ["MO"], "provider_out_of_network": false}	0.950	caller_supplied	2026-08-05T16:18:21.157963+00:00	\N
PMS-DA-D02-SUPERBILL-D00	PRED-SIM-DA-D02	suwanee_smiles	CDT_SUPERBILL	administrative	\N	api	\N	{"fees": [3500.0, 3500.0, 3500.0, 3500.0, 1300.0, 1300.0, 1300.0, 1300.0, 4000.0, 4000.0, 4000.0, 4000.0], "arches": ["upper", "upper", "upper", "upper", "upper", "upper", "upper", "upper", "upper", "upper", "upper", "upper"], "payer_id": "delta_dental", "cdt_codes": ["D6010", "D6010", "D6010", "D6010", "D7953", "D7953", "D7953", "D7953", "D6065", "D6065", "D6065", "D6065"], "member_id": "DDL-114702-M", "quadrants": ["UR", "UR", "UL", "UL", "UR", "UR", "UL", "UL", "UR", "UR", "UL", "UL"], "provider_npi": null, "payer_allowed": [null, null, null, null, null, null, null, null, null, null, null, null], "tooth_numbers": [3, 6, 11, 14, 3, 6, 11, 14, 3, 6, 11, 14], "tooth_surfaces": [null, null, null, null, null, null, null, null, null, null, null, null], "provider_out_of_network": false}	0.950	caller_supplied	2026-08-05T16:18:25.668661+00:00	\N
X12-DA-C02-271-D01	PRED-SIM-DA-C02	suwanee_smiles	X12_271_RESPONSE	eligibility	\N	x12_271	\N	{"payer_id": "delta_dental", "member_id": "DDL-482277-S", "plan_type": "PPO", "group_number": "GRP-77103", "annual_maximum": 2000.0, "deductible_met": 50.0, "coverage_active": true, "enrollment_date": "2019-05-01", "months_enrolled": 87, "deductible_total": 100.0, "implant_coverage": false, "benefit_pct_basic": 80.0, "benefit_pct_major": 50.0, "secondary_payer_id": null, "waiting_period_met": true, "annual_maximum_used": 200.0, "pred_required_codes": ["D4260"], "benefit_pct_implants": 0.0, "deductible_remaining": 50.0, "missing_tooth_clause": true, "benefit_pct_preventive": 100.0, "annual_maximum_remaining": 1800.0, "coordination_of_benefits": false, "missing_tooth_clause_confirmed": false}	0.980	deterministic	2026-08-05T16:18:16.772839+00:00	\N
PMS-DA-D01-SUPERBILL-D00	PRED-SIM-DA-D01	suwanee_smiles	CDT_SUPERBILL	administrative	\N	api	\N	{"fees": [1850.0, 2800.0, 950.0], "arches": ["upper", "upper", "upper"], "payer_id": "delta_dental", "cdt_codes": ["D4260", "D6010", "D7953"], "member_id": "DDL-338847-C", "quadrants": ["UR", "UR", "UR"], "provider_npi": null, "payer_allowed": [null, null, null], "tooth_numbers": [3, 3, 3], "tooth_surfaces": [null, null, null], "provider_out_of_network": true}	0.950	caller_supplied	2026-08-05T16:18:23.326469+00:00	\N
X12-DA-D01-271-D01	PRED-SIM-DA-D01	suwanee_smiles	X12_271_RESPONSE	eligibility	\N	x12_271	\N	{"payer_id": "delta_dental", "member_id": "DDL-338847-C", "plan_type": "PPO", "group_number": "GRP-44821", "annual_maximum": 2000.0, "deductible_met": 50.0, "coverage_active": true, "enrollment_date": "2019-01-01", "months_enrolled": 91, "deductible_total": 100.0, "implant_coverage": true, "benefit_pct_basic": 80.0, "benefit_pct_major": 50.0, "secondary_payer_id": null, "waiting_period_met": true, "annual_maximum_used": 200.0, "pred_required_codes": ["D4260", "D6010", "D7953"], "benefit_pct_implants": 50.0, "deductible_remaining": 50.0, "missing_tooth_clause": true, "benefit_pct_preventive": 100.0, "annual_maximum_remaining": 1800.0, "coordination_of_benefits": false, "missing_tooth_clause_confirmed": false}	0.980	deterministic	2026-08-05T16:18:23.326469+00:00	\N
NOTE-DA-C03-D03	PRED-SIM-DA-C03	suwanee_smiles	CLINICAL_NOTE	clinical	\N	api	\N	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D6010", "D6010", "D6010", "D6010", "D6065", "D6065", "D6065", "D6065"], "diagnosis": "Four implants and four crowns at $18,400. High-value implant cases require CBCT.", "narrative": "D6010+D6010+D6010+D6010+D6065+D6065+D6065+D6065 tooth #3, #14, #19, #30 Procedures planned: D6010, D6010, D6010, D6010, D6065, D6065, D6065, D6065 Panoramic film is not sufficient bone-volume analysis for a full-arch case.", "visit_date": "2026-08-05", "treatment_plan": "D6010+D6010+D6010+D6010+D6065+D6065+D6065+D6065 tooth #3, #14, #19, #30", "cdt_codes_noted": ["D6010", "D6065"], "chief_complaint": "Pended â€” Full Arch CBCT Required", "narrative_present": true, "primary_diagnosis": "Four implants and four crowns at $18,400. High-value implant cases require CBCT."}	0.900	deterministic	2026-08-06T05:21:10.306913+00:00	suwanee_smiles/DA-C03/DA-C03_CLINICAL_NOTE.pdf
INS-DA-C05-CARD-D04	PRED-SIM-DA-C05	suwanee_smiles	INSURANCE_CARD	eligibility	\N	api	\N	{"payer_id": "delta_dental", "member_id": "DDL-902314-P", "plan_type": "PPO", "group_number": "GRP-55290", "coverage_active": true, "secondary_payer_id": "cigna", "coordination_of_benefits": true}	0.950	caller_supplied	2026-08-06T05:21:10.423498+00:00	suwanee_smiles/DA-C05/DA-C05_INSURANCE_CARD.pdf
XRAY-DA-C05-D02	PRED-SIM-DA-C05	suwanee_smiles	XRAY_PA	clinical	14	api	\N	{"pathology": "Caries extending to pulp chamber, tooth #14", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "tooth_number": 14, "decay_present": true, "image_quality": "DIAGNOSTIC"}	0.700	deterministic	2026-08-06T05:21:10.443396+00:00	suwanee_smiles/DA-C05/DA-C05_PA_XRAY_TOOTH14.pdf
DA-C05-PRED_LETTER	PRED-SIM-DA-C05	suwanee_smiles	PRED_LETTER	administrative	\N	s3	accord-dental-documents	{"decision": "pended", "pred_number": "PD-DAC05", "denial_reason": "Dual coverage â€” primary payer must adjudicate first.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["ADMIN_COB_PRIMARY_FIRST", "ELIG_COB_REQUIRED"], "cdt_codes_reviewed": ["D2750"], "denial_reason_text": "Dual coverage â€” primary payer must adjudicate first."}	1.000	deterministic	2026-08-06T05:21:10.461741+00:00	suwanee_smiles/DA-C05/DA-C05_PRED_LETTER_PENDED.pdf
X12-DA-C05-271-D01	PRED-SIM-DA-C05	suwanee_smiles	X12_271_RESPONSE	eligibility	\N	x12_271	\N	{"payer_id": "delta_dental", "member_id": "DDL-902314-P", "plan_type": "PPO", "group_number": "GRP-55290", "annual_maximum": 2000.0, "deductible_met": 50.0, "coverage_active": true, "enrollment_date": "2020-03-01", "months_enrolled": 77, "deductible_total": 100.0, "implant_coverage": false, "benefit_pct_basic": 80.0, "benefit_pct_major": 50.0, "secondary_payer_id": "cigna", "waiting_period_met": true, "annual_maximum_used": 200.0, "pred_required_codes": ["D2750"], "benefit_pct_implants": 0.0, "deductible_remaining": 50.0, "missing_tooth_clause": true, "benefit_pct_preventive": 100.0, "annual_maximum_remaining": 1800.0, "coordination_of_benefits": true, "missing_tooth_clause_confirmed": false}	0.980	deterministic	2026-08-05T16:18:21.157963+00:00	\N
X12-DA-D02-271-D01	PRED-SIM-DA-D02	suwanee_smiles	X12_271_RESPONSE	eligibility	\N	x12_271	\N	{"payer_id": "delta_dental", "member_id": "DDL-114702-M", "plan_type": "PPO", "group_number": "GRP-44821", "annual_maximum": 2000.0, "deductible_met": 50.0, "coverage_active": true, "enrollment_date": "2017-01-01", "months_enrolled": 115, "deductible_total": 100.0, "implant_coverage": true, "benefit_pct_basic": 80.0, "benefit_pct_major": 50.0, "secondary_payer_id": null, "waiting_period_met": true, "annual_maximum_used": 200.0, "pred_required_codes": ["D6010", "D6010", "D6010", "D6010", "D7953", "D7953", "D7953", "D7953", "D6065", "D6065", "D6065", "D6065"], "benefit_pct_implants": 50.0, "deductible_remaining": 50.0, "missing_tooth_clause": true, "benefit_pct_preventive": 100.0, "annual_maximum_remaining": 1800.0, "coordination_of_benefits": false, "missing_tooth_clause_confirmed": false}	0.980	deterministic	2026-08-05T16:18:25.668661+00:00	\N
NOTE-DA-C04-D02	PRED-SIM-DA-C04	suwanee_smiles	CLINICAL_NOTE	clinical	\N	api	\N	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D2750"], "diagnosis": "D2750 submitted with a narrative referencing a 2024 film that was never attached.", "narrative": "A film referenced in the narrative but not attached is not evidence.", "visit_date": "2026-08-05", "treatment_plan": "D2750 tooth #3", "cdt_codes_noted": ["D2750"], "chief_complaint": "Pended â€” Crown Without Current X-ray", "narrative_present": true, "primary_diagnosis": "D2750 submitted with a narrative referencing a 2024 film that was never attached."}	0.900	deterministic	2026-08-06T05:21:10.364503+00:00	suwanee_smiles/DA-C04/DA-C04_CLINICAL_NOTE.pdf
DA-C09-PRED_LETTER	PRED-SIM-DA-C09	suwanee_smiles	PRED_LETTER	administrative	\N	s3	accord-dental-documents	{"decision": "pended", "pred_number": "PD-DAC09", "denial_reason": "IV bisphosphonate therapy â€” osteonecrosis risk.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["CLINICAL_MEDICAL_HISTORY_FLAG"], "cdt_codes_reviewed": ["D6010"], "denial_reason_text": "IV bisphosphonate therapy â€” osteonecrosis risk."}	1.000	deterministic	2026-08-06T05:21:10.705436+00:00	suwanee_smiles/DA-C09/DA-C09_PRED_LETTER_PENDED.pdf
X12-DA-D03-271-D01	PRED-SIM-DA-D03	suwanee_smiles	X12_271_RESPONSE	eligibility	\N	x12_271	\N	{"payer_id": "delta_dental", "member_id": "DDL-667203-L", "plan_type": "PPO", "group_number": "GRP-NEW-2025", "annual_maximum": 2000.0, "deductible_met": 50.0, "coverage_active": true, "enrollment_date": "2025-09-04", "months_enrolled": 11, "deductible_total": 100.0, "implant_coverage": true, "benefit_pct_basic": 80.0, "benefit_pct_major": 50.0, "secondary_payer_id": null, "waiting_period_met": false, "annual_maximum_used": 200.0, "pred_required_codes": ["D6010", "D6065"], "benefit_pct_implants": 50.0, "deductible_remaining": 50.0, "missing_tooth_clause": true, "benefit_pct_preventive": 100.0, "annual_maximum_remaining": 1800.0, "coordination_of_benefits": false, "missing_tooth_clause_confirmed": false}	0.980	deterministic	2026-08-05T16:18:27.413762+00:00	\N
X12-DA-D04-271-D01	PRED-SIM-DA-D04	suwanee_smiles	X12_271_RESPONSE	eligibility	\N	x12_271	\N	{"payer_id": "delta_dental", "member_id": "DDL-445619-T", "plan_type": "PPO", "group_number": "GRP-77103", "annual_maximum": 2000.0, "deductible_met": 50.0, "coverage_active": true, "enrollment_date": "2018-06-01", "months_enrolled": 98, "deductible_total": 100.0, "implant_coverage": false, "benefit_pct_basic": 80.0, "benefit_pct_major": 50.0, "secondary_payer_id": null, "waiting_period_met": true, "annual_maximum_used": 200.0, "pred_required_codes": ["D2740"], "benefit_pct_implants": 0.0, "deductible_remaining": 50.0, "missing_tooth_clause": true, "benefit_pct_preventive": 100.0, "annual_maximum_remaining": 1800.0, "coordination_of_benefits": false, "missing_tooth_clause_confirmed": false}	0.980	deterministic	2026-08-05T16:18:28.881561+00:00	\N
PMS-DA-D03-SUPERBILL-D00	PRED-SIM-DA-D03	suwanee_smiles	CDT_SUPERBILL	administrative	\N	api	\N	{"fees": [2800.0, 1800.0], "arches": ["lower", "lower"], "payer_id": "delta_dental", "cdt_codes": ["D6010", "D6065"], "member_id": "DDL-667203-L", "quadrants": ["LL", "LL"], "provider_npi": null, "payer_allowed": [null, null], "tooth_numbers": [19, 19], "tooth_surfaces": [null, null], "provider_out_of_network": false}	0.950	caller_supplied	2026-08-05T16:18:27.413762+00:00	\N
PMS-DA-D05-SUPERBILL-D00	PRED-SIM-DA-D05	suwanee_smiles	CDT_SUPERBILL	administrative	\N	api	\N	{"fees": [2800.0, 950.0], "arches": ["lower", "lower"], "payer_id": "delta_dental", "cdt_codes": ["D6010", "D7953"], "member_id": "DDL-558934-R", "quadrants": ["LL", "LL"], "provider_npi": null, "payer_allowed": [null, null], "tooth_numbers": [19, 19], "tooth_surfaces": [null, null], "provider_out_of_network": false}	0.950	caller_supplied	2026-08-05T16:18:30.399561+00:00	\N
X12-DA-D05-271-D01	PRED-SIM-DA-D05	suwanee_smiles	X12_271_RESPONSE	eligibility	\N	x12_271	\N	{"payer_id": "delta_dental", "member_id": "DDL-558934-R", "plan_type": "PPO", "group_number": "GRP-44821", "annual_maximum": 2000.0, "deductible_met": 50.0, "coverage_active": true, "enrollment_date": "2021-01-01", "months_enrolled": 67, "deductible_total": 100.0, "implant_coverage": true, "benefit_pct_basic": 80.0, "benefit_pct_major": 50.0, "secondary_payer_id": null, "waiting_period_met": true, "annual_maximum_used": 200.0, "pred_required_codes": ["D6010", "D7953"], "benefit_pct_implants": 50.0, "deductible_remaining": 50.0, "missing_tooth_clause": true, "benefit_pct_preventive": 100.0, "annual_maximum_remaining": 1800.0, "coordination_of_benefits": false, "missing_tooth_clause_confirmed": false}	0.980	deterministic	2026-08-05T16:18:30.399561+00:00	\N
DA-C04-PRED_LETTER	PRED-SIM-DA-C04	suwanee_smiles	PRED_LETTER	administrative	\N	s3	accord-dental-documents	{"decision": "pended", "pred_number": "PD-DAC04", "denial_reason": "No radiograph in the submitted document set.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["CLINICAL_XRAY_REQUIRED"], "cdt_codes_reviewed": ["D2750"], "denial_reason_text": "No radiograph in the submitted document set."}	1.000	deterministic	2026-08-06T05:21:10.384158+00:00	suwanee_smiles/DA-C04/DA-C04_PRED_LETTER_PENDED.pdf
NOTE-DA-C05-D03	PRED-SIM-DA-C05	suwanee_smiles	CLINICAL_NOTE	clinical	\N	api	\N	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D2750"], "diagnosis": "Delta Dental primary, Cigna secondary. Primary must adjudicate first.", "narrative": "Clinically complete, but COB ordering blocks submission until primary responds.", "visit_date": "2026-08-05", "treatment_plan": "D2750 tooth #14", "cdt_codes_noted": ["D2750"], "chief_complaint": "Pended â€” Coordination of Benefits", "narrative_present": true, "primary_diagnosis": "Delta Dental primary, Cigna secondary. Primary must adjudicate first."}	0.900	deterministic	2026-08-06T05:21:10.404096+00:00	suwanee_smiles/DA-C05/DA-C05_CLINICAL_NOTE.pdf
NOTE-DA-D01-D04	PRED-SIM-DA-D01	suwanee_smiles	CLINICAL_NOTE	clinical	\N	api	\N	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D4260", "D6010", "D7953"], "diagnosis": "OON periodontist billing osseous surgery plus an implant and graft at #3.", "narrative": "Two independent blockers at once â€” OON reimbursement tier plus a bundling conflict.", "visit_date": "2026-08-05", "treatment_plan": "D4260+D6010+D7953 tooth #3", "cdt_codes_noted": ["D4260", "D6010", "D7953"], "chief_complaint": "Complex â€” Out-of-Network Specialist + Bundling", "narrative_present": true, "primary_diagnosis": "OON periodontist billing osseous surgery plus an implant and graft at #3."}	0.900	deterministic	2026-08-06T05:21:10.784472+00:00	suwanee_smiles/DA-D01/DA-D01_CLINICAL_NOTE.pdf
XRAY-DA-D01-D03	PRED-SIM-DA-D01	suwanee_smiles	XRAY_PA	clinical	3	api	\N	{"pathology": "Edentulous space #3 with healed ridge", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "bone_loss_mm": 4.2, "tooth_number": 3, "bone_loss_pct": 35.0, "image_quality": "DIAGNOSTIC"}	1.000	deterministic	2026-08-06T05:21:10.804313+00:00	suwanee_smiles/DA-D01/DA-D01_PA_XRAY_TOOTH3.pdf
PMS-DA-D04-SUPERBILL-D00	PRED-SIM-DA-D04	suwanee_smiles	CDT_SUPERBILL	administrative	\N	api	\N	{"fees": [1650.0], "arches": ["upper"], "payer_id": "delta_dental", "cdt_codes": ["D2740"], "member_id": "DDL-445619-T", "quadrants": ["UR"], "provider_npi": null, "payer_allowed": [null], "tooth_numbers": [8], "tooth_surfaces": ["MI"], "provider_out_of_network": false}	0.950	caller_supplied	2026-08-05T16:18:28.881561+00:00	\N
DA-U04-PRED_LETTER	PRED-SIM-DA-U04	suwanee_smiles	PRED_LETTER	administrative	\N	s3	accord-dental-documents	{"decision": "approved", "pred_number": "PD-DAU04", "denial_reason": "", "pred_decision": "APPROVED", "response_date": "2026-08-06", "appeal_deadline": "2027-02-02", "condition_codes": [], "cdt_codes_reviewed": ["D7140"]}	1.000	deterministic	2026-08-06T05:21:11.970579+00:00	suwanee_smiles/DA-U04/DA-U04_PRED_LETTER_APPROVED.pdf
PMS-DA-M01-SUPERBILL-D00	PRED-SIM-DA-M01	suwanee_smiles	CDT_SUPERBILL	administrative	\N	api	\N	{"fees": [1450.0], "arches": ["lower"], "payer_id": "delta_dental", "cdt_codes": ["D2750"], "member_id": "DDL-999001-X", "quadrants": ["LL"], "provider_npi": null, "payer_allowed": [null], "tooth_numbers": [19], "tooth_surfaces": ["MOD"], "provider_out_of_network": false}	0.950	caller_supplied	2026-08-05T16:18:32.029265+00:00	\N
X12-DA-M03-271-D01	PRED-SIM-DA-M03	suwanee_smiles	X12_271_RESPONSE	eligibility	\N	x12_271	\N	{"payer_id": "delta_dental", "member_id": "DDL-771230-W", "plan_type": "PPO", "group_number": "GRP-55290", "annual_maximum": 2000.0, "deductible_met": 50.0, "coverage_active": true, "enrollment_date": "2020-02-01", "months_enrolled": 78, "deductible_total": 100.0, "implant_coverage": false, "benefit_pct_basic": 80.0, "benefit_pct_major": 50.0, "secondary_payer_id": null, "waiting_period_met": true, "annual_maximum_used": 200.0, "pred_required_codes": ["D2750"], "benefit_pct_implants": 0.0, "deductible_remaining": 50.0, "missing_tooth_clause": true, "benefit_pct_preventive": 100.0, "annual_maximum_remaining": 1800.0, "coordination_of_benefits": false, "missing_tooth_clause_confirmed": false}	0.980	deterministic	2026-08-05T16:18:35.130158+00:00	\N
X12-DA-M05-271-D01	PRED-SIM-DA-M05	suwanee_smiles	X12_271_RESPONSE	eligibility	\N	x12_271	\N	{"payer_id": "delta_dental", "member_id": "DDL-330728-M", "plan_type": "PPO", "group_number": "GRP-77103", "annual_maximum": 2000.0, "deductible_met": 50.0, "coverage_active": true, "enrollment_date": "2018-05-01", "months_enrolled": 99, "deductible_total": 100.0, "implant_coverage": false, "benefit_pct_basic": 80.0, "benefit_pct_major": 50.0, "secondary_payer_id": null, "waiting_period_met": true, "annual_maximum_used": 200.0, "pred_required_codes": ["D2750"], "benefit_pct_implants": 0.0, "deductible_remaining": 50.0, "missing_tooth_clause": true, "benefit_pct_preventive": 100.0, "annual_maximum_remaining": 1800.0, "coordination_of_benefits": false, "missing_tooth_clause_confirmed": false}	0.980	deterministic	2026-08-05T16:18:38.174295+00:00	\N
X12-DA-M01-271-D01	PRED-SIM-DA-M01	suwanee_smiles	X12_271_RESPONSE	eligibility	\N	x12_271	\N	{"payer_id": "delta_dental", "member_id": "DDL-999001-X", "plan_type": "PPO", "group_number": "GRP-44821", "annual_maximum": 2000.0, "deductible_met": 50.0, "coverage_active": true, "enrollment_date": "2020-04-01", "months_enrolled": 76, "deductible_total": 100.0, "implant_coverage": false, "benefit_pct_basic": 80.0, "benefit_pct_major": 50.0, "secondary_payer_id": null, "waiting_period_met": true, "annual_maximum_used": 200.0, "pred_required_codes": ["D2750"], "benefit_pct_implants": 0.0, "deductible_remaining": 50.0, "missing_tooth_clause": true, "benefit_pct_preventive": 100.0, "annual_maximum_remaining": 1800.0, "coordination_of_benefits": false, "missing_tooth_clause_confirmed": false}	0.980	deterministic	2026-08-05T16:18:32.029265+00:00	\N
X12-DA-F01-271-D01	PRED-SIM-DA-F01	suwanee_smiles	X12_271_RESPONSE	eligibility	\N	x12_271	\N	{"payer_id": "delta_dental", "member_id": "DDL-826140-G", "plan_type": "PPO", "group_number": "GRP-44821", "annual_maximum": 2000.0, "deductible_met": 50.0, "coverage_active": true, "enrollment_date": "2019-03-01", "months_enrolled": 89, "deductible_total": 100.0, "implant_coverage": false, "benefit_pct_basic": 80.0, "benefit_pct_major": 50.0, "secondary_payer_id": null, "waiting_period_met": true, "annual_maximum_used": 200.0, "pred_required_codes": ["D2740"], "benefit_pct_implants": 0.0, "deductible_remaining": 50.0, "missing_tooth_clause": true, "benefit_pct_preventive": 100.0, "annual_maximum_remaining": 1800.0, "coordination_of_benefits": false, "missing_tooth_clause_confirmed": false}	0.980	deterministic	2026-08-05T16:18:39.602354+00:00	\N
DA-C06-PRED_LETTER	PRED-SIM-DA-C06	suwanee_smiles	PRED_LETTER	administrative	\N	s3	accord-dental-documents	{"decision": "approved", "pred_number": "PD-DAC06", "denial_reason": "", "pred_decision": "APPROVED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["COVERAGE_PRED_REQUIRED"], "cdt_codes_reviewed": ["D2740"]}	1.000	deterministic	2026-08-06T05:21:10.520011+00:00	suwanee_smiles/DA-C06/DA-C06_PRED_LETTER_APPROVED.pdf
DA-C07-PRED_LETTER	PRED-SIM-DA-C07	suwanee_smiles	PRED_LETTER	administrative	\N	s3	accord-dental-documents	{"decision": "approved", "pred_number": "PD-DAC07", "denial_reason": "", "pred_decision": "APPROVED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": [], "cdt_codes_reviewed": ["D0330"]}	1.000	deterministic	2026-08-06T05:21:10.561998+00:00	suwanee_smiles/DA-C07/DA-C07_PRED_LETTER_APPROVED.pdf
PMS-DA-M03-SUPERBILL-D00	PRED-SIM-DA-M03	suwanee_smiles	CDT_SUPERBILL	administrative	\N	api	\N	{"fees": [1450.0], "arches": ["upper"], "payer_id": "delta_dental", "cdt_codes": ["D2750"], "member_id": "DDL-771230-W", "quadrants": ["UL"], "provider_npi": null, "payer_allowed": [null], "tooth_numbers": [14], "tooth_surfaces": ["MOD"], "provider_out_of_network": false}	0.950	caller_supplied	2026-08-05T16:18:35.130158+00:00	\N
PMS-DA-M02-SUPERBILL-D00	PRED-SIM-DA-M02	suwanee_smiles	CDT_SUPERBILL	administrative	\N	api	\N	{"fees": [1850.0], "arches": ["lower"], "payer_id": "delta_dental", "cdt_codes": ["D4260"], "member_id": "DDL-284416-B", "quadrants": ["LR"], "provider_npi": null, "payer_allowed": [null], "tooth_numbers": [null], "tooth_surfaces": [null], "provider_out_of_network": false}	0.950	caller_supplied	2026-08-05T16:18:33.659429+00:00	\N
X12-DA-M02-271-D01	PRED-SIM-DA-M02	suwanee_smiles	X12_271_RESPONSE	eligibility	\N	x12_271	\N	{"payer_id": "delta_dental", "member_id": "DDL-284416-B", "plan_type": "PPO", "group_number": "GRP-77103", "annual_maximum": 2000.0, "deductible_met": 50.0, "coverage_active": true, "enrollment_date": "2019-07-01", "months_enrolled": 85, "deductible_total": 100.0, "implant_coverage": false, "benefit_pct_basic": 80.0, "benefit_pct_major": 50.0, "secondary_payer_id": null, "waiting_period_met": true, "annual_maximum_used": 200.0, "pred_required_codes": ["D4260"], "benefit_pct_implants": 0.0, "deductible_remaining": 50.0, "missing_tooth_clause": true, "benefit_pct_preventive": 100.0, "annual_maximum_remaining": 1800.0, "coordination_of_benefits": false, "missing_tooth_clause_confirmed": false}	0.980	deterministic	2026-08-05T16:18:33.659429+00:00	\N
HIST-DA-M04-PRIOR-D00	PRED-SIM-DA-M04	suwanee_smiles	PRED_LETTER_PENDED	administrative	\N	payer_portal	\N	{"member_id": "DDL-620914-K", "prior_services": [], "open_pred_requests": [{"status": "open", "cdt_code": "D6010", "submitted_on": "2026-06-15", "tooth_number": 19, "pred_request_id": "PRED-DA-M04-PRIOR"}]}	0.990	deterministic	2026-08-05T16:18:36.572418+00:00	\N
DA-C08-PRED_LETTER	PRED-SIM-DA-C08	suwanee_smiles	PRED_LETTER	administrative	\N	s3	accord-dental-documents	{"decision": "pended", "pred_number": "PD-DAC08", "denial_reason": "Dual coverage â€” primary payer must adjudicate first.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["ADMIN_COB_PRIMARY_FIRST", "ELIG_COB_REQUIRED"], "cdt_codes_reviewed": ["D2750"], "denial_reason_text": "Dual coverage â€” primary payer must adjudicate first."}	1.000	deterministic	2026-08-06T05:21:10.645677+00:00	suwanee_smiles/DA-C08/DA-C08_PRED_LETTER_PENDED.pdf
PMS-DA-M04-SUPERBILL-D00	PRED-SIM-DA-M04	suwanee_smiles	CDT_SUPERBILL	administrative	\N	api	\N	{"fees": [2800.0], "arches": ["lower"], "payer_id": "delta_dental", "cdt_codes": ["D6010"], "member_id": "DDL-620914-K", "quadrants": ["LL"], "provider_npi": null, "payer_allowed": [null], "tooth_numbers": [19], "tooth_surfaces": [null], "provider_out_of_network": false}	0.950	caller_supplied	2026-08-05T16:18:36.572418+00:00	\N
X12-DA-F04-271-D01	PRED-SIM-DA-F04	suwanee_smiles	X12_271_RESPONSE	eligibility	\N	x12_271	\N	{"payer_id": "delta_dental", "member_id": "DDL-410288-T", "plan_type": "PPO", "group_number": "GRP-44821", "annual_maximum": 2000.0, "deductible_met": 50.0, "coverage_active": true, "enrollment_date": "2019-04-01", "months_enrolled": 88, "deductible_total": 100.0, "implant_coverage": false, "benefit_pct_basic": 80.0, "benefit_pct_major": 50.0, "secondary_payer_id": null, "waiting_period_met": true, "annual_maximum_used": 200.0, "pred_required_codes": ["D2750"], "benefit_pct_implants": 0.0, "deductible_remaining": 50.0, "missing_tooth_clause": true, "benefit_pct_preventive": 100.0, "annual_maximum_remaining": 1800.0, "coordination_of_benefits": false, "missing_tooth_clause_confirmed": false}	0.980	deterministic	2026-08-05T16:18:44.124872+00:00	\N
DA-C10-PRED_LETTER	PRED-SIM-DA-C10	suwanee_smiles	PRED_LETTER	administrative	\N	s3	accord-dental-documents	{"decision": "pended", "pred_number": "PD-DAC10", "denial_reason": "Provider is on the OIG exclusion list.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["PROVIDER_OIG_EXCLUDED"], "cdt_codes_reviewed": ["D2750"], "denial_reason_text": "Provider is on the OIG exclusion list."}	1.000	deterministic	2026-08-06T05:21:10.764636+00:00	suwanee_smiles/DA-C10/DA-C10_PRED_LETTER_PENDED.pdf
PERIO-DA-D01-D02	PRED-SIM-DA-D01	suwanee_smiles	PERIO_CHART	clinical	\N	api	\N	{"exam_date": "2026-08-05", "charted_on": "2026-08-05", "bleeding_pct": 42.0, "sites_charted": 24, "sites_gte_4mm": 8, "sites_gte_5mm": 8, "sites_gte_6mm": 4, "interpretation": "Probing depths support osseous surgery per AAP criteria.", "perio_diagnosis": "Stage III Periodontitis", "pocket_depth_avg": 3.83, "pocket_depth_max": 6.0, "max_pocket_depth_mm": 6, "bleeding_on_probing_pct": 42.0}	0.900	deterministic	2026-08-06T05:21:10.823167+00:00	suwanee_smiles/DA-D01/DA-D01_PERIO_CHART.pdf
CBCT-DA-D02-D02	PRED-SIM-DA-D02	suwanee_smiles	CBCT_REPORT	clinical	\N	api	\N	{"scan_type": "cone beam CT", "xray_date": "2026-08-05", "date_taken": "2026-08-05", "bone_loss_mm": 6.8, "ridge_width_mm": 6.8, "ridge_height_mm": 11.2, "bone_volume_adequate": true}	0.850	deterministic	2026-08-06T05:21:10.861053+00:00	suwanee_smiles/DA-D02/DA-D02_CBCT_REPORT.pdf
PMS-TB-A01-SUPERBILL-D00	PRED-SIM-TB-A01	tampa_smiles	CDT_SUPERBILL	administrative	\N	api	\N	{"fees": [1400.0], "arches": ["upper"], "payer_id": "humana_dpo", "cdt_codes": ["D2750"], "member_id": "HUM-771204-C", "quadrants": ["UL"], "provider_npi": null, "payer_allowed": [null], "tooth_numbers": [14], "tooth_surfaces": ["MOD"], "provider_out_of_network": false}	0.950	caller_supplied	2026-08-06T13:35:17.794770+00:00	\N
INS-TB-A01-CARD-D04	PRED-SIM-TB-A01	tampa_smiles	INSURANCE_CARD	eligibility	\N	api	\N	{"payer_id": "humana_dpo", "member_id": "HUM-771204-C", "plan_type": "DPPO", "group_number": "GRP-HUM-11", "coverage_active": true}	0.950	caller_supplied	2026-08-06T13:42:02.524864+00:00	tampa_smiles/TB-A01/TB-A01_INSURANCE_CARD.pdf
X12-DA-M04-271-D01	PRED-SIM-DA-M04	suwanee_smiles	X12_271_RESPONSE	eligibility	\N	x12_271	\N	{"payer_id": "delta_dental", "member_id": "DDL-620914-K", "plan_type": "PPO", "group_number": "GRP-44821", "annual_maximum": 2000.0, "deductible_met": 50.0, "coverage_active": true, "enrollment_date": "2021-01-01", "months_enrolled": 67, "deductible_total": 100.0, "implant_coverage": true, "benefit_pct_basic": 80.0, "benefit_pct_major": 50.0, "secondary_payer_id": null, "waiting_period_met": true, "annual_maximum_used": 200.0, "pred_required_codes": ["D6010"], "benefit_pct_implants": 50.0, "deductible_remaining": 50.0, "missing_tooth_clause": true, "benefit_pct_preventive": 100.0, "annual_maximum_remaining": 1800.0, "coordination_of_benefits": false, "missing_tooth_clause_confirmed": false}	0.980	deterministic	2026-08-05T16:18:36.572418+00:00	\N
PMS-DA-F01-SUPERBILL-D00	PRED-SIM-DA-F01	suwanee_smiles	CDT_SUPERBILL	administrative	\N	api	\N	{"fees": [1650.0], "arches": ["upper"], "payer_id": "delta_dental", "cdt_codes": ["D2740"], "member_id": "DDL-826140-G", "quadrants": ["UR"], "provider_npi": null, "payer_allowed": [null], "tooth_numbers": [8], "tooth_surfaces": ["MI"], "provider_out_of_network": false}	0.950	caller_supplied	2026-08-05T16:18:39.602354+00:00	\N
DA-D01-PRED_LETTER	PRED-SIM-DA-D01	suwanee_smiles	PRED_LETTER	administrative	\N	s3	accord-dental-documents	{"decision": "pended", "pred_number": "PD-DAD01", "denial_reason": "Out-of-network provider and bone graft bundled with implant.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["COVERAGE_BUNDLING_CONFLICT", "PROVIDER_OUT_OF_NETWORK"], "cdt_codes_reviewed": ["D4260", "D6010", "D7953"], "denial_reason_text": "Out-of-network provider and bone graft bundled with implant."}	1.000	deterministic	2026-08-06T05:21:10.842415+00:00	suwanee_smiles/DA-D01/DA-D01_PRED_LETTER_PENDED.pdf
PMS-DA-M05-SUPERBILL-D00	PRED-SIM-DA-M05	suwanee_smiles	CDT_SUPERBILL	administrative	\N	api	\N	{"fees": [1450.0], "arches": ["upper"], "payer_id": "delta_dental", "cdt_codes": ["D2750"], "member_id": "DDL-330728-M", "quadrants": ["UR"], "provider_npi": null, "payer_allowed": [null], "tooth_numbers": [3], "tooth_surfaces": ["MO"], "provider_out_of_network": false}	0.950	caller_supplied	2026-08-05T16:18:38.174295+00:00	\N
NOTE-DA-D02-D04	PRED-SIM-DA-D02	suwanee_smiles	CLINICAL_NOTE	clinical	\N	api	\N	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D6010", "D6010", "D6010", "D6010", "D7953", "D7953", "D7953", "D7953", "D6065", "D6065", "D6065", "D6065"], "diagnosis": "Twelve lines: four implants, four grafts, four crowns. Every graft bundles.", "narrative": "D6010+D6010+D6010+D6010+D7953+D7953+D7953+D7953+D6065+D6065+D6065+D6065 tooth #3, #6, #11, #14 Procedures planned: D6010, D6010, D6010, D6010, D7953, D7953, D7953, D7953, D6065, D6065, D6065, D6065 Documentation is complete, but four grafts at once always go to human review.", "visit_date": "2026-08-05", "treatment_plan": "D6010+D6010+D6010+D6010+D7953+D7953+D7953+D7953+D6065+D6065+D6065+D6065 tooth #3, #6, #11, #14", "cdt_codes_noted": ["D6010", "D6065", "D7953"], "chief_complaint": "Complex â€” All-on-4 Full Arch $35K", "narrative_present": true, "primary_diagnosis": "Twelve lines: four implants, four grafts, four crowns. Every graft bundles."}	0.900	deterministic	2026-08-06T05:21:10.881487+00:00	suwanee_smiles/DA-D02/DA-D02_CLINICAL_NOTE.pdf
PAN-DA-D02-D03	PRED-SIM-DA-D02	suwanee_smiles	XRAY_PAN	clinical	\N	api	\N	{"pathology": "Generalized bone loss", "xray_date": "2026-08-05", "xray_type": "panoramic", "date_taken": "2026-08-05", "bone_loss_mm": 5.1, "tooth_number": null, "bone_loss_pct": 40.0, "image_quality": "DIAGNOSTIC"}	0.850	deterministic	2026-08-06T05:21:10.900888+00:00	suwanee_smiles/DA-D02/DA-D02_PANORAMIC_XRAY.pdf
X12-DA-C07-271-D01	PRED-SIM-DA-C07	suwanee_smiles	X12_271_RESPONSE	eligibility	\N	x12_271	\N	{"payer_id": "metlife", "member_id": "MET-330281-A", "plan_type": "PDP", "group_number": "GRP-MET-04", "annual_maximum": 2000.0, "deductible_met": 50.0, "coverage_active": true, "enrollment_date": "2018-01-01", "months_enrolled": 103, "deductible_total": 100.0, "implant_coverage": false, "benefit_pct_basic": 80.0, "benefit_pct_major": 50.0, "secondary_payer_id": null, "waiting_period_met": true, "annual_maximum_used": 200.0, "pred_required_codes": [], "benefit_pct_implants": 0.0, "deductible_remaining": 50.0, "missing_tooth_clause": true, "benefit_pct_preventive": 100.0, "annual_maximum_remaining": 1800.0, "coordination_of_benefits": false, "missing_tooth_clause_confirmed": false}	0.980	deterministic	2026-08-05T16:18:48.573508+00:00	\N
HIST-DA-F03-PRIOR-D00	PRED-SIM-DA-F03	suwanee_smiles	PRED_LETTER_PENDED	administrative	\N	payer_portal	\N	{"member_id": "DDL-507742-W", "prior_services": [{"status": "paid", "cdt_code": "D2750", "tooth_number": 3, "date_of_service": "2021-09-04"}], "open_pred_requests": []}	0.990	deterministic	2026-08-05T16:18:42.521617+00:00	\N
PMS-DA-F03-SUPERBILL-D00	PRED-SIM-DA-F03	suwanee_smiles	CDT_SUPERBILL	administrative	\N	api	\N	{"fees": [1450.0], "arches": ["upper"], "payer_id": "delta_dental", "cdt_codes": ["D2750"], "member_id": "DDL-507742-W", "quadrants": ["UR"], "provider_npi": null, "payer_allowed": [null], "tooth_numbers": [3], "tooth_surfaces": ["MOD"], "provider_out_of_network": false}	0.950	caller_supplied	2026-08-05T16:18:42.521617+00:00	\N
X12-DA-C09-271-D01	PRED-SIM-DA-C09	suwanee_smiles	X12_271_RESPONSE	eligibility	\N	x12_271	\N	{"payer_id": "delta_dental", "member_id": "DDL-880417-T", "plan_type": "PPO", "group_number": "GRP-77103", "annual_maximum": 2000.0, "deductible_met": 50.0, "coverage_active": true, "enrollment_date": "2017-01-01", "months_enrolled": 115, "deductible_total": 100.0, "implant_coverage": true, "benefit_pct_basic": 80.0, "benefit_pct_major": 50.0, "secondary_payer_id": null, "waiting_period_met": true, "annual_maximum_used": 200.0, "pred_required_codes": ["D6010"], "benefit_pct_implants": 50.0, "deductible_remaining": 50.0, "missing_tooth_clause": true, "benefit_pct_preventive": 100.0, "annual_maximum_remaining": 1800.0, "coordination_of_benefits": false, "missing_tooth_clause_confirmed": false}	0.980	deterministic	2026-08-05T16:18:51.500107+00:00	\N
PMS-DA-F02-SUPERBILL-D00	PRED-SIM-DA-F02	suwanee_smiles	CDT_SUPERBILL	administrative	\N	api	\N	{"fees": [1850.0], "arches": ["upper"], "payer_id": "delta_dental", "cdt_codes": ["D4260"], "member_id": "DDL-193355-J", "quadrants": ["UR"], "provider_npi": null, "payer_allowed": [null], "tooth_numbers": [null], "tooth_surfaces": [null], "provider_out_of_network": false}	0.950	caller_supplied	2026-08-05T16:18:41.049392+00:00	\N
X12-DA-F02-271-D01	PRED-SIM-DA-F02	suwanee_smiles	X12_271_RESPONSE	eligibility	\N	x12_271	\N	{"payer_id": "delta_dental", "member_id": "DDL-193355-J", "plan_type": "PPO", "group_number": "GRP-55290", "annual_maximum": 2000.0, "deductible_met": 50.0, "coverage_active": true, "enrollment_date": "2019-01-01", "months_enrolled": 91, "deductible_total": 100.0, "implant_coverage": false, "benefit_pct_basic": 80.0, "benefit_pct_major": 50.0, "secondary_payer_id": null, "waiting_period_met": true, "annual_maximum_used": 200.0, "pred_required_codes": ["D4260"], "benefit_pct_implants": 0.0, "deductible_remaining": 50.0, "missing_tooth_clause": true, "benefit_pct_preventive": 100.0, "annual_maximum_remaining": 1800.0, "coordination_of_benefits": false, "missing_tooth_clause_confirmed": false}	0.980	deterministic	2026-08-05T16:18:41.049392+00:00	\N
DA-D02-PRED_LETTER	PRED-SIM-DA-D02	suwanee_smiles	PRED_LETTER	administrative	\N	s3	accord-dental-documents	{"decision": "pended", "pred_number": "PD-DAD02", "denial_reason": "Four simultaneous bone grafts bundled with four implants.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["CLINICAL_NARRATIVE_REQUIRED", "COVERAGE_BUNDLING_CONFLICT"], "cdt_codes_reviewed": ["D6010", "D6065", "D7953"], "denial_reason_text": "Four simultaneous bone grafts bundled with four implants."}	1.000	deterministic	2026-08-06T05:21:10.921768+00:00	suwanee_smiles/DA-D02/DA-D02_PRED_LETTER_PENDED.pdf
PMS-TB-C01-SUPERBILL-D00	PRED-SIM-TB-C01	tampa_smiles	CDT_SUPERBILL	administrative	\N	api	\N	{"fees": [420.0, 420.0], "arches": ["upper", "upper"], "payer_id": "guardian_dpo", "cdt_codes": ["D4341", "D4341"], "member_id": "GRD-618470-T", "quadrants": ["UR", "UL"], "provider_npi": null, "payer_allowed": [null, null], "tooth_numbers": [null, null], "tooth_surfaces": [null, null], "provider_out_of_network": false}	0.950	caller_supplied	2026-08-06T13:35:21.110657+00:00	\N
X12-TB-C01-271-D01	PRED-SIM-TB-C01	tampa_smiles	X12_271_RESPONSE	eligibility	\N	x12_271	\N	{"payer_id": "guardian_dpo", "member_id": "GRD-618470-T", "plan_type": "DPPO", "group_number": "GRP-GRD-07", "annual_maximum": 2000.0, "deductible_met": 50.0, "coverage_active": true, "enrollment_date": "2019-01-01", "months_enrolled": 91, "deductible_total": 100.0, "implant_coverage": true, "benefit_pct_basic": 80.0, "benefit_pct_major": 50.0, "secondary_payer_id": null, "waiting_period_met": true, "annual_maximum_used": 200.0, "pred_required_codes": [], "benefit_pct_implants": 50.0, "deductible_remaining": 50.0, "missing_tooth_clause": true, "benefit_pct_preventive": 100.0, "annual_maximum_remaining": 1800.0, "coordination_of_benefits": false, "missing_tooth_clause_confirmed": false}	0.980	deterministic	2026-08-06T13:35:21.110657+00:00	\N
HIST-DA-U01-PRIOR-D00	PRED-SIM-DA-U01	suwanee_smiles	PRED_LETTER_PENDED	administrative	\N	payer_portal	\N	{"member_id": "DDL-201455-T", "prior_services": [{"status": "paid", "cdt_code": "D1110", "tooth_number": null, "date_of_service": "2025-06-06"}], "open_pred_requests": []}	0.990	deterministic	2026-08-06T05:18:41.317658+00:00	\N
INS-TB-C01-CARD-D03	PRED-SIM-TB-C01	tampa_smiles	INSURANCE_CARD	eligibility	\N	api	\N	{"payer_id": "guardian_dpo", "member_id": "GRD-618470-T", "plan_type": "DPPO", "group_number": "GRP-GRD-07", "coverage_active": true}	0.950	caller_supplied	2026-08-06T13:42:02.703233+00:00	tampa_smiles/TB-C01/TB-C01_INSURANCE_CARD.pdf
PMS-DA-U01-SUPERBILL-D00	PRED-SIM-DA-U01	suwanee_smiles	CDT_SUPERBILL	administrative	\N	api	\N	{"fees": [150.0], "arches": [null], "payer_id": "delta_dental", "cdt_codes": ["D1110"], "member_id": "DDL-201455-T", "quadrants": [null], "provider_npi": null, "payer_allowed": [null], "tooth_numbers": [null], "tooth_surfaces": [null], "provider_out_of_network": false}	0.950	caller_supplied	2026-08-06T05:18:41.317658+00:00	\N
HIST-DA-F04-PRIOR-D00	PRED-SIM-DA-F04	suwanee_smiles	PRED_LETTER_PENDED	administrative	\N	payer_portal	\N	{"member_id": "DDL-410288-T", "prior_services": [{"status": "paid", "cdt_code": "D2950", "tooth_number": 14, "date_of_service": "2026-08-03"}], "open_pred_requests": []}	0.990	deterministic	2026-08-05T16:18:44.123874+00:00	\N
NOTE-DA-D03-D03	PRED-SIM-DA-D03	suwanee_smiles	CLINICAL_NOTE	clinical	\N	api	\N	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D6010", "D6065"], "diagnosis": "Enrolled 11 months ago. Major services need 12. Denied by one month.", "narrative": "Clinically perfect and still denied â€” resubmit after the waiting period ends.", "visit_date": "2026-08-05", "treatment_plan": "D6010+D6065 tooth #19", "cdt_codes_noted": ["D6010", "D6065"], "chief_complaint": "Complex â€” Waiting Period One Month Short", "narrative_present": true, "primary_diagnosis": "Enrolled 11 months ago. Major services need 12. Denied by one month."}	0.900	deterministic	2026-08-06T05:21:10.941153+00:00	suwanee_smiles/DA-D03/DA-D03_CLINICAL_NOTE.pdf
X12-DA-F03-271-D01	PRED-SIM-DA-F03	suwanee_smiles	X12_271_RESPONSE	eligibility	\N	x12_271	\N	{"payer_id": "delta_dental", "member_id": "DDL-507742-W", "plan_type": "PPO", "group_number": "GRP-77103", "annual_maximum": 2000.0, "deductible_met": 50.0, "coverage_active": true, "enrollment_date": "2016-01-01", "months_enrolled": 127, "deductible_total": 100.0, "implant_coverage": false, "benefit_pct_basic": 80.0, "benefit_pct_major": 50.0, "secondary_payer_id": null, "waiting_period_met": true, "annual_maximum_used": 200.0, "pred_required_codes": ["D2750"], "benefit_pct_implants": 0.0, "deductible_remaining": 50.0, "missing_tooth_clause": true, "benefit_pct_preventive": 100.0, "annual_maximum_remaining": 1800.0, "coordination_of_benefits": false, "missing_tooth_clause_confirmed": false}	0.980	deterministic	2026-08-05T16:18:42.521617+00:00	\N
XRAY-DA-D03-D02	PRED-SIM-DA-D03	suwanee_smiles	XRAY_PA	clinical	19	api	\N	{"pathology": "Edentulous space #19 with healed ridge", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "bone_loss_mm": 4.2, "tooth_number": 19, "bone_loss_pct": 35.0, "image_quality": "DIAGNOSTIC"}	1.000	deterministic	2026-08-06T05:21:10.961217+00:00	suwanee_smiles/DA-D03/DA-D03_PA_XRAY_TOOTH19.pdf
XRAY-DA-D04-D02	PRED-SIM-DA-D04	suwanee_smiles	XRAY_PA	clinical	8	api	\N	{"pathology": "Caries extending to pulp chamber, tooth #8", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "tooth_number": 8, "decay_present": true, "image_quality": "DIAGNOSTIC"}	0.700	deterministic	2026-08-06T05:21:11.019405+00:00	suwanee_smiles/DA-D04/DA-D04_PA_XRAY_TOOTH8.pdf
PMS-DA-F04-SUPERBILL-D00	PRED-SIM-DA-F04	suwanee_smiles	CDT_SUPERBILL	administrative	\N	api	\N	{"fees": [1450.0], "arches": ["upper"], "payer_id": "delta_dental", "cdt_codes": ["D2750"], "member_id": "DDL-410288-T", "quadrants": ["UL"], "provider_npi": null, "payer_allowed": [null], "tooth_numbers": [14], "tooth_surfaces": ["MOD"], "provider_out_of_network": false}	0.950	caller_supplied	2026-08-05T16:18:44.123874+00:00	\N
PMS-TB-D01-SUPERBILL-D00	PRED-SIM-TB-D01	tampa_smiles	CDT_SUPERBILL	administrative	\N	api	\N	{"fees": [1650.0], "arches": ["upper"], "payer_id": "aetna_dmo", "cdt_codes": ["D2740"], "member_id": "AET-905513-P", "quadrants": ["UR"], "provider_npi": null, "payer_allowed": [null], "tooth_numbers": [8], "tooth_surfaces": ["MIF"], "provider_out_of_network": false}	0.950	caller_supplied	2026-08-06T13:35:22.524103+00:00	\N
X12-TB-D01-271-D01	PRED-SIM-TB-D01	tampa_smiles	X12_271_RESPONSE	eligibility	\N	x12_271	\N	{"payer_id": "aetna_dmo", "member_id": "AET-905513-P", "plan_type": "DMO", "group_number": "GRP-AET-02", "annual_maximum": 1500.0, "deductible_met": 0.0, "coverage_active": true, "enrollment_date": "2018-01-01", "months_enrolled": 103, "deductible_total": 0.0, "implant_coverage": false, "benefit_pct_basic": 80.0, "benefit_pct_major": 50.0, "secondary_payer_id": null, "waiting_period_met": true, "annual_maximum_used": 0.0, "pred_required_codes": ["D2740"], "benefit_pct_implants": 0.0, "deductible_remaining": 0.0, "missing_tooth_clause": true, "benefit_pct_preventive": 100.0, "annual_maximum_remaining": 1500.0, "coordination_of_benefits": false, "missing_tooth_clause_confirmed": false}	0.980	deterministic	2026-08-06T13:35:22.524103+00:00	\N
HIST-DA-U05-PRIOR-D00	PRED-SIM-DA-U05	suwanee_smiles	PRED_LETTER_PENDED	administrative	\N	payer_portal	\N	{"member_id": "DDL-447215-W", "prior_services": [{"status": "paid", "cdt_code": "D4910", "tooth_number": null, "date_of_service": "2025-06-06"}], "open_pred_requests": []}	0.990	deterministic	2026-08-06T05:18:46.944019+00:00	\N
INS-TB-D01-CARD-D04	PRED-SIM-TB-D01	tampa_smiles	INSURANCE_CARD	eligibility	\N	api	\N	{"payer_id": "aetna_dmo", "member_id": "AET-905513-P", "plan_type": "DMO", "group_number": "GRP-AET-02", "coverage_active": true}	0.950	caller_supplied	2026-08-06T13:42:02.764275+00:00	tampa_smiles/TB-D01/TB-D01_INSURANCE_CARD.pdf
XRAY-TB-D01-D02	PRED-SIM-TB-D01	tampa_smiles	XRAY_PA	clinical	8	api	\N	{"pathology": "Caries extending to pulp chamber, tooth #8", "xray_date": "2026-08-06", "xray_type": "periapical", "date_taken": "2026-08-06", "tooth_number": 8, "decay_present": true, "image_quality": "DIAGNOSTIC"}	0.700	deterministic	2026-08-06T13:42:02.807076+00:00	tampa_smiles/TB-D01/TB-D01_PA_XRAY_TOOTH8.pdf
PMS-DA-U05-SUPERBILL-D00	PRED-SIM-DA-U05	suwanee_smiles	CDT_SUPERBILL	administrative	\N	api	\N	{"fees": [175.0], "arches": [null], "payer_id": "delta_dental", "cdt_codes": ["D4910"], "member_id": "DDL-447215-W", "quadrants": [null], "provider_npi": null, "payer_allowed": [null], "tooth_numbers": [null], "tooth_surfaces": [null], "provider_out_of_network": false}	0.950	caller_supplied	2026-08-06T05:18:46.944019+00:00	\N
PMS-DA-C06-SUPERBILL-D00	PRED-SIM-DA-C06	suwanee_smiles	CDT_SUPERBILL	administrative	\N	api	\N	{"fees": [1250.0], "arches": ["upper"], "payer_id": "cigna", "cdt_codes": ["D2740"], "member_id": "CIG-774120-W", "quadrants": ["UR"], "provider_npi": null, "payer_allowed": [null], "tooth_numbers": [8], "tooth_surfaces": ["MI"], "provider_out_of_network": false}	0.950	caller_supplied	2026-08-05T16:18:47.138424+00:00	\N
NOTE-DA-C06-D03	PRED-SIM-DA-C06	suwanee_smiles	CLINICAL_NOTE	clinical	\N	api	\N	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D2740"], "diagnosis": "D2740 on anterior tooth #8 under Cigna DPPO. Cigna pays the all-ceramic rate.", "narrative": "Delta downgrades D2740 to the PFM rate; Cigna does not. Same tooth, same code, different patient responsibility â€”", "visit_date": "2026-08-05", "treatment_plan": "D2740 tooth #8", "cdt_codes_noted": ["D2740"], "chief_complaint": "Cigna â€” All-Ceramic Crown Not Downgraded", "narrative_present": true, "primary_diagnosis": "D2740 on anterior tooth #8 under Cigna DPPO. Cigna pays the all-ceramic rate."}	0.900	deterministic	2026-08-06T05:21:10.481448+00:00	suwanee_smiles/DA-C06/DA-C06_CLINICAL_NOTE.pdf
INS-DL-A01-CARD-D04	PRED-SIM-DL-A01	dallas_dental	INSURANCE_CARD	eligibility	\N	api	\N	{"payer_id": "guardian_dpo", "member_id": "GRD-140725-J", "plan_type": "DPPO", "group_number": "GRP-GRD-07", "coverage_active": true}	0.950	caller_supplied	2026-08-06T13:43:06.856984+00:00	dallas_dental/DL-A01/DL-A01_INSURANCE_CARD.pdf
PMS-DA-F05-SUPERBILL-D00	PRED-SIM-DA-F05	suwanee_smiles	CDT_SUPERBILL	administrative	\N	api	\N	{"fees": [2800.0], "arches": ["lower"], "payer_id": "delta_dental", "cdt_codes": ["D6010"], "member_id": "DDL-284900-D", "quadrants": ["LL"], "provider_npi": null, "payer_allowed": [2800.0], "tooth_numbers": [19], "tooth_surfaces": [null], "provider_out_of_network": false}	0.950	caller_supplied	2026-08-05T16:18:45.738088+00:00	\N
X12-DA-F05-271-D01	PRED-SIM-DA-F05	suwanee_smiles	X12_271_RESPONSE	eligibility	\N	x12_271	\N	{"payer_id": "delta_dental", "member_id": "DDL-284900-D", "plan_type": "PPO", "group_number": "GRP-44821", "annual_maximum": 2000.0, "deductible_met": 50.0, "coverage_active": true, "enrollment_date": "2019-01-01", "months_enrolled": 91, "deductible_total": 100.0, "implant_coverage": true, "benefit_pct_basic": 80.0, "benefit_pct_major": 50.0, "secondary_payer_id": null, "waiting_period_met": true, "annual_maximum_used": 200.0, "pred_required_codes": ["D6010"], "benefit_pct_implants": 50.0, "deductible_remaining": 50.0, "missing_tooth_clause": true, "benefit_pct_preventive": 100.0, "annual_maximum_remaining": 1800.0, "coordination_of_benefits": false, "missing_tooth_clause_confirmed": false}	0.980	deterministic	2026-08-05T16:18:45.738088+00:00	\N
XRAY-DA-C06-D02	PRED-SIM-DA-C06	suwanee_smiles	XRAY_PA	clinical	8	api	\N	{"pathology": "Caries extending to pulp chamber, tooth #8", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "tooth_number": 8, "decay_present": true, "image_quality": "DIAGNOSTIC"}	0.700	deterministic	2026-08-06T05:21:10.499991+00:00	suwanee_smiles/DA-C06/DA-C06_PA_XRAY_TOOTH8.pdf
DA-D03-PRED_LETTER	PRED-SIM-DA-D03	suwanee_smiles	PRED_LETTER	administrative	\N	s3	accord-dental-documents	{"decision": "denied", "pred_number": "PD-DAD03", "denial_reason": "12-month waiting period not met. Eligible 09/01/2026.", "pred_decision": "DENIED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["ELIG_WAITING_PERIOD_NOT_MET"], "cdt_codes_reviewed": ["D6010", "D6065"], "denial_reason_text": "12-month waiting period not met. Eligible 09/01/2026."}	1.000	deterministic	2026-08-06T05:21:10.980517+00:00	suwanee_smiles/DA-D03/DA-D03_PRED_LETTER_DENIED.pdf
PMS-TB-U01-SUPERBILL-D00	PRED-SIM-TB-U01	tampa_smiles	CDT_SUPERBILL	administrative	\N	api	\N	{"fees": [150.0], "arches": [null], "payer_id": "humana_dpo", "cdt_codes": ["D1110"], "member_id": "HUM-224806-A", "quadrants": [null], "provider_npi": null, "payer_allowed": [null], "tooth_numbers": [null], "tooth_surfaces": [null], "provider_out_of_network": false}	0.950	caller_supplied	2026-08-06T13:35:24.152773+00:00	\N
X12-TB-U01-271-D01	PRED-SIM-TB-U01	tampa_smiles	X12_271_RESPONSE	eligibility	\N	x12_271	\N	{"payer_id": "humana_dpo", "member_id": "HUM-224806-A", "plan_type": "DPPO", "group_number": "GRP-HUM-11", "annual_maximum": 1500.0, "deductible_met": 50.0, "coverage_active": true, "enrollment_date": "2022-01-01", "months_enrolled": 55, "deductible_total": 50.0, "implant_coverage": true, "benefit_pct_basic": 80.0, "benefit_pct_major": 50.0, "secondary_payer_id": null, "waiting_period_met": true, "annual_maximum_used": 0.0, "pred_required_codes": [], "benefit_pct_implants": 50.0, "deductible_remaining": 0.0, "missing_tooth_clause": false, "benefit_pct_preventive": 100.0, "annual_maximum_remaining": 1500.0, "coordination_of_benefits": false, "missing_tooth_clause_confirmed": false}	0.980	deterministic	2026-08-06T13:35:24.152773+00:00	\N
PMS-DL-A01-SUPERBILL-D00	PRED-SIM-DL-A01	dallas_dental	CDT_SUPERBILL	administrative	\N	api	\N	{"fees": [2800.0, 1800.0], "arches": ["lower", "lower"], "payer_id": "guardian_dpo", "cdt_codes": ["D6010", "D6065"], "member_id": "GRD-140725-J", "quadrants": ["LR", "LR"], "provider_npi": null, "payer_allowed": [null, null], "tooth_numbers": [30, 30], "tooth_surfaces": [null, null], "provider_out_of_network": false}	0.950	caller_supplied	2026-08-06T13:35:54.537826+00:00	\N
INS-TB-U01-CARD-D02	PRED-SIM-TB-U01	tampa_smiles	INSURANCE_CARD	eligibility	\N	api	\N	{"payer_id": "humana_dpo", "member_id": "HUM-224806-A", "plan_type": "DPPO", "group_number": "GRP-HUM-11", "coverage_active": true}	0.950	caller_supplied	2026-08-06T13:42:02.872575+00:00	tampa_smiles/TB-U01/TB-U01_INSURANCE_CARD.pdf
INS-DA-C07-CARD-D02	PRED-SIM-DA-C07	suwanee_smiles	INSURANCE_CARD	eligibility	\N	api	\N	{"payer_id": "metlife", "member_id": "MET-330281-A", "plan_type": "PDP", "group_number": "GRP-MET-04", "coverage_active": true}	0.950	caller_supplied	2026-08-06T05:21:10.541644+00:00	suwanee_smiles/DA-C07/DA-C07_INSURANCE_CARD.pdf
NOTE-DA-C08-D03	PRED-SIM-DA-C08	suwanee_smiles	CLINICAL_NOTE	clinical	\N	api	\N	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D2750"], "diagnosis": "Child with Delta primary and Cigna secondary. Primary must adjudicate first.", "narrative": "Birthday rule decides which parent's plan is primary. Submitting to the wrong payer first restarts the clock.", "visit_date": "2026-08-05", "treatment_plan": "D2750 tooth #3", "cdt_codes_noted": ["D2750"], "chief_complaint": "Dual Coverage â€” COB Birthday Rule", "narrative_present": true, "primary_diagnosis": "Child with Delta primary and Cigna secondary. Primary must adjudicate first."}	0.900	deterministic	2026-08-06T05:21:10.581405+00:00	suwanee_smiles/DA-C08/DA-C08_CLINICAL_NOTE.pdf
INS-DA-C08-CARD-D04	PRED-SIM-DA-C08	suwanee_smiles	INSURANCE_CARD	eligibility	\N	api	\N	{"payer_id": "delta_dental", "member_id": "DDL-664201-D", "plan_type": "PPO", "group_number": "GRP-44821", "coverage_active": true, "secondary_payer_id": "cigna", "coordination_of_benefits": true}	0.950	caller_supplied	2026-08-06T05:21:10.600925+00:00	suwanee_smiles/DA-C08/DA-C08_INSURANCE_CARD.pdf
HIST-DA-C07-PRIOR-D00	PRED-SIM-DA-C07	suwanee_smiles	PRED_LETTER_PENDED	administrative	\N	payer_portal	\N	{"member_id": "MET-330281-A", "prior_services": [{"status": "paid", "cdt_code": "D0330", "tooth_number": null, "date_of_service": "2023-02-04"}], "open_pred_requests": []}	0.990	deterministic	2026-08-05T16:18:48.573508+00:00	\N
X12-DA-C06-271-D01	PRED-SIM-DA-C06	suwanee_smiles	X12_271_RESPONSE	eligibility	\N	x12_271	\N	{"payer_id": "cigna", "member_id": "CIG-774120-W", "plan_type": "DPPO", "group_number": "GRP-CIG-01", "annual_maximum": 2000.0, "deductible_met": 50.0, "coverage_active": true, "enrollment_date": "2020-01-01", "months_enrolled": 79, "deductible_total": 100.0, "implant_coverage": false, "benefit_pct_basic": 80.0, "benefit_pct_major": 50.0, "secondary_payer_id": null, "waiting_period_met": true, "annual_maximum_used": 200.0, "pred_required_codes": ["D2740"], "benefit_pct_implants": 0.0, "deductible_remaining": 50.0, "missing_tooth_clause": true, "benefit_pct_preventive": 100.0, "annual_maximum_remaining": 1800.0, "coordination_of_benefits": false, "missing_tooth_clause_confirmed": false}	0.980	deterministic	2026-08-05T16:18:47.138424+00:00	\N
INS-DL-C01-CARD-D04	PRED-SIM-DL-C01	dallas_dental	INSURANCE_CARD	eligibility	\N	api	\N	{"payer_id": "delta_dental", "member_id": "DDL-668204-W", "plan_type": "PPO", "group_number": "GRP-44821", "coverage_active": true}	0.950	caller_supplied	2026-08-06T13:43:07.010549+00:00	dallas_dental/DL-C01/DL-C01_INSURANCE_CARD.pdf
XRAY-DL-C01-D02	PRED-SIM-DL-C01	dallas_dental	XRAY_PA	clinical	3	api	\N	{"pathology": "Caries extending to pulp chamber, tooth #3", "xray_date": "2026-08-06", "xray_type": "periapical", "date_taken": "2026-08-06", "tooth_number": 3, "decay_present": true, "image_quality": "DIAGNOSTIC"}	0.700	deterministic	2026-08-06T13:43:07.030163+00:00	dallas_dental/DL-C01/DL-C01_PA_XRAY_TOOTH3.pdf
PMS-DA-C07-SUPERBILL-D00	PRED-SIM-DA-C07	suwanee_smiles	CDT_SUPERBILL	administrative	\N	api	\N	{"fees": [155.0], "arches": [null], "payer_id": "metlife", "cdt_codes": ["D0330"], "member_id": "MET-330281-A", "quadrants": [null], "provider_npi": null, "payer_allowed": [null], "tooth_numbers": [null], "tooth_surfaces": [null], "provider_out_of_network": false}	0.950	caller_supplied	2026-08-05T16:18:48.573508+00:00	\N
XRAY-DA-C08-D02	PRED-SIM-DA-C08	suwanee_smiles	XRAY_PA	clinical	3	api	\N	{"pathology": "Caries extending to pulp chamber, tooth #3", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "tooth_number": 3, "decay_present": true, "image_quality": "DIAGNOSTIC"}	0.700	deterministic	2026-08-06T05:21:10.621669+00:00	suwanee_smiles/DA-C08/DA-C08_PA_XRAY_TOOTH3.pdf
NOTE-DA-D04-D03	PRED-SIM-DA-D04	suwanee_smiles	CLINICAL_NOTE	clinical	\N	api	\N	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D2740"], "diagnosis": "D2740 on anterior tooth #8. Covered, but reimbursed at the D2750 PFM rate.", "narrative": "Approved, but the patient owes the all-ceramic to PFM difference â€” quote it up front.", "visit_date": "2026-08-05", "treatment_plan": "D2740 tooth #8", "cdt_codes_noted": ["D2740", "D2750"], "chief_complaint": "Complex â€” All-Ceramic Crown Downgraded", "narrative_present": true, "primary_diagnosis": "D2740 on anterior tooth #8. Covered, but reimbursed at the D2750 PFM rate."}	0.900	deterministic	2026-08-06T05:21:10.999661+00:00	suwanee_smiles/DA-D04/DA-D04_CLINICAL_NOTE.pdf
XRAY-DA-F01-D03	PRED-SIM-DA-F01	suwanee_smiles	XRAY_PA	clinical	8	api	\N	{"pathology": "Caries extending to pulp chamber, tooth #8", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "tooth_number": 8, "decay_present": true, "image_quality": "DIAGNOSTIC"}	0.700	deterministic	2026-08-06T05:21:11.160305+00:00	suwanee_smiles/DA-F01/DA-F01_PA_XRAY_TOOTH8.pdf
PMS-DA-C08-SUPERBILL-D00	PRED-SIM-DA-C08	suwanee_smiles	CDT_SUPERBILL	administrative	\N	api	\N	{"fees": [1190.0], "arches": ["upper"], "payer_id": "delta_dental", "cdt_codes": ["D2750"], "member_id": "DDL-664201-D", "quadrants": ["UR"], "provider_npi": null, "payer_allowed": [null], "tooth_numbers": [3], "tooth_surfaces": ["MOD"], "provider_out_of_network": false}	0.950	caller_supplied	2026-08-05T16:18:49.864804+00:00	\N
NOTE-DA-C09-D03	PRED-SIM-DA-C09	suwanee_smiles	CLINICAL_NOTE	clinical	\N	api	\N	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D6010"], "diagnosis": "Implant requested for a patient on IV zoledronic acid. Osteonecrosis risk.", "narrative": "IV bisphosphonate is an absolute contraindication for implants. Caught from the medical history before the payer ever sees it â€” and before the patient is harmed.", "visit_date": "2026-08-05", "medications": ["zoledronic acid", "calcium carbonate"], "treatment_plan": "D6010 tooth #19", "cdt_codes_noted": ["D6010"], "chief_complaint": "Medical History â€” IV Bisphosphonate Before Implant", "medical_history": "Patient on IV zoledronic acid (Zometa) for metastatic bone disease, ongoing since 2024.", "narrative_present": true, "primary_diagnosis": "Implant requested for a patient on IV zoledronic acid. Osteonecrosis risk."}	0.900	deterministic	2026-08-06T05:21:10.665047+00:00	suwanee_smiles/DA-C09/DA-C09_CLINICAL_NOTE.pdf
XRAY-DA-C09-D02	PRED-SIM-DA-C09	suwanee_smiles	XRAY_PA	clinical	19	api	\N	{"pathology": "Edentulous space #19 with healed ridge", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "bone_loss_mm": 4.2, "tooth_number": 19, "bone_loss_pct": 35.0, "image_quality": "DIAGNOSTIC"}	1.000	deterministic	2026-08-06T05:21:10.685798+00:00	suwanee_smiles/DA-C09/DA-C09_PA_XRAY_TOOTH19.pdf
X12-DA-C08-271-D01	PRED-SIM-DA-C08	suwanee_smiles	X12_271_RESPONSE	eligibility	\N	x12_271	\N	{"payer_id": "delta_dental", "member_id": "DDL-664201-D", "plan_type": "PPO", "group_number": "GRP-44821", "annual_maximum": 1500.0, "deductible_met": 50.0, "coverage_active": true, "enrollment_date": "2019-01-01", "months_enrolled": 91, "deductible_total": 50.0, "implant_coverage": false, "benefit_pct_basic": 80.0, "benefit_pct_major": 50.0, "secondary_payer_id": "cigna", "waiting_period_met": true, "annual_maximum_used": 0.0, "pred_required_codes": ["D2750"], "benefit_pct_implants": 0.0, "deductible_remaining": 0.0, "missing_tooth_clause": true, "benefit_pct_preventive": 100.0, "annual_maximum_remaining": 1500.0, "coordination_of_benefits": true, "missing_tooth_clause_confirmed": false}	0.980	deterministic	2026-08-05T16:18:49.864804+00:00	\N
DA-D04-PRED_LETTER	PRED-SIM-DA-D04	suwanee_smiles	PRED_LETTER	administrative	\N	s3	accord-dental-documents	{"decision": "approved", "pred_number": "PD-DAD04", "denial_reason": "", "pred_decision": "APPROVED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["COVERAGE_DOWNGRADE_APPLIED"], "cdt_codes_reviewed": ["D2740"]}	1.000	deterministic	2026-08-06T05:21:11.039362+00:00	suwanee_smiles/DA-D04/DA-D04_PRED_LETTER_APPROVED.pdf
CBCT-DA-D05-D04	PRED-SIM-DA-D05	suwanee_smiles	CBCT_REPORT	clinical	\N	api	\N	{"scan_type": "cone beam CT", "xray_date": "2026-08-05", "date_taken": "2026-08-05", "bone_loss_mm": 6.8, "ridge_width_mm": 6.8, "ridge_height_mm": 11.2, "bone_volume_adequate": true}	0.850	deterministic	2026-08-06T05:21:11.058808+00:00	suwanee_smiles/DA-D05/DA-D05_CBCT_REPORT.pdf
NOTE-DA-D05-D03	PRED-SIM-DA-D05	suwanee_smiles	CLINICAL_NOTE	clinical	\N	api	\N	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D6010", "D7953"], "diagnosis": "DA-B04 resubmitted with PA X-ray, independent narrative and CBCT bone volume.", "narrative": "Same procedures as DA-B04 â€” complete documentation is what unbundles the graft.", "visit_date": "2026-08-05", "treatment_plan": "D6010+D7953 tooth #19", "cdt_codes_noted": ["D6010", "D7953"], "chief_complaint": "Complex â€” Bone Graft Unbundled on Resubmission", "narrative_present": true, "primary_diagnosis": "DA-B04 resubmitted with PA X-ray, independent narrative and CBCT bone volume."}	0.900	deterministic	2026-08-06T05:21:11.079082+00:00	suwanee_smiles/DA-D05/DA-D05_CLINICAL_NOTE.pdf
PMS-DA-C09-SUPERBILL-D00	PRED-SIM-DA-C09	suwanee_smiles	CDT_SUPERBILL	administrative	\N	api	\N	{"fees": [1985.0], "arches": ["lower"], "payer_id": "delta_dental", "cdt_codes": ["D6010"], "member_id": "DDL-880417-T", "quadrants": ["LL"], "provider_npi": null, "payer_allowed": [null], "tooth_numbers": [19], "tooth_surfaces": [null], "provider_out_of_network": false}	0.950	caller_supplied	2026-08-05T16:18:51.500107+00:00	\N
XRAY-DA-D05-D02	PRED-SIM-DA-D05	suwanee_smiles	XRAY_PA	clinical	19	api	\N	{"pathology": "Edentulous space #19 with healed ridge", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "bone_loss_mm": 4.5, "tooth_number": 19, "bone_loss_pct": 38.0, "image_quality": "DIAGNOSTIC"}	1.000	deterministic	2026-08-06T05:21:11.100246+00:00	suwanee_smiles/DA-D05/DA-D05_PA_XRAY_TOOTH19.pdf
DA-D05-PRED_LETTER	PRED-SIM-DA-D05	suwanee_smiles	PRED_LETTER	administrative	\N	s3	accord-dental-documents	{"decision": "approved", "pred_number": "PD-DAD05", "denial_reason": "", "pred_decision": "APPROVED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["COVERAGE_PRED_REQUIRED"], "cdt_codes_reviewed": ["D6010", "D7953"]}	1.000	deterministic	2026-08-06T05:21:11.121113+00:00	suwanee_smiles/DA-D05/DA-D05_PRED_LETTER_APPROVED.pdf
NOTE-DA-C10-D03	PRED-SIM-DA-C10	suwanee_smiles	CLINICAL_NOTE	clinical	\N	api	\N	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D2750"], "diagnosis": "Submitting provider appears on the OIG exclusion list. No payer will reimburse.", "narrative": "An excluded provider cannot be paid by any federal or commercial payer. Catching it pre-submission avoids a clawback", "visit_date": "2026-08-05", "treatment_plan": "D2750 tooth #14", "cdt_codes_noted": ["D2750"], "chief_complaint": "Provider Integrity â€” OIG Excluded Provider", "narrative_present": true, "primary_diagnosis": "Submitting provider appears on the OIG exclusion list. No payer will reimburse."}	0.900	deterministic	2026-08-06T05:21:10.726009+00:00	suwanee_smiles/DA-C10/DA-C10_CLINICAL_NOTE.pdf
XRAY-DA-C10-D02	PRED-SIM-DA-C10	suwanee_smiles	XRAY_PA	clinical	14	api	\N	{"pathology": "Caries extending to pulp chamber, tooth #14", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "tooth_number": 14, "decay_present": true, "image_quality": "DIAGNOSTIC"}	0.700	deterministic	2026-08-06T05:21:10.745519+00:00	suwanee_smiles/DA-C10/DA-C10_PA_XRAY_TOOTH14.pdf
NOTE-DA-F01-D02	PRED-SIM-DA-F01	suwanee_smiles	CLINICAL_NOTE	clinical	\N	api	\N	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D2750"], "diagnosis": "D2740 billed at $1,650 while the operative note documents a PFM crown (D2750).", "narrative": "$200 spread between D2740 and D2750 â€” small per case, systematic across a practice.", "visit_date": "2026-08-05", "treatment_plan": "D2740 tooth #8", "cdt_codes_noted": ["D2740", "D2750"], "chief_complaint": "Integrity â€” Upcoding All-Ceramic vs PFM", "narrative_present": true, "primary_diagnosis": "D2740 billed at $1,650 while the operative note documents a PFM crown (D2750)."}	0.900	deterministic	2026-08-06T05:21:11.140100+00:00	suwanee_smiles/DA-F01/DA-F01_CLINICAL_NOTE.pdf
DA-F01-PRED_LETTER	PRED-SIM-DA-F01	suwanee_smiles	PRED_LETTER	administrative	\N	s3	accord-dental-documents	{"decision": "pended", "pred_number": "PD-DAF01", "denial_reason": "Billed code contradicts the documented restoration type.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["COVERAGE_DOWNGRADE_APPLIED", "COVERAGE_SURFACE_MISMATCH"], "cdt_codes_reviewed": ["D2740"], "denial_reason_text": "Billed code contradicts the documented restoration type."}	1.000	deterministic	2026-08-06T05:21:11.180193+00:00	suwanee_smiles/DA-F01/DA-F01_PRED_LETTER_PENDED.pdf
PMS-DA-C10-SUPERBILL-D00	PRED-SIM-DA-C10	suwanee_smiles	CDT_SUPERBILL	administrative	\N	api	\N	{"fees": [1190.0], "arches": ["upper"], "payer_id": "delta_dental", "cdt_codes": ["D2750"], "member_id": "DDL-551903-M", "quadrants": ["UL"], "provider_npi": "0000000001", "payer_allowed": [null], "tooth_numbers": [14], "tooth_surfaces": ["MOD"], "provider_out_of_network": false}	0.950	caller_supplied	2026-08-05T16:18:52.906969+00:00	\N
X12-DA-C10-271-D01	PRED-SIM-DA-C10	suwanee_smiles	X12_271_RESPONSE	eligibility	\N	x12_271	\N	{"payer_id": "delta_dental", "member_id": "DDL-551903-M", "plan_type": "PPO", "group_number": "GRP-44821", "annual_maximum": 2000.0, "deductible_met": 50.0, "coverage_active": true, "enrollment_date": "2020-01-01", "months_enrolled": 79, "deductible_total": 100.0, "implant_coverage": false, "benefit_pct_basic": 80.0, "benefit_pct_major": 50.0, "secondary_payer_id": null, "waiting_period_met": true, "annual_maximum_used": 200.0, "pred_required_codes": ["D2750"], "benefit_pct_implants": 0.0, "deductible_remaining": 50.0, "missing_tooth_clause": true, "benefit_pct_preventive": 100.0, "annual_maximum_remaining": 1800.0, "coordination_of_benefits": false, "missing_tooth_clause_confirmed": false}	0.980	deterministic	2026-08-05T16:18:52.906969+00:00	\N
NOTE-DA-F02-D03	PRED-SIM-DA-F02	suwanee_smiles	CLINICAL_NOTE	clinical	\N	api	\N	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D4260"], "diagnosis": "D4260 billed with a chart showing 3mm pockets â€” surgery is not clinically indicated.", "narrative": "The chart was measured and disproves necessity â€” deny, don't pend for more documents.", "visit_date": "2026-08-05", "treatment_plan": "D4260 tooth multiple quadrants", "cdt_codes_noted": ["D4260"], "chief_complaint": "Integrity â€” Phantom Osseous Surgery", "narrative_present": true, "primary_diagnosis": "D4260 billed with a chart showing 3mm pockets â€” surgery is not clinically indicated."}	0.900	deterministic	2026-08-06T05:21:11.200811+00:00	suwanee_smiles/DA-F02/DA-F02_CLINICAL_NOTE.pdf
X12-DA-B02-271-D01	PRED-SIM-DA-B02	suwanee_smiles	X12_271_RESPONSE	eligibility	\N	x12_271	\N	{"payer_id": "delta_dental", "member_id": "DDL-778234-A", "plan_type": "PPO", "group_number": "GRP-44821", "annual_maximum": 2000.0, "deductible_met": 50.0, "coverage_active": true, "enrollment_date": "2022-01-01", "months_enrolled": 55, "deductible_total": 100.0, "implant_coverage": true, "benefit_pct_basic": 80.0, "benefit_pct_major": 50.0, "secondary_payer_id": null, "waiting_period_met": true, "annual_maximum_used": 200.0, "pred_required_codes": ["D6010", "D6065"], "benefit_pct_implants": 50.0, "deductible_remaining": 50.0, "missing_tooth_clause": true, "benefit_pct_preventive": 100.0, "annual_maximum_remaining": 1800.0, "coordination_of_benefits": false, "missing_tooth_clause_confirmed": true}	0.980	deterministic	2026-08-05T16:18:09.511433+00:00	\N
PERIO-DA-F02-D02	PRED-SIM-DA-F02	suwanee_smiles	PERIO_CHART	clinical	\N	api	\N	{"exam_date": "2026-08-05", "charted_on": "2026-08-05", "bleeding_pct": 8.0, "sites_charted": 24, "sites_gte_4mm": 0, "sites_gte_5mm": 0, "sites_gte_6mm": 0, "interpretation": "Probing depths do not meet the AAP threshold for osseous surgery. Non-surgical therapy is indicated before any", "perio_diagnosis": "Gingivitis / no attachment loss", "pocket_depth_avg": 2.04, "pocket_depth_max": 3.0, "max_pocket_depth_mm": 3, "bleeding_on_probing_pct": 8.0}	0.900	deterministic	2026-08-06T05:21:11.219976+00:00	suwanee_smiles/DA-F02/DA-F02_PERIO_CHART.pdf
DA-F02-PRED_LETTER	PRED-SIM-DA-F02	suwanee_smiles	PRED_LETTER	administrative	\N	s3	accord-dental-documents	{"decision": "denied", "pred_number": "PD-DAF02", "denial_reason": "Pocket depths of 3mm do not meet the 5mm surgical threshold.", "pred_decision": "DENIED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["CLINICAL_CRITERIA_NOT_MET", "CLINICAL_POCKET_DEPTH"], "cdt_codes_reviewed": ["D4260"], "denial_reason_text": "Pocket depths of 3mm do not meet the 5mm surgical threshold."}	1.000	deterministic	2026-08-06T05:21:11.239859+00:00	suwanee_smiles/DA-F02/DA-F02_PRED_LETTER_DENIED.pdf
NOTE-DA-F03-D03	PRED-SIM-DA-F03	suwanee_smiles	CLINICAL_NOTE	clinical	\N	api	\N	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D2750"], "diagnosis": "Crown resubmitted 4 years 11 months after the last one â€” one month inside the 5-year limit.", "narrative": "One month short. Timing repeatedly just inside the window is the pattern worth flagging.", "visit_date": "2026-08-05", "treatment_plan": "D2750 tooth #3", "cdt_codes_noted": ["D2750"], "chief_complaint": "Integrity â€” Frequency Gaming", "narrative_present": true, "primary_diagnosis": "Crown resubmitted 4 years 11 months after the last one â€” one month inside the 5-year limit."}	0.900	deterministic	2026-08-06T05:21:11.259588+00:00	suwanee_smiles/DA-F03/DA-F03_CLINICAL_NOTE.pdf
XRAY-DA-F03-D02	PRED-SIM-DA-F03	suwanee_smiles	XRAY_PA	clinical	3	api	\N	{"pathology": "Caries extending to pulp chamber, tooth #3", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "tooth_number": 3, "decay_present": true, "image_quality": "DIAGNOSTIC"}	0.700	deterministic	2026-08-06T05:21:11.278289+00:00	suwanee_smiles/DA-F03/DA-F03_PA_XRAY_TOOTH3.pdf
DA-F03-PRED_LETTER	PRED-SIM-DA-F03	suwanee_smiles	PRED_LETTER	administrative	\N	s3	accord-dental-documents	{"decision": "denied", "pred_number": "PD-DAF03", "denial_reason": "Crown frequency limit â€” last paid 09/02/2021, next eligible 09/02/2026.", "pred_decision": "DENIED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["ELIG_FREQUENCY_LIMIT"], "cdt_codes_reviewed": ["D2750"], "denial_reason_text": "Crown frequency limit â€” last paid 09/02/2021, next eligible 09/02/2026."}	1.000	deterministic	2026-08-06T05:21:11.298818+00:00	suwanee_smiles/DA-F03/DA-F03_PRED_LETTER_DENIED.pdf
NOTE-DA-F04-D03	PRED-SIM-DA-F04	suwanee_smiles	CLINICAL_NOTE	clinical	\N	api	\N	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D2750"], "diagnosis": "Core buildup billed the day before the crown to dodge the same-date bundling edit.", "narrative": "Splitting the date does not separate the service â€” the bundling edit follows the tooth.", "visit_date": "2026-08-05", "treatment_plan": "D2750 tooth #14", "cdt_codes_noted": ["D2750"], "chief_complaint": "Integrity â€” Unbundling by Date Split", "narrative_present": true, "primary_diagnosis": "Core buildup billed the day before the crown to dodge the same-date bundling edit."}	0.900	deterministic	2026-08-06T05:21:11.318665+00:00	suwanee_smiles/DA-F04/DA-F04_CLINICAL_NOTE.pdf
XRAY-DA-F04-D02	PRED-SIM-DA-F04	suwanee_smiles	XRAY_PA	clinical	14	api	\N	{"pathology": "Caries extending to pulp chamber, tooth #14", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "tooth_number": 14, "decay_present": true, "image_quality": "DIAGNOSTIC"}	0.700	deterministic	2026-08-06T05:21:11.338920+00:00	suwanee_smiles/DA-F04/DA-F04_PA_XRAY_TOOTH14.pdf
NOTE-DA-F05-D03	PRED-SIM-DA-F05	suwanee_smiles	CLINICAL_NOTE	clinical	\N	api	\N	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D6010"], "diagnosis": "Submitted fee equals the payer allowed amount exactly â€” the patient share appears waived.", "narrative": "Routine waiver of patient responsibility is an inducement â€” hold for senior review.", "visit_date": "2026-08-05", "treatment_plan": "D6010 tooth #19", "cdt_codes_noted": ["D6010"], "chief_complaint": "Integrity â€” Waived Copay Signal", "narrative_present": true, "primary_diagnosis": "Submitted fee equals the payer allowed amount exactly â€” the patient share appears waived."}	0.900	deterministic	2026-08-06T05:21:11.377278+00:00	suwanee_smiles/DA-F05/DA-F05_CLINICAL_NOTE.pdf
XRAY-DA-F05-D02	PRED-SIM-DA-F05	suwanee_smiles	XRAY_PA	clinical	19	api	\N	{"pathology": "Edentulous space #19 with healed ridge", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "bone_loss_mm": 4.2, "tooth_number": 19, "bone_loss_pct": 35.0, "image_quality": "DIAGNOSTIC"}	1.000	deterministic	2026-08-06T05:21:11.395943+00:00	suwanee_smiles/DA-F05/DA-F05_PA_XRAY_TOOTH19.pdf
DA-F05-PRED_LETTER	PRED-SIM-DA-F05	suwanee_smiles	PRED_LETTER	administrative	\N	s3	accord-dental-documents	{"decision": "pended", "pred_number": "PD-DAF05", "denial_reason": "Submitted fee matches allowed amount exactly â€” routed to review.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["COVERAGE_PRED_REQUIRED"], "cdt_codes_reviewed": ["D6010"], "denial_reason_text": "Submitted fee matches allowed amount exactly â€” routed to review."}	1.000	deterministic	2026-08-06T05:21:11.415540+00:00	suwanee_smiles/DA-F05/DA-F05_PRED_LETTER_PENDED.pdf
NOTE-DA-M01-D04	PRED-SIM-DA-M01	suwanee_smiles	CLINICAL_NOTE	clinical	\N	api	\N	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D2750"], "diagnosis": "Insurance card and X12 271 report different member IDs for the same patient.", "narrative": "Identity must reconcile before coverage means anything â€” contradicts edge on member_id.", "visit_date": "2026-08-05", "treatment_plan": "D2750 tooth #19", "cdt_codes_noted": ["D2750"], "chief_complaint": "Messy â€” Member ID Mismatch", "narrative_present": true, "primary_diagnosis": "Insurance card and X12 271 report different member IDs for the same patient."}	0.900	deterministic	2026-08-06T05:21:11.436001+00:00	suwanee_smiles/DA-M01/DA-M01_CLINICAL_NOTE.pdf
INS-DA-M01-CARD-D02	PRED-SIM-DA-M01	suwanee_smiles	INSURANCE_CARD	eligibility	\N	api	\N	{"payer_id": "delta_dental", "member_id": "DDL-999001-A", "plan_type": "PPO", "group_number": "GRP-44821", "coverage_active": true}	0.950	caller_supplied	2026-08-06T05:21:11.457345+00:00	suwanee_smiles/DA-M01/DA-M01_INSURANCE_CARD.pdf
XRAY-DA-M01-D03	PRED-SIM-DA-M01	suwanee_smiles	XRAY_PA	clinical	19	api	\N	{"pathology": "Caries extending to pulp chamber, tooth #19", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "tooth_number": 19, "decay_present": true, "image_quality": "DIAGNOSTIC"}	0.700	deterministic	2026-08-06T05:21:11.477179+00:00	suwanee_smiles/DA-M01/DA-M01_PA_XRAY_TOOTH19.pdf
DA-M01-PRED_LETTER	PRED-SIM-DA-M01	suwanee_smiles	PRED_LETTER	administrative	\N	s3	accord-dental-documents	{"decision": "pended", "pred_number": "PD-DAM01", "denial_reason": "Member ID on the card contradicts the eligibility response.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["ELIG_PLAN_NOT_FOUND"], "cdt_codes_reviewed": ["D2750"], "denial_reason_text": "Member ID on the card contradicts the eligibility response."}	1.000	deterministic	2026-08-06T05:21:11.496162+00:00	suwanee_smiles/DA-M01/DA-M01_PRED_LETTER_PENDED.pdf
NOTE-DA-M02-D03	PRED-SIM-DA-M02	suwanee_smiles	CLINICAL_NOTE	clinical	\N	api	\N	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D4341"], "diagnosis": "D4260 osseous surgery billed, but the note describes D4341 scaling only.", "narrative": "Pocket depths support surgery but the operative note does not â€” reconcile before submitting.", "visit_date": "2026-08-05", "treatment_plan": "D4260 tooth multiple quadrants", "cdt_codes_noted": ["D4260", "D4341"], "chief_complaint": "Messy â€” Procedure Code Contradicts Narrative", "narrative_present": true, "primary_diagnosis": "D4260 osseous surgery billed, but the note describes D4341 scaling only."}	0.900	deterministic	2026-08-06T05:21:11.515173+00:00	suwanee_smiles/DA-M02/DA-M02_CLINICAL_NOTE.pdf
PERIO-DA-M02-D02	PRED-SIM-DA-M02	suwanee_smiles	PERIO_CHART	clinical	\N	api	\N	{"exam_date": "2026-08-05", "charted_on": "2026-08-05", "bleeding_pct": 42.0, "sites_charted": 24, "sites_gte_4mm": 8, "sites_gte_5mm": 8, "sites_gte_6mm": 4, "interpretation": "Probing depths support osseous surgery per AAP criteria.", "perio_diagnosis": "Stage III Periodontitis", "pocket_depth_avg": 3.83, "pocket_depth_max": 6.0, "max_pocket_depth_mm": 6, "bleeding_on_probing_pct": 42.0}	0.900	deterministic	2026-08-06T05:21:11.534850+00:00	suwanee_smiles/DA-M02/DA-M02_PERIO_CHART.pdf
DA-M02-PRED_LETTER	PRED-SIM-DA-M02	suwanee_smiles	PRED_LETTER	administrative	\N	s3	accord-dental-documents	{"decision": "pended", "pred_number": "PD-DAM02", "denial_reason": "Narrative documents scaling, not osseous surgery.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["CLINICAL_CRITERIA_NOT_MET"], "cdt_codes_reviewed": ["D4260"], "denial_reason_text": "Narrative documents scaling, not osseous surgery."}	1.000	deterministic	2026-08-06T05:21:11.555104+00:00	suwanee_smiles/DA-M02/DA-M02_PRED_LETTER_PENDED.pdf
NOTE-DA-M03-D03	PRED-SIM-DA-M03	suwanee_smiles	CLINICAL_NOTE	clinical	\N	api	\N	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D2750"], "diagnosis": "Crown billed MOD; the radiograph documents a DO restoration.", "narrative": "Surface mismatches drive post-payment recoupment â€” catch them before submission.", "visit_date": "2026-08-05", "treatment_plan": "D2750 tooth #14", "cdt_codes_noted": ["D2750"], "chief_complaint": "Messy â€” Tooth Surface Conflict", "narrative_present": true, "primary_diagnosis": "Crown billed MOD; the radiograph documents a DO restoration."}	0.900	deterministic	2026-08-06T05:21:11.574463+00:00	suwanee_smiles/DA-M03/DA-M03_CLINICAL_NOTE.pdf
XRAY-DA-M03-D02	PRED-SIM-DA-M03	suwanee_smiles	XRAY_PA	clinical	14	api	\N	{"pathology": "Caries extending to pulp chamber, tooth #14", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "tooth_number": 14, "decay_present": true, "image_quality": "DIAGNOSTIC", "tooth_surface": "DO"}	0.700	deterministic	2026-08-06T05:21:11.593355+00:00	suwanee_smiles/DA-M03/DA-M03_PA_XRAY_TOOTH14.pdf
PMS-DL-C01-SUPERBILL-D00	PRED-SIM-DL-C01	dallas_dental	CDT_SUPERBILL	administrative	\N	api	\N	{"fees": [1500.0], "arches": ["upper"], "payer_id": "delta_dental", "cdt_codes": ["D2750"], "member_id": "DDL-668204-W", "quadrants": ["UR"], "provider_npi": null, "payer_allowed": [null], "tooth_numbers": [3], "tooth_surfaces": ["MOD"], "provider_out_of_network": false}	0.950	caller_supplied	2026-08-06T13:35:57.764656+00:00	\N
DA-F04-PRED_LETTER	PRED-SIM-DA-F04	suwanee_smiles	PRED_LETTER	administrative	\N	s3	accord-dental-documents	{"decision": "pended", "pred_number": "PD-DAF04", "denial_reason": "Core buildup billed one day earlier is still bundled with the crown.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["COVERAGE_BUNDLING_CONFLICT"], "cdt_codes_reviewed": ["D2750"], "denial_reason_text": "Core buildup billed one day earlier is still bundled with the crown."}	1.000	deterministic	2026-08-06T05:21:11.358451+00:00	suwanee_smiles/DA-F04/DA-F04_PRED_LETTER_PENDED.pdf
DA-M03-PRED_LETTER	PRED-SIM-DA-M03	suwanee_smiles	PRED_LETTER	administrative	\N	s3	accord-dental-documents	{"decision": "pended", "pred_number": "PD-DAM03", "denial_reason": "Billed surface MOD contradicts the documented DO surface.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["COVERAGE_SURFACE_MISMATCH"], "cdt_codes_reviewed": ["D2750"], "denial_reason_text": "Billed surface MOD contradicts the documented DO surface."}	1.000	deterministic	2026-08-06T05:21:11.616618+00:00	suwanee_smiles/DA-M03/DA-M03_PRED_LETTER_PENDED.pdf
NOTE-DA-M04-D03	PRED-SIM-DA-M04	suwanee_smiles	CLINICAL_NOTE	clinical	\N	api	\N	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D6010"], "diagnosis": "An open pre-D already exists for the same member, tooth and CDT code.", "narrative": "Duplicate submissions reset the payer clock â€” detect on member + code + tooth.", "visit_date": "2026-08-05", "treatment_plan": "D6010 tooth #19", "cdt_codes_noted": ["D6010"], "chief_complaint": "Messy â€” Duplicate Pre-Determination", "narrative_present": true, "primary_diagnosis": "An open pre-D already exists for the same member, tooth and CDT code."}	0.900	deterministic	2026-08-06T05:21:11.636608+00:00	suwanee_smiles/DA-M04/DA-M04_CLINICAL_NOTE.pdf
XRAY-DA-M04-D02	PRED-SIM-DA-M04	suwanee_smiles	XRAY_PA	clinical	19	api	\N	{"pathology": "Edentulous space #19 with healed ridge", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "bone_loss_mm": 4.2, "tooth_number": 19, "bone_loss_pct": 35.0, "image_quality": "DIAGNOSTIC"}	1.000	deterministic	2026-08-06T05:21:11.657247+00:00	suwanee_smiles/DA-M04/DA-M04_PA_XRAY_TOOTH19.pdf
DA-M04-PRED_LETTER	PRED-SIM-DA-M04	suwanee_smiles	PRED_LETTER	administrative	\N	s3	accord-dental-documents	{"decision": "pended", "pred_number": "PD-DAM04", "denial_reason": "Duplicate of an open pre-D for the same tooth and code.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["ADMIN_DUPLICATE_PRED"], "cdt_codes_reviewed": ["D6010"], "denial_reason_text": "Duplicate of an open pre-D for the same tooth and code."}	1.000	deterministic	2026-08-06T05:21:11.676033+00:00	suwanee_smiles/DA-M04/DA-M04_PRED_LETTER_PENDED.pdf
NOTE-DA-M05-D03	PRED-SIM-DA-M05	suwanee_smiles	CLINICAL_NOTE	clinical	\N	api	\N	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D2750"], "diagnosis": "Faxed radiograph extracts at 0.45 confidence; the finding cannot be relied on.", "narrative": "A finding extracted at 0.45 confidence is not evidence â€” re-request a diagnostic image.", "visit_date": "2026-08-05", "treatment_plan": "D2750 tooth #3", "cdt_codes_noted": ["D2750"], "chief_complaint": "Messy â€” Low-Confidence Scanned Extraction", "narrative_present": true, "primary_diagnosis": "Faxed radiograph extracts at 0.45 confidence; the finding cannot be relied on."}	0.900	deterministic	2026-08-06T05:21:11.694769+00:00	suwanee_smiles/DA-M05/DA-M05_CLINICAL_NOTE.pdf
XRAY-DA-M05-D02	PRED-SIM-DA-M05	suwanee_smiles	XRAY_PA	clinical	3	api	\N	{"pathology": "Caries extending to pulp chamber, tooth #3", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "tooth_number": 3, "decay_present": true, "image_quality": "SUBOPTIMAL"}	0.750	ai_vision	2026-08-06T05:21:11.714450+00:00	suwanee_smiles/DA-M05/DA-M05_PA_XRAY_TOOTH3.pdf
DA-M05-PRED_LETTER	PRED-SIM-DA-M05	suwanee_smiles	PRED_LETTER	administrative	\N	s3	accord-dental-documents	{"decision": "pended", "pred_number": "PD-DAM05", "denial_reason": "Radiograph extraction below the 0.70 confidence floor.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["CLINICAL_XRAY_REQUIRED"], "cdt_codes_reviewed": ["D2750"], "denial_reason_text": "Radiograph extraction below the 0.70 confidence floor."}	1.000	deterministic	2026-08-06T05:21:11.734633+00:00	suwanee_smiles/DA-M05/DA-M05_PRED_LETTER_PENDED.pdf
INS-DA-U02-CARD-D02	PRED-SIM-DA-U02	suwanee_smiles	INSURANCE_CARD	eligibility	\N	api	\N	{"payer_id": "delta_dental", "member_id": "DDL-334709-S", "plan_type": "PPO", "group_number": "GRP-44821", "coverage_active": true}	0.950	caller_supplied	2026-08-06T05:21:11.833564+00:00	suwanee_smiles/DA-U02/DA-U02_INSURANCE_CARD.pdf
XRAY-TB-A01-D02	PRED-SIM-TB-A01	tampa_smiles	XRAY_PA	clinical	14	api	\N	{"pathology": "Caries extending to pulp chamber, tooth #14", "xray_date": "2026-08-06", "xray_type": "periapical", "date_taken": "2026-08-06", "tooth_number": 14, "decay_present": true, "image_quality": "DIAGNOSTIC"}	0.700	deterministic	2026-08-06T13:42:02.545412+00:00	tampa_smiles/TB-A01/TB-A01_PA_XRAY_TOOTH14.pdf
TB-A01-PRED_LETTER	PRED-SIM-TB-A01	tampa_smiles	PRED_LETTER	administrative	\N	s3	accord-dental-documents	{"decision": "approved", "pred_number": "PD-TBA01", "denial_reason": "", "pred_decision": "APPROVED", "response_date": "2026-08-06", "appeal_deadline": "2027-02-02", "condition_codes": [], "cdt_codes_reviewed": ["D2750"]}	1.000	deterministic	2026-08-06T13:42:02.571627+00:00	tampa_smiles/TB-A01/TB-A01_PRED_LETTER_APPROVED.pdf
TB-B01-PRED_LETTER	PRED-SIM-TB-B01	tampa_smiles	PRED_LETTER	administrative	\N	s3	accord-dental-documents	{"decision": "denied", "pred_number": "PD-TBB01", "denial_reason": "IMPLANTS_NOT_COVERED", "pred_decision": "DENIED", "response_date": "2026-08-06", "appeal_deadline": "2027-02-02", "condition_codes": ["ELIG_IMPLANTS_NOT_COVERED"], "cdt_codes_reviewed": ["D6010"], "denial_reason_text": "IMPLANTS_NOT_COVERED"}	1.000	deterministic	2026-08-06T13:42:02.658362+00:00	tampa_smiles/TB-B01/TB-B01_PRED_LETTER_DENIED.pdf
TB-C01-PRED_LETTER	PRED-SIM-TB-C01	tampa_smiles	PRED_LETTER	administrative	\N	s3	accord-dental-documents	{"decision": "pended", "pred_number": "PD-TBC01", "denial_reason": "PERIO_CHART_MISSING", "pred_decision": "PENDED", "response_date": "2026-08-06", "appeal_deadline": "2027-02-02", "condition_codes": ["DOC_PERIO_CHART_MISSING"], "cdt_codes_reviewed": ["D4341"], "denial_reason_text": "PERIO_CHART_MISSING"}	1.000	deterministic	2026-08-06T13:42:02.722625+00:00	tampa_smiles/TB-C01/TB-C01_PRED_LETTER_PENDED.pdf
HIST-DA-U02-PRIOR-D00	PRED-SIM-DA-U02	suwanee_smiles	PRED_LETTER_PENDED	administrative	\N	payer_portal	\N	{"member_id": "DDL-334709-S", "prior_services": [{"status": "paid", "cdt_code": "D0274", "tooth_number": null, "date_of_service": "2025-06-06"}], "open_pred_requests": []}	0.990	deterministic	2026-08-06T05:18:42.873753+00:00	\N
PMS-DA-U02-SUPERBILL-D00	PRED-SIM-DA-U02	suwanee_smiles	CDT_SUPERBILL	administrative	\N	api	\N	{"fees": [85.0], "arches": [null], "payer_id": "delta_dental", "cdt_codes": ["D0274"], "member_id": "DDL-334709-S", "quadrants": [null], "provider_npi": null, "payer_allowed": [null], "tooth_numbers": [null], "tooth_surfaces": [null], "provider_out_of_network": false}	0.950	caller_supplied	2026-08-06T05:18:42.873753+00:00	\N
X12-DA-U02-271-D01	PRED-SIM-DA-U02	suwanee_smiles	X12_271_RESPONSE	eligibility	\N	x12_271	\N	{"payer_id": "delta_dental", "member_id": "DDL-334709-S", "plan_type": "PPO", "group_number": "GRP-44821", "annual_maximum": 2000.0, "deductible_met": 50.0, "coverage_active": true, "enrollment_date": "2019-01-01", "months_enrolled": 91, "deductible_total": 100.0, "implant_coverage": false, "benefit_pct_basic": 80.0, "benefit_pct_major": 50.0, "secondary_payer_id": null, "waiting_period_met": true, "annual_maximum_used": 200.0, "pred_required_codes": [], "benefit_pct_implants": 0.0, "deductible_remaining": 50.0, "missing_tooth_clause": true, "benefit_pct_preventive": 100.0, "annual_maximum_remaining": 1800.0, "coordination_of_benefits": false, "missing_tooth_clause_confirmed": false}	0.980	deterministic	2026-08-06T05:18:42.873753+00:00	\N
PMS-DA-U03-SUPERBILL-D00	PRED-SIM-DA-U03	suwanee_smiles	CDT_SUPERBILL	administrative	\N	api	\N	{"fees": [175.0], "arches": ["upper"], "payer_id": "cigna", "cdt_codes": ["D2391"], "member_id": "CIG-889302-L", "quadrants": ["UL"], "provider_npi": null, "payer_allowed": [null], "tooth_numbers": [14], "tooth_surfaces": ["O"], "provider_out_of_network": false}	0.950	caller_supplied	2026-08-06T05:18:44.394700+00:00	\N
X12-DA-U03-271-D01	PRED-SIM-DA-U03	suwanee_smiles	X12_271_RESPONSE	eligibility	\N	x12_271	\N	{"payer_id": "cigna", "member_id": "CIG-889302-L", "plan_type": "DPPO", "group_number": "GRP-CIG-01", "annual_maximum": 2000.0, "deductible_met": 50.0, "coverage_active": true, "enrollment_date": "2019-01-01", "months_enrolled": 91, "deductible_total": 100.0, "implant_coverage": false, "benefit_pct_basic": 80.0, "benefit_pct_major": 50.0, "secondary_payer_id": null, "waiting_period_met": true, "annual_maximum_used": 200.0, "pred_required_codes": [], "benefit_pct_implants": 0.0, "deductible_remaining": 50.0, "missing_tooth_clause": true, "benefit_pct_preventive": 100.0, "annual_maximum_remaining": 1800.0, "coordination_of_benefits": false, "missing_tooth_clause_confirmed": false}	0.980	deterministic	2026-08-06T05:18:44.394700+00:00	\N
PMS-DA-U04-SUPERBILL-D00	PRED-SIM-DA-U04	suwanee_smiles	CDT_SUPERBILL	administrative	\N	api	\N	{"fees": [185.0], "arches": ["lower"], "payer_id": "metlife", "cdt_codes": ["D7140"], "member_id": "MET-556128-C", "quadrants": ["LR"], "provider_npi": null, "payer_allowed": [null], "tooth_numbers": [32], "tooth_surfaces": [null], "provider_out_of_network": false}	0.950	caller_supplied	2026-08-06T05:18:45.671185+00:00	\N
X12-DA-U04-271-D01	PRED-SIM-DA-U04	suwanee_smiles	X12_271_RESPONSE	eligibility	\N	x12_271	\N	{"payer_id": "metlife", "member_id": "MET-556128-C", "plan_type": "PDP", "group_number": "GRP-MET-04", "annual_maximum": 2000.0, "deductible_met": 50.0, "coverage_active": true, "enrollment_date": "2018-01-01", "months_enrolled": 103, "deductible_total": 100.0, "implant_coverage": false, "benefit_pct_basic": 80.0, "benefit_pct_major": 50.0, "secondary_payer_id": null, "waiting_period_met": true, "annual_maximum_used": 200.0, "pred_required_codes": [], "benefit_pct_implants": 0.0, "deductible_remaining": 50.0, "missing_tooth_clause": true, "benefit_pct_preventive": 100.0, "annual_maximum_remaining": 1800.0, "coordination_of_benefits": false, "missing_tooth_clause_confirmed": false}	0.980	deterministic	2026-08-06T05:18:45.671185+00:00	\N
X12-DA-U01-271-D01	PRED-SIM-DA-U01	suwanee_smiles	X12_271_RESPONSE	eligibility	\N	x12_271	\N	{"payer_id": "delta_dental", "member_id": "DDL-201455-T", "plan_type": "PPO", "group_number": "GRP-44821", "annual_maximum": 2000.0, "deductible_met": 50.0, "coverage_active": true, "enrollment_date": "2019-01-01", "months_enrolled": 91, "deductible_total": 100.0, "implant_coverage": false, "benefit_pct_basic": 80.0, "benefit_pct_major": 50.0, "secondary_payer_id": null, "waiting_period_met": true, "annual_maximum_used": 200.0, "pred_required_codes": [], "benefit_pct_implants": 0.0, "deductible_remaining": 50.0, "missing_tooth_clause": true, "benefit_pct_preventive": 100.0, "annual_maximum_remaining": 1800.0, "coordination_of_benefits": false, "missing_tooth_clause_confirmed": false}	0.980	deterministic	2026-08-06T05:18:41.317658+00:00	\N
X12-DA-U05-271-D01	PRED-SIM-DA-U05	suwanee_smiles	X12_271_RESPONSE	eligibility	\N	x12_271	\N	{"payer_id": "delta_dental", "member_id": "DDL-447215-W", "plan_type": "PPO", "group_number": "GRP-44821", "annual_maximum": 2000.0, "deductible_met": 50.0, "coverage_active": true, "enrollment_date": "2017-01-01", "months_enrolled": 115, "deductible_total": 100.0, "implant_coverage": false, "benefit_pct_basic": 80.0, "benefit_pct_major": 50.0, "secondary_payer_id": null, "waiting_period_met": true, "annual_maximum_used": 200.0, "pred_required_codes": [], "benefit_pct_implants": 0.0, "deductible_remaining": 50.0, "missing_tooth_clause": true, "benefit_pct_preventive": 100.0, "annual_maximum_remaining": 1800.0, "coordination_of_benefits": false, "missing_tooth_clause_confirmed": false}	0.980	deterministic	2026-08-06T05:18:46.944019+00:00	\N
NOTE-DA-U01-D03	PRED-SIM-DA-U01	suwanee_smiles	CLINICAL_NOTE	clinical	\N	api	\N	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D1110"], "diagnosis": "D1110 adult cleaning, Delta Dental PPO. The simplest case the platform can see.", "narrative": "100% preventive, 2 per year, last cleaning outside the window. Nothing to hold â€” and the platform has to be able to say so without a human reading it.", "visit_date": "2026-08-06", "treatment_plan": "D1110 tooth multiple quadrants", "cdt_codes_noted": ["D1110"], "chief_complaint": "Uncontested â€” Adult Prophylaxis", "narrative_present": true, "primary_diagnosis": "D1110 adult cleaning, Delta Dental PPO. The simplest case the platform can see."}	0.900	deterministic	2026-08-06T05:21:11.754278+00:00	suwanee_smiles/DA-U01/DA-U01_CLINICAL_NOTE.pdf
INS-DA-U01-CARD-D02	PRED-SIM-DA-U01	suwanee_smiles	INSURANCE_CARD	eligibility	\N	api	\N	{"payer_id": "delta_dental", "member_id": "DDL-201455-T", "plan_type": "PPO", "group_number": "GRP-44821", "coverage_active": true}	0.950	caller_supplied	2026-08-06T05:21:11.774827+00:00	suwanee_smiles/DA-U01/DA-U01_INSURANCE_CARD.pdf
DA-U01-PRED_LETTER	PRED-SIM-DA-U01	suwanee_smiles	PRED_LETTER	administrative	\N	s3	accord-dental-documents	{"decision": "approved", "pred_number": "PD-DAU01", "denial_reason": "", "pred_decision": "APPROVED", "response_date": "2026-08-06", "appeal_deadline": "2027-02-02", "condition_codes": [], "cdt_codes_reviewed": ["D1110"]}	1.000	deterministic	2026-08-06T05:21:11.794453+00:00	suwanee_smiles/DA-U01/DA-U01_PRED_LETTER_APPROVED.pdf
NOTE-DA-U02-D03	PRED-SIM-DA-U02	suwanee_smiles	CLINICAL_NOTE	clinical	\N	api	\N	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D0274"], "diagnosis": "D0274 diagnostic films, Delta Dental PPO. Last set taken over a year ago.", "narrative": "Diagnostic imaging at 100%, 1 per year. The frequency check runs and clears â€” the same check that denies DA-F03", "visit_date": "2026-08-06", "treatment_plan": "D0274 tooth multiple quadrants", "cdt_codes_noted": ["D0274"], "chief_complaint": "Uncontested â€” Four Bitewing Radiographs", "narrative_present": true, "primary_diagnosis": "D0274 diagnostic films, Delta Dental PPO. Last set taken over a year ago."}	0.900	deterministic	2026-08-06T05:21:11.813648+00:00	suwanee_smiles/DA-U02/DA-U02_CLINICAL_NOTE.pdf
DA-U02-PRED_LETTER	PRED-SIM-DA-U02	suwanee_smiles	PRED_LETTER	administrative	\N	s3	accord-dental-documents	{"decision": "approved", "pred_number": "PD-DAU02", "denial_reason": "", "pred_decision": "APPROVED", "response_date": "2026-08-06", "appeal_deadline": "2027-02-02", "condition_codes": [], "cdt_codes_reviewed": ["D0274"]}	1.000	deterministic	2026-08-06T05:21:11.853657+00:00	suwanee_smiles/DA-U02/DA-U02_PRED_LETTER_APPROVED.pdf
NOTE-DA-U03-D03	PRED-SIM-DA-U03	suwanee_smiles	CLINICAL_NOTE	clinical	\N	api	\N	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D2391"], "diagnosis": "D2391 one-surface composite on tooth #14 under Cigna DPPO. Basic service, no pre-D.", "narrative": "A direct restoration is a basic service â€” 80%, no pre-determination, no clinical criteria. The complexity in this catalogue is the exception, not the rule.", "visit_date": "2026-08-06", "treatment_plan": "D2391 tooth #14", "cdt_codes_noted": ["D2391"], "chief_complaint": "Uncontested â€” Posterior Composite Filling", "narrative_present": true, "primary_diagnosis": "D2391 one-surface composite on tooth #14 under Cigna DPPO. Basic service, no pre-D."}	0.900	deterministic	2026-08-06T05:21:11.873229+00:00	suwanee_smiles/DA-U03/DA-U03_CLINICAL_NOTE.pdf
INS-DA-U03-CARD-D02	PRED-SIM-DA-U03	suwanee_smiles	INSURANCE_CARD	eligibility	\N	api	\N	{"payer_id": "cigna", "member_id": "CIG-889302-L", "plan_type": "DPPO", "group_number": "GRP-CIG-01", "coverage_active": true}	0.950	caller_supplied	2026-08-06T05:21:11.893038+00:00	suwanee_smiles/DA-U03/DA-U03_INSURANCE_CARD.pdf
DA-U03-PRED_LETTER	PRED-SIM-DA-U03	suwanee_smiles	PRED_LETTER	administrative	\N	s3	accord-dental-documents	{"decision": "approved", "pred_number": "PD-DAU03", "denial_reason": "", "pred_decision": "APPROVED", "response_date": "2026-08-06", "appeal_deadline": "2027-02-02", "condition_codes": [], "cdt_codes_reviewed": ["D2391"]}	1.000	deterministic	2026-08-06T05:21:11.912197+00:00	suwanee_smiles/DA-U03/DA-U03_PRED_LETTER_APPROVED.pdf
NOTE-DA-U04-D03	PRED-SIM-DA-U04	suwanee_smiles	CLINICAL_NOTE	clinical	\N	api	\N	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D7140"], "diagnosis": "D7140 erupted tooth #32 under MetLife PDP. No surgical flap, no bone removal.", "narrative": "A simple extraction is a basic service, so no major-services waiting period applies â€” the distinction that denies DA-B05 the same month it is enrolled.", "visit_date": "2026-08-06", "treatment_plan": "D7140 tooth #32", "cdt_codes_noted": ["D7140"], "chief_complaint": "Uncontested â€” Simple Extraction", "narrative_present": true, "primary_diagnosis": "D7140 erupted tooth #32 under MetLife PDP. No surgical flap, no bone removal."}	0.900	deterministic	2026-08-06T05:21:11.932146+00:00	suwanee_smiles/DA-U04/DA-U04_CLINICAL_NOTE.pdf
INS-DA-U04-CARD-D02	PRED-SIM-DA-U04	suwanee_smiles	INSURANCE_CARD	eligibility	\N	api	\N	{"payer_id": "metlife", "member_id": "MET-556128-C", "plan_type": "PDP", "group_number": "GRP-MET-04", "coverage_active": true}	0.950	caller_supplied	2026-08-06T05:21:11.951691+00:00	suwanee_smiles/DA-U04/DA-U04_INSURANCE_CARD.pdf
NOTE-DA-U05-D03	PRED-SIM-DA-U05	suwanee_smiles	CLINICAL_NOTE	clinical	\N	api	\N	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D4910"], "diagnosis": "D4910 for an established perio patient, Delta Dental PPO. First maintenance this year.", "narrative": "Maintenance after active periodontal therapy, 4 per year on this plan and none used in the window. Stable pockets are", "visit_date": "2026-08-06", "treatment_plan": "D4910 tooth multiple quadrants", "cdt_codes_noted": ["D4910"], "chief_complaint": "Uncontested â€” Periodontal Maintenance", "narrative_present": true, "primary_diagnosis": "D4910 for an established perio patient, Delta Dental PPO. First maintenance this year."}	0.900	deterministic	2026-08-06T05:21:11.988668+00:00	suwanee_smiles/DA-U05/DA-U05_CLINICAL_NOTE.pdf
INS-DA-U05-CARD-D02	PRED-SIM-DA-U05	suwanee_smiles	INSURANCE_CARD	eligibility	\N	api	\N	{"payer_id": "delta_dental", "member_id": "DDL-447215-W", "plan_type": "PPO", "group_number": "GRP-44821", "coverage_active": true}	0.950	caller_supplied	2026-08-06T05:21:12.009435+00:00	suwanee_smiles/DA-U05/DA-U05_INSURANCE_CARD.pdf
PERIO-DA-U05-D04	PRED-SIM-DA-U05	suwanee_smiles	PERIO_CHART	clinical	\N	api	\N	{"exam_date": "2026-08-06", "charted_on": "2026-08-06", "bleeding_pct": 42.0, "sites_charted": 24, "sites_gte_4mm": 1, "sites_gte_5mm": 0, "sites_gte_6mm": 0, "interpretation": "Probing depths do not meet the AAP threshold for osseous surgery. Non-surgical therapy is indicated before any", "perio_diagnosis": "Stage I Periodontitis", "pocket_depth_avg": 2.08, "pocket_depth_max": 4.0, "max_pocket_depth_mm": 4, "bleeding_on_probing_pct": 42.0}	0.900	deterministic	2026-08-06T05:21:12.029550+00:00	suwanee_smiles/DA-U05/DA-U05_PERIO_CHART.pdf
DA-U05-PRED_LETTER	PRED-SIM-DA-U05	suwanee_smiles	PRED_LETTER	administrative	\N	s3	accord-dental-documents	{"decision": "approved", "pred_number": "PD-DAU05", "denial_reason": "", "pred_decision": "APPROVED", "response_date": "2026-08-06", "appeal_deadline": "2027-02-02", "condition_codes": [], "cdt_codes_reviewed": ["D4910"]}	1.000	deterministic	2026-08-06T05:21:12.048148+00:00	suwanee_smiles/DA-U05/DA-U05_PRED_LETTER_APPROVED.pdf
X12-TB-A01-271-D01	PRED-SIM-TB-A01	tampa_smiles	X12_271_RESPONSE	eligibility	\N	x12_271	\N	{"payer_id": "humana_dpo", "member_id": "HUM-771204-C", "plan_type": "DPPO", "group_number": "GRP-HUM-11", "annual_maximum": 1500.0, "deductible_met": 50.0, "coverage_active": true, "enrollment_date": "2021-01-01", "months_enrolled": 67, "deductible_total": 50.0, "implant_coverage": true, "benefit_pct_basic": 80.0, "benefit_pct_major": 50.0, "secondary_payer_id": null, "waiting_period_met": true, "annual_maximum_used": 0.0, "pred_required_codes": ["D2750"], "benefit_pct_implants": 50.0, "deductible_remaining": 0.0, "missing_tooth_clause": false, "benefit_pct_preventive": 100.0, "annual_maximum_remaining": 1500.0, "coordination_of_benefits": false, "missing_tooth_clause_confirmed": false}	0.980	deterministic	2026-08-06T13:35:17.794770+00:00	\N
PMS-TB-B01-SUPERBILL-D00	PRED-SIM-TB-B01	tampa_smiles	CDT_SUPERBILL	administrative	\N	api	\N	{"fees": [2800.0], "arches": ["lower"], "payer_id": "aetna_dmo", "cdt_codes": ["D6010"], "member_id": "AET-330918-M", "quadrants": ["LL"], "provider_npi": null, "payer_allowed": [null], "tooth_numbers": [19], "tooth_surfaces": [null], "provider_out_of_network": false}	0.950	caller_supplied	2026-08-06T13:35:19.528044+00:00	\N
X12-TB-B01-271-D01	PRED-SIM-TB-B01	tampa_smiles	X12_271_RESPONSE	eligibility	\N	x12_271	\N	{"payer_id": "aetna_dmo", "member_id": "AET-330918-M", "plan_type": "DMO", "group_number": "GRP-AET-02", "annual_maximum": 1500.0, "deductible_met": 0.0, "coverage_active": true, "enrollment_date": "2020-01-01", "months_enrolled": 79, "deductible_total": 0.0, "implant_coverage": false, "benefit_pct_basic": 80.0, "benefit_pct_major": 50.0, "secondary_payer_id": null, "waiting_period_met": true, "annual_maximum_used": 0.0, "pred_required_codes": ["D6010"], "benefit_pct_implants": 0.0, "deductible_remaining": 0.0, "missing_tooth_clause": true, "benefit_pct_preventive": 100.0, "annual_maximum_remaining": 1500.0, "coordination_of_benefits": false, "missing_tooth_clause_confirmed": false}	0.980	deterministic	2026-08-06T13:35:19.528044+00:00	\N
NOTE-TB-A01-D03	PRED-SIM-TB-A01	tampa_smiles	CLINICAL_NOTE	clinical	\N	api	\N	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D2750"], "diagnosis": "D2750 PFM crown tooth #14. Humana pays a PFM crown outright; the FL schedule prices it 5% above GA.", "narrative": "Same crown, same tooth, different state. The clinical answer does not move; the money does â€” FL allowed amounts", "visit_date": "2026-08-06", "treatment_plan": "D2750 tooth #14", "cdt_codes_noted": ["D2750"], "chief_complaint": "Crown Approved â€” Humana DPPO Florida", "narrative_present": true, "primary_diagnosis": "D2750 PFM crown tooth #14. Humana pays a PFM crown outright; the FL schedule prices it 5% above GA."}	0.900	deterministic	2026-08-06T13:42:02.479949+00:00	tampa_smiles/TB-A01/TB-A01_CLINICAL_NOTE.pdf
NOTE-TB-B01-D03	PRED-SIM-TB-B01	tampa_smiles	CLINICAL_NOTE	clinical	\N	api	\N	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D6010"], "diagnosis": "D6010 tooth #19, identical to DA-A01's first line. Delta covers it at 50%; Aetna DMO does not cover it at all.", "narrative": "THE payer-difference scenario. DA-A01 approves this exact code under Delta. A DMO buys a fixed copay schedule with no implant benefit, so the answer is no before a single clinical fact is read â€” and a plan exclusion is not", "visit_date": "2026-08-06", "treatment_plan": "D6010 tooth #19", "cdt_codes_noted": ["D6010"], "chief_complaint": "Implant Denied â€” Aetna DMO Excludes Implants", "narrative_present": true, "primary_diagnosis": "D6010 tooth #19, identical to DA-A01's first line. Delta covers it at 50%; Aetna DMO does not cover it at all."}	0.900	deterministic	2026-08-06T13:42:02.600519+00:00	tampa_smiles/TB-B01/TB-B01_CLINICAL_NOTE.pdf
INS-TB-B01-CARD-D04	PRED-SIM-TB-B01	tampa_smiles	INSURANCE_CARD	eligibility	\N	api	\N	{"payer_id": "aetna_dmo", "member_id": "AET-330918-M", "plan_type": "DMO", "group_number": "GRP-AET-02", "coverage_active": true}	0.950	caller_supplied	2026-08-06T13:42:02.620164+00:00	tampa_smiles/TB-B01/TB-B01_INSURANCE_CARD.pdf
XRAY-TB-B01-D02	PRED-SIM-TB-B01	tampa_smiles	XRAY_PA	clinical	19	api	\N	{"pathology": "Edentulous space #19 with healed ridge", "xray_date": "2026-08-06", "xray_type": "periapical", "date_taken": "2026-08-06", "bone_loss_mm": 4.2, "tooth_number": 19, "bone_loss_pct": 35.0, "image_quality": "DIAGNOSTIC"}	1.000	deterministic	2026-08-06T13:42:02.639911+00:00	tampa_smiles/TB-B01/TB-B01_PA_XRAY_TOOTH19.pdf
NOTE-TB-C01-D02	PRED-SIM-TB-C01	tampa_smiles	CLINICAL_NOTE	clinical	\N	api	\N	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D4341", "D4341"], "diagnosis": "D4341 x2 quadrants. Guardian's structure matches MetLife; the pend is documentation, not coverage.", "narrative": "Guardian and MetLife price this identically. The pend has nothing to do with the payer â€” a scaling claim with no charted pocket depths is unadjudicable for all six.", "visit_date": "2026-08-06", "treatment_plan": "D4341+D4341 tooth multiple quadrants", "cdt_codes_noted": ["D4341"], "chief_complaint": "SRP Pended â€” Guardian DPPO, Perio Chart Missing", "narrative_present": true, "primary_diagnosis": "D4341 x2 quadrants. Guardian's structure matches MetLife; the pend is documentation, not coverage."}	0.900	deterministic	2026-08-06T13:42:02.683412+00:00	tampa_smiles/TB-C01/TB-C01_CLINICAL_NOTE.pdf
X12-DL-A01-271-D01	PRED-SIM-DL-A01	dallas_dental	X12_271_RESPONSE	eligibility	\N	x12_271	\N	{"payer_id": "guardian_dpo", "member_id": "GRD-140725-J", "plan_type": "DPPO", "group_number": "GRP-GRD-07", "annual_maximum": 2000.0, "deductible_met": 50.0, "coverage_active": true, "enrollment_date": "2019-01-01", "months_enrolled": 91, "deductible_total": 100.0, "implant_coverage": true, "benefit_pct_basic": 80.0, "benefit_pct_major": 50.0, "secondary_payer_id": null, "waiting_period_met": true, "annual_maximum_used": 200.0, "pred_required_codes": ["D6010", "D6065"], "benefit_pct_implants": 50.0, "deductible_remaining": 50.0, "missing_tooth_clause": true, "benefit_pct_preventive": 100.0, "annual_maximum_remaining": 1800.0, "coordination_of_benefits": false, "missing_tooth_clause_confirmed": false}	0.980	deterministic	2026-08-06T13:35:54.537826+00:00	\N
NOTE-DL-B01-D03	PRED-SIM-DL-B01	dallas_dental	CLINICAL_NOTE	clinical	\N	api	\N	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D4260"], "diagnosis": "D4260 osseous surgery upper right. ADA criteria require 5mm+ pockets with bone loss; this chart shows 4mm.", "narrative": "A denial the ADA floor produces, not the payer. RULE 2 â€” ada_guidelines is a floor no payer rule or practice overlay may drop below, so this case denies under all six payers and in all seven states.", "visit_date": "2026-08-06", "treatment_plan": "D4260 tooth multiple quadrants", "cdt_codes_noted": ["D4260"], "chief_complaint": "Perio Surgery Denied â€” Pocket Depth Insufficient", "narrative_present": true, "primary_diagnosis": "D4260 osseous surgery upper right. ADA criteria require 5mm+ pockets with bone loss; this chart shows 4mm."}	0.900	deterministic	2026-08-06T13:43:06.915795+00:00	dallas_dental/DL-B01/DL-B01_CLINICAL_NOTE.pdf
INS-DL-B01-CARD-D04	PRED-SIM-DL-B01	dallas_dental	INSURANCE_CARD	eligibility	\N	api	\N	{"payer_id": "guardian_dpo", "member_id": "GRD-573091-L", "plan_type": "DPPO", "group_number": "GRP-GRD-07", "coverage_active": true}	0.950	caller_supplied	2026-08-06T13:43:06.934589+00:00	dallas_dental/DL-B01/DL-B01_INSURANCE_CARD.pdf
PERIO-DL-B01-D02	PRED-SIM-DL-B01	dallas_dental	PERIO_CHART	clinical	\N	api	\N	{"exam_date": "2026-08-06", "charted_on": "2026-08-06", "bleeding_pct": 42.0, "bone_loss_pct": 10, "sites_charted": 24, "sites_gte_4mm": 1, "sites_gte_5mm": 0, "sites_gte_6mm": 0, "interpretation": "Probing depths do not meet the AAP threshold for osseous surgery. Non-surgical therapy is indicated before any", "perio_diagnosis": "Stage I Periodontitis", "pocket_depth_avg": 2.08, "pocket_depth_max": 4.0, "max_pocket_depth_mm": 4, "bleeding_on_probing_pct": 42.0}	0.900	deterministic	2026-08-06T13:43:06.954372+00:00	dallas_dental/DL-B01/DL-B01_PERIO_CHART.pdf
PMS-DL-B01-SUPERBILL-D00	PRED-SIM-DL-B01	dallas_dental	CDT_SUPERBILL	administrative	\N	api	\N	{"fees": [1200.0], "arches": ["upper"], "payer_id": "guardian_dpo", "cdt_codes": ["D4260"], "member_id": "GRD-573091-L", "quadrants": ["UR"], "provider_npi": null, "payer_allowed": [null], "tooth_numbers": [null], "tooth_surfaces": [null], "provider_out_of_network": false}	0.950	caller_supplied	2026-08-06T13:35:56.124237+00:00	\N
X12-DL-B01-271-D01	PRED-SIM-DL-B01	dallas_dental	X12_271_RESPONSE	eligibility	\N	x12_271	\N	{"payer_id": "guardian_dpo", "member_id": "GRD-573091-L", "plan_type": "DPPO", "group_number": "GRP-GRD-07", "annual_maximum": 2000.0, "deductible_met": 50.0, "coverage_active": true, "enrollment_date": "2017-01-01", "months_enrolled": 115, "deductible_total": 100.0, "implant_coverage": true, "benefit_pct_basic": 80.0, "benefit_pct_major": 50.0, "secondary_payer_id": null, "waiting_period_met": true, "annual_maximum_used": 200.0, "pred_required_codes": ["D4260"], "benefit_pct_implants": 50.0, "deductible_remaining": 50.0, "missing_tooth_clause": true, "benefit_pct_preventive": 100.0, "annual_maximum_remaining": 1800.0, "coordination_of_benefits": false, "missing_tooth_clause_confirmed": false}	0.980	deterministic	2026-08-06T13:35:56.124237+00:00	\N
HIST-DL-C01-PRIOR-D00	PRED-SIM-DL-C01	dallas_dental	PRED_LETTER_PENDED	administrative	\N	payer_portal	\N	{"member_id": "DDL-668204-W", "prior_services": [{"status": "paid", "cdt_code": "D2750", "tooth_number": 3, "date_of_service": "2023-08-06"}], "open_pred_requests": []}	0.990	deterministic	2026-08-06T13:35:57.764656+00:00	\N
X12-DL-C01-271-D01	PRED-SIM-DL-C01	dallas_dental	X12_271_RESPONSE	eligibility	\N	x12_271	\N	{"payer_id": "delta_dental", "member_id": "DDL-668204-W", "plan_type": "PPO", "group_number": "GRP-44821", "annual_maximum": 2000.0, "deductible_met": 50.0, "coverage_active": true, "enrollment_date": "2016-01-01", "months_enrolled": 127, "deductible_total": 100.0, "implant_coverage": false, "benefit_pct_basic": 80.0, "benefit_pct_major": 50.0, "secondary_payer_id": null, "waiting_period_met": true, "annual_maximum_used": 200.0, "pred_required_codes": ["D2750"], "benefit_pct_implants": 0.0, "deductible_remaining": 50.0, "missing_tooth_clause": true, "benefit_pct_preventive": 100.0, "annual_maximum_remaining": 1800.0, "coordination_of_benefits": false, "missing_tooth_clause_confirmed": false}	0.980	deterministic	2026-08-06T13:35:57.764656+00:00	\N
INS-DL-D01-CARD-D04	PRED-SIM-DL-D01	dallas_dental	INSURANCE_CARD	eligibility	\N	api	\N	{"payer_id": "humana_dpo", "member_id": "HUM-482260-G", "plan_type": "DPPO", "group_number": "GRP-HUM-11", "coverage_active": true}	0.950	caller_supplied	2026-08-06T13:43:07.086554+00:00	dallas_dental/DL-D01/DL-D01_INSURANCE_CARD.pdf
INS-DL-U01-CARD-D03	PRED-SIM-DL-U01	dallas_dental	INSURANCE_CARD	eligibility	\N	api	\N	{"payer_id": "guardian_dpo", "member_id": "GRD-836142-B", "plan_type": "DPPO", "group_number": "GRP-GRD-07", "coverage_active": true}	0.950	caller_supplied	2026-08-06T13:43:07.144403+00:00	dallas_dental/DL-U01/DL-U01_INSURANCE_CARD.pdf
DOC-DL-D01-D02	PRED-SIM-DL-D01	dallas_dental	PANORAMIC_XRAY	clinical	\N	api	\N	{"image_quality": "xray"}	0.920	caller_supplied	2026-08-06T13:35:59.663639+00:00	\N
PMS-DL-D01-SUPERBILL-D00	PRED-SIM-DL-D01	dallas_dental	CDT_SUPERBILL	administrative	\N	api	\N	{"fees": [4500.0], "arches": [null], "payer_id": "humana_dpo", "cdt_codes": ["D8090"], "member_id": "HUM-482260-G", "quadrants": [null], "provider_npi": null, "payer_allowed": [null], "tooth_numbers": [null], "tooth_surfaces": [null], "provider_out_of_network": false}	0.950	caller_supplied	2026-08-06T13:35:59.663639+00:00	\N
X12-DL-D01-271-D01	PRED-SIM-DL-D01	dallas_dental	X12_271_RESPONSE	eligibility	\N	x12_271	\N	{"payer_id": "humana_dpo", "member_id": "HUM-482260-G", "plan_type": "DPPO", "group_number": "GRP-HUM-11", "annual_maximum": 1500.0, "deductible_met": 50.0, "coverage_active": true, "enrollment_date": "2020-01-01", "months_enrolled": 79, "deductible_total": 50.0, "implant_coverage": true, "benefit_pct_basic": 80.0, "benefit_pct_major": 50.0, "secondary_payer_id": null, "waiting_period_met": true, "annual_maximum_used": 0.0, "pred_required_codes": ["D8090"], "benefit_pct_implants": 50.0, "deductible_remaining": 0.0, "missing_tooth_clause": false, "benefit_pct_preventive": 100.0, "annual_maximum_remaining": 1500.0, "coordination_of_benefits": false, "missing_tooth_clause_confirmed": false}	0.980	deterministic	2026-08-06T13:35:59.663639+00:00	\N
DOC-DL-U01-D02	PRED-SIM-DL-U01	dallas_dental	PANORAMIC_XRAY	clinical	\N	api	\N	{"image_quality": "xray"}	0.920	caller_supplied	2026-08-06T13:36:01.310800+00:00	\N
PMS-DL-U01-SUPERBILL-D00	PRED-SIM-DL-U01	dallas_dental	CDT_SUPERBILL	administrative	\N	api	\N	{"fees": [185.0], "arches": [null], "payer_id": "guardian_dpo", "cdt_codes": ["D0330"], "member_id": "GRD-836142-B", "quadrants": [null], "provider_npi": null, "payer_allowed": [null], "tooth_numbers": [null], "tooth_surfaces": [null], "provider_out_of_network": false}	0.950	caller_supplied	2026-08-06T13:36:01.310800+00:00	\N
X12-DL-U01-271-D01	PRED-SIM-DL-U01	dallas_dental	X12_271_RESPONSE	eligibility	\N	x12_271	\N	{"payer_id": "guardian_dpo", "member_id": "GRD-836142-B", "plan_type": "DPPO", "group_number": "GRP-GRD-07", "annual_maximum": 2000.0, "deductible_met": 50.0, "coverage_active": true, "enrollment_date": "2021-01-01", "months_enrolled": 67, "deductible_total": 100.0, "implant_coverage": true, "benefit_pct_basic": 80.0, "benefit_pct_major": 50.0, "secondary_payer_id": null, "waiting_period_met": true, "annual_maximum_used": 200.0, "pred_required_codes": [], "benefit_pct_implants": 50.0, "deductible_remaining": 50.0, "missing_tooth_clause": true, "benefit_pct_preventive": 100.0, "annual_maximum_remaining": 1800.0, "coordination_of_benefits": false, "missing_tooth_clause_confirmed": false}	0.980	deterministic	2026-08-06T13:36:01.310800+00:00	\N
NOTE-TB-D01-D03	PRED-SIM-TB-D01	tampa_smiles	CLINICAL_NOTE	clinical	\N	api	\N	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D2740"], "diagnosis": "D2740 all-ceramic on anterior tooth #8. Delta and MetLife reimburse at the D2750 PFM rate; Aetna DMO does not.", "narrative": "The mirror of DA-C06. A DMO pays a fixed copay per code, so there is no percentage to downgrade â€” the patient is not billed the ceramic-to-metal difference that a Delta patient would owe on the same tooth.", "visit_date": "2026-08-06", "treatment_plan": "D2740 tooth #8", "cdt_codes_noted": ["D2740", "D2750"], "chief_complaint": "Ceramic Crown â€” Aetna DMO Does NOT Downgrade", "narrative_present": true, "primary_diagnosis": "D2740 all-ceramic on anterior tooth #8. Delta and MetLife reimburse at the D2750 PFM rate; Aetna DMO does not."}	0.900	deterministic	2026-08-06T13:42:02.744182+00:00	tampa_smiles/TB-D01/TB-D01_CLINICAL_NOTE.pdf
TB-D01-PRED_LETTER	PRED-SIM-TB-D01	tampa_smiles	PRED_LETTER	administrative	\N	s3	accord-dental-documents	{"decision": "approved", "pred_number": "PD-TBD01", "denial_reason": "", "pred_decision": "APPROVED", "response_date": "2026-08-06", "appeal_deadline": "2027-02-02", "condition_codes": [], "cdt_codes_reviewed": ["D2740"]}	1.000	deterministic	2026-08-06T13:42:02.827681+00:00	tampa_smiles/TB-D01/TB-D01_PRED_LETTER_APPROVED.pdf
NOTE-TB-U01-D03	PRED-SIM-TB-U01	tampa_smiles	CLINICAL_NOTE	clinical	\N	api	\N	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D1110"], "diagnosis": "D1110 adult prophylaxis. Preventive at 100%, first of two this year.", "narrative": "Preventive is 100% on all six payers. The baseline that proves a new tenant and a new payer did not break the ordinary", "visit_date": "2026-08-06", "treatment_plan": "D1110 tooth multiple quadrants", "cdt_codes_noted": ["D1110"], "chief_complaint": "Uncontested â€” Cleaning, Humana Florida", "narrative_present": true, "primary_diagnosis": "D1110 adult prophylaxis. Preventive at 100%, first of two this year."}	0.900	deterministic	2026-08-06T13:42:02.847913+00:00	tampa_smiles/TB-U01/TB-U01_CLINICAL_NOTE.pdf
TB-U01-PRED_LETTER	PRED-SIM-TB-U01	tampa_smiles	PRED_LETTER	administrative	\N	s3	accord-dental-documents	{"decision": "approved", "pred_number": "PD-TBU01", "denial_reason": "", "pred_decision": "APPROVED", "response_date": "2026-08-06", "appeal_deadline": "2027-02-02", "condition_codes": [], "cdt_codes_reviewed": ["D1110"]}	1.000	deterministic	2026-08-06T13:42:02.893336+00:00	tampa_smiles/TB-U01/TB-U01_PRED_LETTER_APPROVED.pdf
\.


--
-- Data for Name: cob_rules; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.cob_rules (rule_id, rule_code, rule_name, rule_type, description, primary_determination, secondary_determination, documentation_required, notes, created_at) FROM stdin;
71fc35f1-897e-4df7-8130-6db7cbba2a8e	BIRTHDAY_RULE	Birthday Rule	birthday_rule	The parent whose birthday falls earlier in the calendar year (month and day only) has the primary dental plan for dependent children. Year of birth is not considered.	Parent with earlier month/day birthday. If birthdays fall on same month and day, the plan that has been in effect longer is primary.	The other parent's plan pays secondary up to its allowed amount less the primary payment.	Both insurance cards, date of birth verification for both parents.	\N	2026-08-04 18:07:59.558477+00
ba9b3656-daee-44d2-9fc5-902e8188a47f	COURT_ORDER	Court Order Overrides Birthday Rule	court_order	A court order specifying which parent is responsible for the child's dental coverage overrides the birthday rule.	As specified in the court order.	The non-designated parent's plan is secondary.	Copy of court order or divorce decree specifying dental insurance responsibility.	\N	2026-08-04 18:07:59.579727+00
4b9f39e8-92bd-43ac-b183-857124a72a23	MEDICARE_PRIMARY	Medicare Primary	medicare_primary	Medicare is primary over commercial dental plans for Medicare-eligible individuals except when the individual is an active employee covered by an employer group plan.	Medicare is primary. Commercial dental is secondary and pays up to covered amount minus Medicare paid.	Commercial dental plan pays the balance up to its allowed amount.	Medicare card, Medicare EOB.	\N	2026-08-04 18:07:59.601696+00
fbab17cd-10da-4137-b5e5-51bd2e1abf5a	ACTIVE_EMPLOYMENT	Active Employment Takes Precedence	active_employment	An active employee's employer-sponsored plan is primary over Medicare or retiree plans.	Active employer plan is primary.	Medicare or the retiree plan pays secondary.	Employer verification of active employment status.	\N	2026-08-04 18:07:59.622226+00
03423625-913c-403e-b7c9-98eb1aae0f78	GENDER_RULE_LEGACY	Legacy Gender Rule	gender_rule_legacy	Some older plans still use the gender rule where the father's plan is primary. This rule is being phased out and most states have adopted the birthday rule instead. Verify which rule the specific payer applies.	Father's plan primary (if payer applies gender rule). Verify with payer before billing.	Mother's plan pays secondary.	Verification from payer that gender rule applies to this specific plan.	\N	2026-08-04 18:07:59.643489+00
\.


--
-- Data for Name: conditions_library; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.conditions_library (condition_code, category, template_text, payer_citation, sla_hours, assignee, recommended_action) FROM stdin;
ELIG_COVERAGE_INACTIVE	eligibility	Insurance not active on treatment date	Delta Dental PPO	24	provider	\N
ELIG_PLAN_NOT_FOUND	eligibility	Unable to verify plan from member ID ${member_id}	Delta Dental PPO	24	provider	\N
ELIG_IMPLANT_NOT_COVERED	eligibility	Implants excluded from this plan â€” patient responsible for ${case_value}	Delta Dental PPO	24	provider	\N
ELIG_WAITING_PERIOD_NOT_MET	eligibility	Major services waiting period of ${months} months not satisfied. Eligible: ${eligible_date}	Delta Dental PPO	48	provider	\N
ELIG_MISSING_TOOTH_CLAUSE	eligibility	Tooth #${tooth} missing before enrollment ${date} â€” excluded from implant coverage	Delta Dental PPO	48	provider	\N
ELIG_ANNUAL_MAX_EXHAUSTED	eligibility	Annual maximum of ${annual_max} reached â€” patient responsible for 100%	Delta Dental PPO	24	provider	\N
ELIG_ANNUAL_MAX_INSUFFICIENT	eligibility	Remaining max ${remaining} insufficient for case value ${case_value}	Delta Dental PPO	48	provider	\N
ELIG_DEDUCTIBLE_NOT_MET	eligibility	Deductible ${remaining} not yet met â€” higher patient portion	Delta Dental PPO	24	provider	\N
ELIG_COB_REQUIRED	eligibility	Secondary insurance detected â€” primary EOB required before secondary claim	Delta Dental PPO	48	provider	\N
ELIG_FREQUENCY_LIMIT	eligibility	${cdt_code} tooth #${tooth}: last approved ${last_date}. Next eligible: ${eligible_date}	Delta Dental PPO	24	provider	\N
CLINICAL_XRAY_REQUIRED	clinical	Current periapical X-ray (within 12 months) required for ${cdt_code} on tooth #${tooth}	Delta Dental PPO	48	provider	\N
CLINICAL_XRAY_TOO_OLD	clinical	X-ray dated ${date} exceeds 12-month requirement â€” provide current X-ray	Delta Dental PPO	48	provider	\N
CLINICAL_PERIO_CHART_REQUIRED	clinical	Current periodontal chart (within 6 months) required for ${cdt_code}	Delta Dental PPO	48	provider	\N
CLINICAL_BONE_LOSS_THRESHOLD	clinical	Bone loss measurement â‰¥${threshold}mm required. Current X-ray shows ${current}mm	Delta Dental PPO	72	provider	\N
CLINICAL_POCKET_DEPTH	clinical	Pocket depth â‰¥${threshold}mm required in ${min_sites} sites. Current max: ${current}mm	Delta Dental PPO	72	provider	\N
CLINICAL_NARRATIVE_REQUIRED	clinical	Clinical narrative explaining medical necessity required for ${cdt_code}	Delta Dental PPO	48	provider	\N
CLINICAL_CBCT_REQUIRED	clinical	3D CBCT scan with implant site analysis required for D6010 on tooth #${tooth}	Delta Dental PPO	72	provider	\N
CLINICAL_EXTRACTION_DATE	clinical	Extraction date documentation required for tooth #${tooth} â€” verify missing tooth clause	Delta Dental PPO	48	provider	\N
CLINICAL_PRIOR_TREATMENT	clinical	Prior treatment documentation required: ${treatment_required}	Delta Dental PPO	72	provider	\N
CLINICAL_IMPLANT_SITE_ANALYSIS	clinical	Bone volume/density analysis required at tooth #${tooth} â€” inadequate for implant	Delta Dental PPO	72	provider	\N
CLINICAL_PHOTOS_REQUIRED	clinical	Clinical photographs required for ${cdt_code} â€” buccal, lingual, occlusal views	Delta Dental PPO	48	provider	\N
CLINICAL_DIAGNOSIS_CODE	clinical	ICD-10 diagnosis code required â€” medical benefit crossover detected	Delta Dental PPO	48	provider	\N
CLINICAL_CRITERIA_NOT_MET	clinical	${cdt_code} does not meet ${payer} clinical criteria. Score: ${score}. Missing: ${missing}	Delta Dental PPO	72	provider	\N
CLINICAL_SECOND_OPINION	clinical	Second opinion required for case value > ${threshold}	Delta Dental PPO	72	provider	\N
CLINICAL_SPECIALIST_REFERRAL	clinical	${cdt_code} requires periodontist/oral surgeon evaluation	Delta Dental PPO	48	provider	\N
COVERAGE_BUNDLING_CONFLICT	coverage	${cdt_code_a} and ${cdt_code_b} cannot be billed separately per Delta Dental section ${section}	Delta Dental PPO	24	provider	\N
COVERAGE_DOWNGRADE_APPLIED	coverage	${billed_code} downgraded to ${allowed_code} â€” reimbursement based on ${allowed_code} fee	Delta Dental PPO	24	provider	\N
COVERAGE_FREQUENCY_EXCEEDED	coverage	${cdt_code} tooth #${tooth}: frequency limit exceeded. Last approved ${last_date}.	Delta Dental PPO	24	provider	\N
COVERAGE_PRED_REQUIRED	coverage	Pre-determination required before treatment for ${cdt_code} on tooth #${tooth}	Delta Dental PPO	24	provider	\N
COVERAGE_PRED_EXPIRED	coverage	Pre-determination ${pred_number} expired on ${expiry_date} â€” resubmit	Delta Dental PPO	24	provider	\N
COVERAGE_TOOTH_INELIGIBLE	coverage	Tooth #${tooth} ineligible: ${reason}	Delta Dental PPO	24	provider	\N
COVERAGE_SURFACE_MISMATCH	coverage	Billed surface ${billed} does not match X-ray findings ${xray} on tooth #${tooth}	Delta Dental PPO	48	provider	\N
COVERAGE_NOT_MEDICALLY_NECESSARY	coverage	${cdt_code} not covered â€” dental necessity not established per plan policy	Delta Dental PPO	72	provider	\N
COVERAGE_ALTERNATE_BENEFIT	coverage	Alternate benefit: plan pays for ${alt_code} instead of ${billed_code}	Delta Dental PPO	24	provider	\N
COVERAGE_MISSING_TOOTH_EXCL	coverage	Tooth #${tooth} excluded: missing before enrollment ${date}	Delta Dental PPO	24	provider	\N
PROVIDER_OUT_OF_NETWORK	provider	Provider NPI ${npi} out-of-network â€” higher cost-sharing applies	Delta Dental PPO	24	provider	\N
PROVIDER_NOT_CREDENTIALED	provider	Provider NPI ${npi} not credentialed with ${payer}	Delta Dental PPO	24	provider	\N
PROVIDER_LICENSE_EXPIRED	provider	Provider license expired ${date} in ${state}	Delta Dental PPO	24	provider	\N
PROVIDER_NPI_MISMATCH	provider	NPI on pre-D ${submitted_npi} differs from credentialing file ${credentialed_npi}	Delta Dental PPO	24	provider	\N
PROVIDER_SPECIALTY_REQUIRED	provider	${cdt_code} requires periodontist or oral surgeon â€” general dentist NPI ${npi} ineligible	Delta Dental PPO	48	provider	\N
PROVIDER_SUPERVISING_REQUIRED	provider	Supervising dentist required for this procedure	Delta Dental PPO	48	provider	\N
PROVIDER_SANCTIONS	provider	Provider NPI ${npi} has sanctions history requiring compliance review	Delta Dental PPO	24	provider	\N
PROVIDER_REFERRAL_MISMATCH	provider	Referral not from approved referring provider for this plan	Delta Dental PPO	48	provider	\N
ADMIN_DUPLICATE_PRED	administrative	Duplicate pre-D detected for ${patient} tooth #${tooth} (${cdt_code}). Existing: ${pred_number}	Delta Dental PPO	24	provider	\N
ADMIN_PRED_NUMBER_REQUIRED	administrative	Pre-D number required before treatment â€” do not treat until ${pred_request_id} approved	Delta Dental PPO	24	provider	\N
ADMIN_DATE_RANGE_REQUIRED	administrative	Treatment date range required for pre-determination	Delta Dental PPO	24	provider	\N
ADMIN_COB_PRIMARY_FIRST	administrative	${primary_payer} must be billed first â€” attach EOB before submitting to ${secondary_payer}	Delta Dental PPO	48	provider	\N
ADMIN_APPEAL_DEADLINE	administrative	Appeal deadline: ${deadline} â€” ${days_remaining} days remaining. Appeal packet ready.	Delta Dental PPO	24	provider	\N
ADMIN_RETRO_PRED	administrative	Retroactive pre-D required â€” treatment provided without prior authorization	Delta Dental PPO	48	provider	\N
ADMIN_PRED_EXPIRED_RESUBMIT	administrative	Pre-D ${pred_number} expired â€” submit new pre-determination if treatment not yet complete	Delta Dental PPO	24	provider	\N
\.


--
-- Data for Name: cost_estimates; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.cost_estimates (estimate_id, pred_request_id, procedure_id, tenant_id, cdt_code, tooth_number, fee_submitted, allowed_amount, insurance_pays, patient_pays, deductible_applied, benefit_pct, annual_max_applied, downgrade_applied, downgrade_from, computed_at) FROM stdin;
a91aa7a4-525c-4bba-8a0a-2c3b754ec67f	PRED-SIM-DA-C09	L1	suwanee_smiles	D6010	19	1985.00	1985.00	967.50	1017.50	50.00	50.00	f	f	\N	2026-08-06 05:23:19.204339+00
6ab714e1-0e34-4a0a-b48e-0f8704f4df91	PRED-SIM-DA-C10	L1	suwanee_smiles	D2750	14	1190.00	1190.00	570.00	620.00	50.00	50.00	f	f	\N	2026-08-06 05:23:19.204339+00
9659f932-24e4-4e52-a844-2e43559dec50	PRED-SIM-DA-D01	L1	suwanee_smiles	D4260	3	1850.00	1004.50	477.25	527.25	50.00	50.00	f	f	\N	2026-08-06 05:23:19.204339+00
faa852fd-c58b-46f3-aec2-23d201060751	PRED-SIM-DA-D01	L2	suwanee_smiles	D6010	3	2800.00	1985.00	992.50	992.50	0.00	50.00	f	f	\N	2026-08-06 05:23:19.204339+00
13a4ee17-d1c4-4c3e-acb9-ae135364cef7	PRED-SIM-DA-D01	L3	suwanee_smiles	D7953	3	950.00	425.00	212.50	212.50	0.00	50.00	f	f	\N	2026-08-06 05:23:19.204339+00
ea018c26-dc8a-4706-9d60-c31874cad646	PRED-SIM-DA-D02	L1	suwanee_smiles	D6010	3	3500.00	1985.00	967.50	1017.50	50.00	50.00	f	f	\N	2026-08-06 05:23:19.204339+00
c2b63f06-9264-4f22-afcf-88984e6e1d5d	PRED-SIM-DA-D02	L2	suwanee_smiles	D6010	6	3500.00	1985.00	832.50	1152.50	0.00	50.00	t	f	\N	2026-08-06 05:23:19.204339+00
869aa796-71b7-4339-be3b-0fc8391c257b	PRED-SIM-DA-D02	L3	suwanee_smiles	D6010	11	3500.00	1985.00	0.00	1985.00	0.00	50.00	t	f	\N	2026-08-06 05:23:19.204339+00
0c2f1574-d817-483d-92da-364ec489b560	PRED-SIM-DA-D02	L4	suwanee_smiles	D6010	14	3500.00	1985.00	0.00	1985.00	0.00	50.00	t	f	\N	2026-08-06 05:23:19.204339+00
76357ab1-46f3-4a11-a072-2868b1b410c6	PRED-SIM-DA-D02	L5	suwanee_smiles	D7953	3	1300.00	425.00	0.00	425.00	0.00	50.00	t	f	\N	2026-08-06 05:23:19.204339+00
6065f2ee-322e-4529-aa6c-2f5e5535a310	PRED-SIM-DA-D02	L6	suwanee_smiles	D7953	6	1300.00	425.00	0.00	425.00	0.00	50.00	t	f	\N	2026-08-06 05:23:19.204339+00
2a061ba5-9afb-48f2-8295-d63f8e622354	PRED-SIM-DA-D02	L7	suwanee_smiles	D7953	11	1300.00	425.00	0.00	425.00	0.00	50.00	t	f	\N	2026-08-06 05:23:19.204339+00
abed1bb7-7496-4916-894a-0459c921185f	PRED-SIM-DA-D02	L8	suwanee_smiles	D7953	14	1300.00	425.00	0.00	425.00	0.00	50.00	t	f	\N	2026-08-06 05:23:19.204339+00
694bd358-0cda-4b9f-9635-472a5a0ce75d	PRED-SIM-DA-D02	L9	suwanee_smiles	D6065	3	4000.00	1190.00	0.00	1190.00	0.00	50.00	t	t	D6065	2026-08-06 05:23:19.204339+00
9b9bcab8-7b2c-4122-96c0-c946847e4fe0	PRED-SIM-DA-D02	L10	suwanee_smiles	D6065	6	4000.00	1190.00	0.00	1190.00	0.00	50.00	t	t	D6065	2026-08-06 05:23:19.204339+00
69c5f00c-2e22-48bb-84ae-cd660674ff97	PRED-SIM-TB-A01	L1	tampa_smiles	D2750	14	1400.00	1130.50	565.25	565.25	0.00	50.00	f	f	\N	2026-08-06 13:57:06.99124+00
13903834-c8ec-4b1b-a994-acb1d07fa6d5	PRED-SIM-TB-B01	L1	tampa_smiles	D6010	19	2800.00	1786.50	0.00	1786.50	0.00	0.00	f	f	\N	2026-08-06 13:57:06.99124+00
c3e6fbc0-701c-49c4-b5a6-3039b3161f6c	PRED-SIM-TB-C01	L1	tampa_smiles	D4341	\N	420.00	271.62	177.30	94.32	50.00	80.00	f	f	\N	2026-08-06 13:57:06.99124+00
4a90594c-da9d-432b-bd93-623127fa3122	PRED-SIM-TB-C01	L2	tampa_smiles	D4341	\N	420.00	271.62	217.30	54.32	0.00	80.00	f	f	\N	2026-08-06 13:57:06.99124+00
7267f871-af80-4471-8780-d1b907788350	PRED-SIM-TB-D01	L1	tampa_smiles	D2740	8	1650.00	1125.00	562.50	562.50	0.00	50.00	f	f	\N	2026-08-06 13:57:06.99124+00
10f3137f-f939-4a26-babd-dfebf9ccb872	PRED-SIM-TB-U01	L1	tampa_smiles	D1110	\N	150.00	107.11	107.11	0.00	0.00	100.00	f	f	\N	2026-08-06 13:57:06.99124+00
04a1eac4-286a-4846-a605-c760356180b5	PRED-SIM-DL-A01	L1	dallas_dental	D6010	30	2800.00	1985.00	967.50	1017.50	50.00	50.00	f	f	\N	2026-08-06 13:57:08.297238+00
fde3e02c-c821-4688-acf2-d6238289a902	PRED-SIM-DL-A01	L2	dallas_dental	D6065	30	1800.00	1190.00	595.00	595.00	0.00	50.00	f	f	\N	2026-08-06 13:57:08.297238+00
daefde37-dd1f-4bf3-b673-dd00452bc79d	PRED-SIM-DL-B01	L1	dallas_dental	D4260	\N	1200.00	1004.50	477.25	527.25	50.00	50.00	f	f	\N	2026-08-06 13:57:08.297238+00
3ea74b4b-398f-4c59-90d8-39accb132671	PRED-SIM-DL-C01	L1	dallas_dental	D2750	3	1500.00	1190.00	570.00	620.00	50.00	50.00	f	f	\N	2026-08-06 13:57:08.297238+00
88a033fd-533c-462c-8606-860d681778cd	PRED-SIM-DL-D01	L1	dallas_dental	D8090	\N	4500.00	3825.00	1500.00	2325.00	0.00	50.00	t	f	\N	2026-08-06 13:57:08.297238+00
a74b8147-cc18-46eb-a4cd-d6b91decef9e	PRED-SIM-DL-U01	L1	dallas_dental	D0330	\N	185.00	158.87	108.87	50.00	50.00	100.00	f	f	\N	2026-08-06 13:57:08.297238+00
25c8f779-922b-4c12-83b0-4dcce36a1476	PRED-SIM-DA-A01	L1	suwanee_smiles	D6010	19	2800.00	1985.00	967.50	1017.50	50.00	50.00	f	f	\N	2026-08-06 05:23:19.204339+00
8b6b848b-4f5f-4bec-b365-a55cec304c50	PRED-SIM-DA-A01	L2	suwanee_smiles	D7953	19	950.00	425.00	212.50	212.50	0.00	50.00	f	f	\N	2026-08-06 05:23:19.204339+00
abf5cd6a-50c1-425f-9c92-f6c30c6e15bc	PRED-SIM-DA-A01	L3	suwanee_smiles	D6065	19	1800.00	1190.00	595.00	595.00	0.00	50.00	f	t	D6065	2026-08-06 05:23:19.204339+00
3ab2d2c7-9245-47c0-b566-2850dc358292	PRED-SIM-DA-A02	L1	suwanee_smiles	D2750	3	1450.00	1190.00	570.00	620.00	50.00	50.00	f	f	\N	2026-08-06 05:23:19.204339+00
9e211be9-7f9b-43a3-8965-2f4fd074d015	PRED-SIM-DA-A03	L1	suwanee_smiles	D3330	30	1200.00	1050.00	840.00	210.00	0.00	80.00	f	f	\N	2026-08-06 05:23:19.204339+00
8ba1bcf0-f5f7-4a57-a92a-0fed87474cfa	PRED-SIM-DA-A03	L2	suwanee_smiles	D2750	30	1450.00	1190.00	595.00	595.00	0.00	50.00	f	f	\N	2026-08-06 05:23:19.204339+00
bea9f8aa-3fb4-4c38-9041-a86c4ef3899e	PRED-SIM-DA-A04	L1	suwanee_smiles	D4341	\N	285.00	271.62	177.30	94.32	50.00	80.00	f	f	\N	2026-08-06 05:23:19.204339+00
a78c1b4a-89b0-45e1-bebf-7a4001b40174	PRED-SIM-DA-A04	L2	suwanee_smiles	D4341	\N	285.00	271.62	217.30	54.32	0.00	80.00	f	f	\N	2026-08-06 05:23:19.204339+00
c07a628f-19af-4abe-a52b-14f324bfaa89	PRED-SIM-DA-A04	L3	suwanee_smiles	D4341	\N	285.00	271.62	217.30	54.32	0.00	80.00	f	f	\N	2026-08-06 05:23:19.204339+00
d1e9df2e-6ccf-46da-a80c-ed4a045f9178	PRED-SIM-DA-A04	L4	suwanee_smiles	D4341	\N	285.00	271.62	217.30	54.32	0.00	80.00	f	f	\N	2026-08-06 05:23:19.204339+00
baba03d7-7604-4bd5-b61b-7afb02aeb8db	PRED-SIM-DA-A05	L1	suwanee_smiles	D0330	\N	195.00	158.87	158.87	0.00	0.00	100.00	f	f	\N	2026-08-06 05:23:19.204339+00
7e1a1ea2-d645-43f5-b8a3-8bd1cc6651c4	PRED-SIM-DA-B01	L1	suwanee_smiles	D6010	14	2800.00	1985.00	0.00	1985.00	0.00	0.00	f	f	\N	2026-08-06 05:23:19.204339+00
aba2f709-57af-4aa5-a06c-83085c833c06	PRED-SIM-DA-B01	L2	suwanee_smiles	D6065	14	1800.00	1190.00	0.00	1190.00	0.00	0.00	f	t	D6065	2026-08-06 05:23:19.204339+00
c48ab137-6e6e-4c38-982a-97f73e72fecc	PRED-SIM-DA-U01	L1	suwanee_smiles	D1110	\N	150.00	112.75	62.75	50.00	50.00	100.00	f	f	\N	2026-08-06 05:23:19.204339+00
a400a46f-d0e9-40db-ac6c-ddb69d73f7a0	PRED-SIM-DA-U02	L1	suwanee_smiles	D0274	\N	85.00	76.87	26.87	50.00	50.00	100.00	f	f	\N	2026-08-06 05:23:19.204339+00
a4692a3a-341a-4e7c-a13d-8241db61d58b	PRED-SIM-DA-U03	L1	suwanee_smiles	D2391	14	175.00	148.75	79.00	69.75	50.00	80.00	f	f	\N	2026-08-06 05:23:19.204339+00
80be342c-68bc-495c-9c68-e44658b7ce66	PRED-SIM-DA-U04	L1	suwanee_smiles	D7140	32	185.00	185.83	67.92	117.92	50.00	50.00	f	f	\N	2026-08-06 05:23:19.204339+00
73024429-47b2-41ef-b1c1-9bc63196da7e	PRED-SIM-DA-U05	L1	suwanee_smiles	D4910	\N	175.00	148.62	78.90	69.72	50.00	80.00	f	f	\N	2026-08-06 05:23:19.204339+00
295e4d8c-727c-4676-99f2-b63c14fddb1e	PRED-SIM-DA-B02	L1	suwanee_smiles	D6010	19	2800.00	1985.00	967.50	1017.50	50.00	50.00	f	f	\N	2026-08-06 05:23:19.204339+00
2a7ef36b-3254-4ecd-8a33-761ea3704896	PRED-SIM-DA-B02	L2	suwanee_smiles	D6065	19	1800.00	1190.00	595.00	595.00	0.00	50.00	f	t	D6065	2026-08-06 05:23:19.204339+00
a9f00946-bd4e-46ec-90a1-8c8e7ac3bd65	PRED-SIM-DA-B03	L1	suwanee_smiles	D2750	3	1450.00	1190.00	570.00	620.00	50.00	50.00	f	f	\N	2026-08-06 05:23:19.204339+00
40ad71c4-523e-402f-a5d3-bfc11eb0006e	PRED-SIM-DA-B04	L1	suwanee_smiles	D6010	19	2800.00	1985.00	967.50	1017.50	50.00	50.00	f	f	\N	2026-08-06 05:23:19.204339+00
8dd72430-884e-4640-a415-0c7dd03fb363	PRED-SIM-DA-B04	L2	suwanee_smiles	D7953	19	950.00	425.00	212.50	212.50	0.00	50.00	f	f	\N	2026-08-06 05:23:19.204339+00
c14c6e6a-eae7-4cbb-992d-e542d36d1134	PRED-SIM-DA-B05	L1	suwanee_smiles	D2750	13	1450.00	1190.00	570.00	620.00	50.00	50.00	f	f	\N	2026-08-06 05:23:19.204339+00
e8dc4f5a-8535-421e-992d-d50908f433da	PRED-SIM-DA-C01	L1	suwanee_smiles	D6010	19	2800.00	1985.00	967.50	1017.50	50.00	50.00	f	f	\N	2026-08-06 05:23:19.204339+00
469e59c2-9f06-444e-aab0-94cdf700934a	PRED-SIM-DA-C01	L2	suwanee_smiles	D7953	19	950.00	425.00	212.50	212.50	0.00	50.00	f	f	\N	2026-08-06 05:23:19.204339+00
26452045-6538-4259-897f-bbe7324d7efb	PRED-SIM-DA-C02	L1	suwanee_smiles	D4260	14	1850.00	1004.50	477.25	527.25	50.00	50.00	f	f	\N	2026-08-06 05:23:19.204339+00
91e55e5f-9632-4f53-8f25-091c97e0978d	PRED-SIM-DA-C03	L1	suwanee_smiles	D6010	3	2800.00	1985.00	967.50	1017.50	50.00	50.00	f	f	\N	2026-08-06 05:23:19.204339+00
e4695630-07f5-442c-9120-695bb59d10c1	PRED-SIM-DA-C03	L2	suwanee_smiles	D6010	14	2800.00	1985.00	832.50	1152.50	0.00	50.00	t	f	\N	2026-08-06 05:23:19.204339+00
d0e5684d-255b-43ee-8da9-8e5925b23193	PRED-SIM-DA-C03	L3	suwanee_smiles	D6010	19	2800.00	1985.00	0.00	1985.00	0.00	50.00	t	f	\N	2026-08-06 05:23:19.204339+00
aa84b2b7-aa77-4e9e-9d64-1157ec2b4736	PRED-SIM-DA-C03	L4	suwanee_smiles	D6010	30	2800.00	1985.00	0.00	1985.00	0.00	50.00	t	f	\N	2026-08-06 05:23:19.204339+00
a8472c56-f809-401e-aa0e-dcd928b993a2	PRED-SIM-DA-C03	L5	suwanee_smiles	D6065	3	1800.00	1190.00	0.00	1190.00	0.00	50.00	t	t	D6065	2026-08-06 05:23:19.204339+00
09cb265b-91ba-4be6-96cf-349eb6aad3f1	PRED-SIM-DA-C03	L6	suwanee_smiles	D6065	14	1800.00	1190.00	0.00	1190.00	0.00	50.00	t	t	D6065	2026-08-06 05:23:19.204339+00
b5932fdc-3b85-4b6f-a393-e8e5791ed244	PRED-SIM-DA-C03	L7	suwanee_smiles	D6065	19	1800.00	1190.00	0.00	1190.00	0.00	50.00	t	t	D6065	2026-08-06 05:23:19.204339+00
3b79815f-afec-4fbf-9a23-a678d7d837a0	PRED-SIM-DA-C03	L8	suwanee_smiles	D6065	30	1800.00	1190.00	0.00	1190.00	0.00	50.00	t	t	D6065	2026-08-06 05:23:19.204339+00
6bcd970b-9e21-485c-bbc7-5a3b6b6c97ca	PRED-SIM-DA-C04	L1	suwanee_smiles	D2750	3	1450.00	1190.00	570.00	620.00	50.00	50.00	f	f	\N	2026-08-06 05:23:19.204339+00
7ea65e32-6510-4329-aaf1-55779a9a37a8	PRED-SIM-DA-C05	L1	suwanee_smiles	D2750	14	1450.00	1190.00	570.00	620.00	50.00	50.00	f	f	\N	2026-08-06 05:23:19.204339+00
520b4d03-8936-4599-8cca-c7ed07bda6d6	PRED-SIM-DA-C06	L1	suwanee_smiles	D2740	8	1250.00	1312.50	631.25	681.25	50.00	50.00	f	f	\N	2026-08-06 05:23:19.204339+00
183f2621-6247-416d-a59b-03838f4aec5a	PRED-SIM-DA-C07	L1	suwanee_smiles	D0330	\N	155.00	155.70	105.70	50.00	50.00	100.00	f	f	\N	2026-08-06 05:23:19.204339+00
5e6ebc89-ef26-4cca-827f-8b9ca1f8b814	PRED-SIM-DA-C08	L1	suwanee_smiles	D2750	3	1190.00	1190.00	595.00	595.00	0.00	50.00	f	f	\N	2026-08-06 05:23:19.204339+00
3cae1170-95b8-4c0e-91a9-c9da182e35fa	PRED-SIM-DA-D02	L11	suwanee_smiles	D6065	11	4000.00	1190.00	0.00	1190.00	0.00	50.00	t	t	D6065	2026-08-06 05:23:19.204339+00
03b80851-b658-46e4-b52d-c19b3deb860c	PRED-SIM-DA-D02	L12	suwanee_smiles	D6065	14	4000.00	1190.00	0.00	1190.00	0.00	50.00	t	t	D6065	2026-08-06 05:23:19.204339+00
03845dc0-55e4-4fbd-bded-e519967793ae	PRED-SIM-DA-D03	L1	suwanee_smiles	D6010	19	2800.00	1985.00	967.50	1017.50	50.00	50.00	f	f	\N	2026-08-06 05:23:19.204339+00
27b5b07b-7304-496b-bf68-1a84ed9d0eac	PRED-SIM-DA-D03	L2	suwanee_smiles	D6065	19	1800.00	1190.00	595.00	595.00	0.00	50.00	f	t	D6065	2026-08-06 05:23:19.204339+00
e2c4a03b-1116-45a5-af72-7b353ef17ad1	PRED-SIM-DA-D04	L1	suwanee_smiles	D2740	8	1650.00	1190.00	570.00	620.00	50.00	50.00	f	t	D2740	2026-08-06 05:23:19.204339+00
83df4d23-6568-4ba0-85ee-982fe94f9e9c	PRED-SIM-DA-D05	L1	suwanee_smiles	D6010	19	2800.00	1985.00	967.50	1017.50	50.00	50.00	f	f	\N	2026-08-06 05:23:19.204339+00
d3c323cf-82d2-4f68-914d-b1ace0851884	PRED-SIM-DA-D05	L2	suwanee_smiles	D7953	19	950.00	425.00	212.50	212.50	0.00	50.00	f	f	\N	2026-08-06 05:23:19.204339+00
e235618e-f066-4b45-b661-773677c133e3	PRED-SIM-DA-F01	L1	suwanee_smiles	D2740	8	1650.00	1190.00	570.00	620.00	50.00	50.00	f	t	D2740	2026-08-06 05:23:19.204339+00
e5da5d5e-8ac6-4a4a-b815-9d8bb5556b37	PRED-SIM-DA-F02	L1	suwanee_smiles	D4260	\N	1850.00	1004.50	477.25	527.25	50.00	50.00	f	f	\N	2026-08-06 05:23:19.204339+00
c3297920-d205-4b92-9a9a-ca94bcbd8862	PRED-SIM-DA-F03	L1	suwanee_smiles	D2750	3	1450.00	1190.00	570.00	620.00	50.00	50.00	f	f	\N	2026-08-06 05:23:19.204339+00
84b68adb-29e2-4a46-b46e-78f17ef4161c	PRED-SIM-DA-F04	L1	suwanee_smiles	D2750	14	1450.00	1190.00	570.00	620.00	50.00	50.00	f	f	\N	2026-08-06 05:23:19.204339+00
96f91108-e152-436b-9e4d-3d4a62d9e1bf	PRED-SIM-DA-F05	L1	suwanee_smiles	D6010	19	2800.00	1985.00	967.50	1017.50	50.00	50.00	f	f	\N	2026-08-06 05:23:19.204339+00
95a2e106-1510-44a2-abe6-81f87f06aa0f	PRED-SIM-DA-M01	L1	suwanee_smiles	D2750	19	1450.00	1190.00	570.00	620.00	50.00	50.00	f	f	\N	2026-08-06 05:23:19.204339+00
7476c394-50d6-4508-92bf-de84c8274ebd	PRED-SIM-DA-M02	L1	suwanee_smiles	D4260	\N	1850.00	1004.50	477.25	527.25	50.00	50.00	f	f	\N	2026-08-06 05:23:19.204339+00
9d2f4274-6ffa-4b2d-8f98-1d645f32e0dc	PRED-SIM-DA-M03	L1	suwanee_smiles	D2750	14	1450.00	1190.00	570.00	620.00	50.00	50.00	f	f	\N	2026-08-06 05:23:19.204339+00
fbb3d64c-56b2-4ae7-b9bf-865d04f2128e	PRED-SIM-DA-M04	L1	suwanee_smiles	D6010	19	2800.00	1985.00	967.50	1017.50	50.00	50.00	f	f	\N	2026-08-06 05:23:19.204339+00
dc319658-8d5b-443a-a01a-f3ac471b727a	PRED-SIM-DA-M05	L1	suwanee_smiles	D2750	3	1450.00	1190.00	570.00	620.00	50.00	50.00	f	f	\N	2026-08-06 05:23:19.204339+00
\.


--
-- Data for Name: coverage_rules; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.coverage_rules (rule_id, payer_id, cdt_code, covered, benefit_category, coverage_pct, frequency_limit, frequency_unit, frequency_scope, bundled_with, bundling_note, bundling_separable, downgrade_to_cdt, downgrade_note, missing_tooth_clause_applies, pred_required, clinical_criteria_required, policy_section) FROM stdin;
1	delta_dental	D0330	t	preventive	100.00	1	per_5_years	\N	{}	\N	\N	\N	\N	f	f	f	D.1.4
2	delta_dental	D1110	t	preventive	100.00	2	per_year	\N	{}	\N	\N	\N	\N	f	f	f	D.2.1
3	delta_dental	D2740	t	major	50.00	1	per_5_years	\N	{}	\N	\N	D2750	D2740 all-ceramic downgraded to D2750 PFM fee	f	t	f	D.4.2
4	delta_dental	D2750	t	major	50.00	1	per_5_years	\N	{D2950}	\N	f	\N	\N	f	t	f	D.4.3
5	delta_dental	D2950	t	major	50.00	\N	\N	\N	{D2740,D2750}	\N	f	\N	\N	f	f	f	D.4.4
6	delta_dental	D3330	t	basic	80.00	1	per_lifetime	\N	{}	\N	\N	\N	\N	t	f	t	D.5.3
7	delta_dental	D4260	t	major	50.00	1	per_3_years	\N	{}	\N	\N	\N	\N	f	t	t	D.6.3
8	delta_dental	D4341	t	basic	80.00	4	per_year	\N	{D4342}	\N	f	\N	\N	f	f	t	D.6.1
9	delta_dental	D4342	t	basic	80.00	\N	\N	\N	{D4341}	\N	f	\N	\N	f	f	f	D.6.2
10	delta_dental	D4910	t	basic	80.00	4	per_year	\N	{}	\N	\N	\N	\N	f	f	f	D.6.4
11	delta_dental	D6010	t	implant	50.00	1	per_lifetime	\N	{}	\N	\N	\N	\N	t	t	t	D.7.1
12	delta_dental	D6065	t	implant	50.00	1	per_5_years	\N	{}	\N	\N	D2750	D6065 reimbursed at D2750 fee schedule	t	t	f	D.7.2
13	delta_dental	D6066	t	implant	50.00	\N	\N	\N	{}	\N	\N	D2750	\N	t	t	f	D.7.3
14	delta_dental	D7953	t	implant	50.00	1	per_lifetime	\N	{D6010}	D7953 frequently denied as not separately payable with D6010. Requires separate clinical documentation + bone loss >=3mm + narrative. Appeal success ~65% when documented.	t	\N	\N	t	t	t	D.7.4
15	delta_dental	D0120	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
16	cigna	D0120	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
17	metlife	D0120	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
18	delta_dental	D0140	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
19	cigna	D0140	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
20	metlife	D0140	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
21	delta_dental	D0145	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
22	cigna	D0145	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
23	metlife	D0145	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
24	delta_dental	D0150	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
25	cigna	D0150	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
26	metlife	D0150	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
27	delta_dental	D0160	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
28	cigna	D0160	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
29	metlife	D0160	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
30	delta_dental	D0170	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
31	cigna	D0170	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
32	metlife	D0170	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
33	delta_dental	D0180	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
34	cigna	D0180	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
35	metlife	D0180	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
36	delta_dental	D0210	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
37	cigna	D0210	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
38	metlife	D0210	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
39	delta_dental	D0220	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
40	cigna	D0220	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
41	metlife	D0220	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
42	delta_dental	D0230	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
43	cigna	D0230	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
44	metlife	D0230	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
45	delta_dental	D0240	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
46	cigna	D0240	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
47	metlife	D0240	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
48	delta_dental	D0272	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
49	cigna	D0272	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
50	metlife	D0272	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
51	delta_dental	D0273	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
52	cigna	D0273	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
53	metlife	D0273	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
54	delta_dental	D0274	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
55	cigna	D0274	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
56	metlife	D0274	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
57	delta_dental	D0277	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
58	cigna	D0277	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
59	metlife	D0277	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
61	cigna	D0330	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
62	metlife	D0330	t	preventive	100.00	1	per_3_years	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
63	delta_dental	D0364	t	preventive	100.00	1	per_5_years	per_patient	{}	\N	\N	\N	\N	f	f	t	D.1.1
64	cigna	D0364	t	preventive	100.00	1	per_5_years	per_patient	{}	\N	\N	\N	\N	f	f	t	D.1.1
65	metlife	D0364	t	preventive	100.00	1	per_5_years	per_patient	{}	\N	\N	\N	\N	f	f	t	D.1.1
66	delta_dental	D0367	t	preventive	100.00	1	per_5_years	per_patient	{}	\N	\N	\N	\N	f	f	t	D.1.1
67	cigna	D0367	t	preventive	100.00	1	per_5_years	per_patient	{}	\N	\N	\N	\N	f	f	t	D.1.1
68	metlife	D0367	t	preventive	100.00	1	per_5_years	per_patient	{}	\N	\N	\N	\N	f	f	t	D.1.1
69	delta_dental	D0470	f	\N	0.00	\N	\N	\N	{}	Diagnostic casts are not a covered benefit.	\N	\N	\N	f	f	f	D.9.1
70	cigna	D0470	f	\N	0.00	\N	\N	\N	{}	Diagnostic casts are not a covered benefit.	\N	\N	\N	f	f	f	D.9.1
71	metlife	D0470	f	\N	0.00	\N	\N	\N	{}	Diagnostic casts are not a covered benefit.	\N	\N	\N	f	f	f	D.9.1
72	delta_dental	D0601	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
73	cigna	D0601	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
74	metlife	D0601	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
75	delta_dental	D0602	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
76	cigna	D0602	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
77	metlife	D0602	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
78	delta_dental	D0603	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
79	cigna	D0603	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
80	metlife	D0603	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
82	cigna	D1110	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
83	metlife	D1110	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
84	delta_dental	D1120	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
85	cigna	D1120	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
86	metlife	D1120	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
87	delta_dental	D1206	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
88	cigna	D1206	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
89	metlife	D1206	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
90	delta_dental	D1208	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
91	cigna	D1208	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
92	metlife	D1208	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
93	delta_dental	D1310	f	\N	0.00	\N	\N	\N	{}	Nutritional counselling is not a covered benefit.	\N	\N	\N	f	f	f	D.9.1
94	cigna	D1310	f	\N	0.00	\N	\N	\N	{}	Nutritional counselling is not a covered benefit.	\N	\N	\N	f	f	f	D.9.1
95	metlife	D1310	f	\N	0.00	\N	\N	\N	{}	Nutritional counselling is not a covered benefit.	\N	\N	\N	f	f	f	D.9.1
96	delta_dental	D1330	f	\N	0.00	\N	\N	\N	{}	Oral hygiene instruction is not a covered benefit.	\N	\N	\N	f	f	f	D.9.1
97	cigna	D1330	f	\N	0.00	\N	\N	\N	{}	Oral hygiene instruction is not a covered benefit.	\N	\N	\N	f	f	f	D.9.1
98	metlife	D1330	f	\N	0.00	\N	\N	\N	{}	Oral hygiene instruction is not a covered benefit.	\N	\N	\N	f	f	f	D.9.1
99	delta_dental	D1351	t	preventive	100.00	1	per_3_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.1.1
100	cigna	D1351	t	preventive	100.00	1	per_3_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.1.1
101	metlife	D1351	t	preventive	100.00	1	per_3_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.1.1
102	delta_dental	D1352	t	preventive	100.00	1	per_3_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.1.1
103	cigna	D1352	t	preventive	100.00	1	per_3_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.1.1
104	metlife	D1352	t	preventive	100.00	1	per_3_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.1.1
105	delta_dental	D1354	t	preventive	100.00	1	per_3_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.1.1
106	cigna	D1354	t	preventive	100.00	1	per_3_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.1.1
107	metlife	D1354	t	preventive	100.00	1	per_3_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.1.1
108	delta_dental	D1516	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
109	cigna	D1516	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
110	metlife	D1516	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
111	delta_dental	D1517	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
112	cigna	D1517	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
113	metlife	D1517	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
114	delta_dental	D2140	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
115	cigna	D2140	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
116	metlife	D2140	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
117	delta_dental	D2150	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
118	cigna	D2150	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
119	metlife	D2150	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
120	delta_dental	D2160	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
121	cigna	D2160	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
122	metlife	D2160	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
123	delta_dental	D2161	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
124	cigna	D2161	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
125	metlife	D2161	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
126	delta_dental	D2330	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
127	cigna	D2330	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
128	metlife	D2330	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
129	delta_dental	D2331	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
130	cigna	D2331	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
131	metlife	D2331	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
132	delta_dental	D2332	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
133	cigna	D2332	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
134	metlife	D2332	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
135	delta_dental	D2335	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
136	cigna	D2335	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
137	metlife	D2335	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
138	delta_dental	D2390	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
139	cigna	D2390	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
140	metlife	D2390	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
141	delta_dental	D2391	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
142	cigna	D2391	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
143	metlife	D2391	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
144	delta_dental	D2392	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
145	cigna	D2392	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
146	metlife	D2392	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
147	delta_dental	D2393	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
148	cigna	D2393	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
149	metlife	D2393	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
150	delta_dental	D2394	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
151	cigna	D2394	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
152	metlife	D2394	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
153	delta_dental	D2510	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
154	cigna	D2510	t	major	50.00	1	per_4_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
155	metlife	D2510	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
156	delta_dental	D2542	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
157	cigna	D2542	t	major	50.00	1	per_4_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
158	metlife	D2542	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
159	delta_dental	D2610	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	D2510	delta_dental reimburses D2610 at the D2510 rate; the patient covers the difference.	f	t	t	D.4.1
160	cigna	D2610	t	major	50.00	1	per_4_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
161	metlife	D2610	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	D2510	metlife reimburses D2610 at the D2510 rate; the patient covers the difference.	f	t	t	D.4.1
162	delta_dental	D2642	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	D2542	delta_dental reimburses D2642 at the D2542 rate; the patient covers the difference.	f	t	t	D.4.1
163	cigna	D2642	t	major	50.00	1	per_4_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
164	metlife	D2642	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	D2542	metlife reimburses D2642 at the D2542 rate; the patient covers the difference.	f	t	t	D.4.1
165	delta_dental	D2710	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
166	cigna	D2710	t	major	50.00	1	per_4_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
167	metlife	D2710	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
168	delta_dental	D2720	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
169	cigna	D2720	t	major	50.00	1	per_4_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
170	metlife	D2720	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
171	delta_dental	D2721	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
172	cigna	D2721	t	major	50.00	1	per_4_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
173	metlife	D2721	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
174	delta_dental	D2722	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
175	cigna	D2722	t	major	50.00	1	per_4_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
176	metlife	D2722	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
178	cigna	D2740	t	major	50.00	1	per_4_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
179	metlife	D2740	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	D2750	metlife reimburses D2740 at the D2750 rate; the patient covers the difference.	f	t	t	D.4.1
181	cigna	D2750	t	major	50.00	1	per_4_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
182	metlife	D2750	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
183	delta_dental	D2751	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
184	cigna	D2751	t	major	50.00	1	per_4_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
185	metlife	D2751	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
186	delta_dental	D2752	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
187	cigna	D2752	t	major	50.00	1	per_4_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
188	metlife	D2752	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
189	delta_dental	D2780	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
190	cigna	D2780	t	major	50.00	1	per_4_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
191	metlife	D2780	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
192	delta_dental	D2781	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
193	cigna	D2781	t	major	50.00	1	per_4_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
194	metlife	D2781	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
195	delta_dental	D2782	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
196	cigna	D2782	t	major	50.00	1	per_4_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
197	metlife	D2782	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
198	delta_dental	D2790	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
199	cigna	D2790	t	major	50.00	1	per_4_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
200	metlife	D2790	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
201	delta_dental	D2791	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
202	cigna	D2791	t	major	50.00	1	per_4_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
203	metlife	D2791	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
204	delta_dental	D2792	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
205	cigna	D2792	t	major	50.00	1	per_4_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
206	metlife	D2792	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
207	delta_dental	D2910	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
208	cigna	D2910	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
209	metlife	D2910	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
210	delta_dental	D2920	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
211	cigna	D2920	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
212	metlife	D2920	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
213	delta_dental	D2929	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
214	cigna	D2929	t	major	50.00	1	per_4_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
215	metlife	D2929	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
216	delta_dental	D2930	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
217	cigna	D2930	t	major	50.00	1	per_4_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
218	metlife	D2930	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
219	delta_dental	D2931	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
220	cigna	D2931	t	major	50.00	1	per_4_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
221	metlife	D2931	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
222	delta_dental	D2940	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
223	cigna	D2940	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
224	metlife	D2940	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
226	cigna	D2950	t	major	50.00	1	per_4_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.4.1
227	metlife	D2950	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.4.1
228	delta_dental	D2951	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.4.1
229	cigna	D2951	t	major	50.00	1	per_4_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.4.1
230	metlife	D2951	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.4.1
231	delta_dental	D2952	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.4.1
232	cigna	D2952	t	major	50.00	1	per_4_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.4.1
233	metlife	D2952	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.4.1
234	delta_dental	D2954	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.4.1
235	cigna	D2954	t	major	50.00	1	per_4_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.4.1
236	metlife	D2954	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.4.1
237	delta_dental	D3110	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
238	cigna	D3110	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
239	metlife	D3110	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
240	delta_dental	D3120	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
241	cigna	D3120	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
242	metlife	D3120	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
243	delta_dental	D3220	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
244	cigna	D3220	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
245	metlife	D3220	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
246	delta_dental	D3221	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
247	cigna	D3221	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
248	metlife	D3221	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
249	delta_dental	D3310	t	basic	80.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	f	t	D.3.1
250	cigna	D3310	t	basic	80.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	f	t	D.3.1
251	metlife	D3310	t	basic	80.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	f	t	D.3.1
252	delta_dental	D3320	t	basic	80.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	f	t	D.3.1
253	cigna	D3320	t	basic	80.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	f	t	D.3.1
254	metlife	D3320	t	basic	80.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	f	t	D.3.1
256	cigna	D3330	t	basic	80.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	f	t	D.3.1
257	metlife	D3330	t	basic	80.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	f	t	D.3.1
258	delta_dental	D3346	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
259	cigna	D3346	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
260	metlife	D3346	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
261	delta_dental	D3347	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
262	cigna	D3347	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
263	metlife	D3347	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
264	delta_dental	D3348	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
265	cigna	D3348	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
266	metlife	D3348	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
267	delta_dental	D3410	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
268	cigna	D3410	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
269	metlife	D3410	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
270	delta_dental	D3421	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
271	cigna	D3421	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
272	metlife	D3421	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
273	delta_dental	D3425	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
274	cigna	D3425	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
275	metlife	D3425	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
276	delta_dental	D3430	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
277	cigna	D3430	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
278	metlife	D3430	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
279	delta_dental	D4210	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
280	cigna	D4210	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
281	metlife	D4210	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
282	delta_dental	D4211	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
283	cigna	D4211	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
284	metlife	D4211	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
285	delta_dental	D4240	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
286	cigna	D4240	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
287	metlife	D4240	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
288	delta_dental	D4241	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
289	cigna	D4241	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
290	metlife	D4241	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
291	delta_dental	D4249	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
292	cigna	D4249	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
293	metlife	D4249	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
295	cigna	D4260	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
296	metlife	D4260	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
297	delta_dental	D4261	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
298	cigna	D4261	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
299	metlife	D4261	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
300	delta_dental	D4263	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
301	cigna	D4263	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
302	metlife	D4263	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
303	delta_dental	D4264	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
304	cigna	D4264	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
305	metlife	D4264	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
306	delta_dental	D4266	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
307	cigna	D4266	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
308	metlife	D4266	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
309	delta_dental	D4270	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
310	cigna	D4270	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
311	metlife	D4270	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
313	cigna	D4341	t	basic	80.00	4	per_year	per_quadrant	{}	\N	\N	\N	\N	f	f	t	D.3.1
314	metlife	D4341	t	basic	80.00	4	per_year	per_quadrant	{}	\N	\N	\N	\N	f	f	t	D.3.1
316	cigna	D4342	t	basic	80.00	4	per_year	per_quadrant	{}	\N	\N	\N	\N	f	f	t	D.3.1
317	metlife	D4342	t	basic	80.00	4	per_year	per_quadrant	{}	\N	\N	\N	\N	f	f	t	D.3.1
318	delta_dental	D4346	t	basic	80.00	4	per_year	per_quadrant	{}	\N	\N	\N	\N	f	f	t	D.3.1
319	cigna	D4346	t	basic	80.00	4	per_year	per_quadrant	{}	\N	\N	\N	\N	f	f	t	D.3.1
320	metlife	D4346	t	basic	80.00	4	per_year	per_quadrant	{}	\N	\N	\N	\N	f	f	t	D.3.1
321	delta_dental	D4355	t	basic	80.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	f	f	D.3.1
322	cigna	D4355	t	basic	80.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	f	f	D.3.1
323	metlife	D4355	t	basic	80.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	f	f	D.3.1
324	delta_dental	D4381	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
325	cigna	D4381	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
326	metlife	D4381	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
328	cigna	D4910	t	basic	80.00	4	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.3.1
329	metlife	D4910	t	basic	80.00	4	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.3.1
330	delta_dental	D5110	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
331	cigna	D5110	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
332	metlife	D5110	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
333	delta_dental	D5120	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
334	cigna	D5120	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
335	metlife	D5120	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
336	delta_dental	D5130	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
337	cigna	D5130	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
338	metlife	D5130	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
339	delta_dental	D5140	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
340	cigna	D5140	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
341	metlife	D5140	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
342	delta_dental	D5211	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
343	cigna	D5211	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
344	metlife	D5211	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
345	delta_dental	D5212	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
346	cigna	D5212	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
347	metlife	D5212	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
348	delta_dental	D5213	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
349	cigna	D5213	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
350	metlife	D5213	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
351	delta_dental	D5214	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
352	cigna	D5214	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
353	metlife	D5214	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
354	delta_dental	D5410	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
355	cigna	D5410	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
356	metlife	D5410	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
357	delta_dental	D5510	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
358	cigna	D5510	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
359	metlife	D5510	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
360	delta_dental	D5750	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
361	cigna	D5750	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
362	metlife	D5750	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
363	delta_dental	D5751	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
364	cigna	D5751	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
365	metlife	D5751	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
367	cigna	D6010	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
368	metlife	D6010	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
369	delta_dental	D6011	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
370	cigna	D6011	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
371	metlife	D6011	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
372	delta_dental	D6012	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
373	cigna	D6012	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
374	metlife	D6012	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
375	delta_dental	D6013	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
376	cigna	D6013	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
377	metlife	D6013	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
378	delta_dental	D6040	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
379	cigna	D6040	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
380	metlife	D6040	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
381	delta_dental	D6050	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
382	cigna	D6050	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
383	metlife	D6050	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
384	delta_dental	D6055	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
385	cigna	D6055	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
386	metlife	D6055	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
387	delta_dental	D6056	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
388	cigna	D6056	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
389	metlife	D6056	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
390	delta_dental	D6057	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
391	cigna	D6057	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
392	metlife	D6057	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
393	delta_dental	D6058	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	D2750	delta_dental reimburses D6058 at the D2750 rate; the patient covers the difference.	t	t	t	D.7.1
394	cigna	D6058	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
395	metlife	D6058	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	D2750	metlife reimburses D6058 at the D2750 rate; the patient covers the difference.	t	t	t	D.7.1
396	delta_dental	D6059	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
397	cigna	D6059	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
398	metlife	D6059	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
400	cigna	D6065	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
401	metlife	D6065	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	D2750	metlife reimburses D6065 at the D2750 rate; the patient covers the difference.	t	t	t	D.7.1
403	cigna	D6066	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
404	metlife	D6066	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	D2750	metlife reimburses D6066 at the D2750 rate; the patient covers the difference.	t	t	t	D.7.1
405	delta_dental	D6067	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
406	cigna	D6067	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
407	metlife	D6067	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
408	delta_dental	D6080	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
409	cigna	D6080	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
410	metlife	D6080	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
411	delta_dental	D6104	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
412	cigna	D6104	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
413	metlife	D6104	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
414	delta_dental	D6190	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
415	cigna	D6190	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
416	metlife	D6190	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
417	delta_dental	D6210	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
418	cigna	D6210	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
419	metlife	D6210	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
420	delta_dental	D6240	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
421	cigna	D6240	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
422	metlife	D6240	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
423	delta_dental	D6245	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	D6240	delta_dental reimburses D6245 at the D6240 rate; the patient covers the difference.	f	t	t	D.4.1
424	cigna	D6245	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
425	metlife	D6245	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	D6240	metlife reimburses D6245 at the D6240 rate; the patient covers the difference.	f	t	t	D.4.1
426	delta_dental	D6740	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	D6750	delta_dental reimburses D6740 at the D6750 rate; the patient covers the difference.	f	t	t	D.4.1
427	cigna	D6740	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
428	metlife	D6740	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	D6750	metlife reimburses D6740 at the D6750 rate; the patient covers the difference.	f	t	t	D.4.1
429	delta_dental	D6750	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
430	cigna	D6750	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
431	metlife	D6750	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
432	delta_dental	D6930	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
433	cigna	D6930	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
434	metlife	D6930	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
435	delta_dental	D7111	t	basic	80.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
436	cigna	D7111	t	basic	80.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
437	metlife	D7111	t	basic	80.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
438	delta_dental	D7140	t	basic	80.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
439	cigna	D7140	t	basic	80.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
440	metlife	D7140	t	basic	80.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
441	delta_dental	D7210	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
442	cigna	D7210	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
443	metlife	D7210	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
444	delta_dental	D7220	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
445	cigna	D7220	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
446	metlife	D7220	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
447	delta_dental	D7230	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
448	cigna	D7230	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
449	metlife	D7230	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
450	delta_dental	D7240	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
451	cigna	D7240	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
452	metlife	D7240	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
453	delta_dental	D7241	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
454	cigna	D7241	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
455	metlife	D7241	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
456	delta_dental	D7250	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
457	cigna	D7250	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
458	metlife	D7250	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
459	delta_dental	D7280	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	t	t	D.4.1
460	cigna	D7280	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	t	t	D.4.1
461	metlife	D7280	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	t	t	D.4.1
462	delta_dental	D7285	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	t	D.4.1
463	cigna	D7285	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	t	D.4.1
464	metlife	D7285	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	t	D.4.1
465	delta_dental	D7286	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	t	D.4.1
466	cigna	D7286	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	t	D.4.1
467	metlife	D7286	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	t	D.4.1
468	delta_dental	D7310	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	t	t	D.4.1
469	cigna	D7310	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	t	t	D.4.1
470	metlife	D7310	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	t	t	D.4.1
471	delta_dental	D7320	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	t	t	D.4.1
472	cigna	D7320	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	t	t	D.4.1
473	metlife	D7320	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	t	t	D.4.1
474	delta_dental	D7510	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
475	cigna	D7510	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
476	metlife	D7510	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
478	cigna	D7953	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
479	metlife	D7953	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
480	delta_dental	D7960	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	t	t	D.4.1
481	cigna	D7960	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	t	t	D.4.1
482	metlife	D7960	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	t	t	D.4.1
483	delta_dental	D8010	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
484	cigna	D8010	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
485	metlife	D8010	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
486	delta_dental	D8020	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
487	cigna	D8020	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
488	metlife	D8020	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
489	delta_dental	D8030	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
490	cigna	D8030	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
491	metlife	D8030	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
492	delta_dental	D8040	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
493	cigna	D8040	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
494	metlife	D8040	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
495	delta_dental	D8070	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
496	cigna	D8070	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
497	metlife	D8070	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
498	delta_dental	D8080	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
499	cigna	D8080	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
500	metlife	D8080	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
501	delta_dental	D8090	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
502	cigna	D8090	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
503	metlife	D8090	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
504	delta_dental	D8210	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
505	cigna	D8210	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
506	metlife	D8210	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
507	delta_dental	D8220	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
508	cigna	D8220	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
509	metlife	D8220	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
510	delta_dental	D8670	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
511	cigna	D8670	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
512	metlife	D8670	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
513	delta_dental	D8680	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
514	cigna	D8680	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
515	metlife	D8680	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
516	delta_dental	D9110	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
517	cigna	D9110	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
518	metlife	D9110	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
519	delta_dental	D9210	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
520	cigna	D9210	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
521	metlife	D9210	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
522	delta_dental	D9215	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
523	cigna	D9215	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
524	metlife	D9215	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
525	delta_dental	D9220	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	t	t	D.4.1
526	cigna	D9220	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	t	t	D.4.1
527	metlife	D9220	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	t	t	D.4.1
528	delta_dental	D9223	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	t	t	D.4.1
529	cigna	D9223	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	t	t	D.4.1
530	metlife	D9223	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	t	t	D.4.1
531	delta_dental	D9230	f	\N	0.00	\N	\N	\N	{}	Nitrous oxide is not a covered benefit; patient pays out of pocket.	\N	\N	\N	f	f	f	D.9.1
532	cigna	D9230	f	\N	0.00	\N	\N	\N	{}	Nitrous oxide is not a covered benefit; patient pays out of pocket.	\N	\N	\N	f	f	f	D.9.1
533	metlife	D9230	f	\N	0.00	\N	\N	\N	{}	Nitrous oxide is not a covered benefit; patient pays out of pocket.	\N	\N	\N	f	f	f	D.9.1
534	delta_dental	D9239	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	t	t	D.4.1
535	cigna	D9239	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	t	t	D.4.1
536	metlife	D9239	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	t	t	D.4.1
537	delta_dental	D9243	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	t	t	D.4.1
538	cigna	D9243	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	t	t	D.4.1
539	metlife	D9243	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	t	t	D.4.1
540	delta_dental	D9310	t	basic	80.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.3.1
541	cigna	D9310	t	basic	80.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.3.1
542	metlife	D9310	t	basic	80.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.3.1
543	delta_dental	D9430	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
544	cigna	D9430	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
545	metlife	D9430	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
546	delta_dental	D9440	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
547	cigna	D9440	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
548	metlife	D9440	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
549	delta_dental	D9944	t	major	50.00	1	per_5_years	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
550	cigna	D9944	t	major	50.00	1	per_5_years	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
551	metlife	D9944	t	major	50.00	1	per_5_years	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
552	delta_dental	D9951	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
553	cigna	D9951	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
554	metlife	D9951	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
555	delta_dental	D9995	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
556	cigna	D9995	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
557	metlife	D9995	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1101	aetna_dmo	D0120	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1102	humana_dpo	D0120	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1103	guardian_dpo	D0120	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1104	aetna_dmo	D0140	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1105	humana_dpo	D0140	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1106	guardian_dpo	D0140	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1107	aetna_dmo	D0145	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1108	humana_dpo	D0145	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1109	guardian_dpo	D0145	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1110	aetna_dmo	D0150	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1111	humana_dpo	D0150	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1112	guardian_dpo	D0150	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1113	aetna_dmo	D0160	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1114	humana_dpo	D0160	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1115	guardian_dpo	D0160	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1116	aetna_dmo	D0170	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1117	humana_dpo	D0170	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1118	guardian_dpo	D0170	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1119	aetna_dmo	D0180	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1120	humana_dpo	D0180	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1121	guardian_dpo	D0180	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1122	aetna_dmo	D0210	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1123	humana_dpo	D0210	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1124	guardian_dpo	D0210	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1125	aetna_dmo	D0220	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1126	humana_dpo	D0220	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1127	guardian_dpo	D0220	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1128	aetna_dmo	D0230	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1129	humana_dpo	D0230	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1130	guardian_dpo	D0230	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1131	aetna_dmo	D0240	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1132	humana_dpo	D0240	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1133	guardian_dpo	D0240	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1134	aetna_dmo	D0272	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1135	humana_dpo	D0272	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1136	guardian_dpo	D0272	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1137	aetna_dmo	D0273	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1138	humana_dpo	D0273	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1139	guardian_dpo	D0273	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1140	aetna_dmo	D0274	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1141	humana_dpo	D0274	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1142	guardian_dpo	D0274	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1143	aetna_dmo	D0277	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1144	humana_dpo	D0277	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1145	guardian_dpo	D0277	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1146	aetna_dmo	D0330	t	preventive	100.00	1	per_5_years	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1147	humana_dpo	D0330	t	preventive	100.00	1	per_3_years	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1148	guardian_dpo	D0330	t	preventive	100.00	1	per_3_years	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1149	aetna_dmo	D0364	t	preventive	100.00	1	per_5_years	per_patient	{}	\N	\N	\N	\N	f	f	t	D.1.1
1150	humana_dpo	D0364	t	preventive	100.00	1	per_5_years	per_patient	{}	\N	\N	\N	\N	f	f	t	D.1.1
1151	guardian_dpo	D0364	t	preventive	100.00	1	per_5_years	per_patient	{}	\N	\N	\N	\N	f	f	t	D.1.1
1152	aetna_dmo	D0367	t	preventive	100.00	1	per_5_years	per_patient	{}	\N	\N	\N	\N	f	f	t	D.1.1
1153	humana_dpo	D0367	t	preventive	100.00	1	per_5_years	per_patient	{}	\N	\N	\N	\N	f	f	t	D.1.1
1154	guardian_dpo	D0367	t	preventive	100.00	1	per_5_years	per_patient	{}	\N	\N	\N	\N	f	f	t	D.1.1
1155	aetna_dmo	D0470	f	\N	0.00	\N	\N	\N	{}	Diagnostic casts are not a covered benefit.	\N	\N	\N	f	f	f	D.9.1
1156	humana_dpo	D0470	f	\N	0.00	\N	\N	\N	{}	Diagnostic casts are not a covered benefit.	\N	\N	\N	f	f	f	D.9.1
1157	guardian_dpo	D0470	f	\N	0.00	\N	\N	\N	{}	Diagnostic casts are not a covered benefit.	\N	\N	\N	f	f	f	D.9.1
1158	aetna_dmo	D0601	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1159	humana_dpo	D0601	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1160	guardian_dpo	D0601	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1161	aetna_dmo	D0602	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1162	humana_dpo	D0602	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1163	guardian_dpo	D0602	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1164	aetna_dmo	D0603	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1165	humana_dpo	D0603	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1166	guardian_dpo	D0603	t	preventive	100.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1167	aetna_dmo	D1110	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1168	humana_dpo	D1110	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1169	guardian_dpo	D1110	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1170	aetna_dmo	D1120	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1171	humana_dpo	D1120	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1172	guardian_dpo	D1120	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1173	aetna_dmo	D1206	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1174	humana_dpo	D1206	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1175	guardian_dpo	D1206	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1176	aetna_dmo	D1208	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1177	humana_dpo	D1208	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1178	guardian_dpo	D1208	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1179	aetna_dmo	D1310	f	\N	0.00	\N	\N	\N	{}	Nutritional counselling is not a covered benefit.	\N	\N	\N	f	f	f	D.9.1
1180	humana_dpo	D1310	f	\N	0.00	\N	\N	\N	{}	Nutritional counselling is not a covered benefit.	\N	\N	\N	f	f	f	D.9.1
1181	guardian_dpo	D1310	f	\N	0.00	\N	\N	\N	{}	Nutritional counselling is not a covered benefit.	\N	\N	\N	f	f	f	D.9.1
1182	aetna_dmo	D1330	f	\N	0.00	\N	\N	\N	{}	Oral hygiene instruction is not a covered benefit.	\N	\N	\N	f	f	f	D.9.1
1183	humana_dpo	D1330	f	\N	0.00	\N	\N	\N	{}	Oral hygiene instruction is not a covered benefit.	\N	\N	\N	f	f	f	D.9.1
1184	guardian_dpo	D1330	f	\N	0.00	\N	\N	\N	{}	Oral hygiene instruction is not a covered benefit.	\N	\N	\N	f	f	f	D.9.1
1185	aetna_dmo	D1351	t	preventive	100.00	1	per_3_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.1.1
1186	humana_dpo	D1351	t	preventive	100.00	1	per_3_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.1.1
1187	guardian_dpo	D1351	t	preventive	100.00	1	per_3_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.1.1
1188	aetna_dmo	D1352	t	preventive	100.00	1	per_3_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.1.1
1189	humana_dpo	D1352	t	preventive	100.00	1	per_3_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.1.1
1190	guardian_dpo	D1352	t	preventive	100.00	1	per_3_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.1.1
1191	aetna_dmo	D1354	t	preventive	100.00	1	per_3_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.1.1
1192	humana_dpo	D1354	t	preventive	100.00	1	per_3_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.1.1
1193	guardian_dpo	D1354	t	preventive	100.00	1	per_3_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.1.1
1194	aetna_dmo	D1516	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1195	humana_dpo	D1516	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1196	guardian_dpo	D1516	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1197	aetna_dmo	D1517	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1198	humana_dpo	D1517	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1199	guardian_dpo	D1517	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1200	aetna_dmo	D2140	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
1201	humana_dpo	D2140	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
1202	guardian_dpo	D2140	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
1203	aetna_dmo	D2150	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
1204	humana_dpo	D2150	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
1205	guardian_dpo	D2150	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
1206	aetna_dmo	D2160	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
1207	humana_dpo	D2160	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
1208	guardian_dpo	D2160	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
1209	aetna_dmo	D2161	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
1210	humana_dpo	D2161	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
1211	guardian_dpo	D2161	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
1212	aetna_dmo	D2330	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
1213	humana_dpo	D2330	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
1214	guardian_dpo	D2330	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
1215	aetna_dmo	D2331	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
1216	humana_dpo	D2331	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
1217	guardian_dpo	D2331	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
1218	aetna_dmo	D2332	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
1219	humana_dpo	D2332	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
1220	guardian_dpo	D2332	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
1221	aetna_dmo	D2335	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
1222	humana_dpo	D2335	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
1223	guardian_dpo	D2335	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
1224	aetna_dmo	D2390	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
1225	humana_dpo	D2390	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
1226	guardian_dpo	D2390	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
1227	aetna_dmo	D2391	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
1228	humana_dpo	D2391	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
1229	guardian_dpo	D2391	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
1230	aetna_dmo	D2392	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
1231	humana_dpo	D2392	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
1232	guardian_dpo	D2392	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
1233	aetna_dmo	D2393	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
1234	humana_dpo	D2393	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
1235	guardian_dpo	D2393	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
1236	aetna_dmo	D2394	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
1237	humana_dpo	D2394	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
1238	guardian_dpo	D2394	t	basic	80.00	1	per_2_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
1239	aetna_dmo	D2510	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1240	humana_dpo	D2510	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1241	guardian_dpo	D2510	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1242	aetna_dmo	D2542	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1243	humana_dpo	D2542	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1244	guardian_dpo	D2542	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1245	aetna_dmo	D2610	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1246	humana_dpo	D2610	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	D2510	humana_dpo reimburses D2610 at the D2510 rate; the patient covers the difference.	f	t	t	D.4.1
1247	guardian_dpo	D2610	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	D2510	guardian_dpo reimburses D2610 at the D2510 rate; the patient covers the difference.	f	t	t	D.4.1
1248	aetna_dmo	D2642	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1249	humana_dpo	D2642	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	D2542	humana_dpo reimburses D2642 at the D2542 rate; the patient covers the difference.	f	t	t	D.4.1
1250	guardian_dpo	D2642	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	D2542	guardian_dpo reimburses D2642 at the D2542 rate; the patient covers the difference.	f	t	t	D.4.1
1251	aetna_dmo	D2710	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1252	humana_dpo	D2710	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1253	guardian_dpo	D2710	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1254	aetna_dmo	D2720	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1255	humana_dpo	D2720	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1256	guardian_dpo	D2720	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1257	aetna_dmo	D2721	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1258	humana_dpo	D2721	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1259	guardian_dpo	D2721	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1260	aetna_dmo	D2722	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1261	humana_dpo	D2722	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1262	guardian_dpo	D2722	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1263	aetna_dmo	D2740	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1264	humana_dpo	D2740	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	D2750	humana_dpo reimburses D2740 at the D2750 rate; the patient covers the difference.	f	t	t	D.4.1
1265	guardian_dpo	D2740	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	D2750	guardian_dpo reimburses D2740 at the D2750 rate; the patient covers the difference.	f	t	t	D.4.1
1266	aetna_dmo	D2750	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1267	humana_dpo	D2750	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1268	guardian_dpo	D2750	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1269	aetna_dmo	D2751	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1270	humana_dpo	D2751	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1271	guardian_dpo	D2751	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1272	aetna_dmo	D2752	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1273	humana_dpo	D2752	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1274	guardian_dpo	D2752	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1275	aetna_dmo	D2780	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1276	humana_dpo	D2780	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1277	guardian_dpo	D2780	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1278	aetna_dmo	D2781	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1279	humana_dpo	D2781	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1280	guardian_dpo	D2781	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1281	aetna_dmo	D2782	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1282	humana_dpo	D2782	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1283	guardian_dpo	D2782	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1284	aetna_dmo	D2790	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1285	humana_dpo	D2790	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1286	guardian_dpo	D2790	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1287	aetna_dmo	D2791	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1288	humana_dpo	D2791	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1289	guardian_dpo	D2791	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1290	aetna_dmo	D2792	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1291	humana_dpo	D2792	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1292	guardian_dpo	D2792	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1293	aetna_dmo	D2910	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1294	humana_dpo	D2910	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1295	guardian_dpo	D2910	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1296	aetna_dmo	D2920	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1297	humana_dpo	D2920	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1298	guardian_dpo	D2920	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1299	aetna_dmo	D2929	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1300	humana_dpo	D2929	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1301	guardian_dpo	D2929	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1302	aetna_dmo	D2930	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1303	humana_dpo	D2930	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1304	guardian_dpo	D2930	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1305	aetna_dmo	D2931	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1306	humana_dpo	D2931	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1307	guardian_dpo	D2931	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1308	aetna_dmo	D2940	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1309	humana_dpo	D2940	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1310	guardian_dpo	D2940	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1311	aetna_dmo	D2950	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.4.1
1312	humana_dpo	D2950	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.4.1
1313	guardian_dpo	D2950	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.4.1
1314	aetna_dmo	D2951	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.4.1
1315	humana_dpo	D2951	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.4.1
1316	guardian_dpo	D2951	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.4.1
1317	aetna_dmo	D2952	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.4.1
1318	humana_dpo	D2952	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.4.1
1319	guardian_dpo	D2952	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.4.1
1320	aetna_dmo	D2954	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.4.1
1321	humana_dpo	D2954	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.4.1
1322	guardian_dpo	D2954	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.4.1
1323	aetna_dmo	D3110	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1324	humana_dpo	D3110	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1325	guardian_dpo	D3110	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1326	aetna_dmo	D3120	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1327	humana_dpo	D3120	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1328	guardian_dpo	D3120	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1329	aetna_dmo	D3220	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1330	humana_dpo	D3220	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1331	guardian_dpo	D3220	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1332	aetna_dmo	D3221	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1333	humana_dpo	D3221	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1334	guardian_dpo	D3221	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1335	aetna_dmo	D3310	t	basic	80.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	f	t	D.3.1
1336	humana_dpo	D3310	t	basic	80.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	f	t	D.3.1
1337	guardian_dpo	D3310	t	basic	80.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	f	t	D.3.1
1338	aetna_dmo	D3320	t	basic	80.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	f	t	D.3.1
1339	humana_dpo	D3320	t	basic	80.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	f	t	D.3.1
1340	guardian_dpo	D3320	t	basic	80.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	f	t	D.3.1
1341	aetna_dmo	D3330	t	basic	80.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	f	t	D.3.1
1342	humana_dpo	D3330	t	basic	80.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	f	t	D.3.1
1343	guardian_dpo	D3330	t	basic	80.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	f	t	D.3.1
1344	aetna_dmo	D3346	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1345	humana_dpo	D3346	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1346	guardian_dpo	D3346	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1347	aetna_dmo	D3347	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1348	humana_dpo	D3347	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1349	guardian_dpo	D3347	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1350	aetna_dmo	D3348	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1351	humana_dpo	D3348	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1352	guardian_dpo	D3348	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1353	aetna_dmo	D3410	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1354	humana_dpo	D3410	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1355	guardian_dpo	D3410	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1356	aetna_dmo	D3421	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1357	humana_dpo	D3421	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1358	guardian_dpo	D3421	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1359	aetna_dmo	D3425	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1360	humana_dpo	D3425	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1361	guardian_dpo	D3425	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1362	aetna_dmo	D3430	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1363	humana_dpo	D3430	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1364	guardian_dpo	D3430	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1365	aetna_dmo	D4210	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
1366	humana_dpo	D4210	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
1367	guardian_dpo	D4210	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
1368	aetna_dmo	D4211	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
1369	humana_dpo	D4211	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
1370	guardian_dpo	D4211	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
1371	aetna_dmo	D4240	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
1372	humana_dpo	D4240	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
1373	guardian_dpo	D4240	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
1374	aetna_dmo	D4241	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
1375	humana_dpo	D4241	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
1376	guardian_dpo	D4241	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
1377	aetna_dmo	D4249	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
1378	humana_dpo	D4249	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
1379	guardian_dpo	D4249	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
1380	aetna_dmo	D4260	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
1381	humana_dpo	D4260	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
1382	guardian_dpo	D4260	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
1383	aetna_dmo	D4261	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
1384	humana_dpo	D4261	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
1385	guardian_dpo	D4261	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
1386	aetna_dmo	D4263	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
1387	humana_dpo	D4263	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
1388	guardian_dpo	D4263	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
1389	aetna_dmo	D4264	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
1390	humana_dpo	D4264	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
1391	guardian_dpo	D4264	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
1392	aetna_dmo	D4266	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
1393	humana_dpo	D4266	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
1394	guardian_dpo	D4266	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
1395	aetna_dmo	D4270	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
1396	humana_dpo	D4270	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
1397	guardian_dpo	D4270	t	major	50.00	1	per_3_years	per_quadrant	{}	\N	\N	\N	\N	f	t	t	D.4.1
1398	aetna_dmo	D4341	t	basic	80.00	4	per_year	per_quadrant	{}	\N	\N	\N	\N	f	f	t	D.3.1
1399	humana_dpo	D4341	t	basic	80.00	4	per_year	per_quadrant	{}	\N	\N	\N	\N	f	f	t	D.3.1
1400	guardian_dpo	D4341	t	basic	80.00	4	per_year	per_quadrant	{}	\N	\N	\N	\N	f	f	t	D.3.1
1401	aetna_dmo	D4342	t	basic	80.00	4	per_year	per_quadrant	{}	\N	\N	\N	\N	f	f	t	D.3.1
1402	humana_dpo	D4342	t	basic	80.00	4	per_year	per_quadrant	{}	\N	\N	\N	\N	f	f	t	D.3.1
1403	guardian_dpo	D4342	t	basic	80.00	4	per_year	per_quadrant	{}	\N	\N	\N	\N	f	f	t	D.3.1
1404	aetna_dmo	D4346	t	basic	80.00	4	per_year	per_quadrant	{}	\N	\N	\N	\N	f	f	t	D.3.1
1405	humana_dpo	D4346	t	basic	80.00	4	per_year	per_quadrant	{}	\N	\N	\N	\N	f	f	t	D.3.1
1406	guardian_dpo	D4346	t	basic	80.00	4	per_year	per_quadrant	{}	\N	\N	\N	\N	f	f	t	D.3.1
1407	aetna_dmo	D4355	t	basic	80.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	f	f	D.3.1
1408	humana_dpo	D4355	t	basic	80.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	f	f	D.3.1
1409	guardian_dpo	D4355	t	basic	80.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	f	f	D.3.1
1410	aetna_dmo	D4381	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1411	humana_dpo	D4381	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1412	guardian_dpo	D4381	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1413	aetna_dmo	D4910	t	basic	80.00	4	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.3.1
1414	humana_dpo	D4910	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1415	guardian_dpo	D4910	t	preventive	100.00	2	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.1.1
1416	aetna_dmo	D5110	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
1417	humana_dpo	D5110	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
1418	guardian_dpo	D5110	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
1419	aetna_dmo	D5120	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
1420	humana_dpo	D5120	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
1421	guardian_dpo	D5120	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
1422	aetna_dmo	D5130	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
1423	humana_dpo	D5130	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
1424	guardian_dpo	D5130	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
1425	aetna_dmo	D5140	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
1426	humana_dpo	D5140	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
1427	guardian_dpo	D5140	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
1428	aetna_dmo	D5211	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
1429	humana_dpo	D5211	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
1430	guardian_dpo	D5211	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
1431	aetna_dmo	D5212	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
1432	humana_dpo	D5212	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
1433	guardian_dpo	D5212	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
1434	aetna_dmo	D5213	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
1435	humana_dpo	D5213	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
1436	guardian_dpo	D5213	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
1437	aetna_dmo	D5214	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
1438	humana_dpo	D5214	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
1439	guardian_dpo	D5214	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
1440	aetna_dmo	D5410	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
1441	humana_dpo	D5410	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
1442	guardian_dpo	D5410	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
1443	aetna_dmo	D5510	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
1444	humana_dpo	D5510	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
1445	guardian_dpo	D5510	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
1446	aetna_dmo	D5750	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
1447	humana_dpo	D5750	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
1448	guardian_dpo	D5750	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
1449	aetna_dmo	D5751	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
1450	humana_dpo	D5751	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
1451	guardian_dpo	D5751	t	major	50.00	1	per_5_years	per_arch	{}	\N	\N	\N	\N	f	t	t	D.4.1
1452	aetna_dmo	D6010	f	implant	0.00	\N	\N	\N	{}	Aetna DMO carries no implant benefit â€” the patient is responsible for the full amount. A plan exclusion is not an appealable determination.	\N	\N	\N	f	f	f	D.7.1
1453	humana_dpo	D6010	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.7.1
1454	guardian_dpo	D6010	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
1455	aetna_dmo	D6011	f	implant	0.00	\N	\N	\N	{}	Aetna DMO carries no implant benefit â€” the patient is responsible for the full amount. A plan exclusion is not an appealable determination.	\N	\N	\N	f	f	f	D.7.1
1456	humana_dpo	D6011	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.7.1
1457	guardian_dpo	D6011	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
1458	aetna_dmo	D6012	f	implant	0.00	\N	\N	\N	{}	Aetna DMO carries no implant benefit â€” the patient is responsible for the full amount. A plan exclusion is not an appealable determination.	\N	\N	\N	f	f	f	D.7.1
1459	humana_dpo	D6012	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.7.1
1460	guardian_dpo	D6012	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
1461	aetna_dmo	D6013	f	implant	0.00	\N	\N	\N	{}	Aetna DMO carries no implant benefit â€” the patient is responsible for the full amount. A plan exclusion is not an appealable determination.	\N	\N	\N	f	f	f	D.7.1
1462	humana_dpo	D6013	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.7.1
1463	guardian_dpo	D6013	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
1575	aetna_dmo	D8030	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
1464	aetna_dmo	D6040	f	implant	0.00	\N	\N	\N	{}	Aetna DMO carries no implant benefit â€” the patient is responsible for the full amount. A plan exclusion is not an appealable determination.	\N	\N	\N	f	f	f	D.7.1
1465	humana_dpo	D6040	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.7.1
1466	guardian_dpo	D6040	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
1467	aetna_dmo	D6050	f	implant	0.00	\N	\N	\N	{}	Aetna DMO carries no implant benefit â€” the patient is responsible for the full amount. A plan exclusion is not an appealable determination.	\N	\N	\N	f	f	f	D.7.1
1468	humana_dpo	D6050	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.7.1
1469	guardian_dpo	D6050	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
1470	aetna_dmo	D6055	f	implant	0.00	\N	\N	\N	{}	Aetna DMO carries no implant benefit â€” the patient is responsible for the full amount. A plan exclusion is not an appealable determination.	\N	\N	\N	f	f	f	D.7.1
1471	humana_dpo	D6055	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.7.1
1472	guardian_dpo	D6055	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
1473	aetna_dmo	D6056	f	implant	0.00	\N	\N	\N	{}	Aetna DMO carries no implant benefit â€” the patient is responsible for the full amount. A plan exclusion is not an appealable determination.	\N	\N	\N	f	f	f	D.7.1
1474	humana_dpo	D6056	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.7.1
1475	guardian_dpo	D6056	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
1476	aetna_dmo	D6057	f	implant	0.00	\N	\N	\N	{}	Aetna DMO carries no implant benefit â€” the patient is responsible for the full amount. A plan exclusion is not an appealable determination.	\N	\N	\N	f	f	f	D.7.1
1477	humana_dpo	D6057	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.7.1
1478	guardian_dpo	D6057	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
1479	aetna_dmo	D6058	f	implant	0.00	\N	\N	\N	{}	Aetna DMO carries no implant benefit â€” the patient is responsible for the full amount. A plan exclusion is not an appealable determination.	\N	\N	\N	f	f	f	D.7.1
1480	humana_dpo	D6058	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	D2750	humana_dpo reimburses D6058 at the D2750 rate; the patient covers the difference.	f	t	t	D.7.1
1481	guardian_dpo	D6058	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	D2750	guardian_dpo reimburses D6058 at the D2750 rate; the patient covers the difference.	t	t	t	D.7.1
1482	aetna_dmo	D6059	f	implant	0.00	\N	\N	\N	{}	Aetna DMO carries no implant benefit â€” the patient is responsible for the full amount. A plan exclusion is not an appealable determination.	\N	\N	\N	f	f	f	D.7.1
1483	humana_dpo	D6059	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.7.1
1484	guardian_dpo	D6059	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
1485	aetna_dmo	D6065	f	implant	0.00	\N	\N	\N	{}	Aetna DMO carries no implant benefit â€” the patient is responsible for the full amount. A plan exclusion is not an appealable determination.	\N	\N	\N	f	f	f	D.7.1
1486	humana_dpo	D6065	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	D2750	humana_dpo reimburses D6065 at the D2750 rate; the patient covers the difference.	f	t	t	D.7.1
1487	guardian_dpo	D6065	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	D2750	guardian_dpo reimburses D6065 at the D2750 rate; the patient covers the difference.	t	t	t	D.7.1
1488	aetna_dmo	D6066	f	implant	0.00	\N	\N	\N	{}	Aetna DMO carries no implant benefit â€” the patient is responsible for the full amount. A plan exclusion is not an appealable determination.	\N	\N	\N	f	f	f	D.7.1
1489	humana_dpo	D6066	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	D2750	humana_dpo reimburses D6066 at the D2750 rate; the patient covers the difference.	f	t	t	D.7.1
1490	guardian_dpo	D6066	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	D2750	guardian_dpo reimburses D6066 at the D2750 rate; the patient covers the difference.	t	t	t	D.7.1
1491	aetna_dmo	D6067	f	implant	0.00	\N	\N	\N	{}	Aetna DMO carries no implant benefit â€” the patient is responsible for the full amount. A plan exclusion is not an appealable determination.	\N	\N	\N	f	f	f	D.7.1
1492	humana_dpo	D6067	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.7.1
1493	guardian_dpo	D6067	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
1494	aetna_dmo	D6080	f	implant	0.00	\N	\N	\N	{}	Aetna DMO carries no implant benefit â€” the patient is responsible for the full amount. A plan exclusion is not an appealable determination.	\N	\N	\N	f	f	f	D.7.1
1495	humana_dpo	D6080	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.7.1
1496	guardian_dpo	D6080	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
1497	aetna_dmo	D6104	f	implant	0.00	\N	\N	\N	{}	Aetna DMO carries no implant benefit â€” the patient is responsible for the full amount. A plan exclusion is not an appealable determination.	\N	\N	\N	f	f	f	D.7.1
1498	humana_dpo	D6104	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.7.1
1499	guardian_dpo	D6104	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
1500	aetna_dmo	D6190	f	implant	0.00	\N	\N	\N	{}	Aetna DMO carries no implant benefit â€” the patient is responsible for the full amount. A plan exclusion is not an appealable determination.	\N	\N	\N	f	f	f	D.7.1
1501	humana_dpo	D6190	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.7.1
1502	guardian_dpo	D6190	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
1503	aetna_dmo	D6210	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1504	humana_dpo	D6210	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1505	guardian_dpo	D6210	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1506	aetna_dmo	D6240	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1507	humana_dpo	D6240	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1508	guardian_dpo	D6240	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1509	aetna_dmo	D6245	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1576	humana_dpo	D8030	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
1510	humana_dpo	D6245	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	D6240	humana_dpo reimburses D6245 at the D6240 rate; the patient covers the difference.	f	t	t	D.4.1
1511	guardian_dpo	D6245	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	D6240	guardian_dpo reimburses D6245 at the D6240 rate; the patient covers the difference.	f	t	t	D.4.1
1512	aetna_dmo	D6740	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1513	humana_dpo	D6740	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	D6750	humana_dpo reimburses D6740 at the D6750 rate; the patient covers the difference.	f	t	t	D.4.1
1514	guardian_dpo	D6740	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	D6750	guardian_dpo reimburses D6740 at the D6750 rate; the patient covers the difference.	f	t	t	D.4.1
1515	aetna_dmo	D6750	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1516	humana_dpo	D6750	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1517	guardian_dpo	D6750	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1518	aetna_dmo	D6930	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1519	humana_dpo	D6930	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1520	guardian_dpo	D6930	t	major	50.00	1	per_5_years	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1521	aetna_dmo	D7111	t	basic	80.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
1522	humana_dpo	D7111	t	basic	80.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
1523	guardian_dpo	D7111	t	basic	80.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
1524	aetna_dmo	D7140	t	basic	80.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
1525	humana_dpo	D7140	t	basic	80.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
1526	guardian_dpo	D7140	t	basic	80.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	f	f	D.3.1
1527	aetna_dmo	D7210	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1528	humana_dpo	D7210	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1529	guardian_dpo	D7210	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1530	aetna_dmo	D7220	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1531	humana_dpo	D7220	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1532	guardian_dpo	D7220	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1533	aetna_dmo	D7230	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1534	humana_dpo	D7230	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1535	guardian_dpo	D7230	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1536	aetna_dmo	D7240	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1537	humana_dpo	D7240	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1538	guardian_dpo	D7240	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1539	aetna_dmo	D7241	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1540	humana_dpo	D7241	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1541	guardian_dpo	D7241	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1542	aetna_dmo	D7250	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1543	humana_dpo	D7250	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1544	guardian_dpo	D7250	t	major	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.4.1
1545	aetna_dmo	D7280	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	t	t	D.4.1
1546	humana_dpo	D7280	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	t	t	D.4.1
1547	guardian_dpo	D7280	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	t	t	D.4.1
1548	aetna_dmo	D7285	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	t	D.4.1
1549	humana_dpo	D7285	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	t	D.4.1
1550	guardian_dpo	D7285	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	t	D.4.1
1551	aetna_dmo	D7286	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	t	D.4.1
1552	humana_dpo	D7286	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	t	D.4.1
1553	guardian_dpo	D7286	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	t	D.4.1
1554	aetna_dmo	D7310	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	t	t	D.4.1
1555	humana_dpo	D7310	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	t	t	D.4.1
1556	guardian_dpo	D7310	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	t	t	D.4.1
1557	aetna_dmo	D7320	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	t	t	D.4.1
1558	humana_dpo	D7320	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	t	t	D.4.1
1559	guardian_dpo	D7320	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	t	t	D.4.1
1560	aetna_dmo	D7510	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1561	humana_dpo	D7510	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1562	guardian_dpo	D7510	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1563	aetna_dmo	D7953	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
1564	humana_dpo	D7953	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	f	t	t	D.7.1
1565	guardian_dpo	D7953	t	implant	50.00	1	per_lifetime	per_tooth	{}	\N	\N	\N	\N	t	t	t	D.7.1
1566	aetna_dmo	D7960	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	t	t	D.4.1
1567	humana_dpo	D7960	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	t	t	D.4.1
1568	guardian_dpo	D7960	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	t	t	D.4.1
1569	aetna_dmo	D8010	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
1570	humana_dpo	D8010	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
1571	guardian_dpo	D8010	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
1572	aetna_dmo	D8020	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
1573	humana_dpo	D8020	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
1574	guardian_dpo	D8020	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
1577	guardian_dpo	D8030	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
1578	aetna_dmo	D8040	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
1579	humana_dpo	D8040	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
1580	guardian_dpo	D8040	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
1581	aetna_dmo	D8070	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
1582	humana_dpo	D8070	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
1583	guardian_dpo	D8070	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
1584	aetna_dmo	D8080	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
1585	humana_dpo	D8080	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
1586	guardian_dpo	D8080	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
1587	aetna_dmo	D8090	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
1588	humana_dpo	D8090	f	major	0.00	\N	\N	\N	{}	Comprehensive orthodontic treatment for adult dentition is not covered under the Humana standard plan. Child and adolescent orthodontics (D8080) remain covered.	\N	\N	\N	f	f	f	D.9.1
1589	guardian_dpo	D8090	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
1590	aetna_dmo	D8210	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
1591	humana_dpo	D8210	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
1592	guardian_dpo	D8210	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
1593	aetna_dmo	D8220	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
1594	humana_dpo	D8220	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
1595	guardian_dpo	D8220	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
1596	aetna_dmo	D8670	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
1597	humana_dpo	D8670	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
1598	guardian_dpo	D8670	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
1599	aetna_dmo	D8680	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
1600	humana_dpo	D8680	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
1601	guardian_dpo	D8680	t	major	50.00	1	per_lifetime	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
1602	aetna_dmo	D9110	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1603	humana_dpo	D9110	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1604	guardian_dpo	D9110	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1605	aetna_dmo	D9210	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1606	humana_dpo	D9210	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1607	guardian_dpo	D9210	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1608	aetna_dmo	D9215	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1609	humana_dpo	D9215	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1610	guardian_dpo	D9215	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1611	aetna_dmo	D9220	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	t	t	D.4.1
1612	humana_dpo	D9220	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	t	t	D.4.1
1613	guardian_dpo	D9220	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	t	t	D.4.1
1614	aetna_dmo	D9223	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	t	t	D.4.1
1615	humana_dpo	D9223	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	t	t	D.4.1
1616	guardian_dpo	D9223	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	t	t	D.4.1
1617	aetna_dmo	D9230	f	\N	0.00	\N	\N	\N	{}	Nitrous oxide is not a covered benefit; patient pays out of pocket.	\N	\N	\N	f	f	f	D.9.1
1618	humana_dpo	D9230	f	\N	0.00	\N	\N	\N	{}	Nitrous oxide is not a covered benefit; patient pays out of pocket.	\N	\N	\N	f	f	f	D.9.1
1619	guardian_dpo	D9230	f	\N	0.00	\N	\N	\N	{}	Nitrous oxide is not a covered benefit; patient pays out of pocket.	\N	\N	\N	f	f	f	D.9.1
1620	aetna_dmo	D9239	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	t	t	D.4.1
1621	humana_dpo	D9239	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	t	t	D.4.1
1622	guardian_dpo	D9239	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	t	t	D.4.1
1623	aetna_dmo	D9243	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	t	t	D.4.1
1624	humana_dpo	D9243	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	t	t	D.4.1
1625	guardian_dpo	D9243	t	major	50.00	\N	\N	\N	{}	\N	\N	\N	\N	f	t	t	D.4.1
1626	aetna_dmo	D9310	t	basic	80.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.3.1
1627	humana_dpo	D9310	t	basic	80.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.3.1
1628	guardian_dpo	D9310	t	basic	80.00	1	per_year	per_patient	{}	\N	\N	\N	\N	f	f	f	D.3.1
1629	aetna_dmo	D9430	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1630	humana_dpo	D9430	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1631	guardian_dpo	D9430	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1632	aetna_dmo	D9440	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1633	humana_dpo	D9440	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1634	guardian_dpo	D9440	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1635	aetna_dmo	D9944	t	major	50.00	1	per_5_years	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
1636	humana_dpo	D9944	t	major	50.00	1	per_5_years	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
1637	guardian_dpo	D9944	t	major	50.00	1	per_5_years	per_patient	{}	\N	\N	\N	\N	f	t	t	D.4.1
1638	aetna_dmo	D9951	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1639	humana_dpo	D9951	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1640	guardian_dpo	D9951	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1641	aetna_dmo	D9995	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1642	humana_dpo	D9995	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
1643	guardian_dpo	D9995	t	basic	80.00	\N	\N	\N	{}	\N	\N	\N	\N	f	f	f	D.3.1
\.


--
-- Data for Name: downgrade_matrix; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.downgrade_matrix (downgrade_id, payer_id, plan_type, billed_cdt_code, paid_cdt_code, tooth_position, downgrade_reason, patient_choice_allowed, policy_section, effective_date, created_at) FROM stdin;
7c02c9b9-51f8-4ee2-8c9c-b4bcbe36c913	delta_dental	PPO	D2740	D2750	posterior	All-ceramic crown reimbursed at PFM rate on posterior teeth	t	D.4.2	2026-01-01	2026-08-04 18:07:58.522927+00
f478321b-15e1-492b-8b94-517bda54c377	delta_dental	PPO	D2390	D2150	\N	Posterior composite reimbursed at amalgam rate	t	D.4.6	2026-01-01	2026-08-04 18:07:58.548963+00
19e34034-d7ab-4c51-9935-f3eda6739f88	delta_dental	PPO	D6065	D2750	\N	Implant crown reimbursed at conventional crown rate	t	D.7.2	2026-01-01	2026-08-04 18:07:58.570227+00
0c54e5e2-6a20-49ad-b110-bae581f825ad	delta_dental	PPO	D6066	D2750	\N	Implant crown (ceramic) reimbursed at PFM rate	t	D.7.3	2026-01-01	2026-08-04 18:07:58.627249+00
8ca8ea59-8b25-4fa7-828b-0f4bf391ebdb	delta_dental	PPO	D6067	D2750	\N	Implant crown (metal) reimbursed at PFM rate	t	D.7.3	2026-01-01	2026-08-04 18:07:58.65023+00
8e8dbc4f-6730-4985-8507-3aa26cc3f6c9	cigna	DPPO	D2390	D2150	\N	Posterior composite reimbursed at amalgam rate	t	CIGNA-DENT-4.6	2026-01-01	2026-08-04 18:07:58.671767+00
08c32456-03c0-420d-8185-09fcbc3ec51f	cigna	DPPO	D6065	D2750	\N	Implant crown reimbursed at conventional crown rate	t	CIGNA-DENT-7.2	2026-01-01	2026-08-04 18:07:58.696785+00
58179a7b-3c87-4249-8af5-b9aed754eac1	metlife	PDP	D2740	D2750	posterior	All-ceramic crown reimbursed at PFM rate on posterior teeth	t	ML-PDP-4.2	2026-01-01	2026-08-04 18:07:58.717712+00
62e85cec-8455-4c33-b2a2-6088f69fcd09	metlife	PDP	D6065	D2750	\N	Implant crown reimbursed at conventional crown rate	t	ML-PDP-7.2	2026-01-01	2026-08-04 18:07:58.739226+00
\.


--
-- Data for Name: eligibility_profiles; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.eligibility_profiles (pred_request_id, tenant_id, coverage_active, plan_type, annual_maximum, annual_maximum_used, annual_maximum_remaining, deductible_total, deductible_met, deductible_remaining, benefit_pct_preventive, benefit_pct_basic, benefit_pct_major, benefit_pct_implants, implant_coverage, ortho_coverage, waiting_period_met, missing_tooth_clause, missing_tooth_clause_confirmed, coordination_of_benefits, member_id, group_number, payer_id, enrollment_date, pred_required_codes, source, confidence, verified_at, assembled_at, conflicts) FROM stdin;
PRED-SIM-DA-U01	suwanee_smiles	t	PPO	2000.00	200.00	1800.00	100.00	50.00	50.00	100.00	80.00	50.00	0.00	f	f	t	t	f	f	DDL-201455-T	GRP-44821	delta_dental	2019-01-01	[]	x12_271	0.970	2026-08-06T05:18:41.317658+00:00	2026-08-06T05:18:41.317658	[]
PRED-SIM-DA-U02	suwanee_smiles	t	PPO	2000.00	200.00	1800.00	100.00	50.00	50.00	100.00	80.00	50.00	0.00	f	f	t	t	f	f	DDL-334709-S	GRP-44821	delta_dental	2019-01-01	[]	x12_271	0.970	2026-08-06T05:18:42.873753+00:00	2026-08-06T05:18:42.873753	[]
PRED-SIM-DA-U03	suwanee_smiles	t	DPPO	2000.00	200.00	1800.00	100.00	50.00	50.00	100.00	80.00	50.00	0.00	f	f	t	t	f	f	CIG-889302-L	GRP-CIG-01	cigna	2019-01-01	[]	x12_271	0.970	2026-08-06T05:18:44.394700+00:00	2026-08-06T05:18:44.394700	[]
PRED-SIM-DA-U04	suwanee_smiles	t	PDP	2000.00	200.00	1800.00	100.00	50.00	50.00	100.00	80.00	50.00	0.00	f	f	t	t	f	f	MET-556128-C	GRP-MET-04	metlife	2018-01-01	[]	x12_271	0.970	2026-08-06T05:18:45.671185+00:00	2026-08-06T05:18:45.671185	[]
PRED-SIM-DA-U05	suwanee_smiles	t	PPO	2000.00	200.00	1800.00	100.00	50.00	50.00	100.00	80.00	50.00	0.00	f	f	t	t	f	f	DDL-447215-W	GRP-44821	delta_dental	2017-01-01	[]	x12_271	0.970	2026-08-06T05:18:46.944019+00:00	2026-08-06T05:18:46.944019	[]
PRED-SIM-TB-A01	tampa_smiles	t	DPPO	1500.00	0.00	1500.00	50.00	50.00	0.00	100.00	80.00	50.00	50.00	t	f	t	f	f	f	HUM-771204-C	GRP-HUM-11	humana_dpo	2021-01-01	["D2750"]	x12_271	0.970	2026-08-06T13:35:17.794770+00:00	2026-08-06T13:35:17.794770	[]
PRED-SIM-TB-B01	tampa_smiles	t	DMO	1500.00	0.00	1500.00	0.00	0.00	0.00	100.00	80.00	50.00	0.00	f	f	t	t	f	f	AET-330918-M	GRP-AET-02	aetna_dmo	2020-01-01	["D6010"]	x12_271	0.970	2026-08-06T13:35:19.528044+00:00	2026-08-06T13:35:19.528044	[]
PRED-SIM-TB-C01	tampa_smiles	t	DPPO	2000.00	200.00	1800.00	100.00	50.00	50.00	100.00	80.00	50.00	50.00	t	f	t	t	f	f	GRD-618470-T	GRP-GRD-07	guardian_dpo	2019-01-01	[]	x12_271	0.970	2026-08-06T13:35:21.110657+00:00	2026-08-06T13:35:21.110657	[]
PRED-SIM-TB-D01	tampa_smiles	t	DMO	1500.00	0.00	1500.00	0.00	0.00	0.00	100.00	80.00	50.00	0.00	f	f	t	t	f	f	AET-905513-P	GRP-AET-02	aetna_dmo	2018-01-01	["D2740"]	x12_271	0.970	2026-08-06T13:35:22.524103+00:00	2026-08-06T13:35:22.524103	[]
PRED-SIM-TB-U01	tampa_smiles	t	DPPO	1500.00	0.00	1500.00	50.00	50.00	0.00	100.00	80.00	50.00	50.00	t	f	t	f	f	f	HUM-224806-A	GRP-HUM-11	humana_dpo	2022-01-01	[]	x12_271	0.970	2026-08-06T13:35:24.152773+00:00	2026-08-06T13:35:24.152773	[]
PRED-SIM-DL-A01	dallas_dental	t	DPPO	2000.00	200.00	1800.00	100.00	50.00	50.00	100.00	80.00	50.00	50.00	t	f	t	t	f	f	GRD-140725-J	GRP-GRD-07	guardian_dpo	2019-01-01	["D6010", "D6065"]	x12_271	0.970	2026-08-06T13:35:54.537826+00:00	2026-08-06T13:35:54.537826	[]
PRED-SIM-DL-B01	dallas_dental	t	DPPO	2000.00	200.00	1800.00	100.00	50.00	50.00	100.00	80.00	50.00	50.00	t	f	t	t	f	f	GRD-573091-L	GRP-GRD-07	guardian_dpo	2017-01-01	["D4260"]	x12_271	0.970	2026-08-06T13:35:56.124237+00:00	2026-08-06T13:35:56.124237	[]
PRED-SIM-DL-C01	dallas_dental	t	PPO	2000.00	200.00	1800.00	100.00	50.00	50.00	100.00	80.00	50.00	0.00	f	f	t	t	f	f	DDL-668204-W	GRP-44821	delta_dental	2016-01-01	["D2750"]	x12_271	0.970	2026-08-06T13:35:57.764656+00:00	2026-08-06T13:35:57.764656	[]
PRED-SIM-DL-D01	dallas_dental	t	DPPO	1500.00	0.00	1500.00	50.00	50.00	0.00	100.00	80.00	50.00	50.00	t	f	t	f	f	f	HUM-482260-G	GRP-HUM-11	humana_dpo	2020-01-01	["D8090"]	x12_271	0.970	2026-08-06T13:35:59.663639+00:00	2026-08-06T13:35:59.663639	[]
PRED-SIM-DL-U01	dallas_dental	t	DPPO	2000.00	200.00	1800.00	100.00	50.00	50.00	100.00	80.00	50.00	50.00	t	f	t	t	f	f	GRD-836142-B	GRP-GRD-07	guardian_dpo	2021-01-01	[]	x12_271	0.970	2026-08-06T13:36:01.310800+00:00	2026-08-06T13:36:01.310800	[]
PRED-SIM-DA-A01	suwanee_smiles	t	PPO	2000.00	200.00	1800.00	100.00	50.00	50.00	100.00	80.00	50.00	50.00	t	f	t	t	f	f	DDL-842901-M	GRP-44821	delta_dental	2020-01-01	["D6010", "D7953", "D6065"]	x12_271	0.970	2026-08-05T16:18:00.474768+00:00	2026-08-05T16:18:00.474768	[]
PRED-SIM-DA-A02	suwanee_smiles	t	PPO	2000.00	200.00	1800.00	100.00	50.00	50.00	100.00	80.00	50.00	0.00	f	f	t	t	f	f	DDL-531024-W	GRP-44821	delta_dental	2019-03-01	["D2750"]	x12_271	0.970	2026-08-05T16:18:02.565965+00:00	2026-08-05T16:18:02.565965	[]
PRED-SIM-DA-A03	suwanee_smiles	t	PPO	2000.00	200.00	1800.00	50.00	50.00	0.00	100.00	80.00	50.00	0.00	f	f	t	t	f	f	DDL-729384-C	GRP-77103	delta_dental	2021-06-01	["D2750"]	x12_271	0.970	2026-08-05T16:18:04.044097+00:00	2026-08-05T16:18:04.044097	[]
PRED-SIM-DA-A04	suwanee_smiles	t	PPO	2000.00	200.00	1800.00	100.00	50.00	50.00	100.00	80.00	50.00	0.00	f	f	t	t	f	f	DDL-482019-R	GRP-55290	delta_dental	2022-01-01	[]	x12_271	0.970	2026-08-05T16:18:05.508836+00:00	2026-08-05T16:18:05.508836	[]
PRED-SIM-DA-A05	suwanee_smiles	t	PPO	2000.00	200.00	1800.00	0.00	0.00	0.00	100.00	80.00	50.00	0.00	f	f	t	t	f	f	DDL-901234-P	GRP-44821	delta_dental	2020-09-01	[]	x12_271	0.970	2026-08-05T16:18:06.902083+00:00	2026-08-05T16:18:06.902083	[]
PRED-SIM-DA-B01	suwanee_smiles	t	PPO	1500.00	0.00	1500.00	50.00	50.00	0.00	100.00	80.00	50.00	0.00	f	f	t	t	f	f	DDL-334891-J	GRP-BASIC-01	delta_dental	2024-01-01	["D6010", "D6065"]	x12_271	0.970	2026-08-05T16:18:08.057502+00:00	2026-08-05T16:18:08.057502	[]
PRED-SIM-DA-B03	suwanee_smiles	t	PPO	2000.00	200.00	1800.00	100.00	50.00	50.00	100.00	80.00	50.00	0.00	f	f	t	t	f	f	DDL-223847-H	GRP-77103	delta_dental	2018-01-01	["D2750"]	x12_271	0.970	2026-08-05T16:18:10.947658+00:00	2026-08-05T16:18:10.947658	[]
PRED-SIM-DA-B04	suwanee_smiles	t	PPO	2000.00	200.00	1800.00	100.00	50.00	50.00	100.00	80.00	50.00	50.00	t	f	t	t	f	f	DDL-558934-R	GRP-44821	delta_dental	2021-01-01	["D6010", "D7953"]	x12_271	0.970	2026-08-05T16:18:12.575516+00:00	2026-08-05T16:18:12.575516	[]
PRED-SIM-DA-B05	suwanee_smiles	t	PPO	2000.00	200.00	1800.00	100.00	50.00	50.00	100.00	80.00	50.00	0.00	f	f	f	t	f	f	DDL-112983-T	GRP-NEW-2025	delta_dental	2025-12-04	["D2750"]	x12_271	0.970	2026-08-05T16:18:14.018787+00:00	2026-08-05T16:18:14.018787	[]
PRED-SIM-DA-C01	suwanee_smiles	t	PPO	2000.00	200.00	1800.00	100.00	50.00	50.00	100.00	80.00	50.00	50.00	t	f	t	t	f	f	DDL-610455-K	GRP-44821	delta_dental	2020-01-01	["D6010", "D7953"]	x12_271	0.970	2026-08-05T16:18:15.445959+00:00	2026-08-05T16:18:15.445959	[]
PRED-SIM-DA-C02	suwanee_smiles	t	PPO	2000.00	200.00	1800.00	100.00	50.00	50.00	100.00	80.00	50.00	0.00	f	f	t	t	f	f	DDL-482277-S	GRP-77103	delta_dental	2019-05-01	["D4260"]	x12_271	0.970	2026-08-05T16:18:16.772839+00:00	2026-08-05T16:18:16.772839	[]
PRED-SIM-DA-C03	suwanee_smiles	t	PPO	2000.00	200.00	1800.00	100.00	50.00	50.00	100.00	80.00	50.00	50.00	t	f	t	t	f	f	DDL-773901-F	GRP-44821	delta_dental	2018-01-01	["D6010", "D6010", "D6010", "D6010", "D6065", "D6065", "D6065", "D6065"]	x12_271	0.970	2026-08-05T16:18:18.433862+00:00	2026-08-05T16:18:18.433862	[]
PRED-SIM-DA-C04	suwanee_smiles	t	PPO	2000.00	200.00	1800.00	100.00	50.00	50.00	100.00	80.00	50.00	0.00	f	f	t	t	f	f	DDL-559120-W	GRP-77103	delta_dental	2021-02-01	["D2750"]	x12_271	0.970	2026-08-05T16:18:19.894443+00:00	2026-08-05T16:18:19.894443	[]
PRED-SIM-DA-C05	suwanee_smiles	t	PPO	2000.00	200.00	1800.00	100.00	50.00	50.00	100.00	80.00	50.00	0.00	f	f	t	t	f	t	DDL-902314-P	GRP-55290	delta_dental	2020-03-01	["D2750"]	x12_271	0.970	2026-08-05T16:18:21.157963+00:00	2026-08-05T16:18:21.157963	[]
PRED-SIM-DA-D01	suwanee_smiles	t	PPO	2000.00	200.00	1800.00	100.00	50.00	50.00	100.00	80.00	50.00	50.00	t	f	t	t	f	f	DDL-338847-C	GRP-44821	delta_dental	2019-01-01	["D4260", "D6010", "D7953"]	x12_271	0.970	2026-08-05T16:18:23.326469+00:00	2026-08-05T16:18:23.326827	[]
PRED-SIM-DA-D02	suwanee_smiles	t	PPO	2000.00	200.00	1800.00	100.00	50.00	50.00	100.00	80.00	50.00	50.00	t	f	t	t	f	f	DDL-114702-M	GRP-44821	delta_dental	2017-01-01	["D6010", "D6010", "D6010", "D6010", "D7953", "D7953", "D7953", "D7953", "D6065", "D6065", "D6065", "D6065"]	x12_271	0.970	2026-08-05T16:18:25.668661+00:00	2026-08-05T16:18:25.668661	[]
PRED-SIM-DA-D03	suwanee_smiles	t	PPO	2000.00	200.00	1800.00	100.00	50.00	50.00	100.00	80.00	50.00	50.00	t	f	f	t	f	f	DDL-667203-L	GRP-NEW-2025	delta_dental	2025-09-04	["D6010", "D6065"]	x12_271	0.970	2026-08-05T16:18:27.413762+00:00	2026-08-05T16:18:27.413762	[]
PRED-SIM-DA-D04	suwanee_smiles	t	PPO	2000.00	200.00	1800.00	100.00	50.00	50.00	100.00	80.00	50.00	0.00	f	f	t	t	f	f	DDL-445619-T	GRP-77103	delta_dental	2018-06-01	["D2740"]	x12_271	0.970	2026-08-05T16:18:28.881561+00:00	2026-08-05T16:18:28.881561	[]
PRED-SIM-DA-D05	suwanee_smiles	t	PPO	2000.00	200.00	1800.00	100.00	50.00	50.00	100.00	80.00	50.00	50.00	t	f	t	t	f	f	DDL-558934-R	GRP-44821	delta_dental	2021-01-01	["D6010", "D7953"]	x12_271	0.970	2026-08-05T16:18:30.399561+00:00	2026-08-05T16:18:30.400560	[]
PRED-SIM-DA-M01	suwanee_smiles	t	PPO	2000.00	200.00	1800.00	100.00	50.00	50.00	100.00	80.00	50.00	0.00	f	f	t	t	f	f	DDL-999001-X	GRP-44821	delta_dental	2020-04-01	["D2750"]	x12_271	0.970	2026-08-05T16:18:32.029265+00:00	2026-08-05T16:18:32.029265	[{"edge": "contradicts", "field": "member_id", "value_a": "DDL-999001-X", "value_b": "DDL-999001-A", "source_a": "x12_271", "source_b": "api"}]
PRED-SIM-DA-M02	suwanee_smiles	t	PPO	2000.00	200.00	1800.00	100.00	50.00	50.00	100.00	80.00	50.00	0.00	f	f	t	t	f	f	DDL-284416-B	GRP-77103	delta_dental	2019-07-01	["D4260"]	x12_271	0.970	2026-08-05T16:18:33.659429+00:00	2026-08-05T16:18:33.659429	[]
PRED-SIM-DA-M03	suwanee_smiles	t	PPO	2000.00	200.00	1800.00	100.00	50.00	50.00	100.00	80.00	50.00	0.00	f	f	t	t	f	f	DDL-771230-W	GRP-55290	delta_dental	2020-02-01	["D2750"]	x12_271	0.970	2026-08-05T16:18:35.130158+00:00	2026-08-05T16:18:35.130158	[]
PRED-SIM-DA-M04	suwanee_smiles	t	PPO	2000.00	200.00	1800.00	100.00	50.00	50.00	100.00	80.00	50.00	50.00	t	f	t	t	f	f	DDL-620914-K	GRP-44821	delta_dental	2021-01-01	["D6010"]	x12_271	0.970	2026-08-05T16:18:36.572418+00:00	2026-08-05T16:18:36.572418	[]
PRED-SIM-DA-M05	suwanee_smiles	t	PPO	2000.00	200.00	1800.00	100.00	50.00	50.00	100.00	80.00	50.00	0.00	f	f	t	t	f	f	DDL-330728-M	GRP-77103	delta_dental	2018-05-01	["D2750"]	x12_271	0.970	2026-08-05T16:18:38.174295+00:00	2026-08-05T16:18:38.174295	[]
PRED-SIM-DA-F01	suwanee_smiles	t	PPO	2000.00	200.00	1800.00	100.00	50.00	50.00	100.00	80.00	50.00	0.00	f	f	t	t	f	f	DDL-826140-G	GRP-44821	delta_dental	2019-03-01	["D2740"]	x12_271	0.970	2026-08-05T16:18:39.602354+00:00	2026-08-05T16:18:39.602354	[]
PRED-SIM-DA-F02	suwanee_smiles	t	PPO	2000.00	200.00	1800.00	100.00	50.00	50.00	100.00	80.00	50.00	0.00	f	f	t	t	f	f	DDL-193355-J	GRP-55290	delta_dental	2019-01-01	["D4260"]	x12_271	0.970	2026-08-05T16:18:41.049392+00:00	2026-08-05T16:18:41.049392	[]
PRED-SIM-DA-F03	suwanee_smiles	t	PPO	2000.00	200.00	1800.00	100.00	50.00	50.00	100.00	80.00	50.00	0.00	f	f	t	t	f	f	DDL-507742-W	GRP-77103	delta_dental	2016-01-01	["D2750"]	x12_271	0.970	2026-08-05T16:18:42.521617+00:00	2026-08-05T16:18:42.521617	[]
PRED-SIM-DA-F04	suwanee_smiles	t	PPO	2000.00	200.00	1800.00	100.00	50.00	50.00	100.00	80.00	50.00	0.00	f	f	t	t	f	f	DDL-410288-T	GRP-44821	delta_dental	2019-04-01	["D2750"]	x12_271	0.970	2026-08-05T16:18:44.124872+00:00	2026-08-05T16:18:44.124872	[]
PRED-SIM-DA-F05	suwanee_smiles	t	PPO	2000.00	200.00	1800.00	100.00	50.00	50.00	100.00	80.00	50.00	50.00	t	f	t	t	f	f	DDL-284900-D	GRP-44821	delta_dental	2019-01-01	["D6010"]	x12_271	0.970	2026-08-05T16:18:45.738088+00:00	2026-08-05T16:18:45.738088	[]
PRED-SIM-DA-C06	suwanee_smiles	t	DPPO	2000.00	200.00	1800.00	100.00	50.00	50.00	100.00	80.00	50.00	0.00	f	f	t	t	f	f	CIG-774120-W	GRP-CIG-01	cigna	2020-01-01	["D2740"]	x12_271	0.970	2026-08-05T16:18:47.138424+00:00	2026-08-05T16:18:47.138424	[]
PRED-SIM-DA-C07	suwanee_smiles	t	PDP	2000.00	200.00	1800.00	100.00	50.00	50.00	100.00	80.00	50.00	0.00	f	f	t	t	f	f	MET-330281-A	GRP-MET-04	metlife	2018-01-01	[]	x12_271	0.970	2026-08-05T16:18:48.573508+00:00	2026-08-05T16:18:48.573508	[]
PRED-SIM-DA-C08	suwanee_smiles	t	PPO	1500.00	0.00	1500.00	50.00	50.00	0.00	100.00	80.00	50.00	0.00	f	f	t	t	f	t	DDL-664201-D	GRP-44821	delta_dental	2019-01-01	["D2750"]	x12_271	0.970	2026-08-05T16:18:49.864804+00:00	2026-08-05T16:18:49.864804	[]
PRED-SIM-DA-C09	suwanee_smiles	t	PPO	2000.00	200.00	1800.00	100.00	50.00	50.00	100.00	80.00	50.00	50.00	t	f	t	t	f	f	DDL-880417-T	GRP-77103	delta_dental	2017-01-01	["D6010"]	x12_271	0.970	2026-08-05T16:18:51.500107+00:00	2026-08-05T16:18:51.500107	[]
PRED-SIM-DA-C10	suwanee_smiles	t	PPO	2000.00	200.00	1800.00	100.00	50.00	50.00	100.00	80.00	50.00	0.00	f	f	t	t	f	f	DDL-551903-M	GRP-44821	delta_dental	2020-01-01	["D2750"]	x12_271	0.970	2026-08-05T16:18:52.906969+00:00	2026-08-05T16:18:52.906969	[]
PRED-SIM-DA-B02	suwanee_smiles	t	PPO	2000.00	200.00	1800.00	100.00	50.00	50.00	100.00	80.00	50.00	50.00	t	f	t	t	t	f	DDL-778234-A	GRP-44821	delta_dental	2022-01-01	["D6010", "D6065"]	x12_271	0.970	2026-08-05T16:18:09.511433+00:00	2026-08-05T16:18:09.511433	[]
\.


--
-- Data for Name: evidence_edges; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.evidence_edges (edge_id, tenant_id, pred_request_id, from_node, to_node, edge_type, confidence, relationship_type, field, reasoning) FROM stdin;
25	suwanee_smiles	PRED-SIM-DA-A01	112	109	confirms	0.900	confirms	clinical_necessity	X-ray bone loss of 4.2mm meets the 3.0mm threshold and confirms the clinical note narrative
26	suwanee_smiles	PRED-SIM-DA-A01	109	111	contradicts	0.900	contradicts	bundling_conflict	Clinical note CDT codes D6010, D6065, D7953 trigger the bundling rule
27	suwanee_smiles	PRED-SIM-DA-A04	120	119	confirms	0.900	confirms	periodontal_severity	Pocket depth 6.0mm supports the documented periodontal diagnosis
28	suwanee_smiles	PRED-SIM-DA-B04	135	133	confirms	0.900	confirms	clinical_necessity	X-ray bone loss of 4.2mm meets the 3.0mm threshold and confirms the clinical note narrative
29	suwanee_smiles	PRED-SIM-DA-B04	133	134	contradicts	0.900	contradicts	bundling_conflict	Clinical note CDT codes D6010, D7953 trigger the bundling rule
30	suwanee_smiles	PRED-SIM-DA-C01	139	140	contradicts	0.900	contradicts	bundling_conflict	Clinical note CDT codes D6010, D7953 trigger the bundling rule
31	suwanee_smiles	PRED-SIM-DA-C02	143	141	contradicts	0.900	contradicts	clinical_necessity	X-ray bone loss of 2.1mm is below the 3.0mm threshold the narrative relies on
32	suwanee_smiles	PRED-SIM-DA-C03	146	144	confirms	0.850	confirms	clinical_necessity	X-ray bone loss of 4.0mm meets the 3.0mm threshold and confirms the clinical note narrative
33	suwanee_smiles	PRED-SIM-DA-C09	164	162	confirms	0.900	confirms	clinical_necessity	X-ray bone loss of 4.2mm meets the 3.0mm threshold and confirms the clinical note narrative
34	suwanee_smiles	PRED-SIM-DA-D01	171	168	confirms	0.900	confirms	clinical_necessity	X-ray bone loss of 4.2mm meets the 3.0mm threshold and confirms the clinical note narrative
35	suwanee_smiles	PRED-SIM-DA-D01	168	170	contradicts	0.900	contradicts	bundling_conflict	Clinical note CDT codes D4260, D6010, D7953 trigger the bundling rule
36	suwanee_smiles	PRED-SIM-DA-D01	169	168	confirms	0.900	confirms	periodontal_severity	Pocket depth 6.0mm supports the documented periodontal diagnosis
37	suwanee_smiles	PRED-SIM-DA-D02	175	173	confirms	0.850	confirms	clinical_necessity	X-ray bone loss of 5.1mm meets the 3.0mm threshold and confirms the clinical note narrative
38	suwanee_smiles	PRED-SIM-DA-D02	173	174	contradicts	0.900	contradicts	bundling_conflict	Clinical note CDT codes D6010, D6065, D7953 trigger the bundling rule
39	suwanee_smiles	PRED-SIM-DA-D03	178	176	confirms	0.900	confirms	clinical_necessity	X-ray bone loss of 4.2mm meets the 3.0mm threshold and confirms the clinical note narrative
40	suwanee_smiles	PRED-SIM-DA-D04	179	180	contradicts	0.900	contradicts	procedure_code	Upcoding signal: billed D2740, note documents D2750
41	suwanee_smiles	PRED-SIM-DA-D05	185	183	confirms	0.900	confirms	clinical_necessity	X-ray bone loss of 4.5mm meets the 3.0mm threshold and confirms the clinical note narrative
42	suwanee_smiles	PRED-SIM-DA-D05	185	184	corroborates	1.000	corroborates	radiographic_evidence	Approval corroborated by a diagnostic-quality radiograph
43	suwanee_smiles	PRED-SIM-DA-F01	186	187	contradicts	0.900	contradicts	procedure_code	Upcoding signal: billed D2740, note documents D2750
44	suwanee_smiles	PRED-SIM-DA-F02	190	189	contradicts	0.900	contradicts	periodontal_severity	Pocket depth 3.0mm is below the 5mm surgical threshold
45	suwanee_smiles	PRED-SIM-DA-F04	195	196	contradicts	0.900	contradicts	bundling_conflict	Clinical note CDT codes D2750 trigger the bundling rule
46	suwanee_smiles	PRED-SIM-DA-F05	200	198	confirms	0.900	confirms	clinical_necessity	X-ray bone loss of 4.2mm meets the 3.0mm threshold and confirms the clinical note narrative
47	suwanee_smiles	PRED-SIM-DA-M02	206	205	confirms	0.900	confirms	periodontal_severity	Pocket depth 6.0mm supports the documented periodontal diagnosis
48	suwanee_smiles	PRED-SIM-DA-M04	213	211	confirms	0.900	confirms	clinical_necessity	X-ray bone loss of 4.2mm meets the 3.0mm threshold and confirms the clinical note narrative
97	suwanee_smiles	PRED-SIM-DA-U05	447	445	contradicts	0.900	contradicts	periodontal_severity	Pocket depth 4.0mm is below the 5mm surgical threshold
\.


--
-- Data for Name: evidence_nodes; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.evidence_nodes (node_id, tenant_id, pred_request_id, node_type, ref_id, attributes, entity_type, entity_id, properties, confidence, source) FROM stdin;
143	suwanee_smiles	PRED-SIM-DA-C02	document	XRAY-DA-C02-D03	{"pathology": "Edentulous space #14 with healed ridge", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "bone_loss_mm": 2.1, "tooth_number": 14, "bone_loss_pct": 20.0, "image_quality": "DIAGNOSTIC"}	XRAY_PA	XRAY-DA-C02-D03	{"pathology": "Edentulous space #14 with healed ridge", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "bone_loss_mm": 2.1, "tooth_number": 14, "bone_loss_pct": 20.0, "image_quality": "DIAGNOSTIC"}	1.000	deterministic
113	suwanee_smiles	PRED-SIM-DA-A02	document	NOTE-DA-A02-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D2750"], "diagnosis": "D2750 crown. X-ray confirms decay. Frequency limit not triggered.", "visit_date": "2026-08-05", "treatment_plan": "D2750 tooth #3", "cdt_codes_noted": ["D2750"], "chief_complaint": "Clean Approval â€” Crown on Tooth #3", "narrative_present": false, "primary_diagnosis": "D2750 crown. X-ray confirms decay. Frequency limit not triggered."}	CLINICAL_NOTE	NOTE-DA-A02-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D2750"], "diagnosis": "D2750 crown. X-ray confirms decay. Frequency limit not triggered.", "visit_date": "2026-08-05", "treatment_plan": "D2750 tooth #3", "cdt_codes_noted": ["D2750"], "chief_complaint": "Clean Approval â€” Crown on Tooth #3", "narrative_present": false, "primary_diagnosis": "D2750 crown. X-ray confirms decay. Frequency limit not triggered."}	0.750	deterministic
114	suwanee_smiles	PRED-SIM-DA-A02	document	DA-A02-PRED_LETTER	{"decision": "approved", "pred_number": "PD-DAA02", "denial_reason": "", "pred_decision": "APPROVED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": [], "cdt_codes_reviewed": ["D2750"]}	PRED_LETTER	DA-A02-PRED_LETTER	{"decision": "approved", "pred_number": "PD-DAA02", "denial_reason": "", "pred_decision": "APPROVED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": [], "cdt_codes_reviewed": ["D2750"]}	1.000	deterministic
115	suwanee_smiles	PRED-SIM-DA-A02	document	XRAY-DA-A02-D02	{"pathology": "Caries extending to pulp chamber, tooth #3", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "tooth_number": 3, "decay_present": true, "image_quality": "DIAGNOSTIC"}	XRAY_PA	XRAY-DA-A02-D02	{"pathology": "Caries extending to pulp chamber, tooth #3", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "tooth_number": 3, "decay_present": true, "image_quality": "DIAGNOSTIC"}	0.700	deterministic
437	suwanee_smiles	PRED-SIM-DA-U02	document	INS-DA-U02-CARD-D02	{"payer_id": "delta_dental", "member_id": "DDL-334709-S", "plan_type": "PPO", "group_number": "GRP-44821", "coverage_active": true}	INSURANCE_CARD	INS-DA-U02-CARD-D02	{"payer_id": "delta_dental", "member_id": "DDL-334709-S", "plan_type": "PPO", "group_number": "GRP-44821", "coverage_active": true}	0.950	caller_supplied
116	suwanee_smiles	PRED-SIM-DA-A03	document	NOTE-DA-A03-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D3330", "D2750"], "diagnosis": "D3330 + D2750. Core buildup correctly NOT billed separately.", "visit_date": "2026-08-05", "treatment_plan": "D3330+D2750 tooth #30", "cdt_codes_noted": ["D2750", "D3330"], "chief_complaint": "Clean Approval â€” Root Canal + Crown #30", "narrative_present": false, "primary_diagnosis": "D3330 + D2750. Core buildup correctly NOT billed separately."}	CLINICAL_NOTE	NOTE-DA-A03-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D3330", "D2750"], "diagnosis": "D3330 + D2750. Core buildup correctly NOT billed separately.", "visit_date": "2026-08-05", "treatment_plan": "D3330+D2750 tooth #30", "cdt_codes_noted": ["D2750", "D3330"], "chief_complaint": "Clean Approval â€” Root Canal + Crown #30", "narrative_present": false, "primary_diagnosis": "D3330 + D2750. Core buildup correctly NOT billed separately."}	0.750	deterministic
188	suwanee_smiles	PRED-SIM-DA-F01	document	XRAY-DA-F01-D03	{"pathology": "Caries extending to pulp chamber, tooth #8", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "tooth_number": 8, "decay_present": true, "image_quality": "DIAGNOSTIC"}	XRAY_PA	XRAY-DA-F01-D03	{"pathology": "Caries extending to pulp chamber, tooth #8", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "tooth_number": 8, "decay_present": true, "image_quality": "DIAGNOSTIC"}	0.700	deterministic
202	suwanee_smiles	PRED-SIM-DA-M01	document	INS-DA-M01-CARD-D02	{"payer_id": "delta_dental", "member_id": "DDL-999001-A", "plan_type": "PPO", "group_number": "GRP-44821", "coverage_active": true}	INSURANCE_CARD	INS-DA-M01-CARD-D02	{"payer_id": "delta_dental", "member_id": "DDL-999001-A", "plan_type": "PPO", "group_number": "GRP-44821", "coverage_active": true}	0.950	caller_supplied
124	suwanee_smiles	PRED-SIM-DA-B01	document	INS-DA-B01-CARD-D03	{"payer_id": "delta_dental", "member_id": "DDL-334891-J", "plan_type": "PPO", "group_number": "GRP-BASIC-01", "coverage_active": true}	INSURANCE_CARD	INS-DA-B01-CARD-D03	{"payer_id": "delta_dental", "member_id": "DDL-334891-J", "plan_type": "PPO", "group_number": "GRP-BASIC-01", "coverage_active": true}	0.950	caller_supplied
109	suwanee_smiles	PRED-SIM-DA-A01	document	NOTE-DA-A01-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D6010", "D7953", "D6065"], "diagnosis": "Reference: D6010+D7953+D6065 tooth #19. Delta Dental PPO. Bone graft separately documented.", "narrative": "Bone graft documented with PA X-ray showing 4.2mm bone loss. Approved when documentation complete.", "visit_date": "2026-08-05", "treatment_plan": "D6010+D7953+D6065 tooth #19", "cdt_codes_noted": ["D6010", "D6065", "D7953"], "chief_complaint": "Clean Approval â€” Implant + Bone Graft + Crown", "narrative_present": true, "primary_diagnosis": "Reference: D6010+D7953+D6065 tooth #19. Delta Dental PPO. Bone graft separately documented."}	CLINICAL_NOTE	NOTE-DA-A01-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D6010", "D7953", "D6065"], "diagnosis": "Reference: D6010+D7953+D6065 tooth #19. Delta Dental PPO. Bone graft separately documented.", "narrative": "Bone graft documented with PA X-ray showing 4.2mm bone loss. Approved when documentation complete.", "visit_date": "2026-08-05", "treatment_plan": "D6010+D7953+D6065 tooth #19", "cdt_codes_noted": ["D6010", "D6065", "D7953"], "chief_complaint": "Clean Approval â€” Implant + Bone Graft + Crown", "narrative_present": true, "primary_diagnosis": "Reference: D6010+D7953+D6065 tooth #19. Delta Dental PPO. Bone graft separately documented."}	0.900	deterministic
110	suwanee_smiles	PRED-SIM-DA-A01	document	INS-DA-A01-CARD-D04	{"payer_id": "delta_dental", "member_id": "DDL-842901-M", "plan_type": "PPO", "group_number": "GRP-44821", "coverage_active": true}	INSURANCE_CARD	INS-DA-A01-CARD-D04	{"payer_id": "delta_dental", "member_id": "DDL-842901-M", "plan_type": "PPO", "group_number": "GRP-44821", "coverage_active": true}	0.950	caller_supplied
111	suwanee_smiles	PRED-SIM-DA-A01	document	DA-A01-PRED_LETTER	{"decision": "pended", "pred_number": "PD-DAA01", "denial_reason": "", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": [], "cdt_codes_reviewed": ["D6010", "D6065", "D7953"]}	PRED_LETTER	DA-A01-PRED_LETTER	{"decision": "pended", "pred_number": "PD-DAA01", "denial_reason": "", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": [], "cdt_codes_reviewed": ["D6010", "D6065", "D7953"]}	1.000	deterministic
112	suwanee_smiles	PRED-SIM-DA-A01	document	XRAY-DA-A01-D02	{"pathology": "Edentulous space #19 with healed ridge", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "bone_loss_mm": 4.2, "tooth_number": 19, "bone_loss_pct": 35.0, "image_quality": "DIAGNOSTIC"}	XRAY_PA	XRAY-DA-A01-D02	{"pathology": "Edentulous space #19 with healed ridge", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "bone_loss_mm": 4.2, "tooth_number": 19, "bone_loss_pct": 35.0, "image_quality": "DIAGNOSTIC"}	1.000	deterministic
117	suwanee_smiles	PRED-SIM-DA-A03	document	DA-A03-PRED_LETTER	{"decision": "approved", "pred_number": "PD-DAA03", "denial_reason": "", "pred_decision": "APPROVED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": [], "cdt_codes_reviewed": ["D2750", "D3330"]}	PRED_LETTER	DA-A03-PRED_LETTER	{"decision": "approved", "pred_number": "PD-DAA03", "denial_reason": "", "pred_decision": "APPROVED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": [], "cdt_codes_reviewed": ["D2750", "D3330"]}	1.000	deterministic
118	suwanee_smiles	PRED-SIM-DA-A03	document	XRAY-DA-A03-D02	{"pathology": "Caries extending to pulp chamber, tooth #30", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "tooth_number": 30, "decay_present": true, "image_quality": "DIAGNOSTIC"}	XRAY_PA	XRAY-DA-A03-D02	{"pathology": "Caries extending to pulp chamber, tooth #30", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "tooth_number": 30, "decay_present": true, "image_quality": "DIAGNOSTIC"}	0.700	deterministic
119	suwanee_smiles	PRED-SIM-DA-A04	document	NOTE-DA-A04-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D4341", "D4341", "D4341", "D4341"], "diagnosis": "D4341 x4. Perio chart supports pocket depths 5-7mm.", "narrative": "Procedures planned: D4341, D4341, D4341, D4341", "visit_date": "2026-08-05", "treatment_plan": "D4341+D4341+D4341+D4341 tooth multiple quadrants", "cdt_codes_noted": ["D4341"], "chief_complaint": "Clean Approval â€” Perio Scaling 4 Quads", "narrative_present": true, "primary_diagnosis": "D4341 x4. Perio chart supports pocket depths 5-7mm."}	CLINICAL_NOTE	NOTE-DA-A04-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D4341", "D4341", "D4341", "D4341"], "diagnosis": "D4341 x4. Perio chart supports pocket depths 5-7mm.", "narrative": "Procedures planned: D4341, D4341, D4341, D4341", "visit_date": "2026-08-05", "treatment_plan": "D4341+D4341+D4341+D4341 tooth multiple quadrants", "cdt_codes_noted": ["D4341"], "chief_complaint": "Clean Approval â€” Perio Scaling 4 Quads", "narrative_present": true, "primary_diagnosis": "D4341 x4. Perio chart supports pocket depths 5-7mm."}	0.900	deterministic
120	suwanee_smiles	PRED-SIM-DA-A04	document	PERIO-DA-A04-D02	{"exam_date": "2026-08-05", "charted_on": "2026-08-05", "bleeding_pct": 42.0, "sites_charted": 24, "sites_gte_4mm": 8, "sites_gte_5mm": 8, "sites_gte_6mm": 4, "interpretation": "Probing depths support osseous surgery per AAP criteria.", "perio_diagnosis": "Stage III Periodontitis", "pocket_depth_avg": 3.83, "pocket_depth_max": 6.0, "max_pocket_depth_mm": 6, "bleeding_on_probing_pct": 42.0}	PERIO_CHART	PERIO-DA-A04-D02	{"exam_date": "2026-08-05", "charted_on": "2026-08-05", "bleeding_pct": 42.0, "sites_charted": 24, "sites_gte_4mm": 8, "sites_gte_5mm": 8, "sites_gte_6mm": 4, "interpretation": "Probing depths support osseous surgery per AAP criteria.", "perio_diagnosis": "Stage III Periodontitis", "pocket_depth_avg": 3.83, "pocket_depth_max": 6.0, "max_pocket_depth_mm": 6, "bleeding_on_probing_pct": 42.0}	0.900	deterministic
121	suwanee_smiles	PRED-SIM-DA-A04	document	DA-A04-PRED_LETTER	{"decision": "approved", "pred_number": "PD-DAA04", "denial_reason": "", "pred_decision": "APPROVED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": [], "cdt_codes_reviewed": ["D4341"]}	PRED_LETTER	DA-A04-PRED_LETTER	{"decision": "approved", "pred_number": "PD-DAA04", "denial_reason": "", "pred_decision": "APPROVED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": [], "cdt_codes_reviewed": ["D4341"]}	1.000	deterministic
122	suwanee_smiles	PRED-SIM-DA-A05	document	INS-DA-A05-CARD-D02	{"payer_id": "delta_dental", "member_id": "DDL-901234-P", "plan_type": "PPO", "group_number": "GRP-44821", "coverage_active": true}	INSURANCE_CARD	INS-DA-A05-CARD-D02	{"payer_id": "delta_dental", "member_id": "DDL-901234-P", "plan_type": "PPO", "group_number": "GRP-44821", "coverage_active": true}	0.950	caller_supplied
123	suwanee_smiles	PRED-SIM-DA-A05	document	DA-A05-PRED_LETTER	{"decision": "approved", "pred_number": "PD-DAA05", "denial_reason": "", "pred_decision": "APPROVED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": [], "cdt_codes_reviewed": ["D0330"]}	PRED_LETTER	DA-A05-PRED_LETTER	{"decision": "approved", "pred_number": "PD-DAA05", "denial_reason": "", "pred_decision": "APPROVED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": [], "cdt_codes_reviewed": ["D0330"]}	1.000	deterministic
125	suwanee_smiles	PRED-SIM-DA-B01	document	DA-B01-PRED_LETTER	{"decision": "denied", "pred_number": "PD-DAB01", "denial_reason": "Implants excluded from this plan.", "pred_decision": "DENIED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["ELIG_IMPLANT_NOT_COVERED"], "cdt_codes_reviewed": ["D6010", "D6065"], "denial_reason_text": "Implants excluded from this plan."}	PRED_LETTER	DA-B01-PRED_LETTER	{"decision": "denied", "pred_number": "PD-DAB01", "denial_reason": "Implants excluded from this plan.", "pred_decision": "DENIED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["ELIG_IMPLANT_NOT_COVERED"], "cdt_codes_reviewed": ["D6010", "D6065"], "denial_reason_text": "Implants excluded from this plan."}	1.000	deterministic
126	suwanee_smiles	PRED-SIM-DA-B01	document	XRAY-DA-B01-D02	{"pathology": "Edentulous space #14 with healed ridge", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "bone_loss_mm": 4.2, "tooth_number": 14, "bone_loss_pct": 35.0, "image_quality": "DIAGNOSTIC"}	XRAY_PA	XRAY-DA-B01-D02	{"pathology": "Edentulous space #14 with healed ridge", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "bone_loss_mm": 4.2, "tooth_number": 14, "bone_loss_pct": 35.0, "image_quality": "DIAGNOSTIC"}	1.000	deterministic
127	suwanee_smiles	PRED-SIM-DA-B02	document	INS-DA-B02-CARD-D03	{"payer_id": "delta_dental", "member_id": "DDL-778234-A", "plan_type": "PPO", "group_number": "GRP-44821", "coverage_active": true}	INSURANCE_CARD	INS-DA-B02-CARD-D03	{"payer_id": "delta_dental", "member_id": "DDL-778234-A", "plan_type": "PPO", "group_number": "GRP-44821", "coverage_active": true}	0.950	caller_supplied
438	suwanee_smiles	PRED-SIM-DA-U02	document	DA-U02-PRED_LETTER	{"decision": "approved", "pred_number": "PD-DAU02", "denial_reason": "", "pred_decision": "APPROVED", "response_date": "2026-08-06", "appeal_deadline": "2027-02-02", "condition_codes": [], "cdt_codes_reviewed": ["D0274"]}	PRED_LETTER	DA-U02-PRED_LETTER	{"decision": "approved", "pred_number": "PD-DAU02", "denial_reason": "", "pred_decision": "APPROVED", "response_date": "2026-08-06", "appeal_deadline": "2027-02-02", "condition_codes": [], "cdt_codes_reviewed": ["D0274"]}	1.000	deterministic
128	suwanee_smiles	PRED-SIM-DA-B02	document	DA-B02-PRED_LETTER	{"decision": "denied", "pred_number": "PD-DAB02", "denial_reason": "Missing tooth clause â€” tooth #19 missing before enrollment.", "pred_decision": "DENIED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["CLINICAL_EXTRACTION_DATE", "ELIG_MISSING_TOOTH_CLAUSE"], "cdt_codes_reviewed": ["D6010", "D6065"], "denial_reason_text": "Missing tooth clause â€” tooth #19 missing before enrollment."}	PRED_LETTER	DA-B02-PRED_LETTER	{"decision": "denied", "pred_number": "PD-DAB02", "denial_reason": "Missing tooth clause â€” tooth #19 missing before enrollment.", "pred_decision": "DENIED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["CLINICAL_EXTRACTION_DATE", "ELIG_MISSING_TOOTH_CLAUSE"], "cdt_codes_reviewed": ["D6010", "D6065"], "denial_reason_text": "Missing tooth clause â€” tooth #19 missing before enrollment."}	1.000	deterministic
129	suwanee_smiles	PRED-SIM-DA-B02	document	XRAY-DA-B02-D02	{"pathology": "Edentulous space #19 with healed ridge", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "bone_loss_mm": 4.2, "tooth_number": 19, "bone_loss_pct": 35.0, "image_quality": "DIAGNOSTIC"}	XRAY_PA	XRAY-DA-B02-D02	{"pathology": "Edentulous space #19 with healed ridge", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "bone_loss_mm": 4.2, "tooth_number": 19, "bone_loss_pct": 35.0, "image_quality": "DIAGNOSTIC"}	1.000	deterministic
130	suwanee_smiles	PRED-SIM-DA-B03	document	INS-DA-B03-CARD-D03	{"payer_id": "delta_dental", "member_id": "DDL-223847-H", "plan_type": "PPO", "group_number": "GRP-77103", "coverage_active": true}	INSURANCE_CARD	INS-DA-B03-CARD-D03	{"payer_id": "delta_dental", "member_id": "DDL-223847-H", "plan_type": "PPO", "group_number": "GRP-77103", "coverage_active": true}	0.950	caller_supplied
131	suwanee_smiles	PRED-SIM-DA-B03	document	DA-B03-PRED_LETTER	{"decision": "denied", "pred_number": "PD-DAB03", "denial_reason": "Crown frequency limit exceeded. Last approved 2023. Next eligible 2028.", "pred_decision": "DENIED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["ELIG_FREQUENCY_LIMIT"], "cdt_codes_reviewed": ["D2750"], "denial_reason_text": "Crown frequency limit exceeded. Last approved 2023. Next eligible 2028."}	PRED_LETTER	DA-B03-PRED_LETTER	{"decision": "denied", "pred_number": "PD-DAB03", "denial_reason": "Crown frequency limit exceeded. Last approved 2023. Next eligible 2028.", "pred_decision": "DENIED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["ELIG_FREQUENCY_LIMIT"], "cdt_codes_reviewed": ["D2750"], "denial_reason_text": "Crown frequency limit exceeded. Last approved 2023. Next eligible 2028."}	1.000	deterministic
132	suwanee_smiles	PRED-SIM-DA-B03	document	XRAY-DA-B03-D02	{"pathology": "Caries extending to pulp chamber, tooth #3", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "tooth_number": 3, "decay_present": true, "image_quality": "DIAGNOSTIC"}	XRAY_PA	XRAY-DA-B03-D02	{"pathology": "Caries extending to pulp chamber, tooth #3", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "tooth_number": 3, "decay_present": true, "image_quality": "DIAGNOSTIC"}	0.700	deterministic
133	suwanee_smiles	PRED-SIM-DA-B04	document	NOTE-DA-B04-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D6010", "D7953"], "diagnosis": "THE core scenario: D7953 denied as not separately payable with D6010.", "narrative": "Accord catches bundling before submission. Appeal success ~65% when documented.", "visit_date": "2026-08-05", "treatment_plan": "D6010+D7953 tooth #19", "cdt_codes_noted": ["D6010", "D7953"], "chief_complaint": "Denial â€” Bone Graft Bundled with Implant", "narrative_present": true, "primary_diagnosis": "THE core scenario: D7953 denied as not separately payable with D6010."}	CLINICAL_NOTE	NOTE-DA-B04-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D6010", "D7953"], "diagnosis": "THE core scenario: D7953 denied as not separately payable with D6010.", "narrative": "Accord catches bundling before submission. Appeal success ~65% when documented.", "visit_date": "2026-08-05", "treatment_plan": "D6010+D7953 tooth #19", "cdt_codes_noted": ["D6010", "D7953"], "chief_complaint": "Denial â€” Bone Graft Bundled with Implant", "narrative_present": true, "primary_diagnosis": "THE core scenario: D7953 denied as not separately payable with D6010."}	0.900	deterministic
134	suwanee_smiles	PRED-SIM-DA-B04	document	DA-B04-PRED_LETTER	{"decision": "pended", "pred_number": "PD-DAB04", "denial_reason": "D7953 bundled with D6010. Separate clinical documentation required.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["CLINICAL_NARRATIVE_REQUIRED", "CLINICAL_XRAY_REQUIRED", "COVERAGE_BUNDLING_CONFLICT"], "cdt_codes_reviewed": ["D6010", "D7953"], "denial_reason_text": "D7953 bundled with D6010. Separate clinical documentation required."}	PRED_LETTER	DA-B04-PRED_LETTER	{"decision": "pended", "pred_number": "PD-DAB04", "denial_reason": "D7953 bundled with D6010. Separate clinical documentation required.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["CLINICAL_NARRATIVE_REQUIRED", "CLINICAL_XRAY_REQUIRED", "COVERAGE_BUNDLING_CONFLICT"], "cdt_codes_reviewed": ["D6010", "D7953"], "denial_reason_text": "D7953 bundled with D6010. Separate clinical documentation required."}	1.000	deterministic
135	suwanee_smiles	PRED-SIM-DA-B04	document	XRAY-DA-B04-D02	{"pathology": "Edentulous space #19 with healed ridge", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "bone_loss_mm": 4.2, "tooth_number": 19, "bone_loss_pct": 35.0, "image_quality": "DIAGNOSTIC"}	XRAY_PA	XRAY-DA-B04-D02	{"pathology": "Edentulous space #19 with healed ridge", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "bone_loss_mm": 4.2, "tooth_number": 19, "bone_loss_pct": 35.0, "image_quality": "DIAGNOSTIC"}	1.000	deterministic
136	suwanee_smiles	PRED-SIM-DA-B05	document	INS-DA-B05-CARD-D03	{"payer_id": "delta_dental", "member_id": "DDL-112983-T", "plan_type": "PPO", "group_number": "GRP-NEW-2025", "coverage_active": true}	INSURANCE_CARD	INS-DA-B05-CARD-D03	{"payer_id": "delta_dental", "member_id": "DDL-112983-T", "plan_type": "PPO", "group_number": "GRP-NEW-2025", "coverage_active": true}	0.950	caller_supplied
448	suwanee_smiles	PRED-SIM-DA-U05	document	DA-U05-PRED_LETTER	{"decision": "approved", "pred_number": "PD-DAU05", "denial_reason": "", "pred_decision": "APPROVED", "response_date": "2026-08-06", "appeal_deadline": "2027-02-02", "condition_codes": [], "cdt_codes_reviewed": ["D4910"]}	PRED_LETTER	DA-U05-PRED_LETTER	{"decision": "approved", "pred_number": "PD-DAU05", "denial_reason": "", "pred_decision": "APPROVED", "response_date": "2026-08-06", "appeal_deadline": "2027-02-02", "condition_codes": [], "cdt_codes_reviewed": ["D4910"]}	1.000	deterministic
137	suwanee_smiles	PRED-SIM-DA-B05	document	DA-B05-PRED_LETTER	{"decision": "denied", "pred_number": "PD-DAB05", "denial_reason": "12-month waiting period not met. Eligible 12/01/2026.", "pred_decision": "DENIED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["ELIG_WAITING_PERIOD_NOT_MET"], "cdt_codes_reviewed": ["D2750"], "denial_reason_text": "12-month waiting period not met. Eligible 12/01/2026."}	PRED_LETTER	DA-B05-PRED_LETTER	{"decision": "denied", "pred_number": "PD-DAB05", "denial_reason": "12-month waiting period not met. Eligible 12/01/2026.", "pred_decision": "DENIED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["ELIG_WAITING_PERIOD_NOT_MET"], "cdt_codes_reviewed": ["D2750"], "denial_reason_text": "12-month waiting period not met. Eligible 12/01/2026."}	1.000	deterministic
138	suwanee_smiles	PRED-SIM-DA-B05	document	XRAY-DA-B05-D02	{"pathology": "Caries extending to pulp chamber, tooth #13", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "tooth_number": 13, "decay_present": true, "image_quality": "DIAGNOSTIC"}	XRAY_PA	XRAY-DA-B05-D02	{"pathology": "Caries extending to pulp chamber, tooth #13", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "tooth_number": 13, "decay_present": true, "image_quality": "DIAGNOSTIC"}	0.700	deterministic
139	suwanee_smiles	PRED-SIM-DA-C01	document	NOTE-DA-C01-D02	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D6010", "D7953"], "diagnosis": "D6010+D7953 submitted with a narrative but no radiograph. Bone loss unprovable.", "narrative": "Evidence missing, not contradicted â€” pend and request the PA X-ray.", "visit_date": "2026-08-05", "treatment_plan": "D6010+D7953 tooth #19", "cdt_codes_noted": ["D6010", "D7953"], "chief_complaint": "Pended â€” Implant Missing X-ray", "narrative_present": true, "primary_diagnosis": "D6010+D7953 submitted with a narrative but no radiograph. Bone loss unprovable."}	CLINICAL_NOTE	NOTE-DA-C01-D02	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D6010", "D7953"], "diagnosis": "D6010+D7953 submitted with a narrative but no radiograph. Bone loss unprovable.", "narrative": "Evidence missing, not contradicted â€” pend and request the PA X-ray.", "visit_date": "2026-08-05", "treatment_plan": "D6010+D7953 tooth #19", "cdt_codes_noted": ["D6010", "D7953"], "chief_complaint": "Pended â€” Implant Missing X-ray", "narrative_present": true, "primary_diagnosis": "D6010+D7953 submitted with a narrative but no radiograph. Bone loss unprovable."}	0.900	deterministic
140	suwanee_smiles	PRED-SIM-DA-C01	document	DA-C01-PRED_LETTER	{"decision": "pended", "pred_number": "PD-DAC01", "denial_reason": "No radiograph â€” bone loss cannot be established.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["CLINICAL_BONE_LOSS_THRESHOLD", "CLINICAL_XRAY_REQUIRED"], "cdt_codes_reviewed": ["D6010", "D7953"], "denial_reason_text": "No radiograph â€” bone loss cannot be established."}	PRED_LETTER	DA-C01-PRED_LETTER	{"decision": "pended", "pred_number": "PD-DAC01", "denial_reason": "No radiograph â€” bone loss cannot be established.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["CLINICAL_BONE_LOSS_THRESHOLD", "CLINICAL_XRAY_REQUIRED"], "cdt_codes_reviewed": ["D6010", "D7953"], "denial_reason_text": "No radiograph â€” bone loss cannot be established."}	1.000	deterministic
141	suwanee_smiles	PRED-SIM-DA-C02	document	NOTE-DA-C02-D02	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D4260"], "diagnosis": "D4260 with a radiograph showing 20% bone loss (below the 25% threshold) and no perio chart.", "narrative": "Pocket depth was never measured â€” the defining criterion is missing, so pend rather than deny.", "visit_date": "2026-08-05", "treatment_plan": "D4260 tooth #14", "cdt_codes_noted": ["D4260"], "chief_complaint": "Pended â€” Perio Surgery Chart Insufficient", "narrative_present": true, "primary_diagnosis": "D4260 with a radiograph showing 20% bone loss (below the 25% threshold) and no perio chart."}	CLINICAL_NOTE	NOTE-DA-C02-D02	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D4260"], "diagnosis": "D4260 with a radiograph showing 20% bone loss (below the 25% threshold) and no perio chart.", "narrative": "Pocket depth was never measured â€” the defining criterion is missing, so pend rather than deny.", "visit_date": "2026-08-05", "treatment_plan": "D4260 tooth #14", "cdt_codes_noted": ["D4260"], "chief_complaint": "Pended â€” Perio Surgery Chart Insufficient", "narrative_present": true, "primary_diagnosis": "D4260 with a radiograph showing 20% bone loss (below the 25% threshold) and no perio chart."}	0.900	deterministic
142	suwanee_smiles	PRED-SIM-DA-C02	document	DA-C02-PRED_LETTER	{"decision": "pended", "pred_number": "PD-DAC02", "denial_reason": "Perio chart absent; radiographic bone loss below 25%.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["CLINICAL_BONE_LOSS_THRESHOLD", "CLINICAL_PERIO_CHART_REQUIRED"], "cdt_codes_reviewed": ["D4260"], "denial_reason_text": "Perio chart absent; radiographic bone loss below 25%."}	PRED_LETTER	DA-C02-PRED_LETTER	{"decision": "pended", "pred_number": "PD-DAC02", "denial_reason": "Perio chart absent; radiographic bone loss below 25%.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["CLINICAL_BONE_LOSS_THRESHOLD", "CLINICAL_PERIO_CHART_REQUIRED"], "cdt_codes_reviewed": ["D4260"], "denial_reason_text": "Perio chart absent; radiographic bone loss below 25%."}	1.000	deterministic
144	suwanee_smiles	PRED-SIM-DA-C03	document	NOTE-DA-C03-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D6010", "D6010", "D6010", "D6010", "D6065", "D6065", "D6065", "D6065"], "diagnosis": "Four implants and four crowns at $18,400. High-value implant cases require CBCT.", "narrative": "D6010+D6010+D6010+D6010+D6065+D6065+D6065+D6065 tooth #3, #14, #19, #30 Procedures planned: D6010, D6010, D6010, D6010, D6065, D6065, D6065, D6065 Panoramic film is not sufficient bone-volume analysis for a full-arch case.", "visit_date": "2026-08-05", "treatment_plan": "D6010+D6010+D6010+D6010+D6065+D6065+D6065+D6065 tooth #3, #14, #19, #30", "cdt_codes_noted": ["D6010", "D6065"], "chief_complaint": "Pended â€” Full Arch CBCT Required", "narrative_present": true, "primary_diagnosis": "Four implants and four crowns at $18,400. High-value implant cases require CBCT."}	CLINICAL_NOTE	NOTE-DA-C03-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D6010", "D6010", "D6010", "D6010", "D6065", "D6065", "D6065", "D6065"], "diagnosis": "Four implants and four crowns at $18,400. High-value implant cases require CBCT.", "narrative": "D6010+D6010+D6010+D6010+D6065+D6065+D6065+D6065 tooth #3, #14, #19, #30 Procedures planned: D6010, D6010, D6010, D6010, D6065, D6065, D6065, D6065 Panoramic film is not sufficient bone-volume analysis for a full-arch case.", "visit_date": "2026-08-05", "treatment_plan": "D6010+D6010+D6010+D6010+D6065+D6065+D6065+D6065 tooth #3, #14, #19, #30", "cdt_codes_noted": ["D6010", "D6065"], "chief_complaint": "Pended â€” Full Arch CBCT Required", "narrative_present": true, "primary_diagnosis": "Four implants and four crowns at $18,400. High-value implant cases require CBCT."}	0.900	deterministic
145	suwanee_smiles	PRED-SIM-DA-C03	document	DA-C03-PRED_LETTER	{"decision": "pended", "pred_number": "PD-DAC03", "denial_reason": "CBCT required for implant cases above $10,000.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["CLINICAL_CBCT_REQUIRED"], "cdt_codes_reviewed": ["D6010", "D6065"], "denial_reason_text": "CBCT required for implant cases above $10,000."}	PRED_LETTER	DA-C03-PRED_LETTER	{"decision": "pended", "pred_number": "PD-DAC03", "denial_reason": "CBCT required for implant cases above $10,000.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["CLINICAL_CBCT_REQUIRED"], "cdt_codes_reviewed": ["D6010", "D6065"], "denial_reason_text": "CBCT required for implant cases above $10,000."}	1.000	deterministic
146	suwanee_smiles	PRED-SIM-DA-C03	document	PAN-DA-C03-D02	{"pathology": "Generalized bone loss", "xray_date": "2026-08-05", "xray_type": "panoramic", "date_taken": "2026-08-05", "bone_loss_mm": 4.0, "tooth_number": null, "bone_loss_pct": 32.0, "image_quality": "DIAGNOSTIC"}	XRAY_PAN	PAN-DA-C03-D02	{"pathology": "Generalized bone loss", "xray_date": "2026-08-05", "xray_type": "panoramic", "date_taken": "2026-08-05", "bone_loss_mm": 4.0, "tooth_number": null, "bone_loss_pct": 32.0, "image_quality": "DIAGNOSTIC"}	0.850	deterministic
147	suwanee_smiles	PRED-SIM-DA-C04	document	NOTE-DA-C04-D02	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D2750"], "diagnosis": "D2750 submitted with a narrative referencing a 2024 film that was never attached.", "narrative": "A film referenced in the narrative but not attached is not evidence.", "visit_date": "2026-08-05", "treatment_plan": "D2750 tooth #3", "cdt_codes_noted": ["D2750"], "chief_complaint": "Pended â€” Crown Without Current X-ray", "narrative_present": true, "primary_diagnosis": "D2750 submitted with a narrative referencing a 2024 film that was never attached."}	CLINICAL_NOTE	NOTE-DA-C04-D02	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D2750"], "diagnosis": "D2750 submitted with a narrative referencing a 2024 film that was never attached.", "narrative": "A film referenced in the narrative but not attached is not evidence.", "visit_date": "2026-08-05", "treatment_plan": "D2750 tooth #3", "cdt_codes_noted": ["D2750"], "chief_complaint": "Pended â€” Crown Without Current X-ray", "narrative_present": true, "primary_diagnosis": "D2750 submitted with a narrative referencing a 2024 film that was never attached."}	0.900	deterministic
148	suwanee_smiles	PRED-SIM-DA-C04	document	DA-C04-PRED_LETTER	{"decision": "pended", "pred_number": "PD-DAC04", "denial_reason": "No radiograph in the submitted document set.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["CLINICAL_XRAY_REQUIRED"], "cdt_codes_reviewed": ["D2750"], "denial_reason_text": "No radiograph in the submitted document set."}	PRED_LETTER	DA-C04-PRED_LETTER	{"decision": "pended", "pred_number": "PD-DAC04", "denial_reason": "No radiograph in the submitted document set.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["CLINICAL_XRAY_REQUIRED"], "cdt_codes_reviewed": ["D2750"], "denial_reason_text": "No radiograph in the submitted document set."}	1.000	deterministic
149	suwanee_smiles	PRED-SIM-DA-C05	document	NOTE-DA-C05-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D2750"], "diagnosis": "Delta Dental primary, Cigna secondary. Primary must adjudicate first.", "narrative": "Clinically complete, but COB ordering blocks submission until primary responds.", "visit_date": "2026-08-05", "treatment_plan": "D2750 tooth #14", "cdt_codes_noted": ["D2750"], "chief_complaint": "Pended â€” Coordination of Benefits", "narrative_present": true, "primary_diagnosis": "Delta Dental primary, Cigna secondary. Primary must adjudicate first."}	CLINICAL_NOTE	NOTE-DA-C05-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D2750"], "diagnosis": "Delta Dental primary, Cigna secondary. Primary must adjudicate first.", "narrative": "Clinically complete, but COB ordering blocks submission until primary responds.", "visit_date": "2026-08-05", "treatment_plan": "D2750 tooth #14", "cdt_codes_noted": ["D2750"], "chief_complaint": "Pended â€” Coordination of Benefits", "narrative_present": true, "primary_diagnosis": "Delta Dental primary, Cigna secondary. Primary must adjudicate first."}	0.900	deterministic
150	suwanee_smiles	PRED-SIM-DA-C05	document	INS-DA-C05-CARD-D04	{"payer_id": "delta_dental", "member_id": "DDL-902314-P", "plan_type": "PPO", "group_number": "GRP-55290", "coverage_active": true, "secondary_payer_id": "cigna", "coordination_of_benefits": true}	INSURANCE_CARD	INS-DA-C05-CARD-D04	{"payer_id": "delta_dental", "member_id": "DDL-902314-P", "plan_type": "PPO", "group_number": "GRP-55290", "coverage_active": true, "secondary_payer_id": "cigna", "coordination_of_benefits": true}	0.950	caller_supplied
151	suwanee_smiles	PRED-SIM-DA-C05	document	DA-C05-PRED_LETTER	{"decision": "pended", "pred_number": "PD-DAC05", "denial_reason": "Dual coverage â€” primary payer must adjudicate first.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["ADMIN_COB_PRIMARY_FIRST", "ELIG_COB_REQUIRED"], "cdt_codes_reviewed": ["D2750"], "denial_reason_text": "Dual coverage â€” primary payer must adjudicate first."}	PRED_LETTER	DA-C05-PRED_LETTER	{"decision": "pended", "pred_number": "PD-DAC05", "denial_reason": "Dual coverage â€” primary payer must adjudicate first.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["ADMIN_COB_PRIMARY_FIRST", "ELIG_COB_REQUIRED"], "cdt_codes_reviewed": ["D2750"], "denial_reason_text": "Dual coverage â€” primary payer must adjudicate first."}	1.000	deterministic
152	suwanee_smiles	PRED-SIM-DA-C05	document	XRAY-DA-C05-D02	{"pathology": "Caries extending to pulp chamber, tooth #14", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "tooth_number": 14, "decay_present": true, "image_quality": "DIAGNOSTIC"}	XRAY_PA	XRAY-DA-C05-D02	{"pathology": "Caries extending to pulp chamber, tooth #14", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "tooth_number": 14, "decay_present": true, "image_quality": "DIAGNOSTIC"}	0.700	deterministic
153	suwanee_smiles	PRED-SIM-DA-C06	document	NOTE-DA-C06-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D2740"], "diagnosis": "D2740 on anterior tooth #8 under Cigna DPPO. Cigna pays the all-ceramic rate.", "narrative": "Delta downgrades D2740 to the PFM rate; Cigna does not. Same tooth, same code, different patient responsibility â€”", "visit_date": "2026-08-05", "treatment_plan": "D2740 tooth #8", "cdt_codes_noted": ["D2740"], "chief_complaint": "Cigna â€” All-Ceramic Crown Not Downgraded", "narrative_present": true, "primary_diagnosis": "D2740 on anterior tooth #8 under Cigna DPPO. Cigna pays the all-ceramic rate."}	CLINICAL_NOTE	NOTE-DA-C06-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D2740"], "diagnosis": "D2740 on anterior tooth #8 under Cigna DPPO. Cigna pays the all-ceramic rate.", "narrative": "Delta downgrades D2740 to the PFM rate; Cigna does not. Same tooth, same code, different patient responsibility â€”", "visit_date": "2026-08-05", "treatment_plan": "D2740 tooth #8", "cdt_codes_noted": ["D2740"], "chief_complaint": "Cigna â€” All-Ceramic Crown Not Downgraded", "narrative_present": true, "primary_diagnosis": "D2740 on anterior tooth #8 under Cigna DPPO. Cigna pays the all-ceramic rate."}	0.900	deterministic
154	suwanee_smiles	PRED-SIM-DA-C06	document	DA-C06-PRED_LETTER	{"decision": "approved", "pred_number": "PD-DAC06", "denial_reason": "", "pred_decision": "APPROVED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["COVERAGE_PRED_REQUIRED"], "cdt_codes_reviewed": ["D2740"]}	PRED_LETTER	DA-C06-PRED_LETTER	{"decision": "approved", "pred_number": "PD-DAC06", "denial_reason": "", "pred_decision": "APPROVED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["COVERAGE_PRED_REQUIRED"], "cdt_codes_reviewed": ["D2740"]}	1.000	deterministic
155	suwanee_smiles	PRED-SIM-DA-C06	document	XRAY-DA-C06-D02	{"pathology": "Caries extending to pulp chamber, tooth #8", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "tooth_number": 8, "decay_present": true, "image_quality": "DIAGNOSTIC"}	XRAY_PA	XRAY-DA-C06-D02	{"pathology": "Caries extending to pulp chamber, tooth #8", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "tooth_number": 8, "decay_present": true, "image_quality": "DIAGNOSTIC"}	0.700	deterministic
156	suwanee_smiles	PRED-SIM-DA-C07	document	INS-DA-C07-CARD-D02	{"payer_id": "metlife", "member_id": "MET-330281-A", "plan_type": "PDP", "group_number": "GRP-MET-04", "coverage_active": true}	INSURANCE_CARD	INS-DA-C07-CARD-D02	{"payer_id": "metlife", "member_id": "MET-330281-A", "plan_type": "PDP", "group_number": "GRP-MET-04", "coverage_active": true}	0.950	caller_supplied
157	suwanee_smiles	PRED-SIM-DA-C07	document	DA-C07-PRED_LETTER	{"decision": "approved", "pred_number": "PD-DAC07", "denial_reason": "", "pred_decision": "APPROVED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": [], "cdt_codes_reviewed": ["D0330"]}	PRED_LETTER	DA-C07-PRED_LETTER	{"decision": "approved", "pred_number": "PD-DAC07", "denial_reason": "", "pred_decision": "APPROVED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": [], "cdt_codes_reviewed": ["D0330"]}	1.000	deterministic
158	suwanee_smiles	PRED-SIM-DA-C08	document	NOTE-DA-C08-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D2750"], "diagnosis": "Child with Delta primary and Cigna secondary. Primary must adjudicate first.", "narrative": "Birthday rule decides which parent's plan is primary. Submitting to the wrong payer first restarts the clock.", "visit_date": "2026-08-05", "treatment_plan": "D2750 tooth #3", "cdt_codes_noted": ["D2750"], "chief_complaint": "Dual Coverage â€” COB Birthday Rule", "narrative_present": true, "primary_diagnosis": "Child with Delta primary and Cigna secondary. Primary must adjudicate first."}	CLINICAL_NOTE	NOTE-DA-C08-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D2750"], "diagnosis": "Child with Delta primary and Cigna secondary. Primary must adjudicate first.", "narrative": "Birthday rule decides which parent's plan is primary. Submitting to the wrong payer first restarts the clock.", "visit_date": "2026-08-05", "treatment_plan": "D2750 tooth #3", "cdt_codes_noted": ["D2750"], "chief_complaint": "Dual Coverage â€” COB Birthday Rule", "narrative_present": true, "primary_diagnosis": "Child with Delta primary and Cigna secondary. Primary must adjudicate first."}	0.900	deterministic
159	suwanee_smiles	PRED-SIM-DA-C08	document	INS-DA-C08-CARD-D04	{"payer_id": "delta_dental", "member_id": "DDL-664201-D", "plan_type": "PPO", "group_number": "GRP-44821", "coverage_active": true, "secondary_payer_id": "cigna", "coordination_of_benefits": true}	INSURANCE_CARD	INS-DA-C08-CARD-D04	{"payer_id": "delta_dental", "member_id": "DDL-664201-D", "plan_type": "PPO", "group_number": "GRP-44821", "coverage_active": true, "secondary_payer_id": "cigna", "coordination_of_benefits": true}	0.950	caller_supplied
160	suwanee_smiles	PRED-SIM-DA-C08	document	DA-C08-PRED_LETTER	{"decision": "pended", "pred_number": "PD-DAC08", "denial_reason": "Dual coverage â€” primary payer must adjudicate first.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["ADMIN_COB_PRIMARY_FIRST", "ELIG_COB_REQUIRED"], "cdt_codes_reviewed": ["D2750"], "denial_reason_text": "Dual coverage â€” primary payer must adjudicate first."}	PRED_LETTER	DA-C08-PRED_LETTER	{"decision": "pended", "pred_number": "PD-DAC08", "denial_reason": "Dual coverage â€” primary payer must adjudicate first.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["ADMIN_COB_PRIMARY_FIRST", "ELIG_COB_REQUIRED"], "cdt_codes_reviewed": ["D2750"], "denial_reason_text": "Dual coverage â€” primary payer must adjudicate first."}	1.000	deterministic
161	suwanee_smiles	PRED-SIM-DA-C08	document	XRAY-DA-C08-D02	{"pathology": "Caries extending to pulp chamber, tooth #3", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "tooth_number": 3, "decay_present": true, "image_quality": "DIAGNOSTIC"}	XRAY_PA	XRAY-DA-C08-D02	{"pathology": "Caries extending to pulp chamber, tooth #3", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "tooth_number": 3, "decay_present": true, "image_quality": "DIAGNOSTIC"}	0.700	deterministic
162	suwanee_smiles	PRED-SIM-DA-C09	document	NOTE-DA-C09-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D6010"], "diagnosis": "Implant requested for a patient on IV zoledronic acid. Osteonecrosis risk.", "narrative": "IV bisphosphonate is an absolute contraindication for implants. Caught from the medical history before the payer ever sees it â€” and before the patient is harmed.", "visit_date": "2026-08-05", "medications": ["zoledronic acid", "calcium carbonate"], "treatment_plan": "D6010 tooth #19", "cdt_codes_noted": ["D6010"], "chief_complaint": "Medical History â€” IV Bisphosphonate Before Implant", "medical_history": "Patient on IV zoledronic acid (Zometa) for metastatic bone disease, ongoing since 2024.", "narrative_present": true, "primary_diagnosis": "Implant requested for a patient on IV zoledronic acid. Osteonecrosis risk."}	CLINICAL_NOTE	NOTE-DA-C09-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D6010"], "diagnosis": "Implant requested for a patient on IV zoledronic acid. Osteonecrosis risk.", "narrative": "IV bisphosphonate is an absolute contraindication for implants. Caught from the medical history before the payer ever sees it â€” and before the patient is harmed.", "visit_date": "2026-08-05", "medications": ["zoledronic acid", "calcium carbonate"], "treatment_plan": "D6010 tooth #19", "cdt_codes_noted": ["D6010"], "chief_complaint": "Medical History â€” IV Bisphosphonate Before Implant", "medical_history": "Patient on IV zoledronic acid (Zometa) for metastatic bone disease, ongoing since 2024.", "narrative_present": true, "primary_diagnosis": "Implant requested for a patient on IV zoledronic acid. Osteonecrosis risk."}	0.900	deterministic
163	suwanee_smiles	PRED-SIM-DA-C09	document	DA-C09-PRED_LETTER	{"decision": "pended", "pred_number": "PD-DAC09", "denial_reason": "IV bisphosphonate therapy â€” osteonecrosis risk.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["CLINICAL_MEDICAL_HISTORY_FLAG"], "cdt_codes_reviewed": ["D6010"], "denial_reason_text": "IV bisphosphonate therapy â€” osteonecrosis risk."}	PRED_LETTER	DA-C09-PRED_LETTER	{"decision": "pended", "pred_number": "PD-DAC09", "denial_reason": "IV bisphosphonate therapy â€” osteonecrosis risk.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["CLINICAL_MEDICAL_HISTORY_FLAG"], "cdt_codes_reviewed": ["D6010"], "denial_reason_text": "IV bisphosphonate therapy â€” osteonecrosis risk."}	1.000	deterministic
164	suwanee_smiles	PRED-SIM-DA-C09	document	XRAY-DA-C09-D02	{"pathology": "Edentulous space #19 with healed ridge", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "bone_loss_mm": 4.2, "tooth_number": 19, "bone_loss_pct": 35.0, "image_quality": "DIAGNOSTIC"}	XRAY_PA	XRAY-DA-C09-D02	{"pathology": "Edentulous space #19 with healed ridge", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "bone_loss_mm": 4.2, "tooth_number": 19, "bone_loss_pct": 35.0, "image_quality": "DIAGNOSTIC"}	1.000	deterministic
165	suwanee_smiles	PRED-SIM-DA-C10	document	NOTE-DA-C10-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D2750"], "diagnosis": "Submitting provider appears on the OIG exclusion list. No payer will reimburse.", "narrative": "An excluded provider cannot be paid by any federal or commercial payer. Catching it pre-submission avoids a clawback", "visit_date": "2026-08-05", "treatment_plan": "D2750 tooth #14", "cdt_codes_noted": ["D2750"], "chief_complaint": "Provider Integrity â€” OIG Excluded Provider", "narrative_present": true, "primary_diagnosis": "Submitting provider appears on the OIG exclusion list. No payer will reimburse."}	CLINICAL_NOTE	NOTE-DA-C10-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D2750"], "diagnosis": "Submitting provider appears on the OIG exclusion list. No payer will reimburse.", "narrative": "An excluded provider cannot be paid by any federal or commercial payer. Catching it pre-submission avoids a clawback", "visit_date": "2026-08-05", "treatment_plan": "D2750 tooth #14", "cdt_codes_noted": ["D2750"], "chief_complaint": "Provider Integrity â€” OIG Excluded Provider", "narrative_present": true, "primary_diagnosis": "Submitting provider appears on the OIG exclusion list. No payer will reimburse."}	0.900	deterministic
166	suwanee_smiles	PRED-SIM-DA-C10	document	DA-C10-PRED_LETTER	{"decision": "pended", "pred_number": "PD-DAC10", "denial_reason": "Provider is on the OIG exclusion list.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["PROVIDER_OIG_EXCLUDED"], "cdt_codes_reviewed": ["D2750"], "denial_reason_text": "Provider is on the OIG exclusion list."}	PRED_LETTER	DA-C10-PRED_LETTER	{"decision": "pended", "pred_number": "PD-DAC10", "denial_reason": "Provider is on the OIG exclusion list.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["PROVIDER_OIG_EXCLUDED"], "cdt_codes_reviewed": ["D2750"], "denial_reason_text": "Provider is on the OIG exclusion list."}	1.000	deterministic
167	suwanee_smiles	PRED-SIM-DA-C10	document	XRAY-DA-C10-D02	{"pathology": "Caries extending to pulp chamber, tooth #14", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "tooth_number": 14, "decay_present": true, "image_quality": "DIAGNOSTIC"}	XRAY_PA	XRAY-DA-C10-D02	{"pathology": "Caries extending to pulp chamber, tooth #14", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "tooth_number": 14, "decay_present": true, "image_quality": "DIAGNOSTIC"}	0.700	deterministic
168	suwanee_smiles	PRED-SIM-DA-D01	document	NOTE-DA-D01-D04	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D4260", "D6010", "D7953"], "diagnosis": "OON periodontist billing osseous surgery plus an implant and graft at #3.", "narrative": "Two independent blockers at once â€” OON reimbursement tier plus a bundling conflict.", "visit_date": "2026-08-05", "treatment_plan": "D4260+D6010+D7953 tooth #3", "cdt_codes_noted": ["D4260", "D6010", "D7953"], "chief_complaint": "Complex â€” Out-of-Network Specialist + Bundling", "narrative_present": true, "primary_diagnosis": "OON periodontist billing osseous surgery plus an implant and graft at #3."}	CLINICAL_NOTE	NOTE-DA-D01-D04	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D4260", "D6010", "D7953"], "diagnosis": "OON periodontist billing osseous surgery plus an implant and graft at #3.", "narrative": "Two independent blockers at once â€” OON reimbursement tier plus a bundling conflict.", "visit_date": "2026-08-05", "treatment_plan": "D4260+D6010+D7953 tooth #3", "cdt_codes_noted": ["D4260", "D6010", "D7953"], "chief_complaint": "Complex â€” Out-of-Network Specialist + Bundling", "narrative_present": true, "primary_diagnosis": "OON periodontist billing osseous surgery plus an implant and graft at #3."}	0.900	deterministic
169	suwanee_smiles	PRED-SIM-DA-D01	document	PERIO-DA-D01-D02	{"exam_date": "2026-08-05", "charted_on": "2026-08-05", "bleeding_pct": 42.0, "sites_charted": 24, "sites_gte_4mm": 8, "sites_gte_5mm": 8, "sites_gte_6mm": 4, "interpretation": "Probing depths support osseous surgery per AAP criteria.", "perio_diagnosis": "Stage III Periodontitis", "pocket_depth_avg": 3.83, "pocket_depth_max": 6.0, "max_pocket_depth_mm": 6, "bleeding_on_probing_pct": 42.0}	PERIO_CHART	PERIO-DA-D01-D02	{"exam_date": "2026-08-05", "charted_on": "2026-08-05", "bleeding_pct": 42.0, "sites_charted": 24, "sites_gte_4mm": 8, "sites_gte_5mm": 8, "sites_gte_6mm": 4, "interpretation": "Probing depths support osseous surgery per AAP criteria.", "perio_diagnosis": "Stage III Periodontitis", "pocket_depth_avg": 3.83, "pocket_depth_max": 6.0, "max_pocket_depth_mm": 6, "bleeding_on_probing_pct": 42.0}	0.900	deterministic
170	suwanee_smiles	PRED-SIM-DA-D01	document	DA-D01-PRED_LETTER	{"decision": "pended", "pred_number": "PD-DAD01", "denial_reason": "Out-of-network provider and bone graft bundled with implant.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["COVERAGE_BUNDLING_CONFLICT", "PROVIDER_OUT_OF_NETWORK"], "cdt_codes_reviewed": ["D4260", "D6010", "D7953"], "denial_reason_text": "Out-of-network provider and bone graft bundled with implant."}	PRED_LETTER	DA-D01-PRED_LETTER	{"decision": "pended", "pred_number": "PD-DAD01", "denial_reason": "Out-of-network provider and bone graft bundled with implant.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["COVERAGE_BUNDLING_CONFLICT", "PROVIDER_OUT_OF_NETWORK"], "cdt_codes_reviewed": ["D4260", "D6010", "D7953"], "denial_reason_text": "Out-of-network provider and bone graft bundled with implant."}	1.000	deterministic
171	suwanee_smiles	PRED-SIM-DA-D01	document	XRAY-DA-D01-D03	{"pathology": "Edentulous space #3 with healed ridge", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "bone_loss_mm": 4.2, "tooth_number": 3, "bone_loss_pct": 35.0, "image_quality": "DIAGNOSTIC"}	XRAY_PA	XRAY-DA-D01-D03	{"pathology": "Edentulous space #3 with healed ridge", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "bone_loss_mm": 4.2, "tooth_number": 3, "bone_loss_pct": 35.0, "image_quality": "DIAGNOSTIC"}	1.000	deterministic
280	suwanee_smiles	PRED-SIM-DA-D02	document	CBCT-DA-D02-D02	{"scan_type": "cone beam CT", "xray_date": "2026-08-05", "date_taken": "2026-08-05", "bone_loss_mm": 6.8, "ridge_width_mm": 6.8, "ridge_height_mm": 11.2, "bone_volume_adequate": true}	CBCT_REPORT	CBCT-DA-D02-D02	{"scan_type": "cone beam CT", "xray_date": "2026-08-05", "date_taken": "2026-08-05", "bone_loss_mm": 6.8, "ridge_width_mm": 6.8, "ridge_height_mm": 11.2, "bone_volume_adequate": true}	0.850	deterministic
173	suwanee_smiles	PRED-SIM-DA-D02	document	NOTE-DA-D02-D04	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D6010", "D6010", "D6010", "D6010", "D7953", "D7953", "D7953", "D7953", "D6065", "D6065", "D6065", "D6065"], "diagnosis": "Twelve lines: four implants, four grafts, four crowns. Every graft bundles.", "narrative": "D6010+D6010+D6010+D6010+D7953+D7953+D7953+D7953+D6065+D6065+D6065+D6065 tooth #3, #6, #11, #14 Procedures planned: D6010, D6010, D6010, D6010, D7953, D7953, D7953, D7953, D6065, D6065, D6065, D6065 Documentation is complete, but four grafts at once always go to human review.", "visit_date": "2026-08-05", "treatment_plan": "D6010+D6010+D6010+D6010+D7953+D7953+D7953+D7953+D6065+D6065+D6065+D6065 tooth #3, #6, #11, #14", "cdt_codes_noted": ["D6010", "D6065", "D7953"], "chief_complaint": "Complex â€” All-on-4 Full Arch $35K", "narrative_present": true, "primary_diagnosis": "Twelve lines: four implants, four grafts, four crowns. Every graft bundles."}	CLINICAL_NOTE	NOTE-DA-D02-D04	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D6010", "D6010", "D6010", "D6010", "D7953", "D7953", "D7953", "D7953", "D6065", "D6065", "D6065", "D6065"], "diagnosis": "Twelve lines: four implants, four grafts, four crowns. Every graft bundles.", "narrative": "D6010+D6010+D6010+D6010+D7953+D7953+D7953+D7953+D6065+D6065+D6065+D6065 tooth #3, #6, #11, #14 Procedures planned: D6010, D6010, D6010, D6010, D7953, D7953, D7953, D7953, D6065, D6065, D6065, D6065 Documentation is complete, but four grafts at once always go to human review.", "visit_date": "2026-08-05", "treatment_plan": "D6010+D6010+D6010+D6010+D7953+D7953+D7953+D7953+D6065+D6065+D6065+D6065 tooth #3, #6, #11, #14", "cdt_codes_noted": ["D6010", "D6065", "D7953"], "chief_complaint": "Complex â€” All-on-4 Full Arch $35K", "narrative_present": true, "primary_diagnosis": "Twelve lines: four implants, four grafts, four crowns. Every graft bundles."}	0.900	deterministic
174	suwanee_smiles	PRED-SIM-DA-D02	document	DA-D02-PRED_LETTER	{"decision": "pended", "pred_number": "PD-DAD02", "denial_reason": "Four simultaneous bone grafts bundled with four implants.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["CLINICAL_NARRATIVE_REQUIRED", "COVERAGE_BUNDLING_CONFLICT"], "cdt_codes_reviewed": ["D6010", "D6065", "D7953"], "denial_reason_text": "Four simultaneous bone grafts bundled with four implants."}	PRED_LETTER	DA-D02-PRED_LETTER	{"decision": "pended", "pred_number": "PD-DAD02", "denial_reason": "Four simultaneous bone grafts bundled with four implants.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["CLINICAL_NARRATIVE_REQUIRED", "COVERAGE_BUNDLING_CONFLICT"], "cdt_codes_reviewed": ["D6010", "D6065", "D7953"], "denial_reason_text": "Four simultaneous bone grafts bundled with four implants."}	1.000	deterministic
175	suwanee_smiles	PRED-SIM-DA-D02	document	PAN-DA-D02-D03	{"pathology": "Generalized bone loss", "xray_date": "2026-08-05", "xray_type": "panoramic", "date_taken": "2026-08-05", "bone_loss_mm": 5.1, "tooth_number": null, "bone_loss_pct": 40.0, "image_quality": "DIAGNOSTIC"}	XRAY_PAN	PAN-DA-D02-D03	{"pathology": "Generalized bone loss", "xray_date": "2026-08-05", "xray_type": "panoramic", "date_taken": "2026-08-05", "bone_loss_mm": 5.1, "tooth_number": null, "bone_loss_pct": 40.0, "image_quality": "DIAGNOSTIC"}	0.850	deterministic
176	suwanee_smiles	PRED-SIM-DA-D03	document	NOTE-DA-D03-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D6010", "D6065"], "diagnosis": "Enrolled 11 months ago. Major services need 12. Denied by one month.", "narrative": "Clinically perfect and still denied â€” resubmit after the waiting period ends.", "visit_date": "2026-08-05", "treatment_plan": "D6010+D6065 tooth #19", "cdt_codes_noted": ["D6010", "D6065"], "chief_complaint": "Complex â€” Waiting Period One Month Short", "narrative_present": true, "primary_diagnosis": "Enrolled 11 months ago. Major services need 12. Denied by one month."}	CLINICAL_NOTE	NOTE-DA-D03-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D6010", "D6065"], "diagnosis": "Enrolled 11 months ago. Major services need 12. Denied by one month.", "narrative": "Clinically perfect and still denied â€” resubmit after the waiting period ends.", "visit_date": "2026-08-05", "treatment_plan": "D6010+D6065 tooth #19", "cdt_codes_noted": ["D6010", "D6065"], "chief_complaint": "Complex â€” Waiting Period One Month Short", "narrative_present": true, "primary_diagnosis": "Enrolled 11 months ago. Major services need 12. Denied by one month."}	0.900	deterministic
177	suwanee_smiles	PRED-SIM-DA-D03	document	DA-D03-PRED_LETTER	{"decision": "denied", "pred_number": "PD-DAD03", "denial_reason": "12-month waiting period not met. Eligible 09/01/2026.", "pred_decision": "DENIED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["ELIG_WAITING_PERIOD_NOT_MET"], "cdt_codes_reviewed": ["D6010", "D6065"], "denial_reason_text": "12-month waiting period not met. Eligible 09/01/2026."}	PRED_LETTER	DA-D03-PRED_LETTER	{"decision": "denied", "pred_number": "PD-DAD03", "denial_reason": "12-month waiting period not met. Eligible 09/01/2026.", "pred_decision": "DENIED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["ELIG_WAITING_PERIOD_NOT_MET"], "cdt_codes_reviewed": ["D6010", "D6065"], "denial_reason_text": "12-month waiting period not met. Eligible 09/01/2026."}	1.000	deterministic
178	suwanee_smiles	PRED-SIM-DA-D03	document	XRAY-DA-D03-D02	{"pathology": "Edentulous space #19 with healed ridge", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "bone_loss_mm": 4.2, "tooth_number": 19, "bone_loss_pct": 35.0, "image_quality": "DIAGNOSTIC"}	XRAY_PA	XRAY-DA-D03-D02	{"pathology": "Edentulous space #19 with healed ridge", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "bone_loss_mm": 4.2, "tooth_number": 19, "bone_loss_pct": 35.0, "image_quality": "DIAGNOSTIC"}	1.000	deterministic
179	suwanee_smiles	PRED-SIM-DA-D04	document	NOTE-DA-D04-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D2740"], "diagnosis": "D2740 on anterior tooth #8. Covered, but reimbursed at the D2750 PFM rate.", "narrative": "Approved, but the patient owes the all-ceramic to PFM difference â€” quote it up front.", "visit_date": "2026-08-05", "treatment_plan": "D2740 tooth #8", "cdt_codes_noted": ["D2740", "D2750"], "chief_complaint": "Complex â€” All-Ceramic Crown Downgraded", "narrative_present": true, "primary_diagnosis": "D2740 on anterior tooth #8. Covered, but reimbursed at the D2750 PFM rate."}	CLINICAL_NOTE	NOTE-DA-D04-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D2740"], "diagnosis": "D2740 on anterior tooth #8. Covered, but reimbursed at the D2750 PFM rate.", "narrative": "Approved, but the patient owes the all-ceramic to PFM difference â€” quote it up front.", "visit_date": "2026-08-05", "treatment_plan": "D2740 tooth #8", "cdt_codes_noted": ["D2740", "D2750"], "chief_complaint": "Complex â€” All-Ceramic Crown Downgraded", "narrative_present": true, "primary_diagnosis": "D2740 on anterior tooth #8. Covered, but reimbursed at the D2750 PFM rate."}	0.900	deterministic
180	suwanee_smiles	PRED-SIM-DA-D04	document	DA-D04-PRED_LETTER	{"decision": "approved", "pred_number": "PD-DAD04", "denial_reason": "", "pred_decision": "APPROVED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["COVERAGE_DOWNGRADE_APPLIED"], "cdt_codes_reviewed": ["D2740"]}	PRED_LETTER	DA-D04-PRED_LETTER	{"decision": "approved", "pred_number": "PD-DAD04", "denial_reason": "", "pred_decision": "APPROVED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["COVERAGE_DOWNGRADE_APPLIED"], "cdt_codes_reviewed": ["D2740"]}	1.000	deterministic
181	suwanee_smiles	PRED-SIM-DA-D04	document	XRAY-DA-D04-D02	{"pathology": "Caries extending to pulp chamber, tooth #8", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "tooth_number": 8, "decay_present": true, "image_quality": "DIAGNOSTIC"}	XRAY_PA	XRAY-DA-D04-D02	{"pathology": "Caries extending to pulp chamber, tooth #8", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "tooth_number": 8, "decay_present": true, "image_quality": "DIAGNOSTIC"}	0.700	deterministic
290	suwanee_smiles	PRED-SIM-DA-D05	document	CBCT-DA-D05-D04	{"scan_type": "cone beam CT", "xray_date": "2026-08-05", "date_taken": "2026-08-05", "bone_loss_mm": 6.8, "ridge_width_mm": 6.8, "ridge_height_mm": 11.2, "bone_volume_adequate": true}	CBCT_REPORT	CBCT-DA-D05-D04	{"scan_type": "cone beam CT", "xray_date": "2026-08-05", "date_taken": "2026-08-05", "bone_loss_mm": 6.8, "ridge_width_mm": 6.8, "ridge_height_mm": 11.2, "bone_volume_adequate": true}	0.850	deterministic
183	suwanee_smiles	PRED-SIM-DA-D05	document	NOTE-DA-D05-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D6010", "D7953"], "diagnosis": "DA-B04 resubmitted with PA X-ray, independent narrative and CBCT bone volume.", "narrative": "Same procedures as DA-B04 â€” complete documentation is what unbundles the graft.", "visit_date": "2026-08-05", "treatment_plan": "D6010+D7953 tooth #19", "cdt_codes_noted": ["D6010", "D7953"], "chief_complaint": "Complex â€” Bone Graft Unbundled on Resubmission", "narrative_present": true, "primary_diagnosis": "DA-B04 resubmitted with PA X-ray, independent narrative and CBCT bone volume."}	CLINICAL_NOTE	NOTE-DA-D05-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D6010", "D7953"], "diagnosis": "DA-B04 resubmitted with PA X-ray, independent narrative and CBCT bone volume.", "narrative": "Same procedures as DA-B04 â€” complete documentation is what unbundles the graft.", "visit_date": "2026-08-05", "treatment_plan": "D6010+D7953 tooth #19", "cdt_codes_noted": ["D6010", "D7953"], "chief_complaint": "Complex â€” Bone Graft Unbundled on Resubmission", "narrative_present": true, "primary_diagnosis": "DA-B04 resubmitted with PA X-ray, independent narrative and CBCT bone volume."}	0.900	deterministic
184	suwanee_smiles	PRED-SIM-DA-D05	document	DA-D05-PRED_LETTER	{"decision": "approved", "pred_number": "PD-DAD05", "denial_reason": "", "pred_decision": "APPROVED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["COVERAGE_PRED_REQUIRED"], "cdt_codes_reviewed": ["D6010", "D7953"]}	PRED_LETTER	DA-D05-PRED_LETTER	{"decision": "approved", "pred_number": "PD-DAD05", "denial_reason": "", "pred_decision": "APPROVED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["COVERAGE_PRED_REQUIRED"], "cdt_codes_reviewed": ["D6010", "D7953"]}	1.000	deterministic
185	suwanee_smiles	PRED-SIM-DA-D05	document	XRAY-DA-D05-D02	{"pathology": "Edentulous space #19 with healed ridge", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "bone_loss_mm": 4.5, "tooth_number": 19, "bone_loss_pct": 38.0, "image_quality": "DIAGNOSTIC"}	XRAY_PA	XRAY-DA-D05-D02	{"pathology": "Edentulous space #19 with healed ridge", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "bone_loss_mm": 4.5, "tooth_number": 19, "bone_loss_pct": 38.0, "image_quality": "DIAGNOSTIC"}	1.000	deterministic
186	suwanee_smiles	PRED-SIM-DA-F01	document	NOTE-DA-F01-D02	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D2750"], "diagnosis": "D2740 billed at $1,650 while the operative note documents a PFM crown (D2750).", "narrative": "$200 spread between D2740 and D2750 â€” small per case, systematic across a practice.", "visit_date": "2026-08-05", "treatment_plan": "D2740 tooth #8", "cdt_codes_noted": ["D2740", "D2750"], "chief_complaint": "Integrity â€” Upcoding All-Ceramic vs PFM", "narrative_present": true, "primary_diagnosis": "D2740 billed at $1,650 while the operative note documents a PFM crown (D2750)."}	CLINICAL_NOTE	NOTE-DA-F01-D02	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D2750"], "diagnosis": "D2740 billed at $1,650 while the operative note documents a PFM crown (D2750).", "narrative": "$200 spread between D2740 and D2750 â€” small per case, systematic across a practice.", "visit_date": "2026-08-05", "treatment_plan": "D2740 tooth #8", "cdt_codes_noted": ["D2740", "D2750"], "chief_complaint": "Integrity â€” Upcoding All-Ceramic vs PFM", "narrative_present": true, "primary_diagnosis": "D2740 billed at $1,650 while the operative note documents a PFM crown (D2750)."}	0.900	deterministic
187	suwanee_smiles	PRED-SIM-DA-F01	document	DA-F01-PRED_LETTER	{"decision": "pended", "pred_number": "PD-DAF01", "denial_reason": "Billed code contradicts the documented restoration type.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["COVERAGE_DOWNGRADE_APPLIED", "COVERAGE_SURFACE_MISMATCH"], "cdt_codes_reviewed": ["D2740"], "denial_reason_text": "Billed code contradicts the documented restoration type."}	PRED_LETTER	DA-F01-PRED_LETTER	{"decision": "pended", "pred_number": "PD-DAF01", "denial_reason": "Billed code contradicts the documented restoration type.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["COVERAGE_DOWNGRADE_APPLIED", "COVERAGE_SURFACE_MISMATCH"], "cdt_codes_reviewed": ["D2740"], "denial_reason_text": "Billed code contradicts the documented restoration type."}	1.000	deterministic
189	suwanee_smiles	PRED-SIM-DA-F02	document	NOTE-DA-F02-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D4260"], "diagnosis": "D4260 billed with a chart showing 3mm pockets â€” surgery is not clinically indicated.", "narrative": "The chart was measured and disproves necessity â€” deny, don't pend for more documents.", "visit_date": "2026-08-05", "treatment_plan": "D4260 tooth multiple quadrants", "cdt_codes_noted": ["D4260"], "chief_complaint": "Integrity â€” Phantom Osseous Surgery", "narrative_present": true, "primary_diagnosis": "D4260 billed with a chart showing 3mm pockets â€” surgery is not clinically indicated."}	CLINICAL_NOTE	NOTE-DA-F02-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D4260"], "diagnosis": "D4260 billed with a chart showing 3mm pockets â€” surgery is not clinically indicated.", "narrative": "The chart was measured and disproves necessity â€” deny, don't pend for more documents.", "visit_date": "2026-08-05", "treatment_plan": "D4260 tooth multiple quadrants", "cdt_codes_noted": ["D4260"], "chief_complaint": "Integrity â€” Phantom Osseous Surgery", "narrative_present": true, "primary_diagnosis": "D4260 billed with a chart showing 3mm pockets â€” surgery is not clinically indicated."}	0.900	deterministic
190	suwanee_smiles	PRED-SIM-DA-F02	document	PERIO-DA-F02-D02	{"exam_date": "2026-08-05", "charted_on": "2026-08-05", "bleeding_pct": 8.0, "sites_charted": 24, "sites_gte_4mm": 0, "sites_gte_5mm": 0, "sites_gte_6mm": 0, "interpretation": "Probing depths do not meet the AAP threshold for osseous surgery. Non-surgical therapy is indicated before any", "perio_diagnosis": "Gingivitis / no attachment loss", "pocket_depth_avg": 2.04, "pocket_depth_max": 3.0, "max_pocket_depth_mm": 3, "bleeding_on_probing_pct": 8.0}	PERIO_CHART	PERIO-DA-F02-D02	{"exam_date": "2026-08-05", "charted_on": "2026-08-05", "bleeding_pct": 8.0, "sites_charted": 24, "sites_gte_4mm": 0, "sites_gte_5mm": 0, "sites_gte_6mm": 0, "interpretation": "Probing depths do not meet the AAP threshold for osseous surgery. Non-surgical therapy is indicated before any", "perio_diagnosis": "Gingivitis / no attachment loss", "pocket_depth_avg": 2.04, "pocket_depth_max": 3.0, "max_pocket_depth_mm": 3, "bleeding_on_probing_pct": 8.0}	0.900	deterministic
191	suwanee_smiles	PRED-SIM-DA-F02	document	DA-F02-PRED_LETTER	{"decision": "denied", "pred_number": "PD-DAF02", "denial_reason": "Pocket depths of 3mm do not meet the 5mm surgical threshold.", "pred_decision": "DENIED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["CLINICAL_CRITERIA_NOT_MET", "CLINICAL_POCKET_DEPTH"], "cdt_codes_reviewed": ["D4260"], "denial_reason_text": "Pocket depths of 3mm do not meet the 5mm surgical threshold."}	PRED_LETTER	DA-F02-PRED_LETTER	{"decision": "denied", "pred_number": "PD-DAF02", "denial_reason": "Pocket depths of 3mm do not meet the 5mm surgical threshold.", "pred_decision": "DENIED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["CLINICAL_CRITERIA_NOT_MET", "CLINICAL_POCKET_DEPTH"], "cdt_codes_reviewed": ["D4260"], "denial_reason_text": "Pocket depths of 3mm do not meet the 5mm surgical threshold."}	1.000	deterministic
192	suwanee_smiles	PRED-SIM-DA-F03	document	NOTE-DA-F03-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D2750"], "diagnosis": "Crown resubmitted 4 years 11 months after the last one â€” one month inside the 5-year limit.", "narrative": "One month short. Timing repeatedly just inside the window is the pattern worth flagging.", "visit_date": "2026-08-05", "treatment_plan": "D2750 tooth #3", "cdt_codes_noted": ["D2750"], "chief_complaint": "Integrity â€” Frequency Gaming", "narrative_present": true, "primary_diagnosis": "Crown resubmitted 4 years 11 months after the last one â€” one month inside the 5-year limit."}	CLINICAL_NOTE	NOTE-DA-F03-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D2750"], "diagnosis": "Crown resubmitted 4 years 11 months after the last one â€” one month inside the 5-year limit.", "narrative": "One month short. Timing repeatedly just inside the window is the pattern worth flagging.", "visit_date": "2026-08-05", "treatment_plan": "D2750 tooth #3", "cdt_codes_noted": ["D2750"], "chief_complaint": "Integrity â€” Frequency Gaming", "narrative_present": true, "primary_diagnosis": "Crown resubmitted 4 years 11 months after the last one â€” one month inside the 5-year limit."}	0.900	deterministic
193	suwanee_smiles	PRED-SIM-DA-F03	document	DA-F03-PRED_LETTER	{"decision": "denied", "pred_number": "PD-DAF03", "denial_reason": "Crown frequency limit â€” last paid 09/02/2021, next eligible 09/02/2026.", "pred_decision": "DENIED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["ELIG_FREQUENCY_LIMIT"], "cdt_codes_reviewed": ["D2750"], "denial_reason_text": "Crown frequency limit â€” last paid 09/02/2021, next eligible 09/02/2026."}	PRED_LETTER	DA-F03-PRED_LETTER	{"decision": "denied", "pred_number": "PD-DAF03", "denial_reason": "Crown frequency limit â€” last paid 09/02/2021, next eligible 09/02/2026.", "pred_decision": "DENIED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["ELIG_FREQUENCY_LIMIT"], "cdt_codes_reviewed": ["D2750"], "denial_reason_text": "Crown frequency limit â€” last paid 09/02/2021, next eligible 09/02/2026."}	1.000	deterministic
194	suwanee_smiles	PRED-SIM-DA-F03	document	XRAY-DA-F03-D02	{"pathology": "Caries extending to pulp chamber, tooth #3", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "tooth_number": 3, "decay_present": true, "image_quality": "DIAGNOSTIC"}	XRAY_PA	XRAY-DA-F03-D02	{"pathology": "Caries extending to pulp chamber, tooth #3", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "tooth_number": 3, "decay_present": true, "image_quality": "DIAGNOSTIC"}	0.700	deterministic
195	suwanee_smiles	PRED-SIM-DA-F04	document	NOTE-DA-F04-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D2750"], "diagnosis": "Core buildup billed the day before the crown to dodge the same-date bundling edit.", "narrative": "Splitting the date does not separate the service â€” the bundling edit follows the tooth.", "visit_date": "2026-08-05", "treatment_plan": "D2750 tooth #14", "cdt_codes_noted": ["D2750"], "chief_complaint": "Integrity â€” Unbundling by Date Split", "narrative_present": true, "primary_diagnosis": "Core buildup billed the day before the crown to dodge the same-date bundling edit."}	CLINICAL_NOTE	NOTE-DA-F04-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D2750"], "diagnosis": "Core buildup billed the day before the crown to dodge the same-date bundling edit.", "narrative": "Splitting the date does not separate the service â€” the bundling edit follows the tooth.", "visit_date": "2026-08-05", "treatment_plan": "D2750 tooth #14", "cdt_codes_noted": ["D2750"], "chief_complaint": "Integrity â€” Unbundling by Date Split", "narrative_present": true, "primary_diagnosis": "Core buildup billed the day before the crown to dodge the same-date bundling edit."}	0.900	deterministic
196	suwanee_smiles	PRED-SIM-DA-F04	document	DA-F04-PRED_LETTER	{"decision": "pended", "pred_number": "PD-DAF04", "denial_reason": "Core buildup billed one day earlier is still bundled with the crown.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["COVERAGE_BUNDLING_CONFLICT"], "cdt_codes_reviewed": ["D2750"], "denial_reason_text": "Core buildup billed one day earlier is still bundled with the crown."}	PRED_LETTER	DA-F04-PRED_LETTER	{"decision": "pended", "pred_number": "PD-DAF04", "denial_reason": "Core buildup billed one day earlier is still bundled with the crown.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["COVERAGE_BUNDLING_CONFLICT"], "cdt_codes_reviewed": ["D2750"], "denial_reason_text": "Core buildup billed one day earlier is still bundled with the crown."}	1.000	deterministic
197	suwanee_smiles	PRED-SIM-DA-F04	document	XRAY-DA-F04-D02	{"pathology": "Caries extending to pulp chamber, tooth #14", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "tooth_number": 14, "decay_present": true, "image_quality": "DIAGNOSTIC"}	XRAY_PA	XRAY-DA-F04-D02	{"pathology": "Caries extending to pulp chamber, tooth #14", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "tooth_number": 14, "decay_present": true, "image_quality": "DIAGNOSTIC"}	0.700	deterministic
198	suwanee_smiles	PRED-SIM-DA-F05	document	NOTE-DA-F05-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D6010"], "diagnosis": "Submitted fee equals the payer allowed amount exactly â€” the patient share appears waived.", "narrative": "Routine waiver of patient responsibility is an inducement â€” hold for senior review.", "visit_date": "2026-08-05", "treatment_plan": "D6010 tooth #19", "cdt_codes_noted": ["D6010"], "chief_complaint": "Integrity â€” Waived Copay Signal", "narrative_present": true, "primary_diagnosis": "Submitted fee equals the payer allowed amount exactly â€” the patient share appears waived."}	CLINICAL_NOTE	NOTE-DA-F05-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D6010"], "diagnosis": "Submitted fee equals the payer allowed amount exactly â€” the patient share appears waived.", "narrative": "Routine waiver of patient responsibility is an inducement â€” hold for senior review.", "visit_date": "2026-08-05", "treatment_plan": "D6010 tooth #19", "cdt_codes_noted": ["D6010"], "chief_complaint": "Integrity â€” Waived Copay Signal", "narrative_present": true, "primary_diagnosis": "Submitted fee equals the payer allowed amount exactly â€” the patient share appears waived."}	0.900	deterministic
199	suwanee_smiles	PRED-SIM-DA-F05	document	DA-F05-PRED_LETTER	{"decision": "pended", "pred_number": "PD-DAF05", "denial_reason": "Submitted fee matches allowed amount exactly â€” routed to review.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["COVERAGE_PRED_REQUIRED"], "cdt_codes_reviewed": ["D6010"], "denial_reason_text": "Submitted fee matches allowed amount exactly â€” routed to review."}	PRED_LETTER	DA-F05-PRED_LETTER	{"decision": "pended", "pred_number": "PD-DAF05", "denial_reason": "Submitted fee matches allowed amount exactly â€” routed to review.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["COVERAGE_PRED_REQUIRED"], "cdt_codes_reviewed": ["D6010"], "denial_reason_text": "Submitted fee matches allowed amount exactly â€” routed to review."}	1.000	deterministic
200	suwanee_smiles	PRED-SIM-DA-F05	document	XRAY-DA-F05-D02	{"pathology": "Edentulous space #19 with healed ridge", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "bone_loss_mm": 4.2, "tooth_number": 19, "bone_loss_pct": 35.0, "image_quality": "DIAGNOSTIC"}	XRAY_PA	XRAY-DA-F05-D02	{"pathology": "Edentulous space #19 with healed ridge", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "bone_loss_mm": 4.2, "tooth_number": 19, "bone_loss_pct": 35.0, "image_quality": "DIAGNOSTIC"}	1.000	deterministic
201	suwanee_smiles	PRED-SIM-DA-M01	document	NOTE-DA-M01-D04	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D2750"], "diagnosis": "Insurance card and X12 271 report different member IDs for the same patient.", "narrative": "Identity must reconcile before coverage means anything â€” contradicts edge on member_id.", "visit_date": "2026-08-05", "treatment_plan": "D2750 tooth #19", "cdt_codes_noted": ["D2750"], "chief_complaint": "Messy â€” Member ID Mismatch", "narrative_present": true, "primary_diagnosis": "Insurance card and X12 271 report different member IDs for the same patient."}	CLINICAL_NOTE	NOTE-DA-M01-D04	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D2750"], "diagnosis": "Insurance card and X12 271 report different member IDs for the same patient.", "narrative": "Identity must reconcile before coverage means anything â€” contradicts edge on member_id.", "visit_date": "2026-08-05", "treatment_plan": "D2750 tooth #19", "cdt_codes_noted": ["D2750"], "chief_complaint": "Messy â€” Member ID Mismatch", "narrative_present": true, "primary_diagnosis": "Insurance card and X12 271 report different member IDs for the same patient."}	0.900	deterministic
203	suwanee_smiles	PRED-SIM-DA-M01	document	DA-M01-PRED_LETTER	{"decision": "pended", "pred_number": "PD-DAM01", "denial_reason": "Member ID on the card contradicts the eligibility response.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["ELIG_PLAN_NOT_FOUND"], "cdt_codes_reviewed": ["D2750"], "denial_reason_text": "Member ID on the card contradicts the eligibility response."}	PRED_LETTER	DA-M01-PRED_LETTER	{"decision": "pended", "pred_number": "PD-DAM01", "denial_reason": "Member ID on the card contradicts the eligibility response.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["ELIG_PLAN_NOT_FOUND"], "cdt_codes_reviewed": ["D2750"], "denial_reason_text": "Member ID on the card contradicts the eligibility response."}	1.000	deterministic
204	suwanee_smiles	PRED-SIM-DA-M01	document	XRAY-DA-M01-D03	{"pathology": "Caries extending to pulp chamber, tooth #19", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "tooth_number": 19, "decay_present": true, "image_quality": "DIAGNOSTIC"}	XRAY_PA	XRAY-DA-M01-D03	{"pathology": "Caries extending to pulp chamber, tooth #19", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "tooth_number": 19, "decay_present": true, "image_quality": "DIAGNOSTIC"}	0.700	deterministic
205	suwanee_smiles	PRED-SIM-DA-M02	document	NOTE-DA-M02-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D4341"], "diagnosis": "D4260 osseous surgery billed, but the note describes D4341 scaling only.", "narrative": "Pocket depths support surgery but the operative note does not â€” reconcile before submitting.", "visit_date": "2026-08-05", "treatment_plan": "D4260 tooth multiple quadrants", "cdt_codes_noted": ["D4260", "D4341"], "chief_complaint": "Messy â€” Procedure Code Contradicts Narrative", "narrative_present": true, "primary_diagnosis": "D4260 osseous surgery billed, but the note describes D4341 scaling only."}	CLINICAL_NOTE	NOTE-DA-M02-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D4341"], "diagnosis": "D4260 osseous surgery billed, but the note describes D4341 scaling only.", "narrative": "Pocket depths support surgery but the operative note does not â€” reconcile before submitting.", "visit_date": "2026-08-05", "treatment_plan": "D4260 tooth multiple quadrants", "cdt_codes_noted": ["D4260", "D4341"], "chief_complaint": "Messy â€” Procedure Code Contradicts Narrative", "narrative_present": true, "primary_diagnosis": "D4260 osseous surgery billed, but the note describes D4341 scaling only."}	0.900	deterministic
206	suwanee_smiles	PRED-SIM-DA-M02	document	PERIO-DA-M02-D02	{"exam_date": "2026-08-05", "charted_on": "2026-08-05", "bleeding_pct": 42.0, "sites_charted": 24, "sites_gte_4mm": 8, "sites_gte_5mm": 8, "sites_gte_6mm": 4, "interpretation": "Probing depths support osseous surgery per AAP criteria.", "perio_diagnosis": "Stage III Periodontitis", "pocket_depth_avg": 3.83, "pocket_depth_max": 6.0, "max_pocket_depth_mm": 6, "bleeding_on_probing_pct": 42.0}	PERIO_CHART	PERIO-DA-M02-D02	{"exam_date": "2026-08-05", "charted_on": "2026-08-05", "bleeding_pct": 42.0, "sites_charted": 24, "sites_gte_4mm": 8, "sites_gte_5mm": 8, "sites_gte_6mm": 4, "interpretation": "Probing depths support osseous surgery per AAP criteria.", "perio_diagnosis": "Stage III Periodontitis", "pocket_depth_avg": 3.83, "pocket_depth_max": 6.0, "max_pocket_depth_mm": 6, "bleeding_on_probing_pct": 42.0}	0.900	deterministic
207	suwanee_smiles	PRED-SIM-DA-M02	document	DA-M02-PRED_LETTER	{"decision": "pended", "pred_number": "PD-DAM02", "denial_reason": "Narrative documents scaling, not osseous surgery.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["CLINICAL_CRITERIA_NOT_MET"], "cdt_codes_reviewed": ["D4260"], "denial_reason_text": "Narrative documents scaling, not osseous surgery."}	PRED_LETTER	DA-M02-PRED_LETTER	{"decision": "pended", "pred_number": "PD-DAM02", "denial_reason": "Narrative documents scaling, not osseous surgery.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["CLINICAL_CRITERIA_NOT_MET"], "cdt_codes_reviewed": ["D4260"], "denial_reason_text": "Narrative documents scaling, not osseous surgery."}	1.000	deterministic
208	suwanee_smiles	PRED-SIM-DA-M03	document	NOTE-DA-M03-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D2750"], "diagnosis": "Crown billed MOD; the radiograph documents a DO restoration.", "narrative": "Surface mismatches drive post-payment recoupment â€” catch them before submission.", "visit_date": "2026-08-05", "treatment_plan": "D2750 tooth #14", "cdt_codes_noted": ["D2750"], "chief_complaint": "Messy â€” Tooth Surface Conflict", "narrative_present": true, "primary_diagnosis": "Crown billed MOD; the radiograph documents a DO restoration."}	CLINICAL_NOTE	NOTE-DA-M03-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D2750"], "diagnosis": "Crown billed MOD; the radiograph documents a DO restoration.", "narrative": "Surface mismatches drive post-payment recoupment â€” catch them before submission.", "visit_date": "2026-08-05", "treatment_plan": "D2750 tooth #14", "cdt_codes_noted": ["D2750"], "chief_complaint": "Messy â€” Tooth Surface Conflict", "narrative_present": true, "primary_diagnosis": "Crown billed MOD; the radiograph documents a DO restoration."}	0.900	deterministic
209	suwanee_smiles	PRED-SIM-DA-M03	document	DA-M03-PRED_LETTER	{"decision": "pended", "pred_number": "PD-DAM03", "denial_reason": "Billed surface MOD contradicts the documented DO surface.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["COVERAGE_SURFACE_MISMATCH"], "cdt_codes_reviewed": ["D2750"], "denial_reason_text": "Billed surface MOD contradicts the documented DO surface."}	PRED_LETTER	DA-M03-PRED_LETTER	{"decision": "pended", "pred_number": "PD-DAM03", "denial_reason": "Billed surface MOD contradicts the documented DO surface.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["COVERAGE_SURFACE_MISMATCH"], "cdt_codes_reviewed": ["D2750"], "denial_reason_text": "Billed surface MOD contradicts the documented DO surface."}	1.000	deterministic
210	suwanee_smiles	PRED-SIM-DA-M03	document	XRAY-DA-M03-D02	{"pathology": "Caries extending to pulp chamber, tooth #14", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "tooth_number": 14, "decay_present": true, "image_quality": "DIAGNOSTIC", "tooth_surface": "DO"}	XRAY_PA	XRAY-DA-M03-D02	{"pathology": "Caries extending to pulp chamber, tooth #14", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "tooth_number": 14, "decay_present": true, "image_quality": "DIAGNOSTIC", "tooth_surface": "DO"}	0.700	deterministic
211	suwanee_smiles	PRED-SIM-DA-M04	document	NOTE-DA-M04-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D6010"], "diagnosis": "An open pre-D already exists for the same member, tooth and CDT code.", "narrative": "Duplicate submissions reset the payer clock â€” detect on member + code + tooth.", "visit_date": "2026-08-05", "treatment_plan": "D6010 tooth #19", "cdt_codes_noted": ["D6010"], "chief_complaint": "Messy â€” Duplicate Pre-Determination", "narrative_present": true, "primary_diagnosis": "An open pre-D already exists for the same member, tooth and CDT code."}	CLINICAL_NOTE	NOTE-DA-M04-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D6010"], "diagnosis": "An open pre-D already exists for the same member, tooth and CDT code.", "narrative": "Duplicate submissions reset the payer clock â€” detect on member + code + tooth.", "visit_date": "2026-08-05", "treatment_plan": "D6010 tooth #19", "cdt_codes_noted": ["D6010"], "chief_complaint": "Messy â€” Duplicate Pre-Determination", "narrative_present": true, "primary_diagnosis": "An open pre-D already exists for the same member, tooth and CDT code."}	0.900	deterministic
212	suwanee_smiles	PRED-SIM-DA-M04	document	DA-M04-PRED_LETTER	{"decision": "pended", "pred_number": "PD-DAM04", "denial_reason": "Duplicate of an open pre-D for the same tooth and code.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["ADMIN_DUPLICATE_PRED"], "cdt_codes_reviewed": ["D6010"], "denial_reason_text": "Duplicate of an open pre-D for the same tooth and code."}	PRED_LETTER	DA-M04-PRED_LETTER	{"decision": "pended", "pred_number": "PD-DAM04", "denial_reason": "Duplicate of an open pre-D for the same tooth and code.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["ADMIN_DUPLICATE_PRED"], "cdt_codes_reviewed": ["D6010"], "denial_reason_text": "Duplicate of an open pre-D for the same tooth and code."}	1.000	deterministic
213	suwanee_smiles	PRED-SIM-DA-M04	document	XRAY-DA-M04-D02	{"pathology": "Edentulous space #19 with healed ridge", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "bone_loss_mm": 4.2, "tooth_number": 19, "bone_loss_pct": 35.0, "image_quality": "DIAGNOSTIC"}	XRAY_PA	XRAY-DA-M04-D02	{"pathology": "Edentulous space #19 with healed ridge", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "bone_loss_mm": 4.2, "tooth_number": 19, "bone_loss_pct": 35.0, "image_quality": "DIAGNOSTIC"}	1.000	deterministic
433	suwanee_smiles	PRED-SIM-DA-U01	document	NOTE-DA-U01-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D1110"], "diagnosis": "D1110 adult cleaning, Delta Dental PPO. The simplest case the platform can see.", "narrative": "100% preventive, 2 per year, last cleaning outside the window. Nothing to hold â€” and the platform has to be able to say so without a human reading it.", "visit_date": "2026-08-06", "treatment_plan": "D1110 tooth multiple quadrants", "cdt_codes_noted": ["D1110"], "chief_complaint": "Uncontested â€” Adult Prophylaxis", "narrative_present": true, "primary_diagnosis": "D1110 adult cleaning, Delta Dental PPO. The simplest case the platform can see."}	CLINICAL_NOTE	NOTE-DA-U01-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D1110"], "diagnosis": "D1110 adult cleaning, Delta Dental PPO. The simplest case the platform can see.", "narrative": "100% preventive, 2 per year, last cleaning outside the window. Nothing to hold â€” and the platform has to be able to say so without a human reading it.", "visit_date": "2026-08-06", "treatment_plan": "D1110 tooth multiple quadrants", "cdt_codes_noted": ["D1110"], "chief_complaint": "Uncontested â€” Adult Prophylaxis", "narrative_present": true, "primary_diagnosis": "D1110 adult cleaning, Delta Dental PPO. The simplest case the platform can see."}	0.900	deterministic
214	suwanee_smiles	PRED-SIM-DA-M05	document	NOTE-DA-M05-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D2750"], "diagnosis": "Faxed radiograph extracts at 0.45 confidence; the finding cannot be relied on.", "narrative": "A finding extracted at 0.45 confidence is not evidence â€” re-request a diagnostic image.", "visit_date": "2026-08-05", "treatment_plan": "D2750 tooth #3", "cdt_codes_noted": ["D2750"], "chief_complaint": "Messy â€” Low-Confidence Scanned Extraction", "narrative_present": true, "primary_diagnosis": "Faxed radiograph extracts at 0.45 confidence; the finding cannot be relied on."}	CLINICAL_NOTE	NOTE-DA-M05-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D2750"], "diagnosis": "Faxed radiograph extracts at 0.45 confidence; the finding cannot be relied on.", "narrative": "A finding extracted at 0.45 confidence is not evidence â€” re-request a diagnostic image.", "visit_date": "2026-08-05", "treatment_plan": "D2750 tooth #3", "cdt_codes_noted": ["D2750"], "chief_complaint": "Messy â€” Low-Confidence Scanned Extraction", "narrative_present": true, "primary_diagnosis": "Faxed radiograph extracts at 0.45 confidence; the finding cannot be relied on."}	0.900	deterministic
215	suwanee_smiles	PRED-SIM-DA-M05	document	DA-M05-PRED_LETTER	{"decision": "pended", "pred_number": "PD-DAM05", "denial_reason": "Radiograph extraction below the 0.70 confidence floor.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["CLINICAL_XRAY_REQUIRED"], "cdt_codes_reviewed": ["D2750"], "denial_reason_text": "Radiograph extraction below the 0.70 confidence floor."}	PRED_LETTER	DA-M05-PRED_LETTER	{"decision": "pended", "pred_number": "PD-DAM05", "denial_reason": "Radiograph extraction below the 0.70 confidence floor.", "pred_decision": "PENDED", "response_date": "2026-08-05", "appeal_deadline": "2027-02-01", "condition_codes": ["CLINICAL_XRAY_REQUIRED"], "cdt_codes_reviewed": ["D2750"], "denial_reason_text": "Radiograph extraction below the 0.70 confidence floor."}	1.000	deterministic
216	suwanee_smiles	PRED-SIM-DA-M05	document	XRAY-DA-M05-D02	{"pathology": "Caries extending to pulp chamber, tooth #3", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "tooth_number": 3, "decay_present": true, "image_quality": "SUBOPTIMAL"}	XRAY_PA	XRAY-DA-M05-D02	{"pathology": "Caries extending to pulp chamber, tooth #3", "xray_date": "2026-08-05", "xray_type": "periapical", "date_taken": "2026-08-05", "tooth_number": 3, "decay_present": true, "image_quality": "SUBOPTIMAL"}	0.750	ai_vision
434	suwanee_smiles	PRED-SIM-DA-U01	document	INS-DA-U01-CARD-D02	{"payer_id": "delta_dental", "member_id": "DDL-201455-T", "plan_type": "PPO", "group_number": "GRP-44821", "coverage_active": true}	INSURANCE_CARD	INS-DA-U01-CARD-D02	{"payer_id": "delta_dental", "member_id": "DDL-201455-T", "plan_type": "PPO", "group_number": "GRP-44821", "coverage_active": true}	0.950	caller_supplied
435	suwanee_smiles	PRED-SIM-DA-U01	document	DA-U01-PRED_LETTER	{"decision": "approved", "pred_number": "PD-DAU01", "denial_reason": "", "pred_decision": "APPROVED", "response_date": "2026-08-06", "appeal_deadline": "2027-02-02", "condition_codes": [], "cdt_codes_reviewed": ["D1110"]}	PRED_LETTER	DA-U01-PRED_LETTER	{"decision": "approved", "pred_number": "PD-DAU01", "denial_reason": "", "pred_decision": "APPROVED", "response_date": "2026-08-06", "appeal_deadline": "2027-02-02", "condition_codes": [], "cdt_codes_reviewed": ["D1110"]}	1.000	deterministic
436	suwanee_smiles	PRED-SIM-DA-U02	document	NOTE-DA-U02-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D0274"], "diagnosis": "D0274 diagnostic films, Delta Dental PPO. Last set taken over a year ago.", "narrative": "Diagnostic imaging at 100%, 1 per year. The frequency check runs and clears â€” the same check that denies DA-F03", "visit_date": "2026-08-06", "treatment_plan": "D0274 tooth multiple quadrants", "cdt_codes_noted": ["D0274"], "chief_complaint": "Uncontested â€” Four Bitewing Radiographs", "narrative_present": true, "primary_diagnosis": "D0274 diagnostic films, Delta Dental PPO. Last set taken over a year ago."}	CLINICAL_NOTE	NOTE-DA-U02-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D0274"], "diagnosis": "D0274 diagnostic films, Delta Dental PPO. Last set taken over a year ago.", "narrative": "Diagnostic imaging at 100%, 1 per year. The frequency check runs and clears â€” the same check that denies DA-F03", "visit_date": "2026-08-06", "treatment_plan": "D0274 tooth multiple quadrants", "cdt_codes_noted": ["D0274"], "chief_complaint": "Uncontested â€” Four Bitewing Radiographs", "narrative_present": true, "primary_diagnosis": "D0274 diagnostic films, Delta Dental PPO. Last set taken over a year ago."}	0.900	deterministic
439	suwanee_smiles	PRED-SIM-DA-U03	document	NOTE-DA-U03-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D2391"], "diagnosis": "D2391 one-surface composite on tooth #14 under Cigna DPPO. Basic service, no pre-D.", "narrative": "A direct restoration is a basic service â€” 80%, no pre-determination, no clinical criteria. The complexity in this catalogue is the exception, not the rule.", "visit_date": "2026-08-06", "treatment_plan": "D2391 tooth #14", "cdt_codes_noted": ["D2391"], "chief_complaint": "Uncontested â€” Posterior Composite Filling", "narrative_present": true, "primary_diagnosis": "D2391 one-surface composite on tooth #14 under Cigna DPPO. Basic service, no pre-D."}	CLINICAL_NOTE	NOTE-DA-U03-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D2391"], "diagnosis": "D2391 one-surface composite on tooth #14 under Cigna DPPO. Basic service, no pre-D.", "narrative": "A direct restoration is a basic service â€” 80%, no pre-determination, no clinical criteria. The complexity in this catalogue is the exception, not the rule.", "visit_date": "2026-08-06", "treatment_plan": "D2391 tooth #14", "cdt_codes_noted": ["D2391"], "chief_complaint": "Uncontested â€” Posterior Composite Filling", "narrative_present": true, "primary_diagnosis": "D2391 one-surface composite on tooth #14 under Cigna DPPO. Basic service, no pre-D."}	0.900	deterministic
440	suwanee_smiles	PRED-SIM-DA-U03	document	INS-DA-U03-CARD-D02	{"payer_id": "cigna", "member_id": "CIG-889302-L", "plan_type": "DPPO", "group_number": "GRP-CIG-01", "coverage_active": true}	INSURANCE_CARD	INS-DA-U03-CARD-D02	{"payer_id": "cigna", "member_id": "CIG-889302-L", "plan_type": "DPPO", "group_number": "GRP-CIG-01", "coverage_active": true}	0.950	caller_supplied
441	suwanee_smiles	PRED-SIM-DA-U03	document	DA-U03-PRED_LETTER	{"decision": "approved", "pred_number": "PD-DAU03", "denial_reason": "", "pred_decision": "APPROVED", "response_date": "2026-08-06", "appeal_deadline": "2027-02-02", "condition_codes": [], "cdt_codes_reviewed": ["D2391"]}	PRED_LETTER	DA-U03-PRED_LETTER	{"decision": "approved", "pred_number": "PD-DAU03", "denial_reason": "", "pred_decision": "APPROVED", "response_date": "2026-08-06", "appeal_deadline": "2027-02-02", "condition_codes": [], "cdt_codes_reviewed": ["D2391"]}	1.000	deterministic
442	suwanee_smiles	PRED-SIM-DA-U04	document	NOTE-DA-U04-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D7140"], "diagnosis": "D7140 erupted tooth #32 under MetLife PDP. No surgical flap, no bone removal.", "narrative": "A simple extraction is a basic service, so no major-services waiting period applies â€” the distinction that denies DA-B05 the same month it is enrolled.", "visit_date": "2026-08-06", "treatment_plan": "D7140 tooth #32", "cdt_codes_noted": ["D7140"], "chief_complaint": "Uncontested â€” Simple Extraction", "narrative_present": true, "primary_diagnosis": "D7140 erupted tooth #32 under MetLife PDP. No surgical flap, no bone removal."}	CLINICAL_NOTE	NOTE-DA-U04-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D7140"], "diagnosis": "D7140 erupted tooth #32 under MetLife PDP. No surgical flap, no bone removal.", "narrative": "A simple extraction is a basic service, so no major-services waiting period applies â€” the distinction that denies DA-B05 the same month it is enrolled.", "visit_date": "2026-08-06", "treatment_plan": "D7140 tooth #32", "cdt_codes_noted": ["D7140"], "chief_complaint": "Uncontested â€” Simple Extraction", "narrative_present": true, "primary_diagnosis": "D7140 erupted tooth #32 under MetLife PDP. No surgical flap, no bone removal."}	0.900	deterministic
443	suwanee_smiles	PRED-SIM-DA-U04	document	INS-DA-U04-CARD-D02	{"payer_id": "metlife", "member_id": "MET-556128-C", "plan_type": "PDP", "group_number": "GRP-MET-04", "coverage_active": true}	INSURANCE_CARD	INS-DA-U04-CARD-D02	{"payer_id": "metlife", "member_id": "MET-556128-C", "plan_type": "PDP", "group_number": "GRP-MET-04", "coverage_active": true}	0.950	caller_supplied
444	suwanee_smiles	PRED-SIM-DA-U04	document	DA-U04-PRED_LETTER	{"decision": "approved", "pred_number": "PD-DAU04", "denial_reason": "", "pred_decision": "APPROVED", "response_date": "2026-08-06", "appeal_deadline": "2027-02-02", "condition_codes": [], "cdt_codes_reviewed": ["D7140"]}	PRED_LETTER	DA-U04-PRED_LETTER	{"decision": "approved", "pred_number": "PD-DAU04", "denial_reason": "", "pred_decision": "APPROVED", "response_date": "2026-08-06", "appeal_deadline": "2027-02-02", "condition_codes": [], "cdt_codes_reviewed": ["D7140"]}	1.000	deterministic
445	suwanee_smiles	PRED-SIM-DA-U05	document	NOTE-DA-U05-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D4910"], "diagnosis": "D4910 for an established perio patient, Delta Dental PPO. First maintenance this year.", "narrative": "Maintenance after active periodontal therapy, 4 per year on this plan and none used in the window. Stable pockets are", "visit_date": "2026-08-06", "treatment_plan": "D4910 tooth multiple quadrants", "cdt_codes_noted": ["D4910"], "chief_complaint": "Uncontested â€” Periodontal Maintenance", "narrative_present": true, "primary_diagnosis": "D4910 for an established perio patient, Delta Dental PPO. First maintenance this year."}	CLINICAL_NOTE	NOTE-DA-U05-D03	{"provider": "Dr. Sridhar Chinta, DDS", "cdt_codes": ["D4910"], "diagnosis": "D4910 for an established perio patient, Delta Dental PPO. First maintenance this year.", "narrative": "Maintenance after active periodontal therapy, 4 per year on this plan and none used in the window. Stable pockets are", "visit_date": "2026-08-06", "treatment_plan": "D4910 tooth multiple quadrants", "cdt_codes_noted": ["D4910"], "chief_complaint": "Uncontested â€” Periodontal Maintenance", "narrative_present": true, "primary_diagnosis": "D4910 for an established perio patient, Delta Dental PPO. First maintenance this year."}	0.900	deterministic
446	suwanee_smiles	PRED-SIM-DA-U05	document	INS-DA-U05-CARD-D02	{"payer_id": "delta_dental", "member_id": "DDL-447215-W", "plan_type": "PPO", "group_number": "GRP-44821", "coverage_active": true}	INSURANCE_CARD	INS-DA-U05-CARD-D02	{"payer_id": "delta_dental", "member_id": "DDL-447215-W", "plan_type": "PPO", "group_number": "GRP-44821", "coverage_active": true}	0.950	caller_supplied
447	suwanee_smiles	PRED-SIM-DA-U05	document	PERIO-DA-U05-D04	{"exam_date": "2026-08-06", "charted_on": "2026-08-06", "bleeding_pct": 42.0, "sites_charted": 24, "sites_gte_4mm": 1, "sites_gte_5mm": 0, "sites_gte_6mm": 0, "interpretation": "Probing depths do not meet the AAP threshold for osseous surgery. Non-surgical therapy is indicated before any", "perio_diagnosis": "Stage I Periodontitis", "pocket_depth_avg": 2.08, "pocket_depth_max": 4.0, "max_pocket_depth_mm": 4, "bleeding_on_probing_pct": 42.0}	PERIO_CHART	PERIO-DA-U05-D04	{"exam_date": "2026-08-06", "charted_on": "2026-08-06", "bleeding_pct": 42.0, "sites_charted": 24, "sites_gte_4mm": 1, "sites_gte_5mm": 0, "sites_gte_6mm": 0, "interpretation": "Probing depths do not meet the AAP threshold for osseous surgery. Non-surgical therapy is indicated before any", "perio_diagnosis": "Stage I Periodontitis", "pocket_depth_avg": 2.08, "pocket_depth_max": 4.0, "max_pocket_depth_mm": 4, "bleeding_on_probing_pct": 42.0}	0.900	deterministic
\.


--
-- Data for Name: fee_schedules; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.fee_schedules (schedule_id, payer_id, plan_type, cdt_code, state, zip_code, allowed_amount, effective_date, source, created_at) FROM stdin;
eabac412-bb05-40f5-a9c6-6877d2e318a9	delta_dental	PPO	D2740	FL	\N	1312.50	2026-01-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
e5f08466-ceb4-431b-a93d-963307a56c19	delta_dental	PPO	D2750	FL	\N	1249.50	2026-01-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
7457b29f-4028-482f-b7a6-3589aa0e4b05	delta_dental	PPO	D3330	FL	\N	1102.50	2026-01-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
f137d5b9-0e55-4818-8860-c03be57a957d	delta_dental	PPO	D6010	FL	\N	2084.25	2026-01-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
50fb0f67-19ae-441e-b28e-c2f34604fcac	delta_dental	PPO	D2740	GA	\N	1250.00	2026-01-01	estimated	2026-08-04 18:07:59.994239+00
0165c432-00d9-4567-81eb-f009b2989d07	delta_dental	PPO	D2750	GA	\N	1190.00	2026-01-01	estimated	2026-08-04 18:08:00.025431+00
e7c05570-fbd0-4a47-96d3-e5c96c21ad26	delta_dental	PPO	D6065	FL	\N	1249.50	2026-01-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
269bb883-7171-40d0-85de-48f03a35edbb	delta_dental	PPO	D7953	FL	\N	446.25	2026-01-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
9962af05-66ec-4b71-9281-143dfa555fb2	delta_dental	PPO	D3330	GA	\N	1050.00	2026-01-01	estimated	2026-08-04 18:08:00.246725+00
552440a8-2fd5-45ee-a99d-b45b8f6b4048	cigna	DPPO	D2740	FL	\N	1378.13	2026-01-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
580e722f-b0ae-4d1d-be6a-a1c180a779bb	cigna	DPPO	D2750	FL	\N	1311.98	2026-01-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
c331127b-d37c-47dc-96a9-8f48cb018ddd	cigna	DPPO	D3330	FL	\N	1157.63	2026-01-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
4e269712-95b5-4690-8e4a-1e0f8c591f5c	delta_dental	PPO	D6010	GA	\N	1985.00	2026-01-01	estimated	2026-08-04 18:08:00.354237+00
590198c1-c5bf-4bb3-8334-5846ad1e2d25	delta_dental	PPO	D6065	GA	\N	1190.00	2026-01-01	estimated	2026-08-04 18:08:00.375198+00
410cc74a-1969-479e-bfdd-9d759174ebe5	cigna	DPPO	D6010	FL	\N	2188.46	2026-01-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
9f010574-9d0c-41fb-8ef9-f214abf1c33f	cigna	DPPO	D6065	FL	\N	1311.98	2026-01-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
99ae4489-3434-4758-a6e2-e0a885c0595c	delta_dental	PPO	D7953	GA	\N	425.00	2026-01-01	estimated	2026-08-04 18:08:00.440771+00
6c81b75a-04b4-4412-9d13-7bc61085695f	cigna	DPPO	D7953	FL	\N	468.56	2026-01-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
72147e4e-bfda-43df-9b85-9b697ee12b4e	delta_dental	PPO	D0210	FL	\N	188.34	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
360b36fd-df30-4e5f-8969-254a4103f50c	cigna	DPPO	D0210	FL	\N	197.76	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
e7b383ad-55c7-4cba-a336-dab0d8d87b36	metlife	PDP	D0210	FL	\N	184.58	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
78431c19-b0d8-4435-a79c-89e9761e0e61	delta_dental	PPO	D0220	FL	\N	37.66	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
2675fa6d-898d-405d-b844-1de62fca9876	cigna	DPPO	D0220	FL	\N	39.55	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
f9310147-46e3-410c-9f20-c39f7362e89e	metlife	PDP	D0220	FL	\N	36.92	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
cef9ad0c-ebb4-4c74-85fd-5c1f598e6b54	delta_dental	PPO	D0274	FL	\N	80.71	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
6092c675-a8d9-43ae-8322-6c7de39d1a12	metlife	PDP	D2740	FL	\N	1286.25	2026-01-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
22a5b0b9-c66a-4a4c-b4d5-ee8b052029f8	metlife	PDP	D2750	FL	\N	1224.51	2026-01-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
3d7931f8-9f9d-4217-a789-82d7a39f8e2e	cigna	DPPO	D0274	FL	\N	84.76	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
4c1f0502-dc50-4751-821d-2bcfb6df7157	metlife	PDP	D0274	FL	\N	79.11	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
9c2822c0-6304-4637-99f8-81b0f7803ce4	metlife	PDP	D3330	FL	\N	1080.45	2026-01-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
df1fcaf1-5959-4487-8fad-45942d638035	metlife	PDP	D6010	FL	\N	2042.57	2026-01-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
3bf6765f-6206-43a7-b571-ef5788949f92	metlife	PDP	D6065	FL	\N	1224.51	2026-01-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
f61a7847-1b5b-4bfd-b6b5-47f9f9b330b6	cigna	DPPO	D2740	GA	\N	1312.50	2026-01-01	estimated	2026-08-04 18:08:00.794219+00
53eaacd6-a14d-45b7-955d-9f374a40af6b	cigna	DPPO	D2750	GA	\N	1249.50	2026-01-01	estimated	2026-08-04 18:08:00.815246+00
2c29a025-6663-4f55-ab89-4a0591855eea	metlife	PDP	D7953	FL	\N	437.33	2026-01-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
43227d29-fafe-44fb-9a62-d1b71f37e3f3	delta_dental	PPO	D0120	FL	\N	59.19	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
f5188843-882f-4415-b2d9-505c3ae73546	cigna	DPPO	D3330	GA	\N	1102.50	2026-01-01	estimated	2026-08-04 18:08:00.877746+00
379adae0-52d7-4757-a866-dd03086c8cc8	cigna	DPPO	D0120	FL	\N	62.15	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
1684c787-a9a4-458c-bb0e-56f1427ed70a	metlife	PDP	D0120	FL	\N	58.01	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
8a34374c-78fe-4a7b-b8e1-633bba4ed859	delta_dental	PPO	D0150	FL	\N	102.24	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
b1ce697f-ab37-4258-b930-4e59e28fb1f6	cigna	DPPO	D6010	GA	\N	2084.25	2026-01-01	estimated	2026-08-04 18:08:00.965998+00
30914770-2c2f-4688-be14-72891670e6ac	cigna	DPPO	D6065	GA	\N	1249.50	2026-01-01	estimated	2026-08-04 18:08:00.987763+00
9dde23aa-7048-408c-90d3-000b85dd92e8	cigna	DPPO	D0150	FL	\N	107.35	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
dcb91761-1230-44b1-ba45-bf7e2a577b98	metlife	PDP	D0150	FL	\N	100.20	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
2efe11d5-2ca3-4a6d-afda-467d5eed5cf1	cigna	DPPO	D7953	GA	\N	446.25	2026-01-01	estimated	2026-08-04 18:08:01.04949+00
ff78c53a-12d2-4541-bf7c-c8964faebdb1	delta_dental	PPO	D0330	FL	\N	166.81	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
e5b1ae21-c6cd-4672-8672-0a63d289bce3	cigna	DPPO	D0330	FL	\N	175.16	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
d95797be-3672-44cb-8eb5-fdf3568bd025	metlife	PDP	D0330	FL	\N	163.49	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
2b787fd6-8aeb-4475-8c92-dc31050e1b47	delta_dental	PPO	D1110	FL	\N	118.39	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
6e2b0576-a055-4653-bdeb-8895103da18a	cigna	DPPO	D1110	FL	\N	124.31	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
57f820e1-263e-4685-bb45-f2ab659da26f	metlife	PDP	D1110	FL	\N	116.01	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
090d1fb1-e419-4dda-8f36-d9f9136eacef	delta_dental	PPO	D1120	FL	\N	91.48	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
eb18b808-9979-4e9f-9468-cdc0c8c47b76	cigna	DPPO	D1120	FL	\N	96.05	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
64be060b-97dd-4464-a1fd-65b04ed8f14d	delta_dental	PPO	D0210	GA	\N	179.37	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:07:59.71512+00
3e22bbe6-1397-48ce-afbf-f8af038bb1b9	cigna	DPPO	D0210	GA	\N	188.34	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:00.552195+00
fd8c5254-6877-410f-a026-070e0175a0f9	metlife	PDP	D0210	GA	\N	175.79	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:01.156815+00
ac3246f1-f695-4544-91dc-d3352ee635ec	delta_dental	PPO	D0220	GA	\N	35.87	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:07:59.739801+00
619946b6-9729-4a46-9c9a-dddcc7cd2358	cigna	DPPO	D0220	GA	\N	37.67	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:00.57398+00
e98ae785-0aec-4d23-9764-c4c1daa5ca9a	metlife	PDP	D0220	GA	\N	35.16	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:01.179348+00
4da91487-c734-408a-bd52-98b0dd90a1ab	delta_dental	PPO	D0274	GA	\N	76.87	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:07:59.767986+00
40353f68-c63b-4cb7-bdda-7436b5cafe41	metlife	PDP	D2740	GA	\N	1225.00	2026-01-01	estimated	2026-08-04 18:08:01.42791+00
574de3d5-bf35-4dda-8768-20b8265ede7c	metlife	PDP	D2750	GA	\N	1166.20	2026-01-01	estimated	2026-08-04 18:08:01.450294+00
696590b6-3ffe-4c56-9a6b-7a849bc0a49e	cigna	DPPO	D0274	GA	\N	80.72	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:00.595246+00
66fe64bc-7ae2-4fcf-8622-1c3c3bbb1096	metlife	PDP	D0274	GA	\N	75.34	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:01.203132+00
a4b64147-5df1-4e38-a2b3-7f6f7dc31f17	metlife	PDP	D3330	GA	\N	1029.00	2026-01-01	estimated	2026-08-04 18:08:01.518974+00
9846cc45-bcec-43bf-84c1-95b7a234c743	metlife	PDP	D1120	FL	\N	89.65	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
e81c5e3e-310b-4bae-8e72-f38917288d13	delta_dental	PPO	D1351	FL	\N	69.95	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
3c79e72a-487e-42d9-b3dc-23d41182d491	cigna	DPPO	D1351	FL	\N	73.46	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
a7ec1a77-e608-4cd6-b7b2-3d251c0b238e	metlife	PDP	D1351	FL	\N	68.55	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
a71840cb-86e5-4094-a706-3cb10ab5672e	delta_dental	PPO	D2140	FL	\N	188.34	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
99f38715-32bd-43b1-9591-8b216c2978c5	cigna	DPPO	D2140	FL	\N	197.76	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
8c442caf-cf42-4352-b1cb-71efbd7a864a	metlife	PDP	D6010	GA	\N	1945.30	2026-01-01	estimated	2026-08-04 18:08:01.612344+00
7386d8e2-4193-47b6-a8dd-96e350fa518f	metlife	PDP	D6065	GA	\N	1166.20	2026-01-01	estimated	2026-08-04 18:08:01.635502+00
25c465a2-ea82-46e2-b3a5-996a18499583	metlife	PDP	D2140	FL	\N	184.58	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
233962b0-693f-4c7d-904f-cdb4847a7ab2	delta_dental	PPO	D2150	FL	\N	226.01	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
afb0df5c-b90b-4e24-b719-474114f9149f	metlife	PDP	D7953	GA	\N	416.50	2026-01-01	estimated	2026-08-04 18:08:01.701701+00
0881b4c8-6cf0-413d-bc92-059214ea4471	cigna	DPPO	D2150	FL	\N	237.31	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
7d48a68c-563d-45ef-be6a-59679638a8a4	metlife	PDP	D2150	FL	\N	221.49	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
3ae9d5f3-e128-4bb5-85da-b39393b37972	delta_dental	PPO	D2160	FL	\N	269.06	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
759bea17-0905-4532-bf0c-41bdf2e02824	cigna	DPPO	D2160	FL	\N	282.51	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
ea50d64f-12a0-4665-8552-32351ea9bdbf	metlife	PDP	D2160	FL	\N	263.68	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
baea7a24-873d-4270-8305-a573ca9f5040	delta_dental	PPO	D2161	FL	\N	312.11	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
991d5fc5-fcb2-4aaf-a3ec-d577c6f8080e	cigna	DPPO	D2161	FL	\N	327.72	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
fa144f06-ee20-4426-a7c1-70b5ebfceee0	metlife	PDP	D2161	FL	\N	305.87	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
dd69443a-26f5-4763-8de7-4bf5d167ca22	delta_dental	PPO	D3310	FL	\N	941.71	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
533f2f51-af6c-48a9-b18f-02b604d7409d	cigna	DPPO	D3310	FL	\N	988.81	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
40d8581d-e535-4fa3-9c14-90bf8d3d448b	delta_dental	PPO	D0120	GA	\N	56.37	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:07:59.665814+00
fe95eac1-76db-47a8-808d-fd7b820f6b40	cigna	DPPO	D0120	GA	\N	59.19	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:00.508007+00
a3125bd4-be2d-46d3-900a-ece921f902f2	metlife	PDP	D0120	GA	\N	55.25	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:01.113489+00
6a62c3aa-7a2e-4232-85be-924bdfaaf801	delta_dental	PPO	D0150	GA	\N	97.37	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:07:59.692944+00
d48b3459-ebcc-4f22-ac2e-38a6c877e66c	cigna	DPPO	D0150	GA	\N	102.24	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:00.531487+00
44f6d5d4-78e2-4f08-bf73-82c54fda3123	metlife	PDP	D0150	GA	\N	95.43	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:01.13469+00
6d3bbc6d-ed93-4190-9f07-e7688cfd3470	delta_dental	PPO	D0330	GA	\N	158.87	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:07:59.804863+00
cd6df50a-0d64-4d97-96d1-f6d7fe8c653b	cigna	DPPO	D0330	GA	\N	166.82	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:00.619497+00
6063cdcc-5726-4c5e-82c0-44f3ee2c5d17	metlife	PDP	D0330	GA	\N	155.70	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:01.236422+00
552e2718-498e-4bed-b07a-4e5bb15b7d0d	delta_dental	PPO	D1110	GA	\N	112.75	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:07:59.829685+00
3eab5e73-af37-4897-8b27-5f320dafa684	cigna	DPPO	D1110	GA	\N	118.39	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:00.640731+00
a8aad3b1-0f17-4cfa-95e7-55cbaaa1757c	metlife	PDP	D1110	GA	\N	110.49	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:01.261476+00
719b52bd-9275-4060-944f-4aa0ad520df5	delta_dental	PPO	D1120	GA	\N	87.12	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:07:59.864198+00
a61b583d-91a8-447b-8c28-7d798337ba40	cigna	DPPO	D1120	GA	\N	91.48	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:00.661542+00
f3b3a9df-2c6f-4eb6-8ed1-d2a1dde5fb79	metlife	PDP	D1120	GA	\N	85.38	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:01.283205+00
3caa3b6f-8c93-4a5d-8430-17768ce405c9	delta_dental	PPO	D1351	GA	\N	66.62	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:07:59.886729+00
be086edd-1845-4d8e-bbf2-426d1678fdba	cigna	DPPO	D1351	GA	\N	69.96	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:00.683547+00
b3082eb8-5f07-437f-ae84-90c4766950aa	metlife	PDP	D1351	GA	\N	65.29	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:01.307631+00
b2888c5a-f9d7-40ba-86ec-cf983a8821d1	delta_dental	PPO	D2140	GA	\N	179.37	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:07:59.90926+00
c0177934-783a-40fa-aebd-07ff6a0c5750	cigna	DPPO	D2140	GA	\N	188.34	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:00.704759+00
793ef2f3-6b9f-44d4-a2ce-3198fcad1092	metlife	PDP	D2140	GA	\N	175.79	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:01.33009+00
f8a7c3e8-f3ad-4072-b255-75c84b8340a2	delta_dental	PPO	D2150	GA	\N	215.25	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:07:59.931278+00
ca1b2273-74b5-4f17-aebf-c9cdda2682d4	cigna	DPPO	D2150	GA	\N	226.01	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:00.727+00
f23eb575-4bb2-489f-9061-28deb8aeac6c	metlife	PDP	D2150	GA	\N	210.94	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:01.357111+00
b4975dfe-a409-44b1-bb01-0f771508354d	delta_dental	PPO	D2160	GA	\N	256.25	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:07:59.951767+00
5dc64d8c-d962-4494-8508-79b91bbe4119	cigna	DPPO	D2160	GA	\N	269.06	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:00.750239+00
92b854ff-5c5f-48fe-af74-e0e858486678	metlife	PDP	D2160	GA	\N	251.12	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:01.383986+00
8eb25a03-f776-4a3e-9029-a90f7965adc4	delta_dental	PPO	D2161	GA	\N	297.25	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:07:59.97324+00
04154f15-00ee-44b4-9ae2-9443e23b63dc	cigna	DPPO	D2161	GA	\N	312.11	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:00.771491+00
167e104b-2025-4cc8-b86c-373f062ad70c	metlife	PDP	D2161	GA	\N	291.30	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:01.406492+00
5ac3f39a-8e6e-4080-a777-6b7251d6759c	delta_dental	PPO	D3310	GA	\N	896.87	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:00.154836+00
e8576d97-fcc3-4f97-9837-ae718e04f699	cigna	DPPO	D3310	GA	\N	941.72	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:00.836246+00
7c5dad1c-2d36-4d42-9706-05e8339c4e14	metlife	PDP	D3310	GA	\N	878.94	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:01.474631+00
94fde362-f723-45e8-9f20-845f3ec71dd8	delta_dental	PPO	D3320	GA	\N	999.37	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:00.181338+00
12c03cb3-2dc1-4765-80f1-136bf0d9f93a	cigna	DPPO	D3320	GA	\N	1049.34	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:00.85673+00
fb65ef74-fc3d-484f-92cd-4296441d17dd	metlife	PDP	D3320	GA	\N	979.39	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:01.497513+00
36ec34b0-d3e4-455a-8d2f-d3049ab17ac6	delta_dental	PPO	D4260	GA	\N	1004.50	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:00.285278+00
0611ee16-c311-4b2d-8876-3acccaad217c	cigna	DPPO	D4260	GA	\N	1054.72	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:00.900974+00
7a7938fb-63a5-4b37-b4a9-7941663e45d2	metlife	PDP	D4260	GA	\N	984.41	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:01.539888+00
e9e18a23-39d5-4c36-bf83-3852143f2192	delta_dental	PPO	D4341	GA	\N	271.62	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:00.312431+00
8843c9f0-7d71-45e4-8576-3d5452c408f3	cigna	DPPO	D4341	GA	\N	285.21	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:00.922244+00
7d8939d7-581b-499a-ab47-2fb7caeac18a	metlife	PDP	D4341	GA	\N	266.19	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:01.562069+00
854a14c5-9ac9-4084-80bb-42fdbdeb02f9	delta_dental	PPO	D4910	GA	\N	148.62	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:00.333531+00
13493635-6e22-4568-af28-c6de9c3f8a37	cigna	DPPO	D4910	GA	\N	156.06	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:00.94349+00
654e9651-468a-4371-8530-cd34d2443a44	metlife	PDP	D4910	GA	\N	145.65	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:01.59033+00
89caafb6-f3c3-4b5b-86a2-b2c25c2444ef	delta_dental	PPO	D7140	GA	\N	189.62	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:00.396187+00
da558070-d5cc-4aad-a885-af8f76aa940a	cigna	DPPO	D7140	GA	\N	199.11	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:01.008539+00
b0adee41-bcff-457f-844b-7858ca5e5219	metlife	PDP	D3310	FL	\N	922.89	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
4416c331-6b27-4447-98a1-f33eac8831e7	delta_dental	PPO	D3320	FL	\N	1049.34	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
56209842-bd58-4dae-825b-773123b54a3f	cigna	DPPO	D3320	FL	\N	1101.81	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
e56dd403-18a6-41c3-b74b-c7797950af36	metlife	PDP	D3320	FL	\N	1028.36	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
54988a3f-6cf5-4f32-a40f-4108855fa0d1	delta_dental	PPO	D4260	FL	\N	1054.73	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
5a001f65-fa83-4262-b64a-059f1dd0b50c	cigna	DPPO	D4260	FL	\N	1107.46	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
1c852bf4-4482-42c9-b80e-2df8957835b8	metlife	PDP	D4260	FL	\N	1033.63	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
ceef64c5-5024-47f6-aa6e-c254aa315d5f	delta_dental	PPO	D4341	FL	\N	285.20	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
10ddf628-25e7-426a-aa7c-953f8fee8663	cigna	DPPO	D4341	FL	\N	299.47	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
882d9db9-bed9-4150-b57b-aa899eb5fbf0	metlife	PDP	D4341	FL	\N	279.50	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
409c4d54-3e64-4a68-983c-5a3c7a36d65d	metlife	PDP	D7140	GA	\N	185.83	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:01.656077+00
6110cd0b-96c4-4714-a013-dba45b3aa374	delta_dental	PPO	D7210	GA	\N	292.12	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:00.419235+00
2b9c8374-a514-4049-8dbd-1b0bc9bc28d1	cigna	DPPO	D7210	GA	\N	306.73	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:01.028734+00
fa6a59f4-f850-48b9-b6de-1aeaa1459064	metlife	PDP	D7210	GA	\N	286.28	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:01.678981+00
ffeefb55-6794-471b-a7e9-6a2ae8c55348	delta_dental	PPO	D9110	GA	\N	97.37	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:00.462243+00
58326eb0-f841-48e1-8513-06c46d148689	cigna	DPPO	D9110	GA	\N	102.24	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:01.069737+00
4fac2d62-a771-4abc-ab23-2c445e49601e	metlife	PDP	D9110	GA	\N	95.43	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:01.732297+00
0710c918-3021-4217-9929-aeabdd3ce8b0	delta_dental	PPO	D9230	GA	\N	128.12	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:00.485989+00
e86f3d19-0976-42c2-b246-1fe203edb7bb	cigna	DPPO	D9230	GA	\N	134.53	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:01.092214+00
78a01199-4d44-4c36-ba03-edc3f1f8b0f2	metlife	PDP	D9230	GA	\N	125.56	2025-07-01	ga_medicaid_spa_ga25_0005	2026-08-04 18:08:01.779536+00
f3b3ca6d-4659-4060-921c-9fa1309ff71f	delta_dental	PPO	D4910	FL	\N	156.05	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
50d0431e-6541-41ec-a1df-20cce5a6901f	cigna	DPPO	D4910	FL	\N	163.86	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
7b5cd281-ef98-40b3-a718-6f766c6651ad	metlife	PDP	D4910	FL	\N	152.93	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
887c23ba-5610-4a87-b49c-e1a48d75baf5	delta_dental	PPO	D7140	FL	\N	199.10	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
2a4c00e9-c7c1-4c17-95be-db66b6d92901	cigna	DPPO	D7140	FL	\N	209.07	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
171a4780-72df-4ad5-80f6-64398a8e36fe	metlife	PDP	D7140	FL	\N	195.12	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
f540005b-e0dc-4ffe-b8c4-9432bfb4e400	delta_dental	PPO	D7210	FL	\N	306.73	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
2e30d7d5-4e13-4fe4-acd9-707e7dbd3aa9	cigna	DPPO	D7210	FL	\N	322.07	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
8946a1c0-42a4-4cb5-9873-ca7abc862d13	metlife	PDP	D7210	FL	\N	300.59	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
bad4ef80-0a02-4fe5-a47f-384149542d8c	delta_dental	PPO	D9110	FL	\N	102.24	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
e6268f77-7dc5-474d-985d-7201fae5a307	cigna	DPPO	D9110	FL	\N	107.35	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
336d1ca5-cfcc-4080-a200-f601ae312abe	metlife	PDP	D9110	FL	\N	100.20	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
0e30b09c-d58d-43fe-accb-53ed156786fd	delta_dental	PPO	D9230	FL	\N	134.53	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
ae7203a2-8d81-4a69-8322-2ab9d8e958bf	cigna	DPPO	D9230	FL	\N	141.26	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
8fe9abe1-f425-4218-ac23-a58617e3c092	metlife	PDP	D9230	FL	\N	131.84	2025-07-01	fl_medicaid_estimated	2026-08-06 02:31:15.579205+00
ba24a9ad-ff86-42bf-9f93-762940a902a1	delta_dental	PPO	D2740	TX	\N	1375.00	2026-01-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
3a0a3b9f-4c81-4237-a128-596d3de9d103	delta_dental	PPO	D2750	TX	\N	1309.00	2026-01-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
d76e1769-0a90-4e91-baf0-9f5656119a18	delta_dental	PPO	D3330	TX	\N	1155.00	2026-01-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
24ae0952-1f88-4c12-9eac-1ecd9e1a6f14	delta_dental	PPO	D6010	TX	\N	2183.50	2026-01-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
ef9dd147-6681-4c2a-aea1-8f4f140c2cc5	delta_dental	PPO	D6065	TX	\N	1309.00	2026-01-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
ef2104b7-d9b7-4b48-b8d4-2f2b9a61c72d	delta_dental	PPO	D7953	TX	\N	467.50	2026-01-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
59fccdd2-1e76-464e-81dc-2bb57f5780a6	cigna	DPPO	D2740	TX	\N	1443.75	2026-01-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
416d6bfc-81fa-491a-9fad-ea9be8d8c61d	cigna	DPPO	D2750	TX	\N	1374.45	2026-01-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
50fe5e93-a6c9-4fc9-96a8-40219bea9484	cigna	DPPO	D3330	TX	\N	1212.75	2026-01-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
fe6b34c2-e04e-4544-9670-00540fa58d80	cigna	DPPO	D6010	TX	\N	2292.68	2026-01-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
e51e63d7-37ce-4e2c-96b9-13881a954175	cigna	DPPO	D6065	TX	\N	1374.45	2026-01-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
99bea51b-9c70-49c1-a739-26fffccb27de	cigna	DPPO	D7953	TX	\N	490.88	2026-01-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
37f80a57-20ab-4abf-8785-31796418e3ce	delta_dental	PPO	D0210	TX	\N	197.31	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
b24ea5ea-8df5-434b-b5c1-77ad558e94c4	cigna	DPPO	D0210	TX	\N	207.17	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
e3910ed1-eae5-4605-a67c-96c41b975bb7	metlife	PDP	D0210	TX	\N	193.37	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
a755a35e-8974-4828-97eb-f2f9cb7f2d37	delta_dental	PPO	D0220	TX	\N	39.46	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
182b4547-3d0e-4dc1-8b04-2cb09900b7ba	cigna	DPPO	D0220	TX	\N	41.44	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
fecff9c1-cfeb-4f5a-b258-ec2deca397b8	metlife	PDP	D0220	TX	\N	38.68	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
ba53773d-1e9b-4ca0-b899-09c04e01a9e0	delta_dental	PPO	D0274	TX	\N	84.56	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
d5d53f8d-a970-49c1-bbc6-fa3f5b23d60b	metlife	PDP	D2740	TX	\N	1347.50	2026-01-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
add70035-98d0-4b64-8ab3-2407da4dabd2	metlife	PDP	D2750	TX	\N	1282.82	2026-01-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
aaebf0a1-0c87-4ea3-878a-e1d83c5037a0	cigna	DPPO	D0274	TX	\N	88.79	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
d5d497ac-d9f5-4caa-a190-63348c3e1b30	metlife	PDP	D0274	TX	\N	82.87	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
7a3a32d2-e8d0-4ab1-b2e7-10712f2b0cdd	metlife	PDP	D3330	TX	\N	1131.90	2026-01-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
6916c7db-4a81-43b3-b3b8-5b3dd4b164f7	metlife	PDP	D6010	TX	\N	2139.83	2026-01-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
e24ba1e3-ff0e-4edf-a32c-ec7218617cd6	metlife	PDP	D6065	TX	\N	1282.82	2026-01-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
c6ee309b-933e-400a-90a4-9822d5f090cb	metlife	PDP	D7953	TX	\N	458.15	2026-01-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
a8d8b747-422e-406d-900f-3b698d0859a8	delta_dental	PPO	D0120	TX	\N	62.01	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
9c76a439-0759-4fdf-b864-96e9b3b84402	cigna	DPPO	D0120	TX	\N	65.11	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
f73b8fc1-1434-44e2-bdbd-33aef9a3b1c2	metlife	PDP	D0120	TX	\N	60.78	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
1311e841-b49e-4cf6-85ac-eeddf1c37301	delta_dental	PPO	D0150	TX	\N	107.11	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
2d1fcd76-d122-4d2b-83e8-15dd61c3dd2d	cigna	DPPO	D0150	TX	\N	112.46	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
2a014610-d574-4db6-b286-31f03eb1a5ef	metlife	PDP	D0150	TX	\N	104.97	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
9ba6f5f6-1057-42f5-9417-3888e4b32173	delta_dental	PPO	D0330	TX	\N	174.76	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
8856fa09-bc15-45ac-bf5b-90bf4dca83aa	cigna	DPPO	D0330	TX	\N	183.50	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
cee0f1b2-d18e-46df-8f37-5f8ef7f86f77	metlife	PDP	D0330	TX	\N	171.27	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
f43f4bca-8424-4c9b-bb3c-dfc6aa7aa9a7	delta_dental	PPO	D1110	TX	\N	124.03	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
9f90c3e2-6084-407f-870d-fdbea9558fc1	cigna	DPPO	D1110	TX	\N	130.23	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
b3ac806d-46cf-4a01-92b0-2030d84580ae	metlife	PDP	D1110	TX	\N	121.54	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
c7396e6d-b6ba-472a-8419-9d51955c4b30	delta_dental	PPO	D1120	TX	\N	95.83	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
9902415b-161a-419c-ba98-4c633b3e2baa	cigna	DPPO	D1120	TX	\N	100.63	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
91d1d217-919e-4bae-9afe-44e642417e09	metlife	PDP	D1120	TX	\N	93.92	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
95acf8af-4ce5-4020-8126-6b1356fbdfde	delta_dental	PPO	D1351	TX	\N	73.28	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
c457fc0f-2961-47e4-befd-0bd76a287182	cigna	DPPO	D1351	TX	\N	76.96	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
de955574-d9df-41d5-894a-fffd3c8e8b6b	metlife	PDP	D1351	TX	\N	71.82	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
be56af92-9379-489e-b986-ae41b054ab5f	delta_dental	PPO	D2140	TX	\N	197.31	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
fc71e7f4-bb74-4388-8683-04360e261f7e	cigna	DPPO	D2140	TX	\N	207.17	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
06b0c5a3-b39e-4721-9065-2e28b3e26e1c	metlife	PDP	D2140	TX	\N	193.37	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
a65f6650-c2df-470d-84aa-81e8b3ec01b7	delta_dental	PPO	D2150	TX	\N	236.78	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
c50d92d0-eaef-4ac8-bb35-3853ed3438f9	cigna	DPPO	D2150	TX	\N	248.61	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
97178490-e474-4ad1-b973-05cfa786aed1	metlife	PDP	D2150	TX	\N	232.03	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
1a533ce4-e53e-48f7-a8b8-57076348ae85	delta_dental	PPO	D2160	TX	\N	281.88	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
01dd77e8-1c67-4e9f-9a1f-45c411c7203d	cigna	DPPO	D2160	TX	\N	295.97	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
b2435d56-5206-404b-a27f-399fe37d2eb2	metlife	PDP	D2160	TX	\N	276.23	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
095d6420-c71a-4d77-bb9f-19cf86a674f5	delta_dental	PPO	D2161	TX	\N	326.98	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
624ae377-e893-470d-b104-e58c73cd42f8	cigna	DPPO	D2161	TX	\N	343.32	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
f0b28dc1-f04a-4ece-bf4b-64bcee2d247a	metlife	PDP	D2161	TX	\N	320.43	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
50de8501-49f7-493b-b9e3-889acaa68c0d	delta_dental	PPO	D3310	TX	\N	986.56	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
e124c91d-243f-4aa5-9781-4e39f3725702	cigna	DPPO	D3310	TX	\N	1035.89	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
fcd2ae33-4e58-44ef-9193-e9142a396714	metlife	PDP	D3310	TX	\N	966.83	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
9c843d50-cacf-4bcb-abce-23b78e2d7d0e	delta_dental	PPO	D3320	TX	\N	1099.31	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
63c46182-8a61-4544-9cd8-f4178b1a643e	cigna	DPPO	D3320	TX	\N	1154.27	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
c3410bd5-f070-4050-bbda-cad61983473a	metlife	PDP	D3320	TX	\N	1077.33	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
81ce6dc8-0a41-4e75-9167-8338f5abfec3	delta_dental	PPO	D4260	TX	\N	1104.95	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
f19521e3-30ac-498b-b0b6-761367f79464	cigna	DPPO	D4260	TX	\N	1160.19	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
d5c12bd9-b06a-4d93-ba3b-52f6ecb5a248	metlife	PDP	D4260	TX	\N	1082.85	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
250c6888-4bf5-454b-92d9-724a6fa97efe	delta_dental	PPO	D4341	TX	\N	298.78	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
be83df45-383b-48d4-b905-48dc3bff3e1e	cigna	DPPO	D4341	TX	\N	313.73	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
07e9bfbe-e11a-4197-a056-e6584cced69a	metlife	PDP	D4341	TX	\N	292.81	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
59d25ce3-100b-43d3-9148-f9875050569b	delta_dental	PPO	D4910	TX	\N	163.48	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
b04474ac-b59e-4484-a7c7-4b4fc6dd4e40	cigna	DPPO	D4910	TX	\N	171.67	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
31d4e847-85ad-4749-af81-60e0767a098b	metlife	PDP	D4910	TX	\N	160.22	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
e555f5f8-1a18-4f53-9742-a90888f9eed1	delta_dental	PPO	D7140	TX	\N	208.58	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
4532a705-89e8-48e5-85da-9b023a46b6f4	cigna	DPPO	D7140	TX	\N	219.02	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
d1fc519e-2d2e-4e65-97b1-599aa7c823cd	metlife	PDP	D7140	TX	\N	204.41	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
cd826473-083e-4aca-ba4e-6e4accf3d957	delta_dental	PPO	D7210	TX	\N	321.33	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
0258be1b-c794-4e4d-ae36-5e9d59cbc4ef	cigna	DPPO	D7210	TX	\N	337.40	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
780b94b6-2149-4fe0-b690-420f41f19300	metlife	PDP	D7210	TX	\N	314.91	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
b6bce035-0358-4e26-ab66-2b686f063164	delta_dental	PPO	D9110	TX	\N	107.11	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
85ae099b-2d5b-4b85-8580-d32cacf55c88	cigna	DPPO	D9110	TX	\N	112.46	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
26b4ce6e-d377-41cf-9203-f2e27cca593e	metlife	PDP	D9110	TX	\N	104.97	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
553471c0-1950-4113-806d-19560cfaf8cc	delta_dental	PPO	D9230	TX	\N	140.93	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
d167e76b-a08f-4efc-a935-56ae37abdef3	cigna	DPPO	D9230	TX	\N	147.98	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
7e889ff4-4e8c-442c-a1f4-823ad3b8cf00	metlife	PDP	D9230	TX	\N	138.12	2025-07-01	tx_medicaid_estimated	2026-08-06 02:31:15.579205+00
a1947916-8b6a-4513-813b-93d5aeb92d05	delta_dental	PPO	D2740	NC	\N	1225.00	2026-01-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
1154b43b-31f8-4b1c-9950-ca8bb55ef4b4	delta_dental	PPO	D2750	NC	\N	1166.20	2026-01-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
f3a3f20c-b27d-43ff-9c4d-b297e31343be	delta_dental	PPO	D3330	NC	\N	1029.00	2026-01-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
c6930fa0-f833-48e0-80d0-f0ddb7a6790a	delta_dental	PPO	D6010	NC	\N	1945.30	2026-01-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
61c3f5a2-93ac-495e-8c88-b8b6f7704787	delta_dental	PPO	D6065	NC	\N	1166.20	2026-01-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
6ab57971-b809-429a-bffb-0d6d18c4482d	delta_dental	PPO	D7953	NC	\N	416.50	2026-01-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
5677b5b4-dd08-4a7d-9ee1-aabef0dcb245	cigna	DPPO	D2740	NC	\N	1286.25	2026-01-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
f8ef5b65-2519-4acb-b9ce-02d73267698e	cigna	DPPO	D2750	NC	\N	1224.51	2026-01-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
53f4e40d-5ec4-4c9b-92dc-926b245b6b0b	cigna	DPPO	D3330	NC	\N	1080.45	2026-01-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
90a7cdee-6b81-45df-9196-7e44de01bc62	cigna	DPPO	D6010	NC	\N	2042.56	2026-01-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
219d589e-59d8-4951-b9bb-552791e2b8b9	cigna	DPPO	D6065	NC	\N	1224.51	2026-01-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
fb942787-688e-4c45-b6df-c75cfb3921b6	cigna	DPPO	D7953	NC	\N	437.32	2026-01-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
1ca9c07d-4348-4878-b2e6-866fd41fb1cb	delta_dental	PPO	D0210	NC	\N	175.78	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
87f7811c-b013-45b1-8b65-eca3b5646a1a	cigna	DPPO	D0210	NC	\N	184.57	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
a7f87e17-97ee-40e1-8079-b96b6ed9352c	metlife	PDP	D0210	NC	\N	172.27	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
6390b785-9e7c-4e31-b27d-c1b68e7c99ee	delta_dental	PPO	D0220	NC	\N	35.15	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
165cdca9-c716-4c1a-b579-b66e4a31b217	cigna	DPPO	D0220	NC	\N	36.92	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
576ba889-3ae1-4c65-afd5-f9971dd0e69c	metlife	PDP	D0220	NC	\N	34.46	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
11675862-5756-4a09-985f-050f5678dc3a	delta_dental	PPO	D0274	NC	\N	75.33	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
4ed0ede1-2249-4839-a6de-4af9f270acf0	metlife	PDP	D2740	NC	\N	1200.50	2026-01-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
d5298e22-0942-48fd-b40d-fd090697c577	metlife	PDP	D2750	NC	\N	1142.88	2026-01-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
d69d4acf-7e0f-4b67-a6ec-4a6dec24f74b	cigna	DPPO	D0274	NC	\N	79.11	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
b7bccce3-6749-4e6a-933a-95372c57e0f9	metlife	PDP	D0274	NC	\N	73.83	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
8baee3ac-1f70-4495-a858-aba605f9d472	metlife	PDP	D3330	NC	\N	1008.42	2026-01-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
cc9b145f-3db0-414a-bab4-436af9cadc7b	metlife	PDP	D6010	NC	\N	1906.39	2026-01-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
f6231af7-f667-4e21-a20b-750bc76db230	metlife	PDP	D6065	NC	\N	1142.88	2026-01-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
9aa84294-158f-4072-a5e9-e0163c919dc2	metlife	PDP	D7953	NC	\N	408.17	2026-01-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
e735f70e-080b-457a-8e89-56ebff53e8d7	delta_dental	PPO	D0120	NC	\N	55.24	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
3a3f937e-70fc-4a40-9158-f9bcc37d9bb3	cigna	DPPO	D0120	NC	\N	58.01	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
16af8510-6abb-4874-a2e9-287aa677a37c	metlife	PDP	D0120	NC	\N	54.14	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
3737a4e3-d62a-4369-8bd8-a9c980ec9a6c	delta_dental	PPO	D0150	NC	\N	95.42	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
c799fc68-6c6f-4679-b9ce-716591ef8218	cigna	DPPO	D0150	NC	\N	100.20	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
bcfa80d3-3064-4410-b7eb-fb26dadea6d0	metlife	PDP	D0150	NC	\N	93.52	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
1038a211-a47a-4fc9-8d5b-a0314e4808f8	delta_dental	PPO	D0330	NC	\N	155.69	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
3c3baa75-8a08-422b-8d70-581e884fd05c	cigna	DPPO	D0330	NC	\N	163.48	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
a72a5fc9-7341-4fa4-91f9-cf9be72020ad	metlife	PDP	D0330	NC	\N	152.59	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
5d451d59-dd45-41d8-b29c-cffcc20e4980	delta_dental	PPO	D1110	NC	\N	110.49	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
527d99e0-5b1e-4019-b42b-a515bd4ba343	cigna	DPPO	D1110	NC	\N	116.02	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
7bf9d3aa-af88-492e-882e-12db55f3276a	metlife	PDP	D1110	NC	\N	108.28	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
d4b18a15-8c90-49b8-b465-6f1885fe99db	delta_dental	PPO	D1120	NC	\N	85.38	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
43d6d280-5780-41c6-8677-6a409657dcd5	cigna	DPPO	D1120	NC	\N	89.65	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
f3cf7b96-858a-42e3-81d1-a272479ea0d0	metlife	PDP	D1120	NC	\N	83.67	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
65973660-9803-4f9c-bf8a-31ecc526399c	delta_dental	PPO	D1351	NC	\N	65.29	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
7fc241de-e97c-4e55-b6ba-1b3051647bde	cigna	DPPO	D1351	NC	\N	68.56	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
abafbd7b-14c9-40cf-8a59-997e998a1f6b	metlife	PDP	D1351	NC	\N	63.98	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
5016d35e-2014-427a-be23-d8a8ccbc8e2f	delta_dental	PPO	D2140	NC	\N	175.78	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
cbcf9456-4978-4740-b5cc-ee88017a7ce5	cigna	DPPO	D2140	NC	\N	184.57	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
964927e0-f79c-4ab8-9606-d5d78b30b40e	metlife	PDP	D2140	NC	\N	172.27	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
5c2ed8f8-cbb3-4345-9a8e-0e97c02a40f4	delta_dental	PPO	D2150	NC	\N	210.94	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
0f692e07-79fa-4e2c-abee-44d8abae2414	cigna	DPPO	D2150	NC	\N	221.49	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
b55382b0-408c-4d0b-b23d-5a00eb386005	metlife	PDP	D2150	NC	\N	206.72	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
2e1dc762-c87d-4b19-8eee-430317510e43	delta_dental	PPO	D2160	NC	\N	251.12	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
3684fb7d-c7a8-441f-9df0-fbce86ef9480	cigna	DPPO	D2160	NC	\N	263.68	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
0c3c0100-e106-4dfb-b5a9-6a71125f66fa	metlife	PDP	D2160	NC	\N	246.10	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
54b5fd0d-a8a9-4f45-840f-989c77554387	delta_dental	PPO	D2161	NC	\N	291.30	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
ee27a954-0af2-4798-ac66-b37ac795b8c4	cigna	DPPO	D2161	NC	\N	305.87	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
f4aec266-9fa8-4239-bd5d-f0ac8b00e379	metlife	PDP	D2161	NC	\N	285.47	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
776cdedb-6e7a-4e91-a042-c596fd9b2189	delta_dental	PPO	D3310	NC	\N	878.93	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
c0d06c7b-bd80-46ea-8acc-f7fa408ab604	cigna	DPPO	D3310	NC	\N	922.89	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
9084557e-a2f3-4a0a-be69-36784fb189c0	metlife	PDP	D3310	NC	\N	861.36	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
9f6f740a-63a1-4450-82e4-790c6db225ce	delta_dental	PPO	D3320	NC	\N	979.38	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
d7d81196-c8a2-4f85-af15-f00294e7a2df	cigna	DPPO	D3320	NC	\N	1028.35	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
56a67995-6df6-4908-8cd7-e3a70bf59dd3	metlife	PDP	D3320	NC	\N	959.80	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
d089eeca-d11d-45b8-80d5-dd8d15aff164	delta_dental	PPO	D4260	NC	\N	984.41	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
f89de17d-1d3e-4c6f-8c46-88c9de0beeef	cigna	DPPO	D4260	NC	\N	1033.63	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
776bb477-987f-4122-9998-6920c2cca86a	metlife	PDP	D4260	NC	\N	964.72	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
03b48095-ab5f-417e-bb4f-6e626f8faaab	delta_dental	PPO	D4341	NC	\N	266.19	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
71aec54b-a0b4-414f-90c8-508ff483ea18	cigna	DPPO	D4341	NC	\N	279.51	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
49aa9c49-44c3-46e3-a304-5d097215ca90	metlife	PDP	D4341	NC	\N	260.87	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
a04fe1ee-7e58-4fe1-ba2a-31cf4b6adf9d	delta_dental	PPO	D4910	NC	\N	145.65	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
4dce37db-62d2-40a2-ba4f-52397d8fbe8a	cigna	DPPO	D4910	NC	\N	152.94	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
97b4f977-52a2-460d-8e24-39da7ef7ef60	metlife	PDP	D4910	NC	\N	142.74	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
7cb61f83-7202-4ea7-917b-9d2e4bfeacd0	delta_dental	PPO	D7140	NC	\N	185.83	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
dbfa3cea-5826-4376-871f-9d1cf17ffc0a	cigna	DPPO	D7140	NC	\N	195.13	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
a185497e-4916-4d6c-a9c1-8f1fad8a5bb9	metlife	PDP	D7140	NC	\N	182.11	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
e38eda99-2d48-4213-9935-983d31d63bf6	delta_dental	PPO	D7210	NC	\N	286.28	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
bad290e2-a739-4bbe-bd8b-0a09a2276b1c	cigna	DPPO	D7210	NC	\N	300.60	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
b2da24c6-eb9d-4d1b-b625-cd325f36d2a0	metlife	PDP	D7210	NC	\N	280.55	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
2487fcf4-e484-4b3c-a96f-330325f1b873	delta_dental	PPO	D9110	NC	\N	95.42	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
a8d5674d-67bc-408a-a170-3ea601bd8d1e	cigna	DPPO	D9110	NC	\N	100.20	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
4bbb8707-8099-4c55-abdd-eb606944d91f	metlife	PDP	D9110	NC	\N	93.52	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
fa210e6b-30b3-4529-b56b-1171bfa0ec33	delta_dental	PPO	D9230	NC	\N	125.56	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
b0f62214-46bd-43d4-90c7-8113dfb226f8	cigna	DPPO	D9230	NC	\N	131.84	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
bd8c6d18-bbe6-4140-8476-723476deb68f	metlife	PDP	D9230	NC	\N	123.05	2025-07-01	nc_medicaid_estimated	2026-08-06 02:31:15.579205+00
eb91f7c2-4e84-49b7-bb47-b0413bdf7190	delta_dental	PPO	D2740	SC	\N	1187.50	2026-01-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
aed69dec-c75e-4584-be8d-1f18db8a1c43	delta_dental	PPO	D2750	SC	\N	1130.50	2026-01-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
0a2b05ed-e9cc-4dbb-bfa6-699780741ce0	delta_dental	PPO	D3330	SC	\N	997.50	2026-01-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
25192375-5a23-4f83-9abe-c25cc0c25929	delta_dental	PPO	D6010	SC	\N	1885.75	2026-01-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
fb25efde-5f73-4157-bb08-ef983011f2aa	delta_dental	PPO	D6065	SC	\N	1130.50	2026-01-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
03780d79-84a4-4207-9bae-70eacef1ec10	delta_dental	PPO	D7953	SC	\N	403.75	2026-01-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
f4af4397-be6e-4148-8471-d25d985eda2f	cigna	DPPO	D2740	SC	\N	1246.87	2026-01-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
6df3f8ad-00b1-4862-a276-f9db35270390	cigna	DPPO	D2750	SC	\N	1187.02	2026-01-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
f63e4e29-6aaa-4e77-a5d7-6941444620b8	cigna	DPPO	D3330	SC	\N	1047.37	2026-01-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
b386b9a6-cd0d-4226-af43-25187174d146	cigna	DPPO	D6010	SC	\N	1980.04	2026-01-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
992297bb-f89d-489b-9e3d-0e93350a0abc	cigna	DPPO	D6065	SC	\N	1187.02	2026-01-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
e85b1a84-acb2-486f-a34e-c692e3f68a4e	cigna	DPPO	D7953	SC	\N	423.94	2026-01-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
cc796ae2-8407-4017-9c5c-c2b92cd86267	delta_dental	PPO	D0210	SC	\N	170.40	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
6fac391a-ad1a-41fd-ad0f-197899fd2599	cigna	DPPO	D0210	SC	\N	178.92	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
97428ac1-1554-4f19-a54e-2d6fd503c77d	metlife	PDP	D0210	SC	\N	167.00	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
d6a96562-2962-4dfb-940a-12910d0deea2	delta_dental	PPO	D0220	SC	\N	34.08	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
e2b18dca-dd3d-4caa-93b9-fcbc81ab3523	cigna	DPPO	D0220	SC	\N	35.79	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
a2a07d14-c0bf-4003-bc0c-36413432d683	metlife	PDP	D0220	SC	\N	33.40	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
ad71f17e-e60a-4744-9361-a34758098282	delta_dental	PPO	D0274	SC	\N	73.03	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
ae86a754-14a4-45b1-be69-e13dee5cf719	metlife	PDP	D2740	SC	\N	1163.75	2026-01-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
1c9ac7d4-698e-409a-ba6c-6f925e5ecb14	metlife	PDP	D2750	SC	\N	1107.89	2026-01-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
07c249f9-1eb7-488c-bf14-6d37d8d857ac	cigna	DPPO	D0274	SC	\N	76.68	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
6040691f-168e-4c48-86b0-5b8c0052e5ac	metlife	PDP	D0274	SC	\N	71.57	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
4e7cee8a-1294-4925-a69e-e783ef31b286	metlife	PDP	D3330	SC	\N	977.55	2026-01-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
35bf046b-7585-4936-8aa3-9ca99da3185b	metlife	PDP	D6010	SC	\N	1848.03	2026-01-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
8582f55f-8156-45e7-bf32-938104f020ce	metlife	PDP	D6065	SC	\N	1107.89	2026-01-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
8f5d9017-c275-47ba-95b3-6ac801993ef6	metlife	PDP	D7953	SC	\N	395.67	2026-01-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
f22ce915-2438-48a3-ad0b-c72bad9981aa	delta_dental	PPO	D0120	SC	\N	53.55	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
7f4cdcb2-641e-4316-af84-4baaeb22b58b	cigna	DPPO	D0120	SC	\N	56.23	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
4a33a344-c38d-447a-ad35-f8e99786589e	metlife	PDP	D0120	SC	\N	52.49	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
2f498fd6-08a0-482f-8c26-98f94f0c501a	delta_dental	PPO	D0150	SC	\N	92.50	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
381bc206-82b9-42df-bf87-09d28d4512eb	cigna	DPPO	D0150	SC	\N	97.13	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
1a565d25-dbb0-4759-a672-4303b19b0c44	metlife	PDP	D0150	SC	\N	90.66	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
59ec18d6-56b7-4f3e-b5d0-acf58fcf926a	delta_dental	PPO	D0330	SC	\N	150.93	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
a24d09b9-9555-4c37-9b50-2179c72a822e	cigna	DPPO	D0330	SC	\N	158.48	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
262ee272-ad9d-49e0-b15b-14050a8405cd	metlife	PDP	D0330	SC	\N	147.91	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
896fdb27-89bb-4e8c-b7b5-51734999b00d	delta_dental	PPO	D1110	SC	\N	107.11	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
9433d412-f824-4b48-aa9c-d3cab4bdeece	cigna	DPPO	D1110	SC	\N	112.47	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
9023e53b-fb8b-4f29-a478-d6290cdbf2be	metlife	PDP	D1110	SC	\N	104.97	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
e06df9f2-f574-4b80-98b6-a86839a65311	delta_dental	PPO	D1120	SC	\N	82.76	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
dd33db6d-1401-49c0-89f6-22f00253e2ea	cigna	DPPO	D1120	SC	\N	86.91	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
e15298cd-544f-43e5-a212-26315513e3b6	metlife	PDP	D1120	SC	\N	81.11	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
1e679c98-34d1-4371-b75f-2e0f716ac1af	delta_dental	PPO	D1351	SC	\N	63.29	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
c885b6a5-d145-4d7e-8452-037954260219	cigna	DPPO	D1351	SC	\N	66.46	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
294352a0-57f8-4a56-9665-10dae079b97b	metlife	PDP	D1351	SC	\N	62.03	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
b746bb33-4b2a-4411-a92a-9bc6f42da502	delta_dental	PPO	D2140	SC	\N	170.40	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
faf0d111-50aa-4364-8775-f71e89ab6f12	cigna	DPPO	D2140	SC	\N	178.92	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
4b14392c-c771-4dfa-90d0-515f7eef32e4	metlife	PDP	D2140	SC	\N	167.00	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
9bdbadd1-aab2-4540-a6d6-76ab092c8bf1	delta_dental	PPO	D2150	SC	\N	204.49	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
8bc4b4f6-2dd7-4ecd-9223-4ceeaf329bf4	cigna	DPPO	D2150	SC	\N	214.71	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
aeafe672-03f0-4a52-a5d4-fd0867425916	metlife	PDP	D2150	SC	\N	200.39	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
ffe71d2f-cc5a-41be-9ea3-afd83cf344ff	delta_dental	PPO	D2160	SC	\N	243.44	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
b9e1ce4b-b62f-4344-bb58-faf4f59cc306	cigna	DPPO	D2160	SC	\N	255.61	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
cdae77e4-fbe2-41c3-b07b-aebf3540a8bd	metlife	PDP	D2160	SC	\N	238.56	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
0bd22262-b807-46dd-a842-f0a84e91dc44	delta_dental	PPO	D2161	SC	\N	282.39	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
d936387b-864e-4267-a445-ea966f854d2f	cigna	DPPO	D2161	SC	\N	296.50	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
8177f7c2-80b9-4456-8e1c-e8dad8ca35c9	metlife	PDP	D2161	SC	\N	276.73	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
72851b86-1419-4f6e-b4b1-8536dcecc9c9	delta_dental	PPO	D3310	SC	\N	852.03	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
8a5caa6c-9e44-492e-b71c-02ed9b8f7a34	cigna	DPPO	D3310	SC	\N	894.63	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
e3f74ec6-a3fc-43ca-abbe-9437f2cb7409	metlife	PDP	D3310	SC	\N	834.99	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
5cc2e38f-3d34-45b1-b620-bd2971b95523	delta_dental	PPO	D3320	SC	\N	949.40	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
0d267d19-d7d1-4616-acef-272651697a01	cigna	DPPO	D3320	SC	\N	996.87	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
c97c3922-6942-4157-977d-5afec5a1dfd0	metlife	PDP	D3320	SC	\N	930.42	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
28775285-a7f6-4c94-a4f8-69ce529827b2	delta_dental	PPO	D4260	SC	\N	954.27	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
8e3a78d1-0d08-4c7c-94c1-13a77becf7cb	cigna	DPPO	D4260	SC	\N	1001.98	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
9989a682-e182-4704-93ab-239f37b3ba60	metlife	PDP	D4260	SC	\N	935.19	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
07f5f552-3cf4-4cee-ac54-f1acfc75f96e	delta_dental	PPO	D4341	SC	\N	258.04	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
b2c279b7-6adf-4556-a4cc-9f9e6c11473a	cigna	DPPO	D4341	SC	\N	270.95	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
07a9bea0-c6cb-42a3-baa4-51af6f32b38a	metlife	PDP	D4341	SC	\N	252.88	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
0c1352be-94d8-4e00-bcf6-01eb19e14ffd	delta_dental	PPO	D4910	SC	\N	141.19	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
04021905-7de1-4915-bef4-545287f79adb	cigna	DPPO	D4910	SC	\N	148.26	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
a69165f6-94da-4096-be5a-8165ffffb5e0	metlife	PDP	D4910	SC	\N	138.37	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
631606b6-601b-4a88-9d28-dd6cce500927	delta_dental	PPO	D7140	SC	\N	180.14	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
bd28fbba-17bf-4f1e-a4e3-7350b6e72840	cigna	DPPO	D7140	SC	\N	189.15	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
eaf58501-62bd-47f5-971c-d0254113a9b2	metlife	PDP	D7140	SC	\N	176.54	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
14364d1c-71b0-4abf-84a4-d98be5f1015c	delta_dental	PPO	D7210	SC	\N	277.51	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
44259443-b460-4148-9518-5dcecb6b9735	cigna	DPPO	D7210	SC	\N	291.39	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
5f3585b5-ed7e-449e-b377-764d25b29543	metlife	PDP	D7210	SC	\N	271.97	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
834ebc70-083e-4713-a7c1-57500ab772e0	delta_dental	PPO	D9110	SC	\N	92.50	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
f6d355af-e044-44ef-b6ee-b00c9404d9dc	cigna	DPPO	D9110	SC	\N	97.13	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
dac27828-a883-49a2-9e4f-361508c4f788	metlife	PDP	D9110	SC	\N	90.66	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
aeb01d36-4521-417c-a2db-89276c33d9e1	delta_dental	PPO	D9230	SC	\N	121.71	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
a52da246-1f15-49f0-a98c-b17bebba2100	cigna	DPPO	D9230	SC	\N	127.80	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
32aec4cb-7293-4a79-93a8-296ef87af5ce	metlife	PDP	D9230	SC	\N	119.28	2025-07-01	sc_medicaid_estimated	2026-08-06 02:31:15.579205+00
6ba981f2-eea9-42b8-84ab-c498686bad00	delta_dental	PPO	D2740	TN	\N	1212.50	2026-01-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
ca43c671-c51a-4363-9086-c14a34d2c67c	delta_dental	PPO	D2750	TN	\N	1154.30	2026-01-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
5dca8ed7-7b12-417e-aff9-9f954e561fce	delta_dental	PPO	D3330	TN	\N	1018.50	2026-01-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
168eadbf-91ad-4cc3-bab8-b877766f588b	delta_dental	PPO	D6010	TN	\N	1925.45	2026-01-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
57e5e6f0-86fe-401e-81b3-253fd31b65f1	delta_dental	PPO	D6065	TN	\N	1154.30	2026-01-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
bea72a88-d7d0-4da8-8bb7-f4d404321028	delta_dental	PPO	D7953	TN	\N	412.25	2026-01-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
af6e23ae-eff6-48d9-8b97-6835394ea3d4	cigna	DPPO	D2740	TN	\N	1273.12	2026-01-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
44606b4b-9768-491c-b028-be861973f35c	cigna	DPPO	D2750	TN	\N	1212.01	2026-01-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
3c77fa09-4195-4b66-a0a1-f6c881831ac0	cigna	DPPO	D3330	TN	\N	1069.42	2026-01-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
e54630a4-70f0-482e-a274-160826f2915c	cigna	DPPO	D6010	TN	\N	2021.72	2026-01-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
7b0e0e62-35d7-4067-bbb4-7778cef85de6	cigna	DPPO	D6065	TN	\N	1212.01	2026-01-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
17ccb943-1750-4965-8150-688d50b038b5	cigna	DPPO	D7953	TN	\N	432.86	2026-01-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
79377607-4140-4761-abe3-e206e1e27e3a	delta_dental	PPO	D0210	TN	\N	173.99	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
11fda2f1-281d-4d55-88fd-e51eb720ce5f	cigna	DPPO	D0210	TN	\N	182.69	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
0e7ba194-e852-47e1-af6b-d4b6b70a1af7	metlife	PDP	D0210	TN	\N	170.52	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
c8650544-532d-4a4f-b833-4db55a61638e	delta_dental	PPO	D0220	TN	\N	34.79	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
902b1881-f877-4792-a50f-9665d3fe684d	cigna	DPPO	D0220	TN	\N	36.54	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
5ab8b353-d0a9-447a-b396-2772d8650678	metlife	PDP	D0220	TN	\N	34.11	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
960c4842-a1fe-48ee-b795-cd387357f171	delta_dental	PPO	D0274	TN	\N	74.56	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
4efe5504-77ce-405b-ab98-534f6417af04	metlife	PDP	D2740	TN	\N	1188.25	2026-01-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
9210f70f-a2e8-4b17-976a-1dd274b81e47	metlife	PDP	D2750	TN	\N	1131.21	2026-01-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
9218bd54-86f7-4530-bd65-781069e8fe4d	cigna	DPPO	D0274	TN	\N	78.30	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
cd34b3df-0912-40b8-a70a-96d769388a7a	metlife	PDP	D0274	TN	\N	73.08	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
3c856cc7-dd90-4c52-ac57-1f88e91f2f12	metlife	PDP	D3330	TN	\N	998.13	2026-01-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
7fc460ba-8ba5-4701-a4a9-552426328305	metlife	PDP	D6010	TN	\N	1886.94	2026-01-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
f79b1751-184e-4bee-adf4-f1cac805d060	metlife	PDP	D6065	TN	\N	1131.21	2026-01-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
6e4d5304-aaef-4bf1-8515-120e6636cc83	metlife	PDP	D7953	TN	\N	404.00	2026-01-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
196314c3-e3d1-49bc-9a7b-1bedd7515c58	delta_dental	PPO	D0120	TN	\N	54.68	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
cf4052b2-440d-40e7-8a01-4858068885f9	cigna	DPPO	D0120	TN	\N	57.41	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
5a332f02-4ec7-4852-b0c6-b8b60200c4d8	metlife	PDP	D0120	TN	\N	53.59	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
5ae2c260-d907-4b42-ba02-cb70c68db221	delta_dental	PPO	D0150	TN	\N	94.45	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
411e70c6-53b4-476e-9056-d80c1c1aeb3d	cigna	DPPO	D0150	TN	\N	99.17	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
8e78c4a0-9ad4-483a-a540-d0e716d20ec5	metlife	PDP	D0150	TN	\N	92.57	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
65b64960-6142-45cf-87b4-ae3229d1e6f8	delta_dental	PPO	D0330	TN	\N	154.10	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
f374e815-85c2-4f62-8aac-55424941b4db	cigna	DPPO	D0330	TN	\N	161.82	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
c1c56dab-b1c5-44ed-9274-3f0760bb5e02	metlife	PDP	D0330	TN	\N	151.03	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
2b8094b7-72ed-4b18-9fd4-a0a147eae106	delta_dental	PPO	D1110	TN	\N	109.37	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
f3afe4f3-9934-43cf-b081-689e94b04ff6	cigna	DPPO	D1110	TN	\N	114.84	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
55ed4668-4df4-45e0-aa71-0477b42f2ef7	metlife	PDP	D1110	TN	\N	107.18	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
8a42e99c-2d69-4281-8704-0495a8dfeff3	delta_dental	PPO	D1120	TN	\N	84.51	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
30c0a74e-66b6-452c-9ee8-e9b57ec6eb0a	cigna	DPPO	D1120	TN	\N	88.74	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
aee6dded-937b-46da-a8c0-4529acb0eef5	metlife	PDP	D1120	TN	\N	82.82	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
bdb94bae-8a87-433b-b493-657c0f2da6bd	delta_dental	PPO	D1351	TN	\N	64.62	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
de8863e4-7eee-47c4-9244-8f2a1915cef2	cigna	DPPO	D1351	TN	\N	67.86	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
80f1c7c8-c728-4ba1-9c90-6879dee2d4b8	metlife	PDP	D1351	TN	\N	63.33	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
0be515cc-83bd-431f-8c52-eb69a11a69d3	delta_dental	PPO	D2140	TN	\N	173.99	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
5e76537e-b787-4751-9ea9-dc7616a8ec35	cigna	DPPO	D2140	TN	\N	182.69	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
692b8ffa-93ae-480b-a04e-17ed5473f45f	metlife	PDP	D2140	TN	\N	170.52	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
1c694215-ae11-4505-a747-21f38407a07e	delta_dental	PPO	D2150	TN	\N	208.79	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
5e74af47-b382-4ec9-8cd6-a0a5eac54106	cigna	DPPO	D2150	TN	\N	219.23	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
30c07eef-5f5a-47f0-a8e1-7a59c636f04a	metlife	PDP	D2150	TN	\N	204.61	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
ce9f39c5-6f7b-4ae9-ba3e-271d6bfab16f	delta_dental	PPO	D2160	TN	\N	248.56	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
50752cf0-20f6-4c92-a194-72f7513f0676	cigna	DPPO	D2160	TN	\N	260.99	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
b8d88059-dfe5-4eed-9401-3c908408735c	metlife	PDP	D2160	TN	\N	243.59	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
2ee9d54b-0e4d-46e2-859d-8c2807fa0286	delta_dental	PPO	D2161	TN	\N	288.33	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
b1563140-c663-432f-83be-65594711d2e2	cigna	DPPO	D2161	TN	\N	302.75	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
8aff0a54-8aa9-400d-9fcc-631dc13cd760	metlife	PDP	D2161	TN	\N	282.56	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
847c80a4-5afd-4941-98a3-005b8eecdeeb	delta_dental	PPO	D3310	TN	\N	869.96	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
c988da2b-2e6e-4589-a31a-adb29a2dabf2	cigna	DPPO	D3310	TN	\N	913.47	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
dcb9ec3c-b3fc-49ed-8014-7aa0876f423f	metlife	PDP	D3310	TN	\N	852.57	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
ad43264a-09b2-44f1-a968-6f30806985cf	delta_dental	PPO	D3320	TN	\N	969.39	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
4628ca37-22da-46e8-84a1-7d0ec8ede51c	cigna	DPPO	D3320	TN	\N	1017.86	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
c749f640-0d62-4f94-9a05-23ade063c015	metlife	PDP	D3320	TN	\N	950.01	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
68b8568f-a5bf-4244-9a66-80098550de4f	delta_dental	PPO	D4260	TN	\N	974.36	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
ae26afb1-7a0a-4ec3-a1ca-3c23b7bde10c	cigna	DPPO	D4260	TN	\N	1023.08	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
3ae9a4e5-4b2e-4037-a2b7-ab54ea772297	metlife	PDP	D4260	TN	\N	954.88	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
d7c61b7b-d73f-41a1-99db-ea21417c268a	delta_dental	PPO	D4341	TN	\N	263.47	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
e3455f9e-1f28-4ed3-820a-fa3b0998a19b	cigna	DPPO	D4341	TN	\N	276.65	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
0bda953c-dcf1-413e-bddb-aeca41d6d332	metlife	PDP	D4341	TN	\N	258.20	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
aa49c139-f075-4620-8d3e-778bc3d8f240	delta_dental	PPO	D4910	TN	\N	144.16	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
048aa433-8a67-4c51-9045-d037e31186d4	cigna	DPPO	D4910	TN	\N	151.38	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
2d8f3670-ad1e-40d3-96db-6666724042d5	metlife	PDP	D4910	TN	\N	141.28	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
51e571d7-e587-4ea0-b9a1-3afc2ed8c137	delta_dental	PPO	D7140	TN	\N	183.93	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
4a3029c1-49e8-4199-8bcf-752700243a98	cigna	DPPO	D7140	TN	\N	193.14	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
045b5165-d544-4616-8f72-464781134eca	metlife	PDP	D7140	TN	\N	180.26	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
7cc717da-df24-4a9e-87be-b7029a3094ca	delta_dental	PPO	D7210	TN	\N	283.36	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
37cb8ba1-d76f-4d6f-a860-0ed8a0907188	cigna	DPPO	D7210	TN	\N	297.53	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
8382aa4f-bf10-4e7c-9333-982827b15974	metlife	PDP	D7210	TN	\N	277.69	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
cd52e1d1-3a0f-45ee-9117-372b7828ce83	delta_dental	PPO	D9110	TN	\N	94.45	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
25707cdb-f34a-46c3-9c24-620b978861d1	cigna	DPPO	D9110	TN	\N	99.17	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
606b125f-e667-48ac-9971-940ece6572ba	metlife	PDP	D9110	TN	\N	92.57	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
8f2f289e-5776-4a50-b34a-ce33ccfd9732	delta_dental	PPO	D9230	TN	\N	124.28	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
731567b5-e271-488a-a05d-3d7f32851376	cigna	DPPO	D9230	TN	\N	130.49	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
ecff4853-22db-4da4-99c7-6c33559e4f56	metlife	PDP	D9230	TN	\N	121.79	2025-07-01	tn_medicaid_estimated	2026-08-06 02:31:15.579205+00
8babe2a0-0034-45f2-aed4-012f907187b6	delta_dental	PPO	D2740	AL	\N	1150.00	2026-01-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
7968c076-8438-4f17-9d0e-9efd89912d2a	delta_dental	PPO	D2750	AL	\N	1094.80	2026-01-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
f8c67b47-60ce-4373-85cb-d7930eeb569f	delta_dental	PPO	D3330	AL	\N	966.00	2026-01-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
e38b5dc4-e307-47a8-b501-4f612fc0a317	delta_dental	PPO	D6010	AL	\N	1826.20	2026-01-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
98ce3fd1-5e5f-48aa-af53-f8ebe82cd649	delta_dental	PPO	D6065	AL	\N	1094.80	2026-01-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
695107dc-7446-45cc-aaae-21c7b7eb28f4	delta_dental	PPO	D7953	AL	\N	391.00	2026-01-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
9221657f-da71-4e4e-9946-ff8e8213b27c	cigna	DPPO	D2740	AL	\N	1207.50	2026-01-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
c87e69ee-f7a8-4769-a32f-f0453f4ae15c	cigna	DPPO	D2750	AL	\N	1149.54	2026-01-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
7dcc73de-c114-49fa-b7b3-e44e0db6c953	cigna	DPPO	D3330	AL	\N	1014.30	2026-01-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
a3bf9c19-eac2-41bf-84a2-1566078432de	cigna	DPPO	D6010	AL	\N	1917.51	2026-01-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
6ece3340-abb4-4bf3-9975-063260a30682	cigna	DPPO	D6065	AL	\N	1149.54	2026-01-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
6cc7627d-2181-4b5d-8362-13aaee0cad7a	cigna	DPPO	D7953	AL	\N	410.55	2026-01-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
0fa9bc40-22d0-40af-aba5-4387fed7bac9	delta_dental	PPO	D0210	AL	\N	165.02	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
fc12d072-1623-45e3-b6d6-87ff5a0e19a8	cigna	DPPO	D0210	AL	\N	173.27	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
d9e986cd-0229-445c-b355-d9a815c350ce	metlife	PDP	D0210	AL	\N	161.73	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
c033fa19-6e90-45ad-b107-251f6b30a378	delta_dental	PPO	D0220	AL	\N	33.00	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
1cdde638-6025-4e9b-8dec-630f645f1b78	cigna	DPPO	D0220	AL	\N	34.66	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
45076bba-1722-48b7-927f-4c7ae9f5762a	metlife	PDP	D0220	AL	\N	32.35	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
b2d3352c-4931-43e5-a010-0b4ac5aa4301	delta_dental	PPO	D0274	AL	\N	70.72	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
25ff73d5-7469-42bb-adec-813a0ffb9db2	metlife	PDP	D2740	AL	\N	1127.00	2026-01-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
11a37623-3687-4ec8-9bae-552607f7295a	metlife	PDP	D2750	AL	\N	1072.90	2026-01-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
1c4e0b5e-6279-49fe-96e5-23f8e5544c5f	cigna	DPPO	D0274	AL	\N	74.26	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
7a993c5d-f207-4428-88fa-d11779fe1217	metlife	PDP	D0274	AL	\N	69.31	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
b440194b-2330-4306-8cdd-7d6f6bfc0c10	metlife	PDP	D3330	AL	\N	946.68	2026-01-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
fc9411a0-b5eb-4d75-af9b-7f659c9ccb46	metlife	PDP	D6010	AL	\N	1789.68	2026-01-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
95fbcb33-e0b4-414f-a386-d1e327c3595d	metlife	PDP	D6065	AL	\N	1072.90	2026-01-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
2747c823-f6df-48ff-96e7-696d34f9c0d3	metlife	PDP	D7953	AL	\N	383.18	2026-01-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
eb8d8c1c-6a14-42a2-9d41-6ea2241e1826	delta_dental	PPO	D0120	AL	\N	51.86	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
53847a8e-2a58-4a47-9ac4-7a1b1145fa4b	cigna	DPPO	D0120	AL	\N	54.45	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
2d84dbf0-1eb9-4c2f-9b0b-c0739fb937ad	metlife	PDP	D0120	AL	\N	50.83	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
aa094abb-aaae-4d5d-bb7a-f0c0758e8e16	delta_dental	PPO	D0150	AL	\N	89.58	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
81ff269d-0bb3-4b64-88be-2982d35b0b55	cigna	DPPO	D0150	AL	\N	94.06	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
d2e53a03-dfb9-48a6-835a-ab346094724c	metlife	PDP	D0150	AL	\N	87.80	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
20e8d430-8bc4-42b7-a009-d8790e0aa09e	delta_dental	PPO	D0330	AL	\N	146.16	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
8797500e-4619-4794-b735-89a26dfa97e9	cigna	DPPO	D0330	AL	\N	153.47	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
3ecbbfbf-7627-44c7-a32b-a27c8695bc3f	metlife	PDP	D0330	AL	\N	143.24	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
1fa1c9cc-e333-41dd-a27e-026fd2c22852	delta_dental	PPO	D1110	AL	\N	103.73	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
9a9a18c9-9219-4047-acbe-feda613eaa62	cigna	DPPO	D1110	AL	\N	108.92	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
df2396fd-834f-4fb9-8650-8d42f797f32b	metlife	PDP	D1110	AL	\N	101.65	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
1d23f0c4-5e71-4269-a287-082c2019f24a	delta_dental	PPO	D1120	AL	\N	80.15	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
dcc8f877-3018-42ee-b2ce-6d4ea25860e0	cigna	DPPO	D1120	AL	\N	84.16	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
6377c0c8-aed8-46b6-b77b-18cd5f3cecbb	metlife	PDP	D1120	AL	\N	78.55	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
e0be98cf-8bcc-4af4-a5c9-fe2e071de60f	delta_dental	PPO	D1351	AL	\N	61.29	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
aad1e568-0676-4539-a52c-e790ea9b9d24	cigna	DPPO	D1351	AL	\N	64.36	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
d4c3ecc0-54c7-46d9-85d9-4ccadb1f9102	metlife	PDP	D1351	AL	\N	60.07	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
dbebd1ba-5ecd-4cdd-9ee6-21667fab3b2b	delta_dental	PPO	D2140	AL	\N	165.02	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
10a6a570-09c6-4fcf-a8a6-3f2049ff74e8	cigna	DPPO	D2140	AL	\N	173.27	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
61151ecb-ce8a-425c-a446-557e1d7faa72	metlife	PDP	D2140	AL	\N	161.73	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
bdfdc979-639c-4da2-91aa-aed5d40c1afc	delta_dental	PPO	D2150	AL	\N	198.03	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
d8e993b7-e1fe-4f49-887f-69fb6cdc335c	cigna	DPPO	D2150	AL	\N	207.93	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
10e41a1a-dbe4-42e8-9869-b1bfa6aa4dcd	metlife	PDP	D2150	AL	\N	194.06	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
5cf8fab4-6517-47f3-b1e8-cbe98a75f037	delta_dental	PPO	D2160	AL	\N	235.75	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
9f2fe8b9-b658-4676-a615-933b3b9dc3b0	cigna	DPPO	D2160	AL	\N	247.54	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
908177bb-fb44-4790-94e5-58ad42d3f252	metlife	PDP	D2160	AL	\N	231.03	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
f10d1697-24be-4bc8-aef5-2ce5c174d541	delta_dental	PPO	D2161	AL	\N	273.47	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
981889d1-0a28-4778-a540-2f8ff80b7a44	cigna	DPPO	D2161	AL	\N	287.14	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
64b59cba-fd98-42f5-b3ed-f749c6c5f10e	metlife	PDP	D2161	AL	\N	268.00	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
c3b0adea-8b27-43ea-b374-c0a32af59693	delta_dental	PPO	D3310	AL	\N	825.12	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
0c82c5c6-dd8f-4d4b-b7b7-79b4beeb3b66	cigna	DPPO	D3310	AL	\N	866.38	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
e9f1f6ad-c219-45d2-ba76-5a19db5f1830	metlife	PDP	D3310	AL	\N	808.62	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
14af8a63-4461-4bd7-939f-accc2f1ce176	delta_dental	PPO	D3320	AL	\N	919.42	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
12bda587-0239-4183-b950-8f4c292f7e8b	cigna	DPPO	D3320	AL	\N	965.39	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
86b1599c-98c4-4153-81f0-240dee7641c6	metlife	PDP	D3320	AL	\N	901.04	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
a00f5379-1406-43a6-a793-b08e0fffc10d	delta_dental	PPO	D4260	AL	\N	924.14	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
c8579c7a-330d-458c-a3bc-ad8b8d927977	cigna	DPPO	D4260	AL	\N	970.34	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
791edc37-6e9e-4399-9dd4-ac1e608e0ea5	metlife	PDP	D4260	AL	\N	905.66	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
0ef7d957-9ad4-4ca0-9fda-b819dd827691	delta_dental	PPO	D4341	AL	\N	249.89	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
02f39f75-2e0f-49cb-828f-d39ca177f59e	cigna	DPPO	D4341	AL	\N	262.39	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
bb0daebc-b6f3-4700-bec7-6aa555265715	metlife	PDP	D4341	AL	\N	244.89	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
1ea540e7-b6b9-4f5f-85ad-dfc871070fcb	delta_dental	PPO	D4910	AL	\N	136.73	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
41898663-8daf-4b8b-a6ea-6d55ec3e929e	cigna	DPPO	D4910	AL	\N	143.58	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
af2536ea-17d9-4221-89e0-f7060e972bcf	metlife	PDP	D4910	AL	\N	134.00	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
6a485fd4-cf78-4cd1-8e84-21bef41b6cea	delta_dental	PPO	D7140	AL	\N	174.45	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
a6bd34f7-8bec-44d2-9d28-d917f70f2f90	cigna	DPPO	D7140	AL	\N	183.18	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
e4c16f09-588f-428d-9538-059186874900	metlife	PDP	D7140	AL	\N	170.96	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
6bdbd027-72be-4f68-b584-5ae1c5568963	delta_dental	PPO	D7210	AL	\N	268.75	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
3158dfb3-c121-4257-bc1d-49cf70c45086	cigna	DPPO	D7210	AL	\N	282.19	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
b92366cc-0947-4ad0-9864-3b143e5e9a29	metlife	PDP	D7210	AL	\N	263.38	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
899cd1fb-b25f-4294-8ada-139c125d62fa	delta_dental	PPO	D9110	AL	\N	89.58	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
0d0c657d-fb6f-4f16-9eb5-0e72da900bb9	cigna	DPPO	D9110	AL	\N	94.06	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
91f0cf85-44c7-420b-9a77-ef5a7dde04dd	metlife	PDP	D9110	AL	\N	87.80	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
a708eae5-365d-44d3-aee5-9d9d58661e08	delta_dental	PPO	D9230	AL	\N	117.87	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
df9ac055-4f9f-4b12-a33b-078c10edc29a	cigna	DPPO	D9230	AL	\N	123.77	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
ed6e77ea-57db-44ee-8418-f161b4b73dd4	metlife	PDP	D9230	AL	\N	115.52	2025-07-01	al_medicaid_estimated	2026-08-06 02:31:15.579205+00
ac7397f9-be96-4c5b-9fb7-9d733b8607c6	aetna_dmo	DMO	D0120	GA	\N	50.73	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
1498c264-b279-4abf-b014-b0ec50044138	aetna_dmo	DMO	D0120	FL	\N	53.27	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
f96b7565-8043-4ec6-a178-81c5cc275724	aetna_dmo	DMO	D0120	TX	\N	55.81	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
156bd4d9-187b-4aa4-8bcf-17c585129e28	aetna_dmo	DMO	D0120	NC	\N	49.72	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
804fdc58-6c1b-4125-90d2-9ebeaa16c3e6	aetna_dmo	DMO	D0120	SC	\N	48.20	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
f6f44999-b842-4e78-b75f-34ba54ccee4d	aetna_dmo	DMO	D0120	TN	\N	49.21	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
35a8cf77-4210-4472-9c9b-e38493e5388f	aetna_dmo	DMO	D0120	AL	\N	46.67	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
66532421-37d2-49fb-a72c-9593cc4b839e	aetna_dmo	DMO	D0150	GA	\N	87.63	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
8239f05a-2d7d-45b3-916a-9c877d3138fd	aetna_dmo	DMO	D0150	FL	\N	92.01	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
02e544df-5696-4164-bc1b-c3f921445af4	aetna_dmo	DMO	D0150	TX	\N	96.40	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
b906357d-e3f5-4ef2-92ef-f1cf711b35ee	aetna_dmo	DMO	D0150	NC	\N	85.88	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
2336e71b-d8b4-4a2d-b6ed-b383cc833d54	aetna_dmo	DMO	D0150	SC	\N	83.25	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
a0459778-cf07-4d74-8248-5c2158d151fb	aetna_dmo	DMO	D0150	TN	\N	85.00	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
1ba80634-6e4b-407f-8027-d0ec7a2fc6b3	aetna_dmo	DMO	D0150	AL	\N	80.62	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
5cd47e1e-3420-4205-bee2-decb81204402	aetna_dmo	DMO	D0210	GA	\N	161.43	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
1b793077-47b4-4534-b4d7-f5708ad42194	aetna_dmo	DMO	D0210	FL	\N	169.50	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
e05031a9-c801-48c0-a6eb-e072e7426127	aetna_dmo	DMO	D0210	TX	\N	177.58	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
dc3a3be4-463a-47ac-897c-3e9be6133d85	aetna_dmo	DMO	D0210	NC	\N	158.20	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
e5b7172d-49ec-4ce6-8fa7-41f8ca2cd66f	aetna_dmo	DMO	D0210	SC	\N	153.36	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
8ab6cb54-53b6-443c-bd40-c373b6da2578	aetna_dmo	DMO	D0210	TN	\N	156.59	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
215ff357-3819-4385-a901-67a0c4d8911d	aetna_dmo	DMO	D0210	AL	\N	148.52	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
797033e7-e95e-416b-aa6c-8e338737284b	aetna_dmo	DMO	D0220	GA	\N	32.28	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
e63f4494-d8c7-4fc4-920d-2e2a23e0f78d	aetna_dmo	DMO	D0220	FL	\N	33.90	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
ec57dea7-7bd8-4c89-ab5a-185aa9cde4a7	aetna_dmo	DMO	D0220	TX	\N	35.51	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
322cbaed-7269-4ada-a423-7129ab824d18	aetna_dmo	DMO	D0220	NC	\N	31.64	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
e593d876-3dfe-48f6-987d-fb7ae5e1fd53	aetna_dmo	DMO	D0220	SC	\N	30.67	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
39b4e95c-fb84-44b8-b8b7-19b4796da99a	aetna_dmo	DMO	D0220	TN	\N	31.31	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
23ae79e7-c9d4-41bc-b9b4-7bd9f6ef9da3	aetna_dmo	DMO	D0220	AL	\N	29.70	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
f3b13ec3-86b2-4fcb-a627-2d3e694309f1	aetna_dmo	DMO	D0274	GA	\N	69.18	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
97bc1dc2-b529-481a-b306-b2d873a0ae4b	aetna_dmo	DMO	D0274	FL	\N	72.64	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
c21276d1-3784-4534-aa1a-5cbe11073a17	aetna_dmo	DMO	D0274	TX	\N	76.10	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
16f5edb8-b4ed-4f89-affe-dc96bec4fe16	aetna_dmo	DMO	D0274	NC	\N	67.80	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
082864ac-5bc2-4244-ab2f-9c4262257e23	aetna_dmo	DMO	D0274	SC	\N	65.72	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
9916f3a3-3953-4678-b127-0d127400615a	aetna_dmo	DMO	D0274	TN	\N	67.11	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
6b5dab3d-e23e-4fc9-95f7-5938fe5e9f22	aetna_dmo	DMO	D0274	AL	\N	63.65	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
ab0c7b28-7ecf-4412-9929-026ddd28bbce	aetna_dmo	DMO	D0330	GA	\N	142.98	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
64e10791-dcac-4be9-aa50-43ed30eefda2	aetna_dmo	DMO	D0330	FL	\N	150.13	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
30ad1bae-f9f4-4f14-8b59-b5aebe42b8c0	aetna_dmo	DMO	D0330	TX	\N	157.28	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
c4c25de9-0c20-42ff-851c-cb31bf42b2d4	aetna_dmo	DMO	D0330	NC	\N	140.12	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
94ebab42-7706-4b86-bff3-c8e8c1a16a97	aetna_dmo	DMO	D0330	SC	\N	135.83	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
f3880b91-0e61-461e-ae1c-b180c60265c9	aetna_dmo	DMO	D0330	TN	\N	138.69	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
3e90fb01-c089-45a8-a1a0-cca273e60aea	aetna_dmo	DMO	D0330	AL	\N	131.54	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
6ca377ed-ce18-4bdd-bcff-2a5693bcc764	aetna_dmo	DMO	D1110	GA	\N	101.48	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
e7cb85dc-c914-4676-a4b4-779e9314f96e	aetna_dmo	DMO	D1110	FL	\N	106.55	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
599756be-4e56-4ebd-8c1b-95a3c3d4aac2	aetna_dmo	DMO	D1110	TX	\N	111.62	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
cbbf2f06-a342-4891-a86f-1b63fa52a233	aetna_dmo	DMO	D1110	NC	\N	99.45	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
b9633189-9319-4250-8869-de766b30e6d1	aetna_dmo	DMO	D1110	SC	\N	96.40	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
1e4da998-465e-4cd3-80c6-51eff3edc146	aetna_dmo	DMO	D1110	TN	\N	98.43	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
5359b88b-eb4e-475f-a20a-493c6e896dd6	aetna_dmo	DMO	D1110	AL	\N	93.36	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
12a0d411-f329-43a5-8244-a9a21b580c2a	aetna_dmo	DMO	D1120	GA	\N	78.41	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
e4fa381c-708e-43ac-909b-e4ca913aea96	aetna_dmo	DMO	D1120	FL	\N	82.33	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
0afb7665-2314-49de-8545-e78a9b240ba6	aetna_dmo	DMO	D1120	TX	\N	86.25	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
423c8d25-1350-4e1f-80b1-b5c0517b98c3	aetna_dmo	DMO	D1120	NC	\N	76.84	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
ada523f0-9d7f-4a5a-806e-8de813b93470	aetna_dmo	DMO	D1120	SC	\N	74.49	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
fbef3185-cbe5-40b3-9b54-98b4f81691ab	aetna_dmo	DMO	D1120	TN	\N	76.06	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
f228083c-0df9-4cac-a29c-ce838fb945d1	aetna_dmo	DMO	D1120	AL	\N	72.14	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
fbde32a6-9b74-43b1-813d-ecd8dc32eb92	aetna_dmo	DMO	D1351	GA	\N	59.96	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
6e6fa3b6-5daa-4291-9d24-ee92b4304037	aetna_dmo	DMO	D1351	FL	\N	62.96	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
ba06ae25-0bc8-4658-ab0e-c6f006631822	aetna_dmo	DMO	D1351	TX	\N	65.95	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
117f501b-547a-4aca-aade-a7e3e094a6f2	aetna_dmo	DMO	D1351	NC	\N	58.76	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
2abca615-a5cc-4582-96a6-679f4c1c6b00	aetna_dmo	DMO	D1351	SC	\N	56.96	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
6cce419e-0a45-41c8-8f9b-d6e59bb38069	aetna_dmo	DMO	D1351	TN	\N	58.16	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
ac010dfa-bdee-4291-bc1b-d3a5b5344638	aetna_dmo	DMO	D1351	AL	\N	55.16	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
d73c2bb7-8225-41d0-b51f-981b50782920	aetna_dmo	DMO	D2140	GA	\N	161.43	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
ab136c74-8806-48f1-93fe-97b0753082e3	aetna_dmo	DMO	D2140	FL	\N	169.50	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
5c689688-bb57-432a-b57f-478834744e44	aetna_dmo	DMO	D2140	TX	\N	177.58	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
4d9b706b-4bdf-4d63-9751-bc38dd471b1a	aetna_dmo	DMO	D2140	NC	\N	158.20	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
0e4d353e-8c9c-4cae-9fc9-4a5099727e70	aetna_dmo	DMO	D2140	SC	\N	153.36	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
1f3c475a-fae8-42d3-b16a-7b60c0b1bd3f	aetna_dmo	DMO	D2140	TN	\N	156.59	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
a52b3277-f9fd-46d2-88cb-9b6a6624197a	aetna_dmo	DMO	D2140	AL	\N	148.52	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
bda2b7bd-e2bb-45d1-a546-596cd42545b8	aetna_dmo	DMO	D2150	GA	\N	193.72	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
7d77035d-99ef-4543-ac15-f55c315641a7	aetna_dmo	DMO	D2150	FL	\N	203.41	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
a620c3e2-905d-416e-b3c0-18164ddbc8d3	aetna_dmo	DMO	D2150	TX	\N	213.10	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
86f1d0c9-6d74-459a-acbf-103bc4f6ac4c	aetna_dmo	DMO	D2150	NC	\N	189.85	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
fb248221-92e6-417c-8ece-88f8395ac4ca	aetna_dmo	DMO	D2150	SC	\N	184.04	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
bf93953c-7b9d-4d42-9ead-41e869ecda62	aetna_dmo	DMO	D2150	TN	\N	187.91	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
0cff0432-ef48-40a6-9ec6-6d2249df22ec	aetna_dmo	DMO	D2150	AL	\N	178.23	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
123837a3-5f97-48b3-9d7d-9f656b585d97	aetna_dmo	DMO	D2160	GA	\N	230.62	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
ffa319f0-ccbb-4a5b-82a4-cf0a7fae86a4	aetna_dmo	DMO	D2160	FL	\N	242.16	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
06201c24-bcb5-4465-9b4f-60565009353d	aetna_dmo	DMO	D2160	TX	\N	253.69	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
b9c5ff73-c85c-4e52-8d3f-c7ac70c2ce0b	aetna_dmo	DMO	D2160	NC	\N	226.01	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
adacafd0-6e85-4345-9c63-56f333780eef	aetna_dmo	DMO	D2160	SC	\N	219.09	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
95ed9b77-6a03-4458-b456-a936750db771	aetna_dmo	DMO	D2160	TN	\N	223.71	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
0a2d8a2b-73ce-4b6c-9b01-3a6052264faa	aetna_dmo	DMO	D2160	AL	\N	212.18	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
60331b75-d828-4bc2-86aa-5fc491596f8b	aetna_dmo	DMO	D2161	GA	\N	267.53	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
da5cb6f4-c76b-418d-8298-38728ddcd871	aetna_dmo	DMO	D2161	FL	\N	280.90	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
47e88ae2-0457-471f-91dd-5e412c28a17b	aetna_dmo	DMO	D2161	TX	\N	294.28	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
af369c14-ce5a-4a28-9bf5-d8d593f8b6fb	aetna_dmo	DMO	D2161	NC	\N	262.17	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
c0f8ce6d-1168-4861-a1a3-4ee44b6e87cc	aetna_dmo	DMO	D2161	SC	\N	254.15	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
b5e51cc2-0188-474b-a5a9-04c12f6cca55	aetna_dmo	DMO	D2161	TN	\N	259.50	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
5be99c41-4880-45a7-9d82-155e8ae566ff	aetna_dmo	DMO	D2161	AL	\N	246.12	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
cb21656b-2c51-4a1d-bae2-e800ec2fe0ce	aetna_dmo	DMO	D2740	GA	\N	1125.00	2026-01-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
c58362b1-cf5c-4656-b453-bf820a2bbae6	aetna_dmo	DMO	D2740	FL	\N	1181.25	2026-01-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
72ce82a6-2fda-4f11-a466-d21563a0aca1	aetna_dmo	DMO	D2740	TX	\N	1237.50	2026-01-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
32c33a79-f2bf-41ed-a378-871204e643d3	aetna_dmo	DMO	D2740	NC	\N	1102.50	2026-01-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
3de129a6-36b6-403a-8e2a-8735c0ef05c8	aetna_dmo	DMO	D2740	SC	\N	1068.75	2026-01-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
a621300a-bda9-499b-9590-278c51140249	aetna_dmo	DMO	D2740	TN	\N	1091.25	2026-01-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
7d558fff-b4e2-4746-b1a4-ee259b8f6e00	aetna_dmo	DMO	D2740	AL	\N	1035.00	2026-01-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
fdbc81ac-f0a6-49b7-acc5-ba228a23e6ad	aetna_dmo	DMO	D2750	GA	\N	1071.00	2026-01-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
cb7676b8-2d3e-4f36-ad13-bd7eb1862b2f	aetna_dmo	DMO	D2750	FL	\N	1124.55	2026-01-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
a29d1072-d5af-417a-b31b-59f0ae6339c7	aetna_dmo	DMO	D2750	TX	\N	1178.10	2026-01-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
851952d9-bfa4-42f6-b751-cbd5f0c10d14	aetna_dmo	DMO	D2750	NC	\N	1049.58	2026-01-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
495b8a93-daff-4bc3-af52-9a1f6f756ada	aetna_dmo	DMO	D2750	SC	\N	1017.45	2026-01-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
416193d1-aefe-40dd-9d51-84b2c5742cb3	aetna_dmo	DMO	D2750	TN	\N	1038.87	2026-01-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
42b4a105-40da-4f84-acd2-1cfbb12d6bbc	aetna_dmo	DMO	D2750	AL	\N	985.32	2026-01-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
e5cfe67b-3eb3-4941-8dae-b7c2f5834ee6	aetna_dmo	DMO	D3310	GA	\N	807.18	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
ec9d02c0-1185-4bcb-82e6-4341d1e89d17	aetna_dmo	DMO	D3310	FL	\N	847.54	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
73e3474f-269b-4d05-ac23-958e5492c0df	aetna_dmo	DMO	D3310	TX	\N	887.90	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
38ad3f36-b614-4ad6-b920-56480e026194	aetna_dmo	DMO	D3310	NC	\N	791.04	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
954d78a0-cc0e-4640-bb5e-f6038eeee013	aetna_dmo	DMO	D3310	SC	\N	766.82	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
9efaf673-4d64-4d47-b7ce-41121e05dab4	aetna_dmo	DMO	D3310	TN	\N	782.97	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
9da2dbf5-445b-4eb2-a9a2-35a16dab8862	aetna_dmo	DMO	D3310	AL	\N	742.61	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
c42ad720-3afb-47d4-b08a-1e722edd1f0d	aetna_dmo	DMO	D3320	GA	\N	899.43	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
2442e9cb-3122-4a03-bf62-8c9d2aa75a5f	aetna_dmo	DMO	D3320	FL	\N	944.40	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
2742253f-fbc9-4521-911c-aa3e96171812	aetna_dmo	DMO	D3320	TX	\N	989.38	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
d1488d9c-df59-46f8-9bd9-60ced0a29447	aetna_dmo	DMO	D3320	NC	\N	881.44	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
d78542a9-6a42-4c38-9db3-df76aefadf15	aetna_dmo	DMO	D3320	SC	\N	854.46	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
982f87e3-865f-4aff-9265-cbe912973fb0	aetna_dmo	DMO	D3320	TN	\N	872.45	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
3cf7a087-2e9a-4acf-9935-4d8753abd8d5	aetna_dmo	DMO	D3320	AL	\N	827.48	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
3e04ffba-7720-4c6b-b01b-9eccd24de4b7	aetna_dmo	DMO	D3330	GA	\N	945.00	2026-01-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
d90f35be-5a94-4e9a-a3da-89ecbfa06f63	aetna_dmo	DMO	D3330	FL	\N	992.25	2026-01-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
45a233ea-74ea-41e4-ae0b-913d88f10a60	aetna_dmo	DMO	D3330	TX	\N	1039.50	2026-01-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
e7ddf353-4d91-4fa2-9224-2c4cf58655a8	aetna_dmo	DMO	D3330	NC	\N	926.10	2026-01-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
700daff6-6be8-4109-9c9c-c16b51787fd5	aetna_dmo	DMO	D3330	SC	\N	897.75	2026-01-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
15415e50-79f1-46f7-9674-b7d19cd2a244	aetna_dmo	DMO	D3330	TN	\N	916.65	2026-01-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
cd02aee7-b773-4f91-912f-3a0b8fb85657	aetna_dmo	DMO	D3330	AL	\N	869.40	2026-01-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
3d477d59-1297-4895-ab74-be3166731791	aetna_dmo	DMO	D4260	GA	\N	904.05	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
c77b2857-be57-46d8-a36d-825a85ecfbfd	aetna_dmo	DMO	D4260	FL	\N	949.25	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
d040c88c-d8f1-4dba-8986-2329950cb254	aetna_dmo	DMO	D4260	TX	\N	994.46	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
0da95cd6-5f37-4b89-aa53-22234dfb1c45	aetna_dmo	DMO	D4260	NC	\N	885.97	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
c51f00a5-1a16-419b-879e-64b92c0310ea	aetna_dmo	DMO	D4260	SC	\N	858.85	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
72e871eb-cf41-4ca0-aaac-46c02b978ace	aetna_dmo	DMO	D4260	TN	\N	876.93	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
6f279f5c-39d3-4cee-bda3-77c68f5fa45d	aetna_dmo	DMO	D4260	AL	\N	831.73	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
7cde72e6-4f4f-4b56-9bf6-15cfe790838b	aetna_dmo	DMO	D4341	GA	\N	244.46	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
77107498-d406-4037-893b-a1758bae5a89	aetna_dmo	DMO	D4341	FL	\N	256.68	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
ae26edc5-024c-448b-bd38-919301747e1e	aetna_dmo	DMO	D4341	TX	\N	268.90	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
42ddc9ad-6890-410f-a3d8-93510af69997	aetna_dmo	DMO	D4341	NC	\N	239.57	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
9ea9a815-8abd-4c61-b50d-8c5a84b7ba1e	aetna_dmo	DMO	D4341	SC	\N	232.24	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
0020587e-b3a2-4ee1-acb4-c170b553dcb3	aetna_dmo	DMO	D4341	TN	\N	237.12	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
208f6dba-da8c-4ee7-84a4-ad314f933e2e	aetna_dmo	DMO	D4341	AL	\N	224.90	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
eb8c4eeb-890b-47f2-b007-3f3e80329fa0	aetna_dmo	DMO	D4910	GA	\N	133.76	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
1c040a4b-2b1e-4c88-81ff-24e86f42de1e	aetna_dmo	DMO	D4910	FL	\N	140.45	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
c904a7ae-0356-4aa9-bb8a-91b0a8f518e1	aetna_dmo	DMO	D4910	TX	\N	147.13	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
388ceeba-3540-4fc7-93f9-089bd2db55c7	aetna_dmo	DMO	D4910	NC	\N	131.08	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
ff3ce518-940b-45f4-a0d4-40be88740511	aetna_dmo	DMO	D4910	SC	\N	127.07	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
3821888f-208f-4821-a904-09a97f4a43da	aetna_dmo	DMO	D4910	TN	\N	129.75	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
0d0516d5-d050-4dd3-a03a-38bf2d2574cf	aetna_dmo	DMO	D4910	AL	\N	123.06	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
9d67b382-3e00-4e76-b8d1-4eac75d61128	aetna_dmo	DMO	D6010	GA	\N	1786.50	2026-01-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
e93970e4-ac15-4206-a9f8-bfb467d08ea8	aetna_dmo	DMO	D6010	FL	\N	1875.83	2026-01-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
00ebdaf0-3815-4b45-9f59-316822482b4c	aetna_dmo	DMO	D6010	TX	\N	1965.15	2026-01-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
41d16913-8ace-4b5a-bf47-86a24dcba7bf	aetna_dmo	DMO	D6010	NC	\N	1750.77	2026-01-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
ce27cc1f-5e75-461f-ae78-0dee61d91dc2	aetna_dmo	DMO	D6010	SC	\N	1697.17	2026-01-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
82e7a7c2-6bc5-4007-81a9-df37aec8f5eb	aetna_dmo	DMO	D6010	TN	\N	1732.90	2026-01-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
cbfeb126-c3a1-4c66-83e1-8f1f30f6f8c0	aetna_dmo	DMO	D6010	AL	\N	1643.58	2026-01-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
9aa59e03-5af7-42b0-85cc-bcb32a1b9bb1	aetna_dmo	DMO	D6065	GA	\N	1071.00	2026-01-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
ed45d886-55bf-4c96-ba5d-d4f469f424da	aetna_dmo	DMO	D6065	FL	\N	1124.55	2026-01-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
cb852f12-f397-4d7c-9910-f27ba46332c9	aetna_dmo	DMO	D6065	TX	\N	1178.10	2026-01-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
16157004-3815-4d97-a879-304518d724f6	aetna_dmo	DMO	D6065	NC	\N	1049.58	2026-01-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
f5869b7d-8e40-4a4f-8014-719d69cccfe7	aetna_dmo	DMO	D6065	SC	\N	1017.45	2026-01-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
915a4f30-36d7-4842-a3ac-4f500df172d8	aetna_dmo	DMO	D6065	TN	\N	1038.87	2026-01-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
f9e6706c-6f79-437a-bcae-12c92c8b3a9a	aetna_dmo	DMO	D6065	AL	\N	985.32	2026-01-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
aef61367-024c-4944-9acb-4897c961ac38	aetna_dmo	DMO	D7140	GA	\N	170.66	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
ed0eadbb-c83e-466d-877c-9ee55068d367	aetna_dmo	DMO	D7140	FL	\N	179.19	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
c6674a17-abd9-45cb-b19d-e58c89d4ca6c	aetna_dmo	DMO	D7140	TX	\N	187.72	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
f5dc9111-b19a-4666-80a7-e476935a1ee4	aetna_dmo	DMO	D7140	NC	\N	167.24	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
e8c31520-6a79-4420-968e-adbd72e062f5	aetna_dmo	DMO	D7140	SC	\N	162.13	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
10fbc843-b421-47c0-8dce-ea1a27ba0930	aetna_dmo	DMO	D7140	TN	\N	165.54	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
a6121d26-a4c4-4ffb-877c-e797e51f6812	aetna_dmo	DMO	D7140	AL	\N	157.01	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
5c454d7d-628d-4c82-adc9-3eb460609b36	aetna_dmo	DMO	D7210	GA	\N	262.91	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
1dcb48a5-2b25-4520-b69c-aa017bde072a	aetna_dmo	DMO	D7210	FL	\N	276.05	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
e8b83a2e-06b9-43cc-8a78-b02063caefd6	aetna_dmo	DMO	D7210	TX	\N	289.20	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
404a5ae1-e0f0-47c7-9fa6-e97597ac0d79	aetna_dmo	DMO	D7210	NC	\N	257.65	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
b99b36c5-e13a-44c8-aebc-7ebfd0d03f08	aetna_dmo	DMO	D7210	SC	\N	249.76	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
f29d1a4c-30bc-4189-b34c-a6da9083e2b6	aetna_dmo	DMO	D7210	TN	\N	255.02	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
ed3d5457-40e0-4e37-88e2-7a34d5a8efad	aetna_dmo	DMO	D7210	AL	\N	241.88	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
b7c53b9f-151c-460c-91dd-f07ddb933cc9	aetna_dmo	DMO	D7953	GA	\N	382.50	2026-01-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
9748e5b0-10ad-417b-a9e5-f67b51b54f6e	aetna_dmo	DMO	D7953	FL	\N	401.62	2026-01-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
5e37ef33-f29f-4de6-98e7-38c7774461a6	aetna_dmo	DMO	D7953	TX	\N	420.75	2026-01-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
e85e514a-4f87-4c0e-9b4d-665a98dc21a5	aetna_dmo	DMO	D7953	NC	\N	374.85	2026-01-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
b31b46db-212a-41f7-80d2-fb78fbb99082	aetna_dmo	DMO	D7953	SC	\N	363.38	2026-01-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
6ec5706e-419c-4ef7-ad67-6a1ab89d0394	aetna_dmo	DMO	D7953	TN	\N	371.02	2026-01-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
c0fc0fbe-7e46-4bda-89ba-21bdaf624431	aetna_dmo	DMO	D7953	AL	\N	351.90	2026-01-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
dc774dc8-538c-46cc-8daa-7e20dc47911d	aetna_dmo	DMO	D9110	GA	\N	87.63	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
c503bd8b-139a-4a69-9bd0-601df93b09f7	aetna_dmo	DMO	D9110	FL	\N	92.01	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
96f8ff69-280c-4017-886e-4eb546aea4dc	aetna_dmo	DMO	D9110	TX	\N	96.40	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
b07554e8-601e-4fba-b42b-bb82a5892dce	aetna_dmo	DMO	D9110	NC	\N	85.88	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
844a988d-ea75-4905-a51f-74ea389897b7	aetna_dmo	DMO	D9110	SC	\N	83.25	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
44b40daf-0e06-4544-8e8d-ddce037fe4a8	aetna_dmo	DMO	D9110	TN	\N	85.00	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
931ae697-6e7a-465f-bdf3-1ebf6adfcfa0	aetna_dmo	DMO	D9110	AL	\N	80.62	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
1b49c0e6-549e-43b3-8738-2e898c354ccf	aetna_dmo	DMO	D9230	GA	\N	115.31	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
ca355fa4-200d-4c4b-b74e-c578382afc6a	aetna_dmo	DMO	D9230	FL	\N	121.07	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
7269f816-c9dc-4bc1-8968-82c115e86256	aetna_dmo	DMO	D9230	TX	\N	126.84	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
10b2e355-edd0-4dd2-91f8-102268f82318	aetna_dmo	DMO	D9230	NC	\N	113.00	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
0faf3703-b445-4b72-af89-b86513f5fd36	aetna_dmo	DMO	D9230	SC	\N	109.54	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
cc5cdcee-e628-4341-9986-ac8d6af11dea	aetna_dmo	DMO	D9230	TN	\N	111.85	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
abf0942f-8737-493e-8fa9-dcbbe179ec5e	aetna_dmo	DMO	D9230	AL	\N	106.08	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
93390a6f-6d0a-4389-83e0-87ea0f5b3349	humana_dpo	DPPO	D0120	GA	\N	53.55	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
da366204-39a3-4710-8c03-461d0b33ab4d	humana_dpo	DPPO	D0120	FL	\N	56.23	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
52df9f9a-1be9-42c3-b94e-e43234a0eed7	humana_dpo	DPPO	D0120	TX	\N	58.91	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
84700724-45d6-4538-bf1d-5882e265820b	humana_dpo	DPPO	D0120	NC	\N	52.48	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
723f98d2-a69d-4a3b-b216-561834cc52fc	humana_dpo	DPPO	D0120	SC	\N	50.87	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
2c9591ad-930d-4f96-8303-5c0f582a5548	humana_dpo	DPPO	D0120	TN	\N	51.94	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
178ac94f-8f13-493d-a6d4-911adfcf0eb8	humana_dpo	DPPO	D0120	AL	\N	49.27	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
56192811-51ee-4841-8e46-de5f541f7155	humana_dpo	DPPO	D0150	GA	\N	92.50	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
bad55e85-5d6a-444f-82a6-d5ea14ded3d4	humana_dpo	DPPO	D0150	FL	\N	97.13	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
65f69381-dee4-4254-a743-154c66b90a06	humana_dpo	DPPO	D0150	TX	\N	101.75	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
f862ac41-e38c-47f2-8d1b-ab5b4d18b000	humana_dpo	DPPO	D0150	NC	\N	90.65	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
833523e9-67bd-4861-a899-c69dd6378f0a	humana_dpo	DPPO	D0150	SC	\N	87.88	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
f6920798-808a-4387-90e4-affcef4a13e0	humana_dpo	DPPO	D0150	TN	\N	89.73	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
4724e346-f914-409e-bf17-a16885d3b158	humana_dpo	DPPO	D0150	AL	\N	85.10	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
a7c3227d-8dad-4f87-a465-fab620d26e6c	humana_dpo	DPPO	D0210	GA	\N	170.40	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
dee22a97-fad7-40dd-b311-2931b87e0b71	humana_dpo	DPPO	D0210	FL	\N	178.92	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
e6ad5bc7-c426-4c1a-85ca-be49b3b8d1c4	humana_dpo	DPPO	D0210	TX	\N	187.44	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
5d9d396c-9538-473b-9147-cecb1072de22	humana_dpo	DPPO	D0210	NC	\N	166.99	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
e9a93c11-f62f-4335-90b7-46d1c57c89a2	humana_dpo	DPPO	D0210	SC	\N	161.88	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
6246d388-6eeb-4c94-bdb7-83076ccf5a66	humana_dpo	DPPO	D0210	TN	\N	165.29	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
34f7f92e-5c84-4e5c-b877-0c0eca54bbcb	humana_dpo	DPPO	D0210	AL	\N	156.77	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
47cc7f9d-eaab-4adf-accf-d0523aa65442	humana_dpo	DPPO	D0220	GA	\N	34.08	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
70c14231-36b9-4d8b-a560-9c4fc5bd5db3	humana_dpo	DPPO	D0220	FL	\N	35.78	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
eb87890e-7f9e-4793-af58-dd8794f9c18d	humana_dpo	DPPO	D0220	TX	\N	37.48	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
60cb35d0-15d7-4b3e-9a41-c6ff23cd9eaf	humana_dpo	DPPO	D0220	NC	\N	33.39	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
99775e0b-1643-4340-b3b6-9b2ea691e6fd	humana_dpo	DPPO	D0220	SC	\N	32.37	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
e5cf0f74-8541-46c6-8d18-9238cdba7fd4	humana_dpo	DPPO	D0220	TN	\N	33.05	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
c69d1565-a470-4f0f-975d-e15da382c8b6	humana_dpo	DPPO	D0220	AL	\N	31.35	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
f620d8e7-a336-4698-911a-d7fa6bf05397	humana_dpo	DPPO	D0274	GA	\N	73.03	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
2f5f1c39-dfe4-4456-86ee-b2b82605b68a	humana_dpo	DPPO	D0274	FL	\N	76.68	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
297f10b0-82d3-402f-9852-39118a925e8b	humana_dpo	DPPO	D0274	TX	\N	80.33	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
ae722c56-f654-45bf-919e-f0b36249abec	humana_dpo	DPPO	D0274	NC	\N	71.57	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
3090ce6d-a0e8-4120-9b9f-412223eb0e34	humana_dpo	DPPO	D0274	SC	\N	69.38	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
ba29b4ed-b512-4a9c-9a99-cee8d65d9b49	humana_dpo	DPPO	D0274	TN	\N	70.84	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
b7b4868a-fa16-4f6a-bafd-edc54eb6d2fe	humana_dpo	DPPO	D0274	AL	\N	67.18	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
f271877d-9fa9-4cac-a7c5-5139cc0ecec3	humana_dpo	DPPO	D0330	GA	\N	150.93	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
a5f1b876-1f29-40f1-bd42-bd24cc5bf1c2	humana_dpo	DPPO	D0330	FL	\N	158.47	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
ac04447d-399e-4e81-b948-fdf3260e6eac	humana_dpo	DPPO	D0330	TX	\N	166.02	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
4fb6d067-6fa5-4a65-bb3e-2f1f413cb8e0	humana_dpo	DPPO	D0330	NC	\N	147.91	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
793d9a83-7ae3-49f4-b432-f426ad79927f	humana_dpo	DPPO	D0330	SC	\N	143.38	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
0cfcb083-bac0-4b95-95a8-43e0668c82c6	humana_dpo	DPPO	D0330	TN	\N	146.40	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
3248e666-e527-40c3-b982-08a64e4f1341	humana_dpo	DPPO	D0330	AL	\N	138.85	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
88924428-7259-461d-a4e3-fa2e9123cdc2	humana_dpo	DPPO	D1110	GA	\N	107.11	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
9f2250f0-fd4e-4a34-b0ec-b93b01005c58	humana_dpo	DPPO	D1110	FL	\N	112.47	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
384ca49d-1951-466a-b4c0-8efe76f3011f	humana_dpo	DPPO	D1110	TX	\N	117.82	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
38c178c1-c8ed-4524-8cac-f4e6290c9e32	humana_dpo	DPPO	D1110	NC	\N	104.97	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
ed41421a-9ff1-460f-af6d-9463670c8780	humana_dpo	DPPO	D1110	SC	\N	101.76	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
e5ac60d9-9768-4d8c-8e24-292327d5a4bd	humana_dpo	DPPO	D1110	TN	\N	103.90	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
5c084834-fca1-44d0-b311-0632fbc330cb	humana_dpo	DPPO	D1110	AL	\N	98.54	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
5ee85caa-115b-4e3b-8969-52f2a619331f	humana_dpo	DPPO	D1120	GA	\N	82.76	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
b6b6e185-2b5b-4786-bb83-4d607c855903	humana_dpo	DPPO	D1120	FL	\N	86.90	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
35abe94b-3f2d-49e7-a425-ee82b169dbd9	humana_dpo	DPPO	D1120	TX	\N	91.04	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
7eb129aa-d04b-46b0-a9b1-41712b475a14	humana_dpo	DPPO	D1120	NC	\N	81.11	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
6471e35a-7674-4370-87da-f64c2d4d90ee	humana_dpo	DPPO	D1120	SC	\N	78.63	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
6b833670-1d02-445a-805f-674d9104adb1	humana_dpo	DPPO	D1120	TN	\N	80.28	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
41c6cca2-4279-45da-8d15-9be0f1351623	humana_dpo	DPPO	D1120	AL	\N	76.14	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
445ae911-8e9e-472e-8f81-a7314deb3a51	humana_dpo	DPPO	D1351	GA	\N	63.29	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
e7a7282e-6c48-4d46-9add-a0236c32d65e	humana_dpo	DPPO	D1351	FL	\N	66.45	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
877be989-3f9c-4527-bcc7-dd547747092a	humana_dpo	DPPO	D1351	TX	\N	69.62	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
20b2bc4a-5d1d-4a28-abd9-6f5c8a8c7840	humana_dpo	DPPO	D1351	NC	\N	62.02	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
a5fc745a-b12d-4d4a-96c6-a84c42cd3107	humana_dpo	DPPO	D1351	SC	\N	60.12	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
05c0a918-2235-4a6e-9d78-3013cf602fde	humana_dpo	DPPO	D1351	TN	\N	61.39	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
0f354fef-d94f-4f56-a0be-bbe400dfa4d8	humana_dpo	DPPO	D1351	AL	\N	58.23	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
1225d33c-26da-461c-8e12-9f56ad678bfd	humana_dpo	DPPO	D2140	GA	\N	170.40	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
01ae7edd-87e5-47f7-a159-0e9d8f07b1b5	humana_dpo	DPPO	D2140	FL	\N	178.92	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
f15c66ad-6b57-4cf0-8cd4-66e06bd8d10b	humana_dpo	DPPO	D2140	TX	\N	187.44	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
f2505db3-e98a-4c12-a792-d50d64f1fdf7	humana_dpo	DPPO	D2140	NC	\N	166.99	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
57f589a8-ec71-45b6-8d84-ee83bcfff619	humana_dpo	DPPO	D2140	SC	\N	161.88	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
1bdf14c3-7837-43b8-82d9-96574a39f58d	humana_dpo	DPPO	D2140	TN	\N	165.29	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
87893b31-5a19-4bce-9902-3f56122bba39	humana_dpo	DPPO	D2140	AL	\N	156.77	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
319f73b8-dcb4-4f70-abf6-757bc44cc037	humana_dpo	DPPO	D2150	GA	\N	204.49	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
d24b1b0c-d5f5-48c8-b33d-a903bcc5ef81	humana_dpo	DPPO	D2150	FL	\N	214.71	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
74aa0ddd-5cc0-4192-a7df-84b37bb1678a	humana_dpo	DPPO	D2150	TX	\N	224.94	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
3e919e75-5b4a-41cf-a9e2-1829d1cb68e6	humana_dpo	DPPO	D2150	NC	\N	200.40	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
23f9aa81-021b-4b6a-a1fa-78001bc262a1	humana_dpo	DPPO	D2150	SC	\N	194.26	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
0317fc6b-d973-43de-a408-578e495f6829	humana_dpo	DPPO	D2150	TN	\N	198.35	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
8f8fcda0-7034-4727-9622-9ce881e1a055	humana_dpo	DPPO	D2150	AL	\N	188.13	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
9085601e-6097-46eb-8c00-b5233f94e03b	humana_dpo	DPPO	D2160	GA	\N	243.44	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
5cbffb56-b698-4c7e-8943-f049f7936d06	humana_dpo	DPPO	D2160	FL	\N	255.61	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
d5ad6827-5c4c-43dc-99cf-cc1ff51895b7	humana_dpo	DPPO	D2160	TX	\N	267.78	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
787003ed-809f-417b-af16-4d706917de72	humana_dpo	DPPO	D2160	NC	\N	238.57	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
3f8566be-7a3c-4eb0-986d-bb9af983d033	humana_dpo	DPPO	D2160	SC	\N	231.27	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
5e0eae9f-6c5b-4fe1-8e7a-07c65dba3aed	humana_dpo	DPPO	D2160	TN	\N	236.13	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
207d76ab-f4cb-450d-a953-9bdcaddd29c5	humana_dpo	DPPO	D2160	AL	\N	223.96	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
91e3e5fc-c92d-48cc-aafc-5c295022363e	humana_dpo	DPPO	D2161	GA	\N	282.39	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
ab458d1d-82fe-4fb2-a7aa-8878b9b7e060	humana_dpo	DPPO	D2161	FL	\N	296.51	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
ab4b9ad8-21c1-48b0-a80d-d859e4c13795	humana_dpo	DPPO	D2161	TX	\N	310.63	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
a5909502-ea68-4b69-8867-66658fbfca44	humana_dpo	DPPO	D2161	NC	\N	276.74	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
f21d82e1-30b6-4d03-8d20-a3f95052b840	humana_dpo	DPPO	D2161	SC	\N	268.27	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
a1be857f-99b3-4d04-9e09-f848331be0c0	humana_dpo	DPPO	D2161	TN	\N	273.92	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
06f73ce3-45ac-4cf9-9929-6fe1ce6396b4	humana_dpo	DPPO	D2161	AL	\N	259.80	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
ab1f0d50-d186-49da-95be-17e0e5eabcca	humana_dpo	DPPO	D2740	GA	\N	1187.50	2026-01-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
7dbe1948-b937-4295-b372-af1e31c0d9c5	humana_dpo	DPPO	D2740	FL	\N	1246.88	2026-01-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
6f076066-b137-45d5-8163-6b053053a7e0	humana_dpo	DPPO	D2740	TX	\N	1306.25	2026-01-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
0e087582-18ba-42bc-957b-4c3c0da605cc	humana_dpo	DPPO	D2740	NC	\N	1163.75	2026-01-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
5df25f0d-49c2-43f6-b221-f5526fe2da9f	humana_dpo	DPPO	D2740	SC	\N	1128.12	2026-01-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
e199869b-ccf2-43ac-b5e5-842bbfaa1bc2	humana_dpo	DPPO	D2740	TN	\N	1151.88	2026-01-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
73608b82-357b-46f1-b89d-7249c4564110	humana_dpo	DPPO	D2740	AL	\N	1092.50	2026-01-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
1a3a856d-9e26-4c44-b33d-251f276db9c0	humana_dpo	DPPO	D2750	GA	\N	1130.50	2026-01-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
a7942e20-b959-4c73-b722-0839251a10b4	humana_dpo	DPPO	D2750	FL	\N	1187.03	2026-01-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
ab014596-5050-4695-9b82-0faa46f69f40	humana_dpo	DPPO	D2750	TX	\N	1243.55	2026-01-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
a15ee7da-e3e3-48b0-b3c7-ac7b1346a18c	humana_dpo	DPPO	D2750	NC	\N	1107.89	2026-01-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
09c63002-8329-4f8c-abcd-0ca8fc975853	humana_dpo	DPPO	D2750	SC	\N	1073.97	2026-01-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
bb01092e-1aac-459b-9de0-6946dff82fa4	humana_dpo	DPPO	D2750	TN	\N	1096.59	2026-01-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
a1ff66dd-312c-46db-bdf2-b8b2077a9424	humana_dpo	DPPO	D2750	AL	\N	1040.06	2026-01-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
68fdfca3-961f-4ebd-babb-23b78e7da6d0	humana_dpo	DPPO	D3310	GA	\N	852.03	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
518d9eb1-3d2c-44ab-8d47-c09e24b3b5a5	humana_dpo	DPPO	D3310	FL	\N	894.63	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
9759a5af-a40a-405d-8bea-fd7ef6f638c0	humana_dpo	DPPO	D3310	TX	\N	937.23	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
6fb85550-b386-43c0-bd50-bcf9cf32a331	humana_dpo	DPPO	D3310	NC	\N	834.99	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
c39afc1d-cb59-4bab-9bf5-cbf7bf3a8162	humana_dpo	DPPO	D3310	SC	\N	809.43	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
9502811e-33f5-4aef-8396-4fe6e1beab56	humana_dpo	DPPO	D3310	TN	\N	826.47	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
4b5891c4-ba99-425f-80c9-30458ff9b389	humana_dpo	DPPO	D3310	AL	\N	783.86	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
1943945e-7df8-4d30-b4b4-bcedcafd8c6d	humana_dpo	DPPO	D3320	GA	\N	949.40	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
63b288cf-2b76-471c-a00a-a58d4e3564a7	humana_dpo	DPPO	D3320	FL	\N	996.87	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
4798dc18-7aa8-4fd5-9fbf-8e5fff0b18c7	humana_dpo	DPPO	D3320	TX	\N	1044.34	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
7865d8f9-b0fe-484d-bbe1-4c8b4968ee3d	humana_dpo	DPPO	D3320	NC	\N	930.41	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
62adae16-a98e-4873-88dd-feb46ce4e212	humana_dpo	DPPO	D3320	SC	\N	901.93	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
4a9d233f-4ab4-469c-912e-e2f5ed5d5a76	humana_dpo	DPPO	D3320	TN	\N	920.92	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
6259862c-0fd1-4570-afc1-fc7b9b37f453	humana_dpo	DPPO	D3320	AL	\N	873.45	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
7c98785b-daff-4045-a294-bf62901a7466	humana_dpo	DPPO	D3330	GA	\N	997.50	2026-01-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
1ccc1ef3-ba94-4494-bf48-64e630a9a314	humana_dpo	DPPO	D3330	FL	\N	1047.38	2026-01-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
843b8070-eaa5-447a-a151-35c8295232bf	humana_dpo	DPPO	D3330	TX	\N	1097.25	2026-01-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
61a62025-ef18-4bc0-9a62-df8ea04fe0fc	humana_dpo	DPPO	D3330	NC	\N	977.55	2026-01-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
6223b7ee-e556-4763-b438-029a33332581	humana_dpo	DPPO	D3330	SC	\N	947.62	2026-01-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
e09a3348-f0e1-4a17-ab4f-8eb99d471633	humana_dpo	DPPO	D3330	TN	\N	967.57	2026-01-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
a0aaea0a-0797-416a-8884-50870ba20139	humana_dpo	DPPO	D3330	AL	\N	917.70	2026-01-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
4895b216-8547-42ca-974a-4b942c6e25a2	humana_dpo	DPPO	D4260	GA	\N	954.27	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
9ce8e17b-02e6-4606-a501-d108b64d1163	humana_dpo	DPPO	D4260	FL	\N	1001.99	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
973ad08b-93f3-49eb-a62d-b8afba2e24bb	humana_dpo	DPPO	D4260	TX	\N	1049.70	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
b242bdb5-c862-4b0d-a555-250f97380509	humana_dpo	DPPO	D4260	NC	\N	935.19	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
e09203bd-8bb9-4f8d-a94d-6ad1088e98c6	humana_dpo	DPPO	D4260	SC	\N	906.56	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
4d7e547d-d826-444c-bf65-841f7f9386b6	humana_dpo	DPPO	D4260	TN	\N	925.65	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
9da8e9fb-017b-420b-9c04-27362e46abbd	humana_dpo	DPPO	D4260	AL	\N	877.93	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
df0249c1-130c-4d1b-ad79-089e69239a26	humana_dpo	DPPO	D4341	GA	\N	258.04	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
1bae9942-d125-4d69-8717-57ca81e960aa	humana_dpo	DPPO	D4341	FL	\N	270.94	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
e32b4078-e34d-41cd-a3c0-780b105a57c2	humana_dpo	DPPO	D4341	TX	\N	283.84	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
b8056f02-d3f4-458d-ab63-a28e2e36664c	humana_dpo	DPPO	D4341	NC	\N	252.88	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
81aef28e-bfdf-4fd6-8bba-c943254d6158	humana_dpo	DPPO	D4341	SC	\N	245.14	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
a153a4f0-a29b-4baf-b1b2-8841bcd21595	humana_dpo	DPPO	D4341	TN	\N	250.30	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
0f76e4d0-bb7c-474f-a1f7-48cc58c75624	humana_dpo	DPPO	D4341	AL	\N	237.40	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
739891d4-11ba-46dc-b7d2-398e82cfcc19	humana_dpo	DPPO	D4910	GA	\N	141.19	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
7f6c8ebe-7d96-498d-b7d9-ae329bf049e8	humana_dpo	DPPO	D4910	FL	\N	148.25	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
77882e4d-da95-4faf-a49f-b457ab5d2de5	humana_dpo	DPPO	D4910	TX	\N	155.31	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
ec2ad433-9f01-4cef-859b-8dd7d4bd6276	humana_dpo	DPPO	D4910	NC	\N	138.37	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
93fc9868-8414-4005-8123-f5122d0dc620	humana_dpo	DPPO	D4910	SC	\N	134.13	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
1e61b39e-4ee5-477d-83e9-22e0d670838d	humana_dpo	DPPO	D4910	TN	\N	136.95	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
7fcfd0c0-093a-43a6-ae9d-537b3e665db6	humana_dpo	DPPO	D4910	AL	\N	129.89	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
0b34c954-1558-46b3-a375-b61d36c2f5c5	humana_dpo	DPPO	D6010	GA	\N	1885.75	2026-01-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
f369ac7f-5e04-43fe-a77d-a879be1c4cd8	humana_dpo	DPPO	D6010	FL	\N	1980.04	2026-01-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
6a8d783d-1341-494c-963d-948f5a08aa17	humana_dpo	DPPO	D6010	TX	\N	2074.33	2026-01-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
873ed393-6307-4c11-83ca-17610498c101	humana_dpo	DPPO	D6010	NC	\N	1848.03	2026-01-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
af934a3a-9526-4213-8d98-123e11394b66	humana_dpo	DPPO	D6010	SC	\N	1791.46	2026-01-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
8f08dbdc-f395-4172-b005-a53f92eeeda6	humana_dpo	DPPO	D6010	TN	\N	1829.18	2026-01-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
0eabfea0-ad9d-4b67-82a8-0c622337d716	humana_dpo	DPPO	D6010	AL	\N	1734.89	2026-01-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
c2e14957-38af-49ba-bcc3-dc7ca8b8c009	humana_dpo	DPPO	D6065	GA	\N	1130.50	2026-01-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
106cbed0-925a-459c-bd17-9452cd82c3b0	humana_dpo	DPPO	D6065	FL	\N	1187.03	2026-01-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
e6f3772c-740e-407e-9d35-f27286b18b6d	humana_dpo	DPPO	D6065	TX	\N	1243.55	2026-01-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
dd83300f-7ddf-4f02-b4ec-3df4afc1d498	humana_dpo	DPPO	D6065	NC	\N	1107.89	2026-01-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
dec6a58f-6504-40fd-8cfe-a35c865a5b99	humana_dpo	DPPO	D6065	SC	\N	1073.97	2026-01-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
64f47f5b-323b-4d77-9d5d-3d814be429c6	humana_dpo	DPPO	D6065	TN	\N	1096.59	2026-01-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
4d69e68c-4b27-41e0-b49e-7c1b359edbaf	humana_dpo	DPPO	D6065	AL	\N	1040.06	2026-01-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
9e7dc593-12a1-497e-b500-74ef373b8abb	humana_dpo	DPPO	D7140	GA	\N	180.14	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
2fc0bb4f-ef66-4d7f-b138-2337c692d4fb	humana_dpo	DPPO	D7140	FL	\N	189.15	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
de18a503-0dc2-4ae0-825f-702f8fb1cfb9	humana_dpo	DPPO	D7140	TX	\N	198.15	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
ef24938f-1a76-4f4f-b264-5723af21e837	humana_dpo	DPPO	D7140	NC	\N	176.54	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
a563e240-7d7c-4398-ada9-345018137558	humana_dpo	DPPO	D7140	SC	\N	171.13	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
6384b6ee-bf0a-4664-99e0-488b36c2693c	humana_dpo	DPPO	D7140	TN	\N	174.73	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
b712fd82-f93d-4c55-b4c0-e7e44928c825	humana_dpo	DPPO	D7140	AL	\N	165.73	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
4c43a6a4-47e4-450f-8092-c760720b6bc7	humana_dpo	DPPO	D7210	GA	\N	277.51	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
c1912ea1-88a1-41e8-94b0-7ec44402cdfc	humana_dpo	DPPO	D7210	FL	\N	291.39	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
6976f93c-d0a3-4731-908a-3caf796b06c1	humana_dpo	DPPO	D7210	TX	\N	305.27	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
6d48f1c6-7c05-453f-94ce-5a0e46cdbf8a	humana_dpo	DPPO	D7210	NC	\N	271.96	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
cb3dee06-e7a6-471c-ade3-b39707aa9f02	humana_dpo	DPPO	D7210	SC	\N	263.64	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
1b2b517e-c936-4f25-839a-daddb00baa7d	humana_dpo	DPPO	D7210	TN	\N	269.19	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
4a261879-7f99-43af-9d92-c678daad5656	humana_dpo	DPPO	D7210	AL	\N	255.31	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
0d024625-3594-4d87-8bab-394b804ff971	humana_dpo	DPPO	D7953	GA	\N	403.75	2026-01-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
f098674e-0e55-4927-8564-9218817b4267	humana_dpo	DPPO	D7953	FL	\N	423.94	2026-01-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
820d699d-8c5f-4a51-84a3-95dbd1ae8f42	humana_dpo	DPPO	D7953	TX	\N	444.13	2026-01-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
f3f1fa73-7e03-4c74-b59b-a0832d7e156b	humana_dpo	DPPO	D7953	NC	\N	395.68	2026-01-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
7ed5c4fb-fded-4b78-be6c-c58cbc3db983	humana_dpo	DPPO	D7953	SC	\N	383.56	2026-01-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
5995f28e-a1c0-4123-93fd-22e7e38b4634	humana_dpo	DPPO	D7953	TN	\N	391.64	2026-01-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
6edd0e12-3021-481b-a279-a33f83a4bef3	humana_dpo	DPPO	D7953	AL	\N	371.45	2026-01-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
64efc6b7-f0cd-464a-b3e1-0c6eb3e4f573	humana_dpo	DPPO	D9110	GA	\N	92.50	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
afe85e5a-b5f9-4f06-b479-85972d3ae182	humana_dpo	DPPO	D9110	FL	\N	97.13	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
014a41fa-9718-45f1-9da1-15922ddac253	humana_dpo	DPPO	D9110	TX	\N	101.75	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
cc0e81b6-6b73-413e-aea1-75204b10de40	humana_dpo	DPPO	D9110	NC	\N	90.65	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
e2f5fb7b-61f8-4267-a140-1b552d3f1a6d	humana_dpo	DPPO	D9110	SC	\N	87.88	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
54bb2907-b824-4a3c-a71a-4fa02456fab4	humana_dpo	DPPO	D9110	TN	\N	89.73	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
d8a0dfa2-2b05-4d83-bf5f-21cf16865fa0	humana_dpo	DPPO	D9110	AL	\N	85.10	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
1e3a1388-c119-4a2b-a6ff-7aa7103b7e9a	humana_dpo	DPPO	D9230	GA	\N	121.71	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
04e31002-cb22-4f2a-a91a-3afef170b450	humana_dpo	DPPO	D9230	FL	\N	127.80	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
6e547b6c-722e-4c57-8be1-e5161c5b4c97	humana_dpo	DPPO	D9230	TX	\N	133.89	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
8731e200-ee82-46ec-884a-c4382ee7f93c	humana_dpo	DPPO	D9230	NC	\N	119.28	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
c1ed119e-2f59-4c2c-aabe-c33fc1dcaf7e	humana_dpo	DPPO	D9230	SC	\N	115.63	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
32500a49-df9b-4d4e-97f9-d4e0452a46b6	humana_dpo	DPPO	D9230	TN	\N	118.06	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
1c774ef7-3830-458c-8994-89bb80a2aedc	humana_dpo	DPPO	D9230	AL	\N	111.98	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
f95cf17e-891f-421f-8877-96c4efe7f4ad	guardian_dpo	DPPO	D0120	GA	\N	56.37	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
e73fe70f-45dd-4673-9251-96ba640d601d	guardian_dpo	DPPO	D0120	FL	\N	59.19	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
4ec35ecf-2883-49bf-b7cf-e7f62d520361	guardian_dpo	DPPO	D0120	TX	\N	62.01	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
62eeda9b-f451-4e58-ab1d-d885c4c4c711	guardian_dpo	DPPO	D0120	NC	\N	55.24	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
d9548250-2d2b-4f98-bfb1-cf01160e71f0	guardian_dpo	DPPO	D0120	SC	\N	53.55	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
7a3175a0-6905-4bdb-8c29-e9f7fbef70d3	guardian_dpo	DPPO	D0120	TN	\N	54.68	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
2f9764f7-ea20-460b-afbc-1d2ea157a7b2	guardian_dpo	DPPO	D0120	AL	\N	51.86	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
53c9c802-5c19-4fd3-985c-1b8cff1a888e	guardian_dpo	DPPO	D0150	GA	\N	97.37	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
e56fcbf8-b9fe-4f04-9c9e-e354149403f5	guardian_dpo	DPPO	D0150	FL	\N	102.24	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
f72442ac-42e0-44d5-a1d8-7acbb19ecf39	guardian_dpo	DPPO	D0150	TX	\N	107.11	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
147a69c8-c2df-4f67-8017-b1079d2ed17b	guardian_dpo	DPPO	D0150	NC	\N	95.42	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
8f8c5797-ca76-431d-9343-7595ea5b5834	guardian_dpo	DPPO	D0150	SC	\N	92.50	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
15853454-ba87-404e-b122-87efb5e76fa5	guardian_dpo	DPPO	D0150	TN	\N	94.45	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
4db5b617-f08b-4002-9b55-b971d2ebebe3	guardian_dpo	DPPO	D0150	AL	\N	89.58	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
164613b4-36d2-44ff-9ebb-370cc4c6b2ee	guardian_dpo	DPPO	D0210	GA	\N	179.37	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
f815629e-09f1-491c-99d1-1da3ce6d3e8c	guardian_dpo	DPPO	D0210	FL	\N	188.34	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
451746a1-5da5-4f3c-a5c0-2265f5b2a930	guardian_dpo	DPPO	D0210	TX	\N	197.31	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
7f991274-81e0-4b39-9744-60c861c065f5	guardian_dpo	DPPO	D0210	NC	\N	175.78	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
1e1a9a73-8ab1-4a82-9c8b-0196dc1d6ad2	guardian_dpo	DPPO	D0210	SC	\N	170.40	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
5db23cfa-75b5-4867-85ea-f9931bbc1d38	guardian_dpo	DPPO	D0210	TN	\N	173.99	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
5590c4f4-28d6-40dd-ba25-5dc60aafd0ce	guardian_dpo	DPPO	D0210	AL	\N	165.02	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
a5cd468b-5b7b-4e4e-ab69-af857e72dbff	guardian_dpo	DPPO	D0220	GA	\N	35.87	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
5773448c-925e-4854-b854-9c49275d738c	guardian_dpo	DPPO	D0220	FL	\N	37.66	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
6883ea09-72bd-430f-8eb8-f8afe2a1422b	guardian_dpo	DPPO	D0220	TX	\N	39.46	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
6f646137-bce6-4cf2-bb4f-085e2649d428	guardian_dpo	DPPO	D0220	NC	\N	35.15	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
41d3bfa2-ad1f-4919-af23-6bf824bdc499	guardian_dpo	DPPO	D0220	SC	\N	34.08	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
69646f0d-e783-47fc-973c-4a3a4203cd15	guardian_dpo	DPPO	D0220	TN	\N	34.79	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
df9998b2-d780-4d8c-87ce-2d04d5f4cc76	guardian_dpo	DPPO	D0220	AL	\N	33.00	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
ddbf1033-bad3-417e-a0cd-373eb356546d	guardian_dpo	DPPO	D0274	GA	\N	76.87	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
e41c51ef-6474-4b4f-88e4-3347fba6b776	guardian_dpo	DPPO	D0274	FL	\N	80.71	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
71631629-6db8-4980-b345-d2d87b6cbdb4	guardian_dpo	DPPO	D0274	TX	\N	84.56	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
0802c6d7-67db-48a2-98ca-9a9f3d4055e2	guardian_dpo	DPPO	D0274	NC	\N	75.33	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
b4cb9a3c-4808-4853-81da-20d4a2b8e363	guardian_dpo	DPPO	D0274	SC	\N	73.03	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
d0c38f82-ae9c-4770-ab2d-db047b586864	guardian_dpo	DPPO	D0274	TN	\N	74.56	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
6cbdc579-39c3-443e-9135-57e5c74dd1de	guardian_dpo	DPPO	D0274	AL	\N	70.72	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
24d461f4-d850-4f65-b7a8-254b977d5b35	guardian_dpo	DPPO	D0330	GA	\N	158.87	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
2bd267e5-737f-4826-9a5d-6d4f0857b146	guardian_dpo	DPPO	D0330	FL	\N	166.81	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
424aa17d-744b-45c3-a47b-becfd6dda1ce	guardian_dpo	DPPO	D0330	TX	\N	174.76	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
ff1d284e-92c6-4a8b-80ef-91425a0a952b	guardian_dpo	DPPO	D0330	NC	\N	155.69	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
bfd14271-1636-4649-b4a8-81f1b56adc93	guardian_dpo	DPPO	D0330	SC	\N	150.93	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
845e8d59-c102-42c6-9dba-cec09cc6f9ce	guardian_dpo	DPPO	D0330	TN	\N	154.10	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
a75f54d5-f3d3-4a2b-b1fd-5efe616faa7c	guardian_dpo	DPPO	D0330	AL	\N	146.16	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
9c0f3734-fc86-4c70-b624-79e2dfabfc72	guardian_dpo	DPPO	D1110	GA	\N	112.75	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
3e66e17d-7834-4013-89d9-6e2db155cd20	guardian_dpo	DPPO	D1110	FL	\N	118.39	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
632d6741-f446-43a8-a348-69055b12f27c	guardian_dpo	DPPO	D1110	TX	\N	124.03	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
21d33939-5ab8-4ed2-8ae0-a52eb66395b7	guardian_dpo	DPPO	D1110	NC	\N	110.50	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
2694359f-dee6-4dad-a339-a49b3637abf7	guardian_dpo	DPPO	D1110	SC	\N	107.11	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
b7aeaca8-ec81-4161-a37a-8f2f44d57630	guardian_dpo	DPPO	D1110	TN	\N	109.37	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
d0a02e6b-22dd-4297-b878-338d7b118d6f	guardian_dpo	DPPO	D1110	AL	\N	103.73	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
621a3fa1-c566-4845-954b-298929f9c230	guardian_dpo	DPPO	D1120	GA	\N	87.12	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
ed571159-9640-4601-87f5-9476c1622662	guardian_dpo	DPPO	D1120	FL	\N	91.48	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
c95c7f40-98d6-443a-a3b6-19354f094cc7	guardian_dpo	DPPO	D1120	TX	\N	95.83	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
ecafade0-15b4-4d63-a805-042ece53701a	guardian_dpo	DPPO	D1120	NC	\N	85.38	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
44c685a7-7254-405b-b68f-ea033d4bb48f	guardian_dpo	DPPO	D1120	SC	\N	82.76	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
5a00d049-24ee-4066-912e-41f4c6254e39	guardian_dpo	DPPO	D1120	TN	\N	84.51	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
88d1cef9-84e2-465e-81b1-e275ac469343	guardian_dpo	DPPO	D1120	AL	\N	80.15	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
9a5d8b4a-0932-41c1-b76d-838caefd0d12	guardian_dpo	DPPO	D1351	GA	\N	66.62	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
e821aac4-a75f-4332-a337-962d8b93670e	guardian_dpo	DPPO	D1351	FL	\N	69.95	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
bed16b3c-3d80-4b99-bbf2-3cf2042e0b43	guardian_dpo	DPPO	D1351	TX	\N	73.28	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
edee1b23-74de-426a-b30f-a08bbd6db018	guardian_dpo	DPPO	D1351	NC	\N	65.29	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
cf0fa361-3ff0-47c0-9678-34d069f2ca3e	guardian_dpo	DPPO	D1351	SC	\N	63.29	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
9c424a0b-45dc-4605-8c77-58bed1a2ca7d	guardian_dpo	DPPO	D1351	TN	\N	64.62	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
4826267c-4330-49a4-9c3a-4ec307a6fa6c	guardian_dpo	DPPO	D1351	AL	\N	61.29	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
0546bcb1-9a72-4695-842a-b94b5c9d002b	guardian_dpo	DPPO	D2140	GA	\N	179.37	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
74f36383-d800-4f14-9edd-443e29409a19	guardian_dpo	DPPO	D2140	FL	\N	188.34	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
e5372660-0d1a-4b08-b357-64399b67c6f8	guardian_dpo	DPPO	D2140	TX	\N	197.31	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
6e3f9b72-6d39-4eff-a793-f0343d361016	guardian_dpo	DPPO	D2140	NC	\N	175.78	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
814dbd81-fe9d-4645-9df0-71e6f5cfc9c8	guardian_dpo	DPPO	D2140	SC	\N	170.40	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
9d0ea4ee-671b-429f-ad7a-48b6b64309fc	guardian_dpo	DPPO	D2140	TN	\N	173.99	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
579d055a-49e3-4c60-9754-06e56ee3728f	guardian_dpo	DPPO	D2140	AL	\N	165.02	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
0976969c-46d8-41e3-a63f-9240785f8ec9	guardian_dpo	DPPO	D2150	GA	\N	215.25	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
a0ea9d63-315b-480c-afdf-d0c1b49e1b1d	guardian_dpo	DPPO	D2150	FL	\N	226.01	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
9e549800-6c72-4a06-8ab6-b665177561be	guardian_dpo	DPPO	D2150	TX	\N	236.78	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
b646183e-a803-4e94-8652-2f10de47100b	guardian_dpo	DPPO	D2150	NC	\N	210.94	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
14f8357e-26a6-4742-a2c4-896b3f88c408	guardian_dpo	DPPO	D2150	SC	\N	204.49	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
9c3cc486-3844-4f43-bdb0-6394d100318f	guardian_dpo	DPPO	D2150	TN	\N	208.79	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
1aec7ddf-c304-4ed0-8d68-f5a29fc845c9	guardian_dpo	DPPO	D2150	AL	\N	198.03	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
732b4010-fe14-4b69-ab07-56f7b788c548	guardian_dpo	DPPO	D2160	GA	\N	256.25	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
48c23fb0-f17a-42ea-89a4-ed55b0b35d64	guardian_dpo	DPPO	D2160	FL	\N	269.06	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
3903ffb8-4659-4a3e-9522-f2c32a6b46c1	guardian_dpo	DPPO	D2160	TX	\N	281.88	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
90d43900-d7c4-47aa-b220-f3d698222e41	guardian_dpo	DPPO	D2160	NC	\N	251.12	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
d77c94dc-e01e-4218-a370-4a504b15d47c	guardian_dpo	DPPO	D2160	SC	\N	243.44	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
d5a4528d-f457-44f7-ad9f-bbace4a3707a	guardian_dpo	DPPO	D2160	TN	\N	248.56	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
669d080c-7fda-4887-b961-e8417638bc0b	guardian_dpo	DPPO	D2160	AL	\N	235.75	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
ccf50b3d-508f-4007-9c93-aac6a7388da7	guardian_dpo	DPPO	D2161	GA	\N	297.25	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
83712167-6d75-437e-82c2-575a2decc304	guardian_dpo	DPPO	D2161	FL	\N	312.11	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
96e539a4-28f2-4964-9b90-5bdd51246bcd	guardian_dpo	DPPO	D2161	TX	\N	326.98	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
91637c25-4aed-4134-b9bb-5690e4ab4364	guardian_dpo	DPPO	D2161	NC	\N	291.31	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
99e49ff5-303a-4eae-bf7b-689508fcb9c0	guardian_dpo	DPPO	D2161	SC	\N	282.39	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
e1317d9a-0e3f-4505-acc5-cbb17425c0a3	guardian_dpo	DPPO	D2161	TN	\N	288.33	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
30d64308-c248-40a1-a39c-6c753ea8fe21	guardian_dpo	DPPO	D2161	AL	\N	273.47	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
be989f42-76d3-44f2-acd5-2d186f0cbc51	guardian_dpo	DPPO	D2740	GA	\N	1250.00	2026-01-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
4e28bc94-79fa-4b12-bb2a-ef483e69d8c8	guardian_dpo	DPPO	D2740	FL	\N	1312.50	2026-01-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
2d417fae-3c5b-4c33-9668-c295150d61b9	guardian_dpo	DPPO	D2740	TX	\N	1375.00	2026-01-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
5f98e6c3-c80a-44dc-8363-b5c1a4ad083d	guardian_dpo	DPPO	D2740	NC	\N	1225.00	2026-01-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
6778e8ff-ca60-4216-965b-8d989e4fd22e	guardian_dpo	DPPO	D2740	SC	\N	1187.50	2026-01-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
fa24547a-6208-425e-abb9-5ed84b5116a1	guardian_dpo	DPPO	D2740	TN	\N	1212.50	2026-01-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
3731de34-af29-49cb-ab5a-bd7963736b7b	guardian_dpo	DPPO	D2740	AL	\N	1150.00	2026-01-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
eda6bb4c-41d8-4c9b-a881-22c345c76866	guardian_dpo	DPPO	D2750	GA	\N	1190.00	2026-01-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
d094d3f3-da62-4812-8b23-a2ef0be825db	guardian_dpo	DPPO	D2750	FL	\N	1249.50	2026-01-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
b441b973-225f-4c8e-92bc-40eee931c5a1	guardian_dpo	DPPO	D2750	TX	\N	1309.00	2026-01-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
cf921ca8-8f79-4538-a107-28739d9f578e	guardian_dpo	DPPO	D2750	NC	\N	1166.20	2026-01-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
4b3b13ca-4752-479c-a1e7-c4406ce11d74	guardian_dpo	DPPO	D2750	SC	\N	1130.50	2026-01-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
104eab1d-1915-4aca-b980-d1db27d850dd	guardian_dpo	DPPO	D2750	TN	\N	1154.30	2026-01-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
1678680b-6348-4b84-bd2a-51542ffa8464	guardian_dpo	DPPO	D2750	AL	\N	1094.80	2026-01-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
22534691-771e-4727-be12-1714b9ea05f9	guardian_dpo	DPPO	D3310	GA	\N	896.87	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
7f228ebd-12a3-4c28-8b75-563ed156246f	guardian_dpo	DPPO	D3310	FL	\N	941.71	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
b594a838-955b-48c0-874f-73b763e871a6	guardian_dpo	DPPO	D3310	TX	\N	986.56	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
c40eef86-c72c-476d-964b-cb2738c20e75	guardian_dpo	DPPO	D3310	NC	\N	878.93	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
b43d99fd-fc05-49cd-84f9-f19b6132e41e	guardian_dpo	DPPO	D3310	SC	\N	852.03	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
839000e7-5582-4333-91e2-87f0b6a0ce39	guardian_dpo	DPPO	D3310	TN	\N	869.96	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
f79719d2-e58e-4baa-8ef3-e4b5c6485ba8	guardian_dpo	DPPO	D3310	AL	\N	825.12	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
5a768f74-a82e-4980-be44-6aa5fd087ede	guardian_dpo	DPPO	D3320	GA	\N	999.37	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
9d0ab1f7-f187-453b-88ab-db0f483049da	guardian_dpo	DPPO	D3320	FL	\N	1049.34	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
665ae70c-c031-4c9d-aee9-836a91b75350	guardian_dpo	DPPO	D3320	TX	\N	1099.31	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
8b620542-0c30-4dd2-83b8-2a56b2c5ac02	guardian_dpo	DPPO	D3320	NC	\N	979.38	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
3c211112-af15-49b8-91d6-321dd1e28716	guardian_dpo	DPPO	D3320	SC	\N	949.40	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
0c3d92a4-413c-4fbc-9ecd-43655576d80f	guardian_dpo	DPPO	D3320	TN	\N	969.39	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
b5372f6a-6bd5-46b8-a513-b4caeada2557	guardian_dpo	DPPO	D3320	AL	\N	919.42	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
5fe861f9-610e-49af-b9ce-c3fb8d567eaa	guardian_dpo	DPPO	D3330	GA	\N	1050.00	2026-01-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
c584670c-460c-4bff-a779-6f52b692e85b	guardian_dpo	DPPO	D3330	FL	\N	1102.50	2026-01-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
499b22b0-a7e9-45a4-8138-768a038d787b	guardian_dpo	DPPO	D3330	TX	\N	1155.00	2026-01-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
aa352b8b-ee83-41da-b07e-c624e254a4bf	guardian_dpo	DPPO	D3330	NC	\N	1029.00	2026-01-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
4f9d2afc-569f-49c3-afcb-084a0464d341	guardian_dpo	DPPO	D3330	SC	\N	997.50	2026-01-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
3e7808b6-867e-4d80-a7d5-2003a51f73d2	guardian_dpo	DPPO	D3330	TN	\N	1018.50	2026-01-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
95538ed9-1fd9-4f81-9d83-62e6410cb99a	guardian_dpo	DPPO	D3330	AL	\N	966.00	2026-01-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
19874c43-3747-467c-bcad-3b17f2707bd5	guardian_dpo	DPPO	D4260	GA	\N	1004.50	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
ed8a36b1-22af-4b0b-9f85-235b0376d78d	guardian_dpo	DPPO	D4260	FL	\N	1054.73	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
3dc9ebb5-1ba5-4509-af4e-507df5798a3e	guardian_dpo	DPPO	D4260	TX	\N	1104.95	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
4f2116f0-23ec-4622-b836-11a8209874d6	guardian_dpo	DPPO	D4260	NC	\N	984.41	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
6aaab869-cafc-4fb6-8943-1df55aab2244	guardian_dpo	DPPO	D4260	SC	\N	954.27	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
eb3f3d96-e336-4e3c-9aa0-8b5b5dc4c0b7	guardian_dpo	DPPO	D4260	TN	\N	974.37	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
cffa4c3b-1597-4f23-baab-a55a97cfd91d	guardian_dpo	DPPO	D4260	AL	\N	924.14	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
98086f91-8b7d-4cd9-b17e-bd849b155431	guardian_dpo	DPPO	D4341	GA	\N	271.62	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
c87bcf05-d7e4-4691-a48b-70bd625d6d20	guardian_dpo	DPPO	D4341	FL	\N	285.20	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
de75b64c-da3e-42d6-9f16-30810a4f083b	guardian_dpo	DPPO	D4341	TX	\N	298.78	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
68c8c511-d822-41be-8bef-90c5ba5dc7c2	guardian_dpo	DPPO	D4341	NC	\N	266.19	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
7ec9c446-c8a9-418f-8b3a-aa3d6e248e1d	guardian_dpo	DPPO	D4341	SC	\N	258.04	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
2efa7c28-b82d-4ee5-b8ae-9b0257c4d250	guardian_dpo	DPPO	D4341	TN	\N	263.47	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
5914e3f7-574a-4c99-98c9-ea99f84ebf22	guardian_dpo	DPPO	D4341	AL	\N	249.89	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
86c5511e-ffb4-4f97-9a90-2f646b269fa7	guardian_dpo	DPPO	D4910	GA	\N	148.62	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
23b818bb-39ea-4461-9120-aac606b063c7	guardian_dpo	DPPO	D4910	FL	\N	156.05	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
1ba0c4d6-6292-4dfb-80f9-06df5271b5e5	guardian_dpo	DPPO	D4910	TX	\N	163.48	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
2a185105-5cc8-4f09-88ee-263661777dd2	guardian_dpo	DPPO	D4910	NC	\N	145.65	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
85bbd636-eae6-40ad-90dd-f3a074ffc624	guardian_dpo	DPPO	D4910	SC	\N	141.19	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
12658282-6738-43a7-94eb-ab2413606bb1	guardian_dpo	DPPO	D4910	TN	\N	144.16	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
0a96b4e2-019c-4e06-ba76-d991920419bf	guardian_dpo	DPPO	D4910	AL	\N	136.73	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
bafc557e-0f10-4121-8a73-bb9ea302b6e9	guardian_dpo	DPPO	D6010	GA	\N	1985.00	2026-01-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
43152b5c-2cb5-4c12-a310-9ee0b30e8966	guardian_dpo	DPPO	D6010	FL	\N	2084.25	2026-01-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
0d66e5c1-22a4-46e0-9b0f-a357b8f5f44c	guardian_dpo	DPPO	D6010	TX	\N	2183.50	2026-01-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
6d0510ea-2a1c-4e05-aaad-3e080593cccc	guardian_dpo	DPPO	D6010	NC	\N	1945.30	2026-01-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
d653d4d9-e38f-4717-a72d-6359b61d0fa2	guardian_dpo	DPPO	D6010	SC	\N	1885.75	2026-01-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
aa7c3208-fff4-4cf7-bde7-a91dd7c1972b	guardian_dpo	DPPO	D6010	TN	\N	1925.45	2026-01-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
6b8fdb11-915a-4843-b92f-6801aab5ff59	guardian_dpo	DPPO	D6010	AL	\N	1826.20	2026-01-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
14981682-6a75-4513-af6e-c704e564fc71	guardian_dpo	DPPO	D6065	GA	\N	1190.00	2026-01-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
f1d08064-2e41-403c-a990-77e05fc11afa	guardian_dpo	DPPO	D6065	FL	\N	1249.50	2026-01-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
de95c569-1259-4930-b644-3e978f7f78de	guardian_dpo	DPPO	D6065	TX	\N	1309.00	2026-01-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
512308c2-4aa2-485b-85fe-f3d09eb161fe	guardian_dpo	DPPO	D6065	NC	\N	1166.20	2026-01-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
2acc40a2-e219-424e-a1d6-83ad5b80f566	guardian_dpo	DPPO	D6065	SC	\N	1130.50	2026-01-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
e7596ed8-9a5d-45cd-ab93-de5ea9153970	guardian_dpo	DPPO	D6065	TN	\N	1154.30	2026-01-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
815835db-326c-4ac5-a4bb-cb10ff2cf669	guardian_dpo	DPPO	D6065	AL	\N	1094.80	2026-01-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
2bd812ac-ddc6-4520-bb60-e5d54f9d1390	guardian_dpo	DPPO	D7140	GA	\N	189.62	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
8cb41403-2df5-4c13-a1e9-c4e712232ce2	guardian_dpo	DPPO	D7140	FL	\N	199.10	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
ed068993-4912-42f3-a64a-31c8d3c98472	guardian_dpo	DPPO	D7140	TX	\N	208.58	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
87a0acce-155b-4e6f-8c14-4b955fd27ebb	guardian_dpo	DPPO	D7140	NC	\N	185.83	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
2d17053b-b99d-4c08-a9a4-44dbe0b65104	guardian_dpo	DPPO	D7140	SC	\N	180.14	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
18422228-ed34-4e18-8806-3ec78f8c5535	guardian_dpo	DPPO	D7140	TN	\N	183.93	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
822bf184-0a3d-4f17-8a40-3a6780636ca2	guardian_dpo	DPPO	D7140	AL	\N	174.45	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
ca2a3eeb-3411-41b5-824c-4b1f8362abca	guardian_dpo	DPPO	D7210	GA	\N	292.12	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
e98a4b6b-99b0-4198-85f6-0b967cee0d31	guardian_dpo	DPPO	D7210	FL	\N	306.73	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
b186ce1d-2280-4220-a31b-ce10687462d9	guardian_dpo	DPPO	D7210	TX	\N	321.33	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
fa3f6156-d768-498f-97a5-0c1644f74ae2	guardian_dpo	DPPO	D7210	NC	\N	286.28	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
3e6c0bb0-ad3f-4fe9-b15f-282d66dd5482	guardian_dpo	DPPO	D7210	SC	\N	277.51	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
30d4d249-b261-4946-923d-1ab7f7b81e99	guardian_dpo	DPPO	D7210	TN	\N	283.36	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
1012d806-52dd-4fb1-a008-b06ea36c43a3	guardian_dpo	DPPO	D7210	AL	\N	268.75	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
46c281c2-67c8-42cd-8371-b32998ab1145	guardian_dpo	DPPO	D7953	GA	\N	425.00	2026-01-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
39606ecb-16fa-42f2-b145-db53dc244d73	guardian_dpo	DPPO	D7953	FL	\N	446.25	2026-01-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
c80b57d3-6769-45e1-8202-68a0fdf76539	guardian_dpo	DPPO	D7953	TX	\N	467.50	2026-01-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
a4304271-1f7b-4cd6-ae1a-21e54cf03120	guardian_dpo	DPPO	D7953	NC	\N	416.50	2026-01-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
4378602f-2a37-44c7-be49-f3e7f5e1b712	guardian_dpo	DPPO	D7953	SC	\N	403.75	2026-01-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
47a84aed-9f95-4061-a917-5ff300845703	guardian_dpo	DPPO	D7953	TN	\N	412.25	2026-01-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
6b6c2f2a-2658-4a85-b2b0-2d1b91cf64c5	guardian_dpo	DPPO	D7953	AL	\N	391.00	2026-01-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
d0913cad-2801-496f-b19f-5389c08fa91d	guardian_dpo	DPPO	D9110	GA	\N	97.37	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
3cd96932-765e-4cac-a69b-158b14afd9fe	guardian_dpo	DPPO	D9110	FL	\N	102.24	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
8e07c2d8-ec08-4441-b5d4-c8efbe64d88a	guardian_dpo	DPPO	D9110	TX	\N	107.11	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
b6c050ae-c0fd-416a-9500-d8ee1c234d6a	guardian_dpo	DPPO	D9110	NC	\N	95.42	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
450c34f5-0286-419f-badf-b3c5cde6decc	guardian_dpo	DPPO	D9110	SC	\N	92.50	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
81e719fe-148d-4671-af13-90766776ec91	guardian_dpo	DPPO	D9110	TN	\N	94.45	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
4f334cad-03ce-41f5-ba52-d85e5231d978	guardian_dpo	DPPO	D9110	AL	\N	89.58	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
4dafbc9f-f83c-42c5-858c-5610de9cdab0	guardian_dpo	DPPO	D9230	GA	\N	128.12	2025-07-01	ga_medicaid_estimated	2026-08-06 13:29:14.2864+00
8924b862-4c37-4179-b4c1-f70ce4820c0a	guardian_dpo	DPPO	D9230	FL	\N	134.53	2025-07-01	fl_medicaid_estimated	2026-08-06 13:29:14.2864+00
854b7874-4bc7-4955-ae51-56bc6d74f22a	guardian_dpo	DPPO	D9230	TX	\N	140.93	2025-07-01	tx_medicaid_estimated	2026-08-06 13:29:14.2864+00
5f1c06de-e685-4d8e-909d-cc54d644e3ea	guardian_dpo	DPPO	D9230	NC	\N	125.56	2025-07-01	nc_medicaid_estimated	2026-08-06 13:29:14.2864+00
eff2e127-6bde-491e-829d-a7df9da7beec	guardian_dpo	DPPO	D9230	SC	\N	121.71	2025-07-01	sc_medicaid_estimated	2026-08-06 13:29:14.2864+00
eb4754d6-71ac-43ec-8619-f50d121580e4	guardian_dpo	DPPO	D9230	TN	\N	124.28	2025-07-01	tn_medicaid_estimated	2026-08-06 13:29:14.2864+00
6259d6fb-8db1-4552-9c21-284d5e1e10c6	guardian_dpo	DPPO	D9230	AL	\N	117.87	2025-07-01	al_medicaid_estimated	2026-08-06 13:29:14.2864+00
\.


--
-- Data for Name: frequency_limits; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.frequency_limits (limit_id, payer_id, plan_type, cdt_code, frequency_count, frequency_period, frequency_scope, age_limit_min, age_limit_max, waiting_days, notes, effective_date, created_at) FROM stdin;
d3c5d190-2cb4-4455-a1c5-f04930cdf85c	delta_dental	PPO	D0120	2	per_year	per_patient	\N	\N	0	\N	2026-01-01	2026-08-04 18:07:58.761322+00
10be057c-6020-4991-9e9b-affba4734daa	delta_dental	PPO	D0150	1	per_3_years	per_patient	\N	\N	0	\N	2026-01-01	2026-08-04 18:07:58.784998+00
eb5b402b-4d24-4d83-be02-8dcc449705fc	delta_dental	PPO	D0210	1	per_5_years	per_patient	\N	\N	0	\N	2026-01-01	2026-08-04 18:07:58.807771+00
d6db2c23-f3cb-4787-a5f7-a01e584a5f80	delta_dental	PPO	D0220	1	per_year	per_tooth	\N	\N	0	\N	2026-01-01	2026-08-04 18:07:58.830488+00
cb0782e7-b5a5-491f-8f0f-b32de45cdeb1	delta_dental	PPO	D0274	1	per_year	per_patient	\N	\N	0	\N	2026-01-01	2026-08-04 18:07:58.852251+00
67fdc23c-e328-47ee-8783-5ba1d6e3a8a7	delta_dental	PPO	D0330	1	per_5_years	per_patient	\N	\N	0	\N	2026-01-01	2026-08-04 18:07:58.876735+00
883a815e-8a74-469f-9eb8-62f153749a97	delta_dental	PPO	D1110	2	per_year	per_patient	\N	\N	150	\N	2026-01-01	2026-08-04 18:07:58.897941+00
bf840bd6-0d0b-454c-809b-68bb0aefd49e	delta_dental	PPO	D1351	1	per_lifetime	per_tooth	\N	15	0	\N	2026-01-01	2026-08-04 18:07:58.920705+00
99bf3470-a2d8-4ee0-84dd-b17016fdda01	delta_dental	PPO	D2750	1	per_5_years	per_tooth	\N	\N	0	\N	2026-01-01	2026-08-04 18:07:58.9445+00
f075a918-1e5a-4628-a9e8-d9379d6df8c7	delta_dental	PPO	D2740	1	per_5_years	per_tooth	\N	\N	0	\N	2026-01-01	2026-08-04 18:07:58.966763+00
e5ea0883-d736-453f-ad3f-498a6576e269	delta_dental	PPO	D3310	1	per_lifetime	per_tooth	\N	\N	0	\N	2026-01-01	2026-08-04 18:07:58.988745+00
f999fa1c-f3e2-40aa-b326-5a96262c65e3	delta_dental	PPO	D3320	1	per_lifetime	per_tooth	\N	\N	0	\N	2026-01-01	2026-08-04 18:07:59.00926+00
926fd824-3f2d-4b09-a4e5-cf6315431b58	delta_dental	PPO	D3330	1	per_lifetime	per_tooth	\N	\N	0	\N	2026-01-01	2026-08-04 18:07:59.030239+00
bbf19a4c-e18d-49e8-9c71-a65faae68b11	delta_dental	PPO	D4260	1	per_3_years	per_quadrant	\N	\N	0	\N	2026-01-01	2026-08-04 18:07:59.05148+00
9b1a09da-ec44-4372-8d59-8097f56bc822	delta_dental	PPO	D4341	1	per_2_years	per_quadrant	\N	\N	0	\N	2026-01-01	2026-08-04 18:07:59.074985+00
3f3e0bf4-54fe-4a91-854a-cbff55c81c40	delta_dental	PPO	D4910	4	per_year	per_patient	\N	\N	0	\N	2026-01-01	2026-08-04 18:07:59.096241+00
2ac114c9-05b0-4c23-9687-8b7148adf587	delta_dental	PPO	D6010	1	per_lifetime	per_tooth	18	\N	0	\N	2026-01-01	2026-08-04 18:07:59.116968+00
31b628bc-5f5b-4da1-92f1-d0795bcf5ec1	delta_dental	PPO	D6065	1	per_7_years	per_tooth	18	\N	0	\N	2026-01-01	2026-08-04 18:07:59.164745+00
408b5850-6601-485c-a34f-b737ff60ac87	delta_dental	PPO	D8080	1	per_lifetime	per_patient	12	19	0	\N	2026-01-01	2026-08-04 18:07:59.18623+00
4e02872b-e411-4882-8a8c-2ac8a635249f	cigna	DPPO	D2750	1	per_4_years	per_tooth	\N	\N	0	\N	2026-01-01	2026-08-04 18:07:59.206978+00
a6ab08b7-31a5-415a-b5c1-3aadbdf17c8d	cigna	DPPO	D2740	1	per_4_years	per_tooth	\N	\N	0	\N	2026-01-01	2026-08-04 18:07:59.228935+00
79992c8e-5b8d-4db9-b7ce-7186cb7f07cb	cigna	DPPO	D0330	1	per_5_years	per_patient	\N	\N	0	\N	2026-01-01	2026-08-04 18:07:59.250112+00
0a1a06ee-410e-421a-8ea0-30a5fe84a522	cigna	DPPO	D4910	4	per_year	per_patient	\N	\N	0	\N	2026-01-01	2026-08-04 18:07:59.272993+00
12bf958d-2540-446b-b108-8ec3f52b338a	cigna	DPPO	D6065	1	per_5_years	per_tooth	18	\N	0	\N	2026-01-01	2026-08-04 18:07:59.29825+00
38bc3278-95b9-4724-8db7-4dc59c72eb5d	metlife	PDP	D0330	1	per_3_years	per_patient	\N	\N	0	\N	2026-01-01	2026-08-04 18:07:59.320506+00
36fe62a9-6fd0-4045-86f1-126df3c5d693	metlife	PDP	D4910	3	per_year	per_patient	\N	\N	0	\N	2026-01-01	2026-08-04 18:07:59.341723+00
40c236d4-173e-41cd-accc-ac33b2a81031	metlife	PDP	D6065	1	per_5_years	per_tooth	18	\N	0	\N	2026-01-01	2026-08-04 18:07:59.361492+00
\.


--
-- Data for Name: medical_history_flags; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.medical_history_flags (flag_id, flag_code, flag_name, flag_category, contraindicated_cdts, risk_level, icd10_codes, drug_names, drug_classes, documentation_required, clinical_action, notes, created_at) FROM stdin;
1e23ec45-5589-4eb8-b49d-71a1749da4e7	BISPHOS_IV	IV Bisphosphonate Therapy	medication	{D6010,D6011,D7210,D7310,D7953,D4260,D7240}	absolute_contraindication	{Z79.83}	{"zoledronic acid",Zometa,"ibandronate IV",Reclast}	{bisphosphonate}	Medical consultation required. Confirm duration and route of therapy.	Do not perform implants or bone surgery. Risk of osteonecrosis of the jaw (ONJ). Refer to oral surgeon for risk assessment. Document refusal if patient insists.	\N	2026-08-04 18:07:59.381+00
498ad12c-ffff-4e41-9d81-b5a3388364b1	BISPHOS_ORAL	Oral Bisphosphonate Therapy	medication	{D6010,D7953,D4260}	high_risk	{Z79.83}	{alendronate,Fosamax,"ibandronate oral",Boniva,risedronate,Actonel}	{bisphosphonate}	Document duration of oral therapy â€” risk rises after 4 years.	Discuss drug holiday with prescribing physician. Document risk discussion in chart. Proceed only with informed consent.	\N	2026-08-04 18:07:59.401977+00
d4addb6f-6c58-4672-b97f-20a810b4bc14	HEAD_NECK_RADIATION	Prior Head and Neck Radiation	medical_condition	{D6010,D6011,D7953,D4260,D7210,D7220,D7230,D7240}	high_risk	{Z85.818,Z92.3}	{}	{}	Radiation oncology records including dose and field.	Hyperbaric oxygen protocol may be required. Medical clearance mandatory from radiation oncologist. Minimum 6 months post-radiation before elective surgery.	\N	2026-08-04 18:07:59.423247+00
f81c92ea-32e4-4526-a678-cdb1f1a71045	UNCONTROLLED_DIABETES	Uncontrolled Diabetes (HbA1c >9)	medical_condition	{D6010,D7953,D4260,D7210,D7220,D7230,D7240}	requires_medical_clearance	{E11.65,E10.65,E11.649,E10.649}	{}	{}	Recent HbA1c result within 3 months.	Medical clearance required. HbA1c must be <8 before elective surgery. Document glucose control status. Coordinate with endocrinologist.	\N	2026-08-04 18:07:59.444559+00
d70ef188-6f7d-4774-aae3-cac7d9c093a5	BLOOD_THINNER_ANTIPLATELET	Antiplatelet Therapy	medication	{D7210,D7220,D7230,D7240,D4260,D6010,D7953}	requires_medical_clearance	{Z79.02}	{aspirin,clopidogrel,Plavix,ticagrelor,Brilinta,prasugrel,Effient,dipyridamole}	{antiplatelet}	Current medication list and prescribing physician contact.	Consult prescribing physician before stopping. Do not discontinue without medical clearance. Use local hemostatic measures. Document bleeding risk discussion.	\N	2026-08-04 18:07:59.464514+00
538ed533-0840-4e48-b6c9-a74610a8113b	BLOOD_THINNER_ANTICOAGULANT	Anticoagulant Therapy	medication	{D7210,D7220,D7230,D7240,D4260,D6010,D7953,D7310}	requires_medical_clearance	{Z79.01}	{warfarin,Coumadin,rivaroxaban,Xarelto,apixaban,Eliquis,dabigatran,Pradaxa,edoxaban,Savaysa}	{anticoagulant,DOAC,"direct oral anticoagulant"}	INR within 24-72 hours for warfarin patients.	Check INR for warfarin patients (target <3.5 for most dental surgery). For DOACs consult prescribing physician. Use local hemostatic measures. Monitor post-op bleeding.	\N	2026-08-04 18:07:59.485998+00
b395926f-da53-41ff-9d32-79deda2ba4be	PREGNANCY	Current Pregnancy	medical_condition	{D7220,D7230,D7240,D6010,D9220,D9230,D9239}	high_risk	{Z34.00,Z34.10,Z34.20,Z34.30,Z34.80,Z34.90}	{}	{}	Trimester and OB/GYN contact.	Defer elective treatment. Emergency treatment only in second trimester (weeks 14-20 safest). No nitrous oxide. No elective radiographs (use lead apron if essential). No implants or elective surgery. Consult OB/GYN for complex cases.	\N	2026-08-04 18:07:59.516751+00
17943e24-8d45-4b6e-943c-54115ec583a7	SMOKING_ACTIVE	Active Tobacco Smoker	lifestyle	{}	document_only	{Z72.0,F17.210}	{}	{}	Packs per day and duration.	Document smoking status in chart. Affects implant success rate (2-3x higher failure), periodontal healing, and graft incorporation. Counsel on cessation. Critical for appeal documentation â€” payers reference smoking in clinical necessity decisions. Consider nicotine cessation protocol before implants.	\N	2026-08-04 18:07:59.536983+00
\.


--
-- Data for Name: overlay_rules; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.overlay_rules (overlay_rule_id, tenant_id, payer_id, cdt_code, rule_overrides, reason, active, effective_from, effective_to, created_at, updated_at) FROM stdin;
1	suwanee_smiles	delta_dental	D6065	{"clinical_criteria_required": true}	Practice policy: implant crowns get clinical review before submission rather than auto-approving.	t	2026-08-04	\N	2026-08-04 16:44:18.408989+00	2026-08-04 16:56:54.932567+00
2	suwanee_smiles	delta_dental	D7953	{"bundling_note": "Ridge preservation grafted at extraction, staged before implant placement. Document as a separate surgical episode with its own date of service."}	Practice-specific unbundling narrative; ~65% appeal overturn when documented (PRD section 10).	t	2026-08-04	\N	2026-08-04 16:44:18.431505+00	2026-08-04 16:56:54.954291+00
\.


--
-- Data for Name: patients; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.patients (patient_id, tenant_id, first_name, last_name, dob, gender, member_id, group_number, payer_id, enrollment_start, active, plan_id, secondary_payer_id, email, mobile_phone) FROM stdin;
PAT-DA-D05	suwanee_smiles	Carlos	Rivera	08/10/1980	M	SS-DA-D05-0001	GRP-44821	delta_dental	2020-01-01	t	delta_ppo	\N	carlos.rivera.30@email.com	+17705550030
PAT-DA-A01	suwanee_smiles	James	Mitchell	04/15/1972	M	SS-DA-A01-0001	GRP-44821	delta_dental	2020-01-01	t	delta_ppo	\N	james.mitchell@email.com	+17705550001
PAT-DA-D04	suwanee_smiles	Linda	Taylor	11/30/1972	F	SS-DA-D04-0001	GRP-77103	delta_dental	2020-01-01	t	delta_ppo	\N	linda.taylor@email.com	+17705550002
PAT-DA-B04	suwanee_smiles	Carlos	Rivera	08/10/1980	M	SS-DA-B04-0001	GRP-44821	delta_dental	2020-01-01	t	delta_ppo	\N	carlos.rivera@email.com	+17705550003
PAT-DA-A02	suwanee_smiles	Sandra	Williams	09/22/1968	F	SS-DA-A02-0001	GRP-44821	delta_dental	2020-01-01	t	delta_ppo	\N	sandra.williams.7@email.com	+17705550007
PAT-DA-A03	suwanee_smiles	Robert	Chen	11/08/1975	M	SS-DA-A03-0001	GRP-77103	delta_dental	2020-01-01	t	delta_ppo	\N	robert.chen.8@email.com	+17705550008
PAT-DA-A04	suwanee_smiles	Maria	Rodriguez	03/30/1982	F	SS-DA-A04-0001	GRP-55290	delta_dental	2020-01-01	t	delta_ppo	\N	maria.rodriguez.9@email.com	+17705550009
PAT-DA-A05	suwanee_smiles	Kevin	Park	07/14/1990	M	SS-DA-A05-0001	GRP-44821	delta_dental	2020-01-01	t	delta_ppo	\N	kevin.park.10@email.com	+17705550010
PAT-DA-B01	suwanee_smiles	Patricia	Johnson	12/05/1965	F	SS-DA-B01-0001	GRP-BASIC-01	delta_dental	2020-01-01	t	delta_ppo	\N	patricia.johnson.11@email.com	+17705550011
PAT-DA-B02	suwanee_smiles	Thomas	Anderson	06/18/1978	M	SS-DA-B02-0001	GRP-44821	delta_dental	2022-01-01	t	delta_ppo	\N	thomas.anderson.12@email.com	+17705550012
PAT-DA-B03	suwanee_smiles	Dorothy	Harris	02/28/1960	F	SS-DA-B03-0001	GRP-77103	delta_dental	2020-01-01	t	delta_ppo	\N	dorothy.harris.13@email.com	+17705550013
PAT-DA-B05	suwanee_smiles	Ashley	Thompson	05/22/1995	F	SS-DA-B05-0001	GRP-NEW-2025	delta_dental	2025-12-06	t	delta_ppo	\N	ashley.thompson.15@email.com	+17705550015
PAT-DA-C01	suwanee_smiles	Robert	Kim	01/19/1971	M	SS-DA-C01-0001	GRP-44821	delta_dental	2020-01-01	t	delta_ppo	\N	robert.kim.16@email.com	+17705550016
PAT-DA-C02	suwanee_smiles	Elena	Santos	07/03/1974	F	SS-DA-C02-0001	GRP-77103	delta_dental	2020-01-01	t	delta_ppo	\N	elena.santos.17@email.com	+17705550017
PAT-DA-C03	suwanee_smiles	William	Foster	10/27/1963	M	SS-DA-C03-0001	GRP-44821	delta_dental	2020-01-01	t	delta_ppo	\N	william.foster.18@email.com	+17705550018
PAT-DA-C04	suwanee_smiles	Nancy	Wright	04/08/1966	F	SS-DA-C04-0001	GRP-77103	delta_dental	2020-01-01	t	delta_ppo	\N	nancy.wright.19@email.com	+17705550019
PAT-DA-C05	suwanee_smiles	James	Park	12/11/1979	M	SS-DA-C05-0001	GRP-55290	delta_dental	2020-01-01	t	delta_ppo	cigna	james.park.20@email.com	+17705550020
PAT-DA-D01	suwanee_smiles	Barbara	Chen	06/24/1969	F	SS-DA-D01-0001	GRP-44821	delta_dental	2020-01-01	t	delta_ppo	\N	barbara.chen.26@email.com	+17705550026
PAT-DA-D02	suwanee_smiles	Richard	Moore	02/17/1958	M	SS-DA-D02-0001	GRP-44821	delta_dental	2020-01-01	t	delta_ppo	\N	richard.moore.27@email.com	+17705550027
PAT-DA-D03	suwanee_smiles	Susan	Lee	09/05/1985	F	SS-DA-D03-0001	GRP-NEW-2025	delta_dental	2025-09-06	t	delta_ppo	\N	susan.lee.28@email.com	+17705550028
PAT-DL-A01	dallas_dental	David	Johnson	05/11/1978	M	SS-DL-A01-0001	GRP-GRD-07	guardian_dpo	2020-01-01	t	guardian_dppo	\N	david.johnson.1@email.com	+17705550001
PAT-DL-B01	dallas_dental	Patricia	Lee	08/16/1971	F	SS-DL-B01-0001	GRP-GRD-07	guardian_dpo	2020-01-01	t	guardian_dppo	\N	patricia.lee.2@email.com	+17705550002
PAT-DL-C01	dallas_dental	Thomas	Wilson	12/03/1964	M	SS-DL-C01-0001	GRP-44821	delta_dental	2020-01-01	t	delta_ppo	\N	thomas.wilson.3@email.com	+17705550003
PAT-DL-D01	dallas_dental	Emily	Garcia	04/22/1991	F	SS-DL-D01-0001	GRP-HUM-11	humana_dpo	2020-01-01	t	humana_dppo	\N	emily.garcia.4@email.com	+17705550004
PAT-DL-U01	dallas_dental	Kevin	Brown	09/07/1995	M	SS-DL-U01-0001	GRP-GRD-07	guardian_dpo	2020-01-01	t	guardian_dppo	\N	kevin.brown.5@email.com	+17705550005
PAT-DA-C06	suwanee_smiles	Michelle	Wong	05/16/1975	F	SS-DA-C06-0001	GRP-CIG-01	cigna	2020-01-01	t	cigna_dppo	\N	michelle.wong.21@email.com	+17705550021
PAT-DA-C07	suwanee_smiles	Kevin	Adams	02/09/1969	M	SS-DA-C07-0001	GRP-MET-04	metlife	2020-01-01	t	metlife_pdp	\N	kevin.adams.22@email.com	+17705550022
PAT-DA-C08	suwanee_smiles	Emma	Davis	07/22/2014	F	SS-DA-C08-0001	GRP-44821	delta_dental	2020-01-01	t	delta_ppo	cigna	emma.davis.23@email.com	+17705550023
PAT-DA-C09	suwanee_smiles	Ruth	Thompson	11/04/1952	F	SS-DA-C09-0001	GRP-77103	delta_dental	2020-01-01	t	delta_ppo	\N	ruth.thompson.24@email.com	+17705550024
PAT-DA-C10	suwanee_smiles	John	Miller	06/30/1971	M	SS-DA-C10-0001	GRP-44821	delta_dental	2020-01-01	t	delta_ppo	\N	john.miller.25@email.com	+17705550025
PAT-DA-F01	suwanee_smiles	Thomas	Garcia	04/26/1973	M	SS-DA-F01-0001	GRP-44821	delta_dental	2020-01-01	t	delta_ppo	\N	thomas.garcia.31@email.com	+17705550031
PAT-DA-F02	suwanee_smiles	Mary	Johnson	12/19/1961	F	SS-DA-F02-0001	GRP-55290	delta_dental	2020-01-01	t	delta_ppo	\N	mary.johnson.32@email.com	+17705550032
PAT-DA-F03	suwanee_smiles	George	Wilson	07/07/1959	M	SS-DA-F03-0001	GRP-77103	delta_dental	2020-01-01	t	delta_ppo	\N	george.wilson.33@email.com	+17705550033
PAT-DA-F04	suwanee_smiles	Alice	Thompson	02/03/1977	F	SS-DA-F04-0001	GRP-44821	delta_dental	2020-01-01	t	delta_ppo	\N	alice.thompson.34@email.com	+17705550034
PAT-DA-F05	suwanee_smiles	Frank	Davis	09/28/1968	M	SS-DA-F05-0001	GRP-44821	delta_dental	2020-01-01	t	delta_ppo	\N	frank.davis.35@email.com	+17705550035
PAT-DA-M01	suwanee_smiles	Jennifer	Adams	03/14/1983	F	SS-DA-M01-0001	GRP-44821	delta_dental	2020-01-01	t	delta_ppo	\N	jennifer.adams.36@email.com	+17705550036
PAT-DA-M02	suwanee_smiles	Michael	Brown	05/09/1976	M	SS-DA-M02-0001	GRP-77103	delta_dental	2020-01-01	t	delta_ppo	\N	michael.brown.37@email.com	+17705550037
PAT-DA-M03	suwanee_smiles	Patricia	Wong	01/22/1970	F	SS-DA-M03-0001	GRP-55290	delta_dental	2020-01-01	t	delta_ppo	\N	patricia.wong.38@email.com	+17705550038
PAT-DA-M04	suwanee_smiles	David	Kim	10/02/1981	M	SS-DA-M04-0001	GRP-44821	delta_dental	2020-01-01	t	delta_ppo	\N	david.kim.39@email.com	+17705550039
PAT-DA-M05	suwanee_smiles	Helen	Martinez	08/17/1964	F	SS-DA-M05-0001	GRP-77103	delta_dental	2020-01-01	t	delta_ppo	\N	helen.martinez.40@email.com	+17705550040
PAT-DA-U03	suwanee_smiles	Kevin	Lee	11/08/1986	M	SS-DA-U03-0001	GRP-CIG-01	cigna	2020-01-01	t	cigna_dppo	\N	kevin.lee.43@email.com	+17705550043
PAT-DA-U04	suwanee_smiles	Dorothy	Chen	09/30/1961	F	SS-DA-U04-0001	GRP-MET-04	metlife	2020-01-01	t	metlife_pdp	\N	dorothy.chen.44@email.com	+17705550044
PAT-DA-U05	suwanee_smiles	Frank	Wilson	01/17/1966	M	SS-DA-U05-0001	GRP-44821	delta_dental	2020-01-01	t	delta_ppo	\N	frank.wilson.45@email.com	+17705550045
PAT-TB-A01	tampa_smiles	Sarah	Chen	03/12/1988	F	SS-TB-A01-0001	GRP-HUM-11	humana_dpo	2020-01-01	t	humana_dppo	\N	sarah.chen.46@email.com	+17705550046
PAT-TB-B01	tampa_smiles	Robert	Martinez	06/24/1974	M	SS-TB-B01-0001	GRP-AET-02	aetna_dmo	2020-01-01	t	aetna_dmo	\N	robert.martinez.47@email.com	+17705550047
PAT-TB-C01	tampa_smiles	Lisa	Thompson	10/05/1982	F	SS-TB-C01-0001	GRP-GRD-07	guardian_dpo	2020-01-01	t	guardian_dppo	\N	lisa.thompson.48@email.com	+17705550048
PAT-TB-D01	tampa_smiles	Michael	Park	02/19/1985	M	SS-TB-D01-0001	GRP-AET-02	aetna_dmo	2020-01-01	t	aetna_dmo	\N	michael.park.49@email.com	+17705550049
PAT-TB-U01	tampa_smiles	Jennifer	Adams	07/30/1997	F	SS-TB-U01-0001	GRP-HUM-11	humana_dpo	2020-01-01	t	humana_dppo	\N	jennifer.adams.50@email.com	+17705550050
PAT-DA-U01	suwanee_smiles	Robert	Thompson	03/12/1978	M	SS-DA-U01-0001	GRP-44821	delta_dental	2020-01-01	t	delta_ppo	\N	robert.thompson@email.com	+17705550004
PAT-DA-U02	suwanee_smiles	Maria	Santos	07/25/1983	F	SS-DA-U02-0001	GRP-44821	delta_dental	2020-01-01	t	delta_ppo	\N	maria.santos@email.com	+17705550005
\.


--
-- Data for Name: payer_responses; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.payer_responses (response_id, pred_request_id, tenant_id, response_type, pred_number, decision, denial_reason, denial_code, policy_citation, received_at, raw_payload, payer_id, plan_type, response_date, approved_amount, valid_from, valid_to, denial_reason_code, denial_reason_text, appeal_deadline, pend_checklist) FROM stdin;
21	PRED-SIM-DA-D01	suwanee_smiles	pre_determination_response	DD-2026-DA-D01-PND	pended	\N	\N	\N	\N	{"generated_from": "pred_states"}	delta_dental	PPO	2026-08-06	\N	\N	\N	\N	\N	\N	["COVERAGE_PRED_REQUIRED", "PROVIDER_OUT_OF_NETWORK", "COVERAGE_BUNDLING_CONFLICT", "CLINICAL_XRAY_REQUIRED", "CLINICAL_NARRATIVE_REQUIRED"]
24	PRED-SIM-DA-D04	suwanee_smiles	pre_determination_response	DD-2026-DA-D04-APP	approved	\N	\N	\N	\N	{"generated_from": "pred_states"}	delta_dental	PPO	2026-08-06	570.00	2026-08-06	2027-02-02	\N	\N	\N	[]
34	PRED-SIM-DA-M04	suwanee_smiles	pre_determination_response	DD-2026-DA-M04-PND	pended	\N	\N	\N	\N	{"generated_from": "pred_states"}	delta_dental	PPO	2026-08-06	\N	\N	\N	\N	\N	\N	["COVERAGE_PRED_REQUIRED", "ADMIN_DUPLICATE_PRED"]
35	PRED-SIM-DA-M05	suwanee_smiles	pre_determination_response	DD-2026-DA-M05-PND	pended	\N	\N	\N	\N	{"generated_from": "pred_states"}	delta_dental	PPO	2026-08-06	\N	\N	\N	\N	\N	\N	["COVERAGE_PRED_REQUIRED", "CLINICAL_XRAY_REQUIRED"]
107	PRED-SIM-DA-U02	suwanee_smiles	pre_determination_response	DD-2026-DA-U02-APP	approved	\N	\N	\N	\N	{"generated_from": "pred_states"}	delta_dental	PPO	2026-08-06	26.87	2026-08-06	2027-02-02	\N	\N	\N	[]
108	PRED-SIM-DA-U03	suwanee_smiles	pre_determination_response	DD-2026-DA-U03-APP	approved	\N	\N	\N	\N	{"generated_from": "pred_states"}	cigna	DPPO	2026-08-06	79.00	2026-08-06	2027-02-02	\N	\N	\N	[]
109	PRED-SIM-DA-U04	suwanee_smiles	pre_determination_response	DD-2026-DA-U04-APP	approved	\N	\N	\N	\N	{"generated_from": "pred_states"}	metlife	PDP	2026-08-06	67.92	2026-08-06	2027-02-02	\N	\N	\N	[]
110	PRED-SIM-DA-U05	suwanee_smiles	pre_determination_response	DD-2026-DA-U05-APP	approved	\N	\N	\N	\N	{"generated_from": "pred_states"}	delta_dental	PPO	2026-08-06	78.90	2026-08-06	2027-02-02	\N	\N	\N	[]
1	PRED-SIM-DA-A01	suwanee_smiles	pre_determination_response	DD-2026-DA-A01-PND	pended	\N	\N	\N	\N	{"generated_from": "pred_states"}	delta_dental	PPO	2026-08-06	\N	\N	\N	\N	\N	\N	["COVERAGE_PRED_REQUIRED", "COVERAGE_BUNDLING_CONFLICT", "CLINICAL_XRAY_REQUIRED", "CLINICAL_NARRATIVE_REQUIRED", "COVERAGE_DOWNGRADE_APPLIED", "CLINICAL_CRITERIA_NOT_MET"]
2	PRED-SIM-DA-A02	suwanee_smiles	pre_determination_response	DD-2026-DA-A02-APP	approved	\N	\N	\N	\N	{"generated_from": "pred_states"}	delta_dental	PPO	2026-08-06	570.00	2026-08-06	2027-02-02	\N	\N	\N	[]
3	PRED-SIM-DA-A03	suwanee_smiles	pre_determination_response	DD-2026-DA-A03-APP	approved	\N	\N	\N	\N	{"generated_from": "pred_states"}	delta_dental	PPO	2026-08-06	1435.00	2026-08-06	2027-02-02	\N	\N	\N	[]
4	PRED-SIM-DA-A04	suwanee_smiles	pre_determination_response	DD-2026-DA-A04-APP	approved	\N	\N	\N	\N	{"generated_from": "pred_states"}	delta_dental	PPO	2026-08-06	829.20	2026-08-06	2027-02-02	\N	\N	\N	[]
5	PRED-SIM-DA-A05	suwanee_smiles	pre_determination_response	DD-2026-DA-A05-APP	approved	\N	\N	\N	\N	{"generated_from": "pred_states"}	delta_dental	PPO	2026-08-06	158.87	2026-08-06	2027-02-02	\N	\N	\N	[]
6	PRED-SIM-DA-B01	suwanee_smiles	pre_determination_response	DD-2026-DA-B01-DEN	denied	\N	\N	D.1.2	\N	{"generated_from": "pred_states"}	delta_dental	PPO	2026-08-06	0.00	\N	\N	D.1.2	Implants excluded from this plan â€” patient responsible for ${case_value}	2026-10-05	[]
14	PRED-SIM-DA-C04	suwanee_smiles	pre_determination_response	DD-2026-DA-C04-PND	pended	\N	\N	\N	\N	{"generated_from": "pred_states"}	delta_dental	PPO	2026-08-06	\N	\N	\N	\N	\N	\N	["COVERAGE_PRED_REQUIRED", "CLINICAL_XRAY_REQUIRED"]
7	PRED-SIM-DA-B02	suwanee_smiles	pre_determination_response	DD-2026-DA-B02-DEN	denied	\N	\N	D.1.4	\N	{"generated_from": "pred_states"}	delta_dental	PPO	2026-08-06	0.00	\N	\N	D.1.4	Tooth #${tooth} missing before enrollment ${date} â€” excluded from implant coverage	2026-10-05	[]
8	PRED-SIM-DA-B03	suwanee_smiles	pre_determination_response	DD-2026-DA-B03-DEN	denied	\N	\N	D.3.1	\N	{"generated_from": "pred_states"}	delta_dental	PPO	2026-08-06	0.00	\N	\N	D.3.1	${cdt_code} tooth #${tooth}: last approved ${last_date}. Next eligible: ${eligible_date}	2026-10-05	[]
9	PRED-SIM-DA-B04	suwanee_smiles	pre_determination_response	DD-2026-DA-B04-PND	pended	\N	\N	\N	\N	{"generated_from": "pred_states"}	delta_dental	PPO	2026-08-06	\N	\N	\N	\N	\N	\N	["COVERAGE_PRED_REQUIRED", "COVERAGE_BUNDLING_CONFLICT", "CLINICAL_XRAY_REQUIRED", "CLINICAL_NARRATIVE_REQUIRED"]
10	PRED-SIM-DA-B05	suwanee_smiles	pre_determination_response	DD-2026-DA-B05-DEN	denied	\N	\N	D.2.1	\N	{"generated_from": "pred_states"}	delta_dental	PPO	2026-08-06	0.00	\N	\N	D.2.1	Major services waiting period of ${months} months not satisfied. Eligible: ${eligible_date}	2026-10-05	[]
11	PRED-SIM-DA-C01	suwanee_smiles	pre_determination_response	DD-2026-DA-C01-PND	pended	\N	\N	\N	\N	{"generated_from": "pred_states"}	delta_dental	PPO	2026-08-06	\N	\N	\N	\N	\N	\N	["COVERAGE_PRED_REQUIRED", "CLINICAL_CRITERIA_NOT_MET", "COVERAGE_BUNDLING_CONFLICT", "CLINICAL_XRAY_REQUIRED", "CLINICAL_NARRATIVE_REQUIRED", "CLINICAL_BONE_LOSS_THRESHOLD"]
12	PRED-SIM-DA-C02	suwanee_smiles	pre_determination_response	DD-2026-DA-C02-PND	pended	\N	\N	\N	\N	{"generated_from": "pred_states"}	delta_dental	PPO	2026-08-06	\N	\N	\N	\N	\N	\N	["COVERAGE_PRED_REQUIRED", "CLINICAL_CRITERIA_NOT_MET", "CLINICAL_POCKET_DEPTH", "CLINICAL_BONE_LOSS_THRESHOLD", "CLINICAL_PERIO_CHART_REQUIRED"]
13	PRED-SIM-DA-C03	suwanee_smiles	pre_determination_response	DD-2026-DA-C03-PND	pended	\N	\N	\N	\N	{"generated_from": "pred_states"}	delta_dental	PPO	2026-08-06	\N	\N	\N	\N	\N	\N	["COVERAGE_PRED_REQUIRED", "CLINICAL_CBCT_REQUIRED", "COVERAGE_DOWNGRADE_APPLIED"]
15	PRED-SIM-DA-C05	suwanee_smiles	pre_determination_response	DD-2026-DA-C05-PND	pended	\N	\N	\N	\N	{"generated_from": "pred_states"}	delta_dental	PPO	2026-08-06	\N	\N	\N	\N	\N	\N	["COVERAGE_PRED_REQUIRED", "ELIG_COB_REQUIRED", "ADMIN_COB_PRIMARY_FIRST"]
16	PRED-SIM-DA-C06	suwanee_smiles	pre_determination_response	DD-2026-DA-C06-APP	approved	\N	\N	\N	\N	{"generated_from": "pred_states"}	cigna	DPPO	2026-08-06	631.25	2026-08-06	2027-02-02	\N	\N	\N	[]
17	PRED-SIM-DA-C07	suwanee_smiles	pre_determination_response	DD-2026-DA-C07-APP	approved	\N	\N	\N	\N	{"generated_from": "pred_states"}	metlife	PDP	2026-08-06	105.70	2026-08-06	2027-02-02	\N	\N	\N	[]
18	PRED-SIM-DA-C08	suwanee_smiles	pre_determination_response	DD-2026-DA-C08-PND	pended	\N	\N	\N	\N	{"generated_from": "pred_states"}	delta_dental	PPO	2026-08-06	\N	\N	\N	\N	\N	\N	["COVERAGE_PRED_REQUIRED", "ELIG_COB_REQUIRED", "ADMIN_COB_PRIMARY_FIRST"]
19	PRED-SIM-DA-C09	suwanee_smiles	pre_determination_response	DD-2026-DA-C09-PND	pended	\N	\N	\N	\N	{"generated_from": "pred_states"}	delta_dental	PPO	2026-08-06	\N	\N	\N	\N	\N	\N	["COVERAGE_PRED_REQUIRED", "CLINICAL_MEDICAL_HISTORY_FLAG"]
20	PRED-SIM-DA-C10	suwanee_smiles	pre_determination_response	DD-2026-DA-C10-PND	pended	\N	\N	\N	\N	{"generated_from": "pred_states"}	delta_dental	PPO	2026-08-06	\N	\N	\N	\N	\N	\N	["COVERAGE_PRED_REQUIRED", "PROVIDER_OIG_EXCLUDED"]
22	PRED-SIM-DA-D02	suwanee_smiles	pre_determination_response	DD-2026-DA-D02-PND	pended	\N	\N	\N	\N	{"generated_from": "pred_states"}	delta_dental	PPO	2026-08-06	\N	\N	\N	\N	\N	\N	["COVERAGE_PRED_REQUIRED", "COVERAGE_BUNDLING_CONFLICT", "CLINICAL_XRAY_REQUIRED", "CLINICAL_NARRATIVE_REQUIRED", "COVERAGE_DOWNGRADE_APPLIED", "CLINICAL_CRITERIA_NOT_MET"]
23	PRED-SIM-DA-D03	suwanee_smiles	pre_determination_response	DD-2026-DA-D03-DEN	denied	\N	\N	D.2.1	\N	{"generated_from": "pred_states"}	delta_dental	PPO	2026-08-06	0.00	\N	\N	D.2.1	Major services waiting period of ${months} months not satisfied. Eligible: ${eligible_date}	2026-10-05	[]
25	PRED-SIM-DA-D05	suwanee_smiles	pre_determination_response	DD-2026-DA-D05-APP	approved	\N	\N	\N	\N	{"generated_from": "pred_states"}	delta_dental	PPO	2026-08-06	1180.00	2026-08-06	2027-02-02	\N	\N	\N	[]
26	PRED-SIM-DA-F01	suwanee_smiles	pre_determination_response	DD-2026-DA-F01-PND	pended	\N	\N	\N	\N	{"generated_from": "pred_states"}	delta_dental	PPO	2026-08-06	\N	\N	\N	\N	\N	\N	["COVERAGE_DOWNGRADE_APPLIED", "COVERAGE_PRED_REQUIRED", "COVERAGE_SURFACE_MISMATCH"]
27	PRED-SIM-DA-F02	suwanee_smiles	pre_determination_response	DD-2026-DA-F02-DEN	denied	\N	\N	D.4.1	\N	{"generated_from": "pred_states"}	delta_dental	PPO	2026-08-06	0.00	\N	\N	D.4.1	${cdt_code} does not meet ${payer} clinical criteria. Score: ${score}. Missing: ${missing}	2026-10-05	[]
28	PRED-SIM-DA-F03	suwanee_smiles	pre_determination_response	DD-2026-DA-F03-DEN	denied	\N	\N	D.3.1	\N	{"generated_from": "pred_states"}	delta_dental	PPO	2026-08-06	0.00	\N	\N	D.3.1	${cdt_code} tooth #${tooth}: last approved ${last_date}. Next eligible: ${eligible_date}	2026-10-05	[]
29	PRED-SIM-DA-F04	suwanee_smiles	pre_determination_response	DD-2026-DA-F04-PND	pended	\N	\N	\N	\N	{"generated_from": "pred_states"}	delta_dental	PPO	2026-08-06	\N	\N	\N	\N	\N	\N	["COVERAGE_BUNDLING_CONFLICT", "COVERAGE_PRED_REQUIRED"]
30	PRED-SIM-DA-F05	suwanee_smiles	pre_determination_response	DD-2026-DA-F05-PND	pended	\N	\N	\N	\N	{"generated_from": "pred_states"}	delta_dental	PPO	2026-08-06	\N	\N	\N	\N	\N	\N	["COVERAGE_PRED_REQUIRED"]
31	PRED-SIM-DA-M01	suwanee_smiles	pre_determination_response	DD-2026-DA-M01-PND	pended	\N	\N	\N	\N	{"generated_from": "pred_states"}	delta_dental	PPO	2026-08-06	\N	\N	\N	\N	\N	\N	["COVERAGE_PRED_REQUIRED", "ELIG_PLAN_NOT_FOUND"]
32	PRED-SIM-DA-M02	suwanee_smiles	pre_determination_response	DD-2026-DA-M02-PND	pended	\N	\N	\N	\N	{"generated_from": "pred_states"}	delta_dental	PPO	2026-08-06	\N	\N	\N	\N	\N	\N	["COVERAGE_PRED_REQUIRED", "CLINICAL_CRITERIA_NOT_MET", "CLINICAL_BONE_LOSS_THRESHOLD", "CLINICAL_XRAY_REQUIRED"]
33	PRED-SIM-DA-M03	suwanee_smiles	pre_determination_response	DD-2026-DA-M03-PND	pended	\N	\N	\N	\N	{"generated_from": "pred_states"}	delta_dental	PPO	2026-08-06	\N	\N	\N	\N	\N	\N	["COVERAGE_PRED_REQUIRED", "COVERAGE_SURFACE_MISMATCH"]
106	PRED-SIM-DA-U01	suwanee_smiles	pre_determination_response	DD-2026-DA-U01-APP	approved	\N	\N	\N	\N	{"generated_from": "pred_states"}	delta_dental	PPO	2026-08-06	62.75	2026-08-06	2027-02-02	\N	\N	\N	[]
\.


--
-- Data for Name: payers; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.payers (payer_id, name, payer_type, x12_payer_id, portal_url) FROM stdin;
delta_dental	Delta Dental of Georgia	commercial	\N	\N
cigna	Cigna Dental	commercial	62308	\N
metlife	MetLife Dental	commercial	65978	\N
aetna_dmo	Aetna DMO	commercial	60054	\N
humana_dpo	Humana Dental PPO	commercial	73288	\N
guardian_dpo	Guardian DentalGuard PPO	commercial	64246	\N
\.


--
-- Data for Name: plans; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.plans (plan_id, payer_id, plan_type, group_number, benefit_year_start, annual_maximum, deductible, waiting_period_months, plan_name, deductible_individual, deductible_family, waiting_period_basic_months, waiting_period_major_months, waiting_period_implant_months, implant_coverage, missing_tooth_clause, benefit_pct_preventive, benefit_pct_basic, benefit_pct_major, benefit_pct_implants) FROM stdin;
delta_ppo	delta_dental	PPO	\N	\N	2000.00	100.00	12	Delta Dental PPO	100.00	300.00	6	12	12	t	t	100.00	80.00	50.00	50.00
cigna_dppo	cigna	PPO	\N	\N	2000.00	50.00	12	Cigna DPPO	50.00	150.00	6	12	12	t	f	100.00	80.00	50.00	50.00
metlife_pdp	metlife	PPO	\N	\N	1500.00	100.00	12	MetLife PDP	100.00	300.00	6	12	24	t	t	100.00	80.00	50.00	50.00
aetna_dmo	aetna_dmo	DMO	\N	\N	1500.00	0.00	12	Aetna DMO	0.00	0.00	6	12	24	f	t	100.00	80.00	50.00	0.00
humana_dppo	humana_dpo	DPPO	\N	\N	1500.00	50.00	12	Humana Dental PPO	50.00	150.00	6	12	12	t	f	100.00	80.00	50.00	50.00
guardian_dppo	guardian_dpo	DPPO	\N	\N	2000.00	100.00	12	Guardian DentalGuard PPO	100.00	300.00	6	12	12	t	t	100.00	80.00	50.00	50.00
\.


--
-- Data for Name: pred_audit_log; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.pred_audit_log (audit_id, tenant_id, pred_request_id, event_type, actor, payload, criteria_version, occurred_at, created_at) FROM stdin;
1053	tampa_smiles	PRED-SIM-TB-A01	pred_request_created	api	{"procedures": 1, "total_case_value": 1400.0}	\N	2026-08-06 13:35:18.092725+00	\N
1054	tampa_smiles	PRED-SIM-TB-B01	pred_request_created	api	{"procedures": 1, "total_case_value": 2800.0}	\N	2026-08-06 13:35:19.933487+00	\N
1055	tampa_smiles	PRED-SIM-TB-C01	pred_request_created	api	{"procedures": 2, "total_case_value": 840.0}	\N	2026-08-06 13:35:21.49022+00	\N
1056	tampa_smiles	PRED-SIM-TB-D01	pred_request_created	api	{"procedures": 1, "total_case_value": 1650.0}	\N	2026-08-06 13:35:22.924736+00	\N
1057	tampa_smiles	PRED-SIM-TB-U01	pred_request_created	api	{"procedures": 1, "total_case_value": 150.0}	\N	2026-08-06 13:35:24.523765+00	\N
437	suwanee_smiles	PRED-SIM-DA-M03	payer_response_received	payer_simulator	{"decision": "pended", "pred_number": "DD-2026-DA-M03-PND", "approved_amount": null}	\N	2026-04-06 09:00:00+00	2026-04-06 09:00:00+00
95	suwanee_smiles	PRED-SIM-DA-M04	pred_request_created	api	{"scenario_id": "DA-M04", "procedures_count": 1}	\N	2026-03-28 09:30:00+00	2026-03-28 09:30:00+00
439	suwanee_smiles	PRED-SIM-DA-M04	eligibility_verified	eligibility_assembler	{"payer_id": "delta_dental", "coverage_active": true, "annual_max_remaining": 1800.0}	\N	2026-03-28 09:30:03+00	2026-03-28 09:30:03+00
440	suwanee_smiles	PRED-SIM-DA-M04	documents_ingested	ingest_router	{"types": ["CLINICAL_NOTE", "PRED_LETTER", "XRAY_PA"], "document_count": 3}	\N	2026-03-30 09:30:00+00	2026-03-30 09:30:00+00
441	suwanee_smiles	PRED-SIM-DA-M04	clinical_evidence_assembled	clinical_assembler	{"criteria_score": 0.9, "evidence_count": 3}	\N	2026-03-30 09:30:10+00	2026-03-30 09:30:10+00
442	suwanee_smiles	PRED-SIM-DA-M04	coverage_evaluated	coverage_assembler	{"open_conditions": ["COVERAGE_PRED_REQUIRED", "ADMIN_DUPLICATE_PRED"], "has_bundling_conflict": false}	\N	2026-03-30 09:30:20+00	2026-03-30 09:30:20+00
444	suwanee_smiles	PRED-SIM-DA-M04	conditions_opened	conditions_emitter	{"count": 2, "conditions": ["COVERAGE_PRED_REQUIRED", "ADMIN_DUPLICATE_PRED"]}	\N	2026-03-30 09:30:35+00	2026-03-30 09:30:35+00
445	suwanee_smiles	PRED-SIM-DA-M04	payer_response_received	payer_simulator	{"decision": "pended", "pred_number": "DD-2026-DA-M04-PND", "approved_amount": null}	\N	2026-04-08 09:30:00+00	2026-04-08 09:30:00+00
96	suwanee_smiles	PRED-SIM-DA-M05	pred_request_created	api	{"scenario_id": "DA-M05", "procedures_count": 1}	\N	2026-03-30 10:00:00+00	2026-03-30 10:00:00+00
447	suwanee_smiles	PRED-SIM-DA-M05	eligibility_verified	eligibility_assembler	{"payer_id": "delta_dental", "coverage_active": true, "annual_max_remaining": 1800.0}	\N	2026-03-30 10:00:03+00	2026-03-30 10:00:03+00
448	suwanee_smiles	PRED-SIM-DA-M05	documents_ingested	ingest_router	{"types": ["CLINICAL_NOTE", "PRED_LETTER", "XRAY_PA"], "document_count": 3}	\N	2026-04-01 10:00:00+00	2026-04-01 10:00:00+00
449	suwanee_smiles	PRED-SIM-DA-M05	clinical_evidence_assembled	clinical_assembler	{"criteria_score": 0.4, "evidence_count": 3}	\N	2026-04-01 10:00:10+00	2026-04-01 10:00:10+00
450	suwanee_smiles	PRED-SIM-DA-M05	coverage_evaluated	coverage_assembler	{"open_conditions": ["COVERAGE_PRED_REQUIRED", "CLINICAL_XRAY_REQUIRED"], "has_bundling_conflict": false}	\N	2026-04-01 10:00:20+00	2026-04-01 10:00:20+00
451	suwanee_smiles	PRED-SIM-DA-M05	pred_state_computed	aggregation_service	{"decision": "pended", "criteria_score": 0.4}	\N	2026-04-01 10:00:30+00	2026-04-01 10:00:30+00
452	suwanee_smiles	PRED-SIM-DA-M05	conditions_opened	conditions_emitter	{"count": 2, "conditions": ["COVERAGE_PRED_REQUIRED", "CLINICAL_XRAY_REQUIRED"]}	\N	2026-04-01 10:00:35+00	2026-04-01 10:00:35+00
453	suwanee_smiles	PRED-SIM-DA-M05	payer_response_received	payer_simulator	{"decision": "pended", "pred_number": "DD-2026-DA-M05-PND", "approved_amount": null}	\N	2026-04-10 10:00:00+00	2026-04-10 10:00:00+00
736	suwanee_smiles	PRED-SIM-DA-U01	pred_request_created	api	{"scenario_id": "DA-U01", "procedures_count": 1}	\N	2026-04-02 08:00:00+00	2026-04-02 08:00:00+00
1019	suwanee_smiles	PRED-SIM-DA-U01	eligibility_verified	eligibility_assembler	{"payer_id": "delta_dental", "coverage_active": true, "annual_max_remaining": 1800.0}	\N	2026-04-02 08:00:03+00	2026-04-02 08:00:03+00
1020	suwanee_smiles	PRED-SIM-DA-U01	documents_ingested	ingest_router	{"types": ["CLINICAL_NOTE", "INSURANCE_CARD", "PRED_LETTER"], "document_count": 3}	\N	2026-04-04 08:00:00+00	2026-04-04 08:00:00+00
1021	suwanee_smiles	PRED-SIM-DA-U01	clinical_evidence_assembled	clinical_assembler	{"criteria_score": 1.0, "evidence_count": 3}	\N	2026-04-04 08:00:10+00	2026-04-04 08:00:10+00
1022	suwanee_smiles	PRED-SIM-DA-U01	coverage_evaluated	coverage_assembler	{"open_conditions": [], "has_bundling_conflict": false}	\N	2026-04-04 08:00:20+00	2026-04-04 08:00:20+00
1023	suwanee_smiles	PRED-SIM-DA-U01	pred_state_computed	aggregation_service	{"decision": "approved", "criteria_score": 1.0}	\N	2026-04-04 08:00:30+00	2026-04-04 08:00:30+00
1024	suwanee_smiles	PRED-SIM-DA-U01	payer_response_received	payer_simulator	{"decision": "approved", "pred_number": "DD-2026-DA-U01-APP", "approved_amount": 62.75}	\N	2026-04-13 08:00:00+00	2026-04-13 08:00:00+00
737	suwanee_smiles	PRED-SIM-DA-U02	pred_request_created	api	{"scenario_id": "DA-U02", "procedures_count": 1}	\N	2026-04-04 08:30:00+00	2026-04-04 08:30:00+00
1026	suwanee_smiles	PRED-SIM-DA-U02	eligibility_verified	eligibility_assembler	{"payer_id": "delta_dental", "coverage_active": true, "annual_max_remaining": 1800.0}	\N	2026-04-04 08:30:03+00	2026-04-04 08:30:03+00
1027	suwanee_smiles	PRED-SIM-DA-U02	documents_ingested	ingest_router	{"types": ["CLINICAL_NOTE", "INSURANCE_CARD", "PRED_LETTER"], "document_count": 3}	\N	2026-04-06 08:30:00+00	2026-04-06 08:30:00+00
1028	suwanee_smiles	PRED-SIM-DA-U02	clinical_evidence_assembled	clinical_assembler	{"criteria_score": 1.0, "evidence_count": 3}	\N	2026-04-06 08:30:10+00	2026-04-06 08:30:10+00
1029	suwanee_smiles	PRED-SIM-DA-U02	coverage_evaluated	coverage_assembler	{"open_conditions": [], "has_bundling_conflict": false}	\N	2026-04-06 08:30:20+00	2026-04-06 08:30:20+00
1030	suwanee_smiles	PRED-SIM-DA-U02	pred_state_computed	aggregation_service	{"decision": "approved", "criteria_score": 1.0}	\N	2026-04-06 08:30:30+00	2026-04-06 08:30:30+00
1031	suwanee_smiles	PRED-SIM-DA-U02	payer_response_received	payer_simulator	{"decision": "approved", "pred_number": "DD-2026-DA-U02-APP", "approved_amount": 26.87}	\N	2026-04-15 08:30:00+00	2026-04-15 08:30:00+00
738	suwanee_smiles	PRED-SIM-DA-U03	pred_request_created	api	{"scenario_id": "DA-U03", "procedures_count": 1}	\N	2026-04-06 09:00:00+00	2026-04-06 09:00:00+00
1033	suwanee_smiles	PRED-SIM-DA-U03	eligibility_verified	eligibility_assembler	{"payer_id": "cigna", "coverage_active": true, "annual_max_remaining": 1800.0}	\N	2026-04-06 09:00:03+00	2026-04-06 09:00:03+00
1034	suwanee_smiles	PRED-SIM-DA-U03	documents_ingested	ingest_router	{"types": ["CLINICAL_NOTE", "INSURANCE_CARD", "PRED_LETTER"], "document_count": 3}	\N	2026-04-08 09:00:00+00	2026-04-08 09:00:00+00
1058	dallas_dental	PRED-SIM-DL-A01	pred_request_created	api	{"procedures": 2, "total_case_value": 4600.0}	\N	2026-08-06 13:35:54.923203+00	\N
1059	dallas_dental	PRED-SIM-DL-B01	pred_request_created	api	{"procedures": 1, "total_case_value": 1200.0}	\N	2026-08-06 13:35:56.529971+00	\N
1060	dallas_dental	PRED-SIM-DL-C01	pred_request_created	api	{"procedures": 1, "total_case_value": 1500.0}	\N	2026-08-06 13:35:58.157978+00	\N
1061	dallas_dental	PRED-SIM-DL-D01	pred_request_created	api	{"procedures": 1, "total_case_value": 4500.0}	\N	2026-08-06 13:35:59.914726+00	\N
1062	dallas_dental	PRED-SIM-DL-U01	pred_request_created	api	{"procedures": 1, "total_case_value": 185.0}	\N	2026-08-06 13:36:01.696464+00	\N
72	suwanee_smiles	PRED-SIM-DA-A01	pred_request_created	api	{"scenario_id": "DA-A01", "procedures_count": 3}	\N	2026-01-15 08:00:00+00	2026-01-15 08:00:00+00
73	suwanee_smiles	PRED-SIM-DA-A02	pred_request_created	api	{"scenario_id": "DA-A02", "procedures_count": 1}	\N	2026-01-17 08:30:00+00	2026-01-17 08:30:00+00
74	suwanee_smiles	PRED-SIM-DA-A03	pred_request_created	api	{"scenario_id": "DA-A03", "procedures_count": 2}	\N	2026-01-19 09:00:00+00	2026-01-19 09:00:00+00
75	suwanee_smiles	PRED-SIM-DA-A04	pred_request_created	api	{"scenario_id": "DA-A04", "procedures_count": 4}	\N	2026-01-21 09:30:00+00	2026-01-21 09:30:00+00
76	suwanee_smiles	PRED-SIM-DA-A05	pred_request_created	api	{"scenario_id": "DA-A05", "procedures_count": 1}	\N	2026-01-23 10:00:00+00	2026-01-23 10:00:00+00
77	suwanee_smiles	PRED-SIM-DA-B01	pred_request_created	api	{"scenario_id": "DA-B01", "procedures_count": 2}	\N	2026-01-26 08:00:00+00	2026-01-26 08:00:00+00
219	suwanee_smiles	PRED-SIM-DA-B01	coverage_evaluated	coverage_assembler	{"open_conditions": ["ELIG_IMPLANT_NOT_COVERED"], "has_bundling_conflict": false}	\N	2026-01-28 08:00:20+00	2026-01-28 08:00:20+00
220	suwanee_smiles	PRED-SIM-DA-B01	pred_state_computed	aggregation_service	{"decision": "denied", "criteria_score": 0.7}	\N	2026-01-28 08:00:30+00	2026-01-28 08:00:30+00
221	suwanee_smiles	PRED-SIM-DA-B01	conditions_opened	conditions_emitter	{"count": 1, "conditions": ["ELIG_IMPLANT_NOT_COVERED"]}	\N	2026-01-28 08:00:35+00	2026-01-28 08:00:35+00
222	suwanee_smiles	PRED-SIM-DA-B01	payer_response_received	payer_simulator	{"decision": "denied", "pred_number": "DD-2026-DA-B01-DEN", "approved_amount": 0.0}	\N	2026-02-06 08:00:00+00	2026-02-06 08:00:00+00
78	suwanee_smiles	PRED-SIM-DA-B02	pred_request_created	api	{"scenario_id": "DA-B02", "procedures_count": 2}	\N	2026-01-28 08:30:00+00	2026-01-28 08:30:00+00
224	suwanee_smiles	PRED-SIM-DA-B02	eligibility_verified	eligibility_assembler	{"payer_id": "delta_dental", "coverage_active": true, "annual_max_remaining": 1800.0}	\N	2026-01-28 08:30:03+00	2026-01-28 08:30:03+00
225	suwanee_smiles	PRED-SIM-DA-B02	documents_ingested	ingest_router	{"types": ["INSURANCE_CARD", "PRED_LETTER", "XRAY_PA"], "document_count": 3}	\N	2026-01-30 08:30:00+00	2026-01-30 08:30:00+00
226	suwanee_smiles	PRED-SIM-DA-B02	clinical_evidence_assembled	clinical_assembler	{"criteria_score": 0.7, "evidence_count": 3}	\N	2026-01-30 08:30:10+00	2026-01-30 08:30:10+00
227	suwanee_smiles	PRED-SIM-DA-B02	coverage_evaluated	coverage_assembler	{"open_conditions": ["ELIG_MISSING_TOOTH_CLAUSE", "CLINICAL_EXTRACTION_DATE"], "has_bundling_conflict": false}	\N	2026-01-30 08:30:20+00	2026-01-30 08:30:20+00
228	suwanee_smiles	PRED-SIM-DA-B02	pred_state_computed	aggregation_service	{"decision": "denied", "criteria_score": 0.7}	\N	2026-01-30 08:30:30+00	2026-01-30 08:30:30+00
195	suwanee_smiles	PRED-SIM-DA-A03	documents_ingested	ingest_router	{"types": ["CLINICAL_NOTE", "PRED_LETTER", "XRAY_PA"], "document_count": 3}	\N	2026-01-21 09:00:00+00	2026-01-21 09:00:00+00
197	suwanee_smiles	PRED-SIM-DA-A03	coverage_evaluated	coverage_assembler	{"open_conditions": ["COVERAGE_PRED_REQUIRED"], "has_bundling_conflict": false}	\N	2026-01-21 09:00:20+00	2026-01-21 09:00:20+00
198	suwanee_smiles	PRED-SIM-DA-A03	pred_state_computed	aggregation_service	{"decision": "approved", "criteria_score": 1.0}	\N	2026-01-21 09:00:30+00	2026-01-21 09:00:30+00
199	suwanee_smiles	PRED-SIM-DA-A03	conditions_opened	conditions_emitter	{"count": 1, "conditions": ["COVERAGE_PRED_REQUIRED"]}	\N	2026-01-21 09:00:35+00	2026-01-21 09:00:35+00
200	suwanee_smiles	PRED-SIM-DA-A03	payer_response_received	payer_simulator	{"decision": "approved", "pred_number": "DD-2026-DA-A03-APP", "approved_amount": 1435.0}	\N	2026-01-30 09:00:00+00	2026-01-30 09:00:00+00
202	suwanee_smiles	PRED-SIM-DA-A04	eligibility_verified	eligibility_assembler	{"payer_id": "delta_dental", "coverage_active": true, "annual_max_remaining": 1800.0}	\N	2026-01-21 09:30:03+00	2026-01-21 09:30:03+00
203	suwanee_smiles	PRED-SIM-DA-A04	documents_ingested	ingest_router	{"types": ["CLINICAL_NOTE", "PERIO_CHART", "PRED_LETTER"], "document_count": 3}	\N	2026-01-23 09:30:00+00	2026-01-23 09:30:00+00
204	suwanee_smiles	PRED-SIM-DA-A04	clinical_evidence_assembled	clinical_assembler	{"criteria_score": 1.0, "evidence_count": 3}	\N	2026-01-23 09:30:10+00	2026-01-23 09:30:10+00
205	suwanee_smiles	PRED-SIM-DA-A04	coverage_evaluated	coverage_assembler	{"open_conditions": [], "has_bundling_conflict": false}	\N	2026-01-23 09:30:20+00	2026-01-23 09:30:20+00
206	suwanee_smiles	PRED-SIM-DA-A04	pred_state_computed	aggregation_service	{"decision": "approved", "criteria_score": 1.0}	\N	2026-01-23 09:30:30+00	2026-01-23 09:30:30+00
207	suwanee_smiles	PRED-SIM-DA-A04	payer_response_received	payer_simulator	{"decision": "approved", "pred_number": "DD-2026-DA-A04-APP", "approved_amount": 829.2}	\N	2026-02-01 09:30:00+00	2026-02-01 09:30:00+00
209	suwanee_smiles	PRED-SIM-DA-A05	eligibility_verified	eligibility_assembler	{"payer_id": "delta_dental", "coverage_active": true, "annual_max_remaining": 1800.0}	\N	2026-01-23 10:00:03+00	2026-01-23 10:00:03+00
210	suwanee_smiles	PRED-SIM-DA-A05	documents_ingested	ingest_router	{"types": ["INSURANCE_CARD", "PRED_LETTER"], "document_count": 2}	\N	2026-01-25 10:00:00+00	2026-01-25 10:00:00+00
211	suwanee_smiles	PRED-SIM-DA-A05	clinical_evidence_assembled	clinical_assembler	{"criteria_score": 1.0, "evidence_count": 2}	\N	2026-01-25 10:00:10+00	2026-01-25 10:00:10+00
212	suwanee_smiles	PRED-SIM-DA-A05	coverage_evaluated	coverage_assembler	{"open_conditions": [], "has_bundling_conflict": false}	\N	2026-01-25 10:00:20+00	2026-01-25 10:00:20+00
213	suwanee_smiles	PRED-SIM-DA-A05	pred_state_computed	aggregation_service	{"decision": "approved", "criteria_score": 1.0}	\N	2026-01-25 10:00:30+00	2026-01-25 10:00:30+00
214	suwanee_smiles	PRED-SIM-DA-A05	payer_response_received	payer_simulator	{"decision": "approved", "pred_number": "DD-2026-DA-A05-APP", "approved_amount": 158.87}	\N	2026-02-03 10:00:00+00	2026-02-03 10:00:00+00
216	suwanee_smiles	PRED-SIM-DA-B01	eligibility_verified	eligibility_assembler	{"payer_id": "delta_dental", "coverage_active": true, "annual_max_remaining": 1500.0}	\N	2026-01-26 08:00:03+00	2026-01-26 08:00:03+00
217	suwanee_smiles	PRED-SIM-DA-B01	documents_ingested	ingest_router	{"types": ["INSURANCE_CARD", "PRED_LETTER", "XRAY_PA"], "document_count": 3}	\N	2026-01-28 08:00:00+00	2026-01-28 08:00:00+00
218	suwanee_smiles	PRED-SIM-DA-B01	clinical_evidence_assembled	clinical_assembler	{"criteria_score": 0.7, "evidence_count": 3}	\N	2026-01-28 08:00:10+00	2026-01-28 08:00:10+00
229	suwanee_smiles	PRED-SIM-DA-B02	conditions_opened	conditions_emitter	{"count": 2, "conditions": ["ELIG_MISSING_TOOTH_CLAUSE", "CLINICAL_EXTRACTION_DATE"]}	\N	2026-01-30 08:30:35+00	2026-01-30 08:30:35+00
230	suwanee_smiles	PRED-SIM-DA-B02	payer_response_received	payer_simulator	{"decision": "denied", "pred_number": "DD-2026-DA-B02-DEN", "approved_amount": 0.0}	\N	2026-02-08 08:30:00+00	2026-02-08 08:30:00+00
79	suwanee_smiles	PRED-SIM-DA-B03	pred_request_created	api	{"scenario_id": "DA-B03", "procedures_count": 1}	\N	2026-01-30 09:00:00+00	2026-01-30 09:00:00+00
232	suwanee_smiles	PRED-SIM-DA-B03	eligibility_verified	eligibility_assembler	{"payer_id": "delta_dental", "coverage_active": true, "annual_max_remaining": 1800.0}	\N	2026-01-30 09:00:03+00	2026-01-30 09:00:03+00
233	suwanee_smiles	PRED-SIM-DA-B03	documents_ingested	ingest_router	{"types": ["INSURANCE_CARD", "PRED_LETTER", "XRAY_PA"], "document_count": 3}	\N	2026-02-01 09:00:00+00	2026-02-01 09:00:00+00
234	suwanee_smiles	PRED-SIM-DA-B03	clinical_evidence_assembled	clinical_assembler	{"criteria_score": 0.6, "evidence_count": 3}	\N	2026-02-01 09:00:10+00	2026-02-01 09:00:10+00
235	suwanee_smiles	PRED-SIM-DA-B03	coverage_evaluated	coverage_assembler	{"open_conditions": ["ELIG_FREQUENCY_LIMIT", "CLINICAL_NARRATIVE_REQUIRED"], "has_bundling_conflict": false}	\N	2026-02-01 09:00:20+00	2026-02-01 09:00:20+00
236	suwanee_smiles	PRED-SIM-DA-B03	pred_state_computed	aggregation_service	{"decision": "denied", "criteria_score": 0.6}	\N	2026-02-01 09:00:30+00	2026-02-01 09:00:30+00
237	suwanee_smiles	PRED-SIM-DA-B03	conditions_opened	conditions_emitter	{"count": 2, "conditions": ["ELIG_FREQUENCY_LIMIT", "CLINICAL_NARRATIVE_REQUIRED"]}	\N	2026-02-01 09:00:35+00	2026-02-01 09:00:35+00
238	suwanee_smiles	PRED-SIM-DA-B03	payer_response_received	payer_simulator	{"decision": "denied", "pred_number": "DD-2026-DA-B03-DEN", "approved_amount": 0.0}	\N	2026-02-10 09:00:00+00	2026-02-10 09:00:00+00
80	suwanee_smiles	PRED-SIM-DA-B04	pred_request_created	api	{"scenario_id": "DA-B04", "procedures_count": 2}	\N	2026-02-01 09:30:00+00	2026-02-01 09:30:00+00
240	suwanee_smiles	PRED-SIM-DA-B04	eligibility_verified	eligibility_assembler	{"payer_id": "delta_dental", "coverage_active": true, "annual_max_remaining": 1800.0}	\N	2026-02-01 09:30:03+00	2026-02-01 09:30:03+00
241	suwanee_smiles	PRED-SIM-DA-B04	documents_ingested	ingest_router	{"types": ["CLINICAL_NOTE", "PRED_LETTER", "XRAY_PA"], "document_count": 3}	\N	2026-02-03 09:30:00+00	2026-02-03 09:30:00+00
242	suwanee_smiles	PRED-SIM-DA-B04	clinical_evidence_assembled	clinical_assembler	{"criteria_score": 0.85, "evidence_count": 3}	\N	2026-02-03 09:30:10+00	2026-02-03 09:30:10+00
243	suwanee_smiles	PRED-SIM-DA-B04	coverage_evaluated	coverage_assembler	{"open_conditions": ["COVERAGE_PRED_REQUIRED", "COVERAGE_BUNDLING_CONFLICT", "CLINICAL_XRAY_REQUIRED", "CLINICAL_NARRATIVE_REQUIRED"], "has_bundling_conflict": true}	\N	2026-02-03 09:30:20+00	2026-02-03 09:30:20+00
244	suwanee_smiles	PRED-SIM-DA-B04	pred_state_computed	aggregation_service	{"decision": "pended", "criteria_score": 0.85}	\N	2026-02-03 09:30:30+00	2026-02-03 09:30:30+00
245	suwanee_smiles	PRED-SIM-DA-B04	conditions_opened	conditions_emitter	{"count": 4, "conditions": ["COVERAGE_PRED_REQUIRED", "COVERAGE_BUNDLING_CONFLICT", "CLINICAL_XRAY_REQUIRED", "CLINICAL_NARRATIVE_REQUIRED"]}	\N	2026-02-03 09:30:35+00	2026-02-03 09:30:35+00
246	suwanee_smiles	PRED-SIM-DA-B04	payer_response_received	payer_simulator	{"decision": "pended", "pred_number": "DD-2026-DA-B04-PND", "approved_amount": null}	\N	2026-02-12 09:30:00+00	2026-02-12 09:30:00+00
81	suwanee_smiles	PRED-SIM-DA-B05	pred_request_created	api	{"scenario_id": "DA-B05", "procedures_count": 1}	\N	2026-02-03 10:00:00+00	2026-02-03 10:00:00+00
248	suwanee_smiles	PRED-SIM-DA-B05	eligibility_verified	eligibility_assembler	{"payer_id": "delta_dental", "coverage_active": true, "annual_max_remaining": 1800.0}	\N	2026-02-03 10:00:03+00	2026-02-03 10:00:03+00
249	suwanee_smiles	PRED-SIM-DA-B05	documents_ingested	ingest_router	{"types": ["INSURANCE_CARD", "PRED_LETTER", "XRAY_PA"], "document_count": 3}	\N	2026-02-05 10:00:00+00	2026-02-05 10:00:00+00
250	suwanee_smiles	PRED-SIM-DA-B05	clinical_evidence_assembled	clinical_assembler	{"criteria_score": 0.6, "evidence_count": 3}	\N	2026-02-05 10:00:10+00	2026-02-05 10:00:10+00
251	suwanee_smiles	PRED-SIM-DA-B05	coverage_evaluated	coverage_assembler	{"open_conditions": ["ELIG_WAITING_PERIOD_NOT_MET", "CLINICAL_NARRATIVE_REQUIRED"], "has_bundling_conflict": false}	\N	2026-02-05 10:00:20+00	2026-02-05 10:00:20+00
252	suwanee_smiles	PRED-SIM-DA-B05	pred_state_computed	aggregation_service	{"decision": "denied", "criteria_score": 0.6}	\N	2026-02-05 10:00:30+00	2026-02-05 10:00:30+00
253	suwanee_smiles	PRED-SIM-DA-B05	conditions_opened	conditions_emitter	{"count": 2, "conditions": ["ELIG_WAITING_PERIOD_NOT_MET", "CLINICAL_NARRATIVE_REQUIRED"]}	\N	2026-02-05 10:00:35+00	2026-02-05 10:00:35+00
254	suwanee_smiles	PRED-SIM-DA-B05	payer_response_received	payer_simulator	{"decision": "denied", "pred_number": "DD-2026-DA-B05-DEN", "approved_amount": 0.0}	\N	2026-02-14 10:00:00+00	2026-02-14 10:00:00+00
82	suwanee_smiles	PRED-SIM-DA-C01	pred_request_created	api	{"scenario_id": "DA-C01", "procedures_count": 2}	\N	2026-02-06 08:00:00+00	2026-02-06 08:00:00+00
256	suwanee_smiles	PRED-SIM-DA-C01	eligibility_verified	eligibility_assembler	{"payer_id": "delta_dental", "coverage_active": true, "annual_max_remaining": 1800.0}	\N	2026-02-06 08:00:03+00	2026-02-06 08:00:03+00
257	suwanee_smiles	PRED-SIM-DA-C01	documents_ingested	ingest_router	{"types": ["CLINICAL_NOTE", "PRED_LETTER"], "document_count": 2}	\N	2026-02-08 08:00:00+00	2026-02-08 08:00:00+00
258	suwanee_smiles	PRED-SIM-DA-C01	clinical_evidence_assembled	clinical_assembler	{"criteria_score": 0.25, "evidence_count": 2}	\N	2026-02-08 08:00:10+00	2026-02-08 08:00:10+00
259	suwanee_smiles	PRED-SIM-DA-C01	coverage_evaluated	coverage_assembler	{"open_conditions": ["COVERAGE_PRED_REQUIRED", "CLINICAL_CRITERIA_NOT_MET", "COVERAGE_BUNDLING_CONFLICT", "CLINICAL_XRAY_REQUIRED", "CLINICAL_NARRATIVE_REQUIRED", "CLINICAL_BONE_LOSS_THRESHOLD"], "has_bundling_conflict": true}	\N	2026-02-08 08:00:20+00	2026-02-08 08:00:20+00
260	suwanee_smiles	PRED-SIM-DA-C01	pred_state_computed	aggregation_service	{"decision": "pended", "criteria_score": 0.25}	\N	2026-02-08 08:00:30+00	2026-02-08 08:00:30+00
261	suwanee_smiles	PRED-SIM-DA-C01	conditions_opened	conditions_emitter	{"count": 6, "conditions": ["COVERAGE_PRED_REQUIRED", "CLINICAL_CRITERIA_NOT_MET", "COVERAGE_BUNDLING_CONFLICT", "CLINICAL_XRAY_REQUIRED", "CLINICAL_NARRATIVE_REQUIRED", "CLINICAL_BONE_LOSS_THRESHOLD"]}	\N	2026-02-08 08:00:35+00	2026-02-08 08:00:35+00
262	suwanee_smiles	PRED-SIM-DA-C01	payer_response_received	payer_simulator	{"decision": "pended", "pred_number": "DD-2026-DA-C01-PND", "approved_amount": null}	\N	2026-02-17 08:00:00+00	2026-02-17 08:00:00+00
83	suwanee_smiles	PRED-SIM-DA-C02	pred_request_created	api	{"scenario_id": "DA-C02", "procedures_count": 1}	\N	2026-02-08 08:30:00+00	2026-02-08 08:30:00+00
264	suwanee_smiles	PRED-SIM-DA-C02	eligibility_verified	eligibility_assembler	{"payer_id": "delta_dental", "coverage_active": true, "annual_max_remaining": 1800.0}	\N	2026-02-08 08:30:03+00	2026-02-08 08:30:03+00
265	suwanee_smiles	PRED-SIM-DA-C02	documents_ingested	ingest_router	{"types": ["CLINICAL_NOTE", "PRED_LETTER", "XRAY_PA"], "document_count": 3}	\N	2026-02-10 08:30:00+00	2026-02-10 08:30:00+00
266	suwanee_smiles	PRED-SIM-DA-C02	clinical_evidence_assembled	clinical_assembler	{"criteria_score": 0.1, "evidence_count": 3}	\N	2026-02-10 08:30:10+00	2026-02-10 08:30:10+00
267	suwanee_smiles	PRED-SIM-DA-C02	coverage_evaluated	coverage_assembler	{"open_conditions": ["COVERAGE_PRED_REQUIRED", "CLINICAL_CRITERIA_NOT_MET", "CLINICAL_POCKET_DEPTH", "CLINICAL_BONE_LOSS_THRESHOLD", "CLINICAL_PERIO_CHART_REQUIRED"], "has_bundling_conflict": false}	\N	2026-02-10 08:30:20+00	2026-02-10 08:30:20+00
268	suwanee_smiles	PRED-SIM-DA-C02	pred_state_computed	aggregation_service	{"decision": "pended", "criteria_score": 0.1}	\N	2026-02-10 08:30:30+00	2026-02-10 08:30:30+00
1035	suwanee_smiles	PRED-SIM-DA-U03	clinical_evidence_assembled	clinical_assembler	{"criteria_score": 1.0, "evidence_count": 3}	\N	2026-04-08 09:00:10+00	2026-04-08 09:00:10+00
269	suwanee_smiles	PRED-SIM-DA-C02	conditions_opened	conditions_emitter	{"count": 5, "conditions": ["COVERAGE_PRED_REQUIRED", "CLINICAL_CRITERIA_NOT_MET", "CLINICAL_POCKET_DEPTH", "CLINICAL_BONE_LOSS_THRESHOLD", "CLINICAL_PERIO_CHART_REQUIRED"]}	\N	2026-02-10 08:30:35+00	2026-02-10 08:30:35+00
270	suwanee_smiles	PRED-SIM-DA-C02	payer_response_received	payer_simulator	{"decision": "pended", "pred_number": "DD-2026-DA-C02-PND", "approved_amount": null}	\N	2026-02-19 08:30:00+00	2026-02-19 08:30:00+00
84	suwanee_smiles	PRED-SIM-DA-C03	pred_request_created	api	{"scenario_id": "DA-C03", "procedures_count": 8}	\N	2026-02-10 09:00:00+00	2026-02-10 09:00:00+00
272	suwanee_smiles	PRED-SIM-DA-C03	eligibility_verified	eligibility_assembler	{"payer_id": "delta_dental", "coverage_active": true, "annual_max_remaining": 1800.0}	\N	2026-02-10 09:00:03+00	2026-02-10 09:00:03+00
273	suwanee_smiles	PRED-SIM-DA-C03	documents_ingested	ingest_router	{"types": ["CLINICAL_NOTE", "PRED_LETTER", "XRAY_PAN"], "document_count": 3}	\N	2026-02-12 09:00:00+00	2026-02-12 09:00:00+00
274	suwanee_smiles	PRED-SIM-DA-C03	clinical_evidence_assembled	clinical_assembler	{"criteria_score": 0.9, "evidence_count": 3}	\N	2026-02-12 09:00:10+00	2026-02-12 09:00:10+00
275	suwanee_smiles	PRED-SIM-DA-C03	coverage_evaluated	coverage_assembler	{"open_conditions": ["COVERAGE_PRED_REQUIRED", "CLINICAL_CBCT_REQUIRED", "COVERAGE_DOWNGRADE_APPLIED"], "has_bundling_conflict": false}	\N	2026-02-12 09:00:20+00	2026-02-12 09:00:20+00
276	suwanee_smiles	PRED-SIM-DA-C03	pred_state_computed	aggregation_service	{"decision": "pended", "criteria_score": 0.9}	\N	2026-02-12 09:00:30+00	2026-02-12 09:00:30+00
277	suwanee_smiles	PRED-SIM-DA-C03	conditions_opened	conditions_emitter	{"count": 3, "conditions": ["COVERAGE_PRED_REQUIRED", "CLINICAL_CBCT_REQUIRED", "COVERAGE_DOWNGRADE_APPLIED"]}	\N	2026-02-12 09:00:35+00	2026-02-12 09:00:35+00
278	suwanee_smiles	PRED-SIM-DA-C03	payer_response_received	payer_simulator	{"decision": "pended", "pred_number": "DD-2026-DA-C03-PND", "approved_amount": null}	\N	2026-02-21 09:00:00+00	2026-02-21 09:00:00+00
85	suwanee_smiles	PRED-SIM-DA-C04	pred_request_created	api	{"scenario_id": "DA-C04", "procedures_count": 1}	\N	2026-02-12 09:30:00+00	2026-02-12 09:30:00+00
280	suwanee_smiles	PRED-SIM-DA-C04	eligibility_verified	eligibility_assembler	{"payer_id": "delta_dental", "coverage_active": true, "annual_max_remaining": 1800.0}	\N	2026-02-12 09:30:03+00	2026-02-12 09:30:03+00
281	suwanee_smiles	PRED-SIM-DA-C04	documents_ingested	ingest_router	{"types": ["CLINICAL_NOTE", "PRED_LETTER"], "document_count": 2}	\N	2026-02-14 09:30:00+00	2026-02-14 09:30:00+00
282	suwanee_smiles	PRED-SIM-DA-C04	clinical_evidence_assembled	clinical_assembler	{"criteria_score": 0.4, "evidence_count": 2}	\N	2026-02-14 09:30:10+00	2026-02-14 09:30:10+00
283	suwanee_smiles	PRED-SIM-DA-C04	coverage_evaluated	coverage_assembler	{"open_conditions": ["COVERAGE_PRED_REQUIRED", "CLINICAL_XRAY_REQUIRED"], "has_bundling_conflict": false}	\N	2026-02-14 09:30:20+00	2026-02-14 09:30:20+00
284	suwanee_smiles	PRED-SIM-DA-C04	pred_state_computed	aggregation_service	{"decision": "pended", "criteria_score": 0.4}	\N	2026-02-14 09:30:30+00	2026-02-14 09:30:30+00
285	suwanee_smiles	PRED-SIM-DA-C04	conditions_opened	conditions_emitter	{"count": 2, "conditions": ["COVERAGE_PRED_REQUIRED", "CLINICAL_XRAY_REQUIRED"]}	\N	2026-02-14 09:30:35+00	2026-02-14 09:30:35+00
286	suwanee_smiles	PRED-SIM-DA-C04	payer_response_received	payer_simulator	{"decision": "pended", "pred_number": "DD-2026-DA-C04-PND", "approved_amount": null}	\N	2026-02-23 09:30:00+00	2026-02-23 09:30:00+00
86	suwanee_smiles	PRED-SIM-DA-C05	pred_request_created	api	{"scenario_id": "DA-C05", "procedures_count": 1}	\N	2026-02-14 10:00:00+00	2026-02-14 10:00:00+00
288	suwanee_smiles	PRED-SIM-DA-C05	eligibility_verified	eligibility_assembler	{"payer_id": "delta_dental", "coverage_active": true, "annual_max_remaining": 1800.0}	\N	2026-02-14 10:00:03+00	2026-02-14 10:00:03+00
289	suwanee_smiles	PRED-SIM-DA-C05	documents_ingested	ingest_router	{"types": ["CLINICAL_NOTE", "INSURANCE_CARD", "PRED_LETTER", "XRAY_PA"], "document_count": 4}	\N	2026-02-16 10:00:00+00	2026-02-16 10:00:00+00
290	suwanee_smiles	PRED-SIM-DA-C05	clinical_evidence_assembled	clinical_assembler	{"criteria_score": 1.0, "evidence_count": 4}	\N	2026-02-16 10:00:10+00	2026-02-16 10:00:10+00
291	suwanee_smiles	PRED-SIM-DA-C05	coverage_evaluated	coverage_assembler	{"open_conditions": ["COVERAGE_PRED_REQUIRED", "ELIG_COB_REQUIRED", "ADMIN_COB_PRIMARY_FIRST"], "has_bundling_conflict": false}	\N	2026-02-16 10:00:20+00	2026-02-16 10:00:20+00
292	suwanee_smiles	PRED-SIM-DA-C05	pred_state_computed	aggregation_service	{"decision": "pended", "criteria_score": 1.0}	\N	2026-02-16 10:00:30+00	2026-02-16 10:00:30+00
293	suwanee_smiles	PRED-SIM-DA-C05	conditions_opened	conditions_emitter	{"count": 3, "conditions": ["COVERAGE_PRED_REQUIRED", "ELIG_COB_REQUIRED", "ADMIN_COB_PRIMARY_FIRST"]}	\N	2026-02-16 10:00:35+00	2026-02-16 10:00:35+00
294	suwanee_smiles	PRED-SIM-DA-C05	payer_response_received	payer_simulator	{"decision": "pended", "pred_number": "DD-2026-DA-C05-PND", "approved_amount": null}	\N	2026-02-25 10:00:00+00	2026-02-25 10:00:00+00
102	suwanee_smiles	PRED-SIM-DA-C06	pred_request_created	api	{"scenario_id": "DA-C06", "procedures_count": 1}	\N	2026-02-17 08:00:00+00	2026-02-17 08:00:00+00
296	suwanee_smiles	PRED-SIM-DA-C06	eligibility_verified	eligibility_assembler	{"payer_id": "cigna", "coverage_active": true, "annual_max_remaining": 1800.0}	\N	2026-02-17 08:00:03+00	2026-02-17 08:00:03+00
297	suwanee_smiles	PRED-SIM-DA-C06	documents_ingested	ingest_router	{"types": ["CLINICAL_NOTE", "PRED_LETTER", "XRAY_PA"], "document_count": 3}	\N	2026-02-19 08:00:00+00	2026-02-19 08:00:00+00
298	suwanee_smiles	PRED-SIM-DA-C06	clinical_evidence_assembled	clinical_assembler	{"criteria_score": 1.0, "evidence_count": 3}	\N	2026-02-19 08:00:10+00	2026-02-19 08:00:10+00
299	suwanee_smiles	PRED-SIM-DA-C06	coverage_evaluated	coverage_assembler	{"open_conditions": ["COVERAGE_PRED_REQUIRED"], "has_bundling_conflict": false}	\N	2026-02-19 08:00:20+00	2026-02-19 08:00:20+00
300	suwanee_smiles	PRED-SIM-DA-C06	pred_state_computed	aggregation_service	{"decision": "approved", "criteria_score": 1.0}	\N	2026-02-19 08:00:30+00	2026-02-19 08:00:30+00
301	suwanee_smiles	PRED-SIM-DA-C06	conditions_opened	conditions_emitter	{"count": 1, "conditions": ["COVERAGE_PRED_REQUIRED"]}	\N	2026-02-19 08:00:35+00	2026-02-19 08:00:35+00
302	suwanee_smiles	PRED-SIM-DA-C06	payer_response_received	payer_simulator	{"decision": "approved", "pred_number": "DD-2026-DA-C06-APP", "approved_amount": 631.25}	\N	2026-02-28 08:00:00+00	2026-02-28 08:00:00+00
103	suwanee_smiles	PRED-SIM-DA-C07	pred_request_created	api	{"scenario_id": "DA-C07", "procedures_count": 1}	\N	2026-02-19 08:30:00+00	2026-02-19 08:30:00+00
304	suwanee_smiles	PRED-SIM-DA-C07	eligibility_verified	eligibility_assembler	{"payer_id": "metlife", "coverage_active": true, "annual_max_remaining": 1800.0}	\N	2026-02-19 08:30:03+00	2026-02-19 08:30:03+00
305	suwanee_smiles	PRED-SIM-DA-C07	documents_ingested	ingest_router	{"types": ["INSURANCE_CARD", "PRED_LETTER"], "document_count": 2}	\N	2026-02-21 08:30:00+00	2026-02-21 08:30:00+00
306	suwanee_smiles	PRED-SIM-DA-C07	clinical_evidence_assembled	clinical_assembler	{"criteria_score": 1.0, "evidence_count": 2}	\N	2026-02-21 08:30:10+00	2026-02-21 08:30:10+00
307	suwanee_smiles	PRED-SIM-DA-C07	coverage_evaluated	coverage_assembler	{"open_conditions": [], "has_bundling_conflict": false}	\N	2026-02-21 08:30:20+00	2026-02-21 08:30:20+00
308	suwanee_smiles	PRED-SIM-DA-C07	pred_state_computed	aggregation_service	{"decision": "approved", "criteria_score": 1.0}	\N	2026-02-21 08:30:30+00	2026-02-21 08:30:30+00
309	suwanee_smiles	PRED-SIM-DA-C07	payer_response_received	payer_simulator	{"decision": "approved", "pred_number": "DD-2026-DA-C07-APP", "approved_amount": 105.7}	\N	2026-03-02 08:30:00+00	2026-03-02 08:30:00+00
104	suwanee_smiles	PRED-SIM-DA-C08	pred_request_created	api	{"scenario_id": "DA-C08", "procedures_count": 1}	\N	2026-02-21 09:00:00+00	2026-02-21 09:00:00+00
311	suwanee_smiles	PRED-SIM-DA-C08	eligibility_verified	eligibility_assembler	{"payer_id": "delta_dental", "coverage_active": true, "annual_max_remaining": 1500.0}	\N	2026-02-21 09:00:03+00	2026-02-21 09:00:03+00
312	suwanee_smiles	PRED-SIM-DA-C08	documents_ingested	ingest_router	{"types": ["CLINICAL_NOTE", "INSURANCE_CARD", "PRED_LETTER", "XRAY_PA"], "document_count": 4}	\N	2026-02-23 09:00:00+00	2026-02-23 09:00:00+00
313	suwanee_smiles	PRED-SIM-DA-C08	clinical_evidence_assembled	clinical_assembler	{"criteria_score": 1.0, "evidence_count": 4}	\N	2026-02-23 09:00:10+00	2026-02-23 09:00:10+00
314	suwanee_smiles	PRED-SIM-DA-C08	coverage_evaluated	coverage_assembler	{"open_conditions": ["COVERAGE_PRED_REQUIRED", "ELIG_COB_REQUIRED", "ADMIN_COB_PRIMARY_FIRST"], "has_bundling_conflict": false}	\N	2026-02-23 09:00:20+00	2026-02-23 09:00:20+00
315	suwanee_smiles	PRED-SIM-DA-C08	pred_state_computed	aggregation_service	{"decision": "pended", "criteria_score": 1.0}	\N	2026-02-23 09:00:30+00	2026-02-23 09:00:30+00
316	suwanee_smiles	PRED-SIM-DA-C08	conditions_opened	conditions_emitter	{"count": 3, "conditions": ["COVERAGE_PRED_REQUIRED", "ELIG_COB_REQUIRED", "ADMIN_COB_PRIMARY_FIRST"]}	\N	2026-02-23 09:00:35+00	2026-02-23 09:00:35+00
317	suwanee_smiles	PRED-SIM-DA-C08	payer_response_received	payer_simulator	{"decision": "pended", "pred_number": "DD-2026-DA-C08-PND", "approved_amount": null}	\N	2026-03-04 09:00:00+00	2026-03-04 09:00:00+00
105	suwanee_smiles	PRED-SIM-DA-C09	pred_request_created	api	{"scenario_id": "DA-C09", "procedures_count": 1}	\N	2026-02-23 09:30:00+00	2026-02-23 09:30:00+00
319	suwanee_smiles	PRED-SIM-DA-C09	eligibility_verified	eligibility_assembler	{"payer_id": "delta_dental", "coverage_active": true, "annual_max_remaining": 1800.0}	\N	2026-02-23 09:30:03+00	2026-02-23 09:30:03+00
320	suwanee_smiles	PRED-SIM-DA-C09	documents_ingested	ingest_router	{"types": ["CLINICAL_NOTE", "PRED_LETTER", "XRAY_PA"], "document_count": 3}	\N	2026-02-25 09:30:00+00	2026-02-25 09:30:00+00
321	suwanee_smiles	PRED-SIM-DA-C09	clinical_evidence_assembled	clinical_assembler	{"criteria_score": 0.9, "evidence_count": 3}	\N	2026-02-25 09:30:10+00	2026-02-25 09:30:10+00
322	suwanee_smiles	PRED-SIM-DA-C09	coverage_evaluated	coverage_assembler	{"open_conditions": ["COVERAGE_PRED_REQUIRED", "CLINICAL_MEDICAL_HISTORY_FLAG"], "has_bundling_conflict": false}	\N	2026-02-25 09:30:20+00	2026-02-25 09:30:20+00
323	suwanee_smiles	PRED-SIM-DA-C09	pred_state_computed	aggregation_service	{"decision": "pended", "criteria_score": 0.9}	\N	2026-02-25 09:30:30+00	2026-02-25 09:30:30+00
324	suwanee_smiles	PRED-SIM-DA-C09	conditions_opened	conditions_emitter	{"count": 2, "conditions": ["COVERAGE_PRED_REQUIRED", "CLINICAL_MEDICAL_HISTORY_FLAG"]}	\N	2026-02-25 09:30:35+00	2026-02-25 09:30:35+00
325	suwanee_smiles	PRED-SIM-DA-C09	payer_response_received	payer_simulator	{"decision": "pended", "pred_number": "DD-2026-DA-C09-PND", "approved_amount": null}	\N	2026-03-06 09:30:00+00	2026-03-06 09:30:00+00
106	suwanee_smiles	PRED-SIM-DA-C10	pred_request_created	api	{"scenario_id": "DA-C10", "procedures_count": 1}	\N	2026-02-25 10:00:00+00	2026-02-25 10:00:00+00
327	suwanee_smiles	PRED-SIM-DA-C10	eligibility_verified	eligibility_assembler	{"payer_id": "delta_dental", "coverage_active": true, "annual_max_remaining": 1800.0}	\N	2026-02-25 10:00:03+00	2026-02-25 10:00:03+00
328	suwanee_smiles	PRED-SIM-DA-C10	documents_ingested	ingest_router	{"types": ["CLINICAL_NOTE", "PRED_LETTER", "XRAY_PA"], "document_count": 3}	\N	2026-02-27 10:00:00+00	2026-02-27 10:00:00+00
329	suwanee_smiles	PRED-SIM-DA-C10	clinical_evidence_assembled	clinical_assembler	{"criteria_score": 1.0, "evidence_count": 3}	\N	2026-02-27 10:00:10+00	2026-02-27 10:00:10+00
330	suwanee_smiles	PRED-SIM-DA-C10	coverage_evaluated	coverage_assembler	{"open_conditions": ["COVERAGE_PRED_REQUIRED", "PROVIDER_OIG_EXCLUDED"], "has_bundling_conflict": false}	\N	2026-02-27 10:00:20+00	2026-02-27 10:00:20+00
331	suwanee_smiles	PRED-SIM-DA-C10	pred_state_computed	aggregation_service	{"decision": "pended", "criteria_score": 1.0}	\N	2026-02-27 10:00:30+00	2026-02-27 10:00:30+00
332	suwanee_smiles	PRED-SIM-DA-C10	conditions_opened	conditions_emitter	{"count": 2, "conditions": ["COVERAGE_PRED_REQUIRED", "PROVIDER_OIG_EXCLUDED"]}	\N	2026-02-27 10:00:35+00	2026-02-27 10:00:35+00
333	suwanee_smiles	PRED-SIM-DA-C10	payer_response_received	payer_simulator	{"decision": "pended", "pred_number": "DD-2026-DA-C10-PND", "approved_amount": null}	\N	2026-03-08 10:00:00+00	2026-03-08 10:00:00+00
87	suwanee_smiles	PRED-SIM-DA-D01	pred_request_created	api	{"scenario_id": "DA-D01", "procedures_count": 3}	\N	2026-02-28 08:00:00+00	2026-02-28 08:00:00+00
335	suwanee_smiles	PRED-SIM-DA-D01	eligibility_verified	eligibility_assembler	{"payer_id": "delta_dental", "coverage_active": true, "annual_max_remaining": 1800.0}	\N	2026-02-28 08:00:03+00	2026-02-28 08:00:03+00
336	suwanee_smiles	PRED-SIM-DA-D01	documents_ingested	ingest_router	{"types": ["CLINICAL_NOTE", "PERIO_CHART", "PRED_LETTER", "XRAY_PA"], "document_count": 4}	\N	2026-03-02 08:00:00+00	2026-03-02 08:00:00+00
337	suwanee_smiles	PRED-SIM-DA-D01	clinical_evidence_assembled	clinical_assembler	{"criteria_score": 0.9, "evidence_count": 4}	\N	2026-03-02 08:00:10+00	2026-03-02 08:00:10+00
338	suwanee_smiles	PRED-SIM-DA-D01	coverage_evaluated	coverage_assembler	{"open_conditions": ["COVERAGE_PRED_REQUIRED", "PROVIDER_OUT_OF_NETWORK", "COVERAGE_BUNDLING_CONFLICT", "CLINICAL_XRAY_REQUIRED", "CLINICAL_NARRATIVE_REQUIRED"], "has_bundling_conflict": true}	\N	2026-03-02 08:00:20+00	2026-03-02 08:00:20+00
339	suwanee_smiles	PRED-SIM-DA-D01	pred_state_computed	aggregation_service	{"decision": "pended", "criteria_score": 0.9}	\N	2026-03-02 08:00:30+00	2026-03-02 08:00:30+00
340	suwanee_smiles	PRED-SIM-DA-D01	conditions_opened	conditions_emitter	{"count": 5, "conditions": ["COVERAGE_PRED_REQUIRED", "PROVIDER_OUT_OF_NETWORK", "COVERAGE_BUNDLING_CONFLICT", "CLINICAL_XRAY_REQUIRED", "CLINICAL_NARRATIVE_REQUIRED"]}	\N	2026-03-02 08:00:35+00	2026-03-02 08:00:35+00
341	suwanee_smiles	PRED-SIM-DA-D01	payer_response_received	payer_simulator	{"decision": "pended", "pred_number": "DD-2026-DA-D01-PND", "approved_amount": null}	\N	2026-03-11 08:00:00+00	2026-03-11 08:00:00+00
88	suwanee_smiles	PRED-SIM-DA-D02	pred_request_created	api	{"scenario_id": "DA-D02", "procedures_count": 12}	\N	2026-03-02 08:30:00+00	2026-03-02 08:30:00+00
343	suwanee_smiles	PRED-SIM-DA-D02	eligibility_verified	eligibility_assembler	{"payer_id": "delta_dental", "coverage_active": true, "annual_max_remaining": 1800.0}	\N	2026-03-02 08:30:03+00	2026-03-02 08:30:03+00
344	suwanee_smiles	PRED-SIM-DA-D02	documents_ingested	ingest_router	{"types": ["CBCT_REPORT", "CLINICAL_NOTE", "PRED_LETTER", "XRAY_PAN"], "document_count": 4}	\N	2026-03-04 08:30:00+00	2026-03-04 08:30:00+00
345	suwanee_smiles	PRED-SIM-DA-D02	clinical_evidence_assembled	clinical_assembler	{"criteria_score": 1.0, "evidence_count": 4}	\N	2026-03-04 08:30:10+00	2026-03-04 08:30:10+00
346	suwanee_smiles	PRED-SIM-DA-D02	coverage_evaluated	coverage_assembler	{"open_conditions": ["COVERAGE_PRED_REQUIRED", "COVERAGE_BUNDLING_CONFLICT", "CLINICAL_XRAY_REQUIRED", "CLINICAL_NARRATIVE_REQUIRED", "COVERAGE_DOWNGRADE_APPLIED", "CLINICAL_CRITERIA_NOT_MET"], "has_bundling_conflict": true}	\N	2026-03-04 08:30:20+00	2026-03-04 08:30:20+00
347	suwanee_smiles	PRED-SIM-DA-D02	pred_state_computed	aggregation_service	{"decision": "pended", "criteria_score": 1.0}	\N	2026-03-04 08:30:30+00	2026-03-04 08:30:30+00
348	suwanee_smiles	PRED-SIM-DA-D02	conditions_opened	conditions_emitter	{"count": 6, "conditions": ["COVERAGE_PRED_REQUIRED", "COVERAGE_BUNDLING_CONFLICT", "CLINICAL_XRAY_REQUIRED", "CLINICAL_NARRATIVE_REQUIRED", "COVERAGE_DOWNGRADE_APPLIED", "CLINICAL_CRITERIA_NOT_MET"]}	\N	2026-03-04 08:30:35+00	2026-03-04 08:30:35+00
349	suwanee_smiles	PRED-SIM-DA-D02	payer_response_received	payer_simulator	{"decision": "pended", "pred_number": "DD-2026-DA-D02-PND", "approved_amount": null}	\N	2026-03-13 08:30:00+00	2026-03-13 08:30:00+00
89	suwanee_smiles	PRED-SIM-DA-D03	pred_request_created	api	{"scenario_id": "DA-D03", "procedures_count": 2}	\N	2026-03-04 09:00:00+00	2026-03-04 09:00:00+00
351	suwanee_smiles	PRED-SIM-DA-D03	eligibility_verified	eligibility_assembler	{"payer_id": "delta_dental", "coverage_active": true, "annual_max_remaining": 1800.0}	\N	2026-03-04 09:00:03+00	2026-03-04 09:00:03+00
352	suwanee_smiles	PRED-SIM-DA-D03	documents_ingested	ingest_router	{"types": ["CLINICAL_NOTE", "PRED_LETTER", "XRAY_PA"], "document_count": 3}	\N	2026-03-06 09:00:00+00	2026-03-06 09:00:00+00
353	suwanee_smiles	PRED-SIM-DA-D03	clinical_evidence_assembled	clinical_assembler	{"criteria_score": 0.9, "evidence_count": 3}	\N	2026-03-06 09:00:10+00	2026-03-06 09:00:10+00
354	suwanee_smiles	PRED-SIM-DA-D03	coverage_evaluated	coverage_assembler	{"open_conditions": ["ELIG_WAITING_PERIOD_NOT_MET"], "has_bundling_conflict": false}	\N	2026-03-06 09:00:20+00	2026-03-06 09:00:20+00
355	suwanee_smiles	PRED-SIM-DA-D03	pred_state_computed	aggregation_service	{"decision": "denied", "criteria_score": 0.9}	\N	2026-03-06 09:00:30+00	2026-03-06 09:00:30+00
356	suwanee_smiles	PRED-SIM-DA-D03	conditions_opened	conditions_emitter	{"count": 1, "conditions": ["ELIG_WAITING_PERIOD_NOT_MET"]}	\N	2026-03-06 09:00:35+00	2026-03-06 09:00:35+00
357	suwanee_smiles	PRED-SIM-DA-D03	payer_response_received	payer_simulator	{"decision": "denied", "pred_number": "DD-2026-DA-D03-DEN", "approved_amount": 0.0}	\N	2026-03-15 09:00:00+00	2026-03-15 09:00:00+00
90	suwanee_smiles	PRED-SIM-DA-D04	pred_request_created	api	{"scenario_id": "DA-D04", "procedures_count": 1}	\N	2026-03-06 09:30:00+00	2026-03-06 09:30:00+00
359	suwanee_smiles	PRED-SIM-DA-D04	eligibility_verified	eligibility_assembler	{"payer_id": "delta_dental", "coverage_active": true, "annual_max_remaining": 1800.0}	\N	2026-03-06 09:30:03+00	2026-03-06 09:30:03+00
360	suwanee_smiles	PRED-SIM-DA-D04	documents_ingested	ingest_router	{"types": ["CLINICAL_NOTE", "PRED_LETTER", "XRAY_PA"], "document_count": 3}	\N	2026-03-08 09:30:00+00	2026-03-08 09:30:00+00
361	suwanee_smiles	PRED-SIM-DA-D04	clinical_evidence_assembled	clinical_assembler	{"criteria_score": 1.0, "evidence_count": 3}	\N	2026-03-08 09:30:10+00	2026-03-08 09:30:10+00
362	suwanee_smiles	PRED-SIM-DA-D04	coverage_evaluated	coverage_assembler	{"open_conditions": ["COVERAGE_DOWNGRADE_APPLIED", "COVERAGE_PRED_REQUIRED"], "has_bundling_conflict": false}	\N	2026-03-08 09:30:20+00	2026-03-08 09:30:20+00
363	suwanee_smiles	PRED-SIM-DA-D04	pred_state_computed	aggregation_service	{"decision": "approved", "criteria_score": 1.0}	\N	2026-03-08 09:30:30+00	2026-03-08 09:30:30+00
364	suwanee_smiles	PRED-SIM-DA-D04	conditions_opened	conditions_emitter	{"count": 2, "conditions": ["COVERAGE_DOWNGRADE_APPLIED", "COVERAGE_PRED_REQUIRED"]}	\N	2026-03-08 09:30:35+00	2026-03-08 09:30:35+00
365	suwanee_smiles	PRED-SIM-DA-D04	payer_response_received	payer_simulator	{"decision": "approved", "pred_number": "DD-2026-DA-D04-APP", "approved_amount": 570.0}	\N	2026-03-17 09:30:00+00	2026-03-17 09:30:00+00
91	suwanee_smiles	PRED-SIM-DA-D05	pred_request_created	api	{"scenario_id": "DA-D05", "procedures_count": 2}	\N	2026-03-08 10:00:00+00	2026-03-08 10:00:00+00
367	suwanee_smiles	PRED-SIM-DA-D05	eligibility_verified	eligibility_assembler	{"payer_id": "delta_dental", "coverage_active": true, "annual_max_remaining": 1800.0}	\N	2026-03-08 10:00:03+00	2026-03-08 10:00:03+00
368	suwanee_smiles	PRED-SIM-DA-D05	documents_ingested	ingest_router	{"types": ["CBCT_REPORT", "CLINICAL_NOTE", "PRED_LETTER", "XRAY_PA"], "document_count": 4}	\N	2026-03-10 10:00:00+00	2026-03-10 10:00:00+00
369	suwanee_smiles	PRED-SIM-DA-D05	clinical_evidence_assembled	clinical_assembler	{"criteria_score": 1.0, "evidence_count": 4}	\N	2026-03-10 10:00:10+00	2026-03-10 10:00:10+00
370	suwanee_smiles	PRED-SIM-DA-D05	coverage_evaluated	coverage_assembler	{"open_conditions": ["COVERAGE_PRED_REQUIRED"], "has_bundling_conflict": false}	\N	2026-03-10 10:00:20+00	2026-03-10 10:00:20+00
371	suwanee_smiles	PRED-SIM-DA-D05	pred_state_computed	aggregation_service	{"decision": "approved", "criteria_score": 1.0}	\N	2026-03-10 10:00:30+00	2026-03-10 10:00:30+00
372	suwanee_smiles	PRED-SIM-DA-D05	conditions_opened	conditions_emitter	{"count": 1, "conditions": ["COVERAGE_PRED_REQUIRED"]}	\N	2026-03-10 10:00:35+00	2026-03-10 10:00:35+00
373	suwanee_smiles	PRED-SIM-DA-D05	payer_response_received	payer_simulator	{"decision": "approved", "pred_number": "DD-2026-DA-D05-APP", "approved_amount": 1180.0}	\N	2026-03-19 10:00:00+00	2026-03-19 10:00:00+00
97	suwanee_smiles	PRED-SIM-DA-F01	pred_request_created	api	{"scenario_id": "DA-F01", "procedures_count": 1}	\N	2026-03-11 08:00:00+00	2026-03-11 08:00:00+00
375	suwanee_smiles	PRED-SIM-DA-F01	eligibility_verified	eligibility_assembler	{"payer_id": "delta_dental", "coverage_active": true, "annual_max_remaining": 1800.0}	\N	2026-03-11 08:00:03+00	2026-03-11 08:00:03+00
376	suwanee_smiles	PRED-SIM-DA-F01	documents_ingested	ingest_router	{"types": ["CLINICAL_NOTE", "PRED_LETTER", "XRAY_PA"], "document_count": 3}	\N	2026-03-13 08:00:00+00	2026-03-13 08:00:00+00
377	suwanee_smiles	PRED-SIM-DA-F01	clinical_evidence_assembled	clinical_assembler	{"criteria_score": 1.0, "evidence_count": 3}	\N	2026-03-13 08:00:10+00	2026-03-13 08:00:10+00
378	suwanee_smiles	PRED-SIM-DA-F01	coverage_evaluated	coverage_assembler	{"open_conditions": ["COVERAGE_DOWNGRADE_APPLIED", "COVERAGE_PRED_REQUIRED", "COVERAGE_SURFACE_MISMATCH"], "has_bundling_conflict": false}	\N	2026-03-13 08:00:20+00	2026-03-13 08:00:20+00
379	suwanee_smiles	PRED-SIM-DA-F01	pred_state_computed	aggregation_service	{"decision": "pended", "criteria_score": 1.0}	\N	2026-03-13 08:00:30+00	2026-03-13 08:00:30+00
380	suwanee_smiles	PRED-SIM-DA-F01	conditions_opened	conditions_emitter	{"count": 3, "conditions": ["COVERAGE_DOWNGRADE_APPLIED", "COVERAGE_PRED_REQUIRED", "COVERAGE_SURFACE_MISMATCH"]}	\N	2026-03-13 08:00:35+00	2026-03-13 08:00:35+00
381	suwanee_smiles	PRED-SIM-DA-F01	payer_response_received	payer_simulator	{"decision": "pended", "pred_number": "DD-2026-DA-F01-PND", "approved_amount": null}	\N	2026-03-22 08:00:00+00	2026-03-22 08:00:00+00
98	suwanee_smiles	PRED-SIM-DA-F02	pred_request_created	api	{"scenario_id": "DA-F02", "procedures_count": 1}	\N	2026-03-13 08:30:00+00	2026-03-13 08:30:00+00
383	suwanee_smiles	PRED-SIM-DA-F02	eligibility_verified	eligibility_assembler	{"payer_id": "delta_dental", "coverage_active": true, "annual_max_remaining": 1800.0}	\N	2026-03-13 08:30:03+00	2026-03-13 08:30:03+00
384	suwanee_smiles	PRED-SIM-DA-F02	documents_ingested	ingest_router	{"types": ["CLINICAL_NOTE", "PERIO_CHART", "PRED_LETTER"], "document_count": 3}	\N	2026-03-15 08:30:00+00	2026-03-15 08:30:00+00
385	suwanee_smiles	PRED-SIM-DA-F02	clinical_evidence_assembled	clinical_assembler	{"criteria_score": 0.3, "evidence_count": 3}	\N	2026-03-15 08:30:10+00	2026-03-15 08:30:10+00
386	suwanee_smiles	PRED-SIM-DA-F02	coverage_evaluated	coverage_assembler	{"open_conditions": ["COVERAGE_PRED_REQUIRED", "CLINICAL_CRITERIA_NOT_MET", "CLINICAL_POCKET_DEPTH", "CLINICAL_BONE_LOSS_THRESHOLD", "CLINICAL_XRAY_REQUIRED"], "has_bundling_conflict": false}	\N	2026-03-15 08:30:20+00	2026-03-15 08:30:20+00
387	suwanee_smiles	PRED-SIM-DA-F02	pred_state_computed	aggregation_service	{"decision": "denied", "criteria_score": 0.3}	\N	2026-03-15 08:30:30+00	2026-03-15 08:30:30+00
388	suwanee_smiles	PRED-SIM-DA-F02	conditions_opened	conditions_emitter	{"count": 5, "conditions": ["COVERAGE_PRED_REQUIRED", "CLINICAL_CRITERIA_NOT_MET", "CLINICAL_POCKET_DEPTH", "CLINICAL_BONE_LOSS_THRESHOLD", "CLINICAL_XRAY_REQUIRED"]}	\N	2026-03-15 08:30:35+00	2026-03-15 08:30:35+00
389	suwanee_smiles	PRED-SIM-DA-F02	payer_response_received	payer_simulator	{"decision": "denied", "pred_number": "DD-2026-DA-F02-DEN", "approved_amount": 0.0}	\N	2026-03-24 08:30:00+00	2026-03-24 08:30:00+00
99	suwanee_smiles	PRED-SIM-DA-F03	pred_request_created	api	{"scenario_id": "DA-F03", "procedures_count": 1}	\N	2026-03-15 09:00:00+00	2026-03-15 09:00:00+00
391	suwanee_smiles	PRED-SIM-DA-F03	eligibility_verified	eligibility_assembler	{"payer_id": "delta_dental", "coverage_active": true, "annual_max_remaining": 1800.0}	\N	2026-03-15 09:00:03+00	2026-03-15 09:00:03+00
392	suwanee_smiles	PRED-SIM-DA-F03	documents_ingested	ingest_router	{"types": ["CLINICAL_NOTE", "PRED_LETTER", "XRAY_PA"], "document_count": 3}	\N	2026-03-17 09:00:00+00	2026-03-17 09:00:00+00
393	suwanee_smiles	PRED-SIM-DA-F03	clinical_evidence_assembled	clinical_assembler	{"criteria_score": 1.0, "evidence_count": 3}	\N	2026-03-17 09:00:10+00	2026-03-17 09:00:10+00
394	suwanee_smiles	PRED-SIM-DA-F03	coverage_evaluated	coverage_assembler	{"open_conditions": ["ELIG_FREQUENCY_LIMIT"], "has_bundling_conflict": false}	\N	2026-03-17 09:00:20+00	2026-03-17 09:00:20+00
395	suwanee_smiles	PRED-SIM-DA-F03	pred_state_computed	aggregation_service	{"decision": "denied", "criteria_score": 1.0}	\N	2026-03-17 09:00:30+00	2026-03-17 09:00:30+00
396	suwanee_smiles	PRED-SIM-DA-F03	conditions_opened	conditions_emitter	{"count": 1, "conditions": ["ELIG_FREQUENCY_LIMIT"]}	\N	2026-03-17 09:00:35+00	2026-03-17 09:00:35+00
397	suwanee_smiles	PRED-SIM-DA-F03	payer_response_received	payer_simulator	{"decision": "denied", "pred_number": "DD-2026-DA-F03-DEN", "approved_amount": 0.0}	\N	2026-03-26 09:00:00+00	2026-03-26 09:00:00+00
100	suwanee_smiles	PRED-SIM-DA-F04	pred_request_created	api	{"scenario_id": "DA-F04", "procedures_count": 1}	\N	2026-03-17 09:30:00+00	2026-03-17 09:30:00+00
399	suwanee_smiles	PRED-SIM-DA-F04	eligibility_verified	eligibility_assembler	{"payer_id": "delta_dental", "coverage_active": true, "annual_max_remaining": 1800.0}	\N	2026-03-17 09:30:03+00	2026-03-17 09:30:03+00
400	suwanee_smiles	PRED-SIM-DA-F04	documents_ingested	ingest_router	{"types": ["CLINICAL_NOTE", "PRED_LETTER", "XRAY_PA"], "document_count": 3}	\N	2026-03-19 09:30:00+00	2026-03-19 09:30:00+00
401	suwanee_smiles	PRED-SIM-DA-F04	clinical_evidence_assembled	clinical_assembler	{"criteria_score": 1.0, "evidence_count": 3}	\N	2026-03-19 09:30:10+00	2026-03-19 09:30:10+00
402	suwanee_smiles	PRED-SIM-DA-F04	coverage_evaluated	coverage_assembler	{"open_conditions": ["COVERAGE_BUNDLING_CONFLICT", "COVERAGE_PRED_REQUIRED"], "has_bundling_conflict": true}	\N	2026-03-19 09:30:20+00	2026-03-19 09:30:20+00
403	suwanee_smiles	PRED-SIM-DA-F04	pred_state_computed	aggregation_service	{"decision": "pended", "criteria_score": 1.0}	\N	2026-03-19 09:30:30+00	2026-03-19 09:30:30+00
404	suwanee_smiles	PRED-SIM-DA-F04	conditions_opened	conditions_emitter	{"count": 2, "conditions": ["COVERAGE_BUNDLING_CONFLICT", "COVERAGE_PRED_REQUIRED"]}	\N	2026-03-19 09:30:35+00	2026-03-19 09:30:35+00
405	suwanee_smiles	PRED-SIM-DA-F04	payer_response_received	payer_simulator	{"decision": "pended", "pred_number": "DD-2026-DA-F04-PND", "approved_amount": null}	\N	2026-03-28 09:30:00+00	2026-03-28 09:30:00+00
101	suwanee_smiles	PRED-SIM-DA-F05	pred_request_created	api	{"scenario_id": "DA-F05", "procedures_count": 1}	\N	2026-03-19 10:00:00+00	2026-03-19 10:00:00+00
407	suwanee_smiles	PRED-SIM-DA-F05	eligibility_verified	eligibility_assembler	{"payer_id": "delta_dental", "coverage_active": true, "annual_max_remaining": 1800.0}	\N	2026-03-19 10:00:03+00	2026-03-19 10:00:03+00
408	suwanee_smiles	PRED-SIM-DA-F05	documents_ingested	ingest_router	{"types": ["CLINICAL_NOTE", "PRED_LETTER", "XRAY_PA"], "document_count": 3}	\N	2026-03-21 10:00:00+00	2026-03-21 10:00:00+00
409	suwanee_smiles	PRED-SIM-DA-F05	clinical_evidence_assembled	clinical_assembler	{"criteria_score": 0.9, "evidence_count": 3}	\N	2026-03-21 10:00:10+00	2026-03-21 10:00:10+00
410	suwanee_smiles	PRED-SIM-DA-F05	coverage_evaluated	coverage_assembler	{"open_conditions": ["COVERAGE_PRED_REQUIRED"], "has_bundling_conflict": false}	\N	2026-03-21 10:00:20+00	2026-03-21 10:00:20+00
411	suwanee_smiles	PRED-SIM-DA-F05	pred_state_computed	aggregation_service	{"decision": "pended", "criteria_score": 0.9}	\N	2026-03-21 10:00:30+00	2026-03-21 10:00:30+00
412	suwanee_smiles	PRED-SIM-DA-F05	conditions_opened	conditions_emitter	{"count": 1, "conditions": ["COVERAGE_PRED_REQUIRED"]}	\N	2026-03-21 10:00:35+00	2026-03-21 10:00:35+00
178	suwanee_smiles	PRED-SIM-DA-A01	eligibility_verified	eligibility_assembler	{"payer_id": "delta_dental", "coverage_active": true, "annual_max_remaining": 1800.0}	\N	2026-01-15 08:00:03+00	2026-01-15 08:00:03+00
179	suwanee_smiles	PRED-SIM-DA-A01	documents_ingested	ingest_router	{"types": ["CLINICAL_NOTE", "INSURANCE_CARD", "PRED_LETTER", "XRAY_PA"], "document_count": 4}	\N	2026-01-17 08:00:00+00	2026-01-17 08:00:00+00
180	suwanee_smiles	PRED-SIM-DA-A01	clinical_evidence_assembled	clinical_assembler	{"criteria_score": 0.85, "evidence_count": 4}	\N	2026-01-17 08:00:10+00	2026-01-17 08:00:10+00
181	suwanee_smiles	PRED-SIM-DA-A01	coverage_evaluated	coverage_assembler	{"open_conditions": ["COVERAGE_PRED_REQUIRED", "COVERAGE_BUNDLING_CONFLICT", "CLINICAL_XRAY_REQUIRED", "CLINICAL_NARRATIVE_REQUIRED", "COVERAGE_DOWNGRADE_APPLIED", "CLINICAL_CRITERIA_NOT_MET"], "has_bundling_conflict": true}	\N	2026-01-17 08:00:20+00	2026-01-17 08:00:20+00
182	suwanee_smiles	PRED-SIM-DA-A01	pred_state_computed	aggregation_service	{"decision": "pended", "criteria_score": 0.85}	\N	2026-01-17 08:00:30+00	2026-01-17 08:00:30+00
183	suwanee_smiles	PRED-SIM-DA-A01	conditions_opened	conditions_emitter	{"count": 6, "conditions": ["COVERAGE_PRED_REQUIRED", "COVERAGE_BUNDLING_CONFLICT", "CLINICAL_XRAY_REQUIRED", "CLINICAL_NARRATIVE_REQUIRED", "COVERAGE_DOWNGRADE_APPLIED", "CLINICAL_CRITERIA_NOT_MET"]}	\N	2026-01-17 08:00:35+00	2026-01-17 08:00:35+00
184	suwanee_smiles	PRED-SIM-DA-A01	payer_response_received	payer_simulator	{"decision": "pended", "pred_number": "DD-2026-DA-A01-PND", "approved_amount": null}	\N	2026-01-26 08:00:00+00	2026-01-26 08:00:00+00
186	suwanee_smiles	PRED-SIM-DA-A02	eligibility_verified	eligibility_assembler	{"payer_id": "delta_dental", "coverage_active": true, "annual_max_remaining": 1800.0}	\N	2026-01-17 08:30:03+00	2026-01-17 08:30:03+00
187	suwanee_smiles	PRED-SIM-DA-A02	documents_ingested	ingest_router	{"types": ["CLINICAL_NOTE", "PRED_LETTER", "XRAY_PA"], "document_count": 3}	\N	2026-01-19 08:30:00+00	2026-01-19 08:30:00+00
188	suwanee_smiles	PRED-SIM-DA-A02	clinical_evidence_assembled	clinical_assembler	{"criteria_score": 1.0, "evidence_count": 3}	\N	2026-01-19 08:30:10+00	2026-01-19 08:30:10+00
189	suwanee_smiles	PRED-SIM-DA-A02	coverage_evaluated	coverage_assembler	{"open_conditions": ["COVERAGE_PRED_REQUIRED"], "has_bundling_conflict": false}	\N	2026-01-19 08:30:20+00	2026-01-19 08:30:20+00
190	suwanee_smiles	PRED-SIM-DA-A02	pred_state_computed	aggregation_service	{"decision": "approved", "criteria_score": 1.0}	\N	2026-01-19 08:30:30+00	2026-01-19 08:30:30+00
191	suwanee_smiles	PRED-SIM-DA-A02	conditions_opened	conditions_emitter	{"count": 1, "conditions": ["COVERAGE_PRED_REQUIRED"]}	\N	2026-01-19 08:30:35+00	2026-01-19 08:30:35+00
192	suwanee_smiles	PRED-SIM-DA-A02	payer_response_received	payer_simulator	{"decision": "approved", "pred_number": "DD-2026-DA-A02-APP", "approved_amount": 570.0}	\N	2026-01-28 08:30:00+00	2026-01-28 08:30:00+00
194	suwanee_smiles	PRED-SIM-DA-A03	eligibility_verified	eligibility_assembler	{"payer_id": "delta_dental", "coverage_active": true, "annual_max_remaining": 1800.0}	\N	2026-01-19 09:00:03+00	2026-01-19 09:00:03+00
196	suwanee_smiles	PRED-SIM-DA-A03	clinical_evidence_assembled	clinical_assembler	{"criteria_score": 1.0, "evidence_count": 3}	\N	2026-01-21 09:00:10+00	2026-01-21 09:00:10+00
413	suwanee_smiles	PRED-SIM-DA-F05	payer_response_received	payer_simulator	{"decision": "pended", "pred_number": "DD-2026-DA-F05-PND", "approved_amount": null}	\N	2026-03-30 10:00:00+00	2026-03-30 10:00:00+00
92	suwanee_smiles	PRED-SIM-DA-M01	pred_request_created	api	{"scenario_id": "DA-M01", "procedures_count": 1}	\N	2026-03-22 08:00:00+00	2026-03-22 08:00:00+00
415	suwanee_smiles	PRED-SIM-DA-M01	eligibility_verified	eligibility_assembler	{"payer_id": "delta_dental", "coverage_active": true, "annual_max_remaining": 1800.0}	\N	2026-03-22 08:00:03+00	2026-03-22 08:00:03+00
416	suwanee_smiles	PRED-SIM-DA-M01	documents_ingested	ingest_router	{"types": ["CLINICAL_NOTE", "INSURANCE_CARD", "PRED_LETTER", "XRAY_PA"], "document_count": 4}	\N	2026-03-24 08:00:00+00	2026-03-24 08:00:00+00
417	suwanee_smiles	PRED-SIM-DA-M01	clinical_evidence_assembled	clinical_assembler	{"criteria_score": 1.0, "evidence_count": 4}	\N	2026-03-24 08:00:10+00	2026-03-24 08:00:10+00
418	suwanee_smiles	PRED-SIM-DA-M01	coverage_evaluated	coverage_assembler	{"open_conditions": ["COVERAGE_PRED_REQUIRED", "ELIG_PLAN_NOT_FOUND"], "has_bundling_conflict": false}	\N	2026-03-24 08:00:20+00	2026-03-24 08:00:20+00
419	suwanee_smiles	PRED-SIM-DA-M01	pred_state_computed	aggregation_service	{"decision": "pended", "criteria_score": 1.0}	\N	2026-03-24 08:00:30+00	2026-03-24 08:00:30+00
420	suwanee_smiles	PRED-SIM-DA-M01	conditions_opened	conditions_emitter	{"count": 2, "conditions": ["COVERAGE_PRED_REQUIRED", "ELIG_PLAN_NOT_FOUND"]}	\N	2026-03-24 08:00:35+00	2026-03-24 08:00:35+00
421	suwanee_smiles	PRED-SIM-DA-M01	payer_response_received	payer_simulator	{"decision": "pended", "pred_number": "DD-2026-DA-M01-PND", "approved_amount": null}	\N	2026-04-02 08:00:00+00	2026-04-02 08:00:00+00
93	suwanee_smiles	PRED-SIM-DA-M02	pred_request_created	api	{"scenario_id": "DA-M02", "procedures_count": 1}	\N	2026-03-24 08:30:00+00	2026-03-24 08:30:00+00
423	suwanee_smiles	PRED-SIM-DA-M02	eligibility_verified	eligibility_assembler	{"payer_id": "delta_dental", "coverage_active": true, "annual_max_remaining": 1800.0}	\N	2026-03-24 08:30:03+00	2026-03-24 08:30:03+00
424	suwanee_smiles	PRED-SIM-DA-M02	documents_ingested	ingest_router	{"types": ["CLINICAL_NOTE", "PERIO_CHART", "PRED_LETTER"], "document_count": 3}	\N	2026-03-26 08:30:00+00	2026-03-26 08:30:00+00
425	suwanee_smiles	PRED-SIM-DA-M02	clinical_evidence_assembled	clinical_assembler	{"criteria_score": 0.7, "evidence_count": 3}	\N	2026-03-26 08:30:10+00	2026-03-26 08:30:10+00
426	suwanee_smiles	PRED-SIM-DA-M02	coverage_evaluated	coverage_assembler	{"open_conditions": ["COVERAGE_PRED_REQUIRED", "CLINICAL_CRITERIA_NOT_MET", "CLINICAL_BONE_LOSS_THRESHOLD", "CLINICAL_XRAY_REQUIRED"], "has_bundling_conflict": false}	\N	2026-03-26 08:30:20+00	2026-03-26 08:30:20+00
427	suwanee_smiles	PRED-SIM-DA-M02	pred_state_computed	aggregation_service	{"decision": "pended", "criteria_score": 0.7}	\N	2026-03-26 08:30:30+00	2026-03-26 08:30:30+00
428	suwanee_smiles	PRED-SIM-DA-M02	conditions_opened	conditions_emitter	{"count": 4, "conditions": ["COVERAGE_PRED_REQUIRED", "CLINICAL_CRITERIA_NOT_MET", "CLINICAL_BONE_LOSS_THRESHOLD", "CLINICAL_XRAY_REQUIRED"]}	\N	2026-03-26 08:30:35+00	2026-03-26 08:30:35+00
429	suwanee_smiles	PRED-SIM-DA-M02	payer_response_received	payer_simulator	{"decision": "pended", "pred_number": "DD-2026-DA-M02-PND", "approved_amount": null}	\N	2026-04-04 08:30:00+00	2026-04-04 08:30:00+00
94	suwanee_smiles	PRED-SIM-DA-M03	pred_request_created	api	{"scenario_id": "DA-M03", "procedures_count": 1}	\N	2026-03-26 09:00:00+00	2026-03-26 09:00:00+00
431	suwanee_smiles	PRED-SIM-DA-M03	eligibility_verified	eligibility_assembler	{"payer_id": "delta_dental", "coverage_active": true, "annual_max_remaining": 1800.0}	\N	2026-03-26 09:00:03+00	2026-03-26 09:00:03+00
432	suwanee_smiles	PRED-SIM-DA-M03	documents_ingested	ingest_router	{"types": ["CLINICAL_NOTE", "PRED_LETTER", "XRAY_PA"], "document_count": 3}	\N	2026-03-28 09:00:00+00	2026-03-28 09:00:00+00
433	suwanee_smiles	PRED-SIM-DA-M03	clinical_evidence_assembled	clinical_assembler	{"criteria_score": 1.0, "evidence_count": 3}	\N	2026-03-28 09:00:10+00	2026-03-28 09:00:10+00
434	suwanee_smiles	PRED-SIM-DA-M03	coverage_evaluated	coverage_assembler	{"open_conditions": ["COVERAGE_PRED_REQUIRED", "COVERAGE_SURFACE_MISMATCH"], "has_bundling_conflict": false}	\N	2026-03-28 09:00:20+00	2026-03-28 09:00:20+00
435	suwanee_smiles	PRED-SIM-DA-M03	pred_state_computed	aggregation_service	{"decision": "pended", "criteria_score": 1.0}	\N	2026-03-28 09:00:30+00	2026-03-28 09:00:30+00
436	suwanee_smiles	PRED-SIM-DA-M03	conditions_opened	conditions_emitter	{"count": 2, "conditions": ["COVERAGE_PRED_REQUIRED", "COVERAGE_SURFACE_MISMATCH"]}	\N	2026-03-28 09:00:35+00	2026-03-28 09:00:35+00
443	suwanee_smiles	PRED-SIM-DA-M04	pred_state_computed	aggregation_service	{"decision": "pended", "criteria_score": 0.9}	\N	2026-03-30 09:30:30+00	2026-03-30 09:30:30+00
1036	suwanee_smiles	PRED-SIM-DA-U03	coverage_evaluated	coverage_assembler	{"open_conditions": [], "has_bundling_conflict": false}	\N	2026-04-08 09:00:20+00	2026-04-08 09:00:20+00
1037	suwanee_smiles	PRED-SIM-DA-U03	pred_state_computed	aggregation_service	{"decision": "approved", "criteria_score": 1.0}	\N	2026-04-08 09:00:30+00	2026-04-08 09:00:30+00
1038	suwanee_smiles	PRED-SIM-DA-U03	payer_response_received	payer_simulator	{"decision": "approved", "pred_number": "DD-2026-DA-U03-APP", "approved_amount": 79.0}	\N	2026-04-17 09:00:00+00	2026-04-17 09:00:00+00
739	suwanee_smiles	PRED-SIM-DA-U04	pred_request_created	api	{"scenario_id": "DA-U04", "procedures_count": 1}	\N	2026-04-08 09:30:00+00	2026-04-08 09:30:00+00
1040	suwanee_smiles	PRED-SIM-DA-U04	eligibility_verified	eligibility_assembler	{"payer_id": "metlife", "coverage_active": true, "annual_max_remaining": 1800.0}	\N	2026-04-08 09:30:03+00	2026-04-08 09:30:03+00
1041	suwanee_smiles	PRED-SIM-DA-U04	documents_ingested	ingest_router	{"types": ["CLINICAL_NOTE", "INSURANCE_CARD", "PRED_LETTER"], "document_count": 3}	\N	2026-04-10 09:30:00+00	2026-04-10 09:30:00+00
1042	suwanee_smiles	PRED-SIM-DA-U04	clinical_evidence_assembled	clinical_assembler	{"criteria_score": 1.0, "evidence_count": 3}	\N	2026-04-10 09:30:10+00	2026-04-10 09:30:10+00
1043	suwanee_smiles	PRED-SIM-DA-U04	coverage_evaluated	coverage_assembler	{"open_conditions": [], "has_bundling_conflict": false}	\N	2026-04-10 09:30:20+00	2026-04-10 09:30:20+00
1044	suwanee_smiles	PRED-SIM-DA-U04	pred_state_computed	aggregation_service	{"decision": "approved", "criteria_score": 1.0}	\N	2026-04-10 09:30:30+00	2026-04-10 09:30:30+00
1045	suwanee_smiles	PRED-SIM-DA-U04	payer_response_received	payer_simulator	{"decision": "approved", "pred_number": "DD-2026-DA-U04-APP", "approved_amount": 67.92}	\N	2026-04-19 09:30:00+00	2026-04-19 09:30:00+00
740	suwanee_smiles	PRED-SIM-DA-U05	pred_request_created	api	{"scenario_id": "DA-U05", "procedures_count": 1}	\N	2026-04-10 10:00:00+00	2026-04-10 10:00:00+00
1047	suwanee_smiles	PRED-SIM-DA-U05	eligibility_verified	eligibility_assembler	{"payer_id": "delta_dental", "coverage_active": true, "annual_max_remaining": 1800.0}	\N	2026-04-10 10:00:03+00	2026-04-10 10:00:03+00
1048	suwanee_smiles	PRED-SIM-DA-U05	documents_ingested	ingest_router	{"types": ["CLINICAL_NOTE", "INSURANCE_CARD", "PERIO_CHART", "PRED_LETTER"], "document_count": 4}	\N	2026-04-12 10:00:00+00	2026-04-12 10:00:00+00
1049	suwanee_smiles	PRED-SIM-DA-U05	clinical_evidence_assembled	clinical_assembler	{"criteria_score": 1.0, "evidence_count": 4}	\N	2026-04-12 10:00:10+00	2026-04-12 10:00:10+00
1050	suwanee_smiles	PRED-SIM-DA-U05	coverage_evaluated	coverage_assembler	{"open_conditions": [], "has_bundling_conflict": false}	\N	2026-04-12 10:00:20+00	2026-04-12 10:00:20+00
1051	suwanee_smiles	PRED-SIM-DA-U05	pred_state_computed	aggregation_service	{"decision": "approved", "criteria_score": 1.0}	\N	2026-04-12 10:00:30+00	2026-04-12 10:00:30+00
1052	suwanee_smiles	PRED-SIM-DA-U05	payer_response_received	payer_simulator	{"decision": "approved", "pred_number": "DD-2026-DA-U05-APP", "approved_amount": 78.9}	\N	2026-04-21 10:00:00+00	2026-04-21 10:00:00+00
\.


--
-- Data for Name: pred_condition_instances; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.pred_condition_instances (condition_instance_id, pred_request_id, tenant_id, condition_code, status, assignee, due_by, opened_at, resolved_at, context) FROM stdin;
578	PRED-SIM-DA-A01	suwanee_smiles	COVERAGE_PRED_REQUIRED	open	provider	2026-08-06 15:57:00.693393+00	2026-08-05 15:57:00.693393+00	\N	{}
579	PRED-SIM-DA-A01	suwanee_smiles	COVERAGE_BUNDLING_CONFLICT	open	provider	2026-08-06 15:57:00.693393+00	2026-08-05 15:57:00.693393+00	\N	{}
580	PRED-SIM-DA-A01	suwanee_smiles	CLINICAL_XRAY_REQUIRED	open	provider	2026-08-07 15:57:00.693393+00	2026-08-05 15:57:00.693393+00	\N	{}
581	PRED-SIM-DA-A01	suwanee_smiles	CLINICAL_NARRATIVE_REQUIRED	open	provider	2026-08-07 15:57:00.693393+00	2026-08-05 15:57:00.693393+00	\N	{}
582	PRED-SIM-DA-A01	suwanee_smiles	COVERAGE_DOWNGRADE_APPLIED	open	provider	2026-08-06 15:57:00.693393+00	2026-08-05 15:57:00.693393+00	\N	{}
583	PRED-SIM-DA-A01	suwanee_smiles	CLINICAL_CRITERIA_NOT_MET	open	provider	2026-08-08 15:57:00.693393+00	2026-08-05 15:57:00.693393+00	\N	{}
836	PRED-SIM-TB-A01	tampa_smiles	COVERAGE_PRED_REQUIRED	open	provider	2026-08-07 13:35:19.709717+00	2026-08-06 13:35:19.709717+00	\N	{}
837	PRED-SIM-TB-B01	tampa_smiles	ELIG_IMPLANT_NOT_COVERED	open	provider	2026-08-07 13:35:21.299714+00	2026-08-06 13:35:21.299714+00	\N	{}
838	PRED-SIM-TB-C01	tampa_smiles	CLINICAL_CRITERIA_NOT_MET	open	provider	2026-08-09 13:35:22.695469+00	2026-08-06 13:35:22.695469+00	\N	{}
839	PRED-SIM-TB-C01	tampa_smiles	CLINICAL_POCKET_DEPTH	open	provider	2026-08-09 13:35:22.695469+00	2026-08-06 13:35:22.695469+00	\N	{}
840	PRED-SIM-TB-C01	tampa_smiles	CLINICAL_PERIO_CHART_REQUIRED	open	provider	2026-08-08 13:35:22.695469+00	2026-08-06 13:35:22.695469+00	\N	{}
841	PRED-SIM-TB-D01	tampa_smiles	COVERAGE_DOWNGRADE_APPLIED	open	provider	2026-08-07 13:35:24.314478+00	2026-08-06 13:35:24.314478+00	\N	{}
842	PRED-SIM-TB-D01	tampa_smiles	COVERAGE_PRED_REQUIRED	open	provider	2026-08-07 13:35:24.314478+00	2026-08-06 13:35:24.314478+00	\N	{}
843	PRED-SIM-DL-A01	dallas_dental	COVERAGE_PRED_REQUIRED	open	provider	2026-08-07 13:35:56.326209+00	2026-08-06 13:35:56.326209+00	\N	{}
844	PRED-SIM-DL-A01	dallas_dental	COVERAGE_DOWNGRADE_APPLIED	open	provider	2026-08-07 13:35:56.326209+00	2026-08-06 13:35:56.326209+00	\N	{}
845	PRED-SIM-DL-B01	dallas_dental	COVERAGE_PRED_REQUIRED	open	provider	2026-08-07 13:35:57.892712+00	2026-08-06 13:35:57.892712+00	\N	{}
846	PRED-SIM-DL-B01	dallas_dental	CLINICAL_CRITERIA_NOT_MET	open	provider	2026-08-09 13:35:57.892712+00	2026-08-06 13:35:57.892712+00	\N	{}
847	PRED-SIM-DL-B01	dallas_dental	CLINICAL_POCKET_DEPTH	open	provider	2026-08-09 13:35:57.892712+00	2026-08-06 13:35:57.892712+00	\N	{}
848	PRED-SIM-DL-B01	dallas_dental	CLINICAL_BONE_LOSS_THRESHOLD	open	provider	2026-08-09 13:35:57.892712+00	2026-08-06 13:35:57.892712+00	\N	{}
849	PRED-SIM-DL-B01	dallas_dental	CLINICAL_XRAY_REQUIRED	open	provider	2026-08-08 13:35:57.892712+00	2026-08-06 13:35:57.892712+00	\N	{}
850	PRED-SIM-DL-C01	dallas_dental	ELIG_FREQUENCY_LIMIT	open	provider	2026-08-07 13:35:59.729668+00	2026-08-06 13:35:59.729668+00	\N	{}
851	PRED-SIM-DL-D01	dallas_dental	COVERAGE_NOT_MEDICALLY_NECESSARY	open	provider	2026-08-09 13:36:01.496962+00	2026-08-06 13:36:01.496962+00	\N	{}
584	PRED-SIM-DA-A02	suwanee_smiles	COVERAGE_PRED_REQUIRED	open	provider	2026-08-06 15:57:02.49516+00	2026-08-05 15:57:02.49516+00	\N	{}
585	PRED-SIM-DA-A03	suwanee_smiles	COVERAGE_PRED_REQUIRED	open	provider	2026-08-06 15:57:04.093368+00	2026-08-05 15:57:04.093368+00	\N	{}
586	PRED-SIM-DA-B01	suwanee_smiles	ELIG_IMPLANT_NOT_COVERED	open	provider	2026-08-06 15:57:08.102407+00	2026-08-05 15:57:08.102407+00	\N	{}
587	PRED-SIM-DA-B02	suwanee_smiles	ELIG_MISSING_TOOTH_CLAUSE	open	provider	2026-08-07 15:57:09.580818+00	2026-08-05 15:57:09.580818+00	\N	{}
588	PRED-SIM-DA-B02	suwanee_smiles	CLINICAL_EXTRACTION_DATE	open	provider	2026-08-07 15:57:09.580818+00	2026-08-05 15:57:09.580818+00	\N	{}
589	PRED-SIM-DA-B03	suwanee_smiles	ELIG_FREQUENCY_LIMIT	open	provider	2026-08-06 15:57:11.2324+00	2026-08-05 15:57:11.2324+00	\N	{}
590	PRED-SIM-DA-B03	suwanee_smiles	CLINICAL_NARRATIVE_REQUIRED	open	provider	2026-08-07 15:57:11.2324+00	2026-08-05 15:57:11.2324+00	\N	{}
591	PRED-SIM-DA-B04	suwanee_smiles	COVERAGE_PRED_REQUIRED	open	provider	2026-08-06 15:57:12.690898+00	2026-08-05 15:57:12.690898+00	\N	{}
592	PRED-SIM-DA-B04	suwanee_smiles	COVERAGE_BUNDLING_CONFLICT	open	provider	2026-08-06 15:57:12.690898+00	2026-08-05 15:57:12.690898+00	\N	{}
593	PRED-SIM-DA-B04	suwanee_smiles	CLINICAL_XRAY_REQUIRED	open	provider	2026-08-07 15:57:12.690898+00	2026-08-05 15:57:12.690898+00	\N	{}
594	PRED-SIM-DA-B04	suwanee_smiles	CLINICAL_NARRATIVE_REQUIRED	open	provider	2026-08-07 15:57:12.690898+00	2026-08-05 15:57:12.690898+00	\N	{}
595	PRED-SIM-DA-B05	suwanee_smiles	ELIG_WAITING_PERIOD_NOT_MET	open	provider	2026-08-07 15:57:14.209426+00	2026-08-05 15:57:14.209426+00	\N	{}
596	PRED-SIM-DA-B05	suwanee_smiles	CLINICAL_NARRATIVE_REQUIRED	open	provider	2026-08-07 15:57:14.209426+00	2026-08-05 15:57:14.209426+00	\N	{}
597	PRED-SIM-DA-C01	suwanee_smiles	COVERAGE_PRED_REQUIRED	open	provider	2026-08-06 15:57:15.47291+00	2026-08-05 15:57:15.47291+00	\N	{}
598	PRED-SIM-DA-C01	suwanee_smiles	CLINICAL_CRITERIA_NOT_MET	open	provider	2026-08-08 15:57:15.47291+00	2026-08-05 15:57:15.47291+00	\N	{}
599	PRED-SIM-DA-C01	suwanee_smiles	COVERAGE_BUNDLING_CONFLICT	open	provider	2026-08-06 15:57:15.47291+00	2026-08-05 15:57:15.47291+00	\N	{}
600	PRED-SIM-DA-C01	suwanee_smiles	CLINICAL_XRAY_REQUIRED	open	provider	2026-08-07 15:57:15.47291+00	2026-08-05 15:57:15.47291+00	\N	{}
601	PRED-SIM-DA-C01	suwanee_smiles	CLINICAL_NARRATIVE_REQUIRED	open	provider	2026-08-07 15:57:15.47291+00	2026-08-05 15:57:15.47291+00	\N	{}
602	PRED-SIM-DA-C01	suwanee_smiles	CLINICAL_BONE_LOSS_THRESHOLD	open	provider	2026-08-08 15:57:15.47291+00	2026-08-05 15:57:15.47291+00	\N	{}
603	PRED-SIM-DA-C02	suwanee_smiles	COVERAGE_PRED_REQUIRED	open	provider	2026-08-06 15:57:16.985381+00	2026-08-05 15:57:16.985381+00	\N	{}
604	PRED-SIM-DA-C02	suwanee_smiles	CLINICAL_CRITERIA_NOT_MET	open	provider	2026-08-08 15:57:16.985381+00	2026-08-05 15:57:16.985381+00	\N	{}
605	PRED-SIM-DA-C02	suwanee_smiles	CLINICAL_POCKET_DEPTH	open	provider	2026-08-08 15:57:16.985381+00	2026-08-05 15:57:16.985381+00	\N	{}
606	PRED-SIM-DA-C02	suwanee_smiles	CLINICAL_BONE_LOSS_THRESHOLD	open	provider	2026-08-08 15:57:16.985381+00	2026-08-05 15:57:16.985381+00	\N	{}
607	PRED-SIM-DA-C02	suwanee_smiles	CLINICAL_PERIO_CHART_REQUIRED	open	provider	2026-08-07 15:57:16.985381+00	2026-08-05 15:57:16.985381+00	\N	{}
608	PRED-SIM-DA-C03	suwanee_smiles	COVERAGE_PRED_REQUIRED	open	provider	2026-08-06 15:57:18.622859+00	2026-08-05 15:57:18.622859+00	\N	{}
609	PRED-SIM-DA-C03	suwanee_smiles	CLINICAL_CBCT_REQUIRED	open	provider	2026-08-08 15:57:18.622859+00	2026-08-05 15:57:18.622859+00	\N	{}
610	PRED-SIM-DA-C03	suwanee_smiles	COVERAGE_DOWNGRADE_APPLIED	open	provider	2026-08-06 15:57:18.622859+00	2026-08-05 15:57:18.622859+00	\N	{}
611	PRED-SIM-DA-C04	suwanee_smiles	COVERAGE_PRED_REQUIRED	open	provider	2026-08-06 15:57:19.876628+00	2026-08-05 15:57:19.876628+00	\N	{}
612	PRED-SIM-DA-C04	suwanee_smiles	CLINICAL_XRAY_REQUIRED	open	provider	2026-08-07 15:57:19.876628+00	2026-08-05 15:57:19.876628+00	\N	{}
613	PRED-SIM-DA-C05	suwanee_smiles	COVERAGE_PRED_REQUIRED	open	provider	2026-08-06 15:57:21.542361+00	2026-08-05 15:57:21.542361+00	\N	{}
614	PRED-SIM-DA-C05	suwanee_smiles	ELIG_COB_REQUIRED	open	provider	2026-08-07 15:57:21.542361+00	2026-08-05 15:57:21.542361+00	\N	{}
615	PRED-SIM-DA-C05	suwanee_smiles	ADMIN_COB_PRIMARY_FIRST	open	provider	2026-08-07 15:57:21.542361+00	2026-08-05 15:57:21.542361+00	\N	{}
616	PRED-SIM-DA-D01	suwanee_smiles	COVERAGE_PRED_REQUIRED	open	provider	2026-08-06 15:57:23.231401+00	2026-08-05 15:57:23.231401+00	\N	{}
617	PRED-SIM-DA-D01	suwanee_smiles	PROVIDER_OUT_OF_NETWORK	open	provider	2026-08-06 15:57:23.231401+00	2026-08-05 15:57:23.231401+00	\N	{}
618	PRED-SIM-DA-D01	suwanee_smiles	COVERAGE_BUNDLING_CONFLICT	open	provider	2026-08-06 15:57:23.231401+00	2026-08-05 15:57:23.231401+00	\N	{}
619	PRED-SIM-DA-D01	suwanee_smiles	CLINICAL_XRAY_REQUIRED	open	provider	2026-08-07 15:57:23.231401+00	2026-08-05 15:57:23.231401+00	\N	{}
620	PRED-SIM-DA-D01	suwanee_smiles	CLINICAL_NARRATIVE_REQUIRED	open	provider	2026-08-07 15:57:23.231401+00	2026-08-05 15:57:23.231401+00	\N	{}
621	PRED-SIM-DA-D02	suwanee_smiles	COVERAGE_PRED_REQUIRED	open	provider	2026-08-06 15:57:25.217422+00	2026-08-05 15:57:25.217422+00	\N	{}
622	PRED-SIM-DA-D02	suwanee_smiles	COVERAGE_BUNDLING_CONFLICT	open	provider	2026-08-06 15:57:25.217422+00	2026-08-05 15:57:25.217422+00	\N	{}
623	PRED-SIM-DA-D02	suwanee_smiles	CLINICAL_XRAY_REQUIRED	open	provider	2026-08-07 15:57:25.217422+00	2026-08-05 15:57:25.217422+00	\N	{}
624	PRED-SIM-DA-D02	suwanee_smiles	CLINICAL_NARRATIVE_REQUIRED	open	provider	2026-08-07 15:57:25.217422+00	2026-08-05 15:57:25.217422+00	\N	{}
625	PRED-SIM-DA-D02	suwanee_smiles	COVERAGE_DOWNGRADE_APPLIED	open	provider	2026-08-06 15:57:25.217422+00	2026-08-05 15:57:25.217422+00	\N	{}
626	PRED-SIM-DA-D02	suwanee_smiles	CLINICAL_CRITERIA_NOT_MET	open	provider	2026-08-08 15:57:25.217422+00	2026-08-05 15:57:25.217422+00	\N	{}
627	PRED-SIM-DA-D03	suwanee_smiles	ELIG_WAITING_PERIOD_NOT_MET	open	provider	2026-08-07 15:57:26.771146+00	2026-08-05 15:57:26.771146+00	\N	{}
628	PRED-SIM-DA-D04	suwanee_smiles	COVERAGE_DOWNGRADE_APPLIED	open	provider	2026-08-06 15:57:28.258906+00	2026-08-05 15:57:28.258906+00	\N	{}
629	PRED-SIM-DA-D04	suwanee_smiles	COVERAGE_PRED_REQUIRED	open	provider	2026-08-06 15:57:28.258906+00	2026-08-05 15:57:28.258906+00	\N	{}
630	PRED-SIM-DA-D05	suwanee_smiles	COVERAGE_PRED_REQUIRED	open	provider	2026-08-06 15:57:30.02607+00	2026-08-05 15:57:30.02607+00	\N	{}
631	PRED-SIM-DA-M01	suwanee_smiles	COVERAGE_PRED_REQUIRED	open	provider	2026-08-06 15:57:31.85739+00	2026-08-05 15:57:31.85739+00	\N	{}
632	PRED-SIM-DA-M01	suwanee_smiles	ELIG_PLAN_NOT_FOUND	open	provider	2026-08-06 15:57:31.85739+00	2026-08-05 15:57:31.85739+00	\N	{}
633	PRED-SIM-DA-M02	suwanee_smiles	COVERAGE_PRED_REQUIRED	open	provider	2026-08-06 15:57:33.299113+00	2026-08-05 15:57:33.299113+00	\N	{}
634	PRED-SIM-DA-M02	suwanee_smiles	CLINICAL_CRITERIA_NOT_MET	open	provider	2026-08-08 15:57:33.299113+00	2026-08-05 15:57:33.299113+00	\N	{}
635	PRED-SIM-DA-M02	suwanee_smiles	CLINICAL_BONE_LOSS_THRESHOLD	open	provider	2026-08-08 15:57:33.299113+00	2026-08-05 15:57:33.299113+00	\N	{}
636	PRED-SIM-DA-M02	suwanee_smiles	CLINICAL_XRAY_REQUIRED	open	provider	2026-08-07 15:57:33.299113+00	2026-08-05 15:57:33.299113+00	\N	{}
637	PRED-SIM-DA-M03	suwanee_smiles	COVERAGE_PRED_REQUIRED	open	provider	2026-08-06 15:57:34.762103+00	2026-08-05 15:57:34.762103+00	\N	{}
638	PRED-SIM-DA-M03	suwanee_smiles	COVERAGE_SURFACE_MISMATCH	open	provider	2026-08-07 15:57:34.762103+00	2026-08-05 15:57:34.762103+00	\N	{}
639	PRED-SIM-DA-M04	suwanee_smiles	COVERAGE_PRED_REQUIRED	open	provider	2026-08-06 15:57:36.390636+00	2026-08-05 15:57:36.390636+00	\N	{}
640	PRED-SIM-DA-M04	suwanee_smiles	ADMIN_DUPLICATE_PRED	open	provider	2026-08-06 15:57:36.390636+00	2026-08-05 15:57:36.390636+00	\N	{}
641	PRED-SIM-DA-M05	suwanee_smiles	COVERAGE_PRED_REQUIRED	open	provider	2026-08-06 15:57:37.834637+00	2026-08-05 15:57:37.834637+00	\N	{}
642	PRED-SIM-DA-M05	suwanee_smiles	CLINICAL_XRAY_REQUIRED	open	provider	2026-08-07 15:57:37.834637+00	2026-08-05 15:57:37.834637+00	\N	{}
643	PRED-SIM-DA-F01	suwanee_smiles	COVERAGE_DOWNGRADE_APPLIED	open	provider	2026-08-06 15:57:39.280155+00	2026-08-05 15:57:39.280155+00	\N	{}
644	PRED-SIM-DA-F01	suwanee_smiles	COVERAGE_PRED_REQUIRED	open	provider	2026-08-06 15:57:39.280155+00	2026-08-05 15:57:39.280155+00	\N	{}
645	PRED-SIM-DA-F01	suwanee_smiles	COVERAGE_SURFACE_MISMATCH	open	provider	2026-08-07 15:57:39.280155+00	2026-08-05 15:57:39.280155+00	\N	{}
646	PRED-SIM-DA-F02	suwanee_smiles	COVERAGE_PRED_REQUIRED	open	provider	2026-08-06 15:57:40.744137+00	2026-08-05 15:57:40.744137+00	\N	{}
647	PRED-SIM-DA-F02	suwanee_smiles	CLINICAL_CRITERIA_NOT_MET	open	provider	2026-08-08 15:57:40.744137+00	2026-08-05 15:57:40.744137+00	\N	{}
648	PRED-SIM-DA-F02	suwanee_smiles	CLINICAL_POCKET_DEPTH	open	provider	2026-08-08 15:57:40.744137+00	2026-08-05 15:57:40.744137+00	\N	{}
649	PRED-SIM-DA-F02	suwanee_smiles	CLINICAL_BONE_LOSS_THRESHOLD	open	provider	2026-08-08 15:57:40.744137+00	2026-08-05 15:57:40.744137+00	\N	{}
650	PRED-SIM-DA-F02	suwanee_smiles	CLINICAL_XRAY_REQUIRED	open	provider	2026-08-07 15:57:40.744137+00	2026-08-05 15:57:40.744137+00	\N	{}
651	PRED-SIM-DA-F03	suwanee_smiles	ELIG_FREQUENCY_LIMIT	open	provider	2026-08-06 15:57:42.492129+00	2026-08-05 15:57:42.492129+00	\N	{}
652	PRED-SIM-DA-F04	suwanee_smiles	COVERAGE_BUNDLING_CONFLICT	open	provider	2026-08-06 15:57:44.128905+00	2026-08-05 15:57:44.128905+00	\N	{}
653	PRED-SIM-DA-F04	suwanee_smiles	COVERAGE_PRED_REQUIRED	open	provider	2026-08-06 15:57:44.128905+00	2026-08-05 15:57:44.128905+00	\N	{}
654	PRED-SIM-DA-F05	suwanee_smiles	COVERAGE_PRED_REQUIRED	open	provider	2026-08-06 15:57:45.699614+00	2026-08-05 15:57:45.699614+00	\N	{}
655	PRED-SIM-DA-C06	suwanee_smiles	COVERAGE_PRED_REQUIRED	open	provider	2026-08-06 15:57:47.14814+00	2026-08-05 15:57:47.14814+00	\N	{}
656	PRED-SIM-DA-C08	suwanee_smiles	COVERAGE_PRED_REQUIRED	open	provider	2026-08-06 15:57:50.14408+00	2026-08-05 15:57:50.14408+00	\N	{}
657	PRED-SIM-DA-C08	suwanee_smiles	ELIG_COB_REQUIRED	open	provider	2026-08-07 15:57:50.14408+00	2026-08-05 15:57:50.14408+00	\N	{}
658	PRED-SIM-DA-C08	suwanee_smiles	ADMIN_COB_PRIMARY_FIRST	open	provider	2026-08-07 15:57:50.14408+00	2026-08-05 15:57:50.14408+00	\N	{}
659	PRED-SIM-DA-C09	suwanee_smiles	COVERAGE_PRED_REQUIRED	open	provider	2026-08-06 15:57:51.623137+00	2026-08-05 15:57:51.623137+00	\N	{}
660	PRED-SIM-DA-C09	suwanee_smiles	CLINICAL_MEDICAL_HISTORY_FLAG	open	\N	2026-08-07 15:57:51.623137+00	2026-08-05 15:57:51.623137+00	\N	{}
661	PRED-SIM-DA-C10	suwanee_smiles	COVERAGE_PRED_REQUIRED	open	provider	2026-08-06 15:57:54.182723+00	2026-08-05 15:57:54.182723+00	\N	{}
662	PRED-SIM-DA-C10	suwanee_smiles	PROVIDER_OIG_EXCLUDED	open	\N	2026-08-07 15:57:54.182723+00	2026-08-05 15:57:54.182723+00	\N	{}
\.


--
-- Data for Name: pred_requests; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.pred_requests (pred_request_id, tenant_id, patient_id, provider_npi, payer_id, plan_type, pred_number, status, decision, total_case_value, submitted_at, created_at, updated_at, plan_id) FROM stdin;
PRED-SIM-DA-C01	suwanee_smiles	PAT-DA-C01	1134534266	delta_dental	PPO	\N	assembled	pended	3750.00	\N	2026-08-05 15:57:14.425136+00	2026-08-05 16:18:16.697916+00	delta_ppo
PRED-SIM-DA-A01	suwanee_smiles	PAT-DA-A01	1134534266	delta_dental	PPO	\N	assembled	pended	5550.00	\N	2026-08-05 15:56:58.909642+00	2026-08-05 16:18:02.438425+00	delta_ppo
PRED-SIM-DL-A01	dallas_dental	PAT-DL-A01	0987654321	guardian_dpo	DPPO	\N	assembled	approved	4600.00	\N	2026-08-06 13:35:54.923203+00	2026-08-06 13:35:56.436214+00	guardian_dppo
PRED-SIM-DA-A02	suwanee_smiles	PAT-DA-A02	1134534266	delta_dental	PPO	\N	assembled	approved	1450.00	\N	2026-08-05 15:57:01.029629+00	2026-08-05 16:18:03.944948+00	delta_ppo
PRED-SIM-DA-C02	suwanee_smiles	PAT-DA-C02	1134534266	delta_dental	PPO	\N	assembled	pended	1850.00	\N	2026-08-05 15:57:15.765122+00	2026-08-05 16:18:18.229924+00	delta_ppo
PRED-SIM-DA-A03	suwanee_smiles	PAT-DA-A03	1134534266	delta_dental	PPO	\N	assembled	approved	2650.00	\N	2026-08-05 15:57:02.750744+00	2026-08-05 16:18:05.379176+00	delta_ppo
PRED-SIM-DA-M02	suwanee_smiles	PAT-DA-M02	1134534266	delta_dental	PPO	\N	assembled	pended	1850.00	\N	2026-08-05 15:57:32.074634+00	2026-08-05 16:18:35.057407+00	delta_ppo
PRED-SIM-DA-A04	suwanee_smiles	PAT-DA-A04	1134534266	delta_dental	PPO	\N	assembled	approved	1140.00	\N	2026-08-05 15:57:04.292931+00	2026-08-05 16:18:06.838909+00	delta_ppo
PRED-SIM-DA-C03	suwanee_smiles	PAT-DA-C03	1134534266	delta_dental	PPO	\N	assembled	pended	18400.00	\N	2026-08-05 15:57:17.255892+00	2026-08-05 16:18:19.821676+00	delta_ppo
PRED-SIM-DA-A05	suwanee_smiles	PAT-DA-A05	1134534266	delta_dental	PPO	\N	assembled	approved	195.00	\N	2026-08-05 15:57:05.69013+00	2026-08-05 16:18:07.969712+00	delta_ppo
PRED-SIM-DA-B01	suwanee_smiles	PAT-DA-B01	1134534266	delta_dental	PPO	\N	assembled	denied	4600.00	\N	2026-08-05 15:57:06.852621+00	2026-08-05 16:18:09.416916+00	delta_ppo
PRED-SIM-DA-C04	suwanee_smiles	PAT-DA-C04	1134534266	delta_dental	PPO	\N	assembled	pended	1450.00	\N	2026-08-05 15:57:18.853135+00	2026-08-05 16:18:21.090155+00	delta_ppo
PRED-SIM-DA-B02	suwanee_smiles	PAT-DA-B02	1134534266	delta_dental	PPO	\N	assembled	denied	4600.00	\N	2026-08-05 15:57:08.300928+00	2026-08-05 16:18:10.853931+00	delta_ppo
PRED-SIM-DA-B03	suwanee_smiles	PAT-DA-B03	1134534266	delta_dental	PPO	\N	assembled	denied	1450.00	\N	2026-08-05 15:57:09.797003+00	2026-08-05 16:18:12.491165+00	delta_ppo
PRED-SIM-DA-C05	suwanee_smiles	PAT-DA-C05	1134534266	delta_dental	PPO	\N	assembled	pended	1450.00	\N	2026-08-05 15:57:20.109875+00	2026-08-05 16:18:23.046168+00	delta_ppo
PRED-SIM-DA-B04	suwanee_smiles	PAT-DA-B04	1134534266	delta_dental	PPO	\N	assembled	pended	3750.00	\N	2026-08-05 15:57:11.445153+00	2026-08-05 16:18:13.958419+00	delta_ppo
PRED-SIM-DA-B05	suwanee_smiles	PAT-DA-B05	1134534266	delta_dental	PPO	\N	assembled	denied	1450.00	\N	2026-08-05 15:57:12.942877+00	2026-08-05 16:18:15.361917+00	delta_ppo
PRED-SIM-DA-D01	suwanee_smiles	PAT-DA-D01	1134534266	delta_dental	PPO	\N	assembled	pended	5600.00	\N	2026-08-05 15:57:21.777646+00	2026-08-05 16:18:25.37218+00	delta_ppo
PRED-SIM-DA-D02	suwanee_smiles	PAT-DA-D02	1134534266	delta_dental	PPO	\N	assembled	pended	35200.00	\N	2026-08-05 15:57:23.510866+00	2026-08-05 16:18:27.323149+00	delta_ppo
PRED-SIM-DA-D03	suwanee_smiles	PAT-DA-D03	1134534266	delta_dental	PPO	\N	assembled	denied	4600.00	\N	2026-08-05 15:57:25.509634+00	2026-08-05 16:18:28.802161+00	delta_ppo
PRED-SIM-DA-D04	suwanee_smiles	PAT-DA-D04	1134534266	delta_dental	PPO	\N	assembled	approved	1650.00	\N	2026-08-05 15:57:26.973641+00	2026-08-05 16:18:30.310665+00	delta_ppo
PRED-SIM-DA-D05	suwanee_smiles	PAT-DA-D05	1134534266	delta_dental	PPO	\N	assembled	approved	3750.00	\N	2026-08-05 15:57:28.474904+00	2026-08-05 16:18:31.956717+00	delta_ppo
PRED-SIM-DA-M01	suwanee_smiles	PAT-DA-M01	1134534266	delta_dental	PPO	\N	assembled	pended	1450.00	\N	2026-08-05 15:57:30.24734+00	2026-08-05 16:18:33.592414+00	delta_ppo
PRED-SIM-TB-A01	tampa_smiles	PAT-TB-A01	1234567890	humana_dpo	DPPO	\N	assembled	approved	1400.00	\N	2026-08-06 13:35:18.092725+00	2026-08-06 13:35:19.820225+00	humana_dppo
PRED-SIM-TB-B01	tampa_smiles	PAT-TB-B01	1234567890	aetna_dmo	DMO	\N	assembled	denied	2800.00	\N	2026-08-06 13:35:19.933487+00	2026-08-06 13:35:21.39647+00	aetna_dmo
PRED-SIM-TB-C01	tampa_smiles	PAT-TB-C01	1234567890	guardian_dpo	DPPO	\N	assembled	pended	840.00	\N	2026-08-06 13:35:21.49022+00	2026-08-06 13:35:22.825972+00	guardian_dppo
PRED-SIM-TB-D01	tampa_smiles	PAT-TB-D01	1234567890	aetna_dmo	DMO	\N	assembled	approved	1650.00	\N	2026-08-06 13:35:22.924736+00	2026-08-06 13:35:24.425971+00	aetna_dmo
PRED-SIM-TB-U01	tampa_smiles	PAT-TB-U01	1234567890	humana_dpo	DPPO	\N	assembled	approved	150.00	\N	2026-08-06 13:35:24.523765+00	2026-08-06 13:35:25.735976+00	humana_dppo
PRED-SIM-DL-B01	dallas_dental	PAT-DL-B01	0987654321	guardian_dpo	DPPO	\N	assembled	denied	1200.00	\N	2026-08-06 13:35:56.529971+00	2026-08-06 13:35:58.060735+00	guardian_dppo
PRED-SIM-DL-C01	dallas_dental	PAT-DL-C01	0987654321	delta_dental	PPO	\N	assembled	denied	1500.00	\N	2026-08-06 13:35:58.157978+00	2026-08-06 13:35:59.82145+00	delta_ppo
PRED-SIM-DL-D01	dallas_dental	PAT-DL-D01	0987654321	humana_dpo	DPPO	\N	assembled	denied	4500.00	\N	2026-08-06 13:35:59.914726+00	2026-08-06 13:36:01.597726+00	humana_dppo
PRED-SIM-DL-U01	dallas_dental	PAT-DL-U01	0987654321	guardian_dpo	DPPO	\N	assembled	approved	185.00	\N	2026-08-06 13:36:01.696464+00	2026-08-06 13:36:03.127465+00	guardian_dppo
PRED-SIM-DA-U04	suwanee_smiles	PAT-DA-U04	1134534266	metlife	PDP	\N	assembled	approved	185.00	\N	2026-08-06 05:18:45.936477+00	2026-08-06 05:18:47.124457+00	metlife_pdp
PRED-SIM-DA-M03	suwanee_smiles	PAT-DA-M03	1134534266	delta_dental	PPO	\N	assembled	pended	1450.00	\N	2026-08-05 15:57:33.549621+00	2026-08-05 16:18:36.480404+00	delta_ppo
PRED-SIM-DA-M04	suwanee_smiles	PAT-DA-M04	1134534266	delta_dental	PPO	\N	assembled	pended	2800.00	\N	2026-08-05 15:57:34.978396+00	2026-08-05 16:18:38.10473+00	delta_ppo
PRED-SIM-DA-U05	suwanee_smiles	PAT-DA-U05	1134534266	delta_dental	PPO	\N	assembled	approved	175.00	\N	2026-08-06 05:18:47.217813+00	2026-08-06 05:18:48.776976+00	delta_ppo
PRED-SIM-DA-M05	suwanee_smiles	PAT-DA-M05	1134534266	delta_dental	PPO	\N	assembled	pended	1450.00	\N	2026-08-05 15:57:36.60265+00	2026-08-05 16:18:39.538426+00	delta_ppo
PRED-SIM-DA-F01	suwanee_smiles	PAT-DA-F01	1134534266	delta_dental	PPO	\N	assembled	pended	1650.00	\N	2026-08-05 15:57:38.050889+00	2026-08-05 16:18:40.978909+00	delta_ppo
PRED-SIM-DA-F02	suwanee_smiles	PAT-DA-F02	1134534266	delta_dental	PPO	\N	assembled	denied	1850.00	\N	2026-08-05 15:57:39.512932+00	2026-08-05 16:18:42.458148+00	delta_ppo
PRED-SIM-DA-F03	suwanee_smiles	PAT-DA-F03	1134534266	delta_dental	PPO	\N	assembled	denied	1450.00	\N	2026-08-05 15:57:41.020436+00	2026-08-05 16:18:44.044403+00	delta_ppo
PRED-SIM-DA-F04	suwanee_smiles	PAT-DA-F04	1134534266	delta_dental	PPO	\N	assembled	pended	1450.00	\N	2026-08-05 15:57:42.692313+00	2026-08-05 16:18:45.671634+00	delta_ppo
PRED-SIM-DA-F05	suwanee_smiles	PAT-DA-F05	1134534266	delta_dental	PPO	\N	assembled	pended	2800.00	\N	2026-08-05 15:57:44.350905+00	2026-08-05 16:18:47.074232+00	delta_ppo
PRED-SIM-DA-C06	suwanee_smiles	PAT-DA-C06	1134534266	cigna	DPPO	\N	assembled	approved	1250.00	\N	2026-08-05 15:57:45.898875+00	2026-08-05 16:18:48.500754+00	cigna_dppo
PRED-SIM-DA-C07	suwanee_smiles	PAT-DA-C07	1134534266	metlife	PDP	\N	assembled	approved	155.00	\N	2026-08-05 15:57:47.348128+00	2026-08-05 16:18:49.800913+00	metlife_pdp
PRED-SIM-DA-C08	suwanee_smiles	PAT-DA-C08	1134534266	delta_dental	PPO	\N	assembled	pended	1190.00	\N	2026-08-05 15:57:48.694125+00	2026-08-05 16:18:51.431655+00	delta_ppo
PRED-SIM-DA-C09	suwanee_smiles	PAT-DA-C09	1134534266	delta_dental	PPO	\N	assembled	pended	1985.00	\N	2026-08-05 15:57:50.376384+00	2026-08-05 16:18:52.841654+00	delta_ppo
PRED-SIM-DA-C10	suwanee_smiles	PAT-DA-C10	0000000001	delta_dental	PPO	\N	assembled	pended	1190.00	\N	2026-08-05 15:57:51.837654+00	2026-08-05 16:18:54.551397+00	delta_ppo
PRED-SIM-DA-U01	suwanee_smiles	PAT-DA-U01	1134534266	delta_dental	PPO	\N	assembled	approved	150.00	\N	2026-08-06 05:18:41.487018+00	2026-08-06 05:18:43.032729+00	delta_ppo
PRED-SIM-DA-U02	suwanee_smiles	PAT-DA-U02	1134534266	delta_dental	PPO	\N	assembled	approved	85.00	\N	2026-08-06 05:18:43.144992+00	2026-08-06 05:18:44.57124+00	delta_ppo
PRED-SIM-DA-U03	suwanee_smiles	PAT-DA-U03	1134534266	cigna	DPPO	\N	assembled	approved	175.00	\N	2026-08-06 05:18:44.66544+00	2026-08-06 05:18:45.843755+00	cigna_dppo
\.


--
-- Data for Name: pred_states; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.pred_states (pred_request_id, tenant_id, coverage_active, annual_max_remaining, implant_covered, waiting_period_met, missing_tooth_clause_triggered, pred_required, criteria_score, medical_necessity_met, clinical_evidence_count, criteria_met_count, criteria_total_count, missing_evidence, no_critical_conflicts, has_bundling_conflict, conflict_count, conflicts, readiness_flags, status, decision, decision_confidence, requires_human_review, auto_decision_eligible, open_conditions, decision_trace, updated_at, provider_npi_valid, provider_oig_excluded, provider_specialty, submission_ready) FROM stdin;
PRED-SIM-DA-A05	suwanee_smiles	t	1800.00	f	t	f	f	1.000	t	0	0	0	[]	t	f	0	[]	{"xray_present": true, "downgrade_noted": true, "deductible_known": true, "no_fraud_signals": true, "bundling_reviewed": true, "narrative_present": true, "provider_verified": true, "frequency_limit_ok": true, "waiting_period_met": true, "perio_chart_present": true, "eligibility_verified": true, "pre_d_required_noted": true, "annual_max_sufficient": true, "clinical_note_present": false}	\N	approved	\N	f	t	[]	[{"finding": "Coverage active (PPO), annual maximum remaining $1,800.00", "evidence": ["INS-DA-A05-CARD-D02", "X12-DA-A05-271-D01"], "dimension": "eligibility", "explanation": "The patient's plan is active with $1,800.00 left against this year's maximum.", "policy_citation": "Delta Dental PPO plan certificate â€” eligibility provisions", "recommended_action": "None â€” eligibility confirmed."}, {"finding": "Missing tooth clause present on plan â€” payer confirmation: NOT confirmed", "evidence": ["INS-DA-A05-CARD-D02", "X12-DA-A05-271-D01"], "dimension": "eligibility", "explanation": "The plan carries a missing tooth clause, but the payer has not confirmed it applies to this tooth, so it is not being enforced against these procedures.", "policy_citation": "Delta Dental PPO plan certificate â€” missing tooth provision", "recommended_action": "Confirm the extraction date and whether the clause applies with the payer before submitting."}, {"finding": "D0330 approved", "evidence": ["PMS-DA-A05-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D0330 is covered at 100% with no conflicts detected.", "policy_citation": "Delta Dental PPO policy section D.1.4", "recommended_action": "None â€” ready to submit."}]	2026-08-05T16:18:07.001271	t	f	\N	f
PRED-SIM-DA-B01	suwanee_smiles	t	1500.00	f	t	f	t	0.700	t	1	2	4	[]	f	f	0	[]	{"xray_present": true, "downgrade_noted": true, "deductible_known": true, "no_fraud_signals": true, "bundling_reviewed": true, "narrative_present": true, "provider_verified": true, "frequency_limit_ok": true, "waiting_period_met": true, "perio_chart_present": true, "eligibility_verified": true, "pre_d_required_noted": true, "annual_max_sufficient": true, "clinical_note_present": false}	\N	denied	\N	t	f	["ELIG_IMPLANT_NOT_COVERED"]	[{"finding": "Coverage active (PPO), annual maximum remaining $1,500.00", "evidence": ["INS-DA-B01-CARD-D03", "X12-DA-B01-271-D01"], "dimension": "eligibility", "explanation": "The patient's plan is active with $1,500.00 left against this year's maximum.", "policy_citation": "Delta Dental PPO plan certificate â€” eligibility provisions", "recommended_action": "None â€” eligibility confirmed."}, {"finding": "Implant benefit excluded on this plan (applies to D6010, D6065)", "evidence": ["INS-DA-B01-CARD-D03", "X12-DA-B01-271-D01"], "dimension": "eligibility", "explanation": "This plan excludes implant services, so D6010, D6065 will be denied outright.", "policy_citation": "Delta Dental PPO plan certificate â€” implant benefit provisions", "recommended_action": "Present the patient with self-pay options; an appeal will not overcome a plan exclusion."}, {"finding": "Missing tooth clause present on plan â€” payer confirmation: NOT confirmed", "evidence": ["INS-DA-B01-CARD-D03", "X12-DA-B01-271-D01"], "dimension": "eligibility", "explanation": "The plan carries a missing tooth clause, but the payer has not confirmed it applies to this tooth, so it is not being enforced against these procedures.", "policy_citation": "Delta Dental PPO plan certificate â€” missing tooth provision", "recommended_action": "Confirm the extraction date and whether the clause applies with the payer before submitting."}, {"finding": "D6010 denied â€” pre-determination required", "evidence": ["PMS-DA-B01-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D6010 is not a covered benefit under this plan.", "policy_citation": "Delta Dental PPO policy section D.7.1", "recommended_action": "Discuss self-pay with the patient, or add a tenant overlay rule if the practice has negotiated different terms."}, {"finding": "D6065 denied â€” pre-determination required", "evidence": ["PMS-DA-B01-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D6065 is not a covered benefit under this plan.", "policy_citation": "Delta Dental PPO policy section D.7.2", "recommended_action": "Discuss self-pay with the patient, or add a tenant overlay rule if the practice has negotiated different terms."}, {"finding": "Radiographic bone loss 4.2mm (35.0% of root support)", "evidence": ["XRAY-DA-B01-D02"], "dimension": "clinical", "explanation": "The X-ray documents 4.2mm of bone loss, meeting the 3mm the payer requires to establish graft and implant necessity.", "policy_citation": "ADA clinical criteria â€” radiographic evidence (PRD section 11)", "recommended_action": "None â€” radiographic threshold met."}, {"finding": "D6010 criteria score 0.700 â€” pend â€” needs additional documentation", "evidence": ["XRAY-DA-B01-D02"], "dimension": "clinical", "explanation": "Weighted clinical criteria for D6010 scored 0.700, which the payer reads as pend â€” needs additional documentation.", "policy_citation": "ADA clinical criteria â€” implant placement (PRD section 11)", "recommended_action": "All required criteria for D6010 are met; add the optional supporting evidence (e.g. CBCT) to raise the score above the 0.85 auto-approve threshold."}]	2026-08-05T16:18:08.155231	t	f	\N	f
PRED-SIM-DA-C03	suwanee_smiles	t	1800.00	t	t	f	t	0.900	t	2	14	16	[]	t	f	0	[]	{"xray_present": false, "downgrade_noted": true, "deductible_known": true, "no_fraud_signals": true, "bundling_reviewed": true, "narrative_present": true, "provider_verified": true, "frequency_limit_ok": true, "waiting_period_met": true, "perio_chart_present": true, "eligibility_verified": true, "pre_d_required_noted": true, "annual_max_sufficient": true, "clinical_note_present": true}	\N	pended	\N	t	f	["COVERAGE_PRED_REQUIRED", "CLINICAL_CBCT_REQUIRED", "COVERAGE_DOWNGRADE_APPLIED"]	[{"finding": "Coverage active (PPO), annual maximum remaining $1,800.00", "evidence": ["X12-DA-C03-271-D01"], "dimension": "eligibility", "explanation": "The patient's plan is active with $1,800.00 left against this year's maximum.", "policy_citation": "Delta Dental PPO plan certificate â€” eligibility provisions", "recommended_action": "None â€” eligibility confirmed."}, {"finding": "Implant benefit present on this plan (applies to D6010, D6010, D6010, D6010, D6065, D6065, D6065, D6065)", "evidence": ["X12-DA-C03-271-D01"], "dimension": "eligibility", "explanation": "This plan pays implant services at 50%, so D6010, D6010, D6010, D6010, D6065, D6065, D6065, D6065 can be considered.", "policy_citation": "Delta Dental PPO plan certificate â€” implant benefit provisions", "recommended_action": "None â€” implant benefit confirmed."}, {"finding": "Missing tooth clause present on plan â€” payer confirmation: NOT confirmed", "evidence": ["X12-DA-C03-271-D01"], "dimension": "eligibility", "explanation": "The plan carries a missing tooth clause, but the payer has not confirmed it applies to this tooth, so it is not being enforced against these procedures.", "policy_citation": "Delta Dental PPO plan certificate â€” missing tooth provision", "recommended_action": "Confirm the extraction date and whether the clause applies with the payer before submitting."}, {"finding": "D6010 pended â€” pre-determination required", "evidence": ["PMS-DA-C03-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D6010 is covered at 50%, but the payer requires pre-determination before treatment.", "policy_citation": "Delta Dental PPO policy section D.7.1", "recommended_action": "Submit the pre-D and wait for written approval before scheduling."}, {"finding": "D6010 pended â€” pre-determination required", "evidence": ["PMS-DA-C03-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D6010 is covered at 50%, but the payer requires pre-determination before treatment.", "policy_citation": "Delta Dental PPO policy section D.7.1", "recommended_action": "Submit the pre-D and wait for written approval before scheduling."}, {"finding": "D6010 pended â€” pre-determination required", "evidence": ["PMS-DA-C03-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D6010 is covered at 50%, but the payer requires pre-determination before treatment.", "policy_citation": "Delta Dental PPO policy section D.7.1", "recommended_action": "Submit the pre-D and wait for written approval before scheduling."}, {"finding": "D6010 pended â€” pre-determination required", "evidence": ["PMS-DA-C03-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D6010 is covered at 50%, but the payer requires pre-determination before treatment.", "policy_citation": "Delta Dental PPO policy section D.7.1", "recommended_action": "Submit the pre-D and wait for written approval before scheduling."}, {"finding": "D6065 pended â€” downgraded to D2750; pre-determination required", "evidence": ["PMS-DA-C03-SUPERBILL-D00"], "dimension": "coverage", "explanation": "The plan reimburses D6065 at the D2750 fee schedule, so the patient owes the difference.", "policy_citation": "Delta Dental PPO policy section D.7.2", "recommended_action": "Give the patient a written estimate of the D6065-to-D2750 difference before treatment."}, {"finding": "D6065 pended â€” downgraded to D2750; pre-determination required", "evidence": ["PMS-DA-C03-SUPERBILL-D00"], "dimension": "coverage", "explanation": "The plan reimburses D6065 at the D2750 fee schedule, so the patient owes the difference.", "policy_citation": "Delta Dental PPO policy section D.7.2", "recommended_action": "Give the patient a written estimate of the D6065-to-D2750 difference before treatment."}, {"finding": "D6065 pended â€” downgraded to D2750; pre-determination required", "evidence": ["PMS-DA-C03-SUPERBILL-D00"], "dimension": "coverage", "explanation": "The plan reimburses D6065 at the D2750 fee schedule, so the patient owes the difference.", "policy_citation": "Delta Dental PPO policy section D.7.2", "recommended_action": "Give the patient a written estimate of the D6065-to-D2750 difference before treatment."}, {"finding": "D6065 pended â€” downgraded to D2750; pre-determination required", "evidence": ["PMS-DA-C03-SUPERBILL-D00"], "dimension": "coverage", "explanation": "The plan reimburses D6065 at the D2750 fee schedule, so the patient owes the difference.", "policy_citation": "Delta Dental PPO policy section D.7.2", "recommended_action": "Give the patient a written estimate of the D6065-to-D2750 difference before treatment."}, {"finding": "Radiographic bone loss 4.0mm (32.0% of root support)", "evidence": ["PAN-DA-C03-D02"], "dimension": "clinical", "explanation": "The X-ray documents 4.0mm of bone loss, meeting the 3mm the payer requires to establish graft and implant necessity.", "policy_citation": "ADA clinical criteria â€” radiographic evidence (PRD section 11)", "recommended_action": "None â€” radiographic threshold met."}, {"finding": "D6010 criteria score 0.900 â€” sufficient documentation", "evidence": ["NOTE-DA-C03-D03", "PAN-DA-C03-D02"], "dimension": "clinical", "explanation": "Weighted clinical criteria for D6010 scored 0.900, which the payer reads as sufficient documentation.", "policy_citation": "ADA clinical criteria â€” implant placement (PRD section 11)", "recommended_action": "None â€” documentation is sufficient."}]	2026-08-05T16:18:18.533264	t	f	\N	f
PRED-SIM-TB-U01	tampa_smiles	t	1500.00	t	t	f	f	1.000	t	1	0	0	[]	t	f	0	[]	{"xray_present": true, "downgrade_noted": true, "deductible_known": true, "no_fraud_signals": true, "bundling_reviewed": true, "narrative_present": true, "provider_verified": true, "frequency_limit_ok": true, "waiting_period_met": true, "perio_chart_present": true, "eligibility_verified": true, "pre_d_required_noted": true, "annual_max_sufficient": true, "clinical_note_present": true}	\N	approved	\N	f	t	[]	[{"finding": "Coverage active (DPPO), annual maximum remaining $1,500.00", "evidence": ["INS-TB-U01-CARD-D02", "X12-TB-U01-271-D01"], "dimension": "eligibility", "explanation": "The patient's plan is active with $1,500.00 left against this year's maximum.", "policy_citation": "Delta Dental PPO plan certificate â€” eligibility provisions", "recommended_action": "None â€” eligibility confirmed."}, {"finding": "D1110 approved", "evidence": ["PMS-TB-U01-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D1110 is covered at 100% with no conflicts detected.", "policy_citation": "Delta Dental PPO policy section D.2.1", "recommended_action": "None â€” ready to submit."}]	2026-08-06T13:35:24.242906	t	f	\N	t
PRED-SIM-DA-A02	suwanee_smiles	t	1800.00	f	t	f	t	1.000	t	2	2	2	[]	t	f	0	[]	{"xray_present": true, "downgrade_noted": true, "deductible_known": true, "no_fraud_signals": true, "bundling_reviewed": true, "narrative_present": true, "provider_verified": true, "frequency_limit_ok": true, "waiting_period_met": true, "perio_chart_present": true, "eligibility_verified": true, "pre_d_required_noted": true, "annual_max_sufficient": true, "clinical_note_present": true}	\N	approved	\N	t	f	["COVERAGE_PRED_REQUIRED"]	[{"finding": "Coverage active (PPO), annual maximum remaining $1,800.00", "evidence": ["X12-DA-A02-271-D01"], "dimension": "eligibility", "explanation": "The patient's plan is active with $1,800.00 left against this year's maximum.", "policy_citation": "Delta Dental PPO plan certificate â€” eligibility provisions", "recommended_action": "None â€” eligibility confirmed."}, {"finding": "Missing tooth clause present on plan â€” payer confirmation: NOT confirmed", "evidence": ["X12-DA-A02-271-D01"], "dimension": "eligibility", "explanation": "The plan carries a missing tooth clause, but the payer has not confirmed it applies to this tooth, so it is not being enforced against these procedures.", "policy_citation": "Delta Dental PPO plan certificate â€” missing tooth provision", "recommended_action": "Confirm the extraction date and whether the clause applies with the payer before submitting."}, {"finding": "D2750 approved â€” pre-determination required", "evidence": ["PMS-DA-A02-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D2750 is covered at 50%, but the payer requires pre-determination before treatment.", "policy_citation": "Delta Dental PPO policy section D.4.3", "recommended_action": "Submit the pre-D and wait for written approval before scheduling."}, {"finding": "D2750 criteria score 1.000 â€” sufficient documentation", "evidence": ["NOTE-DA-A02-D03", "XRAY-DA-A02-D02"], "dimension": "clinical", "explanation": "Weighted clinical criteria for D2750 scored 1.000, which the payer reads as sufficient documentation.", "policy_citation": "ADA clinical criteria â€” crown restoration (PRD section 11)", "recommended_action": "None â€” documentation is sufficient."}]	2026-08-05T16:18:02.661707	t	f	\N	t
PRED-SIM-DA-A04	suwanee_smiles	t	1800.00	f	t	f	f	1.000	t	2	8	8	[]	t	f	0	[]	{"xray_present": true, "downgrade_noted": true, "deductible_known": true, "no_fraud_signals": true, "bundling_reviewed": true, "narrative_present": true, "provider_verified": true, "frequency_limit_ok": true, "waiting_period_met": true, "perio_chart_present": true, "eligibility_verified": true, "pre_d_required_noted": true, "annual_max_sufficient": true, "clinical_note_present": true}	\N	approved	\N	f	t	[]	[{"finding": "Coverage active (PPO), annual maximum remaining $1,800.00", "evidence": ["X12-DA-A04-271-D01"], "dimension": "eligibility", "explanation": "The patient's plan is active with $1,800.00 left against this year's maximum.", "policy_citation": "Delta Dental PPO plan certificate â€” eligibility provisions", "recommended_action": "None â€” eligibility confirmed."}, {"finding": "Missing tooth clause present on plan â€” payer confirmation: NOT confirmed", "evidence": ["X12-DA-A04-271-D01"], "dimension": "eligibility", "explanation": "The plan carries a missing tooth clause, but the payer has not confirmed it applies to this tooth, so it is not being enforced against these procedures.", "policy_citation": "Delta Dental PPO plan certificate â€” missing tooth provision", "recommended_action": "Confirm the extraction date and whether the clause applies with the payer before submitting."}, {"finding": "D4341 approved", "evidence": ["PMS-DA-A04-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D4341 is covered at 80% with no conflicts detected.", "policy_citation": "Delta Dental PPO policy section D.6.1", "recommended_action": "None â€” ready to submit."}, {"finding": "D4341 approved", "evidence": ["PMS-DA-A04-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D4341 is covered at 80% with no conflicts detected.", "policy_citation": "Delta Dental PPO policy section D.6.1", "recommended_action": "None â€” ready to submit."}, {"finding": "D4341 approved", "evidence": ["PMS-DA-A04-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D4341 is covered at 80% with no conflicts detected.", "policy_citation": "Delta Dental PPO policy section D.6.1", "recommended_action": "None â€” ready to submit."}, {"finding": "D4341 approved", "evidence": ["PMS-DA-A04-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D4341 is covered at 80% with no conflicts detected.", "policy_citation": "Delta Dental PPO policy section D.6.1", "recommended_action": "None â€” ready to submit."}, {"finding": "D4341 criteria score 1.000 â€” sufficient documentation", "evidence": ["NOTE-DA-A04-D03", "PERIO-DA-A04-D02"], "dimension": "clinical", "explanation": "Weighted clinical criteria for D4341 scored 1.000, which the payer reads as sufficient documentation.", "policy_citation": "ADA clinical criteria â€” scaling and root planing (PRD section 11)", "recommended_action": "None â€” documentation is sufficient."}]	2026-08-05T16:18:05.602834	t	f	\N	t
PRED-SIM-DA-B03	suwanee_smiles	t	1800.00	f	t	f	t	0.600	f	1	1	2	["Clinical note"]	f	f	1	[]	{"xray_present": true, "downgrade_noted": true, "deductible_known": true, "no_fraud_signals": true, "bundling_reviewed": true, "narrative_present": true, "provider_verified": true, "frequency_limit_ok": false, "waiting_period_met": true, "perio_chart_present": true, "eligibility_verified": true, "pre_d_required_noted": true, "annual_max_sufficient": true, "clinical_note_present": false}	\N	denied	\N	t	f	["ELIG_FREQUENCY_LIMIT", "CLINICAL_NARRATIVE_REQUIRED"]	[{"finding": "Coverage active (PPO), annual maximum remaining $1,800.00", "evidence": ["INS-DA-B03-CARD-D03", "X12-DA-B03-271-D01"], "dimension": "eligibility", "explanation": "The patient's plan is active with $1,800.00 left against this year's maximum.", "policy_citation": "Delta Dental PPO plan certificate â€” eligibility provisions", "recommended_action": "None â€” eligibility confirmed."}, {"finding": "Missing tooth clause present on plan â€” payer confirmation: NOT confirmed", "evidence": ["INS-DA-B03-CARD-D03", "X12-DA-B03-271-D01"], "dimension": "eligibility", "explanation": "The plan carries a missing tooth clause, but the payer has not confirmed it applies to this tooth, so it is not being enforced against these procedures.", "policy_citation": "Delta Dental PPO plan certificate â€” missing tooth provision", "recommended_action": "Confirm the extraction date and whether the clause applies with the payer before submitting."}, {"finding": "D2750 denied â€” frequency limit exceeded; pre-determination required", "evidence": ["HIST-DA-B03-PRIOR-D00", "PMS-DA-B03-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D2750 is covered at 50%, but the payer requires pre-determination before treatment.", "policy_citation": "Delta Dental PPO policy section D.4.3", "recommended_action": "Submit the pre-D and wait for written approval before scheduling."}, {"finding": "D2750 criteria score 0.600 â€” review required â€” significant gaps", "evidence": ["XRAY-DA-B03-D02"], "dimension": "clinical", "explanation": "Weighted clinical criteria for D2750 scored 0.600, which the payer reads as review required â€” significant gaps.", "policy_citation": "ADA clinical criteria â€” crown restoration (PRD section 11)", "recommended_action": "Attach the missing required evidence for D2750: Clinical note."}, {"finding": "Missing required evidence: Clinical note", "evidence": ["XRAY-DA-B03-D02"], "dimension": "clinical", "explanation": "One or more required clinical criteria have no supporting document on file.", "policy_citation": "ADA clinical criteria â€” required documentation (PRD section 11)", "recommended_action": "Attach: Clinical note."}]	2026-08-05T16:18:11.043191	t	f	\N	f
PRED-SIM-DA-B04	suwanee_smiles	t	1800.00	t	t	f	t	0.850	t	2	5	7	[]	t	t	1	[]	{"xray_present": true, "downgrade_noted": true, "deductible_known": true, "no_fraud_signals": true, "bundling_reviewed": false, "narrative_present": true, "provider_verified": true, "frequency_limit_ok": true, "waiting_period_met": true, "perio_chart_present": true, "eligibility_verified": true, "pre_d_required_noted": true, "annual_max_sufficient": true, "clinical_note_present": true}	\N	pended	\N	t	f	["COVERAGE_PRED_REQUIRED", "COVERAGE_BUNDLING_CONFLICT", "CLINICAL_XRAY_REQUIRED", "CLINICAL_NARRATIVE_REQUIRED"]	[{"finding": "Coverage active (PPO), annual maximum remaining $1,800.00", "evidence": ["X12-DA-B04-271-D01"], "dimension": "eligibility", "explanation": "The patient's plan is active with $1,800.00 left against this year's maximum.", "policy_citation": "Delta Dental PPO plan certificate â€” eligibility provisions", "recommended_action": "None â€” eligibility confirmed."}, {"finding": "Implant benefit present on this plan (applies to D6010, D7953)", "evidence": ["X12-DA-B04-271-D01"], "dimension": "eligibility", "explanation": "This plan pays implant services at 50%, so D6010, D7953 can be considered.", "policy_citation": "Delta Dental PPO plan certificate â€” implant benefit provisions", "recommended_action": "None â€” implant benefit confirmed."}, {"finding": "Missing tooth clause present on plan â€” payer confirmation: NOT confirmed", "evidence": ["X12-DA-B04-271-D01"], "dimension": "eligibility", "explanation": "The plan carries a missing tooth clause, but the payer has not confirmed it applies to this tooth, so it is not being enforced against these procedures.", "policy_citation": "Delta Dental PPO plan certificate â€” missing tooth provision", "recommended_action": "Confirm the extraction date and whether the clause applies with the payer before submitting."}, {"finding": "D6010 approved â€” pre-determination required", "evidence": ["PMS-DA-B04-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D6010 is covered at 50%, but the payer requires pre-determination before treatment.", "policy_citation": "Delta Dental PPO policy section D.7.1", "recommended_action": "Submit the pre-D and wait for written approval before scheduling."}, {"finding": "D7953 pended â€” bundled with D6010; pre-determination required", "evidence": ["PMS-DA-B04-SUPERBILL-D00", "NOTE-DA-B04-D03", "XRAY-DA-B04-D02"], "dimension": "coverage", "explanation": "The payer treats D7953 as part of D6010 unless it is documented as separately necessary.", "policy_citation": "Delta Dental PPO policy section D.7.4", "recommended_action": "Attach a narrative establishing necessity independent of the bundled procedure, plus the supporting X-ray; documented appeals overturn about 65% of the time."}, {"finding": "Radiographic bone loss 4.2mm (35.0% of root support)", "evidence": ["XRAY-DA-B04-D02"], "dimension": "clinical", "explanation": "The X-ray documents 4.2mm of bone loss, meeting the 3mm the payer requires to establish graft and implant necessity.", "policy_citation": "ADA clinical criteria â€” radiographic evidence (PRD section 11)", "recommended_action": "None â€” radiographic threshold met."}, {"finding": "D6010 criteria score 0.900 â€” sufficient documentation", "evidence": ["NOTE-DA-B04-D03", "XRAY-DA-B04-D02"], "dimension": "clinical", "explanation": "Weighted clinical criteria for D6010 scored 0.900, which the payer reads as sufficient documentation.", "policy_citation": "ADA clinical criteria â€” implant placement (PRD section 11)", "recommended_action": "None â€” documentation is sufficient."}, {"finding": "D7953 criteria score 0.800 â€” pend â€” needs additional documentation", "evidence": ["NOTE-DA-B04-D03", "XRAY-DA-B04-D02"], "dimension": "clinical", "explanation": "Weighted clinical criteria for D7953 scored 0.800, which the payer reads as pend â€” needs additional documentation.", "policy_citation": "ADA clinical criteria â€” bone graft / ridge preservation (PRD section 11)", "recommended_action": "All required criteria for D7953 are met; add the optional supporting evidence (e.g. CBCT) to raise the score above the 0.85 auto-approve threshold."}]	2026-08-05T16:18:12.667607	t	f	\N	f
PRED-SIM-DL-A01	dallas_dental	t	1800.00	t	t	f	t	0.900	t	2	3	4	[]	t	f	0	[]	{"xray_present": true, "downgrade_noted": true, "deductible_known": true, "no_fraud_signals": true, "bundling_reviewed": true, "narrative_present": true, "provider_verified": true, "frequency_limit_ok": true, "waiting_period_met": true, "perio_chart_present": true, "eligibility_verified": true, "pre_d_required_noted": true, "annual_max_sufficient": true, "clinical_note_present": true}	\N	approved	\N	t	f	["COVERAGE_PRED_REQUIRED", "COVERAGE_DOWNGRADE_APPLIED"]	[{"finding": "Coverage active (DPPO), annual maximum remaining $1,800.00", "evidence": ["INS-DL-A01-CARD-D04", "X12-DL-A01-271-D01"], "dimension": "eligibility", "explanation": "The patient's plan is active with $1,800.00 left against this year's maximum.", "policy_citation": "Delta Dental PPO plan certificate â€” eligibility provisions", "recommended_action": "None â€” eligibility confirmed."}, {"finding": "Implant benefit present on this plan (applies to D6010, D6065)", "evidence": ["INS-DL-A01-CARD-D04", "X12-DL-A01-271-D01"], "dimension": "eligibility", "explanation": "This plan pays implant services at 50%, so D6010, D6065 can be considered.", "policy_citation": "Delta Dental PPO plan certificate â€” implant benefit provisions", "recommended_action": "None â€” implant benefit confirmed."}, {"finding": "Missing tooth clause present on plan â€” payer confirmation: NOT confirmed", "evidence": ["INS-DL-A01-CARD-D04", "X12-DL-A01-271-D01"], "dimension": "eligibility", "explanation": "The plan carries a missing tooth clause, but the payer has not confirmed it applies to this tooth, so it is not being enforced against these procedures.", "policy_citation": "Delta Dental PPO plan certificate â€” missing tooth provision", "recommended_action": "Confirm the extraction date and whether the clause applies with the payer before submitting."}, {"finding": "D6010 approved â€” pre-determination required", "evidence": ["PMS-DL-A01-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D6010 is covered at 50%, but the payer requires pre-determination before treatment.", "policy_citation": "Delta Dental PPO policy section D.7.1", "recommended_action": "Submit the pre-D and wait for written approval before scheduling."}, {"finding": "D6065 approved â€” downgraded to D2750; pre-determination required", "evidence": ["PMS-DL-A01-SUPERBILL-D00"], "dimension": "coverage", "explanation": "The plan reimburses D6065 at the D2750 fee schedule, so the patient owes the difference.", "policy_citation": "Delta Dental PPO policy section D.7.2", "recommended_action": "Give the patient a written estimate of the D6065-to-D2750 difference before treatment."}, {"finding": "Radiographic bone loss 4.2mm (35.0% of root support)", "evidence": ["XRAY-DL-A01-D02"], "dimension": "clinical", "explanation": "The X-ray documents 4.2mm of bone loss, meeting the 3mm the payer requires to establish graft and implant necessity.", "policy_citation": "ADA clinical criteria â€” radiographic evidence (PRD section 11)", "recommended_action": "None â€” radiographic threshold met."}, {"finding": "D6010 criteria score 0.900 â€” sufficient documentation", "evidence": ["NOTE-DL-A01-D03", "XRAY-DL-A01-D02"], "dimension": "clinical", "explanation": "Weighted clinical criteria for D6010 scored 0.900, which the payer reads as sufficient documentation.", "policy_citation": "ADA clinical criteria â€” implant placement (PRD section 11)", "recommended_action": "None â€” documentation is sufficient."}]	2026-08-06T13:35:54.629917	t	f	\N	t
PRED-SIM-DA-C01	suwanee_smiles	t	1800.00	t	t	f	t	0.250	f	1	1	7	["X-ray showing bone loss >=3mm", "Edentulous site confirmed"]	t	t	1	[]	{"xray_present": false, "downgrade_noted": true, "deductible_known": true, "no_fraud_signals": true, "bundling_reviewed": false, "narrative_present": true, "provider_verified": true, "frequency_limit_ok": true, "waiting_period_met": true, "perio_chart_present": true, "eligibility_verified": true, "pre_d_required_noted": true, "annual_max_sufficient": true, "clinical_note_present": true}	\N	pended	\N	t	f	["COVERAGE_PRED_REQUIRED", "CLINICAL_CRITERIA_NOT_MET", "COVERAGE_BUNDLING_CONFLICT", "CLINICAL_XRAY_REQUIRED", "CLINICAL_NARRATIVE_REQUIRED", "CLINICAL_BONE_LOSS_THRESHOLD"]	[{"finding": "Coverage active (PPO), annual maximum remaining $1,800.00", "evidence": ["X12-DA-C01-271-D01"], "dimension": "eligibility", "explanation": "The patient's plan is active with $1,800.00 left against this year's maximum.", "policy_citation": "Delta Dental PPO plan certificate â€” eligibility provisions", "recommended_action": "None â€” eligibility confirmed."}, {"finding": "Implant benefit present on this plan (applies to D6010, D7953)", "evidence": ["X12-DA-C01-271-D01"], "dimension": "eligibility", "explanation": "This plan pays implant services at 50%, so D6010, D7953 can be considered.", "policy_citation": "Delta Dental PPO plan certificate â€” implant benefit provisions", "recommended_action": "None â€” implant benefit confirmed."}, {"finding": "Missing tooth clause present on plan â€” payer confirmation: NOT confirmed", "evidence": ["X12-DA-C01-271-D01"], "dimension": "eligibility", "explanation": "The plan carries a missing tooth clause, but the payer has not confirmed it applies to this tooth, so it is not being enforced against these procedures.", "policy_citation": "Delta Dental PPO plan certificate â€” missing tooth provision", "recommended_action": "Confirm the extraction date and whether the clause applies with the payer before submitting."}, {"finding": "D6010 pended â€” pre-determination required", "evidence": ["PMS-DA-C01-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D6010 is covered at 50%, but the payer requires pre-determination before treatment.", "policy_citation": "Delta Dental PPO policy section D.7.1", "recommended_action": "Submit the pre-D and wait for written approval before scheduling."}, {"finding": "D7953 pended â€” bundled with D6010; pre-determination required", "evidence": ["PMS-DA-C01-SUPERBILL-D00", "NOTE-DA-C01-D02"], "dimension": "coverage", "explanation": "The payer treats D7953 as part of D6010 unless it is documented as separately necessary.", "policy_citation": "Delta Dental PPO policy section D.7.4", "recommended_action": "Attach a narrative establishing necessity independent of the bundled procedure, plus the supporting X-ray; documented appeals overturn about 65% of the time."}, {"finding": "D6010 criteria score 0.200 â€” insufficient documentation", "evidence": ["NOTE-DA-C01-D02"], "dimension": "clinical", "explanation": "Weighted clinical criteria for D6010 scored 0.200, which the payer reads as insufficient documentation.", "policy_citation": "ADA clinical criteria â€” implant placement (PRD section 11)", "recommended_action": "Attach the missing required evidence for D6010: X-ray showing bone loss >=3mm; Edentulous site confirmed."}, {"finding": "D7953 criteria score 0.300 â€” review required â€” significant gaps", "evidence": ["NOTE-DA-C01-D02"], "dimension": "clinical", "explanation": "Weighted clinical criteria for D7953 scored 0.300, which the payer reads as review required â€” significant gaps.", "policy_citation": "ADA clinical criteria â€” bone graft / ridge preservation (PRD section 11)", "recommended_action": "Attach the missing required evidence for D7953: X-ray showing bone loss >=3mm; Edentulous site confirmed."}, {"finding": "Missing required evidence: X-ray showing bone loss >=3mm; Edentulous site confirmed", "evidence": ["NOTE-DA-C01-D02"], "dimension": "clinical", "explanation": "One or more required clinical criteria have no supporting document on file.", "policy_citation": "ADA clinical criteria â€” required documentation (PRD section 11)", "recommended_action": "Attach: X-ray showing bone loss >=3mm; Edentulous site confirmed."}]	2026-08-05T16:18:15.541454	t	f	\N	f
PRED-SIM-DA-C05	suwanee_smiles	t	1800.00	f	t	f	t	1.000	t	2	2	2	[]	t	f	0	[]	{"xray_present": true, "downgrade_noted": true, "deductible_known": true, "no_fraud_signals": true, "bundling_reviewed": true, "narrative_present": true, "provider_verified": true, "frequency_limit_ok": true, "waiting_period_met": true, "perio_chart_present": true, "eligibility_verified": true, "pre_d_required_noted": true, "annual_max_sufficient": true, "clinical_note_present": true}	\N	pended	\N	t	f	["COVERAGE_PRED_REQUIRED", "ELIG_COB_REQUIRED", "ADMIN_COB_PRIMARY_FIRST"]	[{"finding": "Coverage active (PPO), annual maximum remaining $1,800.00", "evidence": ["INS-DA-C05-CARD-D04", "X12-DA-C05-271-D01"], "dimension": "eligibility", "explanation": "The patient's plan is active with $1,800.00 left against this year's maximum.", "policy_citation": "Delta Dental PPO plan certificate â€” eligibility provisions", "recommended_action": "None â€” eligibility confirmed."}, {"finding": "Missing tooth clause present on plan â€” payer confirmation: NOT confirmed", "evidence": ["INS-DA-C05-CARD-D04", "X12-DA-C05-271-D01"], "dimension": "eligibility", "explanation": "The plan carries a missing tooth clause, but the payer has not confirmed it applies to this tooth, so it is not being enforced against these procedures.", "policy_citation": "Delta Dental PPO plan certificate â€” missing tooth provision", "recommended_action": "Confirm the extraction date and whether the clause applies with the payer before submitting."}, {"finding": "D2750 pended â€” pre-determination required", "evidence": ["PMS-DA-C05-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D2750 is covered at 50%, but the payer requires pre-determination before treatment.", "policy_citation": "Delta Dental PPO policy section D.4.3", "recommended_action": "Submit the pre-D and wait for written approval before scheduling."}, {"finding": "D2750 criteria score 1.000 â€” sufficient documentation", "evidence": ["NOTE-DA-C05-D03", "XRAY-DA-C05-D02"], "dimension": "clinical", "explanation": "Weighted clinical criteria for D2750 scored 1.000, which the payer reads as sufficient documentation.", "policy_citation": "ADA clinical criteria â€” crown restoration (PRD section 11)", "recommended_action": "None â€” documentation is sufficient."}]	2026-08-05T16:18:21.252469	t	f	\N	t
PRED-SIM-DL-C01	dallas_dental	t	1800.00	f	t	f	t	1.000	t	2	2	2	[]	f	f	1	[]	{"xray_present": true, "downgrade_noted": true, "deductible_known": true, "no_fraud_signals": true, "bundling_reviewed": true, "narrative_present": true, "provider_verified": true, "frequency_limit_ok": false, "waiting_period_met": true, "perio_chart_present": true, "eligibility_verified": true, "pre_d_required_noted": true, "annual_max_sufficient": true, "clinical_note_present": true}	\N	denied	\N	t	f	["ELIG_FREQUENCY_LIMIT"]	[{"finding": "Coverage active (PPO), annual maximum remaining $1,800.00", "evidence": ["INS-DL-C01-CARD-D04", "X12-DL-C01-271-D01"], "dimension": "eligibility", "explanation": "The patient's plan is active with $1,800.00 left against this year's maximum.", "policy_citation": "Delta Dental PPO plan certificate â€” eligibility provisions", "recommended_action": "None â€” eligibility confirmed."}, {"finding": "Missing tooth clause present on plan â€” payer confirmation: NOT confirmed", "evidence": ["INS-DL-C01-CARD-D04", "X12-DL-C01-271-D01"], "dimension": "eligibility", "explanation": "The plan carries a missing tooth clause, but the payer has not confirmed it applies to this tooth, so it is not being enforced against these procedures.", "policy_citation": "Delta Dental PPO plan certificate â€” missing tooth provision", "recommended_action": "Confirm the extraction date and whether the clause applies with the payer before submitting."}, {"finding": "D2750 denied â€” frequency limit exceeded; pre-determination required", "evidence": ["HIST-DL-C01-PRIOR-D00", "PMS-DL-C01-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D2750 is covered at 50%, but the payer requires pre-determination before treatment.", "policy_citation": "Delta Dental PPO policy section D.4.3", "recommended_action": "Submit the pre-D and wait for written approval before scheduling."}, {"finding": "D2750 criteria score 1.000 â€” sufficient documentation", "evidence": ["NOTE-DL-C01-D03", "XRAY-DL-C01-D02"], "dimension": "clinical", "explanation": "Weighted clinical criteria for D2750 scored 1.000, which the payer reads as sufficient documentation.", "policy_citation": "ADA clinical criteria â€” crown restoration (PRD section 11)", "recommended_action": "None â€” documentation is sufficient."}]	2026-08-06T13:35:57.857617	t	f	\N	f
PRED-SIM-DA-C10	suwanee_smiles	t	1800.00	f	t	f	t	1.000	t	2	2	2	[]	t	f	0	[]	{"xray_present": true, "downgrade_noted": true, "deductible_known": true, "no_fraud_signals": true, "bundling_reviewed": true, "narrative_present": true, "provider_verified": false, "frequency_limit_ok": true, "waiting_period_met": true, "perio_chart_present": true, "eligibility_verified": true, "pre_d_required_noted": true, "annual_max_sufficient": true, "clinical_note_present": true}	\N	pended	\N	t	f	["COVERAGE_PRED_REQUIRED", "PROVIDER_OIG_EXCLUDED"]	[{"finding": "Coverage active (PPO), annual maximum remaining $1,800.00", "evidence": ["X12-DA-C10-271-D01"], "dimension": "eligibility", "explanation": "The patient's plan is active with $1,800.00 left against this year's maximum.", "policy_citation": "Delta Dental PPO plan certificate â€” eligibility provisions", "recommended_action": "None â€” eligibility confirmed."}, {"finding": "Missing tooth clause present on plan â€” payer confirmation: NOT confirmed", "evidence": ["X12-DA-C10-271-D01"], "dimension": "eligibility", "explanation": "The plan carries a missing tooth clause, but the payer has not confirmed it applies to this tooth, so it is not being enforced against these procedures.", "policy_citation": "Delta Dental PPO plan certificate â€” missing tooth provision", "recommended_action": "Confirm the extraction date and whether the clause applies with the payer before submitting."}, {"finding": "D2750 approved â€” pre-determination required", "evidence": ["PMS-DA-C10-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D2750 is covered at 50%, but the payer requires pre-determination before treatment.", "policy_citation": "Delta Dental PPO policy section D.4.3", "recommended_action": "Submit the pre-D and wait for written approval before scheduling."}, {"finding": "D2750 criteria score 1.000 â€” sufficient documentation", "evidence": ["NOTE-DA-C10-D03", "XRAY-DA-C10-D02"], "dimension": "clinical", "explanation": "Weighted clinical criteria for D2750 scored 1.000, which the payer reads as sufficient documentation.", "policy_citation": "ADA clinical criteria â€” crown restoration (PRD section 11)", "recommended_action": "None â€” documentation is sufficient."}]	2026-08-05T16:18:53.283320	f	t	\N	f
PRED-SIM-DA-D03	suwanee_smiles	t	1800.00	t	f	f	t	0.900	t	2	3	4	[]	f	f	0	[]	{"xray_present": true, "downgrade_noted": true, "deductible_known": true, "no_fraud_signals": true, "bundling_reviewed": true, "narrative_present": true, "provider_verified": true, "frequency_limit_ok": true, "waiting_period_met": false, "perio_chart_present": true, "eligibility_verified": true, "pre_d_required_noted": true, "annual_max_sufficient": true, "clinical_note_present": true}	\N	denied	\N	t	f	["ELIG_WAITING_PERIOD_NOT_MET"]	[{"finding": "Coverage active (PPO), annual maximum remaining $1,800.00", "evidence": ["X12-DA-D03-271-D01"], "dimension": "eligibility", "explanation": "The patient's plan is active with $1,800.00 left against this year's maximum.", "policy_citation": "Delta Dental PPO plan certificate â€” eligibility provisions", "recommended_action": "None â€” eligibility confirmed."}, {"finding": "Implant benefit present on this plan (applies to D6010, D6065)", "evidence": ["X12-DA-D03-271-D01"], "dimension": "eligibility", "explanation": "This plan pays implant services at 50%, so D6010, D6065 can be considered.", "policy_citation": "Delta Dental PPO plan certificate â€” implant benefit provisions", "recommended_action": "None â€” implant benefit confirmed."}, {"finding": "Missing tooth clause present on plan â€” payer confirmation: NOT confirmed", "evidence": ["X12-DA-D03-271-D01"], "dimension": "eligibility", "explanation": "The plan carries a missing tooth clause, but the payer has not confirmed it applies to this tooth, so it is not being enforced against these procedures.", "policy_citation": "Delta Dental PPO plan certificate â€” missing tooth provision", "recommended_action": "Confirm the extraction date and whether the clause applies with the payer before submitting."}, {"finding": "D6010 denied â€” pre-determination required", "evidence": ["PMS-DA-D03-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D6010 is covered at 50%, but the payer requires pre-determination before treatment.", "policy_citation": "Delta Dental PPO policy section D.7.1", "recommended_action": "Submit the pre-D and wait for written approval before scheduling."}, {"finding": "D6065 denied â€” pre-determination required", "evidence": ["PMS-DA-D03-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D6065 is covered at 50%, but the payer requires pre-determination before treatment.", "policy_citation": "Delta Dental PPO policy section D.7.2", "recommended_action": "Submit the pre-D and wait for written approval before scheduling."}, {"finding": "Radiographic bone loss 4.2mm (35.0% of root support)", "evidence": ["XRAY-DA-D03-D02"], "dimension": "clinical", "explanation": "The X-ray documents 4.2mm of bone loss, meeting the 3mm the payer requires to establish graft and implant necessity.", "policy_citation": "ADA clinical criteria â€” radiographic evidence (PRD section 11)", "recommended_action": "None â€” radiographic threshold met."}, {"finding": "D6010 criteria score 0.900 â€” sufficient documentation", "evidence": ["NOTE-DA-D03-D03", "XRAY-DA-D03-D02"], "dimension": "clinical", "explanation": "Weighted clinical criteria for D6010 scored 0.900, which the payer reads as sufficient documentation.", "policy_citation": "ADA clinical criteria â€” implant placement (PRD section 11)", "recommended_action": "None â€” documentation is sufficient."}]	2026-08-05T16:18:27.510658	t	f	\N	f
PRED-SIM-DA-D01	suwanee_smiles	t	1800.00	t	t	f	t	0.900	t	3	9	11	[]	t	t	1	[]	{"xray_present": true, "downgrade_noted": true, "deductible_known": true, "no_fraud_signals": true, "bundling_reviewed": false, "narrative_present": true, "provider_verified": true, "frequency_limit_ok": true, "waiting_period_met": true, "perio_chart_present": true, "eligibility_verified": true, "pre_d_required_noted": true, "annual_max_sufficient": true, "clinical_note_present": true}	\N	pended	\N	t	f	["COVERAGE_PRED_REQUIRED", "PROVIDER_OUT_OF_NETWORK", "COVERAGE_BUNDLING_CONFLICT", "CLINICAL_XRAY_REQUIRED", "CLINICAL_NARRATIVE_REQUIRED"]	[{"finding": "Coverage active (PPO), annual maximum remaining $1,800.00", "evidence": ["X12-DA-D01-271-D01"], "dimension": "eligibility", "explanation": "The patient's plan is active with $1,800.00 left against this year's maximum.", "policy_citation": "Delta Dental PPO plan certificate â€” eligibility provisions", "recommended_action": "None â€” eligibility confirmed."}, {"finding": "Implant benefit present on this plan (applies to D6010, D7953)", "evidence": ["X12-DA-D01-271-D01"], "dimension": "eligibility", "explanation": "This plan pays implant services at 50%, so D6010, D7953 can be considered.", "policy_citation": "Delta Dental PPO plan certificate â€” implant benefit provisions", "recommended_action": "None â€” implant benefit confirmed."}, {"finding": "Missing tooth clause present on plan â€” payer confirmation: NOT confirmed", "evidence": ["X12-DA-D01-271-D01"], "dimension": "eligibility", "explanation": "The plan carries a missing tooth clause, but the payer has not confirmed it applies to this tooth, so it is not being enforced against these procedures.", "policy_citation": "Delta Dental PPO plan certificate â€” missing tooth provision", "recommended_action": "Confirm the extraction date and whether the clause applies with the payer before submitting."}, {"finding": "D4260 pended â€” pre-determination required", "evidence": ["PMS-DA-D01-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D4260 is covered at 50%, but the payer requires pre-determination before treatment.", "policy_citation": "Delta Dental PPO policy section D.6.3", "recommended_action": "Submit the pre-D and wait for written approval before scheduling."}, {"finding": "D6010 pended â€” pre-determination required", "evidence": ["PMS-DA-D01-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D6010 is covered at 50%, but the payer requires pre-determination before treatment.", "policy_citation": "Delta Dental PPO policy section D.7.1", "recommended_action": "Submit the pre-D and wait for written approval before scheduling."}, {"finding": "D7953 pended â€” bundled with D6010; pre-determination required", "evidence": ["PMS-DA-D01-SUPERBILL-D00", "NOTE-DA-D01-D04", "XRAY-DA-D01-D03", "PERIO-DA-D01-D02"], "dimension": "coverage", "explanation": "The payer treats D7953 as part of D6010 unless it is documented as separately necessary.", "policy_citation": "Delta Dental PPO policy section D.7.4", "recommended_action": "Attach a narrative establishing necessity independent of the bundled procedure, plus the supporting X-ray; documented appeals overturn about 65% of the time."}, {"finding": "Radiographic bone loss 4.2mm (35.0% of root support)", "evidence": ["XRAY-DA-D01-D03"], "dimension": "clinical", "explanation": "The X-ray documents 4.2mm of bone loss, meeting the 3mm the payer requires to establish graft and implant necessity.", "policy_citation": "ADA clinical criteria â€” radiographic evidence (PRD section 11)", "recommended_action": "None â€” radiographic threshold met."}, {"finding": "D4260 criteria score 1.000 â€” sufficient documentation", "evidence": ["NOTE-DA-D01-D04", "XRAY-DA-D01-D03", "PERIO-DA-D01-D02"], "dimension": "clinical", "explanation": "Weighted clinical criteria for D4260 scored 1.000, which the payer reads as sufficient documentation.", "policy_citation": "ADA clinical criteria â€” osseous surgery (PRD section 11)", "recommended_action": "None â€” documentation is sufficient."}, {"finding": "D6010 criteria score 0.900 â€” sufficient documentation", "evidence": ["NOTE-DA-D01-D04", "XRAY-DA-D01-D03", "PERIO-DA-D01-D02"], "dimension": "clinical", "explanation": "Weighted clinical criteria for D6010 scored 0.900, which the payer reads as sufficient documentation.", "policy_citation": "ADA clinical criteria â€” implant placement (PRD section 11)", "recommended_action": "None â€” documentation is sufficient."}, {"finding": "D7953 criteria score 0.800 â€” pend â€” needs additional documentation", "evidence": ["NOTE-DA-D01-D04", "XRAY-DA-D01-D03", "PERIO-DA-D01-D02"], "dimension": "clinical", "explanation": "Weighted clinical criteria for D7953 scored 0.800, which the payer reads as pend â€” needs additional documentation.", "policy_citation": "ADA clinical criteria â€” bone graft / ridge preservation (PRD section 11)", "recommended_action": "All required criteria for D7953 are met; add the optional supporting evidence (e.g. CBCT) to raise the score above the 0.85 auto-approve threshold."}]	2026-08-05T16:18:23.561667	t	f	\N	f
PRED-SIM-DA-D02	suwanee_smiles	t	1800.00	t	t	f	t	1.000	t	3	28	28	[]	t	t	4	[]	{"xray_present": false, "downgrade_noted": true, "deductible_known": true, "no_fraud_signals": true, "bundling_reviewed": false, "narrative_present": true, "provider_verified": true, "frequency_limit_ok": true, "waiting_period_met": true, "perio_chart_present": true, "eligibility_verified": true, "pre_d_required_noted": true, "annual_max_sufficient": true, "clinical_note_present": true}	\N	pended	\N	t	f	["COVERAGE_PRED_REQUIRED", "COVERAGE_BUNDLING_CONFLICT", "CLINICAL_XRAY_REQUIRED", "CLINICAL_NARRATIVE_REQUIRED", "COVERAGE_DOWNGRADE_APPLIED", "CLINICAL_CRITERIA_NOT_MET"]	[{"finding": "Coverage active (PPO), annual maximum remaining $1,800.00", "evidence": ["X12-DA-D02-271-D01"], "dimension": "eligibility", "explanation": "The patient's plan is active with $1,800.00 left against this year's maximum.", "policy_citation": "Delta Dental PPO plan certificate â€” eligibility provisions", "recommended_action": "None â€” eligibility confirmed."}, {"finding": "Implant benefit present on this plan (applies to D6010, D6010, D6010, D6010, D7953, D7953, D7953, D7953, D6065, D6065, D6065, D6065)", "evidence": ["X12-DA-D02-271-D01"], "dimension": "eligibility", "explanation": "This plan pays implant services at 50%, so D6010, D6010, D6010, D6010, D7953, D7953, D7953, D7953, D6065, D6065, D6065, D6065 can be considered.", "policy_citation": "Delta Dental PPO plan certificate â€” implant benefit provisions", "recommended_action": "None â€” implant benefit confirmed."}, {"finding": "Missing tooth clause present on plan â€” payer confirmation: NOT confirmed", "evidence": ["X12-DA-D02-271-D01"], "dimension": "eligibility", "explanation": "The plan carries a missing tooth clause, but the payer has not confirmed it applies to this tooth, so it is not being enforced against these procedures.", "policy_citation": "Delta Dental PPO plan certificate â€” missing tooth provision", "recommended_action": "Confirm the extraction date and whether the clause applies with the payer before submitting."}, {"finding": "D6010 approved â€” pre-determination required", "evidence": ["PMS-DA-D02-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D6010 is covered at 50%, but the payer requires pre-determination before treatment.", "policy_citation": "Delta Dental PPO policy section D.7.1", "recommended_action": "Submit the pre-D and wait for written approval before scheduling."}, {"finding": "D6010 approved â€” pre-determination required", "evidence": ["PMS-DA-D02-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D6010 is covered at 50%, but the payer requires pre-determination before treatment.", "policy_citation": "Delta Dental PPO policy section D.7.1", "recommended_action": "Submit the pre-D and wait for written approval before scheduling."}, {"finding": "D6010 approved â€” pre-determination required", "evidence": ["PMS-DA-D02-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D6010 is covered at 50%, but the payer requires pre-determination before treatment.", "policy_citation": "Delta Dental PPO policy section D.7.1", "recommended_action": "Submit the pre-D and wait for written approval before scheduling."}, {"finding": "D6010 approved â€” pre-determination required", "evidence": ["PMS-DA-D02-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D6010 is covered at 50%, but the payer requires pre-determination before treatment.", "policy_citation": "Delta Dental PPO policy section D.7.1", "recommended_action": "Submit the pre-D and wait for written approval before scheduling."}, {"finding": "D7953 pended â€” bundled with D6010; pre-determination required", "evidence": ["PMS-DA-D02-SUPERBILL-D00", "CBCT-DA-D02-D02", "NOTE-DA-D02-D04", "PAN-DA-D02-D03"], "dimension": "coverage", "explanation": "The payer treats D7953 as part of D6010 unless it is documented as separately necessary.", "policy_citation": "Delta Dental PPO policy section D.7.4", "recommended_action": "Attach a narrative establishing necessity independent of the bundled procedure, plus the supporting X-ray; documented appeals overturn about 65% of the time."}, {"finding": "D7953 pended â€” bundled with D6010; pre-determination required", "evidence": ["PMS-DA-D02-SUPERBILL-D00", "CBCT-DA-D02-D02", "NOTE-DA-D02-D04", "PAN-DA-D02-D03"], "dimension": "coverage", "explanation": "The payer treats D7953 as part of D6010 unless it is documented as separately necessary.", "policy_citation": "Delta Dental PPO policy section D.7.4", "recommended_action": "Attach a narrative establishing necessity independent of the bundled procedure, plus the supporting X-ray; documented appeals overturn about 65% of the time."}, {"finding": "D7953 pended â€” bundled with D6010; pre-determination required", "evidence": ["PMS-DA-D02-SUPERBILL-D00", "CBCT-DA-D02-D02", "NOTE-DA-D02-D04", "PAN-DA-D02-D03"], "dimension": "coverage", "explanation": "The payer treats D7953 as part of D6010 unless it is documented as separately necessary.", "policy_citation": "Delta Dental PPO policy section D.7.4", "recommended_action": "Attach a narrative establishing necessity independent of the bundled procedure, plus the supporting X-ray; documented appeals overturn about 65% of the time."}, {"finding": "D7953 pended â€” bundled with D6010; pre-determination required", "evidence": ["PMS-DA-D02-SUPERBILL-D00", "CBCT-DA-D02-D02", "NOTE-DA-D02-D04", "PAN-DA-D02-D03"], "dimension": "coverage", "explanation": "The payer treats D7953 as part of D6010 unless it is documented as separately necessary.", "policy_citation": "Delta Dental PPO policy section D.7.4", "recommended_action": "Attach a narrative establishing necessity independent of the bundled procedure, plus the supporting X-ray; documented appeals overturn about 65% of the time."}, {"finding": "D6065 pended â€” downgraded to D2750; pre-determination required", "evidence": ["PMS-DA-D02-SUPERBILL-D00"], "dimension": "coverage", "explanation": "The plan reimburses D6065 at the D2750 fee schedule, so the patient owes the difference.", "policy_citation": "Delta Dental PPO policy section D.7.2", "recommended_action": "Give the patient a written estimate of the D6065-to-D2750 difference before treatment."}, {"finding": "D6065 pended â€” downgraded to D2750; pre-determination required", "evidence": ["PMS-DA-D02-SUPERBILL-D00"], "dimension": "coverage", "explanation": "The plan reimburses D6065 at the D2750 fee schedule, so the patient owes the difference.", "policy_citation": "Delta Dental PPO policy section D.7.2", "recommended_action": "Give the patient a written estimate of the D6065-to-D2750 difference before treatment."}, {"finding": "D6065 pended â€” downgraded to D2750; pre-determination required", "evidence": ["PMS-DA-D02-SUPERBILL-D00"], "dimension": "coverage", "explanation": "The plan reimburses D6065 at the D2750 fee schedule, so the patient owes the difference.", "policy_citation": "Delta Dental PPO policy section D.7.2", "recommended_action": "Give the patient a written estimate of the D6065-to-D2750 difference before treatment."}, {"finding": "D6065 pended â€” downgraded to D2750; pre-determination required", "evidence": ["PMS-DA-D02-SUPERBILL-D00"], "dimension": "coverage", "explanation": "The plan reimburses D6065 at the D2750 fee schedule, so the patient owes the difference.", "policy_citation": "Delta Dental PPO policy section D.7.2", "recommended_action": "Give the patient a written estimate of the D6065-to-D2750 difference before treatment."}, {"finding": "Radiographic bone loss 5.1mm (40.0% of root support)", "evidence": ["PAN-DA-D02-D03"], "dimension": "clinical", "explanation": "The X-ray documents 5.1mm of bone loss, meeting the 3mm the payer requires to establish graft and implant necessity.", "policy_citation": "ADA clinical criteria â€” radiographic evidence (PRD section 11)", "recommended_action": "None â€” radiographic threshold met."}, {"finding": "D6010 criteria score 1.000 â€” sufficient documentation", "evidence": ["CBCT-DA-D02-D02", "NOTE-DA-D02-D04", "PAN-DA-D02-D03"], "dimension": "clinical", "explanation": "Weighted clinical criteria for D6010 scored 1.000, which the payer reads as sufficient documentation.", "policy_citation": "ADA clinical criteria â€” implant placement (PRD section 11)", "recommended_action": "None â€” documentation is sufficient."}, {"finding": "D7953 criteria score 1.000 â€” sufficient documentation", "evidence": ["CBCT-DA-D02-D02", "NOTE-DA-D02-D04", "PAN-DA-D02-D03"], "dimension": "clinical", "explanation": "Weighted clinical criteria for D7953 scored 1.000, which the payer reads as sufficient documentation.", "policy_citation": "ADA clinical criteria â€” bone graft / ridge preservation (PRD section 11)", "recommended_action": "None â€” documentation is sufficient."}]	2026-08-05T16:18:25.767466	t	f	\N	f
PRED-SIM-DA-D04	suwanee_smiles	t	1800.00	f	t	f	t	1.000	t	2	0	0	[]	t	f	0	[]	{"xray_present": true, "downgrade_noted": true, "deductible_known": true, "no_fraud_signals": true, "bundling_reviewed": true, "narrative_present": true, "provider_verified": true, "frequency_limit_ok": true, "waiting_period_met": true, "perio_chart_present": true, "eligibility_verified": true, "pre_d_required_noted": true, "annual_max_sufficient": true, "clinical_note_present": true}	\N	approved	\N	t	f	["COVERAGE_DOWNGRADE_APPLIED", "COVERAGE_PRED_REQUIRED"]	[{"finding": "Coverage active (PPO), annual maximum remaining $1,800.00", "evidence": ["X12-DA-D04-271-D01"], "dimension": "eligibility", "explanation": "The patient's plan is active with $1,800.00 left against this year's maximum.", "policy_citation": "Delta Dental PPO plan certificate â€” eligibility provisions", "recommended_action": "None â€” eligibility confirmed."}, {"finding": "Missing tooth clause present on plan â€” payer confirmation: NOT confirmed", "evidence": ["X12-DA-D04-271-D01"], "dimension": "eligibility", "explanation": "The plan carries a missing tooth clause, but the payer has not confirmed it applies to this tooth, so it is not being enforced against these procedures.", "policy_citation": "Delta Dental PPO plan certificate â€” missing tooth provision", "recommended_action": "Confirm the extraction date and whether the clause applies with the payer before submitting."}, {"finding": "D2740 approved â€” downgraded to D2750; pre-determination required", "evidence": ["PMS-DA-D04-SUPERBILL-D00"], "dimension": "coverage", "explanation": "The plan reimburses D2740 at the D2750 fee schedule, so the patient owes the difference.", "policy_citation": "Delta Dental PPO policy section D.4.2", "recommended_action": "Give the patient a written estimate of the D2740-to-D2750 difference before treatment."}]	2026-08-05T16:18:28.976508	t	f	\N	t
PRED-SIM-DL-B01	dallas_dental	t	1800.00	t	t	f	t	0.300	f	2	1	4	["Pocket depth >=5mm in 6+ sites", "Bone loss >=25%"]	f	f	0	[]	{"xray_present": true, "downgrade_noted": true, "deductible_known": true, "no_fraud_signals": true, "bundling_reviewed": true, "narrative_present": true, "provider_verified": true, "frequency_limit_ok": true, "waiting_period_met": true, "perio_chart_present": true, "eligibility_verified": true, "pre_d_required_noted": true, "annual_max_sufficient": true, "clinical_note_present": true}	\N	denied	\N	t	f	["COVERAGE_PRED_REQUIRED", "CLINICAL_CRITERIA_NOT_MET", "CLINICAL_POCKET_DEPTH", "CLINICAL_BONE_LOSS_THRESHOLD", "CLINICAL_XRAY_REQUIRED"]	[{"finding": "Coverage active (DPPO), annual maximum remaining $1,800.00", "evidence": ["INS-DL-B01-CARD-D04", "X12-DL-B01-271-D01"], "dimension": "eligibility", "explanation": "The patient's plan is active with $1,800.00 left against this year's maximum.", "policy_citation": "Delta Dental PPO plan certificate â€” eligibility provisions", "recommended_action": "None â€” eligibility confirmed."}, {"finding": "Missing tooth clause present on plan â€” payer confirmation: NOT confirmed", "evidence": ["INS-DL-B01-CARD-D04", "X12-DL-B01-271-D01"], "dimension": "eligibility", "explanation": "The plan carries a missing tooth clause, but the payer has not confirmed it applies to this tooth, so it is not being enforced against these procedures.", "policy_citation": "Delta Dental PPO plan certificate â€” missing tooth provision", "recommended_action": "Confirm the extraction date and whether the clause applies with the payer before submitting."}, {"finding": "D4260 denied â€” pre-determination required", "evidence": ["PMS-DL-B01-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D4260 is covered at 50%, but the payer requires pre-determination before treatment.", "policy_citation": "Delta Dental PPO policy section D.6.3", "recommended_action": "Submit the pre-D and wait for written approval before scheduling."}, {"finding": "D4260 criteria score 0.300 â€” review required â€” significant gaps", "evidence": ["NOTE-DL-B01-D03", "PERIO-DL-B01-D02"], "dimension": "clinical", "explanation": "Weighted clinical criteria for D4260 scored 0.300, which the payer reads as review required â€” significant gaps.", "policy_citation": "ADA clinical criteria â€” osseous surgery (PRD section 11)", "recommended_action": "Attach the missing required evidence for D4260: Pocket depth >=5mm in 6+ sites; Bone loss >=25%."}, {"finding": "Missing required evidence: Pocket depth >=5mm in 6+ sites; Bone loss >=25%", "evidence": ["NOTE-DL-B01-D03", "PERIO-DL-B01-D02"], "dimension": "clinical", "explanation": "One or more required clinical criteria have no supporting document on file.", "policy_citation": "ADA clinical criteria â€” required documentation (PRD section 11)", "recommended_action": "Attach: Pocket depth >=5mm in 6+ sites; Bone loss >=25%."}]	2026-08-06T13:35:56.221035	t	f	\N	t
PRED-SIM-DA-A03	suwanee_smiles	t	1800.00	f	t	f	t	1.000	t	2	4	4	[]	t	f	0	[]	{"xray_present": true, "downgrade_noted": true, "deductible_known": true, "no_fraud_signals": true, "bundling_reviewed": true, "narrative_present": true, "provider_verified": true, "frequency_limit_ok": true, "waiting_period_met": true, "perio_chart_present": true, "eligibility_verified": true, "pre_d_required_noted": true, "annual_max_sufficient": true, "clinical_note_present": true}	\N	approved	\N	t	f	["COVERAGE_PRED_REQUIRED"]	[{"finding": "Coverage active (PPO), annual maximum remaining $1,800.00", "evidence": ["X12-DA-A03-271-D01"], "dimension": "eligibility", "explanation": "The patient's plan is active with $1,800.00 left against this year's maximum.", "policy_citation": "Delta Dental PPO plan certificate â€” eligibility provisions", "recommended_action": "None â€” eligibility confirmed."}, {"finding": "Missing tooth clause present on plan â€” payer confirmation: NOT confirmed", "evidence": ["X12-DA-A03-271-D01"], "dimension": "eligibility", "explanation": "The plan carries a missing tooth clause, but the payer has not confirmed it applies to this tooth, so it is not being enforced against these procedures.", "policy_citation": "Delta Dental PPO plan certificate â€” missing tooth provision", "recommended_action": "Confirm the extraction date and whether the clause applies with the payer before submitting."}, {"finding": "D3330 approved", "evidence": ["PMS-DA-A03-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D3330 is covered at 80% with no conflicts detected.", "policy_citation": "Delta Dental PPO policy section D.5.3", "recommended_action": "None â€” ready to submit."}, {"finding": "D2750 approved â€” pre-determination required", "evidence": ["PMS-DA-A03-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D2750 is covered at 50%, but the payer requires pre-determination before treatment.", "policy_citation": "Delta Dental PPO policy section D.4.3", "recommended_action": "Submit the pre-D and wait for written approval before scheduling."}, {"finding": "D3330 criteria score 1.000 â€” sufficient documentation", "evidence": ["NOTE-DA-A03-D03", "XRAY-DA-A03-D02"], "dimension": "clinical", "explanation": "Weighted clinical criteria for D3330 scored 1.000, which the payer reads as sufficient documentation.", "policy_citation": "ADA clinical criteria â€” endodontic therapy, molar (PRD section 11)", "recommended_action": "None â€” documentation is sufficient."}, {"finding": "D2750 criteria score 1.000 â€” sufficient documentation", "evidence": ["NOTE-DA-A03-D03", "XRAY-DA-A03-D02"], "dimension": "clinical", "explanation": "Weighted clinical criteria for D2750 scored 1.000, which the payer reads as sufficient documentation.", "policy_citation": "ADA clinical criteria â€” crown restoration (PRD section 11)", "recommended_action": "None â€” documentation is sufficient."}]	2026-08-05T16:18:04.141630	t	f	\N	t
PRED-SIM-TB-A01	tampa_smiles	t	1500.00	t	t	f	t	1.000	t	2	2	2	[]	t	f	0	[]	{"xray_present": true, "downgrade_noted": true, "deductible_known": true, "no_fraud_signals": true, "bundling_reviewed": true, "narrative_present": true, "provider_verified": true, "frequency_limit_ok": true, "waiting_period_met": true, "perio_chart_present": true, "eligibility_verified": true, "pre_d_required_noted": true, "annual_max_sufficient": true, "clinical_note_present": true}	\N	approved	\N	t	f	["COVERAGE_PRED_REQUIRED"]	[{"finding": "Coverage active (DPPO), annual maximum remaining $1,500.00", "evidence": ["INS-TB-A01-CARD-D04", "X12-TB-A01-271-D01"], "dimension": "eligibility", "explanation": "The patient's plan is active with $1,500.00 left against this year's maximum.", "policy_citation": "Delta Dental PPO plan certificate â€” eligibility provisions", "recommended_action": "None â€” eligibility confirmed."}, {"finding": "D2750 approved â€” pre-determination required", "evidence": ["PMS-TB-A01-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D2750 is covered at 50%, but the payer requires pre-determination before treatment.", "policy_citation": "Delta Dental PPO policy section D.4.3", "recommended_action": "Submit the pre-D and wait for written approval before scheduling."}, {"finding": "D2750 criteria score 1.000 â€” sufficient documentation", "evidence": ["NOTE-TB-A01-D03", "XRAY-TB-A01-D02"], "dimension": "clinical", "explanation": "Weighted clinical criteria for D2750 scored 1.000, which the payer reads as sufficient documentation.", "policy_citation": "ADA clinical criteria â€” crown restoration (PRD section 11)", "recommended_action": "None â€” documentation is sufficient."}]	2026-08-06T13:35:17.904903	t	f	\N	t
PRED-SIM-TB-B01	tampa_smiles	t	1500.00	f	t	f	t	0.900	t	2	3	4	[]	f	f	0	[]	{"xray_present": true, "downgrade_noted": true, "deductible_known": true, "no_fraud_signals": true, "bundling_reviewed": true, "narrative_present": true, "provider_verified": true, "frequency_limit_ok": true, "waiting_period_met": true, "perio_chart_present": true, "eligibility_verified": true, "pre_d_required_noted": true, "annual_max_sufficient": true, "clinical_note_present": true}	\N	denied	\N	t	f	["ELIG_IMPLANT_NOT_COVERED"]	[{"finding": "Coverage active (DMO), annual maximum remaining $1,500.00", "evidence": ["INS-TB-B01-CARD-D04", "X12-TB-B01-271-D01"], "dimension": "eligibility", "explanation": "The patient's plan is active with $1,500.00 left against this year's maximum.", "policy_citation": "Delta Dental PPO plan certificate â€” eligibility provisions", "recommended_action": "None â€” eligibility confirmed."}, {"finding": "Implant benefit excluded on this plan (applies to D6010)", "evidence": ["INS-TB-B01-CARD-D04", "X12-TB-B01-271-D01"], "dimension": "eligibility", "explanation": "This plan excludes implant services, so D6010 will be denied outright.", "policy_citation": "Delta Dental PPO plan certificate â€” implant benefit provisions", "recommended_action": "Present the patient with self-pay options; an appeal will not overcome a plan exclusion."}, {"finding": "Missing tooth clause present on plan â€” payer confirmation: NOT confirmed", "evidence": ["INS-TB-B01-CARD-D04", "X12-TB-B01-271-D01"], "dimension": "eligibility", "explanation": "The plan carries a missing tooth clause, but the payer has not confirmed it applies to this tooth, so it is not being enforced against these procedures.", "policy_citation": "Delta Dental PPO plan certificate â€” missing tooth provision", "recommended_action": "Confirm the extraction date and whether the clause applies with the payer before submitting."}, {"finding": "D6010 denied â€” pre-determination required", "evidence": ["PMS-TB-B01-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D6010 is not a covered benefit under this plan.", "policy_citation": "Delta Dental PPO policy section D.7.1", "recommended_action": "Discuss self-pay with the patient, or add a tenant overlay rule if the practice has negotiated different terms."}, {"finding": "Radiographic bone loss 4.2mm (35.0% of root support)", "evidence": ["XRAY-TB-B01-D02"], "dimension": "clinical", "explanation": "The X-ray documents 4.2mm of bone loss, meeting the 3mm the payer requires to establish graft and implant necessity.", "policy_citation": "ADA clinical criteria â€” radiographic evidence (PRD section 11)", "recommended_action": "None â€” radiographic threshold met."}, {"finding": "D6010 criteria score 0.900 â€” sufficient documentation", "evidence": ["NOTE-TB-B01-D03", "XRAY-TB-B01-D02"], "dimension": "clinical", "explanation": "Weighted clinical criteria for D6010 scored 0.900, which the payer reads as sufficient documentation.", "policy_citation": "ADA clinical criteria â€” implant placement (PRD section 11)", "recommended_action": "None â€” documentation is sufficient."}]	2026-08-06T13:35:19.619727	t	f	\N	t
PRED-SIM-TB-C01	tampa_smiles	t	1800.00	t	t	f	f	0.000	f	1	0	4	["Pocket depth >=4mm", "Periodontal chart"]	t	f	0	[]	{"xray_present": true, "downgrade_noted": true, "deductible_known": true, "no_fraud_signals": true, "bundling_reviewed": true, "narrative_present": true, "provider_verified": true, "frequency_limit_ok": true, "waiting_period_met": true, "perio_chart_present": false, "eligibility_verified": true, "pre_d_required_noted": true, "annual_max_sufficient": true, "clinical_note_present": true}	\N	pended	\N	t	f	["CLINICAL_CRITERIA_NOT_MET", "CLINICAL_POCKET_DEPTH", "CLINICAL_PERIO_CHART_REQUIRED"]	[{"finding": "Coverage active (DPPO), annual maximum remaining $1,800.00", "evidence": ["INS-TB-C01-CARD-D03", "X12-TB-C01-271-D01"], "dimension": "eligibility", "explanation": "The patient's plan is active with $1,800.00 left against this year's maximum.", "policy_citation": "Delta Dental PPO plan certificate â€” eligibility provisions", "recommended_action": "None â€” eligibility confirmed."}, {"finding": "Missing tooth clause present on plan â€” payer confirmation: NOT confirmed", "evidence": ["INS-TB-C01-CARD-D03", "X12-TB-C01-271-D01"], "dimension": "eligibility", "explanation": "The plan carries a missing tooth clause, but the payer has not confirmed it applies to this tooth, so it is not being enforced against these procedures.", "policy_citation": "Delta Dental PPO plan certificate â€” missing tooth provision", "recommended_action": "Confirm the extraction date and whether the clause applies with the payer before submitting."}, {"finding": "D4341 pended", "evidence": ["PMS-TB-C01-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D4341 is covered at 80% with no conflicts detected.", "policy_citation": "Delta Dental PPO policy section D.6.1", "recommended_action": "None â€” ready to submit."}, {"finding": "D4341 pended", "evidence": ["PMS-TB-C01-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D4341 is covered at 80% with no conflicts detected.", "policy_citation": "Delta Dental PPO policy section D.6.1", "recommended_action": "None â€” ready to submit."}, {"finding": "D4341 criteria score 0.000 â€” insufficient documentation", "evidence": ["NOTE-TB-C01-D02"], "dimension": "clinical", "explanation": "Weighted clinical criteria for D4341 scored 0.000, which the payer reads as insufficient documentation.", "policy_citation": "ADA clinical criteria â€” scaling and root planing (PRD section 11)", "recommended_action": "Attach the missing required evidence for D4341: Pocket depth >=4mm; Periodontal chart."}, {"finding": "Missing required evidence: Pocket depth >=4mm; Periodontal chart", "evidence": ["NOTE-TB-C01-D02"], "dimension": "clinical", "explanation": "One or more required clinical criteria have no supporting document on file.", "policy_citation": "ADA clinical criteria â€” required documentation (PRD section 11)", "recommended_action": "Attach: Pocket depth >=4mm; Periodontal chart."}]	2026-08-06T13:35:21.203146	t	f	\N	f
PRED-SIM-TB-D01	tampa_smiles	t	1500.00	f	t	f	t	1.000	t	2	0	0	[]	t	f	0	[]	{"xray_present": true, "downgrade_noted": true, "deductible_known": true, "no_fraud_signals": true, "bundling_reviewed": true, "narrative_present": true, "provider_verified": true, "frequency_limit_ok": true, "waiting_period_met": true, "perio_chart_present": true, "eligibility_verified": true, "pre_d_required_noted": true, "annual_max_sufficient": true, "clinical_note_present": true}	\N	approved	\N	t	f	["COVERAGE_DOWNGRADE_APPLIED", "COVERAGE_PRED_REQUIRED"]	[{"finding": "Coverage active (DMO), annual maximum remaining $1,500.00", "evidence": ["INS-TB-D01-CARD-D04", "X12-TB-D01-271-D01"], "dimension": "eligibility", "explanation": "The patient's plan is active with $1,500.00 left against this year's maximum.", "policy_citation": "Delta Dental PPO plan certificate â€” eligibility provisions", "recommended_action": "None â€” eligibility confirmed."}, {"finding": "Missing tooth clause present on plan â€” payer confirmation: NOT confirmed", "evidence": ["INS-TB-D01-CARD-D04", "X12-TB-D01-271-D01"], "dimension": "eligibility", "explanation": "The plan carries a missing tooth clause, but the payer has not confirmed it applies to this tooth, so it is not being enforced against these procedures.", "policy_citation": "Delta Dental PPO plan certificate â€” missing tooth provision", "recommended_action": "Confirm the extraction date and whether the clause applies with the payer before submitting."}, {"finding": "D2740 approved â€” downgraded to D2750; pre-determination required", "evidence": ["PMS-TB-D01-SUPERBILL-D00"], "dimension": "coverage", "explanation": "The plan reimburses D2740 at the D2750 fee schedule, so the patient owes the difference.", "policy_citation": "Delta Dental PPO policy section D.4.2", "recommended_action": "Give the patient a written estimate of the D2740-to-D2750 difference before treatment."}]	2026-08-06T13:35:22.617606	t	f	\N	t
PRED-SIM-DL-D01	dallas_dental	t	1500.00	t	t	f	f	1.000	t	2	0	0	[]	f	f	0	[]	{"xray_present": true, "downgrade_noted": true, "deductible_known": true, "no_fraud_signals": true, "bundling_reviewed": true, "narrative_present": true, "provider_verified": true, "frequency_limit_ok": true, "waiting_period_met": true, "perio_chart_present": true, "eligibility_verified": true, "pre_d_required_noted": true, "annual_max_sufficient": true, "clinical_note_present": true}	\N	denied	\N	t	f	["COVERAGE_NOT_MEDICALLY_NECESSARY"]	[{"finding": "Coverage active (DPPO), annual maximum remaining $1,500.00", "evidence": ["INS-DL-D01-CARD-D04", "X12-DL-D01-271-D01"], "dimension": "eligibility", "explanation": "The patient's plan is active with $1,500.00 left against this year's maximum.", "policy_citation": "Delta Dental PPO plan certificate â€” eligibility provisions", "recommended_action": "None â€” eligibility confirmed."}, {"finding": "D8090 denied", "evidence": ["PMS-DL-D01-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D8090 is not a covered benefit under this plan.", "policy_citation": "Delta Dental PPO policy â€” no section on file", "recommended_action": "Discuss self-pay with the patient, or add a tenant overlay rule if the practice has negotiated different terms."}]	2026-08-06T13:35:59.756702	t	f	\N	t
PRED-SIM-DL-U01	dallas_dental	t	1800.00	t	t	f	f	1.000	t	1	0	0	[]	t	f	0	[]	{"xray_present": true, "downgrade_noted": true, "deductible_known": true, "no_fraud_signals": true, "bundling_reviewed": true, "narrative_present": true, "provider_verified": true, "frequency_limit_ok": true, "waiting_period_met": true, "perio_chart_present": true, "eligibility_verified": true, "pre_d_required_noted": true, "annual_max_sufficient": true, "clinical_note_present": true}	\N	approved	\N	f	t	[]	[{"finding": "Coverage active (DPPO), annual maximum remaining $1,800.00", "evidence": ["INS-DL-U01-CARD-D03", "X12-DL-U01-271-D01"], "dimension": "eligibility", "explanation": "The patient's plan is active with $1,800.00 left against this year's maximum.", "policy_citation": "Delta Dental PPO plan certificate â€” eligibility provisions", "recommended_action": "None â€” eligibility confirmed."}, {"finding": "Missing tooth clause present on plan â€” payer confirmation: NOT confirmed", "evidence": ["INS-DL-U01-CARD-D03", "X12-DL-U01-271-D01"], "dimension": "eligibility", "explanation": "The plan carries a missing tooth clause, but the payer has not confirmed it applies to this tooth, so it is not being enforced against these procedures.", "policy_citation": "Delta Dental PPO plan certificate â€” missing tooth provision", "recommended_action": "Confirm the extraction date and whether the clause applies with the payer before submitting."}, {"finding": "D0330 approved", "evidence": ["PMS-DL-U01-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D0330 is covered at 100% with no conflicts detected.", "policy_citation": "Delta Dental PPO policy section D.1.4", "recommended_action": "None â€” ready to submit."}]	2026-08-06T13:36:01.443885	t	f	\N	t
PRED-SIM-DA-D05	suwanee_smiles	t	1800.00	t	t	f	t	1.000	t	3	7	7	[]	t	f	0	[]	{"xray_present": true, "downgrade_noted": true, "deductible_known": true, "no_fraud_signals": true, "bundling_reviewed": true, "narrative_present": true, "provider_verified": true, "frequency_limit_ok": true, "waiting_period_met": true, "perio_chart_present": true, "eligibility_verified": true, "pre_d_required_noted": true, "annual_max_sufficient": true, "clinical_note_present": true}	\N	approved	\N	t	f	["COVERAGE_PRED_REQUIRED"]	[{"finding": "Coverage active (PPO), annual maximum remaining $1,800.00", "evidence": ["X12-DA-D05-271-D01"], "dimension": "eligibility", "explanation": "The patient's plan is active with $1,800.00 left against this year's maximum.", "policy_citation": "Delta Dental PPO plan certificate â€” eligibility provisions", "recommended_action": "None â€” eligibility confirmed."}, {"finding": "Implant benefit present on this plan (applies to D6010, D7953)", "evidence": ["X12-DA-D05-271-D01"], "dimension": "eligibility", "explanation": "This plan pays implant services at 50%, so D6010, D7953 can be considered.", "policy_citation": "Delta Dental PPO plan certificate â€” implant benefit provisions", "recommended_action": "None â€” implant benefit confirmed."}, {"finding": "Missing tooth clause present on plan â€” payer confirmation: NOT confirmed", "evidence": ["X12-DA-D05-271-D01"], "dimension": "eligibility", "explanation": "The plan carries a missing tooth clause, but the payer has not confirmed it applies to this tooth, so it is not being enforced against these procedures.", "policy_citation": "Delta Dental PPO plan certificate â€” missing tooth provision", "recommended_action": "Confirm the extraction date and whether the clause applies with the payer before submitting."}, {"finding": "D6010 approved â€” pre-determination required", "evidence": ["PMS-DA-D05-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D6010 is covered at 50%, but the payer requires pre-determination before treatment.", "policy_citation": "Delta Dental PPO policy section D.7.1", "recommended_action": "Submit the pre-D and wait for written approval before scheduling."}, {"finding": "D7953 approved â€” pre-determination required", "evidence": ["PMS-DA-D05-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D7953 is covered at 50%, but the payer requires pre-determination before treatment.", "policy_citation": "Delta Dental PPO policy section D.7.4", "recommended_action": "Submit the pre-D and wait for written approval before scheduling."}, {"finding": "Radiographic bone loss 4.5mm (38.0% of root support)", "evidence": ["XRAY-DA-D05-D02"], "dimension": "clinical", "explanation": "The X-ray documents 4.5mm of bone loss, meeting the 3mm the payer requires to establish graft and implant necessity.", "policy_citation": "ADA clinical criteria â€” radiographic evidence (PRD section 11)", "recommended_action": "None â€” radiographic threshold met."}, {"finding": "D6010 criteria score 1.000 â€” sufficient documentation", "evidence": ["CBCT-DA-D05-D04", "NOTE-DA-D05-D03", "XRAY-DA-D05-D02"], "dimension": "clinical", "explanation": "Weighted clinical criteria for D6010 scored 1.000, which the payer reads as sufficient documentation.", "policy_citation": "ADA clinical criteria â€” implant placement (PRD section 11)", "recommended_action": "None â€” documentation is sufficient."}, {"finding": "D7953 criteria score 1.000 â€” sufficient documentation", "evidence": ["CBCT-DA-D05-D04", "NOTE-DA-D05-D03", "XRAY-DA-D05-D02"], "dimension": "clinical", "explanation": "Weighted clinical criteria for D7953 scored 1.000, which the payer reads as sufficient documentation.", "policy_citation": "ADA clinical criteria â€” bone graft / ridge preservation (PRD section 11)", "recommended_action": "None â€” documentation is sufficient."}]	2026-08-05T16:18:30.516738	t	f	\N	t
PRED-SIM-DA-C07	suwanee_smiles	t	1800.00	f	t	f	f	1.000	t	0	0	0	[]	t	f	0	[]	{"xray_present": true, "downgrade_noted": true, "deductible_known": true, "no_fraud_signals": true, "bundling_reviewed": true, "narrative_present": true, "provider_verified": true, "frequency_limit_ok": true, "waiting_period_met": true, "perio_chart_present": true, "eligibility_verified": true, "pre_d_required_noted": true, "annual_max_sufficient": true, "clinical_note_present": false}	\N	approved	\N	f	t	[]	[{"finding": "Coverage active (PDP), annual maximum remaining $1,800.00", "evidence": ["INS-DA-C07-CARD-D02", "X12-DA-C07-271-D01"], "dimension": "eligibility", "explanation": "The patient's plan is active with $1,800.00 left against this year's maximum.", "policy_citation": "Delta Dental PPO plan certificate â€” eligibility provisions", "recommended_action": "None â€” eligibility confirmed."}, {"finding": "Missing tooth clause present on plan â€” payer confirmation: NOT confirmed", "evidence": ["INS-DA-C07-CARD-D02", "X12-DA-C07-271-D01"], "dimension": "eligibility", "explanation": "The plan carries a missing tooth clause, but the payer has not confirmed it applies to this tooth, so it is not being enforced against these procedures.", "policy_citation": "Delta Dental PPO plan certificate â€” missing tooth provision", "recommended_action": "Confirm the extraction date and whether the clause applies with the payer before submitting."}, {"finding": "D0330 approved", "evidence": ["HIST-DA-C07-PRIOR-D00", "PMS-DA-C07-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D0330 is covered at 100% with no conflicts detected.", "policy_citation": "Delta Dental PPO policy section D.1.4", "recommended_action": "None â€” ready to submit."}]	2026-08-05T16:18:48.669264	t	f	\N	f
PRED-SIM-DA-F03	suwanee_smiles	t	1800.00	f	t	f	t	1.000	t	2	2	2	[]	f	f	1	[]	{"xray_present": true, "downgrade_noted": true, "deductible_known": true, "no_fraud_signals": true, "bundling_reviewed": true, "narrative_present": true, "provider_verified": true, "frequency_limit_ok": false, "waiting_period_met": true, "perio_chart_present": true, "eligibility_verified": true, "pre_d_required_noted": true, "annual_max_sufficient": true, "clinical_note_present": true}	\N	denied	\N	t	f	["ELIG_FREQUENCY_LIMIT"]	[{"finding": "Coverage active (PPO), annual maximum remaining $1,800.00", "evidence": ["X12-DA-F03-271-D01"], "dimension": "eligibility", "explanation": "The patient's plan is active with $1,800.00 left against this year's maximum.", "policy_citation": "Delta Dental PPO plan certificate â€” eligibility provisions", "recommended_action": "None â€” eligibility confirmed."}, {"finding": "Missing tooth clause present on plan â€” payer confirmation: NOT confirmed", "evidence": ["X12-DA-F03-271-D01"], "dimension": "eligibility", "explanation": "The plan carries a missing tooth clause, but the payer has not confirmed it applies to this tooth, so it is not being enforced against these procedures.", "policy_citation": "Delta Dental PPO plan certificate â€” missing tooth provision", "recommended_action": "Confirm the extraction date and whether the clause applies with the payer before submitting."}, {"finding": "D2750 denied â€” frequency limit exceeded; pre-determination required", "evidence": ["HIST-DA-F03-PRIOR-D00", "PMS-DA-F03-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D2750 is covered at 50%, but the payer requires pre-determination before treatment.", "policy_citation": "Delta Dental PPO policy section D.4.3", "recommended_action": "Submit the pre-D and wait for written approval before scheduling."}, {"finding": "D2750 criteria score 1.000 â€” sufficient documentation", "evidence": ["NOTE-DA-F03-D03", "XRAY-DA-F03-D02"], "dimension": "clinical", "explanation": "Weighted clinical criteria for D2750 scored 1.000, which the payer reads as sufficient documentation.", "policy_citation": "ADA clinical criteria â€” crown restoration (PRD section 11)", "recommended_action": "None â€” documentation is sufficient."}]	2026-08-05T16:18:42.619450	t	f	\N	f
PRED-SIM-DA-A01	suwanee_smiles	t	1800.00	t	t	f	t	0.850	t	2	5	7	[]	t	t	1	[]	{"xray_present": true, "downgrade_noted": true, "deductible_known": true, "no_fraud_signals": true, "bundling_reviewed": false, "narrative_present": true, "provider_verified": true, "frequency_limit_ok": true, "waiting_period_met": true, "perio_chart_present": true, "eligibility_verified": true, "pre_d_required_noted": true, "annual_max_sufficient": true, "clinical_note_present": true}	\N	pended	\N	t	f	["COVERAGE_PRED_REQUIRED", "COVERAGE_BUNDLING_CONFLICT", "CLINICAL_XRAY_REQUIRED", "CLINICAL_NARRATIVE_REQUIRED", "COVERAGE_DOWNGRADE_APPLIED", "CLINICAL_CRITERIA_NOT_MET"]	[{"finding": "Coverage active (PPO), annual maximum remaining $1,800.00", "evidence": ["INS-DA-A01-CARD-D04", "X12-DA-A01-271-D01"], "dimension": "eligibility", "explanation": "The patient's plan is active with $1,800.00 left against this year's maximum.", "policy_citation": "Delta Dental PPO plan certificate â€” eligibility provisions", "recommended_action": "None â€” eligibility confirmed."}, {"finding": "Implant benefit present on this plan (applies to D6010, D7953, D6065)", "evidence": ["INS-DA-A01-CARD-D04", "X12-DA-A01-271-D01"], "dimension": "eligibility", "explanation": "This plan pays implant services at 50%, so D6010, D7953, D6065 can be considered.", "policy_citation": "Delta Dental PPO plan certificate â€” implant benefit provisions", "recommended_action": "None â€” implant benefit confirmed."}, {"finding": "Missing tooth clause present on plan â€” payer confirmation: NOT confirmed", "evidence": ["INS-DA-A01-CARD-D04", "X12-DA-A01-271-D01"], "dimension": "eligibility", "explanation": "The plan carries a missing tooth clause, but the payer has not confirmed it applies to this tooth, so it is not being enforced against these procedures.", "policy_citation": "Delta Dental PPO plan certificate â€” missing tooth provision", "recommended_action": "Confirm the extraction date and whether the clause applies with the payer before submitting."}, {"finding": "D6010 approved â€” pre-determination required", "evidence": ["PMS-DA-A01-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D6010 is covered at 50%, but the payer requires pre-determination before treatment.", "policy_citation": "Delta Dental PPO policy section D.7.1", "recommended_action": "Submit the pre-D and wait for written approval before scheduling."}, {"finding": "D7953 pended â€” bundled with D6010; pre-determination required", "evidence": ["PMS-DA-A01-SUPERBILL-D00", "NOTE-DA-A01-D03", "XRAY-DA-A01-D02"], "dimension": "coverage", "explanation": "The payer treats D7953 as part of D6010 unless it is documented as separately necessary.", "policy_citation": "Delta Dental PPO policy section D.7.4", "recommended_action": "Attach a narrative establishing necessity independent of the bundled procedure, plus the supporting X-ray; documented appeals overturn about 65% of the time."}, {"finding": "D6065 pended â€” downgraded to D2750; pre-determination required", "evidence": ["PMS-DA-A01-SUPERBILL-D00"], "dimension": "coverage", "explanation": "The plan reimburses D6065 at the D2750 fee schedule, so the patient owes the difference.", "policy_citation": "Delta Dental PPO policy section D.7.2", "recommended_action": "Give the patient a written estimate of the D6065-to-D2750 difference before treatment."}, {"finding": "Radiographic bone loss 4.2mm (35.0% of root support)", "evidence": ["XRAY-DA-A01-D02"], "dimension": "clinical", "explanation": "The X-ray documents 4.2mm of bone loss, meeting the 3mm the payer requires to establish graft and implant necessity.", "policy_citation": "ADA clinical criteria â€” radiographic evidence (PRD section 11)", "recommended_action": "None â€” radiographic threshold met."}, {"finding": "D6010 criteria score 0.900 â€” sufficient documentation", "evidence": ["NOTE-DA-A01-D03", "XRAY-DA-A01-D02"], "dimension": "clinical", "explanation": "Weighted clinical criteria for D6010 scored 0.900, which the payer reads as sufficient documentation.", "policy_citation": "ADA clinical criteria â€” implant placement (PRD section 11)", "recommended_action": "None â€” documentation is sufficient."}, {"finding": "D7953 criteria score 0.800 â€” pend â€” needs additional documentation", "evidence": ["NOTE-DA-A01-D03", "XRAY-DA-A01-D02"], "dimension": "clinical", "explanation": "Weighted clinical criteria for D7953 scored 0.800, which the payer reads as pend â€” needs additional documentation.", "policy_citation": "ADA clinical criteria â€” bone graft / ridge preservation (PRD section 11)", "recommended_action": "All required criteria for D7953 are met; add the optional supporting evidence (e.g. CBCT) to raise the score above the 0.85 auto-approve threshold."}]	2026-08-05T16:18:00.589648	t	f	\N	f
PRED-SIM-DA-C09	suwanee_smiles	t	1800.00	t	t	f	t	0.900	t	2	3	4	[]	t	f	0	[]	{"xray_present": true, "downgrade_noted": true, "deductible_known": true, "no_fraud_signals": true, "bundling_reviewed": true, "narrative_present": true, "provider_verified": true, "frequency_limit_ok": true, "waiting_period_met": true, "perio_chart_present": true, "eligibility_verified": true, "pre_d_required_noted": true, "annual_max_sufficient": true, "clinical_note_present": true}	\N	pended	\N	t	f	["COVERAGE_PRED_REQUIRED", "CLINICAL_MEDICAL_HISTORY_FLAG"]	[{"finding": "Coverage active (PPO), annual maximum remaining $1,800.00", "evidence": ["X12-DA-C09-271-D01"], "dimension": "eligibility", "explanation": "The patient's plan is active with $1,800.00 left against this year's maximum.", "policy_citation": "Delta Dental PPO plan certificate â€” eligibility provisions", "recommended_action": "None â€” eligibility confirmed."}, {"finding": "Implant benefit present on this plan (applies to D6010)", "evidence": ["X12-DA-C09-271-D01"], "dimension": "eligibility", "explanation": "This plan pays implant services at 50%, so D6010 can be considered.", "policy_citation": "Delta Dental PPO plan certificate â€” implant benefit provisions", "recommended_action": "None â€” implant benefit confirmed."}, {"finding": "Missing tooth clause present on plan â€” payer confirmation: NOT confirmed", "evidence": ["X12-DA-C09-271-D01"], "dimension": "eligibility", "explanation": "The plan carries a missing tooth clause, but the payer has not confirmed it applies to this tooth, so it is not being enforced against these procedures.", "policy_citation": "Delta Dental PPO plan certificate â€” missing tooth provision", "recommended_action": "Confirm the extraction date and whether the clause applies with the payer before submitting."}, {"finding": "D6010 approved â€” pre-determination required", "evidence": ["PMS-DA-C09-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D6010 is covered at 50%, but the payer requires pre-determination before treatment.", "policy_citation": "Delta Dental PPO policy section D.7.1", "recommended_action": "Submit the pre-D and wait for written approval before scheduling."}, {"finding": "Radiographic bone loss 4.2mm (35.0% of root support)", "evidence": ["XRAY-DA-C09-D02"], "dimension": "clinical", "explanation": "The X-ray documents 4.2mm of bone loss, meeting the 3mm the payer requires to establish graft and implant necessity.", "policy_citation": "ADA clinical criteria â€” radiographic evidence (PRD section 11)", "recommended_action": "None â€” radiographic threshold met."}, {"finding": "D6010 criteria score 0.900 â€” sufficient documentation", "evidence": ["NOTE-DA-C09-D03", "XRAY-DA-C09-D02"], "dimension": "clinical", "explanation": "Weighted clinical criteria for D6010 scored 0.900, which the payer reads as sufficient documentation.", "policy_citation": "ADA clinical criteria â€” implant placement (PRD section 11)", "recommended_action": "None â€” documentation is sufficient."}]	2026-08-05T16:18:51.596256	t	f	\N	t
PRED-SIM-DA-C02	suwanee_smiles	t	1800.00	f	t	f	t	0.100	f	2	0	4	["Pocket depth >=5mm in 6+ sites", "Bone loss >=25%", "Current periodontal chart"]	t	f	0	[]	{"xray_present": true, "downgrade_noted": true, "deductible_known": true, "no_fraud_signals": true, "bundling_reviewed": true, "narrative_present": true, "provider_verified": true, "frequency_limit_ok": true, "waiting_period_met": true, "perio_chart_present": false, "eligibility_verified": true, "pre_d_required_noted": true, "annual_max_sufficient": true, "clinical_note_present": true}	\N	pended	\N	t	f	["COVERAGE_PRED_REQUIRED", "CLINICAL_CRITERIA_NOT_MET", "CLINICAL_POCKET_DEPTH", "CLINICAL_BONE_LOSS_THRESHOLD", "CLINICAL_PERIO_CHART_REQUIRED"]	[{"finding": "Coverage active (PPO), annual maximum remaining $1,800.00", "evidence": ["X12-DA-C02-271-D01"], "dimension": "eligibility", "explanation": "The patient's plan is active with $1,800.00 left against this year's maximum.", "policy_citation": "Delta Dental PPO plan certificate â€” eligibility provisions", "recommended_action": "None â€” eligibility confirmed."}, {"finding": "Missing tooth clause present on plan â€” payer confirmation: NOT confirmed", "evidence": ["X12-DA-C02-271-D01"], "dimension": "eligibility", "explanation": "The plan carries a missing tooth clause, but the payer has not confirmed it applies to this tooth, so it is not being enforced against these procedures.", "policy_citation": "Delta Dental PPO plan certificate â€” missing tooth provision", "recommended_action": "Confirm the extraction date and whether the clause applies with the payer before submitting."}, {"finding": "D4260 pended â€” pre-determination required", "evidence": ["PMS-DA-C02-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D4260 is covered at 50%, but the payer requires pre-determination before treatment.", "policy_citation": "Delta Dental PPO policy section D.6.3", "recommended_action": "Submit the pre-D and wait for written approval before scheduling."}, {"finding": "Radiographic bone loss 2.1mm (20.0% of root support)", "evidence": ["XRAY-DA-C02-D03"], "dimension": "clinical", "explanation": "The X-ray documents 2.1mm of bone loss, short of the 3mm the payer requires to establish graft and implant necessity.", "policy_citation": "ADA clinical criteria â€” radiographic evidence (PRD section 11)", "recommended_action": "Obtain an updated PA X-ray or CBCT documenting at least 3mm of bone loss."}, {"finding": "D4260 criteria score 0.100 â€” insufficient documentation", "evidence": ["NOTE-DA-C02-D02", "XRAY-DA-C02-D03"], "dimension": "clinical", "explanation": "Weighted clinical criteria for D4260 scored 0.100, which the payer reads as insufficient documentation.", "policy_citation": "ADA clinical criteria â€” osseous surgery (PRD section 11)", "recommended_action": "Attach the missing required evidence for D4260: Pocket depth >=5mm in 6+ sites; Bone loss >=25%; Current periodontal chart."}, {"finding": "Missing required evidence: Pocket depth >=5mm in 6+ sites; Bone loss >=25%; Current periodontal chart", "evidence": ["NOTE-DA-C02-D02", "XRAY-DA-C02-D03"], "dimension": "clinical", "explanation": "One or more required clinical criteria have no supporting document on file.", "policy_citation": "ADA clinical criteria â€” required documentation (PRD section 11)", "recommended_action": "Attach: Pocket depth >=5mm in 6+ sites; Bone loss >=25%; Current periodontal chart."}]	2026-08-05T16:18:16.877958	t	f	\N	f
PRED-SIM-DA-M01	suwanee_smiles	t	1800.00	f	t	f	t	1.000	t	2	2	2	[]	t	f	0	[{"edge": "contradicts", "field": "member_id", "value_a": "DDL-999001-X", "value_b": "DDL-999001-A", "source_a": "x12_271", "source_b": "api"}]	{"xray_present": true, "downgrade_noted": true, "deductible_known": true, "no_fraud_signals": true, "bundling_reviewed": true, "narrative_present": true, "provider_verified": true, "frequency_limit_ok": true, "waiting_period_met": true, "perio_chart_present": true, "eligibility_verified": true, "pre_d_required_noted": true, "annual_max_sufficient": true, "clinical_note_present": true}	\N	pended	\N	t	f	["COVERAGE_PRED_REQUIRED", "ELIG_PLAN_NOT_FOUND"]	[{"finding": "Coverage active (PPO), annual maximum remaining $1,800.00", "evidence": ["INS-DA-M01-CARD-D02", "X12-DA-M01-271-D01"], "dimension": "eligibility", "explanation": "The patient's plan is active with $1,800.00 left against this year's maximum.", "policy_citation": "Delta Dental PPO plan certificate â€” eligibility provisions", "recommended_action": "None â€” eligibility confirmed."}, {"finding": "Missing tooth clause present on plan â€” payer confirmation: NOT confirmed", "evidence": ["INS-DA-M01-CARD-D02", "X12-DA-M01-271-D01"], "dimension": "eligibility", "explanation": "The plan carries a missing tooth clause, but the payer has not confirmed it applies to this tooth, so it is not being enforced against these procedures.", "policy_citation": "Delta Dental PPO plan certificate â€” missing tooth provision", "recommended_action": "Confirm the extraction date and whether the clause applies with the payer before submitting."}, {"finding": "D2750 pended â€” pre-determination required", "evidence": ["PMS-DA-M01-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D2750 is covered at 50%, but the payer requires pre-determination before treatment.", "policy_citation": "Delta Dental PPO policy section D.4.3", "recommended_action": "Submit the pre-D and wait for written approval before scheduling."}, {"finding": "D2750 criteria score 1.000 â€” sufficient documentation", "evidence": ["NOTE-DA-M01-D04", "XRAY-DA-M01-D03"], "dimension": "clinical", "explanation": "Weighted clinical criteria for D2750 scored 1.000, which the payer reads as sufficient documentation.", "policy_citation": "ADA clinical criteria â€” crown restoration (PRD section 11)", "recommended_action": "None â€” documentation is sufficient."}]	2026-08-05T16:18:32.126114	t	f	\N	t
PRED-SIM-DA-C04	suwanee_smiles	t	1800.00	f	t	f	t	0.400	f	1	0	2	["Radiograph confirming decay"]	t	f	0	[]	{"xray_present": false, "downgrade_noted": true, "deductible_known": true, "no_fraud_signals": true, "bundling_reviewed": true, "narrative_present": true, "provider_verified": true, "frequency_limit_ok": true, "waiting_period_met": true, "perio_chart_present": true, "eligibility_verified": true, "pre_d_required_noted": true, "annual_max_sufficient": true, "clinical_note_present": true}	\N	pended	\N	t	f	["COVERAGE_PRED_REQUIRED", "CLINICAL_XRAY_REQUIRED"]	[{"finding": "Coverage active (PPO), annual maximum remaining $1,800.00", "evidence": ["X12-DA-C04-271-D01"], "dimension": "eligibility", "explanation": "The patient's plan is active with $1,800.00 left against this year's maximum.", "policy_citation": "Delta Dental PPO plan certificate â€” eligibility provisions", "recommended_action": "None â€” eligibility confirmed."}, {"finding": "Missing tooth clause present on plan â€” payer confirmation: NOT confirmed", "evidence": ["X12-DA-C04-271-D01"], "dimension": "eligibility", "explanation": "The plan carries a missing tooth clause, but the payer has not confirmed it applies to this tooth, so it is not being enforced against these procedures.", "policy_citation": "Delta Dental PPO plan certificate â€” missing tooth provision", "recommended_action": "Confirm the extraction date and whether the clause applies with the payer before submitting."}, {"finding": "D2750 approved â€” pre-determination required", "evidence": ["PMS-DA-C04-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D2750 is covered at 50%, but the payer requires pre-determination before treatment.", "policy_citation": "Delta Dental PPO policy section D.4.3", "recommended_action": "Submit the pre-D and wait for written approval before scheduling."}, {"finding": "D2750 criteria score 0.400 â€” review required â€” significant gaps", "evidence": ["NOTE-DA-C04-D02"], "dimension": "clinical", "explanation": "Weighted clinical criteria for D2750 scored 0.400, which the payer reads as review required â€” significant gaps.", "policy_citation": "ADA clinical criteria â€” crown restoration (PRD section 11)", "recommended_action": "Attach the missing required evidence for D2750: Radiograph confirming decay."}, {"finding": "Missing required evidence: Radiograph confirming decay", "evidence": ["NOTE-DA-C04-D02"], "dimension": "clinical", "explanation": "One or more required clinical criteria have no supporting document on file.", "policy_citation": "ADA clinical criteria â€” required documentation (PRD section 11)", "recommended_action": "Attach: Radiograph confirming decay."}]	2026-08-05T16:18:19.995730	t	f	\N	f
PRED-SIM-DA-F05	suwanee_smiles	t	1800.00	t	t	f	t	0.900	t	2	3	4	[]	t	f	0	[]	{"xray_present": true, "downgrade_noted": true, "deductible_known": true, "no_fraud_signals": true, "bundling_reviewed": true, "narrative_present": true, "provider_verified": true, "frequency_limit_ok": true, "waiting_period_met": true, "perio_chart_present": true, "eligibility_verified": true, "pre_d_required_noted": true, "annual_max_sufficient": true, "clinical_note_present": true}	\N	pended	\N	t	f	["COVERAGE_PRED_REQUIRED"]	[{"finding": "Coverage active (PPO), annual maximum remaining $1,800.00", "evidence": ["X12-DA-F05-271-D01"], "dimension": "eligibility", "explanation": "The patient's plan is active with $1,800.00 left against this year's maximum.", "policy_citation": "Delta Dental PPO plan certificate â€” eligibility provisions", "recommended_action": "None â€” eligibility confirmed."}, {"finding": "Implant benefit present on this plan (applies to D6010)", "evidence": ["X12-DA-F05-271-D01"], "dimension": "eligibility", "explanation": "This plan pays implant services at 50%, so D6010 can be considered.", "policy_citation": "Delta Dental PPO plan certificate â€” implant benefit provisions", "recommended_action": "None â€” implant benefit confirmed."}, {"finding": "Missing tooth clause present on plan â€” payer confirmation: NOT confirmed", "evidence": ["X12-DA-F05-271-D01"], "dimension": "eligibility", "explanation": "The plan carries a missing tooth clause, but the payer has not confirmed it applies to this tooth, so it is not being enforced against these procedures.", "policy_citation": "Delta Dental PPO plan certificate â€” missing tooth provision", "recommended_action": "Confirm the extraction date and whether the clause applies with the payer before submitting."}, {"finding": "D6010 pended â€” pre-determination required", "evidence": ["PMS-DA-F05-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D6010 is covered at 50%, but the payer requires pre-determination before treatment.", "policy_citation": "Delta Dental PPO policy section D.7.1", "recommended_action": "Submit the pre-D and wait for written approval before scheduling."}, {"finding": "Radiographic bone loss 4.2mm (35.0% of root support)", "evidence": ["XRAY-DA-F05-D02"], "dimension": "clinical", "explanation": "The X-ray documents 4.2mm of bone loss, meeting the 3mm the payer requires to establish graft and implant necessity.", "policy_citation": "ADA clinical criteria â€” radiographic evidence (PRD section 11)", "recommended_action": "None â€” radiographic threshold met."}, {"finding": "D6010 criteria score 0.900 â€” sufficient documentation", "evidence": ["NOTE-DA-F05-D03", "XRAY-DA-F05-D02"], "dimension": "clinical", "explanation": "Weighted clinical criteria for D6010 scored 0.900, which the payer reads as sufficient documentation.", "policy_citation": "ADA clinical criteria â€” implant placement (PRD section 11)", "recommended_action": "None â€” documentation is sufficient."}]	2026-08-05T16:18:45.832033	t	f	\N	t
PRED-SIM-DA-C08	suwanee_smiles	t	1500.00	f	t	f	t	1.000	t	2	2	2	[]	t	f	0	[]	{"xray_present": true, "downgrade_noted": true, "deductible_known": true, "no_fraud_signals": true, "bundling_reviewed": true, "narrative_present": true, "provider_verified": true, "frequency_limit_ok": true, "waiting_period_met": true, "perio_chart_present": true, "eligibility_verified": true, "pre_d_required_noted": true, "annual_max_sufficient": true, "clinical_note_present": true}	\N	pended	\N	t	f	["COVERAGE_PRED_REQUIRED", "ELIG_COB_REQUIRED", "ADMIN_COB_PRIMARY_FIRST"]	[{"finding": "Coverage active (PPO), annual maximum remaining $1,500.00", "evidence": ["INS-DA-C08-CARD-D04", "X12-DA-C08-271-D01"], "dimension": "eligibility", "explanation": "The patient's plan is active with $1,500.00 left against this year's maximum.", "policy_citation": "Delta Dental PPO plan certificate â€” eligibility provisions", "recommended_action": "None â€” eligibility confirmed."}, {"finding": "Missing tooth clause present on plan â€” payer confirmation: NOT confirmed", "evidence": ["INS-DA-C08-CARD-D04", "X12-DA-C08-271-D01"], "dimension": "eligibility", "explanation": "The plan carries a missing tooth clause, but the payer has not confirmed it applies to this tooth, so it is not being enforced against these procedures.", "policy_citation": "Delta Dental PPO plan certificate â€” missing tooth provision", "recommended_action": "Confirm the extraction date and whether the clause applies with the payer before submitting."}, {"finding": "D2750 pended â€” pre-determination required", "evidence": ["PMS-DA-C08-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D2750 is covered at 50%, but the payer requires pre-determination before treatment.", "policy_citation": "Delta Dental PPO policy section D.4.3", "recommended_action": "Submit the pre-D and wait for written approval before scheduling."}, {"finding": "D2750 criteria score 1.000 â€” sufficient documentation", "evidence": ["NOTE-DA-C08-D03", "XRAY-DA-C08-D02"], "dimension": "clinical", "explanation": "Weighted clinical criteria for D2750 scored 1.000, which the payer reads as sufficient documentation.", "policy_citation": "ADA clinical criteria â€” crown restoration (PRD section 11)", "recommended_action": "None â€” documentation is sufficient."}]	2026-08-05T16:18:49.958434	t	f	\N	t
PRED-SIM-DA-U03	suwanee_smiles	t	1800.00	f	t	f	f	1.000	t	1	0	0	[]	t	f	0	[]	{"xray_present": true, "downgrade_noted": true, "deductible_known": true, "no_fraud_signals": true, "bundling_reviewed": true, "narrative_present": true, "provider_verified": true, "frequency_limit_ok": true, "waiting_period_met": true, "perio_chart_present": true, "eligibility_verified": true, "pre_d_required_noted": true, "annual_max_sufficient": true, "clinical_note_present": true}	\N	approved	\N	f	t	[]	[{"finding": "Coverage active (DPPO), annual maximum remaining $1,800.00", "evidence": ["INS-DA-U03-CARD-D02", "X12-DA-U03-271-D01"], "dimension": "eligibility", "explanation": "The patient's plan is active with $1,800.00 left against this year's maximum.", "policy_citation": "Delta Dental PPO plan certificate â€” eligibility provisions", "recommended_action": "None â€” eligibility confirmed."}, {"finding": "Missing tooth clause present on plan â€” payer confirmation: NOT confirmed", "evidence": ["INS-DA-U03-CARD-D02", "X12-DA-U03-271-D01"], "dimension": "eligibility", "explanation": "The plan carries a missing tooth clause, but the payer has not confirmed it applies to this tooth, so it is not being enforced against these procedures.", "policy_citation": "Delta Dental PPO plan certificate â€” missing tooth provision", "recommended_action": "Confirm the extraction date and whether the clause applies with the payer before submitting."}, {"finding": "D2391 approved", "evidence": ["PMS-DA-U03-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D2391 is covered at 80% with no conflicts detected.", "policy_citation": "Delta Dental PPO policy section D.3.1", "recommended_action": "None â€” ready to submit."}]	2026-08-06T05:18:44.488290	t	f	\N	t
PRED-SIM-DA-B02	suwanee_smiles	t	1800.00	t	t	t	t	0.700	t	1	2	4	[]	f	f	2	[]	{"xray_present": true, "downgrade_noted": true, "deductible_known": true, "no_fraud_signals": true, "bundling_reviewed": true, "narrative_present": true, "provider_verified": true, "frequency_limit_ok": true, "waiting_period_met": true, "perio_chart_present": true, "eligibility_verified": true, "pre_d_required_noted": true, "annual_max_sufficient": true, "clinical_note_present": false}	\N	denied	\N	t	f	["ELIG_MISSING_TOOTH_CLAUSE", "CLINICAL_EXTRACTION_DATE"]	[{"finding": "Coverage active (PPO), annual maximum remaining $1,800.00", "evidence": ["INS-DA-B02-CARD-D03", "X12-DA-B02-271-D01"], "dimension": "eligibility", "explanation": "The patient's plan is active with $1,800.00 left against this year's maximum.", "policy_citation": "Delta Dental PPO plan certificate â€” eligibility provisions", "recommended_action": "None â€” eligibility confirmed."}, {"finding": "Implant benefit present on this plan (applies to D6010, D6065)", "evidence": ["INS-DA-B02-CARD-D03", "X12-DA-B02-271-D01"], "dimension": "eligibility", "explanation": "This plan pays implant services at 50%, so D6010, D6065 can be considered.", "policy_citation": "Delta Dental PPO plan certificate â€” implant benefit provisions", "recommended_action": "None â€” implant benefit confirmed."}, {"finding": "Missing tooth clause present on plan â€” payer confirmation: confirmed", "evidence": ["INS-DA-B02-CARD-D03", "X12-DA-B02-271-D01"], "dimension": "eligibility", "explanation": "The plan excludes replacing teeth lost before coverage began, and the payer has confirmed the clause applies here.", "policy_citation": "Delta Dental PPO plan certificate â€” missing tooth provision", "recommended_action": "Document the extraction date; expect denial if the tooth was lost before the coverage start date."}, {"finding": "D6010 denied â€” blocked by missing tooth clause; pre-determination required", "evidence": ["PMS-DA-B02-SUPERBILL-D00"], "dimension": "coverage", "explanation": "The plan will not replace a tooth that was already missing when coverage began.", "policy_citation": "Delta Dental PPO policy section D.7.1", "recommended_action": "Provide the extraction date; appeal if the tooth was lost while the patient was covered."}, {"finding": "D6065 denied â€” blocked by missing tooth clause; pre-determination required", "evidence": ["PMS-DA-B02-SUPERBILL-D00"], "dimension": "coverage", "explanation": "The plan will not replace a tooth that was already missing when coverage began.", "policy_citation": "Delta Dental PPO policy section D.7.2", "recommended_action": "Provide the extraction date; appeal if the tooth was lost while the patient was covered."}, {"finding": "Radiographic bone loss 4.2mm (35.0% of root support)", "evidence": ["XRAY-DA-B02-D02"], "dimension": "clinical", "explanation": "The X-ray documents 4.2mm of bone loss, meeting the 3mm the payer requires to establish graft and implant necessity.", "policy_citation": "ADA clinical criteria â€” radiographic evidence (PRD section 11)", "recommended_action": "None â€” radiographic threshold met."}, {"finding": "D6010 criteria score 0.700 â€” pend â€” needs additional documentation", "evidence": ["XRAY-DA-B02-D02"], "dimension": "clinical", "explanation": "Weighted clinical criteria for D6010 scored 0.700, which the payer reads as pend â€” needs additional documentation.", "policy_citation": "ADA clinical criteria â€” implant placement (PRD section 11)", "recommended_action": "All required criteria for D6010 are met; add the optional supporting evidence (e.g. CBCT) to raise the score above the 0.85 auto-approve threshold."}]	2026-08-05T16:18:09.606440	t	f	\N	f
PRED-SIM-DA-B05	suwanee_smiles	t	1800.00	f	f	f	t	0.600	f	1	1	2	["Clinical note"]	f	f	0	[]	{"xray_present": true, "downgrade_noted": true, "deductible_known": true, "no_fraud_signals": true, "bundling_reviewed": true, "narrative_present": true, "provider_verified": true, "frequency_limit_ok": true, "waiting_period_met": false, "perio_chart_present": true, "eligibility_verified": true, "pre_d_required_noted": true, "annual_max_sufficient": true, "clinical_note_present": false}	\N	denied	\N	t	f	["ELIG_WAITING_PERIOD_NOT_MET", "CLINICAL_NARRATIVE_REQUIRED"]	[{"finding": "Coverage active (PPO), annual maximum remaining $1,800.00", "evidence": ["INS-DA-B05-CARD-D03", "X12-DA-B05-271-D01"], "dimension": "eligibility", "explanation": "The patient's plan is active with $1,800.00 left against this year's maximum.", "policy_citation": "Delta Dental PPO plan certificate â€” eligibility provisions", "recommended_action": "None â€” eligibility confirmed."}, {"finding": "Missing tooth clause present on plan â€” payer confirmation: NOT confirmed", "evidence": ["INS-DA-B05-CARD-D03", "X12-DA-B05-271-D01"], "dimension": "eligibility", "explanation": "The plan carries a missing tooth clause, but the payer has not confirmed it applies to this tooth, so it is not being enforced against these procedures.", "policy_citation": "Delta Dental PPO plan certificate â€” missing tooth provision", "recommended_action": "Confirm the extraction date and whether the clause applies with the payer before submitting."}, {"finding": "D2750 denied â€” pre-determination required", "evidence": ["PMS-DA-B05-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D2750 is covered at 50%, but the payer requires pre-determination before treatment.", "policy_citation": "Delta Dental PPO policy section D.4.3", "recommended_action": "Submit the pre-D and wait for written approval before scheduling."}, {"finding": "D2750 criteria score 0.600 â€” review required â€” significant gaps", "evidence": ["XRAY-DA-B05-D02"], "dimension": "clinical", "explanation": "Weighted clinical criteria for D2750 scored 0.600, which the payer reads as review required â€” significant gaps.", "policy_citation": "ADA clinical criteria â€” crown restoration (PRD section 11)", "recommended_action": "Attach the missing required evidence for D2750: Clinical note."}, {"finding": "Missing required evidence: Clinical note", "evidence": ["XRAY-DA-B05-D02"], "dimension": "clinical", "explanation": "One or more required clinical criteria have no supporting document on file.", "policy_citation": "ADA clinical criteria â€” required documentation (PRD section 11)", "recommended_action": "Attach: Clinical note."}]	2026-08-05T16:18:14.111856	t	f	\N	f
PRED-SIM-DA-C06	suwanee_smiles	t	1800.00	f	t	f	t	1.000	t	2	0	0	[]	t	f	0	[]	{"xray_present": true, "downgrade_noted": true, "deductible_known": true, "no_fraud_signals": true, "bundling_reviewed": true, "narrative_present": true, "provider_verified": true, "frequency_limit_ok": true, "waiting_period_met": true, "perio_chart_present": true, "eligibility_verified": true, "pre_d_required_noted": true, "annual_max_sufficient": true, "clinical_note_present": true}	\N	approved	\N	t	f	["COVERAGE_PRED_REQUIRED"]	[{"finding": "Coverage active (DPPO), annual maximum remaining $1,800.00", "evidence": ["X12-DA-C06-271-D01"], "dimension": "eligibility", "explanation": "The patient's plan is active with $1,800.00 left against this year's maximum.", "policy_citation": "Delta Dental PPO plan certificate â€” eligibility provisions", "recommended_action": "None â€” eligibility confirmed."}, {"finding": "Missing tooth clause present on plan â€” payer confirmation: NOT confirmed", "evidence": ["X12-DA-C06-271-D01"], "dimension": "eligibility", "explanation": "The plan carries a missing tooth clause, but the payer has not confirmed it applies to this tooth, so it is not being enforced against these procedures.", "policy_citation": "Delta Dental PPO plan certificate â€” missing tooth provision", "recommended_action": "Confirm the extraction date and whether the clause applies with the payer before submitting."}, {"finding": "D2740 approved â€” pre-determination required", "evidence": ["PMS-DA-C06-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D2740 is covered at 50%, but the payer requires pre-determination before treatment.", "policy_citation": "Delta Dental PPO policy section D.4.2", "recommended_action": "Submit the pre-D and wait for written approval before scheduling."}]	2026-08-05T16:18:47.233922	t	f	\N	t
PRED-SIM-DA-F01	suwanee_smiles	t	1800.00	f	t	f	t	1.000	t	2	0	0	[]	t	f	0	[]	{"xray_present": true, "downgrade_noted": true, "deductible_known": true, "no_fraud_signals": true, "bundling_reviewed": true, "narrative_present": true, "provider_verified": true, "frequency_limit_ok": true, "waiting_period_met": true, "perio_chart_present": true, "eligibility_verified": true, "pre_d_required_noted": true, "annual_max_sufficient": true, "clinical_note_present": true}	\N	pended	\N	t	f	["COVERAGE_DOWNGRADE_APPLIED", "COVERAGE_PRED_REQUIRED", "COVERAGE_SURFACE_MISMATCH"]	[{"finding": "Coverage active (PPO), annual maximum remaining $1,800.00", "evidence": ["X12-DA-F01-271-D01"], "dimension": "eligibility", "explanation": "The patient's plan is active with $1,800.00 left against this year's maximum.", "policy_citation": "Delta Dental PPO plan certificate â€” eligibility provisions", "recommended_action": "None â€” eligibility confirmed."}, {"finding": "Missing tooth clause present on plan â€” payer confirmation: NOT confirmed", "evidence": ["X12-DA-F01-271-D01"], "dimension": "eligibility", "explanation": "The plan carries a missing tooth clause, but the payer has not confirmed it applies to this tooth, so it is not being enforced against these procedures.", "policy_citation": "Delta Dental PPO plan certificate â€” missing tooth provision", "recommended_action": "Confirm the extraction date and whether the clause applies with the payer before submitting."}, {"finding": "D2740 pended â€” downgraded to D2750; pre-determination required", "evidence": ["PMS-DA-F01-SUPERBILL-D00"], "dimension": "coverage", "explanation": "The plan reimburses D2740 at the D2750 fee schedule, so the patient owes the difference.", "policy_citation": "Delta Dental PPO policy section D.4.2", "recommended_action": "Give the patient a written estimate of the D2740-to-D2750 difference before treatment."}]	2026-08-05T16:18:39.698637	t	f	\N	t
PRED-SIM-DA-F02	suwanee_smiles	t	1800.00	f	t	f	t	0.300	f	2	1	4	["Pocket depth >=5mm in 6+ sites", "Bone loss >=25%"]	f	f	0	[]	{"xray_present": true, "downgrade_noted": true, "deductible_known": true, "no_fraud_signals": true, "bundling_reviewed": true, "narrative_present": true, "provider_verified": true, "frequency_limit_ok": true, "waiting_period_met": true, "perio_chart_present": true, "eligibility_verified": true, "pre_d_required_noted": true, "annual_max_sufficient": true, "clinical_note_present": true}	\N	denied	\N	t	f	["COVERAGE_PRED_REQUIRED", "CLINICAL_CRITERIA_NOT_MET", "CLINICAL_POCKET_DEPTH", "CLINICAL_BONE_LOSS_THRESHOLD", "CLINICAL_XRAY_REQUIRED"]	[{"finding": "Coverage active (PPO), annual maximum remaining $1,800.00", "evidence": ["X12-DA-F02-271-D01"], "dimension": "eligibility", "explanation": "The patient's plan is active with $1,800.00 left against this year's maximum.", "policy_citation": "Delta Dental PPO plan certificate â€” eligibility provisions", "recommended_action": "None â€” eligibility confirmed."}, {"finding": "Missing tooth clause present on plan â€” payer confirmation: NOT confirmed", "evidence": ["X12-DA-F02-271-D01"], "dimension": "eligibility", "explanation": "The plan carries a missing tooth clause, but the payer has not confirmed it applies to this tooth, so it is not being enforced against these procedures.", "policy_citation": "Delta Dental PPO plan certificate â€” missing tooth provision", "recommended_action": "Confirm the extraction date and whether the clause applies with the payer before submitting."}, {"finding": "D4260 denied â€” pre-determination required", "evidence": ["PMS-DA-F02-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D4260 is covered at 50%, but the payer requires pre-determination before treatment.", "policy_citation": "Delta Dental PPO policy section D.6.3", "recommended_action": "Submit the pre-D and wait for written approval before scheduling."}, {"finding": "D4260 criteria score 0.300 â€” review required â€” significant gaps", "evidence": ["NOTE-DA-F02-D03", "PERIO-DA-F02-D02"], "dimension": "clinical", "explanation": "Weighted clinical criteria for D4260 scored 0.300, which the payer reads as review required â€” significant gaps.", "policy_citation": "ADA clinical criteria â€” osseous surgery (PRD section 11)", "recommended_action": "Attach the missing required evidence for D4260: Pocket depth >=5mm in 6+ sites; Bone loss >=25%."}, {"finding": "Missing required evidence: Pocket depth >=5mm in 6+ sites; Bone loss >=25%", "evidence": ["NOTE-DA-F02-D03", "PERIO-DA-F02-D02"], "dimension": "clinical", "explanation": "One or more required clinical criteria have no supporting document on file.", "policy_citation": "ADA clinical criteria â€” required documentation (PRD section 11)", "recommended_action": "Attach: Pocket depth >=5mm in 6+ sites; Bone loss >=25%."}]	2026-08-05T16:18:41.144698	t	f	\N	t
PRED-SIM-DA-F04	suwanee_smiles	t	1800.00	f	t	f	t	1.000	t	2	2	2	[]	t	t	1	[]	{"xray_present": true, "downgrade_noted": true, "deductible_known": true, "no_fraud_signals": true, "bundling_reviewed": false, "narrative_present": true, "provider_verified": true, "frequency_limit_ok": true, "waiting_period_met": true, "perio_chart_present": true, "eligibility_verified": true, "pre_d_required_noted": true, "annual_max_sufficient": true, "clinical_note_present": true}	\N	pended	\N	t	f	["COVERAGE_BUNDLING_CONFLICT", "COVERAGE_PRED_REQUIRED"]	[{"finding": "Coverage active (PPO), annual maximum remaining $1,800.00", "evidence": ["X12-DA-F04-271-D01"], "dimension": "eligibility", "explanation": "The patient's plan is active with $1,800.00 left against this year's maximum.", "policy_citation": "Delta Dental PPO plan certificate â€” eligibility provisions", "recommended_action": "None â€” eligibility confirmed."}, {"finding": "Missing tooth clause present on plan â€” payer confirmation: NOT confirmed", "evidence": ["X12-DA-F04-271-D01"], "dimension": "eligibility", "explanation": "The plan carries a missing tooth clause, but the payer has not confirmed it applies to this tooth, so it is not being enforced against these procedures.", "policy_citation": "Delta Dental PPO plan certificate â€” missing tooth provision", "recommended_action": "Confirm the extraction date and whether the clause applies with the payer before submitting."}, {"finding": "D2750 pended â€” bundled with D2950; pre-determination required", "evidence": ["HIST-DA-F04-PRIOR-D00", "PMS-DA-F04-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D2750 cannot be billed alongside D2950 on this plan, and the payer treats this pairing as non-separable.", "policy_citation": "Delta Dental PPO policy section D.4.3", "recommended_action": "Remove D2750 from the submission or bill it on a separate date of service."}, {"finding": "D2750 criteria score 1.000 â€” sufficient documentation", "evidence": ["NOTE-DA-F04-D03", "XRAY-DA-F04-D02"], "dimension": "clinical", "explanation": "Weighted clinical criteria for D2750 scored 1.000, which the payer reads as sufficient documentation.", "policy_citation": "ADA clinical criteria â€” crown restoration (PRD section 11)", "recommended_action": "None â€” documentation is sufficient."}]	2026-08-05T16:18:44.221126	t	f	\N	f
PRED-SIM-DA-M02	suwanee_smiles	t	1800.00	f	t	f	t	0.700	t	2	2	4	["Bone loss >=25%"]	t	f	0	[]	{"xray_present": true, "downgrade_noted": true, "deductible_known": true, "no_fraud_signals": true, "bundling_reviewed": true, "narrative_present": true, "provider_verified": true, "frequency_limit_ok": true, "waiting_period_met": true, "perio_chart_present": true, "eligibility_verified": true, "pre_d_required_noted": true, "annual_max_sufficient": true, "clinical_note_present": true}	\N	pended	\N	t	f	["COVERAGE_PRED_REQUIRED", "CLINICAL_CRITERIA_NOT_MET", "CLINICAL_BONE_LOSS_THRESHOLD", "CLINICAL_XRAY_REQUIRED"]	[{"finding": "Coverage active (PPO), annual maximum remaining $1,800.00", "evidence": ["X12-DA-M02-271-D01"], "dimension": "eligibility", "explanation": "The patient's plan is active with $1,800.00 left against this year's maximum.", "policy_citation": "Delta Dental PPO plan certificate â€” eligibility provisions", "recommended_action": "None â€” eligibility confirmed."}, {"finding": "Missing tooth clause present on plan â€” payer confirmation: NOT confirmed", "evidence": ["X12-DA-M02-271-D01"], "dimension": "eligibility", "explanation": "The plan carries a missing tooth clause, but the payer has not confirmed it applies to this tooth, so it is not being enforced against these procedures.", "policy_citation": "Delta Dental PPO plan certificate â€” missing tooth provision", "recommended_action": "Confirm the extraction date and whether the clause applies with the payer before submitting."}, {"finding": "D4260 pended â€” pre-determination required", "evidence": ["PMS-DA-M02-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D4260 is covered at 50%, but the payer requires pre-determination before treatment.", "policy_citation": "Delta Dental PPO policy section D.6.3", "recommended_action": "Submit the pre-D and wait for written approval before scheduling."}, {"finding": "D4260 criteria score 0.700 â€” pend â€” needs additional documentation", "evidence": ["NOTE-DA-M02-D03", "PERIO-DA-M02-D02"], "dimension": "clinical", "explanation": "Weighted clinical criteria for D4260 scored 0.700, which the payer reads as pend â€” needs additional documentation.", "policy_citation": "ADA clinical criteria â€” osseous surgery (PRD section 11)", "recommended_action": "Attach the missing required evidence for D4260: Bone loss >=25%."}, {"finding": "Missing required evidence: Bone loss >=25%", "evidence": ["NOTE-DA-M02-D03", "PERIO-DA-M02-D02"], "dimension": "clinical", "explanation": "One or more required clinical criteria have no supporting document on file.", "policy_citation": "ADA clinical criteria â€” required documentation (PRD section 11)", "recommended_action": "Attach: Bone loss >=25%."}]	2026-08-05T16:18:33.754515	t	f	\N	t
PRED-SIM-DA-M03	suwanee_smiles	t	1800.00	f	t	f	t	1.000	t	2	2	2	[]	t	f	0	[]	{"xray_present": true, "downgrade_noted": true, "deductible_known": true, "no_fraud_signals": true, "bundling_reviewed": true, "narrative_present": true, "provider_verified": true, "frequency_limit_ok": true, "waiting_period_met": true, "perio_chart_present": true, "eligibility_verified": true, "pre_d_required_noted": true, "annual_max_sufficient": true, "clinical_note_present": true}	\N	pended	\N	t	f	["COVERAGE_PRED_REQUIRED", "COVERAGE_SURFACE_MISMATCH"]	[{"finding": "Coverage active (PPO), annual maximum remaining $1,800.00", "evidence": ["X12-DA-M03-271-D01"], "dimension": "eligibility", "explanation": "The patient's plan is active with $1,800.00 left against this year's maximum.", "policy_citation": "Delta Dental PPO plan certificate â€” eligibility provisions", "recommended_action": "None â€” eligibility confirmed."}, {"finding": "Missing tooth clause present on plan â€” payer confirmation: NOT confirmed", "evidence": ["X12-DA-M03-271-D01"], "dimension": "eligibility", "explanation": "The plan carries a missing tooth clause, but the payer has not confirmed it applies to this tooth, so it is not being enforced against these procedures.", "policy_citation": "Delta Dental PPO plan certificate â€” missing tooth provision", "recommended_action": "Confirm the extraction date and whether the clause applies with the payer before submitting."}, {"finding": "D2750 pended â€” pre-determination required", "evidence": ["PMS-DA-M03-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D2750 is covered at 50%, but the payer requires pre-determination before treatment.", "policy_citation": "Delta Dental PPO policy section D.4.3", "recommended_action": "Submit the pre-D and wait for written approval before scheduling."}, {"finding": "D2750 criteria score 1.000 â€” sufficient documentation", "evidence": ["NOTE-DA-M03-D03", "XRAY-DA-M03-D02"], "dimension": "clinical", "explanation": "Weighted clinical criteria for D2750 scored 1.000, which the payer reads as sufficient documentation.", "policy_citation": "ADA clinical criteria â€” crown restoration (PRD section 11)", "recommended_action": "None â€” documentation is sufficient."}]	2026-08-05T16:18:35.228192	t	f	\N	t
PRED-SIM-DA-M04	suwanee_smiles	t	1800.00	t	t	f	t	0.900	t	2	3	4	[]	t	f	0	[]	{"xray_present": true, "downgrade_noted": true, "deductible_known": true, "no_fraud_signals": true, "bundling_reviewed": true, "narrative_present": true, "provider_verified": true, "frequency_limit_ok": true, "waiting_period_met": true, "perio_chart_present": true, "eligibility_verified": true, "pre_d_required_noted": true, "annual_max_sufficient": true, "clinical_note_present": true}	\N	pended	\N	t	f	["COVERAGE_PRED_REQUIRED", "ADMIN_DUPLICATE_PRED"]	[{"finding": "Coverage active (PPO), annual maximum remaining $1,800.00", "evidence": ["X12-DA-M04-271-D01"], "dimension": "eligibility", "explanation": "The patient's plan is active with $1,800.00 left against this year's maximum.", "policy_citation": "Delta Dental PPO plan certificate â€” eligibility provisions", "recommended_action": "None â€” eligibility confirmed."}, {"finding": "Implant benefit present on this plan (applies to D6010)", "evidence": ["X12-DA-M04-271-D01"], "dimension": "eligibility", "explanation": "This plan pays implant services at 50%, so D6010 can be considered.", "policy_citation": "Delta Dental PPO plan certificate â€” implant benefit provisions", "recommended_action": "None â€” implant benefit confirmed."}, {"finding": "Missing tooth clause present on plan â€” payer confirmation: NOT confirmed", "evidence": ["X12-DA-M04-271-D01"], "dimension": "eligibility", "explanation": "The plan carries a missing tooth clause, but the payer has not confirmed it applies to this tooth, so it is not being enforced against these procedures.", "policy_citation": "Delta Dental PPO plan certificate â€” missing tooth provision", "recommended_action": "Confirm the extraction date and whether the clause applies with the payer before submitting."}, {"finding": "D6010 pended â€” pre-determination required", "evidence": ["HIST-DA-M04-PRIOR-D00", "PMS-DA-M04-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D6010 is covered at 50%, but the payer requires pre-determination before treatment.", "policy_citation": "Delta Dental PPO policy section D.7.1", "recommended_action": "Submit the pre-D and wait for written approval before scheduling."}, {"finding": "Radiographic bone loss 4.2mm (35.0% of root support)", "evidence": ["XRAY-DA-M04-D02"], "dimension": "clinical", "explanation": "The X-ray documents 4.2mm of bone loss, meeting the 3mm the payer requires to establish graft and implant necessity.", "policy_citation": "ADA clinical criteria â€” radiographic evidence (PRD section 11)", "recommended_action": "None â€” radiographic threshold met."}, {"finding": "D6010 criteria score 0.900 â€” sufficient documentation", "evidence": ["NOTE-DA-M04-D03", "XRAY-DA-M04-D02"], "dimension": "clinical", "explanation": "Weighted clinical criteria for D6010 scored 0.900, which the payer reads as sufficient documentation.", "policy_citation": "ADA clinical criteria â€” implant placement (PRD section 11)", "recommended_action": "None â€” documentation is sufficient."}]	2026-08-05T16:18:36.663215	t	f	\N	t
PRED-SIM-DA-M05	suwanee_smiles	t	1800.00	f	t	f	t	0.400	f	2	0	2	["Radiograph confirming decay"]	t	f	0	[]	{"xray_present": true, "downgrade_noted": true, "deductible_known": true, "no_fraud_signals": true, "bundling_reviewed": true, "narrative_present": true, "provider_verified": true, "frequency_limit_ok": true, "waiting_period_met": true, "perio_chart_present": true, "eligibility_verified": true, "pre_d_required_noted": true, "annual_max_sufficient": true, "clinical_note_present": true}	\N	pended	\N	t	f	["COVERAGE_PRED_REQUIRED", "CLINICAL_XRAY_REQUIRED"]	[{"finding": "Coverage active (PPO), annual maximum remaining $1,800.00", "evidence": ["X12-DA-M05-271-D01"], "dimension": "eligibility", "explanation": "The patient's plan is active with $1,800.00 left against this year's maximum.", "policy_citation": "Delta Dental PPO plan certificate â€” eligibility provisions", "recommended_action": "None â€” eligibility confirmed."}, {"finding": "Missing tooth clause present on plan â€” payer confirmation: NOT confirmed", "evidence": ["X12-DA-M05-271-D01"], "dimension": "eligibility", "explanation": "The plan carries a missing tooth clause, but the payer has not confirmed it applies to this tooth, so it is not being enforced against these procedures.", "policy_citation": "Delta Dental PPO plan certificate â€” missing tooth provision", "recommended_action": "Confirm the extraction date and whether the clause applies with the payer before submitting."}, {"finding": "D2750 pended â€” pre-determination required", "evidence": ["PMS-DA-M05-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D2750 is covered at 50%, but the payer requires pre-determination before treatment.", "policy_citation": "Delta Dental PPO policy section D.4.3", "recommended_action": "Submit the pre-D and wait for written approval before scheduling."}, {"finding": "D2750 criteria score 0.400 â€” review required â€” significant gaps", "evidence": ["NOTE-DA-M05-D03", "XRAY-DA-M05-D02"], "dimension": "clinical", "explanation": "Weighted clinical criteria for D2750 scored 0.400, which the payer reads as review required â€” significant gaps.", "policy_citation": "ADA clinical criteria â€” crown restoration (PRD section 11)", "recommended_action": "Attach the missing required evidence for D2750: Radiograph confirming decay."}, {"finding": "Missing required evidence: Radiograph confirming decay", "evidence": ["NOTE-DA-M05-D03", "XRAY-DA-M05-D02"], "dimension": "clinical", "explanation": "One or more required clinical criteria have no supporting document on file.", "policy_citation": "ADA clinical criteria â€” required documentation (PRD section 11)", "recommended_action": "Attach: Radiograph confirming decay."}]	2026-08-05T16:18:38.267313	t	f	\N	t
PRED-SIM-DA-U01	suwanee_smiles	t	1800.00	f	t	f	f	1.000	t	1	0	0	[]	t	f	0	[]	{"xray_present": true, "downgrade_noted": true, "deductible_known": true, "no_fraud_signals": true, "bundling_reviewed": true, "narrative_present": true, "provider_verified": true, "frequency_limit_ok": true, "waiting_period_met": true, "perio_chart_present": true, "eligibility_verified": true, "pre_d_required_noted": true, "annual_max_sufficient": true, "clinical_note_present": true}	\N	approved	\N	f	t	[]	[{"finding": "Coverage active (PPO), annual maximum remaining $1,800.00", "evidence": ["INS-DA-U01-CARD-D02", "X12-DA-U01-271-D01"], "dimension": "eligibility", "explanation": "The patient's plan is active with $1,800.00 left against this year's maximum.", "policy_citation": "Delta Dental PPO plan certificate â€” eligibility provisions", "recommended_action": "None â€” eligibility confirmed."}, {"finding": "Missing tooth clause present on plan â€” payer confirmation: NOT confirmed", "evidence": ["INS-DA-U01-CARD-D02", "X12-DA-U01-271-D01"], "dimension": "eligibility", "explanation": "The plan carries a missing tooth clause, but the payer has not confirmed it applies to this tooth, so it is not being enforced against these procedures.", "policy_citation": "Delta Dental PPO plan certificate â€” missing tooth provision", "recommended_action": "Confirm the extraction date and whether the clause applies with the payer before submitting."}, {"finding": "D1110 approved", "evidence": ["HIST-DA-U01-PRIOR-D00", "PMS-DA-U01-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D1110 is covered at 100% with no conflicts detected.", "policy_citation": "Delta Dental PPO policy section D.2.1", "recommended_action": "None â€” ready to submit."}]	2026-08-06T05:18:41.429178	t	f	\N	t
PRED-SIM-DA-U02	suwanee_smiles	t	1800.00	f	t	f	f	1.000	t	1	0	0	[]	t	f	0	[]	{"xray_present": true, "downgrade_noted": true, "deductible_known": true, "no_fraud_signals": true, "bundling_reviewed": true, "narrative_present": true, "provider_verified": true, "frequency_limit_ok": true, "waiting_period_met": true, "perio_chart_present": true, "eligibility_verified": true, "pre_d_required_noted": true, "annual_max_sufficient": true, "clinical_note_present": true}	\N	approved	\N	f	t	[]	[{"finding": "Coverage active (PPO), annual maximum remaining $1,800.00", "evidence": ["INS-DA-U02-CARD-D02", "X12-DA-U02-271-D01"], "dimension": "eligibility", "explanation": "The patient's plan is active with $1,800.00 left against this year's maximum.", "policy_citation": "Delta Dental PPO plan certificate â€” eligibility provisions", "recommended_action": "None â€” eligibility confirmed."}, {"finding": "Missing tooth clause present on plan â€” payer confirmation: NOT confirmed", "evidence": ["INS-DA-U02-CARD-D02", "X12-DA-U02-271-D01"], "dimension": "eligibility", "explanation": "The plan carries a missing tooth clause, but the payer has not confirmed it applies to this tooth, so it is not being enforced against these procedures.", "policy_citation": "Delta Dental PPO plan certificate â€” missing tooth provision", "recommended_action": "Confirm the extraction date and whether the clause applies with the payer before submitting."}, {"finding": "D0274 approved", "evidence": ["HIST-DA-U02-PRIOR-D00", "PMS-DA-U02-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D0274 is covered at 100% with no conflicts detected.", "policy_citation": "Delta Dental PPO policy section D.1.2", "recommended_action": "None â€” ready to submit."}]	2026-08-06T05:18:42.963747	t	f	\N	t
PRED-SIM-DA-U04	suwanee_smiles	t	1800.00	f	t	f	f	1.000	t	1	0	0	[]	t	f	0	[]	{"xray_present": true, "downgrade_noted": true, "deductible_known": true, "no_fraud_signals": true, "bundling_reviewed": true, "narrative_present": true, "provider_verified": true, "frequency_limit_ok": true, "waiting_period_met": true, "perio_chart_present": true, "eligibility_verified": true, "pre_d_required_noted": true, "annual_max_sufficient": true, "clinical_note_present": true}	\N	approved	\N	f	t	[]	[{"finding": "Coverage active (PDP), annual maximum remaining $1,800.00", "evidence": ["INS-DA-U04-CARD-D02", "X12-DA-U04-271-D01"], "dimension": "eligibility", "explanation": "The patient's plan is active with $1,800.00 left against this year's maximum.", "policy_citation": "Delta Dental PPO plan certificate â€” eligibility provisions", "recommended_action": "None â€” eligibility confirmed."}, {"finding": "Missing tooth clause present on plan â€” payer confirmation: NOT confirmed", "evidence": ["INS-DA-U04-CARD-D02", "X12-DA-U04-271-D01"], "dimension": "eligibility", "explanation": "The plan carries a missing tooth clause, but the payer has not confirmed it applies to this tooth, so it is not being enforced against these procedures.", "policy_citation": "Delta Dental PPO plan certificate â€” missing tooth provision", "recommended_action": "Confirm the extraction date and whether the clause applies with the payer before submitting."}, {"finding": "D7140 approved", "evidence": ["PMS-DA-U04-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D7140 is covered at 80% with no conflicts detected.", "policy_citation": "Delta Dental PPO policy section D.8.1", "recommended_action": "None â€” ready to submit."}]	2026-08-06T05:18:45.766294	t	f	\N	t
PRED-SIM-DA-U05	suwanee_smiles	t	1800.00	f	t	f	f	1.000	t	2	0	0	[]	t	f	0	[]	{"xray_present": true, "downgrade_noted": true, "deductible_known": true, "no_fraud_signals": true, "bundling_reviewed": true, "narrative_present": true, "provider_verified": true, "frequency_limit_ok": true, "waiting_period_met": true, "perio_chart_present": true, "eligibility_verified": true, "pre_d_required_noted": true, "annual_max_sufficient": true, "clinical_note_present": true}	\N	approved	\N	f	t	[]	[{"finding": "Coverage active (PPO), annual maximum remaining $1,800.00", "evidence": ["INS-DA-U05-CARD-D02", "X12-DA-U05-271-D01"], "dimension": "eligibility", "explanation": "The patient's plan is active with $1,800.00 left against this year's maximum.", "policy_citation": "Delta Dental PPO plan certificate â€” eligibility provisions", "recommended_action": "None â€” eligibility confirmed."}, {"finding": "Missing tooth clause present on plan â€” payer confirmation: NOT confirmed", "evidence": ["INS-DA-U05-CARD-D02", "X12-DA-U05-271-D01"], "dimension": "eligibility", "explanation": "The plan carries a missing tooth clause, but the payer has not confirmed it applies to this tooth, so it is not being enforced against these procedures.", "policy_citation": "Delta Dental PPO plan certificate â€” missing tooth provision", "recommended_action": "Confirm the extraction date and whether the clause applies with the payer before submitting."}, {"finding": "D4910 approved", "evidence": ["HIST-DA-U05-PRIOR-D00", "PMS-DA-U05-SUPERBILL-D00"], "dimension": "coverage", "explanation": "D4910 is covered at 80% with no conflicts detected.", "policy_citation": "Delta Dental PPO policy section D.6.4", "recommended_action": "None â€” ready to submit."}]	2026-08-06T05:18:47.033929	t	f	\N	t
\.


--
-- Data for Name: procedure_lines; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.procedure_lines (procedure_line_id, pred_request_id, tenant_id, line_no, cdt_code, tooth_number, tooth_surface, arch, quadrant, fee, payer_allowed, requires_pred, description) FROM stdin;
325	PRED-SIM-DA-M02	suwanee_smiles	1	D4260	\N	\N	lower	LR	1850.00	1004.50	t	Osseous surgery LR quadrant
326	PRED-SIM-DA-M03	suwanee_smiles	1	D2750	14	MOD	upper	UL	1450.00	1190.00	t	Crown PFM upper left molar
327	PRED-SIM-DA-M04	suwanee_smiles	1	D6010	19	\N	lower	LL	2800.00	1985.00	t	Implant body
328	PRED-SIM-DA-M05	suwanee_smiles	1	D2750	3	MO	upper	UR	1450.00	1190.00	t	Crown PFM upper right molar
329	PRED-SIM-DA-F01	suwanee_smiles	1	D2740	8	MI	upper	UR	1650.00	1250.00	t	Crown all-ceramic anterior â€” billed
330	PRED-SIM-DA-F02	suwanee_smiles	1	D4260	\N	\N	upper	UR	1850.00	1004.50	t	Osseous surgery UR quadrant
331	PRED-SIM-DA-F03	suwanee_smiles	1	D2750	3	MOD	upper	UR	1450.00	1190.00	t	Crown PFM upper right molar
332	PRED-SIM-DA-F04	suwanee_smiles	1	D2750	14	MOD	upper	UL	1450.00	1190.00	t	Crown PFM â€” billed today
333	PRED-SIM-DA-F05	suwanee_smiles	1	D6010	19	\N	lower	LL	2800.00	1985.00	t	Implant body
334	PRED-SIM-DA-C06	suwanee_smiles	1	D2740	8	MI	upper	UR	1250.00	1312.50	t	Crown all-ceramic anterior
335	PRED-SIM-DA-C07	suwanee_smiles	1	D0330	\N	\N	\N	\N	155.00	155.70	t	Panoramic radiograph
336	PRED-SIM-DA-C08	suwanee_smiles	1	D2750	3	MOD	upper	UR	1190.00	1190.00	t	Crown PFM upper right molar
337	PRED-SIM-DA-C09	suwanee_smiles	1	D6010	19	\N	lower	LL	1985.00	1985.00	t	Implant body â€” endosteal
338	PRED-SIM-DA-C10	suwanee_smiles	1	D2750	14	MOD	upper	UL	1190.00	1190.00	t	Crown PFM upper left molar
349	PRED-SIM-TB-A01	tampa_smiles	1	D2750	14	MOD	upper	UL	1400.00	1187.03	t	Crown PFM upper left molar
350	PRED-SIM-TB-B01	tampa_smiles	1	D6010	19	\N	lower	LL	2800.00	1875.83	t	Implant body â€” endosteal
351	PRED-SIM-TB-C01	tampa_smiles	1	D4341	\N	\N	upper	UR	420.00	285.20	t	SRP upper right quadrant
352	PRED-SIM-TB-C01	tampa_smiles	2	D4341	\N	\N	upper	UL	420.00	285.20	t	SRP upper left quadrant
353	PRED-SIM-TB-D01	tampa_smiles	1	D2740	8	MIF	upper	UR	1650.00	1181.25	t	Crown â€” all-ceramic, anterior
354	PRED-SIM-TB-U01	tampa_smiles	1	D1110	\N	\N	\N	\N	150.00	112.47	t	Prophylaxis â€” adult
355	PRED-SIM-DL-A01	dallas_dental	1	D6010	30	\N	lower	LR	2800.00	2183.50	t	Implant body â€” endosteal
356	PRED-SIM-DL-A01	dallas_dental	2	D6065	30	\N	lower	LR	1800.00	1309.00	t	Implant crown â€” ceramic
357	PRED-SIM-DL-B01	dallas_dental	1	D4260	\N	\N	upper	UR	1200.00	1104.95	t	Osseous surgery â€” four or more teeth, upper right
358	PRED-SIM-DL-C01	dallas_dental	1	D2750	3	MOD	upper	UR	1500.00	1309.00	t	Crown PFM upper right molar
359	PRED-SIM-DL-D01	dallas_dental	1	D8090	\N	\N	\N	\N	4500.00	\N	t	Comprehensive orthodontic treatment â€” adult dentition
360	PRED-SIM-DL-U01	dallas_dental	1	D0330	\N	\N	\N	\N	185.00	174.76	t	Panoramic radiographic image
272	PRED-SIM-DA-A01	suwanee_smiles	1	D6010	19	\N	lower	LL	2800.00	1985.00	t	Implant body â€” endosteal
273	PRED-SIM-DA-A01	suwanee_smiles	2	D7953	19	\N	lower	LL	950.00	425.00	t	Bone replacement graft
274	PRED-SIM-DA-A01	suwanee_smiles	3	D6065	19	\N	lower	LL	1800.00	1190.00	t	Implant crown PFM
275	PRED-SIM-DA-A02	suwanee_smiles	1	D2750	3	MOD	upper	UR	1450.00	1190.00	t	Crown PFM upper right molar
276	PRED-SIM-DA-A03	suwanee_smiles	1	D3330	30	\N	lower	LR	1200.00	1050.00	t	Root canal molar
277	PRED-SIM-DA-A03	suwanee_smiles	2	D2750	30	MODBL	lower	LR	1450.00	1190.00	t	Crown PFM
278	PRED-SIM-DA-A04	suwanee_smiles	1	D4341	\N	\N	upper	UR	285.00	271.62	t	SRP UR
279	PRED-SIM-DA-A04	suwanee_smiles	2	D4341	\N	\N	upper	UL	285.00	271.62	t	SRP UL
280	PRED-SIM-DA-A04	suwanee_smiles	3	D4341	\N	\N	lower	LR	285.00	271.62	t	SRP LR
281	PRED-SIM-DA-A04	suwanee_smiles	4	D4341	\N	\N	lower	LL	285.00	271.62	t	SRP LL
282	PRED-SIM-DA-A05	suwanee_smiles	1	D0330	\N	\N	\N	\N	195.00	158.87	t	Panoramic radiograph
283	PRED-SIM-DA-B01	suwanee_smiles	1	D6010	14	\N	upper	UL	2800.00	1985.00	t	Implant body
284	PRED-SIM-DA-B01	suwanee_smiles	2	D6065	14	\N	upper	UL	1800.00	1190.00	t	Implant crown
285	PRED-SIM-DA-B02	suwanee_smiles	1	D6010	19	\N	lower	LL	2800.00	1985.00	t	Implant body
286	PRED-SIM-DA-B02	suwanee_smiles	2	D6065	19	\N	lower	LL	1800.00	1190.00	t	Implant crown
287	PRED-SIM-DA-B03	suwanee_smiles	1	D2750	3	MO	upper	UR	1450.00	1190.00	t	Crown PFM â€” last approved 2023
288	PRED-SIM-DA-B04	suwanee_smiles	1	D6010	19	\N	lower	LL	2800.00	1985.00	t	Implant body
289	PRED-SIM-DA-B04	suwanee_smiles	2	D7953	19	\N	lower	LL	950.00	425.00	t	Bone graft â€” insufficient documentation
290	PRED-SIM-DA-B05	suwanee_smiles	1	D2750	13	DO	upper	UL	1450.00	1190.00	t	Crown PFM
291	PRED-SIM-DA-C01	suwanee_smiles	1	D6010	19	\N	lower	LL	2800.00	1985.00	t	Implant body â€” endosteal
292	PRED-SIM-DA-C01	suwanee_smiles	2	D7953	19	\N	lower	LL	950.00	425.00	t	Bone replacement graft
293	PRED-SIM-DA-C02	suwanee_smiles	1	D4260	14	\N	upper	UL	1850.00	1004.50	t	Osseous surgery UL quadrant
294	PRED-SIM-DA-C03	suwanee_smiles	1	D6010	3	\N	upper	UR	2800.00	1985.00	t	Implant body #3
295	PRED-SIM-DA-C03	suwanee_smiles	2	D6010	14	\N	upper	UL	2800.00	1985.00	t	Implant body #14
296	PRED-SIM-DA-C03	suwanee_smiles	3	D6010	19	\N	lower	LL	2800.00	1985.00	t	Implant body #19
297	PRED-SIM-DA-C03	suwanee_smiles	4	D6010	30	\N	lower	LR	2800.00	1985.00	t	Implant body #30
344	PRED-SIM-DA-U01	suwanee_smiles	1	D1110	\N	\N	\N	\N	150.00	112.75	t	Prophylaxis â€” adult
345	PRED-SIM-DA-U02	suwanee_smiles	1	D0274	\N	\N	\N	\N	85.00	76.87	t	Bitewings â€” four radiographic images
346	PRED-SIM-DA-U03	suwanee_smiles	1	D2391	14	O	upper	UL	175.00	\N	t	Resin composite â€” one surface, posterior
347	PRED-SIM-DA-U04	suwanee_smiles	1	D7140	32	\N	lower	LR	185.00	185.83	t	Extraction â€” erupted tooth or exposed root
348	PRED-SIM-DA-U05	suwanee_smiles	1	D4910	\N	\N	\N	\N	175.00	148.62	t	Periodontal maintenance
298	PRED-SIM-DA-C03	suwanee_smiles	5	D6065	3	\N	upper	UR	1800.00	1190.00	t	Implant crown #3
299	PRED-SIM-DA-C03	suwanee_smiles	6	D6065	14	\N	upper	UL	1800.00	1190.00	t	Implant crown #14
300	PRED-SIM-DA-C03	suwanee_smiles	7	D6065	19	\N	lower	LL	1800.00	1190.00	t	Implant crown #19
301	PRED-SIM-DA-C03	suwanee_smiles	8	D6065	30	\N	lower	LR	1800.00	1190.00	t	Implant crown #30
302	PRED-SIM-DA-C04	suwanee_smiles	1	D2750	3	MOD	upper	UR	1450.00	1190.00	t	Crown PFM upper right molar
303	PRED-SIM-DA-C05	suwanee_smiles	1	D2750	14	MO	upper	UL	1450.00	1190.00	t	Crown PFM upper left molar
304	PRED-SIM-DA-D01	suwanee_smiles	1	D4260	3	\N	upper	UR	1850.00	1004.50	t	Osseous surgery UR quadrant
305	PRED-SIM-DA-D01	suwanee_smiles	2	D6010	3	\N	upper	UR	2800.00	1985.00	t	Implant body #3
306	PRED-SIM-DA-D01	suwanee_smiles	3	D7953	3	\N	upper	UR	950.00	425.00	t	Bone replacement graft #3
307	PRED-SIM-DA-D02	suwanee_smiles	1	D6010	3	\N	upper	UR	3500.00	1985.00	t	Implant body #3
308	PRED-SIM-DA-D02	suwanee_smiles	2	D6010	6	\N	upper	UR	3500.00	1985.00	t	Implant body #6
309	PRED-SIM-DA-D02	suwanee_smiles	3	D6010	11	\N	upper	UL	3500.00	1985.00	t	Implant body #11
310	PRED-SIM-DA-D02	suwanee_smiles	4	D6010	14	\N	upper	UL	3500.00	1985.00	t	Implant body #14
311	PRED-SIM-DA-D02	suwanee_smiles	5	D7953	3	\N	upper	UR	1300.00	425.00	t	Bone graft #3
312	PRED-SIM-DA-D02	suwanee_smiles	6	D7953	6	\N	upper	UR	1300.00	425.00	t	Bone graft #6
313	PRED-SIM-DA-D02	suwanee_smiles	7	D7953	11	\N	upper	UL	1300.00	425.00	t	Bone graft #11
314	PRED-SIM-DA-D02	suwanee_smiles	8	D7953	14	\N	upper	UL	1300.00	425.00	t	Bone graft #14
315	PRED-SIM-DA-D02	suwanee_smiles	9	D6065	3	\N	upper	UR	4000.00	1190.00	t	Implant crown #3
316	PRED-SIM-DA-D02	suwanee_smiles	10	D6065	6	\N	upper	UR	4000.00	1190.00	t	Implant crown #6
317	PRED-SIM-DA-D02	suwanee_smiles	11	D6065	11	\N	upper	UL	4000.00	1190.00	t	Implant crown #11
318	PRED-SIM-DA-D02	suwanee_smiles	12	D6065	14	\N	upper	UL	4000.00	1190.00	t	Implant crown #14
319	PRED-SIM-DA-D03	suwanee_smiles	1	D6010	19	\N	lower	LL	2800.00	1985.00	t	Implant body
320	PRED-SIM-DA-D03	suwanee_smiles	2	D6065	19	\N	lower	LL	1800.00	1190.00	t	Implant crown
321	PRED-SIM-DA-D04	suwanee_smiles	1	D2740	8	MI	upper	UR	1650.00	1250.00	t	Crown all-ceramic anterior
322	PRED-SIM-DA-D05	suwanee_smiles	1	D6010	19	\N	lower	LL	2800.00	1985.00	t	Implant body
323	PRED-SIM-DA-D05	suwanee_smiles	2	D7953	19	\N	lower	LL	950.00	425.00	t	Bone graft â€” fully documented
324	PRED-SIM-DA-M01	suwanee_smiles	1	D2750	19	MOD	lower	LL	1450.00	1190.00	t	Crown PFM lower left molar
\.


--
-- Data for Name: providers; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.providers (provider_npi, tenant_id, first_name, last_name, specialty, license_state, license_expiry, credentialed, out_of_network, sanctions, name, credential, taxonomy_code, practice_name, address, phone, network_status, oig_excluded, nppes_verified, nppes_verified_at, source) FROM stdin;
1134534266	suwanee_smiles	SRIDHAR	CHINTA	General Practice	GA	\N	t	f	f	SRIDHAR CHINTA	D.D.S	1223G0001X	Suwanee Smiles Dental	3429 LAWRENCEVILLE SUWANEE RD STE E-F SUWANEE GA 300242433	678-765-9133	in_network	f	t	2026-08-05 15:35:50.484521+00	nppes_search
1972930337	suwanee_smiles	SONYA	SHYAM	Dentist â€” General	GA	\N	t	f	f	SONYA SHYAM	DDS	122300000X	Suwanee Smiles Dental	3335 W WHEATLAND RD STE 150 DALLAS TX 752373444	469-606-4118	in_network	f	t	2026-08-05 15:35:50.529638+00	nppes_search
0000000001	suwanee_smiles	Excluded	Provider Test		GA	\N	t	f	f	Excluded Provider Test			Suwanee Smiles Dental			in_network	t	f	\N	sentinel
1234567890	tampa_smiles	MARIA	RODRIGUEZ	General Practice	FL	\N	t	f	f	DR. MARIA RODRIGUEZ DDS	DDS	1223G0001X	Tampa Bay Smiles	4321 Bay Shore Blvd Ste 200, Tampa FL 33611	813-555-0142	in_network	f	f	\N	placeholder_not_in_nppes
0987654321	dallas_dental	JAMES	WILSON	General Practice	TX	\N	t	f	f	DR. JAMES WILSON DMD	DMD	1223G0001X	Dallas Family Dental	789 Oak Lawn Ave Ste 100, Dallas TX 75219	214-555-0187	in_network	f	f	\N	placeholder_not_in_nppes
\.


--
-- Data for Name: tenants; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tenants (tenant_id, name, domain_type, practice_type, primary_payer, created_at, address, phone, active) FROM stdin;
suwanee_smiles	Suwanee Smiles Dental	dental	general_dentistry	delta_dental	2026-08-05 15:47:22.451133+00	3155 Peachtree Pkwy Ste 120, Suwanee GA 30024	470-291-4593	t
tampa_smiles	Tampa Bay Smiles	dental	general_dentistry	humana_dpo	2026-08-06 13:32:01.134721+00	4321 Bay Shore Blvd Ste 200, Tampa FL 33611	813-555-0142	t
dallas_dental	Dallas Family Dental	dental	general_dentistry	guardian_dpo	2026-08-06 13:32:01.314998+00	789 Oak Lawn Ave Ste 100, Dallas TX 75219	214-555-0187	t
\.


--
-- Name: appeals_appeal_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.appeals_appeal_id_seq', 1, false);


--
-- Name: clinical_criteria_criteria_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.clinical_criteria_criteria_id_seq', 6, true);


--
-- Name: coverage_rules_rule_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.coverage_rules_rule_id_seq', 2186, true);


--
-- Name: evidence_edges_edge_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.evidence_edges_edge_id_seq', 97, true);


--
-- Name: evidence_nodes_node_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.evidence_nodes_node_id_seq', 448, true);


--
-- Name: overlay_rules_overlay_rule_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.overlay_rules_overlay_rule_id_seq', 6, true);


--
-- Name: payer_responses_response_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.payer_responses_response_id_seq', 110, true);


--
-- Name: pred_audit_log_audit_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.pred_audit_log_audit_id_seq', 1067, true);


--
-- Name: pred_condition_instances_condition_instance_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.pred_condition_instances_condition_instance_id_seq', 851, true);


--
-- Name: procedure_lines_procedure_line_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.procedure_lines_procedure_line_id_seq', 366, true);


--
-- Name: ada_guidelines ada_guidelines_cdt_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ada_guidelines
    ADD CONSTRAINT ada_guidelines_cdt_unique UNIQUE (cdt_code);


--
-- Name: ada_guidelines ada_guidelines_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ada_guidelines
    ADD CONSTRAINT ada_guidelines_pkey PRIMARY KEY (guideline_id);


--
-- Name: appeals appeals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.appeals
    ADD CONSTRAINT appeals_pkey PRIMARY KEY (appeal_id);


--
-- Name: bundling_rules bundling_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bundling_rules
    ADD CONSTRAINT bundling_rules_pkey PRIMARY KEY (rule_id);


--
-- Name: bundling_rules bundling_rules_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bundling_rules
    ADD CONSTRAINT bundling_rules_unique UNIQUE (payer_id, primary_cdt_code, bundled_cdt_code);


--
-- Name: catalogue_versions catalogue_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.catalogue_versions
    ADD CONSTRAINT catalogue_versions_pkey PRIMARY KEY (catalogue_name);


--
-- Name: cdt_codes cdt_codes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cdt_codes
    ADD CONSTRAINT cdt_codes_pkey PRIMARY KEY (cdt_code);


--
-- Name: clinical_criteria clinical_criteria_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clinical_criteria
    ADD CONSTRAINT clinical_criteria_pkey PRIMARY KEY (criteria_id);


--
-- Name: clinical_criteria clinical_criteria_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clinical_criteria
    ADD CONSTRAINT clinical_criteria_unique UNIQUE (payer_id, cdt_code);


--
-- Name: clinical_evidence clinical_evidence_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clinical_evidence
    ADD CONSTRAINT clinical_evidence_pkey PRIMARY KEY (evidence_id);


--
-- Name: cob_rules cob_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cob_rules
    ADD CONSTRAINT cob_rules_pkey PRIMARY KEY (rule_id);


--
-- Name: cob_rules cob_rules_rule_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cob_rules
    ADD CONSTRAINT cob_rules_rule_code_key UNIQUE (rule_code);


--
-- Name: conditions_library conditions_library_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conditions_library
    ADD CONSTRAINT conditions_library_pkey PRIMARY KEY (condition_code);


--
-- Name: cost_estimates cost_estimates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cost_estimates
    ADD CONSTRAINT cost_estimates_pkey PRIMARY KEY (estimate_id);


--
-- Name: cost_estimates cost_estimates_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cost_estimates
    ADD CONSTRAINT cost_estimates_unique UNIQUE (pred_request_id, procedure_id, cdt_code);


--
-- Name: coverage_rules coverage_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coverage_rules
    ADD CONSTRAINT coverage_rules_pkey PRIMARY KEY (rule_id);


--
-- Name: coverage_rules coverage_rules_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coverage_rules
    ADD CONSTRAINT coverage_rules_unique UNIQUE (payer_id, cdt_code);


--
-- Name: downgrade_matrix downgrade_matrix_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.downgrade_matrix
    ADD CONSTRAINT downgrade_matrix_pkey PRIMARY KEY (downgrade_id);


--
-- Name: downgrade_matrix downgrade_matrix_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.downgrade_matrix
    ADD CONSTRAINT downgrade_matrix_unique UNIQUE (payer_id, plan_type, billed_cdt_code, tooth_position);


--
-- Name: eligibility_profiles eligibility_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.eligibility_profiles
    ADD CONSTRAINT eligibility_profiles_pkey PRIMARY KEY (pred_request_id);


--
-- Name: evidence_edges evidence_edges_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evidence_edges
    ADD CONSTRAINT evidence_edges_pkey PRIMARY KEY (edge_id);


--
-- Name: evidence_nodes evidence_nodes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evidence_nodes
    ADD CONSTRAINT evidence_nodes_pkey PRIMARY KEY (node_id);


--
-- Name: fee_schedules fee_schedules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fee_schedules
    ADD CONSTRAINT fee_schedules_pkey PRIMARY KEY (schedule_id);


--
-- Name: fee_schedules fee_schedules_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fee_schedules
    ADD CONSTRAINT fee_schedules_unique UNIQUE (payer_id, plan_type, cdt_code, state);


--
-- Name: frequency_limits frequency_limits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.frequency_limits
    ADD CONSTRAINT frequency_limits_pkey PRIMARY KEY (limit_id);


--
-- Name: frequency_limits frequency_limits_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.frequency_limits
    ADD CONSTRAINT frequency_limits_unique UNIQUE (payer_id, plan_type, cdt_code);


--
-- Name: medical_history_flags medical_history_flags_flag_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.medical_history_flags
    ADD CONSTRAINT medical_history_flags_flag_code_key UNIQUE (flag_code);


--
-- Name: medical_history_flags medical_history_flags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.medical_history_flags
    ADD CONSTRAINT medical_history_flags_pkey PRIMARY KEY (flag_id);


--
-- Name: overlay_rules overlay_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.overlay_rules
    ADD CONSTRAINT overlay_rules_pkey PRIMARY KEY (overlay_rule_id);


--
-- Name: overlay_rules overlay_rules_unique_scope; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.overlay_rules
    ADD CONSTRAINT overlay_rules_unique_scope UNIQUE (tenant_id, payer_id, cdt_code);


--
-- Name: patients patients_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.patients
    ADD CONSTRAINT patients_pkey PRIMARY KEY (patient_id);


--
-- Name: payer_responses payer_responses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payer_responses
    ADD CONSTRAINT payer_responses_pkey PRIMARY KEY (response_id);


--
-- Name: payers payers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payers
    ADD CONSTRAINT payers_pkey PRIMARY KEY (payer_id);


--
-- Name: plans plans_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plans
    ADD CONSTRAINT plans_pkey PRIMARY KEY (plan_id);


--
-- Name: pred_audit_log pred_audit_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pred_audit_log
    ADD CONSTRAINT pred_audit_log_pkey PRIMARY KEY (audit_id);


--
-- Name: pred_condition_instances pred_condition_instances_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pred_condition_instances
    ADD CONSTRAINT pred_condition_instances_pkey PRIMARY KEY (condition_instance_id);


--
-- Name: pred_condition_instances pred_condition_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pred_condition_instances
    ADD CONSTRAINT pred_condition_unique UNIQUE (pred_request_id, condition_code);


--
-- Name: pred_requests pred_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pred_requests
    ADD CONSTRAINT pred_requests_pkey PRIMARY KEY (pred_request_id);


--
-- Name: pred_states pred_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pred_states
    ADD CONSTRAINT pred_states_pkey PRIMARY KEY (pred_request_id);


--
-- Name: procedure_lines procedure_lines_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.procedure_lines
    ADD CONSTRAINT procedure_lines_pkey PRIMARY KEY (procedure_line_id);


--
-- Name: providers providers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.providers
    ADD CONSTRAINT providers_pkey PRIMARY KEY (provider_npi);


--
-- Name: tenants tenants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenants
    ADD CONSTRAINT tenants_pkey PRIMARY KEY (tenant_id);


--
-- Name: ada_guidelines_cdt_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ada_guidelines_cdt_idx ON public.ada_guidelines USING btree (cdt_code);


--
-- Name: appeals_pred_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX appeals_pred_idx ON public.appeals USING btree (pred_request_id);


--
-- Name: bundling_rules_primary_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX bundling_rules_primary_idx ON public.bundling_rules USING btree (primary_cdt_code);


--
-- Name: cdt_codes_category_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX cdt_codes_category_idx ON public.cdt_codes USING btree (category);


--
-- Name: clinical_evidence_doc_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX clinical_evidence_doc_unique ON public.clinical_evidence USING btree (pred_request_id, document_type, tooth_number) NULLS NOT DISTINCT;


--
-- Name: clinical_evidence_pred_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX clinical_evidence_pred_idx ON public.clinical_evidence USING btree (pred_request_id);


--
-- Name: clinical_evidence_s3_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX clinical_evidence_s3_idx ON public.clinical_evidence USING btree (s3_key);


--
-- Name: clinical_evidence_tenant_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX clinical_evidence_tenant_idx ON public.clinical_evidence USING btree (tenant_id);


--
-- Name: clinical_evidence_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX clinical_evidence_type_idx ON public.clinical_evidence USING btree (tenant_id, document_type);


--
-- Name: cost_estimates_pred_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX cost_estimates_pred_idx ON public.cost_estimates USING btree (pred_request_id);


--
-- Name: coverage_rules_lookup_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX coverage_rules_lookup_idx ON public.coverage_rules USING btree (payer_id, cdt_code);


--
-- Name: downgrade_matrix_lookup_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX downgrade_matrix_lookup_idx ON public.downgrade_matrix USING btree (payer_id, billed_cdt_code);


--
-- Name: eligibility_profiles_member_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX eligibility_profiles_member_idx ON public.eligibility_profiles USING btree (tenant_id, member_id);


--
-- Name: eligibility_profiles_tenant_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX eligibility_profiles_tenant_idx ON public.eligibility_profiles USING btree (tenant_id);


--
-- Name: evidence_edges_pred_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX evidence_edges_pred_idx ON public.evidence_edges USING btree (pred_request_id);


--
-- Name: evidence_edges_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX evidence_edges_unique ON public.evidence_edges USING btree (pred_request_id, from_node, to_node, field) NULLS NOT DISTINCT;


--
-- Name: evidence_nodes_pred_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX evidence_nodes_pred_idx ON public.evidence_nodes USING btree (pred_request_id);


--
-- Name: evidence_nodes_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX evidence_nodes_unique ON public.evidence_nodes USING btree (pred_request_id, entity_id) NULLS NOT DISTINCT;


--
-- Name: fee_schedules_lookup_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fee_schedules_lookup_idx ON public.fee_schedules USING btree (payer_id, cdt_code, state);


--
-- Name: frequency_limits_lookup_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX frequency_limits_lookup_idx ON public.frequency_limits USING btree (payer_id, cdt_code);


--
-- Name: overlay_rules_lookup_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX overlay_rules_lookup_idx ON public.overlay_rules USING btree (tenant_id, payer_id, cdt_code) WHERE active;


--
-- Name: patients_member_tenant_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX patients_member_tenant_unique ON public.patients USING btree (member_id, tenant_id);


--
-- Name: payer_responses_pred_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX payer_responses_pred_idx ON public.payer_responses USING btree (pred_request_id);


--
-- Name: payer_responses_pred_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX payer_responses_pred_unique ON public.payer_responses USING btree (pred_request_id);


--
-- Name: pred_audit_log_event_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX pred_audit_log_event_unique ON public.pred_audit_log USING btree (pred_request_id, event_type);


--
-- Name: pred_audit_log_pred_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX pred_audit_log_pred_idx ON public.pred_audit_log USING btree (pred_request_id, occurred_at);


--
-- Name: pred_conditions_pred_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX pred_conditions_pred_idx ON public.pred_condition_instances USING btree (pred_request_id, status);


--
-- Name: pred_requests_tenant_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX pred_requests_tenant_idx ON public.pred_requests USING btree (tenant_id, status);


--
-- Name: pred_states_decision_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX pred_states_decision_idx ON public.pred_states USING btree (tenant_id, decision);


--
-- Name: pred_states_decision_trace_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX pred_states_decision_trace_gin ON public.pred_states USING gin (decision_trace jsonb_path_ops);


--
-- Name: pred_states_readiness_flags_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX pred_states_readiness_flags_gin ON public.pred_states USING gin (readiness_flags jsonb_path_ops);


--
-- Name: pred_states_submission_ready_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX pred_states_submission_ready_idx ON public.pred_states USING btree (tenant_id, submission_ready);


--
-- Name: pred_states_tenant_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX pred_states_tenant_idx ON public.pred_states USING btree (tenant_id);


--
-- Name: procedure_lines_pred_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX procedure_lines_pred_idx ON public.procedure_lines USING btree (pred_request_id);


--
-- Name: ada_guidelines ada_guidelines_cdt_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ada_guidelines
    ADD CONSTRAINT ada_guidelines_cdt_code_fkey FOREIGN KEY (cdt_code) REFERENCES public.cdt_codes(cdt_code);


--
-- Name: bundling_rules bundling_rules_payer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bundling_rules
    ADD CONSTRAINT bundling_rules_payer_id_fkey FOREIGN KEY (payer_id) REFERENCES public.payers(payer_id);


--
-- Name: downgrade_matrix downgrade_matrix_payer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.downgrade_matrix
    ADD CONSTRAINT downgrade_matrix_payer_id_fkey FOREIGN KEY (payer_id) REFERENCES public.payers(payer_id);


--
-- Name: fee_schedules fee_schedules_payer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fee_schedules
    ADD CONSTRAINT fee_schedules_payer_id_fkey FOREIGN KEY (payer_id) REFERENCES public.payers(payer_id);


--
-- Name: frequency_limits frequency_limits_payer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.frequency_limits
    ADD CONSTRAINT frequency_limits_payer_id_fkey FOREIGN KEY (payer_id) REFERENCES public.payers(payer_id);


--
-- Name: patients patients_plan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.patients
    ADD CONSTRAINT patients_plan_id_fkey FOREIGN KEY (plan_id) REFERENCES public.plans(plan_id);


--
-- Name: plans plans_payer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plans
    ADD CONSTRAINT plans_payer_id_fkey FOREIGN KEY (payer_id) REFERENCES public.payers(payer_id);


--
-- Name: pred_requests pred_requests_plan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pred_requests
    ADD CONSTRAINT pred_requests_plan_id_fkey FOREIGN KEY (plan_id) REFERENCES public.plans(plan_id);


--
-- Name: appeals; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.appeals ENABLE ROW LEVEL SECURITY;

--
-- Name: appeals appeals_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY appeals_tenant_isolation ON public.appeals USING ((tenant_id = current_setting('app.tenant_id'::text, true)));


--
-- Name: clinical_evidence; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.clinical_evidence ENABLE ROW LEVEL SECURITY;

--
-- Name: clinical_evidence clinical_evidence_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY clinical_evidence_tenant_isolation ON public.clinical_evidence USING ((tenant_id = current_setting('app.tenant_id'::text, true)));


--
-- Name: cost_estimates; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.cost_estimates ENABLE ROW LEVEL SECURITY;

--
-- Name: cost_estimates cost_estimates_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY cost_estimates_tenant_isolation ON public.cost_estimates USING (((tenant_id)::text = current_setting('app.tenant_id'::text, true)));


--
-- Name: eligibility_profiles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.eligibility_profiles ENABLE ROW LEVEL SECURITY;

--
-- Name: eligibility_profiles eligibility_profiles_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY eligibility_profiles_tenant_isolation ON public.eligibility_profiles USING ((tenant_id = current_setting('app.tenant_id'::text, true)));


--
-- Name: evidence_edges; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.evidence_edges ENABLE ROW LEVEL SECURITY;

--
-- Name: evidence_edges evidence_edges_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY evidence_edges_tenant_isolation ON public.evidence_edges USING ((tenant_id = current_setting('app.tenant_id'::text, true)));


--
-- Name: evidence_nodes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.evidence_nodes ENABLE ROW LEVEL SECURITY;

--
-- Name: evidence_nodes evidence_nodes_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY evidence_nodes_tenant_isolation ON public.evidence_nodes USING ((tenant_id = current_setting('app.tenant_id'::text, true)));


--
-- Name: overlay_rules; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.overlay_rules ENABLE ROW LEVEL SECURITY;

--
-- Name: overlay_rules overlay_rules_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY overlay_rules_tenant_isolation ON public.overlay_rules USING (((tenant_id)::text = current_setting('app.tenant_id'::text, true)));


--
-- Name: patients; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.patients ENABLE ROW LEVEL SECURITY;

--
-- Name: patients patients_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY patients_tenant_isolation ON public.patients USING ((tenant_id = current_setting('app.tenant_id'::text, true)));


--
-- Name: payer_responses; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.payer_responses ENABLE ROW LEVEL SECURITY;

--
-- Name: payer_responses payer_responses_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY payer_responses_tenant_isolation ON public.payer_responses USING ((tenant_id = current_setting('app.tenant_id'::text, true)));


--
-- Name: pred_audit_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.pred_audit_log ENABLE ROW LEVEL SECURITY;

--
-- Name: pred_audit_log pred_audit_log_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY pred_audit_log_tenant_isolation ON public.pred_audit_log USING ((tenant_id = current_setting('app.tenant_id'::text, true)));


--
-- Name: pred_condition_instances; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.pred_condition_instances ENABLE ROW LEVEL SECURITY;

--
-- Name: pred_condition_instances pred_condition_instances_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY pred_condition_instances_tenant_isolation ON public.pred_condition_instances USING ((tenant_id = current_setting('app.tenant_id'::text, true)));


--
-- Name: pred_requests; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.pred_requests ENABLE ROW LEVEL SECURITY;

--
-- Name: pred_requests pred_requests_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY pred_requests_tenant_isolation ON public.pred_requests USING ((tenant_id = current_setting('app.tenant_id'::text, true)));


--
-- Name: pred_states; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.pred_states ENABLE ROW LEVEL SECURITY;

--
-- Name: pred_states pred_states_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY pred_states_tenant_isolation ON public.pred_states USING ((tenant_id = current_setting('app.tenant_id'::text, true)));


--
-- Name: procedure_lines; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.procedure_lines ENABLE ROW LEVEL SECURITY;

--
-- Name: procedure_lines procedure_lines_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY procedure_lines_tenant_isolation ON public.procedure_lines USING ((tenant_id = current_setting('app.tenant_id'::text, true)));


--
-- Name: providers; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.providers ENABLE ROW LEVEL SECURITY;

--
-- Name: providers providers_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY providers_tenant_isolation ON public.providers USING ((tenant_id = current_setting('app.tenant_id'::text, true)));


--
-- PostgreSQL database dump complete
--

\unrestrict ruuJxZ53aiTbRkttzfHcbDv407NQvIcRoTj5NqwaaHBE8X4Y8DCpFP3rtb6Ju6g

