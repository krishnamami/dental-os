"""
T-28 — Appeal specialist. Wave 5, human_approval, billing.

Runs only on denied or pended (decisions.yaml). Returns [] for an
approved case rather than a signal saying nothing happened.

TELLING SOMEONE NOT TO APPEAL IS THE VALUABLE HALF.

A waiting-period or exclusion denial is a date or contract fact. No
documentation changes it, and 3-5 hours spent assembling that appeal is
3-5 hours lost. APPEAL_NOT_VIABLE with the reason stated is worth as
much as APPEAL_VIABLE.
"""
from __future__ import annotations

from typing import Any

from core.resolvers import resolve_appeal_viability
from domains.dental.personas.base import DentalPersona


class AppealSpecialist(DentalPersona):
    decision_id = "appeal_specialist"
    persona_name = "Appeal Specialist"
    wave = 5
    mode = "human_approval"
    risk_level = "high"
    owner_team = "billing"

    def _compute_offline(self, context: Any) -> list[dict]:
        if getattr(context, "decision", None) not in ("denied", "pended"):
            return []

        rules = self.rules(context)
        v = resolve_appeal_viability(context, rules)
        if not v.get("applicable"):
            return []

        signals: list[dict] = []

        # ── Deadline first — it can invalidate everything below ──────
        if v.get("deadline_passed"):
            signals.append(self.signal_from_catalogue(
                context, "APPEAL_NOT_VIABLE",
                f"The appeal deadline ({v['appeal_deadline']}) has passed. "
                f"No appeal path remains on this pre-D.",
                mode="recommend",
                data={"appeal_deadline": v["appeal_deadline"],
                      "days_remaining": v["days_remaining"]},
            ))
            return signals

        if v.get("deadline_warning"):
            signals.append(self.signal_from_catalogue(
                context, "APPEAL_DEADLINE_WARNING",
                f"Only {v['days_remaining']} day(s) remain before the appeal "
                f"deadline on {v['appeal_deadline']}.",
                mode="human_approval",
                data={"days_remaining": v["days_remaining"],
                      "appeal_deadline": v["appeal_deadline"]},
                recommended_action="prioritise_this_appeal",
            ))

        # ── Viability ────────────────────────────────────────────────
        if v.get("viable") is True:
            pct = int((v["success_probability"] or 0) * 100)
            signals.append(self.signal_from_catalogue(
                context, "APPEAL_VIABLE",
                f"Appeal is viable — roughly {pct}% of these are overturned "
                f"when properly documented. {v['appeal_strategy']}",
                mode="human_approval",
                data={
                    "success_probability": v["success_probability"],
                    "denial_reason_code": v["denial_reason_code"],
                    "denial_category": v["denial_category"],
                    "days_remaining": v["days_remaining"],
                    "supporting_evidence": v["supporting_evidence"],
                    "appeal_strategy": v["appeal_strategy"],
                    "bone_loss_mm": v.get("bone_loss_mm"),
                },
                citation=v.get("citation"),
                recommended_action="submit_appeal",
            ))
            if v.get("missing_evidence"):
                signals.append(self.make_signal(
                    "APPEAL_PACKET_READY",
                    "Appeal packet can be assembled now. It would be stronger "
                    "with: " + "; ".join(v["missing_evidence"]),
                    mode="human_approval",
                    data={"missing_evidence": v["missing_evidence"],
                          "supporting_evidence": v["supporting_evidence"]},
                    recommended_action="review_packet_before_sending",
                ))

        elif v.get("viable") is False:
            signals.append(self.signal_from_catalogue(
                context, "APPEAL_NOT_VIABLE",
                f"{v['category_rationale']} {v['appeal_strategy']}".strip(),
                mode="recommend",
                data={
                    "success_probability": v["success_probability"],
                    "denial_reason_code": v["denial_reason_code"],
                    "denial_category": v["denial_category"],
                    "missing_evidence": v.get("missing_evidence", []),
                },
                citation=v.get("citation"),
                recommended_action="do_not_appeal",
            ))

        else:
            signals.append(self.make_signal(
                "APPEAL_NOT_VIABLE",
                f"Appeal viability could not be determined: "
                f"{v.get('category_rationale') or 'insufficient information'}. "
                f"Missing: {', '.join(v.get('missing_inputs') or ['unknown'])}.",
                mode="human_approval",
                data={"denial_reason_code": v.get("denial_reason_code"),
                      "missing_inputs": v.get("missing_inputs", [])},
                recommended_action="review_manually",
            ))

        return signals
