# Mode: discover — build or repair the recipe from what really worked

Read the shared sections in `SKILL.md` first (the recipe artifact, config, no-tooling, and the every-mode rules). This file is the discover path only. The recipe format is the `sassy-setup` skill's `references/dogfood.md`; you are writing that file, not executing it.

## 1. Read what the project already says

The existing recipe, the config, and the manifest's scripts (`package.json`, `Makefile`, `pyproject.toml`, `deno.json`, a CI workflow). **Reading is not deciding** — what exists is the starting point, never the target.

## 2. Find the surfaces

Read `**Out of scope:**` first and drop those from the list — they were decided against, and asking again is how a decision gets reopened every week. `**Uncovered:**` surfaces stay: they still want a path.

Then: what is this product? A web app, an API, a CLI, a library, a desktop app, a mobile app in a simulator, several of them. Each surface that a change can break gets its own answer — in a monorepo especially, one app having a suite says nothing about its siblings. **A surface is something this repository serves**; a backend it calls is not a surface — record it as `**Upstream:**` and let its outages be `env`.

## 3. Classify each surface, honestly

| Class | Means | Becomes |
|---|---|---|
| `runtime` | something already drives the running product — e2e, integration, a smoke script | a section that wraps it |
| `unit-only` | tests exist, but they never start the product | an **uncovered** section |
| `none` | nothing | an **uncovered** section |

**A unit test is not a dogfood path**, and neither is `lint`, `tsc`, or `build`: they never start the product. Recording one as coverage is the failure this step exists to prevent — it makes an untested app look tested, and nobody can tell afterwards that the gap was never closed.

## 4. Ask, one surface at a time — and stop until answered

With what you found: *"`web`, `api`, and `admin` have no runtime path — `web` has Playwright, the other two only unit tests. Set up a runtime check for `api` and `admin`?"* The options are wrap an existing suite, add a small runtime check, or leave it uncovered and say so. **This step blocks steps 5–8**: the answer decides what gets written, so with no user to ask, stop and report the question verbatim — never write a recipe on a guessed answer. Never leave a surface uncovered silently, and never fill the gap with what happens to exist.

A **small runtime check is in scope**: a boot plus one assertion, a `curl`, a screenshot diff — written into the recipe as steps. That is not a test framework, and it is the only check this skill authors. Installing a driver or a runner to make one possible is out of bounds; without one already present, the surface is uncovered.

## 5. Write the draft, one section per surface, gaps included

With more than one surface, that surface's `**Preview:**` and `**Upstream:**` go **inside its own section** — a file-level address on a multi-app project can only describe one app. With exactly one surface, keep the file flat. Every surface in the inventory gets a section: an uncovered one ends with `**Prove it:** none`, explicitly, so a plan keeps its rows `Manual`; an out-of-scope one gets no section at all. Name both lists in the header (`**Uncovered:** api (unit tests only)` / `**Out of scope:** admin`) so the gaps are visible without reading every section.

## 6. Run it, and log every deviation

Bring the product up and run the draft. Anything you do that is **not a step in the recipe** — an install, an export, a patch, a workaround, a second terminal — is a *deviation*, written down as you go. This is the only step where improvising is allowed, and it is never silent.

## 7. Reconcile

Every deviation becomes exactly one of two things: a step in the recipe, or the reason this surface is unprovable (`**Prove it:** none`). A recipe whose check passed only with help the recipe does not contain is wrong. If you cannot capture a deviation as a step, the surface is uncovered — say so rather than shipping a procedure nobody else can follow.

## 8. Prove the procedure, not the day — with a fresh agent

Hand the recipe to a run that has **nothing but the recipe and the config**: a new session, or a dispatched agent, but never this one. It is run once from a clean checkout, allowing no deviation. If you cannot get one, say the recipe is **unverified** rather than claiming it. That second run is the artifact. If it needs improvising, the recipe is wrong: fix it and repeat once; still failing means uncovered and visible.

## 9. Report

Per surface: its class, its proof, whether it was asked about, the deviations you reconciled, and what is still unknown. Mark a check you wrote as **unproven** if you never watched it fail — breaking the thing once is the way to earn that. Say plainly that `sassy-setup` flips `dogfood.enabled` and that the switch alone changes nothing.

## Rules for this path

| Rule | Requirement |
|------|-------------|
| Improvise out loud, or not at all | Discovery may improvise, never silently: every action that is not a step is a deviation, and every deviation is promoted into a step or kills the surface. |
| The second run is the artifact | A recipe is proven by a clean checkout that has nothing but the recipe. If it only works with the discoverer's context, it does not work. |
| Ask about every gap | Each uncovered surface gets one question: wrap a suite, add a runtime check, or leave it uncovered and visible. Silence is how a gap becomes a false green. |
| Never promote what exists | A unit test, `lint`, or `build` is not a dogfood path. Discovery records what the product needs, and says so when that is nothing yet. |
| Not a test framework | If the project has a suite, the recipe wraps it. Discovery never grows assertions of its own beyond a step's `Expect`. |
