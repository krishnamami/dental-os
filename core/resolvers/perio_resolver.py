"""
T-17 — Do pocket depths meet the surgical threshold?

Two separate questions, two separate thresholds:

  D4260 osseous surgery   pocket_depth_max >= 5mm AND sites_gte_5mm >= 6
  D4341 SRP               pocket_depth_max >= 4mm

The AND on D4260 is what makes DA-F02 a phantom-procedure case: a chart
showing max 3.0mm and zero deep sites cannot support osseous surgery,
and billing it anyway is the signal fraud_integrity escalates.
"""
from __future__ import annotations

from typing import Any

from core.resolvers.base import (
    PERIO_MAX_AGE_DAYS,
    TRUST_FLOOR,
    as_date,
    as_float,
    as_int,
    evidence_field,
    find_evidence,
    safe_resolver,
    threshold,
)

SAFE_DEFAULT_SURGICAL_MM = 5.0
SAFE_DEFAULT_SRP_MM = 4.0
SAFE_DEFAULT_SITES_REQUIRED = 6


@safe_resolver
def resolve_perio(context: Any, rules: dict, *, today=None) -> dict:
    """Sync. DB-less. Reads from bundle only."""
    from datetime import date as _date

    today = today or _date.today()

    surgical_mm, surgical_governed = threshold(
        rules, "D4260", "pocket_depth_mm_min", SAFE_DEFAULT_SURGICAL_MM
    )
    srp_mm, srp_governed = threshold(
        rules, "D4341", "pocket_depth_mm_min", SAFE_DEFAULT_SRP_MM
    )
    sites_required, sites_governed = threshold(
        rules, "D4260", "sites_min", SAFE_DEFAULT_SITES_REQUIRED
    )
    surgical_mm = as_float(surgical_mm) or SAFE_DEFAULT_SURGICAL_MM
    srp_mm = as_float(srp_mm) or SAFE_DEFAULT_SRP_MM
    sites_required = as_int(sites_required) or SAFE_DEFAULT_SITES_REQUIRED

    perio = find_evidence(context, "PERIO_CHART")
    missing: list[str] = []

    if perio is None:
        missing.append("PERIO_CHART")
        pocket_max = sites_5mm = bleeding = None
    else:
        # The generator writes both pocket_depth_max and the integer
        # max_pocket_depth_mm. Prefer the float.
        pocket_max = as_float(evidence_field(perio, "pocket_depth_max"))
        if pocket_max is None:
            pocket_max = as_float(evidence_field(perio, "max_pocket_depth_mm"))
        if pocket_max is None:
            missing.append("pocket_depth_max")
        sites_5mm = as_int(evidence_field(perio, "sites_gte_5mm"))
        if sites_5mm is None:
            missing.append("sites_gte_5mm")
        bleeding = as_float(evidence_field(perio, "bleeding_pct"))
        if bleeding is None:
            bleeding = as_float(evidence_field(perio, "bleeding_on_probing_pct"))

    # Tri-state throughout. Both halves of the D4260 AND must be known
    # before it can be answered either way.
    if pocket_max is None or sites_5mm is None:
        surgical_met = None
    else:
        surgical_met = pocket_max >= surgical_mm and sites_5mm >= sites_required

    srp_met = None if pocket_max is None else pocket_max >= srp_mm

    # Perio charts go stale faster than radiographs — 6 months, not 12.
    exam_date = as_date(evidence_field(perio, "exam_date")) or as_date(
        getattr(perio, "received_at", None)
    )
    days_old = None if exam_date is None else (today - exam_date).days
    is_current = None if days_old is None else days_old <= PERIO_MAX_AGE_DAYS

    confidence = as_float(getattr(perio, "confidence_score", None))

    return {
        "pocket_depth_max": pocket_max,
        "pocket_depth_avg": as_float(evidence_field(perio, "pocket_depth_avg")),
        "sites_gte_5mm": sites_5mm,
        "sites_gte_4mm": as_int(evidence_field(perio, "sites_gte_4mm")),
        "sites_gte_6mm": as_int(evidence_field(perio, "sites_gte_6mm")),
        "sites_charted": as_int(evidence_field(perio, "sites_charted")),
        "bleeding_pct": bleeding,
        "perio_diagnosis": evidence_field(perio, "perio_diagnosis"),
        "interpretation": evidence_field(perio, "interpretation"),
        "surgical_threshold_met": surgical_met,
        "srp_threshold_met": srp_met,
        "surgical_threshold_mm": surgical_mm,
        "srp_threshold_mm": srp_mm,
        "sites_required": sites_required,
        "thresholds_governed_by": {
            "surgical_mm": surgical_governed,
            "srp_mm": srp_governed,
            "sites_required": sites_governed,
        },
        "perio_present": perio is not None,
        "perio_confidence": confidence,
        "perio_below_trust_floor": (
            None if confidence is None else confidence < TRUST_FLOOR
        ),
        "exam_date": exam_date.isoformat() if exam_date else None,
        "days_old": days_old,
        "is_current": is_current,
        "max_age_days": PERIO_MAX_AGE_DAYS,
        "data_source": "clinical_evidence[PERIO_CHART].extracted_fields",
        "missing_inputs": missing,
    }
