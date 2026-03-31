# Idea Skill — Linear Development Harness

This skill covers the **Ideation** stage of the AI-DLC workflow: claiming Ideas, running structured elaboration rounds to clarify requirements, and preparing for Proposal creation.

---

## Overview

Ideas are the starting point of the AI-DLC pipeline. Humans (or Admin agents) create Ideas as Parent Issues with `harness:idea` label in Triage. The PM Agent claims an Idea, runs elaboration to clarify requirements, and then moves on to `/proposal`.

```
Idea (Triage + harness:idea) --> claim --> elaborating --> elaboration resolved --> /proposal
```

---

## Tools

All operations use the official Linear MCP tools. Key tools for this stage:

| Tool | Purpose |
|------|---------|
| `search_issues` | Find ideas: filter by `status: "Triage"` + `labelIds: [harness:idea]` |
| `get_issue` | Read idea details |
| `update_issue` | Claim idea (assign self, update labels) |
| `create_comment` | Post elaboration questions and summaries |
| `get_comments` | Read elaboration responses |

---

## Workflow

### Step 1: Check In

Call `get_teams` to verify workspace connection and discover team UUIDs. Then `get_labels` to cache `harness:*` label UUIDs.

### Step 2: Find Available Ideas

```
search_issues({
  teamId: "team-uuid",
  status: "Triage",
  labelIds: ["harness-idea-label-uuid"]
})
```

### Step 3: Claim an Idea

Read the idea first, then claim it:

```
get_issue({ issueId: "ENG-101" })

update_issue({
  issueId: "ENG-101",
  assigneeId: "your-agent-uuid",
  labelIds: ["harness-idea-label-uuid", "harness-pm-label-uuid", "harness-agent-label-uuid"]
})

create_comment({
  issueId: "ENG-101",
  body: "**PM Agent claimed this idea for elaboration.**"
})
```

### Step 4: Gather Context

Before elaborating, understand the full picture:

1. Read the idea description and existing comments
2. Read project documents for context (`get_documents`)
3. Review past approved proposals for patterns
4. Check existing tasks to avoid duplication

### Step 5: Elaborate on the Idea

**Every Idea should go through elaboration.** Skip only when requirements are completely unambiguous (e.g., bug fix with clear reproduction steps) — and only with user permission.

#### Structured Elaboration Rounds

Elaboration follows a structured multi-round Q&A format using Issue Comments. Each round has a number, category tags, and explicit questions.

##### Determine Depth

Based on idea complexity, choose a depth:

| Depth | Questions | When to Use |
|-------|-----------|-------------|
| **Minimal** | 2-4 | Small features, minor enhancements |
| **Standard** | 5-10 | Typical new features |
| **Comprehensive** | 10-15 | Large features, architectural changes |

##### Question Categories

Tag each question with a category for clarity:

- `functional` — What the system should do
- `non_functional` — Performance, security, reliability
- `business_context` — Business goals, success metrics
- `technical_context` — Tech stack, constraints, integrations
- `user_scenario` — User stories, workflows, personas
- `scope` — Boundaries, what's in/out

##### Round 1: Post Elaboration Questions

Update labels and post structured questions:

```
update_issue({
  issueId: "ENG-101",
  labelIds: ["harness-elaborating-label-uuid", "harness-pm-label-uuid", "harness-agent-label-uuid"]
})

create_comment({
  issueId: "ENG-101",
  body: "## Elaboration Round 1\n\n### [functional] User Access\n1. What user roles should have access to this feature?\n   - (a) All users\n   - (b) Admin only\n   - (c) Role-based (configurable)\n\n### [technical_context] Integration\n2. Are there existing systems this needs to integrate with?\n\n### [scope] Boundaries\n3. What is explicitly out of scope for v1?\n\n### [non_functional] Performance\n4. Are there specific latency or throughput requirements?\n\nPlease reply to each question. I will proceed once I have sufficient context."
})
```

##### Wait for and Process Responses

```
get_comments({ issueId: "ENG-101" })
```

Review answers. If any are incomplete, ambiguous, or contradictory, create a follow-up round:

##### Follow-Up Rounds (if needed)

```
create_comment({
  issueId: "ENG-101",
  body: "## Elaboration Round 2 — Follow-up\n\n### [functional] Clarification\n1. You mentioned 'role-based access' — which specific roles should be defined at launch?\n\n### [scope] Ambiguity\n2. The timeline says 'Q2' — is that a hard deadline or a target?\n\n**Issue from Round 1:** Q1 answer ('role-based') conflicts with the description which says 'all users'. Please clarify."
})
```

Tag follow-up issues explicitly:
- **Contradiction** — answers conflict with each other or with the original idea
- **Ambiguity** — answer is unclear or can be interpreted multiple ways
- **Incomplete** — answer doesn't provide enough detail to proceed

##### Skip Elaboration

For trivially clear ideas (bug fix with clear steps), you may skip elaboration **only with user permission**. Post a comment explaining why:

```
create_comment({
  issueId: "ENG-101",
  body: "**Elaboration skipped** — Bug fix with clear reproduction steps. Proceeding directly to proposal."
})
```

### Step 6: Summarize and Confirm

Once all questions are answered, post a consolidated summary and ask for confirmation:

```
create_comment({
  issueId: "ENG-101",
  body: "## Elaboration Summary\n\nBased on our discussion:\n\n- **User Access**: Role-based, with Admin and Editor roles at launch\n- **Integration**: Salesforce REST API + internal LDAP\n- **Scale**: ~50K records/day\n- **Timeline**: Q2 2026 (target, not hard deadline)\n- **Out of Scope**: De-provisioning, non-Salesforce CRM\n\nDoes this match your intent? If confirmed, I will create a formal proposal."
})
```

### Step 7: Transition to Proposal

Once confirmed, move to `/proposal` to create the formal proposal. The same Parent Issue will be used — see `/proposal` for the next steps.

---

## Elaboration as Audit Trail

Even if requirements are discussed outside the formal elaboration flow (e.g., in conversation), **record key decisions as elaboration round comments** so they are persisted and visible to the team.

---

## Tips

- When combining multiple ideas, explain how they relate in the elaboration summary
- Elaboration improves Proposal quality — don't skip it unless requirements are trivially clear
- Record decisions made in conversation as elaboration rounds for auditability
- Always ask for confirmation before proceeding to proposal
- Use structured round format consistently for machine and human readability

---

## Next

- Once elaboration is resolved, use `/proposal` to create a Proposal with PRD and task sub-issues
- For platform overview and shared tools, see `/linear-harness`
