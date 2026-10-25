---
name: sassy-skill
description: >-
  Create, retune, or improve an Agent Skill. Asks where the skill should live —
  inside this suite, in a project, or for one user — then writes it there with
  the rules and release steps that location requires. Use when asked to create a
  skill, turn a workflow into a skill, fix a description or triggering,
  restructure a bloated skill, or retune an existing one.
argument-hint: "[mode:create|retune|verify] [name, idea, or skill path]"
disable-model-invocation: true
---

# Sassy Skill

**Outcome:** a well-formed Agent Skill at a location the user chose, or an existing skill improved and re-verified. The harness loads it with no diagnostics.

**Modes.** `mode:create` writes a new skill. `mode:retune` changes the smallest thing that fixes a named failure in an existing skill. `mode:verify` checks an existing skill against the checklist and reports — it edits nothing. Omitted, detect it from the argument: something that already resolves to a skill directory is `retune`, or `verify` when the user only asked whether it is any good; anything else is `create`. State the mode you picked and why; when both are plausible, ask instead of guessing.

**Locations are not interchangeable** — they decide who gets the skill, how it ships, and what it may be called. Ask before writing.

**Scope:** skills only — not extensions, packages, or prompt templates.

## pi's rules (the essentials)

- A skill is a **directory containing `SKILL.md`**. Discovered recursively.
- **Name:** lowercase letters, numbers, hyphens; no leading/trailing/consecutive hyphens; ≤64 chars. Match the directory name.
- **Description:** required, ≤1024 chars. Pi advertises name + description at startup; the body loads only when the skill is used. The description decides whether the skill ever fires — write **what it does and when to use it**.
- **Frontmatter fields:** `name`, `description` (required); optional `license`, `compatibility`, `metadata`, `allowed-tools`, `disable-model-invocation`.
- Use `disable-model-invocation: true` for skills that should run only via explicit `/skill:name`.
- **Reference other skills by name, never by absolute path.** The suite can live in `~/.agents/skills/`, a project `.agents/skills/`, or inside `node_modules/`, so "load the sassy-commit skill" is portable where a `~/…` path is not. Name a bundled file as "the sassy-setup skill's `references/config.md`".
- Pi **validates at startup**; malformed or descriptionless skills warn. `/reload` applies changes.
- Pi implements the **Agent Skills specification** (agentskills.io). For the full spec, pi's own `docs/skills.md` is authoritative — read it when the rules here are not enough.

## Where the skill lives

Ask which one, unless the request already made it obvious. The answer changes the name, the sharing, and whether a release is needed.

| Location | Path | Who gets it | Extra work |
|---|---|---|---|
| **Internal** — part of this suite | `skills/<name>/` in the sassy-skills repo | Everyone, once pushed to `main` | Name it `sassy-<name>`, run `scripts/sync.sh` — it bumps the patch version, tags, and publishes |
| **Project** — team workflow | `<repo>/.agents/skills/<name>/` | Everyone who clones that repo | Commit it; prefix the project (`tap2-…`) so it can't collide with a suite skill or a harness built-in |
| **User** — personal workflow | `~/.agents/skills/<name>/` | Only this person, every repo on this machine | None — but nothing gates it either; never put something a teammate needs here |

Recommend by audience: the team needs it → **project**; only the requester → **user**; it belongs to every project using this suite → **internal**.

Internal is the only one that ships to everyone. Never choose it silently: once it lands on `main`, every consumer gets it on their next `npx skills update`. Say that out loud when you do.

Paths in the table are the defaults. Harnesses also read `skills` arrays in settings and installed packages, so a skill may live elsewhere — write down where it actually went.

## Shape rule — split on outcomes, not on topics

- **One `SKILL.md` is the default, but it is a decision, not a reflex.** Length never decides the shape; the paths do.
- **Split whenever the skill branches into paths that end differently.** A mode, trigger, or branch that writes a different thing, forbids a different thing, or is never needed in the same run as its sibling gets its own `references/<path>.md` — **even at three paragraphs**. How small each path is does not matter: what matters is that a model running path A never reads path B's instructions next to A's. Divergent outcomes sharing one file bleed into each other, and the bleed looks like helpfulness until it has already written the wrong thing. Think ahead when you write it, not after the first misfire.
- **Never split a shared surface.** What every path needs — ids, board or table values, hard rules, API quirks, house style — stays in `SKILL.md`, or each path pays to load it and they drift apart. One reference per **outcome**, never one per **section**: `references/` holding five short topic files is the oversplit, and it makes routing vaguer, not sharper.
- **`SKILL.md` becomes routing.** State the dispatch explicitly — a table naming exactly one reference per path, plus "read that one only". That sentence is what prevents the bleed; a pointer buried in a paragraph does not.
- A reference that is read on *every* run saves nothing and may cost a little, so it belongs in the body.
- Keep `SKILL.md` an index: outcome → hard rules → workflow → explicit pointers ("read `references/x.md` before doing Y"). Never bury path-specific detail in a monolithic file.

## Workflow

1. **Intake.** Settle the mode (above), then what the skill does, when it should trigger, and **where it lives** — internal, project, or user (see above). Ask; do not infer from the cwd. In `mode:retune`, read the existing skill and name the specific failure (won't trigger, too long, wrong steps, stale, wrong scope). In `mode:verify`, read it, run the checklist and Verify, report, and stop without writing.
2. **Choose the shape — enumerate the outcome paths first.** List the ways a run can end (file / comment / move a state; plan / implement / ship; create / retune / verify). Every path that ends differently gets its own reference; what all paths share stays in the body. Then write the dispatch table that names exactly one reference per path. Splitting by outcome is cheap; a misfire because two outcomes shared a page is not.
3. **Write the frontmatter.** A description that states both what and when.
4. **Write the body.** Outcome, a hard-rules table, the workflow, and reference pointers. Plain English. Structured output where the skill returns a result. Match this setup's house style.
5. **Self-check** against the checklist below.
6. **Install and verify.** Place it at the right path, run `/reload`, confirm no startup diagnostics, and test `/skill:<name>`.

## Self-check checklist

- [ ] `name`: lowercase/hyphens, ≤64, matches the directory.
- [ ] `description`: states what **and** when, ≤1024, not vague.
- [ ] Frontmatter is valid YAML with the required fields.
- [ ] Every `references/…` path exists and is pointed to explicitly in the body.
- [ ] Each outcome path that ends differently has its own reference, and the body dispatches to exactly one of them per run.
- [ ] No reference exists merely because its content was a separate section — that is oversplitting, not shaping.
- [ ] The body is lean; no always-read detail needlessly hidden in a reference.
- [ ] No secrets, and no capability the skill cannot actually use.

## Retune

In `mode:retune`, change the **smallest** thing that fixes the named failure:

- **Won't trigger** → rewrite the description (what + when, concrete verbs).
- **Too long / bloated** → extract conditional content to `references/`, or delete what never gets used.
- **One path's rules bleed into another's** (a mode doing the neighbouring mode's job) → that is a shape bug, not a wording bug: split the divergent outcomes into `references/`, one file per path, and give the body a dispatch table that names exactly one file per mode.
- **Wrong or stale steps** → correct the workflow against the current tree.
- **Wrong scope** → move it between internal, project, and user. Moving into the suite is a release; moving out of it means the next release drops the skill for everyone.

Re-verify after any retune.

## Verify

Run this at the end of `create` and `retune`, and as the whole job in `mode:verify`.

- `/reload`.
- Check pi's startup output for warnings about the skill.
- Run `/skill:<name>` and confirm it loads and behaves.
