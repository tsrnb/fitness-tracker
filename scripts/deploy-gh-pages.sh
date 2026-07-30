#!/usr/bin/env bash
# Builds the Flutter web app and publishes flutter_app/build/web to the
# gh-pages branch, keeping it isolated from master via a git worktree.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKTREE_DIR="$REPO_ROOT/.gh-pages-worktree"
BUILD_WEB_DIR="$REPO_ROOT/flutter_app/build/web"

cd "$REPO_ROOT/flutter_app"
# secrets.json (git-ignored, see secrets.example.json) holds AI_PROXY_URL
# and AI_PROXY_CLIENT_KEY for the "Ask AI" food-logging feature — these
# point at the Cloudflare Worker in cf-worker/, which is the only thing
# that ever holds the real OPENAI_API_KEY. A raw OpenAI key baked into this
# bundle would be scraped from the public gh-pages site and auto-revoked by
# OpenAI's own leaked-key scanning (it happened twice), so it can never live
# here — see cf-worker/README.md to deploy the proxy.
if [ -f secrets.json ]; then
  flutter build web --base-href /fitness-tracker/ --dart-define-from-file=secrets.json
else
  echo "secrets.json not found — building without it, Ask AI will be unconfigured. See secrets.example.json." >&2
  flutter build web --base-href /fitness-tracker/
fi
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
