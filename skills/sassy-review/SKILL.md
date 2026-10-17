---
name: sassy-review
description: >-
  Review a diff, branch, PR, or files for bugs, regressions, and quality, then
  offer to fix the findings. Runs the reviewer, asks before changing anything,
  and applies approved fixes via the worker. Use when asked to review code.
  Leaves changes uncommitted.
argument-hint: "[PR ref, branch, files, or blank for current changes]"
disable-model-invocation: true
---

# Sassy Review

**Outcome:** the scope reviewed with concrete findings; the approved fixes applied; everything left uncommitted.

**Orchestrator only.** Never edit code yourself. The `reviewer` finds; the `worker` fixes.

## Workflow

1. **Scope.** Use the target the user named (PR, branch, or files), else the current diff against the base branch.
2. **Review.** Dispatch the `reviewer` on that scope.
3. **Nothing actionable?** If there are no Critical or Warning findings, report the summary and stop.
4. **Confirm.** Present findings grouped Critical / Warnings / Suggestions, and ask which to fix: critical only / all actionable / none.
5. **Fix.** Dispatch one `worker` with the selected findings as its brief: fix exactly those, keep the change minimal, run the relevant tests.
6. **Report.** What was fixed and what was left; leave it uncommitted. Offer to re-review to confirm.

## Hard rules

| Rule | Requirement |
|------|-------------|
| Orchestrator only | Never edit code. The `reviewer` finds, the `worker` fixes. |
| Ask first | Never change code before the user approves. |
| Specific findings | Fix the reviewed findings, not unrelated code. |
| Uncommitted | Never commit, push, or open a PR. |

## Failure handling

The `worker` cannot fix a finding safely → report that finding as open and continue with the rest. Stop on an unsafe or ambiguous failure.
