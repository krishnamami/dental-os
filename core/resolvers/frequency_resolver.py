"""
T-14 — Has a frequency limit been exceeded for any billed procedure?

READ THIS BEFORE TRUSTING THE OUTPUT

dental-simulator carries NO prior-treatment dates. There are zero
EOB_PRIOR documents, and no extracted_fields key anywhere holds a last
service date (verified against the live RDS 2026-08-05). So for every
one of the 35 scenarios this resolver can state the LIMIT but not
whether it was breached.

That is reported honestly rather than papered over: `exceeded` is None
(not False) for any code whose last treatment date is unknown, and
"last_treatment_date" appears in missing_inputs. Returning False would
assert "frequency is fine" on evidence nobody has — which is exactly
the claim a payer denies on.

The lookup path is written and tested; it activates the moment prior
dates land in clinical_evidence or an EOB_PRIOR feed exists.
"""
from __future__ import annotations

from datetime import date
from typing import Any, Optional

from core.resolvers.base import as_date, safe_resolver

# Period label -> days. per_lifetime is a sentinel: any prior treatment
# breaches it, so it needs no day count.
PERIOD_DAYS: dict[str, Optional[int]] = {
    "per_year": 365,
    "per_1_year": 365,
    "per_2_years": 730,
    "per_3_years": 1095,
    "per_4_years": 1460,
    "per_5_years": 1825,
    "per_7_years": 2555,
    "per_6_months": 183,
    "per_lifetime": None,
}
# Verified complete against the catalogue 2026-08-05: frequency_limits
# uses exactly per_year, per_2/3/4/5/7_years and per_lifetime. An
# unmapped label is reported in missing_inputs rather than silently
# treated as unlimited — it was per_7_years (D6065) that exposed the
# gap, and a code with no day count would otherwise read as "no limit".

SAFE_DEFAULT_PERIOD = "per_5_years"

# Where a prior date might live once the data exists. Checked in order.
PRIOR_DATE_KEYS = (
    "last_treatment_date",
    "last_approved_date",
    "prior_service_date",
    "last_service_date",
    "service_date",
)
PRIOR_DATE_DOCS = ("EOB_PRIOR", "PRED_LETTER", "PRED_LETTER_APPROVED")

# fraud_integrity escalates when a procedure lands just inside a limit.
GAMING_WINDOW_DAYS = 30


def _find_prior_date(context: Any, cdt_code: str) -> tuple[Optional[date], Optional[str]]:
    """Most recent prior-treatment date for a code, if the data exists."""
    best: Optional[date] = None
    src: Optional[str] = None
    for ev in getattr(context, "clinical_evidence", []) or []:
        if ev.document_type not in PRIOR_DATE_DOCS:
            continue
        fields = ev.extracted_fields or {}
        codes = fields.get("cdt_codes") or fields.get("approved_codes") or []
        if codes and cdt_code not in codes:
            continue
        for key in PRIOR_DATE_KEYS:
            d = as_date(fields.get(key))
            if d and (best is None or d > best):
                best, src = d, f"{ev.document_type}.{key}"
    return best, src


@safe_resolver
def resolve_frequency(context: Any, rules: dict, *, today: date = None) -> dict:
    """Sync. DB-less. Reads from bundle only."""
    today = today or date.today()
    payer_id = getattr(context, "payer_id", None) or "delta_dental"
    limits = rules.get("frequency_limits") or {}

    violations: list[dict] = []
    missing: set[str] = set()
    unknown_dates = 0

    seen: set[str] = set()
    for proc in getattr(context, "procedures", []) or []:
        cdt = proc.cdt_code
        if cdt in seen:
            continue
        seen.add(cdt)

        limit = limits.get((payer_id, cdt))
        if limit is None:
            # No limit on file for this payer+code is not a violation —
            # it means the code is unlimited or simply uncatalogued.
            continue

        period = limit.get("frequency_period") or SAFE_DEFAULT_PERIOD
        days_required = PERIOD_DAYS.get(period)
        if period not in PERIOD_DAYS:
            missing.add(f"unknown frequency_period {period!r} for {cdt}")

        last_date, date_source = _find_prior_date(context, cdt)
        if last_date is None:
            unknown_dates += 1
            missing.add("last_treatment_date")
            exceeded = None
            days_since = None
            near_limit = None
        else:
            days_since = (today - last_date).days
            if period == "per_lifetime":
                exceeded = True
                near_limit = False
            elif days_required is None:
                exceeded = None
                near_limit = None
            else:
                exceeded = days_since < days_required
                # Symmetric around the boundary, deliberately. Gaming
                # looks like a procedure landing right AT the limit —
                # DA-F03 bills a crown 4y11m into a 5-year limit (15
                # days short, denied), and the mirror image is billing
                # 15 days after it clears. Both are the same behaviour
                # and both deserve a human's eye; only checking one side
                # would miss half of it.
                near_limit = abs(days_since - days_required) <= GAMING_WINDOW_DAYS

        violations.append({
            "cdt_code": cdt,
            "tooth_number": proc.tooth_number,
            "frequency_count": limit.get("frequency_count"),
            "frequency_period": period,
            "frequency_scope": limit.get("frequency_scope"),
            "last_treatment_date": last_date.isoformat() if last_date else None,
            "last_treatment_source": date_source,
            "days_since_last": days_since,
            "days_required": days_required,
            "exceeded": exceeded,
            "near_limit": near_limit,
            "payer_id": payer_id,
            "governed_by": limit.get("governed_by", "payer"),
        })

    determinable = [v for v in violations if v["exceeded"] is not None]

    return {
        "procedures_checked": len(violations),
        "frequency_violations": violations,
        # None, not False: with no prior dates nobody can say. False here
        # would read as "frequency verified clear".
        "any_exceeded": (
            None if not determinable else any(v["exceeded"] for v in determinable)
        ),
        "any_near_limit": (
            None if not determinable else any(v["near_limit"] for v in determinable)
        ),
        "codes_with_limits": len(violations),
        "codes_undeterminable": unknown_dates,
        "payer_id": payer_id,
        "evaluated_on": today.isoformat(),
        "data_source": (
            "frequency_limits catalogue (payer_id, cdt_code) + prior dates from "
            "clinical_evidence[EOB_PRIOR|PRED_LETTER]"
        ),
        "missing_inputs": sorted(missing),
    }
