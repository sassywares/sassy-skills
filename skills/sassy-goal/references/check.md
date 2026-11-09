# Mode: check — validate a shipped slice and carry it forward

Runs on the slice branch after `sassy-ship`, before the PR merges, so whatever it changes rides in the same PR.

1. **Precondition.** Read `goal.md` and find the slice (`slice:<ID>`, else the one `Shipped`). It must be `Shipped`, and every phase in its plan's Phase tracking table must be `Done`. Otherwise stop and say what is due — unfinished phases need `sassy-work` or `sassy-lfg`, an unshipped slice needs `sassy-ship`.

   Then dispatch a probe `worker` to run the `sassy-setup` skill's `scripts/detect.sh --branch` (no `--policy`), returning `state` and `head`, and `gh pr view <head> --json state,url,baseRefName`. Outside `commit.branch: current`:
   - `state` must be `on-branch` — the slice branch. Anything else → stop and tell the user to check out the slice branch.
   - The PR must be `OPEN`. Already merged → stop: the check can no longer ride in the slice's PR. Recovery: cut a branch from the base, run `mode:check` there, and open a PR for the `goal.md` update and any fixes. Closed unmerged → stop and ask what happened.
2. **Find the range.** The probe worker also returns `git merge-base <remote>/<baseRefName> HEAD`. Under `commit.branch: current` there is no PR: ask the user for the commit the slice started from. Under `git.repo: workspace`, get one PR, base, and merge-base per affected repo.
3. **Validate.** Load the `sassy-validate` skill with `mode:return`, the slice plan path with no phase (the whole plan), and `range:<merge-base>..HEAD`. In a workspace, make one call per affected repo, each with its own range. A `Blocked — insufficient grounding` grade stops the check: report what it needs.
4. **Resolve every gap.** On `Conforms`, there are none. Otherwise present each gap with its evidence, and for each the user picks one:
   - **Fix now** — collected and closed together: load the `sassy-cycle` skill on rework with the chosen gaps as findings and the slice plan as the intent reference. A gap still open after its two fix passes goes back to the user to defer or accept.
   - **Defer to a later slice** — the user names one that is still `Pending`. Add the gap to that slice's Scope or Done when in `goal.md`; it also goes in this slice's carry-forward entry. On the last slice there is nothing to defer to: only fix or accept.
   - **Accept** — with the user's reason, recorded in the carry-forward entry.

   The slice cannot turn `Done` while any gap is unchosen. Never pick for the user.
5. **Carry forward.** Append one entry for this slice to Carry-forward per `references/goal-format.md`: what changed versus the plan, new decisions or constraints (they bind later slices), impact on later slices, and each gap deferred (with its slice) or accepted (with its reason). Never edit an earlier entry.
6. **Mark it `Done`** in the slice table, and add the PR link from step 1's `url` to its Plan cell.
7. **Persist** per the SKILL.md Persisting section — `goal.md` and any fixes, committed on the slice branch and pushed so they merge with the slice.
8. **Next commands**, in the harness's syntax:
   - The last slice → `/sassy-goal <goal path> mode:close`, run on this branch before the PR merges.
   - Otherwise → `/sassy-goal <goal path> mode:next`, once this slice's PR has merged.

   Persisting ran with `babysit:off`, so end with `/sassy-babysit <PR url>` to watch the updated PR.
