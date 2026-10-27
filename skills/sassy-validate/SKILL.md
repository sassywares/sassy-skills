---
name: sassy-validate
description: >-
  Check whether implemented work matches what a plan or stated intent expected,
  then offer to close the gaps. Runs the validator, asks before changing
  anything, and applies approved work via the worker. Use when asked to verify
  conformance to a plan or intent. Leaves changes uncommitted.
argument-hint: "[plan path + phase, or the intent to validate against]"
disable-model-invocation: true
---

# Sassy Validate

**Outcome:** a grounded conformance judgment against an intent; the approved gaps closed; everything left uncommitted.

**Orchestrator only.** Never edit code yourself. The `validator` finds gaps; the `worker` closes them.

**This skill needs an intent.** Validation without something to validate against is meaningless. If the user gave no plan path or intent, ask for one before doing anything.

**Harness.** Loading another skill, dispatching an agent, and any command you hand the user follow the `sassy-setup` skill's `references/harness.md`. Read it once per run, before the first of those.

## Workflow

1. **Intent.** Resolve the reference: a plan path plus phase (preferred), or an explicit intent the user states. If neither exists, ask and stop.
2. **Validate.** Dispatch the `validator` with that intent reference.
3. **Conforms?** If the grade is `Conforms`, report it and stop.
4. **Confirm.** If `Partial` or `Diverges`, present the `Gaps` and ask whether to close them (all / specific / none). If `Blocked — insufficient grounding`, report what it needs and stop — do not guess.
5. **Close.** Dispatch one `worker` with the approved gaps as its brief: implement exactly those, and nothing else.
6. **Report.** What was closed and what remains; leave it uncommitted. Offer to re-validate to confirm.

## Hard rules

| Rule | Requirement |
|------|-------------|
| Intent required | Never validate without a plan phase or explicit intent. |
| Orchestrator only | Never edit code. The `validator` judges, the `worker` implements. |
| Ask first | Never change code before the user approves. |
| Gap-bound | Implement only the approved gaps. |
| Uncommitted | Never commit, push, or open a PR. |

## Failure handling

The grade is `Blocked — insufficient grounding` → treat it as a real blocker; report exactly what it asked to inspect and stop. The `worker` cannot close a gap safely → report it as open.
