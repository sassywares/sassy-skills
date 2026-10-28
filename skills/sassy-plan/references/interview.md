# Interview protocol

Read this before the first question. It is how Phase A grills: the ledger, the question discipline, the pushback lenses, and the coverage sweep that has to come back clean before the picker.

## The ledger

The ledger is the decision tree made visible. Keep it current and show it whenever it changes shape — at the map, after a branch opens new children, and at the read-back.

```text
Open
- O1: Who can send invitations? (blocks O3)
- O2: What happens when the invitee already has an account?
- O3: Can an admin revoke a pending invite? (needs O1)

Settled
- D1: Invites expire after 7 days (user-directed, over "never expire": stale links leak access)
- D2: Reuse the existing mailer (from code: src/mail/send.ts:12)

Deferred
- F1: Bulk CSV invites — next phase (user-deferred)

Assumptions
- A1: Single workspace per invite (user-delegated: "use your call")
```

Every item closes into exactly one bucket, with provenance:

| Provenance | Meaning |
|---|---|
| `user-directed` | The user chose against or between options you surfaced. Name the rejected option and the reason. |
| `user-approved` | You recommended with the trade-off shown; the user agreed. |
| `user-delegated` | The user explicitly said to use your recommendation. Lands in Assumptions so it stays visible. |
| `user-deferred` | The user chose to decide later. Lands in Deferred, with when or by whom. |
| `from code` | The repo answered it. Cite `file:line`. Shown to the user, never closed off-screen. |

Decisions the user made earlier in the conversation with the trade-off in view enter the ledger as settled, with their provenance — never re-ask them. Nothing you inferred alone gets a label. "Sounds good" to a passing mention is at most `user-approved`, never `user-directed`. If you cannot name what an item was chosen over, it was not examined — it is still open.

## Asking

- **One question per turn**, the one that unblocks the most of the tree. Parents before children: do not ask how revocation works before you know who can invite.
- **Recommend every time.** State your answer and the one reason that matters here. The user confirms in a word or overrides.
- **Prefer a choice when real options exist.** Use the harness's blocking question tool if it has one (`AskUserQuestion` in Claude Code, `ask_user` in pi); otherwise give numbered options in chat. Put your recommendation first and say so. Use an open question when the answer is a story — evidence, current workaround, who the user is — or when you could not write 2–4 distinct, defensible options without padding.
- **Be concrete.** Name the scenario. "When the invitee's email already belongs to a member of another workspace, do we merge, reject, or add a second membership?" — not "what about existing users?".
- **Explore first.** Anything the repo can answer, look up. Show the found answer and its citation as settled ground so the user can object; do not spend a turn on it.

## Pushback

You are a thinking partner, not a form. Raise each lens as its gap appears, one probe per gap, folded into the walk — never as an up-front checklist. A crisp opening may earn none; a fuzzy one earns several.

- **Evidence.** The need is asserted, not shown. Ask for the most concrete thing someone has already done about it — time spent, a workaround built, a complaint filed.
- **Specificity.** The user is "users". Ask for a specific person or narrow segment and what changes for them when this ships.
- **Counterfactual.** Ask what people do today when this comes up, and what it costs them if nothing ships.
- **Attachment.** The request names a solution shape, not the value it delivers. Ask for the smallest version that still delivers that value, and offer one.
- **Contradiction.** Two answers conflict, or an answer conflicts with the code, a convention, or a prior learning. Quote both sides and ask which wins.
- **Directive.** A bare "do it with X" that nobody examined gets exactly one challenge, backed by evidence: what X costs here and the strongest alternative. Whatever the user then chooses is settled — do not re-litigate it.
- **Scope creep.** A "while we're at it" addition gets the same scrutiny as the core: does it need to ship with this, or is it a deferred item?
- **Higher-upside option.** When an adjacent reframing would make the work clearly more valuable without much carrying cost, put it on the table as a challenger, not a default.

**Can't evaluate vs hasn't decided.** If the user answers "I don't know" or "whatever you think" twice in a row on territory they can't judge, stop asking naked questions. Map that territory instead: 3–7 decisions or hazards, each with the realistic options, the trade-off that matters here, and your recommendation. Then ask which they want to walk through. Anything they skip becomes `user-delegated` — written down, never silently assumed. A user who understands the options but hasn't picked gets the normal question, not a lecture.

## Coverage sweep

Before the read-back, walk this list against the settled tree. Every applicable row needs a decision; every other row needs "N/A — <reason>" said out loud. Do not skip a row silently. Ask about the gaps one at a time, as usual.

| Area | Questions it forces |
|---|---|
| Actors | Who uses it, who administers it, who must never reach it? |
| Flows | For each journey: entry point, decision points, happy path, every terminal state (success, error, cancel, timeout). |
| States | Empty, loading, partial, error, success, stale, offline — which exist and what each shows. |
| Edge and failure paths | Bad input, duplicates, limits, rate limits, retries, partial failure, concurrency, a dependency down. |
| Permissions | Role boundaries, ownership, what each role sees and can do. |
| Data | New or changed shapes, migration, backfill, backward compatibility, retention, deletion. |
| Integration seams | Every place this touches existing features — what each handoff expects. |
| Non-functional | Performance, security, privacy, accessibility, i18n — only where they bear on this work. |
| Rollout | Flag or not, order of release, rollback, who is told. |
| Verification | Done-when for the whole and per slice; what the user will check by hand. |
| Non-goals | What this deliberately does not do, so the work cannot drift into it. |

**Integration check.** Then combine what was decided and look for consequences no single answer showed: "invites expire in 7 days (D1) and revoking deletes the record (D4), so a revoked link and an expired link show the same error — intended?" One probe per real combined effect.

**Implementation-time unknowns** — exact helper names, final query shape, anything only touching the code can answer — are not open branches. Name them in Deferred as implementation-time, with the user's agreement, so they are visible rather than pretended away. Anything that would change behavior, scope, or the done-when is not an implementation detail; it gets asked.

## Read-back

Show the whole ledger: decisions with provenance, constraints, non-goals, deferred items, assumptions — and an empty Open bucket. Ask one question: is this complete and correct? A correction reopens that branch and the walk resumes there. Only a confirmed read-back with zero open items reaches the picker.

If the user ends the interview early, every open item moves to Assumptions with your recommended answer, the user sees that list, and the picker follows. That is their explicit call, not your shortcut.
