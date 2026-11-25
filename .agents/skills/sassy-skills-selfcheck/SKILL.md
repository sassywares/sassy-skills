---
name: sassy-skills-selfcheck
description: Keep this repo's own .sassywares/config.yaml current with the sassy-setup template, then push the result. Runs as a sassy-ship hooks.push after_push entry. Internal Sassywares tooling.
metadata:
  internal: true
---

# sassy-skills-selfcheck

This repo is the suite's source of truth, so its own config must show every
block, comment, and example the suite documents. A push passes through here and
closes any gap before the release hook sees it.

**Hard rule: never rewrite a config value the check accepts.** The sync only adds
what the file lacks; a value — and its same-line trailing comment — that
`--check` accepts stays byte for byte. `commit.branch: current` and any
`"*": main  # confirmed: …` line are the project's decisions, not drift.

**Hard rule: `--sync` is for the template note only.** A `drift:` line is a key
or value the check cannot accept — the project's decision, or a schema the suite
changed, and not something a template merge may paper over. When `--check`
reports genuine drift, stop and report it; never run `--sync --write` over it,
with or without a template note in the same output.

## Steps

1. Run `bash skills/sassy-setup/scripts/detect.sh --root . --check` from the repo
   root. If the output has any `drift:` line, relay each one verbatim and stop —
   real drift is not this skill's to fix, and `--sync` must not run over it.
2. Only with no `drift:` line: if the output carries a `template:` note, run
   `bash skills/sassy-setup/scripts/detect.sh --root . --sync --write`, then
   re-run the check and confirm the note is gone and the check is clean. A note
   that survives the sync, or a new `drift:` line, is a failure: report both
   outputs and stop without committing.
3. Commit only the paths the sync changed — `git status --porcelain` before and
   after, or `git diff --name-only`. Use `git commit -- <paths>`, never
   `git add -A`. Subject: `chore: sync config template`. If anything else is
   dirty, do not stage or commit it: report the paths and stop.
4. Push `main` to `origin/main` without force. A non-fast-forward rejection is
   stop-and-report; never force, never rebase onto a rewritten remote.
5. Report the version-and-config outcome: whether the config changed and which
   blocks were added, the commit and push result, and whether `bin/release` would
   see a consumer-facing change. It should not: `.sassywares/` is in
   `bin/release-ignore`, so a config-only commit bumps nothing. Say so, and say
   the opposite loudly if the diff touched anything outside `.sassywares/`.
