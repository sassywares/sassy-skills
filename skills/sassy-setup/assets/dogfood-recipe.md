# Dogfood — <project>

**Never** production. Local or staging only.

**Set up once:** <install, services to start, env files to copy; name variables,
never values>

**Reset:** <the product back to a known state — a database, a cache, a temp dir.
Never `reports/`: evidence must outlive the run that made it>`

**Preview:** <what you look at once it is up — a URL, a simulator name, a window. Not the command; that is a step below.>

<!--
Incomplete on purpose. sassy-setup writes this skeleton so the shape is visible;
`sassy-dogfood mode:discover` fills it by trying the product once and writing down
what actually worked. Until a section has a **Prove it:** step, every QA row stays
Manual.

Rules: steps are ordered and append-only; every step has **Do** and **Expect**;
one **Prove it:** per section and its exit code is the verdict; env var names
only; no tool names. Schema: sassy-setup/references/dogfood.md
-->

## <section> — <one line: what this proves>

1. **Do** <command or instruction>
   **Expect** <observable, checkable result>

2. **Do** <the proving command>
   **Expect** exit 0

**Prove it:** step 2 — its exit code is the verdict.
