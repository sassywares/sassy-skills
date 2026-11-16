# Mode: preview — bring a checkout up, and leave it up

Read the shared sections in `SKILL.md` first. This file is the preview path only. Preview has no script of its own: it runs the recipe. `stop` is the script that reaps it.

1. **Resolve the target and the section.** `preview <slug>` uses that checkout; with none, ask which. `section:<name>` names a dogfood recipe section; with none, use the first.
2. **Read the recipe** at `dogfood.recipe`. Two things stop the run, and both are reported rather than worked around: no recipe (the project has no stored procedure — say to run `sassy-dogfood mode:discover`), or the section has no `Prove it:` step (nothing marks where bringing-up ends).
3. **Preflight the session.** If the recipe's *Working in a second checkout* or *Set up once* names a session artifact and `.sassywares/session/` in **that checkout** is empty, that is `class: env`: report it with the line that fixes it and stop. Never open a logged-out app and call it a preview — the human will read the login screen as a broken build.
4. **Run the bring-up.** In `WT_PATH`: the recipe's *Set up once* when the checkout is cold (no `.env`, no installed deps), then the section's steps in order **up to but not including** its `Prove it:` step. Judge each step by its `Expect`. A failure stops the preview and is reported with the step id and its output tail — a preview that half-started is not a preview.
5. **Leave it running and report how to see it.** `list --preview <slug>` prints the recipe's `**Preview:**` line with the namespace substituted — the *result*, a URL or a simulator name or a window, never the command that started it. Print exactly that; never build an address yourself, and never assume one is a URL. When the project has ports and the preview answers on one, say it is up; when it does not, say it is running and that stopping it is the project's job.
6. **To stop it,** run `.sassywares/worktree/stop <slug>`. It kills whatever answers on the address this checkout advertises — its claimed port, or the port its preview line names — so it works for a project with no port resource too. A preview that names no port at all is the project's to stop, and it says so.

Preview never judges the work, never writes a report, never commits, and never returns a verdict. If the user wants to know whether it *works*, that is `sassy-dogfood mode:run`.

| Rule | Requirement |
|------|-------------|
| A preview is not a URL | How to see a checkout is the recipe's preview line. A port is one resource among several; a mobile app's preview is a simulator, and this skill must not invent a URL for it. |
| Preview is a promise | Report a URL only when something answers on it. A half-started app is a failure with a step id, not a preview — and an app without a port gets its preview line, not a fabricated address. |
