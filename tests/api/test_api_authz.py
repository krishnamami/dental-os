"""Priority 2: every write returns the right status for every role.

── THE MATRIX IS THE TEST ────────────────────────────────────────────
One table, WRITES, listing each write endpoint with the roles its
capability admits (api/auth.py, `_capability`). Every role is then run
against every endpoint: the admitted ones must succeed, the rest must
be refused. Enumerating both halves is the point — a guard that admits
everybody passes an "allowed role can write" test perfectly.

── WHY 403 AND NOT 404 FOR A ROLE, AND 404 AND NOT 403 FOR A TENANT ──
A role refusal says "you, specifically, may not do this", which the
caller can act on. A tenant refusal must not confirm the record exists,
or the endpoint becomes an oracle: walk the id space and the difference
between 403 and 404 maps out a competitor's caseload. That asymmetry is
deliberate (auth.assert_tenant_allowed) and both directions are
asserted here.

── accord_admin IS IN EVERY allowed LIST ─────────────────────────────
_capability() adds it. Not listed per row; ADMIN is folded in below.
"""
from __future__ import annotations

import pytest

pytestmark = pytest.mark.asyncio(loop_scope="session")

PRED = "PRED-SIM-DA-A01"
DENIED_PRED = "PRED-SIM-DA-B04"

STAFF = ("front_desk", "tx_coord", "revenue_ops", "dentist", "dso_owner")
ADMIN = "accord_admin"


def _appointment_body() -> dict:
    return {
        "tenant_id": "suwanee_smiles",
        "pred_request_id": PRED,
        "patient_name": "Authz Test",
        "appointment_date": "2026-08-15",
        "appointment_time": "10:30",
        "procedure_summary": "Implant consult",
        "provider_npi": "1234567890",
    }


# method, path, body, roles admitted BESIDES accord_admin, the guard
WRITES: tuple[tuple[str, str, dict | None, tuple[str, ...], str], ...] = (
    ("POST", f"/decisions/{PRED}/feedback",
     {"decision_id": PRED, "signal_code": "ELIGIBILITY_VERIFIED",
      "feedback_type": "accepted", "notes": "authz", "submitted_by": "dentist"},
     ("revenue_ops", "dentist"), "require_engine_feedback"),

    ("POST", f"/decisions/{PRED}/attest", None,
     ("dentist",), "require_clinician_cap"),

    ("POST", f"/decisions/{PRED}/narrative",
     {"narrative_text": "Authz probe narrative.", "source": "edited"},
     ("dentist",), "require_clinician_cap"),

    ("POST", f"/decisions/{PRED}/justification",
     # A code that is actually on this pre-D: /justification rejects a
     # signal the case does not carry, and rightly so.
     {"signal_code": "DOC_NARRATIVE_MISSING", "justification": "Authz probe."},
     ("dentist",), "require_clinician_cap"),

    ("POST", f"/decisions/{PRED}/document-requests",
     {"requests": [{"document_type": "radiograph"}],
      "requested_from": "front_desk"},
     ("dentist", "tx_coord"), "require_document_chase"),

    ("POST", f"/decisions/{PRED}/handoff",
     {"to_role": "dentist", "note": "Authz probe.", "kind": "note"},
     STAFF, "require_handoff_sender"),

    ("POST", "/communications/sms",
     {"pred_request_id": PRED, "patient_name": "Authz Test",
      "message": "Authz probe."},
     ("front_desk", "tx_coord", "revenue_ops", "dentist"),
     "require_patient_contact"),

    ("POST", "/appeals",
     {"pred_request_id": DENIED_PRED, "patient_name": "Authz Test",
      "payer_id": "delta_dental", "appeal_type": "standard"},
     ("revenue_ops",), "require_billing"),

    ("POST", "/integrations/appointments", _appointment_body(),
     (), "require_admin"),
)

# GETs behind a capability rather than plain authentication.
ADMIN_READS = (
    ("/auth/users", ("dso_owner",), "require_practice_admin"),
    ("/admin/overlays", ("dso_owner",), "require_practice_admin"),
    ("/admin/practice", ("dso_owner",), "require_practice_admin"),
)


def _denied(allowed: tuple[str, ...]) -> list[str]:
    return [r for r in STAFF if r not in allowed]


def _ids(rows):
    return [f"{r[1].split('/')[-1]}:{r[-1]}" for r in rows]


# ── refusals ─────────────────────────────────────────────────────────

@pytest.mark.parametrize(
    "method,path,body,role,guard",
    [(m, p, b, r, g) for m, p, b, allowed, g in WRITES
     for r in _denied(allowed)],
    ids=lambda v: v if isinstance(v, str) else "",
)
async def test_write_refuses_the_wrong_role(
    client, tokens, method, path, body, role, guard
):
    """403, with a message. Not 401 — the caller IS authenticated."""
    r = await client.request(method, path, json=body, headers=tokens[role])
    assert r.status_code == 403, (
        f"{guard} let {role} through {method} {path} -> {r.status_code}\n"
        f"{r.text[:400]}"
    )
    assert r.json()["detail"], "a 403 with no reason is not actionable"


@pytest.mark.parametrize("path,allowed,guard", ADMIN_READS)
@pytest.mark.parametrize("role", ["front_desk", "tx_coord", "revenue_ops",
                                  "dentist"])
async def test_admin_read_refuses_practice_staff(
    client, tokens, path, allowed, guard, role
):
    r = await client.get(path, headers=tokens[role])
    assert r.status_code == 403, f"{guard} let {role} read {path}"


@pytest.mark.parametrize("method,path", [
    ("GET", "/denials"),
    ("GET", "/appeals"),
    ("GET", f"/decisions/{PRED}"),
    ("GET", "/portfolio/summary"),
    ("POST", f"/decisions/{PRED}/attest"),
    ("POST", "/appeals"),
])
async def test_no_token_is_401(client, method, path):
    r = await client.request(method, path, json={})
    assert r.status_code == 401, f"{method} {path} -> {r.status_code}"


# ── the permitted half ───────────────────────────────────────────────

@pytest.mark.parametrize(
    "method,path,body,role,guard",
    [(m, p, b, (allowed[0] if allowed else ADMIN), g)
     for m, p, b, allowed, g in WRITES],
    ids=lambda v: v if isinstance(v, str) else "",
)
async def test_write_admits_the_right_role(
    client, tokens, reset_events, method, path, body, role, guard
):
    """A 2xx, or a 409 — which is a guard doing its job, not a refusal.

    Anything in the 4xx range other than 409 means the capability
    admitted the role and something further in refused it, which is the
    failure this half exists to find.
    """
    r = await client.request(method, path, json=body, headers=tokens[role])
    assert r.status_code in (200, 201, 409), (
        f"{guard} refused {role} on {method} {path} -> {r.status_code}\n"
        f"{r.text[:400]}"
    )


@pytest.mark.parametrize("method,path,body,_a,guard", WRITES,
                         ids=lambda v: v if isinstance(v, str) else "")
async def test_accord_admin_is_admitted_everywhere(
    client, tokens, reset_events, method, path, body, _a, guard
):
    """_capability() folds accord_admin into every allowed set."""
    r = await client.request(method, path, json=body, headers=tokens[ADMIN])
    assert r.status_code != 403, f"{guard} refused accord_admin on {path}"


# ── the tenant boundary ──────────────────────────────────────────────

@pytest.mark.parametrize("path", [
    f"/decisions/{PRED}",
    f"/decisions/{PRED}/conditions",
    f"/decisions/{PRED}/patient-summary",
    f"/decisions/{PRED}/clinical",
    f"/decisions/{DENIED_PRED}/appeal",
])
async def test_cross_tenant_read_is_404_not_403(client, tokens, path):
    """Tampa asking about a Suwanee pre-D is told it does not exist."""
    r = await client.get(path, headers=tokens["tampa_dentist"])
    assert r.status_code == 404, (
        f"{path} -> {r.status_code} for a Tampa caller. A 403 here "
        f"confirms the record exists under another practice.\n{r.text[:300]}"
    )


@pytest.mark.parametrize("path,body", [
    (f"/decisions/{PRED}/narrative", {"narrative_text": "Cross-tenant."}),
    (f"/decisions/{PRED}/attest", None),
    ("/appeals", {"pred_request_id": DENIED_PRED, "patient_name": "X",
                  "payer_id": "delta_dental"}),
])
async def test_cross_tenant_write_is_404(client, tokens, reset_events,
                                         path, body):
    role = "tampa_revenue_ops" if path == "/appeals" else "tampa_dentist"
    r = await client.post(path, json=body, headers=tokens[role])
    assert r.status_code == 404, (
        f"POST {path} -> {r.status_code} for a Tampa caller\n{r.text[:300]}"
    )


async def test_tampa_reads_are_scoped_to_tampa(client, tokens):
    """RLS, end to end. The corpus is Suwanee's; Tampa must see none of
    it — and must get an empty list rather than an error, because the
    failure mode this guards is 0 rows looking exactly like success."""
    r = await client.get("/denials", headers=tokens["tampa_revenue_ops"])
    assert r.status_code == 200
    assert r.json() == []


# ── the demo bypass ──────────────────────────────────────────────────

async def test_demo_header_can_read(client, sample):
    r = await client.get(f"/decisions/{sample['pred']}",
                         headers={"X-Demo-Mode": "true"})
    assert r.status_code == 200, r.text[:300]


async def test_demo_header_cannot_write(client):
    """Safe methods only. An anonymous header must never authorise a row."""
    r = await client.post(f"/decisions/{PRED}/feedback",
                          json={"decision_id": PRED,
                                "signal_code": "ELIGIBILITY_VERIFIED",
                                "feedback_type": "accept",
                                "submitted_by": "dentist"},
                          headers={"X-Demo-Mode": "true"})
    assert r.status_code in (401, 403), r.text[:300]


async def test_demo_header_is_suwanee_only(client, tokens):
    """A demo request for another practice's pre-D 404s exactly as a
    signed-in Suwanee user's would."""
    tampa = await client.get("/denials", headers=tokens["tampa_revenue_ops"])
    assert tampa.status_code == 200
    r = await client.get("/decisions/PRED-SIM-TB-A01",
                         headers={"X-Demo-Mode": "true"})
    assert r.status_code == 404, r.text[:300]
