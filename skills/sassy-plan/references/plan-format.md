# Plan file format

Read this before writing the plan file.

## Phase splitting rules

1. **Vertical first.** Prefer "ship a thin slice of feature X across all its layers" over "do all the database, then all the API, then all the UI".
2. **One goal per phase.** If naming the goal needs two sentences, split the phase.
3. **Follow-ups are new phases.** Polish, edge cases, and the next user journey get their own phase even if they touch the same files.
4. **Readable.** 3–8 phases for a typical feature. Merge only when a split leaves a phase with no meaningful thing to verify.
5. **No dump sections.** Anything executable lives under a phase. No giant task list outside the phases.

## QA — manual by default

Manual QA is the default: each phase gets a QA table with concrete checks and `Mode: Manual` fixed. Suggest checks from the phase goal (happy path, edge, regression) but the user may edit them later.

The user may ask in plain language to omit QA tables for this plan, in which case omit the tables and the `**QA:**` line entirely.

## Plan file format

```markdown
# <Plan title>

**QA:** manual

## Intent
One short paragraph: what we are building and why.

## Decisions
- D1: …
- D2: …

## Constraints
Anything that must not change, non-goals, and risks. (Omit if none.)

## Phase tracking

| Phase | Goal | Status |
|-------|------|--------|
| P1 | … | Pending |
| P2 | … | Pending |

Status values: `Pending` | `In progress` | `Blocked` | `Done`

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

Every phase has at least one QA row. Status values there are `Pending` | `Done` | `Blocked`. The `**QA:**` line near the title is the source of truth for executors.
