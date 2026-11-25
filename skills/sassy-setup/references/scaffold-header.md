# The scaffold header

One header, one owner. Every project-owned file the suite plants **outside**
`.sassywares/` — today the worktree `create`/`remove` pair, and any future script
or config setup writes — carries the line below. Files inside `.sassywares/` are
either suite-owned assets or carry their own H1.

A file the project already had never gets one. The worktree toolbox under
`.sassywares/worktree/` is copied, not scaffolded: it is suite-owned and carries
its own `worktree-version` line instead.

## The bytes

```text
# sassywares:scaffold v1 skill=<name> version=<version> date=<YYYY-MM-DD>
```

`skill` is the suite skill that wrote it (`sassy-setup`), `date` is the day it was
written. After that line come a blank comment line and the prose block: the
file's contract — what it is called as, what it must exit with, what it must
print — and the statement that future setup runs leave it alone. The header is
part of the file; never move it below the contract.

## What `version` means

The suite release that wrote the file **at write time**. Provenance, never a pin:

- never updated when the suite moves;
- never compared, by `--check` or by anything else;
- never drift, and never a reason to report the file as edited or stale.

The suite-owned toolbox is proven by a content hash; a scaffolded project file
has no hash at all, so an old version number there says nothing about its current
contents.

## Resolving `<version>`

At write time, in this order:

1. The suite's own release, when the install carries one — `version` in the
   `@sassywares/skills` `package.json` beside the skill, or
   `git describe --tags --abbrev=0` in a sassy-skills checkout.
2. Otherwise the literal word `unknown`. Never guess a number and never leave the
   field empty.

`skills-lock.json` cannot supply one. Its `version` is the lock format's era
(`1`, `2`, `3`) and each entry's `computedHash` is content, not a release, so a
project pinned that way still has no suite version to write down.

## Upgrading a scaffold

Never rewrite it. A later setup run may **offer** to migrate a scaffold whose
template version has moved: show the header, the current template, and what the
project added. The answer is the user's, and migrating is editing their file with
their approval — not setup installing over it. Setup installs new files only, so a
scaffold the project deleted stays deleted until the user asks for it again.

## Never on YAML frontmatter

A document that already starts with YAML frontmatter — a plan, a goal, a
solution, a handbook — never takes this header. The frontmatter is its metadata
and the first bytes belong to it; provenance there is `created`/`updated`, not a
comment.
