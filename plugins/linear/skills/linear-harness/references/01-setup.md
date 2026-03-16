# Setup Guide

This guide walks through configuring the Linear Development Harness for first use.

---

## Step 1: Create a Linear API Key

1. Open Linear and navigate to **Settings > Account > Security & Access**
2. Under **API Keys**, click **Create Key**
3. Give it a descriptive name (e.g., "AI Agent Harness")
4. Copy the key — it starts with `lin_api_` and is shown only once

## Step 2: Set Environment Variables

Export the API key so the plugin and MCP server can access it:

```bash
export LINEAR_API_KEY="lin_api_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

Optionally, set a default team to avoid passing `teamId` in every call:

```bash
export LINEAR_TEAM_ID="your-team-uuid"
```

Add these to your shell profile (`~/.zshrc`, `~/.bashrc`) for persistence.

## Step 3: Configure MCP Server

Add the official Linear MCP server to your `.mcp.json` (project root or `~/.claude/.mcp.json`):

```json
{
  "mcpServers": {
    "linear": {
      "type": "http",
      "url": "https://mcp.linear.app/mcp",
      "headers": {
        "Authorization": "Bearer ${LINEAR_API_KEY}"
      }
    }
  }
}
```

The `${LINEAR_API_KEY}` variable is resolved from your environment at runtime.

## Step 4: Verify Connection

Call `list_teams` to confirm the MCP connection works:

```
list_teams()
```

You should see your workspace teams with their UUIDs, keys, and names. If you get an authentication error, verify your `LINEAR_API_KEY` is set correctly.

## Step 5: Run Bootstrap

The bootstrap script creates all `harness:*` labels in your Linear workspace:

```bash
bin/bootstrap.sh
```

This creates the following labels (if they do not already exist):
- `harness:idea`
- `harness:elaborating`
- `harness:proposal`
- `harness:approved`
- `harness:rejected`
- `harness:pm`
- `harness:dev`
- `harness:admin`
- `harness:agent`

The script is idempotent — running it multiple times will not create duplicate labels.

## Step 6: Verify Labels

Confirm labels were created:

```
list_issue_labels()
```

You should see all `harness:*` labels in the output. Note down the UUIDs — you will need them when filtering issues by label.

## Step 7: Verify Workflow States

Check that your team has the required workflow states:

```
list_issue_statuses({ teamId: "your-team-uuid" })
```

Expected states: Triage, Backlog, Todo, In Progress, In Review, Done, Canceled.

If **In Review** is missing, add it manually in Linear under **Settings > Teams > [Your Team] > Workflow**. Place it between "In Progress" and "Done" in the workflow order.

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| "Unauthorized" error | Invalid or missing API key | Verify `LINEAR_API_KEY` is exported and correct |
| No teams returned | API key has no workspace access | Create a new key with workspace access |
| Labels not found after bootstrap | Bootstrap script failed silently | Check script output; ensure `LINEAR_API_KEY` is set |
| "In Review" state not found | Custom state not created | Add it manually in team workflow settings |
| MCP connection timeout | Network or URL issue | Verify `https://mcp.linear.app/mcp` is reachable |
