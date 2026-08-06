"""
T-10i — Coverage resolver. What does the payer cover, and what does the
patient actually owe?

This is the phone call to Delta Dental, answered from the catalogue.
Per CDT code it works out four numbers that are routinely conflated:

  provider_ucr_fee   what Dr. Chinta charges
  contracted_rate    what the payer allows in-network
  provider_discount  the difference — a NEGOTIATED DISCOUNT the patient
                     gets for staying in-network, NOT a write-off and
                     NOT a bill anyone sends
  patient_pays       deductible + coinsurance on the contracted rate

Order of operations, and it matters: deductible comes off the
CONTRACTED rate before coinsurance, never off the UCR fee. Applying the
percentage first inflates what the plan appears to pay and understates
the patient's share — which is exactly the surprise at checkout the
product exists to prevent.

Deductible and annual maximum are consumed ACROSS procedures in billed
order, because that is how a payer adjudicates a claim: the first line
absorbs the deductible, later lines do not pay it again, and once the
annual maximum is gone every remaining line is 100% patient.

RULE 5: sync, DB-less. RULE 11: data_source + missing_inputs.
"""
from __future__ import annotations

from datetime import date
from typing import Any, Optional

from core.resolvers.base import as_date, as_float, safe_resolver

# Applied when a code has no fee schedule row. A rough in-network
# discount, and flagged so nobody quotes it to a patient as the
# payer's allowed amount.
SAFE_DEFAULT_ALLOWED_RATIO = 0.85


def _age_on(dob: Any, on: date) -> Optional[int]:
    d = as_date(dob)
    if d is None:
        return None
    return on.year - d.year - ((on.month, on.day) < (d.month, d.day))


@safe_resolver
def resolve_coverage(context: Any, rules: dict, *, today: date = None) -> dict:
    """Sync. DB-less. Reads from bundle only."""
    today = today or date.today()
    elig = getattr(context, "eligibility", None)
    payer = getattr(context, "payer_id", None) or "delta_dental"
    state = getattr(context, "state", None) or "GA"

    coverage_rules = rules.get("coverage_rules") or {}
    fee_schedules = rules.get("fee_schedules") or {}

    deductible_remaining = as_float(getattr(elig, "deductible_remaining", None)) or 0.0
    annual_max_remaining = as_float(getattr(elig, "annual_max_remaining", None)) or 0.0
    default_pct = as_float(getattr(elig, "benefit_pct_major", None)) or 50.0
    waiting_met = getattr(elig, "waiting_period_met", None)
    patient_dob = getattr(context, "patient_dob", None)

    procedures_result: list[dict] = []
    coverage_gaps: list[str] = []
    pre_d_required_for: list[str] = []
    missing: list[str] = []
    estimated_rate_codes: list[str] = []

    totals = dict(ucr=0.0, contracted=0.0, discount=0.0,
                  deductible=0.0, insurance=0.0, patient=0.0)

    if elig is None:
        missing.append("eligibility_profile")

    for proc in getattr(context, "procedures", []) or []:
        cdt = proc.cdt_code
        ucr_fee = as_float(proc.fee_submitted) or 0.0

        # ── Coverage rule ────────────────────────────────────────────
        rule = coverage_rules.get((payer, cdt))
        used_default_rule = rule is None
        if used_default_rule:
            # RULE 9. Since T-10g every one of the 181 codes has a rule
            # for every payer, so reaching this means an uncatalogued
            # code was billed — worth surfacing, not silently assuming.
            missing.append(f"coverage_rule for {cdt}/{payer}")
            rule = {
                "covered": True,
                "benefit_pct": default_pct,
                "benefit_category": "major",
                "pre_d_required": False,
                "deductible_applies": True,
                "age_limit_min": None, "age_limit_max": None,
                "waiting_period_months": 0, "lifetime_maximum": None,
                "missing_tooth_clause": False, "downgrade_to": None,
                "notes": "SAFE_DEFAULT - no coverage rule found",
            }

        # ── Fee schedule ─────────────────────────────────────────────
        fee_rule = fee_schedules.get((payer, cdt, state))
        if fee_rule and fee_rule.get("allowed_amount") is not None:
            contracted_rate = float(fee_rule["allowed_amount"])
            rate_source = fee_rule.get("source")
            if fee_rule.get("is_estimated"):
                estimated_rate_codes.append(cdt)
        else:
            contracted_rate = round(ucr_fee * SAFE_DEFAULT_ALLOWED_RATIO, 2)
            rate_source = "safe_default_85pct_of_ucr"
            missing.append(f"fee_schedule for {cdt}/{payer}/{state}")
            estimated_rate_codes.append(cdt)

        # ── Downgrade ────────────────────────────────────────────────
        # The payer reimburses the billed code at ANOTHER code's rate.
        # Look the target up in the same fee schedule; if it is absent,
        # keep the billed rate rather than guessing, and say so.
        downgrade_applied = False
        downgrade_from = None
        downgrade_to = rule.get("downgrade_to") or rule.get("downgrade_to_cdt")
        if downgrade_to:
            down_fee = fee_schedules.get((payer, downgrade_to, state))
            if down_fee and down_fee.get("allowed_amount") is not None:
                contracted_rate = float(down_fee["allowed_amount"])
                rate_source = down_fee.get("source")
                downgrade_applied = True
                downgrade_from = cdt
            else:
                missing.append(
                    f"fee_schedule for downgrade target {downgrade_to}/{payer}/{state}"
                )

        provider_discount = round(ucr_fee - contracted_rate, 2)

        # ── Not covered ──────────────────────────────────────────────
        # TWO INDEPENDENT WAYS A CODE CAN BE UNCOVERED, and the
        # plan-level one outranks the code-level one:
        #
        #   coverage_rules.covered=False  the payer never covers this
        #                                 code for anyone
        #   eligibility.implant_covered=False
        #                                 THIS PATIENT'S plan excludes
        #                                 the whole implant benefit
        #
        # coverage_rules is per payer, not per plan, so it says D6010 is
        # covered at 50% — true of Delta generally, false of a plan that
        # bought no implant rider. Reading only the code-level rule paid
        # 50% on DA-B01 and understated the patient's share by $1,500 on
        # a case where they owe every dollar.
        plan_excludes_implants = (
            rule.get("benefit_category") == "implant"
            and getattr(elig, "implant_covered", None) is False
        )
        if not rule.get("covered", True) or plan_excludes_implants:
            reason = (
                "Implant services are excluded from this plan — patient is "
                "responsible for the full amount. A plan exclusion is not "
                "appealable."
                if plan_excludes_implants
                else (rule.get("notes") or "Not a covered benefit")
            )
            procedures_result.append({
                "cdt_code": cdt, "tooth_number": proc.tooth_number,
                "covered": False, "benefit_pct": 0.0,
                "benefit_category": rule.get("benefit_category"),
                "provider_ucr_fee": round(ucr_fee, 2),
                "contracted_rate": round(contracted_rate, 2),
                "provider_discount": provider_discount,
                "deductible_applied": 0.0, "insurance_pays": 0.0,
                "patient_pays": round(contracted_rate, 2),
                "annual_max_exhausted": False,
                "not_covered_reason": reason,
                "age_limit_exceeded": False, "waiting_period_not_met": False,
                "downgrade_applied": False, "downgrade_from": None,
                "downgrade_to": None, "pre_d_required": False,
                "lifetime_maximum": None, "rate_source": rate_source,
                "rate_is_estimated": cdt in estimated_rate_codes,
            })
            coverage_gaps.append(f"{cdt}: {reason}")
            totals["ucr"] += ucr_fee
            totals["contracted"] += contracted_rate
            totals["discount"] += provider_discount
            totals["patient"] += contracted_rate
            continue

        # ── Age limits ───────────────────────────────────────────────
        age = _age_on(patient_dob, today)
        age_limit_exceeded = False
        age_below_minimum = False
        if age is None and (rule.get("age_limit_min") or rule.get("age_limit_max")):
            missing.append("patient_dob (age limit not evaluated)")
        elif age is not None:
            lo, hi = rule.get("age_limit_min"), rule.get("age_limit_max")
            if hi is not None and age > hi:
                age_limit_exceeded = True
            if lo is not None and age < lo:
                age_below_minimum = True

        # ── Waiting period ───────────────────────────────────────────
        # eligibility_profiles.waiting_period_met is authoritative (the
        # payer said it). None means unknown, which is NOT "not met" —
        # treating it as a failure would zero the plan's share on every
        # case where the 271 stayed quiet.
        waiting_not_met = waiting_met is False

        payable = not (age_limit_exceeded or age_below_minimum or waiting_not_met)

        # ── Money ────────────────────────────────────────────────────
        benefit_pct = as_float(rule.get("benefit_pct"))
        if benefit_pct is None:
            benefit_pct = as_float(rule.get("coverage_pct")) or default_pct

        if payable:
            if rule.get("deductible_applies", True):
                ded_applied = round(min(deductible_remaining, contracted_rate), 2)
                deductible_remaining = round(deductible_remaining - ded_applied, 2)
            else:
                ded_applied = 0.0

            after_deductible = round(contracted_rate - ded_applied, 2)
            ins_would_pay = round(after_deductible * (benefit_pct / 100.0), 2)

            if ins_would_pay > annual_max_remaining:
                ins_pays = round(annual_max_remaining, 2)
                annual_max_exhausted = True
            else:
                ins_pays = ins_would_pay
                annual_max_exhausted = False

            annual_max_remaining = round(annual_max_remaining - ins_pays, 2)
            pt_pays = round(ded_applied + (after_deductible - ins_pays), 2)
        else:
            ded_applied = 0.0
            ins_pays = 0.0
            pt_pays = round(contracted_rate, 2)
            annual_max_exhausted = False

        if rule.get("pre_d_required"):
            pre_d_required_for.append(cdt)

        procedures_result.append({
            "cdt_code": cdt, "tooth_number": proc.tooth_number,
            "covered": True, "benefit_pct": benefit_pct,
            "benefit_category": rule.get("benefit_category"),
            "provider_ucr_fee": round(ucr_fee, 2),
            "contracted_rate": round(contracted_rate, 2),
            "provider_discount": provider_discount,
            "deductible_applied": ded_applied,
            "insurance_pays": ins_pays,
            "patient_pays": pt_pays,
            "annual_max_exhausted": annual_max_exhausted,
            "not_covered_reason": None,
            "age_limit_exceeded": age_limit_exceeded,
            "age_below_minimum": age_below_minimum,
            "waiting_period_not_met": waiting_not_met,
            "downgrade_applied": downgrade_applied,
            "downgrade_from": downgrade_from,
            "downgrade_to": downgrade_to,
            "pre_d_required": bool(rule.get("pre_d_required")),
            "lifetime_maximum": rule.get("lifetime_maximum"),
            "rate_source": rate_source,
            "rate_is_estimated": cdt in estimated_rate_codes,
            "used_safe_default_rule": used_default_rule,
        })

        totals["ucr"] += ucr_fee
        totals["contracted"] += contracted_rate
        totals["discount"] += provider_discount
        totals["deductible"] += ded_applied
        totals["insurance"] += ins_pays
        totals["patient"] += pt_pays

    # Every rate on this case is estimated rather than read from a
    # published schedule. See PRD Known Gap on fee provenance.
    if estimated_rate_codes:
        missing.append(
            f"published fee schedule for {', '.join(sorted(set(estimated_rate_codes)))} "
            f"(rates are estimates, not the payer's published allowed amount)"
        )
    if any(p.get("lifetime_maximum") for p in procedures_result):
        missing.append("lifetime_max_used (requires X12 271 history)")

    return {
        "procedures": procedures_result,
        "summary": {
            "total_ucr_fee": round(totals["ucr"], 2),
            "total_contracted": round(totals["contracted"], 2),
            "total_provider_discount": round(totals["discount"], 2),
            "total_deductible": round(totals["deductible"], 2),
            "total_insurance_pays": round(totals["insurance"], 2),
            "total_patient_pays": round(totals["patient"], 2),
            "annual_max_remaining_after": round(annual_max_remaining, 2),
            "annual_max_exhausted": annual_max_remaining <= 0,
            "deductible_remaining_after": round(deductible_remaining, 2),
            "patient_savings_in_network": round(totals["discount"], 2),
            "annual_max_used_this_case": round(totals["insurance"], 2),
            "payer_id": payer,
            "state": state,
        },
        "coverage_gaps": coverage_gaps,
        "pre_d_required_for": pre_d_required_for,
        "rates_estimated": sorted(set(estimated_rate_codes)),
        "data_source": (
            "coverage_rules (payer_id, cdt_code) + fee_schedules "
            "(payer_id, cdt_code, state) + eligibility_profiles "
            "deductible/annual_max/benefit_pct"
        ),
        "missing_inputs": sorted(set(missing)),
    }
