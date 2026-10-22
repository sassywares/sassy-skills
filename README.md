# Sassy Skills

**Lean and mean skills for shipping fast — with full control and 100% reliability.**

Sassy Skills is a suite of explicit-invocation Agent Skills. It follows the Agent Skills format, so it works with any harness that can load `SKILL.md` workflows.

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
- [Repository layout](#repository-layout)
- [Installation](#installation)
- [Repository maintenance](#repository-maintenance)

## Why this suite

- **Lean.** Skills are indexes and workflows, not documentation dumps. Detail moves into `references/` only when it is conditionally needed.
- **Explicit.** Every skill is invoked deliberately. No silent background behavior.
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
1. Write it to docs/plans/<slug>.md
2. Start working now — stop before ship
3. Take it all the way — run it, ship it, babysit the PR
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
| **`sassy-plan`** | Brainstorms and settles the work in one discussion, then offers three choices: write the plan, start working now, or take it all the way to a PR. |
| **`sassy-scout`** | Grounds an area on demand and writes the shared grounding brief other agents read instead of re-exploring. |
| **`sassy-work`** | Executes exactly one plan phase, or one in-context brief, commits after code approval, then hands off the next phase — a brief stops before ship. |
| **`sassy-lfg`** | Executes every phase of a plan, or one in-context brief, then closes out via `sassy-ship` after code approval. |
| **`sassy-cycle`** | Runs one unit of work through implement → review → validate → fix → re-check. |
| **`sassy-debug`** | Diagnoses a bug, gates the fix, fixes via `sassy-cycle`, then ships after code approval. Debug takes no mode and always leaves ship's review gate in place unless you invoke ship yourself with `mode:auto`. |
| **`sassy-handoff`** | Summarizes the session and opens a fresh one via `/handoff`, with the continuation prompt seeded in the editor for you to submit. |

### Code quality

| Skill | What it does |
|---|---|
| **`sassy-review`** | Reviews a diff, branch, PR, or files for bugs, project-rule conformance, and design-system conformance, then offers to fix findings. |
| **`sassy-validate`** | Checks whether work matches a plan or stated intent, then offers to close gaps. |

### Shipping

| Skill | What it does |
|---|---|
| **`sassy-ship`** | Compound learnings, optional handbook, commit, PR, and babysit. Review gate in `mode:manual` (default), skipped by `mode:auto`. |
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
| **`sassy-setup`** | Detects the project topology and writes `.sassywares/config.yaml`; installs the snapshot tooling for a multi-repo workspace. |
| **`sassy-compare`** | Runs one prompt against two models in isolated worktrees, with optional per-side thinking levels, and compares output, code changes, timing, tokens, and errors. |

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
  D -->|2. start working| F[sassy-work]
  D -->|3. take it all the way| G[sassy-lfg]
  E --> F
  E --> G
  F --> H[sassy-cycle]
  G --> H
  H --> I{Code approval}
  I -->|changes| H
  I --> Q{Manual QA}
  Q -->|fails| H
  Q -->|passes, via sassy-work| J[Commit on current branch and stop]
  Q -->|passes, via sassy-lfg| K[sassy-ship]
  K --> L{Ship review}
  L -->|approve or mode:auto| M[Commit, PR, babysit]
```

Option 1 produces a durable plan with phased slices and manual QA tables. Options 2 and 3 keep the whole job as one settled in-context brief and write no plan file.

`sassy-work` handles one phase and hands off the next. `sassy-lfg` drains the whole plan in one session. Both delegate to `sassy-cycle` and stop at one gate carrying code approval plus the manual QA checklist; nothing is `Done`, committed, or shipped until both pass. With an in-context brief there are no QA rows, so the gate is code approval alone.

Work always commits to the current branch; `sassy-ship` creates the shipping branch at close-out when the checked-out branch is the repo default.

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
  J -->|approved| K[sassy-ship]
  K --> L{Ship review}
  L -->|approve| M[Commit, PR, babysit]
```

`sassy-debug` diagnoses inline, using the read-only `scout` as a helper to ground the failure surface; the causal reasoning stays in the main context. It then stops at the fix gate with the causal chain, proposed fix, and risks.

The fix gate offers four options:

- **Fix it now** — hand the fix brief to `sassy-work`: one cycle, its own code approval gate, a commit, then a stop before ship
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

## Repository layout

```text
sassy-skills/
├── skills/
│   ├── sassy-plan/
│   ├── sassy-work/
│   ├── sassy-lfg/
│   └── ...
├── scripts/
│   └── sync.sh
├── AGENTS.md
├── CONCEPTS.md
└── README.md
```

## Installation

The suite installs from this repository with the open `skills` CLI. That CLI vendors the skill files into your project and pins them, so a clone needs no network and every checkout runs the same skills.

```bash
npx skills add sassywares/sassy-skills
```

That writes three things:

- `.agents/skills/sassy-*` — the skill files themselves, read by pi and Cursor
- `.claude/skills/sassy-*` — links for Claude Code, which reads only its own directory
- `skills-lock.json` — source and content hash per skill

Commit the vendored skills and the lock; ignore `.claude/skills`, which is a link created at install time.

```bash
npx skills update -y              # pull the latest from this repo
npx skills experimental_install   # restore exactly what the lock pins
npx skills remove                 # take the suite out again
```

`sassy-setup` does all of this for you, including the ignore line and the two package scripts.

### While editing the suite

`.pi/settings.json` in this repo declares `./skills`, so pi loads your working copy directly. Consumers see a change once it is pushed to `main` and they run `npx skills update` — no release step in between.

### Also published as a package

`@sassywares/skills` is on npm for harnesses that install packages rather than skill directories:

```bash
pi install npm:@sassywares/skills
```

## Repository maintenance

`scripts/sync.sh` commits skill changes, rebases on `origin/main`, and pushes. Any agent that changes a skill must run it immediately, without asking for confirmation. It installs nothing anywhere — consumers get a change when they run `npx skills update` after a push. `AGENTS.md` documents the workflow for agents working on this repo.

### Releases

Publishing is tag-driven. The `Publish` workflow (`.github/workflows/publish.yml`) validates every `skills/*/SKILL.md`, checks that the tag matches `package.json`, and publishes `@sassywares/skills` to npm on a `v*` tag push.

```bash
npm version patch --no-git-tag-version
git add -A && git commit -m "chore: release v$(node -p "require('./package.json').version")"
git push origin main
git tag "v$(node -p "require('./package.json').version")"
git push origin --tags
```
