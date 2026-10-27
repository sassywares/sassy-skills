# Harness conventions

The suite runs in any harness that loads Agent Skills — pi, Claude Code, and others. No skill assumes one. When a skill says to load a skill, dispatch an agent, or hand the user a command, this file is how.

## Loading a skill

"Load the `sassy-x` skill and follow it" means: read `sassy-x/SKILL.md` from the same skills directory as the skill you are running (its sibling, `../sassy-x/SKILL.md`), then follow it. "The `sassy-x` skill's `references/y.md`" is `../sassy-x/references/y.md`.

Read the file; do not rely on the harness's skill-invocation tool. Suite skills set `disable-model-invocation: true`, and some harnesses (Claude Code) enforce that by hiding them from the model entirely. Reading the sibling file works everywhere.

A missing sibling means the suite is incomplete: stop and point at `sassy-setup`.

## Dispatching an agent

"Dispatch a `worker`" (or `scout`, `reviewer`, `validator`) means: start that [sassy-agents](https://github.com/sassywares/sassy-agents) subagent by name through the harness's own mechanism — the `subagent` tool in pi, the Agent tool with that agent type in Claude Code. "In parallel" means several dispatches in one turn.

- **Agent not installed** — stop and point at `sassy-setup`, which installs the roster for the running harness. Never substitute a generic agent silently.
- **Cannot dispatch** — you are yourself a subagent and the harness does not let subagents dispatch (Claude Code), or the harness has no subagents at all. Do that step inline with the same brief and constraints, and say in your result that it ran inline. Never skip it.

## Commands the user types

Skills tell the user what to run next. Write the command for the harness you are running in:

| Harness | Invoke a skill | Pick up new or changed skills and agents |
|---|---|---|
| pi | `/skill:<name> <args>` | `/reload` |
| Claude Code | `/<name> <args>` | restart the session |

For any other harness, give the skill name and its arguments and let the user invoke it their way.

## Temp files

Every file a skill or agent writes outside the repo goes under **`/tmp/sassywares/<harness>/<purpose>/`** — never loose in `/tmp`, never inside the working tree. Each harness gets its own folder; the harness is detected from its environment (`CLAUDECODE` → `claude`, `PI_CODING_AGENT` → `pi`, else `other`), and `SASSY_HARNESS` overrides it. Directories are `0700`; a symlinked directory, or a `/tmp/sassywares` owned by someone else, aborts rather than being followed.

```bash
SW=/tmp/sassywares
HARNESS="${SASSY_HARNESS:-$(if [ -n "${CLAUDECODE:-}" ]; then echo claude; elif [ -n "${PI_CODING_AGENT:-}" ]; then echo pi; else echo other; fi)}"
DIR="$SW/$HARNESS/<purpose>"
for d in "$SW" "$SW/$HARNESS" "$DIR"; do [ -L "$d" ] && { echo "unsafe symlink: $d" >&2; exit 1; }; done
(umask 077; mkdir -p "$DIR")
[ -O "$SW" ] || { echo "not owned by you: $SW" >&2; exit 1; }
```

| Purpose | Folder | Written by |
|---|---|---|
| Grounding briefs | `grounding/` | `scout` (read by every agent) |
| Handoff files | `handoffs/` | `sassy-handoff` |
| Commit messages | `commits/` | `sassy-commit` |
| PR bodies | `prs/` | `sassy-commit-push-pr` |
| Anything else — clones, captured output, drafts | `scratch/` | any skill or agent |

Name files so a run can find its own: a UTC timestamp plus a short slug (`20261027T101500Z-fix-checkout.txt`). Delete scratch you no longer need; `/tmp` clearing on reboot covers the rest. A new purpose gets a new row here, not a new top-level folder.
