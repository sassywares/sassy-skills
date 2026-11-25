#!/usr/bin/env bash
# sassy-overview's identify.sh: one sourced answer per key, offline.
#
# Each fixture is a throwaway project with exactly one manifest, and every
# assertion expects the real value that manifest implies — not `unknown`. Drop
# a row from the script's table and the matching fixture fails here.
#
# Self-contained, offline, bash 3.2. Read-only: identify writes nothing.
set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
ID="$REPO/skills/sassy-overview/scripts/identify.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/sassy-overview.XXXXXX")"
trap 'chmod -R u+rw "$TMP" 2>/dev/null; rm -rf "$TMP"' EXIT
fails=0
pass() { printf 'ok   %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1"; [[ -n "${2:-}" ]] && printf '%s\n' "$2" | sed 's/^/     /'; fails=$((fails + 1)); }

OUT=""
RC=0
run() { # run <root> [args...]
  local root="$1"; shift
  OUT="$(bash "$ID" --root "$root" "$@" 2>&1)"; RC=$?
}
expect() { # expect <name> <expected> <actual>
  if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "$(printf -- '--- expected ---\n%s\n--- actual ---\n%s' "$2" "$3")"; fi
}
expect_rc() { # expect_rc <name> <expected> <actual>
  if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "expected exit $2, got $3"; fi
}
expect_contains() { # expect_contains <name> <needle>
  case "$OUT" in
    *"$2"*) pass "$1" ;;
    *) fail "$1" "missing: $2"$'\n'"$OUT" ;;
  esac
}

# A tab-separated value line, so the fixtures below stay readable.
line() { printf '%s\t%s\t%s' "$1" "$2" "$3"; }

# --- fixtures -------------------------------------------------------------
F="$TMP/fixtures"
mkdir -p "$F"/{go,python,python-req,python-poetry,python-uv,node,node-pnpm,node-yarn,node-bun,node-pkgm,node-empty-scripts,node-inline,node-perm,node-brace,deno,deno-jsonc,deno-jsonc-dev-commented,deno-jsonc-tasks-commented,deno-jsonc-url,deno-jsonc-trailing,deno-brace,deno-large,deno-notasks,dart,dart-plain,rust,php,ruby,make,make-assign,just,just-assign,both,compose,env,empty}

printf 'module example.com/demo\n\ngo 1.22\n' > "$F/go/go.mod"

printf '[project]\nname = "demo"\n' > "$F/python/pyproject.toml"
printf 'DEMO=1\n' > "$F/python/.env.example"
mkdir -p "$F/python/.sassywares"
printf 'commit:\n  branch: current\n' > "$F/python/.sassywares/config.yaml"

printf 'requests\n' > "$F/python-req/requirements.txt"
printf '[project]\nname = "demo"\n' > "$F/python-poetry/pyproject.toml"
printf 'package = []\n' > "$F/python-poetry/poetry.lock"
printf '[project]\nname = "demo"\n' > "$F/python-uv/pyproject.toml"
printf 'version = 1\n' > "$F/python-uv/uv.lock"

cat > "$F/node/package.json" <<'JSON'
{
  "name": "demo",
  "scripts": {
    "dev": "vite",
    "test": "vitest run"
  }
}
JSON

# One lockfile per fixture: the manager is read from the lock, then the field.
printf '{"name": "demo"}\n' > "$F/node-pnpm/package.json"
printf 'lockfileVersion: 9.0\n' > "$F/node-pnpm/pnpm-lock.yaml"
printf '{"name": "demo"}\n' > "$F/node-yarn/package.json"
printf '# yarn lockfile v1\n' > "$F/node-yarn/yarn.lock"
printf '{"name": "demo"}\n' > "$F/node-bun/package.json"
printf 'binary\n' > "$F/node-bun/bun.lockb"
printf '{"name": "demo", "packageManager": "pnpm@9.1.0"}\n' > "$F/node-pkgm/package.json"

# An empty `scripts` object next to a neighbouring object that has a `test`
# key must not fabricate `test → npm test`.
printf '{"scripts": {}, "jest": {"test": "jest"}}\n' > "$F/node-empty-scripts/package.json"
# A single-line, non-empty `scripts` object must still be read.
printf '{"name": "demo", "scripts": {"test": "vitest run"}}\n' > "$F/node-inline/package.json"
# An unreadable manifest must not turn into a shell failure (exit 1).
printf '{"name": "demo"}\n' > "$F/node-perm/package.json"
chmod 000 "$F/node-perm/package.json"

# A `}` inside a script value is data, not the end of the `scripts` block: it
# must not hide the `test` entry that follows it.
cat > "$F/node-brace/package.json" <<'JSON'
{
  "scripts": {
    "dev": "echo }hi",
    "test": "deno test"
  }
}
JSON

cat > "$F/deno/deno.json" <<'JSON'
{
  "tasks": {
    "dev": "deno run -A main.ts",
    "down": "echo stopping",
    "test": "deno test"
  }
}
JSON

# A .jsonc manifest: comments are legal, and `start` is the declared up.
cat > "$F/deno-jsonc/deno.jsonc" <<'JSON'
{
  // comments are legal in a deno.jsonc
  "tasks": {
    "start": "deno run -A main.ts"
  },
  "imports": {
    "std/": "https://deno.land/std@0.220.0/"
  }
}
JSON

# A comment is not a declaration: a `dev` task that exists only in a comment
# declares nothing, while the real `down` and `test` tasks still answer.
cat > "$F/deno-jsonc-dev-commented/deno.jsonc" <<'JSON'
{
  "tasks": {
    // "dev": "deno run -A main.ts",
    "down": "echo stopping",
    "test": "deno test"
  }
}
JSON

# A whole commented-out `tasks` block is absent, so the runner is plain deno.
cat > "$F/deno-jsonc-tasks-commented/deno.jsonc" <<'JSON'
{
  // "tasks": {
  //   "dev": "deno run -A main.ts"
  // },
  "lint": {
    "include": ["src"]
  }
}
JSON

# `//` inside a string is part of the value, not the start of a comment.
cat > "$F/deno-jsonc-url/deno.jsonc" <<'JSON'
{
  "tasks": {
    "serve": "deno run https://x/y.ts"
  },
  "imports": {
    "std/": "https://deno.land/std@0.220.0/"
  }
}
JSON

# A trailing comment after a real task does not hide it, and an escaped quote
# does not end the string early.
cat > "$F/deno-jsonc-trailing/deno.jsonc" <<'JSON'
{
  "tasks": {
    "start": "echo \"starting\" && deno run -A main.ts", // the entry point
    "test": "deno test" // trailing comment
  }
}
JSON

# A `}` inside an earlier task value is data too: without quote state it ends
# `tasks` early and hides the `dev` task that follows it.
cat > "$F/deno-brace/deno.jsonc" <<'JSON'
{
  "tasks": {
    "start": "echo }close",
    "dev": "echo {open"
  }
}
JSON

# A large manifest: 360 KB of comments before a real `tasks` block. The block
# probe finds it early, and exiting there kills the comment stripper with
# SIGPIPE, which `pipefail` turns into a declared block reading as absent.
{
  i=0
  while [ "$i" -lt 6000 ]; do
    printf '// padding %05d xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\n' "$i"
    i=$((i + 1))
  done
  printf '%s\n' '{' '  "tasks": {' '    "dev": "deno run -A main.ts"' '  }' '}'
} > "$F/deno-large/deno.jsonc"

# No `tasks` block: the manifest declares no runnable commands at all.
printf '{\n  "imports": {\n    "std/": "https://deno.land/std@0.220.0/"\n  }\n}\n' > "$F/deno-notasks/deno.json"

printf 'name: demo\nenvironment:\n  sdk: ">=3.0.0 <4.0.0"\ndependencies:\n  flutter:\n    sdk: flutter\n' > "$F/dart/pubspec.yaml"
printf 'name: demo\nenvironment:\n  sdk: ">=3.0.0 <4.0.0"\n' > "$F/dart-plain/pubspec.yaml"

printf '[package]\nname = "demo"\nversion = "0.1.0"\n' > "$F/rust/Cargo.toml"

cat > "$F/php/composer.json" <<'JSON'
{
  "name": "demo/demo",
  "scripts": {
    "test": "phpunit"
  }
}
JSON

printf 'source "https://rubygems.org"\ngem "rails"\n' > "$F/ruby/Gemfile"

printf 'dev:\n\tnpm run dev\n\ntest:\n\tnpm test\n' > "$F/make/Makefile"
# An assignment is not a target: `dev:=1` declares nothing to run.
printf 'dev:=1\n' > "$F/make-assign/Makefile"

printf 'dev:\n    npm run dev\n\ntest:\n    npm test\n\ndown:\n    docker compose down\n' > "$F/just/justfile"
# An assignment is not a recipe: `dev := "x"` declares nothing to run.
printf 'dev := "x"\n' > "$F/just-assign/justfile"

# Both declared: just outranks make.
printf 'dev:\n\tnpm run dev\n' > "$F/both/Makefile"
printf 'dev:\n    npm run dev\n' > "$F/both/justfile"

printf 'services:\n  web:\n    image: nginx\n' > "$F/compose/compose.yaml"

# `.env` outranks `.env.example`.
printf 'DEMO=1\n' > "$F/env/.env"
printf 'DEMO=\n' > "$F/env/.env.example"

# A repo nested inside a folder that owns the config is wired, via the walk-up.
mkdir -p "$F/wired-nested/.sassywares" "$F/wired-nested/repo"
printf 'commit:\n  branch: current\n' > "$F/wired-nested/.sassywares/config.yaml"
NESTED_PARENT="$(cd "$F/wired-nested" && pwd -P)"
NESTED_REPO="$(cd "$F/wired-nested/repo" && pwd -P)"

# --- full output, one fixture at a time -----------------------------------
run "$F/go"
expect "go: every key" "$(printf '%s\n' \
  "$(line stack go go.mod)" \
  "$(line runner go go.mod)" \
  "$(line install 'go mod download' go.mod)" \
  "$(line up unknown -)" \
  "$(line down unknown -)" \
  "$(line test 'go test ./...' go.mod)" \
  "$(line compose unknown -)" \
  "$(line env unknown -)" \
  "$(line wired no -)")" "$OUT"
expect_rc "go: the default run is an inventory and exits 0" 0 "$RC"

run "$F/python"
expect "python: stack, install, env, and wired" "$(printf '%s\n' \
  "$(line stack python pyproject.toml)" \
  "$(line runner pip pyproject.toml)" \
  "$(line install 'pip install -e .' pyproject.toml)" \
  "$(line up unknown -)" \
  "$(line down unknown -)" \
  "$(line test unknown -)" \
  "$(line compose unknown -)" \
  "$(line env .env.example .env.example)" \
  "$(line wired yes .sassywares/config.yaml)")" "$OUT"
expect_rc "python: default exits 0" 0 "$RC"

run "$F/python-req" stack runner install
expect "python: requirements.txt installs from the file" "$(printf '%s\n' \
  "$(line stack python requirements.txt)" \
  "$(line runner pip requirements.txt)" \
  "$(line install 'pip install -r requirements.txt' requirements.txt)")" "$OUT"
expect_rc "python requirements.txt: exits 0" 0 "$RC"

run "$F/python-poetry" stack runner install
expect "python: poetry from its lockfile" "$(printf '%s\n' \
  "$(line stack python pyproject.toml)" \
  "$(line runner poetry poetry.lock)" \
  "$(line install 'poetry install' poetry.lock)")" "$OUT"
expect_rc "python poetry: exits 0" 0 "$RC"

run "$F/python-uv" stack runner install
expect "python: uv from its lockfile" "$(printf '%s\n' \
  "$(line stack python pyproject.toml)" \
  "$(line runner uv uv.lock)" \
  "$(line install 'uv sync' uv.lock)")" "$OUT"
expect_rc "python uv: exits 0" 0 "$RC"

run "$F/node"
expect "node: npm, its lockfile-free install, and the declared test" "$(printf '%s\n' \
  "$(line stack node package.json)" \
  "$(line runner npm package.json)" \
  "$(line install 'npm install' package.json)" \
  "$(line up unknown -)" \
  "$(line down unknown -)" \
  "$(line test 'npm test' package.json)" \
  "$(line compose unknown -)" \
  "$(line env unknown -)" \
  "$(line wired no -)")" "$OUT"
expect_rc "node: default exits 0" 0 "$RC"

run "$F/node-pnpm" runner install
expect "node: pnpm from pnpm-lock.yaml" "$(printf '%s\n' \
  "$(line runner pnpm pnpm-lock.yaml)" \
  "$(line install 'pnpm install' pnpm-lock.yaml)")" "$OUT"
expect_rc "node pnpm-lock.yaml: exits 0" 0 "$RC"

run "$F/node-yarn" runner install
expect "node: yarn from yarn.lock" "$(printf '%s\n' \
  "$(line runner yarn yarn.lock)" \
  "$(line install 'yarn install' yarn.lock)")" "$OUT"
expect_rc "node yarn.lock: exits 0" 0 "$RC"

run "$F/node-bun" runner install
expect "node: bun from bun.lockb" "$(printf '%s\n' \
  "$(line runner bun bun.lockb)" \
  "$(line install 'bun install' bun.lockb)")" "$OUT"
expect_rc "node bun.lockb: exits 0" 0 "$RC"

run "$F/node-pkgm" runner install
expect "node: the packageManager field when no lockfile exists" "$(printf '%s\n' \
  "$(line runner pnpm package.json)" \
  "$(line install 'pnpm install' package.json)")" "$OUT"
expect_rc "node packageManager: exits 0" 0 "$RC"

run "$F/node-empty-scripts" test
expect "node: an empty scripts object does not borrow a neighbour's test" "$(line test unknown -)" "$OUT"
expect_rc "node empty scripts: a requested unknown test exits 3" 3 "$RC"

run "$F/node-inline" test
expect "node: a single-line scripts object is read" "$(line test 'npm test' package.json)" "$OUT"
expect_rc "node single-line scripts: exits 0" 0 "$RC"

run "$F/node-perm"
expect "node: an unreadable package.json still answers, never a shell failure" "$(printf '%s\n' \
  "$(line stack node package.json)" \
  "$(line runner npm package.json)" \
  "$(line install 'npm install' package.json)" \
  "$(line up unknown -)" \
  "$(line down unknown -)" \
  "$(line test unknown -)" \
  "$(line compose unknown -)" \
  "$(line env unknown -)" \
  "$(line wired no -)")" "$OUT"
expect_rc "node unreadable manifest: exits 0, never 1" 0 "$RC"

run "$F/node-brace" up test
# The brace does not close `scripts`, so the `test` entry after it is still read.
expect "node: a brace inside a script value does not close the scripts block" "$(printf '%s\n' \
  "$(line up unknown -)" \
  "$(line test 'npm test' package.json)")" "$OUT"
expect_rc "node brace in script: a requested unknown up exits 3" 3 "$RC"

run "$F/deno"
expect "deno: deno task, and the declared dev, down, and test tasks" "$(printf '%s\n' \
  "$(line stack deno deno.json)" \
  "$(line runner 'deno task' deno.json)" \
  "$(line install unknown -)" \
  "$(line up 'deno task dev' deno.json)" \
  "$(line down 'deno task down' deno.json)" \
  "$(line test 'deno task test' deno.json)" \
  "$(line compose unknown -)" \
  "$(line env unknown -)" \
  "$(line wired no -)")" "$OUT"
expect_rc "deno: default exits 0" 0 "$RC"

run "$F/deno-jsonc" stack runner up
# The `imports` object next to `tasks` never leaks into the task read.
expect "deno.jsonc: the manifest, deno task, and the start task" "$(printf '%s\n' \
  "$(line stack deno deno.jsonc)" \
  "$(line runner 'deno task' deno.jsonc)" \
  "$(line up 'deno task start' deno.jsonc)")" "$OUT"
expect_rc "deno.jsonc: exits 0" 0 "$RC"

run "$F/deno-jsonc-dev-commented"
# The commented-out `dev` is not a task: no up is invented, but the real `down`
# and `test` are still reported.
expect "deno.jsonc: a commented-out dev declares no up, but real tasks answer" "$(printf '%s\n' \
  "$(line stack deno deno.jsonc)" \
  "$(line runner 'deno task' deno.jsonc)" \
  "$(line install unknown -)" \
  "$(line up unknown -)" \
  "$(line down 'deno task down' deno.jsonc)" \
  "$(line test 'deno task test' deno.jsonc)" \
  "$(line compose unknown -)" \
  "$(line env unknown -)" \
  "$(line wired no -)")" "$OUT"
expect_rc "deno.jsonc commented-out dev: the inventory exits 0" 0 "$RC"

run "$F/deno-jsonc-dev-commented" up
# Asking for the up gets the honest unknown, never the commented-out task.
expect "deno.jsonc: a requested up stays unknown behind the comment" "$(line up unknown -)" "$OUT"
expect_rc "deno.jsonc commented-out dev: a requested unknown up exits 3" 3 "$RC"

run "$F/deno-jsonc-tasks-commented"
# A fully commented-out block is absent: plain deno, and no command invented.
expect "deno.jsonc: a commented-out tasks block is absent, so the runner is deno" "$(printf '%s\n' \
  "$(line stack deno deno.jsonc)" \
  "$(line runner deno deno.jsonc)" \
  "$(line install unknown -)" \
  "$(line up unknown -)" \
  "$(line down unknown -)" \
  "$(line test unknown -)" \
  "$(line compose unknown -)" \
  "$(line env unknown -)" \
  "$(line wired no -)")" "$OUT"
expect_rc "deno.jsonc commented-out tasks: the inventory exits 0" 0 "$RC"

run "$F/deno-jsonc-url" stack runner up
# A URL in the value is not a `//` comment, so the task survives intact.
expect "deno.jsonc: a task whose command holds a URL is still reported" "$(printf '%s\n' \
  "$(line stack deno deno.jsonc)" \
  "$(line runner 'deno task' deno.jsonc)" \
  "$(line up 'deno task serve' deno.jsonc)")" "$OUT"
expect_rc "deno.jsonc URL: exits 0" 0 "$RC"

run "$F/deno-jsonc-trailing" runner up test
# A `//` comment after a real task is dropped, not the task.
expect "deno.jsonc: a trailing comment after a real task does not hide it" "$(printf '%s\n' \
  "$(line runner 'deno task' deno.jsonc)" \
  "$(line up 'deno task start' deno.jsonc)" \
  "$(line test 'deno task test' deno.jsonc)")" "$OUT"
expect_rc "deno.jsonc trailing comments: exits 0" 0 "$RC"

run "$F/deno-notasks"
expect "deno: a tasks-less manifest answers unknown for every command" "$(printf '%s\n' \
  "$(line stack deno deno.json)" \
  "$(line runner deno deno.json)" \
  "$(line install unknown -)" \
  "$(line up unknown -)" \
  "$(line down unknown -)" \
  "$(line test unknown -)" \
  "$(line compose unknown -)" \
  "$(line env unknown -)" \
  "$(line wired no -)")" "$OUT"
expect_rc "deno without tasks: the inventory exits 0" 0 "$RC"

run "$F/deno-notasks" up
# A task that is not declared is never the up: no `deno task dev` guessed.
expect "deno: a requested up with no declared task stays unknown" "$(line up unknown -)" "$OUT"
expect_rc "deno without tasks: a requested unknown up exits 3" 3 "$RC"

run "$F/deno-brace" runner up
# The earlier task's `}` does not end `tasks`, so `dev` after it is still read.
expect "deno.jsonc: a brace inside a task value does not close the tasks block" "$(printf '%s\n' \
  "$(line runner 'deno task' deno.jsonc)" \
  "$(line up 'deno task dev' deno.jsonc)")" "$OUT"
expect_rc "deno.jsonc brace in task: exits 0" 0 "$RC"

run "$F/deno-large" runner up
# Size is not structure: a manifest far larger than a pipe buffer still answers.
expect "deno.jsonc: a >300 KB manifest with a real tasks block still reads" "$(printf '%s\n' \
  "$(line runner 'deno task' deno.jsonc)" \
  "$(line up 'deno task dev' deno.jsonc)")" "$OUT"
expect_rc "deno.jsonc large manifest: exits 0" 0 "$RC"

run "$F/dart"
expect "dart/flutter: flutter SDK and pub commands" "$(printf '%s\n' \
  "$(line stack dart pubspec.yaml)" \
  "$(line runner flutter pubspec.yaml)" \
  "$(line install 'flutter pub get' pubspec.yaml)" \
  "$(line up unknown -)" \
  "$(line down unknown -)" \
  "$(line test 'flutter test' pubspec.yaml)" \
  "$(line compose unknown -)" \
  "$(line env unknown -)" \
  "$(line wired no -)")" "$OUT"
expect_rc "dart/flutter: default exits 0" 0 "$RC"

run "$F/dart-plain" stack runner install
expect "dart: a pubspec without the Flutter SDK uses dart" "$(printf '%s\n' \
  "$(line stack dart pubspec.yaml)" \
  "$(line runner dart pubspec.yaml)" \
  "$(line install 'dart pub get' pubspec.yaml)")" "$OUT"
expect_rc "dart plain: exits 0" 0 "$RC"

run "$F/rust"
expect "rust: cargo" "$(printf '%s\n' \
  "$(line stack rust Cargo.toml)" \
  "$(line runner cargo Cargo.toml)" \
  "$(line install 'cargo fetch' Cargo.toml)" \
  "$(line up unknown -)" \
  "$(line down unknown -)" \
  "$(line test 'cargo test' Cargo.toml)" \
  "$(line compose unknown -)" \
  "$(line env unknown -)" \
  "$(line wired no -)")" "$OUT"
expect_rc "rust: default exits 0" 0 "$RC"

run "$F/php"
expect "php: composer, and its declared test script" "$(printf '%s\n' \
  "$(line stack php composer.json)" \
  "$(line runner composer composer.json)" \
  "$(line install 'composer install' composer.json)" \
  "$(line up unknown -)" \
  "$(line down unknown -)" \
  "$(line test 'composer test' composer.json)" \
  "$(line compose unknown -)" \
  "$(line env unknown -)" \
  "$(line wired no -)")" "$OUT"
expect_rc "php: default exits 0" 0 "$RC"

run "$F/ruby"
expect "ruby: bundler" "$(printf '%s\n' \
  "$(line stack ruby Gemfile)" \
  "$(line runner bundle Gemfile)" \
  "$(line install 'bundle install' Gemfile)" \
  "$(line up unknown -)" \
  "$(line down unknown -)" \
  "$(line test unknown -)" \
  "$(line compose unknown -)" \
  "$(line env unknown -)" \
  "$(line wired no -)")" "$OUT"
expect_rc "ruby: default exits 0" 0 "$RC"

run "$F/make"
expect "make: the runner, and its dev and test targets" "$(printf '%s\n' \
  "$(line stack unknown -)" \
  "$(line runner make Makefile)" \
  "$(line install unknown -)" \
  "$(line up 'make dev' Makefile)" \
  "$(line down unknown -)" \
  "$(line test 'make test' Makefile)" \
  "$(line compose unknown -)" \
  "$(line env unknown -)" \
  "$(line wired no -)")" "$OUT"
expect_rc "make: default exits 0" 0 "$RC"

run "$F/make-assign" up runner
expect "make: an assignment line is not a target" "$(printf '%s\n' \
  "$(line up unknown -)" \
  "$(line runner make Makefile)")" "$OUT"
expect_rc "make assignment: a requested unknown up exits 3" 3 "$RC"

run "$F/just"
expect "just: the runner, dev, test, and down recipes" "$(printf '%s\n' \
  "$(line stack unknown -)" \
  "$(line runner just justfile)" \
  "$(line install unknown -)" \
  "$(line up 'just dev' justfile)" \
  "$(line down 'just down' justfile)" \
  "$(line test 'just test' justfile)" \
  "$(line compose unknown -)" \
  "$(line env unknown -)" \
  "$(line wired no -)")" "$OUT"
expect_rc "just: default exits 0" 0 "$RC"

run "$F/just-assign" up runner
expect "just: an assignment line is not a recipe" "$(printf '%s\n' \
  "$(line up unknown -)" \
  "$(line runner just justfile)")" "$OUT"
expect_rc "just assignment: a requested unknown up exits 3" 3 "$RC"

run "$F/both" runner up
expect "make and just: just outranks make" "$(printf '%s\n' \
  "$(line runner just justfile)" \
  "$(line up 'just dev' justfile)")" "$OUT"
expect_rc "make and just together: exits 0" 0 "$RC"

run "$F/compose"
expect "compose: the file, up, down, and docker as runner" "$(printf '%s\n' \
  "$(line stack unknown -)" \
  "$(line runner docker compose.yaml)" \
  "$(line install unknown -)" \
  "$(line up 'docker compose up' compose.yaml)" \
  "$(line down 'docker compose down' compose.yaml)" \
  "$(line test unknown -)" \
  "$(line compose compose.yaml compose.yaml)" \
  "$(line env unknown -)" \
  "$(line wired no -)")" "$OUT"
expect_rc "compose: default exits 0" 0 "$RC"

run "$F/env" env
expect "env: .env outranks .env.example" "$(line env .env .env)" "$OUT"
expect_rc "env: exits 0" 0 "$RC"

run "$F/empty"
expect "empty: every fact unknown, and nothing invented" "$(printf '%s\n' \
  "$(line stack unknown -)" \
  "$(line runner unknown -)" \
  "$(line install unknown -)" \
  "$(line up unknown -)" \
  "$(line down unknown -)" \
  "$(line test unknown -)" \
  "$(line compose unknown -)" \
  "$(line env unknown -)" \
  "$(line wired no -)")" "$OUT"
expect_rc "empty: the default run still exits 0" 0 "$RC"

# --- wired walks up, like detect.sh --------------------------------------
run "$NESTED_PARENT" wired
expect "wired: a repo at the config's root names it relatively" \
  "$(line wired yes .sassywares/config.yaml)" "$OUT"
expect_rc "wired at the root: exits 0" 0 "$RC"

run "$NESTED_REPO" wired
expect "wired: a nested repo finds the parent's config and names it absolutely" \
  "$(line wired yes "$NESTED_PARENT/.sassywares/config.yaml")" "$OUT"
expect_rc "wired nested: exits 0" 0 "$RC"

run "$F/empty" wired
expect "wired: no config anywhere above is a real no" "$(line wired no -)" "$OUT"
expect_rc "wired none: exits 0" 0 "$RC"

# --- requested keys, and the exit codes ----------------------------------
run "$F/go" test
expect "requesting one key prints only it" "$(line test 'go test ./...' go.mod)" "$OUT"
expect_rc "a requested key that is known exits 0" 0 "$RC"

run "$F/go" stack --key test
expect "requested keys keep their named order" "$(printf '%s\n' \
  "$(line stack go go.mod)" \
  "$(line test 'go test ./...' go.mod)")" "$OUT"
expect_rc "two known keys exit 0" 0 "$RC"

run "$F/empty" stack
expect_rc "a requested key with no answer exits 3" 3 "$RC"
expect "…and still prints the line" "$(line stack unknown -)" "$OUT"

run "$F/empty" --key up
expect_rc "--key with no answer exits 3" 3 "$RC"
expect "…and prints up" "$(line up unknown -)" "$OUT"

run "$F/go" stack up
expect_rc "one unknown among known keys exits 3" 3 "$RC"
expect "…and prints both in order" "$(printf '%s\n' \
  "$(line stack go go.mod)" \
  "$(line up unknown -)")" "$OUT"

# --- the argument forms --------------------------------------------------
OUT="$(bash "$ID" --root="$F/go" --key=stack 2>&1)"; RC=$?
expect "--root=DIR and --key=KEY are accepted" "$(line stack go go.mod)" "$OUT"
expect_rc "--root=DIR and --key=KEY: exits 0" 0 "$RC"

OUT="$(bash "$ID" --root="$F/go" --key=test stack 2>&1)"; RC=$?
expect "--root=DIR and --key=KEY keep their named order" "$(printf '%s\n' \
  "$(line test 'go test ./...' go.mod)" \
  "$(line stack go go.mod)")" "$OUT"
expect_rc "--root=DIR and --key=KEY: two known keys exit 0" 0 "$RC"

run "$F/go" bogus
expect_rc "an unknown key name is a usage error" 2 "$RC"
expect_contains "…and says which key" "unknown key 'bogus'"

run "$F/go" --bogus
expect_rc "an unknown option is a usage error" 2 "$RC"

run "$TMP/nope"
expect_rc "a missing --root is a usage error" 2 "$RC"

# --- cwd is the default root --------------------------------------------
OUT="$(cd "$F/node" && bash "$ID" 2>&1)"; RC=$?
expect_contains "no --root answers for the cwd" "$(line stack node package.json)"
expect_rc "no --root: the inventory exits 0" 0 "$RC"

# --- read-only -----------------------------------------------------------
before="$(cd "$F/empty" && find . | sort | shasum)"
run "$F/empty"
after="$(cd "$F/empty" && find . | sort | shasum)"
expect "identify writes no file" "$before" "$after"

echo
if (( fails == 0 )); then
  echo "all checks passed"
  exit 0
fi
echo "$fails check(s) failed"
exit 1
