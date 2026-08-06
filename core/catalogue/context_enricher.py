"""
ContextEnricher — the catalogue gateway (CONTEXT.md RULE 4).

The enricher holds the DB connection, calls rule_loader, and attaches
the resolved rules to the PredContext. A persona reads them off the
context and never touches the catalogue itself — that is what keeps
personas sync and DB-less (RULE 5), and what makes persona_bundles a
faithful record of exactly what the persona saw (RULE 10).

Call order for one pre-D:

    ctx = await ContextBuilder(sim_pool).build(pred_request_id)
    ctx = await ContextEnricher(sim_pool).enrich(ctx)
    # ctx.catalogue_rules is now populated; run the waves.
"""
from __future__ import annotations

import logging
import time

import asyncpg

from core.catalogue.rule_loader import load_dental_rules
from core.context.pred_context import PredContext
from core.db.connection import DEFAULT_TENANT

logger = logging.getLogger(__name__)


class ContextEnricher:
    def __init__(self, pool: asyncpg.Pool):
        self.pool = pool

    async def enrich(
        self,
        context: PredContext,
        tenant_id: str = DEFAULT_TENANT,
    ) -> PredContext:
        """
        Load catalogue rules and attach them to the context.

        Called once per pre-D, before wave execution. After this returns,
        the personas have everything they need.

        The payer comes off the context rather than a parameter — the
        rules that matter are the ones governing THIS pre-D's plan, and
        DA-C06/C07 exist precisely because Cigna and MetLife differ from
        Delta on the same CDT codes.
        """
        started = time.perf_counter()

        async with self.pool.acquire() as conn:
            async with conn.transaction():
                await conn.execute("SET TRANSACTION READ ONLY")
                await conn.execute(
                    "SELECT set_config('app.tenant_id', $1, true)", tenant_id
                )
                rules = await load_dental_rules(
                    conn,
                    tenant_id=tenant_id,
                    payer_id=context.payer_id or "delta_dental",
                )

        elapsed_ms = int((time.perf_counter() - started) * 1000)
        rules["_meta"]["load_ms"] = elapsed_ms
        rules["_meta"]["pred_request_id"] = context.pred_request_id

        context.catalogue_rules = rules

        missing = rules["_meta"].get("missing_sections") or []
        if missing:
            logger.warning(
                "Enriched %s with EMPTY catalogue sections: %s. Personas will "
                "fall back to SAFE_DEFAULTS for those.",
                context.pred_request_id,
                ", ".join(missing),
            )

        logger.info(
            "Enriched %s (payer=%s) in %dms: %d ADA, %d bundling, %d frequency, "
            "%d downgrade, %d CDT, %d conditions, %d flags, %d overlay",
            context.pred_request_id,
            context.payer_id,
            elapsed_ms,
            len(rules.get("ada_thresholds", {})),
            len(rules.get("bundling_rules", {})),
            len(rules.get("frequency_limits", {})),
            len(rules.get("downgrade_matrix", {})),
            len(rules.get("cdt_rules", {})),
            len(rules.get("conditions_library", {})),
            len(rules.get("medical_history_flags", {})),
            len(rules.get("overlay_rules", {}).get("rules", {})),
        )
        return context
