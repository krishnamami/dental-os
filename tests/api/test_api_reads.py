"""Priority 1: every GET returns 200 and a well-formed body.

── WHAT THIS IS FOR ──────────────────────────────────────────────────
GET /denials shipped a 500 — `KeyError: 'predicted_viable'`, a
projection edited into the wrong function — in a session that reported
197 tests green. Not one of them had called an endpoint. Every test in
this file would have caught it, because the bar is "the route runs at
all", which no unit test in this repo was ever asking.

── HOW THE ASSERTIONS WERE CHOSEN ────────────────────────────────────
From the route list and the response models, BEFORE the suite was run
even once. That ordering is the point: assertions written after
watching what an endpoint does are a transcript of current behaviour,
including its bugs. Where a route declares a response_model, FastAPI
has already validated the body by the time a 200 arrives, so the
assertion here is shape plus the few keys a screen cannot render
without.

Counts come from the fixture, not from a previous run — 3 denials, 3
appeals, 50 pre-Ds are facts about tests/fixtures/*.sql.
"""
from __future__ import annotations

import pytest

# Which role is allowed to read what. One per route, chosen from
# docs/specs/roles.md rather than from whichever token happened to
# work — a read test passing under accord_admin proves nothing about
# the practice staff who actually open the screen.
pytestmark = pytest.mark.asyncio(loop_scope="session")


def ok(r, *, status: int = 200):
    assert r.status_code == status, (
        f"{r.request.method} {r.request.url} -> {r.status_code}\n"
        f"{r.text[:600]}"
    )
    return r.json()


def is_list_of_dicts(body) -> bool:
    return isinstance(body, list) and all(isinstance(x, dict) for x in body)


# ── the two that need no identity ────────────────────────────────────

async def test_health_reports_both_databases(client):
    body = ok(await client.get("/health"))
    assert body["status"] == "healthy", body
    # Both halves probed independently — a half-up service must say
    # which half, so neither may be None.
    assert body["simulator_db"] == "connected"
    assert body["os_db"] == "connected"
    assert body["simulator_scenarios"] and body["persona_bundles"]


async def test_login_returns_a_token_and_a_user(client):
    body = ok(await client.post("/auth/login", json={
        "email": "billing@suwaneesmiles.com", "password": "demo2026"}))
    assert body["token"]
    assert body["user"]["role"] == "revenue_ops"
    assert body["user"]["tenant_id"] == "suwanee_smiles"


# ── session ──────────────────────────────────────────────────────────

async def test_me_restores_the_session(client, tokens):
    body = ok(await client.get("/auth/me", headers=tokens["dentist"]))
    assert body["user"]["role"] == "dentist"
    assert body["token"]


async def test_users_lists_the_practice_staff(client, tokens):
    body = ok(await client.get("/auth/users", headers=tokens["dso_owner"]))
    assert is_list_of_dicts(body) and body
    assert all(u["tenant_id"] == "suwanee_smiles" for u in body)
    assert not any("password_hash" in u for u in body), (
        "a hash left the building"
    )


# ── the day-scoped reads ─────────────────────────────────────────────
# All four take ?date and ?tz_offset and none of them defaults — see
# core/dates.py. 240 is US Eastern in summer.

async def test_queue_returns_the_days_cases(client, tokens, sample):
    body = ok(await client.get("/decisions/queue", headers=tokens["dentist"],
                               params={"date": sample["schedule_date"],
                                       "tz_offset": 240}))
    assert is_list_of_dicts(body) and body, "the fixture has a schedule"
    # The queue projects `id`/`patient`, not the column names — it feeds
    # a card, not a record view (routes.py ~798).
    assert {"id", "patient", "status", "open", "blocking"} <= set(body[0])


async def test_submitted_on_a_day(client, tokens, sample):
    body = ok(await client.get("/decisions/submitted",
                               headers=tokens["revenue_ops"],
                               params={"date": sample["schedule_date"],
                                       "tz_offset": 240}))
    assert is_list_of_dicts(body)


async def test_signed_on_a_day(client, tokens, sample):
    body = ok(await client.get("/decisions/signed", headers=tokens["dentist"],
                               params={"date": sample["schedule_date"],
                                       "tz_offset": 240}))
    assert is_list_of_dicts(body)


async def test_checkin_today(client, tokens, sample):
    body = ok(await client.get("/checkin/today", headers=tokens["front_desk"],
                               params={"date": sample["schedule_date"],
                                       "tz_offset": 240}))
    assert is_list_of_dicts(body) and body
    assert "patient_name" in body[0]


async def test_checkin_dates_drives_the_picker(client, tokens):
    body = ok(await client.get("/checkin/dates", headers=tokens["front_desk"]))
    assert isinstance(body, list) and body
    assert all(isinstance(d, str) for d in body)
    assert body == sorted(body, reverse=True), "newest first, per the route"
    assert len(body) <= 30, "capped — it is a dropdown, not a report"


# ── one pre-D, five views ────────────────────────────────────────────

async def test_decision_bundle(client, tokens, sample):
    body = ok(await client.get(f"/decisions/{sample['pred']}",
                               headers=tokens["tx_coord"]))
    assert body["pred_request_id"] == sample["pred"]
    assert body["all_signals"], "a bundle with no signals is not a bundle"
    assert body["waves"], "five waves, per DecisionBundleResponse"


async def test_conditions_is_a_work_queue(client, tokens, sample):
    body = ok(await client.get(f"/decisions/{sample['pred']}/conditions",
                               headers=tokens["front_desk"]))
    assert "conditions" in body
    assert isinstance(body["conditions"], list)


async def test_patient_summary_has_the_money(client, tokens, sample):
    body = ok(await client.get(f"/decisions/{sample['pred']}/patient-summary",
                               headers=tokens["tx_coord"]))
    assert body["pred_request_id"] == sample["pred"]
    # Per CDT: charge, discount, allowed, plan pays, patient owes.
    assert body["procedures"], sorted(body)


async def test_clinical_view_has_three_buckets(client, tokens, sample):
    body = ok(await client.get(f"/decisions/{sample['pred']}/clinical",
                               headers=tokens["dentist"]))
    assert isinstance(body, dict) and body
    # Three buckets plus integrity — BUCKET_LABEL, routes.py:2955.
    keys = {b["key"] for b in body["buckets"]}
    assert keys == {"clinical_support", "documentation_gaps",
                    "payer_friction", "integrity_provider"}, keys


async def test_appeal_packet_for_a_denied_pred(client, tokens, sample):
    body = ok(await client.get(f"/decisions/{sample['denied_pred']}/appeal",
                               headers=tokens["revenue_ops"]))
    assert body["pred_request_id"] == sample["denied_pred"]


# ── revenue ops ──────────────────────────────────────────────────────

async def test_denials(client, tokens):
    """THE REGRESSION. This route 500'd on a KeyError in production."""
    body = ok(await client.get("/denials", headers=tokens["revenue_ops"]))
    assert is_list_of_dicts(body)
    assert len(body) == 3, "the fixture holds three denial_events"
    assert {"denial_id", "pred_request_id", "denied_amount"} <= set(body[0])


async def test_appeals_carry_the_prediction_snapshot(client, tokens):
    body = ok(await client.get("/appeals", headers=tokens["revenue_ops"]))
    assert is_list_of_dicts(body)
    assert len(body) == 3, "the fixture holds three appeal_events"
    # migration 010 — the engine's verdict as it stood at filing.
    assert "predicted_viable" in body[0], sorted(body[0])


async def test_appeal_evidence(client, tokens, sample):
    body = ok(await client.get(f"/appeals/{sample['appeal_id']}/evidence",
                               headers=tokens["revenue_ops"]))
    assert isinstance(body, dict) and body


async def test_billing_analytics_separates_the_two_denials(client, tokens):
    body = ok(await client.get("/analytics/billing",
                               headers=tokens["revenue_ops"]))
    # The route's own docstring: cases.denied is the ENGINE's verdict,
    # denials.total is what a payer actually refused. Both, by name.
    assert "cases" in body and "denials" in body, sorted(body)


# ── owner / admin ────────────────────────────────────────────────────

async def test_portfolio_summary_is_aggregates_only(client, tokens):
    body = ok(await client.get("/portfolio/summary",
                               headers=tokens["dso_owner"]))
    assert isinstance(body, dict) and body
    blob = repr(body)
    assert "PRED-SIM" not in blob, "the only cross-tenant route leaked a pre-D"


async def test_admin_overlays(client, tokens):
    body = ok(await client.get("/admin/overlays", headers=tokens["dso_owner"]))
    assert is_list_of_dicts(body)


async def test_admin_practice(client, tokens):
    body = ok(await client.get("/admin/practice", headers=tokens["dso_owner"]))
    assert isinstance(body, dict) and body
