# Mode: check — verify an existing setup, write nothing

Read the shared sections in `SKILL.md` first, including steps 7–9. This file is only what a check run does differently: it enters at step 7 and never runs steps 1–6.

1. **Enter at step 7.** No detection, no questions, no config write: a folder that is already wired is verified, never rebuilt from detection. Run `scripts/detect.sh --root <path> --check` exactly as step 7 says, and report every `drift:` line verbatim, or that the config matches the tree — plus any `template:` note, which is not drift (see below).
2. **Report the scope you found.** Check the skills and the agents exactly as step 5's **Installed** rules say, and report the scope each was found in or what is missing. **Check installs nothing** — a missing suite or roster is reported with the fix, and it does not block step 8.
3. **Commit only dirty setup-owned files.** Step 8 applies only when something setup already owns is uncommitted — an edited config, a scaffold nobody committed, a pin that drifted — and only when step 7 is clean. Nothing dirty, nothing to commit.
4. **Report as step 9 says,** then name what closes each finding: the drift line, the missing scope, and the mode that fixes it.

A check run never edits the config, never installs a skill or an agent, never rewrites the tree, and never scaffolds a recipe. A check that "just fixes it while it is there" has become an unapproved `init`.

| Rule | Requirement |
|------|-------------|
| Check reports, init repairs | Every finding is reported with `mode:init` as its fix, except the template note, whose fix is the explicit `--sync --write` merge. Nothing is corrected in place, approved or not. |
| No detection | A check compares the file to the tree; it never re-derives the config from the tree and calls the difference drift. |

## What the template note means

A config can match the tree and still be behind the shipped template: a block, a
key, a comment layer, or a commented example that a later version added is
missing, so the next reader gets a thinner file than [`config.md`](config.md)
documents. `--check` prints it as a note — `template: --sync --write would add
worktrees, dogfood and refresh the comments (values the check accepts stay)` —
and still exits 0. It is never drift: every value the file declares is valid.

The fix is `bash scripts/detect.sh --root <path> --sync --write`, which merges
the template onto the file. It keeps the line of every leaf the check accepts —
value and same-line trailing comment, byte for byte — so a project's
`"*": main  # confirmed: …` stays exactly as written, and takes every block,
key, comment, and example the file lacks from the proposal. A malformed value is
not accepted, so it is replaced, the same judgement the check makes. Without
`--write` it is a dry run that prints the merged file and writes nothing; a
second run reports `already current` and touches nothing.

Report the note and the command; run the sync only when the user asks, the same
as every other repair.

## What a worktree finding means

`worktrees.create` and `worktrees.remove` are the project's own files, so a check
never hashes them and never treats them as suite-owned. Five outcomes:

- **Declared and executable** — a note naming the path. Nothing to do.
- **Declared but missing or not executable** — a note, never drift:
  `worktrees.create 'scripts/worktrees/create' is missing or not executable — the built-in .sassywares/worktree/create is used instead`. Report it so the user can restore the file or drop the key.
- **A wrong shape** — whitespace, an absolute or `~/` path, `..`, a list, or a
  block — is drift: `--check` names the key and the value, and the fix is one
  relative path with no arguments.
- **No `sassywares:scaffold` header** — a note naming the file: it carries no
  header, so the run cannot tell whether it prints the `WT_*` block. Provenance,
  never drift.
- **A legacy key** — `up:`, `down:`, or `hooks.worktree` — a `drift:` line that
  names the key, says the lifecycle moved into the project's create/remove
  scripts, and gives the exact edit (delete the `up:`/`down:` line, or the
  `worktree:` block under `hooks`). The fix is `mode:init` and only when the user
  asks for it; a check never deletes the key itself.

A scaffold header's `version=` is provenance, not a pin, so an old scaffold
version is never drift — [`scaffold-header.md`](scaffold-header.md).
