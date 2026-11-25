---
title: Read JSON-looking manifests with a string-aware scanner, never with a regex or a raw-bytes counter
category: shell
tags: [awk, json, jsonc, parsing, shell, manifest]
created: 2026-11-25
---

## Context

A shell probe had to answer "does this manifest declare this task, and what is
its command?" over `package.json`, `composer.json`, `deno.json`, and
`deno.jsonc`. It did so by treating the file as text: match the block's opening
brace, look for a name, and stop at the first `}` or the first `//`. Both
shorthands tested green on small hand-written fixtures and both lied on real
manifests.

## Guidance

A JSON manifest is a character grammar, not a line shape. Two failures share one
root cause — reading raw bytes as structure — and one fix: track quote and
escape state, and only interpret structure outside a string.

- **A `//` inside a string is data.** `.jsonc` allows comments, so a stripper
  must remove them. Stripping by regex or by "line contains `//` → truncate"
  also eats a `"serve": "deno run https://x/y.ts"` value and anything after it
  on that line.
- **A `}` inside a string does not close the block.** Counting braces without
  quote state ended the `scripts`/`tasks` object at `"dev": "echo }hi"`, which
  truncated the command *and* hid every later entry — so a flatly declared
  `test` reported as absent.
- **A commented-out entry is not a declaration.** A `.jsonc` with
  `// "dev": "deno run -A main.ts"` must report no `dev` task, and a whole
  commented-out `"tasks"` block must report no block at all, while the real
  `down` and `test` beside it still answer.

The fix is one small scanner used by every reader:

```awk
function strip(text,   i, c) {
  for (i = 1; i <= length(text); i++) {
    c = substr(text, i, 1)
    if (in_str) {                                   # inside a value
      out = out c
      if (c == "\\") { out = out substr(text, i + 1, 1); i++; continue }
      if (c == "\"") in_str = 0
      continue
    }
    if (c == "\"") { in_str = 1; out = out c; continue }   # contents are opaque
    if (c == "/" && substr(text, i + 1, 1) == "/") break   # comment, only here
    out = out c
  }
  return out
}
```

and the mirror of it for structure — same state, opposite decision:

```awk
function block_end(text,   i, c, depth, q, esc) {
  depth = 0; q = 0; esc = 0
  for (i = 1; i <= length(text); i++) {
    c = substr(text, i, 1)
    if (q) { if (esc) { esc = 0 }           # "\"" is data
             else if (c == "\\") { esc = 1 }
             else if (c == "\"") { q = 0 }
             continue }
    if (c == "\"") { q = 1; continue }
    if (c == "{") depth++
    else if (c == "}") { if (depth == 0) return i; depth-- }
  }
  return 0
}
```

JSON strings never span lines, so both states may reset per line — that is what
keeps the scanners small enough to read.

- **Strip before probing, once per file.** Comment removal belongs in one
  function every reader pipes through, not repeated at each call site: two
  scanners with slightly different quote rules will disagree about the same
  manifest, and the disagreement shows up as a wrong answer, not an error.
- **Strict JSON gets no stripper.** `package.json` is strict JSON, so it must
  keep reading byte-identically; only the `.jsonc` path is stripped.
- **Escape state is not optional.** `"echo \"hi\""` without it ends the string
  one character early, and every following byte is misread as structure.

## Applicability

Any shell tool that extracts a key, a command, or a block from JSON, JSONC,
JSON5, or another line-oriented format with quotes and comments. It does not
apply when a real parser is available and acceptable — `jq`, `node -e`, or a
library is always safer than a hand-rolled scanner. The scanner is the fallback
for when the probe must stay dependency-free and read a file type the project
ships but does not guarantee a parser for.

The general rule survives either way: if the input has quoting or escaping, a
regex over the file is a guess, and the guess fails on the inputs users actually
write — URLs, shell one-liners, and commented-out config.
