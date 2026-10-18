---
name: sassy-compound
description: >-
  Document a solved problem as a durable repo learning. Use after a bug is fixed,
  a problem is solved, or a fresh finding is made. Writes the learning, and also
  maintains CONCEPTS.md and a pointer in AGENTS.md when useful. Lean on purpose.
argument-hint: "[optional context] [mode:review|pipeline]"
disable-model-invocation: true
---

# Sassy Compound

**Outcome:** one durable learning written for a solved problem, `CONCEPTS.md` updated if new terms were learned, and `AGENTS.md` pointed at the knowledge store when that pointer is missing and useful.

**Modes.** `mode:review` (default) asks before the `AGENTS.md` pointer edit. `mode:pipeline` is non-interactive: it applies that edit silently.

## When it qualifies — the durable bar

A learning earns a doc only when it holds reasoning that is **not recoverable** from the final code, tests, types, comments, or existing docs, and losing it would plausibly cause a repeat mistake or substantial rediscovery.

Apply the counterfactual: *if this learning disappeared, would a future engineer reading the final implementation still likely repeat the mistake or redo the investigation?* If no, write nothing and say why. Completion, effort, and diff size do not qualify a learning.

## One learning per run

If several problems were solved, run once per learning. Never batch them into one doc.

## Where things go (repo root)

| Artifact | Path |
|----------|------|
| Learning | `docs/solutions/<category>/<slug>.md` |
| Vocabulary | `CONCEPTS.md` |
| Discoverability pointer | `AGENTS.md` (edit only; never create) |

## Workflow

1. **Identify the learning.** Extract the problem and the verified solution from the conversation. Ground every behavior claim against the code (read the defining line) or soften/attribute it. Redact secrets.
2. **Classify.** Bug track (a defect fixed) or knowledge track (a durable insight or pattern). Pick a `category` and a descriptive `slug`. If the exact path exists and covers the same problem, update it (refresh `updated:`); otherwise create it.
3. **Write the doc.** Read `references/templates.md` now and use the matching template.
4. **Concepts.** If the learning surfaced a term a new engineer would need defined, read `references/concepts.md` now and follow its rules to add or refine it in `CONCEPTS.md`. Create the file if absent. Skip cleanly when nothing qualifies.
5. **AGENTS.md pointer.** If a project instruction file exists (`AGENTS.md` or `CLAUDE.md`) and does not already mention `docs/solutions/` or `CONCEPTS.md`, add one short line pointing to them. Edit only; never create the file. In `mode:pipeline`, do it silently; in `mode:review` (default), ask.
6. **Report.** Path, create vs update, concepts touched, and whether an AGENTS.md pointer was added.

## Hard rules

| Rule | Requirement |
|------|-------------|
| Solved and verified only | Never document an unsolved or unverified problem. |
| One learning per run | Sequential runs, never a batch. |
| Grounded | Every claim checked against the tree, or softened. |
| Write boundary | Only `docs/solutions/`, `CONCEPTS.md`, and a one-line `AGENTS.md` edit. Never touch code. |
