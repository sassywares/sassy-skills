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

- **Assume nothing.** Your inference is not a decision until the user confirms it. No silent defaults, no "I'll go with X unless you object". A branch is closed only when the user decided it, told you to use your recommendation, or chose to defer it — and each closure is recorded.
- **One question per turn.** Pick the single question whose answer unblocks the most of the tree. Stacked questions get diluted answers.
- **Always recommend.** Every question carries your recommended answer and why, so the user can confirm in one word. Recommending is not deciding.
- **Explore before asking.** If the codebase, config, docs, or a prior learning can answer it, look it up and show the answer with its `file:line` instead of asking. Ask only what the user alone can settle.
- **Push back.** Challenge thin reasoning, contradictions, and unexamined solution shapes with evidence. Disagree when you disagree. Concede only to an argument or to the user's explicit call — never to fatigue.
- **No exit with open branches.** "Settled enough" is not settled. The only exits are a ledger with zero open items or the user explicitly ending the interview, in which case every open item becomes a named, user-acknowledged assumption.

## Phase A — Grill

**Read `references/interview.md` first.** It is the decision-tree protocol, the pushback lenses, the coverage sweep, and the ledger format; this section is only the order.

1. **Frame.** Restate the goal in one or two sentences and ask the user to confirm or correct it. Ask what they are already thinking before offering your own ideas.
2. **Ground.** Use `sassy-scout` to ground the area: relevant files, existing patterns, prior art, and prior learnings. It writes a grounding brief and returns a gist plus the brief path; do not read the whole repo yourself. A relevant learning is a constraint — record it as a decision (`D3: …`) so the plan cites it; one that contradicts the user's direction is a pushback, raised now.
3. **Map the tree.** Lay out the decision tree — every branch you can see, in dependency order — as the open ledger, and show it. The user can add, cut, or reorder branches.
4. **Walk it.** Resolve branches one question per turn, parents before children. Each answer can open new branches; add them to the ledger as they appear. Apply the pushback lenses as gaps show up, not as a gauntlet.
5. **Approaches.** When a branch has more than one plausible direction, present 2–3 concrete approaches — at least one non-obvious — with trade-offs, all before your recommendation.
6. **Sweep.** Before declaring anything settled, run the coverage sweep: flows, states, edge and failure paths, permissions, data, integration seams, rollout, verification. Every item ends decided or marked not applicable with a reason. Then run the integration check for consequences of decisions combined.
7. **Read back.** Show the full ledger — decisions with provenance, constraints, non-goals, deferred items, assumptions — and ask the user to confirm it is complete and correct. A correction reopens that branch.

**UI work.** When a decision is about layout, navigation, states, flow, or interaction shape and the user asks to see it, read `references/sketches.md` and draw it. Say once, at the first such decision, that a sketch is available.

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

Decisions the user already made earlier in the conversation, with the trade-off in view, are settled: carry them forward and never re-ask. A bare assertion nobody examined gets exactly one challenge per `references/interview.md`.
