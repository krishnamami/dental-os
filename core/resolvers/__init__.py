"""
Dental resolvers — sync, DB-less, never-raising (CONTEXT.md RULES 5/6/9/11).

Every resolver takes (context: PredContext, rules: dict) and returns a
findings dict carrying `data_source` and `missing_inputs`.
"""
from core.resolvers.appeal_viability_resolver import resolve_appeal_viability
from core.resolvers.base import (
    PERIO_MAX_AGE_DAYS,
    TRUST_FLOOR,
    XRAY_MAX_AGE_DAYS,
    safe_resolver,
)
from core.resolvers.bone_loss_resolver import resolve_bone_loss
from core.resolvers.bundling_resolver import resolve_bundling
from core.resolvers.completeness_resolver import resolve_completeness
from core.resolvers.frequency_resolver import resolve_frequency
from core.resolvers.perio_resolver import resolve_perio
from core.resolvers.upcoding_detector import resolve_upcoding
from core.resolvers.waiting_period_resolver import resolve_waiting_period

ALL_RESOLVERS = {
    "waiting_period": resolve_waiting_period,
    "frequency": resolve_frequency,
    "bundling": resolve_bundling,
    "bone_loss": resolve_bone_loss,
    "perio": resolve_perio,
    "appeal_viability": resolve_appeal_viability,
    "completeness": resolve_completeness,
    "upcoding": resolve_upcoding,
}

__all__ = [
    "ALL_RESOLVERS",
    "PERIO_MAX_AGE_DAYS",
    "TRUST_FLOOR",
    "XRAY_MAX_AGE_DAYS",
    "resolve_appeal_viability",
    "resolve_bone_loss",
    "resolve_bundling",
    "resolve_completeness",
    "resolve_frequency",
    "resolve_perio",
    "resolve_upcoding",
    "resolve_waiting_period",
    "safe_resolver",
]
