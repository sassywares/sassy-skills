#!/usr/bin/env bash
# Shared helpers for the workspace git scripts: branches, pull, checkout-bases.
#
# Installed next to those scripts by sassy-setup, and owned by this project from
# then on — extend it here rather than forking a copy. The one rule worth keeping
# is that the repo inventory and the PR bases come from `repos:` in
# .sassywares/config.yaml; never grow a second base map in this file.
#
# workspace-git-version: 1

set -euo pipefail

WORKSPACE_GIT_VERSION="1"

WS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$WS_DIR/../.." && pwd)"
CONFIG="$ROOT/.sassywares/config.yaml"
# Nested repos conventionally push to origin; override for a workspace that does not.
REMOTE="${WORKSPACE_GIT_REMOTE:-origin}"

log()  { printf '%s\n' "$*"; }
ok()   { printf '  ✓ %s\n' "$*"; }
warn() { printf '  ! %s\n' "$*" >&2; }
die()  { printf '  ✗ %s\n' "$*" >&2; exit 1; }

need_git() {
  command -v git >/dev/null 2>&1 || die "git not found"
}

[[ -f "$CONFIG" ]] || die "no config at $CONFIG — run sassy-setup"

# Print `<dir><TAB><base>` for every entry under `repos:`, in file order.
# Deliberately shallow: that one map, not a YAML parser.
workspace_repos() {
  awk '
    /^[[:space:]]*#/ { next }
    /^repos:[[:space:]]*$/ { in_repos = 1; next }
    !in_repos { next }
    /^[^[:space:]]/ { exit }
    /^[[:space:]]*$/ { next }
    {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      dir = line; sub(/:.*/, "", dir)
      base = line; sub(/^[^:]*:[[:space:]]*/, "", base); sub(/[[:space:]]+#.*$/, "", base)
      if (dir != "" && base != "") printf "%s\t%s\n", dir, base
    }
  ' "$CONFIG"
}

# Immediate children that are their own git repo but carry no `repos:` entry.
# A drift signal for `branches`: never a base inferred on the project's behalf.
unmapped_repos() {
  local path name mapped
  mapped="$(workspace_repos | cut -f1)"
  for path in "$ROOT"/*/; do
    name="$(basename "$path")"
    [[ "$name" == node_modules || "$name" == .* ]] && continue
    [[ -d "$path/.git" ]] || continue
    if ! printf '%s\n' "$mapped" | grep -Fxq -- "$name"; then
      printf '%s\n' "$name"
    fi
  done
}

repo_has_git() {
  [[ -d "$1/.git" ]]
}

current_branch() {
  git -C "$1" rev-parse --abbrev-ref HEAD 2>/dev/null
}

is_dirty() {
  [[ -n "$(git -C "$1" status --porcelain 2>/dev/null)" ]]
}

short_head() {
  git -C "$1" rev-parse --short HEAD 2>/dev/null
}

# The most useful line of captured git output: its first `error:`/`fatal:` line
# when there is one, else the last non-blank line. Git's advice blocks are noise
# in a one-line warn.
git_err() {
  local line
  line="$(printf '%s\n' "$1" | grep -m1 -E '^(error|fatal):' || true)"
  if [[ -n "$line" ]]; then
    printf '%s\n' "$line"
    return 0
  fi
  printf '%s\n' "$1" | grep -v '^[[:space:]]*$' | tail -n 1
}
