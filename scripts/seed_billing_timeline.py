"""Seed three pre-Ds with a real submitted -> denied -> appealed chain.

Replaces the fragment in apply_billing_tracking.py, which wrote a
denial and an appeal and no submission, each date independently
anchored to NOW() at seed time. A denial preceded nothing; an appeal
was filed against a case that had never been sent.

── WHY THREE ─────────────────────────────────────────────────────────
The appeals tab has to show work at three stages or it shows nothing:

  DA-B04  bundling        appeal PENDING     the live one
  DA-B01  frequency       appeal OVERTURNED  the win, and the only
                          thing that gives overturn_rate a denominator
                          — it renders "—" with zero resolved appeals,
                          which is correct and empty
  DA-B05  waiting period  appeal UPHELD      the loss, so the rate is
                          not a meaningless 100%

Patient names are deliberately absent here: they are read from the
corpus. An earlier draft of this file named "Marcus Webb" and "Diane
Foster" for B01 and B05, who are actually Patricia Johnson and Ashley
Thompson — inventing a patient is the exact failure this seed exists
to stop.

Three is the floor. Two cannot produce a credible rate (one resolved
appeal is 0% or 100%). Forty would make every case an appeal, which is
not what a practice looks like — the other 37 stay unsubmitted, which
is also true of a Monday morning.

── EVERY DATE IS DERIVED FROM THE ONE BEFORE IT ──────────────────────
submitted_at is the anchor. Everything else is an interval from it:

  submitted_at    T
  denied_at       T + payer turnaround (14-21 days)
  appeal_deadline denied_at + the payer's own appeal window (60 days)
  filed_at        denied_at + how long billing took to react
  resolved_at     filed_at + the payer's appeal turnaround

Nothing is anchored to NOW(), so the chain stays coherent whenever it
is re-run and however long the corpus sits.
"""
from __future__ import annotations

import asyncio
import os
import pathlib
from datetime import date, datetime, timedelta, timezone

import asyncpg
from dotenv import load_dotenv

ROOT = pathlib.Path(__file__).resolve().parent.parent
load_dotenv(ROOT / ".env")

TENANT = "suwanee_smiles"
PAYER = "delta_dental"

# The payer's appeal window. 60 days is Delta's published figure for
# this plan type; it is applied to denied_at rather than stamped.
APPEAL_WINDOW_DAYS = 60


def _anchor(days_ago: int) -> datetime:
    """A submission date, counted back from today at a fixed hour.

    Fixed hour so re-running does not shuffle same-day ordering.
    """
    d = date.today() - timedelta(days=days_ago)
    return datetime(d.year, d.month, d.day, 14, 30, tzinfo=timezone.utc)


# ⚠ NO PATIENT NAMES AND NO AMOUNTS ARE WRITTEN HERE. Both are read
# from the corpus at run time — the previous seed hardcoded "Carlos
# Rivera" and a denied_amount of 1230.00 that matched no line on the
# case (B04 is D6010 2800 + D7953 950). `denied_codes` names which
# procedure the payer refused; the amount is the sum of those lines'
# fees, so the money on screen is the money on the claim.
CASES = [
    {
        "pred": "PRED-SIM-DA-B04",
        "submitted_days_ago": 30,
        "payer_turnaround": 14,     # denial lands 14 days after sending
        "reason": "bundling",
        "reason_code": "D.7.4-BUNDLE",
        "denied_codes": ["D7953"],  # the graft, bundled into the implant
        "note": ("D7953 denied as bundled with D6010. Separable with a "
                 "narrative documenting the graft as its own surgical "
                 "episode."),
        "appeal_after_days": 5,     # billing filed 5 days after the denial
        "appeal_status": "pending",
        "resolved_after_days": None,
        "recovers": False,
    },
    {
        "pred": "PRED-SIM-DA-B01",
        "submitted_days_ago": 96,
        "payer_turnaround": 18,
        "reason": "frequency",
        "reason_code": "D.1.2-FREQ",
        "denied_codes": ["D6065"],  # the crown on the implant
        "note": ("Denied against the frequency limit. The prior "
                 "restoration was placed by another practice and the "
                 "limit runs from the seat date, not the prep date."),
        "appeal_after_days": 6,
        "appeal_status": "overturned",
        "resolved_after_days": 28,  # payer turned it over 28 days later
        "recovers": True,           # recovered == the denied amount
    },
    {
        "pred": "PRED-SIM-DA-B05",
        "submitted_days_ago": 88,
        "payer_turnaround": 16,
        "reason": "waiting_period",
        "reason_code": "D.2.1-WAIT",
        "denied_codes": ["D2750"],
        "note": ("Denied inside the 12-month major-services waiting "
                 "period. Appealed on continuous-coverage grounds; the "
                 "prior carrier's certificate did not cover the gap."),
        "appeal_after_days": 4,
        "appeal_status": "upheld",
        "resolved_after_days": 31,
        "recovers": False,          # upheld: nothing came back
    },
]


async def _from_corpus(sim_url: str) -> dict:
    """Patient name and denied amount, per case, out of the simulator."""
    sim = await asyncpg.connect(sim_url)
    try:
        out = {}
        for c in CASES:
            await sim.execute(
                "SELECT set_config('app.tenant_id', $1, true)", TENANT)
            row = await sim.fetchrow(
                "SELECT p.first_name || ' ' || p.last_name AS nm "
                "FROM pred_requests pr JOIN patients p "
                "  ON p.patient_id = pr.patient_id "
                "WHERE pr.pred_request_id = $1", c["pred"])
            if row is None:
                raise SystemExit(f"{c['pred']} is not in the corpus.")
            amount = await sim.fetchval(
                "SELECT COALESCE(SUM(fee), 0) FROM procedure_lines "
                "WHERE pred_request_id = $1 AND cdt_code = ANY($2::text[])",
                c["pred"], c["denied_codes"])
            if not amount:
                raise SystemExit(
                    f"{c['pred']} has no line for {c['denied_codes']}")
            out[c["pred"]] = {"patient": row["nm"], "amount": float(amount)}
        return out
    finally:
        await sim.close()


async def main() -> None:
    os_url = os.environ["DENTAL_OS_DATABASE_URL"]
    corpus = await _from_corpus(os.environ["DENTAL_DATABASE_URL"])
    conn = await asyncpg.connect(os_url)
    try:
        biller = await conn.fetchval(
            "SELECT user_id FROM authenticate_user($1)",
            "billing@suwaneesmiles.com",
        )
        if not biller:
            raise SystemExit(
                "billing@suwaneesmiles.com not found — seed users first."
            )

        async with conn.transaction():
            await conn.execute(
                "SELECT set_config('app.tenant_id', $1, true)", TENANT)

            # Clear only what this script owns, so re-running is safe.
            preds = [c["pred"] for c in CASES]
            await conn.execute(
                "DELETE FROM appeal_events WHERE tenant_id = $1 "
                "AND pred_request_id = ANY($2::text[])", TENANT, preds)
            await conn.execute(
                "DELETE FROM denial_events WHERE tenant_id = $1 "
                "AND pred_request_id = ANY($2::text[])", TENANT, preds)
            await conn.execute(
                "DELETE FROM submission_events WHERE tenant_id = $1 "
                "AND pred_request_id = ANY($2::text[])", TENANT, preds)

            for c in CASES:
                submitted = _anchor(c["submitted_days_ago"])
                denied = submitted + timedelta(days=c["payer_turnaround"])
                deadline = denied + timedelta(days=APPEAL_WINDOW_DAYS)
                filed = denied + timedelta(days=c["appeal_after_days"])
                resolved = (
                    filed + timedelta(days=c["resolved_after_days"])
                    if c["resolved_after_days"] is not None
                    else None
                )

                submission_id = await conn.fetchval(
                    """
                    INSERT INTO submission_events
                        (tenant_id, pred_request_id, patient_name, payer_id,
                         payer_name, submitted_by, submitted_at,
                         submission_method, status, notes)
                    VALUES ($1,$2,$3,$4,$5,$6,$7,'manual','responded',$8)
                    RETURNING submission_id
                    """,
                    TENANT, c["pred"], corpus[c["pred"]]["patient"], PAYER,
                    "Delta Dental PPO",
                    biller, submitted,
                    "Submitted from the revenue ops queue.",
                )

                denial_id = await conn.fetchval(
                    """
                    INSERT INTO denial_events
                        (tenant_id, pred_request_id, patient_name, payer_id,
                         submission_id, denied_at, denial_reason,
                         denial_reason_code, denied_amount, appeal_deadline,
                         appeal_viable, appeal_probability, notes)
                    VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,true,65,$11)
                    RETURNING denial_id
                    """,
                    TENANT, c["pred"], corpus[c["pred"]]["patient"], PAYER,
                    submission_id, denied, c["reason"], c["reason_code"],
                    corpus[c["pred"]]["amount"], deadline, c["note"],
                )

                await conn.execute(
                    """
                    INSERT INTO appeal_events
                        (tenant_id, pred_request_id, denial_id, patient_name,
                         payer_id, filed_by, filed_at, appeal_type, status,
                         resolved_at, recovered_amount, notes)
                    VALUES ($1,$2,$3,$4,$5,$6,$7,'standard',$8,$9,$10,$11)
                    """,
                    TENANT, c["pred"], denial_id, corpus[c["pred"]]["patient"],
                    PAYER, biller, filed, c["appeal_status"], resolved,
                    (corpus[c["pred"]]["amount"] if c["recovers"]
                     else (0.00 if resolved else None)),
                    c["note"],
                )

                print(f"  {c['pred']}  submitted {submitted:%Y-%m-%d}"
                      f" -> denied {denied:%Y-%m-%d}"
                      f" -> filed {filed:%Y-%m-%d}"
                      f" -> {c['appeal_status']}"
                      + (f" {resolved:%Y-%m-%d}" if resolved else ""))

        # Prove the chain rather than trusting the inserts.
        bad = await conn.fetch(
            """
            SELECT d.pred_request_id
            FROM denial_events d
            LEFT JOIN submission_events s ON s.submission_id = d.submission_id
            WHERE d.tenant_id = $1
              AND (s.submission_id IS NULL OR d.denied_at < s.submitted_at)
            """,
            TENANT,
        )
        assert not bad, f"denial without or before its submission: {bad}"
        bad = await conn.fetch(
            """
            SELECT a.pred_request_id
            FROM appeal_events a
            LEFT JOIN denial_events d ON d.denial_id = a.denial_id
            WHERE a.tenant_id = $1
              AND (d.denial_id IS NULL OR a.filed_at < d.denied_at)
            """,
            TENANT,
        )
        assert not bad, f"appeal without or before its denial: {bad}"
        print("  chain verified: submission -> denial -> appeal, in order")
    finally:
        await conn.close()


if __name__ == "__main__":
    asyncio.run(main())
