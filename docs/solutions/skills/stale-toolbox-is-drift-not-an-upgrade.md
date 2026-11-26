---
title: An installed toolbox older than the shipped one is drift — a version short-circuit makes the checker unable to name what it lacks
category: skills
tags: [worktree, toolbox, drift, version-header, detect, check, short-circuit]
created: 2026-02-14
---

## Problem

A project carried a v8 `.sassywares/worktree/` toolbox (the git-mechanics scripts
`sassy-setup` installs) under `create`/`remove` wrappers scaffolded against v13.
Its `remove` calls `list --env <slug|branch>`; the v8 `list` answers
`unknown flag: --env` and exits 2, so removal aborted before removing anything.

`detect.sh --check` reported the mismatch as *"worktree tooling is vN; this skill
ships vM — an upgrade, not drift"*, printed it as a note, and exited 0. A second
`--check` after re-scaffolding still passed. The one check that should have warned
was the one that said everything was fine.

The fix's first draft was also internally impossible: the note told the user to
"re-run setup, then delete `.sassywares/worktree/prune`", but setup already
removes `prune`, so the instruction could not be executed in the order given.

## Root cause

`skills/sassy-setup/scripts/worktree-check.mjs` short-circuited on
`installedVersion < shippedVersion` with `note(...)` + `process.exit(0)` *before*
the folder hash and the per-file walk. Only a set **newer** than the shipped one
fell through to hashing, so the checker could never name a single file a stale set
lacked — it stopped at the one fact it had already decided was benign.

The two facts it conflated: an older set is *broken by construction* (the
project's wrappers were written against the shipped contract and call flags the
older one never had), while a newer set merely *isn't the shipped set* (it works).
Treating both as "an upgrade" made the older case a shrug.

## Solution

The short-circuit is gone. A lower header sets a `stale` flag and the existing
hash + per-file walk run as for any other drift, so verdict and evidence land in
one report:

```js
const stale =
  installedVersion !== null &&
  shippedVersion !== null &&
  installedVersion < shippedVersion;
// …
if (stale) {
  drift("worktree setup is stale — it goes off mid-run, not here; re-run setup");
}
```

The walk then names the files: bytes that differ read
`… differs from the shipped copy — re-run setup`, and a file the skill no longer
ships reads `prune is retired and its helpers went with it — it cannot run;
re-run setup` (a command, not untidy leftovers). The flag is **one-directional**:
a set ahead of the shipped one is still drift but never borrows the stale wording,
because claiming it "goes off mid-run" would be the same confident lie as the old
note. Versions stopped appearing in user-facing output — the comparison still uses
them, the message does not, so the note can no longer be wrong about which version
was installed.

## Prevention

`tests/worktree-check.sh` (bash 3.2, offline, `mktemp` fixtures) builds a stale
set by editing a copy's header **down**, never by rolling a project back. Its
load-bearing assertion is the pair, not either half: a stale fixture must produce
**both** the stale verdict **and** the names of the differing files in one run —
restoring the old exit-before-hashing fails 6 assertions. It also pins that a
newer set is drift but never called stale, that a matching set claims the hash
match and nothing else, and end to end that `detect.sh --check` exits non-zero on
a stale set and never prints `config matches the tree`.

**Also rejected, worth recording.** The original plan was for `detect.sh` to
compare each project wrapper's `# sassywares:scaffold … version=<v>` against the
installed toolbox header. That is unimplementable in that direction: the scaffold
header's `version=` is the suite **release** (`0.13.1`) while the toolbox header
is an integer **contract** version (`# worktree-version: 13`), so comparing them
needs a release→contract mapping table — exactly the hardcoded guesswork that
produced the wrong note. With the short-circuit fixed the extra check was
redundant: the stale set reports itself.
