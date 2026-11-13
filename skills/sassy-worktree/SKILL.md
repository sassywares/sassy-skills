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

**Config.** Resolve `.sassywares/config.yaml` (nearest, walking up) per the `sassy-setup` skill's `references/config.md`. `worktrees.enabled` decides whether any of this runs; `dir` and `ports` are read by the scripts, not by you. Precedence: explicit token > session instruction > config > skill default. Read `references/worktree.md` in the `sassy-setup` skill before the first mode.

**The scripts do the git.** `.sassywares/worktree/{create,list,stop,remove,prune}` are installed by `sassy-setup` and own the mechanics: `git worktree`, the port claim, the refusals. This skill never runs `git worktree` itself, never invents a port, and never deletes a directory.

**Harness.** Loading another skill, dispatching an agent, and any command you hand the user follow the `sassy-setup` skill's `references/harness.md`. Read it once per run, before the first of those.

## Modes

| Mode | What it does |
|------|--------------|
| `list` (default) | The table: branch, worktree, address, liveness, last dogfood verdict |
| `create` | Add a worktree for the run's branch, claim its port, dispatch `after_create` |
| `preview` | Bring that checkout up and print how to see it; leave it running. `stop` reaps it |
| `remove` | Dispatch `before_remove`, then delete after the script's refusals pass |
| `prune` | Show merged-or-gone worktrees that are safe to delete, then remove what you approve |

`list` is the default because it is the only mode that changes nothing.

## `create`

1. **Resolve the branch and its start point first**, through the `sassy-setup` skill's `references/branching.md`, exactly as `sassy-work` does. A run that reaches here has already decided; the branch is not created twice. When a human asks for one by hand with no branch named, ask for the branch name — never derive one.
2. **Run `.sassywares/worktree/create <branch> --from <start-point>`** with the resolved start point. It is idempotent: an existing worktree for that branch is reported, a branch held by the main checkout is refused, and a port is claimed either way. On `--env` it prints the `WT_*` block alone.
3. **Dispatch the declared hooks.** The script prints one line per `hooks.worktree.after_create` entry; it cannot dispatch a skill, so you do. One `worker` each, in declared order: *load the project skill at `.agents/skills/<name>/SKILL.md` and follow it*, briefed with the `WT_*` block and the fact that the checkout now exists. A missing skill or a `blocked` result stops here — the checkout is real but unprepared, and saying so is the report.
4. **Report** the path, branch, namespace, port, address, and the hooks that ran or that none are declared. If the caller is a run, tell it to work in `WT_PATH` from now on.

## `list`

Run `.sassywares/worktree/list` and present it as it prints — branch, worktree, address, live, last verdict. `--address <slug>` and `--path <slug>` print one value for scripting. Never summarise the table away: the address is the point.

## `preview`

1. **Resolve the target and the section.** `preview <slug>` uses that checkout; with none, ask which. `section:<name>` names a dogfood recipe section; with none, use the first.
2. **Read the recipe** at `dogfood.recipe`. Two things stop the run, and both are reported rather than worked around: no recipe (the project has no stored procedure — say to run `sassy-dogfood mode:discover`), or the section has no `Prove it:` step (nothing marks where bringing-up ends).
3. **Preflight the session.** If the recipe's *Working in a second checkout* or *Set up once* names a session artifact and `.sassywares/session/` in **that checkout** is empty, that is `class: env`: report it with the line that fixes it and stop. Never open a logged-out app and call it a preview — the human will read the login screen as a broken build.
4. **Run the bring-up.** In `WT_PATH`: the recipe's *Set up once* when the checkout is cold (no `.env`, no installed deps), then the section's steps in order **up to but not including** its `Prove it:` step. Judge each step by its `Expect`. A failure stops the preview and is reported with the step id and its output tail — a preview that half-started is not a preview.
5. **Leave it running and report how to see it.** Print the address from `list --address`, plus the recipe's `**Preview:**` line when it has one (a simulator name, a desktop app, a URL). Verify it answers before you call it up: the address is a promise.
6. **To stop it,** run `.sassywares/worktree/stop <slug>` — by port, never by a recorded pid.

Preview never judges the work, never writes a report, never commits, and never returns a verdict. If the user wants to know whether it *works*, that is `sassy-dogfood mode:run`.

## `remove`

1. **Dispatch `before_remove` first**, one `worker` per declared entry, briefed with the `WT_*` block and that the checkout is about to go. Its job is the project's cleanup: drop the derived database, shut the simulator.
2. **Run `.sassywares/worktree/remove <slug> --hook-ok`.** Without `--hook-ok` it exits `3` by design when a hook is declared — that exit is the handshake, not an error to route around.
3. **Report a refusal verbatim and stop.** Dirty tree, unpushed commits, a live preview, the main checkout: each is a real reason, and `--force` is the user's call, never yours. On success report the released port and the removed path.

## `prune`

1. Run `.sassywares/worktree/prune` with no flag and show the table.
2. Ask before removing. `--yes` removes only rows marked `removable`: merged into their upstream or whose upstream is gone, clean, fully pushed, not running, and no `before_remove` hook it would skip. Rows with a hook are reported so the user can run `remove <slug>` instead and get the cleanup.
3. Report the counts — removed, left, and why each skipped row was skipped.

## Hard rules

| Rule | Requirement |
|------|-------------|
| The scripts do the git | Never run `git worktree`, never invent a port, never `rm -rf` a checkout. `.sassywares/worktree/*` owns all of it. |
| One worktree per run | The branch decision belongs to `references/branching.md`. Never create a second worktree for a run already on its branch. |
| Names come from the script | `WT_NAMESPACE` and `WT_PORT` are derived once. Never build a database name, a compose project, or a device name by hand. |
| Hooks are dispatched, not skipped | A declared `after_create` or `before_remove` runs. `remove` exits `3` rather than skipping it, and that is deliberate. |
| Never force on your behalf | `--force` skips the dirty and unpushed checks. Only the user's explicit instruction passes it. |
| Preview is a promise | Report an address only when something answers on it. A half-started app is a failure with a step id, not a preview. |
| No verdicts | This skill never says whether the work is correct. That is `sassy-dogfood`'s job, with a report. |
| No state of its own | Liveness is probed at read time. There is no registry, no pid file, and nothing to go stale. |
| Never production | A preview serves the local or staging app. A recipe step pointing at production is refused and reported. |
| The main checkout is read-only here | Read config from it, list from it, never work in it on a run's behalf. |

## What worktree is not

Not a second clone: the checkouts share one object store and one branch lock, so two worktrees can never hold the same branch — which is the property that makes this safe and a `git clone` per agent unsafe.

Not a dogfooding skill. It brings a product up so a human can look; `sassy-dogfood` proves a change works and returns a verdict. When the two meet, they meet at the recipe.
