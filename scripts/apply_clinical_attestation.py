"""Apply migrations/004. DDL only — nothing to seed.

The dentist's tables start empty by design: a narrative, a
justification and an attestation are acts a person performs, and
seeding them would put words in a dentist's mouth and a signature
under a case nobody signed.
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

TABLES = (
    "clinical_narratives",
    "clinical_justifications",
    "document_requests",
    "clinical_attestations",
)


async def main() -> None:
    ssm = boto3.Session(profile_name="dental").client(
        "ssm", region_name="us-east-1")
    pw = ssm.get_parameter(
        Name="/dental/db/password", WithDecryption=True)["Parameter"]["Value"]
    u = urlparse(os.environ["DENTAL_OS_DATABASE_URL"])
    admin = (f"postgresql://dental_admin:{quote(pw, safe='')}"
             f"@{u.hostname}:{u.port or 5432}{u.path}")

    sql = (ROOT / "migrations" / "004_clinical_attestation.sql").read_text(
        encoding="utf-8")

    conn = await asyncpg.connect(admin)
    try:
        await conn.execute(sql)
        print("migration 004 applied")
        for t in TABLES:
            rls = await conn.fetchrow(
                "SELECT relrowsecurity, relforcerowsecurity FROM pg_class "
                "WHERE relname = $1", t)
            n = await conn.fetchval(f"SELECT count(*) FROM {t}")
            grants = await conn.fetch(
                "SELECT privilege_type FROM information_schema.role_table_grants "
                "WHERE table_name = $1 AND grantee = 'dental_app' "
                "ORDER BY privilege_type", t)
            print(f"  {t:24} rows={n} rls={rls['relrowsecurity']} "
                  f"force={rls['relforcerowsecurity']} "
                  f"grants={[g['privilege_type'] for g in grants]}")
    finally:
        await conn.close()


asyncio.run(main())
