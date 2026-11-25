---
title: Quote an identity at its producer when a caller will eval it, and pass --version through before capturing any output
category: shell
tags: [bash, shell-quoting, eval, printf-q, scaffold, templates, worktree]
created: 2026-11-25
---

## Problem

The worktree toolbox hands a caller four values — `WT_PATH`, `WT_BRANCH`,
`WT_SLUG`, `WT_NAMESPACE` — as `NAME=value` lines on stdout, and the two project
templates that `sassy-setup` plants scaffolded in a project captured those lines
and `eval`'d them. Unquoted, the block was shell syntax, so the project's own
directory names became code:

- a checkout path containing a space produced `WT_PATH=/…/work`, and the
  remainder of the path ran as a command;
- a branch named with a backtick closed the assignment and executed what followed.

Two further symptoms fell out of the same capture. `create --version` printed
`13`, so a template that captured its own output before forwarding the flag
stored `13` as a path and died on `command-not-found`. And because a caller's
`case` ran after the capture, `--help` was swallowed the same way.

## Root cause

Identity was formatted in one place but *interpreted* in a second place that had
no idea the bytes were data. Hardening each consumer would have meant every
future scaffold re-deriving the same quoting — and the suite ships templates that
are written once and never rewritten, so the ones already in projects would stay
broken.

`skills/sassy-setup/assets/worktree/_lib.sh:119-126` is the single producer
(`wt_print_env`, used by both `create` and `list --env`); it emitted `printf
'WT_PATH=%s\n…'`, which is correct for a human reader and wrong for `eval`.

## Solution

Quote at the producer, so every consumer — present and future — inherits it:

```bash
# %q keeps a space in the path or a backtick in the branch from being read as
# shell syntax when a caller evaluates the block. Simple values are unchanged.
printf 'WT_PATH=%q\nWT_BRANCH=%q\nWT_SLUG=%q\nWT_NAMESPACE=%q\n' \
  "$1" "$2" "$3" "$(wt_namespace "$3")"
```

`%q` leaves an ordinary value byte-identical, so the stdout contract ("only the
four `WT_*` lines") still holds and a test that compares it to plain `NAME=value`
keeps passing.

The templates then put the flag passthrough *before* the capture, where no
output can be mistaken for identity (`skills/sassy-setup/assets/templates/worktrees-create:19-22`,
`worktrees-remove:16-19`):

```bash
case "${1:-}" in
  -h|--help|--version) exec "$ROOT/.sassywares/worktree/create" "$@" ;;
esac
```

`worktrees-remove:28-31` still distinguishes the two orders that matter: capture
first so a failed lookup aborts under `set -e` instead of `eval`ing an empty
block, then `eval`.

## Prevention

`tests/worktree-create.sh` already held the two halves that pin this down, and
both pass with `%q`:

- `:170-181` configures a `worktrees.dir` containing a space, asserts `create`
  still prints exactly four `WT_*` lines, `eval`s the block, and checks that the
  resulting `WT_PATH` keeps the space and names the real checkout.
- `:359-368` runs `--help` and `--version` through both project templates and
  asserts exit code and output match the toolbox byte for byte, so a capture
  placed before the passthrough fails loudly.

The backtick case has no dedicated fixture yet: `%q` covers it by construction,
but the coverage above would not catch a future consumer that formatted identity
by hand. The general rule for the suite is the durable part — when a value
crosses from a script that mints it into a script that `eval`s it, format it
once, at the producer, and let the consumer's only job be to `eval` the block
unchanged.
