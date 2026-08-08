"""Seed a demo schedule across three days so the date picker has options.

Idempotent: the unique index on (tenant_id, pred_request_id,
appointment_date) means re-running this on the same day is a no-op
rather than a second copy of the morning.

RUN THIS DAILY-ISH. Every row is stamped relative to CURRENT_DATE at
insert time, so a schedule seeded on the 6th is not "today" on the 7th
— which is exactly why /coverage rendered an empty morning after
midnight. The date picker makes that visible instead of mysterious, but
it does not stop the newest day going stale.

Names and NPIs come from the corpus, not from a brief:
  the Tampa NPI is 1234567890, and TB-A01 is Sarah Chen.
"""
import asyncio
import os
from datetime import time as _time
from urllib.parse import quote, urlparse

import asyncpg
import boto3
from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"))

# (tenant, pred_request_id, patient, HH:MM, summary, npi, days_ago)
ROWS = [
    # ── Today ────────────────────────────────────────────────────────
    ("suwanee_smiles", "PRED-SIM-DA-A01", "James Mitchell", "09:00",
     "Implant + crown", "1134534266", 0),
    ("suwanee_smiles", "PRED-SIM-DA-D04", "Linda Taylor", "09:30",
     "Crown", "1134534266", 0),
    ("suwanee_smiles", "PRED-SIM-DA-U01", "Robert Thompson", "10:00",
     "Cleaning", "1134534266", 0),
    ("suwanee_smiles", "PRED-SIM-DA-U02", "Maria Santos", "10:30",
     "Bitewings", "1134534266", 0),
    ("suwanee_smiles", "PRED-SIM-DA-B04", "Carlos Rivera", "11:00",
     "Implant + graft", "1134534266", 0),
    # ── Yesterday ────────────────────────────────────────────────────
    ("suwanee_smiles", "PRED-SIM-DA-A01", "James Mitchell", "09:00",
     "Implant + crown", "1134534266", 1),
    ("suwanee_smiles", "PRED-SIM-DA-D04", "Linda Taylor", "09:30",
     "Crown", "1134534266", 1),
    ("suwanee_smiles", "PRED-SIM-DA-U01", "Robert Thompson", "10:00",
     "Cleaning", "1134534266", 1),
    # ── Two days ago ─────────────────────────────────────────────────
    ("suwanee_smiles", "PRED-SIM-DA-B04", "Carlos Rivera", "11:00",
     "Implant + graft", "1134534266", 2),
    ("suwanee_smiles", "PRED-SIM-DA-U02", "Maria Santos", "10:30",
     "Bitewings", "1134534266", 2),
    # Tampa keeps a schedule too. Without this the second tenant's
    # check-in screen is empty, and an empty screen is the one state
    # that cannot tell you whether the tenant filter is working.
    ("tampa_smiles", "PRED-SIM-TB-A01", "Sarah Chen", "09:00",
     "Crown", "1234567890", 0),
    ("tampa_smiles", "PRED-SIM-TB-B01", "Robert Martinez", "10:00",
     "Implant", "1234567890", 0),
    ("tampa_smiles", "PRED-SIM-TB-A01", "Sarah Chen", "14:00",
     "Crown seat", "1234567890", 1),
]

INSERT = """
INSERT INTO appointments
  (tenant_id, pred_request_id, patient_name, appointment_date,
   appointment_time, procedure_summary, provider_npi, pms_source)
VALUES ($1, $2, $3, CURRENT_DATE - ($4 || ' days')::interval, $5, $6, $7,
        'manual')
ON CONFLICT (tenant_id, pred_request_id, appointment_date) DO NOTHING
"""


async def main() -> None:
    ssm = boto3.Session(profile_name="dental").client(
        "ssm", region_name="us-east-1")
    pw = ssm.get_parameter(
        Name="/dental/db/password", WithDecryption=True)["Parameter"]["Value"]
    u = urlparse(os.environ["DENTAL_OS_DATABASE_URL"])
    admin = (f"postgresql://dental_admin:{quote(pw, safe='')}"
             f"@{u.hostname}:{u.port or 5432}{u.path}")

    conn = await asyncpg.connect(admin)
    try:
        for tenant, pred, name, hhmm, summary, npi, days_ago in ROWS:
            # dental_admin owns the table and FORCE RLS binds the owner
            # too, so the tenant has to be set for every row.
            await conn.execute(
                "SELECT set_config('app.tenant_id', $1, false)", tenant)
            hh, mm = (int(x) for x in hhmm.split(":"))
            # asyncpg binds a TIME column from datetime.time, not a
            # string — the ::time cast would run after binding.
            await conn.execute(
                INSERT, tenant, pred, name, str(days_ago),
                _time(hh, mm), summary, npi)

        for tenant in ("suwanee_smiles", "tampa_smiles"):
            await conn.execute(
                "SELECT set_config('app.tenant_id', $1, false)", tenant)
            rows = await conn.fetch(
                "SELECT appointment_date, COUNT(*) AS n FROM appointments "
                "WHERE status <> 'cancelled' "
                "GROUP BY 1 ORDER BY 1 DESC LIMIT 10")
            print(f"\n{tenant}")
            for r in rows:
                print(f"  {r['appointment_date']}  {r['n']} appointments")
    finally:
        await conn.close()


asyncio.run(main())
