---
name: sassy-dogfood
description: >-
  Use the product the way a user does, to prove a change actually works at
  runtime rather than only in the diff. Runs the project's stored dogfood
  procedure, writes a report with a verdict, and — in `mode:discover` — builds
  or repairs that procedure from what really worked. Tooling-agnostic: it uses
  whatever the harness has connected at run time and never installs a runner.
  Use before a phase gate, when a plan row is `Mode: Auto`, or to set up
  agent QA for a project.
argument-hint: "[section:<name>] [mode:run|discover|check]"
---

# Sassy Dogfood

**Outcome:** a report with a verdict — `pass`, `failed` with the failing step and its output tail, or `env`/`recipe` explaining why the run could not judge the work — in `.sassywares/dogfood/reports/<run-id>/`, plus, in `mode:discover`, a `recipe.md` that a fresh agent can follow with no other context.

**A procedure is the artifact.** The project stores how to dogfood itself in `.sassywares/dogfood/recipe.md`: ordered steps, each with an observable expectation, ending in one `Prove it:` step whose exit code is the verdict. The config points at it; it never restates it. Read the `sassy-setup` skill's `references/dogfood.md` first — it owns the recipe format, the report layout, and the verdict classes, and this skill only executes them.

**Config.** Resolve `.sassywares/config.yaml` (nearest, walking up) per the `sassy-setup` skill's `references/config.md`. `dogfood.enabled`, `dogfood.recipe`, `dogfood.reports`, and `dogfood.timeout` are the only inputs. Precedence: explicit token > session instruction > config > skill default.

**No tooling.** This skill names no browser, driver, emulator, or MCP server, and it never installs one. A step says *what to do and what to see*; how the agent satisfies that is discovered at run time from what the harness already offers, and a plain command is often the better answer.

**Harness.** Loading another skill, dispatching an agent, and any command you hand the user follow the `sassy-setup` skill's `references/harness.md`. Read it once per run, before the first of those.

## Modes

| Mode | What it does |
|------|--------------|
| `run` (default) | Preflight, execute the procedure from the recipe, write the report, classify, report back |
| `discover` | Build or repair the recipe: probe the repo, try the cheapest proof that could work, write down what actually worked |
| `check` | Lint the config and the recipe and print the last report's verdict; runs nothing, changes nothing |

`run` never edits the recipe. `discover` never gates anything: it produces a
recipe, and the next `run` is what proves it.

## Steps — `mode:run`

1. **Resolve the target.** Read the `dogfood:` block. If `enabled` is not `true`, stop with one line: reporting is not enabled, and enabling it is `sassy-setup mode:init`. Load the recipe; a section the caller names (`section:<name>`) is the target, otherwise every section. A missing recipe, or one whose section has no `Prove it:` step, stops the run and names `mode:discover`. A section whose `**Prove it:**` says `none` is refused with one line — it has no machine verdict by design, so its QA rows are `Manual`, and running it would only manufacture an opinion. Never guess a verdict from a procedure that has none.
2. **Preflight, and do not run blind.** The recipe's *Set up once* lists what must exist. Check that each env var it **names** is present — presence only, never print a value — that a session the recipe refers to is actually in `.sassywares/session/`, and that the commands' entry points exist. A missing dependency, a tool not on `PATH`, or an absent env var is `class: env`: write the report, report it, and stop. Never install, never `docker pull`, never mutate the environment to get past preflight.
3. **Open the report.** Create `<reports>/<YYYYMMDD-HHMMSS>/` with `steps/` and `artifacts/`, and write `summary.md` with `status: running`, the class blank, the recipe path with the current commit, and the start time. Prune older run directories down to ten.
4. **Execute in order, stopping at the first broken expectation.** Per step: write `steps/<section>-<NN>.log`, capped head-and-tail, with the command and its output, values of every env var the recipe names masked, and the exit code. `Do` is a command *or* an instruction — satisfy it with whatever is available, and judge it only against its `Expect`. A step whose expectation fails ends that section: record it, keep everything already written, and skip to the report. Resume at the failed step on the next run, never from the top: the summary's `Next:` line says which.
5. **Take the verdict from the prove step.** The section's `Prove it:` step decides: exit 0 is `pass`, non-zero is `failed`. A failure earlier in the section is `failed` regardless. This skill holds no opinion about the work — a check it judged by reading instead of running is not a verdict.
6. **Classify.** `env` when the environment cannot produce a verdict: exit 75 or 127, a missing dependency, or **a service nobody in this run controls** being down (a third-party API, a shared backend). That last one is neither `code` nor `recipe` — report it, name the dependency, and stop; `recipe` when a step cannot be followed at all (a script renamed, a URL that no longer exists, a UI that no longer matches) — that is the procedure being stale, not the code being wrong; `code` otherwise. When in doubt between `recipe` and `code`, ask: could a person follow this step as written and still be testing the app? If not, it is `recipe`.
7. **Finalize and report.** Write the final `summary.md` (`status`, `class`, the per-step table, artifacts, `Next:`), then return compactly: verdict, class, section, failing step id, the last ~600 characters of that step's log, the report path, and — for `recipe` — the one-line diff you propose. Never paste a whole log to the caller.
8. **On `recipe`, propose and stop.** Show the diff that would make the procedure followable and ask before writing it. Never edit the recipe to turn a red run green: the cheapest way to pass a check must not be to weaken it.

## Steps — `mode:discover`

1. **Read what the project already says.** The existing recipe, the config, and the manifest's scripts (`package.json`, `Makefile`, `pyproject.toml`, `deno.json`, a CI workflow). **Reading is not deciding** — what exists is the starting point, never the target.
2. **Find the surfaces.** What is this product? A web app, an API, a CLI, a library, a desktop app, a mobile app in a simulator, several of them. Each surface that a change can break gets its own answer — in a monorepo especially, one app having a suite says nothing about its siblings.
3. **Classify each surface, honestly.** Three classes and no fourth:

   | Class | Means | Becomes |
   |---|---|---|
   | `runtime` | something already drives the running product — e2e, integration, a smoke script | a section that wraps it |
   | `unit-only` | tests exist, but they never start the product | an **uncovered** section |
   | `none` | nothing | an **uncovered** section |

   **A unit test is not a dogfood path**, and neither is `lint`, `tsc`, or `build`: they never start the product. Recording one as coverage is the failure this step exists to prevent — it makes an untested app look tested, and nobody can tell afterwards that the gap was never closed.
4. **Ask, one surface at a time.** With what you found: *"`web`, `api`, and `admin` have no runtime path — `web` has Playwright, the other two only unit tests. Set up a runtime check for `api` and `admin`?"* The options are wrap an existing suite, add a small runtime check to the recipe (boot plus one assertion, a curl, a screenshot — the project's call), or leave it uncovered and say so. **Never leave a surface uncovered silently, and never fill the gap with what happens to exist.**
5. **Write the recipe, gaps included.** An uncovered section ends with `**Prove it:** none` — explicitly, so a plan keeps its rows `Manual` and a reader sees the hole. Name the uncovered surfaces in the header too (`**Uncovered:** api (unit tests only), admin (nothing)`), so the gap is visible without reading every section.
6. **Try it, then write down what worked.** Bring the product up, run the proof, watch it fail at least once if you can arrange it — a check nobody has seen fail is not a check — then write the steps exactly as they succeeded, with the `Expect` each one actually produced. Write instructions, not recipes for one tool. **A bring-up step must not mutate dependencies**: install frozen where the project has a lockfile, and treat a broken lockfile as `env` rather than repairing it.
7. **Report.** Per surface: its class, its proof, whether it was asked about, and what is still unknown, plus the uncovered list. Say plainly that `sassy-setup` flips `dogfood.enabled` and that the switch alone changes nothing.

## Steps — `mode:check`

Run the `sassy-setup` skill's `scripts/detect.sh --root <path> --check` and report the `dogfood` and recipe lines verbatim; print the newest report's `status`, `class`, and timestamp, or that there is none. Write nothing.

## Hard rules

| Rule | Requirement |
|------|-------------|
| The verdict is an exit code | A section's `Prove it:` step decides. Never a judgement, a screenshot someone liked, or "looks right". |
| No tooling, no installs | Never name or require a browser, driver, emulator, or MCP server; never install one to make a run possible. Missing tooling is `class: env`. |
| Never production | Local or staging only. A recipe step pointing at production is refused and reported, not run. |
| The run may not edit the check | A red run never fixes itself by editing the recipe or its expectations. Propose the diff, ask, stop. |
| Reports stay local | Never commit `reports/`. Never paste a full log to a caller, a plan, or a PR. |
| No secrets, ever | Env var **names** only, and session material stays in the gitignored `.sassywares/session/`. Mask values before a log is written, and never echo one in a report. |
| Env is not code | Exit 75/127, a missing dependency, or an unreachable service is `env`: report and park. Looping on a broken toolchain burns a run for nothing. |
| Resume, don't restart | Re-run from the failed step; the summary says where. Starting over hides the state that made the failure happen. |
| Reports are disposable | Pruned to ten. The durable record is the QA row's note, which names the verdict and the run id, never a path that will vanish. |
| Never promote what exists | A unit test, `lint`, or `build` is not a dogfood path. Discovery records what the product needs, and says so when that is nothing yet. |
| Ask about every gap | Each uncovered surface gets one question: wrap a suite, add a runtime check, or leave it uncovered and visible. Silence is how a gap becomes a false green. |
| No third-party mutation | A run never registers a user, sends mail, charges a card, or writes to a shared service it does not own. A public demo API is somebody else's database. |
| No dependency churn | A bring-up never changes a lockfile. Install frozen where the project has one; a broken lockfile is `env`, not something to repair mid-run. |
| Not a test framework | If the project has a suite, the recipe wraps it. This skill never grows assertions of its own beyond a step's `Expect`. |

## What dogfood is not

Not a test-authoring skill, and not a CI replacement: CI runs your suite on every push, dogfood runs *this* change against the running product once, and its job is to hand back a verdict the plan can trust. Not a harness either — it does not drive the agent, retry until green, or decide when work is done; `sassy-work` owns the gate and `sassy-cycle` owns the fix.

Not a reason to skip a human. Anything subjective, physical, irreversible, or unobservable stays a `Manual` QA row: a false `Auto` pass is unrecoverable, a manual row is merely slower.
