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

## QA — part of the gate

Every phase gets a QA table. Each row's `Mode` is `Auto` or `Manual`, and the choice is not a preference:

- **`Manual` is the default.** Write each row so a person can run it without reading code — what to set up, what to do, and what passing looks like.
- **`Auto` needs two things**: the project's `dogfood.enabled` is `true` (per the `sassy-setup` skill's `references/dogfood.md`) **and** the row names a recipe section that carries a `Prove it:` step. One without the other stays `Manual`. An `Auto` row with no check behind it is a gate that proves nothing.
- An `Auto` row names the recipe **section**, never a command. Commands belong in the recipe; copied into a row they rot one row at a time.

A row stays `Manual` when the answer is genuinely a human's:

| The check is… | Because |
|---|---|
| subjective | "does this look right", "does this feel intuitive", "is this the right product decision" |
| physical or sensory | audio, haptics, camera, mic, a real device, a push to a real phone |
| irreversible or third-party | payments, mail actually sent, shared or staging data touched |
| unobservable | no artifact an agent can inspect |
| unprovable | no check exists yet |

On doubt, `Manual`. A false `Auto` pass is unrecoverable; a `Manual` row is merely slower.

**An `Auto` check must have been seen failing once** — break the thing, watch the check fail, restore it — before the row is recorded. A check nobody has watched fail is not a check.

QA is a completion gate, not a separate track: a phase turns `Done` only when the code is approved and every QA row for that phase passes. `Manual` rows belong to the user, and the agent records what it hears. `Auto` rows are settled by a `sassy-dogfood` run and its report, never by an opinion.

The user may ask in plain language to omit QA tables for this plan, in which case omit the tables and the `**QA:**` line entirely.

## Plan file format

```markdown
# <Plan title>

**QA:** auto

(`auto` when at least one row in the plan is `Auto`, `manual` when none is. It is the source of truth for executors, so it never disagrees with the tables.)

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

#### QA — P1 (Auto)

| ID | Check | Mode | Status | Notes |
|----|-------|------|--------|-------|
| P1-Q1 | Searching "wool socks" returns matching products | Auto (catalog) | Pending | |
| P1-Q2 | The empty state reads well | Manual | Pending | |

### P2 — <short goal name>
…
```

Every phase has at least one QA row. Status values there are `Pending` | `Done` | `Blocked`: a `Manual` row is `Done` once the user ran that check and confirmed it passed, an `Auto` row is `Done` once a dogfood run passed and its run id is in `Notes`, `Blocked` carries a note saying what failed, and anything unreported stays `Pending`. The `**QA:**` line near the title is the source of truth for executors.
