# .sassywares

Project config and tooling for the Sassy Skills suite. Written by `sassy-setup`.

## Skills

Installed from upstream with the open `skills` CLI, in one of two scopes:

- **Project** — vendored into `.agents/skills/` and pinned in `skills-lock.json`,
  both committed, so every clone runs the same skills. `.claude/skills` is a link
  created at install time and is not committed.
- **User** — `~/.agents/skills/` (plus `~/.claude/skills/` links), for one person
  across every project on their machine. Nothing is committed here.

```bash
npx skills add sassywares/sassy-skills      # project install (-g for user scope)
npx skills update -p -y                      # pull the latest (-g -y for user scope)
npx skills experimental_install              # restore exactly what the project lock pins
```

Refreshing the suite is your decision — nothing here updates itself. With both
scopes installed, Claude Code runs the user-scope copy.

`.agents/skills/` is read by pi and Cursor; Claude Code reads `.claude/skills/` only, which is why those links exist. After any change, reload your harness (`/reload` in pi, a new session in Claude Code).

## Agents

The skills dispatch five subagents by name — `scout`, `worker`, `reviewer`,
`simplifier`, `validator` — from [sassy-agents](https://github.com/sassywares/sassy-agents),
one folder per harness (`pi/`, `claude/`). They live either in the harness's
user directory (`~/.pi/agent/agents/`, `~/.claude/agents/`, linked by
`sassy-agents/scripts/install.sh <harness>`) or in this project's
`.pi/agents/` / `.claude/agents/`. `sassy-setup` checks for them and offers to
install them when missing.

## Missing skills

If a skill tells you another skill is missing, run `npx skills add sassywares/sassy-skills` (add `-g` for user scope, or run `npx skills experimental_install` to restore exactly what the project lock pins) and restart.

## Config

`config.yaml` holds the project's paths, git topology, and PR defaults. Every key is documented inline, including its allowed values, and the full schema is in the `sassy-setup` skill's `references/config.md`. Verify the setup still matches the tree — the config, the hooks it names, and the vendored pin when the suite is installed in project scope:

```bash
.agents/skills/sassy-setup/scripts/detect.sh --root . --check   # ~/.agents/skills/... for user scope
```

Or ask for `mode:check` on the setup skill, which runs the same check and reports it. Neither moves the pin: `npx skills check` is an alias of `update`.

## Workspace scripts

In a `workspace` project, `.sassywares/workspace/` holds the scripts that work
across the sibling repos, next to the `snapshot` that versions the glue:

```bash
.sassywares/workspace/branches          # branch + dirty marker per repo
.sassywares/workspace/pull              # fetch, then ff-only per repo
.sassywares/workspace/checkout-bases    # put each repo on its base
.sassywares/workspace/snapshot          # commit + push the glue
```

Each one also has an alias in the project manifest (`workspace:branches`,
`workspace:pull`, `workspace:checkout-bases`, `workspace:snapshot`), so
`npm run workspace:pull` — or the equivalent for the runner this project uses —
works from the root.

They read the repo inventory and the PR bases from `repos:` in `config.yaml`, so
there is no second base map to keep in step. They are this project's files:
extend them freely — just run the snapshot afterwards, since they live in the
mirrored tree. The `sassy-*` skills do their own git and never call them.

## Hooks

`hooks.pr` names project skills that run inside the PR pipeline, keyed by the PR's **head** branch: `"*"` for every PR, an exact branch, or a family such as `release/*`, overriding per point (`before_create`, `after_create`, `before_merge`, `after_merge`). An entry is `<skill> <args…>`; the args mean whatever that skill says they mean — `mode:auto` pre-authorizes the step. Hooks are ordinary skills in `.agents/skills/`, which makes them **code**: review them like code, and never point a hook at a copy of a suite skill. Under `commit.branch: current` there is no PR, so these hooks do not run.
