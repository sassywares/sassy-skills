---
name: sassy-lfg
description: >-
  Execute a whole sassy plan phase by phase, or one settled in-context brief,
  then close out via sassy-ship after code approval. The orchestrator only
  coordinates. Best for small plans that one context can hold.
argument-hint: "<plan path | brief>"
disable-model-invocation: true
---

# Sassy LFG

**Outcome:** every phase in the plan run through `sassy-cycle`, the whole change approved by the user at one code approval gate, then `sassy-ship` closes it out (compound, handbook, commit, PR, babysit). A brief runs one cycle through the same gate, then ships.

**The orchestrator does not do work.** Read the plan, dispatch `sassy-cycle` per phase, then `sassy-ship`. Never edit application code. Keep the main context small — all heavy work happens in subagents.

## Input

Detect the shape from the argument:

- **Plan input** — a path to an existing `.md` file under `docs/plans/`.
- **Brief input** — anything else. Treat the whole argument as the settled brief from `sassy-plan`.

If nothing is passed and no plan exists, run `sassy-plan` first and use what the user picks there.

## QA

Read the plan's `**QA:**` line and its per-phase QA table. Manual QA is the default, and the rows stay `Pending`: never mark them `Done`. A brief has none, so there is no QA checklist and no QA gate on the brief path. Never invent, enable, or disable QA.

## Steps

1. **Load the plan.** Read the plan and its Phase tracking table.
2. **Run every phase, in order.** For each phase not `Done`:
   - Load the `sassy-cycle` skill and follow it, with work brief = the phase's goal/work/"Done when", and intent reference = the plan path and phase.
   - On `Status: done` and `Validator: Conforms`, mark the phase `Done`.
   - On `Status: blocked`, mark it `Blocked` and stop the run.
3. **Code approval gate.** After the last phase, report: the plan path, each phase's final status, what changed per phase, whether manual QA applies, and that the change is uncommitted. Wait for the user's approval. Do not commit.
4. **Close-out.** On code approval, load the `sassy-ship` skill and follow it. Do only the close-out steps the user approves. Babysit options (`merge:on|off`, `delete-branch:on|off`) are forwarded through `sassy-ship` to `sassy-babysit`.

Work commits to the current branch. `sassy-ship` creates the shipping branch at close-out when the checked-out branch is the repo default.

## Brief input

When the argument is not a plan path, the brief is the one phase:

1. Run one `sassy-cycle` with the brief as the work brief and its decisions / done-when as the intent reference. Do not split it into multiple phases.
2. Present the code approval gate with no QA checklist, and wait.
3. On code approval, run `sassy-ship`. Do not run `sassy-plan` or write a plan file.

## Hard rules

| Rule | Requirement |
|------|-------------|
| Orchestrator only | Delegate every phase to `sassy-cycle`. Never read source or edit code. |
| Phases in plan order | Phases run one after another, in plan order. |
| Code approval before shipping | The change stays uncommitted until the user approves the code. Shipping is `sassy-ship`. |
| No plan on the brief path | Use the in-context brief; never create or update a plan file. |
| Compact context | Only pass briefs to subagents and keep only their summaries. |

## Failure handling

- A phase returns `blocked` → stop the run, report the open findings and diagnostic.
- The validator returns **Blocked — insufficient grounding** → stop; do not advance.
- Ambiguous or unsafe failure → stop and ask rather than guessing.
