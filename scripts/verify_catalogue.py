"""
Loads catalogue rules for DA-A01 (delta_dental / suwanee_smiles) and
asserts the rules the personas will actually gate on are present and
correct.

    python scripts/verify_catalogue.py
"""
import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from dotenv import load_dotenv

load_dotenv()

from core.catalogue.rule_loader import load_dental_rules  # noqa: E402
from core.db.connection import DEFAULT_TENANT, close_pool, get_pool  # noqa: E402

TENANT = DEFAULT_TENANT
PAYER = "delta_dental"

failures: list[str] = []
passes = 0


def expect(label: str, actual, expected) -> None:
    global passes
    if actual == expected:
        passes += 1
        print(f"  + {label:52} {actual!r}")
    else:
        failures.append(f"{label}: got {actual!r}, expected {expected!r}")
        print(f"  x {label:52} {actual!r}  (expected {expected!r})")


def expect_true(label: str, condition: bool, detail: str = "") -> None:
    global passes
    if condition:
        passes += 1
        print(f"  + {label:52} {detail}")
    else:
        failures.append(f"{label}: {detail}")
        print(f"  x {label:52} {detail}")


async def main() -> int:
    pool = await get_pool()
    async with pool.acquire() as conn:
        rules = await load_dental_rules(conn, tenant_id=TENANT, payer_id=PAYER)

    # ── Section counts ────────────────────────────────────────────────
    print(f"Catalogue loaded — tenant={TENANT} payer={PAYER}\n")
    print(f"  ada_thresholds        {len(rules['ada_thresholds']):>4} CDT codes with guidelines")
    print(f"  bundling_rules        {len(rules['bundling_rules']):>4} bundling pairs (incl. reverse-direction keys)")
    print(f"  frequency_limits      {len(rules['frequency_limits']):>4} frequency rules (all payers)")
    print(f"  downgrade_matrix      {len(rules['downgrade_matrix']):>4} downgrade entries (all payers)")
    print(f"  cdt_rules             {len(rules['cdt_rules']):>4} CDT code rules")
    print(f"  coverage_rules        {len(rules['coverage_rules']):>4} payer coverage rules")
    print(f"  conditions_library    {len(rules['conditions_library']):>4} conditions")
    print(f"  medical_history_flags {len(rules['medical_history_flags']):>4} flags")
    print(f"  overlay_rules              tenant={rules['overlay_rules']['tenant_id']}, "
          f"{len(rules['overlay_rules']['rules'])} active override(s)")

    ada = rules["ada_thresholds"]
    bundling = rules["bundling_rules"]
    freq = rules["frequency_limits"]
    down = rules["downgrade_matrix"]
    cdt = rules["cdt_rules"]
    cond = rules["conditions_library"]
    flags = rules["medical_history_flags"]

    print("\nADA thresholds (layer 1 — clinical floor)")
    expect("D6010 bone_loss_mm_min", ada["D6010"]["bone_loss_mm_min"], 3.0)
    expect("D6010 auto_approve_score", ada["D6010"]["auto_approve_score"], 0.85)
    expect("D6010 auto_deny_score", ada["D6010"]["auto_deny_score"], 0.30)
    expect("D6010 age_min", ada["D6010"]["age_min"], 18.0)
    expect("D7953 bone_loss_mm_min", ada["D7953"]["bone_loss_mm_min"], 3.0)
    expect("D4260 pocket_depth_mm_min", ada["D4260"]["pocket_depth_mm_min"], 5.0)
    expect("D4260 sites_min", ada["D4260"]["sites_min"], 6.0)
    expect("D4260 bone_loss_pct_min", ada["D4260"]["bone_loss_pct_min"], 25.0)

    print("\nBundling (the D7953 + D6010 conflict this product exists for)")
    expect_true("('D7953','D6010') present", ("D7953", "D6010") in bundling)
    b = bundling[("D7953", "D6010")]
    expect("D7953+D6010 separable", b["separable"], True)
    expect("D7953+D6010 policy_section", b["policy_section"], "D.7.4")
    expect("D7953+D6010 bundling_type", b["bundling_type"], "soft")
    expect_true(
        "reverse key ('D6010','D7953') also resolves",
        ("D6010", "D7953") in bundling,
        "bundling is symmetric — billed order must not change the answer",
    )
    hard = bundling.get(("D2950", "D2750"))
    expect_true("('D2950','D2750') hard bundle present", hard is not None)
    if hard:
        expect("D2950+D2750 separable", hard["separable"], False)
        expect("D2950+D2750 bundling_type", hard["bundling_type"], "hard")
        expect_true(
            "D2950+D2750 applies to ALL payers",
            hard["applies_to_all_payers"] is True,
            "payer_id IS NULL — an ADA coding standard, not a Delta rule",
        )

    print("\nFrequency limits (payer divergence is the point)")
    expect("Delta D0330 frequency_period", freq[("delta_dental", "D0330")]["frequency_period"], "per_5_years")
    expect("MetLife D0330 frequency_period", freq[("metlife", "D0330")]["frequency_period"], "per_3_years")
    expect("Cigna D0330 frequency_period", freq[("cigna", "D0330")]["frequency_period"], "per_5_years")
    expect("Delta D2750 frequency_period", freq[("delta_dental", "D2750")]["frequency_period"], "per_5_years")
    expect("Cigna D2750 frequency_period", freq[("cigna", "D2750")]["frequency_period"], "per_4_years")
    expect("Delta D2750 frequency_scope", freq[("delta_dental", "D2750")]["frequency_scope"], "per_tooth")

    print("\nDowngrade matrix (absence is meaningful)")
    expect_true(
        "Delta DOES downgrade D2740",
        down.get(("delta_dental", "D2740")) is not None,
        f"-> {(down.get(('delta_dental','D2740')) or {}).get('paid_cdt_code')}",
    )
    expect("Delta D2740 paid_cdt_code", down[("delta_dental", "D2740")]["paid_cdt_code"], "D2750")
    expect("Delta D2740 policy_section", down[("delta_dental", "D2740")]["policy_section"], "D.4.2")
    expect_true(
        "Cigna does NOT downgrade D2740",
        down.get(("cigna", "D2740")) is None,
        "no key -> no downgrade (DA-C06 depends on this)",
    )
    expect_true(
        "Cigna DOES downgrade D6065",
        down.get(("cigna", "D6065")) is not None,
        "absence is per-code, not per-payer",
    )

    print("\nCDT documentation requirements")
    expect("D6010 requires_xray", cdt["D6010"]["requires_xray"], True)
    expect("D6010 age_limit_min", cdt["D6010"]["age_limit_min"], 18)
    expect("D6010 requires_narrative", cdt["D6010"]["requires_narrative"], True)
    expect("D7953 requires_narrative", cdt["D7953"]["requires_narrative"], True)
    expect("D4341 requires_perio_chart", cdt["D4341"]["requires_perio_chart"], True)
    expect("D4260 requires_perio_chart", cdt["D4260"]["requires_perio_chart"], True)

    print("\nConditions library")
    expect_true("COVERAGE_BUNDLING_CONFLICT present", "COVERAGE_BUNDLING_CONFLICT" in cond)
    cbc = cond["COVERAGE_BUNDLING_CONFLICT"]
    expect("COVERAGE_BUNDLING_CONFLICT category", cbc["category"], "coverage")
    expect_true(
        "COVERAGE_BUNDLING_CONFLICT template names the section",
        "${section}" in (cbc["template_text"] or ""),
        "section is a ${section} placeholder filled at render time",
    )

    print("\nMedical history flags")
    expect_true("BISPHOS_IV present", "BISPHOS_IV" in flags)
    expect("BISPHOS_IV risk_level", flags["BISPHOS_IV"]["risk_level"], "absolute_contraindication")
    expect_true(
        "BISPHOS_IV contraindicates D6010",
        "D6010" in flags["BISPHOS_IV"]["contraindicated_cdts"],
        f"{len(flags['BISPHOS_IV']['contraindicated_cdts'])} contraindicated codes",
    )
    expect_true(
        "BISPHOS_IV contraindicates D7953",
        "D7953" in flags["BISPHOS_IV"]["contraindicated_cdts"],
    )

    print("\nTenant overlay (layer 3 — always wins)")
    ov = rules["overlay_rules"]["rules"]
    expect("overlay tenant_id", rules["overlay_rules"]["tenant_id"], "suwanee_smiles")
    for cdt_code, entry in sorted(ov.items()):
        print(f"      {cdt_code}: {entry['overrides']}")
    expect_true(
        "D6065 overlay applied on top of coverage_rules",
        cdt.get("D6065", {}).get("governed_by") == "tenant_overlay"
        or rules["coverage_rules"].get((PAYER, "D6065"), {}).get("governed_by") == "tenant_overlay",
        "clinical_criteria_required forced true by practice policy",
    )

    # ── Catalogue gaps worth reporting, not asserting ─────────────────
    print("\nCatalogue gaps (reported, not fatal)")
    no_action = [k for k, v in cond.items() if not v.get("recommended_action")]
    print(f"      conditions_library rows with NULL recommended_action: "
          f"{len(no_action)}/{len(cond)}")
    generic = [k for k, v in cond.items()
               if v.get("payer_citation") and not any(ch.isdigit() for ch in v["payer_citation"])]
    print(f"      conditions_library rows whose payer_citation has no section "
          f"number: {len(generic)}/{len(cond)}")
    ada_missing = [c for c in ("D6010", "D7953", "D6065", "D4260", "D4341")
                   if c not in ada]
    print(f"      key CDT codes with no ADA guideline row: {ada_missing or 'none'}")
    cov_missing = [c for c in ("D6010", "D7953", "D6065")
                   if (PAYER, c) not in rules["coverage_rules"]]
    print(f"      key CDT codes with no Delta coverage rule: {cov_missing or 'none'}")

    await close_pool()

    print()
    if not failures:
        print(f"+ ALL {passes} CATALOGUE ASSERTIONS PASSED")
        return 0
    print(f"x {len(failures)} of {passes + len(failures)} assertions failed:")
    for f in failures:
        print(f"  {f}")
    return 1


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
