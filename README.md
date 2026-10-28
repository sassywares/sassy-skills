# Sassy Skills

**Lean and mean skills for shipping fast — with full control and 100% reliability.**

Sassy Skills is a suite of explicit-invocation Agent Skills. It follows the Agent Skills format, so it works with any harness that can load `SKILL.md` workflows. Where harnesses differ — how one skill loads another, how agents are dispatched, which command the user types — the skills follow one shared reference, `sassy-setup`'s `references/harness.md`, instead of assuming a harness. The subagents they dispatch come from [sassy-agents](https://github.com/sassywares/sassy-agents), one folder per harness.

It covers the whole path from a rough idea to a shipped PR, and from a bug report to a verified fix — without giving up human control at the moments that matter.

## Table of contents

- [Why this suite](#why-this-suite)
- [Quick start](#quick-start)
- [Skills](#skills)
- [Project config](#project-config)
- [Workflows](#workflows)
  - [From idea to ship](#from-idea-to-ship)
  - [From bug to ship](#from-bug-to-ship)
- [Gates and controls](#gates-and-controls)
- [Branching](#branching)
- [Installation](#installation)
  - [Per project](#per-project)
  - [Globally](#globally)
  - [Both at once](#both-at-once)
- [Repository maintenance](#repository-maintenance)

## Why this suite

- **Lean.** Skills are indexes and workflows, not documentation dumps. Detail moves into `references/` only when it is conditionally needed.
- **Explicit.** Every skill but `sassy-ship` runs only when you invoke it; ship may be started by the agent once you approve the work, and its review gate still waits. No silent background behavior.
- **Controlled.** Code approval, manual QA, and ship review are visible gates that all run in sequence. There are two mode tokens, `mode:manual` (default) and `mode:auto`, accepted by `sassy-ship` and `sassy-compound` only; every other skill takes no mode.
- **Reliable.** Work runs through `sassy-cycle` with isolated subagents for implementation, review, validation, and fixes.
- **Context-efficient.** Orchestrators coordinate; subagents do the heavy reading and return compact results.
- **Never surprising.** Nothing is committed just because a step finished. Shipping is its own phase.

## Quick start

Examples use simple slash commands.

An optional first step: `/sassy-setup` detects the project and writes `.sassywares/config.yaml`, so plans, learnings, and PR bases land where your repo actually keeps them. Skipping it is fine — every key falls back to a documented default.

```text
/sassy-plan Add workspace invitations
```

That discussion settles the work, then offers a pick:

```text
Settled. Pick one:
1. Write the plan — docs/plans/<slug>.md, run it later phase by phase
2. Build it, commit, and stop — runs sassy-work, no PR
3. Build it and ship — runs sassy-lfg: commit, PR, babysit
```

Pick 1 to get a plan file, then run one phase at a time:

```text
/sassy-work docs/plans/add-workspace-invitations.md
```

Or take the whole plan through one session:

```text
/sassy-lfg docs/plans/add-workspace-invitations.md
```

For small work that does not need a plan document, choose 2 or 3 at the picker, or invoke the executor directly with the brief:

```text
/sassy-work "Add a copy-link button to the invite modal"
/sassy-lfg "Add a copy-link button to the invite modal"
```

Debugging:

```text
/sassy-debug https://github.com/org/repo/issues/123
```

## Skills

### Planning and execution

| Skill | What it does |
|---|---|
| **`sassy-plan`** | Grills you one question at a time through every branch of the work — pushing back, assuming nothing, sketching UI on request — until nothing is open, then offers three choices: write the plan, build and commit via `sassy-work`, or build and ship via `sassy-lfg`. |
| **`sassy-scout`** | Grounds an area on demand and writes the shared grounding brief other agents read instead of re-exploring. |
| **`sassy-work`** | Executes exactly one plan phase, or one in-context brief, commits after code approval, then hands off the next phase — a brief stops before ship. |
| **`sassy-lfg`** | Executes every phase of a plan, or one in-context brief, then closes out via `sassy-ship` after code approval. |
| **`sassy-cycle`** | Runs one unit of work through implement → review → validate → fix → verify, with at most two verified fix passes. Also reworks finished work from requested changes or failed QA rows. |
| **`sassy-debug`** | Diagnoses a bug, gates the fix, fixes via `sassy-work` (cycle, code approval, commit), then ships. Debug takes no mode and always leaves ship's review gate in place unless you invoke ship yourself with `mode:auto`. |
| **`sassy-handoff`** | `mode:write` (default) writes a self-contained handoff file to `/tmp/sassywares/<harness>/handoffs/` and gives you a `sassy-handoff mode:read <path>` command for a fresh session; `mode:read` explains what the handoff did, why, and where things stand now, then asks what to do next. Works in any harness. |

### Code quality

| Skill | What it does |
|---|---|
| **`sassy-review`** | Reviews a diff, branch, PR, or files for bugs, project-rule conformance, and design-system conformance, then offers to fix findings. |
| **`sassy-validate`** | Checks whether work matches a plan or stated intent, then offers to close gaps. |

### Shipping

| Skill | What it does |
|---|---|
| **`sassy-ship`** | Compound learnings, optional handbook, commit, PR, and babysit (under `commit.branch: current`: commit and push, no PR). Review gate in `mode:manual` (default), skipped by `mode:auto`. |
| **`sassy-commit`** | Creates a local commit with a clear message. No push, no PR. |
| **`sassy-commit-push-pr`** | Commits, pushes, opens or updates a PR, and babysits by default. |
| **`sassy-babysit`** | Watches a PR until it looks merge-ready or blocked. |

### Knowledge and docs

| Skill | What it does |
|---|---|
| **`sassy-compound`** | Records a solved problem as a durable repo learning. Takes `mode:manual` or `mode:auto`; ship passes `mode:auto` after its own gate. |
| **`sassy-handbook`** | Writes a plain-English team handbook with mermaid diagrams. |

### Meta

| Skill | What it does |
|---|---|
| **`sassy-skill`** | Creates, retunes, or restructures Agent Skills. |
| **`sassy-setup`** | Detects the project topology and writes `.sassywares/config.yaml`; installs the suite and the sassy-agents subagents, globally or per project, when missing; installs the snapshot tooling for a multi-repo workspace; commits the files it wrote. `mode:check` verifies an existing setup, including a project install's pin. |

## Project config

Every skill resolves one file, `.sassywares/config.yaml`, found by walking up from where you are. It is optional — no file means the documented defaults.

```yaml
artifacts:                       # where plans, learnings, handbooks, and the glossary live
  plans: docs/plans
  solutions: docs/solutions
  handbooks: docs/handbooks
  concepts: CONCEPTS.md
knowledge:
  read: [docs/solutions, CONCEPTS.md]   # searched for prior learnings
  write: true                           # false = this project takes no learnings
git:
  repo: origin                   # a remote name | workspace (repos below, none here) | none (no git)
  base_map:                      # head branch -> the base it targets
    "*": staging                 # ordinary work branches from and targets staging
    staging: main                # staging releases to main
  # remote: owner/backup         # workspace only: the snapshot mirror
  # mirror_branch: main          # workspace only: the mirror's branch
repos:                           # workspace only: each nested repo -> the base its PRs target
  fe: dev
commit:
  branch: current
pr:
  babysit: true
  merge: false                   # true authorizes merging every babysat PR here
  delete_branch: false
hooks:
  pr:
    "*":                         # keyed by the PR's HEAD branch
      before_create: [tap2-version mode:auto]   # after the commit, before the PR opens
      after_create: []           # the moment the PR exists
      before_merge: []           # this run is about to merge
      after_merge: []            # this run observed the merge
    staging:                     # a per-point override for one head
      before_create: []
```

### Extending the pipeline

A project adds its own steps by naming a skill that lives in its own `.agents/skills/`. Nothing declared means nothing runs. Keys are the **head** branch — the one a PR comes from — and every point can be overridden per head; entries may carry args (`<skill> <args…>`).

| Hook | Runs | Typical use |
|---|---|---|
| `before_create` | after the commit, before the PR opens | release artifacts: changeset, release notes, i18n sync |
| `after_create` | the PR was just created | labels, deploy-target comment |
| `before_merge` | this run is about to merge | a final approval gate |
| `after_merge` | this run observed the merge | sync a back-merge branch, tag, notify |

Hooks run in declared order, one subagent each, and fail closed: a declared skill that is missing or returns `blocked` stops the run. Only `before_create` may commit its own output, because it runs after the pipeline's commit. `before_merge` and `after_merge` never fire unless this run merges.

This is deliberately not a fork mechanism. A project skill that *adds* a step is a hook; one that *restates* our steps is a copy, and copies rot. Rules are not hooks either — those belong in `AGENTS.md`.

Precedence is always explicit token > session instruction > config > skill default. `sassy-setup` writes the file from the tree it detects and keeps `pr.merge` off unless you say otherwise. The full schema, resolution chains, and the three topologies are in [`skills/sassy-setup/references/config.md`](skills/sassy-setup/references/config.md).

In a `workspace` there is exactly one ignore file, and it is not at the root:

```text
.sassywares/
├── config.yaml
└── workspace/
    ├── snapshot      installed by sassy-setup
    ├── .gitignore    what the snapshot leaves out
    └── mirror/       the side clone, excluded by the script itself
```

## Workflows

### From idea to ship

```mermaid
flowchart LR
  A[Idea] --> B[sassy-plan]
  B --> C[Discussion]
  C --> D{3-option picker}
  D -->|1. plan document| E[docs/plans/slug.md]
  D -->|2. build, commit, stop| F[sassy-work]
  D -->|3. build and ship| G[sassy-lfg]
  E --> F
  E --> G
  F --> H[sassy-cycle]
  G --> H
  H --> I{Code approval}
  I -->|changes| H
  I --> Q{Manual QA}
  Q -->|fails| H
  Q -->|passes, via sassy-work| J[Commit on the run branch and stop]
  Q -->|passes, via sassy-lfg| K[sassy-ship]
  K --> L{Ship review}
  L -->|approve or mode:auto| M[Commit, PR, babysit]
```

Option 1 produces a durable plan with phased slices and manual QA tables. Options 2 and 3 keep the whole job as one settled in-context brief and write no plan file.

`sassy-work` handles one phase and hands off the next. `sassy-lfg` drains the whole plan in one session. Both delegate to `sassy-cycle` and stop at one gate carrying code approval plus the manual QA checklist; nothing is `Done`, committed, or shipped until both pass. With an in-context brief there are no QA rows, so the gate is code approval alone.

Inside the cycle, every finding is fixed and then **verified**: a reviewer scoped to the fix confirms each finding resolved, and checks the fix itself for anything new. Whatever is still open gets a second fix pass; anything open after that comes back `blocked` rather than looping. Critical findings and warnings are fixed automatically; the reviewer's suggestions are listed at the gate for you to pick. Changes you request at the gate and QA rows that fail go through the same loop as findings, then the gate comes back.

The branch is cut once, before the first change, by `sassy-work` or `sassy-lfg` — never at commit time — and `sassy-ship` never creates it. `commit.branch` (default `new`) decides whether the run cuts one at all; see [Branching](#branching).

`sassy-ship` is the close-out. It summarizes what is about to ship and waits, unless the caller passed `mode:auto`.

### From bug to ship

```mermaid
flowchart LR
  A[Bug or issue] --> B[sassy-debug]
  B --> C[Triage]
  C --> D[scout helper]
  D --> E{Fix gate}
  E -->|1. fix it now| F[sassy-work]
  E -->|2. write a plan| G[sassy-plan]
  E -->|3. hand off| H[sassy-handoff]
  E -->|4. stop| I[Diagnosis only]
  F --> J{Code approval}
  J -->|changes| F
  J -->|approved| N[Commit]
  N --> K[sassy-ship]
  K --> L{Ship review}
  L -->|approve| M[Commit, PR, babysit]
```

`sassy-debug` diagnoses inline, using the read-only `scout` as a helper to ground the failure surface; the causal reasoning stays in the main context. It then stops at the fix gate with the causal chain, proposed fix, and risks.

The fix gate offers four options:

- **Fix it now** — hand the fix brief to `sassy-work`: one cycle, the code approval gate, a commit; then debug ships it via `sassy-ship`
- **Write a plan** — carry the diagnosis into `sassy-plan`, which ends in its own 3-option picker
- **Hand off** — continue in a fresh session via `sassy-handoff`
- **Stop here** — keep the diagnosis and change nothing

`sassy-debug` takes no mode. Shipping keeps its own `mode:manual` gate unless you invoke `sassy-ship` yourself with `mode:auto`.

## Gates and controls

| Control | When it applies |
|---|---|
| Code approval | Always on for `sassy-work` and `sassy-lfg`. |
| Manual QA | Part of the same gate, and only when the plan document has QA tables. The user runs the rows; a phase is `Done` only when both pass. |
| Ship review | On in `mode:manual` (default), skipped by `mode:auto`. |

The artifact decides QA: a plan document carries manual QA tables that gate phase completion, an in-context brief does not. Gates are deliberate stops; the only way past one is the user's approval. `mode:auto` is accepted only by `sassy-ship` and `sassy-compound`.

## Branching

`sassy-work`, `sassy-lfg`, and `sassy-debug` decide the branch **before they touch code**, from `commit.branch` (default `new`) compared against `base_map`. On `new`, the run cuts a branch and every commit — phases, docs, ship — lands on it, so no change ever exists on a base branch. A run that is already on a branch that is not a base reuses it, which is how a handed-off phase, a resumed run, or `sassy-lfg` after `sassy-work` converges instead of cutting a second branch.

A base is **any `base_map` value**, not just the remote default: in a repo whose `"*"` targets `staging`, standing on `staging` counts as standing on a base. That distinction is the whole point of the key — see [`skills/sassy-setup/references/branching.md`](skills/sassy-setup/references/branching.md).

The three skills take `branch:infer|current|new` to override the config's branching for one run (the no-PR close-out follows the config `commit.branch: current` regardless of the token): `infer` (default) means the config decides, `new` forces a branch, `current` commits where you stand; it does not skip the PR. Only `commit.branch: current` in the config makes the close-out push to the upstream with no PR, hooks, or babysit. `sassy-ship` never creates a branch; finding the head on a base branch with unpublished commits is a stop-and-ask, except under `commit.branch: current`, where they are pushed along.

## Installation

The suite installs from this repository with the open `skills` CLI. Install it per project, globally, or both.

### Per project

The team's setup. The CLI vendors the skill files into the project and pins them, so a clone needs no network and every checkout runs the same skills.

```bash
npx skills add sassywares/sassy-skills
```

That writes three things:

- `.agents/skills/sassy-*` — the skill files themselves, read by pi and Cursor
- `.claude/skills/sassy-*` — links for Claude Code, which reads only its own directory
- `skills-lock.json` — source and content hash per skill

Commit the vendored skills and the lock; ignore `.claude/skills`, which is a link created at install time.

```bash
npx skills update -p -y           # pull the latest from this repo
npx skills experimental_install   # restore exactly what the lock pins
npx skills remove --all           # take the suite out again
```

`npx skills check` is an alias for `update`: it moves the pin, it does not validate it. To check a project's setup without touching the pin, run `sassy-setup` with `mode:check`.

### Globally

Your own setup, in every project on this machine, with nothing committed anywhere.

```bash
npx skills add sassywares/sassy-skills -g
```

That writes:

- `~/.agents/skills/sassy-*` — the skill files, read by pi and other harnesses that use `~/.agents/skills`
- `~/.claude/skills/sassy-*` — links for Claude Code
- `~/.agents/.skill-lock.json` — the global lock

```bash
npx skills update -g -y           # pull the latest from this repo
npx skills remove -g --all        # take the suite out again
```

A global install is yours alone: teammates do not get it, and it moves whenever you update rather than with the project.

### Both at once

A skill installed in both places is listed once, not twice; the harness picks one copy. Claude Code prefers the global copy over the project's, so on a machine with a global install the project's pin does not decide which version Claude Code runs. Other harnesses apply their own precedence. When a project's pinned version must be the one that runs, skip the global install on that machine.

`sassy-setup` handles either scope, the same way it handles the agents: if the suite is already installed it reports where, and if not it asks where to install it, recommending global. A project install also gets the ignore line, the verified pin, and the commit. `mode:check` verifies the pin only for a project install; a global one has nothing to pin.

### While editing the suite

`.pi/settings.json` in this repo declares `./skills`, so pi loads your working copy directly. Consumers see a change once it is pushed to `main` and they run `npx skills update` — no release step in between.

### Also published as a package

`@sassywares/skills` is on npm for harnesses that install packages rather than skill directories:

```bash
pi install npm:@sassywares/skills
```

## Repository maintenance

Any agent that changes a skill runs `scripts/sync.sh` immediately, which commits, pushes, and — on `main`, when shipped files changed — bumps the patch version and tags the release that publishes `@sassywares/skills` to npm. [`AGENTS.md`](AGENTS.md) is the full guide: layout, adding a skill, sync, and the manual release fallback.
