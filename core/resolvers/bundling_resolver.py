"""
T-15 — Which billed CDT code pairs conflict under bundling rules?

The D7953-with-D6010 conflict this resolver finds is the single reason
Accord Dental exists. Catching it at day 0 instead of day 14 is the
product.

hard vs soft is the whole distinction:
  hard  cannot be separated at any price — one code or the other
  soft  separable WITH documentation, which is a task, not a denial
"""
from __future__ import annotations

from itertools import combinations
from typing import Any

from core.resolvers.base import safe_resolver


@safe_resolver
def resolve_bundling(context: Any, rules: dict) -> dict:
    """Sync. DB-less. Reads from bundle only."""
    bundling = rules.get("bundling_rules") or {}
    payer_id = getattr(context, "payer_id", None) or "delta_dental"

    codes: list[str] = []
    for proc in getattr(context, "procedures", []) or []:
        if proc.cdt_code not in codes:
            codes.append(proc.cdt_code)

    conflicts: list[dict] = []
    seen_pairs: set[frozenset] = set()

    for a, b in combinations(codes, 2):
        # The catalogue registers both directions, but check explicitly
        # so a one-directional seed still resolves.
        rule = bundling.get((a, b)) or bundling.get((b, a))
        if rule is None:
            continue
        pair = frozenset((a, b))
        if pair in seen_pairs:
            continue
        seen_pairs.add(pair)

        conflicts.append({
            "primary_code": a,
            "bundled_code": b,
            "bundling_type": rule.get("bundling_type"),
            "separable": bool(rule.get("separable")),
            "separation_criteria": rule.get("separation_criteria"),
            "policy_section": rule.get("policy_section"),
            "denial_reason_code": rule.get("denial_reason_code"),
            "scope": rule.get("scope"),
            "payer_id": rule.get("payer_id") or payer_id,
            "applies_to_all_payers": rule.get("applies_to_all_payers", False),
            "governed_by": rule.get("governed_by", "payer"),
            "layer": rule.get("layer"),
        })

    hard = [c for c in conflicts if c["bundling_type"] == "hard"]
    soft = [c for c in conflicts if c["bundling_type"] == "soft"]

    # The assembler already reached its own conclusion. Reported for
    # comparison — a disagreement means the catalogue and the simulator
    # have drifted apart and a human should look.
    state_flag = getattr(context, "has_bundling_conflict", None)
    any_conflict = bool(conflicts)
    disagrees = state_flag is not None and bool(state_flag) != any_conflict

    return {
        "conflicts": conflicts,
        "hard_conflicts": len(hard),
        "soft_conflicts": len(soft),
        "any_conflict": any_conflict,
        # Only meaningful when there IS a conflict; a case with no
        # conflict has nothing to separate.
        "separation_possible": any_conflict and all(c["separable"] for c in conflicts),
        "blocking_conflicts": [
            {
                "primary_code": c["primary_code"],
                "bundled_code": c["bundled_code"],
                "policy_section": c["policy_section"],
            }
            for c in hard
        ],
        "codes_evaluated": codes,
        "pairs_evaluated": len(list(combinations(codes, 2))),
        "pred_state_has_bundling_conflict": state_flag,
        "disagrees_with_pred_state": disagrees,
        "data_source": "bundling_rules catalogue + procedure_lines.cdt_code",
        "missing_inputs": [] if codes else ["procedure_lines"],
    }
