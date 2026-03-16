# Linear Development Harness — Skill Overview

## What is the Linear Development Harness?

The Linear Development Harness (`@chorus-aidlc/linear-development-harness`) is a Claude Code plugin that brings the **AI-DLC (AI-Driven Development Lifecycle)** workflow to Linear. It enables multiple AI Agents and humans to collaborate through a structured pipeline — Idea, Proposal, Task, Execute, Verify, Done — using Linear as the single source of truth for project management.

The plugin uses the **official Linear MCP server** (`https://mcp.linear.app/mcp`) for core operations, plus `bin/linear-extra.sh` CLI for advanced features (issue relations, cycles, initiatives, bulk operations). Agent sessions are managed locally via `.linear-harness/` state files, with key events posted as Issue Comments for visibility.

Core philosophy: **"Reversed Conversation"** — AI proposes, humans verify.

## AI-DLC Workflow on Linear

The workflow uses a **single Parent Issue** as the container for the entire lifecycle — from Idea through Proposal to completion. Labels on this Parent Issue track the current phase. Tasks are Sub-issues; PRDs are Documents.

```
[Parent Issue] harness:idea  (Triage)
  |
  v  PM claims, posts elaboration questions as Comments
[Parent Issue] harness:elaborating
  |
  v  PM creates PRD Document + Task Sub-issues + DAG
[Parent Issue] harness:proposal  (In Review)
  |
  v  Admin reviews and approves
[Parent Issue] harness:approved
  |
  v  Sub-issues moved to Todo
[Sub-issues]   Developer claims, In Progress
  |
  v  Developer submits for verify
[Sub-issues]   Admin verifies → Done
```

Each phase maps to a `harness:*` label on the **same Parent Issue**. There is no separate Idea issue and Proposal issue — they are one and the same.

## Three Agent Roles

| Role | Responsibility | Key Labels |
|------|---------------|------------|
| **PM Agent** | Discovers ideas, elaborates requirements, creates proposals with tasks and PRDs | `harness:pm` |
| **Developer Agent** | Claims tasks, implements work, self-checks acceptance criteria, submits for review | `harness:dev` |
| **Admin Agent** | Reviews proposals, approves/rejects, verifies completed tasks, manages projects and cycles | `harness:admin` |

All agents share the same official Linear MCP tools. Role differentiation comes from which workflow steps each agent performs and which labels they apply.

## Shared Linear MCP Tools

All agents connect to the official Linear MCP server at `https://mcp.linear.app/mcp`. Available tool categories:

- **Query**: `list_issues`, `list_projects`, `list_teams`, `list_users`, `list_documents`, `list_cycles`, `list_comments`, `list_issue_labels`, `list_issue_statuses`, `list_project_labels`
- **Read**: `get_issue`, `get_project`, `get_team`, `get_user`, `get_document`, `get_issue_status`
- **Create**: `create_issue`, `create_project`, `create_comment`, `create_issue_label`
- **Update**: `update_issue`, `update_project`
- **Search**: `search_documentation`

For operations not covered by the official MCP (issue relations, cycle management, bulk operations), use `bin/linear-extra.sh` — a CLI tool that wraps GraphQL calls and automatically uses `LINEAR_API_KEY` from environment.

## Label Conventions

The harness uses `harness:*` labels to track AI-DLC state. These labels are workspace-level and visible across all teams.

| Label | Purpose |
|-------|---------|
| `harness:idea` | Idea awaiting elaboration |
| `harness:elaborating` | Under AI elaboration |
| `harness:proposal` | Proposal pending approval |
| `harness:approved` | Proposal approved |
| `harness:rejected` | Proposal rejected |
| `harness:pm` | PM Agent work item |
| `harness:dev` | Developer Agent work item |
| `harness:admin` | Admin review needed |
| `harness:agent` | Assigned to AI Agent (always present on agent-assigned issues) |

Run `bin/bootstrap.sh` to create all labels automatically. See `references/07-label-conventions.md` for full lifecycle details.

## Workflow State Mapping

Each Linear team should have these workflow states configured:

| Linear State | AI-DLC Meaning |
|-------------|----------------|
| Triage | Idea (needs elaboration) |
| Backlog | Elaborated (ready for planning) |
| Todo | Open (ready for assignment) |
| In Progress | In progress (agent working) |
| In Review | Verify (pending admin verification) |
| Done | Completed and verified |
| Canceled | Closed |

The "In Review" state may need to be added as a custom state in your team's workflow settings.

## Session and Observability

Agent sessions are managed **locally** by the plugin, not by Linear:

- `.linear-harness/sessions/` contains session metadata files
- Plugin hooks (`SubagentStart`, `SubagentStop`, `TeammateIdle`) manage lifecycle automatically
- Key events are posted as **Issue Comments** for human visibility
- No server-side session state — purely client-side with a Comment trail

This approach gives full observability in Linear while keeping session management lightweight and self-contained.

## Getting Started

1. **Setup**: Configure your Linear API key and MCP connection (see `references/01-setup.md`)
2. **Bootstrap**: Run `bin/bootstrap.sh` to create `harness:*` labels in your workspace
3. **Check in**: Verify connectivity by calling `list_teams`
4. **Follow your role workflow**:
   - PM Agent: `references/02-pm-workflow.md`
   - Developer Agent: `references/03-developer-workflow.md`
   - Admin Agent: `references/04-admin-workflow.md`

## Execution Rules

1. **Always check viewer info first.** Call `list_teams` or `get_user` to confirm your identity and workspace context before starting any workflow.

2. **Use label conventions — never skip `harness:*` labels.** Every AI-DLC state transition must be accompanied by the correct label change. Labels are the primary mechanism for filtering and tracking workflow state.

3. **A single Parent Issue is both Idea and Proposal.** The same issue starts as `harness:idea`, transitions through `harness:elaborating` and `harness:proposal` to `harness:approved`. Tasks are Sub-issues under it. PRDs are linked Documents.

4. **Elaboration uses Comment threads on the Parent Issue.** All elaboration Q&A happens as Comments on the same Parent Issue that will become the Proposal. This keeps context co-located and auditable.

5. **Acceptance criteria use Markdown checklists.** Task descriptions must include `- [ ]` checklist items. Developers self-check these before submitting for verification.

6. **Sessions are auto-managed by plugin hooks.** Do not manually create or destroy sessions. The plugin's `SubagentStart` and `SubagentStop` hooks handle lifecycle. Post Comments for visibility.

7. **Link CC tasks to Linear issues with `linear:issue:<identifier>` in description.** This enables the plugin to correlate Claude Code task execution with Linear issue tracking.

8. **Use blocking/blocked-by relations for task DAGs.** Issue relations define execution order. Never start a task that has unresolved blocking relations. Use `bash bin/linear-extra.sh relation create` to set relations.

9. **Leverage Cycles for sprint planning.** Assign approved tasks to Cycles to organize work into time-boxed iterations.

10. **Use Initiatives for strategic goal tracking.** Group related Projects under Initiatives for portfolio-level visibility.

## Reference Documents

| File | Content |
|------|---------|
| `references/00-common-tools.md` | Official Linear MCP tool reference |
| `references/01-setup.md` | Setup and configuration guide |
| `references/02-pm-workflow.md` | PM Agent workflow |
| `references/03-developer-workflow.md` | Developer Agent workflow |
| `references/04-admin-workflow.md` | Admin Agent workflow |
| `references/05-session-management.md` | Session lifecycle and observability |
| `references/06-agent-teams.md` | Claude Code Agent Teams integration |
| `references/07-label-conventions.md` | Label lifecycle and conventions |
