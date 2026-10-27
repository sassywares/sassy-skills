---
name: sassy-handoff
description: >-
  Write a self-contained handoff file to a temp directory so a fresh session —
  in any harness — can continue the work, then give the user its path and a
  one-line prompt to paste. Use at a phase boundary, when context is getting
  long, or when the user asks to hand off.
argument-hint: "[goal for the next session]"
disable-model-invocation: true
---

# Sassy Handoff

**Outcome:** a handoff file on disk that a fresh session can act on with no access to this one, plus its absolute path and a paste-ready prompt for the user. This skill never starts or replaces a session; the user does.

**Harness.** Commands you hand the user, and the temp-file rules, follow the `sassy-setup` skill's `references/harness.md`.

## Steps

1. **Determine the continuation goal.**
   - At a sassy plan phase boundary: the next phase that is not `Done`, continued by invoking `sassy-work <plan> phase:<n>`.
   - After a `sassy-plan` run that kept the work in a brief instead of writing a plan: continue from that brief. There is no plan path, so the brief itself — goal, decisions, constraints, done-when — goes in the file.
   - Otherwise: the user's stated objective for the next session.
   - If the goal is genuinely unclear, ask. Do not fabricate a handoff.

2. **Save state before writing.** The new session sees only the file, so:
   - Update the plan's Phase tracking (and any other source-of-truth file).
   - Confirm nothing that matters exists only in this conversation.
   - Redact secrets, credentials, and unrelated personal data.

3. **Write the file.** One file per handoff, under the harness's handoff directory:

   ```bash
   DIR="/tmp/sassy-handoff-$(id -u)/<harness>"   # pi, claude, … — the harness you are running in
   [ -L "/tmp/sassy-handoff-$(id -u)" ] && { echo "unsafe symlink" >&2; exit 1; }
   (umask 077; mkdir -p "$DIR")
   FILE="$DIR/$(date -u +%Y%m%dT%H%M%SZ)-<kebab-goal>.md"
   ```

   Use this shape, and keep every section short:

   ```md
   # Handoff: <goal in one line>

   - **Repo / cwd:** <absolute path> · **Branch:** <branch> @ <short sha> · **Written:** <ISO time>
   - **Plan:** <plan path + next phase, or "none — brief below">

   ## Goal
   What the next session must achieve, and its done-when.

   ## State
   What is done, what is in progress, what is untouched. Uncommitted work, if any, named by path.

   ## Decisions
   Settled choices (`D1: …`) with the reason, so the next session does not reopen them.

   ## Key files
   `path:line` — why it matters. Pointers, not contents.

   ## Next steps
   1. The first concrete action, including the exact skill invocation when one applies.

   ## Open questions and risks
   Anything unresolved, and anything the next session must not do.
   ```

4. **Hand it to the user.** Report the absolute path, then one fenced, copyable prompt for the fresh session:

   ```text
   Read <absolute path> and continue from it.
   ```

   Tell them to start a fresh session in their harness and paste it. When the next step is a skill, the file's **Next steps** names the invocation in that harness's syntax.

## Rules

- **Pointer-first.** Name the plan path, phase, key files, and decisions rather than reproducing them. The plan is the source of truth; the file points at it.
- **Self-contained.** The fresh session cannot see this conversation. When there is no plan file, the brief goes in the handoff file in full.
- **Outside the repo.** The file lives in the temp directory only — never committed, never inside the working tree. `/tmp` clearing on reboot is the intended lifetime.
- **Do not invent a continuation.** If the next step is a real fork with mutually exclusive options, list them under **Next steps**; do not silently pick.
- **The skill does not switch sessions.** Never claim it did; the user starts the fresh session.
