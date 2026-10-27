# Mode: verify — read, judge, report, change nothing

Read the skill's shared sections first (locations, Agent Skills rules, shape rule, checklist). This file is the read-only sweep.

**No writes. Not one.** No edits, no renames, no moving files between locations, no version bumps, no `scripts/sync.sh`. A verify run that "just fixes a typo while it is there" has become a retune without a named failure, and the user loses the report they asked for.

## 1. Read the whole skill as the harness will

- `SKILL.md`, then every file under `references/` — you cannot judge routing without seeing what it routes to.
- Check the frontmatter parses and the directory name matches `name`.
- If it ships from the suite or a package, note the pinned version: verification is against what consumers actually got.

## 2. Run the checklist

Walk the shared **Self-check checklist** item by item. For each, the evidence is the file, not an impression:

- Description: quote it and count the characters; does it name the *moment* it fires?
- References: every pointer resolves to a file that exists, and the body says read only one at a time.
- Shape: do the divergent paths sit in separate files, and is each shared surface back in the body?
- Leanness: is anything in the body only sometimes needed, or anything in a reference read on every run?

## 3. Run the skill, if it is installed

Reload the harness, confirm it lists the skill with no load warning, then invoke it (syntax per the `sassy-setup` skill's `references/harness.md`). Quote what it did. If it cannot be invoked here — different harness, uninstalled, needs credentials — say that plainly instead of implying a pass.

## 4. Report in one shape

```md
**<skill name> — <verdict: sound | needs a retune | malformed>**

**Passes**
- Each checklist item that held, with the evidence in a clause.

**Fails**
- `<checklist item>`: what is wrong, `path:line`, and the one-line fix a retune would make.

**Unverified**
- What you could not check here, and why.
```

Then stop. Name the retunes you would make; do not make them. If the user wants one, that is a new run in `mode:retune`, with the failure named.
