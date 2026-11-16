---
name: sassy-worktree
description: >-
  Run more than one agent, or more than one line of work, in the same repo: a
  worktree per branch, each with its own derived namespace and port, created and
  torn down safely. `mode:preview` brings a checkout up so you can look at it
  without setting it up by hand. Use when asked for parallel work, a second
  checkout, or to see what a worktree looks like.
argument-hint: "[slug] [mode:create|list|preview|remove|prune] [section:<name>]"
---

# Sassy Worktree

**Outcome:** a checkout per branch that a run or a human can use without touching the main one — created, addressed, previewed, and removed without losing work — or a table saying what exists and what is safe to delete.

**Config.** Resolve `.sassywares/config.yaml` (nearest, walking up) per the `sassy-setup` skill's `references/config.md`. `worktrees.enabled` decides whether any of this runs; `dir` and `ports` are read by the scripts, not by you. Precedence: explicit token > session instruction > config > skill default. Read the `sassy-setup` skill's `references/worktree.md` before the first mode: it owns the directory, port, refusal, and hook rules the scripts implement.

**The scripts do the git.** `.sassywares/worktree/{create,list,stop,remove,prune}` are installed by `sassy-setup` and own the mechanics: `git worktree`, the port claim, the refusals. This skill never runs `git worktree` itself, never invents a port, and never deletes a directory.

**Harness.** Loading another skill, dispatching an agent, and any command you hand the user follow the `sassy-setup` skill's `references/harness.md`. Read it once per run, before the first of those.

## Modes

| Mode | Load | It ends with |
|---|---|---|
| `list` (default) | `references/list.md` | the table of managed checkouts, as it prints |
| `create` | `references/create.md` | a ready checkout, its address, and its hooks |
| `preview` | `references/preview.md` | a checkout left running, and how to see it |
| `remove` | `references/remove.md` | a deleted checkout, a released port, a surviving branch |
| `prune` | `references/prune.md` | the removed checkouts, and why each skipped row was skipped |

Resolve the mode: an explicit `mode:` token wins. With none, it is `list` — the only mode that changes nothing; a request to add a checkout is `create`, to bring one up is `preview`, to delete one is `remove`, and to sweep the safe ones is `prune`. Read the one reference for that mode **and only that one**.

## Hard rules — every mode

| Rule | Requirement |
|------|-------------|
| The scripts do the git | Never run `git worktree`, never invent a port, never `rm -rf` a checkout. `.sassywares/worktree/*` owns all of it. |
| Repo topology only | `git.repo: workspace` or `none` means no worktrees at all. Say so in one line and stop — never create a checkout inside a nested repo to work around it. |
| Ours only | A checkout is managed when it sits under `worktrees.dir` **and** carries `.sassywares/config.yaml`. Never list, prune, stop, or remove one that is not — another tool made it, or it was cut before the wiring. `create` says so when that happens. |
| Names come from the script | `WT_NAMESPACE` is derived once, and `WT_PORT` only when the project configured a range. Never build a database name, a compose project, or a device name by hand. |
| Hooks are dispatched, not skipped | A declared `after_create` or `before_remove` runs. `remove` exits `3` rather than skipping it, and that is deliberate. |
| Never force on your behalf | `--force` skips the dirty and unpushed checks. Only the user's explicit instruction passes it. |
| No verdicts | This skill never says whether the work is correct. That is `sassy-dogfood`'s job, with a report. |
| No state of its own | Liveness is probed at read time. There is no registry, no pid file, and nothing to go stale. |
| Never production | A preview serves the local or staging app. A recipe step pointing at production is refused and reported. |
| The main checkout is read-only here | Read config from it, list from it, never work in it on a run's behalf. |

## What worktree is not

Not a second clone: the checkouts share one object store and one branch lock, so two worktrees can never hold the same branch — which is the property that makes this safe and a `git clone` per agent unsafe.

Not a dogfooding skill. It brings a product up so a human can look; `sassy-dogfood` proves a change works and returns a verdict. When the two meet, they meet at the recipe.
