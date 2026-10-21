# Workspace install

Read this only when the topology is `workspace`. Everything the snapshot owns
lives under one directory:

```text
.sassywares/
├── config.yaml
└── workspace/
    ├── snapshot    the script (tracked)
    ├── .gitignore  exclude patterns for the sync (tracked)
    └── mirror/     the side clone (untracked, self-excluded)
```

- Copy `assets/snapshot` to `.sassywares/workspace/snapshot` and make it
  executable. **If a `snapshot` file is already there, say so and ask** — it may
  carry hand edits. Report the version you installed (`snapshot --version`) so a
  later `--check` can catch a stale copy.
- Write `.sassywares/workspace/.gitignore` for excluded paths (vendored trees,
  generated dirs, `.run/`). One pattern per line, `.gitignore` style. Skip it when
  there is nothing to exclude; the sync works without it. The mirror needs no
  line — the script excludes it itself.
- Do **not** add a `.gitignore` at the project root, and do not modify one that
  exists.
- Do **not** run the snapshot during setup. It clones and pushes; that is the
  user's call. Offer `--dry-run` and run it only if they ask.

The mirror remote comes from `git.remote`; the script falls back to the mirror's
own `origin` once it exists. Never create the GitHub repository without the
explicit approval described in the skill.
