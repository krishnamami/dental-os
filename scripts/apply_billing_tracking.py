"""Apply migrations/003 and seed the demo denial + appeal.

Idempotent. The DDL is IF NOT EXISTS throughout and the seed conflicts
on the unique indexes 003 adds, so running this twice is a no-op.

dental_admin owns these tables and FORCE ROW LEVEL SECURITY binds the
owner too, so every seed statement sets app.tenant_id first.
"""
import asyncio
import os
import pathlib
from urllib.parse import quote, urlparse

import asyncpg
import boto3
from dotenv import load_dotenv

ROOT = pathlib.Path(__file__).resolve().parent.parent
load_dotenv(ROOT / ".env")

TENANT = "suwanee_smiles"

SEED_DENIAL = """
INSERT INTO denial_events (
  tenant_id, pred_request_id, patient_name, payer_id, denied_at,
  denial_reason, denial_reason_code, denied_amount, appeal_deadline,
  appeal_viable, appeal_probability, notes
) VALUES (
  $1, 'PRED-SIM-DA-B04', 'Carlos Rivera', 'delta_dental',
  NOW() - INTERVAL '8 days',
  'bundling', 'D.7.4-BUNDLE', 1230.00,
  NOW() + INTERVAL '52 days',
  true, 65,
  'D7953 denied as bundled with D6010. Separable with a narrative '
  'documenting the graft as its own surgical episode.'
)
ON CONFLICT (tenant_id, pred_request_id) DO NOTHING
"""

# filed_by is a real users.user_id. The brief inlined a SELECT against
# `users` inside the INSERT — that works, but resolving it first makes
# the failure legible when the biller account is missing rather than
# raising a NOT NULL violation on a column nobody would look at.
SEED_APPEAL = """
INSERT INTO appeal_events (
  tenant_id, pred_request_id, denial_id, patient_name, payer_id,
  filed_by, filed_at, appeal_type, status, notes
) VALUES (
  $1, 'PRED-SIM-DA-B04',
  (SELECT denial_id FROM denial_events
   WHERE tenant_id = $1 AND pred_request_id = 'PRED-SIM-DA-B04'),
  'Carlos Rivera', 'delta_dental',
  $2, NOW() - INTERVAL '3 days', 'standard', 'pending',
  'Unbundling narrative attached; awaiting payer response.'
)
ON CONFLICT (tenant_id, pred_request_id) DO NOTHING
"""


async def main() -> None:
    ssm = boto3.Session(profile_name="dental").client(
        "ssm", region_name="us-east-1")
    pw = ssm.get_parameter(
        Name="/dental/db/password", WithDecryption=True)["Parameter"]["Value"]
    u = urlparse(os.environ["DENTAL_OS_DATABASE_URL"])
    admin = (f"postgresql://dental_admin:{quote(pw, safe='')}"
             f"@{u.hostname}:{u.port or 5432}{u.path}")

    sql = (ROOT / "migrations" / "003_billing_tracking.sql").read_text(
        encoding="utf-8")

    conn = await asyncpg.connect(admin)
    try:
        await conn.execute(sql)
        print("migration 003 applied")

        biller = await conn.fetchval(
            "SELECT user_id FROM users WHERE email = $1",
            "billing@suwaneesmiles.com")
        if not biller:
            raise SystemExit("billing@suwaneesmiles.com not found — "
                             "run scripts/seed_users.py first")

        await conn.execute(
            "SELECT set_config('app.tenant_id', $1, false)", TENANT)
        await conn.execute(SEED_DENIAL, TENANT)
        await conn.execute(SEED_APPEAL, TENANT, biller)
        print("seeded the DA-B04 denial + appeal")

        for table in ("submission_events", "denial_events", "appeal_events"):
            rls = await conn.fetchrow(
                "SELECT relrowsecurity, relforcerowsecurity FROM pg_class "
                "WHERE relname = $1", table)
            n = await conn.fetchval(f"SELECT count(*) FROM {table}")
            print(f"  {table:20} rows={n} rls={rls['relrowsecurity']} "
                  f"force={rls['relforcerowsecurity']}")

        d = await conn.fetchrow(
            "SELECT pred_request_id, denial_reason, denied_amount, "
            "       appeal_viable, appeal_probability, "
            "       (appeal_deadline::date - CURRENT_DATE) AS days_left "
            "FROM denial_events WHERE tenant_id = $1", TENANT)
        print("  denial:", dict(d) if d else None)
        a = await conn.fetchrow(
            "SELECT pred_request_id, status, appeal_type, denial_id "
            "FROM appeal_events WHERE tenant_id = $1", TENANT)
        print("  appeal:", dict(a) if a else None)
    finally:
        await conn.close()


asyncio.run(main())
