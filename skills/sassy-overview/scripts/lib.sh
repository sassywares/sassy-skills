#!/usr/bin/env bash
# Helpers for sassy-overview's identify.sh.
#
# Read-only file inspection and nothing else: no network, no executing the
# project's tooling (not even `make -n`), no writes. Every helper answers from a
# file's bytes or not at all — "unknown" is the honest answer, never a guess.
#
# Sourced by identify.sh, never run directly. It is a query, so it is invoked by
# path from the skill directory and is never installed into a project's
# `.sassywares/`.

# The key list, in table order, defined once: id_scan initialises every key from
# it and identify.sh validates and prints from it.
ID_KEYS="stack runner install up down test compose env wired"

# One value and one source per key, as plain variables: bash 3.2 has no
# associative arrays, and this runs on a stock macOS shell.
id_v() { printf -v "ID_V_$1" '%s' "$2"; }
id_s() { printf -v "ID_S_$1" '%s' "${2:--}"; }
id_set() { id_v "$1" "$2"; id_s "$1" "${3:--}"; }
id_unknown() { id_set "$1" unknown; }
id_value() { local n="ID_V_$1"; printf '%s' "${!n}"; }
id_source() { local n="ID_S_$1"; printf '%s' "${!n}"; }

# The first candidate that exists under ID_ROOT, printed relative to it.
id_first_file() {
  local f
  for f in "$@"; do
    [ -f "$ID_ROOT/$f" ] && { printf '%s' "$f"; return 0; }
  done
  return 1
}

# The nearest `.sassywares/config.yaml`, walking up from ID_ROOT the way
# `sassy-setup`'s detect.sh resolves it. Printed relative to ID_ROOT when it is
# there, and as an absolute path when it belongs to a parent directory.
id_config() {
  local probe="$ID_ROOT"
  while :; do
    if [ -f "$probe/.sassywares/config.yaml" ]; then
      if [ "$probe" = "$ID_ROOT" ]; then
        printf '%s' .sassywares/config.yaml
      else
        printf '%s' "$probe/.sassywares/config.yaml"
      fi
      return 0
    fi
    [ "$probe" = / ] && return 1
    probe="$(dirname "$probe")"
  done
}

# The node package manager, from its lockfile and then the manifest's
# `packageManager` field. Sets ID_PM and ID_PM_SRC.
id_node_pm() {
  local pair
  for pair in "bun.lockb:bun" "bun.lock:bun" "pnpm-lock.yaml:pnpm" "yarn.lock:yarn"; do
    if [ -f "$ID_ROOT/${pair%%:*}" ]; then
      ID_PM="${pair#*:}"; ID_PM_SRC="${pair%%:*}"; return 0
    fi
  done
  # An unreadable or missing manifest leaves the value empty rather than killing
  # the run: identify's own exit codes are 0, 3 and 2, never a shell's 1.
  ID_PM="$(sed -n 's/.*"packageManager"[[:space:]]*:[[:space:]]*"\([a-z]*\)@.*/\1/p' "$ID_ROOT/package.json" 2>/dev/null | head -n 1)" || ID_PM=""
  [ -n "$ID_PM" ] || ID_PM="npm"
  ID_PM_SRC="package.json"
}

# One named entry from a JSON object such as package.json's `scripts` or
# deno.json's `tasks`. Prints its command, and nothing when the object or the
# name is absent. The block-opening brace is found on the same line, so both a
# pretty-printed and a single-line object are read.
id_json_block_script() { # <file> <block> <name>
  awk -v block="$2" -v want="$3" '
    function emit(line,   i, rest, out, j, c) {
      i = index(line, "\"" want "\"")
      if (!i) return
      rest = substr(line, i + length(want) + 2)
      if (!match(rest, /^[ \t]*:[ \t]*"/)) return
      rest = substr(rest, RLENGTH + 1)
      out = ""
      for (j = 1; j <= length(rest); j++) {
        c = substr(rest, j, 1)
        if (c == "\\") { out = out c substr(rest, j + 1, 1); j++; continue }
        if (c == "\"") break
        out = out c
      }
      if (out != "") found = out
    }
    # Where the `scripts` block closes on this text, or 0 when it does not. The
    # block-opening brace is already behind us, so the first unmatched `}` ends
    # it — which is what keeps a neighbouring object'"'"'s `test` out of reach.
    # A brace inside a string is data, not structure: without quote and escape
    # state a command like `echo }hi` closes the block early and hides every
    # task after it. JSON strings do not span lines, so both reset per line.
    function block_end(text,   i, c, depth, q, esc) {
      depth = 0; q = 0; esc = 0
      for (i = 1; i <= length(text); i++) {
        c = substr(text, i, 1)
        if (q) {
          if (esc) { esc = 0; continue }
          if (c == "\\") { esc = 1; continue }
          if (c == "\"") q = 0
          continue
        }
        if (c == "\"") { q = 1; continue }
        if (c == "{") depth++
        else if (c == "}") { if (depth == 0) return i; depth-- }
      }
      return 0
    }
    {
      if (!inb) {
        i = index($0, "\"" block "\"")
        if (i) {
          rest = substr($0, i + length(block) + 2)
          if (match(rest, /^[ \t]*:[ \t]*\{/)) {
            inb = 1
            rest = substr(rest, RLENGTH + 1)
            cut = block_end(rest)
            if (cut) { emit(substr(rest, 1, cut - 1)); inb = 0 }
            else emit(rest)
          }
        }
        next
      }
      cut = block_end($0)
      if (cut) { emit(substr($0, 1, cut - 1)); inb = 0 }
      else emit($0)
    }
    END { if (found != "") print found }
  ' "$1" 2>/dev/null
}

# A package.json `scripts` entry, through the shared JSON block reader above.
id_pkg_script() { # <package.json> <script name>
  id_json_block_script "$1" scripts "$2"
}

# Whether a JSON object declares a block at all — an empty `"tasks": {}` is a
# declared block, so this cannot be answered by looking for an entry in it.
id_json_has_block() { # <file> <block>
  awk -v block="$2" '
    {
      i = index($0, "\"" block "\"")
      if (!i) next
      rest = substr($0, i + length(block) + 2)
      # Set the flag and keep reading: exiting here closes the pipe on the
      # producer, and under `set -o pipefail` its SIGPIPE (141) reports a
      # declared block as absent. Let END decide, after the input is drained.
      if (match(rest, /^[ \t]*:[ \t]*\{/)) found = 1
    }
    END { exit(found ? 0 : 1) }
  ' "$1" 2>/dev/null
}

# A JSONC manifest with its comments removed, one line at a time. A character
# scanner, not a regex: `//` and `/* */` are dropped only outside a string, so a
# `"https://..."` value and an escaped quote stay intact. Commented-out JSON is
# not a declaration, and this is what makes that true for `.jsonc`.
id_strip_jsonc() { # <file>
  awk '
    {
      line = $0; n = length(line); out = ""; i = 1
      while (i <= n) {
        c = substr(line, i, 1)
        if (in_block) {
          if (c == "*" && substr(line, i + 1, 1) == "/") { in_block = 0; i += 2; continue }
          i++; continue
        }
        if (in_str) {
          out = out c
          if (c == "\\") { out = out substr(line, i + 1, 1); i += 2; continue }
          if (c == "\"") in_str = 0
          i++; continue
        }
        if (c == "\"") { in_str = 1; out = out c; i++; continue }
        if (c == "/" && substr(line, i + 1, 1) == "/") break
        if (c == "/" && substr(line, i + 1, 1) == "*") { in_block = 1; i += 2; continue }
        out = out c; i++
      }
      print out
    }
  ' "$1" 2>/dev/null
}

# A declaration line, not an assignment: `dev:` is a target, `dev:=1` is not.
id_make_target() { # <Makefile> <target>
  grep -qE "^$2[[:space:]]*:([^=]|$)" "$1" 2>/dev/null
}

# A recipe (`dev:` or `dev arg="x":`) or an alias — never an assignment
# (`dev := "x"`), which no runner would accept as a task.
id_just_recipe() { # <justfile> <recipe>
  grep -qE "^@?$2([[:space:]]+[^:]*)?[[:space:]]*:([^=]|$)" "$1" 2>/dev/null
}

# A deno.json/deno.jsonc block, with its comments stripped first. Node and PHP
# manifests never come through here: package.json is strict JSON, and their
# answers must stay byte-identical.
id_deno_has_block() { # <deno.json|deno.jsonc> <block>
  id_strip_jsonc "$1" | id_json_has_block - "$2"
}

# A declared deno.json `tasks` entry — an absent block, a commented-out one, or
# an absent name declares nothing.
id_deno_task() { # <deno.json|deno.jsonc> <task>
  [ -n "$(id_strip_jsonc "$1" | id_json_block_script - tasks "$2")" ]
}

id_has_flutter() { # <pubspec.yaml>
  grep -qE '^[[:space:]]*flutter:' "$1" 2>/dev/null
}

# The first candidate the predicate recognizes, as `<runner> <candidate>`.
id_task() { # <runner> <file> <predicate> <candidate>...
  local runner="$1" file="$2" pred="$3" c
  shift 3
  for c in "$@"; do
    if "$pred" "$ID_ROOT/$file" "$c"; then printf '%s %s' "$runner" "$c"; return 0; fi
  done
  return 1
}

# Walk the manifest table once and fill every key. Order is the table order in
# references/identify.md: the first stack manifest found wins, and a declared
# task runner (just, then make) outranks the ecosystem's own commands.
id_scan() {
  local py deno makefile justfile compose rc envfile

  for k in $ID_KEYS; do id_unknown "$k"; done
  id_set wired no "-"

  # --- stack and its ecosystem commands -----------------------------------
  if [ -f "$ID_ROOT/go.mod" ]; then
    id_set stack go go.mod
    id_set runner go go.mod
    id_set install "go mod download" go.mod
    id_set test "go test ./..." go.mod
  elif [ -f "$ID_ROOT/package.json" ]; then
    id_node_pm
    id_set stack node package.json
    id_set runner "$ID_PM" "$ID_PM_SRC"
    id_set install "$ID_PM install" "$ID_PM_SRC"
    rc="$(id_pkg_script "$ID_ROOT/package.json" test || true)"
    if [ -n "$rc" ]; then id_set test "$ID_PM test" package.json; fi
  elif deno="$(id_first_file deno.json deno.jsonc)"; then
    # The manifest has no dependency-install step of its own — imports are
    # resolved by the runtime — so `install` stays unknown rather than invented.
    id_set stack deno "$deno"
    if id_deno_has_block "$ID_ROOT/$deno" tasks; then
      id_set runner "deno task" "$deno"
      if rc="$(id_task 'deno task' "$deno" id_deno_task dev start up serve)"; then id_set up "$rc" "$deno"; fi
      if rc="$(id_task 'deno task' "$deno" id_deno_task down stop)"; then id_set down "$rc" "$deno"; fi
      if id_deno_task "$ID_ROOT/$deno" test; then id_set test "deno task test" "$deno"; fi
    else
      id_set runner deno "$deno"
    fi
  elif py="$(id_first_file pyproject.toml requirements.txt setup.py)"; then
    id_set stack python "$py"
    if [ -f "$ID_ROOT/poetry.lock" ]; then
      id_set runner poetry poetry.lock
      id_set install "poetry install" poetry.lock
    elif [ -f "$ID_ROOT/uv.lock" ]; then
      id_set runner uv uv.lock
      id_set install "uv sync" uv.lock
    else
      id_set runner pip "$py"
      if [ "$py" = "requirements.txt" ]; then
        id_set install "pip install -r requirements.txt" requirements.txt
      else
        id_set install "pip install -e ." "$py"
      fi
    fi
  elif [ -f "$ID_ROOT/pubspec.yaml" ]; then
    id_set stack dart pubspec.yaml
    if id_has_flutter "$ID_ROOT/pubspec.yaml"; then
      id_set runner flutter pubspec.yaml
      id_set install "flutter pub get" pubspec.yaml
      id_set test "flutter test" pubspec.yaml
    else
      id_set runner dart pubspec.yaml
      id_set install "dart pub get" pubspec.yaml
      id_set test "dart test" pubspec.yaml
    fi
  elif [ -f "$ID_ROOT/Cargo.toml" ]; then
    id_set stack rust Cargo.toml
    id_set runner cargo Cargo.toml
    id_set install "cargo fetch" Cargo.toml
    id_set test "cargo test" Cargo.toml
  elif [ -f "$ID_ROOT/composer.json" ]; then
    id_set stack php composer.json
    id_set runner composer composer.json
    id_set install "composer install" composer.json
    rc="$(id_pkg_script "$ID_ROOT/composer.json" test || true)"
    if [ -n "$rc" ]; then id_set test "composer test" composer.json; fi
  elif [ -f "$ID_ROOT/Gemfile" ]; then
    id_set stack ruby Gemfile
    id_set runner bundle Gemfile
    id_set install "bundle install" Gemfile
  fi

  # --- declared task runners: make, then just (just wins on a clash) ------
  if makefile="$(id_first_file Makefile makefile GNUmakefile)"; then
    id_set runner make "$makefile"
    if rc="$(id_task make "$makefile" id_make_target dev start up serve)"; then id_set up "$rc" "$makefile"; fi
    if rc="$(id_task make "$makefile" id_make_target down stop)"; then id_set down "$rc" "$makefile"; fi
    if id_make_target "$ID_ROOT/$makefile" test; then id_set test "make test" "$makefile"; fi
  fi
  if justfile="$(id_first_file justfile Justfile .justfile)"; then
    id_set runner just "$justfile"
    if rc="$(id_task just "$justfile" id_just_recipe dev start up serve)"; then id_set up "$rc" "$justfile"; fi
    if rc="$(id_task just "$justfile" id_just_recipe down stop)"; then id_set down "$rc" "$justfile"; fi
    if id_just_recipe "$ID_ROOT/$justfile" test; then id_set test "just test" "$justfile"; fi
  fi

  # --- docker compose: the last word on up/down, and a runner of last resort
  if compose="$(id_first_file compose.yaml compose.yml docker-compose.yml docker-compose.yaml)"; then
    id_set compose "$compose" "$compose"
    if [ "$(id_value up)" = unknown ]; then id_set up "docker compose up" "$compose"; fi
    if [ "$(id_value down)" = unknown ]; then id_set down "docker compose down" "$compose"; fi
    if [ "$(id_value runner)" = unknown ]; then id_set runner docker "$compose"; fi
  fi

  # --- environment files ---------------------------------------------------
  if envfile="$(id_first_file .env .env.local .env.example .env.sample)"; then
    id_set env "$envfile" "$envfile"
  fi

  # --- wired for the suite -------------------------------------------------
  if rc="$(id_config)"; then
    id_set wired yes "$rc"
  fi
}
