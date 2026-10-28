#!/usr/bin/env bash
# Detect project topology and emit a proposed .sassywares/config.yaml.
#
# Read-only. Writes nothing. sassy-setup runs this, asks the few questions the
# detection cannot answer, then writes the file itself.
#
# Usage:
#   detect.sh [--root DIR]            print a proposed config to stdout
#   detect.sh [--head BRANCH]         resolve the base and hooks for one head
#   detect.sh --branch [--policy P]   resolve the branch decision for this run
#   detect.sh [--root DIR] --check    compare the existing config, and the
#                                    vendored pin, to reality
#
# --policy takes infer|current|new: the skill-level token. infer (the default)
# defers to commit.branch in the config, and new is the fallback when the config
# is silent. --branch is read-only; it prints the decision, it never cuts.
# --name BRANCH resolves pr-base for the name a run is about to pick, because a
# new name can match a base_map family (release/*) and retarget the PR.
set -euo pipefail

ROOT_ARG=""
HEAD_ARG=""
POLICY_ARG=""
NAME_ARG=""
CHECK=0
BRANCH=0

while (( $# )); do
  case "$1" in
    --root)   shift; [[ $# -ge 1 ]] || { echo "missing DIR after --root" >&2; exit 2; }; ROOT_ARG="$1" ;;
    --root=*) ROOT_ARG="${1#*=}" ;;
    --head)   shift; [[ $# -ge 1 ]] || { echo "missing BRANCH after --head" >&2; exit 2; }; HEAD_ARG="$1" ;;
    --head=*) HEAD_ARG="${1#*=}" ;;
    --policy) shift; [[ $# -ge 1 ]] || { echo "missing POLICY after --policy" >&2; exit 2; }; POLICY_ARG="$1" ;;
    --policy=*) POLICY_ARG="${1#*=}" ;;
    --name)   shift; [[ $# -ge 1 ]] || { echo "missing BRANCH after --name" >&2; exit 2; }; NAME_ARG="$1" ;;
    --name=*) NAME_ARG="${1#*=}" ;;
    --branch) BRANCH=1 ;;
    --check)  CHECK=1 ;;
    -h|--help) sed -n '2,15p' "${BASH_SOURCE[0]}" | sed 's|^# \{0,1\}||'; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

START="${ROOT_ARG:-$PWD}"
[[ -d "$START" ]] || { echo "not a directory: $START" >&2; exit 2; }
# --branch prints a decision; --check validates a config. One at a time, or the
# second is silently ignored.
(( BRANCH && CHECK )) && { echo "--branch and --check are separate modes; run them one at a time" >&2; exit 2; }
# Absolute, or the walk-up loop below re-reads "." forever.
START="$(cd "$START" && pwd -P)"

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ASSET_SNAPSHOT="$SKILL_DIR/assets/snapshot"
ASSET_WORKSPACE="$SKILL_DIR/assets/workspace"

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
    }' "${1:-$CONFIG}"
}

yflat() { yaml_flat "$CONFIG" | awk -F'\t' -v p="$1" '$1 == p { print $2; exit }'; }

# yflat_in FILE PATH — the same reader against another config file.
yflat_in() { yaml_flat "$1" | awk -F'\t' -v p="$2" '$1 == p { print $2; exit }'; }

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
  done < <(yaml_flat "$CONFIG" | awk -F'\t' -v us="$US" -v sec="$section" \
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

# A configured path that leaves the project is a document written somewhere the
# project does not own, so it fails closed rather than being created.
escapes_root() {
  local p="${1#./}"
  case "$p" in
    ..|../*|*/..|*/../*|*"/../"*) return 0 ;;
  esac
  return 1
}

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

  # A typo'd key is the quietest failure in the file: it parses, it is ignored,
  # and the run silently falls back to a default the project never chose. The
  # whitelist is the schema in references/config.md; every key there has a
  # validator of its own below, so anything landing here is unknown.
  while IFS=$'\t' read -r kpath _; do
    [[ -n "$kpath" ]] || continue
    key="${kpath//$US/.}"
    case "$key" in
      artifacts.plans|artifacts.solutions|artifacts.handbooks|artifacts.concepts) ;;
      knowledge.read|knowledge.write) ;;
      git.repo|git.remote|git.mirror_branch) ;;
      git.default_branch) ;;                    # has its own message below
      git.base_map.*) ;;
      repos.*) ;;
      commit.branch) ;;
      pr.babysit|pr.merge|pr.delete_branch) ;;
      hooks.pr.*) ;;                            # shape checked with the hooks
      *) bad "unknown key '$key' — it is ignored, so the run uses the default" ;;
    esac
  done < <(yaml_flat "$CONFIG")

  if [[ -n "$(yflat "git${US}default_branch")" ]]; then
    if [[ "$TOPOLOGY" == "workspace" ]]; then
      bad "git.default_branch is gone — the mirror's branch is git.mirror_branch"
    else
      bad "git.default_branch is gone — use git.base_map with a \"*\" entry"
    fi
  fi

  if [[ "$TOPOLOGY" == "repo" ]]; then
    if [[ -n "$(yflat "git${US}remote")" ]]; then
      bad "git.remote is workspace-only — a repo config names its remote in git.repo"
    fi
    if [[ -n "$(yflat "git${US}mirror_branch")" ]]; then
      bad "git.mirror_branch is workspace-only — a repo routes branches in git.base_map"
    fi
    if [[ -z "$(yflat "git${US}base_map${US}*")" ]]; then
      bad "git.base_map has no \"*\" entry — it is the base for ordinary work"
    else
      while IFS= read -r pat; do
        [[ -n "$pat" ]] || continue
        case "$pat" in
          "*") ;;
          *"*") [[ "${pat%\*}" != *"*" ]] || bad "base_map key '$pat': only one trailing * is allowed" ;;
        esac
      done < <(yaml_flat "$CONFIG" | awk -F'\t' -v us="$US" '{n=split($1,a,us); if (n==3 && a[1]=="git" && a[2]=="base_map") print a[3]}' | sort -u)
      head_ref="${HEAD_ARG:-$(git -C "$ROOT" branch --show-current 2>/dev/null || true)}"
      if [[ -n "$head_ref" ]]; then
        # the --head readout below prints this line; avoid printing it twice
        [[ -n "$HEAD_ARG" ]] || note "  base for '${head_ref}': $(base_for_head "$head_ref")"
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

  # `repos` is the workspace inventory. In a repo config it is a dead map, and
  # a reader would trust it over the base_map that actually applies.
  if [[ "$configured_repo" != "workspace" ]]; then
    while IFS= read -r rname; do
      [[ -n "$rname" ]] || continue
      bad "repos.$rname is workspace-only — git.repo is '${configured_repo:-unset}'"
    done < <(yaml_flat "$CONFIG" \
               | awk -F'\t' -v us="$US" '{n=split($1,a,us); if (n>=2 && a[1]=="repos") print a[2]}' \
               | sort -u)
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

    # The git helpers are optional as a set, but a half-installed or stale set is
    # drift: they read `repos:` from this config, so a version skew means the
    # project is running a reader written for a different map.
    installed_lib="$ROOT/.sassywares/workspace/_lib.sh"
    if [[ -f "$installed_lib" ]]; then
      lib_v="$(sed -n 's/^# workspace-git-version: //p' "$installed_lib" | head -n 1)"
      asset_lib_v="$(sed -n 's/^# workspace-git-version: //p' "$ASSET_WORKSPACE/_lib.sh" | head -n 1)"
      if [[ -z "$lib_v" ]]; then
        bad "installed .sassywares/workspace/_lib.sh has no workspace-git-version line"
      elif [[ -n "$asset_lib_v" && "$lib_v" != "$asset_lib_v" ]]; then
        bad "installed workspace git helpers are v${lib_v}, this skill ships v${asset_lib_v} — re-run setup"
      else
        note "  workspace-git v${lib_v}"
      fi
      for helper in branches pull checkout-bases; do
        if [[ ! -x "$ROOT/.sassywares/workspace/$helper" ]]; then
          bad "missing or not executable: .sassywares/workspace/$helper"
        fi
      done
    else
      note "  no workspace git helpers installed (optional)"
    fi

    # Aliases live in the project's own manifest; setup only ever adds them.
    manifest=""
    for candidate in package.json deno.json deno.jsonc composer.json; do
      if [[ -f "$ROOT/$candidate" ]]; then
        manifest="$candidate"
        break
      fi
    done
    if [[ -n "$manifest" ]]; then
      missing_aliases=()
      for script in branches pull checkout-bases snapshot; do
        grep -q "\"workspace:${script}\"" "$ROOT/$manifest" || missing_aliases+=("$script")
      done
      if [[ ${#missing_aliases[@]} -eq 0 ]]; then
        note "  workspace:* aliases in ${manifest}"
      elif [[ ${#missing_aliases[@]} -lt 4 ]]; then
        bad "${manifest} is missing $(printf '`workspace:%s` ' "${missing_aliases[@]}")— half-wired aliases; re-run setup"
      else
        note "  no workspace:* aliases in ${manifest} (optional)"
      fi
    fi
    while IFS= read -r name; do
      [[ -n "$name" ]] || continue
      base="$(detect_base "$ROOT/$name")"
      listed="$(block_value repos "$name" || true)"
      # A nested repo's own config is authoritative; `repos` is the inventory and
      # the fallback for repos that have none.
      nested="$ROOT/$name/.sassywares/config.yaml"
      nested_base=""
      [[ -f "$nested" ]] && nested_base="$(yflat_in "$nested" "git${US}base_map${US}*")"

      if [[ -n "$nested_base" ]]; then
        if [[ -n "$listed" && "$listed" != "$nested_base" ]]; then
          bad "repos.$name is '$listed' but $name/.sassywares/config.yaml maps \"*\" to '$nested_base' — the nested config wins; fix or drop the repos entry"
        elif [[ -z "$listed" ]]; then
          note "  $name: base '$nested_base' from its own config (no repos entry needed)"
        else
          note "  $name: base '$nested_base' (agrees with its own config)"
        fi
      elif [[ -z "$listed" ]]; then
        bad "repos has no entry for '$name' and $name carries no config (remote default: ${base:-unknown})"
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

  # `hooks.pr.<head>.<point>` is the only shape, and the four points are the
  # only moments a skill asks for. A fifth point name is a step that never fires.
  while IFS=$'\t' read -r depth hpath; do
    [[ -n "$depth" ]] || continue
    if [[ "$depth" != "4" ]]; then
      bad "hooks entry '${hpath//$US/.}' is not head -> point -> list"
      continue
    fi
    point="${hpath##*$US}"
    case "$point" in
      before_create|after_create|before_merge|after_merge) ;;
      *) bad "hooks point '$point' is not one of before_create|after_create|before_merge|after_merge" ;;
    esac
  done < <(yaml_flat "$CONFIG" \
             | awk -F'\t' -v us="$US" '{n=split($1,a,us); if (n>=2 && a[1]=="hooks") print n "\t" $1}')

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

  # artifacts is the one block that fails closed everywhere it is read, so a
  # bad value here is drift, not a note: a typo must not write docs outside the
  # project. Existence is not drift — the directory is created on first write.
  for key in plans solutions handbooks concepts; do
    val="$(block_value artifacts "$key" || true)"
    [[ -n "$val" ]] || continue
    case "$val" in
      /*|~*) bad "artifacts.$key '$val' is not relative to the config" ;;
      .|./) bad "artifacts.$key is the project root itself" ;;
      *)
        if escapes_root "$val"; then
          bad "artifacts.$key '$val' walks outside the project"
        elif [[ "$key" == "concepts" && "$val" == */ ]]; then
          bad "artifacts.concepts '$val' is a directory — concepts is one file"
        elif path_exists "$val"; then
          note "  artifacts.$key: $val (exists)"
        else
          note "  artifacts.$key: $val (created on first write)"
        fi
        ;;
    esac
  done

  # knowledge.read fails soft at read time by design, which is exactly why a
  # broken value has to be visible here: nothing else will ever complain.
  while IFS= read -r kline; do
    [[ -n "$kline" ]] || continue
    bad "knowledge.read must be an inline list — write read: [docs/solutions, CONCEPTS.md]"
  done < <(sed -n '/^knowledge:/,/^[a-z]/p' "$CONFIG" | grep -E '^[[:space:]]*-[[:space:]]' || true)
  readv="$(yflat "knowledge${US}read" || true)"
  while IFS= read -r kpath; do
    [[ -n "$kpath" ]] || continue
    case "$kpath" in
      /*|~*) bad "knowledge.read '$kpath' is not a path relative to the config" ;;
      *) if escapes_root "$kpath"; then
           bad "knowledge.read '$kpath' walks outside the project"
         elif ! path_exists "$kpath"; then
           note "  knowledge.read '$kpath' does not exist — skipped, not fatal"
         fi ;;
    esac
  done < <(list_items "$readv")
  val="$(yflat "knowledge${US}write" || true)"
  if [[ -n "$val" ]]; then
    case "$val" in
      true|false) note "  knowledge.write: $val" ;;
      *) bad "knowledge.write '$val' must be true|false" ;;
    esac
  fi

  # pr.* answers a policy question, so a value that is neither boolean is a
  # policy nobody decided. Bare on/off are YAML 1.1 booleans and parse
  # inconsistently across readers.
  for key in babysit merge delete_branch; do
    val="$(block_value pr "$key" || true)"
    [[ -n "$val" ]] || continue
    case "$val" in
      true|false) note "  pr.$key: $val" ;;
      *) bad "pr.$key '$val' must be true|false, never on/off" ;;
    esac
  done

  # commit.branch steers whether a run may touch a base branch, so an invalid
  # value is reported rather than silently ignored.
  val="$(yflat "commit${US}branch" 2>/dev/null || true)"
  if [[ -n "$val" ]]; then
    case "$val" in
      current|new) note "  commit.branch: $val" ;;
      *) bad "commit.branch '$val' is not current|new" ;;
    esac
  fi

  # The pin. A config can match the tree perfectly while the vendored suite is
  # stale, edited, or half-installed, and every skill downstream then runs
  # something other than what the lock says. Offline, no network.
  if command -v node >/dev/null 2>&1; then
    while IFS=$'\t' read -r kind msg; do
      case "$kind" in
        drift) bad "$msg" ;;
        note)  note "  $msg" ;;
      esac
    done < <(node "$SKILL_DIR/scripts/lockcheck.mjs" --root "$ROOT" 2>/dev/null || true)
  else
    note "  node not found — the vendored pin is unverified (the skills CLI needs node)"
  fi

  if [[ "$TOPOLOGY" == "repo" ]]; then
    # Tracked, not merely present: a clone has to get the pin without a network
    # call, so an untracked lock is a setup that does not travel.
    if [[ -n "$(git -C "$ROOT" ls-files -- skills-lock.json 2>/dev/null)" ]]; then
      note "  skills-lock.json is tracked"
    else
      note "  skills-lock.json is not tracked yet — the setup commit carries it"
    fi
    if [[ -e "$ROOT/.claude/skills" ]] && ! git -C "$ROOT" check-ignore -q -- .claude/skills 2>/dev/null; then
      note "  .claude/skills is not gitignored — install-time links may get committed"
    fi
  fi

  if (( drift )); then exit 1; fi
  note "  config matches the tree"
  exit 0
fi

# --- Branch decision -------------------------------------------------------
# Read-only. Resolves commit.branch into the single decision the entry skills
# (sassy-work, sassy-lfg, sassy-debug) make before they start: cut a branch,
# reuse the one checked out, or commit where you stand.
#
# Every base_map VALUE counts as a base branch, not just the remote default.
# tap2's day-to-day base is `staging`, so comparing only against origin/HEAD
# declared staging "not a base" and let phase work commit onto it.
if (( BRANCH )); then
  policy="${POLICY_ARG:-infer}"
  case "$policy" in
    infer|current|new) ;;
    *) echo "unknown --policy: $policy (expected infer, current, or new)" >&2; exit 2 ;;
  esac
  configured="$(yflat "commit${US}branch" 2>/dev/null || true)"
  note=""
  if [[ -n "$configured" && "$configured" != "current" && "$configured" != "new" ]]; then
    # A soft config error must not become a silently wrong branch decision.
    note="commit.branch '$configured' is not current|new; using new"
    configured=""
  fi
  if [[ "$policy" == "infer" ]]; then
    policy="${configured:-new}"
  fi

  # base_heads_in DIR — every branch DIR's config treats as a base: each
  # base_map value, the repos[<dir>] rung, and the remote default. A workspace
  # has no base_map of its own, so repos[] is what names its bases; reading
  # base_map alone reported every nested repo as on-branch and let runs commit
  # onto staging, which is the bug this whole mode exists to stop.
  base_heads_in() {
    local dir="$1" r v out=""
    if [[ -f "$dir/.sassywares/config.yaml" ]]; then
      out="$(yaml_flat "$dir/.sassywares/config.yaml" 2>/dev/null | awk -F'\t' -v us="$US" \
        '{n=split($1,a,us); if (n==3 && a[1]=="git" && a[2]=="base_map") print $2}' | sort -u || true)"
    fi
    v="$(yflat "repos${US}$(basename "$dir")" 2>/dev/null || true)"
    [[ -n "$v" ]] && out="$out"$'\n'"$v"
    r="$(remote_name "$dir")"
    if [[ -n "$r" ]]; then
      v="$(git -C "$dir" symbolic-ref --short "refs/remotes/$r/HEAD" 2>/dev/null | sed "s|^$r/||" || true)"
      [[ -n "$v" ]] && out="$out"$'\n'"$v"
    fi
    out="$(printf '%s\n' "$out" | grep -v '^$' | sort -u || true)"
    # Probing through gh costs a network call, so only when nothing else said.
    [[ -n "$out" ]] || out="$(detect_base "$dir" 2>/dev/null || true)"
    printf '%s\n' "$out" | grep -v '^$' || true
  }

  # in_base_heads DIR BRANCH — membership without a pipe: `… | grep -q` trips
  # pipefail, because grep exits on the first match and SIGPIPEs the producer,
  # so a branch that IS a base reported as if it were not.
  in_base_heads() {
    local dir="$1" want="$2" b
    while IFS= read -r b; do
      [[ "$b" == "$want" ]] && return 0
    done < <(base_heads_in "$dir")
    return 1
  }

  # repo_base DIR — the base a PR from DIR targets, for a brand-new branch name.
  repo_base() {
    local dir="$1" v="" r
    if [[ -f "$dir/.sassywares/config.yaml" ]]; then
      v="$(yflat_in "$dir/.sassywares/config.yaml" "git${US}base_map${US}*" 2>/dev/null || true)"
    fi
    [[ -n "$v" ]] || v="$(yflat "repos${US}$(basename "$dir")" 2>/dev/null || true)"
    if [[ -z "$v" ]]; then
      v="$(detect_base "$dir" 2>/dev/null || true)"
      [[ -n "$v" ]] && printf '%s' "$v" && return 0
    fi
    printf '%s' "$v"
  }

  # classify DIR [HEAD] — on-base, on-branch, detached, or unknown.
  classify() {
    local dir="$1" h="$2"
    if [[ -z "$h" ]]; then printf 'detached'; return 0; fi
    if in_base_heads "$dir" "$h"; then printf 'on-base'; else printf 'on-branch'; fi
  }

  # start_point DIR HEAD — the upstream ref a new branch is cut from. Prints
  # "none" when there is no upstream ref: cutting from local HEAD would carry
  # commits stranded on the base, which is the failure this prevents.
  start_point() {
    local dir="$1" h="$2" r
    r="$(remote_name "$dir")"
    if [[ -n "$r" && -n "$h" ]] && git -C "$dir" rev-parse --verify --quiet "refs/remotes/$r/$h" >/dev/null 2>&1; then
      printf '%s/%s' "$r" "$h"
    else
      printf 'none'
    fi
  }

  # unpublished DIR HEAD — commits on the local base that are not upstream.
  # Unknown on error, never 0: an unreadable count must not read as "clean".
  unpublished() {
    local dir="$1" h="$2" r n
    r="$(remote_name "$dir")"
    [[ -n "$r" && -n "$h" ]] || { printf 'unknown'; return 0; }
    git -C "$dir" rev-parse --verify --quiet "refs/remotes/$r/$h" >/dev/null 2>&1 || { printf 'unknown'; return 0; }
    n="$(git -C "$dir" rev-list --count "$r/$h..$h" 2>/dev/null || true)"
    [[ -n "$n" ]] && printf '%s' "$n" || printf 'unknown'
  }

  # decide STATE POLICY START UNPUBLISHED — the action, fail closed.
  decide() {
    local st="$1" pol="$2" start="$3" unp="$4"
    case "$st:$pol" in
      on-branch:*)     printf 'reuse'; return 0 ;;
      on-base:new)     ;;
      on-base:current) printf 'commit-here'; return 0 ;;
      detached:new)    ;;
      *)               printf 'refuse'; return 0 ;;
    esac
    # Cutting needs a known-clean upstream base.
    [[ "$start" == "none" ]] && { printf 'refuse'; return 0; }
    [[ "$unp" == "0" ]] || { printf 'stop-and-ask'; return 0; }
    printf 'create'
  }

  repo_value="$(yflat "git${US}repo" 2>/dev/null || true)"

  [[ -n "$note" ]] && printf 'note: %s\n' "$note"
  printf 'topology: %s\n' "$TOPOLOGY"
  printf 'config: %s\n' "${CONFIG:-none}"
  printf 'configured: %s\n' "${configured:-none}"
  printf 'policy: %s\n' "$policy"

  if [[ "$TOPOLOGY" == "none" || "$repo_value" == "none" ]]; then
    if [[ "$repo_value" == "none" ]]; then
      printf 'state: no-git\naction: refuse\nreason: git.repo is none\n'
    else
      printf 'state: no-git\naction: refuse\nreason: not a git work tree\n'
    fi
    exit 0
  fi

  if [[ "$TOPOLOGY" == "workspace" ]]; then
    # One policy for the whole run, resolved per repo: a run cannot follow two
    # branch policies, so a nested repo that disagrees is reported as drift.
    while IFS= read -r dir; do
      [[ -n "$dir" ]] || continue
      d="$ROOT/$dir"
      h="$(git -C "$d" branch --show-current 2>/dev/null || true)"
      st="$(classify "$d" "$h")"
      sp="$(start_point "$d" "$h")"
      base="$(repo_base "$d")"
      if [[ "$st" == "on-base" ]]; then unp="$(unpublished "$d" "$h")"; else unp=n/a; fi
      printf 'repo %s: head=%s state=%s base=%s start-point=%s unpublished=%s action=%s\n' \
        "$dir" "${h:-none}" "$st" "${base:-none}" "$sp" "$unp" "$(decide "$st" "$policy" "$sp" "$unp")"
      own=""
      if [[ -f "$d/.sassywares/config.yaml" ]]; then
        own="$(yflat_in "$d/.sassywares/config.yaml" "commit${US}branch" 2>/dev/null || true)"
      fi
      [[ -n "$own" && "$own" != "$policy" ]] && printf 'drift %s: commit.branch=%s\n' "$dir" "$own"
    done < <(nested_repos)
    exit 0
  fi

  head="${HEAD_ARG:-$(git -C "$ROOT" branch --show-current 2>/dev/null || true)}"
  actual="$(git -C "$ROOT" branch --show-current 2>/dev/null || true)"
  [[ -n "$HEAD_ARG" && "$HEAD_ARG" != "$actual" ]] && printf 'checked-out: %s\n' "${actual:-none}"
  printf 'head: %s\n' "${head:-none}"

  state="$(classify "$ROOT" "$head")"
  printf 'state: %s\n' "$state"
  start="$(start_point "$ROOT" "$head")"
  unp=n/a
  [[ "$state" == "on-base" ]] && unp="$(unpublished "$ROOT" "$head")"
  printf 'action: %s\n' "$(decide "$state" "$policy" "$start" "$unp")"
  printf 'start-point: %s\n' "$start"
  printf 'unpublished: %s\n' "$unp"

  # pr-base is provisional for a branch that does not exist yet: the name the
  # skill picks can match a base_map family (release/*, hotfix/*) and retarget
  # the PR. Pass --name once the name is known to get the final answer.
  pr_src=config
  if [[ -n "$NAME_ARG" ]]; then
    pr_base="$(base_for_head "$NAME_ARG" 2>/dev/null || true)"
  elif [[ "$state" == "on-base" || "$state" == "detached" ]]; then
    pr_base="$(repo_base "$ROOT")"
  else
    pr_base="$(base_for_head "$head" 2>/dev/null || true)"
  fi
  if [[ -z "$pr_base" ]]; then
    pr_base="$(detect_base "$ROOT" 2>/dev/null || true)"
    pr_src=probed
  fi
  [[ -n "$pr_base" ]] || pr_src=unknown
  printf 'pr-base: %s\n' "$pr_base"
  printf 'pr-base-source: %s\n' "$pr_src"
  printf 'pr-base-final: %s\n' "$( [[ -n "$NAME_ARG" ]] && printf yes || printf no )"
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
    printf '    # staging: main    # uncomment when a branch releases somewhere else\n'
    printf '    # release/*: main  # a family of heads, longest prefix wins\n'
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
# current: commit on the checked-out branch, even on a base branch, then push
#          it to its upstream. No PR: pr.* and hooks.pr are ignored.
# new: never commit on a base branch — sassy-work, sassy-lfg, and sassy-debug
#      cut a branch at the start of the run and stay on it.
commit:
EOF
kv branch new 34 '# current | new'
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
