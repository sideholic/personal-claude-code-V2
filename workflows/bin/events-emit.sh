#!/usr/bin/env bash
# events-emit.sh — append one event line to .claude-team/events.jsonl (dashboard feed).
# Usage: events-emit.sh <event> [--ticket ID] [--feature F] [--actor A] [--data '<json>']
# No daemon, no HTTP. Just an append. See docs/events-contract.md.
set -euo pipefail

TEAM_DIR="${CLAUDE_TEAM_DIR:-.claude-team}"
LOG="$TEAM_DIR/events.jsonl"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
command -v python3 >/dev/null || { echo "python3 required" >&2; exit 3; }
mkdir -p "$(dirname "$LOG")"; touch "$LOG"

EVENT="${1:?event required}"; shift || true
TICKET=""; FEATURE=""; ACTOR="king"; DATA="{}"
while [ $# -gt 0 ]; do
  case "$1" in
    --ticket)  TICKET="$2";  shift 2;;
    --feature) FEATURE="$2"; shift 2;;
    --actor)   ACTOR="$2";   shift 2;;
    --data)    DATA="$2";    shift 2;;
    *) echo "unknown arg: $1" >&2; exit 2;;
  esac
done

SEQ=$(( $(wc -l < "$LOG" | tr -d ' ') + 1 ))
TS="$(date +%Y-%m-%dT%H:%M:%S%z | sed -E 's/([0-9]{2})([0-9]{2})$/\1:\2/')"

python3 "$SCRIPT_DIR/_lib/emit_event.py" "$LOG" "$EVENT" "$SEQ" "$TS" "$ACTOR" "$TICKET" "$FEATURE" "$DATA"
