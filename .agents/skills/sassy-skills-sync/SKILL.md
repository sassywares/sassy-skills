---
name: sassy-skills-sync
description: Refresh the projects that vendor this suite themselves — mirror the roster's skills, repin them, commit, and push — then report each consumer's setup verdict. Runs as a sassy-ship hooks.push after_push entry. Internal Sassywares tooling.
metadata:
  internal: true
---

# sassy-skills-sync

A project that installs the suite per project keeps its own copy in
`.agents/skills/` and a pin in `skills-lock.json`; it does not get the
maintainer's `~/.agents/skills` link, so a push here reaches it only through this
run. `.sassywares/consumers` is the record of who vendors, one `<path> <branch>`
per line, and this skill refreshes exactly those. The pin is rewritten by
`scripts/lock.mjs`, which reuses `skills/sassy-setup/scripts/hash-skill.mjs` so a
repinned folder is one the CLI calls clean.

**Hard rules:**

- **Never force a push.** A push rejected twice is reported as blocked with its
  kept checkout path, and the run stops there; a single rejection is retried
  once from a freshly fetched base, never by forcing.
- **Never write into a consumer's `.sassywares/`.** Setup belongs to the project.
  The run reports a setup that is out of date and which project; it never fixes
  it.
- **Never touch a skill outside the roster.** Copy over the roster's entries,
  delete one the lock says we installed and the roster no longer names, and leave
  every other directory byte for byte.
- **Never invent a consumer.** Only `.sassywares/consumers` names them. A
  consumer that cannot be reached — missing path, not a repo, no config, no
  `origin/<branch>` — is reported as skipped with the reason, and the others
  still run.

## Steps

1. From the repo root, run
   `.agents/skills/sassy-skills-sync/scripts/sync --write`. It
   prints nothing to do when no commit since `.sassywares/last-synced-head`
   touched `skills/`; exit 0 is then the whole report.
2. Relay the table: consumer, branch, skills added/updated/deleted, commit, push
   result, and the setup alert (clean, or the named drift or template note).
3. Exit 0 is success, including skipped consumers and `already current`.
   Exit 1 is a **blocked** consumer — a push rejected twice kept its checkout at
   the path the table names. Report it as a failure so the close-out stops;
   never force.
4. Exit 2 is a malformed registry or repo — relay the message verbatim and stop.
