#!/usr/bin/env node
// Verify the vendored sassy-* folders against skills-lock.json.
//
// The suite installs in one of two scopes, like the agents: the project
// (vendored into .agents/skills and pinned in skills-lock.json) or the user
// (~/.agents/skills, plus ~/.claude/skills for Claude Code). Only a project
// install has a pin to verify; a user install is reported, and a missing suite
// is reported without counting as drift.
//
// Read-only, offline. The folder hash is the `skills` CLI's own definition —
// sha256 over each file's relative path then its bytes, files sorted by relative
// path — so "identical to the pin" is a fact this script asserts, not a claim
// the agent has to make in prose.
//
// Usage: lockcheck.mjs [--root DIR]
// Prints "<drift|note>\t<message>" per finding and always exits 0: the caller
// owns the verdict and the formatting.

import { createHash } from "node:crypto";
import { readdir, readFile } from "node:fs/promises";
import { existsSync, readdirSync } from "node:fs";
import { homedir } from "node:os";
import { join, relative } from "node:path";

const SUITE = "sassywares/sassy-skills";
const SASSY = /^sassy-/;

const argv = process.argv.slice(2);
let root = process.cwd();
for (let i = 0; i < argv.length; i += 1) {
  if (argv[i] === "--root") {
    root = argv[i + 1];
    i += 1;
  }
}

const lines = [];
const drift = (message) => lines.push(`drift\t${message}`);
const note = (message) => lines.push(`note\t${message}`);

async function collect(base, dir, files) {
  for (const entry of await readdir(dir, { withFileTypes: true })) {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) {
      if (entry.name === ".git" || entry.name === "node_modules") continue;
      await collect(base, full, files);
    } else if (entry.isFile()) {
      files.push({
        path: relative(base, full).split("\\").join("/"),
        body: await readFile(full),
      });
    }
  }
}

async function folderHash(dir) {
  const files = [];
  await collect(dir, dir, files);
  files.sort((a, b) => a.path.localeCompare(b.path));
  const hash = createHash("sha256");
  for (const file of files) {
    hash.update(file.path);
    hash.update(file.body);
  }
  return hash.digest("hex");
}

// sassy-* skills in a skills directory. Follows symlinks: a user scope may link
// each skill to a working copy rather than holding the files.
function suiteIn(dir) {
  if (!existsSync(dir)) return [];
  return readdirSync(dir).filter(
    (name) => SASSY.test(name) && existsSync(join(dir, name, "SKILL.md")),
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
    drift(`sassy-* folders in .agents/skills but no skills-lock.json — re-pin with npx skills add ${SUITE}`);
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
    ([name, entry]) => SASSY.test(name) || String(entry.source ?? "").includes("sassy-skills"),
  );
  if (pinned.length === 0) {
    drift(`skills-lock.json pins no sassy-* skill — install with npx skills add ${SUITE}`);
    return;
  }

  const suite = join(root, ".agents", "skills");
  if (!existsSync(suite)) {
    drift(`no .agents/skills — the vendored copies are missing; install with npx skills add ${SUITE}`);
    return;
  }

  const installed = (await readdir(suite, { withFileTypes: true }))
    .filter((entry) => entry.isDirectory() && SASSY.test(entry.name))
    .map((entry) => entry.name);
  const installedNames = new Set(installed);
  const pinnedNames = new Set(pinned.map(([name]) => name));
  let matched = 0;

  for (const [name, entry] of pinned) {
    if (!installedNames.has(name)) {
      drift(`vendored ${name} is missing from .agents/skills — re-install with npx skills add ${SUITE}`);
      continue;
    }
    if ((await folderHash(join(suite, name))) !== entry.computedHash) {
      drift(`${name} does not match the pin — edited locally or half-installed; re-install, or re-pin with npx skills add ${SUITE}`);
      continue;
    }
    matched += 1;
  }

  for (const name of installed) {
    if (!pinnedNames.has(name)) {
      drift(`${name} is installed but not pinned in skills-lock.json — npx skills add ${SUITE} pins it`);
    }
  }

  if (matched > 0) {
    note(`${matched}/${pinned.length} sassy-* skill folders match skills-lock.json byte for byte`);
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
