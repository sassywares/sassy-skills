#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PIDFILE="${TMPDIR:-/tmp}/sassy-skills-watch.pid"

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  exit 0
fi

echo $$ > "$PIDFILE"
trap 'rm -f "$PIDFILE"' EXIT

while true; do
  if [ -n "$(git -C "$REPO" status --porcelain 2>/dev/null)" ]; then
    # Let rapid edits settle before committing.
    sleep 4
    "$REPO/scripts/sync.sh" || true
  fi
  sleep 6
done
