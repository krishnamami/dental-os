"""
Runs all 8 resolvers against a REAL PredContext built from the RDS.

The unit tests use hand-built fixtures and prove the logic. This proves
the fixtures still match reality — that the views, the catalogue and
the resolvers agree about what DA-A01 actually contains.

    python scripts/test_resolvers_integration.py [PRED-SIM-DA-XXX]
    python scripts/test_resolvers_integration.py --sweep
"""
import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from dotenv import load_dotenv

load_dotenv()

from core.catalogue.context_enricher import ContextEnricher  # noqa: E402
from core.context.context_builder import ContextBuilder  # noqa: E402
from core.db.connection import close_pool, get_pool  # noqa: E402
from core.resolvers import (  # noqa: E402
    resolve_appeal_viability,
    resolve_bone_loss,
    resolve_bundling,
    resolve_completeness,
    resolve_frequency,
    resolve_perio,
    resolve_upcoding,
    resolve_waiting_period,
)

failures: list[str] = []


def check(label, actual, expected):
    ok = actual == expected
    if not ok:
        failures.append(f"{label}: got {actual!r}, expected {expected!r}")
    return "+" if ok else "x"


def run_all(ctx) -> dict:
    r = ctx.catalogue_rules
    freq = resolve_frequency(ctx, r)
    # upcoding reads frequency's findings for the gaming signal rather
    # than redoing the prior-date lookup itself.
    r_with_freq = dict(r)
    r_with_freq["_frequency_findings"] = freq
    return {
        "waiting_period": resolve_waiting_period(ctx, r),
        "frequency": freq,
        "bundling": resolve_bundling(ctx, r),
        "bone_loss": resolve_bone_loss(ctx, r),
        "perio": resolve_perio(ctx, r),
        "completeness": resolve_completeness(ctx, r),
        "appeal": resolve_appeal_viability(ctx, r),
        "upcoding": resolve_upcoding(ctx, r_with_freq),
    }


async def one(pool, pred_id: str, verbose: bool = True) -> dict:
    ctx = await ContextBuilder(pool).build(pred_id)
    ctx = await ContextEnricher(pool).enrich(ctx)
    out = run_all(ctx)

    if not verbose:
        return out

    wp, freq = out["waiting_period"], out["frequency"]
    bund, bone = out["bundling"], out["bone_loss"]
    perio, comp = out["perio"], out["completeness"]
    appeal, fraud = out["appeal"], out["upcoding"]

    print(f"{ctx.scenario_id} Resolver Results — {ctx.patient_name} "
          f"({ctx.payer_id}, {ctx.state})")
    print(f"  decision={ctx.decision}  criteria_score={ctx.criteria_score}  "
          f"({ctx.confidence_label})")
    print()
    print(f"  Waiting period met: {wp['waiting_period_met']}"
          f"   (enrolled {wp['months_enrolled']}mo, need "
          f"{wp['months_required_applicable']}mo {wp['applicable_category']})")
    print(f"  Frequency exceeded: {freq['any_exceeded']}"
          f"   ({freq['procedures_checked']} code(s) with limits, "
          f"{freq['codes_undeterminable']} undeterminable)")
    print(f"  Bundling conflict:  {bund['any_conflict']}"
          f"   ({bund['soft_conflicts']} soft, {bund['hard_conflicts']} hard)")
    for c in bund["conflicts"]:
        print(f"    {c['primary_code']}+{c['bundled_code']} separable: "
              f"{c['separable']}")
        print(f"    Policy section: {c['policy_section']}")
    print(f"  Bone loss mm:       {bone['bone_loss_mm']}"
          f"   (threshold {bone['threshold_mm']}, "
          f"margin {bone['margin_mm']})")
    print(f"  Bone loss criteria met: {bone['criteria_met']}")
    print(f"  Perio surgical met: {perio['surgical_threshold_met']}"
          f"   (max {perio['pocket_depth_max']}mm, "
          f"{perio['sites_gte_5mm']} sites >=5mm)")
    print(f"  Missing docs:       {comp['missing_docs']}")
    print(f"    completeness_score={comp['completeness_score']}  "
          f"narrative_present={comp['narrative_present']}")
    if comp["low_confidence_docs"]:
        print(f"    low confidence: "
              f"{[d['document_type'] for d in comp['low_confidence_docs']]}")
    if comp["outdated_docs"]:
        print(f"    outdated: {[d['document_type'] for d in comp['outdated_docs']]}")
    print(f"  Appeal viable:      {appeal.get('viable')}"
          f"   (p={appeal.get('success_probability')}, "
          f"{appeal.get('denial_category')})")
    print(f"  Fraud signals:      {fraud['any_fraud_signal']}"
          f"   {fraud['signal_types'] or ''}")
    for s in fraud["signals"]:
        print(f"    [{s['severity']}] {s['signal_type']} {s['cdt_code']}")

    # RULE 11 — every resolver must report both fields.
    print("\n  RULE 11 (data_source + missing_inputs on every resolver):")
    for name, res in out.items():
        has_ds = bool(res.get("data_source"))
        has_mi = "missing_inputs" in res
        mark = "+" if (has_ds and has_mi) else "x"
        if not (has_ds and has_mi):
            failures.append(f"{name} violates RULE 11")
        mi = res.get("missing_inputs") or []
        print(f"    {mark} {name:16} missing_inputs={mi if mi else '[]'}")
    return out


async def sweep(pool) -> int:
    """Every scenario through every resolver. Nothing may raise."""
    from core.db.connection import DEFAULT_TENANT, fetch_with_tenant

    ids = [r["pred_request_id"] for r in await fetch_with_tenant(
        pool, DEFAULT_TENANT, "SELECT pred_request_id FROM pred_states ORDER BY 1")]
    print(f"Sweeping {len(ids)} scenarios x 8 resolvers "
          f"= {len(ids) * 8} resolver runs\n")

    raised = 0
    signal_tally: dict[str, int] = {}
    for pid in ids:
        out = await one(pool, pid, verbose=False)
        for name, res in out.items():
            if "error" in res:
                raised += 1
                failures.append(f"{pid} {name}: {res['error']}")
                print(f"  x {pid} {name}: {res['error']}")
            if not res.get("data_source") or "missing_inputs" not in res:
                failures.append(f"{pid} {name} violates RULE 11")
        for s in out["upcoding"]["signal_types"]:
            signal_tally[s] = signal_tally.get(s, 0) + 1

    print(f"  resolvers that raised: {raised} of {len(ids) * 8}")
    print("\n  Fraud signals across the catalogue:")
    for sig, n in sorted(signal_tally.items(), key=lambda kv: -kv[1]):
        print(f"    {sig:28} {n} scenario(s)")
    return raised


async def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    pred_id = args[0] if args else "PRED-SIM-DA-A01"
    pool = await get_pool()

    out = await one(pool, pred_id)

    if pred_id == "PRED-SIM-DA-A01":
        print("\n  Expected values for DA-A01:")
        wp, freq = out["waiting_period"], out["frequency"]
        bund, bone = out["bundling"], out["bone_loss"]
        comp, fraud = out["completeness"], out["upcoding"]
        c = bund["conflicts"][0] if bund["conflicts"] else {}
        for label, actual, expected in [
            ("Waiting period met", wp["waiting_period_met"], True),
            # None, not False — dental-simulator has no prior treatment
            # dates, so nobody can say. See frequency_resolver docstring.
            ("Frequency exceeded", freq["any_exceeded"], None),
            ("Bundling conflict", bund["any_conflict"], True),
            ("D7953+D6010 separable", c.get("separable"), True),
            ("Policy section", c.get("policy_section"), "D.7.4"),
            ("Bone loss mm", bone["bone_loss_mm"], 4.2),
            ("Bone loss criteria met", bone["criteria_met"], True),
            ("Missing docs", comp["missing_docs"], []),
            ("Fraud signals", fraud["any_fraud_signal"], False),
        ]:
            print(f"    {check(label, actual, expected)} {label:24} {actual!r}")

    if "--sweep" in sys.argv:
        print("\n" + "=" * 66)
        await sweep(pool)

    await close_pool()

    print()
    if failures:
        print(f"x {len(failures)} failure(s):")
        for f in failures:
            print(f"  {f}")
        return 1
    print("+ ALL RESOLVER CHECKS PASSED")
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
