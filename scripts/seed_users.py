"""
Create the `users` table in dental_os and seed the demo accounts.

    python scripts/seed_users.py

Idempotent: ON CONFLICT (email) DO UPDATE, so re-running re-hashes the
password and corrects a name or role without creating duplicates.

⚠ THE PASSWORD IS THE SAME FOR ALL ELEVEN AND IT IS PUBLIC.
`demo2026` is written down in the login screen's own demo panel, and
one of these accounts is accord_admin — which can impersonate every
other user. That is a deliberate trade for a sales demo against a
synthetic corpus. It stops being acceptable the moment a real patient
record exists in this database; at that point these rows come out and
the seeding pathway goes with them.

NO RLS ON THIS TABLE, on purpose. Every other dental_os table is FORCE
row-level security scoped by app.tenant_id, but a login cannot set a
tenant before it knows who is asking, and accord_admin has no tenant at
all. `users` is therefore the one cross-tenant table here — which is
exactly why it holds nothing but credentials and a role.
"""
from __future__ import annotations

import asyncio
import os
import sys
from urllib.parse import urlparse

import asyncpg
import bcrypt
from dotenv import load_dotenv

load_dotenv()

PASSWORD = b"demo2026"

USERS: list[tuple[str, str, str, str | None]] = [
    # Suwanee Smiles — GA
    ("sarah@suwaneesmiles.com", "Sarah R.", "front_desk", "suwanee_smiles"),
    ("billing@suwaneesmiles.com", "Kim B.", "revenue_ops", "suwanee_smiles"),
    ("drchinta@suwaneesmiles.com", "Dr. Sridhar Chinta", "dentist", "suwanee_smiles"),
    ("drshyam@suwaneesmiles.com", "Dr. Shyam Patel", "dso_owner", "suwanee_smiles"),
    # Tampa Bay Smiles — FL
    ("sarah@tampabaysmiles.com", "Sarah T.", "front_desk", "tampa_smiles"),
    ("billing@tampabaysmiles.com", "Kim T.", "revenue_ops", "tampa_smiles"),
    ("drrodriguez@tampabaysmiles.com", "Dr. Maria Rodriguez", "dentist", "tampa_smiles"),
    ("drshyam@tampabaysmiles.com", "Dr. Shyam Patel", "dso_owner", "tampa_smiles"),
    # Dallas Family Dental — TX
    ("billing@dallasfamilydental.com", "Kim D.", "revenue_ops", "dallas_dental"),
    ("drwilson@dallasfamilydental.com", "Dr. James Wilson", "dentist", "dallas_dental"),
    # Accord platform — no tenant
    ("admin@accorddental.io", "Accord Admin", "accord_admin", None),
]

DDL = """
CREATE TABLE IF NOT EXISTS users (
  user_id       TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  email         TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  name          TEXT NOT NULL,
  role          TEXT NOT NULL CHECK (role IN (
                  'front_desk','revenue_ops','dentist',
                  'dso_owner','accord_admin')),
  tenant_id     TEXT,
  active        BOOLEAN DEFAULT true,
  created_at    TIMESTAMPTZ DEFAULT NOW()
)
"""


async def main() -> int:
    dsn = os.environ.get("DENTAL_OS_DATABASE_URL")
    if not dsn:
        print(
            "DENTAL_OS_DATABASE_URL is not set. It must end in /dental_os — "
            "seeding users into the dental-simulator database would violate "
            "RULE 15.",
            file=sys.stderr,
        )
        return 2
    if not urlparse(dsn).path.endswith("/dental_os"):
        print(f"Refusing to seed: DSN does not point at /dental_os", file=sys.stderr)
        return 2

    conn = await asyncpg.connect(dsn)
    try:
        # The API's role (dental_app) has no DDL rights on this
        # database — deliberately. The table is created once by
        # dental_admin, whose password lives only in SSM at
        # /dental/db/password and must never appear in a file here.
        exists = await conn.fetchval("SELECT to_regclass('public.users')")
        if not exists:
            print(
                "The `users` table does not exist and this role cannot "
                "create it. Run the DDL in this file as dental_admin "
                "first, then GRANT SELECT, INSERT, UPDATE ON users TO "
                "dental_app.",
                file=sys.stderr,
            )
            return 2
        print("users table present")

        # One hash for all eleven — they share a password, and eleven
        # separate bcrypt rounds would only make the script slower.
        pw_hash = bcrypt.hashpw(PASSWORD, bcrypt.gensalt()).decode()

        for email, name, role, tenant_id in USERS:
            await conn.execute(
                """
                INSERT INTO users (email, password_hash, name, role, tenant_id)
                VALUES ($1, $2, $3, $4, $5)
                ON CONFLICT (email) DO UPDATE
                  SET password_hash = $2, name = $3, role = $4,
                      tenant_id = $5, active = true
                """,
                email,
                pw_hash,
                name,
                role,
                tenant_id,
            )
            print(f"  seeded {email:35} {role}")

        rows = await conn.fetch(
            "SELECT email, name, role, tenant_id FROM users "
            "ORDER BY tenant_id NULLS LAST, role, name"
        )
        print(f"\n{len(rows)} users in dental_os.users")
        for r in rows:
            print(
                f"  {r['email']:35} {r['name']:22} "
                f"{r['role']:13} {r['tenant_id'] or 'platform'}"
            )
        return 0
    finally:
        await conn.close()


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
