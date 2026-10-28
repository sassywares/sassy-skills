# Sassy Skills — Agent Guide

## What this repo is

This repo is the source of truth for the Sassy Skills suite under `skills/`.

- Local: `~/Documents/Workspace/Sassywares/sassy-skills`
- Remote: `sassywares/sassy-skills`

Consumers install it with `npx skills add sassywares/sassy-skills`, which reads this repo directly — per project (vendored into `.agents/skills/`, pinned in `skills-lock.json`) or globally with `-g` (into `~/.agents/skills/`). README.md's Installation section is the consumer-facing guide; keep it the only place those steps are spelled out.

While editing, this repo's `.pi/settings.json` loads `./skills`, and the maintainer's global symlinks (below) expose the working copy to every project on this machine.

## Layout

```text
sassy-skills/
├── skills/
│   └── <skill-name>/
│       ├── SKILL.md
│       └── references/        # only when conditionally needed
├── .pi/
│   └── settings.json          # dev only: loads ./skills while working here
├── scripts/
│   └── sync.sh                  # bump, commit, push, tag, publish
├── .github/
│   └── workflows/
│       └── publish.yml        # publishes on v* tags
├── AGENTS.md
├── CONCEPTS.md
├── LICENSE
└── package.json               # npm/pi package manifest
```

The npm package is `@sassywares/skills`. `package.json` lists `skills/` under `pi.skills`, and `files` ships `skills/`, `README.md`, `CONCEPTS.md`, and `LICENSE` — nothing else.

Keep `.github/workflows/publish.yml` in sync with the one in `sassy-pi-extensions`; it is intentionally near-identical.

## Adding a skill

1. Create `skills/<name>/SKILL.md`.
2. Use valid frontmatter: `name`, `description`, optional `argument-hint`, and `disable-model-invocation: true` for explicit-only skills.
3. Keep the body lean: outcome → hard rules → workflow → reference pointers.
4. Link it globally — see [Global symlinks](#global-symlinks-maintainer-machine).
5. Sync — see [Sync behavior](#sync-behavior).
6. Reload your harness (`/reload` in pi, a new session in Claude Code).

## Editing or removing

- Edit the files under `skills/`; the global links pick the change up with no reinstall.
- To remove a skill, delete its directory under `skills/` and both of its global links.
- Sync — see [Sync behavior](#sync-behavior).

## Global symlinks (maintainer machine)

Each `skills/<name>` is symlinked into `~/.agents/skills/<name>` (pi and `.agents`-convention harnesses) and `~/.claude/skills/<name>` (Claude Code), so edits here are live everywhere without a reinstall.

- The loop below is idempotent: rerun it after adding a skill. A removed skill's links dangle until you delete them.
- Do not also run `npx skills add sassywares/sassy-skills -g` on this machine: it installs the published copies into the same paths the links occupy.
- Leave `~/.claude/skills/synced/` alone; Claude Code manages it.
- Claude Code resolves same-name skills as personal > project, so these global links override a project's vendored copy of the same skill. Other harnesses apply their own collision rules.

```bash
R=~/Documents/Workspace/Sassywares/sassy-skills/skills
for d in ~/.agents/skills ~/.claude/skills; do
  mkdir -p "$d"
  for s in "$R"/*/; do n=$(basename "$s"); [ -e "$d/$n" ] || ln -s "$R/$n" "$d/$n"; done
done
```

## Sync behavior

There is no background watcher. Any agent that adds, edits, or removes a skill **must run `scripts/sync.sh` immediately as part of the change, without asking the user for confirmation**.

The sync script, in one unattended step:

1. Bumps the patch version when anything consumers receive changed since the last tag — `skills/`, `README.md`, `CONCEPTS.md`, `LICENSE`, or `package.json`. A change to tooling, CI, or `AGENTS.md` commits without a version, because nothing a consumer installs changed.
2. Commits every repo change with a `chore: sync skills <timestamp> (v<version>)` message.
3. Pushes the branch, then tags and pushes `v<version>`.
4. If the current version is already bumped but untagged — an interrupted run, or a hand-written bump — it tags that version instead of bumping again.

Releases only happen on `main`. On any other branch the script commits and pushes without tagging, because a tag pushed from a feature branch would publish unmerged content to npm. It does not install anything anywhere.

Sync command:

```bash
~/Documents/Workspace/Sassywares/sassy-skills/scripts/sync.sh
```

If a push fails, the local commit remains, the script exits non-zero, and the next sync retries. Because the bump is already in `package.json`, the retry tags that version rather than bumping twice. Report the failure instead of leaving the change uncommitted.

## Releasing

Publishing is tag-driven. `publish.yml` validates every `skills/*/SKILL.md`, checks that the tag matches `package.json`, and publishes to npm. Never publish by hand.

`scripts/sync.sh` does the whole release on `main`; run it and stop there. The manual sequence below is the fallback for recovering a run that failed between the commit and the tag — or for publishing without any file change:

```bash
npm version patch --no-git-tag-version
git add -A
git commit -m "chore: release v$(node -p "require('./package.json').version")"
git push origin main
git tag "v$(node -p "require('./package.json').version")"
git push origin --tags
```

Rules:

- Bump the patch version for any user-visible skill change. Bump minor for a new skill or a new required config key. `scripts/sync.sh` applies the patch bump for you; a minor bump is still hand-written.
- Tag only after the version bump is on `main`; the workflow fails when the tag and `package.json` disagree.
- Never bump a version that is already bumped but untagged — tag it instead. A second bump makes the first release impossible to identify.
- The first publish of a new package may need a manual `npm publish` bootstrap before the workflow can use trusted publishing.

## Conventions

- **Lean first.** Skills are indexes and workflows, not documentation dumps. Move only conditionally read detail into `references/`.
- **Explicit invocation.** Every skill except `sassy-ship` uses `disable-model-invocation: true`. Ship is the close-out a session runs once the user has approved the work, so the model may invoke it directly; its own `mode:manual` gate still waits before anything is written, committed, pushed, or opened.
- **Source of truth.** Do not store skill content outside this repo.
- **No secrets.** Never put credentials, tokens, or private keys in a skill.
- **Distribution.** The repo is the distribution: `npx skills add` reads it, so a push to `main` is installable immediately, per project or globally. The npm package is a secondary channel that mirrors it for package-installing harnesses and still needs a version bump.
- **Reference skills by name, never by path.** A consumer's copy may live in a project `.agents/skills/`, the global `~/.agents/skills/`, `node_modules/`, or wherever a harness installs packages.
