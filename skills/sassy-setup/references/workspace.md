# Workspace install

Read this only when the topology is `workspace`. Everything setup installs
lives under one directory:

```text
.sassywares/
├── config.yaml
└── workspace/
    ├── snapshot        sync + commit + push the glue (tracked)
    ├── branches        current branch per repo (tracked)
    ├── pull            fetch + fast-forward per repo (tracked)
    ├── checkout-bases  put each repo on its base (tracked)
    ├── _lib.sh         shared helpers; reads `repos:` (tracked)
    ├── .gitignore      exclude patterns for the sync (tracked)
    └── mirror/         the side clone (untracked, self-excluded)
```

## Install

- **Snapshot.** Copy `assets/snapshot` to `.sassywares/workspace/snapshot` and
  make it executable. **If a `snapshot` file is already there, say so and ask** —
  it may carry hand edits. Report the version you installed
  (`snapshot --version`) so a later `--check` can catch a stale copy.
- **Git helpers.** Copy every file in `assets/workspace/` flat into
  `.sassywares/workspace/` and make the three scripts executable. Report
  `_lib.sh`'s `workspace-git-version` (or `branches --version`) the same way.
  **Ask before overwriting any of them when they already exist** — from the first
  install on they are the project's files, and extending them is expected.
- **Excludes.** Write `.sassywares/workspace/.gitignore` for excluded paths
  (vendored trees, generated dirs, `.run/`). One pattern per line, `.gitignore`
  style. Skip it when there is nothing to exclude; the sync works without it. The
  mirror needs no line — the script excludes it itself.
- Do **not** add a `.gitignore` at the project root, and do not modify one that
  exists. A workspace's only ignore file is the one in `workspace/`.
- Do **not** run the snapshot during setup. It clones and pushes; that is the
  user's call. Offer `--dry-run` and run it only if they ask.

## What the git helpers are for

`branches`, `pull`, and `checkout-bases` do across the workspace's repos what the
same commands do in one repo, and they are a **human/CI convenience**. They read
the repo inventory and the PR bases from `repos:` in `config.yaml` — no second
base map, no probing, no inference: a repo missing from the map is reported as
unmapped, never guessed at.

- `branches` — current branch and dirty marker per repo, `(base: …)` when off base.
- `pull` — `fetch --prune`, then `pull --ff-only` when there is an upstream.
  Dirty trees are kept, divergent branches are reported, nothing is reset.
- `checkout-bases` — switch to each repo's base, creating it from the remote when
  it is missing locally. Refuses to clobber uncommitted work.

They are **not** part of the skill pipeline: skills resolve bases from the config
themselves and run their own git (`sassy-commit` cuts the branch, `sassy-babysit`
checks out the PR head). Never point a hook at these scripts. If a project wants
more — a status summary, a rebase flow — it extends its own copy; setup never
rewrites them without asking.

## The mirror

The mirror remote comes from `git.remote`. The script falls back to the mirror's
own `origin` once it exists. Never create the GitHub repository without the
explicit approval described in the skill.
