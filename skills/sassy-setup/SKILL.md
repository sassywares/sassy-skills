---
name: sassy-setup
description: >-
  Detect a project's topology and wire it for the Sassy Skills suite: write
  .sassywares/config.yaml, vendor the skills from upstream with the open
  `skills` CLI, and install the snapshot tooling in a multi-repo workspace.
  Use when asked to set up, configure, or verify a project.
argument-hint: "[path] [--check]"
disable-model-invocation: true
---

# Sassy Setup

**Outcome:** `.sassywares/config.yaml` at the project root matching the tree it describes, the skills vendored and pinned in `skills-lock.json` and visible to the harness, and — in `workspace` mode — the snapshot tooling installed.

**Read `references/config.md` first.** It is the schema and the resolution rules; this skill only decides and writes.

**Never a repo by force.** Setup records topology, it does not change it. No `git init`, ever.

## Steps

1. **Resolve the start.** The argument's path, else the working directory. If a `.sassywares/config.yaml` is already found walking up, this is a **verify run**: run the checks in step 7 and report, without rewriting anything.
2. **Detect.** Run `scripts/detect.sh --root <path>`. It prints a proposed config: topology (`repo`, `workspace`, `none`), the remote name, a probed base branch, and nested repos with their bases.
3. **Ask only what detection cannot answer.** Never re-ask what the tree already said.
   - **`workspace`** — the snapshot mirror: create a **private** GitHub repo, or connect an existing one? Creating it needs explicit approval and a named slug first.
   - **`none`** — confirm the intent: this folder is deliberately outside git, so commit, PR, and babysit refuse here.
   - **Artifacts** — offer the detected paths as the default; take overrides.
   - **Knowledge** — `knowledge.read` defaults to the solutions dir plus the concepts file. Ask whether there are extra folders to read (a hand-written `notes/learnings/`, a `docs/adr/`).
   - **Base branch** — if detection printed no `default_branch`, ask; never write `main` as a guess. In `workspace` mode, show the `repos` map and get a yes on every row — a probed base is only the remote's default, so a repo that targets `dev` or `staging` reads `main` until a human corrects it.
   - **`pr.*`** — default `babysit: true`, `merge: false`, `delete_branch: false`. Say plainly that `merge: true` authorizes merging every babysat PR in this project without asking.
   - **Hooks** — offer, do not impose. Ask whether the project wants steps injected at `before_create`, `after_create`, `before_merge`, or `after_merge`, and write the skills they name. Leave them `[]` when they have nothing to add. **Never write a hook skill yourself** — hooks are project skills, and copying one of ours into that role is the fork this mechanism exists to prevent.
4. **Write the config.** Build the file from the proposal plus the answers. It is written **fully commented**: every key keeps a description and its allowed values, exactly as the detector emits them. Never strip those comments to save lines — for a teammate opening the file, the comments are the documentation. If a config already exists, show what changes and ask before writing — never silently overwrite. Keep every key; an unset key falls back to its documented default, so a short file is legal when nothing deviates.
5. **Wire the skills.** The suite is installed from upstream with the open `skills` CLI, which vendors the skill files into the project and pins them. Never copy skill files in by hand, never add the suite as a dependency.

   - **Install it**: `npx -y skills add sassywares/sassy-skills -y`. That writes `.agents/skills/sassy-*` (real files), per-agent links such as `.claude/skills/sassy-*`, and `skills-lock.json`.
   - **Scripts**, adding only what is missing: `"skills:sync": "npx -y skills experimental_install"` (restores exactly what the lock pins) and `"skills:update": "npx -y skills update -y"` (pulls the latest from upstream). **Never rewrite an existing `postinstall`** — leave it alone and tell the user to chain what they need.
   - **Commit the vendored skills and the lock.** `.agents/skills/sassy-*` and `skills-lock.json` are the pin; a clone then needs no network.
   - **Ignore `.claude/skills` only.** It is a link created at install time. Create `.gitignore` only when there is none — and in `workspace` topology never touch the project's root `.gitignore` at all.
   - **Write `.sassywares/README.md`** from `assets/sassywares-readme.md` when absent. Never overwrite it — it may carry project notes.
   - **Tell the user to `/reload`.** The skills are invisible to the harness until it rescans.

6. **Install the snapshot, `workspace` only.** Read `references/workspace.md` and follow it.

7. **Verify.** Run `scripts/detect.sh --root <path> --check`. Report every `drift:` line it prints — including an outdated `snapshot` version — or that the config matches the tree, plus that `skills-lock.json` is tracked and matches the vendored skills.
8. **Report.** The config path, the topology, the resolved artifact and knowledge paths, that the vendored skills and lock are committed and `/reload` is needed, and in `workspace` mode what was installed. **Commit nothing.**

## Hard rules

| Rule | Requirement |
|------|-------------|
| No `git init` | Setup never turns a folder into a repo, and never touches an existing repo's git state. |
| Approval to create a remote | Creating the mirror repo needs an explicit yes and a named slug first. |
| No silent overwrite | An existing config or an existing `.sassywares/workspace/snapshot` is shown and asked about, never replaced blind. |
| Version is reported | Setup names the snapshot version it installed; `--check` flags an installed copy older than the skill's. |
| Never commit | Setup writes files and stops. Committing is `sassy-commit`. |
| Skills come from upstream | Install with `npx skills add`; never hand-copy skill files or maintain the links yourself. |
| Scripts are shared | Adding a missing script is fine; rewriting an existing `postinstall` or `skills:*` entry is not. |
| Write boundary | Only `.sassywares/`, the vendored `.agents/skills/sassy-*`, `skills-lock.json`, two `package.json` scripts, and one `.gitignore` line. Never a root `.gitignore` in a workspace. |
| Detect, don't guess | An unknown base branch stays unknown and gets asked about. A probed value is reported as probed. |
| Comments are part of the file | Every key keeps its description and allowed values. A stripped config is an incomplete config. |
| Hooks are named, not written | Setup records hook skill names. Creating those skills is the project's work. |
| Repair is verify | Run against an existing config, setup reports drift — it does not rewrite the file without approval. |

## What setup is not

Not a migration tool. A project already using another convention keeps its files; setup records where they already are. There is no rename step, and no fallback to `docs/` behind a configured path.
