"""
T-19 — What documents are present versus required?

Required is derived per billed CDT code from cdt_rules, not from a
fixed list: D6010 needs an X-ray and a narrative, D4341 needs a perio
chart, D0330 needs neither. A fixed checklist would demand documents
nobody asked for and miss ones that matter.

Three ways a document can fail, and they are NOT the same problem:
  MISSING      no such document on file
  LOW CONF     present, but extracted below TRUST_FLOOR (0.70)
  OUTDATED     present, but older than its currency window
Each routes to a different action, so each is reported separately.
"""
from __future__ import annotations

from datetime import date
from typing import Any

from core.resolvers.base import (
    PERIO_MAX_AGE_DAYS,
    TRUST_FLOOR,
    XRAY_MAX_AGE_DAYS,
    as_bool,
    as_date,
    as_float,
    find_evidence,
    safe_resolver,
)

# cdt_rules flag -> (document_type, max age in days)
REQUIREMENT_MAP = {
    "requires_xray": ("XRAY_PA", XRAY_MAX_AGE_DAYS),
    "requires_perio_chart": ("PERIO_CHART", PERIO_MAX_AGE_DAYS),
    "requires_narrative": ("CLINICAL_NOTE", None),
    "requires_medical_clearance": ("MEDICAL_CLEARANCE", None),
}


@safe_resolver
def resolve_completeness(context: Any, rules: dict, *, today: date = None) -> dict:
    """Sync. DB-less. Reads from bundle only."""
    today = today or date.today()
    cdt_rules = rules.get("cdt_rules") or {}

    billed = list(dict.fromkeys(getattr(context, "cdt_codes", []) or []))
    missing_inputs: list[str] = []
    if not billed:
        missing_inputs.append("procedure_lines")

    # ── Which documents does THIS pre-D require? ─────────────────────
    required: dict[str, bool] = {doc: False for doc, _ in REQUIREMENT_MAP.values()}
    required_by: dict[str, list[str]] = {}
    uncatalogued: list[str] = []

    for code in billed:
        rule = cdt_rules.get(code)
        if rule is None:
            uncatalogued.append(code)
            continue
        for flag, (doc_type, _) in REQUIREMENT_MAP.items():
            if rule.get(flag):
                required[doc_type] = True
                required_by.setdefault(doc_type, []).append(code)
    if uncatalogued:
        missing_inputs.append(
            f"cdt_rules for {', '.join(uncatalogued)} (requirements unknown)"
        )

    # ── What is actually on file? ────────────────────────────────────
    present: dict[str, dict] = {}
    missing_docs: list[str] = []
    low_confidence: list[dict] = []
    outdated: list[dict] = []

    for doc_type, is_required in required.items():
        max_age = next(
            (age for _, (dt, age) in REQUIREMENT_MAP.items() if dt == doc_type), None
        )
        ev = find_evidence(context, doc_type)

        if ev is None:
            present[doc_type] = {"present": False}
            if is_required:
                missing_docs.append(doc_type)
            continue

        confidence = as_float(ev.confidence_score)
        received = as_date(ev.received_at) or as_date(
            (ev.extracted_fields or {}).get("exam_date")
        ) or as_date((ev.extracted_fields or {}).get("date_taken"))
        days_old = None if received is None else (today - received).days
        current = (
            None if (days_old is None or max_age is None) else days_old <= max_age
        )

        entry = {
            "present": True,
            "s3_key": ev.s3_key,
            "confidence": confidence,
            "extraction_method": ev.extraction_method,
            "received_at": ev.received_at,
            "days_old": days_old,
            "current": current,
            "max_age_days": max_age,
            # A structured payload with no PDF behind it is still
            # evidence, but it is not a document a payer can be sent.
            "has_file": ev.s3_key is not None,
        }
        present[doc_type] = entry

        if is_required:
            if confidence is not None and confidence < TRUST_FLOOR:
                low_confidence.append({
                    "document_type": doc_type,
                    "confidence": confidence,
                    "trust_floor": TRUST_FLOOR,
                    "s3_key": ev.s3_key,
                })
            if current is False:
                outdated.append({
                    "document_type": doc_type,
                    "received_at": ev.received_at,
                    "days_old": days_old,
                    "max_age_days": max_age,
                })

    # ── Narrative is a FIELD, not just a document ────────────────────
    # A CLINICAL_NOTE can be on file with narrative_present false. For
    # D7953 that distinction is the whole case: the note has to
    # establish necessity independent of the implant.
    note = find_evidence(context, "CLINICAL_NOTE")
    narrative_present = as_bool((note.extracted_fields or {}).get("narrative_present")) if note else False
    if required.get("CLINICAL_NOTE") and note is not None and not narrative_present:
        missing_docs.append("CLINICAL_NOTE.narrative")

    # ── Score ────────────────────────────────────────────────────────
    # Denominator is what THIS pre-D requires. A case requiring nothing
    # scores 1.0 rather than dividing by zero.
    required_types = [d for d, req in required.items() if req]
    if not required_types:
        score = 1.0
    else:
        satisfied = sum(
            1 for d in required_types
            if present.get(d, {}).get("present")
            and present[d].get("current") is not False
            and (present[d].get("confidence") is None
                 or present[d]["confidence"] >= TRUST_FLOOR)
            and (d != "CLINICAL_NOTE" or narrative_present)
        )
        score = round(satisfied / len(required_types), 3)

    return {
        "required_docs": required,
        "required_by_code": required_by,
        "present_docs": present,
        "missing_docs": missing_docs,
        "low_confidence_docs": low_confidence,
        "outdated_docs": outdated,
        "narrative_present": narrative_present,
        "completeness_score": score,
        "is_complete": not missing_docs and not low_confidence and not outdated,
        "billed_cdt_codes": billed,
        "uncatalogued_codes": uncatalogued,
        "trust_floor": TRUST_FLOOR,
        "data_source": "clinical_evidence + cdt_rules catalogue (requires_* flags)",
        "missing_inputs": missing_inputs,
    }
