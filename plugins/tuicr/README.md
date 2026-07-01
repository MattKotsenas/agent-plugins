# tuicr

Drive [tuicr](https://github.com/agavra/tuicr) - the terminal code-review TUI - from a Copilot session, on
Windows + PowerShell + psmux.

## What it does

The human reviews the diff in the tuicr TUI; the agent works through the `tuicr review` CLI:

- **Attach** to the live review session (`tuicr review list`, selecting the `active` one).
- **Read** the user's comments (`tuicr review comments`) and act on them by type - `issue`, `suggestion`,
  `note`, `praise`.
- **Add** agent-authored findings (`tuicr review add --username ...`) only in an agent-review workflow.
- **Launch** an interactive pane by splitting the agent's *own* psmux pane (`$env:TMUX_PANE`), so the review
  lands next to the session that started it - never in whatever window the user happens to be viewing.

## What it doesn't do

It does not drive the TUI for the user, submit reviews on their behalf, or replace `git diff`.

## Prerequisites

`tuicr` on PATH (`cargo install tuicr`). The review-reading loop works with or without a multiplexer; the
split-pane launch path assumes psmux (or tmux).

## Installation

```
/plugin marketplace add MattKotsenas/agent-plugins
/plugin install tuicr@agent-plugins
```

## How to use it

Agents should load the skill when a review is requested. To make triggering reliable, invoke it directly when you
start a review ("let's review this in tuicr"), or add it to your custom instructions to load on agent start.
