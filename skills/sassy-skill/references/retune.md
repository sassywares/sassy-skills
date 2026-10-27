# Mode: retune — the smallest fix for one named failure

Read the skill's shared sections first (locations, Agent Skills rules, shape rule, checklist). This file is the failure map.

## 1. Name the failure before touching anything

Read the skill and say which of these it is, in one line. "It feels long" is not a failure; "it fires on status moves too" is.

## 2. Failure → smallest fix

| Named failure | The fix |
|---|---|
| **Won't trigger** | Rewrite the description: what + when, concrete verbs, the user's own words. Not the body. |
| **Fires when it shouldn't** | Tighten the description's *when* half, or add `disable-model-invocation: true` if it is an explicit-only skill. |
| **One path's rules bleed into another's** (a mode doing the neighbouring mode's job) | A shape bug, not a wording bug: split the divergent outcomes into `references/`, one file per path, and give the body a dispatch table naming exactly one file per mode. Rewording the paragraph does not fix adjacency. |
| **Too long / bloated** | Extract conditional content to `references/`, or delete what never gets used. Never delete a hard rule to save lines. |
| **Wrong or stale steps** | Correct the workflow against the current tree — read the files the steps name before trusting them. |
| **Wrong scope** | Move it between internal, project, and user. Moving into the suite is a release; moving out means the next release drops the skill for everyone. |
| **Oversplit** (five topic files, vague routing) | Fold shared surfaces back into the body and keep one reference per outcome. |

If the request names no failure, ask for one. A retune without a failure is a rewrite with extra steps.

## 3. Change that thing only

- One failure, the smallest edit that kills it, no drive-by rewrites or tidy-ups.
- Re-read the surrounding lines so the fix does not contradict a rule elsewhere in the file.
- If the fix moves content into `references/`, the body must dispatch to it by name and say to read only that one.

## 4. Ship and re-verify

- Internal skill → `scripts/sync.sh` (commit, bump, tag, publish; say so before running it).
- Project or user skill → committed or written in place, as its location requires.
- Then run the skill's Verification section: reload, no load warning, invoking it behaves. A retune that was never invoked has not been verified.
