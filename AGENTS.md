# Sassy Skills — Agent Guide

## What this repo is

This repo is the source of truth for the user-level pi Agent Skills under `skills/`.

- Local: `~/Documents/Workspace/Sassywares/sassy-skills`
- Remote: `sassywares/sassy-skills`

`~/.agents/skills` is a symlink to `skills/`. Editing, adding, or removing a skill here is immediately visible to pi through that symlink. Do not create a second copy of a skill elsewhere.

## Layout

```text
sassy-skills/
├── skills/
│   └── <skill-name>/
│       ├── SKILL.md
│       └── references/        # only when conditionally needed
├── scripts/
│   └── sync.sh
├── .github/
│   └── workflows/
│       └── publish.yml        # publishes on v* tags
├── AGENTS.md
├── CONCEPTS.md
├── LICENSE
└── package.json               # npm/pi package manifest
```

The npm package is `@sassywares/pi-skills`. `package.json` lists `skills/` under `pi.skills`, and `files` ships `skills/`, `README.md`, `CONCEPTS.md`, and `LICENSE` — nothing else.

Keep `.github/workflows/publish.yml` in sync with the one in `sassy-pi-extensions`; it is intentionally near-identical.

## Adding a skill

1. Create `skills/<name>/SKILL.md`.
2. Use valid frontmatter: `name`, `description`, optional `argument-hint`, and `disable-model-invocation: true` for explicit-only skills.
3. Keep the body lean: outcome → hard rules → workflow → reference pointers.
4. Run `scripts/sync.sh` immediately. Do not ask the user first.
5. Run `/reload` in pi.

## Editing or removing

- Edit the files under `skills/`.
- Remove the skill directory under `skills/`; the symlink makes it disappear from `~/.agents/skills`.
- Run `scripts/sync.sh` immediately. Do not ask the user first.
- Do not manually maintain per-skill symlinks. This repo uses one directory symlink.

## Sync behavior

There is no background watcher. Any agent that adds, edits, or removes a skill **must run `scripts/sync.sh` immediately as part of the change, without asking the user for confirmation**.

The sync script:

1. Ensures `~/.agents/skills` points at `skills/`.
2. Commits any repo changes with a `chore: sync skills <timestamp>` message.
3. Rebases on `origin/main` and pushes.

Sync command:

```bash
~/Documents/Workspace/Sassywares/sassy-skills/scripts/sync.sh
```

If a push fails, the local commit remains and the next sync retries. Report the failure instead of leaving the change uncommitted.

## Releasing

Publishing is tag-driven. `publish.yml` validates every `skills/*/SKILL.md`, checks that the tag matches `package.json`, and publishes to npm. Never publish by hand.

```bash
npm version patch --no-git-tag-version
git add -A
git commit -m "chore: release v$(node -p "require('./package.json').version")"
git push origin main
git tag "v$(node -p "require('./package.json').version")"
git push origin --tags
```

Rules:

- Bump the patch version for any user-visible skill change. Bump minor for a new skill or a new required config key.
- Tag only after the version bump is on `main`; the workflow fails when the tag and `package.json` disagree.
- The first publish of a new package may need a manual `npm publish` bootstrap before the workflow can use trusted publishing.

## Conventions

- **Lean first.** Skills are indexes and workflows, not documentation dumps. Move only conditionally read detail into `references/`.
- **Explicit invocation.** All current skills use `disable-model-invocation: true`.
- **Source of truth.** Do not store skill content outside this repo.
- **No secrets.** Never put credentials, tokens, or private keys in a skill.
- **Symlink invariant.** `~/.agents/skills` must remain a symlink to this repo's `skills/` directory.
