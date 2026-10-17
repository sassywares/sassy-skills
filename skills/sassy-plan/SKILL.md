---
name: sassy-plan
description: >-
  Brainstorm and plan in one sitting. By default, a focused discussion turns a
  vague idea into a sophisticated, vertically-sliced, phase-by-phase
  implementation plan written to docs/plans/. Pass mode:context for small work:
  brainstorm only, keep the settled brief in context, and write no plan file.
  Use when asked to brainstorm, scope, plan, or create a phased plan. Manual QA
  is on by default; pass qa:off to disable QA checklists and gates.
argument-hint: "[feature description, requirements, or idea to scope] [mode:context] [qa:off]"
disable-model-invocation: true
---

# Sassy Plan

**Outcome:** a settled discussion, then either a plan file at `docs/plans/<slug>.md` (default) or a compact in-context brief when `mode:context` is passed. One skill for both brainstorming and planning.

**Does not implement.** Planning only. Execution belongs to `sassy-lfg` or `sassy-work`.

## Resolve the flags

- Consume only the literal tokens `mode:document`, `mode:context`, `qa:manual`, and `qa:off`; strip them before treating the rest of the argument as the feature description. If a token repeats, the last one wins. Defaults: `mode:document`, `qa:manual`.
- `mode:document` → write the plan document.
- `mode:context` → no plan document and no phase breakdown. Treat the entire piece of work as a single phase and keep the settled brief in context. Never create or update a file under `docs/plans/`.
- `qa:manual` (default) → manual QA checklists and gates exist.
- `qa:off` → disable manual QA: no QA tables or checklists, and no QA gate during execution. If the user explicitly asks to skip or disable manual QA in plain language, treat it as `qa:off`.

Work in two phases, in order. Do not write the plan until the discussion has settled the open questions.

## Phase A — Discuss (brainstorm)

Have one focused discussion to turn the idea into something plannable.

- **Establish the goal.** What is being built and why. One or two sentences.
- **Find the real constraints.** Existing architecture, conventions, dependencies, and anything that must not change.
- **Surface the unknown.** Ask only questions whose answer changes the plan. Ask a few at a time, not an interrogation. Offer a recommended default with each so the user can just confirm.
- **Recon the code.** Use `scout` subagents to find relevant files, existing patterns, and prior art. Do not read the whole repo yourself; get compressed context back.
- **Settle decisions.** As choices become firm, record them as `D1: …`, `D2: …`. These go in the plan.

Do not over-interview. Stop when the goal, the constraints, and the major decisions are settled enough to slice or act. In `mode:context`, stop when the whole thing is clear enough to run as one phase; do not look for phase boundaries.

## Phase B — Plan (default `mode:document`)

If `mode:context`, skip this phase entirely — do not read `references/plan-format.md` and do not write a file.

Produce the plan. Research what you still need (scout, or bounded reads for facts already located). Then **read `references/plan-format.md` now** and write `docs/plans/<slug>.md` in that format. Never ask the user to choose a QA mode. With `qa:manual`, include the manual QA checklists and gates; with `qa:off`, omit QA tables and checklists. Record the setting under the plan title: `**QA:** manual` or `**QA:** disabled`.

## Finish

### `mode:document` (default)

Report the absolute plan path. Then ask what to do next:

1. Run `sassy-lfg` on the plan (all phases in one session)
2. Run `sassy-work` on the plan (one phase per session, with handoff)
3. Hand off to a fresh session (`sassy-handoff`) without starting work here
4. Edit the plan further
5. Stop here

Do not implement. Do not commit.

### `mode:context`

Do not write any file and do not produce a phase list or tracking table. Treat the entire piece of work as a single phase. Keep the result in context as a compact brief:

```text
Phase: <one-line goal>
Goal: ...
Decisions: D1 ...; D2 ...
Constraints: ...
Work: ...
Done when: ...
QA: manual
QA checks:
- <happy path>
- <edge / regression>
```

With `qa:manual`, keep the `QA: manual` line and the short checks list; with `qa:off`, replace both with a single `QA: disabled` line and add no checklist.

Then ask what to do next:

1. **Start working now** — load `sassy-work` with `mode:context`, passing this brief as the work brief and intent reference. The brief's QA line decides whether QA gates apply.
2. **Run the full loop** — load `sassy-lfg` with `mode:context`, passing this brief.
3. **Hand off to a fresh session** — load `sassy-handoff` with a self-contained goal carrying this brief, since there is no plan file to point at.
4. **Keep refining** — continue the discussion.

Do not implement, write a plan, or hand off until the user chooses.

## Resume

If the user points at an existing sassy plan, update phases and tables in place. If they point at a raw plan from elsewhere, reshape it into this format without discarding its settled decisions. An existing plan is already the document; `mode:context` applies when starting fresh without one.
