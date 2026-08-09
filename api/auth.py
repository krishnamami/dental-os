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
from fastapi import APIRouter, Depends, HTTPException, Request
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

# How a patient reaches the practice back. These end up on a sheet
# handed to a patient and in the reply-to of a mail they receive, so
# they are the practice's own details — never a coordinator's personal
# line.
#
# Still a literal, like the two tables above, because there is no
# tenants-with-contact-details table on either database. The moment one
# exists, all three of these move into it.
TENANT_CONTACTS = {
    "suwanee_smiles": {
        "email": "info@suwaneesmiles.com",
        "phone": "+17704912345",
    },
    "tampa_smiles": {
        "email": "info@tampabaysmiles.com",
        "phone": "+18135559876",
    },
    "dallas_dental": {
        "email": "info@dallasfamilydental.com",
        "phone": "+12145551234",
    },
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


# ─────────────────────────────────────────────────────────────────────
# Capabilities.
#
# One dependency per CAPABILITY, not per endpoint: two routes that
# answer the same question about a caller share the same guard, so the
# answer cannot drift between them.
#
# ⚠ THESE READ THE EFFECTIVE ROLE, WHICH IS THE POINT. make_token()
# stamps the IMPERSONATED user's role, so an accord_admin viewing as a
# treatment coordinator carries role=tx_coord and is refused clinical
# writes. "accord_admin passes everything" therefore applies to an
# admin acting AS THEMSELVES only. Reading the real identity out of
# `impersonated_by` here would hand every admin a clinician's
# signature the moment they used "view as", which is the opposite of
# what impersonation is for.
# ─────────────────────────────────────────────────────────────────────


def _capability(name: str, roles: tuple[str, ...], message: str):
    """Build a dependency that admits `roles`, plus accord_admin."""
    allowed = set(roles) | {"accord_admin"}

    async def dependency(claims=Depends(get_claims)) -> dict:
        if claims.get("role") in allowed:
            return claims
        raise HTTPException(403, message)

    dependency.__name__ = name
    return dependency


# Writing to the clinical record: a narrative, a justification, an
# attestation. Requires clinical judgement to be answerable for.
require_clinician_cap = _capability(
    "require_clinician_cap",
    ("dentist",),
    "Only a clinician can write to the clinical record on this pre-D",
)

# Judging the ENGINE: accepting a signal, overriding it, calling it a
# false positive. provider_feedback is what the audit trail is built on
# and what retrains the rules, so "who is allowed to say the engine was
# wrong" is a real question and the answer is not "anyone signed in".
#
# revenue_ops and dentist only. The front desk and the coordinator work
# the queue but do not adjudicate payer policy, and dso_owner reads the
# portfolio rather than individual findings.
require_engine_feedback = _capability(
    "require_engine_feedback",
    ("revenue_ops", "dentist"),
    "This role cannot record a verdict on an engine finding",
)

# Handing a case to someone else. Everyone, deliberately — the front
# desk flags a patient to the clinician, the coordinator hands over
# after the consultation, billing chases a narrative. Enumerated rather
# than left as bare authentication so that a NEW role has to be added
# here on purpose; the failure mode of the alternative is a role nobody
# considered quietly gaining the ability to put work in the dentist's
# queue.
require_handoff_sender = _capability(
    "require_handoff_sender",
    ("front_desk", "tx_coord", "revenue_ops", "dentist", "dso_owner"),
    "This role cannot hand a case to another",
)

# Acting on a payer relationship: filing an appeal. Billing's job.
require_billing = _capability(
    "require_billing",
    ("revenue_ops",),
    "Only billing can act on a payer appeal",
)

# Contacting a patient. Everyone who speaks to patients, which is not
# the clinician's exclusive province.
#
# dentist is IN, and was the one screen the first cut of this broke: a
# dentist holds the Patient Financial product and walks the patient
# through their own estimate on /coverage. What made that safe to allow
# is not the role list — it is that send_sms() reads the destination off
# the pre-D's own patient row, so who presses the button can no longer
# change who receives the text.
require_patient_contact = _capability(
    "require_patient_contact",
    ("front_desk", "tx_coord", "revenue_ops", "dentist"),
    "This role does not contact patients",
)

# Chasing a missing document. A coordinator doing this is a real
# workflow, so it is deliberately wider than the clinical writes.
require_document_chase = _capability(
    "require_document_chase",
    ("dentist", "tx_coord"),
    "Only a clinician or a treatment coordinator can request documents",
)


async def require_clinician(claims=Depends(get_claims)) -> dict:
    """Only a clinician may write to the clinical record.

    ⚠ ADDED AFTER A WALKTHROUGH FOUND A TREATMENT COORDINATOR HAD
    SIGNED A CLINICAL ATTESTATION. The statement reads "accurate to the
    best of my clinical judgement"; a coordinator has none to offer and
    the endpoints accepted it anyway, because they used require_claims
    — authenticated, not authorised.

    accord_admin is included so support can act on a practice's behalf;
    that is already an audited, impersonated action.
    """
    if claims.get("role") in ("dentist", "accord_admin"):
        return claims
    raise HTTPException(
        403,
        "Only a clinician can write to the clinical record on this pre-D",
    )


async def require_practice_admin(claims=Depends(get_claims)) -> dict:
    """accord_admin anywhere, or a practice owner INSIDE THEIR OWN TENANT.

    This is deliberately weaker than require_admin and must never be
    used on a route that can read across tenants. Every route that
    depends on it has to scope by `tenant_filter(claims)` rather than by
    a tenant_id the caller sent — a dso_owner who passes
    ?tenant_id=someone_else is asking a question they may not ask, and
    the route answers about their own practice instead.
    """
    if claims.get("role") in ("accord_admin", "dso_owner"):
        return claims
    raise HTTPException(403, "Admin only")


# ─────────────────────────────────────────────────────────────────────
# Guards for the DATA routes.
#
# Everything below is what turns the login from a session into a
# boundary. Before this, GET /decisions/{id} answered anyone.
# ─────────────────────────────────────────────────────────────────────

# The one tenant whose synthetic corpus is deliberately public: it is
# what ?demo=true on the marketing site reads. Nothing else is.
DEMO_TENANT = "suwanee_smiles"

DEMO_CLAIMS = {
    "sub": "demo-user",
    "role": "dentist",
    "tenant_id": DEMO_TENANT,
    "demo": True,
}


async def get_claims_optional(token=Depends(oauth2)) -> dict | None:
    """Claims if a valid token was sent, else None. Never raises."""
    if not token:
        return None
    try:
        return decode_token(token)
    except HTTPException:
        return None


async def require_claims(token=Depends(oauth2)) -> dict:
    """A valid token, or 401."""
    if not token:
        raise HTTPException(401, "Authentication required")
    return decode_token(token)


async def require_claims_or_demo(
    request: Request, token=Depends(oauth2)
) -> dict:
    """A valid token, or the public demo identity.

    ⚠ READ THIS BEFORE ADDING ANOTHER CALLER.

    `X-Demo-Mode: true` is a credential-free path into the API. It is
    here because the marketing site's ?demo=true tour is a deliberate
    public feature — a prospect must see a real pre-D without an
    account. The honest way to say that is: SUWANEE_SMILES' SYNTHETIC
    CORPUS IS PUBLIC DATA. Anyone can read it, header or no header.

    So the header is bounded to the smallest thing that keeps the tour
    working, rather than left as a general bypass:

      · it grants suwanee_smiles and nothing else — a demo request for a
        Tampa or Dallas pre-D 404s exactly like a signed-in Suwanee
        user's would;
      · it grants SAFE METHODS ONLY. POST /feedback writes a row, and a
        write is never something an anonymous header should authorise.

    The day a real patient enters suwanee_smiles, this function and the
    tour it serves both have to go.
    """
    if request.headers.get("X-Demo-Mode") == "true":
        if request.method in ("GET", "HEAD", "OPTIONS"):
            return dict(DEMO_CLAIMS)
        raise HTTPException(
            403, "Demo mode is read-only. Sign in to write."
        )
    if not token:
        raise HTTPException(401, "Authentication required")
    return decode_token(token)


def tenant_filter(claims: dict) -> str | None:
    """The tenant a caller is confined to, or None for accord_admin.

    None means "no filter", NOT "no access" — read it carefully at every
    call site, because getting that backwards fails open.
    """
    if claims.get("role") == "accord_admin":
        return None
    return claims.get("tenant_id")


def assert_tenant_allowed(claims: dict, tenant: str) -> None:
    """Refuse a caller reading a pre-D that belongs to someone else.

    404, not 403. A 403 confirms the record exists under another
    practice, which turns this endpoint into an oracle: walk the id
    space, and the difference between 403 and 404 maps out every
    competitor's caseload. 404 says only "not yours to see".
    """
    allowed = tenant_filter(claims)
    if allowed is None:
        return  # accord_admin
    if allowed != tenant:
        raise HTTPException(404, "Not found")


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
    tenant_id: str | None = None, claims=Depends(require_practice_admin)
) -> list[dict]:
    # A practice owner reads their own staff and nobody else's. The
    # query parameter is IGNORED for them, not validated — validating it
    # would 403 on a mistyped tenant and confirm which tenants exist.
    if claims.get("role") != "accord_admin":
        tenant_id = tenant_filter(claims)
        if not tenant_id:
            raise HTTPException(403, "Admin only")

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
