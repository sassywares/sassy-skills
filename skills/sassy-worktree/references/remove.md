# Mode: remove — delete a checkout, keep its work reachable

Read the shared sections in `SKILL.md` first. This file is the remove path only.

1. **Name one checkout.** A slug or a branch is enough; `remove` accepts both. For a request like "remove the merged ones", run `list` first, confirm once, then run `remove` for each checkout in turn — see the last section.
2. **Resolve the project's remove script and run it once:**

   ```bash
   bash <sassy-setup skill>/scripts/detect.sh --root <project> --worktree-script remove
   <resolved-path> <slug|branch>
   ```

   The project script owns the order in one run, and `references/worktree.md` owns
   the steps and the slots. The skill runs that one command and does not sequence
   the steps itself.
3. **Give a refusal verbatim and stop.** The toolbox refuses before touching anything, and the project script passes that through:
   - `not clean — <n> path(s) modified. Commit, discard, or --force.`
   - `<n> commit(s) on '<branch>' are on no remote — push, or --force`
   - `that is the main checkout — it cannot be removed`

   Each is a real reason. `--force` is the user's call, never yours: it skips the dirty-tree and unpushed-commit checks **only**, never the main checkout. If a refusal leaves a checkout behind, that is the answer; never clear the objection yourself.

   **A non-zero exit names the stage that failed.** The stop step failing means nothing is deleted. A toolbox refusal means nothing is deleted and the tree is intact. A dispose step failing **after** the tree is gone means the checkout is gone and the resources may survive: report what is left and what to run, and never recreate the tree.
4. **Say what survives.** The checkout is gone; the **branch stays**, so the work is still reachable. Naming that stops someone assuming the deletion took their commits with it. Say which path went.

## Removing several checkouts

There is no bulk flag. The plain-language path is the only path:

1. Run `list` and show the table, states included.
2. Confirm the set once, naming the `merged` rows the user picked.
3. Run `remove <slug>` for each checkout, **sequentially**, one project-script run each.
4. Report each result and the count at the end; `references/worktree.md` owns how the walk treats a refusal.

| Rule | Requirement |
|------|-------------|
| The branch outlives the checkout | Say that the branch survived. A removal the user reads as a data loss is a removal that gets skipped next time. |
| A refusal is information | Give dirty, unpushed, or main-checkout verbatim. Never clear the objection yourself and never invent a flag to get past it. |
| One script run per checkout | Never loop inside the project's script or add a bulk mode. The sequential walk is the design. |
