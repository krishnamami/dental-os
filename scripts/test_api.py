"""
Phase 6 integration test — every endpoint against a running API.

    uvicorn api.main:app --port 9010        # terminal 1
    python scripts/test_api.py              # terminal 2

Three expectations in the task spec did not survive contact with the
data. The values asserted below are what the system actually produces,
each verified independently of the API:

  decision_outputs   347, not 360. appeal_specialist carries
                     `only_if decision in (denied, pended)`; 27 of 40
                     qualify, so 27*9 + 13*8 = 347. A 360 here would
                     mean the Wave 5 gate stopped working.

  confidence_label   DA-A01 scores exactly 0.850 and the band in
                     pred_context.confidence_label is `>= 0.85 ->
                     "High confidence"`. "Likely to be approved" is the
                     0.70-0.85 band, which 0.850 is not in.

  total_patient_pays 1825.0, not 1800.0. coverage_resolver agrees line
                     for line with dental-simulator's independently
                     computed cost_estimates: 1017.50 + 212.50 + 595.00
                     = 1825.00 (CONTEXT.md, Gap #4).
"""
from __future__ import annotations

import asyncio
import sys

import httpx

BASE = "http://localhost:9010"

# Floors, not equalities. decision_outputs is append-only and this
# script's own slow-path test adds a bundle, so an exact match would
# fail on the second run of a passing suite. 347/40 is the count after
# one clean sweep of all 40 scenarios; it only ever grows from there.
MIN_DECISION_OUTPUTS = 347
MIN_PERSONA_BUNDLES = 40


async def main() -> int:
    async with httpx.AsyncClient(timeout=60) as client:
        try:
            await client.get(f"{BASE}/health")
        except httpx.ConnectError:
            print(f"Nothing listening on {BASE}.\n"
                  f"Start it first:  uvicorn api.main:app --port 9010")
            return 1

        # ── Health ───────────────────────────────────────────────────
        r = await client.get(f"{BASE}/health")
        assert r.status_code == 200, r.text
        h = r.json()
        assert h["status"] == "healthy", h
        assert h["version"] == "0.2.0", h
        assert h["simulator_db"] == "connected", h
        assert h["os_db"] == "connected", h
        assert h["simulator_scenarios"] == 40, h
        assert h["decision_outputs"] >= MIN_DECISION_OUTPUTS, h
        assert h["persona_bundles"] >= MIN_PERSONA_BUNDLES, h
        print(f"OK  /health  scenarios={h['simulator_scenarios']} "
              f"outputs={h['decision_outputs']} "
              f"bundles={h['persona_bundles']}")

        # ── T-33 main decision endpoint ──────────────────────────────
        r = await client.get(f"{BASE}/decisions/PRED-SIM-DA-A01")
        assert r.status_code == 200, r.text
        data = r.json()
        assert data["patient_name"] == "James Mitchell", data["patient_name"]
        assert data["decision"] == "pended", data["decision"]
        assert data["confidence_label"] == "High confidence", \
            data["confidence_label"]
        assert data["submission_ready"] is False, data["submission_ready"]
        signals = data["all_signals"]
        codes = [s["signal_code"] for s in signals]
        assert "COVERAGE_BUNDLING_CONFLICT" in codes, codes
        assert "DOC_NARRATIVE_MISSING" in codes, codes
        assert "CLINICAL_CRITERIA_MET" in codes, codes
        assert "FRAUD_UPCODING" not in codes, codes
        assert "PROVIDER_OIG_EXCLUDED" not in codes, codes
        # All five waves present, nine decisions.
        assert sorted(data["waves"]) == ["1", "2", "3", "4", "5"], \
            sorted(data["waves"])
        assert sum(len(v) for v in data["waves"].values()) == 9
        assert data["computed"] is False, "expected the fast path"
        print(f"OK  /decisions/DA-A01  signals={len(signals)} "
              f"waves=5 decisions=9 bundle={data['bundle_id'][:8]} "
              f"fast_path={not data['computed']}")

        # ── T-34 conditions ──────────────────────────────────────────
        r = await client.get(f"{BASE}/decisions/PRED-SIM-DA-A01/conditions")
        assert r.status_code == 200, r.text
        c = r.json()
        conds = c["conditions"]
        assert len(conds) > 0, c
        assert any(x["assignee"] == "billing" for x in conds), \
            [x["assignee"] for x in conds]
        assert c["conditions_count"] == len(conds)
        assert c["blocking_count"] + c["advisory_count"] == c["conditions_count"]
        # A work queue, not a report — clean confirmations stay out.
        assert "ELIGIBILITY_VERIFIED" not in [x["signal_code"] for x in conds]
        print(f"OK  /conditions  count={c['conditions_count']} "
              f"blocking={c['blocking_count']} "
              f"advisory={c['advisory_count']}")

        # ── T-36 patient summary ─────────────────────────────────────
        r = await client.get(
            f"{BASE}/decisions/PRED-SIM-DA-A01/patient-summary"
        )
        assert r.status_code == 200, r.text
        ps = r.json()
        s = ps["summary"]
        assert s["total_provider_charges"] == 5550.0, s
        assert s["total_in_network_savings"] == 1950.0, s
        assert s["total_patient_pays"] == 1825.0, s
        assert s["total_contracted"] == 3600.0, s
        # UCR = contracted + discount, or the page contradicts itself.
        assert round(
            s["total_contracted"] + s["total_in_network_savings"], 2
        ) == s["total_provider_charges"], s
        # contracted = insurance + patient, same reason.
        assert round(
            s["total_insurance_pays"] + s["total_patient_pays"], 2
        ) == s["total_contracted"], s
        assert len(ps["procedures"]) == 3, ps["procedures"]
        assert all(p["description"] for p in ps["procedures"]), \
            "every CDT code should resolve a description"
        print(f"OK  /patient-summary  "
              f"UCR=${s['total_provider_charges']:,.0f} "
              f"savings=${s['total_in_network_savings']:,.0f} "
              f"ins=${s['total_insurance_pays']:,.0f} "
              f"pt=${s['total_patient_pays']:,.0f}")

        # ── T-35 appeal — pended case ────────────────────────────────
        r = await client.get(f"{BASE}/decisions/PRED-SIM-DA-B04/appeal")
        assert r.status_code == 200, r.text
        ap = r.json()
        assert ap["viable"] is True, ap
        assert ap["success_probability"] == 0.65, ap
        assert ap["appeal_letter_text"], "expected a draft letter"
        assert ap["appeal_letter_is_draft"] is True, ap
        assert len(ap["evidence_list"]) > 0, ap
        assert len(ap["citations"]) > 0, ap
        print(f"OK  /appeal DA-B04  viable={ap['viable']} "
              f"prob={ap['success_probability']} "
              f"evidence={len(ap['evidence_list'])} "
              f"citations={len(ap['citations'])}")

        # ── T-35 appeal — approved case is a 404 ─────────────────────
        r = await client.get(f"{BASE}/decisions/PRED-SIM-DA-A02/appeal")
        assert r.status_code == 404, f"{r.status_code} {r.text}"
        print("OK  /appeal DA-A02  404 (approved — nothing to appeal)")

        # ── T-37 feedback ────────────────────────────────────────────
        r = await client.post(
            f"{BASE}/decisions/PRED-SIM-DA-A01/feedback",
            json={
                "decision_id": "coverage_analyst",
                "signal_code": "COVERAGE_BUNDLING_CONFLICT",
                "feedback_type": "accepted",
                "notes": "Confirmed — will add narrative",
                "submitted_by": "billing",
            },
        )
        assert r.status_code == 200, r.text
        fb = r.json()
        assert "feedback_id" in fb, fb
        assert fb["feedback_type"] == "accepted", fb
        print(f"OK  /feedback  accepted  id={fb['feedback_id'][:8]}")

        # A bad feedback_type must be rejected before it reaches PG.
        r = await client.post(
            f"{BASE}/decisions/PRED-SIM-DA-A01/feedback",
            json={
                "decision_id": "coverage_analyst",
                "signal_code": "COVERAGE_BUNDLING_CONFLICT",
                "feedback_type": "looks_fine",
                "submitted_by": "billing",
            },
        )
        assert r.status_code == 422, f"{r.status_code} {r.text}"
        print("OK  /feedback  422 on invalid feedback_type")

        # ── 404 on an unknown pre-D ──────────────────────────────────
        r = await client.get(f"{BASE}/decisions/PRED-SIM-DA-Z99")
        assert r.status_code == 404, f"{r.status_code} {r.text}"
        print("OK  /decisions/DA-Z99  404 (no such pre-D)")

        # ── RULE 14 — the old id format is a 400, not a 404 ──────────
        r = await client.get(f"{BASE}/decisions/PRED-DA-A01")
        assert r.status_code == 400, f"{r.status_code} {r.text}"
        print("OK  /decisions/PRED-DA-A01  400 (old id format, RULE 14)")

        # ── Slow path — ?refresh=true re-runs the personas ────────────
        # Every pre-D already has a bundle, so this is the only way to
        # exercise the PersonaRunner branch of T-33. It appends a new
        # bundle and supersedes the old one; the counts above are why
        # they are floors.
        before = (await client.get(f"{BASE}/health")).json()
        r = await client.get(
            f"{BASE}/decisions/PRED-SIM-DA-A01", params={"refresh": "true"}
        )
        assert r.status_code == 200, r.text
        fresh = r.json()
        assert fresh["computed"] is True, "expected the slow path"
        assert fresh["bundle_id"] != data["bundle_id"], \
            "a refresh must mint a new bundle, not reuse the old one"
        # Same inputs, same catalogue, same answer — the runner is
        # deterministic and nothing about a re-run may change a verdict.
        assert [s["signal_code"] for s in fresh["all_signals"]] == codes
        after = (await client.get(f"{BASE}/health")).json()
        assert after["decision_outputs"] == before["decision_outputs"] + 9, \
            (before, after)
        assert after["persona_bundles"] == before["persona_bundles"] + 1, \
            (before, after)
        print(f"OK  /decisions/DA-A01?refresh  slow_path=True "
              f"bundle={fresh['bundle_id'][:8]} "
              f"(+9 outputs, +1 bundle, signals identical)")

        print("\nALL API TESTS PASSED")
        return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
