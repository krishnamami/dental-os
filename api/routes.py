"""
T-33..T-37 — the five dental-os endpoints.

TWO POOLS, and which one a query uses is not a detail:

    request.app.state.simulator_pool   dental  (READ-ONLY, dental_app)
    request.app.state.os_pool          dental_os (READ-WRITE)

CONTEXT.md RULE 15 — dental-simulator tables are read-only here. The
read pool runs every query inside `SET TRANSACTION READ ONLY`, so a
stray write raises instead of committing. Do not "fix" a write error by
switching pools; write to os_pool or don't write.

FAST PATH / SLOW PATH. GET /decisions/{id} reads decision_outputs when
rows exist and runs PersonaRunner when they don't. The runner writes as
a side effect, so the second call to a cold pre-D is a read. Note what
this means for `decision_outputs`: the table is append-only (see
migrations/002), so a caller who wants a re-run gets new rows and a new
bundle rather than an overwrite — the fast path always reads the
CURRENT bundle, via persona_bundles.is_current.
"""
from __future__ import annotations

import json
import logging
from datetime import date, datetime, time as dtime
from typing import Any, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from pydantic import BaseModel

from api.auth import (
    TENANT_CONTACTS,
    assert_tenant_allowed,
    require_claims,
    require_admin,
    require_claims_or_demo,
    require_practice_admin,
    tenant_filter,
)

from api.schemas import (
    AppealResponse,
    Citation,
    Condition,
    ConditionsResponse,
    DecisionBundleResponse,
    DecisionOutput,
    EvidenceItem,
    FeedbackRequest,
    FeedbackResponse,
    PatientProcedure,
    PatientSummaryResponse,
    PatientSummaryTotals,
    Signal,
)
from core.catalogue.context_enricher import ContextEnricher
from core.context.context_builder import ContextBuilder
from core.cron.runner import PersonaRunner
from core.db.connection import (
    DEFAULT_TENANT,
    execute_os_with_tenant,
    fetch_with_tenant,
    get_admin_pool,
)
from core.resolvers import resolve_coverage
from domains.dental.personas import DSOPortfolioManager
from core.resolvers.appeal_viability_resolver import resolve_appeal_viability

logger = logging.getLogger(__name__)

router = APIRouter()

APPEALABLE_DECISIONS = ("denied", "pended")


# ─────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────


def _pools(request: Request) -> tuple[Any, Any]:
    sim = getattr(request.app.state, "simulator_pool", None)
    os_pool = getattr(request.app.state, "os_pool", None)
    if sim is None or os_pool is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Database pools not initialised — the lifespan handler "
                   "did not complete. Check DATABASE_URL and "
                   "DENTAL_OS_DATABASE_URL.",
        )
    return sim, os_pool


def _tenant(request: Request) -> str:
    """The app-level default. Used for dental-os's OWN tables, which are
    written under whichever tenant owns the pre-D — see _tenant_for."""
    return getattr(request.app.state, "tenant_id", DEFAULT_TENANT)


# pred_request_id -> tenant_id. Small, bounded (one entry per pre-D) and
# immutable in practice: a pre-D never changes hands between practices.
_TENANT_CACHE: dict[str, str] = {}


async def _tenant_for(request: Request, pred_request_id: str) -> str:
    """Which practice owns this pre-D.

    Sprint 2. Before this, every route assumed suwanee_smiles, so a
    Tampa pre-D read under the Suwanee tenant returned ZERO ROWS AND NO
    ERROR — the RLS trap — and the API answered 404 for a pre-D that
    plainly exists.

    `pred_requests` is itself RLS-protected, so the lookup cannot simply
    query for the tenant: you need the tenant to do the read. The
    resolution is therefore to try each active practice in turn. That is
    3 cheap indexed lookups worst case, cached thereafter.

    `tenants` is the one table on this database with RLS disabled
    (relrowsecurity = false) — it is a directory of practices, not
    patient data — which is what makes enumerating them legal here.
    """
    if pred_request_id in _TENANT_CACHE:
        return _TENANT_CACHE[pred_request_id]

    sim, _ = _pools(request)
    rows = await fetch_with_tenant(
        sim, _tenant(request),
        "SELECT tenant_id FROM tenants WHERE active ORDER BY tenant_id")
    candidates = [r["tenant_id"] for r in rows] or [_tenant(request)]
    # Try the app default first — 40 of 50 pre-Ds are Suwanee's.
    default = _tenant(request)
    if default in candidates:
        candidates = [default] + [c for c in candidates if c != default]

    for candidate in candidates:
        found = await fetch_with_tenant(
            sim, candidate,
            "SELECT tenant_id FROM pred_requests WHERE pred_request_id = $1",
            pred_request_id)
        if found:
            _TENANT_CACHE[pred_request_id] = found[0]["tenant_id"]
            return _TENANT_CACHE[pred_request_id]

    # Not found under any tenant. Return the default and let the caller's
    # own lookup produce the 404 with its fuller message — resolving a
    # tenant is not the right place to decide a pre-D does not exist.
    return default


def _json(value: Any, default: Any) -> Any:
    """JSONB -> python. asyncpg hands these back as str on these pools."""
    if value is None:
        return default
    if isinstance(value, (dict, list)):
        return value
    if isinstance(value, (str, bytes)):
        try:
            return json.loads(value)
        except (ValueError, TypeError):
            return default
    return default


def _iso(value: Any) -> Optional[str]:
    if value is None:
        return None
    if isinstance(value, (datetime, date)):
        return value.isoformat()
    return str(value)


async def _build_context(request: Request, pred_request_id: str):
    """ContextBuilder + ContextEnricher against the simulator pool.

    Raises 404 rather than letting LookupError become a 500 — a pre-D
    that RLS cannot see is indistinguishable from one that does not
    exist, and both are "not found" to a caller.
    """
    sim, _ = _pools(request)
    tenant = await _tenant_for(request, pred_request_id)
    try:
        context = await ContextBuilder(sim).build(pred_request_id, tenant)
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except ValueError as exc:
        # scenario_id_from_pred_request_id rejects the old PRED-DA-*
        # format (RULE 14). That is a bad request, not a missing row.
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return await ContextEnricher(sim).enrich(context, tenant)


async def _read_current_bundle(
    request: Request, pred_request_id: str
) -> tuple[Optional[dict], list[dict]]:
    """The CURRENT persona_bundles row plus its decision_outputs rows.

    decision_outputs is append-only, so filtering by bundle_id is what
    keeps a re-run's rows from being merged with the previous run's.
    """
    _, os_pool = _pools(request)
    tenant = await _tenant_for(request, pred_request_id)

    bundles = await execute_os_with_tenant(
        os_pool, tenant,
        """
        SELECT bundle_id, bundle_snapshot, wave_outputs, all_signals,
               version, completed_at
        FROM persona_bundles
        WHERE pred_request_id = $1 AND tenant_id = $2 AND is_current
        ORDER BY completed_at DESC LIMIT 1
        """,
        pred_request_id, tenant,
    )
    if not bundles:
        return None, []

    bundle = bundles[0]
    outputs = await execute_os_with_tenant(
        os_pool, tenant,
        """
        SELECT decision_id, wave, mode, outcome, signals, confidence_label,
               created_at
        FROM decision_outputs
        WHERE pred_request_id = $1 AND tenant_id = $2 AND bundle_id = $3
        ORDER BY wave, decision_id
        """,
        pred_request_id, tenant, bundle["bundle_id"],
    )
    return bundle, outputs


def _signals_from_outputs(outputs: list[dict]) -> list[dict]:
    out: list[dict] = []
    for row in outputs:
        out.extend(_json(row["signals"], []))
    return out


def _waves_from_outputs(outputs: list[dict]) -> dict[str, list[DecisionOutput]]:
    waves: dict[str, list[DecisionOutput]] = {}
    for row in outputs:
        waves.setdefault(str(row["wave"]), []).append(DecisionOutput(
            decision_id=row["decision_id"],
            wave=row["wave"],
            mode=row["mode"],
            outcome=row.get("outcome"),
            signals=[Signal(**s) for s in _json(row["signals"], [])],
        ))
    return waves


async def _readiness_flags(
    request: Request, pred_request_id: str, tenant: str
) -> Optional[dict]:
    """The engine's 14 readiness booleans for one pre-D.

    Read LIVE from dental-simulator's pred_states rather than from the
    persona bundle, for two reasons:

      1. readiness_flags is upstream state. It is recomputed by
         compute_readiness.py whenever evidence lands, independently of
         any persona run, so the bundle's copy can be stale while the
         engine's is current.
      2. Bundles written before this change carry no readiness at all.
         Reading live means 50 existing bundles did not have to be
         re-run to gain the field.

    A pre-D with no row, or with readiness never computed, returns None
    — NOT an empty dict. "The engine has not scored this" and "the
    engine scored this and every flag failed" are different answers and
    the client renders them differently.
    """
    sim, _ = _pools(request)
    try:
        rows = await fetch_with_tenant(
            sim, tenant,
            "SELECT readiness_flags FROM pred_states WHERE pred_request_id = $1",
            pred_request_id,
        )
    except Exception as exc:  # noqa: BLE001 — readiness must not 500 the bundle
        logger.warning("readiness read failed for %s: %s", pred_request_id, exc)
        return None
    if not rows:
        return None

    # asyncpg returns JSONB as str on this pool (no codec registered).
    flags = _json(rows[0].get("readiness_flags"), None)
    if not isinstance(flags, dict) or not flags:
        return None
    # Coerce to bool: the column is the engine's, but a client typed
    # against dict[str, bool] should not receive a stray null.
    return {k: bool(v) for k, v in flags.items()}


def _open_condition_codes(signals: list[dict]) -> list[str]:
    """Signal codes that need somebody to do something.

    A human_approval signal by definition needs a human. A recommend
    signal with a recommended_action needs a task but not a signature.
    Codes only — the full objects are on /conditions.
    """
    codes = []
    for s in signals:
        if s.get("mode") == "human_approval" or s.get("recommended_action"):
            code = s.get("signal_code")
            if code and code not in codes:
                codes.append(code)
    return codes


# ─────────────────────────────────────────────────────────────────────
# T-33 — GET /decisions/{pred_request_id}
# ─────────────────────────────────────────────────────────────────────


# ─────────────────────────────────────────────────────────────────────
# The reviewer's queue.
#
# There was no list endpoint for pre-Ds before this — only
# /decisions/{id} for one at a time — so the workbench and the
# submission queue both shipped with their rows hardcoded in the TSX.
# A date picker over a literal array filters nothing, which is why this
# exists.
# ─────────────────────────────────────────────────────────────────────

def _queue_finding(conditions: list[str], decision: str | None) -> str:
    """One line a dentist can act on, from the conditions on the case.

    Ordered by what stops a submission first. "No open findings" is a
    real answer and must not be dressed up as one.
    """
    joined = " ".join(conditions)
    if "BUNDLING_CONFLICT" in joined:
        return "Bundling conflict — procedures billed together"
    if "MISSING" in joined or "XRAY" in joined or "EVIDENCE" in joined:
        return "Clinical evidence outstanding"
    if decision == "denied":
        return "Denied — appeal viability to review"
    if "PRED_REQUIRED" in joined:
        return "Pre-determination required before treatment"
    if "DOWNGRADE" in joined:
        return "Plan pays at a cheaper material's rate"
    return "No open findings"


@router.get("/decisions/submitted")
async def submitted_on(
    request: Request,
    # `date` in the URL, not in Python - this module imports
    # datetime.date and a parameter of that name shadows it.
    date_param: str | None = Query(None, alias="date"),
    claims=Depends(require_claims_or_demo),
) -> list[dict]:
    """Pre-Ds submitted on one day. Defaults to today."""
    tenant = tenant_filter(claims) or DEFAULT_TENANT
    _, os_pool = _pools(request)

    if date_param:
        try:
            on = date.fromisoformat(date_param)
        except ValueError:
            raise HTTPException(422, "date must be YYYY-MM-DD")
    else:
        on = date.today()

    rows = await execute_os_with_tenant(
        os_pool, tenant,
        """
        SELECT submission_id, pred_request_id, patient_name, payer_name,
               submitted_at, status, expected_response_days,
               submission_method, submission_ref
        FROM submission_events
        WHERE tenant_id = $1 AND submitted_at::date = $2
        ORDER BY submitted_at DESC
        """,
        tenant, on,
    )
    return [{**r, "submitted_at": _iso(r["submitted_at"])} for r in rows]


@router.get("/decisions/queue")
async def decisions_queue(
    request: Request,
    date_param: str | None = Query(None, alias="date"),
    claims=Depends(require_claims_or_demo),
) -> list[dict]:
    """Pre-Ds scheduled for one day, as a review queue.

    Scoped by the APPOINTMENT, same as the check-in screen: the four
    persona pages are then all looking at one day's patients rather
    than at four different definitions of "current".

    Reads pred_states and the current persona bundle. It does NOT run
    the personas — /checkin/today does, and that is why it takes seven
    seconds. This is a plain join and stays under a second.
    """
    tenant = tenant_filter(claims) or DEFAULT_TENANT
    sim, os_pool = _pools(request)

    if date_param:
        try:
            appt_date = date.fromisoformat(date_param)
        except ValueError:
            raise HTTPException(422, "date must be YYYY-MM-DD")
    else:
        appt_date = date.today()

    appts = await execute_os_with_tenant(
        os_pool, tenant,
        """
        SELECT pred_request_id, appointment_time
        FROM appointments
        WHERE tenant_id = $1 AND appointment_date = $2
          AND status <> 'cancelled'
        ORDER BY appointment_time
        """,
        tenant, appt_date,
    )
    if not appts:
        return []
    order = {r["pred_request_id"]: i for i, r in enumerate(appts)}

    rows = await fetch_with_tenant(
        sim, tenant,
        """
        SELECT pr.pred_request_id,
               p.first_name || ' ' || p.last_name AS patient_name,
               pr.payer_id, pr.total_case_value,
               pr.created_at, pr.submitted_at,
               ps.decision, ps.open_conditions, ps.submission_ready
        FROM pred_requests pr
        JOIN patients p ON p.patient_id = pr.patient_id
        LEFT JOIN pred_states ps
               ON ps.pred_request_id = pr.pred_request_id
        WHERE pr.tenant_id = $1 AND pr.pred_request_id = ANY($2::text[])
        """,
        tenant, list(order),
    )

    # One query for every bundle, not one per row. `blocking` is the
    # count of signals a human must sign off — mode is only ever
    # 'recommend' or 'human_approval'; there is no auto_execute.
    bundles = await execute_os_with_tenant(
        os_pool, tenant,
        "SELECT pred_request_id, all_signals FROM persona_bundles "
        "WHERE tenant_id = $1 AND is_current "
        "  AND pred_request_id = ANY($2::text[])",
        tenant, list(order),
    )
    blocking: dict[str, int] = {}
    for b in bundles:
        signals = _json(b["all_signals"], [])
        blocking[b["pred_request_id"]] = sum(
            1 for s in signals
            if isinstance(s, dict) and s.get("mode") == "human_approval"
        )

    out: list[dict] = []
    for row in rows:
        rid = row["pred_request_id"]
        conditions = _json(row["open_conditions"], [])
        decision = row["decision"] or "pending"
        out.append({
            "id": rid,
            "patient": row["patient_name"],
            "finding": _queue_finding(conditions, row["decision"]),
            "charges": _f(row["total_case_value"]),
            "payer": _payer_name(row["payer_id"]),
            "status": decision,
            "open": len(conditions),
            "blocking": blocking.get(rid, 0),
            "submission_ready": bool(row["submission_ready"]),
            # When the case entered the queue, so a biller can see what
            # has been sitting. submitted_at is NULL on every row in
            # this corpus — nothing has ever been sent — so a client
            # dating the payer window off it would show every deadline
            # as today. Both are returned; the client decides.
            "created_at": _iso(row["created_at"]),
            "submitted_at": _iso(row["submitted_at"]),
        })
    out.sort(key=lambda x: order.get(x["id"], 99))
    return out


@router.get("/decisions/{pred_request_id}", response_model=DecisionBundleResponse)
async def get_decision_bundle(
    pred_request_id: str,
    request: Request,
    refresh: bool = False,
    claims=Depends(require_claims_or_demo),
) -> DecisionBundleResponse:
    """The complete decision bundle — all nine personas, five waves.

    `?refresh=true` forces a re-run. It appends a new bundle and marks
    it current; the prior one stays in the table as history.
    """
    # ── Tenant boundary ──────────────────────────────────────────
    # _tenant_for resolves which practice OWNS this pre-D. The caller's
    # claims say which practice they may read. If those differ, 404 —
    # never 403, which would confirm the record exists and turn this
    # route into an id-enumeration oracle. Cached, so this costs one
    # lookup per pre-D per process.
    assert_tenant_allowed(claims, await _tenant_for(request, pred_request_id))
    sim, os_pool = _pools(request)
    # Which practice owns this pre-D — NOT the app default. Building the
    # runner with the wrong tenant makes ContextBuilder read zero rows
    # and 404 a pre-D that exists.
    tenant = await _tenant_for(request, pred_request_id)

    bundle, outputs = (None, [])
    if not refresh:
        bundle, outputs = await _read_current_bundle(request, pred_request_id)

    computed = False
    if bundle is None or not outputs:
        # SLOW PATH — no bundle yet (or a forced refresh). Run the waves.
        runner = PersonaRunner(sim, os_pool, tenant)
        try:
            # Passed explicitly as well as via the constructor: run()'s
            # per-request override is the contract other callers use,
            # and exercising it here keeps the two paths identical.
            await runner.run(pred_request_id, tenant_id=tenant)
        except LookupError as exc:
            raise HTTPException(status_code=404, detail=str(exc)) from exc
        except ValueError as exc:
            raise HTTPException(status_code=400, detail=str(exc)) from exc
        computed = True
        bundle, outputs = await _read_current_bundle(request, pred_request_id)
        if bundle is None:
            raise HTTPException(
                status_code=500,
                detail=f"PersonaRunner completed for {pred_request_id} but no "
                       f"current bundle was written. Check RLS tenant context "
                       f"on the dental_os pool.",
            )

    snapshot = _json(bundle["bundle_snapshot"], {})
    all_signals = _signals_from_outputs(outputs)

    # submission_ready is pre_d_assessment's verdict, read back — not
    # recomputed here. The API explains the decision; it never makes one.
    submission_ready = any(
        s.get("signal_code") == "PRED_READY_TO_SUBMIT" for s in all_signals
    )

    flags = await _readiness_flags(request, pred_request_id, tenant)
    met = sum(1 for v in flags.values() if v) if flags else None
    total = len(flags) if flags else None

    return DecisionBundleResponse(
        pred_request_id=pred_request_id,
        patient_name=snapshot.get("patient_name") or "",
        provider_name=snapshot.get("provider_name") or "",
        plan_name=snapshot.get("plan_name") or "",
        payer_id=snapshot.get("payer_id") or "",
        state=snapshot.get("state") or "",
        decision=snapshot.get("decision") or "",
        criteria_score=snapshot.get("criteria_score"),
        confidence_label=(
            outputs[0].get("confidence_label")
            or snapshot.get("confidence_label")
            or ""
        ),
        submission_ready=submission_ready,
        waves=_waves_from_outputs(outputs),
        all_signals=[Signal(**s) for s in all_signals],
        open_conditions=_open_condition_codes(all_signals),
        bundle_id=str(bundle["bundle_id"]),
        processed_at=_iso(bundle.get("completed_at")),
        computed=computed,
        readiness_flags=flags,
        readiness_met=met,
        readiness_total=total,
        readiness_score=(
            round(met / total, 3) if met is not None and total else None
        ),
    )


# ─────────────────────────────────────────────────────────────────────
# T-34 — GET /decisions/{pred_request_id}/conditions
# ─────────────────────────────────────────────────────────────────────


@router.get(
    "/decisions/{pred_request_id}/conditions", response_model=ConditionsResponse
)
async def get_conditions(
    pred_request_id: str,
    request: Request,
    claims=Depends(require_claims_or_demo),
) -> ConditionsResponse:
    """The front-desk / billing queue: only what needs action.

    A signal qualifies when it needs a signature (human_approval) or
    names a task (recommended_action). The clean confirmations —
    ELIGIBILITY_VERIFIED, PROVIDER_VERIFIED — are deliberately absent:
    this endpoint is a work queue, not a report.
    """
    # ── Tenant boundary ──────────────────────────────────────────
    # _tenant_for resolves which practice OWNS this pre-D. The caller's
    # claims say which practice they may read. If those differ, 404 —
    # never 403, which would confirm the record exists and turn this
    # route into an id-enumeration oracle. Cached, so this costs one
    # lookup per pre-D per process.
    assert_tenant_allowed(claims, await _tenant_for(request, pred_request_id))
    bundle, outputs = await _read_current_bundle(request, pred_request_id)
    if bundle is None:
        # Reuse the T-33 path so a cold pre-D computes rather than 404s.
        await get_decision_bundle(pred_request_id, request)
        bundle, outputs = await _read_current_bundle(request, pred_request_id)
        if bundle is None:
            raise HTTPException(status_code=404, detail=pred_request_id)

    snapshot = _json(bundle["bundle_snapshot"], {})
    all_signals = _signals_from_outputs(outputs)

    # conditions_library carries `category`; the enricher is the only
    # thing allowed to load it (RULE 4), so it comes off the context.
    context = await _build_context(request, pred_request_id)
    library = (context.catalogue_rules or {}).get("conditions_library") or {}

    conditions: list[Condition] = []
    for s in all_signals:
        actionable = (
            s.get("mode") == "human_approval" or s.get("recommended_action")
        )
        if not actionable:
            continue
        entry = library.get(s.get("signal_code")) or {}
        conditions.append(Condition(
            signal_code=s.get("signal_code") or "",
            finding=s.get("finding") or "",
            mode=s.get("mode") or "",
            category=entry.get("category"),
            citation=s.get("citation"),
            payer_citation=s.get("payer_citation") or entry.get("payer_citation"),
            recommended_action=(
                s.get("recommended_action") or entry.get("recommended_action")
            ),
            sla_hours=s.get("sla_hours") or entry.get("sla_hours"),
            assignee=s.get("assignee") or entry.get("assignee"),
            wave=s.get("wave"),
            decision_id=s.get("decision_id"),
            data=s.get("data") or {},
        ))

    # Hardest first: a signature blocks, a task does not. Within each,
    # the tighter SLA comes first. None sorts last, not as zero.
    conditions.sort(key=lambda c: (
        c.mode != "human_approval",
        c.sla_hours if c.sla_hours is not None else 10**6,
        c.wave or 0,
    ))

    blocking = sum(1 for c in conditions if c.mode == "human_approval")
    return ConditionsResponse(
        pred_request_id=pred_request_id,
        patient_name=snapshot.get("patient_name") or "",
        decision=snapshot.get("decision") or "",
        submission_ready=any(
            s.get("signal_code") == "PRED_READY_TO_SUBMIT" for s in all_signals
        ),
        conditions=conditions,
        conditions_count=len(conditions),
        blocking_count=blocking,
        advisory_count=len(conditions) - blocking,
    )


# ─────────────────────────────────────────────────────────────────────
# T-35 — GET /decisions/{pred_request_id}/appeal
# ─────────────────────────────────────────────────────────────────────


def build_appeal_letter(context: Any, viability: dict) -> Optional[str]:
    """Assemble a DRAFT appeal from catalogue rows only.

    This is NOT the appeal generator. dental-simulator Gap #3 is still
    open — there is no LLM narrative behind this, and nothing here
    invents a clinical argument (RULE 13). Every sentence below is
    either a fact off the context or a string already in the catalogue:
    the separation criteria come from bundling_rules, the citation from
    the same row, the evidence list from clinical_evidence.

    A human signs this. `appeal_letter_is_draft` stays True.
    """
    if not viability.get("viable"):
        return None
    strategy = viability.get("appeal_strategy") or ""
    citation = viability.get("citation")
    codes = ", ".join(context.cdt_codes) or "the billed procedures"
    evidence = viability.get("supporting_evidence") or []

    lines = [
        f"RE: Appeal of pre-determination for {context.patient_name} "
        f"({context.pred_request_id})",
        f"Payer: {context.payer_id}    Plan: {context.plan_name}",
        f"Provider: {context.provider_name}  NPI {context.provider_npi}",
        "",
        f"This is a request to reconsider the determination on {codes}.",
        "",
        strategy,
    ]
    if citation:
        lines += ["", f"Policy reference: {citation}"]
    if evidence:
        lines += ["", "Enclosed:"] + [f"  - {e}" for e in evidence]
    if viability.get("missing_evidence"):
        lines += [
            "",
            "NOT ENCLOSED — obtain before sending if available:",
        ] + [f"  - {m}" for m in viability["missing_evidence"]]
    lines += [
        "",
        "DRAFT — assembled from catalogue rules. Requires clinical review "
        "and signature before submission.",
    ]
    return "\n".join(lines)


@router.get("/decisions/{pred_request_id}/appeal", response_model=AppealResponse)
async def get_appeal(
    pred_request_id: str,
    request: Request,
    claims=Depends(require_claims_or_demo),
) -> AppealResponse:
    """The appeal packet. 404 when the pre-D was approved.

    An approved pre-D has nothing to appeal, so this is genuinely "no
    such resource" rather than an empty packet — an empty 200 would
    read to a caller as "we looked and found no grounds".
    """
    # ── Tenant boundary ──────────────────────────────────────────
    # _tenant_for resolves which practice OWNS this pre-D. The caller's
    # claims say which practice they may read. If those differ, 404 —
    # never 403, which would confirm the record exists and turn this
    # route into an id-enumeration oracle. Cached, so this costs one
    # lookup per pre-D per process.
    assert_tenant_allowed(claims, await _tenant_for(request, pred_request_id))
    context = await _build_context(request, pred_request_id)

    if context.decision not in APPEALABLE_DECISIONS:
        raise HTTPException(
            status_code=404,
            detail=f"{pred_request_id} is '{context.decision}' — there is "
                   f"nothing to appeal. Appeals exist for "
                   f"{' or '.join(APPEALABLE_DECISIONS)} only.",
        )

    viability = resolve_appeal_viability(context, context.catalogue_rules)

    # Prefer what appeal_specialist actually emitted over recomputing —
    # the persona is the decision of record, this endpoint renders it.
    _, outputs = await _read_current_bundle(request, pred_request_id)
    appeal_signals = [
        s for s in _signals_from_outputs(outputs)
        if s.get("decision_id") == "appeal_specialist"
    ]
    codes = {s.get("signal_code") for s in appeal_signals}
    viable = (
        "APPEAL_VIABLE" in codes if appeal_signals
        else bool(viability.get("viable"))
    )

    payer_response = context.payer_response
    evidence = [
        EvidenceItem(
            document_type=e.document_type,
            s3_key=e.s3_key,
            description=(
                f"{e.document_type.replace('_', ' ').title()} "
                f"({e.extraction_method})"
            ),
            confidence=e.confidence_score,
        )
        for e in context.clinical_evidence
    ]

    citations: list[Citation] = []
    if viability.get("citation"):
        citations.append(Citation(
            source=f"{context.payer_id} provider manual",
            section=viability["citation"],
            text=viability.get("appeal_strategy"),
        ))
    if payer_response and payer_response.policy_citation:
        citations.append(Citation(
            source=f"{context.payer_id} payer response",
            section=payer_response.denial_reason_code,
            text=payer_response.policy_citation,
        ))

    not_viable_reason = None
    if not viable:
        not_viable_reason = (
            viability.get("category_rationale")
            or "No appeal path is supported by the catalogue for this denial."
        )

    return AppealResponse(
        pred_request_id=pred_request_id,
        patient_name=context.patient_name,
        payer_id=context.payer_id,
        pred_number=payer_response.pred_number if payer_response else None,
        decision=context.decision,
        denial_reason_code=viability.get("denial_reason_code"),
        denial_reason_text=viability.get("denial_reason_text"),
        appeal_deadline=viability.get("appeal_deadline"),
        days_remaining=viability.get("days_remaining"),
        deadline_warning=bool(viability.get("deadline_warning")),
        viable=viable,
        success_probability=viability.get("success_probability"),
        appeal_strategy=viability.get("appeal_strategy"),
        appeal_letter_text=build_appeal_letter(context, viability),
        appeal_letter_is_draft=True,
        evidence_list=evidence,
        citations=citations,
        missing_evidence=viability.get("missing_evidence") or [],
        not_viable_reason=not_viable_reason,
    )


# ─────────────────────────────────────────────────────────────────────
# T-36 — GET /decisions/{pred_request_id}/patient-summary
# ─────────────────────────────────────────────────────────────────────


@router.get(
    "/decisions/{pred_request_id}/patient-summary",
    response_model=PatientSummaryResponse,
)
async def get_patient_summary(
    pred_request_id: str,
    request: Request,
    claims=Depends(require_claims_or_demo),
) -> PatientSummaryResponse:
    """The printout that replaces the phone call to Delta Dental.

    Per CDT: what the practice charges, what the in-network discount
    removes, what the plan allows, what it pays, and what the patient
    owes. The discount line matters more than it looks — it is the
    number patients most often mistake for a bill.
    """
    # ── Tenant boundary ──────────────────────────────────────────
    # _tenant_for resolves which practice OWNS this pre-D. The caller's
    # claims say which practice they may read. If those differ, 404 —
    # never 403, which would confirm the record exists and turn this
    # route into an id-enumeration oracle. Cached, so this costs one
    # lookup per pre-D per process.
    assert_tenant_allowed(claims, await _tenant_for(request, pred_request_id))
    context = await _build_context(request, pred_request_id)
    coverage = resolve_coverage(context, context.catalogue_rules)

    cdt_rules = (context.catalogue_rules or {}).get("cdt_rules") or {}
    elig = context.eligibility
    summary = coverage["summary"]

    procedures: list[PatientProcedure] = []
    for p in coverage["procedures"]:
        downgrade_note = None
        if p.get("downgrade_applied"):
            downgrade_note = (
                f"Plan reimburses {p['cdt_code']} at the "
                f"{p.get('downgrade_to')} rate. The difference is the "
                f"patient's responsibility."
            )
        procedures.append(PatientProcedure(
            cdt_code=p["cdt_code"],
            description=(cdt_rules.get(p["cdt_code"]) or {}).get("description"),
            tooth_number=p.get("tooth_number"),
            provider_ucr_fee=p["provider_ucr_fee"],
            in_network_discount=p["provider_discount"],
            contracted_rate=p["contracted_rate"],
            deductible_applied=p["deductible_applied"],
            insurance_pays=p["insurance_pays"],
            patient_pays=p["patient_pays"],
            downgrade_applied=bool(p.get("downgrade_applied")),
            downgrade_note=downgrade_note,
            pre_d_required=bool(p.get("pre_d_required")),
            covered=bool(p.get("covered", True)),
            not_covered_reason=p.get("not_covered_reason"),
            rate_is_estimated=bool(p.get("rate_is_estimated")),
        ))

    notes: list[str] = []
    if summary["total_provider_discount"] > 0:
        notes.append(
            f"Your ${summary['total_provider_discount']:,.0f} in-network "
            f"discount is not your responsibility — it is the amount "
            f"{context.provider_name or 'this practice'} agreed to write off "
            f"for staying in network."
        )
    notes.append(
        f"Annual maximum: ${summary['annual_max_remaining_after']:,.0f} "
        f"remaining after this case."
    )
    if summary["annual_max_exhausted"]:
        notes.append(
            "This case uses your entire remaining annual maximum. Anything "
            "further this benefit year is paid in full by you."
        )
    if coverage.get("pre_d_required_for"):
        notes.append(
            f"Pre-authorization required before treatment begins for "
            f"{', '.join(coverage['pre_d_required_for'])}."
        )
    for gap in coverage.get("coverage_gaps", []):
        notes.append(gap)

    # RULE 11 — anything the estimate could not read, said out loud.
    # resolve_coverage already reports estimated rates inside
    # missing_inputs, so only add the plain-English version when it did
    # not; otherwise a patient reads the same warning twice.
    caveats = list(coverage.get("missing_inputs") or [])
    if coverage.get("rates_estimated") and not any(
        "fee schedule" in c for c in caveats
    ):
        caveats.append(
            f"Rates for {', '.join(coverage['rates_estimated'])} are estimates, "
            f"not the payer's published allowed amount."
        )

    return PatientSummaryResponse(
        pred_request_id=pred_request_id,
        patient_name=context.patient_name,
        provider_name=context.provider_name,
        plan_name=context.plan_name,
        payer_id=context.payer_id,
        state=context.state,
        valid_through=(
            context.payer_response.appeal_deadline
            if context.payer_response and context.decision == "approved"
            else None
        ),
        annual_max_remaining_before=(
            float(elig.annual_max_remaining) if elig else 0.0
        ),
        deductible_remaining_before=(
            float(elig.deductible_remaining) if elig else 0.0
        ),
        procedures=procedures,
        summary=PatientSummaryTotals(
            total_provider_charges=summary["total_ucr_fee"],
            total_in_network_savings=summary["total_provider_discount"],
            total_contracted=summary["total_contracted"],
            total_deductible_applied=summary["total_deductible"],
            total_insurance_pays=summary["total_insurance_pays"],
            total_patient_pays=summary["total_patient_pays"],
            annual_max_remaining_after=summary["annual_max_remaining_after"],
            annual_max_exhausted=bool(summary["annual_max_exhausted"]),
        ),
        notes=notes,
        caveats=caveats,
    )


# ─────────────────────────────────────────────────────────────────────
# T-37 — POST /decisions/{pred_request_id}/feedback
# ─────────────────────────────────────────────────────────────────────


@router.post(
    "/decisions/{pred_request_id}/feedback", response_model=FeedbackResponse
)
async def post_feedback(
    pred_request_id: str,
    body: FeedbackRequest,
    request: Request,
    claims=Depends(require_claims_or_demo),
) -> FeedbackResponse:
    """Capture a human's verdict on one signal.

    feedback_type and submitted_by are validated twice on purpose: the
    Literal types reject a bad value with a 422 before it reaches the
    database, and provider_feedback's CHECK constraints reject it again
    if it somehow gets there. The second layer is what protects a
    direct psql insert, which is how this table will actually be
    backfilled.
    """
    # ── Tenant boundary ──────────────────────────────────────────
    # _tenant_for resolves which practice OWNS this pre-D. The caller's
    # claims say which practice they may read. If those differ, 404 —
    # never 403, which would confirm the record exists and turn this
    # route into an id-enumeration oracle. Cached, so this costs one
    # lookup per pre-D per process.
    assert_tenant_allowed(claims, await _tenant_for(request, pred_request_id))
    _, os_pool = _pools(request)
    # provider_feedback is RLS-scoped, so feedback on a Tampa pre-D must
    # be written under Tampa or the policy's WITH CHECK rejects it.
    tenant = await _tenant_for(request, pred_request_id)

    try:
        rows = await execute_os_with_tenant(
            os_pool, tenant,
            """
            INSERT INTO provider_feedback (
                pred_request_id, tenant_id, decision_id,
                signal_code, feedback_type, notes, submitted_by
            ) VALUES ($1,$2,$3,$4,$5,$6,$7)
            RETURNING feedback_id, submitted_at, expires_at
            """,
            pred_request_id, tenant, body.decision_id,
            body.signal_code, body.feedback_type, body.notes,
            body.submitted_by,
        )
    except Exception as exc:  # noqa: BLE001 — surfaced as a 400, not a 500
        logger.exception("feedback insert failed for %s", pred_request_id)
        raise HTTPException(
            status_code=400,
            detail=f"Could not record feedback: {type(exc).__name__}: {exc}",
        ) from exc

    row = rows[0]
    return FeedbackResponse(
        feedback_id=str(row["feedback_id"]),
        pred_request_id=pred_request_id,
        decision_id=body.decision_id,
        signal_code=body.signal_code,
        feedback_type=body.feedback_type,
        received_at=_iso(row["submitted_at"]) or "",
        expires_at=_iso(row.get("expires_at")),
    )


# ─────────────────────────────────────────────────────────────────────
# Sprint 2 — GET /portfolio/summary
# ─────────────────────────────────────────────────────────────────────


def _f(value: Any) -> float:
    """Decimal | None -> float. JSON has no decimal type and asyncpg
    returns NUMERIC as Decimal, which json cannot serialise."""
    return float(value) if value is not None else 0.0


@router.get("/portfolio/summary")
async def portfolio_summary(
    request: Request, claims=Depends(require_claims_or_demo)
) -> dict:
    """Cross-tenant analytics — every practice in the DSO group.

    THE ONLY CROSS-TENANT ENDPOINT in dental-os. Everything else answers
    for one practice; this answers for the operator who owns several and
    wants to know which one is leaking money.

    It returns aggregates only — counts, rates and sums per practice. No
    patient, no pre-D id, no signal. That is the line: a DSO manager is
    entitled to know Tampa denies at 20%, and is not thereby entitled to
    read a Tampa patient's chart.

    On the admin pool: get_admin_pool() is used because that is the
    named seam for this query, but it does NOT currently bypass RLS —
    these tables are FORCE row-level security and dental_admin holds
    neither BYPASSRLS nor superuser. aggregate_all_tenants therefore
    iterates practices with app.tenant_id set per tenant, which works on
    the ordinary pool too. See get_admin_pool()'s docstring.
    """
    try:
        pool = await get_admin_pool()
    except RuntimeError:
        # No admin DSN configured — the read pool answers identically.
        pool, _ = _pools(request)

    data = await DSOPortfolioManager.aggregate_all_tenants(pool)

    # ── Tenant boundary ──────────────────────────────────────────
    # This is the one endpoint that aggregates ACROSS practices, so it
    # needs the opposite treatment to the others: instead of refusing a
    # foreign pre-D, it narrows the result set.
    #
    # accord_admin (tenant_filter -> None) sees the whole group. Anyone
    # else sees exactly one row — their own practice — even though the
    # aggregate was computed over all of them. A dso_owner today belongs
    # to a single tenant_id, so "their DSO group" and "their practice"
    # are the same thing; when a group spans several tenants this needs
    # a real group membership table, not a wider filter.
    allowed = tenant_filter(claims)
    if allowed is not None:
        data["tenants"] = [
            t for t in data["tenants"] if t["tenant_id"] == allowed
        ]
    tenants = data["tenants"]

    total_pre_ds = sum(t["total_pre_ds"] for t in tenants)
    total_approved = sum(t["approved"] for t in tenants)
    total_denied = sum(t["denied"] for t in tenants)
    total_pended = sum(t["pended"] for t in tenants)
    total_patient = sum(_f(t["total_patient"]) for t in tenants)

    # Revenue at risk is what sits on pre-Ds that did NOT approve, not
    # everything billed. Summing all patient responsibility would count
    # an approved case's copay as money in danger.
    at_risk = sum(
        _f(t["total_patient"]) for t in tenants
        if (t["denied"] or 0) + (t["pended"] or 0) > 0
    )

    # A practice with no cost_estimates rows reports NULL revenue, not
    # zero. Naming them beats publishing a total that quietly omits them.
    missing_costs = [
        t["tenant_id"] for t in tenants if t["total_patient"] is None
    ]

    return {
        "summary": {
            "total_practices": len(tenants),
            "total_pre_ds": total_pre_ds,
            "total_approved": total_approved,
            "total_denied": total_denied,
            "total_pended": total_pended,
            "overall_approval_rate": (
                round(total_approved / total_pre_ds, 3) if total_pre_ds else 0
            ),
            "total_patient_responsibility": round(total_patient, 2),
            "total_patient_revenue_at_risk": round(at_risk, 2),
            "practices_missing_cost_estimates": missing_costs,
        },
        "practices": [
            {
                "tenant_id": t["tenant_id"],
                "practice_name": t["practice_name"],
                "address": t["address"],
                "total_pre_ds": t["total_pre_ds"],
                "approved": t["approved"],
                "denied": t["denied"],
                "pended": t["pended"],
                "approval_rate": (
                    round(t["approved"] / t["total_pre_ds"], 3)
                    if t["total_pre_ds"] else 0
                ),
                "avg_criteria_score": _f(t["avg_score"]),
                "total_contracted": _f(t["total_contracted"]),
                "total_insurance_pays": _f(t["total_insurance"]),
                "total_patient_pays": _f(t["total_patient"]),
                "cost_estimates_available": t["total_patient"] is not None,
            }
            for t in tenants
        ],
        "top_denial_reasons": data["top_denial_reasons"],
        "generated_at": data["generated_at"],
    }


# ─────────────────────────────────────────────────────────────────────
# Check-in — the front desk's screen, pre-computed.
#
# One call for the whole morning instead of three per patient. The
# front end renders what this returns and reads nothing else, which is
# what lets that page ship without a signal code on it.
#
# ⚠ EVERY MONEY FIGURE COMES FROM resolve_coverage(), the same function
# GET /patient-summary uses. cost_estimates holds a stored answer that
# DISAGREES with it — for DA-U01 that table says the patient owes $50
# and the live computation says $0 — and two screens quoting different
# numbers for one visit is the worst thing a dental product can do.
# When that table is reconciled this can read it and save the work.
# ─────────────────────────────────────────────────────────────────────

def _fmt_time(t) -> str:
    """09:00 -> "9:00 AM". The DB holds a TIME; the desk reads a clock."""
    if t is None:
        return ""
    hour = t.hour % 12 or 12
    return f"{hour}:{t.minute:02d} {'AM' if t.hour < 12 else 'PM'}"


_PROC_NAMES = {
    "D6010": "Implant", "D7953": "Bone graft", "D6065": "Crown",
    "D2740": "Crown", "D2750": "Crown", "D1110": "Cleaning",
    "D0274": "Bitewings", "D4341": "Scaling", "D2391": "Filling",
}

_PAYER_NAMES = {
    "delta_dental": "Delta Dental PPO", "cigna": "Cigna DPPO",
    "metlife": "MetLife PDP", "aetna": "Aetna DMO",
    "humana": "Humana DPO", "guardian": "Guardian DPO",
}


def _procedure_summary(codes: list[str]) -> str:
    parts = [_PROC_NAMES.get(c, c) for c in codes]
    return " + ".join(dict.fromkeys(parts)) or "\u2014"


def _payer_name(payer_id: str | None) -> str:
    return _PAYER_NAMES.get(payer_id or "", payer_id or "Unknown plan")


@router.get("/checkin/dates")
async def checkin_dates(
    request: Request, claims=Depends(require_claims_or_demo)
) -> list[str]:
    """Every date this practice has a schedule for, newest first.

    Drives the date picker. Capped at 30 because it is a dropdown, not
    a report — a practice with two years of history would otherwise
    render 500 options.
    """
    tenant = tenant_filter(claims) or DEFAULT_TENANT
    _, os_pool = _pools(request)
    rows = await execute_os_with_tenant(
        os_pool, tenant,
        """
        SELECT DISTINCT appointment_date
        FROM appointments
        WHERE tenant_id = $1 AND status <> 'cancelled'
        ORDER BY appointment_date DESC
        LIMIT 30
        """,
        tenant,
    )
    return [r["appointment_date"].isoformat() for r in rows]


@router.get("/checkin/today")
async def checkin_today(
    request: Request,
    # Named `date` in the URL but NOT in Python: this module imports
    # datetime.date, and a parameter of that name would shadow it —
    # `date.fromisoformat` two lines down would be a string method
    # lookup on whatever the caller sent.
    date_param: str | None = Query(None, alias="date"),
    claims=Depends(require_claims_or_demo),
) -> list[dict]:
    """One day's patients, pre-computed for the check-in screen.

    Defaults to today. An unparseable ?date is a 422 rather than a
    silent fall back to today — a screen that quietly shows a different
    day than the one in its own dropdown is worse than an error.
    """
    tenant = tenant_filter(claims) or DEFAULT_TENANT
    sim, os_pool = _pools(request)

    if date_param:
        try:
            appt_date = date.fromisoformat(date_param)
        except ValueError:
            raise HTTPException(422, "date must be YYYY-MM-DD")
    else:
        appt_date = date.today()

    # The schedule is the source of the day. A pre-D with no appointment
    # row is not that day's patient, and a cancelled one is not either.
    appts = await execute_os_with_tenant(
        os_pool, tenant,
        """
        SELECT pred_request_id, appointment_time, procedure_summary
        FROM appointments
        WHERE tenant_id = $1
          AND appointment_date = $2
          AND status <> 'cancelled'
        ORDER BY appointment_time
        """,
        tenant, appt_date,
    )
    if not appts:
        return []
    schedule = {
        r["pred_request_id"]: {
            "time": _fmt_time(r["appointment_time"]),
            "summary": r["procedure_summary"],
            # Position in the morning, for the sort at the end.
            "slot": i,
        }
        for i, r in enumerate(appts)
    }

    rows = await fetch_with_tenant(
        sim, tenant,
        """
        SELECT pr.pred_request_id,
               p.first_name || ' ' || p.last_name AS patient_name,
               p.email AS patient_email,
               p.mobile_phone AS patient_phone,
               pr.payer_id, pr.provider_npi,
               ep.member_id, ep.enrollment_date,
               ep.annual_maximum, ep.annual_maximum_used,
               ep.annual_maximum_remaining,
               ep.deductible_total, ep.deductible_met,
               ep.pred_required_codes,
               ps.has_bundling_conflict, ps.decision, ps.criteria_score
        FROM pred_requests pr
        JOIN patients p ON p.patient_id = pr.patient_id
        LEFT JOIN eligibility_profiles ep
               ON ep.pred_request_id = pr.pred_request_id
        LEFT JOIN pred_states ps
               ON ps.pred_request_id = pr.pred_request_id
        WHERE pr.tenant_id = $1 AND pr.pred_request_id = ANY($2::text[])
        """,
        tenant, list(schedule),
    )

    # Display names from `providers`, not a dict in this file. The
    # simulator stores them upper-cased ("SRIDHAR CHINTA"); a screen a
    # patient can see wants a name, not a shout.
    prov_rows = await fetch_with_tenant(
        sim, tenant,
        "SELECT provider_npi, first_name, last_name, credential "
        "FROM providers WHERE tenant_id = $1",
        tenant,
    )

    def _display(npi: str | None) -> str:
        for p in prov_rows:
            if p["provider_npi"] == npi:
                first = (p["first_name"] or "").title()
                last = (p["last_name"] or "").title()
                name = f"{first} {last}".strip()
                return f"Dr. {name}" if name else (npi or "Provider")
        return npi or "Provider"

    # WHO IS SENDING. The JWT carries sub, role and tenant_id — no name
    # and no email — so `claims.get("name")` would be silently empty on
    # every response and the mail client would open with a blank From.
    # Read the signed-in user instead. Demo mode has no user row, and
    # says so rather than inventing a sender.
    sender_name, sender_email = "Treatment Coordinator", ""
    sub = claims.get("sub")
    if sub and not claims.get("demo"):
        who = await execute_os_with_tenant(
            os_pool, tenant,
            "SELECT name, email FROM users WHERE user_id = $1", sub)
        if who:
            sender_name = who[0]["name"] or sender_name
            sender_email = who[0]["email"] or ""
    contact = TENANT_CONTACTS.get(tenant, {})

    checked = await execute_os_with_tenant(
        os_pool, tenant,
        # The SELECTED day, not today. Looking at yesterday must show
        # who arrived yesterday — reading today's check-ins against
        # yesterday's schedule would mark the wrong people present.
        "SELECT pred_request_id, checked_in_at FROM checkin_events "
        "WHERE tenant_id = $1 AND checkin_day = $2",
        tenant, appt_date,
    )
    checked_at = {r["pred_request_id"]: r["checked_in_at"] for r in checked}

    out: list[dict] = []
    for row in rows:
        rid = row["pred_request_id"]

        lines = await fetch_with_tenant(
            sim, tenant,
            "SELECT cdt_code FROM procedure_lines WHERE pred_request_id = $1 "
            "ORDER BY line_no",
            rid,
        )
        codes = [r["cdt_code"] for r in lines]

        # The engine's own money, not a second opinion.
        try:
            context = await _build_context(request, rid)
            coverage = resolve_coverage(context, context.catalogue_rules)
            csum = coverage["summary"]
            max_after = _f(csum.get("annual_max_remaining_after"))
            patient_pays = _f(csum.get("total_patient_pays"))
            downgraded = [
                p["cdt_code"] for p in coverage["procedures"]
                if p.get("downgrade_applied")
            ]
        except Exception as exc:  # noqa: BLE001
            logger.warning("check-in coverage failed for %s: %s", rid, exc)
            max_after = patient_pays = None
            downgraded = []

        alerts: list[dict] = []

        # pred_required_codes, NOT procedure_lines.requires_pred — that
        # column is true on every line in this corpus, including a
        # cleaning, and flagging a prophy as needing pre-approval turns
        # the whole screen into noise.
        pred_codes = row["pred_required_codes"] or []
        if isinstance(pred_codes, str):
            pred_codes = json.loads(pred_codes)
        if pred_codes:
            alerts.append({
                "type": "pre_d_required",
                "title": "Pre-determination required",
                "detail": (
                    f"{_payer_name(row['payer_id'])} requires pre-approval for "
                    f"{', '.join(pred_codes)}. It must be submitted and "
                    f"approved before treatment begins."
                ),
            })

        if max_after is not None and max_after < 200:
            used = _f(row["annual_maximum_used"])
            total = _f(row["annual_maximum"])
            alerts.append({
                "type": "annual_max_warning",
                "title": "Annual maximum nearly exhausted",
                "detail": (
                    f"Plan maximum ${total:,.0f} a year, ${used:,.0f} used so "
                    f"far. About ${max_after:,.0f} left after today's visit."
                ),
            })

        if downgraded:
            alerts.append({
                "type": "downgrade",
                "title": "Plan pays at a cheaper material's rate",
                "detail": (
                    f"{', '.join(downgraded)} is reimbursed at a lower code's "
                    f"rate. The patient owes the difference."
                ),
            })

        if row["has_bundling_conflict"]:
            alerts.append({
                "type": "bundling",
                "title": "Two procedures are billed together",
                "detail": (
                    "Billing is documenting them separately. Do not quote a "
                    "final figure to the patient yet."
                ),
            })

        # deductible_met is an AMOUNT, not a boolean — 50.00 against a
        # 100.00 total is half met. bool(50.00) would say "met".
        ded_total = _f(row["deductible_total"])
        ded_met_amt = _f(row["deductible_met"])
        ded_met = ded_total > 0 and ded_met_amt >= ded_total

        # enrollment_date comes back as a STRING on this column, not a
        # date — asyncpg only adapts a real DATE/TIMESTAMP type. Parse
        # rather than assume, and fall through to None if it is neither.
        months = None
        enrolled = row["enrollment_date"]
        if isinstance(enrolled, str):
            try:
                enrolled = date.fromisoformat(enrolled[:10])
            except ValueError:
                enrolled = None
        if isinstance(enrolled, datetime):
            enrolled = enrolled.date()
        if isinstance(enrolled, date):
            months = (date.today() - enrolled).days // 30

        at = checked_at.get(rid)
        status = "checked_in" if at else ("heads_up" if alerts else "clear")

        out.append({
            "pred_request_id": rid,
            "patient_name": row["patient_name"],
            "patient_email": row["patient_email"],
            "patient_phone": row["patient_phone"],
            # Repeated on every row rather than hoisted, because this
            # endpoint returns a bare list and the client renders one
            # card per row. Cheap: four short strings.
            "sender_name": sender_name,
            "sender_email": sender_email,
            "practice_email": contact.get("email", ""),
            "practice_phone": contact.get("phone", ""),
            "appointment_time": schedule[rid]["time"],
            "procedures": codes,
            # The schedule's own wording when the practice set one,
            # otherwise derived from the CDT codes on the pre-D.
            "procedure_summary": (
                schedule[rid]["summary"] or _procedure_summary(codes)
            ),
            "payer_name": _payer_name(row["payer_id"]),
            "payer_id": row["payer_id"],
            # From eligibility_profiles — the payer's own identifier,
            # which is what the card in the patient's wallet says.
            # patients.member_id holds a DIFFERENT value for the same
            # person; the two disagree in this corpus and the payer's
            # wins at a check-in desk.
            "member_id": row["member_id"],
            "enrollment_months": months,
            "provider_name": _display(row["provider_npi"]),
            "provider_npi": row["provider_npi"],
            "insurance_active": True,
            "provider_in_network": True,
            "deductible_met": ded_met,
            "deductible_total": ded_total or None,
            "deductible_remaining": (
                None if ded_total == 0 else max(ded_total - ded_met_amt, 0.0)
            ),
            "annual_max": _f(row["annual_maximum"]) or None,
            "annual_max_remaining": _f(row["annual_maximum_remaining"]) or None,
            "annual_max_remaining_after": max_after,
            "patient_pays_today": patient_pays,
            "alerts": alerts,
            "status": status,
            "checked_in_at": at.isoformat() if at else None,
        })

    # Sort by status, then by CLOCK time. The schedule query is ordered
    # by appointment_time, so its index is the clock — sorting the
    # display string would put "11:00 AM" before "9:00 AM".
    order = {"heads_up": 0, "clear": 1, "checked_in": 2}
    out.sort(key=lambda x: (order.get(x["status"], 3),
                            schedule[x["pred_request_id"]]["slot"]))
    return out


class AppointmentIn(BaseModel):
    tenant_id: str
    pred_request_id: str
    patient_name: str
    appointment_date: str  # YYYY-MM-DD
    appointment_time: str  # HH:MM
    procedure_summary: str
    provider_npi: str
    pms_source: str = "manual"
    pms_appointment_id: str | None = None


@router.post("/integrations/appointments")
async def create_appointment(
    body: AppointmentIn, request: Request, claims=Depends(require_admin)
) -> dict:
    """Accept an appointment from a practice management system.

    accord_admin only. This writes into ANOTHER tenant's schedule by
    design — an integration runs on behalf of the practice, not as one
    of its users — which is exactly why it is not open to a practice
    login. When a per-tenant API key exists, that is what should carry
    this instead of a human admin's token.
    """
    _, os_pool = _pools(request)
    try:
        appt_date = date.fromisoformat(body.appointment_date)
        hh, mm = (int(x) for x in body.appointment_time.split(":")[:2])
        appt_time = dtime(hh, mm)
    except (ValueError, TypeError):
        raise HTTPException(
            422,
            "appointment_date must be YYYY-MM-DD and appointment_time HH:MM",
        )

    rows = await execute_os_with_tenant(
        os_pool, body.tenant_id,
        """
        INSERT INTO appointments
          (tenant_id, pred_request_id, patient_name, appointment_date,
           appointment_time, procedure_summary, provider_npi,
           pms_source, pms_appointment_id)
        VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
        ON CONFLICT (tenant_id, pred_request_id, appointment_date)
        DO UPDATE SET appointment_time = EXCLUDED.appointment_time,
                      procedure_summary = EXCLUDED.procedure_summary,
                      patient_name = EXCLUDED.patient_name,
                      provider_npi = EXCLUDED.provider_npi,
                      pms_source = EXCLUDED.pms_source,
                      pms_appointment_id = EXCLUDED.pms_appointment_id
        RETURNING appointment_id
        """,
        body.tenant_id, body.pred_request_id, body.patient_name,
        appt_date, appt_time, body.procedure_summary, body.provider_npi,
        body.pms_source, body.pms_appointment_id,
    )
    return {
        "status": "created",
        "appointment_id": rows[0]["appointment_id"] if rows else None,
    }


class CheckInRequest(BaseModel):
    pred_request_id: str
    patient_name: str


@router.post("/checkin")
async def check_in_patient(
    body: CheckInRequest,
    request: Request,
    claims=Depends(require_claims_or_demo),
) -> dict:
    """Record that a patient arrived. Idempotent per patient per day."""
    # Same boundary as every other route: you may only check in a
    # patient whose pre-D belongs to your practice.
    tenant = await _tenant_for(request, body.pred_request_id)
    assert_tenant_allowed(claims, tenant)
    _, os_pool = _pools(request)

    rows = await execute_os_with_tenant(
        os_pool, tenant,
        """
        INSERT INTO checkin_events
            (pred_request_id, tenant_id, patient_name, checked_in_by)
        VALUES ($1, $2, $3, $4)
        ON CONFLICT (tenant_id, pred_request_id, checkin_day) DO UPDATE
            SET patient_name = EXCLUDED.patient_name
        RETURNING checked_in_at
        """,
        body.pred_request_id, tenant, body.patient_name,
        claims.get("sub", "demo-user"),
    )
    return {
        "status": "checked_in",
        "pred_request_id": body.pred_request_id,
        "patient_name": body.patient_name,
        "checked_in_at": rows[0]["checked_in_at"].isoformat() if rows else None,
    }


# ─────────────────────────────────────────────────────────────────────
# Practice administration — what a dso_owner may see about their OWN
# practice. Both routes take the tenant from the CLAIMS, never from the
# query string, for the reason spelled out on require_practice_admin.
# ─────────────────────────────────────────────────────────────────────

def _tenant_for_admin(claims: dict, tenant_id: str | None) -> str:
    """The tenant these routes will answer about.

    accord_admin may name one (and must, having none of their own); a
    practice owner gets theirs regardless of what they asked for.
    """
    own = tenant_filter(claims)
    if own:
        return own
    if not tenant_id:
        raise HTTPException(422, "tenant_id is required for accord_admin")
    return tenant_id


@router.get("/admin/overlays")
async def list_overlays(
    request: Request,
    tenant_id: str | None = None,
    claims=Depends(require_practice_admin),
) -> list[dict]:
    """The practice's own coverage rules — catalogue layer 3.

    These are the rules that WIN over the payer's: `rule_overrides` is
    applied last (rule_loader.LAYER_OVERLAY), so a practice owner
    reading this page is reading the only layer they control. Expired
    rows are included with `active` false rather than hidden — a rule
    that stopped applying last month is the first thing you look for
    when a decision changed.
    """
    tenant = _tenant_for_admin(claims, tenant_id)
    sim, _ = _pools(request)
    rows = await fetch_with_tenant(
        sim, tenant,
        """
        SELECT payer_id, cdt_code, rule_overrides, reason, active,
               effective_from, effective_to
        FROM overlay_rules
        WHERE tenant_id = $1
        ORDER BY active DESC, payer_id, cdt_code
        """,
        tenant,
    )
    out = []
    for r in rows:
        raw = r["rule_overrides"]
        overrides = json.loads(raw) if isinstance(raw, str) else (raw or {})
        out.append({
            "payer_id": r["payer_id"],
            "payer_name": _payer_name(r["payer_id"]),
            "cdt_code": r["cdt_code"],
            "procedure": _PROC_NAMES.get(r["cdt_code"], r["cdt_code"]),
            "rule_overrides": overrides,
            "reason": r["reason"],
            "active": r["active"],
            "effective_from": (
                r["effective_from"].isoformat() if r["effective_from"] else None
            ),
            "effective_to": (
                r["effective_to"].isoformat() if r["effective_to"] else None
            ),
        })
    return out


@router.get("/admin/practice")
async def practice_settings(
    request: Request,
    tenant_id: str | None = None,
    claims=Depends(require_practice_admin),
) -> dict:
    """Providers and payer mix for one practice.

    The name and address are NOT here — they come back on the token
    (auth.TENANT_NAMES), so a page that already knows who is signed in
    does not need a round trip to render its own heading.
    """
    tenant = _tenant_for_admin(claims, tenant_id)
    sim, _ = _pools(request)

    providers = await fetch_with_tenant(
        sim, tenant,
        "SELECT provider_npi, first_name, last_name, credential, "
        "       network_status, oig_excluded "
        "FROM providers WHERE tenant_id = $1 ORDER BY last_name",
        tenant,
    )

    # "Primary payer" is not configured anywhere — it is whichever payer
    # the practice's cases actually run against. Counting is the only
    # honest way to answer it.
    payers = await fetch_with_tenant(
        sim, tenant,
        """
        SELECT payer_id, COUNT(*) AS n
        FROM pred_requests
        WHERE tenant_id = $1 AND payer_id IS NOT NULL
        GROUP BY payer_id
        ORDER BY n DESC
        """,
        tenant,
    )

    return {
        "tenant_id": tenant,
        "providers": [
            {
                "provider_npi": p["provider_npi"],
                "name": (
                    f"{(p['first_name'] or '').title()} "
                    f"{(p['last_name'] or '').title()}"
                ).strip(),
                "credential": p["credential"] or "",
                "network_status": p["network_status"] or "unknown",
                # Surfaced, not filtered. A provider on the OIG
                # exclusion list is the single most expensive thing on
                # this page — hiding the row would hide the problem.
                "oig_excluded": bool(p["oig_excluded"]),
            }
            for p in providers
        ],
        "payers": [
            {
                "payer_id": p["payer_id"],
                "payer_name": _payer_name(p["payer_id"]),
                "patients": p["n"],
            }
            for p in payers
        ],
    }



class SMSRequest(BaseModel):
    pred_request_id: str
    patient_name: str
    patient_phone: str
    message: str


@router.post("/communications/sms")
async def send_sms(
    req: SMSRequest,
    request: Request,
    claims=Depends(require_claims_or_demo),
) -> dict:
    """Text a patient their estimate summary.

    ⚠ NOTHING IS SENT. This logs the message and returns success. AWS
    SNS is not wired: there is no SNS topic, no spend limit, no opt-out
    handling and no origination number, and switching it on without
    those is how a demo texts a real phone.

    To go live, uncomment the boto3 block AND first:
      - set an SMS monthly spend limit on the account
      - register an origination identity (10DLC in the US)
      - implement STOP/HELP handling, which is a legal requirement
      - stop accepting the phone number from the CLIENT and read it
        from `patients` server-side, exactly as the check-in screen
        does — see below

    THE NUMBER IN THIS REQUEST IS NOT TRUSTED. It arrives from the
    browser, so a caller could post any number with any patient's name
    attached. It is echoed back for the demo but never dialled; the
    production path must look the number up from the pre-D's own
    patient row under the caller's tenant.
    """
    tenant = tenant_filter(claims)
    if tenant:
        # Same boundary as every other route: you may only message a
        # patient whose pre-D belongs to your practice.
        owner = await _tenant_for(request, req.pred_request_id)
        assert_tenant_allowed(claims, owner)

    if len(req.message) > 320:
        raise HTTPException(422, "message is longer than two SMS segments")

    # PRODUCTION — read the number from the database, not the request:
    #
    # sim, _ = _pools(request)
    # rows = await fetch_with_tenant(
    #     sim, owner,
    #     "SELECT p.mobile_phone FROM patients p "
    #     "JOIN pred_requests pr ON pr.patient_id = p.patient_id "
    #     "WHERE pr.pred_request_id = $1", req.pred_request_id)
    # to_number = rows[0]["mobile_phone"] if rows else None
    #
    # import boto3
    # sns = boto3.client("sns", region_name="us-east-1")
    # sns.publish(
    #     PhoneNumber=to_number,
    #     Message=req.message,
    #     MessageAttributes={
    #         "AWS.SNS.SMS.SenderID": {
    #             "DataType": "String",
    #             "StringValue": "AccordDental",
    #         },
    #         "AWS.SNS.SMS.SMSType": {
    #             "DataType": "String",
    #             "StringValue": "Transactional",
    #         },
    #     },
    # )

    # The message body is NOT logged. It carries a patient's name and
    # what they owe, and application logs are the wrong place for both.
    logger.info(
        "sms requested by %s for %s (%d chars) — not sent, SNS not wired",
        claims.get("sub", "demo"), req.pred_request_id, len(req.message),
    )
    return {
        "status": "logged",
        "to": req.patient_phone,
        "patient": req.patient_name,
        "note": (
            "Demo mode — nothing was sent. AWS SNS is not connected; "
            "see send_sms() for what production needs first."
        ),
    }


# ─────────────────────────────────────────────────────────────────────
# Submission, denial and appeal tracking — migrations/003.
#
# ⚠ NO fetch_os_with_tenant / execute_os_with_tenant ARE DEFINED HERE.
# execute_os_with_tenant already exists in core/db/connection.py, reads
# AND writes, and has twelve callers. Redefining it to return fetchrow
# would break every one of them. Its version is also the safe one: the
# tenant goes in as a BOUND PARAMETER to set_config(..., is_local=true)
# inside a transaction, where the proposed
# `SET app.tenant_id = '{tenant}'` would be string interpolation into
# SQL and a session-level setting that outlives the request on a pooled
# connection — the next borrower would inherit somebody else's tenant.
# ─────────────────────────────────────────────────────────────────────


class SubmitRequest(BaseModel):
    pred_request_id: str
    patient_name: str
    payer_id: str
    payer_name: str
    submission_method: str = "manual"
    notes: str | None = None


@router.post("/decisions/{pred_request_id}/submit")
async def submit_pred(
    pred_request_id: str,
    req: SubmitRequest,
    request: Request,
    claims=Depends(require_claims),
) -> dict:
    """Record that a pre-D went to the payer.

    ⚠ IT DOES NOT GO TO THE PAYER. X12 278 is not wired and neither is
    NEA FastAttach; this writes the event a practice needs to answer
    "when did we send it and who sent it", which is what nothing could
    answer before. The response says so rather than implying a
    transmission happened.
    """
    owner = await _tenant_for(request, pred_request_id)
    assert_tenant_allowed(claims, owner)
    # accord_admin has no tenant of their own; write under the pre-D's.
    tenant = tenant_filter(claims) or owner
    _, os_pool = _pools(request)

    rows = await execute_os_with_tenant(
        os_pool, tenant,
        """
        INSERT INTO submission_events
            (tenant_id, pred_request_id, patient_name, payer_id,
             payer_name, submitted_by, submission_method, notes)
        VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
        ON CONFLICT (tenant_id, pred_request_id) DO UPDATE
            SET submitted_at = NOW(),
                status = 'submitted',
                submission_method = EXCLUDED.submission_method,
                notes = EXCLUDED.notes
        RETURNING submission_id, submitted_at, status,
                  expected_response_days
        """,
        tenant, pred_request_id, req.patient_name, req.payer_id,
        req.payer_name, claims.get("sub"), req.submission_method, req.notes,
    )
    if not rows:
        raise HTTPException(500, "submission was not recorded")
    row = rows[0]
    return {
        "status": "submitted",
        "submission_id": row["submission_id"],
        "submitted_at": _iso(row["submitted_at"]),
        "pred_request_id": pred_request_id,
        "message": (
            f"Submission to {req.payer_name} recorded. Expected response "
            f"in {row['expected_response_days']} business days. Nothing "
            f"was transmitted - X12 278 is not connected."
        ),
    }


def _days_until(when) -> Optional[int]:
    return (when.date() - date.today()).days if when else None


@router.get("/denials")
async def get_denials(
    request: Request, claims=Depends(require_claims_or_demo)
) -> list[dict]:
    """Payer denials for this practice, newest first."""
    tenant = tenant_filter(claims) or DEFAULT_TENANT
    _, os_pool = _pools(request)
    rows = await execute_os_with_tenant(
        os_pool, tenant,
        """
        SELECT d.denial_id, d.pred_request_id, d.patient_name, d.payer_id,
               d.denied_at, d.denial_reason, d.denial_reason_code,
               d.denied_amount, d.appeal_deadline, d.appeal_viable,
               d.appeal_probability, d.notes,
               EXISTS (
                 SELECT 1 FROM appeal_events a
                 WHERE a.pred_request_id = d.pred_request_id
                   AND a.tenant_id = d.tenant_id
               ) AS appeal_filed
        FROM denial_events d
        WHERE d.tenant_id = $1
        ORDER BY d.denied_at DESC
        """,
        tenant,
    )
    return [
        {
            **r,
            "payer_name": _payer_name(r["payer_id"]),
            "denied_at": _iso(r["denied_at"]),
            "appeal_deadline": _iso(r["appeal_deadline"]),
            "days_to_deadline": _days_until(r["appeal_deadline"]),
            "denied_amount": _f(r["denied_amount"]),
        }
        for r in rows
    ]


class AppealRequest(BaseModel):
    pred_request_id: str
    patient_name: str
    payer_id: str
    denial_id: str | None = None
    appeal_type: str = "standard"
    notes: str | None = None


@router.post("/appeals")
async def file_appeal(
    req: AppealRequest, request: Request, claims=Depends(require_claims)
) -> dict:
    """File an appeal against a denied pre-D."""
    # Not in the brief, and the same boundary every other write has:
    # without it a biller could file an appeal onto another practice's
    # case by posting its id.
    owner = await _tenant_for(request, req.pred_request_id)
    assert_tenant_allowed(claims, owner)
    tenant = tenant_filter(claims) or owner
    _, os_pool = _pools(request)

    rows = await execute_os_with_tenant(
        os_pool, tenant,
        """
        INSERT INTO appeal_events
            (tenant_id, pred_request_id, denial_id, patient_name,
             payer_id, filed_by, appeal_type, status, notes)
        VALUES ($1,$2,$3,$4,$5,$6,$7,'filed',$8)
        ON CONFLICT (tenant_id, pred_request_id) DO NOTHING
        RETURNING appeal_id, filed_at, status
        """,
        tenant, req.pred_request_id, req.denial_id, req.patient_name,
        req.payer_id, claims.get("sub"), req.appeal_type, req.notes,
    )

    if not rows:
        # ON CONFLICT DO NOTHING returns NO ROW. The brief then reads
        # row['appeal_id'] off it, which is a 500 the second time
        # anyone clicks. An appeal already on file is not an error -
        # say which one it is.
        existing = await execute_os_with_tenant(
            os_pool, tenant,
            "SELECT appeal_id, filed_at, status FROM appeal_events "
            "WHERE tenant_id = $1 AND pred_request_id = $2",
            tenant, req.pred_request_id,
        )
        if not existing:
            raise HTTPException(500, "appeal was not recorded")
        row = existing[0]
        return {
            "status": row["status"],
            "appeal_id": row["appeal_id"],
            "filed_at": _iso(row["filed_at"]),
            "message": "An appeal is already on file for this pre-D.",
            "already_filed": True,
        }

    row = rows[0]
    return {
        "status": "filed",
        "appeal_id": row["appeal_id"],
        "filed_at": _iso(row["filed_at"]),
        "message": "Appeal recorded. Nothing was sent to the payer.",
        "already_filed": False,
    }


@router.get("/appeals")
async def get_appeals(
    request: Request, claims=Depends(require_claims_or_demo)
) -> list[dict]:
    """Appeals for this practice, newest first, with their denial."""
    tenant = tenant_filter(claims) or DEFAULT_TENANT
    _, os_pool = _pools(request)
    rows = await execute_os_with_tenant(
        os_pool, tenant,
        """
        SELECT a.appeal_id, a.pred_request_id, a.patient_name, a.payer_id,
               a.filed_at, a.appeal_type, a.status, a.resolved_at,
               a.recovered_amount, a.notes,
               d.denial_reason, d.denied_amount, d.appeal_probability,
               d.appeal_deadline
        FROM appeal_events a
        LEFT JOIN denial_events d
               ON d.denial_id = a.denial_id AND d.tenant_id = a.tenant_id
        WHERE a.tenant_id = $1
        ORDER BY a.filed_at DESC
        """,
        tenant,
    )
    return [
        {
            **r,
            "payer_name": _payer_name(r["payer_id"]),
            "filed_at": _iso(r["filed_at"]),
            "resolved_at": _iso(r["resolved_at"]),
            "appeal_deadline": _iso(r["appeal_deadline"]),
            "days_to_deadline": _days_until(r["appeal_deadline"]),
            "denied_amount": _f(r["denied_amount"]),
            # None, not 0.0: an unresolved appeal has recovered nothing
            # YET, which is a different fact from recovering zero.
            "recovered_amount": (
                _f(r["recovered_amount"])
                if r["recovered_amount"] is not None
                else None
            ),
        }
        for r in rows
    ]


@router.get("/analytics/billing")
async def billing_analytics(
    request: Request, claims=Depends(require_claims_or_demo)
) -> dict:
    """What revenue ops needs on one screen.

    Two different notions of "denied" live here and they are NOT the
    same number, so both are returned under their own names:

      cases.denied     the ENGINE's decision on a pre-D - what the
                       policy model predicts before anything is sent
      denials.total    what a payer actually came back and refused,
                       from denial_events

    The brief reported the engine's count under `denials.total` while
    listing reasons from denial_events beside it, so the header and the
    breakdown under it would have disagreed - 7 against 1 today.
    """
    tenant = tenant_filter(claims) or DEFAULT_TENANT
    sim_pool, os_pool = _pools(request)

    subs = await execute_os_with_tenant(
        os_pool, tenant,
        """
        SELECT COUNT(*) AS total_submitted,
               COUNT(*) FILTER (WHERE status = 'submitted') AS pending,
               COUNT(*) FILTER (WHERE status = 'acknowledged') AS acknowledged,
               COUNT(*) FILTER (WHERE status = 'responded') AS responded
        FROM submission_events WHERE tenant_id = $1
        """,
        tenant,
    )

    reasons = await execute_os_with_tenant(
        os_pool, tenant,
        """
        SELECT denial_reason,
               COUNT(*) AS reason_count,
               COALESCE(SUM(denied_amount), 0) AS reason_amount
        FROM denial_events WHERE tenant_id = $1
        GROUP BY denial_reason
        ORDER BY reason_count DESC
        """,
        tenant,
    )

    dtotals = await execute_os_with_tenant(
        os_pool, tenant,
        """
        SELECT COUNT(*) AS total_denials,
               COALESCE(SUM(denied_amount), 0) AS total_denied_amount,
               COUNT(*) FILTER (WHERE appeal_viable) AS appeal_viable
        FROM denial_events WHERE tenant_id = $1
        """,
        tenant,
    )

    appeals = await execute_os_with_tenant(
        os_pool, tenant,
        """
        SELECT COUNT(*) AS total_appeals,
               COUNT(*) FILTER (WHERE status = 'overturned') AS overturned,
               COUNT(*) FILTER (WHERE status = 'upheld') AS upheld,
               COUNT(*) FILTER (WHERE status IN ('filed','pending')) AS pending,
               COALESCE(SUM(recovered_amount), 0) AS total_recovered
        FROM appeal_events WHERE tenant_id = $1
        """,
        tenant,
    )

    # THROUGH fetch_with_tenant, not sim_pool.fetch. A raw pool call
    # carries no app.tenant_id, and RLS then returns zero rows with no
    # error - the practice would read as having no cases at all.
    cases = await fetch_with_tenant(
        sim_pool, tenant,
        """
        SELECT COUNT(*) AS total_cases,
               COUNT(*) FILTER (WHERE ps.decision = 'approved') AS approved,
               COUNT(*) FILTER (WHERE ps.decision = 'denied') AS denied,
               COUNT(*) FILTER (WHERE ps.decision = 'pended') AS pended,
               COALESCE(SUM(pr.total_case_value), 0) AS total_value
        FROM pred_requests pr
        JOIN pred_states ps ON ps.pred_request_id = pr.pred_request_id
        WHERE pr.tenant_id = $1
        """,
        tenant,
    )

    s = subs[0] if subs else {}
    d = dtotals[0] if dtotals else {}
    a = appeals[0] if appeals else {}
    c = cases[0] if cases else {}
    filed = int(a.get("total_appeals") or 0)
    resolved = int(a.get("overturned") or 0) + int(a.get("upheld") or 0)

    return {
        "submissions": {
            "total": int(s.get("total_submitted") or 0),
            "pending": int(s.get("pending") or 0),
            "acknowledged": int(s.get("acknowledged") or 0),
            "responded": int(s.get("responded") or 0),
        },
        "denials": {
            "total": int(d.get("total_denials") or 0),
            "amount": _f(d.get("total_denied_amount")),
            "appeal_viable": int(d.get("appeal_viable") or 0),
            "reasons": [
                {
                    "reason": r["denial_reason"],
                    "count": int(r["reason_count"]),
                    "amount": _f(r["reason_amount"]),
                }
                for r in reasons
            ],
        },
        "appeals": {
            "total": filed,
            "overturned": int(a.get("overturned") or 0),
            "upheld": int(a.get("upheld") or 0),
            "pending": int(a.get("pending") or 0),
            "recovered": _f(a.get("total_recovered")),
            # Of those RESOLVED, not of those filed. A 50% "win rate"
            # counted against pending appeals falls every time one is
            # filed, which is the opposite of what it should do.
            "overturn_rate": (
                round(int(a.get("overturned") or 0) / resolved, 3)
                if resolved
                else None
            ),
        },
        "cases": {
            "total": int(c.get("total_cases") or 0),
            "approved": int(c.get("approved") or 0),
            "denied": int(c.get("denied") or 0),
            "pended": int(c.get("pended") or 0),
            "total_value": _f(c.get("total_value")),
        },
    }
