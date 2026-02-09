#!/usr/bin/env bash
# Bouncer PreToolUse hook shim.
# If bouncer is on PATH, forward stdin and exit with its code.
# If bouncer is missing, allow the tool call and warn on stderr.

if command -v bouncer >/dev/null 2>&1; then
    exec bouncer "$@"
else
    echo '{"decision":"allow","reason":"bouncer not found on PATH; allowing by default"}' 
    echo "[bouncer] WARNING: bouncer is not installed or not on PATH. All tool calls are being allowed. Install with: dotnet tool install --global bouncer --add-source https://f.feedz.io/matt-kotsenas/bouncer/nuget/index.json" >&2
    exit 0
fi
