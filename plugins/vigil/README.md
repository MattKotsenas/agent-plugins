# Vigil

Keep your system awake while AI agents work, let it sleep when they're idle.

Vigil hooks into the agent turn lifecycle to prevent system sleep during active turns. When the agent finishes and waits
for input, the hold is released and the system can sleep normally. Multiple concurrent sessions are handled
independently - the system stays awake as long as any session is active.

## How it works

```
  Agent CLI             Hook Script           vigil / caffeinate       OS Sleep API
     |                      |                        |                      |
     | user submits prompt  |                        |                      |
     |--------------------->|                        |                      |
     |                      |    get parent PID      |                      |
     |                      |   spawn vigil start    |                      |
     |                      |----------------------->|    inhibit sleep     |
     |                      |                        |--------------------->|
     |    hook returns      |                        |                      |
     |<---------------------|                        |  idle timer FROZEN   |
     |                      |                        |                      |
     |  (thinking, tool     |                        |  sleeping forever,   |
     |  calls, responding)  |                        |  0 CPU, watching     |
     |                      |                        |  agent PID           |
     |   agent turn ends    |                        |                      |
     |--------------------->|                        |                      |
     |                      |     read PID file      |                      |
     |                      |      kill vigil        |                      |
     |                      |----------kill--------->X        clear         |
     |                      |    delete PID file     |--------------------->|
     |     hook return      |                        |                      |
     |<---------------------|                        |  flag auto-cleared   |
     |                      |                        |  idle timer RESUMES  |
     |  waiting for input   |                        |                      |
     |                      |                        |                      |

  If the agent crashes, vigil detects the parent death and exits
  automatically, clearing the sleep inhibitor. No orphans.
```

### Platform support

| Platform | Sleep inhibitor |
|----------|----------------|
| Windows  | [`SetThreadExecutionState`](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-setthreadexecutionstate) |
| macOS    | `caffeinate -i -w <pid>` (built-in) |
| Linux    | `systemd-inhibit` |

### Multi-session safety

Each session's vigil process independently holds a sleep inhibitor. On Windows, `SetThreadExecutionState` is tracked
per-thread by the kernel - the system stays awake as long as *any* process holds the flag. No shared state or
coordination needed. On macOS/Linux, each `caffeinate`/`systemd-inhibit` instance is independent.

## Prerequisites

- [.NET 10 SDK](https://dot.net) (Linux and Windows only; macOS uses the built-in `caffeinate`)

## Installation

```
/plugin marketplace add MattKotsenas/agent-plugins
/plugin install vigil@agent-plugins
```

## Commands

| Command | Description |
|---------|-------------|
| `vigil start <pid>` | Keep system awake, watching `<pid>` for crash safety |
| `vigil end <pid>` | Release the vigil for the given session PID |
| `vigil clear` | Kill all vigil processes and clean up (emergency reset) |

## Files

```
hooks/hooks.json     Hook config (userPromptSubmitted, agentStop, sessionEnd)
scripts/vigil.cs     .NET 10 file-based app - sleep inhibitor + parent watcher
scripts/acquire.ps1  Windows hook: gets agent PID, spawns vigil
scripts/release.ps1  Windows hook: reads PID file, kills vigil
scripts/acquire.sh   macOS/Linux hook: caffeinate on Darwin, dotnet run on Linux
scripts/release.sh   macOS/Linux hook: reads PID file, kills vigil
```

PID files are stored in `$TEMP/vigil/<agentPid>.pid`.
