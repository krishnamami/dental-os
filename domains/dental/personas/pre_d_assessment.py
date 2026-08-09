"""
T-30 — Pre-D assessment. Wave 4, human_approval, billing.

The dental equivalent of lending's underwriting_decision, and the only
decision in the domain that produces no findings of its own. It reads
what Waves 1-3 concluded and answers one question the front desk cannot
answer from any single upstream output: **can this packet be sent?**

Depends on all six upstream personas (decisions.yaml `depends_on`), and
`contamination_guard.fail_if_any_upstream_blocked` is why the block
branch returns early — once an OIG exclusion or a fraud signal is on the
record, "what else is missing" is not the next question.

signals_emitted in decisions.yaml is a CLOSED list of five (RULE 7):

    PRED_READY_TO_SUBMIT   PRED_CONDITIONS_OPEN   PRED_BLOCKED_FRAUD
    PRED_BLOCKED_CLINICAL  PRED_BLOCKED_PROVIDER

Note what is NOT in it: there is no PRED_BLOCKED_ELIGIBILITY. A hard
eligibility exclusion (implants not covered, coverage inactive) is
therefore reported as PRED_CONDITIONS_OPEN with the blocking upstream
signal named in `data`, not invented as a sixth code. Adding one is a
decisions.yaml change first and a code change second (RULE 8).
"""
from __future__ import annotations

from typing import Any

from domains.dental.personas.base import DentalPersona

# The six upstream decisions this synthesis reads, in wave order.
UPSTREAM_DECISIONS = (
    "eligibility_analyst",
    "provider_credentialing",
    "fraud_integrity",
    "coverage_analyst",
    "clinical_reviewer",
    "documentation_reviewer",
)

# decisions.yaml block_if, transcribed. Anything here stops submission.
PROVIDER_BLOCKING = ("PROVIDER_OIG_EXCLUDED",)
CLINICAL_BLOCKING = ("CLINICAL_CRITERIA_NOT_MET", "CLINICAL_REVIEW_BLOCKED")
# Eligibility exclusions block submission but have no PRED_BLOCKED_*
# code to land on — see the module docstring.
ELIGIBILITY_BLOCKING = ("ELIG_COVERAGE_INACTIVE", "ELIG_IMPLANTS_NOT_COVERED")

# criteria_score floor from decisions.yaml recommend_if. Same 0.70 as
# TRUST_FLOOR, and deliberately not the same constant — this one is a
# clinical criteria score, not an extraction confidence.
CRITERIA_FLOOR = 0.70


class PreDAssessment(DentalPersona):
    decision_id = "pre_d_assessment"
    persona_name = "Pre-D Assessment"
    wave = 4
    mode = "human_approval"
    risk_level = "high"
    owner_team = "billing"

    def _compute_offline(self, context: Any) -> list[dict]:
        upstream = {
            decision_id: self.upstream_signals(context, decision_id)
            for decision_id in UPSTREAM_DECISIONS
        }
        every = [s for signals in upstream.values() for s in signals]
        codes = {s.get("signal_code") for s in every}

        # A wave that never ran is not the same as a wave that ran clean.
        # Surfaced in data rather than guessed at.
        did_not_run = [d for d in UPSTREAM_DECISIONS if not upstream[d]]

        base_data = {
            "upstream_signal_count": len(every),
            "upstream_decisions_run": [
                d for d in UPSTREAM_DECISIONS if upstream[d]
            ],
            "upstream_decisions_missing": did_not_run,
            "criteria_score": context.criteria_score,
            "payer_decision": context.decision,
        }

        # ── BLOCK — terminal, and ordered by severity ────────────────
        # An excluded provider outranks a fraud signal outranks a
        # clinical failure: the first cannot be cured by any document,
        # the second needs an investigation, the third needs evidence.
        blocked = [s for s in every if s.get("signal_code") in PROVIDER_BLOCKING]
        if blocked:
            return [self._block(
                "PRED_BLOCKED_PROVIDER",
                f"{context.provider_name or 'The treating provider'} is on the "
                f"OIG exclusion list. Nothing billed under this NPI is "
                f"payable, and submitting anyway is a false claim — the "
                f"provider must be changed before this pre-D goes out.",
                blocked, base_data, "reassign_treating_provider",
            )]

        fraud = [
            s for s in every
            if (s.get("signal_code") or "").startswith("FRAUD_")
        ]
        if fraud:
            names = ", ".join(sorted({s["signal_code"] for s in fraud}))
            return [self._block(
                "PRED_BLOCKED_FRAUD",
                f"{len(fraud)} integrity signal(s) on this pre-D ({names}). "
                f"Billing integrity is reviewed before submission, not after "
                f"the payer finds it.",
                fraud, base_data, "route_to_integrity_review",
            )]

        clinical = [s for s in every if s.get("signal_code") in CLINICAL_BLOCKING]
        if clinical:
            return [self._block(
                "PRED_BLOCKED_CLINICAL",
                f"ADA clinical criteria are not met "
                f"(criteria_score={context.criteria_score}). The clinical "
                f"floor cannot be overridden by a payer rule or a practice "
                f"overlay (RULE 2) — the case needs evidence, not an appeal.",
                clinical, base_data, "obtain_clinical_evidence",
            )]

        # ── CONDITIONS OPEN — escalate ───────────────────────────────
        # Everything that keeps the packet from going out today but is
        # curable. Ordered so the reader sees the hardest one first.
        eligibility_hard = [
            s for s in every if s.get("signal_code") in ELIGIBILITY_BLOCKING
        ]
        escalations = [s for s in every if s.get("mode") == "human_approval"]
        open_conditions = list(context.open_conditions or [])
        low_score = (
            context.criteria_score is not None
            and context.criteria_score < CRITERIA_FLOOR
        )

        if eligibility_hard or escalations or open_conditions or low_score:
            reasons = []
            if eligibility_hard:
                reasons.append(
                    f"the plan excludes this treatment "
                    f"({', '.join(sorted({s['signal_code'] for s in eligibility_hard}))})"
                )
            if open_conditions:
                reasons.append(
                    f"{len(open_conditions)} open condition(s): "
                    f"{', '.join(str(c) for c in open_conditions[:4])}"
                    # The count is len(), the list is [:4]. Without this
                    # the sentence said "6 open condition(s)" and then
                    # named four, which reads as a miscount rather than
                    # a truncation.
                    + (f" and {len(open_conditions) - 4} more"
                       if len(open_conditions) > 4 else "")
                )
            if escalations:
                reasons.append(
                    f"{len(escalations)} upstream signal(s) need a human"
                )
            if low_score:
                reasons.append(
                    f"criteria_score {context.criteria_score} is below the "
                    f"{CRITERIA_FLOOR} submission floor"
                )
            return [self.make_signal(
                "PRED_CONDITIONS_OPEN",
                # "The payer decision on record is 'pended'" claimed a
                # payer had ruled on a pre-D that has not been sent.
                # context.decision is payer_responses — the simulator's
                # PREDICTION of how this payer will rule. Say that.
                f"Not ready to submit: {'; '.join(reasons)}. Predicted "
                f"payer outcome if sent as-is: '{context.decision}'.",
                mode="human_approval",
                data={
                    **base_data,
                    "open_conditions": open_conditions,
                    "eligibility_exclusions": [
                        s["signal_code"] for s in eligibility_hard
                    ],
                    "escalating_signals": sorted({
                        s["signal_code"] for s in escalations
                    }),
                    "below_criteria_floor": low_score,
                    "criteria_floor": CRITERIA_FLOOR,
                },
                recommended_action="resolve_open_conditions",
                assignee="billing",
                sla_hours=24,
            )]

        # ── READY — still human_approval ─────────────────────────────
        # Nothing in this domain auto-submits. A clean packet is a
        # recommendation to a billing coordinator, not an action.
        return [self.make_signal(
            "PRED_READY_TO_SUBMIT",
            f"All {len(base_data['upstream_decisions_run'])} upstream "
            f"decisions returned clean, no open conditions, criteria_score "
            f"{context.criteria_score}. Packet is ready for billing to "
            f"submit to {context.payer_id or 'the payer'}.",
            mode="human_approval",
            data={**base_data, "submission_ready": True},
            recommended_action="submit_to_payer",
            assignee="billing",
            sla_hours=24,
        )]

    # ── Helper ───────────────────────────────────────────────────────

    def _block(
        self,
        code: str,
        finding: str,
        triggering: list[dict],
        base_data: dict,
        action: str,
    ) -> dict:
        return self.make_signal(
            code,
            finding,
            mode="human_approval",
            data={
                **base_data,
                "submission_ready": False,
                "blocked_by": sorted({
                    s.get("signal_code") for s in triggering
                }),
                "blocking_findings": [
                    {"signal_code": s.get("signal_code"),
                     "decision_id": s.get("decision_id"),
                     "finding": s.get("finding")}
                    for s in triggering
                ],
            },
            recommended_action=action,
            assignee="billing",
            sla_hours=24,
        )
