# Mode: create — write a new skill

Read the skill's shared sections first (locations, Agent Skills rules, shape rule, checklist). This file is the write side only.

## 1. Intake

Settle three things by asking, not inferring:

- **What it does** — the one outcome, stated as a result ("a merged PR", "a filed ticket", "a plan on disk"), not as an activity.
- **When it fires** — the words a user will actually say. These become the description's *when* half.
- **Where it lives** — internal, project, or user, per the location table. Ask; the cwd proves nothing.

If any of the three is missing, ask before writing a file. A skill authored on a guess is the one that gets retuned next week.

## 2. Choose the shape — enumerate the outcome paths first

List the ways a run can end (for example: file / comment / move a state; plan / implement / ship; create / retune / verify). Then apply the shape rule:

- A path that ends differently, forbids something different, or is never needed alongside its sibling → its own `references/<path>.md`, however short.
- What every path needs → the body.
- Then write the dispatch table in the body that names **exactly one** reference per path, and the sentence that says read only that one.

Two paragraphs of route-specific instruction are worth their own file; a shared field table is not worth splitting.

## 3. Frontmatter

`name` matches the directory. `description` states what and when, ≤1024 chars, in the user's vocabulary. Add `disable-model-invocation: true` when the skill should only run when the user invokes it, and an `argument-hint` when it takes one.

Do not put workflow detail in the description — it decides triggering, not execution.

## 4. Body

House shape, in this order:

1. **Outcome** — one sentence, a result.
2. **Hard rules** — a table of the few invariants that, if broken, make the output wrong regardless of how the steps went.
3. **Workflow** — numbered steps a competent agent can follow without re-deriving them, with the reference pointer for each path.
4. **Pointers** — "read `references/x.md` before doing Y", never a bare file list.

Plain English, no filler. Where the skill returns a result, give the shape of that result so two runs look alike.

## 5. Place and install

- **Internal:** `skills/<name>/` in the sassy-skills repo, named `sassy-<name>`; then `scripts/sync.sh` — it commits, bumps the patch version, tags, and publishes. Say that this ships to everyone before you do it.
- **Project:** `<repo>/.agents/skills/<name>/`, prefixed with the project so it cannot collide with a suite skill or a harness built-in; then commit it.
- **User:** `~/.agents/skills/<name>/` (plus a `~/.claude/skills/<name>` link for Claude Code). Nothing gates it, so check it actually works before trusting it.

Then run the skill's Verification section: reload, no load warning, invoking it behaves. A skill that has never been invoked has not been written.
