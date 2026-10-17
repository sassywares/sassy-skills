#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="$REPO/skills"
TARGET="${SASSY_SKILLS_LINK:-$HOME/.agents/skills}"
LOCK_DIR="${TMPDIR:-/tmp}/sassy-skills-sync.lock"

# Avoid overlapping runs when the watcher and a manual sync fire together.
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  exit 0
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT

# Keep the single directory symlink healthy. Never replace a real directory.
mkdir -p "$(dirname "$TARGET")"
if [ -L "$TARGET" ]; then
  ln -sfn "$SKILLS_DIR" "$TARGET"
elif [ -e "$TARGET" ]; then
  echo "sassy-skills: $TARGET exists and is not a symlink; leaving it alone" >&2
else
  ln -s "$SKILLS_DIR" "$TARGET"
fi

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
