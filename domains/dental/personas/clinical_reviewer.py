"""
T-26 — Clinical reviewer. Wave 2, recommend, dentist.
Depends on provider_credentialing.

SURFACES THE MEASUREMENT AGAINST THE THRESHOLD. DOES NOT DIAGNOSE.

criteria_score 0.85 means the documentation supports the procedure
under ADA criteria. Whether the patient needs the graft is Dr. Chinta's
call, and always was. Every finding here names the measured value and
the threshold it was compared against, so the dentist can disagree with
the comparison rather than with a verdict.
"""
from __future__ import annotations

from typing import Any

from core.context.pred_context import confidence_label
from core.resolvers import resolve_bone_loss, resolve_completeness, resolve_perio
from domains.dental.personas.base import DentalPersona

# Codes whose ADA criteria require a narrative establishing necessity.
NARRATIVE_CODES = ("D7953", "D6010", "D4260")


class ClinicalReviewer(DentalPersona):
    decision_id = "clinical_reviewer"
    persona_name = "Clinical Reviewer"
    wave = 2
    mode = "recommend"
    risk_level = "medium"
    owner_team = "dentist"

    def _compute_offline(self, context: Any) -> list[dict]:
        rules = self.rules(context)

        # ── Upstream: OIG exclusion suspends clinical review ─────────
        # Not because the clinical question changed, but because there
        # is no point scoring a case that cannot be submitted under
        # this NPI at all.
        if self.upstream_has(context, "provider_credentialing",
                             "PROVIDER_OIG_EXCLUDED"):
            return [self.make_signal(
                "CLINICAL_REVIEW_BLOCKED",
                "Provider is OIG excluded — clinical review suspended. "
                "Resolve the provider before spending clinical time on this "
                "case.",
                mode="human_approval",
                data={"blocked_by": "PROVIDER_OIG_EXCLUDED"},
                recommended_action="resolve_provider_first",
            )]

        signals: list[dict] = []
        bone = resolve_bone_loss(context, rules)
        perio = resolve_perio(context, rules)
        comp = resolve_completeness(context, rules)

        score = getattr(context, "criteria_score", None)
        label = confidence_label(score)

        # ── Medical history contraindications ────────────────────────
        # Checked FIRST: an absolute contraindication outranks a good
        # criteria score. A well-documented implant is still the wrong
        # procedure for a patient on IV bisphosphonates.
        flags = rules.get("medical_history_flags") or {}
        if self.has_open_condition(context, "CLINICAL_MEDICAL_HISTORY_FLAG"):
            billed = set(context.cdt_codes)
            hits = [
                (code, f) for code, f in flags.items()
                if billed & set(f.get("contraindicated_cdts") or [])
            ]
            absolute = [(c, f) for c, f in hits
                        if f.get("risk_level") == "absolute_contraindication"]
            chosen = absolute or hits
            for code, flag in chosen[:2]:
                signals.append(self.signal_from_catalogue(
                    context, "CLINICAL_MEDICAL_HISTORY_FLAG",
                    f"{flag.get('flag_name') or code} is a "
                    f"{(flag.get('risk_level') or 'risk').replace('_', ' ')} "
                    f"for {', '.join(sorted(billed & set(flag.get('contraindicated_cdts') or [])))}. "
                    f"{flag.get('clinical_action') or ''}".strip(),
                    mode="human_approval",
                    data={
                        "flag": code,
                        "risk": flag.get("risk_level"),
                        "contraindicated_cdts": flag.get("contraindicated_cdts"),
                        "documentation_required": flag.get("documentation_required"),
                    },
                    recommended_action="obtain_medical_clearance",
                ))

        # ── Bone loss ────────────────────────────────────────────────
        if bone.get("criteria_met") is True:
            signals.append(self.make_signal(
                "CLINICAL_CRITERIA_MET",
                f"Radiographic bone loss measures {bone['bone_loss_mm']}mm "
                f"against a >={bone['threshold_mm']}mm requirement for "
                f"{bone['evaluated_cdt_code']} — margin "
                f"{bone['margin_mm']:+}mm. Criteria score {score} ({label}).",
                mode="recommend",
                data={
                    "bone_loss_mm": bone["bone_loss_mm"],
                    "threshold": bone["threshold_mm"],
                    "margin_mm": bone["margin_mm"],
                    "criteria_score": score,
                    "confidence_label": label,
                    "tooth_number": bone["tooth_number"],
                    "medical_necessity_met": getattr(
                        context, "medical_necessity_met", None),
                },
                citation=bone.get("citation"),
            ))
        elif bone.get("criteria_met") is False:
            signals.append(self.signal_from_catalogue(
                context, "CLINICAL_CRITERIA_NOT_MET",
                f"Radiographic bone loss measures {bone['bone_loss_mm']}mm "
                f"against a >={bone['threshold_mm']}mm requirement for "
                f"{bone['evaluated_cdt_code']} — short by "
                f"{abs(bone['margin_mm'])}mm. Criteria score {score} ({label}).",
                mode="recommend",
                data={
                    "bone_loss_mm": bone["bone_loss_mm"],
                    "threshold": bone["threshold_mm"],
                    "margin_mm": bone["margin_mm"],
                    "criteria_score": score,
                    "confidence_label": label,
                },
                citation=bone.get("citation"),
            ))
        elif "XRAY_PA" in bone.get("missing_inputs", []):
            signals.append(self.signal_from_catalogue(
                context, "CLINICAL_XRAY_REQUIRED",
                f"No periapical radiograph is on file. "
                f"{bone['evaluated_cdt_code']} requires one showing bone loss "
                f">={bone['threshold_mm']}mm before criteria can be scored.",
                mode="recommend",
                recommended_action="obtain_periapical_xray",
            ))

        # ── Perio ────────────────────────────────────────────────────
        if perio.get("surgical_threshold_met") is False:
            signals.append(self.signal_from_catalogue(
                context, "CLINICAL_CRITERIA_NOT_MET",
                f"Periodontal chart shows a maximum pocket depth of "
                f"{perio['pocket_depth_max']}mm across "
                f"{perio['sites_gte_5mm']} site(s) >=5mm. AAP criteria "
                f"require >={perio['surgical_threshold_mm']}mm in "
                f">={perio['sites_required']} sites for osseous surgery.",
                mode="recommend",
                data={
                    "pocket_depth_max": perio["pocket_depth_max"],
                    "sites_gte_5mm": perio["sites_gte_5mm"],
                    "threshold_mm": perio["surgical_threshold_mm"],
                    "sites_required": perio["sites_required"],
                    "perio_diagnosis": perio["perio_diagnosis"],
                },
            ))
        if perio.get("is_current") is False:
            signals.append(self.make_signal(
                "CLINICAL_PERIO_CHART_STALE",
                f"Periodontal chart is {perio['days_old']} days old against a "
                f"{perio['max_age_days']}-day currency window.",
                mode="recommend",
                recommended_action="obtain_current_perio_chart",
            ))

        # ── Narrative ────────────────────────────────────────────────
        # TWO SOURCES, AND THEY DISAGREE ON PURPOSE.
        #
        # comp['narrative_present'] says a note exists with narrative
        # text in it. The assembler's CLINICAL_NARRATIVE_REQUIRED open
        # condition says the narrative THIS CASE NEEDS is not there.
        # On DA-A01 both are true at once: the note reads "Bone graft
        # documented with PA X-ray showing 4.2mm bone loss" — which
        # documents the graft but does NOT establish necessity
        # independent of the implant, and independence is the whole
        # thing D.7.4 asks for.
        #
        # The open condition wins. dental-simulator's policy engine
        # decided; dental-os explains that decision rather than
        # second-guessing it from a boolean.
        narrative_codes = [c for c in context.cdt_codes if c in NARRATIVE_CODES]
        narrative_required = self.has_open_condition(
            context, "CLINICAL_NARRATIVE_REQUIRED"
        )
        if narrative_codes and (narrative_required or not comp.get("narrative_present")):
            signals.append(self.signal_from_catalogue(
                context, "CLINICAL_NARRATIVE_MISSING",
                f"No clinical narrative on file for "
                f"{', '.join(sorted(set(narrative_codes)))}. For D7953 the "
                f"narrative must establish graft necessity INDEPENDENT of "
                f"implant placement — that independence is what unbundles it."
                if "D7953" in narrative_codes and not comp.get("narrative_present")
                else f"The clinical note on file does not establish what "
                     f"{', '.join(sorted(set(narrative_codes)))} requires. For "
                     f"D7953 the narrative must establish graft necessity "
                     f"INDEPENDENT of implant placement — documenting the "
                     f"graft alongside the implant is not the same thing, and "
                     f"it is the independence that unbundles it."
                if "D7953" in narrative_codes else
                f"No clinical narrative on file for "
                f"{', '.join(sorted(set(narrative_codes)))}.",
                mode="recommend",
                data={
                    "codes_requiring_narrative": sorted(set(narrative_codes)),
                    "note_on_file": bool(comp.get("narrative_present")),
                    "required_by_assembler": narrative_required,
                },
                recommended_action="add_clinical_narrative",
            ))

        # ── Image quality ────────────────────────────────────────────
        if (bone.get("image_quality") or "").upper() in ("SUBOPTIMAL", "NON_DIAGNOSTIC"):
            signals.append(self.signal_from_catalogue(
                context, "CLINICAL_IMAGE_QUALITY_LOW",
                f"Radiograph quality reads {bone['image_quality']}. A "
                f"measurement taken off a poor image is not defensible to a "
                f"payer medical director.",
                mode="recommend",
                data={"image_quality": bone["image_quality"],
                      "xray_confidence": bone["xray_confidence"]},
                recommended_action="retake_radiograph",
            ))

        if not signals:
            signals.append(self.make_signal(
                "CLINICAL_CRITERIA_MET",
                f"Clinical criteria satisfied. Criteria score {score} ({label}).",
                mode="recommend",
                data={"criteria_score": score, "confidence_label": label},
            ))
        return signals
