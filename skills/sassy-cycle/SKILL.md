---
name: sassy-cycle
description: >-
  Run one unit of work through a tiered quality loop using subagents: implement,
  then simplify + review + validate for logic changes, review for surface
  changes, or nothing for mechanical ones, fix once, and return. No verify pass.
  Also reworks existing work from a list of findings (failed QA rows, a
  standalone review's picks, PR threads, goal gaps). Used by sassy-work, sassy-lfg,
  sassy-review, sassy-simplify, sassy-validate, sassy-babysit, and sassy-goal.
  Never commits. Built for
  context and token efficiency — the orchestrator only writes briefs and reads
  compact results.
argument-hint: "<work brief | findings> [review:logic|surface|none] [intent reference]"
---

# Sassy Cycle

**Outcome:** one unit of work implemented, reviewed at the depth its change tier needs, every finding fixed in one work pass, and a compact structured result returned to the caller. This skill never commits, pushes, or ships.

**Tiered, not uniform.** The change decides which quality agents run:

- **`logic`** — core code and anything that can change runtime behavior. The `simplifier`, `reviewer`, and `validator` run in parallel.
- **`surface`** — everything that is not core code: docs, Markdown, comments, copy/i18n strings, tests, fixtures, formatting. The `reviewer` alone.
- **`none`** — machine-generated or mechanical: lockfiles, generated or vendored files, formatter churn, mass renames. No quality agent.

**No verify pass.** After the quality agents report, one worker applies the findings and that is the last step. The cycle never re-reviews the fix. A finding left open is reported, not looped on.

**Subagent-maximal by design.** The orchestrator (the main context) must never read source files, diffs, or the tree. Every heavy read happens inside a subagent with its own isolated context window. The orchestrator only writes briefs and reads compact structured results. This is what keeps the caller's context small across many phases.

**Harness.** Loading another skill, dispatching an agent, and any command you hand the user follow the `sassy-setup` skill's `references/harness.md`. Read it once per run, before the first of those.

## Inputs

- **Work brief** — what to build or fix, concretely.
- **Intent reference** — how conformance is judged: a plan path + phase, or root-cause findings. Optional; without one the validator is skipped.
- **Scope hint** — files or areas, optional.
- **Review tier** — `logic`, `surface`, or `none`. Callers pass the plan phase's `**Review:**` line or a `review:` token. When neither exists, step 3 detects it from the work's own report; when the report cannot decide, the tier is `logic`.
- **Findings** — rework only: fixes to work that already exists — failing QA rows, a standalone skill's picked findings, PR threads, goal gaps. Each is a **fix** unless the caller marks it a **simplification**. Given findings, skip steps 1–5 and start at step 6 with the findings as its lists.

A change the user asks for at a gate is **not** a finding. It is new work: the caller runs a new cycle with that change as the work brief, so tier detection, review, and one fix pass apply to it like any other unit.

## Worker brief constraints

Every worker brief this cycle dispatches — implement and fix — carries:

- Tests only for the files the worker changed and the existing tests that directly regress them. The full suite runs once at the final gate.
- A hard timeout around long-running commands, for example `timeout 300 bunx vitest run path/to/file.test.ts`; a hung command is killed and reported.
- Stop and report a blocker to the orchestrator after one failed retry, with the exact command and error, instead of looping on the same failure.
- Report the files it changed and state `Runtime behavior: yes` or `Runtime behavior: no` — whether the change alters what the product does for a user. Running the product in a test or tooling does not count.
- For a **simplification**: behavior stays identical — same output for every input, same errors, same side effects and ordering. Never remove validation, error handling that prevents data loss, authorization, escaping, or accessibility code to make something simpler, and never weaken a test to make it pass. A simplification that cannot meet that is skipped and reported with the reason.

## Steps

1. **Recon (optional).** If the work is large or its location is unclear, run `sassy-scout` first and pass the grounding brief path into the work brief. Skip when the brief is already precise.
2. **Implement.** Dispatch a `worker` with the work brief, the intent reference, and the plan path if there is one, carrying the worker brief constraints above. For independent chunks, batch them as **parallel** `worker` tasks in one call (max 8). The worker reads whatever it needs itself.
3. **Resolve the tier.** An explicit tier from Inputs wins, unless the work contradicts it: a `surface` or `none` unit whose files include a core-code path is promoted to `logic`. Never demote. The worker's `Runtime behavior: yes` is not a promotion on its own — tests, fixtures, and tooling often exercise runtime behavior without changing it. Without an explicit tier, classify from the worker's file report:
   - any core-code path → `logic`
   - only human-authored docs, copy, comments, tests, fixtures, or tooling → `surface`
   - only generated, vendored, lock, or formatting files → `none`
   - mixed surface and generated files → `surface`; the human-authored part decides
   - anything else → `logic` if the worker reported `Runtime behavior: yes`, otherwise `surface`.

   Core code is what ships and runs: product source, UI and styles, schemas and migrations, public contracts, and behavior-changing config. Report the resolved tier as `declared`, `detected`, or `promoted` in the result.
4. **Quality (by tier).** Dispatch in one **parallel** call where the tier has more than one agent:
   - `logic` — the `simplifier`, the `reviewer`, and, when there is an intent reference, the `validator`. Give the validator the intent reference so it can judge conformance; give the simplifier the plan path, if there is one, so settled structure stays.
   - `surface` — the `reviewer` alone, briefed: *surface change — docs, copy, comments, tests, or fixtures. Apply correctness and project-rule conformance; skip the design-system dimension and risk lenses unless the change touches UI or runtime code. Do not pad.*
   - `none` — no agent; go to step 7 as `done`.
5. **Triage.** Two lists, both numbered:
   - **Fixes** — every reviewer **critical** and **warning**, every validator gap, and every blocker a worker reported.
   - **Simplifications** — every simplifier finding.

   Reviewer **Suggestions** are neither: carry them to the result untouched for the caller's gate. Both lists empty → step 7.
6. **Fix once.** Dispatch one `worker` with both lists, labeled, to do exactly those and nothing else, carrying the worker brief constraints above. On rework, the findings are the lists. The worker reports each item `fixed`, `applied`, or `not fixed` / `skipped` with a reason. This is the only fix pass: never verify it, never dispatch a second fix inside this run.
7. **Return** the structured result below.

## Structured result

Return this to the caller, compactly:

```text
Status: done | blocked
Tier: logic | surface | none (declared | detected | promoted) | rework
Files changed: <paths>
Work passes: 1 | 2
Findings: <finding -> fixed | open: reason>
Simplifications: <finding -> applied | skipped: reason | open: reason>
Suggestions: <reviewer suggestions, not acted on>
Validator: Conforms | Partial | Diverges | Blocked | not run
Reviewer: <n> critical, <n> warnings | not run
Notes: <anything the caller needs>
```

`Status` is `blocked` only when the work or the fix could not run (a worker blocker, an unresolved critical the worker reports it cannot fix, or a failed dispatch). `Findings` and `Simplifications` are the fixing worker's report; this cycle does not re-review them. `Tier` and its source tell the caller what depth ran.

## Rules

| Rule | Requirement |
|------|-------------|
| Orchestrator only | Never edit code or read source in the main context. Delegate. |
| Tier decides agents | `logic` → simplifier + reviewer + validator (validator only with an intent reference); `surface` → reviewer; `none` → none. |
| One fix pass, no verify | At most one work pass after the quality agents. Never re-review the fix. |
| Never demote | A declared `surface` or `none` promotes to `logic` only when the changed files include core code. |
| Parallel where independent | Independent work chunks → parallel workers. The tier's quality agents run in one parallel call. |
| Only fixes block | Simplifications are applied or reported but never make a run `blocked`; reviewer suggestions go to the caller's gate for the user to pick and are never applied automatically. |
| Simplifier runs once | Only at the `logic` tier. It never runs on rework. |
| Gate changes are new work | A change the user asks for at a gate runs as a new cycle with that change as the work brief; it is never a findings rework. |
| Never commit | This skill leaves everything uncommitted. Shipping is `sassy-ship`. |
| QA stays the caller's | Never mark a QA row `Done`, `Manual` or `Auto`. A `Manual` row is confirmed by the user at the caller's gate and an `Auto` row by a passing dogfood report; failing rows come back as findings. |

## Context and token discipline

- Pass only the brief and the intent reference to subagents; the subagent reads the code, not the orchestrator.
- Keep the intent reference terse — a plan path plus a phase, or a short findings list.
- Never paste file contents or subagent transcripts through the orchestrator; summarize.
- Prefer one worker with a good brief over a tour of the tree in the main context.
- A `surface` or `none` unit is cheap on purpose: do not add agents the tier does not name. If the work turns out to touch core code, promote it at step 3 instead of widening the brief.
