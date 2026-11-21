---
name: sassy-work
description: >-
  Execute exactly one phase of a sassy plan by delegating to sassy-cycle, then
  commit it (or close out via sassy-ship if it was the last). The next phase is
  a run of its own when the user starts one. Also runs one settled in-context
  brief and stops before ship. The orchestrator only coordinates.
argument-hint: "<plan path | brief> [phase:<n>] [branch:infer|current|new] [worktree:on|off] [review:logic|surface|none]"
---

# Sassy Work

**Outcome:** one phase run through `sassy-cycle`, findings fixed, then a single gate that carries both the code approval and the phase's QA checklist (`Manual` rows from the user, `Auto` rows from a `sassy-dogfood` report), marked `Done` only when both pass, committed via `sassy-commit`; then the run ends, or a `sassy-ship` close-out when this was the last phase.

**Brief input** runs one cycle, presents the code approval gate, commits, and **stops before shipping**.

**The orchestrator does not do work.** Read the plan, dispatch `sassy-cycle`, apply its result, update the plan's tracking table, dispatch `sassy-commit` or the snapshot, and report. Never edit application code.

**Config.** Resolve `.sassywares/config.yaml` (nearest, walking up) per the `sassy-setup` skill's `references/config.md`. Precedence: explicit token > session instruction > config > skill default. `git.repo` decides what the phase commit does, `artifacts.plans` decides where the plan lives, `commit.branch` decides whether this run needs its own branch, and a `worktree:on|off` token answers the checkout question `branching.md` asks at step 6. The token outranks config but never widens what `worktrees.enabled` allows.

**Harness.** Loading another skill, dispatching an agent, and any command you hand the user follow the `sassy-setup` skill's `references/harness.md`. Read it once per run, before the first of those.

## Input

Detect the shape from the argument:

- **Plan input** — a path to an existing `.md` file under `artifacts.plans`. Take an optional `phase:<n>`. Default to the first phase whose status is not `Done`.
- **Brief input** — anything else. Treat the whole argument as the settled brief from `sassy-plan`.

If a plan path is given but the file does not exist, run `sassy-plan` first and stop.

## Review tier

A phase's `**Review:**` line names its change tier — `logic`, `surface`, or `none` — per the `sassy-plan` skill's `references/plan-format.md`. Pass it to `sassy-cycle`. A `review:` token on this run overrides the plan line; without either, the cycle detects the tier from the work. The tier decides the quality agents, so it is never a reason to skip the code approval gate.

## QA gate

Read the plan's `**QA:**` line and its per-phase QA table. QA is part of the phase gate, not a separate track: a phase turns `Done` only when the code is approved **and** every QA row for that phase has passed.

Rows split by `Mode`, and the split decides who can settle them:

- **`Manual` rows are the user's.** The agent never ticks one it did not hear confirmed: it becomes `Done` only on the user's explicit confirmation in this conversation, with their note recorded.
- **`Auto` rows are proved, not opined.** Step 4 runs `sassy-dogfood` for the phase's sections before the gate, and a row becomes `Done` only from a report whose verdict is `pass`, with the run id in `Notes`. A failed run is a finding into a rework cycle; the row never becomes `Done` because the agent judged it fine.
- A row failing again after its rework is `Blocked` with the reason. Rows nobody has reported on stay `Pending`, and they keep the phase `In progress`. Never infer, batch-assume, or self-certify a pass.

A brief has no QA table, so its gate is code approval alone. Never invent, enable, or disable QA. A plan's `Auto` rows exist because the project enabled them: `dogfood.enabled` and a recipe section with a `Prove it:` step, per the `sassy-setup` skill's `references/dogfood.md`. Never edit the recipe to turn a red run green — propose the diff and ask.

## Phase gate

Always gate before committing. The cycle has already fixed its findings in one work pass; present the combined gate — code approval plus the QA checklist — and wait for the user. A change the user sends back is new work: a new cycle with the change as its brief, reviewed at its detected tier, then the gate again. Failing QA rows alone are a one-pass rework. Neither is a direct edit.

## Steps

1. **Load the phase.** Read the plan and only the selected phase's section. If it is already `Done`, stop and report.

   If the phase is `In progress`, an earlier run was interrupted before both gates passed. Ask one question — resume at the gate, or re-run the cycle from scratch — and take the answer. Resuming skips the cycle and goes straight to step 5, but **still resolve the branch at step 2 first**: on `reuse` it is a no-op, and on `create` it is the difference between committing on the base and not.
2. **Resolve the branch, before touching code.** Follow the `sassy-setup` skill's `references/branching.md` with this run's `branch:` and `worktree:` tokens, if any. On `create`, cut the branch now — not at commit time — so no change ever exists on a base branch. On `reuse`, stay where you are, which is how a later phase or a resumed run lands on the branch the first phase cut. On `stop-and-ask`, present the choice and wait. When the decision took a checkout, every brief dispatched from here on names its absolute `WT_PATH`, as `branching.md` requires. Carry the branch, its start point, and the checkout into every gate summary you present.
3. **Run the cycle.** Set the phase `In progress` in the Phase tracking table, then load the `sassy-cycle` skill and follow it, with:
   - work brief = the phase's goal, work items, and "Done when" criteria
   - intent reference = the plan path and phase
   - review tier = this run's `review:` token when present, else the phase's `**Review:**` line
4. **Evaluate the phase.** On `Status: done`, the code is ready for the gate, but leave the phase `In progress` — both gates must pass before it closes. On `Status: blocked`, set it `Blocked` in the Phase tracking table and stop; a blocked phase is a real outcome and needs no approval.

   **Then prove the `Auto` rows.** If the phase has any, run the `sassy-dogfood` skill in `mode:run` with each row's section named, before the gate and never after it. When the decision took a checkout, the report runs against the checkout's own address — `WT_PATH`, and `WT_NAMESPACE`/`WT_PORT` where the project declared a port range — since proof run against the main checkout's app proves the wrong app. Record what each report said. A `failed` verdict is a finding, so the phase goes back through step 3's cycle with the failing step and the report's log tail as its findings, and this step runs again; a `class: env` verdict is not a finding — report that the toolchain is broken, leave the phase `In progress`, and stop. An `Auto` row with no report is `Pending`, never `Done`.
5. **Present the phase gate.** Report the phase, what changed, findings raised and what the single fix pass did with each (self-reported; the cycle does not re-review), the simplifications applied or skipped, the validator grade (or that it did not run), the reviewer summary, and the reviewer's suggestions as options the user may pick. Then give the QA checklist verbatim: each row's ID, check, `Mode`, and — for `Manual` — how to run it and what passing looks like, and for `Auto` — the dogfood verdict and run id, with unreported rows `Pending`. Ask for both decisions — code approval (or the changes wanted, including any suggestions picked) and the result per `Manual` row. Wait.
6. **Resolve the gate.** Four outcomes, nothing in between:
   - **Code approved and every QA row passes** → go to step 7.
   - **Code approved, `Manual` rows still pending** → record that code is approved but leave the phase `In progress`, tick nothing, commit nothing, and report that the phase is waiting on manual QA plus the command that resumes it.
   - **Changes requested** → a new cycle: load `sassy-cycle` with the requested changes as the work brief and as the intent reference; the plan path and phase stay as context. The cycle detects the change's tier and runs that tier's agents. On `done`, re-prove the `Auto` rows (step 4) and present the gate again from step 5; on `blocked`, mark the phase `Blocked` and stop. If a QA row also failed, name it in the work brief as an additional requirement. Change requests have no cap — each one is the user's call.
   - **A QA row fails, with no change requested** → a rework cycle: load `sassy-cycle` with the failing rows as findings and the plan path and phase as the intent reference. On `done`, re-prove the `Auto` rows (step 4) and present the gate again from step 5; on `blocked`, mark the phase `Blocked` and stop. A row that fails again after its rework is `Blocked` with the reason and stops the phase.
7. **Commit the phase.** On both gates passing, first mark the phase's QA rows `Done` — `Manual` rows with the user's notes, `Auto` rows with the verdict and run id from the report — and the phase `Done` in the Phase tracking table, then persist according to `git.repo`:

   - **A remote** — dispatch a `worker` whose task is: *load the `sassy-commit` skill and follow it with `branch:current`*, naming that the commit must include the phase's code changes, the QA table results, and the now-updated Phase tracking table. It returns the hash and subject. The branch already exists: step 2 cut it, so committing on it is the point of `branch:current` here.
   - **`workspace`** — dispatch a `worker` per affected repo to commit that repo's code on the run's shared branch, then run `.sassywares/workspace/snapshot` for the plan, QA results, and docs at the root. The gate's approval is the commit approval; the snapshot runs right after it and is never skipped. A missing or outdated `.sassywares/workspace/snapshot` is a blocker — say to run `sassy-setup`.
   - **`none`** — nothing is persisted. Report that the phase's work is uncommitted and stop; nothing follows an uncommitted phase.

   Do not close out until the commit or snapshot succeeds.
8. **On commit success:**
   - **This was the last phase** → run the close-out: load the `sassy-ship` skill and follow it (under `commit.branch: current` ship commits and pushes, with no PR).
   - **Any phase is left** → report the commit and stop. Name the next phase and the command that picks it up — `sassy-work <plan>` takes the first phase that is not `Done` — and never start it in this session. Continuing, stopping for now, or choosing another executor is the user's call; do not offer or write a handoff.

## Brief input

When the argument is not a plan path, it is one settled brief:

1. Resolve the branch exactly as the plan path does — `references/branching.md`, this run's `branch:` and `worktree:` tokens — before the cycle runs. Every brief dispatched from there names the absolute `WT_PATH` when the decision took a checkout.
2. Run one `sassy-cycle` with the brief as the work brief, its decisions / done-when as the intent reference, and this run's `review:` token as the tier. Do not split it into multiple cycles.
3. Present the code approval gate with no QA checklist, and wait. Changes requested → a new cycle with the changes as the work brief and as the intent reference, the brief's decisions / done-when staying as context, then this gate again; `blocked` stops.
4. On code approval, persist the brief's changes the same way the plan path does: a `sassy-commit` delegation with `branch:current` in a remote repo, or the workspace snapshot in a workspace.
5. Stop and report. Shipping is a separate step (`sassy-ship`), or `sassy-lfg` would have built and shipped it. Never create or update a plan file.

## Hard rules

| Rule | Requirement |
|------|-------------|
| Orchestrator only | Delegate all implementation and quality work to `sassy-cycle`. |
| Branch before code | Resolve the branch per the `sassy-setup` skill's `references/branching.md` before the cycle runs, so no change ever lands on a base branch. |
| Checkout from the branch decision | When the decision took a checkout, every brief names the absolute `WT_PATH` and the main checkout stays read-only; never restate that contract, it is `branching.md`'s. |
| One phase per run | Do exactly one phase. Never continue into the next phase in this session. |
| Gate before commit and close-out | Do not commit or close out until the user approves the code and the phase QA rows pass. |
| Commit per phase | Commit the phase, its QA results, and the plan update via `sassy-commit` before close-out. |
| Handing off is the user's | Never write a handoff or suggest one. The run ends at its report; `sassy-handoff` is invoked by the user, in their own session and on their own initiative. |
| Done needs both gates | Mark a phase `Done` only when the user approves the code and every QA row for that phase is `Done`, never before. |
| QA rows follow their mode | Tick a `Manual` row `Done` only from the user's explicit confirmation, and an `Auto` row only from a passing dogfood report; keep unreported rows `Pending`; a failed row is a finding for a rework cycle. |
| Send-backs split | A user's change request at the gate runs a new `sassy-cycle` at its detected tier; failing QA rows alone go through a one-pass rework. Neither is a direct edit. |
| No shipping on the brief path | The brief path commits and stops. Shipping is `sassy-ship` or `sassy-lfg`. |

## Failure handling

- `sassy-cycle` returns `blocked` → mark the phase `Blocked`, stop, report the open findings and the diagnostic.
- QA stays pending, or a row fails again after its rework → keep the phase `In progress` (or `Blocked` with the reason), commit nothing, and report.
- `sassy-commit` fails or leaves the phase changes uncommitted → stop and report; never close out on top of uncommitted phase work.
- The validator returns **Blocked — insufficient grounding** → treat it as a real blocker; do not advance.
- Ambiguous or unsafe failure → stop and ask.
