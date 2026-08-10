"""Presigned access to the clinical document store.

── THE CONSTRAINT THAT SHAPES THIS MODULE ────────────────────────────
THE CLIENT NEVER SUPPLIES A KEY. Not as a query parameter, not in a
body, not anywhere.

An endpoint that accepts an s3_key and signs it is a read primitive
over the whole bucket: `?key=tampa_smiles/TB-A01/TB-A01_CLINICAL_NOTE
.pdf` is a valid guess, the keys are formulaic, and 427 objects sit
under four predictable prefixes. Worse, a presigned URL is a BEARER
TOKEN — once minted it carries no identity, honours no role, and
answers to anyone holding the string until it expires. Signing an
attacker-chosen key hands them a document with no further checks.

So the caller names a RECORD — a pre-D and an evidence_id — and the
server reads the key out of the row it already had to authorise.

── THERE IS NO SECOND BARRIER ────────────────────────────────────────
Measured, not assumed: the objects carry NO tenant marker. Metadata is
empty, TagSet is empty, and the bucket policy conditions on nothing but
TLS. `suwanee_smiles/...` in the key is a naming convention, and the
task role can read every prefix.

Tenant ownership is therefore knowable ONLY from the clinical_evidence
row pointing at the object. That row is FORCE row-level security and
this module never reads around it — but it does mean a leaked URL is a
leaked document, which is the whole argument for the short TTL below.

── TTL: 5 MINUTES ────────────────────────────────────────────────────
The URL is minted on a click and used immediately. Five minutes covers
a slow connection and a user who clicks then looks away; it does not
cover a URL pasted into a ticket, captured in a proxy log, or left in
browser history for tomorrow. Hours would make the link a credential
with a working life of its own — and since the object has no other
protection, the expiry IS the access control after the fact.
"""
from __future__ import annotations

import logging
import os
from functools import lru_cache

from fastapi import HTTPException

logger = logging.getLogger(__name__)

DOCUMENTS_BUCKET = os.environ.get(
    "DOCUMENTS_BUCKET", "dental-documents-740104998309"
)

# Minutes, not hours. See the module docstring.
URL_TTL_SECONDS = 300


@lru_cache(maxsize=1)
def _client():
    """One boto3 client for the process.

    Imported lazily so the API still boots — and every route that is
    not a document read still answers — on a machine with no AWS
    credentials. A missing client becomes a 503 on this one endpoint
    rather than a failure to start.
    """
    import boto3
    from botocore.config import Config

    return boto3.client(
        "s3",
        region_name=os.environ.get("AWS_REGION", "us-east-1"),
        # SigV4 explicitly: presigned URLs signed with the older
        # algorithm are rejected by buckets created after 2020, and the
        # failure surfaces as a 403 on the URL rather than at signing.
        config=Config(signature_version="s3v4"),
    )


def presign(s3_key: str, *, filename: str | None = None) -> str:
    """A time-limited GET URL for one object.

    ⚠ CALLERS MUST HAVE AUTHORISED THE ROW FIRST. This function does no
    access control of any kind — it cannot, it sees a string. Every call
    site must have read the key out of a tenant-scoped query.
    """
    if not s3_key:
        raise HTTPException(404, "No document on this record")

    params: dict[str, str] = {"Bucket": DOCUMENTS_BUCKET, "Key": s3_key}
    if filename:
        # inline, not attachment: a radiograph should open in the tab a
        # clinician is already looking at rather than land in Downloads.
        params["ResponseContentDisposition"] = f'inline; filename="{filename}"'

    try:
        return _client().generate_presigned_url(
            "get_object", Params=params, ExpiresIn=URL_TTL_SECONDS
        )
    except Exception as exc:  # noqa: BLE001 — any boto failure is a 503
        # ⚠ SIGNING DOES NOT CHECK PERMISSION. generate_presigned_url is
        # arithmetic over the credentials it holds; it succeeds whether
        # or not the task role may read the object, and a missing
        # s3:GetObject shows up as a 403 when the browser follows the
        # link. So this except only catches "no credentials at all".
        # The task role's grant is verified in the deploy checks.
        logger.error("presign failed for %s: %s", s3_key, exc)
        raise HTTPException(
            503,
            "Document storage is not reachable from this deployment.",
        ) from None


def filename_for(s3_key: str) -> str:
    """The last path segment, for the browser's title bar."""
    return s3_key.rsplit("/", 1)[-1] or "document.pdf"
