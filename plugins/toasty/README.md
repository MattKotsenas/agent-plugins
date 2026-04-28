# toasty

Windows toast notifications when your Copilot CLI agent needs attention.

Uses [toasty](https://github.com/shanselman/toasty) to show system-level
notifications when the agent finishes a turn or hits an error, so you can
tab away without missing a beat.

## What you'll see

| Event | Toast title | Message |
|---|---|---|
| Agent finishes a turn | Copilot | "Copilot is waiting for you" |
| Agent asks a question | Input Requested | "Copilot has a question" |
| Error occurs | Error | "Copilot hit an error: ..." |

## Prerequisites

- Windows
- [toasty](https://github.com/shanselman/toasty) on PATH
- PowerShell 5.1+

## Installation

```
/plugin marketplace add MattKotsenas/agent-plugins
/plugin install toasty@agent-plugins
```

## How it works

The plugin registers `agentStop`, `preToolUse`, and `errorOccurred` hooks.
A PowerShell script reads the hook payload, determines the event type (filtering
`preToolUse` to only `ask_user` calls), and calls `toasty.exe` with an appropriate
message and the Copilot icon.

A per-event-type debounce (10 second cooldown) prevents notification spam.

Toasts are suppressed when the user is already looking at the terminal:

- **Outside tmux**: suppressed when Windows Terminal has focus.
- **Inside tmux**: suppressed only when your specific pane is active
  AND Windows Terminal is focused. If you're in a different tmux pane,
  you'll still get the toast.
- **Alt-tabbed away**: always shows the toast.

## Debugging

Debug logging is opt-in. Create an empty `debug.log` file in the plugin
root to enable it:

```powershell
New-Item -ItemType File -Path plugins/toasty/debug.log
```

Raw hook payloads and event decisions are appended to this file. Delete it
to disable logging.

## Files

```
hooks/hooks.json       Hook config (agentStop + preToolUse + errorOccurred)
scripts/notify.ps1     PowerShell script that calls toasty
```
