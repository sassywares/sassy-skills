# Sassy Skills — Agent Guide

## What this repo is

This repo is the source of truth for the user-level pi Agent Skills under `skills/`.

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
├── AGENTS.md
└── CONCEPTS.md
```

## Adding a skill

1. Create `skills/<name>/SKILL.md`.
2. Use valid frontmatter: `name`, `description`, optional `argument-hint`, and `disable-model-invocation: true` for explicit-only skills.
3. Keep the body lean: outcome → hard rules → workflow → reference pointers.
4. Run `scripts/sync.sh`, or wait for the launchd sync (up to 30 seconds).
5. Run `/reload` in pi.

## Editing or removing

- Edit the files under `skills/`.
- Remove the skill directory under `skills/`; the symlink makes it disappear from `~/.agents/skills`.
- Run `scripts/sync.sh` or wait for the launchd sync.
- Do not manually maintain per-skill symlinks. This repo uses one directory symlink.

## Sync behavior

The launchd agent `com.sassywares.sassy-skills-sync` runs `scripts/sync.sh` every 30 seconds.

The script:

1. Ensures `~/.agents/skills` points at `skills/`.
2. Commits any repo changes with a `chore: sync skills <timestamp>` message.
3. Rebases on `origin/main` and pushes.

Manual sync:

```bash
~/Documents/Workspace/Sassywares/sassy-skills/scripts/sync.sh
```

Log:

```text
~/.agents/sassy-skills-sync.log
```

If a push fails, the local commit remains and the next run retries.

## Conventions

- **Lean first.** Skills are indexes and workflows, not documentation dumps. Move only conditionally read detail into `references/`.
- **Explicit invocation.** All current skills use `disable-model-invocation: true`.
- **Source of truth.** Do not store skill content outside this repo.
- **No secrets.** Never put credentials, tokens, or private keys in a skill.
- **Symlink invariant.** `~/.agents/skills` must remain a symlink to this repo's `skills/` directory.
