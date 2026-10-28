---
name: sassy-commit-push-pr
description: >-
  Commit, push, and open a PR, then babysit it by default. Use when asked to
  ship/open a PR, or for a PR-description-only flow (writing, rewriting, or
  describing a PR body).
argument-hint: "[PR ref] [branch:new|current] [base:<branch>] [babysit:on|off] [checkpoint] [merge:on|off] [delete-branch:on|off]"
disable-model-invocation: true
---

# Sassy Commit, Push, PR

**Modes**
- **Full** (default): commit, push, open or update the PR, then babysit it.
- **Description-only** — the user wants just a description (or a pasted PR ref): compose it, print it, apply only if asked.

**Options.** `branch:new|current` selects the branch policy below. `babysit:on|off` (default `on`) controls the closing babysit. `checkpoint` bounds that babysit to a single tick. `merge:on|off` and `delete-branch:on|off` (both default `off`) are forwarded unchanged to `sassy-babysit`.

**Config.** Resolve `.sassywares/config.yaml` (nearest, walking up) per the `sassy-setup` skill's `references/config.md`. `commit.branch` seeds the branch policy, `pr.*` seeds the babysit options, and `hooks.pr` supplies the `before_create` / `after_create` steps for this run's head. Precedence is explicit token > session instruction > config > skill default, and a token is explicit only when the **caller** supplied it; never pass this skill's own default as a token.

**Which branch is a base.** Use the `sassy-setup` skill's `scripts/detect.sh --branch`: a base is any `base_map` value, not `origin/HEAD`. Probing `origin/HEAD` alone calls `staging` "not a base" in a repo whose `base_map` routes `"*"` there, which is how a run once committed phase work straight onto a shared integration branch.

**Keys are the head branch.** Resolve per head: the exact head, then the longest matching family (`release/*`), then `"*"`. Each point overrides independently. An entry is `<skill> <args…>` — split on the first whitespace and pass the args verbatim.

**Harness.** Loading another skill, dispatching an agent, and any command you hand the user follow the `sassy-setup` skill's `references/harness.md`. Read it once per run, before the first of those.

## Context

Each `git`/`gh` probe is its own argv-form shell call; a non-zero exit is control flow, not something to suppress.

```
git status
git diff HEAD
git branch --show-current
git log --oneline -10
git rev-parse --abbrev-ref origin/HEAD
gh repo view --json defaultBranchRef --jq .defaultBranchRef.name
gh pr view --json url,body,baseRefName,headRefName
gh pr list --head <branch> --state open --json url,number
```

Only an exit-0 empty list means "no open PR". A non-zero exit means **unknown** — resolve auth/connectivity first, never treat it as "none". Probe output is a snapshot; re-check branch/remote/PR state right before the push and the PR create.

**Branch policy.** The run's branch is normally already decided: `sassy-work` and `sassy-lfg` cut it at the start via the `sassy-setup` skill's `references/branching.md`, and `sassy-ship` forwards `branch:current`. So the default here is to commit on the checked-out branch when `state` is not `on-base`. Only when it *is* `on-base` or `detached` — a bare invocation with no orchestrator above it — create a feature branch named from the work and say so. `branch:current` or a plain request keeps the checked-out branch (that run still pushes and opens the PR; only `commit.branch: current` in the config skips it, in `sassy-ship`). Never ask whether to branch. Forward the resolved choice to `sassy-commit`: `branch:new <name>` only when this run creates a branch, else `branch:current`.

**Base branch.** `<base>` is `base_map[<current head>]` from the nearest config — a nested repo's own config wins over the workspace's `repos[<dir>]` — falling back to `base_map["*"]`, else the probed remote HEAD **confirmed with the user before use**. The map is the reason a release PR targets `main` while the work sits on `staging`, with no token passed. An explicit `base:<branch>` token wins over all of them — use it when this PR targets something other than the day-to-day base, such as a release PR aimed at `main` while work lands on `staging`. **Never use `defaultBranchRef` as the PR base when the config names one.** Pass it explicitly: `gh pr create --base <base>`.

**Refused topologies.** From a `workspace` root there is no single PR to open — refuse in one line and point at `sassy-ship`, which owns the per-repo fan-out. With `git.repo: none`, refuse and say why. Neither ever pushes directly to a base branch.

## Steps

1. **Commit** — follow `sassy-commit` with the branch choice from the policy above (named files only, outcome-stating message). Honor an `exclude:<paths>` token if present.
2. **`before_create` hooks.** Resolve `before_create` for the head branch (`base_map` decides the base, the head is the branch you are on); empty means skip. Split each entry on the first whitespace — the first token is the skill, the rest are its args. Run each name in declared order, one `worker` per hook, whose task is *read `<repo>/.agents/skills/<name>/SKILL.md` and follow it* plus a brief: plan path, changed files, artifact paths, base, branch, and the commit hash. This point runs **after** the commit, so a hook may write and commit its own artifacts — push whatever ends up on the branch. A missing skill or a `blocked` result stops the run and names the hook; a `needs-decision` result comes back to you to present.
3. **Pre-push gate** — resolve any pre-push or review-ready requirement from the project's active instructions. Only evidence valid for the exact commit being sent satisfies it; otherwise stop and report what is missing. If none, proceed.
4. **Push** — `git push -u origin <branch>` for a new branch, else `git push`. Re-verify branch and remote first, and re-check that the branch is ahead of origin after any hook commits.
5. **Compose the PR title and body**
   - **Title** — a Conventional Commits header, the same rules as `sassy-commit`'s message step, because a squash merge turns it into the commit on the base: `<type>[(scope)][!]: <description>`, at most 72 characters. A single-commit PR reuses that commit's header. A multi-commit PR takes the type of its most significant change (`feat` over `fix` over the rest), and `!` when any commit breaks something.
   - **Body** — use the repo's PR template when one exists: `.github/pull_request_template.md`, `.github/PULL_REQUEST_TEMPLATE.md`, a `.github/PULL_REQUEST_TEMPLATE/` folder (pick the template that fits the change), or the same names at the repo root or under `docs/`. Fill every section; write "N/A" rather than deleting one, and keep its checklists. With no template, use `## Summary` (what changed and why), `## Changes` (the notable ones, as bullets), `## Verification` (how it was tested, the commands and their results), and `## Related` (issues or plan) when there is anything to link. Carry a `BREAKING CHANGE` from the commits into the body. Preserve any existing `Related:` / `Fixes` line on an update.
   - If no PR exists, compose fresh; if one does, edit its body, and its title too when the title is not conventional.
6. **Apply** — re-check PR presence. With a matching PR: `gh pr edit <url> --body-file <path>`, adding `--title <title>` when step 5 rewrote the title. With none: `gh pr create --base <base> --title <title> --body-file <path>`. Always pass the body via `--body-file`, never stdin, and always name the base. The body file lives in `/tmp/sassywares/<harness>/prs/` (per `references/harness.md`), named `<UTC timestamp>-<branch>.md`.
7. **`after_create` hooks.** Only when this run **created** the PR — an update does not fire them, say so in one line. Same resolution and ordering as step 2, with the PR URL added to the brief. These must leave the tree clean: anything they write is reported, not committed.
8. **Babysit** — with `babysit:on` (default), load `sassy-babysit` and follow it for the PR just opened or updated, forwarding `checkpoint`, `merge:`, and `delete-branch:` unchanged. Report the PR URL and the babysit status; for a continuous watch beyond this run, point the user at `sassy-babysit`. With `babysit:off`, report the PR URL only.
