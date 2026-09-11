#!/usr/bin/env bash
#
# Task 3, deferred. Creates both CloudFront distributions and the S3
# bucket policies that let them read.
#
#   ./scripts/provision-cloudfront.sh
#
# WHY THIS IS A SCRIPT AND NOT ALREADY DONE
# CloudFront will not accept an ACM certificate that is still
# PENDING_VALIDATION, and the certificate cannot validate until a CNAME
# is added at the registrar — which needs a human with a Namecheap
# login. So the buckets, the certificate and the OAC exist; the two
# distributions are one command away, behind that DNS record.
#
# Refuses to run until the certificate reports ISSUED. Creating a
# distribution with a pending cert fails partway and leaves a disabled
# distribution that takes ~15 minutes to delete.
set -euo pipefail

PROFILE="${AWS_PROFILE_DENTAL:-dental}"
ACCOUNT="740104998309"
CERT_ARN="${CERT_ARN:-arn:aws:acm:us-east-1:740104998309:certificate/5ed1f81f-167a-450b-be14-acb594bda39e}"
OAC_ID="${OAC_ID:-E242IVFH6W9311}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

STATUS=$(aws acm describe-certificate \
  --certificate-arn "$CERT_ARN" --region us-east-1 --profile "$PROFILE" \
  --query 'Certificate.Status' --output text)

if [ "$STATUS" != "ISSUED" ]; then
  echo "Certificate is ${STATUS}, not ISSUED."
  echo
  echo "Add this CNAME at Namecheap, then wait:"
  aws acm describe-certificate \
    --certificate-arn "$CERT_ARN" --region us-east-1 --profile "$PROFILE" \
    --query 'Certificate.DomainValidationOptions[0].ResourceRecord.[Name,Value]' \
    --output text
  echo
  echo "  aws acm wait certificate-validated \\"
  echo "    --certificate-arn $CERT_ARN \\"
  echo "    --region us-east-1 --profile $PROFILE"
  exit 1
fi

mkdir -p .infra

make_config() {
  local bucket="$1" comment="$2" aliases="$3" ref="$4"
  cat > ".infra/cf-${ref}.json" <<JSON
{
  "CallerReference": "${ref}-$(date +%s)",
  "Comment": "${comment}",
  "Enabled": true,
  "DefaultRootObject": "index.html",
  "Aliases": ${aliases},
  "Origins": {
    "Quantity": 1,
    "Items": [{
      "Id": "${bucket}",
      "DomainName": "${bucket}.s3.us-east-1.amazonaws.com",
      "S3OriginConfig": { "OriginAccessIdentity": "" },
      "OriginAccessControlId": "${OAC_ID}"
    }]
  },
  "DefaultCacheBehavior": {
    "TargetOriginId": "${bucket}",
    "ViewerProtocolPolicy": "redirect-to-https",
    "CachePolicyId": "658327ea-f89d-4fab-a63d-7e88639e58f6",
    "Compress": true,
    "AllowedMethods": {
      "Quantity": 2,
      "Items": ["GET", "HEAD"],
      "CachedMethods": { "Quantity": 2, "Items": ["GET", "HEAD"] }
    }
  },
  "CustomErrorResponses": {
    "Quantity": 2,
    "Items": [
      {
        "ErrorCode": 404,
        "ResponseCode": "200",
        "ResponsePagePath": "/index.html",
        "ErrorCachingMinTTL": 0
      },
      {
        "ErrorCode": 403,
        "ResponseCode": "200",
        "ResponsePagePath": "/index.html",
        "ErrorCachingMinTTL": 0
      }
    ]
  },
  "ViewerCertificate": {
    "ACMCertificateArn": "${CERT_ARN}",
    "SSLSupportMethod": "sni-only",
    "MinimumProtocolVersion": "TLSv1.2_2021"
  },
  "PriceClass": "PriceClass_100"
}
JSON
}

# 403 -> /index.html matters as much as 404. With OAC on a private
# bucket, a missing key returns AccessDenied (403), not NoSuchKey (404),
# because the caller is not allowed to know which it was. Without the
# 403 rule every client-side route except "/" would show CloudFront's
# access-denied page on a hard refresh.
make_config accorddental-io-www "accorddental.io LP" \
  '{"Quantity":2,"Items":["accorddental.io","www.accorddental.io"]}' lp
make_config accorddental-io-app "app.accorddental.io" \
  '{"Quantity":1,"Items":["app.accorddental.io"]}' app

: > infra.env
for ref in lp app; do
  case "$ref" in
    lp)  bucket="accorddental-io-www" ;;
    app) bucket="accorddental-io-app" ;;
  esac

  echo "==> Creating distribution for ${bucket}"
  read -r DIST_ID DOMAIN < <(aws cloudfront create-distribution \
    --distribution-config "file://.infra/cf-${ref}.json" \
    --profile "$PROFILE" \
    --query 'Distribution.[Id,DomainName]' --output text)
  echo "    ${DIST_ID}  ${DOMAIN}"

  cat > ".infra/s3-policy-${ref}.json" <<JSON
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "AllowCloudFrontOAC",
    "Effect": "Allow",
    "Principal": { "Service": "cloudfront.amazonaws.com" },
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::${bucket}/*",
    "Condition": {
      "StringEquals": {
        "AWS:SourceArn": "arn:aws:cloudfront::${ACCOUNT}:distribution/${DIST_ID}"
      }
    }
  }]
}
JSON
  aws s3api put-bucket-policy --bucket "$bucket" \
    --policy "file://.infra/s3-policy-${ref}.json" --profile "$PROFILE"
  echo "    bucket policy applied"

  if [ "$ref" = "lp" ]; then
    echo "CF_ID_LP=${DIST_ID}"   >> infra.env
    echo "CF_DOMAIN_LP=${DOMAIN}" >> infra.env
  else
    echo "CF_ID_APP=${DIST_ID}"   >> infra.env
    echo "CF_DOMAIN_APP=${DOMAIN}" >> infra.env
  fi
done

echo
echo "Wrote infra.env:"
cat infra.env
echo
echo "Now point DNS at these CloudFront domains — see DNS.md."
