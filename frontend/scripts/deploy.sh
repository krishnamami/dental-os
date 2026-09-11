#!/usr/bin/env bash
#
# Build and ship one target to S3 + CloudFront.
#
#   ./scripts/deploy.sh lp     -> accorddental.io
#   ./scripts/deploy.sh app    -> app.accorddental.io
#
# CF_ID_LP / CF_ID_APP are read from the environment (or infra.env) so
# this script can be committed before CloudFront exists. It refuses to
# run rather than invalidating the wrong distribution — a wrong id here
# would silently deploy the app build over the landing page.
set -euo pipefail

TARGET="${1:-lp}"
PROFILE="${AWS_PROFILE_DENTAL:-dental}"
REGION="us-east-1"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Written by scripts/provision-cloudfront.sh once the cert validates.
if [ -f infra.env ]; then
  # shellcheck disable=SC1091
  source infra.env
fi

case "$TARGET" in
  lp)
    BUCKET="accorddental-io-www"
    CF_ID="${CF_ID_LP:-}"
    echo "==> Building LP (accorddental.io)"
    npm run build
    ;;
  app)
    BUCKET="accorddental-io-app"
    CF_ID="${CF_ID_APP:-}"
    echo "==> Building app (app.accorddental.io)"
    VITE_APP_MODE=app npm run build
    ;;
  *)
    echo "usage: $0 [lp|app]" >&2
    exit 2
    ;;
esac

if [ ! -d dist ]; then
  echo "No dist/ after build — nothing to deploy." >&2
  exit 1
fi

echo "==> Syncing to s3://${BUCKET}"
# Hashed assets are immutable and cached for a year. index.html is NOT
# in this sync (--exclude) because it is the one file that must never be
# cached: it is what points at the new hashed bundles, so a cached copy
# pins every visitor to the previous deploy.
aws s3 sync dist/ "s3://${BUCKET}/" \
  --delete \
  --profile "$PROFILE" \
  --region "$REGION" \
  --cache-control "max-age=31536000,immutable" \
  --exclude "index.html"

aws s3 cp dist/index.html "s3://${BUCKET}/index.html" \
  --profile "$PROFILE" \
  --region "$REGION" \
  --cache-control "no-cache,no-store,must-revalidate"

if [ -z "$CF_ID" ]; then
  echo
  echo "!! No CloudFront id for '${TARGET}'. Files are in S3 but nothing"
  echo "   was invalidated, and with the buckets private nothing is"
  echo "   publicly reachable yet."
  echo "   Run scripts/provision-cloudfront.sh once the ACM cert shows"
  echo "   ISSUED; it writes infra.env with CF_ID_LP and CF_ID_APP."
  exit 0
fi

echo "==> Invalidating CloudFront ${CF_ID}"
aws cloudfront create-invalidation \
  --distribution-id "$CF_ID" \
  --paths "/*" \
  --profile "$PROFILE" \
  --query 'Invalidation.Id' \
  --output text

echo "Done. ${TARGET} deploying — CloudFront takes a few minutes to settle."
