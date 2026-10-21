---
name: sassy-ship
description: >-
  Close out approved work: capture learnings, write a handover handbook when
  warranted, then commit, open a PR, and babysit it. Every heavy step is
  delegated to subagents. Default `mode:manual` presents a shipping summary and
  waits before anything is written, committed, pushed, or opened. `mode:auto`
  runs the close-out with no review.
argument-hint: "<plan path or topic> [steps:compound,handbook,commit,pr,babysit] [merge:on|off] [delete-branch:on|off] [mode:manual|auto]"
disable-model-invocation: true
---

# Sassy Ship

**Outcome:** qualifying learnings captured, a handbook written when warranted, the change committed — or snapshotted, in a workspace — a PR opened or updated, and the PR babysat to looks-merge-ready or blocked.

**Modes.** `mode:manual` (default) reviews the whole close-out before any side effect; `mode:auto` is pre-authorized and skips that review. Never toggle it on your own.

**Config.** Resolve `.sassywares/config.yaml` (nearest, walking up) per the `sassy-setup` skill's `references/config.md`. Precedence: explicit token > session instruction > config > skill default. `pr.babysit`, `pr.merge`, and `pr.delete_branch` seed the close-out; `git.repo` decides whether this run commits, snapshots, or refuses; `hooks.pr.*` adds project steps to the PR pipeline.

**Subagent-maximal by design.** The orchestrator delegates every heavy step (docs, tree reads, git, gh) to subagents and only receives compact summaries. It never reads diffs, file contents, or the tree itself.

## Steps (in order)

1. **Review gate.** In `mode:manual` only: present a compact shipping summary — the plan or topic, the changes from the cycle results, the docs the close-out expects to write, the branch/PR target, the babysit options, and **the hooks this run will trigger, by point and name, or that none are declared** — and wait. In `mode:auto`, skip this gate.
2. **Compound (conditional).** If the work produced a qualifying learning, dispatch a `worker` whose task is: *load the `sassy-compound` skill and follow it with `mode:auto`* — with a compact learnings brief (the solved problems, root causes, and solutions taken from the cycle results, not from re-reading the tree). It always gets `mode:auto` because ship's own gate already covered the approval. Skip cleanly when nothing qualifies, and skip entirely when `knowledge.write` is `false`.
3. **Handbook (conditional).** If the feature is self-contained and independent enough that a teammate would benefit from a handover, dispatch a `worker` whose task is: *load the `sassy-handbook` skill and follow it* — with the plan path and topic. The worker reads the tree itself. Skip for small or tightly-coupled changes.
4. **Commit or snapshot.** After the review gate — never before it — the docs and any remaining code become durable.
   - **`git.repo` is a remote.** Dispatch a `worker`: *load the `sassy-commit` skill and follow it*, naming that the commit must include the plan, any new solutions docs, the concepts file, `AGENTS.md`, and any handbook just written — resolved from `artifacts.*`, never hardcoded. Use `branch:current` when already on a feature branch, so the docs land with the phase commits. When the checked-out branch is the base branch, use `branch:new <name>` so the branch is created from `origin/<base>` and carries every phase commit; a workspace run passes the run's shared branch name. Never push directly to the base branch. It returns the hash and subject.
   - **`git.repo: workspace`.** Commit code inside each affected repo on the run's shared branch (cut once on the run's first commit, `branch:current` after), then run `.sassywares/workspace/snapshot`. The snapshot is the workspace's commit and it runs every time, right after approval. A missing or outdated `.sassywares/workspace/snapshot` is a blocker: report it and say to run `sassy-setup`.
   - **`git.repo: none`.** No commit exists here. Report that the work is not persisted and stop.
5. **PR.** In a `remote` repo, dispatch a `worker`: *load the `sassy-commit-push-pr` skill and follow it with `branch:current` and `babysit:off`* (step 6 owns the babysit). It returns the PR URL. In a `workspace`, open one PR per affected repo — the same branch name in each, `--base` from that repo's `repos` entry — and return a table. A touched repo missing from `repos`, or a base that cannot be resolved, is a stop-and-ask, never a guess. `none` opens nothing.

   **The PR step owns the PR hooks.** `before_create` and `after_create` run inside `sassy-commit-push-pr`, once per PR; ship neither runs nor repeats them.
6. **Babysit.** With `pr.babysit` (default `true`), dispatch a `worker`: *load the `sassy-babysit` skill and follow it for the PR just created, one checkpoint*, forwarding any `merge:on|off` and `delete-branch:on|off` the caller supplied, else `pr.merge` and `pr.delete_branch`. It reports looks-ready or blocked. For a continuous watch, tell the user to run `sassy-babysit` in-session.

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
| One branch | Docs land on the current feature branch; from the base branch, ship creates a feature branch so every phase commit moves with it. |
| Never default | Never push directly to the repo base branch. |
| Snapshot after approval | In a workspace, the snapshot runs every time, immediately after the commit approval — never before it, never skipped. |
| One PR per run | `pr.babysit` and `pr.merge` are single-PR. A fan-out gets one babysit run per PR and no automatic merge. |
| Hooks are visible | The gate names every hook this run will trigger. A hook that runs unseen is a side effect nobody approved. |
| One owner per hook | `before_create` and `after_create` belong to `sassy-commit-push-pr`; `before_merge` and `after_merge` belong to `sassy-babysit`. Ship never re-runs them. |
| Compact I/O | Receive hashes, URLs, and one-line statuses only; never paste diffs. |

## Context and token discipline

- Hand each subagent a short brief plus the path of the skill to follow; the subagent reads the skill and the tree in its own context.
- Return only the PR URL, commit hash, doc paths, and a one-line babysit status to the caller.
