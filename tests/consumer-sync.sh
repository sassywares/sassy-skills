#!/usr/bin/env bash
# The consumer-sync contract: mirror exactly the roster, repin it, push once.
#
# This is the hook that reaches projects which vendor the suite themselves. Three
# failures here are silent until someone notices months later:
#
#   * the mirror is too wide — it deletes the project's own skills, or copies a
#     skill the roster no longer names;
#   * the lock is rewritten whole — a foreign pin (`convex-*`) loses its hash, or
#     the `version` era changes, and the next `skills check` reports drift;
#   * a dry run, a skipped consumer, or a rejected push quietly writes anyway.
#
# Every fixture is a throwaway repo with a real `git init --bare` origin. The
# source repo is a copy of this repo's skills, so the hashes asserted here come
# from `skills/sassy-setup/scripts/hash-skill.mjs` — never a second hash.
#
# Self-contained, offline, bash 3.2.
set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SYNC=""   # set to the fixture copy below — never run the real one in a test
REAL_SYNC="$REPO/.agents/skills/sassy-skills-sync/scripts/sync"
HASH="$REPO/skills/sassy-setup/scripts/hash-skill.mjs"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/sassy-consumer-sync.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
fails=0
pass() { printf 'ok   %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1"; [[ -n "${2:-}" ]] && printf '%s\n' "$2" | sed 's/^/     /'; fails=$((fails + 1)); }

expect() { # expect <name> <expected> <actual>
  if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "$(printf -- '--- expected ---\n%s\n--- actual ---\n%s' "$2" "$3")"; fi
}
expect_rc() { # expect_rc <name> <expected> <actual>
  if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "expected exit $2, got $3"; fi
}
expect_contains() { # expect_contains <name> <needle> [haystack]
  case "${3:-}" in
    *"$2"*) pass "$1" ;;
    *) fail "$1" "missing: $2"$'\n'"${3:-}" ;;
  esac
}
expect_not_contains() { # expect_not_contains <name> <needle> [haystack]
  case "${3:-}" in
    *"$2"*) fail "$1" "unexpected: $2"$'\n'"${3:-}" ;;
    *) pass "$1" ;;
  esac
}

git_q() { git -c user.name=test -c user.email=test@example.invalid "$@"; }

# Every sync run gets a hard ceiling: a hung detect.sh or push must fail the test,
# not the suite.
run_sync() { # [--write]
  if command -v timeout >/dev/null 2>&1; then
    timeout 300 "$SYNC" "$@"
  else
    "$SYNC" "$@"
  fi
}

hash_of() { # hash_of <skill-dir> — the CLI-compatible folder hash, imported
  node --input-type=module -e '
    import { pathToFileURL } from "node:url";
    const mod = await import(pathToFileURL(process.argv[1]).href);
    process.stdout.write(await mod.hashSkillFolder(process.argv[2]));
  ' "$HASH" "$1"
}

lock_version() {
  node -e 'process.stdout.write(String(require(process.argv[1]).version))' "$1"
}
lock_field() { # lock_field <lock> <field> <name> — "<missing>" when absent
  node -e '
    const lock = require(process.argv[1]);
    const entry = lock.skills && lock.skills[process.argv[3]];
    const value = entry && entry[process.argv[2]];
    process.stdout.write(value === undefined ? "<missing>" : String(value));
  ' "$1" "$2" "$3"
}

# --- fixture source --------------------------------------------------------
SRC="$TMP/src"
mkdir -p "$SRC/.sassywares" "$SRC/.agents/skills/sassy-skills-sync"
cp -R "$REPO/skills" "$SRC/skills"
cp -R "$REPO/.agents/skills/sassy-skills-sync/scripts" "$SRC/.agents/skills/sassy-skills-sync/scripts"
chmod +x "$SRC/.agents/skills/sassy-skills-sync/scripts/sync"
# Run the fixture's copy: the engine resolves its source repo from its own
# location, so the real one would read the real registry.
SYNC="$SRC/.agents/skills/sassy-skills-sync/scripts/sync"
printf '{ "name": "fixture-source", "version": "9.9.9" }\n' > "$SRC/package.json"
printf 'commit:\n  branch: current\n' > "$SRC/.sassywares/config.yaml"
printf 'fixture source\n' > "$SRC/README.md"
set_registry() { printf '%s\n' "$@" > "$SRC/.sassywares/consumers"; }
set_registry "$TMP/consumer-one staging"
git_q init -q "$SRC"
git_q -C "$SRC" add -A
git_q -C "$SRC" commit -qm "fixture source"
SRC_HEAD="$(git -C "$SRC" rev-parse HEAD)"
HEAD7="${SRC_HEAD:0:7}"
MARKER="$SRC/.sassywares/last-synced-head"
ROSTER="$SRC/skills/sassy-setup/assets/roster"

# The lock a per-project install would have: every directory pinned, one foreign
# source, one entry for a suite skill that has since left the roster, and a wrong
# hash on the one skill whose copy is stale.
cat > "$TMP/mklock.mjs" <<'JS'
import { readFile, readdir, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const [dir, src] = process.argv.slice(2);
const { hashSkillFolder } = await import(
  pathToFileURL(join(src, "skills/sassy-setup/scripts/hash-skill.mjs")).href
);
const skills = {};
const names = (await readdir(join(dir, ".agents/skills"))).sort();
for (const name of names) {
  const folder = join(dir, ".agents/skills", name);
  if (name === "convex-demo") {
    skills[name] = {
      source: "convex/agent-skills",
      sourceType: "github",
      skillPath: `skills/${name}/SKILL.md`,
      computedHash: "c".repeat(64),
      commit: "1234567890abcdef1234567890abcdef12345678",
    };
    continue;
  }
  const stale = name === "sassy-commit" || name === "sassy-retired";
  skills[name] = {
    source: "sassywares/sassy-skills",
    sourceType: "github",
    skillPath: `skills/${name}/SKILL.md`,
    computedHash: stale ? "0".repeat(64) : await hashSkillFolder(folder),
    commit: "0".repeat(40),
  };
}
await writeFile(join(dir, "skills-lock.json"), `${JSON.stringify({ version: 2, skills }, null, 2)}\n`);
JS

# --- fixture consumers -----------------------------------------------------
consumer_skeleton() { # $1 dir, $2 branch — a repo with origin, config, and a push
  local dir="$1" branch="$2" bare
  bare="$TMP/$(basename "$dir")-origin.git"
  git_q init -q --bare "$bare"
  git_q init -q "$dir"
  git_q -C "$dir" config user.name test
  git_q -C "$dir" config user.email test@example.invalid
  git_q -C "$dir" remote add origin "$bare"
  mkdir -p "$dir/.sassywares"
  cat > "$dir/.sassywares/config.yaml" <<EOF
git:
  repo: origin
commit:
  branch: current
worktrees:
  enabled: true
  dir: $TMP/wt
EOF
  printf 'readme\n' > "$dir/README.md"
  git_q -C "$dir" add -A
  git_q -C "$dir" commit -qm "vendor the suite"
  git_q -C "$dir" branch -M "$branch"
  git_q -C "$dir" push -q -u origin "$branch"
}

vendor_consumer() { # $1 dir — stale sassy copy, a missing roster skill, a foreign skill
  local dir="$1" name
  mkdir -p "$dir/.agents/skills"
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    # sassy-overview is newer than this consumer's last update.
    [ "$name" = "sassy-overview" ] && continue
    cp -R "$SRC/skills/$name" "$dir/.agents/skills/$name"
  done < "$ROSTER"
  printf '\nstale copy from an older push\n' >> "$dir/.agents/skills/sassy-commit/SKILL.md"
  mkdir -p "$dir/.agents/skills/convex-demo" "$dir/.agents/skills/sassy-retired"
  printf '# a project skill the roster must never touch\n' > "$dir/.agents/skills/convex-demo/SKILL.md"
  printf '# a suite skill that left the roster\n' > "$dir/.agents/skills/sassy-retired/SKILL.md"
  node "$TMP/mklock.mjs" "$dir" "$SRC"
  git_q -C "$dir" add -A
  git_q -C "$dir" commit -qm "pin the vendored suite"
  git_q -C "$dir" push -q origin HEAD
}

C1="$TMP/consumer-one"
consumer_skeleton "$C1" staging
vendor_consumer "$C1"
BARE1="$TMP/consumer-one-origin.git"
C1_HEAD="$(git -C "$C1" rev-parse HEAD)"

C2="$TMP/consumer-two"
consumer_skeleton "$C2" staging
C2_HEAD="$(git -C "$C2" rev-parse HEAD)"

C3="$TMP/consumer-three"
consumer_skeleton "$C3" staging
vendor_consumer "$C3"
BARE3="$TMP/consumer-three-origin.git"
C3_HEAD="$(git -C "$C3" rev-parse HEAD)"
# Reject every push the way a protected branch would.
mkdir -p "$BARE3/hooks"
printf '#!/bin/sh\nexit 1\n' > "$BARE3/hooks/pre-receive"
chmod +x "$BARE3/hooks/pre-receive"

# consumer-four: its remote-tracking ref is deliberately stale. A second clone
# pushes to the origin, so the consumer's `origin/staging` still names the old
# head and its local branch never moves. The engine must fetch before cutting.
C4="$TMP/consumer-four"
consumer_skeleton "$C4" staging
vendor_consumer "$C4"
BARE4="$TMP/consumer-four-origin.git"
C4_HEAD="$(git -C "$C4" rev-parse HEAD)"
git_q clone -q --branch staging "$BARE4" "$TMP/second-four"
printf 'a commit another clone pushed\n' >> "$TMP/second-four/README.md"
git_q -C "$TMP/second-four" commit -qam "feat: advance the remote"
git_q -C "$TMP/second-four" push -q origin staging
C4_REMOTE="$(git -C "$BARE4" rev-parse refs/heads/staging)"
# Prove the fixture is the bug: the consumer's ref lags the origin.
[ "$C4_HEAD" = "$(git -C "$C4" rev-parse origin/staging)" ]
[ "$C4_HEAD" != "$C4_REMOTE" ] || { fail "the stale-ref fixture is stale"; }

# consumer-five: the origin accepts the second push only. A marker file in the
# hook makes the rejection happen exactly once.
C5="$TMP/consumer-five"
consumer_skeleton "$C5" staging
vendor_consumer "$C5"
BARE5="$TMP/consumer-five-origin.git"
C5_HEAD="$(git -C "$C5" rev-parse HEAD)"
mkdir -p "$BARE5/hooks"
cat > "$BARE5/hooks/pre-receive" <<EOF
#!/bin/sh
if [ ! -f "$TMP/consumer-five-rejected-once" ]; then
  : > "$TMP/consumer-five-rejected-once"
  echo "rejecting the first push" >&2
  exit 1
fi
exit 0
EOF
chmod +x "$BARE5/hooks/pre-receive"

# 1. A malformed registry line is an error that names the line — never a silent
#    skip of the consumer it was trying to declare.
set_registry "only-one-field"
out="$(run_sync --write 2>&1)"; rc=$?
expect_rc "a malformed registry line fails the run" 2 "$rc"
expect_contains "the error names the offending line" 'line 1 is not "<path> <branch>": only-one-field' "$out"

# 2. Dry run: the plan is printed and nothing changes — no checkout, no commit,
#    no marker.
set_registry "$C1 staging" "$C2 nope"
out="$(run_sync 2>&1)"; rc=$?
expect_rc "a dry run exits 0" 0 "$rc"
expect_contains "the dry run plans to add the missing roster skill" "sassy-overview" "$out"
expect_contains "the dry run plans to update the stale skill" "sassy-commit" "$out"
expect_contains "the dry run plans to delete the retired skill" "sassy-retired" "$out"
expect_contains "the dry run says it would push" "would push" "$out"
expect_contains "the dry run reports the consumer it cannot reach" "origin/nope does not resolve" "$out"
expect "a dry run leaves the consumer's branch untouched" "$C1_HEAD" "$(git -C "$C1" rev-parse staging)"
expect "a dry run leaves the consumer clean" "" "$(git -C "$C1" status --porcelain)"
[ ! -f "$MARKER" ] && pass "a dry run writes no marker" || fail "a dry run writes no marker"
[ ! -d "$TMP/wt/consumer-one" ] && pass "a dry run cuts no checkout" || fail "a dry run cuts no checkout"

# 3. Write run: consumer-one syncs, consumer-two is skipped with a reason.
out="$(run_sync --write 2>&1)"; rc=$?
expect_rc "the write run exits 0 with a skipped consumer" 0 "$rc"
expect_contains "the skipped consumer says why" "skipped" "$out"
expect "consumer-two was not touched" "$C2_HEAD" "$(git -C "$C2" rev-parse HEAD)"
expect "the sync commit is on the consumer's branch on origin" \
  "$(git -C "$C1" rev-parse origin/staging)" "$(git -C "$BARE1" rev-parse refs/heads/staging)"
expect_contains "the commit message names the version and head" \
  "chore: sync sassy skills to v9.9.9 ($HEAD7)" "$(git -C "$BARE1" log -1 --format=%s staging)"
C1_SYNCED="$(git -C "$BARE1" rev-parse refs/heads/staging)"

# The pushed tree is the contract: inspect a fresh clone, not the checkout we
# just removed.
git -c advice.detachedHead=false clone -q --branch staging "$BARE1" "$TMP/inspect"
PUSHED="$TMP/inspect"

if diff -r "$SRC/skills/sassy-commit" "$PUSHED/.agents/skills/sassy-commit" >/dev/null 2>&1; then
  pass "a stale roster skill is replaced byte for byte"
else
  fail "a stale roster skill is replaced byte for byte" "$(diff -r "$SRC/skills/sassy-commit" "$PUSHED/.agents/skills/sassy-commit" | head -n 5)"
fi
[ -d "$PUSHED/.agents/skills/sassy-overview" ] \
  && pass "a missing roster skill is added" || fail "a missing roster skill is added"
[ ! -e "$PUSHED/.agents/skills/sassy-retired" ] \
  && pass "a roster skill that left the suite is deleted" || fail "a roster skill that left the suite is deleted"
if diff -r "$C1/.agents/skills/convex-demo" "$PUSHED/.agents/skills/convex-demo" >/dev/null 2>&1; then
  pass "a non-roster skill is left byte for byte"
else
  fail "a non-roster skill is left byte for byte"
fi
case "$(ls "$PUSHED/.agents/skills")" in
  *convex-demo*) pass "the non-roster skill survives the mirror" ;;
  *) fail "the non-roster skill survives the mirror" ;;
esac

LOCK="$PUSHED/skills-lock.json"
expect "the lock keeps its version era" "2" "$(lock_version "$LOCK")"
expect "a foreign source keeps its hash" "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc" \
  "$(lock_field "$LOCK" computedHash convex-demo)"
expect "a foreign source keeps its commit" "1234567890abcdef1234567890abcdef12345678" \
  "$(lock_field "$LOCK" commit convex-demo)"
expect "a foreign source keeps its source" "convex/agent-skills" \
  "$(lock_field "$LOCK" source convex-demo)"
expect "a roster skill is repinned to this repo's head" "$SRC_HEAD" \
  "$(lock_field "$LOCK" commit sassy-commit)"
expect "a roster skill's hash matches the CLI-compatible hash" "$(hash_of "$SRC/skills/sassy-commit")" \
  "$(lock_field "$LOCK" computedHash sassy-commit)"
expect "an added roster skill is pinned too" "$(hash_of "$SRC/skills/sassy-overview")" \
  "$(lock_field "$LOCK" computedHash sassy-overview)"
expect "an added roster skill names its path" "skills/sassy-overview/SKILL.md" \
  "$(lock_field "$LOCK" skillPath sassy-overview)"
expect "a retired skill's entry is dropped" "<missing>" "$(lock_field "$LOCK" source sassy-retired)"

expect "no checkout of ours is left registered" "1" \
  "$(git -C "$C1" worktree list --porcelain | grep -c '^worktree ')"
[ ! -d "$TMP/wt/consumer-one/skills-sync-$HEAD7" ] \
  && pass "no checkout of ours is left on disk" || fail "no checkout of ours is left on disk"
if git -C "$C1" rev-parse --verify --quiet "refs/heads/skills-sync-$HEAD7" >/dev/null; then
  fail "the scratch branch is deleted"
else
  pass "the scratch branch is deleted"
fi
expect "the run advanced last-synced-head" "$SRC_HEAD" "$(tr -d '[:space:]' < "$MARKER")"

# 4. A second run over the same range against an unchanged consumer commits
#    nothing and says so. Deleting the marker replays the same range, which is
#    what an interrupted run looks like.
rm -f "$MARKER"
out="$(run_sync --write 2>&1)"; rc=$?
expect_rc "a replay exits 0" 0 "$rc"
expect_contains "an unchanged consumer reports already current" "already current" "$out"
expect "an unchanged consumer gains no commit" "$(git -C "$BARE1" rev-parse refs/heads/staging)" \
  "$(git -C "$C1" rev-parse origin/staging)"

# 5. A push rejected twice blocks: the first attempt is discarded, one checkout
#    (the retry) is kept, the marker does not advance, and the run fails so the
#    close-out stops.
set_registry "$C3 staging"
rm -f "$MARKER"
out="$(run_sync --write 2>&1)"; rc=$?
expect_rc "a rejected push fails the run" 1 "$rc"
expect_contains "the rejected push is reported as blocked" "blocked" "$out"
expect_contains "the rejected push names the kept checkout" "skills-sync-$HEAD7-r2" "$out"
expect_contains "a rejected push reports its one retry" "(1 retry)" "$out"
expect "the rejected push moved nothing on origin" "$C3_HEAD" "$(git -C "$BARE3" rev-parse refs/heads/staging)"
expect "a blocked consumer keeps exactly one checkout" "2" \
  "$(git -C "$C3" worktree list --porcelain | grep -c '^worktree ')"
expect "a blocked consumer leaves no discarded attempt on disk" "absent" \
  "$([ -e "$TMP/wt/consumer-three/skills-sync-$HEAD7" ] && echo present || echo absent)"
[ -d "$TMP/wt/consumer-three/skills-sync-$HEAD7-r2" ] \
  && pass "a blocked consumer keeps its retry checkout on disk" || fail "a blocked consumer keeps its retry checkout on disk"
git -C "$C3" rev-parse --verify --quiet "refs/heads/skills-sync-$HEAD7-r2" >/dev/null \
  && pass "a blocked consumer keeps its scratch branch" || fail "a blocked consumer keeps its scratch branch"
git -C "$C3" rev-parse --verify --quiet "refs/heads/skills-sync-$HEAD7" >/dev/null \
  && fail "the discarded attempt's branch is deleted" || pass "the discarded attempt's branch is deleted"
[ ! -f "$MARKER" ] && pass "a blocked run does not advance the marker" || fail "a blocked run does not advance the marker"

# 6. A range that did not touch skills/ does nothing at all.
printf 'a doc change\n' >> "$SRC/README.md"
git_q -C "$SRC" commit -qam "chore: docs only"
SRC_CUR="$(git -C "$SRC" rev-parse HEAD)"
printf '%s\n' "$SRC_HEAD" > "$MARKER"
set_registry "$C1 staging"
out="$(run_sync --write 2>&1)"; rc=$?
expect_rc "a range without skills/ exits 0" 0 "$rc"
expect_contains "a range without skills/ reports nothing to sync" "nothing to sync" "$out"
expect "a range without skills/ does not touch a consumer" "$C1_SYNCED" "$(git -C "$BARE1" rev-parse refs/heads/staging)"
expect "a range without skills/ leaves the marker alone" "$SRC_HEAD" "$(tr -d '[:space:]' < "$MARKER")"

# 7. A stale remote-tracking ref is refreshed before the cut: the sync commit
#    lands on top of the origin's newer head, as a fast-forward, never a force.
set_registry "$C4 staging"
rm -f "$MARKER"
out="$(run_sync --write 2>&1)"; rc=$?
expect_rc "a stale remote-tracking ref still syncs" 0 "$rc"
expect_contains "the stale-ref run pushes" "pushed" "$out"
expect_not_contains "the stale-ref run does not retry" "retry" "$out"
expect "the sync commit lands on the origin's newer head" "$C4_REMOTE" \
  "$(git -C "$BARE4" rev-parse refs/heads/staging^)"
expect_contains "the pushed commit is the sync commit" \
  "chore: sync sassy skills to v9.9.9 (${SRC_CUR:0:7})" "$(git -C "$BARE4" log -1 --format=%s staging)"
expect "the stale-ref push forced nothing" "$C4_REMOTE" \
  "$(git -C "$BARE4" merge-base refs/heads/staging "$C4_REMOTE")"
expect "the stale-ref consumer advanced its own ref" "$(git -C "$BARE4" rev-parse refs/heads/staging)" \
  "$(git -C "$C4" rev-parse origin/staging)"
expect "the stale-ref run advanced last-synced-head" "$SRC_CUR" "$(tr -d '[:space:]' < "$MARKER")"

# 8. One bounded retry: the origin rejects the first push only. The attempt is
#    replayed on a refreshed head under a distinct slug and succeeds.
set_registry "$C5 staging"
rm -f "$MARKER"
out="$(run_sync --write 2>&1)"; rc=$?
expect_rc "a once-rejected push is retried and succeeds" 0 "$rc"
expect_contains "the retried run reports its retry" "(1 retry)" "$out"
expect_contains "the retried run reports the push" "pushed" "$out"
expect "the retried push lands on the origin" "$C5_HEAD" \
  "$(git -C "$BARE5" rev-parse refs/heads/staging^)"
expect_contains "the retried push is the sync commit" \
  "chore: sync sassy skills to v9.9.9 (${SRC_CUR:0:7})" "$(git -C "$BARE5" log -1 --format=%s staging)"
expect "the retried run leaves no checkout registered" "1" \
  "$(git -C "$C5" worktree list --porcelain | grep -c '^worktree ')"
git -C "$C5" rev-parse --verify --quiet "refs/heads/skills-sync-$HEAD7" >/dev/null \
  && fail "the retried run deletes its first scratch branch" || pass "the retried run deletes its first scratch branch"
git -C "$C5" rev-parse --verify --quiet "refs/heads/skills-sync-$HEAD7-r2" >/dev/null \
  && fail "the retried run deletes its retry scratch branch" || pass "the retried run deletes its retry scratch branch"
expect "the retried run advanced last-synced-head" "$SRC_CUR" "$(tr -d '[:space:]' < "$MARKER")"

printf '\n%s\n' "fails: $fails"
[ "$fails" -eq 0 ]
