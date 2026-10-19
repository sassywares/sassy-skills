---
name: sassy-work
description: >-
  Execute exactly one phase of a sassy plan by delegating to sassy-cycle, then
  hand off to a fresh session for the next phase (or close out via sassy-ship if
  it was the last). Also runs one settled in-context brief and stops before ship.
  The orchestrator only coordinates.
argument-hint: "<plan path | brief> [phase:<n>]"
disable-model-invocation: true
---

# Sassy Work

**Outcome:** one phase run through `sassy-cycle`, findings fixed, presented for the user's approval, marked `Done` only after approval, then committed via `sassy-commit`; then a handoff that continues the **next** phase in a fresh session, or a `sassy-ship` close-out if this was the last phase.

**Brief input** runs one cycle, presents the code approval gate, commits, and **stops before shipping**.

**The orchestrator does not do work.** Read the plan, dispatch `sassy-cycle`, apply its result, update the plan's tracking table, dispatch `sassy-commit`, and report. Never edit application code.

## Input

Detect the shape from the argument:

- **Plan input** — a path to an existing `.md` file under `docs/plans/`. Take an optional `phase:<n>`. Default to the first phase whose status is not `Done`.
- **Brief input** — anything else. Treat the whole argument as the settled brief from `sassy-plan`.

If a plan path is given but the file does not exist, run `sassy-plan` first and stop.

## QA

Read the plan's `**QA:**` line and its per-phase QA table. Manual QA is the default, and the rows stay `Pending`: never mark them `Done`. A brief has none, so there is no QA gate on the brief path. Never invent, enable, or disable QA.

## Code approval

Always gate before committing. One worker fixes findings, one re-check, then present the phase gate and wait for the user.

## Steps

1. **Load the phase.** Read the plan and only the selected phase's section. If it is already `Done`, stop and report.
2. **Run the cycle.** Load the `sassy-cycle` skill and follow it, with:
   - work brief = the phase's goal, work items, and "Done when" criteria
   - intent reference = the plan path and phase
3. **Evaluate the phase.** On `Status: done` with `Validator: Conforms` and no critical review findings, note that the phase is ready to close but leave its status unchanged — the plan's Phase tracking table is only updated after approval. On `Status: blocked`, set it `Blocked` in the plan's Phase tracking table and stop; a blocked phase is a real outcome and needs no approval.
4. **Present the phase gate.** Report the phase, what changed, findings raised/resolved, the validator grade, and the reviewer summary. Leave QA rows `Pending` (QA is manual). Wait for the user's approval.
5. **Commit the phase.** On code approval, first mark the phase `Done` in the plan's Phase tracking table, then dispatch a `worker` whose task is: *read `~/.agents/skills/sassy-commit/SKILL.md` and follow it with `branch:current`*, naming that the commit must include both the phase's code changes and the now-updated Phase tracking table. It returns the hash and subject.

   Work always commits to the current branch. `sassy-ship` creates the shipping branch at close-out when the checked-out branch is the repo default.

   Do not hand off or close out until the commit succeeds.
6. **On commit success:**
   - **A next phase exists** → hand off so it starts in a fresh session:

     ```text
     /handoff Execute phase <next> of <plan>. Run /skill:sassy-work <plan> phase:<next>
     ```

     The user submits the seeded prompt once, and the next phase starts in the fresh session.

   - **This was the last phase** → run the close-out: load the `sassy-ship` skill and follow it.

**Why a command:** session replacement is only available from an interactive command handler, so a skill cannot switch sessions by itself. Running `/handoff` is the single trigger; the extension does the summary and opens the fresh session.

## Brief input

When the argument is not a plan path, it is one settled brief:

1. Run one `sassy-cycle` with the brief as the work brief and its decisions / done-when as the intent reference. Do not split it into multiple cycles.
2. Present the code approval gate with no QA checklist, and wait.
3. On code approval, commit the brief's changes via the same `sassy-commit` delegation with `branch:current`.
4. Stop and report. Shipping is a separate step (`sassy-ship`), or `sassy-lfg` would have taken it all the way. Never create or update a plan file.

## Hard rules

| Rule | Requirement |
|------|-------------|
| Orchestrator only | Delegate all implementation and quality work to `sassy-cycle`. |
| One phase per run | Do exactly one phase. Never continue into the next phase in this session. |
| Gate before commit and handoff | Do not commit, hand off, or close out until the user approves the code. |
| Commit per phase | Commit the phase and the plan update via `sassy-commit` before handoff or close-out. |
| Plan status follows approval | Mark a phase `Done` only after the user approves it, never before. |
| Manual QA rows stay `Pending` | Never mark QA rows `Done`. |
| No shipping on the brief path | The brief path commits and stops. Shipping is `sassy-ship` or `sassy-lfg`. |

## Failure handling

- `sassy-cycle` returns `blocked` → mark the phase `Blocked`, stop, report the open findings and the diagnostic.
- `sassy-commit` fails or leaves the phase changes uncommitted → stop and report; never hand off on top of uncommitted phase work.
- The validator returns **Blocked — insufficient grounding** → treat it as a real blocker; do not advance or hand off.
- Ambiguous or unsafe failure → stop and ask.
