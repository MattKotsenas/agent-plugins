# yes-milord

Your Peasant reports for duty when your agent needs attention.

Copilot CLI and Claude Code don't notify you when they finish or need input.
You tab away, lose focus, and waste time. **yes-milord** fixes this with
Warcraft II Human Peasant voice lines — so you never miss a beat.

## What you'll hear

| Event | Sound | Examples |
|---|---|---|
| Prompt submitted | Acknowledgment | *"Right-o."*, *"Yes, milord."*, *"As you wish."* |
| Agent stops | Completion | *"Ready, milord."*, *"Work complete."* |

## Installation

### GitHub Copilot CLI / Claude Code

```
/plugin marketplace add MattKotsenas/agent-plugins
/plugin install yes-milord@agent-plugins
```

## Quick controls

Toggle sounds on/off during a session:

| Method | Command |
|---|---|
| **Slash command** | `/yes-milord-toggle` |
| **PowerShell** | `powershell path\to\play-sound.ps1 -toggle` |

Other commands:

```powershell
play-sound.ps1 -pause     # Mute sounds
play-sound.ps1 -resume    # Unmute sounds
play-sound.ps1 -status    # Check if paused or active
```

## Configuration

Edit `scripts/config.json` inside the plugin directory:

```json
{
  "enabled": true,
  "active_pack": "peasant",
  "categories": {
    "acknowledge": true,
    "complete": true
  }
}
```

- **enabled**: Master on/off switch
- **active_pack**: Which sound pack to use
- **categories**: Toggle individual sound types on/off

## Requirements

- Windows (uses `System.Media.SoundPlayer`)
- PowerShell 5.1+

## How it works

`play-sound.ps1` is registered as a hook for `UserPromptSubmit` and `Stop` /
`sessionEnd` events. On each event it maps to a sound category, picks a random
voice line (avoiding repeats), and plays it synchronously.

## Sound credits

Sound files are from Warcraft II: Tides of Darkness by Blizzard Entertainment,
sourced via [Thanatos Realms](https://www.thanatosrealms.com/).
