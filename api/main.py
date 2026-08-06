"""
Accord Dental OS — FastAPI application.

    uvicorn api.main:app --port 9010

TWO POOLS, opened once at startup and stashed on app.state:

    simulator_pool  DATABASE_URL           -> dental      READ-ONLY
    os_pool         DENTAL_OS_DATABASE_URL -> dental_os   READ-WRITE

They are separate DATABASES, not separate schemas, which is what makes
CONTEXT.md RULE 15 a boundary rather than a convention — a dental-os
write physically cannot reach a dental-simulator table. get_os_pool()
refuses to start if the two DSNs are equal.

Pools are opened in a lifespan handler rather than per request: asyncpg
pool creation costs a TLS handshake per connection, and doing that on a
request path would put ~200ms of setup in front of a 40ms read.
"""
from __future__ import annotations

import logging
import os
from contextlib import asynccontextmanager

from dotenv import load_dotenv
from fastapi import FastAPI, Request

from api.routes import router
from api.schemas import HealthResponse
from core.db.connection import (
    DEFAULT_TENANT,
    close_pool,
    execute_os_with_tenant,
    fetch_with_tenant,
    get_os_pool,
    get_pool,
)

load_dotenv()

logging.basicConfig(
    level=os.environ.get("LOG_LEVEL", "WARNING"),
    format="%(asctime)s %(levelname)s %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)

VERSION = "0.3.0"
SERVICE = "accord-dental-os"


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.tenant_id = DEFAULT_TENANT
    app.state.simulator_pool = await get_pool()
    app.state.os_pool = await get_os_pool()
    logger.info("pools open — tenant=%s", app.state.tenant_id)
    try:
        yield
    finally:
        await close_pool()
        app.state.simulator_pool = None
        app.state.os_pool = None


app = FastAPI(
    title="Accord Dental OS",
    version=VERSION,
    description=(
        "Dental pre-determination intelligence. dental-simulator's policy "
        "engine already decided; this API explains the decision and tells a "
        "human what to do next. AI DECIDES NOTHING — every output is "
        "recommend or human_approval."
    ),
    lifespan=lifespan,
)

app.include_router(router)


@app.get("/health", response_model=HealthResponse)
async def health(request: Request) -> HealthResponse:
    """Liveness plus the four counts worth knowing at a glance.

    Each side is probed independently so a half-up service reports which
    half. A count that cannot be read comes back None rather than 0 —
    zero is a real and very different answer, and conflating them is the
    RLS trap in miniature (CONTEXT.md: a missing tenant returns 0 rows
    with no error).
    """
    tenant = getattr(request.app.state, "tenant_id", DEFAULT_TENANT)
    sim_pool = getattr(request.app.state, "simulator_pool", None)
    os_pool = getattr(request.app.state, "os_pool", None)

    scenarios = tenant_count = payers = states = None
    tenant_ids: list[str] = []
    simulator_db = "unavailable"
    if sim_pool is not None:
        try:
            # pred_requests is RLS-scoped, so count(*) under one tenant
            # returns THAT PRACTICE'S pre-Ds, not the deployment's. Sum
            # across the tenant directory instead — otherwise /health
            # would have reported 40 while 50 existed.
            rows = await fetch_with_tenant(
                sim_pool, tenant,
                "SELECT tenant_id FROM tenants WHERE active ORDER BY tenant_id")
            tenant_ids = [r["tenant_id"] for r in rows]
            tenant_count = len(tenant_ids)

            scenarios = 0
            for t in tenant_ids:
                got = await fetch_with_tenant(
                    sim_pool, t,
                    "SELECT count(*) AS n FROM pred_requests WHERE tenant_id = $1",
                    t)
                scenarios += got[0]["n"] if got else 0

            # payers and fee_schedules are global catalogues — no
            # tenant_id, no RLS — so one read covers the deployment.
            got = await fetch_with_tenant(
                sim_pool, tenant,
                "SELECT (SELECT count(*) FROM payers) AS p,"
                "       (SELECT count(DISTINCT state) FROM fee_schedules) AS s")
            payers = got[0]["p"]
            states = got[0]["s"]
            simulator_db = "connected"
        except Exception as exc:  # noqa: BLE001 — health never raises
            logger.warning("simulator probe failed: %s", exc)
            simulator_db = f"error: {type(exc).__name__}"

    decision_outputs = persona_bundles = None
    os_db = "unavailable"
    if os_pool is not None:
        try:
            # decision_outputs and persona_bundles are FORCE RLS in the
            # dental_os database too (migrations/002), so this has to sum
            # per tenant for exactly the same reason as above. Falls back
            # to the app default when the tenant directory was unreadable.
            probe_tenants = tenant_ids if tenant_count else [tenant]
            decision_outputs = persona_bundles = 0
            for t in probe_tenants:
                rows = await execute_os_with_tenant(
                    os_pool, t,
                    "SELECT (SELECT count(*) FROM decision_outputs) AS d,"
                    "       (SELECT count(*) FROM persona_bundles)  AS p",
                )
                decision_outputs += rows[0]["d"]
                persona_bundles += rows[0]["p"]
            os_db = "connected"
        except Exception as exc:  # noqa: BLE001
            logger.warning("os probe failed: %s", exc)
            os_db = f"error: {type(exc).__name__}"

    healthy = simulator_db == "connected" and os_db == "connected"
    return HealthResponse(
        status="healthy" if healthy else "degraded",
        service=SERVICE,
        version=VERSION,
        tenants=tenant_count,
        simulator_scenarios=scenarios,
        decision_outputs=decision_outputs,
        persona_bundles=persona_bundles,
        payers_supported=payers,
        states_supported=states,
        simulator_db=simulator_db,
        os_db=os_db,
    )
