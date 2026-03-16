# PM Agent Workflow

The PM Agent is responsible for discovering ideas, elaborating requirements through stakeholder Q&A, and turning ideas into proposals with tasks and PRDs. This document covers the complete PM workflow on Linear.

**Key concept**: A single Parent Issue serves as both Idea and Proposal. Labels on this issue track its lifecycle phase (`harness:idea` → `harness:elaborating` → `harness:proposal` → `harness:approved`). Tasks are Sub-issues; PRDs are Documents.

---

## Prerequisites

Before starting, ensure you have:
1. Completed setup (`references/01-setup.md`)
2. Cached label UUIDs by calling `get_labels()` — you will need UUIDs for `harness:idea`, `harness:elaborating`, `harness:proposal`, `harness:pm`, `harness:admin`, `harness:agent`
3. Cached workflow state UUIDs by calling `get_workflow_states({ teamId: "..." })`
4. Identified your own user/agent UUID via `get_users()`

---

## Phase 1: Find and Claim Ideas

### Step 1.1: Discover Available Ideas

Search for issues in Triage with the `harness:idea` label:

```
search_issues({
  teamId: "team-uuid",
  status: "Triage",
  labelIds: ["harness-idea-label-uuid"]
})
```

This returns all ideas awaiting elaboration. Review the list and select one to work on.

### Step 1.2: Read the Idea

Get full details of the selected idea:

```
get_issue({ issueId: "ENG-101" })
```

Review the title, description, and any existing comments to understand the request.

### Step 1.3: Claim the Idea

Assign yourself and mark it as PM work:

```
update_issue({
  issueId: "ENG-101",
  assigneeId: "your-agent-uuid",
  labelIds: ["harness-idea-label-uuid", "harness-pm-label-uuid", "harness-agent-label-uuid"]
})
```

### Step 1.4: Post Claim Comment

Announce that you are starting elaboration:

```
create_comment({
  issueId: "ENG-101",
  body: "**PM Agent claimed this idea for elaboration.**\n\nI will analyze this request and post elaboration questions shortly."
})
```

---

## Phase 2: Elaborate Requirements

### Step 2.1: Update Labels for Elaboration

Transition the idea into elaboration state:

```
update_issue({
  issueId: "ENG-101",
  labelIds: ["harness-elaborating-label-uuid", "harness-pm-label-uuid", "harness-agent-label-uuid"]
})
```

Note: `harness:idea` is removed and replaced with `harness:elaborating`.

### Step 2.2: Post Elaboration Questions

Create a structured comment with questions for stakeholders:

```
create_comment({
  issueId: "ENG-101",
  body: "## Elaboration Questions\n\nTo create a complete proposal, I need clarification on the following:\n\n### Scope\n1. What is the primary user persona for this feature?\n2. Are there any existing systems this needs to integrate with?\n3. What is the expected timeline for delivery?\n\n### Technical\n4. Are there any technology constraints or preferences?\n5. What is the expected data volume / scale?\n6. Are there performance requirements (latency, throughput)?\n\n### Business\n7. What is the success metric for this feature?\n8. Are there any compliance or security requirements?\n\nPlease reply to each question. I will proceed with proposal creation once I have sufficient context."
})
```

### Step 2.3: Wait for Responses

Poll for new comments periodically:

```
get_comments({ issueId: "ENG-101" })
```

Review each new comment for answers to your questions. If answers are incomplete, post follow-up questions:

```
create_comment({
  issueId: "ENG-101",
  body: "Thank you for the responses. A few follow-ups:\n\n- Regarding Q2: You mentioned Salesforce integration. Is this via REST API or a specific SDK?\n- Regarding Q5: Could you quantify 'large scale'? Are we talking thousands or millions of records per day?"
})
```

### Step 2.4: Summarize Elaboration

Once all questions are answered, post a summary:

```
create_comment({
  issueId: "ENG-101",
  body: "## Elaboration Summary\n\nBased on our discussion, here is the consolidated understanding:\n\n- **User Persona**: Enterprise admin managing team access\n- **Integration**: Salesforce REST API + internal LDAP\n- **Scale**: ~50K records/day\n- **Timeline**: Q2 2026\n- **Success Metric**: 90% reduction in manual provisioning time\n- **Constraints**: Must comply with SOC2, no PII in logs\n\nI will now create a formal proposal with tasks and PRD."
})
```

### Step 2.5: Summarize and Transition to Proposal

Elaboration is done. Now transition the **same Parent Issue** into a Proposal by updating its description and labels:

```
update_issue({
  issueId: "ENG-101",
  description: "## Proposal: Automated user provisioning via Salesforce + LDAP\n\n### Background\n\nEnterprise admins currently spend 4+ hours/week on manual provisioning.\n\n### Scope\n\n- Salesforce REST API connector\n- LDAP write integration\n- Provisioning rules engine\n- Audit logging (SOC2 compliant)\n- Admin dashboard for monitoring\n\n### Out of Scope\n\n- De-provisioning (phase 2)\n- Non-Salesforce CRM support\n\n### Task Breakdown\n\nSee sub-issues for individual tasks with acceptance criteria.",
  labelIds: ["harness-proposal-label-uuid", "harness-pm-label-uuid", "harness-agent-label-uuid"]
})
```

Note: `harness:elaborating` is replaced with `harness:proposal` on the **same issue**. No separate Proposal issue is created.

---

## Phase 3: Add PRD and Tasks to the Parent Issue

The Parent Issue (ENG-101) is now the Proposal container. Add the PRD as a Document and tasks as Sub-issues.

### Step 3.1: Create PRD Document

Create a detailed requirements document:

```
create_document({
  title: "PRD: Automated User Provisioning",
  content: "# Automated User Provisioning — Product Requirements Document\n\n## 1. Problem Statement\n\nEnterprise admins spend 4+ hours/week manually provisioning users...\n\n## 2. Goals\n\n- Reduce manual provisioning time by 90%\n- Maintain SOC2 compliance\n- Support 50K records/day throughput\n\n## 3. User Stories\n\n### US-1: Admin configures Salesforce connection\nAs an enterprise admin, I want to configure my Salesforce credentials so that the system can pull contact data automatically.\n\n### US-2: Admin defines provisioning rules\nAs an enterprise admin, I want to define rules mapping Salesforce fields to LDAP attributes.\n\n### US-3: Admin monitors provisioning jobs\nAs an enterprise admin, I want a dashboard showing provisioning status, errors, and audit logs.\n\n## 4. Technical Requirements\n\n- Salesforce REST API v58+ connector\n- LDAP v3 write support\n- Job queue with retry logic\n- Structured audit logs (no PII)\n\n## 5. Non-Functional Requirements\n\n- Latency: < 5s per provisioning operation\n- Throughput: 50K records/day\n- Availability: 99.9% uptime\n- Security: SOC2 Type II compliant",
  projectId: "project-uuid"
})
```

### Step 3.3: Create Task Sub-issues

Create each task as a sub-issue under the proposal. Include acceptance criteria as Markdown checklists.

**Task 1: Salesforce Connector**
```
create_issue({
  title: "Implement Salesforce REST API connector",
  teamId: "team-uuid",
  description: "Build a connector module for Salesforce REST API v58+.\n\n## Context\n\nPart of Idea/Proposal ENG-101. See PRD for full requirements.\n\n## Acceptance Criteria\n\n- [ ] OAuth2 authentication with Salesforce\n- [ ] Contact list endpoint integration\n- [ ] Pagination support for large result sets\n- [ ] Rate limiting and retry logic\n- [ ] Error handling with structured error responses\n- [ ] Unit tests with >80% coverage",
  status: "Backlog",
  parentId: "ENG-101",
  labelIds: ["harness-dev-label-uuid"],
  priority: 2
})
```

**Task 2: LDAP Integration**
```
create_issue({
  title: "Implement LDAP write integration",
  teamId: "team-uuid",
  description: "Build LDAP v3 write module for user provisioning.\n\n## Context\n\nPart of Idea/Proposal ENG-101. Depends on Salesforce connector for input data.\n\n## Acceptance Criteria\n\n- [ ] LDAP bind with service account credentials\n- [ ] Create user operation\n- [ ] Update user attributes operation\n- [ ] Connection pooling\n- [ ] Graceful error handling for LDAP failures\n- [ ] Integration tests against test LDAP server",
  status: "Backlog",
  parentId: "ENG-101",
  labelIds: ["harness-dev-label-uuid"],
  priority: 2
})
```

**Task 3: Rules Engine**
```
create_issue({
  title: "Build provisioning rules engine",
  teamId: "team-uuid",
  description: "Create a configurable rules engine for mapping Salesforce fields to LDAP attributes.\n\n## Context\n\nPart of Idea/Proposal ENG-101. Depends on both Salesforce connector and LDAP integration.\n\n## Acceptance Criteria\n\n- [ ] Rule definition schema (JSON-based)\n- [ ] Field mapping support (1:1, computed, conditional)\n- [ ] Rule validation on save\n- [ ] Dry-run mode for testing rules\n- [ ] Audit log for rule changes\n- [ ] Unit tests for all mapping types",
  status: "Backlog",
  parentId: "ENG-101",
  labelIds: ["harness-dev-label-uuid"],
  priority: 2
})
```

**Task 4: Admin Dashboard**
```
create_issue({
  title: "Build admin monitoring dashboard",
  teamId: "team-uuid",
  description: "Create a dashboard for monitoring provisioning jobs.\n\n## Context\n\nPart of Idea/Proposal ENG-101. Depends on rules engine being functional.\n\n## Acceptance Criteria\n\n- [ ] Job list view with status, timestamps, record counts\n- [ ] Error detail view with stack traces (no PII)\n- [ ] Audit log viewer with filtering\n- [ ] Manual retry button for failed jobs\n- [ ] Real-time status updates\n- [ ] Responsive layout for desktop and tablet",
  status: "Backlog",
  parentId: "ENG-101",
  labelIds: ["harness-dev-label-uuid"],
  priority: 3
})
```

### Step 3.4: Set Task Dependencies (DAG)

Use `create_issue_relation` to create blocking relations between tasks:

```
# Task 1 blocks Task 2 (LDAP depends on Salesforce)
create_issue_relation({ issueId: "task-1-uuid", relatedIssueId: "task-2-uuid", type: "blocks" })

# Task 1 and Task 2 both block Task 3 (Rules Engine depends on both)
create_issue_relation({ issueId: "task-1-uuid", relatedIssueId: "task-3-uuid", type: "blocks" })
create_issue_relation({ issueId: "task-2-uuid", relatedIssueId: "task-3-uuid", type: "blocks" })

# Task 3 blocks Task 4 (Dashboard depends on Rules Engine)
create_issue_relation({ issueId: "task-3-uuid", relatedIssueId: "task-4-uuid", type: "blocks" })
```

Verify the DAG:
```
get_issue_relations({ issueId: "task-3-uuid" })
```

This creates the DAG: Task 1 -> Task 2 -> Task 3 -> Task 4 (with Task 3 also depending on Task 1).

---

## Phase 4: Submit for Approval

### Step 4.1: Move to In Review with Admin Label

Flag the Parent Issue for admin review:

```
update_issue({
  issueId: "ENG-101",
  status: "In Review",
  labelIds: ["harness-proposal-label-uuid", "harness-pm-label-uuid", "harness-admin-label-uuid", "harness-agent-label-uuid"]
})
```

### Step 4.2: Post Submission Comment

Summarize the proposal for the reviewer:

```
create_comment({
  issueId: "ENG-101",
  body: "## Proposal Ready for Review\n\n**Proposal**: Automated user provisioning via Salesforce + LDAP\n**PRD**: [Linked document]\n\n### Task Summary\n| # | Task | Priority | Dependencies |\n|---|------|----------|--------------|\n| 1 | Salesforce REST API connector | High | None |\n| 2 | LDAP write integration | High | Task 1 |\n| 3 | Provisioning rules engine | High | Tasks 1, 2 |\n| 4 | Admin monitoring dashboard | Medium | Task 3 |\n\n### DAG\n```\nTask 1 (Salesforce) --+--> Task 2 (LDAP) --+--> Task 3 (Rules) --> Task 4 (Dashboard)\n                      +--------------------+\n```\n\nPlease review and approve or provide feedback."
})
```

---

## Phase 5: Post-Approval

After an Admin approves the Parent Issue (adds `harness:approved`, removes `harness:proposal`):

### Step 5.1: Assign Tasks to Cycle

If there is an active cycle, assign tasks to it:

```
update_issue({ issueId: "task-1-uuid", cycleId: "active-cycle-uuid" })
update_issue({ issueId: "task-2-uuid", cycleId: "active-cycle-uuid" })
update_issue({ issueId: "task-3-uuid", cycleId: "active-cycle-uuid" })
update_issue({ issueId: "task-4-uuid", cycleId: "active-cycle-uuid" })
```

### Step 5.2: Link to Initiative

If the proposal belongs to a strategic initiative:
```
get_initiatives()
# then link project to initiative via Linear UI or API
```

### Step 5.3: Monitor Progress

Periodically check task status:

```
search_issues({
  teamId: "team-uuid",
  projectId: "project-uuid"
})
```

Review comments on in-progress tasks to stay informed:

```
get_comments({ issueId: "task-uuid" })
```

---

## PM Workflow Checklist

Use this checklist to track your progress through the workflow:

- [ ] Found and claimed an idea — Parent Issue with `harness:idea` (Phase 1)
- [ ] Posted elaboration questions on the Parent Issue (Phase 2)
- [ ] Received and processed all answers
- [ ] Summarized elaboration, transitioned Parent Issue to `harness:proposal`
- [ ] Created PRD Document (Phase 3)
- [ ] Created all task Sub-issues under the Parent Issue with acceptance criteria
- [ ] Set blocking relations (DAG)
- [ ] Submitted Parent Issue for admin review — In Review + `harness:admin` (Phase 4)
- [ ] Post-approval: assigned tasks to cycle (Phase 5)
