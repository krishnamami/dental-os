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
any tenant_id that is not the caller's. The next collection someone
adds is covered before it is written.

The recursion also reaches values that are not under a `tenant_id` key
at all: a practice name or an address carrying another practice's
identity is the same disclosure by a different route.
"""
from __future__ import annotations

import pytest

pytestmark = pytest.mark.asyncio(loop_scope="session")

ALL_TENANTS = ("suwanee_smiles", "tampa_smiles", "dallas_dental")


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


async def test_a_single_tenant_owner_sees_only_his_own_tenant(client, tokens):
    """THE REGRESSION, as one assertion over the whole payload."""
    r = await client.get("/portfolio/summary", headers=tokens["dso_owner"])
    assert r.status_code == 200, r.text[:400]
    body = r.json()

    seen = tenant_ids_in(body)
    assert seen == {"suwanee_smiles"}, (
        f"the payload names {sorted(seen)}; this caller owns "
        f"suwanee_smiles. A collection is being returned unnarrowed — "
        f"add it to _PORTFOLIO_COLLECTIONS in api/routes.py."
    )


async def test_no_other_practice_is_named_anywhere_in_the_payload(
    client, tokens
):
    """Not just tenant_id keys. A practice_name or an address is the
    same disclosure spelled differently."""
    r = await client.get("/portfolio/summary", headers=tokens["dso_owner"])
    blob = r.text
    for foreign in ("tampa", "dallas", "Tampa", "Dallas"):
        assert foreign not in blob, (
            f"{foreign!r} appears in a suwanee_smiles owner's portfolio"
        )


async def test_the_denial_reasons_are_the_callers_own(client, tokens):
    """The collection that actually leaked, named explicitly so the
    reason this test exists survives a refactor of the one above."""
    r = await client.get("/portfolio/summary", headers=tokens["dso_owner"])
    reasons = r.json()["top_denial_reasons"]
    assert reasons, "a practice with denials should report conditions"
    assert {x["tenant_id"] for x in reasons} == {"suwanee_smiles"}


async def test_the_totals_match_the_practices_returned(client, tokens):
    """The visible symptom was arithmetic: a TOTAL column larger than
    the only practice on screen. Summing what is returned must equal
    what is reported."""
    body = (await client.get("/portfolio/summary",
                             headers=tokens["dso_owner"])).json()
    practices = body["practices"]
    s = body["summary"]
    assert s["total_practices"] == len(practices)
    assert s["total_pre_ds"] == sum(p["total_pre_ds"] for p in practices)
    assert s["total_denied"] == sum(p["denied"] for p in practices)


async def test_the_tampa_owner_sees_tampa_and_nothing_else(client, tokens):
    """Two practices, two answers — a filter that returns the caller's
    tenant by accident of ordering would pass the Suwanee test alone."""
    r = await client.get("/portfolio/summary",
                         headers=tokens["tampa_dso_owner"])
    assert r.status_code == 200, r.text[:400]
    assert tenant_ids_in(r.json()) == {"tampa_smiles"}


async def test_accord_admin_still_sees_the_whole_group(client, tokens):
    """The narrowing must not become a cap. An admin is the one caller
    this endpoint exists to serve at full width."""
    body = (await client.get("/portfolio/summary",
                             headers=tokens["accord_admin"])).json()
    assert tenant_ids_in(body) == set(ALL_TENANTS)
    assert body["summary"]["total_practices"] == 3


# ── the guard ────────────────────────────────────────────────────────

@pytest.mark.parametrize("role", ["front_desk", "tx_coord", "revenue_ops",
                                  "dentist"])
async def test_practice_staff_cannot_read_the_portfolio(client, tokens, role):
    """It was require_claims_or_demo. A front desk has no business
    reading practice-level revenue."""
    r = await client.get("/portfolio/summary", headers=tokens[role])
    assert r.status_code == 403, f"{role} -> {r.status_code}"


async def test_the_demo_header_cannot_read_the_portfolio(client):
    """⚠ THIS BREAKS THE PUBLIC DEMO TOUR ON PURPOSE. The marketing
    site links /dso?demo=true (lp/Products.tsx), and DEMO_CLAIMS carries
    role=dentist, so the tour now gets a 403 on this endpoint. That is
    the intended trade: an anonymous credential-free path to a
    practice's revenue is not a tour feature."""
    r = await client.get("/portfolio/summary",
                         headers={"X-Demo-Mode": "true"})
    assert r.status_code in (401, 403), r.text[:300]


async def test_no_token_is_401(client):
    r = await client.get("/portfolio/summary")
    assert r.status_code == 401
