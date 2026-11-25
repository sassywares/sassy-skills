# Worktrees

Parallel work in one repo: each run gets its own checkout and its own branch,
without a second clone and without fighting the checkout somebody else is using.

**Repo topology only.** `git.repo: workspace` means the root is not a repo and each
nested repo carries its own config, so there is nothing to cut a checkout from; a
`none` folder has no git at all. Setup writes `worktrees.enabled: false` there and
says why, `--check` reports an `enabled: true` as drift, and the scripts refuse
with that reason rather than "not a git repository".

Read this when the project has `worktrees.enabled: true`, when a run is about to
cut a branch, or when the user asks to run two agents in one project.

**`enabled: true` is permission, not a default.** A run asks before it takes a
checkout — or takes one on a `worktree:on` token — and stays in the main one
otherwise: two runs only collide when they are actually parallel, and one taken
unasked moves the work to another directory, leaves the uncommitted tree behind,
and spends the `after_create` setup on a checkout nobody needed. `branching.md`
owns that ask. `sassy-worktree` runs after the answer is yes, or when a human
asks for a checkout outright; an existing managed checkout for the branch is
reused rather than a second one cut.

## Install

Setup copies `assets/worktree/*` flat into `.sassywares/worktree/`, makes the
four scripts executable, and stops. They are tracked: a worktree is a checkout of
the repo, so every worktree carries the tooling.

**No command runner is required and no manifest is created.** Every caller — the
suite included — runs them by path, `.sassywares/worktree/create <branch>`. Setup
never writes a `package.json`, a `Makefile`, or a `justfile` so that an alias has
somewhere to live; a Go, Python, or Dart project keeps its own tooling file and
nothing else.

| Script | Does | Ends with |
|---|---|---|
| `create <branch> [--from <ref>] [--env]` | cuts the branch untracked | the `WT_*` block (`--env`), the upstream it found, and the `after_create` hooks to dispatch |
| `list [--path <slug>]` | the table: branch, path, dirty, upstream | what it prints; a flag prints one value for scripting |
| `remove <slug\|branch> [--hook-ok] [--force]` | the refusals below, then deletes the checkout | a surviving branch |
| `prune [--yes]` | merged-or-gone, clean, fully pushed — and no `down:` or `before_remove` hook it cannot run | the removals, and why each skipped row was skipped |

`_lib.sh` is shared helpers — it reads `worktrees:` and carries the version; it is
sourced, never run. Every script takes `--version` (prints `worktree-version`) and
`--help` (its own usage). Exit codes: `0` success, `1` a refusal with the reason,
`2` bad usage, and `3` from `remove` when an obligation is left that a shell
cannot dispatch — a declared `before_remove` hook, or a `down:` that names a
skill — and `--hook-ok` is missing. `--hook-ok` is the caller saying the hook
and the `down:` skill have been dispatched, so that exit is the handshake, not an
error to route around.

Nothing else lives there. No state, no registry, no pid file.

**Aliases are a convenience, never a requirement.** When the project already has a
file at the root that carries named commands — `package.json` `scripts`,
`deno.json` `tasks`, `composer.json` `scripts`, a `Makefile` or `justfile` target —
setup offers to add one `worktree:<script>` entry per script, append-only, by
`workspace.md`'s merge rules, and declining is a complete install. It never creates
such a file to hold them: a path works in every shell, hook, and delegation brief
with no runner in between.

The installed set is suite-owned and read-only: nothing under `.sassywares/`
but `config.yaml` is the project's to edit. `--check` hashes the installed
files the way `skills-lock.json` hashes a skill folder, so a differing byte is
drift and the file is named. Setup overwrites the set without asking, because
there is no legitimate project edit to preserve.

## Where things live

```text
~/.sassywares/worktrees/
└── <repo>/          <- the worktree home; .repo records which checkout owns it
    ├── .repo        absolute path of the main checkout
    └── <slug>/      a checkout
```

`worktrees.dir` sets the parent (default `~/.sassywares/worktrees`). It is the
one path in the config that may be absolute or start with `~/` — it names
machine-local state, not something a teammate clones.

**An install at `worktree-version` 8 or lower also has `<worktree home>/ports/`**
— a folder of claim directories. Nothing reads it any more: it is inert and can be
deleted.

The folder is named after the repo. When another **live** clone of the same name
already owns it, this one takes `<repo>-<hash>` instead; a home whose recorded
owner no longer exists is reclaimed, so a finished project does not squat the name
for ever. `.repo` is what makes that decision, and `create` rewrites it.

**Never put checkouts inside `.git` or inside the working tree.** Inside `.git`
is undocumented and breaks where `.git` is a file (linked worktrees, submodules,
`--separate-git-dir`). Inside the working tree is destroyed by `git clean -xdf`
and crawled by every scanner that does not read `.gitignore` (`tsc`, Docker).

**Never `rm -rf` the worktree home.** It is full of checkouts with uncommitted
work; `remove` and `prune` are the only safe exits.

## The branch

`create` cuts a new branch **untracked** and prints the upstream it found:

- **A fresh checkout's branch follows nothing.** Cut from `origin/staging`, git's
  DWIM would make `staging` that branch's upstream, so the branch's own
  `git push` aims at the base — a run that reads as healthy right up until it
  ships. A checkout is a branch of its own, never a follower.
- **An existing branch keeps whatever it tracks**, and `create` says so on its
  `upstream` line; one that is not the branch's own name is called out with what
  a plain push would hit. That is the state a branch cut by hand arrives in.
- **`create` never resolves a base.** The base is `references/branching.md`'s
  decision, and a push names its remote.

## The namespace

`create` derives and prints, for the caller and the hook:

| Variable | Example | Use |
|---|---|---|
| `WT_PATH` | `~/.sassywares/worktrees/shop/feat-catalog` | where the checkout is |
| `WT_BRANCH` | `feat/catalog` | the branch, as git names it |
| `WT_SLUG` | `feat-catalog` | the directory name; the handle `list` and `remove` take |
| `WT_NAMESPACE` | `shop-feat-catalog` | database schema, compose project, simulator name |

The same names expand inside a hook's brief.

**Finding a checkout.** `list` prints paths with `$HOME` shortened to `~`, which
reads well and does **not** paste into anything:

```bash
cd "$(.sassywares/worktree/list --path feat-catalog)"   # the real absolute path
```

`create --env` prints `WT_PATH=` and the rest for scripts, and a slug is just the
branch with `/` flattened.

Derived, never invented downstream: a hook that needs a database name uses
`$WT_NAMESPACE` rather than building its own, so two worktrees cannot collide by
accident.

**Addressing a checkout is the project's own business**: how it is looked at, and
what brings it up, are the project's `up:` and `down:` pair — see
[`config.md`](config.md), Lifecycle. Two checkouts running the same app collide
only if that `up:` lets them.

**Liveness and stopping are the project's.** `list` reports branches, paths, dirty
state, and upstreams, and nothing else: the suite keeps no registry, no pid file,
and nothing to go stale. `remove` refuses a dirty tree, unpushed commits, or the
main checkout, and a configured `down:` is the project's own stop step.

## Hooks

Two points, keyed by head branch like the PR hooks:

```yaml
hooks:
  worktree:
    "*":
      after_create: [shop-worktree]
      before_remove: [shop-worktree]
```

`after_create` runs **after** the checkout exists — that is when a project
installs dependencies, derives `.env` from `$WT_NAMESPACE`, seeds a database or
creates a simulator, and copies the session. `before_remove` runs **before** the
files go, and is where the derived database or device is dropped.

A shell script cannot dispatch a skill, so `remove` fails closed: with a hook
declared and `--hook-ok` missing, it prints `require-hook <name>` and exits `3`.

**Never write a hook skill yourself** — the same rule as every other hook. Setup
records the name; the project writes the body.

**Sessions and third-party origins.** A worktree gets a fresh, empty
`.sassywares/session/`. Most providers register one callback URL, so a worktree
usually cannot log in on its own, and the `after_create` hook is where a project
solves it — copying or linking the main checkout's session is the common answer.
A cookie is host-scoped; a `localStorage` session is origin-scoped and has to be
injected per origin. That difference is worth writing down once rather than
rediscovering it.

## Refusals

`remove` refuses, and `prune` skips rows it cannot prove safe:

| Condition | Why |
|---|---|
| It is the main checkout | the repo itself |
| Dirty tree | uncommitted work |
| Commits on no remote | nothing to recover from |
| A `before_remove` hook not yet run | the project has cleanup to do |
| A `down:` or `before_remove` hook `prune` cannot run | it runs neither, so `--yes` sends the row to `remove` |

`prune --yes` removes nothing on a project with a `down:` configured — real or the
generated stub — or a `before_remove` hook: it can run neither, so every
otherwise-removable checkout is listed for `remove <slug>` to handle instead. That
is by design, not a bug.

`remove` deletes the checkout and nothing else. **The branch
survives** — git keeps it, so the work is still reachable after the worktree is
gone. Deleting it is the user's call, or `pr.delete_branch`'s after a merge.

`--force` skips the dirty and unpushed checks and nothing else. It is never
implied.

## Concurrency rules

- **One worktree per run.** `references/branching.md` decides; a run already on
  a non-base branch reuses it, so a second `sassy-work` in the same checkout does
  not nest another worktree.
- **Enabled is permission, not a default.** A run offers a checkout and takes one
  only on the user's yes; the main checkout is where work happens until then.
- **A `worktree:on` token is that yes.** A human asking outright is not asked
  again, and a managed checkout that already exists for the branch is reused
  instead of cutting a branch in place.
- **Never operate on another worktree.** A delegation brief carries the absolute
  path of the checkout it may touch; `MAIN` is for reading config and listing.
- **Never `git stash`.** It is repository-global: a stash taken in one worktree
  appears in all of them. A worktree already gives you what stash was for.
- **Never `git checkout` a branch in two places.** Git refuses it — that refusal
  is a feature, and `create` reports it as such.
- **Do not copy `node_modules`.** Hardlink copies share inodes, so a rewrite
  through one checkout corrupts the other. Let the package manager's store do
  the deduplicating.
- **`worktrees.enabled` needs `commit.branch: new`.** Under `current` a run
  commits where it stands and never cuts a branch, so no run would ever offer a
  worktree; `--check` notes the combination.
