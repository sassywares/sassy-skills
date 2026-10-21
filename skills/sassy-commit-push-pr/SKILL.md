---
name: sassy-commit-push-pr
description: >-
  Commit, push, and open a PR, then babysit it by default. Use when asked to
  ship/open a PR, or for a PR-description-only flow (writing, rewriting, or
  describing a PR body).
argument-hint: "[PR ref] [branch:new|current] [babysit:on|off] [checkpoint] [merge:on|off] [delete-branch:on|off]"
disable-model-invocation: true
---

# Sassy Commit, Push, PR

**Modes**
- **Full** (default): commit, push, open or update the PR, then babysit it.
- **Description-only** — the user wants just a description (or a pasted PR ref): compose it, print it, apply only if asked.

**Options.** `branch:new|current` selects the branch policy below. `babysit:on|off` (default `on`) controls the closing babysit. `checkpoint` bounds that babysit to a single tick. `merge:on|off` and `delete-branch:on|off` (both default `off`) are forwarded unchanged to `sassy-babysit`.

**Config.** Resolve `.sassywares/config.yaml` (nearest, walking up) per `~/.agents/skills/sassy-setup/references/config.md`. Precedence: explicit token > session instruction > config > skill default. `commit.branch` seeds the branch policy, `pr.*` seeds the babysit options.

## Context

Each `git`/`gh` probe is its own argv-form shell call; a non-zero exit is control flow, not something to suppress.

```
git status
git diff HEAD
git branch --show-current
git log --oneline -10
git rev-parse --abbrev-ref origin/HEAD
gh repo view --json defaultBranchRef --jq .defaultBranchRef.namegh pr view --json url,body,baseRefName,headRefName
gh pr list --head <branch> --state open --json url,number
```

Only an exit-0 empty list means "no open PR". A non-zero exit means **unknown** — resolve auth/connectivity first, never treat it as "none". Probe output is a snapshot; re-check branch/remote/PR state right before the push and the PR create.

**Branch policy.** Default: if on the base branch or detached HEAD, create a feature branch named from the work and say so. `branch:current` or a plain request keeps the checked-out branch (that run pushes and skips the PR). Never ask whether to branch. Forward the resolved choice to `sassy-commit`: `branch:new <name>` when this run creates a branch, else `branch:current`.

**Base branch.** `<base>` is `repos[<repo dir>]` from a workspace config, else `git.default_branch`, else the probed remote HEAD. **Never use `defaultBranchRef` as the PR base when the config names one** — a repo whose PRs target `staging` or `dev` must not get a PR aimed at `main`. Pass it explicitly: `gh pr create --base <base>`.

**Refused topologies.** From a `workspace` root there is no single PR to open — refuse in one line and point at `sassy-ship`, which owns the per-repo fan-out. With `git.repo: none`, refuse and say why. Neither ever pushes directly to a base branch.

## Steps

1. **Commit** — follow `sassy-commit` with the branch choice from the policy above (named files only, outcome-stating message). Honor an `exclude:<paths>` token if present.
2. **Pre-push gate** — resolve any pre-push or review-ready requirement from the project's active instructions. Only evidence valid for the exact commit being sent satisfies it; otherwise stop and report what is missing. If none, proceed.
3. **Push** — `git push -u origin <branch>` for a new branch, else `git push`. Re-verify branch and remote first.
4. **Compose the PR title and body**
   - Title: outcome-stating, concise.
   - Body: what changed, why, and how it was verified. Preserve any existing `Related:` / `Fixes` line on an update.
   - If no PR exists, compose fresh; if one does, edit its body.
5. **Apply** — re-check PR presence. With a matching PR: `gh pr edit <url> --body-file <path>`. With none: `gh pr create --base <base> --title <title> --body-file <path>`. Always pass the body via `--body-file`, never stdin, and always name the base.
6. **Babysit** — with `babysit:on` (default), load `sassy-babysit` and follow it for the PR just opened or updated, forwarding `checkpoint`, `merge:`, and `delete-branch:` unchanged. Report the PR URL and the babysit status; for a continuous watch beyond this run, point the user at `sassy-babysit`. With `babysit:off`, report the PR URL only.
