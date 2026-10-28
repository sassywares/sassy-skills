# Sassy Skills — Concepts

## Source of truth

The repo's `skills/` directory is the only copy of the skills. Consumers install from it with `npx skills add sassywares/sassy-skills` — per project, which vendors the files and pins content hashes in `skills-lock.json`, or globally with `-g`, into `~/.agents/skills/`. See README.md's Installation section.

## Skill

A directory containing `SKILL.md`, discovered by a harness from a project skills directory, a user skills directory, or an installed package. Skills are explicit workflows, not always-on instructions. The model may invoke any of them; the user can also invoke one directly with `/skill:<name>`.

## Agent

A specialized subagent from [sassy-agents](https://github.com/sassywares/sassy-agents), installed per harness (`~/.pi/agent/agents/`, `~/.claude/agents/`, or a project `.pi/agents/` / `.claude/agents/`) by `sassy-setup`. Skills delegate bounded work to agents such as `scout`, `worker`, `reviewer`, `simplifier`, and `validator`.

## Orchestrator

A skill that mostly coordinates. It reads compact results, writes briefs, and avoids reading source or diffs in the main context. `sassy-work`, `sassy-lfg`, `sassy-ship`, and `sassy-debug` are orchestrators.

## Cycle

`sassy-cycle` runs one unit of work through implement → review + simplify + validate (in parallel) → fix → verify. Simplifications are applied and verified but never block. Verify is a reviewer scoped to the fix, confirming each finding resolved and checking the fix for new ones; at most two fix passes, then anything open is `blocked`. Reviewer suggestions never block; they go to the gate. Given findings instead of a brief — requested changes, failed QA rows — it reworks existing work through the same fix → verify loop. It never commits. Work and LFG run it; debug fixes through work.

## Gates

A gate is a deliberate stop or pass/fail condition.

- **Fix gate** — `sassy-debug` presents the causal chain, fix, and risks before changing code.
- **Code approval gate** — the user approves the code before committing or shipping. Always on for `sassy-work` and `sassy-lfg`.
- **Ship review gate** — `sassy-ship` summarizes the close-out and waits in `mode:manual` (default); skipped only when the caller passed `mode:auto`.
- **QA gate** — manual QA checklists, part of phase completion rather than a separate track: a phase turns `Done` only when the code is approved and every QA row passed. The user runs the rows; no agent ticks its own. It exists only when the plan document has QA tables; an in-context brief has none.

## Branch and base

- **Base branch** — any branch the config names as a base: every `base_map` value, the `repos` rung in a workspace, and the remote default. In a repo whose `base_map` routes `"*"` to `staging`, `staging` **is** a base even though `origin/HEAD` is `main`. Comparing against `origin/HEAD` alone is the mistake that let phase work land on a shared integration branch.
- **Run branch** — the branch a run cuts before its first change when `commit.branch` is `new`. Cut once, at the start: every phase, every doc, and ship's commit land on it. A later phase, a resumed run, or `sassy-lfg` after `sassy-work` reuses it rather than cutting another.
- **Token authorship** — a token is explicit only when the caller supplied it or the run's own gate recorded it. A skill that passes its own default as a token outranks the project's config, which is the bug class `commit.branch` was lost to.

## Modes

Three mode tokens: `mode:manual` (default) asks at the skill's gate; `mode:auto` means pre-authorized, no review; `mode:return` reports and changes nothing.

- `sassy-ship` and `sassy-compound` accept `manual` and `auto`. Ship reviews the whole close-out in `mode:manual` and forwards `mode:auto` to compound once its own gate is answered.
- `sassy-review`, `sassy-simplify`, and `sassy-validate` accept all three: `manual` asks which findings to fix, `auto` fixes them without asking, `return` hands the findings back to the caller.
- `sassy-debug` accepts no mode. It always leaves ship's review gate in place.
- `sassy-work` and `sassy-lfg` accept no mode.

Everything else is decided by the artifact, not a mode:

- A plan document under `docs/plans/` drives phased execution and carries manual QA tables.
- An in-context brief drives one cycle and has no plan file and no QA tables.

## Plan

A durable document under `docs/plans/` with intent, decisions, constraints, phase tracking, and per-phase manual QA tables.

## Brief

A settled in-context brief produced by `sassy-plan` when the user picks "start working" (`sassy-work`) or "implement and ship" (`sassy-lfg`). It carries the goal, decisions, constraints, work, and done-when, but no plan file and no QA tables.

## Handoff

`sassy-handoff` in `mode:write` writes a self-contained handoff file under `/tmp/sassywares/<harness>/handoffs/` and gives the user a `sassy-handoff mode:read <path>` command; `mode:read` in the fresh session summarizes what was done, why, and the current state against the tree, then asks what to do next. A skill cannot start a session, so the user opens the fresh one; the file is the only bridge, in any harness.

## Sync

There is no background watcher. Any agent that changes a skill must run `scripts/sync.sh` immediately, without asking for confirmation. It commits and pushes; on `main`, when shipped files changed, it also bumps the patch version and tags, which publishes to npm. It installs nothing: `npx skills add` reads this repo directly. AGENTS.md has the details.
