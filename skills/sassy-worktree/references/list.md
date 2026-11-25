# Mode: list — the table, as it prints

Read the shared sections in `SKILL.md` first. This file is the list path only. `list` is the default because it is the only mode that changes nothing.

1. Run `.sassywares/worktree/list` and present it as it prints — branch, worktree, dirty, upstream, state. Never summarise the table away: the columns are the answer. A non-zero exit means the state cannot be read: report its message and stop; never guess a state.
2. Paths in the table are shortened to `~`. `--path <slug>` prints the real absolute path, which is what you hand a user who wants to open the checkout in an editor.
3. A row's upstream is what the branch tracks, or `—` when nothing. An empty upstream is normal for a branch cut here; an upstream that is not the branch's own name is worth pointing at.
4. **Read the state column.** The definitions live in the `sassy-setup` skill's `references/worktree.md`; say what the row shows instead of guessing.
5. `--env <slug|branch>` prints the same four `WT_*` lines `create` printed, for scripting — `references/worktree.md` owns it. An ambiguous name — two branches can slug to one — is an error naming every match, never a first pick.
6. Only managed checkouts appear. Anything else found under the worktrees directory is counted in a footer, never listed as if it were ours.

| Rule | Requirement |
|------|-------------|
| The table is the answer | A prose summary of the table throws away the column the user needed. Print it, then add at most one sentence. |
