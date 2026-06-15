#!/usr/bin/env bash
# Stop hook — verify changed-file tests before a worker can claim "done". exit 2 = keep going.
# Scope = changed files via `vitest related` (planning §13). Skip with CLAUDE_TEAM_SKIP_VERIFY=1.
set -uo pipefail

[ "${CLAUDE_TEAM_SKIP_VERIFY:-0}" = "1" ] && exit 0
# Only for Next.js projects.
{ [ -f next.config.js ] || [ -f next.config.ts ] || [ -f next.config.mjs ] \
  || grep -q '"next"' package.json 2>/dev/null; } || exit 0
command -v pnpm >/dev/null 2>&1 || exit 0

CHANGED="$( { git diff --name-only HEAD -- '*.ts' '*.tsx' 2>/dev/null; git diff --name-only --staged -- '*.ts' '*.tsx' 2>/dev/null; } \
  | sort -u | grep -vE '\.(test|spec)\.' || true )"
[ -z "$CHANGED" ] && exit 0

echo "[stop-verify] changed TS detected → vitest related" >&2
# vitest related runs only the tests importing the changed files (true changed-file scope).
if ! pnpm exec vitest related --run $CHANGED; then
  echo "[stop-verify] tests failed — not done. Fix or set CLAUDE_TEAM_SKIP_VERIFY=1 to override." >&2
  exit 2
fi
exit 0
