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

When dental-os grows its own tables (decision_outputs, persona_bundles,
provider_feedback, appeal_packets — migrations/002) those writes need a
SEPARATE pool and a separate helper. Do not relax the read-only flag
here to make a write work; that is the guardrail doing its job.
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


async def close_pool() -> None:
    global _pool
    if _pool is not None:
        await _pool.close()
        _pool = None


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
