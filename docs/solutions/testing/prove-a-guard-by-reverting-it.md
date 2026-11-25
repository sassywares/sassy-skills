---
title: Prove a guard by reverting it — a test is only worth its fixture if the fixture fails without the line
category: testing
tags: [testing, fixtures, mutation, regression, shell]
created: 2026-11-25
---

## Context

A shell probe gained four small guards: strip comments only outside strings,
track escapes, count braces without closing on a `}` inside a value, and drain
the input instead of exiting early upstream of a pipe. Each came with a fixture
that exercised the case, and every fixture passed on the first run.

Passing on the first run is the problem. A new fixture and the code it covers
are written by the same author in the same sitting, and a fixture that passes
for the wrong reason looks identical to one that passes for the right reason.
Worse: the bug being fixed was *already* invisible to the existing suite, so
"the suite is green" carried no information about whether the fix worked.

## Guidance

**Mutation is the proof.** For each guard, revert exactly that one line, run the
suite, and confirm the specific fixture fails — then restore it and confirm the
file is byte-identical (`sha256sum` before and after, not a read-through).

- **Name the failing fixture before you revert.** "The suite goes red" is
  enough for a one-guard change and not enough for four: a revert that trips an
  unrelated assertion proves nothing about this guard. Predict the case, then
  check the case that failed.
- **One line at a time.** Reverting two guards together shows that at least one
  of them matters. Only singly-reverted guards show that each one is load-bearing.
- **Restore must be exact.** An editor's reformat during restore quietly adds
  an untested change. Compare the hash, or `git diff --stat`; never rely on
  having retyped it correctly.
- **The fixture must be bigger than the failure's threshold.** The pipeline
  guard only fires past the pipe buffer, so its fixture needed hundreds of KB of
  padding and would have passed at 40 lines. Ask what property makes the bug
  appear — size, ordering, escaping, a second entry after the bad one — and
  build the fixture past that property, not near it.
- **A fixture that pairs a broken case with a working neighbour is worth two.**
  The comment fixture asserted both that the commented-out `dev` is absent
  *and* that the real `down`/`test` beside it still answer, so a scanner that
  simply skipped the whole block could not pass by deleting too much.

This is cheap: a revert, one test run, a restore, a hash. It is the difference
between a suite that demonstrates a fix and one that merely coexists with it.

## Applicability

Any guard whose only evidence is a test that passes — parsers, scanners, state
machines, anything with a threshold or an ordering dependency. It matters most
when the change is a bug fix the existing suite already missed, and least when
the fixture existed before the fix and was observed red.

It does not apply to tests that are true by construction (a constant compared to
itself) or to fixed-output golden files whose source is regenerated from the
code under test — there is nothing to revert that the fixture would notice.
