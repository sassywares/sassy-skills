---
name: sassy-skill
description: >-
  Create, retune, or improve an Agent Skill for pi. Use when asked to create a
  skill, turn a workflow into a skill, fix a skill's description or triggering,
  restructure a bloated skill, or retune an existing one. Writes to the user or
  project skill directory and follows pi's Agent Skills rules.
argument-hint: "[create|retune] [name, idea, or skill path]"
disable-model-invocation: true
---

# Sassy Skill

**Outcome:** a well-formed Agent Skill directory installed at the user or project location, or an existing skill improved and re-verified. Pi's loader accepts it with no diagnostics.

**Scope:** skills only — not extensions, packages, or prompt templates.

## pi's rules (the essentials)

- A skill is a **directory containing `SKILL.md`**. Discovered recursively.
- **Name:** lowercase letters, numbers, hyphens; no leading/trailing/consecutive hyphens; ≤64 chars. Match the directory name.
- **Description:** required, ≤1024 chars. Pi advertises name + description at startup; the body loads only when the skill is used. The description decides whether the skill ever fires — write **what it does and when to use it**.
- **Frontmatter fields:** `name`, `description` (required); optional `license`, `compatibility`, `metadata`, `allowed-tools`, `disable-model-invocation`.
- Use `disable-model-invocation: true` for skills that should run only via explicit `/skill:name`.
- **Locations:** user `~/.agents/skills/<name>/`; project `<repo>/.agents/skills/<name>/` (discovered from cwd up to the repo root). Also the `skills` array in settings and pi packages.
- Pi **validates at startup**; malformed or descriptionless skills warn. `/reload` applies changes.
- Pi implements the **Agent Skills specification** (agentskills.io). For the full spec, pi's own `docs/skills.md` is authoritative — read it when the rules here are not enough.

## Shape rule — the lean rule

- **Default to one `SKILL.md`.**
- Add `references/` **only** for content that is **conditionally read** (or genuinely bulky and only sometimes needed). A reference that is read on *every* run saves nothing and may cost a little.
- Keep `SKILL.md` an index: outcome → hard rules → workflow → explicit pointers ("read `references/x.md` before doing Y").
- Never bury conditional detail in a monolithic `SKILL.md`.

## Workflow

1. **Intake.** What the skill does, when it should trigger, and whether it is **user-level** or **project-level**. For a retune, read the existing skill and name the specific failure (won't trigger, too long, wrong steps, stale).
2. **Choose the shape.** Single file, or `SKILL.md` + `references/` per the rule above.
3. **Write the frontmatter.** A description that states both what and when.
4. **Write the body.** Outcome, a hard-rules table, the workflow, and reference pointers. Plain English. Structured output where the skill returns a result. Match this setup's house style.
5. **Self-check** against the checklist below.
6. **Install and verify.** Place it at the right path, run `/reload`, confirm no startup diagnostics, and test `/skill:<name>`.

## Self-check checklist

- [ ] `name`: lowercase/hyphens, ≤64, matches the directory.
- [ ] `description`: states what **and** when, ≤1024, not vague.
- [ ] Frontmatter is valid YAML with the required fields.
- [ ] Every `references/…` path exists and is pointed to explicitly in the body.
- [ ] The body is lean; no always-read detail needlessly hidden in a reference.
- [ ] No secrets, and no capability the skill cannot actually use.

## Retune

When asked to retune or improve a skill, change the **smallest** thing that fixes the named failure:

- **Won't trigger** → rewrite the description (what + when, concrete verbs).
- **Too long / bloated** → extract conditional content to `references/`, or delete what never gets used.
- **Wrong or stale steps** → correct the workflow against the current tree.
- **Wrong scope** → move it between user and project locations.

Re-verify after any retune.

## Verify

- `/reload`.
- Check pi's startup output for warnings about the skill.
- Run `/skill:<name>` and confirm it loads and behaves.
