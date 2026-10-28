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

**A token is explicit only when the caller supplied it.** Three sources qualify:

1. the user typed it in the request;
2. an approval gate earlier in the same run authorized that side effect;
3. the run's own orchestration decision, already recorded in its gate summary —
   for example `sassy-ship` passing `babysit:off` because its step 6 owns the
   babysit, or `sassy-work` forwarding `branch:current` because its step 2 cut
   the branch and the gate showed it.

What never qualifies is **this skill's own default**. Once a default sits in the
slot, nothing downstream can tell it apart from the user's choice, so it
silently outranks the project's config. A skill defers to config by **omitting**
the token, never by passing a value it invented. That is how `commit.branch`
became unreachable while every skill still read as if it explained the rule.

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
  base_map:                 # head branch -> the base it targets
    "*": staging            # ordinary work branches from and targets staging
    staging: main           # staging releases to main
  remote: owner/backup      # workspace only: the snapshot mirror
  mirror_branch: main       # workspace only: the mirror's branch
repos:                      # workspace only: sibling dir -> PR base
  fe: dev
commit:
  branch: new               # current | new
pr:
  babysit: true
  merge: false
  delete_branch: false
hooks:
  pr:
    "*":
      before_create: [tap2-version mode:auto]
    staging:
      before_create: []
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
| `git.base_map` | probed `"*"` | Head branch → the base it targets. `"*"` is required |
| `git.remote` | mirror of `git.repo` | Workspace only: mirror remote (URL or `owner/name`) |
| `git.mirror_branch` | `main` | Workspace only: the branch the mirror pushes to |
| `repos` | `{}` | Workspace only: repo dir name → the base its PRs target |
| `commit.branch` | `new` | Resolved once per run, before the first change. `new` never commits on a base branch: `sassy-work`, `sassy-lfg`, and `sassy-debug` cut a branch first. `current` commits where you stand, base branch included, and the close-out pushes it to its upstream with no PR |
| `pr.babysit` | `true` | Whether close-out babysits the PR it opened |
| `pr.merge` | `false` | `true` authorizes merging a single babysat PR |
| `pr.delete_branch` | `false` | Delete the head branch once merged |
| `hooks.pr.<pattern>.<point>` | `[]` | Project steps, keyed by the PR's head branch |

Paths are relative to the config's own directory, never to the cwd.

## `git.repo` — the three topologies

| Value | Meaning |
|-------|---------|
| a remote name (`origin`) | This folder is the repo. Git commits, PRs, and babysit are normal |
| `workspace` | Not a repo at this root. Repos live below; this folder's glue is versioned by the snapshot mirror |
| `none` | Deliberate off-switch. No git anywhere here |

`workspace` and `none` are reserved words; a remote cannot be named either.

`base_map` is repo-only. `remote` and `mirror_branch` are workspace-only and
describe the snapshot mirror — in a repo config the remote is simply
the value of `git.repo`.
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

## `commit.branch` — decide once, before code

Resolved once per run, by the entry skill (`sassy-work`, `sassy-lfg`,
`sassy-debug`), **before the first change**, through
`sassy-setup/references/branching.md`. Not at commit time: committing first and
re-branching later leaves the commits on a base branch, and cutting the new
branch from `origin/<base>` then leaves them behind entirely.

| Value | Meaning |
|-------|---------|
| `current` | Commit where you stand, even on a base branch, then push the branch to its upstream (never forced) with no PR. An explicit statement that this repo's work in progress is acceptable |
| `new` (default) | Never commit on a base branch. Cut one first, then stay on it for the rest of the run |

A branch that is already checked out and is **not** a base is reused, whatever
the config says. That is what makes a second phase, a resumed run, or a
handed-off session converge on the branch the first one cut instead of cutting
another.

A base is **any `base_map` value**, plus the remote default — not the remote
default alone. In the config above `staging` is a base because `"*"` targets it,
even though `origin/HEAD` is `main`. Comparing only against `origin/HEAD` is how
phase work once got committed straight onto `staging`.

Under `current` the close-out skips the PR pipeline: `pr.*` and `hooks.pr.*`
are ignored (`before_create`, `after_create`, `before_merge`, `after_merge` never
run), and there is no babysit or merge. A non-fast-forward push stops the run.
Only this config value triggers it. A typed `branch:current` token, or the one
skills forward to `sassy-commit`, does not suppress the PR.

The `branch:infer|current|new` token on those skills overrides this key for one
run, for branching only; the no-PR close-out follows the config
`commit.branch: current` regardless of the token; `infer` means this key decides. In a workspace the key is resolved from the
workspace config for the whole run, one branch name in every repo; a nested
repo whose own `commit.branch` disagrees is drift, because one run cannot follow
two policies.

## Resolution chains

**Effective repo.** Inside a git work tree, the nearest toplevel is the repo —
even when the resolved config says `workspace`. Ran from `fe/`, work commits in
`fe/`. Ran from the workspace root (no repo), the workspace rules above apply.

**Base branch of a head.** `base_map` answers one question — *given this head,
what does a PR target?* — so there is no free-floating "default branch":

```
feature/x  --base_map["*"]-->     staging  --base_map[staging]-->  main
```

1. `base_map[<head>]` — the exact rung
2. the longest matching family key (`release/*`) — a nested rung
3. `base_map["*"]` — ordinary work
4. stop and ask; never guess

A rung is a release edge: standing on `staging`, a PR targets `main` without
anyone passing `base:main`. Add a rung for any branch that releases elsewhere; a
three-rung ladder is just one more line. The map must be acyclic, and `"*"` must
exist — that is the rung everything falls back to.

The probed remote default is only useful as a hint for `"*"`: it tells you where
the repository considers work to land, not what every branch targets. Confirm it
before writing.

`--head <branch>` prints the resolution for one head: the base (repo topology)
and all four hook points. Use it instead of merging maps by hand.

In a `workspace`, `base_map` does not apply — there are no branches at the
workspace level. A nested repo's base resolves in this order:

1. that repo's own `.sassywares/config.yaml` → `base_map` — **authoritative**
2. `repos[<dir>]` in the workspace config — the inventory, and the fallback for a
   repo that carries no config
3. stop and ask

`repos` exists because a workspace can hold repos you do not own and cannot add a
config to. When a repo has both, the nested config wins and `--check` reports
the disagreement rather than picking silently. A nested config needs no ladder
of its own unless its PRs target more than one branch.

**Branch name**, one per run. Derived once from the plan slug or topic when the
run starts, then used in every repo. The branch is cut at the start of the run,
not at commit time, so every repo sits on it before any change exists; each
repo cuts from its own upstream base and reuses the name in the others.

Cut from the base, then verify:

```
git fetch <remote> <base>
git checkout -b <name> <remote>/<base>
git merge-base HEAD <remote>/<base>   # must be <remote>/<base>
```

An ancestry check that fails means the branch was cut from the wrong base —
recreate it. Never leave a PR aimed at the wrong base.

**Mirror remote**, in order: `SASSY_WORKSPACE_REMOTE` → the mirror's own
`origin` → `git.remote` → stop and say setup is incomplete. The value may be an
`owner/name` shorthand, a URL, an scp-style remote, or a local path; the
shorthand expands to `https://github.com/owner/name.git`, everything else is
used verbatim.

**Mirror branch**: `SASSY_WORKSPACE_BRANCH` → the mirror's own
`refs/remotes/origin/HEAD` → `git.mirror_branch` → `main`.

**Knowledge read.** Every path in `knowledge.read` that exists is searched for
prior learnings; a path that does not exist is skipped with one line. Absence of
matches is a fact worth stating, never evidence that no similar problem exists.

## Hooks

A project injects its own steps into the PR pipeline. They run by the skill that
owns the moment, so they fire whichever pipeline the user started. Nothing
declared means nothing runs.

**Keys are the head branch** — the branch the PR comes from, never the one it
targets. `hooks.pr.staging` means *PRs whose source is staging*.

| Key form | Matches |
|----------|---------|
| `staging` | that exact head |
| `release/*` | a family; only one trailing `*` is allowed |
| `"*"` | every other head |

| Point | Owner | Fires |
|-------|-------|-------|
| `before_create` | `sassy-commit-push-pr` | after the commit, before the push and the PR create |
| `after_create` | `sassy-commit-push-pr` | the PR was just created — not on an update |
| `before_merge` | `sassy-babysit` | the PR looks ready **and** this run will merge it |
| `after_merge` | `sassy-babysit` | this run observed the PR merged |

### Resolution

Per point, independently:

1. the exact head
2. the longest matching family, if the head starts with its prefix
3. `"*"`

The first rule that declares a value for that point wins and the rest are not
merged, so a `staging` entry that sets only `before_create` still inherits
`after_merge` from `"*"`. When two families match one head, the longer prefix
wins — `release/v2/*` beats `release/*`.

### Entries carry arguments

An entry is `<skill>` or `<skill> <args…>`, split on the first whitespace. Args
are passed to the hook verbatim — they are that skill's vocabulary, not ours. A
hook skill documents the args it accepts and must not silently ignore one.

Args are how a project pre-authorizes a step: `tap2-version mode:auto` runs
versioning without its approval prompt. Treat it like `pr.merge: true` — visible
in review, and commented when it is deliberate.

### Contract

- **Resolution**: `<repo>/.agents/skills/<name>/SKILL.md`, nearest walking up.
- **Names**: a skill the project owns, never one of ours.
- **Order**: declared order, one worker each, sequential.
- **Brief**: plan path, changed files, artifact paths, base, branch, commit hash,
  and the PR URL where one exists.
- **Result**: `done`, `blocked`, or `needs-decision`; a decision comes back to the
  orchestrator, which holds the gate.
- **Fail closed**: a missing skill or a `blocked` result stops the pipeline.
- **Writes**: only `before_create` may also commit, because it runs after the
  pipeline's commit; every other point leaves the tree clean.
- **Never**: push, open a PR, change `mode`, `branch`, or `merge`.
- **Idempotent**: `after_merge` can be reached by a later run observing an
  already merged PR, and `before_create` can run again on a re-ship.
- **Per PR**: in a workspace fan-out the hooks run once per PR.

### When they do not fire

`before_merge` and `after_merge` need a merge in this run. `pr.merge` defaults to
`false`, so a project that declares them without enabling merging has inert
hooks — the run says so in one line rather than skipping silently.

## Multi-repo runs

A run that touches N repos produces N commits, N PRs (no PRs under `current`), and one snapshot:

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
  `git.mirror_branch` and `repos` are workspace-only too.
- `hooks` is allowed only with the four keys under `hooks.pr`, each a list of
  skill names that resolve to `.agents/skills/<name>/SKILL.md`.
- `commit.branch` is `current` or `new`; `pr.*` are `true` or `false`. Write
  booleans as `true`/`false`, never `on`/`off` — bare `on`/`off` are YAML 1.1
  booleans and parse inconsistently.
- `knowledge.read` is an inline list (`read: [a, b]`). A block list is not read
  by the config reader, so it would silently scout nothing.
- An unknown key is an error, not a fallback: a typo parses, is ignored, and the
  run uses a default this project never chose.

`scripts/detect.sh --check` enforces all of the above and reports each breach as
a `drift:` line, exiting non-zero. It also verifies the vendored pin offline:
every `.agents/skills/sassy-*` folder is hashed with the `skills` CLI's own
definition and compared to `computedHash` in `skills-lock.json`, the lock is
checked against the installed set in both directions, and git-tracked state of
the lock is reported. A stale, hand-edited, or half-installed suite is drift
even when the config itself matches the tree.
