"""
Sprint 2 integration test — three practices through one API.

    uvicorn api.main:app --port 9010        # terminal 1
    python scripts/test_multi_tenant.py     # terminal 2

The regression this guards is subtle and silent. Every route used to
assume suwanee_smiles; RLS returns ZERO ROWS AND NO ERROR under the
wrong tenant, so a Tampa pre-D came back as a 404 for a row that plainly
exists. Nothing raised. The only way to catch it is to ask for a pre-D
from each practice and check the answer is that practice's.
"""
from __future__ import annotations

import asyncio

import httpx

BASE = "http://localhost:9010"


async def main() -> int:
    async with httpx.AsyncClient(timeout=120) as client:
        try:
            await client.get(f"{BASE}/health")
        except httpx.ConnectError:
            print(f"Nothing listening on {BASE}.\n"
                  f"Start it:  uvicorn api.main:app --port 9010")
            return 1

        # ── Health shows the multi-tenant shape ──────────────────────
        r = await client.get(f"{BASE}/health")
        assert r.status_code == 200, r.text
        h = r.json()
        assert h["status"] == "healthy", h
        assert h["version"] == "0.3.0", h
        assert h["tenants"] == 3, h
        assert h["simulator_scenarios"] == 50, h
        assert h["payers_supported"] == 6, h
        assert h["states_supported"] == 7, h
        # 50 current bundles, one per pre-D across all three practices.
        assert h["persona_bundles"] >= 50, h
        print(f"OK  /health  tenants={h['tenants']} "
              f"scenarios={h['simulator_scenarios']} "
              f"payers={h['payers_supported']} "
              f"states={h['states_supported']} "
              f"outputs={h['decision_outputs']} "
              f"bundles={h['persona_bundles']}")

        # ── suwanee_smiles unchanged ─────────────────────────────────
        r = await client.get(f"{BASE}/decisions/PRED-SIM-DA-A01")
        assert r.status_code == 200, r.text
        d = r.json()
        assert d["patient_name"] == "James Mitchell", d["patient_name"]
        assert d["decision"] == "pended", d["decision"]
        assert d["payer_id"] == "delta_dental", d["payer_id"]
        assert d["state"] == "GA", d["state"]
        print(f"OK  DA-A01 suwanee_smiles  {d['patient_name']} "
              f"{d['decision']} {d['payer_id']}/{d['state']} "
              f"signals={len(d['all_signals'])}")

        # ── tampa_smiles — Aetna DMO implant exclusion ───────────────
        r = await client.get(f"{BASE}/decisions/PRED-SIM-TB-B01")
        assert r.status_code == 200, r.text
        d = r.json()
        assert d["decision"] == "denied", d
        assert d["payer_id"] == "aetna_dmo", d["payer_id"]
        assert d["state"] == "FL", d["state"]
        codes = [s["signal_code"] for s in d["all_signals"]]
        assert "ELIG_IMPLANTS_NOT_COVERED" in codes, codes
        print(f"OK  TB-B01 tampa_smiles  denied  {d['payer_id']}/{d['state']}  "
              f"ELIG_IMPLANTS_NOT_COVERED")

        # ── tampa_smiles — Aetna does NOT downgrade the ceramic crown ─
        r = await client.get(f"{BASE}/decisions/PRED-SIM-TB-D01")
        assert r.status_code == 200, r.text
        d = r.json()
        assert d["decision"] == "approved", d
        codes = [s["signal_code"] for s in d["all_signals"]]
        assert "COVERAGE_DOWNGRADE_APPLIED" not in codes, codes
        print(f"OK  TB-D01 tampa_smiles  approved, no downgrade on D2740")

        # ── dallas_dental — adult ortho ──────────────────────────────
        r = await client.get(f"{BASE}/decisions/PRED-SIM-DL-D01")
        assert r.status_code == 200, r.text
        d = r.json()
        assert d["decision"] == "denied", d
        assert d["payer_id"] == "humana_dpo", d["payer_id"]
        assert d["state"] == "TX", d["state"]
        print(f"OK  DL-D01 dallas_dental  denied (adult ortho)  "
              f"{d['payer_id']}/{d['state']}")

        # ── Cross-tenant isolation ───────────────────────────────────
        # The three answers above must not have leaked into each other.
        names = set()
        for pid in ("PRED-SIM-DA-A01", "PRED-SIM-TB-B01", "PRED-SIM-DL-D01"):
            names.add((await client.get(f"{BASE}/decisions/{pid}")
                       ).json()["patient_name"])
        assert len(names) == 3, names
        print(f"OK  cross-tenant isolation  3 distinct patients: "
              f"{', '.join(sorted(names))}")

        # ── Tampa patient-summary uses the FL fee schedule ───────────
        r = await client.get(
            f"{BASE}/decisions/PRED-SIM-TB-U01/patient-summary")
        assert r.status_code == 200, r.text
        ps = r.json()
        assert ps["state"] == "FL", ps["state"]
        assert ps["payer_id"] == "humana_dpo", ps["payer_id"]
        print(f"OK  TB-U01 patient-summary  state={ps['state']} "
              f"payer={ps['payer_id']} "
              f"pt=${ps['summary']['total_patient_pays']:,.2f}")

        # ── Portfolio summary ────────────────────────────────────────
        r = await client.get(f"{BASE}/portfolio/summary")
        assert r.status_code == 200, r.text
        port = r.json()
        s = port["summary"]
        assert s["total_practices"] == 3, s
        assert s["total_pre_ds"] == 50, s
        assert s["total_approved"] + s["total_denied"] + s["total_pended"] == 50, s
        practices = {p["tenant_id"]: p for p in port["practices"]}
        for t in ("suwanee_smiles", "tampa_smiles", "dallas_dental"):
            assert t in practices, list(practices)
        assert practices["suwanee_smiles"]["total_pre_ds"] == 40
        assert practices["tampa_smiles"]["total_pre_ds"] == 5
        assert practices["dallas_dental"]["total_pre_ds"] == 5
        # Every practice must have cost estimates or the revenue number
        # silently understates the group.
        assert not s["practices_missing_cost_estimates"], s
        print(f"OK  /portfolio/summary  {s['total_practices']} practices, "
              f"{s['total_pre_ds']} pre-Ds, "
              f"approval={s['overall_approval_rate']:.1%}")
        for p in port["practices"]:
            print(f"      {p['tenant_id']:16s} {p['total_pre_ds']:>2} pre-Ds  "
                  f"approval={p['approval_rate']:>6.1%}  "
                  f"score={p['avg_criteria_score']:.3f}  "
                  f"patient=${p['total_patient_pays']:>10,.2f}")
        print(f"      top denial reason: "
              f"{port['top_denial_reasons'][0]['condition_code']} "
              f"x{port['top_denial_reasons'][0]['frequency']}")

        # The portfolio endpoint is aggregate-only. A DSO manager may
        # know Tampa denies at 20%; that does not entitle them to a
        # Tampa patient's chart.
        blob = str(port)
        for leaked in ("James Mitchell", "Robert Martinez", "Emily Garcia",
                       "PRED-SIM-"):
            assert leaked not in blob, f"portfolio leaked {leaked!r}"
        print("OK  /portfolio/summary carries no patient or pre-D identifiers")

        print("\nALL MULTI-TENANT TESTS PASSED")
        return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
