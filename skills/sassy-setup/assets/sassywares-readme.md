# .sassywares

Project config and tooling for the Sassy Skills suite. Written by `sassy-setup`.

## Skills

Installed as the npm package `@sassywares/skills`, pinned exactly in `package.json`. The entries in `.agents/skills/` and the `.claude/skills` symlink are **derived** from that package — never edit them by hand and never commit them.

```bash
bun run skills:sync     # recreate the links after a fresh clone
bun run skills:update   # bump to the latest published version, then relink
```

`.agents/skills/` is read by pi and Cursor; Claude Code reads `.claude/skills/` only, which is why that symlink exists. After any change, `/reload` your harness.

If a skill tells you another skill is missing, run `skills:sync` and restart. Substituted package managers: run the same script through `npm`, `pnpm`, or `yarn`.

## Config

`config.yaml` holds the project's paths, git topology, and PR defaults. Every key is documented inline, including its allowed values, and the full schema is in the `sassy-setup` skill's `references/config.md`. Verify the file still matches the tree:

```bash
node_modules/@sassywares/skills/skills/sassy-setup/scripts/detect.sh --root . --check
```

## Hooks

`hooks.pr.*` names project skills that run inside the PR pipeline: `before_create`, `after_create`, `before_merge`, `after_merge`. They are ordinary skills in `.agents/skills/`, which means they are **code** — review them like code, and never point a hook at a copy of a suite skill.
