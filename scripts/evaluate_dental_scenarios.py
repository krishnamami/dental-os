"""
T-32 — run every scenario through PersonaRunner and check the signals.

The dental-os equivalent of decision-os's evaluate_lending_scenarios.py.
Reads the pre-D list from dental-simulator, runs all five waves against
each, and asserts the expected signals for the scenarios that have a
documented expectation.

    DATABASE_URL=...            (dental, read-only)
    DENTAL_OS_DATABASE_URL=...  (dental_os, read-write)
    python scripts/evaluate_dental_scenarios.py

A persona never raises — DentalPersona.run() converts an exception into
a *_ERROR signal so one bad persona cannot take down its wave. That
makes silence the wrong success criterion, so this script scans the
returned signals for *_ERROR codes and reports them separately from
transport-level exceptions.
"""
from __future__ import annotations

import asyncio
import sys
from collections import Counter

sys.path.insert(0, str(__import__("pathlib").Path(__file__).resolve().parents[1]))

from core.cron.runner import PersonaRunner  # noqa: E402
from core.db.connection import (  # noqa: E402
    DEFAULT_TENANT,
    close_pool,
    execute_os_with_tenant,
    fetch_with_tenant,
    get_os_pool,
    get_pool,
)

EXPECTED: dict[str, dict] = {
    "PRED-SIM-DA-A01": {
        "decision": "pended",
        "must_have": ["COVERAGE_BUNDLING_CONFLICT",
                      "DOC_NARRATIVE_MISSING",
                      "CLINICAL_CRITERIA_MET"],
        "must_not_have": ["FRAUD_UPCODING",
                          "PROVIDER_OIG_EXCLUDED"],
    },
    "PRED-SIM-DA-B01": {
        "decision": "denied",
        "must_have": ["ELIG_IMPLANTS_NOT_COVERED"],
        "must_not_have": ["ELIGIBILITY_VERIFIED"],
    },
    "PRED-SIM-DA-B05": {
        "decision": "denied",
        "must_have": ["ELIG_WAITING_PERIOD_NOT_MET"],
    },
    "PRED-SIM-DA-C06": {
        "decision": "approved",
        "must_have": ["ELIGIBILITY_VERIFIED", "COVERAGE_VERIFIED"],
        "must_not_have": ["COVERAGE_DOWNGRADE_APPLIED"],
    },
    "PRED-SIM-DA-C09": {
        "decision": "pended",
        "must_have": ["CLINICAL_MEDICAL_HISTORY_FLAG"],
    },
    "PRED-SIM-DA-C10": {
        "decision": "pended",
        "must_have": ["PROVIDER_OIG_EXCLUDED"],
    },
    "PRED-SIM-DA-F01": {
        "decision": "pended",
        "must_have": ["FRAUD_UPCODING"],
    },
    "PRED-SIM-DA-F02": {
        "decision": "denied",
        "must_have": ["FRAUD_PHANTOM_PROCEDURE"],
    },
    "PRED-SIM-DA-U01": {
        "decision": "approved",
        "must_have": ["ELIGIBILITY_VERIFIED", "DOCUMENTATION_COMPLETE"],
        "must_not_have": ["COVERAGE_BUNDLING_CONFLICT"],
    },
}

# Printed in full at the end — the scenarios the PRD talks about.
DETAIL = ("PRED-SIM-DA-A01", "PRED-SIM-DA-U01",
          "PRED-SIM-DA-C10", "PRED-SIM-DA-F01")


async def main() -> int:
    sim_pool = await get_pool()
    os_pool = await get_os_pool()
    runner = PersonaRunner(sim_pool, os_pool, DEFAULT_TENANT)

    before = await execute_os_with_tenant(
        os_pool, DEFAULT_TENANT,
        "SELECT (SELECT count(*) FROM decision_outputs) AS d,"
        "       (SELECT count(*) FROM persona_bundles)  AS p",
    )
    rows_before = before[0]

    rows = await fetch_with_tenant(
        sim_pool, DEFAULT_TENANT,
        "SELECT pred_request_id FROM pred_requests ORDER BY pred_request_id",
    )
    pred_ids = [r["pred_request_id"] for r in rows]

    print(f"Running {len(pred_ids)} scenarios...\n")

    passed = failed = 0
    errors: list[str] = []
    error_signals: list[str] = []
    results: dict[str, dict] = {}
    decision_counts: Counter = Counter()

    for pred_id in pred_ids:
        try:
            result = await runner.run(pred_id)
            results[pred_id] = result
            signals = [s["signal_code"] for s in result["all_signals"]]
            decision_counts[result["context"].decision] += 1

            # A persona that raised is reported, not swallowed — run()
            # turned it into a signal rather than an exception.
            for code in signals:
                if code.endswith("_ERROR"):
                    error_signals.append(f"{pred_id}: {code}")

            expected = EXPECTED.get(pred_id)
            if expected:
                ok = True
                actual_decision = result["context"].decision
                if expected.get("decision") not in (None, actual_decision):
                    ok = False
                    errors.append(
                        f"{pred_id}: decision is {actual_decision!r}, "
                        f"expected {expected['decision']!r}"
                    )
                for must in expected.get("must_have", []):
                    if must not in signals:
                        ok = False
                        errors.append(f"{pred_id}: missing {must}")
                for must_not in expected.get("must_not_have", []):
                    if must_not in signals:
                        ok = False
                        errors.append(f"{pred_id}: unexpected {must_not}")
                if ok:
                    passed += 1
                    print(f"  OK   {pred_id[-6:]}  signals={len(signals):>2}  "
                          f"decisions={result['decisions_run']}  "
                          f"bundle={result['bundle_id'][:8]}  [checked]")
                else:
                    failed += 1
                    print(f"  FAIL {pred_id[-6:]}  signals={len(signals):>2}  "
                          f"FAILED")
            else:
                passed += 1
                print(f"  OK   {pred_id[-6:]}  signals={len(signals):>2}  "
                      f"decisions={result['decisions_run']}  "
                      f"bundle={result['bundle_id'][:8]}")

        except Exception as exc:  # noqa: BLE001 — the harness reports, not raises
            failed += 1
            errors.append(f"{pred_id}: ERROR {type(exc).__name__}: {exc}")
            print(f"  FAIL {pred_id[-6:]}  ERROR: {type(exc).__name__}: {exc}")

    print()
    print(f"PASSED: {passed}/{len(pred_ids)}")
    print(f"FAILED: {failed}/{len(pred_ids)}")
    print(f"checked against EXPECTED: "
          f"{len([p for p in pred_ids if p in EXPECTED])}")
    print(f"payer decisions: {dict(decision_counts)}")

    if errors:
        print("\nERRORS:")
        for e in errors:
            print(f"  {e}")

    print(f"\npersona exceptions (*_ERROR signals): {len(error_signals)}")
    for e in error_signals:
        print(f"  {e}")

    # ── Per-scenario detail ──────────────────────────────────────────
    for pred_id in DETAIL:
        result = results.get(pred_id)
        if not result:
            continue
        print(f"\n{'-' * 62}\n{pred_id}  "
              f"decision={result['context'].decision}  "
              f"submission_ready={result['submission_ready']}")
        for decision_id, out in result["wave_outputs"].items():
            codes = [s["signal_code"] for s in out["signals"]]
            print(f"  W{out['wave']} {decision_id:<24} {out['outcome']:<9} "
                  f"{', '.join(codes)}")

    # ── dental-os DB ─────────────────────────────────────────────────
    after = await execute_os_with_tenant(
        os_pool, DEFAULT_TENANT,
        "SELECT (SELECT count(*) FROM decision_outputs) AS d,"
        "       (SELECT count(*) FROM persona_bundles)  AS p,"
        "       (SELECT count(*) FROM persona_bundles WHERE is_current) AS c",
    )
    a = after[0]
    print(f"\n{'-' * 62}\ndental-os DB:")
    print(f"  decision_outputs: {a['d']} rows "
          f"(+{a['d'] - rows_before['d']} this run)")
    print(f"  persona_bundles:  {a['p']} rows "
          f"(+{a['p'] - rows_before['p']} this run, {a['c']} current)")

    per_wave = await execute_os_with_tenant(
        os_pool, DEFAULT_TENANT,
        "SELECT wave, count(*) n FROM decision_outputs GROUP BY wave ORDER BY wave",
    )
    print("  by wave: " + ", ".join(f"W{r['wave']}={r['n']}" for r in per_wave))

    await close_pool()
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
