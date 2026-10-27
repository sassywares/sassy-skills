---
name: sassy-work
description: >-
  Execute exactly one phase of a sassy plan by delegating to sassy-cycle, then
  hand off to a fresh session for the next phase (or close out via sassy-ship if
  it was the last). Also runs one settled in-context brief and stops before ship.
  The orchestrator only coordinates.
argument-hint: "<plan path | brief> [phase:<n>] [branch:infer|current|new]"
disable-model-invocation: true
---

# Sassy Work

**Outcome:** one phase run through `sassy-cycle`, findings fixed, then a single gate that carries both the code approval and the phase's manual QA checklist, marked `Done` only when both pass, committed via `sassy-commit`; then a handoff that continues the **next** phase in a fresh session, or a `sassy-ship` close-out if this was the last phase.

**Brief input** runs one cycle, presents the code approval gate, commits, and **stops before shipping**.

**The orchestrator does not do work.** Read the plan, dispatch `sassy-cycle`, apply its result, update the plan's tracking table, dispatch `sassy-commit` or the snapshot, and report. Never edit application code.

**Config.** Resolve `.sassywares/config.yaml` (nearest, walking up) per the `sassy-setup` skill's `references/config.md`. Precedence: explicit token > session instruction > config > skill default. `git.repo` decides what the phase commit does, `artifacts.plans` decides where the plan lives, and `commit.branch` decides whether this run needs its own branch.

**Harness.** Loading another skill, dispatching an agent, and any command you hand the user follow the `sassy-setup` skill's `references/harness.md`. Read it once per run, before the first of those.

## Input

Detect the shape from the argument:

- **Plan input** — a path to an existing `.md` file under `artifacts.plans`. Take an optional `phase:<n>`. Default to the first phase whose status is not `Done`.
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

   If the phase is `In progress`, an earlier run was interrupted before both gates passed. Ask one question — resume at the gate, or re-run the cycle from scratch — and take the answer. Resuming skips the cycle and goes straight to step 5, but **still resolve the branch at step 2 first**: on `reuse` it is a no-op, and on `create` it is the difference between committing on the base and not.
2. **Resolve the branch, before touching code.** Follow the `sassy-setup` skill's `references/branching.md` with this run's `branch:` token, if any. On `create`, cut the branch now — not at commit time — so no change ever exists on a base branch. On `reuse`, stay where you are, which is how a handed-off later phase or a resumed run lands on the branch the first phase cut. On `stop-and-ask`, present the choice and wait. Carry the branch and its start point into every gate summary you present.
3. **Run the cycle.** Set the phase `In progress` in the Phase tracking table, then load the `sassy-cycle` skill and follow it, with:
   - work brief = the phase's goal, work items, and "Done when" criteria
   - intent reference = the plan path and phase
4. **Evaluate the phase.** On `Status: done` with `Validator: Conforms` and no critical review findings, note that the code is ready but leave the phase `In progress` — both gates must pass before it closes. On `Status: blocked`, set it `Blocked` in the Phase tracking table and stop; a blocked phase is a real outcome and needs no approval.
5. **Present the phase gate.** Report the phase, what changed, findings raised/resolved, the validator grade, and the reviewer summary. Then give the QA checklist verbatim: each row's ID, check, how to run it, and what passing looks like, with unreported rows `Pending`. Ask for both decisions — code approval and the QA result per row. Wait.
6. **Resolve the gate.** Three outcomes, nothing in between:
   - **Code approved and every QA row passes** → go to step 7.
   - **Code approved, QA still pending** → record that code is approved but leave the phase `In progress`, tick nothing, commit nothing, hand off nothing, and report that the phase is waiting on manual QA plus the command that resumes it.
   - **Any QA row fails** → run `sassy-cycle` once more on the same phase, with the failing rows as the intent reference and a work brief that fixes exactly those failures. Then present the gate again. If a row still fails after that one pass, mark it `Blocked` with the reason and stop.
7. **Commit the phase.** On both gates passing, first mark the phase's QA rows `Done` with the user's notes and the phase `Done` in the Phase tracking table, then persist according to `git.repo`:

   - **A remote** — dispatch a `worker` whose task is: *load the `sassy-commit` skill and follow it with `branch:current`*, naming that the commit must include the phase's code changes, the QA table results, and the now-updated Phase tracking table. It returns the hash and subject. The branch already exists: step 2 cut it, so committing on it is the point of `branch:current` here.
   - **`workspace`** — dispatch a `worker` per affected repo to commit that repo's code on the run's shared branch, then run `.sassywares/workspace/snapshot` for the plan, QA results, and docs at the root. The gate's approval is the commit approval; the snapshot runs right after it and is never skipped. A missing or outdated `.sassywares/workspace/snapshot` is a blocker — say to run `sassy-setup`.
   - **`none`** — nothing is persisted. Report that the phase's work is uncommitted and stop; never hand off on top of it.

   Do not hand off or close out until the commit or snapshot succeeds.
8. **On commit success:**
   - **A next phase exists** → load the `sassy-handoff` skill in `mode:write` with the goal *Execute phase <next> of <plan> by invoking `sassy-work <plan> phase:<next>`*. It writes the handoff file and gives the user a `sassy-handoff mode:read <path>` command; the next phase starts when they run it in a fresh session and pick it.

   - **This was the last phase** → run the close-out: load the `sassy-ship` skill and follow it.

**Why a fresh session:** one phase per context keeps every phase's context small. A skill cannot start a session itself, so the handoff file is the bridge and the user opens the session.

## Brief input

When the argument is not a plan path, it is one settled brief:

1. Resolve the branch exactly as the plan path does — `references/branching.md`, this run's `branch:` token — before the cycle runs.
2. Run one `sassy-cycle` with the brief as the work brief and its decisions / done-when as the intent reference. Do not split it into multiple cycles.
3. Present the code approval gate with no QA checklist, and wait.
4. On code approval, persist the brief's changes the same way the plan path does: a `sassy-commit` delegation with `branch:current` in a remote repo, or the workspace snapshot in a workspace.
5. Stop and report. Shipping is a separate step (`sassy-ship`), or `sassy-lfg` would have taken it all the way. Never create or update a plan file.

## Hard rules

| Rule | Requirement |
|------|-------------|
| Orchestrator only | Delegate all implementation and quality work to `sassy-cycle`. |
| Branch before code | Resolve the branch per the `sassy-setup` skill's `references/branching.md` before the cycle runs, so no change ever lands on a base branch. |
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
