---
name: sassy-debug
description: >-
  Diagnose a bug to root cause, get approval for the proposed fix, then fix it
  through sassy-cycle (fix, simplify, review, validate), and finally ship it
  through sassy-ship after code approval. Never auto-commits. Use when asked to
  debug or fix a failure.
argument-hint: "[issue reference, error message, test path, or description] [mode:review|pipeline]"
disable-model-invocation: true
---

# Sassy Debug

Find the root cause of a failure, get approval for the fix, fix it through the shared quality cycle, then ship it only after code approval. **This skill never commits on its own.**

**Modes.** `mode:review` (default) keeps every approval gate, including the ship review gate. `mode:pipeline` forwards to `sassy-ship` and skips its approval gates.

**Done when:** the full causal chain is stated with `file:line` evidence, the fix gate was answered, the fix has passed the quality cycle, and either the user has approved shipping or the run ended at the fix gate with a handoff or brainstorm.

**Escalate rather than persist:** 2–3 hypotheses exhausted without confirmation, or 3 failed fix attempts, means diagnose *why* instead of trying again. One hypothesis, one change at a time — never shotgun-debug.

## Phase 0 — Triage

Establish the exact input, the observed symptom, the expected behavior, and how to reproduce it. If an issue/ticket is given, carry its identifier and URL through to the end. If only a stack trace or description is given, there is no issue of record — that is fine; never manufacture one.

Trivial bugs whose cause is readable from the input may skip the diagnoser, but still state the causal chain and pass the fix gate before changing code, then run the fix through `sassy-cycle`.

## Phase 1 — Diagnose

Dispatch the `diagnoser` subagent with the triage brief: exact input, symptom, expected behavior, reproduction, and any issue reference. It is read-only and returns the reproduction, full causal chain, root cause, proposed fix, files/tests, risks, and confidence.

Use its evidence as the diagnosis. If the chain has a gap, send one targeted follow-up to the same agent; do not redo the investigation in the main context. The main context owns the final judgment and presents it at the fix gate.

## Phase 2 — Fix gate

Stop before changing any code. Present only:

- the causal chain
- the fix, including the files and tests it touches
- the risks

Then ask: **fix now / handoff / brainstorm**.

This gate is mandatory even when the original request said "fix the bug". Do not edit code, dispatch `sassy-cycle`, or apply a one-line fix until the user chooses **fix now**.

- **fix now** → continue to Phase 3.
- **handoff** → load `sassy-handoff` with the root-cause chain and proposed fix, then stop.
- **brainstorm** → load `sassy-plan` with the issue and root-cause context, then stop.

## Phase 3 — Fix via `sassy-cycle`

Load the `sassy-cycle` skill and follow it, with:

- work brief = "Fix the root cause: <causal chain>. Apply the smallest change; add or strengthen the regression test first."
- intent reference = the diagnosis from Phase 1
- scope hint = the files the fix touches

This runs fix → simplify → review → validate → fix findings, all in subagents. Do **not** commit.

## Phase 4 — Code approval gate

Leave everything uncommitted. Present the result: the causal chain, the fix, the quality result (validator grade, reviewer findings), and the files changed. Wait for the user's approval. Do **not** commit before approval.

## Phase 5 — Ship via `sassy-ship`

On code approval, load the `sassy-ship` skill and follow it. Ship defaults to `mode:review`, which presents a shipping summary and waits; pass `mode:pipeline` through only when the user supplied it. Never toggle the mode yourself. It compounds any learnings, commits, opens or updates the PR, and babysits it via `sassy-babysit`. Babysit options (`merge:on|off`, `delete-branch:on|off`) are forwarded through `sassy-ship`. Run only the steps the user approves.

If the fix gate ended in **handoff** or **brainstorm**, this skill stops there — never commit.

## Summary (always write first)

```text
## Debug Summary
Problem: [what was broken]
Root Cause: [full causal chain, with file:line]
Recommended Tests: [tests to add/modify]
Fix: [what changed — or the next step chosen at the fix gate]
Confidence: [High/Medium/Low]
```

## Secrets

Debugging shows raw output constantly. Keep credentials in env vars, never on the command line. When output may contain a secret, capture it to a file and show only sanitized excerpts with `<REDACTED>`. No secret appears in anything shown, written, or committed.
