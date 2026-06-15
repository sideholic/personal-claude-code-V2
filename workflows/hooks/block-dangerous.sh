#!/usr/bin/env bash
# PreToolUse(Bash) hook — block obviously destructive commands. exit 2 = block.
# Safety net, not exhaustive. Reads the hook JSON on stdin.
set -uo pipefail

INPUT="$(cat)"
CMD="$(printf '%s' "$INPUT" | python3 -c 'import json,sys
try:
    d = json.load(sys.stdin)
    print(d.get("tool_input", {}).get("command", ""))
except Exception:
    print("")' 2>/dev/null)"
[ -z "$CMD" ] && exit 0

matches() { printf '%s' "$CMD" | grep -qE "$1"; }
block() { echo "blocked (dangerous): $1" >&2; exit 2; }

matches 'rm[[:space:]]+-[rf][rf]?[[:space:]]+(/|~|\$HOME|\*)([[:space:]]|$)' && block "rm -rf on root/home/glob"
matches '\-\-no-verify' && block "--no-verify (bypasses hooks/CI)"
if matches 'git[[:space:]]+push' && matches '([[:space:]]|^)(-f|--force)([[:space:]]|$)' && matches '(main|master)'; then
  block "force-push to main/master"
fi
matches 'chmod[[:space:]]+(-R[[:space:]]+)?777[[:space:]]+/' && block "chmod 777 on /"
matches ':\(\)[[:space:]]*\{[[:space:]]*:[[:space:]]*\|[[:space:]]*:' && block "fork bomb"

exit 0
