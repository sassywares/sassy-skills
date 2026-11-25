# Worktree cut: read-only mechanics, up/down lifecycle, and sassy-overview

**QA:** manual

## Intent

Reduce the worktree half of the suite to what it actually does — git mechanics plus two project-owned lifecycle hooks — by deleting the port broker, the preview mode, and every dependency on the dogfood recipe. In the same stroke, give a project one first-class way to say how its stack comes up and goes down (`up:` / `down:`, top-level, pointing at an exact script or skill), and stop the suite from reinventing stack detection by introducing `sassy-overview`, a script-backed skill that answers "what is this project and how does it run" once, for every skill that needs it.

The evidence is that nobody uses the parts being deleted: the maintainer has never run `preview` or a port claim, and `sassy-worktree` is the only thing that ever read a recipe — `sassy-dogfood` has zero references to worktrees, so the coupling was one-directional and this is pure deletion on our side.

## Decisions

- D1: `hooks.worktree.after_create` / `before_remove` stay exactly as they are. They are per-checkout provisioning and deprovisioning (Convex preview environment in, environment out), not stack lifecycle. (user-directed)
- D2: what "up" and "down" mean is per-project. The suite supplies the shape and the env, never the commands. (user-directed)
- D3: an `up:`/`down:`/hook value may name a skill or a command. A shell script cannot dispatch a skill, so the script exits `3` with `require-hook <name>` and the agent runs it — the existing `remove` handshake. (user-directed; from code: `skills/sassy-setup/assets/worktree/remove`, exit 3)
- D4: `.sassywares/config.yaml` stays the only user-editable file under `.sassywares/`; everything else there is suite-owned and read-only. (user-directed, over "let a project extend `_lib.sh`": `_lib.sh` says the opposite today and that is the doctrine being replaced)
- D5: mechanics live at `.sassywares/worktree/` (singular, unchanged) and are read-only. (user-directed)
- D6: `--check` hashes the installed `.sassywares/worktree/` set with the existing `skills-lock` machinery instead of comparing the `worktree-version` header, so one edited byte is drift; setup then overwrites without asking, because there is no legitimate project edit to preserve. (recommendation, accepted)
- D7: `up:` and `down:` are top-level config keys, each naming exactly one script-or-skill. Not under `worktrees:`, which is gated on `enabled` and on the `repo` topology. (user-directed)
- D8: setup initializes the pair: probe for an existing answer (`make`, `just`, `docker compose`, a `bin/dev`) and offer to point the keys at it; otherwise write a failing stub at a probed path and set both keys. Never fabricate a manifest to hold an alias. (user-directed, option 2)
- D9: `create` runs `after_create` only, never `up` — provisioning must terminate, `up` does not. (from Conductor's docs: setup script vs long-running action)
- D10: `up` runs in the foreground and is stopped by SIGTERM, and it must reap its children; `down` must terminate. A detached or daemonizing `up` leaves processes holding the checkout, which is exactly what `down` then cannot kill. (from Conductor's process-handling rules)
- D11: `remove` runs `down` when configured, then deletes. Its guards reduce to dirty tree, unpushed commits, and the main checkout. Nothing probes for a running process. (user-directed, option 1)
- D12: `mode:preview`, `worktrees.ports`, `stop`, every recipe parse, and the dogfood verdict column are deleted. `sassy-worktree` and `sassy-dogfood` become strangers. (user-directed)
- D13: `WT_NAMESPACE` survives — it is the derived per-checkout name and is what `after_create` needs. `WT_PORT` and `WT_BASE_URL` are removed. (user-directed)
- D14: port strategy is documented for the project and never implemented — one example line deriving a port from `WT_SLUG`. Two checkouts running the same app collide, and the reference says so plainly. (user-directed)
- D15: `list` prints branch · path · dirty · upstream. `--address` and `--preview` are gone. (from the cut in D12: three of its five columns were guesses about a file we did not own)
- D16: `sassy-overview` owns "what is this project and how does it run", with `scripts/identify.sh` and `mode:identify` as the default mode, shaped so further overviews can be added as new scripts and references. (user-directed)
- D17: identify is read-only file inspection — no network, no execution, no `make -n`. Every value carries its source file; `unknown` is a first-class answer; exit `3` when a requested key is unknown so callers branch rather than guess. (user-directed, option 1 of the scope question)
- D18: its consumers are `sassy-setup` now and `sassy-dogfood` after F1 — never `sassy-worktree`, whose `up`/`down` pointers already carry the stack. (from the cut: wiring worktree to a project audit would re-create the recipe seam by another name)
- D19: it lives in `skills/sassy-overview/scripts/`, is invoked by path from the skill directory, and is never installed into `.sassywares/` — it is a query, not a mechanic, so there is nothing to reconcile. (from code: `sassy-setup` already invokes `detect.sh` this way)
- D20: `detect.sh:582`'s hardcoded `package.json deno.json deno.jsonc composer.json` list is replaced by a call to identify. (from code: that is the suite's only stack guess)

## Constraints

- The suite stays project-agnostic. Nothing Sassywares-specific (`bin/release`, the `sassy-skills-release` skill) enters `skills/`.
- Setup writes no editable file into a project's tree. The `up`/`down` stubs are the project's from the moment they land, and setup never touches them again.
- Never create a `package.json`, `Makefile`, or any manifest so an alias has a home.
- Removing `worktrees.ports` is a config-schema change: `--check` must report it with the line that fixes it, and a leftover key must stay harmless.
- `tests/worktree-create.sh` must still fail if `--no-track` is dropped, and `tests/sassy-setup-roster.sh` must still fail if the lock hash changes.
- `skills/sassy-setup/assets/roster` must equal `ls skills/` in the same commit that adds `sassy-overview`.
- Never release with a README describing old behavior.

## Deferred

- F1: `sassy-dogfood`'s own rework, including the `.sassywares/dogfood/recipe.md` file sitting inside the directory D4 calls suite-owned. (user-deferred to the dogfood rework)
- F2: whether identify gains a `--probe` mode that recommends the `up`/`down` wiring as a first-class output instead of `sassy-setup` assembling it from facts. (implementation-time — decide after it has run on real projects)
- F3: whether the removed `worktrees.ports` key warrants a hand-written minor bump. The release script's automatic patch bump is the default. (implementation-time)

## Assumptions

- A1: identify's initial manifest table covers Go, Node, Python, Dart/Flutter, Rust, PHP, Ruby, plus `make`, `just`, and `docker compose`, and the executor adds a row only alongside a fixture test that proves it. (user-delegated)

## Phase tracking

| Phase | Goal | Status |
|-------|------|--------|
| P1 | Land the alias-independent worktree docs | Done |
| P2 | Ship `sassy-overview` with `identify.sh` | Done |
| P3 | Make `detect.sh` hash the tree and ask identify | Done |
| P4 | Cut ports, preview, `stop`, and every dogfood dependency | Done |
| P5 | Add `up:`/`down:` and wire setup to initialize them | Done |
| P6 | Sweep docs and tests to match | Done |

## Phases

### P1 — Land the alias-independent worktree docs

**Goal:** Commit the nine already-verified files that make the worktree and workspace mechanics runner-agnostic, so the cut in P4 happens on a clean base.

**Why this slice:** it is a finished, self-contained change whose README edit documents all five scripts — including `stop`, which P4 deletes. Landing it alone keeps both commits honest and leaves no half-told story between them.

**Review:** none

**Work (vertical):**
- Commit the working tree as one change: the scripts are the contract, aliases optional, no manifest ever fabricated.
- No new edits. If a test fails here, fix it inside this phase.

**Done when:** the nine modified files are committed on `main`, and the README's script contract reflects five scripts.

#### QA — P1 (Manual)

| ID | Check | Mode | Status | Notes |
|----|-------|------|--------|-------|
| P1-Q1 | `bash tests/sassy-setup-roster.sh` and `bash tests/worktree-create.sh` both pass | Manual | Done | |
| P1-Q2 | `bash skills/sassy-setup/scripts/detect.sh --root . --check` reports no drift | Manual | Done | |

### P2 — Ship `sassy-overview` with `identify.sh`

**Goal:** One script gives a definitive, sourced answer to what a project is and how it runs.

**Why this slice:** every later phase that needs to know a stack or a command calls this, so it lands first and gates P3 and P5.

**Review:** logic

**Work (vertical):**
- Create `skills/sassy-overview/` through `sassy-skill mode:create`: `SKILL.md` (outcome, hard rules, dispatch table naming exactly one reference, default `mode:identify`), `references/identify.md`, `scripts/identify.sh`, `scripts/lib.sh`.
- `identify.sh`: tab-separated `key<TAB>value<TAB>source` lines; keys `stack`, `runner`, `install`, `up`, `down`, `test`, `compose`, `env`, `wired`; `unknown` with source `-` when nothing is found; exit `0` answered, `3` a requested key is unknown, `2` usage.
- File inspection only — no network, no execution of project tooling.
- `tests/sassy-overview-identify.sh`: fixture repos (Go, Python, Node, and one with nothing) asserting exact output and the exit codes.
- Add `sassy-overview` to `skills/sassy-setup/assets/roster`; README skill table; `CONCEPTS.md`.

**Done when:** running identify on this repo, a Go fixture, and an empty fixture returns sourced answers, writes nothing, and exits `3` when a requested stack has no command.

#### QA — P2 (Manual)

| ID | Check | Mode | Status | Notes |
|----|-------|------|--------|-------|
| P2-Q1 | `bash tests/sassy-overview-identify.sh` passes and fails if a fixture's manifest is removed | Manual | Done | |
| P2-Q2 | On this repo, identify reports `stack node` with `package.json` as its source and `up unknown`, and writes no file | Manual | Done | |
| P2-Q3 | A reloaded harness lists `sassy-overview` with no load warning, and a bare invocation answers as `mode:identify` | Manual | Done | |

### P3 — Make `detect.sh` hash the tree and ask identify

**Goal:** `--check` can prove the worktree mechanics are untouched, and the suite stops guessing stacks.

**Why this slice:** D4 and D6 are promises until `--check` enforces them, and P4's deletion is only safe once the whole tree is compared byte for byte.

**Review:** logic

**Work (vertical):**
- Replace the `worktree-version` header comparison with a hash of the installed file set, reusing the `skills-lock` machinery (`skills/sassy-setup/scripts/hash-skill.mjs`, golden vectors in `tests/sassy-setup-roster.sh`): any byte difference is `drift` with the file named.
- Report `worktrees.ports` as a removed key with the line that deletes it; keep a leftover key harmless.
- Replace the `:582` manifest loop with a call to the `sassy-overview` skill's `scripts/identify.sh`, keeping the alias note optional.
- Keep topology, config schema, pin drift, and roster untouched.

**Done when:** `--check` names the exact file when one byte of a single installed script changes, and no code in `detect.sh` enumerates a manifest by name.

#### QA — P3 (Manual)

| ID | Check | Mode | Status | Notes |
|----|-------|------|--------|-------|
| P3-Q1 | In a throwaway project, append a comment to `.sassywares/worktree/create` and `--check` reports drift naming that file; restore it and `--check` is clean | Manual | Done | |
| P3-Q2 | Adding `ports: 3000-3099` to that project's config makes `--check` report the removed key with its fix line | Manual | Done | |
| P3-Q3 | `bash tests/sassy-setup-roster.sh` still fails when a lock folder hash changes | Manual | Done | |

### P4 — Cut ports, preview, `stop`, and every dogfood dependency

**Goal:** `.sassywares/worktree/` holds four read-only scripts that know nothing but git and config.

**Why this slice:** it is the deletion D12 describes, and it removes the machinery every later phase would otherwise have to work around.

**Review:** logic

**Work (vertical):**
- Delete `skills/sassy-setup/assets/worktree/stop`.
- `_lib.sh`: remove `wt_claim`, `wt_has_ports`, `tcp_up`, `wt_live_port`, `_wt_preview_block`, `wt_preview`, `wt_preview_port`, `wt_verdict`, and the recipe lookup in `wt_flat`.
- `create`: no claim, no `WT_PORT`/`WT_BASE_URL`, no `--port`; `--env` prints `WT_PATH`, `WT_BRANCH`, `WT_SLUG`, `WT_NAMESPACE` only.
- `list`: branch · path · dirty · upstream; drop `--address` and `--preview`.
- `remove`: run the configured `down` first (exit `3` handshake when it names a skill), then delete; guards are dirty tree, unpushed commits, main checkout.
- `prune`: drop the released-port reporting.
- `sassy-worktree`: delete `references/preview.md`; strip preview/ports/address/recipe/verdict from `SKILL.md` and from `references/{create,list,remove,prune}.md`; delete the "when the two meet, they meet at the recipe" paragraph and the `Never production` rule, which only governed preview; keep `No verdicts` reworded to stand alone.
- Update `bin/release-ignore` only if the deletion changes the shipped set — it should not.

**Done when:** a freshly set-up project has four worktree scripts, and no file under `skills/sassy-worktree/` or `skills/sassy-setup/assets/worktree/` mentions a port, a preview, a recipe, or a verdict.

#### QA — P4 (Manual)

| ID | Check | Mode | Status | Notes |
|----|-------|------|--------|-------|
| P4-Q1 | In a throwaway project, `create` then `list` prints four columns and no address, and `create --env` prints exactly four `WT_*` lines | Manual | Done | |
| P4-Q2 | `grep -rin "port\|preview\|recipe\|verdict\|dogfood" skills/sassy-worktree skills/sassy-setup/assets/worktree` returns nothing | Manual | Done | |
| P4-Q3 | `remove` on a dirty checkout still refuses, and on a clean one deletes it and prints the branch it kept | Manual | Done | |
| P4-Q4 | `bash tests/worktree-create.sh` passes, still failing if `--no-track` is removed | Manual | Done | |

### P5 — Add `up:`/`down:` and wire setup to initialize them

**Goal:** A project declares how its stack starts and stops in two top-level keys, and setup leaves it with something real behind them.

**Why this slice:** this is the feature the whole plan exists for, and it is the last piece that needs identify — setup's probe is its second caller.

**Review:** logic

**Work (vertical):**
- Config: top-level `up:` and `down:`, each `<script> <args…>` or `<skill> <args…>`; documented in `references/config.md` with the supervisor contract (foreground, SIGTERM, reap children) and the `WT_SLUG`-derived port example. Wire the keys through `_lib.sh` so `remove` can resolve `down`.
- `sassy-setup` (init): probe with identify; when the project already has an answer, offer to point the keys at it (`up: just dev`); otherwise write `up`/`down` stubs at a probed path (`bin/`, `tool/`, `scripts/`) that `exit 1` naming the contract, and set both keys. Never edit them afterwards.
- Absent keys mean no lifecycle: say so plainly, never invent one.
- `sassy-worktree`'s `remove` uses the keys; nothing else reads them.

**Done when:** on a project with a `justfile`, setup offers `just dev` and writes no file; on a project with nothing, it writes two stubs, and running `up` in a checkout receives `WT_PATH`, `WT_BRANCH`, `WT_SLUG`, `WT_NAMESPACE`.

#### QA — P5 (Manual)

| ID | Check | Mode | Status | Notes |
|----|-------|------|--------|-------|
| P5-Q1 | Setup on a project with a `justfile` offers targeting it and writes nothing there | Manual | Done | |
| P5-Q2 | Setup on a project with no runner writes both stubs, and running `up` prints the contract with a non-zero exit | Manual | Done | |
| P5-Q3 | Running `up` inside a checkout sees all four `WT_*` values, and Ctrl-C stops it with nothing left holding the directory | Manual | Done | |
| P5-Q4 | `remove` on a checkout whose config names a `down` runs it before deleting | Manual | Done | |

### P6 — Sweep docs and tests to match

**Goal:** every document and test describes four scripts, two keys, and one overview skill — and nothing mentions what was deleted.

**Why this slice:** the cut is only finished when the story matches the code; a stale reference is how `preview` comes back.

**Review:** surface

**Work (vertical):**
- `skills/sassy-setup/references/worktree.md`: delete "Previewing a worktree", `stop`, the port rules, the recipe-derived address; state the collision honestly.
- `references/config.md`: drop `worktrees.ports`; add `up`/`down`.
- `references/init.md`: four scripts; the up/down probe; drop "the first preview will show it".
- `references/dogfood.md`: remove the `$WT_PORT` substitution and port-shaped `**Preview:**` examples — nothing else (F1 owns the rest).
- `README.md` (skill table, "Working in parallel" path contract, gates), `CONCEPTS.md`, `skills/sassy-setup/assets/sassywares-readme.md`, `.sassywares/README.md`.
- `tests/worktree-create.sh`: drop the three port assertions.
- `detect.sh`'s generated config template: no `ports` line.

**Done when:** `grep -rin "worktrees.ports\|WT_PORT\|mode:preview\|worktree/stop"` across the repo returns only this plan, `detect.sh`'s removed-key drift lines and the roster test case that proves them, and every test and `--check` passes.

#### QA — P6 (Manual)

| ID | Check | Mode | Status | Notes |
|----|-------|------|--------|-------|
| P6-Q1 | The README's worktree section lists four scripts and two keys, and reads correctly to someone who never saw the old version | Manual | Done | |
| P6-Q2 | The grep in "Done when" returns only this plan, `detect.sh`'s removed-key drift lines, and the roster test case that proves them | Manual | Done | |
| P6-Q3 | `bash tests/sassy-setup-roster.sh`, `bash tests/worktree-create.sh`, `bash skills/sassy-setup/scripts/detect.sh --root . --check` all pass | Manual | Done | |
