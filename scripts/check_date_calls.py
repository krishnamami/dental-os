"""CI guard: every call to a date-taking endpoint states its clock.

The unit tests cover the server side of the UTC/local rule. This
covers the half they cannot reach — a component that builds the URL
itself and forgets tz_offset. It is a grep, deliberately: the failure
is textual, so the check should be too.

Run:  python scripts/check_date_calls.py ../accorddental/src
"""
from __future__ import annotations

import pathlib
import re
import sys

# Endpoints whose answer depends on which day the CALLER thinks it is.
DATE_ENDPOINTS = (
    "/decisions/queue",
    "/decisions/submitted",
    "/decisions/signed",
    "/checkin/today",
)
CALL = re.compile(r"[`\"'](/(?:decisions|checkin)/[a-z/]+)\?([^`\"']*)")


def main(root: str) -> int:
    bad: list[str] = []
    for f in pathlib.Path(root).rglob("*.ts*"):
        if "node_modules" in str(f) or f.suffix == ".map":
            continue
        for n, line in enumerate(f.read_text(encoding="utf-8").splitlines(), 1):
            for path, qs in CALL.findall(line):
                if path not in DATE_ENDPOINTS:
                    continue
                # dayParams() emits both halves; anything else must
                # spell them out.
                if "dayParams(" in line:
                    continue
                if "tz_offset" not in qs:
                    bad.append(f"{f}:{n}  {path}?{qs}")
    for b in bad:
        print("  MISSING tz_offset:", b)
    print(f"{len(bad)} call(s) send a date without a clock")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "../accorddental/src"))
