#!/usr/bin/env bash
# on-pre-exit-plan.sh — PreToolUse hook for ExitPlanMode
# Reminds to create a Linear Proposal Parent Issue before implementation.
#
# Output: JSON with additionalContext

set -euo pipefail

[ -z "${LINEAR_API_KEY:-}" ] && exit 0

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
API="${SCRIPT_DIR}/linear-api.sh"

CONTEXT="[Linear Harness -- Pre-Implementation Check]
Before exiting plan mode, ensure:
1. A Parent Issue exists with label harness:proposal (transitioned from harness:idea)
2. Task Sub-issues are created under the Parent Issue with acceptance criteria
3. A PRD Document has been created
4. Blocking/blocked-by relations form a proper dependency DAG
5. The Parent Issue has been moved to 'In Review' with label harness:admin for approval
IMPORTANT: Idea and Proposal are the SAME Parent Issue -- do not create a separate Proposal issue."

"$API" hook-output "" "$CONTEXT" "PreToolUse"
