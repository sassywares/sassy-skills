---
name: sassy-plan
description: >-
  Brainstorm and settle a piece of work in one discussion, then let the user
  choose: write a plan document, start working now, or take it all the way to a
  PR. No modes, no QA flags. Use when asked to brainstorm, scope, plan, or create
  a phased plan.
argument-hint: "[feature description, requirements, or idea to scope]"
disable-model-invocation: true
---

# Sassy Plan

**Outcome:** a settled discussion, then the user's explicit choice from three options: write a plan document, start working now, or take it all the way to a PR.

**Does not implement.** Planning never implements. Execution belongs to `sassy-work` or `sassy-lfg`, and only after the user picks.

**Config.** Resolve `.sassywares/config.yaml` (nearest, walking up) per the `sassy-setup` skill's `references/config.md`. Precedence: explicit token > session instruction > config > skill default. Plans land in `artifacts.plans`.

**Update nudge.** Once per run, if `node_modules/.bin/sassy-skills` exists, run `node_modules/.bin/sassy-skills outdated`. It is throttled to once a day per machine and silently does nothing offline. Pass any newer version on in one line; never block, retry, or fail on it.

## Phase A — Discuss (brainstorm)

Have one focused discussion to turn the idea into something plannable.

- **Establish the goal.** What is being built and why. One or two sentences.
- **Find the real constraints.** Existing architecture, conventions, dependencies, and anything that must not change.
- **Surface the unknown.** Ask only questions whose answer changes the plan. Ask a few at a time, not an interrogation. Offer a recommended default with each so the user can just confirm.
- **Recon the code.** Use `sassy-scout` to ground the area: relevant files, existing patterns, prior art, and any prior learning written about it. Do not read the whole repo yourself; it writes a grounding brief and returns a gist plus the brief path.
- **Use the learnings.** When the brief lists prior learnings, treat a relevant one as a constraint on the design and record it as a decision (`D3: …`) so the plan cites it. A learning that contradicts the plan is worth naming at the picker, not discovering mid-phase.
- **Settle decisions.** As choices become firm, record them as `D1: …`, `D2: …`. These go in the plan or the brief.

Do not over-interview. Stop when the goal, the constraints, and the major decisions are settled enough to slice or act.

## The picker

When the discussion settles, present exactly these three options and stop until the user picks. Do not recommend one.

```text
Settled. Pick one:
1. Write it to <artifacts.plans>/<slug>.md
2. Start working now — stop before ship
3. Take it all the way — run it, ship it, babysit the PR
```

The user must pick explicitly. There is no default and no auto-selection. If no human is present to answer (rare, e.g. a scripted invocation), take option 2 and say so.

### Option 1 — Write the plan

Read `references/plan-format.md` and write the plan, including the per-phase manual QA tables that format defines. Then report the absolute path and STOP. No second menu, no "what next" prompt. Do not implement or commit.

### Option 2 — Start working now

Load the `sassy-work` skill with the settled brief as the work brief and its decisions / done-when as the intent reference. No plan file is written. It stops before ship.

### Option 3 — Take it all the way

Load the `sassy-lfg` skill the same way: the settled brief as the work brief, its decisions / done-when as the intent reference. No plan file is written.

## QA

The plan document carries manual QA tables per `references/plan-format.md`. Those rows gate phase completion: a phase is `Done` only when the code is approved and every row passed, with the user running the checks. The in-context brief has no QA table, so its gate is code approval alone. Omit QA tables only when the user explicitly asks to skip QA in plain language.

## Resume

If the user points at an existing sassy plan, update phases and tables in place. If they point at a raw plan from elsewhere, reshape it into this format without discarding its settled decisions. An existing plan is already the document.
