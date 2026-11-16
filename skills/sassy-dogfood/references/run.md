# Mode: run — execute the procedure, return a verdict

Read the shared sections in `SKILL.md` first (the recipe artifact, config, no-tooling, and the every-mode rules). This file is the run path only. The recipe format, report layout, and verdict classes are the `sassy-setup` skill's `references/dogfood.md`.

## 1. Resolve the target

Read the `dogfood:` block. If `enabled` is not `true`, stop with one line: reporting is not enabled, and enabling it is `sassy-setup mode:init`. Load the recipe; a section the caller names (`section:<name>`) is the target, otherwise every section. A missing recipe, or one whose section has no `Prove it:` step, stops the run and names `mode:discover`. A section whose `**Prove it:**` says `none` is refused with one line — it has no machine verdict by design, so its QA rows are `Manual`, and running it would only manufacture an opinion. Never guess a verdict from a procedure that has none.

## 2. Open the report

Create `<reports>/<YYYYMMDD-HHMMSS>/` with `steps/` and `artifacts/`, and write `summary.md` with `status: running`, the class blank, the recipe path with the current commit, and the start time. Prune older run directories down to ten.

## 3. Preflight, then the bring-up

Preflight checks presence only: each env var the recipe **names** (never print a value), a session it refers to — only when it refers to one — actually sitting in `.sassywares/session/`, and the commands' entry points existing. A missing entry point, a tool not on `PATH`, or an absent env var is `class: env` — write the report, report it, and stop.

Then **run the recipe's *Set up once*.** It is the bring-up, not a checklist: install frozen where the project has a lockfile, and continue. That is the only installing a run does — never install something the recipe does not name, never `docker pull`, never mutate the environment to make a step pass.

## 4. Execute in order, stopping at the first broken expectation

Per step: write `steps/<section>-<NN>.log`, capped head-and-tail, with the command and its output, values of every env var the recipe names masked, and the exit code. `Do` is a command *or* an instruction — satisfy it with whatever is available, and judge it only against its `Expect`. The step's own shell mechanics are part of the step: backgrounding a server, redirecting its output, creating the directory a log path lives in. Improvisation is what the recipe does **not** name. A step whose expectation fails ends that section: record it, keep everything already written, and skip to the report. Resume at the failed step on the next run, never from the top: the summary's `Next:` line says which.

## 5. Take the verdict from the prove step

The section's `Prove it:` step decides: exit 0 is `pass`, non-zero is `failed`. A failure earlier in the section is `failed` regardless. This skill holds no opinion about the work — a check it judged by reading instead of running is not a verdict.

**The deadline is yours to hold.** Track wall-clock from the start and stop at `dogfood.timeout`, filing the run as `failed` with `class: env` and the step it stopped in. A step that can hang states its own bound in its `Expect`; the recipe-wide deadline is the backstop, not a substitute.

## 6. Classify

| Class | When |
|---|---|
| `env` | The environment cannot produce a verdict: exit 75 or 127, a missing dependency, or **a service nobody in this run controls** being down (a third-party API, a shared backend). Report it, name the dependency, and stop. |
| `recipe` | The procedure itself is what failed: a step cannot be followed at all (a script renamed, a URL that no longer exists, a UI that no longer matches), or the recipe names the wrong version, script, or URL. |
| `code` | Everything else. |

The line between the last two is whose text is wrong: the named toolchain is right but absent → `env`; the recipe's own instructions cannot be followed or name the wrong thing → `recipe`. When in doubt, ask: could a person follow this step as written and still be testing the app? If not, it is `recipe`.

## 7. Finalize and report

A preflight or bring-up failure has no step id, so it logs to `steps/00-setup.log` and the summary's table row reads `setup`. Write the final `summary.md` (`status`, `class`, the per-step table, artifacts, `Next:`), then return compactly: verdict, class, section, failing step id, the last ~600 characters of that step's log, the report path, and — for `recipe` — the one-line diff you propose. Never paste a whole log to the caller.

## 8. On `recipe`, propose and stop

Show the diff that would make the procedure followable and ask before writing it. Never edit the recipe to turn a red run green: the cheapest way to pass a check must not be to weaken it.

## Rules for this path

| Rule | Requirement |
|------|-------------|
| The run may not edit the check | A red run never fixes itself by editing the recipe or its expectations. Propose the diff, ask, stop. |
| Env is not code | Exit 75/127, a missing dependency, or an unreachable service is `env`: report and park. Looping on a broken toolchain burns a run for nothing. |
| Resume, don't restart | Re-run from the failed step; the summary says where. Starting over hides the state that made the failure happen. |
| No dependency churn | A bring-up never changes a lockfile. Install frozen where the project has one; a broken lockfile is `env`, not something to repair mid-run. |
