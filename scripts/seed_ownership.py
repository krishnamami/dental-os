"""Populate tenant_ownership, and make Dr. Shyam one account.

    python scripts/seed_ownership.py            # show what it would do
    python scripts/seed_ownership.py --apply

Idempotent. Run it after migrations/012.

── WHAT IT DOES AND WHY EACH PART ────────────────────────────────────

1. DALLAS GETS AN OWNER. Dallas Family Dental had a dentist and a
   biller and nobody who could see its portfolio at all — the practice
   was invisible to everyone except accord_admin.

2. DR. SHYAM BECOMES ONE ACCOUNT. He was two user rows,
   drshyam@suwaneesmiles.com and drshyam@tampabaysmiles.com, with
   different user_ids and nothing linking them. The Suwanee row
   survives and gains ownership of both practices.

   ⚠ THE TAMPA ROW IS DEACTIVATED, NOT DELETED. Nothing keys off it —
   checked before writing this, all eleven user-referencing columns in
   dental_os hold zero rows for that user_id and no foreign key
   anywhere points at users — so a delete would be safe. It is still a
   deactivate, because `active = false` is one UPDATE away from being
   wrong and a DELETE is not. Reverse with:

       UPDATE users SET active = true
        WHERE email = 'drshyam@tampabaysmiles.com';

3. EVERY REMAINING dso_owner OWNS THEIR OWN PRACTICE. That is the
   relationship users.tenant_id used to imply, made explicit.

── READING AND WRITING UNDER RLS ─────────────────────────────────────
⚠ THE FIRST DRAFT OF THIS SCRIPT WAS BITTEN BY THE TRAP IT IS ABOUT.
`users` and `tenant_ownership` are both FORCE row-level security. An
unscoped `SELECT ... FROM users WHERE email = $1` returns ZERO ROWS and
raises nothing, so the dry run reported "user does not exist, will
create" about an account that was sitting right there. Exactly the
failure CONTEXT.md warns about, in the script written to avoid it.

So: every read of `users` goes through list_active_users(), the
SECURITY DEFINER function from migrations/006, and every write binds
app.tenant_id to the row's own tenant first. Binding rather than
reaching for a bypass role also means a bug that tried to grant one
practice to another practice's owner is refused by the database.
"""
from __future__ import annotations

import asyncio
import os
import sys

import asyncpg
import bcrypt
from dotenv import load_dotenv

load_dotenv()

PASSWORD = b"demo2026"

# The one account that did not exist. Seeded, like every other login in
# this deployment — the corpus is synthetic.
DALLAS_OWNER = {
    "email": "drreyes@dallasfamilydental.com",
    "name": "Dr. Alan Reyes",
    "role": "dso_owner",
    "tenant_id": "dallas_dental",
}

RETIRE = "drshyam@tampabaysmiles.com"
SURVIVES = "drshyam@suwaneesmiles.com"

# Ownership beyond "the practice on my own row", which is granted to
# every dso_owner automatically below.
EXTRA_OWNERSHIP: dict[str, list[str]] = {
    SURVIVES: ["tampa_smiles"],
}


async def main(apply: bool) -> int:
    dsn = os.environ.get("DENTAL_OS_DATABASE_URL")
    if not dsn:
        print("DENTAL_OS_DATABASE_URL is not set", file=sys.stderr)
        return 2
    conn = await asyncpg.connect(dsn)
    plan: list[str] = []
    try:
        async with conn.transaction():
            # ── 1. Dallas's owner ────────────────────────────────────
            # list_active_users() rather than a bare SELECT — see the
            # module docstring. An inactive account is invisible to it,
            # which is correct here: a deactivated Dallas owner should
            # be reactivated by hand, not silently re-created.
            active = {r["email"]: dict(r)
                      for r in await conn.fetch("SELECT * FROM list_active_users()")}
            row = active.get(DALLAS_OWNER["email"])
            if row is None:
                plan.append(f"CREATE user {DALLAS_OWNER['email']} "
                            f"({DALLAS_OWNER['role']}, "
                            f"{DALLAS_OWNER['tenant_id']})")
                if apply:
                    pw = bcrypt.hashpw(PASSWORD, bcrypt.gensalt()).decode()
                    # WITH CHECK on the users policy: bind first.
                    await conn.execute(
                        "SELECT set_config('app.tenant_id', $1, true)",
                        DALLAS_OWNER["tenant_id"])
                    row = await conn.fetchrow(
                        "INSERT INTO users (email, password_hash, name, "
                        "role, tenant_id) VALUES ($1,$2,$3,$4,$5) "
                        "RETURNING user_id, active",
                        DALLAS_OWNER["email"], pw, DALLAS_OWNER["name"],
                        DALLAS_OWNER["role"], DALLAS_OWNER["tenant_id"])
                    # ⚠ CARRY EVERY FIELD THE OWNERS FILTER READS.
                    # The first cut merged only email and tenant_id, so
                    # the new account had no `role` in this dict, failed
                    # the dso_owner test three blocks down, and its
                    # ownership grant did not happen until the script
                    # was run a second time. Idempotent covered it; one
                    # pass has to be enough.
                    active[DALLAS_OWNER["email"]] = {**DALLAS_OWNER,
                                                     "user_id": row["user_id"]}
            else:
                plan.append(f"keep   user {DALLAS_OWNER['email']} "
                            f"(already exists)")

            # ── 2. Retire the duplicate ──────────────────────────────
            dup = active.get(RETIRE)
            if dup:
                plan.append(f"DEACTIVATE user {RETIRE} "
                            f"(merged into {SURVIVES})")
                if apply:
                    await conn.execute(
                        "SELECT set_config('app.tenant_id', $1, true)",
                        dup["tenant_id"])
                    await conn.execute(
                        "UPDATE users SET active = false WHERE email = $1",
                        RETIRE)
                # Dropped from the in-memory set whether or not we are
                # writing, so a dry run shows the plan AFTER the merge.
                # Leaving it in made the preview offer to grant
                # tampa_smiles to the account being retired.
                active.pop(RETIRE, None)
            else:
                plan.append(f"keep   user {RETIRE} (already inactive)")

            # ── 3. Ownership ─────────────────────────────────────────
            owners = [u for u in active.values()
                      if u.get("role") == "dso_owner" and u.get("tenant_id")]
            owners.sort(key=lambda u: u["email"])

            grants: list[tuple[str, str, str]] = []
            for o in owners:
                wanted = [o["tenant_id"], *EXTRA_OWNERSHIP.get(o["email"], [])]
                for tenant in dict.fromkeys(wanted):  # dedupe, keep order
                    grants.append((o["user_id"], o["email"], tenant))

            for user_id, email, tenant in grants:
                # WITH CHECK on the policy means the connection has to be
                # bound to the tenant being granted. Set it per row.
                await conn.execute(
                    "SELECT set_config('app.tenant_id', $1, true)", tenant)
                exists = await conn.fetchval(
                    "SELECT 1 FROM tenant_ownership "
                    "WHERE user_id = $1 AND tenant_id = $2", user_id, tenant)
                if exists:
                    plan.append(f"keep   own  {email:34} {tenant}")
                    continue
                plan.append(f"GRANT  own  {email:34} {tenant}")
                if apply:
                    await conn.execute(
                        "INSERT INTO tenant_ownership (user_id, tenant_id) "
                        "VALUES ($1, $2) ON CONFLICT DO NOTHING",
                        user_id, tenant)

            if not apply:
                raise _Rollback()
    except _Rollback:
        pass
    finally:
        await conn.close()

    for line in plan:
        print("  " + line)
    print(f"\n{'APPLIED' if apply else 'DRY RUN — pass --apply to write'}")
    return 0


class _Rollback(Exception):
    """Abort the transaction on a dry run so nothing is written."""


if __name__ == "__main__":
    sys.exit(asyncio.run(main("--apply" in sys.argv)))
