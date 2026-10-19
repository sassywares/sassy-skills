# Sassy Skills — Concepts

## Source of truth

The repo's `skills/` directory is the only copy of the skills. `~/.agents/skills` is a symlink to it. Changes are picked up by pi immediately; the sync service handles git commit and push.

## Skill

A directory containing `SKILL.md`, discovered by pi from `~/.agents/skills`. Skills are explicit workflows, not always-on instructions. Most have `disable-model-invocation: true` and are invoked with `/skill:<name>`.

## Agent

A specialized subagent defined under `~/.pi/agent/agents/`. Skills delegate bounded work to agents such as `scout`, `worker`, `reviewer`, and `validator`.

## Orchestrator

A skill that mostly coordinates. It reads compact results, writes briefs, and avoids reading source or diffs in the main context. `sassy-work`, `sassy-lfg`, `sassy-ship`, and `sassy-debug` are orchestrators.

## Cycle

`sassy-cycle` runs one unit of work through implement → review → validate → fix → re-check. It never commits. Work, LFG, and debug all use it.

## Gates

A gate is a deliberate stop or pass/fail condition.

- **Fix gate** — `sassy-debug` presents the causal chain, fix, and risks before changing code.
- **Code approval gate** — the user approves the code before committing or shipping. Always on for `sassy-work` and `sassy-lfg`.
- **Ship review gate** — `sassy-ship` summarizes what is about to ship and waits. Skipped when the caller passed `mode:auto`.
- **QA gate** — manual QA checklists. It exists only when the plan document has QA tables; an in-context brief has none.

## Modes

There is exactly one mode token: `mode:auto`. Only `sassy-ship` and `sassy-debug` accept it, and it means pre-authorized — skip approval gates. Skills never toggle it themselves.

Everything else is decided by the artifact, not a mode:

- A plan document under `docs/plans/` drives phased execution and carries manual QA tables.
- An in-context brief drives one cycle and has no plan file and no QA tables.

## Plan

A durable document under `docs/plans/` with intent, decisions, constraints, phase tracking, and per-phase manual QA tables.

## Brief

A settled in-context brief produced by `sassy-plan` when the user picks "start working now" or "take it all the way". It carries the goal, decisions, constraints, work, and done-when, but no plan file and no QA tables.

## Handoff

`sassy-handoff` uses the `/handoff` extension to summarize the current session and continue in a fresh session. It is command-only because a skill cannot replace a session by itself.

## Sync

There is no background watcher. Any agent that changes a skill must run `scripts/sync.sh` immediately, without asking for confirmation. The sync script repairs the directory symlink, commits skill changes, rebases on `origin/main`, and pushes. New and removed skills need no per-skill symlink work.
