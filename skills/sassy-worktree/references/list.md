# Mode: list — the table, as it prints

Read the shared sections in `SKILL.md` first. This file is the list path only. `list` is the default because it is the only mode that changes nothing.

1. Run `.sassywares/worktree/list` and present it as it prints — branch, worktree, how to see it, live, last verdict. Never summarise the table away: how to see it is the point.
2. Paths in the table are shortened to `~`. `--path <slug>` prints the real absolute path, which is what you hand a user who wants to open the checkout in an editor.
3. `--preview <slug>` prints how to see one checkout, and `--address <slug>` its URL — from its claimed port, or the one its preview line names. Use the script; never assemble an address yourself.
4. Only managed checkouts appear. Anything else found under the worktrees directory is counted in a footer, never listed as if it were ours.

| Rule | Requirement |
|------|-------------|
| The table is the answer | A prose summary of the table throws away the column the user needed. Print it, then add at most one sentence. |
