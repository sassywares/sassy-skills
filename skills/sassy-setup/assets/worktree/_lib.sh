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
# worktree-version: 7

set -euo pipefail

WT_VERSION="7"
WT_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log()  { printf '%s\n' "$*"; }
ok()   { printf '  %-9s %s\n' "$1" "$2"; }
warn() { printf '  %-9s %s\n' "!" "$2" >&2; }
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
  local dir base cand parent owner
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

# --- resources ------------------------------------------------------------
# A port is one resource a checkout may need, not the definition of a preview. A
# mobile app claims a simulator, a desktop app nothing, and both are legitimate:
# when `worktrees.ports` is absent nothing is derived and nothing is claimed.
wt_has_ports() { [ -n "$(wt_cfg ports '')" ]; }

wt_range() {
  local r lo hi
  r="$(wt_cfg ports '')"
  [ -n "$r" ] || return 0
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
  local port="$1"
  # IPv4, then IPv6: a dev server that binds `[::1]` only is up, and an IPv4-only
  # probe reads it as down — which would make `LIVE` lie and `remove`'s
  # live-preview refusal unreachable.
  if (exec 3<>"/dev/tcp/127.0.0.1/$port") >/dev/null 2>&1; then return 0; fi
  if (exec 3<>"/dev/tcp/::1/$port") >/dev/null 2>&1; then return 0; fi
  # Last resort for a listener /dev/tcp cannot reach.
  if command -v lsof >/dev/null 2>&1 && lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

# short_path PATH WIDTH — keep the tail of a long path, because the tail holds the
# slug and the start is always the same worktree home.
short_path() {
  local s="$1" w="$2"
  if [ "${#s}" -gt "$w" ]; then printf '…%s' "${s: -$(( w - 1 ))}"; else printf '%s' "$s"; fi
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
  wt_has_ports || return 0
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

# wt_subst LINE NAME VALUE — expand `$NAME`, `${NAME}` and `${NAME:-default}` for
# one variable. No name here is a prefix of another, so a plain replace is exact.
wt_subst() {
  local line="$1" name="$2" val="$3"
  if [ -n "$val" ]; then
    printf '%s' "$line" \
      | sed -e "s|\${$name:-[^}]*}|$val|g" -e "s|\${$name}|$val|g" -e "s|\$$name|$val|g"
  else
    printf '%s' "$line" \
      | sed -e "s|\${$name:-\([^}]*\)}|\1|g" -e "s|\${$name}||g" -e "s|\$$name||g"
  fi
}

# _wt_preview_block RECIPE [SECTION] — the `**Preview:**` block, joined to one line.
# With no section it reads only what sits *before* the first `## ` heading, so a
# nested recipe's first app cannot masquerade as the file-level address.
_wt_preview_block() {
  awk -v want="${2:-}" '
    /^## / {
      if (want == "") exit
      s = $0; sub(/^## +/, "", s); split(s, pr, /[ \t]+/); cur = pr[1]; inb = 0; next
    }
    want != "" && cur != want { next }
    /^\*\*Preview:\*\*/ { sub(/^\*\*Preview:\*\*[[:space:]]*/, ""); buf = $0; inb = 1; next }
    inb && /^[[:space:]]*$/ { inb = 0; next }
    inb && /^\*\*/ { inb = 0; next }
    inb { buf = buf " " $0 }
    END { printf "%s", buf }
  ' "$1" | sed -E 's/[[:space:]]+/ /g; s/[[:space:]]+$//'
}

# wt_preview SLUG [SECTION] — how to see this checkout, substituted.
# A section's own line wins when one is asked for; otherwise the file-level line is
# the checkout's address. With no file-level line and exactly one section, that
# section is the answer; with several, nothing is returned rather than guessing which
# app a checkout is serving.
wt_preview() {
  local slug="$1" sect="${2:-}" recipe line="" cand count sl port base
  recipe="$(wt_flat | awk -F'\t' -v p="dogfood${WLIB_US}recipe" '$1 == p { print $2; exit }')"
  recipe="${recipe:-.sassywares/dogfood/recipe.md}"
  case "$recipe" in /*) ;; *) recipe="$MAIN/$recipe" ;; esac
  [ -f "$recipe" ] || return 0
  if [ -n "$sect" ]; then line="$(_wt_preview_block "$recipe" "$sect")"; fi
  if [ -z "$line" ]; then line="$(_wt_preview_block "$recipe" "")"; fi
  if [ -z "$line" ]; then
    # Fall back to the single section that *declares* an address. Counting sections
    # would fail on a recipe with one app and one uncovered surface, which is a
    # perfectly ordinary shape: only the app has somewhere to look.
    count=0; cand=""
    while IFS= read -r sl; do
      [ -n "$sl" ] || continue
      cand="$(_wt_preview_block "$recipe" "$sl")"
      [ -n "$cand" ] || continue
      count=$((count + 1))
      line="$cand"
    done < <(sed -n 's/^## \([^ 	]*\).*/\1/p' "$recipe")
    [ "$count" -eq 1 ] || line=""
  fi
  [ -n "$line" ] || return 0
  port=""
  if wt_has_ports; then
    port="$(wt_port_for "$slug")"
    base="http://localhost:$port"
  fi
  line="$(wt_subst "$line" WT_SLUG "$slug")"
  line="$(wt_subst "$line" WT_NAMESPACE "$(wt_namespace "$slug")")"
  line="$(wt_subst "$line" WT_PATH "$(wt_path "$slug")")"
  line="$(wt_subst "$line" WT_PORT "$port")"
  line="$(wt_subst "$line" WT_BASE_URL "$base")"
  printf '%s' "$line"
}

# wt_preview_port SLUG — the port the preview line advertises, if it names one.
# A project with no `worktrees.ports` still has an address; this is how the tools
# find it without assuming a browser or a claim.
wt_preview_port() {
  local line
  line="$(wt_preview "$1")"
  [ -n "$line" ] || return 0
  printf '%s' "$line" \
    | grep -oE '(localhost|127\.0\.0\.1):[0-9]+' | head -n 1 | grep -oE '[0-9]+$'
}

# wt_live_port SLUG — where to probe this checkout: its claim if it has one, else
# the port its preview advertises. Empty means "nothing to probe here".
wt_live_port() {
  local slug="$1" p
  if wt_has_ports; then
    p="$(wt_port_for "$slug")"
    [ -n "$p" ] && { printf '%s' "$p"; return 0; }
  fi
  wt_preview_port "$slug"
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
