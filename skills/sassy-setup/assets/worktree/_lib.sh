#!/usr/bin/env bash
# Shared helpers for the worktree scripts: create, list, remove, prune.
#
# Installed next to those scripts by sassy-setup. Suite-owned and read-only, so
# every project runs the same mechanics. Three rules worth keeping:
#
#   1. Two config sources, each with exactly one owner. The worktree home and the
#      on/off switch live under `worktrees:` in .sassywares/config.yaml; the stack
#      life cycle is the top-level `down:`/`up:`. Never duplicate either one into
#      the other block, and never grow a third source.
#   2. Identity is derived here once — never built by hand downstream.
#   3. Everything resolves against the MAIN checkout, so running any of these
#      from inside a worktree behaves identically.
#
# worktree-version: 12

set -euo pipefail

WT_VERSION="12"
WT_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log()  { printf '%s\n' "$*"; }
ok()   { printf '  %-9s %s\n' "$1" "$2"; }
warn() { printf '  %-9s %s\n' "!" "$*" >&2; }
die()  { printf '  ✗ %s\n' "$*" >&2; exit 1; }
hint() { printf '  %-9s %s\n' "→" "$*"; }
# The exit-3 handshake: something the script cannot dispatch is still owed, and
# the caller has to run it before re-invoking with --hook-ok.
require_dispatch() {
  hint "$1" >&2
  exit 3
}

# The nearest config, walking up from the cwd — used only to explain a refusal
# when there is no repo to work in at all.
wt_find_config() {
  local dir
  dir="$(pwd -P)"
  while :; do
    if [ -f "$dir/.sassywares/config.yaml" ]; then
      printf '%s' "$dir/.sassywares/config.yaml"
      return 0
    fi
    [ "$dir" = "/" ] && return 1
    dir="$(dirname "$dir")"
  done
}

need_git() {
  command -v git >/dev/null 2>&1 || die "git not found"
  local common found cfg_repo
  common="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
  if [ -z "$common" ]; then
    # No repo here. A workspace root is that way on purpose, so say why instead of
    # failing as if the directory were wrong.
    found="$(wt_find_config || true)"
    if [ -n "$found" ]; then
      cfg_repo="$(wt_flat "$found" | awk -F'\t' -v p="git${WLIB_US}repo" '$1 == p { print $2; exit }')"
      case "$cfg_repo" in
        workspace|none)
          die "worktrees need the repo topology — git.repo is '$cfg_repo' here; a nested repo carries its own config"
          ;;
      esac
    fi
    die "not inside a git repository"
  fi
  # The common dir is shared by every worktree; its parent is the main checkout.
  MAIN="$(cd "$common/.." && pwd -P)"
  CONFIG="$MAIN/.sassywares/config.yaml"
}

# --- config ---------------------------------------------------------------
# Flattened to `path<TAB>value`, the same reader sassy-setup's detect.sh uses,
# so a nested map has exactly one interpretation across the suite.
WLIB_US=$'\037'
wt_flat() {
  awk -v us="$(printf '\037')" '
    function ind(s,  m) { m = match(s, /^ */); return m ? RLENGTH : 0 }
    {
      line = $0; sub(/#.*$/, "", line)
      if (line ~ /^[[:space:]]*$/) next
      d = ind(line)
      body = line; sub(/^[[:space:]]*/, "", body); sub(/[[:space:]]+$/, "", body)
      if (body ~ /:$/) {
        key = body; sub(/:$/, "", key); gsub(/"/, "", key)
        while (sp > 0 && sd[sp] >= d) sp--
        sd[++sp] = d; sk[sp] = key
        next
      }
      if (body !~ /:/) next
      key = body; sub(/:.*/, "", key); gsub(/"/, "", key)
      val = body; sub(/^[^:]*:[[:space:]]*/, "", val); gsub(/^"|"$/, "", val)
      path = ""
      for (i = 1; i <= sp; i++) if (sd[i] < d) path = path (path == "" ? "" : us) sk[i]
      print path (path == "" ? "" : us) key "\t" val
    }' "${1:-${CONFIG:-/dev/null}}" 2>/dev/null
}

# wt_get PATH — the value of one flattened config path, or empty. The one lookup
# every reader uses, so a nested map has exactly one interpretation.
wt_get() {
  wt_flat | awk -F'\t' -v p="$1" '$1 == p { print $2; exit }'
}

# wt_cfg KEY DEFAULT — a dotted path under the `worktrees:` block.
wt_cfg() {
  local v
  v="$(wt_get "worktrees${WLIB_US}$1")"
  printf '%s' "${v:-$2}"
}

wt_enabled() { [ "$(wt_cfg enabled false)" = "true" ]; }

# wt_down — the top-level `down:` entry, exactly as written, or empty when the
# project declares no lifecycle. Top-level by design (never under `worktrees:`).
wt_down() { wt_get down; }

# wt_resolve VALUE CHECKOUT — how to run one top-level life-cycle value, as
# `<run|skill|missing|none><TAB><command><TAB><args…>`. `run` means the command
# exists — a path in the checkout, an absolute path, or a word on PATH — so a
# shell script can execute it; `skill` means nothing on disk claims the word, so
# only an agent can dispatch it; `missing` means the value is path-shaped but no
# such executable exists; `none` means the value is empty. Args are command
# words, not patterns: callers disable globbing before expanding them.
wt_resolve() {
  local value="${1:-}" checkout="${2:-}" cmd="" args="" how=skill
  [ -n "$value" ] || { printf 'none\t\t'; return 0; }
  cmd="${value%% *}"
  case "$value" in *" "*) args="${value#* }" ;; esac
  case "$cmd" in
    /*)  if [ -f "$cmd" ] && [ -x "$cmd" ]; then how=run; else how=missing; fi ;;
    */*) if [ -f "$checkout/$cmd" ] && [ -x "$checkout/$cmd" ]; then how=run; else how=missing; fi ;;
    *)   command -v "$cmd" >/dev/null 2>&1 && how=run ;;
  esac
  printf '%s\t%s\t%s' "$how" "$cmd" "$args"
}

# A list value (`[a b]`) split one per line.
wt_list_items() {
  printf '%s' "$1" | sed -e 's/^\[//' -e 's/\]$//' | tr ',' '\n' \
    | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s/^"//; s/"$//' | grep -v '^$' || true
}

# --- identity -------------------------------------------------------------
# The first match wins, so `hooks.worktree."*"` applies when no branch matches.
wt_hook() { # $1 point (after_create|before_remove), $2 branch — one entry per line
  local point="$1" branch="$2" v=""
  v="$(wt_get "hooks${WLIB_US}worktree${WLIB_US}${branch}${WLIB_US}${point}")"
  if [ -z "$v" ]; then
    v="$(wt_get "hooks${WLIB_US}worktree${WLIB_US}*${WLIB_US}${point}")"
  fi
  wt_list_items "$v"
}

wt_slug() { printf '%s' "$1" | sed -E 's#[/ ]+#-#g; s#[^A-Za-z0-9._-]#-#g'; }

# A name safe for a database, a compose project, or a simulator: lowercase,
# no slashes, no dots.
wt_namespace() {
  printf '%s-%s' "$(basename "$MAIN")" "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's#[^a-z0-9]+#-#g; s#^-+##; s#-+$##'
}

# The directory holding every worktree of this repo: one folder per checkout,
# under a home that survives a reboot. A second clone of the same project gets a
# suffixed folder instead of sharing this one.
wt_home() {
  local dir base cand parent owner
  dir="$(wt_cfg dir "$HOME/.sassywares/worktrees")"
  case "$dir" in
    "~")   dir="$HOME" ;;
    "~/"*) dir="$HOME/${dir#\~/}" ;;
    /*)    ;;
    *)     dir="$MAIN/$dir" ;;
  esac
  # Resolve through the parent, so /tmp and /private/tmp never disagree and the
  # paths match what `git worktree list` prints.
  parent="$(dirname "$dir")"
  [ -d "$parent" ] && dir="$(cd "$parent" && pwd -P)/$(basename "$dir")"
  base="$(basename "$MAIN")"
  cand="$dir/$base"
  if [ -f "$cand/.repo" ]; then
    owner="$(cat "$cand/.repo" 2>/dev/null || true)"
    # Only a live checkout squats the plain name; a deleted one is reclaimed, so a
    # finished project does not leave a hash-suffixed home behind forever.
    if [ "$owner" != "$MAIN" ] && [ -n "$owner" ] && [ -d "$owner" ]; then
      cand="$dir/$base-$(printf '%s' "$MAIN" | shasum -a 256 | cut -c1-6)"
    fi
  fi
  printf '%s' "$cand"
}

wt_path() { printf '%s/%s' "$(wt_home)" "$1"; }

# --- display --------------------------------------------------------------
# short_path PATH WIDTH — keep the tail of a long path, because the tail holds the
# slug and the start is always the same worktree home.
short_path() {
  local s="$1" w="$2"
  if [ "${#s}" -gt "$w" ]; then printf '…%s' "${s: -$(( w - 1 ))}"; else printf '%s' "$s"; fi
}

# --- checkouts ------------------------------------------------------------
# Emits one record per worktree: path<TAB>branch.
wt_all() {
  git worktree list --porcelain | awk '
    /^worktree /{ p = $2 }
    /^branch /  { b = $2; sub(/^refs\/heads\//, "", b); print p "\t" b; p = ""; b = "" }
    /^detached/ { print p "\t(detached)"; p = "" }
  '
}

wt_find() { # $1 slug or branch -> path<TAB>branch, or nothing
  local want="$1" p b
  while IFS=$'\t' read -r p b; do
    [ -n "$p" ] || continue
    if [ "$b" = "$want" ] || [ "$(wt_slug "$b")" = "$want" ]; then
      printf '%s\t%s' "$p" "$b"
      return 0
    fi
  done < <(wt_all)
}

# A checkout is ours when it lives under this repo's worktree home AND carries
# the wiring. Anything else — another tool's worktree, or one cut before setup
# was committed — is not managed here: we do not list it, prune it, or delete it.
wt_managed() { # $1 path
  case "$1" in
    "$(wt_home)"/*) [ -f "$1/.sassywares/config.yaml" ] ;;
    *) return 1 ;;
  esac
}

wt_require_managed() { # $1 slug or branch -> path<TAB>branch, or die
  local rec
  # `wt_require` dies inside the substitution, where its exit cannot reach us, so
  # a failure has to be carried out by hand or the caller prints a second, wrong
  # message ("not managed here" for a branch that does not exist at all).
  rec="$(wt_require "$1")" || exit 1
  wt_managed "${rec%%$'\t'*}" \
    || die "'$1' is not managed here — it is outside the worktree home, or it was cut before the wiring"
  printf '%s' "$rec"
}

wt_require() { # $1 slug or branch -> path<TAB>branch, or die
  local rec
  rec="$(wt_find "$1")"
  [ -n "$rec" ] || die "no worktree for '$1' (try: list)"
  printf '%s' "$rec"
}

wt_is_main() { [ "$(cd "$1" && pwd -P)" = "$MAIN" ]; }

wt_dirty() { [ -n "$(git -C "$1" status --porcelain 2>/dev/null)" ]; }

# The ref a checkout's branch tracks, or empty. Read-only, and never a guess:
# `create` prints this instead of deciding what a branch should follow.
wt_upstream() {
  git -C "$1" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true
}

# Commits that exist only here: ahead of the upstream, or — with none — reachable
# from no remote at all.
wt_unpushed() {
  local p="$1" up n
  up="$(wt_upstream "$p")"
  if [ -n "$up" ]; then
    n="$(git -C "$p" rev-list --count "$up..HEAD" 2>/dev/null || echo unknown)"
  else
    n="$(git -C "$p" rev-list --count HEAD --not --remotes 2>/dev/null || echo unknown)"
  fi
  printf '%s' "${n:-0}"
}

wt_upstream_state() { # merged | gone | unmerged
  local p="$1" up
  up="$(wt_upstream "$p")"
  if [ -z "$up" ]; then
    printf 'gone'
  elif git -C "$p" merge-base --is-ancestor HEAD "$up" 2>/dev/null; then
    printf 'merged'
  else
    printf 'unmerged'
  fi
}
