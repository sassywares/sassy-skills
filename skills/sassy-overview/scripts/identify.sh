#!/usr/bin/env bash
# identify.sh — what is this project, and how does it run?
#
# One tab-separated line per key: `key<TAB>value<TAB>source`, where source is
# the file the value came from, or `-` when there is no source (an `unknown`
# value, or `wired: no`). Read-only: it inspects files, never the network, and
# never runs the project's tooling — not even `make -n` — and writes nothing.
#
# Usage:
#   identify.sh [--root DIR]                  every key, in table order
#   identify.sh [--root DIR] [--key KEY]... [KEY]...
#                                             only the keys named, in the order
#                                             they were named (`--key` and a
#                                             bare positional are the same)
#   identify.sh --help
#
# Exit: 0 answered; 3 a requested key is unknown; 2 usage error. The default
# run is an inventory and exits 0 even when keys are unknown — a request is a
# question, and only a question can go unanswered.
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=skills/sassy-overview/scripts/lib.sh
. "$SELF_DIR/lib.sh"

KEYS="$ID_KEYS"
USAGE="usage: identify.sh [--root DIR] [--key KEY]... [KEY]...
       identify.sh --help

Prints one line per key: key<TAB>value<TAB>source. Read-only.

Keys: $KEYS
Exit: 0 answered, 3 a requested key is unknown, 2 usage error."

die_usage() {
  printf 'identify: %s\n%s\n' "$*" "$USAGE" >&2
  exit 2
}

ROOT="$(pwd -P)"
want=()

while (( $# )); do
  case "$1" in
    --root)   (( $# >= 2 )) || die_usage "missing DIR after --root"; ROOT="$2"; shift 2 ;;
    --root=*) ROOT="${1#*=}"; shift ;;
    --key)    (( $# >= 2 )) || die_usage "missing KEY after --key"; want[${#want[@]}]="$2"; shift 2 ;;
    --key=*)  want[${#want[@]}]="${1#*=}"; shift ;;
    --help|-h)
      printf '%s\n' "$USAGE"
      exit 0 ;;
    -*) die_usage "unknown option '$1'" ;;
    *)  want[${#want[@]}]="$1"; shift ;;
  esac
done

[ -d "$ROOT" ] || die_usage "not a directory: $ROOT"
ID_ROOT="$(cd "$ROOT" && pwd -P)"

id_known() {
  case " $KEYS " in *" $1 "*) return 0 ;; esac
  return 1
}

for k in ${want[@]+"${want[@]}"}; do
  id_known "$k" || die_usage "unknown key '$k'"
done

id_scan

# An inventory prints every key and always exits 0; a request prints the keys it
# named, in that order, and exits 3 when one of them has no answer.
if (( ${#want[@]} )); then keys="${want[*]}"; else keys="$KEYS"; fi
missing=0
for k in $keys; do
  v="$(id_value "$k")"
  s="$(id_source "$k")"
  printf '%s\t%s\t%s\n' "$k" "$v" "$s"
  if [ "$v" = unknown ] && (( ${#want[@]} )); then missing=1; fi
done

(( missing == 0 )) || exit 3
exit 0
