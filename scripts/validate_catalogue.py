"""
Pre-deploy catalogue gap check. Run before every deploy.

The distinction this script draws is between a gap the system can
DEGRADE through and one that leaves a human stuck:

  WARNING  a missing threshold — rule_loader falls back to a documented
           SAFE_DEFAULT and the decision still gets made (RULE 9).
  ERROR    a condition code with no library entry — the persona can
           raise the signal but has no template text, no citation, no
           SLA and no assignee to attach. The pre-D stops with a code
           nobody can act on. That blocks a human, so it exits 1.

    python scripts/validate_catalogue.py
    echo $?     # 0 = deployable, 1 = blocked
"""
import asyncio
import logging
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from dotenv import load_dotenv

load_dotenv()

from core.catalogue.rule_loader import load_dental_rules  # noqa: E402
from core.db.connection import (  # noqa: E402
    DEFAULT_TENANT,
    close_pool,
    fetch_with_tenant,
    get_pool,
)

TENANT = DEFAULT_TENANT
HOME_STATE = "GA"

errors: list[str] = []
warnings: list[str] = []


class _WarningCatcher(logging.Handler):
    """Counts SAFE_DEFAULT warnings emitted by rule_loader during check 5."""

    def __init__(self) -> None:
        super().__init__(level=logging.WARNING)
        self.records: list[str] = []

    def emit(self, record: logging.LogRecord) -> None:
        msg = record.getMessage()
        if "CATALOGUE MISSING" in msg or "CATALOGUE EMPTY" in msg:
            self.records.append(msg)


async def main() -> int:
    pool = await get_pool()

    async def q(sql: str, *args):
        return await fetch_with_tenant(pool, TENANT, sql, *args)

    print("CATALOGUE VALIDATION REPORT")
    print("=" * 64)

    # ── 1. CDT codes actually billed vs ada_guidelines ────────────────
    # Scoped to codes that appear in procedure_lines. The catalogue holds
    # 181 CDT codes; only the ones a pre-D actually bills matter, and
    # measuring against all 181 would report a 94% gap that means nothing.
    billed = await q(
        """
        SELECT prl.cdt_code, COUNT(*) AS n
        FROM procedure_lines prl
        GROUP BY prl.cdt_code
        ORDER BY COUNT(*) DESC
        """
    )
    billed_codes = [r["cdt_code"] for r in billed]
    with_ada = await q(
        "SELECT cdt_code FROM ada_guidelines WHERE cdt_code = ANY($1::text[])",
        billed_codes,
    )
    ada_have = {r["cdt_code"] for r in with_ada}
    ada_missing = [c for c in billed_codes if c not in ada_have]

    status = "OK" if not ada_missing else f"WARNING: {len(ada_missing)} using SAFE_DEFAULT"
    print(f"  CDT codes billed with ada_guidelines : "
          f"{len(ada_have)}/{len(billed_codes)}  {status}")
    if ada_missing:
        warnings.append(
            f"{len(ada_missing)} billed CDT codes have no ada_guidelines row: "
            f"{', '.join(ada_missing[:12])}"
            f"{' ...' if len(ada_missing) > 12 else ''}"
        )
        top = [r for r in billed if r["cdt_code"] in ada_missing][:6]
        for r in top:
            print(f"      - {r['cdt_code']} ({r['n']} line(s) billed)")

    # ── 2. Condition codes in flight vs conditions_library ────────────
    # This is the ERROR-level check. A code with no library row cannot be
    # rendered into an instruction, so nobody can act on it.
    open_codes = await q(
        """
        SELECT DISTINCT jsonb_array_elements_text(open_conditions) AS code
        FROM pred_states
        WHERE open_conditions IS NOT NULL
          AND jsonb_typeof(open_conditions) = 'array'
        """
    )
    inst_codes = await q(
        "SELECT DISTINCT condition_code AS code FROM pred_condition_instances"
    )
    in_flight = sorted({r["code"] for r in open_codes} | {r["code"] for r in inst_codes})
    lib = await q("SELECT condition_code FROM conditions_library")
    lib_codes = {r["condition_code"] for r in lib}
    cond_missing = [c for c in in_flight if c not in lib_codes]

    print(f"  Condition codes with library entry   : "
          f"{len(in_flight) - len(cond_missing)}/{len(in_flight)}  "
          f"{'OK' if not cond_missing else f'ERROR: {len(cond_missing)} missing'}")
    for c in cond_missing:
        errors.append(f"condition code {c!r} is in flight but not in conditions_library")
        print(f"      - {c}  (no template text, citation, SLA or assignee)")

    # ── 3. Payers with a home-state fee schedule ──────────────────────
    payers = await q("SELECT payer_id FROM payers ORDER BY payer_id")
    fees = await q(
        "SELECT payer_id, COUNT(*) AS n FROM fee_schedules "
        "WHERE state = $1 GROUP BY payer_id",
        HOME_STATE,
    )
    fee_by_payer = {r["payer_id"]: r["n"] for r in fees}
    no_fees = [r["payer_id"] for r in payers if not fee_by_payer.get(r["payer_id"])]
    print(f"  Payers with {HOME_STATE} fee schedules          : "
          f"{len(payers) - len(no_fees)}/{len(payers)}  "
          f"{'OK' if not no_fees else 'ERROR'}")
    for p in no_fees:
        errors.append(f"payer {p!r} has no fee_schedules rows for state={HOME_STATE}")

    # ── 4. catalogue_versions ─────────────────────────────────────────
    try:
        versions = await q(
            "SELECT catalogue_name, version, row_count, states "
            "FROM catalogue_versions ORDER BY catalogue_name"
        )
    except Exception as exc:  # noqa: BLE001
        versions = []
        errors.append(f"catalogue_versions unreadable: {type(exc).__name__}: {exc}")

    print(f"  catalogue_versions entries           : "
          f"{len(versions)}/8  {'OK' if len(versions) >= 8 else 'WARNING'}")
    if len(versions) < 8:
        warnings.append(
            f"catalogue_versions has {len(versions)} entries; 8 expected. "
            f"Decisions will carry incomplete provenance."
        )

    # Version rows that disagree with reality are worse than none —
    # they read as provenance while being wrong.
    drifted = []
    for v in versions:
        try:
            live = (await q(f"SELECT COUNT(*) AS n FROM {v['catalogue_name']}"))[0]["n"]
        except Exception:  # noqa: BLE001
            continue
        if live != v["row_count"]:
            drifted.append(f"{v['catalogue_name']}: table has {live}, "
                           f"catalogue_versions says {v['row_count']}")
    if drifted:
        for d in drifted:
            warnings.append(f"catalogue_versions row_count drift — {d}")
        print(f"      row_count drift on {len(drifted)} catalogue(s)")

    # ── 5. rule_loader on the 10 most-billed codes ────────────────────
    catcher = _WarningCatcher()
    rl_logger = logging.getLogger("core.catalogue.rule_loader")
    rl_logger.addHandler(catcher)
    prior_level = rl_logger.level
    rl_logger.setLevel(logging.WARNING)
    try:
        async with pool.acquire() as conn:
            rules = await load_dental_rules(
                conn, tenant_id=TENANT, payer_id="delta_dental", state=HOME_STATE
            )
        top10 = billed_codes[:10]
        for code in top10:
            # Touch each section a persona would read for this code.
            rules["ada_thresholds"].get(code)
            rules["cdt_rules"].get(code)
            rules["coverage_rules"].get(code)
            rules["fee_schedules"].get(code)
    finally:
        rl_logger.removeHandler(catcher)
        rl_logger.setLevel(prior_level)

    print(f"  rule_loader SAFE_DEFAULT warnings    : "
          f"{len(catcher.records)}  {'OK' if not catcher.records else 'WARNING'}")
    for msg in catcher.records[:5]:
        warnings.append(f"rule_loader: {msg}")

    # ── Extra: coverage of the top 10 billed codes ────────────────────
    print(f"\n  Top {len(billed_codes[:10])} billed CDT codes:")
    print(f"    {'code':7} {'lines':>5}  {'ada':>4} {'cdt':>4} {'cover':>6} {'fee':>9}")
    for r in billed[:10]:
        c = r["cdt_code"]
        fee = rules["fee_schedules"].get(c, {}).get("allowed_amount")
        print(
            f"    {c:7} {r['n']:>5}  "
            f"{'yes' if c in rules['ada_thresholds'] else 'NO ':>4} "
            f"{'yes' if c in rules['cdt_rules'] else 'NO ':>4} "
            f"{'yes' if c in rules['coverage_rules'] else 'NO ':>6} "
            f"{('$' + str(fee)) if fee else 'NO':>9}"
        )

    # ── Extra: fee schedule provenance ────────────────────────────────
    prov = await q(
        "SELECT state, COUNT(*) AS n, "
        "       COUNT(*) FILTER (WHERE source LIKE '%_medicaid_spa_%') AS sourced "
        "FROM fee_schedules GROUP BY state ORDER BY state"
    )
    est_states = [r["state"] for r in prov if r["sourced"] == 0]
    print(f"\n  Fee schedules: {len(prov)} states, "
          f"{sum(r['n'] for r in prov)} rows")
    if est_states:
        warnings.append(
            f"fee schedules for {', '.join(est_states)} contain no rows traced "
            f"to a published schedule — they are estimated from GA. Never "
            f"quote them to a patient or payer as that state's rate."
        )
        print(f"      estimated-only states: {', '.join(est_states)}")

    # ── Extra: conditions_library completeness ────────────────────────
    incomplete = await q(
        "SELECT COUNT(*) FILTER (WHERE recommended_action IS NULL) AS no_action, "
        "       COUNT(*) FILTER (WHERE payer_citation !~ '[0-9]') AS no_section, "
        "       COUNT(*) AS total FROM conditions_library"
    )
    ic = incomplete[0]
    print(f"  conditions_library: {ic['total']} rows, "
          f"{ic['no_action']} with no recommended_action, "
          f"{ic['no_section']} with no citation section")
    if ic["no_action"]:
        warnings.append(
            f"{ic['no_action']}/{ic['total']} conditions_library rows have NULL "
            f"recommended_action — the condition can say what is wrong but not "
            f"what to do about it"
        )
    if ic["no_section"]:
        warnings.append(
            f"{ic['no_section']}/{ic['total']} conditions_library rows have a "
            f"payer_citation with no section number — no_citation_without_source "
            f"is satisfied in form, not in substance"
        )

    await close_pool()

    # ── Verdict ───────────────────────────────────────────────────────
    print("\n" + "=" * 64)
    if warnings:
        print(f"WARNINGS ({len(warnings)}) — acceptable, SAFE_DEFAULTS in use:")
        for w in warnings:
            print(f"  ! {w}")
    if errors:
        print(f"\nERRORS ({len(errors)}) — these block human action:")
        for e in errors:
            print(f"  x {e}")
        print("\nRESULT: FAIL")
        return 1

    print(f"\nRESULT: PASS ({len(warnings)} warning(s) — "
          f"SAFE_DEFAULTS in use, no blocking gaps)")
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
