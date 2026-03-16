#!/usr/bin/env bash
# linear-extra.sh — CLI for Linear operations not covered by the official MCP server.
# Automatically uses LINEAR_API_KEY from environment.
#
# Usage:
#   bash bin/linear-extra.sh <command> [args...]
#
# Commands:
#   relation create <issueId> <type> <relatedIssueId>   Create issue relation (blocks|blocked-by|related|duplicate)
#   relation list <issueId>                              List relations for an issue
#   relation delete <relationId>                         Delete a relation
#   cycle create <teamId> <name> <startsAt> <endsAt>     Create a cycle
#   cycle list <teamId>                                  List cycles for a team
#   cycle assign <issueId> <cycleId>                     Assign issue to a cycle
#   cycle remove <issueId>                               Remove issue from its cycle
#   initiative create <name> [description]               Create an initiative
#   initiative list                                      List initiatives
#   bulk-move-status <stateId> <issueId> [issueId...]    Move multiple issues to a status
#   viewer                                               Get current viewer info
#   states <teamId>                                      List workflow states for a team

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
API="${SCRIPT_DIR}/linear-api.sh"

# ===== Helpers =====

usage() {
  sed -n '2,/^$/p' "$0" | grep "^#" | sed 's/^# \?//'
  exit 1
}

gql() {
  "$API" graphql "$@"
}

jq_or_raw() {
  if command -v jq &>/dev/null; then
    jq "$@"
  else
    cat
  fi
}

# ===== Commands =====

cmd_relation() {
  local sub="${1:-}"
  shift || true

  case "$sub" in
    create)
      local issue_id="${1:-}"
      local rel_type="${2:-}"
      local related_id="${3:-}"
      [ -n "$issue_id" ] && [ -n "$rel_type" ] && [ -n "$related_id" ] || {
        echo "Usage: linear-extra.sh relation create <issueId> <type> <relatedIssueId>" >&2
        echo "Types: blocks, blocked-by, related, duplicate" >&2
        exit 1
      }
      # Map friendly names to GraphQL enum
      local gql_type
      case "$rel_type" in
        blocks)      gql_type="blocks" ;;
        blocked-by)  gql_type="blocks"; local tmp="$issue_id"; issue_id="$related_id"; related_id="$tmp" ;;
        related)     gql_type="related" ;;
        duplicate)   gql_type="duplicate" ;;
        *)           echo "Unknown relation type: $rel_type (use: blocks, blocked-by, related, duplicate)" >&2; exit 1 ;;
      esac
      gql "mutation { issueRelationCreate(input: { issueId: \"$issue_id\", relatedIssueId: \"$related_id\", type: $gql_type }) { success issueRelation { id type } } }" | jq_or_raw '.'
      ;;
    list)
      local issue_id="${1:-}"
      [ -n "$issue_id" ] || { echo "Usage: linear-extra.sh relation list <issueId>" >&2; exit 1; }
      gql "query { issue(id: \"$issue_id\") { relations { nodes { id type relatedIssue { id identifier title } } } inverseRelations { nodes { id type issue { id identifier title } } } } }" | jq_or_raw '.data.issue'
      ;;
    delete)
      local rel_id="${1:-}"
      [ -n "$rel_id" ] || { echo "Usage: linear-extra.sh relation delete <relationId>" >&2; exit 1; }
      gql "mutation { issueRelationDelete(id: \"$rel_id\") { success } }" | jq_or_raw '.'
      ;;
    *)
      echo "Usage: linear-extra.sh relation <create|list|delete> [args...]" >&2
      exit 1
      ;;
  esac
}

cmd_cycle() {
  local sub="${1:-}"
  shift || true

  case "$sub" in
    create)
      local team_id="${1:-}"
      local name="${2:-}"
      local starts_at="${3:-}"
      local ends_at="${4:-}"
      [ -n "$team_id" ] && [ -n "$name" ] && [ -n "$starts_at" ] && [ -n "$ends_at" ] || {
        echo "Usage: linear-extra.sh cycle create <teamId> <name> <startsAt> <endsAt>" >&2
        echo "Date format: YYYY-MM-DD" >&2
        exit 1
      }
      gql 'mutation($input: CycleCreateInput!) { cycleCreate(input: $input) { success cycle { id name startsAt endsAt } } }' \
        "{\"input\":{\"teamId\":\"$team_id\",\"name\":\"$name\",\"startsAt\":\"$starts_at\",\"endsAt\":\"$ends_at\"}}" | jq_or_raw '.'
      ;;
    list)
      local team_id="${1:-}"
      [ -n "$team_id" ] || { echo "Usage: linear-extra.sh cycle list <teamId>" >&2; exit 1; }
      gql "query { team(id: \"$team_id\") { cycles { nodes { id name startsAt endsAt } } } }" | jq_or_raw '.data.team.cycles.nodes'
      ;;
    assign)
      local issue_id="${1:-}"
      local cycle_id="${2:-}"
      [ -n "$issue_id" ] && [ -n "$cycle_id" ] || { echo "Usage: linear-extra.sh cycle assign <issueId> <cycleId>" >&2; exit 1; }
      gql "mutation { issueUpdate(id: \"$issue_id\", input: { cycleId: \"$cycle_id\" }) { success issue { id identifier cycle { id name } } } }" | jq_or_raw '.'
      ;;
    remove)
      local issue_id="${1:-}"
      [ -n "$issue_id" ] || { echo "Usage: linear-extra.sh cycle remove <issueId>" >&2; exit 1; }
      gql "mutation { issueUpdate(id: \"$issue_id\", input: { cycleId: null }) { success } }" | jq_or_raw '.'
      ;;
    *)
      echo "Usage: linear-extra.sh cycle <create|list|assign|remove> [args...]" >&2
      exit 1
      ;;
  esac
}

cmd_initiative() {
  local sub="${1:-}"
  shift || true

  case "$sub" in
    create)
      local name="${1:-}"
      local desc="${2:-}"
      [ -n "$name" ] || { echo "Usage: linear-extra.sh initiative create <name> [description]" >&2; exit 1; }
      if [ -n "$desc" ]; then
        gql 'mutation($input: InitiativeCreateInput!) { initiativeCreate(input: $input) { success initiative { id name } } }' \
          "{\"input\":{\"name\":\"$name\",\"description\":\"$desc\"}}" | jq_or_raw '.'
      else
        gql 'mutation($input: InitiativeCreateInput!) { initiativeCreate(input: $input) { success initiative { id name } } }' \
          "{\"input\":{\"name\":\"$name\"}}" | jq_or_raw '.'
      fi
      ;;
    list)
      gql "query { initiatives { nodes { id name description status } } }" | jq_or_raw '.data.initiatives.nodes'
      ;;
    *)
      echo "Usage: linear-extra.sh initiative <create|list> [args...]" >&2
      exit 1
      ;;
  esac
}

cmd_bulk_move_status() {
  local state_id="${1:-}"
  shift || true
  [ -n "$state_id" ] || { echo "Usage: linear-extra.sh bulk-move-status <stateId> <issueId> [issueId...]" >&2; exit 1; }
  [ $# -gt 0 ] || { echo "Usage: linear-extra.sh bulk-move-status <stateId> <issueId> [issueId...]" >&2; exit 1; }

  # Build mutation with proper quoting — use single quotes in GraphQL string
  local mutations=""
  local i=0
  for issue_id in "$@"; do
    mutations="${mutations} u${i}: issueUpdate(id: \"${issue_id}\", input: { stateId: \"${state_id}\" }) { success }"
    i=$((i + 1))
  done
  gql "mutation {${mutations} }" | jq_or_raw '.'
}

cmd_viewer() {
  gql "query { viewer { id name email } }" | jq_or_raw '.data.viewer'
}

cmd_states() {
  local team_id="${1:-}"
  [ -n "$team_id" ] || { echo "Usage: linear-extra.sh states <teamId>" >&2; exit 1; }
  gql "query { workflowStates(filter: { team: { id: { eq: \"$team_id\" } } }) { nodes { id name type } } }" | jq_or_raw '.data.workflowStates.nodes'
}

# ===== Main Dispatch =====

cmd="${1:-}"
shift || true

case "$cmd" in
  relation)         cmd_relation "$@" ;;
  cycle)            cmd_cycle "$@" ;;
  initiative)       cmd_initiative "$@" ;;
  bulk-move-status) cmd_bulk_move_status "$@" ;;
  viewer)           cmd_viewer ;;
  states)           cmd_states "$@" ;;
  -h|--help|help|"") usage ;;
  *)
    echo "Unknown command: $cmd" >&2
    usage
    ;;
esac
