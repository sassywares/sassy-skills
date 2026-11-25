---
title: Deleting a config surface is a sweep — the owning skill's write boundary, the one file that owns its rule, and the docs of how it degrades
category: skills
tags: [config, skills, references, single-source-of-truth, write-boundary, migration, worktree]
created: 2026-11-25
---

## Context

The worktree lifecycle was cut down to git mechanics: `up`, `down`, and
`hooks.worktree` were deleted, along with the assets and steps they named, and
the references (`sassy-setup/references/config.md`, `references/worktree.md`)
were rewritten to match. The code and the references agreed, and the change
looked complete.

It was not. Three separate places still described the old surface, each found by
reading the file next to the code rather than by running anything:

- `sassy-setup/SKILL.md` — the very skill whose run writes and commits the
  scaffold — still forbade writing the two files its own step 6 now writes, and
  its report step still told the user the lifecycle was "the two values `up` and
  `down`".
- The rule for a sequential multi-`remove` walk read "continue past a refusal" in
  `sassy-worktree/references/remove.md` and "stop at the first refusal" in
  `sassy-setup/references/worktree.md`. An agent obeying one destroys more
  checkouts than one obeying the other.
- The degradation story said an absent key "degrades with a loud warning", but a
  project that deletes `worktrees.create`/`remove` means it and the scripts stay
  silent. The code was right; the docs were wrong, and `--check` had no rule for
  the difference.

## Guidance

A config surface has more owners than the file it lives in. Before calling a
deletion done, sweep each kind:

- **The owning skill's body, not just its references.** `SKILL.md` holds the
  write boundary, the commit list, and the report — three places that name every
  surface by name. If a deleted key's files are still in the commit list, or its
  names still appear in the report, setup will commit or describe something that
  no longer exists. Read the body and the code side by side; the diff of a
  reference file will never show it.
- **One writer of a rule, the rest pointers.** Per `AGENTS.md`, a suite-wide rule
  has one owner — here `references/worktree.md` — which states it, while the
  executor's file (`sassy-worktree/references/remove.md`) keeps only its steps and
  a pointer ("`references/worktree.md` owns how the walk treats a refusal"). Two
  files stating the same rule do not converge; they drift into opposite outcomes,
  and both look authoritative to whoever reads only one.
- **A fallback with two causes needs the docs to say which is loud.** "Absent key
  → silent, declared-but-unusable → warn" is a rule about the user's intent, not
  about convenience: a key that isn't there was deleted on purpose. Write the
  intent into the schema (`references/config.md`), and let `--check` follow it —
  a declaration whose file is missing is a note, a malformed value is drift. One
  blanket sentence ("degrades with a loud warning") is how the code ends up right
  and the docs wrong, and the doc gets "fixed" into a regression.

## Applicability

Any skill that owns a config surface it also writes, scaffolds, commits, or
reports on — `sassy-setup` today, any future skill with a `write boundary` rule.
It also covers a rule that a suite reference and an executor both need: state it
once, in the reference the suite already treats as the owner, and make the other
file point. Not for a key that lives entirely inside one file with one reader;
there the surface has one owner and no sweep is needed.
