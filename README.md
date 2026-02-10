# Agent Plugins

A plugin marketplace for [Claude Code](https://docs.anthropic.com/en/docs/claude-code)
and [GitHub Copilot CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli).

## Installation

### GitHub Copilot CLI / Claude Code

Add the marketplace, then install the plugin:

```
/plugin marketplace add MattKotsenas/agent-plugins
/plugin install <plugin>@agent-plugins
```

## Plugins

| Plugin | Description |
|--------|-------------|
| [**Delve**](skills/delve/) | Interactive diff review — walk through changes one chunk at a time and capture feedback as TODOs. |
