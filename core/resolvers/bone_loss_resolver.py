"""
T-16 — Does the X-ray show bone loss meeting the ADA threshold?

This resolver surfaces a measurement against a threshold. It does NOT
diagnose. bone_loss_mm 4.2 against a >=3.0mm requirement means the
documentation supports the procedure under ADA criteria; whether the
patient needs the graft is Dr. Chinta's call.

The threshold is per-code: D6010 and D7953 both require >=3.0mm, but
they are separate catalogue rows and either can move independently.
"""
from __future__ import annotations

from typing import Any

from core.resolvers.base import (
    TRUST_FLOOR,
    as_float,
    as_int,
    evidence_field,
    find_evidence,
    safe_resolver,
    threshold,
)

SAFE_DEFAULT_BONE_LOSS_MM = 3.0

# Codes whose ADA criteria gate on radiographic bone loss.
BONE_LOSS_CODES = ("D6010", "D7953")


@safe_resolver
def resolve_bone_loss(context: Any, rules: dict, *, cdt_code: str = None) -> dict:
    """Sync. DB-less. Reads from bundle only."""
    # Score against a code actually billed on this pre-D when one of the
    # bone-loss codes is present; fall back to D6010 as the reference.
    billed = [c for c in (getattr(context, "cdt_codes", []) or [])]
    if cdt_code is None:
        cdt_code = next((c for c in billed if c in BONE_LOSS_CODES), "D6010")

    threshold_mm, governed_by = threshold(
        rules, cdt_code, "bone_loss_mm_min", SAFE_DEFAULT_BONE_LOSS_MM
    )
    threshold_mm = as_float(threshold_mm) or SAFE_DEFAULT_BONE_LOSS_MM

    xray = find_evidence(context, "XRAY_PA")
    missing: list[str] = []

    if xray is None:
        missing.append("XRAY_PA")
        missing.append("bone_loss_mm")
        bone_loss_mm = None
    else:
        bone_loss_mm = as_float(evidence_field(xray, "bone_loss_mm"))
        if bone_loss_mm is None:
            # The document exists but the field did not extract. That is
            # a different problem from "no X-ray" and must not read the
            # same to whoever has to fix it.
            missing.append("bone_loss_mm")

    # Tri-state: None means nobody looked, which is not the same as
    # "criteria not met". See base.py.
    criteria_met = None if bone_loss_mm is None else bone_loss_mm >= threshold_mm
    margin = None if bone_loss_mm is None else round(bone_loss_mm - threshold_mm, 2)

    confidence = as_float(getattr(xray, "confidence_score", None))
    below_floor = None if confidence is None else confidence < TRUST_FLOOR

    ada = (rules.get("ada_thresholds") or {}).get(cdt_code) or {}

    return {
        "bone_loss_mm": bone_loss_mm,
        "bone_loss_pct": as_float(evidence_field(xray, "bone_loss_pct")),
        "threshold_mm": threshold_mm,
        "threshold_governed_by": governed_by,
        "criteria_met": criteria_met,
        "margin_mm": margin,
        "evaluated_cdt_code": cdt_code,
        "tooth_number": as_int(evidence_field(xray, "tooth_number")),
        "pathology": evidence_field(xray, "pathology"),
        "image_quality": evidence_field(xray, "image_quality"),
        "date_taken": evidence_field(xray, "date_taken"),
        "xray_present": xray is not None,
        "xray_confidence": confidence,
        "xray_below_trust_floor": below_floor,
        "xray_s3_key": getattr(xray, "s3_key", None),
        "extraction_method": getattr(xray, "extraction_method", None),
        "citation": ada.get("citation"),
        "data_source": "clinical_evidence[XRAY_PA].extracted_fields.bone_loss_mm",
        "missing_inputs": missing,
    }
