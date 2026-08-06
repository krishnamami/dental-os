"""
T-18 — Is this denial worth appealing?

VIABILITY IS ABOUT THE KIND OF DENIAL, NOT ITS SIZE

  Clinical denials are arguable. "Criteria not met" and "not separately
  payable" both turn on evidence, and evidence can be added.

  Administrative denials are not. A waiting period, a frequency limit
  and a plan exclusion are date or contract facts. No documentation
  changes them, and an appeal wastes the practice's time and the
  patient's.

DENIAL CODES AS THEY ACTUALLY APPEAR (live RDS, 2026-08-05)
  D.1.2  implants excluded            exclusion    NOT viable
  D.1.4  missing tooth clause         exclusion    NOT viable
  D.2.1  waiting period not met       date         NOT viable
  D.3.1  frequency limit exceeded     date         NOT viable
  D.4.1  clinical criteria not met    clinical     viable if close

The task spec expected a 'D.7.4' bundling denial code. No such denial
exists in the data — D.7.4 is the bundling POLICY SECTION carried on
bundling_rules, and the bundling case (DA-B04) comes back PENDED with
COVERAGE_BUNDLING_CONFLICT on its pend_checklist rather than denied
with a code. Bundling viability is therefore detected from the
checklist and from the bundling rule, not from a denial code.
"""
from __future__ import annotations

from datetime import date
from typing import Any, Optional

from core.resolvers.base import as_date, as_float, find_evidence, safe_resolver

# appeal_specialist escalates inside this window (decisions.yaml).
DEADLINE_WARNING_DAYS = 14

# Published overturn rate for a documented D7953 unbundling appeal
# (dental-simulator PRD section 10).
BUNDLING_SUCCESS_PROBABILITY = 0.65
CRITERIA_CLOSE_SUCCESS = 0.45
CRITERIA_FAR_SUCCESS = 0.20

# Denial-code prefix -> (category, appealable, why)
DENIAL_CATEGORIES = {
    "D.1": ("plan_exclusion", False,
            "Plan exclusion is a contract term, not a determination. "
            "Nothing in the chart changes what the plan covers."),
    "D.2": ("waiting_period", False,
            "Waiting periods are date arithmetic. No documentation "
            "shortens one."),
    "D.3": ("frequency_limit", False,
            "Frequency limits are date arithmetic against prior "
            "treatment. Not clinically arguable."),
    "D.4": ("clinical_criteria", True,
            "Clinical criteria turn on evidence, and evidence can be "
            "added or re-read."),
}


def _category(code: Optional[str]) -> tuple[str, Optional[bool], str]:
    if not code:
        return "unknown", None, "No denial reason code supplied by the payer."
    for prefix, (name, appealable, why) in DENIAL_CATEGORIES.items():
        if code.startswith(prefix):
            return name, appealable, why
    return "unrecognised", None, f"Denial code {code!r} is not mapped to an appeal path."


@safe_resolver
def resolve_appeal_viability(context: Any, rules: dict, *, today: date = None) -> dict:
    """Sync. DB-less. Reads from bundle only."""
    today = today or date.today()
    resp = getattr(context, "payer_response", None)
    missing: list[str] = []

    if resp is None:
        return {
            "applicable": False,
            "viable": None,
            "success_probability": None,
            "reason": "No payer response on file — nothing to appeal yet.",
            "data_source": "payer_responses",
            "missing_inputs": ["payer_response"],
        }

    decision = (resp.decision or "").lower()
    # decisions.yaml: appeal_specialist runs on denied OR pended.
    if decision not in ("denied", "pended"):
        return {
            "applicable": False,
            "viable": None,
            "success_probability": None,
            "decision": decision,
            "reason": f"Payer decision is {decision!r} — no appeal path applies.",
            "data_source": "payer_responses.decision",
            "missing_inputs": [],
        }

    code = resp.denial_reason_code
    category, appealable, why = _category(code)

    # Deadline
    deadline = as_date(resp.appeal_deadline)
    days_remaining = None if deadline is None else (deadline - today).days
    if deadline is None:
        missing.append("appeal_deadline")
    deadline_passed = None if days_remaining is None else days_remaining < 0
    deadline_warning = (
        None if days_remaining is None
        else 0 <= days_remaining <= DEADLINE_WARNING_DAYS
    )

    # What evidence is on file to argue with
    xray = find_evidence(context, "XRAY_PA")
    note = find_evidence(context, "CLINICAL_NOTE")
    cbct = find_evidence(context, "CBCT_REPORT")
    bone_loss = as_float((xray.extracted_fields or {}).get("bone_loss_mm")) if xray else None
    narrative = bool((note.extracted_fields or {}).get("narrative_present")) if note else False

    supporting = [e.s3_key for e in getattr(context, "clinical_evidence", [])
                  if e.s3_key and e.document_type in
                  ("XRAY_PA", "XRAY_PAN", "CBCT_REPORT", "PERIO_CHART", "CLINICAL_NOTE")]

    # Bundling: detected from the pend checklist / open conditions and
    # the catalogue rule, since no denial code carries it.
    checklist = list(getattr(resp, "pend_checklist", []) or [])
    open_conditions = list(getattr(context, "open_conditions", []) or [])
    is_bundling = "COVERAGE_BUNDLING_CONFLICT" in checklist + open_conditions

    bundling_rule = None
    if is_bundling:
        for (a, b), rule in (rules.get("bundling_rules") or {}).items():
            billed = getattr(context, "cdt_codes", []) or []
            if a in billed and b in billed and rule.get("separable"):
                bundling_rule = rule
                break

    wants: list[str] = []
    threshold_mm = as_float(
        ((rules.get("ada_thresholds") or {}).get("D7953") or {}).get("bone_loss_mm_min")
    ) or 3.0

    if is_bundling and bundling_rule is not None:
        # The reference appeal. Viable when the two things the payer's
        # own separation_criteria asks for are on file.
        has_bone = bone_loss is not None and bone_loss >= threshold_mm
        if not has_bone:
            wants.append(f"PA X-ray showing bone loss >= {threshold_mm}mm at the graft site")
        if not narrative:
            wants.append("clinical narrative establishing graft necessity "
                         "INDEPENDENT of implant placement")
        if cbct is None:
            wants.append("CBCT bone-volume analysis (optional, raises the rate)")
        viable = has_bone and narrative
        probability = BUNDLING_SUCCESS_PROBABILITY if viable else 0.25
        strategy = (
            "Unbundle under the payer's own separation criteria: "
            f"{bundling_rule.get('separation_criteria') or 'documented separately'}"
        )
        citation = bundling_rule.get("policy_section")
        category = "bundling_separable"
        appealable = True

    elif appealable is False:
        viable = False
        probability = 0.0
        strategy = f"Do not appeal. {why}"
        citation = code
        wants = []

    elif category == "clinical_criteria":
        score = as_float(getattr(context, "criteria_score", None))
        deny_floor = as_float(
            ((rules.get("ada_thresholds") or {}).get("D4260") or {}).get("auto_deny_score")
        ) or 0.30
        if score is None:
            missing.append("criteria_score")
            viable = None
            probability = None
        else:
            close = score >= deny_floor
            viable = close
            probability = CRITERIA_CLOSE_SUCCESS if close else CRITERIA_FAR_SUCCESS
        if bone_loss is None:
            wants.append("PA X-ray with a readable bone-loss measurement")
        if not narrative:
            wants.append("clinical narrative supporting medical necessity")
        strategy = (
            "Re-argue clinical criteria with the measurements already on file "
            "plus whatever is listed in missing_evidence."
        )
        citation = code

    else:
        viable = None
        probability = None
        strategy = why
        citation = code
        missing.append("denial_reason_code")

    # A passed deadline overrides everything — decisions.yaml blocks on it.
    if deadline_passed:
        viable = False
        probability = 0.0
        strategy = "Appeal deadline has passed. No appeal path remains."

    return {
        "applicable": True,
        "decision": decision,
        "viable": viable,
        "success_probability": probability,
        "denial_category": category,
        "denial_reason_code": code,
        "denial_reason_text": resp.denial_reason_text,
        "category_rationale": why,
        "days_remaining": days_remaining,
        "appeal_deadline": deadline.isoformat() if deadline else None,
        "deadline_warning": deadline_warning,
        "deadline_passed": deadline_passed,
        "supporting_evidence": supporting,
        "missing_evidence": wants,
        "appeal_strategy": strategy,
        "citation": citation,
        "bone_loss_mm": bone_loss,
        "narrative_present": narrative,
        "is_bundling_case": is_bundling,
        "data_source": (
            "payer_responses.decision/denial_reason_code/appeal_deadline + "
            "pend_checklist + clinical_evidence + bundling_rules catalogue"
        ),
        "missing_inputs": missing,
    }
