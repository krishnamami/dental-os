"""
Read-only connection pool to dental-simulator RDS.

Always SET app.tenant_id before querying — RLS will return 0 rows
indistinguishably from an empty table without it.

dental-os NEVER writes to dental-simulator tables (CONTEXT.md RULE 15).
Two things enforce that here rather than leaving it to good intentions:

  1. The DSN uses `dental_app`, which is a non-owner and cannot DDL.
  2. Every query issued through fetch_with_tenant() runs inside a
     transaction marked SET TRANSACTION READ ONLY, so an INSERT or
     UPDATE that slipped into a query string raises rather than
     committing.

dental-os's own tables (decision_outputs, persona_bundles,
provider_feedback, appeal_packets — migrations/002) live in a SEPARATE
database, `dental_os`, reached through get_os_pool() and written through
execute_os_with_tenant(). Do not relax the read-only flag here to make a
write work; that is the guardrail doing its job — write to the other
pool instead.

    DATABASE_URL            -> dental      READ-ONLY   dental-simulator
    DENTAL_OS_DATABASE_URL  -> dental_os   READ-WRITE  dental-os

Both databases enforce RLS, so both helpers set app.tenant_id inside a
transaction. That `is_local => true` scoping is not optional: outside a
transaction the setting is discarded immediately and every subsequent
read returns 0 rows with no error.
"""
from __future__ import annotations

import os
from typing import Any, Optional

import asyncpg
from dotenv import load_dotenv

load_dotenv()

# The tenant every query in this repo runs as today. Passed explicitly
# rather than defaulted inside the helpers, so a missing tenant is a
# TypeError at the call site instead of a silent cross-tenant read.
DEFAULT_TENANT = "suwanee_smiles"

_pool: Optional[asyncpg.Pool] = None
_os_pool: Optional[asyncpg.Pool] = None
_admin_pool: Optional[asyncpg.Pool] = None


async def get_pool() -> asyncpg.Pool:
    """Process-wide pool. Created once, reused for the life of the app."""
    global _pool
    if _pool is None:
        dsn = os.environ.get("DATABASE_URL")
        if not dsn:
            raise RuntimeError(
                "DATABASE_URL is not set. Copy .env.example to .env and point "
                "it at the dental-simulator RDS. Note that dental-simulator's "
                "own .env points at localhost:5434, which holds a stale copy "
                "of an OLD pipeline run — see CONTEXT.md."
            )
        _pool = await asyncpg.create_pool(
            dsn=dsn,
            min_size=2,
            max_size=10,
            command_timeout=30,
        )
    return _pool


async def get_os_pool() -> asyncpg.Pool:
    """Pool for dental-os's OWN tables in the `dental_os` database.

    This is the ONLY pool that may write. It is a different database on
    the same RDS instance, so a dental-os write physically cannot touch
    a dental-simulator table (RULE 15). The trade-off is that there is
    no cross-database JOIN — join in Python on pred_request_id.
    """
    global _os_pool
    if _os_pool is None:
        dsn = os.environ.get("DENTAL_OS_DATABASE_URL")
        if not dsn:
            raise RuntimeError(
                "DENTAL_OS_DATABASE_URL is not set. It points at the "
                "`dental_os` database (dental-os's own tables), NOT at "
                "`dental` (dental-simulator, read-only). Apply "
                "migrations/002_dental_os_tables.sql if the database does "
                "not exist yet."
            )
        if dsn == os.environ.get("DATABASE_URL"):
            raise RuntimeError(
                "DENTAL_OS_DATABASE_URL and DATABASE_URL point at the SAME "
                "database. dental-os would then be writing into "
                "dental-simulator, which RULE 15 forbids. The read pool "
                "ends in /dental; the write pool ends in /dental_os."
            )
        _os_pool = await asyncpg.create_pool(
            dsn=dsn,
            min_size=1,
            max_size=5,
            command_timeout=30,
        )
    return _os_pool


async def get_admin_pool() -> asyncpg.Pool:
    """Elevated read pool for cross-tenant aggregates.

    ⚠ IT DOES NOT BYPASS RLS ON THIS DATABASE, and nothing in dental-os
    should be written as though it does. Measured against the live RDS:

        pred_requests / pred_states / cost_estimates
            relrowsecurity = true, relforcerowsecurity = TRUE
        dental_admin
            rolsuper = false, rolbypassrls = FALSE

    FORCE row-level security binds the table OWNER as well, and only a
    superuser or a role holding BYPASSRLS escapes it. `dental_admin`
    owns these tables and holds neither, so connecting as admin returns
    exactly the same single-tenant slice as `dental_app` — while
    handing the caller DDL rights it has no use for.

    A cross-tenant aggregate therefore has to iterate tenants and set
    app.tenant_id for each. That is what
    DSOPortfolioManager.aggregate_all_tenants does, and it needs no
    elevated credential at all.

    This helper exists so the seam is named and configurable: if the
    tables are ever moved off FORCE, or a BYPASSRLS reporting role is
    created, the aggregate switches to a single query by pointing
    DENTAL_ADMIN_DATABASE_URL at it. Until then it falls back to
    DATABASE_URL and is functionally the read pool.

    NEVER use this for per-patient reads. The aggregate view is the
    only justification for an elevated role, and it is a weak one while
    the fallback is the ordinary pool.
    """
    global _admin_pool
    if _admin_pool is None:
        dsn = os.environ.get("DENTAL_ADMIN_DATABASE_URL")
        if not dsn:
            # Deliberate fallback, not a silent downgrade: the aggregate
            # works either way, so a missing admin DSN must not take the
            # portfolio endpoint down.
            dsn = os.environ.get("DATABASE_URL")
        if not dsn:
            raise RuntimeError(
                "Neither DENTAL_ADMIN_DATABASE_URL nor DATABASE_URL is set."
            )
        _admin_pool = await asyncpg.create_pool(
            dsn=dsn, min_size=1, max_size=3, command_timeout=30,
        )
    return _admin_pool


async def execute_os_with_tenant(
    pool: asyncpg.Pool,
    tenant_id: str,
    query: str,
    *args: Any,
) -> list[dict]:
    """Write (or read) dental-os's own tables under RLS tenant context.

    Read-write by design — the counterpart to fetch_with_tenant. Use
    RETURNING to get rows back. The transaction is mandatory for the
    same reason as on the read side: is_local=true dies with it, and
    the WITH CHECK clause on every policy would then reject the insert.
    """
    async with pool.acquire() as conn:
        async with conn.transaction():
            await conn.execute(
                "SELECT set_config('app.tenant_id', $1, true)", tenant_id
            )
            rows = await conn.fetch(query, *args)
    return [dict(r) for r in rows]


async def close_pool() -> None:
    global _pool, _os_pool, _admin_pool
    if _pool is not None:
        await _pool.close()
        _pool = None
    if _os_pool is not None:
        await _os_pool.close()
        _os_pool = None
    if _admin_pool is not None:
        await _admin_pool.close()
        _admin_pool = None


async def fetch_with_tenant(
    pool: asyncpg.Pool,
    tenant_id: str,
    query: str,
    *args: Any,
) -> list[dict]:
    """
    Execute SELECT with RLS tenant context.

    All dental-os queries MUST go through this function.
    Never query dental-simulator without tenant context.

    set_config(..., is_local=true) scopes the setting to this
    transaction, so a pooled connection handed to the next caller never
    carries a stale tenant. That is the whole reason for the explicit
    transaction — without it the setting would leak across borrowers of
    the same connection.
    """
    async with pool.acquire() as conn:
        async with conn.transaction():
            await conn.execute("SET TRANSACTION READ ONLY")
            await conn.execute(
                "SELECT set_config('app.tenant_id', $1, true)",
                tenant_id,
            )
            rows = await conn.fetch(query, *args)
    return [dict(r) for r in rows]


async def fetchrow_with_tenant(
    pool: asyncpg.Pool,
    tenant_id: str,
    query: str,
    *args: Any,
) -> Optional[dict]:
    rows = await fetch_with_tenant(pool, tenant_id, query, *args)
    return rows[0] if rows else None


async def fetchval_with_tenant(
    pool: asyncpg.Pool,
    tenant_id: str,
    query: str,
    *args: Any,
) -> Any:
    """Single scalar. Returns None when the query yields no rows."""
    row = await fetchrow_with_tenant(pool, tenant_id, query, *args)
    if row is None:
        return None
    return next(iter(row.values()), None)
