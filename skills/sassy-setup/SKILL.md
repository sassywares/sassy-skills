---
name: sassy-setup
description: >-
  Detect a project's topology and wire it for the Sassy Skills suite: write
  .sassywares/config.yaml, check for the suite's skills and the sassy-agents
  subagents and install whichever is missing in user or project scope, and
  install the snapshot tooling in a multi-repo workspace.
  Use when asked to set up or configure a project, or to check an existing
  setup (`mode:check`).
argument-hint: "[path] [mode:init|check]"
---

# Sassy Setup

**Outcome:** `.sassywares/config.yaml` at the project root matching the tree it describes, the dogfood scaffold when agent QA was asked for, the skills installed in user or project scope and visible to the harness, the sassy-agents roster installed for the running harness, the snapshot tooling installed in `workspace` mode, and every file setup wrote committed — so the project is wired and the user is good to go in one run. A `check` run produces the same knowledge as a report, and changes nothing except committing setup-owned files that were already dirty.

**Read `references/config.md` first.** It is the schema and the resolution rules; this skill only decides and writes.

**Never a repo by force.** Setup records topology, it does not change it. No `git init`, ever.

**Harness.** Loading another skill, dispatching an agent, and any command you hand the user follow `references/harness.md`; the agent wiring in step 5 of the init path uses its tables.

**The rest of the suite's shared references.** `references/branching.md` is how a run picks a branch and a base — setup records it here, every run reads it there. On the init path, `references/init.md` points at `references/worktree.md`, `references/dogfood.md`, and `references/workspace.md` when an answer or a topology needs them; a check run needs none of the three.

## Modes

| Mode | Load | It ends with |
|---|---|---|
| `init` (default) | `references/init.md` — steps 1–6, then the shared steps below | a wired, verified, committed project |
| `check` | `references/check.md` — step 7 onward, its own way | a report of drift and scope; no config and no tree written |

The argument names the mode: `mode:init`, `mode:check` (or `--check`, the older spelling). A run with no mode that finds a `.sassywares/config.yaml` walking up is a **check** run — a folder that is already wired is verified, never rebuilt from detection. Read the one reference for that mode **and only that one**; steps 7–9 below are shared and run in both.

A check run never edits the config and never rewrites the tree. Its only possible write is step 8 committing setup-owned files that were already dirty. A fix is an `init` run, where each change is shown and approved first.

## Steps 7–9 — shared by both modes

7. **Verify.** Run `scripts/detect.sh --root <path> --check`. It validates the config against the tree — topology and remotes, `base_map` shape and cycles, `repos` against each nested repo, hooks, artifacts paths, `knowledge`, `pr.*` booleans, `commit.branch`, the `worktrees` block, the top-level `up`/`down` pair (accepted there, and a stray nested `up.*`/`down.*` is an unknown key), the `dogfood` block, any unknown key, and in `workspace` mode the installed snapshot's version — plus, for a project-scope install, the pin: every suite-skill folder in `.agents/skills` (a name in the suite's roster, `assets/roster` in sassy-setup, not any `sassy-` prefix) hashed against `skills-lock.json`, the lock's coverage both ways, and whether git carries the lock. A user-scope install has no pin here; the check notes the scope it found. Report every `drift:` line verbatim, or that the config matches the tree. Drift blocks step 8.

   The `worktrees` half checks what a run would read: the switch, that the tooling is installed with the shipped bytes, that no checkout sits inside the working tree, and that none holds a branch `base_map` names as a base.

   The `dogfood` half is structural and never runs the product: `enabled` and `timeout` are in range, the two paths are relative and stay inside the project, `reports` and `.sassywares/session` are gitignored in a `repo` topology, and the recipe has a `**Prove it:**` line per section with an `**Expect**` per step and no secret-shaped string. A recipe that does not exist yet is a note, not drift — unless `enabled` is `true`, which is the one combination that would let a planner write Auto rows against a check nobody has.

   Then check the skills and the agents exactly as step 5's **Installed** rules say, and report the scope each was found in or what is missing. Step 7 never installs anything: a missing suite or roster is reported with the fix (`mode:init`), and it does not block step 8.

8. **Commit what setup owns.** `repo` topology only, and only when step 7 is clean. The file list is exactly what setup wrote or found unwritten:

   `.sassywares/config.yaml`, `.sassywares/README.md`, `.sassywares/dogfood/recipe.md` and `.sassywares/.gitignore` when step 4 created them, the `up`/`down` stubs step 4 wrote (only those two named scripts — never their directory), `.sassywares/worktree/*` when step 6 installed the tooling, the runner file when the user accepted aliases in it, `.agents/skills/sassy-*` and `skills-lock.json` when the suite is in project scope, the project-scope agent files when step 5 copied them, and a root `.gitignore` when step 5 created one. Named files only — never `git add -A`, never `git add .`. The reports directory is never in this list: it is gitignored, and nothing setup writes lives there.

   Dispatch `sassy-commit` with that list and `branch:current`. The token is explicit, not this skill's default: wiring is a one-time bootstrap commit, and cutting a branch would leave the project configured but uncommitted until someone ships it. Name the branch it landed on, base branch included.

   **Nothing else** unless the user asks: a plan, a doc, a source file, or anything already dirty in the tree stays uncommitted, because setup's commit is not a place to launder work in progress. A user who says "commit my plan too" widens the list with the file they named — never with a sweep for it. On a `check` run this fires only when something setup owns is dirty: an uncommitted pin, a config edited since the last commit, a scaffold nobody committed. Nothing dirty, nothing to commit.

   - **`workspace`** — nothing to commit: the root is not a repo, and `references/workspace.md` forbids running the snapshot here. Say the root config and the pin land with the project's next snapshot.
   - **`none`** — nothing to commit, deliberately.

9. **Report.** The config path, the topology, the resolved artifact and knowledge paths, the lifecycle — the two values `up` and `down` name, or one line saying the project declares **no lifecycle** because the keys are absent, with no suggestion attached — whether agent QA is **off** — one line saying every QA row stays a human's, with no suggestion attached — or on, and then whether the recipe is ready or still a skeleton until `sassy-dogfood mode:discover` runs, where the skills are installed (scope) and where the agents are (scope and harness), or why either is not, the commit (hash and branch) or why there is none, and in `workspace` mode what was installed, with versions (`snapshot vN`, `workspace-git vN`), and where the `worktree:*` / `workspace:*` aliases went, or that none were wired because the project has no command-building file to put them in — naming the scripts' path instead, since that is how they are run either way. Remind: `/reload` so the harness rescans. Close with what is left over — at most dirt setup deliberately did not commit — and nothing else: a clean setup leaves the user good to go.

## Hard rules — every mode

| Rule | Requirement |
|------|-------------|
| No `git init` | Setup never turns a folder into a repo, and never does remote or ref surgery. The step 8 commit is its only git write. |
| Verify before commit | A config that fails `--check` is reported, never committed. |
| Commit only what setup owns | The config, the setup README, the `up`/`down` stubs step 4 wrote, the vendored `sassy-*` folders and `skills-lock.json` (project scope), the project-scope agent files, and a `.gitignore` setup created. Never a file the user wrote or the repo already had, unless they name it. |
| No silent overwrite | An existing config or an existing `.sassywares/workspace/snapshot` is shown and asked about, never replaced blind. |
| Write boundary | Only `.sassywares/` (the config, the setup README, the dogfood scaffold, and the worktree tooling), the two `up`/`down` stubs step 4 wrote at their probed path, the skills and agent files step 5 installed in the scope the user chose, `skills-lock.json` (project scope), `.sassywares/.gitignore` with its two lines, and at most one root `.gitignore` line that step 5 created. Never `package.json` outside step 6's `worktree:*` and `workspace:*` aliases, never a root `.gitignore` in a workspace. Workspace git helpers land in `.sassywares/workspace/`, never in a project's `bin/`. |
| Install the tooling, never use it | Setup copies `.sassywares/worktree/` and offers the aliases. It never creates a checkout, never runs a script, and never starts or stops the project's stack — `up` is the project's or the user's, and `down` runs only from `remove`. |
| Skills come from upstream | Install with `npx skills add`, `-g` for user scope; never hand-copy skill files or maintain the links yourself. |
| Agents come from sassy-agents | Only the running harness's folder, as-is: linked by `install.sh` (user scope) or copied verbatim (project scope). Never edit, merge, or overwrite a differing agent file without asking. |
| Never edit the manifest | No dependencies, no `postinstall`, no `skills:*` scripts. Step 6's `worktree:*` and `workspace:*` aliases may be added, and only into a file that already carries named commands: appended or corrected, never removed, nothing else in the file touched, and **never a manifest created to hold them**. A project with no such file gets no aliases and loses nothing — the scripts are run by path. Setup installs the suite; the user or project decides how it updates. |
| Run output and sessions never ship | `.sassywares/.gitignore` holds `/session/` and `/dogfood/reports/`. Never remove a line, never add anything from either path to the commit, and never write a credential anywhere else. |
| No secrets in setup's writes | Env var names only, in the config and in the skeleton. A credential never lands in a file setup commits. |
| Version is reported | Setup names the snapshot and `workspace-git` versions it installed; `--check` flags an installed copy older than the skill's. |
| Repair is `init` | `check` reports drift and never rewrites; closing it is `mode:init`, where every change is shown and approved first. |

## What setup is not

Not a migration tool. A project already using another convention keeps its files; setup records where they already are. There is no rename step, and no fallback to `docs/` behind a configured path.

Not an updater. `check` reports a project pin that is stale or edited; it never moves it. Updating the suite is `npx skills update` (`-g` for user scope), which is the user's or project's decision and not setup's.
