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

**Outcome:** `.sassywares/config.yaml` at the project root matching the tree it describes, the dogfood scaffold when agent QA was asked for, the skills installed in user or project scope and visible to the harness, the sassy-agents roster installed for the running harness, the snapshot tooling installed in `workspace` mode, and every file setup wrote committed — so the project is wired and the user is good to go in one run.

**Read `references/config.md` first.** It is the schema and the resolution rules; this skill only decides and writes.

**Never a repo by force.** Setup records topology, it does not change it. No `git init`, ever.

**Harness.** Loading another skill, dispatching an agent, and any command you hand the user follow `references/harness.md`; the agent wiring in step 5 uses its tables.

## Modes

| Mode | What it does |
|------|--------------|
| `init` (default) | Detect, ask, write, wire, verify, commit, report |
| `check` | Verify an existing setup against the tree and report |

The argument names the mode: `mode:init`, `mode:check` (or `--check`, the older spelling). A run with no mode that finds a `.sassywares/config.yaml` walking up is a **check** run — a folder that is already wired is verified, never rebuilt from detection.

A check run never edits the config and never rewrites the tree: it prints what `detect.sh --check` says, and its only possible write is step 8 committing setup-owned files that were already dirty. A fix is an `init` run, where each change is shown and approved first.

## Steps

1. **Resolve the start and the mode.** The path argument, else the working directory; the mode per above. On `check`, run steps 7 → 8 → 9 and stop.
2. **Detect.** Run `scripts/detect.sh --root <path>`. It prints a proposed config: topology (`repo`, `workspace`, `none`), the remote name, a probed base branch, and nested repos with their bases.
3. **Ask only what detection cannot answer.** Never re-ask what the tree already said.
   - **`workspace`** — the snapshot mirror: create a **private** GitHub repo, or connect an existing one? Creating it needs explicit approval and a named slug first.
   - **`none`** — confirm the intent: this folder is deliberately outside git, so commit, PR, and babysit refuse here.
   - **Artifacts** — offer the detected paths as the default; take overrides.
   - **Knowledge** — `knowledge.read` defaults to the solutions dir plus the concepts file. Ask whether there are extra folders to read (a hand-written `notes/learnings/`, a `docs/adr/`).
   - **Base map** — detection proposes `"*"` from the probed remote default. Ask where ordinary work branches from, and whether the default branch itself releases to another branch (a `staging: main` rung). Never write `main` as a guess. In `workspace` mode, show the `repos` map and get a yes on every row — a probed base is only the remote's default.
   - **`commit.branch`** — default `new`: the run cuts a branch before the first change and never commits on a base branch. Offer `current` for a repo that genuinely wants work committed where it stands, and say plainly that `current` lets a run commit onto its base branch and push it, with no PR (`pr.*` and `hooks.pr` are ignored; `hooks.push` runs). Under `mode:auto` with `current` on a base branch, ship pushes to that base with no gate.
   - **`pr.*`** — default `babysit: true`, `merge: false`, `delete_branch: false`. Say plainly that `merge: true` authorizes merging every babysat PR in this project without asking.
   - **Hooks** — offer, do not impose. Ask whether the project wants steps injected at `before_create`, `after_create`, `before_merge`, or `after_merge` (or `hooks.push` `after_push`, for `commit.branch: current` only), and under which head branch (`"*"` for all). Entries may carry args (`<skill> <args…>`); a hook skill's args are its own vocabulary. Leave them `[]` when there is nothing to add. **Never write a hook skill yourself** — hooks are project skills, and copying one of ours into that role is the fork this mechanism exists to prevent.
   - **Worktrees** — ask whether the project wants parallel work in this repo: a checkout per branch, each with its own derived namespace and port, so two runs never fight over one working tree. Say plainly what it costs and what it needs. `false` — the run works here, which is today's behaviour. `true` — a run may create a checkout, and `sassy-worktree` gains `create`, `list`, `preview`, `remove`, and `prune`. It needs `commit.branch: new`: under `current` nothing ever cuts a branch, so the switch would do nothing — say so and leave it `false` rather than writing a setting that cannot fire. In `workspace` or `none` topology, say it is not available and write `false`. Read `references/worktree.md`; **never write a hook yourself** for the project's checkout prep.
   - **Dogfood** — ask whether the project wants agent QA: a stored procedure that proves a change works in the running product, which then lets `sassy-plan` write `Mode: Auto` QA rows instead of manual ones. Say plainly what each answer means. `false` — every QA row stays a human's, which is today's behavior. `true` — a plan may write Auto rows, but only for a recipe section that carries a `Prove it:` step, so the switch alone never makes a gate prove something. Write the answer explicitly either way; never leave it to inference. On yes, scaffold per step 4. Read `references/dogfood.md` and **never** write a command into the block or author the procedure: the recipe is the project's, and its first real content comes from a `sassy-dogfood mode:discover` run.
4. **Write the config.** Build the file from the proposal plus the answers. It is written **fully commented**: every key keeps a description and its allowed values, exactly as the detector emits them. Never strip those comments to save lines — for a teammate opening the file, the comments are the documentation. If a config already exists, show what changes and ask before writing — never silently overwrite. Keep every key; an unset key falls back to its documented default, so a short file is legal when nothing deviates.

   **The dogfood scaffold, only when the answer was yes.** Create `.sassywares/dogfood/` holding `recipe.md` copied verbatim from `assets/dogfood-recipe.md`, and `.sassywares/.gitignore` with two lines — `/session/` and `/dogfood/reports/` — adding them to a `.gitignore` that already exists rather than replacing it. Never overwrite an existing recipe — show it and ask. The skeleton is deliberately incomplete: it carries the shape and the rules and fills in nothing, because `sassy-dogfood mode:discover` writes the procedure from what actually worked. Say so in the report — `enabled: true` is a permission, not a promise that a check exists.
5. **Wire the skills and the agents.** Both install the same way: if they are already there in either scope, report which and move on; if not, ask once where to install, recommending user scope.

   - **Skills.** The suite comes from upstream with the open `skills` CLI. Never copy skill files in by hand, never add the suite as a dependency.

     **Installed** means the `sassy-*` skills exist in the project scope (`.agents/skills/sassy-*`, pinned in `skills-lock.json`) or the user scope (`~/.agents/skills/`, plus `~/.claude/skills/` for Claude Code). If they do, report which scope and move on. If not, ask once where to install, recommending user scope:

     - **User scope** — every project on this machine, nothing committed, updated with `npx skills update -g`. Run `npx -y skills add sassywares/sassy-skills -g -y`, which writes `~/.agents/skills/sassy-*`, the `~/.claude/skills/sassy-*` links, and `~/.agents/.skill-lock.json`.
     - **Project scope** — only this project, pinned with it. Run `npx -y skills add sassywares/sassy-skills -y`, which writes `.agents/skills/sassy-*` (real files), per-agent links such as `.claude/skills/sassy-*`, and `skills-lock.json`. The vendored folders and the lock are the pin and join step 8's commit list, so a clone needs no network. Ignore `.claude/skills` only — it is a link created at install time. Create `.gitignore` only when there is none, and in `workspace` topology never touch the project's root `.gitignore` at all.

     A project that wants its own pin on a machine that already has the user-scope suite can install in project scope too — say that Claude Code prefers the user-scope copy, so the project's pin does not decide what Claude Code runs there.

     **Do not wire updates.** How and when the suite is refreshed is the user's or the project's decision, not setup's: no `skills:*` scripts, no `postinstall` edit. Mention the update command for the chosen scope and stop there. Note for yourself that `npx skills check` is an alias of `update` — it is not a validator, and running it here would silently move the pin.

   - **Write `.sassywares/README.md`** from `assets/sassywares-readme.md` when absent. Never overwrite it — it may carry project notes.
   - **Agents.** The skills dispatch five subagents by name — `scout`, `worker`, `reviewer`, `simplifier`, `validator` — from [`sassy-agents`](https://github.com/sassywares/sassy-agents), which keeps one folder per harness. Use the row for the harness you are running in:

     | Harness | sassy-agents folder | User scope | Project scope |
     |---|---|---|---|
     | pi | `pi/` | `~/.pi/agent/agents/` | `.pi/agents/` |
     | Claude Code | `claude/` | `~/.claude/agents/` | `.claude/agents/` |

     A harness with no row has no folder in sassy-agents: say so, skip the agents, and name it in the report. Never translate another harness's folder by hand.

     **Installed** means all five `<name>.md` files exist in the user scope or the project scope. If they do, report which scope and move on. If any are missing, ask once where to install, recommending user scope:

     - **User scope** — every project on this machine, updated by `git pull`. Reuse the user's sassy-agents checkout if they have one; otherwise ask where to clone it (`git clone https://github.com/sassywares/sassy-agents.git <dir>`). Then run `<dir>/scripts/install.sh <folder>`, which symlinks the folder into the user scope and never overwrites a differing file.
     - **Project scope** — only this project, pinned with it. Shallow-clone into its own `mktemp -d` under `/tmp/sassywares/scratch/` (two runs share that folder now, per `references/harness.md`), copy `<folder>/*.md` into the project scope directory, delete the clone. Never overwrite an existing agent file that differs: show it and ask. The copies join step 8's commit list.

   - **Tell the user to `/reload`** (or restart the harness). The skills and agents are invisible to the harness until it rescans.

6. **Install the git tooling.** Two independent sets, each only when its answer was yes.

   - **Worktrees, `repo` topology and `worktrees.enabled: true`.** Copy every file in `assets/worktree/` flat into `.sassywares/worktree/` and make the five scripts executable, then add one `worktree:<script>` alias per script to the project's manifest, append-only, exactly as the workspace aliases are. Report the `worktree-version` you installed. **Ask before overwriting any of them when they already exist** — from the first install they are the project's files. Read `references/worktree.md`. Do not create a worktree, and do not run a script: installing is the whole job, and the first `create` belongs to a run or to the user.
   - **Workspace, `workspace` topology only.** The snapshot plus the `branches` / `pull` / `checkout-bases` git helpers, and one `workspace:<script>` alias per script in the project's own manifest. Read `references/workspace.md` and follow it.
7. **Verify.** Run `scripts/detect.sh --root <path> --check`. It validates the config against the tree — topology and remotes, `base_map` shape and cycles, `repos` against each nested repo, hooks, artifacts paths, `knowledge`, `pr.*` booleans, `commit.branch`, the `worktrees` block, the `dogfood` block, any unknown key, and in `workspace` mode the installed snapshot's version — plus, for a project-scope install, the pin: every suite-skill folder in `.agents/skills` (a name in the suite's roster, `assets/roster` in sassy-setup, not any `sassy-` prefix) hashed against `skills-lock.json`, the lock's coverage both ways, and whether git carries the lock. A user-scope install has no pin here; the check notes the scope it found. Report every `drift:` line verbatim, or that the config matches the tree. Drift blocks step 8.

   The `worktrees` half checks what a run would read: the switch and the port range, that the tooling is installed at the shipped version, that no checkout sits inside the working tree, that none holds a branch `base_map` names as a base, and that no port is still claimed by a worktree that no longer exists.

   The `dogfood` half is structural and never runs the product: `enabled` and `timeout` are in range, the two paths are relative and stay inside the project, `reports` and `.sassywares/session` are gitignored in a `repo` topology, and the recipe has a `**Prove it:**` line per section with an `**Expect**` per step and no secret-shaped string. A recipe that does not exist yet is a note, not drift — unless `enabled` is `true`, which is the one combination that would let a planner write Auto rows against a check nobody has.

   Then check the skills and the agents exactly as step 5's **Installed** rules say, and report the scope each was found in or what is missing. A check run never installs them; a missing suite or roster is reported with the fix (`mode:init`), and it does not block step 8.
8. **Commit what setup owns.** `repo` topology only, and only when step 7 is clean. The file list is exactly what setup wrote or found unwritten:

   `.sassywares/config.yaml`, `.sassywares/README.md`, `.sassywares/dogfood/recipe.md` and `.sassywares/.gitignore` when step 4 created them, `.sassywares/worktree/*` when step 6 installed them, `.agents/skills/sassy-*` and `skills-lock.json` when the suite is in project scope, the project-scope agent files when step 5 copied them, and `.gitignore` when step 5 created it. Named files only — never `git add -A`, never `git add .`. The reports directory is never in this list: it is gitignored, and nothing setup writes lives there.

   Dispatch `sassy-commit` with that list and `branch:current`. The token is explicit, not this skill's default: wiring is a one-time bootstrap commit, and cutting a branch would leave the project configured but uncommitted until someone ships it. Name the branch it landed on, base branch included.

   **Nothing else** unless the user asks: a plan, a doc, a source file, or anything already dirty in the tree stays uncommitted, because setup's commit is not a place to launder work in progress. A user who says "commit my plan too" widens the list with the file they named — never with a sweep for it. On a `check` run this fires only when something setup owns is dirty: an uncommitted pin, a config edited since the last commit, a scaffold nobody committed. Nothing dirty, nothing to commit.

   - **`workspace`** — nothing to commit: the root is not a repo, and `references/workspace.md` forbids running the snapshot here. Say the root config and the pin land with the project's next snapshot.
   - **`none`** — nothing to commit, deliberately.

9. **Report.** The config path, the topology, the resolved artifact and knowledge paths, whether agent QA is on and — when it is — that the recipe is a skeleton until a `sassy-dogfood mode:discover` run writes it, where the skills are installed (scope) and where the agents are (scope and harness), or why either is not, the commit (hash and branch) or why there is none, and in `workspace` mode what was installed, with versions (`snapshot vN`, `workspace-git vN`), and the manifest the `workspace:*` aliases went into — naming it as created when there was no script surface to begin with. Remind: `/reload` so the harness rescans. Close with what is left over — at most dirt setup deliberately did not commit — and nothing else: a clean setup leaves the user good to go.

## Hard rules

| Rule | Requirement |
|------|-------------|
| No `git init` | Setup never turns a folder into a repo, and never does remote or ref surgery. The step 8 commit is its only git write. |
| Commit only what setup owns | The config, the setup README, the vendored `sassy-*` folders and `skills-lock.json` (project scope), the project-scope agent files, and a `.gitignore` setup created. Never a file the user wrote or the repo already had, unless they name it. |
| Verify before commit | A config that fails `--check` is reported, never committed. |
| Approval to create a remote | Creating the mirror repo needs an explicit yes and a named slug first. |
| No silent overwrite | An existing config or an existing `.sassywares/workspace/snapshot` is shown and asked about, never replaced blind. |
| Version is reported | Setup names the snapshot and `workspace-git` versions it installed; `--check` flags an installed copy older than the skill's. |
| Skills come from upstream | Install with `npx skills add`, `-g` for user scope; never hand-copy skill files or maintain the links yourself. |
| Agents come from sassy-agents | Only the running harness's folder, as-is: linked by `install.sh` (user scope) or copied verbatim (project scope). Never edit, merge, or overwrite a differing agent file without asking. |
| Never edit the manifest | No dependencies, no `postinstall`, no `skills:*` scripts. The one exception is step 6's `worktree:*` and `workspace:*` aliases: appended or corrected, never removed, and nothing else in the file touched. Setup installs the suite; the user or project decides how it updates. |
| Write boundary | Only `.sassywares/` (the config, the setup README, the dogfood scaffold, and the worktree tooling), the skills and agent files step 5 installed in the scope the user chose, `skills-lock.json` (project scope), and one `.gitignore` line — and the project-scope part of that list is step 8's commit. Never `package.json` outside step 6's `worktree:*` and `workspace:*` aliases, never a root `.gitignore` in a workspace. Workspace git helpers land in `.sassywares/workspace/`, never in a project's `bin/`. |
| Detect, don't guess | An unknown base branch stays unknown and gets asked about. A probed value is reported as probed. |
| Comments are part of the file | Every key keeps its description and allowed values. A stripped config is an incomplete config. |
| Hooks are named, not written | Setup records hook skill names. Creating those skills is the project's work. |
| Dogfood is a pointer | The block names a recipe, a reports path, a timeout, and whether Auto rows are allowed — four keys. Never a command and never a tool: a copied command duplicates the manifest and cannot express step order. |
| The recipe is the project's | Setup scaffolds the skeleton and stops. Authoring or "fixing" a procedure is `sassy-dogfood mode:discover`'s job, and a run may never edit the recipe to make its own failure pass. |
| Run output and sessions never ship | `.sassywares/.gitignore` holds `/session/` and `/dogfood/reports/`. Never remove a line, never add anything from either path to the commit, and never write a credential anywhere else. |
| No secrets in setup's writes | Env var names only, in the config and in the skeleton. A credential never lands in a file setup commits. |
| Worktrees need `new` | `worktrees.enabled: true` with `commit.branch: current` is refused, not written: nothing cuts a branch there, so the switch could never fire. |
| Install the tooling, never use it | Setup copies `.sassywares/worktree/` and wires the aliases. It never creates a checkout, never claims a port, and never runs a script — those are a run's or the user's. |
| Repair is `check` | Run against an existing config, setup reports drift — it does not rewrite the file without approval. |

## What setup is not

Not a migration tool. A project already using another convention keeps its files; setup records where they already are. There is no rename step, and no fallback to `docs/` behind a configured path.

Not an updater. `check` reports a project pin that is stale or edited; it never moves it. Updating the suite is `npx skills update` (`-g` for user scope), which is the user's or project's decision and not setup's.
