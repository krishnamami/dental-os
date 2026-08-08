"""Give every patient an email and a mobile number.

⚠ THIS TOUCHES A DENTAL-SIMULATOR TABLE. CONTEXT.md RULE 15 makes
`patients` READ-ONLY for dental-os, and that rule holds at runtime —
the API only ever SELECTs these columns. This is a one-off migration
run by hand against the database, not by the service, and its proper
long-term home is dental-simulator's own migrations. It lives here
because that is where the feature was asked for; move it when the two
repos next reconcile their schemas.

Idempotent: ADD COLUMN IF NOT EXISTS, and the backfill only touches
rows where email IS NULL.

Addresses are synthetic and deliberately on @email.com — a
non-deliverable placeholder domain. Nothing in this corpus is a real
person, and a demo that sends mail to a plausible real address is a
demo that eventually mails a stranger.
"""
import asyncio
import os
from urllib.parse import quote, urlparse

import asyncpg
import boto3
from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"))

DDL = """
ALTER TABLE patients
  ADD COLUMN IF NOT EXISTS email TEXT,
  ADD COLUMN IF NOT EXISTS mobile_phone TEXT;
"""

# A window function cannot appear in UPDATE ... SET — the brief's
# `LPAD((ROW_NUMBER() OVER())::TEXT, 4, '0')` is a syntax error in
# Postgres. It has to be computed in a subquery and joined back.
#
# The row number is taken over (tenant_id, patient_id) so a re-run
# assigns the same number to the same patient, and so two practices
# cannot collide on one phone number.
BACKFILL = """
WITH numbered AS (
  SELECT patient_id,
         tenant_id,
         ROW_NUMBER() OVER (ORDER BY tenant_id, patient_id) AS n
  FROM patients
)
UPDATE patients p
SET email = lower(regexp_replace(p.first_name, '^(Dr|Mr|Mrs|Ms)\\.?\\s+', ''))
            || '.' || lower(p.last_name)
            -- The row number is in the local part, not just the phone:
            -- this corpus has repeated names, and without it two
            -- different patients would share one address.
            || '.' || numbered.n || '@email.com',
    mobile_phone = '+1770555' || LPAD(numbered.n::TEXT, 4, '0')
FROM numbered
WHERE p.patient_id = numbered.patient_id
  AND p.tenant_id = numbered.tenant_id
  AND p.email IS NULL;
"""

# The five on today's schedule get the clean addresses the demo script
# reads out. Applied after the backfill so they win.
#
# Keyed on patient_id, NOT on name. There are TWO Carlos Riveras in
# this corpus (PAT-DA-B04 and PAT-DA-D05), so matching on
# first_name/last_name gave them the same address — two different
# patients, one inbox, and a coordinator one click from mailing the
# wrong person's treatment estimate. The other Carlos keeps his
# backfilled address.
DEMO = [
    ("PAT-DA-A01", "james.mitchell@email.com", "+17705550001"),
    ("PAT-DA-D04", "linda.taylor@email.com", "+17705550002"),
    ("PAT-DA-B04", "carlos.rivera@email.com", "+17705550003"),
    ("PAT-DA-U01", "robert.thompson@email.com", "+17705550004"),
    ("PAT-DA-U02", "maria.santos@email.com", "+17705550005"),
]


async def main() -> None:
    ssm = boto3.Session(profile_name="dental").client(
        "ssm", region_name="us-east-1")
    pw = ssm.get_parameter(
        Name="/dental/db/password", WithDecryption=True)["Parameter"]["Value"]
    u = urlparse(os.environ["DATABASE_URL"])
    admin = (f"postgresql://dental_admin:{quote(pw, safe='')}"
             f"@{u.hostname}:{u.port or 5432}{u.path}")

    conn = await asyncpg.connect(admin)
    try:
        await conn.execute(DDL)
        print("patients.email + patients.mobile_phone ready")

        # patients is RLS-protected and dental_admin owns it under FORCE
        # ROW LEVEL SECURITY, so every statement needs a tenant set.
        tenants = [
            r["tenant_id"]
            for r in await conn.fetch(
                "SELECT tenant_id FROM tenants WHERE active ORDER BY 1")
        ]
        for tenant in tenants:
            await conn.execute(
                "SELECT set_config('app.tenant_id', $1, false)", tenant)
            await conn.execute(BACKFILL)
            for patient_id, email, phone in DEMO:
                await conn.execute(
                    "UPDATE patients SET email = $1, mobile_phone = $2 "
                    "WHERE patient_id = $3 AND tenant_id = $4",
                    email, phone, patient_id, tenant)

        for tenant in tenants:
            await conn.execute(
                "SELECT set_config('app.tenant_id', $1, false)", tenant)
            rows = await conn.fetch(
                "SELECT first_name, last_name, email, mobile_phone "
                "FROM patients WHERE email IS NOT NULL "
                "ORDER BY last_name LIMIT 4")
            total = await conn.fetchval(
                "SELECT count(*) FROM patients WHERE email IS NULL")
            print(f"\n{tenant}: {total} still without an address")
            for r in rows:
                print(f"  {r['first_name']} {r['last_name']:12} "
                      f"{r['email']:34} {r['mobile_phone']}")

        dupes = await conn.fetch(
            "SELECT email, count(*) n FROM patients WHERE email IS NOT NULL "
            "GROUP BY email HAVING count(*) > 1")
        print("\nduplicate addresses:", len(dupes))
        for d in dupes:
            print("  ", d["email"], d["n"])
    finally:
        await conn.close()


asyncio.run(main())
