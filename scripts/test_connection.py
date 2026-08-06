"""
Tests the read-only connection to dental-simulator RDS.

Verifies all key tables are accessible with the expected row counts, and
demonstrates the RLS trap: the same query without tenant context returns
0 rows and no error.

    python scripts/test_connection.py
"""
import asyncio
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import asyncpg
from dotenv import load_dotenv

load_dotenv()

from core.db.connection import (  # noqa: E402
    DEFAULT_TENANT,
    close_pool,
    fetch_with_tenant,
    get_pool,
)

TENANT = DEFAULT_TENANT

# Counts verified against the live RDS 2026-08-05. The check is >=, so a
# reload that adds rows still passes; a load that dropped rows fails.
TABLES = [
    ("pred_states", 35),
    ("pred_requests", 35),
    ("eligibility_profiles", 35),
    ("clinical_evidence", 183),
    ("procedure_lines", 67),
    ("cost_estimates", 67),
    ("payer_responses", 35),
    ("pred_audit_log", 277),
    ("evidence_nodes", 108),
    ("evidence_edges", 24),
    ("pred_condition_instances", 85),
    ("patients", 35),
    ("providers", 3),
    ("plans", 3),
    ("payers", 3),
    ("cdt_codes", 181),
    ("ada_guidelines", 10),
    ("bundling_rules", 20),
    ("frequency_limits", 27),
    ("downgrade_matrix", 9),
    ("conditions_library", 50),
    ("coverage_rules", 543),      # 181 codes x 3 payers (T-10g)
    ("fee_schedules", 588),       # 28 codes x 3 payers x 7 states
    ("catalogue_versions", 9),
]


async def main() -> int:
    print("Testing dental-os -> dental-simulator RDS connection...")
    dsn = os.environ.get("DATABASE_URL", "NOT SET")
    # Never print the password, even to a local terminal.
    safe = dsn
    if "@" in dsn and "//" in dsn:
        scheme, rest = dsn.split("//", 1)
        safe = f"{scheme}//***@{rest.split('@', 1)[1]}"
    print(f"URL: {safe[:90]}")
    print()

    pool = await get_pool()

    # ── The RLS trap ──────────────────────────────────────────────────
    async with pool.acquire() as conn:
        n = await conn.fetchval("SELECT COUNT(*) FROM pred_states")
    trap_ok = n == 0
    print(f"WITHOUT tenant context: pred_states = {n} (expect 0 - RLS)")
    if not trap_ok:
        print("  !! RLS IS NOT ENFORCING. A connection with no tenant context")
        print("     can see rows. Check that the DSN uses dental_app and not")
        print("     an owner/superuser role before trusting tenant isolation.")

    # ── With tenant context ───────────────────────────────────────────
    print(f"\nWITH tenant context ('{TENANT}'):")
    errors: list[str] = []
    for table, expected in TABLES:
        try:
            rows = await fetch_with_tenant(
                pool, TENANT, f"SELECT COUNT(*) AS n FROM {table}"
            )
            actual = rows[0]["n"]
        except Exception as exc:  # noqa: BLE001 - report, don't abort the sweep
            errors.append(f"{table}: {type(exc).__name__}: {exc}")
            print(f"  x {table:28} {'ERROR':>7}")
            continue
        ok = actual >= expected
        if not ok:
            errors.append(f"{table}: got {actual}, expected >={expected}")
        print(f"  {'+' if ok else 'x'} {table:28} {actual:>7}  (expect >={expected})")

    # ── Full join ─────────────────────────────────────────────────────
    rows = await fetch_with_tenant(
        pool,
        TENANT,
        """
        SELECT pr.pred_request_id,
               p.first_name || ' ' || p.last_name AS patient,
               ps.decision,
               ps.criteria_score
        FROM pred_requests pr
        JOIN patients    p  ON p.patient_id = pr.patient_id
        JOIN pred_states ps ON ps.pred_request_id = pr.pred_request_id
        ORDER BY pr.pred_request_id
        LIMIT 5
        """,
    )
    total = await fetch_with_tenant(
        pool, TENANT, "SELECT COUNT(*) AS n FROM pred_requests"
    )
    print(f"\nFull join (5 of {total[0]['n']}):")
    for r in rows:
        print(
            f"  {r['pred_request_id'][-6:]} | {r['patient']:20} | "
            f"{r['decision']:8} | score={r['criteria_score']}"
        )
    if not rows:
        errors.append("full join returned 0 rows")

    # ── Read-only guard ───────────────────────────────────────────────
    # RULE 15: dental-os must not be able to write to a simulator table.
    try:
        await fetch_with_tenant(
            pool,
            TENANT,
            "INSERT INTO pred_audit_log (tenant_id, pred_request_id, event_type) "
            "VALUES ('x', 'x', 'x') RETURNING audit_id",
        )
        errors.append("READ-ONLY GUARD FAILED - an INSERT was accepted")
        print("\nRead-only guard: x FAILED - INSERT was accepted")
    except asyncpg.PostgresError as exc:
        print(f"\nRead-only guard: + INSERT refused ({type(exc).__name__})")

    await close_pool()

    print()
    if not errors:
        print("+ ALL CHECKS PASSED - dental-os -> dental-simulator connected")
        return 0
    print(f"x {len(errors)} error(s):")
    for e in errors:
        print(f"  {e}")
    return 1


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
