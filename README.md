# @chorus-aidlc/development-agent-harness

AI-DLC development harness collection. Brings the **AI-Driven Development Lifecycle** (Idea → Proposal → Task → Execute → Verify → Done) to popular project management platforms via Claude Code plugins.

Part of the [Chorus AI-DLC](https://github.com/Chorus-AIDLC/Chorus) ecosystem — an open collaboration platform for AI Agents and humans.

## What is AI-DLC?

AI-DLC is a structured workflow where AI agents and humans collaborate through defined roles:

- **PM Agent** — discovers ideas, runs structured elaboration, creates proposals with PRD and task breakdowns
- **Developer Agent** — claims tasks, implements code, self-checks acceptance criteria with evidence
- **Admin Agent** — reviews proposals, verifies tasks against AC, manages project governance

The workflow follows: **Idea → Elaboration → Proposal → Approval → Execute → Verify → Done**

Each stage has dedicated skills with Linear-specific guidance, and the plugin automates session lifecycle, context injection, and observability through Claude Code hooks.

## Plugins

| Plugin | Platform | Version | Status |
|--------|----------|---------|--------|
| [linear](plugins/linear/) | [Linear](https://linear.app) | v0.4.0 | Active |

## Key Features

- **6 modular skills** — core, idea, proposal, develop, quick-dev, review
- **Independent review agents** — `proposal-reviewer` and `task-reviewer` auto-suggested via PostToolUse hooks after submission
- **Structured elaboration** — multi-round Q&A via `AskUserQuestion` with categories and depth levels
- **Proposal label state machine** — draft → submitted → approved/rejected via label stacking
- **Structured acceptance criteria** — `AC-{n}:` format with dev self-check and admin verification
- **Quick-Dev fast track** — skip Idea→Proposal for small tasks, with admin self-verify
- **Agent Teams integration** — wave-based parallel execution with DAG-aware task dispatch
- **Automated hooks** — session lifecycle, PostToolUse review triggers, unblocked task discovery
- **Configurable via userConfig** — `enableProposalReviewer` / `enableTaskReviewer` toggles in plugin settings
- **Client-side sessions** — no server dependency, full observability via Linear Issue Comments

## Install

```bash
# 1. Add the marketplace
claude /plugin marketplace add Chorus-AIDLC/Development-Agent-Harness

# 2. Install the Linear plugin
claude /plugin install linear@development-agent-harness

# 3. Set your Linear API key
export LINEAR_API_KEY="lin_api_xxx"
```

`harness:*` labels are auto-created on first session start — no manual bootstrap needed.

## Quick Start

1. **Start a session**: Labels are auto-created on first launch
2. **Check your role** and use the appropriate skill:
   - PM Agent → `/idea` then `/proposal`
   - Developer Agent → `/develop`
   - Admin Agent → `/review`
   - Quick tasks → `/quick-dev`
3. **For Agent Teams**: Team Lead spawns sub-agents with `linear:issue:<identifier>` — the plugin auto-injects session context

## Structure

```
.claude-plugin/           # Marketplace manifest
plugins/
  linear/                 # Linear platform plugin
    .claude-plugin/       # Plugin manifest + userConfig
    .mcp.json             # MCP server config
    hooks/                # Claude Code hook routing (incl. PostToolUse)
    bin/                  # Hook scripts + CLI tools
    agents/               # Independent review agents
      proposal-reviewer.md  # Read-only proposal QA (VERDICT: PASS/FAIL/PARTIAL)
      task-reviewer.md      # Read-only task verification (runs tests, checks AC)
    skills/
      linear-harness/     # Core skill — overview, shared tools, setup
      idea/               # Ideation — elaboration via AskUserQuestion
      proposal/           # Planning — PRD, tasks, DAG, label state machine
      develop/            # Development — claim, implement, AC self-check
      quick-dev/          # Fast track — skip proposal for small tasks
      review/             # Governance — approve/reject, verify with AC
```

## Relationship to Chorus

This harness brings the [Chorus AI-DLC](https://github.com/Chorus-AIDLC/Chorus) workflow to Linear. Chorus is a full collaboration platform with server-side session management, structured MCP tools, and a web UI. This harness adapts the same concepts for Linear using:

- **Linear Issues** as the equivalent of Chorus Ideas, Proposals, and Tasks
- **Linear Documents** as the equivalent of Chorus PRD/Tech Design documents
- **Linear Labels** (`harness:*`) as the workflow state machine
- **Linear Issue Relations** (blocking/blocked-by) as the task dependency DAG
- **Linear Issue Comments** as the observability trail (replacing Chorus server-side sessions)
- **Client-side state files** (`.linear-harness/`) for local session management

The design philosophy is the same — "Reversed Conversation" where AI proposes and humans verify — adapted to work natively with Linear's data model.

## License

MIT
