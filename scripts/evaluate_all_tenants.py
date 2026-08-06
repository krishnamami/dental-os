"""
Sprint 2 — run all five waves for every practice, not just Suwanee.

    DATABASE_URL=... DENTAL_OS_DATABASE_URL=... \
      python scripts/evaluate_all_tenants.py
    python scripts/evaluate_all_tenants.py --tenant tampa_smiles
    python scripts/evaluate_all_tenants.py --skip-existing

The tenant list comes from the `tenants` table rather than a constant,
so a fourth practice is picked up without editing this file.

RLS: pred_requests is FORCE row-level security. Every read below sets
app.tenant_id for the tenant it is asking about — a missing setting
returns zero pre-Ds with no error, which would print "0 scenarios" and
look like the practice simply had none.
"""
from __future__ import annotations

import argparse
import asyncio
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from core.cron.runner import PersonaRunner  # noqa: E402
from core.db.connection import (  # noqa: E402
    DEFAULT_TENANT,
    close_pool,
    execute_os_with_tenant,
    fetch_with_tenant,
    get_os_pool,
    get_pool,
)

RULE = "=" * 70


async def tenants_from_db(sim_pool) -> list[str]:
    rows = await fetch_with_tenant(
        sim_pool, DEFAULT_TENANT,
        "SELECT tenant_id FROM tenants WHERE active ORDER BY tenant_id")
    return [r["tenant_id"] for r in rows]


async def pred_ids_for(sim_pool, tenant: str) -> list[str]:
    rows = await fetch_with_tenant(
        sim_pool, tenant,
        "SELECT pred_request_id FROM pred_requests WHERE tenant_id = $1"
        " ORDER BY pred_request_id", tenant)
    return [r["pred_request_id"] for r in rows]


async def already_run(os_pool, tenant: str) -> set[str]:
    rows = await execute_os_with_tenant(
        os_pool, tenant,
        "SELECT DISTINCT pred_request_id FROM persona_bundles"
        " WHERE tenant_id = $1 AND is_current", tenant)
    return {r["pred_request_id"] for r in rows}


async def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--tenant", help="one tenant only; default is all active")
    ap.add_argument("--skip-existing", action="store_true",
                    help="skip pre-Ds that already have a current bundle "
                         "(decision_outputs is append-only, so a re-run "
                         "adds rows rather than replacing them)")
    args = ap.parse_args()

    sim_pool = await get_pool()
    os_pool = await get_os_pool()
    # One runner for every tenant. run() takes the tenant per call, so
    # nothing about the runner is practice-specific.
    runner = PersonaRunner(sim_pool, os_pool, DEFAULT_TENANT)

    tenants = [args.tenant] if args.tenant else await tenants_from_db(sim_pool)

    before = 0
    for t in tenants:
        rows = await execute_os_with_tenant(
            os_pool, t,
            "SELECT (SELECT count(*) FROM decision_outputs) AS d")
        before += rows[0]["d"]

    print(RULE)
    print(f"Running personas for {len(tenants)} tenant(s): {', '.join(tenants)}")
    print(RULE)

    total_ok = total_fail = total_skipped = 0
    errors: list[str] = []
    error_signals: list[str] = []

    for tenant in tenants:
        pred_ids = await pred_ids_for(sim_pool, tenant)
        skip = await already_run(os_pool, tenant) if args.skip_existing else set()
        print(f"\n  {tenant} — {len(pred_ids)} pre-D(s)"
              + (f", {len(skip)} already have a bundle" if skip else ""))
        if not pred_ids:
            print(f"    ! zero pre-Ds visible. If you expected some, RLS "
                  f"returns 0 rows with no error when the tenant is wrong.")
            continue

        decisions: Counter = Counter()
        for pred_id in pred_ids:
            if pred_id in skip:
                total_skipped += 1
                continue
            try:
                result = await runner.run(pred_id, tenant_id=tenant)
                codes = [s["signal_code"] for s in result["all_signals"]]
                for c in codes:
                    if c.endswith("_ERROR"):
                        error_signals.append(f"{pred_id}: {c}")
                decisions[result["context"].decision] += 1
                total_ok += 1
                print(f"    OK  {pred_id[-6:]}  signals={len(codes):>2}  "
                      f"decisions={result['decisions_run']}  "
                      f"{result['context'].decision:<8} "
                      f"bundle={result['bundle_id'][:8]}")
            except Exception as exc:  # noqa: BLE001 — harness reports
                total_fail += 1
                errors.append(f"{pred_id}: {type(exc).__name__}: {exc}")
                print(f"    FAIL {pred_id[-6:]}  {type(exc).__name__}: {exc}")
        if decisions:
            print(f"    -> {dict(decisions)}")

    after = 0
    bundles = 0
    for t in tenants:
        rows = await execute_os_with_tenant(
            os_pool, t,
            "SELECT (SELECT count(*) FROM decision_outputs) AS d,"
            "       (SELECT count(*) FROM persona_bundles WHERE is_current) AS b")
        after += rows[0]["d"]
        bundles += rows[0]["b"]

    print(f"\n{RULE}")
    print(f"  ran {total_ok}, skipped {total_skipped}, failed {total_fail}")
    print(f"  persona exceptions (*_ERROR signals): {len(error_signals)}")
    for e in error_signals:
        print(f"    {e}")
    if errors:
        print("  ERRORS:")
        for e in errors:
            print(f"    {e}")
    print(f"  decision_outputs: {after} (+{after - before} this run)")
    print(f"  persona_bundles (is_current): {bundles}")

    await close_pool()
    return 0 if total_fail == 0 else 1


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
