# Plan file format

Read this before writing the plan file.

## No open questions

The plan has no open-questions section. Every branch the interview found is a decision, a deferred item, or an assumption — copy the ledger as it stood at the confirmed read-back. If you find an open branch while writing, stop and ask it before the file lands.

## Phase splitting rules

1. **Vertical first.** Prefer "ship a thin slice of feature X across all its layers" over "do all the database, then all the API, then all the UI".
2. **One goal per phase.** If naming the goal needs two sentences, split the phase.
3. **Follow-ups are new phases.** Polish, edge cases, and the next user journey get their own phase even if they touch the same files.
4. **Readable.** 3–8 phases for a typical feature. Merge only when a split leaves a phase with no meaningful thing to verify.
5. **No dump sections.** Anything executable lives under a phase. No giant task list outside the phases.

## QA — manual, and part of the gate

Manual QA is the default: each phase gets a QA table with `Mode: Manual` fixed. Write each row so a person can run it without reading code — say what to set up, what to do, and what passing looks like. Suggest checks from the phase goal (happy path, edge, regression) but the user may edit them later.

QA is a completion gate, not a separate track: a phase turns `Done` only when the code is approved and every QA row for that phase passes. The user runs the rows and the agent records them; an agent never ticks its own row.

The user may ask in plain language to omit QA tables for this plan, in which case omit the tables and the `**QA:**` line entirely.

## Plan file format

```markdown
# <Plan title>

**QA:** manual

## Intent
One short paragraph: what we are building and why.

## Decisions
- D1: … (user-directed, over <alternative>: <reason>)
- D2: … (from code: `path/to/file.ts:12`)

Every decision carries its provenance from the interview ledger.

## Constraints
Anything that must not change, non-goals, and risks. (Omit if none.)

## Deferred
- F1: … (user-deferred — <when or by whom>)
- F2: … (implementation-time — <what only the code will answer>)

(Omit if none.)

## Assumptions
- A1: … (user-delegated)

Items the user handed to the agent's recommendation, or left open when they ended the interview. (Omit if none.)

## Phase tracking

| Phase | Goal | Status |
|-------|------|--------|
| P1 | … | Pending |
| P2 | … | Pending |

Status values: `Pending` | `In progress` | `Blocked` | `Done`

`Done` on a phase means its code was approved and every QA row for it is `Done`.

## Phases

### P1 — <short goal name>

**Goal:** One sentence. The only main goal for this phase.

**Why this slice:** One sentence on the tracer bullet (end-to-end for this goal).

**Work (vertical):**
- Database: …
- Backend: …
- Frontend: …
- Tests/config: …

Omit empty layers. Do not put the next goal's work here.

**Done when:** Plain-language acceptance for this phase only.

#### QA — P1 (Manual)

| ID | Check | Mode | Status | Notes |
|----|-------|------|--------|-------|
| P1-Q1 | … | Manual | Pending | |
| P1-Q2 | … | Manual | Pending | |

### P2 — <short goal name>
…
```

Every phase has at least one QA row. Status values there are `Pending` | `Done` | `Blocked`: `Done` means the user ran that check and confirmed it passed, `Blocked` carries a note saying what failed, and anything unreported stays `Pending`. The `**QA:**` line near the title is the source of truth for executors.
