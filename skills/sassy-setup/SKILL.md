---
name: sassy-setup
description: >-
  Detect a project's topology and wire it for the Sassy Skills suite: write
  .sassywares/config.yaml, pin the skills as an npm dependency, link them where
  harnesses look, and install the snapshot tooling in a multi-repo workspace.
  Use when asked to set up, configure, or verify a project.
argument-hint: "[path] [--check]"
disable-model-invocation: true
---

# Sassy Setup

**Outcome:** `.sassywares/config.yaml` at the project root matching the tree it describes, the skills wired as a pinned dependency and visible to the harness, and — in `workspace` mode — the snapshot tooling installed.

**Read `references/config.md` first.** It is the schema and the resolution rules; this skill only decides and writes.

**Never a repo by force.** Setup records topology, it does not change it. No `git init`, ever.

## Steps

1. **Resolve the start.** The argument's path, else the working directory. If a `.sassywares/config.yaml` is already found walking up, this is a **verify run**: run the checks in step 7 and report, without rewriting anything.
2. **Detect.** Run `scripts/detect.sh --root <path>`. It prints a proposed config: topology (`repo`, `workspace`, `none`), the remote name, a probed base branch, nested repos with their bases, and which artifact paths exist.
3. **Ask only what detection cannot answer.** Never re-ask what the tree already said.
   - **`workspace`** — the snapshot mirror: create a **private** GitHub repo, or connect an existing one? Creating it needs explicit approval and a named slug first.
   - **`none`** — confirm the intent: this folder is deliberately outside git, so commit, PR, and babysit refuse here.
   - **Artifacts** — offer the detected paths as the default; take overrides.
   - **Knowledge** — `knowledge.read` defaults to the solutions dir plus the concepts file. Ask whether there are extra folders to read (a hand-written `notes/learnings/`, a `docs/adr/`).
   - **Base branch** — if detection printed no `default_branch`, ask; never write `main` as a guess. In `workspace` mode, show the `repos` map and get a yes on every row — a probed base is only the remote's default, so a repo that targets `dev` or `staging` reads `main` until a human corrects it.
   - **`pr.*`** — default `babysit: true`, `merge: false`, `delete_branch: false`. Say plainly that `merge: true` authorizes merging every babysat PR in this project without asking.
   - **Hooks** — offer, do not impose. Ask whether the project wants steps injected at `before_create`, `after_create`, `before_merge`, or `after_merge`, and write the skills they name. Leave them `[]` when they have nothing to add. **Never write a hook skill yourself** — hooks are project skills, and copying one of ours into that role is the fork this mechanism exists to prevent.
4. **Write the config.** Build the file from the proposal plus the answers. It is written **fully commented**: every key keeps a description and its allowed values, exactly as the detector emits them. Never strip those comments to save lines — for a teammate opening the file, the comments are the documentation. If a config already exists, show what changes and ask before writing — never silently overwrite. Keep every key; an unset key falls back to its documented default, so a short file is legal when nothing deviates.
5. **Wire the skills.** The suite is the package `@sassywares/skills`, and its own CLI creates the links. Never copy skill files into a project.

   - **It needs a `package.json`.** With none, say so and ask whether to add a minimal manifest or skip the wiring. Do not create one unasked, and do not invent a second distribution mechanism for non-JS projects.
   - **Detect the package manager** from the lockfile: `bun.lock`/`bun.lockb`, `pnpm-lock.yaml`, `yarn.lock`, `package-lock.json`. Ask when several disagree or none exists.
   - **Add the dependency pinned exactly** — `bun add --dev --exact @sassywares/skills@<version>`, `npm install --save-dev --save-exact …`, `pnpm add --save-dev --save-exact …`, `yarn add --dev --exact …`. Exact, because one pinned version for every teammate and every harness is the entire point.
   - **Scripts**, adding only what is missing: `"skills:sync": "sassy-skills sync"`, `"skills:update": "sassy-skills update"`, and `"postinstall": "sassy-skills sync"`. **Never overwrite an existing `postinstall`** — if one is there, leave it alone and tell the user to chain `&& sassy-skills sync`, so setup cannot erase someone's install steps.
   - **Run `sassy-skills sync`.** The package's CLI is now in `node_modules/.bin`; it links `.agents/skills/sassy-*` and creates `.claude/skills → ../.agents/skills`. The linking rules travel with the lockfile, so they upgrade with the suite instead of drifting in the repo.
   - **Ignore the derived links.** Add `/.agents/skills/sassy-*` and `/.claude/skills` to `.gitignore` when missing. Create `.gitignore` only when there is none.
   - **Write `.sassywares/README.md`** from `assets/sassywares-readme.md` when absent. Never overwrite it — it may carry project notes.
   - **Tell the user to `/reload`.** The links are invisible to the harness until it rescans.

6. **Install the snapshot, `workspace` only.** Read `references/workspace.md` and follow it.

7. **Verify.** Run `scripts/detect.sh --root <path> --check`, then `sassy-skills check` for the links. Report every `drift:` line it prints — including an outdated `snapshot` version — or that the config matches the tree.
8. **Report.** The config path, the topology, the resolved artifact and knowledge paths, the skills version pinned and that `/reload` is needed, and in `workspace` mode what was installed. **Commit nothing.**

## Hard rules

| Rule | Requirement |
|------|-------------|
| No `git init` | Setup never turns a folder into a repo, and never touches an existing repo's git state. |
| Approval to create a remote | Creating the mirror repo needs an explicit yes and a named slug first. |
| No silent overwrite | An existing config or an existing `.sassywares/workspace/snapshot` is shown and asked about, never replaced blind. |
| Version is reported | Setup names the snapshot version it installed; `--check` flags an installed copy older than the skill's. |
| Never commit | Setup writes files and stops. Committing is `sassy-commit`. |
| Skills are a dependency | Pin `@sassywares/skills`; never copy skill files into a project or maintain hand-made links. |
| Scripts are shared | Adding a missing script is fine; rewriting an existing `postinstall` or `skills:*` entry is not. |
| Write boundary | Only `.sassywares/`, the `package.json` scripts and devDependency, the lockfile, and two `.gitignore` lines. Never skill content. |
| Detect, don't guess | An unknown base branch stays unknown and gets asked about. A probed value is reported as probed. |
| Comments are part of the file | Every key keeps its description and allowed values. A stripped config is an incomplete config. |
| Hooks are named, not written | Setup records hook skill names. Creating those skills is the project's work. |
| Repair is verify | Run against an existing config, setup reports drift — it does not rewrite the file without approval. |

## What setup is not

Not a migration tool. A project already using another convention keeps its files; setup records where they already are. There is no rename step, and no fallback to `docs/` behind a configured path.
