#!/usr/bin/env bash
# on-session-start.sh — SessionStart hook
# Triggered on Claude Code session startup/resume.
# Calls Linear GraphQL to get viewer info and teams.
# Stores viewer/team info in state for other hooks.
#
# Output: JSON with systemMessage (user) + additionalContext (Claude)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
API="${SCRIPT_DIR}/linear-api.sh"

# Read event JSON from stdin (if available)
EVENT=""
if [ ! -t 0 ]; then
  EVENT=$(cat)
fi

# Check if Linear environment is configured
if [ -z "${LINEAR_API_KEY:-}" ]; then
  "$API" hook-output \
    "Linear Harness: not configured (set LINEAR_API_KEY)" \
    "Linear environment not configured. Set LINEAR_API_KEY to enable Linear Development Harness." \
    "SessionStart"
  exit 0
fi

# Get viewer info from Linear
VIEWER_RESULT=$("$API" graphql "query { viewer { id name email } }" 2>/dev/null) || {
  "$API" hook-output \
    "Linear Harness: connection failed" \
    "WARNING: Unable to reach Linear API. Check LINEAR_API_KEY." \
    "SessionStart"
  exit 0
}

# Extract viewer fields
VIEWER_ID=""
VIEWER_NAME=""
VIEWER_EMAIL=""
if command -v jq &>/dev/null; then
  VIEWER_ID=$(echo "$VIEWER_RESULT" | jq -r '.data.viewer.id // empty' 2>/dev/null) || true
  VIEWER_NAME=$(echo "$VIEWER_RESULT" | jq -r '.data.viewer.name // empty' 2>/dev/null) || true
  VIEWER_EMAIL=$(echo "$VIEWER_RESULT" | jq -r '.data.viewer.email // empty' 2>/dev/null) || true
fi

if [ -z "$VIEWER_ID" ]; then
  "$API" hook-output \
    "Linear Harness: authentication failed" \
    "WARNING: Could not authenticate with Linear. Check LINEAR_API_KEY value." \
    "SessionStart"
  exit 0
fi

# Store viewer info in state
"$API" state-set "viewer_id" "$VIEWER_ID"
"$API" state-set "viewer_name" "$VIEWER_NAME"
"$API" state-set "viewer_email" "$VIEWER_EMAIL"

# Get teams from Linear
TEAMS_RESULT=$("$API" graphql "query { teams { nodes { id name key } } }" 2>/dev/null) || true
TEAMS_LIST=""
FIRST_TEAM_ID=""
if command -v jq &>/dev/null && [ -n "$TEAMS_RESULT" ]; then
  TEAMS_LIST=$(echo "$TEAMS_RESULT" | jq -r '.data.teams.nodes[]? | "- \(.name) (\(.key)): \(.id)"' 2>/dev/null) || true
  FIRST_TEAM_ID=$(echo "$TEAMS_RESULT" | jq -r '.data.teams.nodes[0].id // empty' 2>/dev/null) || true
fi

# Store default team ID if not already set
if [ -z "${LINEAR_TEAM_ID:-}" ] && [ -n "$FIRST_TEAM_ID" ]; then
  "$API" state-set "default_team_id" "$FIRST_TEAM_ID"
else
  if [ -n "${LINEAR_TEAM_ID:-}" ]; then
    "$API" state-set "default_team_id" "$LINEAR_TEAM_ID"
  fi
fi

# Check for existing session files (resumed session)
SESSIONS_DIR="${CLAUDE_PROJECT_DIR:-.}/.linear-harness/sessions"
SESSION_INFO=""
if [ -d "$SESSIONS_DIR" ]; then
  SESSION_COUNT=0
  for f in "$SESSIONS_DIR"/*.json; do
    [ -f "$f" ] || continue
    SESSION_COUNT=$((SESSION_COUNT + 1))
  done
  if [ "$SESSION_COUNT" -gt 0 ]; then
    SESSION_INFO="
Resuming with ${SESSION_COUNT} existing local session file(s)."
  fi
fi

# Build context for Claude
CONTEXT="# Linear Development Harness -- Active

Connected to Linear API as ${VIEWER_NAME} (${VIEWER_EMAIL}).
Session lifecycle hooks are enabled: SubagentStart, SubagentStop, TeammateIdle, TaskCompleted.

## Viewer Info
- ID: ${VIEWER_ID}
- Name: ${VIEWER_NAME}
- Email: ${VIEWER_EMAIL}

## Teams
${TEAMS_LIST:-No teams found.}

## Session Management -- IMPORTANT

The Linear Development Harness **fully automates** local session lifecycle:
- Sub-agent spawn -> local session file auto-created + workflow auto-injected into sub-agent context
- Teammate idle -> local session timestamp updated (no API call)
- Sub-agent stop -> local session cleaned up + optional completion comment posted

**Do NOT manually manage sessions.** The plugin handles this.
When spawning sub-agents, pass Linear issue IDs in the prompt. Workflow instructions are auto-injected by SubagentStart hook.

To link a Claude Code task to a Linear issue, include \`linear:issue:<identifier>\` in the task description.

## Linear MCP Server

The official Linear MCP server tools are available (list_issues, create_issue, update_issue, search_issues, etc.).
Use these tools for all Linear operations — creating issues, updating status, managing labels, etc.

## Labels Convention

The harness uses these label prefixes for AI-DLC workflow:
- \`harness:idea\` — Idea issues
- \`harness:proposal\` — Proposal parent issues
- \`harness:task\` — Task sub-issues
- \`harness:admin\` — Issues needing admin review${SESSION_INFO}"

USER_MSG="Linear Harness connected as ${VIEWER_NAME}"

"$API" hook-output "$USER_MSG" "$CONTEXT" "SessionStart"
