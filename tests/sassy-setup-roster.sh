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

# Same hash the skills CLI and lockcheck.mjs use: sha256 over each file's
# relative path then bytes, files sorted by relative path.
lock_for() { # lock_for <skills-dir> <names...> -> skills-lock.json on stdout
  local dir="$1"; shift
  node -e '
    const { createHash } = require("crypto");
    const fs = require("fs"); const path = require("path");
    const [dir, ...names] = process.argv.slice(1);
    const walk = (base, d, out) => { for (const e of fs.readdirSync(d, { withFileTypes: true })) {
      const f = path.join(d, e.name);
      if (e.isDirectory()) { if (e.name !== ".git" && e.name !== "node_modules") walk(base, f, out); }
      else if (e.isFile()) out.push({ p: path.relative(base, f).split(path.sep).join("/"), b: fs.readFileSync(f) }); } };
    const skills = {};
    for (const n of names) {
      const files = []; walk(path.join(dir, n), path.join(dir, n), files);
      files.sort((a, b) => a.p.localeCompare(b.p));
      const h = createHash("sha256"); for (const f of files) { h.update(f.p); h.update(f.b); }
      skills[n] = { source: "sassywares/sassy-skills", sourceType: "github", computedHash: h.digest("hex") };
    }
    console.log(JSON.stringify({ version: 1, skills }, null, 2));
  ' "$dir" "$@"
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

# (a) project scope: project skills are not "ours"
A="$TMP/a"; mkproject "$A" "$CFG_OK"
out="$(bash "$A/.agents/skills/sassy-setup/scripts/detect.sh" --root "$A" --check 2>&1)"
if printf '%s' "$out" | grep -q 'drift:'; then fail "(a) project scope has no drift" "$out"; else pass "(a) project scope has no drift"; fi

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

(( fails == 0 )) && echo "all passed" || { echo "$fails failed"; exit 1; }
