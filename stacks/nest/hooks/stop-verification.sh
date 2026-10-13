#!/usr/bin/env bash
# Stop hook — verify changed-file tests before a worker can claim "done". exit 2 = keep going.
# Scope = changed files only (planning §13). Runner = whatever the repo declares in package.json:
#   vitest (NestJS 12+ scaffold default) → `vitest related`, jest (older scaffold) → `jest --findRelatedTests`.
# No runner declared → skip (never block on a missing tool). Skip with CLAUDE_TEAM_SKIP_VERIFY=1.
set -uo pipefail

[ "${CLAUDE_TEAM_SKIP_VERIFY:-0}" = "1" ] && exit 0
# Only for NestJS projects (and not Next.js — that stack has its own hook).
grep -q '"@nestjs/core"' package.json 2>/dev/null || exit 0
command -v pnpm >/dev/null 2>&1 || exit 0

CHANGED="$( { git diff --name-only HEAD -- '*.ts' 2>/dev/null; git diff --name-only --staged -- '*.ts' 2>/dev/null; } \
  | sort -u | grep -vE '\.(test|spec)\.' || true )"
[ -z "$CHANGED" ] && exit 0

if grep -q '"vitest"' package.json; then
  echo "[stop-verify] changed TS detected → vitest related" >&2
  # vitest related runs only the tests importing the changed files (true changed-file scope).
  pnpm exec vitest related --run --passWithNoTests $CHANGED; RC=$?
elif grep -q '"jest"' package.json; then
  echo "[stop-verify] changed TS detected → jest --findRelatedTests" >&2
  pnpm exec jest --findRelatedTests --passWithNoTests $CHANGED; RC=$?
else
  echo "[stop-verify] no test runner (vitest/jest) in package.json — skipped." >&2
  exit 0
fi
if [ "$RC" -ne 0 ]; then
  echo "[stop-verify] tests failed — not done. Fix or set CLAUDE_TEAM_SKIP_VERIFY=1 to override." >&2
  exit 2
fi
exit 0
