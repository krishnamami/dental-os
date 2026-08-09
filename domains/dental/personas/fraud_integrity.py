"""
T-24 — Fraud and integrity. Wave 1, human_approval, billing.

THE FINDING IS A MISMATCH, NOT AN ACCUSATION.

Every signal here compares two records that disagree. A surface
conflict between a note and a radiograph is far more often a charting
slip than fraud; upcoding is more often a template default than intent.
The persona's job is to put both values in front of the billing
manager. The billing manager decides what it means — which is exactly
why this decision is human_approval and why the finding text always
names both sides of the comparison.
"""
from __future__ import annotations

from typing import Any

from core.resolvers import resolve_frequency, resolve_upcoding
from domains.dental.personas.base import DentalPersona

# Which detector outputs escalate to a human vs merely inform.
# Surface conflicts are the one genuinely ambiguous case — a charting
# shorthand difference reads identically to a billing change — so they
# recommend rather than demand sign-off.
# evidence_edges.field values that describe a COVERAGE conclusion
# rather than a clinical disagreement. A contradicts edge on one of
# these is the rules engine recording a bundling/frequency finding, and
# coverage_analyst already reports it — re-reporting it as an integrity
# signal would double-count and, worse, read as suspected fraud.
COVERAGE_DOMAIN_FIELDS = {
    "bundling_conflict",
    "frequency_limit",
    "downgrade",
    "coverage",
}

SIGNAL_MODES = {
    # No FRAUD_UPCODING: the detector no longer emits it, because the
    # check that carried the name tested the opposite condition. See
    # core/resolvers/upcoding_detector.py.
    #
    # `recommend`, not human_approval: the chart records more work than
    # the claim bills for. Nobody is over-charged, so it does not hold
    # a submission — it is money the practice is leaving behind.
    "BILLING_UNBILLED_PROCEDURE": "recommend",
    "FRAUD_PHANTOM_PROCEDURE": "human_approval",
    "FRAUD_WAIVED_COPAY": "human_approval",
    "FRAUD_UNBUNDLING": "human_approval",
    "FRAUD_FREQUENCY_GAMING": "recommend",
    "FRAUD_SURFACE_CONFLICT": "recommend",
}


class FraudIntegrity(DentalPersona):
    decision_id = "fraud_integrity"
    persona_name = "Fraud and Integrity"
    wave = 1
    mode = "human_approval"
    risk_level = "high"
    owner_team = "billing"

    def _compute_offline(self, context: Any) -> list[dict]:
        rules = dict(self.rules(context))
        # The gaming detector lives in frequency_resolver, which owns the
        # prior-date lookup. Hand its findings to the detector rather
        # than duplicating that logic here.
        rules["_frequency_findings"] = resolve_frequency(context, self.rules(context))
        detected = resolve_upcoding(context, rules)

        signals: list[dict] = []
        for sig in detected.get("signals", []):
            code = sig["signal_type"]
            signals.append(self.signal_from_catalogue(
                context, code, sig["evidence"],
                mode=SIGNAL_MODES.get(code, "human_approval"),
                data={
                    "cdt_code": sig["cdt_code"],
                    "severity": sig["severity"],
                    "billed_codes": detected["billed_codes"],
                    "note_codes": detected["note_codes"],
                },
                recommended_action="confirm_with_treating_provider",
            ))

        # ── Contradicting evidence in the knowledge graph ────────────
        # Only CLINICAL contradictions belong here. DA-A01 — the
        # reference clean case — carries a 'contradicts' edge whose
        # field is 'bundling_conflict', which is the coverage rule
        # firing, modelled as a graph edge. Two documents are not
        # disagreeing about anything; treating it as an integrity
        # concern would flag the cleanest case in the catalogue.
        contradicts = getattr(context, "contradicts_count", 0) or 0
        fields = [f for f in (getattr(context, "contradicts_fields", []) or [])
                  if f not in COVERAGE_DOMAIN_FIELDS]
        if contradicts and fields:
            signals.append(self.make_signal(
                "FRAUD_SURFACE_CONFLICT",
                f"Clinical sources disagree on "
                f"{', '.join(sorted(fields))} — {contradicts} contradicting "
                f"edge(s) in the evidence graph.",
                mode="recommend",
                data={"contradicts_count": contradicts,
                      "contradicts_fields": fields,
                      "confirms_count": getattr(context, "confirms_count", 0)},
                recommended_action="reconcile_conflicting_documents",
            ))

        if not signals:
            signals.append(self.make_signal(
                "INTEGRITY_VERIFIED",
                "No integrity anomalies detected. Billed codes match the "
                "clinical note, fees differ from allowed amounts, and no "
                "clinical source contradicts another.",
                mode="recommend",
                data={
                    "billed_codes": detected["billed_codes"],
                    "note_codes": detected["note_codes"],
                    "confirms_count": getattr(context, "confirms_count", 0),
                    "contradicts_count": contradicts,
                    "detectors_undeterminable": detected.get("missing_inputs", []),
                },
            ))
        return signals
