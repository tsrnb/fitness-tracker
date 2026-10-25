#!/usr/bin/env bash
# Builds the Flutter web app and publishes flutter_app/build/web to the
# gh-pages branch, keeping it isolated from master via a git worktree.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKTREE_DIR="$REPO_ROOT/.gh-pages-worktree"
BUILD_WEB_DIR="$REPO_ROOT/flutter_app/build/web"

cd "$REPO_ROOT/flutter_app"
# Live users get the PROD backend. secrets.prod.json (git-ignored; see
# secrets.example.json) holds API_URL, AI_URL, CDN_URL and GOOGLE_WEB_CLIENT_ID
# from `cdk deploy -c stage=prod`. None of these are secret: the API is
# protected by each user's Google session, and the OpenAI key only ever lives
# in AWS SSM. Refuse to ship a dev backend to live users by accident.
SECRETS_FILE="${SECRETS_FILE:-secrets.prod.json}"
if [ ! -f "$SECRETS_FILE" ]; then
  echo "$SECRETS_FILE not found. Deploy the prod stack first (infra/README.md), then create it from secrets.example.json." >&2
  exit 1
fi
if grep -q "localhost" "$SECRETS_FILE"; then
  echo "$SECRETS_FILE points at localhost. Refusing to publish it." >&2
  exit 1
fi
flutter build web --base-href /fitness-tracker/ --dart-define-from-file="$SECRETS_FILE"
cd "$REPO_ROOT"

if [ ! -d "$WORKTREE_DIR" ]; then
  git fetch origin gh-pages
  git worktree add "$WORKTREE_DIR" gh-pages
fi

cd "$WORKTREE_DIR"
git fetch origin gh-pages
git checkout gh-pages
git reset --hard origin/gh-pages

rsync -a --delete "$BUILD_WEB_DIR"/ "$WORKTREE_DIR"/ --exclude=.git

git add -A
if git diff --cached --quiet; then
  echo "No changes to deploy."
  exit 0
fi

git commit -m "Deploy Flutter Web build/web from master"
git push origin gh-pages

echo "Deployed to gh-pages."
