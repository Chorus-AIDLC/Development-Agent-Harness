# Admin Agent Workflow

The Admin Agent reviews proposals, approves or rejects them, verifies completed tasks, and manages projects and cycles. This document covers all admin workflows on Linear.

---

## Prerequisites

Before starting, ensure you have:
1. Completed setup (`references/01-setup.md`)
2. Cached label UUIDs by calling `get_labels()` — you will need UUIDs for `harness:proposal`, `harness:approved`, `harness:rejected`, `harness:admin`, `harness:dev`, `harness:agent`
3. Cached workflow state UUIDs by calling `get_workflow_states({ teamId: "..." })`
4. Identified your own user/agent UUID via `get_users()`

---

## Workflow A: Proposal Review

### A.1: Find Pending Proposals

Search for proposals awaiting review:

```
search_issues({
  teamId: "team-uuid",
  status: "In Review",
  labelIds: ["harness-proposal-label-uuid", "harness-admin-label-uuid"]
})
```

### A.2: Review the Proposal

Read the Parent Issue (which serves as both Idea and Proposal) in detail:

```
get_issue({ issueId: "ENG-101" })
```

### A.3: Review the PRD

Find and read the linked document:

```
get_documents({ projectId: "project-uuid" })
get_document({ documentId: "prd-document-uuid" })
```

### A.4: Review Sub-issues (Tasks)

List all task sub-issues under the Parent Issue:

```
search_issues({
  teamId: "team-uuid",
  parentId: "ENG-101-uuid"
})
```

For each task, verify:
- Title is clear and actionable
- Description provides sufficient context
- Acceptance criteria are complete and measurable (`- [ ]` format)
- Priority is reasonable

### A.5: Review Task DAG

Check blocking relations by reading each task's details:

```
get_issue({ issueId: "task-1-uuid" })
get_issue({ issueId: "task-2-uuid" })
get_issue({ issueId: "task-3-uuid" })
get_issue({ issueId: "task-4-uuid" })
```

Verify:
- Dependencies make logical sense
- No circular dependencies exist
- The execution order is feasible

### A.6: Quality Checklist

Before making a decision, confirm:

- [ ] Proposal description clearly states the problem and solution
- [ ] PRD is complete with user stories and technical requirements
- [ ] All tasks have acceptance criteria in `- [ ]` format
- [ ] Task dependencies form a valid DAG (no cycles)
- [ ] Scope is reasonable for the timeline
- [ ] No overlap with existing work
- [ ] Security/compliance considerations addressed

### A.7a: Approve the Proposal

If the proposal meets quality standards:

**Update Parent Issue labels:**
```
update_issue({
  issueId: "ENG-101",
  labelIds: ["harness-approved-label-uuid", "harness-pm-label-uuid", "harness-agent-label-uuid"]
})
```

Note: `harness:proposal` and `harness:admin` are removed, `harness:approved` is added. The Parent Issue stays in its current state (the sub-issues are what get worked on).

**Post approval comment:**
```
create_comment({
  issueId: "ENG-101",
  body: "## Proposal Approved\n\nThis proposal meets all quality criteria:\n\n- Clear problem statement and solution scope\n- Complete PRD with user stories\n- Well-defined tasks with measurable acceptance criteria\n- Valid dependency graph\n\nMoving all tasks to Todo status for assignment."
})
```

**Move sub-issues to Todo:**

Update each task sub-issue to Todo status. This signals they are ready for Developer Agents to claim:

```
update_issue({ issueId: "task-1-uuid", status: "Todo" })
update_issue({ issueId: "task-2-uuid", status: "Todo" })
update_issue({ issueId: "task-3-uuid", status: "Todo" })
update_issue({ issueId: "task-4-uuid", status: "Todo" })
```

For many tasks, use batch update for efficiency:

```
update_issue_batch({
  issueIds: ["task-1-uuid", "task-2-uuid", "task-3-uuid", "task-4-uuid"],
  status: "Todo"
})
```

### A.7b: Reject the Proposal

If the proposal has significant issues:

**Update proposal labels:**
```
update_issue({
  issueId: "ENG-101",
  status: "Backlog",
  labelIds: ["harness-rejected-label-uuid", "harness-pm-label-uuid", "harness-agent-label-uuid"]
})
```

**Post rejection comment with specific feedback:**
```
create_comment({
  issueId: "ENG-101",
  body: "## Proposal Rejected\n\nThis proposal needs revision before approval. Specific issues:\n\n### Missing Requirements\n1. No error recovery strategy defined\n2. Acceptance criteria for Task 3 are too vague — 'dry-run mode' needs specific test scenarios\n\n### Scope Concerns\n3. The dashboard task (Task 4) scope is too broad for a single task — consider splitting into backend API and frontend UI tasks\n\n### Dependency Issues\n4. Task 2 (LDAP) should not block Task 3 (Rules Engine) — the rules engine can be developed with mock LDAP responses\n\nPlease address these issues and resubmit."
})
```

---

## Workflow B: Task Verification

### B.1: Find Tasks Pending Verification

```
search_issues({
  teamId: "team-uuid",
  status: "In Review",
  labelIds: ["harness-admin-label-uuid"]
})
```

Filter for issues that are sub-issues (have a parent) and are not proposals.

### B.2: Review the Task

Read the full issue with acceptance criteria:

```
get_issue({ issueId: "ENG-201" })
```

### B.3: Review Work Evidence

Read comments to see the developer's progress trail and self-check:

```
get_comments({ issueId: "ENG-201" })
```

Look for:
- The developer's self-check comment with all criteria marked as met
- Progress updates showing the implementation approach
- Any blocker reports and their resolutions
- References to code changes (branches, files)

### B.4: Verify Acceptance Criteria

Go through each acceptance criterion in the description:

For each `- [x]` item, verify the developer's evidence is convincing:
- Is the claimed functionality actually implemented (based on progress comments)?
- Are test coverage claims substantiated?
- Were any criteria marked done without sufficient evidence?

### B.5a: Verify (Approve) the Task

If all criteria are genuinely met:

```
update_issue({
  issueId: "ENG-201",
  status: "Done",
  labelIds: ["harness-dev-label-uuid", "harness-agent-label-uuid"]
})
```

Note: Remove `harness:admin` since review is complete.

```
create_comment({
  issueId: "ENG-201",
  body: "## Task Verified\n\nAll acceptance criteria confirmed:\n\n- [x] OAuth2 authentication — Token refresh logic verified in progress comments\n- [x] Contact list integration — Full CRUD confirmed\n- [x] Pagination — Tested with 10K records per developer report\n- [x] Rate limiting — Exponential backoff implementation confirmed\n- [x] Error handling — Structured error types with codes\n- [x] Unit tests — 94% coverage exceeds 80% threshold\n\nTask complete. Well done."
})
```

### B.5b: Reopen the Task

If criteria are not met or evidence is insufficient:

```
update_issue({
  issueId: "ENG-201",
  status: "In Progress",
  labelIds: ["harness-dev-label-uuid", "harness-agent-label-uuid"]
})
```

Note: Remove `harness:admin` — it will be re-added when the developer resubmits.

```
create_comment({
  issueId: "ENG-201",
  body: "## Verification Failed — Reopened\n\nThe following criteria need additional work:\n\n### Issues Found\n1. **Rate limiting**: The self-check mentions 'max 3 retries' but no evidence of handling 429 status codes specifically. Please add a test case for Salesforce rate limit responses.\n2. **Error handling**: Error messages should include the original Salesforce error code for debugging. Current implementation only shows generic messages.\n\n### Action Required\n- Add integration test for 429 response handling\n- Include Salesforce error codes in structured error responses\n- Resubmit when addressed"
})
```

---

## Workflow C: Project and Cycle Management

### C.1: Create Projects

When a new initiative starts, create a Linear project:

```
create_project({
  name: "Q2 Platform Modernization",
  description: "Strategic initiative to modernize the platform infrastructure.\n\n## Goals\n- Migrate to new auth system\n- Improve API performance\n- Enhance monitoring",
  teamIds: ["team-uuid"]
})
```

### C.2: Manage Cycles

Create a new sprint cycle:

```
create_cycle({
  teamId: "team-uuid",
  name: "Sprint 12",
  startsAt: "2026-03-16",
  endsAt: "2026-03-30"
})
```

List existing cycles and assign tasks:

```
get_cycles({ teamId: "team-uuid" })
update_issue({ issueId: "issue-uuid", cycleId: "cycle-uuid" })
```

### C.3: Manage Initiatives

Create strategic initiatives:

```
create_initiative({
  name: "Platform Reliability",
  description: "Improve platform reliability to 99.99% uptime"
})
get_initiatives()
```

### C.4: Close and Archive

When a project is complete:

```
update_project({
  projectId: "project-uuid",
  status: "completed"
})
```

For canceled ideas or proposals:

```
update_issue({
  issueId: "issue-uuid",
  status: "Canceled"
})
```

---

## Daily Routine

Follow this sequence each day for effective admin oversight:

### 1. Check Pending Proposals

```
search_issues({
  teamId: "team-uuid",
  labelIds: ["harness-proposal-label-uuid", "harness-admin-label-uuid"]
})
```

Review and approve or reject each proposal (Workflow A).

### 2. Check Tasks for Verification

```
search_issues({
  teamId: "team-uuid",
  status: "In Review",
  labelIds: ["harness-admin-label-uuid"]
})
```

Verify or reopen each task (Workflow B).

### 3. Review In-Progress Work

```
search_issues({
  teamId: "team-uuid",
  status: "In Progress"
})
```

Scan for stale tasks (no recent comments), blockers, or issues needing attention.

### 4. Review Project Health

```
get_projects({ teamId: "team-uuid" })
```

For each active project, check progress against cycle deadlines.

### 5. Check for Unassigned Tasks

```
search_issues({
  teamId: "team-uuid",
  status: "Todo"
})
```

If tasks have been in Todo for too long without being claimed, consider adjusting priority or reaching out to available agents.

---

## Admin Workflow Checklist

- [ ] Reviewed all pending proposals (Workflow A)
- [ ] Approved proposals with quality sign-off
- [ ] Moved approved tasks to Todo
- [ ] Rejected proposals with specific feedback
- [ ] Verified all tasks In Review (Workflow B)
- [ ] Reopened tasks with insufficient evidence
- [ ] Checked project health and cycle progress (Workflow C)
- [ ] Addressed stale or blocked work items
