"""
Shared rule loader for all dental resolvers.

Reads from three catalogue layers (CONTEXT.md RULE 2):
  Layer 1  ada_guidelines      clinical authority — the FLOOR
  Layer 2  payer rules         coverage / bundling / frequency / downgrade
  Layer 3  overlay_rules       tenant config — ALWAYS WINS

Note the inversion from lending: there, agency guidelines sit ABOVE the
regulatory floor. Here ADA is a clinical floor that neither a payer rule
nor a tenant overlay may drop below — an overlay may be STRICTER, never
looser. resolve_layered() enforces that; a looser overlay is applied
(the tenant asked for it) but flagged `breaches_clinical_floor` so the
persona can surface it rather than silently honouring it.

RULE 4  The enricher calls this. Personas NEVER call it directly.
RULE 8  Catalogue before code — seed the rule, verify it loads, then
        write the resolver against it.
RULE 9  SAFE_DEFAULTS is the only fallback. A missing rule logs a
        WARNING naming the row to add and returns the default. This
        module NEVER raises on missing data.
RULE 12 Every query runs under SET app.tenant_id. The caller is
        responsible for setting it on the connection; load_dental_rules
        sets it defensively as well.

SCHEMA NOTES (verified against the live RDS 2026-08-05):
  - ada_guidelines.clinical_thresholds is JSONB and carries the real
    numbers (bone_loss_mm_min, pocket_depth_mm_min, sites_min, age_min).
    The scalar auto_approve_score / auto_deny_score columns duplicate
    two of those keys; the columns win when they disagree.
  - bundling_rules.payer_id is NULL on 18 of 20 rows. Those are ADA
    coding standards that apply to every payer, so the query is
    `payer_id = $1 OR payer_id IS NULL` — filtering on payer alone
    would drop every hard-bundling rule including D2950 + crown.
  - frequency_limits and downgrade_matrix load for ALL payers, not just
    the current one. Cross-payer comparison is the point: MetLife pays
    D0330 1-per-3-years where Delta pays 1-per-5.
  - overlay_rules.rule_overrides is JSONB keyed on (tenant, payer, cdt).
  - asyncpg returns NUMERIC as Decimal and JSONB as str on this pool.
    _num() and _json() normalise at the boundary.
"""
from __future__ import annotations

import json
import logging
from decimal import Decimal
from typing import Any, Optional

import asyncpg

logger = logging.getLogger(__name__)


# ─────────────────────────────────────────────────────────────────────
# RULE 9 — the only acceptable fallback.
# ─────────────────────────────────────────────────────────────────────

SAFE_DEFAULTS: dict[str, Any] = {
    "bone_loss_mm_min": 3.0,
    "pocket_depth_mm_min": 5.0,
    "auto_approve_score": 0.85,
    "auto_deny_score": 0.30,
    "frequency_period": "per_5_years",
    "sla_hours": 48,
}

# Layer numbers, so a persona can say WHERE a threshold came from.
LAYER_ADA = 1
LAYER_PAYER = 2
LAYER_OVERLAY = 3


# ─────────────────────────────────────────────────────────────────────
# Coercion
# ─────────────────────────────────────────────────────────────────────


def _num(value: Any) -> Optional[float]:
    if value is None:
        return None
    if isinstance(value, Decimal):
        return float(value)
    if isinstance(value, bool):
        return float(value)
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _json(value: Any, default: Any) -> Any:
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


def get_rule(rules: dict, section: str, key: Any, field: str) -> Any:
    """Read one field out of a loaded rules dict, falling back to
    SAFE_DEFAULTS with a WARNING that names what to seed.

    This is the accessor a resolver should use rather than indexing the
    dict directly, so a missing catalogue row degrades to a documented
    default instead of a KeyError mid-decision.
    """
    entry = (rules.get(section) or {}).get(key)
    if entry is not None and field in entry and entry[field] is not None:
        return entry[field]

    default = SAFE_DEFAULTS.get(field)
    logger.warning(
        "CATALOGUE MISSING: %s[%r].%s — using safe default %r. "
        "Seed the row in dental-simulator and re-run "
        "scripts/verify_catalogue.py.",
        section,
        key,
        field,
        default,
    )
    return default


# ─────────────────────────────────────────────────────────────────────
# Layer resolution — ADA floor vs payer vs tenant overlay
# ─────────────────────────────────────────────────────────────────────


def resolve_layered(
    ada_value: Any = None,
    payer_value: Any = None,
    overlay_value: Any = None,
    *,
    stricter_is_higher: bool = True,
) -> dict:
    """Resolve one threshold across the three layers.

    Overlay always wins on `applied` — that is RULE 2 and the practice
    asked for it. But when the overlay is LOOSER than the ADA clinical
    floor, `breaches_clinical_floor` is set so the persona surfaces the
    fact rather than quietly applying it. ADA is a floor, not a
    suggestion.
    """
    layers: dict[str, Any] = {}
    if ada_value is not None:
        layers["ada"] = ada_value
    if payer_value is not None:
        layers["payer"] = payer_value
    if overlay_value is not None:
        layers["overlay"] = overlay_value

    if overlay_value is not None:
        applied, governed_by, layer = overlay_value, "tenant_overlay", LAYER_OVERLAY
    elif payer_value is not None:
        applied, governed_by, layer = payer_value, "payer", LAYER_PAYER
    elif ada_value is not None:
        applied, governed_by, layer = ada_value, "ADA", LAYER_ADA
    else:
        return {
            "applied": None,
            "governed_by": "safe_default",
            "layer": None,
            "layers": {},
            "using_default": True,
            "breaches_clinical_floor": False,
        }

    breaches = False
    a, ada = _num(applied), _num(ada_value)
    if a is not None and ada is not None:
        breaches = (a < ada) if stricter_is_higher else (a > ada)

    return {
        "applied": applied,
        "governed_by": governed_by,
        "layer": layer,
        "layers": layers,
        "using_default": False,
        "breaches_clinical_floor": breaches,
    }


# ─────────────────────────────────────────────────────────────────────
# load_dental_rules
# ─────────────────────────────────────────────────────────────────────


async def load_dental_rules(
    conn: asyncpg.Connection,
    tenant_id: str,
    payer_id: str = "delta_dental",
) -> dict:
    """
    Load all catalogue rules for one pre-D evaluation.

    Returns a structured dict — personas read from this, never from the
    DB directly (RULE 5). Never raises: a table that is empty or missing
    yields an empty section plus a WARNING, because a decision that
    degrades loudly beats one that crashes mid-wave.

    Opens its own transaction when the caller has not already. That is
    not a nicety: set_config(..., is_local => true) is scoped to the
    enclosing transaction, so outside one the tenant is discarded the
    instant the statement ends. Every subsequent read then runs with NO
    tenant — and because RLS returns 0 rows rather than an error, the
    tenant-scoped sections (overlay_rules) come back EMPTY while the
    non-tenant reference tables load fine. The result looks like a
    successful load with no tenant overlay, which is exactly the shape
    of a silent wrong answer. Caught by verify_catalogue.py.
    """
    if not conn.is_in_transaction():
        async with conn.transaction():
            return await _load(conn, tenant_id, payer_id)
    return await _load(conn, tenant_id, payer_id)


async def _load(
    conn: asyncpg.Connection,
    tenant_id: str,
    payer_id: str,
) -> dict:
    await conn.execute("SELECT set_config('app.tenant_id', $1, true)", tenant_id)

    # Read it back. Cheap, and it turns "RLS quietly returned nothing"
    # into a loud warning naming the cause.
    active = await conn.fetchval("SELECT current_setting('app.tenant_id', true)")
    if active != tenant_id:
        logger.warning(
            "TENANT NOT SET: requested %r but current_setting reports %r. Every "
            "tenant-scoped read below will return 0 rows with no error. This "
            "usually means set_config ran outside a transaction.",
            tenant_id,
            active,
        )

    rules: dict[str, Any] = {
        "_meta": {
            "tenant_id": tenant_id,
            "payer_id": payer_id,
            "layers": {
                LAYER_ADA: "ada_guidelines (clinical floor, cannot be overridden)",
                LAYER_PAYER: "payer rules (coverage / bundling / frequency / downgrade)",
                LAYER_OVERLAY: "overlay_rules (tenant — always wins)",
            },
            "missing_sections": [],
        }
    }

    # ── Layer 1: ADA guidelines ──────────────────────────────────────
    ada: dict[str, dict] = {}
    for r in await conn.fetch(
        """
        SELECT cdt_code, guideline_name, guideline_type, issuing_body,
               criteria_checklist, clinical_thresholds,
               auto_approve_score, auto_deny_score, citation, guideline_version
        FROM ada_guidelines
        ORDER BY cdt_code
        """
    ):
        thresholds = _json(r["clinical_thresholds"], {})
        entry: dict[str, Any] = {
            # Every key of clinical_thresholds is promoted to the top
            # level so a resolver reads bone_loss_mm_min directly rather
            # than reaching into a nested dict.
            **{k: _num(v) if isinstance(v, (int, float, Decimal)) else v
               for k, v in thresholds.items()},
            "criteria_checklist": _json(r["criteria_checklist"], []),
            "clinical_thresholds": thresholds,
            "guideline_name": r["guideline_name"],
            "guideline_type": r["guideline_type"],
            "guideline_version": r["guideline_version"],
            "issuing_body": r["issuing_body"],
            "citation": r["citation"],
            "governed_by": "ADA",
            "layer": LAYER_ADA,
        }
        # The scalar columns are authoritative over the JSONB copies.
        entry["auto_approve_score"] = _num(r["auto_approve_score"])
        entry["auto_deny_score"] = _num(r["auto_deny_score"])
        ada[r["cdt_code"]] = entry
    rules["ada_thresholds"] = ada
    _warn_if_empty(rules, "ada_thresholds", "ada_guidelines")

    # ── Layer 2: bundling ────────────────────────────────────────────
    # payer_id IS NULL means "applies to every payer" — 18 of the 20
    # rows are universal ADA coding standards. Dropping them would lose
    # every hard-bundling rule, D2950 + crown included.
    bundling: dict[tuple, dict] = {}
    for r in await conn.fetch(
        """
        SELECT payer_id, primary_cdt_code, bundled_cdt_code, bundling_type,
               scope, separable, separation_criteria, denial_reason_code,
               policy_section
        FROM bundling_rules
        WHERE payer_id = $1 OR payer_id IS NULL
        ORDER BY payer_id NULLS LAST
        """,
        payer_id,
    ):
        key = (r["primary_cdt_code"], r["bundled_cdt_code"])
        entry = {
            "bundling_type": r["bundling_type"],
            "scope": r["scope"],
            "separable": r["separable"],
            "separation_criteria": r["separation_criteria"],
            "denial_reason_code": r["denial_reason_code"],
            "policy_section": r["policy_section"],
            "payer_id": r["payer_id"],
            "applies_to_all_payers": r["payer_id"] is None,
            "governed_by": "payer" if r["payer_id"] else "ADA_coding_standard",
            "layer": LAYER_PAYER if r["payer_id"] else LAYER_ADA,
        }
        # ORDER BY payer_id NULLS LAST puts the payer-specific row first,
        # so a payer rule beats the universal one on the same pair.
        bundling.setdefault(key, entry)
        # Bundling is symmetric in practice — the pair conflicts whichever
        # order the codes were billed in. Register the reverse only if it
        # is not already an explicit rule of its own.
        bundling.setdefault((key[1], key[0]), {**entry, "_reversed": True})
    rules["bundling_rules"] = bundling
    _warn_if_empty(rules, "bundling_rules", "bundling_rules")

    # ── Layer 2: frequency limits (ALL payers) ───────────────────────
    frequency: dict[tuple, dict] = {}
    for r in await conn.fetch(
        """
        SELECT payer_id, plan_type, cdt_code, frequency_count, frequency_period,
               frequency_scope, age_limit_min, age_limit_max, waiting_days, notes
        FROM frequency_limits
        ORDER BY payer_id, cdt_code
        """
    ):
        frequency[(r["payer_id"], r["cdt_code"])] = {
            "frequency_count": r["frequency_count"],
            "frequency_period": r["frequency_period"],
            "frequency_scope": r["frequency_scope"],
            "plan_type": r["plan_type"],
            "age_limit_min": r["age_limit_min"],
            "age_limit_max": r["age_limit_max"],
            "waiting_days": r["waiting_days"],
            "notes": r["notes"],
            "payer_id": r["payer_id"],
            "governed_by": "payer",
            "layer": LAYER_PAYER,
        }
    rules["frequency_limits"] = frequency
    _warn_if_empty(rules, "frequency_limits", "frequency_limits")

    # ── Layer 2: downgrade matrix (ALL payers) ───────────────────────
    # Absence is meaningful: no ('cigna','D2740') key means Cigna does
    # NOT downgrade that code. Callers use .get() and read None as "no
    # downgrade", which is why this is never backfilled with placeholders.
    downgrade: dict[tuple, dict] = {}
    for r in await conn.fetch(
        """
        SELECT payer_id, plan_type, billed_cdt_code, paid_cdt_code,
               tooth_position, downgrade_reason, patient_choice_allowed,
               policy_section
        FROM downgrade_matrix
        ORDER BY payer_id, billed_cdt_code
        """
    ):
        downgrade[(r["payer_id"], r["billed_cdt_code"])] = {
            "paid_cdt_code": r["paid_cdt_code"],
            "tooth_position": r["tooth_position"],
            "downgrade_reason": r["downgrade_reason"],
            "patient_choice_allowed": r["patient_choice_allowed"],
            "policy_section": r["policy_section"],
            "plan_type": r["plan_type"],
            "payer_id": r["payer_id"],
            "governed_by": "payer",
            "layer": LAYER_PAYER,
        }
    rules["downgrade_matrix"] = downgrade
    _warn_if_empty(rules, "downgrade_matrix", "downgrade_matrix")

    # ── Layer 1/2: CDT documentation requirements ────────────────────
    cdt: dict[str, dict] = {}
    for r in await conn.fetch(
        """
        SELECT cdt_code, description, category, subcategory,
               tooth_specific, surface_specific, arch_specific, quadrant_specific,
               valid_tooth_ranges, valid_surfaces, age_limit_min, age_limit_max,
               requires_xray, requires_perio_chart, requires_narrative,
               requires_medical_clearance, sedation_code
        FROM cdt_codes
        ORDER BY cdt_code
        """
    ):
        cdt[r["cdt_code"]] = {
            "description": r["description"],
            "category": r["category"],
            "subcategory": r["subcategory"],
            "requires_xray": r["requires_xray"],
            "requires_perio_chart": r["requires_perio_chart"],
            "requires_narrative": r["requires_narrative"],
            "requires_medical_clearance": r["requires_medical_clearance"],
            "tooth_specific": r["tooth_specific"],
            "surface_specific": r["surface_specific"],
            "arch_specific": r["arch_specific"],
            "quadrant_specific": r["quadrant_specific"],
            "valid_tooth_ranges": r["valid_tooth_ranges"],
            "valid_surfaces": r["valid_surfaces"],
            "age_limit_min": r["age_limit_min"],
            "age_limit_max": r["age_limit_max"],
            "sedation_code": r["sedation_code"],
            "governed_by": "ADA",
            "layer": LAYER_ADA,
        }
    rules["cdt_rules"] = cdt
    _warn_if_empty(rules, "cdt_rules", "cdt_codes")

    # ── Layer 2: coverage rules for this payer ───────────────────────
    coverage: dict[str, dict] = {}
    for r in await conn.fetch(
        """
        SELECT payer_id, cdt_code, covered, benefit_category, coverage_pct,
               frequency_limit, frequency_unit, frequency_scope, bundled_with,
               bundling_note, bundling_separable, downgrade_to_cdt, downgrade_note,
               missing_tooth_clause_applies, pred_required,
               clinical_criteria_required, policy_section
        FROM coverage_rules
        WHERE payer_id = $1
        ORDER BY cdt_code
        """,
        payer_id,
    ):
        coverage[r["cdt_code"]] = {
            "covered": r["covered"],
            "benefit_category": r["benefit_category"],
            "coverage_pct": _num(r["coverage_pct"]),
            "frequency_limit": r["frequency_limit"],
            "frequency_unit": r["frequency_unit"],
            "frequency_scope": r["frequency_scope"],
            "bundled_with": r["bundled_with"],
            "bundling_note": r["bundling_note"],
            "bundling_separable": r["bundling_separable"],
            "downgrade_to_cdt": r["downgrade_to_cdt"],
            "downgrade_note": r["downgrade_note"],
            "missing_tooth_clause_applies": r["missing_tooth_clause_applies"],
            "pred_required": r["pred_required"],
            "clinical_criteria_required": r["clinical_criteria_required"],
            "policy_section": r["policy_section"],
            "payer_id": r["payer_id"],
            "governed_by": "payer",
            "layer": LAYER_PAYER,
        }
    rules["coverage_rules"] = coverage
    _warn_if_empty(rules, "coverage_rules", "coverage_rules")

    # ── Conditions library ───────────────────────────────────────────
    conditions: dict[str, dict] = {}
    for r in await conn.fetch(
        """
        SELECT condition_code, category, template_text, payer_citation,
               sla_hours, assignee, recommended_action
        FROM conditions_library
        ORDER BY condition_code
        """
    ):
        conditions[r["condition_code"]] = {
            "category": r["category"],
            "template_text": r["template_text"],
            "payer_citation": r["payer_citation"],
            "sla_hours": r["sla_hours"] if r["sla_hours"] is not None
                         else SAFE_DEFAULTS["sla_hours"],
            "assignee": r["assignee"],
            "recommended_action": r["recommended_action"],
            "governed_by": "payer",
            "layer": LAYER_PAYER,
        }
    rules["conditions_library"] = conditions
    _warn_if_empty(rules, "conditions_library", "conditions_library")

    # ── Medical history flags ────────────────────────────────────────
    flags: dict[str, dict] = {}
    for r in await conn.fetch(
        """
        SELECT flag_code, flag_name, flag_category, contraindicated_cdts,
               risk_level, icd10_codes, drug_names, drug_classes,
               documentation_required, clinical_action, notes
        FROM medical_history_flags
        ORDER BY flag_code
        """
    ):
        flags[r["flag_code"]] = {
            "flag_name": r["flag_name"],
            "flag_category": r["flag_category"],
            "contraindicated_cdts": list(r["contraindicated_cdts"] or []),
            "risk_level": r["risk_level"],
            "icd10_codes": list(r["icd10_codes"] or []),
            "drug_names": list(r["drug_names"] or []),
            "drug_classes": list(r["drug_classes"] or []),
            "documentation_required": r["documentation_required"],
            "clinical_action": r["clinical_action"],
            "notes": r["notes"],
            "governed_by": "ADA",
            "layer": LAYER_ADA,
        }
    rules["medical_history_flags"] = flags
    _warn_if_empty(rules, "medical_history_flags", "medical_history_flags")

    # ── Layer 3: tenant overlay — ALWAYS WINS ────────────────────────
    overlay_by_cdt: dict[str, dict] = {}
    for r in await conn.fetch(
        """
        SELECT tenant_id, payer_id, cdt_code, rule_overrides, reason,
               effective_from, effective_to
        FROM overlay_rules
        WHERE tenant_id = $1
          AND (payer_id = $2 OR payer_id IS NULL)
          AND active = true
          AND (effective_from IS NULL OR effective_from <= CURRENT_DATE)
          AND (effective_to   IS NULL OR effective_to   >= CURRENT_DATE)
        ORDER BY payer_id NULLS LAST
        """,
        tenant_id,
        payer_id,
    ):
        overrides = _json(r["rule_overrides"], {})
        overlay_by_cdt[r["cdt_code"]] = {
            "overrides": overrides,
            "reason": r["reason"],
            "payer_id": r["payer_id"],
            "governed_by": "tenant_overlay",
            "layer": LAYER_OVERLAY,
        }
    rules["overlay_rules"] = {
        "tenant_id": tenant_id,
        "payer_id": payer_id,
        "rules": overlay_by_cdt,
    }
    if not overlay_by_cdt:
        logger.info(
            "No active tenant overlay for tenant=%s payer=%s. Payer rules "
            "apply unmodified.",
            tenant_id,
            payer_id,
        )

    # ── Apply overlay on top of coverage + cdt rules ─────────────────
    # Layer 3 always wins. Each overridden field records what it
    # replaced, so the trace can show ADA | payer | overlay | applied.
    for cdt_code, ov in overlay_by_cdt.items():
        for section in ("coverage_rules", "cdt_rules"):
            target = rules[section].get(cdt_code)
            if target is None:
                continue
            for field, value in (ov["overrides"] or {}).items():
                if field not in target:
                    continue
                target.setdefault("_overlay_replaced", {})[field] = target[field]
                target[field] = value
                target["governed_by"] = "tenant_overlay"
                target["layer"] = LAYER_OVERLAY
                target["overlay_reason"] = ov["reason"]

    return rules


def _warn_if_empty(rules: dict, section: str, table: str) -> None:
    if not rules.get(section):
        rules["_meta"]["missing_sections"].append(section)
        logger.warning(
            "CATALOGUE EMPTY: %s loaded 0 rows from dental-simulator table %r. "
            "Resolvers will fall back to SAFE_DEFAULTS. Seed the table and "
            "re-run scripts/verify_catalogue.py.",
            section,
            table,
        )
