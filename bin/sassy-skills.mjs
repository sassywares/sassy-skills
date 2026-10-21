#!/usr/bin/env node
// sassy-skills — wire this package's skills into a project.
//
// Nothing scans node_modules on its own, so the harnesses that read a project
// skills directory need links. This tool creates them, checks them, and updates
// the pinned version.
//
//   sassy-skills sync            link skills into .agents/skills (and .claude/skills)
//   sassy-skills check           exit 1 if the wiring is missing or stale
//   sassy-skills update          bump to the latest published version, then sync
//
// Options: --root <dir>  --quiet  --help
import { existsSync, lstatSync, mkdirSync, readdirSync, readFileSync, readlinkSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { execFileSync } from "node:child_process";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const SKILLS_DIR = resolve(HERE, "..", "skills");
const PKG = JSON.parse(readFileSync(resolve(HERE, "..", "package.json"), "utf8"));
const NAME = PKG.name;
const VERSION = PKG.version;
const REGISTRY = process.env.SASSY_SKILLS_REGISTRY ?? "https://registry.npmjs.org";

const args = process.argv.slice(2);
const quiet = args.includes("--quiet");
const rootFlag = args.indexOf("--root");
const rootValueIndex = rootFlag >= 0 ? rootFlag + 1 : -1;
const ROOT = rootFlag >= 0 ? resolve(args[rootFlag + 1] ?? ".") : process.cwd();
if (args.includes("--help") || args.includes("-h")) {
  console.log(`sassy-skills@${VERSION}\n\n  sync     link skills into .agents/skills and .claude/skills\n  check    exit 1 when the wiring is missing or stale\n  update   bump ${NAME} to the latest version, then sync\n  outdated print a one-line nudge when a newer version is published (throttled, offline-safe)\n\nOptions: --root <dir>  --quiet  --force`);
  process.exit(0);
}

const command = args.find((a, i) => !a.startsWith("-") && i !== rootValueIndex) ?? "sync";

const log = (...a) => { if (!quiet) console.log(...a); };
const ok = (m) => log(`  ✓ ${m}`);
const warn = (m) => console.error(`  ! ${m}`);
const die = (m) => { console.error(`  ✗ ${m}`); process.exit(1); };

const IS_WIN = process.platform === "win32";

function linkedSkills() {
  if (!existsSync(SKILLS_DIR)) die(`package has no skills/ directory at ${SKILLS_DIR}`);
  return readdirSync(SKILLS_DIR, { withFileTypes: true })
    .filter((e) => e.isDirectory() && existsSync(join(SKILLS_DIR, e.name, "SKILL.md")))
    .map((e) => e.name)
    .sort();
}

function makeLink(target, linkPath) {
  try {
    if (lstatSync(linkPath).isSymbolicLink()) rmSync(linkPath);
    else { warn(`${linkPath} exists and is not a symlink — leaving it alone`); return false; }
  } catch { /* does not exist */ }
  symlinkSync(target, linkPath, IS_WIN ? "junction" : "dir");
  return true;
}

function sync() {
  const skills = linkedSkills();
  const agents = join(ROOT, ".agents", "skills");
  mkdirSync(agents, { recursive: true });

  let made = 0;
  for (const name of skills) {
    const target = resolve(SKILLS_DIR, name);
    if (makeLink(target, join(agents, name))) made++;
  }
  ok(`${skills.length} skills linked into .agents/skills (${NAME}@${VERSION})`);

  // Claude Code reads .claude/skills only. A directory symlink is enough, and it
  // is the least invasive form when the directory does not already exist.
  const claude = join(ROOT, ".claude", "skills");
  try {
    const st = lstatSync(claude);
    if (!st.isSymbolicLink()) {
      warn(".claude/skills exists and is not a symlink — Claude Code will not see the project skills unless you link them yourself");
    }
  } catch {
    mkdirSync(dirname(claude), { recursive: true });
    symlinkSync(IS_WIN ? join(ROOT, ".agents", "skills") : "../.agents/skills", claude, IS_WIN ? "junction" : "dir");
    ok("linked .claude/skills → .agents/skills");
  }

  if (made) log(`\nRestart or /reload your harness to pick up the new skills.`);
  return 0;
}

function check() {
  const skills = linkedSkills();
  const agents = join(ROOT, ".agents", "skills");
  let problems = 0;

  for (const name of skills) {
    const link = join(agents, name);
    const target = resolve(SKILLS_DIR, name);
    try {
      const st = lstatSync(link);
      if (!st.isSymbolicLink()) { warn(`${name}: real directory, not a link`); problems++; continue; }
      const points = resolve(agents, readlinkSync(link));
      if (points !== target) { warn(`${name}: points at ${points}, expected ${target}`); problems++; }
    } catch {
      warn(`${name}: not linked`);
      problems++;
    }
  }
  if (!existsSync(join(ROOT, ".claude", "skills"))) warn(".claude/skills missing (Claude Code only)");
  if (problems) { console.error(`  ✗ ${problems} skill link(s) need attention — run: sassy-skills sync`); return 1; }
  ok(`${skills.length} skills correctly linked (${NAME}@${VERSION})`);
  return 0;
}

function detectPM() {
  if (existsSync(join(ROOT, "bun.lock")) || existsSync(join(ROOT, "bun.lockb"))) return "bun";
  if (existsSync(join(ROOT, "pnpm-lock.yaml"))) return "pnpm";
  if (existsSync(join(ROOT, "yarn.lock"))) return "yarn";
  if (existsSync(join(ROOT, "package-lock.json"))) return "npm";
  return null;
}

function update() {
  const pm = detectPM();
  if (!pm) die("no lockfile found — cannot tell which package manager to update with");
  const spec = `${NAME}@latest`;
  const cmd = {
    bun: ["bun", ["add", "--dev", "--exact", spec]],
    npm: ["npm", ["install", "--save-dev", "--save-exact", spec]],
    pnpm: ["pnpm", ["add", "--save-dev", "--save-exact", spec]],
    yarn: ["yarn", ["add", "--dev", "--exact", spec]],
  }[pm];
  log(`Updating ${NAME} with ${pm}…`);
  execFileSync(cmd[0], cmd[1], { cwd: ROOT, stdio: "inherit" });
  return sync();
}

function newerThan(a, b) {
  const pa = String(a).split(/[.+-]/).map((x) => parseInt(x, 10) || 0);
  const pb = String(b).split(/[.+-]/).map((x) => parseInt(x, 10) || 0);
  for (let i = 0; i < 3; i++) {
    if ((pa[i] ?? 0) !== (pb[i] ?? 0)) return (pa[i] ?? 0) > (pb[i] ?? 0);
  }
  return false;
}

function updateHint() {
  const pm = detectPM();
  const script = pm === "bun" ? "bun run skills:update"
    : pm ? `${pm} run skills:update`
    : "sassy-skills update";
  return script;
}

// Non-blocking version nudge. Throttled to once a day per machine, silent when
// offline, and it never fails a run — a stale pin is worth mentioning, not
// worth blocking work over.
async function outdated(force = false) {
  const cacheFile = join(tmpdir(), "sassy-skills-version-check.json");
  const TTL = 24 * 60 * 60 * 1000;
  let cached = null;
  try { cached = JSON.parse(readFileSync(cacheFile, "utf8")); } catch { /* first run */ }

  let latest = null;
  const fresh = cached && typeof cached.checkedAt === "number" && Date.now() - cached.checkedAt < TTL;
  if (fresh && !force) {
    latest = cached.latest ?? null;
  } else {
    try {
      const res = await fetch(`${REGISTRY}/${encodeURIComponent(NAME)}/latest`, {
        signal: AbortSignal.timeout(2000),
        headers: { accept: "application/json" },
      });
      const body = await res.json();
      latest = typeof body?.version === "string" ? body.version : null;
    } catch { latest = null; }
    try { writeFileSync(cacheFile, JSON.stringify({ checkedAt: Date.now(), latest })); } catch { /* read-only tmp */ }
  }

  if (!latest || !newerThan(latest, VERSION)) return 0;
  console.log(`  ↑ ${NAME} ${VERSION} → ${latest} available — ${updateHint()}`);
  return 0;
}

switch (command) {
  case "outdated": process.exit(await outdated(args.includes("--force")));
  case "sync": process.exit(sync());
  case "check": process.exit(check());
  case "update": process.exit(update());
  default:
    die(`unknown command: ${command} (try --help)`);
}
