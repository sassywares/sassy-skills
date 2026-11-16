# Mode: check — verify an existing setup, write nothing

Read the shared sections in `SKILL.md` first, including steps 7–9. This file is only what a check run does differently: it enters at step 7 and never runs steps 1–6.

1. **Enter at step 7.** No detection, no questions, no config write: a folder that is already wired is verified, never rebuilt from detection. Run `scripts/detect.sh --root <path> --check` exactly as step 7 says, and report every `drift:` line verbatim, or that the config matches the tree.
2. **Report the scope you found.** Check the skills and the agents exactly as step 5's **Installed** rules say, and report the scope each was found in or what is missing. **Check installs nothing** — a missing suite or roster is reported with the fix, and it does not block step 8.
3. **Commit only dirty setup-owned files.** Step 8 applies only when something setup already owns is uncommitted — an edited config, a scaffold nobody committed, a pin that drifted — and only when step 7 is clean. Nothing dirty, nothing to commit.
4. **Report as step 9 says,** then name what closes each finding: the drift line, the missing scope, and the mode that fixes it.

A check run never edits the config, never installs a skill or an agent, never rewrites the tree, and never scaffolds a recipe. A check that "just fixes it while it is there" has become an unapproved `init`.

| Rule | Requirement |
|------|-------------|
| Check reports, init repairs | Every finding is reported with `mode:init` as its fix. Nothing is corrected in place, approved or not. |
| No detection | A check compares the file to the tree; it never re-derives the config from the tree and calls the difference drift. |
