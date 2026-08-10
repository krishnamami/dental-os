"""Access to the clinical document store.

── WHAT THIS IS GUARDING ─────────────────────────────────────────────
160 stored documents, and the objects carry NO tenant marker: empty
metadata, empty tag set, a bucket policy that conditions on nothing but
TLS, and a task role that can read every prefix. Tenant ownership is
knowable only from the clinical_evidence row pointing at the object.

That makes two things load-bearing, and both are asserted here:

  1. The client can never name a key. A presigned URL is a bearer
     token — it carries no identity and honours no role for as long as
     it lives — so an endpoint that signs a supplied key is a read
     primitive over the whole bucket.
  2. The row that authorises the request is the row the key comes from,
     read under RLS with both the pre-D and the evidence id in the
     WHERE clause.

── THE URL IS NOT FETCHED ────────────────────────────────────────────
These tests assert that a URL is minted, signed, and scoped. They do
not follow it: the suite is offline by design and the fixtures do not
depend on AWS. Whether the task role may actually GET the object is an
IAM question, verified against the deployment rather than here — and
noted in core/documents.py, because generate_presigned_url succeeds
whether or not the permission exists.
"""
from __future__ import annotations

import pathlib
import re
import urllib.parse

import pytest

pytestmark = pytest.mark.asyncio(loop_scope="session")

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent

# A Suwanee pre-D with real PDFs behind it.
PRED = "PRED-SIM-DA-A01"


async def a_document(client, tokens, pred: str = PRED) -> dict:
    """One evidence row on `pred` that has a file behind it."""
    r = await client.get(f"/decisions/{pred}/appeal",
                         headers=tokens["revenue_ops"])
    if r.status_code != 200:
        pytest.skip(f"{pred} has no appeal packet to read evidence from")
    docs = [e for e in r.json()["evidence_list"] if e["has_document"]]
    assert docs, f"{pred} has no stored documents in the fixture"
    return docs[0]


# ── the shape of the thing ───────────────────────────────────────────

async def test_the_evidence_list_names_an_id_and_never_a_key(client, tokens):
    """The response must carry no bucket path at all.

    EvidenceTimeline used to print s3_key on screen as the caption
    under "PA X-ray" — an internal object path shown to a clinician
    under a heading promising a document nobody could open.
    """
    r = await client.get(f"/decisions/{PRED}/appeal",
                         headers=tokens["revenue_ops"])
    assert r.status_code == 200, r.text[:300]
    assert "s3_key" not in r.text, "a bucket path is in the response body"
    assert ".pdf" not in r.text, "an object filename is in the response body"

    for e in r.json()["evidence_list"]:
        assert "evidence_id" in e and "has_document" in e


async def test_an_allowed_role_gets_a_signed_url(client, tokens):
    doc = await a_document(client, tokens)
    r = await client.get(
        f"/decisions/{PRED}/documents/{doc['evidence_id']}",
        headers=tokens["revenue_ops"],
    )
    assert r.status_code == 200, r.text[:400]
    body = r.json()

    parts = urllib.parse.urlparse(body["url"])
    q = urllib.parse.parse_qs(parts.query)
    assert parts.scheme == "https", "an unsigned or insecure URL"
    assert "dental-documents" in parts.netloc or "dental-documents" in parts.path
    # SigV4. The older algorithm is rejected outright by the bucket, and
    # the failure would surface as a 403 on the link rather than here.
    assert q.get("X-Amz-Algorithm") == ["AWS4-HMAC-SHA256"], q
    assert q.get("X-Amz-Signature"), "not actually signed"


async def test_the_url_expires_in_minutes_not_hours(client, tokens):
    """Five minutes. The object has no other protection, so after the
    fact the expiry IS the access control."""
    doc = await a_document(client, tokens)
    body = (await client.get(
        f"/decisions/{PRED}/documents/{doc['evidence_id']}",
        headers=tokens["dentist"])).json()

    assert body["expires_in"] == 300
    q = urllib.parse.parse_qs(urllib.parse.urlparse(body["url"]).query)
    assert q["X-Amz-Expires"] == ["300"], q
    assert int(q["X-Amz-Expires"][0]) <= 900, "an hours-long bearer token"


async def test_the_filename_travels_for_the_browser(client, tokens):
    doc = await a_document(client, tokens)
    body = (await client.get(
        f"/decisions/{PRED}/documents/{doc['evidence_id']}",
        headers=tokens["dentist"])).json()
    assert body["filename"].endswith(".pdf")
    assert "/" not in body["filename"], "the key leaked through the filename"


# ── role ─────────────────────────────────────────────────────────────

@pytest.mark.parametrize("role", ["dentist", "revenue_ops", "accord_admin"])
async def test_roles_that_read_the_chart_are_allowed(client, tokens, role):
    doc = await a_document(client, tokens)
    r = await client.get(f"/decisions/{PRED}/documents/{doc['evidence_id']}",
                         headers=tokens[role])
    assert r.status_code == 200, f"{role} -> {r.status_code}\n{r.text[:300]}"


@pytest.mark.parametrize("role", ["front_desk", "tx_coord", "dso_owner"])
async def test_every_other_role_is_refused(client, tokens, role):
    """⚠ dso_owner IS IN THIS LIST ON PURPOSE. It is the same line drawn
    on per-pre-D access: an owner may know Tampa denies at 20% and may
    not read a Tampa patient's radiograph. Ownership widened the
    portfolio and nothing else."""
    doc = await a_document(client, tokens)
    r = await client.get(f"/decisions/{PRED}/documents/{doc['evidence_id']}",
                         headers=tokens[role])
    assert r.status_code == 403, f"{role} -> {r.status_code}"


async def test_no_token_is_401(client, tokens):
    doc = await a_document(client, tokens)
    r = await client.get(f"/decisions/{PRED}/documents/{doc['evidence_id']}")
    assert r.status_code == 401


async def test_the_demo_header_cannot_open_a_document(client, tokens):
    doc = await a_document(client, tokens)
    r = await client.get(f"/decisions/{PRED}/documents/{doc['evidence_id']}",
                         headers={"X-Demo-Mode": "true"})
    assert r.status_code in (401, 403), r.text[:300]


# ── tenant ───────────────────────────────────────────────────────────

async def test_a_cross_tenant_request_is_404_not_403(client, tokens):
    """Tampa's dentist asking for a Suwanee document is told it does
    not exist. A 403 would confirm the id, which turns the endpoint
    into an oracle over a bucket whose keys are formulaic."""
    doc = await a_document(client, tokens)
    r = await client.get(f"/decisions/{PRED}/documents/{doc['evidence_id']}",
                         headers=tokens["tampa_dentist"])
    assert r.status_code == 404, f"-> {r.status_code}\n{r.text[:300]}"


async def test_an_evidence_id_from_another_tenant_is_refused(client, tokens):
    """⚠ THE CHECK THE PRE-D GUARD DOES NOT MAKE.

    A Suwanee caller, on a Suwanee pre-D they legitimately own, naming
    a Tampa evidence_id. assert_tenant_allowed passes — the pre-D is
    theirs. Only the row lookup catches it, because app.tenant_id is
    bound and the pre-D is in the WHERE clause.
    """
    from tests.api.conftest import SIM_DB, _psql

    foreign = _psql(
        SIM_DB,
        "SELECT evidence_id FROM clinical_evidence "
        "WHERE tenant_id <> 'suwanee_smiles' AND s3_key IS NOT NULL LIMIT 1")
    assert foreign, "the fixture has no other tenant's document to try"

    r = await client.get(f"/decisions/{PRED}/documents/{foreign}",
                         headers=tokens["dentist"])
    assert r.status_code == 404, (
        f"a Tampa evidence_id resolved through a Suwanee pre-D "
        f"-> {r.status_code}\n{r.text[:300]}"
    )


async def test_an_evidence_id_from_another_pred_in_the_same_tenant_is_refused(
    client, tokens
):
    """Same practice, wrong case. RLS cannot catch this one — both rows
    are Suwanee's — so it rests entirely on pred_request_id being in
    the WHERE clause."""
    from tests.api.conftest import SIM_DB, _psql

    other = _psql(
        SIM_DB,
        "SELECT evidence_id FROM clinical_evidence "
        "WHERE tenant_id = 'suwanee_smiles' AND s3_key IS NOT NULL "
        f"AND pred_request_id <> '{PRED}' LIMIT 1")
    assert other

    r = await client.get(f"/decisions/{PRED}/documents/{other}",
                         headers=tokens["dentist"])
    assert r.status_code == 404, f"-> {r.status_code}\n{r.text[:300]}"


async def test_an_invented_evidence_id_is_404(client, tokens):
    r = await client.get(f"/decisions/{PRED}/documents/does-not-exist",
                         headers=tokens["dentist"])
    assert r.status_code == 404


async def test_a_record_with_no_file_says_so(client, tokens):
    """111 of 271 evidence rows are structured payloads, not documents.
    404 would say "no such record", which is untrue and sends someone
    looking for a bug."""
    r = await client.get(f"/decisions/{PRED}/appeal",
                         headers=tokens["revenue_ops"])
    payloads = [e for e in r.json()["evidence_list"]
                if not e["has_document"] and e["evidence_id"]]
    if not payloads:
        pytest.skip(f"{PRED} has no payload-only evidence rows")

    got = await client.get(
        f"/decisions/{PRED}/documents/{payloads[0]['evidence_id']}",
        headers=tokens["dentist"])
    assert got.status_code == 409, got.text[:300]
    assert "not a stored document" in got.json()["detail"]


# ── the structural guarantee ─────────────────────────────────────────

def test_no_endpoint_anywhere_accepts_an_s3_key_from_a_client():
    """⚠ THE ONE THAT MATTERS MOST, AND IT IS A GREP.

    Every other test here checks the endpoint that exists. This checks
    that nobody adds a different one. An s3_key arriving from a client
    — as a query parameter, a path parameter or a body field — is a
    read primitive over 427 objects under four guessable prefixes, and
    the presigned URL it returns answers to anyone holding it.

    A grep, deliberately: the failure is textual and a type checker
    would not see it.
    """
    offenders: list[str] = []

    # Query and path parameters on any route handler.
    routes = (ROOT / "api" / "routes.py").read_text(encoding="utf-8")
    for n, line in enumerate(routes.splitlines(), 1):
        if re.search(r"^\s*s3_key\s*:", line):
            offenders.append(f"api/routes.py:{n}  handler parameter: {line.strip()}")
        if re.search(r'Query\(.*\).*s3_key|s3_key.*=\s*Query\(', line):
            offenders.append(f"api/routes.py:{n}  query parameter: {line.strip()}")
        if re.search(r'\{s3_key\}|\{key\}', line):
            offenders.append(f"api/routes.py:{n}  path parameter: {line.strip()}")

    # Request bodies.
    schemas = (ROOT / "api" / "schemas.py").read_text(encoding="utf-8")
    cls = None
    for n, line in enumerate(schemas.splitlines(), 1):
        m = re.match(r"class (\w+)\(BaseModel\):", line)
        if m:
            cls = m.group(1)
        if re.match(r"\s+s3_key\s*:", line) and cls and (
            cls.endswith("Request") or cls.endswith("In")
        ):
            offenders.append(f"api/schemas.py:{n}  request body {cls}: {line.strip()}")

    assert not offenders, (
        "an endpoint takes a bucket key from the caller:\n  "
        + "\n  ".join(offenders)
        + "\n\nThe caller names a RECORD; the server reads the key out of "
          "the row it authorised. See core/documents.py."
    )


def test_the_ttl_stays_short():
    """A guard on the constant itself, so raising it is a deliberate
    edit against a stated reason rather than a one-character change."""
    from core.documents import URL_TTL_SECONDS

    assert 60 <= URL_TTL_SECONDS <= 900, (
        f"{URL_TTL_SECONDS}s. The objects carry no tenant marker and no "
        f"second barrier, so this expiry is the access control once the "
        f"URL exists. Minutes, not hours."
    )
