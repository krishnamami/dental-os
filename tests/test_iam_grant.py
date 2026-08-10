"""The task role may read clinical documents and do nothing else.

── WHY THIS IS A TEST AND NOT A COMMENT ──────────────────────────────
The document objects carry no tenant marker: empty metadata, empty tag
set, and a bucket policy that conditions on nothing but TLS. Tenant
ownership lives only in the clinical_evidence row. So for a task that
has been compromised, the IAM grant is not one control among several —
it is the only thing between the process and every practice's charts.

It held s3:PutObject, s3:DeleteObject and s3:ListBucket, and nothing in
either service has ever written or listed. Ingestion runs from a
developer machine as the `dental-deploy` user
(dental-simulator/infra/upload_docs.sh, `--profile dental`), which is a
separate principal and keeps its write rights.

── WHY IT WILL DRIFT BACK IF NOBODY WATCHES ──────────────────────────
⚠ THE ROLE IS OWNED BY CLOUDFORMATION, IN THE OTHER REPO.
dental-simulator/infra/cloudformation/04-ecs.yaml declares the wide
version, the `dental-ecs` stack owns it, and CONTEXT.md RULE 15 makes
that file read-only from here. The live policy was tightened directly,
so the stack is now drifted on purpose — and a future
`aws cloudformation deploy` of dental-ecs would silently restore
PutObject and DeleteObject with no error and no alarm.

This test is what turns that from silent into loud.

── IT SKIPS WITHOUT CREDENTIALS ──────────────────────────────────────
The rest of the API suite is offline by design and must stay runnable
with no AWS at all. This one needs the real account to mean anything,
so it skips rather than fails when the profile is absent — and runs
wherever the credentials exist, which is where the drift would happen.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess

import pytest

ROLE = "arn:aws:iam::740104998309:role/dental-task-role"
BUCKET = "dental-documents-740104998309"
PROFILE = os.environ.get("AWS_PROFILE_DENTAL", "dental")

# Everything a compromised task must not be able to do to the corpus.
FORBIDDEN_ON_OBJECT = (
    "s3:PutObject",
    "s3:DeleteObject",
    "s3:DeleteObjectVersion",
    "s3:PutObjectAcl",
    "s3:RestoreObject",
)
FORBIDDEN_ON_BUCKET = (
    "s3:ListBucket",
    "s3:DeleteBucket",
    "s3:PutBucketPolicy",
    "s3:PutBucketAcl",
)


def _simulate(actions: tuple[str, ...], resource: str) -> dict[str, str]:
    """Effective decisions, from IAM itself.

    simulate-principal-policy rather than reading the inline document:
    it evaluates every attached policy, boundary and SCP together, so a
    second policy quietly granting writes cannot slip past a test that
    only greps the one we know about.
    """
    out = subprocess.run(
        ["aws", "iam", "simulate-principal-policy",
         "--policy-source-arn", ROLE,
         "--action-names", *actions,
         "--resource-arns", resource,
         "--profile", PROFILE, "--output", "json"],
        capture_output=True, text=True,
    )
    if out.returncode:
        pytest.skip(f"cannot reach IAM: {out.stderr.strip()[:200]}")
    return {
        r["EvalActionName"]: r["EvalDecision"]
        for r in json.loads(out.stdout)["EvaluationResults"]
    }


@pytest.fixture(scope="module", autouse=True)
def _needs_aws():
    if not shutil.which("aws"):
        pytest.skip("no aws CLI on PATH")
    probe = subprocess.run(
        ["aws", "sts", "get-caller-identity", "--profile", PROFILE],
        capture_output=True, text=True,
    )
    if probe.returncode:
        pytest.skip(f"no usable '{PROFILE}' AWS profile")


def test_the_task_role_can_read_a_document():
    """The feature has to keep working. A grant tightened into
    uselessness fails the same customer as one left wide open."""
    d = _simulate(("s3:GetObject",), f"arn:aws:s3:::{BUCKET}/suwanee_smiles/x.pdf")
    assert d["s3:GetObject"] == "allowed", d


def test_the_task_role_cannot_write_or_delete_a_document():
    """⚠ IF THIS FAILS, CHECK FOR A CloudFormation DEPLOY.

    dental-simulator's 04-ecs.yaml still declares PutObject and
    DeleteObject. Deploying the dental-ecs stack restores them without
    error, and nothing else in this repo would notice.
    """
    d = _simulate(FORBIDDEN_ON_OBJECT, f"arn:aws:s3:::{BUCKET}/suwanee_smiles/x.pdf")
    widened = [a for a, v in d.items() if v == "allowed"]
    assert not widened, (
        f"the task role can {widened} on the clinical document store. "
        f"Nothing in either service writes to it; ingestion runs as "
        f"dental-deploy from a developer machine. Most likely cause: "
        f"the dental-ecs stack was redeployed from "
        f"dental-simulator/infra/cloudformation/04-ecs.yaml, which still "
        f"declares the wide policy."
    )


def test_the_task_role_cannot_act_on_the_bucket_itself():
    d = _simulate(FORBIDDEN_ON_BUCKET, f"arn:aws:s3:::{BUCKET}")
    widened = [a for a, v in d.items() if v == "allowed"]
    assert not widened, f"the task role holds bucket-level rights: {widened}"


def test_the_grant_is_scoped_to_the_documents_bucket():
    """GetObject on this bucket must not be GetObject on any bucket.
    The website buckets are in the same account."""
    for other in ("accorddental-io-www", "accorddental-io-app"):
        d = _simulate(("s3:GetObject",), f"arn:aws:s3:::{other}/index.html")
        assert d["s3:GetObject"] != "allowed", (
            f"the task role can read s3://{other} — the grant is wider "
            f"than the document store"
        )
