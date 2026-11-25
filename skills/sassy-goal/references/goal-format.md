# Goal file format

Read this before writing or revising `goal.md`.

## Layout

A goal is a folder under `artifacts.plans`:

```text
<artifacts.plans>/<type>-<slug>/
├── goal.md               # this format
├── 01-<slice-slug>.md    # S1's plan, written by sassy-plan when S1 starts
└── 02-<slice-slug>.md    # S2's plan, written when S2 starts
```

The folder name is `<type>-<slug>`, and that whole name is the key `hooks.goal` uses in the project config — prefix included: `hooks.goal.feat-powersync`. The `slug` alone is the part after the `<type>-`.

- **`type`** is one of `feat fix chore refactor docs test perf ci build` — the Conventional Commit type the goal will ship as. `mode:next` passes it into each slice plan's frontmatter, and `branching.md` reads it there to name the slice branch, so the chain runs goal → slice plan → branch.
- **`slug`** is lowercase ASCII kebab, 2–3 words (ceiling 5), naming the thing that changes, never the activity. It is the folder name minus its `<type>-` prefix.
- **Unique.** Two goals on the same object take a qualifier (`-phase-two`), never a timestamp, because the folder name is the `hooks.goal` key.
- **Undated.** A date in the folder name would land in every `hooks.goal` entry and break when the goal is renamed.

Slice plans keep `NN-<slice-slug>.md` (written via `out:`). `NN` is the slice's order and matches its ID: `S1` → `01-`, `S2` → `02-`. A slice plan is an ordinary sassy plan, so `sassy-work`, `sassy-lfg`, `sassy-ship`, and `sassy-validate` run on it unchanged.

## Frontmatter

Required keys, in this order, and nothing else:

- **`type`** — one of the list above, matching the folder prefix.
- **`status`** — `active` | `done`.
- **`created`** — `YYYY-MM-DD`, the day the goal was first written; never changes.
- **`updated`** — `YYYY-MM-DD`; set to today on every material revision, in the same edit. `mode:write`, `mode:next`, `mode:check`, and `mode:close` all set it whenever they edit the file.

The H1 title stays: frontmatter does not render on GitHub, so the heading is what a reader sees.

## Rules

- **No open questions.** Like a plan, the goal has no open-questions section. Every goal-level branch is a decision, a constraint, a deferred item, or an assumption.
- **Goal level only.** Decisions here are the ones that bind more than one slice. Anything one slice can settle alone is deferred to that slice's grill.
- **Slices stay surface level.** A slice outline says what ships and how you know; its plan says how. Never write phases, QA rows, or file-by-file work into `goal.md`.
- **Every slice ships something complete.** A slice that leaves a half-built layer — a schema nobody reads, an API nobody calls — is not a slice. Re-cut it until each one ships a working outcome on its own.
- **Carry-forward is append-only.** One entry per checked slice, added by `mode:check`, never edited afterward. Later slices read it as settled ground; a correction is a new entry.
- **Done slices are history.** A revision never re-cuts, renumbers, or rewrites a `Done` slice or its plan.

## Slice statuses

| Status | Set by | Meaning |
|---|---|---|
| `Pending` | `mode:write` | Outlined; no plan yet |
| `Planned` | `mode:next` | Plan written; work not shipped |
| `Shipped` | `sassy-ship` | Close-out committed and PR open |
| `Done` | `mode:check` | Checked against its plan; every gap fixed, deferred, or accepted |
| `Blocked` | any mode | Cannot proceed; the Plan cell or a note says why |

Order: `Pending` > `Planned` > `Shipped` > `Done`. Only one slice is ever `Planned` or `Shipped` at a time.

## Template

```markdown
---
type: feat
status: active
created: YYYY-MM-DD
updated: YYYY-MM-DD
---

# <Goal title>

## Intent
One paragraph: the outcome when the whole goal lands, and why it is worth a multi-slice effort.

## Done when
Goal-level acceptance — what `mode:close` checks against the whole tree.
- G1: … (e.g. every screen reads from the local database)
- G2: … (repo-wide checks too, e.g. "no imports of the HTTP client remain")

## Decisions
Cross-slice decisions only, each with provenance from the interview ledger.
- D1: … (user-directed, over <alternative>: <reason>)
- D2: … (from code: `path/to/file.ts:12`)

## Constraints
Non-goals and anything that must not change.

## Landscape
Per domain: what changes, where, and the blast radius.

| Domain | What changes | Where | Blast radius |
|---|---|---|---|
| Sync | … | `src/sync/client.ts:40` | … |

## Risks
Known issues, unknowns, and spikes, each with the slice that retires it.

## Coexistence
How the app runs mid-goal: what old and new run side by side, which flags gate what, and when each is removed.

## Slice tracking

| ID | Slice | Ships | Depends | Plan | Status |
|----|-------|-------|---------|------|--------|
| S1 | … | … | — | — | Pending |
| S2 | … | … | S1 | — | Pending |

The Plan cell holds the plan link once written, and the PR link once `mode:check` records it: `[plan](01-slug.md) · [PR](<url>)`.

## Slices

### S1 — <short name>

**Ships:** One sentence: the complete outcome a user or the system has when this merges.

**Scope:** The domains and areas it touches, surface level.

**Done when:** Plain-language acceptance for this slice only.

### S2 — <short name>
…

## Carry-forward
Append-only. One entry per checked slice, added by `mode:check`.

### S1 — <date>
- **Changed vs plan:** …
- **New decisions / constraints:** … (they bind later slices)
- **Impact on later slices:** S3 — …
- **Gaps:** deferred to S2 — …; accepted — … (reason)

## Deferred
- F1: … (user-deferred — to S3's grill)

## Assumptions
- A1: … (user-delegated)
```

Omit Risks, Deferred, or Assumptions only when empty. Carry-forward starts empty with its one-line note.
