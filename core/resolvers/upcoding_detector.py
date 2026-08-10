"""
T-20 — Does the billed CDT match what the chart documents?

THIS DETECTOR DOES NOT ACCUSE ANYONE.

Every signal here is a MISMATCH between two records. A surface conflict
between a note and a radiograph is far more often a charting slip than
fraud, and upcoding is far more often a template default than intent.
The job is to put both values side by side; the billing manager decides
what it means. That is why fraud_integrity is human_approval and why
every signal carries the two values it compared.

Signals, per decisions.yaml fraud_integrity.signals_emitted:
  INTEGRITY_CODE_NOT_DOCUMENTED  billed procedure the chart cannot support
  INTEGRITY_SURFACE_MISMATCH   billed surface disagrees with the radiograph
  INTEGRITY_FREQUENCY_PROXIMITY   procedure lands just inside a frequency limit
  INTEGRITY_FEE_EQUALS_ALLOWED       submitted fee exactly equals the allowed amount
  BILLING_UNBILLED_PROCEDURE  the chart documents work not on the claim

⚠ FRAUD_UPCODING IS NO LONGER EMITTED, and the reason matters.

Its definition is "billed code richer than the note documents". The
branch that carried the name tested the OPPOSITE — it fired when the
note listed a code the claim did not, which is under-billing. Every
firing accused a practice of upcoding on evidence that they had
under-charged.

Detecting the real thing needs a way to rank two CDT codes by richness
(D2394 four-surface against D2391 one-surface). `cdt_codes` carries no
tier, rank or relative-value column, and `fee_schedules` prices codes
per payer rather than ordering them clinically. So the check cannot be
written from what exists, and leaving a differently-shaped check under
its name was worse than not having it. The under-billing finding it
actually computed is real and is kept, correctly named.
"""
from __future__ import annotations

from typing import Any

from core.resolvers.base import (
    as_float,
    as_list,
    evidence_field,
    find_evidence,
    safe_resolver,
)

# Codes whose ADA criteria gate on periodontal surgical depth.
PERIO_SURGICAL_CODES = ("D4260", "D4261")
SAFE_DEFAULT_SURGICAL_MM = 5.0
SAFE_DEFAULT_SITES_REQUIRED = 6


def _signal(signal_type: str, cdt_code: str, evidence: str, severity: str) -> dict:
    return {
        "signal_type": signal_type,
        "cdt_code": cdt_code,
        "evidence": evidence,
        "severity": severity,
    }


@safe_resolver
def resolve_upcoding(context: Any, rules: dict) -> dict:
    """Sync. DB-less. Reads from bundle only."""
    signals: list[dict] = []
    missing: list[str] = []

    procedures = list(getattr(context, "procedures", []) or [])
    billed_codes = [p.cdt_code for p in procedures]

    note = find_evidence(context, "CLINICAL_NOTE")
    if note is None:
        missing.append("clinical_note")
        note_codes: list[str] = []
    else:
        note_codes = [str(c) for c in as_list(evidence_field(note, "cdt_codes_noted"))]

    xray = find_evidence(context, "XRAY_PA")
    perio = find_evidence(context, "PERIO_CHART")

    # ── BILLING_UNBILLED_PROCEDURE ───────────────────────────────────
    # The note lists a code that was NOT billed, alongside one that was.
    # The chart recorded more work than the claim asks to be paid for.
    #
    # This is revenue leakage or a charting slip, NOT an integrity
    # concern, and it is severity "medium" rather than "high" for the
    # same reason: nobody is being over-charged. It used to be emitted
    # as FRAUD_UPCODING — see the module docstring.
    for proc in procedures:
        extra = [c for c in note_codes if c not in billed_codes]
        if note_codes and proc.cdt_code in note_codes and extra:
            signals.append(_signal(
                "BILLING_UNBILLED_PROCEDURE",
                proc.cdt_code,
                f"Clinical note documents {note_codes} but only {billed_codes} "
                f"billed. {', '.join(extra)} appears in the chart and not on the "
                f"claim — confirm which procedure was actually performed.",
                "medium",
            ))
            break

    # A billed code the note never mentions at all.
    if note_codes:
        undocumented = [c for c in billed_codes if c not in note_codes]
        for code in undocumented:
            signals.append(_signal(
                "INTEGRITY_CODE_NOT_DOCUMENTED",
                code,
                f"{code} is billed but does not appear in the clinical note "
                f"({note_codes}). Either the note is incomplete or the code is.",
                "high",
            ))

    # ── INTEGRITY_CODE_NOT_DOCUMENTED (clinical criteria) ──────────────────
    # Osseous surgery billed against a chart that cannot support it.
    if perio is not None:
        pocket_max = as_float(evidence_field(perio, "pocket_depth_max"))
        if pocket_max is None:
            pocket_max = as_float(evidence_field(perio, "max_pocket_depth_mm"))
        sites = as_float(evidence_field(perio, "sites_gte_5mm"))
        ada = (rules.get("ada_thresholds") or {}).get("D4260") or {}
        need_mm = as_float(ada.get("pocket_depth_mm_min")) or SAFE_DEFAULT_SURGICAL_MM
        need_sites = as_float(ada.get("sites_min")) or SAFE_DEFAULT_SITES_REQUIRED

        for proc in procedures:
            if proc.cdt_code not in PERIO_SURGICAL_CODES:
                continue
            if pocket_max is None or sites is None:
                missing.append("perio pocket_depth_max / sites_gte_5mm")
                continue
            if pocket_max < need_mm or sites < need_sites:
                signals.append(_signal(
                    "INTEGRITY_CODE_NOT_DOCUMENTED",
                    proc.cdt_code,
                    f"{proc.cdt_code} billed, but the perio chart shows a max "
                    f"pocket depth of {pocket_max}mm across {int(sites)} site(s) "
                    f">=5mm. AAP criteria require >={need_mm}mm in "
                    f">={int(need_sites)} sites.",
                    "high",
                ))
    elif any(p.cdt_code in PERIO_SURGICAL_CODES for p in procedures):
        missing.append("perio_chart")

    # ── INTEGRITY_SURFACE_MISMATCH ───────────────────────────────────────
    if xray is not None:
        xray_surface = evidence_field(xray, "tooth_surface")
        if xray_surface:
            for proc in procedures:
                billed_surface = proc.tooth_surface
                if not billed_surface:
                    continue
                if set(str(billed_surface).upper()) != set(str(xray_surface).upper()):
                    signals.append(_signal(
                        "INTEGRITY_SURFACE_MISMATCH",
                        proc.cdt_code,
                        f"Billed surface {billed_surface} on tooth "
                        f"#{proc.tooth_number} but the radiograph reads "
                        f"{xray_surface}.",
                        "medium",
                    ))

    # ── INTEGRITY_FEE_EQUALS_ALLOWED ───────────────────────────────────────────
    # Submitted fee exactly equal to the allowed amount means the
    # patient portion nets to zero — a routine write-off of coinsurance
    # is a compliance issue regardless of intent.
    for proc in procedures:
        fee = as_float(proc.fee_submitted)
        allowed = as_float(proc.allowed_amount)
        if fee is None or allowed is None:
            continue
        if abs(fee - allowed) < 0.005:
            signals.append(_signal(
                "INTEGRITY_FEE_EQUALS_ALLOWED",
                proc.cdt_code,
                f"Submitted fee ${fee:,.2f} exactly equals the allowed amount "
                f"${allowed:,.2f} on {proc.cdt_code}. The patient portion nets "
                f"to zero.",
                "medium",
            ))

    # ── INTEGRITY_FREQUENCY_PROXIMITY ───────────────────────────────────────
    # Delegated to frequency_resolver, which owns the prior-date lookup.
    # It currently cannot fire: dental-simulator has no prior treatment
    # dates at all, so "just inside the limit" is not computable.
    freq = rules.get("_frequency_findings")
    if isinstance(freq, dict):
        for v in freq.get("frequency_violations", []):
            if v.get("near_limit"):
                signals.append(_signal(
                    "INTEGRITY_FREQUENCY_PROXIMITY",
                    v["cdt_code"],
                    f"{v['cdt_code']} last treated {v['days_since_last']} days ago "
                    f"against a {v['days_required']}-day limit — inside the "
                    f"30-day gaming window.",
                    "medium",
                ))
    else:
        missing.append("last_treatment_date (frequency gaming not computable)")

    ordered = sorted(signals, key=lambda s: 0 if s["severity"] == "high" else 1)

    return {
        "signals": ordered,
        "any_fraud_signal": bool(ordered),
        "high_severity_count": sum(1 for s in ordered if s["severity"] == "high"),
        "signal_types": sorted({s["signal_type"] for s in ordered}),
        "billed_codes": billed_codes,
        "note_codes": note_codes,
        "clinical_note_present": note is not None,
        "data_source": (
            "procedure_lines + clinical_evidence[CLINICAL_NOTE].cdt_codes_noted + "
            "[PERIO_CHART] + [XRAY_PA] + cost_estimates.allowed_amount"
        ),
        "missing_inputs": sorted(set(missing)),
    }
