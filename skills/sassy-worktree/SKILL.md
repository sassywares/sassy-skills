---
name: sassy-worktree
description: >-
  Run more than one agent, or more than one line of work, in the same repo: a
  worktree per branch, each with its own derived namespace, created and torn down
  safely. Use when asked for parallel work, a second checkout, or to see what a
  worktree looks like, and when a run offers one and the user accepts.
argument-hint: "[slug] [mode:list|create|remove]"
---

# Sassy Worktree

**Outcome:** a checkout per branch that a run or a human can use without touching the main one — created and removed without losing work — or a table saying what exists and what is safe to delete.

**Config.** Resolve `.sassywares/config.yaml` (nearest, walking up) per the `sassy-setup` skill's `references/config.md`. `worktrees.enabled` decides whether a checkout is available at all — permission, never an instruction to take one; `worktrees.dir` is read by the scripts, not by you; `worktrees.create` and `worktrees.remove` name the project's own prepare and teardown scripts. Precedence: explicit token > session instruction > config > skill default. Read the `sassy-setup` skill's `references/worktree.md` before the first mode: it owns the directory, the streams, the refusal, and the script-order rules the scripts implement, and its `references/config.md` Lifecycle owns the two keys' shape and degrade.

**Harness.** Loading another skill, dispatching an agent, and any command you hand the user follow the `sassy-setup` skill's `references/harness.md`. Read it once per run, before the first of those.

## Modes

| Mode | Load | It ends with |
|---|---|---|
| `list` (default) | `references/list.md` | the table of managed checkouts, as it prints, with each row's state |
| `create` | `references/create.md` | a ready checkout and its identity, or one reported as real but unprepared |
| `remove` | `references/remove.md` | a deleted checkout, a surviving branch |

Resolve the mode: an explicit `mode:` token wins. With none, it is `list` — the only mode that changes nothing; a request to add a checkout is `create`, to delete one is `remove`. Read the one reference for that mode **and only that one**.

## Hard rules — every mode

| Rule | Requirement |
|------|-------------|
| The project's scripts are the entry point | A create or remove step runs `<worktrees.create>` / `<worktrees.remove>` as `detect.sh --worktree-script` resolves them, never the toolbox directly. The resolver's degrade rule is `references/worktree.md`'s; the keys are `references/config.md`'s Lifecycle. |
| The scripts do the git | Never run `git worktree`, never delete a checkout by hand. `.sassywares/worktree/*` owns all of it. |
| Repo topology only | `git.repo: workspace` or `none` means no worktrees at all. Say so in one line and stop — never create a checkout inside a nested repo to work around it. |
| Enabled is permission | `worktrees.enabled: true` lets a run *offer* a checkout. `create` runs on the user's yes, or on a human asking outright — never because the config allowed it. |
| Ours only | A checkout is managed when it sits under `worktrees.dir` **and** carries `.sassywares/config.yaml`. Never list or remove one that is not — another tool made it, or it was cut before the wiring. `create` says so when that happens. |
| Names come from the script | `WT_NAMESPACE` is derived once. Never build a database name, a compose project, or a device name by hand. |
| The identity is the contract | A create must exit `0` **and** print the four `WT_*` lines. Anything else is reported as "checkout is real but unprepared", never filled in from a guess. |
| Never force on your behalf | `--force` skips the dirty and unpushed checks. Only the user's explicit instruction passes it. |
| No judgement | This skill says what exists and what is safe to delete. Whether the work is correct is a different question, and not one it answers. |
| The main checkout is read-only here | Read config from it, list from it, never work in it on a run's behalf. |

## What worktree is not

Not a second clone: the checkouts share one object store and one branch lock, so two worktrees can never hold the same branch — which is the property that makes this safe and a `git clone` per agent unsafe.

Not a runner. How the stack starts and stops belongs in the project's `create` and `remove` scripts, and this skill neither owns it nor guesses at it.
