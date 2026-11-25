---
title: Give every frontmatter key a writer and a reader, or make it a date-less switch that disappears when unused
category: skills
tags: [frontmatter, plan-format, goal-format, qa-gate, naming, single-source-of-truth]
created: 2026-11-26
---

## Context

The suite had grown four pieces of plan and goal metadata whose ownership was
never settled. A plan carried `**QA:** auto` next to the title, while every
per-phase QA row already carried its own `Mode` column; `updated` existed on
`goal.md` but no mode was told to write it; a slice plan had no machine-readable
link back to its goal; and a goal's Conventional Commit type lived only in prose,
so branch naming could not read it. The result was metadata that was declared
and then ignored, or duplicated with a second copy that could disagree.

## Guidance

A key is only real if something writes it and something reads it. Test each key
in both directions before shipping it:

- **A writer** — exactly which steps set it, named in the doc that owns the
  format. `sassy-goal`'s `write`, `next`, `check`, and `close` are each named as
  setting `updated`; `sassy-plan` and the executors `sassy-work` / `sassy-lfg`
  are named as bumping it when they edit a plan in place.
- **A reader** — the step that acts on the value. A slice plan's `goal` and
  `slice` are written by `sassy-goal` `mode:next` and read by `sassy-ship` to
  tell a goal slice from a standalone plan (the directory convention surviving
  only as a fallback). A goal's `type` has a full chain: `goal.md` frontmatter →
  the slice plan's frontmatter → the branch prefix that `sassy-setup`'s
  `branching.md` derives, which the `NN-<slice-slug>.md` filename cannot supply.
- **One owner per fact.** The old `**QA:** auto|manual` line restated what the
  row `Mode` column already decided, and a plan mixing `Auto` and `Manual` rows
  made the line untruthful by construction — it could not be "the source of
  truth for executors" and agree with the tables at the same time. It was
  replaced by `qa: off` alone: absence means the gate is on, and the per-row
  `Mode` is the only place a check's mode lives. A flag whose value is derivable
  from data the document already holds is a second source of truth, not a
  setting.
- **Prefer a switch with one meaningful value.** `qa: off` is a key that exists
  only to be absent otherwise: no `on`, no `auto`, no `manual`. Nothing can
  disagree with it, and deleting the key restores the default without a
  migration. If a key needs a symmetric pair (`on`/`off`) to make sense, it is
  probably recording state that something else already owns.

### The corollary: a name is identity, a date is metadata

The same test applies to the filename, which is a field no frontmatter parser
sees. A plan filename is a reference target — `sassy-work <plan>`, hook briefs,
and `goal.md`'s Plan links all point at it — so it carries only identity:
`<type>-<slug>.md`, or `NN-<slice-slug>.md` for a slice. The date moved into
`created` / `updated`, because a rename breaks every reference at once, while
frontmatter survives a revision and a re-cut. Uniqueness comes from a qualifier
(`-phase-two`), never a timestamp, for the same reason: `hooks.goal` keys on the
goal's folder name, prefix included, so a timestamp in that name leaks into
every hook entry and breaks on rename.

## Applicability

Any document format the suite defines — plan, goal, handbook, learning. It does
not apply to keys that exist purely for a human reader, such as the H1 title,
which stays in the body because frontmatter does not render on GitHub. A key
with no reader is dead weight; a key with two writers or two owners is a future
contradiction.
