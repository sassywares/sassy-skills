#!/usr/bin/env node
// Verify an installed `.sassywares/worktree/` set against the copy this skill
// ships.
//
// A `worktree-version` header cannot prove the tree is untouched: it is
// hand-maintained, so an edited byte and an asset change without a bump both
// still read as current. Instead hash both folders with the `skills` CLI's own
// definition (./hash-skill.mjs — the one skills-lock.json uses), and when the
// hashes differ, name every file that differs. The expected hash is the shipped
// asset folder's: setup installs it by copying that folder flat, so no separate
// state file records it and no second hash definition exists.
//
// The shipped set is four files — _lib.sh, create, list, remove. `prune` is
// gone, so an older install is stale by construction and its hash cannot match.
// That is not tampering, but it is not harmless either: the project's own
// create/remove scripts are written against the set this skill ships, and an
// older one lacks the flags and helpers they call, so a run stops mid-operation
// where no check is watching. A stale set is therefore drift, never a shrugged
// "upgrade": named once as stale, then by file.
//
// Usage: worktree-check.mjs --installed DIR --shipped DIR
// Prints "<drift|note>\t<message>" per finding and always exits 0: the caller
// owns the verdict and the formatting. Read-only, offline.

import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

import { hashFiles, skillFiles } from "./hash-skill.mjs";

let installed = "";
let shipped = "";

const argv = process.argv.slice(2);
for (let i = 0; i < argv.length; i += 1) {
  if (argv[i] === "--installed") {
    installed = argv[i + 1] ?? "";
    i += 1;
  } else if (argv[i] === "--shipped") {
    shipped = argv[i + 1] ?? "";
    i += 1;
  }
}

const lines = [];
const drift = (message) => lines.push(`drift\t${message}`);
const note = (message) => lines.push(`note\t${message}`);

if (!installed || !shipped) {
  drift("usage: worktree-check.mjs --installed DIR --shipped DIR");
  console.log(lines.join("\n"));
  process.exit(0);
}

// A missing installed set is the caller's "re-run setup" finding, not an empty
// folder that happens to hash differently.
if (!existsSync(installed)) {
  drift("missing .sassywares/worktree — re-run setup");
  console.log(lines.join("\n"));
  process.exit(0);
}

// headerVersion DIR — the number on `# worktree-version: N` in DIR/_lib.sh, or
// null when there is no readable header. A header is never the verdict, but a
// lower one names an install built for a contract this skill no longer ships.
const headerVersion = (dir) => {
  const file = join(dir, "_lib.sh");
  if (!existsSync(file)) return null;
  const match = readFileSync(file, "utf8").match(/^# worktree-version:\s*(\d+)\s*$/m);
  return match ? Number(match[1]) : null;
};

const installedVersion = headerVersion(installed);
const shippedVersion = headerVersion(shipped);

// A lower header than the shipped one is the stale case: the set installed is
// not the set the project's scripts were written against, so they stop mid-run
// on a flag it never had. A higher header is not stale — a newer set works, it
// is simply not the one this skill ships — so it reports through the file walk
// alone and never borrows the "falls over" wording.
const stale =
  installedVersion !== null &&
  shippedVersion !== null &&
  installedVersion < shippedVersion;

// Walk each side once: the hash is the verdict and the same arrays name which
// bytes moved, so the per-file report cannot contradict the folder hash.
const [installedFiles, shippedFiles] = await Promise.all([
  skillFiles(installed),
  skillFiles(shipped),
]);

const got = hashFiles(installedFiles);
const want = hashFiles(shippedFiles);

if (got === want) {
  note(`worktree tooling matches the shipped set (hash ${got.slice(0, 12)})`);
  console.log(lines.join("\n"));
  process.exit(0);
}

// Verdict first, evidence after: the stale line says what it costs, and the walk
// below names the files so the report cannot be read as vague.
if (stale) {
  drift("worktree setup is stale — it goes off mid-run, not here; re-run setup");
}

const byPath = (files) => new Map(files.map((file) => [file.path, file.body]));
const installedByPath = byPath(installedFiles);
const shippedByPath = byPath(shippedFiles);

for (const [path, body] of shippedByPath) {
  if (!installedByPath.has(path)) {
    drift(`.sassywares/worktree/${path} is missing from the installed set — re-run setup`);
  } else if (!installedByPath.get(path).equals(body)) {
    drift(`.sassywares/worktree/${path} differs from the shipped copy — re-run setup`);
  }
}
// A file this skill no longer ships is left over from an older set, and the
// `_lib.sh` helpers it calls went with it — so it is not merely untidy, it is a
// command that cannot work.
for (const path of installedByPath.keys()) {
  if (!shippedByPath.has(path)) {
    drift(`${path} is retired and its helpers went with it — it cannot run; re-run setup`);
  }
}

// Always say the hashes disagreed, even when only a mode or a file the walk
// cannot see moved: the failure is the hash, and the lines above are the detail.
drift(`.sassywares/worktree hash ${got} != the shipped ${want} — re-run setup`);
console.log(lines.join("\n"));
