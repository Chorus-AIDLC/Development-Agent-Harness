#!/usr/bin/env bash
# on-user-prompt.sh — UserPromptSubmit hook
# Fires on EVERY user message. Must be ultra-fast (<100ms).
# NO API calls, NO network calls — only local file checks.
# Injects a brief Linear Harness reminder into Claude's context.
#
# Output: JSON with additionalContext (for Claude)

set -euo pipefail

STATE_DIR="${CLAUDE_PROJECT_DIR:-.}/.linear-harness"
SESSIONS_DIR="${STATE_DIR}/sessions"

# Skip entirely if Linear is not configured
if [ -z "${LINEAR_API_KEY:-}" ]; then
  exit 0
fi

# Count active session files (fast local check)
SESSION_COUNT=0
SESSION_NAMES=""
if [ -d "$SESSIONS_DIR" ]; then
  for f in "$SESSIONS_DIR"/*.json; do
    [ -f "$f" ] || continue
    SESSION_COUNT=$((SESSION_COUNT + 1))
    NAME=$(basename "$f" .json)
    if [ -n "$SESSION_NAMES" ]; then
      SESSION_NAMES="${SESSION_NAMES}, ${NAME}"
    else
      SESSION_NAMES="$NAME"
    fi
  done
fi

# Build context — keep it concise to minimize token usage
CONTEXT="[Linear Development Harness Active]
- Sub-agent sessions are auto-managed by hooks (create/cleanup).
- Do NOT manually manage sessions -- the plugin handles this.
- When spawning sub-agents: pass Linear issue IDs. Workflow is auto-injected by SubagentStart hook.
- Link CC tasks to Linear issues with \`linear:issue:<identifier>\` in description."

if [ "$SESSION_COUNT" -gt 0 ]; then
  CONTEXT="${CONTEXT}
- Active sub-agent sessions (${SESSION_COUNT}): ${SESSION_NAMES}"
fi

# Output JSON — no systemMessage (too noisy for every turn)
if command -v jq &>/dev/null; then
  jq -n --arg ac "$CONTEXT" '{additionalContext: $ac}'
else
  AC_ESCAPED="${CONTEXT//\\/\\\\}"
  AC_ESCAPED="${AC_ESCAPED//\"/\\\"}"
  AC_ESCAPED="${AC_ESCAPED//$'\n'/\\n}"
  printf '{"additionalContext":"%s"}\n' "$AC_ESCAPED"
fi
