# Worktrees

Parallel work in one repo: each run gets its own checkout, its own branch, and
its own port, without a second clone and without fighting the checkout somebody
else is using.

Read this when the project has `worktrees.enabled: true`, or when the user asks
to run two agents in one project.

## Install

Setup copies `assets/worktree/*` flat into `.sassywares/worktree/`, makes the
scripts executable, and wires one `worktree:<script>` alias per script into the
project's manifest — the same exception `workspace:*` uses. They are tracked: a
worktree is a checkout of the repo, so every worktree carries the tooling.

```text
.sassywares/worktree/
├── _lib.sh    shared helpers; reads `worktrees:`; carries worktree-version
├── create     add a worktree, claim a port, print the namespace
├── list       the table; --address / --path for scripting
├── stop       kill whatever is on that worktree's port
├── remove     refuse unsafe removals, then delete
└── prune      merged-or-gone candidates; removes only what you approve
```

Nothing else lives there. No state, no registry, no pid file.

`_lib.sh` carries `# worktree-version: N`. Bump `N` when an asset changes;
`--check` compares the installed copy and reports a stale one. Ask before
overwriting an existing copy — from the first install it is the project's file.

## Where things live

```text
~/.sassywares/worktrees/
└── <repo>/          <- the worktree home; .repo records which checkout owns it
    ├── .repo        absolute path of the main checkout
    ├── ports/       claim directories, one per claimed port
    └── <slug>/      a checkout
```

`worktrees.dir` sets the parent (default `~/.sassywares/worktrees`). It is the
one path in the config that may be absolute or start with `~/` — it names
machine-local state, not something a teammate clones.

**Never put checkouts inside `.git` or inside the working tree.** Inside `.git`
is undocumented and breaks where `.git` is a file (linked worktrees, submodules,
`--separate-git-dir`). Inside the working tree is destroyed by `git clean -xdf`
and crawled by every scanner that does not read `.gitignore` (`tsc`, Docker).

**Never `rm -rf` the worktree home.** It is full of checkouts with uncommitted
work; `remove` and `prune` are the only safe exits.

## The namespace

`create` derives and prints, for the caller and the hook:

| Variable | Example | Use |
|---|---|---|
| `WT_PATH` | `~/.sassywares/worktrees/shop/feat-catalog` | where the checkout is |
| `WT_BRANCH` | `feat/catalog` | the branch, as git names it |
| `WT_SLUG` | `feat-catalog` | the directory name, port key, registry key |
| `WT_NAMESPACE` | `shop-feat-catalog` | database schema, compose project, simulator name |
| `WT_PORT` | `3041` | the private port this checkout owns |
| `WT_BASE_URL` | `http://localhost:3041` | what to open |

Derived, never invented downstream: a hook that needs a database name uses
`$WT_NAMESPACE` rather than building its own, so two worktrees cannot collide by
accident.

**Ports.** The slug hashes into `worktrees.ports`, then the claim is taken with
an atomic `mkdir` and probed forward one port at a time on a collision. A claim
belongs to a slug, so a restarted app returns to the same port, and two slugs
that hash alike do not fight. `list` probes for liveness and never trusts a
recorded pid: a killed process leaves nothing to believe.

## Hooks

Two points, keyed by head branch like every other hook:

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

## Previewing a worktree

`sassy-worktree mode:preview` brings the product up in a checkout and prints
`how_to_see`, using the dogfood recipe's bring-up steps — everything up to, but
not including, that section's `Prove it:` step. It leaves the app running, and
`stop` (or `remove`) reaps it by port.

There is no separate preview configuration. How the app comes up is the recipe's
job, because it is the only place that knowledge is allowed to live.

**Sessions and third-party origins.** A worktree gets a fresh, empty
`.sassywares/session/`. Most providers register one callback URL, so a worktree
usually cannot log in on its own; the recipe's *Working in a second checkout*
section says how this project solves that, and the `after_create` hook does it —
copying or linking the main checkout's session is the common answer. A cookie is
host-scoped and crosses ports freely; a `localStorage` session is origin-scoped,
port included, and has to be injected per origin. That difference is worth
writing down once in the recipe rather than rediscovering it.

## Refusals

`remove` refuses, and `prune` skips rows it cannot prove safe:

| Condition | Why |
|---|---|
| It is the main checkout | the repo itself |
| Dirty tree | uncommitted work |
| Commits on no remote | nothing to recover from |
| Something listening on its port | stop the app first |
| A `before_remove` hook not yet run | the project has cleanup to do |

`--force` skips the dirty and unpushed checks and nothing else. It is never
implied.

## Concurrency rules

- **One worktree per run.** `references/branching.md` decides; a run already on
  a non-base branch reuses it, so a second `sassy-work` in the same checkout does
  not nest another worktree.
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
  commits where it stands and never cuts a branch, so no run would ever create a
  worktree; `--check` notes the combination.
