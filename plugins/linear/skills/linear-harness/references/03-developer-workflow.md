# Developer Agent Workflow

The Developer Agent claims tasks, implements the work, self-checks acceptance criteria, and submits for admin verification. This document covers the complete developer workflow on Linear.

---

## Prerequisites

Before starting, ensure you have:
1. Completed setup (`references/01-setup.md`)
2. Cached label UUIDs by calling `get_labels()` — you will need UUIDs for `harness:dev`, `harness:admin`, `harness:agent`
3. Cached workflow state UUIDs by calling `get_workflow_states({ teamId: "..." })`
4. Identified your own user/agent UUID via `get_users()`

---

## Step 1: Find Available Work

Search for tasks that are ready to be claimed:

```
search_issues({
  teamId: "team-uuid",
  status: "Todo"
})
```

Filter for issues with the `harness:dev` label that have no assignee. These are tasks created by a PM Agent and approved by an Admin.

You can also look for tasks with specific priority:

```
search_issues({
  teamId: "team-uuid",
  status: "Todo",
  labelIds: ["harness-dev-label-uuid"]
})
```

---

## Step 2: Check Dependencies

Before claiming a task, verify it is not blocked:

```
get_issue({ issueId: "ENG-201" })
```

Examine the issue's relations. If the issue has any **blocked-by** relations pointing to issues that are not in Done status, do not claim it. Move on to the next available task.

**Decision logic:**
- All blocking issues are Done -> safe to claim
- Any blocking issue is not Done -> skip this task, find another
- No blocking relations -> safe to claim

---

## Step 3: Claim the Task

Assign yourself, move to In Progress, and add agent labels:

```
update_issue({
  issueId: "ENG-201",
  assigneeId: "your-agent-uuid",
  status: "In Progress",
  labelIds: ["harness-dev-label-uuid", "harness-agent-label-uuid"]
})
```

---

## Step 4: Post Start Comment

Announce that work has started. This is important for observability:

```
create_comment({
  issueId: "ENG-201",
  body: "**Developer Agent started working on this issue.**\n\nReviewing requirements and acceptance criteria now."
})
```

---

## Step 5: Gather Context

Collect all information needed to complete the task.

### 5.1: Read Full Issue Details

```
get_issue({ issueId: "ENG-201" })
```

Extract:
- Description with acceptance criteria (`- [ ]` items)
- Any links to related documents
- Priority and deadline information

### 5.2: Read Elaboration Context

Check the parent issue (the proposal) for broader context:

```
get_issue({ issueId: "ENG-200" })
```

### 5.3: Read Comments for Additional Context

```
get_comments({ issueId: "ENG-201" })
```

Also read comments on the parent proposal and the original idea for full history:

```
get_comments({ issueId: "ENG-200" })
```

### 5.4: Read PRD Document

If a PRD document is linked, read it for detailed requirements:

```
get_document({ documentId: "document-uuid" })
```

### 5.5: Check Sibling Tasks

List other sub-issues under the same proposal to understand the broader scope:

```
search_issues({
  teamId: "team-uuid",
  parentId: "proposal-issue-uuid"
})
```

---

## Step 6: Work and Report Progress

While implementing the task, post periodic progress updates as comments. This serves two purposes: observability for humans and a trail for the Admin Agent during verification.

### Progress Update Pattern

Post updates at meaningful milestones, not on a fixed schedule:

```
create_comment({
  issueId: "ENG-201",
  body: "**Progress Update**\n\n- Completed OAuth2 authentication module\n- Google provider working end-to-end\n- Starting GitHub provider integration\n\nNo blockers."
})
```

### Blocker Reporting

If you encounter a blocker, report it immediately:

```
create_comment({
  issueId: "ENG-201",
  body: "**Blocker**\n\nThe Salesforce API sandbox is returning 503 errors. Unable to test connector integration.\n\nRequested: Access to a working Salesforce sandbox instance.\n\nSwitching to unit tests with mocked responses in the meantime."
})
```

### Linking to Code Changes

When work involves code, reference the Claude Code task or branch:

```
create_comment({
  issueId: "ENG-201",
  body: "**Implementation Details**\n\n- Branch: `feature/salesforce-connector`\n- CC Task: `linear:issue:ENG-201`\n- Key files: `src/connectors/salesforce.ts`, `src/connectors/salesforce.test.ts`\n\nAll unit tests passing (14/14)."
})
```

---

## Step 7: Self-Check Acceptance Criteria

Before submitting for verification, carefully review each acceptance criterion in the issue description.

### 7.1: Re-read the Issue

```
get_issue({ issueId: "ENG-201" })
```

Extract the checklist items from the description:
```
- [ ] OAuth2 authentication with Salesforce
- [ ] Contact list endpoint integration
- [ ] Pagination support for large result sets
- [ ] Rate limiting and retry logic
- [ ] Error handling with structured error responses
- [ ] Unit tests with >80% coverage
```

### 7.2: Verify Each Criterion

Go through each item and confirm it is met. If any criterion is not met, continue working until it is.

### 7.3: Post Self-Check Results

```
create_comment({
  issueId: "ENG-201",
  body: "## Acceptance Criteria Self-Check\n\n- [x] OAuth2 authentication with Salesforce — Implemented with token refresh\n- [x] Contact list endpoint integration — Full CRUD support\n- [x] Pagination support for large result sets — Cursor-based pagination, tested with 10K records\n- [x] Rate limiting and retry logic — Exponential backoff, max 3 retries\n- [x] Error handling with structured error responses — Custom error types with codes\n- [x] Unit tests with >80% coverage — 94% line coverage\n\nAll criteria met. Ready for verification."
})
```

### 7.4: Update Issue Description (Optional)

If you want to check off items in the description itself, update the description with checked boxes:

```
update_issue({
  issueId: "ENG-201",
  description: "Build a connector module for Salesforce REST API v58+.\n\n## Context\n\nPart of Proposal ENG-200. See PRD for full requirements.\n\n## Acceptance Criteria\n\n- [x] OAuth2 authentication with Salesforce\n- [x] Contact list endpoint integration\n- [x] Pagination support for large result sets\n- [x] Rate limiting and retry logic\n- [x] Error handling with structured error responses\n- [x] Unit tests with >80% coverage"
})
```

---

## Step 8: Submit for Verification

### 8.1: Move to In Review

Update the issue status and add the admin label:

```
update_issue({
  issueId: "ENG-201",
  status: "In Review",
  labelIds: ["harness-dev-label-uuid", "harness-agent-label-uuid", "harness-admin-label-uuid"]
})
```

### 8.2: Post Submission Comment

Provide a summary for the Admin reviewer:

```
create_comment({
  issueId: "ENG-201",
  body: "**Submitted for Verification**\n\nAll acceptance criteria have been met (see self-check above).\n\n### Summary of Work\n- Implemented Salesforce REST API v58 connector with OAuth2 auth\n- Full contact list integration with cursor-based pagination\n- Rate limiting with exponential backoff (max 3 retries)\n- Structured error handling with typed error responses\n- 94% unit test coverage (14 test cases)\n\n### Files Changed\n- `src/connectors/salesforce.ts` (new)\n- `src/connectors/salesforce.test.ts` (new)\n- `src/connectors/index.ts` (updated exports)\n\nReady for admin review."
})
```

---

## Step 9: Handle Feedback

If the Admin reopens the task (moves back to In Progress with feedback):

### 9.1: Read Feedback

```
get_comments({ issueId: "ENG-201" })
```

Look for the Admin's verification comment, which will contain specific feedback.

### 9.2: Acknowledge and Address

```
create_comment({
  issueId: "ENG-201",
  body: "**Acknowledged feedback.** Addressing the following:\n\n1. Add integration test for token refresh edge case\n2. Improve error message clarity for 429 responses\n\nWill resubmit once addressed."
})
```

### 9.3: Fix and Resubmit

After addressing feedback, repeat Steps 7 and 8 (self-check and submit).

---

## Step 10: Handle Unblocked Tasks

After your task is marked Done, check if any other tasks were blocked by it:

```
get_issue({ issueId: "ENG-201" })
```

Look at the issue relations for any **blocks** relations. Those issues may now be unblocked and ready for work. If you are available, you can claim the next unblocked task by going back to Step 1.

---

## Session-Aware Workflow Notes

When operating as a sub-agent in a Claude Code Agent Team:

- The plugin auto-creates your local session via `SubagentStart` hook
- Your session UUID is injected into the workflow context
- Always post Issue Comments at these key moments:
  1. When starting work on a task (Step 4)
  2. At meaningful progress milestones (Step 6)
  3. When encountering blockers (Step 6)
  4. When submitting self-check results (Step 7)
  5. When submitting for verification (Step 8)
- These Comments form the observability trail that humans and Admin Agents review
- Do not worry about session cleanup — the `SubagentStop` hook handles it

---

## Developer Workflow Checklist

- [ ] Found available task with no unresolved blockers (Steps 1-2)
- [ ] Claimed task and moved to In Progress (Step 3)
- [ ] Posted start comment (Step 4)
- [ ] Gathered full context: issue, parent, comments, PRD (Step 5)
- [ ] Implemented work with progress updates (Step 6)
- [ ] Self-checked all acceptance criteria (Step 7)
- [ ] Submitted for verification with summary (Step 8)
- [ ] Checked for newly unblocked tasks (Step 10)
