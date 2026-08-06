"""
Verifies the 8 context views created by migrations/001_context_views.sql.

Checks three things:
  1. Every view exists and returns rows under tenant context.
  2. Every view returns ZERO rows WITHOUT tenant context — proving
     security_invoker is on and RLS is evaluated as the caller, not as
     the view owner. A view that returns rows here is a cross-tenant
     leak, not a passing test.
  3. DA-A01 spot check: bone_loss_mm from vw_clinical_context is 4.2.

    python scripts/verify_views.py
"""
import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from dotenv import load_dotenv

load_dotenv()

from core.db.connection import (  # noqa: E402
    DEFAULT_TENANT,
    close_pool,
    fetch_with_tenant,
    get_pool,
)

TENANT = DEFAULT_TENANT
PRED = "PRED-SIM-DA-A01"

# view -> (expected minimum rows, grain)
VIEWS = [
    ("vw_eligibility_context", 35, "one row per pre-D"),
    ("vw_coverage_context", 67, "one row per procedure line"),
    ("vw_clinical_context", 183, "one row per evidence document"),
    ("vw_documentation_context", 183, "one row per evidence document"),
    ("vw_provider_context", 35, "one row per pre-D"),
    ("vw_fraud_context", 67, "one row per procedure line"),
    ("vw_appeal_context", 35, "one row per pre-D"),
    ("vw_portfolio_context", 1, "one row per tenant (aggregate)"),
]


async def main() -> int:
    pool = await get_pool()
    errors: list[str] = []

    print("Verifying dental-os context views\n")
    print(f"{'view':30} {'rows':>6}  {'no-tenant':>9}  grain")
    print("-" * 78)

    for view, expected, grain in VIEWS:
        try:
            rows = await fetch_with_tenant(
                pool, TENANT, f"SELECT COUNT(*) AS n FROM {view}"
            )
            n = rows[0]["n"]
        except Exception as exc:  # noqa: BLE001
            errors.append(f"{view}: {type(exc).__name__}: {exc}")
            print(f"{view:30} {'ERROR':>6}")
            continue

        # Same view, no tenant context. MUST be 0.
        async with pool.acquire() as conn:
            leaked = await conn.fetchval(f"SELECT COUNT(*) FROM {view}")

        ok = n >= expected
        if not ok:
            errors.append(f"{view}: got {n} rows, expected >={expected}")
        if leaked != 0:
            errors.append(
                f"{view}: TENANT LEAK - {leaked} rows visible with no tenant "
                f"context. security_invoker is off or RLS is not applying."
            )

        mark = "+" if ok else "x"
        leak_mark = "+ 0" if leaked == 0 else f"x {leaked}"
        print(f"{mark} {view:28} {n:>6}  {leak_mark:>9}  {grain}")

    # ── DA-A01 spot check ─────────────────────────────────────────────
    print(f"\nSpot check - {PRED} through vw_clinical_context:")
    rows = await fetch_with_tenant(
        pool,
        TENANT,
        """
        SELECT document_type, bone_loss_mm, bone_loss_pct, image_quality,
               confidence_score, extraction_method, criteria_score
        FROM vw_clinical_context
        WHERE pred_request_id = $1
        ORDER BY document_type
        """,
        PRED,
    )
    for r in rows:
        bl = "-" if r["bone_loss_mm"] is None else str(r["bone_loss_mm"])
        print(
            f"  {r['document_type']:20} bone_loss_mm={bl:>5}  "
            f"conf={r['confidence_score']}  {r['extraction_method']}"
        )

    xray = [r for r in rows if r["document_type"] == "XRAY_PA"]
    if not xray:
        errors.append(f"{PRED}: no XRAY_PA row in vw_clinical_context")
    else:
        actual = float(xray[0]["bone_loss_mm"])
        if abs(actual - 4.2) < 1e-9:
            print(f"\n  + bone_loss_mm = {actual} (expected 4.2)")
        else:
            errors.append(f"{PRED}: bone_loss_mm = {actual}, expected 4.2")
            print(f"\n  x bone_loss_mm = {actual}, expected 4.2")

    # ── Portfolio aggregate ───────────────────────────────────────────
    port = await fetch_with_tenant(
        pool,
        TENANT,
        """
        SELECT total_pred_requests, approved_count, denied_count, pended_count,
               avg_criteria_score, first_pass_approval_rate, total_billed,
               total_insurance_pays, total_patient_pays, revenue_at_risk
        FROM vw_portfolio_context
        """,
    )
    if port:
        p = port[0]
        print("\nPortfolio aggregate:")
        print(
            f"  {p['total_pred_requests']} pre-Ds  |  "
            f"approved={p['approved_count']} denied={p['denied_count']} "
            f"pended={p['pended_count']}"
        )
        print(
            f"  avg_criteria_score={p['avg_criteria_score']}  "
            f"first_pass_approval_rate={p['first_pass_approval_rate']}"
        )
        print(
            f"  billed=${p['total_billed']}  insurance=${p['total_insurance_pays']}  "
            f"patient=${p['total_patient_pays']}  at_risk=${p['revenue_at_risk']}"
        )

    await close_pool()

    print()
    if not errors:
        print("+ ALL 8 VIEWS VERIFIED - rows present, no tenant leak, DA-A01 correct")
        return 0
    print(f"x {len(errors)} error(s):")
    for e in errors:
        print(f"  {e}")
    return 1


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
