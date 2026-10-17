# Sassy Skills — Concepts

## Source of truth

The repo's `skills/` directory is the only copy of the skills. `~/.agents/skills` is a symlink to it. Changes are picked up by pi immediately; the sync service handles git commit and push.

## Skill

A directory containing `SKILL.md`, discovered by pi from `~/.agents/skills`. Skills are explicit workflows, not always-on instructions. Most have `disable-model-invocation: true` and are invoked with `/skill:<name>`.

## Agent

A specialized subagent defined under `~/.pi/agent/agents/`. Skills delegate bounded work to agents such as `scout`, `diagnoser`, `worker`, `reviewer`, `validator`, and `simplifier`.

## Orchestrator

A skill that mostly coordinates. It reads compact results, writes briefs, and avoids reading source or diffs in the main context. `sassy-work`, `sassy-lfg`, `sassy-ship`, and `sassy-debug` are orchestrators.

## Cycle

`sassy-cycle` runs one unit of work through implement → simplify → review → validate → fix → re-check. It never commits. Work, LFG, and debug all use it.

## Gates

A gate is a deliberate stop or pass/fail condition.

- **Fix gate** — `sassy-debug` presents the causal chain, fix, and risks before changing code.
- **QA gate** — manual QA checklists. Controlled by `qa:manual` / `qa:off`.
- **Code approval gate** — the user approves the code before handoff or shipping. Controlled by `code-approval:manual` / `code-approval:off`.
- **Ship review gate** — `sassy-ship` summarizes what is about to ship and waits. Controlled by `mode:review` / `mode:pipeline`.

## Modes

- `mode:document` — `sassy-plan` writes a phased plan file.
- `mode:context` — `sassy-plan` keeps a single-phase brief in context and writes no plan file. Also used by work/LFG to consume that brief.
- `mode:review` — `sassy-ship` presents the shipping summary and waits for approval.
- `mode:pipeline` — `sassy-ship` skips approval gates and runs straight through.

## Plan

A durable document under `docs/plans/` with intent, decisions, constraints, phase tracking, and (unless disabled) per-phase manual QA tables.

## Handoff

`sassy-handoff` uses the `/handoff` extension to summarize the current session and continue in a fresh session. It is command-only because a skill cannot replace a session by itself.

## Auto-sync

A launchd job runs every 30 seconds. It repairs the directory symlink, commits skill changes, rebases on `origin/main`, and pushes. New and removed skills need no per-skill symlink work.
