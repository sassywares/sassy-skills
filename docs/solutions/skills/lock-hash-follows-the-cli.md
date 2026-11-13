---
title: A lock hash belongs to whoever writes the lock — follow the CLI, never restate it
category: skills
tags: [sassy-setup, lockcheck, skills-lock, skills-cli, hashing, drift]
created: 2026-05-22
---

## Context

`sassy-setup`'s `--check` verifies a project's vendored suite against
`skills-lock.json` offline. It hashed each skill folder with its own reading of
the `skills` CLI's definition. The CLI then changed that definition, and every
suite skill in a freshly installed project reported drift at once:

```
drift: sassy-babysit does not match the pin — edited locally or half-installed
drift: sassy-commit does not match the pin — ...
(21 of them, in tap2-workspace)
```

The folder contents were byte-identical to a fresh `npx skills add`. Only the
hash was wrong, and a false "re-install" instruction is worse than a missed
check: it invites an agent to overwrite a healthy project.

## Guidance

A lock hash is the lock writer's contract. Transcribe it, version it, and pin it
with vectors — do not restate it from memory.

- **Two formats are live.** The CLI versioned its lock, and both eras still
  exist on disk:
  - lock `version: 1` (CLI ≤ 1.7.x) — sha256 over `path` then bytes, files
    sorted by `localeCompare`, only `.git`/`node_modules` skipped.
  - lock `version: 2` (CLI ≥ 1.8.x) — sha256 over `path`, `"\0"`, byte length,
    `"\0"`, bytes; files sorted by `Buffer.compare` (byte order, so `Z.md`
    before `a.md`); CRLF normalized to LF; `metadata.json`, `.git`,
    `__pycache__`, `__pypackages__` excluded; symlinks followed only inside the
    skill folder.
- **Try the version's format first, the other second.** Trying both cannot hide
  an edit — edited bytes match neither hash — it only stops a sound pin of
  either era from reading as drift. A v2-era CLI still reads v1 locks and
  migrates them on the next install, so v1 locks are not legacy debris.
- **Keep the oracle.** `skills/${skill}/scripts/hash-skill.mjs` is the single
  definition; `tests/hash-lock.mjs` and the tests build locks from it, and
  `tests/sassy-setup-roster.sh` holds golden vectors captured from the CLI
  (current) and from the v1 collects (legacy). A test that recomputes the hash
  privately proves nothing.
- **Verify against the real thing.** `node -e` importing the CLI's
  `computeSkillFolderHash` from `node_modules/skills/dist` over every real skill
  folder is the cheapest confirmation that a transcription is still exact.

## Trap found on the way

The refactor first kept the hash in the CLI script behind a
`import.meta.url === pathToFileURL(process.argv[1])` guard. On macOS the
script's module URL is the realpath (`/private/tmp/...`) while `argv[1]` is the
logical path (`/tmp/...`), so the guard was false, the script printed nothing,
and `--check` reported a clean pin **without hashing anything at all** — a
silent pass. Two rules came out of it: importing a module must never be how you
run a CLI (put the shared code in its own module), and a check that can print
nothing must be asserted to print its verdict — the test now requires the
"match ... byte for byte" note, not merely the absence of `drift:`.

## Applicability

Any tool that verifies a foreign tool's hash, cache key, or lock fingerprint.
It does not apply when the format is yours alone — then just version it.
