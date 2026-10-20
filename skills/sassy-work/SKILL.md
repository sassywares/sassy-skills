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

**Outcome:** one phase run through `sassy-cycle`, findings fixed, then a single gate that carries both the code approval and the phase's manual QA checklist, marked `Done` only when both pass, committed via `sassy-commit`; then a handoff that continues the **next** phase in a fresh session, or a `sassy-ship` close-out if this was the last phase.

**Brief input** runs one cycle, presents the code approval gate, commits, and **stops before shipping**.

**The orchestrator does not do work.** Read the plan, dispatch `sassy-cycle`, apply its result, update the plan's tracking table, dispatch `sassy-commit`, and report. Never edit application code.

## Input

Detect the shape from the argument:

- **Plan input** — a path to an existing `.md` file under `docs/plans/`. Take an optional `phase:<n>`. Default to the first phase whose status is not `Done`.
- **Brief input** — anything else. Treat the whole argument as the settled brief from `sassy-plan`.

If a plan path is given but the file does not exist, run `sassy-plan` first and stop.

## QA gate

Read the plan's `**QA:**` line and its per-phase QA table. QA is manual and it is part of the phase gate, not a separate track: a phase turns `Done` only when the code is approved **and** every QA row for that phase has passed.

- The user runs the checks. The agent never ticks a row it did not hear confirmed: a row becomes `Done` only on the user's explicit confirmation in this conversation, with their note recorded.
- A row the user reports failing is a finding. Route it through the same fix-and-recheck loop and present the gate again; a row that cannot pass after that is `Blocked` with the reason.
- Rows nobody has reported on stay `Pending`, and they keep the phase `In progress`. Never infer, batch-assume, or self-certify a pass.

A brief has no QA table, so its gate is code approval alone. Never invent, enable, or disable QA.

## Phase gate

Always gate before committing. One worker fixes findings, one re-check, then present the combined gate — code approval plus the QA checklist — and wait for the user.

## Steps

1. **Load the phase.** Read the plan and only the selected phase's section. If it is already `Done`, stop and report.

   If the phase is `In progress`, an earlier run was interrupted before both gates passed. Ask one question — resume at the gate, or re-run the cycle from scratch — and take the answer. Resuming skips straight to step 4 and does not rebuild the phase.
2. **Run the cycle.** Set the phase `In progress` in the Phase tracking table, then load the `sassy-cycle` skill and follow it, with:
   - work brief = the phase's goal, work items, and "Done when" criteria
   - intent reference = the plan path and phase
3. **Evaluate the phase.** On `Status: done` with `Validator: Conforms` and no critical review findings, note that the code is ready but leave the phase `In progress` — both gates must pass before it closes. On `Status: blocked`, set it `Blocked` in the Phase tracking table and stop; a blocked phase is a real outcome and needs no approval.
4. **Present the phase gate.** Report the phase, what changed, findings raised/resolved, the validator grade, and the reviewer summary. Then give the QA checklist verbatim: each row's ID, check, how to run it, and what passing looks like, with unreported rows `Pending`. Ask for both decisions — code approval and the QA result per row. Wait.
5. **Resolve the gate.** Three outcomes, nothing in between:
   - **Code approved and every QA row passes** → go to step 6.
   - **Code approved, QA still pending** → record that code is approved but leave the phase `In progress`, tick nothing, commit nothing, hand off nothing, and report that the phase is waiting on manual QA plus the command that resumes it.
   - **Any QA row fails** → run `sassy-cycle` once more on the same phase, with the failing rows as the intent reference and a work brief that fixes exactly those failures. Then present the gate again. If a row still fails after that one pass, mark it `Blocked` with the reason and stop.
6. **Commit the phase.** On both gates passing, first mark the phase's QA rows `Done` with the user's notes and the phase `Done` in the Phase tracking table, then dispatch a `worker` whose task is: *read `~/.agents/skills/sassy-commit/SKILL.md` and follow it with `branch:current`*, naming that the commit must include the phase's code changes, the QA table results, and the now-updated Phase tracking table. It returns the hash and subject.

   Work always commits to the current branch. `sassy-ship` creates the shipping branch at close-out when the checked-out branch is the repo default.

   Do not hand off or close out until the commit succeeds.
7. **On commit success:**
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
| Gate before commit and handoff | Do not commit, hand off, or close out until the user approves the code and the phase QA rows pass. |
| Commit per phase | Commit the phase, its QA results, and the plan update via `sassy-commit` before handoff or close-out. |
| Done needs both gates | Mark a phase `Done` only when the user approves the code and every QA row for that phase is `Done`, never before. |
| QA rows follow the user | Tick a QA row `Done` only from the user's explicit confirmation; keep unreported rows `Pending`; log a failed row as a finding to fix. |
| No shipping on the brief path | The brief path commits and stops. Shipping is `sassy-ship` or `sassy-lfg`. |

## Failure handling

- `sassy-cycle` returns `blocked` → mark the phase `Blocked`, stop, report the open findings and the diagnostic.
- QA stays pending or keeps failing across the one allowed fix pass → keep the phase `In progress` (or `Blocked` with the reason), commit nothing, hand off nothing, and report.
- `sassy-commit` fails or leaves the phase changes uncommitted → stop and report; never hand off on top of uncommitted phase work.
- The validator returns **Blocked — insufficient grounding** → treat it as a real blocker; do not advance or hand off.
- Ambiguous or unsafe failure → stop and ask.
