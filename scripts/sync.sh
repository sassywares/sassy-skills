#!/usr/bin/env bash
# Commit, version, push, and tag this repo in one step.
#
# Consumers install from this repo:
#   npx skills add sassywares/sassy-skills     # vendor into .agents/skills + skills-lock.json
#   npx skills update                          # pull the latest after a push
# Working in this repo, `.pi/settings.json` already loads `./skills`.
#
# The npm package `@sassywares/skills` is a secondary channel, and publishing is
# tag-driven. A push that changed shipped content without a tag left npm behind
# main, so this script owns the whole release: it bumps the patch version when
# shipped content changed, commits, pushes main, then tags and pushes the tag.
# Tagging is mandatory — a bumped but untagged version is a release that
# silently never happened.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCK_DIR="${TMPDIR:-/tmp}/sassy-skills-sync.lock"

# Paths that reach consumers. A change here needs a version; a change to
# tooling, CI, or docs outside `package.json#files` does not.
PUBLISHED_PATHS=(skills README.md CONCEPTS.md LICENSE package.json)

die() {
  echo "sassy-skills: $*" >&2
  exit 1
}

# Avoid overlapping runs when several agents sync at the same time.
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  echo "sassy-skills: another sync is running, skipping" >&2
  exit 0
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT

cd "$REPO"
[ -d .git ] || die "$REPO is not a git repository"

pkg_version() {
  node -p "require('./package.json').version"
}

tag_exists() {
  git rev-parse -q --verify "refs/tags/v$1" >/dev/null 2>&1
}

# True when shipped content differs from what the given version released.
published_drift() {
  local tag="v$1"
  [ -n "$(git diff --name-only "$tag" -- "${PUBLISHED_PATHS[@]}" 2>/dev/null || true)" ] && return 0
  [ -n "$(git ls-files --others --exclude-standard -- skills 2>/dev/null || true)" ] && return 0
  return 1
}

branch="$(git symbolic-ref --short HEAD 2>/dev/null || echo HEAD)"

release=""

# Releasing only happens on main: a tag published off a feature branch would
# ship unmerged content to npm. Branch work is committed and pushed only.
if [ "$branch" = "main" ]; then
  version="$(pkg_version)"

  if tag_exists "$version"; then
    # The current version is already released. Ship a new one only if something
    # consumers receive has changed since that tag.
    if published_drift "$version"; then
      npm version patch --no-git-tag-version >/dev/null
      release="$(pkg_version)"
    fi
  else
    # A bump landed without its tag (an interrupted run, or a hand-written bump).
    # Tag what is already there instead of bumping again.
    release="$version"
  fi
fi

if [ -n "$(git status --porcelain)" ]; then
  git add -A
  message="chore: sync skills $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  [ -z "$release" ] || message="$message (v$release)"
  git commit -m "$message" >/dev/null
fi

if git remote get-url origin >/dev/null 2>&1; then
  pushed=1
  if ! git push origin "$branch" >/dev/null 2>&1; then
    git pull --rebase --autostash origin "$branch" >/dev/null 2>&1 || true
    git push origin "$branch" >/dev/null 2>&1 || pushed=0
  fi
  [ "$pushed" = 1 ] || die "could not push $branch; the commit is local and the next sync retries"

  if [ -n "$release" ]; then
    tag_exists "$release" || git tag -a "v$release" -m "v$release"
    git push origin "v$release" >/dev/null 2>&1 || die "could not push tag v$release"
    git ls-remote --tags origin "refs/tags/v$release" 2>/dev/null | grep -q . \
      || die "tag v$release is not on origin after pushing"
  fi
else
  [ -z "$release" ] || die "no origin remote; v$release is committed locally but not released"
fi

if [ -n "$release" ]; then
  echo "sassy-skills: released v$release"
elif [ "$branch" != "main" ]; then
  echo "sassy-skills: synced $branch, release happens on main"
else
  echo "sassy-skills: synced, nothing to release"
fi
