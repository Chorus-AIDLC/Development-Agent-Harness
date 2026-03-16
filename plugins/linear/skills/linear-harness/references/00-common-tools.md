# Common Tools Reference — Official Linear MCP

All agents share the same set of tools provided by the official Linear MCP server at `https://mcp.linear.app/mcp`. This document covers every available tool, its parameters, and usage examples.

---

## Query Tools

### `list_issues`

List and filter issues across your workspace.

**Key Parameters:**
- `teamId` (string, optional) — Filter by team UUID
- `status` (string, optional) — Filter by workflow state name (e.g., "Triage", "In Progress")
- `assigneeId` (string, optional) — Filter by assignee UUID
- `labelIds` (string[], optional) — Filter by label UUIDs
- `projectId` (string, optional) — Filter by project UUID
- `cycleId` (string, optional) — Filter by cycle UUID

**Example — Find unassigned ideas:**
```
list_issues({
  teamId: "team-uuid",
  status: "Triage",
  labelIds: ["harness-idea-label-uuid"]
})
```

**Example — Find tasks ready for work:**
```
list_issues({
  teamId: "team-uuid",
  status: "Todo"
})
```

### `list_projects`

List projects in the workspace.

**Key Parameters:**
- `teamId` (string, optional) — Filter by team

**Example:**
```
list_projects({ teamId: "team-uuid" })
```

### `list_teams`

Get all teams in the workspace. Call this first to discover team UUIDs.

**No parameters required.**

**Example:**
```
list_teams()
```

### `list_users`

Get all workspace members.

**No parameters required.**

**Example:**
```
list_users()
```

### `list_documents`

List documents in the workspace.

**Key Parameters:**
- `projectId` (string, optional) — Filter by project

**Example:**
```
list_documents({ projectId: "project-uuid" })
```

### `list_cycles`

List cycles for a team.

**Key Parameters:**
- `teamId` (string, required) — Team UUID

**Example:**
```
list_cycles({ teamId: "team-uuid" })
```

### `list_comments`

List comments on an issue. Essential for reading elaboration threads.

**Key Parameters:**
- `issueId` (string, required) — Issue UUID

**Example:**
```
list_comments({ issueId: "issue-uuid" })
```

### `list_issue_labels`

List all labels in the workspace. Use this to find `harness:*` label UUIDs.

**No parameters required.**

**Example:**
```
list_issue_labels()
```

### `list_issue_statuses`

List workflow states for a team. Use this to discover state UUIDs for status transitions.

**Key Parameters:**
- `teamId` (string, required) — Team UUID

**Example:**
```
list_issue_statuses({ teamId: "team-uuid" })
```

### `list_project_labels`

List project-level labels.

**No parameters required.**

---

## Read Tools

### `get_issue`

Get detailed information about a single issue, including description, comments, relations, and labels.

**Key Parameters:**
- `issueId` (string, required) — Issue UUID or identifier (e.g., "ENG-123")

**Example:**
```
get_issue({ issueId: "ENG-123" })
```

**Returns:** Title, description, status, priority, assignee, labels, parent issue, sub-issues, relations (blocking/blocked-by), comments, and more.

### `get_project`

Get project details including description, status, and associated teams.

**Key Parameters:**
- `projectId` (string, required) — Project UUID

### `get_team`

Get team information including key, name, and workflow settings.

**Key Parameters:**
- `teamId` (string, required) — Team UUID

### `get_user`

Get user information. Useful for resolving assignee details.

**Key Parameters:**
- `userId` (string, required) — User UUID

### `get_document`

Get document content. Used to read PRDs linked to proposals.

**Key Parameters:**
- `documentId` (string, required) — Document UUID

### `get_issue_status`

Get details about a specific workflow state.

**Key Parameters:**
- `statusId` (string, required) — Status UUID

---

## Create Tools

### `create_issue`

Create a new issue. This is the primary tool for creating ideas, proposals, and tasks.

**Key Parameters:**
- `title` (string, required) — Issue title
- `teamId` (string, required) — Team UUID
- `description` (string, optional) — Markdown description (include acceptance criteria as `- [ ]` checklists for tasks)
- `status` (string, optional) — Workflow state name or UUID
- `priority` (number, optional) — 0=No priority, 1=Urgent, 2=High, 3=Medium, 4=Low
- `assigneeId` (string, optional) — Assignee UUID
- `labelIds` (string[], optional) — Label UUIDs to apply
- `parentId` (string, optional) — Parent issue UUID (for creating sub-issues/tasks under a proposal)
- `projectId` (string, optional) — Project UUID

**Example — Create a proposal parent issue:**
```
create_issue({
  title: "Proposal: User authentication redesign",
  teamId: "team-uuid",
  description: "## Overview\nRedesign the auth flow...\n\n## Scope\n- OAuth2 support\n- MFA\n- Session management",
  status: "Backlog",
  labelIds: ["harness-proposal-label-uuid", "harness-pm-label-uuid"],
  projectId: "project-uuid"
})
```

**Example — Create a task as sub-issue:**
```
create_issue({
  title: "Implement OAuth2 provider integration",
  teamId: "team-uuid",
  description: "## Acceptance Criteria\n- [ ] OAuth2 flow works with Google\n- [ ] OAuth2 flow works with GitHub\n- [ ] Token refresh is handled\n- [ ] Error states show user-friendly messages",
  status: "Backlog",
  parentId: "proposal-issue-uuid",
  labelIds: ["harness-dev-label-uuid"]
})
```

### `create_project`

Create a new project.

**Key Parameters:**
- `name` (string, required) — Project name
- `description` (string, optional) — Project description
- `teamIds` (string[], optional) — Associated team UUIDs

### `create_comment`

Add a comment to an issue. Used for elaboration Q&A, progress updates, and session logs.

**Key Parameters:**
- `issueId` (string, required) — Issue UUID
- `body` (string, required) — Comment body in Markdown

**Example — Elaboration question:**
```
create_comment({
  issueId: "idea-issue-uuid",
  body: "## Elaboration Questions\n\n1. What authentication providers should be supported?\n2. Is MFA a requirement for v1?\n3. What is the expected session duration?"
})
```

**Example — Progress update:**
```
create_comment({
  issueId: "task-issue-uuid",
  body: "**Progress Update**\n\nCompleted OAuth2 Google integration. Starting GitHub provider next. All tests passing."
})
```

### `create_issue_label`

Create a new label. Used by `bin/bootstrap.sh` to set up `harness:*` labels.

**Key Parameters:**
- `name` (string, required) — Label name (e.g., "harness:idea")
- `color` (string, optional) — Hex color code
- `description` (string, optional) — Label description

---

## Update Tools

### `update_issue`

Update issue fields. This is the workhorse tool for state transitions.

**Key Parameters:**
- `issueId` (string, required) — Issue UUID or identifier
- `title` (string, optional) — New title
- `description` (string, optional) — New description
- `status` (string, optional) — New workflow state
- `priority` (number, optional) — New priority
- `assigneeId` (string, optional) — New assignee UUID
- `labelIds` (string[], optional) — Replace all labels (provide full list)
- `parentId` (string, optional) — Set or change parent issue
- `cycleId` (string, optional) — Assign to a cycle

**Example — Claim a task:**
```
update_issue({
  issueId: "ENG-456",
  assigneeId: "my-user-uuid",
  status: "In Progress",
  labelIds: ["harness-dev-label-uuid", "harness-agent-label-uuid"]
})
```

**Example — Submit for verification:**
```
update_issue({
  issueId: "ENG-456",
  status: "In Review",
  labelIds: ["harness-dev-label-uuid", "harness-agent-label-uuid", "harness-admin-label-uuid"]
})
```

### `update_project`

Update project fields.

**Key Parameters:**
- `projectId` (string, required) — Project UUID
- `name` (string, optional) — New name
- `description` (string, optional) — New description
- `status` (string, optional) — Project status

---

## Search

### `search_documentation`

Search Linear's documentation and help articles.

**Key Parameters:**
- `query` (string, required) — Search query

---

## Extra CLI Tools (`bin/linear-extra.sh`)

For operations not available in the official MCP, use `bin/linear-extra.sh`. It automatically reads `LINEAR_API_KEY` from the environment — no manual auth needed.

### Issue Relations (Blocking/Blocked-by)

Create dependency relationships between issues to form task DAGs:

```bash
# Create: issueA blocks issueB
bash bin/linear-extra.sh relation create "<issueId-A>" blocks "<issueId-B>"

# Also supports: blocked-by, related, duplicate
bash bin/linear-extra.sh relation create "<issueId>" blocked-by "<blockerId>"

# List all relations for an issue
bash bin/linear-extra.sh relation list "<issueId>"

# Delete a relation
bash bin/linear-extra.sh relation delete "<relationId>"
```

### Cycle Management

```bash
# Create a cycle
bash bin/linear-extra.sh cycle create "<teamId>" "Sprint 5" "2026-03-16" "2026-03-30"

# List cycles for a team
bash bin/linear-extra.sh cycle list "<teamId>"

# Assign an issue to a cycle
bash bin/linear-extra.sh cycle assign "<issueId>" "<cycleId>"

# Remove issue from its cycle
bash bin/linear-extra.sh cycle remove "<issueId>"
```

### Initiative Management

```bash
# Create an initiative
bash bin/linear-extra.sh initiative create "Q2 Platform Modernization" "Strategic initiative for platform upgrades"

# List all initiatives
bash bin/linear-extra.sh initiative list
```

### Bulk Operations

Move multiple issues to the same status in one call:

```bash
# Get the state ID first
bash bin/linear-extra.sh states "<teamId>"

# Bulk move to Todo
bash bin/linear-extra.sh bulk-move-status "<todo-state-id>" "<issueId-1>" "<issueId-2>" "<issueId-3>"
```

This is particularly useful when approving a proposal and moving all sub-issues from Backlog to Todo.

### Utility Commands

```bash
# Get current viewer info
bash bin/linear-extra.sh viewer

# List workflow states for a team
bash bin/linear-extra.sh states "<teamId>"
```
