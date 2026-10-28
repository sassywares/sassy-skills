---
name: sassy-ship
description: >-
  Close out approved work: capture learnings, write a handover handbook when
  warranted, then commit, open a PR, and babysit it (under
  `commit.branch: current`, commit and push only). Every heavy step is
  delegated to subagents. Default `mode:manual` presents a shipping summary and
  waits before anything is written, committed, pushed, or opened. `mode:auto`
  runs the close-out with no review.
argument-hint: "<plan path or topic> [steps:compound,handbook,commit,pr,babysit] [base:<branch>] [merge:on|off] [delete-branch:on|off] [mode:manual|auto]"
---

# Sassy Ship

**Outcome:** qualifying learnings captured, a handbook written when warranted, the change committed — or snapshotted, in a workspace — a PR opened or updated, and the PR babysat to looks-merge-ready or blocked. Under `commit.branch: current` there is no PR: the commit is pushed to the checked-out branch's upstream and the close-out ends there.

**Modes.** `mode:manual` (default) reviews the whole close-out before any side effect; `mode:auto` is pre-authorized and skips that review. Never toggle it on your own.

**Config.** Resolve `.sassywares/config.yaml` (nearest, walking up) per the `sassy-setup` skill's `references/config.md`. Precedence: explicit token > session instruction > config > skill default. `pr.babysit`, `pr.merge`, and `pr.delete_branch` seed the close-out; `git.repo` decides whether this run commits, snapshots, or refuses; `hooks.pr.*` adds project steps to the PR pipeline. `commit.branch: current` replaces the PR pipeline with a push; see Current policy below.

**Current policy.** `commit.branch: current` in the config is an explicit opt-in to work landing where it stands. Under it the close-out commits on the checked-out branch and pushes it to its upstream, base branch included, and skips the PR entirely: no `sassy-commit-push-pr`, no `hooks.pr.*`, no babysit, no merge. A user-typed `branch:current` token keeps its usual meaning (commit on the checked-out branch) and does not suppress the PR; neither does the `branch:current` ship forwards to `sassy-commit`.

**How to obtain it.** Before the gate, in both `mode:manual` and `mode:auto`, dispatch one dedicated probe `worker`: run the `sassy-setup` skill's `scripts/detect.sh --branch` with **no `--policy`** and return `configured`, `head`, and the upstream (or that none is set). `configured: current` means the current policy applies. Never take the policy from the commit worker: it runs with the forwarded `branch:current` and always reports `policy: current`.

**Subagent-maximal by design.** The orchestrator delegates every heavy step (docs, tree reads, git, gh) to subagents and only receives compact summaries. It never reads diffs, file contents, or the tree itself.

**Harness.** Loading another skill, dispatching an agent, and any command you hand the user follow the `sassy-setup` skill's `references/harness.md`. Read it once per run, before the first of those.

## Steps (in order)

1. **Review gate.** In `mode:manual` only: present a compact shipping summary — the plan or topic, the changes from the cycle results, the docs the close-out expects to write, the branch/PR target, the babysit options, and **the hooks resolved for this run's head — point, skill, and args — or that none are declared** — and wait. Under `commit.branch: current`, state instead "commit + push to `<head>`, no PR" and that no PR, babysit, merge, or `hooks.pr.*` (`before_create`, `after_create`, `before_merge`, `after_merge`) will run. In `mode:auto`, skip this gate.
2. **Compound (conditional).** If the work produced a qualifying learning, dispatch a `worker` whose task is: *load the `sassy-compound` skill and follow it with `mode:auto`* — with a compact learnings brief (the solved problems, root causes, and solutions taken from the cycle results, not from re-reading the tree). It always gets `mode:auto` because ship's own gate already covered the approval. Skip cleanly when nothing qualifies, and skip entirely when `knowledge.write` is `false`.
3. **Handbook (conditional).** If the feature is self-contained and independent enough that a teammate would benefit from a handover, dispatch a `worker` whose task is: *load the `sassy-handbook` skill and follow it* — with the plan path and topic. The worker reads the tree itself. Skip for small or tightly-coupled changes.
4. **Commit or snapshot.** After the review gate — never before it — the docs and any remaining code become durable.
   - **`git.repo` is a remote.** Dispatch a `worker`: *load the `sassy-commit` skill and follow it with `branch:current`*, naming that the commit must include the plan, any new solutions docs, the concepts file, `AGENTS.md`, and any handbook just written — resolved from `artifacts.*`, never hardcoded. The branch already exists: `sassy-work` or `sassy-lfg` cut it before the first change, so the docs belong on it with the phase commits. It returns the hash and subject.

     **Ship never creates the branch.** Outside `commit.branch: current`, a head on a base branch with unpublished commits is a mis-run — `sassy-work` was supposed to cut before touching code. Ask the commit worker to return `state` and `unpublished` from the `sassy-setup` skill's `scripts/detect.sh --branch`, and stop and ask if they show a base with a non-zero count. Never relocate commits silently, never push to the base. Under `commit.branch: current` this check does not fire: unpublished commits on the head are simply pushed along with the close-out commit.
   - **`git.repo: workspace`.** Commit code inside each affected repo on the run's shared branch — cut once at the start of the run, `branch:current` from then on — then run `.sassywares/workspace/snapshot`. The snapshot is the workspace's commit and it runs every time, right after approval. A missing or outdated `.sassywares/workspace/snapshot` is a blocker: report it and say to run `sassy-setup`.
   - **`git.repo: none`.** No commit exists here. Report that the work is not persisted and stop.
5. **PR, or push.** Under `commit.branch: current` in a `remote` repo, skip the PR: dispatch a `worker` to push the head to its upstream with `git push` (upstream set), or `git push -u <remote> <head>` when the head has no upstream — never force. On a non-fast-forward rejection, stop and report; fetching or rebasing is a stop-and-ask. Return the pushed hash and `<head>`, then end the close-out (step 6 is skipped too). In a workspace, push each affected repo in `repos` order, stop at the first rejection, and return a per-repo table (pushed / rejected / not attempted). The final report says "no PR — hooks.pr.* skipped", in `mode:auto` too. Otherwise, in a `remote` repo, dispatch a `worker`: *load the `sassy-commit-push-pr` skill and follow it with `branch:current` and `babysit:off`, forwarding `base:<branch>` when the caller supplied one* (step 6 owns the babysit). It returns the PR URL. In a `workspace`, open one PR per affected repo — the same branch name in each, `--base` from that repo's own `base_map` when it carries a `.sassywares/config.yaml`, else its `repos` entry — and return a table. A touched repo missing from `repos`, or a base that cannot be resolved, is a stop-and-ask, never a guess. `none` opens nothing.

   **The PR step owns the PR hooks.** `before_create` and `after_create` run inside `sassy-commit-push-pr`, once per PR; ship neither runs nor repeats them.
6. **Babysit.** Skipped under `commit.branch: current`. With `pr.babysit` (default `true`), dispatch a `worker`: *load the `sassy-babysit` skill and follow it for the PR just created, one checkpoint*, forwarding any `merge:on|off` and `delete-branch:on|off` the caller supplied, else `pr.merge` and `pr.delete_branch`. It reports looks-ready or blocked. For a continuous watch, tell the user to run `sassy-babysit` in-session.

   **One PR per run.** Babysitting a workspace fan-out means one `sassy-babysit` run per PR, and a fan-out is never auto-merged: `pr.merge` and `pr.merge:on` apply to a single-PR run only. A multi-repo merge needs an explicit per-PR say-so.

## Rules

| Rule | Requirement |
|------|-------------|
| Review gate | `mode:manual` (default) presents the summary and waits before any write, commit, push, or PR. |
| No review | `mode:auto` runs the close-out with no approval gate. Never toggled by the skill. |
| All-or-nothing gate | In `mode:manual`, nothing is written until the gate is answered. |
| Delegate everything | The orchestrator runs no git, gh, or file work itself. |
| Conditional docs | Compound and handbook are skipped when they do not qualify. |
| Docs in the commit | New docs and pointer lines ship in the same change. |
| One branch | The branch is cut once, before the first change, by `sassy-work` or `sassy-lfg` (unless `commit.branch: current`). Ship and its docs commit land on it. |
| Never create the branch | Ship never cuts a branch. Outside `commit.branch: current`, a head on a base branch with unpublished commits is a stop-and-ask, decided from the commit worker's `state` and `unpublished`. |
| Never default | Never push directly to the repo base branch — except under `commit.branch: current`, an explicit opt-in, where ship pushes the checked-out branch (base or not) to its upstream, never forced. |
| Current policy | `commit.branch: current` means commit + push, no PR: no `sassy-commit-push-pr`, no `hooks.pr.*`, no babysit, no merge. A non-fast-forward push is a stop-and-report; in a workspace the push stops at the first rejected repo. |
| Snapshot after approval | In a workspace, the snapshot runs every time, immediately after the commit approval — never before it, never skipped. |
| One PR per run | `pr.babysit` and `pr.merge` are single-PR. A fan-out gets one babysit run per PR and no automatic merge. |
| Hooks are visible | The gate names every hook this run will trigger. A hook that runs unseen is a side effect nobody approved. |
| One owner per hook | `before_create` and `after_create` belong to `sassy-commit-push-pr`; `before_merge` and `after_merge` belong to `sassy-babysit`. Ship never re-runs them. |
| Compact I/O | Receive hashes, URLs, and one-line statuses only; never paste diffs. |

## Context and token discipline

- Hand each subagent a short brief plus the path of the skill to follow; the subagent reads the skill and the tree in its own context.
- Return only the PR URL (or the pushed hash and "no PR — hooks.pr.* skipped"), commit hash, doc paths, and a one-line babysit status to the caller.
