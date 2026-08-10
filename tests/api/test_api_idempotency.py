"""Priority 4: what happens the second time someone clicks.

Every one of these is a double-click, a retried request, or two people
on the same case — none of which is exotic. The question each test asks
is the same: does the second write return something sensible, and how
many rows are there afterwards.

The row count is the assertion that matters. A 200 proves the endpoint
did not crash; only `SELECT count(*)` proves it did not write twice.

── THE GUARDS, AS THEY ACTUALLY ARE ──────────────────────────────────
    /attest              409. One signature per pre-D, full stop.
    /submit              upsert on (tenant, pred). Re-submitting is a
                         correction, not a second filing.
    /submit attested     409 if already signed — same guard as /attest,
                         because it is the same function.
    /appeals             DO NOTHING, then return the appeal already on
                         file. A second click is not an error.
    /handoff             upsert per (to_role, kind) — migration 008.
    /handoff/read        no-op. Second call marks 0.
    /checkin             upsert per (pred, checkin_day).
    /narrative           upsert. Latest wins.
    /justification       upsert per signal_code.
    /document-requests   NO GUARD — appends. Asserted below so that it
                         is a decision on the record rather than
                         something nobody checked.
"""
from __future__ import annotations

import pytest
from freezegun import freeze_time

from tests.api.conftest import OS_DB, _psql

pytestmark = pytest.mark.asyncio(loop_scope="session")

PRED = "PRED-SIM-DA-A01"
DENIED_PRED = "PRED-SIM-DA-B04"


def count(table: str, pred: str = PRED, extra: str = "") -> int:
    return int(_psql(OS_DB, f"SELECT count(*) FROM {table} "
                            f"WHERE pred_request_id = '{pred}' {extra}"))


async def test_a_pred_carries_one_signature(client, tokens, reset_events):
    """The second signature is refused, and does not land."""
    first = await client.post(f"/decisions/{PRED}/attest",
                              headers=tokens["dentist"])
    assert first.status_code in (200, 201), first.text[:300]

    second = await client.post(f"/decisions/{PRED}/attest",
                               headers=tokens["dentist"])
    assert second.status_code == 409, second.text[:300]
    assert "already signed" in second.json()["detail"]
    assert count("clinical_attestations") == 1


async def test_submit_with_attested_hits_the_same_guard(
    client, tokens, reset_events
):
    """/submit and /attest share _write_attestation. If they did not,
    signing through one and then the other would produce two rows on a
    record that is supposed to carry exactly one."""
    await client.post(f"/decisions/{PRED}/attest", headers=tokens["dentist"])
    r = await client.post(f"/decisions/{PRED}/submit", headers=tokens["dentist"],
                          json={"pred_request_id": PRED,
                                "patient_name": "Idem Test",
                                "payer_id": "delta_dental",
                                "payer_name": "Delta Dental",
                                "attested": True})
    assert r.status_code == 409, r.text[:300]
    assert count("clinical_attestations") == 1


async def test_resubmitting_corrects_rather_than_duplicates(
    client, tokens, reset_events
):
    body = {"pred_request_id": PRED, "patient_name": "Idem Test",
            "payer_id": "delta_dental", "payer_name": "Delta Dental",
            "notes": "first"}
    a = await client.post(f"/decisions/{PRED}/submit", json=body,
                          headers=tokens["revenue_ops"])
    b = await client.post(f"/decisions/{PRED}/submit",
                          json={**body, "notes": "second"},
                          headers=tokens["revenue_ops"])
    assert a.status_code in (200, 201) and b.status_code in (200, 201), b.text[:300]
    assert count("submission_events") == 1


async def test_filing_an_appeal_twice_returns_the_first_one(
    client, tokens, reset_events
):
    """DO NOTHING returns no row, and reading appeal_id off it was a
    500 the second time anyone clicked. The endpoint now answers with
    the appeal already on file."""
    _psql(OS_DB, f"DELETE FROM appeal_events "
                 f"WHERE pred_request_id = '{DENIED_PRED}'")
    body = {"pred_request_id": DENIED_PRED, "patient_name": "Idem Test",
            "payer_id": "delta_dental", "appeal_type": "standard"}

    a = await client.post("/appeals", json=body, headers=tokens["revenue_ops"])
    b = await client.post("/appeals", json=body, headers=tokens["revenue_ops"])
    assert a.status_code in (200, 201), a.text[:300]
    assert b.status_code in (200, 201, 409), b.text[:300]
    assert count("appeal_events", DENIED_PRED) == 1
    if b.status_code != 409:
        assert b.json()["appeal_id"] == a.json()["appeal_id"], (
            "the second filing invented a new appeal id"
        )


async def test_handoff_is_one_per_role_and_kind(client, tokens, reset_events):
    """Migration 008. Two notes to the dentist replace each other; a
    note and a consultation record are different things and coexist."""
    _psql(OS_DB, f"DELETE FROM clinical_handoffs "
                 f"WHERE pred_request_id = '{PRED}'")

    for note in ("first note", "second note"):
        r = await client.post(f"/decisions/{PRED}/handoff",
                              headers=tokens["tx_coord"],
                              json={"to_role": "dentist", "note": note,
                                    "kind": "note"})
        assert r.status_code in (200, 201), r.text[:300]
    assert count("clinical_handoffs") == 1
    assert r.json()["replaced_existing"] is True

    other = await client.post(f"/decisions/{PRED}/handoff",
                              headers=tokens["tx_coord"],
                              json={"to_role": "dentist",
                                    "note": "consult done",
                                    # The endpoint admits exactly two
                                    # kinds; a third is a 422.
                                    "kind": "consultation_complete"})
    assert other.status_code in (200, 201), other.text[:300]
    assert count("clinical_handoffs") == 2, "kind is part of the key"


async def test_marking_read_twice_is_a_no_op(client, tokens, reset_events):
    """read_at is set by an explicit user action. The second call must
    not move the timestamp — the bug this replaced was an effect on
    mount clearing the note nobody had opened."""
    _psql(OS_DB, f"DELETE FROM clinical_handoffs "
                 f"WHERE pred_request_id = '{PRED}'")
    await client.post(f"/decisions/{PRED}/handoff", headers=tokens["tx_coord"],
                      json={"to_role": "dentist", "note": "read me",
                            "kind": "note"})

    first = await client.post(f"/decisions/{PRED}/handoff/read",
                              headers=tokens["dentist"])
    assert first.status_code == 200 and first.json()["marked"] == 1, first.text
    stamp = _psql(OS_DB, f"SELECT read_at::text FROM clinical_handoffs "
                         f"WHERE pred_request_id = '{PRED}'")

    second = await client.post(f"/decisions/{PRED}/handoff/read",
                               headers=tokens["dentist"])
    assert second.status_code == 200
    assert second.json()["marked"] == 0, "it re-marked an already-read note"
    assert _psql(OS_DB, f"SELECT read_at::text FROM clinical_handoffs "
                        f"WHERE pred_request_id = '{PRED}'") == stamp


async def test_marking_read_is_scoped_to_the_callers_role(
    client, tokens, reset_events
):
    """Reading the dentist's note off the screen must not clear one
    addressed to the front desk."""
    _psql(OS_DB, f"DELETE FROM clinical_handoffs "
                 f"WHERE pred_request_id = '{PRED}'")
    for role in ("dentist", "front_desk"):
        await client.post(f"/decisions/{PRED}/handoff",
                          headers=tokens["tx_coord"],
                          json={"to_role": role, "note": f"for {role}",
                                "kind": "note"})

    await client.post(f"/decisions/{PRED}/handoff/read",
                      headers=tokens["dentist"])
    unread = count("clinical_handoffs", extra="AND read_at IS NULL")
    assert unread == 1, "the dentist cleared the front desk's note"


@freeze_time("2026-08-10T00:39:00+00:00")
async def test_checking_in_twice_on_one_day_is_one_row(
    client, tokens, reset_events
):
    """Scoped to the DAY, and to a day the fixture does not already
    hold — the key is (tenant, pred, checkin_day), so a bare count over
    the pre-D would be measuring the fixture, not the upsert. The clock
    is frozen for the same reason: which day the row lands on must not
    depend on when the suite runs."""
    _psql(OS_DB, f"DELETE FROM checkin_events "
                 f"WHERE pred_request_id = '{PRED}'")
    body = {"pred_request_id": PRED, "patient_name": "Idem Test",
            "tz_offset": 240}
    for _ in range(2):
        r = await client.post("/checkin", json=body,
                              headers=tokens["front_desk"])
        assert r.status_code in (200, 201), r.text[:300]
    assert count("checkin_events") == 1
    assert count("checkin_events", extra="AND checkin_day = '2026-08-09'") == 1


async def test_saving_a_narrative_twice_keeps_the_latest(
    client, tokens, reset_events
):
    for text in ("first draft", "second draft"):
        r = await client.post(f"/decisions/{PRED}/narrative",
                              headers=tokens["dentist"],
                              json={"narrative_text": text,
                                    "source": "edited"})
        assert r.status_code in (200, 201), r.text[:300]
    assert count("clinical_narratives") == 1
    saved = _psql(OS_DB, f"SELECT narrative_text FROM clinical_narratives "
                         f"WHERE pred_request_id = '{PRED}'")
    assert saved == "second draft"


async def test_justification_is_one_per_signal(client, tokens, reset_events):
    for text in ("because", "because, revised"):
        r = await client.post(f"/decisions/{PRED}/justification",
                              headers=tokens["dentist"],
                              json={"signal_code": "DOC_NARRATIVE_MISSING",
                                    "justification": text})
        assert r.status_code in (200, 201), r.text[:300]
    assert count("clinical_justifications") == 1

    other = await client.post(f"/decisions/{PRED}/justification",
                              headers=tokens["dentist"],
                              json={"signal_code": "COVERAGE_PRED_REQUIRED",
                                    "justification": "different signal"})
    assert other.status_code in (200, 201), other.text[:300]
    assert count("clinical_justifications") == 2


async def test_document_requests_append(client, tokens, reset_events):
    """⚠ NO GUARD, DELIBERATELY ASSERTED. Chasing the same document
    twice is a real thing a practice does — the second request is a
    second chase, not a duplicate. If that ever changes, this test is
    the thing that will say so.
    """
    body = {"requests": [{"document_type": "radiograph"}],
            "requested_from": "front_desk"}
    for _ in range(2):
        r = await client.post(f"/decisions/{PRED}/document-requests",
                              json=body, headers=tokens["dentist"])
        assert r.status_code in (200, 201), r.text[:300]
    assert count("document_requests") == 2
