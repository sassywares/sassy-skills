# Mode: check — lint the setup, print the last verdict, change nothing

Read the shared sections in `SKILL.md` first. This file is the check path only, and it is four lines long for a reason.

1. **Lint.** Run the `sassy-setup` skill's `scripts/detect.sh --root <path> --check` and report the `dogfood` and recipe lines verbatim.
2. **Report the last run.** Print the newest report's `status`, `class`, and timestamp, or that there is none. Read the summary only — never a step log.
3. **Name the fix, don't make it.** Drift and a missing recipe are reported with the mode that fixes them: a skeleton or a stale procedure is `mode:discover`, and a config that forbids runs is `sassy-setup mode:init`.
4. **Write nothing.** No report directory, no recipe edit, no config edit. A check that "just fixes a line while it is there" has become a discover run without the evidence to earn it.

| Rule | Requirement |
|------|-------------|
| Check writes nothing | Verdicts come from a `run`, procedures from a `discover`, config from `sassy-setup mode:init`. Check only reports. |
