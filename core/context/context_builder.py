"""
ContextBuilder — assembles a PredContext from the dental-simulator RDS.

Mirrors decision-os core/context_store/context_builder.py: one place
that reads the store and hands personas a typed, frozen-for-the-request
view of the world. Everything a persona reasons over must come from the
context object — that is the contract that makes a decision replayable
from persona_bundles later.

import logging

logger = logging.getLogger(__name__)
Reads CONTEXT VIEWS, not raw tables (CONTEXT.md RULE 4). Every query
goes through fetch_with_tenant, so RLS tenant context is never missing
and the transaction is read-only.
"""
from __future__ import annotations

import json
from decimal import Decimal
from typing import Any, Optional

import asyncpg

from core.db.connection import DEFAULT_TENANT, fetch_with_tenant
from core.context.pred_context import (
    ClinicalEvidence,
    EligibilityProfile,
    PayerResponse,
    PredContext,
    ProcedureLine,
    confidence_label,
    scenario_id_from_pred_request_id,
)


# ─────────────────────────────────────────────────────────────────────
# Coercion helpers
#
# asyncpg returns NUMERIC as Decimal and JSONB as str (no codec is
# registered on this pool). Personas should never have to care, so
# normalise at the boundary rather than in nine different places.
# ─────────────────────────────────────────────────────────────────────


def _f(value: Any) -> Optional[float]:
    if value is None:
        return None
    if isinstance(value, Decimal):
        return float(value)
    return float(value)


def _b(value: Any) -> bool:
    return bool(value) if value is not None else False


def _json(value: Any, default: Any) -> Any:
    """JSONB -> python. Tolerates str, already-parsed, and None."""
    if value is None:
        return default
    if isinstance(value, (dict, list)):
        return value
    if isinstance(value, (str, bytes)):
        try:
            return json.loads(value)
        except (ValueError, TypeError):
            return default
    return default


class ContextBuilder:
    """Builds one PredContext per pre-D, per request."""

    def __init__(self, pool: asyncpg.Pool, os_pool: asyncpg.Pool | None = None):
        self.pool = pool
        # OPTIONAL, and every existing caller omits it. Without it the
        # context carries no denial_event and the appeal persona stays
        # silent — which is the correct answer for a pre-D nobody has
        # submitted, and the safe answer for a caller that has not been
        # taught about the second database yet.
        self.os_pool = os_pool

    async def build(
        self,
        pred_request_id: str,
        tenant_id: str = DEFAULT_TENANT,
    ) -> PredContext:
        # Raises on the old PRED-DA-* format before any query runs, so a
        # stale id fails loudly instead of returning an empty context
        # that reads like "this pre-D has no evidence".
        scenario_id = scenario_id_from_pred_request_id(pred_request_id)

        # 1 + 2 + 3. Header, PredState and EligibilityProfile all come
        # from vw_eligibility_context — it already joins pred_requests,
        # patients, plans, payers, eligibility_profiles and pred_states.
        header = await self._one(
            tenant_id,
            """
            SELECT * FROM vw_eligibility_context WHERE pred_request_id = $1
            """,
            pred_request_id,
        )
        if header is None:
            raise LookupError(
                f"no pre-D {pred_request_id!r} visible for tenant "
                f"{tenant_id!r}. If you expected one: RLS returns 0 rows "
                f"rather than an error when the tenant is wrong, so check "
                f"the tenant before concluding the row is missing."
            )

        provider = await self._one(
            tenant_id,
            """
            SELECT provider_name, provider_npi, credential, specialty,
                   oig_excluded, nppes_verified, network_status, license_state,
                   provider_npi_valid, provider_oig_excluded
            FROM vw_provider_context WHERE pred_request_id = $1
            """,
            pred_request_id,
        ) or {}

        # The fee schedule that applies is the one where the service is
        # rendered, so state comes off the treating provider's licence.
        # Falls back to GA — the design partner's state, and the only
        # one whose rates trace to a published schedule.
        state = (provider.get("license_state") or "GA").strip().upper()[:2] or "GA"

        eligibility = EligibilityProfile(
            coverage_active=_b(header.get("coverage_active")),
            payer_id=header.get("payer_id") or "",
            plan_type=header.get("plan_type") or "",
            annual_maximum=_f(header.get("elig_annual_maximum")) or 0.0,
            annual_max_remaining=_f(header.get("annual_maximum_remaining")) or 0.0,
            deductible_remaining=_f(header.get("deductible_remaining")) or 0.0,
            benefit_pct_preventive=_f(header.get("benefit_pct_preventive")) or 0.0,
            benefit_pct_basic=_f(header.get("benefit_pct_basic")) or 0.0,
            benefit_pct_major=_f(header.get("benefit_pct_major")) or 0.0,
            benefit_pct_implants=_f(header.get("benefit_pct_implants")) or 0.0,
            # eligibility_profiles says implant_coverage; pred_states says
            # implant_covered. Prefer the profile (what the payer said),
            # fall back to the state (what the assembler concluded).
            implant_covered=_b(
                header.get("elig_implant_coverage")
                if header.get("elig_implant_coverage") is not None
                else header.get("state_implant_covered")
            ),
            waiting_period_met=_b(header.get("waiting_period_met")),
            missing_tooth_clause_triggered=_b(
                header.get("missing_tooth_clause_triggered")
            ),
            coordination_of_benefits=_b(header.get("coordination_of_benefits")),
            enrollment_start=(
                header["enrollment_start"].isoformat()
                if header.get("enrollment_start") else None
            ),
            waiting_period_basic_months=header.get("waiting_period_basic_months"),
            waiting_period_major_months=header.get("waiting_period_major_months"),
            waiting_period_implant_months=header.get("waiting_period_implant_months"),
            # Deliberately NOT _b() — None must survive as None. See the
            # field's comment in pred_context.EligibilityProfile.
            member_id_mismatch=header.get("member_id_mismatch"),
        )

        # 4. Procedure lines + their cost breakdown.
        procedures = [
            ProcedureLine(
                cdt_code=r["cdt_code"],
                tooth_number=r["tooth_number"],
                tooth_surface=r["tooth_surface"],
                fee_submitted=_f(r["fee"]) or 0.0,
                allowed_amount=_f(r["allowed_amount"]),
                insurance_pays=_f(r["insurance_pays"]),
                patient_pays=_f(r["patient_pays"]),
                downgrade_applied=_b(r["downgrade_applied"]),
                downgrade_from=r["downgrade_from"],
                line_no=r["line_no"],
                quadrant=r["quadrant"],
                requires_pred=_b(r["requires_pred"]),
            )
            for r in await self._all(
                tenant_id,
                """
                SELECT line_no, cdt_code, tooth_number, tooth_surface, quadrant,
                       fee, requires_pred, allowed_amount, insurance_pays,
                       patient_pays, downgrade_applied, downgrade_from
                FROM vw_coverage_context
                WHERE pred_request_id = $1
                ORDER BY line_no
                """,
                pred_request_id,
            )
        ]

        # 5. Clinical evidence.
        evidence = [
            ClinicalEvidence(
                document_type=r["document_type"],
                s3_key=r["s3_key"],
                extracted_fields=_json(r["extracted_fields"], {}),
                confidence_score=_f(r["confidence_score"]) or 0.0,
                extraction_method=r["extraction_method"] or "none",
                received_at=r["received_at"],
                evidence_id=r["evidence_id"],
            )
            for r in await self._all(
                tenant_id,
                """
                SELECT evidence_id, document_type, s3_key, extracted_fields,
                       confidence_score, extraction_method, received_at
                FROM vw_clinical_context
                WHERE pred_request_id = $1
                ORDER BY document_type
                """,
                pred_request_id,
            )
        ]

        # 6 + 7 + 8. Payer response, graph summary and audit events all
        # come from vw_appeal_context.
        appeal = await self._one(
            tenant_id,
            """
            SELECT payer_decision, pred_number, approved_amount,
                   denial_reason_code, denial_reason_text, policy_citation,
                   appeal_deadline, pend_checklist, recent_audit_events,
                   criteria_score, medical_necessity_met, has_bundling_conflict,
                   open_conditions, decision_trace, missing_evidence
            FROM vw_appeal_context WHERE pred_request_id = $1
            """,
            pred_request_id,
        ) or {}

        payer_response = None
        if appeal.get("payer_decision"):
            deadline = appeal.get("appeal_deadline")
            payer_response = PayerResponse(
                decision=appeal["payer_decision"],
                pred_number=appeal.get("pred_number"),
                approved_amount=_f(appeal.get("approved_amount")),
                denial_reason_code=appeal.get("denial_reason_code"),
                denial_reason_text=appeal.get("denial_reason_text"),
                appeal_deadline=deadline.isoformat() if deadline else None,
                pend_checklist=_json(appeal.get("pend_checklist"), []),
                policy_citation=appeal.get("policy_citation"),
            )

        # A REAL denial, from dental_os. Loaded here rather than in the
        # persona because a persona is sync and DB-less (RULE 5), and
        # the two databases cannot be joined — they are separate
        # databases on one instance with no fdw.
        denial_event = None
        if self.os_pool is not None:
            try:
                async with self.os_pool.acquire() as conn:
                    async with conn.transaction():
                        await conn.execute(
                            "SELECT set_config('app.tenant_id', $1, true)",
                            tenant_id,
                        )
                        row = await conn.fetchrow(
                            "SELECT denial_id, denied_at, denial_reason, "
                            "       denial_reason_code, denied_amount, "
                            "       appeal_deadline, appeal_viable, "
                            "       appeal_probability, submission_id "
                            "FROM denial_events "
                            "WHERE tenant_id = $1 AND pred_request_id = $2 "
                            "ORDER BY denied_at DESC LIMIT 1",
                            tenant_id, pred_request_id,
                        )
                denial_event = dict(row) if row else None
            except Exception as exc:  # noqa: BLE001
                # A missing denial must not fail the whole context. It
                # reads as "no denial", which is what it is.
                logger.warning("denial_events read failed for %s: %s",
                               pred_request_id, exc)

        graph = await self._one(
            tenant_id,
            """
            SELECT MAX(confirms_count) AS confirms,
                   MAX(contradicts_count) AS contradicts,
                   -- FILTER is required, not cosmetic: array_agg over a
                   -- NULL array raises "cannot accumulate null arrays",
                   -- and contradicts_fields is NULL for every scenario
                   -- with no contradicting edges — which is most of them.
                   (array_agg(contradicts_fields)
                      FILTER (WHERE contradicts_fields IS NOT NULL))[1]
                       AS contradicts_fields
            FROM vw_fraud_context WHERE pred_request_id = $1
            """,
            pred_request_id,
        ) or {}

        criteria_score = _f(appeal.get("criteria_score"))

        return PredContext(
            pred_request_id=pred_request_id,
            tenant_id=tenant_id,
            scenario_id=scenario_id,
            patient_name=header.get("patient_name") or "",
            patient_dob=header.get("dob"),
            provider_name=provider.get("provider_name") or "",
            provider_npi=provider.get("provider_npi") or header.get("provider_npi") or "",
            plan_name=header.get("plan_name") or "",
            payer_id=header.get("payer_id") or "",
            state=state,
            # Prefer the providers table over the assembler's rollup: the
            # table is the credentialing record, the rollup is a copy.
            # Fall back to the rollup when the join found no provider.
            provider_oig_excluded=(
                provider.get("oig_excluded")
                if provider.get("oig_excluded") is not None
                else provider.get("provider_oig_excluded")
            ),
            provider_npi_valid=(
                provider.get("provider_npi_valid")
                if provider.get("provider_npi_valid") is not None
                else provider.get("nppes_verified")
            ),
            provider_network_status=provider.get("network_status"),
            provider_specialty=provider.get("specialty"),
            provider_credential=provider.get("credential"),
            provider_nppes_verified=provider.get("nppes_verified"),
            decision=header.get("decision") or "",
            criteria_score=criteria_score,
            confidence_label=confidence_label(criteria_score),
            has_bundling_conflict=_b(appeal.get("has_bundling_conflict")),
            open_conditions=_json(
                appeal.get("open_conditions") or header.get("open_conditions"), []
            ),
            decision_trace=_json(appeal.get("decision_trace"), []),
            medical_necessity_met=_b(appeal.get("medical_necessity_met")),
            missing_evidence=_json(appeal.get("missing_evidence"), []),
            eligibility=eligibility,
            procedures=procedures,
            clinical_evidence=evidence,
            payer_response=payer_response,
            denial_event=denial_event,
            confirms_count=int(graph.get("confirms") or 0),
            contradicts_count=int(graph.get("contradicts") or 0),
            contradicts_fields=list(graph.get("contradicts_fields") or []),
            audit_events=_json(appeal.get("recent_audit_events"), []),
        )

    # ── Query helpers ────────────────────────────────────────────────

    async def _all(self, tenant_id: str, sql: str, *args: Any) -> list[dict]:
        return await fetch_with_tenant(self.pool, tenant_id, sql, *args)

    async def _one(self, tenant_id: str, sql: str, *args: Any) -> Optional[dict]:
        rows = await fetch_with_tenant(self.pool, tenant_id, sql, *args)
        return rows[0] if rows else None
