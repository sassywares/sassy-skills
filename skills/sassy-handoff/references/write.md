# Mode: write — capture the session for a fresh one

1. **Determine the continuation goal.**
   - At a sassy plan phase boundary: the next phase that is not `Done`, continued by invoking `sassy-work <plan> phase:<n>`.
   - After a `sassy-plan` run that kept the work in a brief instead of writing a plan: continue from that brief. There is no plan path, so the brief itself — goal, decisions, constraints, done-when — goes in the file.
   - Otherwise: the user's stated objective for the next session.
   - If the goal is genuinely unclear, ask. Do not fabricate a handoff.

2. **Save state before writing.** The new session sees only the file, so:
   - Update the plan's Phase tracking (and any other source-of-truth file).
   - Confirm nothing that matters exists only in this conversation.
   - Redact secrets, credentials, and unrelated personal data.

3. **Write the file** in the shape `SKILL.md` defines, one file per handoff. Create the directory with the `sassy-setup` skill's `references/harness.md` snippet, `<purpose>` = `handoffs`, then:

   ```bash
   FILE="$DIR/$(date -u +%Y%m%dT%H%M%SZ)-<kebab-goal>.md"
   ```

   Fill **Done** with the *why*, not just the what: the next session reads it to understand the work, not to replay it. Keep every section short. When there is no plan file, the brief goes in the file in full — the fresh session cannot see this conversation.

4. **Hand it to the user.** Report the absolute path, then one fenced, copyable command in the running harness's syntax (per `references/harness.md`):

   ```text
   /sassy-handoff mode:read <absolute path>          # Claude Code
   /skill:sassy-handoff mode:read <absolute path>    # pi
   ```

   Print only the line for the harness you are in. Tell the user to start a fresh session and run it.

## Rules

- **Do not invent a continuation.** If the next step is a real fork with mutually exclusive options, list them under **Next steps**; do not silently pick.
- **No duplicate doc.** Write only the handoff file — no second markdown in the repo unless the user asks.
