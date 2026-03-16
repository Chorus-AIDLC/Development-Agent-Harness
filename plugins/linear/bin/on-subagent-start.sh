#!/usr/bin/env bash
# on-subagent-start.sh — SubagentStart hook
# Triggered SYNCHRONOUSLY when a sub-agent (teammate) is spawned.
#
# Name resolution: Claims a per-agent pending file written by PreToolUse:Task
# using atomic mv (only one process can successfully mv a given file).
#
# Session management (local only — no Chorus-style server sessions):
#   1. Claim pending file via atomic mv
#   2. Create local session file in .linear-harness/sessions/
#   3. Store state mappings for other hooks (TeammateIdle, SubagentStop)
#   4. Inject workflow context into sub-agent
#
# Output: JSON with systemMessage (user) + additionalContext (sub-agent)

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

# Extract agent info from event
# Note: SubagentStart only provides agent_id and agent_type — NOT the name.
# The name is captured by on-pre-spawn-agent.sh and stored in .linear-harness/pending/.
AGENT_ID=$(echo "$EVENT" | jq -r '.agent_id // .agentId // empty' 2>/dev/null) || true
AGENT_TYPE=$(echo "$EVENT" | jq -r '.agent_type // .agentType // empty' 2>/dev/null) || true

# Skip non-worker agent types (read-only agents don't need sessions)
case "$(printf '%s' "$AGENT_TYPE" | tr '[:upper:]' '[:lower:]')" in
  explore|plan|haiku|claude-code-guide|statusline-setup)
    exit 0
    ;;
esac

if [ -z "$AGENT_ID" ]; then
  exit 0
fi

# Claim a pending file written by PreToolUse:Task (on-pre-spawn-agent.sh).
# Claim strategy (atomic mv — only one process can succeed per file):
#   1. Try exact match: mv .linear-harness/pending/{agent_type} -> claimed/{agent_id}
#   2. Fallback: claim the oldest pending file (FIFO by modification time)
# If no pending file exists, this is an internal/cleanup agent -> skip.
AGENT_NAME=""
PENDING_DIR="${CLAUDE_PROJECT_DIR:-.}/.linear-harness/pending"
CLAIMED_DIR="${CLAUDE_PROJECT_DIR:-.}/.linear-harness/claimed"
mkdir -p "$CLAIMED_DIR"

CLAIMED_FILE=""

# Strategy 1: exact match by agent_type (CC uses name as agent_type)
if [ -f "${PENDING_DIR}/${AGENT_TYPE}" ]; then
  if mv "${PENDING_DIR}/${AGENT_TYPE}" "${CLAIMED_DIR}/${AGENT_ID}" 2>/dev/null; then
    CLAIMED_FILE="${CLAIMED_DIR}/${AGENT_ID}"
    AGENT_NAME="$AGENT_TYPE"
  fi
fi

# Strategy 2: FIFO — claim oldest pending file
if [ -z "$CLAIMED_FILE" ] && [ -d "$PENDING_DIR" ]; then
  for candidate in $(ls -tr "$PENDING_DIR" 2>/dev/null); do
    if mv "${PENDING_DIR}/${candidate}" "${CLAIMED_DIR}/${AGENT_ID}" 2>/dev/null; then
      CLAIMED_FILE="${CLAIMED_DIR}/${AGENT_ID}"
      # Read name from file content if available
      FILE_NAME=$(jq -r '.name // empty' "$CLAIMED_FILE" 2>/dev/null) || true
      AGENT_NAME="${FILE_NAME:-$candidate}"
      break
    fi
    # mv failed -> another process claimed it first, try next
  done
fi

# No pending file claimed -> internal/cleanup agent -> skip
if [ -z "$CLAIMED_FILE" ]; then
  exit 0
fi

# Fallback: use agent_type + short ID if no name was captured
SESSION_NAME="${AGENT_NAME:-${AGENT_TYPE:-worker}-${AGENT_ID}}"
# Truncate long session names for display (keep first 60 chars)
if [ ${#SESSION_NAME} -gt 60 ]; then
  SESSION_NAME=$(printf '%s' "$SESSION_NAME" | cut -c1-60)
fi

# === State: store mapping for other hooks (TeammateIdle, SubagentStop) ===
"$API" state-set "session_${AGENT_ID}" "$SESSION_NAME"
"$API" state-set "name_for_agent_${AGENT_ID}" "$SESSION_NAME"
"$API" state-set "agent_for_name_${SESSION_NAME}" "$AGENT_ID"

# === Session file: minimal metadata for other hooks ===
SESSIONS_DIR="${CLAUDE_PROJECT_DIR:-.}/.linear-harness/sessions"
mkdir -p "$SESSIONS_DIR"

cat > "${SESSIONS_DIR}/${SESSION_NAME}.json" <<SESSIONEOF
{
  "agentId": "${AGENT_ID}",
  "agentName": "${SESSION_NAME}",
  "agentType": "${AGENT_TYPE:-unknown}",
  "createdAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "lastActiveAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
SESSIONEOF

# === Owner info: read from state (stored by on-session-start.sh) ===
OWNER_SECTION=""
VIEWER_ID=$("$API" state-get "viewer_id" 2>/dev/null) || true
if [ -n "$VIEWER_ID" ]; then
  VIEWER_NAME=$("$API" state-get "viewer_name" 2>/dev/null) || true
  VIEWER_EMAIL=$("$API" state-get "viewer_email" 2>/dev/null) || true
  OWNER_SECTION="
## Owner Info

Your owner (the human who configured this harness): ${VIEWER_NAME} (${VIEWER_EMAIL}), Linear ID: ${VIEWER_ID}
Use this info when you need to @mention your owner in comments."
fi

# === Output: inject workflow directly into sub-agent context via additionalContext ===
WORKFLOW="## Linear Development Harness Session (Auto-injected by plugin)

Your session name: ${SESSION_NAME}
Agent ID: ${AGENT_ID}
The plugin manages session lifecycle. Do NOT manually manage sessions.

### Workflow -- follow these steps for each Linear Issue:

**Before starting:**
1. Move to In Progress: update_issue({ issueId: \"<ISSUE_ID>\", status: \"In Progress\" })
2. Post start comment: create_comment({ issueId: \"<ISSUE_ID>\", body: \"Started working on this issue.\" })

**While working:**
3. Report progress via comments: create_comment({ issueId: \"<ISSUE_ID>\", body: \"Progress: ...\" })

**After completing:**
4. Self-check: verify any Markdown checklists in the issue description are complete
5. Submit for review: update_issue({ issueId: \"<ISSUE_ID>\", status: \"In Review\" })
6. Post completion comment: create_comment({ issueId: \"<ISSUE_ID>\", body: \"Ready for verification. Summary: ...\" })

Replace <ISSUE_ID> with the actual Linear issue ID from your prompt.${OWNER_SECTION}"

"$API" hook-output \
  "Linear Harness session created: '${SESSION_NAME}'" \
  "$WORKFLOW" \
  "SubagentStart"
