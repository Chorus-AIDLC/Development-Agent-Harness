#!/usr/bin/env bash
# on-teammate-idle.sh — TeammateIdle hook
# Triggered when a teammate goes idle (between turns).
# Updates local session timestamp. No API call (Linear has no heartbeat concept).
#
# Output: suppressed (idle events are frequent and noisy)

set -euo pipefail

# Check environment
if [ -z "${LINEAR_API_KEY:-}" ]; then
  exit 0
fi

# Read event JSON from stdin
EVENT=""
if [ ! -t 0 ]; then
  EVENT=$(cat)
fi

if [ -z "$EVENT" ]; then
  echo '{"suppressOutput": true}'
  exit 0
fi

# Extract teammate info
TEAMMATE_NAME=$(echo "$EVENT" | jq -r '.teammate_name // .teammateName // empty' 2>/dev/null) || true

# Update session file timestamp if we can find the session
if [ -n "$TEAMMATE_NAME" ]; then
  SESSIONS_DIR="${CLAUDE_PROJECT_DIR:-.}/.linear-harness/sessions"
  SESSION_FILE="${SESSIONS_DIR}/${TEAMMATE_NAME}.json"
  if [ -f "$SESSION_FILE" ] && command -v jq &>/dev/null; then
    tmp=$(mktemp)
    jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '.lastActiveAt = $ts' "$SESSION_FILE" > "$tmp" && mv "$tmp" "$SESSION_FILE" 2>/dev/null || true
  fi
fi

# Suppress output entirely — no systemMessage for idle events
echo '{"suppressOutput": true}'
