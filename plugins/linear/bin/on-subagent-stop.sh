#!/usr/bin/env bash
# on-subagent-stop.sh — SubagentStop hook
# Triggered when a sub-agent (teammate) exits.
# Cleans up local state and session files.
# Optionally posts a completion comment on tracked Linear issues.
#
# Output: JSON with systemMessage (user) + additionalContext (Claude)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
API="${SCRIPT_DIR}/linear-api.sh"

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
  exit 0
fi

# Extract agent ID from event
AGENT_ID=$(echo "$EVENT" | jq -r '.agent_id // .agentId // empty' 2>/dev/null) || true

if [ -z "$AGENT_ID" ]; then
  exit 0
fi

# Lookup session name from state
SESSION_NAME=$("$API" state-get "session_${AGENT_ID}" 2>/dev/null) || true
AGENT_NAME=$("$API" state-get "name_for_agent_${AGENT_ID}" 2>/dev/null) || true

if [ -z "$SESSION_NAME" ] && [ -z "$AGENT_NAME" ]; then
  # No session tracked for this agent — skip
  exit 0
fi

DISPLAY_NAME="${AGENT_NAME:-${SESSION_NAME:-${AGENT_ID}}}"

# Check if there's a tracked issue ID for this agent
TRACKED_ISSUE=$("$API" state-get "issue_for_agent_${AGENT_ID}" 2>/dev/null) || true

# Post completion comment on tracked issue (best effort)
COMMENT_OK=false
if [ -n "$TRACKED_ISSUE" ]; then
  COMMENT_QUERY="mutation { commentCreate(input: { issueId: \"${TRACKED_ISSUE}\", body: \"Agent '${DISPLAY_NAME}' completed work on this issue.\" }) { success comment { id } } }"
  COMMENT_RESULT=$("$API" graphql "$COMMENT_QUERY" 2>/dev/null) || true
  if command -v jq &>/dev/null && [ -n "$COMMENT_RESULT" ]; then
    COMMENT_SUCCESS=$(echo "$COMMENT_RESULT" | jq -r '.data.commentCreate.success // false' 2>/dev/null) || true
    if [ "$COMMENT_SUCCESS" = "true" ]; then
      COMMENT_OK=true
    fi
  fi
fi

# Clean up state entries
"$API" state-delete "session_${AGENT_ID}" 2>/dev/null || true
"$API" state-delete "name_for_agent_${AGENT_ID}" 2>/dev/null || true
if [ -n "$SESSION_NAME" ]; then
  "$API" state-delete "agent_for_name_${SESSION_NAME}" 2>/dev/null || true
fi
if [ -n "$TRACKED_ISSUE" ]; then
  "$API" state-delete "issue_for_agent_${AGENT_ID}" 2>/dev/null || true
fi

# Clean up session file
SESSIONS_DIR="${CLAUDE_PROJECT_DIR:-.}/.linear-harness/sessions"
if [ -n "$AGENT_NAME" ] && [ -f "${SESSIONS_DIR}/${AGENT_NAME}.json" ]; then
  rm -f "${SESSIONS_DIR}/${AGENT_NAME}.json"
elif [ -n "$SESSION_NAME" ] && [ -f "${SESSIONS_DIR}/${SESSION_NAME}.json" ]; then
  rm -f "${SESSIONS_DIR}/${SESSION_NAME}.json"
fi

# Clean up claimed file (written by SubagentStart)
CLAIMED_DIR="${CLAUDE_PROJECT_DIR:-.}/.linear-harness/claimed"
if [ -n "$AGENT_ID" ] && [ -f "${CLAIMED_DIR}/${AGENT_ID}" ]; then
  rm -f "${CLAIMED_DIR}/${AGENT_ID}"
fi

# === Output ===
CONTEXT_MSG="Linear Harness session for sub-agent '${DISPLAY_NAME}' cleaned up."
if [ "$COMMENT_OK" = true ]; then
  CONTEXT_MSG="${CONTEXT_MSG} Completion comment posted on issue ${TRACKED_ISSUE}."
fi

"$API" hook-output \
  "Linear Harness session ended: '${DISPLAY_NAME}'" \
  "$CONTEXT_MSG" \
  "SubagentStop"
