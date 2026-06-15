#!/usr/bin/env bash
# Stop hook — verify changed-file tests before a worker can claim "done". exit 2 = keep going.
# Scope = changed files (planning §13). Skip with CLAUDE_TEAM_SKIP_VERIFY=1.
set -uo pipefail

[ "${CLAUDE_TEAM_SKIP_VERIFY:-0}" = "1" ] && exit 0
# Only for Gradle/Kotlin projects.
{ [ -f build.gradle.kts ] || [ -f settings.gradle.kts ]; } || exit 0
command -v ./gradlew >/dev/null 2>&1 || [ -x ./gradlew ] || exit 0

CHANGED="$( { git diff --name-only HEAD -- '*.kt' 2>/dev/null; git diff --name-only --staged -- '*.kt' 2>/dev/null; } \
  | sort -u | grep -vE '/(test|generated)/' || true )"
[ -z "$CHANGED" ] && exit 0

echo "[stop-verify] changed .kt detected → ./gradlew test" >&2
# Note: per-file test selection is a refinement; runs the module suite for now.
if ! ./gradlew test --quiet; then
  echo "[stop-verify] tests failed — not done. Fix or set CLAUDE_TEAM_SKIP_VERIFY=1 to override." >&2
  exit 2
fi
exit 0
