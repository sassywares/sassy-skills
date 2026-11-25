# Mode: create — add a checkout for a branch

Read the shared sections in `SKILL.md` first. This file is the create path only.

1. **Resolve the branch and its start point first**, through the `sassy-setup` skill's `references/branching.md`, exactly as `sassy-work` does. A run that reaches here has already decided; the branch is not created twice. When a human asks for one by hand with no branch named, ask for the branch name — never derive one.
2. **Resolve the project's create script**, then run it once:

   ```bash
   bash <sassy-setup skill>/scripts/detect.sh --root <project> --worktree-script create
   <resolved-path> <branch> --from <start-point>
   ```

   An absent key uses the built-in silently; a declared value that is unusable — a missing or non-executable file, or a wrong-shape path — falls back to it with a warning naming the key and the file, and that is not an error. The script takes the same `--from` and the same refusals as the toolbox: `references/worktree.md`'s Refusals table is the list. It does all the project's prepare work around the git call.
3. **Check the contract, not the narration.** stdout carries only the four `WT_*` lines; the human lines — including the upstream it found — are on stderr. A non-zero exit is a refusal or a failed prepare: report its message verbatim and stop. Exit `0` without a complete, four-line identity is the other failure: say **the checkout is real but unprepared**, show what was printed and the path the script named if any, and never invent the missing names or present the checkout as ready.
4. **Say** the path, branch, the namespace, the upstream the script named (`none` is normal), and that the project's prepare step ran. If the caller is a run, tell it to work in `WT_PATH` from now on.

| Rule | Requirement |
|------|-------------|
| One worktree per run | The branch decision belongs to the `sassy-setup` skill's `references/branching.md`. Never create a second worktree for a run already on its branch. |
| Never derive a branch | A human asking for a checkout by hand names its branch. Guessing one is how a checkout lands on a branch nobody is working. |
