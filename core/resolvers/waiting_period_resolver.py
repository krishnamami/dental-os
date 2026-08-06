"""
T-13 — Is the plan's waiting period met for this pre-D?

A waiting period is a date computation, not a clinical judgement: it is
either satisfied or it is not, and no documentation changes it. That is
also why a waiting-period denial is not appealable (see
appeal_viability_resolver).
"""
from __future__ import annotations

from datetime import date
from typing import Any

from core.resolvers.base import as_date, months_between, safe_resolver

# RULE 9 fallbacks. Delta Dental PPO's published defaults.
SAFE_DEFAULT_BASIC_MONTHS = 6
SAFE_DEFAULT_MAJOR_MONTHS = 12
SAFE_DEFAULT_IMPLANT_MONTHS = 12


@safe_resolver
def resolve_waiting_period(context: Any, rules: dict, *, today: date = None) -> dict:
    """Sync. DB-less. Reads from bundle only."""
    today = today or date.today()
    elig = getattr(context, "eligibility", None)
    missing: list[str] = []
    used_defaults: list[str] = []

    enrollment_start = as_date(getattr(elig, "enrollment_start", None))
    if enrollment_start is None:
        missing.append("enrollment_start")

    def _months(attr: str, fallback: int, label: str) -> int:
        value = getattr(elig, attr, None)
        if value is None:
            used_defaults.append(label)
            return fallback
        return int(value)

    req_basic = _months("waiting_period_basic_months", SAFE_DEFAULT_BASIC_MONTHS, "basic")
    req_major = _months("waiting_period_major_months", SAFE_DEFAULT_MAJOR_MONTHS, "major")
    req_implant = _months(
        "waiting_period_implant_months", SAFE_DEFAULT_IMPLANT_MONTHS, "implant"
    )

    months_enrolled = months_between(enrollment_start, today)

    # Which period actually applies depends on what is being billed.
    # A D6-prefixed code is an implant service; anything else billed on
    # a pre-D is major. Using the implant period for a crown would
    # over-report a shortfall.
    cdt_codes = list(getattr(context, "cdt_codes", []) or [])
    has_implant = any(str(c).upper().startswith("D6") for c in cdt_codes)
    applicable_months = req_implant if has_implant else req_major
    applicable_category = "implant" if has_implant else "major"

    if months_enrolled is None:
        implant_met = major_met = basic_met = None
        applicable_met = None
        months_short = None
    else:
        implant_met = months_enrolled >= req_implant
        major_met = months_enrolled >= req_major
        basic_met = months_enrolled >= req_basic
        applicable_met = months_enrolled >= applicable_months
        months_short = max(applicable_months - months_enrolled, 0)

    # The assembler's own conclusion, for comparison. Reported rather
    # than trusted: if the two disagree that is worth a human's eye.
    state_flag = getattr(elig, "waiting_period_met", None)
    disagrees = (
        applicable_met is not None
        and state_flag is not None
        and bool(state_flag) != bool(applicable_met)
    )

    return {
        "waiting_period_met": applicable_met,
        "months_enrolled": months_enrolled,
        "months_required_applicable": applicable_months,
        "applicable_category": applicable_category,
        "months_required_implant": req_implant,
        "months_required_major": req_major,
        "months_required_basic": req_basic,
        "months_short": months_short,
        "implant_waiting_met": implant_met,
        "major_waiting_met": major_met,
        "basic_waiting_met": basic_met,
        "enrollment_start": enrollment_start.isoformat() if enrollment_start else None,
        "evaluated_on": today.isoformat(),
        "billed_cdt_codes": cdt_codes,
        "pred_state_waiting_period_met": state_flag,
        "disagrees_with_pred_state": disagrees,
        "used_safe_defaults": used_defaults,
        "data_source": (
            "patients.enrollment_start + plans.waiting_period_*_months "
            "(via vw_eligibility_context); pred_states.waiting_period_met "
            "reported for comparison only"
        ),
        "missing_inputs": missing,
    }
