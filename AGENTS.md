# Sassy Skills — Agent Guide

## What this is

This repo is the source of truth for the Sassy Skills suite under `skills/`.

- Local: `~/Documents/Workspace/Sassywares/sassy-skills`
- Remote: `sassywares/sassy-skills`

Consumers install it with `npx skills add sassywares/sassy-skills`, which reads this repo directly — per project (vendored into `.agents/skills/`, pinned in `skills-lock.json`) or globally with `-g` (into `~/.agents/skills/`). README.md's Installation section is the consumer-facing guide; keep it the only place those steps are spelled out.

While editing, this repo's `.pi/settings.json` loads `./skills`, and the maintainer's global symlinks (below) expose the working copy to every project on this machine.

The repo is wired with `sassy-setup`: `.sassywares/config.yaml` sets `commit.branch: current` (every change lands on `main`, the only release line) and `hooks.push."*".after_push: [sassy-skills-release]`.

## Layout

```text
sassy-skills/
├── skills/
│   └── <skill-name>/
│       ├── SKILL.md
│       └── references/        # only when conditionally needed
├── .pi/
│   └── settings.json          # dev only: loads ./skills while working here
├── .sassywares/
│   ├── config.yaml            # sassy-setup config (commit.branch: current, hooks.push)
│   └── README.md              # what the folder is
├── bin/
│   ├── release                # vendored release script (sassywares/sassy-release)
│   └── release-ignore         # paths that never reach consumers
├── .agents/
│   └── skills/
│       └── sassy-skills-release/ # project skill that runs bin/release
├── .github/
│   └── workflows/
│       └── publish.yml        # publishes on v* tags
├── AGENTS.md
├── CONCEPTS.md
├── LICENSE
└── package.json               # npm/pi package manifest
```

The npm package is `@sassywares/skills`. `package.json` lists `skills/` under `pi.skills`, and `files` ships `skills/`, `README.md`, `CONCEPTS.md`, and `LICENSE` — nothing else. Never add `.sassywares/` or `.agents/` to `files`.

Keep `.github/workflows/publish.yml` in sync with the one in `sassy-pi-extensions`; it is intentionally near-identical.

## How to run

There is nothing to build or start. Consumers install with `npx skills add sassywares/sassy-skills` (per project) or `npx skills add sassywares/sassy-skills -g` (globally); the full steps live in README.md. On the maintainer machine the working copy is linked into the harness skill folders instead — see [Global symlinks](#global-symlinks-maintainer-machine). Reload your harness after a change (`/reload` in pi, a new session in Claude Code).

## Adding a skill

1. Create `skills/<name>/SKILL.md`.
2. Use valid frontmatter: `name`, `description`, and optional `argument-hint`.
3. Keep the body lean: outcome → hard rules → workflow → reference pointers.
4. Link it globally — see [Global symlinks](#global-symlinks-maintainer-machine).
5. Add its name to `skills/sassy-setup/assets/roster` (one per line, sorted) in the same commit; `tests/sassy-setup-roster.sh` and `publish.yml` fail when the roster differs from `ls skills/`.
6. Update README.md (skill list) and CONCEPTS.md as [Docs upkeep](#docs-upkeep) says, then ship — see [Releasing](#releasing).
7. Reload your harness (`/reload` in pi, a new session in Claude Code).

## Editing or removing

- Edit the files under `skills/`; the global links pick the change up with no reinstall.
- To remove a skill, delete its directory under `skills/` and both of its global links, and remove its line from `skills/sassy-setup/assets/roster` in the same commit.
- Adding, renaming, or removing a skill updates `skills/sassy-setup/assets/roster` in the same commit.
- Ship — see [Releasing](#releasing).

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

## Testing

There is no test suite beyond one script; skills are validated structurally.

- **Roster and pin.** `bash tests/sassy-setup-roster.sh` checks that `skills/sassy-setup/assets/roster` equals `ls skills/` and runs `detect.sh --check` in project scope, user scope (three real Sassywares repos), and with the roster missing.

- **Frontmatter.** Every `skills/*/SKILL.md` starts with `---` frontmatter holding `name` and `description` (`argument-hint` optional). `publish.yml` enforces `name` and `description` and fails the publish without them, so check locally first.
- **Config tooling.** After changing `sassy-setup` or the config schema, run `bash skills/sassy-setup/scripts/detect.sh --root . --check` (config and vendored pin versus reality) and `bash skills/sassy-setup/scripts/detect.sh --root .` (proposed config) and confirm the output matches `references/config.md`.
- **Publish workflow.** `.github/workflows/publish.yml` runs on `v*` tags only: it checks the tag matches `package.json`, validates every `skills/*/SKILL.md`, publishes to npm, and polls the registry packument for the new version.
- Run a changed skill once in a harness to confirm it loads and its gates behave.

## Releasing

Publishing is tag-driven. `publish.yml` validates every `skills/*/SKILL.md`, checks that the tag matches `package.json`, and publishes to npm. Never publish by hand. A release installs nothing on consumers' machines: `npx skills add` reads this repo directly.

Releases go through `sassy-ship` (`commit.branch: current`): after the approved push, `hooks.push` `after_push` runs the `sassy-skills-release` project skill, which runs the vendored `bin/release`. That script comes from [sassywares/sassy-release](https://github.com/sassywares/sassy-release); refresh the vendored copy by comparing its `# sassy-release vN` header with the repo's latest tag.

- Patch bumps are automatic: when consumer-facing files changed since the highest `v*` tag on origin, the script bumps the patch version in `package.json`, commits `chore: release v<version>`, pushes `main`, and tags and pushes `v<version>`.
- A version already above the highest tag (a hand-written minor or major bump, an interrupted run, the first release) is tagged as-is. Bump minor for a new skill or a new required config key: edit `package.json` by hand. A hand-written version must be >= the highest tag on origin, or the script stops.
- A prerelease (`X.Y.Z-beta.1`) is tagged as-is and never auto-bumped: once tagged, later consumer-facing changes make the script stop until the next version is hand-set.
- What counts as consumer-facing is every changed path not listed in `bin/release-ignore`: only `skills/`, `README.md`, `CONCEPTS.md`, `LICENSE`, and `package.json` count. The file replaces the script's defaults, so it repeats them (including `bin/release` and `bin/release-ignore`) and adds `.pi/` and `.gitignore`. `bin/` is not shipped: `package.json` `files` does not list it, and only those two files in it are ignored. `package.json` counts whole: it holds the version, the skill manifest, and the shipped file list. Publishing therefore needs a file change: with none, a hand-written version bump in `package.json` is the only way to release.
- Releases only happen on `main`. A tag pushed from another branch would publish unmerged content to npm.
- Tag only after the version bump is on `main`; the workflow fails when the tag and `package.json` disagree.
- The first publish of a new package may need a manual `npm publish` bootstrap before the workflow can use trusted publishing.
- Recovery (a run that failed between the commit and the tag, or a push that failed): run `bin/release` from a clean `main`. It is idempotent and tags what is already bumped instead of bumping twice.
- If any step fails, report the failure; never continue silently.
- Never release with a README that describes old behavior — see [Docs upkeep](#docs-upkeep).

## Docs upkeep

Any change to user-visible behavior, install steps, commands or keys, configuration, environment variables, requirements, or outputs updates `README.md` in the **same commit**. A stale README is a review finding, and a release never goes out with the README describing old behavior.

| Change | README section |
|---|---|
| New, removed, or renamed skill | Skills (the tables), "Why this suite" if modes change, Workflows |
| Changed mode tokens or gates | Why this suite, Gates and controls |
| New or changed config key, default, or hook point | Project config, Extending the pipeline |
| Changed branching or `commit.branch` behaviour | Branching |
| Changed workflow between skills | Workflows (the diagram and its prose) |
| Changed install, update, or removal steps | Installation (and Quick start if the first steps change) |
| Release or maintenance flow | Repository maintenance |

- Update `CONCEPTS.md` when a user-facing term is added or renamed.
- Update this file when a rule or an architecture fact changes.
- **Version pins.** The README carries no literal version pins, and the release script never edits the README, so a pin would go stale on every release.

## Conventions

- **Lean first.** Skills are indexes and workflows, not documentation dumps. Move only conditionally read detail into `references/`.
- **Model invocation.** No suite skill sets `disable-model-invocation`; the model may invoke any of them. Skills that write, commit, push, or open anything keep their own gates (e.g. `sassy-ship`'s `mode:manual`).
- **Source of truth.** Do not store skill content outside this repo.
- **No secrets.** Never put credentials, tokens, or private keys in a skill.
- **Distribution.** The repo is the distribution: `npx skills add` reads it, so a push to `main` is installable immediately, per project or globally. The npm package is a secondary channel that mirrors it for package-installing harnesses and still needs a version bump.
- **Reference skills by name, never by path.** A consumer's copy may live in a project `.agents/skills/`, the global `~/.agents/skills/`, `node_modules/`, or wherever a harness installs packages.
- **The suite stays project-agnostic.** Nothing Sassywares-specific (release tooling, the `sassy-skills-release` skill) goes into `skills/`; it lives in `bin/`, `.sassywares/` and `.agents/` here, and none ships.

## Knowledge store

- Vocabulary and naming: [`CONCEPTS.md`](CONCEPTS.md).
- Consumer-facing guide: [`README.md`](README.md).
- Durable learnings: `docs/solutions/`, created on the first write (`knowledge.read` also searches `CONCEPTS.md` and `README.md`).
