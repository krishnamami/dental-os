"""
T-25 — Coverage analyst. Wave 2, recommend, billing.
Depends on eligibility_analyst.

This is the step that pays for the product. It catches the
D7953-with-D6010 bundling conflict at day 0 instead of day 14, and it
tells the front desk exactly what to add so the graft stands on its own.
"""
from __future__ import annotations

from typing import Any

from core.resolvers import resolve_bundling
from domains.dental.personas.base import DentalPersona


class CoverageAnalyst(DentalPersona):
    decision_id = "coverage_analyst"
    persona_name = "Coverage Analyst"
    wave = 2
    mode = "recommend"
    risk_level = "medium"
    owner_team = "billing"

    def _compute_offline(self, context: Any) -> list[dict]:
        rules = self.rules(context)
        signals: list[dict] = []

        # ── Upstream ─────────────────────────────────────────────────
        # An eligibility block does not stop coverage analysis. The
        # reviewer needs the whole picture in one place, so the work
        # still runs — it is just labelled as running under a block.
        if self.upstream_blocked(context, "eligibility_analyst"):
            blocking = [
                s["signal_code"]
                for s in self.upstream_signals(context, "eligibility_analyst")
                if s.get("mode") == "human_approval"
            ]
            signals.append(self.make_signal(
                "COVERAGE_UPSTREAM_BLOCKED",
                f"Eligibility raised {', '.join(blocking)} for human review. "
                f"Coverage analysis below is still valid, but nothing should "
                f"be submitted until eligibility is resolved.",
                mode="recommend",
                data={"upstream_signals": blocking},
            ))

        # ── Bundling ─────────────────────────────────────────────────
        bundling = resolve_bundling(context, rules)
        for c in bundling.get("conflicts", []):
            if c["separable"]:
                signals.append(self.signal_from_catalogue(
                    context, "COVERAGE_BUNDLING_CONFLICT",
                    f"{c['primary_code']} and {c['bundled_code']} are bundled "
                    f"under {c['payer_id']} policy {c['policy_section']}. This "
                    f"is SEPARABLE with documentation — submit as-is and "
                    f"{c['bundled_code']} will be denied as not separately "
                    f"payable.",
                    mode="recommend",
                    data={
                        "primary": c["primary_code"],
                        "bundled": c["bundled_code"],
                        "separable": True,
                        "bundling_type": c["bundling_type"],
                        "separation_criteria": c["separation_criteria"],
                        "policy_section": c["policy_section"],
                    },
                    recommended_action="add_separation_documentation",
                ))
            else:
                signals.append(self.signal_from_catalogue(
                    context, "COVERAGE_BUNDLING_CONFLICT",
                    f"{c['primary_code']} and {c['bundled_code']} are HARD "
                    f"bundled under {c['policy_section']} — they cannot be "
                    f"separated by documentation. Bill one or the other.",
                    mode="human_approval",
                    data={
                        "primary": c["primary_code"],
                        "bundled": c["bundled_code"],
                        "separable": False,
                        "bundling_type": c["bundling_type"],
                        "policy_section": c["policy_section"],
                    },
                    recommended_action="remove_one_code",
                ))

        # ── Downgrades ───────────────────────────────────────────────
        # Not a denial — a lower payment the patient must be told about
        # BEFORE treatment, which is the whole point of step 5.
        downgrades = (rules.get("downgrade_matrix") or {})
        for proc in getattr(context, "procedures", []) or []:
            if not proc.downgrade_applied:
                continue
            entry = downgrades.get((context.payer_id, proc.cdt_code)) or {}
            paid = entry.get("paid_cdt_code")
            signals.append(self.signal_from_catalogue(
                context, "COVERAGE_DOWNGRADE_APPLIED",
                f"{context.payer_id} reimburses {proc.cdt_code} at the "
                f"{paid or 'alternate'} rate"
                + (f" per policy {entry['policy_section']}"
                   if entry.get("policy_section") else "")
                + f". Allowed ${proc.allowed_amount or 0:,.2f} against a "
                  f"${proc.fee_submitted:,.2f} fee — the patient covers the "
                  f"difference.",
                mode="recommend",
                data={
                    "billed_code": proc.cdt_code,
                    "paid_code": paid,
                    "payer_id": context.payer_id,
                    "fee_submitted": proc.fee_submitted,
                    "allowed_amount": proc.allowed_amount,
                    "patient_pays": proc.patient_pays,
                    "policy_section": entry.get("policy_section"),
                },
                recommended_action="inform_patient_of_downgrade",
            ))

        # ── Pre-D required ───────────────────────────────────────────
        pred_required = [
            p.cdt_code for p in (getattr(context, "procedures", []) or [])
            if p.requires_pred
        ]
        if pred_required:
            signals.append(self.signal_from_catalogue(
                context, "COVERAGE_PRED_REQUIRED",
                f"Pre-determination is required before treatment for "
                f"{', '.join(sorted(set(pred_required)))}.",
                mode="recommend",
                data={"codes": sorted(set(pred_required))},
            ))

        # ── Clean ────────────────────────────────────────────────────
        if not bundling.get("any_conflict"):
            signals.append(self.make_signal(
                "COVERAGE_VERIFIED",
                f"All {len(bundling.get('codes_evaluated', []))} billed code(s) "
                f"are covered under this {context.payer_id} plan with no "
                f"bundling conflicts.",
                mode="recommend",
                data={
                    "codes_evaluated": bundling.get("codes_evaluated", []),
                    "pairs_evaluated": bundling.get("pairs_evaluated", 0),
                    "payer_id": context.payer_id,
                },
            ))
        return signals
