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
| [**Delve**](plugins/delve/) | Interactive diff review - walk through changes one chunk at a time and capture feedback as TODOs. |
| [**git-good**](plugins/git-good/) | Git safety guardrails - fixup-not-amend, surgical conflict resolution, rebase checklists, and destructive command protection. |
| [**Prune**](plugins/prune/) | Interactive branch cleanup - catalog, verify, and delete stale branches with squash-merge awareness. |
| [**Vigil**](plugins/vigil/) | Keep your system awake during active AI agent turns, let it sleep when idle. Cross-platform (Windows, macOS, Linux). |
| [**yes-milord**](plugins/yes-milord/) | Warcraft II Peasant sound notifications - hear "Yes, milord" on prompt submit, "Work complete" when done. |
