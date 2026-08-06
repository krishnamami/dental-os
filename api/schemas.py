"""
T-33..T-37 — response models for the dental-os API.

These are the wire contract. They exist so a caller can rely on a shape
rather than on whatever a persona happened to put in `data` this run —
`data` is deliberately typed `dict` and deliberately NOT flattened,
because its keys differ per signal and pinning them here would turn
every new signal into a schema migration.

Money is `float` throughout rather than Decimal. Every number on these
endpoints has already been rounded to cents by coverage_resolver, and
JSON has no decimal type, so a Decimal would serialise to a string and
push the parsing problem onto the caller.
"""
from __future__ import annotations

from typing import Any, Literal, Optional

from pydantic import BaseModel, Field

FeedbackType = Literal["accepted", "overridden", "false_positive"]
SubmittedBy = Literal["front_desk", "billing", "dentist", "dso_manager"]


# ─────────────────────────────────────────────────────────────────────
# Shared
# ─────────────────────────────────────────────────────────────────────


class Signal(BaseModel):
    """One persona finding. Mirrors DentalPersona.make_signal()."""

    signal_code: str
    finding: str
    mode: str
    decision_id: Optional[str] = None
    wave: Optional[int] = None
    owner_team: Optional[str] = None
    risk_level: Optional[str] = None
    citation: Optional[str] = None
    payer_citation: Optional[str] = None
    recommended_action: Optional[str] = None
    sla_hours: Optional[int] = None
    assignee: Optional[str] = None
    data: dict[str, Any] = Field(default_factory=dict)


class DecisionOutput(BaseModel):
    """One persona's whole output, as stored in decision_outputs."""

    decision_id: str
    wave: int
    mode: str
    outcome: Optional[str] = None
    signals: list[Signal] = Field(default_factory=list)


# ─────────────────────────────────────────────────────────────────────
# T-33 — GET /decisions/{id}
# ─────────────────────────────────────────────────────────────────────


class DecisionBundleResponse(BaseModel):
    pred_request_id: str
    patient_name: str
    provider_name: str
    plan_name: str
    payer_id: str
    state: str

    decision: str
    criteria_score: Optional[float] = None
    confidence_label: str
    submission_ready: bool

    # Keyed "1".."5" — JSON object keys are strings, and a caller
    # iterating waves in order wants them stable, not renumbered when a
    # wave produces nothing.
    waves: dict[str, list[DecisionOutput]] = Field(default_factory=dict)

    all_signals: list[Signal] = Field(default_factory=list)
    open_conditions: list[str] = Field(default_factory=list)
    bundle_id: Optional[str] = None
    processed_at: Optional[str] = None
    # True when this request ran the personas rather than reading rows
    # that already existed. Lets a caller tell a 40ms read from a 2s run.
    computed: bool = False


# ─────────────────────────────────────────────────────────────────────
# T-34 — GET /decisions/{id}/conditions
# ─────────────────────────────────────────────────────────────────────


class Condition(BaseModel):
    signal_code: str
    finding: str
    mode: str
    category: Optional[str] = None       # coverage | clinical | provider | …
    citation: Optional[str] = None
    payer_citation: Optional[str] = None
    recommended_action: Optional[str] = None
    sla_hours: Optional[int] = None
    assignee: Optional[str] = None
    wave: Optional[int] = None
    decision_id: Optional[str] = None
    data: dict[str, Any] = Field(default_factory=dict)


class ConditionsResponse(BaseModel):
    pred_request_id: str
    patient_name: str
    decision: str
    submission_ready: bool
    conditions: list[Condition] = Field(default_factory=list)
    conditions_count: int
    blocking_count: int      # mode == human_approval
    advisory_count: int      # mode == recommend


# ─────────────────────────────────────────────────────────────────────
# T-35 — GET /decisions/{id}/appeal
# ─────────────────────────────────────────────────────────────────────


class EvidenceItem(BaseModel):
    document_type: str
    s3_key: Optional[str] = None
    description: Optional[str] = None
    confidence: Optional[float] = None


class Citation(BaseModel):
    source: str
    section: Optional[str] = None
    text: Optional[str] = None


class AppealResponse(BaseModel):
    pred_request_id: str
    patient_name: str
    payer_id: str
    pred_number: Optional[str] = None
    decision: str
    denial_reason_code: Optional[str] = None
    denial_reason_text: Optional[str] = None
    appeal_deadline: Optional[str] = None
    days_remaining: Optional[int] = None
    deadline_warning: bool = False

    viable: bool
    success_probability: Optional[float] = None
    appeal_strategy: Optional[str] = None

    # A DRAFT assembled from catalogue rows — never a generated letter.
    # See the note in routes.build_appeal_letter.
    appeal_letter_text: Optional[str] = None
    appeal_letter_is_draft: bool = True
    evidence_list: list[EvidenceItem] = Field(default_factory=list)
    citations: list[Citation] = Field(default_factory=list)
    missing_evidence: list[str] = Field(default_factory=list)

    not_viable_reason: Optional[str] = None


# ─────────────────────────────────────────────────────────────────────
# T-36 — GET /decisions/{id}/patient-summary
# ─────────────────────────────────────────────────────────────────────


class PatientProcedure(BaseModel):
    cdt_code: str
    description: Optional[str] = None
    tooth_number: Optional[int] = None
    provider_ucr_fee: float
    in_network_discount: float
    contracted_rate: float
    deductible_applied: float
    insurance_pays: float
    patient_pays: float
    downgrade_applied: bool = False
    downgrade_note: Optional[str] = None
    pre_d_required: bool = False
    covered: bool = True
    not_covered_reason: Optional[str] = None
    # The rate is an estimate, not the payer's published allowed amount.
    # Surfaced because this page is handed to a patient.
    rate_is_estimated: bool = False


class PatientSummaryTotals(BaseModel):
    total_provider_charges: float
    total_in_network_savings: float
    total_contracted: float
    total_deductible_applied: float
    total_insurance_pays: float
    total_patient_pays: float
    annual_max_remaining_after: float
    annual_max_exhausted: bool


class PatientSummaryResponse(BaseModel):
    pred_request_id: str
    patient_name: str
    provider_name: str
    plan_name: str
    payer_id: str
    state: str
    valid_through: Optional[str] = None

    annual_max_remaining_before: float
    deductible_remaining_before: float

    procedures: list[PatientProcedure] = Field(default_factory=list)
    summary: PatientSummaryTotals
    notes: list[str] = Field(default_factory=list)
    # Anything the estimate could not read. RULE 11 — a patient-facing
    # number with a silent gap behind it is the failure mode this
    # product exists to prevent.
    caveats: list[str] = Field(default_factory=list)


# ─────────────────────────────────────────────────────────────────────
# T-37 — POST /decisions/{id}/feedback
# ─────────────────────────────────────────────────────────────────────


class FeedbackRequest(BaseModel):
    decision_id: str
    signal_code: str
    feedback_type: FeedbackType
    notes: Optional[str] = None
    # A ROLE, never a named individual — provider_feedback carries a
    # CHECK constraint to the same four values.
    submitted_by: SubmittedBy


class FeedbackResponse(BaseModel):
    feedback_id: str
    pred_request_id: str
    decision_id: str
    signal_code: str
    feedback_type: str
    received_at: str
    expires_at: Optional[str] = None


# ─────────────────────────────────────────────────────────────────────
# GET /health
# ─────────────────────────────────────────────────────────────────────


class HealthResponse(BaseModel):
    status: str
    service: str
    version: str
    simulator_scenarios: Optional[int] = None
    decision_outputs: Optional[int] = None
    persona_bundles: Optional[int] = None
    simulator_db: str
    os_db: str
