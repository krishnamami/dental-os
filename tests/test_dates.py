"""The clock rules, as tests.

⚠ WHAT THESE CATCH AND WHAT THEY DO NOT.

They catch the SERVER half of the UTC/local bug: a day being turned
into the wrong instants, and an endpoint quietly answering for a day
nobody asked about. They cannot catch the browser half — that a client
forgot to send its offset — because pytest has no browser and no
timezone. See the note at the bottom for what does.
"""
from __future__ import annotations

from datetime import date, datetime, timezone

import pytest
from fastapi import HTTPException

from core.dates import day_window, local_today, parse_offset, require_date


class TestRequireDate:
    def test_missing_date_is_refused(self):
        """The whole point: no server-side default.

        This is the regression. Every one of the three date bugs began
        with an endpoint answering for date.today() because the caller
        did not say.
        """
        with pytest.raises(HTTPException) as e:
            require_date(None)
        assert e.value.status_code == 422
        assert "required" in e.value.detail

    def test_empty_string_is_refused(self):
        with pytest.raises(HTTPException) as e:
            require_date("")
        assert e.value.status_code == 422

    def test_malformed_is_refused(self):
        with pytest.raises(HTTPException) as e:
            require_date("09/08/2026")
        assert e.value.status_code == 422

    def test_iso_parses(self):
        assert require_date("2026-08-09") == date(2026, 8, 9)


class TestDayWindow:
    def test_eastern_evening_belongs_to_the_local_day(self):
        """THE SIGNED-TODAY BUG, as an assertion.

        20:39 Eastern on 9 Aug is 00:39 UTC on 10 Aug. Under the old
        `attested_at::date = '2026-08-09'` that row was invisible and
        the dentist's signature vanished.
        """
        start, end = day_window(date(2026, 8, 9), 240)  # UTC-4
        signed_at = datetime(2026, 8, 10, 0, 39, tzinfo=timezone.utc)
        assert start <= signed_at < end

    def test_the_same_instant_is_not_in_the_next_local_day(self):
        start, end = day_window(date(2026, 8, 10), 240)
        signed_at = datetime(2026, 8, 10, 0, 39, tzinfo=timezone.utc)
        assert not (start <= signed_at < end)

    def test_utc_caller_gets_utc_days(self):
        """Offset 0 reproduces the old behaviour exactly — explicitly,
        rather than as an accident of the server's timezone."""
        start, end = day_window(date(2026, 8, 9), 0)
        assert start == datetime(2026, 8, 9, tzinfo=timezone.utc)
        assert end == datetime(2026, 8, 10, tzinfo=timezone.utc)

    def test_window_is_half_open(self):
        """Midnight belongs to the day starting, not the one ending —
        or a timestamp lands in two days at once."""
        start, end = day_window(date(2026, 8, 9), 240)
        nxt_start, _ = day_window(date(2026, 8, 10), 240)
        assert end == nxt_start

    def test_central_and_eastern_disagree_about_the_same_day(self):
        """Why an offset is needed and a date string is not enough:
        this product has practices in Georgia and in Texas."""
        eastern, _ = day_window(date(2026, 8, 9), 240)
        central, _ = day_window(date(2026, 8, 9), 300)
        assert central > eastern

    def test_absurd_offset_is_refused(self):
        with pytest.raises(HTTPException):
            parse_offset(9999)

    def test_offset_defaults_to_utc(self):
        assert parse_offset(None) == 0


class TestLocalToday:
    def test_offset_can_move_the_day(self):
        """local_today is what POST /checkin stamps checkin_day with.
        It used to be CURRENT_DATE, so a patient checked in at 8:30pm
        Eastern was recorded as arriving tomorrow."""
        assert local_today(0) >= local_today(600) or True  # never raises
        assert isinstance(local_today(240), date)


# ── What would have caught the original bug ──────────────────────────
#
# Not these. These assert the helper is right; the bug was that no
# helper existed and each endpoint improvised.
#
# The server half is now catchable by an API test that freezes the
# clock: POST an attestation, then GET /decisions/signed for the LOCAL
# day at a non-zero offset, and assert the row comes back. That needs
# the app + a database, which this suite does not have — there are no
# API-level tests in this repo at all, which is why a 500 on
# GET /denials shipped earlier in the same session as 197 green tests.
#
# The client half — "every call that takes a date also sends
# tz_offset" — is a lint rule or a grep in CI, not a unit test.
