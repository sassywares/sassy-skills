#!/usr/bin/env node
// Verify the vendored suite skill folders against skills-lock.json.
//
// The suite installs in one of two scopes, like the agents: the project
// (vendored into .agents/skills and pinned in skills-lock.json) or the user
// (~/.agents/skills, plus ~/.claude/skills for Claude Code). Only a project
// install has a pin to verify; a user install is reported, and a missing suite
// is reported without counting as drift.
//
// Read-only, offline. The folder hash is the `skills` CLI's own definition
// (./hash-skill.mjs), so "identical to the pin" is a fact this script asserts,
// not a claim the agent has to make in prose. Both hash eras are live — the
// lock's version names the one it was written with — so the definition that
// version names is tried first and the other second. Trying both cannot hide an
// edited folder: edited bytes match neither.
//
// Usage: lockcheck.mjs [--root DIR] [--roster a,b,c]
// A suite skill is a name in --roster (assets/roster in sassy-setup); without
// one, any name starting with `sassy-`.
// Prints "<drift|note>\t<message>" per finding and always exits 0: the caller
// owns the verdict and the formatting.

import { existsSync, readdirSync } from "node:fs";
import { readdir, readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";

import { hashSkillFolder } from "./hash-skill.mjs";

const SUITE = "sassywares/sassy-skills";

let roster = null; // suite skill names (--roster a,b,c); null falls back to the sassy- prefix
const isSuite = (name) => (roster ? roster.has(name) : /^sassy-/.test(name));

const argv = process.argv.slice(2);
let root = process.cwd();
for (let i = 0; i < argv.length; i += 1) {
  if (argv[i] === "--roster") {
    const names = (argv[i + 1] ?? "").split(",").filter(Boolean);
    roster = names.length > 0 ? new Set(names) : null;
    i += 1;
  } else if (argv[i] === "--root") {
    root = argv[i + 1];
    i += 1;
  }
}

const lines = [];
const drift = (message) => lines.push(`drift\t${message}`);
const note = (message) => lines.push(`note\t${message}`);

// suite skills in a skills directory. Follows symlinks: a user scope may link
// each skill to a working copy rather than holding the files.
function suiteIn(dir) {
  if (!existsSync(dir)) return [];
  return readdirSync(dir).filter(
    (name) => isSuite(name) && existsSync(join(dir, name, "SKILL.md")),
  );
}

async function main() {
  const lockPath = join(root, "skills-lock.json");
  if (!existsSync(lockPath) && suiteIn(join(root, ".agents", "skills")).length === 0) {
    const userScope = [join(homedir(), ".agents", "skills"), join(homedir(), ".claude", "skills")]
      .map((dir) => [dir, suiteIn(dir).length])
      .filter(([, count]) => count > 0);
    if (userScope.length > 0) {
      const where = userScope.map(([dir, count]) => `${dir} (${count})`).join(", ");
      note(`suite installed in user scope: ${where} — this project does not pin it`);
    } else {
      note(`suite not found in the project or user scope — sassy-setup mode:init installs it`);
    }
    return;
  }
  if (!existsSync(lockPath)) {
    drift(`suite skill folders in .agents/skills but no skills-lock.json — re-pin with npx skills add ${SUITE}`);
    return;
  }

  let lock;
  try {
    lock = JSON.parse(await readFile(lockPath, "utf8"));
  } catch {
    drift(`skills-lock.json is not valid JSON — re-install with npx skills add ${SUITE}`);
    return;
  }

  const pinned = Object.entries(lock.skills ?? {}).filter(
    ([name]) => isSuite(name),
  );
  if (pinned.length === 0) {
    drift(`skills-lock.json pins no suite skill — install with npx skills add ${SUITE}`);
    return;
  }

  const suite = join(root, ".agents", "skills");
  if (!existsSync(suite)) {
    drift(`no .agents/skills — the vendored copies are missing; install with npx skills add ${SUITE}`);
    return;
  }

  // The lock's version names the hash era; the other era is the fallback.
  const legacyFirst = Number(lock.version) === 1;
  const installed = (await readdir(suite, { withFileTypes: true }))
    .filter((entry) => entry.isDirectory() && isSuite(entry.name))
    .map((entry) => entry.name);
  const installedNames = new Set(installed);
  const pinnedNames = new Set(pinned.map(([name]) => name));
  let matched = 0;
  let otherEra = 0;

  for (const [name, entry] of pinned) {
    if (!installedNames.has(name)) {
      drift(`vendored ${name} is missing from .agents/skills — re-install with npx skills add ${SUITE}`);
      continue;
    }
    const dir = join(suite, name);
    if ((await hashSkillFolder(dir, legacyFirst)) === entry.computedHash) {
      matched += 1;
      continue;
    }
    if ((await hashSkillFolder(dir, !legacyFirst)) === entry.computedHash) {
      matched += 1;
      otherEra += 1;
      continue;
    }
    drift(`${name} does not match the pin — edited locally or half-installed; re-install, or re-pin with npx skills add ${SUITE}`);
  }

  for (const name of installed) {
    if (!pinnedNames.has(name)) {
      drift(`${name} is installed but not pinned in skills-lock.json — npx skills add ${SUITE} pins it`);
    }
  }

  if (matched > 0) {
    note(`${matched}/${pinned.length} suite skill folders match skills-lock.json byte for byte`);
  }
  if (otherEra > 0) {
    note(`${otherEra} of them matched the other skills-lock hash era — the next npx skills add ${SUITE} migrates the lock`);
  }

  const sources = [...new Set(pinned.map(([, entry]) => String(entry.source ?? "unknown")))];
  if (sources.length === 1 && sources[0] !== SUITE) {
    note(`pinned from ${sources[0]}, not ${SUITE}`);
  }
}

main()
  .catch((error) => drift(`could not verify the pin: ${error.message}`))
  .finally(() => {
    if (lines.length > 0) process.stdout.write(`${lines.join("\n")}\n`);
  });
