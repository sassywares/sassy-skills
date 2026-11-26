# Sassy Skills — Concepts

## Source of truth

The repo's `skills/` directory is the only copy of the skills. Consumers install from it with `npx skills add sassywares/sassy-skills` — per project, which vendors the files and pins content hashes in `skills-lock.json`, or globally with `-g`, into `~/.agents/skills/`. See README.md's Installation section.

## Consumer project

A project that installs the suite per project, so it vendors its own copy in `.agents/skills/` and pins it in `skills-lock.json`. It does not get the maintainer's `~/.agents/skills` link, so a push to this repo reaches it only through the `sassy-skills-sync` hook, which mirrors exactly the suite's roster, repins those skills, commits, and pushes to the branch recorded in `.sassywares/consumers`. Its setup is never auto-updated: the sync reports that it is out of date, and which project.

## Skill

A directory containing `SKILL.md`, discovered by a harness from a project skills directory, a user skills directory, or an installed package. Skills are explicit workflows, not always-on instructions. The model may invoke any of them, and the user can invoke one directly through their harness (the `sassy-setup` skill's `references/harness.md` lists each harness's command).

## Write boundary

The exact set of paths a skill's run may create or edit, and so the exact set its commit step may stage — stated as a hard rule in the skill's `SKILL.md` and repeated as its commit file list. It names every surface the skill owns by name, which is why deleting a config key has to reach it: a body still naming a removed file is a boundary that commits or reports something no longer real.

## Agent

A specialized subagent from [sassy-agents](https://github.com/sassywares/sassy-agents), installed per harness (`~/.pi/agent/agents/`, `~/.claude/agents/`, or a project `.pi/agents/` / `.claude/agents/`) by `sassy-setup`. Skills delegate bounded work to agents such as `scout`, `worker`, `reviewer`, `simplifier`, and `validator`.

## Orchestrator

A skill that mostly coordinates. It reads compact results, writes briefs, and avoids reading source or diffs in the main context. `sassy-work`, `sassy-lfg`, `sassy-ship`, `sassy-debug`, and `sassy-goal` are orchestrators.

## Cycle

`sassy-cycle` runs one unit of work through a tiered loop: implement → quality by change tier → one fix pass → return. A `logic` unit runs the simplifier, reviewer, and validator in parallel; a `surface` unit runs the reviewer; a `none` unit runs neither. The fix pass applies every finding once, and the cycle never re-reviews it — findings the worker leaves open are reported, and simplifications never block. Reviewer suggestions go to the gate. Given findings instead of a brief — failed QA rows, picked review findings — it applies them in one work pass. A change the user asks for at a gate is not a finding: it runs as a new cycle with that change as the work brief, so tier detection and review apply. It never commits. Work and LFG run it; debug fixes through work.

## Change tier

The depth of quality work a unit needs: declared per plan phase with `**Review:**`, passed as a `review:` token, or detected by `sassy-cycle` from the work. `logic` is core code and anything that can change runtime behavior; `surface` is everything that is not core code — docs, Markdown, comments, copy/i18n, tests, fixtures, formatting; `none` is machine-generated or mechanical churn. A declared `surface` or `none` is promoted to `logic` when the changed files include core code; never the reverse, and a worker's `Runtime behavior: yes` does not promote on its own, because tests and tooling can exercise behavior without changing it.

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
- **Gate change** — a change the user asks for while the code approval or QA gate is open is new work: a new `sassy-cycle` with that change as its work brief, at its detected tier, then the gate again. Failing QA rows alone are a one-pass rework.
- **Ship review gate** — `sassy-ship` summarizes the close-out and waits in `mode:manual` (default); skipped only when the caller passed `mode:auto`.
- **QA gate** — QA tables, part of phase completion rather than a separate track: a phase turns `Done` only when the code is approved and every QA row passed. A `Manual` row belongs to the user, and no agent ticks its own. An `Auto` row is settled by a passing dogfood report, never by an opinion, and ship will not persist behind one that is unproven. It exists only when the plan document has QA tables; an in-context brief has none.

## Branch and base

- **Base branch** — any branch the config names as a base: every `base_map` value, the `repos` rung in a workspace, and the remote default. In a repo whose `base_map` routes `"*"` to `staging`, `staging` **is** a base even though `origin/HEAD` is `main`. Comparing against `origin/HEAD` alone is the mistake that let phase work land on a shared integration branch.
- **Run branch** — the branch a run cuts before its first change when `commit.branch` is `new`. Cut once, at the start: every phase, every doc, and ship's commit land on it. A later phase, a resumed run, or `sassy-lfg` after `sassy-work` reuses it rather than cutting another.
- **Token authorship** — a token is explicit only when the caller supplied it or the run's own gate recorded it. A skill that passes its own default as a token outranks the project's config, which is the bug class `commit.branch` was lost to.

## Worktree

One checkout per branch, so two runs never share a working tree. `sassy-worktree`
owns the workflow; the scripts in `.sassywares/worktree/` own the git.

- **Worktree** — a second checkout of the same repository, at
  `~/.sassywares/worktrees/<repo>/<slug>`. It shares one object store and one
  branch lock with the main checkout, so the same branch can never be held twice
  — the property that makes it safe where a `git clone` per agent is not.
- **Permission, not a default** — `worktrees.enabled: true` means a checkout may
  be offered. A run asks before taking one and otherwise works in the main
  checkout: two runs only collide when they are actually parallel, and an unasked
  checkout relocates the work and leaves the uncommitted tree behind. A
  `worktree:on` token is the other way to say yes — the ask answered up front —
  and a managed checkout that already exists for the branch is reused rather than
  a second one cut.
- **Slug** — the branch with `/` flattened (`feat/catalog` → `feat-catalog`). It
  names the directory the checkout lives in, and the handle `list --path` and
  `remove` take — `remove` also accepts the branch.
- **Namespace** — the slug prefixed with the repo (`shop-feat-catalog`), and the
  only name a project script should use for a database, a compose project, or a
  simulator. Derived once by `create`; never rebuilt by hand.
- **Identity block** — the four `WT_*` lines `create` mints and `list --env` hands
  back: `WT_PATH`, `WT_BRANCH`, `WT_SLUG`, `WT_NAMESPACE`. The stream rule and the
  unprepared case are the `sassy-setup` skill's `references/worktree.md`'s.
- **Project scripts** — the pair `<home>/worktrees/create` and
  `<home>/worktrees/remove`, named by `worktrees.create` and `worktrees.remove`.
  They are the lifecycle; the `sassy-setup` skill's `references/worktree.md` owns
  their order, slots, and degrade rule, and `.sassywares/worktree/` ships only the
  git mechanics. Addressing a checkout — a URL, a simulator, a window — is the
  project's business too, and lives in those scripts.
- **Scaffold header** — the first line of a project-owned file setup plants,
  `# sassywares:scaffold v1 skill=<name> version=<version> date=<YYYY-MM-DD>`.
  The `sassy-setup` skill's `references/scaffold-header.md` owns its bytes and the
  offer-only upgrade rule.
- **Toolbox** — the installed `.sassywares/worktree/` set of git-mechanics
  scripts, versioned by an integer *contract* header that the project's own
  wrappers are written against. That number is not the suite release a scaffold
  header records, so the two are not comparable; a toolbox older than the shipped
  one is drift, not an upgrade, because the wrappers call flags it never had.
- **Managed checkout** — one under `worktrees.dir` that also carries
  `.sassywares/config.yaml`. The tooling lists and removes only those; anything
  else belongs to another tool or predates the wiring.
- **State** — each managed checkout's `merged`, `gone`, or `unmerged`
  classification, from the branch's upstream. The `sassy-setup` skill's
  `references/worktree.md` owns the definitions; `list` is where it prints.

`create` and `remove` need an agent because the run has to ask permission before
taking a checkout, report each refusal verbatim, and confirm a set before removing
several. The orchestration is the skill's; the git is the toolbox's.

## Overview

What a project is and how it runs, answered from its files. `sassy-overview`
owns it; its `identify.sh` is the query.

- **Identify** — the default `mode:identify`: one `key<TAB>value<TAB>source` line
  per fact, read-only and never executing the project's tooling. The keys are
  `stack`, `runner`, `install`, `up`, `down`, `test`, `compose`, `env`, `wired`.
- **Source** — the file a value came from, or `-` when there is none. A value
  without a source is not a fact, which is why `unknown` carries `-`.
- **Unknown** — a first-class answer: the project has not declared this fact.
  It is never a gap to fill with a default or a manifest written to hold one.
- **Answered vs. asked** — the default run is an inventory and exits `0`; naming
  keys makes it a question, and any requested `unknown` exits `3` so the caller
  branches instead of guessing. Usage errors exit `2`.

## Modes

Three shared mode tokens: `mode:manual` (default) asks at the skill's gate; `mode:auto` means pre-authorized, no review; `mode:return` reports and changes nothing. Some skills take their own modes instead: `sassy-goal`, `sassy-handoff` (`write`, `read`), `sassy-setup` (`init`, `check`), `sassy-overview` (`identify`), `sassy-worktree` (`list`, `create`, `remove`), and `sassy-skill` (`create`, `retune`, `verify`).

- `sassy-ship` and `sassy-compound` accept `manual` and `auto`. Ship reviews the whole close-out in `mode:manual` and forwards `mode:auto` to compound once its own gate is answered.
- `sassy-review`, `sassy-simplify`, and `sassy-validate` accept all three: `manual` asks which findings to fix, `auto` fixes them without asking, `return` hands the findings back to the caller.
- `sassy-debug` accepts no mode. It always leaves ship's review gate in place.
- `sassy-work` and `sassy-lfg` accept no mode.
- `sassy-goal` takes its own modes, one per step of a goal: `mode:write` (default), `mode:next`, `mode:check`, and `mode:close`.

Everything else is decided by the artifact, not a mode:

- A plan document under `docs/plans/` — `<type>-<slug>.md`, with YAML frontmatter for `type`, `created`, `updated` (plus `qa: off` when the user asks for no QA gates) — drives phased execution and carries QA tables whose rows are `Auto` or `Manual`.
- An in-context brief drives one cycle and has no plan file and no QA tables.

## Plan

A durable document under `docs/plans/<type>-<slug>.md` with frontmatter, intent, decisions, constraints, phase tracking, and per-phase QA tables.

## Goal

Work too big for one plan — a migration, an epic — run by `sassy-goal` as a folder under `artifacts.plans`, `<type>-<slug>/`: `goal.md` (intent, cross-slice decisions, landscape, coexistence, a slice table, carry-forward) plus one plan per started slice. It turns `done` when `mode:close` verifies its done-when against the whole tree.

## Slice

One step of a goal: its own plan (`NN-<slug>.md`, written only when `mode:next` starts it), branch, and PR, and it must ship something complete on its own — never a half-built layer. One slice is in flight at a time: `Pending` > `Planned` > `Shipped` > `Done`.

## Carry-forward

The append-only section of `goal.md` that `mode:check` adds to once per slice: what changed versus the plan, new decisions, impact on later slices, and gaps deferred or accepted. Every later slice's grill reads it as settled.

## Goal hook

A project skill run at a goal's boundaries, declared under `hooks.goal` and keyed by the goal's folder name under `artifacts.plans`, `<type>-<slug>` (prefix included). `before_slice` runs in `mode:next` after the previous slice's merge is confirmed and before the next slice is grilled; `after_close` runs in `mode:close` after the status is persisted, on `done` and on a goal left `active`. Neither may touch the goal itself (`goal.md`, the slice plan, the status); anything else — switching to the bases, pulling, rebasing, committing, pushing, migrating — is the project's call, provided every base ends level with its remote. `before_slice` fires before `mode:next` checks the base, so it can be what freshens it. Entries are idempotent, and both fail closed. They are not PR-keyed, so `commit.branch: current` does not suppress them, and since `sassy-goal` has no approval gate the mode's report names what ran, that none are declared, or where it stopped.

## Brief

A settled in-context brief produced by `sassy-plan` when the user picks "start working" (`sassy-work`) or "implement and ship" (`sassy-lfg`). It carries the goal, decisions, constraints, work, and done-when, but no plan file and no QA tables.

## Handoff

`sassy-handoff` in `mode:write` writes a self-contained handoff file under `/tmp/sassywares/handoffs/` and gives the user a `sassy-handoff mode:read <path>` command; `mode:read` in the fresh session summarizes what was done, why, and the current state against the tree, then asks what to do next. A skill cannot start a session, so the user opens the fresh one; the file is the only bridge, in any harness. Reaching for it is the user's call alone: no skill in the plan → work → ship pipeline writes, offers, or suggests one, and a run ends at its own report.

## Release

There is no background watcher. Releases go through `sassy-ship` under `commit.branch: current`: after the approved push, the `hooks.push` `after_push` hook runs the `sassy-skills-release` project skill, which runs the vendored `bin/release` script. It bumps the patch version and tags when consumer-facing files changed, and the tag publishes to npm. It installs nothing: `npx skills add` reads this repo directly. AGENTS.md has the details.
