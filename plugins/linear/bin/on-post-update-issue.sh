#!/usr/bin/env bash
# on-post-update-issue.sh — PostToolUse hook for update_issue
# Triggered after any update_issue MCP call completes.
# Parses the tool_input labelIds to detect:
#   - Proposal submission: labelIds contain harness:proposal + harness:admin
#   - Task verification:   labelIds contain harness:ac-passed + harness:admin
# Outputs a suggestion to spawn the appropriate reviewer agent.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
API="${SCRIPT_DIR}/linear-api.sh"

# Read event JSON from stdin (PostToolUse hook input)
EVENT=""
if [ ! -t 0 ]; then
  EVENT=$(cat)
fi

if [ -z "$EVENT" ]; then
  exit 0
fi

# Extract labelIds array from tool_input — exit early if no labelIds
LABEL_IDS_JSON=$(echo "$EVENT" | jq -c '.tool_input.labelIds // empty' 2>/dev/null) || true

if [ -z "$LABEL_IDS_JSON" ] || [ "$LABEL_IDS_JSON" = "null" ]; then
  exit 0
fi

LABEL_COUNT=$(echo "$LABEL_IDS_JSON" | jq 'length' 2>/dev/null) || true
if [ -z "$LABEL_COUNT" ] || [ "$LABEL_COUNT" -lt 2 ]; then
  # Need at least 2 labels for either detection pattern
  exit 0
fi

# Extract issueId from tool_input
ISSUE_ID=$(echo "$EVENT" | jq -r '.tool_input.issueId // empty' 2>/dev/null) || true
if [ -z "$ISSUE_ID" ]; then
  exit 0
fi

# Resolve label UUIDs to names by querying Linear API
# Build a GraphQL query to fetch labels by their IDs
LABEL_IDS_GQL=$(echo "$LABEL_IDS_JSON" | jq -r '[.[] | "\"" + . + "\""] | join(", ")' 2>/dev/null) || true

if [ -z "$LABEL_IDS_GQL" ]; then
  exit 0
fi

LABEL_RESULT=$("$API" graphql "query { issueLabels(filter: { id: { in: [${LABEL_IDS_GQL}] } }) { nodes { id name } } }" 2>/dev/null) || true

if [ -z "$LABEL_RESULT" ]; then
  exit 0
fi

# Extract label names into a newline-separated list
LABEL_NAMES=$(echo "$LABEL_RESULT" | jq -r '.data.issueLabels.nodes[].name' 2>/dev/null) || true

if [ -z "$LABEL_NAMES" ]; then
  exit 0
fi

# Check for harness:admin (required for both patterns)
if ! echo "$LABEL_NAMES" | grep -qx "harness:admin" 2>/dev/null; then
  exit 0
fi

# --- Proposal submission detection ---
if echo "$LABEL_NAMES" | grep -qx "harness:proposal" 2>/dev/null; then
  # Check toggle — default enabled
  if [ "${CLAUDE_PLUGIN_OPTION_ENABLEPROPOSALREVIEWER:-true}" != "true" ]; then
    exit 0
  fi

  CONTEXT="[Linear Harness — Proposal Submitted for Review]
Issue ${ISSUE_ID} has been submitted as a proposal for admin review (harness:proposal + harness:admin).

ACTION REQUIRED: Spawn the \`proposal-reviewer\` agent to perform an independent quality review before admin approval.

Example:
  Agent({ subagent_type: \"proposal-reviewer\", prompt: \"Review proposal on issue ${ISSUE_ID}. Fetch the issue and its description, check document quality, task granularity, AC alignment, and cross-task dependencies. Post your VERDICT as a comment on the issue.\" })

The reviewer is read-only and will post its VERDICT as a comment on the issue. The result is advisory — the admin makes the final approval decision.

IMPORTANT: Run the reviewer synchronously (do NOT set run_in_background). Wait for its VERDICT before proceeding with approval."

  "$API" hook-output "" "$CONTEXT" "PostToolUse"
  exit 0
fi

# --- Task verification submission detection ---
if echo "$LABEL_NAMES" | grep -qx "harness:ac-passed" 2>/dev/null; then
  # Check toggle — default disabled
  if [ "${CLAUDE_PLUGIN_OPTION_ENABLETASKREVIEWER:-false}" != "true" ]; then
    exit 0
  fi

  CONTEXT="[Linear Harness — Task Submitted for Verification]
Issue ${ISSUE_ID} has been submitted for verification (harness:ac-passed + harness:admin).

ACTION REQUIRED: Spawn the \`task-reviewer\` agent to perform an independent review before admin verification.

Example:
  Agent({ subagent_type: \"task-reviewer\", prompt: \"Review task ${ISSUE_ID}. Fetch the issue and its AC, read the proposal documents, examine the code, run tests if available. Post your VERDICT as a comment on the issue.\" })

The reviewer is read-only and will post its VERDICT as a comment on the issue. The result is advisory — the admin makes the final verification decision.

IMPORTANT: Run the reviewer synchronously (do NOT set run_in_background). Wait for its VERDICT before proceeding with admin verification."

  "$API" hook-output "" "$CONTEXT" "PostToolUse"
  exit 0
fi

# Neither pattern matched — exit silently
exit 0
