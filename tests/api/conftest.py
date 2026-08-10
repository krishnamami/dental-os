"""The API suite's harness: a real app, over a real Postgres, offline.

── WHY THIS EXISTS ───────────────────────────────────────────────────
There were 197 tests in this repo and every one of them was a unit
test. A `KeyError: 'predicted_viable'` — a 500 on GET /denials, on the
first line of the response body — shipped in a session that reported
them all green, because nothing in the suite had ever called an
endpoint. These tests boot the app and make HTTP requests. They are
slower and they catch a different class of thing.

── WHAT IT RUNS AGAINST ──────────────────────────────────────────────
The `dental-postgres` container that already runs on this machine for
local development, port 5434. Two databases are dropped and rebuilt
from tests/fixtures/*.sql at the start of each session:

    dental_test      the simulator corpus, whole
    dental_os_test   dental-os's schema, plus bundles for 7 pre-Ds

The fixtures are COMMITTED. A test run must not need AWS credentials,
a VPN, or production to be in a particular state. Regenerate them with
scripts/refresh_test_fixture.py when the corpus moves.

── THE APP CONNECTS AS dental_app, NOT AS THE SUPERUSER ──────────────
Deliberately, and it is the single most important line in this file.
Postgres skips RLS entirely for a superuser, so a suite that connected
as `dental` would pass every cross-tenant test while proving nothing —
the exact failure mode CONTEXT.md warns about, where a missing tenant
returns rows instead of an error. dental_app is an ordinary role, so
the policies apply to it here as they do on RDS.

── users IS NOT IN THE FIXTURE ───────────────────────────────────────
Dumping it would commit production auth rows and their bcrypt hashes.
This file creates its own accounts, at bcrypt cost 4 rather than the
default 12 — the suite logs in eight times and 12 rounds would spend
about a second of every run proving bcrypt still works.
"""
from __future__ import annotations

import os
import pathlib
import subprocess

import bcrypt
import pytest
import pytest_asyncio

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
FIXTURES = ROOT / "tests" / "fixtures"

CONTAINER = os.environ.get("PG_CONTAINER", "dental-postgres")
SUPERUSER = "dental"          # the container's POSTGRES_USER
APP_ROLE = "dental_app"       # what the app connects as — see above
APP_PW = "dental_dev"
HOST_PORT = os.environ.get("PG_TEST_PORT", "5434")

SIM_DB = "dental_test"
OS_DB = "dental_os_test"

PASSWORD = "demo2026"

# Prefix for the pristine copies reset_events rewinds to.
_SNAP = "_fixture_"

# Suwanee is the tenant with the corpus. Tampa exists so cross-tenant
# refusal is testable with a real second identity rather than a forged
# claim — a hand-made token would test the helper, not the wiring.
TEST_USERS: tuple[tuple[str, str, str, str | None], ...] = (
    ("sarah@suwaneesmiles.com", "Sarah R.", "front_desk", "suwanee_smiles"),
    ("tc@suwaneesmiles.com", "Jennifer M.", "tx_coord", "suwanee_smiles"),
    ("billing@suwaneesmiles.com", "Kim B.", "revenue_ops", "suwanee_smiles"),
    ("drchinta@suwaneesmiles.com", "Dr. Chinta", "dentist", "suwanee_smiles"),
    ("drshyam@suwaneesmiles.com", "Dr. Shyam", "dso_owner", "suwanee_smiles"),
    ("admin@accorddental.io", "Accord Admin", "accord_admin", None),
    ("billing@tampabaysmiles.com", "Kim T.", "revenue_ops", "tampa_smiles"),
    ("drrodriguez@tampabaysmiles.com", "Dr. Rodriguez", "dentist",
     "tampa_smiles"),
    # A SECOND owner, at the other practice. /portfolio/summary narrows
    # to the caller's tenant, and a narrowing that returns the right
    # answer by accident of row order passes with only one owner to try
    # it with. Mirrors production, where Dr. Shyam is two unrelated
    # rows — one per practice, nothing linking them.
    ("drshyam@tampabaysmiles.com", "Dr. Shyam", "dso_owner", "tampa_smiles"),
)

# Everything a test can write, in FK order — parents first, because
# reset_events reinserts along this list.
#
# ⚠ THESE ARE NOT EMPTY IN THE FIXTURE. clinical_handoffs has 2 rows,
# provider_feedback 11, checkin_events 5, and the submitted → denied →
# appealed chain 3 each. Read tests need them. So reset_events restores
# a snapshot rather than truncating: a write test that clears the table
# it shares with a read test turns "did this endpoint work" into "which
# test ran first".
MUTABLE_TABLES = (
    "provider_feedback",
    "clinical_narratives",
    "clinical_justifications",
    "clinical_attestations",
    "clinical_handoffs",
    "document_requests",
    "checkin_events",
    "submission_events",
    "denial_events",
    "appeal_events",
    "appeal_packets",
)


# ─────────────────────────────────────────────────────────────────────
# ⚠ ENV BEFORE IMPORT. core.db.connection reads DATABASE_URL at call
# time but calls load_dotenv() at import time, and .env points at RDS.
# Assigning here wins because load_dotenv does not override a variable
# that is already set — but only if this module is imported first, which
# is why the assignment is at module scope in a conftest and not inside
# a fixture.
# ─────────────────────────────────────────────────────────────────────
def _dsn(db: str) -> str:
    return f"postgresql://{APP_ROLE}:{APP_PW}@localhost:{HOST_PORT}/{db}"


os.environ["DATABASE_URL"] = _dsn(SIM_DB)
os.environ["DENTAL_OS_DATABASE_URL"] = _dsn(OS_DB)
# ⚠ THE SIMULATOR DATABASE, NOT dental_os. The only caller is
# DSOPortfolioManager.aggregate_all_tenants, which reads `tenants` and
# `pred_requests` — simulator tables. connection.get_admin_pool()
# falls back to DATABASE_URL when this is unset, and .env leaves it
# unset, so pointing it at dental_os here would have been the harness
# inventing a wiring production does not have.
os.environ["DENTAL_ADMIN_DATABASE_URL"] = (
    f"postgresql://{SUPERUSER}:{APP_PW}@localhost:{HOST_PORT}/{SIM_DB}"
)
os.environ["API_PREFIX"] = ""
os.environ.setdefault("JWT_SECRET", "test-secret-not-a-real-one")


def _psql(db: str, sql: str, *, quiet: bool = False) -> str:
    """Run SQL in the container as the superuser."""
    r = subprocess.run(
        ["docker", "exec", "-i", CONTAINER, "psql", "-v", "ON_ERROR_STOP=1",
         "-U", SUPERUSER, "-d", db, "-tAc", sql],
        capture_output=True, text=True,
    )
    if r.returncode and not quiet:
        raise RuntimeError(f"psql {db}: {r.stderr.strip()[:800]}\n  {sql[:200]}")
    return r.stdout.strip()


def _restore(db: str, path: pathlib.Path) -> None:
    """Pipe a dump into the container.

    ON_ERROR_STOP is OFF here on purpose: a dump taken with --no-owner
    still carries a handful of statements that only an RDS instance can
    satisfy (rds_superuser grants, extensions this image lacks). Those
    are noise. The check that matters is the row count afterwards, not
    a clean exit — so errors are counted and summarised, and a restore
    that produced no data fails loudly a few lines below.
    """
    with path.open("rb") as fh:
        r = subprocess.run(
            ["docker", "exec", "-i", CONTAINER, "psql", "-q",
             "-U", SUPERUSER, "-d", db],
            stdin=fh, capture_output=True, text=True,
        )
    errs = [ln for ln in r.stderr.splitlines() if "ERROR" in ln]
    if errs:
        seen: dict[str, int] = {}
        for e in errs:
            key = e.split("ERROR:")[-1].strip()[:90]
            seen[key] = seen.get(key, 0) + 1
        print(f"\n  {path.name}: {len(errs)} restore errors, {len(seen)} kinds")
        for k, n in list(seen.items())[:8]:
            print(f"     ×{n:<4} {k}")


@pytest.fixture(scope="session", autouse=True)
def database() -> None:
    """Rebuild both test databases from the committed fixtures.

    Session-scoped and destructive. It drops `dental_test` and
    `dental_os_test` — never `dental`, which is the container's own
    development database and not ours to clear.
    """
    for f in ("dental.sql", "dental_os.sql", "dental_os_bundles.sql"):
        if not (FIXTURES / f).exists():
            pytest.fail(
                f"tests/fixtures/{f} is missing. Run "
                f"`python scripts/refresh_test_fixture.py` (needs AWS)."
            )

    # The dumps name these roles in policies and function bodies, so
    # they have to exist before the restore, not after.
    for role, extra in ((APP_ROLE, f"LOGIN PASSWORD '{APP_PW}'"),
                        ("dental_auth", "NOLOGIN BYPASSRLS"),
                        ("dental_admin", "NOLOGIN")):
        _psql("postgres", f"""
            DO $$ BEGIN
              IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='{role}')
              THEN CREATE ROLE {role} {extra};
              ELSE ALTER ROLE {role} {extra};
              END IF;
            END $$;""")

    for db, dumps in ((SIM_DB, ["dental.sql"]),
                      (OS_DB, ["dental_os.sql", "dental_os_bundles.sql"])):
        _psql("postgres", f"DROP DATABASE IF EXISTS {db} WITH (FORCE)")
        _psql("postgres", f"CREATE DATABASE {db}")
        for d in dumps:
            _restore(db, FIXTURES / d)
        # --no-acl stripped the GRANTs. dental_app is still a non-owner,
        # so every RLS policy applies to it — which is the property this
        # suite depends on.
        _psql(db, f"""
            GRANT USAGE ON SCHEMA public TO {APP_ROLE};
            GRANT SELECT, INSERT, UPDATE, DELETE
              ON ALL TABLES IN SCHEMA public TO {APP_ROLE};
            GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO {APP_ROLE};
            GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO {APP_ROLE};""")

    preds = _psql(SIM_DB, "SELECT count(*) FROM pred_requests")
    bundles = _psql(OS_DB, "SELECT count(*) FROM persona_bundles")
    if preds == "0" or bundles == "0":
        pytest.fail(
            f"restore produced no data (pred_requests={preds}, "
            f"persona_bundles={bundles}). The fixtures are stale or the "
            f"restore errors above were not noise after all."
        )

    # users, ours, never production's.
    pw = bcrypt.hashpw(PASSWORD.encode(), bcrypt.gensalt(rounds=4)).decode()
    _psql(OS_DB, "TRUNCATE users")
    for email, name, role, tenant in TEST_USERS:
        t = f"'{tenant}'" if tenant else "NULL"
        _psql(OS_DB,
              f"INSERT INTO users (email, password_hash, name, role, tenant_id)"
              f" VALUES ('{email}', '{pw}', '{name}', '{role}', {t})")

    # The pristine copy reset_events rewinds to. Taken after the users
    # exist so it is the state every test starts from.
    for t in MUTABLE_TABLES:
        _psql(OS_DB, f"CREATE TABLE {_SNAP}{t} AS TABLE {t}")

    print(f"\n  test db ready — {preds} pre-Ds, {bundles} bundles, "
          f"{len(TEST_USERS)} users")


@pytest_asyncio.fixture(scope="session", loop_scope="session")
async def client(database):
    """The app, booted, with its lifespan run.

    httpx's ASGITransport does not run startup events, and this app
    opens both pools in a lifespan handler — without entering it
    explicitly every request would find app.state.os_pool is None.
    """
    import httpx

    from core.db import connection

    # A previous test module may have created pools against another
    # DSN. These are module globals; clear them or get_pool() hands
    # back the wrong database with no error.
    connection._pool = None
    connection._os_pool = None
    connection._admin_pool = None

    from api.main import app

    async with app.router.lifespan_context(app):
        transport = httpx.ASGITransport(app=app)
        async with httpx.AsyncClient(
            transport=transport, base_url="http://test", timeout=30.0
        ) as c:
            yield c


@pytest_asyncio.fixture(scope="session", loop_scope="session")
async def tokens(client) -> dict[str, dict[str, str]]:
    """role -> Authorization header, by actually logging in.

    Minting tokens directly would skip authenticate_user(), which is a
    SECURITY DEFINER function over an RLS-protected table and exactly
    the kind of thing that breaks silently.
    """
    out: dict[str, dict[str, str]] = {}
    for email, _name, role, tenant in TEST_USERS:
        key = role if tenant != "tampa_smiles" else f"tampa_{role}"
        r = await client.post(
            "/auth/login", json={"email": email, "password": PASSWORD}
        )
        assert r.status_code == 200, f"login failed for {email}: {r.text[:300]}"
        out[key] = {"Authorization": f"Bearer {r.json()['token']}"}
    return out


@pytest.fixture(scope="session")
def sample(database) -> dict[str, str]:
    """Ids the fixture actually contains, read out of it once.

    Read from the database rather than hard-coded, so refreshing the
    fixture cannot leave a test asserting against a pre-D that is no
    longer there — it would fail here, once, with a clear reason,
    instead of as a 404 in fifteen unrelated tests.
    """
    got = {
        "schedule_date": _psql(
            OS_DB, "SELECT max(appointment_date)::text FROM appointments "
                   "WHERE tenant_id = 'suwanee_smiles'"),
        "denied_pred": _psql(
            OS_DB, "SELECT pred_request_id FROM denial_events "
                   "ORDER BY pred_request_id LIMIT 1"),
        "appeal_id": _psql(
            OS_DB, "SELECT appeal_id FROM appeal_events "
                   "ORDER BY filed_at LIMIT 1"),
        "attested_pred": _psql(
            OS_DB, "SELECT pred_request_id FROM clinical_attestations LIMIT 1"),
        "pred": "PRED-SIM-DA-A01",
    }
    missing = [k for k, v in got.items() if not v]
    if missing:
        pytest.fail(f"fixture is missing {missing} — regenerate it")
    return got


@pytest.fixture
def reset_events():
    """Put every writable table back to exactly what the fixture holds.

    Before the test rather than after, so a failure leaves its rows
    behind to be looked at. TRUNCATE takes all of them in one statement
    because they reference each other; the reinserts then follow
    MUTABLE_TABLES, which is in FK order.
    """
    # One round trip. Every write test asks for this, and eleven
    # separate `docker exec`s would put a second of process startup in
    # front of each of them.
    _psql(OS_DB, "TRUNCATE " + ", ".join(MUTABLE_TABLES) + " CASCADE; " + " ".join(
        f"INSERT INTO {t} SELECT * FROM {_SNAP}{t};" for t in MUTABLE_TABLES))
    yield
