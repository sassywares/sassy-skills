---
name: sassy-review
description: >-
  Review a diff, branch, PR, or files for bugs, regressions, quality, project-rule
  conformance, and design-system conformance, then offer to fix the findings. Runs
  the reviewer, asks before changing anything, and applies approved fixes via the
  worker. Use when asked to review code. Leaves changes uncommitted.
argument-hint: "[PR ref, branch, files, or blank for current changes]"
disable-model-invocation: true
---

# Sassy Review

**Outcome:** the scope reviewed with concrete findings; the approved fixes applied; everything left uncommitted.

**Orchestrator only.** Never edit code yourself. The `reviewer` finds; the `worker` fixes.

**Harness.** Loading another skill, dispatching an agent, and any command you hand the user follow the `sassy-setup` skill's `references/harness.md`. Read it once per run, before the first of those.

## Review dimensions

The `reviewer` covers all four. Do not drop any of them.

| Dimension | What it checks |
|-----------|----------------|
| Correctness & security | Bugs, regressions, injection, auth gaps, data loss. |
| Project rules | Nearest `AGENTS.md`/`CLAUDE.md` at repo root and in each touched package, plus conventions they reference: required validators/auth, forbidden or gated commands, typing, naming, file placement, generated files. |
| Design system | Shared components and tokens instead of hardcoded colors/spacing/typography, required variants and states, accessibility, responsive/RTL, i18n, approved icons and assets. |
| Quality | Duplication, clarity, dead code, maintainability. |

Findings must be grounded: every rule finding quotes the rule file and section; every design finding names the shared component, token, or system pattern the code bypasses. A dimension with no applicable surface is reported as not applicable, not padded. If the change knowingly departs from a rule, ask for the reason or a docs update instead of assuming it is fine.

## Workflow

1. **Scope.** Use the target the user named (PR, branch, or files), else the current diff against the base branch.
2. **Review.** Dispatch the `reviewer` on that scope across all four dimensions.
3. **Nothing actionable?** If there are no Critical or Warning findings, report the summary plus the rules/design-system check list and stop.
4. **Confirm.** Present findings grouped Critical / Warnings / Suggestions, including the rules and design-system check list, and ask which to fix: critical only / all actionable / none.
5. **Fix.** Dispatch one `worker` with the selected findings as its brief: fix exactly those, keep the change minimal, run the relevant tests.
6. **Report.** What was fixed and what was left; leave it uncommitted. Offer to re-review to confirm.

## Hard rules

| Rule | Requirement |
|------|-------------|
| Orchestrator only | Never edit code. The `reviewer` finds, the `worker` fixes. |
| Ask first | Never change code before the user approves. |
| Specific findings | Fix the reviewed findings, not unrelated code. |
| Grounded findings | Rule and design-system findings cite the rule file, shared component, or token they rest on. |
| Uncommitted | Never commit, push, or open a PR. |

## Failure handling

The `worker` cannot fix a finding safely → report that finding as open and continue with the rest. Stop on an unsafe or ambiguous failure.
