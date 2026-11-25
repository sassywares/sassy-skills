#!/usr/bin/env bash
# The worktree toolbox contract: identity on stdout, mechanics in git.
#
# Three bugs live here because each one is silent until far too late:
#
#   * `git worktree add -b <branch> <path> <start-point>` follows the DWIM rule:
#     cut from a remote-tracking ref and the branch tracks it, so the branch's own
#     `git push` aims at the base. Nothing prints until someone pushes at staging.
#   * `create` used to narrate on stdout, so a caller could not eval its identity.
#   * a configured `remove` script that is gone used to fail or vanish; the
#     contract is a built-in fallback with a named warning (D3).
#
# The mutation check at the end proves the upstream assertion is load-bearing:
# delete `--no-track` from a copy and the branch MUST inherit its base. If the
# mutant still comes out untracked, the test would not catch the real regression
# and says so instead of passing.
#
# Self-contained, offline, bash 3.2.
set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
ASSETS="$REPO/skills/sassy-setup/assets/worktree"
DETECT="$REPO/skills/sassy-setup/scripts/detect.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/sassy-worktree.XXXXXX")"
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

# A main checkout with one commit on a real remote: `origin/main` has to exist,
# because that is the ref whose DWIM behaviour is under test.
MAIN="$TMP/main"
git_q init -q --bare "$TMP/remote.git"
git_q init -q "$MAIN"
cd "$MAIN" || exit 1
git_q remote add origin "$TMP/remote.git"
printf 'readme\n' > README.md
git_q add -A
git_q commit -qm "init"
git_q branch -M main
git_q push -q -u origin main
MAIN_REAL="$(cd "$MAIN" && pwd -P)"

mkdir -p "$MAIN/.sassywares/worktree"
cp "$ASSETS"/* "$MAIN/.sassywares/worktree/"
chmod +x "$MAIN"/.sassywares/worktree/*
printf 'worktrees:\n  enabled: true\n  dir: %s/worktrees\n' "$TMP" > "$MAIN/.sassywares/config.yaml"
# The config has to be on origin/main: `create` cuts from there, and a checkout
# without .sassywares/config.yaml is not managed here — `list` would skip it.
git_q add .sassywares/config.yaml
git_q commit -qm "add the sassywares config"
git_q push -q origin main

WT="$MAIN/.sassywares/worktree/create"
LIST="$MAIN/.sassywares/worktree/list"
REMOVE="$MAIN/.sassywares/worktree/remove"

# 1. `create` puts exactly the four identity lines on stdout and every human
#    line on stderr, so a caller can eval stdout while a person reads the rest.
"$WT" feat/thing --from origin/main >"$TMP/create.out" 2>"$TMP/create.err"; rc=$?
expect_rc "create exits 0" 0 "$rc"
expected_home="$(cd "$(dirname "$TMP/worktrees/main")" && pwd -P)/main"
expected="WT_PATH=$expected_home/feat-thing
WT_BRANCH=feat/thing
WT_SLUG=feat-thing
WT_NAMESPACE=main-feat-thing"
expect "create prints exactly the four WT_* identity lines" "$expected" "$(cat "$TMP/create.out")"
expect_contains "create narrates on stderr, not stdout" "namespace" "$(cat "$TMP/create.err")"
[ -d "$expected_home/feat-thing" ] && pass "the checkout exists" || fail "the checkout exists"

# 2. A second call reports the same checkout instead of cutting a new one.
"$WT" feat/thing >"$TMP/create2.out" 2>/dev/null; rc=$?
expect_rc "re-running create exits 0" 0 "$rc"
expect "a reused checkout prints the same identity" "$expected" "$(cat "$TMP/create2.out")"
# A reused checkout must still have no upstream: the first call is the one that
# cuts the branch, and a regression there would only show up on the branch's own
# push.
expect "the reused checkout has no branch remote" "" "$(git -C "$MAIN" config --get branch.feat/thing.remote || true)"
expect "the reused checkout has no branch merge" "" "$(git -C "$MAIN" config --get branch.feat/thing.merge || true)"

# 3. A branch that already tracks the base is called out — the state a run cut by
#    hand lands in, and the one that reads as healthy until the first push.
#    `create` reuses the branch it finds and must not silently retarget it.
git_q branch --track feat/inherited origin/main >/dev/null 2>&1 || git_q branch feat/inherited origin/main
"$WT" feat/inherited >"$TMP/inh.out" 2>"$TMP/inh.err"; rc=$?
expect_rc "create on a tracking branch exits 0" 0 "$rc"
expect_contains "a branch tracking the base is called out" "a plain 'git push' lands there" "$(cat "$TMP/inh.err")"
inherited_merge="$(git -C "$MAIN" config --get branch.feat/inherited.merge || true)"
expect "a branch cut from a base-tracking ref keeps that base, called out not retargeted" "refs/heads/main" "$inherited_merge"

# 4. `list --env` hands back byte-identical identity — one formatter, so the two
#    commands cannot drift.
"$LIST" --env feat/thing >"$TMP/env.out" 2>/dev/null; rc=$?
expect_rc "list --env exits 0" 0 "$rc"
expect "list --env is byte-identical to what create printed" "$expected" "$(cat "$TMP/env.out")"

# 5. `list` classifies what is safe to remove: merged, unmerged, or gone.
"$WT" feat/merged --from origin/main >/dev/null 2>&1
git_q -C "$MAIN" branch --set-upstream-to=origin/main feat/merged >/dev/null 2>&1
"$WT" feat/unmerged --from origin/main >/dev/null 2>&1
unmerged_path="$("$LIST" --path feat-unmerged)"
printf 'local change\n' > "$unmerged_path/change.txt"
git_q -C "$unmerged_path" add -A
git_q -C "$unmerged_path" commit -qm "local work"
git_q -C "$unmerged_path" branch --set-upstream-to=origin/main feat/unmerged >/dev/null 2>&1
"$WT" feat/gone --from origin/main >/dev/null 2>&1
"$LIST" >"$TMP/list.out" 2>/dev/null
state_of() { awk -v b="$1" '$1 == b { print $NF; exit }' "$TMP/list.out"; }
expect "list shows a merged checkout as merged" "merged" "$(state_of feat/merged)"
expect "list shows an unmerged checkout as unmerged" "unmerged" "$(state_of feat/unmerged)"
expect "list shows an upstream-less checkout as gone" "gone" "$(state_of feat/gone)"

# 6. `list --env` refuses to guess. Two branches can slug to one name, and a
#    silent first pick would hand a caller another branch's checkout.
git_q worktree add -q --no-track -b feat/x "$TMP/extra/x" origin/main
git_q worktree add -q --no-track -b feat-x "$TMP/extra/xx" origin/main
"$LIST" --env feat-x >/dev/null 2>"$TMP/amb.err"; rc=$?
[ "$rc" -ne 0 ] && pass "an ambiguous list --env exits non-zero" || fail "an ambiguous list --env exits non-zero"
expect_contains "the ambiguity names both matches" "matches 2 worktrees" "$(cat "$TMP/amb.err")"
"$LIST" --env no-such-checkout >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] && pass "an unknown list --env exits non-zero" || fail "an unknown list --env exits non-zero"

# 7. `remove` takes the checkout, keeps the branch, and guards what would be lost.
"$REMOVE" feat/thing >"$TMP/rm.out" 2>"$TMP/rm.err"; rc=$?
expect_rc "remove exits 0 with no obligation flag" 0 "$rc"
expect "remove writes nothing to stdout" "" "$(cat "$TMP/rm.out")"
[ ! -d "$expected_home/feat-thing" ] && pass "remove deletes the checkout" || fail "remove deletes the checkout"
git -C "$MAIN" rev-parse --verify --quiet refs/heads/feat/thing >/dev/null \
  && pass "remove leaves the branch behind" || fail "remove leaves the branch behind"

"$WT" feat/dirty --from origin/main >/dev/null 2>&1
dirty_path="$("$LIST" --path feat-dirty)"
printf 'local work\n' > "$dirty_path/scratch.txt"
"$REMOVE" feat/dirty >/dev/null 2>"$TMP/dirty.err"; rc=$?
[ "$rc" -ne 0 ] && pass "a dirty checkout refuses removal" || fail "a dirty checkout refuses removal"
expect_contains "the dirty refusal says what blocks it" "not clean" "$(cat "$TMP/dirty.err")"
[ -d "$dirty_path" ] && pass "the refused checkout is still there" || fail "the refused checkout is still there"

"$WT" feat/unpushed --from origin/main >/dev/null 2>&1
unpushed_path="$("$LIST" --path feat-unpushed)"
printf 'unpushed work\n' > "$unpushed_path/work.txt"
git_q -C "$unpushed_path" add -A
git_q -C "$unpushed_path" commit -qm "unpushed"
"$REMOVE" feat/unpushed >/dev/null 2>"$TMP/unpushed.err"; rc=$?
[ "$rc" -ne 0 ] && pass "an unpushed commit refuses removal" || fail "an unpushed commit refuses removal"
expect_contains "the unpushed refusal names the commits" "are on no remote" "$(cat "$TMP/unpushed.err")"
[ -d "$unpushed_path" ] && pass "the unpushed checkout is still there" || fail "the unpushed checkout is still there"

# 7b. A worktrees.dir containing a space must survive the identity block: every
#     caller evaluates the block, so an unquoted path would be truncated and the
#     rest of the line executed.
printf 'worktrees:\n  enabled: true\n  dir: %s/work trees\n' "$TMP" > "$MAIN/.sassywares/config.yaml"
"$WT" feat/spaced --from origin/main >"$TMP/spaced.out" 2>/dev/null; rc=$?
expect_rc "a worktrees.dir with a space still creates" 0 "$rc"
spaced_block="$(cat "$TMP/spaced.out")"
expect "a spaced worktrees.dir still prints exactly four lines" "4" "$(printf '%s\n' "$spaced_block" | grep -c '^WT_')"
( eval "$spaced_block"; printf '%s\n' "$WT_PATH" >"$TMP/spaced.path" )
spaced_path="$(cat "$TMP/spaced.path")"
expect_contains "the printed WT_PATH keeps the space" "/work trees/" "$spaced_path"
[ -d "$spaced_path" ] && pass "the spaced WT_PATH names the real checkout" || fail "the spaced WT_PATH names the real checkout" "$spaced_path"

# 8. A configured script that is gone degrades to the built-in with a warning
#    that names the key and the file. Read-only: neither path is created.
printf 'worktrees:\n  enabled: true\n  dir: %s/worktrees\n  remove: ./scripts/worktrees/remove\n' "$TMP" > "$MAIN/.sassywares/config.yaml"
"$DETECT" --root "$MAIN" --worktree-script remove >"$TMP/detect.out" 2>"$TMP/detect.err"; rc=$?
expect_rc "a missing remove script still resolves, exit 0" 0 "$rc"
expect "the built-in remove path is printed" "$MAIN_REAL/.sassywares/worktree/remove" "$(cat "$TMP/detect.out")"
detect_err="$(cat "$TMP/detect.err")"
expect_contains "the warning names the config key" "worktrees.remove" "$detect_err"
expect_contains "the warning names the missing file" "scripts/worktrees/remove is missing or not executable" "$detect_err"
expect_contains "the warning says the built-in is used" "using the built-in .sassywares/worktree/remove" "$detect_err"
[ ! -e "$MAIN/scripts/worktrees/remove" ] && pass "resolving creates no directory or file" || fail "resolving creates no directory or file"

# 9. Legacy lifecycle keys are a named error, not a generic unknown key: a
#    project that believed `up:` still started its stack must be told where the
#    lifecycle moved and that the line is the fix.
legacy_cfg() { # legacy_cfg <key>
  printf 'git:\n  repo: origin\n  base_map:\n    "*": main\ncommit:\n  branch: new\nworktrees:\n  enabled: true\n  dir: %s/worktrees\n%s: just dev\n' "$TMP" "$1" > "$MAIN/.sassywares/config.yaml"
}
for legacy in up down; do
  legacy_cfg "$legacy"
  "$DETECT" --root "$MAIN" --check >"$TMP/legacy.out" 2>&1; rc=$?
  legacy_out="$(cat "$TMP/legacy.out")"
  [ "$rc" -ne 0 ] && pass "a '$legacy:' config fails --check" || fail "a '$legacy:' config fails --check" "$legacy_out"
  expect_contains "the '$legacy:' error says where the lifecycle moved" \
    "$legacy is gone — the lifecycle moved into worktrees.create and worktrees.remove" "$legacy_out"
  expect_contains "the '$legacy:' error says to delete the key" \
    "Delete the '$legacy:' line from .sassywares/config.yaml" "$legacy_out"
  expect_not_contains "the '$legacy:' error is not the generic unknown-key line" "unknown key '$legacy'" "$legacy_out"
done

# 10. Legacy `hooks.worktree` is the same migration as `up:`/`down:`, reported
#     once for the whole block: one block is one fix, and the dedupe counter is
#     what this assertion holds.
printf 'git:\n  repo: origin\n  base_map:\n    "*": main\ncommit:\n  branch: new\nworktrees:\n  enabled: true\n  dir: %s/worktrees\nhooks:\n  worktree:\n    "*":\n      after_create: []\n      before_remove: []\n' "$TMP" > "$MAIN/.sassywares/config.yaml"
"$DETECT" --root "$MAIN" --check >"$TMP/hww.out" 2>&1; rc=$?
hww_out="$(cat "$TMP/hww.out")"
[ "$rc" -ne 0 ] && pass "a hooks.worktree block fails --check" || fail "a hooks.worktree block fails --check" "$hww_out"
expect_contains "the hooks.worktree error says it is gone" "hooks.worktree is gone" "$hww_out"
hww_count="$(grep -o 'hooks.worktree is gone' "$TMP/hww.out" | wc -l | tr -d ' ')"
expect "the hooks.worktree error is reported once for the whole block" "1" "$hww_count"

# 11. A declared script that exists resolves to its physical path, exits 0, and
#     warns about nothing.
mkdir -p "$MAIN/scripts/worktrees"
printf '#!/usr/bin/env bash\nexit 0\n' > "$MAIN/scripts/worktrees/create"
chmod +x "$MAIN/scripts/worktrees/create"
printf 'worktrees:\n  enabled: true\n  dir: %s/worktrees\n  create: ./scripts/worktrees/create\n' "$TMP" > "$MAIN/.sassywares/config.yaml"
"$DETECT" --root "$MAIN" --worktree-script create >"$TMP/pos.out" 2>"$TMP/pos.err"; rc=$?
expect_rc "an existing create script resolves, exit 0" 0 "$rc"
expect "the declared create script is printed as a physical path" "$MAIN_REAL/scripts/worktrees/create" "$(cat "$TMP/pos.out")"
expect "resolving an existing script warns on nothing" "" "$(cat "$TMP/pos.err")"

# 12. A missing script degrades to the built-in with a warning, for BOTH keys —
#     and the fallback must run, not just resolve: execute the printed path in a
#     fresh repo and assert the identity it hands back.
printf 'worktrees:\n  enabled: true\n  dir: %s/worktrees\n  create: ./scripts/worktrees/nope\n  remove: ./scripts/worktrees/nope\n' "$TMP" > "$MAIN/.sassywares/config.yaml"
"$DETECT" --root "$MAIN" --worktree-script create >"$TMP/deg-c.out" 2>"$TMP/deg-c.err"; rc=$?
expect_rc "a missing create script still resolves, exit 0" 0 "$rc"
expect "the built-in create path is printed" "$MAIN_REAL/.sassywares/worktree/create" "$(cat "$TMP/deg-c.out")"
expect_contains "the create warning names the key" "worktrees.create" "$(cat "$TMP/deg-c.err")"
"$DETECT" --root "$MAIN" --worktree-script remove >"$TMP/deg-r.out" 2>"$TMP/deg-r.err"; rc=$?
expect_rc "a missing remove script still resolves, exit 0" 0 "$rc"
expect "the built-in remove path is printed" "$MAIN_REAL/.sassywares/worktree/remove" "$(cat "$TMP/deg-r.out")"
expect_contains "the remove warning names the key" "worktrees.remove" "$(cat "$TMP/deg-r.err")"

FRESH="$TMP/fresh"
git_q init -q "$FRESH"
mkdir -p "$FRESH/.sassywares"
printf 'worktrees:\n  enabled: true\n  dir: %s/fresh-worktrees\n' "$TMP" > "$FRESH/.sassywares/config.yaml"
printf 'readme\n' > "$FRESH/README.md"
git_q -C "$FRESH" add -A
git_q -C "$FRESH" commit -qm "init"
git_q -C "$FRESH" branch -M main
( cd "$FRESH" && "$(cat "$TMP/deg-c.out")" feat/fallback >"$TMP/fallback.out" 2>"$TMP/fallback.err" ); rc=$?
expect_rc "the built-in create path runs when the declared one is missing" 0 "$rc"
expect "the fallback prints exactly four WT_* lines" "4" "$(grep -c '^WT_' "$TMP/fallback.out")"
expect "the fallback hands back the branch it was asked for" "feat/fallback" "$(sed -n 's/^WT_BRANCH=//p' "$TMP/fallback.out")"
fallback_path="$(sed -n 's/^WT_PATH=//p' "$TMP/fallback.out")"
[ -d "$fallback_path" ] && pass "the fallback actually creates the checkout" || fail "the fallback actually creates the checkout" "$fallback_path"
fallback_ns="$(sed -n 's/^WT_NAMESPACE=//p' "$TMP/fallback.out")"
expect "the fallback derives the namespace" "fresh-feat-fallback" "$fallback_ns"

# 13. Argument errors are exit 2 on the toolbox, so a caller can tell a usage
#     mistake from a refusal.
"$WT" --bogus >/dev/null 2>&1; rc=$?
expect_rc "create rejects an unknown flag with exit 2" 2 "$rc"
"$WT" feat/thing --from >/dev/null 2>&1; rc=$?
expect_rc "create --from with no argument exits 2" 2 "$rc"
"$LIST" --env >/dev/null 2>&1; rc=$?
expect_rc "list --env with no argument exits 2" 2 "$rc"
"$LIST" --bogus >/dev/null 2>&1; rc=$?
expect_rc "list rejects an unknown flag with exit 2" 2 "$rc"
"$LIST" --path feat-x --env feat-x >/dev/null 2>&1; rc=$?
expect_rc "list --path with --env exits 2" 2 "$rc"
"$REMOVE" --bogus >/dev/null 2>&1; rc=$?
expect_rc "remove rejects an unknown flag with exit 2" 2 "$rc"

# 14. A hand-written project pair — the shape a project ships — must run the
#     toolbox in one order: create, stop while the tree still exists, delete,
#     dispose after it is gone. Each step logs only when its condition held, so
#     the log itself is the proof.
PAIR="$TMP/pair"
PAIR_LOG="$TMP/pair.log"
: > "$PAIR_LOG"
git_q init -q --bare "$TMP/pair-remote.git"
git_q init -q "$PAIR"
git_q -C "$PAIR" remote add origin "$TMP/pair-remote.git"
mkdir -p "$PAIR/.sassywares/worktree" "$PAIR/scripts/worktrees"
cp "$ASSETS"/* "$PAIR/.sassywares/worktree/"
chmod +x "$PAIR"/.sassywares/worktree/*
printf 'worktrees:\n  enabled: true\n  dir: %s/pair-worktrees\n' "$TMP" > "$PAIR/.sassywares/config.yaml"
printf 'readme\n' > "$PAIR/README.md"
git_q -C "$PAIR" add -A
git_q -C "$PAIR" commit -qm "init"
git_q -C "$PAIR" branch -M main
git_q -C "$PAIR" push -q -u origin main
cat > "$PAIR/scripts/worktrees/create" <<EOF
#!/usr/bin/env bash
set -euo pipefail
"$PAIR/.sassywares/worktree/create" "\$@"
printf 'create\n' >> "$PAIR_LOG"
EOF
cat > "$PAIR/scripts/worktrees/remove" <<EOF
#!/usr/bin/env bash
set -euo pipefail
env_out="\$("$PAIR/.sassywares/worktree/list" --env "\$1")"
WT_PATH="\$(printf '%s\n' "\$env_out" | sed -n 's/^WT_PATH=//p')"
printf 'stop\n' >> "$PAIR_LOG"
[ -d "\$WT_PATH" ] || { echo "the tree is gone before stop" >&2; exit 1; }
"$PAIR/.sassywares/worktree/remove" "\$1" >/dev/null 2>&1
[ ! -e "\$WT_PATH" ] || { echo "the tree is still there after delete" >&2; exit 1; }
printf 'dispose\n' >> "$PAIR_LOG"
EOF
chmod +x "$PAIR/scripts/worktrees/create" "$PAIR/scripts/worktrees/remove"

( cd "$PAIR" && ./scripts/worktrees/create feat/pair >"$TMP/pair.out" 2>"$TMP/pair-create.err" ); rc=$?
expect_rc "the project create script exits 0" 0 "$rc"
expect "the project create prints the identity exactly once" "1" "$(grep -c '^WT_PATH=' "$TMP/pair.out")"
expect "the project create prints all four identity lines" "4" "$(grep -c '^WT_' "$TMP/pair.out")"
( cd "$PAIR" && ./scripts/worktrees/remove feat/pair >/dev/null 2>"$TMP/pair-remove.err" ); rc=$?
expect_rc "the project remove script exits 0" 0 "$rc"
expect "the project pair runs create, stop, then dispose in order" \
  "$(printf 'create\nstop\ndispose')" "$(cat "$PAIR_LOG")"

# 15. The scaffolded project pair, copied the way setup writes it: untouched, it
#     must behave exactly like the toolbox — identity, help, version, removal,
#     and a failed identity lookup must abort before the tree is touched.
TPL="$TMP/tpl"
TPL_HOME="$TMP/tpl-worktrees/tpl"
TEMPLATES="$REPO/skills/sassy-setup/assets/templates"
git_q init -q --bare "$TMP/tpl-remote.git"
git_q init -q "$TPL"
git_q -C "$TPL" remote add origin "$TMP/tpl-remote.git"
mkdir -p "$TPL/.sassywares/worktree" "$TPL/scripts/worktrees"
cp "$ASSETS"/* "$TPL/.sassywares/worktree/"
chmod +x "$TPL"/.sassywares/worktree/*
sed 's/<version>/0.0.0-test/; s/<YYYY-MM-DD>/2025-01-01/' "$TEMPLATES/worktrees-create" > "$TPL/scripts/worktrees/create"
sed 's/<version>/0.0.0-test/; s/<YYYY-MM-DD>/2025-01-01/' "$TEMPLATES/worktrees-remove" > "$TPL/scripts/worktrees/remove"
chmod +x "$TPL/scripts/worktrees/create" "$TPL/scripts/worktrees/remove"
printf 'worktrees:\n  enabled: true\n  dir: %s/tpl-worktrees\n  create: scripts/worktrees/create\n  remove: scripts/worktrees/remove\n' "$TMP" > "$TPL/.sassywares/config.yaml"
printf 'readme\n' > "$TPL/README.md"
git_q -C "$TPL" add -A
git_q -C "$TPL" commit -qm "init"
git_q -C "$TPL" branch -M main
git_q -C "$TPL" push -q -u origin main

( cd "$TPL" && ./scripts/worktrees/create feat/tpl --from origin/main >"$TMP/tpl-create.out" 2>"$TMP/tpl-create.err" ); rc=$?
expect_rc "the untouched template create exits 0" 0 "$rc"
expect "the untouched template create prints exactly four WT_* lines" "4" "$(grep -c '^WT_' "$TMP/tpl-create.out")"
expect "the untouched template create prints nothing else on stdout" "" "$(grep -v '^WT_' "$TMP/tpl-create.out" || true)"
( cd "$TPL" && ./.sassywares/worktree/create feat/tpl >"$TMP/tpl-direct.out" 2>/dev/null ); rc=$?
expect_rc "a direct toolbox create on the same branch exits 0" 0 "$rc"
expect "the template create matches a direct toolbox create" "$(cat "$TMP/tpl-direct.out")" "$(cat "$TMP/tpl-create.out")"
( cd "$TPL" && ./.sassywares/worktree/list --env feat/tpl >"$TMP/tpl-env.out" 2>/dev/null ); rc=$?
expect_rc "list --env exits 0" 0 "$rc"
expect "the template create matches list --env" "$(cat "$TMP/tpl-env.out")" "$(cat "$TMP/tpl-create.out")"
for flag in --help --version; do
  ( cd "$TPL" && ./scripts/worktrees/create "$flag" ) >"$TMP/tpl-c.out" 2>&1; t_rc=$?
  ( cd "$TPL" && ./.sassywares/worktree/create "$flag" ) >"$TMP/tb-c.out" 2>&1; b_rc=$?
  expect_rc "template create $flag exits like the toolbox" "$b_rc" "$t_rc"
  expect "template create $flag matches the toolbox" "$(cat "$TMP/tb-c.out")" "$(cat "$TMP/tpl-c.out")"
  ( cd "$TPL" && ./scripts/worktrees/remove "$flag" ) >"$TMP/tpl-r.out" 2>&1; t_rc=$?
  ( cd "$TPL" && ./.sassywares/worktree/remove "$flag" ) >"$TMP/tb-r.out" 2>&1; b_rc=$?
  expect_rc "template remove $flag exits like the toolbox" "$b_rc" "$t_rc"
  expect "template remove $flag matches the toolbox" "$(cat "$TMP/tb-r.out")" "$(cat "$TMP/tpl-r.out")"
done
( cd "$TPL" && ./scripts/worktrees/remove feat/tpl >"$TMP/tpl-rm.out" 2>"$TMP/tpl-rm.err" ); rc=$?
expect_rc "the template remove exits 0" 0 "$rc"
expect "the template remove writes nothing to stdout" "" "$(cat "$TMP/tpl-rm.out")"
[ ! -d "$TPL_HOME/feat-tpl" ] && pass "the template remove deletes the checkout" || fail "the template remove deletes the checkout"
git -C "$TPL" rev-parse --verify --quiet refs/heads/feat/tpl >/dev/null \
  && pass "the template remove leaves the branch behind" || fail "the template remove leaves the branch behind"
# Two branches that slug to the same name make list --env fail. The pair must
# abort before the toolbox remove runs, so both trees survive.
git_q -C "$TPL" worktree add -q --no-track -b feat/x "$TPL_HOME/x-one" origin/main
git_q -C "$TPL" worktree add -q --no-track -b feat-x "$TPL_HOME/x-two" origin/main
( cd "$TPL" && ./scripts/worktrees/remove feat-x >"$TMP/tpl-bad.out" 2>"$TMP/tpl-bad.err" ); rc=$?
[ "$rc" -ne 0 ] && pass "a failed identity lookup aborts the template remove" || fail "a failed identity lookup aborts the template remove"
expect_contains "the failed lookup names both matches" "matches 2 worktrees" "$(cat "$TMP/tpl-bad.err")"
[ -d "$TPL_HOME/x-one" ] && [ -d "$TPL_HOME/x-two" ] \
  && pass "a failed identity lookup touches neither tree" || fail "a failed identity lookup touches neither tree"

# 16. Mutation check. The upstream assertion above is only worth keeping if
#     removing `--no-track` reproduces the bug; if the mutant comes out untracked
#     too, this test would pass a regression and says so.
mkdir -p "$TMP/mutant"
cp "$ASSETS"/* "$TMP/mutant/"
chmod +x "$TMP/mutant"/*
sed 's/ --no-track//' "$ASSETS/create" > "$TMP/mutant/create"
chmod +x "$TMP/mutant/create"
"$TMP/mutant/create" feat/mutant --from origin/main >/dev/null 2>&1
mutant_upstream="$(git -C "$MAIN" config --get branch.feat/mutant.remote || true)"
if [ "$mutant_upstream" = "origin" ]; then
  pass "mutation: dropping --no-track makes the branch inherit its base, so the assertion is load-bearing"
else
  fail "mutation: dropping --no-track left the branch untracked — the upstream assertion would miss the regression" \
    "branch.feat/mutant.remote='${mutant_upstream}'"
fi

printf '\n%s\n' "$([ "$fails" -eq 0 ] && echo "all passed" || echo "$fails failed")"
[ "$fails" -eq 0 ]
