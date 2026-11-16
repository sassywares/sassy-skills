# Mode: create — add a checkout for a branch

Read the shared sections in `SKILL.md` first. This file is the create path only.

1. **Resolve the branch and its start point first**, through the `sassy-setup` skill's `references/branching.md`, exactly as `sassy-work` does. A run that reaches here has already decided; the branch is not created twice. When a human asks for one by hand with no branch named, ask for the branch name — never derive one.
2. **Run `.sassywares/worktree/create <branch> --from <start-point>`** with the resolved start point. It is idempotent: an existing worktree for that branch is reported, a branch held by the main checkout is refused, and a port is claimed either way. On `--env` it prints the `WT_*` block alone.
3. **Dispatch the declared hooks.** The script prints one line per `hooks.worktree.after_create` entry; it cannot dispatch a skill, so you do. One `worker` each, in declared order: *load the project skill at `.agents/skills/<name>/SKILL.md` and follow it*, briefed with the `WT_*` block and the fact that the checkout now exists. A missing skill or a `blocked` result stops here — the checkout is real but unprepared, and saying so is the report.
4. **Report** the path, branch, namespace, port, address, the preview line, and the hooks that ran or that none are declared. If the caller is a run, tell it to work in `WT_PATH` from now on.

| Rule | Requirement |
|------|-------------|
| One worktree per run | The branch decision belongs to the `sassy-setup` skill's `references/branching.md`. Never create a second worktree for a run already on its branch. |
| Never derive a branch | A human asking for a checkout by hand names its branch. Guessing one is how a checkout lands on a branch nobody is working. |
