// Edit a consumer's skills-lock.json for the roster's skills, and nothing else.
//
// The skills CLI's folder hash is not re-derived here: `write` imports
// skills/sassy-setup/scripts/hash-skill.mjs from the source repo, so a folder
// this writes a pin for is a folder `npx skills check` calls clean. What the
// lock owns is the only record of which entries we installed: an entry from
// another source, or a roster skill we did not vendor, is kept byte for byte.
//
// No imports beyond node's stdlib and that one module. Commands:
//
//   owned <lock>                          names this suite installed, one per line
//   write <lock> <source> <roster> <sha>  rewrite our roster entries in place
//
// `write` keeps `version` and every foreign entry as they are, drops our entry
// for a skill that left the roster, and inserts a new name in sorted position.
import { readFile, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const SOURCE_REPO = "sassywares/sassy-skills";

function fail(message) {
  process.stderr.write(`  ✗ ${message}\n`);
  process.exit(2);
}

const ours = (entry) => Boolean(entry) && entry.source === SOURCE_REPO;

async function readLock(path) {
  let text;
  try {
    text = await readFile(path, "utf8");
  } catch (error) {
    fail(`cannot read ${path}: ${error.message}`);
  }
  let lock;
  try {
    lock = JSON.parse(text);
  } catch (error) {
    fail(`${path} is not valid JSON: ${error.message}`);
  }
  if (!lock || typeof lock !== "object" || !lock.skills || typeof lock.skills !== "object") {
    fail(`${path} has no "skills" object`);
  }
  return lock;
}

async function loadHasher(sourceRoot) {
  const module = join(sourceRoot, "skills", "sassy-setup", "scripts", "hash-skill.mjs");
  try {
    return (await import(pathToFileURL(module).href)).hashSkillFolder;
  } catch (error) {
    fail(`cannot import ${module}: ${error.message}`);
  }
}

const [command, ...args] = process.argv.slice(2);

if (command === "owned") {
  if (!args[0]) fail("owned needs <lock>");
  const lock = await readLock(args[0]);
  for (const name of Object.keys(lock.skills)) {
    if (ours(lock.skills[name])) process.stdout.write(`${name}\n`);
  }
  process.exit(0);
}

if (command === "write") {
  const [lockPath, sourceRoot, rosterPath, commit] = args;
  if (!lockPath || !sourceRoot || !rosterPath || !commit) {
    fail("write needs <lock> <source-root> <roster> <commit>");
  }
  const lock = await readLock(lockPath);
  const hashSkillFolder = await loadHasher(sourceRoot);
  const roster = (await readFile(rosterPath, "utf8"))
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);
  const inRoster = new Set(roster);
  const before = lock.skills;

  // Keep the file's order for entries that stay. Our entry for a skill that
  // left the roster goes with its folder — the lock is what says we installed
  // it, so a stale entry would claim a skill that no longer exists here.
  const names = Object.keys(before).filter((name) => !(ours(before[name]) && !inRoster.has(name)));
  for (const name of roster) {
    if (names.includes(name)) continue;
    const at = names.findIndex((existing) => existing > name);
    if (at === -1) names.push(name);
    else names.splice(at, 0, name);
  }

  const skills = {};
  for (const name of names) {
    if (!inRoster.has(name)) {
      skills[name] = before[name];
      continue;
    }
    const dir = join(sourceRoot, "skills", name);
    let computedHash;
    try {
      computedHash = await hashSkillFolder(dir);
    } catch (error) {
      fail(`cannot hash ${dir}: ${error.message}`);
    }
    skills[name] = {
      source: SOURCE_REPO,
      sourceType: "github",
      skillPath: `skills/${name}/SKILL.md`,
      computedHash,
      commit,
    };
  }

  lock.skills = skills;
  await writeFile(lockPath, `${JSON.stringify(lock, null, 2)}\n`);
  process.exit(0);
}

fail(`unknown command: ${command ?? "(none)"} — expected owned or write`);
