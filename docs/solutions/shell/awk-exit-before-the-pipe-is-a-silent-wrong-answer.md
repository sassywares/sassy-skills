---
title: An awk that exits early upstream of a pipe is a silent "no" under pipefail — drain the input and decide in END
category: shell
tags: [awk, bash, pipefail, sigpipe, set-euo-pipefail, pipeline]
created: 2026-11-25
---

## Context

A shell probe answers "does this file declare X?" as an exit status:

```bash
awk -v block="$2" '... { if (match(rest, /^[ \t]*:[ \t]*\{/)) found = 1 } END { exit(found ? 0 : 1) }' "$1"
```

with nothing piped into it, that is correct. The same function was also called
downstream of a comment stripper:

```bash
strip_comments "$1" | has_block - "$2"
```

The document was a few hundred KB of comments followed by the block. The probe
answered "no block", so the caller reported the file as declaring no runnable
commands — for a manifest that plainly declared one.

## Root cause

`awk '...; exit'` stops reading as soon as it matches. Upstream of a pipe that
success is a lie about the whole input:

1. awk matches early and exits `0` at its own line.
2. The producer (`strip_comments`) is still writing; its next `write()` gets
   `EPIPE` and it dies of `SIGPIPE`, status `141`.
3. `set -o pipefail` makes the pipeline's status the rightmost non-zero — `141`.
4. `set -e` turns that into a failed statement; and a caller written as
   `if probe …` reads a failure of `141` exactly like the intended "no".

Nothing crashes, nothing prints, and the wrong answer is a *plausible* one.
It also only appears past the pipe buffer: with a small fixture the producer has
already finished before awk exits, there is no `EPIPE`, and the same code is
green. A test suite of small fixtures cannot catch it.

## Guidance

- **Drain, then decide.** Let the scanner read to end of input and answer in
  `END`. `END` runs after every line, so the pipeline finishes cleanly and the
  exit status means what it says:

  ```awk
  {
    i = index($0, "\"" block "\"")
    if (!i) next
    rest = substr($0, i + length(block) + 2)
    if (match(rest, /^[ \t]*:[ \t]*\{/)) found = 1   # keep reading
  }
  END { exit(found ? 0 : 1) }
  ```

  Early exit is fine when nothing is upstream — but "nothing is upstream today"
  is a property of one call site, not of the function.
- **Never `exit` from an awk that sits in a pipeline** whose status you branch
  on. The saving is real bytes and no time, and the cost is a wrong answer on
  exactly the inputs that are big enough to matter.
- **Treat `141` as a bug, not a status.** `pipefail` exists to surface it; the
  fix belongs at the producer/consumer boundary, not in `|| true`.
- **Test with a manifest larger than the pipe buffer.** ~64 KB is the usual
  default; a fixture needs a few hundred KB of padding before the match to be
  reliably bigger. A 6000-line comment block ahead of the real declaration is
  enough and costs milliseconds.

## Applicability

Any `set -euo pipefail` script that pipes into a tool which may stop early —
`awk`, `grep -q`, `head`, `sed q`, `node -e … process.exit()`. It does not
apply to a tool whose early exit is the point and whose status the caller
ignores (a progress filter, a deliberately truncated stream), nor to a pipeline
whose status is never read.
