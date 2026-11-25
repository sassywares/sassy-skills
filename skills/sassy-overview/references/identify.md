# Identify

`scripts/identify.sh` inspects a project's files and prints one line per key. It is the whole of `mode:identify`: run it, read its lines, branch on its exit code.

```bash
bash <sassy-overview skill>/scripts/identify.sh [--root DIR] [--key KEY]... [KEY]...
```

`--root` defaults to the current directory. Positional keys and `--key KEY` are the same thing; both may be mixed. With no keys it prints every key in table order. `scripts/lib.sh` holds the table and is sourced by `identify.sh` — never invoked directly.

## The contract

Exactly three tab-separated columns, one line per key, no header, no blank lines:

```
key<TAB>value<TAB>source
```

- `key` — one of the nine names below.
- `value` — what the project declares, or `unknown`.
- `source` — the file the value came from, relative to `--root`, or `-` when there is none (`unknown`, and `wired: no`). The one exception: a `.sassywares/config.yaml` belonging to a directory above `--root` has no relative path, so `wired` names it absolutely.

Exit codes decide what a caller may do:

| Code | Meaning | Caller's move |
|---|---|---|
| `0` | answered | use the values |
| `3` | a requested key is `unknown` | say the fact is unknown and stop; never substitute a command |
| `2` | usage error (bad key name, bad option, missing directory) | fix the invocation |

The default run is an **inventory**: it prints every key and exits `0` even when some are unknown, because an inventory is not a question. Naming keys makes it a question — any requested key that is `unknown` makes the run exit `3`, after printing all requested lines. Requested keys print in the order they were named.

Everything is file inspection: no network, no executing the project's tooling (not even `make -n`), no writes. A wrong answer is possible only where the files are ambiguous; a fabricated one is not.

## The keys

| Key | It means | `unknown` when |
|---|---|---|
| `stack` | the project's language ecosystem | no stack manifest in the table |
| `runner` | the tool that runs the project's commands | no task runner and no stack manifest |
| `install` | how dependencies are installed | nothing declared |
| `up` | how the app starts | no declared start target and no compose file |
| `down` | how the app stops | no declared stop target and no compose file |
| `test` | how the test suite runs | nothing declares one (a language default counts only where it is unambiguous) |
| `compose` | the compose file in use | no compose file |
| `env` | the env file in use | no env file |
| `wired` | the suite is set up here | never — the answer is `yes` or `no` |

`up` and `down` are the only keys a project might reasonably have and not declare, and this script reads only what a file declares: a `Makefile`/`justfile` target or a compose file. A project that states them in `.sassywares/config.yaml` (`up:`/`down:`, which `sassy-setup` initializes and the worktree mechanics read) is answering through the config — this script still reports `unknown` for them, because it never reads the suite's own config for a stack fact, and the config is the authority once it names one.

`wired` is the one key that always has an answer: `yes` with the nearest `.sassywares/config.yaml` as its source, otherwise `no` with `-`. The search walks up from `--root` the same way `sassy-setup`'s `detect.sh` resolves a config, so a repo nested inside a folder that owns one is `wired: yes`; the source is then that config's absolute path, since it sits outside the root.

## The manifest table

The first stack manifest in this order wins, so a repo with several gets one stack and one set of ecosystem commands. A `Makefile`/`justfile` then overrides `runner` and any command it declares (just outranks make), and a compose file takes `up`/`down` only where nothing else declared them.

| Stack | Manifest | `runner` | `install` | `test` |
|---|---|---|---|---|
| `go` | `go.mod` | `go` | `go mod download` | `go test ./...` |
| `node` | `package.json` | `bun`/`pnpm`/`yarn`/`npm`, from its lockfile then `packageManager` | `<pm> install` | `<pm> test`, when `scripts.test` exists |
| `deno` | `deno.json`, `deno.jsonc` | `deno task` when it declares `tasks`, else `deno` | — | `deno task test`, when declared |
| `python` | `pyproject.toml`, `requirements.txt`, `setup.py` | `poetry`/`uv` from their lockfile, else `pip` | `poetry install`, `uv sync`, `pip install -r requirements.txt`, or `pip install -e .` | — |
| `dart` | `pubspec.yaml` | `flutter` when the SDK is declared, else `dart` | `flutter pub get` / `dart pub get` | `flutter test` / `dart test` |
| `rust` | `Cargo.toml` | `cargo` | `cargo fetch` | `cargo test` |
| `php` | `composer.json` | `composer` | `composer install` | `composer test`, when `scripts.test` exists |
| `ruby` | `Gemfile` | `bundle` | `bundle install` | — |
| — | `Makefile` | `make` | — | `make test`, when declared |
| — | `justfile` | `just` | — | `just test`, when declared |
| — | `compose.yaml`, `compose.yml`, `docker-compose.yml`, `docker-compose.yaml` | `docker` (last resort) | — | — |

`up` and `down` are declared, never inferred from a language: a `dev`/`start`/`up`/`serve` target in a `Makefile` or `justfile` (or a task of that name in a `deno.json`/`deno.jsonc` `tasks` object), then a compose file (`docker compose up` / `docker compose down`). A node `scripts.dev` is deliberately not read — it says how a tool starts, not how the project comes up. A target is recognized by its declaration line; nothing is executed to prove it exists. A Deno manifest declares no dependency-install step (imports are resolved by the runtime), so its `install` is `unknown` rather than an invented `deno install`.

`env` is the first of `.env`, `.env.local`, `.env.example`, `.env.sample`. Its value is the path, never the contents.

Adding a row to this table means adding a fixture to `tests/sassy-overview-identify.sh` in the same change that asserts the row's real value — not `unknown`. A row without a fixture is a guess with a source column.

## Consuming a value

- **Print the source with the value.** A caller that says `test: go test ./... (go.mod)` can be checked; one that says `test: go test` cannot.
- **Treat `3` as information.** If `up` was requested and is `unknown`, the project has not said how it starts. Report that. Do not invent `npm run dev`, do not write a `Makefile` so an answer exists, and do not fall back to a sibling key.
- **Ask for what you need.** Requesting one key is cheaper to read and gives a sharper exit code than parsing the full inventory.
- **Never cache it.** It is a file read; rerun it after the project's files change rather than trusting a remembered answer.
