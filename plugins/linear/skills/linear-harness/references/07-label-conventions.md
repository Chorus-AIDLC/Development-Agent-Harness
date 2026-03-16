# Label Conventions

The Linear Development Harness uses `harness:*` labels to track AI-DLC workflow state. Labels are workspace-level and visible across all teams. This document covers every label, its lifecycle, and usage rules.

---

## Complete Label Reference

| Label | Color | Description | Applied By | Removed By |
|-------|-------|-------------|-----------|------------|
| `harness:idea` | `#8B5CF6` (purple) | Idea awaiting elaboration | Human/PM when creating idea | PM after elaboration starts |
| `harness:elaborating` | `#F59E0B` (amber) | Under AI elaboration | PM when starting Q&A | PM when elaboration complete |
| `harness:proposal` | `#3B82F6` (blue) | Proposal pending approval | PM when creating proposal | Admin on approval/rejection |
| `harness:approved` | `#10B981` (green) | Proposal approved | Admin on approval | Never removed |
| `harness:rejected` | `#EF4444` (red) | Proposal rejected | Admin on rejection | PM if resubmitting |
| `harness:pm` | `#8B5CF6` (purple) | PM Agent work item | PM when claiming work | Remains for attribution |
| `harness:dev` | `#3B82F6` (blue) | Developer Agent work item | PM when creating tasks | Remains for attribution |
| `harness:admin` | `#F59E0B` (amber) | Admin review needed | PM/Dev when requesting review | Admin after review complete |
| `harness:agent` | `#6B7280` (gray) | Assigned to AI Agent | Any agent when claiming | Remains for filtering |

---

## Label Lifecycle Diagrams

### Parent Issue Lifecycle (Idea → Proposal → Approved)

A single Parent Issue flows through all phases via label transitions:

```
Parent Issue created in Triage
  + harness:idea

PM claims
  + harness:pm, harness:agent

PM starts elaboration (Comment Q&A)
  - harness:idea
  + harness:elaborating

PM completes elaboration, creates PRD + Sub-issues
  - harness:elaborating
  + harness:proposal

PM submits for review (moves to In Review)
  + harness:admin

Admin approves
  - harness:proposal, harness:admin
  + harness:approved

  --- OR ---

Admin rejects
  - harness:proposal, harness:admin
  + harness:rejected

PM addresses feedback and resubmits
  - harness:rejected
  + harness:proposal, harness:admin
```

### Task Lifecycle

```
Task created as Sub-issue (Backlog)
  + harness:dev

Admin approves proposal, moves task to Todo
  (no label change)

Developer claims task
  + harness:agent
  (harness:dev remains)

Developer submits for verification
  + harness:admin

Admin verifies
  - harness:admin
  (harness:dev and harness:agent remain for attribution)

  --- OR ---

Admin reopens
  - harness:admin
  (Developer addresses feedback, then re-adds harness:admin)
```

---

## Rules

### Always Apply `harness:agent` on Agent-Assigned Issues

Any issue assigned to an AI agent must have the `harness:agent` label. This enables workspace-wide filtering to see all agent work:

```
list_issues({ labelIds: ["harness-agent-label-uuid"] })
```

### Role Labels Are Permanent

`harness:pm` and `harness:dev` are attribution labels. Once applied, they remain on the issue for historical tracking. Do not remove them when transitioning states.

### `harness:admin` Is Transient

`harness:admin` signals "needs admin attention." It is added when requesting review and removed after the admin acts. Never leave it on an issue after the review is complete.

### Label Updates Replace All Labels

The `update_issue` tool's `labelIds` parameter replaces the entire label list. When updating labels, always provide the complete set of labels the issue should have, not just the ones being added.

**Correct:**
```
update_issue({
  issueId: "ENG-201",
  labelIds: ["harness-dev-uuid", "harness-agent-uuid", "harness-admin-uuid"]
})
```

**Incorrect** (would remove existing labels):
```
update_issue({
  issueId: "ENG-201",
  labelIds: ["harness-admin-uuid"]
})
```

To safely add a label, first read the issue's current labels with `get_issue`, then include all existing label UUIDs plus the new one.

---

## Bootstrap

Run `bin/bootstrap.sh` to create all `harness:*` labels in your workspace. The script:

1. Reads `LINEAR_API_KEY` from the environment
2. Calls the Linear GraphQL API to create each label
3. Skips labels that already exist (idempotent)
4. Reports success/skip for each label

Labels are created at the workspace level, making them available to all teams without per-team configuration.

---

## Filtering Patterns

Common label-based queries:

| Goal | Filter |
|------|--------|
| All ideas | `labelIds: [harness:idea]` |
| Ideas under elaboration | `labelIds: [harness:elaborating]` |
| Pending proposals | `labelIds: [harness:proposal, harness:admin]` |
| Approved proposals | `labelIds: [harness:approved]` |
| All agent work | `labelIds: [harness:agent]` |
| PM work items | `labelIds: [harness:pm]` |
| Dev tasks | `labelIds: [harness:dev]` |
| Items needing admin | `labelIds: [harness:admin]` |
