---
name: sassy-skills-release
description: Release this repo with its vendored release script. Use when asked to release, cut a release, tag a version, or bump and publish, and when invoked as a sassy-ship hooks.push after_push hook. Internal Sassywares tooling.
metadata:
  internal: true
---

# sassy-skills-release

Runs the repo's vendored release script and reports the result. The script
decides everything (bump, commit, push, tag); this skill never improvises a
release by hand.

## Steps

1. From the repo root, check `bin/release` exists and is executable. If it is missing, that is a
   FAILURE, not a skip: report it as failed with a non-zero status ("`bin/release` is not
   vendored; copy `release.sh` from https://github.com/sassywares/sassy-release to `bin/release` and `chmod +x` it")
   so a calling hook fails closed. Do not write a substitute.
2. Run `bin/release` from the repo root.
3. Exit 0 is success, including "nothing to release". Report: the version and tag
   (`released vX.Y.Z`), or "nothing to release", or "pushed <branch>, release happens on
   main", plus the exit status. Any other exit fails the hook: relay the script's message
   verbatim and stop; never retry with force, never create or push tags yourself.

The script is idempotent, so it is safe to re-run after a failure (for example a failed tag
push is finished by the rerun). It takes tag state from origin, refuses a dirty tree (the
work commit must already exist), tags only on `main`, bumps only the patch version of a
plain `X.Y.Z` (a prerelease like `1.0.0-beta.1` is tagged as-is, never auto-bumped), and
never force-pushes. Minor and major bumps are hand-written in `package.json` / `VERSION`;
the script then tags them. `package.json` needs node.

`bin/release-ignore` lists non-consumer paths: root-anchored path prefixes and bash
globs (`*` may cross `/`), `#` comments; `!` and `**` lines are errors. A custom file
REPLACES the defaults (`AGENTS.md docs/ tests/ .sassywares/ .github/ .agents/ .claude/
scripts/ bin/release bin/release-ignore`), so re-list the ones you still want ignored.

## Refreshing the vendored copy

The first lines of the script read `# sassy-release vN`. Compare that N with the latest
tag (or `main`) of https://github.com/sassywares/sassy-release. If the source's N is
higher, tell the user and, when asked, replace `bin/release` with the source's
`release.sh` (keep it executable) and refresh this `SKILL.md` from `skill/SKILL.md`,
keeping the project name. Never compare against the source or refresh during a hook run
(no network refresh); this is a separate, user-requested action.
