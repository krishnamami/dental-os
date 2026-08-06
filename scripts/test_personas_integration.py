"""
Runs Waves 1-3 (and 5) against a REAL PredContext built from the RDS,
threading each wave's output into the next as upstream context.

    python scripts/test_personas_integration.py [PRED-SIM-DA-XXX]
    python scripts/test_personas_integration.py --sweep
"""
import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from dotenv import load_dotenv

load_dotenv()

from core.catalogue.context_enricher import ContextEnricher  # noqa: E402
from core.context.context_builder import ContextBuilder  # noqa: E402
from core.db.connection import (  # noqa: E402
    DEFAULT_TENANT,
    close_pool,
    fetch_with_tenant,
    get_pool,
)
from domains.dental.personas import (  # noqa: E402
    AppealSpecialist,
    ClinicalReviewer,
    CoverageAnalyst,
    DocumentationReviewer,
    DSOPortfolioManager,
    EligibilityAnalyst,
    FraudIntegrity,
    ProviderCredentialing,
)

failures: list[str] = []


def check(label, actual, expected):
    if actual != expected:
        failures.append(f"{label}: got {actual!r}, expected {expected!r}")
        return "x"
    return "+"


def run_waves(context) -> list[dict]:
    """Waves 1 -> 2 -> 3 -> 5, threading upstream_outputs forward."""
    # Wave 1 — independent, no upstream
    w1 = {
        "eligibility_analyst": EligibilityAnalyst().run(context),
        "provider_credentialing": ProviderCredentialing().run(context),
        "fraud_integrity": FraudIntegrity().run(context),
    }
    for did, sigs in w1.items():
        context.upstream_outputs[did] = {"signals": sigs}

    # Wave 2 — inherits Wave 1
    w2 = {
        "coverage_analyst": CoverageAnalyst().run(context),
        "clinical_reviewer": ClinicalReviewer().run(context),
    }
    for did, sigs in w2.items():
        context.upstream_outputs[did] = {"signals": sigs}

    # Wave 3 — inherits Wave 2
    w3 = {"documentation_reviewer": DocumentationReviewer().run(context)}
    for did, sigs in w3.items():
        context.upstream_outputs[did] = {"signals": sigs}

    # Wave 5 — appeal runs only on denied/pended; portfolio needs aggregate
    w5 = {
        "appeal_specialist": AppealSpecialist().run(context),
        "dso_portfolio_manager": DSOPortfolioManager().run(context),
    }
    for did, sigs in w5.items():
        context.upstream_outputs[did] = {"signals": sigs}

    out: list[dict] = []
    for group in (w1, w2, w3, w5):
        for sigs in group.values():
            out.extend(sigs)
    return out


async def load_portfolio(pool) -> dict:
    rows = await fetch_with_tenant(
        pool, DEFAULT_TENANT, "SELECT * FROM vw_portfolio_context")
    return dict(rows[0]) if rows else {}


async def one(pool, pred_id: str, portfolio: dict, verbose=True) -> list[dict]:
    ctx = await ContextBuilder(pool).build(pred_id)
    ctx = await ContextEnricher(pool).enrich(ctx)
    ctx.portfolio_stats = portfolio
    signals = run_waves(ctx)

    if not verbose:
        return signals

    core = [s for s in signals if s["wave"] <= 3]
    print(f"{ctx.scenario_id} — {ctx.patient_name} ({ctx.payer_id}) — "
          f"decision={ctx.decision}")
    print(f"{len(core)} signals across 6 personas (waves 1-3):\n")
    for s in core:
        print(f"  [{s['wave']}] {s['signal_code']:32} mode={s['mode']}")
    print()
    for s in signals:
        if s["wave"] == 5:
            print(f"  [5] {s['signal_code']:32} mode={s['mode']}")

    print("\n  What the front desk actually reads:")
    for s in core:
        if s.get("recommended_action"):
            print(f"    - {s['finding']}")
            print(f"      -> {s['recommended_action']}"
                  + (f"  (SLA {s['sla_hours']}h, {s['assignee']})"
                     if s.get("sla_hours") else ""))
    return signals


async def sweep(pool, portfolio) -> None:
    ids = [r["pred_request_id"] for r in await fetch_with_tenant(
        pool, DEFAULT_TENANT, "SELECT pred_request_id FROM pred_states ORDER BY 1")]
    print(f"Sweeping {len(ids)} scenarios x 8 personas\n")

    tally: dict[str, int] = {}
    errors = 0
    modes = {"recommend": 0, "human_approval": 0}
    for pid in ids:
        for s in await one(pool, pid, portfolio, verbose=False):
            tally[s["signal_code"]] = tally.get(s["signal_code"], 0) + 1
            modes[s["mode"]] = modes.get(s["mode"], 0) + 1
            if s["signal_code"].endswith("_ERROR"):
                errors += 1
                failures.append(f"{pid}: {s['finding']}")
            if s["mode"] not in ("recommend", "human_approval"):
                failures.append(f"{pid}: illegal mode {s['mode']}")

    print(f"  personas that errored: {errors}")
    print(f"  modes: recommend={modes['recommend']}  "
          f"human_approval={modes['human_approval']}  auto_execute=0")
    print("\n  Signal frequency across the catalogue:")
    for code, n in sorted(tally.items(), key=lambda kv: -kv[1]):
        print(f"    {code:34} {n}")


async def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    pred_id = args[0] if args else "PRED-SIM-DA-A01"
    pool = await get_pool()
    portfolio = await load_portfolio(pool)

    signals = await one(pool, pred_id, portfolio)

    if pred_id == "PRED-SIM-DA-A01":
        got = [s["signal_code"] for s in signals if s["wave"] <= 3]
        print("\n  Expected for DA-A01:")
        for code in ["ELIGIBILITY_VERIFIED", "PROVIDER_VERIFIED",
                     "INTEGRITY_VERIFIED", "COVERAGE_BUNDLING_CONFLICT",
                     "COVERAGE_PRED_REQUIRED", "CLINICAL_CRITERIA_MET",
                     "CLINICAL_NARRATIVE_MISSING", "DOC_NARRATIVE_MISSING"]:
            present = code in got
            if not present:
                failures.append(f"DA-A01 missing expected signal {code}")
            print(f"    {'+' if present else 'x'} {code}")
        print(f"\n    {check('no auto_execute', all(s['mode'] in ('recommend', 'human_approval') for s in signals), True)} "
              f"every signal is recommend or human_approval")

    if "--sweep" in sys.argv:
        print("\n" + "=" * 66)
        await sweep(pool, portfolio)

    await close_pool()

    print()
    if failures:
        print(f"x {len(failures)} failure(s):")
        for f in failures:
            print(f"  {f}")
        return 1
    print("+ ALL PERSONA CHECKS PASSED")
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
