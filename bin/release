#!/usr/bin/env bash
# sassy-release v1
# Source: https://github.com/sassywares/sassy-release
# Vendored into each repo as `bin/release`; run it from anywhere inside the
# repo. Refresh the copy when the source's `# sassy-release vN` is newer.
# Safe to re-run: every step is idempotent, so a rerun after any failure
# finishes the release (or says there is nothing to do).
#
# On `main`: fetch tags from origin. The released-tag set is what origin has
# (`git ls-remote --tags`), so a stale local tag that origin lacks never counts;
# a local tag that differs from origin's dies, and a local-only tag at HEAD is
# pushed. If consumer-facing files changed since the highest remote `v*` tag
# (chosen by this script's own version compare), bump the patch
# version, commit `chore: release v<version>`, push main, create the annotated
# tag, push only that tag. A version that is already bumped but has no tag
# (hand-written minor/major bump, interrupted run, first ever release) is
# tagged as-is; a tag that exists only locally is pushed. On any other branch:
# push, never tag.
#
# Version source: package.json `version` (needs node) if present, else a
# VERSION file. Format X.Y.Z without leading zeros. A prerelease suffix
# (X.Y.Z-beta.1) is accepted but never auto-bumped: it is tagged as-is when
# untagged, and if it is already tagged and consumer files changed, the script
# dies and asks you to hand-bump the version file (then rerun).
#
# Ordering: the current version must be >= the highest version tag, and if it
# equals it, that tag must be an ancestor of HEAD.
#
# Ignore list: `bin/release-ignore`, one entry per line, `#` comments.
# Entries are root-anchored path prefixes (`docs/` or `docs`) and bash globs
# (`*.md`; `*` may cross `/`). `!` negation and `**` are unsupported and die.
# A custom file REPLACES the defaults, so re-list `docs/`, `bin/release` etc.
# Default: AGENTS.md docs/ tests/ .sassywares/ .github/ .agents/ .claude/ scripts/
#          bin/release bin/release-ignore (the rest of bin/ counts as consumer-facing)
#
# package.json is re-serialized with its detected indent (like `npm version`).
#
# Never commits anything but the version file, never force-pushes, never
# bypasses signing or hooks; any failure exits non-zero.
set -euo pipefail

export GIT_TERMINAL_PROMPT=0
# Never prompt over SSH, but keep the user's own SSH setup: GIT_SSH_COMMAND, else
# core.sshCommand, else (when only GIT_SSH is set) leave SSH entirely alone.
ssh_base="${GIT_SSH_COMMAND:-$(git config --get core.sshCommand || true)}"
if [ -n "$ssh_base" ] || [ -z "${GIT_SSH:-}" ]; then
  export GIT_SSH_COMMAND="${ssh_base:-ssh} -o BatchMode=yes"
fi

DEFAULT_IGNORE=(AGENTS.md docs/ tests/ .sassywares/ .github/ .agents/ .claude/ scripts/ bin/release bin/release-ignore)
VERSION_RE='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?$'

die() { echo "sassy-release: $*" >&2; exit 1; }
say() { echo "sassy-release: $*"; }

root="$(git rev-parse --show-toplevel 2>/dev/null)" || die "not inside a git repository"
cd "$root"

dirty="$(git status --porcelain --untracked-files=normal)" || die "git status failed"
[ -z "$dirty" ] || die "working tree is dirty; commit or stash first (the work commit must already exist)"
branch="$(git symbolic-ref --short HEAD 2>/dev/null || true)"
[ -n "$branch" ] || die "detached HEAD; check out a branch first"
git remote get-url origin >/dev/null 2>&1 || die "no origin remote"

# ---- version file handling -------------------------------------------------
if [ -f package.json ]; then
  vfile=package.json
  command -v node >/dev/null 2>&1 || die "package.json needs node, which is not installed"
elif [ -f VERSION ]; then
  vfile=VERSION
else
  die "no package.json or VERSION file at the repo root"
fi

read_version() {
  local v
  if [ "$vfile" = VERSION ]; then
    v="$(tr -d '[:space:]' < VERSION)"
  else
    v="$(node -e 'process.stdout.write(String(JSON.parse(require("fs").readFileSync("package.json","utf8")).version))')" \
      || die "could not read package.json"
  fi
  [[ "$v" =~ $VERSION_RE ]] || die "$vfile version '$v' is not X.Y.Z (no leading zeros; optional -prerelease)"
  printf '%s' "$v"
}

write_version() {
  local next="$1"
  if [ "$vfile" = VERSION ]; then
    printf '%s\n' "$next" > VERSION
  else
    node -e '
      const fs = require("fs");
      const raw = fs.readFileSync("package.json", "utf8");
      const m = raw.match(/^\{\r?\n([ \t]+)"/);
      const indent = m ? m[1] : 2;
      const nl = raw.endsWith("\r\n") ? "\r\n" : raw.endsWith("\n") ? "\n" : "";
      const obj = JSON.parse(raw);
      obj.version = process.argv[1];
      let out = JSON.stringify(obj, null, indent);
      if (nl === "\r\n") out = out.replace(/\n/g, "\r\n");
      fs.writeFileSync("package.json", out + nl);
    ' "$next" || die "could not write package.json"
  fi
}

# vcmp A B -> prints -1, 0 or 1 (A relative to B); no prerelease > prerelease.
vcmp() {
  local a="$1" b="$2" ca cb pa pb i
  ca="${a%%-*}"; cb="${b%%-*}"
  pa=""; pb=""
  [ "$a" = "$ca" ] || pa="${a#*-}"
  [ "$b" = "$cb" ] || pb="${b#*-}"
  local -a xa xb
  IFS=. read -r -a xa <<< "$ca"
  IFS=. read -r -a xb <<< "$cb"
  for i in 0 1 2; do
    if (( 10#${xa[i]} > 10#${xb[i]} )); then echo 1; return; fi
    if (( 10#${xa[i]} < 10#${xb[i]} )); then echo -1; return; fi
  done
  if [ "$pa" = "$pb" ]; then echo 0
  elif [ -z "$pa" ]; then echo 1
  elif [ -z "$pb" ]; then echo -1
  elif [ "$(printf '%s\n%s\n' "$pa" "$pb" | sort -V | head -n 1)" = "$pa" ]; then echo -1
  else echo 1; fi
}

# ---- consumer-facing change detection ---------------------------------------
ignores=()
if [ -f bin/release-ignore ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [ -n "$line" ] || continue
    case "$line" in
      '!'*) die "release-ignore: '!' negation is unsupported: $line" ;;
      *'**'*) die "release-ignore: '**' is unsupported (a single * already crosses /): $line" ;;
    esac
    ignores+=("${line#/}")
  done < bin/release-ignore
else
  ignores=("${DEFAULT_IGNORE[@]}")
fi

is_ignored() {
  local path="$1" pat
  for pat in ${ignores[@]+"${ignores[@]}"}; do
    case "$pat" in
      */) [[ "$path" == "$pat"* ]] && return 0 ;;
      *[*?[]*) [[ "$path" == $pat ]] && return 0 ;;
      *) [ "$path" = "$pat" ] && return 0
         [[ "$path" == "$pat"/* ]] && return 0 ;;
    esac
  done
  return 1
}

diff_empty=0
consumer_changes() {
  local tag="$1" changed path
  changed="$(git -c core.quotePath=false diff --name-only --no-renames "$tag" HEAD)" \
    || die "could not diff $tag..HEAD; refusing to guess"
  [ -n "$changed" ] || diff_empty=1
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    is_ignored "$path" || return 0
  done <<< "$changed"
  return 1
}

# ---- git helpers ------------------------------------------------------------
local_tag_id() { git rev-parse -q --verify "refs/tags/v$1" 2>/dev/null || true; }

remote_tag_id() { # prints the remote tag object id, empty if absent; dies if origin is unreachable
  local out
  out="$(git ls-remote --tags origin "refs/tags/v$1")" || die "could not query origin for tag v$1"
  printf '%s\n' "$out" | awk -v r="refs/tags/v$1" '$2 == r { print $1 }'
}

push_branch() { # $1: failure suffix
  git push origin "$branch" || die "could not push $branch (not fast-forward or no access)$1"
}

push_tag() {
  local v="$1" lid rid
  git push origin "refs/tags/v$v" || die "could not push tag v$v; it exists locally, rerun to retry"
  lid="$(local_tag_id "$v")"
  rid="$(remote_tag_id "$v")"
  [ -n "$rid" ] && [ "$rid" = "$lid" ] || die "tag v$v on origin ('${rid:-missing}') does not match local ('$lid') after pushing"
}

# ---- non-main: push only ----------------------------------------------------
if [ "$branch" != "main" ]; then
  push_branch "; pull or rebase, then retry"
  say "pushed $branch, release happens on main"
  exit 0
fi

# ---- main: tag state comes from the remote ----------------------------------
git fetch --tags origin \
  || die "could not fetch tags from origin (network/auth, or a local tag differs from origin's; if so compare with 'git ls-remote --tags origin' and delete the wrong local tag with 'git tag -d')"

version="$(read_version)"
head_commit="$(git rev-parse HEAD)"
lid="$(local_tag_id "$version")"
rid="$(remote_tag_id "$version")"

if [ -n "$rid" ]; then
  [ -n "$lid" ] || die "tag v$version is on origin but missing locally after fetch; investigate"
  [ "$rid" = "$lid" ] || die "tag v$version differs between local ($lid) and origin ($rid); decide which is right, then delete the wrong one ('git tag -d v$version' locally, or ask a maintainer to fix origin) and rerun"
elif [ -n "$lid" ]; then
  # Local-only tag (an earlier tag push failed): push it if it is this release.
  tcommit="$(git rev-parse "refs/tags/v$version^{commit}")"
  [ "$tcommit" = "$head_commit" ] \
    || die "local-only tag v$version points at $tcommit, not HEAD ($head_commit); if it is stale delete it with 'git tag -d v$version' and rerun"
  push_branch "; nothing was tagged"
  push_tag "$version"
  say "released v$version (pushed the existing local tag)"
  exit 0
fi

# Highest released version tag: from origin, ordered by vcmp (not git's sorting).
remote_all="$(git ls-remote --tags origin)" || die "could not list tags on origin"
highest=""
while IFS= read -r t; do
  [[ "${t#v}" =~ $VERSION_RE ]] || continue
  if [ -z "$highest" ] || [ "$(vcmp "${t#v}" "${highest#v}")" = 1 ]; then highest="$t"; fi
done < <(printf '%s\n' "$remote_all" | awk '$2 ~ /^refs\/tags\/v/ && $2 !~ /\^\{\}$/ { sub("refs/tags/", "", $2); print $2 }')
if [ -n "$highest" ]; then
  git rev-parse -q --verify "refs/tags/$highest^{commit}" >/dev/null \
    || die "$highest is on origin but missing locally after fetch; investigate"
fi

release=""
if [ -z "$highest" ]; then
  release="$version"                       # first release: tag as-is
else
  hv="${highest#v}"
  cmp="$(vcmp "$version" "$hv")"
  if [ "$cmp" = -1 ]; then
    die "version $version is lower than the highest tag $highest; fix the version file"
  elif [ "$cmp" = 1 ]; then
    release="$version"                     # already bumped, untagged
  else
    git merge-base --is-ancestor "$highest" HEAD \
      || die "$highest is not an ancestor of HEAD although the version equals it; history diverged from the tag"
    if consumer_changes "$highest"; then
      case "$version" in
        *-*) die "$version is a prerelease and consumer files changed since $highest; the script never bumps a prerelease: set the next version by hand, commit, rerun" ;;
      esac
      IFS=. read -r mj mn pt <<< "$version"
      next="$mj.$mn.$(( 10#$pt + 1 ))"
      nl_id="$(local_tag_id "$next")"
      nr_id="$(remote_tag_id "$next")"   # dies if origin is unreachable (fail closed)
      { [ -z "$nl_id" ] && [ -z "$nr_id" ]; } \
        || die "v$next already exists (locally or on origin); fix the version file or tags"
      write_version "$next"
      if ! out="$(git add -- "$vfile" && git commit -q -m "chore: release v$next" 2>&1)"; then
        git reset -q HEAD -- "$vfile" >/dev/null 2>&1 || true
        git checkout -- "$vfile" >/dev/null 2>&1 || true
        die "could not commit the version bump (tree restored): $out"
      fi
      release="$(read_version)"
      [ "$release" = "$next" ] || die "version bump did not produce $next"
    fi
  fi
fi

if [ -z "$release" ]; then
  if [ "$diff_empty" = 1 ]; then
    say "nothing to release (nothing changed since $highest)"
  else
    say "nothing to release (only ignored paths changed since $highest)"
  fi
  exit 0
fi

push_branch "; nothing was tagged"
git tag -a "v$release" -m "v$release" || die "could not create tag v$release"
push_tag "$release"
say "released v$release"
