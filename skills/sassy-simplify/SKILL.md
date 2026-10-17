---
name: sassy-simplify
description: >-
  Find and apply simplifications to recently changed code while preserving
  behavior. Runs the simplifier to report opportunities, asks before changing
  anything, then applies the approved ones via the worker. Use when asked to
  simplify, clean up, or reduce complexity. Leaves changes uncommitted.
argument-hint: "[files, diff, or blank for current changes]"
disable-model-invocation: true
---

# Sassy Simplify

**Outcome:** simplification opportunities found; the approved ones applied; everything left uncommitted.

**Orchestrator only.** Never edit code yourself. The `simplifier` finds; the `worker` does.

## Workflow

1. **Scope.** Use the target the user named, else the current uncommitted changes.
2. **Find.** Dispatch the `simplifier` in **report-only** mode:
   > Identify simplification opportunities in <scope> that preserve behavior exactly. Do **not** edit any files. Return a numbered list: `file:line` — what to simplify and why.
3. **Nothing?** If the list is empty, report "nothing to simplify" and stop.
4. **Confirm.** Present the list and ask which to apply: all / specific numbers / none.
5. **Apply.** Dispatch one `worker` with the approved items as its brief: apply exactly those, preserve behavior, run the relevant tests.
6. **Report.** What changed; leave it uncommitted. Offer to re-run the simplifier to confirm.

## Hard rules

| Rule | Requirement |
|------|-------------|
| Orchestrator only | Never edit code. The `simplifier` finds, the `worker` applies. |
| Ask first | Never change code before the user approves. |
| Behavior preserved | Simplification only — no functional changes. |
| Scope-bound | Touch only the agreed scope. |
| Uncommitted | Never commit, push, or open a PR. |

## Failure handling

The `worker` fails or breaks behavior → report it, leave the changes as they are, and stop. Do not layer another fix without the user.
