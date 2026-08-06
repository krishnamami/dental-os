"""
PredContext — the dental equivalent of decision-os's LendingContext.

One object per pre-D. Assembled ONCE per HTTP request by
ContextBuilder, then passed to every persona. No persona makes a DB
call; everything it needs is already here (CONTEXT.md RULE 5).

Lifetime is one HTTP request, then it is garbage collected. It is NOT
the audit record — persona_bundles, written after each wave settles, is
what survives and what replay reads (RULE 10).

Nothing in this module writes. PredContext is assembled from
dental-simulator's computed state; the policy engine already decided,
and dental-os explains that decision rather than recomputing it.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Optional


# ─────────────────────────────────────────────────────────────────────
# Confidence labelling
# ─────────────────────────────────────────────────────────────────────
#
# Thresholds mirror the criteria-score bands in dental-simulator PRD
# section 11 and clinical_reviewer's boundary in decisions.yaml
# (0.85 recommend / 0.50-0.85 escalate / <0.30 block). These are LABELS
# for a human reading a screen — they are not the boundary evaluation,
# and nothing should branch on them.


def confidence_label(score: Optional[float]) -> str:
    """Map criteria_score to a human-readable confidence label."""
    if score is None:
        return "Not scored"
    if score >= 0.85:
        return "High confidence"
    if score >= 0.70:
        return "Likely to be approved"
    if score >= 0.50:
        return "Moderate confidence"
    if score >= 0.30:
        return "Likely to pend"
    return "High confidence denial"


def scenario_id_from_pred_request_id(pred_request_id: str) -> str:
    """PRED-SIM-DA-A01 -> DA-A01.

    The scenario id is what S3 keys are built from
    (suwanee_smiles/DA-A01/...), so this is not cosmetic. CONTEXT.md
    RULE 14: the PRED-DA-* form is the OLD deleted pipeline and must
    never be produced here.
    """
    if pred_request_id.startswith("PRED-SIM-"):
        return pred_request_id[len("PRED-SIM-"):]
    if pred_request_id.startswith("PRED-DA-"):
        raise ValueError(
            f"{pred_request_id!r} uses the OLD PRED-DA-* id format. That "
            f"pipeline run was deleted; rows still exist in the local "
            f"Postgres on :5434. Use PRED-SIM-DA-* (CONTEXT.md RULE 14)."
        )
    return pred_request_id


# ─────────────────────────────────────────────────────────────────────
# Sub-contexts
# ─────────────────────────────────────────────────────────────────────


@dataclass
class ProcedureLine:
    cdt_code: str
    tooth_number: Optional[int]
    tooth_surface: Optional[str]
    fee_submitted: float
    allowed_amount: Optional[float] = None
    insurance_pays: Optional[float] = None
    patient_pays: Optional[float] = None
    downgrade_applied: bool = False
    downgrade_from: Optional[str] = None
    line_no: Optional[int] = None
    quadrant: Optional[str] = None
    requires_pred: bool = False


@dataclass
class ClinicalEvidence:
    document_type: str
    s3_key: Optional[str]
    extracted_fields: dict
    confidence_score: float
    extraction_method: str
    received_at: Optional[str] = None
    evidence_id: Optional[str] = None

    # TRUST_FLOOR, not the extractors' AI_FALLBACK_FLOOR of 0.6.
    # See CONTEXT.md "Confidence Threshold Reference" and PRD Gap #5.
    TRUST_FLOOR: float = 0.70

    @property
    def below_trust_floor(self) -> bool:
        return self.confidence_score < self.TRUST_FLOOR


@dataclass
class EligibilityProfile:
    coverage_active: bool
    payer_id: str
    plan_type: str
    annual_maximum: float
    annual_max_remaining: float
    deductible_remaining: float
    benefit_pct_preventive: float
    benefit_pct_basic: float
    benefit_pct_major: float
    benefit_pct_implants: float
    implant_covered: bool
    waiting_period_met: bool
    missing_tooth_clause_triggered: bool
    coordination_of_benefits: bool
    # Tri-state on purpose. None means "no insurance card on file, so
    # the comparison could not be made" — which is NOT the same as
    # "the ids match". Only 10 of the 35 scenarios carry a card.
    # Collapsing None to False would report a clean check that never ran.
    member_id_mismatch: Optional[bool] = None


@dataclass
class PayerResponse:
    decision: str
    pred_number: Optional[str] = None
    approved_amount: Optional[float] = None
    denial_reason_code: Optional[str] = None
    denial_reason_text: Optional[str] = None
    appeal_deadline: Optional[str] = None
    pend_checklist: list = field(default_factory=list)
    policy_citation: Optional[str] = None


# ─────────────────────────────────────────────────────────────────────
# PredContext
# ─────────────────────────────────────────────────────────────────────


@dataclass
class PredContext:
    # ── Identity ─────────────────────────────────────────────────────
    pred_request_id: str
    tenant_id: str
    scenario_id: str
    patient_name: str
    provider_name: str
    provider_npi: str
    plan_name: str
    payer_id: str

    # ── Policy engine output — dental-simulator already decided ──────
    decision: str
    criteria_score: Optional[float]
    confidence_label: str
    has_bundling_conflict: bool
    open_conditions: list
    decision_trace: list
    medical_necessity_met: bool
    missing_evidence: list

    # ── Sub-contexts per persona ─────────────────────────────────────
    eligibility: Optional[EligibilityProfile] = None
    procedures: list[ProcedureLine] = field(default_factory=list)
    clinical_evidence: list[ClinicalEvidence] = field(default_factory=list)
    payer_response: Optional[PayerResponse] = None

    # ── Knowledge graph summary ──────────────────────────────────────
    confirms_count: int = 0
    contradicts_count: int = 0

    # ── Upstream persona outputs, populated as waves complete ────────
    upstream_outputs: dict = field(default_factory=dict)

    # ── Audit ────────────────────────────────────────────────────────
    audit_events: list = field(default_factory=list)

    # ── Catalogue rules, attached by ContextEnricher ─────────────────
    # Empty until enrich() runs. A persona reading this while empty is
    # a wiring bug, not a data gap — the enricher is the ONLY thing
    # that populates it (RULE 4), and personas never load rules
    # themselves (RULE 5).
    catalogue_rules: dict = field(default_factory=dict)

    # ── Convenience accessors ────────────────────────────────────────
    # Read-only derivations. A persona uses these instead of walking
    # the evidence list itself, so "where does bone_loss_mm come from"
    # has exactly one answer.

    @property
    def total_fee_submitted(self) -> float:
        return sum(p.fee_submitted or 0.0 for p in self.procedures)

    @property
    def total_patient_pays(self) -> float:
        return sum(p.patient_pays or 0.0 for p in self.procedures)

    @property
    def cdt_codes(self) -> list[str]:
        return [p.cdt_code for p in self.procedures]

    def evidence_of_type(self, document_type: str) -> list[ClinicalEvidence]:
        return [e for e in self.clinical_evidence if e.document_type == document_type]

    def extracted(self, key: str, document_type: Optional[str] = None) -> Any:
        """First non-null value of ``key`` across extracted_fields.

        Scoped to one document_type when given. Returns None rather than
        raising — a missing measurement is a normal state that
        documentation_reviewer is meant to surface, not an error.
        """
        pool = (
            self.evidence_of_type(document_type)
            if document_type
            else self.clinical_evidence
        )
        for ev in pool:
            value = (ev.extracted_fields or {}).get(key)
            if value is not None:
                return value
        return None

    @property
    def bone_loss_mm(self) -> Optional[float]:
        value = self.extracted("bone_loss_mm", "XRAY_PA")
        return None if value is None else float(value)

    @property
    def low_confidence_documents(self) -> list[ClinicalEvidence]:
        return [e for e in self.clinical_evidence if e.below_trust_floor]

    def summary(self) -> str:
        """One-line human summary, for logs and smoke tests."""
        return (
            f"{self.scenario_id} | {self.patient_name} | {self.decision} | "
            f"score={self.criteria_score} ({self.confidence_label}) | "
            f"{len(self.procedures)} procedures | "
            f"{len(self.clinical_evidence)} documents | "
            f"{len(self.open_conditions)} open conditions"
        )
