---
name: sassy-work
description: >-
  Execute exactly ONE phase of a sassy plan by delegating to sassy-cycle, then
  hand off to a fresh session for the next phase (or close out via sassy-ship if
  it was the last). Also runs a settled in-context brief with `mode:pipeline`. The
  orchestrator only coordinates.
argument-hint: "<plan path | in-context brief> [phase:<n>] [mode:document|pipeline] [qa:off] [code-approval:off]"
disable-model-invocation: true
---

# Sassy Work

**Outcome:** one phase run through `sassy-cycle`, findings fixed, the phase marked `Done`; presented for the user's approval (or continued automatically with `code-approval:off`); committed via `sassy-commit`; then a handoff that continues the **next** phase in a fresh session, or a `sassy-ship` close-out if this was the last phase.

**The orchestrator does not do work.** Read the plan, dispatch `sassy-cycle`, apply its result, update the plan's tracking table, dispatch `sassy-commit`, and report. Never edit application code.

## Input

Take a plan path from the argument, and an optional `phase:<n>`. Default to the first phase whose status is not `Done`. If the plan does not exist, run `sassy-plan` first and stop.

**Modes.** `mode:document` (default) works from a plan file. `mode:pipeline` consumes a settled in-context brief from `sassy-plan mode:pipeline` instead of a plan path.

**In-context mode (`mode:pipeline`).** When the caller passes `mode:pipeline`, the argument is a settled work brief, not a plan path. The brief is the entire phase: run one cycle from it, do not split it further, and do not create or update any plan file. This is for small work that was deliberately kept in context.

**QA setting.** Read the plan's `**QA:**` line, or the context brief's `QA:` line. `manual` keeps the QA checklist and gate; `disabled` (`qa:off`) removes both. Never toggle QA on or off on your own.

**Code approval flag.** Take an optional `code-approval:manual` or `code-approval:off` (default `manual`). `manual` keeps the code approval gate; `off` removes it. Never toggle it on your own.

## Steps

1. **Load the phase.** Read the plan and only the selected phase's section. If it is already `Done`, stop and report.
2. **Run the cycle.** Load the `sassy-cycle` skill and follow it, with:
   - work brief = the phase's goal, work items, and "Done when" criteria
   - intent reference = the plan path and phase
3. **Close the phase.** On `Status: done` and `Validator: Conforms` with no critical review findings, set the phase `Done` in the plan's Phase tracking table. On `Status: blocked`, set it `Blocked` and stop.
4. **Present the phase gate.** Report the phase, what changed, findings raised/resolved, the validator grade, and the reviewer summary. When QA is enabled, leave QA rows `Pending` (QA is manual); when QA is disabled, omit QA entirely. If code approval is manual, wait for the user's approval. If `code-approval:off`, report the same summary and continue without waiting.
5. **Commit the phase.** On code approval (or immediately when `code-approval:off`), dispatch a `worker` whose task is: *read `~/.agents/skills/sassy-commit/SKILL.md` and follow it with `branch:current`*, naming that the commit must include the phase's code changes and the plan's updated Phase tracking table. It returns the hash and subject.

   **Branch guard.** In `mode:document`, if the checked-out branch is the repo default branch, tell the worker to use `branch:new` for the first phase commit, so the remaining phases and `sassy-ship` land on the same feature branch. Later phases always use `branch:current`. In `mode:pipeline`, never create a branch: always use `branch:current`, even on the default branch. If that branch is the repo default, say so in the phase report; `sassy-ship` creates the shipping branch at close-out.

   Do not hand off or close out until the commit succeeds.
6. **On commit success:**
   - **A next phase exists** → hand off so it starts in a fresh session:

     ```text
     /handoff mode:pipeline Execute phase <next> of <plan>. Run /skill:sassy-work <plan> phase:<next>
     ```

   - **This was the last phase** → run the close-out: load the `sassy-ship` skill and follow it.

### In-context mode (`mode:pipeline`)

When the caller passes `mode:pipeline`, skip the plan steps and treat the brief as one phase:

1. Run one `sassy-cycle` with the in-context brief as the work brief and its decisions / done-when as the intent reference. Do not split it into multiple cycles.
2. Present the phase gate exactly as step 4. With manual QA, include the brief's `QA checks` and leave them for the user; with `qa:off`, omit the checklist and the QA gate. If code approval is manual, wait; with `code-approval:off`, continue without waiting.
3. On code approval, or immediately when `code-approval:off`, commit the brief's changes via the same `sassy-commit` delegation with `branch:current` (never `branch:new`), then run the `sassy-ship` close-out — there is no next phase.
4. On `blocked`, stop and report. Never create or update a plan file.

**Why a command:** session replacement is only available from an interactive command handler, so a skill cannot switch sessions by itself. Running `/handoff` is the single trigger; the extension does the summary, opens the fresh session, and `mode:pipeline` starts the next phase.

## Hard rules

| Rule | Requirement |
|------|-------------|
| Orchestrator only | Delegate all implementation and quality work to `sassy-cycle`. |
| One phase per run | Do exactly one phase. Never continue into the next phase in this session. |
| No plan in `mode:pipeline` | Use the in-context brief; never create or update a plan file. |
| Gate before handoff | Do not hand off or close out until the user approves the code, unless `code-approval:off`. |
| Commit per phase | After code approval (or `code-approval:off`), commit the phase and the plan update via `sassy-commit` before handoff or close-out. |
| Manual QA | When QA is enabled, never mark QA rows `Done`. When `qa:off`, skip QA rows and gates. |
| No shipping before code approval | Shipping happens only in `sassy-ship`, after code approval or when `code-approval:off`. |

## Failure handling

- `sassy-cycle` returns `blocked` → mark the phase `Blocked`, stop, report the open findings and the diagnostic.
- `sassy-commit` fails or leaves the phase changes uncommitted → stop and report; never hand off on top of uncommitted phase work.
- The validator returns **Blocked — insufficient grounding** → treat it as a real blocker; do not advance or hand off.
- Ambiguous or unsafe failure → stop and ask.
