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
| ~~[**Vigil**](plugins/vigil/)~~ | **Removed** — superseded by Copilot CLI's built-in `keepAlive: "busy"` setting in `~/.copilot/settings.json` ([docs](https://docs.github.com/copilot/how-tos/copilot-cli)). If previously installed, run `/plugin uninstall vigil@agent-plugins`. |
| [**yes-milord**](plugins/yes-milord/) | Warcraft II Peasant sound notifications - hear "Yes, milord" on prompt submit, "Work complete" when done. |
| [**toasty**](plugins/toasty/) | Windows toast notifications when the agent needs attention - powered by [toasty](https://github.com/shanselman/toasty). |
| [**gnhf**](plugins/gnhf/) | Good Night, Have Fun - one provably-correct, complexity-reducing change per invocation, on its own branch off the default branch. |
