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
// Usage: worktree-check.mjs --installed DIR --shipped DIR
// Prints "<drift|note>\t<message>" per finding and always exits 0: the caller
// owns the verdict and the formatting. Read-only, offline.

import { existsSync } from "node:fs";

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
for (const path of installedByPath.keys()) {
  if (!shippedByPath.has(path)) {
    drift(`.sassywares/worktree/${path} is not shipped by this skill — remove it, or re-run setup`);
  }
}

// Always say the hashes disagreed, even when only a mode or a file the walk
// cannot see moved: the failure is the hash, and the lines above are the detail.
drift(`.sassywares/worktree hash ${got} != the shipped ${want} — re-run setup`);
console.log(lines.join("\n"));
