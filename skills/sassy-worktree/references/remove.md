# Mode: remove — delete a checkout, keep its work reachable

Read the shared sections in `SKILL.md` first. This file is the remove path only.

1. **Dispatch `before_remove` first**, one `worker` per declared entry, briefed with the `WT_*` block and that the checkout is about to go. Its job is the project's cleanup: drop the derived database, shut the simulator.
2. **Run `.sassywares/worktree/remove <slug> --hook-ok`.** Without `--hook-ok` it exits `3` by design when a hook is declared — that exit is the handshake, not an error to route around.
3. **Say what survives.** `remove` deletes the checkout and its port claim; the **branch stays**, so the work is still reachable. Naming that stops someone assuming the deletion took their commits with it.
4. **Report a refusal verbatim and stop.** Dirty tree, unpushed commits, a live preview, the main checkout: each is a real reason, and `--force` is the user's call, never yours. On success report the released port and the removed path.

| Rule | Requirement |
|------|-------------|
| The branch outlives the checkout | Report that the branch survived. A removal the user reads as a data loss is a removal that gets skipped next time. |
| A refusal is information | Report dirty, unpushed, or live-preview verbatim. Never route around `--hook-ok`, and never clear the objection yourself. |
