---
name: sassy-commit
description: >-
  Create a git commit with a clear, value-communicating message. Use when asked
  to commit or save staged/unstaged changes with a repo-appropriate message.
  Local commit only — no push, no PR.
argument-hint: "[branch:current|new]"
disable-model-invocation: true
---

# Sassy Commit

**Outcome:** Each logical change committed with an explicit file list and a message stating the outcome, and `git status` clean of those changes.

## Context

Gather this first, each command as its own shell call (no `;`, `&&`, `|`, or redirects):

| Command | Purpose |
|---------|---------|
| `git status` | Working-tree state |
| `git diff HEAD` | Uncommitted changes |
| `git branch --show-current` | Current branch |
| `git log --oneline -10` | Recent message style |
| `git rev-parse --abbrev-ref origin/HEAD` | Remote default branch |

Treat the reads as a snapshot; re-read branch and staged set right before committing if anything may have changed. Strip a leading `origin/` from `origin/HEAD` to get the bare default branch name.

**Branch option.** `branch:current|new`, default `current`. `current` commits on the checked-out branch. `new` creates a feature branch named from the change and commits there. `sassy-commit-push-pr` forwards its own `branch` choice here.

## Workflow

0. **Gather** the context above.
1. **Nothing to commit** — if there are no staged, modified, or untracked files, say so and stop.
2. **Branch** — honor the `branch` option. With `branch:new`, create a feature branch named from the change (`git checkout -b <name>`) and commit there; if the name exists, pick a non-conflicting suffix. With `branch:current` (default), commit on the checked-out branch; if that is the default branch or a detached HEAD, say so in one line before proceeding.
3. **Convention** — match the project's existing commit style; else the recent log pattern; else conventional commits (`type(scope): description`). When `fix`/`feat` both fit, default to `fix:`.
4. **Logical commits** — if changed files clearly split into distinct concerns, make separate commits (file level, 2–3 max, never `git add -p`). If ambiguous, one commit.
5. **Message** — imperative subject naming the outcome, not the file list. Body only when the motivation is not obvious.
   - Bad: `Update checkout.rb`
   - Good: `Fix double-submit on checkout`
6. **Stage and commit** — stage **named files only** (never `git add -A` or `git add .`). Write the full message to a file outside the repo, then:
   ```
   git add file1 file2 file3
   git commit -F <message-file> -- file1 file2 file3
   ```
   The trailing path list keeps unrelated staged files out.
7. **Confirm** — run `git status`; report the hash(es) and subject(s).
