# Mode: remove — delete a checkout, keep its work reachable

Read the shared sections in `SKILL.md` first. This file is the remove path only.

1. **Run `.sassywares/worktree/remove <slug>`.** It refuses first — dirty, unpushed, the main checkout — before it stops anything.
2. **Then, in this order:** a top-level `down:` naming a script is run by the script itself, in the checkout; a `down:` naming a skill is not, so it joins the hooks in the exit-3 handshake. That exit is the handshake, not an error to route around: it lists every obligation still owed in one round — that `down`, and every declared `hooks.worktree.before_remove` — so dispatch them all, one `worker` per hook briefed with the `WT_*` block and that the checkout is about to go (drop the derived database, shut the simulator), then re-run once with `--hook-ok`. That re-run skips a script `down` that already ran: it continues the same removal, so nothing is stopped twice. A `down:` whose value is path-shaped but has no executable in the checkout is a mistake, not a skill, and `remove` refuses naming both the value and the checkout.

   A generated stub exits `78` to mean **unimplemented**. `remove` warns loudly, names the `down:` key, and removes anyway; any other non-zero status aborts before the handshake. Drop the key if nothing needs stopping, or implement the stub.
3. **Say what survives.** `remove` deletes the checkout; the **branch stays**, so the work is still reachable. Naming that stops someone assuming the deletion took their commits with it.
4. **Give a refusal verbatim and stop.** Dirty tree, unpushed commits, the main checkout: each is a real reason, and `--force` is the user's call, never yours. On success say which path went.

| Rule | Requirement |
|------|-------------|
| The branch outlives the checkout | Say that the branch survived. A removal the user reads as a data loss is a removal that gets skipped next time. |
| A refusal is information | Give dirty, unpushed, or main-checkout verbatim. Never route around `--hook-ok`, and never clear the objection yourself. |
