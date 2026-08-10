"""Priority 3: the date-taking endpoints, at 20:39 Eastern.

20:39 on 9 August in Atlanta is 00:39 UTC on the 10th. That one hour
and thirty-nine minutes has produced three separate bugs: the date
picker showed the wrong day's patients, appointments looked like they
expired at 8pm, and a dentist's signature vanished from SIGNED TODAY
the moment he signed. core/dates.py is the fix; tests/test_dates.py
asserts the helper is right. This file asserts the ENDPOINTS use it.

── WHY freezegun IS ONLY HALF THE TOOL ───────────────────────────────
freezegun moves Python's clock. It does not move Postgres's, and
`clinical_attestations.attested_at` and `submission_events.submitted_at`
both DEFAULT to now() — the row is stamped by the database, inside the
transaction, from a clock no test can touch.

So the two halves are driven differently, on purpose:

  the Python clock   POST /checkin stamps checkin_day with
                     local_today(tz_offset). freezegun, directly.

  the database clock the row is written by the endpoint and then moved
                     to the exact instant with an UPDATE. Contrived,
                     and the only honest way to ask "does an 00:39Z
                     timestamp come back for the local 9th" without
                     waiting until 20:39 to run the suite.

What is under test either way is day_window() reaching the SQL — the
half-open `>= start AND < end` that replaced `attested_at::date`.
"""
from __future__ import annotations

import pytest
from freezegun import freeze_time

from tests.api.conftest import OS_DB, _psql

pytestmark = pytest.mark.asyncio(loop_scope="session")

PRED = "PRED-SIM-DA-A01"

# 20:39 Eastern on 9 Aug 2026, written as the instant it actually is.
EVENING = "2026-08-10T00:39:00+00:00"
LOCAL_DAY = "2026-08-09"     # what the dentist's screen says
UTC_DAY = "2026-08-10"       # what the server would have said
EASTERN = 240                # JS getTimezoneOffset() in summer

DATE_ENDPOINTS = (
    "/decisions/queue",
    "/decisions/signed",
    "/decisions/submitted",
    "/checkin/today",
)


# ── the rule: no server-side default ─────────────────────────────────

@pytest.mark.parametrize("path", DATE_ENDPOINTS)
async def test_missing_date_is_422_not_a_guess(client, tokens, path):
    """Every one of the three bugs began with an endpoint answering for
    date.today() because the caller did not say."""
    r = await client.get(path, headers=tokens["dentist"],
                         params={"tz_offset": EASTERN})
    assert r.status_code == 422, (
        f"{path} answered for a day nobody asked about -> {r.status_code}"
    )
    assert "required" in str(r.json()["detail"]).lower()


@pytest.mark.parametrize("path", DATE_ENDPOINTS)
async def test_malformed_date_is_422(client, tokens, path):
    r = await client.get(path, headers=tokens["dentist"],
                         params={"date": "09/08/2026", "tz_offset": EASTERN})
    assert r.status_code == 422, f"{path} accepted a non-ISO date"


@pytest.mark.parametrize("path", DATE_ENDPOINTS)
async def test_absurd_offset_is_422(client, tokens, path):
    """Real offsets run -12:00 to +14:00. 9999 is a malformed request,
    not a place."""
    r = await client.get(path, headers=tokens["dentist"],
                         params={"date": LOCAL_DAY, "tz_offset": 9999})
    assert r.status_code == 422, f"{path} accepted tz_offset=9999"


# ── the signature that vanished ──────────────────────────────────────

def _stamp(table: str, column: str, when: str) -> None:
    """Move the row this test just wrote to a chosen instant."""
    _psql(OS_DB, f"UPDATE {table} SET {column} = '{when}'::timestamptz "
                 f"WHERE pred_request_id = '{PRED}'")


async def _sign(client, tokens) -> None:
    r = await client.post(f"/decisions/{PRED}/attest", headers=tokens["dentist"])
    assert r.status_code in (200, 201), r.text[:300]


async def test_signature_at_2039_eastern_belongs_to_the_local_day(
    client, tokens, reset_events
):
    """THE BUG, end to end. Under `attested_at::date = '2026-08-09'`
    this returned nothing and the dentist watched his own signature
    disappear."""
    await _sign(client, tokens)
    _stamp("clinical_attestations", "attested_at", EVENING)

    r = await client.get("/decisions/signed", headers=tokens["dentist"],
                         params={"date": LOCAL_DAY, "tz_offset": EASTERN})
    assert r.status_code == 200, r.text[:300]
    assert PRED in [x["pred_request_id"] for x in r.json()], (
        "signed at 20:39 Eastern and absent from that evening's list"
    )


async def test_the_same_signature_is_not_in_the_next_local_day(
    client, tokens, reset_events
):
    """The other half. A fix that returns the row for BOTH days is not
    a fix — it is a signature that appears twice."""
    await _sign(client, tokens)
    _stamp("clinical_attestations", "attested_at", EVENING)

    r = await client.get("/decisions/signed", headers=tokens["dentist"],
                         params={"date": UTC_DAY, "tz_offset": EASTERN})
    assert PRED not in [x["pred_request_id"] for x in r.json()]


async def test_a_utc_caller_sees_it_on_the_utc_day(
    client, tokens, reset_events
):
    """Offset 0 reproduces the old behaviour exactly — which proves the
    offset is the thing moving the row, not a coincidence of ordering."""
    await _sign(client, tokens)
    _stamp("clinical_attestations", "attested_at", EVENING)

    r = await client.get("/decisions/signed", headers=tokens["dentist"],
                         params={"date": UTC_DAY, "tz_offset": 0})
    assert PRED in [x["pred_request_id"] for x in r.json()]


async def test_midnight_belongs_to_the_day_beginning(
    client, tokens, reset_events
):
    """The window is half-open. 04:00Z is the boundary between the 9th
    and the 10th in Eastern; BETWEEN would put this row in both."""
    await _sign(client, tokens)
    _stamp("clinical_attestations", "attested_at", "2026-08-10T04:00:00+00:00")

    ninth = await client.get("/decisions/signed", headers=tokens["dentist"],
                             params={"date": LOCAL_DAY, "tz_offset": EASTERN})
    tenth = await client.get("/decisions/signed", headers=tokens["dentist"],
                             params={"date": UTC_DAY, "tz_offset": EASTERN})
    ids = lambda r: [x["pred_request_id"] for x in r.json()]  # noqa: E731
    assert PRED not in ids(ninth), "midnight leaked into the day ending"
    assert PRED in ids(tenth)


async def test_submitted_uses_the_same_window(client, tokens, reset_events):
    body = {"pred_request_id": PRED, "patient_name": "Date Test",
            "payer_id": "delta_dental", "payer_name": "Delta Dental"}
    r = await client.post(f"/decisions/{PRED}/submit", json=body,
                          headers=tokens["revenue_ops"])
    assert r.status_code in (200, 201), r.text[:300]
    _stamp("submission_events", "submitted_at", EVENING)

    on_local = await client.get("/decisions/submitted",
                                headers=tokens["revenue_ops"],
                                params={"date": LOCAL_DAY,
                                        "tz_offset": EASTERN})
    on_utc = await client.get("/decisions/submitted",
                              headers=tokens["revenue_ops"],
                              params={"date": UTC_DAY, "tz_offset": EASTERN})
    assert PRED in [x["pred_request_id"] for x in on_local.json()]
    assert PRED not in [x["pred_request_id"] for x in on_utc.json()]


# ── the Python clock: POST /checkin ──────────────────────────────────

@freeze_time(EVENING)
async def test_checkin_at_2039_is_recorded_on_the_local_day(
    client, tokens, reset_events
):
    """checkin_day used to be CURRENT_DATE, so a patient arriving at
    8:39pm Eastern was recorded as arriving tomorrow — and then did not
    appear on the check-in screen, which asks for today."""
    r = await client.post("/checkin", headers=tokens["front_desk"], json={
        "pred_request_id": PRED, "patient_name": "Evening Arrival",
        "tz_offset": EASTERN})
    assert r.status_code in (200, 201), r.text[:300]

    day = _psql(OS_DB, f"SELECT checkin_day::text FROM checkin_events "
                       f"WHERE pred_request_id = '{PRED}' "
                       f"ORDER BY checkin_day DESC LIMIT 1")
    assert day == LOCAL_DAY, (
        f"checked in at 20:39 Eastern, recorded on {day}"
    )


@freeze_time(EVENING)
async def test_a_utc_client_still_gets_the_utc_day(
    client, tokens, reset_events
):
    """Offset 0 is not a timezone the server invented for a caller that
    did not state one — it is the old behaviour, explicitly."""
    r = await client.post("/checkin", headers=tokens["front_desk"], json={
        "pred_request_id": PRED, "patient_name": "Evening Arrival",
        "tz_offset": 0})
    assert r.status_code in (200, 201), r.text[:300]

    day = _psql(OS_DB, f"SELECT checkin_day::text FROM checkin_events "
                       f"WHERE pred_request_id = '{PRED}' "
                       f"ORDER BY checkin_day DESC LIMIT 1")
    assert day == UTC_DAY
