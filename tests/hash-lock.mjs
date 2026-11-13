#!/usr/bin/env node
// Build test locks with sassy-setup's own hash definitions, so the tests never
// reimplement the hash the `skills` CLI owns (a private copy is how the roster
// check drifted from the CLI in the first place).
//
//   hash-lock.mjs [--legacy] <skills-dir> <name...>  skills-lock.json on stdout
//   hash-lock.mjs --hash <dir>                      "<current> <legacy>"
//
// --legacy writes the lock v1 definition, the default is the current one.

import { join } from "node:path";

const { hashSkillFolder } = await import(
  new URL("../skills/sassy-setup/scripts/hash-skill.mjs", import.meta.url).href
);

const argv = process.argv.slice(2);
const legacy = argv.includes("--legacy");
const rest = argv.filter((arg) => arg !== "--legacy" && arg !== "--hash");
const [dir, ...names] = rest;

if (argv.includes("--hash")) {
  const current = await hashSkillFolder(dir);
  const old = await hashSkillFolder(dir, true);
  console.log(`${current} ${old}`);
} else {
  const skills = {};
  for (const name of names) {
    skills[name] = {
      source: "sassywares/sassy-skills",
      sourceType: "github",
      computedHash: await hashSkillFolder(join(dir, name), legacy),
    };
  }
  console.log(JSON.stringify({ version: legacy ? 1 : 2, skills }, null, 2));
}
