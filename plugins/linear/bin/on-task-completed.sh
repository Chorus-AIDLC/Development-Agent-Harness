#!/usr/bin/env bash
# on-task-completed.sh — TaskCompleted hook
# Triggered when a Claude Code task is marked completed.
# Checks for a Linear issue identifier in the task metadata (linear:issue:<identifier>).
# If found, posts a completion comment on the Linear issue via GraphQL.
#
# Output: JSON with systemMessage (user) when a comment is posted

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

# Extract task info
TASK_DESCRIPTION=$(echo "$EVENT" | jq -r '.task_description // .taskDescription // .description // empty' 2>/dev/null) || true
TASK_SUBJECT=$(echo "$EVENT" | jq -r '.task_subject // .taskSubject // .subject // empty' 2>/dev/null) || true

# Look for linear:issue:<identifier> pattern in description or subject
LINEAR_ISSUE_ID=""

for text in "$TASK_DESCRIPTION" "$TASK_SUBJECT"; do
  if [ -n "$text" ]; then
    # Match linear:issue:<id> where id can be a UUID or issue identifier
    MATCH=$(echo "$text" | grep -o 'linear:issue:[A-Za-z0-9_-]*' | head -1 | sed 's/linear:issue://') || true
    if [ -n "$MATCH" ]; then
      LINEAR_ISSUE_ID="$MATCH"
      break
    fi
  fi
done

if [ -z "$LINEAR_ISSUE_ID" ]; then
  # No Linear issue linked — silent exit
  exit 0
fi

# Post a completion comment on the Linear issue
COMMENT_QUERY="mutation { commentCreate(input: { issueId: \"${LINEAR_ISSUE_ID}\", body: \"Claude Code task completed for this issue. Ready for verification.\" }) { success comment { id } } }"
COMMENT_RESULT=$("$API" graphql "$COMMENT_QUERY" 2>/dev/null) || {
  "$API" hook-output \
    "Linear Harness: failed to comment on issue ${LINEAR_ISSUE_ID}" \
    "WARNING: Failed to post completion comment on Linear issue ${LINEAR_ISSUE_ID}." \
    "TaskCompleted"
  exit 0
}

COMMENT_SUCCESS=""
if command -v jq &>/dev/null; then
  COMMENT_SUCCESS=$(echo "$COMMENT_RESULT" | jq -r '.data.commentCreate.success // false' 2>/dev/null) || true
fi

if [ "$COMMENT_SUCCESS" = "true" ]; then
  "$API" hook-output \
    "Linear Harness: completion comment posted on ${LINEAR_ISSUE_ID}" \
    "Posted completion comment on Linear issue ${LINEAR_ISSUE_ID} (via metadata bridge linear:issue:<id>)." \
    "TaskCompleted"
else
  "$API" hook-output \
    "Linear Harness: comment may have failed on ${LINEAR_ISSUE_ID}" \
    "Attempted to post completion comment on Linear issue ${LINEAR_ISSUE_ID} but success was not confirmed." \
    "TaskCompleted"
fi
