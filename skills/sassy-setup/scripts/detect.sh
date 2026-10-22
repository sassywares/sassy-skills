#!/usr/bin/env bash
# Detect project topology and emit a proposed .sassywares/config.yaml.
#
# Read-only. Writes nothing. sassy-setup runs this, asks the few questions the
# detection cannot answer, then writes the file itself.
#
# Usage:
#   detect.sh [--root DIR]            print a proposed config to stdout
#   detect.sh [--root DIR] --check    compare the existing config to reality
set -euo pipefail

ROOT_ARG=""
HEAD_ARG=""
CHECK=0

while (( $# )); do
  case "$1" in
    --root)   shift; [[ $# -ge 1 ]] || { echo "missing DIR after --root" >&2; exit 2; }; ROOT_ARG="$1" ;;
    --root=*) ROOT_ARG="${1#*=}" ;;
    --head)   shift; [[ $# -ge 1 ]] || { echo "missing BRANCH after --head" >&2; exit 2; }; HEAD_ARG="$1" ;;
    --head=*) HEAD_ARG="${1#*=}" ;;
    --check)  CHECK=1 ;;
    -h|--help) sed -n '2,10p' "${BASH_SOURCE[0]}" | sed 's|^# \{0,1\}||'; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

START="${ROOT_ARG:-$PWD}"
[[ -d "$START" ]] || { echo "not a directory: $START" >&2; exit 2; }
# Absolute, or the walk-up loop below re-reads "." forever.
START="$(cd "$START" && pwd -P)"

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ASSET_SNAPSHOT="$SKILL_DIR/assets/snapshot"

# The nearest config wins, walking up. Report where it is if one exists.
CONFIG=""
probe="$START"
while :; do
  if [[ -f "$probe/.sassywares/config.yaml" ]]; then CONFIG="$probe/.sassywares/config.yaml"; break; fi
  [[ "$probe" == "/" ]] && break
  probe="$(dirname "$probe")"
done

# A --check run validates the config against the tree the CONFIG describes, which
# is not the git toplevel when you are standing inside one of its nested repos.
if [[ -n "$CONFIG" ]]; then
  ROOT="${CONFIG%/.sassywares/config.yaml}"
  if git -C "$ROOT" rev-parse --show-toplevel >/dev/null 2>&1; then
    TOPOLOGY="repo"
  else
    TOPOLOGY="workspace"
    shopt -s nullglob
    NESTED_FOUND=0
    for child in "$ROOT"/*/; do
      [[ -d "$child/.git" ]] && { NESTED_FOUND=1; break; }
    done
    shopt -u nullglob
    [[ "$NESTED_FOUND" -eq 1 ]] || TOPOLOGY="none"
  fi
# Topology root: the git toplevel when inside a work tree, else the start dir.
elif TOPLEVEL="$(git -C "$START" rev-parse --show-toplevel 2>/dev/null)"; then
  ROOT="$TOPLEVEL"
  TOPOLOGY="repo"
else
  ROOT="$(cd "$START" && pwd -P)"
  TOPOLOGY="workspace"
  # No nested repos below means there is nothing for a workspace to hold.
  shopt -s nullglob
  NESTED_FOUND=0
  for child in "$ROOT"/*/; do
    if [[ -d "$child/.git" ]]; then NESTED_FOUND=1; break; fi
  done
  shopt -u nullglob
  [[ "$NESTED_FOUND" -eq 1 ]] || TOPOLOGY="none"
fi

config_value() {
  local key="$1" file="${2:-$CONFIG}"
  [[ -f "$file" ]] || return 1
  sed -n "s/^[[:space:]]*${key}:[[:space:]]*//p" "$file" \
    | head -n 1 \
    | sed -E 's/[[:space:]]+#.*$//; s/^["'\'']//; s/["'\'']$//' \
    | grep -v '^$' || return 1
}

block_value() { # $1 block name, $2 key — value only, comments stripped
  sed -n "/^$1:/,/^[a-z]/p" "$CONFIG" \
    | sed -n "s/^[[:space:]]\{1,\}$2:[[:space:]]*//p" \
    | head -n 1 \
    | sed -E 's/[[:space:]]+#.*$//; s/[[:space:]]+$//'
}

# Base branch for one repo. Empty output means unknown — never guessed.
hook_skill_path() { # $1 hook skill name — nearest .agents/skills/<name>/SKILL.md
  local name="$1" dir="$ROOT"
  while :; do
    if [[ -f "$dir/.agents/skills/$name/SKILL.md" ]]; then
      printf '%s' "$dir/.agents/skills/$name/SKILL.md"
      return 0
    fi
    [[ "$dir" == "/" ]] && return 1
    dir="$(dirname "$dir")"
  done
}

# --- config readers -------------------------------------------------------
# The file is flattened to `path<TAB>value` with paths joined by unit separators,
# which is enough to read the two nested maps we own (git.base_map, hooks.pr.*).
US=$'\037'

yaml_flat() {
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
    }' "$CONFIG"
}

yflat() { yaml_flat | awk -F'\t' -v p="$1" '$1 == p { print $2; exit }'; }

list_items() {
  printf '%s' "$1" | sed -e 's/^\[//' -e 's/\]$//' | tr ',' '\n' \
    | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s/^"//; s/"$//' | grep -v '^$' || true
}

# map_match SECTION HEAD — exact key, then the longest matching family, then "*".
# base_map uses it, and hooks use the same rule, so "which pattern applies" has
# exactly one answer in the whole config.
map_match() {
  local section="$1" head="$2" pat stem best="" bestlen=0 v
  v="$(yflat "git${US}${section}${US}${head}")"
  [[ -n "$v" ]] && { printf '%s' "$v"; return; }
  while IFS= read -r pat; do
    case "$pat" in *"*") ;; *) continue ;; esac
    [[ "$pat" == "*" ]] && continue
    stem="${pat%\*}"
    if [[ "$head" == "$stem"* ]] && (( ${#stem} > bestlen )); then
      best="$pat"; bestlen=${#stem}
    fi
  done < <(yaml_flat | awk -F'\t' -v us="$US" -v sec="$section" \
             '{n=split($1,a,us); if (n==3 && a[1]=="git" && a[2]==sec) print a[3]}' | sort -u)
  if [[ -n "$best" ]]; then
    v="$(yflat "git${US}${section}${US}${best}")"
    [[ -n "$v" ]] && { printf '%s' "$v"; return; }
  fi
  yflat "git${US}${section}${US}*"
}

base_for_head() { map_match base_map "$1"; }

hook_patterns() {
  yaml_flat | awk -F'\t' -v us="$US" '{n=split($1,a,us); if (n==4 && a[1]=="hooks" && a[2]=="pr") print a[3]}' | sort -u
}

# hooks_for_head_point HEAD POINT — exact head, then the longest matching
# family, then "*". A pattern that declares no entry for this point inherits.
hooks_for_head_point() {
  local head="$1" point="$2" pat stem best="" bestlen=0 v
  v="$(yflat "hooks${US}pr${US}${head}${US}${point}")"
  [[ -n "$v" ]] && { printf '%s' "$v"; return; }
  while IFS= read -r pat; do
    case "$pat" in *"*") ;; *) continue ;; esac
    [[ "$pat" == "*" ]] && continue
    stem="${pat%\*}"
    if [[ "$head" == "$stem"* ]] && (( ${#stem} > bestlen )); then
      best="$pat"; bestlen=${#stem}
    fi
  done < <(hook_patterns)
  if [[ -n "$best" ]]; then
    v="$(yflat "hooks${US}pr${US}${best}${US}${point}")"
    [[ -n "$v" ]] && { printf '%s' "$v"; return; }
  fi
  printf '%s' "$(yflat "hooks${US}pr${US}*${US}${point}")"
}

detect_base() {
  local dir="$1" b
  b="$(git -C "$dir" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||' || true)"
  if [[ -n "$b" ]]; then printf '%s' "$b"; return 0; fi
  if command -v gh >/dev/null 2>&1; then
    b="$(cd "$dir" && gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || true)"
    if [[ -n "$b" ]]; then printf '%s' "$b"; return 0; fi
  fi
  return 0
}

remote_name() {
  local dir="$1" remotes
  remotes="$(git -C "$dir" remote 2>/dev/null)"
  if printf '%s\n' "$remotes" | grep -qx origin; then printf 'origin'; return 0; fi
  printf '%s\n' "$remotes" | head -n 1
}

nested_repos() {
  shopt -s nullglob
  local child
  for child in "$ROOT"/*/; do
    [[ -d "$child/.git" ]] || continue
    printf '%s\n' "$(basename "$child")"
  done
  shopt -u nullglob
}

path_exists() { [[ -e "$ROOT/$1" ]]; }

pick_artifact() {
  local candidate="$1" fallback="$2"
  if path_exists "$candidate"; then printf '%s' "$candidate"; else printf '%s' "$fallback"; fi
}

PLANS="$(pick_artifact docs/plans docs/plans)"
SOLUTIONS="$(pick_artifact docs/solutions docs/solutions)"
HANDBOOKS="$(pick_artifact docs/handbooks docs/handbooks)"
CONCEPTS="$(pick_artifact CONCEPTS.md CONCEPTS.md)"

MIRROR_REMOTE=""
MIRROR_BRANCH="main"
REPO_NAME=""
DEFAULT_BRANCH=""

case "$TOPOLOGY" in
  repo)
    REPO_NAME="$(remote_name "$ROOT")"
    REPO_NAME="${REPO_NAME:-origin}"
    # A check run reads the base from the config; probing costs a network call.
    (( CHECK )) || DEFAULT_BRANCH="$(detect_base "$ROOT")"
    ;;
  workspace)
    MIRROR_REMOTE="$(config_value remote 2>/dev/null || true)"
    MIRROR_BRANCH="$(config_value mirror_branch 2>/dev/null || true)"
    MIRROR_BRANCH="${MIRROR_BRANCH:-main}"
    ;;
esac

if (( CHECK )); then
  drift=0
  note() { printf '%s\n' "$*"; }
  bad()  { printf '  drift: %s\n' "$*"; drift=1; }

  note "root: ${ROOT}"
  note "config: ${CONFIG:-none found (walking up from $START)}"

  if [[ -z "$CONFIG" ]]; then
    bad "no .sassywares/config.yaml found — run sassy-setup"
    exit 1
  fi

  configured_repo="$(config_value repo 2>/dev/null || true)"
  if [[ -z "$configured_repo" ]]; then
    bad "git.repo is unset"
  elif [[ "$TOPOLOGY" == "repo" ]]; then
    # The tree is a repo: the configured value must name one of its remotes.
    case "$configured_repo" in
      workspace|none) bad "git.repo is '$configured_repo' but this folder is a git repo" ;;
      *) git -C "$ROOT" remote 2>/dev/null | grep -qx "$configured_repo" \
           || bad "git.repo '$configured_repo' is not a remote of this repo" ;;
    esac
  else
    # Not a repo: `workspace` and `none` are both legal, and which one is a
    # human policy call the tree cannot verify.
    case "$configured_repo" in
      workspace|none) note "  not a repo; '$configured_repo' accepted" ;;
      *) bad "git.repo is '$configured_repo' but this folder is not a git repo" ;;
    esac
  fi

  if [[ -n "$(yflat "git${US}default_branch")" ]]; then
    if [[ "$TOPOLOGY" == "workspace" ]]; then
      bad "git.default_branch is gone — the mirror's branch is git.mirror_branch"
    else
      bad "git.default_branch is gone — use git.base_map with a \"*\" entry"
    fi
  fi

  if [[ "$TOPOLOGY" == "repo" ]]; then
    if [[ -z "$(yflat "git${US}base_map${US}*")" ]]; then
      bad "git.base_map has no \"*\" entry — it is the base for ordinary work"
    else
      while IFS= read -r pat; do
        [[ -n "$pat" ]] || continue
        case "$pat" in
          "*") ;;
          *"*") [[ "${pat%\*}" != *"*" ]] || bad "base_map key '$pat': only one trailing * is allowed" ;;
        esac
      done < <(yaml_flat | awk -F'\t' -v us="$US" '{n=split($1,a,us); if (n==3 && a[1]=="git" && a[2]=="base_map") print a[3]}' | sort -u)
      head_ref="${HEAD_ARG:-$(git -C "$ROOT" branch --show-current 2>/dev/null || true)}"
      if [[ -n "$head_ref" ]]; then
        note "  base for '${head_ref}': $(base_for_head "$head_ref")"
        cur="$head_ref"; hops=0
        while [[ -n "$cur" ]] && (( hops < 8 )); do
          next="$(yflat "git${US}base_map${US}${cur}")"
          [[ -z "$next" ]] && break
          cur="$next"; hops=$((hops + 1))
          if [[ "$cur" == "$head_ref" ]]; then
            bad "git.base_map cycles through '$head_ref'"; break
          fi
        done
      else
        note "  detached HEAD — pass --head <branch> to see the resolved base"
      fi
    fi
  fi

  if [[ "$TOPOLOGY" == "workspace" ]]; then
    [[ -n "$MIRROR_REMOTE" ]] || bad "git.remote is required when git.repo is workspace"
    installed="$ROOT/.sassywares/workspace/snapshot"
    if [[ -x "$installed" ]]; then
      installed_v="$(sed -n 's/^# snapshot-version: //p' "$installed" | head -n 1)"
      asset_v="$(sed -n 's/^# snapshot-version: //p' "$ASSET_SNAPSHOT" | head -n 1)"
      if [[ -z "$installed_v" ]]; then
        bad "installed .sassywares/workspace/snapshot has no version line"
      elif [[ "$installed_v" != "$asset_v" ]]; then
        bad "installed snapshot is v${installed_v}, this skill ships v${asset_v} — re-run setup"
      else
        note "  snapshot v${installed_v}"
      fi
    else
      bad "missing .sassywares/workspace/snapshot"
    fi
    while IFS= read -r name; do
      [[ -n "$name" ]] || continue
      base="$(detect_base "$ROOT/$name")"
      listed="$(block_value repos "$name" || true)"
      if [[ -z "$listed" ]]; then
        bad "repos has no entry for '$name' (remote default: ${base:-unknown})"
      elif [[ -n "$base" && "$listed" != "$base" ]]; then
        note "  repos.$name '$listed' overrides the remote default '$base' — expected for an integration branch"
      fi
    done < <(nested_repos)
  fi

  # Hooks: head-scoped, so `staging` means "the PR is from staging".
  if [[ -n "$(yflat "hooks${US}pr${US}before_create")" ]]; then
    bad "hooks.pr.<point> is now nested by head branch — write hooks.pr.\"*\".<point>"
  fi
  while IFS= read -r pat; do
    [[ -n "$pat" ]] || continue
    case "$pat" in
      "*") ;;
      *"*") [[ "${pat%\*}" != *"*" ]] || bad "hook pattern '$pat': only one trailing * is allowed" ;;
    esac
    for point in before_create after_create before_merge after_merge; do
      val="$(yflat "hooks${US}pr${US}${pat}${US}${point}")"
      [[ -n "$val" ]] || continue
      while IFS= read -r entry; do
        [[ -n "$entry" ]] || continue
        name="${entry%% *}"
        case "$name" in
          sassy-*) bad "hooks.$pat.$point: '$name' is one of our skills — hooks are project skills only" ;;
          *) hook_skill_path "$name" >/dev/null 2>&1 \
               || bad "hooks.$pat.$point: '$name' not found at .agents/skills/$name/SKILL.md" ;;
        esac
      done < <(list_items "$val")
    done
  done < <(hook_patterns)

  # Resolve for one head, so nobody has to merge maps in their head.
  if [[ -n "$HEAD_ARG" ]]; then
    if [[ "$TOPOLOGY" == "repo" ]]; then
      note "  base for '$HEAD_ARG': $(base_for_head "$HEAD_ARG")"
    fi
    for point in before_create after_create before_merge after_merge; do
      resolved="$(hooks_for_head_point "$HEAD_ARG" "$point")"
      note "  head '$HEAD_ARG' → $point: $( [[ -n "$resolved" ]] && printf '%s' "$resolved" || printf 'none' )"
    done
  fi

  for key in plans solutions handbooks concepts; do
    val="$(block_value artifacts "$key" || true)"
    [[ -n "$val" ]] && note "  artifacts.$key: $val"
  done

  if (( drift )); then exit 1; fi
  note "  config matches the tree"
  exit 0
fi

# --- Emit a proposal -------------------------------------------------------
# Every key carries its meaning and its allowed values. The file is the
# documentation a teammate reads, so the comments are part of the output, not
# decoration to be stripped.

# kv KEY VALUE WIDTH COMMENT [INDENT] — prints "key: value" padded so comments
# align. WIDTH 0 means no padding.
kv() {
  local indent="${5:-  }" line
  line="$indent$1: $2"
  if [[ -n "${4:-}" && "${3:-0}" != "0" ]]; then
    printf '%-*s%s\n' "$3" "$line" "$4"
  elif [[ -n "${4:-}" ]]; then
    printf '%s  %s\n' "$line" "$4"
  else
    printf '%s\n' "$line"
  fi
}

cat <<EOF
# Sassy Skills project config — written by sassy-setup.
# Every key is optional: delete a line to fall back to the documented default.
# Guide: https://github.com/sassywares/sassy-skills/blob/main/skills/sassy-setup/references/config.md

# --- Artifacts ------------------------------------------------------------
# Where sassy writes its documents. Paths are relative to this file's folder.
artifacts:
EOF
kv plans "$PLANS" 34 '# sassy-plan writes plans here'
kv solutions "$SOLUTIONS" 34 '# sassy-compound writes learnings here'
kv handbooks "$HANDBOOKS" 34 '# sassy-handbook writes handovers here'
kv concepts "$CONCEPTS" 34 '# the glossary sassy-compound maintains (a file)'
cat <<EOF

# --- Knowledge ------------------------------------------------------------
# read: folders and files searched for prior learnings before planning or
#       debugging. Any paths; one that does not exist is skipped, not fatal.
# write: true | false — false means this project takes no learnings.
knowledge:
EOF
kv read "[$SOLUTIONS, $CONCEPTS]" 0
kv write true 34 '# true | false'

case "$TOPOLOGY" in
  repo)
    cat <<EOF

# --- Git ------------------------------------------------------------------
# repo: a remote name (this folder is the repo) | workspace (repos live below,
#       this folder is not a repo) | none (no git anywhere here).
# base_map: the base for a HEAD branch, so a PR targets the right rung.
#   "*" is ordinary work; add a rung for a branch that releases elsewhere.
git:
EOF
    kv repo "$REPO_NAME" 0
    printf '  base_map:\n'
    if [[ -n "$DEFAULT_BRANCH" ]]; then
      printf '    "*": %s   # probed — confirm this is where ordinary work branches from\n' "$DEFAULT_BRANCH"
    else
      printf '    "*": %s   # base for ordinary work; never guessed\n' "<confirm by hand>"
    fi
    printf '    # staging: main   # uncomment when a branch releases somewhere else\n'
    cat <<'EOF'

# workspace only: each nested repo folder -> the base its PRs target
# repos:
#   fe: dev
EOF
    ;;
  workspace)
    cat <<EOF

# --- Git ------------------------------------------------------------------
# repo: workspace means repos live below and this folder is not a repo.
# remote: the snapshot mirror (GitHub owner/name or URL), required here.
# mirror_branch: the branch the mirror pushes to. Not a PR base — nested repos
#   carry their own, and a workspace has no branches of its own.
git:
EOF
    kv repo workspace 0
    kv remote "${MIRROR_REMOTE:-<set the snapshot mirror, owner/name or URL>}" 0
    kv mirror_branch "$MIRROR_BRANCH" 0
    cat <<'EOF'

# --- Repos ----------------------------------------------------------------
# Every nested repo -> the base its PRs target. A touched repo missing here is
# a question, never a default.
repos:
EOF
    any=0
    while IFS= read -r name; do
      [[ -n "$name" ]] || continue
      base="$(detect_base "$ROOT/$name")"
      if [[ -n "$base" ]]; then
        kv "$name" "$base" 34 '# probed — confirm the PR base'
      else
        kv "$name" "<confirm>" 34 '# base unknown; confirm by hand'
      fi
      any=1
    done < <(nested_repos)
    (( any )) || printf '  # no nested repos found\n'
    ;;
  *)
    cat <<EOF

# --- Git ------------------------------------------------------------------
# repo: none means this folder is deliberately outside git: commit, PR, and
#       babysit refuse here, and work still leaves its changes on disk.
git:
EOF
    kv repo none 0
    ;;
esac

cat <<'EOF'

# --- Commit ---------------------------------------------------------------
# current: commit on the checked-out branch.
# new: cut a branch from the base map for the current head; name it in multi-repo runs so
#      every repo gets the same branch name.
commit:
EOF
kv branch current 34 '# current | new'
cat <<'EOF'

# --- Pull requests --------------------------------------------------------
pr:
EOF
kv babysit true 24 '# true | false — babysit the PR this run opened'
kv merge false 24 '# true = merge every babysat PR here'
kv delete_branch false 24 '# true | false — delete the head branch once merged'
cat <<'EOF'

# --- Hooks ----------------------------------------------------------------
# Project steps injected into the PR pipeline, keyed by the HEAD branch — the
# branch the PR comes from, never the one it targets. `"*"` is the default;
# a name overrides per point, and `release/*` matches a family. Each entry is
# `<skill> <args…>`, resolved at .agents/skills/<name>/SKILL.md; args are passed
# to the skill verbatim. Declared order, one worker each, missing skill fails closed.
hooks:
  pr:
    "*":
EOF
kv before_create '[]' 30 '# after the commit, before the PR opens' '      '
kv after_create '[]' 30 '# the PR was just created' '      '
kv before_merge '[]' 30 '# this run is about to merge' '      '
kv after_merge '[]' 30 '# this run observed the merge' '      '
cat <<'EOF'
    # staging:            # per-point override for one head branch
    #   before_create: []
    # release/*:          # a family of heads
    #   after_merge: [notify mode:auto]
EOF
