---
name: sassy-cycle
description: >-
  Run one unit of work through the full quality loop using subagents: implement,
  review + simplify + validate in parallel, then fix and verify findings — at
  most two fix passes. Also reworks existing work from a list of findings
  (requested changes, failed QA rows, a standalone review's picks). Used by
  sassy-work, sassy-lfg, sassy-review, sassy-simplify, and sassy-validate.
  Never commits. Built for context and token
  efficiency — the orchestrator only writes briefs and reads compact results.
argument-hint: "<work brief | findings> [intent reference]"
---

# Sassy Cycle

**Outcome:** one unit of work taken through the full quality loop, every finding fixed and verified fixed by a reviewer — or reported open after two fix passes — returning a compact structured result to the caller. This skill never commits, pushes, or ships.

**Subagent-maximal by design.** The orchestrator (the main context) must never read source files, diffs, or the tree. Every heavy read happens inside a subagent with its own isolated context window. The orchestrator only writes briefs and reads compact structured results. This is what keeps the caller's context small across many phases.

**Harness.** Loading another skill, dispatching an agent, and any command you hand the user follow the `sassy-setup` skill's `references/harness.md`. Read it once per run, before the first of those.

## Inputs

- **Work brief** — what to build or fix, concretely.
- **Intent reference** — how conformance is judged: a plan path + phase, or root-cause findings. Optional on rework only; without one, verify runs the reviewer alone.
- **Scope hint** — files or areas, optional.
- **Findings** — rework only: a list of changes to make to work that already exists — the user's requested changes, failing QA rows, a standalone skill's picked findings. Each is a **fix** unless the caller marks it a **simplification**. Given findings, skip steps 1–3 and start at step 4. The intent reference stays the original one, so the validator still judges the whole unit.

## Steps

1. **Recon (optional).** If the work is large or its location is unclear, run `sassy-scout` first and pass the grounding brief path into the work brief. Skip when the brief is already precise.
2. **Implement.** Dispatch a `worker` with the work brief, the intent reference, and the plan path if there is one. Every worker brief — here and in step 5 — must also carry these constraints:
   - Tests only for the files the worker changed and the existing tests that directly regress them. The full suite runs once at the final gate.
   - A hard timeout around long-running commands, for example `timeout 300 bunx vitest run path/to/file.test.ts`; a hung command is killed and reported.
   - Stop and report a blocker to the orchestrator after one failed retry, with the exact command and error, instead of looping on the same failure.
   - Report the files it changed.
   - For a **simplification**: behavior stays identical — same output for every input, same errors, same side effects and ordering. Never remove validation, error handling that prevents data loss, authorization, escaping, or accessibility code to make something simpler, and never weaken a test to make it pass. A simplification that cannot meet that is skipped and reported with the reason.

   For independent chunks, batch them as **parallel** `worker` tasks in one call (max 8). The worker reads whatever it needs itself.
3. **Review + simplify + validate (parallel).** Dispatch the `reviewer`, the `simplifier`, and the `validator` together in one **parallel** call. Give the validator the intent reference so it can judge conformance; give the simplifier the plan path, if there is one, so settled structure stays.
4. **Triage.** Two lists, both numbered:
   - **Fixes** — every reviewer **critical** and **warning**, every validator gap, every blocker a worker reported, and on rework every finding not marked a simplification.
   - **Simplifications** — every simplifier finding, and on rework every finding marked one.

   Reviewer **Suggestions** are neither: carry them to the result untouched for the caller's gate. Both lists empty → step 7.
5. **Fix.** Dispatch one `worker` with both lists, labeled, to do exactly those and nothing else. This is fix pass 1 or 2.
6. **Verify (parallel).** Dispatch the `reviewer` and, when there is an intent reference, the `validator` together, both scoped to this fix. The simplifier does not run again — a fresh pass would always find more.
   - **Reviewer** — both lists and the files the fix changed. It returns, per item, `resolved` or `not resolved` with a reason — for a simplification, `resolved` also means behavior is unchanged — plus any **new** critical or warning the fix's changes introduced. A simplification that changed behavior is a new finding.
   - **Validator** — the intent reference plus the fixes list. It re-grades conformance and names any gap left.

   The new fixes list is every unresolved fix, every new finding, and every validator gap; unresolved simplifications carry forward on their own list. Both empty → step 7 as `done`. Otherwise, after fix pass 1 → back to step 5; after fix pass 2 → step 7: `blocked` when fixes remain open, `done` when only simplifications do — they are reported, never blocking.
7. **Return** the structured result below.

## Structured result

Return this to the caller, compactly:

```text
Status: done | blocked
Files changed: <paths>
Fix passes: 0 | 1 | 2
Findings: <finding -> resolved (pass n) | open: reason>
Simplifications: <finding -> applied (pass n) | skipped: reason | open: reason>
Suggestions: <reviewer suggestions, not acted on>
Validator: Conforms | Partial | Diverges | Blocked
Reviewer: <n> critical, <n> warnings open
Notes: <anything the caller needs>
```

A finding is `resolved`, and a simplification `applied`, only when step 6's reviewer said so. The fixing worker's own report is never evidence.

## Rules

| Rule | Requirement |
|------|-------------|
| Orchestrator only | Never edit code or read source in the main context. Delegate. |
| Parallel where independent | Independent work chunks → parallel workers. Reviewer, simplifier, and validator run in one parallel call; verify's reviewer and validator likewise. |
| Two fix passes, verified | At most two fix → verify rounds per run. Every fix is verified by a reviewer scoped to that fix; anything still open after the second → `blocked`. Never loop further. |
| Only fixes block | Simplifications are applied and verified but never make a run `blocked`; reviewer suggestions go to the caller's gate for the user to pick and are never applied automatically. |
| Simplifier runs once | Only at step 3 (or never, on rework). Verify re-checks what was applied; it does not hunt for more. |
| Never commit | This skill leaves everything uncommitted. Shipping is `sassy-ship`. |
| Manual QA | Never mark QA rows `Done`. QA is confirmed by the user at the caller's gate; failing rows come back as findings. |

## Context and token discipline

- Pass only the brief and the intent reference to subagents; the subagent reads the code, not the orchestrator.
- Keep the intent reference terse — a plan path plus a phase, or a short findings list.
- Never paste file contents or subagent transcripts through the orchestrator; summarize.
- Prefer one worker with a good brief over a tour of the tree in the main context.
