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
    require_billing,
    require_claims,
    require_clinician,
    require_clinician_cap,
    require_document_chase,
    require_engine_feedback,
    require_handoff_sender,
    require_patient_contact,
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
    sim, os_pool = _pools(request)
    tenant = await _tenant_for(request, pred_request_id)
    try:
        # BOTH pools. Without os_pool the context carries no
        # denial_event, so resolve_appeal_viability falls back to
        # payer_responses.appeal_deadline — the fixture that says
        # 2026-10-05 for a denial whose real window closed 2026-07-22.
        context = await ContextBuilder(sim, os_pool).build(
            pred_request_id, tenant)
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
    flags = {k: bool(v) for k, v in flags.items()}

    # ⚠ RECONCILE no_fraud_signals AGAINST THE BUNDLE.
    #
    # The simulator computes it as "no FRAUD_* code in
    # pred_states.open_conditions" — and open_conditions has never
    # contained one: zero rows across the corpus. Since the rename it
    # cannot ever match, because no code starts with FRAUD_ any more.
    # This reconcile is now the only thing that computes the flag. Integrity findings
    # live in the persona bundle instead, so the flag read true on a
    # case showing two of them, which is the readiness badge and the
    # conditions list contradicting each other on one screen.
    #
    # The real fix belongs in dental-simulator's readiness_assembler,
    # which is read-only from here (CONTEXT.md RULE 15). This corrects
    # the answer at the point of use and leaves the engine's own copy
    # untouched.
    if "no_fraud_signals" in flags:
        _, os_pool = _pools(request)
        try:
            bundle_rows = await execute_os_with_tenant(
                os_pool, tenant,
                "SELECT all_signals FROM persona_bundles "
                "WHERE tenant_id = $1 AND pred_request_id = $2 AND is_current",
                tenant, pred_request_id,
            )
            codes = {
                sig.get("signal_code")
                for row in bundle_rows
                for sig in _json(row["all_signals"], [])
                if isinstance(sig, dict)
            }
            if any(str(c).startswith("INTEGRITY_") for c in codes if c):
                flags["no_fraud_signals"] = False
        except Exception as exc:  # noqa: BLE001 — never 500 the bundle
            logger.warning("integrity reconcile failed for %s: %s",
                           pred_request_id, exc)
    return flags


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


@router.get("/decisions/signed")
async def signed_on(
    request: Request,
    date_param: str | None = Query(None, alias="date"),
    claims=Depends(require_claims_or_demo),
) -> list[dict]:
    """Pre-Ds a clinician SIGNED on one day. Defaults to today.

    The dentist's counterpart to /decisions/submitted. The two are
    deliberately different lists now that signing and filing are
    different acts by different people: a case the dentist signed this
    morning may not go to the payer until Kim works her queue this
    afternoon, and the dentist's screen should show what HE did, not
    what happened to it afterwards.

    DISTINCT ON because clinical_attestations is append-only — a
    re-signed pre-D has more than one row and would otherwise appear
    twice in a list of five.
    """
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
        SELECT DISTINCT ON (a.pred_request_id)
               a.attestation_id, a.pred_request_id, a.attested_by,
               a.attested_at, a.submission_id,
               u.name AS attested_by_name,
               s.submitted_at
        FROM clinical_attestations a
        LEFT JOIN users u ON u.user_id = a.attested_by
        LEFT JOIN submission_events s
               ON s.tenant_id = a.tenant_id
              AND s.pred_request_id = a.pred_request_id
        WHERE a.tenant_id = $1 AND a.attested_at::date = $2
        ORDER BY a.pred_request_id, a.attested_at DESC
        """,
        tenant, on,
    )
    return [
        {
            "attestation_id": r["attestation_id"],
            "pred_request_id": r["pred_request_id"],
            "attested_by": r["attested_by"],
            "attested_by_name": r["attested_by_name"],
            "attested_at": _iso(r["attested_at"]),
            # Whether Kim has filed it yet. NULL means signed and
            # waiting, which is the normal state for most of the day.
            "submitted_at": _iso(r["submitted_at"]),
        }
        for r in rows
    ]


# ─────────────────────────────────────────────────────────────────────
# needs_clinician — does this case want the dentist before it goes out?
#
# ⚠ TWO OF THE FOUR RULES NAME TABLES THAT DID NOT EXIST.
#   justification_events  -> is clinical_justifications, built in 004
#                            under a different name. Treated as the
#                            same thing.
#   clinical_handoffs     -> did not exist at all. Created in 005; the
#                            schema is mine, not the spec's.
#
# ⚠ CONDITIONS 2 AND 3 READ THE ENGINE'S SIGNALS, NOT downgrade_matrix
# AND bundling_rules DIRECTLY. Those two joins are exactly what the
# coverage resolver already ran to raise COVERAGE_DOWNGRADE_APPLIED and
# COVERAGE_BUNDLING_CONFLICT, and the queue ALREADY loads every
# bundle's signals to count `blocking` — so this costs nothing, where
# re-deriving through resolve_coverage() per row is what makes
# /checkin/today take seven seconds. Verified equivalent on all five
# scheduled cases: the signal is present exactly when the table join
# hits (A01 dm=1 br=1, D04 dm=1 br=0, B04 dm=0 br=1, U01/U02 neither).
# ─────────────────────────────────────────────────────────────────────

# Gaps a dentist can close from the chair.
#
# ⚠ WAVE 3 ONLY. The rule says a DOCUMENTS-WAVE signal, and documents
# is wave 3. The first cut also listed the wave-2 CLINICAL_XRAY_
# REQUIRED / CLINICAL_NARRATIVE_MISSING, which made all five scheduled
# cases need the clinician — a filter that selects everything is not a
# filter. Robert Thompson's cleaning carries CLINICAL_XRAY_REQUIRED
# and no wave-3 gap at all; he is exactly the case that should fall
# out. Wave is read off the signal rather than guessed from the name.
#
# DOC_MEMBER_ID_MISMATCH is deliberately absent: no clinician can fix
# an insurance card, and routing it to one is how it sits for a week.
_CLINICIAN_CAPTURABLE = {
    "DOC_XRAY_MISSING": "radiograph",
    "DOC_PERIO_CHART_MISSING": "perio charting",
    "DOC_NARRATIVE_MISSING": "narrative",
}
_DOCUMENTS_WAVE = 3

_DOWNGRADE_SIGNAL = "COVERAGE_DOWNGRADE_APPLIED"
_BUNDLING_SIGNAL = "COVERAGE_BUNDLING_CONFLICT"

# What the downgraded thing is called out loud, so the pill can read
# "Crown downgrade" rather than "D6065 downgrade".
_PROC_WORD = {
    "D2740": "Crown", "D2750": "Crown", "D6065": "Crown",
    "D2950": "Buildup", "D6010": "Implant", "D7953": "Graft",
}


def _needs_clinician(
    signals: list[dict],
    open_codes: set[str],
    justified: set[str],
    handoff: Optional[dict],
    procedure_codes: list[str],
) -> tuple[bool, Optional[str], int]:
    """(needs_clinician, needs_reason, cleared_count).

    needs_reason is built most-specific-first and capped at 40
    characters, because it renders in a pill. It is never truncated
    mid-word — a shorter phrase is chosen instead.
    """
    present = {s.get("signal_code") for s in signals}
    by_code = {s.get("signal_code"): s for s in signals}

    # 1 — an unmet documents-wave gap the clinician can close.
    gaps = list(dict.fromkeys(
        _CLINICIAN_CAPTURABLE[c]
        for c in open_codes
        if c in _CLINICIAN_CAPTURABLE
        and (by_code.get(c) or {}).get("wave") == _DOCUMENTS_WAVE
    ))

    # 2 and 3 — a downgrade or a bundling hit nobody has justified.
    downgrade = _DOWNGRADE_SIGNAL in present and _DOWNGRADE_SIGNAL not in justified
    bundling = _BUNDLING_SIGNAL in present and _BUNDLING_SIGNAL not in justified

    # 4 — somebody handed this case to the dentist and nobody read it.
    handed = handoff is not None

    # Everything the dentist has already answered on this case.
    cleared = len(justified & (present | set(_CLINICIAN_CAPTURABLE)))

    if not (gaps or downgrade or bundling or handed):
        return False, None, cleared

    # Name the procedure the finding is actually ABOUT, from the
    # signal's own data — billed_code on a downgrade, primary on a
    # bundle. Taking the first line instead called A01's crown
    # downgrade an "Implant downgrade", because D6010 is line 1.
    def _word_for(code: str, key: str) -> Optional[str]:
        data = (by_code.get(code) or {}).get("data") or {}
        cdt = data.get(key) if isinstance(data, dict) else None
        return _PROC_WORD.get(cdt or "")

    down_word = _word_for(_DOWNGRADE_SIGNAL, "billed_code")
    bund_word = _word_for(_BUNDLING_SIGNAL, "primary")
    fallback = next(
        (_PROC_WORD[c] for c in procedure_codes if c in _PROC_WORD), "Plan"
    )
    word = down_word or bund_word or fallback

    # Most specific first: a handoff is a person asking, which beats
    # anything the engine inferred.
    candidates: list[str] = []
    if handed:
        candidates.append("Handed to you — unread")
    if downgrade and gaps:
        candidates.append(
            f"{down_word or word} downgrade + missing {gaps[0]}"
        )
    if bundling and gaps:
        candidates.append(f"{bund_word or word} bundling risk + {gaps[0]}")
    if downgrade:
        candidates.append(f"{down_word or word} downgrade — justify or accept")
        candidates.append(f"{down_word or word} downgrade unjustified")
    if bundling:
        candidates.append(f"{bund_word or word} bundling risk — narrative only")
        candidates.append(f"{bund_word or word} bundling risk unjustified")
    if len(gaps) > 1:
        candidates.append(f"Missing {gaps[0]} + {gaps[1]}")
    if gaps:
        candidates.append(f"Missing {gaps[0]}")
    candidates.append("Clinician review needed")

    # First one that fits the pill. Never a mid-word truncation.
    reason = next((c for c in candidates if len(c) <= 40), "Clinician review")
    return True, reason, cleared


@router.get("/decisions/queue")
async def decisions_queue(
    request: Request,
    date_param: str | None = Query(None, alias="date"),
    # A FILTER, not a second endpoint. Absent, every row comes back
    # exactly as before — the four new fields are added to each row but
    # no row is removed, so Kim's call is unchanged in content and
    # ordering.
    needs_clinician: bool | None = Query(None),
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
    actionable: dict[str, int] = {}
    signals_by_id: dict[str, list[dict]] = {}
    open_by_id: dict[str, set[str]] = {}
    for b in bundles:
        signals = _json(b["all_signals"], [])
        signals_by_id[b["pred_request_id"]] = signals
        open_by_id[b["pred_request_id"]] = set(_open_condition_codes(signals))
        blocking[b["pred_request_id"]] = sum(
            1 for s in signals
            if isinstance(s, dict) and s.get("mode") == "human_approval"
        )
        # ⚠ THE SAME PREDICATE GET /decisions/:id/conditions USES.
        # `open` used to be len(pred_states.open_conditions), which is a
        # different set entirely — the queue said "2 open" about a case
        # whose conditions list returned five. One of those numbers was
        # always going to be wrong and there was no way to tell which.
        actionable[b["pred_request_id"]] = sum(
            1 for s in signals
            if isinstance(s, dict)
            and (s.get("mode") == "human_approval" or s.get("recommended_action"))
        )

    # Two more queries for the whole page, not two per row.
    just_rows = await execute_os_with_tenant(
        os_pool, tenant,
        "SELECT pred_request_id, signal_code FROM clinical_justifications "
        "WHERE tenant_id = $1 AND pred_request_id = ANY($2::text[])",
        tenant, list(order),
    )
    justified_by_id: dict[str, set[str]] = {}
    for j in just_rows:
        justified_by_id.setdefault(j["pred_request_id"], set()).add(
            j["signal_code"]
        )

    # Who has actually signed. One query for the page. clinical_
    # attestations is append-only, so the LATEST row is the live one —
    # DISTINCT ON rather than a plain select, or a re-signed pre-D
    # would return two rows and double-count.
    att_rows = await execute_os_with_tenant(
        os_pool, tenant,
        "SELECT DISTINCT ON (pred_request_id) pred_request_id, attested_by, "
        "       attested_at "
        "FROM clinical_attestations "
        "WHERE tenant_id = $1 AND pred_request_id = ANY($2::text[]) "
        "ORDER BY pred_request_id, attested_at DESC",
        tenant, list(order),
    )
    attested_by_id = {a["pred_request_id"]: a for a in att_rows}

    handoff_rows = await execute_os_with_tenant(
        os_pool, tenant,
        "SELECT DISTINCT ON (pred_request_id) pred_request_id, handoff_id, "
        "       from_user, message, created_at, to_role, read_at "
        "FROM clinical_handoffs "
        "WHERE tenant_id = $1 AND pred_request_id = ANY($2::text[]) "
        "  AND to_role = $3 "
        "ORDER BY pred_request_id, created_at DESC",
        # ADDRESSED TO THE CALLER, not hardcoded to the dentist. The
        # note is a message between two named people about a patient;
        # returning the dentist's copy to whoever asked meant Kim's
        # queue carried it too. accord_admin sees the dentist's, which
        # is the queue they are looking at when they view the workbench.
        #
        # ⚠ READ ONES COME BACK TOO. Filtering on read_at IS NULL here
        # meant the note vanished the instant the dentist opened the
        # case — the client marks it read on render, the queue refetched,
        # and the message they were about to read was gone. read_at now
        # decides whether the case still NEEDS them, not whether they
        # are allowed to see what was said.
        tenant, list(order),
        "dentist" if claims.get("role") == "accord_admin" else claims.get("role"),
    )
    handoff_by_id = {h["pred_request_id"]: h for h in handoff_rows}

    # The lines drive the wording of the pill ("Crown downgrade"), and
    # one query covers every case on the page.
    line_rows = await fetch_with_tenant(
        sim, tenant,
        "SELECT pred_request_id, cdt_code FROM procedure_lines "
        "WHERE pred_request_id = ANY($1::text[]) ORDER BY line_no",
        list(order),
    )
    codes_by_id: dict[str, list[str]] = {}
    for l in line_rows:
        codes_by_id.setdefault(l["pred_request_id"], []).append(l["cdt_code"])

    out: list[dict] = []
    for row in rows:
        rid = row["pred_request_id"]
        conditions = _json(row["open_conditions"], [])
        decision = row["decision"] or "pending"
        ho = handoff_by_id.get(rid)
        # Only an UNREAD note puts the case in the "needs you" bucket.
        # A note already read stays on the card as context.
        unread = ho if ho and ho["read_at"] is None else None
        needs, reason, cleared = _needs_clinician(
            signals_by_id.get(rid, []),
            open_by_id.get(rid, set()),
            justified_by_id.get(rid, set()),
            unread,
            codes_by_id.get(rid, []),
        )
        out.append({
            "id": rid,
            "patient": row["patient_name"],
            "finding": _queue_finding(conditions, row["decision"]),
            "charges": _f(row["total_case_value"]),
            "payer": _payer_name(row["payer_id"]),
            # The id as well as the label: POST /decisions/:id/submit
            # records payer_id, and reverse-mapping a display name back
            # to an id in the browser is how "Delta Dental PPO" ends up
            # filed against a payer that does not exist.
            "payer_id": row["payer_id"],
            "status": decision,
            # Counts what the conditions endpoint would return for this
            # pre-D, including the synthesised attestation condition —
            # so "n open" on the card and the list behind it agree.
            "open": actionable.get(rid, 0) + (0 if rid in attested_by_id else 1),
            "blocking": blocking.get(rid, 0) + (0 if rid in attested_by_id else 1),
            # The ENGINE's verdict, unchanged: every open condition is
            # cleared. It says nothing about whether a human signed,
            # which is why `attested` is a separate field rather than
            # folded into this one — the dentist's queue and the
            # needs_clinician filter both read submission_ready and
            # neither of them means "signed".
            "submission_ready": bool(row["submission_ready"]),
            # Has a clinician put their name to this. A pre-D can be
            # transmitted without it; the billing screen shows that as
            # blocked-on-clinical rather than refusing the submission.
            "attested": rid in attested_by_id,
            "attested_at": _iso(attested_by_id[rid]["attested_at"])
            if rid in attested_by_id
            else None,
            # When the case entered the queue, so a biller can see what
            # has been sitting. submitted_at is NULL on every row in
            # this corpus — nothing has ever been sent — so a client
            # dating the payer window off it would show every deadline
            # as today. Both are returned; the client decides.
            "created_at": _iso(row["created_at"]),
            "submitted_at": _iso(row["submitted_at"]),
            "needs_clinician": needs,
            "needs_reason": reason,
            "handoff": (
                {
                    "handoff_id": ho["handoff_id"],
                    "from_user": ho["from_user"],
                    "message": ho["message"],
                    "to_role": ho["to_role"],
                    "created_at": _iso(ho["created_at"]),
                    # NULL until the target role has seen it. The client
                    # uses this to stop re-POSTing the read marker.
                    "read_at": _iso(ho["read_at"]),
                }
                if ho
                else None
            ),
            "cleared_count": cleared,
        })
    out.sort(key=lambda x: order.get(x["id"], 99))
    # Applied AFTER sorting so a filtered page keeps the morning's
    # order rather than re-deriving one.
    if needs_clinician is not None:
        out = [r for r in out if r["needs_clinician"] is needs_clinician]
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
    owner = await _tenant_for(request, pred_request_id)
    assert_tenant_allowed(claims, owner)
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

    # ── The one condition the engine cannot raise ───────────────────
    # Attestation is not a signal: no persona emits it, because it is
    # not a fact about the case, it is a fact about whether a human has
    # signed. It belongs in this list all the same — "why is this not
    # ready" is exactly the question this endpoint answers, and without
    # it a biller sees a case with every box ticked and no explanation
    # for why nobody has stood behind it.
    #
    # assignee is `dentist`, so every client that groups by owner files
    # it under clinical and read-only automatically.
    _, os_pool = _pools(request)
    signed = await execute_os_with_tenant(
        os_pool, owner,
        "SELECT 1 FROM clinical_attestations "
        "WHERE tenant_id = $1 AND pred_request_id = $2 LIMIT 1",
        owner, pred_request_id,
    )
    if not signed:
        conditions.append(Condition(
            signal_code="CLINICAL_ATTESTATION_MISSING",
            finding=(
                "Awaiting clinician attestation. No dentist has signed "
                "that the clinical record supports this pre-D. It can "
                "still be submitted, but nobody has stood behind it."
            ),
            mode="human_approval",
            category="clinical",
            recommended_action="Ask the treating dentist to review and attest",
            assignee="dentist",
            wave=3,
            # provider_feedback.decision_id is NOT NULL and this signal
            # has no engine decision behind it. Namespaced rather than
            # borrowed from a real one, so an override logged against it
            # reads as what it is and cannot be mistaken for a verdict a
            # persona actually reached.
            decision_id=f"attestation:{pred_request_id}",
            data={},
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
    claims=Depends(require_engine_feedback),
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

    # Whether the coordinator has finished with each patient. This used
    # to be a Set in the browser, so a refresh of /coverage put everyone
    # she had already seen back under "ready for consultation" and let
    # her hand the same case over twice.
    done_rows = await execute_os_with_tenant(
        os_pool, tenant,
        "SELECT pred_request_id, created_at FROM clinical_handoffs "
        "WHERE tenant_id = $1 AND kind = 'consultation_complete' "
        "  AND pred_request_id = ANY($2::text[])",
        tenant, list(schedule),
    )
    consult_done = {r["pred_request_id"]: r["created_at"] for r in done_rows}

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
        done_at = consult_done.get(rid)

        out.append({
            "pred_request_id": rid,
            # Server-side, so it survives a refresh. The coverage screen
            # buckets on this rather than on its own local Set.
            "consultation_complete": done_at is not None,
            "consultation_completed_at": _iso(done_at),
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
    message: str
    # Optional and CROSS-CHECKED, never used as the destination. The
    # caller may say which patient they think they are texting; if that
    # disagrees with the pre-D, the request is refused rather than
    # quietly sent to whoever the pre-D belongs to.
    patient_id: str | None = None
    # ⚠ ACCEPTED AND IGNORED. The frontend still sends it and Pydantic
    # would drop an unknown field silently, which would make this look
    # like it had been removed when it had only been forgotten. Named
    # here so the next reader sees it is deliberately unused.
    patient_phone: str | None = None


@router.post("/communications/sms")
async def send_sms(
    req: SMSRequest,
    request: Request,
    claims=Depends(require_patient_contact),
) -> dict:
    """Text a patient their estimate summary.

    THE DESTINATION COMES FROM THE PATIENT RECORD. It is looked up from
    the pre-D's own patient row under RLS, and any number in the body
    is ignored — a caller could otherwise post a colleague's name with
    their own phone and receive somebody else's treatment costs.

    ⚠ NOTHING IS SENT. This logs the message and returns success. AWS
    SNS is not wired: there is no SNS topic, no spend limit, no opt-out
    handling and no origination number, and switching it on without
    those is how a demo texts a real phone.

    To go live, uncomment the boto3 block AND first:
      - set an SMS monthly spend limit on the account
      - register an origination identity (10DLC in the US)
      - implement STOP/HELP handling, which is a legal requirement

    """
    # Resolve the owning practice FIRST and unconditionally. Guarding
    # only when tenant_filter() is truthy skipped the check for
    # accord_admin (who has no tenant of their own), and left `owner`
    # undefined for them — the patient lookup below would then have
    # fallen back to DEFAULT_TENANT and read the wrong practice.
    owner = await _tenant_for(request, req.pred_request_id)
    assert_tenant_allowed(claims, owner)
    tenant = tenant_filter(claims) or owner

    if len(req.message) > 320:
        raise HTTPException(422, "message is longer than two SMS segments")

    # ── The destination, from the record ────────────────────────────
    sim, _ = _pools(request)
    rows = await fetch_with_tenant(
        sim, tenant,
        "SELECT p.patient_id, p.mobile_phone, "
        "       p.first_name || ' ' || p.last_name AS patient_name "
        "FROM pred_requests pr JOIN patients p ON p.patient_id = pr.patient_id "
        "WHERE pr.pred_request_id = $1",
        req.pred_request_id,
    )
    if not rows:
        raise HTTPException(404, "Not found")
    patient = rows[0]
    if req.patient_id and req.patient_id != patient["patient_id"]:
        raise HTTPException(
            422,
            "patient_id does not match the patient on this pre-D",
        )
    to_number = patient["mobile_phone"]
    if not to_number:
        raise HTTPException(
            422,
            f"No mobile number on file for {patient['patient_name']}",
        )

    # PRODUCTION — to_number above is already the record's own number:
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
        # The number actually resolved, not the one that was sent.
        "to": to_number,
        "patient": patient["patient_name"],
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


ATTESTATION_STATEMENT = (
    "I attest that the clinical record supports the procedures submitted "
    "and that the narrative accompanying this pre-determination is "
    "accurate to the best of my clinical judgement."
)


class SubmitRequest(BaseModel):
    pred_request_id: str
    patient_name: str
    payer_id: str
    payer_name: str
    submission_method: str = "manual"
    notes: str | None = None
    # ── The dentist's sign-off ──────────────────────────────────────
    narrative_text: str | None = None
    # OPTIONAL, and tri-state on purpose. Absent means "record that this
    # went out"; true means "and I am signing for it". It defaulted to
    # False, which made the guard below reject every caller who simply
    # did not send the field — including the revenue ops queue, whose
    # submit button has been returning 422 in production.
    attested: bool | None = None
    # Accepted so the documented contract holds, but NEITHER IS
    # TRUSTED. attested_by is taken from the token and attested_at from
    # the server clock — a signature a caller can address to somebody
    # else, or backdate, is not a signature. A mismatch is refused
    # rather than silently corrected, because a client sending another
    # user's id is a bug worth surfacing.
    attested_by: str | None = None
    attested_at: str | None = None


async def _write_attestation(
    os_pool, tenant, pred_request_id, signer, narrative,
    submission_id=None,
):
    """The one place a signature is recorded.

    Shared by /submit and /attest so the two cannot drift: the same
    statement text, the same append-only insert, the same rule that the
    narrative is COPIED onto the attestation rather than referenced. A
    later edit to clinical_narratives must not change what was signed,
    and that only holds if both routes copy it the same way.
    """
    if not narrative:
        saved = await execute_os_with_tenant(
            os_pool, tenant,
            "SELECT narrative_text FROM clinical_narratives "
            "WHERE tenant_id = $1 AND pred_request_id = $2",
            tenant, pred_request_id,
        )
        narrative = saved[0]["narrative_text"] if saved else ""
    rows = await execute_os_with_tenant(
        os_pool, tenant,
        """
        INSERT INTO clinical_attestations
            (tenant_id, pred_request_id, attested_by, narrative_text,
             statement, submission_id)
        VALUES ($1,$2,$3,$4,$5,$6)
        RETURNING attestation_id, attested_at
        """,
        tenant, pred_request_id, signer, narrative or None,
        ATTESTATION_STATEMENT, submission_id,
    )
    # The narrative comes back with the rows: the caller needs to know
    # which text was actually signed, and only this function knows
    # whether it used the one it was handed or the one on file.
    return rows, narrative


@router.post("/decisions/{pred_request_id}/attest")
async def attest_pred(
    pred_request_id: str,
    request: Request,
    claims=Depends(require_clinician_cap),
) -> dict:
    """Sign that the clinical record supports this pre-D. Nothing is filed.

    Splitting the signature from the submission is what lets the two
    acts belong to different people: the dentist signs from the chair,
    billing files when the packet is ready. /submit still accepts
    attested:true and does both at once — whether the practice uses one
    button or two is a workflow decision, and the API supports either.

    The narrative is read from clinical_narratives and copied onto the
    attestation, exactly as /submit does it.
    """
    tenant = await _tenant_for(request, pred_request_id)
    assert_tenant_allowed(claims, tenant)
    _, os_pool = _pools(request)
    rows, _signed_text = await _write_attestation(
        os_pool, tenant, pred_request_id, claims.get("sub"), "",
    )
    if not rows:
        raise HTTPException(500, "the attestation was not recorded")
    row = rows[0]
    return {
        "status": "attested",
        "pred_request_id": pred_request_id,
        "attestation_id": row["attestation_id"],
        "attested_by": claims.get("sub"),
        # Server clock, never the caller's.
        "attested_at": _iso(row["attested_at"]),
        "statement": ATTESTATION_STATEMENT,
        "message": (
            "Attestation recorded. Nothing was submitted — the pre-D now "
            "shows as ready in the billing queue."
        ),
    }


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

    # ── Attesting is a separate act from submitting ─────────────────
    # Recording that a pre-D went to the payer is billing's job and
    # always was. Signing that the clinical record supports it is the
    # clinician's, and only that second act is gated. Refusing the
    # first because the second had not happened did not protect the
    # attestation — it just stopped anyone from filing anything.
    #
    # A pre-D can therefore be transmitted unattested. That is a real
    # exposure and it is answered by making it VISIBLE rather than
    # impossible: the queue returns `attested` per row and the billing
    # screen shows an unattested case as blocked on clinical.
    signer = claims.get("sub")
    is_clinician = claims.get("role") in ("dentist", "accord_admin")
    attesting = req.attested is True

    if attesting and not is_clinician:
        raise HTTPException(
            403,
            "Only a clinician can attest a pre-D. A treatment "
            "coordinator or biller cannot sign for clinical judgement.",
        )
    if attesting and req.attested_by and req.attested_by != signer:
        raise HTTPException(
            422,
            "attested_by does not match the signed-in user; you cannot "
            "attest on someone else's behalf",
        )
    # Submitting is not a side door onto the clinical record. POST
    # /decisions/:id/narrative is clinician-only; accepting narrative
    # text here from a biller would be the same write through a route
    # that happens not to check.
    if (req.narrative_text or "").strip() and not is_clinician:
        raise HTTPException(
            403,
            "Only a clinician can write the narrative. Submit without "
            "narrative_text to record the transmission.",
        )

    # The narrative is stored BEFORE the attestation and copied onto it,
    # so a later edit cannot change what was signed.
    narrative = (req.narrative_text or "").strip()
    if narrative and attesting:
        await execute_os_with_tenant(
            os_pool, tenant,
            """
            INSERT INTO clinical_narratives
                (tenant_id, pred_request_id, narrative_text, source,
                 written_by)
            VALUES ($1,$2,$3,'edited',$4)
            ON CONFLICT (tenant_id, pred_request_id) DO UPDATE
                SET narrative_text = EXCLUDED.narrative_text,
                    written_by = EXCLUDED.written_by,
                    updated_at = NOW()
            """,
            tenant, pred_request_id, narrative, signer,
        )

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

    # Append-only: one row per act of signing, never an upsert. Only
    # written when somebody actually signed — an empty attestation row
    # would be worse than none, because the queue reads its presence as
    # the fact that a clinician stood behind this.
    att: list = []
    if attesting:
        # _write_attestation falls back to the narrative on file when
        # this request carried none, and reports back which it used —
        # so narrative_captured below is the signed text, not the
        # request body.
        att, narrative = await _write_attestation(
            os_pool, tenant, pred_request_id, signer, narrative,
            submission_id=row["submission_id"],
        )

    return {
        "status": "submitted",
        "submission_id": row["submission_id"],
        "submitted_at": _iso(row["submitted_at"]),
        "pred_request_id": pred_request_id,
        "attested": bool(att),
        "attestation": (
            {
                "attestation_id": att[0]["attestation_id"],
                "attested_by": signer,
                # Server clock, not the caller's.
                "attested_at": _iso(att[0]["attested_at"]),
                "statement": ATTESTATION_STATEMENT,
                "narrative_captured": bool(narrative),
            }
            if att
            else None
        ),
        "message": (
            f"Submission to {req.payer_name} recorded"
            + (" and attested. " if att else " WITHOUT a clinician "
               "attestation. ")
            + f"Expected response in {row['expected_response_days']} "
            f"business days. Nothing was transmitted - X12 278 is not "
            f"connected."
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
    req: AppealRequest, request: Request, claims=Depends(require_billing)
) -> dict:
    """File an appeal against a denied pre-D. Billing and admin only."""
    # Not in the brief, and the same boundary every other write has:
    # without it a biller could file an appeal onto another practice's
    # case by posting its id.
    owner = await _tenant_for(request, req.pred_request_id)
    assert_tenant_allowed(claims, owner)
    tenant = tenant_filter(claims) or owner
    _, os_pool = _pools(request)

    # ── What the engine expected, BEFORE the payer answers ──────────
    # Written here and never recomputed. resolve_appeal_viability does
    # not return the same answer twice — it reads evidence that
    # accumulates and short-circuits once the deadline passes — so
    # re-running it after the outcome tells you about today, not about
    # what anyone believed when they filed.
    #
    # A failure here must not stop an appeal being filed. NULL means
    # "no prediction on record", which the UI renders as exactly that.
    predicted_viable = None
    predicted_probability = None
    try:
        ctx = await _build_context(request, req.pred_request_id)
        viability = resolve_appeal_viability(ctx, ctx.catalogue_rules)
        if viability.get("applicable") is not False:
            predicted_viable = viability.get("viable")
            prob = viability.get("success_probability")
            predicted_probability = (
                round(float(prob), 3) if prob is not None else None
            )
    except Exception as exc:  # noqa: BLE001 — never block the filing
        logger.warning("appeal prediction snapshot failed for %s: %s",
                       req.pred_request_id, exc)

    rows = await execute_os_with_tenant(
        os_pool, tenant,
        """
        INSERT INTO appeal_events
            (tenant_id, pred_request_id, denial_id, patient_name,
             payer_id, filed_by, appeal_type, status, notes,
             predicted_viable, predicted_probability)
        VALUES ($1,$2,$3,$4,$5,$6,$7,'filed',$8,$9,$10)
        ON CONFLICT (tenant_id, pred_request_id) DO NOTHING
        RETURNING appeal_id, filed_at, status
        """,
        tenant, req.pred_request_id, req.denial_id, req.patient_name,
        req.payer_id, claims.get("sub"), req.appeal_type, req.notes,
        predicted_viable, predicted_probability,
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
               -- The engine's verdict as it stood when this was filed.
               a.predicted_viable, a.predicted_probability,
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
            "predicted_viable": r["predicted_viable"],
            # 0-1 in the column, percent on the screen. Converted once,
            # here, so no component has to remember the scale.
            "predicted_probability": (
                round(float(r["predicted_probability"]) * 100)
                if r["predicted_probability"] is not None
                else None
            ),
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


# ─────────────────────────────────────────────────────────────────────
# The dentist's workbench — migrations/004.
#
# ── The bucket mapping ───────────────────────────────────────────────
#
# Three buckets were asked for; the corpus uses 44 distinct signal
# codes and three buckets leave 16 of them homeless, so there is a
# fourth. The roll-ups and the portfolio signals are deliberately NOT
# bucketed:
#
#   PRED_*        wave 4, and not findings at all — they are summaries
#                 OF the other findings. Bucketing them double-counts
#                 every case. They drive the header instead.
#   PORTFOLIO_*   practice-level, dso_manager-owned, identical on all
#                 40 bundles. Not a chairside concern; dropped.
#
# ── Ownership uses owner_team, not assignee ──────────────────────────
#
# Revenue Ops keys its billing/front-desk/clinical split on `assignee`.
# That field says `provider` on 83 signals across the corpus, which the
# fallback maps to "clinical" — so COVERAGE_PRED_REQUIRED (40 of 40
# cases), COVERAGE_DOWNGRADE_APPLIED and COVERAGE_BUNDLING_CONFLICT all
# read as the dentist's work when they are billing's. `owner_team` is
# the field that means whose job it is, and it is what the buckets use.
# Kim's screen still uses `assignee`; the two disagree until that is
# reconciled, which is a frontend change and not this prompt.
# ─────────────────────────────────────────────────────────────────────

CLINICAL_SUPPORT = "clinical_support"
DOCUMENTATION_GAPS = "documentation_gaps"
PAYER_FRICTION = "payer_friction"
INTEGRITY_PROVIDER = "integrity_provider"

BUCKET_LABEL = {
    CLINICAL_SUPPORT: "Clinical support",
    DOCUMENTATION_GAPS: "Documentation gaps",
    PAYER_FRICTION: "Payer friction",
    INTEGRITY_PROVIDER: "Integrity and provider",
}

# Prefix rules, not a 44-line literal: the corpus grows a signal code
# most sprints, and a list would silently drop each new one into
# "unbucketed" until somebody noticed.
_BUCKET_PREFIXES = (
    ("CLINICAL_", CLINICAL_SUPPORT),
    ("DOC_", DOCUMENTATION_GAPS),
    ("DOCUMENTATION_", DOCUMENTATION_GAPS),
    ("COVERAGE_", PAYER_FRICTION),
    ("ELIG_", PAYER_FRICTION),
    ("ELIGIBILITY_", PAYER_FRICTION),
    ("APPEAL_", PAYER_FRICTION),
    ("INTEGRITY_", INTEGRITY_PROVIDER),
    ("INTEGRITY_", INTEGRITY_PROVIDER),
    ("PROVIDER_", INTEGRITY_PROVIDER),
)

# Roll-ups: the header, never a bucket.
_ROLLUP_PREFIX = "PRED_"
# Practice-level: not shown chairside at all.
_PORTFOLIO_PREFIX = "PORTFOLIO_"


def bucket_of(signal_code: str) -> Optional[str]:
    """Which bucket a signal belongs in, or None if it is not one."""
    if signal_code.startswith(_PORTFOLIO_PREFIX):
        return None
    if signal_code.startswith(_ROLLUP_PREFIX):
        return None
    for prefix, bucket in _BUCKET_PREFIXES:
        if signal_code.startswith(prefix):
            return bucket
    return None


# A signal is SATISFIED when the engine is not asking for anything.
# There is no boolean on the payload saying so — "met" is encoded by
# naming convention in the code's suffix plus membership of
# open_conditions, and the two are checked together rather than trusting
# either alone.
_SATISFIED_SUFFIXES = (
    "_VERIFIED", "_MET", "_COMPLETE", "_READY_TO_SUBMIT", "_NOT_VIABLE",
)


def _is_satisfied(signal_code: str, open_codes: set[str]) -> bool:
    if signal_code in open_codes:
        return False
    if signal_code.endswith("_NOT_MET"):
        return False
    return any(signal_code.endswith(s) for s in _SATISFIED_SUFFIXES)


def _tooth_phrase(teeth: list[int]) -> str:
    if not teeth:
        return ""
    if len(teeth) == 1:
        return f"tooth #{teeth[0]}"
    return "teeth #" + ", #".join(str(t) for t in teeth[:-1]) + f" and #{teeth[-1]}"


def _fmt_date(value) -> Optional[str]:
    """'2026-08-05' -> '5 August 2026'. Returns None on anything else."""
    if not value:
        return None
    try:
        d = date.fromisoformat(str(value)[:10])
    except ValueError:
        return None
    return f"{d.day} {d.strftime('%B')} {d.year}"


def _draft_narrative(
    procedures: list[dict],
    evidence: list[dict],
    guidelines: dict[str, dict],
    frequency: list[dict],
) -> tuple[Optional[str], Optional[str]]:
    """Two to four sentences of plain clinical prose, and why not if not.

    Returns (draft, reason_when_none). A case with nothing clinical to
    state gets no draft and says so — a prophylaxis needs no narrative,
    and inventing one would put words in a dentist's mouth to fill a
    box.

    ⚠ THE REGISTER IS MY CHOICE. The three examples meant to set it live
    in DentistWorkbench.jsx, which is in none of the three repos. This
    follows the written instruction instead: declarative, measurements
    with units, the ADA threshold named where one applies, and no
    "appears to" / "may indicate" / "suggestive of". A payer reads
    hedging as doubt.
    """
    if not procedures:
        return None, "no procedure lines on this pre-D"

    by_type: dict[str, dict] = {}
    for e in evidence:
        by_type.setdefault(e["document_type"], e)

    xray = by_type.get("XRAY_PA") or by_type.get("XRAY_BITEWING")
    xf = _json(xray.get("extracted_fields"), {}) if xray else {}
    teeth = sorted({
        p["tooth_number"] for p in procedures if p.get("tooth_number")
    })
    codes = [p["cdt_code"] for p in procedures]
    tooth_txt = _tooth_phrase(teeth)
    sentences: list[str] = []

    # 1 — the finding, in the radiograph's own words.
    pathology = xf.get("pathology")
    if pathology:
        names_tooth = any(f"#{t}" in pathology for t in teeth)
        tail = "" if names_tooth or not tooth_txt else f" at {tooth_txt}"
        sentences.append(f"{pathology.rstrip('.')}{tail}.")

    # 2 — the measurement, against the ADA threshold for the lead code.
    bone_mm = xf.get("bone_loss_mm")
    taken = _fmt_date(xf.get("xray_date") or xf.get("date_taken"))
    if bone_mm is not None:
        lead = next((c for c in codes if c in guidelines), None)
        g = guidelines.get(lead or "", {})
        minimum = _json(g.get("clinical_thresholds"), {}).get("bone_loss_mm_min")
        measured = f"{bone_mm} mm"
        pct = xf.get("bone_loss_pct")
        if pct is not None:
            measured += f" ({pct}%)"
        clause = (
            f"A periapical radiograph{f' taken {taken}' if taken else ''} "
            f"demonstrates {measured} of bone loss at the site"
        )
        if minimum is not None and g.get("citation"):
            clause += f", above the {minimum} mm minimum in {g['citation'].split(';')[0]}"
        sentences.append(clause + ".")
    elif xray and taken and not pathology:
        sentences.append(f"A periapical radiograph was taken {taken}.")

    # 3 — the separation argument, where a payer will bundle.
    if "D7953" in codes and any(c.startswith("D60") for c in codes):
        sentences.append(
            "Ridge preservation grafting was performed at the extraction "
            "site as a distinct surgical episode, on its own date of "
            "service, and is documented separately from implant placement."
        )

    # 4 — what is being restored. Any crown or implant crown, not just
    # D6065: a D2740 case is the commonest thing a dentist narrates.
    restorative = [
        p for p in procedures
        if p["cdt_code"].startswith("D27") or p["cdt_code"].startswith("D6065")
    ]
    if restorative:
        r = restorative[0]
        what = (r.get("description") or r["cdt_code"]).strip().rstrip(".")
        where = f" at tooth #{r['tooth_number']}" if r.get("tooth_number") else ""
        sentences.append(f"{what} ({r['cdt_code']}) restores function{where}.")

    # 5 — frequency, when that is the whole clinical question. A recall
    # prophylaxis has no pathology and no radiograph; what a payer wants
    # is the interval since the last one against the plan's limit.
    if len(sentences) < 2 and frequency:
        prior = None
        for e in evidence:
            ef = _json(e.get("extracted_fields"), {})
            for svc in ef.get("prior_services") or []:
                if svc.get("cdt_code") in codes and svc.get("date_of_service"):
                    prior = svc
                    break
        lim = frequency[0]
        proc_txt = (procedures[0].get("description") or codes[0]).rstrip(".")
        if prior:
            when = _fmt_date(prior["date_of_service"])
            sentences.append(
                f"{proc_txt} ({codes[0]}) is a recall service; the most "
                f"recent on file was {when}."
            )
        # frequency_period is stored as "per_year" / "per_24_months",
        # so the "per " goes in front of the stripped value or it reads
        # "2 per per_year".
        period = str(lim["frequency_period"] or "").removeprefix("per_")
        period = period.replace("_", " ") or "period"
        sentences.append(
            f"The plan allows {lim['frequency_count']} per {period}."
        )

    if len(sentences) < 2:
        return None, (
            "not enough clinical evidence on file to draft from — no "
            "radiographic finding, measurement or restorative procedure"
        )
    return " ".join(sentences[:4]), None


@router.get("/decisions/{pred_request_id}/clinical")
async def clinical_view(
    pred_request_id: str,
    request: Request,
    claims=Depends(require_claims_or_demo),
) -> dict:
    """Everything the dentist's workbench needs for one pre-D.

    Three buckets plus integrity, a header built from the wave-4
    roll-ups, and a narrative drafted from the case's own procedure
    lines and clinical evidence. Nothing here is stored until the
    dentist saves it.
    """
    tenant = await _tenant_for(request, pred_request_id)
    assert_tenant_allowed(claims, tenant)
    sim, os_pool = _pools(request)

    bundle, outputs = await _read_current_bundle(request, pred_request_id)
    if bundle is None:
        raise HTTPException(404, f"no decision bundle for {pred_request_id}")
    signals = _json(bundle.get("all_signals"), [])
    snapshot = _json(bundle.get("bundle_snapshot"), {})
    # _open_condition_codes, NOT snapshot["open_conditions"]. The
    # snapshot carries pred_states' own list and the two DISAGREE —
    # A01's snapshot says COVERAGE_PRED_REQUIRED and CLINICAL_XRAY_
    # REQUIRED are open, the signal-derived list says
    # ELIG_FREQUENCY_UNVERIFIED and APPEAL_VIABLE. GET /decisions/:id
    # publishes the derived one, so the dentist view uses it too;
    # otherwise the same case shows a different set of open items on
    # two screens.
    open_codes = set(_open_condition_codes(signals))

    # Saved work, so the screen reopens where the dentist left it.
    saved_narrative = await execute_os_with_tenant(
        os_pool, tenant,
        "SELECT narrative_text, source, updated_at FROM clinical_narratives "
        "WHERE tenant_id = $1 AND pred_request_id = $2",
        tenant, pred_request_id,
    )
    justified = await execute_os_with_tenant(
        os_pool, tenant,
        "SELECT signal_code, justification, updated_at "
        "FROM clinical_justifications "
        "WHERE tenant_id = $1 AND pred_request_id = $2",
        tenant, pred_request_id,
    )
    just_by_code = {j["signal_code"]: j for j in justified}
    requests_open = await execute_os_with_tenant(
        os_pool, tenant,
        "SELECT request_id, document_type, signal_code, status, note, "
        "       requested_at FROM document_requests "
        "WHERE tenant_id = $1 AND pred_request_id = $2 "
        "ORDER BY requested_at DESC",
        tenant, pred_request_id,
    )
    requested_types = {
        r["document_type"] for r in requests_open if r["status"] == "open"
    }
    attestations = await execute_os_with_tenant(
        os_pool, tenant,
        "SELECT attestation_id, attested_by, attested_at, statement "
        "FROM clinical_attestations "
        "WHERE tenant_id = $1 AND pred_request_id = $2 "
        "ORDER BY attested_at DESC LIMIT 1",
        tenant, pred_request_id,
    )

    buckets: dict[str, list[dict]] = {
        CLINICAL_SUPPORT: [],
        DOCUMENTATION_GAPS: [],
        PAYER_FRICTION: [],
        INTEGRITY_PROVIDER: [],
    }
    rollups: list[dict] = []
    unbucketed: list[str] = []

    for s in signals:
        code = s.get("signal_code", "")
        if code.startswith(_PORTFOLIO_PREFIX):
            continue
        if code.startswith(_ROLLUP_PREFIX):
            rollups.append({
                "signal_code": code,
                "finding": s.get("finding"),
                "mode": s.get("mode"),
                "risk_level": s.get("risk_level"),
            })
            continue
        b = bucket_of(code)
        if b is None:
            unbucketed.append(code)
            continue
        j = just_by_code.get(code)
        buckets[b].append({
            "signal_code": code,
            "finding": s.get("finding"),
            "mode": s.get("mode"),
            "wave": s.get("wave"),
            # owner_team, NOT assignee — see the note at the top.
            "owner_team": s.get("owner_team"),
            "assignee": s.get("assignee"),
            "risk_level": s.get("risk_level"),
            "citation": s.get("citation"),
            "payer_citation": s.get("payer_citation"),
            "recommended_action": s.get("recommended_action"),
            "sla_hours": s.get("sla_hours"),
            "satisfied": _is_satisfied(code, open_codes),
            "justification": j["justification"] if j else None,
            "justified_at": _iso(j["updated_at"]) if j else None,
            "document_requested": any(
                r["signal_code"] == code and r["status"] == "open"
                for r in requests_open
            ),
        })

    procedures = await fetch_with_tenant(
        sim, tenant,
        "SELECT line_no, cdt_code, tooth_number, tooth_surface, fee, "
        "       description, requires_pred FROM procedure_lines "
        "WHERE pred_request_id = $1 ORDER BY line_no",
        pred_request_id,
    )
    evidence = await fetch_with_tenant(
        sim, tenant,
        "SELECT document_type, document_category, tooth_number, "
        "       confidence_score, extracted_fields, received_at "
        "FROM clinical_evidence WHERE pred_request_id = $1",
        pred_request_id,
    )
    codes = [p["cdt_code"] for p in procedures]
    guide_rows = await fetch_with_tenant(
        sim, tenant,
        "SELECT cdt_code, guideline_name, citation, criteria_checklist, "
        "       clinical_thresholds FROM ada_guidelines "
        "WHERE cdt_code = ANY($1::text[])",
        codes,
    ) if codes else []
    guidelines = {g["cdt_code"]: dict(g) for g in guide_rows}

    payer_id = snapshot.get("payer_id")
    frequency = await fetch_with_tenant(
        sim, tenant,
        "SELECT cdt_code, frequency_count, frequency_period, waiting_days "
        "FROM frequency_limits WHERE payer_id = $1 AND cdt_code = ANY($2::text[])",
        payer_id, codes,
    ) if (codes and payer_id) else []

    draft, no_draft_reason = _draft_narrative(
        [dict(p) for p in procedures],
        [dict(e) for e in evidence],
        guidelines,
        [dict(f) for f in frequency],
    )
    current = saved_narrative[0] if saved_narrative else None

    return {
        "pred_request_id": pred_request_id,
        # From the snapshot — persona_bundles has no patient_name column.
        "patient_name": snapshot.get("patient_name"),
        "decision": snapshot.get("decision"),
        # snapshot["submission_ready"] is null on every bundle. The
        # verdict lives in the wave-4 signal, read back the same way
        # GET /decisions/:id reads it.
        "submission_ready": any(
            s.get("signal_code") == "PRED_READY_TO_SUBMIT" for s in signals
        ),
        # The wave-4 signals, as a header rather than a bucket.
        "status_rollup": rollups,
        "buckets": [
            {
                "key": key,
                "label": BUCKET_LABEL[key],
                "open": sum(1 for x in buckets[key] if not x["satisfied"]),
                "signals": buckets[key],
            }
            for key in (
                CLINICAL_SUPPORT,
                DOCUMENTATION_GAPS,
                PAYER_FRICTION,
                INTEGRITY_PROVIDER,
            )
        ],
        # Empty in this corpus. Returned anyway so a signal code added
        # upstream shows up here instead of vanishing from the screen.
        "unbucketed": unbucketed,
        "procedures": [
            {
                "line_no": p["line_no"],
                "cdt_code": p["cdt_code"],
                "tooth_number": p["tooth_number"],
                "description": p["description"],
                "fee": _f(p["fee"]),
                "requires_pred": p["requires_pred"],
                "ada_citation": (guidelines.get(p["cdt_code"], {}) or {}).get(
                    "citation"
                ),
            }
            for p in procedures
        ],
        "evidence": [
            {
                "document_type": e["document_type"],
                "document_category": e["document_category"],
                "tooth_number": e["tooth_number"],
                "confidence_score": _f(e["confidence_score"]),
                "received_at": _iso(e["received_at"]),
            }
            for e in evidence
        ],
        "narrative": {
            "draft": draft,
            # Why there is nothing to edit, rather than an empty box.
            "no_draft_reason": no_draft_reason,
            "saved": current["narrative_text"] if current else None,
            "source": current["source"] if current else None,
            "updated_at": _iso(current["updated_at"]) if current else None,
        },
        "document_requests": [
            {
                "request_id": r["request_id"],
                "document_type": r["document_type"],
                "signal_code": r["signal_code"],
                "status": r["status"],
                "note": r["note"],
                "requested_at": _iso(r["requested_at"]),
            }
            for r in requests_open
        ],
        "requested_types": sorted(requested_types),
        "attestation": (
            {
                "attestation_id": attestations[0]["attestation_id"],
                "attested_by": attestations[0]["attested_by"],
                "attested_at": _iso(attestations[0]["attested_at"]),
                "statement": attestations[0]["statement"],
            }
            if attestations
            else None
        ),
    }


class NarrativeRequest(BaseModel):
    narrative_text: str
    source: str = "edited"


@router.post("/decisions/{pred_request_id}/narrative")
async def save_narrative(
    pred_request_id: str,
    req: NarrativeRequest,
    request: Request,
    claims=Depends(require_clinician_cap),
) -> dict:
    """Save the dentist's narrative. One live version per pre-D."""
    tenant = await _tenant_for(request, pred_request_id)
    assert_tenant_allowed(claims, tenant)
    text = req.narrative_text.strip()
    if not text:
        raise HTTPException(422, "narrative_text is empty")
    if req.source not in ("draft", "edited", "authored"):
        raise HTTPException(422, "source must be draft, edited or authored")
    _, os_pool = _pools(request)

    rows = await execute_os_with_tenant(
        os_pool, tenant,
        """
        INSERT INTO clinical_narratives
            (tenant_id, pred_request_id, narrative_text, source, written_by)
        VALUES ($1,$2,$3,$4,$5)
        ON CONFLICT (tenant_id, pred_request_id) DO UPDATE
            SET narrative_text = EXCLUDED.narrative_text,
                source = EXCLUDED.source,
                written_by = EXCLUDED.written_by,
                updated_at = NOW()
        RETURNING narrative_id, source, updated_at
        """,
        tenant, pred_request_id, text, req.source, claims.get("sub"),
    )
    row = rows[0]
    return {
        "status": "saved",
        "narrative_id": row["narrative_id"],
        "source": row["source"],
        "updated_at": _iso(row["updated_at"]),
        "characters": len(text),
    }


class JustificationRequest(BaseModel):
    signal_code: str
    justification: str


@router.post("/decisions/{pred_request_id}/justification")
async def save_justification(
    pred_request_id: str,
    req: JustificationRequest,
    request: Request,
    claims=Depends(require_clinician_cap),
) -> dict:
    """Record why a criterion the engine could not confirm is met.

    The signal must actually be on the case. Justifying a code that is
    not there produces a record nobody can act on and a row that never
    matches anything on screen.
    """
    tenant = await _tenant_for(request, pred_request_id)
    assert_tenant_allowed(claims, tenant)
    text = req.justification.strip()
    if not text:
        raise HTTPException(422, "justification is empty")

    bundle, _ = await _read_current_bundle(request, pred_request_id)
    if bundle is None:
        raise HTTPException(404, f"no decision bundle for {pred_request_id}")
    codes = {
        s.get("signal_code") for s in _json(bundle.get("all_signals"), [])
    }
    if req.signal_code not in codes:
        raise HTTPException(
            422,
            f"{req.signal_code} is not a signal on {pred_request_id}",
        )

    _, os_pool = _pools(request)
    rows = await execute_os_with_tenant(
        os_pool, tenant,
        """
        INSERT INTO clinical_justifications
            (tenant_id, pred_request_id, signal_code, justification,
             justified_by)
        VALUES ($1,$2,$3,$4,$5)
        ON CONFLICT (tenant_id, pred_request_id, signal_code) DO UPDATE
            SET justification = EXCLUDED.justification,
                justified_by = EXCLUDED.justified_by,
                updated_at = NOW()
        RETURNING justification_id, updated_at
        """,
        tenant, pred_request_id, req.signal_code, text, claims.get("sub"),
    )
    row = rows[0]
    return {
        "status": "saved",
        "justification_id": row["justification_id"],
        "signal_code": req.signal_code,
        "updated_at": _iso(row["updated_at"]),
    }


# ─────────────────────────────────────────────────────────────────────
# Handing a case to somebody else.
#
# clinical_handoffs was built read-only in 005: the queue filter read
# it and nothing on earth wrote to it, so four buttons in the frontend
# rendered "notified ✓" with no request behind them.
# ─────────────────────────────────────────────────────────────────────

# The roles a case can be handed TO. Not every role in the system:
# handing work to accord_admin or to a DSO owner is not a workflow, it
# is a typo, and an unrecognised value here means a note nobody's queue
# will ever filter for.
HANDOFF_ROLES = ("dentist", "front_desk", "tx_coord", "revenue_ops")

# What the note MEANS. 'note' is somebody asking for attention;
# 'consultation_complete' is the coordinator saying she has finished
# with the patient, which the coverage screen reads back as state.
# Distinct kinds coexist on one pre-D; repeats of one kind collapse.
HANDOFF_KINDS = ("note", "consultation_complete")


class HandoffRequest(BaseModel):
    to_role: str = "dentist"
    note: str
    kind: str = "note"


@router.post("/decisions/{pred_request_id}/handoff")
async def create_handoff(
    pred_request_id: str,
    req: HandoffRequest,
    request: Request,
    claims=Depends(require_handoff_sender),
) -> dict:
    """Put a case in another role's queue, with a note.

    Addressed to a ROLE rather than a person: "the dentist" is whoever
    covers the chair today, and naming an individual means the case
    vanishes when they are on leave.
    """
    tenant = await _tenant_for(request, pred_request_id)
    assert_tenant_allowed(claims, tenant)

    note = req.note.strip()
    if not note:
        raise HTTPException(422, "note is empty")
    if len(note) > 1000:
        raise HTTPException(422, "note is longer than 1000 characters")
    if req.to_role not in HANDOFF_ROLES:
        raise HTTPException(
            422,
            f"to_role must be one of {', '.join(HANDOFF_ROLES)}",
        )
    if req.kind not in HANDOFF_KINDS:
        raise HTTPException(
            422,
            f"kind must be one of {', '.join(HANDOFF_KINDS)}",
        )

    _, os_pool = _pools(request)
    rows = await execute_os_with_tenant(
        os_pool, tenant,
        # IDEMPOTENT PER KIND. Two clicks of [Mark consultation
        # complete] used to queue two notes with nothing to tell them
        # apart. The repeat now refreshes the note in place and re-opens
        # it — somebody asking a second time is asking again, not
        # asking about a second thing.
        """
        INSERT INTO clinical_handoffs
            (tenant_id, pred_request_id, to_role, from_user, message, kind)
        VALUES ($1,$2,$3,$4,$5,$6)
        ON CONFLICT (tenant_id, pred_request_id, to_role, kind) DO UPDATE
            SET message = EXCLUDED.message,
                from_user = EXCLUDED.from_user,
                created_at = NOW(),
                read_at = NULL,
                read_by = NULL
        RETURNING handoff_id, created_at,
                  (xmax <> 0) AS was_existing
        """,
        tenant, pred_request_id, req.to_role, claims.get("sub"), note,
        req.kind,
    )
    row = rows[0]
    return {
        "status": "sent",
        "handoff_id": row["handoff_id"],
        "pred_request_id": pred_request_id,
        "to_role": req.to_role,
        "kind": req.kind,
        # True when this replaced an existing note rather than adding
        # one. The caller does not need it; a human reading the log does.
        "replaced_existing": row["was_existing"],
        "created_at": _iso(row["created_at"]),
    }


@router.post("/decisions/{pred_request_id}/handoff/read")
async def mark_handoff_read(
    pred_request_id: str,
    request: Request,
    claims=Depends(require_handoff_sender),
) -> dict:
    """Mark the handoffs addressed to the CALLER'S role as read.

    Scoped to the caller's own role, so reading the dentist's note off
    the screen cannot clear one addressed to the front desk. A separate
    call rather than a side effect of the GET: a read that mutates is
    the kind of thing a prefetch or a double-render clears by accident.
    """
    tenant = await _tenant_for(request, pred_request_id)
    assert_tenant_allowed(claims, tenant)
    _, os_pool = _pools(request)
    rows = await execute_os_with_tenant(
        os_pool, tenant,
        """
        UPDATE clinical_handoffs
           SET read_at = NOW(), read_by = $3
         WHERE tenant_id = $1 AND pred_request_id = $2
           AND to_role = $4 AND read_at IS NULL
        RETURNING handoff_id
        """,
        tenant, pred_request_id, claims.get("sub"), claims.get("role"),
    )
    return {"status": "read", "marked": len(rows)}


class DocumentRequestItem(BaseModel):
    document_type: str
    signal_code: str | None = None
    note: str | None = None


class DocumentRequestsRequest(BaseModel):
    requests: list[DocumentRequestItem]
    requested_from: str = "front_desk"


@router.post("/decisions/{pred_request_id}/document-requests")
async def create_document_requests(
    pred_request_id: str,
    req: DocumentRequestsRequest,
    request: Request,
    claims=Depends(require_document_chase),
) -> dict:
    """Ask whoever holds the records for what is missing.

    ⚠ NOTHING IS DELIVERED. This records the ask; there is no channel
    to the front desk and no inbox at the other end. The row is real
    and so is the audit trail — the notification is not built.
    """
    tenant = await _tenant_for(request, pred_request_id)
    assert_tenant_allowed(claims, tenant)
    if not req.requests:
        raise HTTPException(422, "requests is empty")
    if len(req.requests) > 20:
        raise HTTPException(422, "no more than 20 documents in one request")
    _, os_pool = _pools(request)

    created = []
    for item in req.requests:
        doc = item.document_type.strip()
        if not doc:
            raise HTTPException(422, "document_type is empty")
        rows = await execute_os_with_tenant(
            os_pool, tenant,
            """
            INSERT INTO document_requests
                (tenant_id, pred_request_id, document_type, signal_code,
                 requested_from, requested_by, note)
            VALUES ($1,$2,$3,$4,$5,$6,$7)
            RETURNING request_id, document_type, status, requested_at
            """,
            tenant, pred_request_id, doc, item.signal_code,
            req.requested_from, claims.get("sub"), item.note,
        )
        r = rows[0]
        created.append({
            "request_id": r["request_id"],
            "document_type": r["document_type"],
            "status": r["status"],
            "requested_at": _iso(r["requested_at"]),
        })

    return {
        "status": "requested",
        "pred_request_id": pred_request_id,
        "requested_from": req.requested_from,
        "count": len(created),
        "requests": created,
        "message": (
            f"{len(created)} document request(s) recorded for "
            f"{req.requested_from}. No notification was sent — there is no "
            f"channel to them yet."
        ),
    }


@router.get("/appeals/{appeal_id}/evidence")
async def appeal_evidence(
    appeal_id: str,
    request: Request,
    claims=Depends(require_claims_or_demo),
) -> dict:
    """The evidence checklist behind one appeal — including the
    dentist's own words.

    ⚠ THIS ENDPOINT DID NOT EXIST. The criterion names
    GET /api/appeals/:id/evidence as though it were there to be
    extended; there was no /appeals/{id}/... route at all. Built here.
    Also: `justification_events` is `clinical_justifications`, created
    in migration 004 under a different name.
    Also: dentist-workbench-build-prompt.md is in none of the three
    repos, so this is built from the criterion as written in the
    prompt.
    """
    tenant = tenant_filter(claims) or DEFAULT_TENANT
    sim, os_pool = _pools(request)

    appeals = await execute_os_with_tenant(
        os_pool, tenant,
        """
        SELECT a.appeal_id, a.pred_request_id, a.patient_name, a.payer_id,
               a.filed_at, a.status, a.appeal_type,
               d.denial_reason, d.denied_amount, d.appeal_probability,
               d.appeal_deadline
        FROM appeal_events a
        LEFT JOIN denial_events d
               ON d.denial_id = a.denial_id AND d.tenant_id = a.tenant_id
        WHERE a.tenant_id = $1 AND a.appeal_id = $2
        """,
        tenant, appeal_id,
    )
    if not appeals:
        # 404, not 403, for the same reason assert_tenant_allowed does:
        # confirming an id exists under another practice turns this into
        # an oracle.
        raise HTTPException(404, "Not found")
    a = appeals[0]
    pred_request_id = a["pred_request_id"]

    # ── What the chart holds ────────────────────────────────────────
    docs = await fetch_with_tenant(
        sim, tenant,
        "SELECT document_type, document_category, confidence_score, "
        "       s3_key, received_at FROM clinical_evidence "
        "WHERE pred_request_id = $1 ORDER BY document_type",
        pred_request_id,
    )

    items: list[dict] = [
        {
            "kind": "document",
            "key": f"doc:{d['document_type']}",
            "label": d["document_type"].replace("_", " ").title(),
            "present": True,
            "detail": None,
            "confidence": _f(d["confidence_score"]),
            "s3_key": d["s3_key"],
            "recorded_at": _iso(d["received_at"]),
            "recorded_by": None,
        }
        for d in docs
        # A pre-D letter is the denial being appealed, not evidence for
        # it. Listing it as supporting evidence pads the checklist with
        # the very thing under dispute.
        if not d["document_type"].startswith("PRED_LETTER")
    ]

    # ── What the DENTIST wrote ──────────────────────────────────────
    #
    # This is the join the criterion is about. Keyed on
    # pred_request_id, because a justification is written against the
    # DECISION and an appeal is filed against the same decision — there
    # is no appeal_id on a justification and there should not be: the
    # clinical reasoning predates the appeal and survives it being
    # withdrawn and refiled.
    justifications = await execute_os_with_tenant(
        os_pool, tenant,
        """
        SELECT j.justification_id, j.signal_code, j.justification,
               j.justified_by, j.updated_at,
               u.name AS author_name, u.role AS author_role
        FROM clinical_justifications j
        LEFT JOIN users u ON u.user_id = j.justified_by
        WHERE j.tenant_id = $1 AND j.pred_request_id = $2
        ORDER BY j.updated_at
        """,
        tenant, pred_request_id,
    )
    for j in justifications:
        who = j["author_name"] or "a clinician"
        when = j["updated_at"]
        stamp = (
            f"{when.day} {when.strftime('%b')}" if when else ""
        )
        items.append({
            "kind": "clinical_justification",
            "key": f"justification:{j['signal_code']}",
            "label": (
                f"Clinical necessity documented by {who}"
                + (f", {stamp}" if stamp else "")
            ),
            "present": True,
            # The dentist's actual wording, for the expander.
            "detail": j["justification"],
            "signal_code": j["signal_code"],
            "confidence": None,
            "s3_key": None,
            "recorded_at": _iso(when),
            "recorded_by": who,
            "author_role": j["author_role"],
        })

    # ── And the narrative, which is the same kind of thing ──────────
    narratives = await execute_os_with_tenant(
        os_pool, tenant,
        """
        SELECT n.narrative_text, n.updated_at, n.source,
               u.name AS author_name
        FROM clinical_narratives n
        LEFT JOIN users u ON u.user_id = n.written_by
        WHERE n.tenant_id = $1 AND n.pred_request_id = $2
        """,
        tenant, pred_request_id,
    )
    for nrow in narratives:
        who = nrow["author_name"] or "a clinician"
        when = nrow["updated_at"]
        stamp = f"{when.day} {when.strftime('%b')}" if when else ""
        items.append({
            "kind": "clinical_narrative",
            "key": "narrative",
            "label": (
                f"Clinical narrative written by {who}"
                + (f", {stamp}" if stamp else "")
            ),
            "present": True,
            "detail": nrow["narrative_text"],
            "confidence": None,
            "s3_key": None,
            "recorded_at": _iso(when),
            "recorded_by": who,
        })

    # ── And the attestation ─────────────────────────────────────────
    attestations = await execute_os_with_tenant(
        os_pool, tenant,
        """
        SELECT c.attested_at, c.statement, u.name AS author_name
        FROM clinical_attestations c
        LEFT JOIN users u ON u.user_id = c.attested_by
        WHERE c.tenant_id = $1 AND c.pred_request_id = $2
        ORDER BY c.attested_at DESC LIMIT 1
        """,
        tenant, pred_request_id,
    )
    for at in attestations:
        who = at["author_name"] or "a clinician"
        when = at["attested_at"]
        stamp = f"{when.day} {when.strftime('%b')}" if when else ""
        items.append({
            "kind": "attestation",
            "key": "attestation",
            "label": f"Attested by {who}" + (f", {stamp}" if stamp else ""),
            "present": True,
            "detail": at["statement"],
            "confidence": None,
            "s3_key": None,
            "recorded_at": _iso(when),
            "recorded_by": who,
        })

    # ── What is still missing ───────────────────────────────────────
    #
    # From the engine's own appeal resolver rather than a second
    # opinion, so this checklist and the viability card agree.
    missing: list[str] = []
    try:
        context = await _build_context(request, pred_request_id)
        # Same signature as the /appeal endpoint uses at line ~962.
        # Called with one argument this raised and the except swallowed
        # it, so the checklist silently reported zero gaps.
        appeal = resolve_appeal_viability(context, context.catalogue_rules)
        missing = list(appeal.get("missing_evidence") or [])
    except Exception as exc:  # noqa: BLE001
        logger.warning("appeal evidence: viability failed for %s: %s",
                       pred_request_id, exc)

    items.extend(
        {
            "kind": "gap",
            "key": f"gap:{m}",
            "label": m,
            "present": False,
            "detail": None,
            "confidence": None,
            "s3_key": None,
            "recorded_at": None,
            "recorded_by": None,
        }
        for m in missing
    )

    present = [i for i in items if i["present"]]
    return {
        "appeal_id": appeal_id,
        "pred_request_id": pred_request_id,
        "patient_name": a["patient_name"],
        "status": a["status"],
        "denial_reason": a["denial_reason"],
        "appeal_probability": a["appeal_probability"],
        "filed_at": _iso(a["filed_at"]),
        "evidence": items,
        "present_count": len(present),
        "missing_count": len(items) - len(present),
        # The one the checklist exists to answer: has a clinician put
        # their reasoning on the record for this case?
        "has_clinical_necessity": any(
            i["kind"] in ("clinical_justification", "clinical_narrative")
            for i in items
        ),
    }
