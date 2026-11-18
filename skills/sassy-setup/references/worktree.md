# Worktrees

Parallel work in one repo: each run gets its own checkout, its own branch, and
its own port, without a second clone and without fighting the checkout somebody
else is using.

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
| `WT_SLUG` | `feat-catalog` | the directory name, port key, registry key |
| `WT_NAMESPACE` | `shop-feat-catalog` | database schema, compose project, simulator name |
| `WT_PORT` | `3041` | a private port — **only when `ports:` is configured** |
| `WT_BASE_URL` | `http://localhost:3041` | the URL on that port — same condition |

The same five names expand inside the recipe, including the dashed form
`${WT_PORT:-5180}` that makes a recipe runnable in the main checkout too.

**Finding a checkout.** `list` prints paths with `$HOME` shortened to `~`, which
reads well and does **not** paste into anything:

```bash
cd "$(worktree:list --path feat-catalog)"     # the real absolute path
worktree:list --address feat-catalog          # the URL, when ports are configured
```

`create --env` prints `WT_PATH=` and the rest for scripts, and a slug is just the
branch with `/` flattened.

Derived, never invented downstream: a hook that needs a database name uses
`$WT_NAMESPACE` rather than building its own, so two worktrees cannot collide by
accident.

**A port is a resource, not the model.** `worktrees.ports` is optional, and
deleting it is how a project says "my preview is not a URL". Then no port is
derived, nothing is claimed, `WT_PORT` and `WT_BASE_URL` are absent, and the
checkout is addressed by the recipe's `**Preview:**` line instead. That covers a
mobile app (a simulator named `$WT_NAMESPACE`), a desktop app (a window), and a
CLI or library (nothing to look at).

**One port models a single service.** A stack that serves a web app, a docs site,
and a backend at once has more than one address per checkout; the claim covers the
one a human opens, and the recipe's steps carry the rest (distinct ports per
service, derived from `$WT_PORT` or fixed by the project). Do not add a port list
to the config for this — it is procedure, not identity.

When a range *is* configured: the slug hashes into it, the claim is taken with an
atomic `mkdir`, and a collision probes forward one port at a time. A claim
belongs to a slug, so a restarted app returns to the same port and two slugs that
hash alike do not fight.

**Liveness and stopping follow the address, not the claim.** `list` probes the port
the checkout advertises — its claim if it has one, otherwise the port its recipe's
`**Preview:**` line names — and never trusts a recorded pid. `stop` kills by that
same address, and `remove` refuses to delete a checkout while it answers. A preview
that names no port at all (a simulator, a desktop window) has nothing to probe, so
`LIVE` reads `—` and stopping it is the project's job.

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

## Previewing a worktree

`sassy-worktree mode:preview` brings the product up in a checkout and prints how
to see it, using the dogfood recipe's bring-up steps — everything up to, but not
including, that section's `Prove it:` step. It leaves the app running.

How to see it is the recipe's `**Preview:**` line with the namespace substituted,
so it is a URL, a simulator, or a window depending on the project and never a
guess by this tooling. `list` prints that same line in its `HOW TO SEE` column,
which is why the column is not called "address".

What stops a preview follows from the same split: kill it by port when there is
one, hand it to the project when there is not.

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
| Something listening on its advertised address | stop the app first |
| A `before_remove` hook not yet run | the project has cleanup to do |

`remove` deletes the checkout, the port claim, and nothing else. **The branch
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
