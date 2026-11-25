---
name: sassy-overview
description: >-
  Answers what a project is and how it runs — its stack, install, up, down,
  test, compose, env, and whether the suite is wired — from its files, read-only,
  with the source file for every value and `unknown` when nothing is declared.
  Use when a skill or a user needs project facts before acting: setting up a
  repo, deciding how to start or stop it, or checking a stack instead of
  guessing one. Never installs, runs, or changes anything.
argument-hint: "[mode:identify] [key...]"
---

# Sassy Overview

**Outcome:** one definitive, sourced answer to "what is this project and how does it run" — or `unknown` where the project has not said — so no skill has to guess a stack or invent a command.

**The script answers; the skill reads it.** `scripts/identify.sh` (with `scripts/lib.sh`) does the work by inspecting files. It is invoked by path from this skill's directory, is never installed into a project's `.sassywares/`, and needs no config, no pin, and no reconciliation: it is a query.

**Read-only, always.** It reads file bytes. It never touches the network, never executes the project's tooling — not even `make -n` — and writes no file. Anything it cannot see in a file is `unknown`, which is a real answer and never a prompt to guess.

## Modes

| Mode | Load | It ends with |
|---|---|---|
| `identify` (default) | `references/identify.md` | the key/value/source lines, and the facts they prove |

`identify` is the only path today. A later overview (a dependency audit, an environment check) lands as its own script plus its own reference and gets a row here — never as a section appended to `identify`. Read the one reference for the mode you were dispatched to, and only that one.

## Workflow

1. Run `bash <this skill's directory>/scripts/identify.sh --root <project>` — every key, or name the ones you need (`identify.sh --root <project> test up`).
2. Read the three columns: `key`, `value`, `source`. A value with a source is a fact; `unknown` is the project declining to say.
3. Branch on the exit code, never on a guess: `0` answered, `3` a key you requested is unknown, `2` usage. A caller that needs `up` and gets `3` says so and stops; it never substitutes a command it made up.
4. Quote the source file when you pass a value on. "test: `go test ./...` (go.mod)" is auditable; "test: `go test`" is not.

## Hard rules

| Rule | Requirement |
|---|---|
| Files only | No network, no running project tooling, no `make -n`. A command is reported only when a manifest declares it. |
| Every value is sourced | `key<TAB>value<TAB>source`; `-` when there is no file behind it. Never print a value without one. |
| `unknown` is final | Report it. Never fill a gap with a plausible default, and never write a manifest so an answer exists. |
| Exit code is the answer | `3` means the requested fact is unknown; a caller branches on it instead of guessing. |
| Writes nothing | Not the project's tree, not the suite's, not a temp file. |
| Never this skill's job | It does not wire, start, migrate, install, or fix a project. It reports, and `sassy-setup` or the user acts. |

## Consuming it

Any skill that needs project facts names it and runs the script; nothing copies its table.

- `sassy-setup` is the intended consumer: it probes with this script before offering a project's `up:`/`down:` keys, so a project that already declares a command is pointed at it instead of being handed a stub. Once `.sassywares/config.yaml` names `up`/`down`, the config is the authority for those two facts and the worktree mechanics read it; this script keeps reporting what a manifest declares, never the suite's config.
- Nobody else reads it yet. `sassy-worktree` must not: its `up`/`down` pointers already carry the stack, so an overview there would re-create the seam this replaced.
