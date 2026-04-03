# Review Skill — Linear Development Harness

This skill covers the **Review** stage of the AI-DLC workflow: approving or rejecting Proposals, verifying completed Tasks with structured acceptance criteria marking, and managing project governance as an Admin Agent.

---

## Overview

The Admin Agent is the **human proxy role** — acting on behalf of the project owner to ensure quality. Key responsibilities:

- **Proposal review** — approve or reject Proposals with label stacking
- **Task verification** — verify Tasks by reviewing AC evidence, or reopen for rework
- **Project governance** — create projects, manage cycles, close/archive entities

---

## Tools

All operations use the official Linear MCP tools:

| Tool | Purpose |
|------|---------|
| `search_issues` | Find pending proposals and tasks awaiting verification |
| `get_issue` | Read proposal/task details |
| `update_issue` | Approve/reject proposals (label stacking), verify/reopen tasks |
| `update_issue_batch` | Bulk activate sub-issues to Todo on approval |
| `create_comment` | Post review feedback |
| `get_comments` | Read developer work reports and self-check evidence |
| `get_document` | Read linked PRD |
| `create_project` | Create new projects |
| `create_cycle` | Create sprint cycles |

---

## Workflow A: Proposal Review

### A1: Find Pending Proposals

Pending proposals have `harness:proposal` + `harness:admin` but neither `harness:approved` nor `harness:rejected`:

```
search_issues({
  teamId: "team-uuid",
  status: "In Review",
  labelIds: ["harness-proposal-label-uuid", "harness-admin-label-uuid"]
})
```

### A2: Review the Proposal

```
get_issue({ issueId: "ENG-101" })
```

Read: description, scope, sub-issues (tasks), linked documents.

### A3: Review PRD and Tasks

```
get_documents({ projectId: "project-uuid" })
get_document({ documentId: "prd-uuid" })
```

For each task sub-issue, verify:
- Title is clear and actionable
- Acceptance criteria are in `- [ ] AC-{n}:` format and are measurable
- Priority is set
- Dependencies form a valid DAG

### A4: Quality Checklist

Before deciding, confirm:

- [ ] Proposal description clearly states the problem and solution
- [ ] PRD is complete with requirements
- [ ] All tasks have structured acceptance criteria
- [ ] Task dependencies form a valid DAG (no cycles)
- [ ] Scope is reasonable
- [ ] No overlap with existing work

### A5a: Approve — Label Stacking

Add `harness:approved` **on top of** `harness:proposal` (do NOT remove `harness:proposal`):

```
update_issue({
  issueId: "ENG-101",
  status: "In Progress",
  labelIds: [
    "harness-proposal-label-uuid",
    "harness-approved-label-uuid",
    "harness-pm-label-uuid",
    "harness-agent-label-uuid"
  ]
})

create_comment({
  issueId: "ENG-101",
  body: "## Proposal Approved\n\nQuality criteria met:\n- Clear problem statement and solution scope\n- Complete PRD\n- Well-defined tasks with measurable AC\n- Valid dependency graph\n\nActivating all tasks to Todo."
})
```

Note: Set status to **In Progress** — the proposal is now actively being developed via its sub-issues.

**Activate sub-issues** (move from Backlog to Todo):

```
update_issue_batch({
  issueIds: ["task-1-uuid", "task-2-uuid", "task-3-uuid"],
  status: "Todo"
})
```

### A5b: Reject — Label Stacking

Add `harness:rejected` **on top of** `harness:proposal`:

```
update_issue({
  issueId: "ENG-101",
  status: "Backlog",
  labelIds: [
    "harness-proposal-label-uuid",
    "harness-rejected-label-uuid",
    "harness-pm-label-uuid",
    "harness-agent-label-uuid"
  ]
})

create_comment({
  issueId: "ENG-101",
  body: "## Proposal Rejected\n\nIssues to address:\n\n1. **Missing requirements**: No error recovery strategy in PRD\n2. **Vague AC**: Task 3 AC 'dry-run mode' needs specific test scenarios\n3. **Scope concern**: Dashboard task is too broad — consider splitting\n\nPlease revise and resubmit."
})
```

The PM will fix issues, remove `harness:rejected`, and re-add `harness:admin` to resubmit.

---

## Workflow B: Task Verification

### B1: Find Tasks Awaiting Verification

```
search_issues({
  teamId: "team-uuid",
  status: "In Review",
  labelIds: ["harness-admin-label-uuid"]
})
```

Filter for sub-issues (tasks) vs parent issues (proposals).

### B2: Review the Task

```
get_issue({ issueId: "ENG-201" })
```

Check the issue description for AC checklist and look for `harness:ac-passed` label.

### B3: Review Work Evidence

```
get_comments({ issueId: "ENG-201" })
```

Look for:
- The developer's **AC Self-Check** comment with pass/fail and evidence for each criterion
- Progress updates showing implementation approach
- References to code changes (files, commits, PRs)

### B4: Mark Acceptance Criteria

Review each AC item against the developer's evidence. Post your verification:

```
create_comment({
  issueId: "ENG-201",
  body: "## Admin AC Verification\n\n| AC | Dev Status | Admin Verdict | Notes |\n|----|-----------|---------------|-------|\n| AC-1: OAuth2 auth | PASS | PASS | Token refresh confirmed in progress comments |\n| AC-2: Contact list | PASS | PASS | Full CRUD verified |\n| AC-3: Pagination | PASS | PASS | 10K record test confirmed |\n| AC-4: Unit tests | PASS | PASS | 94% > 80% threshold |\n\n**Result: 4/4 VERIFIED**"
})
```

### B5a: Verify (Approve) the Task

If all required criteria pass:

```
update_issue({
  issueId: "ENG-201",
  status: "Done",
  labelIds: ["harness-dev-label-uuid", "harness-agent-label-uuid"]
})
```

Remove `harness:admin` and `harness:ac-passed` (task is done, labels no longer needed for filtering).

**Check for unblocked tasks:**

```
get_issue_relations({ issueId: "ENG-201" })
```

If this task blocks other tasks, check whether those downstream tasks are now fully unblocked (all their blockers are Done).

### B5b: Reopen the Task

If evidence is insufficient or criteria not met:

```
update_issue({
  issueId: "ENG-201",
  status: "In Progress",
  labelIds: ["harness-dev-label-uuid", "harness-agent-label-uuid"]
})

create_comment({
  issueId: "ENG-201",
  body: "## Verification Failed — Reopened\n\n### Issues\n1. **AC-3 (Pagination)**: No evidence of handling empty result sets\n2. **AC-4 (Tests)**: Missing integration test for token refresh edge case\n\n### Action Required\n- Add test for empty pagination results\n- Add integration test for token refresh\n- Resubmit when addressed"
})
```

Remove `harness:admin` and `harness:ac-passed`. The developer will fix, re-self-check, and resubmit.

---

## Workflow C: Project and Cycle Management

### Create Projects

```
create_project({
  name: "Q2 Platform Modernization",
  description: "Strategic initiative for platform upgrades.",
  teamIds: ["team-uuid"]
})
```

### Manage Cycles

```
create_cycle({
  teamId: "team-uuid",
  name: "Sprint 12",
  startsAt: "2026-03-16",
  endsAt: "2026-03-30"
})

get_cycles({ teamId: "team-uuid" })
update_issue({ issueId: "task-uuid", cycleId: "cycle-uuid" })
```

### Manage Initiatives

```
create_initiative({ name: "Platform Reliability", description: "..." })
get_initiatives()
```

### Close and Archive

```
update_issue({ issueId: "issue-uuid", status: "Canceled" })
archive_issue({ issueId: "issue-uuid" })
```

---

## Daily Admin Routine

1. **Check in** — `get_teams`, review workspace state
2. **Process proposals** — Review and approve/reject pending proposals (Workflow A)
3. **Verify tasks** — Review and verify/reopen tasks in In Review (Workflow B)
4. **Check project health** — Stale tasks? Blocked items? Orphaned ideas?
5. **Manage cycles** — Assign tasks to active cycles

---

## Governance Principles

1. **Quality over speed** — A rejected proposal now saves rework later
2. **Actionable feedback** — Every rejection should include specific fixes
3. **Criteria-based verification** — Verify against AC with evidence, not just subjective impression
4. **Label integrity** — Always use label stacking correctly; `harness:proposal` stays permanently
5. **Unblock the team** — Your reviews are the bottleneck; prioritize them
6. **Preserve history** — Close > Delete; comments > silent actions
7. **Verify between waves** — In Agent Teams mode, verify tasks to Done between waves to unblock dependencies

---

## Tips

- **Review thoroughly** — Don't rubber-stamp proposals
- **Give actionable feedback** — When rejecting, explain specifically what to fix
- **Check AC evidence** — Read the developer's self-check comment carefully
- **Manage scope** — Close ideas and tasks that are no longer relevant
- **Document decisions** — Use comments to explain approval/rejection reasoning

---

## Next

- For platform overview, see `/linear-harness`
- For Idea elaboration (before proposals), see `/idea`
- For Proposal creation (what you're reviewing), see `/proposal`
- For Developer workflow (what you're verifying), see `/develop`
