---
name: measure-twice
description: Turn the measure-twice review gate on or off for the current session, set the default for new sessions, check its status, or set its review prompt. Use when the user wants to start or stop gating the current session, change what new sessions start with, ask whether it's active, or swap the review agents in the prompt.
user_invocable: true
---

# measure-twice

Control the measure-twice review gate. Match the user's request to a row below, run the command with the Bash
tool, and report the output.

| User wants | Command |
|---|---|
| Gate on for this session | `powershell -ExecutionPolicy Bypass -File "<plugin-root>/scripts/gate.ps1" -enable` |
| Gate off for this session | `powershell -ExecutionPolicy Bypass -File "<plugin-root>/scripts/gate.ps1" -disable` |
| Set the default for new sessions | `powershell -ExecutionPolicy Bypass -File "<plugin-root>/scripts/gate.ps1" -setdefault on` (or `off`) |
| Check status | `powershell -ExecutionPolicy Bypass -File "<plugin-root>/scripts/gate.ps1" -status` |
| Set the review prompt | `powershell -ExecutionPolicy Bypass -File "<plugin-root>/scripts/gate.ps1" -setprompt "YOUR PROMPT"` |

`<plugin-root>` is this plugin's own directory.
