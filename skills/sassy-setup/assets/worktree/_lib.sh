#!/usr/bin/env bash
# Shared helpers for the worktree scripts: create, list, stop, remove, prune.
#
# Installed next to those scripts by sassy-setup, and owned by this project from
# then on — extend it here rather than forking a copy. Three rules worth keeping:
#
#   1. The worktree home, the port range, and the on/off switch come from
#      `worktrees:` in .sassywares/config.yaml. Never grow a second source.
#   2. A port is claimed, never assumed. The claim directory is the lock.
#   3. Everything resolves against the MAIN checkout, so running any of these
#      from inside a worktree behaves identically.
#
# worktree-version: 1

set -euo pipefail

WT_VERSION="1"
WT_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log()  { printf '%s\n' "$*"; }
ok()   { printf '  %-9s %s\n' "$1" "$2"; }
warn() { printf '  %-9s %s\n' "!" "$2" >&2; }
die()  { printf '  ✗ %s\n' "$*" >&2; exit 1; }
hint() { printf '  %-9s %s\n' "→" "$*"; }

need_git() {
  command -v git >/dev/null 2>&1 || die "git not found"
  local common
  common="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" \
    || die "not inside a git repository"
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
    }' "${CONFIG:-/dev/null}" 2>/dev/null
}

# wt_cfg KEY DEFAULT — a dotted path under the `worktrees:` block.
wt_cfg() {
  local v
  v="$(wt_flat | awk -F'\t' -v p="worktrees${WLIB_US}$1" '$1 == p { print $2; exit }')"
  printf '%s' "${v:-$2}"
}

wt_enabled() { [ "$(wt_cfg enabled false)" = "true" ]; }

# A list value (`[a b]`) split one per line.
wt_list_items() {
  printf '%s' "$1" | sed -e 's/^\[//' -e 's/\]$//' | tr ',' '\n' \
    | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s/^"//; s/"$//' | grep -v '^$' || true
}

# --- identity -------------------------------------------------------------
# The first match wins, so `hooks.worktree."*"` applies when no branch matches.
wt_hook() { # $1 point (after_create|before_remove), $2 branch — one entry per line
  local point="$1" branch="$2" v=""
  v="$(wt_flat | awk -F'\t' -v b="$branch" -v p="hooks${WLIB_US}worktree${WLIB_US}${branch}${WLIB_US}${point}" '$1 == p { print $2; exit }')"
  if [ -z "$v" ]; then
    v="$(wt_flat | awk -F'\t' -v p="hooks${WLIB_US}worktree${WLIB_US}*${WLIB_US}${point}" '$1 == p { print $2; exit }')"
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
  local dir base cand parent
  dir="$(wt_cfg dir "$HOME/.sassywares/worktrees")"
  case "$dir" in
    "~")   dir="$HOME" ;;
    "~/"*) dir="$HOME/${dir#\~/}" ;;
    /*)    ;;
    *)     dir="$MAIN/$dir" ;;
  esac
  # Resolve through the parent, so /tmp and /private/tmp never disagree and the
  # paths match what `git worktree list` reports.
  parent="$(dirname "$dir")"
  [ -d "$parent" ] && dir="$(cd "$parent" && pwd -P)/$(basename "$dir")"
  base="$(basename "$MAIN")"
  cand="$dir/$base"
  if [ -f "$cand/.repo" ] && [ "$(cat "$cand/.repo" 2>/dev/null)" != "$MAIN" ]; then
    cand="$dir/$base-$(printf '%s' "$MAIN" | shasum -a 256 | cut -c1-6)"
  fi
  printf '%s' "$cand"
}

wt_path() { printf '%s/%s' "$(wt_home)" "$1"; }

# --- ports ----------------------------------------------------------------
wt_range() {
  local r lo hi
  r="$(wt_cfg ports 3000-3099)"
  case "$r" in
    *-*) lo="${r%%-*}"; hi="${r##*-}" ;;
    *)   lo="$r"; hi="$r" ;;
  esac
  case "$lo$hi" in *[!0-9]*) die "worktrees.ports '$r' is not <from>-<to>" ;; esac
  [ "$lo" -le "$hi" ] || die "worktrees.ports '$r' has an empty range"
  printf '%s %s' "$lo" "$hi"
}

# tcp_up PORT — 0 when something accepts a connection on loopback.
# Liveness is observed, never read from a state file: a killed preview leaves no
# trace to go stale. The probe runs in a subshell so a successful connect cannot
# leave a descriptor (or a fatal `exec`) behind in the caller.
tcp_up() {
  (exec 3<>"/dev/tcp/127.0.0.1/$1") >/dev/null 2>&1
}

wt_claim_dir() { printf '%s/ports/%s' "$(wt_home)" "$1"; }

# wt_owner PORT — the slug that claimed a port, or empty.
wt_owner() {
  local f
  f="$(wt_claim_dir "$1")/owner"
  [ -f "$f" ] && cat "$f" 2>/dev/null || true
}

# wt_claim SLUG — print the port this slug owns, claiming one when needed.
# Deterministic first (a restarted preview comes back on the same port), then a
# linear probe so two slugs that hash alike do not fight.
# wt_port_for SLUG — the port this slug uses: an existing claim, else the derived
# one probed forward past claims held by others. Read-only, so `list` may call it.
wt_port_for() {
  local slug="$1" lo hi span i port owner hex d
  read -r lo hi <<<"$(wt_range)"
  for d in "$(wt_home)/ports"/*; do
    [ -d "$d" ] || continue
    if [ "$(cat "$d/owner" 2>/dev/null)" = "$slug" ]; then
      basename "$d"
      return 0
    fi
  done
  span=$(( hi - lo + 1 ))
  hex="$(printf '%s' "$slug" | shasum -a 256 | cut -c1-8)"
  i=$(( 16#$hex % span ))
  port=$(( lo + i ))
  while :; do
    owner="$(wt_owner "$port")"
    if [ -z "$owner" ] || [ "$owner" = "$slug" ]; then
      printf '%s' "$port"
      return 0
    fi
    port=$(( port + 1 ))
    [ "$port" -gt "$hi" ] && port=$lo
    i=$(( i + 1 ))
    [ "$i" -gt "$span" ] && die "no free port in $(wt_range | sed 's/ /-/')"
  done
}

# wt_claim SLUG — claim and print the port, writing the lock directory.
wt_claim() {
  local slug="$1" port
  port="$(wt_port_for "$slug")"
  mkdir -p "$(wt_claim_dir "$port")"
  printf '%s' "$slug" > "$(wt_claim_dir "$port")/owner"
  printf '%s' "$port"
}

wt_release() { # $1 port, $2 slug
  local d
  d="$(wt_claim_dir "$1")"
  [ "$(wt_owner "$1")" = "$2" ] && rm -rf "$d"
  return 0
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

wt_require() { # $1 slug or branch -> path<TAB>branch, or die
  local rec
  rec="$(wt_find "$1")"
  [ -n "$rec" ] || die "no worktree for '$1' (try: list)"
  printf '%s' "$rec"
}

wt_is_main() { [ "$(cd "$1" && pwd -P)" = "$MAIN" ]; }

wt_dirty() { [ -n "$(git -C "$1" status --porcelain 2>/dev/null)" ]; }

# Commits that exist only here: ahead of the upstream, or — with none — reachable
# from no remote at all.
wt_unpushed() {
  local p="$1" up n
  up="$(git -C "$p" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
  if [ -n "$up" ]; then
    n="$(git -C "$p" rev-list --count "$up..HEAD" 2>/dev/null || echo unknown)"
  else
    n="$(git -C "$p" rev-list --count HEAD --not --remotes 2>/dev/null || echo unknown)"
  fi
  printf '%s' "${n:-0}"
}

wt_upstream_state() { # merged | gone | unmerged
  local p="$1" up
  up="$(git -C "$p" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
  if [ -z "$up" ]; then
    printf 'gone'
  elif git -C "$p" merge-base --is-ancestor HEAD "$up" 2>/dev/null; then
    printf 'merged'
  else
    printf 'unmerged'
  fi
}

# Newest dogfood verdict for a checkout, as `status  class` — or empty.
wt_verdict() {
  local dir="$1/.sassywares/dogfood/reports" newest s c
  [ -d "$dir" ] || return 0
  newest="$(ls -1t "$dir" 2>/dev/null | head -n 1)"
  [ -n "$newest" ] || return 0
  s="$(sed -n 's/^\*\*status:\*\* //p' "$dir/$newest/summary.md" 2>/dev/null | head -n 1)"
  c="$(sed -n 's/^\*\*class:\*\* //p' "$dir/$newest/summary.md" 2>/dev/null | head -n 1)"
  printf '%s%s' "${s:-unknown}" "$( [ -n "$c" ] && printf '  %s' "$c" )"
}
