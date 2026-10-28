---
name: sassy-simplify
description: >-
  Find behavior-preserving simplifications in changed code — reuse, quality,
  efficiency — then apply the ones you pick. Runs the simplifier and applies
  through sassy-cycle. mode:manual (default) asks which to apply, mode:auto
  applies all, mode:return only reports. Use when asked to simplify, tidy, or
  refactor recent changes. Leaves changes uncommitted.
argument-hint: "[files, branch, or blank for current changes] [mode:manual|auto|return]"
disable-model-invocation: true
---

# Sassy Simplify

**Outcome:** the scope's simplification findings, and — unless `mode:return` — the chosen ones applied with behavior unchanged and verified; everything left uncommitted.

**Simplify only.** Not a bug hunt — that is `sassy-review`. Not a plan check — that is `sassy-validate`.

**Orchestrator only.** Never edit code or read source yourself. The `simplifier` finds; `sassy-cycle` applies and verifies.

**Harness.** Loading another skill, dispatching an agent, and any command you hand the user follow the `sassy-setup` skill's `references/harness.md`. Read it once per run, before the first of those.

## Modes

| Mode | Behavior |
|------|----------|
| `mode:manual` (default) | Present the findings, ask which to apply, apply those. |
| `mode:auto` | Apply every finding without asking. |
| `mode:return` | Return the findings and change nothing — for a caller that owns the fix. |

Use the mode the caller passed; never pick one yourself.

## What it looks for

The `simplifier` covers three dimensions, all behavior-preserving:

| Dimension | What it checks |
|-----------|----------------|
| Reuse | New code that duplicates an existing helper, reimplements a standard-library primitive, or hand-maintains a guarantee a framework already provides. |
| Quality | Redundant state, parameter sprawl, near-duplicate code, leaky abstractions, raw strings where a constant exists, deep nesting, narrating comments, dead code. |
| Efficiency | Repeated or N+1 work, sequential calls that could run concurrently, hot-path bloat, unconditional updates, leaks, overly broad reads. |

Fewer lines is not the goal. A finding that would make code longer or harder to follow, change behavior, or remove a safety check is not a finding.

## Workflow

1. **Scope.** Use the target the user named (files, branch, or PR), else the current diff against the base branch. Nothing in scope → ask what to simplify and stop.
2. **Simplify.** Dispatch the `simplifier` on that scope, with the plan path if the caller gave one, so settled structure stays.
3. **Nothing to apply?** On `Nothing to simplify` or no findings, report that and stop.
4. **Return.** In `mode:return`, return the simplifier's findings as-is — files reviewed, findings by dimension, summary — and stop.
5. **Choose.** In `mode:manual`, present the findings grouped by dimension and ask which to apply: all / specific / none. In `mode:auto`, take all.
6. **Apply.** Load the `sassy-cycle` skill on rework with the chosen findings, each marked a **simplification**, and the scope's files as the scope hint. The cycle's worker keeps behavior identical and its verify step confirms each one.
7. **Report.** What was applied per dimension, what was skipped and why, and the checks the worker ran. Leave it uncommitted.

## Hard rules

| Rule | Requirement |
|------|-------------|
| Behavior is fixed | Same output for every input, same errors, same side effects and ordering. |
| Safety stays | Never remove validation, data-loss error handling, authorization, escaping, or accessibility code. |
| Tests stay | Never weaken an assertion or skip a test to make a simplification pass. |
| Ask first | In `mode:manual`, never change code before the user picks. |
| Orchestrator only | The `simplifier` finds; `sassy-cycle` applies. |
| Uncommitted | Never commit, push, or open a PR. |
