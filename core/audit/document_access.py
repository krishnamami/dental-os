"""Write document_access_events at presign time.

Called exclusively from the presign endpoint. Every presign is one row.
No exceptions.

⚠ IT RAISES, AND THE CALLER MUST NOT SWALLOW IT. If this insert fails
the endpoint returns 500 and does NOT return the URL. An access that
happened without a record is worse than an access that did not happen:
the document is out and nothing can say who took it. That trade — lose
the read rather than lose the record — is the whole reason the call
sits before the URL is returned and not after.

── WHY stdlib logging AND NOT structlog ─────────────────────────────
The brief used structlog. It is not a dependency of this repo and
nothing else here uses it; every other module logs through
`logging.getLogger(__name__)`, which is what api/main.py configures.
Adding a logging framework for one call site is not worth the
divergence, so the structured fields are passed as %-args instead.

── WHY THE TENANT IS BOUND, NOT TRUSTED ─────────────────────────────
The write goes through execute_os_with_tenant, so app.tenant_id is set
inside the transaction and the row has to satisfy the table's WITH
CHECK. A bug that tried to log one practice's access under another
practice's tenant is refused by the database rather than recorded
wrongly — which for an audit table matters more than for most.
"""
from __future__ import annotations

import logging
from datetime import datetime

from core.db.connection import execute_os_with_tenant

logger = logging.getLogger(__name__)


async def log_document_access(
    os_pool,
    *,
    tenant_id: str,
    pred_request_id: str,
    evidence_id: str,
    document_type: str,
    user_id: str,
    user_role: str,
    ip_address: str | None,
    user_agent: str | None,
    url_expires_at: datetime | None,
    access_type: str = "presign",
) -> int:
    """Insert one row. Returns its access_id.

    Must be called BEFORE the presigned URL reaches the client. If this
    raises, the caller returns 500 and withholds the URL.
    """
    rows = await execute_os_with_tenant(
        os_pool,
        tenant_id,
        """
        INSERT INTO document_access_events (
            tenant_id, pred_request_id, evidence_id, document_type,
            access_type, user_id, user_role, ip_address, user_agent,
            url_expires_at, occurred_at
        ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10, now())
        RETURNING access_id
        """,
        tenant_id, pred_request_id, evidence_id, document_type,
        access_type, user_id, user_role, ip_address,
        # A user agent is attacker-influenced and unbounded; a browser
        # sends ~120 chars and a fuzzer sends whatever it likes. Capped
        # so one request cannot bloat the audit table.
        (user_agent or "")[:512] or None,
        url_expires_at,
    )
    access_id = rows[0]["access_id"]

    logger.info(
        "document_access_logged access_id=%s tenant=%s pred=%s evidence=%s "
        "type=%s user=%s role=%s",
        access_id, tenant_id, pred_request_id, evidence_id,
        document_type, user_id, user_role,
    )
    return access_id
