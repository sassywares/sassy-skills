#!/usr/bin/env bash
# Shared helpers for the worktree scripts: create, list, remove.
#
# Installed next to those scripts by sassy-setup. Suite-owned and read-only, so
# every project runs the same mechanics. Three rules worth keeping:
#
#   1. One config source. The worktree home and the on/off switch live under
#      `worktrees:` in .sassywares/config.yaml; a stack's own start and stop steps
#      belong to the project's scripts, not to a key here. Never grow a second
#      source.
#   2. Identity is derived here once — never built by hand downstream.
#   3. Everything resolves against the MAIN checkout, so running any of these
#      from inside a worktree behaves identically.
#
# worktree-version: 13

set -euo pipefail

# shellcheck disable=SC2034  # read by every script that sources this file
WT_VERSION="13"

log()  { printf '%s\n' "$*"; }
ok()   { printf '  %-9s %s\n' "$1" "$2"; }
warn() { printf '  %-9s %s\n' "!" "$*" >&2; }
die()  { printf '  ✗ %s\n' "$*" >&2; exit 1; }
hint() { printf '  %-9s %s\n' "→" "$*"; }

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

# --- identity -------------------------------------------------------------
wt_slug() { printf '%s' "$1" | sed -E 's#[/ ]+#-#g; s#[^A-Za-z0-9._-]#-#g'; }

# A name safe for a database, a compose project, or a simulator: lowercase,
# no slashes, no dots.
wt_namespace() {
  printf '%s-%s' "$(basename "$MAIN")" "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's#[^a-z0-9]+#-#g; s#^-+##; s#-+$##'
}

# wt_print_env PATH BRANCH SLUG — the four `WT_*` lines a caller evaluates. One
# formatter: `create` mints an identity and `list --env` hands one back, so the
# two cannot drift apart. Nothing else goes on stdout when this runs.
wt_print_env() {
  # %q keeps a space in the path or a backtick in the branch from being read as
  # shell syntax when a caller evaluates the block. Simple values are unchanged.
  printf 'WT_PATH=%q\nWT_BRANCH=%q\nWT_SLUG=%q\nWT_NAMESPACE=%q\n' \
    "$1" "$2" "$3" "$(wt_namespace "$3")"
}

# The directory holding every worktree of this repo: one folder per checkout,
# under a home that survives a reboot. A second clone of the same project gets a
# suffixed folder instead of sharing this one.
wt_home() {
  local dir base cand parent owner
  dir="$(wt_cfg dir "$HOME/.sassywares/worktrees")"
  # The patterns are literal (case does not expand a tilde), so the strip below
  # removes the two characters the user wrote, not a home directory.
  # shellcheck disable=SC2088
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
# was committed — is not managed here: we do not list it or delete it.
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
