"""
Authentication — who is asking, and on behalf of which practice.

⚠ WHAT THIS DOES AND DOES NOT PROTECT
─────────────────────────────────────────────────────────────────────
This issues a signed token and tells the frontend which role it holds.
It does NOT yet guard the data endpoints: GET /decisions/{id} and the
rest are still open to anyone who can reach the API, and on
accorddental.io that is the public internet.

So this is a session and a role, not an access-control boundary. A
login screen in front of an open API protects nothing on its own —
the second half of the job is a dependency on every data route that
reads `tenant_id` from these claims instead of trusting a query
parameter. Until then, treat the corpus as public. It is synthetic, so
that is survivable; it stops being survivable the day a real patient
lands in it.

TOKENS
    HS256, 7 days, no refresh and no revocation list. Signing out
    forgets the token client-side; it stays valid until it expires.
    Good enough for a demo, not for a product — a compromised token
    cannot be withdrawn.

IMPERSONATION
    accord_admin may mint a token for any user. The token records who
    did it in `impersonated_by`, so the audit question ("was this Dr.
    Chinta, or an admin acting as her?") is answerable from the token
    alone. Nothing consumes that claim yet — see the note on guards.
"""
from __future__ import annotations

import logging
import os
import secrets
from datetime import datetime, timedelta, timezone

import bcrypt
import jwt as pyjwt
from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import OAuth2PasswordBearer
from pydantic import BaseModel
from starlette.concurrency import run_in_threadpool

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/auth", tags=["auth"])

# ─────────────────────────────────────────────────────────────────────
# The signing key.
#
# There is deliberately NO usable default committed here. A literal
# like "dental-dev-2026" in a public repository is not a secret: anyone
# who reads this file can mint a token claiming role=accord_admin, and
# accord_admin can impersonate every user in the system. That is worse
# than having no login at all, because it looks like a door.
#
# Unset -> a random key for this process. Local development works; the
# tokens simply stop being valid when the server restarts, which is a
# visible annoyance rather than a silent hole. Production sets
# JWT_SECRET from SSM.
# ─────────────────────────────────────────────────────────────────────
JWT_SECRET = os.environ.get("JWT_SECRET")
if not JWT_SECRET:
    JWT_SECRET = secrets.token_urlsafe(48)
    logger.warning(
        "JWT_SECRET is not set — using a random key for this process. "
        "Tokens will not survive a restart. Set JWT_SECRET in any "
        "deployment that expects sessions to persist."
    )

JWT_ALGO = "HS256"
JWT_HOURS = 24 * 7

oauth2 = OAuth2PasswordBearer(tokenUrl="/auth/login", auto_error=False)

TENANT_NAMES = {
    "suwanee_smiles": "Suwanee Smiles Dental",
    "tampa_smiles": "Tampa Bay Smiles",
    "dallas_dental": "Dallas Family Dental",
}

TENANT_ADDRESSES = {
    "suwanee_smiles": "3155 Peachtree Pkwy Ste 120, Suwanee GA",
    "tampa_smiles": "4321 Bay St, Tampa FL",
    "dallas_dental": "7890 Commerce St, Dallas TX",
}

# Wired by main.py's lifespan once the pool exists.
os_pool = None


def _pool():
    """Fail with a diagnosis rather than 'NoneType has no fetchrow'."""
    if os_pool is None:
        raise HTTPException(
            503,
            "Auth is not wired to a database. api.main must set "
            "auth.os_pool during startup.",
        )
    return os_pool


class LoginRequest(BaseModel):
    email: str
    password: str


class UserOut(BaseModel):
    user_id: str
    email: str
    name: str
    role: str
    tenant_id: str | None
    tenant_name: str | None
    tenant_address: str | None


class LoginResponse(BaseModel):
    token: str
    user: UserOut


class ImpersonateRequest(BaseModel):
    user_id: str


def make_token(user_id, role, tenant_id, impersonated_by=None) -> str:
    payload = {
        "sub": user_id,
        "role": role,
        "tenant_id": tenant_id,
        "exp": datetime.now(timezone.utc) + timedelta(hours=JWT_HOURS),
    }
    if impersonated_by:
        payload["impersonated_by"] = impersonated_by
    return pyjwt.encode(payload, JWT_SECRET, JWT_ALGO)


def decode_token(token: str) -> dict:
    try:
        return pyjwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGO])
    except pyjwt.ExpiredSignatureError:
        raise HTTPException(401, "Token expired")
    except pyjwt.InvalidTokenError:
        raise HTTPException(401, "Invalid token")


async def get_claims(token=Depends(oauth2)) -> dict:
    if not token:
        raise HTTPException(401, "Not authenticated")
    return decode_token(token)


async def require_admin(claims=Depends(get_claims)) -> dict:
    if claims.get("role") != "accord_admin":
        raise HTTPException(403, "Admin only")
    return claims


def row_to_user(row) -> UserOut:
    tenant = row["tenant_id"] or ""
    return UserOut(
        user_id=row["user_id"],
        email=row["email"],
        name=row["name"],
        role=row["role"],
        tenant_id=row["tenant_id"],
        tenant_name=TENANT_NAMES.get(tenant),
        tenant_address=TENANT_ADDRESSES.get(tenant),
    )


# A valid hash of a value nobody will submit. Verifying against it when
# the email is unknown makes a miss cost the same as a wrong password,
# so response time stops telling an attacker which addresses exist.
_DUMMY_HASH = bcrypt.hashpw(secrets.token_bytes(32), bcrypt.gensalt()).decode()


def _check(password: str, hashed: str) -> bool:
    try:
        return bcrypt.checkpw(password.encode(), hashed.encode())
    except ValueError:
        # A malformed hash in the row — treat as a failed login, not a 500.
        return False


@router.post("/login", response_model=LoginResponse)
async def login(req: LoginRequest) -> LoginResponse:
    row = await _pool().fetchrow(
        "SELECT * FROM users WHERE email = $1 AND active = true",
        req.email.lower().strip(),
    )
    # bcrypt is CPU-bound by design — roughly 100ms at the default cost
    # factor. Awaiting it on the event loop would stall every other
    # request in this worker for that long, so it runs on a thread.
    ok = await run_in_threadpool(
        _check, req.password, row["password_hash"] if row else _DUMMY_HASH
    )
    if not row or not ok:
        raise HTTPException(401, "Invalid email or password")
    return LoginResponse(
        token=make_token(row["user_id"], row["role"], row["tenant_id"]),
        user=row_to_user(row),
    )


@router.get("/me", response_model=LoginResponse)
async def me(claims=Depends(get_claims)) -> LoginResponse:
    """Restore a session, and re-read the user rather than trusting the
    token's copy of their role — a role changed in the database has to
    take effect before the 7-day expiry."""
    row = await _pool().fetchrow(
        "SELECT * FROM users WHERE user_id = $1 AND active = true",
        claims["sub"],
    )
    if not row:
        raise HTTPException(404, "User not found")
    # Carry the impersonation marker across a refresh, or "view as"
    # would quietly become "is" the moment the tab reloads.
    return LoginResponse(
        token=make_token(
            row["user_id"],
            row["role"],
            row["tenant_id"],
            impersonated_by=claims.get("impersonated_by"),
        ),
        user=row_to_user(row),
    )


@router.post("/impersonate", response_model=LoginResponse)
async def impersonate(
    req: ImpersonateRequest, claims=Depends(require_admin)
) -> LoginResponse:
    row = await _pool().fetchrow(
        "SELECT * FROM users WHERE user_id = $1 AND active = true",
        req.user_id,
    )
    if not row:
        raise HTTPException(404, "User not found")
    # An already-impersonating admin cannot chain: the ORIGINAL admin
    # stays recorded, so the trail never loses who started it.
    origin = claims.get("impersonated_by") or claims["sub"]
    logger.info("impersonation: %s -> %s", origin, row["user_id"])
    return LoginResponse(
        token=make_token(
            row["user_id"], row["role"], row["tenant_id"], impersonated_by=origin
        ),
        user=row_to_user(row),
    )


@router.get("/users")
async def list_users(
    tenant_id: str | None = None, claims=Depends(require_admin)
) -> list[dict]:
    if tenant_id:
        rows = await _pool().fetch(
            "SELECT user_id, email, name, role, tenant_id FROM users "
            "WHERE tenant_id = $1 AND active = true ORDER BY role, name",
            tenant_id,
        )
    else:
        rows = await _pool().fetch(
            "SELECT user_id, email, name, role, tenant_id FROM users "
            "WHERE active = true ORDER BY tenant_id NULLS LAST, role, name"
        )
    return [dict(r) for r in rows]
