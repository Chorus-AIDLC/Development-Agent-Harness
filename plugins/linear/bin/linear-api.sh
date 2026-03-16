#!/usr/bin/env bash
# linear-api.sh — Lightweight GraphQL API wrapper for Linear
# Used by hook scripts to communicate with Linear backend.
#
# Environment variables:
#   LINEAR_API_KEY   — Linear API key (lin_api_xxx) — NO Bearer prefix
#   LINEAR_TEAM_ID   — (optional) Default team ID
#
# State file: $CLAUDE_PROJECT_DIR/.linear-harness/state.json (gitignored)

set -euo pipefail

# ===== Configuration =====

LINEAR_API_KEY="${LINEAR_API_KEY:-}"
LINEAR_TEAM_ID="${LINEAR_TEAM_ID:-}"
LINEAR_API_URL="https://api.linear.app/graphql"
STATE_DIR="${CLAUDE_PROJECT_DIR:-.}/.linear-harness"
STATE_FILE="${STATE_DIR}/state.json"

# ===== Helpers =====

die() {
  echo "ERROR: $*" >&2
  exit 1
}

require_env() {
  [ -n "$LINEAR_API_KEY" ] || die "LINEAR_API_KEY is not set"
}

# ===== Linear GraphQL API =====

# Make an authenticated GraphQL request to Linear
# Usage: linear_graphql "query { viewer { id name } }"
# or:    linear_graphql "mutation { ... }" '{"input": {...}}'
# Auth header: Authorization: <key> (NO Bearer prefix for API keys)
linear_graphql() {
  local query="$1"
  local variables="${2:-}"

  require_env

  local body
  if [ -n "$variables" ]; then
    if command -v jq &>/dev/null; then
      body=$(jq -n --arg q "$query" --argjson v "$variables" '{"query": $q, "variables": $v}')
    else
      body="{\"query\":$(printf '%s' "$query" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))' 2>/dev/null || printf '"%s"' "$query"),\"variables\":${variables}}"
    fi
  else
    if command -v jq &>/dev/null; then
      body=$(jq -n --arg q "$query" '{"query": $q}')
    else
      body="{\"query\":$(printf '%s' "$query" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))' 2>/dev/null || printf '"%s"' "$query")}"
    fi
  fi

  local response
  response=$(curl -s -S -X POST \
    -H "Authorization: ${LINEAR_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "$body" \
    "$LINEAR_API_URL" 2>&1) || {
    echo "CURL_ERROR: Failed to reach ${LINEAR_API_URL}" >&2
    return 1
  }

  echo "$response"
}

# ===== State Management =====

ensure_state() {
  mkdir -p "$STATE_DIR"
  if [ ! -f "$STATE_FILE" ]; then
    echo '{}' > "$STATE_FILE"
  fi
}

state_get() {
  local key="$1"
  ensure_state
  if command -v jq &>/dev/null; then
    jq -r --arg k "$key" '.[$k] // empty' "$STATE_FILE"
  else
    # Fallback: simple grep-based extraction
    grep -o "\"${key}\":\"[^\"]*\"" "$STATE_FILE" 2>/dev/null | cut -d'"' -f4
  fi
}

state_set() {
  local key="$1"
  local value="$2"
  ensure_state
  # Use flock to serialize concurrent state writes (multiple SubagentStart hooks
  # may run in parallel, each calling state-set multiple times).
  (
    flock -w 5 200 || { echo "WARN: state_set flock timeout for key=$key" >&2; return 0; }
    if command -v jq &>/dev/null; then
      local tmp
      tmp=$(mktemp)
      jq --arg k "$key" --arg v "$value" '.[$k] = $v' "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
    else
      if grep -q "\"${key}\":" "$STATE_FILE" 2>/dev/null; then
        sed -i "s|\"${key}\":\"[^\"]*\"|\"${key}\":\"${value}\"|" "$STATE_FILE"
      else
        local tmp
        tmp=$(mktemp)
        sed "s|}$|,\"${key}\":\"${value}\"}|" "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
      fi
    fi
  ) 200>"${STATE_FILE}.lock"
}

state_delete() {
  local key="$1"
  ensure_state
  (
    flock -w 5 200 || { echo "WARN: state_delete flock timeout for key=$key" >&2; return 0; }
    if command -v jq &>/dev/null; then
      local tmp
      tmp=$(mktemp)
      jq --arg k "$key" 'del(.[$k])' "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
    fi
  ) 200>"${STATE_FILE}.lock"
}

# ===== Hook Output =====
# Produces JSON that Claude Code parses:
#   systemMessage                          -> shown to user as notification
#   hookSpecificOutput.additionalContext   -> injected into Claude's context (LLM sees this)
#   hookSpecificOutput.hookEventName       -> identifies which hook event produced this context
#
# Usage: hook_output "User-visible message" "Context for Claude LLM" ["HookEventName"] ["updatedInputJSON"]
hook_output() {
  local system_message="$1"
  local additional_context="${2:-}"
  local hook_event_name="${3:-}"
  local updated_input_json="${4:-}"  # Optional: raw JSON object for updatedInput
  if command -v jq &>/dev/null; then
    if [ -n "$updated_input_json" ]; then
      jq -n \
        --arg sm "$system_message" \
        --arg ac "$additional_context" \
        --arg hen "$hook_event_name" \
        --argjson ui "$updated_input_json" \
        '{systemMessage: $sm, hookSpecificOutput: {hookEventName: $hen, additionalContext: $ac, updatedInput: $ui}}'
    elif [ -n "$additional_context" ]; then
      jq -n \
        --arg sm "$system_message" \
        --arg ac "$additional_context" \
        --arg hen "$hook_event_name" \
        '{systemMessage: $sm, hookSpecificOutput: {hookEventName: $hen, additionalContext: $ac}}'
    else
      jq -n \
        --arg sm "$system_message" \
        '{systemMessage: $sm}'
    fi
  else
    # Fallback: manual JSON — escape newlines and quotes
    local sm_escaped="${system_message//\\/\\\\}"
    sm_escaped="${sm_escaped//\"/\\\"}"
    sm_escaped="${sm_escaped//$'\n'/\\n}"
    if [ -n "$additional_context" ]; then
      local ac_escaped="${additional_context//\\/\\\\}"
      ac_escaped="${ac_escaped//\"/\\\"}"
      ac_escaped="${ac_escaped//$'\n'/\\n}"
      printf '{"systemMessage":"%s","hookSpecificOutput":{"hookEventName":"%s","additionalContext":"%s"}}\n' "$sm_escaped" "$hook_event_name" "$ac_escaped"
    else
      printf '{"systemMessage":"%s"}\n' "$sm_escaped"
    fi
  fi
}

# ===== Session File Management =====

SESSIONS_DIR="${STATE_DIR}/sessions"

# Read a session file by agent name
# Usage: session_file_read <agent_name>
session_file_read() {
  local name="$1"
  local file="${SESSIONS_DIR}/${name}.json"
  if [ -f "$file" ]; then
    cat "$file"
  else
    echo "" >&2
    return 1
  fi
}

# List all session files
session_file_list() {
  if [ ! -d "$SESSIONS_DIR" ]; then
    echo "[]"
    return
  fi
  if command -v jq &>/dev/null; then
    local result="["
    local first=true
    for f in "$SESSIONS_DIR"/*.json; do
      [ -f "$f" ] || continue
      if [ "$first" = true ]; then
        first=false
      else
        result="${result},"
      fi
      result="${result}$(cat "$f")"
    done
    result="${result}]"
    echo "$result" | jq '.'
  else
    ls "$SESSIONS_DIR"/*.json 2>/dev/null | while read -r f; do
      basename "$f" .json
    done
  fi
}

# ===== Subcommands =====

cmd_graphql() {
  local query="${1:-}"
  local variables="${2:-}"
  [ -n "$query" ] || die "Usage: linear-api.sh graphql <query> [variables_json]"
  linear_graphql "$query" "$variables"
}

# ===== Main Dispatch =====

cmd="${1:-}"
shift || true

case "$cmd" in
  graphql)         cmd_graphql "$@" ;;
  state-get)       state_get "${1:-}" ;;
  state-set)       state_set "${1:-}" "${2:-}" ;;
  state-delete)    state_delete "${1:-}" ;;
  session-read)    session_file_read "${1:-}" ;;
  session-list)    session_file_list ;;
  hook-output)     hook_output "${1:-}" "${2:-}" "${3:-}" "${4:-}" ;;
  *)
    echo "Usage: linear-api.sh <command> [args...]"
    echo ""
    echo "Commands:"
    echo "  graphql <query> [vars_json]          Call Linear GraphQL API"
    echo "  state-get <key>                      Read from state.json"
    echo "  state-set <key> <value>              Write to state.json"
    echo "  state-delete <key>                   Delete key from state.json"
    echo "  session-read <name>                  Read session file for an agent"
    echo "  session-list                         List all session files"
    echo "  hook-output <msg> [ctx] [event] [ui] Produce hook output JSON"
    exit 1
    ;;
esac
