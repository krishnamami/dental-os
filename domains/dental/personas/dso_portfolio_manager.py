"""
T-29 — DSO portfolio manager. Wave 5, recommend, dso_manager.

ADVISORY ONLY. Never blocks an individual pre-D — that is a hard rule
in decisions.yaml (portfolio_never_blocks_a_case), and every signal
here is mode='recommend' by construction.

Requires an aggregate that a single-pre-D request does not carry. When
portfolio_stats is empty the persona says so and stops, rather than
computing a denial rate from one case.
"""
from __future__ import annotations

import json
from typing import Any

from domains.dental.personas.base import DentalPersona

DENIAL_RATE_THRESHOLD = 0.15
PAYER_GAP_THRESHOLD = 0.15


def _rows(value: Any) -> list[dict]:
    """JSONB aggregate -> list of dicts.

    portfolio_stats is handed in by whatever loaded it, and asyncpg
    returns JSONB as a str unless a codec is registered. Coerce here
    rather than trusting the caller: a persona that raises takes down
    its wave, and this one is advisory — it must never be the reason a
    pre-D stalls.
    """
    if value is None:
        return []
    if isinstance(value, str):
        try:
            value = json.loads(value)
        except (ValueError, TypeError):
            return []
    if isinstance(value, dict):
        return [value]
    return [v for v in value if isinstance(v, dict)] if isinstance(value, list) else []


class DSOPortfolioManager(DentalPersona):
    decision_id = "dso_portfolio_manager"
    persona_name = "DSO Portfolio Manager"
    wave = 5
    mode = "recommend"
    risk_level = "low"
    owner_team = "dso_manager"

    def _compute_offline(self, context: Any) -> list[dict]:
        stats = getattr(context, "portfolio_stats", None) or {}

        if not stats:
            return [self.make_signal(
                "PORTFOLIO_UNAVAILABLE",
                "Portfolio analytics need the aggregate across all pre-Ds, "
                "which this single-pre-D request does not carry. Populate "
                "context.portfolio_stats from vw_portfolio_context to enable "
                "this view.",
                mode="recommend",
                data={"reason": "portfolio_stats not populated"},
            )]

        total = stats.get("total_pred_requests") or 0
        denied = stats.get("denied_count") or 0
        pended = stats.get("pended_count") or 0
        approved = stats.get("approved_count") or 0
        signals: list[dict] = []

        denial_rate = round(denied / total, 4) if total else None
        first_pass = stats.get("first_pass_approval_rate")

        # ── Denial pattern ───────────────────────────────────────────
        top_conditions = _rows(stats.get("denial_by_condition"))
        top = top_conditions[0] if top_conditions else {}
        if denial_rate is not None and denial_rate > DENIAL_RATE_THRESHOLD:
            signals.append(self.make_signal(
                "PORTFOLIO_DENIAL_PATTERN",
                f"{denied} of {total} pre-Ds denied ({denial_rate:.1%}), plus "
                f"{pended} pended. The most frequent open condition is "
                f"{top.get('condition_code', 'unknown')} "
                f"({top.get('n', 0)} occurrences).",
                mode="recommend",
                data={
                    "denial_rate": denial_rate,
                    "denied_count": denied,
                    "pended_count": pended,
                    "approved_count": approved,
                    "total": total,
                    "top_denied_condition": top.get("condition_code"),
                    "top_conditions": top_conditions[:5],
                },
            ))

        # ── Revenue at risk ──────────────────────────────────────────
        at_risk = stats.get("revenue_at_risk")
        if at_risk:
            billed = stats.get("total_billed") or 0
            signals.append(self.make_signal(
                "PORTFOLIO_REVENUE_AT_RISK",
                f"${float(at_risk):,.2f} of ${float(billed):,.2f} billed sits "
                f"on denied pre-Ds. Documentation-driven appeals recover "
                f"roughly 65% of the bundling subset.",
                mode="recommend",
                data={
                    "revenue_at_risk": float(at_risk),
                    "total_billed": float(billed),
                    "total_insurance_pays": float(stats.get("total_insurance_pays") or 0),
                    "total_patient_pays": float(stats.get("total_patient_pays") or 0),
                    "first_pass_approval_rate": first_pass,
                },
            ))

        # ── Payer performance ────────────────────────────────────────
        by_payer = _rows(stats.get("denial_by_payer"))
        rates = []
        for p in by_payer:
            n = p.get("total") or 0
            if n:
                rates.append((p.get("payer_id"), round((p.get("denied") or 0) / n, 4), n))
        if len(rates) > 1:
            rates.sort(key=lambda r: -r[1])
            worst, best = rates[0], rates[-1]
            if worst[1] - best[1] > PAYER_GAP_THRESHOLD:
                signals.append(self.make_signal(
                    "PORTFOLIO_PAYER_PERFORMANCE",
                    f"{worst[0]} denies {worst[1]:.1%} of pre-Ds against "
                    f"{best[0]} at {best[1]:.1%}. The gap is where "
                    f"payer-specific documentation templates pay for "
                    f"themselves.",
                    mode="recommend",
                    data={"by_payer": [
                        {"payer_id": p, "denial_rate": r, "volume": n}
                        for p, r, n in rates
                    ]},
                ))

        # ── Training — always ────────────────────────────────────────
        low_conf = stats.get("low_confidence_doc_count") or 0
        avg_conf = stats.get("avg_extraction_confidence")
        signals.append(self.make_signal(
            "PORTFOLIO_TRAINING_NEEDED",
            f"Highest-yield training target is "
            f"{top.get('condition_code', 'documentation completeness')} "
            f"({top.get('n', 0)} occurrences across {total} pre-Ds)."
            + (f" {low_conf} document(s) extracted below the trust floor "
               f"(average confidence {avg_conf})." if low_conf else ""),
            mode="recommend",
            data={
                "top_condition": top.get("condition_code"),
                "occurrences": top.get("n"),
                "low_confidence_doc_count": low_conf,
                "avg_extraction_confidence": (
                    float(avg_conf) if avg_conf is not None else None),
                "avg_criteria_score": (
                    float(stats["avg_criteria_score"])
                    if stats.get("avg_criteria_score") is not None else None),
            },
        ))
        return signals

    # ── Cross-tenant roll-up (Sprint 2) ──────────────────────────────

    @classmethod
    async def aggregate_all_tenants(
        cls, pool: Any, tenants: Optional[list[str]] = None
    ) -> dict:
        """Every practice in the DSO group, in one result.

        THE ONE PLACE dental-os LOOKS ACROSS TENANTS. Everything else in
        this repo is scoped to a single practice; this answers the
        question a DSO operator asks that a practice never does — which
        of my locations is losing money, and to what.

        It is async and it takes a pool, which is the opposite of RULE 5
        (personas are sync and DB-less). That rule governs
        `_compute_offline`, the decision path — a persona must not reach
        for data mid-decision, because persona_bundles has to be a
        faithful record of what it saw. This is a reporting classmethod
        on the same class for cohesion; it emits no signals, gates no
        pre-D, and is never called from a wave.

        ── WHY THIS ITERATES INSTEAD OF RUNNING ONE QUERY ──────────────
        The obvious implementation is a single GROUP BY over
        pred_requests joined to tenants, run as dental_admin to "bypass
        RLS". That does not work on this database, and the reason is
        worth writing down so nobody tries it again:

            pred_requests, pred_states, cost_estimates
                relforcerowsecurity = TRUE
            dental_admin
                rolsuper = false, rolbypassrls = false

        FORCE row-level security binds the table owner too. Only a
        superuser or a BYPASSRLS role escapes it, and dental_admin is
        neither — so a cross-tenant query returns whatever single tenant
        app.tenant_id happens to name, or nothing at all. It would not
        error. It would quietly report one practice as the whole group.

        So the loop below sets app.tenant_id per tenant and aggregates
        in Python. It needs no elevated credential, which also means the
        DSO view cannot become the reason a DDL-capable password gets
        deployed.

        `tenants` defaults to every row in the tenants table — which is
        NOT RLS-protected (relrowsecurity = false), being a directory of
        practices rather than patient data. That is the one legitimate
        cross-tenant read on this database.
        """
        from datetime import datetime, timezone

        async def scoped(tenant: str, sql: str, *args) -> list[dict]:
            async with pool.acquire() as conn:
                async with conn.transaction():
                    await conn.execute("SET TRANSACTION READ ONLY")
                    await conn.execute(
                        "SELECT set_config('app.tenant_id', $1, true)", tenant)
                    return [dict(r) for r in await conn.fetch(sql, *args)]

        if tenants is None:
            async with pool.acquire() as conn:
                rows = await conn.fetch(
                    "SELECT tenant_id FROM tenants WHERE active "
                    "ORDER BY tenant_id")
            tenants = [r["tenant_id"] for r in rows]

        practices: list[dict] = []
        denial_counts: dict[tuple[str, str], int] = {}

        for tenant in tenants:
            rows = await scoped(tenant, """
                SELECT pr.tenant_id,
                       t.name    AS practice_name,
                       t.address AS address,
                       COUNT(*)                                        AS total_pre_ds,
                       COUNT(*) FILTER (WHERE ps.decision = 'approved') AS approved,
                       COUNT(*) FILTER (WHERE ps.decision = 'denied')   AS denied,
                       COUNT(*) FILTER (WHERE ps.decision = 'pended')   AS pended,
                       ROUND(AVG(ps.criteria_score)::numeric, 3)        AS avg_score,
                       SUM(ce.total_contracted)                         AS total_contracted,
                       SUM(ce.total_insurance)                          AS total_insurance,
                       SUM(ce.total_patient)                            AS total_patient
                FROM pred_requests pr
                JOIN pred_states ps ON ps.pred_request_id = pr.pred_request_id
                JOIN tenants t      ON t.tenant_id = pr.tenant_id
                LEFT JOIN (
                    SELECT pred_request_id,
                           SUM(allowed_amount) AS total_contracted,
                           SUM(insurance_pays) AS total_insurance,
                           SUM(patient_pays)   AS total_patient
                    FROM cost_estimates
                    GROUP BY pred_request_id
                ) ce ON ce.pred_request_id = pr.pred_request_id
                WHERE pr.tenant_id = $1
                GROUP BY pr.tenant_id, t.name, t.address
            """, tenant)
            practices.extend(rows)

            # open_conditions is JSONB, not a text[] — jsonb_array_elements_text,
            # not unnest(). unnest() raises "function unnest(jsonb) does not
            # exist" rather than returning nothing, so this one fails loudly.
            for r in await scoped(tenant, """
                SELECT cond.value       AS condition_code,
                       pr.tenant_id     AS tenant_id,
                       COUNT(*)         AS frequency
                FROM pred_states ps
                JOIN pred_requests pr ON pr.pred_request_id = ps.pred_request_id
                CROSS JOIN LATERAL jsonb_array_elements_text(
                    COALESCE(ps.open_conditions, '[]'::jsonb)) AS cond
                WHERE ps.decision IN ('denied', 'pended')
                  AND pr.tenant_id = $1
                GROUP BY cond.value, pr.tenant_id
            """, tenant):
                key = (r["condition_code"], r["tenant_id"])
                denial_counts[key] = denial_counts.get(key, 0) + r["frequency"]

        top_denials = [
            {"condition_code": code, "tenant_id": tenant, "frequency": n}
            for (code, tenant), n in sorted(
                denial_counts.items(), key=lambda kv: -kv[1])[:20]
        ]

        return {
            "tenants": practices,
            "top_denial_reasons": top_denials,
            "generated_at": datetime.now(timezone.utc).isoformat(),
        }
