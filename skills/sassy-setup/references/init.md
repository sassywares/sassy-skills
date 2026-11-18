# Mode: init — detect, ask, write, wire

Read the shared sections in `SKILL.md` first (config-first, never-a-repo, harness, the modes, and steps 7–9). This file is steps 1–6. When step 6 is done, return to `SKILL.md` for steps 7–9: verify, commit, report.

## 1. Resolve the start

The path argument, else the working directory. `init` is the default mode; the mode rules live in `SKILL.md`.

## 2. Detect

Run `scripts/detect.sh --root <path>`. It prints a proposed config: topology (`repo`, `workspace`, `none`), the remote name, a probed base branch, and nested repos with their bases.

**A config that already exists is the proposal.** When `.sassywares/config.yaml` is found — an explicit `init` on a project that is already wired — the detector's output is only the starting point: take every value it **probes** (`git.repo`, `base_map`'s `"*"`, `repos`), and take every value it **emits as a default** from the existing file instead — the other `base_map` rungs, `hooks.*`, `worktrees.*`, `dogfood.*`, `pr.*`, `commit.branch`, `knowledge.*`, `artifacts.*`. A default is not an answer: writing the blank slate here would retarget `"*"` away from the integration branch the project actually uses and delete its hooks. Present the result as a **diff against the file, key by key**, and ask before writing.

## 3. Ask only what detection cannot answer

Never re-ask what the tree already said.

- **`workspace`** — the snapshot mirror: create a **private** GitHub repo, or connect an existing one? Creating it needs explicit approval and a named slug first.
- **`none`** — confirm the intent: this folder is deliberately outside git, so commit, PR, and babysit refuse here.
- **Artifacts** — offer the detected paths as the default; take overrides.
- **Knowledge** — `knowledge.read` defaults to the solutions dir plus the concepts file. Ask whether there are extra folders to read (a hand-written `notes/learnings/`, a `docs/adr/`).
- **Base map** — detection proposes `"*"` from the probed remote default. Ask where ordinary work branches from, and whether the default branch itself releases to another branch (a `staging: main` rung). Never write `main` as a guess. In `workspace` mode, show the `repos` map and get a yes on every row — a probed base is only the remote's default.
- **`commit.branch`** — default `new`: the run cuts a branch before the first change and never commits on a base branch. Offer `current` for a repo that genuinely wants work committed where it stands, and say plainly that `current` lets a run commit onto its base branch and push it, with no PR (`pr.*` and `hooks.pr` are ignored; `hooks.push` runs), and that a later `sassy-ship` run in `mode:auto` will then push to that base with no gate.
- **`pr.*`** — default `babysit: true`, `merge: false`, `delete_branch: false`. Say plainly that `merge: true` authorizes merging every babysat PR in this project without asking.
- **Hooks** — offer, do not impose. Ask whether the project wants steps injected at `before_create`, `after_create`, `before_merge`, or `after_merge` (or `hooks.push` `after_push`, for `commit.branch: current` only), and under which head branch (`"*"` for all). Also offer goal hooks — `before_slice` and `after_close` under `hooks.goal`, keyed by the goal slug — as base refresh, environment preparation, and boundary announcements that never touch the goal itself and leave every base level with its remote. Entries may carry args (`<skill> <args…>`); a hook skill's args are its own vocabulary. Leave them `[]` when there is nothing to add. **Never write a hook skill yourself** — hooks are project skills, and copying one of ours into that role is the fork this mechanism exists to prevent.
- **Worktrees** — ask whether the project wants parallel work in this repo: a checkout per branch, each with its own derived namespace and port, so two runs never fight over one working tree. Say plainly what it costs and what it needs. `false` — the run works here, which is today's behaviour. `true` — a run may *offer* a checkout and takes one only on your yes, or outright when the run carries a `worktree:on` token, and `sassy-worktree` gains `create`, `list`, `preview`, `remove`, and `prune`. It needs `commit.branch: new`: under `current` nothing ever cuts a branch, so the switch would do nothing — say so and leave it `false` rather than writing a setting that cannot fire. In `workspace` or `none` topology, say it is not available and write `false`. Read `references/worktree.md`. **Say what a checkout will need for this project** — install, `.env` derivation, a per-namespace database, a simulator, the session — and offer to create the hook with `sassy-skill`; **never write its body yourself**. With no hook, say plainly that every new checkout starts empty and the first preview will show it.
- **Dogfood** — ask whether the project wants agent QA: a stored procedure that proves a change works in the running product, which then lets `sassy-plan` write `Mode: Auto` QA rows instead of manual ones. Say plainly what each answer means. `false` — every QA row stays a human's, which is today's behavior. `true` — a plan may write Auto rows, but only for a recipe section that carries a `Prove it:` step, so the switch alone never makes a gate prove something. Write the answer explicitly either way; never leave it to inference. On yes, scaffold per step 4 and offer to run the first `sassy-dogfood mode:discover` before this run ends: yes means do it now (it is the only step that knows how to bring this app up), no means hand over the command and say the recipe stays a skeleton until it runs. Read `references/dogfood.md` and **never** write a command into the block or author the procedure: the recipe is the project's, and its first real content comes from a `sassy-dogfood mode:discover` run.

## 4. Write the config

Build the file from the proposal plus the answers. It is written **fully commented**: every key keeps a description and its allowed values, exactly as the detector emits them. Never strip those comments to save lines — for a teammate opening the file, the comments are the documentation. If a config already exists, show what changes and ask before writing — never silently overwrite. Keep every key; an unset key falls back to its documented default, so a short file is legal when nothing deviates.

**The dogfood scaffold, only when the answer was yes.** Create `.sassywares/dogfood/` holding `recipe.md` copied verbatim from `assets/dogfood-recipe.md`, and `.sassywares/.gitignore` with two lines — `/session/` and `/dogfood/reports/` — adding them to a `.gitignore` that already exists rather than replacing it. Never overwrite an existing recipe — show it and ask. The skeleton is deliberately incomplete: it carries the shape and the rules and fills in nothing, because `sassy-dogfood mode:discover` writes the procedure from what actually worked. Say so in the report — `enabled: true` is a permission, not a promise that a check exists.

## 5. Wire the skills and the agents

Both install the same way: report the scope if the pieces are present, otherwise ask once where to install, recommending user scope.

- **Skills.** The suite comes from upstream with the open `skills` CLI. Never copy skill files in by hand, never add the suite as a dependency.

  **Installed** means the `sassy-*` skills exist in the project scope (`.agents/skills/sassy-*`, pinned in `skills-lock.json`) or the user scope (`~/.agents/skills/`, plus `~/.claude/skills/` for Claude Code).

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

  **Installed** means all five `<name>.md` files exist in the user scope or the project scope.

  - **User scope** — every project on this machine, updated by `git pull`. Reuse the user's sassy-agents checkout if they have one; otherwise ask where to clone it (`git clone https://github.com/sassywares/sassy-agents.git <dir>`). Then run `<dir>/scripts/install.sh <folder>`, which symlinks the folder into the user scope and never overwrites a differing file.
  - **Project scope** — only this project, pinned with it. Shallow-clone into its own `mktemp -d` under `/tmp/sassywares/scratch/` (two runs share that folder now, per `references/harness.md`), copy `<folder>/*.md` into the project scope directory, delete the clone. Never overwrite an existing agent file that differs: show it and ask. The copies join step 8's commit list.

- **Tell the user to `/reload`** (or restart the harness). The skills and agents are invisible to the harness until it rescans.

## 6. Install the git tooling

Two independent sets, each only when its answer was yes.

- **Worktrees, `repo` topology and `worktrees.enabled: true`.** Copy every file in `assets/worktree/` flat into `.sassywares/worktree/` and make the five scripts executable, then add one `worktree:<script>` alias per script to the project's manifest, append-only, exactly as the workspace aliases are. **Prove the merge**: the file must still parse (`node -p "require('./package.json')"`, or the manifest's own syntax check) and `git diff` must show only added lines plus at most one trailing comma — anything else is a rewrite, so restore the file from `HEAD` and insert again. Report the `worktree-version` you installed. **Ask before overwriting any of them when they already exist** — from the first install they are the project's files. Read `references/worktree.md`. Do not create a worktree, and do not run a script: installing is the whole job, and the first `create` belongs to the user — a run asks, or takes one on `worktree:on`.
- **Workspace, `workspace` topology only.** The snapshot plus the `branches` / `pull` / `checkout-bases` git helpers, and one `workspace:<script>` alias per script in the project's own manifest. Read `references/workspace.md` and follow it.

Then return to `SKILL.md` for steps 7–9.

## Rules for this path

| Rule | Requirement |
|------|-------------|
| Detect, don't guess | An unknown base branch stays unknown and gets asked about. A probed value is reported as probed. |
| A re-apply is a diff | On a project that already has a config, every key the detector only *defaults* keeps its value from that file. Changing one needs the user to say so — never a detector default, and never a silent deletion. |
| Approval to create a remote | Creating the mirror repo needs an explicit yes and a named slug first. |
| Comments are part of the file | Every key keeps its description and allowed values. A stripped config is an incomplete config. |
| Hooks are named, not written | Setup records hook skill names. Creating those skills is the project's work. |
| Dogfood is a pointer | The block names a recipe, a reports path, a timeout, and whether Auto rows are allowed — four keys. Never a command and never a tool: a copied command duplicates the manifest and cannot express step order. |
| The recipe is the project's | Setup scaffolds the skeleton and stops. Authoring or "fixing" a procedure is `sassy-dogfood mode:discover`'s job, and a run may never edit the recipe to make its own failure pass. |
| Worktrees need `new` | `worktrees.enabled: true` with `commit.branch: current` is refused, not written: nothing cuts a branch there, so the switch could never fire. |
