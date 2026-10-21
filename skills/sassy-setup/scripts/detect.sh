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
CHECK=0

while (( $# )); do
  case "$1" in
    --root)   shift; [[ $# -ge 1 ]] || { echo "missing DIR after --root" >&2; exit 2; }; ROOT_ARG="$1" ;;
    --root=*) ROOT_ARG="${1#*=}" ;;
    --check)  CHECK=1 ;;
    -h|--help) sed -n '2,10p' "${BASH_SOURCE[0]}" | sed 's|^# \{0,1\}||'; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

START="${ROOT_ARG:-$PWD}"
[[ -d "$START" ]] || { echo "not a directory: $START" >&2; exit 2; }

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

# Topology root: the git toplevel when inside a work tree, else the start dir.
if TOPLEVEL="$(git -C "$START" rev-parse --show-toplevel 2>/dev/null)"; then
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
  local dir="$1"
  git -C "$dir" remote 2>/dev/null | head -n 1
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
    DEFAULT_BRANCH="$(detect_base "$ROOT")"
    ;;
  workspace)
    MIRROR_REMOTE="$(config_value remote 2>/dev/null || true)"
    MIRROR_BRANCH="$(config_value default_branch 2>/dev/null || true)"
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

  if [[ "$TOPOLOGY" == "repo" ]]; then
    configured_base="$(config_value default_branch 2>/dev/null || true)"
    if [[ -z "$configured_base" ]]; then
      bad "git.default_branch is unset — name the branch new work is cut from"
    elif [[ -n "$DEFAULT_BRANCH" && "$configured_base" != "$DEFAULT_BRANCH" ]]; then
      # A team base is a policy choice: staging, dev, or the release branch can
      # all differ from the remote default. Report it, do not call it drift.
      note "  default_branch '$configured_base' overrides the remote default '$DEFAULT_BRANCH' — expected when PRs target a team base"
    elif [[ -z "$DEFAULT_BRANCH" ]]; then
      note "  remote default undetectable — '$configured_base' taken as declared"
    fi
    configured_remote="$(config_value remote 2>/dev/null || true)"
    [[ -z "$configured_remote" ]] || bad "git.remote is set but git.repo is not workspace"
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

  # Hooks: every declared name resolves to a project skill, and none may be ours.
  if grep -q '^hooks:' "$CONFIG" 2>/dev/null; then
    while IFS= read -r hline; do
      [[ "$hline" == " "* ]] || continue          # only nested lines belong here
      hkey="$(printf '%s' "$hline" | sed -nE 's/^[[:space:]]*([A-Za-z_]+):.*/\1/p')"
      case "$hkey" in
        "") continue ;;
        pr) continue ;;
        before_create|after_create|before_merge|after_merge) ;;
        *) bad "unknown hook point '$hkey' under hooks:"; continue ;;
      esac
      hlist="$(printf '%s' "$hline" | sed -nE 's/^[^:]+:[[:space:]]*\[([^]]*)\].*/\1/p')"
      [[ -n "$hlist" ]] || continue
      while IFS= read -r hraw; do
        hname="$(printf '%s' "$hraw" | sed -E 's/#.*$//; s/^[[:space:]]+//; s/[[:space:]]+$//; s/^["'\'']//; s/["'\'']$//')"
        [[ -n "$hname" ]] || continue
        case "$hname" in
          sassy-*) bad "hook $hkey: '$hname' is one of our skills — hooks are project skills only" ;;
          *)
            if hook_skill_path "$hname" >/dev/null; then
              note "  hook $hkey → $hname"
            else
              bad "hook $hkey: '$hname' not found at .agents/skills/$hname/SKILL.md"
            fi
            ;;
        esac
      done < <(printf '%s\n' "$hlist" | tr ',' '\n')
    done < <(sed -n '/^hooks:/,/^[a-z]/p' "$CONFIG")
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
# default_branch: what new branches are cut from, and what PRs target.
git:
EOF
    kv repo "$REPO_NAME" 0
    if [[ -n "$DEFAULT_BRANCH" ]]; then
      kv default_branch "$DEFAULT_BRANCH" 34 '# probed — confirm it is the team base'
    else
      kv default_branch "<confirm by hand>" 34 '# base for branches and PRs; never guessed'
    fi
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
# default_branch: the mirror's branch, not any nested repo's base.
git:
EOF
    kv repo workspace 0
    kv remote "${MIRROR_REMOTE:-<set the snapshot mirror, owner/name or URL>}" 0
    kv default_branch "$MIRROR_BRANCH" 0
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
# new: cut a branch from origin/<default_branch>; name it in multi-repo runs so
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
# Project steps injected into the PR pipeline. Each entry is a skill name,
# resolved at .agents/skills/<name>/SKILL.md, nearest walking up. Declared
# order, one worker each, and a declared-but-missing skill fails closed.
#   before_create — after the commit, before the PR opens (may commit its output)
#   after_create  — the PR was just created
#   before_merge  — this run is about to merge the PR
#   after_merge   — this run observed the PR merged
hooks:
  pr:
EOF
kv before_create '[]' 24 '# after the commit, before the PR opens' '    '
kv after_create '[]' 24 '# the PR was just created' '    '
kv before_merge '[]' 24 '# this run is about to merge' '    '
kv after_merge '[]' 24 '# this run observed the merge' '    '
