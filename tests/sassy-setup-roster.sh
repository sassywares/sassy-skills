#!/usr/bin/env bash
# Roster behaviour of sassy-setup's `detect.sh --check`: only names in
# skills/sassy-setup/assets/roster are "ours". Self-contained, offline, bash 3.2.
set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/sassy-roster.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
fails=0
pass() { printf 'ok   %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1"; [[ -n "${2:-}" ]] && printf '%s\n' "$2" | sed 's/^/     /'; fails=$((fails + 1)); }

# The lock is built with hash-skill.mjs's definitions (tests/hash-lock.mjs), never
# a second copy of them: a private copy is exactly how this check drifted from
# the skills CLI's hash and read a sound pin as 21 false drifts.
LOCK="$REPO/tests/hash-lock.mjs"
lock_for() { # lock_for <skills-dir> <names...> -> skills-lock.json on stdout
  node "$LOCK" "$@"
}

mkproject() { # mkproject <dir> <hooks-yaml-body>
  local p="$1"
  mkdir -p "$p/.agents/skills" "$p/.sassywares"
  cp -R "$REPO"/skills/* "$p/.agents/skills/"
  for s in sassy-tmp-release tap2-version proj-goal-hook; do
    mkdir -p "$p/.agents/skills/$s"
    printf -- '---\nname: %s\ndescription: project skill\n---\n' "$s" > "$p/.agents/skills/$s/SKILL.md"
  done
  # shellcheck disable=SC2046
  lock_for "$p/.agents/skills" $(ls "$REPO/skills") > "$p/skills-lock.json"
  git -C "$p" init -q 2>/dev/null
  git -C "$p" remote add origin https://example.invalid/x.git 2>/dev/null
  printf '%s\n' "$2" > "$p/.sassywares/config.yaml"
}

CFG_OK='git:
  repo: origin
  base_map:
    "*": main
commit:
  branch: current
hooks:
  pr:
    "*":
      before_create: [tap2-version]
  push:
    "*":
      after_push: [sassy-tmp-release]'

# (a) project scope: project skills are not "ours", and the pin is really read
A="$TMP/a"; mkproject "$A" "$CFG_OK"
out="$(bash "$A/.agents/skills/sassy-setup/scripts/detect.sh" --root "$A" --check 2>&1)"
if printf '%s' "$out" | grep -q 'drift:'; then
  fail "(a) project scope has no drift" "$out"
elif ! printf '%s' "$out" | grep -q 'suite skill folders match skills-lock.json'; then
  fail "(a) project scope has no drift" "the pin was never checked: $out"
else pass "(a) project scope has no drift"; fi

# (b) a hook naming a suite skill is drift
B="$TMP/b"; mkproject "$B" "$(printf '%s' "$CFG_OK" | sed 's/sassy-tmp-release/sassy-commit/')"
out="$(bash "$B/.agents/skills/sassy-setup/scripts/detect.sh" --root "$B" --check 2>&1)"
if printf '%s' "$out" | grep -q "'sassy-commit' is one of our skills"; then pass "(b) suite skill as hook is drift"; else fail "(b) suite skill as hook is drift" "$out"; fi

# (c) a suite skill vendored but not pinned is drift
C="$TMP/c"; mkproject "$C" "$CFG_OK"
node -e '
  const fs = require("fs"); const f = process.argv[1]; const l = JSON.parse(fs.readFileSync(f, "utf8"));
  delete l.skills["sassy-commit"]; fs.writeFileSync(f, JSON.stringify(l, null, 2));
' "$C/skills-lock.json"
out="$(bash "$C/.agents/skills/sassy-setup/scripts/detect.sh" --root "$C" --check 2>&1)"
if printf '%s' "$out" | grep -q 'sassy-commit is installed but not pinned'; then pass "(c) unpinned vendored suite skill is drift"; else fail "(c) unpinned vendored suite skill is drift" "$out"; fi

# (d) user scope: run from the real repo, against SASSY_ROSTER_REPOS (space-separated
# paths) or, by default, the sibling checkouts and this repo itself
if [[ -n "${SASSY_ROSTER_REPOS:-}" ]]; then
  read -r -a repos <<< "$SASSY_ROSTER_REPOS"
else
  repos=("$REPO/../sassy-code" "$REPO/../sassy-pi-extensions" "$REPO")
fi
for root in "${repos[@]}"; do
  r="$(basename "$root")"
  if [[ ! -d "$root" ]]; then printf 'skip (d) %s: not on this machine\n' "$r"; continue; fi
  out="$(bash "$REPO/skills/sassy-setup/scripts/detect.sh" --root "$root" --check 2>&1)"
  if printf '%s' "$out" | grep -q 'config matches the tree' && ! printf '%s' "$out" | grep -q 'drift:'; then
    pass "(d) $r matches the tree"
  else fail "(d) $r matches the tree" "$out"; fi
done

# (e) roster missing: prefix fallback, announced
E="$TMP/e"; mkproject "$E" "$CFG_OK"
rm -f "$E/.agents/skills/sassy-setup/assets/roster"
out="$(bash "$E/.agents/skills/sassy-setup/scripts/detect.sh" --root "$E" --check 2>&1)"
if printf '%s' "$out" | grep -q 'suite roster not found — falling back to the sassy-\* name prefix'; then pass "(e) missing roster falls back with a note"; else fail "(e) missing roster falls back with a note" "$out"; fi

# (f) the roster equals ls skills/
if diff <(ls "$REPO/skills" | sort) <(sort "$REPO/skills/sassy-setup/assets/roster") >/dev/null; then
  pass "(f) roster equals ls skills/"
else fail "(f) roster equals ls skills/" "$(diff <(ls "$REPO/skills" | sort) <(sort "$REPO/skills/sassy-setup/assets/roster"))"; fi

# (g) a lock v1 (skills CLI <= 1.7.x) still verifies against the older hash
G="$TMP/g"; mkproject "$G" "$CFG_OK"
# shellcheck disable=SC2046
node "$LOCK" --legacy "$G/.agents/skills" $(ls "$REPO/skills") > "$G/skills-lock.json"
out="$(bash "$G/.agents/skills/sassy-setup/scripts/detect.sh" --root "$G" --check 2>&1)"
if printf '%s' "$out" | grep -q 'drift:'; then fail "(g) a v1 lock verifies" "$out"; else pass "(g) a v1 lock verifies"; fi

# (h) a v2 lock carrying the older hash still verifies, and says so
H="$TMP/h"; mkproject "$H" "$CFG_OK"
# shellcheck disable=SC2046
node "$LOCK" --legacy "$H/.agents/skills" $(ls "$REPO/skills") > "$H/skills-lock.json"
node -e '
  const fs = require("fs"); const f = process.argv[1]; const l = JSON.parse(fs.readFileSync(f, "utf8"));
  l.version = 2; fs.writeFileSync(f, JSON.stringify(l, null, 2));
' "$H/skills-lock.json"
out="$(bash "$H/.agents/skills/sassy-setup/scripts/detect.sh" --root "$H" --check 2>&1)"
if printf '%s' "$out" | grep -q 'drift:'; then
  fail "(h) a v2 lock with a v1 hash verifies" "$out"
elif ! printf '%s' "$out" | grep -q 'matched the other skills-lock hash era'; then
  fail "(h) a v2 lock with a v1 hash verifies" "no other-era note: $out"
else pass "(h) a v2 lock with a v1 hash verifies"; fi

# (i) an edited vendored skill is still drift: the fallback cannot hide it
I="$TMP/i"; mkproject "$I" "$CFG_OK"
printf '\nlocal edit\n' >> "$I/.agents/skills/sassy-commit/SKILL.md"
out="$(bash "$I/.agents/skills/sassy-setup/scripts/detect.sh" --root "$I" --check 2>&1)"
if printf '%s' "$out" | grep -q 'sassy-commit does not match the pin'; then
  pass "(i) an edited vendored skill is drift"
else fail "(i) an edited vendored skill is drift" "$out"; fi

# (j) both hash definitions still match the skills CLI. The current hash was
# captured from skills 1.8.1 (its own computeSkillFolderHash over this fixture)
# and the older one from the v1 collects: an LF SKILL.md, a CRLF file, a
# metadata.json and a __pycache__ the current definition must ignore, and a
# case pair (Z.md, a.md) that sorts one way by bytes and the other by locale.
J="$TMP/j"; mkdir -p "$J/nested" "$J/__pycache__"
printf -- '---\nname: golden\ndescription: fixture\n---\n' > "$J/SKILL.md"
printf 'a\r\nb\r\n' > "$J/notes.md"
printf '{"x":1}\n' > "$J/metadata.json"
printf 'Z\n' > "$J/Z.md"
printf 'a\n' > "$J/a.md"
printf 'caf\303\251\n' > "$J/nested/body.md"
printf 'junk' > "$J/__pycache__/junk.pyc"
read -r got_current got_legacy <<< "$(node "$LOCK" --hash "$J")"
want_current="9abae83494b9fbbe7ff3e54aee41fd4a02d275b03f94ea9f348298cd3f3e28b2"
want_legacy="9107e8238b7590124b459550e9f40ff43a59f68ef972b1c1505b7d4e1de27c6a"
if [[ "$got_current" == "$want_current" && "$got_legacy" == "$want_legacy" ]]; then
  pass "(j) hash definitions match the skills CLI"
else
  fail "(j) hash definitions match the skills CLI" "current $got_current (want $want_current)
legacy  $got_legacy (want $want_legacy)"
fi

# (k) goal hooks resolve per slug: the exact slug wins, the rest falls back to "*"
# (an explicit [] is a value, and an absent entry inherits the "*" entry's args)
CFG_GOAL='git:
  repo: origin
  base_map:
    "*": main
commit:
  branch: current
hooks:
  goal:
    "*":
      before_slice: [proj-goal-hook mode:auto]
      after_close: []
    one-goal:
      before_slice: [proj-goal-hook]'
K="$TMP/k"; mkproject "$K" "$CFG_GOAL"
out="$(bash "$K/.agents/skills/sassy-setup/scripts/detect.sh" --root "$K" --check --goal one-goal 2>&1)"
out2="$(bash "$K/.agents/skills/sassy-setup/scripts/detect.sh" --root "$K" --check --goal other-goal 2>&1)"
if printf '%s\n' "$out" | grep -q "goal 'one-goal' → before_slice: \[proj-goal-hook\]" \
   && printf '%s\n' "$out" | grep -q "goal 'one-goal' → after_close: \[\]" \
   && ! printf '%s' "$out" | grep -q 'drift:' \
   && printf '%s\n' "$out2" | grep -q "goal 'other-goal' → before_slice: \[proj-goal-hook mode:auto\]" \
   && printf '%s\n' "$out2" | grep -q "goal 'other-goal' → after_close: \[\]"; then
  pass "(k) goal hooks resolve per slug with no drift"
else fail "(k) goal hooks resolve per slug with no drift" "$out
---
$out2"; fi

# (l) a point name that is not one of hooks.goal's two points is drift
L="$TMP/l"; mkproject "$L" "$(printf '%s' "$CFG_GOAL" | sed 's/after_close: \[\]/after_check: [proj-goal-hook]/')"
out="$(bash "$L/.agents/skills/sassy-setup/scripts/detect.sh" --root "$L" --check 2>&1)"
if printf '%s' "$out" | grep -q "hooks.goal point 'after_check' is not one of before_slice|after_close"; then
  pass "(l) a bogus goal point is drift"
else fail "(l) a bogus goal point is drift" "$out"; fi

# (m) a goal hook naming a suite skill is drift, exactly like hooks.pr
M="$TMP/m"; mkproject "$M" "$(printf '%s' "$CFG_GOAL" | sed 's/proj-goal-hook/sassy-commit/')"
out="$(bash "$M/.agents/skills/sassy-setup/scripts/detect.sh" --root "$M" --check 2>&1)"
if printf '%s' "$out" | grep -q "'sassy-commit' is one of our skills"; then
  pass "(m) a suite skill as a goal hook is drift"
else fail "(m) a suite skill as a goal hook is drift" "$out"; fi

# (n) the installed worktree set is proven byte for byte against the shipped
# folder: an edited script is drift naming that file, and restoring the shipped
# copy is clean again. The expected hash is the shipped asset folder's — setup
# installs by copying it, so there is no separate state file to fall out of sync.
CFG_WT='git:
  repo: origin
  base_map:
    "*": main
commit:
  branch: new
worktrees:
  enabled: true'
mkworktree() { # mkworktree <dir> <config>
  mkproject "$1" "$2"
  mkdir -p "$1/.sassywares/worktree"
  cp -R "$REPO/skills/sassy-setup/assets/worktree/." "$1/.sassywares/worktree/"
  chmod +x "$1"/.sassywares/worktree/*
}
N="$TMP/n"; mkworktree "$N" "$CFG_WT"
printf '\n# local edit\n' >> "$N/.sassywares/worktree/create"
out="$(bash "$N/.agents/skills/sassy-setup/scripts/detect.sh" --root "$N" --check 2>&1)"
if printf '%s' "$out" | grep -q 'drift: .sassywares/worktree/create differs from the shipped copy' \
   && printf '%s' "$out" | grep -q 'drift: .sassywares/worktree hash '; then
  pass "(n) an edited installed worktree file is drift, named"
else fail "(n) an edited installed worktree file is drift, named" "$out"; fi
cp "$REPO/skills/sassy-setup/assets/worktree/create" "$N/.sassywares/worktree/create"
chmod +x "$N/.sassywares/worktree/create"
out="$(bash "$N/.agents/skills/sassy-setup/scripts/detect.sh" --root "$N" --check 2>&1)"
if printf '%s' "$out" | grep -q 'config matches the tree'; then
  pass "(n2) restoring the shipped copy is clean again"
else fail "(n2) restoring the shipped copy is clean again" "$out"; fi

# (o) worktrees.ports is removed: one drift line carrying the line to delete,
# and a leftover key never cascades into a second unknown-key finding.
O="$TMP/o"; mkworktree "$O" "$(printf '%s\n  ports: 3000-3099' "$CFG_WT")"
out="$(bash "$O/.agents/skills/sassy-setup/scripts/detect.sh" --root "$O" --check 2>&1)"
if printf '%s' "$out" | grep -q "drift: worktrees.ports is gone — delete the 'ports:' line under worktrees in .sassywares/config.yaml" \
   && ! printf '%s' "$out" | grep -q "unknown key 'worktrees.ports'"; then
  pass "(o) worktrees.ports is reported removed with its fix line"
else fail "(o) worktrees.ports is reported removed with its fix line" "$out"; fi

# (p) the identify substitution: a named-scripts manifest with only some of the
# four aliases gets one optional note, never drift, (q) a project without
# the sassy-overview skill says the aliases went unchecked instead of guessing,
# and (r) a Deno workspace repo names its own manifest rather than going silent.
CFG_WS='git:
  repo: workspace
  remote: origin
  mirror_branch: main
repos:
  fe: main'
mkworkspace() { # mkworkspace <dir> <config>
  mkproject "$1" "$2"
  # A workspace root is not a repo; one nested repo makes the topology real.
  rm -rf "$1/.git"
  mkdir -p "$1/fe"
  git -C "$1/fe" init -q 2>/dev/null
  mkdir -p "$1/.sassywares/workspace"
  cp -R "$REPO/skills/sassy-setup/assets/workspace/." "$1/.sassywares/workspace/"
  cp "$REPO/skills/sassy-setup/assets/snapshot" "$1/.sassywares/workspace/snapshot"
  chmod +x "$1"/.sassywares/workspace/*
  printf '{\n  "name": "fixture",\n  "scripts": {\n    "workspace:branches": "bash .sassywares/workspace/branches",\n    "workspace:pull": "bash .sassywares/workspace/pull"\n  }\n}\n' > "$1/package.json"
}
P="$TMP/p"; mkworkspace "$P" "$CFG_WS"
out="$(bash "$P/.agents/skills/sassy-setup/scripts/detect.sh" --root "$P" --check 2>&1)"
if printf '%s' "$out" | grep -q 'aliases: workspace:checkout-bases, workspace:snapshot not wired in package.json (optional — the scripts run by path)' \
   && ! printf '%s' "$out" | grep -q 'drift:'; then
  pass "(p) partial workspace aliases are one optional note, not drift"
else fail "(p) partial workspace aliases are one optional note, not drift" "$out"; fi

Q="$TMP/q"; mkworkspace "$Q" "$CFG_WS"
rm -rf "$Q/.agents/skills/sassy-overview"
node -e '
  const fs = require("fs"); const f = process.argv[1]; const l = JSON.parse(fs.readFileSync(f, "utf8"));
  delete l.skills["sassy-overview"]; fs.writeFileSync(f, JSON.stringify(l, null, 2));
' "$Q/skills-lock.json"
out="$(bash "$Q/.agents/skills/sassy-setup/scripts/detect.sh" --root "$Q" --check 2>&1)"; rc=$?
if [[ "$rc" -eq 0 ]] \
   && printf '%s' "$out" | grep -q 'sassy-overview is not installed — workspace aliases unchecked' \
   && ! printf '%s' "$out" | grep -q 'drift:'; then
  pass "(q) no sassy-overview means the aliases go unchecked, exit 0"
else fail "(q) no sassy-overview means the aliases go unchecked, exit 0" "exit $rc
$out"; fi

# (r) identify names deno.json as the manifest for a Deno stack, so a Deno
# workspace repo gets the alias note instead of silence.
R="$TMP/r"; mkworkspace "$R" "$CFG_WS"
rm -f "$R/package.json"
printf '{\n  "tasks": {\n    "workspace:branches": "bash .sassywares/workspace/branches"\n  }\n}\n' > "$R/deno.json"
out="$(bash "$R/.agents/skills/sassy-setup/scripts/detect.sh" --root "$R" --check 2>&1)"; rc=$?
if [[ "$rc" -eq 0 ]] \
   && printf '%s' "$out" | grep -q 'aliases: workspace:pull, workspace:checkout-bases, workspace:snapshot not wired in deno.json (optional — the scripts run by path)' \
   && ! printf '%s' "$out" | grep -q 'drift:'; then
  pass "(r) a Deno workspace repo gets the alias note for deno.json"
else fail "(r) a Deno workspace repo gets the alias note for deno.json" "exit $rc
$out"; fi

(( fails == 0 )) && echo "all passed" || { echo "$fails failed"; exit 1; }
