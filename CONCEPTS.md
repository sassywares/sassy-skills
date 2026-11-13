# Sassy Skills — Concepts

## Source of truth

The repo's `skills/` directory is the only copy of the skills. Consumers install from it with `npx skills add sassywares/sassy-skills` — per project, which vendors the files and pins content hashes in `skills-lock.json`, or globally with `-g`, into `~/.agents/skills/`. See README.md's Installation section.

## Skill

A directory containing `SKILL.md`, discovered by a harness from a project skills directory, a user skills directory, or an installed package. Skills are explicit workflows, not always-on instructions. The model may invoke any of them, and the user can invoke one directly through their harness (the `sassy-setup` skill's `references/harness.md` lists each harness's command).

## Agent

A specialized subagent from [sassy-agents](https://github.com/sassywares/sassy-agents), installed per harness (`~/.pi/agent/agents/`, `~/.claude/agents/`, or a project `.pi/agents/` / `.claude/agents/`) by `sassy-setup`. Skills delegate bounded work to agents such as `scout`, `worker`, `reviewer`, `simplifier`, and `validator`.

## Orchestrator

A skill that mostly coordinates. It reads compact results, writes briefs, and avoids reading source or diffs in the main context. `sassy-work`, `sassy-lfg`, `sassy-ship`, `sassy-debug`, and `sassy-goal` are orchestrators.

## Cycle

`sassy-cycle` runs one unit of work through implement → review + simplify + validate (in parallel) → fix → verify. Simplifications are applied and verified but never block. Verify is a reviewer scoped to the fix, confirming each finding resolved and checking the fix for new ones; at most two fix passes, then anything open is `blocked`. Reviewer suggestions never block; they go to the gate. Given findings instead of a brief — requested changes, failed QA rows — it reworks existing work through the same fix → verify loop. It never commits. Work and LFG run it; debug fixes through work.

## Dogfood

Agent QA: the project's own stored procedure for proving a change works in the running product, not merely in the diff. `sassy-dogfood` executes it, and the report's verdict is the only thing that settles an `Auto` QA row.

- **Recipe** — `.sassywares/dogfood/recipe.md`, committed and reviewed like code. Append-only sections of ordered steps, each with a `Do` and an `Expect`, ending in one `Prove it:` step whose exit code is the verdict. It names no tool: whatever the harness has connected at run time is what satisfies a step. The config points at it and never restates it — commands in the config would duplicate the manifest and could not express order.
- **Report** — `.sassywares/dogfood/reports/<run-id>/`, never committed and pruned to ten: `summary.md` (status, class, the per-step table, artifact paths), one log per executed step, and the artifacts. The durable record is the QA row's note — verdict and run id — never a path that will vanish.
- **Verdict classes** — `code` is a finding for the cycle, `env` means the toolchain is broken (report and park, never loop), `recipe` means the procedure itself is stale (propose a diff, never improvise around it).
- **Two gates** — an `Auto` row needs `dogfood.enabled: true` **and** a section with a `Prove it:` step. One without the other keeps the row `Manual`, which is how an unfinished recipe degrades safely instead of making a gate lie.
- **Frozen against the run** — a red run never edits the recipe or its expectations to pass. The cheapest way past a check must not be to weaken it.

## Gates

A gate is a deliberate stop or pass/fail condition.

- **Fix gate** — `sassy-debug` presents the causal chain, fix, and risks before changing code.
- **Code approval gate** — the user approves the code before committing or shipping. Always on for `sassy-work` and `sassy-lfg`.
- **Ship review gate** — `sassy-ship` summarizes the close-out and waits in `mode:manual` (default); skipped only when the caller passed `mode:auto`.
- **QA gate** — QA tables, part of phase completion rather than a separate track: a phase turns `Done` only when the code is approved and every QA row passed. A `Manual` row belongs to the user, and no agent ticks its own. An `Auto` row is settled by a passing dogfood report, never by an opinion, and ship will not persist behind one that is unproven. It exists only when the plan document has QA tables; an in-context brief has none.

## Branch and base

- **Base branch** — any branch the config names as a base: every `base_map` value, the `repos` rung in a workspace, and the remote default. In a repo whose `base_map` routes `"*"` to `staging`, `staging` **is** a base even though `origin/HEAD` is `main`. Comparing against `origin/HEAD` alone is the mistake that let phase work land on a shared integration branch.
- **Run branch** — the branch a run cuts before its first change when `commit.branch` is `new`. Cut once, at the start: every phase, every doc, and ship's commit land on it. A later phase, a resumed run, or `sassy-lfg` after `sassy-work` reuses it rather than cutting another.
- **Token authorship** — a token is explicit only when the caller supplied it or the run's own gate recorded it. A skill that passes its own default as a token outranks the project's config, which is the bug class `commit.branch` was lost to.

## Worktree

One checkout per branch, so two runs never share a working tree. `sassy-worktree`
owns the lifecycle; the scripts in `.sassywares/worktree/` own the git.

- **Worktree** — a second checkout of the same repository, at
  `~/.sassywares/worktrees/<repo>/<slug>`. It shares one object store and one
  branch lock with the main checkout, so the same branch can never be held twice
  — the property that makes it safe where a `git clone` per agent is not.
- **Slug** — the branch with `/` flattened (`feat/catalog` → `feat-catalog`). It
  names the directory, the port, and the registry entry.
- **Namespace** — the slug prefixed with the repo (`shop-feat-catalog`), and the
  only name a hook should use for a database, a compose project, or a simulator.
  Derived once by `create`; never rebuilt by hand.
- **Port claim** — the private port a checkout owns: hashed from the slug into the
  configured range, claimed with an atomic `mkdir`, and probed forward on a
  collision. Liveness is *probed*, never read from a pid file.
- **Preview** — bringing that checkout up so a human can look at it. It runs the
  dogfood recipe's steps up to the section's `Prove it:` and never judges the
  work; proving is dogfood's job.

`create` and `remove` need an agent because their hooks are project skills, and a
script cannot dispatch one. That is why the lifecycle is a skill and the git is a
script.

## Modes

Three shared mode tokens: `mode:manual` (default) asks at the skill's gate; `mode:auto` means pre-authorized, no review; `mode:return` reports and changes nothing. Some skills take their own modes instead: `sassy-goal`, `sassy-handoff` (`write`, `read`), `sassy-setup` (`init`, `check`), and `sassy-skill` (`create`, `retune`, `verify`).

- `sassy-ship` and `sassy-compound` accept `manual` and `auto`. Ship reviews the whole close-out in `mode:manual` and forwards `mode:auto` to compound once its own gate is answered.
- `sassy-review`, `sassy-simplify`, and `sassy-validate` accept all three: `manual` asks which findings to fix, `auto` fixes them without asking, `return` hands the findings back to the caller.
- `sassy-debug` accepts no mode. It always leaves ship's review gate in place.
- `sassy-work` and `sassy-lfg` accept no mode.
- `sassy-goal` takes its own modes, one per step of a goal: `mode:write` (default), `mode:next`, `mode:check`, and `mode:close`.

Everything else is decided by the artifact, not a mode:

- A plan document under `docs/plans/` drives phased execution and carries QA tables whose rows are `Auto` or `Manual`.
- An in-context brief drives one cycle and has no plan file and no QA tables.

## Plan

A durable document under `docs/plans/` with intent, decisions, constraints, phase tracking, and per-phase QA tables.

## Goal

Work too big for one plan — a migration, an epic — run by `sassy-goal` as a folder under `artifacts.plans`: `goal.md` (intent, cross-slice decisions, landscape, coexistence, a slice table, carry-forward) plus one plan per started slice. It turns `Done` when `mode:close` verifies its done-when against the whole tree.

## Slice

One step of a goal: its own plan (`NN-<slug>.md`, written only when `mode:next` starts it), branch, and PR, and it must ship something complete on its own — never a half-built layer. One slice is in flight at a time: `Pending` > `Planned` > `Shipped` > `Done`.

## Carry-forward

The append-only section of `goal.md` that `mode:check` adds to once per slice: what changed versus the plan, new decisions, impact on later slices, and gaps deferred or accepted. Every later slice's grill reads it as settled.

## Brief

A settled in-context brief produced by `sassy-plan` when the user picks "start working" (`sassy-work`) or "implement and ship" (`sassy-lfg`). It carries the goal, decisions, constraints, work, and done-when, but no plan file and no QA tables.

## Handoff

`sassy-handoff` in `mode:write` writes a self-contained handoff file under `/tmp/sassywares/handoffs/` and gives the user a `sassy-handoff mode:read <path>` command; `mode:read` in the fresh session summarizes what was done, why, and the current state against the tree, then asks what to do next. A skill cannot start a session, so the user opens the fresh one; the file is the only bridge, in any harness.

## Release

There is no background watcher. Releases go through `sassy-ship` under `commit.branch: current`: after the approved push, the `hooks.push` `after_push` hook runs the `sassy-skills-release` project skill, which runs the vendored `bin/release` script. It bumps the patch version and tags when consumer-facing files changed, and the tag publishes to npm. It installs nothing: `npx skills add` reads this repo directly. AGENTS.md has the details.
