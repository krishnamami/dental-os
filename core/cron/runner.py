"""
T-30 + T-31 — PersonaRunner. Five waves, one pre-D, nine decisions.

Mirrors decision-os core/cron/runner.py: the runner owns every async
thing — pools, transactions, wave ordering, the audit write — so a
persona can stay sync and DB-less (CONTEXT.md RULE 5).

    ctx = ContextBuilder(sim_pool).build()   ← reads dental-simulator
    ctx = ContextEnricher(sim_pool).enrich() ← attaches the catalogue
    waves 1..5, each waiting for the last
    decision_outputs THEN persona_bundles    ← RULE 10, one transaction

THE RUNNER DECIDES NOTHING. It never inspects a signal to change a
verdict, never overrides a persona, and never suppresses one. It orders
execution, moves outputs between waves, and writes what came back. The
only branch it takes on content is Wave 5's `only_if` gate, which is
declared in decisions.yaml rather than inferred here.

── Two reads of the spec that the schema settles ────────────────────

`decision_outputs` has no unique constraint on
(pred_request_id, decision_id) and the migration says why: "append-only
and versioned: a re-run adds a row, never mutates one". So this writes
plain INSERTs. An UPSERT would need a new constraint and would silently
destroy the prior run's audit trail — the opposite of what the table is
for. `persona_bundles` carries the versioning instead: prior bundles for
the pre-D are flipped is_current=false and the new one takes version+1.

Wave 1 is described as "parallel, no dependencies". Personas are sync,
so there is no concurrency to gain — but parallelism has a semantic
consequence worth keeping: no Wave 1 persona may read another Wave 1
persona's output. Outputs are therefore published to
`upstream_outputs` at the END of each wave, not as each persona
finishes. Publishing eagerly would let persona #3 read persona #1 and
create a dependency the DAG does not declare.
"""
from __future__ import annotations

import json
import logging
import time
import uuid
from typing import Any, Optional

import asyncpg

from core.catalogue.context_enricher import ContextEnricher
from core.context.context_builder import ContextBuilder
from core.context.pred_context import PredContext
from core.db.connection import DEFAULT_TENANT, fetch_with_tenant
from domains.dental.personas import (
    AppealSpecialist,
    ClinicalReviewer,
    CoverageAnalyst,
    DSOPortfolioManager,
    DocumentationReviewer,
    EligibilityAnalyst,
    FraudIntegrity,
    PreDAssessment,
    ProviderCredentialing,
)

logger = logging.getLogger(__name__)


# ─────────────────────────────────────────────────────────────────────
# Wave + persona registry
#
# WAVE_CONFIG mirrors decisions.yaml `depends_on` / `wave` / `mode`,
# kept inline so the runner takes no YAML parse on a hot path. The
# persona CLASSES are the real registry — a rename in
# domains/dental/personas/__init__.py becomes an ImportError here
# rather than a silently skipped decision.
# ─────────────────────────────────────────────────────────────────────

WAVE_CONFIG: dict[str, dict[str, Any]] = {
    "eligibility_analyst":    {"wave": 1, "upstream": []},
    "provider_credentialing": {"wave": 1, "upstream": []},
    "fraud_integrity":        {"wave": 1, "upstream": []},
    "coverage_analyst":       {"wave": 2, "upstream": ["eligibility_analyst"]},
    "clinical_reviewer":      {"wave": 2, "upstream": ["provider_credentialing"]},
    "documentation_reviewer": {"wave": 3, "upstream": [
        "coverage_analyst", "clinical_reviewer",
    ]},
    "pre_d_assessment":       {"wave": 4, "upstream": [
        "eligibility_analyst", "provider_credentialing", "fraud_integrity",
        "coverage_analyst", "clinical_reviewer", "documentation_reviewer",
    ]},
    "appeal_specialist":      {"wave": 5, "upstream": ["pre_d_assessment"]},
    # Independent by type, scheduled in wave 5: it reads the aggregate
    # after individual cases settle and never gates one of them.
    "dso_portfolio_manager":  {"wave": 5, "upstream": []},
}

WAVES: tuple[tuple[type, ...], ...] = (
    (EligibilityAnalyst, ProviderCredentialing, FraudIntegrity),
    (CoverageAnalyst, ClinicalReviewer),
    (DocumentationReviewer,),
    (PreDAssessment,),
    (AppealSpecialist, DSOPortfolioManager),
)

# sla_seconds / risk_level / owner_team / mode, kept in sync with
# domains/dental/decisions.yaml. The persona class carries the same
# risk_level and owner_team; _defaults_agree() asserts they match at
# import time so the two copies can never drift apart unnoticed.
DECISION_DEFAULTS: dict[str, dict[str, Any]] = {
    "eligibility_analyst":    {"sla_seconds": 30,  "risk_level": "medium", "owner_team": "front_desk",  "mode": "recommend"},
    "provider_credentialing": {"sla_seconds": 30,  "risk_level": "high",   "owner_team": "billing",     "mode": "human_approval"},
    "fraud_integrity":        {"sla_seconds": 30,  "risk_level": "high",   "owner_team": "billing",     "mode": "human_approval"},
    "coverage_analyst":       {"sla_seconds": 60,  "risk_level": "medium", "owner_team": "billing",     "mode": "recommend"},
    "clinical_reviewer":      {"sla_seconds": 60,  "risk_level": "medium", "owner_team": "dentist",     "mode": "recommend"},
    "documentation_reviewer": {"sla_seconds": 60,  "risk_level": "medium", "owner_team": "front_desk",  "mode": "recommend"},
    "pre_d_assessment":       {"sla_seconds": 120, "risk_level": "high",   "owner_team": "billing",     "mode": "human_approval"},
    "appeal_specialist":      {"sla_seconds": 60,  "risk_level": "high",   "owner_team": "billing",     "mode": "human_approval"},
    "dso_portfolio_manager":  {"sla_seconds": 60,  "risk_level": "low",    "owner_team": "dso_manager", "mode": "recommend"},
}

# Wave 5 `only_if` from decisions.yaml: appeal_specialist runs only on a
# denied or pended payer decision. An approved pre-D has nothing to
# appeal, so it gets 8 decision_outputs rows rather than 9.
APPEAL_DECISIONS = ("denied", "pended")

# decisions.yaml block_if, for the `outcome` column only. This does NOT
# change a signal or gate a persona — it is a label on the row so a
# reviewer can filter decision_outputs without re-parsing signals JSONB.
BLOCK_CODES = frozenset({
    "PRED_BLOCKED_FRAUD", "PRED_BLOCKED_CLINICAL", "PRED_BLOCKED_PROVIDER",
    "PROVIDER_OIG_EXCLUDED", "ELIG_COVERAGE_INACTIVE",
    "ELIG_IMPLANTS_NOT_COVERED",
})


def _defaults_agree() -> None:
    """decisions.yaml, DECISION_DEFAULTS and the persona class all carry
    risk_level + owner_team. Two copies drift; three copies drift
    faster. Fail at import rather than write a mislabelled audit row."""
    for wave in WAVES:
        for cls in wave:
            want = DECISION_DEFAULTS[cls.decision_id]
            for attr in ("risk_level", "owner_team", "mode"):
                if getattr(cls, attr) != want[attr]:
                    raise AssertionError(
                        f"{cls.__name__}.{attr}={getattr(cls, attr)!r} but "
                        f"DECISION_DEFAULTS says {want[attr]!r}. One of them "
                        f"disagrees with domains/dental/decisions.yaml."
                    )
            if cls.wave != WAVE_CONFIG[cls.decision_id]["wave"]:
                raise AssertionError(
                    f"{cls.__name__}.wave={cls.wave} but WAVE_CONFIG says "
                    f"{WAVE_CONFIG[cls.decision_id]['wave']}."
                )


_defaults_agree()


def _outcome(signals: list[dict]) -> str:
    """recommend | escalate | block — the decision_outputs label.

    Read off what the persona already emitted. The runner is not
    allowed a view of its own (AI DECIDES NOTHING), so this is a
    projection of the signals, never a judgement about them.
    """
    codes = {s.get("signal_code") for s in signals}
    if codes & BLOCK_CODES:
        return "block"
    if any(s.get("mode") == "human_approval" for s in signals):
        return "escalate"
    return "recommend"


def _stringify_keys(value: Any) -> Any:
    """Make a dict JSON-serialisable when its keys are tuples.

    rule_loader keys coverage_rules, frequency_limits, downgrade_matrix
    and bundling_rules by (payer_id, cdt_code) and fee_schedules by
    (payer_id, cdt_code, state) — JSON has no tuple key, so json.dumps
    raises TypeError on the raw catalogue. Joined with '|' so a replay
    can split the key back apart:

        ('delta_dental', 'D6010')  ->  'delta_dental|D6010'
    """
    if isinstance(value, dict):
        return {
            ("|".join(str(part) for part in k) if isinstance(k, tuple)
             else str(k)): _stringify_keys(v)
            for k, v in value.items()
        }
    if isinstance(value, (list, tuple)):
        return [_stringify_keys(v) for v in value]
    return value


def _jsonb(value: Any) -> str:
    """asyncpg wants JSONB as text on this pool — no codec is
    registered. default=str carries Decimal and date through."""
    return json.dumps(_stringify_keys(value), default=str)


class PersonaRunner:
    """Run all five waves for one pre-D and write the audit record."""

    def __init__(
        self,
        simulator_pool: asyncpg.Pool,
        os_pool: asyncpg.Pool,
        tenant_id: str = DEFAULT_TENANT,
    ):
        self.simulator_pool = simulator_pool   # READ dental-simulator
        self.os_pool = os_pool                 # WRITE dental-os (RULE 15)
        self.tenant_id = tenant_id
        self.builder = ContextBuilder(simulator_pool)
        self.enricher = ContextEnricher(simulator_pool)
        # The portfolio aggregate is identical for every pre-D in a
        # batch, so it is fetched once and reused. Without it
        # dso_portfolio_manager degrades to PORTFOLIO_UNAVAILABLE.
        self._portfolio_stats: Optional[dict] = None

    # ── Public entry point ───────────────────────────────────────────

    async def run(self, pred_request_id: str) -> dict:
        """Run all waves for one pre-D.

        Returns the bundle of every signal from every persona, and
        writes decision_outputs + persona_bundles to the dental-os DB.
        """
        started = time.perf_counter()

        # STEP 1 — build + enrich. Both read-only, both tenant-scoped.
        context = await self.builder.build(pred_request_id, self.tenant_id)
        context = await self.enricher.enrich(context, self.tenant_id)
        context.portfolio_stats = await self._load_portfolio_stats()

        all_signals: list[dict] = []
        wave_outputs: dict[str, dict] = {}

        # STEP 2-6 — the five waves, each waiting for the last.
        for wave_no, persona_classes in enumerate(WAVES, start=1):
            settled: dict[str, list[dict]] = {}

            for cls in persona_classes:
                if not self._should_run(cls, context):
                    continue
                signals, elapsed_ms = self._run_persona(cls, context)
                settled[cls.decision_id] = signals
                wave_outputs[cls.decision_id] = {
                    "signals": signals,
                    "wave": wave_no,
                    "mode": cls.mode,
                    "outcome": _outcome(signals),
                    "processing_ms": elapsed_ms,
                    "sla_seconds": DECISION_DEFAULTS[cls.decision_id]["sla_seconds"],
                    "sla_breached": elapsed_ms
                    > DECISION_DEFAULTS[cls.decision_id]["sla_seconds"] * 1000,
                }
                all_signals.extend(signals)

            # Publish only after the whole wave has settled — see the
            # module docstring on why this is not done per-persona.
            for decision_id, signals in settled.items():
                context.upstream_outputs[decision_id] = {"signals": signals}

        # STEP 7 — decision_outputs, THEN persona_bundles (RULE 10).
        bundle_id = await self._write_outputs(
            pred_request_id, wave_outputs, all_signals, context
        )

        total_ms = int((time.perf_counter() - started) * 1000)
        logger.info(
            "%s: %d decisions, %d signals, %dms, bundle=%s",
            pred_request_id, len(wave_outputs), len(all_signals),
            total_ms, bundle_id,
        )

        return {
            "pred_request_id": pred_request_id,
            "bundle_id": str(bundle_id),
            "tenant_id": self.tenant_id,
            "total_signals": len(all_signals),
            "decisions_run": len(wave_outputs),
            "wave_outputs": wave_outputs,
            "all_signals": all_signals,
            # Derived from the Wave 4 signal, not from a flag a persona
            # set on the context — pre_d_assessment owns this verdict
            # and the runner only reads it back.
            "submission_ready": self._submission_ready(wave_outputs),
            "processing_ms": total_ms,
            "context": context,
        }

    # ── Wave mechanics ───────────────────────────────────────────────

    def _should_run(self, cls: type, context: PredContext) -> bool:
        """Wave 5 `only_if`. The one content branch the runner takes,
        and it is declared in decisions.yaml, not inferred here."""
        if cls is AppealSpecialist:
            return context.decision in APPEAL_DECISIONS
        return True

    def _run_persona(
        self, cls: type, context: PredContext
    ) -> tuple[list[dict], int]:
        """One persona, timed.

        Calls run(), NOT _compute_offline(). run() carries the
        never-raises guarantee from DentalPersona: a persona that blows
        up returns a *_ERROR signal instead of taking down its wave and
        every wave after it. Going straight to _compute_offline would
        discard exactly the protection the base class exists to provide.
        """
        persona = cls()
        started = time.perf_counter()
        signals = persona.run(context)
        elapsed_ms = int((time.perf_counter() - started) * 1000)
        return signals, elapsed_ms

    @staticmethod
    def _submission_ready(wave_outputs: dict) -> bool:
        pre_d = wave_outputs.get("pre_d_assessment") or {}
        return any(
            s.get("signal_code") == "PRED_READY_TO_SUBMIT"
            for s in pre_d.get("signals", [])
        )

    async def _load_portfolio_stats(self) -> dict:
        """vw_portfolio_context, once per runner.

        dso_portfolio_manager is the only consumer and it reads the
        aggregate across all pre-Ds, which does not change between the
        rows of one batch.
        """
        if self._portfolio_stats is None:
            rows = await fetch_with_tenant(
                self.simulator_pool,
                self.tenant_id,
                "SELECT * FROM vw_portfolio_context",
            )
            self._portfolio_stats = dict(rows[0]) if rows else {}
        return self._portfolio_stats

    # ── Persistence ──────────────────────────────────────────────────

    async def _write_outputs(
        self,
        pred_request_id: str,
        wave_outputs: dict,
        all_signals: list,
        context: PredContext,
    ) -> uuid.UUID:
        """Write to the dental-os database — never dental-simulator.

        RULE 10: decision_outputs first, persona_bundles second, both in
        one transaction. The ordering is the point — the bundle is the
        audit snapshot of a set of outputs that already exist, so a
        crash between them can leave outputs without a bundle but never
        a bundle pointing at outputs that were never written.
        """
        bundle_id = uuid.uuid4()

        async with self.os_pool.acquire() as conn:
            async with conn.transaction():
                # RLS is FORCE on all four tables and every policy has a
                # WITH CHECK — without this the INSERT is rejected, not
                # silently dropped. is_local=true dies with the txn.
                await conn.execute(
                    "SELECT set_config('app.tenant_id', $1, true)",
                    self.tenant_id,
                )

                # ── decision_outputs — one row per decision ──────────
                # Append-only INSERT, no UPSERT: see the module
                # docstring and the migration's own comment.
                for decision_id, output in wave_outputs.items():
                    await conn.execute(
                        """
                        INSERT INTO decision_outputs (
                            pred_request_id, tenant_id, decision_id,
                            wave, mode, outcome, signals, findings,
                            confidence_label, processing_ms, bundle_id
                        ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
                        """,
                        pred_request_id,
                        self.tenant_id,
                        decision_id,
                        output["wave"],
                        output["mode"],
                        output["outcome"],
                        _jsonb(output["signals"]),
                        _jsonb({
                            "signal_count": len(output["signals"]),
                            "signal_codes": [
                                s.get("signal_code") for s in output["signals"]
                            ],
                            "sla_seconds": output["sla_seconds"],
                            "sla_breached": output["sla_breached"],
                        }),
                        context.confidence_label,
                        output["processing_ms"],
                        bundle_id,
                    )

                # ── persona_bundles — AFTER, same transaction ────────
                # Versioned: a re-run supersedes rather than overwrites,
                # so is_current always points at exactly one bundle.
                prior = await conn.fetchval(
                    """
                    SELECT COALESCE(MAX(version), 0) FROM persona_bundles
                    WHERE pred_request_id = $1 AND tenant_id = $2
                    """,
                    pred_request_id, self.tenant_id,
                )
                await conn.execute(
                    """
                    UPDATE persona_bundles SET is_current = false
                    WHERE pred_request_id = $1 AND tenant_id = $2
                      AND is_current
                    """,
                    pred_request_id, self.tenant_id,
                )
                await conn.execute(
                    """
                    INSERT INTO persona_bundles (
                        bundle_id, pred_request_id, tenant_id,
                        bundle_snapshot, rules_snapshot,
                        wave_outputs, all_signals,
                        is_current, version
                    ) VALUES ($1,$2,$3,$4,$5,$6,$7,true,$8)
                    """,
                    bundle_id,
                    pred_request_id,
                    self.tenant_id,
                    _jsonb(self._snapshot(context)),
                    # Without this a replay re-resolves against today's
                    # catalogue and can reach a different answer than
                    # the one a human signed off on.
                    _jsonb(context.catalogue_rules),
                    _jsonb(wave_outputs),
                    _jsonb(all_signals),
                    (prior or 0) + 1,
                )

        return bundle_id

    @staticmethod
    def _snapshot(context: PredContext) -> dict:
        """The frozen PredContext, as persona_bundles.bundle_snapshot."""
        elig = context.eligibility
        return {
            "pred_request_id": context.pred_request_id,
            "scenario_id": context.scenario_id,
            "patient_name": context.patient_name,
            "provider_name": context.provider_name,
            "provider_npi": context.provider_npi,
            "plan_name": context.plan_name,
            "payer_id": context.payer_id,
            "state": context.state,
            "decision": context.decision,
            "criteria_score": context.criteria_score,
            "confidence_label": context.confidence_label,
            "has_bundling_conflict": context.has_bundling_conflict,
            "medical_necessity_met": context.medical_necessity_met,
            "open_conditions": context.open_conditions,
            "missing_evidence": context.missing_evidence,
            "provider_oig_excluded": context.provider_oig_excluded,
            "provider_network_status": context.provider_network_status,
            "confirms_count": context.confirms_count,
            "contradicts_count": context.contradicts_count,
            "contradicts_fields": context.contradicts_fields,
            "total_fee_submitted": context.total_fee_submitted,
            "procedures": [
                {
                    "cdt_code": p.cdt_code,
                    "tooth_number": p.tooth_number,
                    "tooth_surface": p.tooth_surface,
                    "fee": p.fee_submitted,
                    "allowed_amount": p.allowed_amount,
                    "insurance_pays": p.insurance_pays,
                    "patient_pays": p.patient_pays,
                    "downgrade_applied": p.downgrade_applied,
                }
                for p in context.procedures
            ],
            "clinical_evidence": [
                {
                    "document_type": e.document_type,
                    "confidence_score": e.confidence_score,
                    "extraction_method": e.extraction_method,
                    "below_trust_floor": e.below_trust_floor,
                }
                for e in context.clinical_evidence
            ],
            "eligibility": None if elig is None else {
                "coverage_active": elig.coverage_active,
                "plan_type": elig.plan_type,
                "annual_max_remaining": elig.annual_max_remaining,
                "deductible_remaining": elig.deductible_remaining,
                "implant_covered": elig.implant_covered,
                "waiting_period_met": elig.waiting_period_met,
                "missing_tooth_clause_triggered": elig.missing_tooth_clause_triggered,
                "coordination_of_benefits": elig.coordination_of_benefits,
                "member_id_mismatch": elig.member_id_mismatch,
            },
            "payer_response": None if context.payer_response is None else {
                "decision": context.payer_response.decision,
                "denial_reason_code": context.payer_response.denial_reason_code,
                "denial_reason_text": context.payer_response.denial_reason_text,
                "appeal_deadline": context.payer_response.appeal_deadline,
            },
        }
