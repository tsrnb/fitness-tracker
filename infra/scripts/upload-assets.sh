#!/usr/bin/env bash
# Uploads the exercise clips to the assets bucket under a versioned, immutable path.
set -euo pipefail
BUCKET="${1:?usage: upload-assets.sh <bucket> <cdn-url>}"
CDN="${2:?usage: upload-assets.sh <bucket> <cdn-url>}"
SRC="$(cd "$(dirname "$0")/../../flutter_app/assets/exercises" && pwd)"
aws s3 sync "$SRC" "s3://$BUCKET/v1/exercises/" \
  --exclude "*" --include "*.mp4" \
  --content-type video/mp4 \
  --cache-control "public, max-age=31536000, immutable"
echo "Clips available at: $CDN/v1/exercises/<name>.mp4"
