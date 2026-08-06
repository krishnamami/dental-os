"""
Unit tests for coverage_resolver.

Every figure below was read off the live RDS on 2026-08-06 and
cross-checked against dental-simulator's own cost_estimates, which
computes the same claim independently.

    python -m pytest tests/resolvers/test_coverage_resolver.py -v
"""
from __future__ import annotations

from datetime import date

import pytest

from core.context.pred_context import ProcedureLine
from core.resolvers import resolve_coverage
from tests.resolvers.test_all_resolvers import elig, make_context

TODAY = date(2026, 8, 6)


def cov(payer, cdt, *, covered=True, pct=50.0, category="major",
        pre_d=False, deductible=True, downgrade=None, notes=None,
        age_min=None, age_max=None) -> tuple:
    return ((payer, cdt), {
        "covered": covered, "benefit_pct": pct, "coverage_pct": pct,
        "benefit_category": category, "pre_d_required": pre_d,
        "deductible_applies": deductible, "downgrade_to": downgrade,
        "notes": notes, "age_limit_min": age_min, "age_limit_max": age_max,
        "lifetime_maximum": None, "missing_tooth_clause": False,
    })


def fee(payer, cdt, state, amount, source="ga_medicaid_spa_ga25_0005") -> tuple:
    return ((payer, cdt, state), {
        "allowed_amount": amount, "source": source,
        "is_estimated": source.endswith("estimated"), "state": state,
    })


@pytest.fixture
def da_a01_rules() -> dict:
    return {
        "coverage_rules": dict([
            cov("delta_dental", "D6010", pct=50.0, category="implant", pre_d=True),
            cov("delta_dental", "D7953", pct=50.0, category="implant", pre_d=True),
            cov("delta_dental", "D6065", pct=50.0, category="implant", pre_d=True,
                downgrade="D2750"),
            cov("delta_dental", "D2750", pct=50.0, category="major", pre_d=True),
            cov("delta_dental", "D0330", pct=100.0, category="preventive",
                deductible=False),
            cov("delta_dental", "D2740", pct=50.0, category="major",
                pre_d=True, downgrade="D2750"),
            cov("cigna", "D2740", pct=50.0, category="major", pre_d=True),
            cov("metlife", "D0330", pct=100.0, category="preventive",
                deductible=False),
            cov("delta_dental", "D1310", covered=False, pct=0.0, category=None,
                notes="Nutritional counselling is not a covered benefit."),
        ]),
        "fee_schedules": dict([
            fee("delta_dental", "D6010", "GA", 1985.00),
            fee("delta_dental", "D7953", "GA", 425.00),
            fee("delta_dental", "D6065", "GA", 1190.00),
            fee("delta_dental", "D2750", "GA", 1190.00),
            fee("delta_dental", "D2740", "GA", 1250.00),
            fee("delta_dental", "D0330", "GA", 158.87),
            fee("delta_dental", "D1310", "GA", 60.00),
            fee("cigna", "D2740", "GA", 1312.50),
            fee("metlife", "D0330", "GA", 155.69),
        ]),
    }


def a01_context(**kw):
    defaults = dict(
        eligibility=elig(deductible_remaining=50.0, annual_max_remaining=1800.0),
        procedures=[
            ProcedureLine("D6010", 19, None, 2800.0, requires_pred=True),
            ProcedureLine("D7953", 19, None, 950.0, requires_pred=True),
            ProcedureLine("D6065", 19, None, 1800.0, requires_pred=True),
        ],
        patient_dob="1975-03-14",
    )
    defaults.update(kw)
    return make_context(**defaults)


def line(result, cdt) -> dict:
    return next(p for p in result["procedures"] if p["cdt_code"] == cdt)


# ═════════════════════════════════════════════════════════════════════
# DA-A01 — the reference case
# ═════════════════════════════════════════════════════════════════════


class TestDaA01:
    def test_d6010_absorbs_the_deductible(self, da_a01_rules):
        """First billed line takes the deductible; later lines do not."""
        r = resolve_coverage(a01_context(), da_a01_rules, today=TODAY)
        p = line(r, "D6010")
        assert p["provider_ucr_fee"] == 2800.00
        assert p["contracted_rate"] == 1985.00
        assert p["provider_discount"] == 815.00
        assert p["deductible_applied"] == 50.00
        assert p["insurance_pays"] == 967.50
        assert p["patient_pays"] == 1017.50
        assert p["pre_d_required"] is True
        assert p["downgrade_applied"] is False

    def test_d7953_pays_no_second_deductible(self, da_a01_rules):
        r = resolve_coverage(a01_context(), da_a01_rules, today=TODAY)
        p = line(r, "D7953")
        assert p["contracted_rate"] == 425.00
        assert p["provider_discount"] == 525.00
        assert p["deductible_applied"] == 0.00
        assert p["insurance_pays"] == 212.50
        assert p["patient_pays"] == 212.50

    def test_d6065_downgraded_to_d2750(self, da_a01_rules):
        r = resolve_coverage(a01_context(), da_a01_rules, today=TODAY)
        p = line(r, "D6065")
        assert p["downgrade_applied"] is True
        assert p["downgrade_to"] == "D2750"
        assert p["downgrade_from"] == "D6065"
        assert p["contracted_rate"] == 1190.00
        assert p["provider_discount"] == 610.00
        assert p["insurance_pays"] == 595.00
        assert p["patient_pays"] == 595.00

    def test_summary_matches_cost_estimates(self, da_a01_rules):
        """These totals equal dental-simulator's own cost_estimates."""
        s = resolve_coverage(a01_context(), da_a01_rules, today=TODAY)["summary"]
        assert s["total_ucr_fee"] == 5550.00
        assert s["total_contracted"] == 3600.00
        assert s["total_provider_discount"] == 1950.00
        assert s["total_deductible"] == 50.00
        assert s["total_insurance_pays"] == 1775.00
        assert s["total_patient_pays"] == 1825.00
        assert s["annual_max_remaining_after"] == 25.00
        assert s["patient_savings_in_network"] == 1950.00

    def test_ucr_reconciles(self, da_a01_rules):
        """contracted = ucr - discount, and patient + insurance = contracted."""
        s = resolve_coverage(a01_context(), da_a01_rules, today=TODAY)["summary"]
        assert s["total_contracted"] == pytest.approx(
            s["total_ucr_fee"] - s["total_provider_discount"])
        assert s["total_contracted"] == pytest.approx(
            s["total_insurance_pays"] + s["total_patient_pays"])

    def test_pre_d_required_for_all_three(self, da_a01_rules):
        r = resolve_coverage(a01_context(), da_a01_rules, today=TODAY)
        assert r["pre_d_required_for"] == ["D6010", "D7953", "D6065"]

    def test_contract_fields(self, da_a01_rules):
        r = resolve_coverage(a01_context(), da_a01_rules, today=TODAY)
        assert r["data_source"]
        assert isinstance(r["missing_inputs"], list)


# ═════════════════════════════════════════════════════════════════════
# Plan-level exclusion
# ═════════════════════════════════════════════════════════════════════


class TestNotCovered:
    def test_da_b01_plan_excludes_implants(self, da_a01_rules):
        """coverage_rules says D6010 is covered — the PLAN says otherwise.

        coverage_rules is per payer, not per plan. Reading only the
        code-level rule pays 50% on a plan that bought no implant rider
        and understates the patient's share by $1,500.
        """
        ctx = a01_context(
            scenario_id="DA-B01", patient_name="Patricia Johnson",
            eligibility=elig(implant_covered=False, deductible_remaining=50.0,
                             annual_max_remaining=1800.0),
            procedures=[ProcedureLine("D6010", 19, None, 2800.0),
                        ProcedureLine("D6065", 19, None, 1800.0)])
        r = resolve_coverage(ctx, da_a01_rules, today=TODAY)
        p = line(r, "D6010")
        assert p["covered"] is False
        assert p["insurance_pays"] == 0.0
        assert p["patient_pays"] == 1985.00
        assert "not appealable" in p["not_covered_reason"]
        # 1985 + 1190, matching cost_estimates for DA-B01.
        assert r["summary"]["total_patient_pays"] == 3175.00
        assert r["summary"]["total_insurance_pays"] == 0.0
        assert r["coverage_gaps"]

    def test_code_level_not_covered(self, da_a01_rules):
        ctx = a01_context(
            procedures=[ProcedureLine("D1310", None, None, 75.0)],
            eligibility=elig(deductible_remaining=0.0))
        r = resolve_coverage(ctx, da_a01_rules, today=TODAY)
        p = line(r, "D1310")
        assert p["covered"] is False
        assert p["insurance_pays"] == 0.0
        assert p["patient_pays"] == 60.00
        assert "Nutritional counselling" in p["not_covered_reason"]


# ═════════════════════════════════════════════════════════════════════
# Payer divergence
# ═════════════════════════════════════════════════════════════════════


class TestPayerDivergence:
    def test_da_c06_cigna_does_not_downgrade_d2740(self, da_a01_rules):
        ctx = a01_context(
            scenario_id="DA-C06", payer_id="cigna",
            eligibility=elig(deductible_remaining=0.0, annual_max_remaining=1500.0),
            procedures=[ProcedureLine("D2740", 3, "MOD", 1650.0)])
        r = resolve_coverage(ctx, da_a01_rules, today=TODAY)
        p = line(r, "D2740")
        assert p["downgrade_applied"] is False
        assert p["downgrade_to"] is None
        assert p["contracted_rate"] == 1312.50

    def test_delta_does_downgrade_d2740(self, da_a01_rules):
        ctx = a01_context(
            eligibility=elig(deductible_remaining=0.0, annual_max_remaining=1500.0),
            procedures=[ProcedureLine("D2740", 3, "MOD", 1650.0)])
        r = resolve_coverage(ctx, da_a01_rules, today=TODAY)
        p = line(r, "D2740")
        assert p["downgrade_applied"] is True
        assert p["downgrade_to"] == "D2750"
        assert p["contracted_rate"] == 1190.00

    def test_da_c07_metlife_d0330_preventive_100pct(self, da_a01_rules):
        ctx = a01_context(
            scenario_id="DA-C07", payer_id="metlife",
            eligibility=elig(deductible_remaining=50.0, annual_max_remaining=2000.0),
            procedures=[ProcedureLine("D0330", None, None, 155.0)])
        r = resolve_coverage(ctx, da_a01_rules, today=TODAY)
        p = line(r, "D0330")
        assert p["benefit_pct"] == 100.0
        assert p["covered"] is True
        # Preventive is paid before the deductible.
        assert p["deductible_applied"] == 0.0
        assert p["insurance_pays"] == 155.69
        assert p["patient_pays"] == 0.0


# ═════════════════════════════════════════════════════════════════════
# Annual maximum
# ═════════════════════════════════════════════════════════════════════


class TestAnnualMaximum:
    def test_capped_at_remaining(self, da_a01_rules):
        ctx = a01_context(
            eligibility=elig(deductible_remaining=0.0, annual_max_remaining=100.0),
            procedures=[ProcedureLine("D6010", 19, None, 2800.0)])
        r = resolve_coverage(ctx, da_a01_rules, today=TODAY)
        p = line(r, "D6010")
        assert p["insurance_pays"] == 100.00
        assert p["annual_max_exhausted"] is True
        assert p["patient_pays"] == 1885.00
        assert r["summary"]["annual_max_remaining_after"] == 0.0

    def test_consumed_across_procedures_in_billed_order(self, da_a01_rules):
        """The maximum is a running balance, not applied per line."""
        r = resolve_coverage(a01_context(), da_a01_rules, today=TODAY)
        assert line(r, "D6010")["annual_max_exhausted"] is False
        assert line(r, "D6065")["annual_max_exhausted"] is False
        assert r["summary"]["annual_max_used_this_case"] == 1775.00
        assert r["summary"]["annual_max_remaining_after"] == 25.00

    def test_exhausted_mid_case(self, da_a01_rules):
        ctx = a01_context(
            eligibility=elig(deductible_remaining=0.0, annual_max_remaining=1000.0))
        r = resolve_coverage(ctx, da_a01_rules, today=TODAY)
        assert line(r, "D6010")["insurance_pays"] == 992.50
        assert line(r, "D7953")["insurance_pays"] == 7.50
        assert line(r, "D7953")["annual_max_exhausted"] is True
        assert line(r, "D6065")["insurance_pays"] == 0.0
        assert r["summary"]["annual_max_remaining_after"] == 0.0


# ═════════════════════════════════════════════════════════════════════
# Degradation — never raises, never guesses silently
# ═════════════════════════════════════════════════════════════════════


class TestDegradation:
    def test_missing_coverage_rule_uses_safe_default(self):
        ctx = a01_context(procedures=[ProcedureLine("D9999", None, None, 500.0)])
        r = resolve_coverage(ctx, {}, today=TODAY)
        p = line(r, "D9999")
        assert p["used_safe_default_rule"] is True
        assert p["contracted_rate"] == 425.00        # 85% of UCR
        assert any("coverage_rule for D9999" in m for m in r["missing_inputs"])

    def test_missing_fee_schedule_is_reported(self, da_a01_rules):
        ctx = a01_context(procedures=[ProcedureLine("D6010", 19, None, 2800.0)],
                          state="TX")
        r = resolve_coverage(ctx, da_a01_rules, today=TODAY)
        assert any("fee_schedule for D6010" in m for m in r["missing_inputs"])

    def test_estimated_rates_are_flagged(self):
        rules = {
            "coverage_rules": dict([cov("delta_dental", "D6010", category="implant")]),
            "fee_schedules": dict([
                fee("delta_dental", "D6010", "GA", 1985.0, "estimated")]),
        }
        ctx = a01_context(procedures=[ProcedureLine("D6010", 19, None, 2800.0)])
        r = resolve_coverage(ctx, rules, today=TODAY)
        assert r["rates_estimated"] == ["D6010"]
        assert any("published fee schedule" in m for m in r["missing_inputs"])

    def test_no_eligibility_does_not_raise(self, da_a01_rules):
        ctx = a01_context(eligibility=None)
        r = resolve_coverage(ctx, da_a01_rules, today=TODAY)
        assert "error" not in r
        assert "eligibility_profile" in r["missing_inputs"]

    def test_garbage_does_not_raise(self, da_a01_rules):
        ctx = a01_context(
            procedures=[ProcedureLine("D6010", "x", None, "free")],
            patient_dob="not-a-date")
        r = resolve_coverage(ctx, da_a01_rules, today=TODAY)
        assert "error" not in r

    def test_empty_case(self, da_a01_rules):
        r = resolve_coverage(a01_context(procedures=[]), da_a01_rules, today=TODAY)
        assert r["procedures"] == []
        assert r["summary"]["total_patient_pays"] == 0.0

    def test_waiting_period_not_met_zeroes_the_benefit(self, da_a01_rules):
        """If the waiting period is not met the plan pays nothing.

        dental-simulator's cost_estimates prices these as though
        approved; this resolver prices what the patient would actually
        owe today. DA-B05 and DA-D03 differ from cost_estimates for
        exactly this reason, deliberately.
        """
        ctx = a01_context(
            eligibility=elig(waiting_period_met=False, deductible_remaining=0.0),
            procedures=[ProcedureLine("D6010", 19, None, 2800.0)])
        r = resolve_coverage(ctx, da_a01_rules, today=TODAY)
        p = line(r, "D6010")
        assert p["waiting_period_not_met"] is True
        assert p["insurance_pays"] == 0.0
        assert p["patient_pays"] == 1985.00

    def test_unknown_waiting_period_is_not_a_failure(self, da_a01_rules):
        """None means the 271 stayed quiet, not that the period failed."""
        e = elig(deductible_remaining=0.0)
        e.waiting_period_met = None
        ctx = a01_context(eligibility=e,
                          procedures=[ProcedureLine("D6010", 19, None, 2800.0)])
        r = resolve_coverage(ctx, da_a01_rules, today=TODAY)
        assert line(r, "D6010")["insurance_pays"] == 992.50

    def test_age_floor_blocks_benefit(self, da_a01_rules):
        rules = dict(da_a01_rules)
        rules["coverage_rules"] = dict(da_a01_rules["coverage_rules"])
        rules["coverage_rules"][("delta_dental", "D6010")] = {
            **da_a01_rules["coverage_rules"][("delta_dental", "D6010")],
            "age_limit_min": 18}
        ctx = a01_context(
            patient_dob="2015-01-01",
            eligibility=elig(deductible_remaining=0.0),
            procedures=[ProcedureLine("D6010", 19, None, 2800.0)])
        r = resolve_coverage(ctx, rules, today=TODAY)
        p = line(r, "D6010")
        assert p["age_below_minimum"] is True
        assert p["insurance_pays"] == 0.0

    def test_missing_dob_reports_rather_than_assumes(self, da_a01_rules):
        rules = dict(da_a01_rules)
        rules["coverage_rules"] = dict(da_a01_rules["coverage_rules"])
        rules["coverage_rules"][("delta_dental", "D6010")] = {
            **da_a01_rules["coverage_rules"][("delta_dental", "D6010")],
            "age_limit_min": 18}
        ctx = a01_context(
            patient_dob=None, eligibility=elig(deductible_remaining=0.0),
            procedures=[ProcedureLine("D6010", 19, None, 2800.0)])
        r = resolve_coverage(ctx, rules, today=TODAY)
        assert any("patient_dob" in m for m in r["missing_inputs"])
        assert line(r, "D6010")["insurance_pays"] == 992.50
