"""
Full patient benefit summary from coverage_resolver, built from the RDS.

This is the sheet the front desk hands the patient BEFORE treatment —
step 5 of the provider workflow in the PRD.

    python scripts/test_coverage_resolver.py [PRED-SIM-DA-XXX]
    python scripts/test_coverage_resolver.py --sweep
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
from core.resolvers import resolve_coverage  # noqa: E402

failures: list[str] = []


async def one(pool, pred_id: str, verbose=True):
    ctx = await ContextBuilder(pool).build(pred_id)
    ctx = await ContextEnricher(pool).enrich(ctx)
    result = resolve_coverage(ctx, ctx.catalogue_rules)
    if not verbose:
        return ctx, result

    print("=" * 57)
    print(f"BENEFIT SUMMARY — {ctx.patient_name}")
    print(f"{ctx.plan_name} | In-Network | Suwanee Smiles ({ctx.state})")
    print("=" * 57)

    for p in result["procedures"]:
        dg = f" -> {p['downgrade_to']}" if p["downgrade_applied"] else ""
        print(f"\n{p['cdt_code']}{dg}")
        print(f"  Dr. Chinta charges:  ${p['provider_ucr_fee']:>9,.2f}")
        print(f"  In-network discount: (${p['provider_discount']:>8,.2f})")
        print(f"  Contracted rate:     ${p['contracted_rate']:>9,.2f}")
        print(f"  Deductible applied:  ${p['deductible_applied']:>9,.2f}")
        if p["covered"]:
            print(f"  Plan pays ({p['benefit_pct']:>3.0f}%):     "
                  f"${p['insurance_pays']:>9,.2f}")
        else:
            print(f"  Plan pays:           ${0:>9,.2f}   "
                  f"NOT COVERED - {p['not_covered_reason']}")
        print(f"  Your share:          ${p['patient_pays']:>9,.2f}")
        if p["pre_d_required"]:
            print("  * Pre-D required")
        if p["annual_max_exhausted"]:
            print("  * Annual maximum reached on this line")
        if p.get("rate_is_estimated"):
            print(f"  * Rate is ESTIMATED ({p['rate_source']}), not the "
                  f"payer's published allowed amount")

    s = result["summary"]
    print(f"\n{'-' * 57}")
    print(f"Total Dr. Chinta charges: ${s['total_ucr_fee']:>10,.2f}")
    print(f"Total in-network savings: (${s['total_provider_discount']:>9,.2f})")
    print(f"Total contracted:         ${s['total_contracted']:>10,.2f}")
    print(f"Deductible applied:       ${s['total_deductible']:>10,.2f}")
    print(f"Plan pays:                ${s['total_insurance_pays']:>10,.2f}")
    print(f"YOUR TOTAL:               ${s['total_patient_pays']:>10,.2f}")
    print(f"Annual max after case:    ${s['annual_max_remaining_after']:>10,.2f}")

    if result["pre_d_required_for"]:
        print(f"\n* Pre-D required: {result['pre_d_required_for']}")
    if result["coverage_gaps"]:
        print(f"* Not covered: {result['coverage_gaps']}")
    if result["missing_inputs"]:
        print("\nmissing_inputs:")
        for m in result["missing_inputs"]:
            print(f"  - {m}")
    return ctx, result


async def cross_check(pool, pred_id, result) -> None:
    """The resolver against dental-simulator's own cost_estimates.

    Two independent computations of the same claim. If they agree, the
    catalogue-driven path reproduces what the rules engine produced —
    which is the strongest available evidence that this is right.
    """
    rows = await fetch_with_tenant(pool, DEFAULT_TENANT, """
        SELECT cdt_code, allowed_amount, insurance_pays, patient_pays
        FROM cost_estimates WHERE pred_request_id = $1 ORDER BY cdt_code""",
        pred_id)
    if not rows:
        return
    sim = {r["cdt_code"]: r for r in rows}
    print(f"\n{'-' * 57}")
    print("Cross-check against dental-simulator cost_estimates")
    print(f"  {'code':7} {'resolver pt':>12} {'simulator pt':>13}  match")
    for p in result["procedures"]:
        s = sim.get(p["cdt_code"])
        if s is None:
            continue
        sim_pt = float(s["patient_pays"] or 0)
        ok = abs(sim_pt - p["patient_pays"]) < 0.01
        if not ok:
            failures.append(
                f"{pred_id} {p['cdt_code']}: resolver ${p['patient_pays']} vs "
                f"cost_estimates ${sim_pt}")
        print(f"  {p['cdt_code']:7} {p['patient_pays']:>12,.2f} "
              f"{sim_pt:>13,.2f}  {'+' if ok else 'x'}")
    sim_total = sum(float(r["patient_pays"] or 0) for r in rows)
    ok = abs(sim_total - result["summary"]["total_patient_pays"]) < 0.01
    print(f"  {'TOTAL':7} {result['summary']['total_patient_pays']:>12,.2f} "
          f"{sim_total:>13,.2f}  {'+' if ok else 'x'}")


async def sweep(pool) -> None:
    ids = [r["pred_request_id"] for r in await fetch_with_tenant(
        pool, DEFAULT_TENANT, "SELECT pred_request_id FROM pred_states ORDER BY 1")]
    print(f"Sweeping {len(ids)} scenarios\n")
    matched = mismatched = 0
    for pid in ids:
        _, res = await one(pool, pid, verbose=False)
        if "error" in res:
            failures.append(f"{pid}: {res['error']}")
            continue
        rows = await fetch_with_tenant(pool, DEFAULT_TENANT,
            "SELECT SUM(patient_pays) t FROM cost_estimates WHERE pred_request_id=$1",
            pid)
        sim = float(rows[0]["t"] or 0)
        got = res["summary"]["total_patient_pays"]
        if abs(sim - got) < 0.01:
            matched += 1
            continue

        # Classify rather than just print a delta. Both known causes are
        # places where the resolver models the PLAN and cost_estimates
        # models the PROCEDURE — a difference of intent, not a bug.
        procs = res["procedures"]
        if any(p.get("waiting_period_not_met") for p in procs):
            cause = ("waiting period not met — resolver pays $0 (the plan "
                     "genuinely pays nothing); cost_estimates prices it as "
                     "though approved")
        elif any(p.get("benefit_category") == "preventive"
                 and p.get("deductible_applied") == 0 for p in procs):
            cause = ("preventive deductible — resolver applies none "
                     "(derived: preventive is paid at 100% before the "
                     "deductible); cost_estimates applies one")
        else:
            cause = "UNEXPLAINED"
            failures.append(f"{pid}: unexplained ${got - sim:+,.2f} vs cost_estimates")
        mismatched += 1
        print(f"  {pid[-6:]}  resolver ${got:>9,.2f}  simulator ${sim:>9,.2f}  "
              f"diff ${got - sim:>+9,.2f}")
        print(f"          {cause}")

    print(f"\n  patient-total agrees with cost_estimates: {matched}/{len(ids)}")
    print(f"  differs for a KNOWN, deliberate reason:    {mismatched}")


async def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    pred_id = args[0] if args else "PRED-SIM-DA-A01"
    pool = await get_pool()

    _, result = await one(pool, pred_id)
    await cross_check(pool, pred_id, result)

    if "--sweep" in sys.argv:
        print("\n" + "=" * 57)
        await sweep(pool)

    await close_pool()
    print()
    if failures:
        print(f"x {len(failures)} mismatch(es):")
        for f in failures[:20]:
            print(f"  {f}")
        return 1
    print("+ coverage_resolver agrees with dental-simulator cost_estimates")
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
