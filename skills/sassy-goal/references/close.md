# Mode: close — verify the whole goal

Runs on the last slice's branch after its `mode:check`, before its PR merges, so `**Status:** Done` rides in the last PR.

1. **Precondition.** Read `goal.md`. Every slice must be `Done`. Then dispatch a probe `worker` to return:
   - the `sassy-setup` skill's `scripts/detect.sh --branch` (no `--policy`) `state` and `head`;
   - `gh pr view <head> --json state,url` for the last slice's PR;
   - `gh pr view <url> --json state` for every earlier slice's PR link.

   Outside `commit.branch: current`, `state` must be `on-branch` (the last slice's branch) and its PR `OPEN`; every earlier PR must be `MERGED`. Under `commit.branch: current`, `git.repo: workspace`, or `git.repo: none` — or when a slice has no PR link — ask the user to confirm the merges instead. Anything else → stop and say what is due. If the last PR already merged, the status can no longer ride in it: cut a branch from the base, run `mode:close` there, and open a PR for it.
2. **Two read-only checks, in parallel.** Dispatch both in one turn; neither edits anything:
   - **Done when** — a `worker` that checks each goal Done-when item against the whole tree, including repo-wide checks, and returns pass / fail per item with `file:line` evidence.
   - **Roll-up** — a `worker` that reads `goal.md` and its slice plans and returns whether every slice is `Done` and every gap a carry-forward entry deferred landed in a later slice's plan or was explicitly accepted, naming each one that did not.
3. **Resolve every gap.** Present each failure with its evidence, and for each the user picks one:
   - **Fix on this branch** — load the `sassy-cycle` skill on rework with the chosen gaps as findings and `goal.md` as the intent reference.
   - **Add a slice** — record the gap under Deferred in `goal.md` as *needs a new slice*. The user adds the slice with `sassy-goal <goal path> mode:write`, which revises the goal.
   - **Accept** — record it as a Decision with provenance: `D<n>: <gap> accepted unmet — <reason> (user-directed, over fixing)`. Never as an Assumption or a Carry-forward entry.

   Nothing is left unchosen. With mixed choices, run the chosen fixes first.
4. **Mark it `Done`** — only when no gap was sent to a new slice: set `**Status:** Done`. If any was, the goal stays `Active`.
5. **Persist** per the SKILL.md Persisting section, on this branch, so `goal.md` and any fixes merge with the last slice.
6. **Report** the goal path, each Done-when item with its result, and the gaps fixed, accepted, or sent to a new slice. If the goal stayed `Active`, give `/sassy-goal <goal path> mode:write` to add the slice, then `mode:next` once this PR merges. Otherwise the goal is closed when this PR merges. Persisting ran with `babysit:off`, so end with `/sassy-babysit <PR url>` in the harness's syntax.
