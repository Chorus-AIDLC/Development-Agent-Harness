# @chorus-aidlc/development-agent-harness

AI-DLC development harness collection. Brings the AI-Driven Development Lifecycle (Idea → Proposal → Task → Execute → Verify → Done) to popular project management platforms via Claude Code plugins.

## Plugins

| Plugin | Platform | Status |
|--------|----------|--------|
| [linear](plugins/linear/) | [Linear](https://linear.app) | v0.1.0 |

## Install

```bash
# 1. Add the marketplace
claude /plugin marketplace add Chorus-AIDLC/Development-Agent-Harness

# 2. Install the Linear plugin
claude /plugin install linear@development-agent-harness

# 3. Set your Linear API key
export LINEAR_API_KEY="lin_api_xxx"
```

## Structure

```
.claude-plugin/     # Marketplace manifest
plugins/
  linear/           # Linear platform plugin
    .claude-plugin/ # Plugin manifest
    .mcp.json       # MCP server config
    hooks/          # Claude Code hook routing
    bin/            # Hook scripts + CLI tools
    skills/         # Skill documentation
```

## License

MIT
