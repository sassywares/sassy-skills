# Branching

One branch decision per run, made **before** the first change. `sassy-work`,
`sassy-lfg`, and `sassy-debug` all resolve it here, through one detector, so the
three cannot drift apart the way three hand-copied paragraphs would.

## Resolve

```bash
bash .agents/skills/sassy-setup/scripts/detect.sh --branch [--policy current|new]
```

`--policy` is the `branch:` token: `infer` (the default), `current`, or `new`.
Omit it to let `commit.branch` decide; `branch:infer` means exactly that and is
passed only to be explicit.

Output:

| Key | Meaning |
|---|---|
| `topology` | `repo`, `workspace`, or `none` |
| `configured` | `commit.branch` from the config, or `none` |
| `policy` | what actually applies: the token, else the config, else `new` |
| `head` | the checked-out branch, or `none` when detached |
| `state` | `on-base`, `on-branch`, `detached`, or `no-git` |
| `action` | `create`, `reuse`, `commit-here`, or `refuse` |
| `start-point` | where a new branch is cut from — `origin/<head>`, never local `HEAD` |
| `unpublished` | commits on local `<head>` that are not on `origin/<head>` |
| `pr-base` | the base a PR from this run targets |
| `pr-base-source` | `config`, `probed`, or `unknown` — a probed base is confirmed with the user before use |

A base branch is **any `base_map` value**, plus the remote default. That is why
`staging` counts as a base in a repo whose `base_map` routes `"*"` to it: the
remote default alone is not the base, it is only one of them.

## Token authorship

Pass `--policy` only when the **caller** asked for it — the user typed
`branch:new`, or an earlier gate of this same run authorized it.

Never pass a token that is merely this skill's own default. Doing that launders
a default into "explicit token", which outranks the project's config and makes
`commit.branch` unreachable. Omitting `--policy` is how a skill defers to
config. This applies to every token these skills forward, not just `branch`.

## Act on `action`

### `create`

1. `unpublished` must be `0`. If not, **stop and ask**: cutting from local HEAD
   would carry commits stranded on the base into the new branch, and cutting
   from `origin/<head>` would abandon them. Name the count, the branch, and the
   choice.
2. Name it `<type>/<slug>` from the plan filename or the topic, deterministically,
   so a retried run converges on the same name instead of forking `-2`.
3. If that name already exists: reuse it when it descends from `start-point`;
   stop and ask when it has diverged.
4. `git fetch <remote> <head>`, then `git checkout -b <name> <start-point>`.
5. Report the branch, the start point, and `pr-base`.

### `reuse`

Report `head` and carry on. Do **not** re-cut because `commit.branch` is `new`:
a second phase, a resumed run, or a handed-off session is already standing on
the branch the first one cut. That is the whole reason this is inferred rather
than forced.

### `commit-here`

Only reachable with `policy: current`, which is an explicit statement that
committing on the base branch is intended. Proceed, and say in the run's gate
summary that the commits are landing on `<head>` and that `pr-base` is
`<pr-base>`. Never infer this from a skill default.

### `refuse`

Detached HEAD with `policy: current`, or `topology: none`. Report and stop;
there is no branch to commit to.

## Workspace

Resolve once at the workspace root; the run uses **one branch name across every
nested repo**. The detector prints each repo's head and state, so cut inside the
repos whose state is `on-base` and reuse the rest. A nested repo carrying its own
`commit.branch` that disagrees is printed as `drift` — that is a config bug to
report, not a per-repo override, because one run cannot follow two policies.

## After the branch exists

Downstream steps forward `branch:current` to `sassy-commit`, because the decision
has already been made and the commits belong on that branch. `sassy-ship` never
creates the branch — by the time it runs, the branch carries the work. If it ever
finds the run's head on a base branch with unpublished commits, that is a
mis-run: stop and ask, never relocate commits silently.

Report the branch and its start point in every gate summary. A decision the user
cannot see is a decision they cannot correct.
