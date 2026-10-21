---
name: sassy-setup
description: >-
  Detect a project's topology and write .sassywares/config.yaml, so every sassy
  skill resolves paths, base branches, and git behavior from one file. Also
  installs the workspace snapshot tooling when the folder is a multi-repo
  workspace rather than a repo. Use when asked to set up, configure, or verify a
  project.
argument-hint: "[path] [--check]"
disable-model-invocation: true
---

# Sassy Setup

**Outcome:** `.sassywares/config.yaml` at the project root, matching the tree it describes. In `workspace` mode, also `.sassywares/bin/snapshot` plus the `.gitignore` entry that keeps the mirror out of itself.

**Read `references/config.md` first.** It is the schema and the resolution rules; this skill only decides and writes.

**Never a repo by force.** Setup records topology, it does not change it. No `git init`, ever.

## Steps

1. **Resolve the start.** The argument's path, else the working directory. If a `.sassywares/config.yaml` is already found walking up, this is a **verify run**: skip to step 5 with `--check`.
2. **Detect.** Run `scripts/detect.sh --root <path>`. It prints a proposed config: topology (`repo`, `workspace`, `none`), the remote name, a probed base branch, nested repos with their bases, and which artifact paths exist.
3. **Ask only what detection cannot answer.** Never re-ask what the tree already said.
   - **`workspace`** — the snapshot mirror: create a **private** GitHub repo, or connect an existing one (`owner/name` or URL)? For creating it, get explicit approval and name the slug before running anything. Automatic creation is `gh repo create` inside `snapshot`, and only after that approval.
   - **`none`** — confirm the intent: this folder is deliberately outside git, so commit, PR, and babysit refuse here.
   - **Artifacts** — offer the detected paths as the default; take overrides.
   - **Knowledge** — `knowledge.read` defaults to the solutions dir plus the concepts file. Ask whether there are extra folders to read (a hand-written `notes/learnings/`, a `docs/adr/`).
   - **Base branch** — in `repo` mode, if detection printed no `default_branch`, ask. Never fill in `main` as a guess. In `workspace` mode, show the detected `repos` map and get a yes on every row: each probed base is only the remote's default, so a repo that targets `dev` or `staging` will read `main` until a human corrects it. Never write an unconfirmed probed base.
   - **`pr.*`** — default `babysit: true`, `merge: false`, `delete_branch: false`. Say plainly that `merge: true` authorizes merging every babysat PR in this project without asking.
4. **Write the config.** Build the file from the proposal plus the answers. If a config already exists, show what changes and ask before writing — never silently overwrite. Keep every key; an unset key falls back to its documented default, so a short file is legal when nothing deviates.
5. **Install, `workspace` only.**
   - Copy `assets/snapshot` to `.sassywares/bin/snapshot` and make it executable. **If a `snapshot` file is already there, say so and ask** — it may carry hand edits.
   - Add `/.sassywares/mirror/` to `.gitignore` if that line is missing. Create `.gitignore` only when there is none.
   - Offer to write `.sassywares/snapshot-exclude` for extra excluded paths (vendored trees, generated dirs). One pattern per line, `.gitignore` style. Skip when there is nothing to exclude.
   - Do **not** run the snapshot during setup. It clones and pushes; that is the user's call. Offer `--dry-run` and run it only if they ask.
6. **Verify.** Run `scripts/detect.sh --root <path> --check`. Report every `drift:` line it prints, or that the config matches the tree.
7. **Report.** The config path, the topology, the resolved artifact and knowledge paths, and in `workspace` mode what was installed. **Commit nothing.**

## Hard rules

| Rule | Requirement |
|------|-------------|
| No `git init` | Setup never turns a folder into a repo, and never touches an existing repo's git state. |
| Approval to create a remote | Creating the mirror repo needs an explicit yes and a named slug first. |
| No silent overwrite | An existing config or an existing `.sassywares/bin/snapshot` is shown and asked about, never replaced blind. |
| Never commit | Setup writes files and stops. Committing is `sassy-commit`. |
| Write boundary | Only `.sassywares/config.yaml`, `.sassywares/bin/snapshot`, `.sassywares/snapshot-exclude`, and one `.gitignore` line. |
| Detect, don't guess | An unknown base branch stays unknown and gets asked about. A probed value is reported as probed. |
| Repair is verify | Run against an existing config, setup reports drift — it does not rewrite the file without approval. |

## What setup is not

Not a migration tool. A project already using another convention keeps its files; setup records where they already are. There is no rename step, and no fallback to `docs/` behind a configured path.
