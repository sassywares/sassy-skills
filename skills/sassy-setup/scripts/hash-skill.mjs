// The `skills` CLI's skill-folder hash, as sassy-setup checks it.
//
// Two eras are live in the wild and the lock's `version` says which one wrote
// its `computedHash`:
//
//   lock v1 (skills CLI <= 1.7.x)  sha256 over, per file sorted by
//                                  localeCompare: relative path, then bytes.
//   lock v2 (skills CLI >= 1.8.x)  sha256 over, per file sorted by Buffer
//                                  compare: relative path, "\0", byte length,
//                                  "\0", bytes — CRLF normalized to LF, and
//                                  metadata.json, .git, __pycache__ and
//                                  __pypackages__ excluded.
//
// Both are transcriptions of the CLI's own collectFiles + hashSkillFiles (the
// CLI keeps the v1 one to migrate old locks), so a folder this module calls
// clean is a folder `skills check` calls clean. A hash that drifts from the
// CLI's is not a cosmetic bug: it reports a sound pin as drift on every suite
// skill. Re-read the CLI's source when bumping, and keep the golden vectors in
// tests/sassy-setup-roster.sh honest.
//
// No side effects: lockcheck.mjs and tests/hash-lock.mjs import it.

import { createHash } from "node:crypto";
import { readdir, readFile, realpath, stat } from "node:fs/promises";
import { join, relative, sep } from "node:path";

// skills CLI >= 1.8.x, for lock v2 and later.
const EXCLUDE_FILES = new Set(["metadata.json"]);
const EXCLUDE_DIRS = new Set([".git", "__pycache__", "__pypackages__"]);

async function walk(base, dir, realRoot, ancestors, files) {
  const realDir = await realpath(dir);
  if (ancestors.has(realDir)) return;
  const branch = new Set(ancestors).add(realDir);
  for (const entry of await readdir(dir, { withFileTypes: true })) {
    if (EXCLUDE_FILES.has(entry.name)) continue;
    if (entry.isDirectory() && EXCLUDE_DIRS.has(entry.name)) continue;
    const full = join(dir, entry.name);
    let isDirectory = entry.isDirectory();
    if (entry.isSymbolicLink()) {
      const target = await realpath(full).catch(() => null);
      // A link out of the skill folder is not part of the skill; one that stays
      // inside is (a user scope links each skill to a working copy).
      if (!target || (target !== realRoot && !target.startsWith(realRoot + sep))) continue;
      isDirectory = (await stat(target)).isDirectory();
      if (isDirectory && EXCLUDE_DIRS.has(entry.name)) continue;
    } else if (!isDirectory && !entry.isFile()) {
      continue;
    }
    if (isDirectory) {
      await walk(base, full, realRoot, branch, files);
    } else {
      files.push({
        path: relative(base, full).split("\\").join("/"),
        body: await readFile(full),
      });
    }
  }
}

// The v1 walk: no exclusions beyond .git/node_modules, no symlinks followed.
async function walkLegacy(base, dir, files) {
  for (const entry of await readdir(dir, { withFileTypes: true })) {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) {
      if (entry.name === ".git" || entry.name === "node_modules") continue;
      await walkLegacy(base, full, files);
    } else if (entry.isFile()) {
      files.push({
        path: relative(base, full).split("\\").join("/"),
        body: await readFile(full),
      });
    }
  }
}

// CRLF to LF, unless the file holds a NUL or has none — the CLI's own rule.
function normalizeLineEndings(body) {
  if (body.includes(0) || !body.includes("\r\n")) return body;
  return Buffer.from(body.toString("latin1").replaceAll("\r\n", "\n"), "latin1");
}

// Hash one skill folder the way the CLI does for a lock of the given era.
export async function hashSkillFolder(dir, legacy = false) {
  const hash = createHash("sha256");
  if (legacy) {
    const files = [];
    await walkLegacy(dir, dir, files);
    files.sort((a, b) => a.path.localeCompare(b.path));
    for (const file of files) hash.update(file.path).update(file.body);
    return hash.digest("hex");
  }
  const files = [];
  await walk(dir, dir, await realpath(dir), new Set(), files);
  const entries = files
    .map((file) => ({
      path: Buffer.from(file.path, "utf8"),
      body: normalizeLineEndings(file.body),
    }))
    .sort((a, b) => Buffer.compare(a.path, b.path));
  for (const entry of entries) {
    hash
      .update(entry.path)
      .update("\0")
      .update(String(entry.body.length))
      .update("\0")
      .update(entry.body);
  }
  return hash.digest("hex");
}
