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
# Force-push guard — the three conditions must hold *within one command segment*.
# Checking them against the whole $CMD produces false positives on compound
# commands: `git push origin --delete feat/x && git worktree remove --force . &&
# git log origin/main..origin/develop` satisfies push/--force/main from three
# unrelated parts and gets blocked. Split on ; && || | and newlines first.
# The ref match is anchored so substrings like "domain"/"maintenance" don't count.
while IFS= read -r seg; do
  printf '%s' "$seg" | grep -qE 'git[[:space:]]+push' || continue
  printf '%s' "$seg" | grep -qE '([[:space:]]|^)(-f|--force)([[:space:]]|$)' || continue
  printf '%s' "$seg" | grep -qE '([[:space:]]|[/:]|^)(main|master)([[:space:]]|$)' || continue
  block "force-push to main/master"
done < <(printf '%s\n' "$CMD" | tr ';&|\n' '\n\n\n\n')   # trailing \n: read drops an unterminated last segment
matches 'chmod[[:space:]]+(-R[[:space:]]+)?777[[:space:]]+/' && block "chmod 777 on /"
matches ':\(\)[[:space:]]*\{[[:space:]]*:[[:space:]]*\|[[:space:]]*:' && block "fork bomb"

exit 0
