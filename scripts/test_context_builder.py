"""
Builds a PredContext for PRED-SIM-DA-A01 and prints every field a
persona would read, so a regression in the view layer shows up here
rather than inside a persona.

    python scripts/test_context_builder.py [PRED-SIM-DA-XXX]
"""
import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from dotenv import load_dotenv

load_dotenv()

from core.context.context_builder import ContextBuilder  # noqa: E402
from core.db.connection import close_pool, get_pool  # noqa: E402

PRED = sys.argv[1] if len(sys.argv) > 1 else "PRED-SIM-DA-A01"

# Verified against the live RDS 2026-08-05.
EXPECTED = {
    "pred_request_id": "PRED-SIM-DA-A01",
    "scenario_id": "DA-A01",
    "patient_name": "James Mitchell",
    "decision": "pended",
    "criteria_score": 0.85,
    # DA-A01 sits exactly ON the 0.85 boundary, so this is the one value
    # where the band edge matters. >= 0.85 is "High confidence": that is
    # what dental-simulator PRD section 11 calls the auto-approve band
    # (0.85-1.00) AND what clinical_reviewer's recommend_if clause uses
    # (criteria_score >= 0.85). The task spec expected "Likely to be
    # approved" here, which would require the band to be > 0.85 and would
    # disagree with both of those sources. Note the label describes
    # DOCUMENTATION sufficiency, not the outcome — DA-A01 is documented
    # well and still pends, because of the bundling conflict.
    "confidence_label": "High confidence",
    "coverage_active": True,
    "annual_max_remaining": 1800.0,
    "procedure_count": 3,
    "cdt_codes": ["D6010", "D7953", "D6065"],
    "evidence_count": 6,
    "bone_loss_mm": 4.2,
    "pred_number": "DD-2026-DA-A01-PND",
    "confirms_count": 1,
    "contradicts_count": 1,
}


def check(label: str, actual, expected, errors: list) -> str:
    if expected is None:
        return " "
    ok = actual == expected
    if not ok:
        errors.append(f"{label}: got {actual!r}, expected {expected!r}")
    return "+" if ok else "x"


async def main() -> int:
    pool = await get_pool()
    builder = ContextBuilder(pool)

    ctx = await builder.build(PRED)
    errors: list[str] = []
    exp = EXPECTED if PRED == EXPECTED["pred_request_id"] else {}

    def row(label: str, actual, key: str = None, width: int = 24):
        mark = check(label, actual, exp.get(key) if key else None, errors)
        print(f"  {mark} {label:<{width}} {actual}")

    print(f"PredContext for {PRED}\n")

    print("Identity")
    row("pred_request_id", ctx.pred_request_id, "pred_request_id")
    row("scenario_id", ctx.scenario_id, "scenario_id")
    row("patient_name", ctx.patient_name, "patient_name")
    row("provider_name", ctx.provider_name)
    row("provider_npi", ctx.provider_npi)
    row("plan_name", ctx.plan_name)
    row("payer_id", ctx.payer_id)

    print("\nPolicy engine output")
    row("decision", ctx.decision, "decision")
    row("criteria_score", ctx.criteria_score, "criteria_score")
    row("confidence_label", ctx.confidence_label, "confidence_label")
    row("has_bundling_conflict", ctx.has_bundling_conflict)
    row("medical_necessity_met", ctx.medical_necessity_met)
    row("open_conditions", len(ctx.open_conditions))
    row("decision_trace entries", len(ctx.decision_trace))
    row("missing_evidence", ctx.missing_evidence)

    print("\nEligibility")
    e = ctx.eligibility
    row("coverage_active", e.coverage_active, "coverage_active")
    row("annual_max_remaining", e.annual_max_remaining, "annual_max_remaining")
    row("deductible_remaining", e.deductible_remaining)
    row("implant_covered", e.implant_covered)
    row("waiting_period_met", e.waiting_period_met)
    row("missing_tooth_triggered", e.missing_tooth_clause_triggered)
    row("coordination_of_benefits", e.coordination_of_benefits)
    row("member_id_mismatch", e.member_id_mismatch)
    row("benefit_pct_implants", e.benefit_pct_implants)

    print("\nProcedures")
    row("count", len(ctx.procedures), "procedure_count")
    row("cdt_codes", ctx.cdt_codes, "cdt_codes")
    for p in ctx.procedures:
        print(
            f"      {p.cdt_code}  tooth #{p.tooth_number}  "
            f"fee=${p.fee_submitted:,.2f}  allowed=${p.allowed_amount or 0:,.2f}  "
            f"patient=${p.patient_pays or 0:,.2f}"
            # downgrade_from records the BILLED code, not the code the
            # payer pays at (D6065 is reimbursed at the D2750 rate per
            # downgrade_matrix D.7.2). The paid code is not stored on
            # cost_estimates, so do not print it as "from X to Y".
            + ("  [downgraded]" if p.downgrade_applied else "")
        )
    row("total_fee_submitted", f"${ctx.total_fee_submitted:,.2f}")
    row("total_patient_pays", f"${ctx.total_patient_pays:,.2f}")

    print("\nClinical evidence")
    row("count", len(ctx.clinical_evidence), "evidence_count")
    for d in ctx.clinical_evidence:
        flag = "  <- below TRUST_FLOOR" if d.below_trust_floor else ""
        print(
            f"      {d.document_type:20} conf={d.confidence_score:<5} "
            f"{d.extraction_method:16}{flag}"
        )
    row("bone_loss_mm", ctx.bone_loss_mm, "bone_loss_mm")
    row("low confidence docs", len(ctx.low_confidence_documents))

    print("\nPayer response")
    pr = ctx.payer_response
    if pr is None:
        row("payer_response", None)
    else:
        row("decision", pr.decision)
        row("pred_number", pr.pred_number, "pred_number")
        row("denial_reason_code", pr.denial_reason_code)
        row("appeal_deadline", pr.appeal_deadline)
        row("pend_checklist", len(pr.pend_checklist))

    print("\nKnowledge graph")
    row("confirms_count", ctx.confirms_count, "confirms_count")
    row("contradicts_count", ctx.contradicts_count, "contradicts_count")

    print("\nAudit")
    row("audit_events", len(ctx.audit_events))
    for ev in ctx.audit_events[:3]:
        print(f"      {ev.get('occurred_at', '')[:19]}  {ev.get('event_type')}")

    print(f"\nsummary(): {ctx.summary()}")

    await close_pool()

    print()
    if not errors:
        print(f"+ PredContext assembled and verified for {PRED}")
        return 0
    print(f"x {len(errors)} mismatch(es):")
    for e in errors:
        print(f"  {e}")
    return 1


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
