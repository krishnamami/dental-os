"""scripts/check_date_calls.py, wired into the suite.

── WHY IT IS A TEST AND NOT A MAKE TARGET ────────────────────────────
It found three callers on its first run. A check that only fires when
somebody remembers to type its name finds nothing on the run that
matters. As a test it fails alongside everything else, in every runner,
including the pre-commit hook and CI, with no separate step to forget.

── WHAT IT COVERS THAT NOTHING ELSE CAN ──────────────────────────────
tests/api/test_api_dates.py proves the SERVER refuses a request with no
date. This proves the CLIENT sends one. Between them is the actual
rule from core/dates.py — the browser owns the clock — and neither half
can check the other: pytest has no browser, and the frontend has no
database.

── IT SKIPS RATHER THAN FAILS WHEN THE FRONTEND IS ABSENT ────────────
accorddental is a sibling checkout, not a dependency. On a machine that
has only this repo the check has nothing to read, and a red suite there
would say "your frontend is wrong" when the truth is "your frontend is
elsewhere". CI clones both, so it runs where it counts.

── AND IT CHECKS ITSELF ──────────────────────────────────────────────
A grep that stops matching passes silently, which is the worst
possible failure for a guard: green forever, checking nothing. The
second test below feeds it a known-bad file and requires it to
complain.
"""
from __future__ import annotations

import pathlib
import subprocess
import sys

import pytest

ROOT = pathlib.Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "scripts" / "check_date_calls.py"
FRONTEND = ROOT.parent / "accorddental" / "src"


def test_every_date_call_states_its_clock():
    if not FRONTEND.is_dir():
        pytest.skip(f"no frontend checkout at {FRONTEND}")

    r = subprocess.run(
        [sys.executable, str(SCRIPT), str(FRONTEND)],
        capture_output=True, text=True, cwd=ROOT,
    )
    assert r.returncode == 0, (
        "a component asks for a day without saying which clock it means.\n"
        "Use dayParams() from hooks/useDatePicker, or send tz_offset "
        "explicitly.\n\n" + r.stdout + r.stderr
    )


def test_the_check_still_catches_a_missing_offset(tmp_path):
    """The self-test. Two calls to the same endpoint, one of which
    forgot — the check must find exactly the one."""
    src = tmp_path / "Bad.tsx"
    src.write_text(
        "const good = api.get(`/decisions/queue?${dayParams(day)}`)\n"
        "const bad  = api.get(`/decisions/queue?date=${day}`)\n",
        encoding="utf-8",
    )
    r = subprocess.run(
        [sys.executable, str(SCRIPT), str(tmp_path)],
        capture_output=True, text=True, cwd=ROOT,
    )
    assert r.returncode == 1, (
        "the guard passed a call with no tz_offset — it has stopped "
        "checking:\n" + r.stdout + r.stderr
    )
    assert "1 call(s)" in r.stdout, r.stdout
    assert "Bad.tsx" in r.stdout
