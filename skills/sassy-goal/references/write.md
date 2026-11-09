# Mode: write — grill and write the goal

**Documents only.** This mode writes or revises `goal.md`. It never writes a slice plan, cuts a branch, edits code, or commits.

## New goal (the argument is an idea)

1. **Frame.** Restate the goal in one or two sentences — the outcome and why it needs more than one plan. Ask the user to confirm or correct it, and what they are already thinking.
2. **Ground once, broadly.** Use `sassy-scout` on every domain the goal touches, in one run. Its brief feeds Landscape — what changes per domain, where (with `file:line` citations), and the blast radius — and seeds Risks and Coexistence. Do not re-scout per slice here; each slice's grill grounds its own detail.
3. **Grill, bounded to the goal.** Read the `sassy-plan` skill's `references/interview.md` and follow it — the ledger, one question per turn with your recommendation, pushback, the read-back — but walk only goal-level branches:
   - the domains in scope, and the non-goals
   - slice boundaries and their order (Depends)
   - coexistence: how the app runs mid-goal, old and new side by side, which flags
   - the goal's Done when, including repo-wide checks (e.g. "no HTTP client imports left")
   - decisions that bind more than one slice

   Anything a single slice can settle alone — UI states, a table's columns, a helper's shape — goes to Deferred as *to S<n>'s grill*, with the user's agreement. Run the coverage sweep only against these goal-level rows; the rest are N/A until their slice starts.
4. **Push back on incomplete slices.** Every slice must ship a working outcome on its own. A "schema first, API next, UI last" cut is the half-built layer this skill exists to prevent: challenge it with the evidence and offer a vertical re-cut (e.g. "one screen end to end on the new store"). Concede only to an argument or the user's explicit call, and record that call as `user-directed`.
5. **Read back.** The whole ledger — decisions, constraints, the slice list with Ships / Depends, deferred items, assumptions — with an empty Open bucket. A correction reopens that branch.
6. **Write.** Read `references/goal-format.md` and write `<artifacts.plans>/<goal-slug>/goal.md` with `**Status:** Active`, every slice `Pending`, and an empty Carry-forward.

## Existing goal (the argument is a goal folder or `goal.md`)

1. Read `goal.md`. If its status is `Done`, say so and stop unless the user asks to reopen it.
2. Ask what changed, then grill **only the delta** with the same protocol: re-cut, add, drop, or reorder slices, or change a goal-level decision, Done-when item, or constraint. Everything else already in `goal.md` is settled ground.
3. Keep history intact. `Done` slices, their plans, and every Carry-forward entry stay exactly as written. A `Planned` or `Shipped` slice is in flight: changing it is a contradiction to raise with the user, never a silent edit. New slices take the next free ID, so existing plan filenames never move.
4. Apply the same pushback on incomplete slices, read back the delta, then update `goal.md` in place.

## End

Report the absolute path of `goal.md`, the slice table, and the next command in the harness's syntax:

```text
Goal written to <absolute path>. Start the first slice:
/sassy-goal <goal path> mode:next
```

Stop there. Do not plan the first slice in this run.
