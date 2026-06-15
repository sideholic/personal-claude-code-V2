#!/usr/bin/env bash
# launch-flags.sh — echo the `claude` launch flags for a Technoking pane, sourced from
# .claude-team/config.yml (SSOT). ONE source for model + king effort → kills the v1 model
# mismatch (planning L5: config.yml vs agents/*.md vs worker-idle.sh). Bypass perms so a pane
# never prompts mid-dispatch (needs settings.json skipDangerousModePermissionPrompt:true to be silent).
# Usage: FLAGS="$(launch-flags.sh [team_dir])"   → "--model … --effort … --dangerously-skip-permissions"
set -uo pipefail

CFG="${1:-${CLAUDE_TEAM_DIR:-.claude-team}}/config.yml"

cfg() { # cfg <key-regex> → value with inline comment + surrounding ws stripped (empty if absent)
  [ -f "$CFG" ] || return 0
  awk -v pat="$1" '$0 ~ pat { sub(/^[^:]*:[[:space:]]*/, ""); sub(/[[:space:]]*#.*$/, ""); gsub(/[[:space:]]/, ""); print; exit }' "$CFG"
}

MODEL="$(cfg '^model:')";                    MODEL="${MODEL:-claude-opus-4-8}"   # G7: latest opus
EFFORT="$(cfg '^[[:space:]]+technoking:')";  EFFORT="${EFFORT:-high}"            # king = high (non-blocking responsiveness)

printf -- '--model %s --effort %s --dangerously-skip-permissions' "$MODEL" "$EFFORT"
