# Dogfood

Agent QA: a stored procedure that proves a change actually works in the running
product, not just in the diff. `sassy-dogfood` executes it, `sassy-plan` writes
automated QA rows against it, `sassy-work` gates on it, and `sassy-ship` refuses
to open a PR with it red.

The reference is deliberately tooling-agnostic. Nothing here names a browser, a
driver, or an MCP server: a recipe is steps and expectations, and whatever the
harness has connected at run time is what satisfies them.

## Why a procedure, and not a command

A single command cannot say "seed first, boot the simulator, wait for the health
endpoint, then re-auth if the token is stale" — and that ordering is the entire
project-specific knowledge. It is also what every fresh agent otherwise
re-derives, differently, every time.

So the config stores a **pointer and a switch**, never commands. Commands live in
the recipe because only the recipe can express their order, their prerequisites,
and what counts as success between them. A command copied into the config would
duplicate `package.json` or a `Makefile` and drift from it silently.

## Config

```yaml
dogfood:
  enabled: false                                   # false = every QA row is Manual
  recipe: .sassywares/dogfood/recipe.md            # the procedure
  reports: .sassywares/dogfood/reports             # run logs and artifacts; never committed
  timeout: 900                                     # whole procedure, seconds
```

| Key | Default | Meaning |
|-----|---------|---------|
| `dogfood.enabled` | `false` | `true` lets `sassy-plan` write `Mode: Auto` QA rows. `false` forbids them. Absent means `false`: no block is today's behavior — manual QA |
| `dogfood.recipe` | `.sassywares/dogfood/recipe.md` | The procedure. Relative to the config. Point it at an existing runbook only if that runbook is already in this format |
| `dogfood.reports` | `.sassywares/dogfood/reports` | Where a run writes its summary, step logs, and artifacts. Must be gitignored |
| `dogfood.timeout` | `900` | Wall-clock for one whole run. A timeout is a failure, never a hang |

`enabled` is written explicitly by `sassy-setup`, never left to inference, so a
teammate reads the decision instead of guessing at it. `enabled: true` is not a
promise that a check exists: an unfinished recipe degrades to Manual rows
(see *Two gates*), which is why the switch alone can never make a gate lie.

## Files

```text
.sassywares/
├── config.yaml
├── .gitignore         /session/ and /dogfood/reports/ — setup-owned
├── session/           cookie jar, storage state, token — shared, never committed
└── dogfood/
    ├── recipe.md      the procedure — committed, reviewed like code
    └── reports/       run output — never committed
```

The two ignore lines are setup-owned. `--check` reports it missing as drift,
because a project that "helpfully" removes it commits screenshots by accident.

## Recipe format

```markdown
# Dogfood — <project>

**Never** production. Local or staging only.

**Set up once:** `bun install` — shared by every section below.

**Reset:** `bun run db:reset`

**Uncovered:** mobile (unit tests only)

**Out of scope:** admin — decided against

## catalog — a search returns matching products

**Preview:** open `http://localhost:${WT_PORT:-3000}`

**Upstream:** `api.example.com` — a service this run does not control. Down is
`env`, never a retry.

1. **Do** `bun run db:seed -- --fixtures catalog-small`
   **Expect** `seeded 12 products`
2. **Do** `bun dev &`, then poll `curl -fsS localhost:3000/healthz`
   **Expect** `ok` within 60s
3. **Do** open `/catalog` and sign in as `DOGFOOD_USER`
   **Expect** the header shows that email; a 401 means the token env var is stale
4. **Do** search "wool socks", open the first result
   **Expect** the detail page titles match the search term
5. **Do** `bun run e2e -- --grep catalog`
   **Expect** exit 0

**Prove it:** step 5 — its exit code is the verdict.

## mobile — no runtime path yet

**Uncovered:** 100+ unit tests that never start the app; a later discovery builds its
runtime check.

**Prove it:** none
```

**A section is one testable area** — `catalog`, `auth`, `mobile`, `api`. A QA row
names a section; it never restates a step.

**Every step has `Do` and `Expect`.** Without an `Expect` it is a suggestion, not
a check, and `--check` reports it as drift. `Do` is a command *or* an
instruction ("open `/catalog`, sign in as `DOGFOOD_USER`") — the instruction is
why the recipe outlives whatever tool the agent happens to have this quarter.

**One `Prove it:` per section**, naming a step (`step 5`) or saying `none`. A
named step's exit code is the verdict; `none` is a legal, explicit "this surface
has no machine verdict" — the section still records what a person should check,
and every QA row for it stays `Manual`.

**Steps after the `Prove it:` step are cleanup.** They always run, they never
change the exit code, and that is where a port is freed or a process is stopped.
Putting teardown before the verdict means a failed run leaves the port held. Steps before
it set up state and assert along the way; the prove step is the machine-readable
answer. A section without one has no verdict.

### File level and section level

`**Preview:**`, `**Upstream:**`, `**Set up once:**`, and `**Reset:**` can be written at
file level **or inside a `## ` section**. A section's own value wins for that section;
the file-level value is the default every section inherits.

- **One surface: keep it flat.** File-level lines, one section — the shape most
  projects want, and nothing below changes it.
- **Several surfaces: nest.** Each app's address and backend belong in that app's
  section. A file-level `**Preview:**` on a five-app project can only describe one of
  them, which is how a recipe ends up talking about the web app while claiming to
  describe the project.

For a **checkout's address**, `sassy-worktree` reads the file-level line; with no
file-level line and exactly one section it uses that section's; with several sections
and none at file level it shows nothing, because guessing which app a checkout serves
is worse than saying nothing.

`**Uncovered:**` and `**Out of scope:**` stay **file level** — they are the inventory of
surfaces, not a description of one. Each name in that inventory still needs its own
section (see `**Uncovered:**` below).

**One `**Preview:**` line**, optional: **what you look at**, not the command that
starts it. The command belongs in the section's steps, where its `Expect` can be
checked — and no step has to consume this line: a suite that starts its own server
never visits the address a human would. The result — a URL, a simulator, a window — is the project's own answer
to "what is the address", and it is why the suite never has to assume a browser.

`$WT_SLUG`, `$WT_NAMESPACE`, `$WT_PATH`, `$WT_PORT`, and `$WT_BASE_URL` are
substituted into the preview line and into every step. The last two exist only
when `worktrees.ports` is configured, and a recipe must also run in the **main
checkout**, where no worktree exists — so write the port with the project's own
default: `${WT_PORT:-5180}`. One expansion that works in both places is what
keeps a recipe runnable outside a worktree.

| Project | Preview line |
|---|---|
| Web | `http://localhost:${WT_PORT:-5180}` |
| Mobile | `simulator "$WT_NAMESPACE"` — booted by the `after_create` hook |
| Desktop | `the app window is already open` |
| CLI | *(none — there is nothing to look at)* |

**`**Upstream:**` and `**Uncovered:**`** are optional header lines that make the
two dangerous facts visible without reading every step: which third-party services
the recipe depends on, and which parts have no machine verdict at all. `Uncovered`
may name a sub-area of a covered surface — "the web surface's auth and write
flows" — which is where a third-party rule usually lands.

**`**Out of scope:**` is different from `**Uncovered:**`** and the difference is the
whole point: `Uncovered` means *no path yet* — a later discovery is expected to ask
again — while `Out of scope` means *decided against*, and a later discovery must
leave it alone. Without the two words, "we have not built this" and "we do not want
this" read the same, and discovery asks about both for ever. A section
with no verdict ends `**Prove it:** none`, so a plan keeps its rows `Manual`
instead of inventing an Auto row for a check that does not exist.

Prose, like every other line here: no tool, no schema.

**Rules.**

- Ordered, numbered, **append-only**: add steps at the end of their section;
  never reorder or renumber. A removal carries its one-line why in the commit.
- **Env var names only.** Never a credential, a token, or a session cookie. If a
  step needs one, it names the variable and the project's own gitignored env file
  holds the value.
- **Local or staging only.** A recipe that names production is a bug.
- **A prerequisite carries its command.** *Set up once* is commands, not prose: a
  required Node, JDK, or database names the command that provides it (`nvm use 24`)
  as well as the requirement. A run may not improvise activation, so a stated
  requirement with no command only works on machines that happen to be ready.
- **No dependency churn.** *Set up once* installs frozen when a lockfile exists.
  A broke lockfile is `env`; repairing it silently re-resolves versions and makes
  every checkout dirty.
- **No third-party mutation.** A step never registers a user, sends mail, or
  writes to a shared service. Log in by hand and copy the session in.
- **The happy path plus its checks.** Debris ("metro holds 8081") is a learning,
  not a step: it goes to `artifacts.solutions` via `sassy-compound`, which
  scouting already reads. This is what keeps a busy project's recipe at forty
  lines instead of becoming a wiki.
- **No harness tools.** Never "use Playwright" or "use the Chrome MCP" — a driver,
  MCP server, or emulator is a harness choice, not a procedure. Ordinary shell
  utilities (`curl`, `lsof`, `grep`) are fine: they are how a step is written.

## Sessions, and a second checkout

Authentication is the one thing that cannot be standardized: a cookie jar, a
storage-state file, a bearer token, a client certificate, a device-code flow —
each project is different, and the mechanism is *discovered* rather than
configured. Two things follow, and they are all this file says about it:

- **Session material lives in `.sassywares/session/`**, gitignored with the same
  setup-owned file as the reports. The suite never inspects what is in there. A
  step that needs a credential names an env var or points at that directory and
  never carries a value.
- **The procedure says how it is obtained and used** — in *Set up once*, in
  `**Preview:**`, or in a plain section of its own. `mode:discover` writes it
  once, after finding out what actually works, and `mode:run` or
  `mode:preview` stops with an env-class report when the session is missing
  rather than retrying against a login page.

A worktree gets a fresh, empty `session/`. When a project's provider registers a
single callback URL, a second checkout usually cannot log in on its own, so the
usual answer is to copy or link the main checkout's session in the
`after_create` hook. Worth writing down, because a **cookie** is host-scoped and
crosses ports freely while a **`localStorage`** session is origin-scoped, port
included, and has to be injected per origin — the difference looks like a broken
transplant when it is only the wrong mechanism.

## Reports

```text
.sassywares/dogfood/reports/
└── 20260514-093107/                 run id: YYYYMMDD-HHMMSS, sorts chronologically
    ├── summary.md                   the only file read whole
    ├── steps/
    │   ├── catalog-01.log           <section>-<NN> — a file name is a citation
    │   └── catalog-05.log
    └── artifacts/
        ├── catalog-03-header.png
        └── catalog-05-trace.zip
```

```markdown
# Dogfood run 20260514-093107

**status:** failed
**class:** code
**section:** catalog
**recipe:** .sassywares/dogfood/recipe.md @ a91f3c2
**started:** 09:31:07  **finished:** 09:33:41

| Step | Expect | Result |
|---|---|---|
| catalog-1 | `seeded 12 products` | pass |
| catalog-5 | exit 0 | **fail, exit 1** |

**Prove it:** catalog-5 → exit 1. 3 of 41 e2e specs failed.
**Artifacts:** `artifacts/catalog-05-report.json`, `artifacts/catalog-05-trace.zip`
**Next:** re-run from catalog-4, not catalog-1.
```

`summary.md` is created at the start with `status: running` and finalized on exit.
A killed session therefore leaves an accurate breadcrumb, and the next one reads
one file to know where it stopped.

- **`status`** — `running` | `pass` | `failed`.
- **`class`** — `code` (a finding for the rework cycle) | `env` (the environment
  cannot produce a verdict: a missing dependency, exit 75 or 127, or a third-party
  service nobody in this run owns being down — report and park, never loop) |
  `recipe` (the procedure itself is stale: a renamed script, a dead URL, a step
  that cannot be followed). `recipe` is the rot signal: the run proposes a
  one-line diff and never quietly improvises around it.
- **A preflight or bring-up failure** has no step id: its log is `steps/00-setup.log`
  and its table row is `setup`. It is a verdict about the environment, so it still
  gets a `class`.
- **One log per executed step**, capped head-and-tail (~64 KB) with a
  `[truncated N lines]` marker, so a runaway loop cannot fill the disk.
- **Redaction happens before the write.** Every value of an env var the recipe
  names is masked, plus a token-shape pass. A recipe that "stores creds" must not
  leave them in a log an agent will later paste into a report.
- **The agent never reads a log whole.** It reads `summary.md`, then the last
  ~600 characters of the failing step. An agent that reads a 40k-line log dies of
  a missing semicolon.
- **Reports are pruned to the ten most recent** at the start of each run. Nothing
  is committed here, so nothing must survive. The durable record is the QA row's
  note — `catalog-5 exit 1, run 20260514-093107` — which never depends on a path
  that will be deleted.
- **Never committed.** Not the logs, the artifacts, or the traces.
- **Never deleted by a recipe.** `**Reset:**` puts the *product* back to a known
  state; it never touches `reports/`. Pruning to ten is the tooling's job, and a
  recipe that deletes reports destroys the record of the failure you were about to
  investigate — including the one that is still open.

## Two gates: `enabled` and the recipe

An Auto QA row needs **both** `dogfood.enabled: true` **and** a section whose
recipe carries a `Prove it:` step. One without the other means the row stays
`Manual`. That is how an unfinished recipe degrades safely instead of producing a
green gate that proves nothing — there is no third state in the config and no
lying switch.

## Who writes what

| Artifact | Owner |
|----------|-------|
| `dogfood:` block in the config | `sassy-setup` — the only skill that writes the config |
| `.sassywares/dogfood/recipe.md` | `sassy-dogfood` (`mode:discover` authors and repairs it; a `mode:run` never edits it to pass) |
| `.sassywares/.gitignore` | `sassy-setup`; never removes a line |
| `.sassywares/session/` contents | the project — obtained and written by its own step or hook, never by this skill |
| `reports/` | `sassy-dogfood`, always gitignored, pruned to ten |
| `Mode: Auto` QA rows | `sassy-plan`, a section name per row |
| Row results | `sassy-work`, from a passing report — never from an opinion |

## `--check` lint

Structural, never executed:

- `enabled` is `true|false`; `timeout` is a positive integer; both paths are
  relative and stay inside the project.
- `recipe` exists when `enabled` is `true` — absent, it is "created by the first
  `sassy-dogfood` run", a note rather than drift.
- `reports` is gitignored in a `repo` topology (`git check-ignore`), since a run
  once committed would be drift nobody catches later. The same check covers
  `.sassywares/session` whenever that directory exists — a committed session is a
  credential leak, not a heavy history.
- A surface named under `**Out of scope:**` has no section; one under
  `**Uncovered:**` has a section ending `**Prove it:** none`.
- The recipe has at least one `## ` section, every section has a `**Prove it:**`
  line whose value names a step (`step 3`) or is `none`, every numbered step has an
  `**Expect**`, and the file carries no secret-shaped strings. A `Prove it:` that
  is neither is a typo, and a typo reads as a verdict.
- `dogfood.*` is a known key block; anything else in it is an unknown key.
