---
name: sassy-validate
description: >-
  Check whether implemented work matches what a plan or stated intent expected,
  then close the gaps you pick. Runs the validator and closes gaps through
  sassy-cycle. mode:manual (default) asks which to close, mode:auto closes all,
  mode:return only reports. Use when asked to verify conformance to a plan or
  intent. Leaves changes uncommitted.
argument-hint: "[plan path + phase, or the intent to validate against] [mode:manual|auto|return]"
disable-model-invocation: true
---

# Sassy Validate

**Outcome:** a grounded conformance judgment against an intent, and — unless `mode:return` — the chosen gaps closed and verified; everything left uncommitted.

**Validate only.** Code quality and bugs are `sassy-review`; simplification is `sassy-simplify`.

**Orchestrator only.** Never edit code yourself. The `validator` finds gaps; `sassy-cycle` closes and verifies them.

**This skill needs an intent.** Validation without something to validate against is meaningless. If the user gave no plan path or intent, ask for one before doing anything.

**Harness.** Loading another skill, dispatching an agent, and any command you hand the user follow the `sassy-setup` skill's `references/harness.md`. Read it once per run, before the first of those.

## Modes

| Mode | Behavior |
|------|----------|
| `mode:manual` (default) | Present the gaps, ask which to close, close those. |
| `mode:auto` | Close every gap without asking. |
| `mode:return` | Return the grade and gaps and change nothing — for a caller that owns the fix. |

Use the mode the caller passed; never pick one yourself.

## Workflow

1. **Intent.** Resolve the reference: a plan path plus phase (preferred), or an explicit intent the user states. If neither exists, ask and stop.
2. **Validate.** Dispatch the `validator` with that intent reference.
3. **Return.** In `mode:return`, return the validator's grade, evidence, and gaps as-is and stop.
4. **Conforms?** If the grade is `Conforms`, report it and stop. If `Blocked — insufficient grounding`, report what it needs and stop — do not guess.
5. **Choose.** On `Partial` or `Diverges`, in `mode:manual` present the `Gaps` and ask which to close: all / specific / none. In `mode:auto`, take all.
6. **Close.** Load the `sassy-cycle` skill on rework with the chosen gaps as findings and the same intent reference. Its verify step re-runs the validator against that intent, with at most two fix passes.
7. **Report.** What was closed, what remains and why; leave it uncommitted.

## Hard rules

| Rule | Requirement |
|------|-------------|
| Intent required | Never validate without a plan phase or explicit intent. |
| Orchestrator only | Never edit code. The `validator` judges, `sassy-cycle` closes. |
| Ask first | In `mode:manual`, never change code before the user picks. |
| Gap-bound | Close only the chosen gaps. |
| Uncommitted | Never commit, push, or open a PR. |

## Failure handling

The grade is `Blocked — insufficient grounding` → treat it as a real blocker; report exactly what it asked to inspect and stop. The cycle returns a gap open after two passes → report it with its reason.
