#!/usr/bin/env bash
# Commit and push this repo. Skills reach harnesses as the published package
# `@sassywares/skills`, so there is no global link to maintain here.
#
# Consumers pin a version:
#   project  bun add -d @sassywares/skills@x.y.z
#   pi user  pi install npm:@sassywares/skills@x.y.z
# While editing, point a consumer at this checkout with `bun link @sassywares/skills`
# (or add `.pi/settings.json` with `skills: ["./skills"]` when working in this repo).
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCK_DIR="${TMPDIR:-/tmp}/sassy-skills-sync.lock"

# Avoid overlapping runs when several agents sync at the same time.
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  exit 0
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT

cd "$REPO"

if [ ! -d .git ]; then
  echo "sassy-skills: $REPO is not a git repository" >&2
  exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
  git add -A
  git commit -m "chore: sync skills $(date -u +%Y-%m-%dT%H:%M:%SZ)" >/dev/null
fi

if git remote get-url origin >/dev/null 2>&1; then
  branch="$(git symbolic-ref --short HEAD 2>/dev/null || echo main)"

  if ! git push origin "$branch" >/dev/null 2>&1; then
    git pull --rebase --autostash origin "$branch" >/dev/null 2>&1 || true
    git push origin "$branch" >/dev/null 2>&1 || true
  fi
fi
