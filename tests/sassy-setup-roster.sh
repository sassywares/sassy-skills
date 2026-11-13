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
  for s in sassy-tmp-release tap2-version; do
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

(( fails == 0 )) && echo "all passed" || { echo "$fails failed"; exit 1; }
