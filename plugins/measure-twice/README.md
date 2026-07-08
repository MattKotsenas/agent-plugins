# measure-twice

Measure twice, cut once. A review gate that makes your agent stop and run your review agents before it finishes a
turn.

Instructions ask the agent to review its own work, and the agent forgets. **measure-twice** makes the check
non-skippable: when the agent tries to end a turn, the gate blocks it and hands back a one-time token. The agent
only gets the token by reading the block, so it cannot finish without at least being asked to review.

## Installation

```
/plugin marketplace add MattKotsenas/agent-plugins
/plugin install measure-twice@agent-plugins
```

Hooks load when the CLI starts, so restart your session after installing.

## Modes

On or off is per session. Enabling or disabling flips only the current session; setting the default changes what
new sessions start from. Both go through `/measure-twice`:

- **This session**: enable or disable. The choice lives in the session folder, so it never leaks to other sessions
  or to your dotfiles.
- **Default for new sessions**: set the default, or manage it in `config.json` (below). It ships as `on`, so an
  installed gate works immediately.

Turn the current session off for a quiet interactive stretch.

## Configuring the review prompt

The prompt injected on each block is yours to set. The default names no specific reviewers; name your own so the
agent knows exactly what to run. Set it through `/measure-twice`, or manage `config.json` from your dotfiles to keep
it under version control:

```json
{
  "defaultMode": "on",
  "prompt": "Run rubber-duck and iron-shrike, then address any Critical or High findings."
}
```

The home config holds the prompt and the new-session default. It lives in `<COPILOT_HOME>/measure-twice/config.json`
(by default `~/.copilot/measure-twice/config.json`), outside the plugin directory, so it survives plugin updates and
is safe to symlink from dotfiles. Each session's own on/off and gate state live in that session's folder.

## How it works

`scripts/gate.ps1` is registered on the Copilot CLI `agentStop` event. When the gate is
active and the agent tries to finish:

1. The gate generates a random token, splits it with a space, and blocks the turn with your review prompt plus an
   instruction to echo the token with the space removed.
2. The agent runs its reviews, addresses findings, and outputs the joined token.
3. The gate sees the token in the agent's message, clears its state, and lets the turn finish.

Splitting the token is what makes the check real: the joined form never appears in the prompt, so echoing it proves
the agent read the block. A fresh token each turn and a block cap keep a stuck agent from looping.

## Requirements

- PowerShell (the gate is a PowerShell script; Windows PowerShell 5.1 or PowerShell 7+)
- Copilot CLI

## Limits

A determined agent can echo the token without reviewing: the gate defends against forgetting, not evasion. Pair it
with a measurement loop if you need to catch an agent that games it.
