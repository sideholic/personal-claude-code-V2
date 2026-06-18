#!/usr/bin/env bash
# ticket-transition.sh — move a ticket between status dirs + patch script-owned fields.
# Usage: ticket-transition.sh <id|path> [--to queued|in_progress|in_review|done|cancelled]
#   [--bump-rescue] [--progress-note "<text>"]
# Script-owned fields only (status/started/done/updated/last_activity_at/counters);
# agent-owned fields + body preserved. Atomic temp+os.replace. Emits the matching event.
# Note-only updates (no --to) emit nothing (dashboard reads frontmatter directly).
set -euo pipefail

TEAM_DIR="${CLAUDE_TEAM_DIR:-.claude-team}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

command -v python3 >/dev/null || { echo "python3 required" >&2; exit 3; }
REF="${1:?ticket id or path required}"; shift || true

NOW="$(date +%Y-%m-%dT%H:%M:%S%z | sed -E 's/([0-9]{2})([0-9]{2})$/\1:\2/')"

# Apply the change atomically. Prints status=/dest=/review_rounds=/rescue_count=.
OUT="$(python3 "$SCRIPT_DIR/_lib/transition_ticket.py" "$TEAM_DIR" "$REF" "$NOW" "$@")"
STATUS="$(printf '%s\n' "$OUT" | sed -n 's/^status=//p')"
ROUNDS="$(printf '%s\n' "$OUT" | sed -n 's/^review_rounds=//p')"

# Detect whether a --to / --bump-rescue was requested (vs note-only).
TO=""; BUMP=0; PREV=""
for a in "$@"; do
  [ "$PREV" = "--to" ] && TO="$a"
  [ "$a" = "--bump-rescue" ] && BUMP=1
  PREV="$a"
done

ID="$(basename "$REF" .md | sed -E 's/^([A-Z]+-[0-9]+).*/\1/')"

# Emit the event that matches the transition (note-only -> nothing).
emit() { "$SCRIPT_DIR/events-emit.sh" "$1" --ticket "$ID" --actor king --data "$2"; }
if [ -n "$TO" ]; then
  case "$TO" in
    in_progress) emit ticket.claimed '{}';;
    in_review)   emit ticket.review "$(python3 -c 'import json,sys;print(json.dumps({"round":int(sys.argv[1])}))' "$ROUNDS")";;
    done)        emit ticket.done '{}';;
    cancelled)   emit ticket.cancelled '{}';;
  esac
fi
if [ "$BUMP" = "1" ]; then
  emit rescue.triggered '{}'
fi

printf '%s\n' "$OUT"
