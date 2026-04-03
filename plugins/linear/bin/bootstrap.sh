#!/usr/bin/env bash
# bootstrap.sh — First-run setup for Linear Development Harness
# Creates harness:* labels in the Linear workspace (idempotent).
# Validates Workflow States and stores team/label IDs in local state.
#
# Usage: LINEAR_API_KEY=lin_api_xxx bash bootstrap.sh [--team TEAM_ID]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
API="${SCRIPT_DIR}/linear-api.sh"

# Check environment
if [ -z "${LINEAR_API_KEY:-}" ]; then
  echo "ERROR: LINEAR_API_KEY is not set" >&2
  echo "Usage: LINEAR_API_KEY=lin_api_xxx bash $0 [--team TEAM_ID]" >&2
  exit 1
fi

# Parse optional --team argument
TEAM_ID="${LINEAR_TEAM_ID:-}"
while [ $# -gt 0 ]; do
  case "$1" in
    --team) TEAM_ID="$2"; shift 2 ;;
    *) shift ;;
  esac
done

echo "=== Linear Development Harness — Bootstrap ==="
echo ""

# Step 1: Get viewer info
echo "Step 1: Verifying API connection..."
VIEWER=$("$API" graphql "query { viewer { id name email } }" 2>/dev/null) || {
  echo "ERROR: Failed to connect to Linear API. Check LINEAR_API_KEY." >&2
  exit 1
}
VIEWER_NAME=$(echo "$VIEWER" | jq -r '.data.viewer.name // .data.viewer.email // "unknown"')
echo "  Connected as: $VIEWER_NAME"

# Step 2: Get or select team
echo ""
echo "Step 2: Resolving team..."
if [ -z "$TEAM_ID" ]; then
  TEAMS=$("$API" graphql "query { teams { nodes { id name key } } }" 2>/dev/null) || {
    echo "ERROR: Failed to list teams." >&2
    exit 1
  }
  TEAM_COUNT=$(echo "$TEAMS" | jq '.data.teams.nodes | length')
  if [ "$TEAM_COUNT" -eq 0 ]; then
    echo "ERROR: No teams found in workspace." >&2
    exit 1
  elif [ "$TEAM_COUNT" -eq 1 ]; then
    TEAM_ID=$(echo "$TEAMS" | jq -r '.data.teams.nodes[0].id')
    TEAM_NAME=$(echo "$TEAMS" | jq -r '.data.teams.nodes[0].name')
    echo "  Auto-selected team: $TEAM_NAME ($TEAM_ID)"
  else
    echo "  Multiple teams found. Please specify: --team <TEAM_ID>"
    echo "$TEAMS" | jq -r '.data.teams.nodes[] | "  - \(.name) (\(.key)): \(.id)"'
    exit 1
  fi
else
  echo "  Using team: $TEAM_ID"
fi

"$API" state-set "default_team_id" "$TEAM_ID"

# Step 3: Get existing labels (to skip duplicates)
echo ""
echo "Step 3: Creating harness:* labels..."
EXISTING=$("$API" graphql "query { issueLabels(filter: { name: { startsWith: \"harness:\" } }) { nodes { id name } } }" 2>/dev/null) || true
EXISTING_NAMES=$(echo "$EXISTING" | jq -r '.data.issueLabels.nodes[].name' 2>/dev/null) || true

create_label() {
  local name="$1"
  local color="$2"
  local desc="$3"

  # Check if already exists
  if echo "$EXISTING_NAMES" | grep -qx "$name" 2>/dev/null; then
    local existing_id
    existing_id=$(echo "$EXISTING" | jq -r --arg n "$name" '.data.issueLabels.nodes[] | select(.name == $n) | .id' 2>/dev/null)
    echo "  SKIP  $name (already exists: $existing_id)"
    "$API" state-set "label_${name}" "$existing_id" 2>/dev/null || true
    return 0
  fi

  local result
  result=$("$API" graphql "mutation(\$input: IssueLabelCreateInput!) { issueLabelCreate(input: \$input) { success issueLabel { id name } } }" "{\"input\":{\"name\":\"$name\",\"color\":\"$color\"}}" 2>/dev/null) || {
    echo "  FAIL  $name"
    return 0
  }

  local success
  success=$(echo "$result" | jq -r '.data.issueLabelCreate.success // false' 2>/dev/null)
  if [ "$success" = "true" ]; then
    local label_id
    label_id=$(echo "$result" | jq -r '.data.issueLabelCreate.issueLabel.id // empty' 2>/dev/null)
    echo "  OK    $name ($label_id)"
    "$API" state-set "label_${name}" "$label_id" 2>/dev/null || true
  else
    echo "  FAIL  $name — $(echo "$result" | jq -r '.errors[0].message // "unknown error"' 2>/dev/null)"
  fi
}

create_label "harness:idea"        "#7C3AED" "Idea awaiting elaboration"
create_label "harness:elaborating" "#F59E0B" "Under AI elaboration"
create_label "harness:proposal"    "#3B82F6" "Proposal submitted (identity label — stays permanently)"
create_label "harness:approved"    "#10B981" "Proposal approved (stacked with harness:proposal)"
create_label "harness:rejected"    "#EF4444" "Proposal rejected (stacked with harness:proposal)"
create_label "harness:pm"          "#8B5CF6" "PM Agent work item"
create_label "harness:dev"         "#06B6D4" "Developer Agent work item"
create_label "harness:admin"       "#F97316" "Admin review needed"
create_label "harness:agent"       "#6366F1" "Assigned to AI Agent"
create_label "harness:ac-passed"   "#14B8A6" "All acceptance criteria self-checked as passed"

# Step 4: Validate Workflow States
echo ""
echo "Step 4: Validating Workflow States..."
STATES=$("$API" graphql "query { workflowStates(filter: { team: { id: { eq: \"$TEAM_ID\" } } }) { nodes { id name type } } }" 2>/dev/null) || true

if [ -n "$STATES" ]; then
  HAS_IN_REVIEW=$(echo "$STATES" | jq -r '.data.workflowStates.nodes[] | select(.name == "In Review") | .id' 2>/dev/null) || true

  echo "  Available states:"
  echo "$STATES" | jq -r '.data.workflowStates.nodes[] | "    [\(.type)] \(.name) — \(.id)"' 2>/dev/null || true

  if [ -n "$HAS_IN_REVIEW" ]; then
    echo "  OK: 'In Review' state found ($HAS_IN_REVIEW)"
    "$API" state-set "state_in_review_id" "$HAS_IN_REVIEW" 2>/dev/null || true
  else
    echo ""
    echo "  WARNING: 'In Review' state NOT found in this team."
    echo "  The AI-DLC workflow requires an 'In Review' state between 'In Progress' and 'Done'."
    echo "  Please add it manually: Linear > Team Settings > Workflow > Add state > Type: Started > Name: In Review"
    echo ""
  fi

  # Store key state IDs
  for state_name in "Triage" "Backlog" "Todo" "In Progress" "Done" "Canceled"; do
    state_id=$(echo "$STATES" | jq -r --arg n "$state_name" '.data.workflowStates.nodes[] | select(.name == $n) | .id' 2>/dev/null) || true
    if [ -n "$state_id" ]; then
      safe_key=$(printf '%s' "$state_name" | tr '[:upper:] ' '[:lower:]_')
      "$API" state-set "state_${safe_key}_id" "$state_id" 2>/dev/null || true
    fi
  done
fi

echo ""
echo "=== Bootstrap Complete ==="
echo ""
echo "State saved to: ${CLAUDE_PROJECT_DIR:-.}/.linear-harness/state.json"
echo ""
echo "Next steps:"
echo "  1. Verify MCP connection: list_teams in Claude Code"
echo "  2. Start using AI-DLC workflow (see SKILL.md)"
