# Agent Teams — Claude Code Integration

The Linear Development Harness integrates with Claude Code Agent Teams to enable multi-agent swarm execution. A Team Lead orchestrates sub-agents, each working on Linear issues in parallel, with full observability through Issue Comments and local session state.

---

## Architecture

```
Team Lead (Claude Code)
  |
  |-- reads Linear issues, plans work, checks DAG
  |
  +-- spawns Sub-agent 1 (worker-1)
  |     |-- plugin creates local session
  |     |-- claims ENG-201, works, posts Comments
  |     +-- plugin cleans up session
  |
  +-- spawns Sub-agent 2 (worker-2)
  |     |-- plugin creates local session
  |     |-- claims ENG-202, works, posts Comments
  |     +-- plugin cleans up session
  |
  +-- spawns Sub-agent 3 (worker-3)
        |-- plugin creates local session
        |-- claims ENG-203, works, posts Comments
        +-- plugin cleans up session
```

- **Team Lead**: Plans execution, checks dependencies, spawns workers, monitors progress
- **Sub-agents**: Each handles one or more Linear issues, operates independently
- **Plugin hooks**: Auto-manage session lifecycle per sub-agent
- **Linear**: Single source of truth for issue state, comments, and relations

## Workflow

### Step 1: Team Lead Plans Work

The Team Lead reads the Linear project state:

```
list_issues({
  teamId: "team-uuid",
  status: "Todo",
  labelIds: ["harness-dev-label-uuid"]
})
```

Check blocking relations to determine which tasks can be executed in parallel:

```
get_issue({ issueId: "task-1-uuid" })
get_issue({ issueId: "task-2-uuid" })
get_issue({ issueId: "task-3-uuid" })
```

Build a mental model of the DAG:
- Wave 1: Tasks with no unresolved blockers (can run in parallel)
- Wave 2: Tasks unblocked after Wave 1 completes
- Wave 3: Tasks unblocked after Wave 2 completes

### Step 2: Team Lead Spawns Sub-agents

For each task in Wave 1, spawn a sub-agent with the Linear issue identifier in the Claude Code task description:

```
Task for worker-1:
  Implement Salesforce REST API connector.
  Linear issue: linear:issue:ENG-201
  Follow the developer workflow in the linear-harness skill.
```

The `linear:issue:<identifier>` pattern enables the plugin to link the Claude Code task to the Linear issue.

### Step 3: Plugin Auto-creates Sessions

When a sub-agent starts, the `SubagentStart` hook:
1. Creates a session file in `.linear-harness/sessions/`
2. Injects the developer workflow context into the sub-agent's prompt
3. Provides the session UUID for tracking

The sub-agent does not need to call any session creation tool — it is handled automatically.

### Step 4: Sub-agents Execute

Each sub-agent follows the developer workflow (`references/03-developer-workflow.md`):
1. Claim the issue (update assignee, move to In Progress)
2. Post start comment
3. Gather context
4. Implement work with progress comments
5. Self-check acceptance criteria
6. Submit for verification

All key events are posted as Issue Comments for the Team Lead and Admin to see.

### Step 5: Sub-agent Stops

When a sub-agent finishes (or is stopped), the `SubagentStop` hook:
1. Removes the session file
2. Releases any claim locks
3. The Issue Comments remain as a permanent record

### Step 6: Team Lead Checks for Unblocked Work

After Wave 1 sub-agents complete, the Team Lead checks for newly unblocked tasks:

```
list_issues({
  teamId: "team-uuid",
  status: "Todo"
})
```

For each Todo task, check if all blocking relations point to Done issues:

```
get_issue({ issueId: "wave-2-task-uuid" })
```

If unblocked, spawn the next wave of sub-agents.

### Step 7: Repeat Until Done

Continue spawning waves until all tasks are complete or submitted for verification.

---

## Wave-Based Execution Example

Given a DAG:
```
Task A (no deps) ---> Task C (blocked by A, B)
Task B (no deps) --+      |
                         v
                   Task D (blocked by C)
```

**Wave 1**: Spawn workers for Task A and Task B in parallel.
**Wave 2**: After A and B are Done, spawn worker for Task C.
**Wave 3**: After C is Done, spawn worker for Task D.

The Team Lead orchestrates this by checking issue status between waves.

---

## Key Points

### One Session Per Worker

Each sub-agent gets exactly one local session. The plugin handles creation and cleanup automatically. Do not attempt to share sessions between workers.

### Linking CC Tasks to Linear Issues

Always include `linear:issue:<identifier>` in the Claude Code task description. This can be either:
- The issue identifier: `linear:issue:ENG-201`
- The issue UUID: `linear:issue:a1b2c3d4-...`

The identifier format (e.g., ENG-201) is preferred for readability.

### Direct MCP Tool Access

Sub-agents use the official Linear MCP tools directly. There is no proxy or wrapper — each sub-agent authenticates with the same `LINEAR_API_KEY` and has full access to the Linear workspace.

### Auto-injected Workflow

The `SubagentStart` hook injects the developer workflow instructions into the sub-agent's context. Sub-agents do not need to be told how to interact with Linear — they receive the workflow automatically.

### Concurrent Claim Safety

Multiple sub-agents may discover the same unassigned task. The plugin's atomic file claiming prevents double-claims at the local level. Additionally, sub-agents should check the issue's assignee via `get_issue` before attempting to claim.

### Comment-Based Observability

Since sessions are local, the Issue Comment trail is the primary observability mechanism. The Team Lead can check progress by reading comments:

```
list_comments({ issueId: "ENG-201" })
```

---

## Troubleshooting

### Sub-agent Cannot Find Issue

**Symptom**: `get_issue` returns not found.

**Causes and fixes**:
- Incorrect identifier format: Use the team key prefix (e.g., `ENG-201`, not just `201`)
- Issue was deleted or merged: Check in Linear UI
- Wrong workspace: Verify `LINEAR_API_KEY` connects to the correct workspace

### Labels Missing

**Symptom**: `list_issue_labels` does not show `harness:*` labels.

**Fix**: Run `bin/bootstrap.sh` to create all harness labels. The script is idempotent.

### Status Update Fails

**Symptom**: `update_issue` with a status name fails.

**Causes and fixes**:
- Workflow state does not exist: Call `list_issue_statuses({ teamId: "..." })` to see available states
- "In Review" not configured: Add it manually in Linear team workflow settings
- Using state name instead of ID: Some API calls require the state UUID, not the name

### Sub-agent Stalls

**Symptom**: A sub-agent stops posting comments but has not completed.

**Diagnosis**:
1. Check the local session file in `.linear-harness/sessions/`
2. Check the issue status in Linear
3. If the session file is stale (no heartbeat for 1+ hour), the sub-agent likely crashed

**Fix**: The Team Lead can spawn a new sub-agent for the same task. The new agent should check the issue's current state and comments before resuming.

### Multiple Agents Claimed Same Issue

**Symptom**: Two agents are both assigned to the same issue.

**Fix**: This should not happen with atomic file claiming. If it does:
1. Check which agent posted the first "started working" comment
2. Reassign the issue to that agent
3. The other agent should release the task and find new work
