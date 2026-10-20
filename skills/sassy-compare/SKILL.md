---
name: sassy-compare
description: >-
  Run the same prompt against two models in separate git worktrees, compare
  their final output, code changes, timing, tokens, and errors, then tear the
  worktrees down and report. Use when choosing between two models for a task or
  checking whether one model is faster or more reliable.
argument-hint: "model-a:<model> model-b:<model> [--base <ref>] [--timeout <sec>] [--keep] <prompt>"
disable-model-invocation: true
---

# Sassy Compare

**Outcome:** one prompt run against two models in isolated worktrees, a report comparing output, code changes, wall time, model time, tool time, turns, tokens, cost, and errors, and the worktrees removed unless `--keep` was passed.

**The main worktree is never touched.** Compare runs in disposable worktrees created from `HEAD` (or `--base`).

## Input

Parse the request into three parts:

- `model-a:<model-identifier>` — first model.
- `model-b:<model-identifier>` — second model.
- The prompt — everything else, verbatim.

Model identifiers are passed straight to `pi --model`; `provider/model` and an optional `:thinking` suffix are allowed, for example `deepseek/deepseek-flash:high`.

If a model or the prompt is missing, ask one short question for the missing part. Do not guess a model.

## Workflow

1. **Resolve the skill directory.** Use the absolute path the host supplied for this `SKILL.md`; the script is at `scripts/compare.py` beside it.
2. **Run the comparison.** Pass the prompt as one argument:

   ```bash
   python3 <skill-dir>/scripts/compare.py \
     --model-a "<model-a>" \
     --model-b "<model-b>" \
     --prompt "<prompt>"
   ```

   Useful options:

   - `--base <ref>` — branch both worktrees from a ref other than `HEAD`.
   - `--timeout <seconds>` — per-model timeout, default 1800.
   - `--keep` — keep the worktrees after the run. Use only when the user asks to inspect them.
   - `--prompt-file <path>` — read the prompt from a file instead of inline.
   - `--dry-run` — create and tear down the worktrees without invoking a model.

3. **Read the report.** The script prints the report path, normally under `~/.pi/compare/<run-id>/report.md`. Read it and present:
   - the summary table,
   - the final output diff,
   - the code diff, or the file lists when the diff is too large,
   - any errors or timeouts.

4. **Report facts, not a verdict.** Do not declare a winner unless the user asked for a recommendation. If asked, base the recommendation on the evidence in the report and name the tradeoff (quality, time, cost, reliability).

## What the script does

- Creates `model-a` and `model-b` worktrees from the chosen base commit.
- Runs each model sequentially with `pi --mode json --no-session --model <model>`, so timing is not polluted by the two runs competing for resources.
- Captures the final assistant text, the full diff against the base (committed and uncommitted), file lists, stderr, turns, model time, tool time, token usage, cost, retries, and error turns.
- Writes the report and artifacts under `~/.pi/compare/<run-id>/`.
- Removes both worktrees and prunes git worktree metadata, unless `--keep` is set.

## Hard rules

| Rule | Requirement |
|------|-------------|
| Isolated worktrees | Never run the prompt in the main worktree. Both models get their own worktree. |
| Same prompt and base | Both models receive the identical prompt and start from the same commit. |
| Sequential runs | Do not run the two models in parallel by default; concurrent runs distort wall-time and provider-latency comparisons. |
| No false comparison | If one run times out or fails, report the failure and do not compare output quality. |
| No silent cleanup loss | Worktrees are removed by default; artifacts and the report stay under `~/.pi/compare/`. |
| Uncommitted work is excluded | Worktrees start from the base commit. Warn the user when the repo is dirty; do not copy local changes. |

## Failure handling

- `pi` is missing or not runnable → stop and report the binary path that failed.
- Not inside a git repository, or the base ref is invalid → stop with the exact error.
- A model times out → report the timeout, keep that model's partial output and stderr, and do not compare quality.
- `git worktree add` fails → stop, report the command output, and remove anything already created.
