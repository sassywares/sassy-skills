---
name: sassy-ship
description: >-
  Close out approved work: capture learnings, write a handover handbook when
  warranted, then commit, open a PR, and babysit it. Every heavy step is
  delegated to subagents. In mode:review (default), present a shipping summary
  and wait for approval before commit/push/PR; mode:pipeline skips all approvals.
argument-hint: "<plan path or topic> [steps:compound,handbook,commit,pr,babysit] [merge:on|off] [delete-branch:on|off] [mode:review|pipeline]"
disable-model-invocation: true
---

# Sassy Ship

**Outcome:** qualifying learnings captured, a handbook written when warranted, the change committed, a PR opened or updated, and the PR babysat to looks-merge-ready or blocked.

**Runs after code approval.** `mode:review` (default) adds a separate shipping gate: summarize what is about to ship and wait for the user before any commit, push, or PR. `mode:pipeline` skips all ship approval gates.

**Ship mode.** `mode:review` (default) presents the shipping summary and waits for approval; `mode:pipeline` is pre-authorized and skips that gate. Never toggle it yourself.

**Subagent-maximal by design.** The orchestrator delegates every heavy step (docs, tree reads, git, gh) to subagents and only receives compact summaries. It never reads diffs, file contents, or the tree itself.

## Steps (in order)

1. **Compound (conditional).** If the work produced a qualifying learning, dispatch a `worker` whose task is: *read `~/.agents/skills/sassy-compound/SKILL.md` and follow it* — with a compact learnings brief (the solved problems, root causes, and solutions taken from the cycle results, not from re-reading the tree). Skip cleanly when nothing qualifies.
2. **Handbook (conditional).** If the feature is self-contained and independent enough that a teammate would benefit from a handover, dispatch a `worker` whose task is: *read `~/.agents/skills/sassy-handbook/SKILL.md` and follow it* — with the plan path and topic. The worker reads the tree itself. Skip for small or tightly-coupled changes.
3. **Review gate (`mode:review` only).** Present a compact shipping summary: the plan or topic, the changes from the cycle results, the docs that will be committed, the branch/PR target, and any babysit options. Wait for the user's approval. With `mode:pipeline`, skip this gate.
4. **Commit.** Dispatch a `worker` whose task is: *read `~/.agents/skills/sassy-commit/SKILL.md` and follow it*, naming that the commit must include the plan, any new `docs/solutions/` docs, `CONCEPTS.md`, `AGENTS.md`, and any `docs/handbooks/` file just written. Use `branch:current` when already on a feature branch, so the docs land on the same branch as any per-phase commits. When the checked-out branch is the repo default, use `branch:new` so the branch is created at the current HEAD and carries every phase commit; if nothing is left to commit, still create that branch at HEAD before shipping. Never push directly to the default branch. It returns the hash and subject, or reports that the branch was created with nothing new to commit.
5. **Ship.** Dispatch a `worker` whose task is: *read `~/.agents/skills/sassy-commit-push-pr/SKILL.md` and follow it with `branch:current` and `babysit:off`* (step 6 owns the babysit). It returns the PR URL.
6. **Babysit.** Dispatch a `worker` whose task is: *read `~/.agents/skills/sassy-babysit/SKILL.md` and follow it for the PR just created, one checkpoint*, forwarding any `merge:on|off` and `delete-branch:on|off` the caller supplied. It reports looks-ready or blocked. For a continuous watch, tell the user to run `sassy-babysit` in-session.

## Rules

| Rule | Requirement |
|------|-------------|
| Review gate | In `mode:review`, present the shipping summary and wait before commit, push, or PR. |
| Pipeline | In `mode:pipeline`, skip all ship approval gates. |
| Delegate everything | The orchestrator runs no git, gh, or file work itself. |
| Conditional docs | Compound and handbook are skipped when they do not qualify. |
| Docs in the commit | New docs and pointer lines ship in the same change. |
| One branch | Docs land on the current feature branch; from the default branch, ship creates the feature branch at HEAD so every phase commit moves with it. |
| Never default | Never push directly to the repo default branch. |
| Compact I/O | Receive hashes, URLs, and one-line statuses only; never paste diffs. |

## Context and token discipline

- Hand each subagent a short brief plus the path of the skill to follow; the subagent reads the skill and the tree in its own context.
- Return only the PR URL, commit hash, doc paths, and a one-line babysit status to the caller.
