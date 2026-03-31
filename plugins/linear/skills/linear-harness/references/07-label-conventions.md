# Label Conventions

The Linear Development Harness uses `harness:*` labels to track AI-DLC workflow state. Labels are workspace-level and visible across all teams. This document covers every label, its lifecycle, and usage rules.

---

## Complete Label Reference

| Label | Color | Description | Applied By | Removed By |
|-------|-------|-------------|-----------|------------|
| `harness:idea` | `#7C3AED` (purple) | Idea awaiting elaboration | Human/PM when creating idea | PM after elaboration starts |
| `harness:elaborating` | `#F59E0B` (amber) | Under structured elaboration | PM when starting Q&A rounds | PM when elaboration complete |
| `harness:proposal` | `#3B82F6` (blue) | Proposal identity (permanent) | PM when submitting proposal | **Never removed** |
| `harness:approved` | `#10B981` (green) | Proposal approved (stacked) | Admin on approval | Never removed |
| `harness:rejected` | `#EF4444` (red) | Proposal rejected (stacked) | Admin on rejection | PM when resubmitting |
| `harness:pm` | `#8B5CF6` (purple) | PM Agent work item | PM when claiming work | Never removed (attribution) |
| `harness:dev` | `#06B6D4` (cyan) | Developer Agent work item | PM when creating tasks | Never removed (attribution) |
| `harness:admin` | `#F97316` (orange) | Admin review needed | PM/Dev when requesting review | Admin after review complete |
| `harness:agent` | `#6366F1` (indigo) | Assigned to AI Agent | Any agent when claiming | Never removed (filtering) |
| `harness:ac-passed` | `#14B8A6` (teal) | All AC self-checked as passed | Developer after self-check | Admin after verify/reopen |

---

## Label Stacking Model

Labels are **additive, not replacements**. This is the key difference from a simple state machine.

### Proposal Labels

`harness:proposal` is an **identity label** — it marks "this is a proposal" and stays permanently:

| Proposal State | Labels Present |
|---------------|---------------|
| Pending review | `harness:proposal` + `harness:admin` |
| Approved | `harness:proposal` + `harness:approved` |
| Rejected | `harness:proposal` + `harness:rejected` |
| Resubmitted | `harness:proposal` + `harness:admin` (rejected removed) |

**Filtering patterns:**
- All proposals: `labelIds: [harness:proposal]`
- Pending proposals: `harness:proposal` + `harness:admin` (without approved/rejected)
- Approved: `harness:proposal` + `harness:approved`
- Rejected: `harness:proposal` + `harness:rejected`

### Task AC Labels

`harness:ac-passed` signals that the developer has self-checked all acceptance criteria as passed:

| Task State | Labels |
|-----------|--------|
| In progress | `harness:dev` + `harness:agent` |
| AC self-checked | `harness:dev` + `harness:agent` + `harness:ac-passed` |
| Submitted for verify | `harness:dev` + `harness:agent` + `harness:ac-passed` + `harness:admin` |
| Verified (Done) | `harness:dev` + `harness:agent` |
| Reopened | `harness:dev` + `harness:agent` (ac-passed removed) |

---

## Label Lifecycle Diagrams

### Parent Issue Lifecycle (Idea → Proposal → Approved)

```
Parent Issue created in Triage
  + harness:idea

PM claims
  + harness:pm, harness:agent

PM starts elaboration (structured Comment Q&A)
  - harness:idea
  + harness:elaborating

PM completes elaboration, builds proposal (PRD + Sub-issues)
  - harness:elaborating
  + harness:proposal                    ← identity label, stays forever
  + harness:admin                       ← signals "ready for review"

Admin approves
  + harness:approved                    ← stacked on top of proposal
  - harness:admin

  --- OR ---

Admin rejects
  + harness:rejected                    ← stacked on top of proposal
  - harness:admin

PM addresses feedback and resubmits
  - harness:rejected
  + harness:admin
```

### Task Lifecycle

```
Task created as Sub-issue (Backlog)
  + harness:dev

Admin approves proposal, moves task to Todo
  (no label change)

Developer claims task
  + harness:agent

Developer self-checks AC (all passed)
  + harness:ac-passed

Developer submits for verification
  + harness:admin

Admin verifies → Done
  - harness:admin, - harness:ac-passed

  --- OR ---

Admin reopens → In Progress
  - harness:admin, - harness:ac-passed
  (Developer fixes, re-self-checks, resubmits)
```

---

## Rules

### Labels Are Additive

Never remove `harness:proposal` when approving or rejecting. Stack status labels on top.

### Role Labels Are Permanent

`harness:pm` and `harness:dev` are attribution labels. Once applied, they remain for historical tracking.

### `harness:admin` Is Transient

Added when review is needed, removed after Admin acts. Never leave on an issue after review.

### `harness:ac-passed` Is Transient

Added by developer after self-check, removed by Admin after verify or reopen.

### Label Updates Replace All Labels

The `update_issue` tool's `labelIds` replaces the **entire** label list. Always provide the complete set:

**Correct:**
```
update_issue({
  issueId: "ENG-201",
  labelIds: ["harness-dev-uuid", "harness-agent-uuid", "harness-ac-passed-uuid", "harness-admin-uuid"]
})
```

**Incorrect** (would remove existing labels):
```
update_issue({
  issueId: "ENG-201",
  labelIds: ["harness-admin-uuid"]
})
```

To safely add a label, first read the issue's current labels with `get_issue`, then include all existing UUIDs plus the new one.

---

## Bootstrap

Labels are **auto-created on first session start** by the `SessionStart` hook. No manual setup needed.

`bin/bootstrap.sh` is still available as a manual fallback for validating workflow states.

Labels are workspace-level, available to all teams without per-team configuration.

---

## Filtering Patterns

| Goal | Filter |
|------|--------|
| All ideas | `labelIds: [harness:idea]` |
| Ideas under elaboration | `labelIds: [harness:elaborating]` |
| All proposals | `labelIds: [harness:proposal]` |
| Pending proposals | `labelIds: [harness:proposal, harness:admin]` |
| Approved proposals | `labelIds: [harness:proposal, harness:approved]` |
| Rejected proposals | `labelIds: [harness:proposal, harness:rejected]` |
| All agent work | `labelIds: [harness:agent]` |
| PM work items | `labelIds: [harness:pm]` |
| Dev tasks | `labelIds: [harness:dev]` |
| Items needing admin | `labelIds: [harness:admin]` |
| Tasks with AC passed | `labelIds: [harness:ac-passed]` |
