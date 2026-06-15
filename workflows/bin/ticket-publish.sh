#!/usr/bin/env bash
# ticket-publish.sh — allocate an atomic ticket ID and publish to tickets/queue/.
# Usage: ticket-publish.sh <work|review|backlog> <file.md>
#   <file.md>: markdown w/ YAML frontmatter (title required; id/status/created auto-filled).
# Prints the allocated ID (e.g. T-0007) on stdout. Atomic via python fcntl.flock (macOS-safe).
set -euo pipefail

TEAM_DIR="${CLAUDE_TEAM_DIR:-.claude-team}"
REGISTRY="$TEAM_DIR/workers/registry.json"
LOCK="$TEAM_DIR/.counter.lock"
QUEUE="$TEAM_DIR/tickets/queue"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

command -v python3 >/dev/null || { echo "python3 required" >&2; exit 3; }
[ -f "$REGISTRY" ] || { echo "registry not found: $REGISTRY (run /setup-team)" >&2; exit 2; }
mkdir -p "$QUEUE"

TYPE="${1:?type required: work|review|backlog}"
FILE="${2:?ticket markdown file required}"
[ -f "$FILE" ] || { echo "file not found: $FILE" >&2; exit 2; }
case "$TYPE" in
  work) KEY=T;; review) KEY=RV;; backlog) KEY=BL;;
  *) echo "invalid type: $TYPE (work|review|backlog)" >&2; exit 2;;
esac

# 1) Atomic counter increment (exclusive advisory lock, auto-released on death).
ID="$(python3 "$SCRIPT_DIR/_lib/counter.py" "$REGISTRY" "$LOCK" "$KEY")"

# 2) Patch frontmatter + slug + write to queue/. Prints "<dest>\n<title>".
NOW="$(date +%Y-%m-%dT%H:%M:%S%z | sed -E 's/([0-9]{2})([0-9]{2})$/\1:\2/')"
INFO="$(python3 "$SCRIPT_DIR/_lib/publish_ticket.py" "$FILE" "$QUEUE" "$ID" "$TYPE" "$NOW")"
TITLE="$(printf '%s\n' "$INFO" | sed -n 2p)"

# 3) Emit dashboard event.
DATA="$(python3 -c 'import json,sys; print(json.dumps({"title": sys.argv[1]}))' "$TITLE")"
"$SCRIPT_DIR/events-emit.sh" ticket.published --ticket "$ID" --actor king --data "$DATA"

echo "$ID"
