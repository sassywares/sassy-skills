---
name: sassy-debug
description: >-
  Diagnose a bug to root cause, get approval for the proposed fix, then fix it
  through sassy-cycle (fix, review, validate), and finally ship it
  through sassy-ship after code approval. Never auto-commits. Use when asked to
  debug or fix a failure.
argument-hint: "[issue reference, error message, test path, or description] [branch:infer|current|new]"
disable-model-invocation: true
---

# Sassy Debug

Find the root cause of a failure, get approval for the fix, fix it through the shared quality cycle, then ship it only after code approval. **This skill never commits on its own.**

**Done when:** the full causal chain is stated with `file:line` evidence, the fix gate was answered with one of its four options, and either the fix has passed the quality cycle and shipped after code approval, or the run ended at the fix gate.

**Config.** Resolve `.sassywares/config.yaml` (nearest, walking up) per the `sassy-setup` skill's `references/config.md`. `commit.branch` decides whether the fix needs its own branch; `sassy-work` makes that decision when the fix starts, because the branch belongs to the work and not to the diagnosis.

**Escalate rather than persist:** 2–3 hypotheses exhausted without confirmation, or 3 failed fix attempts, means diagnose *why* instead of trying again. One hypothesis, one change at a time — never shotgun-debug. Before escalating, re-search the prior learnings with the keywords of what you just ruled out: an exhausted hypothesis list is often a documented trap.

**Harness.** Loading another skill, dispatching an agent, and any command you hand the user follow the `sassy-setup` skill's `references/harness.md`. Read it once per run, before the first of those.

## Phase 0 — Triage

Establish the exact input, the observed symptom, the expected behavior, and how to reproduce it. If an issue/ticket is given, carry its identifier and URL through to the end. If only a stack trace or description is given, there is no issue of record — that is fine; never manufacture one.

Trivial bugs whose cause is readable from the input may skip the scout, but still state the causal chain and pass the fix gate before changing code, then run the fix through `sassy-cycle`.

**Search prior learnings first.** Resolve `.sassywares/config.yaml` (nearest, walking up) per the `sassy-setup` skill's `references/config.md`. For every existing path in `knowledge.read`, search the docs for the symptom's keywords, the module, and the failure type. A matching doc **seeds or confirms** a hypothesis — it never replaces the causal chain or the reproduction. Name the docs you consulted, and say plainly when none matched: no match is not evidence that nothing similar has happened.

## Phase 1 — Diagnose inline, with `scout` as a helper

You own the diagnosis. The causal reasoning happens here, in the main context, because that is where the full picture lives and where the fix gate is presented.

Dispatch `scout` as a **helper**, not as the diagnostician, with the triage brief: exact input, symptom, expected behavior, reproduction, any issue reference, and the files or areas you suspect. It grounds the area and returns a gist plus the path to its grounding brief.

Then do the diagnosis yourself:

- Read the gist and the brief. Reproduce the failure before explaining it.
- Form one hypothesis at a time and confirm it with a targeted read, a targeted `scout` follow-up, or a failing test. State the chain trigger → symptom with `file:line` evidence.
- Send at most one scoped follow-up per gap. Never hand the whole investigation back to a subagent, and never re-scout the repo.

If the chain still has a gap after that, say so at the fix gate and lower the confidence rather than guessing.

**Then offer the next step, exactly as before:** the fix gate below asks whether to fix it now, write a plan, hand it off, or stop at the diagnosis.

## Phase 2 — Fix gate

Stop before changing any code. Present the causal chain, the proposed fix with the files and tests it touches, and the risks. Then present exactly this menu and stop until the user picks. Do not recommend one.

```text
Pick one:
1. Fix it now — smallest change, regression test first, stop before ship
2. Write a plan — take this diagnosis into sassy-plan
3. Hand off — continue in a fresh session
4. Stop here — diagnosis only
```

This gate is mandatory even when the original request said "fix the bug". Do not edit code, dispatch `sassy-cycle`, or apply a one-line fix before the user picks.

### Option 1 — Fix it now

Load the `sassy-work` skill with the fix brief as the work brief and the diagnosis from Phase 1 as the intent reference, forwarding this run's `branch:` token if it was given. Work runs one cycle, presents its own code approval gate, commits, and stops before ship.

The branch decision belongs to work, not to this phase: diagnosis writes nothing, so cutting a branch before the fix gate would leave an empty branch every time the gate ends in *Write a plan*, *Hand off*, or *Stop here*. Work resolves it per `sassy-setup`'s `references/branching.md` before it touches code, so the fix is on its own branch from the first edit and still never lands on a base branch.

Continue to Phase 3.

### Option 2 — Write a plan

Load the `sassy-plan` skill with the issue and the root-cause context. Plan runs its discussion and ends in its own three-option picker; the diagnosis carries into the plan so the discussion does not re-derive it.

### Option 3 — Hand off

Load the `sassy-handoff` skill in `mode:write` with the root-cause chain and proposed fix, then stop.

### Option 4 — Stop here

Report the diagnosis and stop. Nothing is committed.

## Phase 3 — Fix via `sassy-cycle`

Runs only after the user picked **Fix it now** at the fix gate. Load the `sassy-cycle` skill and follow it, with:

- work brief = "Fix the root cause: <causal chain>. Apply the smallest change; add or strengthen the regression test first."
- intent reference = the diagnosis from Phase 1
- scope hint = the files the fix touches

This runs fix → review → validate → fix findings, all in subagents. Do **not** commit.

## Phase 4 — Code approval gate

Leave everything uncommitted. Present the result: the causal chain, the fix, the quality result (validator grade, reviewer findings), and the files changed. Wait for the user's approval. Do **not** commit before approval.

## Phase 5 — Ship via `sassy-ship`

On code approval, load the `sassy-ship` skill and follow it, leaving ship's default `mode:manual` review gate in place. Do not pass a mode yourself. Ship presents its shipping summary and waits. It compounds any learnings, commits, opens or updates the PR, and babysits it via `sassy-babysit` (under `commit.branch: current` it commits and pushes the checked-out branch instead, with no PR, hooks, or babysit). Babysit options (`merge:on|off`, `delete-branch:on|off`) are forwarded through `sassy-ship`. Run only the steps the user approves.

If the fix gate ended in **Write a plan**, **Hand off**, or **Stop here**, this skill stops there — never commit.

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
