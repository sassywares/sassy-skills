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

# Base branch for one repo. Empty output means unknown — never guessed.
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
    if [[ -n "$DEFAULT_BRANCH" ]]; then
      [[ "$configured_base" == "$DEFAULT_BRANCH" ]] \
        || bad "git.default_branch is '${configured_base:-<unset>}', detected '$DEFAULT_BRANCH'"
    else
      note "  base branch undetectable here — confirm git.default_branch by hand"
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
      listed="$(sed -n "/^repos:/,/^[a-z]/p" "$CONFIG" | sed -n "s/^[[:space:]]\{1,\}${name}:[[:space:]]*//p" | head -n 1 || true)"
      if [[ -z "$listed" ]]; then
        bad "repos has no entry for '$name' (detected base: ${base:-unknown})"
      elif [[ -n "$base" && "$listed" != "$base" ]]; then
        bad "repos.$name is '$listed', detected '$base'"
      fi
    done < <(nested_repos)
  fi

  for key in plans solutions handbooks concepts; do
    val="$(sed -n "/^artifacts:/,/^[a-z]/p" "$CONFIG" | sed -n "s/^[[:space:]]\{1,\}${key}:[[:space:]]*//p" | head -n 1 || true)"
    [[ -n "$val" ]] && note "  artifacts.$key: $val"
  done

  if (( drift )); then exit 1; fi
  note "  config matches the tree"
  exit 0
fi

# --- Emit a proposal -------------------------------------------------------

cat <<EOF
# .sassywares/config.yaml — written by sassy-setup. Every key is optional;
# deleting this file restores the documented defaults.
artifacts:
  plans: $PLANS
  solutions: $SOLUTIONS
  handbooks: $HANDBOOKS
  concepts: $CONCEPTS
knowledge:
  read: [$SOLUTIONS, ${CONCEPTS}]
  write: true
EOF

case "$TOPOLOGY" in
  repo)
    printf 'git:\n  repo: %s\n' "$REPO_NAME"
    if [[ -n "$DEFAULT_BRANCH" ]]; then
      printf '  default_branch: %s   # probed: the remote default, confirm it is the team base\n' "$DEFAULT_BRANCH"
    fi
    ;;
  workspace)
    printf 'git:\n  repo: workspace\n'
    printf '  remote: %s\n' "${MIRROR_REMOTE:-<set the snapshot mirror remote, owner/name or URL>}"
    printf '  default_branch: %s\n' "$MIRROR_BRANCH"
    printf 'repos:\n'
    any=0
    while IFS= read -r name; do
      [[ -n "$name" ]] || continue
      base="$(detect_base "$ROOT/$name")"
      if [[ -n "$base" ]]; then
        printf '  %s: %s   # probed: the remote default, confirm the PR base\n' "$name" "$base"
      else
        printf '  %s: %s\n' "$name" "<base unknown, confirm by hand>"
      fi
      any=1
    done < <(nested_repos)
    (( any )) || printf '  # no nested repos found\n'
    ;;
  *)
    printf 'git:\n  repo: none\n'
    ;;
esac

cat <<EOF
commit:
  branch: current
pr:
  babysit: true
  merge: false
  delete_branch: false
EOF
