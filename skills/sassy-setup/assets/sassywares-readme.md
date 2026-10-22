# .sassywares

Project config and tooling for the Sassy Skills suite. Written by `sassy-setup`.

## Skills

Installed from upstream with the open `skills` CLI, which vendors the skills into
`.agents/skills/` and pins them in `skills-lock.json`:

```bash
npx skills add sassywares/sassy-skills   # first install
npx skills update -y                      # pull the latest from upstream
npx skills experimental_install           # restore exactly what the lock pins
```

Refreshing the suite is this project's decision — nothing here updates itself.

The vendored skills and the lock are committed; `.claude/skills` is a link and is not.

`.agents/skills/` is read by pi and Cursor; Claude Code reads `.claude/skills/` only, which is why that symlink exists. After any change, `/reload` your harness.

If a skill tells you another skill is missing, run `npx skills add sassywares/sassy-skills` (or `npx skills experimental_install` to restore exactly what the lock pins) and restart.

## Config

`config.yaml` holds the project's paths, git topology, and PR defaults. Every key is documented inline, including its allowed values, and the full schema is in the `sassy-setup` skill's `references/config.md`. Verify the file still matches the tree:

```bash
.agents/skills/sassy-setup/scripts/detect.sh --root . --check
```

## Hooks

`hooks.pr` names project skills that run inside the PR pipeline, keyed by the PR's **head** branch: `"*"` for every PR, an exact branch, or a family such as `release/*`, overriding per point (`before_create`, `after_create`, `before_merge`, `after_merge`). An entry is `<skill> <args…>`; the args mean whatever that skill says they mean — `mode:auto` pre-authorizes the step. Hooks are ordinary skills in `.agents/skills/`, which makes them **code**: review them like code, and never point a hook at a copy of a suite skill.
