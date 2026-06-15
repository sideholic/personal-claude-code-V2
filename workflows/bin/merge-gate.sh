#!/usr/bin/env bash
# merge-gate.sh — serialize squash merges across multiple Technokings (opt-in multi-king).
# Runs <cmd...> while holding the exclusive merge lock, so concurrent kings never race on main.
# Usage: merge-gate.sh <cmd...>   e.g.  merge-gate.sh gh pr merge 42 --squash
set -euo pipefail

TEAM_DIR="${CLAUDE_TEAM_DIR:-.claude-team}"
LOCK="$TEAM_DIR/.merge.lock"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
command -v python3 >/dev/null || { echo "python3 required" >&2; exit 3; }
mkdir -p "$TEAM_DIR"
[ $# -ge 1 ] || { echo "usage: merge-gate.sh <cmd...>" >&2; exit 2; }

exec python3 "$SCRIPT_DIR/_lib/with_lock.py" "$LOCK" "$@"
