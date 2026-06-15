#!/usr/bin/env bash
# king-pane.sh — launch N additional Technoking panes (OPT-IN multi-king). tmux required.
# Each pane is an independent interactive `claude` (drive it with /feat). Kings coordinate via
# the atomic T-counter (ticket-publish.sh) + the merge gate (merge-gate.sh) — no shared pane state.
# Usage: king-pane.sh [N=1]
set -euo pipefail

N="${1:-1}"
command -v tmux >/dev/null || { echo "tmux required for multi-king" >&2; exit 3; }
[ -n "${TMUX:-}" ] || { echo "run inside a tmux session first (tmux new -s claude)" >&2; exit 2; }
case "$N" in (*[!0-9]*|'') echo "N must be a positive integer" >&2; exit 2;; esac

for _ in $(seq 1 "$N"); do
  tmux split-window -h -c "$PWD" "claude"
  tmux select-layout tiled >/dev/null
done
echo "launched $N Technoking pane(s). They share the atomic ticket counter + merge gate; no pane cap."
