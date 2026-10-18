---
name: sassy-handoff
description: >-
  Create a continuity handoff and continue the work in a fresh session, using the
  /handoff extension. Use at a phase boundary, when context is getting long, or
  when the user asks to hand off. Interactive TUI only.
argument-hint: "[goal for the next session] [mode:review|pipeline]"
disable-model-invocation: true
---

# Sassy Handoff

**Outcome:** the current session is summarized into a focused continuation prompt, and a fresh session opens with it — reviewed and submitted by the user in `mode:review` (default), or actively continued in `mode:pipeline`.

**Modes.** `mode:review` (default) asks: the generated prompt opens in an editor, then the new session starts with it in the editor for the user to review and submit. `mode:pipeline` is non-interactive: the prompt is sent immediately as the new session's first turn.

**How this works:** the `/handoff` extension from `@sassywares/pi-extensions` performs the session replacement. A skill cannot start or replace a session — that operation is command-only in pi — so this skill prepares the handoff and gives you the exact command to run. Running it is the whole action; the summarization, the fresh session, and (in `mode:pipeline`) the first turn are all automatic.

## Steps

1. **Determine the continuation goal.**
   - At a sassy plan phase boundary: the next phase that is not `Done`, as `/skill:sassy-work <plan> phase:<n>`.
   - After a `sassy-plan mode:pipeline` run: continue from its in-context brief. There is no plan path; carry the goal, decisions, constraints, and done-when in the handoff goal itself.
   - Otherwise: the user's stated objective for the next session.
   - If the goal is genuinely unclear, ask. Do not fabricate a handoff.

2. **Save state before switching.** The new session cannot see this one except through the prompt, so:
   - Update the plan's Phase tracking (and any other source-of-truth file).
   - Confirm nothing that matters exists only in this conversation.
   - Redact secrets, credentials, and unrelated personal data.

3. **Emit the exact command.** One fenced, copyable block:

   ```text
   /handoff [mode:review|pipeline] <goal>
   ```

   For a plan phase, make it self-contained:

   ```text
   /handoff mode:pipeline Execute phase <next> of <plan>. Run /skill:sassy-work <plan> phase:<next>
   ```

4. **Say what will happen.** In `mode:pipeline` the fresh session starts the work immediately. In `mode:review` (default) the generated prompt is placed in the new session's editor for you to review and submit.

## Rules

- **Pointer-first.** Name the plan path, phase, key files, and decisions rather than reproducing them. The plan is the source of truth; the handoff points at it.
- **No duplicate doc.** The extension carries the context into the new session; do not also write a handoff markdown unless the user asks for one.
- **No plan file.** When the work was kept in context (`mode:pipeline`), the fresh session cannot see this conversation or point at a plan. Include the compact brief in the handoff goal.
- **Do not invent a continuation.** If the next step is a real fork with mutually exclusive options, present them; do not silently pick.
- **The skill does not switch sessions.** Never claim it did; the user runs `/handoff`.

## Requirements

- Interactive TUI mode (the extension refuses otherwise).
- A selected model (the extension uses it to write the summary).
