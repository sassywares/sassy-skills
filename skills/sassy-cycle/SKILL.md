---
name: sassy-cycle
description: >-
  Run one unit of work through the full quality loop using subagents: implement,
  review, validate, fix findings, re-check. Used by sassy-lfg,
  sassy-work, and sassy-debug. Never commits. Built for context and token
  efficiency — the orchestrator only writes briefs and reads compact results.
argument-hint: "<work brief> [intent reference]"
disable-model-invocation: true
---

# Sassy Cycle

**Outcome:** one unit of work taken through the full quality loop, findings fixed and re-checked, returning a compact structured result to the caller. This skill never commits, pushes, or ships.

**Subagent-maximal by design.** The orchestrator (the main context) must never read source files, diffs, or the tree. Every heavy read happens inside a subagent with its own isolated context window. The orchestrator only writes briefs and reads compact structured results. This is what keeps the caller's context small across many phases.

**Harness.** Loading another skill, dispatching an agent, and any command you hand the user follow the `sassy-setup` skill's `references/harness.md`. Read it once per run, before the first of those.

## Inputs

- **Work brief** — what to build or fix, concretely.
- **Intent reference** — how conformance is judged: a plan path + phase, or root-cause findings.
- **Scope hint** — files or areas, optional.

## Steps

1. **Recon (optional).** If the work is large or its location is unclear, run `sassy-scout` first and pass the grounding brief path into the work brief. Skip when the brief is already precise.
2. **Implement.** Dispatch a `worker` with the work brief, the intent reference, and the plan path if there is one. Every worker brief must also carry these constraints:
   - Tests only for the files the worker changed and the existing tests that directly regress them. The full suite runs once at the final gate.
   - A hard timeout around long-running commands, for example `timeout 300 bunx vitest run path/to/file.test.ts`; a hung command is killed and reported.
   - Stop and report a blocker to the orchestrator after one failed retry, with the exact command and error, instead of looping on the same failure.

   For independent chunks, batch them as **parallel** `worker` tasks in one call (max 8). The worker reads whatever it needs itself.
3. **Review + validate (parallel).** Dispatch the `reviewer` and the `validator` together in one **parallel** call. Give the validator the intent reference so it can judge conformance. Simplification opportunities belong in the reviewer's Suggestions, not a separate pass.
4. **Fix findings.** Collect every finding from steps 2–3. If any exist, dispatch one `worker` to fix exactly those findings.
5. **Re-check.** Re-run the `reviewer` and `validator` in parallel once.
6. **Return** the structured result below.

## Structured result

Return this to the caller, compactly:

```text
Status: done | blocked
Files changed: <paths>
Findings: <raised -> fixed | open>
Validator: Conforms | Partial | Diverges | Blocked
Reviewer: <n> critical, <n> warnings
Notes: <anything the caller needs>
```

## Rules

| Rule | Requirement |
|------|-------------|
| Orchestrator only | Never edit code or read source in the main context. Delegate. |
| Parallel where independent | Independent work chunks → parallel workers. Reviewer + validator always run in parallel. |
| One fix pass | One worker fix, one re-check. If findings remain after that → `blocked`. |
| Never commit | This skill leaves everything uncommitted. Shipping is `sassy-ship`. |
| Manual QA | Never mark QA rows `Done`. QA is confirmed by the user at the caller's gate; failing rows come back as findings. |

## Context and token discipline

- Pass only the brief and the intent reference to subagents; the subagent reads the code, not the orchestrator.
- Keep the intent reference terse — a plan path plus a phase, or a short findings list.
- Never paste file contents or subagent transcripts through the orchestrator; summarize.
- Prefer one worker with a good brief over a tour of the tree in the main context.
