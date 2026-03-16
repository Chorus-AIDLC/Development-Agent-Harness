# @chorus-aidlc/development-harness

AI-DLC development harness collection. Brings the AI-Driven Development Lifecycle (Idea → Proposal → Task → Execute → Verify → Done) to popular project management platforms via Claude Code plugins.

## Plugins

| Plugin | Platform | Status |
|--------|----------|--------|
| [linear](plugins/linear/) | [Linear](https://linear.app) | v0.1.0 |

## Usage

Each plugin is a self-contained Claude Code plugin. Point `--plugin-dir` at the specific plugin folder:

```bash
export LINEAR_API_KEY="lin_api_xxx"
cd your-project
claude --plugin-dir /path/to/development-harness/plugins/linear
```

## Structure

```
.claude-plugin/     # Repository-level marketplace manifest
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
