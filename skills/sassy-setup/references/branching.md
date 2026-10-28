# Branching

One branch decision per run, made **before** the first change. `sassy-work`,
`sassy-lfg`, and `sassy-debug` all resolve it here, through one detector, so the
three cannot drift apart the way three hand-copied paragraphs would.

## Resolve

Run the `sassy-setup` skill's `scripts/detect.sh` — by skill name, never by an
absolute install path, because a consumer's copy may live in `.agents/skills/`
or anywhere else a harness puts it:

```bash
bash scripts/detect.sh --branch [--policy infer|current|new] [--name BRANCH]
```

`--policy` is the `branch:` token: `infer` (the default), `current`, or `new`.
Omit it to let `commit.branch` decide; `branch:infer` means exactly that and is
passed only to be explicit. `--name` is optional and answers one question early:
which base a PR from the branch you are about to name will target.

The detector is read-only, but not network-free: when the config names no base it
falls back to the remote HEAD, which may shell out to `gh`.

## Output — repo topology

| Key | Meaning |
|---|---|
| `note` | present only when the config is unusable, e.g. a bad `commit.branch`; it names the fallback taken |
| `topology` | `repo`, `workspace`, or `none` |
| `config` | the config file in force, or `none` |
| `configured` | `commit.branch` from the config (after validation), or `none` |
| `policy` | what actually applies: the token, else the config, else `new` |
| `checked-out` | printed only with `--head`, when you asked about a branch you are not on |
| `head` | the branch being decided for |
| `state` | `on-base`, `on-branch`, `detached`, or `no-git` |
| `action` | `create`, `reuse`, `commit-here`, `stop-and-ask`, or `refuse` |
| `start-point` | where a new branch is cut from — `<remote>/<head>`, or `none` |
| `unpublished` | commits on local `<head>` missing upstream, `0`, `unknown`, or `n/a` |
| `pr-base` | the base a PR from this run targets |
| `pr-base-source` | `config`, `probed` (confirm it with the user), or `unknown` |
| `pr-base-final` | `yes` when `--name` resolved it for the real branch name, else `no` |

A base branch is **any `base_map` value**, plus the `repos` rung, plus the remote
default. That is why `staging` counts as a base in a repo whose `base_map` routes
`"*"` to it: the remote default alone is not the base, it is only one of them.

## Token authorship

Pass `--policy` only when the **caller** asked for it — the user typed
`branch:new`, or the run's own gate summary already recorded the decision.

Never pass a token that is merely this skill's own default. Doing that launders
a default into "explicit token", which outranks the project's config and makes
`commit.branch` unreachable. Omitting `--policy` is how a skill defers to
config. This applies to every token these skills forward, not just `branch`.

## Act on `action`

### `create`

1. Run `git fetch <remote> <head>` **before** trusting the detector: a stale
   upstream ref reads as "unpublished commits" and produces a false stop.
2. `unpublished` must be `0` and `start-point` must not be `none`. Anything else
   is a stop: cutting from local HEAD would carry commits stranded on the base
   into the new branch, and cutting from a missing upstream ref silently does
   exactly that. Name the count, the branch, and the choice.
3. Name it `<type>/<slug>` from the plan filename or the topic, deterministically,
   so a retried run converges on the same name instead of forking `-2`.
4. Re-run with `--name <name>` and take `pr-base` from that answer: a name like
   `release/1.2` or `hotfix/x` matches a `base_map` family and retargets the PR,
   and it also changes which `hooks.pr` pattern applies — a plan slug containing
   "release" is not a neutral name.
5. If the name already exists: reuse it when it descends from `start-point`;
   stop and ask when it has diverged.
6. `git checkout -b <name> <start-point>`. Uncommitted work comes along — say so
   in the gate summary if the tree was dirty.
7. Report the branch, the start point, and `pr-base`.

### `reuse`

Report `head` and carry on. Do **not** re-cut because `commit.branch` is `new`:
a second phase, a resumed run, or a handed-off session is already standing on
the branch the first one cut. That is the whole reason this is inferred rather
than forced.

### `commit-here`

Only reachable with `policy: current`, which is an explicit statement that
committing on the base branch is intended. Proceed, and say in the run's gate
summary that the commits are landing on `<head>`. When the config says
`commit.branch: current`, the close-out commits and pushes `<head>` to its upstream with **no PR** — no
`sassy-commit-push-pr`, no `hooks.pr.*`, no babysit, no merge. `pr-base` is
irrelevant here. Never infer this from a skill default.

### `stop-and-ask`

The base has commits that never reached the remote. Present the choice — publish
them, move them to the new branch, or drop them — and take the answer. Never
resolve it by cutting anyway.

### `refuse`

Detached HEAD without a policy that permits it, `topology: none`, `git.repo:
none`, or no upstream ref to cut from. Report the `reason` line and stop; there
is no branch to commit to.

## Workspace

Resolve once at the workspace root; the run uses **one branch name across every
nested repo**. The detector prints one line per repo:

```
repo fe: head=staging state=on-base base=staging start-point=origin/staging unpublished=0 action=create
drift fe: commit.branch=current
```

`base` is that repo's own `base_map["*"]` when it carries a config, else its
`repos[<dir>]` rung. Apply `action` per repo — cut where it is `create`, keep the
rest — and stop if any repo reports `stop-and-ask` or `refuse`. A nested repo
carrying its own `commit.branch` that disagrees is printed as `drift` — a config
bug to report, not a per-repo override, because one run cannot follow two
policies.

## After the branch exists

With the token alone, this is a commit only; the push-and-no-PR close-out comes
from the config. Downstream steps forward `branch:current` to `sassy-commit`,
because the decision has already been made and the commits belong on that branch. `sassy-ship` never
creates the branch — by the time it runs, the branch carries the work. If it ever
finds the run's head on a base branch with unpublished commits, that is a
mis-run: stop and ask, never relocate commits silently. The exception is a
config with `commit.branch: current`, where unpublished commits on the head are
simply pushed along. Only that config skips the PR. A typed `branch:current`
token, and the `branch:current` forwarded to `sassy-commit`, do not.

Report the branch and its start point in every gate summary. A decision the user
cannot see is a decision they cannot correct.
