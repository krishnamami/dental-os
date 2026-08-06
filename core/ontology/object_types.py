"""
Dental ontology — object-type descriptors for the Accord Dental domain.

This is a REFERENCE IMPLEMENTATION, the same shape as decision-os
core/ontology/object_types.py. It is NOT enforced at runtime: the
context views in migrations/001_context_views.sql are what actually
gate which persona sees which columns. What this module gives you is a
single Python-side statement of:

  - which dental-simulator table each entity comes from
  - which of the 9 decisions may read it
  - what its properties are, and their types
  - how the entities link to each other, and what those links mean

Class-level defaults mirror domains/dental/knowledge_base.json, so a
resolver in either direction (json <-> python) is straightforward. Every
property name here was read off the live RDS on 2026-08-05, not
transcribed from a PRD — where the two disagreed, the database won.

RULE 15: dental_os_writes is False on all eight. These are dental-simulator's
tables. dental-os reads them and never writes them.
"""
from __future__ import annotations

from enum import Enum
from typing import Any, Optional

from pydantic import BaseModel, Field


# ─────────────────────────────────────────────────────────────────────
# Link primitives
# ─────────────────────────────────────────────────────────────────────


class Cardinality(str, Enum):
    ONE_TO_ONE = "one_to_one"
    ONE_TO_MANY = "one_to_many"
    MANY_TO_ONE = "many_to_one"
    MANY_TO_MANY = "many_to_many"
    ONE_TO_ONE_OPTIONAL = "one_to_one_optional"


class LinkDirection(str, Enum):
    OUTBOUND = "outbound"
    INBOUND = "inbound"
    SELF_REFERENTIAL = "self_referential"


class Link(BaseModel):
    name: str
    target: str
    cardinality: Cardinality
    direction: LinkDirection = LinkDirection.OUTBOUND
    semantic_meaning: str


# How many edges of a given cardinality may exit a single source instance.
# Cardinality is read source->target: one_to_many means one source has many targets.
_MAX_LINKS_PER_SOURCE: dict[Cardinality, float] = {
    Cardinality.ONE_TO_ONE: 1,
    Cardinality.ONE_TO_ONE_OPTIONAL: 1,
    Cardinality.MANY_TO_ONE: 1,
    Cardinality.ONE_TO_MANY: float("inf"),
    Cardinality.MANY_TO_MANY: float("inf"),
}


# ─────────────────────────────────────────────────────────────────────
# Base DentalObjectType
# ─────────────────────────────────────────────────────────────────────


class DentalObjectType(BaseModel):
    """Descriptor for one dental business object type.

    A subclass per entity sets the class-level defaults. Instances are
    reusable singletons the rest of the system queries for schema, link
    semantics, and decision-aware projections.
    """

    object_type_id: str
    display_name: str = ""
    semantic_definition: str = ""
    primary_key: str
    source_table: str
    source_repo: str = "dental-simulator"
    dental_os_reads: bool = True
    dental_os_writes: bool = False
    context_view: Optional[str] = None
    properties: dict[str, str] = Field(default_factory=dict)
    links: list[Link] = Field(default_factory=list)
    decisions_that_read_it: list[str] = Field(default_factory=list)

    # ── Decision-aware projection ────────────────────────────────────

    def to_context_bundle(
        self,
        instance: dict[str, Any],
        decision_id: str,
        fields: Optional[list[str]] = None,
    ) -> dict[str, Any]:
        """Project a stored instance down to only the fields a given
        decision is authorized to read.

        Refuses to project for a decision not listed in
        ``decisions_that_read_it`` — least privilege at the data layer
        rather than relying on persona good behaviour.
        """
        if decision_id not in self.decisions_that_read_it:
            raise PermissionError(
                f"decision {decision_id!r} does not read object type "
                f"{self.object_type_id!r}"
            )

        if fields is None:
            fields = list(self.properties.keys())

        unknown = [f for f in fields if f not in self.properties]
        if unknown:
            raise KeyError(f"unknown fields for {self.object_type_id!r}: {unknown}")

        bundle = {f: instance.get(f) for f in fields}
        bundle["_object_type"] = self.object_type_id
        bundle["_primary_key"] = instance.get(self.primary_key)
        bundle["_decision_id"] = decision_id
        return bundle

    # ── Link validation ──────────────────────────────────────────────

    def link(self, name: str) -> Link:
        for link in self.links:
            if link.name == name:
                return link
        raise KeyError(
            f"no link {name!r} on {self.object_type_id!r}; "
            f"defined: {[l.name for l in self.links]}"
        )

    def validate_link(self, name: str, existing_link_count: int = 0) -> Link:
        """Confirm one more outgoing edge of ``name`` would not exceed
        the link's cardinality. Returns the Link on success."""
        link = self.link(name)
        if existing_link_count < 0:
            raise ValueError("existing_link_count must be >= 0")

        max_allowed = _MAX_LINKS_PER_SOURCE[link.cardinality]
        if existing_link_count + 1 > max_allowed:
            raise ValueError(
                f"cardinality {link.cardinality.value} on "
                f"{self.object_type_id}.{name} allows at most "
                f"{int(max_allowed)} edge(s) per source; already at "
                f"{existing_link_count}"
            )
        return link


# ─────────────────────────────────────────────────────────────────────
# The 9 decisions, for reference in decisions_that_read_it
# ─────────────────────────────────────────────────────────────────────

ALL_DECISIONS: list[str] = [
    "eligibility_analyst",
    "provider_credentialing",
    "fraud_integrity",
    "coverage_analyst",
    "clinical_reviewer",
    "documentation_reviewer",
    "pre_d_assessment",
    "appeal_specialist",
    "dso_portfolio_manager",
]


# ─────────────────────────────────────────────────────────────────────
# Dental object types — 8 concrete subclasses
# ─────────────────────────────────────────────────────────────────────


class PredRequestType(DentalObjectType):
    object_type_id: str = "PredRequest"
    display_name: str = "Pre-Determination Request"
    semantic_definition: str = (
        "The root entity — one dental pre-determination request. Everything "
        "else in the model hangs off this. Lifecycle-bound: a resubmission is "
        "a NEW PredRequest, never an edit of the prior one. The dental "
        "equivalent of lending's Application. Ids take the form "
        "PRED-SIM-DA-A01 (CONTEXT.md RULE 14)."
    )
    primary_key: str = "pred_request_id"
    source_table: str = "pred_requests"
    properties: dict[str, str] = Field(default_factory=lambda: {
        "pred_request_id": "string",
        "tenant_id": "string",
        "patient_id": "string",
        "provider_npi": "string",
        "payer_id": "string",
        "plan_id": "string",
        "plan_type": "string",
        "pred_number": "string",
        "status": "string",
        "decision": "enum<approved|denied|pended>",
        "total_case_value": "decimal",
        "submitted_at": "string",
        "created_at": "datetime",
        "updated_at": "datetime",
    })
    links: list[Link] = Field(default_factory=lambda: [
        Link(name="submitted_for", target="Patient",
             cardinality=Cardinality.MANY_TO_ONE, direction=LinkDirection.OUTBOUND,
             semantic_meaning="Submitted for patient — one patient carries many pre-D requests over time."),
        Link(name="submitted_by", target="Provider",
             cardinality=Cardinality.MANY_TO_ONE, direction=LinkDirection.OUTBOUND,
             semantic_meaning="Submitted by provider — joined on provider_npi, the providers table's actual key."),
        Link(name="governed_by", target="Plan",
             cardinality=Cardinality.MANY_TO_ONE, direction=LinkDirection.OUTBOUND,
             semantic_meaning="Governed by plan — the plan in force determines coverage, waiting periods and the annual maximum."),
        Link(name="contains", target="ProcedureLine",
             cardinality=Cardinality.ONE_TO_MANY, direction=LinkDirection.OUTBOUND,
             semantic_meaning="Contains procedures — one line per CDT code per tooth."),
        Link(name="has_coverage_profile", target="EligibilityProfile",
             cardinality=Cardinality.ONE_TO_ONE, direction=LinkDirection.OUTBOUND,
             semantic_meaning="Has coverage profile — assembled from the X12 271 response."),
        Link(name="has_computed_state", target="PredState",
             cardinality=Cardinality.ONE_TO_ONE, direction=LinkDirection.OUTBOUND,
             semantic_meaning="Has computed state — the assembler output every persona starts from."),
        Link(name="supported_by", target="ClinicalEvidence",
             cardinality=Cardinality.ONE_TO_MANY, direction=LinkDirection.OUTBOUND,
             semantic_meaning="Supported by evidence — X-rays, perio charts, notes, cards, payer letters."),
    ])
    decisions_that_read_it: list[str] = Field(default_factory=lambda: list(ALL_DECISIONS))


class PatientType(DentalObjectType):
    object_type_id: str = "Patient"
    display_name: str = "Patient"
    semantic_definition: str = (
        "The WHO. Persists across pre-D requests and across time. Carries the "
        "insurance identity — member_id, group_number, payer_id, "
        "enrollment_start — which is what the eligibility check and the "
        "member-ID mismatch detection both run against."
    )
    primary_key: str = "patient_id"
    source_table: str = "patients"
    properties: dict[str, str] = Field(default_factory=lambda: {
        "patient_id": "string",
        "tenant_id": "string",
        "member_id": "string",
        "group_number": "string",
        "first_name": "string",
        "last_name": "string",
        "dob": "string",
        "gender": "string",
        "plan_id": "string",
        "payer_id": "string",
        "secondary_payer_id": "string",
        "enrollment_start": "date",
        "active": "boolean",
    })
    links: list[Link] = Field(default_factory=lambda: [
        Link(name="has_pred_requests", target="PredRequest",
             cardinality=Cardinality.ONE_TO_MANY, direction=LinkDirection.OUTBOUND,
             semantic_meaning="Has pre-D requests — frequency limits are evaluated across this history."),
        Link(name="enrolled_in", target="Plan",
             cardinality=Cardinality.MANY_TO_ONE, direction=LinkDirection.OUTBOUND,
             semantic_meaning="Enrolled in plan — enrollment_start is what the missing tooth clause and waiting periods are measured from."),
    ])
    decisions_that_read_it: list[str] = Field(default_factory=lambda: [
        "eligibility_analyst",
        "coverage_analyst",
        "clinical_reviewer",
        "pre_d_assessment",
    ])


class ProviderType(DentalObjectType):
    object_type_id: str = "Provider"
    display_name: str = "Provider"
    semantic_definition: str = (
        "The treating dentist. Carries the credentialing posture that gates "
        "the whole submission: an OIG exclusion is an absolute hard stop, an "
        "unverified NPI or out-of-network status escalates. NPI 1134534266 is "
        "Dr. Chinta; 1467573653 is NOT a registered NPI and must never "
        "reappear."
    )
    primary_key: str = "provider_npi"  # NOT npi, NOT provider_id — neither column exists
    source_table: str = "providers"
    properties: dict[str, str] = Field(default_factory=lambda: {
        "provider_npi": "string",
        "tenant_id": "string",
        "name": "string",
        "first_name": "string",
        "last_name": "string",
        "credential": "string",
        "specialty": "string",
        "taxonomy_code": "string",
        "practice_name": "string",
        "license_state": "string",
        "license_expiry": "string",
        "credentialed": "boolean",
        "network_status": "enum<in_network|out_of_network>",
        "out_of_network": "boolean",
        "oig_excluded": "boolean",
        "sanctions": "boolean",
        "nppes_verified": "boolean",
        "nppes_verified_at": "datetime",
        "source": "string",
    })
    links: list[Link] = Field(default_factory=lambda: [
        Link(name="performs_for", target="PredRequest",
             cardinality=Cardinality.ONE_TO_MANY, direction=LinkDirection.OUTBOUND,
             semantic_meaning="Performs procedures for — joined on provider_npi."),
    ])
    decisions_that_read_it: list[str] = Field(default_factory=lambda: [
        "provider_credentialing",
        "pre_d_assessment",
    ])


class PlanType(DentalObjectType):
    object_type_id: str = "Plan"
    display_name: str = "Insurance Plan"
    semantic_definition: str = (
        "The benefit structure in force. Everything the eligibility and "
        "coverage decisions gate on lives here — annual maximum, deductibles, "
        "waiting periods by category, the implant exclusion, the missing tooth "
        "clause, and benefit percentages by service class."
    )
    primary_key: str = "plan_id"
    source_table: str = "plans"
    properties: dict[str, str] = Field(default_factory=lambda: {
        "plan_id": "string",
        "payer_id": "string",
        "plan_name": "string",
        "plan_type": "string",
        "group_number": "string",
        "benefit_year_start": "string",
        "annual_maximum": "decimal",
        "deductible": "decimal",
        "deductible_individual": "decimal",
        "deductible_family": "decimal",
        "waiting_period_months": "integer",
        "waiting_period_basic_months": "integer",
        "waiting_period_major_months": "integer",
        "waiting_period_implant_months": "integer",
        "implant_coverage": "boolean",
        "missing_tooth_clause": "boolean",
        "benefit_pct_preventive": "decimal",
        "benefit_pct_basic": "decimal",
        "benefit_pct_major": "decimal",
        "benefit_pct_implants": "decimal",
    })
    links: list[Link] = Field(default_factory=lambda: [
        Link(name="covers", target="Patient",
             cardinality=Cardinality.ONE_TO_MANY, direction=LinkDirection.OUTBOUND,
             semantic_meaning="Covers patients."),
        Link(name="governs", target="PredRequest",
             cardinality=Cardinality.ONE_TO_MANY, direction=LinkDirection.OUTBOUND,
             semantic_meaning="Governs pre-D requests — the plan is what makes a code covered or excluded."),
    ])
    decisions_that_read_it: list[str] = Field(default_factory=lambda: [
        "eligibility_analyst",
        "coverage_analyst",
    ])


class ProcedureLineType(DentalObjectType):
    object_type_id: str = "ProcedureLine"
    display_name: str = "Procedure Line"
    semantic_definition: str = (
        "One billed CDT code on one tooth. The unit that bundling, frequency, "
        "downgrade and upcoding checks all operate on. tooth_number is "
        "universal numbering 1-32; tooth_surface is what a fraud_integrity "
        "surface_conflict compares against the radiograph. Surrogate PK; the "
        "natural key is (pred_request_id, line_no)."
    )
    primary_key: str = "procedure_line_id"
    source_table: str = "procedure_lines"
    properties: dict[str, str] = Field(default_factory=lambda: {
        "procedure_line_id": "bigint",
        "pred_request_id": "string",
        "tenant_id": "string",
        "line_no": "integer",
        "cdt_code": "string",
        "tooth_number": "integer",
        "tooth_surface": "string",
        "arch": "enum<upper|lower>",
        "quadrant": "enum<UR|UL|LR|LL>",
        "fee": "decimal",
        "payer_allowed": "decimal",
        "requires_pred": "boolean",
        "description": "string",
    })
    links: list[Link] = Field(default_factory=lambda: [
        Link(name="belongs_to", target="PredRequest",
             cardinality=Cardinality.MANY_TO_ONE, direction=LinkDirection.INBOUND,
             semantic_meaning="Belongs to pre-D."),
        Link(name="has_cost_breakdown", target="CostEstimate",
             cardinality=Cardinality.ONE_TO_ONE, direction=LinkDirection.OUTBOUND,
             semantic_meaning="Has cost breakdown — insurance portion vs patient portion for this line."),
    ])
    decisions_that_read_it: list[str] = Field(default_factory=lambda: [
        "coverage_analyst",
        "fraud_integrity",
        "documentation_reviewer",
    ])


class ClinicalEvidenceType(DentalObjectType):
    object_type_id: str = "ClinicalEvidence"
    display_name: str = "Clinical Evidence"
    semantic_definition: str = (
        "The document index. One row per piece of supporting evidence, with "
        "the fields extracted from it and a confidence in that extraction. "
        "183 rows: 108 with an s3_key (real PDFs) plus 75 structured payloads "
        "with no PDF behind them (35 X12_271_RESPONSE, 35 CDT_SUPERBILL, "
        "5 PRED_LETTER_PENDED). The S3 prefix uses the BARE scenario id "
        "(DA-A01), not the pred_request_id."
    )
    primary_key: str = "evidence_id"
    source_table: str = "clinical_evidence"
    properties: dict[str, str] = Field(default_factory=lambda: {
        "evidence_id": "string",
        "pred_request_id": "string",
        "tenant_id": "string",
        "document_type": (
            "enum<XRAY_PA|XRAY_PAN|CBCT_REPORT|PERIO_CHART|CLINICAL_NOTE|"
            "INSURANCE_CARD|PRED_LETTER|PRED_LETTER_PENDED|X12_271_RESPONSE|"
            "CDT_SUPERBILL>"
        ),
        "document_category": "string",
        "tooth_number": "integer",
        "source_channel": "string",
        "source_system": "string",
        "s3_key": "string",
        "extracted_fields": "jsonb",
        "confidence_score": "decimal",
        "extraction_method": "enum<deterministic|ai_vision|caller_supplied|none>",
        "received_at": "string",
    })
    links: list[Link] = Field(default_factory=lambda: [
        Link(name="supports", target="PredRequest",
             cardinality=Cardinality.MANY_TO_ONE, direction=LinkDirection.INBOUND,
             semantic_meaning="Supports pre-D."),
        Link(name="represented_as", target="EvidenceNode",
             cardinality=Cardinality.ONE_TO_ONE, direction=LinkDirection.OUTBOUND,
             semantic_meaning="Represented as graph node — typed edges (confirms/corroborates/contradicts) connect nodes and are what fraud_integrity reads."),
    ])
    decisions_that_read_it: list[str] = Field(default_factory=lambda: [
        "clinical_reviewer",
        "documentation_reviewer",
        "fraud_integrity",
    ])


class EligibilityProfileType(DentalObjectType):
    object_type_id: str = "EligibilityProfile"
    display_name: str = "Eligibility Profile"
    semantic_definition: str = (
        "Typed columns — not JSONB. Assembled from the X12 271 eligibility "
        "response. One row per PredRequest. This is what eligibility_analyst "
        "reads. Watch the naming: this table says annual_maximum_remaining and "
        "implant_coverage where pred_states says annual_max_remaining and "
        "implant_covered, and it splits the missing tooth clause into "
        "missing_tooth_clause (on the plan) and missing_tooth_clause_confirmed "
        "(for THIS tooth) where pred_states rolls both into "
        "missing_tooth_clause_triggered."
    )
    primary_key: str = "pred_request_id"
    source_table: str = "eligibility_profiles"
    properties: dict[str, str] = Field(default_factory=lambda: {
        "pred_request_id": "string",
        "tenant_id": "string",
        "coverage_active": "boolean",
        "payer_id": "string",
        "plan_type": "string",
        "member_id": "string",
        "group_number": "string",
        "enrollment_date": "string",
        "annual_maximum": "decimal",
        "annual_maximum_used": "decimal",
        "annual_maximum_remaining": "decimal",
        "deductible_total": "decimal",
        "deductible_met": "decimal",
        "deductible_remaining": "decimal",
        "benefit_pct_preventive": "decimal",
        "benefit_pct_basic": "decimal",
        "benefit_pct_major": "decimal",
        "benefit_pct_implants": "decimal",
        "implant_coverage": "boolean",
        "ortho_coverage": "boolean",
        "waiting_period_met": "boolean",
        "missing_tooth_clause": "boolean",
        "missing_tooth_clause_confirmed": "boolean",
        "coordination_of_benefits": "boolean",
        "pred_required_codes": "jsonb",
        "conflicts": "jsonb",
        "confidence": "decimal",
        "source": "string",
        "verified_at": "string",
        "assembled_at": "string",
    })
    links: list[Link] = Field(default_factory=lambda: [
        Link(name="describes_coverage_for", target="PredRequest",
             cardinality=Cardinality.ONE_TO_ONE, direction=LinkDirection.INBOUND,
             semantic_meaning="Describes coverage for."),
    ])
    decisions_that_read_it: list[str] = Field(default_factory=lambda: [
        "eligibility_analyst",
        "coverage_analyst",
        "pre_d_assessment",
    ])


class PredStateType(DentalObjectType):
    object_type_id: str = "PredState"
    display_name: str = "Pre-D Computed State"
    semantic_definition: str = (
        "THE most important entity. Central computed state. dental-simulator "
        "assembled this; dental-os reads it. All 9 personas start from "
        "PredState. 35 rows: approved=8, denied=7, pended=20. "
        "readiness_flags is {} on all 35 rows (NOT null) and status / "
        "decision_confidence are NULL — Known Gap #1, do not read them as "
        "signal. decision_trace is a variable-length array of assembler "
        "findings (4-9 entries), NOT one entry per persona — never index "
        "into it positionally."
    )
    primary_key: str = "pred_request_id"
    source_table: str = "pred_states"
    properties: dict[str, str] = Field(default_factory=lambda: {
        "pred_request_id": "string",
        "tenant_id": "string",
        "decision": "enum<approved|denied|pended>",
        "coverage_active": "boolean",
        "annual_max_remaining": "decimal",
        "implant_covered": "boolean",
        "waiting_period_met": "boolean",
        "missing_tooth_clause_triggered": "boolean",
        "pred_required": "boolean",
        "criteria_score": "decimal",
        "medical_necessity_met": "boolean",
        "criteria_met_count": "integer",
        "criteria_total_count": "integer",
        "clinical_evidence_count": "integer",
        "missing_evidence": "jsonb",
        "no_critical_conflicts": "boolean",
        "has_bundling_conflict": "boolean",
        "conflict_count": "integer",
        "conflicts": "jsonb",
        "open_conditions": "jsonb",
        "decision_trace": "jsonb",
        "provider_npi_valid": "boolean",
        "provider_oig_excluded": "boolean",
        "provider_specialty": "string",
        "readiness_flags": "jsonb",
        "status": "string",
        "decision_confidence": "decimal",
        "requires_human_review": "boolean",
        "auto_decision_eligible": "boolean",
        "updated_at": "string",
    })
    links: list[Link] = Field(default_factory=lambda: [
        Link(name="is_computed_state_for", target="PredRequest",
             cardinality=Cardinality.ONE_TO_ONE, direction=LinkDirection.INBOUND,
             semantic_meaning="Is computed state for."),
    ])
    decisions_that_read_it: list[str] = Field(default_factory=lambda: list(ALL_DECISIONS))


# ─────────────────────────────────────────────────────────────────────
# Registry
# ─────────────────────────────────────────────────────────────────────

DENTAL_OBJECT_TYPES: dict[str, DentalObjectType] = {
    cls().object_type_id: cls()
    for cls in (
        PredRequestType,
        PatientType,
        ProviderType,
        PlanType,
        ProcedureLineType,
        ClinicalEvidenceType,
        EligibilityProfileType,
        PredStateType,
    )
}

# decision_id -> the object types that decision may read.
DECISION_READ_MAP: dict[str, list[str]] = {
    decision: [
        ot_id
        for ot_id, ot in DENTAL_OBJECT_TYPES.items()
        if decision in ot.decisions_that_read_it
    ]
    for decision in ALL_DECISIONS
}


def readable_object_types(decision_id: str) -> list[DentalObjectType]:
    """Object types a given decision is permitted to read."""
    if decision_id not in ALL_DECISIONS:
        raise KeyError(f"unknown decision_id: {decision_id!r}")
    return [
        ot
        for ot in DENTAL_OBJECT_TYPES.values()
        if decision_id in ot.decisions_that_read_it
    ]
