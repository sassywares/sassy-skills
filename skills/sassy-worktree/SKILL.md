---
name: sassy-worktree
description: >-
  Run more than one agent, or more than one line of work, in the same repo: a
  worktree per branch, each with its own derived namespace, created and torn down
  safely. Use when asked for parallel work, a second checkout, or to see what a
  worktree looks like, and when a run offers one and the user accepts.
argument-hint: "[slug] [mode:create|list|remove|prune]"
---

# Sassy Worktree

**Outcome:** a checkout per branch that a run or a human can use without touching the main one — created and removed without losing work — or a table saying what exists and what is safe to delete.

**Config.** Resolve `.sassywares/config.yaml` (nearest, walking up) per the `sassy-setup` skill's `references/config.md`. `worktrees.enabled` decides whether a checkout is available at all — permission, never an instruction to take one; `dir` is read by the scripts, not by you. Precedence: explicit token > session instruction > config > skill default. Read the `sassy-setup` skill's `references/worktree.md` before the first mode: it owns the directory, refusal, and hook rules the scripts implement.

**The scripts do the git.** `.sassywares/worktree/{create,list,remove,prune}` are installed by `sassy-setup` and own the mechanics: `git worktree`, the identity, the refusals. This skill never runs `git worktree` itself and never deletes a directory.

**Harness.** Loading another skill, dispatching an agent, and any command you hand the user follow the `sassy-setup` skill's `references/harness.md`. Read it once per run, before the first of those.

## Modes

| Mode | Load | It ends with |
|---|---|---|
| `list` (default) | `references/list.md` | the table of managed checkouts, as it prints |
| `create` | `references/create.md` | a ready checkout and its hooks |
| `remove` | `references/remove.md` | a deleted checkout, a surviving branch |
| `prune` | `references/prune.md` | the removed checkouts, and why each skipped row was skipped |

Resolve the mode: an explicit `mode:` token wins. With none, it is `list` — the only mode that changes nothing; a request to add a checkout is `create`, to delete one is `remove`, and to sweep the safe ones is `prune`. Read the one reference for that mode **and only that one**.

## Hard rules — every mode

| Rule | Requirement |
|------|-------------|
| The scripts do the git | Never run `git worktree`, never delete a checkout by hand. `.sassywares/worktree/*` owns all of it. |
| Repo topology only | `git.repo: workspace` or `none` means no worktrees at all. Say so in one line and stop — never create a checkout inside a nested repo to work around it. |
| Enabled is permission | `worktrees.enabled: true` lets a run *offer* a checkout. `create` runs on the user's yes, or on a human asking outright — never because the config allowed it. |
| Ours only | A checkout is managed when it sits under `worktrees.dir` **and** carries `.sassywares/config.yaml`. Never list, prune, or remove one that is not — another tool made it, or it was cut before the wiring. `create` says so when that happens. |
| Names come from the script | `WT_NAMESPACE` is derived once. Never build a database name, a compose project, or a device name by hand. |
| Hooks are dispatched, not skipped | A declared `after_create` or `before_remove` runs, or a `down:` that names a skill. `remove` exits `3` rather than skipping it, and that is deliberate. |
| Never force on your behalf | `--force` skips the dirty and unpushed checks. Only the user's explicit instruction passes it. |
| No judgement | This skill says what exists and what is safe to delete. Whether the work is correct is a different question, and not one it answers. |
| No state of its own | The scripts keep no registry and no pid file. What exists is what `git worktree list` prints. |
| The main checkout is read-only here | Read config from it, list from it, never work in it on a run's behalf. |

## What worktree is not

Not a second clone: the checkouts share one object store and one branch lock, so two worktrees can never hold the same branch — which is the property that makes this safe and a `git clone` per agent unsafe.

Not a runner. How the stack starts and stops belongs to the project, and this skill neither owns it nor guesses at it.
