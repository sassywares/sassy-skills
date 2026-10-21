# Project config

One file: `.sassywares/config.yaml` at the project root. Every config-reading
skill follows this document. `sassy-setup` is the only skill that writes it.

No file means today's behavior — every default below is the fallback.

The file `sassy-setup` writes is **fully commented**: every key carries its
meaning and its allowed values, and `detect.sh` emits those comments as part of
the proposal. Keep them. For a teammate opening the file, the comments *are* the
documentation, and a stripped config is an incomplete one.

## Discovery

Walk up from the working directory until `.sassywares/config.yaml` is found.
Nearest wins. **Never merge files** — one project, one config.

Walking up crosses repo boundaries on purpose: run from `fe/` inside a workspace
and you must still find the workspace root's config.

## Precedence

```
explicit token in the request  >  instruction in this session
>  .sassywares/config.yaml  >  skill default
```

Read it once per run. An orchestrator resolves every config-backed value and
passes the resolved values into subagent briefs; subagents never re-read the
file. A skill invoked directly resolves it itself.

## Schema

```yaml
artifacts:
  plans: docs/plans
  solutions: docs/solutions
  handbooks: docs/handbooks
  concepts: CONCEPTS.md
knowledge:
  read: [docs/solutions, CONCEPTS.md]
  write: true
git:
  repo: origin              # <remote name> | workspace | none
  remote: thekayshawn/knit  # workspace only: the snapshot mirror
  default_branch: main      # repo base; workspace: the mirror branch
repos:                      # workspace only: sibling dir -> PR base
  fe: dev
  knit-ai-pipeline: master
commit:
  branch: current           # current | new
pr:
  babysit: true
  merge: false
  delete_branch: false
hooks:
  pr:
    before_create: []       # after the commit, before the PR opens
    after_create: []        # the moment the PR exists
    before_merge: []        # this run is about to merge
    after_merge: []         # this run observed the merge
```

| Key | Default | Meaning |
|-----|---------|---------|
| `artifacts.plans` | `docs/plans` | Where `sassy-plan` writes plans |
| `artifacts.solutions` | `docs/solutions` | Where `sassy-compound` writes learnings |
| `artifacts.handbooks` | `docs/handbooks` | Where `sassy-handbook` writes handbooks |
| `artifacts.concepts` | `CONCEPTS.md` | The glossary file compound maintains |
| `knowledge.read` | `[docs/solutions, CONCEPTS.md]` | Paths scouted for prior learnings |
| `knowledge.write` | `true` | `false` = this project takes no learnings |
| `git.repo` | `origin` | Remote name, or a reserved value (below) |
| `git.remote` | mirror of `git.repo` | Workspace only: mirror remote (URL or `owner/name`) |
| `git.default_branch` | probed | Repo base branch; workspace: the mirror branch |
| `repos` | `{}` | Workspace only: repo dir name → the base its PRs target |
| `commit.branch` | `current` | `current` commits where you are; `new` cuts a branch |
| `pr.babysit` | `true` | Whether close-out babysits the PR it opened |
| `pr.merge` | `false` | `true` authorizes merging a single babysat PR |
| `pr.delete_branch` | `false` | Delete the head branch once merged |
| `hooks.pr.*` | `[]` | Project steps injected into the PR pipeline |

Paths are relative to the config's own directory, never to the cwd.

## `git.repo` — the three topologies

| Value | Meaning |
|-------|---------|
| a remote name (`origin`) | This folder is the repo. Git commits, PRs, and babysit are normal |
| `workspace` | Not a repo at this root. Repos live below; this folder's glue is versioned by the snapshot mirror |
| `none` | Deliberate off-switch. No git anywhere here |

`workspace` and `none` are reserved words; a remote cannot be named either.

`remote` and `default_branch` are conditional. In a repo config, `remote` is
omitted (the repo name is `git.repo`) and `default_branch` is the repo's base.
In a workspace config, both describe **the snapshot mirror**: where it pushes,
and its branch.

### Workspace layout

Fixed, so nothing has to be guessed:

```text
.sassywares/
├── config.yaml
└── workspace/
    ├── snapshot      the script; its header carries the version
    ├── .gitignore    exclude patterns, one per line
    └── mirror/       the side clone, untracked
```

This is the only ignore file. There is no `.gitignore` at the project root, and
setup does not touch one that exists. The mirror is excluded by the script
itself, so no pattern is needed for it.

`.sassywares/workspace/.gitignore` is a pattern list for the sync, and it is
itself synced into the mirror, where git honors it for paths under
`.sassywares/workspace/`. Two safeguards keep a broad pattern from silently
dropping the config or the script: the sync includes `config.yaml`,
`workspace/.gitignore`, and `workspace/snapshot` ahead of every user pattern,
and the mirror stages with `git add -A -f`. Anchor patterns with a leading `/`
when you mean the workspace root.

The script's header carries `# snapshot-version: N`. Bump `N` whenever the asset
changes; `sassy-setup --check` compares the installed copy against the skill's
and reports a stale one as drift. Setup never overwrites an existing script
without asking, so the version line is how staleness surfaces.

### What each topology does

| Step | remote | `workspace` | `none` |
|------|--------|-------------|--------|
| plan, cycle, work, review, validate | normal | normal | normal |
| compound, handbook | normal | normal, at the root | normal |
| commit | `git commit` | no `git commit`; run the snapshot | refused, one line |
| PR, ship's PR step, babysit | normal | per affected repo (below) | refused, one line |
| snapshot | not used | the commit mechanism | not used |

In `workspace` and `none`, changes still land on disk. Nothing is silently
dropped; the refusal names why and what to run instead.

## Resolution chains

**Effective repo.** Inside a git work tree, the nearest toplevel is the repo —
even when the resolved config says `workspace`. Ran from `fe/`, work commits in
`fe/`. Ran from the workspace root (no repo), the workspace rules above apply.

**Base branch**, per affected repo:

1. `repos[<dir name>]` in a workspace config; `git.default_branch` in a repo config
2. `git -C <repo> symbolic-ref --short refs/remotes/origin/HEAD`
3. `gh repo view <repo> --json defaultBranchRef -q .defaultBranchRef.name`
4. stop and ask — **never guess `main`**

Steps 2 and 3 can only learn the **remote's default**, which is not necessarily the team's base: a repo whose PRs target `dev` or `staging` still reports `main`. So a probed base is reported as probed, and confirmed by a human before it is written. A wrong base aims PRs at the wrong branch — the exact failure a hand-kept integration table exists to prevent.

A repo on disk but absent from `repos` is a question, not a default. A `repos`
entry with no directory on disk is ignored with one line.

**Branch name**, one per run. Derived once from the plan slug or topic before the
first commit, then passed to every repo. Multi-repo runs pass
`branch:new <name>`; a per-repo derived name would diverge.

Cut from the base, then verify:

```
git fetch origin <base>
git checkout -b <name> origin/<base>
git merge-base HEAD origin/<base>   # must be origin/<base>
```

An ancestry check that fails means the branch was cut from the wrong base —
recreate it. Never leave a PR aimed at the wrong base.

**Mirror remote**, in order: `SASSY_WORKSPACE_REMOTE` → the mirror's own
`origin` → `git.remote` → stop and say setup is incomplete.

**Mirror branch**: `SASSY_WORKSPACE_BRANCH` → the mirror's own
`refs/remotes/origin/HEAD` → `git.default_branch` → `main`.

**Knowledge read.** Every path in `knowledge.read` that exists is searched for
prior learnings; a path that does not exist is skipped with one line. Absence of
matches is a fact worth stating, never evidence that no similar problem exists.

## Hooks

A project injects its own steps into our pipeline by declaring them here. They are
run by the skill that owns the moment, so they fire no matter which pipeline the
user started. Nothing declared means nothing runs.

Only the PR has hook points. Planning, phases, review, and commit do not: their
extension point is `AGENTS.md` for rules, or a project skill the user invokes
directly.

| Point | Owner | Fires |
|-------|-------|-------|
| `before_create` | `sassy-commit-push-pr` | after the commit, before the push and the PR create |
| `after_create` | `sassy-commit-push-pr` | the PR was just created — not on an update |
| `before_merge` | `sassy-babysit` | the PR looks ready **and** this run will merge it |
| `after_merge` | `sassy-babysit` | this run observed the PR merged |

### Contract

- **Resolution**: `<repo>/.agents/skills/<name>/SKILL.md`, nearest walking up.
- **Names**: project-prefixed, and never one of our own skills.
- **Order**: declared order, one worker each, sequential.
- **Brief**: plan path, changed files, artifact paths, base, branch, commit hash,
  and the PR URL where one exists.
- **Result**: `done`, `blocked`, or `needs-decision`. A decision comes back to the
  orchestrator, which holds the gate — a worker never blocks on a prompt.
- **Fail closed**: a missing file or a `blocked` result stops the pipeline and
  names the hook. A mandatory step must never evaporate.
- **Writes**: a hook may write files. Only `before_create` may also **commit**
  them, because it runs after the pipeline's own commit; every other point must
  leave the tree clean.
- **Never**: push, open a PR, change `mode`, `branch`, or `merge`.
- **Idempotent**: `after_merge` can be reached by a later run observing an already
  merged PR, and `before_create` can run again on a re-ship.
- **Per PR**: in a workspace fan-out the hooks run once per PR.

### When they do not fire

`before_merge` and `after_merge` need a merge in this run. `pr.merge` defaults to
`false`, so a project that declares them without enabling merging has inert
hooks — the run says so in one line rather than skipping silently.

## Multi-repo runs

A run that touches N repos produces N commits, N PRs, and one snapshot:

| Artifact | Where |
|----------|-------|
| code | one branch per repo, same name, N commits |
| cross-cutting docs (`artifacts.*`) | the workspace root, one snapshot |
| PRs | one per affected repo, `--base` from `repos` |

Report the result as a table — `repo | base | branch | commit | PR` — and list
partial failures explicitly. Never collapse it into one status.

`pr.babysit` and `pr.merge` apply to **single-PR runs only**. Babysitting a
fan-out means one `sassy-babysit` run per PR; merging a fan-out needs an explicit
per-PR say-so, because one switch would merge N PRs nobody re-read.

## Fail closed vs soft

- **Fail closed** (stop, say why): an unusable `artifacts.*` or `git.*` value.
  A typo must not silently write docs into the wrong place.
- **Soft** (fall back, say so): an unusable `commit.*` or `pr.*` value, and any
  `knowledge.read` path that is missing.

## Validation rules

- `artifacts.*` values are repo-relative directories (or one file for
  `concepts`), must resolve inside the project, and must not be the root itself.
- `git.repo` is `workspace`, `none`, or one existing remote name.
- `git.remote` is required when `git.repo: workspace`; forbidden otherwise.
- `repos` is allowed only when `git.repo: workspace`.
- `hooks` is allowed only with the four keys under `hooks.pr`, each a list of
  skill names that resolve to `.agents/skills/<name>/SKILL.md`.
- `commit.branch` is `current` or `new`; `pr.*` are `true` or `false`. Write
  booleans as `true`/`false`, never `on`/`off` — bare `on`/`off` are YAML 1.1
  booleans and parse inconsistently.
