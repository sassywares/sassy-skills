---
type: feat
created: 2026-11-26
updated: 2026-11-26
---

# Worktree lifecycle: two project-owned scripts

## Intent

Move every per-worktree project step out of the suite and into two scripts the project owns — `create` and `remove` — which setup scaffolds once and never rewrites. The suite keeps only project-agnostic git mechanics. `up`, `down`, `hooks.worktree`, and the `prune` mode are deleted: the scripts are the lifecycle, `list` answers what is safe to delete, and a project's own teardown runs because the script says so, not because a key declared it.

## Decisions

- **D1 — Project scripts are the entry points.** `sassy-worktree` runs `<worktrees.create>` / `<worktrees.remove>`; those scripts call `.sassywares/worktree/create|remove` when they need git work. (user-directed, over the suite script executing a configured path: the suite would stay the caller of project code, which is the coupling being removed)
- **D2 — Location is probed, then recorded.** `<home>/worktrees/create` and `<home>/worktrees/remove`, where `<home>` is the first existing of `scripts/`, `bin/`, `tool/`, `tools/`, else `tool/` for dart/flutter and `scripts/` otherwise. `sassy-overview`'s `stack` breaks only that tie; the identify table gains no column. New files only. (user-directed, over a per-stack table: Go's `bin/` is gitignored build output and npm's `bin/` means published CLI entry points)
- **D3 — Config carries paths, and absence degrades.** `worktrees: {enabled, dir, create, remove}`; `create`/`remove` are single paths with no arguments. An **absent** key falls back to the built-in silently — a project that deleted the pair means it. A key that **declares** something unusable falls back to the built-in with a loud warning naming the key and the file: a missing or non-executable file is a `--check` **note** (a deleted script is legitimate), while a malformed value — more than one path, an absolute or `..` path, a list — is **drift**, because that is a config mistake and not an absent file. (user-directed: "if they end up removing it we of course just use the internal scripts")
- **D4 — The suite never rewrites a project file.** Suite assets stay read-only and hash-checked; the two project scripts are wholly the project's, installed once from a template. The contract is enforced behaviorally: `create` must exit 0 **and** emit the `WT_*` identity, and a run that doesn't is reported as "checkout is real but unprepared". `--check` asserts the contract line exists (a grep), never rewrites. (user-directed, over a sentinel-delimited managed block: setup editing a file the user edits is the failure mode that made the hooks feel broken)
- **D5 — Every scaffold carries a provenance header.** `# sassywares:scaffold v1 skill=<skill> version=<version> date=<YYYY-MM-DD>`, then prose naming the contract and stating the file is the project's. It is write-time provenance, never a version pin: never updated, never compared, never drift. An upgrade is offered, never applied. One owner: `sassy-setup/references/scaffold-header.md`. (user-directed; contrasts with the no-pins rule in `AGENTS.md`)
- **D6 — The toolbox keeps `skills/sassy-setup/assets/worktree/` with `_lib.sh`, `create`, `list`, `remove`.** `prune` is deleted; the singular path now distinguishes the suite-owned toolbox from the project's `<home>/worktrees/`. `# worktree-version:` and `WT_VERSION` move 12 → 13 together. (from code: `skills/sassy-setup/assets/worktree/_lib.sh`)
- **D7 — `list` absorbs the classification `prune` owned.** A state column — `merged` / `gone` / `unmerged` — from `wt_upstream_state`. No bulk removal: one `remove <slug>` per checkout, with the plain-language "remove the merged ones" path documented as a confirmation plus a sequential walk. (user-directed; `remove` keeps the branch, so "merged" was never a data-safety gate — `worktree.md:180-186`)
- **D8 — `create` splits its streams.** The four `WT_*` lines go to stdout, all human narration to stderr; `--env` is retired. (user-directed, over keeping `--env`: one call instead of two, and the unprepared check becomes a bare assertion)
- **D9 — `list --env <slug|branch>` prints the same four lines** for an existing checkout, via one `wt_print_env` shared with `create`. `create` mints an identity, `remove` receives one. (user-directed, over the caller exporting `WT_*`: the scripts then behave the same by hand and under an agent)
- **D10 — Setup's interview writes named, inert stubs.** Per confirmed need (a convex preview deployment, a seeded temporary database dropped on remove, a compose namespace), a labelled comment in the right slot, specific because of the answer, executable by nobody. An untouched template behaves exactly like the git-only baseline. (user-directed, over setup writing working code it cannot verify; upholds `init.md:98` "hooks are named, not written" and `init.md:100` "setup scaffolds the skeleton and stops")
- **D11 — Legacy keys are a named error, and mutation is requested.** `--check` hard-errors on `up`, `down`, and `hooks.worktree` with the exact fix (`detect.sh:511` already fails unknown keys; this adds a legacy-specific message); a `mode:write` run the user asks for deletes them, writes `worktrees.create`/`remove`, and scaffolds the pair. Detection automatic and loud, mutation requested. (user-directed, over a silent legacy warning: a project that believed `down:` stopped its stack would get silent non-stopping)

## Constraints

- **Suite assets stay project-agnostic.** Nothing Sassywares-specific enters `skills/`; the release tooling lives in `bin/`, `.sassywares/`, and `.agents/`.
- **`.sassywares/config.yaml` remains the only config file, and the toolbox is read-only.** Mechanics stay at `skills/sassy-setup/assets/worktree/`, vendored to `.sassywares/worktree/`; no fifth script, no second config.
- **`worktree-version` and `WT_VERSION` move together** or `worktree-check.mjs` reads a stale tree as intact.
- **Skill bodies are behavior.** A phase that changes what an agent does is `logic`, not `surface`, however small the diff.
- **All three phases land in one commit** (`commit.branch: current`), so `AGENTS.md`'s same-commit docs rule holds even though `README.md` and `CONCEPTS.md` are swept in P3.
- **Risks.** A deleted `create` script degrades to git-only, so a checkout can look successful while unprepped — the warning must name the key and the file. Removing `prune` widens the gap for a project with dozens of stale checkouts: `list` state plus a sequential walk is slower by design.

## Deferred

- **F1 — Migrate the maintainer's three Sassywares repos** (drop `up:`/`down:`, scaffold the pair). Outside this repo, and only reached when `SASSY_ROSTER_REPOS` is set: `tests/sassy-setup-roster.sh:75` gates those checks behind that opt-in, so no default run depends on them. (user-deferred — after the suite ships)
- **F2 — Exact stub wording per pattern** (convex, compose, postgres drop, simulator). (implementation-time — the shape is D10; the sentence per pattern is best written against a real project)

## Assumptions

- **A1 — First match wins** when two candidate `<home>` directories exist; setup asks, so a wrong default is one edit. (user-delegated)
- **A2 — The shipped default create body is the one git call and the identity re-emit**, and the default remove body is `list --env`, the single git removal, and nothing else — i.e. the baseline is today's behavior, expressed in project files. (user-delegated)
- **A3 — Untouched stubs are inert and warn nothing.** Only the *contract line* is enforced; an unedited scaffold behaves like the git-only baseline without nagging. (user-delegated)

## Phase tracking

| Phase | Goal | Status |
|-------|------|--------|
| P1 | The toolbox gains the new contract, loses `prune`, `up`/`down`, and hooks | Done |
| P2 | Setup scaffolds and interviews; the references describe the new surface | Done |
| P3 | The suite's skill, README, concepts, and tests describe only the new world | Done |

Status values: `Pending` | `In progress` | `Blocked` | `Done`

`Done` on a phase means its code was approved and every QA row for it is `Done`.

## Phases

### P1 — Toolbox: scripts, keys, contract

**Goal:** the four remaining scripts implement D8, D9, D7, and D3, and every dead key is gone from the reader.

**Why this slice:** after this phase a project *could* wire its own scripts by hand — the full contract exists end to end — even though nothing scaffolds them yet.

**Review:** logic

**Work (vertical):**
- `assets/worktree/_lib.sh`: `wt_print_env` (one formatter); `wt_upstream_state` stays as the state source; delete `wt_down`, `wt_hook`, and the helpers only they called; bump `# worktree-version:` and `WT_VERSION` to 13.
- `assets/worktree/create`: stdout carries only the four `WT_*` lines, narration to stderr, `--env` gone; keep idempotency and every refusal.
- `assets/worktree/list`: state column from `wt_upstream_state`; `--env <slug|branch>` printing the four lines; ambiguity is an error, never a first match.
- `assets/worktree/remove`: delete `--hook-ok` and the `down:` execution; guards → git removal, branch survives.
- Delete `assets/worktree/prune` and `assets/lifecycle/{up,down}`.
- `scripts/detect.sh`: accept `worktrees.create`/`worktrees.remove`/`worktrees.enabled`/`worktrees.dir`; drop `up`, `down`, `hooks.worktree`; legacy-specific message on each; add the read-only `--worktree-script create|remove` resolver — the declared path when it is executable and well-shaped, else the built-in with a warning naming the key and the file; keep the `--check` output shape.
- `scripts/worktree-check.mjs`: hash four files instead of five. ~~treat a 12 → 13 version as an upgrade, not drift~~ — **reversed in the v13 aftermath:** that short-circuit exited 0 before hashing, so a v8 set under v13 wrappers passed every check while `remove` died on `list --env`. A lower header is now drift.
- `tests/worktree-create.sh`: assert the stream split, `list --env` parity, the state column, the missing-script warning, and a remove that runs with `WT_*` set and no hooks.

**Done when:** on a scratch repo, a hand-written pair of project scripts creates a prepared checkout and tears it down in order — stop while the tree exists, delete, dispose after — with no `up`, `down`, `prune`, or hook anywhere in the path.

#### QA — P1 (Manual)

| ID | Check | Mode | Status | Notes |
|----|-------|------|--------|-------|
| P1-Q1 | In a scratch repo with the toolbox installed, `.sassywares/worktree/create demo --from origin/main 2>/dev/null` prints four `WT_*` lines and nothing else, and the same command without `2>/dev/null` shows the narration | Manual | Pending | |
| P1-Q2 | `.sassywares/worktree/list` shows a state column reading `merged`, `gone`, or `unmerged` per checkout, and `list --env demo` prints the same four lines `create` printed | Manual | Pending | |
| P1-Q3 | Delete the `create:` key's file, run `create demo2` again, and the run still produces the checkout while printing a warning that names the key and the missing file | Manual | Pending | |
| P1-Q4 | With an `up: just dev` line in a scratch config, `detect.sh --check` fails and the message names `up` and says where the lifecycle moved | Manual | Pending | |
| P1-Q5 | `bash tests/worktree-create.sh` passes | Manual | Pending | |

### P2 — Scaffold: templates, header, interview

**Goal:** `sassy-setup` scaffolds the pair after an overview, interviews for project needs, and records the probed paths.

**Why this slice:** with the contract in place, the default project needs no hand-writing: setup produces two working scripts, and a project with a convex backend or a per-worktree database gets a stub naming exactly what to add.

**Review:** logic

**Work (vertical):**
- `references/scaffold-header.md` (new): the header's exact bytes, its semantics (write-time provenance, never a pin, never compared), and the offer-only upgrade rule — cited by every skill that plants a project file.
- `assets/templates/worktrees-create`, `assets/templates/worktrees-remove`: the contract line, the labelled slots (`before git` / `after git`; `stop, while the tree exists` / `dispose, after the tree is gone`), A2's bodies, the header.
- `references/init.md`: probe `<home>`, ask and record `worktrees.create`/`remove`, install the templates executable, run the D10 interview, and write D11's legacy migration on request.
- `references/config.md`: replace the Lifecycle section and `up`/`down`/`hooks.worktree` with `worktrees.create|remove` semantics, the degrade rule, the schema list, and the config template block.
- `references/worktree.md`: the four-script table, the stdout/stderr contract, `list --env`, the state column, no `prune`, no hooks, and the script-order diagram.
- `references/check.md`: the legacy error and the note a degraded key produces.

**Done when:** a fresh `sassy-setup` run in a scratch repo leaves two executable scripts carrying the header, keys recording them, and either an empty or an explicitly stubbed extension area — and a second `--check` run changes nothing.

#### QA — P2 (Manual)

| ID | Check | Mode | Status | Notes |
|----|-------|------|--------|-------|
| P2-Q1 | Run setup on a scratch repo; `scripts/worktrees/create` and `remove` exist, are executable, carry the `# sassywares:scaffold v1 …` header and the contract comment, and the config records both paths | Manual | Pending | |
| P2-Q2 | Run `scripts/worktrees/create demo --from origin/main` unedited: the checkout is identical to a direct toolbox create, and the command prints the four `WT_*` lines | Manual | Pending | |
| P2-Q3 | During the interview, confirm a per-worktree database; the created template carries a labelled comment naming the need and its removal step, and no executable line for it | Manual | Pending | |
| P2-Q4 | Run `detect.sh --root <scratch> --check` twice; the second run reports no drift and neither script is touched | Manual | Pending | |
| P2-Q5 | On a scratch config containing `down: just stop`, `--check` fails with the named fix, and a `mode:write` run the user asks for removes the key and writes the two paths | Manual | Pending | |

### P3 — Thread-through: skill, docs, tests

**Goal:** no suite file describes `up`, `down`, `hooks.worktree`, `prune`, `--hook-ok`, or `--env`, and the skill runs the project scripts.

**Why this slice:** a contract nobody's documentation agrees with is a future bug report; this is the phase that makes the whole suite speak one world.

**Review:** logic

**Work (vertical):**
- `skills/sassy-worktree/SKILL.md`: modes become `list|create|remove`; the create/remove paths run the configured scripts.
- `references/create.md`, `references/remove.md`, `references/list.md`: rewritten around D1, D8, D9, D7 — including the "unprepared" report and the sequential walk for several checkouts.
- Delete `references/prune.md`.
- Sweep `skills/` for `down:`, `up:`, `hooks.worktree`, `prune`, `--hook-ok`, `--env`, and rewrite each hit.
- `README.md`: the worktree section, the config table, and the skill modes.
- `CONCEPTS.md`: retire the lifecycle and prune vocabulary, define the create/remove scripts and the scaffold header.
- `AGENTS.md`: the layout line for `assets/worktree/` and the deleted lifecycle assets.
- `tests/sassy-setup-roster.sh`: any fixture that declared `up`/`down` moves to the new keys.

**Done when:** grep finds no dead token across `skills/`, `tests/`, `README.md`, `CONCEPTS.md`, and `AGENTS.md`, the three test scripts pass, and `detect.sh --root . --check` passes on this repo.

#### QA — P3 (Manual)

| ID | Check | Mode | Status | Notes |
|----|-------|------|--------|-------|
| P3-Q1 | `grep -rn "hooks.worktree\|--hook-ok\|prune\b" skills/ tests/ README.md CONCEPTS.md AGENTS.md` returns nothing about a live surface | Manual | Pending | |
| P3-Q2 | In a scratch repo with the scaffolded pair, ask `sassy-worktree` for `mode:create` and then `mode:remove`: the run uses the project scripts, and the remove stops the stack before deleting the tree | Manual | Pending | |
| P3-Q3 | `bash tests/worktree-create.sh`, `bash tests/sassy-setup-roster.sh`, and `bash tests/sassy-overview-identify.sh` all pass | Manual | Pending | |
| P3-Q4 | `bash skills/sassy-setup/scripts/detect.sh --root . --check` passes on this repo | Manual | Pending | |
| P3-Q5 | README's worktree section and config table describe only the new keys and the two scripts, with no `up`/`down` | Manual | Pending | |
