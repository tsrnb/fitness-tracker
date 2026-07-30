#!/usr/bin/env bash
# Builds the Flutter web app and publishes flutter_app/build/web to the
# gh-pages branch, keeping it isolated from master via a git worktree.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKTREE_DIR="$REPO_ROOT/.gh-pages-worktree"
BUILD_WEB_DIR="$REPO_ROOT/flutter_app/build/web"

cd "$REPO_ROOT/flutter_app"
# secrets.json (git-ignored, see secrets.example.json) holds OPENAI_API_KEY
# for the "Ask AI" food-logging feature — --dart-define-from-file keeps it
# out of shell history and out of the repo, at the cost of it still ending
# up readable in the compiled web bundle, which is why this app is only
# ever shared with people who already have the link, not linked publicly.
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
