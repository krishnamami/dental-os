--
-- PostgreSQL database dump
--


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

--
-- Name: authenticate_user(text); Type: FUNCTION; Schema: public; Owner: dental_auth
--

CREATE FUNCTION public.authenticate_user(p_email text) RETURNS TABLE(user_id text, email text, name text, role text, tenant_id text, password_hash text, active boolean)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public'
    AS $$
  SELECT u.user_id, u.email, u.name, u.role, u.tenant_id,
         u.password_hash, u.active
  FROM public.users u
  WHERE u.email = lower(btrim(p_email))
    AND u.active = true
$$;


ALTER FUNCTION public.authenticate_user(p_email text) OWNER TO dental_auth;

--
-- Name: get_user_by_id(text); Type: FUNCTION; Schema: public; Owner: dental_auth
--

CREATE FUNCTION public.get_user_by_id(p_user_id text) RETURNS TABLE(user_id text, email text, name text, role text, tenant_id text)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public'
    AS $$
  SELECT u.user_id, u.email, u.name, u.role, u.tenant_id
  FROM public.users u
  WHERE u.user_id = p_user_id
    AND u.active = true
$$;


ALTER FUNCTION public.get_user_by_id(p_user_id text) OWNER TO dental_auth;

--
-- Name: list_active_users(); Type: FUNCTION; Schema: public; Owner: dental_auth
--

CREATE FUNCTION public.list_active_users() RETURNS TABLE(user_id text, email text, name text, role text, tenant_id text)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public'
    AS $$
  SELECT u.user_id, u.email, u.name, u.role, u.tenant_id
  FROM public.users u
  WHERE u.active = true
  ORDER BY u.tenant_id NULLS LAST, u.role, u.name
$$;


ALTER FUNCTION public.list_active_users() OWNER TO dental_auth;

--
-- Name: tenants_owned_by(text); Type: FUNCTION; Schema: public; Owner: dental_auth
--

CREATE FUNCTION public.tenants_owned_by(p_user_id text) RETURNS TABLE(tenant_id text)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public'
    AS $$
    SELECT o.tenant_id
    FROM tenant_ownership o
    JOIN users u ON u.user_id = o.user_id
    -- A deactivated account owns nothing. Deactivating is how a person
    -- is removed, and it must not leave their practices readable.
    WHERE o.user_id = p_user_id
      AND u.active
    ORDER BY o.tenant_id
$$;


ALTER FUNCTION public.tenants_owned_by(p_user_id text) OWNER TO dental_auth;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: appeal_events; Type: TABLE; Schema: public; Owner: dental_admin
--

CREATE TABLE public.appeal_events (
    appeal_id text DEFAULT (gen_random_uuid())::text NOT NULL,
    tenant_id text NOT NULL,
    pred_request_id text NOT NULL,
    denial_id text,
    patient_name text NOT NULL,
    payer_id text NOT NULL,
    filed_by text NOT NULL,
    filed_at timestamp with time zone DEFAULT now(),
    appeal_type text DEFAULT 'standard'::text,
    status text DEFAULT 'filed'::text,
    resolved_at timestamp with time zone,
    recovered_amount numeric(10,2),
    notes text,
    predicted_viable boolean,
    predicted_probability numeric(4,3),
    CONSTRAINT appeal_predicted_probability_chk CHECK (((predicted_probability IS NULL) OR ((predicted_probability >= (0)::numeric) AND (predicted_probability <= (1)::numeric))))
);

ALTER TABLE ONLY public.appeal_events FORCE ROW LEVEL SECURITY;


ALTER TABLE public.appeal_events OWNER TO dental_admin;

--
-- Name: COLUMN appeal_events.predicted_viable; Type: COMMENT; Schema: public; Owner: dental_admin
--

COMMENT ON COLUMN public.appeal_events.predicted_viable IS 'The engine''s verdict at the moment of filing. NULL = not recorded.';


--
-- Name: COLUMN appeal_events.predicted_probability; Type: COMMENT; Schema: public; Owner: dental_admin
--

COMMENT ON COLUMN public.appeal_events.predicted_probability IS 'resolve_appeal_viability success_probability, 0-1, at filing time.';


--
-- Name: appeal_packets; Type: TABLE; Schema: public; Owner: dental_admin
--

CREATE TABLE public.appeal_packets (
    packet_id uuid DEFAULT gen_random_uuid() NOT NULL,
    pred_request_id character varying(50) NOT NULL,
    tenant_id character varying(50) NOT NULL,
    payer_id character varying(50) NOT NULL,
    denial_reason_code character varying(20),
    viability_score numeric(4,3),
    success_probability numeric(4,3),
    appeal_letter_text text,
    evidence_list jsonb DEFAULT '[]'::jsonb,
    citations jsonb DEFAULT '[]'::jsonb,
    appeal_deadline date,
    days_remaining integer,
    approved_by character varying(50),
    generated_at timestamp with time zone DEFAULT now() NOT NULL,
    submitted_at timestamp with time zone,
    outcome character varying(20),
    CONSTRAINT appeal_packets_outcome_chk CHECK (((outcome IS NULL) OR ((outcome)::text = ANY ((ARRAY['approved'::character varying, 'denied'::character varying, 'pending'::character varying])::text[])))),
    CONSTRAINT appeal_packets_submitted_needs_approver_chk CHECK (((submitted_at IS NULL) OR (approved_by IS NOT NULL))),
    CONSTRAINT appeal_packets_viability_chk CHECK (((viability_score IS NULL) OR ((viability_score >= (0)::numeric) AND (viability_score <= (1)::numeric))))
);

ALTER TABLE ONLY public.appeal_packets FORCE ROW LEVEL SECURITY;


ALTER TABLE public.appeal_packets OWNER TO dental_admin;

--
-- Name: appointments; Type: TABLE; Schema: public; Owner: dental_admin
--

CREATE TABLE public.appointments (
    appointment_id text DEFAULT (gen_random_uuid())::text NOT NULL,
    tenant_id text NOT NULL,
    pred_request_id text NOT NULL,
    patient_name text NOT NULL,
    appointment_date date NOT NULL,
    appointment_time time without time zone NOT NULL,
    procedure_summary text,
    provider_npi text,
    status text DEFAULT 'scheduled'::text,
    pms_source text DEFAULT 'manual'::text,
    pms_appointment_id text,
    created_at timestamp with time zone DEFAULT now()
);

ALTER TABLE ONLY public.appointments FORCE ROW LEVEL SECURITY;


ALTER TABLE public.appointments OWNER TO dental_admin;

--
-- Name: checkin_events; Type: TABLE; Schema: public; Owner: dental_admin
--

CREATE TABLE public.checkin_events (
    event_id text DEFAULT (gen_random_uuid())::text NOT NULL,
    pred_request_id text NOT NULL,
    tenant_id text NOT NULL,
    patient_name text NOT NULL,
    checked_in_by text NOT NULL,
    checked_in_at timestamp with time zone DEFAULT now(),
    checkin_day date DEFAULT CURRENT_DATE NOT NULL,
    notes text
);

ALTER TABLE ONLY public.checkin_events FORCE ROW LEVEL SECURITY;


ALTER TABLE public.checkin_events OWNER TO dental_admin;

--
-- Name: clinical_attestations; Type: TABLE; Schema: public; Owner: dental_admin
--

CREATE TABLE public.clinical_attestations (
    attestation_id text DEFAULT (gen_random_uuid())::text NOT NULL,
    tenant_id text NOT NULL,
    pred_request_id text NOT NULL,
    attested_by text NOT NULL,
    attested_at timestamp with time zone DEFAULT now(),
    narrative_text text,
    statement text NOT NULL,
    submission_id text
);

ALTER TABLE ONLY public.clinical_attestations FORCE ROW LEVEL SECURITY;


ALTER TABLE public.clinical_attestations OWNER TO dental_admin;

--
-- Name: clinical_handoffs; Type: TABLE; Schema: public; Owner: dental_admin
--

CREATE TABLE public.clinical_handoffs (
    handoff_id text DEFAULT (gen_random_uuid())::text NOT NULL,
    tenant_id text NOT NULL,
    pred_request_id text NOT NULL,
    to_role text DEFAULT 'dentist'::text NOT NULL,
    from_user text NOT NULL,
    message text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    read_at timestamp with time zone,
    read_by text,
    kind text DEFAULT 'note'::text NOT NULL
);

ALTER TABLE ONLY public.clinical_handoffs FORCE ROW LEVEL SECURITY;


ALTER TABLE public.clinical_handoffs OWNER TO dental_admin;

--
-- Name: clinical_justifications; Type: TABLE; Schema: public; Owner: dental_admin
--

CREATE TABLE public.clinical_justifications (
    justification_id text DEFAULT (gen_random_uuid())::text NOT NULL,
    tenant_id text NOT NULL,
    pred_request_id text NOT NULL,
    signal_code text NOT NULL,
    justification text NOT NULL,
    justified_by text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

ALTER TABLE ONLY public.clinical_justifications FORCE ROW LEVEL SECURITY;


ALTER TABLE public.clinical_justifications OWNER TO dental_admin;

--
-- Name: clinical_narratives; Type: TABLE; Schema: public; Owner: dental_admin
--

CREATE TABLE public.clinical_narratives (
    narrative_id text DEFAULT (gen_random_uuid())::text NOT NULL,
    tenant_id text NOT NULL,
    pred_request_id text NOT NULL,
    narrative_text text NOT NULL,
    source text DEFAULT 'edited'::text NOT NULL,
    written_by text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

ALTER TABLE ONLY public.clinical_narratives FORCE ROW LEVEL SECURITY;


ALTER TABLE public.clinical_narratives OWNER TO dental_admin;

--
-- Name: decision_outputs; Type: TABLE; Schema: public; Owner: dental_admin
--

CREATE TABLE public.decision_outputs (
    output_id uuid DEFAULT gen_random_uuid() NOT NULL,
    pred_request_id character varying(50) NOT NULL,
    tenant_id character varying(50) NOT NULL,
    decision_id character varying(50) NOT NULL,
    wave integer NOT NULL,
    mode character varying(20) NOT NULL,
    outcome character varying(20),
    signals jsonb DEFAULT '[]'::jsonb NOT NULL,
    findings jsonb DEFAULT '{}'::jsonb NOT NULL,
    confidence_label character varying(50),
    boundary_rule text,
    processing_ms integer,
    bundle_id uuid,
    human_action character varying(20),
    human_reviewer character varying(50),
    human_override_reason text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT decision_outputs_human_action_chk CHECK (((human_action IS NULL) OR ((human_action)::text = ANY ((ARRAY['approved'::character varying, 'overridden'::character varying, 'escalated'::character varying])::text[])))),
    CONSTRAINT decision_outputs_mode_chk CHECK (((mode)::text = ANY ((ARRAY['recommend'::character varying, 'human_approval'::character varying])::text[]))),
    CONSTRAINT decision_outputs_outcome_chk CHECK (((outcome IS NULL) OR ((outcome)::text = ANY ((ARRAY['recommend'::character varying, 'escalate'::character varying, 'block'::character varying])::text[])))),
    CONSTRAINT decision_outputs_wave_chk CHECK (((wave >= 1) AND (wave <= 5)))
);

ALTER TABLE ONLY public.decision_outputs FORCE ROW LEVEL SECURITY;


ALTER TABLE public.decision_outputs OWNER TO dental_admin;

--
-- Name: CONSTRAINT decision_outputs_mode_chk ON decision_outputs; Type: COMMENT; Schema: public; Owner: dental_admin
--

COMMENT ON CONSTRAINT decision_outputs_mode_chk ON public.decision_outputs IS 'No auto_execute. decisions.yaml has no automate_if clause and no auto_execute mode; recommend is the ceiling. AI decides nothing.';


--
-- Name: denial_events; Type: TABLE; Schema: public; Owner: dental_admin
--

CREATE TABLE public.denial_events (
    denial_id text DEFAULT (gen_random_uuid())::text NOT NULL,
    tenant_id text NOT NULL,
    pred_request_id text NOT NULL,
    patient_name text NOT NULL,
    payer_id text NOT NULL,
    denied_at timestamp with time zone DEFAULT now(),
    denial_reason text,
    denial_reason_code text,
    denied_amount numeric(10,2),
    appeal_deadline timestamp with time zone,
    appeal_viable boolean DEFAULT false,
    appeal_probability integer,
    notes text,
    submission_id text
);

ALTER TABLE ONLY public.denial_events FORCE ROW LEVEL SECURITY;


ALTER TABLE public.denial_events OWNER TO dental_admin;

--
-- Name: document_requests; Type: TABLE; Schema: public; Owner: dental_admin
--

CREATE TABLE public.document_requests (
    request_id text DEFAULT (gen_random_uuid())::text NOT NULL,
    tenant_id text NOT NULL,
    pred_request_id text NOT NULL,
    document_type text NOT NULL,
    signal_code text,
    requested_from text DEFAULT 'front_desk'::text NOT NULL,
    requested_by text NOT NULL,
    note text,
    status text DEFAULT 'open'::text NOT NULL,
    requested_at timestamp with time zone DEFAULT now(),
    resolved_at timestamp with time zone
);

ALTER TABLE ONLY public.document_requests FORCE ROW LEVEL SECURITY;


ALTER TABLE public.document_requests OWNER TO dental_admin;

--
-- Name: persona_bundles; Type: TABLE; Schema: public; Owner: dental_admin
--

CREATE TABLE public.persona_bundles (
    bundle_id uuid DEFAULT gen_random_uuid() NOT NULL,
    pred_request_id character varying(50) NOT NULL,
    tenant_id character varying(50) NOT NULL,
    bundle_snapshot jsonb NOT NULL,
    rules_snapshot jsonb DEFAULT '{}'::jsonb NOT NULL,
    wave_outputs jsonb DEFAULT '{}'::jsonb NOT NULL,
    all_signals jsonb DEFAULT '[]'::jsonb NOT NULL,
    is_current boolean DEFAULT true NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    dental_os_version character varying(20) DEFAULT '0.1.0'::character varying NOT NULL,
    completed_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY public.persona_bundles FORCE ROW LEVEL SECURITY;


ALTER TABLE public.persona_bundles OWNER TO dental_admin;

--
-- Name: COLUMN persona_bundles.rules_snapshot; Type: COMMENT; Schema: public; Owner: dental_admin
--

COMMENT ON COLUMN public.persona_bundles.rules_snapshot IS 'The catalogue rules as resolved at decision time. Without this a replay would re-resolve against today''s catalogue and could reach a different answer than the one a human signed off on.';


--
-- Name: provider_feedback; Type: TABLE; Schema: public; Owner: dental_admin
--

CREATE TABLE public.provider_feedback (
    feedback_id uuid DEFAULT gen_random_uuid() NOT NULL,
    pred_request_id character varying(50) NOT NULL,
    tenant_id character varying(50) NOT NULL,
    decision_id character varying(50) NOT NULL,
    signal_code character varying(50) NOT NULL,
    feedback_type character varying(20) NOT NULL,
    notes text,
    submitted_by character varying(50),
    submitted_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone DEFAULT (now() + '365 days'::interval) NOT NULL,
    CONSTRAINT provider_feedback_role_chk CHECK (((submitted_by IS NULL) OR ((submitted_by)::text = ANY ((ARRAY['front_desk'::character varying, 'billing'::character varying, 'dentist'::character varying, 'dso_manager'::character varying])::text[])))),
    CONSTRAINT provider_feedback_type_chk CHECK (((feedback_type)::text = ANY ((ARRAY['accepted'::character varying, 'overridden'::character varying, 'false_positive'::character varying])::text[])))
);

ALTER TABLE ONLY public.provider_feedback FORCE ROW LEVEL SECURITY;


ALTER TABLE public.provider_feedback OWNER TO dental_admin;

--
-- Name: CONSTRAINT provider_feedback_role_chk ON provider_feedback; Type: COMMENT; Schema: public; Owner: dental_admin
--

COMMENT ON CONSTRAINT provider_feedback_role_chk ON public.provider_feedback IS 'The four owner_team values in decisions.yaml. A role, never a named individual â€” this table is about which desk overrode the recommendation, not who.';


--
-- Name: submission_events; Type: TABLE; Schema: public; Owner: dental_admin
--

CREATE TABLE public.submission_events (
    submission_id text DEFAULT (gen_random_uuid())::text NOT NULL,
    tenant_id text NOT NULL,
    pred_request_id text NOT NULL,
    patient_name text NOT NULL,
    payer_id text NOT NULL,
    payer_name text NOT NULL,
    submitted_by text NOT NULL,
    submitted_at timestamp with time zone DEFAULT now(),
    submission_method text DEFAULT 'manual'::text,
    submission_ref text,
    expected_response_days integer DEFAULT 15,
    status text DEFAULT 'submitted'::text,
    notes text
);

ALTER TABLE ONLY public.submission_events FORCE ROW LEVEL SECURITY;


ALTER TABLE public.submission_events OWNER TO dental_admin;

--
-- Name: tenant_ownership; Type: TABLE; Schema: public; Owner: dental_admin
--

CREATE TABLE public.tenant_ownership (
    ownership_id text DEFAULT (gen_random_uuid())::text NOT NULL,
    user_id text NOT NULL,
    tenant_id text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY public.tenant_ownership FORCE ROW LEVEL SECURITY;


ALTER TABLE public.tenant_ownership OWNER TO dental_admin;

--
-- Name: users; Type: TABLE; Schema: public; Owner: dental_admin
--

CREATE TABLE public.users (
    user_id text DEFAULT (gen_random_uuid())::text NOT NULL,
    email text NOT NULL,
    password_hash text NOT NULL,
    name text NOT NULL,
    role text NOT NULL,
    tenant_id text,
    active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT users_role_check CHECK ((role = ANY (ARRAY['front_desk'::text, 'tx_coord'::text, 'revenue_ops'::text, 'dentist'::text, 'dso_owner'::text, 'accord_admin'::text])))
);

ALTER TABLE ONLY public.users FORCE ROW LEVEL SECURITY;


ALTER TABLE public.users OWNER TO dental_admin;

--
-- Data for Name: appeal_events; Type: TABLE DATA; Schema: public; Owner: dental_admin
--

COPY public.appeal_events (appeal_id, tenant_id, pred_request_id, denial_id, patient_name, payer_id, filed_by, filed_at, appeal_type, status, resolved_at, recovered_amount, notes, predicted_viable, predicted_probability) FROM stdin;
7d3f7001-fe9e-4f5b-8baa-1b01610060e4	suwanee_smiles	PRED-SIM-DA-B01	2be5d675-34e8-467e-8039-5456595d8bb1	Patricia Johnson	delta_dental	3069f79f-8ea4-41b0-a35f-74a640e68238	2026-05-29 14:30:00+00	standard	overturned	2026-06-26 14:30:00+00	1800.00	Denied against the frequency limit. The prior restoration was placed by another practice and the limit runs from the seat date, not the prep date.	f	0.000
5100bfc5-ba4c-44cc-ba22-b15b3965572a	suwanee_smiles	PRED-SIM-DA-B05	fa28ed91-2f36-4d23-847c-1301dfed3d99	Ashley Thompson	delta_dental	3069f79f-8ea4-41b0-a35f-74a640e68238	2026-06-02 14:30:00+00	standard	upheld	2026-07-03 14:30:00+00	0.00	Denied inside the 12-month major-services waiting period. Appealed on continuous-coverage grounds; the prior carrier's certificate did not cover the gap.	f	0.000
64258830-30d2-4867-a4cb-481e91bb9f45	suwanee_smiles	PRED-SIM-DA-B04	7af1d503-589b-41fb-9ecc-d99f52a64404	Carlos Rivera	delta_dental	3069f79f-8ea4-41b0-a35f-74a640e68238	2026-08-10 00:31:35.901362+00	standard	filed	\N	\N	Filed from revenue ops against bundling.	t	0.650
\.


--
-- Data for Name: appeal_packets; Type: TABLE DATA; Schema: public; Owner: dental_admin
--

COPY public.appeal_packets (packet_id, pred_request_id, tenant_id, payer_id, denial_reason_code, viability_score, success_probability, appeal_letter_text, evidence_list, citations, appeal_deadline, days_remaining, approved_by, generated_at, submitted_at, outcome) FROM stdin;
\.


--
-- Data for Name: appointments; Type: TABLE DATA; Schema: public; Owner: dental_admin
--

COPY public.appointments (appointment_id, tenant_id, pred_request_id, patient_name, appointment_date, appointment_time, procedure_summary, provider_npi, status, pms_source, pms_appointment_id, created_at) FROM stdin;
d71dbc0a-50ee-4e2b-84e0-5a0e1e4a471b	suwanee_smiles	PRED-SIM-DA-A01	James Mitchell	2026-08-07	09:00:00	Implant + crown	1134534266	scheduled	manual	\N	2026-08-07 19:59:35.557112+00
b78115d5-0573-4360-9431-9b9d4c6ac3e7	suwanee_smiles	PRED-SIM-DA-D04	Linda Taylor	2026-08-07	09:30:00	Crown	1134534266	scheduled	manual	\N	2026-08-07 19:59:35.63134+00
d4afa2a7-81d2-42fa-b3b1-9e457a50c7d9	suwanee_smiles	PRED-SIM-DA-U01	Robert Thompson	2026-08-07	10:00:00	Cleaning	1134534266	scheduled	manual	\N	2026-08-07 19:59:35.681694+00
a4c1a0a4-768c-4f98-b127-69033168eef3	suwanee_smiles	PRED-SIM-DA-U02	Maria Santos	2026-08-07	10:30:00	Bitewings	1134534266	scheduled	manual	\N	2026-08-07 19:59:35.732115+00
4283cc6c-62b9-4c3c-9b8e-cff560f5d60c	suwanee_smiles	PRED-SIM-DA-B04	Carlos Rivera	2026-08-07	11:00:00	Implant + graft	1134534266	scheduled	manual	\N	2026-08-07 19:59:35.784588+00
e4318c0a-b181-465b-8706-50fa2e031ba0	tampa_smiles	PRED-SIM-TB-A01	Sarah Chen	2026-08-07	09:00:00	Crown	1234567890	scheduled	manual	\N	2026-08-07 19:59:35.836114+00
d30c6cb5-8c4a-4c00-8ce6-2ca7022b1080	tampa_smiles	PRED-SIM-TB-B01	Robert Martinez	2026-08-07	10:00:00	Implant	1234567890	scheduled	manual	\N	2026-08-07 19:59:35.883109+00
050418d4-9440-4f9d-97e2-9e17f5ddf314	tampa_smiles	PRED-SIM-TB-U01	Jennifer Adams	2026-08-07	14:15:00	Cleaning	1234567890	scheduled	dentrix	DTX-99012	2026-08-07 20:37:19.50265+00
8b938863-02aa-4329-8127-2eea064c7efb	tampa_smiles	PRED-SIM-TB-C01	Lisa Thompson	2026-08-07	15:45:00	Scaling	1234567890	scheduled	opendental	OD-7781	2026-08-07 20:47:02.635018+00
21fe22d1-a48f-48b2-95d4-3f4610735213	suwanee_smiles	PRED-SIM-DA-A01	James Mitchell	2026-08-08	09:00:00	Implant + crown	1134534266	scheduled	manual	\N	2026-08-08 00:07:08.90193+00
ea01c7c5-c20a-4408-bc98-5b0d6db1dcb5	suwanee_smiles	PRED-SIM-DA-D04	Linda Taylor	2026-08-08	09:30:00	Crown	1134534266	scheduled	manual	\N	2026-08-08 00:07:08.975935+00
5e07fabb-5315-445e-8106-ad880e51c479	suwanee_smiles	PRED-SIM-DA-U01	Robert Thompson	2026-08-08	10:00:00	Cleaning	1134534266	scheduled	manual	\N	2026-08-08 00:07:09.023415+00
9251e00e-5748-4ba5-99eb-61b8d2488134	suwanee_smiles	PRED-SIM-DA-U02	Maria Santos	2026-08-08	10:30:00	Bitewings	1134534266	scheduled	manual	\N	2026-08-08 00:07:09.074957+00
7f2587c2-ecbb-4814-a11c-02b1097c3c7f	suwanee_smiles	PRED-SIM-DA-B04	Carlos Rivera	2026-08-08	11:00:00	Implant + graft	1134534266	scheduled	manual	\N	2026-08-08 00:07:09.123414+00
a37b3d52-d748-4574-b5df-010d9a1f344a	suwanee_smiles	PRED-SIM-DA-B04	Carlos Rivera	2026-08-06	11:00:00	Implant + graft	1134534266	scheduled	manual	\N	2026-08-08 00:07:09.325161+00
46087246-66ab-41d6-854f-06c0b280ccea	suwanee_smiles	PRED-SIM-DA-U02	Maria Santos	2026-08-06	10:30:00	Bitewings	1134534266	scheduled	manual	\N	2026-08-08 00:07:09.375403+00
bf5ec284-f342-494f-af90-4dc22efed1f8	tampa_smiles	PRED-SIM-TB-A01	Sarah Chen	2026-08-08	09:00:00	Crown	1234567890	scheduled	manual	\N	2026-08-08 00:07:09.425655+00
3fc44f2a-7890-494e-a02c-70271cc3b1e6	tampa_smiles	PRED-SIM-TB-B01	Robert Martinez	2026-08-08	10:00:00	Implant	1234567890	scheduled	manual	\N	2026-08-08 00:07:09.477916+00
90482963-de62-4639-93c3-ab01f4d8b7e5	suwanee_smiles	PRED-SIM-DA-D04	Linda Taylor	2026-08-09	09:30:00	Crown	1134534266	scheduled	demo	\N	2026-08-08 00:47:47.713364+00
8ef8fe13-789e-47f6-bcfd-e37706b25b0d	suwanee_smiles	PRED-SIM-DA-U01	Robert Thompson	2026-08-09	10:00:00	Cleaning	1134534266	scheduled	demo	\N	2026-08-08 00:47:47.833919+00
82aa2158-fb14-4437-94ce-06a8b9ce5583	suwanee_smiles	PRED-SIM-DA-U02	Maria Santos	2026-08-09	10:30:00	Bitewings	1134534266	scheduled	demo	\N	2026-08-08 00:47:47.936759+00
cd265031-f7df-4bab-a94e-c6f175eecfa2	suwanee_smiles	PRED-SIM-DA-B04	Carlos Rivera	2026-08-09	11:00:00	Implant + graft	1134534266	scheduled	demo	\N	2026-08-08 00:47:48.040449+00
855b6eb4-6613-4805-8015-f120584eb663	suwanee_smiles	PRED-SIM-DA-A01	James Mitchell	2026-08-10	09:00:00	Implant + crown	1134534266	scheduled	demo	\N	2026-08-08 00:47:48.165365+00
b1114dfd-e8e5-44b2-816e-159246fbbd78	suwanee_smiles	PRED-SIM-DA-D04	Linda Taylor	2026-08-10	09:30:00	Crown	1134534266	scheduled	demo	\N	2026-08-08 00:47:48.270078+00
e68e69c1-38de-47fe-b0b3-7b176b568e40	suwanee_smiles	PRED-SIM-DA-U01	Robert Thompson	2026-08-10	10:00:00	Cleaning	1134534266	scheduled	demo	\N	2026-08-08 00:47:48.401519+00
b221ae42-edb6-49c9-83c4-30279099f5fc	suwanee_smiles	PRED-SIM-DA-U02	Maria Santos	2026-08-10	10:30:00	Bitewings	1134534266	scheduled	demo	\N	2026-08-08 00:47:48.505434+00
e63efd69-f59b-4027-89ec-175dd887db33	suwanee_smiles	PRED-SIM-DA-B04	Carlos Rivera	2026-08-10	11:00:00	Implant + graft	1134534266	scheduled	demo	\N	2026-08-08 00:47:48.606202+00
87168b38-a579-4df3-ba9a-eaaec021ad72	suwanee_smiles	PRED-SIM-DA-A01	James Mitchell	2026-08-11	09:00:00	Implant + crown	1134534266	scheduled	demo	\N	2026-08-08 00:47:48.729372+00
1dbf45dc-164e-4c5c-b0ee-9a4a372fc917	suwanee_smiles	PRED-SIM-DA-D04	Linda Taylor	2026-08-11	09:30:00	Crown	1134534266	scheduled	demo	\N	2026-08-08 00:47:48.840932+00
ef30d800-739e-42b5-bc8b-df2785bd4fce	suwanee_smiles	PRED-SIM-DA-U01	Robert Thompson	2026-08-11	10:00:00	Cleaning	1134534266	scheduled	demo	\N	2026-08-08 00:47:48.955598+00
cee1f9da-674d-4904-9924-58e2ded67126	suwanee_smiles	PRED-SIM-DA-U02	Maria Santos	2026-08-11	10:30:00	Bitewings	1134534266	scheduled	demo	\N	2026-08-08 00:47:49.080952+00
b6487a4f-6b71-4d35-9498-6525b788f112	suwanee_smiles	PRED-SIM-DA-B04	Carlos Rivera	2026-08-11	11:00:00	Implant + graft	1134534266	scheduled	demo	\N	2026-08-08 00:47:49.188155+00
cb248a7b-165e-44ea-a19e-62fd97f386f7	suwanee_smiles	PRED-SIM-DA-A01	James Mitchell	2026-08-12	09:00:00	Implant + crown	1134534266	scheduled	demo	\N	2026-08-08 00:47:49.313141+00
b9b82fc0-3691-42b4-978a-fda0f2d31073	suwanee_smiles	PRED-SIM-DA-D04	Linda Taylor	2026-08-12	09:30:00	Crown	1134534266	scheduled	demo	\N	2026-08-08 00:47:49.412575+00
e34e9e1d-e24a-4452-9af3-b37f0cdee2db	suwanee_smiles	PRED-SIM-DA-U01	Robert Thompson	2026-08-12	10:00:00	Cleaning	1134534266	scheduled	demo	\N	2026-08-08 00:47:49.532853+00
09946b2b-aab2-4383-9e54-94283b264cf8	suwanee_smiles	PRED-SIM-DA-U02	Maria Santos	2026-08-12	10:30:00	Bitewings	1134534266	scheduled	demo	\N	2026-08-08 00:47:49.671329+00
099e42b5-668f-401b-ad49-022ed6085cea	suwanee_smiles	PRED-SIM-DA-B04	Carlos Rivera	2026-08-12	11:00:00	Implant + graft	1134534266	scheduled	demo	\N	2026-08-08 00:47:49.776925+00
58abdd14-fe17-4e48-a5c4-3ff34d427a72	suwanee_smiles	PRED-SIM-DA-A01	James Mitchell	2026-08-13	09:00:00	Implant + crown	1134534266	scheduled	demo	\N	2026-08-08 00:47:49.878254+00
e8337211-abfd-4c4a-bc62-972370a3db6d	suwanee_smiles	PRED-SIM-DA-D04	Linda Taylor	2026-08-13	09:30:00	Crown	1134534266	scheduled	demo	\N	2026-08-08 00:47:49.980699+00
1958df7f-a337-4f24-b81d-3ab6d6a2e607	suwanee_smiles	PRED-SIM-DA-U01	Robert Thompson	2026-08-13	10:00:00	Cleaning	1134534266	scheduled	demo	\N	2026-08-08 00:47:50.13762+00
3fc94dee-03f4-40e6-b553-d659f91fb8e7	suwanee_smiles	PRED-SIM-DA-U02	Maria Santos	2026-08-13	10:30:00	Bitewings	1134534266	scheduled	demo	\N	2026-08-08 00:47:50.243106+00
d324f113-29c6-474b-aa74-5e78854aff1c	suwanee_smiles	PRED-SIM-DA-B04	Carlos Rivera	2026-08-13	11:00:00	Implant + graft	1134534266	scheduled	demo	\N	2026-08-08 00:47:50.361331+00
64c3b322-3b0b-4303-b7cd-84f328107983	suwanee_smiles	PRED-SIM-DA-A01	X	2026-08-09	09:00:00	Implant + crown	1134534266	scheduled	manual	\N	2026-08-08 00:47:47.606675+00
5d6be60e-4cf9-4f0a-bf65-10e824e4db88	suwanee_smiles	PRED-SIM-DA-A01	James Mitchell	2026-08-14	09:00:00	Implant + crown	1134534266	scheduled	demo	\N	2026-08-08 00:47:50.481608+00
0d893ad9-459e-45fb-9673-8a8a3cbe873e	suwanee_smiles	PRED-SIM-DA-D04	Linda Taylor	2026-08-14	09:30:00	Crown	1134534266	scheduled	demo	\N	2026-08-08 00:47:50.590511+00
dee66154-b87b-4640-83b0-e57691ebd386	suwanee_smiles	PRED-SIM-DA-U01	Robert Thompson	2026-08-15	10:00:00	Cleaning	1134534266	scheduled	demo	\N	2026-08-08 00:47:51.278709+00
36f538dd-ee28-46b3-8e15-2b17843ca19f	suwanee_smiles	PRED-SIM-DA-U01	Robert Thompson	2026-08-14	10:00:00	Cleaning	1134534266	scheduled	demo	\N	2026-08-08 00:47:50.690053+00
46a5d60d-3076-45d5-b155-70106cc1c9ac	suwanee_smiles	PRED-SIM-DA-U02	Maria Santos	2026-08-14	10:30:00	Bitewings	1134534266	scheduled	demo	\N	2026-08-08 00:47:50.82409+00
2e0f879a-4bc5-449e-890e-623a6e0d8781	suwanee_smiles	PRED-SIM-DA-B04	Carlos Rivera	2026-08-14	11:00:00	Implant + graft	1134534266	scheduled	demo	\N	2026-08-08 00:47:50.937329+00
0ee6e8df-2f84-490b-b854-88a323e6c5ec	suwanee_smiles	PRED-SIM-DA-A01	James Mitchell	2026-08-15	09:00:00	Implant + crown	1134534266	scheduled	demo	\N	2026-08-08 00:47:51.051575+00
ac42f2ae-c15c-4f7d-8f27-764575dae6eb	suwanee_smiles	PRED-SIM-DA-D04	Linda Taylor	2026-08-15	09:30:00	Crown	1134534266	scheduled	demo	\N	2026-08-08 00:47:51.175995+00
421c225c-ae8d-4079-b70e-c2c2dc091b53	suwanee_smiles	PRED-SIM-DA-U02	Maria Santos	2026-08-15	10:30:00	Bitewings	1134534266	scheduled	demo	\N	2026-08-08 00:47:51.379651+00
aafb39ad-e4eb-443a-9ebb-d773c36ca86a	suwanee_smiles	PRED-SIM-DA-B04	Carlos Rivera	2026-08-15	11:00:00	Implant + graft	1134534266	scheduled	demo	\N	2026-08-08 00:47:51.498241+00
\.


--
-- Data for Name: checkin_events; Type: TABLE DATA; Schema: public; Owner: dental_admin
--

COPY public.checkin_events (event_id, pred_request_id, tenant_id, patient_name, checked_in_by, checked_in_at, checkin_day, notes) FROM stdin;
8db350a9-bf07-4c55-a17d-05505dbcfdc2	PRED-SIM-DA-A01	suwanee_smiles	James Mitchell	ec17b817-c9b0-41e2-abdf-a0eac4e32dec	2026-08-07 19:22:48.811672+00	2026-08-07	\N
2a552f5e-f288-471f-b8df-1ce1d7eb1c29	PRED-SIM-DA-U01	suwanee_smiles	Robert Thompson	ec17b817-c9b0-41e2-abdf-a0eac4e32dec	2026-08-07 19:27:02.699027+00	2026-08-07	\N
792a30e6-9058-4f4c-adc9-bb4c64a7a968	PRED-SIM-DA-A01	suwanee_smiles	James Mitchell	ec17b817-c9b0-41e2-abdf-a0eac4e32dec	2026-08-09 21:45:42.940311+00	2026-08-09	\N
a2b21f5f-5110-4ebe-8204-e7c51f88defb	PRED-SIM-DA-D04	suwanee_smiles	Linda Taylor	ec17b817-c9b0-41e2-abdf-a0eac4e32dec	2026-08-09 21:45:42.996044+00	2026-08-09	\N
a09b8e04-85c3-4630-92df-c38ec181b48e	PRED-SIM-DA-B04	suwanee_smiles	Carlos Rivera	ec17b817-c9b0-41e2-abdf-a0eac4e32dec	2026-08-09 21:45:43.051394+00	2026-08-09	\N
\.


--
-- Data for Name: clinical_attestations; Type: TABLE DATA; Schema: public; Owner: dental_admin
--

COPY public.clinical_attestations (attestation_id, tenant_id, pred_request_id, attested_by, attested_at, narrative_text, statement, submission_id) FROM stdin;
080eae52-5bc5-41e2-8ad3-c018d58aaf72	suwanee_smiles	PRED-SIM-DA-D04	2ae13640-9c22-460d-aade-ffbf1afd7343	2026-08-10 00:39:36.74519+00	Caries extending to pulp chamber, tooth #8. Crown all-ceramic anterior (D2740) restores function at tooth #8.	I attest that the clinical record supports the procedures submitted and that the narrative accompanying this pre-determination is accurate to the best of my clinical judgement.	\N
26b12bb4-610e-40c2-8ecc-80f62717c067	suwanee_smiles	PRED-SIM-DA-U02	2ae13640-9c22-460d-aade-ffbf1afd7343	2026-08-10 00:56:59.343581+00	\N	I attest that the clinical record supports the procedures submitted and that the narrative accompanying this pre-determination is accurate to the best of my clinical judgement.	\N
\.


--
-- Data for Name: clinical_handoffs; Type: TABLE DATA; Schema: public; Owner: dental_admin
--

COPY public.clinical_handoffs (handoff_id, tenant_id, pred_request_id, to_role, from_user, message, created_at, read_at, read_by, kind) FROM stdin;
ea46dcd0-a591-44fe-b56c-8edefc1992e1	suwanee_smiles	PRED-SIM-DA-A01	dentist	abfec417-f4a8-4c1f-9dc1-6abcad3db672	Consultation complete with James Mitchell. Patient portion $1,240.00 discussed â€” he asked whether a filling would hold instead. Price-sensitive; wants to hear it from you.	2026-08-10 00:37:17.936091+00	2026-08-10 00:38:28.539681+00	2ae13640-9c22-460d-aade-ffbf1afd7343	consultation_complete
b8140b5d-11ec-44b0-a57c-d541bc2b8803	suwanee_smiles	PRED-SIM-DA-B04	dentist	abfec417-f4a8-4c1f-9dc1-6abcad3db672	Carlos is back in chair 3 â€” he wants to know if the graft can wait until January for the new benefit year.	2026-08-10 00:41:44.020385+00	2026-08-10 01:03:33.619633+00	2ae13640-9c22-460d-aade-ffbf1afd7343	note
\.


--
-- Data for Name: clinical_justifications; Type: TABLE DATA; Schema: public; Owner: dental_admin
--

COPY public.clinical_justifications (justification_id, tenant_id, pred_request_id, signal_code, justification, justified_by, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: clinical_narratives; Type: TABLE DATA; Schema: public; Owner: dental_admin
--

COPY public.clinical_narratives (narrative_id, tenant_id, pred_request_id, narrative_text, source, written_by, created_at, updated_at) FROM stdin;
6a0d10be-7120-4084-9bfb-074cd37b970b	suwanee_smiles	PRED-SIM-DA-D04	Caries extending to pulp chamber, tooth #8. Crown all-ceramic anterior (D2740) restores function at tooth #8.	draft	2ae13640-9c22-460d-aade-ffbf1afd7343	2026-08-10 00:39:36.624418+00	2026-08-10 00:39:36.624418+00
\.


--
-- Data for Name: denial_events; Type: TABLE DATA; Schema: public; Owner: dental_admin
--

COPY public.denial_events (denial_id, tenant_id, pred_request_id, patient_name, payer_id, denied_at, denial_reason, denial_reason_code, denied_amount, appeal_deadline, appeal_viable, appeal_probability, notes, submission_id) FROM stdin;
7af1d503-589b-41fb-9ecc-d99f52a64404	suwanee_smiles	PRED-SIM-DA-B04	Carlos Rivera	delta_dental	2026-07-24 14:30:00+00	bundling	D.7.4-BUNDLE	950.00	2026-09-22 14:30:00+00	t	\N	D7953 denied as bundled with D6010. Separable with a narrative documenting the graft as its own surgical episode.	3eab7596-4d5e-411b-b8e9-8d58359c39ec
2be5d675-34e8-467e-8039-5456595d8bb1	suwanee_smiles	PRED-SIM-DA-B01	Patricia Johnson	delta_dental	2026-05-23 14:30:00+00	frequency	D.1.2-FREQ	1800.00	2026-07-22 14:30:00+00	t	\N	Denied against the frequency limit. The prior restoration was placed by another practice and the limit runs from the seat date, not the prep date.	c274c3fc-0e26-4440-8b11-c9634879f83e
fa28ed91-2f36-4d23-847c-1301dfed3d99	suwanee_smiles	PRED-SIM-DA-B05	Ashley Thompson	delta_dental	2026-05-29 14:30:00+00	waiting_period	D.2.1-WAIT	1450.00	2026-07-28 14:30:00+00	t	\N	Denied inside the 12-month major-services waiting period. Appealed on continuous-coverage grounds; the prior carrier's certificate did not cover the gap.	ef0506a5-ab6d-4f22-8fce-836c364c48fc
\.


--
-- Data for Name: document_requests; Type: TABLE DATA; Schema: public; Owner: dental_admin
--

COPY public.document_requests (request_id, tenant_id, pred_request_id, document_type, signal_code, requested_from, requested_by, note, status, requested_at, resolved_at) FROM stdin;
\.


--
-- Data for Name: provider_feedback; Type: TABLE DATA; Schema: public; Owner: dental_admin
--

COPY public.provider_feedback (feedback_id, pred_request_id, tenant_id, decision_id, signal_code, feedback_type, notes, submitted_by, submitted_at, expires_at) FROM stdin;
c2125635-69be-4135-8716-7c038fcfd991	PRED-SIM-DA-A01	suwanee_smiles	coverage_analyst	COVERAGE_BUNDLING_CONFLICT	accepted	Confirmed â€” will add narrative	billing	2026-08-06 12:31:10.049707+00	2027-08-06 12:31:10.049707+00
9ef02523-bf44-4cdc-9491-b8c9436f95a6	PRED-SIM-DA-A01	suwanee_smiles	coverage_analyst	COVERAGE_BUNDLING_CONFLICT	accepted	Confirmed â€” will add narrative	billing	2026-08-06 12:32:09.253653+00	2027-08-06 12:32:09.253653+00
37df8805-9ec5-4dfe-adf9-34d25d06e713	PRED-SIM-DA-A01	suwanee_smiles	coverage_analyst	COVERAGE_BUNDLING_CONFLICT	accepted	Confirmed â€” will add narrative	billing	2026-08-06 12:32:32.479904+00	2027-08-06 12:32:32.479904+00
e0822bdd-4ce9-444f-9d0e-a88fe35a7bb2	PRED-SIM-DA-A01	suwanee_smiles	coverage_analyst	COVERAGE_BUNDLING_CONFLICT	accepted	Confirmed â€” will add narrative	billing	2026-08-06 12:36:28.089609+00	2027-08-06 12:36:28.089609+00
2c654b68-8fff-4b0a-b86c-6266a8106753	PRED-SIM-DA-A01	suwanee_smiles	coverage_analyst	COVERAGE_BUNDLING_CONFLICT	accepted	Confirmed â€” will add narrative	billing	2026-08-06 12:38:25.33868+00	2027-08-06 12:38:25.33868+00
aff492ba-ef20-4733-85e2-225fb961218f	PRED-SIM-DA-A01	suwanee_smiles	coverage_analyst	COVERAGE_BUNDLING_CONFLICT	accepted	Confirmed â€” will add narrative	billing	2026-08-06 14:03:31.431776+00	2027-08-06 14:03:31.431776+00
9e3a8c9d-8a1b-4694-ac94-8f4330923ad9	PRED-SIM-DA-A01	suwanee_smiles	coverage_analyst	COVERAGE_BUNDLING_CONFLICT	accepted	Confirmed â€” will add narrative	billing	2026-08-06 19:50:25.072713+00	2027-08-06 19:50:25.072713+00
85750c59-e63d-453a-b211-25e1dc908413	PRED-SIM-DA-A01	suwanee_smiles	pre_d_assessment	PRED_CONDITIONS_OPEN	accepted	Resolved by revenue ops	billing	2026-08-06 21:04:16.054365+00	2027-08-06 21:04:16.054365+00
084d5c14-2000-4240-aecf-002c915e42c9	PRED-SIM-DA-D04	suwanee_smiles	pre_d_assessment	PRED_READY_TO_SUBMIT	accepted	Submitted to Delta Dental PPO by revenue ops	billing	2026-08-08 14:19:15.231036+00	2027-08-08 14:19:15.231036+00
480e16e4-3f9b-417a-99db-366125b8c376	PRED-SIM-DA-A01	suwanee_smiles	pre_d_assessment	PRED_CONDITIONS_OPEN	accepted	Resolved by revenue ops	billing	2026-08-08 14:19:48.127059+00	2027-08-08 14:19:48.127059+00
798c9019-6aff-4d97-b08d-238cacd88825	PRED-SIM-DA-A01	suwanee_smiles	pre_d_assessment	PRED_CONDITIONS_OPEN	accepted	Resolved by revenue ops	billing	2026-08-08 14:20:36.418237+00	2027-08-08 14:20:36.418237+00
\.


--
-- Data for Name: submission_events; Type: TABLE DATA; Schema: public; Owner: dental_admin
--

COPY public.submission_events (submission_id, tenant_id, pred_request_id, patient_name, payer_id, payer_name, submitted_by, submitted_at, submission_method, submission_ref, expected_response_days, status, notes) FROM stdin;
3eab7596-4d5e-411b-b8e9-8d58359c39ec	suwanee_smiles	PRED-SIM-DA-B04	Carlos Rivera	delta_dental	Delta Dental PPO	3069f79f-8ea4-41b0-a35f-74a640e68238	2026-07-10 14:30:00+00	manual	\N	15	responded	Submitted from the revenue ops queue.
c274c3fc-0e26-4440-8b11-c9634879f83e	suwanee_smiles	PRED-SIM-DA-B01	Patricia Johnson	delta_dental	Delta Dental PPO	3069f79f-8ea4-41b0-a35f-74a640e68238	2026-05-05 14:30:00+00	manual	\N	15	responded	Submitted from the revenue ops queue.
ef0506a5-ab6d-4f22-8fce-836c364c48fc	suwanee_smiles	PRED-SIM-DA-B05	Ashley Thompson	delta_dental	Delta Dental PPO	3069f79f-8ea4-41b0-a35f-74a640e68238	2026-05-13 14:30:00+00	manual	\N	15	responded	Submitted from the revenue ops queue.
\.


--
-- Name: appeal_events appeal_events_pkey; Type: CONSTRAINT; Schema: public; Owner: dental_admin
--

ALTER TABLE ONLY public.appeal_events
    ADD CONSTRAINT appeal_events_pkey PRIMARY KEY (appeal_id);


--
-- Name: appeal_packets appeal_packets_pkey; Type: CONSTRAINT; Schema: public; Owner: dental_admin
--

ALTER TABLE ONLY public.appeal_packets
    ADD CONSTRAINT appeal_packets_pkey PRIMARY KEY (packet_id);


--
-- Name: appointments appointments_pkey; Type: CONSTRAINT; Schema: public; Owner: dental_admin
--

ALTER TABLE ONLY public.appointments
    ADD CONSTRAINT appointments_pkey PRIMARY KEY (appointment_id);


--
-- Name: checkin_events checkin_events_pkey; Type: CONSTRAINT; Schema: public; Owner: dental_admin
--

ALTER TABLE ONLY public.checkin_events
    ADD CONSTRAINT checkin_events_pkey PRIMARY KEY (event_id);


--
-- Name: clinical_attestations clinical_attestations_pkey; Type: CONSTRAINT; Schema: public; Owner: dental_admin
--

ALTER TABLE ONLY public.clinical_attestations
    ADD CONSTRAINT clinical_attestations_pkey PRIMARY KEY (attestation_id);


--
-- Name: clinical_handoffs clinical_handoffs_pkey; Type: CONSTRAINT; Schema: public; Owner: dental_admin
--

ALTER TABLE ONLY public.clinical_handoffs
    ADD CONSTRAINT clinical_handoffs_pkey PRIMARY KEY (handoff_id);


--
-- Name: clinical_justifications clinical_justifications_pkey; Type: CONSTRAINT; Schema: public; Owner: dental_admin
--

ALTER TABLE ONLY public.clinical_justifications
    ADD CONSTRAINT clinical_justifications_pkey PRIMARY KEY (justification_id);


--
-- Name: clinical_narratives clinical_narratives_pkey; Type: CONSTRAINT; Schema: public; Owner: dental_admin
--

ALTER TABLE ONLY public.clinical_narratives
    ADD CONSTRAINT clinical_narratives_pkey PRIMARY KEY (narrative_id);


--
-- Name: decision_outputs decision_outputs_pkey; Type: CONSTRAINT; Schema: public; Owner: dental_admin
--

ALTER TABLE ONLY public.decision_outputs
    ADD CONSTRAINT decision_outputs_pkey PRIMARY KEY (output_id);


--
-- Name: denial_events denial_events_pkey; Type: CONSTRAINT; Schema: public; Owner: dental_admin
--

ALTER TABLE ONLY public.denial_events
    ADD CONSTRAINT denial_events_pkey PRIMARY KEY (denial_id);


--
-- Name: document_requests document_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: dental_admin
--

ALTER TABLE ONLY public.document_requests
    ADD CONSTRAINT document_requests_pkey PRIMARY KEY (request_id);


--
-- Name: persona_bundles persona_bundles_pkey; Type: CONSTRAINT; Schema: public; Owner: dental_admin
--

ALTER TABLE ONLY public.persona_bundles
    ADD CONSTRAINT persona_bundles_pkey PRIMARY KEY (bundle_id);


--
-- Name: provider_feedback provider_feedback_pkey; Type: CONSTRAINT; Schema: public; Owner: dental_admin
--

ALTER TABLE ONLY public.provider_feedback
    ADD CONSTRAINT provider_feedback_pkey PRIMARY KEY (feedback_id);


--
-- Name: submission_events submission_events_pkey; Type: CONSTRAINT; Schema: public; Owner: dental_admin
--

ALTER TABLE ONLY public.submission_events
    ADD CONSTRAINT submission_events_pkey PRIMARY KEY (submission_id);


--
-- Name: tenant_ownership tenant_ownership_pkey; Type: CONSTRAINT; Schema: public; Owner: dental_admin
--

ALTER TABLE ONLY public.tenant_ownership
    ADD CONSTRAINT tenant_ownership_pkey PRIMARY KEY (ownership_id);


--
-- Name: tenant_ownership tenant_ownership_unique; Type: CONSTRAINT; Schema: public; Owner: dental_admin
--

ALTER TABLE ONLY public.tenant_ownership
    ADD CONSTRAINT tenant_ownership_unique UNIQUE (user_id, tenant_id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: dental_admin
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: dental_admin
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (user_id);


--
-- Name: appeal_events_tenant_date; Type: INDEX; Schema: public; Owner: dental_admin
--

CREATE INDEX appeal_events_tenant_date ON public.appeal_events USING btree (tenant_id, filed_at);


--
-- Name: appeal_events_unique; Type: INDEX; Schema: public; Owner: dental_admin
--

CREATE UNIQUE INDEX appeal_events_unique ON public.appeal_events USING btree (tenant_id, pred_request_id);


--
-- Name: appointments_one_per_pred_per_day; Type: INDEX; Schema: public; Owner: dental_admin
--

CREATE UNIQUE INDEX appointments_one_per_pred_per_day ON public.appointments USING btree (tenant_id, pred_request_id, appointment_date);


--
-- Name: appointments_pms_id; Type: INDEX; Schema: public; Owner: dental_admin
--

CREATE UNIQUE INDEX appointments_pms_id ON public.appointments USING btree (pms_source, pms_appointment_id) WHERE (pms_appointment_id IS NOT NULL);


--
-- Name: checkin_events_once_per_day; Type: INDEX; Schema: public; Owner: dental_admin
--

CREATE UNIQUE INDEX checkin_events_once_per_day ON public.checkin_events USING btree (tenant_id, pred_request_id, checkin_day);


--
-- Name: checkin_events_tenant_date; Type: INDEX; Schema: public; Owner: dental_admin
--

CREATE INDEX checkin_events_tenant_date ON public.checkin_events USING btree (tenant_id, checked_in_at);


--
-- Name: clinical_attestations_one_per_pred; Type: INDEX; Schema: public; Owner: dental_admin
--

CREATE UNIQUE INDEX clinical_attestations_one_per_pred ON public.clinical_attestations USING btree (tenant_id, pred_request_id);


--
-- Name: clinical_attestations_tenant_pred; Type: INDEX; Schema: public; Owner: dental_admin
--

CREATE INDEX clinical_attestations_tenant_pred ON public.clinical_attestations USING btree (tenant_id, pred_request_id, attested_at DESC);


--
-- Name: clinical_handoffs_one_per_kind; Type: INDEX; Schema: public; Owner: dental_admin
--

CREATE UNIQUE INDEX clinical_handoffs_one_per_kind ON public.clinical_handoffs USING btree (tenant_id, pred_request_id, to_role, kind);


--
-- Name: clinical_handoffs_unread; Type: INDEX; Schema: public; Owner: dental_admin
--

CREATE INDEX clinical_handoffs_unread ON public.clinical_handoffs USING btree (tenant_id, to_role, pred_request_id) WHERE (read_at IS NULL);


--
-- Name: clinical_justifications_unique; Type: INDEX; Schema: public; Owner: dental_admin
--

CREATE UNIQUE INDEX clinical_justifications_unique ON public.clinical_justifications USING btree (tenant_id, pred_request_id, signal_code);


--
-- Name: clinical_narratives_unique; Type: INDEX; Schema: public; Owner: dental_admin
--

CREATE UNIQUE INDEX clinical_narratives_unique ON public.clinical_narratives USING btree (tenant_id, pred_request_id);


--
-- Name: denial_events_tenant_date; Type: INDEX; Schema: public; Owner: dental_admin
--

CREATE INDEX denial_events_tenant_date ON public.denial_events USING btree (tenant_id, denied_at);


--
-- Name: denial_events_unique; Type: INDEX; Schema: public; Owner: dental_admin
--

CREATE UNIQUE INDEX denial_events_unique ON public.denial_events USING btree (tenant_id, pred_request_id);


--
-- Name: document_requests_tenant_pred; Type: INDEX; Schema: public; Owner: dental_admin
--

CREATE INDEX document_requests_tenant_pred ON public.document_requests USING btree (tenant_id, pred_request_id, status);


--
-- Name: idx_appeal_packets_pred; Type: INDEX; Schema: public; Owner: dental_admin
--

CREATE INDEX idx_appeal_packets_pred ON public.appeal_packets USING btree (pred_request_id, tenant_id);


--
-- Name: idx_decision_outputs_decision; Type: INDEX; Schema: public; Owner: dental_admin
--

CREATE INDEX idx_decision_outputs_decision ON public.decision_outputs USING btree (decision_id, tenant_id, created_at DESC);


--
-- Name: idx_decision_outputs_pred; Type: INDEX; Schema: public; Owner: dental_admin
--

CREATE INDEX idx_decision_outputs_pred ON public.decision_outputs USING btree (pred_request_id, tenant_id);


--
-- Name: idx_persona_bundles_current; Type: INDEX; Schema: public; Owner: dental_admin
--

CREATE INDEX idx_persona_bundles_current ON public.persona_bundles USING btree (pred_request_id, tenant_id) WHERE is_current;


--
-- Name: idx_persona_bundles_pred; Type: INDEX; Schema: public; Owner: dental_admin
--

CREATE INDEX idx_persona_bundles_pred ON public.persona_bundles USING btree (pred_request_id, tenant_id);


--
-- Name: idx_provider_feedback_pred; Type: INDEX; Schema: public; Owner: dental_admin
--

CREATE INDEX idx_provider_feedback_pred ON public.provider_feedback USING btree (pred_request_id, tenant_id);


--
-- Name: idx_provider_feedback_signal; Type: INDEX; Schema: public; Owner: dental_admin
--

CREATE INDEX idx_provider_feedback_signal ON public.provider_feedback USING btree (signal_code, tenant_id);


--
-- Name: submission_events_tenant_date; Type: INDEX; Schema: public; Owner: dental_admin
--

CREATE INDEX submission_events_tenant_date ON public.submission_events USING btree (tenant_id, submitted_at);


--
-- Name: submission_events_unique; Type: INDEX; Schema: public; Owner: dental_admin
--

CREATE UNIQUE INDEX submission_events_unique ON public.submission_events USING btree (tenant_id, pred_request_id);


--
-- Name: tenant_ownership_user; Type: INDEX; Schema: public; Owner: dental_admin
--

CREATE INDEX tenant_ownership_user ON public.tenant_ownership USING btree (user_id);


--
-- Name: appeal_events appeal_events_denial_fk; Type: FK CONSTRAINT; Schema: public; Owner: dental_admin
--

ALTER TABLE ONLY public.appeal_events
    ADD CONSTRAINT appeal_events_denial_fk FOREIGN KEY (denial_id) REFERENCES public.denial_events(denial_id) ON DELETE SET NULL;


--
-- Name: denial_events denial_events_submission_fk; Type: FK CONSTRAINT; Schema: public; Owner: dental_admin
--

ALTER TABLE ONLY public.denial_events
    ADD CONSTRAINT denial_events_submission_fk FOREIGN KEY (submission_id) REFERENCES public.submission_events(submission_id) ON DELETE SET NULL;


--
-- Name: tenant_ownership tenant_ownership_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: dental_admin
--

ALTER TABLE ONLY public.tenant_ownership
    ADD CONSTRAINT tenant_ownership_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id) ON DELETE CASCADE;


--
-- Name: appeal_events; Type: ROW SECURITY; Schema: public; Owner: dental_admin
--

ALTER TABLE public.appeal_events ENABLE ROW LEVEL SECURITY;

--
-- Name: appeal_packets; Type: ROW SECURITY; Schema: public; Owner: dental_admin
--

ALTER TABLE public.appeal_packets ENABLE ROW LEVEL SECURITY;

--
-- Name: appeal_events appeal_tenant_isolation; Type: POLICY; Schema: public; Owner: dental_admin
--

CREATE POLICY appeal_tenant_isolation ON public.appeal_events USING ((tenant_id = current_setting('app.tenant_id'::text, true))) WITH CHECK ((tenant_id = current_setting('app.tenant_id'::text, true)));


--
-- Name: appointments; Type: ROW SECURITY; Schema: public; Owner: dental_admin
--

ALTER TABLE public.appointments ENABLE ROW LEVEL SECURITY;

--
-- Name: appointments appointments_tenant; Type: POLICY; Schema: public; Owner: dental_admin
--

CREATE POLICY appointments_tenant ON public.appointments USING ((tenant_id = current_setting('app.tenant_id'::text, true))) WITH CHECK ((tenant_id = current_setting('app.tenant_id'::text, true)));


--
-- Name: checkin_events; Type: ROW SECURITY; Schema: public; Owner: dental_admin
--

ALTER TABLE public.checkin_events ENABLE ROW LEVEL SECURITY;

--
-- Name: checkin_events checkin_events_tenant; Type: POLICY; Schema: public; Owner: dental_admin
--

CREATE POLICY checkin_events_tenant ON public.checkin_events USING ((tenant_id = current_setting('app.tenant_id'::text, true))) WITH CHECK ((tenant_id = current_setting('app.tenant_id'::text, true)));


--
-- Name: clinical_attestations; Type: ROW SECURITY; Schema: public; Owner: dental_admin
--

ALTER TABLE public.clinical_attestations ENABLE ROW LEVEL SECURITY;

--
-- Name: clinical_attestations clinical_attestations_tenant; Type: POLICY; Schema: public; Owner: dental_admin
--

CREATE POLICY clinical_attestations_tenant ON public.clinical_attestations USING ((tenant_id = current_setting('app.tenant_id'::text, true))) WITH CHECK ((tenant_id = current_setting('app.tenant_id'::text, true)));


--
-- Name: clinical_handoffs; Type: ROW SECURITY; Schema: public; Owner: dental_admin
--

ALTER TABLE public.clinical_handoffs ENABLE ROW LEVEL SECURITY;

--
-- Name: clinical_handoffs clinical_handoffs_tenant; Type: POLICY; Schema: public; Owner: dental_admin
--

CREATE POLICY clinical_handoffs_tenant ON public.clinical_handoffs USING ((tenant_id = current_setting('app.tenant_id'::text, true))) WITH CHECK ((tenant_id = current_setting('app.tenant_id'::text, true)));


--
-- Name: clinical_justifications; Type: ROW SECURITY; Schema: public; Owner: dental_admin
--

ALTER TABLE public.clinical_justifications ENABLE ROW LEVEL SECURITY;

--
-- Name: clinical_justifications clinical_justifications_tenant; Type: POLICY; Schema: public; Owner: dental_admin
--

CREATE POLICY clinical_justifications_tenant ON public.clinical_justifications USING ((tenant_id = current_setting('app.tenant_id'::text, true))) WITH CHECK ((tenant_id = current_setting('app.tenant_id'::text, true)));


--
-- Name: clinical_narratives; Type: ROW SECURITY; Schema: public; Owner: dental_admin
--

ALTER TABLE public.clinical_narratives ENABLE ROW LEVEL SECURITY;

--
-- Name: clinical_narratives clinical_narratives_tenant; Type: POLICY; Schema: public; Owner: dental_admin
--

CREATE POLICY clinical_narratives_tenant ON public.clinical_narratives USING ((tenant_id = current_setting('app.tenant_id'::text, true))) WITH CHECK ((tenant_id = current_setting('app.tenant_id'::text, true)));


--
-- Name: decision_outputs; Type: ROW SECURITY; Schema: public; Owner: dental_admin
--

ALTER TABLE public.decision_outputs ENABLE ROW LEVEL SECURITY;

--
-- Name: denial_events; Type: ROW SECURITY; Schema: public; Owner: dental_admin
--

ALTER TABLE public.denial_events ENABLE ROW LEVEL SECURITY;

--
-- Name: denial_events denial_tenant_isolation; Type: POLICY; Schema: public; Owner: dental_admin
--

CREATE POLICY denial_tenant_isolation ON public.denial_events USING ((tenant_id = current_setting('app.tenant_id'::text, true))) WITH CHECK ((tenant_id = current_setting('app.tenant_id'::text, true)));


--
-- Name: document_requests; Type: ROW SECURITY; Schema: public; Owner: dental_admin
--

ALTER TABLE public.document_requests ENABLE ROW LEVEL SECURITY;

--
-- Name: document_requests document_requests_tenant; Type: POLICY; Schema: public; Owner: dental_admin
--

CREATE POLICY document_requests_tenant ON public.document_requests USING ((tenant_id = current_setting('app.tenant_id'::text, true))) WITH CHECK ((tenant_id = current_setting('app.tenant_id'::text, true)));


--
-- Name: persona_bundles; Type: ROW SECURITY; Schema: public; Owner: dental_admin
--

ALTER TABLE public.persona_bundles ENABLE ROW LEVEL SECURITY;

--
-- Name: provider_feedback; Type: ROW SECURITY; Schema: public; Owner: dental_admin
--

ALTER TABLE public.provider_feedback ENABLE ROW LEVEL SECURITY;

--
-- Name: submission_events; Type: ROW SECURITY; Schema: public; Owner: dental_admin
--

ALTER TABLE public.submission_events ENABLE ROW LEVEL SECURITY;

--
-- Name: submission_events submission_tenant_isolation; Type: POLICY; Schema: public; Owner: dental_admin
--

CREATE POLICY submission_tenant_isolation ON public.submission_events USING ((tenant_id = current_setting('app.tenant_id'::text, true))) WITH CHECK ((tenant_id = current_setting('app.tenant_id'::text, true)));


--
-- Name: appeal_packets tenant_isolation; Type: POLICY; Schema: public; Owner: dental_admin
--

CREATE POLICY tenant_isolation ON public.appeal_packets USING (((tenant_id)::text = current_setting('app.tenant_id'::text, true))) WITH CHECK (((tenant_id)::text = current_setting('app.tenant_id'::text, true)));


--
-- Name: decision_outputs tenant_isolation; Type: POLICY; Schema: public; Owner: dental_admin
--

CREATE POLICY tenant_isolation ON public.decision_outputs USING (((tenant_id)::text = current_setting('app.tenant_id'::text, true))) WITH CHECK (((tenant_id)::text = current_setting('app.tenant_id'::text, true)));


--
-- Name: persona_bundles tenant_isolation; Type: POLICY; Schema: public; Owner: dental_admin
--

CREATE POLICY tenant_isolation ON public.persona_bundles USING (((tenant_id)::text = current_setting('app.tenant_id'::text, true))) WITH CHECK (((tenant_id)::text = current_setting('app.tenant_id'::text, true)));


--
-- Name: provider_feedback tenant_isolation; Type: POLICY; Schema: public; Owner: dental_admin
--

CREATE POLICY tenant_isolation ON public.provider_feedback USING (((tenant_id)::text = current_setting('app.tenant_id'::text, true))) WITH CHECK (((tenant_id)::text = current_setting('app.tenant_id'::text, true)));


--
-- Name: tenant_ownership; Type: ROW SECURITY; Schema: public; Owner: dental_admin
--

ALTER TABLE public.tenant_ownership ENABLE ROW LEVEL SECURITY;

--
-- Name: tenant_ownership tenant_ownership_tenant; Type: POLICY; Schema: public; Owner: dental_admin
--

CREATE POLICY tenant_ownership_tenant ON public.tenant_ownership USING ((tenant_id = current_setting('app.tenant_id'::text, true))) WITH CHECK ((tenant_id = current_setting('app.tenant_id'::text, true)));


--
-- Name: users; Type: ROW SECURITY; Schema: public; Owner: dental_admin
--

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

--
-- Name: users users_tenant; Type: POLICY; Schema: public; Owner: dental_admin
--

CREATE POLICY users_tenant ON public.users USING ((tenant_id = current_setting('app.tenant_id'::text, true))) WITH CHECK ((tenant_id = current_setting('app.tenant_id'::text, true)));


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: pg_database_owner
--

GRANT USAGE ON SCHEMA public TO dental_app;
GRANT USAGE ON SCHEMA public TO dental_auth;


--
-- Name: FUNCTION authenticate_user(p_email text); Type: ACL; Schema: public; Owner: dental_auth
--

REVOKE ALL ON FUNCTION public.authenticate_user(p_email text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.authenticate_user(p_email text) TO dental_app;


--
-- Name: FUNCTION get_user_by_id(p_user_id text); Type: ACL; Schema: public; Owner: dental_auth
--

REVOKE ALL ON FUNCTION public.get_user_by_id(p_user_id text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.get_user_by_id(p_user_id text) TO dental_app;


--
-- Name: FUNCTION list_active_users(); Type: ACL; Schema: public; Owner: dental_auth
--

REVOKE ALL ON FUNCTION public.list_active_users() FROM PUBLIC;
GRANT ALL ON FUNCTION public.list_active_users() TO dental_app;


--
-- Name: FUNCTION tenants_owned_by(p_user_id text); Type: ACL; Schema: public; Owner: dental_auth
--

REVOKE ALL ON FUNCTION public.tenants_owned_by(p_user_id text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.tenants_owned_by(p_user_id text) TO dental_app;


--
-- Name: TABLE appeal_events; Type: ACL; Schema: public; Owner: dental_admin
--

GRANT SELECT,INSERT,UPDATE ON TABLE public.appeal_events TO dental_app;


--
-- Name: TABLE appeal_packets; Type: ACL; Schema: public; Owner: dental_admin
--

GRANT SELECT,INSERT,UPDATE ON TABLE public.appeal_packets TO dental_app;


--
-- Name: TABLE appointments; Type: ACL; Schema: public; Owner: dental_admin
--

GRANT SELECT,INSERT,UPDATE ON TABLE public.appointments TO dental_app;


--
-- Name: TABLE checkin_events; Type: ACL; Schema: public; Owner: dental_admin
--

GRANT SELECT,INSERT,UPDATE ON TABLE public.checkin_events TO dental_app;


--
-- Name: TABLE clinical_attestations; Type: ACL; Schema: public; Owner: dental_admin
--

GRANT SELECT,INSERT ON TABLE public.clinical_attestations TO dental_app;


--
-- Name: TABLE clinical_handoffs; Type: ACL; Schema: public; Owner: dental_admin
--

GRANT SELECT,INSERT,UPDATE ON TABLE public.clinical_handoffs TO dental_app;


--
-- Name: TABLE clinical_justifications; Type: ACL; Schema: public; Owner: dental_admin
--

GRANT SELECT,INSERT,UPDATE ON TABLE public.clinical_justifications TO dental_app;


--
-- Name: TABLE clinical_narratives; Type: ACL; Schema: public; Owner: dental_admin
--

GRANT SELECT,INSERT,UPDATE ON TABLE public.clinical_narratives TO dental_app;


--
-- Name: TABLE decision_outputs; Type: ACL; Schema: public; Owner: dental_admin
--

GRANT SELECT,INSERT,UPDATE ON TABLE public.decision_outputs TO dental_app;


--
-- Name: TABLE denial_events; Type: ACL; Schema: public; Owner: dental_admin
--

GRANT SELECT,INSERT,UPDATE ON TABLE public.denial_events TO dental_app;


--
-- Name: TABLE document_requests; Type: ACL; Schema: public; Owner: dental_admin
--

GRANT SELECT,INSERT,UPDATE ON TABLE public.document_requests TO dental_app;


--
-- Name: TABLE persona_bundles; Type: ACL; Schema: public; Owner: dental_admin
--

GRANT SELECT,INSERT,UPDATE ON TABLE public.persona_bundles TO dental_app;


--
-- Name: TABLE provider_feedback; Type: ACL; Schema: public; Owner: dental_admin
--

GRANT SELECT,INSERT,UPDATE ON TABLE public.provider_feedback TO dental_app;


--
-- Name: TABLE submission_events; Type: ACL; Schema: public; Owner: dental_admin
--

GRANT SELECT,INSERT,UPDATE ON TABLE public.submission_events TO dental_app;


--
-- Name: TABLE tenant_ownership; Type: ACL; Schema: public; Owner: dental_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.tenant_ownership TO dental_app;
GRANT SELECT ON TABLE public.tenant_ownership TO dental_auth;


--
-- Name: TABLE users; Type: ACL; Schema: public; Owner: dental_admin
--

GRANT SELECT,INSERT,UPDATE ON TABLE public.users TO dental_app;
GRANT SELECT ON TABLE public.users TO dental_auth;


--
-- PostgreSQL database dump complete
--


