"""
Shared plumbing for the dental resolvers.

THE CONTRACT (CONTEXT.md RULES 5, 6, 9, 11)

    def resolve_x(context: PredContext, rules: dict) -> dict

  SYNC and DB-LESS   No await, no conn, no asyncpg. Everything comes
                     from the bundle: PredContext + catalogue_rules.
  NEVER WRITES       A resolver returns findings. It does not persist.
  NEVER RAISES       Any exception is caught and converted into a
                     findings dict with an `error` key. A resolver that
                     raises takes down a wave; one that degrades lets
                     the persona report what it could not determine.
  ALWAYS REPORTS     Every return carries `data_source` and
                     `missing_inputs`. A missing input surfaces in
                     `missing_inputs` and the field degrades to None —
                     never to a fabricated value, and never to a
                     default that reads like a measurement.

WHY None AND NOT False
  Throughout these resolvers, a criteria field is TRI-STATE:
      True   the criterion is met
      False  the criterion is NOT met — a real, evidenced negative
      None   it could not be evaluated, because the input is absent
  Collapsing None into False would report "criteria not met" for a
  case where nobody looked. That is a different clinical claim, and it
  is the one that would put a defensible pre-D on the denied pile.
"""
from __future__ import annotations

import functools
import logging
from datetime import date, datetime
from typing import Any, Callable, Optional

logger = logging.getLogger(__name__)

# CONTEXT.md "Confidence Threshold Reference": the ingestion-side floor.
# NOT the extractors' AI_FALLBACK_FLOOR of 0.6.
TRUST_FLOOR = 0.70

# Document currency windows, from dental-simulator PRD sections 11-13.
XRAY_MAX_AGE_DAYS = 365       # "current X-ray (within 12 months)"
PERIO_MAX_AGE_DAYS = 183      # "current periodontal chart (within 6 months)"


def safe_resolver(fn: Callable) -> Callable:
    """Guarantees the never-raises half of the contract.

    A resolver that blows up on unexpected data returns a findings dict
    describing the failure instead of propagating. The persona then has
    something to report; the alternative is an exception surfacing three
    layers up as a 500 with no clinical meaning.
    """

    @functools.wraps(fn)
    def wrapper(context: Any, rules: Optional[dict] = None, **kwargs: Any) -> dict:
        try:
            return fn(context, rules or {}, **kwargs)
        except Exception as exc:  # noqa: BLE001 — that is the point
            logger.exception("resolver %s failed", fn.__name__)
            return {
                "error": f"{type(exc).__name__}: {exc}",
                "resolver": fn.__name__,
                "data_source": "unavailable — resolver raised",
                "missing_inputs": ["*"],
            }

    return wrapper


# ─────────────────────────────────────────────────────────────────────
# Coercion — extracted_fields is JSONB and its values arrive loosely
# typed. None in, None out; garbage in, None out. Never a guess.
# ─────────────────────────────────────────────────────────────────────


def as_float(value: Any) -> Optional[float]:
    if value is None or isinstance(value, bool):
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def as_int(value: Any) -> Optional[int]:
    f = as_float(value)
    return None if f is None else int(f)


def as_bool(value: Any) -> Optional[bool]:
    if value is None:
        return None
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        low = value.strip().lower()
        if low in ("true", "t", "yes", "y", "1"):
            return True
        if low in ("false", "f", "no", "n", "0"):
            return False
        return None
    if isinstance(value, (int, float)):
        return bool(value)
    return None


def as_date(value: Any) -> Optional[date]:
    """Parse a date from the several shapes extracted_fields uses."""
    if value is None:
        return None
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, date):
        return value
    text = str(value).strip()
    if not text:
        return None
    for fmt in ("%Y-%m-%d", "%Y-%m-%dT%H:%M:%S", "%m/%d/%Y", "%Y/%m/%d"):
        try:
            return datetime.strptime(text[: len(fmt) + 4], fmt).date()
        except ValueError:
            continue
    try:
        return datetime.fromisoformat(text.replace("Z", "+00:00")).date()
    except ValueError:
        return None


def as_list(value: Any) -> list:
    """cdt_codes_noted arrives as a JSON string, a list, or nothing."""
    if value is None:
        return []
    if isinstance(value, list):
        return value
    if isinstance(value, str):
        import json

        try:
            parsed = json.loads(value)
            return parsed if isinstance(parsed, list) else [parsed]
        except (ValueError, TypeError):
            return [p.strip() for p in value.split(",") if p.strip()]
    return [value]


def months_between(start: Optional[date], end: Optional[date] = None) -> Optional[int]:
    """Whole months elapsed. Counts a month only once the day-of-month
    has been reached, so 2025-12-05 -> 2026-08-04 is 7, not 8."""
    if start is None:
        return None
    end = end or date.today()
    months = (end.year - start.year) * 12 + (end.month - start.month)
    if end.day < start.day:
        months -= 1
    return max(months, 0)


def find_evidence(context: Any, document_type: str) -> Optional[Any]:
    """Most recent evidence of a type, or None.

    Most recent, not first: a resubmitted X-ray should win over the
    stale one it replaced.
    """
    matches = [
        e for e in getattr(context, "clinical_evidence", [])
        if e.document_type == document_type
    ]
    if not matches:
        return None
    return max(matches, key=lambda e: as_date(e.received_at) or date.min)


def evidence_field(evidence: Any, key: str) -> Any:
    if evidence is None:
        return None
    return (evidence.extracted_fields or {}).get(key)


def threshold(
    rules: dict,
    cdt_code: str,
    field: str,
    safe_default: Any,
) -> tuple[Any, str]:
    """Read an ADA threshold, falling back to a SAFE_DEFAULT (RULE 9).

    Returns (value, governed_by) so the caller can report whether the
    number came from the catalogue or from a fallback. Personas that
    cite a threshold need to know which — a SAFE_DEFAULT has no
    citation behind it.
    """
    entry = (rules.get("ada_thresholds") or {}).get(cdt_code) or {}
    value = entry.get(field)
    if value is not None:
        return value, "ADA"
    logger.warning(
        "SAFE_DEFAULT: ada_thresholds[%r].%s missing — using %r. Seed the "
        "row in dental-simulator ada_guidelines.",
        cdt_code,
        field,
        safe_default,
    )
    return safe_default, "safe_default"
