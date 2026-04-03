# Develop Skill — Linear Development Harness

This skill covers the **Development** stage of the AI-DLC workflow: claiming Tasks, writing code, reporting progress, self-checking acceptance criteria with evidence, submitting for verification, and managing sessions for sub-agent observability.

---

## Overview

Developer Agents take Tasks created by PM Agents (via `/proposal`) or quick tasks (via `/quick-dev`) and turn them into working code. Each task follows:

```
claim --> In Progress --> report work --> self-check AC --> submit for verify --> Admin /review
```

For multi-agent parallel execution, the harness integrates with Claude Code Agent Teams (swarm mode) with full session-based observability.

---

## Tools

All operations use the official Linear MCP tools:

| Tool | Purpose |
|------|---------|
| `search_issues` | Find available tasks (status: "Todo", label: harness:dev) |
| `get_issue` | Read task details, AC, dependencies |
| `update_issue` | Claim task, update status, add labels |
| `create_comment` | Post progress updates, self-check results, submission summary |
| `get_comments` | Read context and feedback |
| `get_issue_relations` | Check blocking dependencies |
| `get_document` | Read linked PRD |

---

## Workflow

### Step 1: Find Available Work

```
search_issues({
  teamId: "team-uuid",
  status: "Todo",
  labelIds: ["harness-dev-label-uuid"]
})
```

### Step 2: Check Dependencies

Before claiming, verify the task is not blocked:

```
get_issue({ issueId: "ENG-201" })
```

Check issue relations. If any **blocked-by** relation points to an issue not in Done status, skip this task.

### Step 3: Claim the Task

```
update_issue({
  issueId: "ENG-201",
  assigneeId: "your-agent-uuid",
  status: "In Progress",
  labelIds: ["harness-dev-label-uuid", "harness-agent-label-uuid"]
})

create_comment({
  issueId: "ENG-201",
  body: "**Developer Agent started working on this issue.**\n\nReviewing requirements and acceptance criteria."
})
```

### Step 4: Gather Context

1. **Read the task** — description, acceptance criteria, priority
2. **Read the parent issue** (proposal) for broader context:
   ```
   get_issue({ issueId: "ENG-101" })
   ```
3. **Read comments** on the task and parent for discussion context
4. **Read PRD document** if linked:
   ```
   get_document({ documentId: "doc-uuid" })
   ```
5. **Check sibling tasks** under the same parent for scope awareness

### Step 5: Work and Report Progress

Post updates at meaningful milestones. Include structured information:

```
create_comment({
  issueId: "ENG-201",
  body: "**Progress Update**\n\n**Completed:**\n- OAuth2 authentication module\n- Google provider integration\n\n**Files:**\n- `src/connectors/salesforce.ts` (new)\n- `src/connectors/salesforce.test.ts` (new)\n\n**Git:**\n- Commit: abc1234 \"feat: salesforce connector\"\n- Branch: `feature/salesforce-connector`\n\n**Remaining:** GitHub provider integration\n\n**Blockers:** None"
})
```

### Step 6: Self-Check Acceptance Criteria

Before submitting, verify each AC item and post structured evidence.

#### 6a: Read the AC from Issue Description

```
get_issue({ issueId: "ENG-201" })
```

Extract the checklist:
```
- [ ] AC-1: OAuth2 authentication with Salesforce
- [ ] AC-2: Contact list endpoint integration
- [ ] AC-3: Pagination support for large result sets
- [ ] AC-4: Unit tests with >80% coverage
```

#### 6b: Post Self-Check with Evidence

For each criterion, provide a `pass`/`fail` status and evidence:

```
create_comment({
  issueId: "ENG-201",
  body: "## Acceptance Criteria Self-Check\n\n| AC | Status | Evidence |\n|----|--------|----------|\n| AC-1: OAuth2 auth | PASS | Token refresh + error handling implemented, tested in `salesforce.test.ts` |\n| AC-2: Contact list | PASS | Full CRUD support, cursor-based pagination |\n| AC-3: Pagination | PASS | Tested with 10K records, avg 200ms/page |\n| AC-4: Unit tests | PASS | 94% line coverage (threshold: 80%) |\n\n**Result: 4/4 PASS** — All required criteria met."
})
```

#### 6c: Update Issue Description (check off items)

```
update_issue({
  issueId: "ENG-201",
  description: "...\n\n## Acceptance Criteria\n- [x] AC-1: OAuth2 authentication with Salesforce\n- [x] AC-2: Contact list endpoint integration\n- [x] AC-3: Pagination support for large result sets\n- [x] AC-4: Unit tests with >80% coverage"
})
```

#### 6d: Add AC-Passed Label

If all required criteria pass, add the `harness:ac-passed` label:

```
update_issue({
  issueId: "ENG-201",
  labelIds: ["harness-dev-label-uuid", "harness-agent-label-uuid", "harness-ac-passed-label-uuid"]
})
```

### Step 7: Submit for Verification

```
update_issue({
  issueId: "ENG-201",
  status: "In Review",
  labelIds: ["harness-dev-label-uuid", "harness-agent-label-uuid", "harness-ac-passed-label-uuid", "harness-admin-label-uuid"]
})

create_comment({
  issueId: "ENG-201",
  body: "**Submitted for Verification**\n\nAll acceptance criteria met (4/4 PASS). See self-check above.\n\n### Summary\n- Implemented Salesforce REST API v58 connector\n- OAuth2 with token refresh\n- Cursor-based pagination\n- 94% unit test coverage\n\n### Files Changed\n- `src/connectors/salesforce.ts` (new)\n- `src/connectors/salesforce.test.ts` (new)\n- `src/connectors/index.ts` (updated)\n\nReady for admin review."
})
```

### Step 8: Handle Feedback

If the Admin reopens the task (moves back to In Progress):

1. Read feedback: `get_comments({ issueId: "ENG-201" })`
2. Address issues, remove `harness:ac-passed` label
3. Re-run self-check (Step 6) and resubmit (Step 7)

### Step 9: Check for Unblocked Tasks

After your task is marked Done, check for tasks that were blocked by it:

```
get_issue_relations({ issueId: "ENG-201" })
```

Look for **blocks** relations. Those downstream issues may now be unblocked and ready for work.

---

## Session-Aware Workflow (Sub-Agents)

When operating as a sub-agent in a Claude Code Agent Team:

- The plugin auto-creates your local session via `SubagentStart` hook
- Always post Issue Comments at key moments:
  1. When starting work (Step 3)
  2. At progress milestones (Step 5)
  3. When self-checking AC (Step 6)
  4. When submitting for verification (Step 7)
- These Comments form the observability trail
- Do not worry about session cleanup — `SubagentStop` handles it

---

## Claude Code Agent Teams Integration

### Team Lead Workflow

```
# 1. Plan work
search_issues({ teamId: "team-uuid", status: "Todo", labelIds: ["harness-dev-label-uuid"] })

# 2. Check DAG — find Wave 1 (no unresolved blockers)
get_issue({ issueId: "task-1-uuid" })
get_issue({ issueId: "task-2-uuid" })

# 3. Claim tasks BEFORE spawning — set assignee and status
update_issue({ issueId: "ENG-201", assigneeId: "me", status: "In Progress", labelIds: ["harness-dev-label-uuid", "harness-agent-label-uuid"] })
update_issue({ issueId: "ENG-202", assigneeId: "me", status: "In Progress", labelIds: ["harness-dev-label-uuid", "harness-agent-label-uuid"] })

# 4. Spawn sub-agents — MUST include full workflow instructions
Task({
  name: "worker-1",
  prompt: "Implement Salesforce connector.\nLinear issue: linear:issue:ENG-201\n\nAfter completing the implementation, you MUST follow the full submission workflow:\n1. Self-check each AC item with evidence (post as comment)\n2. Check off AC items in the issue description\n3. Add harness:ac-passed label\n4. Submit for verification: set status to 'In Review', add harness:admin label\n5. Post a submission summary comment\n\nDo NOT just move the status — the labels trigger automated review agents."
})
```

**Important:**
- The Team Lead must claim tasks (assign + set In Progress) **before** spawning sub-agents. Sub-agents may not have permission to self-assign, and unclaimed tasks have no assignee trail.
- The spawn prompt **must include the submission workflow** (self-check → ac-passed label → admin label → In Review). Sub-agents do not automatically read the `/develop` skill, so label and status steps must be explicit in the prompt. Without these labels, the PostToolUse hook cannot trigger review agents.

**Wave-based execution:**
1. Claim and spawn Wave 1 workers (tasks with no blockers)
2. Wait for completion — check via `get_comments`
3. After Wave 1 tasks are Done, find newly unblocked tasks
4. Claim and spawn Wave 2 workers
5. Repeat until all tasks complete

### Linking CC Tasks to Linear Issues

Always include `linear:issue:<identifier>` in the Claude Code task description:
- `linear:issue:ENG-201` (preferred — human readable)
- `linear:issue:a1b2c3d4-...` (UUID format also works)

---

## Work Report Best Practices

**Good report:**
```
Implemented password reset flow:

Files: src/services/auth.service.ts (new), src/app/api/auth/reset/route.ts (new)
Git: Commit a1b2c3d "feat: password reset", PR #15
Tests: 12 new tests, all passing

AC Status:
- [x] AC-1: User can request reset via email
- [x] AC-2: Reset link expires after 1 hour
- [x] AC-3: Rate limiting prevents abuse
```

**Bad report:** `Done.`

---

## Tips

- **Read task comments first** — they contain previous work reports for context
- **Check upstream dependencies** — read blocking tasks and their comments
- **Read the originating proposal** — understand design intent
- Report progress frequently — include file paths, commits, and PRs
- Write detailed submit summaries — Admin needs them to verify
- One task at a time: finish or release before claiming another

---

## Next

- After submitting, an Admin reviews using `/review`
- For platform overview, see `/linear-harness`
