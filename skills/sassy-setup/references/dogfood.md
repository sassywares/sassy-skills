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

**Set up once:** `bun install`; `docker compose up -d db`;
copy `.env.example` → `.env` and fill `DOGFOOD_USER`, `DOGFOOD_PASS`.

**Reset:** `bun run db:reset`; `rm -rf .sassywares/dogfood/reports/*`

**Preview:** `bun dev --port $PORT`, then open `$BASE_URL`

## catalog — a search returns matching products

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

## auth — an expired session re-authenticates

1. …
**Prove it:** step 2.
```

**A section is one testable area** — `catalog`, `auth`, `mobile`, `api`. A QA row
names a section; it never restates a step.

**Every step has `Do` and `Expect`.** Without an `Expect` it is a suggestion, not
a check, and `--check` reports it as drift. `Do` is a command *or* an
instruction ("open `/catalog`, sign in as `DOGFOOD_USER`") — the instruction is
why the recipe outlives whatever tool the agent happens to have this quarter.

**One `Prove it:` per section**, and its exit code is the verdict. Steps before
it set up state and assert along the way; the prove step is the machine-readable
answer. A section without one has no verdict.

**One `**Preview:**` line**, optional: how a human sees this checkout running. A
URL, a simulator name, a desktop app — whatever `sassy-worktree mode:preview`
should print once the app is up. Without one, the address is `$WT_BASE_URL`. It
is prose, like every other line here: no tool, no schema.

**Rules.**

- Ordered, numbered, **append-only**: add steps at the end of their section;
  never reorder or renumber. A removal carries its one-line why in the commit.
- **Env var names only.** Never a credential, a token, or a session cookie. If a
  step needs one, it names the variable and the project's own gitignored env file
  holds the value.
- **Local or staging only.** A recipe that names production is a bug.
- **The happy path plus its checks.** Debris ("metro holds 8081") is a learning,
  not a step: it goes to `artifacts.solutions` via `sassy-compound`, which
  scouting already reads. This is what keeps a busy project's recipe at forty
  lines instead of becoming a wiki.
- **No tool names.** Never "use Playwright" or "use the Chrome MCP". Say what to
  do and what to see, and let the run discover how.

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
- **`class`** — `code` (a finding for the rework cycle) | `env` (the toolchain is
  broken: a missing dependency, exit 75 or 127 — report and park, never loop) |
  `recipe` (the procedure itself is stale: a renamed script, a dead URL, a step
  that cannot be followed). `recipe` is the rot signal: the run proposes a
  one-line diff and never quietly improvises around it.
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
- The recipe has at least one `## ` section, every section has a `**Prove it:**`
  line, every numbered step has an `**Expect**`, and the file carries no
  secret-shaped strings.
- `dogfood.*` is a known key block; anything else in it is an unknown key.
