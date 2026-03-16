#!/bin/bash
# Output Linear API key as Authorization header in JSON format.
# Used by Claude Code's headersHelper to inject auth headers into MCP requests,
# bypassing automatic OAuth discovery.

if [ -z "$LINEAR_API_KEY" ]; then
  echo '{}' >&2
  exit 1
fi

echo "{\"Authorization\": \"Bearer $LINEAR_API_KEY\"}"
