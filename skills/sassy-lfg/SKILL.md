---
name: sassy-lfg
description: >-
  Execute a whole sassy plan phase by phase, or one settled in-context brief,
  then close out via sassy-ship after code approval. The orchestrator only
  coordinates. Best for small plans that one context can hold.
argument-hint: "<plan path | brief> [branch:infer|current|new]"
disable-model-invocation: true
---

# Sassy LFG

**Outcome:** every phase in the plan run through `sassy-cycle`, then one gate that carries the code approval and every phase's manual QA checklist, phases marked `Done` only when both pass, then `sassy-ship` closes it out (compound, handbook, commit, PR, babysit; under `commit.branch: current`, commit and push with no PR). A brief runs one cycle through the same gate, then ships.

**The orchestrator does not do work.** Read the plan, dispatch `sassy-cycle` per phase, then `sassy-ship`. Never edit application code. Keep the main context small — all heavy work happens in subagents.

**Config.** Resolve `.sassywares/config.yaml` (nearest, walking up) per the `sassy-setup` skill's `references/config.md`. Precedence: explicit token > session instruction > config > skill default. Plans live under `artifacts.plans`; `git.repo` decides how the close-out persists; `commit.branch` decides whether the run needs its own branch.

**Harness.** Loading another skill, dispatching an agent, and any command you hand the user follow the `sassy-setup` skill's `references/harness.md`. Read it once per run, before the first of those.

## Input

Detect the shape from the argument:

- **Plan input** — a path to an existing `.md` file under `artifacts.plans`.
- **Brief input** — anything else. Treat the whole argument as the settled brief from `sassy-plan`.

If nothing is passed and no plan exists, run `sassy-plan` first and use what the user picks there.

## QA gate

Read the plan's `**QA:**` line and its per-phase QA tables. QA is manual and part of the completion gate: LFG builds every phase first, then presents one gate carrying code approval plus every phase's QA checklist. No phase turns `Done`, and nothing is committed or shipped, until both pass.

- The user runs the checks. The agent never ticks a row it did not hear confirmed: a row becomes `Done` only on the user's explicit confirmation, with their note recorded.
- A failed row is a finding. Route it through one more `sassy-cycle` on its phase and present the gate again; a row that still fails is `Blocked` with the reason and stops the run.
- Rows nobody has reported on stay `Pending` and hold their phase `In progress`.

A brief has no QA table, so its gate is code approval alone. Never invent, enable, or disable QA.

## Steps

1. **Load the plan.** Read the plan and its Phase tracking table. If phases are already `In progress` from an interrupted run, ask once whether to resume at the gate or rerun those cycles, then continue from the answer.
2. **Resolve the branch, before touching code.** Follow the `sassy-setup` skill's `references/branching.md` with this run's `branch:` token, if any. LFG runs every phase in one session, so the branch is cut once here and every phase commits onto it. Report the branch and its start point in the gate. A `stop-and-ask` here stops the run before any phase starts.
3. **Run every phase, in order.** For each phase not `Done`:
   - Set the phase `In progress`, then load the `sassy-cycle` skill and follow it, with work brief = the phase's goal/work/"Done when", and intent reference = the plan path and phase.
   - On `Status: done` and `Validator: Conforms`, leave the phase `In progress` — its QA rows are still owed, and only the gate closes them.
   - On `Status: blocked`, mark it `Blocked` and stop the run.
4. **The gate.** After the last phase, report: the plan path, each phase's status, what changed per phase, and the validator/reviewer summaries. Then give every phase's QA checklist verbatim — row ID, check, how to run it, what passing looks like — with unreported rows `Pending`. Ask for both decisions: code approval and the QA result per row. Wait. Do not commit.
5. **Resolve the gate.** Three outcomes:
   - **Code approved and every QA row passes** → mark the rows `Done` with the user's notes, mark the phases `Done`, then run the close-out below.
   - **Code approved, QA still pending** → tick nothing, mark nothing `Done`, commit nothing, ship nothing. Report which rows are outstanding and how to resume (invoke `sassy-lfg <plan>` in the harness's syntax), and stop.
   - **Any QA row fails** → run one more `sassy-cycle` on that phase with the failing rows as the intent reference, then present the gate again. A row that still fails is `Blocked` with the reason and stops the run.
6. **Close-out.** On both gates passing, load the `sassy-ship` skill and follow it. Do only the close-out steps the user approves. Babysit options (`merge:on|off`, `delete-branch:on|off`) are forwarded through `sassy-ship` to `sassy-babysit`. The branch from step 2 already carries the work, so ship commits and opens the PR on it; ship never creates the branch. Under `commit.branch: current` ship commits and pushes the checked-out branch to its upstream and skips the PR, `hooks.pr.*`, babysit, and merge.

## Brief constraints

Every worker brief this run dispatches must include:

- Tests only for the files the worker changed and the existing tests that directly regress them. The full suite runs once at the final gate.
- A hard timeout around long-running commands, for example `timeout 300 bunx vitest run path/to/file.test.ts`; a hung command is killed and reported.
- The instruction to stop and report a blocker to the orchestrator after one failed retry, with the exact command and error, instead of looping on the same failure.

## Brief input

When the argument is not a plan path, the brief is the one phase:

1. Resolve the branch exactly as the plan path does — the `sassy-setup` skill's `references/branching.md`, this run's `branch:` token — before the cycle runs.
2. Run one `sassy-cycle` with the brief as the work brief and its decisions / done-when as the intent reference. Do not split it into multiple phases.
3. Present the code approval gate with no QA checklist, and wait.
4. On code approval, run `sassy-ship`. Do not run `sassy-plan` or write a plan file.

## Hard rules

| Rule | Requirement |
|------|-------------|
| Orchestrator only | Delegate every phase to `sassy-cycle`. Never read source or edit code. |
| Branch before code | Resolve the branch per the `sassy-setup` skill's `references/branching.md` before any phase runs, so no change lands on a base branch. |
| Phases in plan order | Phases run one after another, in plan order. |
| Done needs both gates | Mark a phase `Done` only when the user approves the code and every QA row for it is `Done`. |
| QA rows follow the user | Tick a QA row `Done` only from the user's explicit confirmation; keep unreported rows `Pending`; log a failed row as a finding for one more cycle. |
| Gates before shipping | Nothing is committed or shipped until the code is approved and every QA row passes. Shipping is `sassy-ship`. |
| No plan on the brief path | Use the in-context brief; never create or update a plan file. |
| Compact context | Only pass briefs to subagents and keep only their summaries. |

## Failure handling

- A phase returns `blocked` → stop the run, report the open findings and diagnostic.
- QA rows stay pending or keep failing after the one allowed pass → stop, commit nothing, ship nothing, report the outstanding rows.
- The validator returns **Blocked — insufficient grounding** → stop; do not advance.
- Ambiguous or unsafe failure → stop and ask rather than guessing.
