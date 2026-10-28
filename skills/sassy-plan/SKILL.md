---
name: sassy-plan
description: >-
  Grill the user relentlessly about a piece of work, walking every branch of the
  decision tree until nothing is assumed or open, then let the user choose:
  write a plan document, start working now, or take it all the way to a PR.
  Sketches UI on request. No modes, no QA flags. Use when asked to brainstorm,
  scope, plan, or create a phased plan.
argument-hint: "[feature description, requirements, or idea to scope]"
disable-model-invocation: true
---

# Sassy Plan

**Outcome:** a decision ledger with zero open items — every branch of the work resolved by the user, explicitly delegated by them, or explicitly deferred by them — then the user's explicit choice from three options: write a plan document, start working now, or take it all the way to a PR.

**Does not implement.** Planning never implements. Execution belongs to `sassy-work` or `sassy-lfg`, and only after the user picks.

**Config.** Resolve `.sassywares/config.yaml` (nearest, walking up) per the `sassy-setup` skill's `references/config.md`. Precedence: explicit token > session instruction > config > skill default. Plans land in `artifacts.plans`.

**Harness.** Loading another skill, dispatching an agent, and any command you hand the user follow the `sassy-setup` skill's `references/harness.md`. Read it once per run, before the first of those.

## Hard rules

- **Assume nothing.** Your inference is not a decision until the user confirms it. No silent defaults.
- **One question per turn, always with your recommended answer.** Recommending is not deciding.
- **Explore before asking.** What the repo can answer, look up and cite.
- **Push back** with evidence. Concede to an argument or the user's explicit call, never to fatigue.
- **No exit with open branches.** Only a ledger with zero open items, or the user explicitly ending the interview, reaches the picker.

## Phase A — Grill

**Read `references/interview.md` first.** It owns the ledger, how to ask, the pushback lenses, the coverage sweep, and the read-back; this is only the order.

1. **Frame.** Restate the goal in one or two sentences; ask the user to confirm or correct it, and what they are already thinking.
2. **Ground.** Use `sassy-scout` on the area; it returns a gist and a brief path. A relevant prior learning becomes a decision the plan cites, or a pushback if it contradicts the user's direction.
3. **Map.** Show the decision tree as the open ledger, in dependency order. The user can add, cut, or reorder.
4. **Walk.** Resolve branches parents first, adding new ones as answers open them. Where a branch has several plausible directions, present 2–3 approaches — one non-obvious — before recommending.
5. **Sweep and read back.** Run the coverage sweep and integration check, then the read-back.

**UI work.** At the first layout, state, flow, or interaction-shape decision, say once that you can sketch it; when the user asks, read `references/sketches.md`.

## The picker

Only when the read-back is confirmed with zero open items, present exactly these three options and stop until the user picks. Do not recommend one.

```text
Settled. Pick one:
1. Write it to <artifacts.plans>/<slug>.md
2. Start working now — stop before ship
3. Take it all the way — run it, ship it, babysit the PR
```

The user must pick explicitly. There is no default and no auto-selection. If no human is present to answer (rare, e.g. a scripted invocation), take option 2 and say so; every branch you resolved without the user is recorded as an assumption, never as a decision.

### Option 1 — Write the plan

Read `references/plan-format.md` and write the plan, including the per-phase manual QA tables that format defines. Then report the absolute path and STOP. No second menu, no "what next" prompt. Do not implement or commit.

### Option 2 — Start working now

Load the `sassy-work` skill with the settled brief as the work brief and its decisions / done-when as the intent reference. No plan file is written. It stops before ship.

### Option 3 — Take it all the way

Load the `sassy-lfg` skill the same way: the settled brief as the work brief, its decisions / done-when as the intent reference. No plan file is written.

## QA

The plan document carries manual QA tables per `references/plan-format.md`. Those rows gate phase completion: a phase is `Done` only when the code is approved and every row passed, with the user running the checks. The in-context brief has no QA table, so its gate is code approval alone. Omit QA tables only when the user explicitly asks to skip QA in plain language.

## Resume

If the user points at an existing sassy plan, update phases and tables in place. If they point at a raw plan from elsewhere, reshape it into this format without discarding its settled decisions — but grill whatever it leaves open or merely asserts. An existing plan is already the document.

Decisions already settled earlier in the conversation carry forward per `references/interview.md`; never re-ask them.
