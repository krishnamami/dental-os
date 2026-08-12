/**
 * TypeScript mirrors of the dental-os API wire contract.
 *
 * Source of truth is `dental-os/api/schemas.py`. When that changes,
 * this changes — these are hand-maintained, not generated, so treat a
 * mismatch here as a bug in this file rather than in the API.
 *
 * Two conventions worth knowing before using them:
 *
 *   `mode` is only ever 'recommend' or 'human_approval'. There is no
 *   auto_execute in this domain — the policy engine already decided and
 *   the product explains that decision to a human. Do not add a third
 *   value to make a UI state fit; the API would reject it.
 *
 *   `data` on a Signal is deliberately untyped. Its keys differ per
 *   signal_code, and pinning them would turn every new signal into a
 *   breaking change here. Narrow it at the point of use.
 */

export type SignalMode = "recommend" | "human_approval";

/** The payer's verdict, from dental-simulator's policy engine. */
export type PayerDecision = "approved" | "denied" | "pended";

export type Role =
  | "front_desk"
  /** Treatment coordinator — owns the money conversation with the
   *  patient, between the front desk and the chair. */
  | "tx_coord"
  | "revenue_ops"
  | "dentist"
  | "dso_owner"
  | "accord_admin";

// ── Auth ─────────────────────────────────────────────────────────────

/** The `user` half of POST /auth/login, /auth/me and /auth/impersonate.
 *  tenant_id is null for accord_admin, who belongs to the platform
 *  rather than to a practice — so every consumer has to handle it. */
export interface AuthUser {
  user_id: string;
  email: string;
  name: string;
  role: Role;
  tenant_id: string | null;
  tenant_name: string | null;
  tenant_address: string | null;
}

/** What the admin console hands to impersonate(). A subset of AuthUser
 *  on purpose: it is built from GET /auth/users, which does not return
 *  the tenant's display name. */
export interface ImpersonatedUser {
  user_id: string;
  name: string;
  role: Role;
  tenant_id: string | null;
}

export interface Signal {
  signal_code: string;
  finding: string;
  mode: SignalMode;
  decision_id: string;
  wave: number;
  owner_team?: string;
  risk_level?: string;
  citation?: string;
  payer_citation?: string;
  recommended_action?: string;
  sla_hours?: number;
  assignee?: string;
  data: Record<string, unknown>;
}

export interface DecisionOutput {
  decision_id: string;
  wave: number;
  mode: SignalMode;
  outcome?: "recommend" | "escalate" | "block";
  signals: Signal[];
}

export interface Decision {
  pred_request_id: string;
  patient_name: string;
  provider_name: string;
  plan_name: string;
  payer_id: string;
  state: string;

  decision: PayerDecision;
  criteria_score: number | null;
  confidence_label: string;
  submission_ready: boolean;

  /** Keyed "1".."5". Object keys are strings in JSON. */
  waves: Record<string, DecisionOutput[]>;
  all_signals: Signal[];
  open_conditions: string[];
  bundle_id: string;
  processed_at?: string;
  /** True when this request ran the personas instead of reading rows. */
  computed?: boolean;

  /**
   * The engine's 14 readiness booleans, straight from
   * pred_states.readiness_flags. Keys are dental-simulator's names —
   * see READINESS_LABELS for the prose.
   *
   * null means the engine has not scored this pre-D. That is NOT the
   * same as every flag failing, and the checklist renders it
   * differently.
   */
  readiness_flags: Record<string, boolean> | null;
  /** Counted from readiness_flags. There is no engine score column. */
  readiness_met: number | null;
  readiness_total: number | null;
  readiness_score: number | null;
}

// ── Conditions queue ─────────────────────────────────────────────────

export interface Condition {
  signal_code: string;
  finding: string;
  mode: SignalMode;
  category?: string;
  citation?: string;
  payer_citation?: string;
  recommended_action?: string;
  sla_hours?: number;
  assignee?: string;
  wave?: number;
  decision_id?: string;
  data: Record<string, unknown>;
}

export interface ConditionsResponse {
  pred_request_id: string;
  patient_name: string;
  decision: PayerDecision;
  submission_ready: boolean;
  conditions: Condition[];
  conditions_count: number;
  /** mode === 'human_approval' — needs a signature. */
  blocking_count: number;
  /** mode === 'recommend' — needs a task. */
  advisory_count: number;
}

// ── Patient summary ──────────────────────────────────────────────────

export interface ProcedureCost {
  cdt_code: string;
  description?: string;
  tooth_number?: number | null;
  provider_ucr_fee: number;
  in_network_discount: number;
  contracted_rate: number;
  deductible_applied: number;
  insurance_pays: number;
  patient_pays: number;
  downgrade_applied: boolean;
  downgrade_note?: string | null;
  pre_d_required: boolean;
  covered: boolean;
  not_covered_reason?: string | null;
  /** Rate is an estimate, not the payer's published allowed amount. */
  rate_is_estimated?: boolean;
}

export interface CostSummary {
  total_provider_charges: number;
  total_in_network_savings: number;
  total_contracted: number;
  total_deductible_applied: number;
  total_insurance_pays: number;
  total_patient_pays: number;
  annual_max_remaining_after: number;
  annual_max_exhausted: boolean;
}

export interface PatientSummary {
  pred_request_id: string;
  patient_name: string;
  provider_name: string;
  plan_name: string;
  payer_id: string;
  state: string;
  valid_through?: string | null;
  annual_max_remaining_before: number;
  deductible_remaining_before: number;
  procedures: ProcedureCost[];
  summary: CostSummary;
  notes: string[];
  /** Anything the estimate could not read. Show these — a patient-facing
   *  number with a silent gap behind it is the failure this prevents. */
  caveats: string[];
}

// ── Appeal ───────────────────────────────────────────────────────────

export interface EvidenceItem {
  document_type: string;
  /**
   * What a document is named by. NOT the bucket key — the API stopped
   * returning s3_key entirely, because no client is permitted to send
   * one back and shipping it only put a guessable object path into
   * every response body, cache and log. Resolve it through
   * GET /decisions/:pred/documents/:evidence_id, which presigns for
   * five minutes after checking role and tenant.
   */
  evidence_id?: string | null;
  /** False for the structured payloads — there is no file to open. */
  has_document?: boolean;
  description?: string | null;
  confidence?: number | null;
}

export interface DocumentUrl {
  url: string;
  filename: string;
  document_type: string;
  expires_in: number;
}

export interface Citation {
  source: string;
  section?: string | null;
  text?: string | null;
}

export interface Appeal {
  pred_request_id: string;
  patient_name: string;
  payer_id: string;
  pred_number?: string | null;
  decision: PayerDecision;
  denial_reason_code?: string | null;
  denial_reason_text?: string | null;
  appeal_deadline?: string | null;
  days_remaining?: number | null;
  deadline_warning: boolean;
  viable: boolean;
  success_probability?: number | null;
  appeal_strategy?: string | null;
  /** Assembled from catalogue rows, never generated. Always a draft. */
  appeal_letter_text?: string | null;
  appeal_letter_is_draft: boolean;
  evidence_list: EvidenceItem[];
  citations: Citation[];
  missing_evidence: string[];
  not_viable_reason?: string | null;
}

// ── Portfolio (DSO) ──────────────────────────────────────────────────

export interface Practice {
  tenant_id: string;
  practice_name: string;
  address: string;
  total_pre_ds: number;
  approved: number;
  denied: number;
  pended: number;
  approval_rate: number;
  avg_criteria_score: number;
  total_contracted: number;
  total_insurance_pays: number;
  total_patient_pays: number;
  cost_estimates_available: boolean;
}

export interface DenialReason {
  condition_code: string;
  tenant_id: string;
  frequency: number;
}

/**
 * One row per (practice, payer). Counts only — the API deliberately
 * ships no computed rate, because most cells here are one or two
 * pre-Ds and a percentage off two cases looks authoritative and means
 * very little. The screen honours that and does not compute one either.
 */
export interface PayerPerformance {
  tenant_id: string;
  payer_id: string;
  payer_name: string;
  total: number;
  approved: number;
  denied: number;
}

export interface Portfolio {
  summary: {
    total_practices: number;
    total_pre_ds: number;
    total_approved: number;
    total_denied: number;
    total_pended: number;
    overall_approval_rate: number;
    total_patient_responsibility: number;
    total_patient_revenue_at_risk: number;
    practices_missing_cost_estimates: string[];
  };
  practices: Practice[];
  top_denial_reasons: DenialReason[];
  payer_performance: PayerPerformance[];
  generated_at: string;
}

// ── Feedback ─────────────────────────────────────────────────────────

export type FeedbackType = "accepted" | "overridden" | "false_positive";

export interface FeedbackRequest {
  decision_id: string;
  signal_code: string;
  feedback_type: FeedbackType;
  notes?: string | null;
  /** A role, never a named individual. */
  submitted_by: "front_desk" | "billing" | "dentist" | "dso_manager";
}

export interface FeedbackResponse {
  feedback_id: string;
  pred_request_id: string;
  decision_id: string;
  signal_code: string;
  feedback_type: string;
  received_at: string;
  expires_at?: string | null;
}

// ── Health ───────────────────────────────────────────────────────────

export interface Health {
  status: string;
  service: string;
  version: string;
  tenants?: number | null;
  simulator_scenarios?: number | null;
  decision_outputs?: number | null;
  persona_bundles?: number | null;
  payers_supported?: number | null;
  states_supported?: number | null;
  simulator_db: string;
  os_db: string;
}


// ── Document access audit (dental-os migrations/013) ─────────────────

export interface DocumentAccessEvent {
  access_id: number;
  evidence_id: string;
  document_type: string;
  document_label: string;
  access_type: "presign" | "view" | "download";
  user_id: string;
  user_name: string | null;
  user_role: string;
  occurred_at: string;
  url_expires_at: string | null;
}

export interface RequiredDocumentReview {
  evidence_id: string;
  document_type: string;
  document_label: string;
  reviewed: boolean;
  reviewed_at: string | null;
  reviewed_by: string | null;
}

export interface DocumentAccess {
  pred_request_id: string;
  total_accesses: number;
  submitted_at: string | null;
  /**
   * null when the case has not been filed — "no gap yet" is a different
   * answer from "reviewed in time", and the screen says different
   * things about them.
   */
  audit_complete: boolean | null;
  required_documents: RequiredDocumentReview[];
  events: DocumentAccessEvent[];
}
