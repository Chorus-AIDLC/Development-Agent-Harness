# Proposal Skill — Linear Development Harness

This skill covers the **Planning** stage of the AI-DLC workflow: building proposals with PRD documents and task sub-issues, managing dependency DAGs, validating completeness, and submitting for Admin review.

---

## Overview

After an Idea's elaboration is resolved (see `/idea`), the PM Agent builds a Proposal on the **same Parent Issue** — adding a PRD Document, creating task Sub-issues with acceptance criteria, and setting up the dependency DAG. The proposal goes through a label-based state machine before Admin review.

```
Elaboration resolved --> Build Proposal (draft) --> Self-validate --> Submit (+ harness:proposal) --> Admin /review
```

---

## Label State Machine

Proposals use a **label stacking model**. `harness:proposal` is an identity label that stays permanently; status labels are added on top.

| Stage | Labels on Parent Issue | Meaning |
|-------|----------------------|---------|
| **Draft** | No `harness:proposal` | PM is building — Sub-issues and Documents can be freely added/modified |
| **Submitted** | `harness:proposal` + `harness:admin` | PM self-validated and submitted; waiting for Admin review |
| **Approved** | `harness:proposal` + `harness:approved` | Admin approved; Sub-issues activated to Todo |
| **Rejected** | `harness:proposal` + `harness:rejected` | Admin rejected; PM fixes and resubmits |

**Key rules:**
- `harness:proposal` is **never removed** once added — it marks "this is a proposal" permanently
- `harness:approved` / `harness:rejected` are stacked on top, not replacements
- To resubmit after rejection: remove `harness:rejected`, re-add `harness:admin`

---

## Tools

All operations use the official Linear MCP tools:

| Tool | Purpose |
|------|---------|
| `update_issue` | Update Parent Issue labels and description |
| `create_document` | Create PRD document |
| `create_issue` | Create task Sub-issues under the Parent Issue |
| `create_issue_relation` | Set blocking/blocked-by dependencies (DAG) |
| `get_issue` | Read proposal and task details |
| `create_comment` | Post submission summary |
| `update_issue_batch` | Bulk status updates on approval |

---

## Workflow

### Step 1: Build the Proposal (Draft Phase)

The Parent Issue (from `/idea`) is in Triage/Backlog with `harness:elaborating` label. During the draft phase, freely add Documents and Sub-issues without adding `harness:proposal`.

#### 1a: Update Parent Issue Description

Update the Parent Issue with a formal proposal description:

```
update_issue({
  issueId: "ENG-101",
  description: "## Proposal: <Feature Name>\n\n### Background\n...\n\n### Scope\n- ...\n\n### Out of Scope\n- ...\n\n### Task Breakdown\nSee sub-issues for individual tasks with acceptance criteria."
})
```

#### 1b: Create PRD Document

> **Note:** The `create_document` MCP tool has a known bug. Use the `linear-api.sh` CLI wrapper instead:

```bash
bash bin/linear-api.sh create-document \
  --title "PRD: <Feature Name>" \
  --project "project-uuid" \
  --content "# PRD: <Feature Name>

## Background
...

## Requirements
### Functional
- FR-1: ...

### Non-Functional
- NFR-1: ...

## User Stories
- As a <role>, I want <action>, so that <benefit>

## Out of Scope
..."
```

Use `--project <id>` or `--team <id>` to associate the document. This calls the Linear GraphQL API directly, bypassing the MCP server bug.

**Document types** (use title prefix for categorization):
- `PRD:` — Product Requirements Document
- `Tech Design:` — Technical design document
- `ADR:` — Architecture Decision Record

#### 1c: Create Task Sub-issues

Create each task as a sub-issue under the Parent Issue. **Always include structured acceptance criteria:**

```
create_issue({
  title: "Implement OAuth2 provider integration",
  teamId: "team-uuid",
  description: "Build OAuth2 integration module.\n\n## Context\nPart of Proposal ENG-101. See PRD for full requirements.\n\n## Acceptance Criteria\n- [ ] AC-1: OAuth2 flow works with Google provider\n- [ ] AC-2: OAuth2 flow works with GitHub provider\n- [ ] AC-3: Token refresh handled automatically\n- [ ] AC-4: Error states show user-friendly messages\n- [ ] AC-5: Unit tests with >80% coverage",
  status: "Backlog",
  parentId: "ENG-101-uuid",
  labelIds: ["harness-dev-label-uuid"],
  priority: 2
})
```

**AC format**: `- [ ] AC-{n}: {description}` for required criteria. Use `- [ ] AC-{n}? {description}` (note the `?`) for optional criteria.

#### 1d: Set Task Dependencies (DAG)

```
create_issue_relation({ issueId: "task-1-uuid", relatedIssueId: "task-2-uuid", type: "blocks" })
create_issue_relation({ issueId: "task-2-uuid", relatedIssueId: "task-3-uuid", type: "blocks" })
```

### Step 2: Self-Validate Before Submitting

Before adding `harness:proposal`, verify completeness:

**Validation checklist:**
- [ ] At least 1 PRD document created
- [ ] At least 1 task sub-issue created
- [ ] Every task has acceptance criteria in `- [ ] AC-{n}:` format
- [ ] Task dependencies form a valid DAG (no cycles)
- [ ] Parent Issue description summarizes the proposal scope
- [ ] Priority is set on all tasks
- [ ] No orphan tasks (every task is either independent or has clear dependencies)

If validation fails, fix issues before proceeding.

### Step 3: Submit for Review

Add the `harness:proposal` and `harness:admin` labels to signal the proposal is ready:

```
update_issue({
  issueId: "ENG-101",
  status: "In Review",
  labelIds: [
    "harness-proposal-label-uuid",
    "harness-pm-label-uuid",
    "harness-admin-label-uuid",
    "harness-agent-label-uuid"
  ]
})
```

Post a submission summary:

```
create_comment({
  issueId: "ENG-101",
  body: "## Proposal Ready for Review\n\n**Proposal**: <Feature Name>\n**PRD**: [document title]\n\n### Task Summary\n| # | Task | Priority | Dependencies |\n|---|------|----------|--------------|\n| 1 | Salesforce connector | High | None |\n| 2 | LDAP integration | High | Task 1 |\n| 3 | Rules engine | High | Tasks 1, 2 |\n\n### DAG\n```\nTask 1 --> Task 2 --+--> Task 3\n  +----------------+\n```\n\n### Validation\n- Documents: 1 PRD\n- Tasks: 3 (all with AC)\n- Dependencies: Valid DAG\n\nPlease review and approve or provide feedback."
})
```

### Step 4: Handle Rejection

If rejected (Admin adds `harness:rejected`):

1. Read the Admin's feedback comments
2. Fix the issues (update documents, tasks, AC)
3. Resubmit by updating labels:

```
update_issue({
  issueId: "ENG-101",
  labelIds: [
    "harness-proposal-label-uuid",
    "harness-pm-label-uuid",
    "harness-admin-label-uuid",
    "harness-agent-label-uuid"
  ]
})
```

Note: Remove `harness:rejected` and re-add `harness:admin`.

### Step 5: Post-Approval

After Admin approves (adds `harness:approved`), sub-issues are moved to Todo. The PM can optionally:

1. Assign tasks to a cycle:
   ```
   update_issue({ issueId: "task-uuid", cycleId: "active-cycle-uuid" })
   ```

2. Link project to an initiative:
   ```
   get_initiatives()
   ```

3. Monitor progress:
   ```
   search_issues({ teamId: "team-uuid", projectId: "project-uuid" })
   ```

---

## Task Writing Guidelines

Good tasks are:
- **Atomic** — One clear deliverable per task
- **Testable** — Clear acceptance criteria in `- [ ] AC-{n}:` format
- **Sized** — Reasonable scope (estimate via priority: High/Medium/Low)
- **Ordered** — Use `create_issue_relation` to express execution order
- **Contextual** — Include enough context for a developer agent to start without questions

---

## Tips

- Keep PRD focused on *what* and *why*; tech design focused on *how*
- Break large features into multiple smaller tasks rather than one monolithic task
- Always set up task dependency DAG — tasks without dependencies are assumed parallelizable
- When combining multiple ideas, explain how they relate in the proposal description
- Self-validate thoroughly — rejected proposals waste everyone's time

---

## Next

- After submission, an Admin will review using `/review`
- After approval, Developers claim tasks using `/develop`
- For Idea elaboration, see `/idea`
- For platform overview, see `/linear-harness`
