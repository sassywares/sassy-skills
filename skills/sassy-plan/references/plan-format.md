# Plan file format

Read this before writing the plan file.

## The file name

The filename is the plan's identity: `<artifacts.plans>/<type>-<slug>.md` for a standalone plan, whose `<type>-` prefix matches the frontmatter `type`; a goal slice is `<NN>-<slice-slug>.md`, and its slug carries no type.

- **`type`** is one of `feat fix chore refactor docs test perf ci build` — the Conventional Commit type the work will ship as — and a standalone plan's filename prefix must equal the frontmatter `type`.
- **`slug`** is lowercase ASCII kebab, 2–3 words (ceiling 5), naming the thing that changes, never the activity: `worktree-cut`, not `cutting-the-worktree-half`.
- **No date, no `-plan` suffix, no phase numbers.** The date is frontmatter, because a filename must survive a revision, and a rename breaks every reference to it (`sassy-work <plan>`, hook briefs, `goal.md`'s Plan links).
- **Never overwrite another plan.** Two concurrent plans on the same object take a qualifier (`-phase-two`), never a timestamp.
- **A caller passing `out:<path>` owns the name.** Slice plans stay `NN-<slice-slug>.md`, and the caller's path wins over every rule here.

## The frontmatter

Keys, in this order: `type`, `created`, and `updated` are required; `qa` is optional.

- **`type`** — matches the filename prefix and names the commit type the work will ship as. For a standalone plan the prefix must equal it; for a slice plan it equals the parent `goal.md`'s `type`, which the caller passes.
- **`created`** — `YYYY-MM-DD`, the day the plan was first written; never changes.
- **`updated`** — `YYYY-MM-DD`; a revision sets it to today in the same edit, and every executor that writes a phase status or a QA row result bumps it too.

**`qa`** is a gate switch, not a record of mode. Write `qa: off` only when the user asked for a plan with no QA gates at all, which also means no QA tables anywhere in the file; omit the key otherwise, and the QA gate is on. Never write `on`, `auto`, or `manual`. A check's mode lives only in the row `Mode` column, where rows freely mix `Auto` and `Manual`.

Slice plans add `goal` (relative path to the parent `goal.md`) and `slice` (the slice ID, e.g. `S1`).

The H1 title stays: frontmatter does not render on GitHub, so the heading is what a reader sees.

## No open questions

The plan has no open-questions section. Every branch the interview found is a decision, a deferred item, or an assumption — copy the ledger as it stood at the confirmed read-back. If you find an open branch while writing, stop and ask it before the file lands.

## Phase splitting rules

1. **Vertical first.** Prefer "ship a thin slice of feature X across all its layers" over "do all the database, then all the API, then all the UI".
2. **One goal per phase.** If naming the goal needs two sentences, split the phase.
3. **Follow-ups are new phases.** Polish, edge cases, and the next user journey get their own phase even if they touch the same files.
4. **Readable.** 3–8 phases for a typical feature. Merge only when a split leaves a phase with no meaningful thing to verify.
5. **No dump sections.** Anything executable lives under a phase. No giant task list outside the phases.

## Review — the phase's change tier

Every phase names the depth of quality work it needs with a `**Review:**` line. The executor passes it to `sassy-cycle`, which runs that tier's agents.

- **`logic`** — core code and anything that can change runtime behavior: product source, UI and styles, schemas and migrations, public contracts, behavior-changing config. Simplifier + reviewer + validator, then one fix pass.
- **`surface`** — everything that is not core code: docs, Markdown, comments, copy/i18n strings, tests, fixtures, formatting. Reviewer only, then one fix pass.
- **`none`** — machine-generated or mechanical: lockfiles, generated or vendored files, formatter churn, mass renames. No review; the worker's own checks are the record.

Default to `logic` when unsure. The tier is a declaration, not a trap: a `surface` phase that turns out to touch core code is promoted to `logic` by the executor, so declaring it optimistically costs nothing. The template shows `logic`; a missing line is read as `logic`.

## QA — part of the gate

Every phase gets a QA table. Each row's `Mode` is `Auto` or `Manual`, and the choice is not a preference:

- **`Manual` is the default.** Write each row so a person can run it without reading code — what to set up, what to do, and what passing looks like.
- **`Auto` needs two things**: the project's `dogfood.enabled` is `true` (per the `sassy-setup` skill's `references/dogfood.md`) **and** the row names a recipe section whose `**Prove it:**` names a step. One without the other stays `Manual`. A section whose `**Prove it:**` says `none` has no machine verdict by design — its rows are `Manual`, and writing `Auto` against it is a gate that proves nothing.
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

The user may ask in plain language for a plan with no QA gates, in which case omit every `#### QA — P<NN>` subsection and set `qa: off` in the frontmatter. An executor runs a QA gate unless that key says `off`.

## Plan file format

```markdown
---
type: feat
created: YYYY-MM-DD
updated: YYYY-MM-DD
---

# <Plan title>

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

**Review:** logic

**Work (vertical):**
- Database: …
- Backend: …
- Frontend: …
- Tests/config: …

Omit empty layers. Do not put the next goal's work here. The `**Review:**` line follows the work: a phase with any core-code layer is `logic`; a docs, copy, test, or fixture phase is `surface`; generated or formatter-only churn is `none`.

**Done when:** Plain-language acceptance for this phase only.

#### QA — P1 (Auto)

| ID | Check | Mode | Status | Notes |
|----|-------|------|--------|-------|
| P1-Q1 | Searching "wool socks" returns matching products | Auto (catalog) | Pending | |
| P1-Q2 | The empty state reads well | Manual | Pending | |

### P2 — <short goal name>
…
```

`qa: off` is added to the frontmatter only for a gate-free plan.

Every phase has at least one QA row. Status values there are `Pending` | `Done` | `Blocked`: a `Manual` row is `Done` once the user ran that check and confirmed it passed, an `Auto` row is `Done` once a dogfood run passed and its run id is in `Notes`, `Blocked` carries a note saying what failed, and anything unreported stays `Pending`. The frontmatter's `qa: off` is the only thing that removes the gate for executors; its absence leaves the gate on.
