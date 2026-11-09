---
name: sassy-goal
description: >-
  Run a large project or major feature that one plan cannot hold — a migration,
  an epic, a milestone, a whole-app rewrite — as a goal split into slices, each
  of which plans, ships, and is checked on its own. mode:write (default)
  grills and writes or revises the goal; mode:next plans the next slice via
  sassy-plan; mode:check validates a shipped slice and records carry-forward;
  mode:close verifies the whole goal before the last PR merges. Use when work
  is too big for one plan, spans several PRs, or the user says goal, epic,
  milestone, or migration.
argument-hint: "<idea | goal path> [mode:write|next|check|close] [slice:<ID>]"
---

# Sassy Goal

**Outcome:** a goal folder whose `goal.md` holds the intent, the cross-slice decisions, and a slice table — then, one slice at a time, a slice plan written when that slice starts, shipped through the usual `sassy-work` / `sassy-lfg` → `sassy-ship` path, checked against its plan, and carried forward; finally the whole goal verified and marked `Done`.

**One slice ships at a time, and every slice ships something complete.** A slice is its own plan → work or lfg → ship. It never leaves a half-built layer behind for a later slice to finish.

**The user drives every step.** Each mode ends by printing the next command; nothing chains on its own. This skill never implements: code changes belong to `sassy-work`, `sassy-lfg`, and `sassy-cycle`.

**Config.** Resolve `.sassywares/config.yaml` (nearest, walking up) per the `sassy-setup` skill's `references/config.md`. Precedence: explicit token > session instruction > config > skill default. Goals live under `artifacts.plans`; `git.repo` and `commit.branch` decide how check and close persist.

**Harness.** Loading another skill, dispatching an agent, and any command you hand the user follow the `sassy-setup` skill's `references/harness.md`. Read it once per run, before the first of those.

## The goal

A goal is the folder `<artifacts.plans>/<goal-slug>/`: `goal.md` plus one plan per started slice, named `NN-<slice-slug>.md` where `NN` matches the slice ID (`S1` → `01-`). Slice plans are ordinary sassy plans. `references/goal-format.md` owns the `goal.md` format, the slice statuses, and the template — read it before writing or revising `goal.md`.

Slice statuses run `Pending` > `Planned` > `Shipped` > `Done`, plus `Blocked`. `mode:next` sets `Planned`, `sassy-ship` sets `Shipped` (and babysits the slice PR without merging), `mode:check` sets `Done` and records the PR link.

## Modes

| Mode | Load | Runs | It ends with |
|---|---|---|---|
| `write` (default) | `references/write.md` | anytime | a new or revised `goal.md`, and the `mode:next` command |
| `next` | `references/next.md` | on the base, previous slice merged | the slice's plan written, the slice `Planned`, and the work / lfg commands |
| `check` | `references/check.md` | on the slice branch after ship, before merge | the slice `Done`, carry-forward appended, pushed with the slice |
| `close` | `references/close.md` | on the last slice's branch after its check, before merge | `**Status:** Done` (or `Active` with a slice to add), pushed with the last slice |

Resolve the mode: an explicit `mode:` token wins. With none, it is `write` — an idea creates a goal, a path to an existing goal folder or `goal.md` revises it. Read the one reference for that mode **and only that one**.

```text
write → next → work/lfg → ship → check → next → … → ship → check → close
```

## Persisting

`check` and `close` commit on the slice branch so `goal.md` merges with the slice. Persist exactly like `sassy-ship` steps 4–5, per `git.repo`:

- **A remote** — dispatch a `worker`: *load the `sassy-commit-push-pr` skill and follow it with `branch:current` and `babysit:off`*, which commits, pushes, and updates the slice's open PR. Under `commit.branch: current` there is no PR: the worker loads `sassy-commit` with `branch:current`, then pushes the head to its upstream — never forced; a non-fast-forward rejection is a stop-and-report.
- **`workspace`** — commit each affected repo on the run's shared branch, run `.sassywares/workspace/snapshot` for `goal.md` and the docs at the root, then push each repo. A missing or outdated snapshot script is a blocker: say to run `sassy-setup`.
- **`none`** — nothing persists. Report that `goal.md` and any fixes are uncommitted, and stop.

## Hard rules

| Rule | Requirement |
|------|-------------|
| Writing never implements | `mode:write` and `mode:next` produce documents only. Fixes in check and close go through `sassy-cycle`. |
| Complete slices | Push back on any slice that does not ship a working outcome on its own; re-cut it before the goal is written. |
| One slice in flight | Never plan a slice while another is `Planned` or `Shipped`. No parallel slices. |
| Plan at slice start | A slice's plan is grilled and written only when `mode:next` starts it — never upfront. |
| Settled stays settled | The goal's decisions and every carry-forward entry reach each slice grill as settled; they are never re-asked. |
| Carry-forward is append-only | One entry per checked slice; never edit or remove an earlier one. |
| Done is history | A revision never re-cuts, renumbers, or rewrites a `Done` slice or its plan. |
| No unchosen gaps | A slice or the goal turns `Done` only when every gap is fixed, deferred to a named slice, or accepted with a recorded reason. |
| Never default | Never push to a base branch outside `commit.branch: current`; never force-push. |

## Non-goals

No auto-chaining between slices or modes, no parallel slices, no auto mode (a future follow-up), and no dependency on any framework outside this suite.
