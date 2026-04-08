#!/bin/sh
# Acquire: start a vigil for the agent session that spawned this hook
# Hook parent = copilot/claude, so $PPID is the agent PID
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

case "$(uname)" in
    Darwin)
        # macOS: caffeinate does everything natively
        caffeinate -i -w "$PPID" &
        VIGIL_DIR="${TMPDIR:-/tmp}/vigil"
        mkdir -p "$VIGIL_DIR"
        echo $! > "$VIGIL_DIR/$PPID.pid"
        ;;
    *)
        # Linux: use vigil.cs via dotnet run
        nohup dotnet run "$SCRIPT_DIR/vigil.cs" -- start "$PPID" > /dev/null 2>&1 &
        ;;
esac
