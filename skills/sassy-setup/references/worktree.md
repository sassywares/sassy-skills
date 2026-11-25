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
and spends the setup step on a checkout nobody needed. `branching.md` owns that
ask. `sassy-worktree` runs after the answer is yes, or when a human asks for a
checkout outright; an existing managed checkout for the branch is reused rather
than a second one cut.

## The project's scripts are the entry point; the toolbox is git only

The suite ships four small scripts that create, list, and remove a checkout — the
git mechanics, project-agnostic and suite-owned. Everything a *particular*
project needs around that (installing dependencies, deriving an `.env`, seeding a
database, stopping a stack) belongs to that project's own pair:
`<home>/worktrees/create` and `<home>/worktrees/remove`, scaffolded by setup from
`assets/templates/`. `sassy-worktree` runs the project's scripts; those call the
toolbox when they need git. Neither the toolbox nor the suite knows how a project
starts or stops its stack.

The pair carries the scaffold header — write-time provenance and the statement
that the file belongs to the project — described once in
[`scaffold-header.md`](scaffold-header.md). Setup installs them new-files-only and
never rewrites them; an untouched pair behaves exactly like calling the toolbox
directly.

## Install

Setup copies `assets/worktree/*` flat into `.sassywares/worktree/`, makes the
three scripts executable, and stops. They are tracked: a worktree is a checkout of
the repo, so every worktree carries the tooling. Setup also scaffolds the
project's pair under `<home>/worktrees/`, probes `<home>`, and records both paths
as `worktrees.create` and `worktrees.remove` — [`init.md`](init.md) step 6.

**No command runner is required and no manifest is created.** Every caller — the
suite included — runs them by path, `.sassywares/worktree/create <branch>`. Setup
never writes a `package.json`, a `Makefile`, or a `justfile` so that an alias has
somewhere to live; a Go, Python, or Dart project keeps its own tooling file and
nothing else.

| Script | Does | Ends with |
|---|---|---|
| `create <branch> [--from <ref>]` | cuts the branch untracked (or shows an existing checkout) | the four `WT_*` lines on stdout |
| `list [--path <slug>] [--env <slug\|branch>]` | the table: branch, path, dirty, upstream, state | what it prints; a flag prints one value for scripting |
| `remove <slug\|branch> [--force]` | the refusals below, then deletes the checkout | a surviving branch |
| `_lib.sh` | shared helpers: config, slug, namespace, identity, upstream state | sourced, never run |

**Streams are a contract.** `create` puts only the four `WT_*` identity lines on
stdout, once, at the end of a successful run; every human line (progress, the
upstream it found, a warning) goes to stderr. `list --env` prints the same four
lines and nothing else. `remove` writes every human line to stderr and nothing to
stdout — nothing consumes its stdout. A caller can `eval` stdout while a person
still reads the narration, and `create` and `list --env` are interchangeable for
that.

**Exit codes.** `0` success, `1` a refusal with the reason, `2` bad usage with the
usage on stderr — a usage error touches nothing. A removal either happened or was
refused before touching anything.

Nothing else lives there. No state, no registry, no pid file. Every script takes
`--version` (prints `WT_VERSION`) and `--help` (its own usage).

**Aliases are a convenience, never a requirement.** When the project already has a
file at the root that carries named commands — `package.json` `scripts`,
`deno.json` `tasks`, `composer.json` `scripts`, a `Makefile` or `justfile` target —
setup offers to add one `worktree:<script>` entry per script, append-only, by
`workspace.md`'s merge rules, and declining is a complete install. It never creates
such a file to hold them: a path works in every shell, hook, and delegation brief
with no runner in between.

The installed toolbox is suite-owned and read-only: nothing under
`.sassywares/worktree/` is the project's to edit. `--check` hashes the installed
files the way `skills-lock.json` hashes a skill folder, so a differing byte is
drift and the file is named. Setup overwrites the set without asking, because
there is no legitimate project edit to preserve. The project's scripts under
`<home>/worktrees/` are the opposite: wholly the project's, never rewritten.

**The missing-script degrade.** `scripts/detect.sh --worktree-script create|remove`
answers which path a run executes. A declared path is relative to the project
root. An absent key falls back to the built-in silently — a project that deleted
the pair means it. A declared value that is unusable — a missing or non-executable
file, whitespace or arguments, an absolute or `~/` path, `..`, a list, or a block —
warns on stderr naming the key and the file, then falls back to the built-in. The
rule and its warning live in [`config.md`](config.md)'s Lifecycle.

**Upgrading the toolbox: version 12 → 13.** `# worktree-version:` in `_lib.sh` and
`WT_VERSION` move together. 13 deletes `prune`: what it classified is now a state
column on `list`, and `remove` keeps the branch, so "merged" was never a data-safety
gate. `--check` treats a 12 header as an upgrade rather than tampering; the fix is
a setup re-run, which overwrites the set. Then delete a stale
`.sassywares/worktree/prune` if one is still there — nothing reads it. An install
at version 8 or lower may also carry `<worktree home>/ports/`; inert, delete it.

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

The folder is named after the repo. When another **live** clone of the same name
already owns it, this one takes `<repo>-<hash>` instead; a home whose recorded
owner no longer exists is reclaimed, so a finished project does not squat the name
for ever. `.repo` is what makes that decision, and `create` rewrites it.

**Never put checkouts inside `.git` or inside the working tree.** Inside `.git`
is undocumented and breaks where `.git` is a file (linked worktrees, submodules,
`--separate-git-dir`). Inside the working tree is destroyed by `git clean -xdf`
and crawled by every scanner that does not read `.gitignore` (`tsc`, Docker).

**Never `rm -rf` the worktree home.** It is full of checkouts with uncommitted
work; `remove` is the only safe exit.

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
  decision, and a push names its remote. A caller that has already resolved the
  base passes `--from`; the script never guesses.

## The namespace

`create` derives and prints the identity a caller inherits:

| Variable | Example | Use |
|---|---|---|
| `WT_PATH` | `~/.sassywares/worktrees/shop/feat-catalog` | where the checkout is |
| `WT_BRANCH` | `feat/catalog` | the branch, as git names it |
| `WT_SLUG` | `feat-catalog` | the directory name; the handle `list` and `remove` take |
| `WT_NAMESPACE` | `shop-feat-catalog` | database schema, compose project, simulator name |

The same names are what a project's `create` and `remove` slots expand. Derived,
never invented downstream: a script that needs a database name uses
`$WT_NAMESPACE` rather than building its own, so two worktrees cannot collide by
accident. `create` mints an identity; `remove` receives one.

**Finding a checkout.** `list` prints paths with `$HOME` shortened to `~`, which
reads well and does **not** paste into anything:

```bash
cd "$(.sassywares/worktree/list --path feat-catalog)"   # the real absolute path
```

`list --env <slug|branch>` prints the four assignments. A slug that matches two
branches (`feat/x` and `feat-x`) is an error naming every match, never a first
pick.

```bash
eval "$(.sassywares/worktree/list --env feat/catalog)"
```

## The state column, and removing several checkouts

`list` adds a state per managed checkout, from the branch's upstream:

| State | Means |
|---|---|
| `merged` | HEAD is an ancestor of the tracked upstream — the work is on a remote |
| `gone` | the branch tracks nothing, so "merged" is unknowable |
| `unmerged` | there are commits the upstream does not have |

`remove <slug>` refuses a dirty tree, unpushed commits, or the main checkout, and
removes one checkout. There is no bulk `prune`: a user who says "remove the merged
ones" gets the list, a confirmation, and a sequential walk over each `merged` row —
one `remove <slug>` at a time, reporting each refusal and continuing, so one
blocked checkout does not hide the rest. Slower by design, and every row is
visible before it goes.

`remove` deletes the checkout and nothing else. **The branch survives** — git keeps
it, so the work is still reachable after the worktree is gone. Deleting it is the
user's call, or `pr.delete_branch`'s after a merge. `--force` skips the dirty and
unpushed checks and nothing else; it is never implied. When git removes the
registration but not the folder, the script says so and exits `1` rather than
claiming success.

## A project's `remove` runs four steps in order

The scaffold's slots exist because the order is the point:

```text
identity  ->  stop  ->  delete  ->  dispose
list --env    project   toolbox    project
              (files    (git)      ($WT_NAMESPACE
               exist)               still set)
```

1. **Identity** — `list --env` gives `WT_PATH`, `WT_BRANCH`, `WT_SLUG`,
   `WT_NAMESPACE`. Asking the toolbox means the names are the ones `create`
   minted; `remove` never rebuilds a slug.
2. **Stop, while the checkout still exists** — the project stops whatever it
   started for this checkout. A process holding the tree is what makes a removal
   half-fail.
3. **Delete** — the toolbox's `remove` runs its guards and deletes the tree.
4. **Dispose, after the tree is gone** — `$WT_NAMESPACE` is still set, so the
   project drops what it derived: a database, a preview deployment, a simulator.

There is no hook handshake, no `--hook-ok`, and no exit `3`: a shell script cannot
dispatch a skill, so anything needing one is the agent's job before it calls the
script. The scaffold's slots are labelled comments — a comment is where a project
writes a step, and setup writes none of them as code.

## The suite carries no stack, no port, and no registry

Two checkouts running the same app collide only if the project's own scripts let
them. The suite carries no address and no port range and never derives one; a
port belongs in the project's `create`, derived from `$WT_SLUG` (a hash, because
nothing here tracks claims, so a collision is possible and the script is where it
surfaces).

`list` reports branches, paths, dirty state, upstreams, and the state column, and
nothing else: the suite keeps no registry, no pid file, and nothing to go stale.

## Refusals

| Condition | Why |
|---|---|
| It is the main checkout | the repo itself |
| A dirty tree | uncommitted work |
| Commits on no remote | nothing to recover from |
| A checkout outside the worktree home, or without `.sassywares/config.yaml` | it is not managed here — another tool's, or cut before the wiring |
| A branch already checked out elsewhere | git's own refusal; `create` reports it as such |

`--force` skips the dirty and unpushed checks only.

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
  through one checkout corrupts the other. Let the package manager's store do the
  deduplicating.
- **`worktrees.enabled` needs `commit.branch: new`.** Under `current` a run
  commits where it stands and never cuts a branch, so no run would ever offer a
  worktree; `--check` notes the combination.
