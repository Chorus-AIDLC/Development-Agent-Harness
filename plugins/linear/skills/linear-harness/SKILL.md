# Linear Development Harness — Core Skill

The Linear Development Harness brings the **AI-DLC (AI-Driven Development Lifecycle)** workflow to [Linear](https://linear.app). It is part of the [Chorus AI-DLC](https://github.com/Chorus-AIDLC/Chorus) ecosystem — a collaboration platform for AI Agents and humans.

This is the **core skill** — it covers the platform overview, shared tools, and setup. For stage-specific workflows, use the dedicated skills listed in [Skill Routing](#skill-routing).

---

## AI-DLC Workflow on Linear

The workflow uses a **single Parent Issue** as the container for the entire lifecycle — from Idea through Proposal to completion. Labels on this Parent Issue track the current phase. Tasks are Sub-issues; PRDs are Documents.

```
Idea --> Elaboration --> Proposal --> Approval --> Tasks --> Execute --> Verify --> Done
 ^            ^             ^           ^           ^          ^          ^         ^
Human      PM Agent      PM Agent    Admin       Admin     Dev Agent    Admin    Admin
creates    Q&A rounds    PRD+tasks   reviews     activates  codes &    reviews   closes
           on issue      + DAG       proposal    sub-issues reports    & marks AC
```

Core philosophy: **"Reversed Conversation"** — AI proposes, humans verify.

---

## Three Agent Roles

| Role | Responsibility | Key Labels |
|------|---------------|------------|
| **PM Agent** | Discovers ideas, runs structured elaboration, creates proposals with tasks and PRDs | `harness:pm` |
| **Developer Agent** | Claims tasks, implements work, self-checks acceptance criteria, submits for review | `harness:dev` |
| **Admin Agent** | Reviews proposals, approves/rejects, verifies tasks with AC marking, manages projects | `harness:admin` |

All agents share the same official Linear MCP tools. Role differentiation comes from which workflow steps each agent performs and which labels they apply.

---

## Shared Linear MCP Tools

All agents connect to the @calltelemetry/linear-mcp server. Available tool categories:

- **Query**: `search_issues`, `get_projects`, `get_teams`, `get_users`, `get_documents`, `get_cycles`, `get_comments`, `get_labels`, `get_workflow_states`, `get_project_labels`
- **Read**: `get_issue`, `get_user`, `get_document`
- **Create**: `create_issue`, `create_project`, `create_comment`, `create_label`, `create_document`, `create_cycle`, `create_initiative`
- **Update**: `update_issue`, `update_project`, `update_issue_batch`
- **Search**: `search_documents`
- **Relations**: `create_issue_relation`, `get_issue_relations`, `delete_issue_relation`
- **Other**: `get_initiatives`, `get_notifications`, `mark_notification_read`, `archive_issue`, `delete_issue`

See `references/00-common-tools.md` for full tool reference.

---

## Label Conventions

The harness uses `harness:*` labels to track AI-DLC state. Labels are workspace-level and visible across all teams.

| Label | Purpose |
|-------|---------|
| `harness:idea` | Idea awaiting elaboration |
| `harness:elaborating` | Under structured elaboration |
| `harness:proposal` | Proposal submitted for approval |
| `harness:approved` | Proposal approved (stacked with `harness:proposal`) |
| `harness:rejected` | Proposal rejected (stacked with `harness:proposal`) |
| `harness:pm` | PM Agent work item |
| `harness:dev` | Developer Agent work item |
| `harness:admin` | Admin review needed |
| `harness:agent` | Assigned to AI Agent (always present on agent-assigned issues) |
| `harness:ac-passed` | All acceptance criteria self-checked as passed |

### Label Stacking Model

Labels are **additive, not replacements**. Key rules:

- `harness:proposal` is an **identity label** — it stays on the Parent Issue permanently once submitted
- `harness:approved` / `harness:rejected` are **status labels** stacked on top of `harness:proposal`
- Pending proposals = `harness:proposal` without approved or rejected
- `harness:pm`, `harness:dev` are **attribution labels** — never removed
- `harness:admin` is **transient** — added when review needed, removed after review complete

Labels are **auto-created on first session start** — no manual setup needed. See `references/07-label-conventions.md` for full lifecycle details.

---

## Workflow State Mapping

| Linear State | AI-DLC Meaning |
|-------------|----------------|
| Triage | Idea (needs elaboration) |
| Backlog | Draft / Elaborated (building proposal) |
| Todo | Open (ready for assignment) |
| In Progress | In progress (agent working) |
| In Review | Verify (pending admin verification) |
| Done | Completed and verified |
| Canceled | Closed |

---

## Session and Observability

Agent sessions are managed **locally** by the plugin:

- `.linear-harness/sessions/` contains session metadata files
- Plugin hooks (`SubagentStart`, `SubagentStop`, `TeammateIdle`) manage lifecycle automatically
- Key events are posted as **Issue Comments** for human visibility
- No server-side session state — purely client-side with a Comment trail

---

## Execution Rules

1. **Always check viewer info first.** Call `get_teams` or `get_user` to confirm your identity and workspace context.

2. **Use label conventions — never skip `harness:*` labels.** Every AI-DLC state transition must have the correct label change. Labels are the primary filtering mechanism.

3. **A single Parent Issue is both Idea and Proposal.** The same issue transitions through `harness:idea` → `harness:elaborating` → `harness:proposal` → `harness:proposal` + `harness:approved`.

4. **Labels are additive.** `harness:proposal` stays permanently. `harness:approved` / `harness:rejected` are stacked on top — never remove `harness:proposal` when approving or rejecting.

5. **Elaboration uses structured Comment threads.** Post questions as structured Markdown with round numbers and categories. Track rounds via local state.

6. **Acceptance criteria use structured Markdown checklists.** Task descriptions must include `- [ ] AC-{n}: {description}` items. Self-check with evidence before submitting.

7. **Sessions are auto-managed by plugin hooks.** Do not manually create or destroy sessions.

8. **Link CC tasks to Linear issues with `linear:issue:<identifier>` in description.**

9. **Use blocking/blocked-by relations for task DAGs.** Issue relations define execution order. Never start a task with unresolved blockers.

10. **Leverage Cycles and Initiatives.** Assign tasks to Cycles for sprint planning; group Projects under Initiatives.

---

## Skill Routing

This is the core overview skill. For stage-specific workflows, use:

| Stage | Skill | Description |
|-------|-------|-------------|
| **Quick Dev** | `/quick-dev` | Skip Idea→Proposal, create tasks directly, execute, and self-verify |
| **Ideation** | `/idea` | Claim Ideas, run structured elaboration rounds, prepare for proposal |
| **Planning** | `/proposal` | Build proposals with PRD + task sub-issues, manage DAG, submit for review |
| **Development** | `/develop` | Claim Tasks, report work, self-check AC, session & Agent Teams integration |
| **Review** | `/review` | Approve/reject Proposals, verify Tasks with AC marking, project governance |

### Getting Started

1. Start a session — labels are auto-created on first launch
2. Based on your role, use the appropriate skill:
   - PM Agent → `/idea` then `/proposal`
   - Developer Agent → `/develop`
   - Admin Agent → `/review` (also has access to all PM and Developer workflows)

---

## Status Lifecycle Reference

### Parent Issue (Idea → Proposal → Approved)

```
[Triage]  + harness:idea
    |
    v  PM claims, starts elaboration
[Triage]  - harness:idea, + harness:elaborating, + harness:pm, + harness:agent
    |
    v  PM completes proposal (PRD + Sub-issues)
[In Review]  - harness:elaborating, + harness:proposal, + harness:admin
    |
    +---> Admin approves: + harness:approved, - harness:admin
    |
    +---> Admin rejects: + harness:rejected, - harness:admin
              |
              v  PM fixes, resubmits: - harness:rejected, + harness:admin
```

### Task (Sub-issue)

```
[Backlog]  + harness:dev                     (created as draft under proposal)
    |
    v  Admin approves proposal → moves to Todo
[Todo]  (no label change)
    |
    v  Developer claims
[In Progress]  + harness:agent
    |
    v  Developer self-checks AC, submits
[In Review]  + harness:admin, + harness:ac-passed (if all AC passed)
    |
    +---> Admin verifies: [Done], - harness:admin
    |
    +---> Admin reopens: [In Progress], - harness:admin, - harness:ac-passed
```

---

## Reference Documents

| File | Content |
|------|---------|
| `references/00-common-tools.md` | Official Linear MCP tool reference |
| `references/01-setup.md` | Setup and configuration guide |
| `references/05-session-management.md` | Session lifecycle and observability |
| `references/06-agent-teams.md` | Claude Code Agent Teams integration |
| `references/07-label-conventions.md` | Label lifecycle and conventions |
