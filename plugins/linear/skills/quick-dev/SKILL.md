# Quick Dev Skill — Linear Development Harness

Skip the full AI-DLC pipeline (Idea → Elaboration → Proposal → Approval) and create tasks directly. Ideal for small, well-understood work. The goal is for agents to **autonomously record their development work and verify task completion** through structured acceptance criteria.

---

## Overview

The standard AI-DLC flow ensures quality through structured planning, but adds overhead for small tasks. Quick Dev provides a lightweight alternative:

```
[check role] → create issue → claim → In Progress → report → self-check AC → submit → [self-verify if admin] → Done
```

**Use Quick Dev when:**
- Bug fixes with clear reproduction steps
- Small features (few hours of work)
- Post-delivery patches and gap-filling after a proposal's tasks are done
- Prototype or exploratory tasks
- Urgent hotfixes that can't wait for proposal review

**Do NOT use Quick Dev when:**
- The feature needs a PRD or tech design document
- Multiple interdependent tasks require upfront planning
- Stakeholder elaboration is needed to clarify requirements
- The work impacts architecture or shared components significantly

For complex work, use `/idea` + `/proposal` instead.

---

## Pre-Flight: Admin Self-Verify Check

**Before creating tasks**, if you have admin access, ask the user:

> "I have admin privileges. After development, should I verify the task myself, or leave it for another admin to verify?"

Admin agents can verify their own quick tasks to close the loop autonomously. If the user approves self-verification, you can complete the entire create → develop → verify cycle without waiting. Record the decision and apply it in Step 7.

---

## Tools

All operations use the official Linear MCP tools:

| Tool | Purpose |
|------|---------|
| `create_issue` | Create quick task(s) — standalone or under existing Parent Issue |
| `update_issue` | Claim, update status, add labels |
| `create_comment` | Report progress, post self-check |
| `get_issue` | Read task details |
| `search_issues` | Find context or verify state |

---

## Workflow

### Step 1: Create a Quick Task

**Always include structured acceptance criteria** — these are the foundation for self-checking in Step 6. Write specific, testable criteria. Vague AC like "works correctly" defeats the purpose.

```
create_issue({
  title: "Fix login redirect loop on Safari",
  teamId: "team-uuid",
  description: "Safari loses session cookie after redirect due to SameSite=Strict policy.\n\n## Acceptance Criteria\n- [ ] AC-1: Login works on Safari 17+ without redirect loop\n- [ ] AC-2: Existing Chrome/Firefox behavior unchanged\n- [ ] AC-3: Session cookie uses SameSite=Lax",
  status: "Backlog",
  labelIds: ["harness-dev-label-uuid"],
  priority: 1
})
```

**Standalone vs attached:**
- **Standalone** — Omit `parentId` for independent quick tasks (bug fixes, hotfixes)
- **Attached** — Pass `parentId` to link under an existing Parent Issue (gap-filling, follow-up patches)

### Step 2: Claim the Task

```
update_issue({
  issueId: "ENG-301",
  assigneeId: "your-agent-uuid",
  status: "In Progress",
  labelIds: ["harness-dev-label-uuid", "harness-agent-label-uuid"]
})
```

### Step 3: Work and Report Progress

```
create_comment({
  issueId: "ENG-301",
  body: "**Progress Update**\n\n**Root cause:** SameSite=Strict incompatible with OAuth redirect flow on Safari.\n**Fix:** Changed cookie policy to SameSite=Lax.\n\n**Files:** `src/middleware/cookies.ts`\n**Commit:** abc1234 \"fix: safari login redirect loop\""
})
```

### Step 4: Self-Check Acceptance Criteria

Read the task to get current AC, then post structured self-check:

```
get_issue({ issueId: "ENG-301" })

create_comment({
  issueId: "ENG-301",
  body: "## Acceptance Criteria Self-Check\n\n| AC | Status | Evidence |\n|----|--------|----------|\n| AC-1: Safari login | PASS | Tested on Safari 17.2, no redirect loop |\n| AC-2: Chrome/Firefox | PASS | Regression tests pass (12/12) |\n| AC-3: SameSite=Lax | PASS | Verified in cookie header |\n\n**Result: 3/3 PASS**"
})
```

Update the issue description to check off items:

```
update_issue({
  issueId: "ENG-301",
  description: "...\n\n## Acceptance Criteria\n- [x] AC-1: Login works on Safari 17+\n- [x] AC-2: Chrome/Firefox unchanged\n- [x] AC-3: SameSite=Lax",
  labelIds: ["harness-dev-label-uuid", "harness-agent-label-uuid", "harness-ac-passed-label-uuid"]
})
```

### Step 5: Submit for Verification

```
update_issue({
  issueId: "ENG-301",
  status: "In Review",
  labelIds: ["harness-dev-label-uuid", "harness-agent-label-uuid", "harness-ac-passed-label-uuid", "harness-admin-label-uuid"]
})

create_comment({
  issueId: "ENG-301",
  body: "**Submitted for Verification**\n\nFixed Safari login redirect loop. SameSite cookie policy changed from Strict to Lax. All AC passed (3/3)."
})
```

### Step 6: Self-Verify (Admin Only)

If you have admin access **and** the user approved self-verification in Pre-Flight:

```
update_issue({
  issueId: "ENG-301",
  status: "Done",
  labelIds: ["harness-dev-label-uuid", "harness-agent-label-uuid"]
})

create_comment({
  issueId: "ENG-301",
  body: "## Task Verified (Self)\n\nAll AC verified. Self-verification approved by user.\n\n| AC | Verdict |\n|----|---------|\n| AC-1 | PASS |\n| AC-2 | PASS |\n| AC-3 | PASS |"
})
```

This completes the full autonomous cycle: create → develop → verify → done.

---

## Session Integration

Quick Tasks work with Claude Code Agent Teams just like proposal-based tasks:

- **Team Lead**: create quick tasks, then assign to sub-agents via Linear issue identifiers
- **Sub-agents**: follow the same developer workflow — post comments at key milestones
- **Session lifecycle** is fully automated by the plugin hooks

---

## Tips

- Keep Quick Tasks small — if you need more than 2-3 tasks, consider `/proposal`
- **Always write acceptance criteria at creation** — they are your self-check contract
- Use `parentId` to attach follow-up tasks to an existing proposal for context grouping
- Quick Tasks appear in the same project task list and DAG as proposal-based tasks
- Admin agents can complete the full lifecycle autonomously — but always confirm with user first

---

## Next

- For full task lifecycle details, see `/develop`
- For admin verification, see `/review`
- For the standard planning flow, see `/idea` and `/proposal`
- For platform overview, see `/linear-harness`
