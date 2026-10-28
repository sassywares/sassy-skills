---
name: sassy-review
description: >-
  Review a diff, branch, PR, or files for bugs, regressions, security,
  project-rule conformance, and design-system conformance, then fix the findings
  you pick. Runs the reviewer and fixes through sassy-cycle. mode:manual
  (default) asks which to fix, mode:auto fixes all actionable, mode:return only
  reports. Use when asked to review code. Leaves changes uncommitted.
argument-hint: "[PR ref, branch, files, or blank for current changes] [mode:manual|auto|return]"
disable-model-invocation: true
---

# Sassy Review

**Outcome:** the scope reviewed with concrete findings, and — unless `mode:return` — the chosen ones fixed and verified; everything left uncommitted.

**Review only.** Simplification is `sassy-simplify`; plan conformance is `sassy-validate`.

**Orchestrator only.** Never edit code yourself. The `reviewer` finds; `sassy-cycle` fixes and verifies.

**Harness.** Loading another skill, dispatching an agent, and any command you hand the user follow the `sassy-setup` skill's `references/harness.md`. Read it once per run, before the first of those.

## Modes

| Mode | Behavior |
|------|----------|
| `mode:manual` (default) | Present the findings, ask which to fix, fix those. |
| `mode:auto` | Fix every Critical and Warning without asking; Suggestions are reported, not fixed. |
| `mode:return` | Return the findings and change nothing — for a caller that owns the fix. |

Use the mode the caller passed; never pick one yourself.

## Review dimensions

The `reviewer` covers the first three always, and each risk lens when the diff touches its surface.

| Dimension | What it checks |
|-----------|----------------|
| Correctness & security | Bugs, regressions, injection, auth gaps, data loss; behavior changed with no test changed. |
| Project rules | Nearest `AGENTS.md`/`CLAUDE.md` at repo root and in each touched package, plus conventions they reference: required validators/auth, forbidden or gated commands, typing, naming, file placement, generated files. |
| Design system | Shared components and tokens instead of hardcoded colors/spacing/typography, required variants and states, accessibility, responsive/RTL, i18n, approved icons and assets. |
| Risk lenses | Security, data migrations, API contracts, concurrency and reliability — only where the diff touches them. |

Findings must be grounded: every rule finding quotes the rule file and section; every design finding names the shared component, token, or system pattern the code bypasses. A dimension with no applicable surface is reported as not applicable, not padded. Issues already handled elsewhere, or not introduced by the diff, are dropped. If the change knowingly departs from a rule, ask for the reason or a docs update instead of assuming it is fine.

## Workflow

1. **Scope.** Use the target the user named (PR, branch, or files), else the current diff against the base branch.
2. **Review.** Dispatch the `reviewer` on that scope.
3. **Return.** In `mode:return`, return the reviewer's output as-is and stop.
4. **Nothing actionable?** If there are no Critical or Warning findings, report the summary plus the rules/design-system check list and stop.
5. **Choose.** In `mode:manual`, present findings grouped Critical / Warnings / Suggestions, including the rules and design-system check list, and ask which to fix: critical only / all actionable / specific / none. In `mode:auto`, take every Critical and Warning.
6. **Fix.** Load the `sassy-cycle` skill on rework with the chosen findings and the reviewed files as the scope hint. Its verify step confirms each one resolved, with at most two fix passes.
7. **Report.** What was fixed, what is still open and why; leave it uncommitted.

## Hard rules

| Rule | Requirement |
|------|-------------|
| Orchestrator only | Never edit code. The `reviewer` finds, `sassy-cycle` fixes. |
| Ask first | In `mode:manual`, never change code before the user picks. |
| Specific findings | Fix the reviewed findings, not unrelated code. |
| Grounded findings | Rule and design-system findings cite the rule file, shared component, or token they rest on. |
| Uncommitted | Never commit, push, or open a PR. |

## Failure handling

The cycle returns a finding open after two passes → report it with its reason and continue with the rest. Stop on an unsafe or ambiguous failure.
