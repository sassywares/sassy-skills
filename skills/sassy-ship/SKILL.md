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

**Outcome:** qualifying learnings captured, a handbook written when warranted, the change committed, a PR opened or updated, and the PR babysat to looks-merge-ready or blocked.

**Modes.** `mode:manual` (default) reviews the whole close-out before any side effect; `mode:auto` is pre-authorized and skips that review. Never toggle it on your own.

**Subagent-maximal by design.** The orchestrator delegates every heavy step (docs, tree reads, git, gh) to subagents and only receives compact summaries. It never reads diffs, file contents, or the tree itself.

## Steps (in order)

1. **Review gate.** In `mode:manual` only: present a compact shipping summary — the plan or topic, the changes from the cycle results, the docs the close-out expects to write, the branch/PR target, and any babysit options — and wait. In `mode:auto`, skip this gate.
2. **Compound (conditional).** If the work produced a qualifying learning, dispatch a `worker` whose task is: *read `~/.agents/skills/sassy-compound/SKILL.md` and follow it with `mode:auto`* — with a compact learnings brief (the solved problems, root causes, and solutions taken from the cycle results, not from re-reading the tree). It always gets `mode:auto` because ship's own gate already covered the approval. Skip cleanly when nothing qualifies.
3. **Handbook (conditional).** If the feature is self-contained and independent enough that a teammate would benefit from a handover, dispatch a `worker` whose task is: *read `~/.agents/skills/sassy-handbook/SKILL.md` and follow it* — with the plan path and topic. The worker reads the tree itself. Skip for small or tightly-coupled changes.
4. **Commit.** Dispatch a `worker` whose task is: *read `~/.agents/skills/sassy-commit/SKILL.md` and follow it*, naming that the commit must include the plan, any new `docs/solutions/` docs, `CONCEPTS.md`, `AGENTS.md`, and any `docs/handbooks/` file just written. Use `branch:current` when already on a feature branch, so the docs land on the same branch as any per-phase commits. When the checked-out branch is the repo default, use `branch:new` so the branch is created at the current HEAD and carries every phase commit; if nothing is left to commit, still create that branch at HEAD before shipping. Never push directly to the default branch. It returns the hash and subject, or reports that the branch was created with nothing new to commit.
5. **Ship.** Dispatch a `worker` whose task is: *read `~/.agents/skills/sassy-commit-push-pr/SKILL.md` and follow it with `branch:current` and `babysit:off`* (step 6 owns the babysit). It returns the PR URL.
6. **Babysit.** Dispatch a `worker` whose task is: *read `~/.agents/skills/sassy-babysit/SKILL.md` and follow it for the PR just created, one checkpoint*, forwarding any `merge:on|off` and `delete-branch:on|off` the caller supplied. It reports looks-ready or blocked. For a continuous watch, tell the user to run `sassy-babysit` in-session.

## Rules

| Rule | Requirement |
|------|-------------|
| Review gate | `mode:manual` (default) presents the summary and waits before any write, commit, push, or PR. |
| No review | `mode:auto` runs the close-out with no approval gate. Never toggled by the skill. |
| All-or-nothing gate | In `mode:manual`, nothing is written until the gate is answered. |
| Delegate everything | The orchestrator runs no git, gh, or file work itself. |
| Conditional docs | Compound and handbook are skipped when they do not qualify. |
| Docs in the commit | New docs and pointer lines ship in the same change. |
| One branch | Docs land on the current feature branch; from the default branch, ship creates the feature branch at HEAD so every phase commit moves with it. |
| Never default | Never push directly to the repo default branch. |
| Compact I/O | Receive hashes, URLs, and one-line statuses only; never paste diffs. |

## Context and token discipline

- Hand each subagent a short brief plus the path of the skill to follow; the subagent reads the skill and the tree in its own context.
- Return only the PR URL, commit hash, doc paths, and a one-line babysit status to the caller.
