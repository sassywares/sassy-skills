# Mode: prune — sweep the checkouts that are safe to delete

Read the shared sections in `SKILL.md` first. This file is the prune path only.

1. Run `.sassywares/worktree/prune` with no flag and show the table.
2. Ask before removing. `--yes` removes only rows marked `removable`: merged into their upstream or whose upstream is gone, clean, fully pushed, not running, and no `before_remove` hook it would skip.
3. Rows with a declared hook are reported so the user can run `remove <slug>` instead and get the cleanup. Prune never skips a hook silently.
4. Report the counts — removed, left, and why each skipped row was skipped.

| Rule | Requirement |
|------|-------------|
| Only `removable` rows | The script's marking is the safety proof. Never extend `--yes` to a row it left out, and never prune by hand. |
| A skipped row says why | `merged`, `dirty`, `unpushed`, `live`, or `hook`: name it. A bare count leaves the user unable to tell a safe sweep from a stuck one. |
