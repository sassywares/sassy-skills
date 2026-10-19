---
name: sassy-scout
description: >-
  Scout an area of the repo on demand and write the shared grounding brief other
  agents read, so nothing downstream re-explores the same code. Returns a short
  gist plus the brief path, never a wall of file contents. Use when a plan, fix,
  or review needs verified project evidence before it starts.
argument-hint: "[the area or question to ground]"
disable-model-invocation: true
---

# Sassy Scout

**Outcome:** a grounding brief on disk for the area you asked about, and a 3–5 line gist back in this context. Nothing else.

**Orchestrator only.** Do not read the repo yourself. One `scout` dispatch per independent area, in parallel when the areas do not overlap.

## When to use

- Before planning a change, to ground files, patterns, and prior art.
- Before a fix, to ground the failure surface once instead of twice.
- Before a review of unfamiliar code, when the diff alone is not enough.
- Whenever more than one agent is about to explore the same area.

## Workflow

1. **Scope.** Reduce the request to one question the brief will answer, in one line. If it is really two questions, use two dispatches.
2. **Dispatch `scout`** with that scope, what the caller intends to do with it, and the paths or areas you already suspect.
3. **Keep the gist.** Read the returned gist; do not pull the brief's bulk into this context.
4. **Report the brief path** to the caller, so downstream agents read it instead of scouting again.

## The brief

The scout writes it under a per-user temp directory, keyed by the worktree root:

```bash
ROOT="/tmp/pi-grounding-$(id -u)"
ROOT_ABS=$(cd "$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")" && pwd -P)
KEY=$(printf '%s' "$ROOT_ABS" | shasum -a 256 | cut -d' ' -f1)
BRIEF="$ROOT/$KEY.md"
```

It is fresh only while its `head` and `dirty` lines match the working tree. After any commit or edit, re-scout.

## Hard rules

| Rule | Requirement |
|------|-------------|
| One question | A brief answers one scoped question. Split, do not sprawl. |
| Gist only | Return the gist and the brief path. Never paste the brief. |
| No edits | Scouting is read-only. It never changes code or commits. |
| Fresh or re-scout | A stale brief is worse than none. Check the header before reusing it. |
