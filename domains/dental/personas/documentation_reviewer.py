"""
T-27 — Documentation reviewer. Wave 3, recommend, front_desk.
Depends on coverage_analyst + clinical_reviewer.

Answers one question: is the packet complete enough to submit?

It reads BOTH upstream waves because "required" is not a fixed list.
A narrative is always nice to have; when coverage found a separable
bundling conflict, the narrative becomes the thing that unbundles a
$950 line item. Same missing document, different urgency, and the
front desk needs to know which one they are looking at.
"""
from __future__ import annotations

from typing import Any

from core.resolvers import resolve_completeness
from domains.dental.personas.base import DentalPersona

MISSING_SIGNAL = {
    "XRAY_PA": "DOC_XRAY_MISSING",
    "PERIO_CHART": "DOC_PERIO_CHART_MISSING",
    "CBCT_REPORT": "DOC_CBCT_REQUIRED",
    "MEDICAL_CLEARANCE": "DOC_MEDICAL_CLEARANCE_NEEDED",
    "CLINICAL_NOTE": "DOC_NARRATIVE_MISSING",
    "CLINICAL_NOTE.narrative": "DOC_NARRATIVE_MISSING",
}
OUTDATED_SIGNAL = {
    "XRAY_PA": "DOC_XRAY_TOO_OLD",
    "PERIO_CHART": "DOC_PERIO_CHART_OUTDATED",
}


class DocumentationReviewer(DentalPersona):
    decision_id = "documentation_reviewer"
    persona_name = "Documentation Reviewer"
    wave = 3
    mode = "recommend"
    risk_level = "medium"
    owner_team = "front_desk"

    def _compute_offline(self, context: Any) -> list[dict]:
        rules = self.rules(context)
        comp = resolve_completeness(context, rules)
        signals: list[dict] = []

        # What upstream found changes how urgent a gap is.
        bundling_signals = [
            s for s in self.upstream_signals(context, "coverage_analyst")
            if s.get("signal_code") == "COVERAGE_BUNDLING_CONFLICT"
            and s.get("data", {}).get("separable")
        ]
        clinical_narrative_missing = self.upstream_has(
            context, "clinical_reviewer", "CLINICAL_NARRATIVE_MISSING"
        )

        # ── Missing documents ────────────────────────────────────────
        for doc in comp.get("missing_docs", []):
            if doc in ("CLINICAL_NOTE", "CLINICAL_NOTE.narrative"):
                continue  # handled below, where the bundling context is known
            code = MISSING_SIGNAL.get(doc, "DOC_XRAY_MISSING")
            signals.append(self.signal_from_catalogue(
                context, code,
                f"{doc.replace('_', ' ').title()} is required for "
                f"{', '.join(comp.get('required_by_code', {}).get(doc, []))} "
                f"and is not on file.",
                mode="recommend",
                data={"document_type": doc,
                      "required_by": comp.get("required_by_code", {}).get(doc, [])},
                assignee="front_desk",
                sla_hours=48,
                recommended_action=f"obtain_{doc.lower()}",
            ))

        # ── Narrative — the one that unbundles D7953 ─────────────────
        # The assembler's open condition is authoritative over the
        # extracted narrative_present boolean — a note can be on file
        # and still not say what the case needs. See the long note in
        # clinical_reviewer._compute_offline.
        narrative_missing = (
            self.has_open_condition(context, "CLINICAL_NARRATIVE_REQUIRED")
            or clinical_narrative_missing
            or not comp.get("narrative_present")
            or "CLINICAL_NOTE" in comp.get("missing_docs", [])
            or "CLINICAL_NOTE.narrative" in comp.get("missing_docs", [])
        )
        if narrative_missing and bundling_signals:
            b = bundling_signals[0]["data"]
            signals.append(self.signal_from_catalogue(
                context, "DOC_NARRATIVE_MISSING",
                f"Clinical narrative required to separate {b['bundled']} from "
                f"{b['primary']} per {b['policy_section']}. Without it "
                f"{b['bundled']} is denied as not separately payable — with "
                f"it, roughly 65% of these are overturned.",
                mode="recommend",
                data={
                    "primary": b["primary"],
                    "bundled": b["bundled"],
                    "policy_section": b["policy_section"],
                    "separation_criteria": b.get("separation_criteria"),
                    "blocks_separation": True,
                },
                assignee="front_desk",
                sla_hours=48,
                recommended_action="request_clinical_narrative",
            ))
        elif narrative_missing and clinical_narrative_missing:
            signals.append(self.signal_from_catalogue(
                context, "DOC_NARRATIVE_MISSING",
                "Clinical narrative is required for the billed codes and is "
                "not on file.",
                mode="recommend",
                assignee="front_desk",
                sla_hours=48,
                recommended_action="request_clinical_narrative",
            ))

        # ── Outdated ─────────────────────────────────────────────────
        for d in comp.get("outdated_docs", []):
            doc = d["document_type"]
            signals.append(self.signal_from_catalogue(
                context, OUTDATED_SIGNAL.get(doc, "DOC_XRAY_TOO_OLD"),
                f"{doc.replace('_', ' ').title()} is {d['days_old']} days old "
                f"against a {d['max_age_days']}-day requirement.",
                mode="recommend",
                data=d,
                assignee="front_desk",
                sla_hours=48,
                recommended_action="obtain_current_document",
            ))

        # ── Low confidence ───────────────────────────────────────────
        for d in comp.get("low_confidence_docs", []):
            signals.append(self.make_signal(
                "DOC_LOW_CONFIDENCE",
                f"{d['document_type']} extracted at confidence "
                f"{d['confidence']} against a {d['trust_floor']} trust floor. "
                f"The values read off it are not reliable enough to submit on.",
                mode="recommend",
                data=d,
                assignee="front_desk",
                sla_hours=48,
                recommended_action="re_extract_or_rescan_document",
            ))

        # ── Member identity ──────────────────────────────────────────
        elig = getattr(context, "eligibility", None)
        if getattr(elig, "member_id_mismatch", None) is True:
            signals.append(self.signal_from_catalogue(
                context, "DOC_MEMBER_ID_MISMATCH",
                "The member ID on the insurance card does not match the X12 "
                "271 eligibility response. Submitting on the wrong ID rejects.",
                mode="human_approval",
                recommended_action="reconcile_member_id",
            ))

        # ── Complete ─────────────────────────────────────────────────
        if not signals:
            signals.append(self.make_signal(
                "DOCUMENTATION_COMPLETE",
                f"All required documents are present, current and extracted "
                f"above the {comp['trust_floor']} trust floor. Completeness "
                f"score {comp['completeness_score']}.",
                mode="recommend",
                data={
                    "completeness_score": comp["completeness_score"],
                    "required_docs": [d for d, r in comp["required_docs"].items() if r],
                    "narrative_present": comp["narrative_present"],
                },
            ))
        return signals
