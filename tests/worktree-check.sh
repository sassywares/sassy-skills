#!/usr/bin/env bash
# A stale worktree set has to be drift, not a note.
#
# The incident this guards: a project carried a v8 `.sassywares/worktree/` under
# v13 create/remove scripts. `--check` saw the older header, called it "an
# upgrade, not drift", exited 0, and never read a byte of the set — so the v13
# `remove` wrapper called `list --env`, which v8 answers with `unknown flag`, and
# every removal aborted before removing anything. The check that should have
# warned was the one that said everything was fine.
#
# What is proven here:
#
#   * an older header is drift, and the walk still runs — the stale verdict and
#     the names of the differing files appear in the same report (that pair is
#     the load-bearing assertion: restore the old short-circuit and it fails);
#   * files the skill no longer ships are reported as retired commands, not as
#     untidy leftovers;
#   * a *newer* set is drift but never borrows the "it goes off mid-run"
#     wording — a set ahead of the shipped one works, and claiming otherwise
#     would be the same confident lie the old note told;
#   * a set that matches says so and reports nothing;
#   * end to end, `detect.sh --check` exits non-zero on a stale set and does not
#     print `config matches the tree`.
#
# Stale fixtures are built by editing a copy's header down, never by rolling a
# project back. Self-contained, offline, bash 3.2.
set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
ASSETS="$REPO/skills/sassy-setup/assets/worktree"
CHECK="$REPO/skills/sassy-setup/scripts/worktree-check.mjs"
DETECT="$REPO/skills/sassy-setup/scripts/detect.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/sassy-wtcheck.XXXXXX")"
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

if ! command -v node >/dev/null 2>&1; then
  printf 'skip worktree-check: node not found (the check is a node script)\n'
  exit 0
fi

# set_version <dir> <n> — rewrite the toolbox header in place, portably.
set_version() {
  sed "s/^# worktree-version: [0-9][0-9]*\$/# worktree-version: $2/" "$1/_lib.sh" > "$1/_lib.sh.new"
  mv "$1/_lib.sh.new" "$1/_lib.sh"
}

check() { # check <installed-dir> — `<drift|note>\t<message>` lines, always exit 0
  node "$CHECK" --installed "$1" --shipped "$ASSETS" 2>&1
}

# --- (a) stale set: older header, plus two files v13 no longer ships ---------
A="$TMP/stale"
cp -R "$ASSETS" "$A"
set_version "$A" 8
printf '#!/usr/bin/env bash\n# retired with the v13 lifecycle\nwt_hook down\n' > "$A/prune"
printf '#!/usr/bin/env bash\nwrapper stop\n' > "$A/stop"
chmod +x "$A/prune" "$A/stop"
out="$(check "$A")"
expect_rc "(a) stale set still exits 0 (the caller owns the verdict)" 0 "$?"
expect_contains "(a) stale set is named stale" \
  "drift	worktree setup is stale — it goes off mid-run, not here; re-run setup" "$out"
expect_contains "(a) the set was actually read: differing files are named" \
  ".sassywares/worktree/_lib.sh differs from the shipped copy" "$out"
expect_contains "(a) unshipped prune is a retired command" \
  "prune is retired and its helpers went with it — it cannot run; re-run setup" "$out"
expect_contains "(a) unshipped stop is a retired command" \
  "stop is retired and its helpers went with it — it cannot run; re-run setup" "$out"
expect_not_contains "(a) the old shrug is gone" "an upgrade, not drift" "$out"
expect_not_contains "(a) no order the user cannot execute" "then delete" "$out"
expect_not_contains "(a) a stale set never claims to match" "matches the shipped set" "$out"

# The stale line comes first: verdict, then evidence.
first_line="$(printf '%s\n' "$out" | head -n 1)"
expect_contains "(a) the verdict leads the report" "worktree setup is stale" "$first_line"

# --- (b) an identical set matches and reports nothing ------------------------
B="$TMP/current"
cp -R "$ASSETS" "$B"
out="$(check "$B")"
expect_rc "(b) identical set exits 0" 0 "$?"
expect_contains "(b) identical set reports the match" "note	worktree tooling matches the shipped set (hash " "$out"
expect_not_contains "(b) identical set reports no drift" "drift	" "$out"

# --- (c) a set ahead of the shipped one: drift, but not "it falls over" ------
C="$TMP/ahead"
cp -R "$ASSETS" "$C"
set_version "$C" 14
out="$(check "$C")"
expect_contains "(c) a newer set is drift" ".sassywares/worktree/_lib.sh differs from the shipped copy" "$out"
expect_not_contains "(c) a newer set is never called stale" "worktree setup is stale" "$out"

# --- (d) same header, one edited byte: drift, no stale claim -----------------
D="$TMP/edited"
cp -R "$ASSETS" "$D"
printf '\n# local edit\n' >> "$D/list"
out="$(check "$D")"
expect_contains "(d) an edited file is named" ".sassywares/worktree/list differs from the shipped copy" "$out"
expect_not_contains "(d) an equal header is not stale" "worktree setup is stale" "$out"

# --- (e) end to end: --check fails a stale set ------------------------------
E="$TMP/project"
mkdir -p "$E/.sassywares"
git -C "$E" init -q
cp -R "$ASSETS" "$E/.sassywares/worktree"
set_version "$E/.sassywares/worktree" 8
printf 'worktrees:\n  enabled: true\ncommit:\n  branch: current\n' > "$E/.sassywares/config.yaml"
out="$(bash "$DETECT" --root "$E" --check 2>&1)"
rc=$?
expect_rc "(e) --check exits non-zero on a stale set" 1 "$rc"
expect_contains "(e) --check prints the stale line verbatim" \
  "drift: worktree setup is stale — it goes off mid-run, not here; re-run setup" "$out"
expect_not_contains "(e) a stale set is not \"config matches the tree\"" "config matches the tree" "$out"

# --- (f) end to end: --check passes the current set -------------------------
F="$TMP/current-project"
mkdir -p "$F/.sassywares"
git -C "$F" init -q
cp -R "$ASSETS" "$F/.sassywares/worktree"
printf 'worktrees:\n  enabled: true\ncommit:\n  branch: current\n' > "$F/.sassywares/config.yaml"
out="$(bash "$DETECT" --root "$F" --check 2>&1)"
expect_contains "(f) a current set is reported as matching" "worktree tooling matches the shipped set" "$out"
expect_not_contains "(f) a current set reports no worktree drift" "drift: worktree" "$out"

printf '\n'
if (( fails )); then printf '%d failed\n' "$fails"; exit 1; fi
printf 'all worktree-check assertions passed\n'
