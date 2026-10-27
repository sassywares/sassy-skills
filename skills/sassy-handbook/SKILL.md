---
name: sassy-handbook
description: >-
  Write a plain-English, self-contained developer handbook for handing a new
  feature off to the team, stored in the project's handbooks folder. Hyperfocused, key
  information only, with mermaid diagrams. Use when asked for a handbook,
  handover notes, a team reference, or to turn a plan into a readable guide.
argument-hint: "[plan path, topic, or brief context]"
disable-model-invocation: true
---

# Sassy Handbook

**Outcome:** one team-readable handbook under the configured handbooks path that any teammate can follow without knowing which agent, skill, or setup produced the work.

**Not this skill:** durable gotcha learnings (`sassy-compound`), implementation plans, or shipping code.

**Config.** Resolve `.sassywares/config.yaml` (nearest, walking up) per the `sassy-setup` skill's `references/config.md`. Handbooks land in `artifacts.handbooks`.

**Harness.** Loading another skill, dispatching an agent, and any command you hand the user follow the `sassy-setup` skill's `references/harness.md`. Read it once per run, before the first of those.

## When to run

- After a plan or multi-phase change needs a **human handover** (what landed, what is left, how to extend it).
- When the user asks for a **handbook**, **handover**, or **team reference**.

## Hard rules

| Rule | Requirement |
|------|-------------|
| Audience | Humans on the team — not agents, not one person's toolchain. |
| No toolchain names | Never name skills, slash-commands, agents, or "run X then Y" recipes. Say what to check in the app or in code. |
| Hyperfocused | Only the key information. Link deep docs instead of restating them. A teammate should skim it in a few minutes. |
| No fake completion | Distinguish **done**, **in progress**, and **still to do**. Never write as if unfinished work shipped. |
| Grounded | Paths, types, and behaviors match the tree you can read now. Soften or drop claims you cannot verify. |
| One per topic | Update an existing handbook rather than spawning near-duplicates. |
| Write boundary | Only the configured handbooks path (create it if missing). Do not rewrite the source plan. |

## Location

```text
<artifacts.handbooks>/<kebab-topic>-handbook.md
```

No dates in the filename. Keep the existing filename when updating an existing handbook.

## Workflow

1. **Gather.** The plan or brief the user named, plus a light tree check of the paths and types the handbook will claim. Open the real files; do not invent. Delegate heavy reading to `sassy-scout` if the change is large.
2. **Create or update.** No handbook for this topic → create `<topic>-handbook.md`. Existing and stale → update in place and refresh **As of**. User pointed at a path → edit that file.
3. **Write the handbook.** Read `references/handbook-format.md` now and write it in that shape, with mermaid diagrams where they clarify.
4. **Voice scrub.** Follow the voice rules in that reference: remove skill names, phase IDs, gate tables, and jargon piles.
5. **Ground and report.** Confirm cited paths exist (or mark them planned), confirm statuses match reality, and report the absolute path, create vs update, and anything unverified.
