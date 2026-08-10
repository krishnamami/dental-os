"""
Unit tests for the 8 dental resolvers.

DB-LESS BY CONSTRUCTION. Every fixture is a hand-built PredContext, so
these run in milliseconds and cannot pass or fail because of RDS state.
The values in them were read off the live database on 2026-08-05 and
are cited per fixture; scripts/test_resolvers_integration.py is what
checks they still match reality.

    python -m pytest tests/resolvers/ -v
"""
from __future__ import annotations

from datetime import date

import pytest

from core.context.pred_context import (
    ClinicalEvidence,
    EligibilityProfile,
    PayerResponse,
    PredContext,
    ProcedureLine,
)
from core.resolvers import (
    ALL_RESOLVERS,
    resolve_appeal_viability,
    resolve_bone_loss,
    resolve_bundling,
    resolve_completeness,
    resolve_frequency,
    resolve_perio,
    resolve_upcoding,
    resolve_waiting_period,
)

# Frozen "today" so enrollment maths cannot drift as the suite ages.
TODAY = date(2026, 8, 5)


# ─────────────────────────────────────────────────────────────────────
# Catalogue fixture — the subset of rules the resolvers read.
# Values verified against the live RDS 2026-08-05.
# ─────────────────────────────────────────────────────────────────────


@pytest.fixture
def rules() -> dict:
    return {
        "ada_thresholds": {
            "D6010": {"bone_loss_mm_min": 3.0, "auto_approve_score": 0.85,
                      "auto_deny_score": 0.30, "age_min": 18.0,
                      "citation": "ADA CDT-2026 D6010; AAOMS 2024"},
            "D7953": {"bone_loss_mm_min": 3.0, "auto_approve_score": 0.85,
                      "auto_deny_score": 0.30, "citation": "ADA CDT-2026 D7953"},
            "D4260": {"pocket_depth_mm_min": 5.0, "sites_min": 6.0,
                      "bone_loss_pct_min": 25.0, "auto_approve_score": 0.85,
                      "auto_deny_score": 0.30},
            "D4341": {"pocket_depth_mm_min": 4.0, "auto_approve_score": 0.80,
                      "auto_deny_score": 0.30},
        },
        "bundling_rules": {
            ("D7953", "D6010"): {
                "bundling_type": "soft", "separable": True,
                "policy_section": "D.7.4", "denial_reason_code": "97",
                "scope": "same_site_within_30_days", "payer_id": "delta_dental",
                "separation_criteria": "Requires: (1) PA X-ray showing bone loss "
                                       ">=3mm documented separately, (2) narrative",
                "applies_to_all_payers": False, "governed_by": "payer", "layer": 2,
            },
            ("D6010", "D7953"): {
                "bundling_type": "soft", "separable": True,
                "policy_section": "D.7.4", "payer_id": "delta_dental",
                "separation_criteria": "…", "applies_to_all_payers": False,
                "governed_by": "payer", "layer": 2, "_reversed": True,
            },
            ("D2950", "D2750"): {
                "bundling_type": "hard", "separable": False,
                "policy_section": "ADA coding standard", "payer_id": None,
                "separation_criteria": None, "applies_to_all_payers": True,
                "governed_by": "ADA_coding_standard", "layer": 1,
            },
            ("D2750", "D2950"): {
                "bundling_type": "hard", "separable": False,
                "policy_section": "ADA coding standard", "payer_id": None,
                "applies_to_all_payers": True,
                "governed_by": "ADA_coding_standard", "layer": 1, "_reversed": True,
            },
        },
        "frequency_limits": {
            ("delta_dental", "D0330"): {"frequency_count": 1,
                                        "frequency_period": "per_5_years",
                                        "frequency_scope": "per_patient",
                                        "governed_by": "payer"},
            ("metlife", "D0330"): {"frequency_count": 1,
                                   "frequency_period": "per_3_years",
                                   "frequency_scope": "per_patient",
                                   "governed_by": "payer"},
            ("delta_dental", "D2750"): {"frequency_count": 1,
                                        "frequency_period": "per_5_years",
                                        "frequency_scope": "per_tooth",
                                        "governed_by": "payer"},
        },
        "cdt_rules": {
            "D6010": {"requires_xray": True, "requires_narrative": True,
                      "requires_perio_chart": False, "age_limit_min": 18},
            "D7953": {"requires_xray": True, "requires_narrative": True,
                      "requires_perio_chart": False},
            "D6065": {"requires_xray": True, "requires_narrative": False,
                      "requires_perio_chart": False},
            "D4341": {"requires_xray": False, "requires_narrative": False,
                      "requires_perio_chart": True},
            "D4260": {"requires_xray": True, "requires_narrative": True,
                      "requires_perio_chart": True},
            "D2750": {"requires_xray": True, "requires_narrative": False,
                      "requires_perio_chart": False},
        },
        "conditions_library": {},
    }


# ─────────────────────────────────────────────────────────────────────
# Context builders
# ─────────────────────────────────────────────────────────────────────


def make_context(**kw) -> PredContext:
    defaults = dict(
        pred_request_id="PRED-SIM-DA-A01", tenant_id="suwanee_smiles",
        scenario_id="DA-A01", patient_name="James Mitchell",
        provider_name="SRIDHAR CHINTA", provider_npi="1134534266",
        plan_name="Delta Dental PPO", payer_id="delta_dental",
        decision="pended", criteria_score=0.85,
        confidence_label="High confidence", has_bundling_conflict=True,
        open_conditions=[], decision_trace=[], medical_necessity_met=True,
        missing_evidence=[],
    )
    defaults.update(kw)
    return PredContext(**defaults)


def elig(**kw) -> EligibilityProfile:
    defaults = dict(
        coverage_active=True, payer_id="delta_dental", plan_type="PPO",
        annual_maximum=1500.0, annual_max_remaining=1800.0,
        deductible_remaining=50.0, benefit_pct_preventive=100.0,
        benefit_pct_basic=80.0, benefit_pct_major=50.0,
        benefit_pct_implants=50.0, implant_covered=True,
        waiting_period_met=True, missing_tooth_clause_triggered=False,
        coordination_of_benefits=False, enrollment_start="2020-01-01",
        waiting_period_basic_months=6, waiting_period_major_months=12,
        waiting_period_implant_months=12,
    )
    defaults.update(kw)
    return EligibilityProfile(**defaults)


def ev(document_type, fields=None, confidence=1.0, s3_key="s3/x.pdf",
       received_at="2026-08-05", method="deterministic") -> ClinicalEvidence:
    return ClinicalEvidence(
        document_type=document_type, s3_key=s3_key,
        extracted_fields=fields or {}, confidence_score=confidence,
        extraction_method=method, received_at=received_at,
    )


def proc(cdt, tooth=19, fee=1000.0, allowed=800.0, surface=None) -> ProcedureLine:
    return ProcedureLine(
        cdt_code=cdt, tooth_number=tooth, tooth_surface=surface,
        fee_submitted=fee, allowed_amount=allowed, patient_pays=200.0,
    )


# ═════════════════════════════════════════════════════════════════════
# Contract — applies to every resolver
# ═════════════════════════════════════════════════════════════════════


class TestResolverContract:
    """RULE 11 + never-raises, enforced on all 8 uniformly."""

    @pytest.mark.parametrize("name", sorted(ALL_RESOLVERS))
    def test_reports_data_source_and_missing_inputs(self, name, rules):
        ctx = make_context(eligibility=elig(), procedures=[proc("D6010")])
        out = ALL_RESOLVERS[name](ctx, rules)
        assert "data_source" in out, f"{name} omits data_source"
        assert "missing_inputs" in out, f"{name} omits missing_inputs"
        assert isinstance(out["missing_inputs"], list)
        assert out["data_source"], f"{name} data_source is empty"

    @pytest.mark.parametrize("name", sorted(ALL_RESOLVERS))
    def test_never_raises_on_empty_context(self, name, rules):
        ctx = make_context(eligibility=None, procedures=[], clinical_evidence=[])
        out = ALL_RESOLVERS[name](ctx, rules)
        assert isinstance(out, dict)

    @pytest.mark.parametrize("name", sorted(ALL_RESOLVERS))
    def test_never_raises_on_empty_rules(self, name):
        ctx = make_context(eligibility=elig(), procedures=[proc("D6010")])
        out = ALL_RESOLVERS[name](ctx, {})
        assert isinstance(out, dict)

    @pytest.mark.parametrize("name", sorted(ALL_RESOLVERS))
    def test_never_raises_on_garbage(self, name, rules):
        ctx = make_context(
            eligibility=elig(enrollment_start="not-a-date"),
            procedures=[proc("D6010", tooth="banana", fee="free", allowed=None)],
            clinical_evidence=[ev("XRAY_PA", {"bone_loss_mm": "lots"})],
            criteria_score="high",
        )
        out = ALL_RESOLVERS[name](ctx, rules)
        assert isinstance(out, dict)
        assert "error" not in out, f"{name} raised on garbage: {out.get('error')}"


# ═════════════════════════════════════════════════════════════════════
# T-13 waiting period
# ═════════════════════════════════════════════════════════════════════


class TestWaitingPeriod:
    def test_da_b05_months_short_is_4(self, rules):
        """DA-B05 Ashley Thompson — enrolled 2025-12-05, 12 months required."""
        ctx = make_context(
            scenario_id="DA-B05", patient_name="Ashley Thompson",
            eligibility=elig(enrollment_start="2025-12-05", waiting_period_met=False),
            procedures=[proc("D2750")],
        )
        out = resolve_waiting_period(ctx, rules, today=TODAY)
        assert out["months_enrolled"] == 8
        assert out["months_required_applicable"] == 12
        assert out["months_short"] == 4
        assert out["waiting_period_met"] is False

    def test_da_d03_months_short_is_1(self, rules):
        """DA-D03 Susan Lee — enrolled 2025-09-05."""
        ctx = make_context(
            scenario_id="DA-D03", patient_name="Susan Lee",
            eligibility=elig(enrollment_start="2025-09-05", waiting_period_met=False),
            procedures=[proc("D6010"), proc("D6065")],
        )
        out = resolve_waiting_period(ctx, rules, today=TODAY)
        assert out["months_enrolled"] == 11
        assert out["months_short"] == 1
        assert out["waiting_period_met"] is False

    def test_da_a01_met(self, rules):
        ctx = make_context(
            eligibility=elig(enrollment_start="2020-01-01"),
            procedures=[proc("D6010")],
        )
        out = resolve_waiting_period(ctx, rules, today=TODAY)
        assert out["waiting_period_met"] is True
        assert out["months_short"] == 0

    def test_implant_period_used_for_d6_codes(self, rules):
        """A D6 code must be measured against the IMPLANT period, not major."""
        ctx = make_context(
            eligibility=elig(enrollment_start="2025-01-05",
                             waiting_period_major_months=12,
                             waiting_period_implant_months=24),
            procedures=[proc("D6010")],
        )
        out = resolve_waiting_period(ctx, rules, today=TODAY)
        assert out["applicable_category"] == "implant"
        assert out["months_required_applicable"] == 24
        assert out["waiting_period_met"] is False

    def test_missing_enrollment_reports_not_guesses(self, rules):
        ctx = make_context(
            eligibility=elig(enrollment_start=None), procedures=[proc("D6010")]
        )
        out = resolve_waiting_period(ctx, rules, today=TODAY)
        assert out["waiting_period_met"] is None
        assert "enrollment_start" in out["missing_inputs"]

    def test_safe_default_when_plan_months_absent(self, rules):
        ctx = make_context(
            eligibility=elig(waiting_period_major_months=None,
                             waiting_period_implant_months=None),
            procedures=[proc("D2750")],
        )
        out = resolve_waiting_period(ctx, rules, today=TODAY)
        assert "major" in out["used_safe_defaults"]
        assert out["months_required_major"] == 12


# ═════════════════════════════════════════════════════════════════════
# T-14 frequency
# ═════════════════════════════════════════════════════════════════════


class TestFrequency:
    def test_no_prior_date_is_none_not_false(self, rules):
        """The whole point: unknown must not read as verified-clear."""
        ctx = make_context(procedures=[proc("D2750")], clinical_evidence=[])
        out = resolve_frequency(ctx, rules, today=TODAY)
        assert out["any_exceeded"] is None
        assert "last_treatment_date" in out["missing_inputs"]
        assert out["codes_undeterminable"] == 1

    def test_exceeded_when_prior_date_present(self, rules):
        """DA-B03 shape: crown 3 years ago against a 5-year limit."""
        ctx = make_context(
            procedures=[proc("D2750")],
            clinical_evidence=[ev("EOB_PRIOR", {
                "cdt_codes": ["D2750"], "last_treatment_date": "2023-08-05"})],
        )
        out = resolve_frequency(ctx, rules, today=TODAY)
        v = out["frequency_violations"][0]
        assert v["days_since_last"] == 1096
        assert v["days_required"] == 1825
        assert v["exceeded"] is True
        assert out["any_exceeded"] is True

    def test_metlife_d0330_not_exceeded_where_delta_would_be(self, rules):
        """DA-C07 — the payer divergence that proves the hierarchy works.

        3.5 years since the last pan. MetLife allows 1 per 3 years, so it
        is clear. Delta allows 1 per 5 years, so the same facts breach.
        """
        prior = ev("EOB_PRIOR", {"cdt_codes": ["D0330"],
                                 "last_treatment_date": "2023-02-05"})
        metlife = make_context(scenario_id="DA-C07", patient_name="Kevin Adams",
                               payer_id="metlife", procedures=[proc("D0330")],
                               clinical_evidence=[prior])
        out_m = resolve_frequency(metlife, rules, today=TODAY)
        assert out_m["frequency_violations"][0]["frequency_period"] == "per_3_years"
        assert out_m["frequency_violations"][0]["exceeded"] is False
        assert out_m["any_exceeded"] is False

        delta = make_context(payer_id="delta_dental", procedures=[proc("D0330")],
                             clinical_evidence=[prior])
        out_d = resolve_frequency(delta, rules, today=TODAY)
        assert out_d["frequency_violations"][0]["frequency_period"] == "per_5_years"
        assert out_d["frequency_violations"][0]["exceeded"] is True

    def test_near_limit_flags_gaming_window(self, rules):
        """DA-F03 shape: crown 4y11m into a 5-year limit — 15 days short.

        Still EXCEEDED (it is inside the limit, hence DA-F03's denial),
        and simultaneously near_limit, which is the gaming signal. The
        two are not alternatives.
        """
        ctx = make_context(
            procedures=[proc("D2750")],
            clinical_evidence=[ev("EOB_PRIOR", {
                "cdt_codes": ["D2750"], "last_treatment_date": "2021-08-20"})],
        )
        out = resolve_frequency(ctx, rules, today=TODAY)
        v = out["frequency_violations"][0]
        assert v["days_since_last"] == 1811
        assert v["days_required"] == 1825
        assert v["exceeded"] is True
        assert v["near_limit"] is True
        assert out["any_near_limit"] is True

    def test_just_past_limit_also_flags_gaming(self, rules):
        """Mirror image: billing 14 days AFTER the limit clears."""
        ctx = make_context(
            procedures=[proc("D2750")],
            clinical_evidence=[ev("EOB_PRIOR", {
                "cdt_codes": ["D2750"], "last_treatment_date": "2021-07-22"})],
        )
        out = resolve_frequency(ctx, rules, today=TODAY)
        v = out["frequency_violations"][0]
        assert v["exceeded"] is False
        assert v["near_limit"] is True

    def test_comfortably_clear_is_not_gaming(self, rules):
        ctx = make_context(
            procedures=[proc("D2750")],
            clinical_evidence=[ev("EOB_PRIOR", {
                "cdt_codes": ["D2750"], "last_treatment_date": "2015-01-01"})],
        )
        out = resolve_frequency(ctx, rules, today=TODAY)
        v = out["frequency_violations"][0]
        assert v["exceeded"] is False
        assert v["near_limit"] is False

    def test_code_with_no_limit_is_not_a_violation(self, rules):
        ctx = make_context(procedures=[proc("D9999")])
        out = resolve_frequency(ctx, rules, today=TODAY)
        assert out["procedures_checked"] == 0
        assert out["any_exceeded"] is None


# ═════════════════════════════════════════════════════════════════════
# T-15 bundling
# ═════════════════════════════════════════════════════════════════════


class TestBundling:
    def test_da_a01_soft_conflict_separable_d74(self, rules):
        ctx = make_context(
            procedures=[proc("D6010"), proc("D7953"), proc("D6065")],
            has_bundling_conflict=True,
        )
        out = resolve_bundling(ctx, rules)
        assert out["any_conflict"] is True
        assert out["soft_conflicts"] == 1
        assert out["hard_conflicts"] == 0
        c = out["conflicts"][0]
        assert c["separable"] is True
        assert c["policy_section"] == "D.7.4"
        assert c["bundling_type"] == "soft"
        assert out["separation_possible"] is True

    def test_hard_conflict_not_separable(self, rules):
        ctx = make_context(procedures=[proc("D2950"), proc("D2750")])
        out = resolve_bundling(ctx, rules)
        assert out["hard_conflicts"] == 1
        assert out["conflicts"][0]["separable"] is False
        assert out["separation_possible"] is False
        assert out["blocking_conflicts"]

    def test_billed_order_does_not_change_the_answer(self, rules):
        a = resolve_bundling(make_context(procedures=[proc("D7953"), proc("D6010")]), rules)
        b = resolve_bundling(make_context(procedures=[proc("D6010"), proc("D7953")]), rules)
        assert a["any_conflict"] == b["any_conflict"] is True
        assert a["conflicts"][0]["policy_section"] == b["conflicts"][0]["policy_section"]

    def test_no_conflict_when_codes_do_not_pair(self, rules):
        ctx = make_context(procedures=[proc("D0330")], has_bundling_conflict=False)
        out = resolve_bundling(ctx, rules)
        assert out["any_conflict"] is False
        assert out["separation_possible"] is False

    def test_reports_disagreement_with_pred_state(self, rules):
        ctx = make_context(procedures=[proc("D0330")], has_bundling_conflict=True)
        out = resolve_bundling(ctx, rules)
        assert out["disagrees_with_pred_state"] is True


# ═════════════════════════════════════════════════════════════════════
# T-16 bone loss
# ═════════════════════════════════════════════════════════════════════


class TestBoneLoss:
    def test_da_a01_met(self, rules):
        ctx = make_context(
            procedures=[proc("D6010"), proc("D7953")],
            clinical_evidence=[ev("XRAY_PA", {"bone_loss_mm": 4.2,
                                              "bone_loss_pct": 35.0,
                                              "tooth_number": 19})],
        )
        out = resolve_bone_loss(ctx, rules)
        assert out["bone_loss_mm"] == 4.2
        assert out["threshold_mm"] == 3.0
        assert out["criteria_met"] is True
        assert out["margin_mm"] == 1.2
        assert out["tooth_number"] == 19
        assert out["missing_inputs"] == []

    def test_da_c02_not_met(self, rules):
        ctx = make_context(
            scenario_id="DA-C02", procedures=[proc("D4260")],
            clinical_evidence=[ev("XRAY_PA", {"bone_loss_mm": 2.1})],
        )
        out = resolve_bone_loss(ctx, rules)
        assert out["bone_loss_mm"] == 2.1
        assert out["criteria_met"] is False
        assert out["margin_mm"] == -0.9

    def test_da_c01_no_xray_is_none_not_false(self, rules):
        ctx = make_context(scenario_id="DA-C01",
                           procedures=[proc("D6010"), proc("D7953")],
                           clinical_evidence=[])
        out = resolve_bone_loss(ctx, rules)
        assert out["bone_loss_mm"] is None
        assert out["criteria_met"] is None
        assert "bone_loss_mm" in out["missing_inputs"]
        assert "XRAY_PA" in out["missing_inputs"]
        assert out["xray_present"] is False

    def test_xray_present_but_field_missing(self, rules):
        """DA-M05 shape — the document is there, the measurement is not."""
        ctx = make_context(
            procedures=[proc("D2750")],
            clinical_evidence=[ev("XRAY_PA", {"tooth_number": 3}, confidence=0.75)],
        )
        out = resolve_bone_loss(ctx, rules)
        assert out["xray_present"] is True
        assert out["criteria_met"] is None
        assert "bone_loss_mm" in out["missing_inputs"]
        assert "XRAY_PA" not in out["missing_inputs"]

    def test_safe_default_when_threshold_uncatalogued(self):
        ctx = make_context(
            procedures=[proc("D6010")],
            clinical_evidence=[ev("XRAY_PA", {"bone_loss_mm": 4.2})],
        )
        out = resolve_bone_loss(ctx, {"ada_thresholds": {}})
        assert out["threshold_mm"] == 3.0
        assert out["threshold_governed_by"] == "safe_default"


# ═════════════════════════════════════════════════════════════════════
# T-17 perio
# ═════════════════════════════════════════════════════════════════════


class TestPerio:
    def test_da_a04_surgical_met(self, rules):
        ctx = make_context(
            scenario_id="DA-A04", patient_name="Maria Rodriguez",
            procedures=[proc("D4341")],
            clinical_evidence=[ev("PERIO_CHART", {
                "pocket_depth_max": 6.0, "sites_gte_5mm": 8,
                "bleeding_pct": 42.0, "perio_diagnosis": "Stage III Periodontitis",
                "exam_date": "2026-08-04"})],
        )
        out = resolve_perio(ctx, rules, today=TODAY)
        assert out["pocket_depth_max"] == 6.0
        assert out["sites_gte_5mm"] == 8
        assert out["surgical_threshold_met"] is True
        assert out["srp_threshold_met"] is True
        assert out["is_current"] is True

    def test_da_f02_surgical_not_met(self, rules):
        """The phantom-procedure chart: 3.0mm max, zero deep sites."""
        ctx = make_context(
            scenario_id="DA-F02", patient_name="Mary Johnson",
            procedures=[proc("D4260")],
            clinical_evidence=[ev("PERIO_CHART", {
                "pocket_depth_max": 3.0, "sites_gte_5mm": 0,
                "bleeding_pct": 8.0,
                "perio_diagnosis": "Gingivitis / no attachment loss",
                "exam_date": "2026-08-04"})],
        )
        out = resolve_perio(ctx, rules, today=TODAY)
        assert out["surgical_threshold_met"] is False
        assert out["srp_threshold_met"] is False

    def test_sites_short_fails_the_and(self, rules):
        """Depth alone is not enough — D4260 needs depth AND site count."""
        ctx = make_context(
            procedures=[proc("D4260")],
            clinical_evidence=[ev("PERIO_CHART", {
                "pocket_depth_max": 5.5, "sites_gte_5mm": 3,
                "exam_date": "2026-08-04"})],
        )
        out = resolve_perio(ctx, rules, today=TODAY)
        assert out["surgical_threshold_met"] is False
        assert out["srp_threshold_met"] is True

    def test_missing_chart_is_none(self, rules):
        ctx = make_context(procedures=[proc("D4260")], clinical_evidence=[])
        out = resolve_perio(ctx, rules, today=TODAY)
        assert out["surgical_threshold_met"] is None
        assert out["srp_threshold_met"] is None
        assert "PERIO_CHART" in out["missing_inputs"]

    def test_stale_chart_flagged(self, rules):
        ctx = make_context(
            procedures=[proc("D4260")],
            clinical_evidence=[ev("PERIO_CHART",
                                  {"pocket_depth_max": 6.0, "sites_gte_5mm": 8,
                                   "exam_date": "2025-06-01"},
                                  received_at="2025-06-01")],
        )
        out = resolve_perio(ctx, rules, today=TODAY)
        assert out["is_current"] is False
        assert out["days_old"] > 183


# ═════════════════════════════════════════════════════════════════════
# T-18 appeal viability
# ═════════════════════════════════════════════════════════════════════


class TestAppealViability:
    def test_bundling_case_viable_at_65_pct(self, rules):
        """DA-B04 shape — pended with a bundling conflict, evidence on file."""
        ctx = make_context(
            scenario_id="DA-B04", patient_name="Carlos Rivera",
            procedures=[proc("D6010"), proc("D7953")],
            open_conditions=["COVERAGE_BUNDLING_CONFLICT"],
            clinical_evidence=[
                ev("XRAY_PA", {"bone_loss_mm": 4.2}),
                ev("CLINICAL_NOTE", {"narrative_present": True}),
            ],
            payer_response=PayerResponse(
                decision="pended", pred_number="DD-2026-DA-B04-PND",
                appeal_deadline="2026-10-04",
                pend_checklist=["COVERAGE_BUNDLING_CONFLICT"]),
        )
        out = resolve_appeal_viability(ctx, rules, today=TODAY)
        assert out["applicable"] is True
        assert out["viable"] is True
        assert out["success_probability"] == 0.65
        assert out["denial_category"] == "bundling_separable"
        assert out["citation"] == "D.7.4"

    def test_bundling_case_weak_without_narrative(self, rules):
        ctx = make_context(
            procedures=[proc("D6010"), proc("D7953")],
            open_conditions=["COVERAGE_BUNDLING_CONFLICT"],
            clinical_evidence=[ev("XRAY_PA", {"bone_loss_mm": 4.2})],
            payer_response=PayerResponse(decision="pended",
                                         appeal_deadline="2026-10-04"),
        )
        out = resolve_appeal_viability(ctx, rules, today=TODAY)
        assert out["viable"] is False
        assert any("narrative" in m for m in out["missing_evidence"])

    def test_da_b01_exclusion_not_viable(self, rules):
        """DA-B01 Patricia Johnson — implants excluded, D.1.2."""
        ctx = make_context(
            scenario_id="DA-B01", patient_name="Patricia Johnson",
            procedures=[proc("D6010"), proc("D6065")],
            payer_response=PayerResponse(
                decision="denied", denial_reason_code="D.1.2",
                denial_reason_text="Implants excluded from this plan",
                appeal_deadline="2026-10-04"),
        )
        out = resolve_appeal_viability(ctx, rules, today=TODAY)
        assert out["viable"] is False
        assert out["success_probability"] == 0.0
        assert out["denial_category"] == "plan_exclusion"

    def test_da_b05_waiting_period_not_viable(self, rules):
        """A date fact. No documentation shortens a waiting period."""
        ctx = make_context(
            scenario_id="DA-B05", patient_name="Ashley Thompson",
            procedures=[proc("D2750")],
            payer_response=PayerResponse(
                decision="denied", denial_reason_code="D.2.1",
                appeal_deadline="2026-10-04"),
        )
        out = resolve_appeal_viability(ctx, rules, today=TODAY)
        assert out["viable"] is False
        assert out["success_probability"] == 0.0
        assert out["denial_category"] == "waiting_period"

    def test_frequency_denial_not_viable(self, rules):
        ctx = make_context(
            procedures=[proc("D2750")],
            payer_response=PayerResponse(decision="denied",
                                         denial_reason_code="D.3.1",
                                         appeal_deadline="2026-10-04"),
        )
        out = resolve_appeal_viability(ctx, rules, today=TODAY)
        assert out["viable"] is False
        assert out["denial_category"] == "frequency_limit"

    def test_deadline_warning_inside_14_days(self, rules):
        ctx = make_context(
            procedures=[proc("D2750")],
            payer_response=PayerResponse(decision="denied",
                                         denial_reason_code="D.4.1",
                                         appeal_deadline="2026-08-12"),
        )
        out = resolve_appeal_viability(ctx, rules, today=TODAY)
        assert out["days_remaining"] == 7
        assert out["deadline_warning"] is True

    def test_passed_deadline_blocks(self, rules):
        ctx = make_context(
            procedures=[proc("D2750")],
            payer_response=PayerResponse(decision="denied",
                                         denial_reason_code="D.4.1",
                                         appeal_deadline="2026-07-01"),
        )
        out = resolve_appeal_viability(ctx, rules, today=TODAY)
        assert out["deadline_passed"] is True
        assert out["viable"] is False
        assert out["success_probability"] == 0.0

    def test_approved_case_not_applicable(self, rules):
        ctx = make_context(payer_response=PayerResponse(decision="approved"))
        out = resolve_appeal_viability(ctx, rules, today=TODAY)
        assert out["applicable"] is False

    def test_no_response_yet(self, rules):
        out = resolve_appeal_viability(make_context(), rules, today=TODAY)
        assert out["applicable"] is False
        assert "payer_response" in out["missing_inputs"]


# ═════════════════════════════════════════════════════════════════════
# T-19 completeness
# ═════════════════════════════════════════════════════════════════════


class TestCompleteness:
    def test_da_c01_missing_xray(self, rules):
        ctx = make_context(
            scenario_id="DA-C01", patient_name="Robert Kim",
            procedures=[proc("D6010"), proc("D7953")],
            clinical_evidence=[ev("CLINICAL_NOTE", {"narrative_present": True})],
        )
        out = resolve_completeness(ctx, rules, today=TODAY)
        assert "XRAY_PA" in out["missing_docs"]
        assert out["is_complete"] is False
        assert out["required_docs"]["XRAY_PA"] is True

    def test_da_a01_complete(self, rules):
        ctx = make_context(
            procedures=[proc("D6010"), proc("D7953"), proc("D6065")],
            clinical_evidence=[
                ev("XRAY_PA", {"bone_loss_mm": 4.2}, confidence=1.0),
                ev("CLINICAL_NOTE", {"narrative_present": True}, confidence=0.9),
            ],
        )
        out = resolve_completeness(ctx, rules, today=TODAY)
        assert out["missing_docs"] == []
        assert out["completeness_score"] == 1.0
        assert out["narrative_present"] is True

    def test_low_confidence_flagged_at_trust_floor(self, rules):
        ctx = make_context(
            procedures=[proc("D2750")],
            clinical_evidence=[ev("XRAY_PA", {"bone_loss_mm": 3.5}, confidence=0.45)],
        )
        out = resolve_completeness(ctx, rules, today=TODAY)
        assert out["low_confidence_docs"]
        assert out["low_confidence_docs"][0]["confidence"] == 0.45
        assert out["trust_floor"] == 0.70

    def test_confidence_between_floors_is_acceptable(self, rules):
        """0.75 clears TRUST_FLOOR 0.70 even though it is above the
        extractors' 0.6 fallback trigger. The two floors are different
        questions — PRD Known Gap #5."""
        ctx = make_context(
            procedures=[proc("D2750")],
            clinical_evidence=[ev("XRAY_PA", {"bone_loss_mm": 3.5}, confidence=0.75)],
        )
        out = resolve_completeness(ctx, rules, today=TODAY)
        assert out["low_confidence_docs"] == []

    def test_outdated_xray_flagged(self, rules):
        ctx = make_context(
            procedures=[proc("D2750")],
            clinical_evidence=[ev("XRAY_PA", {"bone_loss_mm": 3.5},
                                  received_at="2024-01-01")],
        )
        out = resolve_completeness(ctx, rules, today=TODAY)
        assert out["outdated_docs"]
        assert out["outdated_docs"][0]["document_type"] == "XRAY_PA"

    def test_note_present_but_narrative_false(self, rules):
        """A note on file is not the same as a note that argues necessity."""
        ctx = make_context(
            procedures=[proc("D7953")],
            clinical_evidence=[
                ev("XRAY_PA", {"bone_loss_mm": 4.2}),
                ev("CLINICAL_NOTE", {"narrative_present": False}),
            ],
        )
        out = resolve_completeness(ctx, rules, today=TODAY)
        assert "CLINICAL_NOTE.narrative" in out["missing_docs"]
        assert out["narrative_present"] is False

    def test_uncatalogued_code_reported(self, rules):
        ctx = make_context(procedures=[proc("D9999")])
        out = resolve_completeness(ctx, rules, today=TODAY)
        assert "D9999" in out["uncatalogued_codes"]
        assert any("cdt_rules" in m for m in out["missing_inputs"])


# ═════════════════════════════════════════════════════════════════════
# T-20 upcoding / fraud signals
# ═════════════════════════════════════════════════════════════════════


class TestUpcoding:
    def test_da_f01_upcoding(self, rules):
        """DA-F01 Thomas Garcia — billed D2740, note documents both."""
        ctx = make_context(
            scenario_id="DA-F01", patient_name="Thomas Garcia",
            procedures=[proc("D2740", tooth=3, fee=1650.0, allowed=1250.0,
                             surface="MI")],
            clinical_evidence=[ev("CLINICAL_NOTE", {
                "cdt_codes_noted": ["D2740", "D2750"], "narrative_present": True})],
        )
        out = resolve_upcoding(ctx, rules)
        assert out["any_fraud_signal"] is True
        assert "BILLING_UNBILLED_PROCEDURE" in out["signal_types"]
        assert "FRAUD_UPCODING" not in out["signal_types"]
        assert out["note_codes"] == ["D2740", "D2750"]

    def test_da_a01_clean(self, rules):
        ctx = make_context(
            procedures=[proc("D6010", fee=2800.0, allowed=1985.0),
                        proc("D7953", fee=950.0, allowed=425.0),
                        proc("D6065", fee=1800.0, allowed=1190.0)],
            clinical_evidence=[ev("CLINICAL_NOTE", {
                "cdt_codes_noted": ["D6010", "D6065", "D7953"],
                "narrative_present": True})],
        )
        out = resolve_upcoding(ctx, rules)
        assert out["any_fraud_signal"] is False
        assert out["signals"] == []

    def test_da_f02_phantom_procedure(self, rules):
        ctx = make_context(
            scenario_id="DA-F02", patient_name="Mary Johnson",
            procedures=[proc("D4260", tooth=None, fee=1850.0, allowed=1004.5)],
            clinical_evidence=[
                ev("CLINICAL_NOTE", {"cdt_codes_noted": ["D4260"],
                                     "narrative_present": True}),
                ev("PERIO_CHART", {"pocket_depth_max": 3.0, "sites_gte_5mm": 0}),
            ],
        )
        out = resolve_upcoding(ctx, rules)
        assert "INTEGRITY_CODE_NOT_DOCUMENTED" in out["signal_types"]
        assert out["signals"][0]["severity"] == "high"

    def test_waived_copay_when_fee_equals_allowed(self, rules):
        """DA-C09 shape — fee 1985.00, allowed 1985.00."""
        ctx = make_context(
            procedures=[proc("D6010", fee=1985.0, allowed=1985.0)],
            clinical_evidence=[ev("CLINICAL_NOTE", {
                "cdt_codes_noted": ["D6010"], "narrative_present": True})],
        )
        out = resolve_upcoding(ctx, rules)
        assert "INTEGRITY_FEE_EQUALS_ALLOWED" in out["signal_types"]

    def test_surface_conflict(self, rules):
        ctx = make_context(
            procedures=[proc("D2750", tooth=3, surface="MOD",
                             fee=1450.0, allowed=1190.0)],
            clinical_evidence=[
                ev("CLINICAL_NOTE", {"cdt_codes_noted": ["D2750"]}),
                ev("XRAY_PA", {"tooth_surface": "DO"}),
            ],
        )
        out = resolve_upcoding(ctx, rules)
        assert "INTEGRITY_SURFACE_MISMATCH" in out["signal_types"]

    def test_no_note_reports_missing_not_clean(self, rules):
        ctx = make_context(procedures=[proc("D6010", fee=2800.0, allowed=1985.0)],
                           clinical_evidence=[])
        out = resolve_upcoding(ctx, rules)
        assert "clinical_note" in out["missing_inputs"]
        assert out["clinical_note_present"] is False
