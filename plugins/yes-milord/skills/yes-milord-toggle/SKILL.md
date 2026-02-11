---
name: yes-milord-toggle
description: Toggle yes-milord sound notifications on/off. Use when user wants to mute, unmute, pause, or resume peasant sounds during a session.
user_invocable: true
---

# yes-milord-toggle

Toggle yes-milord sounds on or off.

Run the following command using the Bash tool:

```powershell
powershell -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/play-sound.ps1" -toggle
```

Report the output to the user. The command will print either:
- `yes-milord: sounds paused` — sounds are now muted
- `yes-milord: sounds resumed` — sounds are now active
