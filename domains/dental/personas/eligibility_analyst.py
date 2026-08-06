"""
T-22 — Eligibility analyst. Wave 1, recommend, front_desk.

Answers one question at check-in: will this plan pay anything at all
for this case? SLA is 3 seconds, because the patient is standing there.
"""
from __future__ import annotations

from typing import Any

from core.resolvers import resolve_frequency, resolve_waiting_period
from domains.dental.personas.base import DentalPersona

# Below this share of the case value, the remaining benefit is not worth
# planning around and the patient should be told before treatment.
ANNUAL_MAX_MATERIALITY = 0.10


class EligibilityAnalyst(DentalPersona):
    decision_id = "eligibility_analyst"
    persona_name = "Eligibility Analyst"
    wave = 1
    mode = "recommend"
    risk_level = "medium"
    owner_team = "front_desk"

    def _compute_offline(self, context: Any) -> list[dict]:
        rules = self.rules(context)
        elig = getattr(context, "eligibility", None)
        signals: list[dict] = []

        wp = resolve_waiting_period(context, rules)
        freq = resolve_frequency(context, rules)

        coverage_active = bool(getattr(elig, "coverage_active", False))
        case_value = context.total_fee_submitted

        # ── Hard stop: no coverage at all ────────────────────────────
        if not coverage_active:
            signals.append(self.signal_from_catalogue(
                context, "ELIG_COVERAGE_INACTIVE",
                "Insurance is not active on the treatment date. Nothing on "
                "this pre-D is payable until coverage is verified.",
                mode="human_approval",
                data={"coverage_active": False},
            ))

        # ── Implants excluded ────────────────────────────────────────
        # A plan exclusion is a contract term, not a determination, so
        # it is not appealable. The patient owes 100% and must be told
        # before treatment, not at checkout.
        implant_codes = [c for c in context.cdt_codes if str(c).upper().startswith("D6")]
        if implant_codes and getattr(elig, "implant_covered", None) is False:
            signals.append(self.signal_from_catalogue(
                context, "ELIG_IMPLANTS_NOT_COVERED",
                f"This plan excludes implant services. "
                f"{', '.join(implant_codes)} will not be paid and the patient "
                f"is responsible for the full ${case_value:,.2f}. A plan "
                f"exclusion is not appealable.",
                mode="human_approval",
                data={"implant_codes": implant_codes,
                      "patient_responsibility": case_value},
            ))

        # ── Waiting period ───────────────────────────────────────────
        if wp.get("waiting_period_met") is False:
            signals.append(self.signal_from_catalogue(
                context, "ELIG_WAITING_PERIOD_NOT_MET",
                f"{wp['applicable_category'].title()} services waiting period "
                f"of {wp['months_required_applicable']} months is not "
                f"satisfied — enrolled {wp['months_enrolled']} months, "
                f"{wp['months_short']} short.",
                mode="human_approval",
                data={
                    "months_enrolled": wp["months_enrolled"],
                    "months_required": wp["months_required_applicable"],
                    "months_short": wp["months_short"],
                    "enrollment_start": wp["enrollment_start"],
                    "category": wp["applicable_category"],
                },
            ))

        # ── Missing tooth clause ─────────────────────────────────────
        if getattr(elig, "missing_tooth_clause_triggered", None):
            signals.append(self.signal_from_catalogue(
                context, "ELIG_MISSING_TOOTH_CLAUSE",
                "The missing tooth clause is confirmed for this tooth — it "
                "was missing before enrollment, so replacement is excluded.",
                mode="human_approval",
            ))

        # ── Frequency ────────────────────────────────────────────────
        # Tri-state: None means the prior treatment date is unknown, not
        # that frequency is clear. Reported so the front desk knows the
        # check did not run rather than assuming it passed.
        if freq.get("any_exceeded") is True:
            breached = [v for v in freq["frequency_violations"] if v["exceeded"]]
            signals.append(self.signal_from_catalogue(
                context, "ELIG_FREQUENCY_EXCEEDED",
                "Frequency limit exceeded for "
                + ", ".join(
                    f"{v['cdt_code']} (last treated {v['days_since_last']} days "
                    f"ago against a {v['frequency_period']} limit)"
                    for v in breached
                ),
                mode="human_approval",
                data={"violations": breached},
            ))
        elif freq.get("any_exceeded") is None and freq.get("procedures_checked"):
            signals.append(self.make_signal(
                "ELIG_FREQUENCY_UNVERIFIED",
                f"Frequency limits apply to "
                f"{freq['procedures_checked']} code(s) on this pre-D, but no "
                f"prior treatment date is on file — the check could not run. "
                f"This is NOT confirmation that frequency is clear.",
                mode="recommend",
                data={"codes_undeterminable": freq["codes_undeterminable"],
                      "missing": freq["missing_inputs"]},
                recommended_action="obtain_prior_eob_or_treatment_history",
            ))

        # ── Coordination of benefits ─────────────────────────────────
        if getattr(elig, "coordination_of_benefits", None):
            signals.append(self.signal_from_catalogue(
                context, "ELIG_COB_REQUIRED",
                "Secondary insurance detected. The primary payer must be "
                "billed first and its EOB attached before the secondary "
                "claim goes out.",
                mode="recommend",
                recommended_action="verify_cob_primary_first",
            ))

        # ── Annual maximum ───────────────────────────────────────────
        remaining = getattr(elig, "annual_max_remaining", None)
        if remaining is not None and case_value:
            if remaining <= 0:
                signals.append(self.signal_from_catalogue(
                    context, "ELIG_ANNUAL_MAX_EXHAUSTED",
                    "The annual maximum is exhausted. The patient is "
                    f"responsible for 100% of ${case_value:,.2f}.",
                    mode="recommend",
                    data={"annual_max_remaining": remaining,
                          "case_value": case_value},
                ))
            elif remaining < case_value * ANNUAL_MAX_MATERIALITY:
                signals.append(self.signal_from_catalogue(
                    context, "ELIG_ANNUAL_MAX_EXCEEDED",
                    f"Only ${remaining:,.2f} of the annual maximum remains "
                    f"against a case value of ${case_value:,.2f}. Quote the "
                    f"patient portion before treatment begins.",
                    mode="recommend",
                    data={"annual_max_remaining": remaining,
                          "case_value": case_value},
                ))

        # ── Member identity ──────────────────────────────────────────
        if getattr(elig, "member_id_mismatch", None) is True:
            signals.append(self.signal_from_catalogue(
                context, "ELIG_PLAN_NOT_FOUND",
                "The member ID on the insurance card does not match the one "
                "returned by the payer's eligibility response.",
                mode="human_approval",
            ))

        # ── Clean ────────────────────────────────────────────────────
        # ELIGIBILITY_VERIFIED tracks decisions.yaml's recommend_if
        # clause exactly — coverage_active, waiting_period_met,
        # annual_max_remaining > 0 — and nothing else. An ADVISORY
        # signal like ELIG_FREQUENCY_UNVERIFIED reports a check that
        # could not run; it must not silently withhold the verification
        # the boundary says is earned. Suppressing it here would put
        # DA-A01 in a state decisions.yaml does not describe.
        boundary_met = (
            coverage_active
            and wp.get("waiting_period_met") is not False
            and (remaining is None or remaining > 0)
        )
        blocking = [s for s in signals if s["mode"] == "human_approval"]
        if boundary_met and not blocking:
            signals.append(self.make_signal(
                "ELIGIBILITY_VERIFIED",
                f"Coverage active. ${remaining:,.2f} of the annual maximum "
                f"remains and the {wp['applicable_category']} waiting period "
                f"is satisfied ({wp['months_enrolled']} months enrolled)."
                if remaining is not None else "Coverage active.",
                mode="recommend",
                data={
                    "coverage_active": True,
                    "annual_max_remaining": remaining,
                    "waiting_period_met": wp.get("waiting_period_met"),
                    "months_enrolled": wp.get("months_enrolled"),
                    "implant_covered": getattr(elig, "implant_covered", None),
                },
            ))
        return signals
