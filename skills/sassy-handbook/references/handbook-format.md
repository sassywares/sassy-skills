# Handbook format, diagrams, and voice

Read this before writing a handbook.

## Handbook shape

Drop sections that would be empty.

```markdown
# <Title in plain language>

**As of:** YYYY-MM-DD
**Audience:** <who should read this>

One or two sentences: what this handbook is for.

## 1. What this covers
The outcome, and what is true today vs still planned.

## 2. Mental model
| Term or idea | Meaning |
| ------------ | ------- |
| …            | …       |

<Optional mermaid diagram of how the pieces fit.>

## 3. What already landed
Work actually in the tree. If nothing has shipped, say so and point at the contract as the target.

## 4. The contract (rules to keep)
Numbered durable decisions, written so someone can apply them without reading the plan.

## 5. How to continue / enroll the next piece
Ordered checklist with concrete paths. For multi-slice work, use a simple status table (Not started / In progress / Done) — never a QA gate table.

## 6. Code map
| Concern | Where |
| ------- | ----- |
| …       | `path/…` |

## 7. Quick checks
What a human should verify in the app or with a quick search. No agent-command names.

## 8. Do not
Short negative list.

## 9. Still open
Deferred work and known gaps.

## 10. Related docs
Links to the plan and any deeper docs. Link, do not copy.
```

## Mermaid diagrams

Add a diagram where it explains the system faster than prose:

- `flowchart` — the main flow, or how a request moves through the system
- `sequenceDiagram` — interactions between components
- `stateDiagram-v2` — a lifecycle or status model
- `erDiagram` — data relationships

Keep each small: only the key paths. Use plain node names that match the code map. One or two strong diagrams beat five weak ones. Verify the syntax renders; a broken diagram is worse than none.

## Voice

**Do:** short sentences; real paths (`apps/dev/lib/communities/use-community-detail.ts`); honest status ("not started", "wrapper still returns old-shaped fields").

**Do not:** name skills, slash-commands, or personal setups; paste plan IDs and phase tables as the main text; claim code is done when the tree still has the old shape; write for "the next agent" — write for the next teammate.
