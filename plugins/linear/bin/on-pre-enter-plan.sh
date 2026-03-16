#!/usr/bin/env bash
# on-pre-enter-plan.sh — PreToolUse hook for EnterPlanMode
# Injects AI-DLC planning guidance for Linear when Claude enters plan mode.
#
# Output: JSON with additionalContext

set -euo pipefail

[ -z "${LINEAR_API_KEY:-}" ] && exit 0

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
API="${SCRIPT_DIR}/linear-api.sh"

CONTEXT="[Linear Development Harness -- Planning Workflow]
When planning implementation, follow the AI-DLC lifecycle on Linear:
1. Find or create a Parent Issue as Idea (label: harness:idea, Triage status)
2. Elaborate requirements via Comment Q&A on the Parent Issue (label: harness:elaborating)
3. Transition the same Parent Issue to Proposal (label: harness:proposal)
4. Write a Document (PRD) and create task Sub-issues under the Parent Issue
5. Set blocking/blocked-by relations between sub-issues for the dependency DAG
6. Submit for admin approval: add label harness:admin and move Parent Issue to 'In Review'
7. After approval (harness:approved), sub-issues can be claimed and worked on

IMPORTANT: Idea and Proposal are the SAME Parent Issue. Do NOT create a separate Proposal issue.

When planning sub-agent work distribution:
- The Linear Harness auto-manages local session lifecycle -- do NOT plan to create sessions manually.
- Plan which Linear issue IDs each sub-agent will work on -- that is what the prompt needs.
- Use the Linear MCP tools (create_issue, update_issue, etc.) for all Linear operations."

"$API" hook-output "Linear Harness: plan mode -- follow proposal workflow" "$CONTEXT" "PreToolUse"
