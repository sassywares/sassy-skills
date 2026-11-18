#!/usr/bin/env bash
# A new checkout's branch must not inherit an upstream.
#
# `git worktree add -b <branch> <path> <start-point>` follows the DWIM rule: cut
# from a remote-tracking ref and the branch tracks it, so the branch's own `git
# push` aims at the base. That is a silent, whole-run-shaped bug — nothing prints
# until someone pushes at staging — so it gets a test rather than a comment.
#
# Self-contained, offline, bash 3.2.
set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
ASSETS="$REPO/skills/sassy-setup/assets/worktree"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/sassy-worktree.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
fails=0
pass() { printf 'ok   %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1"; [[ -n "${2:-}" ]] && printf '%s\n' "$2" | sed 's/^/     /'; fails=$((fails + 1)); }

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

mkdir -p "$MAIN/.sassywares/worktree"
cp "$ASSETS"/* "$MAIN/.sassywares/worktree/"
chmod +x "$MAIN"/.sassywares/worktree/*
printf 'worktrees:\n  enabled: true\n  dir: %s/worktrees\n' "$TMP" > "$MAIN/.sassywares/config.yaml"

WT="$MAIN/.sassywares/worktree/create"

# 1. A branch cut from origin/main is untracked, and create says so.
out="$("$WT" feat/thing --from origin/main 2>&1)" || { fail "create exits 0" "$out"; }
upstream="$(git -C "$MAIN" config --get branch.feat/thing.remote || true)/$(git -C "$MAIN" config --get branch.feat/thing.merge || true)"
if [ "$upstream" = "/" ]; then
  pass "feat/thing has no upstream"
else
  fail "feat/thing has no upstream" "tracks $upstream"
fi
case "$out" in
  *"upstream  none"*) pass "create reports an empty upstream" ;;
  *) fail "create reports an empty upstream" "$out" ;;
esac

# 2. A second call reports the same checkout instead of cutting a new one.
out2="$("$WT" feat/thing 2>&1)" || { fail "re-running create exits 0" "$out2"; }
case "$out2" in
  *"upstream  none"*) pass "the reused checkout is still untracked" ;;
  *) fail "the reused checkout is still untracked" "$out2" ;;
esac

# 3. A branch that already tracks the base is called out — the state a run cut by
#    hand lands in, and the one that reads as healthy until the first push.
git_q branch --track feat/inherited origin/main 2>/dev/null || git_q branch feat/inherited origin/main
out3="$("$WT" feat/inherited 2>&1)" || { fail "create on a tracking branch exits 0" "$out3"; }
case "$out3" in
  *"a plain 'git push' lands there"*) pass "a branch tracking the base is called out" ;;
  *) fail "a branch tracking the base is called out" "$out3" ;;
esac

printf '\n%s\n' "$([ "$fails" -eq 0 ] && echo "all passed" || echo "$fails failed")"
[ "$fails" -eq 0 ]
