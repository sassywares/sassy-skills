# Mode: next — plan the next slice

**One slice in flight.** This mode starts exactly one slice by planning it. It never implements, never plans a second slice, and never runs work or lfg itself.

1. **Start from a fresh base.** The slice's branch is cut later by `sassy-work` or `sassy-lfg`, and a run standing on a non-base branch would reuse it. Dispatch a probe `worker` to `git fetch` the remote, run the `sassy-setup` skill's `scripts/detect.sh --branch` (no `--policy`), and return `state`, `head`, and whether local `<head>` equals `<remote>/<head>`. `state` must be `on-base` and the two must match. `on-branch` (usually the previous slice's merged branch), `detached`, or a base behind or ahead of its remote → tell the user to switch to the base and pull, then stop. Under `commit.branch: current` this step does not apply.
2. **Load the goal.** Only now read `goal.md`. If its status is `Done`, say so and stop.
3. **Nothing in flight.** If any slice is `Planned` or `Shipped`, stop and name what is due: a `Planned` slice needs `sassy-work` or `sassy-lfg` on its plan, a `Shipped` slice needs `mode:check`.
4. **Earlier slices merged.** Every `Done` slice's PR must be merged before the next slice starts, or the new slice is built on code that may still change. Dispatch a `worker` to check each PR with `gh pr view <url> --json state` and return the states. Under `commit.branch: current`, `git.repo: workspace`, or `git.repo: none` — or when a slice has no PR link — ask the user to confirm instead. Anything unmerged → stop and say which PR must merge first.
5. **Pick the slice.** The first `Pending` slice whose Depends are all `Done`. A `slice:<ID>` token overrides the pick, but its Depends must still be `Done`; a slice that is not `Pending` is a stop. No eligible slice → if every slice is `Done`, point at `mode:close`; otherwise report what blocks each `Pending` slice and stop.
6. **Plan it.** Load the `sassy-plan` skill and follow it, with:
   - **frame** = the slice's Ships, Scope, and Done when from `goal.md`
   - **settled** = the goal's Decisions and Constraints, and every Carry-forward entry — enter them in the ledger as settled with their provenance; never re-ask them
   - **context** = the goal path, the goal's Landscape and Coexistence rows for this slice's domains, and the Deferred items addressed to this slice
   - **`out:<goal folder>/NN-<slice-slug>.md`**, with `NN` from the slice ID

   `sassy-plan` grills the slice in full — this is where its detail gets decided — writes the plan to that path, skips its picker, and returns the path.

   **Interrupted run.** If an `NN-*.md` for this slice already exists while the slice is still `Pending`, an earlier run stopped after writing it. Pass that file to `sassy-plan` as the `out:` path and the existing plan, so it updates it in place per its existing-plan rule instead of re-grilling from scratch.
7. **Mark it `Planned`.** In the slice table set the slice `Planned` and the Plan cell to the plan link. Commit nothing. The plan and `goal.md` ride onto the slice's branch when `sassy-work` or `sassy-lfg` cuts it. Their commits name the plan, not `goal.md`, so the `Planned` mark stays uncommitted on the slice branch until `sassy-ship`'s step 4 commit, which sets it `Shipped`.
8. **Hand over.** Report the plan path and print both commands in the harness's syntax, then stop:

   ```text
   S<n> planned at <plan path>. Pick one:
   /sassy-work <plan path>   — one phase per session
   /sassy-lfg <plan path>    — every phase, then ship
   ```

   After `sassy-ship` closes the slice it prints the `mode:check` command.
