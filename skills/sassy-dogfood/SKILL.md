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

**Outcome:** a report with a verdict — `pass`, `failed` with the failing step and its output tail, or `env`/`recipe` explaining why the run could not judge the work — in `.sassywares/dogfood/reports/<run-id>/`; or, in `mode:discover`, a `recipe.md` a fresh agent can follow with no other context; or, in `mode:check`, a lint and the last verdict, printed.

**A procedure is the artifact.** The project stores how to dogfood itself in `.sassywares/dogfood/recipe.md`: ordered steps, each with an observable expectation, ending in one `Prove it:` step whose exit code is the verdict. The config points at it; it never restates it. Read the `sassy-setup` skill's `references/dogfood.md` first — it owns the recipe format, the report layout, and the verdict classes, and this skill only executes them.

**Config.** Resolve `.sassywares/config.yaml` (nearest, walking up) per the `sassy-setup` skill's `references/config.md`. `dogfood.enabled`, `dogfood.recipe`, `dogfood.reports`, and `dogfood.timeout` are the only inputs. Precedence: explicit token > session instruction > config > skill default.

**No tooling.** This skill names no browser, driver, emulator, or MCP server, and it never installs one. A step says *what to do and what to see*; how the agent satisfies that is discovered at run time from what the harness already offers, and a plain command is often the better answer.

**Harness.** Loading another skill, dispatching an agent, and any command you hand the user follow the `sassy-setup` skill's `references/harness.md`. Read it once per run, before the first of those.

## Modes

| Mode | Load | It ends with |
|---|---|---|
| `run` (default) | `references/run.md` | a verdict from a report, returned compactly |
| `discover` | `references/discover.md` | a `recipe.md` proven by a clean run, with every gap visible |
| `check` | `references/check.md` | a printed lint and the last verdict; nothing written |

Resolve the mode: an explicit `mode:` token wins. With none, it is `run`; a request to check or lint the setup is `check`, and a request to build, repair, or set up the procedure is `discover`. Read the one reference for that mode **and only that one**.

`run` never edits the recipe, and `discover` never gates anything: it produces a recipe, and the next `run` is what proves it. Only `discover` improvises; a run executes what the recipe names, classifies what it cannot, and stops.

## Hard rules — every mode

| Rule | Requirement |
|------|-------------|
| The verdict is an exit code | A section's `Prove it:` step decides. Never a judgement, a screenshot someone liked, or "looks right". |
| No tooling, no installs | Never name or require a browser, driver, emulator, or MCP server. **What the recipe names is allowed** — if *Set up once* says `bun install --frozen-lockfile` or downloads the browser its suite declares, that is the project's declared bring-up and a run executes it. Installing anything the recipe does not name is out of bounds, and so is choosing a tool the project has not committed to. A permitted command's own lifecycle hooks (a `postinstall`) come with it; the run adds none of its own. |
| Never production | Local or staging only. A recipe step pointing at production is refused and reported, not run. |
| No secrets, ever | Env var **names** only, and session material stays in the gitignored `.sassywares/session/`. Mask values before a log is written, and never echo one in a report. |
| No third-party mutation | A run never registers a user, sends mail, charges a card, or writes to a service it does not own — a public demo API is somebody else's database. **A project-owned test environment is the exception**: an E2E deployment the project built, seeded by its own provisioning script and named in `**Upstream:**`, is the project's call. Production never is. |
| Reports stay local and disposable | Never commit `reports/`, which are pruned to ten. Never paste a full log to a caller, a plan, or a PR. The durable record is the QA row's note, which names the verdict and the run id, never a path that will vanish. |

## What dogfood is not

Not a test-authoring skill, and not a CI replacement: CI runs your suite on every push, dogfood runs *this* change against the running product once, and its job is to hand back a verdict the plan can trust. Not a harness either — it does not drive the agent, retry until green, or decide when work is done; `sassy-work` owns the gate and `sassy-cycle` owns the fix.

Not a reason to skip a human. Anything subjective, physical, irreversible, or unobservable stays a `Manual` QA row: a false `Auto` pass is unrecoverable, a manual row is merely slower.
