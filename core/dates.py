"""What "today" means. One answer, in one place.

⚠ THIS IS THE THIRD TIME. The date picker showed the wrong day's
patients. Appointments appeared to expire at 8pm Eastern. Then a
dentist's signature vanished from SIGNED TODAY the moment he signed
after 8pm, and the case he had just signed reappeared in his queue.
Same root cause every time, patched locally every time.

── THE RULE ──────────────────────────────────────────────────────────

1. The CLIENT decides what day it is. It has the only clock that knows
   what day the person looking at the screen is living in.

2. NO ENDPOINT DEFAULTS TO date.today(). A server-side default is a
   silent guess in UTC, and it is wrong for four hours out of every
   twenty-four for a US Eastern practice. A missing date is now a 422:
   loud, at the caller, at the moment they forgot.

3. A DATE column (appointments.appointment_date, checkin_events.
   checkin_day) is a calendar day and compares to a date directly.
   A TIMESTAMPTZ column (submitted_at, attested_at, filed_at) is an
   INSTANT, and `stamp::date` casts it in the SESSION's timezone —
   UTC on this server. Comparing that to a browser's local date is the
   bug. Use day_window() and compare against the half-open range.

4. The client sends its UTC offset with the date. A date string alone
   cannot identify an instant range; "2026-08-09" is a different span
   of time in Atlanta and in Dallas, and this product has practices in
   both.

── WHY NOT A PRACTICE TIMEZONE COLUMN ────────────────────────────────

Because there isn't one, and inventing "all practices are Eastern"
would be wrong for Dallas today rather than in the abstract. The
browser's offset is information we already have and did not use. When
a tenants.timezone column exists, day_window should read it and the
client offset becomes a fallback — the call sites do not change.
"""
from __future__ import annotations

from datetime import date, datetime, timedelta, timezone

from fastapi import HTTPException

# A sane bound. Real offsets run -12:00 to +14:00; anything outside is a
# malformed request rather than a place.
_MAX_OFFSET_MIN = 14 * 60
_MIN_OFFSET_MIN = -12 * 60


def require_date(date_param: str | None, *, field: str = "date") -> date:
    """Parse a required YYYY-MM-DD. No default, deliberately.

    The absent case used to fall through to date.today(). That is the
    behaviour this module exists to remove: the caller who forgot gets
    an error naming what to send, not a plausible answer from the
    wrong clock.
    """
    if not date_param:
        raise HTTPException(
            422,
            f"{field} is required as YYYY-MM-DD. The server does not "
            f"assume a day — it runs in UTC and would answer for the "
            f"wrong one after early evening in the Americas.",
        )
    try:
        return date.fromisoformat(date_param)
    except ValueError:
        raise HTTPException(422, f"{field} must be YYYY-MM-DD") from None


def parse_offset(tz_offset: int | None) -> int:
    """Minutes to ADD to local time to get UTC — JS getTimezoneOffset().

    US Eastern in summer is 240. Defaults to 0, which reproduces the
    old UTC behaviour exactly rather than inventing a timezone for a
    caller that did not state one.
    """
    if tz_offset is None:
        return 0
    if not (_MIN_OFFSET_MIN <= tz_offset <= _MAX_OFFSET_MIN):
        raise HTTPException(
            422,
            f"tz_offset must be between {_MIN_OFFSET_MIN} and "
            f"{_MAX_OFFSET_MIN} minutes",
        )
    return tz_offset


def day_window(
    on: date, tz_offset: int | None = None
) -> tuple[datetime, datetime]:
    """The UTC instants bounding one LOCAL calendar day.

    Half-open [start, end): a timestamp at exactly midnight belongs to
    the day beginning, not the one ending, and BETWEEN would count it
    twice across two queries.

        day_window(2026-08-09, 240)
        -> 2026-08-09 04:00Z .. 2026-08-10 04:00Z

    Compare with `stamp >= $start AND stamp < $end`, never with
    `stamp::date = $day` — the cast happens in the server's timezone
    and throws the caller's away.
    """
    minutes = parse_offset(tz_offset)
    start_local = datetime(on.year, on.month, on.day, tzinfo=timezone.utc)
    start = start_local + timedelta(minutes=minutes)
    return start, start + timedelta(days=1)


def local_today(tz_offset: int | None = None) -> date:
    """The calendar day it is right now at the given offset.

    For writes that need a day and have no client-supplied one —
    checkin_events.checkin_day, which used CURRENT_DATE and therefore
    rolled over at 8pm Eastern.
    """
    minutes = parse_offset(tz_offset)
    return (datetime.now(timezone.utc) - timedelta(minutes=minutes)).date()
