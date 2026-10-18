---
name: sassy-lfg
description: >-
  Execute an entire sassy plan by delegating each phase to sassy-cycle, then
  close out via sassy-ship after the user approves. Also runs a settled
  in-context brief with `mode:pipeline`. The orchestrator only coordinates. Best for
  small plans that one context can hold.
argument-hint: "[path to sassy plan | in-context brief] [mode:document|pipeline] [qa:off] [code-approval:off]"
disable-model-invocation: true
---

# Sassy LFG

**Outcome:** every phase in the plan run through `sassy-cycle`, the whole change reviewed by the user at one gate, then `sassy-ship` closes it out (compound, handbook, commit, PR, babysit).

**The orchestrator does not do work.** Read the plan, dispatch `sassy-cycle` per phase, then `sassy-ship`. Never edit application code. Keep the main context small — all heavy work happens in subagents.

## Input

Take a sassy plan path. If none is given, run `sassy-plan` first and use the file it writes.

**Modes.** `mode:document` (default) works from a plan file. `mode:pipeline` consumes a settled in-context brief from `sassy-plan mode:pipeline` instead of a plan path.

**In-context mode (`mode:pipeline`).** When the caller passes `mode:pipeline`, the argument is a settled work brief, not a plan path. It is the entire phase: run one `sassy-cycle` from the brief without splitting it, stop at the review gate, then close out via `sassy-ship` on approval. Do not run `sassy-plan` and do not create a plan file. Never create a branch: work on the checked-out branch, and let `sassy-ship` handle branching at close-out.

**QA setting.** Read the plan's `**QA:**` line, or the context brief's `QA:` line. `manual` keeps the QA checklist and gate; `disabled` (`qa:off`) removes both. Never toggle QA on or off on your own.

**Code approval flag.** Take an optional `code-approval:manual` or `code-approval:off` (default `manual`). `manual` keeps the code approval gate; `off` removes it. Never toggle it on your own.

## Steps

1. **Load the plan.** Read the plan and its Phase tracking table.
2. **Run every phase, in order.** For each phase not `Done`:
   - Load the `sassy-cycle` skill and follow it, with work brief = the phase's goal/work/"Done when", and intent reference = the plan path and phase.
   - On `Status: done` and `Validator: Conforms`, mark the phase `Done`.
   - On `Status: blocked`, mark it `Blocked` and stop the run.
3. **Review gate.** After the last phase, report: the plan path, each phase's final status, what changed per phase, whether manual QA applies, and that the change is uncommitted. If code approval is manual, wait for the user's approval. If `code-approval:off`, report the same summary and continue without waiting. Do not commit.
4. **Close-out.** On code approval, or immediately when `code-approval:off`, load the `sassy-ship` skill and follow it. Do only the close-out steps the user approves. Babysit options (`merge:on|off`, `delete-branch:on|off`) are forwarded through `sassy-ship` to `sassy-babysit`.

### In-context mode (`mode:pipeline`)

When the caller passes `mode:pipeline`, there is no plan file and the brief is the one phase:

1. Run one `sassy-cycle` with the in-context brief as the work brief and its decisions / done-when as the intent reference. Do not split it into multiple phases.
2. Stop at the review gate and report. With manual QA, include the brief's `QA checks`; with `qa:off`, omit them and the QA gate. If code approval is manual, wait; with `code-approval:off`, continue without waiting.
3. On code approval, or immediately when `code-approval:off`, run `sassy-ship`. Do not run `sassy-plan` or write a plan file.

## Hard rules

| Rule | Requirement |
|------|-------------|
| Orchestrator only | Delegate every phase to `sassy-cycle`. Never read source or edit code. |
| Pipeline order | Phases run one after another, in plan order. |
| No shipping before code approval | The change stays uncommitted until the user approves the code, unless `code-approval:off`. Shipping is `sassy-ship`. |
| Manual QA | When QA is enabled, never mark QA rows `Done`. When `qa:off`, skip QA rows and gates. |
| No plan in `mode:pipeline` | Use the in-context brief; never create or update a plan file. |
| Compact context | Only pass briefs to subagents and keep only their summaries. |

## Failure handling

- A phase returns `blocked` → stop the run, report the open findings and diagnostic.
- The validator returns **Blocked — insufficient grounding** → stop; do not advance.
- Ambiguous or unsafe failure → stop and ask rather than guessing.
