---
name: sassy-commit
description: >-
  Create a git commit with a Conventional Commits message that states the outcome. Use when asked
  to commit or save staged/unstaged changes with a repo-appropriate message.
  Local commit only — no push, no PR.
argument-hint: "[branch:current|new <name>]"
disable-model-invocation: true
---

# Sassy Commit

**Outcome:** Each logical change committed with an explicit file list and a Conventional Commits message stating the outcome, and `git status` clean of those changes.

**Harness.** Loading another skill, dispatching an agent, and any command you hand the user follow the `sassy-setup` skill's `references/harness.md`. Read it once per run, before the first of those.

## Context

Gather this first, each command as its own shell call (no `;`, `&&`, `|`, or redirects):

| Command | Purpose |
|---------|---------|
| `git status` | Working-tree state |
| `git diff HEAD` | Uncommitted changes |
| `git branch --show-current` | Current branch |
| `git log --oneline -10` | Recent message style |
| `git rev-parse --abbrev-ref origin/HEAD` | Probed base — only when the config leaves it unknown |

Treat the reads as a snapshot; re-read branch and staged set right before committing if anything may have changed. Strip a leading `origin/` from `origin/HEAD` to get the bare base branch name.

**Never bypass hooks.** No `--no-verify`, and never pass it through to a project script this run invokes. A repo's git hooks are the layer that cannot be skipped, so disabling them silently removes an enforcement the project relies on.

**Config.** Resolve `.sassywares/config.yaml` (nearest, walking up) per the `sassy-setup` skill's `references/config.md`. `commit.branch` supplies the default.

**Who may pass a token.** Precedence is explicit token > session instruction > config > skill default, and a token counts as explicit only when the **caller** supplied it — the user typed it, or an earlier gate of the same run authorized it. A skill must never pass its own default as a token: that promotes a default over the project's config and makes `commit.branch` unreachable. When the entry skill (`sassy-work`, `sassy-lfg`, `sassy-debug`) has already resolved the branch through `sassy-setup`'s `references/branching.md`, it passes `branch:current`, because the branch exists and the work belongs on it.

**Branch option.** `branch:current|new [<name>]`. `current` commits on the checked-out branch. `new` cuts a branch from `origin/<base>` — `<base>` is `base_map` from the repo's own config when it has one, else `repos[<dir>]` from the workspace config, else the probed base **confirmed with the user** — named `<name>` when given, else from the change. Use `new` only when no branch has been cut yet; the entry skills cut at the start of a run, so a `new` from them means the cut was skipped. `sassy-commit-push-pr` forwards its own `branch` choice here.

**Not in a workspace root, not outside git.** With `git.repo: workspace` there is no local commit to make: refuse in one line and name the snapshot instead. With `git.repo: none`, refuse and say the project is deliberately outside git. Inside a nested repo, a normal commit is correct — the nearest work tree is the repo.

## Workflow

0. **Gather** the context above.
1. **Nothing to commit** — if there are no staged, modified, or untracked files, say so and stop.
2. **Branch** — honor the `branch` option. With `branch:new`, cut from the base: `git fetch <remote> <base>`, then `git checkout -b <name> <remote>/<base>`, then confirm `git merge-base HEAD <remote>/<base>` is `<remote>/<base>`. If that ancestry check fails, the branch was cut from the wrong base — recreate it, never push it. If the name already exists, reuse it when it descends from the base; fork a suffix only when it has diverged, and never cut a second branch off the base for the same work.

   With `branch:current`, commit on the checked-out branch — but check what it is first with the `sassy-setup` skill's `scripts/detect.sh --branch`, passing `--policy current` so the detector knows the caller chose this branch. **Base means any `base_map` value, not just `origin/HEAD`.** Read `action` before committing:
   - `commit-here` — the caller's `branch:current` (or a config that says `current`) chose this branch. Commit, and name the branch in the summary you return.
   - `reuse` — a branch that is not a base. Commit.
   - `create` — you were told `current` but nothing chose it and this is a base: the caller skipped the branch decision. **Stop and report** — do not commit. A warning inside a subagent's summary has already failed to protect a shared branch once; this is a stop, not a notice.
   - `stop-and-ask` or `refuse` — report the reason line and stop.
3. **Convention** — [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/), always. The project refines it, never replaces it: allowed types, scopes, and case come from its commitlint config, `CONTRIBUTING`, or agent instructions when they exist, and recent history shows which scopes are in use. Only an explicit project rule mandating a different format overrides it — follow that and say so. A non-conventional log is not such a rule.
4. **Logical commits** — if changed files clearly split into distinct concerns, make separate commits (file level, 2–3 max, never `git add -p`). If ambiguous, one commit.
5. **Message** — `<type>[(scope)][!]: <description>`, then an optional body and footers, each after a blank line.
   - **Type** — `feat` (new behavior), `fix` (bug fix), `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`. When `fix`/`feat` both fit, default to `fix`. Split the commit rather than pick a type that hides half of it.
   - **Scope** — optional; the area touched, lowercase, as the project already names it (`checkout`, `api`). Omit rather than invent one.
   - **Description** — imperative, names the outcome rather than the file list, lowercase start, no trailing period, header at most 72 characters.
   - **Body** — only when the motivation is not obvious: why, not what. Wrap at 72.
   - **Breaking change** — `!` before the colon and a `BREAKING CHANGE: <what breaks and how to migrate>` footer.
   - **Footers** — `Refs: #123`, `Closes #123`, `Co-authored-by:` lines go last.
   - Bad: `Update checkout.rb`, `Fix double-submit on checkout`
   - Good: `fix(checkout): prevent double-submit on slow networks`
6. **Stage and commit** — stage **named files only** (never `git add -A` or `git add .`). Write the full message to `/tmp/sassywares/<harness>/commits/<UTC timestamp>-<slug>.txt` (directory per the `sassy-setup` skill's `references/harness.md`), then:
   ```
   git add file1 file2 file3
   git commit -F <message-file> -- file1 file2 file3
   ```
   The trailing path list keeps unrelated staged files out.
7. **Confirm** — run `git status`; report the hash(es) and subject(s).
