"""
Unit tests for the 8 dental personas.

DB-less: every fixture is a hand-built PredContext carrying values read
off the live RDS on 2026-08-05. scripts/test_personas_integration.py is
what checks they still match reality.

    python -m pytest tests/personas/ -v
"""
from __future__ import annotations

import pytest

from core.context.pred_context import (
    ClinicalEvidence,
    EligibilityProfile,
    PayerResponse,
    PredContext,
    ProcedureLine,
)
from domains.dental.personas import (
    ALL_PERSONAS,
    AppealSpecialist,
    ClinicalReviewer,
    CoverageAnalyst,
    DocumentationReviewer,
    DSOPortfolioManager,
    EligibilityAnalyst,
    FraudIntegrity,
    ProviderCredentialing,
)
from tests.resolvers.test_all_resolvers import elig, ev, make_context, proc, rules  # noqa: F401


def codes(signals) -> list[str]:
    return [s["signal_code"] for s in signals]


def by_code(signals, code) -> dict:
    return next(s for s in signals if s["signal_code"] == code)


def ctx_with_rules(rules_fixture, **kw) -> PredContext:
    c = make_context(**kw)
    c.catalogue_rules = rules_fixture
    return c


# ═════════════════════════════════════════════════════════════════════
# Contract — all 8 personas
# ═════════════════════════════════════════════════════════════════════


class TestPersonaContract:
    @pytest.mark.parametrize("decision_id", sorted(ALL_PERSONAS))
    def test_returns_list_of_signal_dicts(self, decision_id, rules):
        p = ALL_PERSONAS[decision_id]()
        c = ctx_with_rules(rules, eligibility=elig(), procedures=[proc("D6010")])
        out = p.run(c)
        assert isinstance(out, list)
        for s in out:
            assert isinstance(s, dict)
            assert s["signal_code"] and s["finding"]
            assert s["decision_id"] == decision_id
            assert s["wave"] == p.wave

    @pytest.mark.parametrize("decision_id", sorted(ALL_PERSONAS))
    def test_mode_is_never_auto_execute(self, decision_id, rules):
        p = ALL_PERSONAS[decision_id]()
        c = ctx_with_rules(rules, eligibility=elig(), procedures=[proc("D6010")])
        for s in p.run(c):
            assert s["mode"] in ("recommend", "human_approval"), s

    @pytest.mark.parametrize("decision_id", sorted(ALL_PERSONAS))
    def test_never_raises_on_empty_context(self, decision_id, rules):
        p = ALL_PERSONAS[decision_id]()
        c = ctx_with_rules(rules, eligibility=None, procedures=[],
                           clinical_evidence=[])
        out = p.run(c)
        assert isinstance(out, list)
        assert not any(s["signal_code"].endswith("_ERROR") for s in out), out

    @pytest.mark.parametrize("decision_id", sorted(ALL_PERSONAS))
    def test_never_raises_on_empty_rules(self, decision_id):
        p = ALL_PERSONAS[decision_id]()
        c = make_context(eligibility=elig(), procedures=[proc("D6010")])
        c.catalogue_rules = {}
        out = p.run(c)
        assert isinstance(out, list)
        assert not any(s["signal_code"].endswith("_ERROR") for s in out), out

    def test_make_signal_refuses_auto_execute(self):
        p = EligibilityAnalyst()
        with pytest.raises(ValueError, match="auto_execute"):
            p.make_signal("X", "y", mode="auto_execute")

    def test_make_signal_refuses_code_with_no_finding(self):
        p = EligibilityAnalyst()
        with pytest.raises(ValueError, match="finding"):
            p.make_signal("X", "")

    def test_no_persona_exposes_add_flag(self):
        """RULE 7 — make_signal() only."""
        for cls in ALL_PERSONAS.values():
            assert not hasattr(cls, "add_flag"), cls


# ═════════════════════════════════════════════════════════════════════
# T-22 eligibility_analyst
# ═════════════════════════════════════════════════════════════════════


class TestEligibilityAnalyst:
    def test_da_a01_verified(self, rules):
        c = ctx_with_rules(
            rules, eligibility=elig(),
            procedures=[proc("D6010"), proc("D7953"), proc("D6065")])
        out = EligibilityAnalyst().run(c)
        assert "ELIGIBILITY_VERIFIED" in codes(out)
        assert by_code(out, "ELIGIBILITY_VERIFIED")["mode"] == "recommend"

    def test_da_b05_waiting_period_months_short_4(self, rules):
        c = ctx_with_rules(
            rules, scenario_id="DA-B05", patient_name="Ashley Thompson",
            eligibility=elig(enrollment_start="2025-12-05",
                             waiting_period_met=False),
            procedures=[proc("D2750", fee=1450.0)])
        out = EligibilityAnalyst().run(c)
        s = by_code(out, "ELIG_WAITING_PERIOD_NOT_MET")
        assert s["data"]["months_short"] == 4
        assert s["data"]["months_enrolled"] == 8
        assert s["mode"] == "human_approval"

    def test_da_b01_implants_not_covered(self, rules):
        c = ctx_with_rules(
            rules, scenario_id="DA-B01", patient_name="Patricia Johnson",
            eligibility=elig(implant_covered=False),
            procedures=[proc("D6010", fee=2800.0), proc("D6065", fee=1800.0)])
        out = EligibilityAnalyst().run(c)
        s = by_code(out, "ELIG_IMPLANTS_NOT_COVERED")
        assert s["mode"] == "human_approval"
        assert s["data"]["implant_codes"] == ["D6010", "D6065"]

    def test_da_c08_cob_required(self, rules):
        c = ctx_with_rules(
            rules, scenario_id="DA-C08",
            eligibility=elig(coordination_of_benefits=True),
            procedures=[proc("D2750")])
        out = EligibilityAnalyst().run(c)
        s = by_code(out, "ELIG_COB_REQUIRED")
        assert s["recommended_action"] == "verify_cob_primary_first"

    def test_frequency_exceeded_blocks(self, rules):
        c = ctx_with_rules(
            rules, scenario_id="DA-B03", patient_name="Dorothy Harris",
            eligibility=elig(), procedures=[proc("D2750")],
            clinical_evidence=[ev("EOB_PRIOR", {
                "cdt_codes": ["D2750"], "last_treatment_date": "2023-08-05"})])
        out = EligibilityAnalyst().run(c)
        s = by_code(out, "ELIG_FREQUENCY_EXCEEDED")
        assert s["mode"] == "human_approval"

    def test_frequency_unverified_is_advisory_not_blocking(self, rules):
        """An unrunnable check is reported, but does not withhold the
        verification decisions.yaml's recommend_if clause earns.

        ELIGIBILITY_VERIFIED tracks coverage_active + waiting_period_met
        + annual_max_remaining > 0 and nothing else. Suppressing it here
        would put the case in a state the boundary does not describe.
        """
        c = ctx_with_rules(rules, eligibility=elig(),
                           procedures=[proc("D2750")], clinical_evidence=[])
        out = EligibilityAnalyst().run(c)
        assert "ELIG_FREQUENCY_UNVERIFIED" in codes(out)
        assert "ELIGIBILITY_VERIFIED" in codes(out)
        assert all(s["mode"] == "recommend" for s in out)

    def test_human_approval_signal_does_withhold_verified(self, rules):
        c = ctx_with_rules(rules,
                           eligibility=elig(enrollment_start="2025-12-05",
                                            waiting_period_met=False),
                           procedures=[proc("D2750")])
        out = EligibilityAnalyst().run(c)
        assert "ELIGIBILITY_VERIFIED" not in codes(out)

    def test_annual_max_exhausted(self, rules):
        c = ctx_with_rules(
            rules, eligibility=elig(annual_max_remaining=0.0),
            procedures=[proc("D6010", fee=2800.0)])
        out = EligibilityAnalyst().run(c)
        assert "ELIG_ANNUAL_MAX_EXHAUSTED" in codes(out)


# ═════════════════════════════════════════════════════════════════════
# T-23 provider_credentialing
# ═════════════════════════════════════════════════════════════════════


class TestProviderCredentialing:
    def test_da_a01_verified(self, rules):
        c = ctx_with_rules(rules, provider_oig_excluded=False,
                           provider_npi_valid=True,
                           provider_network_status="in_network",
                           provider_specialty="General Practice",
                           procedures=[proc("D6010")])
        out = ProviderCredentialing().run(c)
        assert codes(out) == ["PROVIDER_VERIFIED"]
        assert out[0]["mode"] == "recommend"

    def test_da_c10_oig_excluded(self, rules):
        c = ctx_with_rules(
            rules, scenario_id="DA-C10", provider_npi="0000000001",
            provider_name="Excluded Provider Test",
            provider_oig_excluded=True, provider_npi_valid=False,
            procedures=[proc("D2750")])
        out = ProviderCredentialing().run(c)
        assert codes(out) == ["PROVIDER_OIG_EXCLUDED"]
        assert out[0]["mode"] == "human_approval"
        assert out[0]["citation"] == "42 CFR 1001.1901(b)"
        assert out[0]["recommended_action"] == "do_not_submit_under_this_npi"

    def test_oig_short_circuits_everything_else(self, rules):
        """An excluded provider yields ONE signal, not a list of gripes."""
        c = ctx_with_rules(rules, provider_oig_excluded=True,
                           provider_npi_valid=False,
                           provider_network_status="out_of_network",
                           procedures=[proc("D4260")])
        assert len(ProviderCredentialing().run(c)) == 1

    def test_out_of_network(self, rules):
        c = ctx_with_rules(rules, provider_oig_excluded=False,
                           provider_npi_valid=True,
                           provider_network_status="out_of_network",
                           procedures=[proc("D6010")])
        out = ProviderCredentialing().run(c)
        assert "PROVIDER_OUT_OF_NETWORK" in codes(out)

    def test_unverified_npi_is_not_invalid(self, rules):
        c = ctx_with_rules(rules, provider_oig_excluded=False,
                           provider_npi_valid=None,
                           procedures=[proc("D6010")])
        out = ProviderCredentialing().run(c)
        assert "PROVIDER_NPI_UNVERIFIED" in codes(out)
        assert "PROVIDER_NPI_INVALID" not in codes(out)


# ═════════════════════════════════════════════════════════════════════
# T-24 fraud_integrity
# ═════════════════════════════════════════════════════════════════════


class TestFraudIntegrity:
    def test_da_a01_integrity_verified(self, rules):
        c = ctx_with_rules(
            rules,
            procedures=[proc("D6010", fee=2800.0, allowed=1985.0),
                        proc("D7953", fee=950.0, allowed=425.0),
                        proc("D6065", fee=1800.0, allowed=1190.0)],
            clinical_evidence=[ev("CLINICAL_NOTE", {
                "cdt_codes_noted": ["D6010", "D6065", "D7953"],
                "narrative_present": True})],
            confirms_count=1, contradicts_count=0)
        out = FraudIntegrity().run(c)
        assert codes(out) == ["INTEGRITY_VERIFIED"]

    def test_da_f01_unbilled_procedure_advises(self, rules):
        c = ctx_with_rules(
            rules, scenario_id="DA-F01", patient_name="Thomas Garcia",
            procedures=[proc("D2740", tooth=3, fee=1650.0, allowed=1250.0,
                             surface="MI")],
            clinical_evidence=[ev("CLINICAL_NOTE", {
                "cdt_codes_noted": ["D2740", "D2750"],
                "narrative_present": True})])
        out = FraudIntegrity().run(c)
        # DA-F01: the note records D2740 AND D2750; only D2740 was
        # billed. That is under-billing, so it advises rather than
        # holding the submission — and it must not be reported as
        # upcoding, which is the opposite finding.
        s = by_code(out, "BILLING_UNBILLED_PROCEDURE")
        assert s["mode"] == "recommend"
        assert s["data"]["note_codes"] == ["D2740", "D2750"]
        assert not [x for x in out if x["signal_code"] == "FRAUD_UPCODING"]

    def test_da_f02_phantom_procedure(self, rules):
        c = ctx_with_rules(
            rules, scenario_id="DA-F02",
            procedures=[proc("D4260", tooth=None, fee=1850.0, allowed=1004.5)],
            clinical_evidence=[
                ev("CLINICAL_NOTE", {"cdt_codes_noted": ["D4260"]}),
                ev("PERIO_CHART", {"pocket_depth_max": 3.0, "sites_gte_5mm": 0}),
            ])
        out = FraudIntegrity().run(c)
        s = by_code(out, "INTEGRITY_CODE_NOT_DOCUMENTED")
        assert s["mode"] == "human_approval"

    def test_waived_copay(self, rules):
        c = ctx_with_rules(
            rules, procedures=[proc("D6010", fee=1985.0, allowed=1985.0)],
            clinical_evidence=[ev("CLINICAL_NOTE",
                                  {"cdt_codes_noted": ["D6010"]})])
        out = FraudIntegrity().run(c)
        assert by_code(out, "INTEGRITY_FEE_EQUALS_ALLOWED")["mode"] == "human_approval"

    def test_clinical_contradiction_is_reported(self, rules):
        c = ctx_with_rules(
            rules, procedures=[proc("D6010", fee=2800.0, allowed=1985.0)],
            clinical_evidence=[ev("CLINICAL_NOTE",
                                  {"cdt_codes_noted": ["D6010"]})],
            contradicts_count=1, confirms_count=1,
            contradicts_fields=["bone_loss_mm"])
        out = FraudIntegrity().run(c)
        assert "INTEGRITY_SURFACE_MISMATCH" in codes(out)
        assert "INTEGRITY_VERIFIED" not in codes(out)

    def test_bundling_contradiction_is_not_an_integrity_signal(self, rules):
        """DA-A01 carries a contradicts edge on field='bundling_conflict'.

        That is the coverage rule firing, modelled as a graph edge — not
        two documents disagreeing about a clinical fact. Counting it as
        fraud would flag the cleanest case in the catalogue.
        """
        c = ctx_with_rules(
            rules,
            procedures=[proc("D6010", fee=2800.0, allowed=1985.0),
                        proc("D7953", fee=950.0, allowed=425.0)],
            clinical_evidence=[ev("CLINICAL_NOTE", {
                "cdt_codes_noted": ["D6010", "D7953"]})],
            contradicts_count=1, confirms_count=1,
            contradicts_fields=["bundling_conflict"])
        out = FraudIntegrity().run(c)
        assert codes(out) == ["INTEGRITY_VERIFIED"]


# ═════════════════════════════════════════════════════════════════════
# T-25 coverage_analyst
# ═════════════════════════════════════════════════════════════════════


class TestCoverageAnalyst:
    def test_da_a01_bundling_plus_pred_required(self, rules):
        c = ctx_with_rules(
            rules,
            procedures=[
                ProcedureLine("D6010", 19, None, 2800.0, 1985.0, requires_pred=True),
                ProcedureLine("D7953", 19, None, 950.0, 425.0, requires_pred=True),
                ProcedureLine("D6065", 19, None, 1800.0, 1190.0,
                              downgrade_applied=True, downgrade_from="D6065",
                              requires_pred=True),
            ],
            has_bundling_conflict=True)
        out = CoverageAnalyst().run(c)
        assert "COVERAGE_BUNDLING_CONFLICT" in codes(out)
        assert "COVERAGE_PRED_REQUIRED" in codes(out)
        s = by_code(out, "COVERAGE_BUNDLING_CONFLICT")
        assert s["data"]["separable"] is True
        assert s["data"]["policy_section"] == "D.7.4"
        assert s["mode"] == "recommend"

    def test_hard_bundle_is_human_approval(self, rules):
        c = ctx_with_rules(rules,
                           procedures=[proc("D2950"), proc("D2750")],
                           has_bundling_conflict=True)
        out = CoverageAnalyst().run(c)
        s = by_code(out, "COVERAGE_BUNDLING_CONFLICT")
        assert s["mode"] == "human_approval"
        assert s["data"]["separable"] is False

    def test_da_c06_cigna_verified_no_downgrade(self, rules):
        """Cigna does not downgrade D2740 — Delta does."""
        c = ctx_with_rules(
            rules, scenario_id="DA-C06", payer_id="cigna",
            procedures=[ProcedureLine("D2740", 3, "MOD", 1650.0, 1250.0,
                                      downgrade_applied=False)],
            has_bundling_conflict=False)
        out = CoverageAnalyst().run(c)
        assert "COVERAGE_VERIFIED" in codes(out)
        assert "COVERAGE_DOWNGRADE_APPLIED" not in codes(out)

    def test_downgrade_reported(self, rules):
        rules["downgrade_matrix"] = {
            ("delta_dental", "D6065"): {"paid_cdt_code": "D2750",
                                        "policy_section": "D.7.2"}}
        c = ctx_with_rules(
            rules,
            procedures=[ProcedureLine("D6065", 19, None, 1800.0, 1190.0,
                                      patient_pays=595.0,
                                      downgrade_applied=True,
                                      downgrade_from="D6065")],
            has_bundling_conflict=False)
        out = CoverageAnalyst().run(c)
        s = by_code(out, "COVERAGE_DOWNGRADE_APPLIED")
        assert s["data"]["paid_code"] == "D2750"

    def test_upstream_block_is_noted_not_fatal(self, rules):
        c = ctx_with_rules(rules, procedures=[proc("D6010"), proc("D7953")],
                           has_bundling_conflict=True)
        c.upstream_outputs["eligibility_analyst"] = {"signals": [
            {"signal_code": "ELIG_IMPLANTS_NOT_COVERED",
             "mode": "human_approval"}]}
        out = CoverageAnalyst().run(c)
        assert "COVERAGE_UPSTREAM_BLOCKED" in codes(out)
        assert "COVERAGE_BUNDLING_CONFLICT" in codes(out)


# ═════════════════════════════════════════════════════════════════════
# T-26 clinical_reviewer
# ═════════════════════════════════════════════════════════════════════


class TestClinicalReviewer:
    def test_da_a01_criteria_met(self, rules):
        c = ctx_with_rules(
            rules, criteria_score=0.85,
            procedures=[proc("D6010"), proc("D7953")],
            clinical_evidence=[
                ev("XRAY_PA", {"bone_loss_mm": 4.2, "tooth_number": 19}),
                ev("CLINICAL_NOTE", {"narrative_present": True}),
            ])
        out = ClinicalReviewer().run(c)
        s = by_code(out, "CLINICAL_CRITERIA_MET")
        assert s["data"]["bone_loss_mm"] == 4.2
        assert s["data"]["threshold"] == 3.0
        assert s["data"]["confidence_label"] == "High confidence"

    def test_da_a01_narrative_missing(self, rules):
        c = ctx_with_rules(
            rules, criteria_score=0.85,
            procedures=[proc("D6010"), proc("D7953")],
            clinical_evidence=[
                ev("XRAY_PA", {"bone_loss_mm": 4.2}),
                ev("CLINICAL_NOTE", {"narrative_present": False}),
            ])
        out = ClinicalReviewer().run(c)
        s = by_code(out, "CLINICAL_NARRATIVE_MISSING")
        assert "INDEPENDENT" in s["finding"]
        assert s["recommended_action"] == "add_clinical_narrative"

    def test_da_c02_criteria_not_met(self, rules):
        c = ctx_with_rules(
            rules, scenario_id="DA-C02", criteria_score=0.5,
            procedures=[proc("D7953")],
            clinical_evidence=[
                ev("XRAY_PA", {"bone_loss_mm": 2.1}),
                ev("CLINICAL_NOTE", {"narrative_present": True}),
            ])
        out = ClinicalReviewer().run(c)
        s = by_code(out, "CLINICAL_CRITERIA_NOT_MET")
        assert s["data"]["bone_loss_mm"] == 2.1

    def test_da_c09_medical_history_flag(self, rules):
        rules["medical_history_flags"] = {
            "BISPHOS_IV": {
                "flag_name": "IV Bisphosphonate Therapy",
                "risk_level": "absolute_contraindication",
                "contraindicated_cdts": ["D6010", "D7953", "D4260"],
                "clinical_action": "Do not place implants.",
                "documentation_required": "Oncology clearance",
            }}
        c = ctx_with_rules(
            rules, scenario_id="DA-C09", criteria_score=1.0,
            procedures=[proc("D6010")],
            open_conditions=["CLINICAL_MEDICAL_HISTORY_FLAG"],
            clinical_evidence=[ev("XRAY_PA", {"bone_loss_mm": 4.2}),
                               ev("CLINICAL_NOTE", {"narrative_present": True})])
        out = ClinicalReviewer().run(c)
        s = by_code(out, "CLINICAL_MEDICAL_HISTORY_FLAG")
        assert s["mode"] == "human_approval"
        assert s["data"]["flag"] == "BISPHOS_IV"
        assert s["data"]["risk"] == "absolute_contraindication"

    def test_da_c01_xray_required(self, rules):
        c = ctx_with_rules(
            rules, scenario_id="DA-C01", criteria_score=0.4,
            procedures=[proc("D6010"), proc("D7953")],
            clinical_evidence=[ev("CLINICAL_NOTE", {"narrative_present": True})])
        out = ClinicalReviewer().run(c)
        assert "CLINICAL_XRAY_REQUIRED" in codes(out)

    def test_oig_upstream_suspends_review(self, rules):
        c = ctx_with_rules(rules, procedures=[proc("D6010")],
                           clinical_evidence=[ev("XRAY_PA", {"bone_loss_mm": 4.2})])
        c.upstream_outputs["provider_credentialing"] = {"signals": [
            {"signal_code": "PROVIDER_OIG_EXCLUDED", "mode": "human_approval"}]}
        out = ClinicalReviewer().run(c)
        assert codes(out) == ["CLINICAL_REVIEW_BLOCKED"]
        assert out[0]["mode"] == "human_approval"


# ═════════════════════════════════════════════════════════════════════
# T-27 documentation_reviewer
# ═════════════════════════════════════════════════════════════════════


class TestDocumentationReviewer:
    def _wave2(self, c, separable=True):
        c.upstream_outputs["coverage_analyst"] = {"signals": [{
            "signal_code": "COVERAGE_BUNDLING_CONFLICT", "mode": "recommend",
            "data": {"primary": "D6010", "bundled": "D7953",
                     "separable": separable, "policy_section": "D.7.4",
                     "separation_criteria": "PA X-ray + narrative"}}]}
        c.upstream_outputs["clinical_reviewer"] = {"signals": [
            {"signal_code": "CLINICAL_NARRATIVE_MISSING", "mode": "recommend"}]}
        return c

    def test_da_a01_narrative_missing_cites_d74(self, rules):
        c = self._wave2(ctx_with_rules(
            rules, procedures=[proc("D6010"), proc("D7953")],
            clinical_evidence=[
                ev("XRAY_PA", {"bone_loss_mm": 4.2}),
                ev("CLINICAL_NOTE", {"narrative_present": False}),
            ]))
        out = DocumentationReviewer().run(c)
        s = by_code(out, "DOC_NARRATIVE_MISSING")
        assert s["data"]["policy_section"] == "D.7.4"
        assert s["data"]["blocks_separation"] is True
        assert s["recommended_action"] == "request_clinical_narrative"

    def test_da_c01_xray_missing(self, rules):
        c = ctx_with_rules(rules, scenario_id="DA-C01",
                           procedures=[proc("D6010"), proc("D7953")],
                           clinical_evidence=[ev("CLINICAL_NOTE",
                                                 {"narrative_present": True})])
        out = DocumentationReviewer().run(c)
        s = by_code(out, "DOC_XRAY_MISSING")
        assert s["assignee"] == "front_desk"
        assert s["sla_hours"] == 48

    def test_da_c04_xray_too_old(self, rules):
        c = ctx_with_rules(rules, procedures=[proc("D2750")],
                           clinical_evidence=[ev("XRAY_PA",
                                                 {"bone_loss_mm": 3.5},
                                                 received_at="2024-01-01")])
        out = DocumentationReviewer().run(c)
        assert "DOC_XRAY_TOO_OLD" in codes(out)

    def test_da_m05_low_confidence(self, rules):
        c = ctx_with_rules(rules, procedures=[proc("D2750")],
                           clinical_evidence=[ev("XRAY_PA",
                                                 {"bone_loss_mm": 3.5},
                                                 confidence=0.45)])
        out = DocumentationReviewer().run(c)
        s = by_code(out, "DOC_LOW_CONFIDENCE")
        assert s["data"]["confidence"] == 0.45

    def test_da_m01_member_id_mismatch(self, rules):
        c = ctx_with_rules(
            rules, scenario_id="DA-M01",
            eligibility=elig(member_id_mismatch=True),
            procedures=[proc("D2750")],
            clinical_evidence=[ev("XRAY_PA", {"bone_loss_mm": 3.5})])
        out = DocumentationReviewer().run(c)
        assert by_code(out, "DOC_MEMBER_ID_MISMATCH")["mode"] == "human_approval"

    def test_complete_packet(self, rules):
        c = ctx_with_rules(
            rules, procedures=[proc("D6010")],
            clinical_evidence=[
                ev("XRAY_PA", {"bone_loss_mm": 4.2}),
                ev("CLINICAL_NOTE", {"narrative_present": True}),
            ])
        out = DocumentationReviewer().run(c)
        assert codes(out) == ["DOCUMENTATION_COMPLETE"]


# ═════════════════════════════════════════════════════════════════════
# T-28 appeal_specialist
# ═════════════════════════════════════════════════════════════════════


# A denial_events row, as ContextBuilder loads it. Its presence is the
# gate; the resolver still reads dates and codes off payer_response.
DENIED_EVENT = {
    "denial_id": "test-denial",
    "denied_at": "2026-07-31",
    "denial_reason": "bundling",
    "denial_reason_code": "D.7.4-BUNDLE",
    "denied_amount": 1230.00,
    "appeal_deadline": "2026-09-29",
    "appeal_viable": True,
}


class TestAppealSpecialist:
    def test_pended_with_no_denial_emits_nothing(self, rules):
        """The DA-A01 defect: pended is a PREDICTION, not a refusal.

        payer_responses says "pended" on 20 of the 40 cases and none of
        them has been sent anywhere. Appealing something no payer has
        refused is not a thing, and this used to emit APPEAL_VIABLE and
        APPEAL_PACKET_READY on exactly that.
        """
        c = ctx_with_rules(
            rules, decision="pended",
            procedures=[proc("D6010"), proc("D7953")],
            open_conditions=["COVERAGE_BUNDLING_CONFLICT"],
            clinical_evidence=[ev("XRAY_PA", {"bone_loss_mm": 4.2}),
                               ev("CLINICAL_NOTE", {"narrative_present": True})],
            payer_response=PayerResponse(decision="pended",
                                         appeal_deadline="2026-10-04",
                                         pend_checklist=["COVERAGE_BUNDLING_CONFLICT"]))
        assert AppealSpecialist().run(c) == []

    def test_bundling_is_viable_once_really_denied(self, rules):
        c = ctx_with_rules(
            rules, decision="pended", denial_event=DENIED_EVENT,
            procedures=[proc("D6010"), proc("D7953")],
            open_conditions=["COVERAGE_BUNDLING_CONFLICT"],
            clinical_evidence=[ev("XRAY_PA", {"bone_loss_mm": 4.2}),
                               ev("CLINICAL_NOTE", {"narrative_present": True})],
            payer_response=PayerResponse(decision="pended",
                                         appeal_deadline="2026-10-04",
                                         pend_checklist=["COVERAGE_BUNDLING_CONFLICT"]))
        out = AppealSpecialist().run(c)
        s = by_code(out, "APPEAL_VIABLE")
        assert s["data"]["success_probability"] == 0.65
        assert s["mode"] == "human_approval"
        assert "65%" in s["finding"]

    def test_da_b01_not_viable(self, rules):
        c = ctx_with_rules(
            rules, decision="denied", denial_event=DENIED_EVENT, scenario_id="DA-B01",
            procedures=[proc("D6010")],
            payer_response=PayerResponse(decision="denied",
                                         denial_reason_code="D.1.2",
                                         appeal_deadline="2026-10-04"))
        out = AppealSpecialist().run(c)
        s = by_code(out, "APPEAL_NOT_VIABLE")
        assert s["data"]["success_probability"] == 0.0
        assert s["recommended_action"] == "do_not_appeal"

    def test_da_b05_waiting_period_not_viable(self, rules):
        c = ctx_with_rules(
            rules, decision="denied", denial_event=DENIED_EVENT, scenario_id="DA-B05",
            procedures=[proc("D2750")],
            payer_response=PayerResponse(decision="denied",
                                         denial_reason_code="D.2.1",
                                         appeal_deadline="2026-10-04"))
        out = AppealSpecialist().run(c)
        assert by_code(out, "APPEAL_NOT_VIABLE")["data"]["denial_category"] == "waiting_period"

    def test_approved_case_emits_nothing(self, rules):
        c = ctx_with_rules(rules, decision="approved",
                           payer_response=PayerResponse(decision="approved"))
        assert AppealSpecialist().run(c) == []

    def test_deadline_passed_short_circuits(self, rules):
        # The deadline now comes off the DENIAL, not the fixture — so
        # the past date has to be on the denial_event for this to test
        # what it says it tests.
        c = ctx_with_rules(
            rules, decision="denied",
            denial_event={**DENIED_EVENT, "appeal_deadline": "2020-01-01"},
            procedures=[proc("D2750")],
            payer_response=PayerResponse(decision="denied",
                                         denial_reason_code="D.4.1",
                                         appeal_deadline="2020-01-01"))
        out = AppealSpecialist().run(c)
        assert codes(out) == ["APPEAL_NOT_VIABLE"]


# ═════════════════════════════════════════════════════════════════════
# T-29 dso_portfolio_manager
# ═════════════════════════════════════════════════════════════════════


class TestDSOPortfolioManager:
    def test_no_stats_says_so(self, rules):
        out = DSOPortfolioManager().run(ctx_with_rules(rules))
        assert codes(out) == ["PORTFOLIO_UNAVAILABLE"]

    def test_with_stats(self, rules):
        c = ctx_with_rules(rules, portfolio_stats={
            "total_pred_requests": 35, "approved_count": 8,
            "denied_count": 7, "pended_count": 20,
            "avg_criteria_score": 0.8243, "first_pass_approval_rate": 0.2286,
            "total_billed": 128505.0, "total_insurance_pays": 29221.52,
            "total_patient_pays": 52230.03, "revenue_at_risk": 20000.0,
            "denial_by_condition": [{"condition_code": "COVERAGE_PRED_REQUIRED",
                                     "n": 33}],
            "denial_by_payer": [
                {"payer_id": "delta_dental", "total": 30, "denied": 7},
                {"payer_id": "cigna", "total": 3, "denied": 0}],
            "low_confidence_doc_count": 0, "avg_extraction_confidence": 0.92,
        })
        out = DSOPortfolioManager().run(c)
        assert "PORTFOLIO_DENIAL_PATTERN" in codes(out)
        assert "PORTFOLIO_REVENUE_AT_RISK" in codes(out)
        assert "PORTFOLIO_TRAINING_NEEDED" in codes(out)
        assert all(s["mode"] == "recommend" for s in out)

    def test_never_blocks(self, rules):
        """Hard rule: portfolio_never_blocks_a_case."""
        c = ctx_with_rules(rules, portfolio_stats={
            "total_pred_requests": 35, "denied_count": 35,
            "revenue_at_risk": 999999.0, "denial_by_condition": [],
            "denial_by_payer": []})
        assert all(s["mode"] == "recommend" for s in DSOPortfolioManager().run(c))
