# Common Tools Reference — @calltelemetry/linear-mcp

All agents share the same set of tools provided by the @calltelemetry/linear-mcp server. This document covers every available tool, its parameters, and usage examples.

---

## Query Tools

### `search_issues`

Search and filter issues across your workspace.

**Key Parameters:**
- `teamId` (string, optional) — Filter by team UUID
- `status` (string, optional) — Filter by workflow state name (e.g., "Triage", "In Progress")
- `assigneeId` (string, optional) — Filter by assignee UUID
- `labelIds` (string[], optional) — Filter by label UUIDs
- `projectId` (string, optional) — Filter by project UUID
- `cycleId` (string, optional) — Filter by cycle UUID

**Example — Find unassigned ideas:**
```
search_issues({
  teamId: "team-uuid",
  status: "Triage",
  labelIds: ["harness-idea-label-uuid"]
})
```

**Example — Find tasks ready for work:**
```
search_issues({
  teamId: "team-uuid",
  status: "Todo"
})
```

### `get_projects`

List projects in the workspace.

**Key Parameters:**
- `teamId` (string, optional) — Filter by team

**Example:**
```
get_projects({ teamId: "team-uuid" })
```

### `get_teams`

Get all teams in the workspace. Call this first to discover team UUIDs.

**No parameters required.**

**Example:**
```
get_teams()
```

### `get_users`

Get all workspace members.

**No parameters required.**

**Example:**
```
get_users()
```

### `get_documents`

List documents in the workspace.

**Key Parameters:**
- `projectId` (string, optional) — Filter by project

**Example:**
```
get_documents({ projectId: "project-uuid" })
```

### `get_cycles`

List cycles for a team.

**Key Parameters:**
- `teamId` (string, required) — Team UUID

**Example:**
```
get_cycles({ teamId: "team-uuid" })
```

### `get_comments`

List comments on an issue. Essential for reading elaboration threads.

**Key Parameters:**
- `issueId` (string, required) — Issue UUID

**Example:**
```
get_comments({ issueId: "issue-uuid" })
```

### `get_labels`

List all labels in the workspace. Use this to find `harness:*` label UUIDs.

**No parameters required.**

**Example:**
```
get_labels()
```

### `get_workflow_states`

List workflow states for a team. Use this to discover state UUIDs for status transitions.

**Key Parameters:**
- `teamId` (string, required) — Team UUID

**Example:**
```
get_workflow_states({ teamId: "team-uuid" })
```

### `get_project_labels`

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

### `get_user`

Get user information. Useful for resolving assignee details.

**Key Parameters:**
- `userId` (string, required) — User UUID

### `get_document`

Get document content. Used to read PRDs linked to proposals.

**Key Parameters:**
- `documentId` (string, required) — Document UUID

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

### `create_label`

Create a new label. Used by `bin/bootstrap.sh` to set up `harness:*` labels.

**Key Parameters:**
- `name` (string, required) — Label name (e.g., "harness:idea")
- `color` (string, optional) — Hex color code
- `description` (string, optional) — Label description

### `create_document`

Create a new document. Used for PRDs linked to proposals.

**Key Parameters:**
- `title` (string, required) — Document title
- `content` (string, required) — Document content in Markdown
- `projectId` (string, optional) — Associated project UUID

### `create_cycle`

Create a new sprint cycle.

**Key Parameters:**
- `teamId` (string, required) — Team UUID
- `name` (string, required) — Cycle name (e.g., "Sprint 12")
- `startsAt` (string, required) — Start date (ISO 8601)
- `endsAt` (string, required) — End date (ISO 8601)

**Example:**
```
create_cycle({
  teamId: "team-uuid",
  name: "Sprint 12",
  startsAt: "2026-03-16",
  endsAt: "2026-03-30"
})
```

### `create_initiative`

Create a strategic initiative.

**Key Parameters:**
- `name` (string, required) — Initiative name
- `description` (string, optional) — Initiative description

**Example:**
```
create_initiative({
  name: "Q2 Platform Modernization",
  description: "Strategic initiative for platform upgrades"
})
```

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

### `update_issue_batch`

Update multiple issues at once. Useful for bulk status transitions (e.g., moving all approved tasks to Todo).

**Key Parameters:**
- `issueIds` (string[], required) — List of issue UUIDs
- `status` (string, optional) — New workflow state
- Other fields as supported

**Example — Bulk move to Todo:**
```
update_issue_batch({
  issueIds: ["task-1-uuid", "task-2-uuid", "task-3-uuid", "task-4-uuid"],
  status: "Todo"
})
```

---

## Search

### `search_documents`

Search Linear documents.

**Key Parameters:**
- `query` (string, required) — Search query

---

## Issue Relations

Manage blocking/blocked-by relationships between issues to form task DAGs.

### `create_issue_relation`

Create a dependency relationship between two issues.

**Key Parameters:**
- `issueId` (string, required) — Source issue UUID
- `relatedIssueId` (string, required) — Target issue UUID
- `type` (string, required) — Relation type: "blocks", "blocked-by", "related", "duplicate"

**Example — issueA blocks issueB:**
```
create_issue_relation({
  issueId: "issueA-uuid",
  relatedIssueId: "issueB-uuid",
  type: "blocks"
})
```

### `get_issue_relations`

List all relations for an issue.

**Key Parameters:**
- `issueId` (string, required) — Issue UUID

**Example:**
```
get_issue_relations({ issueId: "issue-uuid" })
```

### `delete_issue_relation`

Delete an existing relation.

**Key Parameters:**
- `relationId` (string, required) — Relation UUID

**Example:**
```
delete_issue_relation({ relationId: "relation-uuid" })
```

---

## Initiative Management

### `get_initiatives`

List all initiatives.

**Example:**
```
get_initiatives()
```

---

## Notifications

### `get_notifications`

Get notifications for the authenticated user.

### `mark_notification_read`

Mark a notification as read.

**Key Parameters:**
- `notificationId` (string, required) — Notification UUID

---

## Issue Lifecycle

### `archive_issue`

Archive an issue.

**Key Parameters:**
- `issueId` (string, required) — Issue UUID

### `delete_issue`

Permanently delete an issue.

**Key Parameters:**
- `issueId` (string, required) — Issue UUID
