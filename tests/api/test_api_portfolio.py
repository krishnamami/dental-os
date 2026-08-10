"""The tenant boundary on /portfolio/summary, asserted over the WHOLE
payload rather than field by field.

── WHY IT IS WRITTEN THIS WAY ────────────────────────────────────────
The leak this replaces was not a wrong filter. It was a right filter
applied to one collection out of two: `tenants` was narrowed to the
caller and `top_denial_reasons` went back whole, so a Suwanee owner
received rows tagged dallas_dental and /dso/denials rendered
"SUWANEE 21 | TOTAL 22".

A per-field assertion would not have caught it, because the field that
leaked was the field nobody thought to assert on. So the test walks the
entire response — every dict, every list, at any depth — and fails on
any tenant_id outside the caller's own set. The next collection someone
adds is covered before it is written. `payer_performance` was in fact
added after this test existed, and this is what made adding it safe.

── THE THREE OWNERS ──────────────────────────────────────────────────
    dso_owner      Dr. Shyam       suwanee + tampa   two practices
    dallas_owner   Dr. Reyes       dallas            one
    orphan_owner   Dr. No Practice —                 none

Two and one matter because a scope that collapses to "my own row" gets
the single-practice case right and the multi-practice case wrong, which
is exactly the bug ownership was introduced to fix. None matters
because an empty scope must mean zero practices, not "unscoped".
"""
from __future__ import annotations

import pytest

pytestmark = pytest.mark.asyncio(loop_scope="session")

ALL_TENANTS = {"suwanee_smiles", "tampa_smiles", "dallas_dental"}
SHYAM_OWNS = {"suwanee_smiles", "tampa_smiles"}


def tenant_ids_in(node, found: set[str] | None = None) -> set[str]:
    """Every value of any `tenant_id` key, at any depth."""
    found = set() if found is None else found
    if isinstance(node, dict):
        for k, v in node.items():
            if k == "tenant_id" and isinstance(v, str):
                found.add(v)
            else:
                tenant_ids_in(v, found)
    elif isinstance(node, list):
        for item in node:
            tenant_ids_in(item, found)
    return found


async def portfolio(client, tokens, who: str) -> dict:
    r = await client.get("/portfolio/summary", headers=tokens[who])
    assert r.status_code == 200, f"{who} -> {r.status_code}\n{r.text[:400]}"
    return r.json()


# ── scope ────────────────────────────────────────────────────────────

async def test_an_owner_of_two_sees_both_and_only_those_two(client, tokens):
    """The point of the ownership table. Under users.tenant_id this
    returned one practice and Dr. Shyam needed a second login to see
    the other."""
    body = await portfolio(client, tokens, "dso_owner")

    assert tenant_ids_in(body) == SHYAM_OWNS, (
        f"payload names {sorted(tenant_ids_in(body))}, owns {sorted(SHYAM_OWNS)}"
    )
    assert body["summary"]["total_practices"] == 2
    assert {p["tenant_id"] for p in body["practices"]} == SHYAM_OWNS


async def test_an_owner_of_one_sees_one(client, tokens):
    """Same code path, not a special case."""
    body = await portfolio(client, tokens, "dallas_owner")

    assert tenant_ids_in(body) == {"dallas_dental"}
    assert body["summary"]["total_practices"] == 1


async def test_owning_nothing_is_an_empty_portfolio_not_a_403(client, tokens):
    """⚠ THE DANGEROUS CASE. An empty scope must mean zero practices.
    Read as "no filter" — which is what None means one line away in
    this endpoint — it would mean every practice in the deployment."""
    r = await client.get("/portfolio/summary", headers=tokens["orphan_owner"])
    assert r.status_code == 200, r.text[:300]
    body = r.json()

    assert tenant_ids_in(body) == set(), "an owner of nothing was shown a tenant"
    assert body["practices"] == []
    assert body["top_denial_reasons"] == []
    assert body["payer_performance"] == []
    assert body["summary"]["total_practices"] == 0
    assert body["summary"]["total_pre_ds"] == 0
    assert body["summary"]["overall_approval_rate"] == 0


async def test_accord_admin_still_sees_the_whole_group(client, tokens):
    """The narrowing must not become a cap."""
    body = await portfolio(client, tokens, "accord_admin")
    assert tenant_ids_in(body) == ALL_TENANTS
    assert body["summary"]["total_practices"] == 3


async def test_no_unowned_practice_is_named_anywhere(client, tokens):
    """Not just tenant_id keys. A practice_name or an address is the
    same disclosure spelled differently."""
    blob = (await client.get("/portfolio/summary",
                             headers=tokens["dallas_owner"])).text
    for foreign in ("Suwanee", "suwanee", "Tampa", "tampa"):
        assert foreign not in blob, (
            f"{foreign!r} appears in the Dallas owner's portfolio"
        )


# ── the loop really does bind each tenant ────────────────────────────

async def test_the_aggregate_equals_the_sum_of_the_per_tenant_reads(
    client, tokens
):
    """⚠ THE ONE THAT PROVES THE MECHANISM.

    Shyam's two-practice portfolio must equal, practice by practice,
    what each practice's own owner sees on their own. If the loop ran
    one query across both tenants instead of binding each — the thing
    RLS is there to prevent, and the thing a BYPASSRLS role would have
    made easy — the totals would still look plausible while the
    per-practice split silently came from a single unscoped scan.
    """
    both = await portfolio(client, tokens, "dso_owner")
    dallas = await portfolio(client, tokens, "dallas_owner")
    group = await portfolio(client, tokens, "accord_admin")

    by_tenant = {p["tenant_id"]: p for p in both["practices"]}
    reference = {p["tenant_id"]: p for p in group["practices"]}

    for tid in SHYAM_OWNS:
        for field in ("total_pre_ds", "approved", "denied", "pended",
                      "total_patient_pays"):
            assert by_tenant[tid][field] == reference[tid][field], (
                f"{tid}.{field} differs between a two-tenant read and a "
                f"whole-group read — the loop is not binding per tenant"
            )

    # And the summary is the sum of exactly those practices, not of the
    # group the query ran over.
    assert both["summary"]["total_pre_ds"] == sum(
        by_tenant[t]["total_pre_ds"] for t in SHYAM_OWNS)
    assert both["summary"]["total_denied"] == sum(
        by_tenant[t]["denied"] for t in SHYAM_OWNS)

    # Dallas is in the group total and in neither of Shyam's.
    assert dallas["summary"]["total_pre_ds"] > 0
    assert (both["summary"]["total_pre_ds"]
            + dallas["summary"]["total_pre_ds"]
            == group["summary"]["total_pre_ds"])


async def test_the_totals_match_the_practices_returned(client, tokens):
    """The visible symptom of the leak was arithmetic: a TOTAL column
    larger than the practices on screen."""
    for who in ("dso_owner", "dallas_owner", "accord_admin"):
        body = await portfolio(client, tokens, who)
        p, s = body["practices"], body["summary"]
        assert s["total_practices"] == len(p), who
        assert s["total_pre_ds"] == sum(x["total_pre_ds"] for x in p), who
        assert s["total_denied"] == sum(x["denied"] for x in p), who


# ── payer performance, which used to be a hardcoded literal ──────────

async def test_payer_performance_is_scoped_and_counted(client, tokens):
    """It was a static DATA array in PayerPerformance.tsx, counted by
    hand on 2026-08-06 and rendered to every user regardless of tenant
    — Suwanee's owner was looking at Tampa's and Dallas's payer mix."""
    body = await portfolio(client, tokens, "dso_owner")
    rows = body["payer_performance"]
    assert rows, "a practice with pre-Ds has payers"
    assert {r["tenant_id"] for r in rows} <= SHYAM_OWNS

    for r in rows:
        assert r["approved"] + r["denied"] <= r["total"]
        assert r["payer_name"], "a payer id with no display name"

    # Counted, not asserted against a literal: the per-payer totals for
    # one practice must add up to that practice's own pre-D count.
    for tid, practice in {p["tenant_id"]: p for p in body["practices"]}.items():
        counted = sum(r["total"] for r in rows if r["tenant_id"] == tid)
        assert counted == practice["total_pre_ds"], tid


# ── ownership does not widen chart access ────────────────────────────

@pytest.mark.parametrize("path", [
    "/decisions/PRED-SIM-DA-A01",
    "/decisions/PRED-SIM-DA-A01/clinical",
    "/decisions/PRED-SIM-DA-A01/patient-summary",
])
async def test_a_dso_owner_cannot_read_a_pred_he_does_not_own(
    client, tokens, path
):
    """Dallas's owner has no business in a Suwanee chart, on any route.
    404 rather than 403 — the id space must not become an oracle."""
    r = await client.get(path, headers=tokens["dallas_owner"])
    assert r.status_code == 404, f"{path} -> {r.status_code}\n{r.text[:300]}"


async def test_owning_a_practice_does_not_grant_its_charts(client, tokens):
    """⚠ A DELIBERATE LINE, WORTH RE-READING BEFORE CHANGING IT.

    Shyam owns tampa_smiles, and still cannot open a Tampa pre-D. The
    portfolio is aggregates only — "Tampa denies at 20%" is an owner's
    business, a Tampa patient's chart is not. Per-pre-D access stays on
    assert_tenant_allowed, which reads the practice he WORKS at.

    If that is ever meant to change, it changes here first, on purpose.
    """
    r = await client.get("/decisions/PRED-SIM-TB-A01",
                         headers=tokens["dso_owner"])
    assert r.status_code == 404, r.text[:300]


# ── the guard ────────────────────────────────────────────────────────

@pytest.mark.parametrize("role", ["front_desk", "tx_coord", "revenue_ops",
                                  "dentist"])
async def test_practice_staff_cannot_read_the_portfolio(client, tokens, role):
    """It was require_claims_or_demo. A front desk has no business
    reading practice-level revenue."""
    r = await client.get("/portfolio/summary", headers=tokens[role])
    assert r.status_code == 403, f"{role} -> {r.status_code}"


async def test_the_demo_header_cannot_read_the_portfolio(client):
    """The public tour's link was removed from lp/Products.tsx in the
    same change — an anonymous credential-free path to a practice's
    revenue is not a tour feature."""
    r = await client.get("/portfolio/summary",
                         headers={"X-Demo-Mode": "true"})
    assert r.status_code in (401, 403), r.text[:300]


async def test_no_token_is_401(client):
    r = await client.get("/portfolio/summary")
    assert r.status_code == 401
