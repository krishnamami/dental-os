/**
 * dental-os API access. One axios client, one query key convention.
 *
 * Every path goes through "/api", which vite.config.ts proxies to
 * localhost:9010 in development. No component may hardcode a host —
 * that is what lets the same build run against a local API, a staging
 * one, or CloudFront without a rebuild.
 */
import axios from "axios";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";

import type {
  Appeal,
  ConditionsResponse,
  Decision,
  FeedbackRequest,
  FeedbackResponse,
  Health,
  PatientSummary,
  Portfolio,
} from "../types/dental";

export const api = axios.create({
  baseURL: "/api",
  timeout: 60_000,
  headers: { "Content-Type": "application/json" },
});

/** Where AuthContext keeps the token. Duplicated as a literal rather
 *  than imported, because AuthContext imports THIS module — and an
 *  interceptor that only registers when the context happens to have
 *  been loaded is a request that silently goes out unauthenticated. */
const TOKEN_KEY = "accord_dental_token";

/**
 * Every request carries whatever credential this tab has.
 *
 * A signed-in tab sends its bearer token. A ?demo=true visitor has no
 * token and sends X-Demo-Mode instead, which the API accepts for READS
 * of the suwanee_smiles corpus only — see require_claims_or_demo in
 * dental-os. Sending neither now means 401 on every data route, which
 * is the point of the change this belongs to.
 *
 * isDemo is read from the URL rather than from useDemo(): an axios
 * interceptor is not a component and cannot call a hook. Same source
 * of truth, same parsing rule — presence counts, only an explicit
 * ?demo=false turns it off.
 */
api.interceptors.request.use((config) => {
  try {
    const token = window.localStorage.getItem(TOKEN_KEY);
    if (token) config.headers.Authorization = `Bearer ${token}`;
  } catch {
    // Safari private mode. Fall through to demo/anonymous.
  }
  const raw = new URLSearchParams(window.location.search).get("demo");
  if (raw !== null && raw !== "false" && raw !== "0") {
    config.headers["X-Demo-Mode"] = "true";
  }
  return config;
});

/**
 * FastAPI puts its message in `detail`. Surfacing that instead of
 * axios's generic "Request failed with status code 404" is the
 * difference between "not found" and "this pre-D is approved, so there
 * is nothing to appeal" — the API writes useful 404s and throwing them
 * away would waste them.
 */
export class ApiError extends Error {
  // Declared and assigned explicitly rather than as a constructor
  // parameter property: this template sets `erasableSyntaxOnly`, which
  // rejects any TypeScript that is not pure type annotation.
  status?: number;

  constructor(message: string, status?: number) {
    super(message);
    this.name = "ApiError";
    this.status = status;
  }
}

/**
 * Reject a 200 that is not JSON.
 *
 * ⚠ THIS IS THE IMPORTANT ONE. In production `/api/*` is not routed
 * anywhere: it misses in S3, CloudFront's SPA fallback catches the 404
 * and serves **index.html with status 200**. axios sees a success, and
 * every hook resolves with a string of HTML where a Decision should be.
 *
 * The damage is not a network error — it is worse. `isError` stays
 * false, `data` is truthy, and the first `data.something.length` in any
 * component throws "Cannot read properties of undefined". Every page's
 * carefully written error branch is skipped, because as far as React
 * Query is concerned the request succeeded.
 *
 * Turning it back into an ApiError means the SPA fallback can no longer
 * impersonate the API, and the error states that already exist do their
 * job.
 */
function assertJson<T>(path: string, data: unknown, contentType: unknown): T {
  const type = typeof contentType === "string" ? contentType : "";
  if (typeof data === "string" || (type && !type.includes("json"))) {
    throw new ApiError(
      `GET ${path} returned ${type || "a non-JSON body"} instead of JSON. ` +
        "The API is not reachable from this origin — in production /api " +
        "is not routed to dental-os, so the SPA fallback answers instead.",
      502,
    );
  }
  return data as T;
}

async function get<T>(path: string): Promise<T> {
  try {
    const res = await api.get<T>(path);
    return assertJson<T>(path, res.data, res.headers?.["content-type"]);
  } catch (err) {
    if (axios.isAxiosError(err)) {
      const detail = (err.response?.data as { detail?: string } | undefined)
        ?.detail;
      throw new ApiError(detail ?? err.message, err.response?.status);
    }
    throw err;
  }
}

/** Query keys, in one place so invalidation cannot miss one. */
export const keys = {
  health: ["health"] as const,
  decision: (id: string) => ["decision", id] as const,
  conditions: (id: string) => ["conditions", id] as const,
  patientSummary: (id: string) => ["patient-summary", id] as const,
  appeal: (id: string) => ["appeal", id] as const,
  portfolio: ["portfolio"] as const,
  submitted: (date: string) => ["submissions", date] as const,
  denials: ["denials"] as const,
  appeals: ["appeals"] as const,
  billingAnalytics: ["analytics", "billing"] as const,
  clinicalQueue: (date: string) => ["clinical-queue", date] as const,
  clinical: (id: string) => ["clinical", id] as const,
  appealEvidence: (id: string) => ["appeal-evidence", id] as const,
};

// A pre-D's decision bundle never changes unless someone forces a
// re-run, so it is worth caching hard. The portfolio moves with every
// new case, so it is not.
const STABLE = { staleTime: 5 * 60_000, refetchOnWindowFocus: false };

export function useHealth() {
  return useQuery({
    queryKey: keys.health,
    queryFn: () => get<Health>("/health"),
    refetchInterval: 60_000,
  });
}

export function useDecision(predRequestId?: string) {
  return useQuery({
    queryKey: keys.decision(predRequestId ?? ""),
    queryFn: () => get<Decision>(`/decisions/${predRequestId}`),
    enabled: Boolean(predRequestId),
    ...STABLE,
  });
}

export function useConditions(predRequestId?: string) {
  return useQuery({
    queryKey: keys.conditions(predRequestId ?? ""),
    queryFn: () => get<ConditionsResponse>(`/decisions/${predRequestId}/conditions`),
    enabled: Boolean(predRequestId),
    ...STABLE,
  });
}

export function usePatientSummary(predRequestId?: string) {
  return useQuery({
    queryKey: keys.patientSummary(predRequestId ?? ""),
    queryFn: () => get<PatientSummary>(`/decisions/${predRequestId}/patient-summary`),
    enabled: Boolean(predRequestId),
    ...STABLE,
  });
}

/**
 * 404 is a VALID answer here, not a failure: an approved pre-D has
 * nothing to appeal. Retrying it would be pure latency, so don't.
 */
export function useAppeal(predRequestId?: string) {
  return useQuery({
    queryKey: keys.appeal(predRequestId ?? ""),
    queryFn: () => get<Appeal>(`/decisions/${predRequestId}/appeal`),
    enabled: Boolean(predRequestId),
    retry: (count, error) =>
      error instanceof ApiError && error.status === 404 ? false : count < 2,
    ...STABLE,
  });
}

export function usePortfolio() {
  return useQuery({
    queryKey: keys.portfolio,
    queryFn: () => get<Portfolio>("/portfolio/summary"),
    staleTime: 60_000,
  });
}

// ── Billing tracking (dental-os migrations/003) ────────────────────
//
// These four read tables that did not exist a week ago. Everything
// they return is a RECORDED EVENT — a submission logged, a denial
// entered, an appeal filed — not a prediction. useAppeal() above is
// the other thing: the engine's view of whether an appeal WOULD be
// viable. Both are useful and they are not interchangeable.

export interface SubmissionRow {
  submission_id: string;
  pred_request_id: string;
  patient_name: string;
  payer_name: string;
  submitted_at: string;
  status: string;
  expected_response_days: number;
  submission_method: string;
  submission_ref: string | null;
}

export interface DenialRow {
  denial_id: string;
  pred_request_id: string;
  patient_name: string;
  payer_id: string;
  payer_name: string;
  denied_at: string;
  denial_reason: string | null;
  denial_reason_code: string | null;
  denied_amount: number | null;
  appeal_deadline: string | null;
  appeal_viable: boolean;
  appeal_probability: number | null;
  days_to_deadline: number | null;
  appeal_filed: boolean;
  notes: string | null;
}

export interface AppealRow {
  appeal_id: string;
  pred_request_id: string;
  patient_name: string;
  payer_id: string;
  payer_name: string;
  filed_at: string;
  appeal_type: string;
  status: string;
  resolved_at: string | null;
  /** null while unresolved — NOT zero. */
  recovered_amount: number | null;
  denial_reason: string | null;
  denied_amount: number | null;
  appeal_probability: number | null;
  appeal_deadline: string | null;
  days_to_deadline: number | null;
  notes: string | null;
}

export interface BillingAnalytics {
  submissions: {
    total: number;
    pending: number;
    acknowledged: number;
    responded: number;
  };
  denials: {
    total: number;
    amount: number;
    appeal_viable: number;
    reasons: Array<{ reason: string | null; count: number; amount: number }>;
  };
  appeals: {
    total: number;
    overturned: number;
    upheld: number;
    pending: number;
    recovered: number;
    /** null until at least one appeal has resolved. */
    overturn_rate: number | null;
  };
  cases: {
    total: number;
    approved: number;
    denied: number;
    pended: number;
    total_value: number;
  };
}

// ── The dentist's workbench (dental-os migrations/004 + 005) ───────

export interface ClinicalSignal {
  signal_code: string;
  finding: string | null;
  mode: string;
  wave: number;
  owner_team: string | null;
  assignee: string | null;
  risk_level: string | null;
  citation: string | null;
  payer_citation: string | null;
  recommended_action: string | null;
  sla_hours: number | null;
  /** The engine is not asking for anything on this one. */
  satisfied: boolean;
  justification: string | null;
  justified_at: string | null;
  document_requested: boolean;
}

export interface ClinicalBucket {
  key: "clinical_support" | "documentation_gaps" | "payer_friction" | "integrity_provider";
  label: string;
  open: number;
  signals: ClinicalSignal[];
}

export interface ClinicalView {
  pred_request_id: string;
  patient_name: string | null;
  decision: string | null;
  submission_ready: boolean;
  status_rollup: Array<{
    signal_code: string;
    finding: string | null;
    mode: string;
    risk_level: string | null;
  }>;
  buckets: ClinicalBucket[];
  unbucketed: string[];
  procedures: Array<{
    line_no: number;
    cdt_code: string;
    tooth_number: number | null;
    description: string | null;
    fee: number;
    requires_pred: boolean;
    ada_citation: string | null;
  }>;
  evidence: Array<{
    document_type: string;
    document_category: string | null;
    tooth_number: number | null;
    confidence_score: number;
    received_at: string | null;
  }>;
  narrative: {
    draft: string | null;
    /** Why there is nothing to edit, when there is no draft. */
    no_draft_reason: string | null;
    saved: string | null;
    source: string | null;
    updated_at: string | null;
  };
  document_requests: Array<{
    request_id: string;
    document_type: string;
    signal_code: string | null;
    status: string;
    note: string | null;
    requested_at: string | null;
  }>;
  requested_types: string[];
  attestation: {
    attestation_id: string;
    attested_by: string;
    attested_at: string | null;
    statement: string;
  } | null;
}

/** The morning, already filtered to the cases that want a clinician. */
export function useClinicalQueue(date: string) {
  return useQuery({
    queryKey: keys.clinicalQueue(date),
    queryFn: () =>
      get<QueueRowLite[]>(
        `/decisions/queue?date=${encodeURIComponent(date)}&needs_clinician=true`,
      ),
    staleTime: 30_000,
  });
}

export interface QueueRowLite {
  id: string;
  patient: string;
  finding: string;
  charges: number;
  payer: string;
  payer_id: string;
  status: string;
  open: number;
  blocking: number;
  submission_ready: boolean;
  created_at?: string | null;
  needs_clinician: boolean;
  needs_reason: string | null;
  handoff: {
    handoff_id: string;
    from_user: string;
    message: string;
    to_role: string;
    created_at: string | null;
  } | null;
  cleared_count: number;
}

export function useClinical(predRequestId?: string) {
  return useQuery({
    queryKey: keys.clinical(predRequestId ?? ""),
    queryFn: () => get<ClinicalView>(`/decisions/${predRequestId}/clinical`),
    enabled: Boolean(predRequestId),
    staleTime: 30_000,
  });
}

export function useSubmittedOn(date: string) {
  return useQuery({
    queryKey: keys.submitted(date),
    queryFn: () =>
      get<SubmissionRow[]>(
        `/decisions/submitted?date=${encodeURIComponent(date)}`,
      ),
    staleTime: 30_000,
  });
}

export function useDenials() {
  return useQuery({
    queryKey: keys.denials,
    queryFn: () => get<DenialRow[]>("/denials"),
    staleTime: 60_000,
  });
}

export function useAppeals() {
  return useQuery({
    queryKey: keys.appeals,
    queryFn: () => get<AppealRow[]>("/appeals"),
    staleTime: 60_000,
  });
}

export interface AppealEvidenceItem {
  kind:
    | "document"
    | "clinical_justification"
    | "clinical_narrative"
    | "attestation"
    | "gap";
  key: string;
  label: string;
  present: boolean;
  /** The clinician's actual wording, for the expander. */
  detail: string | null;
  signal_code?: string | null;
  confidence: number | null;
  s3_key: string | null;
  recorded_at: string | null;
  recorded_by: string | null;
  author_role?: string | null;
}

export interface AppealEvidence {
  appeal_id: string;
  pred_request_id: string;
  patient_name: string;
  status: string;
  denial_reason: string | null;
  appeal_probability: number | null;
  filed_at: string | null;
  evidence: AppealEvidenceItem[];
  present_count: number;
  missing_count: number;
  /** Has a clinician put their reasoning on the record for this case? */
  has_clinical_necessity: boolean;
}

export function useAppealEvidence(appealId?: string) {
  return useQuery({
    queryKey: keys.appealEvidence(appealId ?? ""),
    queryFn: () => get<AppealEvidence>(`/appeals/${appealId}/evidence`),
    enabled: Boolean(appealId),
    // Short: the whole point is that a dentist writing a justification
    // shows up on Kim's screen without a redeploy or a hard refresh.
    staleTime: 15_000,
  });
}

export function useBillingAnalytics() {
  return useQuery({
    queryKey: keys.billingAnalytics,
    queryFn: () => get<BillingAnalytics>("/analytics/billing"),
    staleTime: 60_000,
  });
}

/**
 * Human verdict on one signal. Invalidates the conditions queue so the
 * item the user just actioned stops staring at them.
 */
export function useSubmitFeedback(predRequestId?: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (body: FeedbackRequest) => {
      const { data } = await api.post<FeedbackResponse>(
        `/decisions/${predRequestId}/feedback`,
        body,
      );
      return data;
    },
    onSuccess: () => {
      if (predRequestId) {
        qc.invalidateQueries({ queryKey: keys.conditions(predRequestId) });
      }
    },
  });
}
