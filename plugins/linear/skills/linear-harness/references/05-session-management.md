# Session Management

Agent sessions in the Linear Development Harness are managed **locally** by the plugin, not by Linear. This document explains how sessions work, how observability is achieved, and how concurrent access is handled.

---

## Architecture

Sessions are purely client-side. The plugin maintains session state in local files and posts key events as Linear Issue Comments for human visibility.

```
.linear-harness/
  sessions/
    <session-uuid>.json     # Session metadata (agent ID, start time, task IDs)
    <session-uuid>.lock     # Lock file for concurrent safety
  state/
    claimed-<issue-id>.lock # Atomic claim locks
```

## Lifecycle

| Event | Trigger | Action |
|-------|---------|--------|
| Create | `SubagentStart` hook fires | Write session JSON, inject workflow context |
| Heartbeat | `TeammateIdle` hook fires | Update timestamp in session JSON |
| Close | `SubagentStop` hook fires | Remove session JSON, release claims |

The plugin hooks manage this lifecycle automatically. Agents do not need to create or close sessions manually.

## Issue Comment Trail

Key session events are posted as Issue Comments on the relevant Linear issue for observability:

| Event | Comment |
|-------|---------|
| Task start | "**Agent 'worker-1' started working on this issue.**" |
| Progress | "**Progress Update** ..." (posted by agent during work) |
| Blocker | "**Blocker** ..." (posted by agent when stuck) |
| Task complete | "**Agent 'worker-1' completed work. Submitting for verification.**" |

These comments are the primary mechanism for humans and Admin Agents to track what agents are doing. Always post comments at key workflow milestones.

## Concurrent Safety

Multiple agents may attempt to claim the same issue simultaneously. The plugin uses two mechanisms to prevent conflicts:

1. **Atomic file claiming**: The `mv` command is used to atomically create claim lock files. Only one agent can successfully `mv` a temporary file to the claim path.

2. **File locking**: `flock` is used on session files to prevent concurrent modifications to the same session state.

3. **Linear assignee check**: Before claiming, agents should verify the issue has no assignee via `get_issue`. If already assigned, skip it.

These three layers ensure that even in swarm scenarios with many concurrent sub-agents, each task is claimed by exactly one worker.

## Session Data Format

Session metadata files (`<session-uuid>.json`) contain:

```json
{
  "sessionUuid": "uuid",
  "agentId": "agent-identifier",
  "startedAt": "2026-03-15T10:00:00Z",
  "lastHeartbeat": "2026-03-15T10:05:00Z",
  "checkedInTasks": ["ENG-201", "ENG-202"],
  "status": "active"
}
```

## Cleanup

When the `SubagentStop` hook fires:
1. Session JSON is removed
2. Claim locks held by this session are released
3. If the agent was mid-task, the task remains In Progress (another agent or human can pick it up)

If a session becomes stale (no heartbeat for 1+ hour), other agents may reclaim its tasks after verifying the assignee via `get_issue`.
