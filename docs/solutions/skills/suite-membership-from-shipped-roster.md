---
title: Identify suite skills from a roster the suite ships, never from names or neighbouring folders
category: skills
tags: [sassy-setup, roster, detect, lockcheck, project-skills]
created: 2026-11-11
---

## Context

`sassy-setup` has to decide whether a skill is one of the suite's own
("is this a suite skill?") to classify drift, pins, and hook targets. Two
heuristics were tried and both failed.

## Guidance

Identify a suite's members from data the suite ships, never from names or
install-location neighbours.

- **Name prefix (`sassy-`)** wrongly flagged legitimately named project skills.
  Example: a repo named `sassy-code` with the project skill
  `sassy-code-release`, used as a `hooks.push` hook, produced the drift "is one
  of our skills" and a false pin drift.
- **Scanning sassy-setup's sibling folders** was worse. In project scope the
  siblings are the project's own `.agents/skills`, so every project skill became
  "suite" and every project hook failed `--check`. In global real-copy installs,
  foreign global skills joined the suite.
- **Fix:** ship the roster with the suite at `skills/sassy-setup/assets/roster`
  and read it from the running sassy-setup's own directory. `detect.sh` and
  `lockcheck.mjs` share one suite predicate. Only when the roster file is
  missing do they fall back to the prefix, and they say so in a note.
- **Keeping it current:** AGENTS.md steps for adding a skill, a `publish.yml`
  check comparing `ls skills` to the roster, and `tests/sassy-setup-roster.sh`
  covering the project, user, npm, and fallback install shapes.

## Applicability

Applies to any tool that must tell "ours" from "theirs" across install
locations (project, user, npm, real-copy). It does not apply when membership is
genuinely defined by location alone; even then, prefer a shipped list over
inferring from folder contents, since the folder is not under the suite's
control.
